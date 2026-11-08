import 'package:flutter/material.dart';
import 'package:dakhl_restaurant/accounting/chicken_editor.dart';
import 'package:dakhl_restaurant/accounts/accounts_repository.dart';
import 'package:dakhl_restaurant/accounts/legacy_account_codec.dart';

import '../accounts/accounts_view_model_test.dart' as account_fixture;

import 'package:flutter_test/flutter_test.dart';
import 'package:madar_application/madar_application.dart';
import 'package:dakhl_restaurant/accounting/daily_metadata_controller.dart';
import 'package:dakhl_restaurant/accounting/daily_cash_queries.dart';

import 'categories_view_model_test.dart' show setupFixture;

void main() {
  testWidgets('blocked chicken save reports why it cannot write', (
    tester,
  ) async {
    final store = account_fixture.FixtureStore();
    final repository = AccountsRepository(store: store);
    await repository.open();
    await repository.save(const LegacyAccountCodec().empty());
    final writes = store.writes;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showChickenEditor(
              context,
              controller: DailyMetadataController(repository),
              date: '2026-03-01',
              used: 0,
              left: 0,
              canWrite: () => false,
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('حفظ التغيير'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'الحفظ غير متاح الآن. أكمل العملية المعلقة أو حدّث الحساب ثم حاول مرة أخرى.',
      ),
      findsOneWidget,
    );
    expect(store.writes, writes);
  });
  testWidgets(
    'stale chicken verification permits closing without confirming save',
    (tester) async {
      final store = account_fixture.FixtureStore();
      final repository = AccountsRepository(store: store);
      await repository.open();
      await repository.save(const LegacyAccountCodec().empty());
      final controller = DailyMetadataController(repository);
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => showChickenEditor(
                context,
                controller: controller,
                date: '2026-03-01',
                used: 0,
                left: 0,
                canWrite: () => true,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      store.throwAfterCommit = true;
      await tester.tap(find.text('حفظ التغيير'));
      await tester.pumpAndSettle();
      expect(controller.needsReadback, true);
      final committed = store.document!;
      store.document = DocumentSnapshot(
        payload: committed.payload,
        revision: committed.revision + 1,
        fence: committed.fence,
        writeToken: 'other-writer',
      );
      store.throwAfterCommit = false;
      await tester.tap(find.text('التحقق من الحفظ'));
      await tester.pumpAndSettle();
      expect(controller.needsReadback, false);
      expect(
        find.text(
          'تعذّر الحفظ. راجع الأعداد أو أعد فتح النافذة بعد تحديث الحساب.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('إلغاء'));
      await tester.pumpAndSettle();
      expect(find.text('تتبّع الدجاج'), findsNothing);
    },
  );

  test(
    'stale readback releases chicken pending ownership without confirming save',
    () async {
      final store = account_fixture.FixtureStore();
      final repository = AccountsRepository(store: store);
      await repository.open();
      await repository.save(const LegacyAccountCodec().empty());
      final controller = DailyMetadataController(repository);
      store.throwAfterCommit = true;
      expect(
        await controller.saveChicken(date: '2026-03-01', used: '2', left: '3'),
        isA<CapabilityFailure<void>>(),
      );
      expect(controller.needsReadback, true);
      final committed = store.document!;
      store.document = DocumentSnapshot(
        payload: committed.payload,
        revision: committed.revision + 1,
        fence: committed.fence,
        writeToken: 'other-writer',
      );
      store.throwAfterCommit = false;
      expect(
        (await controller.reconcile() as CapabilityFailure<void>).code,
        'stale_revision',
      );
      expect(repository.hasUnknownWrite, false);
      expect(controller.needsReadback, false);
    },
  );

  test(
    'chicken update preserves financial records and rejects stale editor',
    () async {
      final (store, repository, model) = await setupFixture();
      addTearDown(model.dispose);
      final before = repository.document!;
      final controller = DailyMetadataController(repository);
      final stale = DailyMetadataController(repository);
      expect(
        await controller.saveChicken(date: '2026-03-01', used: '١٢', left: '٨'),
        isA<CapabilitySuccess<void>>(),
      );
      final after = repository.document!;
      expect(after.days['2026-03-01'], containsPair('chickenUsed', 12));
      expect(after.days['2026-03-01'], containsPair('chickenLeft', 8));
      final oldDay = Map<String, Object?>.from(
        before.days['2026-03-01']! as Map,
      );
      final newDay = Map<String, Object?>.from(
        after.days['2026-03-01']! as Map,
      );
      for (final key in ['chickenUsed', 'chickenLeft']) {
        oldDay.remove(key);
        newDay.remove(key);
      }
      expect(newDay, oldDay);
      for (final entry in before.toJson().entries) {
        if (entry.key != 'days') expect(after.toJson()[entry.key], entry.value);
      }
      expect(
        DailyCashQueries(after).day('2026-03-01').dailySpent,
        DailyCashQueries(before).day('2026-03-01').dailySpent,
      );
      final writes = store.writes;
      expect(
        (await stale.saveChicken(
          date: '2026-03-01',
          used: '1',
          left: '1',
        ) as CapabilityFailure).code,
        'stale_revision',
      );
      expect(store.writes, writes);
    },
  );
}
