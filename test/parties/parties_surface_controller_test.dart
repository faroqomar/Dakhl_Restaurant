import 'package:dakhl_restaurant/parties/parties_surface_controller.dart';
import 'package:dakhl_restaurant/accounting/restaurant_journal_spending_commands.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar_application/madar_application.dart';
import 'package:madar_domain/madar_domain.dart';

import '../accounting/restaurant_journal_invoice_correction_commands_test.dart'
    show setup, lines, date;

void main() {
  test(
    'selected material identity and fresh creation identity stay distinct',
    () {
      final line = InvoiceLineForm(id: 'existing', name: 'Saved');
      expect(line.capture().materialIdForCreation, 'existing');
      expect(line.id, isNot(InvoiceLineForm(id: 'existing').id));
      line.selectedMaterialId = null;
      line.name = 'Independent new material';
      expect(line.capture().materialIdForCreation, isNot('existing'));
      expect(line.capture().materialIdForCreation, line.creationMaterialId);
    },
  );
  test(
    'create payment category override persists and omitted category replays',
    () async {
      final (_, owner) = await setup();
      addTearDown(owner.dispose);
      final editor = PartiesSurfaceController(operations: owner);
      addTearDown(editor.dispose);
      await editor.saveInvoice(
        InvoiceEditorSubmission(
          id: 'invoice',
          supplierId: 's',
          number: '1',
          date: '2026-11-07',
          note: '',
          lines: lines(1000),
        ),
      );
      final categories = (owner.account.toJson()['categories']! as List)
          .cast<Map<String, Object?>>();
      final category =
          categories.firstWhere((c) => c['id'] != 'samoon')['id']! as String;
      expect(
        await editor.savePaymentCreate(
          supplierId: 's',
          invoiceId: 'invoice',
          categoryId: category,
          dateText: '2026-11-07',
          amountText: '100',
          source: 'shared',
          dailyText: '60',
          cashText: '40',
          note: 'Created',
        ),
        isA<CapabilitySuccess<void>>(),
      );
      expect(owner.payments.single['categoryId'], category);
      expect(owner.payments.single['funding'], {
        'source': 'shared',
        'dailyAmount': 60,
        'cashAmount': 40,
      });
      final legacy = owner.supplierPaymentIntent(
        operationId: 'old',
        paymentId: 'old',
        journalId: 'old-journal',
        supplierId: 's',
        invoiceId: 'invoice',
        date: date('2026-11-07'),
        amount: BigInt.from(100),
        fundingSource: FundingSource.daily,
        recordedAt: '2026-11-07T12:00:00Z',
      );
      expect(await owner.submitPayment(legacy), isA<DurableCommandSuccess>());
      expect(owner.payments.last['categoryId'], 'samoon');
      expect(await owner.submitPayment(legacy), isA<DurableCommandReplayed>());
      expect(editor.invoiceDue('invoice'), BigInt.from(800));
      expect(
        await editor.deleteFinancial(
          original: owner.invoices.single,
          invoice: true,
          reason: 'Remove invoice',
        ),
        isA<CapabilityFailure<void>>(),
      );
      for (final row in List<Map<String, Object?>>.of(owner.payments)) {
        final result = await editor.deleteFinancial(
          original: row,
          invoice: false,
          reason: 'Remove payment',
        );
        expect(
          result,
          isA<CapabilitySuccess<void>>(),
          reason: result is CapabilityFailure<void> ? result.code : '',
        );
      }
      expect(editor.invoiceDue('invoice'), BigInt.from(1000));
      expect(
        await editor.deleteFinancial(
          original: owner.invoices.single,
          invoice: true,
          reason: 'Remove invoice',
        ),
        isA<CapabilitySuccess<void>>(),
      );
      expect(owner.invoices, isEmpty);
      expect(owner.payments, isEmpty);
    },
  );
  test('editor submissions persist invoice and immutable corrections through portable owner', () async {
    final (_, parties) = await setup();
    addTearDown(parties.dispose);
    final editor = PartiesSurfaceController(operations: parties);
    addTearDown(editor.dispose);
    expect(
      await editor.saveInvoice(
        InvoiceEditorSubmission(
          id: 'invoice',
          supplierId: 's',
          number: '1',
          date: '2026-11-07',
          note: 'Captured',
          lines: lines(1000),
        ),
      ),
      isA<CapabilitySuccess<void>>(),
    );
    final original = parties.invoices.single;
    expect(
      await editor.saveInvoice(
        InvoiceEditorSubmission(
          id: 'invoice',
          supplierId: 's',
          number: '1',
          date: '2026-11-07',
          note: 'Corrected',
          reason: 'Supplier correction',
          lines: lines(1200),
          expectedSource: original,
        ),
      ),
      isA<CapabilitySuccess<void>>(),
    );
    expect(parties.invoices.single['note'], 'Corrected');
    expect(editor.invoiceTotal(parties.invoices.single), BigInt.from(1200));
    expect(
      await parties.submitPayment(
        parties.supplierPaymentIntent(
          operationId: 'payment-op',
          paymentId: 'payment',
          journalId: 'payment-journal',
          supplierId: 's',
          invoiceId: 'invoice',
          date: date('2026-11-07'),
          amount: BigInt.from(100),
          fundingSource: FundingSource.daily,
          recordedAt: '2026-11-07T14:00:00Z',
        ),
      ),
      isA<DurableCommandSuccess<RestaurantJournalSpendingOutcome>>(),
    );
    final payment = parties.payments.single;
    expect(
      await editor.savePaymentEdit(
        original: payment,
        supplierId: 's',
        invoiceId: 'invoice',
        categoryId: 'samoon',
        dateText: '2026-11-07',
        amountText: '150',
        source: 'daily',
        dailyText: '150',
        cashText: '0',
        note: 'Corrected payment',
        reason: 'Amount correction',
      ),
      isA<CapabilitySuccess<void>>(),
    );
    expect(parties.payments.single['amount'], 150);
    expect(editor.invoiceDue('invoice'), BigInt.from(1050));
    expect(parties.invoices.length, 1);
    expect(parties.payments.length, 1);
  });
}
