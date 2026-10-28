import 'dart:async';
import 'dart:io';

import 'package:dakhl_restaurant/capabilities/capability_contracts.dart';
import 'package:dakhl_restaurant/capabilities/isolated_probe_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory temporary;
  late Directory root;
  const first = SyntheticProbe(message: 'تجربة 123', sequence: 1);
  const second = SyntheticProbe(message: 'تجربة 456', sequence: 2);

  setUp(() async {
    temporary = await Directory.systemTemp.createTemp('phase00-contract-');
    root = Directory('${temporary.path}/${IsolatedProbeRepository.rootName}');
  });
  tearDown(() async => temporary.delete(recursive: true));

  test(
    'writes only synthetic isolated output and discovers latest on reopen',
    () async {
      final unrelated = File('${temporary.path}/accounts.json');
      await unrelated.writeAsString('untouched');
      final repository = IsolatedProbeRepository(root);
      expect(await repository.write(first), isA<CapabilitySuccess<void>>());
      expect(await repository.write(second), isA<CapabilitySuccess<void>>());
      final reopened = await IsolatedProbeRepository(root).read();
      expect((reopened as CapabilitySuccess<SyntheticProbe>).value.sequence, 2);
      expect(await unrelated.readAsString(), 'untouched');
      expect(await _committedCount(root), 2);
    },
  );

  test(
    'repeating the same write after reopen does not create duplicates',
    () async {
      await IsolatedProbeRepository(root).write(first);
      expect(
        await IsolatedProbeRepository(root).write(first),
        isA<CapabilitySuccess<void>>(),
      );
      expect(await _committedCount(root), 1);
    },
  );

  test('committed synthetic output survives a separate Dart process', () async {
    final contracts = File('lib/capabilities/capability_contracts.dart')
        .absolute
        .uri;
    final storage = File('lib/capabilities/isolated_probe_repository.dart')
        .absolute
        .uri;
    final child = File('${temporary.path}/writer.dart');
    await child.writeAsString('''
import 'dart:io';
import '$contracts';
import '$storage';
Future<void> main(List<String> arguments) async {
  final result = await IsolatedProbeRepository(Directory(arguments.single))
    .write(const SyntheticProbe(message: 'اختبار عملية منفصلة 73', sequence: 73));
  if (result is! CapabilitySuccess<void>) exitCode = 2;
}
''');
    final result = await Process.run('dart', [
      '--packages=${File('.dart_tool/package_config.json').absolute.path}',
      child.path,
      root.path,
    ], workingDirectory: temporary.path);
    expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
    final reopened = await IsolatedProbeRepository(root).read();
    expect((reopened as CapabilitySuccess<SyntheticProbe>).value.sequence, 73);
    expect(await _committedCount(root), 1);
  });

  test(
    'concurrent repositories cannot publish overlapping revisions',
    () async {
      final started = Completer<void>();
      final release = Completer<void>();
      final repository = IsolatedProbeRepository(
        root,
        publishDirectory: (staging, destination) async {
          started.complete();
          await release.future;
          return staging.rename(destination);
        },
      );
      final writing = repository.write(first);
      await started.future;
      final overlapping = await IsolatedProbeRepository(root).write(second);
      expect((overlapping as CapabilityFailure<void>).code, 'busy');
      release.complete();
      expect(await writing, isA<CapabilitySuccess<void>>());
      expect(await _committedCount(root), 1);
      expect(
        await IsolatedProbeRepository(root).write(second),
        isA<CapabilitySuccess<void>>(),
      );
      expect(await _committedCount(root), 2);
    },
  );

  test(
    'actual read-only lock denies a write while preserving committed bytes',
    () async {
      final repository = IsolatedProbeRepository(root);
      await repository.write(first);
      final before = await _allCommittedBytes(root);
      final lockPath = '${root.path}/.probe-lock';
      expect((await Process.run('chmod', ['400', lockPath])).exitCode, 0);
      try {
        expect(await repository.write(second), isA<CapabilityFailure<void>>());
        expect(await _allCommittedBytes(root), before);
      } finally {
        expect((await Process.run('chmod', ['600', lockPath])).exitCode, 0);
      }
      expect(await repository.write(second), isA<CapabilitySuccess<void>>());
      expect(await _committedCount(root), 2);
    },
    skip: Platform.isWindows,
  );

  test(
    'denied publication preserves old committed bytes and retry succeeds',
    () async {
      var denied = false;
      final repository = IsolatedProbeRepository(
        root,
        publishDirectory: (staging, destination) {
          if (denied) {
            throw FileSystemException(
              'Permission denied',
              destination,
              const OSError('denied', 13),
            );
          }
          return staging.rename(destination);
        },
      );
      await repository.write(first);
      final before = await _allCommittedBytes(root);
      denied = true;
      final failed = await repository.write(second);
      expect(failed, isA<CapabilityFailure<void>>());
      expect(await _allCommittedBytes(root), before);
      expect(
        (await repository.read() as CapabilitySuccess<SyntheticProbe>)
            .value
            .sequence,
        1,
      );
      denied = false;
      expect(await repository.write(second), isA<CapabilitySuccess<void>>());
      expect(await repository.write(second), isA<CapabilitySuccess<void>>());
      expect(await _committedCount(root), 2);
    },
  );

  test(
    'retry after publication but lost acknowledgement never duplicates output',
    () async {
      var loseAcknowledgement = true;
      final repository = IsolatedProbeRepository(
        root,
        publishDirectory: (staging, destination) async {
          final committed = await staging.rename(destination);
          if (loseAcknowledgement) {
            throw const FileSystemException(
              'Process response interrupted after commit',
            );
          }
          return committed;
        },
      );
      expect(await repository.write(first), isA<CapabilityFailure<void>>());
      expect(await _committedCount(root), 1);
      loseAcknowledgement = false;
      expect(await repository.write(first), isA<CapabilitySuccess<void>>());
      expect(await _committedCount(root), 1);
      expect(
        (await repository.read() as CapabilitySuccess<SyntheticProbe>)
            .value
            .sequence,
        1,
      );
    },
  );

  test('ignores unpublished crash staging but fails closed on corrupt committed latest', () async {
    final repository = IsolatedProbeRepository(root);
    await repository.write(first);
    final interrupted = await Directory('${root.path}/.pending-crash').create();
    await File('${interrupted.path}/probe.json').writeAsString('incomplete');
    expect(
      (await IsolatedProbeRepository(root).read()
              as CapabilitySuccess<SyntheticProbe>)
          .value
          .sequence,
      1,
    );
    await repository.write(second);
    final committed = (await root.list().toList())
        .whereType<Directory>()
        .singleWhere(
          (d) =>
              d.uri.pathSegments.where((s) => s.isNotEmpty).last ==
              'revision-0000000002',
        );
    await File('${committed.path}/probe.json').writeAsString('corrupt');
    expect(await repository.read(), isA<CapabilityFailure<SyntheticProbe>>());
    expect(await repository.write(second), isA<CapabilityFailure<void>>());
    expect(await _committedCount(root), 2);
  });

  test('rejects unsafe roots and existing unowned directories without modifying them', () async {
    final productionLike = await Directory('${temporary.path}/Daftar').create();
    final account = File('${productionLike.path}/accounts.json');
    await account.writeAsString('real-looking sentinel, never parsed');
    expect(
      await IsolatedProbeRepository(productionLike).write(first),
      isA<CapabilityFailure<void>>(),
    );
    final nested = Directory(
      '${productionLike.path}/${IsolatedProbeRepository.rootName}',
    );
    expect(
      await IsolatedProbeRepository(nested).write(first),
      isA<CapabilityFailure<void>>(),
    );
    expect(await nested.exists(), isFalse);
    await root.create();
    final sentinel = File('${root.path}/accounts.json');
    await sentinel.writeAsString('unowned');
    expect(
      await IsolatedProbeRepository(root).write(first),
      isA<CapabilityFailure<void>>(),
    );
    expect(await sentinel.readAsString(), 'unowned');
    expect(await account.readAsString(), 'real-looking sentinel, never parsed');
    expect(await root.list().length, 1);
  });

  test('rejects symlink roots and committed payload symlinks', () async {
    final outside = await Directory('${temporary.path}/outside').create();
    await Link(root.path).create(outside.path);
    expect(
      await IsolatedProbeRepository(root).write(first),
      isA<CapabilityFailure<void>>(),
    );
    expect(await outside.list().length, 0);
    await Link(root.path).delete();
    final repository = IsolatedProbeRepository(root);
    await repository.write(first);
    final committed = (await root.list().toList())
        .whereType<Directory>()
        .single;
    final payload = File('${committed.path}/probe.json');
    await payload.delete();
    final sentinel = File('${outside.path}/sentinel');
    await sentinel.writeAsString('must not read or change');
    await Link(payload.path).create(sentinel.path);
    expect(await repository.read(), isA<CapabilityFailure<SyntheticProbe>>());
    expect(await repository.write(second), isA<CapabilityFailure<void>>());
    expect(await sentinel.readAsString(), 'must not read or change');
  });

  test('rejects invalid payload before creating any directory', () async {
    expect(
      await IsolatedProbeRepository(root)
          .write(const SyntheticProbe(message: '', sequence: 0)),
      isA<CapabilityFailure<void>>(),
    );
    expect(await root.exists(), isFalse);
  });
}

Future<int> _committedCount(Directory root) async =>
    (await root.list().toList())
        .whereType<Directory>()
        .where(
          (d) =>
              d.path.split(Platform.pathSeparator).last.startsWith('revision-'),
        )
        .length;

Future<List<String>> _allCommittedBytes(Directory root) async {
  final directories =
      (await root.list().toList())
          .whereType<Directory>()
          .where(
            (d) => d.path
                .split(Platform.pathSeparator)
                .last
                .startsWith('revision-'),
          )
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));
  return Future.wait(
    directories.map((d) => File('${d.path}/probe.json').readAsString()),
  );
}
