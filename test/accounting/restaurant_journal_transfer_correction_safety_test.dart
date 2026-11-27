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
import 'package:dakhl_restaurant/accounting/restaurant_journal_transfer_correction_commands.dart';
import 'package:dakhl_restaurant/accounts/account_document.dart';
import 'package:dakhl_restaurant/accounts/legacy_account_codec.dart';
import 'package:dakhl_restaurant/accounts/portable_journal_codec.dart';
import 'package:dakhl_restaurant/accounts/portable_journal_state.dart';
import 'package:dakhl_restaurant/sales/return_proposal.dart';

void main() {
  final oracle = jsonDecode(
    File('test/fixtures/legacy/durable-transfer-corrections-oracle.json')
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

  PortableJournalState buildSyntheticState({
    required AccountDocument account,
    String accountLineage = 'safety-correction-lineage-1',
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

  group('Restaurant Journal Transfer Correction Safety & Frozen JS Differential Parity', () {
    late Directory tempDir;
    final openStores = <PowerSyncLocalDocumentWorkspaceStore>[];

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp(
        'dakhl-transfer-correction-safety-',
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

    test('Scenario 1: 20k -> 30k -> delete differential parity against frozen model.js and renderer.js', () async {
      final fixture = (oracle['scenarios'] as Map)['1'] as Map;
      final seedAccount = legacyCodec.decodeJson(
        (fixture['seed'] as Map).cast<String, Object?>(),
      );

      final store = await openStore();
      final transferCoord = RestaurantJournalTransferCommandCoordinator(
        store: store,
        mapper: mapper,
      );
      final correctionCoord =
          RestaurantJournalTransferCorrectionCommandCoordinator(
            store: store,
            mapper: mapper,
          );

      final initialState = buildSyntheticState(account: seedAccount);
      await store.writeDocument(
        codec.encodeState(initialState),
        writeToken: 'tok-init',
      );

      // 1. Create transfer 20k
      final fence1 = await currentFence(store);
      final createCmd = DailyToCashboxTransferCommand(
        operationId: 'op-sc1-create',
        accountLineage: initialState.accountLineage,
        expectedFence: fence1,
        transferId: 't1',
        journalId: 'j1',
        date: postDate,
        amount: BigInt.from(20000),
        recordedAt: '2026-01-15T10:00:00.000Z',
      );
      final createRes = await transferCoord.execute(createCmd);
      expect(
        createRes,
        isA<DurableCommandSuccess<RestaurantJournalTransferOutcome>>(),
      );

      final stateAfterCreate = codec.decodeState(
        ((await store.readDocument()) as CapabilitySuccess<DocumentSnapshot?>)
            .value!
            .payload,
      );
      final expectedAccountCreate = (fixture['afterCreate']['account'] as Map)
          .cast<String, Object?>();
      expect(
        stateAfterCreate.account.toJson()['transfers'],
        expectedAccountCreate['transfers'],
      );

      final queries1 = DailyCashQueries(stateAfterCreate.account);
      final snap1 = queries1.day('2026-01-15');
      final jsSummary1 = fixture['afterCreate']['summary'] as Map;
      expect(snap1.remaining, BigInt.from(jsSummary1['remaining'] as int));
      expect(snap1.transferred, BigInt.from(jsSummary1['transferred'] as int));
      expect(snap1.recordedBalance, BigInt.from(jsSummary1['balance'] as int));

      // 2. Edit transfer 20k -> 30k
      final fence2 = await currentFence(store);
      final editCmd = EditDailyTransferCommand(
        operationId: 'op-sc1-edit',
        accountLineage: initialState.accountLineage,
        expectedFence: fence2,
        transferId: 't1',
        expectedActiveJournalId: 'j1',
        inverseJournalId: 'j-inv-1',
        replacementJournalId: 'j-repl-1',
        newAmount: BigInt.from(30000),
        reason: 'Adjust transfer amount to 30k',
        recordedAt: '2026-01-15T12:00:00.000Z',
      );

      final editRes = await correctionCoord.executeEdit(editCmd);
      expect(
        editRes,
        isA<
          DurableCommandSuccess<RestaurantJournalTransferCorrectionOutcome>
        >(),
      );

      final stateAfterEdit = codec.decodeState(
        ((await store.readDocument()) as CapabilitySuccess<DocumentSnapshot?>)
            .value!
            .payload,
      );
      final expectedAccountEdit = (fixture['afterEdit']['account'] as Map)
          .cast<String, Object?>();
      expect(
        stateAfterEdit.account.toJson()['transfers'],
        expectedAccountEdit['transfers'],
      );

      final queries2 = DailyCashQueries(stateAfterEdit.account);
      final snap2 = queries2.day('2026-01-15');
      final jsSummary2 = fixture['afterEdit']['summary'] as Map;
      expect(snap2.remaining, BigInt.from(jsSummary2['remaining'] as int));
      expect(snap2.transferred, BigInt.from(jsSummary2['transferred'] as int));
      expect(snap2.recordedBalance, BigInt.from(jsSummary2['balance'] as int));

      // 3. Delete transfer
      final fence3 = await currentFence(store);
      final delCmd = DeleteDailyTransferCommand(
        operationId: 'op-sc1-del',
        accountLineage: initialState.accountLineage,
        expectedFence: fence3,
        transferId: 't1',
        expectedActiveJournalId: 'j-repl-1',
        inverseJournalId: 'j-del-inv-1',
        reason: 'Delete transfer and return funds to drawer',
        recordedAt: '2026-01-15T14:00:00.000Z',
      );
      final delRes = await correctionCoord.executeDelete(delCmd);
      expect(
        delRes,
        isA<
          DurableCommandSuccess<RestaurantJournalTransferCorrectionOutcome>
        >(),
      );

      final stateAfterDel = codec.decodeState(
        ((await store.readDocument()) as CapabilitySuccess<DocumentSnapshot?>)
            .value!
            .payload,
      );
      final expectedAccountDel = (fixture['afterDelete']['account'] as Map)
          .cast<String, Object?>();
      expect(
        stateAfterDel.account.toJson()['transfers'],
        expectedAccountDel['transfers'],
      );

      final queries3 = DailyCashQueries(stateAfterDel.account);
      final snap3 = queries3.day('2026-01-15');
      final jsSummary3 = fixture['afterDelete']['summary'] as Map;
      expect(snap3.remaining, BigInt.from(jsSummary3['remaining'] as int));
      expect(snap3.transferred, BigInt.from(jsSummary3['transferred'] as int));
      expect(snap3.recordedBalance, BigInt.from(jsSummary3['balance'] as int));

      // 4. Replay create, edit, and delete commands against the final store
      final replayCreate = await transferCoord.execute(createCmd);
      expect(
        replayCreate,
        isA<DurableCommandReplayed<RestaurantJournalTransferOutcome>>(),
      );
      final outcomeCreate =
          (replayCreate
                  as DurableCommandReplayed<RestaurantJournalTransferOutcome>)
              .outcome;
      expect(outcomeCreate!.netAmount, '20000');

      final replayEdit = await correctionCoord.executeEdit(editCmd);
      expect(
        replayEdit,
        isA<
          DurableCommandReplayed<RestaurantJournalTransferCorrectionOutcome>
        >(),
      );
      final outcomeEdit =
          (replayEdit
                  as DurableCommandReplayed<
                    RestaurantJournalTransferCorrectionOutcome
                  >)
              .outcome;
      expect(outcomeEdit!.netAmount, '30000');
      expect(outcomeEdit.replacementJournalId, 'j-repl-1');

      final replayDel = await correctionCoord.executeDelete(delCmd);
      expect(
        replayDel,
        isA<
          DurableCommandReplayed<RestaurantJournalTransferCorrectionOutcome>
        >(),
      );
      final outcomeDel =
          (replayDel
                  as DurableCommandReplayed<
                    RestaurantJournalTransferCorrectionOutcome
                  >)
              .outcome;
      expect(outcomeDel!.netAmount, '30000');
      expect(outcomeDel.replacementJournalId, isNull);
    });

    test('Scenario 2: Repeated edits (20k -> 40k -> 25k -> 50k) parity and historical replay', () async {
      final fixture = (oracle['scenarios'] as Map)['2'] as Map;
      final seedAccount = legacyCodec.decodeJson(
        (fixture['seed'] as Map).cast<String, Object?>(),
      );

      final store = await openStore();
      final transferCoord = RestaurantJournalTransferCommandCoordinator(
        store: store,
        mapper: mapper,
      );
      final correctionCoord =
          RestaurantJournalTransferCorrectionCommandCoordinator(
            store: store,
            mapper: mapper,
          );

      final initialState = buildSyntheticState(account: seedAccount);
      await store.writeDocument(
        codec.encodeState(initialState),
        writeToken: 'tok-init-2',
      );

      // Create 20k
      var fence = await currentFence(store);
      final cmdCreate = DailyToCashboxTransferCommand(
        operationId: 'op-sc2-create',
        accountLineage: initialState.accountLineage,
        expectedFence: fence,
        transferId: 't2',
        journalId: 'j2-0',
        date: postDate,
        amount: BigInt.from(20000),
        recordedAt: '2026-01-15T10:00:00.000Z',
      );
      await transferCoord.execute(cmdCreate);

      // Edit 1: 40k
      fence = await currentFence(store);
      final cmdEdit1 = EditDailyTransferCommand(
        operationId: 'op-sc2-edit1',
        accountLineage: initialState.accountLineage,
        expectedFence: fence,
        transferId: 't2',
        expectedActiveJournalId: 'j2-0',
        inverseJournalId: 'j2-inv1',
        replacementJournalId: 'j2-repl1',
        newAmount: BigInt.from(40000),
        reason: 'Edit to 40k',
        recordedAt: '2026-01-15T11:00:00.000Z',
      );
      await correctionCoord.executeEdit(cmdEdit1);

      var state = codec.decodeState(
        ((await store.readDocument()) as CapabilitySuccess<DocumentSnapshot?>)
            .value!
            .payload,
      );
      var snap = DailyCashQueries(state.account).day('2026-01-15');
      var jsSummary = fixture['afterEdit1']['summary'] as Map;
      expect(snap.remaining, BigInt.from(jsSummary['remaining'] as int));
      expect(snap.transferred, BigInt.from(jsSummary['transferred'] as int));

      // Edit 2: 25k
      fence = await currentFence(store);
      final cmdEdit2 = EditDailyTransferCommand(
        operationId: 'op-sc2-edit2',
        accountLineage: initialState.accountLineage,
        expectedFence: fence,
        transferId: 't2',
        expectedActiveJournalId: 'j2-repl1',
        inverseJournalId: 'j2-inv2',
        replacementJournalId: 'j2-repl2',
        newAmount: BigInt.from(25000),
        reason: 'Edit to 25k',
        recordedAt: '2026-01-15T12:00:00.000Z',
      );
      await correctionCoord.executeEdit(cmdEdit2);

      state = codec.decodeState(
        ((await store.readDocument()) as CapabilitySuccess<DocumentSnapshot?>)
            .value!
            .payload,
      );
      snap = DailyCashQueries(state.account).day('2026-01-15');
      jsSummary = fixture['afterEdit2']['summary'] as Map;
      expect(snap.remaining, BigInt.from(jsSummary['remaining'] as int));
      expect(snap.transferred, BigInt.from(jsSummary['transferred'] as int));

      // Edit 3: 50k
      fence = await currentFence(store);
      final cmdEdit3 = EditDailyTransferCommand(
        operationId: 'op-sc2-edit3',
        accountLineage: initialState.accountLineage,
        expectedFence: fence,
        transferId: 't2',
        expectedActiveJournalId: 'j2-repl2',
        inverseJournalId: 'j2-inv3',
        replacementJournalId: 'j2-repl3',
        newAmount: BigInt.from(50000),
        reason: 'Edit to 50k',
        recordedAt: '2026-01-15T13:00:00.000Z',
      );
      await correctionCoord.executeEdit(cmdEdit3);

      state = codec.decodeState(
        ((await store.readDocument()) as CapabilitySuccess<DocumentSnapshot?>)
            .value!
            .payload,
      );
      snap = DailyCashQueries(state.account).day('2026-01-15');
      jsSummary = fixture['afterEdit3']['summary'] as Map;
      expect(snap.remaining, BigInt.from(jsSummary['remaining'] as int));
      expect(snap.transferred, BigInt.from(jsSummary['transferred'] as int));

      // Replay all previous commands against the store
      final repCreate = await transferCoord.execute(cmdCreate);
      expect(
        repCreate,
        isA<DurableCommandReplayed<RestaurantJournalTransferOutcome>>(),
      );
      expect(
        (repCreate as DurableCommandReplayed<RestaurantJournalTransferOutcome>)
            .outcome!
            .netAmount,
        '20000',
      );

      final repEdit1 = await correctionCoord.executeEdit(cmdEdit1);
      expect(
        repEdit1,
        isA<
          DurableCommandReplayed<RestaurantJournalTransferCorrectionOutcome>
        >(),
      );
      expect(
        (repEdit1
                as DurableCommandReplayed<
                  RestaurantJournalTransferCorrectionOutcome
                >)
            .outcome!
            .netAmount,
        '40000',
      );

      final repEdit2 = await correctionCoord.executeEdit(cmdEdit2);
      expect(
        repEdit2,
        isA<
          DurableCommandReplayed<RestaurantJournalTransferCorrectionOutcome>
        >(),
      );
      expect(
        (repEdit2
                as DurableCommandReplayed<
                  RestaurantJournalTransferCorrectionOutcome
                >)
            .outcome!
            .netAmount,
        '25000',
      );

      final repEdit3 = await correctionCoord.executeEdit(cmdEdit3);
      expect(
        repEdit3,
        isA<
          DurableCommandReplayed<RestaurantJournalTransferCorrectionOutcome>
        >(),
      );
      expect(
        (repEdit3
                as DurableCommandReplayed<
                  RestaurantJournalTransferCorrectionOutcome
                >)
            .outcome!
            .netAmount,
        '50000',
      );
    });

    test('Scenario 3: Legacy unset-total recovery and delete balance preservation parity', () async {
      final fixture = (oracle['scenarios'] as Map)['3'] as Map;
      final seedAccount = legacyCodec.decodeJson(
        (fixture['seed'] as Map).cast<String, Object?>(),
      );

      final store = await openStore();
      final correctionCoord =
          RestaurantJournalTransferCorrectionCommandCoordinator(
            store: store,
            mapper: mapper,
          );

      final cutover = PortableJournalCutoverState.established(
        cutoverDate: cutoverDate,
        openingJournalId: 'open-jnl-1',
      );
      final openEntry = PortableJournalEntry(
        journal: BalancedJournal.validate(
          id: 'open-jnl-1',
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
      );

      // Map initial transfer t0 (5000)
      final t0Proposal = mapper.mapDailyToCashboxTransfer(
        journalId: 'j-t0',
        transferId: 't0',
        effectiveDate: postDate,
        amount: BigInt.from(5000),
      );
      final t0Entry = PortableJournalEntry(
        journal: t0Proposal.journal,
        sourceType: t0Proposal.sourceType.name,
        sourceRecordId: 't0',
        recordedAt: '2026-01-15T08:00:00.000Z',
        metadata: {
          'operationId': 'op-sc3-seed',
          'transferId': 't0',
          'date': '2026-01-15',
          'amount': '5000',
          'sourceVersion': '11',
        },
      );

      final initialState = PortableJournalState(
        accountLineage: 'sc3-lineage',
        account: seedAccount,
        sourceProvenance: const PortableJournalSourceProvenance(
          sourceVersion: 11,
          enrolledAt: '2026-01-01T00:00:00.000Z',
          migrated: false,
        ),
        cutoverState: cutover,
        journals: [openEntry, t0Entry],
        receipts: [
          DurableCommandReceipt(
            identity: DailyToCashboxTransferCommand(
              operationId: 'op-sc3-seed',
              accountLineage: 'sc3-lineage',
              expectedFence: const StorageFence(
                storeId: 'fixture-store',
                generation: 'fixture-generation',
              ),
              transferId: 't0',
              journalId: 'j-t0',
              date: postDate,
              amount: BigInt.from(5000),
              recordedAt: '2026-01-15T08:00:00.000Z',
            ).identity,
            status: DurableCommandStatus.committed,
            outcomePayload: RestaurantJournalTransferOutcome(
              commandType: 'daily_to_cashbox_transfer',
              operationId: 'op-sc3-seed',
              transferId: 't0',
              journalId: 'j-t0',
              effectiveDate: '2026-01-15',
              netAmount: '5000',
              metadata: t0Entry.metadata,
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
      await store.writeDocument(
        codec.encodeState(initialState),
        writeToken: 'tok-init-3',
      );

      // Edit t0 to 15,000 -> recovers unset balance to 125,000
      var fence = await currentFence(store);
      final editCmd = EditDailyTransferCommand(
        operationId: 'op-sc3-edit',
        accountLineage: initialState.accountLineage,
        expectedFence: fence,
        transferId: 't0',
        expectedActiveJournalId: 'j-t0',
        inverseJournalId: 'j-t0-inv',
        replacementJournalId: 'j-t0-repl',
        newAmount: BigInt.from(15000),
        reason: 'Recover and edit to 15k',
        recordedAt: '2026-01-15T09:00:00.000Z',
      );
      await correctionCoord.executeEdit(editCmd);

      var state = codec.decodeState(
        ((await store.readDocument()) as CapabilitySuccess<DocumentSnapshot?>)
            .value!
            .payload,
      );
      var dayData =
          (state.account.toJson()['days'] as Map)['2026-01-15'] as Map;
      expect(dayData['balance'], 125000);
      var snap = DailyCashQueries(state.account).day('2026-01-15');
      final jsSummary1 = fixture['afterEdit']['summary'] as Map;
      expect(snap.remaining, BigInt.from(jsSummary1['remaining'] as int));
      expect(snap.transferred, BigInt.from(jsSummary1['transferred'] as int));

      // Delete t0 -> preserves recovered balance at 125,000
      fence = await currentFence(store);
      final delCmd = DeleteDailyTransferCommand(
        operationId: 'op-sc3-del',
        accountLineage: initialState.accountLineage,
        expectedFence: fence,
        transferId: 't0',
        expectedActiveJournalId: 'j-t0-repl',
        inverseJournalId: 'j-t0-del-inv',
        reason: 'Delete t0',
        recordedAt: '2026-01-15T10:00:00.000Z',
      );
      await correctionCoord.executeDelete(delCmd);

      state = codec.decodeState(
        ((await store.readDocument()) as CapabilitySuccess<DocumentSnapshot?>)
            .value!
            .payload,
      );
      dayData = (state.account.toJson()['days'] as Map)['2026-01-15'] as Map;
      expect(dayData['balance'], 125000); // Preserved!
      snap = DailyCashQueries(state.account).day('2026-01-15');
      final jsSummary2 = fixture['afterDelete']['summary'] as Map;
      expect(snap.remaining, BigInt.from(jsSummary2['remaining'] as int));
      expect(snap.transferred, BigInt.from(jsSummary2['transferred'] as int));
    });

    test('Scenario 4: Intervening sales, refunds, expenses between create, edit, delete', () async {
      final fixture = (oracle['scenarios'] as Map)['4'] as Map;
      final seedAccount = legacyCodec.decodeJson(
        (fixture['seed'] as Map).cast<String, Object?>(),
      );

      final store = await openStore();
      final transferCoord = RestaurantJournalTransferCommandCoordinator(
        store: store,
        mapper: mapper,
      );
      final correctionCoord =
          RestaurantJournalTransferCorrectionCommandCoordinator(
            store: store,
            mapper: mapper,
          );

      final initialState = buildSyntheticState(account: seedAccount);
      await store.writeDocument(
        codec.encodeState(initialState),
        writeToken: 'tok-init-4',
      );

      // 1. Create transfer 20k
      var fence = await currentFence(store);
      final createCmd = DailyToCashboxTransferCommand(
        operationId: 'op-sc4-create',
        accountLineage: initialState.accountLineage,
        expectedFence: fence,
        transferId: 't4',
        journalId: 'j4-0',
        date: postDate,
        amount: BigInt.from(20000),
        recordedAt: '2026-01-15T10:00:00.000Z',
      );
      await transferCoord.execute(createCmd);

      final salesCoord = RestaurantJournalSaleCommandCoordinator(
        store: store,
        mapper: mapper,
      );
      final spendingCoord = RestaurantJournalSpendingCommandCoordinator(
        store: store,
        mapper: mapper,
      );

      // 2. Intervening sale of 10k
      fence = await currentFence(store);
      await salesCoord.execute(
        CompleteSaleCommand(
          operationId: 'op-sc4-sale',
          accountLineage: initialState.accountLineage,
          expectedFence: fence,
          saleId: 'sale-1',
          journalId: 'j-sale-1',
          draft: {
            'date': '2026-01-15',
            'lines': [
              {'productId': 'prod-1', 'quantity': 1},
            ],
            'discount': 0,
            'orderType': 'صالة',
          },
          recordedAt: '2026-01-15T11:00:00.000Z',
        ),
      );

      // 3. Intervening expense of 5k
      fence = await currentFence(store);
      await spendingCoord.execute(
        CreateOperatingExpenseCommand(
          operationId: 'op-sc4-exp',
          accountLineage: initialState.accountLineage,
          expectedFence: fence,
          expenseId: 'exp-1',
          journalId: 'j-exp-1',
          date: postDate,
          categoryId: 'samoon',
          amount: BigInt.from(5000),
          fundingSource: FundingSource.daily,
          dailyAmount: BigInt.from(5000),
          cashAmount: BigInt.zero,
          note: '',
          recordedAt: '2026-01-15T12:00:00.000Z',
        ),
      );

      // 4. Intervening refund of 10k
      fence = await currentFence(store);
      await salesCoord.execute(
        SaleReturnCommand(
          operationId: 'op-sc4-ret',
          accountLineage: initialState.accountLineage,
          expectedFence: fence,
          returnId: 'ret-1',
          saleId: 'sale-1',
          journalId: 'j-ref-1',
          returnDate: postDate,
          reason: 'customer return',
          recordedAt: '2026-01-15T13:00:00.000Z',
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

      var state = codec.decodeState(
        ((await store.readDocument()) as CapabilitySuccess<DocumentSnapshot?>)
            .value!
            .payload,
      );
      var snap = DailyCashQueries(state.account).day('2026-01-15');
      var jsSummary = fixture['afterRefund']['summary'] as Map;
      expect(snap.remaining, BigInt.from(jsSummary['remaining'] as int));

      // 5. Edit transfer to 35,000 (available remaining was 75k + old 20k = 95k)
      fence = await currentFence(store);
      final editCmd = EditDailyTransferCommand(
        operationId: 'op-sc4-edit',
        accountLineage: initialState.accountLineage,
        expectedFence: fence,
        transferId: 't4',
        expectedActiveJournalId: 'j4-0',
        inverseJournalId: 'j4-inv1',
        replacementJournalId: 'j4-repl1',
        newAmount: BigInt.from(35000),
        reason: 'Edit to 35k after intervening activity',
        recordedAt: '2026-01-15T14:00:00.000Z',
      );

      final editRes = await correctionCoord.executeEdit(editCmd);
      expect(
        editRes,
        isA<
          DurableCommandSuccess<RestaurantJournalTransferCorrectionOutcome>
        >(),
      );

      state = codec.decodeState(
        ((await store.readDocument()) as CapabilitySuccess<DocumentSnapshot?>)
            .value!
            .payload,
      );
      snap = DailyCashQueries(state.account).day('2026-01-15');
      jsSummary = fixture['afterEdit']['summary'] as Map;
      expect(snap.remaining, BigInt.from(jsSummary['remaining'] as int));
      expect(snap.transferred, BigInt.from(jsSummary['transferred'] as int));

      // 6. Delete transfer
      fence = await currentFence(store);
      final delCmd = DeleteDailyTransferCommand(
        operationId: 'op-sc4-del',
        accountLineage: initialState.accountLineage,
        expectedFence: fence,
        transferId: 't4',
        expectedActiveJournalId: 'j4-repl1',
        inverseJournalId: 'j4-del-inv',
        reason: 'Delete transfer',
        recordedAt: '2026-01-15T15:00:00.000Z',
      );
      final delRes = await correctionCoord.executeDelete(delCmd);
      expect(
        delRes,
        isA<
          DurableCommandSuccess<RestaurantJournalTransferCorrectionOutcome>
        >(),
      );

      state = codec.decodeState(
        ((await store.readDocument()) as CapabilitySuccess<DocumentSnapshot?>)
            .value!
            .payload,
      );
      snap = DailyCashQueries(state.account).day('2026-01-15');
      jsSummary = fixture['afterDelete']['summary'] as Map;
      expect(snap.remaining, BigInt.from(jsSummary['remaining'] as int));
      expect(snap.transferred, BigInt.from(jsSummary['transferred'] as int));
    });

    test('multi-date isolation: edits and deletes on Date A do not change Date B remaining', () async {
      final store = await openStore();
      final transferCoord = RestaurantJournalTransferCommandCoordinator(
        store: store,
        mapper: mapper,
      );
      final correctionCoord =
          RestaurantJournalTransferCorrectionCommandCoordinator(
            store: store,
            mapper: mapper,
          );

      final dateA = DateOnly.parse(
        '2026-01-15',
        minimumYear: 1000,
        maximumYear: 9999,
      );
      final dateB = DateOnly.parse(
        '2026-01-16',
        minimumYear: 1000,
        maximumYear: 9999,
      );

      final raw = Map<String, Object?>.from(legacyCodec.empty().toJson());
      raw['days'] = {
        dateA.toString(): {
          'expenses': [],
          'chickenUsed': 0,
          'chickenLeft': 0,
          'balance': 100000,
          'totalOverride': null,
          'remaining': {
            'amount': 100000,
            'dailySpent': 0,
            'transferred': 0,
            'salesTotal': 0,
          },
        },
        dateB.toString(): {
          'expenses': [],
          'chickenUsed': 0,
          'chickenLeft': 0,
          'balance': 100000,
          'totalOverride': null,
          'remaining': {
            'amount': 100000,
            'dailySpent': 0,
            'transferred': 0,
            'salesTotal': 0,
          },
        },
      };
      final initialAccount = legacyCodec.decodeJson(raw);
      final initialState = buildSyntheticState(account: initialAccount);
      await store.writeDocument(
        codec.encodeState(initialState),
        writeToken: 'tok-init-iso',
      );

      // Create transfer on A (20k) and transfer on B (30k)
      var fence = await currentFence(store);
      await transferCoord.execute(
        DailyToCashboxTransferCommand(
          operationId: 'op-iso-a1',
          accountLineage: initialState.accountLineage,
          expectedFence: fence,
          transferId: 't-a',
          journalId: 'j-a',
          date: dateA,
          amount: BigInt.from(20000),
          recordedAt: '2026-01-15T10:00:00.000Z',
        ),
      );

      fence = await currentFence(store);
      await transferCoord.execute(
        DailyToCashboxTransferCommand(
          operationId: 'op-iso-b1',
          accountLineage: initialState.accountLineage,
          expectedFence: fence,
          transferId: 't-b',
          journalId: 'j-b',
          date: dateB,
          amount: BigInt.from(30000),
          recordedAt: '2026-01-16T10:00:00.000Z',
        ),
      );

      var state = codec.decodeState(
        ((await store.readDocument()) as CapabilitySuccess<DocumentSnapshot?>)
            .value!
            .payload,
      );
      var snapB = DailyCashQueries(state.account).day(dateB.toString());
      expect(snapB.remaining, BigInt.from(70000));
      expect(snapB.transferred, BigInt.from(30000));

      // Edit transfer on A (20k -> 40k)
      fence = await currentFence(store);
      await correctionCoord.executeEdit(
        EditDailyTransferCommand(
          operationId: 'op-iso-edit-a',
          accountLineage: initialState.accountLineage,
          expectedFence: fence,
          transferId: 't-a',
          expectedActiveJournalId: 'j-a',
          inverseJournalId: 'j-inv-a',
          replacementJournalId: 'j-repl-a',
          newAmount: BigInt.from(40000),
          reason: 'Edit A',
          recordedAt: '2026-01-15T12:00:00.000Z',
        ),
      );

      state = codec.decodeState(
        ((await store.readDocument()) as CapabilitySuccess<DocumentSnapshot?>)
            .value!
            .payload,
      );
      snapB = DailyCashQueries(state.account).day(dateB.toString());
      expect(
        snapB.remaining,
        BigInt.from(70000),
      ); // Date B remains exactly 70k!
      expect(snapB.transferred, BigInt.from(30000));

      // Delete transfer on A
      fence = await currentFence(store);
      await correctionCoord.executeDelete(
        DeleteDailyTransferCommand(
          operationId: 'op-iso-del-a',
          accountLineage: initialState.accountLineage,
          expectedFence: fence,
          transferId: 't-a',
          expectedActiveJournalId: 'j-repl-a',
          inverseJournalId: 'j-del-inv-a',
          reason: 'Delete A',
          recordedAt: '2026-01-15T14:00:00.000Z',
        ),
      );

      state = codec.decodeState(
        ((await store.readDocument()) as CapabilitySuccess<DocumentSnapshot?>)
            .value!
            .payload,
      );
      snapB = DailyCashQueries(state.account).day(dateB.toString());
      expect(
        snapB.remaining,
        BigInt.from(70000),
      ); // Date B still remains exactly 70k!
      expect(snapB.transferred, BigInt.from(30000));
    });

    test('exact boundary: edit of available+oldAmount succeeds, available+oldAmount+1 rejects', () async {
      final store = await openStore();
      final transferCoord = RestaurantJournalTransferCommandCoordinator(
        store: store,
        mapper: mapper,
      );
      final correctionCoord =
          RestaurantJournalTransferCorrectionCommandCoordinator(
            store: store,
            mapper: mapper,
          );

      final raw = Map<String, Object?>.from(legacyCodec.empty().toJson());
      raw['days'] = {
        postDate.toString(): {
          'expenses': [],
          'chickenUsed': 0,
          'chickenLeft': 0,
          'balance': 100000,
          'totalOverride': null,
          'remaining': {
            'amount': 100000,
            'dailySpent': 0,
            'transferred': 0,
            'salesTotal': 0,
          },
        },
      };
      final initialAccount = legacyCodec.decodeJson(raw);
      final initialState = buildSyntheticState(account: initialAccount);
      await store.writeDocument(
        codec.encodeState(initialState),
        writeToken: 'tok-init-bound',
      );

      // Create 20,000 transfer (available remaining becomes 80,000)
      var fence = await currentFence(store);
      await transferCoord.execute(
        DailyToCashboxTransferCommand(
          operationId: 'op-bound-create',
          accountLineage: initialState.accountLineage,
          expectedFence: fence,
          transferId: 't-bound',
          journalId: 'j-bound',
          date: postDate,
          amount: BigInt.from(20000),
          recordedAt: '2026-01-15T10:00:00.000Z',
        ),
      );

      // Max allowed is available (80,000) + old (20,000) = 100,000
      // 1. Attempt 100,001 -> Rejects with excessive_transfer_amount
      fence = await currentFence(store);
      final rejectRes = await correctionCoord.executeEdit(
        EditDailyTransferCommand(
          operationId: 'op-bound-excess',
          accountLineage: initialState.accountLineage,
          expectedFence: fence,
          transferId: 't-bound',
          expectedActiveJournalId: 'j-bound',
          inverseJournalId: 'j-bound-inv-bad',
          replacementJournalId: 'j-bound-repl-bad',
          newAmount: BigInt.from(100001),
          reason: 'Excessive boundary',
          recordedAt: '2026-01-15T11:00:00.000Z',
        ),
      );
      expect(
        rejectRes,
        isA<
          DurableCommandFailure<RestaurantJournalTransferCorrectionOutcome>
        >(),
      );
      expect(
        (rejectRes as DurableCommandFailure).code,
        RestaurantJournalTransferCorrectionErrorCodes.excessiveTransferAmount,
      );

      // 2. Attempt exact 100,000 -> Succeeds!
      final successRes = await correctionCoord.executeEdit(
        EditDailyTransferCommand(
          operationId: 'op-bound-exact',
          accountLineage: initialState.accountLineage,
          expectedFence: fence,
          transferId: 't-bound',
          expectedActiveJournalId: 'j-bound',
          inverseJournalId: 'j-bound-inv-good',
          replacementJournalId: 'j-bound-repl-good',
          newAmount: BigInt.from(100000),
          reason: 'Exact boundary transfer-all',
          recordedAt: '2026-01-15T11:00:00.000Z',
        ),
      );
      expect(
        successRes,
        isA<
          DurableCommandSuccess<RestaurantJournalTransferCorrectionOutcome>
        >(),
      );

      final state = codec.decodeState(
        ((await store.readDocument()) as CapabilitySuccess<DocumentSnapshot?>)
            .value!
            .payload,
      );
      final snap = DailyCashQueries(state.account).day(postDate.toString());
      expect(snap.remaining, BigInt.zero);
      expect(snap.transferred, BigInt.from(100000));
    });
  });
}
