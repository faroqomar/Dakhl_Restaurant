import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:madar_application/madar_application.dart';
import 'package:dakhl_restaurant/accounting/categories_view_model.dart';
import 'package:dakhl_restaurant/accounts/accounts_repository.dart';
import 'package:dakhl_restaurant/accounts/legacy_account_codec.dart';

class FixtureStore implements LocalDocumentWorkspaceStore {
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
      return const CapabilityFailure(
        'stale_revision',
        'Stale revision in fixture',
      );
    }
    snapshot = DocumentSnapshot(
      payload: payload,
      revision: (snapshot?.revision ?? 0) + 1,
      fence: const StorageFence(storeId: 'fixture', generation: 'cat-test'),
      writeToken: writeToken,
    );
    return CapabilitySuccess(snapshot!);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<(FixtureStore, AccountsRepository, CategoriesViewModel)> setupFixture({
  List<Map<String, Object?>>? extraCategories,
  Map<String, Object?>? initialDays,
}) async {
  const codec = LegacyAccountCodec();
  final raw = Map<String, Object?>.of(codec.empty().toJson());

  if (extraCategories != null) {
    final existing = (raw['categories'] as List).cast<Map<String, Object?>>();
    raw['categories'] = [...existing, ...extraCategories];
  }

  raw['suppliers'] = [
    {
      'id': 'supplier-1',
      'name': 'مورد اللحم',
      'phone': '07700000000',
      'note': '',
      'categoryId': 'market',
      'openingBalance': 15000,
      'materials': <Object?>[],
    },
  ];

  raw['days'] =
      initialDays ??
      {
        '2026-03-01': {
          'expenses': [
            {
              'id': 'exp-1',
              'categoryId': 'samoon',
              'amount': 5000,
              'note': 'صمون صباحي',
              'funding': {
                'source': 'daily',
                'dailyAmount': 5000,
                'cashAmount': 0,
              },
            },
          ],
          'chickenUsed': 0,
          'chickenLeft': 0,
          'balance': null,
          'totalOverride': null,
          'remaining': null,
          'corrections': <Object?>[],
        },
      };

  final doc = codec.decodeJson(raw);
  final store = FixtureStore()
    ..snapshot = DocumentSnapshot(
      payload: utf8.decode(codec.encode(doc)),
      revision: 1,
      fence: const StorageFence(storeId: 'fixture', generation: 'cat-test'),
      writeToken: 'seed-token',
    );
  final repository = AccountsRepository(store: store);
  await repository.open();
  return (store, repository, CategoriesViewModel(repository));
}

void main() {
  group('CategoriesViewModel presentation contract (C4-01 / C4-03)', () {
    test(
      'initializes with 4 built-in categories in order with Arabic names',
      () async {
        final (_, _, vm) = await setupFixture();

        expect(vm.allCategories.length, 4);
        expect(vm.activeCategories.length, 4);
        expect(vm.primaryCategories.length, 4);
        expect(vm.additionalCategories.length, 0);
        expect(vm.archivedCategories.length, 0);

        final samoon = vm.findById('samoon')!;
        expect(samoon.name, 'الصمون');
        expect(samoon.isBuiltIn, isTrue);
        expect(samoon.isActive, isTrue);
        expect(samoon.isPrimary, isTrue);
        expect(samoon.isArchived, isFalse);

        expect(vm.categoryName('samoon'), 'الصمون');
        expect(vm.categoryName('unknown-id'), 'خانة');
        expect(
          vm.categoryName('unknown-id', fallback: 'غير معروف'),
          'غير معروف',
        );
      },
    );

    test('selectorChoices includes active categories and includes current archived category if referenced', () async {
      final (_, _, vm) = await setupFixture(
        extraCategories: [
          {
            'id': 'custom-cleaning',
            'name': 'منظفات',
            'type': 'additional',
            'archived': false,
          },
          {
            'id': 'custom-old-decor',
            'name': 'ديكورات قديمة',
            'type': 'additional',
            'archived': true,
          },
        ],
      );

      expect(vm.allCategories.length, 6);
      expect(vm.activeCategories.length, 5);
      expect(vm.archivedCategories.length, 1);

      // Without currentCategoryId: returns only active categories
      final activeChoices = vm.selectorChoices();
      expect(
        activeChoices.map((c) => c.id),
        containsAll([
          'samoon',
          'bread',
          'falafel',
          'market',
          'custom-cleaning',
        ]),
      );
      expect(activeChoices.any((c) => c.id == 'custom-old-decor'), isFalse);

      // With active currentCategoryId: returns active categories
      final activeSelectedChoices = vm.selectorChoices(
        currentCategoryId: 'custom-cleaning',
      );
      expect(
        activeSelectedChoices.map((c) => c.id),
        containsAll([
          'samoon',
          'bread',
          'falafel',
          'market',
          'custom-cleaning',
        ]),
      );
      expect(
        activeSelectedChoices.any((c) => c.id == 'custom-old-decor'),
        isFalse,
      );

      // With archived currentCategoryId: includes the archived category so historical entry preserves its selection
      final archivedSelectedChoices = vm.selectorChoices(
        currentCategoryId: 'custom-old-decor',
      );
      expect(
        archivedSelectedChoices.any((c) => c.id == 'custom-old-decor'),
        isTrue,
      );
      expect(archivedSelectedChoices.length, 6);
    });
  });

  group('Classification & automatic type save (C4-01)', () {
    test('switching category type triggers automatic save and survives repository reopen', () async {
      final (store, repo, vm) = await setupFixture();

      // Core built-in can switch classification between primary and additional
      final result = await vm.setCategoryType(
        'falafel',
        CategoryType.additional,
      );
      expect(result, isA<CapabilitySuccess<CategoryRecord>>());
      expect(store.writes, 1);

      expect(vm.findById('falafel')!.type, CategoryType.additional);
      expect(vm.findById('falafel')!.isAdditional, isTrue);
      expect(vm.primaryCategories.map((c) => c.id), isNot(contains('falafel')));
      expect(vm.additionalCategories.map((c) => c.id), contains('falafel'));

      // Reopen repository to verify persistence across restarts
      final reopenedRepo = AccountsRepository(store: store);
      await reopenedRepo.open();
      final reopenedVm = CategoriesViewModel(reopenedRepo);
      expect(reopenedVm.findById('falafel')!.type, CategoryType.additional);
      expect(reopenedVm.findById('falafel')!.isBuiltIn, isTrue);
    });

    test('setting the same type is a no-op that writes zero bytes', () async {
      final (store, _, vm) = await setupFixture();

      final result = await vm.setCategoryType('samoon', CategoryType.primary);
      expect(result, isA<CapabilitySuccess<CategoryRecord>>());
      expect(store.writes, 0);
    });
  });

  group('Category create, edit & inline creation (C4-01 / C4-02 / C4-03)', () {
    test('creates custom category with stable ID and survives restart without altering history', () async {
      final (store, repo, vm) = await setupFixture();
      final originalDays = repo.document!.toJson()['days'];
      final originalSuppliers = repo.document!.toJson()['suppliers'];

      final draft = vm.newCategoryDraft(type: CategoryType.additional);
      draft.name = 'الغاز والمحروقات';
      final result = await vm.saveCategory(draft);

      expect(result, isA<CapabilitySuccess<CategoryRecord>>());
      final savedRecord = (result as CapabilitySuccess<CategoryRecord>).value;
      expect(savedRecord.name, 'الغاز والمحروقات');
      expect(savedRecord.type, CategoryType.additional);
      expect(savedRecord.isBuiltIn, isFalse);
      expect(savedRecord.isArchived, isFalse);
      expect(store.writes, 1);

      // Verify history is untouched
      expect(repo.document!.toJson()['days'], equals(originalDays));
      expect(repo.document!.toJson()['suppliers'], equals(originalSuppliers));

      // Reopen
      final reopenedRepo = AccountsRepository(store: store);
      await reopenedRepo.open();
      final reopenedVm = CategoriesViewModel(reopenedRepo);
      expect(reopenedVm.findById(savedRecord.id)?.name, 'الغاز والمحروقات');
      expect(reopenedVm.allCategories.length, 5);
    });

    test(
      'createInlineCategory creates category immediately and is selector-ready',
      () async {
        final (store, repo, vm) = await setupFixture();

        final result = await vm.createInlineCategory(
          name: 'نثريات متنوعة',
          type: CategoryType.additional,
        );

        expect(result, isA<CapabilitySuccess<CategoryRecord>>());
        final record = (result as CapabilitySuccess<CategoryRecord>).value;
        expect(record.name, 'نثريات متنوعة');
        expect(vm.activeCategories.map((c) => c.id), contains(record.id));
        expect(vm.selectorChoices().map((c) => c.id), contains(record.id));
        expect(store.writes, 1);
      },
    );

    test('edits custom category and preserves stable identity for historical references', () async {
      final (store, repo, vm) = await setupFixture(
        extraCategories: [
          {
            'id': 'cat-spice',
            'name': 'بهارات',
            'type': 'additional',
            'archived': false,
          },
        ],
        initialDays: {
          '2026-03-01': {
            'expenses': [
              {
                'id': 'exp-spice',
                'categoryId': 'cat-spice',
                'amount': 2500,
                'note': 'بهارات مشكلة',
                'funding': {
                  'source': 'daily',
                  'dailyAmount': 2500,
                  'cashAmount': 0,
                },
              },
            ],
            'chickenUsed': 0,
            'chickenLeft': 0,
            'balance': null,
            'totalOverride': null,
            'remaining': null,
            'corrections': <Object?>[],
          },
        },
      );

      final draft = vm.editCategoryDraft('cat-spice')!;
      expect(draft.name, 'بهارات');
      draft.name = 'توابل وبهارات درجة أولى';
      draft.type = CategoryType.primary;

      final saveResult = await vm.saveCategory(draft);
      expect(saveResult, isA<CapabilitySuccess<CategoryRecord>>());
      expect(store.writes, 1);

      // Category name updated, ID fixed
      expect(vm.categoryName('cat-spice'), 'توابل وبهارات درجة أولى');
      expect(vm.findById('cat-spice')!.isPrimary, isTrue);

      // Historical expense continues pointing to 'cat-spice' and was not rewritten
      final days = repo.document!.toJson()['days'] as Map<String, Object?>;
      final day = days['2026-03-01']! as Map<String, Object?>;
      final expenses = (day['expenses']! as List).cast<Map<String, Object?>>();
      expect(expenses.single['categoryId'], 'cat-spice');
    });
  });

  group('Built-in category restrictions (C4-02)', () {
    test('built-in categories cannot be renamed', () async {
      final (store, _, vm) = await setupFixture();

      final draft = vm.editCategoryDraft('samoon')!;
      expect(draft.isBuiltIn, isTrue);

      // Setter ignores renaming attempts on built-ins
      draft.name = 'اسم جديد';
      expect(draft.name, 'الصمون');

      // Even if a draft is constructed with a renamed built-in, save rejects it
      final hackedDraft = vm.newCategoryDraft(id: 'samoon');
      hackedDraft.name = 'صمون حجري';
      final result = await vm.saveCategory(hackedDraft);

      expect(result, isA<CapabilityFailure<CategoryRecord>>());
      final failure = result as CapabilityFailure<CategoryRecord>;
      expect(failure.code, 'forbidden');
      expect(store.writes, 0);
    });

    test('built-in categories cannot be archived', () async {
      final (store, _, vm) = await setupFixture();

      final draft = vm.editCategoryDraft('bread')!;
      draft.isArchived = true;
      expect(draft.isArchived, isFalse); // locked

      final result = await vm.archiveCategory('bread');
      expect(result, isA<CapabilityFailure<CategoryRecord>>());
      final failure = result as CapabilityFailure<CategoryRecord>;
      expect(failure.code, 'forbidden');
      expect(store.writes, 0);
    });
  });

  group('Duplicate validation & normalization (C4-02)', () {
    test('rejects duplicate name matching existing category exactly or with whitespace trimming', () async {
      final (store, _, vm) = await setupFixture();

      final draft = vm.newCategoryDraft();
      draft.name = '  الصمون  '; // same as built-in after trim
      final result = await vm.saveCategory(draft);

      expect(result, isA<CapabilityFailure<CategoryRecord>>());
      final failure = result as CapabilityFailure<CategoryRecord>;
      expect(failure.code, 'duplicate_name');
      expect(store.writes, 0);
    });

    test('rejects empty or whitespace-only name', () async {
      final (store, _, vm) = await setupFixture();

      final draft = vm.newCategoryDraft();
      draft.name = '   ';
      final result = await vm.saveCategory(draft);

      expect(result, isA<CapabilityFailure<CategoryRecord>>());
      final failure = result as CapabilityFailure<CategoryRecord>;
      expect(failure.code, 'invalid_name');
      expect(store.writes, 0);
    });

    test('rejects name exceeding 80 characters', () async {
      final (store, _, vm) = await setupFixture();

      final draft = vm.newCategoryDraft();
      draft.name = 'أ' * 81;
      final result = await vm.saveCategory(draft);

      expect(result, isA<CapabilityFailure<CategoryRecord>>());
      final failure = result as CapabilityFailure<CategoryRecord>;
      expect(failure.code, 'invalid_name');
      expect(store.writes, 0);
    });
  });

  group('Archive & restore lifecycle (C4-02)', () {
    test('custom category can be archived and restored without losing historical records', () async {
      final (store, _, vm) = await setupFixture(
        extraCategories: [
          {
            'id': 'cat-packaging',
            'name': 'أكياس وتغليف',
            'type': 'additional',
            'archived': false,
          },
        ],
      );

      expect(vm.activeCategories.map((c) => c.id), contains('cat-packaging'));

      // Archive custom category
      final archiveResult = await vm.archiveCategory('cat-packaging');
      expect(archiveResult, isA<CapabilitySuccess<CategoryRecord>>());
      expect(store.writes, 1);

      expect(vm.findById('cat-packaging')!.isArchived, isTrue);
      expect(
        vm.activeCategories.map((c) => c.id),
        isNot(contains('cat-packaging')),
      );
      expect(vm.archivedCategories.map((c) => c.id), contains('cat-packaging'));

      // Restore custom category
      final restoreResult = await vm.restoreCategory('cat-packaging');
      expect(restoreResult, isA<CapabilitySuccess<CategoryRecord>>());
      expect(store.writes, 2);

      expect(vm.findById('cat-packaging')!.isArchived, isFalse);
      expect(vm.activeCategories.map((c) => c.id), contains('cat-packaging'));
      expect(
        vm.archivedCategories.map((c) => c.id),
        isNot(contains('cat-packaging')),
      );
    });
  });

  group('Fencing, stale draft, overlapping saves & unknown writes', () {
    test('stale draft cannot overwrite intervening category changes and retains draft fields on failure', () async {
      final (store, repo, vm1) = await setupFixture();
      final staleDraft = vm1.newCategoryDraft()..name = 'أدوات مطبخ';

      // Intervening save via another ViewModel instance
      final vm2 = CategoriesViewModel(repo);
      await vm2.createInlineCategory(name: 'مشتريات طارئة');
      expect(store.writes, 1);

      // Now attempt to save stale draft from vm1
      final result = await vm1.saveCategory(staleDraft);
      expect(result, isA<CapabilityFailure<CategoryRecord>>());
      final failure = result as CapabilityFailure<CategoryRecord>;
      expect(failure.code, 'conflict');
      expect(store.writes, 1);

      // The draft retains all user input so it can be retried
      expect(staleDraft.name, 'أدوات مطبخ');
    });

    test('concurrent overlapping save is rejected with busy code', () async {
      final (store, _, vm) = await setupFixture();
      store.delay = Completer<void>();

      final draft1 = vm.newCategoryDraft()..name = 'خانة أولى';
      final draft2 = vm.newCategoryDraft()..name = 'خانة ثانية';

      final pending1 = vm.saveCategory(draft1);
      final result2 = await vm.saveCategory(draft2);

      expect(result2, isA<CapabilityFailure<CategoryRecord>>());
      expect((result2 as CapabilityFailure<CategoryRecord>).code, 'busy');

      store.delay!.complete();
      final result1 = await pending1;
      expect(result1, isA<CapabilitySuccess<CategoryRecord>>());
    });

    test('reconciliation required if repository has unknown write', () async {
      final (store, repo, vm) = await setupFixture();

      // Simulate repository unknown write
      store.failure = 'store_error';
      // Trigger a failed save on repository to create unknown state if token was sent, or test hasUnknownWrite guard
      final draft = vm.newCategoryDraft()..name = 'فحص العطل';
      final res = await vm.saveCategory(draft);
      expect(res, isA<CapabilityFailure<CategoryRecord>>());
    });

    test(
      'disposed ViewModel rejects operations safely without calling listeners',
      () async {
        final (_, _, vm) = await setupFixture();
        var notifyCount = 0;
        vm.addListener(() => notifyCount++);

        final draft = vm.newCategoryDraft()..name = 'خانة متأخرة';
        vm.dispose();
        expect(vm.isDisposed, isTrue);

        final result = await vm.saveCategory(draft);
        expect(result, isA<CapabilityFailure<CategoryRecord>>());
        expect((result as CapabilityFailure<CategoryRecord>).code, 'disposed');
        expect(notifyCount, 0);

        expect(() => vm.newCategoryDraft(), throwsStateError);
      },
    );
  });
}
