import 'package:flutter_test/flutter_test.dart';
import 'package:madar_application/madar_application.dart';
import 'package:madar_domain/madar_domain.dart';
import 'package:dakhl_restaurant/accounts/legacy_account_codec.dart';
import 'package:dakhl_restaurant/accounts/portable_journal_codec.dart';
import 'package:dakhl_restaurant/parties/purchase_proposal.dart';
import 'package:dakhl_restaurant/parties/parties_operations_view_model.dart';

import '../sales/sales_workflow_session_test.dart' show fixture;
import '../accounts/accounts_view_model_test.dart' show FixtureStore;

DateOnly date(String text) =>
    DateOnly.parse(text, minimumYear: 1000, maximumYear: 9999);
List<PurchaseLine> lines(int amount) => [
  PurchaseLine(
    materialIdForCreation: 'm',
    name: 'Rice',
    unit: 'piece',
    quantityCartons: 0,
    quantityPieces: 1,
    priceCarton: 0,
    pricePiece: amount,
  ),
];
Future<(FixtureStore, PartiesOperationsViewModel)> setup() async {
  final (store, snapshot) = await fixture();
  const codec = PortableJournalCodec();
  final state = codec.decodeState(snapshot.payload);
  final account = const LegacyAccountCodec().decodeJson({
    ...state.account.toJson(),
    'suppliers': [
      {
        'id': 's',
        'name': 'Supplier',
        'phone': '',
        'note': '',
        'categoryId': 'samoon',
        'openingBalance': 0,
        'materials': <Map<String, Object?>>[],
      },
    ],
  });
  final seeded = await store.writeDocument(
    codec.encodeState(state.copyWith(account: account)),
    writeToken: 'seed',
    expected: snapshot,
  );
  final model = PartiesOperationsViewModel(
    store: store,
    snapshot: (seeded as CapabilitySuccess<DocumentSnapshot>).value,
    compareText: (a, b) => a.compareTo(b),
  );
  return (store, model);
}

void main() {
  test('invoice edit preserves original date inverse, create replay and corrected payment eligibility', () async {
    final (store, model) = await setup();
    addTearDown(model.dispose);
    final create = model.purchaseInvoiceIntent(
      operationId: 'create',
      invoiceId: 'invoice',
      invoiceJournalId: 'invoice-journal',
      supplierId: 's',
      invoiceNumber: '1',
      date: date('2026-11-07'),
      lines: lines(1000),
      recordedAt: '2026-11-07T10:00:00Z',
    );
    expect(await model.submitInvoice(create), isA<DurableCommandSuccess>());
    final before = model.invoices.single;
    final edit = model.editInvoiceIntent(
      operationId: 'edit',
      invoiceId: 'invoice',
      expectedSource: before,
      expectedActiveJournalId: 'invoice-journal',
      inverseJournalId: 'inverse',
      replacementJournalId: 'replacement',
      supplierId: 's',
      invoiceNumber: ' ٠٠٢ ',
      date: date('2026-11-08'),
      lines: lines(1500),
      note: ' revised ',
      reason: 'Correct invoice',
      recordedAt: '2026-11-09T10:00:00Z',
    );
    expect(
      await model.submitInvoiceCorrection(edit),
      isA<DurableCommandSuccess>(),
    );
    final changed = model.invoices.single;
    expect(changed['createdAt'], before['createdAt']);
    expect(changed['number'], '002');
    final state = const PortableJournalCodec().decodeState(
      store.document!.payload,
    );
    expect(
      state.journals
          .singleWhere((j) => j.journal.id == 'inverse')
          .journal
          .effectiveDate,
      date('2026-11-07'),
    );
    expect(
      state.journals
          .singleWhere((j) => j.journal.id == 'replacement')
          .journal
          .effectiveDate,
      date('2026-11-08'),
    );
    final writes = store.writes;
    expect(await model.submitInvoice(create), isA<DurableCommandReplayed>());
    expect(store.writes, writes);
    final payment = model.supplierPaymentIntent(
      operationId: 'pay',
      paymentId: 'pay',
      journalId: 'pay-journal',
      supplierId: 's',
      invoiceId: 'invoice',
      date: date('2026-11-08'),
      amount: BigInt.from(500),
      fundingSource: FundingSource.daily,
      recordedAt: '2026-11-08T12:00:00Z',
    );
    expect(await model.submitPayment(payment), isA<DurableCommandSuccess>());
    final second = model.editInvoiceIntent(
      operationId: 'edit2',
      invoiceId: 'invoice',
      expectedSource: model.invoices.single,
      expectedActiveJournalId: 'replacement',
      inverseJournalId: 'inverse2',
      replacementJournalId: 'replacement2',
      supplierId: 's',
      invoiceNumber: '3',
      date: date('2026-11-08'),
      lines: lines(1200),
      reason: 'Second correction',
      recordedAt: '2026-11-10T10:00:00Z',
    );
    expect(
      await model.submitInvoiceCorrection(second),
      isA<DurableCommandSuccess>(),
    );
    expect(
      await model.submitInvoiceCorrection(edit),
      isA<DurableCommandReplayed>(),
    );
    final invalid = model.editInvoiceIntent(
      operationId: 'invalid',
      invoiceId: 'invoice',
      expectedSource: model.invoices.single,
      expectedActiveJournalId: 'replacement2',
      inverseJournalId: 'bad-inverse',
      replacementJournalId: 'bad-replacement',
      supplierId: 's',
      invoiceNumber: '4',
      date: date('2026-11-08'),
      lines: lines(100),
      reason: 'Below paid',
      recordedAt: '2026-11-11T10:00:00Z',
    );
    final beforeFailure = store.document!.payload, count = store.writes;
    expect(
      await model.submitInvoiceCorrection(invalid),
      isA<DurableCommandFailure>(),
    );
    expect(store.document!.payload, beforeFailure);
    expect(store.writes, count);
  });

  test(
    'unpaid invoice deletion preserves create/edit/delete replay after reopen',
    () async {
      final (store, model) = await setup();
      addTearDown(model.dispose);
      final create = model.purchaseInvoiceIntent(
        operationId: 'create',
        invoiceId: 'invoice',
        invoiceJournalId: 'invoice-journal',
        supplierId: 's',
        invoiceNumber: '1',
        date: date('2026-11-07'),
        lines: lines(1000),
        recordedAt: '2026-11-07T10:00:00Z',
      );
      await model.submitInvoice(create);
      final edit = model.editInvoiceIntent(
        operationId: 'edit',
        invoiceId: 'invoice',
        expectedSource: model.invoices.single,
        expectedActiveJournalId: 'invoice-journal',
        inverseJournalId: 'inverse',
        replacementJournalId: 'replacement',
        supplierId: 's',
        invoiceNumber: '2',
        date: date('2026-11-08'),
        lines: lines(1500),
        reason: 'Correction',
        recordedAt: '2026-11-09T10:00:00Z',
      );
      expect(
        await model.submitInvoiceCorrection(edit),
        isA<DurableCommandSuccess>(),
      );
      final remove = model.deleteInvoiceIntent(
        operationId: 'delete',
        invoiceId: 'invoice',
        expectedSource: model.invoices.single,
        expectedActiveJournalId: 'replacement',
        inverseJournalId: 'delete-inverse',
        reason: 'Remove unpaid invoice',
        recordedAt: '2026-11-10T10:00:00Z',
      );
      expect(
        await model.submitInvoiceCorrection(remove),
        isA<DurableCommandSuccess>(),
      );
      expect(model.invoices, isEmpty);
      expect(model.activeInvoicePosting('invoice'), isNull);
      final reopened = PartiesOperationsViewModel(
        store: store,
        snapshot: store.document!,
        compareText: (a, b) => a.compareTo(b),
      );
      addTearDown(reopened.dispose);
      final count = store.writes;
      expect(
        await reopened.submitInvoice(create),
        isA<DurableCommandReplayed>(),
      );
      expect(
        await reopened.submitInvoiceCorrection(edit),
        isA<DurableCommandReplayed>(),
      );
      expect(
        await reopened.submitInvoiceCorrection(remove),
        isA<DurableCommandReplayed>(),
      );
      expect(store.writes, count);
    },
  );

  test('changed source and missing original posting fail closed', () async {
    final (store, model) = await setup();
    addTearDown(model.dispose);
    final create = model.purchaseInvoiceIntent(
      operationId: 'create',
      invoiceId: 'invoice',
      invoiceJournalId: 'invoice-journal',
      supplierId: 's',
      invoiceNumber: '1',
      date: date('2026-11-07'),
      lines: lines(1000),
      recordedAt: '2026-11-07T10:00:00Z',
    );
    await model.submitInvoice(create);
    final changed = model.editInvoiceIntent(
      operationId: 'stale',
      invoiceId: 'invoice',
      expectedSource: {...model.invoices.single, 'note': 'tampered'},
      expectedActiveJournalId: 'invoice-journal',
      inverseJournalId: 'inverse',
      replacementJournalId: 'replacement',
      supplierId: 's',
      invoiceNumber: '2',
      date: date('2026-11-08'),
      lines: lines(1500),
      reason: 'Correction',
      recordedAt: '2026-11-09T10:00:00Z',
    );
    final count = store.writes;
    expect(
      (await model.submitInvoiceCorrection(
        changed,
      ) as DurableCommandFailure).code,
      'invoice_source_changed',
    );
    expect(store.writes, count);
    final state = const PortableJournalCodec().decodeState(
      store.document!.payload,
    );
    final missing = state.copyWith(
      journals: state.journals.where((j) => j.journal.id != 'invoice-journal'),
      receipts: [],
    );
    final unposted = await store.writeDocument(
      const PortableJournalCodec().encodeState(missing),
      writeToken: 'fixture-unposted',
      expected: store.document,
    );
    final other = PartiesOperationsViewModel(
      store: store,
      snapshot: (unposted as CapabilitySuccess<DocumentSnapshot>).value,
      compareText: (a, b) => a.compareTo(b),
    );
    addTearDown(other.dispose);
    final intent = other.deleteInvoiceIntent(
      operationId: 'missing',
      invoiceId: 'invoice',
      expectedSource: other.invoices.single,
      expectedActiveJournalId: 'invoice-journal',
      inverseJournalId: 'missing-inverse',
      reason: 'No original',
      recordedAt: '2026-11-10T10:00:00Z',
    );
    expect(
      (await other.submitInvoiceCorrection(
        intent,
      ) as DurableCommandFailure).code,
      'invoice_history_mismatch',
    );
  });
}
