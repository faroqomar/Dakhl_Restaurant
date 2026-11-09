import 'package:flutter_test/flutter_test.dart';
import 'package:madar_application/madar_application.dart';
import 'package:dakhl_restaurant/accounting/categories_view_model.dart';

import 'categories_view_model_test.dart' show setupFixture;

void main() {
  test(
    'submission captures all draft fields before notifying listeners',
    () async {
      final (_, _, vm) = await setupFixture();
      addTearDown(vm.dispose);
      final draft = vm.newCategoryDraft(id: 'snapshot')..name = 'Fixture';
      vm.addListener(() {
        if (vm.busy) {
          draft.name = 'Later';
          draft.type = CategoryType.primary;
          draft.isArchived = true;
        }
      });
      expect(
        await vm.saveCategory(draft),
        isA<CapabilitySuccess<CategoryRecord>>(),
      );
      final saved = vm.findById('snapshot')!;
      expect(saved.name, 'Fixture');
      expect(saved.type, CategoryType.additional);
      expect(saved.isArchived, false);
      expect(draft.name, 'Later');
    },
  );

  test('category uniqueness uses source case-sensitive names', () async {
    final (_, _, vm) = await setupFixture(
      extraCategories: [
        {'id': 'upper', 'name': 'Gas', 'type': 'additional'},
      ],
    );
    addTearDown(vm.dispose);
    final lower = vm.newCategoryDraft(id: 'lower')..name = 'gas';
    expect(
      await vm.saveCategory(lower),
      isA<CapabilitySuccess<CategoryRecord>>(),
    );
    final duplicate = vm.newCategoryDraft(id: 'duplicate')..name = ' Gas ';
    expect(
      await vm.saveCategory(duplicate),
      isA<CapabilityFailure<CategoryRecord>>().having(
        (r) => r.code,
        'code',
        'duplicate_name',
      ),
    );
  });

  test(
    'validation and storage failures notify and success clears errors',
    () async {
      final (store, _, vm) = await setupFixture();
      addTearDown(vm.dispose);
      final errors = <String?>[];
      vm.addListener(() => errors.add(vm.lastErrorCode));
      final draft = vm.newCategoryDraft(id: 'errors');
      await vm.saveCategory(draft);
      expect(errors, contains('invalid_name'));
      draft.name = 'Valid';
      store.failure = 'unavailable';
      await vm.saveCategory(draft);
      expect(vm.lastErrorCode, 'unavailable');
      expect(errors.last, 'unavailable');
      store.failure = null;
      expect(
        await vm.saveCategory(draft),
        isA<CapabilitySuccess<CategoryRecord>>(),
      );
      expect(vm.lastErrorCode, isNull);
      expect(vm.lastErrorMessage, isNull);
      expect(errors.last, isNull);
    },
  );

  test(
    'referenced archived category keeps its document selector position',
    () async {
      final (_, _, vm) = await setupFixture(
        extraCategories: [
          {'id': 'before', 'name': 'Before', 'type': 'additional'},
          {
            'id': 'historical',
            'name': 'Historical',
            'type': 'additional',
            'archived': true,
          },
          {'id': 'after', 'name': 'After', 'type': 'additional'},
        ],
      );
      addTearDown(vm.dispose);
      expect(
        vm.selectorChoices(currentCategoryId: 'historical').map((c) => c.id),
        [
          'samoon',
          'bread',
          'falafel',
          'market',
          'before',
          'historical',
          'after',
        ],
      );
    },
  );
}
