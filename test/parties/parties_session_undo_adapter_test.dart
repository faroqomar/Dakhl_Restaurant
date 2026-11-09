import 'package:flutter_test/flutter_test.dart';
import 'package:madar_application/madar_application.dart';
import 'package:madar_domain/madar_domain.dart';
import 'package:dakhl_restaurant/accounting/financial_session_undo.dart';
import 'package:dakhl_restaurant/accounts/legacy_account_codec.dart';
import 'package:dakhl_restaurant/accounts/portable_journal_codec.dart';
import 'package:dakhl_restaurant/parties/parties_operations_view_model.dart';
import 'package:dakhl_restaurant/parties/parties_session_undo_adapter.dart';
import 'package:dakhl_restaurant/parties/purchase_proposal.dart';

import '../accounts/accounts_view_model_test.dart' show FixtureStore;
import '../accounting/restaurant_journal_invoice_correction_commands_test.dart'
    as invoices;

Future<(FixtureStore, PartiesOperationsViewModel)> setup() async {
  final (store, model) = await invoices.setup();
  const codec = PortableJournalCodec();
  final state = codec.decodeState(model.snapshot.payload);
  final candidate = state.copyWith(
    account: const LegacyAccountCodec().decodeJson({
      ...state.account.toJson(),
      'materials': [
        {
          'id': 'm',
          'name': 'Rice',
          'unit': 'piece',
          'priceCarton': 0,
          'pricePiece': 1000,
          'archived': false,
        },
      ],
    }),
  );
  final saved = await store.writeDocument(
    codec.encodeState(candidate),
    writeToken: 'seed-material',
    expected: model.snapshot,
  );
  expect(
    model.acceptSnapshot((saved as CapabilitySuccess<DocumentSnapshot>).value),
    isA<CapabilitySuccess<void>>(),
  );
  return (store, model);
}

void register(
  FinancialSessionUndoController undo,
  PartiesOperationsViewModel model,
  DocumentSnapshot before,
  DurableCommandResult result,
) {
  final receipt = switch (result) {
    DurableCommandSuccess(:final receipt) => receipt,
    DurableCommandReplayed(:final receipt) => receipt,
    _ => throw StateError('Fixture not committed'),
  };
  expect(
    undo.register(
      before: before,
      result: result,
      adapter: PartiesSessionUndoAdapter(
        parties: model,
        identity: receipt.identity,
      ),
    ),
    isA<CapabilitySuccess<void>>(),
  );
}

Future<DurableCommandResult> createInvoice(PartiesOperationsViewModel model) =>
    model.submitInvoice(
      model.purchaseInvoiceIntent(
        operationId: 'create-invoice',
        invoiceId: 'invoice',
        invoiceJournalId: 'invoice-root',
        supplierId: 's',
        invoiceNumber: '1',
        date: invoices.date('2026-11-07'),
        lines: invoices.lines(1000),
        recordedAt: '2026-11-07T10:00:00Z',
      ),
    );
void main() {
  restorationCases();
  sourceOrderCases();
  test('invoice edit then create undo restore prior source while retaining posting history', () async {
    final (store, m) = await setup();
    addTearDown(m.dispose);
    final undo = FinancialSessionUndoController(
      readSnapshot: () => m.snapshot,
      isWriteBlocked: () => false,
    );
    addTearDown(undo.dispose);
    final originalBefore = m.snapshot;
    final created = await createInvoice(m);
    register(undo, m, originalBefore, created);
    final before = m.snapshot;
    final edit = m.editInvoiceIntent(
      operationId: 'edit-invoice',
      invoiceId: 'invoice',
      expectedSource: m.invoices.single,
      expectedActiveJournalId: 'invoice-root',
      inverseJournalId: 'invoice-inverse',
      replacementJournalId: 'invoice-replacement',
      supplierId: 's',
      invoiceNumber: '2',
      date: invoices.date('2026-11-08'),
      lines: invoices.lines(1500),
      note: 'Changed',
      reason: 'Correct',
      recordedAt: '2026-11-08T10:00:00Z',
    );
    register(undo, m, before, await m.submitInvoiceCorrection(edit));
    expect(
      await undo.undo(),
      isA<CapabilitySuccess<void>>(),
      reason: undo.errorCode,
    );
    expect(m.invoices.single['number'], '1');
    expect((m.invoices.single['lines'] as List).single['pricePiece'], 1000);
    final retained = const PortableJournalCodec()
        .decodeState(m.snapshot.payload)
        .journals
        .map((j) => j.toJson())
        .toList();
    expect(
      await undo.undo(),
      isA<CapabilitySuccess<void>>(),
      reason: undo.errorCode,
    );
    expect(m.invoices, isEmpty);
    expect(undo.length, 0);
    final after = const PortableJournalCodec().decodeState(m.snapshot.payload);
    expect(
      after.journals.take(retained.length).map((j) => j.toJson()).toList(),
      retained,
    );
    final writes = store.writes;
    expect(await createInvoice(m), isA<DurableCommandReplayed>());
    expect(store.writes, writes);
  });
  test(
    'payment edit and uncertain create undo restore settlement and pop once',
    () async {
      final (store, m) = await setup();
      addTearDown(m.dispose);
      await createInvoice(m);
      final undo = FinancialSessionUndoController(
        readSnapshot: () => m.snapshot,
        isWriteBlocked: () => false,
      );
      addTearDown(undo.dispose);
      final before = m.snapshot;
      final payment = m.supplierPaymentIntent(
        operationId: 'pay-create',
        paymentId: 'payment',
        journalId: 'payment-root',
        supplierId: 's',
        invoiceId: 'invoice',
        date: invoices.date('2026-11-07'),
        amount: BigInt.from(200),
        fundingSource: FundingSource.daily,
        recordedAt: '2026-11-07T11:00:00Z',
      );
      register(undo, m, before, await m.submitPayment(payment));
      final beforeEdit = m.snapshot;
      final edit = m.editPaymentIntent(
        operationId: 'pay-edit',
        paymentId: 'payment',
        expectedActiveJournalId: 'payment-root',
        expectedSource: m.payments.single,
        inverseJournalId: 'payment-inverse',
        replacementJournalId: 'payment-replacement',
        date: invoices.date('2026-11-08'),
        categoryId: 'samoon',
        supplierId: 's',
        invoiceId: 'invoice',
        invoiceAmount: BigInt.from(400),
        debtAmount: BigInt.zero,
        amount: BigInt.from(400),
        fundingSource: FundingSource.daily,
        reason: 'Correct',
        recordedAt: '2026-11-08T10:00:00Z',
      );
      register(undo, m, beforeEdit, await m.submitPaymentCorrection(edit));
      expect(
        await undo.undo(),
        isA<CapabilitySuccess<void>>(),
        reason: undo.errorCode,
      );
      expect(m.payments.single['amount'], 200);
      expect(m.payments.single['date'], '2026-11-07');
      store.writeFailure = 'commit_unknown';
      expect(await undo.undo(), isA<CapabilityFailure<void>>());
      expect(undo.needsReadback, true);
      expect(undo.length, 1);
      store.writeFailure = null;
      expect(
        await undo.undo(),
        isA<CapabilitySuccess<void>>(),
        reason: undo.errorCode,
      );
      expect(m.payments, isEmpty);
      expect(undo.length, 0);
      final writes = store.writes;
      expect(await m.submitPayment(payment), isA<DurableCommandReplayed>());
      expect(store.writes, writes);
    },
  );
  test('inline-paid invoice undo removes its material/payment/source in one revision', () async {
    final (store, m) = await invoices.setup();
    addTearDown(m.dispose);
    final undo = FinancialSessionUndoController(
      readSnapshot: () => m.snapshot,
      isWriteBlocked: () => false,
    );
    addTearDown(undo.dispose);
    final before = m.snapshot;
    // Inline payment is part of the same original acknowledged command.
    final command = m.purchaseInvoiceIntent(
      operationId: 'inline',
      invoiceId: 'invoice',
      invoiceJournalId: 'invoice-root',
      supplierId: 's',
      invoiceNumber: '1',
      date: invoices.date('2026-11-07'),
      lines: invoices.lines(1000),
      immediatePayment: const PurchasePayment(
        id: 'payment',
        amount: 200,
        source: 'daily',
        dailyAmount: 200,
      ),
      paymentJournalId: 'payment-root',
      recordedAt: '2026-11-07T10:00:00Z',
    );
    register(undo, m, before, await m.submitInvoice(command));
    final writes = store.writes;
    final prior = const PortableJournalCodec().decodeState(m.snapshot.payload);
    final revision = m.snapshot.revision;
    store.writeFailure = 'commit_unknown';
    expect(await undo.undo(), isA<CapabilityFailure<void>>());
    expect(undo.needsReadback, true);
    expect(undo.length, 1);
    expect(m.invoices.length, 1);
    expect(m.payments.length, 1);
    expect(m.materials.length, 1);
    expect(m.snapshot.revision, revision);
    store.writeFailure = null;
    expect(
      await undo.undo(),
      isA<CapabilitySuccess<void>>(),
      reason: undo.errorCode,
    );
    expect(undo.length, 0);
    expect(m.invoices, isEmpty);
    expect(m.payments, isEmpty);
    expect(m.materials, isEmpty);
    expect(store.writes, writes + 2);
    expect(m.snapshot.revision, revision + 1);
    final after = const PortableJournalCodec().decodeState(m.snapshot.payload);
    expect(after.receipts.length, prior.receipts.length + 1);
    expect(after.journals.length, prior.journals.length + 2);
    final replayWrites = store.writes;
    expect(await m.submitInvoice(command), isA<DurableCommandReplayed>());
    expect(store.writes, replayWrites);
  });
}

// Kept separate from the baseline cases so retained-ID restoration has its own
// focused acceptance receipt.
void restorationCases() {
  test('deleted invoice undo restores retained ID and allows later correction and old replay', () async {
    final (store, m) = await setup();
    addTearDown(m.dispose);
    await createInvoice(m);
    final original = m.invoices.single;
    final undo = FinancialSessionUndoController(
      readSnapshot: () => m.snapshot,
      isWriteBlocked: () => false,
    );
    addTearDown(undo.dispose);
    final before = m.snapshot;
    final command = m.deleteInvoiceIntent(
      operationId: 'delete-invoice',
      invoiceId: 'invoice',
      expectedSource: original,
      expectedActiveJournalId: 'invoice-root',
      inverseJournalId: 'delete-inverse',
      reason: 'Cancelled',
      recordedAt: '2026-11-08T10:00:00Z',
    );
    register(undo, m, before, await m.submitInvoiceCorrection(command));
    expect(m.invoices, isEmpty);
    expect(
      await undo.undo(),
      isA<CapabilitySuccess<void>>(),
      reason: undo.errorCode,
    );
    expect(m.invoices.single, original);
    final active = m.activeInvoicePosting('invoice');
    expect(active, isNotNull);
    expect(active!.journal.reversesId, isNull);
    expect(active.correctedFromJournalId, 'invoice-root');
    expect(
      await m.submitInvoiceCorrection(
        m.editInvoiceIntent(
          operationId: 'later-edit',
          invoiceId: 'invoice',
          expectedSource: original,
          expectedActiveJournalId: active.journal.id,
          inverseJournalId: 'later-inverse',
          replacementJournalId: 'later-replacement',
          supplierId: 's',
          invoiceNumber: '2',
          date: invoices.date('2026-11-08'),
          lines: invoices.lines(1500),
          reason: 'Later correct',
          recordedAt: '2026-11-09T10:00:00Z',
        ),
      ),
      isA<DurableCommandSuccess>(),
    );
    final writes = store.writes;
    expect(
      await m.submitInvoiceCorrection(command),
      isA<DurableCommandReplayed>(),
    );
    expect(await createInvoice(m), isA<DurableCommandReplayed>());
    expect(store.writes, writes);
  });
  test('deleted payment undo retries exact retained settlement without erasing deletion', () async {
    final (store, m) = await setup();
    addTearDown(m.dispose);
    await createInvoice(m);
    final created = m.supplierPaymentIntent(
      operationId: 'payment-create',
      paymentId: 'payment',
      journalId: 'payment-root',
      supplierId: 's',
      invoiceId: 'invoice',
      date: invoices.date('2026-11-07'),
      amount: BigInt.from(200),
      fundingSource: FundingSource.daily,
      recordedAt: '2026-11-07T11:00:00Z',
    );
    expect(await m.submitPayment(created), isA<DurableCommandSuccess>());
    final original = m.payments.single;
    final undo = FinancialSessionUndoController(
      readSnapshot: () => m.snapshot,
      isWriteBlocked: () => false,
    );
    addTearDown(undo.dispose);
    final before = m.snapshot;
    final command = m.deletePaymentIntent(
      operationId: 'payment-delete',
      paymentId: 'payment',
      expectedActiveJournalId: 'payment-root',
      expectedSource: original,
      inverseJournalId: 'delete-inverse',
      reason: 'Cancelled',
      recordedAt: '2026-11-08T10:00:00Z',
    );
    register(undo, m, before, await m.submitPaymentCorrection(command));
    store.writeFailure = 'commit_unknown';
    expect(await undo.undo(), isA<CapabilityFailure<void>>());
    expect(undo.needsReadback, true);
    store.writeFailure = null;
    expect(
      await undo.undo(),
      isA<CapabilitySuccess<void>>(),
      reason: undo.errorCode,
    );
    expect(m.payments.single, original);
    expect(undo.length, 0);
    final state = const PortableJournalCodec().decodeState(m.snapshot.payload);
    expect(state.journals.any((j) => j.journal.id == 'delete-inverse'), true);
    final restored = state.journals.last;
    expect(restored.journal.reversesId, isNull);
    expect(restored.correctedFromJournalId, 'payment-root');
    final writes = store.writes;
    expect(
      await m.submitPaymentCorrection(command),
      isA<DurableCommandReplayed>(),
    );
    expect(await m.submitPayment(created), isA<DurableCommandReplayed>());
    expect(store.writes, writes);
  });
}

void sourceOrderCases() {
  test('invoice edit undo restores order and inline material while preserving unrelated current metadata', () async {
    final (store, m) = await setup();
    addTearDown(m.dispose);
    await createInvoice(m);
    expect(
      await m.submitInvoice(
        m.purchaseInvoiceIntent(
          operationId: 'second-create',
          invoiceId: 'second',
          invoiceJournalId: 'second-root',
          supplierId: 's',
          invoiceNumber: '2',
          date: invoices.date('2026-11-07'),
          lines: invoices.lines(1000),
          recordedAt: '2026-11-07T11:00:00Z',
        ),
      ),
      isA<DurableCommandSuccess>(),
    );
    const codec = PortableJournalCodec();
    final before = codec.decodeState(m.snapshot.payload),
        original = m.invoices.first;
    final edit = m.editInvoiceIntent(
      operationId: 'first-edit',
      invoiceId: 'invoice',
      expectedSource: original,
      expectedActiveJournalId: 'invoice-root',
      inverseJournalId: 'first-inverse',
      replacementJournalId: 'first-replacement',
      supplierId: 's',
      invoiceNumber: '1R',
      date: invoices.date('2026-11-08'),
      lines: const [
        PurchaseLine(
          materialIdForCreation: 'new-material',
          name: 'Beans',
          unit: 'piece',
          quantityCartons: 0,
          quantityPieces: 1,
          priceCarton: 0,
          pricePiece: 1500,
        ),
      ],
      reason: 'Correct',
      recordedAt: '2026-11-08T10:00:00Z',
    );
    final result = await m.submitInvoiceCorrection(edit);
    expect(result, isA<DurableCommandSuccess>());
    final after = codec.decodeState(m.snapshot.payload);
    final raw = m.account.toJson();
    final current = after.copyWith(
      account: const LegacyAccountCodec().decodeJson({
        ...raw,
        'products': [
          for (final p
              in (raw['products']! as List).cast<Map<String, Object?>>())
            {...p, 'archived': true},
        ],
        'materials': [
          ...raw['materials']! as List,
          {
            'id': 'unrelated',
            'name': 'Salt',
            'unit': 'piece',
            'priceCarton': 0,
            'pricePiece': 1,
            'archived': false,
          },
        ],
      }),
    );
    final saved = await store.writeDocument(
      codec.encodeState(current),
      writeToken: 'unrelated-metadata',
      expected: m.snapshot,
    );
    expect(
      m.acceptSnapshot((saved as CapabilitySuccess<DocumentSnapshot>).value),
      isA<CapabilitySuccess<void>>(),
    );
    final attempt = PartiesSessionUndoAdapter(
      parties: m,
      identity: (result as DurableCommandSuccess).receipt.identity,
    ).prepare(before: before, after: after, current: current);
    expect(await attempt.execute!(), isA<DurableCommandSuccess>());
    expect(m.invoices.map((r) => r['id']).toList(), ['invoice', 'second']);
    expect(m.invoices.first, original);
    expect((m.account.toJson()['products']! as List).first['archived'], true);
    expect(m.materials.map((r) => r.id).toList(), ['m', 'unrelated']);
    final writes = store.writes;
    expect(
      await m.submitInvoiceCorrection(edit),
      isA<DurableCommandReplayed>(),
    );
    expect(store.writes, writes);
  });
  test('payment edit undo restores prior source position without changing sibling settlement', () async {
    final (_, m) = await setup();
    addTearDown(m.dispose);
    await createInvoice(m);
    for (final id in ['first', 'second']) {
      expect(
        await m.submitPayment(
          m.supplierPaymentIntent(
            operationId: '$id-create',
            paymentId: id,
            journalId: '$id-root',
            supplierId: 's',
            invoiceId: 'invoice',
            date: invoices.date('2026-11-07'),
            amount: BigInt.from(200),
            fundingSource: FundingSource.daily,
            recordedAt: '2026-11-07T11:00:00Z',
          ),
        ),
        isA<DurableCommandSuccess>(),
      );
    }
    final original = [...m.payments], before = m.snapshot;
    final undo = FinancialSessionUndoController(
      readSnapshot: () => m.snapshot,
      isWriteBlocked: () => false,
    );
    addTearDown(undo.dispose);
    final edit = m.editPaymentIntent(
      operationId: 'first-edit',
      paymentId: 'first',
      expectedActiveJournalId: 'first-root',
      expectedSource: m.payments.first,
      inverseJournalId: 'first-inverse',
      replacementJournalId: 'first-replacement',
      date: invoices.date('2026-11-08'),
      categoryId: 'samoon',
      supplierId: 's',
      invoiceId: 'invoice',
      invoiceAmount: BigInt.from(300),
      debtAmount: BigInt.zero,
      amount: BigInt.from(300),
      fundingSource: FundingSource.daily,
      reason: 'Correct',
      recordedAt: '2026-11-08T10:00:00Z',
    );
    register(undo, m, before, await m.submitPaymentCorrection(edit));
    expect(m.payments.map((r) => r['id']).toList(), ['second', 'first']);
    expect(
      await undo.undo(),
      isA<CapabilitySuccess<void>>(),
      reason: undo.errorCode,
    );
    expect(m.payments, original);
  });
}
