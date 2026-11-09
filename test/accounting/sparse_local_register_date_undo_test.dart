import 'package:flutter_test/flutter_test.dart';
import 'package:madar_application/madar_application.dart';
import 'package:dakhl_restaurant/accounts/legacy_account_codec.dart';
import 'package:dakhl_restaurant/accounts/portable_journal_codec.dart';
import 'package:dakhl_restaurant/accounts/portable_journal_state.dart';
import 'package:dakhl_restaurant/accounting/day_date_correction_controller.dart';
import 'package:dakhl_restaurant/accounting/day_date_session_undo_adapter.dart';
import 'package:dakhl_restaurant/accounting/daily_register_snapshot_controller.dart';
import 'package:dakhl_restaurant/accounting/daily_register_session_undo_adapter.dart';

import '../sales/sales_workflow_session_test.dart' show fixture;

const codec = PortableJournalCodec();
Map<String, Object?> day(int chicken) => {
  'expenses': <Object?>[],
  'chickenUsed': chicken,
  'chickenLeft': 0,
  'balance': null,
  'totalOverride': null,
  'remaining': null,
};
PortableJournalState artifacts(PortableJournalState state) => state.copyWith(
  account: const LegacyAccountCodec().decodeJson({
    ...state.account.toJson(),
    'products': [
      ...state.account.toJson()['products']! as List,
      {
        'id': 'retained',
        'name': 'Archived',
        'code': '',
        'unit': 'piece',
        'group': '',
        'price': 5,
        'minStock': 0,
        'trackStock': true,
        'archived': true,
      },
    ],
    'stockEntries': [
      {
        'id': 'opening-stock',
        'productId': 'retained',
        'date': '2026-11-07',
        'quantity': 2,
        'kind': 'opening',
        'note': '',
        'createdAt': '2026-11-07T10:00:00Z',
      },
      {
        'id': 'inverse-stock',
        'productId': 'retained',
        'date': '2026-11-07',
        'quantity': -2,
        'kind': 'adjustment',
        'note': 'Undo',
        'createdAt': '2026-11-07T11:00:00Z',
        'reversesId': 'opening-stock',
      },
    ],
  }),
);
void main() {
  test(
    'sparse exact inverse preserves gap day and retained stock artifacts',
    () async {
      final (store, snapshot) = await fixture();
      final state = codec.decodeState(snapshot.payload);
      await store.writeDocument(
        codec.encodeState(
          state.copyWith(
            account: const LegacyAccountCodec().decodeJson({
              ...state.account.toJson(),
              'days': {
                '2026-11-07': day(1),
                '2026-11-09': day(2),
                '2026-11-18': day(3),
              },
            }),
          ),
        ),
        writeToken: 'days',
        expected: snapshot,
      );
      final before = codec.decodeState(store.document!.payload),
          dates = DayDateCorrectionController(
            store: store,
            snapshot: store.document!,
            isWriteBlocked: () => false,
          );
      addTearDown(dates.dispose);
      final shift = dates.capture(
        operationId: 'sparse',
        from: '2026-11-07',
        to: '2026-11-17',
        end: '2026-11-09',
        reason: 'Date',
        recordedAt: '2026-11-20T10:00:00Z',
      );
      final result = await dates.submit(shift);
      expect(result, isA<DurableCommandSuccess>());
      final after = codec.decodeState(store.document!.payload),
          current = artifacts(after);
      await store.writeDocument(
        codec.encodeState(current),
        writeToken: 'retained-artifacts',
        expected: store.document,
      );
      dates.acceptSnapshot(store.document!);
      final adapter = DayDateSessionUndoAdapter(
        dates: dates,
        identity: (result as DurableCommandSuccess).receipt.identity,
      );
      final undo = await adapter
          .prepare(before: before, after: after, current: current)
          .execute!();
      expect(
        undo,
        isA<DurableCommandSuccess>(),
        reason: undo is DurableCommandFailure ? undo.code : '',
      );
      final restored = codec.decodeState(store.document!.payload);
      expect(restored.account.days, before.account.days);
      expect(restored.account.days['2026-11-18'], day(3));
      expect(
        restored.account.toJson()['products'],
        current.account.toJson()['products'],
      );
      expect(
        restored.account.toJson()['stockEntries'],
        current.account.toJson()['stockEntries'],
      );
      expect(restored.receipts.length, after.receipts.length + 1);
      expect(
        await dates.coordinator.execute(shift),
        isA<DurableCommandReplayed>(),
      );
    },
  );
  test('register undo restores touched field preserving retained stock and other day quantities', () async {
    final (store, snapshot) = await fixture();
    final state = codec.decodeState(snapshot.payload),
        d = day(1)..['balance'] = 80;
    await store.writeDocument(
      codec.encodeState(
        state.copyWith(
          account: const LegacyAccountCodec().decodeJson({
            ...state.account.toJson(),
            'days': {'2026-11-07': d},
          }),
        ),
      ),
      writeToken: 'day',
      expected: snapshot,
    );
    final before = codec.decodeState(store.document!.payload),
        register = DailyRegisterSnapshotController(
          store: store,
          snapshot: store.document!,
        );
    addTearDown(register.dispose);
    final result = await register.recordBalance(
      date: '2026-11-07',
      amount: BigInt.from(100),
      reason: 'Count',
      operationId: 'balance',
      recordedAt: '2026-11-07T11:00:00Z',
    );
    expect(result, isA<DurableCommandSuccess>());
    final after = codec.decodeState(store.document!.payload),
        base = artifacts(after);
    final current = base.copyWith(
      account: const LegacyAccountCodec().decodeJson({
        ...base.account.toJson(),
        'days': {
          '2026-11-07': {
            ...(base.account.days['2026-11-07']! as Map)
                .cast<String, Object?>(),
            'chickenUsed': 8,
          },
        },
      }),
    );
    await store.writeDocument(
      codec.encodeState(current),
      writeToken: 'retained-artifacts',
      expected: store.document,
    );
    register.acceptSnapshot(store.document!);
    final attempt = DailyRegisterSessionUndoAdapter(
      register: register,
      identity: (result as DurableCommandSuccess).receipt.identity,
    ).prepare(before: before, after: after, current: current);
    final undo = await attempt.execute!();
    expect(
      undo,
      isA<DurableCommandSuccess>(),
      reason: undo is DurableCommandFailure ? undo.code : '',
    );
    final restored = codec.decodeState(store.document!.payload),
        r = restored.account.days['2026-11-07']! as Map;
    expect(r['balance'], 80);
    expect(r['chickenUsed'], 8);
    expect(
      restored.account.toJson()['stockEntries'],
      current.account.toJson()['stockEntries'],
    );
    expect(
      restored.account.toJson()['products'],
      current.account.toJson()['products'],
    );
  });
}
