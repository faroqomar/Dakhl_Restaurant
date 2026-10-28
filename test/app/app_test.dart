import 'package:dakhl_restaurant/app/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('boots in Arabic RTL with development identity only', (
    tester,
  ) async {
    await tester.pumpWidget(const DakhlRestaurantApp());

    final identity = find.text('Dakhl_Restaurant Dev');
    expect(identity, findsOneWidget);
    expect(find.text('بيئة تطوير'), findsOneWidget);
    expect(
      Localizations.localeOf(tester.element(identity)),
      const Locale('ar'),
    );
    expect(Directionality.of(tester.element(identity)), TextDirection.rtl);
    expect(find.byType(EditableText), findsNothing);
    expect(find.byType(FloatingActionButton), findsNothing);
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.byType(Drawer), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final size in [const Size(320, 568), const Size(1440, 900)]) {
    testWidgets('development identity fits $size with large text', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await tester.pumpWidget(const DakhlRestaurantApp());

      expect(find.text('Dakhl_Restaurant Dev'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
