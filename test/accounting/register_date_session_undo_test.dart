import 'package:flutter_test/flutter_test.dart';
import 'package:madar_application/madar_application.dart';
import 'package:madar_domain/madar_domain.dart';
import 'package:dakhl_restaurant/accounts/legacy_account_codec.dart';
import 'package:dakhl_restaurant/accounts/portable_journal_codec.dart';
import 'package:dakhl_restaurant/accounting/daily_register_snapshot_controller.dart';
import 'package:dakhl_restaurant/accounting/daily_register_session_undo_adapter.dart';
import 'package:dakhl_restaurant/accounting/day_date_correction_controller.dart';
import 'package:dakhl_restaurant/accounting/day_date_correction_commands.dart';
import 'package:dakhl_restaurant/accounting/day_date_session_undo_adapter.dart';
import 'package:dakhl_restaurant/accounting/restaurant_journal_spending_commands.dart';

import '../sales/sales_workflow_session_test.dart' show fixture;

const codec = PortableJournalCodec();
DateOnly date(String s) =>
    DateOnly.parse(s, minimumYear: 1000, maximumYear: 9999);
DurableCommandReceipt receipt(DurableCommandResult<dynamic> result) =>
    switch (result) {
      DurableCommandSuccess(:final receipt) => receipt,
      DurableCommandReplayed(:final receipt) => receipt,
      _ => throw StateError('No receipt'),
    };
void main() {
  test(
    'register balance undo keeps audit trail and journals; replay adds nothing',
    () async {
      final (store, snapshot) = await fixture();
      final state = codec.decodeState(snapshot.payload),
          day = <String, Object?>{
            'expenses': <Object?>[],
            'chickenUsed': 0,
            'chickenLeft': 0,
            'balance': 80,
            'totalOverride': null,
            'remaining': null,
            'corrections': [
              {
                'field': 'balance',
                'date': '2026-11-07',
                'before': 0,
                'after': 80,
                'reason': 'Initial observation',
                'createdAt': '2026-11-07T08:00:00Z',
              },
            ],
          };
      await store.writeDocument(
        codec.encodeState(
          state.copyWith(
            account: const LegacyAccountCodec().decodeJson({
              ...state.account.toJson(),
              'days': {'2026-11-07': day},
            }),
          ),
        ),
        writeToken: 'day',
        expected: snapshot,
      );
      final register = DailyRegisterSnapshotController(
        store: store,
        snapshot: store.document!,
      );
      addTearDown(register.dispose);
      final before = codec.decodeState(store.document!.payload);
      final result = await register.recordBalance(
        date: '2026-11-07',
        amount: BigInt.from(-100),
        reason: 'Count',
        operationId: 'balance',
        recordedAt: '2026-11-07T09:00:00Z',
      );
      expect(result, isA<DurableCommandSuccess>());
      final after = codec.decodeState(store.document!.payload);
      final adapter = DailyRegisterSessionUndoAdapter(
        register: register,
        identity: receipt(result).identity,
      );
      final attempt = adapter.prepare(
        before: before,
        after: after,
        current: after,
      );
      final undo = await attempt.execute!();
      expect(
        undo,
        isA<DurableCommandSuccess>(),
        reason: undo is DurableCommandFailure ? undo.code : '',
      );
      final restored = codec.decodeState(store.document!.payload),
          row =
              (restored.account.toJson()['days']! as Map)['2026-11-07'] as Map;
      expect(row['balance'], 80);
      expect((row['corrections']! as List).length, 3);
      expect((row['corrections']! as List).last, {
        'field': 'balance',
        'date': '2026-11-07',
        'before': -100,
        'after': 80,
        'reason': 'تراجع عن التصحيح السابق',
        'createdAt': (undo as DurableCommandSuccess).outcome.recordedAt,
      });
      expect(
        restored.journals.map((j) => j.toJson()),
        before.journals.map((j) => j.toJson()),
      );
      expect(restored.receipts.length, before.receipts.length + 2);
      final writes = store.writes;
      expect(await attempt.execute!(), isA<DurableCommandReplayed>());
      expect(store.writes, writes);
    },
  );
  test('remaining snapshot undo retains exact baseline and pending command on failure', () async {
    final (store, snapshot) = await fixture();
    final register = DailyRegisterSnapshotController(
      store: store,
      snapshot: snapshot,
    );
    addTearDown(register.dispose);
    final before = codec.decodeState(snapshot.payload);
    final result = await register.recordRemaining(
      date: '2026-11-07',
      amount: BigInt.from(500),
      operationId: 'remaining',
      recordedAt: '2026-11-07T09:00:00Z',
    );
    expect(result, isA<DurableCommandSuccess>());
    final after = codec.decodeState(store.document!.payload);
    final attempt = DailyRegisterSessionUndoAdapter(
      register: register,
      identity: receipt(result).identity,
    ).prepare(before: before, after: after, current: after);
    store.writeFailure = 'commit_unknown';
    expect(await attempt.execute!(), isA<DurableCommandFailure>());
    expect(register.needsReadback, true);
    expect(
      codec.decodeState(store.document!.payload).account.toJson(),
      after.account.toJson(),
    );
    store.writeFailure = null;
    expect(await attempt.execute!(), isA<DurableCommandSuccess>());
    expect(register.needsReadback, false);
    final restored = codec.decodeState(store.document!.payload);
    expect(restored.account.toJson(), before.account.toJson());
    expect(
      restored.journals.map((j) => j.toJson()),
      before.journals.map((j) => j.toJson()),
    );
  });
  test('day-date undo appends compensation and old batch replays after restoration', () async {
    final (store, snapshot) = await fixture();
    final spending = RestaurantJournalSpendingCommandCoordinator(store: store);
    final original = CreateOperatingExpenseCommand(
      operationId: 'expense',
      accountLineage: 'lineage',
      expectedFence: snapshot.fence,
      expenseId: 'e',
      journalId: 'j',
      date: date('2026-11-07'),
      categoryId: 'samoon',
      amount: BigInt.from(100),
      fundingSource: FundingSource.daily,
      recordedAt: '2026-11-07T10:00:00Z',
    );
    expect(
      await spending.executeExpense(original),
      isA<DurableCommandSuccess>(),
    );
    final before = codec.decodeState(store.document!.payload),
        dates = DayDateCorrectionController(
          store: store,
          snapshot: store.document!,
          isWriteBlocked: () => false,
        );
    addTearDown(dates.dispose);
    final command = dates.capture(
      operationId: 'shift',
      from: '2026-11-07',
      to: '2026-11-08',
      reason: 'Date',
      recordedAt: '2026-11-10T10:00:00Z',
    );
    final shifted = await dates.submit(command);
    expect(shifted, isA<DurableCommandSuccess>());
    final after = codec.decodeState(store.document!.payload);
    final attempt = DayDateSessionUndoAdapter(
      dates: dates,
      identity: receipt(shifted).identity,
    ).prepare(before: before, after: after, current: after);
    final undo = await attempt.execute!();
    expect(
      undo,
      isA<DurableCommandSuccess>(),
      reason: undo is DurableCommandFailure ? undo.code : '',
    );
    final restored = codec.decodeState(store.document!.payload);
    expect(restored.account.toJson(), before.account.toJson());
    expect(restored.journals.length, before.journals.length + 4);
    expect(restored.receipts.length, before.receipts.length + 2);
    expect(
      restored.journals.take(before.journals.length).map((j) => j.toJson()),
      before.journals.map((j) => j.toJson()),
    );
    expect(
      await dates.coordinator.execute(
        DayDateCorrectionCommand.fromIntent(command.intent),
      ),
      isA<DurableCommandReplayed>(),
    );
    expect(
      await spending.executeExpense(original),
      isA<DurableCommandReplayed>(),
    );
  });
}
