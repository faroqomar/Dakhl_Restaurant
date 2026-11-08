import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart' show sha256;
import 'package:dakhl_restaurant/accounts/accounts_repository.dart';
import 'package:dakhl_restaurant/accounts/accounts_view_model.dart';
import 'package:dakhl_restaurant/accounts/legacy_account_codec.dart';
import 'package:dakhl_restaurant/accounts/workspace_document.dart';
import 'package:dakhl_restaurant/app/accounts_store.dart';
import 'package:flutter/foundation.dart';
import 'package:madar_application/madar_application.dart';
import 'package:madar_data/madar_data.dart';
import 'package:madar_flutter_adapters/madar_flutter_adapters.dart';
import 'package:path/path.dart' as p;

/// Synthetic schema11 data; padding belongs only to recognized transaction notes.
final class C0ImportBoundaryBytes {
  C0ImportBoundaryBytes._(this.exact, this.baseBytes, this.noteBytes);
  final Uint8List exact;
  final int baseBytes, noteBytes;
  static const transactionCount = 10000, maxNoteBytes = 2000;
  Uint8List get oversized => Uint8List(exact.length + 1)
    ..setRange(0, exact.length, exact)
    ..[exact.length] = 10;

  static C0ImportBoundaryBytes build() {
    const codec = LegacyAccountCodec();
    final raw = Map<String, Object?>.from(codec.empty().toJson());
    final rows = List.generate(
      transactionCount,
      (index) => <String, Object?>{
        'id': 'c0_boundary_${index.toString().padLeft(5, '0')}',
        'date': '2026-11-08',
        'type': 'deposit',
        'amount': 1,
        'note': '',
        'createdAt': '2026-11-08T00:00:00.000Z',
      },
    );
    raw['transactions'] = rows;
    final base = codec.encode(codec.decodeJson(raw)).length;
    final padding = LegacyAccountCodec.maxPayloadBytes - base;
    _require(
      padding >= 0 && padding <= transactionCount * maxNoteBytes,
      'fixture_note_capacity',
    );
    var remaining = padding;
    for (final row in rows) {
      final length = remaining.clamp(0, maxNoteBytes);
      row['note'] = 'n' * length;
      remaining -= length;
    }
    _require(remaining == 0, 'fixture_padding_incomplete');
    final exact = codec.encode(codec.decodeJson(raw));
    _require(
      exact.length == LegacyAccountCodec.maxPayloadBytes,
      'fixture_exact_length',
    );
    _require(
      listEquals(codec.encode(codec.decodeBytes(exact)), exact),
      'fixture_not_byte_canonical',
    );
    return C0ImportBoundaryBytes._(exact, base, padding);
  }
}

/// Opt-in native QA ownership. No default/production account-location factory.
/// A fresh UUID owns one case and never resumes or overwrites an older root.
final class C0ImportBoundaryFixture {
  C0ImportBoundaryFixture._(
    this.namespace,
    this.root,
    this.fixtureId,
    this.stage,
    this.store,
    this.model,
    this._closeResources,
    this._beforeClose,
    this._beforeRootDelete,
    this._ioZone,
  );
  static const _namespaceOwner = 'dakhl-c0-import-boundary-namespace-v1\n';
  static const _rootOwner = 'dakhl-c0-import-boundary-fixture-v1\n';
  static const stages = [
    'cancel-open',
    'exact-cancel',
    'oversize',
    'exact-confirm',
  ];
  final Directory namespace, root;
  final String fixtureId, stage;
  final AppAccountsStore store;
  final AccountsViewModel model;
  final Zone _ioZone;
  final Set<String> _metadataTemps = {};
  final Future<void> Function() _closeResources;
  final Future<void> Function()? _beforeClose, _beforeRootDelete;
  Future<void>? _closing, _cleaning;
  bool _shutdownRequested = false, _cleanupComplete = false;
  bool _rootVerified = false, _rootRemoved = false;
  int _activeOperations = 0;
  C0ImportBoundaryBytes? _bytes;
  Map<String, Object?>? _before;
  CapabilityResult<Uint8List>? openResult;
  bool sawImportReady = false, _closed = false, _opening = false;
  int selectionCount = 0, confirmationCount = 0, errorDialogCount = 0;
  final List<Map<String, Object?>> _events = [];
  Directory get target => Directory(p.join(root.path, 'target'));
  File get exactFile =>
      File(p.join(root.path, 'picker-inputs', 'exact-20971520.json'));
  File get oversizedFile =>
      File(p.join(root.path, 'picker-inputs', 'oversize-20971521.json'));
  File get _marker => File(p.join(root.path, '.c0-import-boundary-owner'));
  File get _intent => File(p.join(namespace.path, '$fixtureId.intent.json'));

  static Future<C0ImportBoundaryFixture> open({
    required Directory namespace,
    required String fixtureId,
    required String stage,
    @visibleForTesting Future<void> Function()? beforeClose,
    @visibleForTesting Future<void> Function()? beforeRootDelete,
  }) async {
    _require(
      RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
      ).hasMatch(fixtureId),
      'invalid_fixture_id',
    );
    _require(stages.contains(stage), 'invalid_stage');
    await _safeDirectory(namespace, create: true);
    final owner = File(p.join(namespace.path, '.c0-import-boundary-namespace'));
    if (await _regularExists(owner)) {
      _require(
        await owner.readAsString() == _namespaceOwner,
        'unknown_namespace',
      );
    } else {
      _require(await namespace.list().isEmpty, 'unmarked_namespace');
      await _exclusiveText(owner, _namespaceOwner);
    }
    final root = Directory(p.join(namespace.path, fixtureId));
    final intent = File(p.join(namespace.path, '$fixtureId.intent.json'));
    _require(
      await FileSystemEntity.type(root.path, followLinks: false) ==
          FileSystemEntityType.notFound,
      'fixture_already_exists',
    );
    await _exclusiveText(
      intent,
      jsonEncode({
        'schema': 1,
        'fixtureId': fixtureId,
        'stage': stage,
        'status': 'allocated',
      }),
    );
    await root.create();
    await _exclusiveText(
      File(p.join(root.path, '.c0-import-boundary-owner')),
      '$_rootOwner$fixtureId\n',
    );
    final target = Directory(p.join(root.path, 'target'));
    await target.create();
    PowerSyncLocalDocumentWorkspaceStore? nativeOwner;
    final store = AppAccountsStore(
      openStore: () async {
        final result = await PowerSyncLocalDocumentWorkspaceStore.open(
          directoryPath: target.path,
        );
        if (result is CapabilitySuccess<PowerSyncLocalDocumentWorkspaceStore>) {
          nativeOwner = result.value;
        }
        return result;
      },
    );
    final model = AccountsViewModel(
      repository: AccountsRepository(store: store),
    );
    final fixture = C0ImportBoundaryFixture._(
      namespace,
      root,
      fixtureId,
      stage,
      store,
      model,
      () async {
        // Retain the native owner's retryable close even if the wrapper's
        // close Future fails. Mark the facade closed after handles release.
        await nativeOwner?.close();
        await store.close();
      },
      beforeClose,
      beforeRootDelete,
      Zone.current,
    );
    try {
      await model.initialize();
      _require(model.state == AccountsState.absent, 'target_not_absent');
      const codec = LegacyAccountCodec();
      final raw = Map<String, Object?>.from(codec.empty().toJson());
      final prefs = Map<String, Object?>.from(raw['preferences']! as Map);
      prefs['restaurant'] = {
        'name': 'C0 synthetic $fixtureId',
        'contact': '',
        'footer': '',
      };
      raw['preferences'] = prefs;
      model.prepareImport(codec.encode(codec.decodeJson(raw)));
      await model.confirmImport();
      _require(model.state == AccountsState.saved, 'target_initial_save');
      // Ensure the baseline includes an independently readable previous copy.
      await model.save();
      await model.saveWorkspace(
        WorkspaceDocument(
          active: {'note': 'C0 retained input $fixtureId'},
          form: {'fixture': fixtureId},
          held: const [],
        ),
        model.fence!,
      );
      _require(model.state == AccountsState.saved, 'target_workspace_save');
      _require(model.pendingImport == null, 'old_pending_import');
      model.addListener(fixture._observe);
      fixture._before = await fixture._authority();
      _require(
        fixture._before!['previous'] != null,
        'baseline_previous_missing',
      );
      await fixture._writeReceipt('prepared', {'before': fixture._before});
      return fixture;
    } on Object {
      await fixture.close();
      rethrow;
    }
  }

  void _observe() {
    if (model.state == AccountsState.importReady &&
        model.pendingImport != null) {
      sawImportReady = true;
    }
  }

  /// The host selects these regular files in the actual native picker.
  /// NativeFileTransfer.save cannot stage the oversized sibling: its cap is L.
  Future<Map<String, Object?>> stagePickerFiles() =>
      _duringOperation(_stagePickerFiles);

  Future<Map<String, Object?>> _stagePickerFiles() async {
    _require(!_closed && !_opening && _bytes == null, 'staging_unavailable');
    _require(selectionCount == 0, 'selection_already_started');
    final bytes = C0ImportBoundaryBytes.build();
    final directory = exactFile.parent;
    _require(
      await FileSystemEntity.type(directory.path, followLinks: false) ==
          FileSystemEntityType.notFound,
      'staging_already_exists',
    );
    await directory.create();
    await exactFile.create(exclusive: true);
    await exactFile.writeAsBytes(bytes.exact, flush: true);
    await oversizedFile.create(exclusive: true);
    final sink = oversizedFile.openWrite();
    sink.add(bytes.exact);
    sink.add(const [10]);
    await sink.flush();
    await sink.close();
    _bytes = bytes;
    await _requireSourceIdentity();
    final receipt = {
      'baseBytes': bytes.baseBytes,
      'noteBytes': bytes.noteBytes,
      'transactions': C0ImportBoundaryBytes.transactionCount,
      'exact': await _fileReceipt(exactFile),
      'oversized': await _fileReceipt(oversizedFile),
      'staging': 'regular owned files; native save adapter not used',
      'hostSha256': 'capture from these exact paths before native selection',
      'providerLimit': 'provider may materialize full input before Dart reads',
    };
    await _writeReceipt('staged', receipt);
    return receipt;
  }

  /// Native QA always delegates to the actual capped default picker.
  FileTransferCapability nativeTransfer() => _ObservedNativeTransfer(
    this,
    NativeFileTransfer(
      maxBytes: LegacyAccountCodec.maxPayloadBytes,
      fileName: 'c0-boundary-$fixtureId.json',
      mimeType: 'application/json',
    ),
  );

  @visibleForTesting
  FileTransferCapability transferForTest(FileTransferCapability delegate) =>
      _ObservedNativeTransfer(this, delegate);

  Future<T> _duringOperation<T>(Future<T> Function() action) async {
    _require(!_shutdownRequested && !_closed, 'fixture_closed');
    _require(!_opening && _activeOperations == 0, 'operation_in_flight');
    _activeOperations++;
    try {
      return await _ioZone.run(action);
    } finally {
      _activeOperations--;
    }
  }

  void recordPopup() {
    if (model.state == AccountsState.importReady &&
        model.pendingImport != null) {
      confirmationCount++;
    } else if (model.state == AccountsState.failed) {
      errorDialogCount++;
    }
  }

  Future<void> _beginOpen() async {
    _require(!_shutdownRequested && !_closed, 'fixture_closed');
    _require(!_opening && selectionCount == 0, 'one_selection_per_case');
    _require(
      model.pendingImport == null && model.recoverySelection == null,
      'old_pending_import',
    );
    _require(stage == 'cancel-open' || _bytes != null, 'stage_files_first');
    _require(
      _same(await _authority(), _before),
      'baseline_changed_before_picker',
    );
    if (_bytes != null) await _requireSourceIdentity();
    _opening = true;
    selectionCount++;
    await _writeReceipt('before-native-open', {'authority': _before});
  }

  Future<void> _finishOpen(CapabilityResult<Uint8List> result) async {
    openResult = result;
    try {
      if (result is CapabilitySuccess<Uint8List>) {
        _require(
          _bytes != null && listEquals(result.value, _bytes!.exact),
          'selected_unexpected_bytes',
        );
      }
      await _writeReceipt('native-open-result', {
        'result': result is CapabilitySuccess<Uint8List>
            ? 'selected'
            : result is CapabilityFailure<Uint8List>
            ? result.code
            : 'cancelled',
        'selectedBytes': result is CapabilitySuccess<Uint8List>
            ? result.value.length
            : null,
        'authorityUnchanged': _same(await _authority(), _before),
      });
    } finally {
      _opening = false;
    }
  }

  /// Call after the operator dismisses the real dialog, or confirms explicitly.
  Future<Map<String, Object?>> verify() => _duringOperation(_verify);

  Future<Map<String, Object?>> _verify() async {
    _require(
      !_closed && !_opening && !model.busy && selectionCount == 1,
      'selection_not_settled',
    );
    if (_bytes != null) await _requireSourceIdentity();
    final actual = await _authority();
    final unchanged = _same(actual, _before);
    if (stage == 'oversize') {
      _require(
        openResult is CapabilityFailure<Uint8List> &&
            (openResult as CapabilityFailure<Uint8List>).code ==
                'input_too_large',
        'oversize_wrong_outcome',
      );
      _require(
        model.state == AccountsState.failed &&
            model.failureCode == 'input_too_large' &&
            model.pendingImport == null &&
            !sawImportReady &&
            confirmationCount == 0,
        'oversize_reached_confirmation',
      );
      _require(unchanged, 'oversize_changed_authority');
    } else if (stage == 'cancel-open') {
      _require(
        openResult is CapabilityCancelled<Uint8List> &&
            model.state == AccountsState.saved &&
            model.pendingImport == null &&
            !sawImportReady &&
            confirmationCount == 0 &&
            unchanged,
        'cancel_open_changed_state',
      );
    } else {
      _require(
        openResult is CapabilitySuccess<Uint8List> &&
            sawImportReady &&
            confirmationCount == 1 &&
            model.pendingImport == null &&
            model.state == AccountsState.saved,
        'exact_confirmation_not_settled',
      );
      if (stage == 'exact-cancel') {
        _require(unchanged, 'cancel_confirmation_changed_authority');
      } else {
        _require(
          !unchanged && listEquals(model.exportBytes(), _bytes!.exact),
          'confirmed_payload_mismatch',
        );
        final previous = (actual['previous']! as Map)['snapshot'];
        _require(
          _same(previous, _before!['document']),
          'prior_backup_mismatch',
        );
        _require(
          !_same(
            (actual['document']! as Map)['fence'],
            (_before!['document']! as Map)['fence'],
          ),
          'replacement_fence_unchanged',
        );
        _require(
          model.workspace.encode() == WorkspaceDocument.empty().encode(),
          'replacement_workspace_not_reset',
        );
        final archive = Directory(p.join(target.path, 'sources'));
        var exactArchived = false;
        await for (final entry in archive.list(followLinks: false)) {
          if (entry is File &&
              !entry.path.endsWith('.meta.json') &&
              await entry.length() == _bytes!.exact.length &&
              await _matches(entry, _bytes!.exact)) {
            exactArchived = true;
          }
        }
        _require(exactArchived, 'import_source_not_archived');
      }
    }
    final receipt = <String, Object?>{
      'stage': stage,
      'verified': true,
      'authorityUnchanged': unchanged,
      'sawImportReady': sawImportReady,
      'confirmationCount': confirmationCount,
      'errorDialogCount': errorDialogCount,
      'state': model.state.name,
      'failureCode': model.failureCode,
      'after': stage == 'exact-confirm'
          ? {
              'document': await _documentReceipt(),
              'previousMatchesBaseline': true,
            }
          : actual,
    };
    await _writeReceipt('verified', receipt);
    return receipt;
  }

  Future<Map<String, Object?>> _documentReceipt() async {
    final snapshot = model.repository.snapshot!;
    return {
      'payloadBytes': utf8.encode(snapshot.payload).length,
      'revision': snapshot.revision,
      'writeToken': snapshot.writeToken,
      'fence': _fence(snapshot.fence),
    };
  }

  Future<Map<String, Object?>> _authority() async {
    final read = await store.readDocument();
    _require(
      read is CapabilitySuccess<DocumentSnapshot?> && read.value != null,
      'document_read_failed',
    );
    final snapshot = (read as CapabilitySuccess<DocumentSnapshot?>).value!;
    final workspace = await store.readWorkspace(snapshot.fence);
    _require(
      workspace is CapabilitySuccess<WorkspaceState>,
      'workspace_read_failed',
    );
    final ws = (workspace as CapabilitySuccess<WorkspaceState>).value;
    final previous = await store.readPrevious();
    _require(
      previous is CapabilitySuccess<PreviousDocument?>,
      'previous_read_failed',
    );
    final old = (previous as CapabilitySuccess<PreviousDocument?>).value;
    final files = <String, Object?>{};
    for (final name in [
      'active.json',
      'previous.json',
      'sources',
      'identities',
    ]) {
      final path = p.join(target.path, name);
      final type = await FileSystemEntity.type(path, followLinks: false);
      if (type == FileSystemEntityType.notFound) continue;
      if (type == FileSystemEntityType.file) {
        files[name] = await _streamedIdentity(File(path));
      } else {
        _require(
          type == FileSystemEntityType.directory,
          'unsafe_authority_artifact',
        );
        await for (final file in Directory(
          path,
        ).list(recursive: true, followLinks: false)) {
          _require(file is File, 'unsafe_authority_archive');
          files[p.relative(file.path, from: target.path)] =
              await _streamedIdentity(file as File);
        }
      }
    }
    final sorted = Map.fromEntries(
      files.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
    );
    return {
      'document': _snapshot(snapshot),
      'workspace': ws.snapshot == null
          ? null
          : {
              'payload': ws.snapshot!.payload,
              'revision': ws.snapshot!.revision,
              'writeToken': ws.snapshot!.writeToken,
              'fence': _fence(ws.snapshot!.fence),
            },
      'viewWorkspace': model.workspace.encode(),
      'previous': old == null
          ? null
          : {'identity': old.identity, 'snapshot': _snapshot(old.snapshot)},
      'sourceAndAuthorityFiles': sorted,
    };
  }

  Future<void> _requireSourceIdentity() async {
    _require(await _matches(exactFile, _bytes!.exact), 'exact_source_changed');
    _require(
      await _matches(oversizedFile, _bytes!.exact, trailingLf: true),
      'oversize_source_changed',
    );
  }

  Future<void> _writeReceipt(String event, Map<String, Object?> data) async {
    final receipt = <String, Object?>{
      'schema': 1,
      'fixtureId': fixtureId,
      'stage': stage,
      'event': event,
      'utc': DateTime.now().toUtc().toIso8601String(),
      ...data,
    };
    await _exclusiveText(
      File(p.join(root.path, '$event.json')),
      jsonEncode(receipt),
    );
    _events.add(receipt);
  }

  @visibleForTesting
  Future<Map<String, Object?>> captureAuthority() =>
      _duringOperation(_authority);

  @visibleForTesting
  Future<void> assertAuthorityUnchanged() => _duringOperation(() async {
    _require(_same(await _authority(), _before), 'authority_changed');
  });

  void beginShutdown() {
    if (_closed || _shutdownRequested) return;
    _require(
      !_opening && !model.busy && _activeOperations == 0,
      'native_operation_in_flight',
    );
    _shutdownRequested = true;
  }

  Future<void> close() {
    if (_closed) return Future<void>.value();
    beginShutdown();
    final pending = _closing;
    if (pending != null) return pending;
    final attempt = _ioZone.run<Future<void>>(_closeAttempt);
    _closing = attempt;
    return attempt;
  }

  Future<void> _closeAttempt() async {
    try {
      await _beforeClose?.call();
      await _closeResources();
      model.removeListener(_observe);
      model.dispose();
      _closed = true;
    } catch (_) {
      _closing = null;
      rethrow;
    }
  }

  Future<void> cleanup() {
    if (_cleanupComplete) return Future<void>.value();
    beginShutdown();
    final pending = _cleaning;
    if (pending != null) return pending;
    final attempt = _ioZone.run<Future<void>>(_cleanupAttempt);
    _cleaning = attempt;
    return attempt;
  }

  Future<void> _publishMetadata(File destination, String text) async {
    final temporary = File('${destination.path}.cleanup-pending');
    if (await _regularExists(temporary)) {
      _require(_metadataTemps.contains(temporary.path), 'unknown_cleanup_temp');
    } else {
      _metadataTemps.add(temporary.path);
      await temporary.create(exclusive: true);
    }
    await temporary.writeAsString(text, flush: true);
    await temporary.rename(destination.path);
    _metadataTemps.remove(temporary.path);
  }

  Future<void> _cleanupAttempt() async {
    try {
      await close();
      await _safeDirectory(namespace);
      final owner = File(
        p.join(namespace.path, '.c0-import-boundary-namespace'),
      );
      _require(
        await _regularExists(owner) &&
            await owner.readAsString() == _namespaceOwner,
        'unknown_namespace',
      );
      _require(await _regularExists(_intent), 'intent_missing');
      final intent = jsonDecode(await _intent.readAsString()) as Map;
      _require(
        intent['fixtureId'] == fixtureId && intent['stage'] == stage,
        'unknown_fixture_intent',
      );
      if (!_rootRemoved) {
        final rootType = await FileSystemEntity.type(
          root.path,
          followLinks: false,
        );
        _require(
          rootType == FileSystemEntityType.directory ||
              rootType == FileSystemEntityType.notFound,
          'unsafe_cleanup_root',
        );
        if (rootType == FileSystemEntityType.directory) {
          await _safeDirectory(root);
          final entries = await root.list(followLinks: false).toList();
          if (await _regularExists(_marker)) {
            _require(
              await _marker.readAsString() == '$_rootOwner$fixtureId\n',
              'unknown_fixture_owner',
            );
            _rootVerified = true;
          } else {
            _require(_rootVerified && entries.isEmpty, 'unknown_fixture_owner');
          }
          await for (final entry in root.list(
            recursive: true,
            followLinks: false,
          )) {
            _require(
              entry is File || entry is Directory,
              'unsafe_cleanup_entry',
            );
          }
          // Keep the marker until payload deletion succeeds. A partial failure
          // can retry without discarding proof of ownership.
          for (final entry in entries) {
            if (entry.path == _marker.path) continue;
            await entry.delete(recursive: entry is Directory);
          }
          if (await _regularExists(_marker)) await _marker.delete();
          await _beforeRootDelete?.call();
          await root.delete();
        } else {
          _require(_rootVerified, 'unknown_fixture_root_missing');
        }
        _rootRemoved = true;
      }
      final closeout = File(p.join(namespace.path, '$fixtureId.closeout.json'));
      final text = jsonEncode({
        'schema': 1,
        'fixtureId': fixtureId,
        'stage': stage,
        'events': _events,
        'cleanup': 'owned root removed',
      });
      if (await _regularExists(closeout)) {
        _require(await closeout.readAsString() == text, 'closeout_conflict');
      } else {
        await _publishMetadata(closeout, text);
      }
      await _publishMetadata(
        _intent,
        jsonEncode({
          'schema': 1,
          'fixtureId': fixtureId,
          'stage': stage,
          'status': 'cleaned',
        }),
      );
      _bytes = null;
      _cleanupComplete = true;
    } catch (_) {
      _cleaning = null;
      rethrow;
    }
  }
}

final class _ObservedNativeTransfer implements FileTransferCapability {
  _ObservedNativeTransfer(this.fixture, this.delegate);
  final C0ImportBoundaryFixture fixture;
  final FileTransferCapability delegate;
  @override
  Future<CapabilityResult<Uint8List>> open() async {
    await fixture._beginOpen();
    try {
      final result = await delegate.open();
      await fixture._finishOpen(result);
      return result;
    } finally {
      // A throwing picker must release the QA lifecycle interlock as well.
      fixture._opening = false;
    }
  }

  @override
  Future<CapabilityResult<void>> save(Uint8List bytes) async =>
      const CapabilityFailure(
        'qa_export_disabled',
        'This case exercises import only.',
      );
}

Map<String, Object?> _fence(StorageFence fence) => {
  'storeId': fence.storeId,
  'generation': fence.generation,
};
Map<String, Object?> _snapshot(DocumentSnapshot snapshot) => {
  'payload': snapshot.payload,
  'revision': snapshot.revision,
  'writeToken': snapshot.writeToken,
  'fence': _fence(snapshot.fence),
};
bool _same(Object? a, Object? b) => jsonEncode(a) == jsonEncode(b);
void _require(bool condition, String code) {
  if (!condition) throw C0ImportBoundaryException(code);
}

final class C0ImportBoundaryException implements Exception {
  const C0ImportBoundaryException(this.code);
  final String code;
  @override
  String toString() => 'C0ImportBoundaryException($code)';
}

Future<void> _exclusiveText(File file, String text) async {
  await file.create(exclusive: true);
  await file.writeAsString(text, flush: true);
}

Future<bool> _regularExists(File file) async {
  final type = await FileSystemEntity.type(file.path, followLinks: false);
  _require(
    type == FileSystemEntityType.notFound || type == FileSystemEntityType.file,
    'unsafe_file',
  );
  return type == FileSystemEntityType.file;
}

Future<void> _safeDirectory(Directory directory, {bool create = false}) async {
  final type = await FileSystemEntity.type(directory.path, followLinks: false);
  _require(
    type == FileSystemEntityType.directory ||
        (create && type == FileSystemEntityType.notFound),
    'unsafe_directory',
  );
  if (type == FileSystemEntityType.notFound) await directory.create();
  _require(
    await directory.resolveSymbolicLinks() == directory.path,
    'symlink_directory',
  );
}

Future<bool> _matches(
  File file,
  List<int> exact, {
  bool trailingLf = false,
}) async {
  if (!await _regularExists(file) ||
      await file.length() != exact.length + (trailingLf ? 1 : 0)) {
    return false;
  }
  var offset = 0;
  await for (final chunk in file.openRead()) {
    for (final byte in chunk) {
      if (offset < exact.length ? byte != exact[offset] : byte != 10) {
        return false;
      }
      offset++;
    }
  }
  return offset == exact.length + (trailingLf ? 1 : 0);
}

Future<Map<String, Object?>> _fileReceipt(File file) async => {
  'path': file.path,
  ...await _streamedIdentity(file),
};

Future<Map<String, Object?>> _streamedIdentity(File file) async {
  final before = await file.length();
  final digest = await sha256.bind(file.openRead()).first;
  _require(await file.length() == before, 'authority_file_changed_during_read');
  return {'bytes': before, 'sha256': digest.toString()};
}
