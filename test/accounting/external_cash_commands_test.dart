import 'package:dakhl_restaurant/accounting/cash_adjustment_editor.dart';
import 'package:dakhl_restaurant/accounting/restaurant_journal_external_cash_commands.dart';
import 'package:dakhl_restaurant/accounting/spending_operations_view_model.dart';
import 'package:dakhl_restaurant/accounts/portable_journal_codec.dart';
import 'package:dakhl_restaurant/accounts/legacy_account_codec.dart';
import 'package:dakhl_restaurant/ui/components.dart';
import 'package:dakhl_restaurant/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar_application/madar_application.dart';
import 'package:madar_domain/madar_domain.dart';

import '../sales/sales_workflow_session_test.dart' show fixture;
import '../sales/source_sales_completion_test.dart' show RefundAckStore;

// Synthetic test configuration, not acceptance of a restaurant counteraccount.
const accepted = 'test:accepted-external-counter';
DateOnly date(String s) =>
    DateOnly.parse(s, minimumYear: 1000, maximumYear: 9999);
List<Map<String, Object?>> rows(SpendingOperationsViewModel m) =>
    (m.account.toJson()['transactions']! as List).cast<Map<String, Object?>>();
ExternalCashCommand create(SpendingOperationsViewModel m) =>
    m.createExternalCashIntent(
      operationId: 'create',
      transactionId: 'cash',
      journalId: 'cash-original',
      date: date('2026-11-07'),
      amount: BigInt.from(1000),
      type: 'deposit',
      note: '  Deposit  ',
      recordedAt: '2026-11-07T10:00:00Z',
    );
void main() {
  test('cash correction chain preserves immutable dates, source timestamp and old receipts after reopen/delete', () async {
    final (store, snapshot) = await fixture();
    final m = SpendingOperationsViewModel(
      store: store,
      snapshot: snapshot,
      acceptedCounterAccountId: accepted,
    );
    addTearDown(m.dispose);
    final initial = create(m);
    expect(await m.submitExternalCash(initial), isA<DurableCommandSuccess>());
    expect(m.cashBalance, BigInt.from(1000));
    final original = rows(m).single;
    final edit = m.editExternalCashIntent(
      operationId: 'edit',
      transactionId: 'cash',
      journalId: 'replacement',
      inverseJournalId: 'inverse',
      expectedActiveJournalId: 'cash-original',
      expectedSource: original,
      reason: 'Correct source date and direction',
      date: date('2026-11-08'),
      amount: BigInt.from(500),
      type: 'withdrawal',
      note: ' Revised ',
      recordedAt: '2026-11-08T10:00:00Z',
    );
    expect(await m.submitExternalCash(edit), isA<DurableCommandSuccess>());
    expect(rows(m).single['createdAt'], original['createdAt']);
    expect(rows(m).single['note'], 'Revised');
    expect(m.cashBalance, BigInt.from(-500));
    var state = const PortableJournalCodec().decodeState(m.snapshot.payload);
    expect(
      state.journals
          .singleWhere((j) => j.journal.id == 'inverse')
          .journal
          .effectiveDate
          .toString(),
      '2026-11-07',
    );
    expect(
      state.journals
          .singleWhere((j) => j.journal.id == 'replacement')
          .journal
          .effectiveDate
          .toString(),
      '2026-11-08',
    );
    var writes = store.writes;
    expect(await m.submitExternalCash(initial), isA<DurableCommandReplayed>());
    expect(store.writes, writes);
    final delete = m.deleteExternalCashIntent(
      operationId: 'delete',
      transactionId: 'cash',
      inverseJournalId: 'delete-inverse',
      expectedActiveJournalId: 'replacement',
      expectedSource: rows(m).single,
      reason: 'Remove mistaken entry',
      recordedAt: '2026-11-08T11:00:00Z',
    );
    expect(await m.submitExternalCash(delete), isA<DurableCommandSuccess>());
    expect(rows(m), isEmpty);
    expect(m.cashBalance, BigInt.zero);
    final reopened = SpendingOperationsViewModel(
      store: store,
      snapshot: m.snapshot,
      acceptedCounterAccountId: accepted,
    );
    addTearDown(reopened.dispose);
    writes = store.writes;
    expect(
      await reopened.submitExternalCash(initial),
      isA<DurableCommandReplayed>(),
    );
    expect(
      await reopened.submitExternalCash(edit),
      isA<DurableCommandReplayed>(),
    );
    expect(
      await reopened.submitExternalCash(delete),
      isA<DurableCommandReplayed>(),
    );
    expect(store.writes, writes);
    state = const PortableJournalCodec().decodeState(reopened.snapshot.payload);
    expect(
      RestaurantJournalExternalCashHistory.validate(
        state,
        'cash',
        reopened.externalCashCommands.mapper,
      ),
      true,
    );
    expect(reopened.activeExternalCashPosting('cash'), isNull);
  });
  test('missing accepted mapping refuses without write and stale source/missing posting remain ineligible', () async {
    final (store, snapshot) = await fixture();
    final unconfigured = SpendingOperationsViewModel(
      store: store,
      snapshot: snapshot,
    );
    addTearDown(unconfigured.dispose);
    final before = store.writes;
    final refusal = await unconfigured.submitExternalCash(create(unconfigured));
    expect(refusal, isA<DurableCommandFailure>());
    expect((refusal as DurableCommandFailure).code, 'unmapped_financial_gap');
    expect(store.writes, before);
    final m = SpendingOperationsViewModel(
      store: store,
      snapshot: snapshot,
      acceptedCounterAccountId: accepted,
    );
    addTearDown(m.dispose);
    expect(
      (await unconfigured.submitExternalCash(
        create(m),
      ) as DurableCommandFailure).code,
      'unmapped_financial_gap',
    );
    expect(store.writes, before);
    expect(await m.submitExternalCash(create(m)), isA<DurableCommandSuccess>());
    final source = rows(m).single;
    final edit = m.editExternalCashIntent(
      operationId: 'stale',
      transactionId: 'cash',
      journalId: 'new',
      inverseJournalId: 'inv',
      expectedActiveJournalId: 'cash-original',
      expectedSource: {...source, 'note': 'wrong'},
      reason: 'Correction',
      date: date('2026-11-08'),
      amount: BigInt.one,
      type: 'deposit',
      recordedAt: '2026-11-08T10:00:00Z',
    );
    final stale = await m.submitExternalCash(edit);
    expect((stale as DurableCommandFailure).code, 'transaction_source_changed');
    expect(rows(m).single, source);
    final missing = m.deleteExternalCashIntent(
      operationId: 'missing',
      transactionId: 'cash',
      inverseJournalId: 'missing-inverse',
      expectedActiveJournalId: 'absent',
      expectedSource: source,
      reason: 'Delete',
      recordedAt: '2026-11-08T10:00:00Z',
    );
    expect(
      (await m.submitExternalCash(missing) as DurableCommandFailure).code,
      'cross_cutover_source_has_no_post_cutover_journal',
    );
    expect(rows(m).single, source);
  });
  test('unknown cash acknowledgement retries exact captured intent without a second posting', () async {
    final (store, snapshot) = await fixture();
    final wrapped = RefundAckStore(store);
    final m = SpendingOperationsViewModel(
      store: wrapped,
      snapshot: snapshot,
      acceptedCounterAccountId: accepted,
    );
    addTearDown(m.dispose);
    wrapped.loseNext = true;
    expect(
      (await m.submitExternalCash(create(m)) as DurableCommandFailure).code,
      'commit_unknown',
    );
    expect(m.needsReadback, true);
    final writes = store.writes;
    wrapped.blocked = false;
    expect(await m.retry(), isA<DurableCommandReplayed>());
    expect(m.needsReadback, false);
    expect(store.writes, writes);
    expect(rows(m).single['amount'], 1000);
  });
  test(
    'history rejects altered source snapshots and pre-cutover creation',
    () async {
      final (store, snapshot) = await fixture();
      final m = SpendingOperationsViewModel(
        store: store,
        snapshot: snapshot,
        acceptedCounterAccountId: accepted,
      );
      addTearDown(m.dispose);
      final pre = m.createExternalCashIntent(
        operationId: 'pre',
        transactionId: 'pre',
        journalId: 'pre-journal',
        date: date('2026-10-31'),
        amount: BigInt.one,
        type: 'deposit',
        recordedAt: '2026-11-08T10:00:00Z',
      );
      expect(
        (await m.submitExternalCash(pre) as DurableCommandFailure).code,
        'pre_cutover_operation_rejected',
      );
      expect(rows(m), isEmpty);
      expect(
        await m.submitExternalCash(create(m)),
        isA<DurableCommandSuccess>(),
      );
      final state = const PortableJournalCodec().decodeState(
        m.snapshot.payload,
      );
      final raw = {
        ...state.account.toJson(),
        'transactions': [
          {...rows(m).single, 'amount': 999},
        ],
      };
      final altered = state.copyWith(
        account: const LegacyAccountCodec().decodeJson(raw),
      );
      expect(
        RestaurantJournalExternalCashHistory.validate(
          altered,
          'cash',
          m.externalCashCommands.mapper,
        ),
        false,
      );
    },
  );
  testWidgets(
    '390px cash form disables unclassified saves and submits exact durable deposit then reasoned delete',
    (tester) async {
      tester.view.physicalSize = const Size(390, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final (store, snapshot) = await fixture();
      final m = SpendingOperationsViewModel(
        store: store,
        snapshot: snapshot,
        acceptedCounterAccountId: accepted,
      );
      addTearDown(m.dispose);
      Future<void> mount(
        SpendingOperationsViewModel? model, {
        Map<String, Object?>? source,
      }) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: DakhlTheme.light,
            home: Directionality(
              textDirection: TextDirection.rtl,
              child: Scaffold(
                body: Builder(
                  builder: (ctx) => TextButton(
                    onPressed: () => showCashAdjustmentEditor(
                      ctx,
                      model: model,
                      source: source,
                    ),
                    child: const Text('Open'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
      }

      Finder field(String label) => find.descendant(
        of: find.widgetWithText(DakhlField, label),
        matching: find.byType(TextFormField),
      );
      await mount(null);
      expect(
        find.text(
          'الحفظ غير متاح حتى تحديد المعالجة المحاسبية المعتمدة لهذه الحركة.',
        ),
        findsOneWidget,
      );
      expect(
        tester
            .widget<DakhlButton>(find.widgetWithText(DakhlButton, 'حفظ الحركة'))
            .onPressed,
        isNull,
      );
      await tester.tap(
        find.byWidgetPredicate(
          (w) => w is DakhlIconButton && w.label == 'إغلاق النافذة',
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpWidget(const SizedBox());
      await mount(m);
      await tester.enterText(field('المبلغ · د.ع'), '١٢٣');
      await tester.enterText(field('ملاحظة'), 'Deposit memo');
      await tester.pump();
      await tester.ensureVisible(
        find.widgetWithText(DakhlButton, 'حفظ الحركة'),
      );
      await tester.tap(find.widgetWithText(DakhlButton, 'حفظ الحركة'));
      await tester.pumpAndSettle();
      expect(rows(m).single['amount'], 123);
      expect(rows(m).single['note'], 'Deposit memo');
      await tester.pumpWidget(const SizedBox());
      await mount(m, source: rows(m).single);
      expect(
        tester
            .widget<DakhlButton>(find.widgetWithText(DakhlButton, 'حذف الحركة'))
            .onPressed,
        isNull,
      );
      await tester.enterText(field('سبب التصحيح'), 'Remove fixture');
      await tester.pump();
      await tester.ensureVisible(
        find.widgetWithText(DakhlButton, 'حذف الحركة'),
      );
      await tester.tap(find.widgetWithText(DakhlButton, 'حذف الحركة'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(DakhlButton, 'حذف الحركة').last);
      await tester.pumpAndSettle();
      expect(rows(m), isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
}
