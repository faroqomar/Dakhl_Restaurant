import 'dart:convert';
import 'dart:io';

import 'package:dakhl_restaurant/accounting/daily_cash_queries.dart';
import 'package:dakhl_restaurant/accounting/restaurant_journal_mapper.dart';
import 'package:dakhl_restaurant/accounting/restaurant_journal_sale_commands.dart';
import 'package:dakhl_restaurant/accounting/restaurant_journal_spending_commands.dart';
import 'package:dakhl_restaurant/accounts/legacy_account_codec.dart';
import 'package:dakhl_restaurant/accounts/portable_journal_codec.dart';
import 'package:dakhl_restaurant/accounts/portable_journal_state.dart';
import 'package:dakhl_restaurant/catalog/catalog_stock_history.dart';
import 'package:dakhl_restaurant/parties/purchase_proposal.dart';
import 'package:dakhl_restaurant/parties/supplier_ledger.dart';
import 'package:dakhl_restaurant/sales/return_proposal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar_application/madar_application.dart';
import 'package:madar_data/madar_data.dart';
import 'package:madar_domain/madar_domain.dart';

import 'restaurant_journal_sale_conformance_test.dart' show UnknownAckStore;

// Durable acceptance tests. All data is synthetic. These deterministic SDK
// checkpoint faults establish only the named transaction/acknowledgement bounds.
const _codec = PortableJournalCodec();
const _at = '2026-01-05T12:00:00.000Z';
DateOnly _date(String value) =>
    DateOnly.parse(value, minimumYear: 1000, maximumYear: 9999);

T _value<T>(CapabilityResult<T> result) {
  expect(result, isA<CapabilitySuccess<T>>());
  return (result as CapabilitySuccess<T>).value;
}

PortableJournalState _initialState() {
  final oracle = jsonDecode(
    File('test/sales/sale_proposal_oracle.json').readAsStringSync(),
  ) as Map<String, Object?>;
  final raw = Map<String, Object?>.from(
    ((oracle['cases'] as List).first as Map)['state'] as Map,
  );
  raw['suppliers'] = [
    {
      'id': 'supplier',
      'name': 'Synthetic supplier',
      'phone': '',
      'note': '',
      'categoryId': 'samoon',
      'openingBalance': 0,
      'materials': <Map<String, Object?>>[],
    },
  ];
  return PortableJournalState(
    accountLineage: 'atomicity-fixture',
    account: const LegacyAccountCodec().decodeJson(raw),
    sourceProvenance: const PortableJournalSourceProvenance(
      sourceVersion: 11,
      enrolledAt: '2026-01-01T00:00:00.000Z',
      migrated: false,
    ),
    cutoverState: PortableJournalCutoverState.established(
      cutoverDate: _date('2026-01-01'),
      openingJournalId: 'opening-journal',
    ),
    journals: [
      PortableJournalEntry(
        journal: BalancedJournal.validate(
          id: 'opening-journal',
          effectiveDate: _date('2026-01-01'),
          policy: RestaurantJournalPolicies.opening,
          lines: [
            JournalLine(
              accountId: 'asset:cash:daily',
              side: JournalSide.debit,
              amountUnits: BigInt.from(10000),
              currency: 'IQD',
              scale: 0,
            ),
            JournalLine(
              accountId: 'equity:opening_balance',
              side: JournalSide.credit,
              amountUnits: BigInt.from(10000),
              currency: 'IQD',
              scale: 0,
            ),
          ],
        ),
        sourceType: 'cutoverOpening',
        sourceRecordId: 'synthetic-opening',
        recordedAt: '2026-01-01T00:00:00.000Z',
      ),
    ],
    receipts: const [],
  );
}

CompleteSaleCommand _sale(StorageFence fence, {bool changed = false}) =>
    CompleteSaleCommand(
      operationId: 'sale-op',
      accountLineage: 'atomicity-fixture',
      expectedFence: fence,
      saleId: 'sale',
      journalId: 'sale-journal',
      recordedAt: _at,
      draft: {
        'date': '2026-01-03',
        'discount': changed ? 1 : 0,
        'lines': [
          {'productId': 'p', 'quantity': 2},
        ],
      },
    );

CreatePurchaseInvoiceCommand _invoice(
  StorageFence fence, {
  bool changed = false,
}) => CreatePurchaseInvoiceCommand(
  operationId: 'invoice-op',
  accountLineage: 'atomicity-fixture',
  expectedFence: fence,
  invoiceId: 'invoice',
  invoiceJournalId: 'invoice-journal',
  paymentJournalId: 'inline-payment-journal',
  supplierId: 'supplier',
  invoiceNumber: changed ? 'CHANGED' : 'SYNTHETIC-1',
  date: _date('2026-01-04'),
  lines: const [
    PurchaseLine(
      materialIdForCreation: 'inline-material',
      name: 'Synthetic flour',
      unit: 'bag',
      quantityCartons: 2,
      quantityPieces: 2,
      priceCarton: 2000,
      pricePiece: 100,
    ),
  ],
  immediatePayment: const PurchasePayment(
    id: 'inline-payment',
    amount: 1500,
    source: 'shared',
    dailyAmount: 900,
    cashAmount: 600,
  ),
  recordedAt: _at,
);

Object _command(String kind, StorageFence fence, {bool changed = false}) =>
    switch (kind) {
      'sale' => _sale(fence, changed: changed),
      'return' => SaleReturnCommand(
        operationId: 'return-op',
        accountLineage: 'atomicity-fixture',
        expectedFence: fence,
        saleId: 'sale',
        returnId: 'return',
        journalId: 'return-journal',
        returnDate: _date('2026-01-05'),
        today: _date('2026-01-05'),
        reason: changed ? 'Changed intent' : 'Synthetic return',
        recordedAt: _at,
        lines: [
          ReturnLineRequest(
            productId: 'p',
            quantityUnits: BigInt.from(1000),
            restock: true,
          ),
        ],
      ),
      'void' => SaleVoidCommand(
        operationId: 'void-op',
        accountLineage: 'atomicity-fixture',
        expectedFence: fence,
        saleId: 'sale',
        reversalJournalId: 'void-journal',
        voidRecordId: 'void',
        reason: changed ? 'Changed intent' : 'Synthetic void',
        voidedAt: _at,
      ),
      'expense' => CreateOperatingExpenseCommand(
        operationId: 'expense-op',
        accountLineage: 'atomicity-fixture',
        expectedFence: fence,
        expenseId: 'expense',
        journalId: 'expense-journal',
        date: _date('2026-01-05'),
        categoryId: 'samoon',
        amount: BigInt.from(1200),
        fundingSource: FundingSource.shared,
        dailyAmount: BigInt.from(700),
        cashAmount: BigInt.from(500),
        note: changed ? 'Changed intent' : 'Synthetic expense',
        recordedAt: _at,
      ),
      'invoice' => _invoice(fence, changed: changed),
      'payment' => CreateSupplierPaymentCommand(
        operationId: 'payment-op',
        accountLineage: 'atomicity-fixture',
        expectedFence: fence,
        paymentId: 'payment',
        journalId: 'payment-journal',
        supplierId: 'supplier',
        invoiceId: 'invoice',
        date: _date('2026-01-05'),
        amount: BigInt.from(1200),
        fundingSource: FundingSource.shared,
        dailyAmount: BigInt.from(700),
        cashAmount: BigInt.from(500),
        note: changed ? 'Changed intent' : 'Synthetic payment',
        recordedAt: _at,
      ),
      _ => throw StateError(kind),
    };

Future<DurableCommandResult<Object>> _execute(
  LocalDocumentWorkspaceStore store,
  Object command,
) => switch (command) {
  RestaurantJournalSaleCommand() => RestaurantJournalSaleCommandCoordinator(
    store: store,
  ).execute(command),
  RestaurantJournalSpendingCommand() =>
    RestaurantJournalSpendingCommandCoordinator(store: store).execute(command),
  _ => throw StateError('Unsupported test command'),
};

Future<DocumentSnapshot> _snapshot(LocalDocumentWorkspaceStore store) async =>
    _value<DocumentSnapshot?>(await store.readDocument())!;

List<Map<String, Object?>> _rows(PortableJournalState state, String key) =>
    (state.account.toJson()[key] as List).cast<Map<String, Object?>>();

BigInt _net(PortableJournalState state, String accountId) => state.journals
    .expand((entry) => entry.journal.lines)
    .where((line) => line.accountId == accountId)
    .fold(
      BigInt.zero,
      (sum, line) =>
          sum +
          (line.side == JournalSide.debit
              ? line.amountUnits
              : -line.amountUnits),
    );

BigInt _stock(PortableJournalState state) => CatalogStockHistory.compose(
  state.account,
  productId: 'p',
  today: _date('2026-01-06'),
).last.runningBalanceUnits;

// Literal fixture expectations: no production proposal/query builds expected rows.
Map<String, Object?> _expectedAccount(
  String kind,
  PortableJournalState before,
) {
  final expected =
      jsonDecode(jsonEncode(before.account.toJson())) as Map<String, dynamic>;
  final payment = <String, Object?>{
    'id': kind == 'invoice' ? 'inline-payment' : 'payment',
    'supplierId': 'supplier',
    'invoiceId': 'invoice',
    'categoryId': 'samoon',
    'date': kind == 'invoice' ? '2026-01-04' : '2026-01-05',
    'amount': kind == 'invoice' ? 1500 : 1200,
    'invoiceAmount': kind == 'invoice' ? 1500 : 1200,
    'debtAmount': 0,
    'funding': {
      'source': 'shared',
      'dailyAmount': kind == 'invoice' ? 900 : 700,
      'cashAmount': kind == 'invoice' ? 600 : 500,
    },
    'note': kind == 'invoice' ? '' : 'Synthetic payment',
    'createdAt': _at,
  };
  switch (kind) {
    case 'sale':
      (expected['sales'] as List).add({
        'id': 'sale',
        'number': 'S-000001',
        'date': '2026-01-03',
        'status': 'completed',
        'orderType': 'صالة',
        'discount': 0,
        'paid': 2000,
        'note': '',
        'createdAt': _at,
        'lines': [
          {
            'productId': 'p',
            'name': 'صنف',
            'unit': 'قطعة',
            'trackStock': true,
            'price': 1000,
            'quantity': 2,
          },
        ],
      });
    case 'return':
      (expected['saleReturns'] as List).add({
        'id': 'return',
        'saleId': 'sale',
        'date': '2026-01-05',
        'reason': 'Synthetic return',
        'createdAt': _at,
        'amount': 1000,
        'lines': [
          {'productId': 'p', 'quantity': 1, 'restock': true, 'amount': 1000},
        ],
      });
    case 'void':
      final sale = (expected['sales'] as List).single as Map;
      sale['status'] = 'void';
      sale['voidReason'] = 'Synthetic void';
      sale['voidedAt'] = _at;
    case 'expense':
      (expected['days'] as Map)['2026-01-05'] = {
        'expenses': [
          {
            'id': 'expense',
            'categoryId': 'samoon',
            'amount': 1200,
            'note': 'Synthetic expense',
            'createdAt': _at,
            'funding': {
              'source': 'shared',
              'dailyAmount': 700,
              'cashAmount': 500,
            },
          },
        ],
        'chickenUsed': 0,
        'chickenLeft': 0,
        'balance': null,
        'totalOverride': null,
        'remaining': null,
      };
    case 'invoice':
      (expected['materials'] as List).add({
        'id': 'inline-material',
        'name': 'Synthetic flour',
        'unit': 'bag',
        'priceCarton': 2000,
        'pricePiece': 100,
        'archived': false,
      });
      (expected['invoices'] as List).add({
        'id': 'invoice',
        'supplierId': 'supplier',
        'number': 'SYNTHETIC-1',
        'date': '2026-01-04',
        'createdAt': _at,
        'note': '',
        'lines': [
          {
            'materialId': 'inline-material',
            'name': 'Synthetic flour',
            'unit': 'bag',
            'quantityCartons': 2,
            'quantityPieces': 2,
            'priceCarton': 2000,
            'pricePiece': 100,
            'quantity': 2,
            'price': 100,
          },
        ],
      });
      (expected['payments'] as List).add(payment);
    case 'payment':
      (expected['payments'] as List).add(payment);
    default:
      throw StateError(kind);
  }
  return expected;
}

List<List<(String, String, String)>> _expectedLines(String kind) =>
    switch (kind) {
      'sale' => [
        [
          ('asset:cash:daily', 'debit', '2000'),
          ('revenue:sales', 'credit', '2000'),
        ],
      ],
      'return' => [
        [
          ('contra_revenue:sales_return', 'debit', '1000'),
          ('asset:cash:daily', 'credit', '1000'),
        ],
      ],
      'void' => [
        [
          ('asset:cash:daily', 'credit', '2000'),
          ('revenue:sales', 'debit', '2000'),
        ],
      ],
      'expense' => [
        [
          ('expense:category:samoon', 'debit', '1200'),
          ('asset:cash:daily', 'credit', '700'),
          ('asset:cash:cashbox', 'credit', '500'),
        ],
      ],
      'invoice' => [
        [
          ('expense:purchases', 'debit', '4200'),
          ('liability:supplier:supplier', 'credit', '4200'),
        ],
        [
          ('liability:supplier:supplier', 'debit', '1500'),
          ('asset:cash:daily', 'credit', '900'),
          ('asset:cash:cashbox', 'credit', '600'),
        ],
      ],
      'payment' => [
        [
          ('liability:supplier:supplier', 'debit', '1200'),
          ('asset:cash:daily', 'credit', '700'),
          ('asset:cash:cashbox', 'credit', '500'),
        ],
      ],
      _ => throw StateError(kind),
    };

void _assertCommitted(
  String kind,
  PortableJournalState before,
  PortableJournalState after,
) {
  final extraJournals = kind == 'invoice' ? 2 : 1;
  final actualAccount = after.account.toJson();
  final expectedAccount = _expectedAccount(kind, before);
  expect(actualAccount.keys, unorderedEquals(expectedAccount.keys));
  for (final key in expectedAccount.keys) {
    expect(
      actualAccount[key],
      expectedAccount[key],
      reason: '$kind complete source field $key and retained prior rows',
    );
  }
  expect(after.receipts.length, before.receipts.length + 1);
  expect(after.journals.length, before.journals.length + extraJournals);
  expect(after.receipts.last.identity.operationId, '$kind-op');
  expect(after.receipts.last.sequence, before.receipts.length + 1);
  expect(after.receipts.last.status, DurableCommandStatus.committed);
  expect(after.receipts.last.outcomePayload, isNotEmpty);
  final outcome = jsonDecode(after.receipts.last.outcomePayload!) as Map;
  expect(outcome['operationId'], '$kind-op');
  expect(
    outcome['journalId'],
    kind == 'invoice' ? 'invoice-journal' : '$kind-journal',
  );
  expect(outcome['netAmount'], switch (kind) {
    'sale' || 'void' => '2000',
    'return' => '1000',
    'invoice' => '4200',
    _ => '1200',
  });
  if (kind == 'invoice') {
    expect(outcome['paymentJournalId'], 'inline-payment-journal');
    expect(outcome['paymentId'], 'inline-payment');
  }
  for (final key in [
    'categories',
    'products',
    'stockEntries',
    'preferences',
    'transactions',
    'transfers',
    'workers',
    'savingsEntries',
    'debts',
  ]) {
    expect(
      after.account.toJson()[key],
      before.account.toJson()[key],
      reason: key,
    );
  }
  // Assert exact old journal/receipt preservation, including original outcomes.
  for (var i = 0; i < before.journals.length; i++) {
    expect(after.journals[i].toJson(), before.journals[i].toJson());
  }
  for (var i = 0; i < before.receipts.length; i++) {
    expect(after.receipts[i], before.receipts[i]);
  }
  final expectedDelta = switch (kind) {
    'sale' => (2000, 0, 0, -2000),
    'return' => (-1000, 0, 0, 1000),
    'void' => (-2000, 0, 0, 2000),
    'expense' => (-700, -500, 0, 0),
    'invoice' => (-900, -600, -2700, 0),
    'payment' => (-700, -500, 1200, 0),
    _ => throw StateError(kind),
  };
  for (final (id, delta) in [
    ('asset:cash:daily', expectedDelta.$1),
    ('asset:cash:cashbox', expectedDelta.$2),
    ('liability:supplier:supplier', expectedDelta.$3),
    ('revenue:sales', expectedDelta.$4),
  ]) {
    // Return contra revenue has its own account, rather than sales revenue.
    if (kind == 'return' && id == 'revenue:sales') continue;
    expect(_net(after, id) - _net(before, id), BigInt.from(delta), reason: id);
  }
  final added = after.journals.skip(before.journals.length).toList();
  final expectedIds = switch (kind) {
    'invoice' => ['invoice-journal', 'inline-payment-journal'],
    _ => ['$kind-journal'],
  };
  expect(added.map((entry) => entry.journal.id), expectedIds);
  final expectedLines = _expectedLines(kind);
  for (var i = 0; i < added.length; i++) {
    expect(
      added[i].journal.lines.map(
        (l) => (l.accountId, l.side.name, l.amountUnits.toString()),
      ),
      unorderedEquals(expectedLines[i]),
      reason: '$kind literal complete journal lines',
    );
    expect(
      added[i].journal.lines.every((l) => l.currency == 'IQD' && l.scale == 0),
      isTrue,
    );
  }
  switch (kind) {
    case 'sale':
      expect(_rows(after, 'sales').single['id'], 'sale');
      expect(_stock(after), BigInt.from(3000));
      expect(added.single.sourceRecordId, 'sale');
    case 'return':
      expect(_rows(after, 'saleReturns').single['id'], 'return');
      expect(_stock(after), BigInt.from(4000));
      expect(added.single.sourceRecordId, 'return');
      expect(added.single.journal.effectiveDate.toString(), '2026-01-05');
      expect(added.single.journal.totalUnits, BigInt.from(1000));
      expect(
        _net(after, 'contra_revenue:sales_return') -
            _net(before, 'contra_revenue:sales_return'),
        BigInt.from(1000),
      );
    case 'void':
      expect(_rows(after, 'sales').single['status'], 'void');
      expect(_stock(after), BigInt.from(5000));
      expect(added.single.journal.effectiveDate.toString(), '2026-01-03');
      expect(added.single.journal.reversesId, 'sale-journal');
    case 'expense':
      final days = after.account.toJson()['days'] as Map;
      final expense =
          ((days['2026-01-05'] as Map)['expenses'] as List).single as Map;
      expect(expense['id'], 'expense');
      expect(expense['amount'], 1200);
      expect(
        DailyCashQueries(after.account).statement().total,
        BigInt.from(1200),
      );
      expect(added.single.sourceRecordId, 'expense');
    case 'invoice':
      expect(_rows(after, 'invoices').single['id'], 'invoice');
      expect(_rows(after, 'payments').single['id'], 'inline-payment');
      expect(_rows(after, 'materials').single['id'], 'inline-material');
      expect(added.map((entry) => entry.sourceRecordId), [
        'invoice',
        'inline-payment',
      ]);
      expect(added.map((entry) => entry.journal.totalUnits), [
        BigInt.from(4200),
        BigInt.from(1500),
      ]);
      expect(
        DailyCashQueries(after.account).statement().total,
        BigInt.from(1500),
      );
      expect(_stock(after), _stock(before));
    case 'payment':
      expect(_rows(after, 'payments').map((row) => row['id']), [
        'inline-payment',
        'payment',
      ]);
      final ledger = SupplierLedgerQueries(
        after.account,
        compareText: (_, _) =>
            throw StateError('No ordered query in atomicity assertions.'),
      );
      expect(ledger.invoiceDue('invoice'), BigInt.from(1500));
      expect(
        DailyCashQueries(after.account).statement().total,
        BigInt.from(2700),
      );
      expect(added.single.sourceRecordId, 'payment');
      expect(_stock(after), _stock(before));
  }
}

// The underlying transaction.after_commit fault creates the real pending state.
// This decorator only keeps resolution unavailable until the owner closes it.
class _UnavailableResolutionStore extends UnknownAckStore {
  _UnavailableResolutionStore(super.inner);
  int attempts = 0;
  @override
  Future<CapabilityResult<void>> resolvePendingWrite() async {
    attempts++;
    return const CapabilityFailure(
      DocumentErrorCodes.unavailable,
      'Synthetic resolution outage.',
    );
  }
}

void main() {
  late Directory directory;
  PowerSyncLocalDocumentWorkspaceStore? current;
  String? armedBoundary;
  final fired = <String>[];

  Future<PowerSyncLocalDocumentWorkspaceStore> open() async {
    final store = _value(
      await PowerSyncLocalDocumentWorkspaceStore.open(
        directoryPath: directory.path,
        checkpoint: (point) async {
          if (armedBoundary == point) {
            armedBoundary = null;
            fired.add(point);
            throw StateError('Synthetic checkpoint fault: $point');
          }
        },
      ),
    );
    current = store;
    return store;
  }

  Future<PowerSyncLocalDocumentWorkspaceStore> reopen() async {
    await current!.close();
    current = null;
    return open();
  }

  setUp(() async {
    armedBoundary = null;
    fired.clear();
    directory = await Directory.systemTemp.createTemp(
      'dakhl-command-atomicity-',
    );
    addTearDown(() async {
      await current?.close();
      current = null;
      if (await directory.exists()) await directory.delete(recursive: true);
      expect(await directory.exists(), isFalse);
    });
  });

  Future<PowerSyncLocalDocumentWorkspaceStore> prepare(String kind) async {
    final store = await open();
    _value(
      await store.writeDocument(
        _codec.encodeState(_initialState()),
        writeToken: 'seed',
      ),
    );
    if (kind == 'return' || kind == 'void') {
      expect(
        await _execute(store, _sale((await _snapshot(store)).fence)),
        isA<DurableCommandSuccess<Object>>(),
      );
    }
    if (kind == 'payment') {
      expect(
        await _execute(store, _invoice((await _snapshot(store)).fence)),
        isA<DurableCommandSuccess<Object>>(),
      );
    }
    return store;
  }

  for (final kind in [
    'sale',
    'return',
    'void',
    'expense',
    'invoice',
    'payment',
  ]) {
    test(
      '$kind rolls back complete state at actual before-commit checkpoint then retries once',
      () async {
        final store = await prepare(kind);
        final before = await _snapshot(store);
        final command = _command(kind, before.fence);
        armedBoundary = 'transaction.before_commit';
        final result = await _execute(store, command);
        expect(result, isA<DurableCommandFailure<Object>>());
        expect(
          (result as DurableCommandFailure<Object>).code,
          DocumentErrorCodes.unavailable,
        );
        expect(fired, ['transaction.before_commit']);
        final immediate = await _snapshot(store);
        expect(immediate.payload, before.payload);
        expect(immediate.revision, before.revision);
        expect(immediate.writeToken, before.writeToken);
        final reopened = await reopen();
        final rolledBack = await _snapshot(reopened);
        expect(rolledBack.payload, before.payload);
        expect(rolledBack.revision, before.revision);
        expect(
          await _execute(reopened, command),
          isA<DurableCommandSuccess<Object>>(),
        );
        final committed = await _snapshot(reopened);
        expect(committed.revision, before.revision + 1);
        _assertCommitted(
          kind,
          _codec.decodeState(before.payload),
          _codec.decodeState(committed.payload),
        );
        expect(
          await _execute(reopened, command),
          isA<DurableCommandReplayed<Object>>(),
        );
        expect((await _snapshot(reopened)).payload, committed.payload);
      },
    );

    test(
      '$kind resolves actual after-commit lost acknowledgement and reopens without duplicate effects',
      () async {
        final store = await prepare(kind);
        final before = await _snapshot(store);
        final command = _command(kind, before.fence);
        armedBoundary = 'transaction.after_commit';
        final result = await _execute(store, command);
        expect(result, isA<DurableCommandReplayed<Object>>());
        expect(fired, ['transaction.after_commit']);
        final committed = await _snapshot(store);
        expect(committed.revision, before.revision + 1);
        _assertCommitted(
          kind,
          _codec.decodeState(before.payload),
          _codec.decodeState(committed.payload),
        );
        final reopened = await reopen();
        expect((await _snapshot(reopened)).payload, committed.payload);
        final replay = await _execute(reopened, command);
        expect(replay, isA<DurableCommandReplayed<Object>>());
        expect(
          (replay as DurableCommandReplayed<Object>).receipt,
          (result as DurableCommandReplayed<Object>).receipt,
        );
        final changed = await _execute(
          reopened,
          _command(kind, before.fence, changed: true),
        );
        expect(changed, isA<DurableCommandFailure<Object>>());
        expect(
          (changed as DurableCommandFailure<Object>).code,
          DurableCommandErrorCodes.changedPayloadRejected,
        );
        expect((await _snapshot(reopened)).payload, committed.payload);
        expect((await _snapshot(reopened)).revision, committed.revision);
      },
    );
  }

  test('unresolved committed multi-journal invoice reopens then survives interleaved stock sale and replay', () async {
    final store = await prepare('invoice');
    final before = await _snapshot(store);
    final command = _invoice(before.fence);
    final unavailable = _UnavailableResolutionStore(store);
    armedBoundary = 'transaction.after_commit';
    final result = await _execute(unavailable, command);
    expect(result, isA<DurableCommandFailure<Object>>());
    expect(
      (result as DurableCommandFailure<Object>).code,
      DurableCommandErrorCodes.commitUnknown,
    );
    expect(unavailable.attempts, 1);
    final pending = await store.readDocument();
    expect(pending, isA<CapabilityFailure<DocumentSnapshot?>>());
    expect(
      (pending as CapabilityFailure<DocumentSnapshot?>).code,
      DocumentErrorCodes.commitUnknown,
    );
    final reopened = await reopen();
    final persisted = await _snapshot(reopened);
    _assertCommitted(
      'invoice',
      _codec.decodeState(before.payload),
      _codec.decodeState(persisted.payload),
    );
    final restored = await _execute(reopened, command);
    expect(restored, isA<DurableCommandReplayed<Object>>());
    final sale = _sale(persisted.fence);
    expect(
      await _execute(reopened, sale),
      isA<DurableCommandSuccess<Object>>(),
    );
    final interleaved = await _snapshot(reopened);
    _assertCommitted(
      'sale',
      _codec.decodeState(persisted.payload),
      _codec.decodeState(interleaved.payload),
    );
    expect(
      await _execute(reopened, command),
      isA<DurableCommandReplayed<Object>>(),
    );
    expect(
      await _execute(reopened, sale),
      isA<DurableCommandReplayed<Object>>(),
    );
    expect((await _snapshot(reopened)).payload, interleaved.payload);
    final finalStore = await reopen();
    expect((await _snapshot(finalStore)).payload, interleaved.payload);
    expect((await _snapshot(finalStore)).revision, before.revision + 2);
  });
}
