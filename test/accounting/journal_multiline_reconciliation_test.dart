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
import 'package:dakhl_restaurant/accounts/legacy_account_codec.dart';
import 'package:dakhl_restaurant/accounts/portable_journal_codec.dart';
import 'package:dakhl_restaurant/accounts/portable_journal_state.dart';
import 'package:dakhl_restaurant/inventory/stock_projection.dart';
import 'package:dakhl_restaurant/parties/purchase_proposal.dart';
import 'package:dakhl_restaurant/parties/supplier_ledger.dart';
import 'package:dakhl_restaurant/sales/return_proposal.dart';

// Independent frozen model.js oracle; no candidate arithmetic generated these
// literals. Provenance and reproducible Node harness live in the owned receipt.
// Frozen model SHA-256: 65a9b33cdca42e328d710f1afaa1b0fb42a7778284bd2f07f7c7e77d3d9f07f4
const _seedJson =
    r'''{"version":11,"products":[{"id":"a","name":"Item A","code":"A","unit":"piece","price":1001,"group":"food","minStock":0,"trackStock":true,"archived":false},{"id":"b","name":"Item B","code":"B","unit":"piece","price":799,"group":"food","minStock":0,"trackStock":true,"archived":false}],"stockEntries":[{"id":"open-a","productId":"a","date":"2026-02-01","quantity":10,"kind":"opening","note":"Synthetic opening","createdAt":"2026-02-01T12:00:00.000Z"},{"id":"open-b","productId":"b","date":"2026-02-01","quantity":8,"kind":"opening","note":"Synthetic opening","createdAt":"2026-02-01T12:00:00.000Z"}],"sales":[],"saleReturns":[],"preferences":{"shortcuts":["sales","inventory","sale-history","expenses","cash","settings"],"orderTypes":["صالة","سفري","توصيل"],"restaurant":{"name":"","contact":"","footer":""}},"categories":[{"id":"samoon","name":"الصمون","type":"primary"},{"id":"bread","name":"الخبز","type":"primary"},{"id":"falafel","name":"الفلافل","type":"primary"},{"id":"market","name":"الأسواق","type":"primary"}],"days":{},"transactions":[{"id":"cashbox-opening","date":"2026-02-01","type":"deposit","amount":20000,"note":"Synthetic opening","createdAt":"2026-02-01T12:00:00.000Z"}],"transfers":[],"suppliers":[{"id":"s","name":"Supplier S","phone":"","note":"","categoryId":"samoon","openingBalance":500,"materials":[]}],"invoices":[],"payments":[],"debts":[],"materials":[],"workers":[],"savingsEntries":[]}''';
const _expectedJson =
    r'''{"version":11,"products":[{"id":"a","name":"Item A","code":"A","unit":"piece","price":1001,"group":"food","minStock":0,"trackStock":true,"archived":false},{"id":"b","name":"Item B","code":"B","unit":"piece","price":799,"group":"food","minStock":0,"trackStock":true,"archived":false}],"stockEntries":[{"id":"open-a","productId":"a","date":"2026-02-01","quantity":10,"kind":"opening","note":"Synthetic opening","createdAt":"2026-02-01T12:00:00.000Z"},{"id":"open-b","productId":"b","date":"2026-02-01","quantity":8,"kind":"opening","note":"Synthetic opening","createdAt":"2026-02-01T12:00:00.000Z"}],"sales":[{"id":"shared","number":"S-000001","date":"2026-02-02","status":"completed","lines":[{"productId":"a","name":"Item A","unit":"piece","quantity":2.5,"price":1001,"trackStock":true},{"productId":"b","name":"Item B","unit":"piece","quantity":1.75,"price":799,"trackStock":true}],"discount":101,"paid":3800,"note":"Multi-line discounted","createdAt":"2026-02-02T12:00:00.000Z","orderType":"صالة"},{"id":"void-sale","number":"S-000002","date":"2026-02-03","status":"void","lines":[{"productId":"a","name":"Item A","unit":"piece","quantity":0.4,"price":1001,"trackStock":true},{"productId":"b","name":"Item B","unit":"piece","quantity":0.125,"price":799,"trackStock":true}],"discount":1,"paid":499,"note":"Void later","createdAt":"2026-02-03T12:00:00.000Z","orderType":"صالة","voidReason":"Original-date correction","voidedAt":"2026-02-06T12:00:00.000Z"},{"id":"kept","number":"S-000003","date":"2026-02-06","status":"completed","lines":[{"productId":"a","name":"Item A","unit":"piece","quantity":0.125,"price":1001,"trackStock":true},{"productId":"b","name":"Item B","unit":"piece","quantity":0.25,"price":799,"trackStock":true}],"discount":0,"paid":325,"note":"Retained sale","createdAt":"2026-02-06T12:00:00.000Z","orderType":"صالة"}],"saleReturns":[{"id":"r1","saleId":"shared","date":"2026-02-03","reason":"Staged refund","createdAt":"2026-02-03T12:00:00.000Z","lines":[{"productId":"a","quantity":0.75,"restock":true,"amount":731},{"productId":"b","quantity":0.5,"restock":false,"amount":389}],"amount":1120},{"id":"r2","saleId":"shared","date":"2026-02-04","reason":"Staged refund","createdAt":"2026-02-04T12:00:00.000Z","lines":[{"productId":"a","quantity":0.5,"restock":false,"amount":488},{"productId":"b","quantity":0.25,"restock":true,"amount":194}],"amount":682},{"id":"r3","saleId":"shared","date":"2026-02-05","reason":"Staged refund","createdAt":"2026-02-05T12:00:00.000Z","lines":[{"productId":"a","quantity":1.25,"restock":true,"amount":1219},{"productId":"b","quantity":1,"restock":true,"amount":779}],"amount":1998}],"preferences":{"shortcuts":["sales","inventory","sale-history","expenses","cash","settings"],"orderTypes":["صالة","سفري","توصيل"],"restaurant":{"name":"","contact":"","footer":""}},"categories":[{"id":"samoon","name":"الصمون","type":"primary"},{"id":"bread","name":"الخبز","type":"primary"},{"id":"falafel","name":"الفلافل","type":"primary"},{"id":"market","name":"الأسواق","type":"primary"}],"days":{"2026-02-04":{"expenses":[{"id":"shared","categoryId":"samoon","amount":90,"note":"Mixed expense","funding":{"source":"shared","dailyAmount":60,"cashAmount":30},"createdAt":"2026-02-04T12:00:00.000Z"}],"chickenUsed":0,"chickenLeft":0,"balance":null,"totalOverride":null,"remaining":null}},"transactions":[{"id":"cashbox-opening","date":"2026-02-01","type":"deposit","amount":20000,"note":"Synthetic opening","createdAt":"2026-02-01T12:00:00.000Z"}],"transfers":[],"suppliers":[{"id":"s","name":"Supplier S","phone":"","note":"","categoryId":"samoon","openingBalance":500,"materials":[]}],"invoices":[{"id":"shared","supplierId":"s","number":"ML-1","date":"2026-02-05","lines":[{"materialId":"m","name":"Flour","unit":"bag","quantityCartons":0.5,"quantityPieces":1.25,"priceCarton":2000,"pricePiece":400,"quantity":1.25,"price":400}],"note":"Mixed purchase","createdAt":"2026-02-05T12:00:00.000Z"}],"payments":[{"id":"initial","supplierId":"s","invoiceId":"shared","invoiceAmount":600,"debtAmount":0,"categoryId":"samoon","date":"2026-02-05","amount":600,"funding":{"source":"shared","dailyAmount":400,"cashAmount":200},"note":"","createdAt":"2026-02-05T12:00:00.000Z"},{"id":"shared","supplierId":"s","invoiceId":"shared","invoiceAmount":900,"debtAmount":100,"categoryId":"samoon","date":"2026-02-06","amount":1000,"funding":{"source":"shared","dailyAmount":700,"cashAmount":300},"note":"Settle invoice and opening","createdAt":"2026-02-06T12:00:00.000Z"}],"debts":[],"materials":[{"id":"m","name":"Flour","unit":"bag","priceCarton":2000,"pricePiece":400,"archived":false}],"workers":[],"savingsEntries":[]}''';

const _codec = PortableJournalCodec();
const _lineage = 'synthetic-multiline-reconciliation';
BigInt _n(int n) => BigInt.from(n);
DateOnly _date(int day) => DateOnly.parse(
  '2026-02-${day.toString().padLeft(2, '0')}',
  minimumYear: 1000,
  maximumYear: 9999,
);
String _stamp(int day) => '${_date(day)}T12:00:00.000Z';

PortableJournalState _seed() {
  final opening = RestaurantJournalMapper().mapVerifiedCutoverOpening(
    journalId: 'j-opening',
    effectiveDate: _date(1),
    verifiedPhysicalRegisterCash: _n(100000),
    verifiedCashboxBalance: _n(20000),
    verifiedSupplierDebts: {'s': _n(500)},
  );
  return PortableJournalState(
    accountLineage: _lineage,
    account: const LegacyAccountCodec().decodeJson(jsonDecode(_seedJson)),
    sourceProvenance: PortableJournalSourceProvenance(
      sourceVersion: 11,
      enrolledAt: _stamp(1),
      migrated: false,
    ),
    cutoverState: PortableJournalCutoverState.established(
      cutoverDate: _date(1),
      openingJournalId: 'j-opening',
    ),
    journals: [
      PortableJournalEntry(
        journal: opening.journal,
        sourceType: opening.sourceType.name,
        sourceRecordId: 'synthetic-cutover',
        recordedAt: _stamp(1),
      ),
    ],
    receipts: const [],
  );
}

// Assertion projection only; this neither posts nor allocates money.
BigInt _balance(PortableJournalState state, String account, {int? day}) => state
    .journals
    .where((j) => day == null || j.journal.effectiveDate == _date(day))
    .expand((j) => j.journal.lines)
    .where((l) => l.accountId == account)
    .fold(
      BigInt.zero,
      (sum, l) =>
          sum + (l.side == JournalSide.debit ? l.amountUnits : -l.amountUnits),
    );

void main() {
  test('multiline fractional history reconciles cumulative refunds, dated stock, namespaces and durable replay', () async {
    final directory = await Directory.systemTemp.createTemp(
      'dakhl-f09-multiline-',
    );
    PowerSyncLocalDocumentWorkspaceStore? store;
    addTearDown(() async {
      await store?.close();
      if (directory.existsSync()) directory.deleteSync(recursive: true);
    });
    Future<void> open() async {
      final result = await PowerSyncLocalDocumentWorkspaceStore.open(
        directoryPath: directory.path,
      );
      expect(
        result,
        isA<CapabilitySuccess<PowerSyncLocalDocumentWorkspaceStore>>(),
      );
      store =
          (result as CapabilitySuccess<PowerSyncLocalDocumentWorkspaceStore>)
              .value;
    }

    Future<DocumentSnapshot> snapshot() async {
      final result = await store!.readDocument();
      expect(result, isA<CapabilitySuccess<DocumentSnapshot?>>());
      return (result as CapabilitySuccess<DocumentSnapshot?>).value!;
    }

    Future<PortableJournalState> read() async =>
        _codec.decodeState((await snapshot()).payload);
    RestaurantJournalSaleCommandCoordinator sales() =>
        RestaurantJournalSaleCommandCoordinator(store: store!, codec: _codec);
    RestaurantJournalSpendingCommandCoordinator spending() =>
        RestaurantJournalSpendingCommandCoordinator(
          store: store!,
          codec: _codec,
        );
    final saleCommands = <RestaurantJournalSaleCommand>[];
    final spendingCommands = <RestaurantJournalSpendingCommand>[];
    final committedReceipts = <DurableCommandReceipt>[];
    Future<void> sale(RestaurantJournalSaleCommand command) async {
      final result = await sales().execute(command);
      expect(
        result,
        isA<DurableCommandSuccess<RestaurantJournalSaleOutcome>>(),
        reason: '${command.operationId}: $result',
      );
      saleCommands.add(command);
      committedReceipts.add(
        (result as DurableCommandSuccess<RestaurantJournalSaleOutcome>).receipt,
      );
    }

    Future<void> spend(RestaurantJournalSpendingCommand command) async {
      final result = await spending().execute(command);
      expect(
        result,
        isA<DurableCommandSuccess<RestaurantJournalSpendingOutcome>>(),
        reason: '${command.operationId}: $result',
      );
      spendingCommands.add(command);
      committedReceipts.add(
        (result as DurableCommandSuccess<RestaurantJournalSpendingOutcome>)
            .receipt,
      );
    }

    Future<void> stock(int day, int a, int b) async {
      final projection = RestaurantStockProjection((await read()).account);
      expect(
        projection.balanceFor('a', through: _date(day)),
        _n(a),
        reason: 'day$day a',
      );
      expect(
        projection.balanceFor('b', through: _date(day)),
        _n(b),
        reason: 'day$day b',
      );
      expect(projection.balancesAt(_date(day)), {'a': _n(a), 'b': _n(b)});
      projection.validateHistory();
    }

    await open();
    expect(
      await store!.writeDocument(
        _codec.encodeState(_seed()),
        writeToken: 'seed',
      ),
      isA<CapabilitySuccess<DocumentSnapshot>>(),
    );
    final fence = (await snapshot()).fence;
    CompleteSaleCommand complete(
      String id,
      int day,
      int discount,
      num a,
      num b,
      String note,
    ) => CompleteSaleCommand(
      operationId: 'op-sale-$id',
      accountLineage: _lineage,
      expectedFence: fence,
      saleId: id,
      journalId: 'j-sale-$id',
      recordedAt: _stamp(day),
      draft: {
        'date': '${_date(day)}',
        'discount': discount,
        'note': note,
        'lines': [
          {'productId': 'a', 'quantity': a},
          {'productId': 'b', 'quantity': b},
        ],
      },
    );
    SaleReturnCommand refund(
      String id,
      int day,
      int aUnits,
      int bUnits,
      bool aRestock,
      bool bRestock,
    ) => SaleReturnCommand(
      operationId: 'op-$id',
      accountLineage: _lineage,
      expectedFence: fence,
      saleId: 'shared',
      returnId: id,
      journalId: 'j-$id',
      returnDate: _date(day),
      today: _date(day),
      recordedAt: _stamp(day),
      reason: 'Staged refund',
      lines: [
        ReturnLineRequest(
          productId: 'a',
          quantityUnits: _n(aUnits),
          restock: aRestock,
        ),
        ReturnLineRequest(
          productId: 'b',
          quantityUnits: _n(bUnits),
          restock: bRestock,
        ),
      ],
    );
    await stock(1, 10000, 8000);
    final original = complete(
      'shared',
      2,
      101,
      2.5,
      1.75,
      'Multi-line discounted',
    );
    await sale(original);
    await stock(2, 7500, 6250);
    await sale(refund('r1', 3, 750, 500, true, false));
    await sale(complete('void-sale', 3, 1, .4, .125, 'Void later'));
    await stock(3, 7850, 6125);
    await sale(refund('r2', 4, 500, 250, false, true));
    await stock(4, 7850, 6375);
    await sale(refund('r3', 5, 1250, 1000, true, true));
    await stock(5, 9100, 7375);
    await sale(
      SaleVoidCommand(
        operationId: 'op-void',
        accountLineage: _lineage,
        expectedFence: fence,
        saleId: 'void-sale',
        reversalJournalId: 'j-void',
        reason: 'Original-date correction',
        voidedAt: _stamp(6),
      ),
    );
    await stock(3, 8250, 6250);
    await stock(5, 9500, 7500);
    await sale(complete('kept', 6, 0, .125, .25, 'Retained sale'));
    await spend(
      CreateOperatingExpenseCommand(
        operationId: 'op-expense-shared',
        accountLineage: _lineage,
        expectedFence: fence,
        expenseId: 'shared',
        journalId: 'j-expense-shared',
        date: _date(4),
        categoryId: 'samoon',
        amount: _n(90),
        fundingSource: FundingSource.shared,
        dailyAmount: _n(60),
        cashAmount: _n(30),
        note: 'Mixed expense',
        recordedAt: _stamp(4),
      ),
    );
    await spend(
      CreatePurchaseInvoiceCommand(
        operationId: 'op-invoice-shared',
        accountLineage: _lineage,
        expectedFence: fence,
        invoiceId: 'shared',
        invoiceJournalId: 'j-invoice-shared',
        supplierId: 's',
        invoiceNumber: 'ML-1',
        date: _date(5),
        recordedAt: _stamp(5),
        note: 'Mixed purchase',
        lines: const [
          PurchaseLine(
            materialIdForCreation: 'm',
            name: 'Flour',
            unit: 'bag',
            quantityCartons: .5,
            quantityPieces: 1.25,
            priceCarton: 2000,
            pricePiece: 400,
          ),
        ],
        immediatePayment: const PurchasePayment(
          id: 'initial',
          amount: 600,
          source: 'shared',
          dailyAmount: 400,
          cashAmount: 200,
        ),
        paymentJournalId: 'j-payment-initial',
      ),
    );
    await spend(
      CreateSupplierPaymentCommand(
        operationId: 'op-payment-shared',
        accountLineage: _lineage,
        expectedFence: fence,
        paymentId: 'shared',
        journalId: 'j-payment-shared',
        supplierId: 's',
        invoiceId: 'shared',
        date: _date(6),
        amount: _n(1000),
        fundingSource: FundingSource.shared,
        dailyAmount: _n(700),
        cashAmount: _n(300),
        note: 'Settle invoice and opening',
        recordedAt: _stamp(6),
      ),
    );
    final persisted = await snapshot();
    await store!.close();
    store = null;
    await open();
    final reopened = await snapshot();
    expect(reopened.payload, persisted.payload);
    expect(reopened.fence, fence);
    final state = await read();
    final expected = jsonDecode(_expectedJson) as Map<String, dynamic>;
    final actual = state.account.toJson();
    expect(actual.keys.toSet(), expected.keys.toSet());
    for (final key in expected.keys) {
      expect(
        actual[key],
        expected[key],
        reason: 'Complete independent source snapshot: $key',
      );
    }
    final cash = DailyCashQueries(state.account);
    expect(cash.statement().total, _n(1690));
    expect(cash.statement().dailyShare, _n(1160));
    expect(cash.statement().cashShare, _n(530));
    expect(cash.cashBalance, _n(19470));
    expect(cash.statement().rows.map((r) => (r['id'], r['amount'])).toSet(), {
      ('shared', 90),
      ('initial', 600),
      ('shared', 1000),
    });
    final ledger = SupplierLedgerQueries(
      state.account,
      compareText: (_, _) =>
          throw StateError('No ordered collation query in this fixture'),
    );
    expect(
      ledger.invoiceTotal(
        (actual['invoices'] as List).single as Map<String, Object?>,
      ),
      _n(1500),
    );
    expect(ledger.invoiceDue('shared'), _n(0));
    expect(ledger.debtAvailable('s'), _n(400));
    expect(ledger.supplierBalance('s'), _n(400));
    for (final row in <(int, int, int, int)>[
      (1, 0, 10000, 8000),
      (2, 3800, 7500, 6250),
      (3, -1120, 8250, 6250),
      (4, -682, 8250, 6500),
      (5, -1998, 9500, 7500),
      (6, 325, 9375, 7250),
    ]) {
      expect(cash.day('${_date(row.$1)}').netSales, _n(row.$2));
      await stock(row.$1, row.$3, row.$4);
    }
    const debit = JournalSide.debit, credit = JournalSide.credit;
    final expectedJournals =
        <(String, String, String, int, List<(String, JournalSide, int)>)>[
          (
            'j-opening',
            'cutoverOpening',
            'synthetic-cutover',
            1,
            [
              ('asset:cash:daily', debit, 100000),
              ('asset:cash:cashbox', debit, 20000),
              ('liability:supplier:s', credit, 500),
              ('equity:opening_balance', credit, 119500),
            ],
          ),
          (
            'j-sale-shared',
            'sale',
            'shared',
            2,
            [
              ('asset:cash:daily', debit, 3800),
              ('revenue:sales', credit, 3800),
            ],
          ),
          (
            'j-r1',
            'saleReturn',
            'r1',
            3,
            [
              ('contra_revenue:sales_return', debit, 1120),
              ('asset:cash:daily', credit, 1120),
            ],
          ),
          (
            'j-sale-void-sale',
            'sale',
            'void-sale',
            3,
            [('asset:cash:daily', debit, 499), ('revenue:sales', credit, 499)],
          ),
          (
            'j-r2',
            'saleReturn',
            'r2',
            4,
            [
              ('contra_revenue:sales_return', debit, 682),
              ('asset:cash:daily', credit, 682),
            ],
          ),
          (
            'j-r3',
            'saleReturn',
            'r3',
            5,
            [
              ('contra_revenue:sales_return', debit, 1998),
              ('asset:cash:daily', credit, 1998),
            ],
          ),
          (
            'j-void',
            'voidReversal',
            'void-sale',
            3,
            [('asset:cash:daily', credit, 499), ('revenue:sales', debit, 499)],
          ),
          (
            'j-sale-kept',
            'sale',
            'kept',
            6,
            [('asset:cash:daily', debit, 325), ('revenue:sales', credit, 325)],
          ),
          (
            'j-expense-shared',
            'expense',
            'shared',
            4,
            [
              ('expense:category:samoon', debit, 90),
              ('asset:cash:daily', credit, 60),
              ('asset:cash:cashbox', credit, 30),
            ],
          ),
          (
            'j-invoice-shared',
            'purchaseInvoice',
            'shared',
            5,
            [
              ('expense:purchases', debit, 1500),
              ('liability:supplier:s', credit, 1500),
            ],
          ),
          (
            'j-payment-initial',
            'supplierPayment',
            'initial',
            5,
            [
              ('liability:supplier:s', debit, 600),
              ('asset:cash:daily', credit, 400),
              ('asset:cash:cashbox', credit, 200),
            ],
          ),
          (
            'j-payment-shared',
            'supplierPayment',
            'shared',
            6,
            [
              ('liability:supplier:s', debit, 1000),
              ('asset:cash:daily', credit, 700),
              ('asset:cash:cashbox', credit, 300),
            ],
          ),
        ];
    expect(state.journals.length, 12);
    final financialSnapshot = state.journals
        .singleWhere((j) => j.journal.id == 'j-sale-shared')
        .metadata;
    expect(
      (
        financialSnapshot['gross'],
        financialSnapshot['discount'],
        financialSnapshot['net'],
      ),
      ('3901', '101', '3800'),
    );
    for (final item in expectedJournals) {
      final entry = state.journals.singleWhere((j) => j.journal.id == item.$1);
      expect(
        (entry.sourceType, entry.sourceRecordId, entry.journal.effectiveDate),
        (item.$2, item.$3, _date(item.$4)),
        reason: item.$1,
      );
      expect(
        entry.journal.lines
            .map(
              (l) => (l.accountId, l.side, l.amountUnits, l.currency, l.scale),
            )
            .toList(),
        [for (final l in item.$5) (l.$1, l.$2, _n(l.$3), 'IQD', 0)],
        reason: item.$1,
      );
    }
    final inverse = state.journals.singleWhere((j) => j.journal.id == 'j-void');
    expect(inverse.journal.reversesId, 'j-sale-void-sale');
    expect(inverse.recordedAt, _stamp(6));
    expect(_balance(state, 'asset:cash:daily'), _n(99165));
    expect(_balance(state, 'asset:cash:cashbox'), _n(19470));
    expect(_balance(state, 'liability:supplier:s'), _n(-400));
    expect(_balance(state, 'expense:purchases'), _n(1500));
    for (final row in <(int, int, int)>[
      (1, 100000, 0),
      (2, 3800, 0),
      (3, -1120, 0),
      (4, -742, -30),
      (5, -2398, -200),
      (6, -375, -300),
    ]) {
      expect(_balance(state, 'asset:cash:daily', day: row.$1), _n(row.$2));
      expect(
        _balance(state, 'asset:cash:cashbox', day: row.$1),
        _n(row.$1 == 1 ? 20000 : row.$3),
      );
    }
    final refunds = (actual['saleReturns'] as List)
        .cast<Map<String, Object?>>();
    expect(refunds.map((r) => r['amount']), [1120, 682, 1998]);
    expect(
      refunds
          .expand((r) => (r['lines'] as List).cast<Map<String, Object?>>())
          .map((l) => l['amount']),
      [731, 389, 488, 194, 1219, 779],
    );
    expect(refunds.fold<int>(0, (sum, r) => sum + (r['amount'] as int)), 3800);
    final ids = [
      'op-sale-shared',
      'op-r1',
      'op-sale-void-sale',
      'op-r2',
      'op-r3',
      'op-void',
      'op-sale-kept',
      'op-expense-shared',
      'op-invoice-shared',
      'op-payment-shared',
    ];
    expect(state.receipts.map((r) => r.identity.operationId), ids);
    expect(state.receipts, committedReceipts);
    final expectedReceiptValues = <(String, int, int)>[
      ('j-sale-shared', 3800, 2),
      ('j-r1', 1120, 3),
      ('j-sale-void-sale', 499, 3),
      ('j-r2', 682, 4),
      ('j-r3', 1998, 5),
      ('j-void', 499, 3),
      ('j-sale-kept', 325, 6),
      ('j-expense-shared', 90, 4),
      ('j-invoice-shared', 1500, 5),
      ('j-payment-shared', 1000, 6),
    ];
    for (var i = 0; i < state.receipts.length; i++) {
      final receipt = state.receipts[i];
      expect(receipt.sequence, i + 1);
      expect(receipt.committedRevision, i + 2);
      expect(receipt.fence, fence);
      final outcome = jsonDecode(receipt.outcomePayload!) as Map;
      expect(outcome['operationId'], ids[i]);
      final expectedReceipt = expectedReceiptValues[i];
      expect(
        (outcome['journalId'], outcome['netAmount'], outcome['effectiveDate']),
        (
          expectedReceipt.$1,
          '${expectedReceipt.$2}',
          '${_date(expectedReceipt.$3)}',
        ),
      );
      expect(
        state.journals
            .singleWhere((j) => j.journal.id == expectedReceipt.$1)
            .metadata['operationId'],
        ids[i],
      );
    }
    final jointOutcome = jsonDecode(state.receipts[8].outcomePayload!) as Map;
    expect(
      (
        jointOutcome['invoiceId'],
        jointOutcome['paymentId'],
        jointOutcome['paymentJournalId'],
      ),
      ('shared', 'initial', 'j-payment-initial'),
    );
    final joint = state.journals
        .where((j) => j.metadata['operationId'] == 'op-invoice-shared')
        .map((j) => j.journal.id)
        .toSet();
    expect(joint, {'j-invoice-shared', 'j-payment-initial'});
    final beforeReplay = await snapshot();
    for (final command in saleCommands) {
      expect(
        await sales().execute(command),
        isA<DurableCommandReplayed<RestaurantJournalSaleOutcome>>(),
      );
    }
    for (final command in spendingCommands) {
      expect(
        await spending().execute(command),
        isA<DurableCommandReplayed<RestaurantJournalSpendingOutcome>>(),
      );
    }
    expect((await snapshot()).payload, beforeReplay.payload);
    expect((await snapshot()).revision, beforeReplay.revision);
    final changed = complete(
      'shared',
      2,
      102,
      2.5,
      1.75,
      'Multi-line discounted',
    );
    final rejected = await sales().execute(changed);
    expect(
      rejected,
      isA<DurableCommandFailure<RestaurantJournalSaleOutcome>>(),
    );
    expect(
      (rejected as DurableCommandFailure<RestaurantJournalSaleOutcome>).code,
      DurableCommandErrorCodes.changedPayloadRejected,
    );
    expect((await snapshot()).payload, beforeReplay.payload);
    expect((await snapshot()).revision, beforeReplay.revision);
    final invalid = await sales().execute(
      refund('over-return', 7, 1, 1, true, true),
    );
    expect(invalid, isA<DurableCommandFailure<RestaurantJournalSaleOutcome>>());
    final voidReturned = await sales().execute(
      SaleVoidCommand(
        operationId: 'reject-returned-void',
        accountLineage: _lineage,
        expectedFence: fence,
        saleId: 'shared',
        reversalJournalId: 'never-written',
        reason: 'Not eligible',
        voidedAt: _stamp(7),
      ),
    );
    expect(
      voidReturned,
      isA<DurableCommandFailure<RestaurantJournalSaleOutcome>>(),
    );
    expect((await snapshot()).payload, beforeReplay.payload);
    expect((await snapshot()).revision, beforeReplay.revision);
    await stock(6, 9375, 7250);
  });
}
