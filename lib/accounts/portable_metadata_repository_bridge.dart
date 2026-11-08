import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:madar_application/madar_application.dart';

import 'account_document.dart';
import 'portable_metadata_validation.dart';
import 'legacy_account_codec.dart';
import 'portable_journal_codec.dart';
import 'portable_journal_state.dart';

/// App-owned representation bridge for existing metadata ViewModels. It borrows
/// one Madar owner and never exposes a schema11 import/export/recovery surface.
/// Full-envelope persistence/CAS and uncertainty recovery remain store-owned;
/// AccountsRepository retains its existing token/payload reconciliation policy.
final class PortableMetadataRepositoryBridge extends ChangeNotifier
    implements LocalDocumentWorkspaceStore {
  PortableMetadataRepositoryBridge({
    required this.inner,
    required DocumentSnapshot snapshot,
    required this.isWriteBlocked,
    this.codec = const PortableJournalCodec(),
  }) : authorityFence = snapshot.fence,
       _complete = snapshot {
    final state = codec.decodeState(snapshot.payload);
    _lineage = state.accountLineage;
    _projection = _project(snapshot, state.account);
  }
  final LocalDocumentWorkspaceStore inner;
  final PortableJournalCodec codec;
  final bool Function() isWriteBlocked;
  final StorageFence authorityFence;
  late final String _lineage;
  DocumentSnapshot _complete;
  late DocumentSnapshot _projection;
  bool _busy = false, _unknown = false, _closed = false;
  int _notificationDepth = 0;
  bool get busy => _busy;
  bool get needsReadback => _unknown;
  DocumentSnapshot get snapshot => _complete;
  static const _legacy = LegacyAccountCodec();
  CapabilityFailure<T> _fail<T>(String code) =>
      CapabilityFailure(code, 'Metadata projection operation refused.');
  CapabilityResult<T> _cast<T>(CapabilityResult<dynamic> result) =>
      switch (result) {
        CapabilityFailure(:final code) => _fail(code),
        CapabilityCancelled() => const CapabilityCancelled(),
        _ => _fail('invalid_store_result'),
      };
  static bool _same(DocumentSnapshot a, DocumentSnapshot b) =>
      a.fence == b.fence &&
      a.revision == b.revision &&
      a.writeToken == b.writeToken &&
      a.payload == b.payload;
  DocumentSnapshot _project(DocumentSnapshot full, AccountDocument account) =>
      DocumentSnapshot(
        payload: utf8.decode(_legacy.encode(account)),
        revision: full.revision,
        fence: full.fence,
        writeToken: full.writeToken,
      );
  PortableJournalState _decode(DocumentSnapshot full) {
    if (full.fence != authorityFence) {
      throw const FormatException('stale_generation');
    }
    if (full.revision < _complete.revision ||
        (full.revision == _complete.revision && !_same(full, _complete))) {
      throw const FormatException('stale_revision');
    }
    final state = codec.decodeState(full.payload);
    if (state.accountLineage != _lineage) {
      throw const FormatException('account_lineage_mismatch');
    }
    return state;
  }

  void _accept(DocumentSnapshot full) {
    final state = _decode(full);
    if (_same(full, _complete)) return;
    final projection = _project(full, state.account);
    _complete = full;
    _projection = projection;
  }

  void _notify() {
    if (_closed) return;
    _notificationDepth++;
    try {
      notifyListeners();
    } finally {
      _notificationDepth--;
      if (_closed && _notificationDepth == 0) super.dispose();
    }
  }

  @override
  Future<CapabilityResult<DocumentSnapshot?>> readDocument() async {
    if (_closed) return _fail('disposed');
    try {
      final read = await inner.readDocument();
      if (read is! CapabilitySuccess<DocumentSnapshot?>) return _cast(read);
      if (read.value == null) return _fail('account_missing');
      final changed = !_same(read.value!, _complete);
      _accept(read.value!);
      if (changed) _notify();
      return CapabilitySuccess(_projection);
    } on FormatException catch (error) {
      return _fail(error.message);
    } on PortableJournalException catch (error) {
      return _fail(error.code);
    } on Object {
      return _fail('unavailable');
    }
  }

  /// Validate source-only edits without importing the Flutter repository bridge.
  static void validateMetadataChange(
    AccountDocument before,
    AccountDocument after,
  ) => validatePortableMetadataChange(before, after);

  @override
  Future<CapabilityResult<DocumentSnapshot>> writeDocument(
    String payload, {
    required String writeToken,
    DocumentSnapshot? expected,
    bool replaceGeneration = false,
  }) async {
    if (_closed) return _fail('disposed');
    if (_busy || isWriteBlocked()) return _fail('busy');
    if (_unknown) return _fail('commit_unknown');
    if (replaceGeneration || expected == null) {
      return _fail('metadata_replacement_refused');
    }
    if (!_same(expected, _projection)) return _fail('stale_revision');
    _busy = true;
    _notify();
    var attempted = false;
    try {
      final next = _legacy.decodeBytes(utf8.encode(payload));
      final read = await inner.readDocument();
      if (read is! CapabilitySuccess<DocumentSnapshot?>) return _cast(read);
      final actual = read.value;
      if (actual == null || !_same(actual, _complete)) {
        return _fail('stale_revision');
      }
      final state = _decode(actual);
      validateMetadataChange(state.account, next);
      final completePayload = codec.encodeState(state.copyWith(account: next));
      if (_closed) return _fail('disposed');
      if (isWriteBlocked()) return _fail('busy');
      attempted = true;
      final result = await inner.writeDocument(
        completePayload,
        writeToken: writeToken,
        expected: actual,
      );
      if (result case CapabilitySuccess<DocumentSnapshot>(:final value)) {
        if (value.fence != authorityFence ||
            value.revision != actual.revision + 1 ||
            value.payload != completePayload ||
            value.writeToken != writeToken) {
          _unknown = true;
          return _fail('commit_unknown');
        }
        _accept(value);
        return CapabilitySuccess(_projection);
      }
      if (result is CapabilityFailure<DocumentSnapshot> &&
          [
            'commit_unknown',
            'pending_write',
            'recovery_publication_unknown',
          ].contains(result.code)) {
        _unknown = true;
        return _fail('commit_unknown');
      }
      return _cast(result);
    } on FormatException catch (error) {
      if (attempted) _unknown = true;
      return _fail(attempted ? 'commit_unknown' : error.message);
    } on AccountCodecException catch (error) {
      if (attempted) _unknown = true;
      return _fail(attempted ? 'commit_unknown' : error.code);
    } on PortableJournalException catch (error) {
      if (attempted) _unknown = true;
      return _fail(attempted ? 'commit_unknown' : error.code);
    } on Object {
      if (attempted) _unknown = true;
      return _fail(attempted ? 'commit_unknown' : 'unavailable');
    } finally {
      _busy = false;
      _notify();
    }
  }

  @override
  Future<CapabilityResult<WorkspaceState>> readWorkspace(
    StorageFence fence,
  ) async {
    if (_closed) return _fail('disposed');
    if (fence != authorityFence) return _fail('stale_generation');
    final read = await inner.readWorkspace(fence);
    if (read is CapabilitySuccess<WorkspaceState> &&
        (read.value.fence != fence ||
            (read.value.snapshot != null &&
                read.value.snapshot!.fence != fence))) {
      return _fail('stale_generation');
    }
    return read;
  }

  @override
  Future<CapabilityResult<WorkspaceSnapshot>> writeWorkspace(
    String payload, {
    required StorageFence fence,
    required int? expectedRevision,
    required String writeToken,
  }) async {
    if (_closed) return _fail('disposed');
    if (_busy || isWriteBlocked()) return _fail('busy');
    if (_unknown) return _fail('commit_unknown');
    if (fence != authorityFence) return _fail('stale_generation');
    _busy = true;
    _notify();
    try {
      final result = await inner.writeWorkspace(
        payload,
        fence: fence,
        expectedRevision: expectedRevision,
        writeToken: writeToken,
      );
      if (result is CapabilityFailure<WorkspaceSnapshot> &&
          ['commit_unknown', 'pending_write'].contains(result.code)) {
        _unknown = true;
        return _fail('commit_unknown');
      }
      return result;
    } on Object {
      _unknown = true;
      return _fail('commit_unknown');
    } finally {
      _busy = false;
      _notify();
    }
  }

  @override
  Future<CapabilityResult<void>> resolvePendingWrite() async {
    if (_closed) return _fail('disposed');
    if (_busy || isWriteBlocked()) return _fail('busy');
    final result = await inner.resolvePendingWrite();
    if (result is CapabilitySuccess<void>) _unknown = false;
    return result;
  }

  @override
  Future<CapabilityResult<DocumentSnapshot>> resumeInitialCreation(
    String payload, {
    required String writeToken,
  }) async => _fail('metadata_creation_refused');
  @override
  Future<CapabilityResult<PreviousDocument?>> readPrevious() async =>
      _fail('metadata_recovery_refused');
  @override
  Future<CapabilityResult<String>> preserveSource(List<int> bytes) async =>
      _fail('metadata_import_refused');
  @override
  Future<CapabilityResult<DocumentSnapshot>> recoverPrevious(
    PreviousDocument previous, {
    required String payload,
    required String writeToken,
  }) async => _fail('metadata_recovery_refused');
  @override
  Future<void> close() async {
    dispose();
  }

  @override
  void dispose() {
    if (_closed) return;
    _closed = true;
    if (_notificationDepth == 0) super.dispose();
  }
}
