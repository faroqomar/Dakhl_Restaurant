import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:madar_application/madar_application.dart';
import 'package:madar_data/madar_data.dart';
import 'package:madar_domain/madar_domain.dart';
import 'package:dakhl_restaurant/accounting/daily_cash_queries.dart';
import 'package:dakhl_restaurant/accounting/restaurant_journal_mapper.dart';
import 'package:dakhl_restaurant/accounting/restaurant_journal_transfer_commands.dart';
import 'package:dakhl_restaurant/accounting/restaurant_journal_transfer_correction_commands.dart';
import 'package:dakhl_restaurant/accounts/account_document.dart';
import 'package:dakhl_restaurant/accounts/legacy_account_codec.dart';
import 'package:dakhl_restaurant/accounts/portable_journal_codec.dart';
import 'package:dakhl_restaurant/accounts/portable_journal_state.dart';

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
        'Simulated unknown read acknowledgement.',
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
    String accountLineage = 'test-corr-lineage-1',
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

  group('Restaurant Journal Transfer Correction Real Store Conformance', () {
    late Directory tempDir;
    final openStores = <PowerSyncLocalDocumentWorkspaceStore>[];

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp(
        'dakhl-transfer-corr-conformance-store-',
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
        final custom = RestaurantJournalMapper(
          profile: const RestaurantAccountProfile(
            dailyCashAccountId: 'asset:cash:custom_daily',
            cashboxAccountId: 'asset:cash:custom_safe',
          ),
        );
        final transferCoord = RestaurantJournalTransferCommandCoordinator(
          store: store,
          mapper: custom,
        );
        final corrCoord = RestaurantJournalTransferCorrectionCommandCoordinator(
          store: store,
          mapper: custom,
        );

        await store.writeDocument(
          codec.encodeState(buildSyntheticState(account: buildSampleAccount())),
          writeToken: 'seed-custom-profile',
        );

        // Create initial transfer
        var fence = await currentFence(store);
        final createCmd = DailyToCashboxTransferCommand(
          operationId: 'op-custom-create',
          accountLineage: 'test-corr-lineage-1',
          expectedFence: fence,
          transferId: 't-custom',
          journalId: 'j-custom',
          date: postDate,
          amount: BigInt.from(20000),
          recordedAt: '2026-01-15T10:00:00.000Z',
        );
        await transferCoord.execute(createCmd);

        // Edit transfer with custom profile
        fence = await currentFence(store);
        final editCmd = EditDailyTransferCommand(
          operationId: 'op-custom-edit',
          accountLineage: 'test-corr-lineage-1',
          expectedFence: fence,
          transferId: 't-custom',
          expectedActiveJournalId: 'j-custom',
          inverseJournalId: 'j-custom-inv',
          replacementJournalId: 'j-custom-repl',
          newAmount: BigInt.from(35000),
          reason: 'Custom profile edit to 35k',
          recordedAt: '2026-01-15T11:00:00.000Z',
        );

        final editRes = await corrCoord.executeEdit(editCmd);
        expect(
          editRes,
          isA<
            DurableCommandSuccess<RestaurantJournalTransferCorrectionOutcome>
          >(),
        );

        // Replay returns DurableCommandReplayed
        final replayRes = await corrCoord.executeEdit(editCmd);
        expect(
          replayRes,
          isA<
            DurableCommandReplayed<RestaurantJournalTransferCorrectionOutcome>
          >(),
        );

        // Verify custom account IDs on inverse and replacement entries
        final snap =
            ((await store.readDocument())
                    as CapabilitySuccess<DocumentSnapshot?>)
                .value!;
        final state = codec.decodeState(snap.payload);
        final invEntry = state.journals.firstWhere(
          (j) => j.journal.id == 'j-custom-inv',
        );
        final replEntry = state.journals.firstWhere(
          (j) => j.journal.id == 'j-custom-repl',
        );

        expect(invEntry.journal.lines.map((l) => l.accountId), [
          'asset:cash:custom_safe',
          'asset:cash:custom_daily',
        ]);
        expect(invEntry.journal.lines[0].side, JournalSide.credit);
        expect(invEntry.journal.lines[1].side, JournalSide.debit);
        expect(replEntry.journal.lines.map((l) => l.accountId), [
          'asset:cash:custom_safe',
          'asset:cash:custom_daily',
        ]);
        expect(replEntry.journal.lines[0].side, JournalSide.debit);
        expect(replEntry.journal.lines[1].side, JournalSide.credit);
      },
    );

    test('atomic persistence of edit updates source, 2 journals, and 1 receipt in 1 revision increment', () async {
      final store = await openStore();
      final transferCoord = RestaurantJournalTransferCommandCoordinator(
        store: store,
        mapper: mapper,
      );
      final corrCoord = RestaurantJournalTransferCorrectionCommandCoordinator(
        store: store,
        mapper: mapper,
      );

      await store.writeDocument(
        codec.encodeState(buildSyntheticState(account: buildSampleAccount())),
        writeToken: 'seed-edit-atomicity',
      );

      var fence = await currentFence(store);
      await transferCoord.execute(
        DailyToCashboxTransferCommand(
          operationId: 'op-atom-create',
          accountLineage: 'test-corr-lineage-1',
          expectedFence: fence,
          transferId: 't-atom',
          journalId: 'j-atom-0',
          date: postDate,
          amount: BigInt.from(20000),
          recordedAt: '2026-01-15T10:00:00.000Z',
        ),
      );

      // Store is at revision 2 after create
      final afterCreateSnap =
          ((await store.readDocument()) as CapabilitySuccess<DocumentSnapshot?>)
              .value!;
      expect(afterCreateSnap.revision, 2);

      // Execute edit
      fence = await currentFence(store);
      final editCmd = EditDailyTransferCommand(
        operationId: 'op-atom-edit',
        accountLineage: 'test-corr-lineage-1',
        expectedFence: fence,
        transferId: 't-atom',
        expectedActiveJournalId: 'j-atom-0',
        inverseJournalId: 'j-atom-inv',
        replacementJournalId: 'j-atom-repl',
        newAmount: BigInt.from(30000),
        reason: 'Atomic edit to 30k',
        recordedAt: '2026-01-15T11:00:00.000Z',
      );

      final editRes = await corrCoord.executeEdit(editCmd);
      expect(
        editRes,
        isA<
          DurableCommandSuccess<RestaurantJournalTransferCorrectionOutcome>
        >(),
      );

      // Exactly 1 revision increment (revision 3)
      final afterEditSnap =
          ((await store.readDocument()) as CapabilitySuccess<DocumentSnapshot?>)
              .value!;
      expect(afterEditSnap.revision, 3);

      final state = codec.decodeState(afterEditSnap.payload);
      // Source transfer updated to 30,000
      final transfers = (state.account.toJson()['transfers'] as List)
          .cast<Map<String, Object?>>();
      expect(transfers, hasLength(1));
      expect(transfers.single['amount'], 30000);

      // Journals contain original + inverse + replacement = 3 (plus opening = 4 total)
      expect(state.journals, hasLength(4));
      final inv = state.journals.firstWhere(
        (j) => j.journal.id == 'j-atom-inv',
      );
      final repl = state.journals.firstWhere(
        (j) => j.journal.id == 'j-atom-repl',
      );
      expect(inv.journal.reversesId, 'j-atom-0');
      expect(repl.correctedFromJournalId, 'j-atom-0');

      // Exactly 2 receipts (1 create + 1 edit)
      expect(state.receipts, hasLength(2));
      final editReceipt = state.receipts.firstWhere(
        (r) => r.identity.operationId == 'op-atom-edit',
      );
      expect(editReceipt.status, DurableCommandStatus.committed);

      // Queries reflect updated remaining
      final snap = DailyCashQueries(state.account).day(postDate.toString());
      expect(snap.remaining, BigInt.from(70000));
      expect(snap.transferred, BigInt.from(30000));
    });

    test('atomic persistence of delete removes source transfer, appends 1 inverse journal and 1 receipt in 1 revision increment', () async {
      final store = await openStore();
      final transferCoord = RestaurantJournalTransferCommandCoordinator(
        store: store,
        mapper: mapper,
      );
      final corrCoord = RestaurantJournalTransferCorrectionCommandCoordinator(
        store: store,
        mapper: mapper,
      );

      await store.writeDocument(
        codec.encodeState(buildSyntheticState(account: buildSampleAccount())),
        writeToken: 'seed-del-atomicity',
      );

      var fence = await currentFence(store);
      await transferCoord.execute(
        DailyToCashboxTransferCommand(
          operationId: 'op-del-create',
          accountLineage: 'test-corr-lineage-1',
          expectedFence: fence,
          transferId: 't-del',
          journalId: 'j-del-0',
          date: postDate,
          amount: BigInt.from(25000),
          recordedAt: '2026-01-15T10:00:00.000Z',
        ),
      );

      // Store is at revision 2
      expect(
        ((await store.readDocument()) as CapabilitySuccess<DocumentSnapshot?>)
            .value!
            .revision,
        2,
      );

      // Delete transfer
      fence = await currentFence(store);
      final delCmd = DeleteDailyTransferCommand(
        operationId: 'op-del-exec',
        accountLineage: 'test-corr-lineage-1',
        expectedFence: fence,
        transferId: 't-del',
        expectedActiveJournalId: 'j-del-0',
        inverseJournalId: 'j-del-inv',
        reason: 'Delete transfer',
        recordedAt: '2026-01-15T11:00:00.000Z',
      );

      final delRes = await corrCoord.executeDelete(delCmd);
      expect(
        delRes,
        isA<
          DurableCommandSuccess<RestaurantJournalTransferCorrectionOutcome>
        >(),
      );

      // Exactly 1 revision increment (revision 3)
      final afterDelSnap =
          ((await store.readDocument()) as CapabilitySuccess<DocumentSnapshot?>)
              .value!;
      expect(afterDelSnap.revision, 3);

      final state = codec.decodeState(afterDelSnap.payload);
      // Source transfer removed
      final transfers = (state.account.toJson()['transfers'] as List)
          .cast<Map<String, Object?>>();
      expect(transfers, isEmpty);

      // Inverse journal appended
      final inv = state.journals.firstWhere((j) => j.journal.id == 'j-del-inv');
      expect(inv.journal.reversesId, 'j-del-0');

      // Queries reflect remaining returned to drawer
      final snap = DailyCashQueries(state.account).day(postDate.toString());
      expect(snap.remaining, BigInt.from(100000));
      expect(snap.transferred, BigInt.zero);
    });

    test('real store close and reopen preserves complete state, journals, and receipts, enabling historical replay', () async {
      final store = await openStore();
      final transferCoord = RestaurantJournalTransferCommandCoordinator(
        store: store,
        mapper: mapper,
      );
      final corrCoord = RestaurantJournalTransferCorrectionCommandCoordinator(
        store: store,
        mapper: mapper,
      );

      await store.writeDocument(
        codec.encodeState(buildSyntheticState(account: buildSampleAccount())),
        writeToken: 'seed-reopen-test',
      );

      // 1. Create
      var fence = await currentFence(store);
      final cmdCreate = DailyToCashboxTransferCommand(
        operationId: 'op-hist-create',
        accountLineage: 'test-corr-lineage-1',
        expectedFence: fence,
        transferId: 't-hist',
        journalId: 'j-hist-0',
        date: postDate,
        amount: BigInt.from(20000),
        recordedAt: '2026-01-15T10:00:00.000Z',
      );
      await transferCoord.execute(cmdCreate);

      // 2. Edit
      fence = await currentFence(store);
      final cmdEdit = EditDailyTransferCommand(
        operationId: 'op-hist-edit',
        accountLineage: 'test-corr-lineage-1',
        expectedFence: fence,
        transferId: 't-hist',
        expectedActiveJournalId: 'j-hist-0',
        inverseJournalId: 'j-hist-inv',
        replacementJournalId: 'j-hist-repl',
        newAmount: BigInt.from(40000),
        reason: 'Edit to 40k',
        recordedAt: '2026-01-15T11:00:00.000Z',
      );
      await corrCoord.executeEdit(cmdEdit);

      // 3. Delete
      fence = await currentFence(store);
      final cmdDelete = DeleteDailyTransferCommand(
        operationId: 'op-hist-del',
        accountLineage: 'test-corr-lineage-1',
        expectedFence: fence,
        transferId: 't-hist',
        expectedActiveJournalId: 'j-hist-repl',
        inverseJournalId: 'j-hist-del-inv',
        reason: 'Delete transfer',
        recordedAt: '2026-01-15T12:00:00.000Z',
      );
      await corrCoord.executeDelete(cmdDelete);

      // Close store and reopen
      await store.close();
      openStores.remove(store);

      final reopenedStore = await openStore();
      final reopenedTransferCoord = RestaurantJournalTransferCommandCoordinator(
        store: reopenedStore,
        mapper: mapper,
      );
      final reopenedCorrCoord =
          RestaurantJournalTransferCorrectionCommandCoordinator(
            store: reopenedStore,
            mapper: mapper,
          );

      final snap =
          ((await reopenedStore.readDocument())
                  as CapabilitySuccess<DocumentSnapshot?>)
              .value!;
      expect(snap.revision, 4);

      // Replay all historical commands against reopened store
      final replayCreate = await reopenedTransferCoord.execute(cmdCreate);
      expect(
        replayCreate,
        isA<DurableCommandReplayed<RestaurantJournalTransferOutcome>>(),
      );

      final replayEdit = await reopenedCorrCoord.executeEdit(cmdEdit);
      expect(
        replayEdit,
        isA<
          DurableCommandReplayed<RestaurantJournalTransferCorrectionOutcome>
        >(),
      );
      expect(
        (replayEdit
                as DurableCommandReplayed<
                  RestaurantJournalTransferCorrectionOutcome
                >)
            .outcome!
            .netAmount,
        '40000',
      );

      final replayDelete = await reopenedCorrCoord.executeDelete(cmdDelete);
      expect(
        replayDelete,
        isA<
          DurableCommandReplayed<RestaurantJournalTransferCorrectionOutcome>
        >(),
      );
      expect(
        (replayDelete
                as DurableCommandReplayed<
                  RestaurantJournalTransferCorrectionOutcome
                >)
            .outcome!
            .netAmount,
        '40000',
      );
    });

    test('idempotent replay of edit and delete returns DurableCommandReplayed without incrementing store revision', () async {
      final store = await openStore();
      final transferCoord = RestaurantJournalTransferCommandCoordinator(
        store: store,
        mapper: mapper,
      );
      final corrCoord = RestaurantJournalTransferCorrectionCommandCoordinator(
        store: store,
        mapper: mapper,
      );

      await store.writeDocument(
        codec.encodeState(buildSyntheticState(account: buildSampleAccount())),
        writeToken: 'seed-idemp-test',
      );

      var fence = await currentFence(store);
      await transferCoord.execute(
        DailyToCashboxTransferCommand(
          operationId: 'op-idemp-create',
          accountLineage: 'test-corr-lineage-1',
          expectedFence: fence,
          transferId: 't-idemp',
          journalId: 'j-idemp-0',
          date: postDate,
          amount: BigInt.from(15000),
          recordedAt: '2026-01-15T10:00:00.000Z',
        ),
      );

      // Execute edit 1st time
      fence = await currentFence(store);
      final editCmd = EditDailyTransferCommand(
        operationId: 'op-idemp-edit',
        accountLineage: 'test-corr-lineage-1',
        expectedFence: fence,
        transferId: 't-idemp',
        expectedActiveJournalId: 'j-idemp-0',
        inverseJournalId: 'j-idemp-inv',
        replacementJournalId: 'j-idemp-repl',
        newAmount: BigInt.from(25000),
        reason: 'Edit to 25k',
        recordedAt: '2026-01-15T11:00:00.000Z',
      );
      final firstEdit = await corrCoord.executeEdit(editCmd);
      expect(
        firstEdit,
        isA<
          DurableCommandSuccess<RestaurantJournalTransferCorrectionOutcome>
        >(),
      );
      expect(
        ((await store.readDocument()) as CapabilitySuccess<DocumentSnapshot?>)
            .value!
            .revision,
        3,
      );

      // Execute edit 2nd time (replay)
      final replayEdit = await corrCoord.executeEdit(editCmd);
      expect(
        replayEdit,
        isA<
          DurableCommandReplayed<RestaurantJournalTransferCorrectionOutcome>
        >(),
      );
      expect(
        ((await store.readDocument()) as CapabilitySuccess<DocumentSnapshot?>)
            .value!
            .revision,
        3,
      );

      // Execute delete 1st time
      fence = await currentFence(store);
      final delCmd = DeleteDailyTransferCommand(
        operationId: 'op-idemp-del',
        accountLineage: 'test-corr-lineage-1',
        expectedFence: fence,
        transferId: 't-idemp',
        expectedActiveJournalId: 'j-idemp-repl',
        inverseJournalId: 'j-idemp-del-inv',
        reason: 'Delete',
        recordedAt: '2026-01-15T12:00:00.000Z',
      );
      final firstDel = await corrCoord.executeDelete(delCmd);
      expect(
        firstDel,
        isA<
          DurableCommandSuccess<RestaurantJournalTransferCorrectionOutcome>
        >(),
      );
      expect(
        ((await store.readDocument()) as CapabilitySuccess<DocumentSnapshot?>)
            .value!
            .revision,
        4,
      );

      // Execute delete 2nd time (replay)
      final replayDel = await corrCoord.executeDelete(delCmd);
      expect(
        replayDel,
        isA<
          DurableCommandReplayed<RestaurantJournalTransferCorrectionOutcome>
        >(),
      );
      expect(
        ((await store.readDocument()) as CapabilitySuccess<DocumentSnapshot?>)
            .value!
            .revision,
        4,
      );
    });

    test(
      'tampered command on replay rejects with changed_payload_rejected',
      () async {
        final store = await openStore();
        final transferCoord = RestaurantJournalTransferCommandCoordinator(
          store: store,
          mapper: mapper,
        );
        final corrCoord = RestaurantJournalTransferCorrectionCommandCoordinator(
          store: store,
          mapper: mapper,
        );

        await store.writeDocument(
          codec.encodeState(buildSyntheticState(account: buildSampleAccount())),
          writeToken: 'seed-tamper-test',
        );

        var fence = await currentFence(store);
        await transferCoord.execute(
          DailyToCashboxTransferCommand(
            operationId: 'op-tamp-create',
            accountLineage: 'test-corr-lineage-1',
            expectedFence: fence,
            transferId: 't-tamp',
            journalId: 'j-tamp-0',
            date: postDate,
            amount: BigInt.from(15000),
            recordedAt: '2026-01-15T10:00:00.000Z',
          ),
        );

        fence = await currentFence(store);
        final editCmd = EditDailyTransferCommand(
          operationId: 'op-tamp-edit',
          accountLineage: 'test-corr-lineage-1',
          expectedFence: fence,
          transferId: 't-tamp',
          expectedActiveJournalId: 'j-tamp-0',
          inverseJournalId: 'j-tamp-inv',
          replacementJournalId: 'j-tamp-repl',
          newAmount: BigInt.from(25000),
          reason: 'Edit to 25k',
          recordedAt: '2026-01-15T11:00:00.000Z',
        );
        await corrCoord.executeEdit(editCmd);

        // Attempt replay with changed amount
        final tamperedEditCmd = EditDailyTransferCommand(
          operationId: 'op-tamp-edit',
          accountLineage: 'test-corr-lineage-1',
          expectedFence: fence,
          transferId: 't-tamp',
          expectedActiveJournalId: 'j-tamp-0',
          inverseJournalId: 'j-tamp-inv',
          replacementJournalId: 'j-tamp-repl',
          newAmount: BigInt.from(28000), // Changed amount!
          reason: 'Edit to 25k',
          recordedAt: '2026-01-15T11:00:00.000Z',
        );
        final tampRes = await corrCoord.executeEdit(tamperedEditCmd);
        expect(
          tampRes,
          isA<
            DurableCommandFailure<RestaurantJournalTransferCorrectionOutcome>
          >(),
        );
        expect(
          (tampRes as DurableCommandFailure).code,
          DurableCommandErrorCodes.changedPayloadRejected,
        );

        // Attempt replay with changed payloadVersion
        final tamperedVersionCmd = EditDailyTransferCommand(
          operationId: 'op-tamp-edit',
          payloadVersion: 2, // Changed version!
          accountLineage: 'test-corr-lineage-1',
          expectedFence: fence,
          transferId: 't-tamp',
          expectedActiveJournalId: 'j-tamp-0',
          inverseJournalId: 'j-tamp-inv',
          replacementJournalId: 'j-tamp-repl',
          newAmount: BigInt.from(25000),
          reason: 'Edit to 25k',
          recordedAt: '2026-01-15T11:00:00.000Z',
        );
        final tampVerRes = await corrCoord.executeEdit(tamperedVersionCmd);
        expect(
          tampVerRes,
          isA<
            DurableCommandFailure<RestaurantJournalTransferCorrectionOutcome>
          >(),
        );
        expect(
          (tampVerRes as DurableCommandFailure).code,
          DurableCommandErrorCodes.changedPayloadRejected,
        );
      },
    );

    test('account lineage mismatch and stale authority fence rejection with zero writes', () async {
      final store = await openStore();
      final corrCoord = RestaurantJournalTransferCorrectionCommandCoordinator(
        store: store,
        mapper: mapper,
      );

      await store.writeDocument(
        codec.encodeState(buildSyntheticState(account: buildSampleAccount())),
        writeToken: 'seed-lin-test',
      );

      var fence = await currentFence(store);
      final editWrongLineage = EditDailyTransferCommand(
        operationId: 'op-wrong-lin',
        accountLineage: 'wrong-lineage-submitted',
        expectedFence: fence,
        transferId: 't-wrong',
        expectedActiveJournalId: 'j-wrong',
        inverseJournalId: 'j-wrong-inv',
        replacementJournalId: 'j-wrong-repl',
        newAmount: BigInt.from(30000),
        reason: 'Wrong lineage',
        recordedAt: '2026-01-15T11:00:00.000Z',
      );
      final wrongLinRes = await corrCoord.executeEdit(editWrongLineage);
      expect(
        wrongLinRes,
        isA<
          DurableCommandFailure<RestaurantJournalTransferCorrectionOutcome>
        >(),
      );
      expect(
        (wrongLinRes as DurableCommandFailure).code,
        RestaurantJournalTransferCorrectionErrorCodes.accountLineageMismatch,
      );
      expect(
        ((await store.readDocument()) as CapabilitySuccess<DocumentSnapshot?>)
            .value!
            .revision,
        1,
      );

      // Stale fence
      const staleFence = StorageFence(
        storeId: 'dakhl-store',
        generation: 'stale-gen',
      );
      final editStaleFence = EditDailyTransferCommand(
        operationId: 'op-stale-fence',
        accountLineage: 'test-corr-lineage-1',
        expectedFence: staleFence,
        transferId: 't-stale',
        expectedActiveJournalId: 'j-stale',
        inverseJournalId: 'j-stale-inv',
        replacementJournalId: 'j-stale-repl',
        newAmount: BigInt.from(30000),
        reason: 'Stale fence',
        recordedAt: '2026-01-15T11:00:00.000Z',
      );
      final staleFenceRes = await corrCoord.executeEdit(editStaleFence);
      expect(
        staleFenceRes,
        isA<
          DurableCommandFailure<RestaurantJournalTransferCorrectionOutcome>
        >(),
      );
      expect(
        (staleFenceRes as DurableCommandFailure).code,
        DurableCommandErrorCodes.staleAuthorityFence,
      );
      expect(
        ((await store.readDocument()) as CapabilitySuccess<DocumentSnapshot?>)
            .value!
            .revision,
        1,
      );
    });

    test('proposal rejection leaves store revision and payload completely unchanged', () async {
      final store = await openStore();
      final transferCoord = RestaurantJournalTransferCommandCoordinator(
        store: store,
        mapper: mapper,
      );
      final corrCoord = RestaurantJournalTransferCorrectionCommandCoordinator(
        store: store,
        mapper: mapper,
      );

      await store.writeDocument(
        codec.encodeState(buildSyntheticState(account: buildSampleAccount())),
        writeToken: 'seed-prop-reject',
      );

      var fence = await currentFence(store);
      await transferCoord.execute(
        DailyToCashboxTransferCommand(
          operationId: 'op-prop-create',
          accountLineage: 'test-corr-lineage-1',
          expectedFence: fence,
          transferId: 't-prop',
          journalId: 'j-prop-0',
          date: postDate,
          amount: BigInt.from(20000),
          recordedAt: '2026-01-15T10:00:00.000Z',
        ),
      );

      final beforeSnap =
          ((await store.readDocument()) as CapabilitySuccess<DocumentSnapshot?>)
              .value!;
      expect(beforeSnap.revision, 2);

      // Attempt edit with excessive amount (> 100k available + old 20k = 100k total available)
      fence = await currentFence(store);
      final excessiveEdit = EditDailyTransferCommand(
        operationId: 'op-prop-excessive',
        accountLineage: 'test-corr-lineage-1',
        expectedFence: fence,
        transferId: 't-prop',
        expectedActiveJournalId: 'j-prop-0',
        inverseJournalId: 'j-prop-inv',
        replacementJournalId: 'j-prop-repl',
        newAmount: BigInt.from(150000),
        reason: 'Excessive edit',
        recordedAt: '2026-01-15T11:00:00.000Z',
      );
      final rejectRes = await corrCoord.executeEdit(excessiveEdit);
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

      final afterSnap =
          ((await store.readDocument()) as CapabilitySuccess<DocumentSnapshot?>)
              .value!;
      expect(afterSnap.revision, beforeSnap.revision);
      expect(afterSnap.payload, beforeSnap.payload);
    });

    test('lost committed write acknowledgement on edit resolves and reopens seamlessly', () async {
      final realStore = await openStore();
      final wrapper = UnknownAckStore(realStore);
      final transferCoord = RestaurantJournalTransferCommandCoordinator(
        store: wrapper,
        mapper: mapper,
      );
      final corrCoord = RestaurantJournalTransferCorrectionCommandCoordinator(
        store: wrapper,
        mapper: mapper,
      );

      await realStore.writeDocument(
        codec.encodeState(buildSyntheticState(account: buildSampleAccount())),
        writeToken: 'seed-lost-edit-ack',
      );

      var fence = await currentFence(realStore);
      await transferCoord.execute(
        DailyToCashboxTransferCommand(
          operationId: 'op-lost-create',
          accountLineage: 'test-corr-lineage-1',
          expectedFence: fence,
          transferId: 't-lost',
          journalId: 'j-lost-0',
          date: postDate,
          amount: BigInt.from(20000),
          recordedAt: '2026-01-15T10:00:00.000Z',
        ),
      );

      fence = await currentFence(realStore);
      final editCmd = EditDailyTransferCommand(
        operationId: 'op-lost-edit',
        accountLineage: 'test-corr-lineage-1',
        expectedFence: fence,
        transferId: 't-lost',
        expectedActiveJournalId: 'j-lost-0',
        inverseJournalId: 'j-lost-inv',
        replacementJournalId: 'j-lost-repl',
        newAmount: BigInt.from(30000),
        reason: 'Lost ack edit',
        recordedAt: '2026-01-15T11:00:00.000Z',
      );

      wrapper.loseNextCommittedWriteAcknowledgement = true;
      final result = await corrCoord.executeEdit(editCmd);
      expect(
        result,
        isA<
          DurableCommandReplayed<RestaurantJournalTransferCorrectionOutcome>
        >(),
      );
      expect(wrapper.committedWrites, 2); // 1 create + 1 edit
      expect(wrapper.lostAcknowledgements, 1);
      expect(wrapper.resolveCalls, greaterThanOrEqualTo(1));

      // Close and reopen
      await realStore.close();
      final reopened = await openStore();
      final snap =
          ((await reopened.readDocument())
                  as CapabilitySuccess<DocumentSnapshot?>)
              .value!;
      expect(snap.revision, 3);
      final state = codec.decodeState(snap.payload);
      expect(state.receipts, hasLength(2));
      expect(
        state.receipts.any((r) => r.identity.operationId == 'op-lost-edit'),
        isTrue,
      );
    });

    test('lost committed write acknowledgement on delete resolves and reopens seamlessly', () async {
      final realStore = await openStore();
      final wrapper = UnknownAckStore(realStore);
      final transferCoord = RestaurantJournalTransferCommandCoordinator(
        store: wrapper,
        mapper: mapper,
      );
      final corrCoord = RestaurantJournalTransferCorrectionCommandCoordinator(
        store: wrapper,
        mapper: mapper,
      );

      await realStore.writeDocument(
        codec.encodeState(buildSyntheticState(account: buildSampleAccount())),
        writeToken: 'seed-lost-del-ack',
      );

      var fence = await currentFence(realStore);
      await transferCoord.execute(
        DailyToCashboxTransferCommand(
          operationId: 'op-lost-del-create',
          accountLineage: 'test-corr-lineage-1',
          expectedFence: fence,
          transferId: 't-lost-del',
          journalId: 'j-lost-del-0',
          date: postDate,
          amount: BigInt.from(20000),
          recordedAt: '2026-01-15T10:00:00.000Z',
        ),
      );

      fence = await currentFence(realStore);
      final delCmd = DeleteDailyTransferCommand(
        operationId: 'op-lost-del-cmd',
        accountLineage: 'test-corr-lineage-1',
        expectedFence: fence,
        transferId: 't-lost-del',
        expectedActiveJournalId: 'j-lost-del-0',
        inverseJournalId: 'j-lost-del-inv',
        reason: 'Lost ack delete',
        recordedAt: '2026-01-15T11:00:00.000Z',
      );

      wrapper.loseNextCommittedWriteAcknowledgement = true;
      final result = await corrCoord.executeDelete(delCmd);
      expect(
        result,
        isA<
          DurableCommandReplayed<RestaurantJournalTransferCorrectionOutcome>
        >(),
      );
      expect(wrapper.committedWrites, 2); // 1 create + 1 delete
      expect(wrapper.lostAcknowledgements, 1);
      expect(wrapper.resolveCalls, greaterThanOrEqualTo(1));

      // Close and reopen
      await realStore.close();
      final reopened = await openStore();
      final snap =
          ((await reopened.readDocument())
                  as CapabilitySuccess<DocumentSnapshot?>)
              .value!;
      expect(snap.revision, 3);
      final state = codec.decodeState(snap.payload);
      expect(state.receipts, hasLength(2));
      expect(
        state.receipts.any((r) => r.identity.operationId == 'op-lost-del-cmd'),
        isTrue,
      );
    });

    test('pending-read uncertainty resolves before command commits', () async {
      final realStore = await openStore();
      final wrapper = UnknownAckStore(realStore);
      final transferCoord = RestaurantJournalTransferCommandCoordinator(
        store: wrapper,
        mapper: mapper,
      );
      final corrCoord = RestaurantJournalTransferCorrectionCommandCoordinator(
        store: wrapper,
        mapper: mapper,
      );

      await realStore.writeDocument(
        codec.encodeState(buildSyntheticState(account: buildSampleAccount())),
        writeToken: 'seed-pend-read',
      );

      var fence = await currentFence(realStore);
      await transferCoord.execute(
        DailyToCashboxTransferCommand(
          operationId: 'op-pend-create',
          accountLineage: 'test-corr-lineage-1',
          expectedFence: fence,
          transferId: 't-pend',
          journalId: 'j-pend-0',
          date: postDate,
          amount: BigInt.from(20000),
          recordedAt: '2026-01-15T10:00:00.000Z',
        ),
      );

      // Inject unknown on read before edit
      wrapper.injectUnknownRead = true;

      fence = await currentFence(realStore);
      final editCmd = EditDailyTransferCommand(
        operationId: 'op-pend-edit',
        accountLineage: 'test-corr-lineage-1',
        expectedFence: fence,
        transferId: 't-pend',
        expectedActiveJournalId: 'j-pend-0',
        inverseJournalId: 'j-pend-inv',
        replacementJournalId: 'j-pend-repl',
        newAmount: BigInt.from(30000),
        reason: 'Pending read resolve edit',
        recordedAt: '2026-01-15T11:00:00.000Z',
      );

      final result = await corrCoord.executeEdit(editCmd);
      expect(
        result,
        isA<
          DurableCommandSuccess<RestaurantJournalTransferCorrectionOutcome>
        >(),
      );
      expect(wrapper.resolveCalls, greaterThanOrEqualTo(1));

      final readRes = await realStore.readDocument();
      final snap = (readRes as CapabilitySuccess<DocumentSnapshot?>).value!;
      expect(snap.revision, 3);
      final state = codec.decodeState(snap.payload);
      expect(state.receipts, hasLength(2));
      expect(state.receipts.last.identity.operationId, 'op-pend-edit');
    });
  });
}
