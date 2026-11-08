import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar_application/madar_application.dart';
import 'package:dakhl_restaurant/app/app.dart';
import 'package:dakhl_restaurant/app/restaurant_operations_session.dart';
import 'package:dakhl_restaurant/accounts/portable_journal_codec.dart';
import 'package:dakhl_restaurant/shell/shell_view_model.dart';

import '../sales/sales_workflow_session_test.dart' show fixture, fresh;
import '../support/preferences_store.dart';

void main() {
  testWidgets(
    'daily screen records and clears signed balance without cash posting',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final (store, snapshot) = await fixture();
      final opened = await RestaurantOperationsSession.open(
        store: store,
        snapshot: snapshot,
        compareText: (a, b) => a.compareTo(b),
        fresh: fresh('daily'),
      );
      final session =
          (opened as CapabilitySuccess<RestaurantOperationsSession>).value;
      addTearDown(session.dispose);
      ShellViewModel? shell;
      await tester.pumpWidget(
        DakhlRestaurantApp(
          preferencesStore: MemoryPreferencesStore(),
          operations: session,
          onShellReady: (value) => shell = value,
        ),
      );
      await tester.pumpAndSettle();
      await shell!.navigate('expenses');
      await tester.pumpAndSettle();
      final before = const PortableJournalCodec().decodeState(
        store.document!.payload,
      );
      await tester.tap(find.text('تعديل الرصيد الكلي'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).at(0), '-1200');
      await tester.enterText(
        find.byType(TextField).at(1),
        'Register correction',
      );
      await tester.tap(find.text('حفظ التغيير'));
      await tester.pumpAndSettle();
      final date = DateTime.now().toIso8601String().substring(0, 10);
      expect(
        session.dailyRegister.daySnapshot(date).recordedBalance,
        BigInt.from(-1200),
      );
      await tester.tap(find.text('تعديل الرصيد الكلي'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).at(1), 'Clear register');
      await tester.tap(find.text('إزالة الرصيد المسجّل'));
      await tester.pumpAndSettle();
      expect(session.dailyRegister.daySnapshot(date).recordedBalance, isNull);
      final after = const PortableJournalCodec().decodeState(
        store.document!.payload,
      );
      expect(
        after.journals.map((j) => j.toJson()).toList(),
        before.journals.map((j) => j.toJson()).toList(),
      );
      expect(after.receipts.length, before.receipts.length + 2);
      expect(session.dailyRegister.corrections(date), hasLength(2));
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('day correction preview moves only the selected register day', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final (store, snapshot) = await fixture();
    final opened = await RestaurantOperationsSession.open(
      store: store,
      snapshot: snapshot,
      compareText: (a, b) => a.compareTo(b),
      fresh: fresh('date'),
    );
    final session =
        (opened as CapabilitySuccess<RestaurantOperationsSession>).value;
    addTearDown(session.dispose);
    await session.dailyRegister.recordRemaining(
      date: '2098-12-30',
      amount: BigInt.from(700),
    );
    await session.synchronize();
    final before = const PortableJournalCodec().decodeState(
      store.document!.payload,
    );
    ShellViewModel? shell;
    await tester.pumpWidget(
      DakhlRestaurantApp(
        preferencesStore: MemoryPreferencesStore(),
        operations: session,
        onShellReady: (value) => shell = value,
      ),
    );
    await tester.pumpAndSettle();
    await shell!.navigate('expenses');
    await tester.pumpAndSettle();
    await tester.tap(find.text('تصحيح التاريخ'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), '2098-12-30');
    await tester.enterText(find.byType(TextField).at(1), '2098-12-31');
    await tester.enterText(
      find.byType(TextField).at(2),
      'Correct register date',
    );
    await tester.pump();
    expect(find.textContaining('2098-12-30 ← 2098-12-31'), findsOneWidget);
    await tester.tap(find.text('تأكيد تصحيح التاريخ'));
    await tester.pumpAndSettle();
    final after = const PortableJournalCodec().decodeState(
      store.document!.payload,
    );
    expect(after.account.days.containsKey('2098-12-30'), isFalse);
    expect(
      session.dailyRegister.daySnapshot('2098-12-31').remaining,
      BigInt.from(700),
    );
    expect(
      after.journals.map((j) => j.toJson()).toList(),
      before.journals.map((j) => j.toJson()).toList(),
    );
    expect(after.receipts.length, before.receipts.length + 1);
    expect(tester.takeException(), isNull);
  });
}
