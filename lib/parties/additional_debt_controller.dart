import 'package:flutter/foundation.dart';
import 'package:madar_application/madar_application.dart';

import '../accounts/account_document.dart';
import '../accounts/portable_journal_codec.dart';
import '../accounts/portable_journal_state.dart';
import 'additional_debt_commands.dart';
import '../accounting/journal_command_host.dart';
import '../accounting/source_record_order.dart';
import '../accounting/restaurant_journal_mapper.dart';

import 'package:madar_domain/madar_domain.dart';

/// Borrowed-store owner for a caller-initialized portable account. Composition
/// must include this owner's busy/readback state in reciprocal write exclusion.
final class AdditionalDebtController extends ChangeNotifier {
  AdditionalDebtController({
    required LocalDocumentWorkspaceStore store,
    required DocumentSnapshot snapshot,
    required this.isWriteBlocked,
    this.onSnapshot,
    this.acceptedCounterAccountId,
    RestaurantJournalMapper? mapper,
  }) : _snapshot = snapshot,
       _state = const PortableJournalCodec().decodeState(snapshot.payload),
       coordinator = AdditionalDebtCoordinator(
         host: JournalCommandHost(store: store),
         mapper: mapper,
       ),
       authorityFence = snapshot.fence;
  final AdditionalDebtCoordinator coordinator;
  final String? acceptedCounterAccountId;
  final StorageFence authorityFence;
  final bool Function() isWriteBlocked;
  final void Function(DocumentSnapshot)? onSnapshot;
  DocumentSnapshot _snapshot;
  PortableJournalState _state;
  AdditionalDebtCommand? _pending;
  bool _busy = false, _disposed = false;
  String? errorCode;
  bool get busy => _busy;
  bool get needsReadback => _pending != null;
  DocumentSnapshot get snapshot => _snapshot;
  AccountDocument get account => _state.account;
  AdditionalDebtCommand capture({
    required String operationId,
    String kind = 'create',
    required String debtId,
    String? supplierId,
    String? date,
    BigInt? amount,
    String note = '',
    String reason = '',
    required String recordedAt,
  }) {
    if (_disposed || busy || needsReadback || isWriteBlocked()) {
      throw const FormatException('busy');
    }
    final rows = AdditionalDebtHistory.rows(_state, debtId);
    final family = kind == 'create'
        ? null
        : AdditionalDebtHistory.validate(_state, debtId, coordinator.mapper);
    final restoring = kind == 'restore';
    final source = restoring
        ? family?.deletion?.expectedSource
        : kind == 'create' || rows.length != 1
        ? null
        : rows.single;
    final active = restoring ? family?.deletedTarget : family?.active;
    if (kind != 'create' &&
        (source == null ||
            active == null ||
            (restoring &&
                (rows.isNotEmpty ||
                    family?.active != null ||
                    family?.deletion?.sourceOrder == null)))) {
      throw const FormatException(
        'cross_cutover_source_has_no_post_cutover_journal',
      );
    }
    final allRows = (_state.account.toJson()['debts']! as List)
        .cast<Map<String, Object?>>();
    final order = restoring
        ? family!.deletion!.sourceOrder
        : kind == 'delete'
        ? SourceRecordOrder(
            position: allRows.indexWhere((row) => row['id'] == debtId),
            siblingIds: allRows
                .where((row) => row['id'] != debtId)
                .map((row) => row['id']! as String),
          )
        : null;
    return AdditionalDebtCommand(
      kind: kind,
      operationId: operationId,
      accountLineage: _state.accountLineage,
      fence: authorityFence,
      debtId: debtId,
      recordedAt: recordedAt,
      acceptedCounterAccountId: acceptedCounterAccountId,
      mapper: coordinator.mapper,
      supplierId: supplierId ?? source?['supplierId'] as String?,
      date: restoring
          ? DateOnly.parse(
              source!['date']! as String,
              minimumYear: 1000,
              maximumYear: 9999,
            )
          : date == null
          ? null
          : DateOnly.parse(date, minimumYear: 1000, maximumYear: 9999),
      amount: restoring ? BigInt.from(source!['amount']! as int) : amount,
      note: restoring ? source!['note']! as String : note,
      reason: reason,
      expectedSource: source,
      expectedActiveJournalId: active?.journal.id,
      sourceOrder: order,
      restoreOf: restoring
          ? family!.deletion!.identity.canonicalPayloadIdentity
          : null,
    );
  }

  CapabilityResult<void> acceptSnapshot(DocumentSnapshot next) {
    if (_disposed || _busy || needsReadback) {
      return const CapabilityFailure(
        'busy',
        'Resolve the current additional debt first.',
      );
    }
    try {
      _accept(next);
      _notify();
      return const CapabilitySuccess(null);
    } on Object {
      return const CapabilityFailure(
        'stale_snapshot',
        'Snapshot was not accepted.',
      );
    }
  }

  void _accept(DocumentSnapshot next) {
    if (next.fence != authorityFence ||
        next.revision < _snapshot.revision ||
        (next.revision == _snapshot.revision &&
            (next.payload != _snapshot.payload ||
                next.writeToken != _snapshot.writeToken))) {
      throw const FormatException('stale_snapshot');
    }
    final state = const PortableJournalCodec().decodeState(next.payload);
    if (state.accountLineage != _state.accountLineage) {
      throw const FormatException('account_lineage_mismatch');
    }
    _state = state;
    _snapshot = next;
  }

  Future<DurableCommandResult<AdditionalDebtOutcome>> retry() async {
    final command = _pending;
    if (command == null) {
      return const DurableCommandFailure(
        code: 'no_pending_operation',
        message: 'No additional debt needs readback.',
      );
    }
    return submit(command);
  }

  Future<DurableCommandResult<AdditionalDebtOutcome>> submit(
    AdditionalDebtCommand command,
  ) async {
    if (_disposed || _busy || isWriteBlocked()) {
      return const DurableCommandFailure(
        code: 'busy',
        message: 'Another workflow is pending.',
      );
    }
    if (_pending != null && _pending!.identity != command.identity) {
      return const DurableCommandFailure(
        code: 'commit_unknown',
        message: 'Resolve the captured additional debt first.',
      );
    }
    if (command.accountLineage != _state.accountLineage ||
        command.fence != authorityFence) {
      return const DurableCommandFailure(
        code: 'stale_authority_fence',
        message: 'Account authority changed.',
      );
    }
    _busy = true;
    _pending = command;
    errorCode = null;
    _notify();
    try {
      final result = await coordinator.execute(command);
      switch (result) {
        case DurableCommandSuccess(:final snapshot) ||
            DurableCommandReplayed(:final snapshot):
          _accept(snapshot);
          _pending = null;
          onSnapshot?.call(snapshot);
        case DurableCommandFailure(
          :final code,
          :final latestSnapshot,
          :final receipt,
        ):
          errorCode = code;
          if (latestSnapshot != null && receipt != null) {
            _accept(latestSnapshot);
            onSnapshot?.call(latestSnapshot);
          }
          if (code != DurableCommandErrorCodes.commitUnknown &&
              code != DocumentErrorCodes.pendingWrite) {
            _pending = null;
          }
      }
      return result;
    } on Object {
      errorCode = 'commit_unknown';
      return const DurableCommandFailure(
        code: 'commit_unknown',
        message: 'Additional debt acknowledgement is unresolved.',
      );
    } finally {
      _busy = false;
      _notify();
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
