import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar_application/madar_application.dart';
import 'package:dakhl_restaurant/app/app.dart';
import 'package:dakhl_restaurant/app/restaurant_operations_session.dart';
import 'package:dakhl_restaurant/accounts/accounts_surface.dart';
import 'package:dakhl_restaurant/accounts/accounts_repository.dart';
import 'package:dakhl_restaurant/accounts/accounts_view_model.dart';
import 'package:dakhl_restaurant/accounts/legacy_account_codec.dart';
import 'package:dakhl_restaurant/accounts/portable_journal_codec.dart';
import 'package:dakhl_restaurant/shell/shell_view_model.dart';
import 'package:dakhl_restaurant/ui/components.dart';

import '../sales/sales_workflow_session_test.dart' show fixture, fresh;
import '../support/preferences_store.dart';
import '../accounts/accounts_view_model_test.dart' show FixtureStore;

void main() {
  testWidgets(
    'portable app saves sale and category then undoes metadata without losing journals',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
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
      ShellViewModel? shell;
      await tester.pumpWidget(
        DakhlRestaurantApp(
          preferencesStore: MemoryPreferencesStore(),
          operations: session,
          portableDataSurface: const Text('Complete-envelope files'),
          onShellReady: (value) => shell = value,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(DakhlButton, 'إضافة Product'));
      await tester.pumpAndSettle();
      final pay = find.widgetWithText(DakhlButton, 'تأكيد البيع النقدي');
      expect(tester.widget<DakhlButton>(pay).onPressed, isNotNull);
      await tester.ensureVisible(pay);
      await tester.tap(pay);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('تم تأكيد البيع النقدي'), findsOneWidget);
      await tester.tap(find.byTooltip('إغلاق النافذة'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('تم تأكيد البيع النقدي'), findsNothing);
      await tester.pumpAndSettle();
      expect(
        (session.sales.operations.account.toJson()['sales'] as List).length,
        1,
      );
      await session.synchronize();
      final before = const PortableJournalCodec().decodeState(
        store.document!.payload,
      );
      await shell!.navigate('categories');
      await tester.pumpAndSettle();
      await tester.tap(find.text('إضافة خانة'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'خانة مستقلة');
      await tester.tap(find.text('حفظ الخانة'));
      await tester.pumpAndSettle();
      await session.synchronize();
      final after = const PortableJournalCodec().decodeState(
        store.document!.payload,
      );
      expect(
        after.account.categories.any((row) => row['name'] == 'خانة مستقلة'),
        true,
      );
      expect(after.account.toJson()['sales'], before.account.toJson()['sales']);
      expect(
        after.journals.map((j) => j.toJson()).toList(),
        before.journals.map((j) => j.toJson()).toList(),
      );
      expect(after.receipts.length, before.receipts.length);
      await shell!.navigate('settings');
      await tester.pumpAndSettle();
      expect(find.byType(AccountsSurface), findsNothing);
      await tester.tap(find.text('عن دفتر'));
      await tester.pumpAndSettle();
      final undo = find.text('تراجع عن آخر تغيير').last;
      await tester.ensureVisible(undo);
      await tester.tap(undo);
      await tester.pumpAndSettle();
      await session.synchronize();
      final undone = const PortableJournalCodec().decodeState(
        store.document!.payload,
      );
      expect(
        undone.account.categories.any((row) => row['name'] == 'خانة مستقلة'),
        false,
      );
      expect(
        undone.journals.map((j) => j.toJson()).toList(),
        after.journals.map((j) => j.toJson()).toList(),
      );
      expect(undone.receipts.length, after.receipts.length);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );
  testWidgets(
    'normal account category undo uses source controller without portable migration',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final store = FixtureStore();
      final repository = AccountsRepository(store: store);
      await repository.open();
      await repository.save(const LegacyAccountCodec().empty());
      final accounts = AccountsViewModel(repository: repository);
      addTearDown(accounts.dispose);
      ShellViewModel? shell;
      await tester.pumpWidget(
        DakhlRestaurantApp(
          preferencesStore: MemoryPreferencesStore(),
          accounts: accounts,
          onShellReady: (value) => shell = value,
        ),
      );
      await tester.pumpAndSettle();
      await shell!.navigate('categories');
      await tester.pumpAndSettle();
      await tester.tap(find.text('إضافة خانة'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'خانة محلية');
      await tester.tap(find.text('حفظ الخانة'));
      await tester.pumpAndSettle();
      expect(
        repository.document!.categories.any((c) => c['name'] == 'خانة محلية'),
        true,
      );
      await shell!.navigate('settings');
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Local Kitchen');
      await tester.pump();
      await tester.ensureVisible(find.byKey(const Key('settings-save')));
      await tester.tap(find.byKey(const Key('settings-save')));
      await tester.pumpAndSettle();
      expect(
        repository.document!.preferences.restaurant['name'],
        'Local Kitchen',
      );
      await tester.tap(find.text('عن دفتر'));
      await tester.pumpAndSettle();
      final undo = find.text('تراجع عن آخر تغيير').last;
      await tester.ensureVisible(undo);
      await tester.tap(undo);
      await tester.pumpAndSettle();
      expect(repository.document!.preferences.restaurant['name'], '');
      expect(
        repository.document!.categories.any((c) => c['name'] == 'خانة محلية'),
        true,
      );
      await tester.tap(undo);
      await tester.pumpAndSettle();
      expect(
        repository.document!.categories.any((c) => c['name'] == 'خانة محلية'),
        false,
      );
      expect(
        const LegacyAccountCodec()
            .decodeBytes(utf8.encode(store.document!.payload))
            .version,
        11,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );
  for (final portable in [false, true]) {
    testWidgets(
      'explicit settings discard clears retained edits portable=$portable',
      (tester) async {
        tester.view.physicalSize = const Size(1440, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        RestaurantOperationsSession? session;
        AccountsViewModel? accounts;
        if (portable) {
          final (store, snapshot) = await fixture();
          session = (await RestaurantOperationsSession.open(
            store: store,
            snapshot: snapshot,
            compareText: (a, b) => a.compareTo(b),
            fresh: fresh('discard'),
          ) as CapabilitySuccess<RestaurantOperationsSession>).value;
          addTearDown(session.dispose);
        } else {
          final repository = AccountsRepository(store: FixtureStore());
          await repository.open();
          await repository.save(const LegacyAccountCodec().empty());
          accounts = AccountsViewModel(repository: repository);
          addTearDown(accounts.dispose);
        }
        ShellViewModel? shell;
        await tester.pumpWidget(
          DakhlRestaurantApp(
            preferencesStore: MemoryPreferencesStore(),
            accounts: accounts,
            operations: session,
            onShellReady: (value) => shell = value,
          ),
        );
        await tester.pumpAndSettle();
        await shell!.navigate('settings');
        await tester.pumpAndSettle();
        final original = tester
            .widget<TextField>(find.byKey(const Key('settings-name')))
            .controller!
            .text;
        await tester.enterText(
          find.byKey(const Key('settings-name')),
          'Discard this edit',
        );
        await tester.pump();
        await tester.tap(find.widgetWithText(DakhlButton, 'المبيعات').first);
        await tester.pumpAndSettle();
        expect(find.text('هل تريد تجاهل التغييرات؟'), findsOneWidget);
        await tester.tap(find.widgetWithText(DakhlButton, 'تجاهل التغييرات'));
        await tester.pumpAndSettle();
        expect(shell!.routeId, 'sales');
        if (session != null) expect(session.settings.isDirty, false);
        await shell!.navigate('settings');
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<TextField>(find.byKey(const Key('settings-name')))
              .controller!
              .text,
          original,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      },
    );
  }
}
