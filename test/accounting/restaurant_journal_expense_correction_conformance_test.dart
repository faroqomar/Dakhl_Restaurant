import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:madar_application/madar_application.dart';
import 'package:madar_data/madar_data.dart';
import 'package:madar_domain/madar_domain.dart';
import 'package:dakhl_restaurant/accounting/journal_command_host.dart';
import 'package:dakhl_restaurant/accounting/restaurant_journal_expense_correction_commands.dart';
import 'package:dakhl_restaurant/accounting/restaurant_journal_expense_history.dart';
import 'package:dakhl_restaurant/accounting/restaurant_journal_mapper.dart';
import 'package:dakhl_restaurant/accounting/restaurant_journal_spending_commands.dart';
import 'package:dakhl_restaurant/accounting/daily_cash_queries.dart';
import 'package:dakhl_restaurant/accounts/portable_journal_codec.dart';
import 'package:dakhl_restaurant/accounts/portable_journal_state.dart';

import 'restaurant_journal_expense_correction_commands_test.dart' as fixtures;
import 'restaurant_journal_sale_safety_test.dart'
    show LostCommitAcknowledgementStore;

const expenseCodec = PortableJournalCodec();
Future<DocumentSnapshot> expenseSnapshot(
  LocalDocumentWorkspaceStore store,
) async =>
    (await store.readDocument() as CapabilitySuccess<DocumentSnapshot?>).value!;
Future<PortableJournalState> expenseState(
  LocalDocumentWorkspaceStore store,
) async => expenseCodec.decodeState((await expenseSnapshot(store)).payload);

void main() {
  late Directory temp;
  final stores = <LocalDocumentWorkspaceStore>[];
  setUp(() async {
    temp = await Directory.systemTemp.createTemp('dakhl-expense-correction-');
  });
  tearDown(() async {
    for (final store in stores.reversed) {
      await store.close();
    }
    stores.clear();
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });
  Future<PowerSyncLocalDocumentWorkspaceStore> open({
    WorkspaceCheckpoint? checkpoint,
  }) async {
    final result = await PowerSyncLocalDocumentWorkspaceStore.open(
      directoryPath: temp.path,
      checkpoint: checkpoint,
    );
    final store =
        (result as CapabilitySuccess<PowerSyncLocalDocumentWorkspaceStore>)
            .value;
    stores.add(store);
    return store;
  }

  Future<StorageFence> seed(
    LocalDocumentWorkspaceStore store, {
    RestaurantJournalMapper? mapper,
  }) async {
    final result = await store.writeDocument(
      expenseCodec.encodeState(fixtures.expenseSeed(mapper: mapper)),
      writeToken: 'seed',
    );
    return (result as CapabilitySuccess<DocumentSnapshot>).value.fence;
  }

  test('PowerSync frozen edit/delete fixture full-map parity and historical replay after reopen', () async {
    final store = await open();
    final fence = await seed(store);
    final create = fixtures.createExpense(fence: fence);
    final spending = RestaurantJournalSpendingCommandCoordinator(store: store);
    expect(
      await spending.executeExpense(create),
      isA<DurableCommandSuccess<RestaurantJournalSpendingOutcome>>(),
    );
    final initial = await expenseState(store);
    final oracle = jsonDecode(
      File('test/fixtures/legacy/expense_corrections.json').readAsStringSync(),
    ) as Map;
    final expected = oracle['results'] as List;
    final correction = RestaurantJournalExpenseCorrectionCoordinator(
      store: store,
    );
    final first = fixtures.editExpense(fence: fence, category: 'market');
    final second = fixtures.editExpense(
      fence: fence,
      operation: 'second',
      target: 'replacement',
      inverse: 'inverse-2',
      replacement: 'replacement-2',
      day: '10',
      amount: 90,
      note: ' second ',
      category: 'bread',
      fundingSource: FundingSource.shared,
      dailyAmount: 30,
      cashAmount: 60,
    );
    final third = fixtures.editExpense(
      fence: fence,
      operation: 'zero',
      target: 'replacement-2',
      inverse: 'inverse-3',
      replacement: 'replacement-3',
      day: '10',
      amount: 0,
      category: 'bread',
      note: ' zero ',
      fundingSource: FundingSource.daily,
      policy: RestaurantJournalPolicies.allowZero,
    );
    final delete = fixtures.deleteExpense(
      fence: fence,
      target: 'replacement-3',
      policy: RestaurantJournalPolicies.allowZero,
    );
    var index = 0;
    for (final command in [first, second, third, delete]) {
      final before = await expenseSnapshot(store);
      expect(
        await correction.execute(command),
        isA<DurableCommandSuccess<RestaurantJournalExpenseCorrectionOutcome>>(),
      );
      final after = await expenseSnapshot(store);
      expect(after.revision, before.revision + 1);
      final state = expenseCodec.decodeState(after.payload);
      expect(state.account.toJson(), (expected[index] as Map)['account']);
      final queries = DailyCashQueries(state.account);
      expect(
        queries.cashBalance.toInt(),
        ((expected[index] as Map)['summary'] as Map)['cash'],
      );
      for (final day
          in (state.account.toJson()['days'] as Map).keys.cast<String>()) {
        final expectedDay =
            (((expected[index] as Map)['summary'] as Map)['days'] as Map)[day]
                as Map;
        final actual = queries.day(day);
        expect(actual.dailySpent.toInt(), expectedDay['dailySpent']);
        expect(actual.total.toInt(), expectedDay['total']);
        expect(actual.remaining?.toInt(), expectedDay['remaining']);
        expect(actual.recordedBalance?.toInt(), expectedDay['balance']);
      }
      expect(state.receipts.length, index + 2);
      expect(
        state.journals
            .take(initial.journals.length)
            .map((j) => j.toJson())
            .toList(),
        initial.journals.map((j) => j.toJson()).toList(),
      );
      index++;
    }
    final finalSnapshot = await expenseSnapshot(store);
    for (final command in [first, second, third, delete]) {
      expect(
        await correction.execute(command),
        isA<
          DurableCommandReplayed<RestaurantJournalExpenseCorrectionOutcome>
        >(),
      );
    }
    expect(
      await spending.executeExpense(create),
      isA<DurableCommandReplayed<RestaurantJournalSpendingOutcome>>(),
    );
    expect((await expenseSnapshot(store)).payload, finalSnapshot.payload);
    await store.close();
    stores.remove(store);
    final reopened = await open();
    expect(
      await RestaurantJournalSpendingCommandCoordinator(store: reopened)
          .executeExpense(create),
      isA<DurableCommandReplayed<RestaurantJournalSpendingOutcome>>(),
    );
    expect(
      await RestaurantJournalExpenseCorrectionCoordinator(store: reopened)
          .execute(first),
      isA<DurableCommandReplayed<RestaurantJournalExpenseCorrectionOutcome>>(),
    );
    expect((await expenseSnapshot(reopened)).payload, finalSnapshot.payload);
  });
  for (final deleting in [false, true]) {
    test(
      'real precommit fault keeps complete bytes/revision, then retry ${deleting ? 'delete' : 'edit'}',
      () async {
        var fail = false, hits = 0;
        final store = await open(
          checkpoint: (boundary) async {
            if (fail && boundary == 'transaction.before_commit') {
              hits++;
              throw StateError('synthetic precommit fault');
            }
          },
        );
        final fence = await seed(store);
        await RestaurantJournalSpendingCommandCoordinator(store: store)
            .executeExpense(fixtures.createExpense(fence: fence));
        final correction = RestaurantJournalExpenseCorrectionCoordinator(
          store: store,
        );
        final command = deleting
            ? fixtures.deleteExpense(fence: fence, target: 'original')
            : fixtures.editExpense(fence: fence);
        final before = await expenseSnapshot(store);
        fail = true;
        expect(
          await correction.execute(command),
          isA<
            DurableCommandFailure<RestaurantJournalExpenseCorrectionOutcome>
          >(),
        );
        fail = false;
        expect(hits, 1);
        final after = await expenseSnapshot(store);
        expect(after.payload, before.payload);
        expect(after.revision, before.revision);
        await store.close();
        stores.remove(store);
        final reopened = await open();
        final coordinator = RestaurantJournalExpenseCorrectionCoordinator(
          store: reopened,
        );
        expect(
          await coordinator.execute(command),
          isA<
            DurableCommandSuccess<RestaurantJournalExpenseCorrectionOutcome>
          >(),
        );
        expect(
          await coordinator.execute(command),
          isA<
            DurableCommandReplayed<RestaurantJournalExpenseCorrectionOutcome>
          >(),
        );
      },
    );
  }
  test(
    'real committed lost ACK resolves once and reopens without second effect',
    () async {
      final inner = await open();
      final fence = await seed(inner);
      await RestaurantJournalSpendingCommandCoordinator(store: inner)
          .executeExpense(fixtures.createExpense(fence: fence));
      final wrapper = LostCommitAcknowledgementStore(inner)
        ..loseNextWrite = true;
      final command = fixtures.editExpense(fence: fence);
      final coordinator = RestaurantJournalExpenseCorrectionCoordinator(
        store: wrapper,
      );
      final before = await expenseSnapshot(inner);
      final result = await coordinator.execute(command);
      expect(
        result,
        isA<
          DurableCommandReplayed<RestaurantJournalExpenseCorrectionOutcome>
        >(),
      );
      expect(wrapper.writes, 1);
      expect(wrapper.resolveCalls, 1);
      final committed = await expenseSnapshot(inner);
      expect(committed.revision, before.revision + 1);
      expect(
        await coordinator.execute(command),
        isA<
          DurableCommandReplayed<RestaurantJournalExpenseCorrectionOutcome>
        >(),
      );
      expect(wrapper.writes, 1);
      await inner.close();
      stores.remove(inner);
      final reopened = await open();
      expect(
        await RestaurantJournalExpenseCorrectionCoordinator(store: reopened)
            .execute(command),
        isA<
          DurableCommandReplayed<RestaurantJournalExpenseCorrectionOutcome>
        >(),
      );
      expect((await expenseSnapshot(reopened)).payload, committed.payload);
    },
  );
  test(
    'competing correction intents produce one inverse and one durable effect',
    () async {
      final store = await open();
      final fence = await seed(store);
      await RestaurantJournalSpendingCommandCoordinator(store: store)
          .executeExpense(fixtures.createExpense(fence: fence));
      final first = fixtures.editExpense(fence: fence);
      final second = fixtures.editExpense(
        fence: fence,
        operation: 'racer',
        inverse: 'racer-inverse',
        replacement: 'racer-replacement',
        amount: 190,
      );
      final results = await Future.wait([
        RestaurantJournalExpenseCorrectionCoordinator(store: store)
            .execute(first),
        RestaurantJournalExpenseCorrectionCoordinator(store: store)
            .execute(second),
      ]);
      expect(
        results
            .whereType<
              DurableCommandSuccess<RestaurantJournalExpenseCorrectionOutcome>
            >(),
        hasLength(1),
      );
      expect(
        results
            .whereType<
              DurableCommandFailure<RestaurantJournalExpenseCorrectionOutcome>
            >(),
        hasLength(1),
      );
      final state = await expenseState(store);
      expect(state.receipts, hasLength(2));
      expect(state.journals, hasLength(4));
      expect(
        state.journals.where((j) => j.journal.reversesId == 'original'),
        hasLength(1),
      );
      expect(
        RestaurantJournalExpenseHistory.validate(
          state: state,
          expenseId: 'expense',
          mapper: RestaurantJournalMapper(),
        ),
        isTrue,
      );
    },
  );
  test(
    'authority/lineage/changed intent/foreign host reject without writes',
    () async {
      final store = await open();
      final fence = await seed(store);
      await RestaurantJournalSpendingCommandCoordinator(store: store)
          .executeExpense(fixtures.createExpense(fence: fence));
      final coordinator = RestaurantJournalExpenseCorrectionCoordinator(
        store: store,
      );
      expect(
        await coordinator.execute(fixtures.editExpense()),
        isA<DurableCommandFailure<RestaurantJournalExpenseCorrectionOutcome>>(),
      );
      expect(
        await coordinator.execute(fixtures.editExpense(fence: null)),
        isA<DurableCommandFailure<RestaurantJournalExpenseCorrectionOutcome>>(),
      );
      final edited = fixtures.editExpense(fence: fence);
      expect(
        await coordinator.execute(edited),
        isA<DurableCommandSuccess<RestaurantJournalExpenseCorrectionOutcome>>(),
      );
      final before = await expenseSnapshot(store);
      expect(
        await coordinator.execute(
          fixtures.editExpense(fence: fence, note: 'changed'),
        ),
        isA<DurableCommandFailure<RestaurantJournalExpenseCorrectionOutcome>>(),
      );
      final foreign = await Directory.systemTemp.createTemp(
        'dakhl-expense-foreign-',
      );
      addTearDown(() => foreign.deleteSync(recursive: true));
      final other = (await PowerSyncLocalDocumentWorkspaceStore.open(
        directoryPath: foreign.path,
      ) as CapabilitySuccess<PowerSyncLocalDocumentWorkspaceStore>).value;
      try {
        expect(
          () => RestaurantJournalExpenseCorrectionCoordinator(
            store: store,
            host: JournalCommandHost(store: other),
          ),
          throwsArgumentError,
        );
      } finally {
        await other.close();
      }
      expect((await expenseSnapshot(store)).payload, before.payload);
      final state = await expenseState(store);
      expect(
        RestaurantJournalExpenseHistory.validate(
          state: state.copyWith(accountLineage: 'foreign'),
          expenseId: 'expense',
          mapper: RestaurantJournalMapper(),
        ),
        isFalse,
      );
    },
  );
}
