import 'package:dakhl_restaurant/accounting/restaurant_journal_mapper.dart';
import 'package:dakhl_restaurant/accounting/restaurant_journal_spending_commands.dart';
import 'package:dakhl_restaurant/accounts/legacy_account_codec.dart';
import 'package:dakhl_restaurant/accounts/portable_journal_codec.dart';
import 'package:dakhl_restaurant/accounts/portable_journal_state.dart';
import 'package:dakhl_restaurant/parties/parties_operations_view_model.dart';
import 'package:dakhl_restaurant/parties/purchase_operations_controller.dart';
import 'package:dakhl_restaurant/parties/purchase_proposal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar_application/madar_application.dart';
import 'package:madar_domain/madar_domain.dart';

import '../accounts/accounts_view_model_test.dart' show FixtureStore;

DateOnly date(String value) =>
    DateOnly.parse(value, minimumYear: 1000, maximumYear: 9999);

void main() {
  test('parties operations viewModel submits purchase invoice, supplier payment, and replays idempotently', () async {
    const legacy = LegacyAccountCodec();
    const codec = PortableJournalCodec();
    final raw = Map<String, Object?>.from(legacy.empty().toJson());
    raw['suppliers'] = [
      {
        'id': 'sup-1',
        'name': 'مورد اللحوم',
        'phone': '07700000000',
        'note': 'لحوم طازجة',
        'categoryId': 'samoon',
        'openingBalance': 50000,
        'archived': false,
        'materials': <Map<String, Object?>>[],
      },
    ];
    raw['materials'] = [
      {
        'id': 'mat-1',
        'name': 'لحم غنم',
        'unit': 'كغم',
        'priceCarton': 150000,
        'pricePiece': 15000,
        'archived': false,
      },
    ];
    final account = legacy.decodeJson(raw);
    final opening = RestaurantJournalMapper().mapVerifiedCutoverOpening(
      journalId: 'opening',
      effectiveDate: date('2026-11-01'),
      verifiedPhysicalRegisterCash: BigInt.from(100000),
      verifiedCashboxBalance: BigInt.from(50000),
      verifiedSupplierDebts: {'sup-1': BigInt.from(50000)},
    );
    final state = PortableJournalState(
      accountLineage: 'lineage-parties',
      account: account,
      sourceProvenance: const PortableJournalSourceProvenance(
        sourceVersion: 11,
        enrolledAt: '2026-11-01T00:00:00Z',
        migrated: false,
      ),
      cutoverState: PortableJournalCutoverState.established(
        cutoverDate: date('2026-11-01'),
        openingJournalId: 'opening',
      ),
      journals: [
        PortableJournalEntry(
          journal: opening.journal,
          sourceType: RestaurantJournalSourceType.cutoverOpening.name,
          sourceRecordId: 'opening-source',
          recordedAt: '2026-11-01T00:00:00Z',
        ),
      ],
    );
    final store = FixtureStore();
    final created = await store.writeDocument(
      codec.encodeState(state),
      writeToken: 'initial-parties',
    );
    final initial = (created as CapabilitySuccess<DocumentSnapshot>).value;

    final parties = PartiesOperationsViewModel(
      compareText: (a, b) => a.compareTo(b),
      snapshot: initial,
      store: store,
    );
    addTearDown(parties.dispose);

    expect(parties.postingEnabled, true);
    expect(parties.accountLineage, 'lineage-parties');
    expect(parties.suppliers.length, 1);
    expect(parties.materials.length, 1);

    // 1. Purchase Invoice with Lines
    final invoiceIntent = parties.purchaseInvoiceIntent(
      operationId: 'op-inv-1',
      invoiceId: 'inv-1',
      invoiceJournalId: 'jnl-inv-1',
      supplierId: 'sup-1',
      invoiceNumber: 'INV-101',
      date: date('2026-11-07'),
      lines: [
        PurchaseLine(
          materialIdForCreation: 'mat-1',
          name: 'لحم غنم',
          unit: 'كغم',
          quantityCartons: 1,
          quantityPieces: 0,
          priceCarton: 150000,
          pricePiece: 15000,
        ),
      ],
      note: 'First meat invoice',
      recordedAt: '2026-11-07T11:00:00Z',
    );

    final previewInv = parties.previewInvoice(invoiceIntent);
    expect(previewInv.rejected, false);

    final resultInv = await parties.submitInvoice(invoiceIntent);
    expect(
      resultInv,
      isA<DurableCommandSuccess<RestaurantJournalSpendingOutcome>>(),
    );
    expect(parties.selectedInvoiceId, 'inv-1');
    expect(parties.invoices.length, 1);
    expect(parties.invoices.first['number'], 'INV-101');

    // Replay check
    final writesBeforeReplay = store.writes;
    final replayInv = await parties.submitInvoice(invoiceIntent);
    expect(
      replayInv,
      isA<DurableCommandReplayed<RestaurantJournalSpendingOutcome>>(),
    );
    expect(store.writes, writesBeforeReplay);

    // 2. Supplier Debt Payment Intent & Submission
    final paymentIntent = parties.supplierPaymentIntent(
      operationId: 'op-pay-1',
      paymentId: 'pay-1',
      journalId: 'jnl-pay-1',
      supplierId: 'sup-1',
      invoiceId: 'inv-1',
      date: date('2026-11-07'),
      amount: BigInt.from(50000),
      fundingSource: FundingSource.daily,
      dailyAmount: BigInt.from(50000),
      cashAmount: BigInt.zero,
      note: 'Partial invoice payment',
      recordedAt: '2026-11-07T14:00:00Z',
    );

    final previewPay = parties.previewPayment(paymentIntent);
    expect(previewPay.rejected, false);

    final resultPay = await parties.submitPayment(paymentIntent);
    expect(
      resultPay,
      isA<DurableCommandSuccess<RestaurantJournalSpendingOutcome>>(),
    );
    expect(parties.selectedPaymentId, 'pay-1');
    expect(parties.payments.length, 1);
    expect(parties.payments.first['amount'], 50000);

    // 3. PurchaseOperationsController integration check
    final controller = PurchaseOperationsController(
      parties: parties,
      initialSupplierId: 'sup-1',
    );
    addTearDown(controller.dispose);

    expect(controller.selectedSupplierId, 'sup-1');
    expect(controller.selectedSupplier?.name, 'مورد اللحوم');

    final lineTotal = controller.calculateLineTotal(
      PurchaseLine(
        materialIdForCreation: 'mat-1',
        name: 'لحم غنم',
        unit: 'كغم',
        quantityCartons: 2,
        quantityPieces: 3,
        priceCarton: 100000,
        pricePiece: 10000,
      ),
    );
    expect(lineTotal, BigInt.from(230000));

    final split = controller.allocatePayment(
      supplierId: 'sup-1',
      invoiceId: 'inv-1',
      amount: BigInt.from(20000),
      date: date('2026-11-08'),
    );
    expect(split.selectedLiability, BigInt.from(20000));
  });
}
