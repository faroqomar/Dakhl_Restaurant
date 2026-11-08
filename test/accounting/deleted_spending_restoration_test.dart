import 'dart:convert';

import 'package:dakhl_restaurant/accounting/deleted_spending_restoration.dart';
import 'package:dakhl_restaurant/accounting/financial_session_undo.dart';
import 'package:dakhl_restaurant/accounting/spending_session_undo_adapter.dart';
import 'package:dakhl_restaurant/accounting/spending_operations_view_model.dart';
import 'package:dakhl_restaurant/accounting/restaurant_journal_expense_history.dart';
import 'package:dakhl_restaurant/accounts/legacy_account_codec.dart';
import 'package:dakhl_restaurant/accounts/portable_journal_codec.dart';
import 'package:dakhl_restaurant/accounts/portable_journal_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar_application/madar_application.dart';
import 'package:madar_domain/madar_domain.dart';

import '../accounts/accounts_view_model_test.dart' show FixtureStore;
import '../sales/sales_workflow_session_test.dart' show fixture;
import '../sales/source_sales_completion_test.dart' show RefundAckStore;
import 'external_cash_commands_test.dart' show date, accepted;

Future<(FixtureStore, RefundAckStore, SpendingOperationsViewModel)>
setup() async {
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
    writeToken: 'restoration-seed',
    expected: snapshot,
  );
  final wrapper = RefundAckStore(store);
  return (
    store,
    wrapper,
    SpendingOperationsViewModel(
      store: wrapper,
      snapshot: (seeded as CapabilitySuccess<DocumentSnapshot>).value,
      acceptedCounterAccountId: accepted,
    ),
  );
}

PortableJournalState state(SpendingOperationsViewModel m) =>
    const PortableJournalCodec().decodeState(m.snapshot.payload);
List<Map<String, Object?>> records(
  SpendingOperationsViewModel m,
  DeletedSpendingKind kind,
) => kind == DeletedSpendingKind.expense
    ? RestaurantJournalExpenseHistory.sourceRows(state(m), 'record')
    : (m.account.toJson()[kind == DeletedSpendingKind.transfer
                  ? 'transfers'
                  : 'transactions']!
              as List)
          .cast<Map<String, Object?>>()
          .where((r) => r['id'] == 'record')
          .toList();
Future<DurableCommandResult<dynamic>> create(
  SpendingOperationsViewModel m,
  DeletedSpendingKind k,
) => switch (k) {
  DeletedSpendingKind.expense => m.submitExpense(
    m.createExpenseIntent(
      operationId: 'create',
      expenseId: 'record',
      journalId: 'original',
      date: date('2026-11-07'),
      categoryId: 'samoon',
      amount: BigInt.from(100),
      fundingSource: FundingSource.daily,
      note: 'Original',
      recordedAt: '2026-11-07T10:00:00Z',
    ),
  ),
  DeletedSpendingKind.transfer => m.submitTransfer(
    m.transferIntent(
      operationId: 'create',
      transferId: 'record',
      journalId: 'original',
      date: date('2026-11-07'),
      amount: BigInt.from(100),
      recordedAt: '2026-11-07T10:00:00Z',
    ),
  ),
  DeletedSpendingKind.externalCash => m.submitExternalCash(
    m.createExternalCashIntent(
      operationId: 'create',
      transactionId: 'record',
      journalId: 'original',
      date: date('2026-11-07'),
      amount: BigInt.from(100),
      type: 'deposit',
      note: 'Original',
      recordedAt: '2026-11-07T10:00:00Z',
    ),
  ),
};
Object deletion(
  SpendingOperationsViewModel m,
  DeletedSpendingKind k,
  String target,
  String op,
) => switch (k) {
  DeletedSpendingKind.expense => m.deleteExpenseIntent(
    operationId: op,
    expenseId: 'record',
    expectedActiveJournalId: target,
    inverseJournalId: '$op-inverse',
    reason: 'Remove fixture',
    recordedAt: '2026-11-08T10:00:00Z',
  ),
  DeletedSpendingKind.transfer => m.deleteTransferIntent(
    operationId: op,
    transferId: 'record',
    expectedActiveJournalId: target,
    inverseJournalId: '$op-inverse',
    reason: 'Remove fixture',
    recordedAt: '2026-11-08T10:00:00Z',
  ),
  DeletedSpendingKind.externalCash => m.deleteExternalCashIntent(
    operationId: op,
    transactionId: 'record',
    expectedActiveJournalId: target,
    inverseJournalId: '$op-inverse',
    expectedSource: records(m, k).single,
    reason: 'Remove fixture',
    recordedAt: '2026-11-08T10:00:00Z',
  ),
};
Future<DurableCommandResult<dynamic>> submitDelete(
  SpendingOperationsViewModel m,
  DeletedSpendingKind k,
  Object c,
) => switch (k) {
  DeletedSpendingKind.expense => m.submitExpenseCorrection(c as dynamic),
  DeletedSpendingKind.transfer => m.submitTransferCorrection(c),
  DeletedSpendingKind.externalCash => m.submitExternalCash(c as dynamic),
};
RestoreDeletedSpendingCommand restore(
  SpendingOperationsViewModel m,
  DeletedSpendingKind k,
  Map<String, Object?> source, {
  String deleteOp = 'delete',
  List<String> siblings = const [],
}) => m.restoreDeletedIntent(
  kind: k,
  operationId: 'restore',
  recordId: 'record',
  deletedJournalId: 'original',
  deleteInverseJournalId: 'delete-inverse',
  deleteOperationId: deleteOp,
  replacementJournalId: 'restored',
  sourceSnapshot: source,
  position: 0,
  expectedSiblingIds: siblings,
  reason: 'Restore deleted source',
  recordedAt: '2026-11-08T11:00:00Z',
);
void main() {
  for (final kind in DeletedSpendingKind.values) {
    test(
      '${kind.name} undo restores delete then permits edit/delete and old operation replay',
      () async {
        final (store, _, m) = await setup();
        addTearDown(m.dispose);
        final created = await create(m, kind);
        expect(created, isA<DurableCommandSuccess>());
        final source = records(m, kind).single;
        final before = m.snapshot;
        final undo = FinancialSessionUndoController(
          readSnapshot: () => m.snapshot,
          isWriteBlocked: () => false,
        );
        addTearDown(undo.dispose);
        final del = deletion(m, kind, 'original', 'delete');
        final result = await submitDelete(m, kind, del);
        expect(result, isA<DurableCommandSuccess>());
        final receipt = (result as DurableCommandSuccess).receipt;
        expect(
          undo.register(
            before: before,
            result: result,
            adapter: SpendingSessionUndoAdapter(
              spending: m,
              identity: receipt.identity,
            ),
          ),
          isA<CapabilitySuccess<void>>(),
        );
        final prefix = state(m).journals.map((j) => j.toJson()).toList();
        expect(
          await undo.undo(),
          isA<CapabilitySuccess<void>>(),
          reason: undo.errorCode,
        );
        expect(records(m, kind).single, source);
        expect(
          state(m).journals.take(prefix.length).map((j) => j.toJson()),
          prefix,
        );
        final restored = state(m).journals.last;
        expect(restored.journal.reversesId, isNull);
        expect(restored.correctedFromJournalId, 'original');
        final restoreCommand = RestoreDeletedSpendingCommand.fromIntent(
          (jsonDecode(
            state(m).receipts.last.identity.canonicalPayloadIdentity,
          ) as Map).cast<String, Object?>(),
          m.deletedRestorationCommands.mapper,
        );
        final writes = store.writes;
        expect(await submitDelete(m, kind, del), isA<DurableCommandReplayed>());
        expect(store.writes, writes);
        final Future<DurableCommandResult<dynamic>> edit = switch (kind) {
          DeletedSpendingKind.expense => m.submitExpenseCorrection(
            m.editExpenseIntent(
              operationId: 'edit',
              expenseId: 'record',
              expectedActiveJournalId: restored.journal.id,
              inverseJournalId: 'edit-inverse',
              replacementJournalId: 'edited',
              date: date('2026-11-07'),
              categoryId: 'samoon',
              amount: BigInt.from(200),
              fundingSource: FundingSource.daily,
              note: 'Edited',
              reason: 'Edit restored',
              recordedAt: '2026-11-08T12:00:00Z',
            ),
          ),
          DeletedSpendingKind.transfer => m.submitTransferCorrection(
            m.editTransferIntent(
              operationId: 'edit',
              transferId: 'record',
              expectedActiveJournalId: restored.journal.id,
              inverseJournalId: 'edit-inverse',
              replacementJournalId: 'edited',
              newAmount: BigInt.from(200),
              reason: 'Edit restored',
              recordedAt: '2026-11-08T12:00:00Z',
            ),
          ),
          DeletedSpendingKind.externalCash => m.submitExternalCash(
            m.editExternalCashIntent(
              operationId: 'edit',
              transactionId: 'record',
              expectedActiveJournalId: restored.journal.id,
              inverseJournalId: 'edit-inverse',
              journalId: 'edited',
              expectedSource: records(m, kind).single,
              date: date('2026-11-07'),
              amount: BigInt.from(200),
              type: 'deposit',
              note: 'Edited',
              reason: 'Edit restored',
              recordedAt: '2026-11-08T12:00:00Z',
            ),
          ),
        };
        expect(await edit, isA<DurableCommandSuccess>());
        expect(
          await submitDelete(
            m,
            kind,
            deletion(m, kind, 'edited', 'delete-again'),
          ),
          isA<DurableCommandSuccess>(),
        );
        expect(records(m, kind), isEmpty);
        final count = store.writes;
        expect(await submitDelete(m, kind, del), isA<DurableCommandReplayed>());
        expect(
          await m.submitDeletedRestoration(restoreCommand),
          isA<DurableCommandReplayed>(),
        );
        // Reconstruct the original immutable command with its original IDs/payload.
        expect(await create(m, kind), isA<DurableCommandReplayed>());
        expect(store.writes, count);
      },
    );
  }
  test('restoration refuses wrong delete receipt, altered retained source and changed sibling list', () async {
    final (_, _, m) = await setup();
    addTearDown(m.dispose);
    expect(
      await create(m, DeletedSpendingKind.externalCash),
      isA<DurableCommandSuccess>(),
    );
    final source = records(m, DeletedSpendingKind.externalCash).single;
    expect(
      await submitDelete(
        m,
        DeletedSpendingKind.externalCash,
        deletion(m, DeletedSpendingKind.externalCash, 'original', 'delete'),
      ),
      isA<DurableCommandSuccess>(),
    );
    final wrong = await m.submitDeletedRestoration(
      restore(m, DeletedSpendingKind.externalCash, source, deleteOp: 'absent'),
    );
    expect(wrong, isA<DurableCommandFailure>());
    expect(records(m, DeletedSpendingKind.externalCash), isEmpty);
    final altered = restore(m, DeletedSpendingKind.externalCash, {
      ...source,
      'amount': 101,
    });
    expect(m.previewDeletedRestoration(altered).rejected, true);
    expect(
      m
          .previewDeletedRestoration(
            restore(
              m,
              DeletedSpendingKind.externalCash,
              source,
              siblings: ['changed'],
            ),
          )
          .rejectionCode,
      'restoration_source_changed',
    );
  });
  test('unknown restoration retries captured command once and retains deleted history', () async {
    final (store, wrapper, m) = await setup();
    addTearDown(m.dispose);
    expect(
      await create(m, DeletedSpendingKind.externalCash),
      isA<DurableCommandSuccess>(),
    );
    final source = records(m, DeletedSpendingKind.externalCash).single;
    expect(
      await submitDelete(
        m,
        DeletedSpendingKind.externalCash,
        deletion(m, DeletedSpendingKind.externalCash, 'original', 'delete'),
      ),
      isA<DurableCommandSuccess>(),
    );
    final c = restore(m, DeletedSpendingKind.externalCash, source);
    wrapper.loseNext = true;
    expect(
      (await m.submitDeletedRestoration(c) as DurableCommandFailure).code,
      'commit_unknown',
    );
    final writes = store.writes;
    wrapper.blocked = false;
    expect(await m.retry(), isA<DurableCommandReplayed>());
    expect(store.writes, writes);
    expect(records(m, DeletedSpendingKind.externalCash).single, source);
    expect(state(m).journals, hasLength(4));
  });
}
