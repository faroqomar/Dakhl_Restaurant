import 'package:dakhl_restaurant/accounting/restaurant_journal_mapper.dart';
import 'package:dakhl_restaurant/accounting/restaurant_journal_sale_commands.dart';
import 'package:dakhl_restaurant/accounts/legacy_account_codec.dart';
import 'package:dakhl_restaurant/accounts/portable_journal_codec.dart';
import 'package:dakhl_restaurant/accounts/portable_journal_state.dart';
import 'package:dakhl_restaurant/accounts/workspace_document.dart';
import 'package:dakhl_restaurant/sales/sales_workflow_session.dart';
import 'package:dakhl_restaurant/sales/ticket_workspace.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar_application/madar_application.dart';
import 'package:madar_domain/madar_domain.dart';

import '../accounts/accounts_view_model_test.dart' show FixtureStore;

DateOnly date(String value) =>
    DateOnly.parse(value, minimumYear: 1000, maximumYear: 9999);

Future<(FixtureStore, DocumentSnapshot)> fixture() async {
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
  return (store, initial);
}

TicketDraft fresh(String id) => TicketDraft(
  id: id,
  date: '2026-11-07',
  orderType: 'سفري',
  discount: '',
  note: '',
  lines: [],
);
void main() {
  test('checkout cleans finalized active only, preserving held and form through reopen', () async {
    final (store, snapshot) = await fixture();
    final draft = TicketDraft(
      id: 'active',
      date: '2026-11-07',
      orderType: 'سفري',
      discount: '',
      note: '',
      lines: [
        TicketLine(
          productId: 'p',
          quantityUnits: BigInt.from(1000),
          price: 1000,
        ),
      ],
    );
    final held = HeldTicket(
      id: 'held',
      label: 'Keep me',
      savedAt: '2026-11-07T10:00:00Z',
      draft: fresh('held-draft'),
    );
    await store.writeWorkspace(
      TicketWorkspace(
        active: draft,
        held: [held],
        form: {'account-form': 'retained'},
      ).toEnvelope().encode(),
      fence: snapshot.fence,
      expectedRevision: null,
      writeToken: 'draft',
    );
    final opened = await SalesWorkflowSession.open(
      commands: RestaurantJournalSaleCommandCoordinator(store: store),
      snapshot: snapshot,
      initial: fresh('new'),
    );
    final session = (opened as CapabilitySuccess<SalesWorkflowSession>).value;
    addTearDown(session.dispose);
    expect(session.active!.id, 'active');
    // Commit the sale, but lose the following workspace acknowledgement.
    store.workspaceWriteFailure = 'commit_unknown';
    final result = await session.checkout(
      fresh: fresh('next'),
      operationId: 'checkout-op',
      journalId: 'sale-journal',
      recordedAt: '2026-11-07T12:00:00Z',
    );
    expect(result, isA<CapabilityFailure<RestaurantJournalSaleOutcome>>());
    expect(session.checkoutPending, true);
    expect(session.operations.history.completedCount, 1);
    final writes = store.writes;
    expect(await session.addProduct('p'), isA<CapabilityFailure<void>>());
    store.workspaceWriteFailure = null;
    expect(
      await session.retryCheckout(),
      isA<CapabilitySuccess<RestaurantJournalSaleOutcome>>(),
    );
    expect(store.writes, writes);
    expect(session.active!.id, 'next');
    expect(session.active!.lines, isEmpty);
    expect(session.held.single.id, 'held');
    expect(
      WorkspaceDocument.decode(store.workspace!.payload).form['account-form'],
      'retained',
    );
    final reopened = await SalesWorkflowSession.open(
      commands: RestaurantJournalSaleCommandCoordinator(store: store),
      snapshot: session.operations.snapshot,
      initial: fresh('fallback'),
    );
    final successor =
        (reopened as CapabilitySuccess<SalesWorkflowSession>).value;
    addTearDown(successor.dispose);
    expect(successor.active!.id, 'next');
    expect(successor.held.single.id, 'held');
    expect(successor.operations.history.completedCount, 1);
  });
}
