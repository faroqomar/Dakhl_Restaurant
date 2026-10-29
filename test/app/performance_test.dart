import 'dart:convert';
import 'dart:io';

import 'package:dakhl_restaurant/app/app.dart';
import 'package:dakhl_restaurant/platform/performance_scenarios.dart';
import 'package:dakhl_restaurant/shell/shell_view_model.dart';
import 'package:dakhl_restaurant/ui/dakhl_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/preferences_store.dart';

void main() {
  test('benchmark rejects unknown operations and unsafe run identities', () {
    expect(
      () => PerformanceOptions.parse(['--case', 'orders.process']),
      throwsFormatException,
    );
    expect(
      () => PerformanceOptions.parse(['--run-id', '../accounts']),
      throwsFormatException,
    );
    expect(
      () => PerformanceOptions.parse(['--iterations', '0']),
      throwsFormatException,
    );
  });

  test(
    'fixture owns a fresh temp directory and never removes its parent',
    () async {
      final parent = await Directory.systemTemp.createTemp('dakhl-bench-test-');
      addTearDown(() => parent.delete(recursive: true));
      final sentinel = await File('${parent.path}/keep').writeAsString('keep');
      final fixture = await PerformanceFixture.create(
        'test-run',
        parent: parent,
      );
      expect(fixture.directory.parent.path, parent.path);
      expect(fixture.databasePath, startsWith(fixture.directory.path));
      await fixture.close();
      expect(await fixture.directory.exists(), isFalse);
      expect(await sentinel.readAsString(), 'keep');
    },
  );

  test(
    'real scenario requires persisted six slots and waits for rendering',
    () async {
      final store = MemoryPreferencesStore();
      final model = ShellViewModel(store: store);
      addTearDown(model.dispose);
      await model.initialize();
      var frames = 0;
      await runPerformanceIteration(
        model,
        'shortcuts.save',
        0,
        afterFrame: () async {
          frames++;
        },
      );
      expect(
        jsonDecode(store.writes.single)['shortcuts'],
        performanceShortcuts(0),
      );
      expect(model.shortcutDraft, isNull);
      expect(frames, 1);
      await runPerformanceIteration(
        model,
        'shortcuts.save',
        1,
        afterFrame: () async {
          frames++;
        },
      );
      expect(store.writes, hasLength(2));
      expect(
        jsonDecode(store.writes.last)['shortcuts'],
        performanceShortcuts(1),
      );
      store.writeFailure = 'unavailable';
      await expectLater(
        runPerformanceIteration(
          model,
          'shortcuts.save',
          2,
          afterFrame: () async {},
        ),
        throwsStateError,
      );
    },
  );

  testWidgets(
    'optional observation sees usable actual shell and route frames',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final store = MemoryPreferencesStore();
      ShellViewModel? observed;
      var calls = 0;
      await tester.pumpWidget(
        DakhlRestaurantApp(
          preferencesStore: store,
          onShellReady: (model) {
            observed = model;
            calls++;
          },
        ),
      );
      await tester.pumpAndSettle();
      expect(calls, 1);
      expect(observed!.bootstrapState, ShellBootstrapState.ready);
      expect(find.byType(DakhlShellView), findsOneWidget);
      expect(store.writes, isEmpty);
      final operation = runPerformanceIteration(
        observed!,
        'navigation.switch_route',
        0,
        afterFrame: () async {},
      );
      await tester.pumpAndSettle();
      await operation;
      expect(
        tester
            .widget<Phase01RouteSurface>(find.byType(Phase01RouteSurface))
            .routeId,
        'inventory',
      );
      expect(jsonDecode(store.writes.single)['lastRouteId'], 'inventory');
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    },
  );
}
