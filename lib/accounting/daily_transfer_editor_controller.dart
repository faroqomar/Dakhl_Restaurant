import 'package:madar_application/madar_application.dart';
import 'package:madar_domain/madar_domain.dart';

import '../accounts/portable_journal_codec.dart';
import '../catalog/catalog_formatters.dart';
import 'restaurant_journal_transfer_commands.dart';
import 'restaurant_journal_transfer_history.dart';
import 'spending_operations_view_model.dart';

/// Captures one source-defined transfer form intent; command owners retain all
/// balance, posting, lineage and persistence validation.
final class DailyTransferEditorController {
  DailyTransferEditorController({
    required this.spending,
    required String date,
    Map<String, Object?>? transfer,
  }) : original = transfer == null ? null : Map.unmodifiable(transfer),
       date = transfer?['date'] as String? ?? date,
       amount =
           '${transfer?['amount'] ?? spending.daySnapshot(date).remaining ?? 0}' {
    if (transfer != null) {
      final state = const PortableJournalCodec().decodeState(
        spending.snapshot.payload,
      );
      for (final entry in state.journals.reversed) {
        if (entry.sourceRecordId == transfer['id'] &&
            RestaurantJournalTransferHistory.validateTransferLineage(
              state: state,
              transferId: transfer['id']! as String,
              mapper: spending.transferCorrectionCommands.mapper,
              expectedActiveJournalId: entry.journal.id,
            )) {
          _activeJournalId = entry.journal.id;
          break;
        }
      }
    }
  }
  final SpendingOperationsViewModel spending;
  final String date;
  final Map<String, Object?>? original;
  String amount, reason = '';
  String? _activeJournalId;
  Object? _intent;
  bool _busy = false;
  bool get busy => _busy;
  bool get pending => _intent != null;
  bool get editable => original == null || _activeJournalId != null;
  BigInt? get available => spending.daySnapshot(date).remaining;
  static final _money = ExactIntegerPolicy(
    maxAbs: BigInt.from(1000000000000),
    maxSafeInteger: BigInt.parse('9007199254740991'),
    signed: false,
    positive: true,
  );
  CapabilityFailure<void> _fail(String code) =>
      CapabilityFailure(code, 'Transfer change was not confirmed.');

  Future<CapabilityResult<void>> save({bool delete = false}) async {
    if (_busy) return _fail('busy');
    if (!editable) return _fail('missing_original_posting');
    if (_intent == null) {
      if (!spending.postingEnabled || spending.busy || spending.needsReadback) {
        return _fail('busy');
      }
      try {
        final operation = CatalogFormatters.generateId('transfer-op');
        final recordedAt = CatalogFormatters.currentIsoTimestamp();
        if (delete) {
          if (original == null) return _fail('transfer_not_found');
          _intent = spending.deleteTransferIntent(
            operationId: operation,
            transferId: original!['id']! as String,
            expectedActiveJournalId: _activeJournalId!,
            inverseJournalId: 'inverse-$operation',
            reason: reason,
            recordedAt: recordedAt,
          );
        } else {
          final units = _money.parse(
            amount,
            normalizeDigits: true,
            allowGrouping: true,
          );
          _intent = original == null
              ? spending.transferIntent(
                  operationId: operation,
                  transferId: 'transfer-$operation',
                  journalId: 'journal-$operation',
                  date: DateOnly.parse(
                    date,
                    minimumYear: 1000,
                    maximumYear: 9999,
                  ),
                  amount: units,
                  recordedAt: recordedAt,
                )
              : spending.editTransferIntent(
                  operationId: operation,
                  transferId: original!['id']! as String,
                  expectedActiveJournalId: _activeJournalId!,
                  inverseJournalId: 'inverse-$operation',
                  replacementJournalId: 'replacement-$operation',
                  newAmount: units,
                  reason: reason,
                  recordedAt: recordedAt,
                );
        }
      } on Object {
        return _fail('invalid_transfer_input');
      }
    }
    _busy = true;
    try {
      final command = _intent!;
      final DurableCommandResult result =
          command is DailyToCashboxTransferCommand
          ? await spending.submitTransfer(command)
          : await spending.submitTransferCorrection(command);
      if (result is DurableCommandSuccess || result is DurableCommandReplayed) {
        _intent = null;
        return const CapabilitySuccess<void>(null);
      }
      final code = (result as DurableCommandFailure).code;
      if (code != DurableCommandErrorCodes.commitUnknown &&
          code != DocumentErrorCodes.pendingWrite) {
        _intent = null;
      }
      return _fail(code);
    } on Object {
      return _fail('commit_unknown');
    } finally {
      _busy = false;
    }
  }
}
