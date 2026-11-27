import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:madar_application/madar_application.dart';
import 'package:madar_data/madar_data.dart';
import 'package:madar_domain/madar_domain.dart';
import 'package:dakhl_restaurant/accounting/daily_cash_queries.dart';
import 'package:dakhl_restaurant/accounting/restaurant_journal_mapper.dart';
import 'package:dakhl_restaurant/accounting/restaurant_journal_sale_commands.dart';
import 'package:dakhl_restaurant/accounting/restaurant_journal_spending_commands.dart';
import 'package:dakhl_restaurant/accounting/restaurant_journal_transfer_commands.dart';
import 'package:dakhl_restaurant/accounts/account_document.dart';
import 'package:dakhl_restaurant/accounts/legacy_account_codec.dart';
import 'package:dakhl_restaurant/accounts/portable_journal_codec.dart';
import 'package:dakhl_restaurant/accounts/portable_journal_state.dart';
import 'package:dakhl_restaurant/sales/return_proposal.dart';

void main() {
  final oracle = jsonDecode(
    File('test/fixtures/legacy/durable-transfer-oracle.json')
        .readAsStringSync(),
  ) as Map<String, dynamic>;
  const legacyCodec = LegacyAccountCodec();
  final mapper = RestaurantJournalMapper();
  const codec = PortableJournalCodec();
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

  Future<StorageFence> currentFence(LocalDocumentWorkspaceStore store) async {
    final res = await store.readDocument();
    if (res is! CapabilitySuccess<DocumentSnapshot?> || res.value == null) {
      throw StateError('Cannot read fence from store: $res');
    }
    return res.value!.fence;
  }

  AccountDocument buildSampleAccount({
    String date = '2026-01-15',
    int? dayBalance = 100000,
    Map<String, Object?>? remainingSnapshot = const {
      'amount': 100000,
      'dailySpent': 0,
      'transferred': 0,
      'salesTotal': 0,
    },
    List<Map<String, Object?>> products = const [],
    List<Map<String, Object?>> expenses = const [],
    List<Map<String, Object?>> transfers = const [],
    Map<String, Map<String, Object?>> additionalDays = const {},
  }) {
    final raw = Map<String, Object?>.from(legacyCodec.empty().toJson());
    raw['products'] = products;
    raw['days'] = {
      date: {
        'expenses': expenses,
        'chickenUsed': 0,
        'chickenLeft': 0,
        'balance': dayBalance,
        'totalOverride': null,
        'remaining': remainingSnapshot,
      },
      ...additionalDays,
    };
    raw['transfers'] = transfers;
    return legacyCodec.decodeJson(raw);
  }

  PortableJournalState buildSyntheticState({
    required AccountDocument account,
    String accountLineage = 'safety-lineage-1',
  }) {
    final cutover = PortableJournalCutoverState.established(
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

    final openEntry = PortableJournalEntry(
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
      journals: [openEntry],
      receipts: const [],
    );
  }

  group(
    'Restaurant Journal Transfer Safety & Frozen JS Differential Parity',
    () {
      late Directory tempDir;
      final openStores = <PowerSyncLocalDocumentWorkspaceStore>[];

      setUp(() async {
        tempDir = await Directory.systemTemp.createTemp(
          'dakhl-transfer-safety-store-',
        );
      });

      tearDown(() async {
        for (final s in openStores) {
          try {
            await s.close();
          } catch (_) {}
        }
        openStores.clear();
        try {
          if (tempDir.existsSync()) {
            tempDir.deleteSync(recursive: true);
          }
        } catch (_) {}
      });

      Future<PowerSyncLocalDocumentWorkspaceStore> openStore() async {
        final res = await PowerSyncLocalDocumentWorkspaceStore.open(
          directoryPath: tempDir.path,
        );
        if (res is! CapabilitySuccess<PowerSyncLocalDocumentWorkspaceStore>) {
          throw StateError('Failed to open store: $res');
        }
        final s = res.value;
        openStores.add(s);
        return s;
      }

      test('Scenario 1: Ordinary transfer differential parity against frozen model.js', () async {
        final fixture = (oracle['scenarios'] as Map)['1'] as Map;
        final js = fixture['summary'] as Map;
        // Frozen JS oracle reference values for Scenario 1:
        // remaining: 80000, transferred: 20000, balance: 100000, cash: 20000
        final jsRemaining = js['remaining'];
        final jsTransferred = js['transferred'];
        final jsBalance = js['balance'];
        final jsCash = js['cash'];

        final store = await openStore();
        final coordinator = RestaurantJournalTransferCommandCoordinator(
          store: store,
          mapper: mapper,
          codec: codec,
        );

        final initialDoc = buildSampleAccount();
        expect(initialDoc.toJson(), fixture['seed']);
        final initialState = buildSyntheticState(account: initialDoc);
        await store.writeDocument(
          codec.encodeState(initialState),
          writeToken: 'seed-sc1',
        );

        final cmd = DailyToCashboxTransferCommand(
          operationId: 'op-sc1',
          accountLineage: 'safety-lineage-1',
          expectedFence: await currentFence(store),
          transferId: 't-sc1',
          journalId: 'j-sc1',
          date: postDate,
          amount: BigInt.from(20000),
          recordedAt: '2026-01-15T12:00:00.000Z',
        );

        final res = await coordinator.execute(cmd);
        expect(
          res,
          isA<DurableCommandSuccess<RestaurantJournalTransferOutcome>>(),
        );

        final readRes = await store.readDocument();
        final snap = (readRes as CapabilitySuccess<DocumentSnapshot?>).value!;
        final state = codec.decodeState(snap.payload);
        expect(state.account.toJson(), fixture['account']);

        final queries = DailyCashQueries(state.account);
        final daySnap = queries.day(postDate.toString());

        expect(daySnap.remaining!.toInt(), equals(jsRemaining));
        expect(daySnap.transferred.toInt(), equals(jsTransferred));
        expect(daySnap.recordedBalance!.toInt(), equals(jsBalance));

        final transferMoves = queries.cashMovements.where(
          (m) => m['kind'] == 'transfer',
        );
        final cashboxTotal = transferMoves.fold<int>(
          0,
          (sum, m) => sum + (m['amount'] as int),
        );
        expect(cashboxTotal, equals(jsCash));
      });

      test(
        'Scenario 2: Transfer-all differential parity against frozen model.js',
        () async {
          final fixture = (oracle['scenarios'] as Map)['2'] as Map;
          final js = fixture['summary'] as Map;
          // Frozen JS oracle reference values for Scenario 2:
          // remaining: 0, transferred: 100000, balance: 100000, cash: 100000
          final jsRemaining = js['remaining'];
          final jsTransferred = js['transferred'];
          final jsBalance = js['balance'];
          final jsCash = js['cash'];

          final store = await openStore();
          final coordinator = RestaurantJournalTransferCommandCoordinator(
            store: store,
            mapper: mapper,
            codec: codec,
          );

          final initialDoc = buildSampleAccount();
          expect(initialDoc.toJson(), fixture['seed']);
          final initialState = buildSyntheticState(account: initialDoc);
          await store.writeDocument(
            codec.encodeState(initialState),
            writeToken: 'seed-sc2',
          );

          final cmd = DailyToCashboxTransferCommand(
            operationId: 'op-sc2',
            accountLineage: 'safety-lineage-1',
            expectedFence: await currentFence(store),
            transferId: 't-sc2',
            journalId: 'j-sc2',
            date: postDate,
            amount: BigInt.from(100000),
            recordedAt: '2026-01-15T12:00:00.000Z',
          );

          final res = await coordinator.execute(cmd);
          expect(
            res,
            isA<DurableCommandSuccess<RestaurantJournalTransferOutcome>>(),
          );

          final readRes = await store.readDocument();
          final snap = (readRes as CapabilitySuccess<DocumentSnapshot?>).value!;
          final state = codec.decodeState(snap.payload);
          expect(state.account.toJson(), fixture['account']);

          final queries = DailyCashQueries(state.account);
          final daySnap = queries.day(postDate.toString());

          expect(daySnap.remaining!.toInt(), equals(jsRemaining));
          expect(daySnap.transferred.toInt(), equals(jsTransferred));
          expect(daySnap.recordedBalance!.toInt(), equals(jsBalance));

          final transferMoves = queries.cashMovements.where(
            (m) => m['kind'] == 'transfer',
          );
          final cashboxTotal = transferMoves.fold<int>(
            0,
            (sum, m) => sum + (m['amount'] as int),
          );
          expect(cashboxTotal, equals(jsCash));
        },
      );

      test('Scenario 3: Legacy unset-total recovery differential parity against frozen model.js', () async {
        final fixture = (oracle['scenarios'] as Map)['3'] as Map;
        final js = fixture['summary'] as Map;
        // Frozen JS oracle reference values for Scenario 3:
        // remaining: 70000, transferred: 35000, balance: 125000, cash: 35000
        final jsRemaining = js['remaining'];
        final jsTransferred = js['transferred'];
        final jsBalance = js['balance'];
        final jsCash = js['cash'];

        final store = await openStore();
        final coordinator = RestaurantJournalTransferCommandCoordinator(
          store: store,
          mapper: mapper,
          codec: codec,
        );

        final initialDoc = buildSampleAccount(
          dayBalance: null, // Unset total
          remainingSnapshot: {
            'amount': 100000,
            'dailySpent': 20000,
            'transferred': 5000,
            'salesTotal': 0,
          },
          expenses: [
            {
              'id': 'e1',
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
              'id': 't0',
              'date': postDate.toString(),
              'amount': 5000,
              'createdAt': '2026-01-15T09:00:00.000Z',
            },
          ],
        );

        expect(initialDoc.toJson(), fixture['seed']);
        final initialState = buildSyntheticState(account: initialDoc);
        await store.writeDocument(
          codec.encodeState(initialState),
          writeToken: 'seed-sc3',
        );

        final cmd = DailyToCashboxTransferCommand(
          operationId: 'op-sc3',
          accountLineage: 'safety-lineage-1',
          expectedFence: await currentFence(store),
          transferId: 't-sc3',
          journalId: 'j-sc3',
          date: postDate,
          amount: BigInt.from(30000),
          recordedAt: '2026-01-15T12:00:00.000Z',
        );

        final res = await coordinator.execute(cmd);
        expect(
          res,
          isA<DurableCommandSuccess<RestaurantJournalTransferOutcome>>(),
        );

        final readRes = await store.readDocument();
        final snap = (readRes as CapabilitySuccess<DocumentSnapshot?>).value!;
        final state = codec.decodeState(snap.payload);
        expect(state.account.toJson(), fixture['account']);

        final queries = DailyCashQueries(state.account);
        final daySnap = queries.day(postDate.toString());

        expect(daySnap.remaining!.toInt(), equals(jsRemaining));
        expect(daySnap.transferred.toInt(), equals(jsTransferred));
        expect(daySnap.recordedBalance!.toInt(), equals(jsBalance));

        final transferMoves = queries.cashMovements.where(
          (m) => m['kind'] == 'transfer',
        );
        final cashboxTotal = transferMoves.fold<int>(
          0,
          (sum, m) => sum + (m['amount'] as int),
        );
        expect(cashboxTotal, equals(jsCash));
      });

      test('Scenario 4: Subsequent dated effects differential parity against frozen model.js', () async {
        final fixture = (oracle['scenarios'] as Map)['4'] as Map;
        final js = fixture['summary'] as Map;
        // Frozen JS oracle reference values for Scenario 4:
        // remaining: 60000, transferred: 35000, balance: 100000, cash: 35000, dailySpent: 25000, salesTotal: 0
        final jsRemaining = js['remaining'];
        final jsTransferred = js['transferred'];
        final jsBalance = js['balance'];
        final jsCash = js['cash'];
        final jsDailySpent = js['dailySpent'];
        final jsSalesTotal = js['salesTotal'];

        final store = await openStore();
        final transferCoordinator = RestaurantJournalTransferCommandCoordinator(
          store: store,
          mapper: mapper,
          codec: codec,
        );
        final salesCoordinator = RestaurantJournalSaleCommandCoordinator(
          store: store,
          mapper: mapper,
          codec: codec,
        );
        final spendingCoordinator = RestaurantJournalSpendingCommandCoordinator(
          store: store,
          mapper: mapper,
          codec: codec,
        );

        final initialDoc = buildSampleAccount(
          products: [
            {
              'id': 'prod-1',
              'name': 'Kebab',
              'code': '',
              'group': '',
              'unit': 'plate',
              'price': 10000,
              'minStock': 0,
              'trackStock': false,
              'archived': false,
            },
          ],
          expenses: [
            {
              'id': 'e1',
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
          remainingSnapshot: {
            'amount': 100000,
            'dailySpent': 20000,
            'transferred': 0,
            'salesTotal': 0,
          },
        );
        expect(initialDoc.toJson(), fixture['seed']);
        final initialState = buildSyntheticState(account: initialDoc);
        await store.writeDocument(
          codec.encodeState(initialState),
          writeToken: 'seed-sc4',
        );

        // 1. Transfer 20,000
        await transferCoordinator.execute(
          DailyToCashboxTransferCommand(
            operationId: 'op-sc4-t1',
            accountLineage: 'safety-lineage-1',
            expectedFence: await currentFence(store),
            transferId: 't-sc4-1',
            journalId: 'j-sc4-1',
            date: postDate,
            amount: BigInt.from(20000),
            recordedAt: '2026-01-15T11:00:00.000Z',
          ),
        );

        // 2. Sale 10,000
        await salesCoordinator.execute(
          CompleteSaleCommand(
            operationId: 'op-sc4-sale',
            accountLineage: 'safety-lineage-1',
            expectedFence: await currentFence(store),
            saleId: 'sale-sc4-1',
            journalId: 'j-sale-sc4-1',
            draft: {
              'date': '2026-01-15',
              'lines': [
                {'productId': 'prod-1', 'quantity': 1},
              ],
              'discount': 0,
              'orderType': 'صالة',
            },
            recordedAt: '2026-01-15T12:00:00.000Z',
          ),
        );

        // 3. Daily Expense 5,000
        await spendingCoordinator.execute(
          CreateOperatingExpenseCommand(
            operationId: 'op-sc4-exp',
            accountLineage: 'safety-lineage-1',
            expectedFence: await currentFence(store),
            expenseId: 'exp-sc4-2',
            journalId: 'j-exp-sc4-2',
            date: postDate,
            categoryId: 'samoon',
            amount: BigInt.from(5000),
            fundingSource: FundingSource.daily,
            dailyAmount: BigInt.from(5000),
            cashAmount: BigInt.zero,
            note: '',
            recordedAt: '2026-01-15T13:00:00.000Z',
          ),
        );

        // 4. Return Sale 10,000
        await salesCoordinator.execute(
          SaleReturnCommand(
            operationId: 'op-sc4-ret',
            accountLineage: 'safety-lineage-1',
            expectedFence: await currentFence(store),
            returnId: 'ret-sc4-1',
            saleId: 'sale-sc4-1',
            journalId: 'j-ret-sc4-1',
            returnDate: postDate,
            reason: 'return',
            recordedAt: '2026-01-15T14:00:00.000Z',
            today: postDate,
            lines: [
              ReturnLineRequest(
                productId: 'prod-1',
                quantityUnits: BigInt.from(1000),
                restock: false,
              ),
            ],
          ),
        );

        // 5. Transfer 15,000
        await transferCoordinator.execute(
          DailyToCashboxTransferCommand(
            operationId: 'op-sc4-t2',
            accountLineage: 'safety-lineage-1',
            expectedFence: await currentFence(store),
            transferId: 't-sc4-2',
            journalId: 'j-sc4-2',
            date: postDate,
            amount: BigInt.from(15000),
            recordedAt: '2026-01-15T15:00:00.000Z',
          ),
        );

        final readRes = await store.readDocument();
        final snap = (readRes as CapabilitySuccess<DocumentSnapshot?>).value!;
        final state = codec.decodeState(snap.payload);
        expect(state.account.toJson(), fixture['account']);

        final queries = DailyCashQueries(state.account);
        final daySnap = queries.day(postDate.toString());

        expect(daySnap.remaining!.toInt(), equals(jsRemaining));
        expect(daySnap.transferred.toInt(), equals(jsTransferred));
        expect(daySnap.recordedBalance!.toInt(), equals(jsBalance));
        expect(daySnap.dailySpent.toInt(), equals(jsDailySpent));
        expect(daySnap.netSales.toInt(), equals(jsSalesTotal));

        final transferMoves = queries.cashMovements.where(
          (m) => m['kind'] == 'transfer',
        );
        final cashboxTotal = transferMoves.fold<int>(
          0,
          (sum, m) => sum + (m['amount'] as int),
        );
        expect(cashboxTotal, equals(jsCash));
      });

      test('multi-date isolation: transfers on date A do not change available remaining on date B', () async {
        final dateA = postDate;
        final dateB = DateOnly.parse(
          '2026-01-16',
          minimumYear: 1000,
          maximumYear: 9999,
        );

        final store = await openStore();
        final coordinator = RestaurantJournalTransferCommandCoordinator(
          store: store,
          mapper: mapper,
          codec: codec,
        );

        final initialDoc = buildSampleAccount(
          date: dateA.toString(),
          remainingSnapshot: {
            'amount': 80000,
            'dailySpent': 0,
            'transferred': 0,
            'salesTotal': 0,
          },
          additionalDays: {
            dateB.toString(): {
              'expenses': <Map<String, Object?>>[],
              'chickenUsed': 0,
              'chickenLeft': 0,
              'balance': 50000,
              'totalOverride': null,
              'remaining': {
                'amount': 50000,
                'dailySpent': 0,
                'transferred': 0,
                'salesTotal': 0,
              },
            },
          },
        );
        final initialState = buildSyntheticState(account: initialDoc);
        await store.writeDocument(
          codec.encodeState(initialState),
          writeToken: 'seed-multidate',
        );

        // Transfer 30k on date A
        await coordinator.execute(
          DailyToCashboxTransferCommand(
            operationId: 'op-date-a',
            accountLineage: 'safety-lineage-1',
            expectedFence: await currentFence(store),
            transferId: 't-date-a',
            journalId: 'j-date-a',
            date: dateA,
            amount: BigInt.from(30000),
            recordedAt: '2026-01-15T12:00:00.000Z',
          ),
        );

        final readRes = await store.readDocument();
        final snap = (readRes as CapabilitySuccess<DocumentSnapshot?>).value!;
        final state = codec.decodeState(snap.payload);
        final queries = DailyCashQueries(state.account);

        // Date A updated
        final snapA = queries.day(dateA.toString());
        expect(snapA.transferred, BigInt.from(30000));
        expect(snapA.remaining, BigInt.from(50000)); // 80k - 30k

        // Date B completely unaffected
        final snapB = queries.day(dateB.toString());
        expect(snapB.transferred, BigInt.zero);
        expect(snapB.remaining, BigInt.from(50000));
        expect(snapB.recordedBalance, BigInt.from(50000));
      });

      test('exact boundary: transfer of minimal 1 IQD succeeds, transfer of available+1 rejects', () async {
        final store = await openStore();
        final coordinator = RestaurantJournalTransferCommandCoordinator(
          store: store,
          mapper: mapper,
          codec: codec,
        );

        final initialDoc = buildSampleAccount(
          remainingSnapshot: {
            'amount': 1000,
            'dailySpent': 0,
            'transferred': 0,
            'salesTotal': 0,
          },
        );
        final initialState = buildSyntheticState(account: initialDoc);
        await store.writeDocument(
          codec.encodeState(initialState),
          writeToken: 'seed-bound',
        );

        // 1. Transfer minimal 1 IQD
        final res1 = await coordinator.execute(
          DailyToCashboxTransferCommand(
            operationId: 'op-min-1',
            accountLineage: 'safety-lineage-1',
            expectedFence: await currentFence(store),
            transferId: 't-min-1',
            journalId: 'j-min-1',
            date: postDate,
            amount: BigInt.one,
            recordedAt: '2026-01-15T12:00:00.000Z',
          ),
        );
        expect(
          res1,
          isA<DurableCommandSuccess<RestaurantJournalTransferOutcome>>(),
        );

        // Now available is 999 IQD
        // 2. Transfer of 1000 IQD (available + 1) must reject with excessive_transfer_amount
        final res2 = await coordinator.execute(
          DailyToCashboxTransferCommand(
            operationId: 'op-excess-1',
            accountLineage: 'safety-lineage-1',
            expectedFence: await currentFence(store),
            transferId: 't-excess-1',
            journalId: 'j-excess-1',
            date: postDate,
            amount: BigInt.from(1000), // 1000 > 999
            recordedAt: '2026-01-15T13:00:00.000Z',
          ),
        );
        expect(
          res2,
          isA<DurableCommandFailure<RestaurantJournalTransferOutcome>>(),
        );
        final fail =
            res2 as DurableCommandFailure<RestaurantJournalTransferOutcome>;
        expect(
          fail.code,
          RestaurantJournalTransferErrorCodes.excessiveTransferAmount,
        );

        // 3. Transfer of exactly 999 IQD succeeds and leaves zero
        final res3 = await coordinator.execute(
          DailyToCashboxTransferCommand(
            operationId: 'op-exact-remain',
            accountLineage: 'safety-lineage-1',
            expectedFence: await currentFence(store),
            transferId: 't-exact-1',
            journalId: 'j-exact-1',
            date: postDate,
            amount: BigInt.from(999),
            recordedAt: '2026-01-15T14:00:00.000Z',
          ),
        );
        expect(
          res3,
          isA<DurableCommandSuccess<RestaurantJournalTransferOutcome>>(),
        );

        final readRes = await store.readDocument();
        final snap = (readRes as CapabilitySuccess<DocumentSnapshot?>).value!;
        final state = codec.decodeState(snap.payload);
        final queries = DailyCashQueries(state.account);
        final daySnap = queries.day(postDate.toString());

        expect(daySnap.transferred, BigInt.from(1000));
        expect(daySnap.remaining, BigInt.zero);
      });
    },
  );
}
