import 'package:dakhl_restaurant/accounts/legacy_account_codec.dart';
import 'package:dakhl_restaurant/accounts/portable_journal_codec.dart';
import 'package:dakhl_restaurant/parties/additional_debt_commands.dart';
import 'package:dakhl_restaurant/parties/additional_debt_controller.dart';
import 'package:dakhl_restaurant/parties/additional_debt_session_undo_adapter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dakhl_restaurant/parties/parties_operations_view_model.dart';
import 'package:madar_domain/madar_domain.dart';
import 'package:madar_application/madar_application.dart';

import '../sales/sales_workflow_session_test.dart' show fixture;
import '../sales/source_sales_completion_test.dart' show RefundAckStore;

const accepted = 'test:owner-accepted-debt-counter';
const codec = PortableJournalCodec();

Future<(dynamic, DocumentSnapshot)> seed({bool importedDebt = false}) async {
  final (store, snapshot) = await fixture();
  final state = codec.decodeState(snapshot.payload);
  final raw = <String, Object?>{...state.account.toJson()};
  raw['suppliers'] = <Map<String, Object?>>[
    {
      'id': 'supplier',
      'name': 'Supplier',
      'phone': '',
      'note': '',
      'openingBalance': 0,
      'categoryId': 'samoon',
    },
  ];
  if (importedDebt) {
    raw['debts'] = <Map<String, Object?>>[
      {
        'id': 'legacy',
        'supplierId': 'supplier',
        'date': '2026-11-07',
        'amount': 1000,
        'note': '',
        'createdAt': '2026-11-07T00:00:00Z',
      },
    ];
  }
  final written = await store.writeDocument(
    codec.encodeState(
      state.copyWith(account: const LegacyAccountCodec().decodeJson(raw)),
    ),
    expected: snapshot,
    writeToken: 'supplier-seed',
  );
  return (store, (written as CapabilitySuccess<DocumentSnapshot>).value);
}

AdditionalDebtCommand create(AdditionalDebtController c) => c.capture(
  operationId: 'debt-create',
  debtId: 'debt',
  supplierId: 'supplier',
  date: '2026-11-07',
  amount: BigInt.from(1000),
  note: ' Original ',
  recordedAt: '2026-11-07T10:00:00Z',
);

void main() {
  test('deleted debt undo restores exact source order with one posting and exact unknown retry', () async {
    final (inner, initial) = await seed(importedDebt: true);
    final store = RefundAckStore(inner);
    final c = AdditionalDebtController(
      store: store,
      snapshot: initial,
      acceptedCounterAccountId: accepted,
      isWriteBlocked: () => false,
    );
    addTearDown(c.dispose);
    final first = create(c);
    expect(await c.submit(first), isA<DurableCommandSuccess>());
    final sibling = c.capture(
      operationId: 'sibling-create',
      debtId: 'sibling',
      supplierId: 'supplier',
      date: '2026-11-07',
      amount: BigInt.from(200),
      recordedAt: '2026-11-07T11:00:00Z',
    );
    expect(await c.submit(sibling), isA<DurableCommandSuccess>());
    final before = codec.decodeState(c.snapshot.payload);
    final deleted = c.capture(
      kind: 'delete',
      operationId: 'restore-delete',
      debtId: 'debt',
      reason: 'Mistaken removal',
      recordedAt: '2026-11-08T10:00:00Z',
    );
    expect(await c.submit(deleted), isA<DurableCommandSuccess>());
    final after = codec.decodeState(c.snapshot.payload);
    final undo = AdditionalDebtSessionUndoAdapter(
      controller: c,
      identity: deleted.identity,
    ).prepare(before: before, after: after, current: after);
    store.loseNext = true;
    expect(await undo.execute!(), isA<DurableCommandFailure>());
    expect(c.needsReadback, isTrue);
    final writes = inner.writes;
    store.blocked = false;
    expect(await undo.execute!(), isA<DurableCommandReplayed>());
    expect(inner.writes, writes);
    final restored = codec.decodeState(c.snapshot.payload);
    expect(
      restored.account.toJson()['debts'],
      before.account.toJson()['debts'],
    );
    expect(restored.journals.length, after.journals.length + 1);
    final posting = restored.journals.last;
    expect(posting.journal.reversesId, isNull);
    expect(posting.correctedFromJournalId, 'debt-create:debt');
    expect(
      posting.metadata['restoresDeletion'],
      deleted.identity.canonicalPayloadIdentity,
    );
    for (final old in [first, deleted]) {
      expect(await c.submit(old), isA<DurableCommandReplayed>());
    }
    final edit = c.capture(
      kind: 'edit',
      operationId: 'restored-edit',
      debtId: 'debt',
      date: '2026-11-08',
      amount: BigInt.from(800),
      note: 'Restored then corrected',
      reason: 'Correct after restoration',
      recordedAt: '2026-11-08T11:00:00Z',
    );
    expect(await c.submit(edit), isA<DurableCommandSuccess>());
    final remove = c.capture(
      kind: 'delete',
      operationId: 'restored-delete-again',
      debtId: 'debt',
      reason: 'Remove after correction',
      recordedAt: '2026-11-08T12:00:00Z',
    );
    expect(await c.submit(remove), isA<DurableCommandSuccess>());
    expect(await c.submit(first), isA<DurableCommandReplayed>());
    expect(await c.submit(deleted), isA<DurableCommandReplayed>());
    expect(await c.submit(edit), isA<DurableCommandReplayed>());
    expect(await c.submit(remove), isA<DurableCommandReplayed>());
  });

  test(
    'mixed unposted debt cannot mask corrections below recognized settlements',
    () async {
      final (store, initial) = await seed(importedDebt: true);
      final initialState = codec.decodeState(initial.payload);
      final raw = <String, Object?>{...initialState.account.toJson()};
      raw['suppliers'] = [
        ...(raw['suppliers']! as List),
        <String, Object?>{
          'id': 'other',
          'name': 'Other supplier',
          'phone': '',
          'note': '',
          'openingBalance': 0,
          'categoryId': 'samoon',
        },
      ];
      final seeded = await store.writeDocument(
        codec.encodeState(
          initialState.copyWith(
            account: const LegacyAccountCodec().decodeJson(raw),
          ),
        ),
        expected: initial,
        writeToken: 'second-supplier',
      );
      final c = AdditionalDebtController(
        store: store,
        snapshot: (seeded as CapabilitySuccess<DocumentSnapshot>).value,
        acceptedCounterAccountId: accepted,
        isWriteBlocked: () => false,
      );
      addTearDown(c.dispose);
      expect(await c.submit(create(c)), isA<DurableCommandSuccess>());
      final parties = PartiesOperationsViewModel(
        store: store,
        snapshot: c.snapshot,
      );
      addTearDown(parties.dispose);
      final payment = parties.supplierPaymentIntent(
        operationId: 'mixed-settle',
        paymentId: 'mixed-payment',
        journalId: 'mixed-journal',
        supplierId: 'supplier',
        date: DateOnly.parse(
          '2026-11-08',
          minimumYear: 1000,
          maximumYear: 9999,
        ),
        amount: BigInt.from(700),
        fundingSource: FundingSource.daily,
        dailyAmount: BigInt.from(700),
        cashAmount: BigInt.zero,
        recordedAt: '2026-11-08T12:00:00Z',
      );
      expect(
        await parties.submitPayment(payment),
        isA<DurableCommandSuccess>(),
      );
      expect(
        c.acceptSnapshot(parties.snapshot),
        isA<CapabilitySuccess<void>>(),
      );
      final laterPayment = parties.supplierPaymentIntent(
        operationId: 'mixed-future-settle',
        paymentId: 'mixed-future-payment',
        journalId: 'mixed-future-journal',
        supplierId: 'supplier',
        date: DateOnly.parse(
          '2026-11-10',
          minimumYear: 1000,
          maximumYear: 9999,
        ),
        amount: BigInt.from(200),
        fundingSource: FundingSource.daily,
        dailyAmount: BigInt.from(200),
        cashAmount: BigInt.zero,
        recordedAt: '2026-11-08T13:00:00Z',
      );
      expect(
        await parties.submitPayment(laterPayment),
        isA<DurableCommandSuccess>(),
      );
      expect(
        c.acceptSnapshot(parties.snapshot),
        isA<CapabilitySuccess<void>>(),
      );
      final originalJournals = codec
          .decodeState(c.snapshot.payload)
          .journals
          .length;
      for (final scenario in [
        'delete',
        'reduce',
        'future-reservation',
        'later-date',
        'other-supplier',
      ]) {
        final command = c.capture(
          kind: scenario == 'delete' ? 'delete' : 'edit',
          operationId: 'mixed-$scenario',
          debtId: 'debt',
          supplierId: scenario == 'other-supplier' ? 'other' : 'supplier',
          date: scenario == 'delete'
              ? null
              : scenario == 'later-date'
              ? '2026-11-09'
              : '2026-11-07',
          amount: scenario == 'delete'
              ? null
              : BigInt.from(
                  scenario == 'reduce'
                      ? 600
                      : scenario == 'future-reservation'
                      ? 800
                      : 1000,
                ),
          reason: 'Correction must preserve recognized settlements',
          recordedAt: '2026-11-08T14:00:00Z',
        );
        final writes = store.writes;
        final result = await c.submit(command);
        expect(store.writes, writes, reason: scenario);
        expect(result, isA<DurableCommandFailure>(), reason: scenario);
        expect(
          (result as DurableCommandFailure).code,
          'debt_correction_exceeds_recognized_liability',
          reason: scenario,
        );
        expect(
          (c.account.toJson()['debts'] as List).singleWhere(
            (d) => d['id'] == 'debt',
          )['amount'],
          1000,
        );
        expect(
          codec.decodeState(c.snapshot.payload).journals.length,
          originalJournals,
        );
      }
      final allowed = c.capture(
        kind: 'edit',
        operationId: 'mixed-allowed',
        debtId: 'debt',
        date: '2026-11-08',
        amount: BigInt.from(900),
        note: 'Still covers settlement',
        reason: 'Reduce to recognized paid amount',
        recordedAt: '2026-11-08T15:00:00Z',
      );
      expect(await c.submit(allowed), isA<DurableCommandSuccess>());
      expect(
        (c.account.toJson()['debts'] as List).singleWhere(
          (d) => d['id'] == 'debt',
        )['amount'],
        900,
      );
    },
  );

  test('debt undo compensates edits then creation while preserving journal history', () async {
    final (store, initial) = await seed();
    final c = AdditionalDebtController(
      store: store,
      snapshot: initial,
      acceptedCounterAccountId: accepted,
      isWriteBlocked: () => false,
    );
    addTearDown(c.dispose);
    final before = codec.decodeState(initial.payload);
    final original = create(c);
    expect(await c.submit(original), isA<DurableCommandSuccess>());
    final created = codec.decodeState(c.snapshot.payload);
    final edit = c.capture(
      kind: 'edit',
      operationId: 'undo-edit-source',
      debtId: 'debt',
      date: '2026-11-08',
      amount: BigInt.from(400),
      note: 'Changed',
      reason: 'Change',
      recordedAt: '2026-11-08T10:00:00Z',
    );
    expect(await c.submit(edit), isA<DurableCommandSuccess>());
    final edited = codec.decodeState(c.snapshot.payload);
    final undoEdit = AdditionalDebtSessionUndoAdapter(
      controller: c,
      identity: edit.identity,
    ).prepare(before: created, after: edited, current: edited);
    expect(await undoEdit.execute!(), isA<DurableCommandSuccess>());
    expect((c.account.toJson()['debts'] as List).single['amount'], 1000);
    final restored = codec.decodeState(c.snapshot.payload);
    final undoCreate = AdditionalDebtSessionUndoAdapter(
      controller: c,
      identity: original.identity,
    ).prepare(before: before, after: created, current: restored);
    expect(await undoCreate.execute!(), isA<DurableCommandSuccess>());
    expect(c.account.toJson()['debts'], isEmpty);
    expect(
      codec.decodeState(c.snapshot.payload).journals.length,
      greaterThan(edited.journals.length),
    );
    expect(await c.submit(original), isA<DurableCommandReplayed>());
  });

  test(
    'source-only debt cannot authorize payment against unverified liability',
    () async {
      final (store, initial) = await seed(importedDebt: true);
      final parties = PartiesOperationsViewModel(
        store: store,
        snapshot: initial,
      );
      addTearDown(parties.dispose);
      final payment = parties.supplierPaymentIntent(
        operationId: 'unverified-settle',
        paymentId: 'unverified-payment',
        journalId: 'unverified-journal',
        supplierId: 'supplier',
        date: DateOnly.parse(
          '2026-11-08',
          minimumYear: 1000,
          maximumYear: 9999,
        ),
        amount: BigInt.from(500),
        fundingSource: FundingSource.daily,
        dailyAmount: BigInt.from(500),
        cashAmount: BigInt.zero,
        recordedAt: '2026-11-08T12:00:00Z',
      );
      final result = await parties.submitPayment(payment);
      expect(result, isA<DurableCommandFailure>());
      expect(
        (result as DurableCommandFailure).code,
        'unverified_historical_debt',
      );
      expect(parties.account.toJson()['payments'], isEmpty);
    },
  );

  test(
    'payments settle proven additional debt and reserve prior settlements',
    () async {
      final (store, initial) = await seed();
      final c = AdditionalDebtController(
        store: store,
        snapshot: initial,
        acceptedCounterAccountId: accepted,
        isWriteBlocked: () => false,
      );
      addTearDown(c.dispose);
      expect(await c.submit(create(c)), isA<DurableCommandSuccess>());
      final parties = PartiesOperationsViewModel(
        store: store,
        snapshot: c.snapshot,
      );
      addTearDown(parties.dispose);
      final payment = parties.supplierPaymentIntent(
        operationId: 'settle',
        paymentId: 'payment',
        journalId: 'settle-journal',
        supplierId: 'supplier',
        date: DateOnly.parse(
          '2026-11-08',
          minimumYear: 1000,
          maximumYear: 9999,
        ),
        amount: BigInt.from(700),
        fundingSource: FundingSource.daily,
        dailyAmount: BigInt.from(700),
        cashAmount: BigInt.zero,
        recordedAt: '2026-11-08T12:00:00Z',
      );
      expect(
        await parties.submitPayment(payment),
        isA<DurableCommandSuccess>(),
      );
      final over = parties.supplierPaymentIntent(
        operationId: 'over-settle',
        paymentId: 'payment-2',
        journalId: 'over-journal',
        supplierId: 'supplier',
        date: DateOnly.parse(
          '2026-11-08',
          minimumYear: 1000,
          maximumYear: 9999,
        ),
        amount: BigInt.from(400),
        fundingSource: FundingSource.daily,
        dailyAmount: BigInt.from(400),
        cashAmount: BigInt.zero,
        recordedAt: '2026-11-08T13:00:00Z',
      );
      expect(await parties.submitPayment(over), isA<DurableCommandFailure>());
      expect((parties.account.toJson()['payments'] as List).length, 1);
      expect(
        c.acceptSnapshot(parties.snapshot),
        isA<CapabilitySuccess<void>>(),
      );
      final delete = c.capture(
        kind: 'delete',
        operationId: 'delete-settled',
        debtId: 'debt',
        reason: 'Would overdraw liability',
        recordedAt: '2026-11-08T14:00:00Z',
      );
      expect(await c.submit(delete), isA<DurableCommandFailure>());
      expect((c.account.toJson()['debts'] as List).length, 1);
    },
  );

  test('create edit delete retains immutable postings and replays all receipts after reopen', () async {
    final (store, initial) = await seed();
    final c = AdditionalDebtController(
      store: store,
      snapshot: initial,
      acceptedCounterAccountId: accepted,
      isWriteBlocked: () => false,
    );
    addTearDown(c.dispose);
    final first = create(c);
    expect(await c.submit(first), isA<DurableCommandSuccess>());
    final edit = c.capture(
      kind: 'edit',
      operationId: 'debt-edit',
      debtId: 'debt',
      date: '2026-11-08',
      amount: BigInt.from(700),
      note: 'Revised',
      reason: 'Correction',
      recordedAt: '2026-11-08T10:00:00Z',
    );
    expect(await c.submit(edit), isA<DurableCommandSuccess>());
    final state = codec.decodeState(c.snapshot.payload);
    expect(
      state.journals
          .singleWhere((j) => j.journal.id == 'debt-edit:inverse')
          .journal
          .effectiveDate
          .toString(),
      '2026-11-07',
    );
    expect(
      (c.account.toJson()['debts'] as List).single['createdAt'],
      '2026-11-07T10:00:00Z',
    );
    final remove = c.capture(
      kind: 'delete',
      operationId: 'debt-delete',
      debtId: 'debt',
      reason: 'Mistaken debt',
      recordedAt: '2026-11-08T11:00:00Z',
    );
    expect(await c.submit(remove), isA<DurableCommandSuccess>());
    expect(c.account.toJson()['debts'], isEmpty);
    final reopened = AdditionalDebtController(
      store: store,
      snapshot: c.snapshot,
      acceptedCounterAccountId: accepted,
      isWriteBlocked: () => false,
    );
    addTearDown(reopened.dispose);
    final writes = store.writes;
    for (final command in [first, edit, remove]) {
      expect(await reopened.submit(command), isA<DurableCommandReplayed>());
    }
    expect(store.writes, writes);
    expect(
      codec.decodeState(reopened.snapshot.payload).journals.length,
      state.journals.length + 1,
    );
  });

  test(
    'unmapped debt refuses without writing even a rejection receipt',
    () async {
      final (store, initial) = await seed();
      final c = AdditionalDebtController(
        store: store,
        snapshot: initial,
        isWriteBlocked: () => false,
      );
      addTearDown(c.dispose);
      final writes = store.writes;
      final result = await c.submit(create(c));
      expect((result as DurableCommandFailure).code, 'unmapped_financial_gap');
      expect(store.writes, writes);
      expect(c.needsReadback, isFalse);
    },
  );

  test(
    'imported source debt without an original posting cannot be corrected',
    () async {
      final (store, initial) = await seed(importedDebt: true);
      final c = AdditionalDebtController(
        store: store,
        snapshot: initial,
        acceptedCounterAccountId: accepted,
        isWriteBlocked: () => false,
      );
      addTearDown(c.dispose);
      final writes = store.writes;
      expect(
        () => c.capture(
          kind: 'delete',
          operationId: 'legacy-delete',
          debtId: 'legacy',
          reason: 'Try correction',
          recordedAt: '2026-11-08T11:00:00Z',
        ),
        throwsFormatException,
      );
      expect(store.writes, writes);
    },
  );

  test(
    'unknown committed debt retries exact identity without another posting',
    () async {
      final (inner, initial) = await seed();
      final store = RefundAckStore(inner)..loseNext = true;
      final c = AdditionalDebtController(
        store: store,
        snapshot: initial,
        acceptedCounterAccountId: accepted,
        isWriteBlocked: () => false,
      );
      addTearDown(c.dispose);
      final result = await c.submit(create(c));
      expect(result, isA<DurableCommandFailure>());
      expect(c.needsReadback, isTrue);
      final writes = inner.writes;
      store.blocked = false;
      expect(await c.retry(), isA<DurableCommandReplayed>());
      expect(inner.writes, writes);
      expect(c.needsReadback, isFalse);
      expect((c.account.toJson()['debts'] as List).length, 1);
    },
  );
}
