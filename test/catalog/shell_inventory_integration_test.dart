import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar_application/madar_application.dart';
import 'package:dakhl_restaurant/accounts/accounts_repository.dart';
import 'package:dakhl_restaurant/accounts/accounts_view_model.dart';
import 'package:dakhl_restaurant/app/app.dart';
import 'package:dakhl_restaurant/catalog/inventory_surface.dart';
import 'package:dakhl_restaurant/catalog/product_form_dialog.dart';
import 'package:dakhl_restaurant/ui/dakhl_ui.dart';

import '../accounts/accounts_view_model_test.dart' show FixtureStore;
import '../support/preferences_store.dart';

Future<(AccountsRepository, AccountsViewModel)> setupAccounts() async {
  final store = FixtureStore();
  final repo = AccountsRepository(store: store);
  final accountsVm = AccountsViewModel(repository: repo);
  await accountsVm.initialize();
  await accountsVm.save();
  return (repo, accountsVm);
}

void desktop(WidgetTester tester) {
  tester.view.physicalSize = const Size(1440, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  testWidgets(
    'account generation change rebuilds the mounted inventory with a live model',
    (tester) async {
      desktop(tester);
      final (repo, accounts) = await setupAccounts();
      final preferences = MemoryPreferencesStore(
        snapshot: PreferenceSnapshot(
          payload: jsonEncode({
            'schemaVersion': 1,
            'lastRouteId': 'inventory',
            'shortcuts': [
              'sales',
              'inventory',
              'expenses',
              'cash',
              'materials',
              'settings',
            ],
          }),
          revision: 1,
        ),
      );
      await tester.pumpWidget(
        DakhlRestaurantApp(accounts: accounts, preferencesStore: preferences),
      );
      await tester.pumpAndSettle();
      final oldModel = tester
          .widget<InventorySurface>(find.byType(InventorySurface))
          .model;
      await repo.save(
        repo.codec.decodeJson(repo.document!.toJson()),
        replace: true,
      );
      await accounts.initialize();
      await tester.pumpAndSettle();
      final newModel = tester
          .widget<InventorySurface>(find.byType(InventorySurface))
          .model;
      expect(identical(oldModel, newModel), isFalse);
      expect(() => newModel!.beginEdit(), returnsNormally);
      expect(() => oldModel!.beginEdit(), throwsStateError);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      accounts.dispose();
    },
  );

  testWidgets(
    'DakhlRestaurantApp renders InventorySurface when navigating to inventory route',
    (tester) async {
      desktop(tester);
      final (repo, accountsVm) = await setupAccounts();
      final prefStore = MemoryPreferencesStore(
        snapshot: PreferenceSnapshot(
          payload: jsonEncode({
            'schemaVersion': 1,
            'lastRouteId': 'inventory',
            'shortcuts': [
              'sales',
              'inventory',
              'expenses',
              'cash',
              'materials',
              'settings',
            ],
          }),
          revision: 1,
        ),
      );

      await tester.pumpWidget(
        DakhlRestaurantApp(accounts: accountsVm, preferencesStore: prefStore),
      );
      await tester.pumpAndSettle();

      expect(find.byType(InventorySurface), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(InventorySurface),
          matching: find.text('المخزن'),
        ),
        findsOneWidget,
      );
      expect(find.widgetWithText(DakhlButton, 'إضافة صنف'), findsAtLeast(1));

      accountsVm.dispose();
    },
  );

  testWidgets('shell protects dirty product dialog from route navigation', (
    tester,
  ) async {
    desktop(tester);
    final (repo, accountsVm) = await setupAccounts();
    final prefStore = MemoryPreferencesStore(
      snapshot: PreferenceSnapshot(
        payload: jsonEncode({
          'schemaVersion': 1,
          'lastRouteId': 'inventory',
          'shortcuts': [
            'sales',
            'inventory',
            'expenses',
            'cash',
            'materials',
            'settings',
          ],
        }),
        revision: 1,
      ),
    );

    await tester.pumpWidget(
      DakhlRestaurantApp(accounts: accountsVm, preferencesStore: prefStore),
    );
    await tester.pumpAndSettle();

    // Tap 'إضافة صنف' (top button)
    await tester.tap(find.widgetWithText(DakhlButton, 'إضافة صنف').first);
    await tester.pumpAndSettle();

    expect(find.byType(ProductFormDialog), findsOneWidget);

    // Enter name to dirty the form
    final nameField = find.widgetWithText(DakhlField, 'اسم الصنف');
    await tester.enterText(nameField, 'كباب تجريبي');
    await tester.pumpAndSettle();

    // Try to cancel while form is dirty
    final cancelBtn = find.widgetWithText(DakhlButton, 'إلغاء');
    await tester.tap(cancelBtn);
    await tester.pumpAndSettle();

    // Discard confirmation dialog should be shown
    expect(find.text('تغييرات غير محفوظة'), findsOneWidget);
    expect(find.text('هل تريد تجاهل التغييرات؟'), findsOneWidget);

    // Cancel discard ("متابعة التعديل")
    await tester.tap(find.text('متابعة التعديل'));
    await tester.pumpAndSettle();

    // ProductFormDialog is still open with dirty input retained
    expect(find.byType(ProductFormDialog), findsOneWidget);
    expect(find.text('كباب تجريبي'), findsOneWidget);

    // Now tap cancel again and confirm discard ("تجاهل التغييرات")
    await tester.tap(cancelBtn);
    await tester.pumpAndSettle();
    expect(find.text('تغييرات غير محفوظة'), findsOneWidget);

    await tester.tap(find.text('تجاهل التغييرات'));
    await tester.pumpAndSettle();

    // Product dialog is dismissed
    expect(find.byType(ProductFormDialog), findsNothing);

    accountsVm.dispose();
  });

  testWidgets(
    'DakhlRestaurantApp handles null accounts gracefully without error',
    (tester) async {
      desktop(tester);
      final prefStore = MemoryPreferencesStore(
        snapshot: PreferenceSnapshot(
          payload: jsonEncode({
            'schemaVersion': 1,
            'lastRouteId': 'inventory',
            'shortcuts': [
              'sales',
              'inventory',
              'expenses',
              'cash',
              'materials',
              'settings',
            ],
          }),
          revision: 1,
        ),
      );

      // Render app with null accounts
      await tester.pumpWidget(
        DakhlRestaurantApp(accounts: null, preferencesStore: prefStore),
      );
      await tester.pumpAndSettle();

      expect(find.byType(Phase01RouteSurface), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
