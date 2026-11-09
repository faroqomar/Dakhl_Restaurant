import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:madar_application/madar_application.dart';
import 'package:madar_data/madar_data.dart';
import 'package:dakhl_restaurant/accounting/restaurant_journal_expense_correction_commands.dart';
import 'package:dakhl_restaurant/accounting/restaurant_journal_expense_history.dart';
import 'package:dakhl_restaurant/accounting/restaurant_journal_mapper.dart';
import 'package:dakhl_restaurant/accounting/restaurant_journal_spending_commands.dart';
import 'package:dakhl_restaurant/accounts/portable_journal_codec.dart';
import 'package:dakhl_restaurant/accounts/portable_journal_state.dart';

import 'restaurant_journal_expense_correction_commands_test.dart' as f;

void main() {
  const codec = PortableJournalCodec();
  test(
    'historical expense receipts allow revisions to reset under a new fence',
    () {
      final root = f.applyCreate(f.expenseSeed());
      const newFence = StorageFence(
        storeId: 'fixture',
        generation: 'new-generation',
      );
      final command = f.editExpense(fence: newFence);
      final result = RestaurantJournalExpenseCorrectionCoordinator.evaluate(
        command: command,
        state: root,
        mapper: RestaurantJournalMapper(),
      );
      expect(result.rejected, isFalse);
      final candidate = result.candidateState!.copyWith(
        receipts: [
          ...root.receipts,
          DurableCommandReceipt(
            identity: command.identity,
            status: DurableCommandStatus.committed,
            outcomePayload: result.outcomePayload!,
            committedRevision: 1,
            sequence: 2,
            fence: newFence,
          ),
        ],
      );
      expect(
        codec.decodeState(codec.encodeState(candidate)).receipts.length,
        2,
      );
      expect(
        () => candidate.copyWith(
          receipts: [
            ...root.receipts,
            DurableCommandReceipt(
              identity: command.identity,
              status: DurableCommandStatus.committed,
              outcomePayload: result.outcomePayload!,
              committedRevision: root.receipts.single.committedRevision,
              sequence: 2,
              fence: root.receipts.single.fence,
            ),
          ],
        ),
        throwsA(
          isA<PortableJournalException>().having(
            (error) => error.code,
            'code',
            'invalid_receipt_revision',
          ),
        ),
      );
      expect(
        RestaurantJournalExpenseHistory.validate(
          state: candidate,
          expenseId: 'expense',
          mapper: RestaurantJournalMapper(),
        ),
        isTrue,
      );
    },
  );
  for (final deleting in [false, true]) {
    test(
      'fresh ${deleting ? 'delete' : 'edit'} succeeds after same-account restore',
      () async {
        final temp = await Directory.systemTemp.createTemp(
          'dakhl-expense-fence-restore-',
        );
        final opened = await PowerSyncLocalDocumentWorkspaceStore.open(
          directoryPath: temp.path,
        );
        var store =
            (opened as CapabilitySuccess<PowerSyncLocalDocumentWorkspaceStore>)
                .value;
        try {
          final seed = await store.writeDocument(
            codec.encodeState(f.expenseSeed()),
            writeToken: 'restore-regression-seed',
          );
          final fence =
              (seed as CapabilitySuccess<DocumentSnapshot>).value.fence;
          expect(
            await RestaurantJournalSpendingCommandCoordinator(store: store)
                .executeExpense(f.createExpense(fence: fence)),
            isA<DurableCommandSuccess<RestaurantJournalSpendingOutcome>>(),
          );
          final before =
              (await store.readDocument()
                      as CapabilitySuccess<DocumentSnapshot?>)
                  .value!;
          await store.close();
          await Directory('${temp.path}/restored').create();
          final restored = await PowerSyncLocalDocumentWorkspaceStore.open(
            directoryPath: '${temp.path}/restored',
          );
          store =
              (restored
                      as CapabilitySuccess<
                        PowerSyncLocalDocumentWorkspaceStore
                      >)
                  .value;
          final replaced = await store.writeDocument(
            before.payload,
            writeToken: 'restore-regression-replacement',
          );
          final replacement =
              (replaced as CapabilitySuccess<DocumentSnapshot>).value;
          expect(replacement.fence, isNot(fence));
          expect(replacement.revision, 1);
          final command = deleting
              ? f.deleteExpense(fence: replacement.fence, target: 'original')
              : f.editExpense(fence: replacement.fence);
          final result = await RestaurantJournalExpenseCorrectionCoordinator(
            store: store,
          ).execute(command);
          expect(
            result,
            isA<
              DurableCommandSuccess<RestaurantJournalExpenseCorrectionOutcome>
            >(),
            reason:
                result
                    is DurableCommandFailure<
                      RestaurantJournalExpenseCorrectionOutcome
                    >
                ? 'actual code: ${result.code}'
                : '$result',
          );
        } finally {
          await store.close();
          if (temp.existsSync()) temp.deleteSync(recursive: true);
        }
      },
    );
  }
}
