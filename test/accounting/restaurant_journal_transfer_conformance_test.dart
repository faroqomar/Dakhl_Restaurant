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

class UnknownAckStore implements LocalDocumentWorkspaceStore {
  UnknownAckStore(this.inner);
  final LocalDocumentWorkspaceStore inner;
  bool injectUnknownRead = false;
  bool loseNextCommittedWriteAcknowledgement = false;
  int committedWrites = 0;
  int lostAcknowledgements = 0;
  int resolveCalls = 0;

  @override
  Future<CapabilityResult<DocumentSnapshot?>> readDocument() async {
    if (injectUnknownRead) {
      injectUnknownRead = false;
      return const CapabilityFailure(
        DocumentErrorCodes.commitUnknown,
        'Simulated unknown write acknowledgement.',
      );
    }
    return inner.readDocument();
  }

  @override
  Future<CapabilityResult<void>> resolvePendingWrite() async {
    resolveCalls++;
    return inner.resolvePendingWrite();
  }

  @override
  Future<CapabilityResult<DocumentSnapshot>> writeDocument(
    String payload, {
    required String writeToken,
    DocumentSnapshot? expected,
    bool replaceGeneration = false,
  }) async {
    final result = await inner.writeDocument(
      payload,
      writeToken: writeToken,
      expected: expected,
      replaceGeneration: replaceGeneration,
    );
    if (result is CapabilitySuccess<DocumentSnapshot>) {
      committedWrites++;
      if (loseNextCommittedWriteAcknowledgement) {
        loseNextCommittedWriteAcknowledgement = false;
        lostAcknowledgements++;
        return const CapabilityFailure(
          DocumentErrorCodes.commitUnknown,
          'Acknowledgement lost after the real store committed.',
        );
      }
    }
    return result;
  }

  @override
  Future<CapabilityResult<DocumentSnapshot>> resumeInitialCreation(
    String payload, {
    required String writeToken,
  }) => inner.resumeInitialCreation(payload, writeToken: writeToken);

  @override
  Future<CapabilityResult<WorkspaceState>> readWorkspace(StorageFence fence) =>
      inner.readWorkspace(fence);

  @override
  Future<CapabilityResult<WorkspaceSnapshot>> writeWorkspace(
    String payload, {
    required StorageFence fence,
    required int? expectedRevision,
    required String writeToken,
  }) => inner.writeWorkspace(
    payload,
    fence: fence,
    expectedRevision: expectedRevision,
    writeToken: writeToken,
  );

  @override
  Future<CapabilityResult<PreviousDocument?>> readPrevious() =>
      inner.readPrevious();

  @override
  Future<CapabilityResult<String>> preserveSource(List<int> bytes) =>
      inner.preserveSource(bytes);

  @override
  Future<CapabilityResult<DocumentSnapshot>> recoverPrevious(
    PreviousDocument previous, {
    required String payload,
    required String writeToken,
  }) =>
      inner.recoverPrevious(previous, payload: payload, writeToken: writeToken);

  @override
  Future<void> close() => inner.close();
}

void main() {
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
    };
    raw['transfers'] = transfers;
    return legacyCodec.decodeJson(raw);
  }

  PortableJournalState buildSyntheticState({
    required AccountDocument account,
    String accountLineage = 'test-xfer-lineage-1',
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

  group('Restaurant Journal Transfer Real Store Conformance', () {
    late Directory tempDir;
    final openStores = <PowerSyncLocalDocumentWorkspaceStore>[];

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp(
        'dakhl-transfer-conformance-store-',
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

    test(
      'custom mapper profile commits and replays its expected accounts',
      () async {
        final store = await openStore();
        await store.writeDocument(
          codec.encodeState(buildSyntheticState(account: buildSampleAccount())),
          writeToken: 'seed-custom-profile',
        );
        final custom = RestaurantJournalMapper(
          profile: const RestaurantAccountProfile(
            dailyCashAccountId: 'asset:cash:custom_daily',
            cashboxAccountId: 'asset:cash:custom_safe',
          ),
        );
        final host = RestaurantJournalTransferCommandCoordinator(
          store: store,
          mapper: custom,
        );
        final command = DailyToCashboxTransferCommand(
          operationId: 'custom-profile',
          accountLineage: 'test-xfer-lineage-1',
          expectedFence: await currentFence(store),
          transferId: 'custom-transfer',
          journalId: 'custom-journal',
          date: postDate,
          amount: BigInt.from(12000),
          recordedAt: '2026-01-15T12:00:00.000Z',
        );
        expect(
          await host.execute(command),
          isA<DurableCommandSuccess<RestaurantJournalTransferOutcome>>(),
        );
        expect(
          await host.execute(command),
          isA<DurableCommandReplayed<RestaurantJournalTransferOutcome>>(),
        );
        final snapshot =
            (await store.readDocument() as CapabilitySuccess<DocumentSnapshot?>)
                .value!;
        final entry = codec.decodeState(snapshot.payload).journals.last;
        expect(entry.journal.lines.map((line) => line.accountId), [
          'asset:cash:custom_safe',
          'asset:cash:custom_daily',
        ]);
        expect(snapshot.revision, 2);
      },
    );

    for (final changedField in ['date', 'sourceVersion', 'maximumLines']) {
      test(
        'replay rejects tampered transfer $changedField without writes',
        () async {
          final store = await openStore();
          await store.writeDocument(
            codec.encodeState(
              buildSyntheticState(account: buildSampleAccount()),
            ),
            writeToken: 'seed-tamper-$changedField',
          );
          final host = RestaurantJournalTransferCommandCoordinator(
            store: store,
          );
          final command = DailyToCashboxTransferCommand(
            operationId: 'tamper-$changedField',
            accountLineage: 'test-xfer-lineage-1',
            expectedFence: await currentFence(store),
            transferId: 'transfer-$changedField',
            journalId: 'journal-$changedField',
            date: postDate,
            amount: BigInt.from(12000),
            recordedAt: '2026-01-15T12:00:00.000Z',
          );
          expect(
            await host.execute(command),
            isA<DurableCommandSuccess<RestaurantJournalTransferOutcome>>(),
          );
          final before =
              (await store.readDocument()
                      as CapabilitySuccess<DocumentSnapshot?>)
                  .value!;
          final raw = jsonDecode(before.payload) as Map<String, dynamic>;
          final journal =
              (raw['journals'] as List).last as Map<String, dynamic>;
          if (changedField == 'maximumLines') {
            (journal['policy'] as Map)['maximumLines'] = 2;
          } else {
            final value = changedField == 'date' ? '2099-12-31' : '9';
            (journal['metadata'] as Map)[changedField] = value;
            final receipt =
                (raw['receipts'] as List).single as Map<String, dynamic>;
            final outcome = jsonDecode(
              receipt['outcomePayload'] as String,
            ) as Map<String, dynamic>;
            (outcome['metadata'] as Map)[changedField] = value;
            receipt['outcomePayload'] = jsonEncode(outcome);
          }
          final payload = codec.encodeState(codec.decodeState(jsonEncode(raw)));
          final written = await store.writeDocument(
            payload,
            expected: before,
            writeToken: 'tampered-$changedField',
          );
          expect(written, isA<CapabilitySuccess<DocumentSnapshot>>());
          final tampered =
              (written as CapabilitySuccess<DocumentSnapshot>).value;
          final result = await host.execute(command);
          expect(
            result,
            isA<DurableCommandFailure<RestaurantJournalTransferOutcome>>(),
          );
          expect(
            (result as DurableCommandFailure).code,
            DurableCommandErrorCodes.corruptState,
          );
          final after =
              (await store.readDocument()
                      as CapabilitySuccess<DocumentSnapshot?>)
                  .value!;
          expect(after.payload, tampered.payload);
          expect(after.revision, tampered.revision);
          expect(after.fence, tampered.fence);
        },
      );
    }

    test('atomic persistence of transfer updates source, 1 journal, and 1 receipt in 1 revision increment', () async {
      final store = await openStore();
      final coordinator = RestaurantJournalTransferCommandCoordinator(
        store: store,
        mapper: mapper,
        codec: codec,
      );

      final initialDoc = buildSampleAccount();
      final initialState = buildSyntheticState(account: initialDoc);

      await store.writeDocument(
        codec.encodeState(initialState),
        writeToken: 'seed-token-1',
      );

      final fence = await currentFence(store);
      final cmd = DailyToCashboxTransferCommand(
        operationId: 'cmd-xfer-1',
        accountLineage: 'test-xfer-lineage-1',
        expectedFence: fence,
        transferId: 't-conf-1',
        journalId: 'j-conf-1',
        date: postDate,
        amount: BigInt.from(20000),
        recordedAt: '2026-01-15T12:00:00.000Z',
      );

      final result = await coordinator.execute(cmd);
      expect(
        result,
        isA<DurableCommandSuccess<RestaurantJournalTransferOutcome>>(),
      );
      final success =
          result as DurableCommandSuccess<RestaurantJournalTransferOutcome>;

      expect(success.outcome.commandType, 'daily_to_cashbox_transfer');
      expect(success.outcome.netAmount, '20000');
      expect(success.snapshot.revision, 2);

      // Verify stored state in real store
      final readRes = await store.readDocument();
      expect(readRes, isA<CapabilitySuccess<DocumentSnapshot?>>());
      final snap = (readRes as CapabilitySuccess<DocumentSnapshot?>).value!;
      expect(snap.revision, 2);

      final state = codec.decodeState(snap.payload);
      expect(state.receipts, hasLength(1));
      expect(state.receipts.single.identity.operationId, 'cmd-xfer-1');
      expect(state.receipts.single.status, DurableCommandStatus.committed);

      // Verify source transfer
      final transfers = (state.account.toJson()['transfers'] as List)
          .cast<Map<String, Object?>>();
      expect(transfers, hasLength(1));
      expect(transfers.single['id'], 't-conf-1');
      expect(transfers.single['amount'], 20000);

      // Verify journal entry
      final transferJournals = state.journals
          .where((j) => j.journal.id == 'j-conf-1')
          .toList();
      expect(transferJournals, hasLength(1));
      final journal = transferJournals.single.journal;
      expect(journal.totalUnits, BigInt.from(20000));
      expect(journal.lines, hasLength(2));

      // Verify DailyCashQueries
      final queries = DailyCashQueries(state.account);
      final daySnap = queries.day(postDate.toString());
      expect(daySnap.transferred, BigInt.from(20000));
      expect(daySnap.remaining, BigInt.from(80000));
      expect(daySnap.recordedBalance, BigInt.from(100000));
    });

    test('real store close and reopen preserves complete state, journals, and receipts', () async {
      final store = await openStore();
      final coordinator = RestaurantJournalTransferCommandCoordinator(
        store: store,
        mapper: mapper,
        codec: codec,
      );

      final initialDoc = buildSampleAccount();
      final initialState = buildSyntheticState(account: initialDoc);

      await store.writeDocument(
        codec.encodeState(initialState),
        writeToken: 'seed-token-reopen',
      );

      final fence = await currentFence(store);
      final cmd = DailyToCashboxTransferCommand(
        operationId: 'cmd-xfer-reopen',
        accountLineage: 'test-xfer-lineage-1',
        expectedFence: fence,
        transferId: 't-reopen-1',
        journalId: 'j-reopen-1',
        date: postDate,
        amount: BigInt.from(25000),
        recordedAt: '2026-01-15T12:00:00.000Z',
      );

      final result = await coordinator.execute(cmd);
      expect(
        result,
        isA<DurableCommandSuccess<RestaurantJournalTransferOutcome>>(),
      );

      // Close the store
      await store.close();
      openStores.remove(store);

      // Reopen from same disk directory
      final reopenedStore = await openStore();
      final reopenedRead = await reopenedStore.readDocument();
      expect(reopenedRead, isA<CapabilitySuccess<DocumentSnapshot?>>());
      final snap =
          (reopenedRead as CapabilitySuccess<DocumentSnapshot?>).value!;
      expect(snap.revision, 2);

      final reopenedState = codec.decodeState(snap.payload);
      expect(reopenedState.receipts, hasLength(1));
      expect(
        reopenedState.receipts.single.identity.operationId,
        'cmd-xfer-reopen',
      );

      // Replay against reopened store works seamlessly
      final reopenedCoordinator = RestaurantJournalTransferCommandCoordinator(
        store: reopenedStore,
        mapper: mapper,
        codec: codec,
      );

      final replayRes = await reopenedCoordinator.execute(cmd);
      expect(
        replayRes,
        isA<DurableCommandReplayed<RestaurantJournalTransferOutcome>>(),
      );
      final replayed =
          replayRes as DurableCommandReplayed<RestaurantJournalTransferOutcome>;
      expect(replayed.snapshot.revision, 2);
      expect(replayed.outcome!.netAmount, '25000');
    });

    test('idempotent replay returns DurableCommandReplayed without incrementing store revision', () async {
      final store = await openStore();
      final coordinator = RestaurantJournalTransferCommandCoordinator(
        store: store,
        mapper: mapper,
        codec: codec,
      );

      final initialDoc = buildSampleAccount();
      final initialState = buildSyntheticState(account: initialDoc);

      await store.writeDocument(
        codec.encodeState(initialState),
        writeToken: 'seed-token-replay',
      );

      final fence = await currentFence(store);
      final cmd = DailyToCashboxTransferCommand(
        operationId: 'cmd-xfer-replay',
        accountLineage: 'test-xfer-lineage-1',
        expectedFence: fence,
        transferId: 't-replay-1',
        journalId: 'j-replay-1',
        date: postDate,
        amount: BigInt.from(15000),
        recordedAt: '2026-01-15T12:00:00.000Z',
      );

      final firstRes = await coordinator.execute(cmd);
      expect(
        firstRes,
        isA<DurableCommandSuccess<RestaurantJournalTransferOutcome>>(),
      );

      // Second execution: replay!
      final replayRes = await coordinator.execute(cmd);
      expect(
        replayRes,
        isA<DurableCommandReplayed<RestaurantJournalTransferOutcome>>(),
      );
      final replayed =
          replayRes as DurableCommandReplayed<RestaurantJournalTransferOutcome>;

      expect(replayed.outcome, isNotNull);
      expect(replayed.outcome!.netAmount, '15000');
      expect(replayed.outcome!.operationId, 'cmd-xfer-replay');
      expect(replayed.snapshot.revision, 2); // Still 2!

      final readRes = await store.readDocument();
      final currentSnap =
          (readRes as CapabilitySuccess<DocumentSnapshot?>).value!;
      expect(currentSnap.revision, 2); // Not incremented!
    });

    test('tampered command with changed financial amount on replay rejects with changed_payload_rejected', () async {
      final store = await openStore();
      final coordinator = RestaurantJournalTransferCommandCoordinator(
        store: store,
        mapper: mapper,
        codec: codec,
      );

      final initialDoc = buildSampleAccount();
      final initialState = buildSyntheticState(account: initialDoc);

      await store.writeDocument(
        codec.encodeState(initialState),
        writeToken: 'seed-token-tamper',
      );

      final fence = await currentFence(store);
      final cmd = DailyToCashboxTransferCommand(
        operationId: 'cmd-xfer-tamper',
        accountLineage: 'test-xfer-lineage-1',
        expectedFence: fence,
        transferId: 't-tamper-1',
        journalId: 'j-tamper-1',
        date: postDate,
        amount: BigInt.from(15000),
        recordedAt: '2026-01-15T12:00:00.000Z',
      );

      final firstRes = await coordinator.execute(cmd);
      expect(
        firstRes,
        isA<DurableCommandSuccess<RestaurantJournalTransferOutcome>>(),
      );

      // Attempt replay with changed amount under SAME operationId
      final tamperedCmd = DailyToCashboxTransferCommand(
        operationId: 'cmd-xfer-tamper',
        accountLineage: 'test-xfer-lineage-1',
        expectedFence: fence,
        transferId: 't-tamper-1',
        journalId: 'j-tamper-1',
        date: postDate,
        amount: BigInt.from(18000), // Changed amount!
        recordedAt: '2026-01-15T12:00:00.000Z',
      );

      final replayRes = await coordinator.execute(tamperedCmd);
      expect(
        replayRes,
        isA<DurableCommandFailure<RestaurantJournalTransferOutcome>>(),
      );
      final failure =
          replayRes as DurableCommandFailure<RestaurantJournalTransferOutcome>;
      expect(failure.code, DurableCommandErrorCodes.changedPayloadRejected);

      // Verify store revision unchanged
      final readRes = await store.readDocument();
      final snap = (readRes as CapabilitySuccess<DocumentSnapshot?>).value!;
      expect(snap.revision, 2);
    });

    test('replaying with changed payload version rejects with changed_payload_rejected', () async {
      final store = await openStore();
      final coordinator = RestaurantJournalTransferCommandCoordinator(
        store: store,
        mapper: mapper,
        codec: codec,
      );

      final initialDoc = buildSampleAccount();
      final initialState = buildSyntheticState(account: initialDoc);

      await store.writeDocument(
        codec.encodeState(initialState),
        writeToken: 'seed-token-ver',
      );

      final fence = await currentFence(store);
      final cmd = DailyToCashboxTransferCommand(
        operationId: 'cmd-xfer-ver',
        payloadVersion: 1,
        accountLineage: 'test-xfer-lineage-1',
        expectedFence: fence,
        transferId: 't-ver-1',
        journalId: 'j-ver-1',
        date: postDate,
        amount: BigInt.from(10000),
        recordedAt: '2026-01-15T12:00:00.000Z',
      );

      await coordinator.execute(cmd);

      // Replay with version = 2
      final cmdV2 = DailyToCashboxTransferCommand(
        operationId: 'cmd-xfer-ver',
        payloadVersion: 2,
        accountLineage: 'test-xfer-lineage-1',
        expectedFence: fence,
        transferId: 't-ver-1',
        journalId: 'j-ver-1',
        date: postDate,
        amount: BigInt.from(10000),
        recordedAt: '2026-01-15T12:00:00.000Z',
      );

      final replayRes = await coordinator.execute(cmdV2);
      expect(
        replayRes,
        isA<DurableCommandFailure<RestaurantJournalTransferOutcome>>(),
      );
      final failure =
          replayRes as DurableCommandFailure<RestaurantJournalTransferOutcome>;
      expect(failure.code, DurableCommandErrorCodes.changedPayloadRejected);
    });

    test('account lineage mismatch is checked before replay and rejects without executing', () async {
      final store = await openStore();
      final coordinator = RestaurantJournalTransferCommandCoordinator(
        store: store,
        mapper: mapper,
        codec: codec,
      );

      final initialDoc = buildSampleAccount();
      final initialState = buildSyntheticState(
        account: initialDoc,
        accountLineage: 'lineage-store-real',
      );

      await store.writeDocument(
        codec.encodeState(initialState),
        writeToken: 'seed-token-lin',
      );

      final fence = await currentFence(store);
      final cmd = DailyToCashboxTransferCommand(
        operationId: 'cmd-xfer-lin',
        accountLineage: 'wrong-lineage-submitted',
        expectedFence: fence,
        transferId: 't-lin-1',
        journalId: 'j-lin-1',
        date: postDate,
        amount: BigInt.from(10000),
        recordedAt: '2026-01-15T12:00:00.000Z',
      );

      final result = await coordinator.execute(cmd);
      expect(
        result,
        isA<DurableCommandFailure<RestaurantJournalTransferOutcome>>(),
      );
      final failure =
          result as DurableCommandFailure<RestaurantJournalTransferOutcome>;
      expect(
        failure.code,
        RestaurantJournalTransferErrorCodes.accountLineageMismatch,
      );

      // Zero writes
      final readRes = await store.readDocument();
      final snap = (readRes as CapabilitySuccess<DocumentSnapshot?>).value!;
      expect(snap.revision, 1);
    });

    test(
      'stale expected storage fence rejects command with stale_authority_fence',
      () async {
        final store = await openStore();
        final coordinator = RestaurantJournalTransferCommandCoordinator(
          store: store,
          mapper: mapper,
          codec: codec,
        );

        final initialDoc = buildSampleAccount();
        final initialState = buildSyntheticState(account: initialDoc);

        await store.writeDocument(
          codec.encodeState(initialState),
          writeToken: 'seed-token-fence',
        );

        // Submit with stale generation
        const staleFence = StorageFence(
          storeId: 'dakhl-store',
          generation: 'stale-gen',
        );
        final cmd = DailyToCashboxTransferCommand(
          operationId: 'cmd-xfer-stale',
          accountLineage: 'test-xfer-lineage-1',
          expectedFence: staleFence,
          transferId: 't-stale-1',
          journalId: 'j-stale-1',
          date: postDate,
          amount: BigInt.from(10000),
          recordedAt: '2026-01-15T12:00:00.000Z',
        );

        final result = await coordinator.execute(cmd);
        expect(
          result,
          isA<DurableCommandFailure<RestaurantJournalTransferOutcome>>(),
        );
        final failure =
            result as DurableCommandFailure<RestaurantJournalTransferOutcome>;
        expect(failure.code, DurableCommandErrorCodes.staleAuthorityFence);
      },
    );

    test(
      'rejection paths leave store revision and payload completely unchanged',
      () async {
        final store = await openStore();
        final coordinator = RestaurantJournalTransferCommandCoordinator(
          store: store,
          mapper: mapper,
          codec: codec,
        );

        final initialDoc = buildSampleAccount(
          remainingSnapshot: {
            'amount': 50000,
            'dailySpent': 0,
            'transferred': 0,
            'salesTotal': 0,
          },
        );
        final initialState = buildSyntheticState(account: initialDoc);
        final seedPayload = codec.encodeState(initialState);

        await store.writeDocument(seedPayload, writeToken: 'seed-token-reject');
        final fence = await currentFence(store);

        // Attempt transfer exceeding available remaining (attempt 60k from 50k)
        final excessiveCmd = DailyToCashboxTransferCommand(
          operationId: 'cmd-excessive',
          accountLineage: 'test-xfer-lineage-1',
          expectedFence: fence,
          transferId: 't-exc-1',
          journalId: 'j-exc-1',
          date: postDate,
          amount: BigInt.from(60000),
          recordedAt: '2026-01-15T12:00:00.000Z',
        );

        final result = await coordinator.execute(excessiveCmd);
        expect(
          result,
          isA<DurableCommandFailure<RestaurantJournalTransferOutcome>>(),
        );
        final failure =
            result as DurableCommandFailure<RestaurantJournalTransferOutcome>;
        expect(
          failure.code,
          RestaurantJournalTransferErrorCodes.excessiveTransferAmount,
        );

        final readRes = await store.readDocument();
        final afterSnap =
            (readRes as CapabilitySuccess<DocumentSnapshot?>).value!;
        expect(afterSnap.revision, 1);
        expect(afterSnap.payload, seedPayload);
      },
    );

    test(
      'pending-read uncertainty resolves before the command commits',
      () async {
        final realStore = await openStore();
        final unknownStore = UnknownAckStore(realStore);
        final coordinator = RestaurantJournalTransferCommandCoordinator(
          store: unknownStore,
          mapper: mapper,
          codec: codec,
        );

        final initialDoc = buildSampleAccount();
        final initialV12 = buildSyntheticState(
          account: initialDoc,
          accountLineage: 'ack-xfer-lineage',
        );

        await unknownStore.writeDocument(
          codec.encodeState(initialV12),
          writeToken: 'seed-token-ack',
        );

        // Inject unknown on initial read
        unknownStore.injectUnknownRead = true;

        final transferCmd = DailyToCashboxTransferCommand(
          expectedFence: await currentFence(realStore),
          operationId: 'cmd-ack-xfer',
          accountLineage: 'ack-xfer-lineage',
          transferId: 't-ack-1',
          journalId: 'j-ack-1',
          date: postDate,
          amount: BigInt.from(12000),
          recordedAt: '2026-01-15T12:00:00.000Z',
        );

        final result = await coordinator.execute(transferCmd);
        expect(
          result,
          isA<DurableCommandSuccess<RestaurantJournalTransferOutcome>>(),
        );
        expect(unknownStore.resolveCalls, greaterThanOrEqualTo(1));

        final readRes = await realStore.readDocument();
        final snap = (readRes as CapabilitySuccess<DocumentSnapshot?>).value!;
        expect(snap.revision, 2);
        final state = codec.decodeState(snap.payload);
        expect(state.receipts.length, 1);
        expect(state.receipts.first.identity.operationId, 'cmd-ack-xfer');
      },
    );

    test('lost committed write acknowledgement resolves and reopens with one transfer', () async {
      final realStore = await openStore();
      final wrapper = UnknownAckStore(realStore);
      final host = RestaurantJournalTransferCommandCoordinator(store: wrapper);
      await realStore.writeDocument(
        codec.encodeState(buildSyntheticState(account: buildSampleAccount())),
        writeToken: 'seed-lost-commit-ack',
      );
      final command = DailyToCashboxTransferCommand(
        operationId: 'lost-commit-ack',
        accountLineage: 'test-xfer-lineage-1',
        expectedFence: await currentFence(realStore),
        transferId: 'ack-transfer',
        journalId: 'ack-journal',
        date: postDate,
        amount: BigInt.from(12000),
        recordedAt: '2026-01-15T12:00:00.000Z',
      );
      wrapper.loseNextCommittedWriteAcknowledgement = true;
      final result = await host.execute(command);
      expect(
        result,
        isA<DurableCommandReplayed<RestaurantJournalTransferOutcome>>(),
      );
      expect(wrapper.committedWrites, 1);
      expect(wrapper.lostAcknowledgements, 1);
      expect(wrapper.resolveCalls, greaterThanOrEqualTo(1));
      await realStore.close();
      final reopened = await openStore();
      final before =
          (await reopened.readDocument()
                  as CapabilitySuccess<DocumentSnapshot?>)
              .value!;
      final state = codec.decodeState(before.payload);
      expect(before.revision, 2);
      expect((state.account.toJson()['transfers'] as List).single, {
        'id': 'ack-transfer',
        'date': '2026-01-15',
        'amount': 12000,
        'createdAt': '2026-01-15T12:00:00.000Z',
      });
      expect(
        state.journals.where((j) => j.sourceRecordId == 'ack-transfer').length,
        1,
      );
      expect(state.receipts.length, 1);
      final replay = await RestaurantJournalTransferCommandCoordinator(
        store: reopened,
      ).execute(command);
      expect(
        replay,
        isA<DurableCommandReplayed<RestaurantJournalTransferOutcome>>(),
      );
      final after =
          (await reopened.readDocument()
                  as CapabilitySuccess<DocumentSnapshot?>)
              .value!;
      expect(after.payload, before.payload);
      expect(after.revision, before.revision);
      expect(
        DailyCashQueries(state.account).day('2026-01-15').remaining,
        BigInt.from(88000),
      );
    });

    test('mixed history: transfer -> sale -> expense -> return -> transfer2 preserves all invariants and replaying first transfer succeeds', () async {
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

      // Initial account with 1 tracked product and 100k remaining snapshot
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
      final initialState = buildSyntheticState(account: initialDoc);

      await store.writeDocument(
        codec.encodeState(initialState),
        writeToken: 'seed-token-mixed',
      );

      // Step 1: Initial transfer of 20,000 IQD
      final fence1 = await currentFence(store);
      final transferCmd1 = DailyToCashboxTransferCommand(
        operationId: 'mix-xfer-1',
        accountLineage: 'test-xfer-lineage-1',
        expectedFence: fence1,
        transferId: 't-mix-1',
        journalId: 'j-mix-1',
        date: postDate,
        amount: BigInt.from(20000),
        recordedAt: '2026-01-15T11:00:00.000Z',
      );
      final res1 = await transferCoordinator.execute(transferCmd1);
      expect(
        res1,
        isA<DurableCommandSuccess<RestaurantJournalTransferOutcome>>(),
      );

      // Step 2: Subsequent completed sale (1 plate kebab = 10,000 IQD)
      final fence2 = await currentFence(store);
      final saleCmd = CompleteSaleCommand(
        operationId: 'mix-sale-1',
        accountLineage: 'test-xfer-lineage-1',
        expectedFence: fence2,
        saleId: 'sale-mix-1',
        journalId: 'j-sale-mix-1',
        draft: {
          'date': '2026-01-15',
          'lines': [
            {'productId': 'prod-1', 'quantity': 1},
          ],
          'discount': 0,
          'orderType': 'صالة',
        },
        recordedAt: '2026-01-15T12:00:00.000Z',
      );
      final res2 = await salesCoordinator.execute(saleCmd);
      expect(res2, isA<DurableCommandSuccess<RestaurantJournalSaleOutcome>>());

      // Step 3: Subsequent operating daily expense (5,000 IQD)
      final fence3 = await currentFence(store);
      final expenseCmd = CreateOperatingExpenseCommand(
        operationId: 'mix-exp-1',
        accountLineage: 'test-xfer-lineage-1',
        expectedFence: fence3,
        expenseId: 'exp-mix-2',
        journalId: 'j-exp-mix-2',
        date: postDate,
        categoryId: 'samoon',
        amount: BigInt.from(5000),
        fundingSource: FundingSource.daily,
        dailyAmount: BigInt.from(5000),
        cashAmount: BigInt.zero,
        note: 'Fresh herbs',
        recordedAt: '2026-01-15T13:00:00.000Z',
      );
      final res3 = await spendingCoordinator.execute(expenseCmd);
      expect(
        res3,
        isA<DurableCommandSuccess<RestaurantJournalSpendingOutcome>>(),
      );

      // Step 4: Subsequent customer refund (return the sale of 10,000 IQD)
      final fence4 = await currentFence(store);
      final returnCmd = SaleReturnCommand(
        operationId: 'mix-ret-1',
        accountLineage: 'test-xfer-lineage-1',
        expectedFence: fence4,
        returnId: 'ret-mix-1',
        saleId: 'sale-mix-1',
        journalId: 'j-ret-mix-1',
        returnDate: postDate,
        reason: 'Customer cancelled order',
        recordedAt: '2026-01-15T14:00:00.000Z',
        today: postDate,
        lines: [
          ReturnLineRequest(
            productId: 'prod-1',
            quantityUnits: BigInt.from(1000),
            restock: false,
          ),
        ],
      );
      final res4 = await salesCoordinator.execute(returnCmd);
      expect(res4, isA<DurableCommandSuccess<RestaurantJournalSaleOutcome>>());

      // Step 5: Second transfer of 15,000 IQD
      final fence5 = await currentFence(store);
      final transferCmd2 = DailyToCashboxTransferCommand(
        operationId: 'mix-xfer-2',
        accountLineage: 'test-xfer-lineage-1',
        expectedFence: fence5,
        transferId: 't-mix-2',
        journalId: 'j-mix-2',
        date: postDate,
        amount: BigInt.from(15000),
        recordedAt: '2026-01-15T15:00:00.000Z',
      );
      final res5 = await transferCoordinator.execute(transferCmd2);
      expect(
        res5,
        isA<DurableCommandSuccess<RestaurantJournalTransferOutcome>>(),
      );

      // Read final state from store
      final readRes = await store.readDocument();
      final snap = (readRes as CapabilitySuccess<DocumentSnapshot?>).value!;
      expect(snap.revision, 6); // initial 1 + 5 commands = 6

      final state = codec.decodeState(snap.payload);
      expect(state.receipts, hasLength(5));

      // Verify mathematical invariants with DailyCashQueries
      final queries = DailyCashQueries(state.account);
      final daySnap = queries.day(postDate.toString());

      // dailySpent: 20,000 (initial) + 5,000 (expense2) = 25,000
      expect(daySnap.dailySpent, BigInt.from(25000));

      // transferred: 20,000 (transfer1) + 15,000 (transfer2) = 35,000
      expect(daySnap.transferred, BigInt.from(35000));

      // netSales: 10,000 (sale) - 10,000 (return) = 0
      expect(daySnap.netSales, BigInt.zero);

      // remaining: 100,000 - (25k-20k) - (35k-0) + (0-0) = 100,000 - 5k - 35k = 60,000 IQD
      expect(daySnap.remaining, BigInt.from(60000));

      // recordedBalance: 100,000 (preserved)
      expect(daySnap.recordedBalance, BigInt.from(100000));

      // Cash movements: cashbox deposits = 20k + 15k = 35k
      final transferMoves = queries.cashMovements
          .where((m) => m['kind'] == 'transfer')
          .toList();
      expect(transferMoves, hasLength(2));
      final totalCashboxTransferred = transferMoves.fold<int>(
        0,
        (sum, m) => sum + (m['amount'] as int),
      );
      expect(totalCashboxTransferred, 35000);

      // Step 6: REPLAY the FIRST transfer against this evolved multi-command store!
      // Must succeed cleanly with DurableCommandReplayed and revision remains 6!
      final replayRes1 = await transferCoordinator.execute(transferCmd1);
      expect(
        replayRes1,
        isA<DurableCommandReplayed<RestaurantJournalTransferOutcome>>(),
      );
      final replayed1 =
          replayRes1
              as DurableCommandReplayed<RestaurantJournalTransferOutcome>;
      expect(replayed1.outcome!.transferId, 't-mix-1');
      expect(replayed1.outcome!.netAmount, '20000');
      expect(replayed1.snapshot.revision, 6);
    });
  });
}
