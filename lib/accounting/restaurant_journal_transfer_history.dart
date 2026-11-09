import 'dart:convert';

import 'correction_batch_receipts.dart';
import 'deleted_spending_restoration.dart';
import 'source_record_order.dart';

import 'package:madar_application/madar_application.dart';
import 'package:madar_domain/madar_domain.dart';

import '../accounts/portable_journal_state.dart';
import 'journal_command_host.dart' as snapshots;
import 'restaurant_journal_mapper.dart';
import 'restaurant_journal_transfer_commands.dart';
import 'restaurant_journal_transfer_correction_commands.dart';

/// Reconciles app-owned transfer history with captured durable command intent.
final class RestaurantJournalTransferHistory {
  const RestaurantJournalTransferHistory._();

  static String canonicalIdentity(Map<String, Object?> values) =>
      snapshots.canonicalIdentity(values);

  static Map<String, Object?> freezeMetadata(Map<String, Object?> values) =>
      snapshots.freezeMap(values);

  /// Reconstructs the exact correction envelopes from validated predecessor and
  /// captured intent. Stored correction metadata is never its own authority.
  static List<PortableJournalEntry> correctionEntries({
    required PortableJournalEntry target,
    required String transferId,
    required String operationId,
    required String inverseJournalId,
    String? replacementJournalId,
    BigInt? newAmount,
    DateOnly? newDate,
    required String reason,
    required String recordedAt,
    required Map<String, Object?> beforeSnapshot,
    required RestaurantJournalMapper mapper,
    JournalPolicy? policy,
  }) {
    final sourceVersion = int.parse(
      target.metadata['sourceVersion'].toString(),
    );
    final original = RestaurantJournalProposal(
      journal: target.journal,
      sourceType: RestaurantJournalSourceType.values.byName(target.sourceType),
      sourceRecordId: transferId,
      receiptNumber: target.journal.id,
      sourceVersion: sourceVersion,
      metadata: target.metadata,
    );
    final inverse = mapper.mapOriginalDateVoid(
      originalProposal: original,
      reversalJournalId: inverseJournalId,
      reason: reason.trim(),
      isEligible: true,
      voidRecordId: transferId,
    );
    final after = replacementJournalId == null
        ? <String, Object?>{'deleted': true, 'id': transferId}
        : <String, Object?>{
            ...beforeSnapshot,
            'amount': newAmount!.toInt(),
            if (newDate != null) 'date': newDate.toString(),
          };
    final inverseMetadata = <String, Object?>{
      ...target.metadata,
      'operationId': operationId,
      'transferId': transferId,
      'targetJournalId': target.journal.id,
      'replacementJournalId': ?replacementJournalId,
      'reversalReason': reason.trim(),
      'originalJournalId': target.journal.id,
      'beforeSnapshot': beforeSnapshot,
      'afterSnapshot': after,
      'sourceVersion': inverse.sourceVersion,
    };
    final entries = <PortableJournalEntry>[
      PortableJournalEntry(
        journal: inverse.journal,
        sourceType: inverse.sourceType.name,
        sourceRecordId: transferId,
        replacementJournalId: replacementJournalId,
        recordedAt: recordedAt,
        metadata: inverseMetadata,
      ),
    ];
    if (replacementJournalId != null) {
      final replacement = mapper.mapReplacementProposal(
        newProposal: mapper.mapDailyToCashboxTransfer(
          journalId: replacementJournalId,
          transferId: transferId,
          effectiveDate: newDate ?? target.journal.effectiveDate,
          amount: newAmount!,
          policy: policy ?? target.journal.policy,
        ),
        correctedFromId: target.journal.id,
      );
      entries.add(
        PortableJournalEntry(
          journal: replacement.journal,
          sourceType: replacement.sourceType.name,
          sourceRecordId: transferId,
          correctedFromJournalId: target.journal.id,
          recordedAt: recordedAt,
          metadata: {
            'amount': newAmount.toInt(),
            'correctedFromId': target.journal.id,
            'operationId': operationId,
            'transferId': transferId,
            'inverseJournalId': inverseJournalId,
            'beforeSnapshot': beforeSnapshot,
            'afterSnapshot': after,
            'sourceVersion': replacement.sourceVersion,
          },
        ),
      );
    }
    return List.unmodifiable(entries);
  }

  /// Validates one complete, receipt-backed, linear create/edit/delete history.
  /// Optional original-command anchors bind historical create replay.
  static bool validateTransferLineage({
    required PortableJournalState state,
    required String transferId,
    required RestaurantJournalMapper mapper,
    String? initialJournalId,
    BigInt? initialAmount,
    DateOnly? initialDate,
    String? initialRecordedAt,
    String? expectedActiveJournalId,
  }) {
    try {
      final roots = state.journals.where(
        (entry) =>
            entry.sourceRecordId == transferId &&
            entry.sourceType ==
                RestaurantJournalSourceType.cashboxTransfer.name,
      );
      if (roots.length != 1) return false;
      final root = roots.single;
      final usedEntries = <String>{root.journal.id};
      final usedReceipts = <String>{};
      final createReceipt = _receipt(state, root.metadata['operationId']);
      final createIntent = _intent(createReceipt, state, transferId);
      final create = DailyToCashboxTransferCommand(
        operationId: createIntent['operationId'] as String,
        payloadVersion: createIntent['payloadVersion'] as int,
        accountLineage: createIntent['accountLineage'] as String,
        expectedFence: _fence(createIntent),
        transferId: createIntent['transferId'] as String,
        journalId: createIntent['journalId'] as String,
        date: _date(createIntent['date']),
        amount: BigInt.parse(createIntent['amount'] as String),
        recordedAt: createIntent['recordedAt'] as String,
        policy: _policy(createIntent['policy']),
      );
      if (create.identity != createReceipt.identity ||
          create.commandType != createIntent['commandType'] ||
          create.journalId != root.journal.id ||
          (initialJournalId != null && create.journalId != initialJournalId) ||
          (initialAmount != null && create.amount != initialAmount) ||
          (initialDate != null && create.date != initialDate) ||
          (initialRecordedAt != null &&
              create.recordedAt != initialRecordedAt) ||
          create.date.compareTo(state.cutoverState.cutoverDate!) < 0) {
        return false;
      }
      final mapped = mapper.mapDailyToCashboxTransfer(
        journalId: create.journalId,
        transferId: transferId,
        effectiveDate: create.date,
        amount: create.amount,
        policy: create.policy,
      );
      final metadata = <String, Object?>{
        'operationId': create.operationId,
        'transferId': transferId,
        'date': create.date.toString(),
        'amount': create.amount.toString(),
        'sourceVersion': mapped.sourceVersion.toString(),
      };
      final expectedRoot = PortableJournalEntry(
        journal: mapped.journal,
        sourceType: mapped.sourceType.name,
        sourceRecordId: transferId,
        recordedAt: create.recordedAt,
        metadata: metadata,
      );
      if (!_same(root.toJson(), expectedRoot.toJson()) ||
          !_same(
            _outcome(createReceipt),
            RestaurantJournalTransferOutcome(
              commandType: create.commandType,
              operationId: create.operationId,
              transferId: transferId,
              journalId: create.journalId,
              effectiveDate: create.date.toString(),
              netAmount: create.amount.toString(),
              metadata: metadata,
            ).toJson(),
          )) {
        return false;
      }
      usedReceipts.add(create.operationId);
      var previousSequence = createReceipt.sequence;
      var previousJournalIndex = state.journals.indexOf(root);
      PortableJournalEntry? active = root;
      var source = <String, Object?>{
        'id': transferId,
        'date': create.date.toString(),
        'amount': create.amount.toInt(),
        'createdAt': create.recordedAt,
      };
      while (active != null) {
        final reversals = state.journals
            .where((entry) => entry.journal.reversesId == active!.journal.id)
            .toList();
        if (reversals.isEmpty) break;
        if (reversals.length != 1) return false;
        final inverse = reversals.single;
        final receipt = _receipt(state, inverse.metadata['operationId']);
        final intent = _intent(receipt, state, transferId);
        if (receipt.sequence <= previousSequence ||
            !usedReceipts.add(receipt.identity.operationId)) {
          return false;
        }
        previousSequence = receipt.sequence;
        if (intent['newDate'] != null &&
            (state.cutoverState.cutoverDate == null ||
                _date(intent['newDate'])
                        .compareTo(state.cutoverState.cutoverDate!) <
                    0)) {
          return false;
        }
        final isEdit = intent['commandType'] == 'edit_daily_transfer';
        final isDelete = intent['commandType'] == 'delete_daily_transfer';
        if (!isEdit && !isDelete) return false;
        final inverseId = intent['inverseJournalId'] as String;
        final targetId = intent['expectedActiveJournalId'] as String;
        final operationId = intent['operationId'] as String;
        final reason = intent['reason'] as String;
        final recordedAt = intent['recordedAt'] as String;
        final policy = _policy(intent['policy']);
        final replacementId = isEdit
            ? intent['replacementJournalId'] as String
            : null;
        final amount = isEdit
            ? BigInt.parse(intent['newAmount'] as String)
            : null;
        final identity = isEdit
            ? EditDailyTransferCommand(
                operationId: operationId,
                payloadVersion: intent['payloadVersion'] as int,
                accountLineage: state.accountLineage,
                expectedFence: _fence(intent),
                transferId: transferId,
                expectedActiveJournalId: targetId,
                inverseJournalId: inverseId,
                replacementJournalId: replacementId!,
                newAmount: amount!,
                sourceOrder: intent['sourceOrder'] == null
                    ? null
                    : SourceRecordOrder.fromJson(
                        (intent['sourceOrder']! as Map).cast<String, Object?>(),
                      ),
                newDate: intent['newDate'] == null
                    ? null
                    : _date(intent['newDate']),
                reason: reason,
                recordedAt: recordedAt,
                policy: policy,
              ).identity
            : DeleteDailyTransferCommand(
                operationId: operationId,
                payloadVersion: intent['payloadVersion'] as int,
                accountLineage: state.accountLineage,
                expectedFence: _fence(intent),
                transferId: transferId,
                expectedActiveJournalId: targetId,
                inverseJournalId: inverseId,
                reason: reason,
                recordedAt: recordedAt,
                policy: policy,
              ).identity;
        if (identity != receipt.identity ||
            targetId != active.journal.id ||
            inverseId != inverse.journal.id) {
          return false;
        }
        final expected = correctionEntries(
          target: active,
          transferId: transferId,
          operationId: operationId,
          inverseJournalId: inverseId,
          replacementJournalId: replacementId,
          newAmount: amount,
          newDate: intent['newDate'] == null ? null : _date(intent['newDate']),
          reason: reason,
          recordedAt: recordedAt,
          beforeSnapshot: source,
          mapper: mapper,
          policy: policy,
        );
        for (final entry in expected) {
          final actual = state.journals.where(
            (j) => j.journal.id == entry.journal.id,
          );
          if (actual.length != 1 ||
              !usedEntries.add(entry.journal.id) ||
              !_same(actual.single.toJson(), entry.toJson())) {
            return false;
          }
          final index = state.journals.indexOf(actual.single);
          if (index <= previousJournalIndex) {
            return false;
          }
          previousJournalIndex = index;
        }
        final expectedOutcome = RestaurantJournalTransferCorrectionOutcome(
          commandType: intent['commandType'] as String,
          operationId: operationId,
          transferId: transferId,
          targetJournalId: active.journal.id,
          inverseJournalId: inverseId,
          replacementJournalId: replacementId,
          effectiveDate: expected.last.journal.effectiveDate.toString(),
          netAmount: (amount ?? active.journal.totalUnits).toString(),
          metadata: expected.last.metadata,
        );
        if (!_same(_outcome(receipt), expectedOutcome.toJson())) return false;
        final deletedTarget = active;
        active = isEdit ? expected.last : null;
        if (isDelete) {
          final restored = DeletedSpendingRestorationHistory.afterDelete(
            state: state,
            kind: DeletedSpendingKind.transfer,
            recordId: transferId,
            deleted: deletedTarget,
            inverse: expected.first,
            deletion: receipt,
            source: source,
            mapper: mapper,
          );
          if (restored != null) {
            if (!usedEntries.add(restored.entry.journal.id) ||
                !usedReceipts.add(restored.receipt.identity.operationId) ||
                restored.receipt.sequence <= previousSequence ||
                state.journals.indexOf(restored.entry) <=
                    previousJournalIndex) {
              return false;
            }
            previousSequence = restored.receipt.sequence;
            previousJournalIndex = state.journals.indexOf(restored.entry);
            active = restored.entry;
          }
        }
        if (isEdit) {
          source = {
            ...source,
            'amount': amount!.toInt(),
            if (intent['newDate'] != null) 'date': intent['newDate'],
          };
        }
      }
      if (expectedActiveJournalId != null &&
          active?.journal.id != expectedActiveJournalId) {
        return false;
      }
      for (final entry in state.journals) {
        final transferOwned =
            entry.sourceRecordId == transferId &&
            (entry.sourceType ==
                    RestaurantJournalSourceType.cashboxTransfer.name ||
                entry.metadata['transferId'] == transferId);
        final linked =
            usedEntries.contains(entry.journal.reversesId) ||
            usedEntries.contains(entry.correctedFromJournalId);
        if ((transferOwned || linked) &&
            !usedEntries.contains(entry.journal.id)) {
          return false;
        }
      }
      for (final receipt in correctionReceiptViews(state)) {
        if (receipt.status != DurableCommandStatus.committed) continue;
        Object? intent;
        try {
          intent = jsonDecode(receipt.identity.canonicalPayloadIdentity);
        } on FormatException {
          // Other command families may use opaque non-JSON identities.
          continue;
        }
        if (intent is Map &&
            intent['transferId'] == transferId &&
            const {
              'daily_to_cashbox_transfer',
              'edit_daily_transfer',
              'delete_daily_transfer',
              'restore_deleted_transfer',
            }.contains(intent['commandType']) &&
            !usedReceipts.contains(receipt.identity.operationId)) {
          return false;
        }
      }
      final rows = (state.account.toJson()['transfers'] as List)
          .cast<Map<String, Object?>>()
          .where((row) => row['id'] == transferId)
          .toList();
      return active == null
          ? rows.isEmpty
          : rows.length == 1 && _same(rows.single, source);
    } catch (_) {
      return false;
    }
  }

  static DurableCommandReceipt _receipt(
    PortableJournalState state,
    Object? operationId,
  ) {
    final matches = correctionReceiptViews(state).where(
      (r) =>
          r.identity.operationId == operationId &&
          r.status == DurableCommandStatus.committed,
    );
    if (matches.length != 1) {
      throw const FormatException('missing_transfer_receipt');
    }
    return matches.single;
  }

  static Map<String, Object?> _intent(
    DurableCommandReceipt receipt,
    PortableJournalState state,
    String transferId,
  ) {
    final intent = (jsonDecode(
      receipt.identity.canonicalPayloadIdentity,
    ) as Map).cast<String, Object?>();
    if (intent['accountLineage'] != state.accountLineage ||
        intent['transferId'] != transferId ||
        intent['operationId'] != receipt.identity.operationId ||
        intent['payloadVersion'] != receipt.identity.payloadVersion ||
        _fence(intent) != receipt.fence) {
      throw const FormatException('invalid_transfer_intent');
    }
    return intent;
  }

  static StorageFence? _fence(Map<String, Object?> intent) {
    final fence = intent['expectedFence'];
    if (fence == null) return null;
    final map = (fence as Map).cast<String, Object?>();
    if (map.length != 2) throw const FormatException('invalid_transfer_fence');
    return StorageFence(
      storeId: map['storeId'] as String,
      generation: map['generation'] as String,
    );
  }

  static JournalPolicy? _policy(Object? value) {
    if (value == null) return null;
    final map = (value as Map).cast<String, Object?>();
    if (map.length != 6) throw const FormatException('invalid_transfer_policy');
    return JournalPolicy(
      currency: map['currency'] as String,
      scale: map['scale'] as int,
      maximumLines: map['maximumLines'] as int,
      maximumLineUnits: BigInt.parse(map['maximumLineUnits'] as String),
      maximumSideUnits: BigInt.parse(map['maximumSideUnits'] as String),
      allowZeroLines: map['allowZeroLines'] as bool,
    );
  }

  static DateOnly _date(Object? value) =>
      DateOnly.parse(value as String, minimumYear: 1000, maximumYear: 9999);
  static Map<String, Object?> _outcome(DurableCommandReceipt receipt) =>
      (jsonDecode(receipt.outcomePayload!) as Map).cast<String, Object?>();
  static bool _same(Map<String, Object?> a, Map<String, Object?> b) =>
      canonicalIdentity(a) == canonicalIdentity(b);
}
