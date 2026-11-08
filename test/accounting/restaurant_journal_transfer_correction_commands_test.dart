import 'package:flutter_test/flutter_test.dart';
import 'package:madar_application/madar_application.dart';
import 'package:madar_domain/madar_domain.dart';
import 'package:dakhl_restaurant/accounting/daily_cash_queries.dart';
import 'package:dakhl_restaurant/accounting/restaurant_journal_mapper.dart';
import 'package:dakhl_restaurant/accounting/restaurant_journal_transfer_commands.dart';
import 'package:dakhl_restaurant/accounting/restaurant_journal_transfer_correction_commands.dart';
import 'package:dakhl_restaurant/accounts/legacy_account_codec.dart';
import 'package:dakhl_restaurant/accounts/portable_journal_state.dart';

void main() {
  const legacyCodec = LegacyAccountCodec();
  final mapper = RestaurantJournalMapper();
  final cutoverDate = DateOnly.parse(
    '2026-01-01',
    minimumYear: 1000,
    maximumYear: 9999,
  );
  final transferDate = DateOnly.parse(
    '2026-01-15',
    minimumYear: 1000,
    maximumYear: 9999,
  );
  final preCutoverDate = DateOnly.parse(
    '2025-12-31',
    minimumYear: 1000,
    maximumYear: 9999,
  );

  PortableJournalState createBaselineState({
    bool includeTransfer = true,
    int transferAmount = 20000,
    bool nullBalance = false,
    bool preCutover = false,
  }) {
    final activeDate = preCutover ? preCutoverDate : transferDate;
    final dateKey = activeDate.toString();

    final dayMap = <String, Object?>{
      'expenses': <Object?>[],
      'chickenUsed': 0,
      'chickenLeft': 0,
      'balance': nullBalance ? null : 100000,
      'totalOverride': null,
      'remaining': {
        'amount': 100000,
        'dailySpent': 0,
        'transferred': 0,
        'salesTotal': 0,
      },
    };

    final transfersList = <Map<String, Object?>>[
      if (includeTransfer)
        {
          'id': 't1',
          'date': dateKey,
          'amount': transferAmount,
          'createdAt': '2026-01-15T10:00:00.000Z',
        },
    ];

    final accountMap = <String, Object?>{
      ...legacyCodec.empty().toJson(),
      'days': {dateKey: dayMap},
      'transfers': transfersList,
    };

    final account = legacyCodec.decodeJson(accountMap);

    final journals = <PortableJournalEntry>[];
    if (includeTransfer) {
      final transferProposal = mapper.mapDailyToCashboxTransfer(
        journalId: 'j1',
        transferId: 't1',
        effectiveDate: activeDate,
        amount: BigInt.from(transferAmount),
      );
      journals.add(
        PortableJournalEntry(
          journal: transferProposal.journal,
          sourceType: transferProposal.sourceType.name,
          sourceRecordId: 't1',
          recordedAt: '2026-01-15T10:00:00.000Z',
          metadata: {
            'operationId': 'op-initial',
            'transferId': 't1',
            'date': dateKey,
            'amount': transferAmount.toString(),
            'sourceVersion': '11',
          },
        ),
      );
    }

    return PortableJournalState(
      accountLineage: 'restaurant-lineage-1',
      account: account,
      sourceProvenance: const PortableJournalSourceProvenance(
        sourceVersion: 11,
        enrolledAt: '2026-01-01T00:00:00.000Z',
        migrated: false,
      ),
      cutoverState: PortableJournalCutoverState.established(
        cutoverDate: cutoverDate,
        openingJournalId: 'opening-j1',
      ),
      journals: [
        PortableJournalEntry(
          journal: BalancedJournal.validate(
            id: 'opening-j1',
            effectiveDate: cutoverDate,
            policy: RestaurantJournalPolicies.opening,
            lines: [
              JournalLine(
                accountId: 'asset:cash:daily',
                side: JournalSide.debit,
                amountUnits: BigInt.from(100000),
                currency: 'IQD',
                scale: 0,
              ),
              JournalLine(
                accountId: 'equity:opening_balance',
                side: JournalSide.credit,
                amountUnits: BigInt.from(100000),
                currency: 'IQD',
                scale: 0,
              ),
            ],
          ),
          sourceType: RestaurantJournalSourceType.cutoverOpening.name,
          recordedAt: '2026-01-01T00:00:00.000Z',
        ),
        ...journals,
      ],
      receipts: [
        if (includeTransfer)
          DurableCommandReceipt(
            identity: DailyToCashboxTransferCommand(
              operationId: 'op-initial',
              accountLineage: 'restaurant-lineage-1',
              expectedFence: const StorageFence(
                storeId: 'fixture-store',
                generation: 'fixture-generation',
              ),
              transferId: 't1',
              journalId: 'j1',
              date: activeDate,
              amount: BigInt.from(transferAmount),
              recordedAt: '2026-01-15T10:00:00.000Z',
            ).identity,
            status: DurableCommandStatus.committed,
            outcomePayload: RestaurantJournalTransferOutcome(
              commandType: 'daily_to_cashbox_transfer',
              operationId: 'op-initial',
              transferId: 't1',
              journalId: 'j1',
              effectiveDate: dateKey,
              netAmount: transferAmount.toString(),
              metadata: journals.single.metadata,
            ).toOutcomePayload(),
            committedRevision: 1,
            sequence: 1,
            fence: const StorageFence(
              storeId: 'fixture-store',
              generation: 'fixture-generation',
            ),
          ),
      ],
    );
  }

  group('EditDailyTransferCommand Constructor & Identity', () {
    test('valid command builds with canonical payload identity', () {
      final cmd = EditDailyTransferCommand(
        operationId: 'op-edit-1',
        accountLineage: 'lineage-1',
        expectedFence: const StorageFence(storeId: 's1', generation: 'g1'),
        transferId: 't1',
        expectedActiveJournalId: 'j1',
        inverseJournalId: 'j-inv-1',
        replacementJournalId: 'j-repl-1',
        newAmount: BigInt.from(30000),
        reason: 'Adjust cashbox transfer amount',
        recordedAt: '2026-01-15T12:00:00.000Z',
      );

      expect(cmd.operationId, 'op-edit-1');
      expect(cmd.commandType, 'edit_daily_transfer');
      expect(cmd.newAmount, BigInt.from(30000));
      expect(cmd.reason, 'Adjust cashbox transfer amount');
      expect(cmd.canonicalPayloadIdentity, isNotEmpty);

      // Verify deterministic identity
      final cmd2 = EditDailyTransferCommand(
        operationId: 'op-edit-1',
        accountLineage: 'lineage-1',
        expectedFence: const StorageFence(storeId: 's1', generation: 'g1'),
        transferId: 't1',
        expectedActiveJournalId: 'j1',
        inverseJournalId: 'j-inv-1',
        replacementJournalId: 'j-repl-1',
        newAmount: BigInt.from(30000),
        reason: 'Adjust cashbox transfer amount',
        recordedAt: '2026-01-15T12:00:00.000Z',
      );
      expect(cmd.canonicalPayloadIdentity, cmd2.canonicalPayloadIdentity);
    });

    test('constructor rejects empty or whitespace fields', () {
      expect(
        () => EditDailyTransferCommand(
          operationId: '   ',
          accountLineage: 'lineage-1',
          transferId: 't1',
          expectedActiveJournalId: 'j1',
          inverseJournalId: 'j-inv-1',
          replacementJournalId: 'j-repl-1',
          newAmount: BigInt.from(30000),
          reason: 'reason',
          recordedAt: '2026-01-15T12:00:00.000Z',
        ),
        throwsFormatException,
      );

      expect(
        () => EditDailyTransferCommand(
          operationId: 'op-1',
          accountLineage: '',
          transferId: 't1',
          expectedActiveJournalId: 'j1',
          inverseJournalId: 'j-inv-1',
          replacementJournalId: 'j-repl-1',
          newAmount: BigInt.from(30000),
          reason: 'reason',
          recordedAt: '2026-01-15T12:00:00.000Z',
        ),
        throwsFormatException,
      );

      expect(
        () => EditDailyTransferCommand(
          operationId: 'op-1',
          accountLineage: 'lineage-1',
          transferId: 't1',
          expectedActiveJournalId: 'j1',
          inverseJournalId: 'j-inv-1',
          replacementJournalId: 'j-repl-1',
          newAmount: BigInt.zero,
          reason: 'reason',
          recordedAt: '2026-01-15T12:00:00.000Z',
        ),
        throwsFormatException,
      );

      expect(
        () => EditDailyTransferCommand(
          operationId: 'op-1',
          accountLineage: 'lineage-1',
          transferId: 't1',
          expectedActiveJournalId: 'j1',
          inverseJournalId: 'same-id',
          replacementJournalId: 'same-id',
          newAmount: BigInt.from(30000),
          reason: 'reason',
          recordedAt: '2026-01-15T12:00:00.000Z',
        ),
        throwsFormatException,
      );

      expect(
        () => EditDailyTransferCommand(
          operationId: 'op-1',
          accountLineage: 'lineage-1',
          transferId: 't1',
          expectedActiveJournalId: 'same-id',
          inverseJournalId: 'same-id',
          replacementJournalId: 'repl-id',
          newAmount: BigInt.from(30000),
          reason: 'reason',
          recordedAt: '2026-01-15T12:00:00.000Z',
        ),
        throwsFormatException,
      );
    });
  });

  group('DeleteDailyTransferCommand Constructor & Identity', () {
    test('valid command builds with canonical payload identity', () {
      final cmd = DeleteDailyTransferCommand(
        operationId: 'op-del-1',
        accountLineage: 'lineage-1',
        expectedFence: const StorageFence(storeId: 's1', generation: 'g1'),
        transferId: 't1',
        expectedActiveJournalId: 'j1',
        inverseJournalId: 'j-del-inv-1',
        reason: 'Cancel deposit and return cash to daily drawer',
        recordedAt: '2026-01-15T14:00:00.000Z',
      );

      expect(cmd.operationId, 'op-del-1');
      expect(cmd.commandType, 'delete_daily_transfer');
      expect(cmd.reason, 'Cancel deposit and return cash to daily drawer');
      expect(cmd.canonicalPayloadIdentity, isNotEmpty);
    });

    test('constructor rejects empty reason or matching journal IDs', () {
      expect(
        () => DeleteDailyTransferCommand(
          operationId: 'op-del-1',
          accountLineage: 'lineage-1',
          transferId: 't1',
          expectedActiveJournalId: 'same-id',
          inverseJournalId: 'same-id',
          reason: 'some reason',
          recordedAt: '2026-01-15T14:00:00.000Z',
        ),
        throwsFormatException,
      );

      expect(
        () => DeleteDailyTransferCommand(
          operationId: 'op-del-1',
          accountLineage: 'lineage-1',
          transferId: 't1',
          expectedActiveJournalId: 'j1',
          inverseJournalId: 'j-inv-1',
          reason: '   ',
          recordedAt: '2026-01-15T14:00:00.000Z',
        ),
        throwsFormatException,
      );
    });
  });

  group('RestaurantJournalTransferCorrectionOutcome Serialization', () {
    test('round-trip serialization preserves all fields', () {
      final outcome = RestaurantJournalTransferCorrectionOutcome(
        commandType: 'edit_daily_transfer',
        operationId: 'op-edit-1',
        transferId: 't1',
        targetJournalId: 'j1',
        inverseJournalId: 'j-inv-1',
        replacementJournalId: 'j-repl-1',
        effectiveDate: '2026-01-15',
        netAmount: '30000',
        metadata: {
          'reason': 'Adjusted deposit',
          'sourceVersion': 11,
          'beforeSnapshot': {'amount': 20000},
          'afterSnapshot': {'amount': 30000},
        },
      );

      final payload = outcome.toOutcomePayload();
      final decoded =
          RestaurantJournalTransferCorrectionOutcome.fromOutcomePayload(
            payload,
          );

      expect(decoded, outcome);
      expect(decoded.hashCode, outcome.hashCode);
      expect(decoded.commandType, 'edit_daily_transfer');
      expect(decoded.replacementJournalId, 'j-repl-1');
      expect(decoded.metadata['reason'], 'Adjusted deposit');
      expect(decoded.toString(), contains('redacted'));
    });

    test('delete outcome serializes with null replacementJournalId', () {
      final outcome = RestaurantJournalTransferCorrectionOutcome(
        commandType: 'delete_daily_transfer',
        operationId: 'op-del-1',
        transferId: 't1',
        targetJournalId: 'j1',
        inverseJournalId: 'j-inv-1',
        effectiveDate: '2026-01-15',
        netAmount: '20000',
      );

      final payload = outcome.toOutcomePayload();
      final decoded =
          RestaurantJournalTransferCorrectionOutcome.fromOutcomePayload(
            payload,
          );

      expect(decoded.commandType, 'delete_daily_transfer');
      expect(decoded.replacementJournalId, isNull);
      expect(decoded, outcome);
    });
  });

  group('Proposal Evaluation: EditDailyTransferCommand', () {
    test('successful edit proposal produces inverse, replacement, updated source and snapshots', () {
      final state = createBaselineState(transferAmount: 20000);
      final cmd = EditDailyTransferCommand(
        operationId: 'op-edit-1',
        accountLineage: state.accountLineage,
        transferId: 't1',
        expectedActiveJournalId: 'j1',
        inverseJournalId: 'j-inv-1',
        replacementJournalId: 'j-repl-1',
        newAmount: BigInt.from(30000),
        reason: 'Increase cashbox deposit',
        recordedAt: '2026-01-15T12:00:00.000Z',
      );

      final evaluation =
          RestaurantJournalTransferCorrectionCommandCoordinator.evaluateEdit(
            command: cmd,
            state: state,
            cutoverDate: cutoverDate,
            mapper: mapper,
          );

      expect((!evaluation.rejected), isTrue);
      final candidate = evaluation.candidateState!;
      expect(candidate.journals.length, state.journals.length + 2);

      final inv = candidate.journals.firstWhere(
        (j) => j.journal.id == 'j-inv-1',
      );
      expect(inv.journal.reversesId, 'j1');
      expect(inv.replacementJournalId, 'j-repl-1');
      expect(inv.journal.effectiveDate, transferDate);
      expect(inv.metadata['beforeSnapshot'], {
        'id': 't1',
        'date': '2026-01-15',
        'amount': 20000,
        'createdAt': '2026-01-15T10:00:00.000Z',
      });
      expect(inv.metadata['afterSnapshot'], {
        'id': 't1',
        'date': '2026-01-15',
        'amount': 30000,
        'createdAt': '2026-01-15T10:00:00.000Z',
      });

      final repl = candidate.journals.firstWhere(
        (j) => j.journal.id == 'j-repl-1',
      );
      expect(repl.correctedFromJournalId, 'j1');
      expect(repl.journal.reversesId, isNull);
      expect(repl.journal.totalUnits, BigInt.from(30000));
      expect(repl.journal.effectiveDate, transferDate);

      // Check updated source transfer row: keeps id, date, createdAt; updates amount
      final rawTransfers = (candidate.account.toJson()['transfers'] as List)
          .cast<Map<String, Object?>>();
      expect(rawTransfers.length, 1);
      final updatedTransfer = rawTransfers.single;
      expect(updatedTransfer['id'], 't1');
      expect(updatedTransfer['date'], '2026-01-15');
      expect(updatedTransfer['amount'], 30000);
      expect(updatedTransfer['createdAt'], '2026-01-15T10:00:00.000Z');

      // Check DailyCashQueries parity
      final queries = DailyCashQueries(candidate.account);
      final day = queries.day('2026-01-15');
      expect(day.remaining, BigInt.from(70000));
      expect(day.transferred, BigInt.from(30000));
    });

    test('legacy unset-total recovery recovers balance and preserves it', () {
      final state = createBaselineState(
        transferAmount: 20000,
        nullBalance: true,
      );
      final cmd = EditDailyTransferCommand(
        operationId: 'op-edit-unset',
        accountLineage: state.accountLineage,
        transferId: 't1',
        expectedActiveJournalId: 'j1',
        inverseJournalId: 'j-inv-unset',
        replacementJournalId: 'j-repl-unset',
        newAmount: BigInt.from(35000),
        reason: 'Recover unset total and edit',
        recordedAt: '2026-01-15T12:00:00.000Z',
      );

      final evaluation =
          RestaurantJournalTransferCorrectionCommandCoordinator.evaluateEdit(
            command: cmd,
            state: state,
            cutoverDate: cutoverDate,
            mapper: mapper,
          );

      expect((!evaluation.rejected), isTrue);
      final rawDays =
          (evaluation.candidateState!.account.toJson()['days'] as Map)
              .cast<String, Object?>();
      final dayMap = rawDays['2026-01-15'] as Map;
      // balance = total(0) + remaining(80000) + transferred(20000) = 100000
      expect(dayMap['balance'], 100000);
    });

    test('rejects target transfer not found', () {
      final state = createBaselineState(includeTransfer: false);
      final cmd = EditDailyTransferCommand(
        operationId: 'op-edit-absent',
        accountLineage: state.accountLineage,
        transferId: 'non-existent-transfer',
        expectedActiveJournalId: 'j1',
        inverseJournalId: 'j-inv-1',
        replacementJournalId: 'j-repl-1',
        newAmount: BigInt.from(30000),
        reason: 'Edit non-existent',
        recordedAt: '2026-01-15T12:00:00.000Z',
      );

      final evaluation =
          RestaurantJournalTransferCorrectionCommandCoordinator.evaluateEdit(
            command: cmd,
            state: state,
            cutoverDate: cutoverDate,
            mapper: mapper,
          );

      expect(evaluation.rejected, isTrue);
      expect(
        evaluation.rejectionCode,
        RestaurantJournalTransferCorrectionErrorCodes.transferNotFound,
      );
    });

    test('rejects pre-cutover transfer correction', () {
      final state = createBaselineState(preCutover: true);
      final cmd = EditDailyTransferCommand(
        operationId: 'op-edit-pre',
        accountLineage: state.accountLineage,
        transferId: 't1',
        expectedActiveJournalId: 'j1',
        inverseJournalId: 'j-inv-1',
        replacementJournalId: 'j-repl-1',
        newAmount: BigInt.from(30000),
        reason: 'Edit pre-cutover',
        recordedAt: '2026-01-15T12:00:00.000Z',
      );

      final evaluation =
          RestaurantJournalTransferCorrectionCommandCoordinator.evaluateEdit(
            command: cmd,
            state: state,
            cutoverDate: cutoverDate,
            mapper: mapper,
          );

      expect(evaluation.rejected, isTrue);
      expect(
        evaluation.rejectionCode,
        RestaurantJournalTransferCorrectionErrorCodes
            .preCutoverOperationRejected,
      );
    });

    test('rejects excessive transfer amount (> available + oldAmount)', () {
      final state = createBaselineState(transferAmount: 20000);
      // available is 80,000; oldAmount is 20,000; maxAllowed is 100,000.
      final cmd = EditDailyTransferCommand(
        operationId: 'op-edit-excessive',
        accountLineage: state.accountLineage,
        transferId: 't1',
        expectedActiveJournalId: 'j1',
        inverseJournalId: 'j-inv-1',
        replacementJournalId: 'j-repl-1',
        newAmount: BigInt.from(100001),
        reason: 'Too much',
        recordedAt: '2026-01-15T12:00:00.000Z',
      );

      final evaluation =
          RestaurantJournalTransferCorrectionCommandCoordinator.evaluateEdit(
            command: cmd,
            state: state,
            cutoverDate: cutoverDate,
            mapper: mapper,
          );

      expect(evaluation.rejected, isTrue);
      expect(
        evaluation.rejectionCode,
        RestaurantJournalTransferCorrectionErrorCodes.excessiveTransferAmount,
      );
    });

    test('rejects stale target journal ID', () {
      final state = createBaselineState(transferAmount: 20000);
      final cmd = EditDailyTransferCommand(
        operationId: 'op-edit-stale',
        accountLineage: state.accountLineage,
        transferId: 't1',
        expectedActiveJournalId: 'wrong-journal-id',
        inverseJournalId: 'j-inv-1',
        replacementJournalId: 'j-repl-1',
        newAmount: BigInt.from(30000),
        reason: 'Stale target',
        recordedAt: '2026-01-15T12:00:00.000Z',
      );

      final evaluation =
          RestaurantJournalTransferCorrectionCommandCoordinator.evaluateEdit(
            command: cmd,
            state: state,
            cutoverDate: cutoverDate,
            mapper: mapper,
          );

      expect(evaluation.rejected, isTrue);
      expect(
        evaluation.rejectionCode,
        RestaurantJournalTransferCorrectionErrorCodes.staleTargetJournal,
      );
    });

    test('rejects duplicate correction journal IDs', () {
      final state = createBaselineState(transferAmount: 20000);
      final cmd = EditDailyTransferCommand(
        operationId: 'op-edit-dup',
        accountLineage: state.accountLineage,
        transferId: 't1',
        expectedActiveJournalId: 'j1',
        inverseJournalId: 'opening-j1', // already exists!
        replacementJournalId: 'j-repl-1',
        newAmount: BigInt.from(30000),
        reason: 'Duplicate ID',
        recordedAt: '2026-01-15T12:00:00.000Z',
      );

      final evaluation =
          RestaurantJournalTransferCorrectionCommandCoordinator.evaluateEdit(
            command: cmd,
            state: state,
            cutoverDate: cutoverDate,
            mapper: mapper,
          );

      expect(evaluation.rejected, isTrue);
      expect(
        evaluation.rejectionCode,
        RestaurantJournalTransferCorrectionErrorCodes.duplicateJournalId,
      );
    });

    test(
      'rejects target journal with mismatched amount as staleTargetJournal',
      () {
        final state = createBaselineState(transferAmount: 20000);
        // Construct a state where expectedActiveJournalId has a different amount than the transfer record
        final mismatchedProposal = mapper.mapDailyToCashboxTransfer(
          journalId: 'j-mismatched',
          transferId: 't1',
          effectiveDate: transferDate,
          amount: BigInt.from(
            15000,
          ), // Mismatched: transfer in source has 20000
        );
        final mismatchedState = state.copyWith(
          journals: [
            ...state.journals,
            PortableJournalEntry(
              journal: mismatchedProposal.journal,
              sourceType: mismatchedProposal.sourceType.name,
              sourceRecordId: 't1',
              recordedAt: '2026-01-15T10:00:00.000Z',
            ),
          ],
        );

        final cmd = EditDailyTransferCommand(
          operationId: 'op-edit-mismatch',
          accountLineage: state.accountLineage,
          transferId: 't1',
          expectedActiveJournalId: 'j-mismatched',
          inverseJournalId: 'j-inv-1',
          replacementJournalId: 'j-repl-1',
          newAmount: BigInt.from(30000),
          reason: 'Mismatched journal amount',
          recordedAt: '2026-01-15T12:00:00.000Z',
        );

        final evaluation =
            RestaurantJournalTransferCorrectionCommandCoordinator.evaluateEdit(
              command: cmd,
              state: mismatchedState,
              cutoverDate: cutoverDate,
              mapper: mapper,
            );

        expect(evaluation.rejected, isTrue);
        expect(
          evaluation.rejectionCode,
          RestaurantJournalTransferCorrectionErrorCodes.staleTargetJournal,
        );
      },
    );
  });

  group('Proposal Evaluation: DeleteDailyTransferCommand', () {
    test('successful delete proposal removes source transfer, preserves remaining snapshot and appends inverse', () {
      final state = createBaselineState(transferAmount: 20000);
      final cmd = DeleteDailyTransferCommand(
        operationId: 'op-del-1',
        accountLineage: state.accountLineage,
        transferId: 't1',
        expectedActiveJournalId: 'j1',
        inverseJournalId: 'j-del-inv-1',
        reason: 'Cancel deposit and return to drawer',
        recordedAt: '2026-01-15T14:00:00.000Z',
      );

      final evaluation =
          RestaurantJournalTransferCorrectionCommandCoordinator.evaluateDelete(
            command: cmd,
            state: state,
            cutoverDate: cutoverDate,
            mapper: mapper,
          );

      expect((!evaluation.rejected), isTrue);
      final candidate = evaluation.candidateState!;
      expect(candidate.journals.length, state.journals.length + 1);

      final inv = candidate.journals.firstWhere(
        (j) => j.journal.id == 'j-del-inv-1',
      );
      expect(inv.journal.reversesId, 'j1');
      expect(inv.replacementJournalId, isNull);
      expect(inv.journal.effectiveDate, transferDate);
      expect(inv.metadata['beforeSnapshot'], {
        'id': 't1',
        'date': '2026-01-15',
        'amount': 20000,
        'createdAt': '2026-01-15T10:00:00.000Z',
      });
      expect(inv.metadata['afterSnapshot'], {'deleted': true, 'id': 't1'});

      // Source transfer is completely removed from source records
      final rawTransfers = (candidate.account.toJson()['transfers'] as List)
          .cast<Map<String, Object?>>();
      expect(rawTransfers.any((t) => t['id'] == 't1'), isFalse);

      // Remaining snapshot and balance are preserved
      final queries = DailyCashQueries(candidate.account);
      final day = queries.day('2026-01-15');
      expect(day.remaining, BigInt.from(100000));
      expect(day.transferred, BigInt.zero);
      final rawD =
          (candidate.account.toJson()["days"] as Map)["2026-01-15"] as Map;
      expect(rawD["balance"], 100000);
    });

    test('delete rejects already reversed target journal', () {
      final state = createBaselineState(transferAmount: 20000);
      // First reverse j1
      final invJournal = state.journals
          .firstWhere((j) => j.journal.id == 'j1')
          .journal
          .reversed(
            id: 'prior-inv',
            effectiveDate: transferDate,
            reason: 'Prior void',
          );
      final stateWithReversal = state.copyWith(
        journals: [
          ...state.journals,
          PortableJournalEntry(
            journal: invJournal,
            sourceType: RestaurantJournalSourceType.voidReversal.name,
            sourceRecordId: 't1',
            recordedAt: '2026-01-15T11:00:00.000Z',
          ),
        ],
      );

      final cmd = DeleteDailyTransferCommand(
        operationId: 'op-del-already-rev',
        accountLineage: state.accountLineage,
        transferId: 't1',
        expectedActiveJournalId: 'j1',
        inverseJournalId: 'j-del-inv-2',
        reason: 'Try delete already reversed',
        recordedAt: '2026-01-15T14:00:00.000Z',
      );

      final evaluation =
          RestaurantJournalTransferCorrectionCommandCoordinator.evaluateDelete(
            command: cmd,
            state: stateWithReversal,
            cutoverDate: cutoverDate,
            mapper: mapper,
          );

      expect(evaluation.rejected, isTrue);
      expect(
        evaluation.rejectionCode,
        RestaurantJournalTransferCorrectionErrorCodes.transferAlreadyReversed,
      );
    });
  });
}
