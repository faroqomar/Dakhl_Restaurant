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

const _codec = PortableJournalCodec();
const _lineage = 'synthetic-mixed-reconciliation';
DateOnly _date(int day) => DateOnly.parse(
  '2026-01-${day.toString().padLeft(2, '0')}',
  minimumYear: 1000,
  maximumYear: 9999,
);
String _stamp(int day) => '${_date(day)}T12:00:00.000Z';
BigInt _n(int n) => BigInt.from(n);

PortableJournalState _seed() {
  const legacy = LegacyAccountCodec();
  final raw = Map<String, Object?>.from(legacy.empty().toJson());
  raw['products'] = [
    {
      'id': 'p',
      'name': 'Synthetic item',
      'code': '',
      'unit': 'piece',
      'price': 1000,
      'group': '',
      'minStock': 0,
      'trackStock': true,
      'archived': false,
    },
  ];
  raw['stockEntries'] = [
    {
      'id': 'stock-opening',
      'productId': 'p',
      'date': '${_date(1)}',
      'quantity': 20,
      'kind': 'opening',
      'note': '',
      'createdAt': _stamp(1),
    },
  ];
  raw['transactions'] = [
    {
      'id': 'cashbox-opening',
      'date': '${_date(1)}',
      'type': 'deposit',
      'amount': 50000,
      'note': 'Synthetic opening',
      'createdAt': _stamp(1),
    },
  ];
  raw['suppliers'] = [
    {
      'id': 's',
      'name': 'Synthetic supplier',
      'phone': '',
      'note': '',
      'categoryId': 'samoon',
      'openingBalance': 5000,
    },
  ];
  final opening = RestaurantJournalMapper().mapVerifiedCutoverOpening(
    journalId: 'j-opening',
    effectiveDate: _date(1),
    verifiedPhysicalRegisterCash: _n(100000),
    verifiedCashboxBalance: _n(50000),
    verifiedSupplierDebts: {'s': _n(5000)},
  );
  return PortableJournalState(
    accountLineage: _lineage,
    account: legacy.decodeJson(raw),
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

List<Map<String, Object?>> _rows(PortableJournalState state, String key) =>
    (state.account.toJson()[key]! as List).cast<Map<String, Object?>>();

SupplierLedgerQueries _supplier(PortableJournalState state) =>
    SupplierLedgerQueries(
      state.account,
      compareText: (_, _) {
        throw StateError('Ordered locale query is outside this fixture.');
      },
    );

// Assertion projection only: no posting, allocation or account algorithm.
void _journal(
  PortableJournalState state,
  String id,
  String source,
  String record,
  int day,
  List<(String, JournalSide, int)> expected,
) {
  final entry = state.journals.singleWhere((e) => e.journal.id == id);
  expect(entry.sourceType, source, reason: id);
  expect(entry.sourceRecordId, record, reason: id);
  expect(entry.journal.effectiveDate, _date(day), reason: id);
  expect(
    entry.journal.lines
        .map((l) => (l.accountId, l.side, l.amountUnits, l.currency, l.scale))
        .toList(),
    [for (final line in expected) (line.$1, line.$2, _n(line.$3), 'IQD', 0)],
    reason: id,
  );
}

void main() {
  test(
    'mixed real-store history reconciles source, journals, paid cash and stock',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'dakhl-f09-mixed-',
      );
      PowerSyncLocalDocumentWorkspaceStore? active;
      addTearDown(() async {
        await active?.close();
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
        active =
            (result as CapabilitySuccess<PowerSyncLocalDocumentWorkspaceStore>)
                .value;
      }

      Future<DocumentSnapshot> snapshot() async {
        final result = await active!.readDocument();
        expect(result, isA<CapabilitySuccess<DocumentSnapshot?>>());
        return (result as CapabilitySuccess<DocumentSnapshot?>).value!;
      }

      Future<PortableJournalState> read() async =>
          _codec.decodeState((await snapshot()).payload);
      Future<StorageFence> fence() async => (await snapshot()).fence;
      RestaurantJournalSaleCommandCoordinator sales() =>
          RestaurantJournalSaleCommandCoordinator(
            store: active!,
            codec: _codec,
            mapper: RestaurantJournalMapper(),
          );
      RestaurantJournalSpendingCommandCoordinator spending() =>
          RestaurantJournalSpendingCommandCoordinator(
            store: active!,
            codec: _codec,
            mapper: RestaurantJournalMapper(),
          );
      final receipts = <DurableCommandReceipt>[];
      Future<void> sale(RestaurantJournalSaleCommand command) async {
        final result = await sales().execute(command);
        expect(
          result,
          isA<DurableCommandSuccess<RestaurantJournalSaleOutcome>>(),
          reason: '${command.operationId}: $result',
        );
        receipts.add(
          (result as DurableCommandSuccess<RestaurantJournalSaleOutcome>)
              .receipt,
        );
      }

      Future<void> spend(RestaurantJournalSpendingCommand command) async {
        final result = await spending().execute(command);
        expect(
          result,
          isA<DurableCommandSuccess<RestaurantJournalSpendingOutcome>>(),
          reason: '${command.operationId}: $result',
        );
        receipts.add(
          (result as DurableCommandSuccess<RestaurantJournalSpendingOutcome>)
              .receipt,
        );
      }

      Future<void> complete(
        String id,
        int day,
        int quantity,
        int discount,
      ) async {
        await sale(
          CompleteSaleCommand(
            operationId: 'op-$id',
            accountLineage: _lineage,
            expectedFence: await fence(),
            saleId: id,
            journalId: 'j-$id',
            recordedAt: _stamp(day),
            draft: {
              'date': '${_date(day)}',
              'discount': discount,
              'lines': [
                {'productId': 'p', 'quantity': quantity},
              ],
            },
          ),
        );
      }

      Future<void> refund(
        String id,
        int day,
        int quantity,
        bool restock,
      ) async {
        await sale(
          SaleReturnCommand(
            operationId: 'op-$id',
            accountLineage: _lineage,
            expectedFence: await fence(),
            saleId: 'sale-refund',
            returnId: id,
            journalId: 'j-$id',
            returnDate: _date(day),
            today: _date(day),
            recordedAt: _stamp(day),
            reason: 'Synthetic customer refund',
            lines: [
              ReturnLineRequest(
                productId: 'p',
                quantityUnits: _n(quantity * 1000),
                restock: restock,
              ),
            ],
          ),
        );
      }

      Future<void> checkStock(int day, int expected) async {
        final projection = RestaurantStockProjection((await read()).account);
        expect(
          projection.balanceFor('p', through: _date(day)),
          _n(expected * 1000),
        );
        expect(projection.balancesAt(_date(day))['p'], _n(expected * 1000));
        projection.validateHistory();
      }

      await open();
      final seed = _seed();
      expect(
        await active!.writeDocument(
          _codec.encodeState(seed),
          writeToken: 'seed',
        ),
        isA<CapabilitySuccess<DocumentSnapshot>>(),
      );
      await checkStock(1, 20);
      await complete('sale-refund', 2, 3, 100);
      await checkStock(2, 17);
      await refund('return-partial', 3, 1, true);
      await checkStock(3, 18);
      await refund('return-final', 4, 2, false);
      await checkStock(4, 18);
      await complete('sale-void', 3, 2, 0);
      await checkStock(4, 16);
      await sale(
        SaleVoidCommand(
          operationId: 'op-void',
          accountLineage: _lineage,
          expectedFence: await fence(),
          saleId: 'sale-void',
          reversalJournalId: 'j-void',
          reason: 'Synthetic error',
          voidedAt: _stamp(6),
        ),
      );
      await checkStock(
        3,
        18,
      ); // Original-date inverse, even when recorded on day6.
      await complete('sale-kept', 5, 2, 0);
      await checkStock(6, 16);

      await spend(
        CreateOperatingExpenseCommand(
          operationId: 'op-expense',
          accountLineage: _lineage,
          expectedFence: await fence(),
          expenseId: 'expense',
          journalId: 'j-expense',
          date: _date(2),
          categoryId: 'samoon',
          amount: _n(3000),
          fundingSource: FundingSource.shared,
          dailyAmount: _n(2000),
          cashAmount: _n(1000),
          recordedAt: _stamp(2),
        ),
      );
      await spend(
        CreatePurchaseInvoiceCommand(
          operationId: 'op-unpaid',
          accountLineage: _lineage,
          expectedFence: await fence(),
          invoiceId: 'unpaid',
          invoiceJournalId: 'j-unpaid',
          supplierId: 's',
          invoiceNumber: 'UNPAID',
          date: _date(3),
          recordedAt: _stamp(3),
          lines: const [
            PurchaseLine(
              materialIdForCreation: 'm1',
              name: 'Oil',
              unit: 'unit',
              quantityCartons: 2,
              quantityPieces: 3,
              priceCarton: 4000,
              pricePiece: 500,
            ),
          ],
        ),
      );
      var state = await read();
      expect(
        _supplier(state).invoiceTotal(_rows(state, 'invoices').single),
        _n(9500),
      );
      expect(_supplier(state).supplierBalance('s'), _n(14500));
      expect(DailyCashQueries(state.account).statement().total, _n(3000));
      expect(DailyCashQueries(state.account).expenses('${_date(3)}'), isEmpty);
      await checkStock(6, 16); // Purchase units never become sellable stock.

      await spend(
        CreatePurchaseInvoiceCommand(
          operationId: 'op-immediate',
          accountLineage: _lineage,
          expectedFence: await fence(),
          invoiceId: 'immediate',
          invoiceJournalId: 'j-immediate',
          supplierId: 's',
          invoiceNumber: 'IMMEDIATE',
          date: _date(4),
          recordedAt: _stamp(4),
          lines: const [
            PurchaseLine(
              materialIdForCreation: 'm2',
              name: 'Sauce',
              unit: 'piece',
              quantityCartons: 0,
              quantityPieces: 2,
              priceCarton: 0,
              pricePiece: 1000,
            ),
          ],
          immediatePayment: const PurchasePayment(
            id: 'pay-immediate',
            amount: 1500,
            source: 'cash',
          ),
          paymentJournalId: 'j-pay-immediate',
        ),
      );
      final settling = CreateSupplierPaymentCommand(
        operationId: 'op-settle',
        accountLineage: _lineage,
        expectedFence: await fence(),
        paymentId: 'settle',
        journalId: 'j-settle',
        supplierId: 's',
        invoiceId: 'unpaid',
        date: _date(5),
        amount: _n(11000),
        fundingSource: FundingSource.shared,
        dailyAmount: _n(7000),
        cashAmount: _n(4000),
        recordedAt: _stamp(5),
      );
      await spend(settling);
      await spend(
        CreateSupplierPaymentCommand(
          operationId: 'op-opening-settle',
          accountLineage: _lineage,
          expectedFence: await fence(),
          paymentId: 'opening-settle',
          journalId: 'j-opening-settle',
          supplierId: 's',
          date: _date(6),
          amount: _n(3500),
          fundingSource: FundingSource.daily,
          recordedAt: _stamp(6),
        ),
      );

      // Reopen before aggregate assertions, proving persisted complete state.
      final persisted = (await snapshot()).payload;
      await active!.close();
      active = null;
      await open();
      expect((await snapshot()).payload, persisted);
      state = await read();
      final expectedOutcomes = <(String, String, String)>[
        ('op-sale-refund', 'j-sale-refund', '2900'),
        ('op-return-partial', 'j-return-partial', '966'),
        ('op-return-final', 'j-return-final', '1934'),
        ('op-sale-void', 'j-sale-void', '2000'),
        ('op-void', 'j-void', '2000'),
        ('op-sale-kept', 'j-sale-kept', '2000'),
        ('op-expense', 'j-expense', '3000'),
        ('op-unpaid', 'j-unpaid', '9500'),
        ('op-immediate', 'j-immediate', '2000'),
        ('op-settle', 'j-settle', '11000'),
        ('op-opening-settle', 'j-opening-settle', '3500'),
      ];
      for (var i = 0; i < expectedOutcomes.length; i++) {
        final payload = jsonDecode(state.receipts[i].outcomePayload!) as Map;
        final expected = expectedOutcomes[i];
        expect((
          payload['operationId'],
          payload['journalId'],
          payload['netAmount'],
        ), expected);
        expect(
          state.journals
              .singleWhere((j) => j.journal.id == expected.$2)
              .metadata['operationId'],
          expected.$1,
        );
        expect(state.receipts[i].committedRevision, i + 2);
        expect(state.receipts[i].fence, (await snapshot()).fence);
      }
      final beforeReplay = await snapshot();
      final replay = await spending().executePayment(settling);
      expect(
        replay,
        isA<DurableCommandReplayed<RestaurantJournalSpendingOutcome>>(),
      );
      final replayed =
          replay as DurableCommandReplayed<RestaurantJournalSpendingOutcome>;
      expect(replayed.receipt, receipts[9]);
      expect((await snapshot()).revision, beforeReplay.revision);
      expect((await snapshot()).payload, beforeReplay.payload);

      const debit = JournalSide.debit, credit = JournalSide.credit;
      _journal(state, 'j-sale-refund', 'sale', 'sale-refund', 2, [
        ('asset:cash:daily', debit, 2900),
        ('revenue:sales', credit, 2900),
      ]);
      _journal(state, 'j-return-partial', 'saleReturn', 'return-partial', 3, [
        ('contra_revenue:sales_return', debit, 966),
        ('asset:cash:daily', credit, 966),
      ]);
      _journal(state, 'j-return-final', 'saleReturn', 'return-final', 4, [
        ('contra_revenue:sales_return', debit, 1934),
        ('asset:cash:daily', credit, 1934),
      ]);
      _journal(state, 'j-sale-void', 'sale', 'sale-void', 3, [
        ('asset:cash:daily', debit, 2000),
        ('revenue:sales', credit, 2000),
      ]);
      _journal(state, 'j-void', 'voidReversal', 'sale-void', 3, [
        ('asset:cash:daily', credit, 2000),
        ('revenue:sales', debit, 2000),
      ]);
      _journal(state, 'j-sale-kept', 'sale', 'sale-kept', 5, [
        ('asset:cash:daily', debit, 2000),
        ('revenue:sales', credit, 2000),
      ]);
      _journal(state, 'j-expense', 'expense', 'expense', 2, [
        ('expense:category:samoon', debit, 3000),
        ('asset:cash:daily', credit, 2000),
        ('asset:cash:cashbox', credit, 1000),
      ]);
      _journal(state, 'j-unpaid', 'purchaseInvoice', 'unpaid', 3, [
        ('expense:purchases', debit, 9500),
        ('liability:supplier:s', credit, 9500),
      ]);
      _journal(state, 'j-immediate', 'purchaseInvoice', 'immediate', 4, [
        ('expense:purchases', debit, 2000),
        ('liability:supplier:s', credit, 2000),
      ]);
      _journal(
        state,
        'j-pay-immediate',
        'supplierPayment',
        'pay-immediate',
        4,
        [
          ('liability:supplier:s', debit, 1500),
          ('asset:cash:cashbox', credit, 1500),
        ],
      );
      _journal(state, 'j-settle', 'supplierPayment', 'settle', 5, [
        ('liability:supplier:s', debit, 11000),
        ('asset:cash:daily', credit, 7000),
        ('asset:cash:cashbox', credit, 4000),
      ]);
      _journal(
        state,
        'j-opening-settle',
        'supplierPayment',
        'opening-settle',
        6,
        [
          ('liability:supplier:s', debit, 3500),
          ('asset:cash:daily', credit, 3500),
        ],
      );

      expect(state.journals.length, 13);
      expect(state.receipts.length, 11);
      expect(
        state.receipts.map((r) => r.sequence),
        orderedEquals(List.generate(11, (i) => i + 1)),
      );
      expect(
        state.receipts.map((r) => r.identity.operationId),
        orderedEquals([
          'op-sale-refund',
          'op-return-partial',
          'op-return-final',
          'op-sale-void',
          'op-void',
          'op-sale-kept',
          'op-expense',
          'op-unpaid',
          'op-immediate',
          'op-settle',
          'op-opening-settle',
        ]),
      );
      expect(state.receipts, receipts);
      expect(state.journals.map((j) => j.journal.id).toSet().length, 13);
      final voidEntry = state.journals.singleWhere(
        (j) => j.journal.id == 'j-void',
      );
      expect(voidEntry.journal.reversesId, 'j-sale-void');
      expect(voidEntry.recordedAt, _stamp(6));
      final saleRecords = _rows(state, 'sales');
      expect(saleRecords.map((s) => (s['id'], s['status'], s['number'])), [
        ('sale-refund', 'completed', 'S-000001'),
        ('sale-void', 'void', 'S-000002'),
        ('sale-kept', 'completed', 'S-000003'),
      ]);
      expect(
        _rows(
          state,
          'saleReturns',
        ).map((r) => (r['id'], r['saleId'], r['amount'])),
        [
          ('return-partial', 'sale-refund', 966),
          ('return-final', 'sale-refund', 1934),
        ],
      );
      expect(
        _rows(
          state,
          'payments',
        ).map((p) => (p['id'], p['invoiceAmount'], p['debtAmount'])),
        [
          ('pay-immediate', 1500, 0),
          ('settle', 9500, 1500),
          ('opening-settle', 0, 3500),
        ],
      );
      final supplier = _supplier(state);
      expect(supplier.invoiceDue('unpaid'), _n(0));
      expect(supplier.invoiceDue('immediate'), _n(500));
      expect(supplier.debtAvailable('s'), _n(0));
      expect(supplier.supplierBalance('s'), _n(500));
      final cash = DailyCashQueries(state.account),
          paid = DailyCashQueries(state.account).statement();
      expect(
        paid.rows.map((r) {
          final f = r['funding'] as Map;
          return (
            r['id'],
            r['date'],
            r['amount'],
            f['dailyAmount'],
            f['cashAmount'],
          );
        }).toSet(),
        {
          ('expense', '2026-01-02', 3000, 2000, 1000),
          ('pay-immediate', '2026-01-04', 1500, 0, 1500),
          ('settle', '2026-01-05', 11000, 7000, 4000),
          ('opening-settle', '2026-01-06', 3500, 3500, 0),
        },
      );
      expect(
        cash.statement(from: '2026-01-03', to: '2026-01-03').rows,
        isEmpty,
      );
      expect(cash.statement(source: SpendingSource.daily).total, _n(12500));
      expect(cash.statement(source: SpendingSource.cash).total, _n(6500));
      final immediateOutcome =
          jsonDecode(state.receipts[8].outcomePayload!) as Map;
      expect(immediateOutcome['paymentId'], 'pay-immediate');
      expect(immediateOutcome['paymentJournalId'], 'j-pay-immediate');
      expect(
        state.journals
            .singleWhere((j) => j.journal.id == 'j-pay-immediate')
            .metadata['operationId'],
        'op-immediate',
      );
      expect(paid.total, _n(19000));
      expect(paid.dailyShare, _n(12500));
      expect(paid.cashShare, _n(6500));
      expect(paid.rows.map((r) => r['id']).toSet(), {
        'expense',
        'pay-immediate',
        'settle',
        'opening-settle',
      });
      expect(cash.cashBalance, _n(43500));
      for (final example in <(int, int, int)>[
        (2, 2900, 2000),
        (3, -966, 0),
        (4, -1934, 0),
        (5, 2000, 7000),
        (6, 0, 3500),
      ]) {
        expect(cash.day('${_date(example.$1)}').netSales, _n(example.$2));
        expect(cash.day('${_date(example.$1)}').dailySpent, _n(example.$3));
      }
      // Independent fixed cumulative balances, with no production account defaults.
      final expectedBalances = {
        'asset:cash:daily': 89500,
        'asset:cash:cashbox': 43500,
        'liability:supplier:s': -500,
        'expense:purchases': 11500,
      };
      for (final expected in expectedBalances.entries) {
        final actual = state.journals
            .expand((j) => j.journal.lines)
            .where((l) => l.accountId == expected.key)
            .fold(
              BigInt.zero,
              (sum, line) =>
                  sum +
                  (line.side == debit ? line.amountUnits : -line.amountUnits),
            );
        expect(actual, _n(expected.value), reason: expected.key);
      }
      // Fixed dated effects include original-date void and return-date refunds.
      for (final example in <(int, String, int)>[
        (1, 'asset:cash:daily', 100000),
        (2, 'asset:cash:daily', 900),
        (3, 'asset:cash:daily', -966),
        (4, 'asset:cash:daily', -1934),
        (5, 'asset:cash:daily', -5000),
        (6, 'asset:cash:daily', -3500),
        (1, 'liability:supplier:s', -5000),
        (3, 'liability:supplier:s', -9500),
        (4, 'liability:supplier:s', -500),
        (5, 'liability:supplier:s', 11000),
        (6, 'liability:supplier:s', 3500),
      ]) {
        final actual = state.journals
            .where((j) => j.journal.effectiveDate == _date(example.$1))
            .expand((j) => j.journal.lines)
            .where((l) => l.accountId == example.$2)
            .fold(
              BigInt.zero,
              (sum, line) =>
                  sum +
                  (line.side == debit ? line.amountUnits : -line.amountUnits),
            );
        expect(actual, _n(example.$3), reason: '${example.$1} ${example.$2}');
      }
      final savedInvoice = _rows(
        state,
        'invoices',
      ).singleWhere((i) => i['id'] == 'unpaid');
      final savedLine = (savedInvoice['lines'] as List).single as Map;
      expect(
        (
          savedLine['quantityCartons'],
          savedLine['quantityPieces'],
          savedLine['priceCarton'],
          savedLine['pricePiece'],
        ),
        (2, 3, 4000, 500),
      );
      expect(savedInvoice['supplierId'], 's');
      expect(savedInvoice['date'], '${_date(3)}');
      final retained = saleRecords.singleWhere((s) => s['id'] == 'sale-refund');
      expect(retained['discount'], 100);
      expect(retained['paid'], 2900);
      final retainedLine = (retained['lines'] as List).single as Map;
      expect(
        (
          retainedLine['productId'],
          retainedLine['quantity'],
          retainedLine['price'],
        ),
        ('p', 3, 1000),
      );
      expect(state.journals.first.sourceType, 'cutoverOpening');
      expect(state.journals.first.sourceRecordId, 'synthetic-cutover');
      expect(
        state.journals.first.journal.lines.map(
          (l) => (l.accountId, l.side, l.amountUnits),
        ),
        [
          ('asset:cash:daily', debit, _n(100000)),
          ('asset:cash:cashbox', debit, _n(50000)),
          ('liability:supplier:s', credit, _n(5000)),
          ('equity:opening_balance', credit, _n(145000)),
        ],
      );

      // Rejected follow-ups preserve the complete accepted mixed history.
      final beforeReject = await snapshot();
      final voidReturned = await sales().executeVoid(
        SaleVoidCommand(
          operationId: 'reject-void-returned',
          accountLineage: _lineage,
          expectedFence: await fence(),
          saleId: 'sale-refund',
          reversalJournalId: 'reject-journal',
          reason: 'Synthetic invalid void',
          voidedAt: _stamp(7),
        ),
      );
      expect(
        voidReturned,
        isA<DurableCommandFailure<RestaurantJournalSaleOutcome>>(),
      );
      expect(
        (voidReturned as DurableCommandFailure<RestaurantJournalSaleOutcome>)
            .code,
        RestaurantJournalSaleErrorCodes.voidIneligibleSaleHasReturns,
      );
      final overpay = await spending().executePayment(
        CreateSupplierPaymentCommand(
          operationId: 'reject-overpay',
          accountLineage: _lineage,
          expectedFence: await fence(),
          paymentId: 'reject-payment',
          journalId: 'reject-payment-journal',
          supplierId: 's',
          invoiceId: 'immediate',
          date: _date(7),
          amount: _n(501),
          fundingSource: FundingSource.daily,
          recordedAt: _stamp(7),
        ),
      );
      expect(
        overpay,
        isA<DurableCommandFailure<RestaurantJournalSpendingOutcome>>(),
      );
      expect(
        (overpay as DurableCommandFailure<RestaurantJournalSpendingOutcome>)
            .code,
        RestaurantJournalSpendingErrorCodes.paymentExceedsLiability,
      );
      expect((await snapshot()).payload, beforeReject.payload);
      expect((await snapshot()).revision, beforeReject.revision);
      await checkStock(6, 16);
      expect(
        _codec.decodeState(_codec.encodeState(state)).toJson(),
        state.toJson(),
      );
    },
  );
}
