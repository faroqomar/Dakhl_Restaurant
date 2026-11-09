import 'package:flutter_test/flutter_test.dart';
import 'package:madar_application/madar_application.dart';
import 'package:madar_domain/madar_domain.dart';
import 'package:dakhl_restaurant/accounting/daily_register_snapshot_controller.dart';
import 'package:dakhl_restaurant/accounting/restaurant_journal_mapper.dart';
import 'package:dakhl_restaurant/accounts/legacy_account_codec.dart';
import 'package:dakhl_restaurant/accounts/portable_journal_codec.dart';
import 'package:dakhl_restaurant/accounts/portable_journal_state.dart';
import 'package:dakhl_restaurant/app/restaurant_operations_session.dart';

import '../accounts/accounts_view_model_test.dart' show FixtureStore;
import '../sales/sales_workflow_session_test.dart' show fixture, fresh;

DateOnly _date(String value) =>
    DateOnly.parse(value, minimumYear: 1000, maximumYear: 9999);

Future<(FixtureStore, DocumentSnapshot, PortableJournalState)>
_setupTestAccount({int dailySpent = 15000, int transferred = 5000}) async {
  const legacy = LegacyAccountCodec();
  const codec = PortableJournalCodec();
  final raw = Map<String, Object?>.from(legacy.empty().toJson());
  raw['days'] = {
    '2026-11-07': {
      'expenses': [
        {
          'id': 'exp-1',
          'categoryId': 'samoon',
          'amount': dailySpent,
          'note': 'Flour and oil',
          'funding': {
            'source': 'daily',
            'dailyAmount': dailySpent,
            'cashAmount': 0,
          },
          'createdAt': '2026-11-07T08:00:00Z',
        },
      ],
      'chickenUsed': 0,
      'chickenLeft': 0,
      'balance': null,
      'totalOverride': null,
      'remaining': null,
    },
  };
  raw['transfers'] = <Map<String, Object?>>[];
  final account = legacy.decodeJson(raw);
  final opening = RestaurantJournalMapper().mapVerifiedCutoverOpening(
    journalId: 'opening-jnl',
    effectiveDate: _date('2026-11-01'),
    verifiedPhysicalRegisterCash: BigInt.from(50000),
    verifiedCashboxBalance: BigInt.from(20000),
    verifiedSupplierDebts: {},
  );
  final state = PortableJournalState(
    accountLineage: 'lineage-register-test',
    account: account,
    sourceProvenance: const PortableJournalSourceProvenance(
      sourceVersion: 11,
      enrolledAt: '2026-11-01T00:00:00Z',
      migrated: false,
    ),
    cutoverState: PortableJournalCutoverState.established(
      cutoverDate: _date('2026-11-01'),
      openingJournalId: 'opening-jnl',
    ),
    journals: [
      PortableJournalEntry(
        journal: opening.journal,
        sourceType: RestaurantJournalSourceType.cutoverOpening.name,
        sourceRecordId: 'opening-src',
        recordedAt: '2026-11-01T00:00:00Z',
      ),
    ],
  );
  final store = FixtureStore();
  final created = await store.writeDocument(
    codec.encodeState(state),
    writeToken: 'initial-register',
  );
  final snapshot = (created as CapabilitySuccess<DocumentSnapshot>).value;
  return (store, snapshot, state);
}

void main() {
  test('recordRemaining computes total + amount + transferred, preserves journals, and replays idempotently', () async {
    final (store, snapshot, state) = await _setupTestAccount(
      dailySpent: 15000,
      transferred: 5000,
    );
    final controller = DailyRegisterSnapshotController(
      store: store,
      snapshot: snapshot,
    );
    addTearDown(controller.dispose);

    // 1. Initial queries show no remaining or balance
    final initialQuery = controller.daySnapshot('2026-11-07');
    expect(initialQuery.dailySpent, BigInt.from(15000));
    expect(initialQuery.transferred, BigInt.zero);
    expect(initialQuery.total, BigInt.from(15000));
    expect(initialQuery.remaining, isNull);
    expect(initialQuery.recordedBalance, isNull);

    // 2. Record remaining amount = 25000
    final result = await controller.recordRemaining(
      date: '2026-11-07',
      amount: BigInt.from(25000),
      operationId: 'op-rem-1',
      recordedAt: '2026-11-07T12:00:00Z',
    );
    expect(result, isA<DurableCommandSuccess<DailyRegisterSnapshotOutcome>>());
    final success =
        result as DurableCommandSuccess<DailyRegisterSnapshotOutcome>;
    expect(success.outcome.kind, 'remaining');
    expect(success.outcome.remainingAmount, BigInt.from(25000));
    // total (15000) + remaining (25000) + transferred (0) = 40000
    expect(success.outcome.recordedBalance, BigInt.from(40000));

    final updatedQuery = controller.daySnapshot('2026-11-07');
    expect(updatedQuery.remaining, BigInt.from(25000));
    expect(updatedQuery.recordedBalance, BigInt.from(40000));

    // Journals and cutover state preserved unchanged
    const codec = PortableJournalCodec();
    final latestState = codec.decodeState(controller.snapshot.payload);
    expect(latestState.journals.length, state.journals.length);
    expect(latestState.receipts.length, 1);
    expect(latestState.receipts.first.identity.operationId, 'op-rem-1');

    // 3. Replay with the same operationId is idempotent
    final replay = await controller.recordRemaining(
      date: '2026-11-07',
      amount: BigInt.from(25000),
      operationId: 'op-rem-1',
      recordedAt: '2026-11-07T12:00:00Z',
    );
    expect(replay, isA<DurableCommandReplayed<DailyRegisterSnapshotOutcome>>());
    final replayed =
        replay as DurableCommandReplayed<DailyRegisterSnapshotOutcome>;
    expect(replayed.outcome?.recordedBalance, BigInt.from(40000));
  });

  test('recordBalance and recordTotal update overrides/balance, require reason, and append retained corrections', () async {
    final (store, snapshot, _) = await _setupTestAccount();
    final controller = DailyRegisterSnapshotController(
      store: store,
      snapshot: snapshot,
    );
    addTearDown(controller.dispose);

    // Empty reason rejected
    final emptyReason = await controller.recordBalance(
      date: '2026-11-07',
      amount: BigInt.from(50000),
      reason: '   ',
    );
    expect(
      emptyReason,
      isA<DurableCommandFailure<DailyRegisterSnapshotOutcome>>(),
    );
    expect((emptyReason as DurableCommandFailure).code, 'invalid_reason');

    // 1. Record balance with reason
    final balRes = await controller.recordBalance(
      date: '2026-11-07',
      amount: BigInt.from(50000),
      reason: 'عد الصندوق الفعلي',
      operationId: 'op-bal-1',
      recordedAt: '2026-11-07T13:00:00Z',
    );
    expect(balRes, isA<DurableCommandSuccess<DailyRegisterSnapshotOutcome>>());
    expect(
      controller.daySnapshot('2026-11-07').recordedBalance,
      BigInt.from(50000),
    );
    expect(controller.corrections('2026-11-07').length, 1);
    expect(
      controller.corrections('2026-11-07').first['reason'],
      'عد الصندوق الفعلي',
    );
    expect(controller.corrections('2026-11-07').first['before'], isNull);
    expect(controller.corrections('2026-11-07').first['after'], 50000);

    // 2. Clear balance with null
    final clearBalRes = await controller.recordBalance(
      date: '2026-11-07',
      amount: null,
      reason: 'إلغاء التثبيت اليدوي',
      operationId: 'op-bal-2',
      recordedAt: '2026-11-07T13:30:00Z',
    );
    expect(
      clearBalRes,
      isA<DurableCommandSuccess<DailyRegisterSnapshotOutcome>>(),
    );
    expect(controller.daySnapshot('2026-11-07').recordedBalance, isNull);
    expect(controller.corrections('2026-11-07').length, 2);
    expect(controller.corrections('2026-11-07').last['before'], 50000);
    expect(controller.corrections('2026-11-07').last['after'], isNull);

    // 3. Record total override
    final totalRes = await controller.recordTotal(
      date: '2026-11-07',
      amount: BigInt.from(18000),
      reason: 'تعديل المجموع يدويا',
      operationId: 'op-tot-1',
      recordedAt: '2026-11-07T14:00:00Z',
    );
    expect(
      totalRes,
      isA<DurableCommandSuccess<DailyRegisterSnapshotOutcome>>(),
    );
    expect(controller.daySnapshot('2026-11-07').total, BigInt.from(18000));
    expect(controller.corrections('2026-11-07').length, 3);
    expect(controller.corrections('2026-11-07').last['field'], 'total');

    // 4. Restore automatic total with null
    final autoTotalRes = await controller.recordTotal(
      date: '2026-11-07',
      amount: null,
      reason: 'الرجوع للحساب التلقائي',
      operationId: 'op-tot-2',
      recordedAt: '2026-11-07T14:30:00Z',
    );
    expect(
      autoTotalRes,
      isA<DurableCommandSuccess<DailyRegisterSnapshotOutcome>>(),
    );
    // total falls back to dailySpent (15000)
    expect(controller.daySnapshot('2026-11-07').total, BigInt.from(15000));
    expect(controller.corrections('2026-11-07').length, 4);
  });

  test(
    'rejection on invalid bounds, out-of-range amounts, and invalid date',
    () async {
      final (store, snapshot, _) = await _setupTestAccount();
      final controller = DailyRegisterSnapshotController(
        store: store,
        snapshot: snapshot,
      );
      addTearDown(controller.dispose);

      // Amount exceeds 1e12
      final overflow = await controller.recordRemaining(
        date: '2026-11-07',
        amount: BigInt.from(1000000000001),
      );
      expect(
        overflow,
        isA<DurableCommandFailure<DailyRegisterSnapshotOutcome>>(),
      );
      expect((overflow as DurableCommandFailure).code, 'invalid_amount');

      // Negative remaining amount
      final neg = await controller.recordRemaining(
        date: '2026-11-07',
        amount: BigInt.from(-100),
      );
      expect(neg, isA<DurableCommandFailure<DailyRegisterSnapshotOutcome>>());
      expect((neg as DurableCommandFailure).code, 'invalid_amount');

      // Invalid date
      final badDate = await controller.recordRemaining(
        date: 'invalid-date',
        amount: BigInt.from(1000),
      );
      expect(
        badDate,
        isA<DurableCommandFailure<DailyRegisterSnapshotOutcome>>(),
      );
      expect((badDate as DurableCommandFailure).code, 'invalid_date');
    },
  );

  test('commit_unknown write captures pending command, blocks other commands, and resolves via retry without self-block', () async {
    final (store, snapshot, _) = await _setupTestAccount();
    final controller = DailyRegisterSnapshotController(
      store: store,
      snapshot: snapshot,
    );
    addTearDown(controller.dispose);

    // Simulate store write failure to commit_unknown
    store.writeFailure = 'commit_unknown';
    final failed = await controller.recordRemaining(
      date: '2026-11-07',
      amount: BigInt.from(30000),
      operationId: 'op-unknown-1',
    );
    expect(failed, isA<DurableCommandFailure<DailyRegisterSnapshotOutcome>>());
    expect((failed as DurableCommandFailure).code, 'commit_unknown');
    expect(controller.needsReadback, true);
    expect(controller.pending, true);

    // Other operations blocked while pending uncertain write
    final blocked = await controller.recordBalance(
      date: '2026-11-07',
      amount: BigInt.from(10000),
      reason: 'Blocked check',
    );
    expect(blocked, isA<DurableCommandFailure<DailyRegisterSnapshotOutcome>>());
    expect((blocked as DurableCommandFailure).code, 'commit_unknown');

    // Clear write failure and retry the pending command without self-block
    store.writeFailure = null;
    final retried = await controller.retry();
    expect(retried, isA<DurableCommandSuccess<DailyRegisterSnapshotOutcome>>());
    expect(controller.needsReadback, false);
    expect(controller.daySnapshot('2026-11-07').remaining, BigInt.from(30000));
  });

  test('session integration coordinates dailyRegister with peer synchronization and mutual exclusion', () async {
    final (store, snapshot) = await fixture();
    final opened = await RestaurantOperationsSession.open(
      store: store,
      snapshot: snapshot,
      compareText: (a, b) => a.compareTo(b),
      fresh: fresh('active'),
    );
    final session =
        (opened as CapabilitySuccess<RestaurantOperationsSession>).value;
    addTearDown(session.dispose);

    expect(session.dailyRegister, isNotNull);
    expect(session.dailyRegister.snapshot.revision, snapshot.revision);

    // Record remaining via session.dailyRegister API
    final res = await session.dailyRegister.recordRemaining(
      date: '2026-11-07',
      amount: BigInt.from(55000),
      operationId: 'session-reg-op',
    );
    expect(res, isA<DurableCommandSuccess<DailyRegisterSnapshotOutcome>>());

    // Advance and verify synchronization across peers
    expect(await session.synchronize(), isA<CapabilitySuccess<void>>());
    expect(
      session.spending.snapshot.revision,
      session.dailyRegister.snapshot.revision,
    );
    expect(
      session.settings.snapshot.revision,
      session.dailyRegister.snapshot.revision,
    );
    expect(
      session.parties.snapshot.revision,
      session.dailyRegister.snapshot.revision,
    );
    expect(
      session.dailyRegister.daySnapshot('2026-11-07').remaining,
      BigInt.from(55000),
    );
  });
}
