import 'package:dakhl_restaurant/accounts/portable_journal_codec.dart';
import 'package:dakhl_restaurant/app/app.dart';
import 'package:dakhl_restaurant/app/restaurant_operations_session.dart';
import 'package:dakhl_restaurant/settings/settings_surface.dart';
import 'package:dakhl_restaurant/shell/shell_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar_application/madar_application.dart';

import '../parties/additional_debt_controller_test.dart' show seed;
import '../sales/sales_workflow_session_test.dart' show fresh;
import '../support/preferences_store.dart';

void main() {
  testWidgets('opening revision is an explicit quick-undo boundary', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final (store, snapshot) = await seed();
    final opened = await RestaurantOperationsSession.open(
      store: store,
      snapshot: snapshot,
      compareText: (a, b) => a.compareTo(b),
      fresh: fresh('opening-composition'),
      acceptedOpeningEquityAccountId: 'equity:opening_balance',
    );
    final session =
        (opened as CapabilitySuccess<RestaurantOperationsSession>).value;
    addTearDown(session.dispose);
    ShellViewModel? shell;
    await tester.pumpWidget(
      DakhlRestaurantApp(
        operations: session,
        preferencesStore: MemoryPreferencesStore(),
        onShellReady: (value) => shell = value,
      ),
    );
    await tester.pumpAndSettle();

    Future<void> category(String name) async {
      await shell!.navigate('categories');
      await tester.pumpAndSettle();
      await tester.tap(find.text('إضافة خانة'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), name);
      await tester.tap(find.text('حفظ الخانة'));
      await tester.pumpAndSettle();
      expect(await session.synchronize(), isA<CapabilitySuccess<void>>());
      await tester.pumpAndSettle();
    }

    Future<SettingsSurface> settings() async {
      await shell!.navigate('settings');
      await tester.pumpAndSettle();
      return tester.widget<SettingsSurface>(find.byType(SettingsSurface));
    }

    await category('Before opening');
    expect((await settings()).onUndo, isNotNull);
    final command = session.supplierOpenings.capture(
      operationId: 'opening-composition-write',
      supplierId: 'supplier',
      openingBalance: BigInt.from(1000),
      reason: 'Verified fixture opening',
      recordedAt: '2026-11-08T10:00:00Z',
    );
    expect(
      await session.supplierOpenings.submit(command),
      isA<DurableCommandSuccess>(),
    );
    await tester.pumpAndSettle();
    expect(await session.synchronize(), isA<CapabilitySuccess<void>>());
    await tester.pumpAndSettle();
    expect((await settings()).onUndo, isNull);

    await category('After opening');
    final next = await settings();
    expect(next.onUndo, isNotNull);
    next.onUndo!();
    await tester.pumpAndSettle();
    await session.synchronize();
    await tester.pumpAndSettle();
    final state = const PortableJournalCodec().decodeState(
      store.document!.payload,
    );
    expect(
      state.account.categories.any((c) => c['name'] == 'Before opening'),
      true,
    );
    expect(
      state.account.categories.any((c) => c['name'] == 'After opening'),
      false,
    );
    expect(
      (state.account.toJson()['suppliers'] as List).single['openingBalance'],
      1000,
    );
    expect(
      (await settings()).onUndo,
      isNull,
      reason: 'Earlier metadata cannot cross the opening boundary.',
    );
  });
}
