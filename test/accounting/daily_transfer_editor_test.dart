import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar_application/madar_application.dart';
import 'package:dakhl_restaurant/accounting/daily_transfer_editor_controller.dart';
import 'package:dakhl_restaurant/accounting/daily_transfer_editor.dart';
import 'package:dakhl_restaurant/app/restaurant_operations_session.dart';
import 'package:dakhl_restaurant/ui/theme.dart';

import '../accounts/accounts_view_model_test.dart' show FixtureStore;
import '../sales/sales_workflow_session_test.dart' show fixture, fresh;

Future<(FixtureStore, RestaurantOperationsSession)> setup() async {
  final (store, snapshot) = await fixture();
  final result = await RestaurantOperationsSession.open(
    store: store,
    snapshot: snapshot,
    compareText: (a, b) => a.compareTo(b),
    fresh: fresh('active'),
  );
  final session =
      (result as CapabilitySuccess<RestaurantOperationsSession>).value;
  expect(
    await session.dailyRegister.recordRemaining(
      date: '2026-11-07',
      amount: BigInt.from(10000),
    ),
    isA<DurableCommandSuccess>(),
  );
  await session.synchronize();
  return (store, session);
}

Map<String, Object?> transfer(RestaurantOperationsSession session) =>
    (session.spending.account.toJson()['transfers'] as List).single
        as Map<String, Object?>;

void main() {
  test('create edit delete adjusts daily cash once and retains correction journals', () async {
    final (_, session) = await setup();
    addTearDown(session.dispose);
    final create = DailyTransferEditorController(
      spending: session.spending,
      date: '2026-11-07',
    )..amount = '4000';
    expect(await create.save(), isA<CapabilitySuccess<void>>());
    await session.synchronize();
    expect(
      session.spending.daySnapshot('2026-11-07').remaining,
      BigInt.from(6000),
    );
    final original = transfer(session);
    final edit =
        DailyTransferEditorController(
            spending: session.spending,
            date: '2026-11-07',
            transfer: original,
          )
          ..amount = '3000'
          ..reason = 'Correct amount';
    expect(edit.editable, true);
    expect(await edit.save(), isA<CapabilitySuccess<void>>());
    await session.synchronize();
    expect(transfer(session)['amount'], 3000);
    expect(transfer(session)['createdAt'], original['createdAt']);
    expect(
      session.spending.daySnapshot('2026-11-07').remaining,
      BigInt.from(7000),
    );
    final delete = DailyTransferEditorController(
      spending: session.spending,
      date: '2026-11-07',
      transfer: transfer(session),
    )..reason = 'Cancelled';
    expect(await delete.save(delete: true), isA<CapabilitySuccess<void>>());
    await session.synchronize();
    expect(session.spending.account.toJson()['transfers'], isEmpty);
    expect(
      session.spending.daySnapshot('2026-11-07').remaining,
      BigInt.from(10000),
    );
    expect(session.spending.expensesForDate('2026-11-07'), isEmpty);
  });
  test('uncertain create retries captured amount while missing source posting refuses', () async {
    final (store, session) = await setup();
    addTearDown(session.dispose);
    final editor = DailyTransferEditorController(
      spending: session.spending,
      date: '2026-11-07',
    )..amount = '2000';
    store.writeFailure = 'commit_unknown';
    expect(await editor.save(), isA<CapabilityFailure<void>>());
    expect(editor.pending, true);
    editor.amount = '9000';
    store.writeFailure = null;
    expect(await editor.save(), isA<CapabilitySuccess<void>>());
    await session.synchronize();
    expect(transfer(session)['amount'], 2000);
    final before = store.writes;
    final missing = DailyTransferEditorController(
      spending: session.spending,
      date: '2026-11-07',
      transfer: {'id': 'missing', 'date': '2026-11-07', 'amount': 100},
    );
    expect(missing.editable, false);
    expect(
      (await missing.save() as CapabilityFailure<void>).code,
      'missing_original_posting',
    );
    expect(store.writes, before);
  });
  testWidgets('390px transfer form saves bounded positive amount', (
    tester,
  ) async {
    final (_, session) = await setup();
    addTearDown(session.dispose);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final editor = DailyTransferEditorController(
      spending: session.spending,
      date: '2026-11-07',
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: DakhlTheme.light,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () =>
                  showDailyTransferEditor(context, controller: editor),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '1500');
    await tester.tap(find.text('تأكيد الإيداع'));
    await tester.pumpAndSettle();
    expect(transfer(session)['amount'], 1500);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}
