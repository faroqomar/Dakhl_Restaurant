import 'package:flutter_test/flutter_test.dart';
import 'package:madar_application/madar_application.dart';
import 'package:madar_domain/madar_domain.dart';
import 'package:dakhl_restaurant/accounts/legacy_account_codec.dart';
import 'package:dakhl_restaurant/accounts/portable_journal_codec.dart';
import 'package:dakhl_restaurant/accounts/workspace_document.dart';
import 'package:dakhl_restaurant/app/restaurant_operations_session.dart';
import 'package:dakhl_restaurant/catalog/catalog_view_model.dart';
import 'package:dakhl_restaurant/accounting/categories_view_model.dart';
import 'package:dakhl_restaurant/parties/parties_view_model.dart';

import '../sales/sales_workflow_session_test.dart' show fixture, fresh;

void main() {
  test('existing catalog/category/party controllers join financial session without losing envelope', () async {
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
    final catalog = CatalogViewModel(session.metadataRepository);
    final categories = CategoriesViewModel(session.metadataRepository);
    final parties = PartiesViewModel(session.metadataRepository);
    addTearDown(catalog.dispose);
    addTearDown(categories.dispose);
    addTearDown(parties.dispose);
    expect(
      await catalog.createProduct({
        'id': 'p2',
        'name': 'Second product',
        'code': '',
        'group': '',
        'unit': 'piece',
        'price': 500,
        'minStock': 0,
        'trackStock': false,
        'archived': false,
      }, session: catalog.beginEdit()),
      isA<CapabilitySuccess>(),
    );
    expect(await session.synchronize(), isA<CapabilitySuccess<void>>());
    final category = categories.newCategoryDraft(id: 'extra')..name = 'Extra';
    expect(await categories.saveCategory(category), isA<CapabilitySuccess>());
    expect(await session.synchronize(), isA<CapabilitySuccess<void>>());
    final supplier = parties.newSupplier(id: 's', categoryId: 'samoon')
      ..name = 'Supplier';
    expect(await parties.saveSupplier(supplier), isA<CapabilitySuccess>());
    expect(await session.synchronize(), isA<CapabilitySuccess<void>>());
    expect(session.parties.suppliers.single.name, 'Supplier');
    expect(
      await session.sales.addProduct('p2'),
      isA<CapabilitySuccess<void>>(),
    );
    expect(
      await session.sales.checkout(
        fresh: fresh('next'),
        operationId: 'sale',
        journalId: 'sale-journal',
        recordedAt: '2026-11-07T12:00:00Z',
      ),
      isA<CapabilitySuccess>(),
    );
    expect(
      await session.synchronize(fresh: fresh('next')),
      isA<CapabilitySuccess<void>>(),
    );
    const codec = PortableJournalCodec();
    final before = codec.decodeState(store.document!.payload);
    final candidate = const LegacyAccountCodec().decodeJson({
      ...session.metadataRepository.document!.toJson(),
      'days': {
        '2026-11-07': {
          'expenses': <Object?>[],
          'chickenUsed': 5,
          'chickenLeft': 10,
          'balance': null,
          'totalOverride': null,
          'remaining': null,
        },
      },
    });
    expect(
      await session.metadataRepository.save(candidate),
      isA<CapabilitySuccess>(),
    );
    expect(await session.synchronize(), isA<CapabilitySuccess<void>>());
    final after = codec.decodeState(store.document!.payload);
    expect(after.copyWith(account: before.account).toJson(), before.toJson());
    expect(
      (session.spending.account.days['2026-11-07'] as Map)['chickenUsed'],
      5,
    );
    expect(
      session.metadataRepository.snapshot!.revision,
      session.snapshot.revision,
    );
  });

  test('projection refuses financial rows, financial day edits, opening debt and replacement', () async {
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
    final repository = session.metadataRepository,
        base = repository.document!.toJson();
    final count = store.writes, bytes = store.document!.payload;
    final financial = const LegacyAccountCodec().decodeJson({
      ...base,
      'transactions': [
        {
          'id': 'forbidden',
          'type': 'deposit',
          'date': '2026-11-07',
          'amount': 1000,
          'note': '',
          'createdAt': '2026-11-07T12:00:00Z',
        },
      ],
    });
    expect(
      (await repository.save(financial) as CapabilityFailure).code,
      'metadata_financial_mutation_refused',
    );
    final daily = const LegacyAccountCodec().decodeJson({
      ...base,
      'days': {
        '2026-11-07': {
          'expenses': <Object?>[],
          'chickenUsed': 0,
          'chickenLeft': 0,
          'balance': 1,
          'totalOverride': null,
          'remaining': null,
        },
      },
    });
    expect(
      (await repository.save(daily) as CapabilityFailure).code,
      'metadata_financial_day_refused',
    );
    final opening = const LegacyAccountCodec().decodeJson({
      ...base,
      'suppliers': [
        {
          'id': 's',
          'name': 'Supplier',
          'phone': '',
          'note': '',
          'categoryId': 'samoon',
          'openingBalance': 1,
          'materials': <Object?>[],
        },
      ],
    });
    expect(
      (await repository.save(opening) as CapabilityFailure).code,
      'metadata_opening_debt_refused',
    );
    expect(
      (await repository.save(
        repository.document!,
        replace: true,
      ) as CapabilityFailure).code,
      'metadata_replacement_refused',
    );
    expect(
      (await session.metadataBridge.preserveSource([
        1,
      ]) as CapabilityFailure).code,
      'metadata_import_refused',
    );
    expect(
      (await session.metadataBridge.readPrevious() as CapabilityFailure).code,
      'metadata_recovery_refused',
    );
    expect(store.writes, count);
    expect(store.document!.payload, bytes);
  });

  test('unknown metadata resolves through existing repository and stale drafts cannot overwrite sale', () async {
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
    final catalog = CatalogViewModel(session.metadataRepository);
    addTearDown(catalog.dispose);
    store.throwAfterCommit = true;
    final result = await catalog.editProduct({
      ...((session.metadataRepository.document!.toJson()['products']! as List)
                  .single
              as Map)
          .cast<String, Object?>(),
      'name': 'Updated product',
    }, session: catalog.beginEdit());
    expect((result as CapabilityFailure).code, 'commit_unknown');
    expect(session.metadataRepository.hasUnknownWrite, true);
    expect(
      (await session.sales.addProduct('p') as CapabilityFailure).code,
      'busy',
    );
    store.throwAfterCommit = false;
    expect(await session.reconcileMetadata(), isA<CapabilitySuccess<void>>());
    expect(session.metadataBridge.needsReadback, false);
    final stale = catalog.beginEdit();
    final product =
        ((session.metadataRepository.document!.toJson()['products']! as List)
                    .single
                as Map)
            .cast<String, Object?>();
    expect(
      await session.dailyCash.recordExpense(
        operationId: 'expense',
        expenseId: 'expense',
        journalId: 'expense-journal',
        categoryId: 'samoon',
        amount: BigInt.from(100),
        fundingSource: FundingSource.daily,
        recordedAt: '2026-11-07T12:00:00Z',
      ),
      isA<DurableCommandSuccess>(),
    );
    expect(await session.synchronize(), isA<CapabilitySuccess<void>>());
    final writes = store.writes;
    expect(
      (await catalog.editProduct({
        ...product,
        'name': 'Stale',
      }, session: stale) as CapabilityFailure).code,
      'stale_revision',
    );
    expect(store.writes, writes);
    expect(
      session.sales.operations.account.toJson()['products'],
      contains(containsPair('name', 'Updated product')),
    );
  });

  test('one ticket owner saves frozen form without replacing active or held and gates uncertain drafts', () async {
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
    await session.sales.addProduct('p');
    expect(
      await session.sales.hold(
        label: 'Held',
        heldId: 'held',
        fresh: fresh('second'),
        savedAt: '2026-11-07T12:00:00Z',
      ),
      isA<CapabilitySuccess<void>>(),
    );
    await session.sales.addProduct('p');
    final priorActive = session.sales.active!.toJson(),
        priorHeld = session.sales.held.single.toJson();
    final form = {'note': 'Frozen'};
    final saving = session.sales.saveFormDraft(form);
    form['note'] = 'Caller changed';
    expect(await saving, isA<CapabilitySuccess<void>>());
    final workspace = WorkspaceDocument.decode(store.workspace!.payload);
    expect(workspace.form['note'], 'Frozen');
    expect(session.sales.active!.toJson(), priorActive);
    expect(session.sales.held.single.toJson(), priorHeld);
    store.workspaceWriteFailure = 'commit_unknown';
    expect(
      (await session.sales.saveFormDraft({
        'note': 'Uncertain',
      }) as CapabilityFailure).code,
      'commit_unknown',
    );
    expect(session.sales.draftNeedsReadback, true);
    final directVoid = session.sales.operations.voidIntent(
      operationId: 'blocked-void',
      saleId: 'saved',
      reversalJournalId: 'blocked-inverse',
      reason: 'blocked',
      voidedAt: '2026-11-07T13:00:00Z',
    );
    final direct = await session.sales.operations.submit(directVoid);
    expect((direct as DurableCommandFailure).code, 'busy');
    expect((await session.settings.save() as CapabilityFailure).code, 'busy');
    expect(
      (await session.sales.checkout(
        fresh: fresh('third'),
        operationId: 'blocked',
        journalId: 'blocked',
        recordedAt: '2026-11-07T13:00:00Z',
      ) as CapabilityFailure).code,
      'commit_unknown',
    );
    store.workspaceWriteFailure = null;
    expect(
      await session.sales.reconcileDraft(),
      isA<CapabilitySuccess<void>>(),
    );
    expect(session.sales.draftNeedsReadback, false);
    expect(session.sales.held.single.toJson(), priorHeld);
    await session.metadataBridge.close();
    expect(await store.readDocument(), isA<CapabilitySuccess>());
  });
}
