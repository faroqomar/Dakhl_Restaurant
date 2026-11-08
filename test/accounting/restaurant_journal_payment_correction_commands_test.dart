import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:madar_application/madar_application.dart';
import 'package:madar_domain/madar_domain.dart';
import 'package:dakhl_restaurant/accounting/journal_command_host.dart';
import 'package:dakhl_restaurant/accounting/restaurant_journal_payment_correction_commands.dart';
import 'package:dakhl_restaurant/accounting/restaurant_journal_payment_history.dart';
import 'package:dakhl_restaurant/accounting/restaurant_journal_mapper.dart';
import 'package:dakhl_restaurant/accounting/daily_cash_queries.dart';
import 'package:dakhl_restaurant/accounts/legacy_account_codec.dart';
import 'package:dakhl_restaurant/accounts/portable_journal_state.dart';

import 'support/payment_correction_fixtures.dart';

EditSupplierPaymentCommand paymentEdit(
  PortableJournalState state, {
  StorageFence? fence = paymentFence,
  String operation = 'payment-edit',
  int payloadVersion = 1,
  String target = 'payment-journal',
  String inverse = 'payment-inverse',
  String replacement = 'payment-replacement',
  int amount = 18000,
  int invoiceAmount = 12500,
  int debtAmount = 5500,
  String day = '10',
  String category = 'market',
  String note = ' edited ',
  Map<String, Object?>? expectedSource,
  RestaurantAccountProfile profile = const RestaurantAccountProfile(),
  DateOnly? date,
}) => EditSupplierPaymentCommand(
  operationId: operation,
  payloadVersion: payloadVersion,
  accountLineage: 'lineage',
  expectedFence: fence,
  paymentId: 'payment',
  expectedActiveJournalId: target,
  expectedSource: expectedSource ?? paymentRow(state),
  inverseJournalId: inverse,
  replacementJournalId: replacement,
  supplierId: 'supplier',
  invoiceId: 'invoice',
  date: date ?? paymentDate(day),
  profile: profile,
  categoryId: category,
  amount: BigInt.from(amount),
  invoiceAmount: BigInt.from(invoiceAmount),
  debtAmount: BigInt.from(debtAmount),
  fundingSource: FundingSource.shared,
  dailyAmount: BigInt.from(amount - 5000),
  cashAmount: BigInt.from(5000),
  note: note,
  reason: ' correct payment ',
  recordedAt: '2026-01-12T12:00:00.000Z',
);
DeleteSupplierPaymentCommand paymentDelete(
  PortableJournalState state, {
  StorageFence? fence = paymentFence,
  String target = 'payment-replacement',
}) => DeleteSupplierPaymentCommand(
  operationId: 'payment-delete',
  accountLineage: 'lineage',
  expectedFence: fence,
  paymentId: 'payment',
  expectedActiveJournalId: target,
  expectedSource: paymentRow(state),
  inverseJournalId: 'payment-delete-inverse',
  reason: ' remove payment ',
  recordedAt: '2026-01-13T12:00:00.000Z',
);
PortableJournalState paymentApply(
  PortableJournalState state,
  SupplierPaymentCorrectionCommand command, {
  StorageFence fence = paymentFence,
  int? revision,
}) {
  final result = RestaurantJournalPaymentCorrectionCoordinator.evaluate(
    command: command,
    state: state,
    mapper: RestaurantJournalMapper(),
  );
  expect(result.rejected, false, reason: result.rejectionCode);
  return paymentReceipt(
    result.candidateState!,
    command.identity,
    result.outcomePayload!,
    fence: fence,
    revision: revision,
  );
}

void main() {
  test('accepted B edit and deletion preserve source/history and exact cash effects', () {
    final before = paymentPosted();
    expect(paymentRow(before)['invoiceAmount'], 12500);
    expect(paymentRow(before)['debtAmount'], 7500);
    final command = paymentEdit(before);
    final edited = paymentApply(before, command);
    expect(paymentRow(edited), {
      'id': 'payment',
      'supplierId': 'supplier',
      'invoiceId': 'invoice',
      'categoryId': 'market',
      'date': '2026-01-10',
      'amount': 18000,
      'invoiceAmount': 12500,
      'debtAmount': 5500,
      'funding': {'source': 'shared', 'dailyAmount': 13000, 'cashAmount': 5000},
      'note': 'edited',
      'createdAt': paymentStamp,
    });
    expect(
      edited.journals.take(3).map((e) => e.toJson()).toList(),
      before.journals.map((e) => e.toJson()).toList(),
    );
    expect(edited.journals[3].journal.reversesId, 'payment-journal');
    expect(edited.journals.last.journal.totalUnits, BigInt.from(18000));
    expect(
      DailyCashQueries(edited.account).statement().total,
      BigInt.from(18000),
    );
    expect(
      RestaurantJournalPaymentHistory.validate(
        state: edited,
        paymentId: 'payment',
        mapper: RestaurantJournalMapper(),
        expectedActiveJournalId: 'payment-replacement',
        initialIdentity: paymentCreate().identity,
      ),
      true,
    );
    final deleted = paymentApply(edited, paymentDelete(edited));
    expect(deleted.account.toJson()['payments'], isEmpty);
    expect(DailyCashQueries(deleted.account).statement().total, BigInt.zero);
    expect(
      RestaurantJournalPaymentHistory.validate(
        state: deleted,
        paymentId: 'payment',
        mapper: RestaurantJournalMapper(),
        initialIdentity: paymentCreate().identity,
      ),
      true,
    );
    expect(deleted.receipts.take(3).toList(), edited.receipts.toList());
  });
  test('captured source and split intent reject equal-total mutations', () {
    final before = paymentPosted();
    final result = RestaurantJournalPaymentCorrectionCoordinator.evaluate(
      command: paymentEdit(before, invoiceAmount: 12000, debtAmount: 6000),
      state: before,
      mapper: RestaurantJournalMapper(),
    );
    expect(result.rejected, true);
    expect(result.rejectionCode, 'payment_allocation_intent_mismatch');
    final source = Map<String, Object?>.from(paymentRow(before));
    source['note'] = 'forged';
    final stale = RestaurantJournalPaymentCorrectionCoordinator.evaluate(
      command: paymentEdit(before, expectedSource: source),
      state: before,
      mapper: RestaurantJournalMapper(),
    );
    expect(stale.rejected, true);
    expect(stale.rejectionCode, 'payment_source_changed');
  });
  test(
    'source input deep snapshot and identity preserve raw note and fence',
    () {
      final before = paymentPosted();
      final source =
          jsonDecode(jsonEncode(paymentRow(before))) as Map<String, Object?>;
      final command = paymentEdit(before, expectedSource: source);
      (source['funding'] as Map)['dailyAmount'] = 1;
      expect((command.expectedSource['funding'] as Map)['dailyAmount'], 15000);
      expect(
        () => (command.expectedSource['funding'] as Map)['dailyAmount'] = 2,
        throwsUnsupportedError,
      );
      expect(
        command.identity,
        isNot(paymentEdit(before, note: 'edited').identity),
      );
      expect(
        command.identity,
        isNot(paymentEdit(before, fence: null).identity),
      );
    },
  );
  test(
    'history rejects tampered terminal source and missing correction edge',
    () {
      final before = paymentPosted();
      final edited = paymentApply(before, paymentEdit(before));
      final raw = jsonDecode(
        jsonEncode(edited.account.toJson()),
      ) as Map<String, Object?>;
      (raw['payments'] as List).single['categoryId'] = 'samoon';
      final tampered = edited.copyWith(
        account: const LegacyAccountCodec().decodeJson(raw),
      );
      expect(
        RestaurantJournalPaymentHistory.validate(
          state: tampered,
          paymentId: 'payment',
          mapper: RestaurantJournalMapper(),
        ),
        false,
      );
      final missing = edited.copyWith(
        journals: edited.journals.where(
          (j) => j.journal.id != 'payment-inverse',
        ),
      );
      expect(
        RestaurantJournalPaymentHistory.validate(
          state: missing,
          paymentId: 'payment',
          mapper: RestaurantJournalMapper(),
        ),
        false,
      );
    },
  );
  test('history accepts increasing receipt sequence across a new fence revision reset', () {
    final before = paymentPosted();
    const restored = StorageFence(storeId: 'restored', generation: 'new');
    final command = paymentEdit(before, fence: restored);
    final edited = paymentApply(before, command, fence: restored, revision: 1);
    expect(
      RestaurantJournalPaymentHistory.validate(
        state: edited,
        paymentId: 'payment',
        mapper: RestaurantJournalMapper(),
      ),
      true,
    );
  });
  test('constructor rejects zero, incoherent allocations and invalid journal identity', () {
    final state = paymentPosted();
    expect(
      () => paymentEdit(state, amount: 0, invoiceAmount: 0, debtAmount: 0),
      throwsFormatException,
    );
    expect(
      () => paymentEdit(state, invoiceAmount: 12000, debtAmount: 1),
      throwsFormatException,
    );
    expect(
      () => paymentEdit(state, inverse: 'payment-journal'),
      throwsFormatException,
    );
  });
  test(
    'before-invoice date and missing authority are rejected without candidates',
    () {
      final before = paymentPosted();
      for (final command in [
        paymentEdit(before, day: '01'),
        paymentEdit(before, fence: null),
      ]) {
        final r = RestaurantJournalPaymentCorrectionCoordinator.evaluate(
          command: command,
          state: before,
          mapper: RestaurantJournalMapper(),
        );
        expect(r.rejected, true);
        expect(r.candidateState, isNull);
      }
    },
  );
  test('outcome roundtrip retains every immutable field', () {
    final before = paymentPosted();
    final r = RestaurantJournalPaymentCorrectionCoordinator.evaluate(
      command: paymentEdit(before),
      state: before,
      mapper: RestaurantJournalMapper(),
    );
    expect(r.rejected, false);
    final outcome = r.outcome!;
    expect(
      canonicalIdentity(
        RestaurantJournalPaymentCorrectionOutcome.fromOutcomePayload(
          outcome.toOutcomePayload(),
        ).toJson(),
      ),
      canonicalIdentity(outcome.toJson()),
    );
  });
  test('gated and actual pre-cutover replacements remain blocked', () {
    final state = paymentPosted();
    final command = paymentEdit(
      state,
      date: DateOnly.parse('2025-12-31', minimumYear: 1000, maximumYear: 9999),
    );
    expect(
      RestaurantJournalPaymentCorrectionCoordinator.evaluate(
        command: command,
        state: state,
        mapper: RestaurantJournalMapper(),
      ).rejectionCode,
      'pre_cutover_operation_rejected',
    );
    expect(
      RestaurantJournalPaymentCorrectionCoordinator.evaluate(
        command: paymentEdit(state),
        state: state.copyWith(
          cutoverState: PortableJournalCutoverState.gated(),
        ),
        mapper: RestaurantJournalMapper(),
      ).rejectionCode,
      'cutover_gated',
    );
  });
  test('custom chart context posts exact replacement and mismatched context rejects', () {
    const profile = RestaurantAccountProfile(
      dailyCashAccountId: 'cash:day',
      cashboxAccountId: 'cash:safe',
      supplierLiabilityPrefix: 'payable:',
    );
    final mapper = RestaurantJournalMapper(profile: profile);
    final state = paymentPosted(mapper: mapper);
    final command = paymentEdit(state, profile: profile);
    final result = RestaurantJournalPaymentCorrectionCoordinator.evaluate(
      command: command,
      state: state,
      mapper: mapper,
    );
    expect(result.rejected, false, reason: result.rejectionCode);
    expect(
      result.candidateState!.journals.last.journal.lines.map(
        (l) => l.accountId,
      ),
      containsAll(['cash:day', 'cash:safe', 'payable:supplier']),
    );
    expect(
      RestaurantJournalPaymentCorrectionCoordinator.evaluate(
        command: command,
        state: state,
        mapper: RestaurantJournalMapper(),
      ).rejectionCode,
      'payment_profile_mismatch',
    );
  });
}
