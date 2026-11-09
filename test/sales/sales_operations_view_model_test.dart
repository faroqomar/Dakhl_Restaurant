import 'package:dakhl_restaurant/accounting/restaurant_journal_mapper.dart';
import 'package:dakhl_restaurant/accounting/restaurant_journal_sale_commands.dart';
import 'package:dakhl_restaurant/accounts/legacy_account_codec.dart';
import 'package:dakhl_restaurant/accounts/portable_journal_codec.dart';
import 'package:dakhl_restaurant/accounts/portable_journal_state.dart';
import 'package:dakhl_restaurant/sales/sales_operations_view_model.dart';
import 'package:dakhl_restaurant/sales/return_proposal.dart';
import 'package:dakhl_restaurant/sales/ticket_workspace.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar_application/madar_application.dart';
import 'package:madar_domain/madar_domain.dart';

import '../accounts/accounts_view_model_test.dart' show FixtureStore;

DateOnly date(String value) =>
    DateOnly.parse(value, minimumYear: 1000, maximumYear: 9999);

void main() {
  test('captured ticket checkout exposes saved receipt and replays without duplicates', () async {
    const legacy = LegacyAccountCodec();
    const codec = PortableJournalCodec();
    final account = legacy.decodeJson({
      ...legacy.empty().toJson(),
      'products': [
        {
          'id': 'p',
          'name': 'Product',
          'code': '',
          'unit': 'piece',
          'group': '',
          'price': 1000,
          'minStock': 0,
          'trackStock': false,
          'archived': false,
        },
      ],
    });
    final opening = RestaurantJournalMapper().mapVerifiedCutoverOpening(
      journalId: 'opening',
      effectiveDate: date('2026-11-01'),
      verifiedPhysicalRegisterCash: BigInt.from(10000),
      verifiedCashboxBalance: BigInt.zero,
      verifiedSupplierDebts: {},
    );
    final state = PortableJournalState(
      accountLineage: 'lineage',
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
      writeToken: 'initial',
    );
    final initial = (created as CapabilitySuccess<DocumentSnapshot>).value;
    final model = SalesOperationsViewModel(
      commands: RestaurantJournalSaleCommandCoordinator(store: store),
      snapshot: initial,
    );
    addTearDown(model.dispose);
    final ticket = TicketDraft(
      id: 'sale',
      date: '2026-11-07',
      orderType: account.preferences.orderTypes.first,
      discount: '١٠٠',
      note: 'Captured',
      lines: [
        TicketLine(
          productId: 'p',
          quantityUnits: BigInt.from(1500),
          price: 800,
        ),
      ],
    );
    final intent = model.checkoutIntent(
      ticket: ticket,
      operationId: 'sale-op',
      journalId: 'sale-journal',
      recordedAt: '2026-11-07T12:00:00Z',
    );
    expect(model.preview(intent).rejected, false);
    expect(
      await model.submit(intent),
      isA<DurableCommandSuccess<RestaurantJournalSaleOutcome>>(),
    );
    expect(model.selectedSale!['paid'], 1100);
    expect(model.selectedSale!['note'], 'Captured');
    expect(
      ((model.selectedSale!['lines'] as List).single as Map)['price'],
      800,
    );
    expect(model.history.completedCount, 1);
    final writes = store.writes;
    expect(
      await model.submit(intent),
      isA<DurableCommandReplayed<RestaurantJournalSaleOutcome>>(),
    );
    expect(store.writes, writes);
    expect(model.history.completedCount, 1);
    expect(model.acceptSnapshot(initial), isA<CapabilityFailure<void>>());
    expect(model.history.completedCount, 1);
    expect(model.needsReadback, false);
    final refund = model.returnIntent(
      operationId: 'refund-op',
      saleId: 'sale',
      returnId: 'refund',
      journalId: 'refund-journal',
      date: date('2026-11-08'),
      today: date('2026-11-08'),
      reason: 'Customer return',
      recordedAt: '2026-11-08T12:00:00Z',
      lines: [
        ReturnLineRequest(
          productId: 'p',
          quantityUnits: BigInt.from(1500),
          restock: false,
        ),
      ],
    );
    expect(model.preview(refund).rejected, false);
    expect(
      await model.submit(refund),
      isA<DurableCommandSuccess<RestaurantJournalSaleOutcome>>(),
    );
    expect(model.selectedReturns.single['amount'], 1100);
    expect(model.history.refunded, BigInt.from(1100));
    expect(model.history.netMovement, BigInt.zero);
    final beforeVoid = store.writes;
    final voidIntent = model.voidIntent(
      operationId: 'void-op',
      saleId: 'sale',
      reversalJournalId: 'void-journal',
      reason: 'Wrong sale',
      voidedAt: '2026-11-08T13:00:00Z',
    );
    expect(model.preview(voidIntent).rejected, true);
    expect(
      await model.submit(voidIntent),
      isA<DurableCommandFailure<RestaurantJournalSaleOutcome>>(),
    );
    expect(store.writes, beforeVoid);
    expect(model.selectedSale!['status'], 'completed');
  });
}
