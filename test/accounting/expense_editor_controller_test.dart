import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar_application/madar_application.dart';
import 'package:madar_domain/madar_domain.dart';
import 'package:dakhl_restaurant/app/restaurant_operations_session.dart';
import 'package:dakhl_restaurant/accounting/expense_editor_controller.dart';
import 'package:dakhl_restaurant/accounting/expense_editor.dart';
import 'package:dakhl_restaurant/ui/theme.dart';

import '../sales/sales_workflow_session_test.dart' show fixture, fresh;

Future<RestaurantOperationsSession> session() async {
  final (store, snapshot) = await fixture();
  return ((await RestaurantOperationsSession.open(
    store: store,
    snapshot: snapshot,
    compareText: (a, b) => a.compareTo(b),
    fresh: fresh('active'),
  )) as CapabilitySuccess<RestaurantOperationsSession>).value;
}

void main() {
  test(
    'expense editor create edit delete uses immutable journals and exact split',
    () async {
      final app = await session();
      addTearDown(app.dispose);
      final create =
          ExpenseEditorController(spending: app.spending, date: '2026-11-07')
            ..amount = '1000'
            ..source = FundingSource.shared
            ..daily = '600'
            ..cash = '400'
            ..note = 'Entry';
      expect(await create.save(), isA<CapabilitySuccess<void>>());
      await app.synchronize();
      final saved = app.spending.expensesForDate('2026-11-07').single;
      expect(saved['funding'], {
        'source': 'shared',
        'dailyAmount': 600,
        'cashAmount': 400,
      });
      final edit =
          ExpenseEditorController(
              spending: app.spending,
              date: '2026-11-07',
              expense: saved,
            )
            ..amount = '900'
            ..source = FundingSource.daily
            ..reason = 'Input correction';
      expect(edit.editable, true);
      expect(await edit.save(), isA<CapabilitySuccess<void>>());
      await app.synchronize();
      final corrected = app.spending.expensesForDate('2026-11-07').single;
      expect(corrected['amount'], 900);
      expect(corrected['createdAt'], saved['createdAt']);
      final deletion = ExpenseEditorController(
        spending: app.spending,
        date: '2026-11-07',
        expense: corrected,
      )..reason = 'Cancelled entry';
      expect(await deletion.save(delete: true), isA<CapabilitySuccess<void>>());
      expect(app.spending.expensesForDate('2026-11-07'), isEmpty);
      expect(app.spending.snapshot.revision, greaterThan(3));
    },
  );
  test('zero expense uses explicit source-compatible policy', () async {
    final app = await session();
    addTearDown(app.dispose);
    final create = ExpenseEditorController(
      spending: app.spending,
      date: '2026-11-07',
    )..amount = '0';
    expect(await create.save(), isA<CapabilitySuccess<void>>());
    expect(app.spending.expensesForDate('2026-11-07').single['amount'], 0);
  });
  testWidgets('expense form submits saved daily amount', (tester) async {
    final app = await session();
    addTearDown(app.dispose);
    final model = ExpenseEditorController(
      spending: app.spending,
      date: '2026-11-07',
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: DakhlTheme.light,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showExpenseEditor(context, controller: model),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'المبلغ · د.ع'),
      '1500',
    );
    await tester.ensureVisible(find.text('حفظ المصروف'));
    await tester.tap(find.text('حفظ المصروف'));
    await tester.pumpAndSettle();
    expect(app.spending.expensesForDate('2026-11-07').single['amount'], 1500);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}
