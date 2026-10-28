import 'dart:io';
import 'dart:typed_data';

import 'capability_contracts.dart';

/// Disposable phase 00 capability storage, never a restaurant repository.
///
/// A flushed staging directory is renamed to a NEW revision path. Publication
/// never replaces an existing file or directory. Readers discover the highest
/// committed revision, ignoring unpublished staging left by an interrupted run.
/// This proves process-restart persistence, not power-loss/fsync durability.
final class IsolatedProbeRepository {
  IsolatedProbeRepository(
    this.root, {
    Future<Directory> Function(Directory staging, String destination)?
    publishDirectory,
  }) : _publishDirectory = publishDirectory ?? _rename;

  static const rootName = 'dakhl_restaurant_phase00_devprobe';
  static const _markerName = '.phase00-synthetic-only';
  static const _markerValue = 'dakhl_restaurant.phase00.synthetic-only.v1';
  static final _activeRoots = <String>{};
  final Directory root;
  final Future<Directory> Function(Directory staging, String destination)
  _publishDirectory;

  static Future<Directory> _rename(Directory staging, String destination) =>
      staging.rename(destination);

  Future<CapabilityResult<void>> initialise() =>
      _guard<void>((_) async => const CapabilitySuccess(null));

  Future<CapabilityResult<SyntheticProbe>> read() => _guard((directory) async {
    final latest = await _latest(directory);
    return latest.probe == null
        ? const CapabilityFailure('empty', 'No synthetic probe has been saved.')
        : CapabilitySuccess(latest.probe!);
  });

  Future<CapabilityResult<void>> write(SyntheticProbe probe) async {
    if (!probe.isValid) {
      return const CapabilityFailure(
        'invalid_synthetic_input',
        'Only a bounded synthetic probe can be saved.',
      );
    }
    return _guard((directory) async {
      final latest = await _latest(directory);
      // A retry after an uncertain response/reopen is idempotent.
      if (latest.probe?.message == probe.message &&
          latest.probe?.sequence == probe.sequence) {
        return const CapabilitySuccess(null);
      }
      if (latest.number >= 9999999999) {
        return const CapabilityFailure('capacity', 'Synthetic revision limit.');
      }
      final destination =
          '${directory.path}/revision-${(latest.number + 1).toString().padLeft(10, '0')}';
      if (await FileSystemEntity.type(destination, followLinks: false) !=
          FileSystemEntityType.notFound) {
        return const CapabilityFailure('collision', 'Revision already exists.');
      }
      final staging = await directory.createTemp('.pending-');
      try {
        await File('${staging.path}/probe.json')
            .writeAsBytes(probe.encode(), flush: true);
        await _publishDirectory(staging, destination);
        return const CapabilitySuccess(null);
      } finally {
        // Only this operation's unpublished directory is removed. Committed
        // revisions and interrupted runs from other invocations are preserved.
        if (await staging.exists()) await staging.delete(recursive: true);
      }
    });
  }

  Future<CapabilityResult<T>> _guard<T>(
    Future<CapabilityResult<T>> Function(Directory directory) action,
  ) async {
    String? key;
    RandomAccessFile? lock;
    try {
      final directory = await _resolveRoot();
      key = directory.path;
      if (!_activeRoots.add(key)) {
        key = null;
        return const CapabilityFailure('busy', 'A probe operation is running.');
      }
      await _ensureOwnedRoot(directory);
      final lockPath = '${directory.path}/.probe-lock';
      final lockType = await FileSystemEntity.type(
        lockPath,
        followLinks: false,
      );
      if (lockType != FileSystemEntityType.notFound &&
          lockType != FileSystemEntityType.file) {
        throw const FileSystemException('Unsafe probe lock');
      }
      lock = await File(lockPath).open(mode: FileMode.append);
      // OS lock supplements the per-process guard for independent processes.
      await lock.lock(FileLock.exclusive);
      return await action(directory);
    } on FileSystemException {
      return const CapabilityFailure(
        'storage_failure',
        'Isolated synthetic storage is unavailable or unsafe.',
      );
    } on FormatException {
      return const CapabilityFailure(
        'invalid_synthetic_input',
        'Stored synthetic probe is invalid; existing files were preserved.',
      );
    } finally {
      try {
        await lock?.close();
      } finally {
        if (key != null) _activeRoots.remove(key);
      }
    }
  }

  Future<Directory> _resolveRoot() async {
    final normalized = root.absolute.uri.normalizePath();
    final segments = normalized.pathSegments
        .where((s) => s.isNotEmpty)
        .toList();
    if (segments.isEmpty || segments.last != rootName) {
      throw const FileSystemException('Development probe root required');
    }
    // Resolving the parent permits system aliases such as macOS /var ->
    // /private/var. Links within the owned probe root are never followed.
    final parent = await root.absolute.parent.resolveSymbolicLinks();
    final parentSegments = Directory(parent).uri.pathSegments;
    if (parentSegments.any(
      (segment) => RegExp(
        r'^(daftar|com\.daftar(?:\..*)?)$',
        caseSensitive: false,
      ).hasMatch(segment),
    )) {
      throw const FileSystemException('Legacy app root forbidden');
    }
    return Directory('$parent/$rootName');
  }

  Future<void> _ensureOwnedRoot(Directory directory) async {
    final type = await FileSystemEntity.type(
      directory.path,
      followLinks: false,
    );
    if (type == FileSystemEntityType.notFound) {
      await directory.create();
    } else if (type != FileSystemEntityType.directory) {
      throw const FileSystemException('Unsafe probe root');
    }
    final marker = File('${directory.path}/$_markerName');
    final markerType = await FileSystemEntity.type(
      marker.path,
      followLinks: false,
    );
    if (markerType == FileSystemEntityType.notFound) {
      if (await directory.list(followLinks: false).isEmpty) {
        await marker.writeAsString(_markerValue, flush: true);
      } else {
        throw const FileSystemException('Unowned directory');
      }
    } else if (markerType != FileSystemEntityType.file ||
        await marker.length() != _markerValue.length ||
        await marker.readAsString() != _markerValue) {
      throw const FileSystemException('Invalid development ownership marker');
    }
  }

  Future<({int number, SyntheticProbe? probe})> _latest(
    Directory directory,
  ) async {
    var number = 0;
    Directory? latest;
    await for (final entry in directory.list(followLinks: false)) {
      final name = entry.path.split(Platform.pathSeparator).last;
      if (!name.startsWith('revision-')) continue;
      final match = RegExp(r'^revision-(\d{10})$').firstMatch(name);
      if (match == null || entry is! Directory) {
        throw const FileSystemException('Unsafe committed revision');
      }
      final candidate = int.parse(match.group(1)!);
      if (candidate > number) {
        number = candidate;
        latest = entry;
      }
    }
    if (latest == null) return (number: 0, probe: null);
    final file = File('${latest.path}/probe.json');
    if (await FileSystemEntity.type(file.path, followLinks: false) !=
        FileSystemEntityType.file) {
      throw const FileSystemException('Unsafe committed payload');
    }
    final handle = await file.open();
    try {
      final bytes = await handle.read(SyntheticProbe.maxBytes + 1);
      final decoded = SyntheticProbe.decode(Uint8List.fromList(bytes));
      if (decoded case CapabilitySuccess<SyntheticProbe>(:final value)) {
        return (number: number, probe: value);
      }
      throw const FormatException('Invalid committed synthetic payload');
    } finally {
      await handle.close();
    }
  }
}
