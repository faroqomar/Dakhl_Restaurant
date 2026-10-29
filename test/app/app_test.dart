import 'dart:convert';

import 'package:dakhl_restaurant/app/app.dart';
import 'package:dakhl_restaurant/ui/dakhl_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

  testWidgets(
    'healthy reread warns when a newer session route remains unsaved',
    (tester) async {
      desktop(tester);
      final store = MemoryPreferencesStore(
        readFailure: PreferenceErrorCodes.unavailable,
        snapshot: PreferenceSnapshot(
          payload: jsonEncode({
            'schemaVersion': 1,
            'lastRouteId': 'inventory',
            'shortcuts': [
              'sales',
              'inventory',
              'sale-history',
              'expenses',
              'cash',
              'settings',
            ],
          }),
          revision: 4,
        ),
      );
      await tester.pumpWidget(DakhlRestaurantApp(preferencesStore: store));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(DakhlButton, 'الإعدادات').first);
      await tester.pumpAndSettle();
      expect(store.writes, isEmpty);
      store.readFailure = null;
      await tester.tap(
        find.widgetWithText(DakhlButton, 'إعادة المحاولة').first,
      );
      await tester.pumpAndSettle();
      final shell = tester.widget<DakhlShellView>(find.byType(DakhlShellView));
      expect(shell.routeId, 'settings');
      expect(
        store.writes,
        isEmpty,
        reason: 'Read completion must never save session intent.',
      );
      expect(jsonDecode(store.snapshot!.payload)['lastRouteId'], 'inventory');
      expect(
        shell.statusMessage,
        'تغييرات العرض لهذه الجلسة فقط؛ لم تُحفظ على جهازك.',
      );
      expect(shell.statusKind, DakhlStatusKind.info);
      expect(find.text('محفوظ على جهازك'), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await tester.pumpWidget(DakhlRestaurantApp(preferencesStore: store));
      await tester.pumpAndSettle();
      final restored = tester.widget<DakhlShellView>(
        find.byType(DakhlShellView),
      );
      expect(restored.routeId, 'inventory');
      expect(restored.statusMessage, 'محفوظ على جهازك');
      expect(restored.statusKind, DakhlStatusKind.saved);
      expect(store.writes, isEmpty);
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
  }, variant: const TargetPlatformVariant({TargetPlatform.android}));

  void iosPhone(WidgetTester tester) {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  MemoryPreferencesStore restoredRoute(String id) => MemoryPreferencesStore(
    snapshot: PreferenceSnapshot(
      payload: jsonEncode({
        'schemaVersion': 1,
        'lastRouteId': id,
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

  String currentRoute(WidgetTester tester) => tester
      .widget<Phase01RouteSurface>(find.byType(Phase01RouteSurface))
      .routeId;

  Future<void> rtlBackSwipe(WidgetTester tester) async {
    final rect = tester.getRect(find.byType(Phase01RouteSurface));
    await tester.timedDragFrom(
      Offset(rect.right - 2, rect.center.dy),
      Offset(-rect.width * .65, 0),
      const Duration(milliseconds: 350),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'resumed Android registers framework Back through shell navigation and modal closure',
    (tester) async {
      desktop(tester);
      final originalLifecycle = tester.binding.lifecycleState;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      addTearDown(
        () => tester.binding.handleAppLifecycleStateChanged(
          originalLifecycle ?? AppLifecycleState.detached,
        ),
      );
      final handlesBack = <bool>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'SystemNavigator.setFrameworkHandlesBack') {
            handlesBack.add(call.arguments as bool);
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      final store = MemoryPreferencesStore();
      await tester.pumpWidget(DakhlRestaurantApp(preferencesStore: store));
      await tester.pumpAndSettle();
      expect(handlesBack, isNotEmpty);
      expect(
        handlesBack.last,
        isFalse,
        reason: 'Clean Sales may exit: $handlesBack',
      );
      await tester.tap(find.byTooltip('القائمة الرئيسية'));
      await tester.pumpAndSettle();
      expect(
        handlesBack.last,
        isTrue,
        reason: 'Open menu handles Back: $handlesBack',
      );
      await tester.tap(find.text('المخزن').last);
      await tester.pumpAndSettle();
      expect(currentRoute(tester), 'inventory');
      expect(
        handlesBack.last,
        isTrue,
        reason: 'Inventory must keep framework Back registered: $handlesBack',
      );
      await tester.tap(find.byTooltip('تخصيص الاختصارات'));
      await tester.pumpAndSettle();
      expect(handlesBack.last, isTrue);
      await tester.tap(find.widgetWithText(DakhlButton, 'إلغاء').last);
      await tester.pumpAndSettle();
      expect(currentRoute(tester), 'inventory');
      expect(
        handlesBack.last,
        isTrue,
        reason:
            'Closing the modal must retain Inventory Back handling: $handlesBack',
      );
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(currentRoute(tester), 'sales');
      expect(
        handlesBack.last,
        isFalse,
        reason: 'Clean Sales can exit again: $handlesBack',
      );
      final model = ProviderScope.containerOf(
        tester.element(find.byType(Phase01RouteSurface)),
      ).read(shellViewModelProvider);
      model.setFormDraft({'quantity': '2'});
      await tester.pumpAndSettle();
      expect(
        handlesBack.last,
        isTrue,
        reason: 'Dirty Sales must guard exit: $handlesBack',
      );
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('هل تريد تجاهل التغييرات؟'), findsOneWidget);
      await tester.tap(find.widgetWithText(DakhlButton, 'متابعة التعديل'));
      await tester.pumpAndSettle();
      expect(model.dirtyForm, isTrue);
      expect(handlesBack.last, isTrue);
      model.discardForm();
      await tester.pumpAndSettle();
      expect(
        handlesBack.last,
        isFalse,
        reason:
            'Discarding session dirt restores clean Sales exit: $handlesBack',
      );
      expect(tester.takeException(), isNull);
    },
    variant: const TargetPlatformVariant({TargetPlatform.android}),
  );

  testWidgets('iOS completed RTL leading-edge swipe returns to Sales', (
    tester,
  ) async {
    iosPhone(tester);
    final store = restoredRoute('settings');
    await tester.pumpWidget(DakhlRestaurantApp(preferencesStore: store));
    await tester.pumpAndSettle();
    expect(currentRoute(tester), 'settings');
    await rtlBackSwipe(tester);
    expect(currentRoute(tester), 'sales');
    expect(jsonDecode(store.writes.single)['lastRouteId'], 'sales');
    expect(tester.takeException(), isNull);
  }, variant: const TargetPlatformVariant({TargetPlatform.iOS}));

  testWidgets('iOS edge swipe uses one dirty guard and Cancel retains input', (
    tester,
  ) async {
    iosPhone(tester);
    final store = restoredRoute('settings');
    await tester.pumpWidget(DakhlRestaurantApp(preferencesStore: store));
    await tester.pumpAndSettle();
    final model = ProviderScope.containerOf(
      tester.element(find.byType(Phase01RouteSurface)),
    ).read(shellViewModelProvider);
    model.setFormDraft({'quantity': '2'});
    await tester.pump();
    await rtlBackSwipe(tester);
    expect(find.text('هل تريد تجاهل التغييرات؟'), findsOneWidget);
    await rtlBackSwipe(tester);
    expect(find.text('هل تريد تجاهل التغييرات؟'), findsOneWidget);
    await tester.tap(find.widgetWithText(DakhlButton, 'متابعة التعديل'));
    await tester.pumpAndSettle();
    expect(currentRoute(tester), 'settings');
    expect(model.formDraft['quantity'], '2');
    expect(model.dirtyForm, isTrue);
    expect(store.writes, isEmpty);
    await rtlBackSwipe(tester);
    await tester.tap(find.widgetWithText(DakhlButton, 'تجاهل التغييرات'));
    await tester.pumpAndSettle();
    expect(currentRoute(tester), 'sales');
    expect(model.formDraft, isEmpty);
    expect(store.writes, hasLength(1));
  }, variant: const TargetPlatformVariant({TargetPlatform.iOS}));

  testWidgets(
    'iOS shell swipe cannot navigate through an open menu or dialog',
    (tester) async {
      iosPhone(tester);
      final store = restoredRoute('settings');
      await tester.pumpWidget(DakhlRestaurantApp(preferencesStore: store));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('القائمة الرئيسية'));
      await tester.pumpAndSettle();
      await rtlBackSwipe(tester);
      expect(currentRoute(tester), 'settings');
      expect(store.writes, isEmpty);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('تخصيص الاختصارات'));
      await tester.pumpAndSettle();
      await rtlBackSwipe(tester);
      expect(find.byType(DakhlShortcutEditor), findsOneWidget);
      expect(currentRoute(tester), 'settings');
      expect(store.writes, isEmpty);
    },
    variant: const TargetPlatformVariant({TargetPlatform.iOS}),
  );

  testWidgets(
    'iOS wrong-edge vertical short and canceled swipes do not navigate',
    (tester) async {
      iosPhone(tester);
      final store = restoredRoute('settings');
      await tester.pumpWidget(DakhlRestaurantApp(preferencesStore: store));
      await tester.pumpAndSettle();
      final rect = tester.getRect(find.byType(Phase01RouteSurface));
      await tester.dragFrom(
        Offset(rect.left + 2, rect.center.dy),
        const Offset(200, 0),
      );
      await tester.pumpAndSettle();
      await tester.dragFrom(
        Offset(rect.right - 2, rect.center.dy),
        const Offset(0, -200),
      );
      await tester.pumpAndSettle();
      await tester.dragFrom(
        Offset(rect.right - 2, rect.center.dy),
        const Offset(-30, 0),
      );
      await tester.pumpAndSettle();
      await tester.dragFrom(
        Offset(rect.right - 2, rect.center.dy),
        const Offset(-130, 200),
      );
      await tester.pumpAndSettle();
      final gesture = await tester.startGesture(
        Offset(rect.right - 2, rect.center.dy),
      );
      await gesture.moveBy(const Offset(-200, 0));
      await tester.pump();
      await gesture.cancel();
      await tester.pumpAndSettle();
      expect(currentRoute(tester), 'settings');
      expect(store.writes, isEmpty);
      expect(tester.takeException(), isNull);
    },
    variant: const TargetPlatformVariant({TargetPlatform.iOS}),
  );

  testWidgets('iOS edge swipe on Sales never requests app exit', (
    tester,
  ) async {
    iosPhone(tester);
    final store = restoredRoute('sales');
    var exits = 0;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'SystemNavigator.pop') exits++;
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await tester.pumpWidget(DakhlRestaurantApp(preferencesStore: store));
    await tester.pumpAndSettle();
    await rtlBackSwipe(tester);
    expect(currentRoute(tester), 'sales');
    expect(exits, 0);
    expect(store.writes, isEmpty);
  }, variant: const TargetPlatformVariant({TargetPlatform.iOS}));

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
