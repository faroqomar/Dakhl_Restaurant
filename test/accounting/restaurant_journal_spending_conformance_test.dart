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
import 'package:dakhl_restaurant/accounts/account_document.dart';
import 'package:dakhl_restaurant/accounts/legacy_account_codec.dart';
import 'package:dakhl_restaurant/accounts/portable_journal_codec.dart';
import 'package:dakhl_restaurant/accounts/portable_journal_state.dart';
import 'package:dakhl_restaurant/parties/purchase_proposal.dart';

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

  AccountDocument buildSampleAccount({
    int openingBalance = 10000,
    List<Map<String, Object?>> suppliers = const [],
    List<Map<String, Object?>> invoices = const [],
    List<Map<String, Object?>> payments = const [],
    List<Map<String, Object?>> debts = const [],
  }) {
    final oracle = jsonDecode(
      File('test/sales/sale_proposal_oracle.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final defaultCase = (oracle['cases'] as List).first as Map<String, dynamic>;
    final raw = Map<String, Object?>.from(
      defaultCase['state'] as Map<String, dynamic>,
    );
    raw['suppliers'] = [
      {
        'id': 'supp-1',
        'name': 'المورد الأول',
        'phone': '123456',
        'note': '',
        'categoryId': 'samoon',
        'openingBalance': openingBalance,
        'materials': <Map<String, Object?>>[
          {
            'id': 'mat-1',
            'name': 'Meat',
            'unit': 'kg',
            'price': 5000,
            'archived': false,
          },
          {
            'id': 'mat-flour',
            'name': 'Flour',
            'unit': 'bag',
            'price': 20000,
            'archived': false,
          },
        ],
      },
      ...suppliers,
    ];
    raw['invoices'] = invoices;
    raw['payments'] = payments;
    raw['debts'] = debts;
    return legacyCodec.decodeJson(raw);
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
            sourceRecordId: 'cutover-record',
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
      journals: [?openingEntry],
      receipts: const [],
    );
  }

  group('Restaurant Journal Spending Store Conformance', () {
    late Directory tempDir;
    final openStores = <PowerSyncLocalDocumentWorkspaceStore>[];

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp(
        'dakhl-spending-conformance-store-',
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

    test('atomic persistence of operating expense updates source, journals, and receipts', () async {
      final store = await openStore();
      final coordinator = RestaurantJournalSpendingCommandCoordinator(
        store: store,
        mapper: mapper,
        codec: codec,
      );

      final initialDoc = buildSampleAccount();
      final initialV12 = buildSyntheticState(
        account: initialDoc,
        accountLineage: 'conformance-spend-1',
      );

      final seedRes = await store.writeDocument(
        codec.encodeState(initialV12),
        writeToken: 'seed-token-1',
      );
      expect(seedRes, isA<CapabilitySuccess<DocumentSnapshot>>());

      final expenseCmd = CreateOperatingExpenseCommand(
        expectedFence: await _currentFence(store),
        operationId: 'cmd-exp-101',
        accountLineage: 'conformance-spend-1',
        expenseId: 'exp-101',
        journalId: 'jnl-exp-101',
        date: d('2026-01-03'),
        categoryId: 'samoon',
        amount: BigInt.from(12000),
        fundingSource: FundingSource.daily,
        recordedAt: '2026-01-03T12:00:00.000Z',
      );

      final result = await coordinator.executeExpense(expenseCmd);
      expect(
        result,
        isA<DurableCommandSuccess<RestaurantJournalSpendingOutcome>>(),
      );
      final success =
          result as DurableCommandSuccess<RestaurantJournalSpendingOutcome>;
      expect(success.outcome.expenseId, 'exp-101');
      expect(success.outcome.journalId, 'jnl-exp-101');
      expect(success.outcome.netAmount, '12000');
      expect(success.receipt.sequence, 1);
      expect(success.snapshot.revision, 2);

      // Verify readback from real persistent store
      final readRes = await store.readDocument();
      final snap = (readRes as CapabilitySuccess<DocumentSnapshot?>).value!;
      final state = codec.decodeState(snap.payload);

      expect(state.accountLineage, 'conformance-spend-1');
      final days = (state.account.toJson()['days'] as Map)
          .cast<String, Object?>();
      final dayMap = days['2026-01-03'] as Map<String, Object?>?;
      expect(dayMap, isNotNull);
      final expenses = (dayMap!['expenses'] as List)
          .cast<Map<String, Object?>>();
      expect(expenses.length, 1);
      expect(expenses.first['id'], 'exp-101');
      expect(expenses.first['amount'], 12000);

      expect(state.journals.length, 2); // opening + expense
      final expenseJournal = state.journals.last;
      expect(expenseJournal.sourceType, 'expense');
      expect(expenseJournal.sourceRecordId, 'exp-101');
      expect(
        expenseJournal.journal.lines[0].accountId,
        'expense:category:samoon',
      );
      expect(expenseJournal.journal.lines[0].side, JournalSide.debit);
      expect(expenseJournal.journal.lines[1].accountId, 'asset:cash:daily');
      expect(expenseJournal.journal.lines[1].side, JournalSide.credit);

      expect(state.receipts.length, 1);
      expect(state.receipts.first.identity.operationId, 'cmd-exp-101');

      // Cash register check
      final statement = DailyCashQueries(state.account).statement();
      expect(statement.total, BigInt.from(12000));
    });

    test('atomic persistence of purchase invoice with atomic immediate payment updates source, 2 journals, 1 receipt', () async {
      final store = await openStore();
      final coordinator = RestaurantJournalSpendingCommandCoordinator(
        store: store,
        mapper: mapper,
        codec: codec,
      );

      final initialDoc = buildSampleAccount();
      final initialV12 = buildSyntheticState(
        account: initialDoc,
        accountLineage: 'conformance-spend-inv',
      );

      await store.writeDocument(
        codec.encodeState(initialV12),
        writeToken: 'seed-token',
      );

      final invCmd = CreatePurchaseInvoiceCommand(
        expectedFence: await _currentFence(store),
        operationId: 'cmd-inv-atomic-1',
        accountLineage: 'conformance-spend-inv',
        invoiceId: 'inv-conf-1',
        invoiceJournalId: 'jnl-inv-conf-1',
        paymentJournalId: 'jnl-pay-conf-1',
        supplierId: 'supp-1',
        invoiceNumber: 'INV-CONF-1',
        date: d('2026-01-04'),
        lines: [
          const PurchaseLine(
            materialIdForCreation: 'mat-flour',
            name: 'Flour',
            unit: 'bag',
            quantityCartons: 2,
            quantityPieces: 0,
            priceCarton: 20000,
            pricePiece: 0,
          ),
        ],
        immediatePayment: const PurchasePayment(
          id: 'pay-conf-1',
          amount: 25000,
          source: 'daily',
        ),
        recordedAt: '2026-01-04T12:00:00.000Z',
      );

      final result = await coordinator.executeInvoice(invCmd);
      expect(
        result,
        isA<DurableCommandSuccess<RestaurantJournalSpendingOutcome>>(),
      );
      final success =
          result as DurableCommandSuccess<RestaurantJournalSpendingOutcome>;
      expect(success.outcome.invoiceId, 'inv-conf-1');
      expect(success.outcome.paymentId, 'pay-conf-1');
      expect(success.outcome.netAmount, '40000');
      expect(success.receipt.sequence, 1);
      expect(success.snapshot.revision, 2);

      // Verify readback from real persistent store
      final readRes = await store.readDocument();
      final snap = (readRes as CapabilitySuccess<DocumentSnapshot?>).value!;
      final state = codec.decodeState(snap.payload);

      expect(state.journals.length, 3); // opening + invoice + payment
      final invJournal = state.journals[1];
      expect(invJournal.sourceType, 'purchaseInvoice');
      expect(invJournal.journal.totalUnits, BigInt.from(40000));
      expect(invJournal.journal.lines[0].accountId, 'expense:purchases');
      expect(invJournal.journal.lines[0].side, JournalSide.debit);
      expect(
        invJournal.journal.lines[1].accountId,
        'liability:supplier:supp-1',
      );
      expect(invJournal.journal.lines[1].side, JournalSide.credit);

      final payJournal = state.journals[2];
      expect(payJournal.sourceType, 'supplierPayment');
      expect(payJournal.journal.totalUnits, BigInt.from(25000));
      expect(
        payJournal.journal.lines[0].accountId,
        'liability:supplier:supp-1',
      );
      expect(payJournal.journal.lines[0].side, JournalSide.debit);
      expect(payJournal.journal.lines[1].accountId, 'asset:cash:daily');
      expect(payJournal.journal.lines[1].side, JournalSide.credit);

      // Exactly ONE receipt for the entire atomic command
      expect(state.receipts.length, 1);
      expect(state.receipts.first.identity.operationId, 'cmd-inv-atomic-1');

      // Cash register check: only payment amount visible, never unpaid invoice remainder
      final statement = DailyCashQueries(state.account).statement();
      expect(statement.total, BigInt.from(25000));
      expect(statement.rows.single['amount'], 25000);
    });

    test('atomic persistence of unpaid purchase invoice creates 1 invoice journal and 0 cash entries', () async {
      final store = await openStore();
      final coordinator = RestaurantJournalSpendingCommandCoordinator(
        store: store,
        mapper: mapper,
        codec: codec,
      );

      final initialDoc = buildSampleAccount();
      final initialV12 = buildSyntheticState(
        account: initialDoc,
        accountLineage: 'conformance-spend-unpaid',
      );

      await store.writeDocument(
        codec.encodeState(initialV12),
        writeToken: 'seed-token',
      );

      final invCmd = CreatePurchaseInvoiceCommand(
        expectedFence: await _currentFence(store),
        operationId: 'cmd-inv-unpaid-1',
        accountLineage: 'conformance-spend-unpaid',
        invoiceId: 'inv-unpaid-1',
        invoiceJournalId: 'jnl-inv-unpaid-1',
        supplierId: 'supp-1',
        invoiceNumber: 'INV-UNPAID-1',
        date: d('2026-01-04'),
        lines: [
          const PurchaseLine(
            materialIdForCreation: 'mat-1',
            name: 'Meat',
            unit: 'kg',
            quantityCartons: 0,
            quantityPieces: 6,
            priceCarton: 0,
            pricePiece: 5000,
          ),
        ],
        recordedAt: '2026-01-04T12:00:00.000Z',
      );

      final result = await coordinator.executeInvoice(invCmd);
      expect(
        result,
        isA<DurableCommandSuccess<RestaurantJournalSpendingOutcome>>(),
      );

      final readRes = await store.readDocument();
      final snap = (readRes as CapabilitySuccess<DocumentSnapshot?>).value!;
      final state = codec.decodeState(snap.payload);

      expect(state.journals.length, 2); // opening + invoice
      expect(state.journals.last.sourceType, 'purchaseInvoice');
      expect(state.journals.last.journal.totalUnits, BigInt.from(30000));

      final statement = DailyCashQueries(state.account).statement();
      expect(statement.total, BigInt.zero);
      expect(statement.rows, isEmpty);
    });

    test('atomic persistence of separate supplier payment settles invoice liability and registers visible cash', () async {
      final store = await openStore();
      final coordinator = RestaurantJournalSpendingCommandCoordinator(
        store: store,
        mapper: mapper,
        codec: codec,
      );

      final initialDoc = buildSampleAccount();
      final initialV12 = buildSyntheticState(
        account: initialDoc,
        accountLineage: 'conformance-separate-pay',
      );

      await store.writeDocument(
        codec.encodeState(initialV12),
        writeToken: 'seed-token',
      );

      // 1. Post unpaid invoice for 30,000 IQD
      final invCmd = CreatePurchaseInvoiceCommand(
        expectedFence: await _currentFence(store),
        operationId: 'cmd-inv-for-pay',
        accountLineage: 'conformance-separate-pay',
        invoiceId: 'inv-for-pay-1',
        invoiceJournalId: 'jnl-inv-for-pay-1',
        supplierId: 'supp-1',
        invoiceNumber: 'INV-PAY-1',
        date: d('2026-01-04'),
        lines: [
          const PurchaseLine(
            materialIdForCreation: 'mat-1',
            name: 'Meat',
            unit: 'kg',
            quantityCartons: 0,
            quantityPieces: 6,
            priceCarton: 0,
            pricePiece: 5000,
          ),
        ],
        recordedAt: '2026-01-04T12:00:00.000Z',
      );

      final invRes = await coordinator.executeInvoice(invCmd);
      expect(
        invRes,
        isA<DurableCommandSuccess<RestaurantJournalSpendingOutcome>>(),
      );

      // 2. Separate supplier payment of 20,000 IQD settling invoice
      final payCmd = CreateSupplierPaymentCommand(
        expectedFence: await _currentFence(store),
        operationId: 'cmd-separate-pay-1',
        accountLineage: 'conformance-separate-pay',
        paymentId: 'pay-sep-1',
        journalId: 'jnl-pay-sep-1',
        supplierId: 'supp-1',
        invoiceId: 'inv-for-pay-1',
        date: d('2026-01-05'),
        amount: BigInt.from(20000),
        fundingSource: FundingSource.daily,
        recordedAt: '2026-01-05T12:00:00.000Z',
      );

      final payRes = await coordinator.executePayment(payCmd);
      expect(
        payRes,
        isA<DurableCommandSuccess<RestaurantJournalSpendingOutcome>>(),
      );
      final paySuccess =
          payRes as DurableCommandSuccess<RestaurantJournalSpendingOutcome>;
      expect(paySuccess.outcome.paymentId, 'pay-sep-1');
      expect(paySuccess.snapshot.revision, 3);

      final readRes = await store.readDocument();
      final snap = (readRes as CapabilitySuccess<DocumentSnapshot?>).value!;
      final state = codec.decodeState(snap.payload);

      expect(state.journals.length, 3); // opening + invoice + payment
      final payJournal = state.journals.last;
      expect(payJournal.sourceType, 'supplierPayment');
      expect(
        payJournal.journal.lines[0].accountId,
        'liability:supplier:supp-1',
      );
      expect(payJournal.journal.lines[0].side, JournalSide.debit);
      expect(payJournal.journal.lines[1].accountId, 'asset:cash:daily');
      expect(payJournal.journal.lines[1].side, JournalSide.credit);

      final statement = DailyCashQueries(state.account).statement();
      expect(statement.total, BigInt.from(20000));
    });

    test('idempotent replay returns DurableCommandReplayed without incrementing store revision', () async {
      final store = await openStore();
      final coordinator = RestaurantJournalSpendingCommandCoordinator(
        store: store,
        mapper: mapper,
        codec: codec,
      );

      final initialDoc = buildSampleAccount();
      final initialV12 = buildSyntheticState(
        account: initialDoc,
        accountLineage: 'spend-replay-lineage',
      );

      await store.writeDocument(
        codec.encodeState(initialV12),
        writeToken: 'seed-token',
      );

      final expenseCmd = CreateOperatingExpenseCommand(
        expectedFence: await _currentFence(store),
        operationId: 'cmd-replay-exp',
        accountLineage: 'spend-replay-lineage',
        expenseId: 'exp-replay',
        journalId: 'jnl-exp-replay',
        date: d('2026-01-03'),
        categoryId: 'samoon',
        amount: BigInt.from(5000),
        fundingSource: FundingSource.daily,
        recordedAt: '2026-01-03T12:00:00.000Z',
      );

      // First run: commits
      final result1 = await coordinator.executeExpense(expenseCmd);
      expect(
        result1,
        isA<DurableCommandSuccess<RestaurantJournalSpendingOutcome>>(),
      );
      final snap1 =
          (result1 as DurableCommandSuccess<RestaurantJournalSpendingOutcome>)
              .snapshot;
      expect(snap1.revision, 2);

      // Replay: exact same command
      final result2 = await coordinator.executeExpense(expenseCmd);
      expect(
        result2,
        isA<DurableCommandReplayed<RestaurantJournalSpendingOutcome>>(),
      );
      final replayed =
          result2 as DurableCommandReplayed<RestaurantJournalSpendingOutcome>;
      expect(replayed.snapshot.revision, 2); // No revision increment
      expect(replayed.receipt.identity.operationId, 'cmd-replay-exp');
      expect(replayed.outcome, isNotNull);
      expect(replayed.outcome!.expenseId, 'exp-replay');
      expect(replayed.outcome!.netAmount, '5000');

      // Verify store document revision remained 2
      final readRes = await store.readDocument();
      final currentSnap =
          (readRes as CapabilitySuccess<DocumentSnapshot?>).value!;
      expect(currentSnap.revision, 2);
    });

    test('tampered command with changed financial field on replay rejects with changed_payload_rejected', () async {
      final store = await openStore();
      final coordinator = RestaurantJournalSpendingCommandCoordinator(
        store: store,
        mapper: mapper,
        codec: codec,
      );

      final initialDoc = buildSampleAccount();
      final initialV12 = buildSyntheticState(
        account: initialDoc,
        accountLineage: 'spend-tamper-lineage',
      );

      await store.writeDocument(
        codec.encodeState(initialV12),
        writeToken: 'seed-token',
      );

      final originalCmd = CreateOperatingExpenseCommand(
        expectedFence: await _currentFence(store),
        operationId: 'cmd-tamper-exp',
        accountLineage: 'spend-tamper-lineage',
        expenseId: 'exp-tamper',
        journalId: 'jnl-exp-tamper',
        date: d('2026-01-03'),
        categoryId: 'samoon',
        amount: BigInt.from(5000),
        fundingSource: FundingSource.daily,
        recordedAt: '2026-01-03T12:00:00.000Z',
      );

      final result1 = await coordinator.executeExpense(originalCmd);
      expect(
        result1,
        isA<DurableCommandSuccess<RestaurantJournalSpendingOutcome>>(),
      );

      // Tampered replay with CHANGED amount (8000 instead of 5000)
      final tamperedCmd = CreateOperatingExpenseCommand(
        expectedFence: await _currentFence(store),
        operationId: 'cmd-tamper-exp', // same operationId
        accountLineage: 'spend-tamper-lineage',
        expenseId: 'exp-tamper',
        journalId: 'jnl-exp-tamper',
        date: d('2026-01-03'),
        categoryId: 'samoon',
        amount: BigInt.from(8000), // tampered!
        fundingSource: FundingSource.daily,
        recordedAt: '2026-01-03T12:00:00.000Z',
      );

      final result2 = await coordinator.executeExpense(tamperedCmd);
      expect(
        result2,
        isA<DurableCommandFailure<RestaurantJournalSpendingOutcome>>(),
      );
      final failure =
          result2 as DurableCommandFailure<RestaurantJournalSpendingOutcome>;
      expect(failure.code, DurableCommandErrorCodes.changedPayloadRejected);

      // Verify store document revision and state remained untouched
      final readRes = await store.readDocument();
      final snap = (readRes as CapabilitySuccess<DocumentSnapshot?>).value!;
      expect(snap.revision, 2);
      final state = codec.decodeState(snap.payload);
      expect(state.receipts.length, 1);
      expect(state.journals.last.metadata['amount'], '5000');
    });

    test(
      'replaying with changed payload version rejects without writes',
      () async {
        final store = await openStore();
        final coordinator = RestaurantJournalSpendingCommandCoordinator(
          store: store,
          mapper: mapper,
          codec: codec,
        );

        final initialDoc = buildSampleAccount();
        final initialV12 = buildSyntheticState(
          account: initialDoc,
          accountLineage: 'spend-version-lineage',
        );

        await store.writeDocument(
          codec.encodeState(initialV12),
          writeToken: 'seed-token',
        );

        final cmdV1 = CreateOperatingExpenseCommand(
          expectedFence: await _currentFence(store),
          operationId: 'cmd-ver-exp',
          payloadVersion: 1,
          accountLineage: 'spend-version-lineage',
          expenseId: 'exp-ver',
          journalId: 'jnl-exp-ver',
          date: d('2026-01-03'),
          categoryId: 'samoon',
          amount: BigInt.from(5000),
          fundingSource: FundingSource.daily,
          recordedAt: '2026-01-03T12:00:00.000Z',
        );

        await coordinator.executeExpense(cmdV1);

        // Replay with payloadVersion: 2
        final cmdV2 = CreateOperatingExpenseCommand(
          expectedFence: await _currentFence(store),
          operationId: 'cmd-ver-exp',
          payloadVersion: 2, // Changed!
          accountLineage: 'spend-version-lineage',
          expenseId: 'exp-ver',
          journalId: 'jnl-exp-ver',
          date: d('2026-01-03'),
          categoryId: 'samoon',
          amount: BigInt.from(5000),
          fundingSource: FundingSource.daily,
          recordedAt: '2026-01-03T12:00:00.000Z',
        );

        final result = await coordinator.executeExpense(cmdV2);
        expect(
          result,
          isA<DurableCommandFailure<RestaurantJournalSpendingOutcome>>(),
        );
        final failure =
            result as DurableCommandFailure<RestaurantJournalSpendingOutcome>;
        expect(failure.code, DurableCommandErrorCodes.changedPayloadRejected);
      },
    );

    test('account lineage mismatch is checked before replay and rejects without executing', () async {
      final store = await openStore();
      final coordinator = RestaurantJournalSpendingCommandCoordinator(
        store: store,
        mapper: mapper,
        codec: codec,
      );

      final initialDoc = buildSampleAccount();
      final initialV12 = buildSyntheticState(
        account: initialDoc,
        accountLineage: 'store-spending-lineage',
      );

      await store.writeDocument(
        codec.encodeState(initialV12),
        writeToken: 'seed-token',
      );

      final cmdWrongLineage = CreateOperatingExpenseCommand(
        expectedFence: await _currentFence(store),
        operationId: 'cmd-wrong-spend-lineage',
        accountLineage: 'foreign-spending-lineage', // mismatch!
        expenseId: 'exp-wrong',
        journalId: 'jnl-exp-wrong',
        date: d('2026-01-03'),
        categoryId: 'samoon',
        amount: BigInt.from(5000),
        fundingSource: FundingSource.daily,
        recordedAt: '2026-01-03T12:00:00.000Z',
      );

      final result = await coordinator.executeExpense(cmdWrongLineage);
      expect(
        result,
        isA<DurableCommandFailure<RestaurantJournalSpendingOutcome>>(),
      );
      final failure =
          result as DurableCommandFailure<RestaurantJournalSpendingOutcome>;
      expect(
        failure.code,
        RestaurantJournalSpendingErrorCodes.accountLineageMismatch,
      );

      final snap =
          ((await store.readDocument()) as CapabilitySuccess<DocumentSnapshot?>)
              .value!;
      expect(snap.revision, 1);
    });

    test(
      'stale expected storage fence rejects command with stale_authority_fence',
      () async {
        final store = await openStore();
        final coordinator = RestaurantJournalSpendingCommandCoordinator(
          store: store,
          mapper: mapper,
          codec: codec,
        );

        final initialDoc = buildSampleAccount();
        final initialV12 = buildSyntheticState(
          account: initialDoc,
          accountLineage: 'spend-fence-lineage',
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
        final cmdStaleFence = CreateOperatingExpenseCommand(
          operationId: 'cmd-stale-spend-fence',
          accountLineage: 'spend-fence-lineage',
          expectedFence: originalFence, // Stale!
          expenseId: 'exp-stale',
          journalId: 'jnl-exp-stale',
          date: d('2026-01-03'),
          categoryId: 'samoon',
          amount: BigInt.from(5000),
          fundingSource: FundingSource.daily,
          recordedAt: '2026-01-03T12:00:00.000Z',
        );

        final result = await coordinator.executeExpense(cmdStaleFence);
        expect(
          result,
          isA<DurableCommandFailure<RestaurantJournalSpendingOutcome>>(),
        );
        final fail =
            result as DurableCommandFailure<RestaurantJournalSpendingOutcome>;
        expect(fail.code, DurableCommandErrorCodes.staleAuthorityFence);
      },
    );

    test(
      'rejection paths leave store revision and payload completely unchanged',
      () async {
        final store = await openStore();
        final coordinator = RestaurantJournalSpendingCommandCoordinator(
          store: store,
          mapper: mapper,
          codec: codec,
        );

        // Seed a gated state (refuses posting)
        final initialDoc = buildSampleAccount();
        final gatedState = buildSyntheticState(
          account: initialDoc,
          accountLineage: 'gated-spend-lineage',
          isGated: true,
        );

        final seedRes = await store.writeDocument(
          codec.encodeState(gatedState),
          writeToken: 'seed-token',
        );
        final seedSnap = (seedRes as CapabilitySuccess<DocumentSnapshot>).value;

        final cmd = CreateOperatingExpenseCommand(
          expectedFence: await _currentFence(store),
          operationId: 'cmd-gated-spend',
          accountLineage: 'gated-spend-lineage',
          expenseId: 'exp-gated',
          journalId: 'jnl-exp-gated',
          date: d('2026-01-03'),
          categoryId: 'samoon',
          amount: BigInt.from(5000),
          fundingSource: FundingSource.daily,
          recordedAt: '2026-01-03T12:00:00.000Z',
        );

        final result = await coordinator.executeExpense(cmd);
        expect(
          result,
          isA<DurableCommandFailure<RestaurantJournalSpendingOutcome>>(),
        );
        final fail =
            result as DurableCommandFailure<RestaurantJournalSpendingOutcome>;
        expect(fail.code, RestaurantJournalSpendingErrorCodes.cutoverGated);

        // Document revision and payload MUST be unchanged!
        final afterSnap =
            ((await store.readDocument())
                    as CapabilitySuccess<DocumentSnapshot?>)
                .value!;
        expect(afterSnap.revision, seedSnap.revision);
        expect(afterSnap.payload, seedSnap.payload);
      },
    );

    test('real store close and reopen preserves complete state, journals, and receipts', () async {
      final store = await openStore();
      final coordinator = RestaurantJournalSpendingCommandCoordinator(
        store: store,
        mapper: mapper,
        codec: codec,
      );

      final initialDoc = buildSampleAccount();
      final initialV12 = buildSyntheticState(
        account: initialDoc,
        accountLineage: 'reopen-spend-lineage',
      );

      await store.writeDocument(
        codec.encodeState(initialV12),
        writeToken: 'seed-token',
      );

      final expenseCmd = CreateOperatingExpenseCommand(
        expectedFence: await _currentFence(store),
        operationId: 'cmd-reopen-spend',
        accountLineage: 'reopen-spend-lineage',
        expenseId: 'exp-reopen',
        journalId: 'jnl-exp-reopen',
        date: d('2026-01-03'),
        categoryId: 'samoon',
        amount: BigInt.from(7500),
        fundingSource: FundingSource.daily,
        recordedAt: '2026-01-03T12:00:00.000Z',
      );

      final res = await coordinator.executeExpense(expenseCmd);
      expect(
        res,
        isA<DurableCommandSuccess<RestaurantJournalSpendingOutcome>>(),
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
      expect(reopenedState.accountLineage, 'reopen-spend-lineage');
      expect(reopenedState.journals.length, 2);
      expect(reopenedState.receipts.length, 1);
      expect(
        reopenedState.receipts.first.identity.operationId,
        'cmd-reopen-spend',
      );
      expect(reopenedState.journals.last.metadata['amount'], '7500');

      // Replay against reopened store works seamlessly
      final reopenedCoordinator = RestaurantJournalSpendingCommandCoordinator(
        store: reopenedStore,
        mapper: mapper,
        codec: codec,
      );
      final replayRes = await reopenedCoordinator.executeExpense(expenseCmd);
      expect(
        replayRes,
        isA<DurableCommandReplayed<RestaurantJournalSpendingOutcome>>(),
      );
      final replayed =
          replayRes as DurableCommandReplayed<RestaurantJournalSpendingOutcome>;
      expect(replayed.snapshot.revision, 2);
      expect(replayed.outcome!.netAmount, '7500');
    });

    test('uncertain acknowledgement resolves pending write and succeeds without duplicate commits', () async {
      final realStore = await openStore();
      final unknownStore = UnknownAckStore(realStore);
      final coordinator = RestaurantJournalSpendingCommandCoordinator(
        store: unknownStore,
        mapper: mapper,
        codec: codec,
      );

      final initialDoc = buildSampleAccount();
      final initialV12 = buildSyntheticState(
        account: initialDoc,
        accountLineage: 'ack-spend-lineage',
      );

      await unknownStore.writeDocument(
        codec.encodeState(initialV12),
        writeToken: 'seed-token',
      );

      // Inject unknown on initial read
      unknownStore.injectUnknownRead = true;

      final expenseCmd = CreateOperatingExpenseCommand(
        expectedFence: await _currentFence(realStore),
        operationId: 'cmd-ack-spend',
        accountLineage: 'ack-spend-lineage',
        expenseId: 'exp-ack',
        journalId: 'jnl-exp-ack',
        date: d('2026-01-03'),
        categoryId: 'samoon',
        amount: BigInt.from(9000),
        fundingSource: FundingSource.daily,
        recordedAt: '2026-01-03T12:00:00.000Z',
      );

      final result = await coordinator.executeExpense(expenseCmd);
      expect(
        result,
        isA<DurableCommandSuccess<RestaurantJournalSpendingOutcome>>(),
      );
      expect(unknownStore.resolveCalls, greaterThanOrEqualTo(1));

      final readRes = await realStore.readDocument();
      final snap = (readRes as CapabilitySuccess<DocumentSnapshot?>).value!;
      expect(snap.revision, 2);
      final state = codec.decodeState(snap.payload);
      expect(state.receipts.length, 1);
      expect(state.receipts.first.identity.operationId, 'cmd-ack-spend');
    });

    test('mixed sales and spending operations on the same store maintain mutual isolation and full compatibility', () async {
      final store = await openStore();
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

      final initialDoc = buildSampleAccount();
      final initialV12 = buildSyntheticState(
        account: initialDoc,
        accountLineage: 'mixed-lifecycle-lineage',
      );

      await store.writeDocument(
        codec.encodeState(initialV12),
        writeToken: 'seed-token',
      );

      // 1. Execute Sales Command: CompleteSale
      final saleCmd = CompleteSaleCommand(
        expectedFence: await _currentFence(store),
        operationId: 'cmd-mixed-sale',
        accountLineage: 'mixed-lifecycle-lineage',
        saleId: 'sal-mix-1',
        journalId: 'jnl-sal-mix-1',
        draft: {
          'date': '2026-01-03',
          'discount': 0,
          'lines': [
            {'productId': 'p', 'quantity': 5, 'price': 1000},
          ],
        },
        recordedAt: '2026-01-03T12:00:00.000Z',
      );
      final saleRes = await salesCoordinator.executeSale(saleCmd);
      expect(
        saleRes,
        isA<DurableCommandSuccess<RestaurantJournalSaleOutcome>>(),
      );
      final saleSuccess =
          saleRes as DurableCommandSuccess<RestaurantJournalSaleOutcome>;
      expect(saleSuccess.receipt.sequence, 1);
      expect(saleSuccess.snapshot.revision, 2);

      // 2. Execute Spending Command: CreateOperatingExpense
      final expCmd = CreateOperatingExpenseCommand(
        expectedFence: await _currentFence(store),
        operationId: 'cmd-mixed-exp',
        accountLineage: 'mixed-lifecycle-lineage',
        expenseId: 'exp-mix-1',
        journalId: 'jnl-exp-mix-1',
        date: d('2026-01-03'),
        categoryId: 'samoon',
        amount: BigInt.from(2000),
        fundingSource: FundingSource.daily,
        recordedAt: '2026-01-03T13:00:00.000Z',
      );
      final expRes = await spendingCoordinator.executeExpense(expCmd);
      expect(
        expRes,
        isA<DurableCommandSuccess<RestaurantJournalSpendingOutcome>>(),
      );
      final expSuccess =
          expRes as DurableCommandSuccess<RestaurantJournalSpendingOutcome>;
      expect(expSuccess.receipt.sequence, 2);
      expect(expSuccess.snapshot.revision, 3);

      // 3. Execute Spending Command: CreatePurchaseInvoice with immediate payment
      final invCmd = CreatePurchaseInvoiceCommand(
        expectedFence: await _currentFence(store),
        operationId: 'cmd-mixed-inv',
        accountLineage: 'mixed-lifecycle-lineage',
        invoiceId: 'inv-mix-1',
        invoiceJournalId: 'jnl-inv-mix-1',
        paymentJournalId: 'jnl-pay-mix-1',
        supplierId: 'supp-1',
        invoiceNumber: 'INV-MIX-1',
        date: d('2026-01-04'),
        lines: [
          const PurchaseLine(
            materialIdForCreation: 'mat-flour',
            name: 'Flour',
            unit: 'bag',
            quantityCartons: 1,
            quantityPieces: 0,
            priceCarton: 20000,
            pricePiece: 0,
          ),
        ],
        immediatePayment: const PurchasePayment(
          id: 'pay-mix-1',
          amount: 15000,
          source: 'daily',
        ),
        recordedAt: '2026-01-04T12:00:00.000Z',
      );
      final invRes = await spendingCoordinator.executeInvoice(invCmd);
      expect(
        invRes,
        isA<DurableCommandSuccess<RestaurantJournalSpendingOutcome>>(),
      );
      final invSuccess =
          invRes as DurableCommandSuccess<RestaurantJournalSpendingOutcome>;
      expect(invSuccess.receipt.sequence, 3);
      expect(invSuccess.snapshot.revision, 4);

      // 4. Execute Spending Command: Separate Supplier Payment settling remaining 5,000 IQD
      final payCmd = CreateSupplierPaymentCommand(
        expectedFence: await _currentFence(store),
        operationId: 'cmd-mixed-pay',
        accountLineage: 'mixed-lifecycle-lineage',
        paymentId: 'pay-mix-2',
        journalId: 'jnl-pay-mix-2',
        supplierId: 'supp-1',
        invoiceId: 'inv-mix-1',
        date: d('2026-01-05'),
        amount: BigInt.from(5000),
        fundingSource: FundingSource.daily,
        recordedAt: '2026-01-05T12:00:00.000Z',
      );
      final payRes = await spendingCoordinator.executePayment(payCmd);
      expect(
        payRes,
        isA<DurableCommandSuccess<RestaurantJournalSpendingOutcome>>(),
      );
      final paySuccess =
          payRes as DurableCommandSuccess<RestaurantJournalSpendingOutcome>;
      expect(paySuccess.receipt.sequence, 4);
      expect(paySuccess.snapshot.revision, 5);

      // Verify complete reconcilability across both sales and spending!
      final readRes = await store.readDocument();
      final snap = (readRes as CapabilitySuccess<DocumentSnapshot?>).value!;
      expect(snap.revision, 5);
      final state = codec.decodeState(snap.payload);

      // Receipts: 4 receipts in monotonically increasing sequence
      expect(state.receipts.length, 4);
      expect(state.receipts.map((r) => r.sequence).toList(), [1, 2, 3, 4]);
      expect(state.receipts.map((r) => r.identity.operationId).toList(), [
        'cmd-mixed-sale',
        'cmd-mixed-exp',
        'cmd-mixed-inv',
        'cmd-mixed-pay',
      ]);

      // Journals: opening + sale (1) + expense (1) + invoice (1) + invoice immediate payment (1) + supplier payment (1) = 6 journals
      expect(state.journals.length, 6);
      expect(state.journals.map((j) => j.sourceType).toList(), [
        RestaurantJournalSourceType.cutoverOpening.name,
        'sale',
        'expense',
        'purchaseInvoice',
        'supplierPayment',
        'supplierPayment',
      ]);

      // Replaying any of them works and does NOT increment revision
      final replaySaleRes = await salesCoordinator.executeSale(saleCmd);
      expect(
        replaySaleRes,
        isA<DurableCommandReplayed<RestaurantJournalSaleOutcome>>(),
      );

      final replayExpRes = await spendingCoordinator.executeExpense(expCmd);
      expect(
        replayExpRes,
        isA<DurableCommandReplayed<RestaurantJournalSpendingOutcome>>(),
      );

      final finalRead = await store.readDocument();
      expect(
        (finalRead as CapabilitySuccess<DocumentSnapshot?>).value!.revision,
        5,
      );
    });
  });
}
