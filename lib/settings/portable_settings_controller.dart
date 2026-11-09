import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:madar_application/madar_application.dart';

import '../accounts/account_document.dart';
import '../accounts/legacy_account_codec.dart';
import '../accounts/portable_journal_codec.dart';
import '../accounts/portable_journal_state.dart';
import 'account_settings.dart';

/// Isolated complete-envelope metadata editor. It never creates an account,
/// changes cutover, posts a journal or writes a schema11-only projection.
///
/// The composition owner must exclude other pending operations through
/// [isWriteBlocked] and block its other commands while [busy] or
/// [needsReadback]. Exact snapshot compare-and-swap also protects concurrent
/// processes and writers that do not share the UI exclusion callback.
final class PortableSettingsController extends ChangeNotifier {
  PortableSettingsController({
    required this.store,
    required DocumentSnapshot snapshot,
    required this.isWriteBlocked,
    this.codec = const PortableJournalCodec(),
  }) : authorityFence = snapshot.fence,
       _snapshot = snapshot,
       _state = codec.decodeState(snapshot.payload) {
    _lineage = _state.accountLineage;
    _draft = AccountSettingsDraft(_state.account);
  }
  final LocalDocumentWorkspaceStore store;
  final PortableJournalCodec codec;
  final bool Function() isWriteBlocked;
  final StorageFence authorityFence;
  late final String _lineage;
  DocumentSnapshot _snapshot;
  PortableJournalState _state;
  late final AccountSettingsDraft _draft;
  bool _busy = false, _disposed = false, _reloadRequired = false;
  int _editVersion = 0;
  String? _pendingToken, _pendingPayload;
  AccountDocument? _pendingAccount;
  int? _pendingEditVersion;
  bool get busy => _busy;
  bool get needsReadback => _pendingToken != null;
  bool get requiresReload => _reloadRequired;
  bool get isDirty => _draft.isDirty;
  AccountSettingsValues get values => _draft.values;
  AccountDocument get account => _state.account;
  DocumentSnapshot get snapshot => _snapshot;
  void replace(AccountSettingsValues values) {
    if (_disposed) return;
    _editVersion++;
    _draft.replace(values);
    _notify();
  }

  void discard() {
    if (_disposed || _busy || needsReadback) return;
    _editVersion++;
    _draft.discard();
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  CapabilityFailure<void> _fail(String code) =>
      CapabilityFailure(code, 'Settings operation not acknowledged.');
  bool _same(DocumentSnapshot a, DocumentSnapshot b) =>
      a.fence == b.fence &&
      a.revision == b.revision &&
      a.payload == b.payload &&
      a.writeToken == b.writeToken;
  PortableJournalState _decode(DocumentSnapshot next) {
    if (next.fence != authorityFence) {
      throw const FormatException('stale_generation');
    }
    if (next.revision < _snapshot.revision ||
        (next.revision == _snapshot.revision && !_same(next, _snapshot))) {
      throw const FormatException('stale_revision');
    }
    final state = codec.decodeState(next.payload);
    if (state.accountLineage != _lineage) {
      throw const FormatException('account_lineage_mismatch');
    }
    return state;
  }

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
  void _clearPending() {
    _pendingToken = null;
    _pendingPayload = null;
    _pendingAccount = null;
    _pendingEditVersion = null;
  }

  void _acceptWrite(DocumentSnapshot next) {
    if (next.revision <= _snapshot.revision) {
      throw const FormatException('stale_revision');
    }
    final state = _decode(next);
    final later = _draft.values;
    final editedLater = _editVersion != _pendingEditVersion;
    _snapshot = next;
    _state = state;
    _draft.acceptSaved(_pendingAccount!);
    if (editedLater) _draft.replace(later);
    _reloadRequired = false;
    _clearPending();
  }

  /// Explicit refresh grants consent to the new revision, only within the
  /// captured lineage and storage generation. Dirty edits need explicit discard.
  Future<CapabilityResult<void>> load({bool discardChanges = false}) async {
    if (_disposed) return _fail('disposed');
    if (_busy || isWriteBlocked()) return _fail('busy');
    if (needsReadback) return _fail('commit_unknown');
    if (isDirty && !discardChanges) return _fail('unsaved_changes');
    final loadedEditVersion = _editVersion;
    _busy = true;
    _notify();
    try {
      final read = await store.readDocument();
      if (read is! CapabilitySuccess<DocumentSnapshot?>) {
        return _fail(_code(read));
      }
      final next = read.value;
      if (next == null) return _fail('account_missing');
      final state = _decode(next);
      if (_disposed) return _fail('disposed');
      final later = _draft.values;
      final editedLater = loadedEditVersion != _editVersion;
      _state = state;
      _snapshot = next;
      _draft.acceptSaved(state.account);
      if (editedLater) _draft.replace(later);
      _editVersion++;
      _reloadRequired = false;
      return const CapabilitySuccess(null);
    } on PortableJournalException catch (error) {
      return _fail(error.code);
    } on FormatException catch (error) {
      return _fail(error.message);
    } on Object {
      return _fail('unavailable');
    } finally {
      _busy = false;
      _notify();
    }
  }

  Future<CapabilityResult<void>> save() async {
    if (_disposed) return _fail('disposed');
    if (_busy || isWriteBlocked()) return _fail('busy');
    if (needsReadback) return _fail('commit_unknown');
    if (_reloadRequired) return _fail('stale_revision');
    _busy = true;
    _notify();
    try {
      final candidate = _draft.prepareSave(_state.account);
      final submittedEditVersion = _editVersion;
      final payload = codec.encodeState(_state.copyWith(account: candidate));
      final read = await store.readDocument();
      if (read is! CapabilitySuccess<DocumentSnapshot?>) {
        return _fail(_code(read));
      }
      final actual = read.value;
      if (actual == null || !_same(actual, _snapshot)) {
        _reloadRequired = true;
        return _fail('stale_revision');
      }
      _decode(actual);
      if (_disposed) return _fail('disposed');
      if (isWriteBlocked()) return _fail('busy');
      _pendingToken = _token();
      _pendingPayload = payload;
      _pendingAccount = candidate;
      _pendingEditVersion = submittedEditVersion;
      final result = await store.writeDocument(
        payload,
        writeToken: _pendingToken!,
        expected: _snapshot,
      );
      if (result case CapabilitySuccess<DocumentSnapshot>(:final value)) {
        if (value.fence != authorityFence ||
            value.revision <= _snapshot.revision ||
            value.writeToken != _pendingToken ||
            value.payload != payload) {
          return _fail('commit_unknown');
        }
        _acceptWrite(value);
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
    } on AccountCodecException catch (error) {
      return _fail(error.code);
    } on PortableJournalException catch (error) {
      return _fail(error.code);
    } on Object {
      return _fail(needsReadback ? 'commit_unknown' : 'unavailable');
    } finally {
      _busy = false;
      _notify();
    }
  }

  /// Resolve an uncertain metadata write before granting any retry authority.
  /// A different latest write cannot prove this write's outcome; require an
  /// explicit reload rather than overwrite it or claim successful settings.
  Future<CapabilityResult<void>> reconcile() async {
    if (_disposed) return _fail('disposed');
    if (_busy || isWriteBlocked()) return _fail('busy');
    if (!needsReadback) return _fail('no_pending_write');
    _busy = true;
    _notify();
    try {
      final resolved = await store.resolvePendingWrite();
      if (resolved is! CapabilitySuccess<void>) return _fail(_code(resolved));
      final read = await store.readDocument();
      if (read is! CapabilitySuccess<DocumentSnapshot?>) {
        return _fail(_code(read));
      }
      final actual = read.value;
      if (actual == null ||
          actual.writeToken != _pendingToken ||
          actual.payload != _pendingPayload) {
        _clearPending();
        _reloadRequired = true;
        return _fail('stale_revision');
      }
      _acceptWrite(actual);
      return const CapabilitySuccess(null);
    } on PortableJournalException catch (error) {
      return _fail(error.code);
    } on Object {
      return _fail('commit_unknown');
    } finally {
      _busy = false;
      _notify();
    }
  }
}
