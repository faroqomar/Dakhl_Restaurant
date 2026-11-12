import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:madar_application/madar_application.dart';
import 'package:madar_domain/madar_domain.dart';
import 'package:dakhl_restaurant/accounts/legacy_account_codec.dart';
import 'package:dakhl_restaurant/accounts/portable_journal_codec.dart';
import 'package:dakhl_restaurant/accounting/day_date_plan.dart';
import 'package:dakhl_restaurant/accounting/day_date_correction_commands.dart';
import 'package:dakhl_restaurant/accounting/day_date_correction_controller.dart';
import 'package:dakhl_restaurant/accounting/daily_cash_queries.dart';
import 'package:dakhl_restaurant/accounting/restaurant_journal_spending_commands.dart';
import 'package:dakhl_restaurant/accounting/restaurant_journal_transfer_commands.dart';
import 'package:dakhl_restaurant/parties/parties_operations_view_model.dart';
import 'package:dakhl_restaurant/parties/parties_surface_controller.dart';

import '../accounting/restaurant_journal_invoice_correction_commands_test.dart'
    show setup, lines, date;

const codec = PortableJournalCodec();
Map<String, Object?> day(int chickens) => {
  'expenses': <Object?>[],
  'chickenUsed': chickens,
  'chickenLeft': 0,
  'balance': 1000,
  'totalOverride': null,
  'remaining': {
    'amount': 1000,
    'dailySpent': 0,
    'transferred': 0,
    'salesTotal': 0,
  },
};
void main() {
  test(
    'source range oracle preserves independent sales and snapshot baseline',
    () async {
      final values = jsonDecode(
        File('test/fixtures/legacy/day_date_correction.json')
            .readAsStringSync(),
      ) as Map;
      final before = const LegacyAccountCodec().decodeJson(
        (values['before'] as Map).cast<String, Object?>(),
      );
      final after = DayDatePlan.create(
        before,
        from: '2026-11-07',
        to: '2026-11-08',
        end: '2026-11-08',
      ).apply(before);
      final expected = const LegacyAccountCodec().decodeJson(
        (values['after'] as Map).cast<String, Object?>(),
      );
      expect(after.toJson(), expected.toJson());
      expect(
        DailyCashQueries(after).day('2026-11-08').remaining,
        BigInt.from(50000),
      );
      expect((after.toJson()['sales'] as List).single['date'], '2026-11-07');
    },
  );
  test('one atomic expense payment transfer range receipt supports old replay and later correction', () async {
    final (store, parties) = await setup();
    addTearDown(parties.dispose);
    var state = codec.decodeState(store.document!.payload);
    final seeded = await store.writeDocument(
      codec.encodeState(
        state.copyWith(
          account: const LegacyAccountCodec().decodeJson({
            ...state.account.toJson(),
            'days': {'2026-11-07': day(2), '2026-11-08': day(1)},
          }),
        ),
      ),
      writeToken: 'days',
      expected: store.document,
    );
    parties.acceptSnapshot(
      (seeded as CapabilitySuccess<DocumentSnapshot>).value,
    );
    final invoice = parties.purchaseInvoiceIntent(
      operationId: 'invoice-op',
      invoiceId: 'invoice',
      invoiceJournalId: 'invoice-journal',
      supplierId: 's',
      invoiceNumber: '1',
      date: date('2026-11-07'),
      lines: lines(1000),
      recordedAt: '2026-11-07T10:00:00Z',
    );
    expect(await parties.submitInvoice(invoice), isA<DurableCommandSuccess>());
    final spending = RestaurantJournalSpendingCommandCoordinator(store: store);
    final expense = CreateOperatingExpenseCommand(
      operationId: 'expense-op',
      accountLineage: 'lineage',
      expectedFence: store.document!.fence,
      expenseId: 'expense',
      journalId: 'expense-journal',
      date: date('2026-11-07'),
      categoryId: 'samoon',
      amount: BigInt.from(100),
      fundingSource: FundingSource.shared,
      dailyAmount: BigInt.from(60),
      cashAmount: BigInt.from(40),
      recordedAt: '2026-11-07T10:00:00Z',
    );
    expect(
      await spending.executeExpense(expense),
      isA<DurableCommandSuccess>(),
    );
    final payment = parties.supplierPaymentIntent(
      operationId: 'payment-op',
      paymentId: 'payment',
      journalId: 'payment-journal',
      supplierId: 's',
      invoiceId: 'invoice',
      date: date('2026-11-07'),
      amount: BigInt.from(100),
      fundingSource: FundingSource.daily,
      recordedAt: '2026-11-07T10:00:00Z',
    );
    expect(await parties.submitPayment(payment), isA<DurableCommandSuccess>());
    final transfers = RestaurantJournalTransferCommandCoordinator(store: store);
    final transfer = DailyToCashboxTransferCommand(
      operationId: 'transfer-op',
      accountLineage: 'lineage',
      expectedFence: store.document!.fence,
      transferId: 'transfer',
      journalId: 'transfer-journal',
      date: date('2026-11-07'),
      amount: BigInt.from(50),
      recordedAt: '2026-11-07T10:00:00Z',
    );
    expect(await transfers.execute(transfer), isA<DurableCommandSuccess>());
    final before = codec.decodeState(store.document!.payload),
        writes = store.writes;
    final controller = DayDateCorrectionController(
      store: store,
      snapshot: store.document!,
      isWriteBlocked: () => false,
    );
    addTearDown(controller.dispose);
    final command = controller.capture(
      operationId: 'shift',
      from: '2026-11-07',
      to: '2026-11-08',
      end: '2026-11-08',
      reason: 'Correct date range',
      recordedAt: '2026-11-10T10:00:00Z',
    );
    final result = await controller.submit(command);
    expect(
      result,
      isA<DurableCommandSuccess>(),
      reason: result is DurableCommandFailure<DayDateCorrectionOutcome>
          ? result.code
          : '',
    );
    state = codec.decodeState(store.document!.payload);
    expect(store.writes, writes + 1);
    expect(state.receipts.length, before.receipts.length + 1);
    expect(state.journals.length, before.journals.length + 6);
    expect(
      state.journals.take(before.journals.length).map((j) => j.toJson()),
      before.journals.map((j) => j.toJson()),
    );
    expect(
      state.account.toJson(),
      DayDatePlan.create(
        before.account,
        from: '2026-11-07',
        to: '2026-11-08',
        end: '2026-11-08',
      ).apply(before.account).toJson(),
    );
    expect(
      await spending.executeExpense(expense),
      isA<DurableCommandReplayed>(),
    );
    expect(
      await spending.executePayment(payment),
      isA<DurableCommandReplayed>(),
    );
    expect(await transfers.execute(transfer), isA<DurableCommandReplayed>());
    final owner = PartiesOperationsViewModel(
      store: store,
      snapshot: store.document!,
      compareText: (a, b) => a.compareTo(b),
    );
    addTearDown(owner.dispose);
    final editor = PartiesSurfaceController(operations: owner);
    addTearDown(editor.dispose);
    expect(
      await editor.savePaymentEdit(
        original: owner.payments.single,
        supplierId: 's',
        invoiceId: 'invoice',
        categoryId: 'samoon',
        dateText: '2026-11-08',
        amountText: '100',
        source: 'daily',
        dailyText: '100',
        cashText: '0',
        note: 'Later correction',
        reason: 'Adjust note',
      ),
      isA<CapabilitySuccess<void>>(),
    );
    final repeat = await controller.coordinator.execute(
      DayDateCorrectionCommand.fromIntent(command.intent),
    );
    expect(
      repeat,
      isA<DurableCommandReplayed>(),
      reason: repeat is DurableCommandFailure<DayDateCorrectionOutcome>
          ? repeat.code
          : '',
    );
  });
  test('exact state digest rejects an intervening source write without compensation', () async {
    final (store, owner) = await setup();
    addTearDown(owner.dispose);
    var state = codec.decodeState(store.document!.payload);
    await store.writeDocument(
      codec.encodeState(
        state.copyWith(
          account: const LegacyAccountCodec().decodeJson({
            ...state.account.toJson(),
            'days': {'2026-11-07': day(2)},
          }),
        ),
      ),
      writeToken: 'day',
      expected: store.document,
    );
    final c = DayDateCorrectionController(
      store: store,
      snapshot: store.document!,
      isWriteBlocked: () => false,
    );
    addTearDown(c.dispose);
    final command = c.capture(
      operationId: 'changed-source',
      from: '2026-11-07',
      to: '2026-11-08',
      reason: 'Date',
      recordedAt: '2026-11-10T10:00:00Z',
    );
    state = codec.decodeState(store.document!.payload);
    await store.writeDocument(
      codec.encodeState(
        state.copyWith(
          account: const LegacyAccountCodec().decodeJson({
            ...state.account.toJson(),
            'days': {'2026-11-07': day(3)},
          }),
        ),
      ),
      writeToken: 'intervening',
      expected: store.document,
    );
    final unchanged = store.document!, writes = store.writes;
    final result = await c.submit(command);
    expect(result, isA<DurableCommandFailure<DayDateCorrectionOutcome>>());
    expect(
      (result as DurableCommandFailure<DayDateCorrectionOutcome>).code,
      'day_shift_source_changed',
    );
    expect(store.document, unchanged);
    expect(store.writes, writes);
  });
  test('missing posting collision and exact revision mismatch preserve complete state', () async {
    final (store, owner) = await setup();
    addTearDown(owner.dispose);
    var state = codec.decodeState(store.document!.payload);
    await store.writeDocument(
      codec.encodeState(
        state.copyWith(
          account: const LegacyAccountCodec().decodeJson({
            ...state.account.toJson(),
            'days': {'2026-11-07': day(2)},
          }),
        ),
      ),
      writeToken: 'day',
      expected: store.document,
    );
    final c = DayDateCorrectionController(
      store: store,
      snapshot: store.document!,
      isWriteBlocked: () => false,
    );
    addTearDown(c.dispose);
    final command = c.capture(
      operationId: 'stale',
      from: '2026-11-07',
      to: '2026-11-08',
      reason: 'Date',
      recordedAt: '2026-11-10T10:00:00Z',
    );
    await store.writeDocument(
      store.document!.payload,
      writeToken: 'equal-payload-new-revision',
      expected: store.document,
    );
    final before = store.document!, writes = store.writes;
    final result = await c.submit(command);
    expect(result, isA<DurableCommandFailure>());
    expect(store.document, before);
    expect(store.writes, writes);
    state = codec.decodeState(before.payload);
    final raw = state.account.toJson(), d = day(2);
    d['expenses'] = [
      {
        'id': 'legacy',
        'categoryId': 'samoon',
        'amount': 1,
        'note': '',
        'createdAt': '2026-11-07T10:00:00Z',
        'funding': {'source': 'daily', 'dailyAmount': 1, 'cashAmount': 0},
      },
    ];
    final missing = state.copyWith(
      account: const LegacyAccountCodec().decodeJson({
        ...raw,
        'days': {'2026-11-07': d, '2026-11-09': day(1)},
      }),
    );
    expect(
      () => DayDateCorrectionCommand.capture(
        state: missing,
        fence: before.fence,
        expectedRevision: before.revision,
        operationId: 'missing',
        from: '2026-11-07',
        to: '2026-11-08',
        reason: 'Date',
        recordedAt: '2026-11-10T10:00:00Z',
      ),
      throwsFormatException,
    );
    expect(
      () => DayDatePlan.create(
        missing.account,
        from: '2026-11-07',
        to: '2026-11-09',
      ),
      throwsFormatException,
    );
    expect(store.document, before);
  });
}
