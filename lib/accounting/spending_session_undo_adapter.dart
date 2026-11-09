import 'dart:convert';

import 'package:madar_application/madar_application.dart';
import 'package:madar_domain/madar_domain.dart';

import '../accounts/portable_journal_state.dart';
import '../catalog/catalog_formatters.dart';
import 'financial_session_undo.dart';
import 'deleted_spending_restoration.dart';
import 'journal_command_host.dart';
import 'source_record_order.dart';
import 'restaurant_journal_expense_history.dart';
import 'restaurant_journal_external_cash_commands.dart';
import 'restaurant_journal_expense_correction_commands.dart';
import 'restaurant_journal_transfer_history.dart';
import 'spending_operations_view_model.dart';

/// Receipt-driven adapter for supported spending inverses. It validates the
/// full proposed restored source before submitting any compensation.
final class SpendingSessionUndoAdapter implements FinancialUndoAdapter {
  SpendingSessionUndoAdapter({required this.spending, required this.identity});
  final SpendingOperationsViewModel spending;
  final DurableCommandIdentity identity;
  @override
  String get label => 'آخر تغيير مالي';
  static const reason = 'تراجع عن التصحيح السابق';
  @override
  FinancialUndoAttempt prepare({
    required PortableJournalState before,
    required PortableJournalState after,
    required PortableJournalState current,
  }) {
    if (!spending.postingEnabled) throw const FormatException('busy');
    if (!after.receipts.any(
      (r) =>
          r.identity == identity && r.status == DurableCommandStatus.committed,
    )) {
      throw const FormatException('undo_missing_original_receipt');
    }
    final intent = (jsonDecode(identity.canonicalPayloadIdentity) as Map)
        .cast<String, Object?>();
    final kind = intent['commandType'];
    final op = CatalogFormatters.generateId('undo-operation'),
        inverse = CatalogFormatters.generateId('undo-inverse'),
        replacement = CatalogFormatters.generateId('undo-replacement'),
        stamp = CatalogFormatters.currentIsoTimestamp();
    if ([
      'delete_operating_expense',
      'delete_daily_transfer',
      'external_cash_delete',
    ].contains(kind)) {
      final family = kind == 'delete_operating_expense'
          ? DeletedSpendingKind.expense
          : kind == 'delete_daily_transfer'
          ? DeletedSpendingKind.transfer
          : DeletedSpendingKind.externalCash;
      final key = family == DeletedSpendingKind.expense
          ? 'expenseId'
          : family == DeletedSpendingKind.transfer
          ? 'transferId'
          : 'transactionId';
      final id = intent[key]! as String;
      _assertAffected(after, current, family, id);
      final old = family == DeletedSpendingKind.expense
          ? RestaurantJournalExpenseHistory.sourceRows(before, id)
          : _rows(
              before,
              family == DeletedSpendingKind.transfer
                  ? 'transfers'
                  : 'transactions',
              id,
            );
      if (old.length != 1) {
        throw const FormatException('undo_missing_deleted_snapshot');
      }
      final date = old.single['date']! as String;
      List<Map<String, Object?>> list(PortableJournalState s) =>
          family == DeletedSpendingKind.expense
          ? (((s.account.days[date]! as Map)['expenses']! as List)
                .map((r) => (r as Map).cast<String, Object?>())
                .toList())
          : (s.account.toJson()[family == DeletedSpendingKind.transfer
                        ? 'transfers'
                        : 'transactions']!
                    as List)
                .map((r) => (r as Map).cast<String, Object?>())
                .toList();
      final originalList = list(before), currentList = list(current);
      final position = originalList.indexWhere((r) => r['id'] == id);
      final command = spending.restoreDeletedIntent(
        kind: family,
        operationId: op,
        recordId: id,
        deletedJournalId: intent['expectedActiveJournalId']! as String,
        deleteInverseJournalId: intent['inverseJournalId']! as String,
        deleteOperationId: identity.operationId,
        replacementJournalId: replacement,
        sourceSnapshot: old.single,
        position: position,
        expectedSiblingIds: currentList.map((r) => r['id']! as String),
        reason: reason,
        recordedAt: stamp,
      );
      _requireRestored(
        spending.previewDeletedRestoration(command),
        _expected(before, current, family, id),
      );
      return FinancialUndoAttempt(
        () => spending.submitDeletedRestoration(command),
      );
    }
    if (['operating_expense', 'edit_operating_expense'].contains(kind)) {
      final id = intent['expenseId']! as String;
      _assertAffected(after, current, DeletedSpendingKind.expense, id);
      final old = RestaurantJournalExpenseHistory.sourceRows(before, id);
      final now = RestaurantJournalExpenseHistory.sourceRows(current, id);
      if (now.length != 1 ||
          (kind == 'operating_expense' ? old.isNotEmpty : old.length != 1)) {
        throw const FormatException('undo_source_changed');
      }
      final active = _activeExpense(current, id);
      if (active == null) {
        throw const FormatException('undo_missing_original_posting');
      }
      final command = kind == 'operating_expense'
          ? spending.deleteExpenseIntent(
              operationId: op,
              expenseId: id,
              expectedActiveJournalId: active.journal.id,
              inverseJournalId: inverse,
              reason: reason,
              recordedAt: stamp,
              profile: spending.expenseCorrectionCommands.mapper.profile,
            )
          : _expenseEdit(
              old.single,
              id,
              op,
              inverse,
              replacement,
              active.journal.id,
              stamp,
              before,
              current,
            );
      final proposal = spending.previewExpenseCorrection(command);
      _requireRestored(
        proposal,
        _expected(before, current, DeletedSpendingKind.expense, id),
      );
      return FinancialUndoAttempt(
        () => spending.submitExpenseCorrection(command),
      );
    }
    if (['daily_to_cashbox_transfer', 'edit_daily_transfer'].contains(kind)) {
      final id = intent['transferId']! as String;
      _assertAffected(after, current, DeletedSpendingKind.transfer, id);
      final old = _rows(before, 'transfers', id),
          now = _rows(current, 'transfers', id);
      if (now.length != 1 ||
          (kind == 'daily_to_cashbox_transfer'
              ? old.isNotEmpty
              : old.length != 1)) {
        throw const FormatException('undo_source_changed');
      }
      final active = _activeTransfer(current, id);
      if (active == null) {
        throw const FormatException('undo_missing_original_posting');
      }
      if (old.isNotEmpty && old.single['date'] != now.single['date']) {
        throw const FormatException('undo_date_batch_required');
      }
      final command = kind == 'daily_to_cashbox_transfer'
          ? spending.deleteTransferIntent(
              operationId: op,
              transferId: id,
              expectedActiveJournalId: active.journal.id,
              inverseJournalId: inverse,
              reason: reason,
              recordedAt: stamp,
            )
          : spending.editTransferIntent(
              operationId: op,
              transferId: id,
              expectedActiveJournalId: active.journal.id,
              inverseJournalId: inverse,
              replacementJournalId: replacement,
              newAmount: BigInt.from(old.single['amount']! as int),
              reason: reason,
              recordedAt: stamp,
              policy: _activeTransfer(before, id)?.journal.policy,
              sourceOrder: _order(
                before,
                current,
                DeletedSpendingKind.transfer,
                id,
              ),
            );
      final proposal = spending.previewTransferCorrection(command);
      _requireRestored(
        proposal,
        _expected(before, current, DeletedSpendingKind.transfer, id),
      );
      return FinancialUndoAttempt(
        () => spending.submitTransferCorrection(command),
      );
    }
    if (['external_cash_create', 'external_cash_edit'].contains(kind)) {
      final id = intent['transactionId']! as String,
          old = _rows(
            before,
            'transactions',
            intent['transactionId']! as String,
          ),
          now = _rows(
            current,
            'transactions',
            intent['transactionId']! as String,
          );
      if (now.length != 1 ||
          (kind == 'external_cash_create' ? old.isNotEmpty : old.length != 1)) {
        throw const FormatException('undo_source_changed');
      }
      _assertAffected(after, current, DeletedSpendingKind.externalCash, id);
      final active = RestaurantJournalExternalCashHistory.activePosting(
        current,
        id,
        spending.externalCashCommands.mapper,
      );
      if (active == null) {
        throw const FormatException('undo_missing_original_posting');
      }
      final command = kind == 'external_cash_create'
          ? spending.deleteExternalCashIntent(
              operationId: op,
              transactionId: id,
              inverseJournalId: inverse,
              expectedActiveJournalId: active.journal.id,
              expectedSource: now.single,
              reason: reason,
              recordedAt: stamp,
            )
          : spending.editExternalCashIntent(
              operationId: op,
              transactionId: id,
              journalId: replacement,
              inverseJournalId: inverse,
              expectedActiveJournalId: active.journal.id,
              expectedSource: now.single,
              reason: reason,
              date: CatalogFormatters.parseDate(old.single['date']! as String),
              amount: BigInt.from(old.single['amount']! as int),
              type: old.single['type']! as String,
              note: old.single['note']! as String,
              sourceOrder: _order(
                before,
                current,
                DeletedSpendingKind.externalCash,
                id,
              ),
              recordedAt: stamp,
            );
      final proposal = RestaurantJournalExternalCashCoordinator.evaluate(
        command: command,
        state: current,
        mapper: spending.externalCashCommands.mapper,
      );
      _requireRestored(
        proposal,
        _expected(before, current, DeletedSpendingKind.externalCash, id),
      );
      return FinancialUndoAttempt(() => spending.submitExternalCash(command));
    }
    throw const FormatException('undo_kind_not_supported');
  }

  EditOperatingExpenseCommand _expenseEdit(
    Map<String, Object?> row,
    String id,
    String op,
    String inverse,
    String replacement,
    String active,
    String stamp,
    PortableJournalState before,
    PortableJournalState current,
  ) {
    final e = (row['expense']! as Map).cast<String, Object?>(),
        f = ((row['expense']! as Map)['funding']! as Map)
            .cast<String, Object?>();
    return spending.editExpenseIntent(
      operationId: op,
      expenseId: id,
      expectedActiveJournalId: active,
      inverseJournalId: inverse,
      replacementJournalId: replacement,
      date: CatalogFormatters.parseDate(row['date']! as String),
      categoryId: e['categoryId']! as String,
      amount: BigInt.from(e['amount']! as int),
      fundingSource: FundingSource.values.byName(f['source']! as String),
      dailyAmount: BigInt.from(f['dailyAmount']! as int),
      cashAmount: BigInt.from(f['cashAmount']! as int),
      note: e['note']! as String,
      reason: reason,
      recordedAt: stamp,
      profile: spending.expenseCorrectionCommands.mapper.profile,
      policy: _activeExpense(before, id)?.journal.policy,
      sourceOrder: _order(before, current, DeletedSpendingKind.expense, id),
    );
  }

  PortableJournalEntry? _activeExpense(PortableJournalState state, String id) {
    final matches = state.journals
        .where(
          (j) =>
              j.sourceRecordId == id &&
              RestaurantJournalExpenseHistory.validate(
                state: state,
                expenseId: id,
                mapper: spending.expenseCorrectionCommands.mapper,
                expectedActiveJournalId: j.journal.id,
              ),
        )
        .toList();
    return matches.length == 1 ? matches.single : null;
  }

  PortableJournalEntry? _activeTransfer(PortableJournalState state, String id) {
    final matches = state.journals
        .where(
          (j) =>
              j.sourceRecordId == id &&
              RestaurantJournalTransferHistory.validateTransferLineage(
                state: state,
                transferId: id,
                mapper: spending.transferCorrectionCommands.mapper,
                expectedActiveJournalId: j.journal.id,
              ),
        )
        .toList();
    return matches.length == 1 ? matches.single : null;
  }

  static List<Map<String, Object?>> _rows(
    PortableJournalState s,
    String key,
    String id,
  ) => (s.account.toJson()[key]! as List)
      .map((e) => (e as Map).cast<String, Object?>())
      .where((e) => e['id'] == id)
      .toList();
  static List<Map<String, Object?>> _familyRows(
    PortableJournalState s,
    DeletedSpendingKind family,
    String id,
  ) => family == DeletedSpendingKind.expense
      ? RestaurantJournalExpenseHistory.sourceRows(s, id)
      : _rows(
          s,
          family == DeletedSpendingKind.transfer ? 'transfers' : 'transactions',
          id,
        );
  static void _assertAffected(
    PortableJournalState after,
    PortableJournalState current,
    DeletedSpendingKind family,
    String id,
  ) {
    if (after.accountLineage != current.accountLineage ||
        canonicalIdentity({'rows': _familyRows(after, family, id)}) !=
            canonicalIdentity({'rows': _familyRows(current, family, id)})) {
      throw const FormatException('undo_source_changed');
    }
  }

  static List<Map<String, Object?>> _list(
    PortableJournalState state,
    DeletedSpendingKind family, {
    String? date,
  }) => family == DeletedSpendingKind.expense
      ? (((state.account.days[date]! as Map)['expenses']! as List)
            .cast<Map<String, Object?>>())
      : (state.account.toJson()[family == DeletedSpendingKind.transfer
                    ? 'transfers'
                    : 'transactions']!
                as List)
            .cast<Map<String, Object?>>();
  static SourceRecordOrder _order(
    PortableJournalState before,
    PortableJournalState current,
    DeletedSpendingKind family,
    String id,
  ) {
    final old = _familyRows(before, family, id).single;
    final date = family == DeletedSpendingKind.expense
        ? old['date']! as String
        : null;
    return SourceRecordOrder(
      position: _list(
        before,
        family,
        date: date,
      ).indexWhere((r) => r['id'] == id),
      siblingIds: _list(
        current,
        family,
        date: date,
      ).where((r) => r['id'] != id).map((r) => r['id']! as String),
    );
  }

  /// Expected candidate changes only the retained affected source; all unrelated
  /// current source, including compensating stock history, stays byte-equivalent.
  static Map<String, Object?> _expected(
    PortableJournalState before,
    PortableJournalState current,
    DeletedSpendingKind family,
    String id,
  ) {
    final raw = (jsonDecode(jsonEncode(current.account.toJson())) as Map)
        .cast<String, Object?>();
    final old = _familyRows(before, family, id);
    if (family == DeletedSpendingKind.expense) {
      final days = (raw['days']! as Map).cast<String, Object?>();
      for (final day in days.values) {
        final d = (day! as Map).cast<String, Object?>();
        d['expenses'] = (d['expenses']! as List)
            .where((r) => (r as Map)['id'] != id)
            .toList();
      }
      if (old.isNotEmpty) {
        final source = old.single,
            day = (days[source['date']]! as Map).cast<String, Object?>();
        final rows = (day['expenses']! as List)
            .map((r) => (r as Map).cast<String, Object?>())
            .toList();
        rows.insert(
          _order(before, current, family, id).position,
          (source['expense']! as Map).cast<String, Object?>(),
        );
        day['expenses'] = rows;
      }
    } else {
      final key = family == DeletedSpendingKind.transfer
          ? 'transfers'
          : 'transactions';
      final rows = (raw[key]! as List)
          .map((r) => (r as Map).cast<String, Object?>())
          .where((r) => r['id'] != id)
          .toList();
      if (old.isNotEmpty) {
        rows.insert(_order(before, current, family, id).position, old.single);
      }
      raw[key] = rows;
    }
    return raw;
  }

  static void _requireRestored(
    DurableProposalEvaluation<PortableJournalState, dynamic> proposal,
    Map<String, Object?> expected,
  ) {
    if (proposal.rejected) {
      throw FormatException(proposal.rejectionCode ?? 'undo_not_reconciled');
    }
    if (proposal.candidateState == null ||
        canonicalIdentity(proposal.candidateState!.account.toJson()) !=
            canonicalIdentity(expected)) {
      throw const FormatException('undo_complete_source_restore_required');
    }
  }
}
