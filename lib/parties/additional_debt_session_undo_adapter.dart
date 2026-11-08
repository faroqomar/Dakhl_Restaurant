import 'dart:convert';

import 'package:madar_application/madar_application.dart';

import '../accounts/portable_journal_state.dart';
import '../accounting/financial_session_undo.dart';
import '../accounting/journal_command_host.dart';
import '../catalog/catalog_formatters.dart';
import 'additional_debt_commands.dart';
import 'additional_debt_controller.dart';

/// Compensates acknowledged debt changes through their retained journal family.
/// Deleted debt restoration appends a replacement instead of reversing an inverse.
final class AdditionalDebtSessionUndoAdapter implements FinancialUndoAdapter {
  AdditionalDebtSessionUndoAdapter({
    required this.controller,
    required this.identity,
  });
  final AdditionalDebtController controller;
  final DurableCommandIdentity identity;
  @override
  String get label => 'آخر دين إضافي';
  @override
  FinancialUndoAttempt prepare({
    required PortableJournalState before,
    required PortableJournalState after,
    required PortableJournalState current,
  }) {
    if (controller.busy ||
        controller.needsReadback ||
        controller.isWriteBlocked()) {
      throw const FormatException('busy');
    }
    if (!after.receipts.any(
      (r) =>
          r.identity == identity && r.status == DurableCommandStatus.committed,
    )) {
      throw const FormatException('undo_original_mismatch');
    }
    final original = AdditionalDebtCommand.fromIntent(
      (jsonDecode(identity.canonicalPayloadIdentity) as Map)
          .cast<String, Object?>(),
      controller.coordinator.mapper,
    );
    final saved = AdditionalDebtHistory.rows(after, original.debtId);
    final active = AdditionalDebtHistory.rows(current, original.debtId);
    if (original.kind == 'delete'
        ? saved.isNotEmpty || active.isNotEmpty
        : saved.length != 1 ||
              active.length != 1 ||
              canonicalIdentity(saved.single) !=
                  canonicalIdentity(active.single)) {
      throw const FormatException('undo_source_changed');
    }
    if (original.kind == 'delete' &&
        AdditionalDebtHistory.validate(
              current,
              original.debtId,
              controller.coordinator.mapper,
            )?.deletion?.identity !=
            identity) {
      throw const FormatException('undo_deleted_debt_family_changed');
    }
    final prior = AdditionalDebtHistory.rows(before, original.debtId);
    final command = controller.capture(
      kind: original.kind == 'delete'
          ? 'restore'
          : ['create', 'restore'].contains(original.kind)
          ? 'delete'
          : 'edit',
      operationId: CatalogFormatters.generateId('undo-debt'),
      debtId: original.debtId,
      supplierId: original.kind != 'edit'
          ? null
          : prior.single['supplierId']! as String,
      date: original.kind != 'edit' ? null : prior.single['date']! as String,
      amount: original.kind != 'edit'
          ? null
          : BigInt.from(prior.single['amount']! as int),
      note: original.kind != 'edit' ? '' : prior.single['note']! as String,
      reason: 'تراجع عن التغيير السابق',
      recordedAt: CatalogFormatters.currentIsoTimestamp(),
    );
    final proposal = controller.coordinator.evaluate(command, current);
    if (proposal.rejected) {
      throw FormatException(proposal.rejectionCode ?? 'undo_refused');
    }
    return FinancialUndoAttempt(() => controller.submit(command));
  }
}
