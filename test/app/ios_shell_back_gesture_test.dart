import 'dart:async';

import 'package:dakhl_restaurant/app/ios_shell_back_gesture.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  void phone(WidgetTester tester) {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Widget surface({
    required Widget child,
    required Future<void> Function() onBack,
    bool Function()? canStart,
  }) => MaterialApp(
    home: Directionality(
      textDirection: TextDirection.rtl,
      child: IosShellBackGesture(
        canStart: canStart ?? () => true,
        onBack: onBack,
        child: child,
      ),
    ),
  );

  Future<void> swipe(WidgetTester tester) async {
    await tester.timedDragFrom(
      const Offset(388, 400),
      const Offset(-240, 0),
      const Duration(milliseconds: 350),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('ordinary child horizontal drags win even near the edge', (
    tester,
  ) async {
    phone(tester);
    var backs = 0;
    var horizontalDrags = 0;
    await tester.pumpWidget(
      surface(
        onBack: () async => backs++,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragEnd: (_) => horizontalDrags++,
          child: const SizedBox.expand(),
        ),
      ),
    );
    await swipe(tester);
    await tester.dragFrom(const Offset(200, 400), const Offset(-160, 0));
    await tester.pumpAndSettle();
    expect(horizontalDrags, 2);
    expect(backs, 0);
  }, variant: const TargetPlatformVariant({TargetPlatform.iOS}));

  testWidgets('vertical scroll intent near the edge stays with its child', (
    tester,
  ) async {
    phone(tester);
    var backs = 0;
    var verticalDrags = 0;
    await tester.pumpWidget(
      surface(
        onBack: () async => backs++,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onVerticalDragEnd: (_) => verticalDrags++,
          child: const SizedBox.expand(),
        ),
      ),
    );
    await tester.dragFrom(const Offset(388, 400), const Offset(-30, -220));
    await tester.pumpAndSettle();
    expect(verticalDrags, 1);
    expect(backs, 0);
  }, variant: const TargetPlatformVariant({TargetPlatform.iOS}));

  testWidgets('ordinary text interaction cannot dispatch shell back', (
    tester,
  ) async {
    phone(tester);
    var backs = 0;
    final text = TextEditingController(text: 'synthetic text');
    addTearDown(text.dispose);
    await tester.pumpWidget(
      surface(
        onBack: () async => backs++,
        child: Material(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: TextField(controller: text),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();
    await tester.dragFrom(
      tester.getCenter(find.byType(TextField)),
      const Offset(-100, 0),
    );
    await tester.pumpAndSettle();
    expect(text.text, 'synthetic text');
    expect(backs, 0);
  }, variant: const TargetPlatformVariant({TargetPlatform.iOS}));

  testWidgets('a reversed or canceled swipe never completes navigation', (
    tester,
  ) async {
    phone(tester);
    var backs = 0;
    await tester.pumpWidget(
      surface(onBack: () async => backs++, child: const SizedBox.expand()),
    );
    final reversed = await tester.startGesture(const Offset(388, 400));
    await reversed.moveBy(const Offset(-180, 0));
    await reversed.moveBy(const Offset(170, 0));
    await reversed.up();
    await tester.pumpAndSettle();
    final canceled = await tester.startGesture(const Offset(388, 400));
    await canceled.moveBy(const Offset(-180, 0));
    await canceled.cancel();
    await tester.pumpAndSettle();
    expect(backs, 0);
  }, variant: const TargetPlatformVariant({TargetPlatform.iOS}));

  testWidgets(
    'pending back action prevents another swipe or concurrent prompt',
    (tester) async {
      phone(tester);
      var backs = 0;
      final done = Completer<void>();
      await tester.pumpWidget(
        surface(
          onBack: () {
            backs++;
            return done.future;
          },
          child: const SizedBox.expand(),
        ),
      );
      await swipe(tester);
      await swipe(tester);
      expect(backs, 1);
      done.complete();
      await tester.pumpAndSettle();
    },
    variant: const TargetPlatformVariant({TargetPlatform.iOS}),
  );

  testWidgets('Android gets no iOS edge adapter', (tester) async {
    phone(tester);
    var backs = 0;
    await tester.pumpWidget(
      surface(onBack: () async => backs++, child: const SizedBox.expand()),
    );
    await swipe(tester);
    expect(backs, 0);
  }, variant: const TargetPlatformVariant({TargetPlatform.android}));
}
