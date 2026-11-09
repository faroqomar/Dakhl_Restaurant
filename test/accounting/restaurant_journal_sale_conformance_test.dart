import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:madar_application/madar_application.dart';
import 'package:madar_data/madar_data.dart';
import 'package:madar_domain/madar_domain.dart';
import 'package:dakhl_restaurant/accounting/restaurant_journal_mapper.dart';
import 'package:dakhl_restaurant/accounting/restaurant_journal_sale_commands.dart';
import 'package:dakhl_restaurant/accounts/account_document.dart';
import 'package:dakhl_restaurant/accounts/legacy_account_codec.dart';
import 'package:dakhl_restaurant/accounts/portable_journal_codec.dart';
import 'package:dakhl_restaurant/accounts/portable_journal_state.dart';
import 'package:dakhl_restaurant/sales/return_proposal.dart';

/// Test decorator that simulates an uncertain acknowledgement on write/read.
class UnknownAckStore implements LocalDocumentWorkspaceStore {
  UnknownAckStore(this.inner);
  final LocalDocumentWorkspaceStore inner;
  bool injectUnknownRead = false;
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
  }) => inner.writeDocument(
    payload,
    writeToken: writeToken,
    expected: expected,
    replaceGeneration: replaceGeneration,
  );

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

Future<StorageFence> _currentFence(LocalDocumentWorkspaceStore store) async {
  final read = await store.readDocument();
  return (read as CapabilitySuccess<DocumentSnapshot?>).value!.fence;
}

void main() {
  const legacyCodec = LegacyAccountCodec();
  const codec = PortableJournalCodec();
  final mapper = RestaurantJournalMapper();

  AccountDocument buildSampleAccount() {
    final oracle = jsonDecode(
      File('test/sales/sale_proposal_oracle.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final defaultCase = (oracle['cases'] as List).first as Map<String, dynamic>;
    final stateJson = defaultCase['state'] as Map<String, dynamic>;
    return legacyCodec.decodeJson(Map<String, Object?>.from(stateJson));
  }

  DateOnly d(String iso) =>
      DateOnly.parse(iso, minimumYear: 1000, maximumYear: 9999);

  PortableJournalState buildSyntheticState({
    required AccountDocument account,
    required String accountLineage,
    bool isGated = false,
    DateOnly? cutoverDate,
    String? openingJournalId,
  }) {
    final cutover = isGated
        ? PortableJournalCutoverState.gated()
        : PortableJournalCutoverState.established(
            cutoverDate: cutoverDate ?? d('2026-01-01'),
            openingJournalId: openingJournalId ?? 'open-jnl-1',
          );

    final openingEntry = isGated
        ? null
        : PortableJournalEntry(
            journal: BalancedJournal.validate(
              id: openingJournalId ?? 'open-jnl-1',
              effectiveDate: cutoverDate ?? d('2026-01-01'),
              policy: RestaurantJournalPolicies.opening,
              lines: [
                JournalLine(
                  accountId: 'asset:cash:daily',
                  side: JournalSide.debit,
                  amountUnits: BigInt.from(50000),
                  currency: 'IQD',
                  scale: 0,
                ),
                JournalLine(
                  accountId: 'equity:opening_balance',
                  side: JournalSide.credit,
                  amountUnits: BigInt.from(50000),
                  currency: 'IQD',
                  scale: 0,
                ),
              ],
            ),
            sourceType: RestaurantJournalSourceType.cutoverOpening.name,
            sourceRecordId: 'cutover-record',
            recordedAt: '2026-01-01T00:00:00.000Z',
          );

    return PortableJournalState(
      accountLineage: accountLineage,
      account: account,
      sourceProvenance: PortableJournalSourceProvenance(
        sourceVersion: 11,
        enrolledAt: '2026-01-01T00:00:00.000Z',
        migrated: false,
      ),
      cutoverState: cutover,
      journals: [?openingEntry],
      receipts: const [],
    );
  }

  group('Restaurant Journal Sales Store Conformance', () {
    late Directory tempDir;
    final openStores = <PowerSyncLocalDocumentWorkspaceStore>[];

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp(
        'dakhl-sales-conformance-store-',
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

    test('atomic persistence of completed sale updates source, journals, and receipts', () async {
      final store = await openStore();
      final coordinator = RestaurantJournalSaleCommandCoordinator(
        store: store,
        mapper: mapper,
        codec: codec,
      );

      final initialDoc = buildSampleAccount();
      final initialV12 = buildSyntheticState(
        account: initialDoc,
        accountLineage: 'conformance-lineage-1',
      );

      final seedRes = await store.writeDocument(
        codec.encodeState(initialV12),
        writeToken: 'seed-token-1',
      );
      expect(seedRes, isA<CapabilitySuccess<DocumentSnapshot>>());
      final seedSnap = (seedRes as CapabilitySuccess<DocumentSnapshot>).value;
      expect(seedSnap.revision, 1);

      // Execute CompleteSaleCommand
      final saleCmd = CompleteSaleCommand(
        expectedFence: await _currentFence(store),
        operationId: 'cmd-sale-101',
        accountLineage: 'conformance-lineage-1',
        saleId: 'sal-101',
        journalId: 'jnl-sal-101',
        draft: {
          'date': '2026-01-03',
          'discount': 100,
          'lines': [
            {'productId': 'p', 'quantity': 2, 'price': 1000},
          ],
        },
        recordedAt: '2026-01-03T12:00:00.000Z',
      );

      final result = await coordinator.executeSale(saleCmd);
      expect(
        result,
        isA<DurableCommandSuccess<RestaurantJournalSaleOutcome>>(),
      );
      final success =
          result as DurableCommandSuccess<RestaurantJournalSaleOutcome>;
      expect(success.outcome.saleId, 'sal-101');
      expect(success.outcome.journalId, 'jnl-sal-101');
      expect(success.outcome.netAmount, '1900');
      expect(success.receipt.sequence, 1);
      expect(success.snapshot.revision, 2);

      // Verify persisted state from real store
      final readRes = await store.readDocument();
      final snap = (readRes as CapabilitySuccess<DocumentSnapshot?>).value!;
      final state = codec.decodeState(snap.payload);

      expect(state.accountLineage, 'conformance-lineage-1');
      final sales = (state.account.toJson()['sales'] as List)
          .cast<Map<String, Object?>>();
      expect(sales.length, 1);
      expect(sales.first['id'], 'sal-101');
      expect(sales.first['status'], 'completed');
      expect(state.journals.length, 2); // opening + sale

      final saleJournal = state.journals.last;
      expect(saleJournal.sourceType, 'sale');
      expect(saleJournal.sourceRecordId, 'sal-101');
      expect(saleJournal.metadata['net'], '1900');
      expect(saleJournal.metadata['gross'], '2000');
      expect(saleJournal.metadata['discount'], '100');
      expect(saleJournal.metadata['sourceVersion'], 11);
      expect(saleJournal.metadata['receiptNumber'], 'S-000001');

      expect(state.receipts.length, 1);
      expect(state.receipts.first.identity.operationId, 'cmd-sale-101');
    });

    test('idempotent replay returns DurableCommandReplayed without incrementing store revision', () async {
      final store = await openStore();
      final coordinator = RestaurantJournalSaleCommandCoordinator(
        store: store,
        mapper: mapper,
        codec: codec,
      );

      final initialDoc = buildSampleAccount();
      final initialV12 = buildSyntheticState(
        account: initialDoc,
        accountLineage: 'replay-lineage',
      );

      await store.writeDocument(
        codec.encodeState(initialV12),
        writeToken: 'seed-token',
      );

      final saleCmd = CompleteSaleCommand(
        expectedFence: await _currentFence(store),
        operationId: 'cmd-replay-sale',
        accountLineage: 'replay-lineage',
        saleId: 'sal-replay',
        journalId: 'jnl-sal-replay',
        draft: {
          'date': '2026-01-03',
          'discount': 0,
          'lines': [
            {'productId': 'p', 'quantity': 1},
          ],
        },
        recordedAt: '2026-01-03T12:00:00.000Z',
      );

      // First run: commits
      final result1 = await coordinator.executeSale(saleCmd);
      expect(
        result1,
        isA<DurableCommandSuccess<RestaurantJournalSaleOutcome>>(),
      );
      final snap1 =
          (result1 as DurableCommandSuccess<RestaurantJournalSaleOutcome>)
              .snapshot;
      expect(snap1.revision, 2);

      // Replay: exact same command
      final result2 = await coordinator.executeSale(saleCmd);
      expect(
        result2,
        isA<DurableCommandReplayed<RestaurantJournalSaleOutcome>>(),
      );
      final replayed =
          result2 as DurableCommandReplayed<RestaurantJournalSaleOutcome>;
      expect(replayed.snapshot.revision, 2); // No new revision!
      expect(replayed.receipt.identity.operationId, 'cmd-replay-sale');
      expect(replayed.outcome, isNotNull);
      expect(replayed.outcome!.saleId, 'sal-replay');
      expect(replayed.outcome!.netAmount, '1000');

      // Verify store document was not modified
      final readRes = await store.readDocument();
      final currentSnap =
          (readRes as CapabilitySuccess<DocumentSnapshot?>).value!;
      expect(currentSnap.revision, 2);
      final currentState = codec.decodeState(currentSnap.payload);
      expect(currentState.journals.length, 2);
      expect(currentState.receipts.length, 1);
    });

    test('tampered command with changed financial field on replay rejects with changed_payload_rejected', () async {
      final store = await openStore();
      final coordinator = RestaurantJournalSaleCommandCoordinator(
        store: store,
        mapper: mapper,
        codec: codec,
      );

      final initialDoc = buildSampleAccount();
      final initialV12 = buildSyntheticState(
        account: initialDoc,
        accountLineage: 'tamper-lineage',
      );

      await store.writeDocument(
        codec.encodeState(initialV12),
        writeToken: 'seed-token',
      );

      final saleCmdOriginal = CompleteSaleCommand(
        expectedFence: await _currentFence(store),
        operationId: 'cmd-tamper-sale',
        accountLineage: 'tamper-lineage',
        saleId: 'sal-tamper',
        journalId: 'jnl-sal-tamper',
        draft: {
          'date': '2026-01-03',
          'discount': 100,
          'lines': [
            {'productId': 'p', 'quantity': 1},
          ],
        },
        recordedAt: '2026-01-03T12:00:00.000Z',
      );

      final result1 = await coordinator.executeSale(saleCmdOriginal);
      expect(
        result1,
        isA<DurableCommandSuccess<RestaurantJournalSaleOutcome>>(),
      );

      // Attempt replay with SAME operationId but CHANGED discount (200 instead of 100):
      final saleCmdTampered = CompleteSaleCommand(
        expectedFence: await _currentFence(store),
        operationId: 'cmd-tamper-sale', // same operationId
        accountLineage: 'tamper-lineage',
        saleId: 'sal-tamper',
        journalId: 'jnl-sal-tamper',
        draft: {
          'date': '2026-01-03',
          'discount': 200, // tampered financial field!
          'lines': [
            {'productId': 'p', 'quantity': 1},
          ],
        },
        recordedAt: '2026-01-03T12:00:00.000Z',
      );

      final result2 = await coordinator.executeSale(saleCmdTampered);
      expect(
        result2,
        isA<DurableCommandFailure<RestaurantJournalSaleOutcome>>(),
      );
      final failure =
          result2 as DurableCommandFailure<RestaurantJournalSaleOutcome>;
      expect(failure.code, DurableCommandErrorCodes.changedPayloadRejected);

      // Verify store document revision and state remained completely untouched!
      final readRes = await store.readDocument();
      final snap = (readRes as CapabilitySuccess<DocumentSnapshot?>).value!;
      expect(snap.revision, 2);
      final state = codec.decodeState(snap.payload);
      expect(state.receipts.length, 1);
      expect(
        state.journals.last.metadata['discount'],
        '100',
      ); // original untouched
    });

    test(
      'replaying with changed payload version rejects without writes',
      () async {
        final store = await openStore();
        final coordinator = RestaurantJournalSaleCommandCoordinator(
          store: store,
          mapper: mapper,
          codec: codec,
        );

        final initialDoc = buildSampleAccount();
        final initialV12 = buildSyntheticState(
          account: initialDoc,
          accountLineage: 'version-lineage',
        );

        await store.writeDocument(
          codec.encodeState(initialV12),
          writeToken: 'seed-token',
        );

        final cmdV1 = CompleteSaleCommand(
          expectedFence: await _currentFence(store),
          operationId: 'cmd-version-test',
          payloadVersion: 1,
          accountLineage: 'version-lineage',
          saleId: 'sal-v1',
          journalId: 'jnl-sal-v1',
          draft: {
            'date': '2026-01-03',
            'discount': 0,
            'lines': [
              {'productId': 'p', 'quantity': 1},
            ],
          },
          recordedAt: '2026-01-03T12:00:00.000Z',
        );

        await coordinator.executeSale(cmdV1);

        // Replay with payloadVersion: 2
        final cmdV2 = CompleteSaleCommand(
          expectedFence: await _currentFence(store),
          operationId: 'cmd-version-test',
          payloadVersion: 2, // Changed!
          accountLineage: 'version-lineage',
          saleId: 'sal-v1',
          journalId: 'jnl-sal-v1',
          draft: {
            'date': '2026-01-03',
            'discount': 0,
            'lines': [
              {'productId': 'p', 'quantity': 1},
            ],
          },
          recordedAt: '2026-01-03T12:00:00.000Z',
        );

        final result = await coordinator.executeSale(cmdV2);
        expect(
          result,
          isA<DurableCommandFailure<RestaurantJournalSaleOutcome>>(),
        );
        final fail =
            result as DurableCommandFailure<RestaurantJournalSaleOutcome>;
        expect(fail.code, DurableCommandErrorCodes.changedPayloadRejected);
      },
    );

    test('account lineage mismatch is checked before replay and rejects without executing', () async {
      final store = await openStore();
      final coordinator = RestaurantJournalSaleCommandCoordinator(
        store: store,
        mapper: mapper,
        codec: codec,
      );

      final initialDoc = buildSampleAccount();
      final initialV12 = buildSyntheticState(
        account: initialDoc,
        accountLineage: 'store-actual-lineage',
      );

      await store.writeDocument(
        codec.encodeState(initialV12),
        writeToken: 'seed-token',
      );

      // Command targeting a DIFFERENT expected account lineage:
      final cmdWrongLineage = CompleteSaleCommand(
        expectedFence: await _currentFence(store),
        operationId: 'cmd-wrong-lineage',
        accountLineage: 'different-expected-lineage',
        saleId: 'sal-wrong-lineage',
        journalId: 'jnl-sal-wrong-lineage',
        draft: {
          'date': '2026-01-03',
          'discount': 0,
          'lines': [
            {'productId': 'p', 'quantity': 1},
          ],
        },
        recordedAt: '2026-01-03T12:00:00.000Z',
      );

      final result = await coordinator.executeSale(cmdWrongLineage);
      expect(
        result,
        isA<DurableCommandFailure<RestaurantJournalSaleOutcome>>(),
      );
      final failure =
          result as DurableCommandFailure<RestaurantJournalSaleOutcome>;
      expect(
        failure.code,
        RestaurantJournalSaleErrorCodes.accountLineageMismatch,
      );

      // Ensure store remains at revision 1 and untouched
      final snap =
          ((await store.readDocument()) as CapabilitySuccess<DocumentSnapshot?>)
              .value!;
      expect(snap.revision, 1);
      final state = codec.decodeState(snap.payload);
      expect(state.receipts.isEmpty, isTrue);
    });

    test(
      'stale expected storage fence rejects command with stale_authority_fence',
      () async {
        final store = await openStore();
        final coordinator = RestaurantJournalSaleCommandCoordinator(
          store: store,
          mapper: mapper,
          codec: codec,
        );

        final initialDoc = buildSampleAccount();
        final initialV12 = buildSyntheticState(
          account: initialDoc,
          accountLineage: 'fence-lineage',
        );

        final seedRes = await store.writeDocument(
          codec.encodeState(initialV12),
          writeToken: 'seed-token',
        );
        final seedSnap = (seedRes as CapabilitySuccess<DocumentSnapshot>).value;
        final originalFence = seedSnap.fence;

        // Replace generation
        final replaceRes = await store.writeDocument(
          seedSnap.payload,
          expected: seedSnap,
          writeToken: 'replace-token',
          replaceGeneration: true,
        );
        final newFence =
            (replaceRes as CapabilitySuccess<DocumentSnapshot>).value.fence;
        expect(newFence.generation, isNot(originalFence.generation));

        // Attempt command targeting old stale fence:
        final cmdStaleFence = CompleteSaleCommand(
          operationId: 'cmd-stale-fence',
          accountLineage: 'fence-lineage',
          expectedFence: originalFence, // Stale!
          saleId: 'sal-stale',
          journalId: 'jnl-sal-stale',
          draft: {
            'date': '2026-01-03',
            'discount': 0,
            'lines': [
              {'productId': 'p', 'quantity': 1},
            ],
          },
          recordedAt: '2026-01-03T12:00:00.000Z',
        );

        final result = await coordinator.executeSale(cmdStaleFence);
        expect(
          result,
          isA<DurableCommandFailure<RestaurantJournalSaleOutcome>>(),
        );
        final fail =
            result as DurableCommandFailure<RestaurantJournalSaleOutcome>;
        expect(fail.code, DurableCommandErrorCodes.staleAuthorityFence);
      },
    );

    test(
      'rejection paths leave store revision and payload completely unchanged',
      () async {
        final store = await openStore();
        final coordinator = RestaurantJournalSaleCommandCoordinator(
          store: store,
          mapper: mapper,
          codec: codec,
        );

        // Seed a gated state (refuses posting)
        final initialDoc = buildSampleAccount();
        final gatedState = buildSyntheticState(
          account: initialDoc,
          accountLineage: 'gated-lineage',
          isGated: true,
        );

        final seedRes = await store.writeDocument(
          codec.encodeState(gatedState),
          writeToken: 'seed-token',
        );
        final seedSnap = (seedRes as CapabilitySuccess<DocumentSnapshot>).value;

        final cmd = CompleteSaleCommand(
          expectedFence: await _currentFence(store),
          operationId: 'cmd-gated-test',
          accountLineage: 'gated-lineage',
          saleId: 'sal-gated',
          journalId: 'jnl-sal-gated',
          draft: {
            'date': '2026-01-03',
            'discount': 0,
            'lines': [
              {'productId': 'p', 'quantity': 1},
            ],
          },
          recordedAt: '2026-01-03T12:00:00.000Z',
        );

        final result = await coordinator.executeSale(cmd);
        expect(
          result,
          isA<DurableCommandFailure<RestaurantJournalSaleOutcome>>(),
        );
        final fail =
            result as DurableCommandFailure<RestaurantJournalSaleOutcome>;
        expect(fail.code, RestaurantJournalSaleErrorCodes.cutoverGated);

        // Document revision and payload MUST be unchanged!
        final afterSnap =
            ((await store.readDocument())
                    as CapabilitySuccess<DocumentSnapshot?>)
                .value!;
        expect(afterSnap.revision, seedSnap.revision);
        expect(afterSnap.payload, seedSnap.payload);
      },
    );

    test('complete lifecycle: sale -> partial return -> full return with exact daily cash impact', () async {
      final store = await openStore();
      final coordinator = RestaurantJournalSaleCommandCoordinator(
        store: store,
        mapper: mapper,
        codec: codec,
      );

      final initialDoc = buildSampleAccount();
      final initialV12 = buildSyntheticState(
        account: initialDoc,
        accountLineage: 'lifecycle-lineage',
      );

      await store.writeDocument(
        codec.encodeState(initialV12),
        writeToken: 'seed-token',
      );

      // 1. Sale: 2 units of p at 1000 = 2000 gross, 0 discount, 2000 net
      final saleCmd = CompleteSaleCommand(
        expectedFence: await _currentFence(store),
        operationId: 'cmd-lifecycle-sale',
        accountLineage: 'lifecycle-lineage',
        saleId: 'sal-life-1',
        journalId: 'jnl-sal-life-1',
        draft: {
          'date': '2026-01-03',
          'discount': 0,
          'lines': [
            {'productId': 'p', 'quantity': 2, 'price': 1000},
          ],
        },
        recordedAt: '2026-01-03T12:00:00.000Z',
      );

      final saleRes = await coordinator.executeSale(saleCmd);
      expect(
        saleRes,
        isA<DurableCommandSuccess<RestaurantJournalSaleOutcome>>(),
      );

      // 2. Partial return: 1 unit on return date 2026-01-04
      final returnCmd1 = SaleReturnCommand(
        expectedFence: await _currentFence(store),
        operationId: 'cmd-lifecycle-ret-1',
        accountLineage: 'lifecycle-lineage',
        returnId: 'ret-life-1',
        saleId: 'sal-life-1',
        journalId: 'jnl-ret-life-1',
        returnDate: d('2026-01-04'),
        reason: 'First return',
        recordedAt: '2026-01-04T10:00:00.000Z',
        today: d('2026-01-04'),
        lines: [
          ReturnLineRequest(
            productId: 'p',
            quantityUnits: BigInt.from(1000), // 1 unit
            restock: true,
          ),
        ],
      );

      final returnRes1 = await coordinator.executeReturn(returnCmd1);
      expect(
        returnRes1,
        isA<DurableCommandSuccess<RestaurantJournalSaleOutcome>>(),
      );
      final retSuccess1 =
          returnRes1 as DurableCommandSuccess<RestaurantJournalSaleOutcome>;
      expect(retSuccess1.outcome.netAmount, '1000');
      expect(retSuccess1.snapshot.revision, 3);

      // 3. Second return completing the return: 1 unit on return date 2026-01-05
      final returnCmd2 = SaleReturnCommand(
        expectedFence: await _currentFence(store),
        operationId: 'cmd-lifecycle-ret-2',
        accountLineage: 'lifecycle-lineage',
        returnId: 'ret-life-2',
        saleId: 'sal-life-1',
        journalId: 'jnl-ret-life-2',
        returnDate: d('2026-01-05'),
        reason: 'Second return completing full refund',
        recordedAt: '2026-01-05T10:00:00.000Z',
        today: d('2026-01-05'),
        lines: [
          ReturnLineRequest(
            productId: 'p',
            quantityUnits: BigInt.from(1000),
            restock: true,
          ),
        ],
      );

      final returnRes2 = await coordinator.executeReturn(returnCmd2);
      expect(
        returnRes2,
        isA<DurableCommandSuccess<RestaurantJournalSaleOutcome>>(),
      );
      final retSuccess2 =
          returnRes2 as DurableCommandSuccess<RestaurantJournalSaleOutcome>;
      expect(retSuccess2.outcome.netAmount, '1000');
      expect(retSuccess2.snapshot.revision, 4);

      // 4. Over-return attempt: another 1 unit on same sale -> MUST BE REJECTED
      final overReturnCmd = SaleReturnCommand(
        expectedFence: await _currentFence(store),
        operationId: 'cmd-lifecycle-over-ret',
        accountLineage: 'lifecycle-lineage',
        returnId: 'ret-life-3',
        saleId: 'sal-life-1',
        journalId: 'jnl-ret-life-3',
        returnDate: d('2026-01-06'),
        reason: 'Excess return attempt',
        recordedAt: '2026-01-06T10:00:00.000Z',
        today: d('2026-01-06'),
        lines: [
          ReturnLineRequest(
            productId: 'p',
            quantityUnits: BigInt.from(1000),
            restock: false,
          ),
        ],
      );

      final overRes = await coordinator.executeReturn(overReturnCmd);
      expect(
        overRes,
        isA<DurableCommandFailure<RestaurantJournalSaleOutcome>>(),
      );
      final overFail =
          overRes as DurableCommandFailure<RestaurantJournalSaleOutcome>;
      expect(
        overFail.code,
        RestaurantJournalSaleErrorCodes.invalidReturnProposal,
      );

      // Verify store document revision remained 4
      final finalSnap =
          ((await store.readDocument()) as CapabilitySuccess<DocumentSnapshot?>)
              .value!;
      expect(finalSnap.revision, 4);
    });

    test('eligible original-date void reverses journal on original date and prevents subsequent returns or voids', () async {
      final store = await openStore();
      final coordinator = RestaurantJournalSaleCommandCoordinator(
        store: store,
        mapper: mapper,
        codec: codec,
      );

      final initialDoc = buildSampleAccount();
      final initialV12 = buildSyntheticState(
        account: initialDoc,
        accountLineage: 'void-lifecycle-lineage',
      );

      await store.writeDocument(
        codec.encodeState(initialV12),
        writeToken: 'seed-token',
      );

      // 1. Sale on 2026-01-03
      final saleCmd = CompleteSaleCommand(
        expectedFence: await _currentFence(store),
        operationId: 'cmd-void-sale',
        accountLineage: 'void-lifecycle-lineage',
        saleId: 'sal-to-be-voided',
        journalId: 'jnl-sal-to-be-voided',
        draft: {
          'date': '2026-01-03',
          'discount': 0,
          'lines': [
            {'productId': 'p', 'quantity': 2, 'price': 1000},
          ],
        },
        recordedAt: '2026-01-03T12:00:00.000Z',
      );

      final saleRes = await coordinator.executeSale(saleCmd);
      expect(
        saleRes,
        isA<DurableCommandSuccess<RestaurantJournalSaleOutcome>>(),
      );

      // 2. Void on 2026-01-04
      final voidCmd = SaleVoidCommand(
        expectedFence: await _currentFence(store),
        operationId: 'cmd-void-op',
        accountLineage: 'void-lifecycle-lineage',
        saleId: 'sal-to-be-voided',
        reversalJournalId: 'jnl-reversal-void',
        reason: 'Cashier error void ticket',
        voidedAt: '2026-01-04T09:00:00.000Z',
      );

      final voidRes = await coordinator.executeVoid(voidCmd);
      expect(
        voidRes,
        isA<DurableCommandSuccess<RestaurantJournalSaleOutcome>>(),
      );
      final voidSuccess =
          voidRes as DurableCommandSuccess<RestaurantJournalSaleOutcome>;
      expect(voidSuccess.snapshot.revision, 3);
      expect(voidSuccess.outcome.journalId, 'jnl-reversal-void');

      // Verify readback from store: reversal is strictly on 2026-01-03 (original date)
      final readRes = await store.readDocument();
      final snap = (readRes as CapabilitySuccess<DocumentSnapshot?>).value!;
      final state = codec.decodeState(snap.payload);

      final reversalEntry = state.journals.last;
      expect(reversalEntry.journal.id, 'jnl-reversal-void');
      expect(reversalEntry.journal.reversesId, 'jnl-sal-to-be-voided');
      expect(reversalEntry.journal.effectiveDate, d('2026-01-03'));
      expect(
        reversalEntry.metadata['reversalReason'],
        'Cashier error void ticket',
      );

      final sourceSales = (state.account.toJson()['sales'] as List)
          .cast<Map<String, Object?>>();
      final sourceSale = sourceSales.firstWhere(
        (s) => s['id'] == 'sal-to-be-voided',
      );
      expect(sourceSale['status'], 'void');
      expect(sourceSale['voidReason'], 'Cashier error void ticket');

      // 3. Attempt to return items against a voided sale: MUST BE REJECTED
      final returnCmd = SaleReturnCommand(
        expectedFence: await _currentFence(store),
        operationId: 'cmd-ret-voided',
        accountLineage: 'void-lifecycle-lineage',
        returnId: 'ret-against-void',
        saleId: 'sal-to-be-voided',
        journalId: 'jnl-ret-against-void',
        returnDate: d('2026-01-05'),
        reason: 'Refund',
        recordedAt: '2026-01-05T12:00:00.000Z',
        today: d('2026-01-05'),
        lines: [
          ReturnLineRequest(
            productId: 'p',
            quantityUnits: BigInt.from(1000),
            restock: false,
          ),
        ],
      );

      final returnRes = await coordinator.executeReturn(returnCmd);
      expect(
        returnRes,
        isA<DurableCommandFailure<RestaurantJournalSaleOutcome>>(),
      );
      final returnFail =
          returnRes as DurableCommandFailure<RestaurantJournalSaleOutcome>;
      expect(
        returnFail.code,
        RestaurantJournalSaleErrorCodes.saleUnavailableForReturn,
      );

      // 4. Attempt to void the voided sale again: MUST BE REJECTED
      final voidCmd2 = SaleVoidCommand(
        expectedFence: await _currentFence(store),
        operationId: 'cmd-void-again',
        accountLineage: 'void-lifecycle-lineage',
        saleId: 'sal-to-be-voided',
        reversalJournalId: 'jnl-reversal-twice',
        reason: 'Void again',
        voidedAt: '2026-01-05T14:00:00.000Z',
      );

      final voidRes2 = await coordinator.executeVoid(voidCmd2);
      expect(
        voidRes2,
        isA<DurableCommandFailure<RestaurantJournalSaleOutcome>>(),
      );
      final voidFail2 =
          voidRes2 as DurableCommandFailure<RestaurantJournalSaleOutcome>;
      expect(voidFail2.code, RestaurantJournalSaleErrorCodes.saleAlreadyVoid);
    });

    test('real store close and reopen preserves complete state, journals, and receipts', () async {
      final store = await openStore();
      final coordinator = RestaurantJournalSaleCommandCoordinator(
        store: store,
        mapper: mapper,
        codec: codec,
      );

      final initialDoc = buildSampleAccount();
      final initialV12 = buildSyntheticState(
        account: initialDoc,
        accountLineage: 'reopen-lineage',
      );

      await store.writeDocument(
        codec.encodeState(initialV12),
        writeToken: 'seed-token',
      );

      final saleCmd = CompleteSaleCommand(
        expectedFence: await _currentFence(store),
        operationId: 'cmd-reopen-sale',
        accountLineage: 'reopen-lineage',
        saleId: 'sal-reopen',
        journalId: 'jnl-sal-reopen',
        draft: {
          'date': '2026-01-03',
          'discount': 50,
          'lines': [
            {'productId': 'p', 'quantity': 1, 'price': 1000},
          ],
        },
        recordedAt: '2026-01-03T12:00:00.000Z',
      );

      final saleRes = await coordinator.executeSale(saleCmd);
      expect(
        saleRes,
        isA<DurableCommandSuccess<RestaurantJournalSaleOutcome>>(),
      );

      // Close the store
      await store.close();
      openStores.remove(store);

      // Reopen from same directory
      final reopenedStore = await openStore();
      final reopenedRead = await reopenedStore.readDocument();
      expect(reopenedRead, isA<CapabilitySuccess<DocumentSnapshot?>>());
      final snap =
          (reopenedRead as CapabilitySuccess<DocumentSnapshot?>).value!;
      expect(snap.revision, 2);

      final reopenedState = codec.decodeState(snap.payload);
      expect(reopenedState.accountLineage, 'reopen-lineage');
      expect(reopenedState.journals.length, 2);
      expect(reopenedState.receipts.length, 1);
      expect(
        reopenedState.receipts.first.identity.operationId,
        'cmd-reopen-sale',
      );
      expect(reopenedState.journals.last.metadata['net'], '950');

      // Replay against reopened store works seamlessly!
      final reopenedCoordinator = RestaurantJournalSaleCommandCoordinator(
        store: reopenedStore,
        mapper: mapper,
        codec: codec,
      );
      final replayRes = await reopenedCoordinator.executeSale(saleCmd);
      expect(
        replayRes,
        isA<DurableCommandReplayed<RestaurantJournalSaleOutcome>>(),
      );
      final replayed =
          replayRes as DurableCommandReplayed<RestaurantJournalSaleOutcome>;
      expect(replayed.snapshot.revision, 2);
      expect(replayed.outcome!.netAmount, '950');
    });

    test('uncertain acknowledgement resolves pending write and succeeds without duplicate commits', () async {
      final realStore = await openStore();
      final unknownStore = UnknownAckStore(realStore);
      final coordinator = RestaurantJournalSaleCommandCoordinator(
        store: unknownStore,
        mapper: mapper,
        codec: codec,
      );

      final initialDoc = buildSampleAccount();
      final initialV12 = buildSyntheticState(
        account: initialDoc,
        accountLineage: 'ack-lineage',
      );

      await unknownStore.writeDocument(
        codec.encodeState(initialV12),
        writeToken: 'seed-token',
      );

      // Inject unknown on initial read
      unknownStore.injectUnknownRead = true;

      final saleCmd = CompleteSaleCommand(
        expectedFence: await _currentFence(realStore),
        operationId: 'cmd-ack-sale',
        accountLineage: 'ack-lineage',
        saleId: 'sal-ack',
        journalId: 'jnl-sal-ack',
        draft: {
          'date': '2026-01-03',
          'discount': 0,
          'lines': [
            {'productId': 'p', 'quantity': 1},
          ],
        },
        recordedAt: '2026-01-03T12:00:00.000Z',
      );

      final result = await coordinator.executeSale(saleCmd);
      expect(
        result,
        isA<DurableCommandSuccess<RestaurantJournalSaleOutcome>>(),
      );
      expect(unknownStore.resolveCalls, greaterThanOrEqualTo(1));

      final readRes = await realStore.readDocument();
      final snap = (readRes as CapabilitySuccess<DocumentSnapshot?>).value!;
      expect(snap.revision, 2);
      final state = codec.decodeState(snap.payload);
      expect(state.receipts.length, 1);
      expect(state.receipts.first.identity.operationId, 'cmd-ack-sale');
    });
  });
}
