import 'dart:convert';

import 'package:dakhl_restaurant/app/app.dart';
import 'package:dakhl_restaurant/ui/dakhl_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar_application/madar_application.dart';

import '../support/preferences_store.dart';

void main() {
  void desktop(WidgetTester tester) {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  MemoryPreferencesStore inventory() => MemoryPreferencesStore(
    snapshot: PreferenceSnapshot(
      revision: 1,
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
    ),
  );
  String route(WidgetTester tester) => tester
      .widget<Phase01RouteSurface>(find.byType(Phase01RouteSurface))
      .routeId;
  Future<void> chord(WidgetTester tester, LogicalKeyboardKey key) async {
    final modifier = defaultTargetPlatform == TargetPlatform.macOS
        ? LogicalKeyboardKey.metaLeft
        : LogicalKeyboardKey.controlLeft;
    await tester.sendKeyDownEvent(modifier);
    await tester.sendKeyEvent(key);
    await tester.sendKeyUpEvent(modifier);
    await tester.pumpAndSettle();
  }

  const platforms = TargetPlatformVariant({
    TargetPlatform.macOS,
    TargetPlatform.windows,
  });

  testWidgets(
    'fresh restored Inventory accepts global search without a preceding click',
    (tester) async {
      desktop(tester);
      final store = inventory();
      await tester.pumpWidget(DakhlRestaurantApp(preferencesStore: store));
      await tester.pumpAndSettle();
      expect(route(tester), 'inventory');
      expect(store.writes, isEmpty);
      await chord(tester, LogicalKeyboardKey.keyK);
      expect(route(tester), 'sales');
      expect(tester.testTextInput.hasAnyClients, isTrue);
      // Send text to the current input client, without finder-driven focus.
      tester.testTextInput.enterText('كباب');
      await tester.pump();
      final search = find.descendant(
        of: find.byWidgetPredicate(
          (w) => w is DakhlField && w.label == 'ابحث باسم الصنف أو رمزه...',
        ),
        matching: find.byType(EditableText),
      );
      expect(tester.widget<EditableText>(search).controller.text, 'كباب');
      expect(tester.takeException(), isNull);
    },
    variant: platforms,
  );

  testWidgets(
    'fresh global numbered shortcuts navigate while editable text owns slot and Undo keys',
    (tester) async {
      desktop(tester);
      await tester.pumpWidget(
        DakhlRestaurantApp(preferencesStore: inventory()),
      );
      await tester.pumpAndSettle();
      // No pointer or prior focused control: this is the first interaction.
      await chord(tester, LogicalKeyboardKey.digit3);
      expect(route(tester), 'sale-history');
      await chord(tester, LogicalKeyboardKey.digit1);
      expect(route(tester), 'sales');
      final discount = find.descendant(
        of: find.byWidgetPredicate(
          (w) => w is DakhlField && w.label == 'خصم · د.ع',
        ),
        matching: find.byType(TextFormField),
      );
      await tester.enterText(discount, '2,000');
      await tester.pump();
      // A session undo entry now exists. Search has its own native text history.
      final search = find.descendant(
        of: find.byWidgetPredicate(
          (w) => w is DakhlField && w.label == 'ابحث باسم الصنف أو رمزه...',
        ),
        matching: find.byType(TextFormField),
      );
      await tester.tap(search);
      await tester.pump(const Duration(milliseconds: 600));
      await tester.enterText(search, 'كباب');
      await tester.pump(const Duration(milliseconds: 600));
      await chord(tester, LogicalKeyboardKey.digit3);
      expect(route(tester), 'sales');
      expect(find.text('كباب'), findsOneWidget);
      await chord(tester, LogicalKeyboardKey.keyZ);
      expect(
        tester.widget<TextFormField>(search).controller?.text ??
            tester
                .widget<EditableText>(
                  find.descendant(
                    of: search,
                    matching: find.byType(EditableText),
                  ),
                )
                .controller
                .text,
        isEmpty,
      );
      expect(
        tester
            .widget<Phase01RouteSurface>(find.byType(Phase01RouteSurface))
            .ticketPresentation['discount'],
        '2,000',
      );
      expect(route(tester), 'sales');
      expect(tester.takeException(), isNull);
    },
    variant: platforms,
  );
}
