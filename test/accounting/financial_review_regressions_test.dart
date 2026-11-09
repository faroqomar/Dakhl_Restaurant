import 'package:dakhl_restaurant/accounting/restaurant_journal_mapper.dart';
import 'package:dakhl_restaurant/accounting/restaurant_journal_sale_commands.dart';
import 'package:dakhl_restaurant/accounts/portable_journal_codec.dart';
import 'package:dakhl_restaurant/parties/purchase_proposal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar_application/madar_application.dart';
import 'package:madar_domain/madar_domain.dart';

import '../sales/sales_workflow_session_test.dart' show fixture;
import 'restaurant_journal_invoice_correction_commands_test.dart' as invoices;

void main() {
  test(
    'custom account sale creates and replays after coordinator reopen',
    () async {
      final (store, snapshot) = await fixture();
      final mapper = RestaurantJournalMapper(
        profile: const RestaurantAccountProfile(
          dailyCashAccountId: 'custom:daily',
          salesRevenueAccountId: 'custom:sales',
        ),
      );
      final command = CompleteSaleCommand(
        operationId: 'custom-sale',
        accountLineage: 'lineage',
        expectedFence: snapshot.fence,
        saleId: 'custom-sale',
        journalId: 'custom-sale-journal',
        draft: {
          'date': '2026-11-07',
          'discount': 0,
          'lines': [
            {'productId': 'p', 'quantity': 1},
          ],
        },
        recordedAt: '2026-11-07T10:00:00Z',
      );
      expect(
        await RestaurantJournalSaleCommandCoordinator(
          store: store,
          mapper: mapper,
        ).executeSale(command),
        isA<DurableCommandSuccess>(),
      );
      final state = const PortableJournalCodec().decodeState(
        store.document!.payload,
      );
      expect(
        state.journals.last.journal.lines.map((line) => line.accountId),
        containsAll(['custom:daily', 'custom:sales']),
      );
      final writes = store.writes, payload = store.document!.payload;
      expect(
        await RestaurantJournalSaleCommandCoordinator(
          store: store,
          mapper: mapper,
        ).executeSale(command),
        isA<DurableCommandReplayed>(),
      );
      expect(store.writes, writes);
      expect(store.document!.payload, payload);
      expect(
        await RestaurantJournalSaleCommandCoordinator(store: store)
            .executeSale(command),
        isA<DurableCommandFailure>(),
      );
      expect(store.writes, writes);
    },
  );

  test(
    'corrected invoice retains inline-payment authority during replacement',
    () async {
      final (store, model) = await invoices.setup();
      addTearDown(model.dispose);
      final create = model.purchaseInvoiceIntent(
        operationId: 'inline-create',
        invoiceId: 'invoice',
        invoiceJournalId: 'invoice-journal',
        supplierId: 's',
        invoiceNumber: '1',
        date: invoices.date('2026-11-07'),
        lines: invoices.lines(1000),
        immediatePayment: const PurchasePayment(
          id: 'inline',
          amount: 200,
          source: 'daily',
        ),
        paymentJournalId: 'inline-journal',
        recordedAt: '2026-11-07T10:00:00Z',
      );
      expect(await model.submitInvoice(create), isA<DurableCommandSuccess>());
      final editInvoice = model.editInvoiceIntent(
        operationId: 'invoice-edit',
        invoiceId: 'invoice',
        expectedSource: model.invoices.single,
        expectedActiveJournalId: 'invoice-journal',
        inverseJournalId: 'invoice-inverse',
        replacementJournalId: 'invoice-replacement',
        supplierId: 's',
        invoiceNumber: '1',
        date: invoices.date('2026-11-07'),
        lines: invoices.lines(1200),
        reason: 'Correct saved price',
        recordedAt: '2026-11-07T11:00:00Z',
      );
      expect(
        await model.submitInvoiceCorrection(editInvoice),
        isA<DurableCommandSuccess>(),
      );
      final editPayment = model.editPaymentIntent(
        operationId: 'inline-edit',
        paymentId: 'inline',
        expectedActiveJournalId: 'inline-journal',
        expectedSource: model.payments.single,
        inverseJournalId: 'inline-inverse',
        replacementJournalId: 'inline-replacement',
        date: invoices.date('2026-11-07'),
        categoryId: 'samoon',
        supplierId: 's',
        invoiceId: 'invoice',
        invoiceAmount: BigInt.from(100),
        debtAmount: BigInt.zero,
        amount: BigInt.from(100),
        fundingSource: FundingSource.daily,
        note: 'Correct inline payment',
        reason: 'Correct amount',
        recordedAt: '2026-11-07T12:00:00Z',
      );
      expect(
        await model.submitPaymentCorrection(editPayment),
        isA<DurableCommandSuccess>(),
      );
      expect(model.payments.single['amount'], 100);
      expect(model.payments.single['note'], 'Correct inline payment');
      final state = const PortableJournalCodec().decodeState(
        store.document!.payload,
      );
      expect(state.journals.length, 7);
      expect(state.receipts.length, 3);
      final writes = store.writes;
      expect(
        await model.submitPaymentCorrection(editPayment),
        isA<DurableCommandReplayed>(),
      );
      expect(store.writes, writes);
      final overpay = model.editPaymentIntent(
        operationId: 'inline-overpay',
        paymentId: 'inline',
        expectedActiveJournalId: 'inline-replacement',
        expectedSource: model.payments.single,
        inverseJournalId: 'overpay-inverse',
        replacementJournalId: 'overpay-replacement',
        date: invoices.date('2026-11-07'),
        categoryId: 'samoon',
        supplierId: 's',
        invoiceId: 'invoice',
        invoiceAmount: BigInt.from(1201),
        debtAmount: BigInt.zero,
        amount: BigInt.from(1201),
        fundingSource: FundingSource.daily,
        reason: 'Invalid excess',
        recordedAt: '2026-11-07T13:00:00Z',
      );
      final payload = store.document!.payload;
      expect(
        await model.submitPaymentCorrection(overpay),
        isA<DurableCommandFailure>(),
      );
      expect(store.writes, writes);
      expect(store.document!.payload, payload);
    },
  );
}
