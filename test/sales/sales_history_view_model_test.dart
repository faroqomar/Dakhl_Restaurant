import 'package:dakhl_restaurant/accounting/restaurant_journal_sale_commands.dart';
import 'package:dakhl_restaurant/sales/sales_history_view_model.dart';
import 'package:dakhl_restaurant/sales/sales_operations_view_model.dart';
import 'package:dakhl_restaurant/sales/ticket_workspace.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar_application/madar_application.dart';

import 'sales_workflow_session_test.dart' show fixture;

void main() {
  test('portable history void delegates original-date journal and refreshes saved receipt', () async {
    final (store, snapshot) = await fixture();
    final operations = SalesOperationsViewModel(
      commands: RestaurantJournalSaleCommandCoordinator(store: store),
      snapshot: snapshot,
    );
    addTearDown(operations.dispose);
    final command = operations.checkoutIntent(
      ticket: TicketDraft(
        id: 'sale',
        date: '2026-11-07',
        orderType: 'سفري',
        discount: '',
        note: '',
        lines: [
          TicketLine(
            productId: 'p',
            quantityUnits: BigInt.from(1000),
            price: 1000,
          ),
        ],
      ),
      operationId: 'sale-op',
      journalId: 'sale-journal',
      recordedAt: '2026-11-07T12:00:00Z',
    );
    expect(
      await operations.submit(command),
      isA<DurableCommandSuccess<RestaurantJournalSaleOutcome>>(),
    );
    final history = SalesHistoryViewModel(operations: operations);
    addTearDown(history.dispose);
    history.select('sale');
    expect(history.canVoid, true);
    expect(history.receipt().reference, 'S-000001');
    expect(history.returnAvailability.single.remainingUnits, BigInt.from(1000));
    expect(
      await history.voidSale('Wrong saved sale'),
      isA<CapabilitySuccess<void>>(),
    );
    expect(history.selected!['status'], 'void');
    expect(history.history!.voidCount, 1);
    expect(history.canVoid, false);
    expect(
      history.receipt().sections.expand((s) => s.rows).expand((r) => r),
      contains('Wrong saved sale'),
    );
    expect((operations.account.toJson()['sales'] as List).length, 1);
  });
}
