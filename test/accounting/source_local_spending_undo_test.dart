import 'dart:convert';

import 'package:dakhl_restaurant/accounting/deleted_spending_restoration.dart';
import 'package:dakhl_restaurant/accounting/financial_session_undo.dart';
import 'package:dakhl_restaurant/accounting/spending_session_undo_adapter.dart';
import 'package:dakhl_restaurant/accounts/portable_journal_codec.dart';
import 'package:dakhl_restaurant/app/restaurant_operations_session.dart';
import 'package:dakhl_restaurant/catalog/catalog_view_model.dart';
import 'package:dakhl_restaurant/inventory/stock_session_undo.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar_application/madar_application.dart';
import 'package:madar_domain/madar_domain.dart';

import '../sales/sales_workflow_session_test.dart' show fixture, fresh;
import '../inventory/inventory_commands_test.dart' show product, movement;
import 'deleted_spending_restoration_test.dart'
    show setup, create, records, state;
import 'external_cash_commands_test.dart' show date;

DurableCommandReceipt receipt(DurableCommandResult<dynamic> result) =>
    switch (result) {
      DurableCommandSuccess(:final receipt) => receipt,
      DurableCommandReplayed(:final receipt) => receipt,
      _ => throw StateError('Fixture did not commit'),
    };
void main() {
  test('older financial undo preserves later archived product and original-date stock compensation', () async {
    final (store, snapshot) = await fixture();
    final session = (await RestaurantOperationsSession.open(
      store: store,
      snapshot: snapshot,
      compareText: (a, b) => a.compareTo(b),
      fresh: fresh('draft'),
    ) as CapabilitySuccess<RestaurantOperationsSession>).value;
    addTearDown(session.dispose);
    final undo = FinancialSessionUndoController(
      readSnapshot: () => session.snapshot,
      isWriteBlocked: () => false,
    );
    addTearDown(undo.dispose);
    final m = session.spending;
    final beforeExpense = session.snapshot;
    final saved = await m.submitExpense(
      m.createExpenseIntent(
        operationId: 'expense',
        expenseId: 'e',
        journalId: 'e-journal',
        date: date('2026-11-07'),
        categoryId: 'samoon',
        amount: BigInt.from(100),
        fundingSource: FundingSource.daily,
        recordedAt: '2026-11-07T10:00:00Z',
      ),
    );
    expect(saved, isA<DurableCommandSuccess>());
    await session.synchronize();
    expect(
      undo.register(
        before: beforeExpense,
        result: saved,
        adapter: SpendingSessionUndoAdapter(
          spending: m,
          identity: receipt(saved).identity,
        ),
      ),
      isA<CapabilitySuccess<void>>(),
    );
    final catalog = CatalogViewModel(session.metadataRepository);
    addTearDown(catalog.dispose);
    final beforeStock = session.snapshot;
    expect(
      await catalog.createProduct(
        product('retained'),
        session: catalog.beginEdit(),
        opening: movement(
          'opening-retained',
          2000,
          productId: 'retained',
          kind: StockEntryKind.opening,
          day: '2026-11-07',
        ),
      ),
      isA<CapabilitySuccess>(),
    );
    await session.synchronize();
    expect(
      undo.registerTransition(
        before: beforeStock,
        after: session.snapshot,
        adapter: StockMovementSessionUndoAdapter(
          repository: session.metadataRepository,
          bridge: session.metadataBridge,
          reason: 'Undo created product',
        ),
      ),
      isA<CapabilitySuccess<void>>(),
    );
    expect(await undo.undo(), isA<CapabilitySuccess<void>>());
    await session.synchronize();
    final retained = const PortableJournalCodec().decodeState(
      session.snapshot.payload,
    );
    final products = retained.account.toJson()['products'],
        stock = retained.account.toJson()['stockEntries'];
    expect(
      (products as List).cast<Map>().singleWhere(
        (p) => p['id'] == 'retained',
      )['archived'],
      true,
    );
    expect(stock as List, hasLength(2));
    expect(
      await undo.undo(),
      isA<CapabilitySuccess<void>>(),
      reason: undo.errorCode,
    );
    await session.synchronize();
    expect(m.expensesForDate('2026-11-07'), isEmpty);
    expect(m.account.toJson()['products'], products);
    expect(m.account.toJson()['stockEntries'], stock);
    expect(
      state(m).journals.take(retained.journals.length).map((j) => j.toJson()),
      retained.journals.map((j) => j.toJson()),
    );
    expect(undo.length, 0);
  });
  test('non-last expense transfer and cash edit undo restores original row order and historical replay', () async {
    for (final kind in DeletedSpendingKind.values) {
      final (store, _, m) = await setup();
      addTearDown(m.dispose);
      expect(await create(m, kind), isA<DurableCommandSuccess>());
      final other = switch (kind) {
        DeletedSpendingKind.expense => m.submitExpense(
          m.createExpenseIntent(
            operationId: 'other',
            expenseId: 'other',
            journalId: 'other-journal',
            date: date('2026-11-07'),
            categoryId: 'samoon',
            amount: BigInt.from(20),
            fundingSource: FundingSource.daily,
            recordedAt: '2026-11-07T11:00:00Z',
          ),
        ),
        DeletedSpendingKind.transfer => m.submitTransfer(
          m.transferIntent(
            operationId: 'other',
            transferId: 'other',
            journalId: 'other-journal',
            date: date('2026-11-07'),
            amount: BigInt.from(20),
            recordedAt: '2026-11-07T11:00:00Z',
          ),
        ),
        DeletedSpendingKind.externalCash => m.submitExternalCash(
          m.createExternalCashIntent(
            operationId: 'other',
            transactionId: 'other',
            journalId: 'other-journal',
            date: date('2026-11-07'),
            amount: BigInt.from(20),
            type: 'deposit',
            recordedAt: '2026-11-07T11:00:00Z',
          ),
        ),
      };
      expect(await other, isA<DurableCommandSuccess>());
      final before = m.snapshot, original = m.account.toJson();
      final undo = FinancialSessionUndoController(
        readSnapshot: () => m.snapshot,
        isWriteBlocked: () => false,
      );
      addTearDown(undo.dispose);
      final Object command = switch (kind) {
        DeletedSpendingKind.expense => m.editExpenseIntent(
          operationId: 'edit',
          expenseId: 'record',
          expectedActiveJournalId: 'original',
          inverseJournalId: 'edit-inverse',
          replacementJournalId: 'edited',
          date: date('2026-11-07'),
          categoryId: 'samoon',
          amount: BigInt.from(200),
          fundingSource: FundingSource.daily,
          note: 'Changed',
          reason: 'Edit non-last',
          recordedAt: '2026-11-08T10:00:00Z',
        ),
        DeletedSpendingKind.transfer => m.editTransferIntent(
          operationId: 'edit',
          transferId: 'record',
          expectedActiveJournalId: 'original',
          inverseJournalId: 'edit-inverse',
          replacementJournalId: 'edited',
          newAmount: BigInt.from(200),
          reason: 'Edit non-last',
          recordedAt: '2026-11-08T10:00:00Z',
        ),
        DeletedSpendingKind.externalCash => m.editExternalCashIntent(
          operationId: 'edit',
          transactionId: 'record',
          expectedActiveJournalId: 'original',
          inverseJournalId: 'edit-inverse',
          journalId: 'edited',
          expectedSource: records(m, kind).single,
          date: date('2026-11-07'),
          amount: BigInt.from(200),
          type: 'deposit',
          note: 'Changed',
          reason: 'Edit non-last',
          recordedAt: '2026-11-08T10:00:00Z',
        ),
      };
      Future<DurableCommandResult<dynamic>> submit() => switch (kind) {
        DeletedSpendingKind.expense => m.submitExpenseCorrection(
          command as dynamic,
        ),
        DeletedSpendingKind.transfer => m.submitTransferCorrection(command),
        DeletedSpendingKind.externalCash => m.submitExternalCash(
          command as dynamic,
        ),
      };
      final result = await submit();
      expect(result, isA<DurableCommandSuccess>());
      expect(
        (jsonDecode(receipt(result).identity.canonicalPayloadIdentity) as Map)
            .containsKey('sourceOrder'),
        false,
      );
      expect(
        undo.register(
          before: before,
          result: result,
          adapter: SpendingSessionUndoAdapter(
            spending: m,
            identity: receipt(result).identity,
          ),
        ),
        isA<CapabilitySuccess<void>>(),
      );
      expect(
        await undo.undo(),
        isA<CapabilitySuccess<void>>(),
        reason: '${kind.name}: ${undo.errorCode}',
      );
      expect(m.account.toJson(), original);
      final lastIntent = jsonDecode(
        state(m).receipts.last.identity.canonicalPayloadIdentity,
      ) as Map;
      expect(lastIntent['sourceOrder'], {
        'position': 0,
        'siblingIds': ['other'],
      });
      final writes = store.writes;
      expect(await submit(), isA<DurableCommandReplayed>());
      expect(store.writes, writes);
    }
  });
}
