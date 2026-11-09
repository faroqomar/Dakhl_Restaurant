import 'package:flutter_test/flutter_test.dart';
import 'package:madar_application/madar_application.dart';
import 'package:madar_domain/madar_domain.dart';
import 'package:dakhl_restaurant/accounting/daily_cash_queries.dart';
import 'package:dakhl_restaurant/accounting/restaurant_journal_mapper.dart';
import 'package:dakhl_restaurant/accounting/restaurant_journal_transfer_commands.dart';
import 'package:dakhl_restaurant/accounts/account_document.dart';
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
  final postDate = DateOnly.parse(
    '2026-01-15',
    minimumYear: 1000,
    maximumYear: 9999,
  );
  final preDate = DateOnly.parse(
    '2025-12-31',
    minimumYear: 1000,
    maximumYear: 9999,
  );

  AccountDocument buildSampleAccount({
    String date = '2026-01-15',
    int? dayBalance = 100000,
    Map<String, Object?>? remainingSnapshot = const {
      'amount': 100000,
      'dailySpent': 0,
      'transferred': 0,
      'salesTotal': 0,
    },
    List<Map<String, Object?>> expenses = const [],
    List<Map<String, Object?>> transfers = const [],
  }) {
    final raw = Map<String, Object?>.from(legacyCodec.empty().toJson());
    raw['days'] = {
      date: {
        'expenses': expenses,
        'chickenUsed': 0,
        'chickenLeft': 0,
        'balance': dayBalance,
        'totalOverride': null,
        'remaining': remainingSnapshot,
      },
    };
    raw['transfers'] = transfers;
    return legacyCodec.decodeJson(raw);
  }

  PortableJournalState buildSyntheticState({
    required AccountDocument account,
    String accountLineage = 'test-lineage-1',
    bool isGated = false,
  }) {
    final cutover = isGated
        ? PortableJournalCutoverState.gated()
        : PortableJournalCutoverState.established(
            cutoverDate: cutoverDate,
            openingJournalId: 'open-jnl-1',
          );

    final openingLines = [
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
    ];

    final openEntry = isGated
        ? null
        : PortableJournalEntry(
            journal: BalancedJournal.validate(
              id: 'open-jnl-1',
              effectiveDate: cutoverDate,
              policy: RestaurantJournalPolicies.opening,
              lines: openingLines,
            ),
            sourceType: RestaurantJournalSourceType.cutoverOpening.name,
            sourceRecordId: 'cutover-record-1',
            recordedAt: '2026-01-01T00:00:00.000Z',
          );

    return PortableJournalState(
      accountLineage: accountLineage,
      account: account,
      sourceProvenance: const PortableJournalSourceProvenance(
        sourceVersion: 11,
        enrolledAt: '2026-01-01T00:00:00.000Z',
        migrated: false,
      ),
      cutoverState: cutover,
      journals: [?openEntry],
      receipts: const [],
    );
  }

  group('DailyToCashboxTransferCommand Validation & Identity', () {
    test('valid command constructs with canonical payload identity', () {
      final cmd = DailyToCashboxTransferCommand(
        operationId: 'op-xfer-1',
        payloadVersion: 1,
        accountLineage: 'lineage-1',
        expectedFence: const StorageFence(storeId: 's1', generation: 'g1'),
        transferId: 't-1',
        journalId: 'j-1',
        date: postDate,
        amount: BigInt.from(20000),
        recordedAt: '2026-01-15T12:00:00.000Z',
      );

      expect(cmd.operationId, 'op-xfer-1');
      expect(cmd.payloadVersion, 1);
      expect(cmd.accountLineage, 'lineage-1');
      expect(cmd.transferId, 't-1');
      expect(cmd.journalId, 'j-1');
      expect(cmd.date, postDate);
      expect(cmd.amount, BigInt.from(20000));
      expect(cmd.commandType, 'daily_to_cashbox_transfer');
      expect(cmd.identity.operationId, 'op-xfer-1');
      expect(cmd.identity.payloadVersion, 1);
      expect(cmd.canonicalPayloadIdentity, isNotEmpty);
      expect(
        cmd.canonicalPayloadIdentity,
        contains('daily_to_cashbox_transfer'),
      );
    });

    test('rejects empty or whitespace operationId', () {
      expect(
        () => DailyToCashboxTransferCommand(
          operationId: '  ',
          accountLineage: 'lineage-1',
          transferId: 't-1',
          journalId: 'j-1',
          date: postDate,
          amount: BigInt.from(20000),
          recordedAt: '2026-01-15T12:00:00.000Z',
        ),
        throwsFormatException,
      );
    });

    test('rejects non-positive payload version', () {
      expect(
        () => DailyToCashboxTransferCommand(
          operationId: 'op-1',
          payloadVersion: 0,
          accountLineage: 'lineage-1',
          transferId: 't-1',
          journalId: 'j-1',
          date: postDate,
          amount: BigInt.from(20000),
          recordedAt: '2026-01-15T12:00:00.000Z',
        ),
        throwsFormatException,
      );
    });

    test('rejects empty or whitespace accountLineage', () {
      expect(
        () => DailyToCashboxTransferCommand(
          operationId: 'op-1',
          accountLineage: '',
          transferId: 't-1',
          journalId: 'j-1',
          date: postDate,
          amount: BigInt.from(20000),
          recordedAt: '2026-01-15T12:00:00.000Z',
        ),
        throwsFormatException,
      );
    });

    test('rejects zero or negative amount', () {
      expect(
        () => DailyToCashboxTransferCommand(
          operationId: 'op-1',
          accountLineage: 'lineage-1',
          transferId: 't-1',
          journalId: 'j-1',
          date: postDate,
          amount: BigInt.zero,
          recordedAt: '2026-01-15T12:00:00.000Z',
        ),
        throwsFormatException,
      );
      expect(
        () => DailyToCashboxTransferCommand(
          operationId: 'op-1',
          accountLineage: 'lineage-1',
          transferId: 't-1',
          journalId: 'j-1',
          date: postDate,
          amount: BigInt.from(-5000),
          recordedAt: '2026-01-15T12:00:00.000Z',
        ),
        throwsFormatException,
      );
    });

    test('rejects excessive amount exceeding maximum allowed limit', () {
      expect(
        () => DailyToCashboxTransferCommand(
          operationId: 'op-1',
          accountLineage: 'lineage-1',
          transferId: 't-1',
          journalId: 'j-1',
          date: postDate,
          amount: RestaurantJournalPolicies.defaultLimit + BigInt.one,
          recordedAt: '2026-01-15T12:00:00.000Z',
        ),
        throwsFormatException,
      );
    });
  });

  group('RestaurantJournalTransferOutcome Serialization & Equivalence', () {
    test('serializes and deserializes outcome payload losslessly', () {
      final outcome = RestaurantJournalTransferOutcome(
        commandType: 'daily_to_cashbox_transfer',
        operationId: 'op-xfer-1',
        transferId: 't-1',
        journalId: 'j-1',
        effectiveDate: '2026-01-15',
        netAmount: '20000',
        metadata: {'operationId': 'op-xfer-1', 'transferId': 't-1'},
      );

      final payload = outcome.toOutcomePayload();
      final restored = RestaurantJournalTransferOutcome.fromOutcomePayload(
        payload,
      );

      expect(restored, equals(outcome));
      expect(restored.hashCode, equals(outcome.hashCode));
      expect(restored.commandType, 'daily_to_cashbox_transfer');
      expect(restored.operationId, 'op-xfer-1');
      expect(restored.transferId, 't-1');
      expect(restored.journalId, 'j-1');
      expect(restored.effectiveDate, '2026-01-15');
      expect(restored.netAmount, '20000');
    });

    test('toString redacts financial details', () {
      final outcome = RestaurantJournalTransferOutcome(
        commandType: 'daily_to_cashbox_transfer',
        operationId: 'op-xfer-1',
        transferId: 't-1',
        journalId: 'j-1',
        effectiveDate: '2026-01-15',
        netAmount: '20000',
      );

      expect(
        outcome.toString(),
        'RestaurantJournalTransferOutcome(type: daily_to_cashbox_transfer, details: redacted)',
      );
      expect(outcome.toString(), isNot(contains('20000')));
    });

    test('rejects invalid JSON keys and malformed outcome types', () {
      expect(
        () => RestaurantJournalTransferOutcome.fromJson({
          'commandType': 'unknown_type',
          'operationId': 'op-1',
          'transferId': 't-1',
          'journalId': 'j-1',
          'effectiveDate': '2026-01-15',
          'netAmount': '20000',
        }),
        throwsFormatException,
      );

      expect(
        () => RestaurantJournalTransferOutcome.fromJson({
          'commandType': 'daily_to_cashbox_transfer',
          'operationId': 'op-1',
          'transferId': 't-1',
          'journalId': 'j-1',
          'effectiveDate': '2026-01-15',
          'netAmount': '20000',
          'unexpectedExtraKey': true,
        }),
        throwsFormatException,
      );
    });
  });

  group('Proposal Evaluation & Invariants', () {
    test('pre-cutover transfer date is rejected', () {
      final account = buildSampleAccount(date: preDate.toString());
      final state = buildSyntheticState(account: account);

      final cmd = DailyToCashboxTransferCommand(
        operationId: 'op-1',
        accountLineage: 'test-lineage-1',
        transferId: 't-pre',
        journalId: 'j-pre',
        date: preDate,
        amount: BigInt.from(20000),
        recordedAt: '2025-12-31T12:00:00.000Z',
      );

      final eval = RestaurantJournalTransferCommandCoordinator.evaluateTransfer(
        command: cmd,
        state: state,
        cutoverDate: cutoverDate,
        mapper: mapper,
      );

      expect(eval.rejected, isTrue);
      expect(
        eval.rejectionCode,
        RestaurantJournalTransferErrorCodes.preCutoverOperationRejected,
      );
    });

    test('rejects when remaining snapshot is missing for date', () {
      final account = buildSampleAccount(remainingSnapshot: null);
      final state = buildSyntheticState(account: account);

      final cmd = DailyToCashboxTransferCommand(
        operationId: 'op-1',
        accountLineage: 'test-lineage-1',
        transferId: 't-1',
        journalId: 'j-1',
        date: postDate,
        amount: BigInt.from(20000),
        recordedAt: '2026-01-15T12:00:00.000Z',
      );

      final eval = RestaurantJournalTransferCommandCoordinator.evaluateTransfer(
        command: cmd,
        state: state,
        cutoverDate: cutoverDate,
        mapper: mapper,
      );

      expect(eval.rejected, isTrue);
      expect(
        eval.rejectionCode,
        RestaurantJournalTransferErrorCodes.missingRemainingSnapshot,
      );
    });

    test('rejects when transfer amount exceeds available remaining cash', () {
      // 100,000 available
      final account = buildSampleAccount(
        remainingSnapshot: {
          'amount': 100000,
          'dailySpent': 0,
          'transferred': 0,
          'salesTotal': 0,
        },
      );
      final state = buildSyntheticState(account: account);

      // Attempt to transfer 100,001 IQD
      final cmd = DailyToCashboxTransferCommand(
        operationId: 'op-1',
        accountLineage: 'test-lineage-1',
        transferId: 't-1',
        journalId: 'j-1',
        date: postDate,
        amount: BigInt.from(100001),
        recordedAt: '2026-01-15T12:00:00.000Z',
      );

      final eval = RestaurantJournalTransferCommandCoordinator.evaluateTransfer(
        command: cmd,
        state: state,
        cutoverDate: cutoverDate,
        mapper: mapper,
      );

      expect(eval.rejected, isTrue);
      expect(
        eval.rejectionCode,
        RestaurantJournalTransferErrorCodes.excessiveTransferAmount,
      );
    });

    test('rejects duplicate transferId in source records', () {
      final account = buildSampleAccount(
        transfers: [
          {
            'id': 't-dup',
            'date': postDate.toString(),
            'amount': 10000,
            'createdAt': '2026-01-15T10:00:00.000Z',
          },
        ],
      );
      final state = buildSyntheticState(account: account);

      final cmd = DailyToCashboxTransferCommand(
        operationId: 'op-1',
        accountLineage: 'test-lineage-1',
        transferId: 't-dup', // Duplicate ID
        journalId: 'j-1',
        date: postDate,
        amount: BigInt.from(20000),
        recordedAt: '2026-01-15T12:00:00.000Z',
      );

      final eval = RestaurantJournalTransferCommandCoordinator.evaluateTransfer(
        command: cmd,
        state: state,
        cutoverDate: cutoverDate,
        mapper: mapper,
      );

      expect(eval.rejected, isTrue);
      expect(
        eval.rejectionCode,
        RestaurantJournalTransferErrorCodes.duplicateTransferId,
      );
    });

    test('rejects duplicate journalId in journal entries', () {
      final account = buildSampleAccount();
      final state = buildSyntheticState(account: account);

      final cmd = DailyToCashboxTransferCommand(
        operationId: 'op-1',
        accountLineage: 'test-lineage-1',
        transferId: 't-1',
        journalId: 'open-jnl-1', // Duplicate with opening journal
        date: postDate,
        amount: BigInt.from(20000),
        recordedAt: '2026-01-15T12:00:00.000Z',
      );

      final eval = RestaurantJournalTransferCommandCoordinator.evaluateTransfer(
        command: cmd,
        state: state,
        cutoverDate: cutoverDate,
        mapper: mapper,
      );

      expect(eval.rejected, isTrue);
      expect(
        eval.rejectionCode,
        RestaurantJournalTransferErrorCodes.duplicateJournalId,
      );
    });

    test('ordinary transfer 20,000 from 100,000 leaves 80,000 and adds 20,000 cashbox', () {
      final account = buildSampleAccount(
        dayBalance: 100000,
        remainingSnapshot: {
          'amount': 100000,
          'dailySpent': 0,
          'transferred': 0,
          'salesTotal': 0,
        },
      );
      final state = buildSyntheticState(account: account);

      final cmd = DailyToCashboxTransferCommand(
        operationId: 'op-ord-1',
        accountLineage: 'test-lineage-1',
        transferId: 't-ord-1',
        journalId: 'j-ord-1',
        date: postDate,
        amount: BigInt.from(20000),
        recordedAt: '2026-01-15T12:00:00.000Z',
      );

      final eval = RestaurantJournalTransferCommandCoordinator.evaluateTransfer(
        command: cmd,
        state: state,
        cutoverDate: cutoverDate,
        mapper: mapper,
      );

      expect(eval.rejected, isFalse);
      final newState = eval.candidateState!;
      final outcome = eval.outcome!;

      expect(outcome.netAmount, '20000');
      expect(outcome.transferId, 't-ord-1');
      expect(outcome.journalId, 'j-ord-1');

      // Check source records
      final newQueries = DailyCashQueries(newState.account);
      final daySnap = newQueries.day(postDate.toString());
      expect(daySnap.transferred, BigInt.from(20000));
      expect(daySnap.remaining, BigInt.from(80000)); // 100k - 20k = 80k
      expect(daySnap.recordedBalance, BigInt.from(100000)); // balance preserved

      // Cashbox movement
      final moves = newQueries.cashMovements;
      final transferMoves = moves
          .where((m) => m['kind'] == 'transfer')
          .toList();
      expect(transferMoves, hasLength(1));
      expect(transferMoves.single['amount'], 20000);
      expect(transferMoves.single['type'], 'deposit');

      // Check balanced journal
      final transferJournals = newState.journals
          .where((j) => j.journal.id == 'j-ord-1')
          .toList();
      expect(transferJournals, hasLength(1));
      final journal = transferJournals.single.journal;
      expect(journal.totalUnits, BigInt.from(20000));
      expect(journal.lines, hasLength(2));

      final debitLine = journal.lines.firstWhere(
        (l) => l.side == JournalSide.debit,
      );
      final creditLine = journal.lines.firstWhere(
        (l) => l.side == JournalSide.credit,
      );
      expect(debitLine.accountId, 'asset:cash:cashbox');
      expect(debitLine.amountUnits, BigInt.from(20000));
      expect(creditLine.accountId, 'asset:cash:daily');
      expect(creditLine.amountUnits, BigInt.from(20000));
    });

    test(
      'transfer-all 100,000 from 100,000 reaches zero available remaining',
      () {
        final account = buildSampleAccount(
          dayBalance: 100000,
          remainingSnapshot: {
            'amount': 100000,
            'dailySpent': 0,
            'transferred': 0,
            'salesTotal': 0,
          },
        );
        final state = buildSyntheticState(account: account);

        final cmd = DailyToCashboxTransferCommand(
          operationId: 'op-all-1',
          accountLineage: 'test-lineage-1',
          transferId: 't-all-1',
          journalId: 'j-all-1',
          date: postDate,
          amount: BigInt.from(100000),
          recordedAt: '2026-01-15T12:00:00.000Z',
        );

        final eval =
            RestaurantJournalTransferCommandCoordinator.evaluateTransfer(
              command: cmd,
              state: state,
              cutoverDate: cutoverDate,
              mapper: mapper,
            );

        expect(eval.rejected, isFalse);
        final newState = eval.candidateState!;
        final newQueries = DailyCashQueries(newState.account);
        final daySnap = newQueries.day(postDate.toString());

        expect(daySnap.transferred, BigInt.from(100000));
        expect(daySnap.remaining, BigInt.zero); // reaches zero!
        expect(daySnap.recordedBalance, BigInt.from(100000));
      },
    );

    test(
      'recovers unset total on legacy records before transfer and preserves it',
      () {
        // Legacy day with remaining snapshot and prior transfer, but unset total (balance == null)
        final account = buildSampleAccount(
          dayBalance: null, // Unset total
          remainingSnapshot: {
            'amount': 100000,
            'dailySpent': 20000,
            'transferred': 5000,
            'salesTotal': 0,
          },
          expenses: [
            {
              'id': 'exp-1',
              'categoryId': 'samoon',
              'amount': 20000,
              'note': '',
              'createdAt': '2026-01-15T10:00:00.000Z',
              'funding': {
                'source': 'daily',
                'dailyAmount': 20000,
                'cashAmount': 0,
              },
            },
          ],
          transfers: [
            {
              'id': 't-prior',
              'date': postDate.toString(),
              'amount': 5000,
              'createdAt': '2026-01-15T09:00:00.000Z',
            },
          ],
        );

        // Verify that before transfer, balance is null
        final rawDaysBefore = account.toJson()['days'] as Map<String, Object?>;
        expect((rawDaysBefore[postDate.toString()] as Map)['balance'], isNull);

        final state = buildSyntheticState(account: account);

        final cmd = DailyToCashboxTransferCommand(
          operationId: 'op-rec-1',
          accountLineage: 'test-lineage-1',
          transferId: 't-rec-1',
          journalId: 'j-rec-1',
          date: postDate,
          amount: BigInt.from(30000),
          recordedAt: '2026-01-15T12:00:00.000Z',
        );

        final eval =
            RestaurantJournalTransferCommandCoordinator.evaluateTransfer(
              command: cmd,
              state: state,
              cutoverDate: cutoverDate,
              mapper: mapper,
            );

        expect(eval.rejected, isFalse);
        final newState = eval.candidateState!;
        final rawDaysAfter =
            newState.account.toJson()['days'] as Map<String, Object?>;
        final dayAfter =
            rawDaysAfter[postDate.toString()] as Map<String, Object?>;

        // Recovered balance = total (20k) + available (100k) + prior transferred (5k) = 125,000 IQD!
        expect(dayAfter['balance'], 125000);

        final queries = DailyCashQueries(newState.account);
        final snap = queries.day(postDate.toString());
        expect(snap.recordedBalance, BigInt.from(125000));
        expect(snap.transferred, BigInt.from(35000)); // 5k + 30k
        expect(snap.remaining, BigInt.from(70000)); // 100k - 30k
      },
    );
  });
}
