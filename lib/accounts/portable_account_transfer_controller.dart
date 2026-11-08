import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:madar_application/madar_application.dart';

import 'account_document.dart';
import 'portable_journal_codec.dart';
import 'portable_journal_state.dart';

/// An immutable container for a prepared Version 12 import candidate,
/// preserving the exact incoming bytes for provenance and archival.
final class PendingPortableAccountImport {
  PendingPortableAccountImport({
    required this.state,
    required List<int> originalBytes,
    this.previous,
  }) : _bytes = Uint8List.fromList(originalBytes);

  final PortableJournalState state;
  final PreviousDocument? previous;
  bool get isRecovery => previous != null;
  final Uint8List _bytes;

  /// Exact unmutated source bytes captured at import selection.
  Uint8List get originalBytes => Uint8List.fromList(_bytes);

  int get byteLength => _bytes.length;
}

/// Isolated complete-envelope Version 12 import/export transfer controller.
///
/// It never bootstraps an uninitialized account, mutates live runtime accounts,
/// modifies Schema 11 repositories, or activates cutover. It operates strictly on
/// an explicitly initialized isolated account document snapshot and preserves
/// all journals, receipts, lineage, cutover state, and history.
///
/// The composition owner coordinates exclusive access via [isWriteBlocked]
/// and must gate other commands while this controller is [busy] or
/// [needsReadback]. Exact CAS and generation fencing protect against
/// concurrent writes.
final class PortableAccountTransferController extends ChangeNotifier {
  PortableAccountTransferController({
    required this.store,
    required DocumentSnapshot snapshot,
    required this.isWriteBlocked,
    this.codec = const PortableJournalCodec(),
  }) : _snapshot = snapshot,
       _state = codec.decodeState(snapshot.payload) {
    _lineage = _state.accountLineage;
  }

  final LocalDocumentWorkspaceStore store;
  final PortableJournalCodec codec;
  final bool Function() isWriteBlocked;

  DocumentSnapshot _snapshot;
  PortableJournalState _state;
  late String _lineage;

  bool _busy = false;
  bool _disposed = false;
  bool _reloadRequired = false;

  PendingPortableAccountImport? _pendingImport;

  String? _pendingToken;
  String? _pendingPayload;
  PortableJournalState? _pendingState;

  bool get busy => _busy;
  bool get isDisposed => _disposed;
  bool get needsReadback => _pendingToken != null;
  bool get requiresReload => _reloadRequired;

  DocumentSnapshot get snapshot => _snapshot;
  StorageFence get authorityFence => _snapshot.fence;
  PortableJournalState get state => _state;
  String get accountLineage => _lineage;
  AccountDocument get account => _state.account;
  List<PortableJournalEntry> get journals => _state.journals;
  List<DurableCommandReceipt> get receipts => _state.receipts;
  PortableJournalCutoverState get cutoverState => _state.cutoverState;
  PortableJournalSourceProvenance get sourceProvenance =>
      _state.sourceProvenance;

  PendingPortableAccountImport? get pendingImport => _pendingImport;
  bool get hasPendingImport => _pendingImport != null;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  CapabilityFailure<T> _fail<T>(String code, [String? message]) =>
      CapabilityFailure<T>(code, message ?? 'Transfer operation failed.');

  String _token() {
    final random = Random.secure();
    return List.generate(
      24,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
  }

  String _code<T>(CapabilityResult<T> result) => switch (result) {
    CapabilityFailure<T>(:final code) => code,
    CapabilityCancelled<T>() => 'cancelled',
    _ => 'invalid_store_result',
  };

  bool _same(DocumentSnapshot a, DocumentSnapshot b) =>
      a.fence == b.fence &&
      a.revision == b.revision &&
      a.payload == b.payload &&
      a.writeToken == b.writeToken;

  void _clearPending() {
    _pendingToken = null;
    _pendingPayload = null;
    _pendingState = null;
  }

  Uint8List? _retainedExportBytes;

  /// Exact retained export bytes from the most recent export attempt, if any.
  Uint8List? get retainedExportBytes => _retainedExportBytes == null
      ? null
      : Uint8List.fromList(_retainedExportBytes!);

  /// Whether exact export bytes are currently retained for retry.
  bool get hasRetainedExportBytes => _retainedExportBytes != null;

  void _acceptReplacement(
    DocumentSnapshot next,
    PortableJournalState nextState,
  ) {
    _snapshot = next;
    _state = nextState;
    _lineage = nextState.accountLineage;
    _pendingImport = null;
    _reloadRequired = false;
    _retainedExportBytes = null;
    _clearPending();
  }

  /// Accepts an acknowledged snapshot from the active session that monotonically
  /// advances revision within the same storage fence and account lineage.
  ///
  /// Rejects if the controller is busy, has a pending import, or has an unknown
  /// commit outcome requiring readback.
  CapabilityResult<void> acceptAcknowledgedSnapshot(
    DocumentSnapshot acknowledged,
  ) {
    if (_disposed) return _fail('disposed', 'Controller is disposed.');
    if (_busy) return _fail('busy', 'Controller is busy.');
    if (hasPendingImport) {
      return _fail(
        'pending_import',
        'Cannot accept snapshot with pending import.',
      );
    }
    if (needsReadback) {
      return _fail('commit_unknown', 'Pending commit must be reconciled.');
    }
    if (acknowledged.fence != _snapshot.fence) {
      return _fail('conflict', 'Fence mismatch.');
    }
    if (acknowledged.revision < _snapshot.revision) {
      return _fail(
        'stale_revision',
        'Snapshot revision is older than current revision.',
      );
    }
    if (acknowledged.revision == _snapshot.revision) {
      if (_same(acknowledged, _snapshot)) {
        return const CapabilitySuccess(null);
      }
      return _fail('conflict', 'Conflicting snapshot at current revision.');
    }

    try {
      final decoded = codec.decodeState(acknowledged.payload);
      if (decoded.accountLineage != _lineage) {
        return _fail('conflict', 'Lineage mismatch.');
      }
      _snapshot = acknowledged;
      _state = decoded;
      _lineage = decoded.accountLineage;
      _retainedExportBytes = null;
      _reloadRequired = false;
      _notify();
      return const CapabilitySuccess(null);
    } on PortableJournalException catch (error) {
      return _fail(error.code, error.message);
    } on FormatException catch (error) {
      return _fail('corrupt_state', error.message);
    } on Object {
      return _fail('corrupt_state', 'Failed to decode acknowledged snapshot.');
    }
  }

  /// Exact canonical export bytes for the current Version 12 envelope.
  Uint8List exportBytes() => codec.encodeBytes(_state);

  /// Saves the exact Version 12 envelope bytes using the provided [FileTransferCapability].
  ///
  /// If [retry] is true and exact bytes were retained from a previous failed attempt,
  /// those identical bytes are reused rather than re-encoded.
  Future<CapabilityResult<void>> exportTo(
    FileTransferCapability transfer, {
    bool retry = false,
  }) async {
    if (_disposed) return _fail('disposed', 'Controller is disposed.');
    if (_busy || isWriteBlocked()) return _fail('busy', 'Controller is busy.');
    if (needsReadback) {
      return _fail('commit_unknown', 'Pending commit must be reconciled.');
    }
    _busy = true;
    _notify();
    try {
      final bytes = (retry && _retainedExportBytes != null)
          ? _retainedExportBytes!
          : exportBytes();
      _retainedExportBytes = bytes;
      final result = await transfer.save(bytes);
      if (result is! CapabilitySuccess<void>) {
        return _fail(_code(result), 'Export failed.');
      }
      _retainedExportBytes = null;
      return const CapabilitySuccess(null);
    } on Object {
      return _fail('file_unavailable', 'Export failed.');
    } finally {
      _busy = false;
      _notify();
    }
  }

  /// Prepares an import from selected raw bytes, enforcing strict capacity bounds,
  /// UTF-8 validation, and Version 12 complete-envelope structural invariants while
  /// preserving original bytes in [pendingImport].
  CapabilityResult<PendingPortableAccountImport> prepareImport(
    List<int> bytes,
  ) {
    if (_disposed) return _fail('disposed', 'Controller is disposed.');
    if (_busy || isWriteBlocked()) return _fail('busy', 'Controller is busy.');
    if (needsReadback) {
      return _fail('commit_unknown', 'Pending commit must be reconciled.');
    }
    final res = _prepareBytes(bytes);
    _notify();
    return res;
  }

  CapabilityResult<PendingPortableAccountImport> _prepareBytes(
    List<int> bytes,
  ) {
    if (bytes.isEmpty) {
      _pendingImport = null;
      return _fail('invalid_payload', 'Import bytes cannot be empty.');
    }
    if (bytes.length > codec.maxPayloadBytes) {
      _pendingImport = null;
      return _fail(
        'payload_too_large',
        'Payload size ${bytes.length} exceeds maximum ${codec.maxPayloadBytes}.',
      );
    }
    try {
      final decoded = codec.decodeBytes(bytes);
      if (decoded.version != 12) {
        _pendingImport = null;
        return _fail('unsupported_version', 'Expected version 12 envelope.');
      }
      final pending = PendingPortableAccountImport(
        state: decoded,
        originalBytes: bytes,
      );
      _pendingImport = pending;
      return CapabilitySuccess(pending);
    } on PortableJournalException catch (error) {
      _pendingImport = null;
      return _fail(error.code, error.message);
    } on FormatException catch (error) {
      _pendingImport = null;
      return _fail('corrupt_state', error.message);
    } on Object {
      _pendingImport = null;
      return _fail('corrupt_state', 'Failed to decode import bytes.');
    }
  }

  /// Inspects the store-owned previous copy without publishing or decoding it
  /// through the legacy account projection. Confirmation uses its opaque identity.
  Future<CapabilityResult<PendingPortableAccountImport>>
  preparePrevious() async {
    if (_disposed) return _fail('disposed');
    if (_busy || isWriteBlocked()) return _fail('busy');
    if (needsReadback) return _fail('commit_unknown');
    if (hasPendingImport) return _fail('unsaved_import');
    _busy = true;
    _notify();
    try {
      final read = await store.readPrevious();
      if (read is! CapabilitySuccess<PreviousDocument?>) {
        return _fail(_code(read));
      }
      final previous = read.value;
      if (previous == null) return _fail('no_previous_copy');
      final bytes = utf8.encode(previous.payload);
      final decoded = codec.decodeBytes(bytes);
      final pending = PendingPortableAccountImport(
        state: decoded,
        originalBytes: bytes,
        previous: previous,
      );
      _pendingImport = pending;
      return CapabilitySuccess(pending);
    } on PortableJournalException catch (error) {
      return _fail(error.code, error.message);
    } on FormatException catch (error) {
      return _fail('corrupt_state', error.message);
    } on Object {
      return _fail('unavailable');
    } finally {
      _busy = false;
      _notify();
    }
  }

  /// Opens and validates a Version 12 file through [FileTransferCapability].
  Future<CapabilityResult<PendingPortableAccountImport>> pickImport(
    FileTransferCapability transfer,
  ) async {
    if (_disposed) return _fail('disposed', 'Controller is disposed.');
    if (_busy || isWriteBlocked()) return _fail('busy', 'Controller is busy.');
    if (needsReadback) {
      return _fail('commit_unknown', 'Pending commit must be reconciled.');
    }
    _busy = true;
    _notify();
    try {
      final result = await transfer.open();
      if (result is CapabilityCancelled<Uint8List>) {
        return const CapabilityCancelled();
      }
      if (result is! CapabilitySuccess<Uint8List>) {
        return _fail(_code(result), 'File selection failed.');
      }
      final outcome = _prepareBytes(result.value);
      return outcome;
    } on Object {
      return _fail('file_unreadable', 'Failed to read file from transfer.');
    } finally {
      _busy = false;
      _notify();
    }
  }

  /// Cancels any pending import candidate without mutating store or state.
  void cancelImport() {
    if (_disposed || _busy || needsReadback) return;
    _pendingImport = null;
    _notify();
  }

  /// Explicitly confirms replacement of the current account with the prepared
  /// [pendingImport].
  ///
  /// Steps:
  /// 1. Preserves original incoming bytes via [store.preserveSource].
  /// 2. Performs CAS verification against store authority.
  /// 3. Performs explicit fenced replacement ([replaceGeneration: true]).
  /// 4. Handles commit uncertainty safely, leaving [needsReadback] on unknown outcome.
  Future<CapabilityResult<void>> confirmImport() async {
    if (_disposed) return _fail('disposed', 'Controller is disposed.');
    if (_busy || isWriteBlocked()) return _fail('busy', 'Controller is busy.');
    if (needsReadback) {
      return _fail('commit_unknown', 'Pending commit must be reconciled.');
    }
    if (_reloadRequired) {
      return _fail('stale_revision', 'Authority changed; reload required.');
    }
    final pending = _pendingImport;
    if (pending == null) {
      return _fail('no_pending_import', 'No import candidate prepared.');
    }
    _busy = true;
    _notify();
    try {
      final preserved = await store.preserveSource(pending.originalBytes);
      if (preserved is! CapabilitySuccess<String>) {
        return _fail(
          _code(preserved),
          'Failed to preserve original import source.',
        );
      }

      final candidateState = pending.state;
      final payload = codec.encodeState(candidateState);

      final read = await store.readDocument();
      if (read is CapabilitySuccess<DocumentSnapshot?>) {
        final actual = read.value;
        if (actual == null || !_same(actual, _snapshot)) {
          _reloadRequired = true;
          return _fail('stale_revision', 'Stale snapshot authority.');
        }
      } else if (!(pending.isRecovery &&
          read is CapabilityFailure<DocumentSnapshot?> &&
          read.code == DocumentErrorCodes.corruptPrimary)) {
        return _fail(
          _code(read),
          'Failed to verify current document authority.',
        );
      }
      if (isWriteBlocked()) return _fail('busy', 'Write blocked.');

      final token = _token();
      _pendingToken = token;
      _pendingPayload = payload;
      _pendingState = candidateState;

      final result = pending.previous == null
          ? await store.writeDocument(
              payload,
              writeToken: token,
              expected: _snapshot,
              replaceGeneration: true,
            )
          : await store.recoverPrevious(
              pending.previous!,
              payload: payload,
              writeToken: token,
            );

      if (result case CapabilitySuccess<DocumentSnapshot>(:final value)) {
        if (value.revision <= 0 ||
            value.fence == _snapshot.fence ||
            value.writeToken != token ||
            value.payload != payload) {
          return _fail('commit_unknown', 'Uncertain write acknowledgement.');
        }
        _acceptReplacement(value, candidateState);
        return const CapabilitySuccess(null);
      }

      final code = _code(result);
      if (result is CapabilityFailure<DocumentSnapshot> &&
          code != 'commit_unknown' &&
          code != 'recovery_publication_unknown') {
        _clearPending();
        if (code == 'stale_revision' || code == 'conflict') {
          _reloadRequired = true;
        }
      }
      return _fail(needsReadback ? 'commit_unknown' : code);
    } on PortableJournalException catch (error) {
      return _fail(error.code, error.message);
    } on Object {
      return _fail(
        needsReadback ? 'commit_unknown' : 'unavailable',
        'Unexpected error during import replacement.',
      );
    } finally {
      _busy = false;
      _notify();
    }
  }

  /// Reconciles an uncertain commit outcome when [needsReadback] is true.
  Future<CapabilityResult<void>> reconcile() async {
    if (_disposed) return _fail('disposed', 'Controller is disposed.');
    if (_busy || isWriteBlocked()) return _fail('busy', 'Controller is busy.');
    if (!needsReadback) {
      return _fail('no_pending_write', 'No pending write to reconcile.');
    }
    _busy = true;
    _notify();
    try {
      final resolved = await store.resolvePendingWrite();
      if (resolved is! CapabilitySuccess<void>) {
        return _fail(_code(resolved), 'Failed to resolve pending write gate.');
      }
      final read = await store.readDocument();
      if (read is! CapabilitySuccess<DocumentSnapshot?>) {
        return _fail(_code(read), 'Failed to read document after resolution.');
      }
      final actual = read.value;
      if (actual == null ||
          actual.writeToken != _pendingToken ||
          actual.payload != _pendingPayload) {
        _clearPending();
        _reloadRequired = true;
        return _fail(
          'stale_revision',
          'Committed state does not match pending write.',
        );
      }
      _acceptReplacement(actual, _pendingState!);
      return const CapabilitySuccess(null);
    } on PortableJournalException catch (error) {
      return _fail(error.code, error.message);
    } on Object {
      return _fail('commit_unknown', 'Failed to reconcile commit outcome.');
    } finally {
      _busy = false;
      _notify();
    }
  }

  /// Reloads current document state from the store, granting explicit consent to a
  /// new revision under the same or refreshed authority.
  Future<CapabilityResult<void>> reload({
    bool discardPendingImport = false,
  }) async {
    if (_disposed) return _fail('disposed', 'Controller is disposed.');
    if (_busy || isWriteBlocked()) return _fail('busy', 'Controller is busy.');
    if (needsReadback) {
      return _fail('commit_unknown', 'Pending commit must be reconciled.');
    }
    if (hasPendingImport && !discardPendingImport) {
      return _fail(
        'unsaved_import',
        'Pending import exists; discard explicitly.',
      );
    }
    _busy = true;
    _notify();
    try {
      final read = await store.readDocument();
      if (read is! CapabilitySuccess<DocumentSnapshot?>) {
        return _fail(_code(read), 'Failed to read document from store.');
      }
      final next = read.value;
      if (next == null) {
        return _fail('account_missing', 'No account document found in store.');
      }
      final nextState = codec.decodeState(next.payload);
      _snapshot = next;
      _state = nextState;
      _lineage = nextState.accountLineage;
      _pendingImport = null;
      _reloadRequired = false;
      _retainedExportBytes = null;
      return const CapabilitySuccess(null);
    } on PortableJournalException catch (error) {
      return _fail(error.code, error.message);
    } on FormatException catch (error) {
      return _fail('corrupt_state', error.message);
    } on Object {
      return _fail('unavailable', 'Reload failed unexpectedly.');
    } finally {
      _busy = false;
      _notify();
    }
  }
}
