import 'package:dakhl_restaurant/accounts/portable_journal_codec.dart';
import 'package:dakhl_restaurant/platform/visible_performance_scenarios.dart';
import 'package:dakhl_restaurant/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar_application/madar_application.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'visible options refuse unknown, duplicate, unsafe and invalid counts',
    () {
      for (final args in [
        ['--case', 'fake'],
        ['--case', 'sales.add_item', '--iterations', '0'],
        ['--case', 'sales.add_item', '--run-id', '../foreign'],
        ['--case', 'sales.add_item', '--case', 'orders.process'],
      ]) {
        expect(
          () => VisiblePerformanceOptions.parse(args),
          throwsFormatException,
        );
      }
    },
  );
  for (final operation in visiblePerformanceCases) {
    testWidgets('$operation updates its actual surface and survives reopen', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(800, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final fixture = (await tester.runAsync(
        () => VisiblePerformanceFixture.create('widget', operation),
      ))!;
      try {
        await tester.pumpWidget(
          MaterialApp(
            theme: DakhlTheme.light,
            locale: const Locale('ar'),
            supportedLocales: const [Locale('ar')],
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            home: Scaffold(body: fixture.surface()),
          ),
        );
        await tester.pumpAndSettle();
        await tester.runAsync(fixture.run);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        fixture.verifyRendered();
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.runAsync(fixture.verifyDurable);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.runAsync(fixture.close);
      }
      expect(await tester.runAsync(fixture.seed.directory.exists), false);
    });
  }
  test(
    'checkout verification refuses a source without its durable receipt',
    () async {
      final fixture = await VisiblePerformanceFixture.create(
        'negative',
        'orders.process',
      );
      try {
        await fixture.run();
        final current =
            (await fixture.seed.store.readDocument()
                    as CapabilitySuccess<DocumentSnapshot?>)
                .value!;
        const codec = PortableJournalCodec();
        final state = codec.decodeState(current.payload);
        final changed = await fixture.seed.store.writeDocument(
          codec.encodeState(state.copyWith(receipts: [])),
          expected: current,
          writeToken: 'remove-visible-receipt',
        );
        expect(changed, isA<CapabilitySuccess<DocumentSnapshot>>());
        await expectLater(fixture.verifyDurable(), throwsStateError);
      } finally {
        await fixture.close();
      }
    },
  );
  test('checkout verification refuses a stale persisted cart despite a cleared model', () async {
    final fixture = await VisiblePerformanceFixture.create(
      'stale-cart',
      'orders.process',
    );
    try {
      final before = (await fixture.seed.store.readWorkspace(
        fixture.session.snapshot.fence,
      ) as CapabilitySuccess<WorkspaceState>).value.snapshot!;
      await fixture.run();
      final current = (await fixture.seed.store.readWorkspace(
        fixture.session.snapshot.fence,
      ) as CapabilitySuccess<WorkspaceState>).value.snapshot!;
      expect(
        await fixture.seed.store.writeWorkspace(
          before.payload,
          fence: current.fence,
          expectedRevision: current.revision,
          writeToken: 'restore-stale-visible-cart',
        ),
        isA<CapabilitySuccess<WorkspaceSnapshot>>(),
      );
      expect(fixture.session.sales.active!.lines, isEmpty);
      await expectLater(fixture.verifyDurable(), throwsStateError);
    } finally {
      await fixture.close();
    }
  });
}
