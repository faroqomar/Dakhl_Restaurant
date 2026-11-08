import 'package:dakhl_restaurant/accounting/financial_session_undo.dart';
import 'package:dakhl_restaurant/accounting/spending_session_undo_adapter.dart';
import 'package:dakhl_restaurant/accounting/spending_operations_view_model.dart';
import 'package:dakhl_restaurant/accounts/legacy_account_codec.dart';
import 'package:dakhl_restaurant/accounts/portable_journal_codec.dart';
import 'package:dakhl_restaurant/sales/sales_operations_view_model.dart';
import 'package:dakhl_restaurant/accounting/restaurant_journal_sale_commands.dart';
import 'package:dakhl_restaurant/sales/ticket_workspace.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar_application/madar_application.dart';
import 'package:madar_domain/madar_domain.dart';

import '../sales/sales_workflow_session_test.dart' show fixture;
import '../sales/source_sales_completion_test.dart' show RefundAckStore;
import 'external_cash_commands_test.dart' show date, create, rows, accepted;

void register(
  FinancialSessionUndoController undo,
  SpendingOperationsViewModel model,
  DocumentSnapshot before,
  DurableCommandResult<dynamic> result,
) {
  final receipt = switch (result) {
    DurableCommandSuccess(:final receipt) => receipt,
    DurableCommandReplayed(:final receipt) => receipt,
    _ => throw StateError('Fixture command did not commit'),
  };
  expect(
    undo.register(
      before: before,
      result: result,
      adapter: SpendingSessionUndoAdapter(
        spending: model,
        identity: receipt.identity,
      ),
    ),
    isA<CapabilitySuccess<void>>(),
  );
}

void main() {
  test('session undo compensates cash edit then creation and retains original journals/old replay', () async {
    final (store, snapshot) = await fixture();
    final m = SpendingOperationsViewModel(
      store: store,
      snapshot: snapshot,
      acceptedCounterAccountId: accepted,
    );
    final undo = FinancialSessionUndoController(
      readSnapshot: () => m.snapshot,
      isWriteBlocked: () => false,
    );
    addTearDown(m.dispose);
    addTearDown(undo.dispose);
    var before = m.snapshot;
    final original = create(m), created = await m.submitExternalCash(original);
    register(undo, m, before, created);
    before = m.snapshot;
    final edit = m.editExternalCashIntent(
      operationId: 'edit',
      transactionId: 'cash',
      journalId: 'replacement',
      inverseJournalId: 'inverse',
      expectedActiveJournalId: 'cash-original',
      expectedSource: rows(m).single,
      reason: 'Correct',
      date: date('2026-11-08'),
      amount: BigInt.from(700),
      type: 'withdrawal',
      note: 'Changed',
      recordedAt: '2026-11-08T10:00:00Z',
    );
    final edited = await m.submitExternalCash(edit);
    register(undo, m, before, edited);
    expect(undo.length, 2);
    expect(await undo.undo(), isA<CapabilitySuccess<void>>());
    expect(rows(m).single['amount'], 1000);
    expect(rows(m).single['type'], 'deposit');
    expect(undo.length, 1);
    final trail = const PortableJournalCodec()
        .decodeState(m.snapshot.payload)
        .journals
        .map((j) => j.toJson())
        .toList();
    expect(trail, hasLength(6));
    expect(await undo.undo(), isA<CapabilitySuccess<void>>());
    expect(rows(m), isEmpty);
    expect(undo.length, 0);
    final after = const PortableJournalCodec().decodeState(m.snapshot.payload);
    expect(after.journals.take(6).map((j) => j.toJson()), trail);
    final writes = store.writes;
    expect(await m.submitExternalCash(original), isA<DurableCommandReplayed>());
    expect(store.writes, writes);
  });
  test('expense edit undo restores exact previous amount/funding and create undo removes expense on existing day', () async {
    final (store, snapshot) = await fixture();
    const codec = PortableJournalCodec();
    final state = codec.decodeState(snapshot.payload);
    final account = const LegacyAccountCodec().decodeJson({
      ...state.account.toJson(),
      'days': {
        '2026-11-07': {
          'expenses': <Object?>[],
          'balance': 10000,
          'chickenUsed': 0,
          'chickenLeft': 0,
          'totalOverride': null,
          'remaining': {
            'amount': 10000,
            'dailySpent': 0,
            'transferred': 0,
            'salesTotal': 0,
          },
        },
      },
    });
    final seeded = await store.writeDocument(
      codec.encodeState(state.copyWith(account: account)),
      writeToken: 'seed-day',
      expected: snapshot,
    );
    final m = SpendingOperationsViewModel(
      store: store,
      snapshot: (seeded as CapabilitySuccess<DocumentSnapshot>).value,
    );
    final undo = FinancialSessionUndoController(
      readSnapshot: () => m.snapshot,
      isWriteBlocked: () => false,
    );
    addTearDown(m.dispose);
    addTearDown(undo.dispose);
    var before = m.snapshot;
    final c = m.createExpenseIntent(
      operationId: 'expense',
      expenseId: 'e',
      journalId: 'e-journal',
      date: date('2026-11-07'),
      categoryId: 'samoon',
      amount: BigInt.from(100),
      fundingSource: FundingSource.daily,
      note: 'Original',
      recordedAt: '2026-11-07T10:00:00Z',
    );
    register(undo, m, before, await m.submitExpense(c));
    before = m.snapshot;
    final edit = m.editExpenseIntent(
      operationId: 'expense-edit',
      expenseId: 'e',
      expectedActiveJournalId: 'e-journal',
      inverseJournalId: 'e-inverse',
      replacementJournalId: 'e-replacement',
      date: date('2026-11-07'),
      categoryId: 'samoon',
      amount: BigInt.from(200),
      fundingSource: FundingSource.shared,
      dailyAmount: BigInt.from(150),
      cashAmount: BigInt.from(50),
      note: 'Changed',
      reason: 'Correct',
      recordedAt: '2026-11-08T10:00:00Z',
    );
    register(undo, m, before, await m.submitExpenseCorrection(edit));
    expect(await undo.undo(), isA<CapabilitySuccess<void>>());
    expect(m.expensesForDate('2026-11-07').single['amount'], 100);
    expect(
      (m.expensesForDate('2026-11-07').single['funding'] as Map)['source'],
      'daily',
    );
    expect(await undo.undo(), isA<CapabilitySuccess<void>>());
    expect(m.expensesForDate('2026-11-07'), isEmpty);
    expect(m.account.toJson(), account.toJson());
  });
  test('failed inverse retains undo position and unknown acknowledgement retries one captured compensation', () async {
    final (store, snapshot) = await fixture();
    final wrapped = RefundAckStore(store);
    final m = SpendingOperationsViewModel(
      store: wrapped,
      snapshot: snapshot,
      acceptedCounterAccountId: accepted,
    );
    final undo = FinancialSessionUndoController(
      readSnapshot: () => m.snapshot,
      isWriteBlocked: () => false,
    );
    addTearDown(m.dispose);
    addTearDown(undo.dispose);
    final before = m.snapshot;
    register(undo, m, before, await m.submitExternalCash(create(m)));
    final payload = m.snapshot.payload;
    store.writeFailure = 'fixture_failure';
    expect(await undo.undo(), isA<CapabilityFailure<void>>());
    expect(undo.length, 1);
    expect(m.snapshot.payload, payload);
    store.writeFailure = null;
    wrapped.loseNext = true;
    expect(await undo.undo(), isA<CapabilityFailure<void>>());
    expect(undo.needsReadback, true);
    expect(undo.length, 1);
    expect(undo.reset(), isA<CapabilityFailure<void>>());
    final writes = store.writes;
    wrapped.blocked = false;
    expect(await undo.undo(), isA<CapabilitySuccess<void>>());
    expect(store.writes, writes);
    expect(undo.length, 0);
    expect(rows(m), isEmpty);
  });
  test('unsupported adapter and unregistered newer commit refuse with stack intact', () async {
    final (store, snapshot) = await fixture();
    final m = SpendingOperationsViewModel(
      store: store,
      snapshot: snapshot,
      acceptedCounterAccountId: accepted,
    );
    final undo = FinancialSessionUndoController(
      readSnapshot: () => m.snapshot,
      isWriteBlocked: () => false,
    );
    addTearDown(m.dispose);
    addTearDown(undo.dispose);
    expect(await m.submitExternalCash(create(m)), isA<DurableCommandSuccess>());
    final before = m.snapshot;
    final del = m.deleteExternalCashIntent(
      operationId: 'delete',
      transactionId: 'cash',
      inverseJournalId: 'deleted',
      expectedActiveJournalId: 'cash-original',
      expectedSource: rows(m).single,
      reason: 'Delete',
      recordedAt: '2026-11-08T10:00:00Z',
    );
    final deleted = await m.submitExternalCash(del);
    expect(
      undo.register(
        before: before,
        result: deleted,
        adapter: const UnsupportedFinancialUndo(
          'Unsupported registered action',
        ),
      ),
      isA<CapabilitySuccess<void>>(),
    );
    final writes = store.writes;
    expect(await undo.undo(), isA<CapabilityFailure<void>>());
    expect(undo.errorCode, 'undo_kind_not_supported');
    expect(undo.length, 1);
    expect(store.writes, writes);
    final c = m.createExternalCashIntent(
      operationId: 'other',
      transactionId: 'other',
      journalId: 'other-journal',
      date: date('2026-11-08'),
      amount: BigInt.one,
      type: 'deposit',
      recordedAt: '2026-11-08T10:00:00Z',
    );
    expect(await m.submitExternalCash(c), isA<DurableCommandSuccess>());
    expect(await undo.undo(), isA<CapabilityFailure<void>>());
    expect(undo.errorCode, 'stale_undo_snapshot');
    expect(undo.length, 1);
  });
  test('observer registration caps30, dedupes and resets on load/import/sales boundary', () async {
    final (store, snapshot) = await fixture();
    final m = SpendingOperationsViewModel(
      store: store,
      snapshot: snapshot,
      acceptedCounterAccountId: accepted,
    );
    final undo = FinancialSessionUndoController(
      readSnapshot: () => m.snapshot,
      isWriteBlocked: () => false,
    );
    addTearDown(m.dispose);
    addTearDown(undo.dispose);
    for (var i = 0; i < 31; i++) {
      final before = m.snapshot,
          c = m.createExternalCashIntent(
            operationId: 'op$i',
            transactionId: 't$i',
            journalId: 'j$i',
            date: date('2026-11-07'),
            amount: BigInt.one,
            type: 'deposit',
            recordedAt: '2026-11-07T10:00:00Z',
          );
      final result = await m.submitExternalCash(c);
      final receipt = (result as DurableCommandSuccess).receipt;
      final adapter = SpendingSessionUndoAdapter(
        spending: m,
        identity: receipt.identity,
      );
      expect(
        undo.registerTransition(
          before: before,
          after: m.snapshot,
          adapter: adapter,
        ),
        isA<CapabilitySuccess<void>>(),
      );
      expect(
        undo.registerTransition(
          before: before,
          after: m.snapshot,
          adapter: adapter,
        ),
        isA<CapabilitySuccess<void>>(),
      );
    }
    expect(undo.length, 30);
    final unchangedBefore = m.snapshot;
    final rewritten = await store.writeDocument(
      unchangedBefore.payload,
      writeToken: 'same-source-rewrite',
      expected: unchangedBefore,
    );
    expect(
      m.acceptSnapshot(
        (rewritten as CapabilitySuccess<DocumentSnapshot>).value,
      ),
      isA<CapabilitySuccess<void>>(),
    );
    expect(
      undo.registerTransition(
        before: unchangedBefore,
        after: m.snapshot,
        adapter: const UnsupportedFinancialUndo('No source change'),
      ),
      isA<CapabilitySuccess<void>>(),
    );
    expect(undo.length, 30);
    expect(undo.reset(), isA<CapabilitySuccess<void>>());
    expect(undo.length, 0);
    final before = m.snapshot, result = await m.submitExternalCash(create(m));
    register(undo, m, before, result);
    expect(undo.length, 1);
    final sales = SalesOperationsViewModel(
      commands: RestaurantJournalSaleCommandCoordinator(store: store),
      snapshot: m.snapshot,
    );
    addTearDown(sales.dispose);
    expect(
      await sales.submit(
        sales.checkoutIntent(
          ticket: TicketDraft(
            id: 'sale',
            date: '2026-11-07',
            orderType: 'سفري',
            discount: '0',
            note: '',
            lines: [
              TicketLine(
                productId: 'p',
                quantityUnits: BigInt.from(1000),
                price: 1000,
              ),
            ],
          ),
          operationId: 'sale',
          journalId: 'sale-journal',
          recordedAt: '2026-11-07T11:00:00Z',
        ),
      ),
      isA<DurableCommandSuccess>(),
    );
    expect(m.acceptSnapshot(sales.snapshot), isA<CapabilitySuccess<void>>());
    expect(undo.observe(), isA<CapabilitySuccess<void>>());
    expect(undo.length, 0);
  });
}
