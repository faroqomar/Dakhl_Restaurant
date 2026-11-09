import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:madar_application/madar_application.dart';
import 'package:dakhl_restaurant/accounts/accounts_repository.dart';
import 'package:dakhl_restaurant/accounts/legacy_account_codec.dart';
import 'package:dakhl_restaurant/parties/parties_view_model.dart';

class Store implements LocalDocumentWorkspaceStore {
  DocumentSnapshot? snapshot;
  String? failure;
  Completer<void>? delay;
  int writes = 0;
  @override
  Future<CapabilityResult<DocumentSnapshot?>> readDocument() async =>
      CapabilitySuccess(snapshot);
  @override
  Future<CapabilityResult<DocumentSnapshot>> writeDocument(
    String payload, {
    required String writeToken,
    DocumentSnapshot? expected,
    bool replaceGeneration = false,
  }) async {
    writes++;
    await delay?.future;
    if (failure != null) return CapabilityFailure(failure!, 'Fixture failure');
    if (expected != snapshot) {
      return const CapabilityFailure('stale_revision', 'Stale');
    }
    snapshot = DocumentSnapshot(
      payload: payload,
      revision: (snapshot?.revision ?? 0) + 1,
      fence: const StorageFence(storeId: 'fixture', generation: 'one'),
      writeToken: writeToken,
    );
    return CapabilitySuccess(snapshot!);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<(Store, AccountsRepository, PartiesViewModel)> setup() async {
  const codec = LegacyAccountCodec();
  final raw = Map<String, Object?>.of(codec.empty().toJson());
  final category = (raw['categories'] as List).first['id'];
  raw['suppliers'] = [
    {
      'id': 'supplier',
      'name': 'Supplier',
      'phone': 'old',
      'note': '',
      'categoryId': category,
      'openingBalance': 900,
      'materials': <Object?>[],
    },
  ];
  raw['materials'] = [
    {
      'id': 'material',
      'name': 'Rice',
      'unit': 'bag',
      'priceCarton': 1200,
      'pricePiece': 150,
      'archived': false,
    },
  ];
  raw['invoices'] = [
    {
      'id': 'invoice',
      'supplierId': 'supplier',
      'number': '1',
      'date': '2026-01-01',
      'lines': [
        {
          'materialId': 'material',
          'name': 'Historic rice',
          'unit': 'old bag',
          'quantity': 2,
          'price': 100,
        },
      ],
      'note': '',
      'createdAt': '2026-01-01T00:00:00.000Z',
    },
  ];
  raw['payments'] = [
    {
      'id': 'payment',
      'supplierId': 'supplier',
      'invoiceId': 'invoice',
      'invoiceAmount': 50,
      'debtAmount': 0,
      'categoryId': category,
      'date': '2026-01-01',
      'amount': 50,
      'funding': {'source': 'daily', 'dailyAmount': 50, 'cashAmount': 0},
      'note': 'historical',
      'createdAt': '2026-01-01T00:00:00.000Z',
    },
  ];
  raw['debts'] = [
    {
      'id': 'debt',
      'supplierId': 'supplier',
      'date': '2026-01-01',
      'amount': 70,
      'note': 'historical',
      'createdAt': '2026-01-01T00:00:00.000Z',
    },
  ];
  final doc = codec.decodeJson(raw);
  final store = Store()
    ..snapshot = DocumentSnapshot(
      payload: utf8.decode(codec.encode(doc)),
      revision: 1,
      fence: const StorageFence(storeId: 'fixture', generation: 'one'),
      writeToken: 'seed',
    );
  final repository = AccountsRepository(store: store);
  await repository.open();
  return (store, repository, PartiesViewModel(repository));
}

void main() {
  test('metadata and independent prices persist without rewriting invoice snapshots or opening debt', () async {
    final (store, repo, vm) = await setup();
    final history = repo.document!.toJson()['invoices'];
    final payments = repo.document!.toJson()['payments'];
    final debts = repo.document!.toJson()['debts'];
    final supplier = vm.editSupplier('supplier')!
      ..name = 'Renamed'
      ..phone = 'new'
      ..note = 'memo'
      ..archived = true;
    expect(await vm.saveSupplier(supplier), isA<CapabilitySuccess>());
    final material = vm.editMaterial('material')!
      ..name = 'New rice'
      ..priceCarton = 880
      ..pricePiece = 33
      ..archived = true;
    expect(await vm.saveMaterial(material), isA<CapabilitySuccess>());
    final reopened = AccountsRepository(store: store);
    await reopened.open();
    final read = PartiesViewModel(reopened);
    expect(read.suppliers.single.openingBalance, 900);
    expect(read.suppliers.single.archived, true);
    expect(read.materials.single.priceCarton, 880);
    expect(read.materials.single.pricePiece, 33);
    expect(reopened.document!.toJson()['invoices'], history);
    expect(reopened.document!.toJson()['payments'], payments);
    expect(reopened.document!.toJson()['debts'], debts);
  });
  test(
    'invalid and duplicate names do not write; definite failure can retry',
    () async {
      final (store, repo, vm) = await setup();
      final invalid = vm.editMaterial('material')!..pricePiece = -1;
      expect(await vm.saveMaterial(invalid), isA<CapabilityFailure>());
      expect(store.writes, 0);
      final duplicate = vm.newMaterial(id: 'other')
        ..name = 'rice'
        ..unit = 'bag';
      expect(await vm.saveMaterial(duplicate), isA<CapabilityFailure>());
      expect(store.writes, 0);
      final draft = vm.editSupplier('supplier')!..note = 'retry';
      final original = repo.document;
      store.failure = 'unavailable';
      expect(await vm.saveSupplier(draft), isA<CapabilityFailure>());
      expect(identical(repo.document, original), true);
      store.failure = null;
      expect(await vm.saveSupplier(draft), isA<CapabilitySuccess>());
    },
  );
  test(
    'stale shared repository drafts cannot overwrite intervening changes',
    () async {
      final (store, repo, vm) = await setup();
      final stale = vm.editSupplier('supplier')!..name = 'stale';
      final other = PartiesViewModel(repo);
      expect(
        await other.saveMaterial(
          other.editMaterial('material')!..pricePiece = 500,
        ),
        isA<CapabilitySuccess>(),
      );
      final result = await vm.saveSupplier(stale) as CapabilityFailure;
      expect(result.code, 'conflict');
      expect(store.writes, 1);
    },
  );
  test(
    'in-flight duplicate is busy and independent repository writer is fenced',
    () async {
      final (store, repo, vm) = await setup();
      final secondRepo = AccountsRepository(store: store);
      await secondRepo.open();
      final other = PartiesViewModel(secondRepo);
      final stale = other.editMaterial('material')!..pricePiece = 999;
      store.delay = Completer<void>();
      final pending = vm.saveSupplier(
        vm.editSupplier('supplier')!..note = 'first',
      );
      expect(
        (await vm.saveSupplier(
          vm.editSupplier('supplier')!,
        ) as CapabilityFailure).code,
        'busy',
      );
      store.delay!.complete();
      expect(await pending, isA<CapabilitySuccess>());
      expect(
        (await other.saveMaterial(stale) as CapabilityFailure).code,
        'stale_revision',
      );
      expect(repo.document!.toJson()['materials'], isNotNull);
    },
  );
  test('new supplier has zero opening; archived IDs remain usable and drafts require an account', () async {
    final (_, repo, vm) = await setup();
    final draft = vm.newSupplier(
      id: 'new',
      categoryId: vm.suppliers.single.categoryId,
    )..name = 'Second';
    expect(await vm.saveSupplier(draft), isA<CapabilitySuccess>());
    expect(vm.suppliers.last.openingBalance, 0);
    final empty = PartiesViewModel(AccountsRepository(store: Store()));
    expect(() => empty.newMaterial(id: 'm'), throwsStateError);
    expect(repo.document, isNotNull);
  });
  test(
    'unknown acknowledgement prevents retry; disposing during write is safe',
    () async {
      final (store, repo, vm) = await setup();
      final draft = vm.editSupplier('supplier')!..note = 'unknown';
      store.failure = 'commit_unknown';
      expect(
        (await vm.saveSupplier(draft) as CapabilityFailure).code,
        'commit_unknown',
      );
      expect(repo.hasUnknownWrite, true);
      expect(
        (await vm.saveSupplier(draft) as CapabilityFailure).code,
        'commit_unknown',
      );
      expect(store.writes, 1);
      final (otherStore, _, other) = await setup();
      otherStore.delay = Completer<void>();
      final pending = other.saveMaterial(
        other.editMaterial('material')!..unit = 'new unit',
      );
      other.dispose();
      otherStore.delay!.complete();
      expect(await pending, isA<CapabilitySuccess>());
    },
  );
}
