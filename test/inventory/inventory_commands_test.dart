import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:madar_application/madar_application.dart';
import 'package:madar_data/madar_data.dart';
import 'package:madar_domain/madar_domain.dart';
import 'package:dakhl_restaurant/accounts/accounts_repository.dart';
import 'package:dakhl_restaurant/accounts/account_document.dart';
import 'package:dakhl_restaurant/inventory/inventory_commands.dart';
import 'package:dakhl_restaurant/inventory/stock_projection.dart';

import '../accounts/accounts_view_model_test.dart' show FixtureStore;

Map<String, Object?> product([String id = 'p']) => {
  'id': id,
  'name': 'Synthetic $id',
  'code': id,
  'unit': 'piece',
  'price': 1000,
  'group': 'test',
  'minStock': 0,
  'trackStock': true,
  'archived': false,
};
InventoryMovement movement(
  String id,
  int units, {
  String productId = 'p',
  StockEntryKind kind = StockEntryKind.restock,
  String day = '2026-01-01',
}) => InventoryMovement(
  id: id,
  productId: productId,
  quantityUnits: BigInt.from(units),
  effectiveDate: DateOnly.parse(day, minimumYear: 1000, maximumYear: 9999),
  kind: kind,
  createdAt: '2026-01-01T00:00:00.000Z',
);
Future<AccountsRepository> setup(LocalDocumentWorkspaceStore store) async {
  final r = AccountsRepository(store: store);
  await r.open();
  expect(
    await r.save(r.codec.empty()),
    isA<CapabilitySuccess<AccountDocument>>(),
  );
  return r;
}

void main() {
  test(
    'stock reversal reasons preserve JavaScript BOM and NEL semantics',
    () async {
      final store = FixtureStore();
      final r = await setup(store);
      final c = InventoryCommands(r);
      await c.createProduct(
        product(),
        expected: r.snapshot!,
        opening: movement('open', 1000, kind: StockEntryKind.opening),
      );
      final before = r.document;
      expect(
        await c.reverseMovement(
          'open',
          newId: 'bom',
          reason: '\ufeff',
          createdAt: '2026-01-02T00:00:00Z',
          expected: r.snapshot!,
        ),
        isA<CapabilityFailure<AccountDocument>>(),
      );
      expect(identical(r.document, before), true);
      expect(
        await c.reverseMovement(
          'open',
          newId: 'nel',
          reason: ' \u0085 ',
          createdAt: '2026-01-02T00:00:00Z',
          expected: r.snapshot!,
        ),
        isA<CapabilitySuccess<AccountDocument>>(),
      );
      final raw = r.document!.toJson();
      expect(((raw['stockEntries'] as List).last as Map)['note'], '\u0085');
      // Direct codec import exercises the validation boundary independently.
      expect(r.codec.decodeJson(raw).toJson(), raw);
      final entries = (raw['stockEntries'] as List)
          .map((e) => Map<String, Object?>.from(e as Map))
          .toList();
      entries.last['note'] = '\ufeff';
      expect(
        () => r.codec.decodeJson({...raw, 'stockEntries': entries}),
        throwsA(anything),
      );
    },
  );
  test('atomic product opening, busy rejection, restart and duplicate preservation', () async {
    final store = FixtureStore();
    final actual = await setup(store);
    final c = InventoryCommands(actual);
    final expected = actual.snapshot!;
    final first = c.createProduct(
      product(),
      expected: expected,
      opening: movement('open', 10000, kind: StockEntryKind.opening),
    );
    expect(
      (await c.createProduct(
        product('q'),
        expected: expected,
      ) as CapabilityFailure).code,
      'busy',
    );
    expect(await first, isA<CapabilitySuccess<AccountDocument>>());
    final reopened = AccountsRepository(store: store);
    await reopened.open();
    expect(
      RestaurantStockProjection(reopened.document!).balanceFor(
        'p',
        through: DateOnly.parse(
          '2026-01-01',
          minimumYear: 1000,
          maximumYear: 9999,
        ),
      ),
      BigInt.from(10000),
    );
    final prior = actual.document, writes = store.writes;
    expect(
      await c.createProduct(product(), expected: actual.snapshot!),
      isA<CapabilityFailure<AccountDocument>>(),
    );
    expect(identical(actual.document, prior), true);
    expect(store.writes, writes);
  });
  test(
    'history locks unit/tracking, price snapshots survive edit and archive',
    () async {
      final store = FixtureStore();
      final actual = await setup(store);
      final c = InventoryCommands(actual);
      await c.createProduct(
        product(),
        expected: actual.snapshot!,
        opening: movement('open', 10000, kind: StockEntryKind.opening),
      );
      final raw = Map<String, Object?>.from(actual.document!.toJson());
      raw['sales'] = [
        {
          'id': 'sale',
          'number': '1',
          'date': '2026-01-01',
          'status': 'completed',
          'lines': [
            {
              'productId': 'p',
              'name': 'Synthetic p',
              'unit': 'piece',
              'quantity': 2,
              'price': 1000,
              'trackStock': true,
            },
          ],
          'discount': 0,
          'paid': 2000,
          'note': '',
          'createdAt': '2026-01-01T00:00:00.000Z',
        },
      ];
      await actual.save(actual.codec.decodeJson(raw));
      expect(
        await c.editProduct({
          ...product(),
          'unit': 'kg',
          'trackStock': false,
          'price': 2000,
        }, expected: actual.snapshot!),
        isA<CapabilitySuccess<AccountDocument>>(),
      );
      final current = actual.document!.toJson();
      final p = (current['products'] as List).single as Map;
      expect(p['unit'], 'piece');
      expect(p['trackStock'], true);
      expect(p['price'], 2000);
      expect(
        (((current['sales'] as List).single as Map)['lines'] as List).single,
        containsPair('price', 1000),
      );
      expect(
        await c.setArchived('p', true, expected: actual.snapshot!),
        isA<CapabilitySuccess<AccountDocument>>(),
      );
      expect(
        ((actual.document!.toJson()['products'] as List).single
            as Map)['archived'],
        true,
      );
    },
  );
  test('dated reversal rejects consumed opening and repeated inverse; definite failure preserves state', () async {
    final store = FixtureStore();
    final r = await setup(store);
    final c = InventoryCommands(r);
    await c.createProduct(
      product(),
      expected: r.snapshot!,
      opening: movement('open', 10000, kind: StockEntryKind.opening),
    );
    await c.postMovement(
      movement('loss', -2000, kind: StockEntryKind.adjustment),
      expected: r.snapshot!,
    );
    final before = r.document;
    final writes = store.writes;
    expect(
      await c.reverseMovement(
        'open',
        newId: 'bad',
        reason: 'correction',
        createdAt: '2026-01-02T00:00:00Z',
        expected: r.snapshot!,
      ),
      isA<CapabilityFailure<AccountDocument>>(),
    );
    expect(identical(r.document, before), true);
    expect(store.writes, writes);
    expect(
      await c.reverseMovement(
        'loss',
        newId: 'undo',
        reason: 'correction',
        createdAt: '2026-01-02T00:00:00Z',
        expected: r.snapshot!,
      ),
      isA<CapabilitySuccess<AccountDocument>>(),
    );
    final inverse = (r.document!.toJson()['stockEntries'] as List).last as Map;
    expect(inverse['date'], '2026-01-01');
    expect(inverse['reversesId'], 'loss');
    expect(
      await c.reverseMovement(
        'loss',
        newId: 'again',
        reason: 'correction',
        createdAt: '2026-01-02T00:00:00Z',
        expected: r.snapshot!,
      ),
      isA<CapabilityFailure<AccountDocument>>(),
    );
    store.writeFailure = 'disk_full';
    final saved = r.document;
    expect(
      (await c.postMovement(
        movement('later', 1000),
        expected: r.snapshot!,
      ) as CapabilityFailure).code,
      'disk_full',
    );
    expect(identical(r.document, saved), true);
  });
  test('shared-repository stale authority and unknown acknowledgement prevent retry', () async {
    final store = FixtureStore();
    final r = await setup(store);
    final c = InventoryCommands(r);
    final old = r.snapshot!;
    await r.save(r.document!);
    expect(
      (await c.createProduct(
        product(),
        expected: old,
      ) as CapabilityFailure).code,
      'stale_revision',
    );
    store.throwAfterCommit = true;
    final current = r.snapshot!;
    expect(
      (await c.createProduct(
        product(),
        expected: current,
      ) as CapabilityFailure).code,
      'commit_unknown',
    );
    final writes = store.writes;
    expect(
      (await c.createProduct(
        product(),
        expected: current,
      ) as CapabilityFailure).code,
      'commit_unknown',
    );
    expect(store.writes, writes);
    store.throwAfterCommit = false;
    expect(await r.reconcile(), isA<CapabilitySuccess<AccountDocument>>());
    expect((r.document!.toJson()['products'] as List).length, 1);
  });
  test(
    'invalid movements and untracked stock preserve acknowledged records',
    () async {
      final store = FixtureStore();
      final r = await setup(store);
      final c = InventoryCommands(r);
      await c.createProduct(product(), expected: r.snapshot!);
      final before = r.document, writes = store.writes;
      for (final invalid in [
        movement('zero', 0),
        movement('negative', -1000),
        movement('excess', 1000000000001),
        movement('missing', 1000, productId: 'unknown'),
        movement('overdraft', -1, kind: StockEntryKind.adjustment),
      ]) {
        expect(
          await c.postMovement(invalid, expected: r.snapshot!),
          isA<CapabilityFailure<AccountDocument>>(),
        );
        expect(identical(r.document, before), true);
        expect(store.writes, writes);
      }
      expect(
        await c.editProduct({
          ...product(),
          'trackStock': false,
          'minStock': 50,
        }, expected: r.snapshot!),
        isA<CapabilitySuccess<AccountDocument>>(),
      );
      expect(
        ((r.document!.toJson()['products'] as List).single as Map)['minStock'],
        0,
      );
      expect(
        await c.postMovement(
          movement('untracked', 1000),
          expected: r.snapshot!,
        ),
        isA<CapabilityFailure<AccountDocument>>(),
      );
    },
  );
  test(
    'real adapter persists opening and reversal across close/reopen',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'dakhl-stock-command-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final opened = await PowerSyncLocalDocumentWorkspaceStore.open(
        directoryPath: directory.path,
      );
      final store =
          (opened as CapabilitySuccess<PowerSyncLocalDocumentWorkspaceStore>)
              .value;
      addTearDown(store.close);
      final r = await setup(store);
      final c = InventoryCommands(r);
      expect(
        await c.createProduct(
          product(),
          expected: r.snapshot!,
          opening: movement('open', 1250, kind: StockEntryKind.opening),
        ),
        isA<CapabilitySuccess<AccountDocument>>(),
      );
      expect(
        await c.reverseMovement(
          'open',
          newId: 'reverse',
          reason: 'fixture correction',
          createdAt: '2026-01-02T00:00:00Z',
          expected: r.snapshot!,
        ),
        isA<CapabilitySuccess<AccountDocument>>(),
      );
      await store.close();
      final again = await PowerSyncLocalDocumentWorkspaceStore.open(
        directoryPath: directory.path,
      );
      final restored =
          (again as CapabilitySuccess<PowerSyncLocalDocumentWorkspaceStore>)
              .value;
      addTearDown(restored.close);
      final reopened = AccountsRepository(store: restored);
      await reopened.open();
      expect((reopened.document!.toJson()['stockEntries'] as List).length, 2);
      expect(
        RestaurantStockProjection(reopened.document!).balanceFor(
          'p',
          through: DateOnly.parse(
            '2026-01-02',
            minimumYear: 1000,
            maximumYear: 9999,
          ),
        ),
        BigInt.zero,
      );
    },
  );
}
