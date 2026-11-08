import 'dart:convert';

import 'package:dakhl_restaurant/accounts/account_document.dart';
import 'package:dakhl_restaurant/accounts/accounts_repository.dart';
import 'package:dakhl_restaurant/accounts/legacy_account_codec.dart';
import 'package:dakhl_restaurant/sales/sales_view_model.dart';
import 'package:dakhl_restaurant/sales/ticket_workspace.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar_application/madar_application.dart';

import '../accounts/accounts_view_model_test.dart' show FixtureStore;
import 'ticket_workspace_test.dart' show DelayedWorkspaceStore;

TicketDraft fresh(String id) => TicketDraft(
  id: id,
  date: '2026-11-07',
  orderType: 'سفري',
  discount: '',
  note: '',
  lines: [],
);
Map<String, Object?> product(
  String id, {
  int price = 12000,
  bool tracked = false,
  bool archived = false,
  String group = 'food',
}) => {
  'id': id,
  'name': 'Product $id',
  'code': 'code$id',
  'group': group,
  'unit': 'piece',
  'price': price,
  'trackStock': tracked,
  'archived': archived,
  'minStock': 0,
};
AccountDocument account({int count = 1, bool tracked = false}) =>
    const LegacyAccountCodec().decodeJson({
      ...const LegacyAccountCodec().empty().toJson(),
      'products': [
        for (var i = 0; i < count; i++)
          product('p$i', tracked: tracked, group: i.isEven ? 'food' : 'drink'),
      ],
      if (tracked)
        'stockEntries': [
          {
            'id': 'opening',
            'productId': 'p0',
            'kind': 'opening',
            'date': '2026-11-07',
            'quantity': 3,
            'note': '',
            'createdAt': '2026-11-07T08:00:00Z',
          },
        ],
    });
Future<AccountsRepository> repository(
  LocalDocumentWorkspaceStore store, {
  int count = 1,
  bool tracked = false,
}) async {
  final repo = AccountsRepository(store: store);
  await repo.open();
  expect(
    await repo.save(account(count: count, tracked: tracked)),
    isA<CapabilitySuccess<void>>(),
  );
  return repo;
}

String? failure(CapabilityResult<void> result) =>
    result is CapabilityFailure<void> ? result.code : null;

void main() {
  test(
    'catalog composes eighty-row pages with source search and filter reset',
    () async {
      final repo = await repository(FixtureStore(), count: 161);
      final vm = SalesViewModel(repo);
      addTearDown(vm.dispose);
      expect(await vm.load(fresh('a')), isA<CapabilitySuccess<void>>());
      expect(vm.catalog!.items.length, 80);
      vm.selectPage(3);
      expect(vm.catalog!.items.single.id, 'p160');
      vm.filter(group: 'drink');
      expect(vm.page, 1);
      expect(vm.catalog!.total, 80);
      vm.filter(query: 'CODEP15', group: '');
      expect(vm.catalog!.total, 11);
      expect(vm.groups, ['food', 'drink']);
      expect(() => vm.catalog!.items.clear(), throwsUnsupportedError);
    },
  );

  test('captured prices, scaled quotes and all draft fields survive hold and reopen', () async {
    final store = FixtureStore();
    final repo = await repository(store);
    final vm = SalesViewModel(repo);
    addTearDown(vm.dispose);
    await vm.load(fresh('a'));
    final accountBefore = jsonEncode(repo.document!.toJson());
    final accountWrites = store.writes;
    await vm.addProduct('p0', quantityUnits: BigInt.from(1250));
    await vm.updateDetails(
      discount: '٥٠٠',
      note: 'retain',
      orderType: 'صالة',
      date: '2026-11-08',
    );
    expect(vm.quote.calculation!.subtotal, BigInt.from(15000));
    expect(vm.quote.calculation!.net, BigInt.from(14500));
    expect(jsonEncode(repo.document!.toJson()), accountBefore);
    expect(store.writes, accountWrites);
    await repo.save(
      const LegacyAccountCodec().decodeJson({
        ...repo.document!.toJson(),
        'products': [product('p0', price: 50000)],
      }),
    );
    await vm.addProduct('p0', quantityUnits: BigInt.from(250));
    expect(vm.active!.lines.single.price, 12000);
    expect(vm.quote.calculation!.net, BigInt.from(17500));
    await vm.hold(
      label: 'label',
      heldId: 'h1',
      fresh: fresh('b'),
      savedAt: '2026-11-08T09:00:00Z',
    );
    final reopened = SalesViewModel(repo);
    addTearDown(reopened.dispose);
    await reopened.load(fresh('unused'));
    expect(reopened.held.single.draft.note, 'retain');
    await reopened.resume(
      'h1',
      swapId: 'swap',
      swapLabel: 'swap',
      savedAt: '2026-11-08T09:01:00Z',
    );
    expect(reopened.active!.id, 'a');
    expect(reopened.active!.heldLabel, 'label');
    expect(reopened.active!.date, '2026-11-08');
    expect(reopened.active!.orderType, 'صالة');
    expect(reopened.active!.discount, '٥٠٠');
    expect(reopened.active!.lines.single.quantityUnits, BigInt.from(1500));
    expect(() => reopened.active!.lines.clear(), throwsUnsupportedError);
  });

  test(
    'draft quantity and discount failures preserve workspace and report errors',
    () async {
      final store = FixtureStore();
      final repo = await repository(store);
      final vm = SalesViewModel(repo);
      addTearDown(vm.dispose);
      await vm.load(fresh('a'));
      await vm.addProduct('p0');
      final writes = store.workspaceWrites;
      final before = store.workspace!.payload;
      expect(failure(await vm.setQuantity('p0', '0')), 'invalid_sign');
      expect(
        failure(await vm.updateDetails(discount: '-1')),
        'invalid_integer',
      );
      expect(
        failure(await vm.updateDetails(orderType: 'missing')),
        'invalid_order_type',
      );
      expect(store.workspaceWrites, writes);
      expect(store.workspace!.payload, before);
      expect(
        await vm.updateDetails(discount: '12001'),
        isA<CapabilitySuccess<void>>(),
      );
      expect(vm.quote.errorCode, 'discount_exceeds_subtotal');
      await vm.updateDetails(discount: '12000');
      expect(vm.quote.calculation!.net, BigInt.zero);
      expect(vm.errorCode, isNull);
      await vm.removeProduct('p0');
      expect(vm.active!.lines, isEmpty);
      expect(vm.quote.errorCode, 'empty_ticket');
    },
  );

  test('default plus adds fractional stock below one unit', () async {
    final repo = await repository(FixtureStore(), tracked: true);
    final doc =
        jsonDecode(jsonEncode(repo.document!.toJson())) as Map<String, dynamic>;
    (doc['stockEntries'] as List)
            .cast<Map<String, Object?>>()
            .single['quantity'] =
        0.5;
    await repo.save(const LegacyAccountCodec().decodeJson(doc));
    final vm = SalesViewModel(repo);
    addTearDown(vm.dispose);
    await vm.load(fresh('fractional-empty'));
    final accountBefore = jsonEncode(repo.document!.toJson());
    expect(await vm.addProduct('p0'), isA<CapabilitySuccess<void>>());
    expect(vm.active!.lines.single.quantityUnits, BigInt.from(500));
    expect(vm.quote.calculation!.subtotal, BigInt.from(6000));
    expect(jsonEncode(repo.document!.toJson()), accountBefore);
  });

  test(
    'default plus fills fractional remainder and retains first-add price',
    () async {
      final repo = await repository(FixtureStore(), tracked: true);
      final doc = jsonDecode(
        jsonEncode(repo.document!.toJson()),
      ) as Map<String, dynamic>;
      (doc['stockEntries'] as List)
              .cast<Map<String, Object?>>()
              .single['quantity'] =
          1.25;
      await repo.save(const LegacyAccountCodec().decodeJson(doc));
      final vm = SalesViewModel(repo);
      addTearDown(vm.dispose);
      await vm.load(fresh('fractional-remainder'));
      await vm.addProduct('p0', quantityUnits: BigInt.from(750));
      final changed = jsonDecode(
        jsonEncode(repo.document!.toJson()),
      ) as Map<String, dynamic>;
      (changed['products'] as List)
              .cast<Map<String, Object?>>()
              .single['price'] =
          24000;
      await repo.save(const LegacyAccountCodec().decodeJson(changed));
      vm.refresh();
      final accountBefore = jsonEncode(repo.document!.toJson());
      expect(await vm.addProduct('p0'), isA<CapabilitySuccess<void>>());
      expect(vm.active!.lines.single.quantityUnits, BigInt.from(1250));
      expect(vm.active!.lines.single.price, 12000);
      expect(vm.quote.calculation!.subtotal, BigInt.from(15000));
      final ticketBefore = jsonEncode(vm.active!.toJson());
      expect(await vm.addProduct('p0'), isA<CapabilitySuccess<void>>());
      expect(jsonEncode(vm.active!.toJson()), ticketBefore);
      expect(
        failure(await vm.addProduct('p0', quantityUnits: BigInt.one)),
        'insufficient_stock',
      );
      expect(jsonEncode(vm.active!.toJson()), ticketBefore);
      expect(jsonEncode(repo.document!.toJson()), accountBefore);
    },
  );

  test('default plus with zero stock preserves an empty ticket', () async {
    final repo = await repository(FixtureStore(), tracked: true);
    final doc =
        jsonDecode(jsonEncode(repo.document!.toJson())) as Map<String, dynamic>;
    (doc['stockEntries'] as List).clear();
    await repo.save(const LegacyAccountCodec().decodeJson(doc));
    final vm = SalesViewModel(repo);
    addTearDown(vm.dispose);
    await vm.load(fresh('no-remaining'));
    final before = jsonEncode(vm.active!.toJson());
    expect(await vm.addProduct('p0'), isA<CapabilitySuccess<void>>());
    expect(jsonEncode(vm.active!.toJson()), before);
    expect(vm.quote.errorCode, 'empty_ticket');
  });

  test('dated stock, missing and archived eligibility use current catalog without recapture', () async {
    final store = FixtureStore();
    final repo = await repository(store, tracked: true);
    final vm = SalesViewModel(repo);
    addTearDown(vm.dispose);
    await vm.load(fresh('a'));
    expect(failure(await vm.addProduct('missing')), 'missing_product');
    await vm.addProduct('p0', quantityUnits: BigInt.from(2000));
    expect(failure(await vm.setQuantity('p0', '4')), 'insufficient_stock');
    await vm.updateDetails(date: '2026-11-06');
    expect(vm.quote.errorCode, 'insufficient_stock');
    await vm.updateDetails(date: '2026-11-07');
    expect(vm.quote.eligible, isTrue);
    await repo.save(
      const LegacyAccountCodec().decodeJson({
        ...repo.document!.toJson(),
        'products': [product('p0', tracked: true, archived: true)],
      }),
    );
    vm.refresh();
    expect(vm.quote.errorCode, 'archived_product');
    expect(vm.catalog!.items, isEmpty);
    await vm.updateDetails(note: 'can still recover stale ticket');
    expect(vm.active!.note, 'can still recover stale ticket');
    await vm.removeProduct('p0');
    expect(vm.active!.lines, isEmpty);
  });

  test(
    'forty held tickets and atomic swap delegate without changing account',
    () async {
      final store = FixtureStore();
      final repo = await repository(store);
      final vm = SalesViewModel(repo);
      addTearDown(vm.dispose);
      await vm.load(fresh('a0'));
      final accountBefore = store.document;
      for (var i = 0; i < 40; i++) {
        await vm.addProduct('p0');
        expect(
          await vm.hold(
            label: 'H$i',
            heldId: 'h$i',
            fresh: fresh('a${i + 1}'),
            savedAt: '2026-11-07T10:00:00Z',
          ),
          isA<CapabilitySuccess<void>>(),
        );
      }
      await vm.addProduct('p0');
      final payload = store.workspace!.payload;
      final writes = store.workspaceWrites;
      expect(
        failure(
          await vm.hold(
            label: 'overflow',
            heldId: 'h40',
            fresh: fresh('a41'),
            savedAt: '2026-11-07T10:00:00Z',
          ),
        ),
        'held_limit',
      );
      expect(store.workspace!.payload, payload);
      expect(store.workspaceWrites, writes);
      await vm.resume(
        'h0',
        swapId: 'swapped',
        swapLabel: 'active',
        savedAt: '2026-11-07T10:01:00Z',
      );
      expect(vm.active!.id, 'a0');
      expect(vm.held.length, 40);
      expect(vm.held.last.draft.id, 'a40');
      await vm.deleteHeld('swapped');
      expect(vm.held.length, 39);
      expect(store.document, same(accountBefore));
    },
  );

  test(
    'definite failure retains active draft and clears after confirmed retry',
    () async {
      final store = FixtureStore();
      final repo = await repository(store);
      final vm = SalesViewModel(repo);
      addTearDown(vm.dispose);
      await vm.load(fresh('a'));
      store.workspaceWriteFailure = 'file_unavailable';
      expect(failure(await vm.addProduct('p0')), 'file_unavailable');
      expect(vm.active!.lines, isEmpty);
      expect(vm.busy, isFalse);
      store.workspaceWriteFailure = null;
      await vm.addProduct('p0');
      expect(vm.errorCode, isNull);
      expect(vm.active!.lines.length, 1);
    },
  );

  test('unknown acknowledgement blocks mutations until existing readback without rewrite', () async {
    final store = FixtureStore();
    final repo = await repository(store);
    final vm = SalesViewModel(repo);
    addTearDown(vm.dispose);
    await vm.load(fresh('a'));
    store.workspaceWriteFailure = 'commit_unknown';
    expect(failure(await vm.addProduct('p0')), 'commit_unknown');
    final writes = store.workspaceWrites;
    final token = store.workspace!.writeToken;
    expect(vm.needsReadback, isTrue);
    expect(vm.active!.lines, isEmpty);
    expect(failure(await vm.addProduct('p0')), 'commit_unknown');
    expect(store.workspaceWrites, writes);
    store.workspaceWriteFailure = null;
    expect(await vm.reconcile(), isA<CapabilitySuccess<void>>());
    expect(store.workspaceWrites, writes);
    expect(store.workspace!.writeToken, token);
    expect(vm.active!.lines.length, 1);
    expect(vm.needsReadback, isFalse);
  });

  test(
    'competing workspace revision rejects old model until explicit reload',
    () async {
      final repo = await repository(FixtureStore());
      final first = SalesViewModel(repo);
      final second = SalesViewModel(repo);
      addTearDown(first.dispose);
      addTearDown(second.dispose);
      await first.load(fresh('a'));
      await second.load(fresh('b'));
      await second.addProduct('p0');
      expect(failure(await first.addProduct('p0')), 'stale_revision');
      expect(first.active!.lines, isEmpty);
      await first.load(fresh('unused'));
      expect(first.active!.id, 'b');
      expect(first.active!.lines.length, 1);
    },
  );

  test(
    'busy listener reentrancy cannot overwrite frozen submitted fields',
    () async {
      final store = FixtureStore();
      final repo = await repository(store);
      final vm = SalesViewModel(repo);
      addTearDown(vm.dispose);
      await vm.load(fresh('a'));
      Future<CapabilityResult<void>>? competing;
      vm.addListener(() {
        if (vm.busy) competing ??= vm.updateDetails(note: 'injected');
      });
      await vm.updateDetails(note: 'submitted');
      expect(failure(await competing!), 'busy');
      expect(vm.active!.note, 'submitted');
      expect(vm.errorCode, isNull);
    },
  );

  test(
    'listener disposal prevents persistence and tolerates repeated disposal',
    () async {
      final store = FixtureStore();
      final repo = await repository(store);
      final vm = SalesViewModel(repo);
      await vm.load(fresh('a'));
      vm.addListener(vm.dispose);
      expect(failure(await vm.addProduct('p0')), 'disposed');
      expect(store.workspaceWrites, 0);
      vm.dispose();
    },
  );

  test(
    'late acknowledgement after disposal has no publication or callbacks',
    () async {
      final store = DelayedWorkspaceStore();
      final repo = await repository(store);
      final vm = SalesViewModel(repo);
      await vm.load(fresh('a'));
      var notices = 0;
      vm.addListener(() => notices++);
      final pending = vm.addProduct('p0');
      await store.committed.future;
      vm.dispose();
      final prior = notices;
      store.acknowledge.complete();
      expect(failure(await pending), 'disposed');
      expect(notices, prior);
      expect(vm.active, isNull);
    },
  );

  test('generation replacement discards old state and late results', () async {
    final store = DelayedWorkspaceStore();
    final repo = await repository(store);
    final vm = SalesViewModel(repo);
    addTearDown(vm.dispose);
    await vm.load(fresh('a'));
    final pending = vm.addProduct('p0');
    await store.committed.future;
    expect(
      await repo.save(account(), replace: true),
      isA<CapabilitySuccess<void>>(),
    );
    store.acknowledge.complete();
    expect(failure(await pending), 'stale_generation');
    expect(vm.active, isNull);
    expect(vm.held, isEmpty);
    expect(vm.catalog, isNull);
    expect(failure(await vm.load(fresh('old'))), 'stale_generation');
    final replacement = SalesViewModel(repo);
    addTearDown(replacement.dispose);
    // FixtureStore does not clear its workspace on replacement; emulate the storage contract.
    store.inner.workspace = null;
    await replacement.load(fresh('new'));
    expect(replacement.active!.id, 'new');
  });

  test('unloaded and unsupported workspace fail protected', () async {
    final store = FixtureStore();
    final repo = await repository(store);
    final vm = SalesViewModel(repo);
    addTearDown(vm.dispose);
    expect(failure(await vm.addProduct('p0')), 'not_loaded');
    store.workspace = WorkspaceSnapshot(
      payload:
          '{"version":1,"active":{"legacy":"unsupported"},"form":{},"held":[]}',
      revision: 1,
      fence: repo.snapshot!.fence,
      writeToken: 'foreign',
    );
    expect(failure(await vm.load(fresh('a'))), 'unsupported_ticket_workspace');
    expect(vm.active, isNull);
    expect(store.workspaceWrites, 0);
  });
  test(
    'fractional half ties and zero net use the public quote profile',
    () async {
      final repo = await repository(FixtureStore());
      await repo.save(
        const LegacyAccountCodec().decodeJson({
          ...repo.document!.toJson(),
          'products': [product('p0', price: 500)],
        }),
      );
      final vm = SalesViewModel(repo);
      addTearDown(vm.dispose);
      await vm.load(fresh('a'));
      await vm.addProduct('p0', quantityUnits: BigInt.one);
      expect(vm.quote.calculation!.subtotal, BigInt.one);
      await vm.updateDetails(discount: '1');
      expect(vm.quote.calculation!.net, BigInt.zero);
      final before = vm.active!.lines.single;
      expect(
        failure(await vm.setQuantity('p0', '0.0001')),
        'invalid_precision',
      );
      expect(vm.active!.lines.single, same(before));
    },
  );

  test('subtotal overflow remains an ineligible draft rather than financial posting', () async {
    final store = FixtureStore();
    final repo = await repository(store, count: 2);
    await repo.save(
      const LegacyAccountCodec().decodeJson({
        ...repo.document!.toJson(),
        'products': [
          product('p0', price: 1000000000000),
          product('p1', price: 1000000000000),
        ],
      }),
    );
    final before = store.document;
    final vm = SalesViewModel(repo);
    addTearDown(vm.dispose);
    await vm.load(fresh('a'));
    await vm.addProduct('p0');
    await vm.addProduct('p1');
    expect(vm.active!.lines.length, 2);
    expect(vm.quote.errorCode, 'out_of_range');
    expect(vm.quote.eligible, isFalse);
    expect(store.document, same(before));
    await vm.removeProduct('p1');
    expect(vm.quote.eligible, isTrue);
    expect(vm.quote.calculation!.net, BigInt.from(1000000000000));
  });

  test('invalid date and quantity bound reject before writing', () async {
    final store = FixtureStore();
    final repo = await repository(store);
    final vm = SalesViewModel(repo);
    addTearDown(vm.dispose);
    await vm.load(fresh('a'));
    final writes = store.workspaceWrites;
    expect(
      await vm.updateDetails(date: '0999-12-31'),
      isA<CapabilityFailure<void>>(),
    );
    expect(
      failure(
        await vm.addProduct('p0', quantityUnits: BigInt.from(1000000000001)),
      ),
      'invalid_quantity',
    );
    expect(vm.active!.date, '2026-11-07');
    expect(vm.active!.lines, isEmpty);
    expect(store.workspaceWrites, writes);
  });
  test('source quantity entry normalizes Arabic decimals and grouping but rejects exponent syntax', () async {
    final store = FixtureStore();
    final repo = await repository(store);
    final vm = SalesViewModel(repo);
    addTearDown(vm.dispose);
    await vm.load(fresh('a'));
    await vm.addProduct('p0');
    expect(
      await vm.setQuantity('p0', '١٬٢٣٤٫٥٦٧'),
      isA<CapabilitySuccess<void>>(),
    );
    expect(vm.active!.lines.single.quantityUnits, BigInt.from(1234567));
    final before = store.workspace!.payload;
    expect(failure(await vm.setQuantity('p0', '1e2')), 'invalid_decimal');
    expect(store.workspace!.payload, before);
  });
}
