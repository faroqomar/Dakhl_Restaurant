import 'dart:convert';

import 'package:madar_application/madar_application.dart';

import '../accounts/portable_journal_state.dart';
import '../catalog/catalog_formatters.dart';
import 'day_date_correction_controller.dart';
import 'financial_session_undo.dart';
import 'journal_command_host.dart';

/// An inverse source-range operation creates a new receipt and compensating
/// postings. Exact receipt-bound inverse mappings preserve unrelated gaps.
final class DayDateSessionUndoAdapter implements FinancialUndoAdapter {
  DayDateSessionUndoAdapter({required this.dates, required this.identity});
  final DayDateCorrectionController dates;
  final DurableCommandIdentity identity;
  @override
  String get label => 'آخر تصحيح تاريخ';
  @override
  FinancialUndoAttempt prepare({
    required PortableJournalState before,
    required PortableJournalState after,
    required PortableJournalState current,
  }) {
    if (!after.receipts.any(
      (r) =>
          r.identity == identity && r.status == DurableCommandStatus.committed,
    )) {
      throw const FormatException('undo_original_mismatch');
    }
    final intent = (jsonDecode(identity.canonicalPayloadIdentity) as Map)
        .cast<String, Object?>();
    if (intent['commandType'] != 'day_date_correction' ||
        canonicalIdentity(
              (intent['expectedAccount']! as Map).cast<String, Object?>(),
            ) !=
            canonicalIdentity(before.account.toJson())) {
      throw const FormatException('undo_original_mismatch');
    }
    final receipt = after.receipts.singleWhere((r) => r.identity == identity),
        outcome = (jsonDecode(receipt.outcomePayload!) as Map)
            .cast<String, Object?>();
    final mapping = (outcome['mapping']! as Map).cast<String, String>();
    final destinations = mapping.values.toList()..sort();
    if (destinations.isEmpty) throw const FormatException('nothing_to_undo');
    final command = dates.capture(
      operationId: CatalogFormatters.generateId('undo-day-date'),
      from: intent['to']! as String,
      to: intent['from']! as String,
      end: destinations.last,
      reason: 'تراجع عن التصحيح السابق',
      recordedAt: CatalogFormatters.currentIsoTimestamp(),
      inverseOf: identity,
    );
    return FinancialUndoAttempt(() => dates.submit(command));
  }
}
