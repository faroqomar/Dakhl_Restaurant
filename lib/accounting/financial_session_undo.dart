import 'package:flutter/foundation.dart';
import 'package:madar_application/madar_application.dart';

import '../accounts/portable_journal_codec.dart';
import '../accounts/portable_journal_state.dart';
import 'journal_command_host.dart';

/// A prepared compensation captures one immutable command and executes that
/// same command on uncertain retries. Adapters retain their normal owner gates.
final class FinancialUndoAttempt {
  const FinancialUndoAttempt(this.execute) : executeMetadata = null;
  const FinancialUndoAttempt.metadata(this.executeMetadata) : execute = null;
  final Future<DurableCommandResult<dynamic>> Function()? execute;
  final Future<CapabilityResult<DocumentSnapshot>> Function()? executeMetadata;
}

abstract interface class FinancialUndoAdapter {
  String get label;
  FinancialUndoAttempt prepare({
    required PortableJournalState before,
    required PortableJournalState after,
    required PortableJournalState current,
  });
}

final class UnsupportedFinancialUndo implements FinancialUndoAdapter {
  const UnsupportedFinancialUndo(
    this.label, {
    this.code = 'undo_kind_not_supported',
  });
  @override
  final String label;
  final String code;
  @override
  FinancialUndoAttempt prepare({
    required PortableJournalState before,
    required PortableJournalState after,
    required PortableJournalState current,
  }) => throw FormatException(code);
}

final class _UndoRecord {
  const _UndoRecord(this.before, this.after, this.adapter);
  final PortableJournalState before, after;
  final FinancialUndoAdapter adapter;
}

/// Source-compatible session-local stack. Durable source/journals/receipts are
/// never replaced by saved envelopes. Root composition registers acknowledgements
/// and calls observe/reset at source load/import or sales/refund boundaries.
final class FinancialSessionUndoController extends ChangeNotifier {
  FinancialSessionUndoController({
    required this.readSnapshot,
    required this.isWriteBlocked,
    PortableJournalCodec? codec,
  }) : _codec = codec ?? const PortableJournalCodec() {
    _latest = readSnapshot();
    _sales = _salesKey(_decode(_latest));
  }
  final DocumentSnapshot Function() readSnapshot;
  final bool Function() isWriteBlocked;
  final PortableJournalCodec _codec;
  late DocumentSnapshot _latest;
  late String _sales;
  final _stack = <_UndoRecord>[];
  final _seen = <String>{};
  FinancialUndoAttempt? _attempt;
  bool _busy = false, _disposed = false;
  String? errorCode;
  int get length => _stack.length;
  bool get busy => _busy;
  bool get needsReadback => _attempt != null;
  String? get nextLabel => _stack.isEmpty ? null : _stack.last.adapter.label;
  bool get canUndo => !_busy && !isWriteBlocked() && _stack.isNotEmpty;
  PortableJournalState _decode(DocumentSnapshot s) =>
      _codec.decodeState(s.payload);
  static String _salesKey(PortableJournalState s) => canonicalIdentity({
    'sales': s.account.toJson()['sales'],
    'saleReturns': s.account.toJson()['saleReturns'],
  });
  static bool _sameSnapshot(DocumentSnapshot a, DocumentSnapshot b) =>
      a.fence == b.fence &&
      a.revision == b.revision &&
      a.writeToken == b.writeToken &&
      a.payload == b.payload;
  CapabilityResult<void> _fail(String code) {
    errorCode = code;
    if (!_disposed) notifyListeners();
    return CapabilityFailure(code, 'The undo state was not changed.');
  }

  /// Register only an acknowledged new command, retaining the original before
  /// snapshot across an unknown acknowledgement. Replayed registration is deduped.
  CapabilityResult<void> register({
    required DocumentSnapshot before,
    required DurableCommandResult<dynamic> result,
    required FinancialUndoAdapter adapter,
  }) {
    if (_disposed) return _fail('disposed');
    if (_busy || needsReadback) return _fail('commit_unknown');
    if (result is! DurableCommandSuccess && result is! DurableCommandReplayed) {
      return _fail('undo_requires_acknowledged_commit');
    }
    final (
      DocumentSnapshot snapshot,
      DurableCommandReceipt receipt,
    ) = switch (result) {
      DurableCommandSuccess(:final snapshot, :final receipt) => (
        snapshot,
        receipt,
      ),
      DurableCommandReplayed(:final snapshot, :final receipt) => (
        snapshot,
        receipt,
      ),
      _ => throw const FormatException('undo_requires_acknowledged_commit'),
    };
    try {
      final old = _decode(before), after = _decode(snapshot);
      if (_seen.contains(receipt.identity.operationId)) {
        return const CapabilitySuccess(null);
      }
      if (!_sameSnapshot(readSnapshot(), snapshot) ||
          before.fence != snapshot.fence ||
          snapshot.revision <= before.revision ||
          old.accountLineage != after.accountLineage ||
          receipt.status != DurableCommandStatus.committed ||
          receipt.fence != snapshot.fence ||
          receipt.committedRevision != snapshot.revision ||
          old.receipts.any(
            (r) => r.identity.operationId == receipt.identity.operationId,
          ) ||
          !after.receipts.any(
            (r) =>
                r.identity == receipt.identity &&
                r.outcomePayload == receipt.outcomePayload,
          )) {
        return _fail('invalid_undo_registration');
      }
      if (_salesKey(old) != _salesKey(after)) return reset();
      if (_stack.isNotEmpty && !_sameSnapshot(_latest, before)) {
        return _fail('stale_undo_snapshot');
      }
      _stack.add(_UndoRecord(old, after, adapter));
      if (_stack.length > 30) _stack.removeAt(0);
      _seen.add(receipt.identity.operationId);
      _latest = snapshot;
      _sales = _salesKey(after);
      errorCode = null;
      notifyListeners();
      return const CapabilitySuccess(null);
    } on Object {
      return _fail('invalid_undo_registration');
    }
  }

  /// Session observer entrypoint. Root chooses the corresponding receipt or
  /// metadata adapter; metadata adapters must enforce their exact whitelist.
  CapabilityResult<void> registerTransition({
    required DocumentSnapshot before,
    required DocumentSnapshot after,
    required FinancialUndoAdapter adapter,
  }) {
    if (_disposed) return _fail('disposed');
    if (_busy || needsReadback) return _fail('commit_unknown');
    try {
      final old = _decode(before), next = _decode(after);
      if (_sameSnapshot(_latest, after)) return const CapabilitySuccess(null);
      if (!_sameSnapshot(readSnapshot(), after) ||
          before.fence != after.fence ||
          next.accountLineage != old.accountLineage ||
          after.revision <= before.revision) {
        return _fail('invalid_undo_registration');
      }
      if (_salesKey(old) != _salesKey(next)) return reset();
      final added = next.receipts
          .where(
            (r) => !old.receipts.any(
              (a) => a.identity.operationId == r.identity.operationId,
            ),
          )
          .toList();
      if (added.length == 1 &&
          added.single.status == DurableCommandStatus.committed) {
        return register(
          before: before,
          result: DurableCommandSuccess<void>(
            outcome: null,
            receipt: added.single,
            snapshot: after,
          ),
          adapter: adapter,
        );
      }
      if (added.isNotEmpty) {
        if (added.every((r) => r.status == DurableCommandStatus.rejected) &&
            _sameVisible(old, next) &&
            (_stack.isEmpty || _sameSnapshot(_latest, before))) {
          _latest = after;
          errorCode = null;
          notifyListeners();
          return const CapabilitySuccess(null);
        }
        return _fail('undo_transition_not_atomic');
      }
      final oldEnvelope = {...old.toJson()}..remove('account');
      final nextEnvelope = {...next.toJson()}..remove('account');
      if (canonicalIdentity(oldEnvelope) != canonicalIdentity(nextEnvelope)) {
        return _fail('undo_unreceipted_financial_change');
      }
      if (_stack.isNotEmpty && !_sameSnapshot(_latest, before)) {
        return _fail('stale_undo_snapshot');
      }
      if (canonicalIdentity(old.account.toJson()) ==
          canonicalIdentity(next.account.toJson())) {
        _latest = after;
        errorCode = null;
        notifyListeners();
        return const CapabilitySuccess(null);
      }
      _stack.add(_UndoRecord(old, next, adapter));
      if (_stack.length > 30) _stack.removeAt(0);
      _latest = after;
      _sales = _salesKey(next);
      errorCode = null;
      notifyListeners();
      return const CapabilitySuccess(null);
    } on Object {
      return _fail('invalid_undo_registration');
    }
  }

  CapabilityResult<void> reset() {
    if (_disposed) return _fail('disposed');
    if (_busy || needsReadback) return _fail('commit_unknown');
    _latest = readSnapshot();
    _sales = _salesKey(_decode(_latest));
    _stack.clear();
    _seen.clear();
    errorCode = null;
    notifyListeners();
    return const CapabilitySuccess(null);
  }

  /// Sales/returns invalidate the source session stack; an unregistered other
  /// commit remains a visible stale barrier rather than silently restoring it.
  CapabilityResult<void> observe() {
    if (_disposed) return _fail('disposed');
    final current = readSnapshot();
    if (current.fence != _latest.fence ||
        _decode(current).accountLineage != _decode(_latest).accountLineage ||
        _salesKey(_decode(current)) != _sales) {
      return reset();
    }
    if (!_sameSnapshot(current, _latest) &&
        _stack.isNotEmpty &&
        !needsReadback) {
      return _fail('stale_undo_snapshot');
    }
    if (_stack.isEmpty && !needsReadback) _latest = current;
    return const CapabilitySuccess(null);
  }

  Future<CapabilityResult<void>> undo() async {
    if (_disposed) return _fail('disposed');
    if (_busy || isWriteBlocked()) return _fail('busy');
    if (_stack.isEmpty) return _fail('nothing_to_undo');
    if (!needsReadback) {
      final observed = observe();
      if (observed is! CapabilitySuccess<void>) return observed;
      if (_stack.isEmpty) return _fail('nothing_to_undo');
      try {
        _attempt = _stack.last.adapter.prepare(
          before: _stack.last.before,
          after: _stack.last.after,
          current: _decode(readSnapshot()),
        );
      } on FormatException catch (e) {
        return _fail(e.message);
      } on Object {
        return _fail('undo_not_reconciled');
      }
    }
    _busy = true;
    errorCode = null;
    notifyListeners();
    try {
      final metadata = _attempt!.executeMetadata;
      if (metadata != null) {
        final result = await metadata();
        if (_disposed) {
          return const CapabilityFailure('disposed', 'Undo owner closed.');
        }
        if (result is CapabilitySuccess<DocumentSnapshot>) {
          final snapshot = result.value;
          if (snapshot.fence != _latest.fence ||
              _decode(snapshot).accountLineage !=
                  _decode(_latest).accountLineage ||
              snapshot.revision <= _latest.revision) {
            errorCode = 'commit_unknown';
            return const CapabilityFailure(
              'commit_unknown',
              'Metadata compensation acknowledgement is not reconciled.',
            );
          }
          _latest = snapshot;
          _sales = _salesKey(_decode(snapshot));
          _stack.removeLast();
          _attempt = null;
          return const CapabilitySuccess(null);
        }
        final code = result is CapabilityFailure<DocumentSnapshot>
            ? result.code
            : 'cancelled';
        errorCode = code;
        if (code != DurableCommandErrorCodes.commitUnknown &&
            code != DocumentErrorCodes.pendingWrite) {
          _attempt = null;
        }
        return CapabilityFailure(
          code,
          'The metadata compensation was not confirmed.',
        );
      }
      final result = await _attempt!.execute!();
      if (_disposed) {
        return const CapabilityFailure('disposed', 'Undo owner closed.');
      }
      switch (result) {
        case DurableCommandSuccess(:final snapshot):
          _latest = snapshot;
          _sales = _salesKey(_decode(snapshot));
          _stack.removeLast();
          _attempt = null;
        case DurableCommandReplayed(:final snapshot):
          _latest = snapshot;
          _sales = _salesKey(_decode(snapshot));
          _stack.removeLast();
          _attempt = null;
        case DurableCommandFailure(
          :final code,
          :final latestSnapshot,
          :final receipt,
        ):
          errorCode = code;
          if (code != DurableCommandErrorCodes.commitUnknown &&
              code != DocumentErrorCodes.pendingWrite) {
            _attempt = null;
            if (latestSnapshot != null &&
                receipt?.status == DurableCommandStatus.rejected &&
                _sameVisible(_decode(_latest), _decode(latestSnapshot))) {
              _latest = latestSnapshot;
            }
          }
          return CapabilityFailure(
            code,
            'The undo compensation was not confirmed.',
          );
      }
      return const CapabilitySuccess(null);
    } on Object {
      errorCode = 'commit_unknown';
      return const CapabilityFailure(
        'commit_unknown',
        'Resolve the original compensation before retrying.',
      );
    } finally {
      _busy = false;
      if (!_disposed) notifyListeners();
    }
  }

  static bool _sameVisible(PortableJournalState a, PortableJournalState b) =>
      canonicalIdentity({
        'account': a.account.toJson(),
        'journals': a.journals.map((j) => j.toJson()).toList(),
        'cutover': a.cutoverState.toJson(),
        'lineage': a.accountLineage,
      }) ==
      canonicalIdentity({
        'account': b.account.toJson(),
        'journals': b.journals.map((j) => j.toJson()).toList(),
        'cutover': b.cutoverState.toJson(),
        'lineage': b.accountLineage,
      });
  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
