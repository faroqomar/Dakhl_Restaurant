import 'package:flutter_test/flutter_test.dart';
import 'package:madar_application/madar_application.dart';
import 'package:madar_domain/madar_domain.dart';
import 'package:dakhl_restaurant/accounting/financial_session_undo.dart';
import 'package:dakhl_restaurant/accounts/portable_journal_codec.dart';
import 'package:dakhl_restaurant/app/restaurant_operations_session.dart';
import 'package:dakhl_restaurant/catalog/catalog_view_model.dart';
import 'package:dakhl_restaurant/inventory/stock_session_undo.dart';

import '../sales/sales_workflow_session_test.dart' show fixture, fresh;
import 'inventory_commands_test.dart' show movement, product;

const _codec = PortableJournalCodec();

void main() {
  test('stock undo appends original-date reasoned inverse and retains source history', () async {
    final (store, snapshot) = await fixture();
    final session = ((await RestaurantOperationsSession.open(
      store: store,
      snapshot: snapshot,
      compareText: (a, b) => a.compareTo(b),
      fresh: fresh('active'),
    )) as CapabilitySuccess<RestaurantOperationsSession>).value;
    addTearDown(session.dispose);
    final catalog = CatalogViewModel(session.metadataRepository);
    addTearDown(catalog.dispose);
    expect(
      await catalog.createProduct(
        product('tracked'),
        session: catalog.beginEdit(),
      ),
      isA<CapabilitySuccess>(),
    );
    await session.synchronize();
    final before = session.metadataBridge.snapshot;
    final undo = FinancialSessionUndoController(
      readSnapshot: () => session.metadataBridge.snapshot,
      isWriteBlocked: () => false,
    );
    addTearDown(undo.dispose);
    expect(
      await catalog.postMovement(
        movement('restock', 2000, productId: 'tracked', day: '2026-11-07'),
        session: catalog.beginEdit(),
      ),
      isA<CapabilitySuccess>(),
    );
    await session.synchronize();
    final after = session.metadataBridge.snapshot;
    final adapter = StockMovementSessionUndoAdapter(
      repository: session.metadataRepository,
      bridge: session.metadataBridge,
      reason: 'Session undo',
    );
    expect(
      undo.registerTransition(before: before, after: after, adapter: adapter),
      isA<CapabilitySuccess>(),
    );
    expect(await undo.undo(), isA<CapabilitySuccess<void>>());
    final state = _codec.decodeState(store.document!.payload);
    final entries = state.account.toJson()['stockEntries']! as List;
    expect(entries.length, 2);
    expect(
      entries.first,
      (_codec.decodeState(after.payload).account.toJson()['stockEntries']
              as List)
          .single,
    );
    expect(entries.last['reversesId'], 'restock');
    expect(entries.last['quantity'], -2);
    expect(entries.last['date'], '2026-11-07');
    expect(entries.last['note'], 'Session undo');
    final prior = _codec.decodeState(after.payload);
    expect(state.copyWith(account: prior.account).toJson(), prior.toJson());
    expect(undo.length, 0);
    expect(
      () => adapter.prepare(before: prior, after: state, current: state),
      throwsA(
        isA<FormatException>().having(
          (e) => e.message,
          'code',
          'undo_stock_reversal_not_supported',
        ),
      ),
    );
  });
  test(
    'undo refuses a restock reversal that would leave later negative stock',
    () async {
      final (store, snapshot) = await fixture();
      final session = ((await RestaurantOperationsSession.open(
        store: store,
        snapshot: snapshot,
        compareText: (a, b) => a.compareTo(b),
        fresh: fresh('active'),
      )) as CapabilitySuccess<RestaurantOperationsSession>).value;
      addTearDown(session.dispose);
      final catalog = CatalogViewModel(session.metadataRepository);
      addTearDown(catalog.dispose);
      await catalog.createProduct(
        product('tracked'),
        session: catalog.beginEdit(),
      );
      await session.synchronize();
      final before = _codec.decodeState(store.document!.payload);
      await catalog.postMovement(
        movement('restock', 2000, productId: 'tracked', day: '2026-11-07'),
        session: catalog.beginEdit(),
      );
      await session.synchronize();
      final after = _codec.decodeState(store.document!.payload);
      expect(
        await catalog.postMovement(
          movement(
            'used',
            -1000,
            productId: 'tracked',
            kind: StockEntryKind.adjustment,
            day: '2026-11-08',
          ),
          session: catalog.beginEdit(),
        ),
        isA<CapabilitySuccess>(),
      );
      await session.synchronize();
      final current = _codec.decodeState(store.document!.payload);
      final payload = store.document!.payload, writes = store.writes;
      final attempt = StockMovementSessionUndoAdapter(
        repository: session.metadataRepository,
        bridge: session.metadataBridge,
        reason: 'Session undo',
      ).prepare(before: before, after: after, current: current);
      final result = await attempt.executeMetadata!();
      expect(result, isA<CapabilityFailure<DocumentSnapshot>>());
      // The canonical account codec rejects the negative-history candidate
      // before the later inventory projection validation runs.
      expect((result as CapabilityFailure).code, 'invalid_payload');
      expect(store.document!.payload, payload);
      expect(store.writes, writes);
    },
  );
  for (final consumed in [false, true]) {
    test(
      'product opening undo is atomic with archive; consumed=$consumed',
      () async {
        final (store, snapshot) = await fixture();
        final session = ((await RestaurantOperationsSession.open(
          store: store,
          snapshot: snapshot,
          compareText: (a, b) => a.compareTo(b),
          fresh: fresh('opening'),
        )) as CapabilitySuccess<RestaurantOperationsSession>).value;
        addTearDown(session.dispose);
        final catalog = CatalogViewModel(session.metadataRepository);
        addTearDown(catalog.dispose);
        final before = _codec.decodeState(store.document!.payload);
        expect(
          await catalog.createProduct(
            product('new-tracked'),
            session: catalog.beginEdit(),
            opening: movement(
              'new-opening',
              2000,
              productId: 'new-tracked',
              kind: StockEntryKind.opening,
              day: '2026-11-07',
            ),
          ),
          isA<CapabilitySuccess>(),
        );
        await session.synchronize();
        final after = _codec.decodeState(store.document!.payload);
        if (consumed) {
          expect(
            await catalog.postMovement(
              movement(
                'used-opening',
                -1000,
                productId: 'new-tracked',
                kind: StockEntryKind.adjustment,
                day: '2026-11-08',
              ),
              session: catalog.beginEdit(),
            ),
            isA<CapabilitySuccess>(),
          );
          await session.synchronize();
        }
        final payload = store.document!.payload, writes = store.writes;
        final current = _codec.decodeState(payload);
        final attempt = StockMovementSessionUndoAdapter(
          repository: session.metadataRepository,
          bridge: session.metadataBridge,
          reason: 'Undo product creation',
        ).prepare(before: before, after: after, current: current);
        final result = await attempt.executeMetadata!();
        if (consumed) {
          expect(result, isA<CapabilityFailure<DocumentSnapshot>>());
          expect(store.document!.payload, payload);
          expect(store.writes, writes);
        } else {
          expect(result, isA<CapabilitySuccess<DocumentSnapshot>>());
          final undone = _codec.decodeState(store.document!.payload);
          final products = undone.account.toJson()['products'] as List;
          expect(
            products
                .where((p) => (p as Map)['id'] == 'new-tracked')
                .single['archived'],
            true,
          );
          final entries = undone.account.toJson()['stockEntries'] as List;
          expect(entries.length, 2);
          expect(
            entries.first,
            (after.account.toJson()['stockEntries'] as List).single,
          );
          expect(entries.last['reversesId'], 'new-opening');
          expect(entries.last['quantity'], -2);
          expect(
            undone.copyWith(account: before.account).toJson(),
            before.toJson(),
          );
          expect(store.writes, writes + 1);
        }
      },
    );
  }
}
