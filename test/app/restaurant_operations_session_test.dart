import 'package:flutter_test/flutter_test.dart';
import 'package:madar_application/madar_application.dart';
import 'package:madar_domain/madar_domain.dart';
import 'package:dakhl_restaurant/accounts/legacy_account_codec.dart';
import 'package:dakhl_restaurant/accounts/portable_journal_codec.dart';
import 'package:dakhl_restaurant/parties/purchase_proposal.dart';
import 'package:dakhl_restaurant/app/restaurant_operations_session.dart';

import '../sales/sales_workflow_session_test.dart' show fixture, fresh;

void main() {
  test(
    'nonrecorded business rejection preserves acknowledged workflow snapshots',
    () async {
      final (store, snapshot) = await fixture();
      final opened = await RestaurantOperationsSession.open(
        store: store,
        snapshot: snapshot,
        compareText: (a, b) => a.compareTo(b),
        fresh: fresh('active'),
      );
      final session =
          (opened as CapabilitySuccess<RestaurantOperationsSession>).value;
      addTearDown(session.dispose);
      final result = await session.dailyCash.recordExpense(
        operationId: 'rejected-expense',
        expenseId: 'rejected-expense',
        journalId: 'rejected-journal',
        categoryId: 'missing-category',
        amount: BigInt.one,
        fundingSource: FundingSource.daily,
        recordedAt: '2026-11-07T10:00:00Z',
      );
      expect(result, isA<DurableCommandFailure>());
      final rejection = result as DurableCommandFailure;
      expect(rejection.receipt, isNull);
      expect(rejection.latestSnapshot!.revision, snapshot.revision);
      expect(rejection.latestSnapshot, isNotNull);
      await session.synchronize();
      expect(
        session.spending.snapshot.revision,
        rejection.latestSnapshot!.revision,
      );
      expect(
        session.settings.snapshot.revision,
        session.spending.snapshot.revision,
      );
      expect(
        session.parties.snapshot.revision,
        session.spending.snapshot.revision,
      );
      expect(
        session.sales.operations.snapshot.revision,
        session.spending.snapshot.revision,
      );
    },
  );

  test('spending and purchases share acknowledged snapshots and paid report semantics', () async {
    final (store, base) = await fixture();
    const codec = PortableJournalCodec();
    final state = codec.decodeState(base.payload);
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
      writeToken: 'seed-supplier',
      expected: base,
    );
    var comparisons = 0;
    final opened = await RestaurantOperationsSession.open(
      store: store,
      snapshot: (seeded as CapabilitySuccess<DocumentSnapshot>).value,
      compareText: (a, b) {
        comparisons++;
        return a.compareTo(b);
      },
      fresh: fresh('active'),
    );
    final session =
        (opened as CapabilitySuccess<RestaurantOperationsSession>).value;
    addTearDown(session.dispose);
    expect(
      await session.dailyCash.recordExpense(
        operationId: 'expense-op',
        expenseId: 'expense',
        journalId: 'expense-journal',
        categoryId: 'samoon',
        amount: BigInt.from(1000),
        fundingSource: FundingSource.daily,
        recordedAt: '2026-11-07T10:00:00Z',
      ),
      isA<DurableCommandSuccess>(),
    );
    expect(await session.synchronize(), isA<CapabilitySuccess<void>>());
    expect(
      session.parties.snapshot.revision,
      session.spending.snapshot.revision,
    );
    expect(
      await session.purchases.createInvoice(
        operationId: 'invoice-op',
        invoiceId: 'invoice',
        invoiceJournalId: 'invoice-journal',
        supplierId: 's',
        invoiceNumber: '1',
        date: DateOnly.parse(
          '2026-11-07',
          minimumYear: 1000,
          maximumYear: 9999,
        ),
        lines: [
          const PurchaseLine(
            materialIdForCreation: 'm',
            name: 'Rice',
            unit: 'piece',
            quantityCartons: 1,
            quantityPieces: 0,
            priceCarton: 2500,
            pricePiece: 0,
          ),
        ],
        recordedAt: '2026-11-07T11:00:00Z',
      ),
      isA<DurableCommandSuccess>(),
    );
    expect(await session.synchronize(), isA<CapabilitySuccess<void>>());
    expect(
      await session.purchases.createPayment(
        operationId: 'payment-op',
        paymentId: 'payment',
        journalId: 'payment-journal',
        supplierId: 's',
        invoiceId: 'invoice',
        amount: BigInt.from(1000),
        date: DateOnly.parse(
          '2026-11-07',
          minimumYear: 1000,
          maximumYear: 9999,
        ),
        fundingSource: FundingSource.daily,
        recordedAt: '2026-11-07T12:00:00Z',
      ),
      isA<DurableCommandSuccess>(),
    );
    expect(await session.synchronize(), isA<CapabilitySuccess<void>>());
    expect(session.reports.statement.total, BigInt.from(2000));
    expect(session.purchases.invoiceDue('invoice'), BigInt.from(1500));
    expect(session.parties.supplierLedger('s').ledger('s'), hasLength(2));
    expect(comparisons, greaterThan(0));
    session.settings.replace(session.settings.values.copyWith(name: 'Current'));
    expect(await session.saveSettings(), isA<CapabilitySuccess<void>>());
    expect(session.spending.snapshot.revision, session.snapshot.revision);
    expect(session.parties.snapshot.revision, session.snapshot.revision);
    final finalState = codec.decodeState(store.document!.payload);
    expect(finalState.receipts, hasLength(3));
    expect(finalState.account.preferences.restaurant['name'], 'Current');
    expect(session.dailyCash.expenses, hasLength(2));
  });

  test(
    'unknown spending excludes all peer writes and retries the same intent',
    () async {
      final (store, snapshot) = await fixture();
      final opened = await RestaurantOperationsSession.open(
        store: store,
        snapshot: snapshot,
        compareText: (a, b) => a.compareTo(b),
        fresh: fresh('active'),
      );
      final session =
          (opened as CapabilitySuccess<RestaurantOperationsSession>).value;
      addTearDown(session.dispose);
      // Keep the write outcome unresolved across the coordinator's bounded
      // readback attempts. A single lost ack normally reconciles immediately.
      store.writeFailure = 'commit_unknown';
      final result = await session.dailyCash.recordExpense(
        operationId: 'expense-op',
        expenseId: 'expense',
        journalId: 'expense-journal',
        categoryId: 'samoon',
        amount: BigInt.from(1000),
        fundingSource: FundingSource.daily,
        recordedAt: '2026-11-07T10:00:00Z',
      );
      expect(result, isA<DurableCommandFailure>());
      expect(session.spending.needsReadback, true);
      final writes = store.writes;
      expect(
        (await session.sales.addProduct('p') as CapabilityFailure).code,
        'busy',
      );
      expect((await session.settings.save() as CapabilityFailure).code, 'busy');
      expect(session.parties.postingEnabled, false);
      final peer = session.parties.supplierPaymentIntent(
        operationId: 'blocked',
        paymentId: 'blocked',
        journalId: 'blocked',
        supplierId: 'absent',
        amount: BigInt.one,
        date: DateOnly.parse(
          '2026-11-07',
          minimumYear: 1000,
          maximumYear: 9999,
        ),
        fundingSource: FundingSource.daily,
        recordedAt: '2026-11-07T11:00:00Z',
      );
      expect(
        (await session.parties.submitPayment(
          peer,
        ) as DurableCommandFailure).code,
        'busy',
      );
      expect(store.writes, writes);
      store.writeFailure = null;
      expect(await session.spending.retry(), isA<DurableCommandSuccess>());
      expect(await session.synchronize(), isA<CapabilitySuccess<void>>());
      expect(session.reports.statement.total, BigInt.from(1000));
      expect(session.parties.postingEnabled, true);
    },
  );
  test('same-store settings and checkout publish current report and clean settings snapshots', () async {
    final (store, snapshot) = await fixture();
    final opened = await RestaurantOperationsSession.open(
      store: store,
      snapshot: snapshot,
      compareText: (a, b) => a.compareTo(b),
      fresh: fresh('active'),
    );
    expect(opened, isA<CapabilitySuccess<RestaurantOperationsSession>>());
    final session =
        (opened as CapabilitySuccess<RestaurantOperationsSession>).value;
    addTearDown(session.dispose);
    session.settings.replace(session.settings.values.copyWith(name: 'مطعم'));
    expect(await session.saveSettings(), isA<CapabilitySuccess<void>>());
    expect(
      session.sales.operations.account.preferences.restaurant['name'],
      'مطعم',
    );
    expect(session.reports.composer.statement().identity['name'], 'مطعم');
    expect(await session.sales.addProduct('p'), isA<CapabilitySuccess<void>>());
    expect(
      await session.sales.checkout(
        fresh: fresh('next'),
        operationId: 'sale-op',
        journalId: 'sale-journal',
        recordedAt: '2026-11-07T12:00:00Z',
      ),
      isA<CapabilitySuccess>(),
    );
    expect(
      await session.synchronize(fresh: fresh('next')),
      isA<CapabilitySuccess<void>>(),
    );
    expect(
      session.settings.snapshot.revision,
      session.sales.operations.snapshot.revision,
    );
    expect((session.settings.account.toJson()['sales'] as List).length, 1);
    expect((session.reports.account.toJson()['sales'] as List).length, 1);
    expect(session.synchronizationError, isNull);
  });

  test(
    'checkout preserves dirty settings and stale save cannot overwrite receipt',
    () async {
      final (store, snapshot) = await fixture();
      final opened = await RestaurantOperationsSession.open(
        store: store,
        snapshot: snapshot,
        compareText: (a, b) => a.compareTo(b),
        fresh: fresh('active'),
      );
      final session =
          (opened as CapabilitySuccess<RestaurantOperationsSession>).value;
      addTearDown(session.dispose);
      session.settings.replace(
        session.settings.values.copyWith(name: 'Unsaved'),
      );
      await session.sales.addProduct('p');
      expect(
        await session.sales.checkout(
          fresh: fresh('next'),
          operationId: 'sale-op',
          journalId: 'sale-journal',
          recordedAt: '2026-11-07T12:00:00Z',
        ),
        isA<CapabilitySuccess>(),
      );
      await session.synchronize();
      expect(session.settings.values.name, 'Unsaved');
      final writes = store.writes;
      expect(
        (await session.saveSettings() as CapabilityFailure).code,
        'stale_revision',
      );
      expect(store.writes, writes);
      expect((session.reports.account.toJson()['sales'] as List).length, 1);
      expect(
        await session.reloadSettings(discardChanges: true),
        isA<CapabilitySuccess<void>>(),
      );
      expect(session.settings.values.name, '');
    },
  );

  test(
    'unknown metadata acknowledgement excludes sales until explicit readback',
    () async {
      final (store, snapshot) = await fixture();
      final opened = await RestaurantOperationsSession.open(
        store: store,
        snapshot: snapshot,
        compareText: (a, b) => a.compareTo(b),
        fresh: fresh('active'),
      );
      final session =
          (opened as CapabilitySuccess<RestaurantOperationsSession>).value;
      addTearDown(session.dispose);
      session.settings.replace(
        session.settings.values.copyWith(name: 'Saved once'),
      );
      store.throwAfterCommit = true;
      expect(
        (await session.saveSettings() as CapabilityFailure).code,
        'commit_unknown',
      );
      final writes = store.writes;
      expect(
        (await session.sales.addProduct('p') as CapabilityFailure).code,
        'busy',
      );
      final directVoid = session.sales.operations.voidIntent(
        operationId: 'blocked-void',
        saleId: 'existing-sale',
        reversalJournalId: 'blocked-reversal',
        reason: 'blocked',
        voidedAt: '2026-11-07T12:00:00Z',
      );
      final blocked = await session.sales.operations.submit(directVoid);
      expect(blocked, isA<DurableCommandFailure>());
      expect((blocked as DurableCommandFailure).code, 'busy');
      expect(session.sales.operations.postingEnabled, false);
      expect(store.writes, writes);
      store.throwAfterCommit = false;
      expect(await session.reconcileSettings(), isA<CapabilitySuccess<void>>());
      expect(
        session.sales.operations.account.preferences.restaurant['name'],
        'Saved once',
      );
      expect(session.settings.needsReadback, false);
      expect(
        await session.sales.addProduct('p'),
        isA<CapabilitySuccess<void>>(),
      );
    },
  );
}
