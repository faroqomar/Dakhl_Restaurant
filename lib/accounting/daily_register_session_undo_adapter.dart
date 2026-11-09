import 'dart:convert';

import 'package:madar_application/madar_application.dart';

import '../accounts/portable_journal_state.dart';
import '../catalog/catalog_formatters.dart';
import 'daily_register_snapshot_controller.dart';
import 'financial_session_undo.dart';

final class DailyRegisterSessionUndoAdapter implements FinancialUndoAdapter {
  DailyRegisterSessionUndoAdapter({
    required this.register,
    required this.identity,
  });
  final DailyRegisterSnapshotController register;
  final DurableCommandIdentity identity;
  @override
  String get label => 'آخر تسجيل يومي';
  @override
  FinancialUndoAttempt prepare({
    required PortableJournalState before,
    required PortableJournalState after,
    required PortableJournalState current,
  }) {
    if (register.busy || register.needsReadback || register.externallyBlocked) {
      throw const FormatException('busy');
    }
    final intent = (jsonDecode(identity.canonicalPayloadIdentity) as Map)
        .cast<String, Object?>();
    if (![
          'record_remaining',
          'record_balance',
          'record_total',
        ].contains(intent['type']) ||
        !after.receipts.any(
          (r) =>
              r.identity == identity &&
              r.status == DurableCommandStatus.committed,
        )) {
      throw const FormatException('undo_original_mismatch');
    }
    final command = RestoreDailyRegisterCommand(
      operationId: CatalogFormatters.generateId('undo-register'),
      date: intent['date']! as String,
      accountLineage: current.accountLineage,
      expectedFence: register.authorityFence,
      recordedAt: CatalogFormatters.currentIsoTimestamp(),
      expectedRevision: register.snapshot.revision,
      originalIdentity: identity,
      expectedAccount: current.account.toJson(),
      beforeAccount: before.account.toJson(),
      afterAccount: after.account.toJson(),
    );
    final proposal = evaluateDailyRegisterRestore(
      command: command,
      state: current,
      fence: register.authorityFence,
    );
    if (proposal.rejected) {
      throw FormatException(proposal.rejectionCode ?? 'undo_not_reconciled');
    }
    return FinancialUndoAttempt(() => register.submitRestoration(command));
  }
}
