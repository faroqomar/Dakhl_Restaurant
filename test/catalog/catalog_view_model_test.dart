import 'dart:async';

import 'package:madar_domain/madar_domain.dart';
import 'package:dakhl_restaurant/catalog/catalog_read_model.dart';

import 'package:madar_application/madar_application.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dakhl_restaurant/accounts/accounts_repository.dart';
import 'package:dakhl_restaurant/catalog/catalog_view_model.dart';

import '../inventory/inventory_commands_test.dart' as inventory;
import '../parties/parties_view_model_test.dart' show Store, setup;

void main() {
  test('commands persist and validation failure preserves storage', () async {
    final (store, repository, parties) = await setup();
    final model = CatalogViewModel(repository);
    final product = <String, Object?>{
      'id': 'product',
      'name': 'Rice',
      'code': '',
      'group': '',
      'unit': 'piece',
      'price': 100,
      'archived': false,
      'trackStock': false,
      'minStock': 0,
    };
    await model.createProduct(product, session: model.beginEdit());
    expect(model.errorCode, isNull);
    expect((repository.document!.toJson()['products'] as List).length, 1);
    await model.setArchived('product', true, session: model.beginEdit());
    expect(
      (repository.document!.toJson()['products'] as List).single['archived'],
      true,
    );
    final writes = store.writes;
    await model.setArchived('missing', true, session: model.beginEdit());
    expect(model.errorCode, 'missing_product');
    expect(store.writes, writes);
    model.dispose();
    parties.dispose();
  });

  test('edit and reversal preserve historical movement', () async {
    final (_, repository, parties) = await setup();
    final model = CatalogViewModel(repository);
    await model.createProduct(inventory.product(), session: model.beginEdit());
    await model.postMovement(
      inventory.movement('entry', 2000),
      session: model.beginEdit(),
    );
    expect(model.errorCode, isNull);
    await model.editProduct({
      ...inventory.product(),
      'name': 'Edited',
    }, session: model.beginEdit());
    expect(model.errorCode, isNull);
    await model.reverseMovement(
      'entry',
      session: model.beginEdit(),
      newId: 'inverse',
      reason: 'Synthetic correction',
      createdAt: '2026-01-01T00:00:00.000Z',
    );
    expect(model.errorCode, isNull);
    final rows = repository.document!.toJson()['stockEntries'] as List;
    expect(rows.length, 2);
    expect(rows.first['id'], 'entry');
    expect(rows.last['reversesId'], 'entry');
    await model.reverseMovement(
      'entry',
      session: model.beginEdit(),
      newId: 'again',
      reason: 'Duplicate',
      createdAt: '2026-01-01T00:00:00.000Z',
    );
    expect(model.errorCode, 'invalid_stock_reversal');
    model.dispose();
    parties.dispose();
  });

  test(
    'stale draft, concurrent write, disposal and filter notifications',
    () async {
      final (store, repository, parties) = await setup();
      final model = CatalogViewModel(repository);
      final draft = model.beginEdit();
      var notifications = 0;
      model.addListener(() => notifications++);
      model.selectPage(3);
      model.filter(query: 'rice');
      expect(model.page, 1);
      expect(notifications, 2);
      await repository.save(repository.document!);
      final before = store.writes;
      final stale = await model.setArchived('missing', true, session: draft);
      expect((stale as CapabilityFailure).code, 'stale_revision');
      expect(store.writes, before);
      final current = model.beginEdit();
      Future<CapabilityResult<dynamic>>? concurrent;
      void reenter() {
        if (model.busy && concurrent == null) {
          concurrent = model.setArchived('missing', true, session: current);
        }
      }

      model.addListener(reenter);
      await model.setArchived('missing', true, session: current);
      expect((await concurrent! as CapabilityFailure).code, 'busy');
      model.dispose();
      final disposed = await model.setArchived(
        'missing',
        true,
        session: current,
      );
      expect((disposed as CapabilityFailure).code, 'disposed');
      parties.dispose();
    },
  );

  test(
    'successful delayed write owns error state despite busy rejection',
    () async {
      final (store, repository, parties) = await setup();
      final model = CatalogViewModel(repository);
      final session = model.beginEdit();
      store.delay = Completer<void>();
      final pending = model.createProduct(
        inventory.product(),
        session: session,
      );
      final rejected = await model.createProduct(
        inventory.product(),
        session: session,
      );
      expect((rejected as CapabilityFailure).code, 'busy');
      expect(model.errorCode, isNull);
      store.delay!.complete();
      expect(await pending, isA<CapabilitySuccess>());
      expect(model.busy, false);
      expect(model.errorCode, isNull);
      model.dispose();
      parties.dispose();
    },
  );

  test(
    'listener cannot change submitted product and disposal prevents dispatch',
    () async {
      final (store, repository, parties) = await setup();
      final model = CatalogViewModel(repository);
      final product = inventory.product();
      final name = product['name'];
      void mutate() {
        product['name'] = 'Changed by listener';
      }

      model.addListener(mutate);
      expect(
        await model.createProduct(product, session: model.beginEdit()),
        isA<CapabilitySuccess>(),
      );
      expect(
        (repository.document!.toJson()['products'] as List).single['name'],
        name,
      );
      model.removeListener(mutate);
      final writes = store.writes;
      model.addListener(model.dispose);
      final result = await model.setArchived(
        'product',
        true,
        session: model.beginEdit(),
      );
      expect((result as CapabilityFailure).code, 'disposed');
      expect(store.writes, writes);
      parties.dispose();
    },
  );

  test('stale rejection notifies once and disposal during write suppresses notification', () async {
    final (store, repository, parties) = await setup();
    final model = CatalogViewModel(repository);
    final stale = model.beginEdit();
    await repository.save(repository.document!, replace: true);
    var notifications = 0;
    model.addListener(() => notifications++);
    final result = await model.createProduct(
      inventory.product(),
      session: stale,
    );
    expect((result as CapabilityFailure).code, 'stale_revision');
    expect(notifications, 1);
    store.delay = Completer<void>();
    final pending = model.createProduct(
      inventory.product(),
      session: model.beginEdit(),
    );
    final beforeDispose = notifications;
    model.dispose();
    store.delay!.complete();
    expect(await pending, isA<CapabilitySuccess>());
    expect(notifications, beforeDispose);
    expect(model.busy, false);
    parties.dispose();
  });

  test(
    'inventory composes date projection, filters and page clamping',
    () async {
      final (_, repository, parties) = await setup();
      final model = CatalogViewModel(repository);
      final day = DateOnly.parse(
        '2026-01-01',
        minimumYear: 1000,
        maximumYear: 9999,
      );
      await model.createProduct(
        inventory.product(),
        session: model.beginEdit(),
      );
      expect(model.inventoryAt(day)!.items.single.availableUnits, BigInt.zero);
      for (final query in ['Synthetic', 'p', 'test']) {
        model.filter(query: query, group: 'test', status: InventoryStatus.out);
        expect(model.inventoryAt(day)!.total, 1);
      }
      model.filter(query: '', status: InventoryStatus.low);
      expect(model.inventoryAt(day)!.total, 1);
      await model.postMovement(
        inventory.movement('stock', 2000),
        session: model.beginEdit(),
      );
      expect(model.inventoryAt(day)!.total, 0);
      model.filter(status: InventoryStatus.active);
      model.selectPage(99);
      expect(model.inventoryAt(day)!.page, 1);
      expect(
        model.inventoryAt(day)!.items.single.availableUnits,
        BigInt.from(2000),
      );
      await model.setArchived('p', true, session: model.beginEdit());
      expect(model.inventoryAt(day)!.total, 0);
      for (final status in [InventoryStatus.archived, InventoryStatus.all]) {
        model.filter(status: status);
        expect(model.inventoryAt(day)!.total, 1);
      }
      model.filter(group: 'missing');
      expect(model.inventoryAt(day)!.total, 0);
      model.dispose();
      parties.dispose();
      final empty = CatalogViewModel(AccountsRepository(store: Store()));
      expect(empty.inventoryAt(day), isNull);
      empty.dispose();
    },
  );

  test('uninitialized controller cannot capture authority', () {
    final model = CatalogViewModel(AccountsRepository(store: Store()));
    expect(model.beginEdit, throwsStateError);
    model.dispose();
    expect(model.beginEdit, throwsStateError);
  });
}
