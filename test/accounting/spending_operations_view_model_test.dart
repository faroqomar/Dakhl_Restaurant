import 'package:dakhl_restaurant/accounting/daily_cash_controller.dart';
import 'package:dakhl_restaurant/accounting/restaurant_journal_mapper.dart';
import 'package:dakhl_restaurant/accounting/restaurant_journal_spending_commands.dart';
import 'package:dakhl_restaurant/accounting/restaurant_journal_transfer_commands.dart';
import 'package:dakhl_restaurant/accounting/spending_operations_view_model.dart';
import 'package:dakhl_restaurant/accounts/legacy_account_codec.dart';
import 'package:dakhl_restaurant/accounts/portable_journal_codec.dart';
import 'package:dakhl_restaurant/accounts/portable_journal_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar_application/madar_application.dart';
import 'package:madar_domain/madar_domain.dart';

import '../accounts/accounts_view_model_test.dart' show FixtureStore;

DateOnly date(String value) =>
    DateOnly.parse(value, minimumYear: 1000, maximumYear: 9999);

void main() {
  test('spending operations viewModel submits operating expense, transfers, and replays idempotently', () async {
    const legacy = LegacyAccountCodec();
    const codec = PortableJournalCodec();
    final raw = Map<String, Object?>.from(legacy.empty().toJson());
    raw['days'] = {
      '2026-11-07': {
        'expenses': <Map<String, Object?>>[],
        'chickenUsed': 0,
        'chickenLeft': 0,
        'balance': 100000,
        'totalOverride': null,
        'remaining': {
          'amount': 100000,
          'dailySpent': 0,
          'transferred': 0,
          'salesTotal': 0,
        },
      },
    };
    final account = legacy.decodeJson(raw);
    final opening = RestaurantJournalMapper().mapVerifiedCutoverOpening(
      journalId: 'opening',
      effectiveDate: date('2026-11-01'),
      verifiedPhysicalRegisterCash: BigInt.from(100000),
      verifiedCashboxBalance: BigInt.from(50000),
      verifiedSupplierDebts: {},
    );
    final state = PortableJournalState(
      accountLineage: 'lineage-spending',
      account: account,
      sourceProvenance: const PortableJournalSourceProvenance(
        sourceVersion: 11,
        enrolledAt: '2026-11-01T00:00:00Z',
        migrated: false,
      ),
      cutoverState: PortableJournalCutoverState.established(
        cutoverDate: date('2026-11-01'),
        openingJournalId: 'opening',
      ),
      journals: [
        PortableJournalEntry(
          journal: opening.journal,
          sourceType: RestaurantJournalSourceType.cutoverOpening.name,
          sourceRecordId: 'opening-source',
          recordedAt: '2026-11-01T00:00:00Z',
        ),
      ],
    );
    final store = FixtureStore();
    final created = await store.writeDocument(
      codec.encodeState(state),
      writeToken: 'initial-spending',
    );
    final initial = (created as CapabilitySuccess<DocumentSnapshot>).value;

    final spending = SpendingOperationsViewModel(
      snapshot: initial,
      store: store,
    );
    addTearDown(spending.dispose);

    expect(spending.postingEnabled, true);
    expect(spending.accountLineage, 'lineage-spending');

    // 1. Operating Expense Intent & Submission
    final expenseIntent = spending.createExpenseIntent(
      operationId: 'op-exp-1',
      expenseId: 'exp-1',
      journalId: 'jnl-exp-1',
      date: date('2026-11-07'),
      categoryId: 'samoon',
      amount: BigInt.from(25000),
      fundingSource: FundingSource.daily,
      note: 'Fresh lettuce and onions',
      recordedAt: '2026-11-07T10:00:00Z',
    );

    final previewExp = spending.previewExpense(expenseIntent);
    expect(previewExp.rejected, false);

    final resultExp = await spending.submitExpense(expenseIntent);
    expect(
      resultExp,
      isA<DurableCommandSuccess<RestaurantJournalSpendingOutcome>>(),
    );
    expect(spending.selectedExpenseId, 'exp-1');
    expect(spending.selectedExpense?['amount'], 25000);

    // Replay check
    final writesBeforeReplay = store.writes;
    final replayExp = await spending.submitExpense(expenseIntent);
    expect(
      replayExp,
      isA<DurableCommandReplayed<RestaurantJournalSpendingOutcome>>(),
    );
    expect(store.writes, writesBeforeReplay);

    // 2. Transfer Intent & Submission
    final transferIntent = spending.transferIntent(
      operationId: 'op-tr-1',
      transferId: 'tr-1',
      journalId: 'jnl-tr-1',
      date: date('2026-11-07'),
      amount: BigInt.from(15000),
      recordedAt: '2026-11-07T12:00:00Z',
    );

    final previewTr = spending.previewTransfer(transferIntent);
    expect(previewTr.rejected, false);

    final resultTr = await spending.submitTransfer(transferIntent);
    expect(
      resultTr,
      isA<DurableCommandSuccess<RestaurantJournalTransferOutcome>>(),
    );
    expect(spending.selectedTransferId, 'tr-1');
    expect(spending.selectedTransfer?['amount'], 15000);

    // 3. Controller integration check
    final controller = DailyCashController(
      spending: spending,
      initialDate: '2026-11-07',
    );
    addTearDown(controller.dispose);

    expect(controller.selectedDate, '2026-11-07');
    final daySnap = controller.daySnapshot;
    expect(daySnap.dailySpent, BigInt.from(25000));
    expect(daySnap.transferred, BigInt.from(15000));
    expect(controller.transfers.length, 1);
    expect(controller.expenses.length, 1);
  });
}
