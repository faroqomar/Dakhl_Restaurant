import 'dart:convert';

import 'package:dakhl_restaurant/app/app.dart';
import 'package:dakhl_restaurant/ui/dakhl_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:madar_application/madar_application.dart';

import '../support/preferences_store.dart';

void main() {
  void desktop(WidgetTester tester) {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('Arabic RTL development app composes the navigation shell', (
    tester,
  ) async {
    desktop(tester);
    await tester.pumpWidget(
      DakhlRestaurantApp(preferencesStore: MemoryPreferencesStore()),
    );
    await tester.pumpAndSettle();
    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.title, 'Dakhl_Restaurant Dev');
    final surface = find.byType(Phase01RouteSurface);
    expect(surface, findsOneWidget);
    expect(Localizations.localeOf(tester.element(surface)), const Locale('ar'));
    expect(Directionality.of(tester.element(surface)), TextDirection.rtl);
    expect(find.byType(DakhlShellView), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'fresh app instance restores route and slots without bootstrap write',
    (tester) async {
      desktop(tester);
      final store = MemoryPreferencesStore(
        snapshot: PreferenceSnapshot(
          payload: jsonEncode({
            'schemaVersion': 1,
            'lastRouteId': 'inventory',
            'shortcuts': [
              'settings',
              '',
              'sales',
              'cash',
              'sales',
              'materials',
            ],
          }),
          revision: 4,
        ),
      );
      await tester.pumpWidget(DakhlRestaurantApp(preferencesStore: store));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<Phase01RouteSurface>(find.byType(Phase01RouteSurface))
            .routeId,
        'inventory',
      );
      expect(
        tester.widget<DakhlShellView>(find.byType(DakhlShellView)).shortcuts,
        ['settings', '', 'sales', 'cash', 'sales', 'materials'],
      );
      expect(store.writes, isEmpty);
    },
  );

  testWidgets(
    'a visible shortcut changes route and saves shell preferences only',
    (tester) async {
      desktop(tester);
      final store = MemoryPreferencesStore();
      await tester.pumpWidget(DakhlRestaurantApp(preferencesStore: store));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(DakhlButton, 'الإعدادات').first);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<Phase01RouteSurface>(find.byType(Phase01RouteSurface))
            .routeId,
        'settings',
      );
      expect(
        jsonDecode(store.writes.single).keys,
        unorderedEquals(['schemaVersion', 'lastRouteId', 'shortcuts']),
      );
      expect(jsonDecode(store.writes.single)['lastRouteId'], 'settings');
    },
  );

  testWidgets(
    'unavailable preferences permit session navigation without writes',
    (tester) async {
      desktop(tester);
      final store = MemoryPreferencesStore(
        readFailure: PreferenceErrorCodes.unavailable,
      );
      await tester.pumpWidget(DakhlRestaurantApp(preferencesStore: store));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(DakhlButton, 'الإعدادات').first);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<Phase01RouteSurface>(find.byType(Phase01RouteSurface))
            .routeId,
        'settings',
      );
      expect(store.writes, isEmpty);
      expect(
        tester.widget<DakhlShellView>(find.byType(DakhlShellView)).statusKind,
        DakhlStatusKind.error,
      );
    },
  );

  testWidgets('unknown router destination falls back to Sales consistently', (
    tester,
  ) async {
    desktop(tester);
    final store = MemoryPreferencesStore(
      snapshot: PreferenceSnapshot(
        payload: jsonEncode({
          'schemaVersion': 1,
          'lastRouteId': 'settings',
          'shortcuts': [
            'sales',
            'inventory',
            'sale-history',
            'expenses',
            'cash',
            'settings',
          ],
        }),
        revision: 2,
      ),
    );
    await tester.pumpWidget(DakhlRestaurantApp(preferencesStore: store));
    await tester.pumpAndSettle();
    GoRouter.of(tester.element(find.byType(Phase01RouteSurface)))
        .go('/retired-or-unknown');
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<Phase01RouteSurface>(find.byType(Phase01RouteSurface))
          .routeId,
      'sales',
    );
    expect(
      tester.widget<DakhlShellView>(find.byType(DakhlShellView)).routeId,
      'sales',
    );
  });

  testWidgets('mobile back from a shell destination returns to Sales', (
    tester,
  ) async {
    desktop(tester);
    final store = MemoryPreferencesStore();
    await tester.pumpWidget(DakhlRestaurantApp(preferencesStore: store));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(DakhlButton, 'الإعدادات').first);
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<Phase01RouteSurface>(find.byType(Phase01RouteSurface))
          .routeId,
      'sales',
    );
  });

  testWidgets('canceling shortcut discard retains the edited choices', (
    tester,
  ) async {
    desktop(tester);
    final store = MemoryPreferencesStore();
    await tester.pumpWidget(DakhlRestaurantApp(preferencesStore: store));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('تخصيص الاختصارات'));
    await tester.pumpAndSettle();
    expect(find.byType(DakhlShortcutEditor), findsOneWidget);
    await tester.tap(
      find
          .descendant(
            of: find.byType(DakhlShortcutEditor),
            matching: find.byType(DropdownButtonFormField<String>),
          )
          .first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('القاصة').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(DakhlButton, 'إلغاء').last);
    await tester.pumpAndSettle();
    expect(find.text('هل تريد تجاهل التغييرات؟'), findsOneWidget);
    await tester.tap(find.widgetWithText(DakhlButton, 'متابعة التعديل'));
    await tester.pumpAndSettle();
    expect(find.byType(DakhlShortcutEditor), findsOneWidget);
    expect(
      tester
          .widget<DakhlShortcutEditor>(find.byType(DakhlShortcutEditor))
          .choices
          .first,
      'cash',
    );
    expect(store.writes, isEmpty);
  });

  testWidgets('failed shortcut save retries inside the open dialog', (
    tester,
  ) async {
    desktop(tester);
    final store = MemoryPreferencesStore(writeFailure: 'unavailable');
    await tester.pumpWidget(DakhlRestaurantApp(preferencesStore: store));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('تخصيص الاختصارات'));
    await tester.pumpAndSettle();
    await tester.tap(
      find
          .descendant(
            of: find.byType(DakhlShortcutEditor),
            matching: find.byType(DropdownButtonFormField<String>),
          )
          .first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('القاصة').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(DakhlButton, 'حفظ الاختصارات'));
    await tester.pumpAndSettle();
    expect(find.byType(DakhlShortcutEditor), findsOneWidget);
    expect(store.writes, isEmpty);
    store.writeFailure = null;
    final retry = find.descendant(
      of: find.byType(DakhlShortcutEditor),
      matching: find.widgetWithText(DakhlButton, 'إعادة المحاولة'),
    );
    expect(retry, findsOneWidget);
    await tester.tap(retry);
    await tester.pumpAndSettle();
    expect(find.byType(DakhlShortcutEditor), findsNothing);
    expect(jsonDecode(store.writes.single)['shortcuts'][0], 'cash');
  });

  for (final size in [const Size(320, 568), const Size(1440, 1000)]) {
    testWidgets(
      'shell keeps essential layout reachable at $size and 200% text',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await tester.pumpWidget(
          DakhlRestaurantApp(preferencesStore: MemoryPreferencesStore()),
        );
        await tester.pumpAndSettle();
        expect(find.byType(DakhlShellView), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
