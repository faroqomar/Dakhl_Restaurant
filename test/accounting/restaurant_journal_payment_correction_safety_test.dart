import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:madar_application/madar_application.dart';
import 'package:madar_domain/madar_domain.dart';
import 'package:dakhl_restaurant/accounting/restaurant_journal_payment_correction_commands.dart';
import 'package:dakhl_restaurant/accounting/restaurant_journal_payment_history.dart';
import 'package:dakhl_restaurant/accounting/restaurant_journal_mapper.dart';
import 'package:dakhl_restaurant/accounting/restaurant_journal_spending_commands.dart';
import 'package:dakhl_restaurant/accounting/daily_cash_queries.dart';
import 'package:dakhl_restaurant/parties/purchase_proposal.dart';

import 'restaurant_journal_payment_correction_commands_test.dart' as f;
import 'support/payment_correction_fixtures.dart';

void main() {
  test(
    'frozen supplier edit/delete fixtures preserve complete source maps',
    () async {
      var state = paymentPosted();
      final oracle = jsonDecode(
        File('test/fixtures/legacy/payment_corrections.json')
            .readAsStringSync(),
      ) as Map;
      final cases = oracle['results'] as List;
      state = f.paymentApply(state, f.paymentEdit(state));
      expect(state.account.toJson(), cases[0]['account']);
      state = f.paymentApply(
        state,
        f.paymentEdit(
          state,
          operation: 'second',
          target: 'payment-replacement',
          inverse: 'second-inverse',
          replacement: 'second-replacement',
          amount: 17000,
          debtAmount: 4500,
          day: '11',
          category: 'bread',
          note: ' twice ',
        ),
      );
      expect(state.account.toJson(), cases[1]['account']);
      state = f.paymentApply(
        state,
        f.paymentDelete(state, target: 'second-replacement'),
      );
      expect(state.account.toJson(), cases[2]['account']);
      expect(
        DailyCashQueries(state.account).cashBalance.toInt(),
        cases[2]['cash'],
      );
    },
  );
  test(
    'later recognized payment remains eligible after an earlier correction',
    () {
      var state = paymentPosted();
      state = f.paymentApply(state, f.paymentEdit(state));
      final later = CreateSupplierPaymentCommand(
        operationId: 'later',
        accountLineage: 'lineage',
        expectedFence: paymentFence,
        paymentId: 'later',
        journalId: 'later-journal',
        supplierId: 'supplier',
        date: paymentDate('15'),
        amount: BigInt.from(2000),
        fundingSource: FundingSource.daily,
        recordedAt: '2026-01-15T12:00:00.000Z',
      );
      final r = RestaurantJournalSpendingCommandCoordinator.evaluatePayment(
        command: later,
        state: state,
        cutoverDate: paymentDate('01'),
        mapper: RestaurantJournalMapper(),
      );
      expect(r.rejected, false, reason: r.rejectionCode);
      state = paymentReceipt(
        r.candidateState!,
        later.identity,
        r.outcomePayload!,
      );
      final deleted = f.paymentApply(state, f.paymentDelete(state));
      expect((deleted.account.toJson()['payments'] as List).length, 1);
      expect(
        RestaurantJournalPaymentHistory.validate(
          state: deleted,
          paymentId: 'payment',
          mapper: RestaurantJournalMapper(),
        ),
        true,
      );
    },
  );
  test('future saved payments reserve capacity during earlier replacement', () {
    var state = paymentPosted();
    state = f.paymentApply(
      state,
      f.paymentEdit(state, amount: 17000, debtAmount: 4500),
    );
    final later = CreateSupplierPaymentCommand(
      operationId: 'future',
      accountLineage: 'lineage',
      expectedFence: paymentFence,
      paymentId: 'future',
      journalId: 'future-journal',
      supplierId: 'supplier',
      date: paymentDate('20'),
      amount: BigInt.from(3000),
      fundingSource: FundingSource.daily,
      recordedAt: '2026-01-20T12:00:00.000Z',
    );
    final r = RestaurantJournalSpendingCommandCoordinator.evaluatePayment(
      command: later,
      state: state,
      cutoverDate: paymentDate('01'),
      mapper: RestaurantJournalMapper(),
    );
    expect(r.rejected, false, reason: r.rejectionCode);
    state = paymentReceipt(
      r.candidateState!,
      later.identity,
      r.outcomePayload!,
    );
    final over = RestaurantJournalPaymentCorrectionCoordinator.evaluate(
      command: f.paymentEdit(
        state,
        operation: 'over',
        target: 'payment-replacement',
        inverse: 'over-inverse',
        replacement: 'over-replacement',
        amount: 18000,
        debtAmount: 5500,
      ),
      state: state,
      mapper: RestaurantJournalMapper(),
    );
    expect(over.rejected, true);
  });
  test('legacy raw payments are refused and receipt-backed inline roots are eligible', () {
    final state = paymentPosted();
    final raw =
        jsonDecode(jsonEncode(state.account.toJson())) as Map<String, Object?>;
    final missing = state.copyWith(
      journals: state.journals.where((j) => j.journal.id != 'payment-journal'),
    );
    expect(
      RestaurantJournalPaymentCorrectionCoordinator.evaluate(
        command: f.paymentEdit(missing),
        state: missing,
        mapper: RestaurantJournalMapper(),
      ).rejected,
      true,
    );
    final seed = paymentSeed();
    final command = CreatePurchaseInvoiceCommand(
      operationId: 'immediate-invoice',
      accountLineage: 'lineage',
      expectedFence: paymentFence,
      invoiceId: 'invoice',
      invoiceJournalId: 'invoice-root',
      paymentJournalId: 'immediate-root',
      supplierId: 'supplier',
      invoiceNumber: 'I-1',
      date: paymentDate('05'),
      lines: const [
        PurchaseLine(
          materialIdForCreation: 'material',
          name: 'Flour',
          unit: 'bag',
          quantityCartons: 0,
          quantityPieces: 1,
          priceCarton: 0,
          pricePiece: 12500,
        ),
      ],
      immediatePayment: const PurchasePayment(
        id: 'payment',
        amount: 12500,
        source: 'daily',
      ),
      recordedAt: paymentStamp,
    );
    final evaluated =
        RestaurantJournalSpendingCommandCoordinator.evaluateInvoice(
          command: command,
          state: seed,
          cutoverDate: paymentDate('01'),
          mapper: RestaurantJournalMapper(),
        );
    expect(evaluated.rejected, false, reason: evaluated.rejectionCode);
    final immediate = paymentReceipt(
      evaluated.candidateState!,
      command.identity,
      evaluated.outcomePayload!,
    );
    final correction = f.paymentEdit(immediate, target: 'immediate-root');
    expect(
      RestaurantJournalPaymentCorrectionCoordinator.evaluate(
        command: correction,
        state: immediate,
        mapper: RestaurantJournalMapper(),
      ).rejected,
      false,
    );
    expect(
      RestaurantJournalPaymentCorrectionCoordinator.evaluate(
        command: correction,
        state: immediate.copyWith(receipts: const []),
        mapper: RestaurantJournalMapper(),
      ).rejected,
      true,
    );
    expect(raw['payments'], isNotEmpty);
  });
  test(
    'tampered historical allocation, profile or outcome cannot reconcile',
    () {
      final original = paymentPosted();
      final edited = f.paymentApply(original, f.paymentEdit(original));
      final receipts = edited.receipts.toList();
      final old = receipts.last;
      final outcome = jsonDecode(old.outcomePayload!) as Map<String, Object?>;
      (outcome['metadata'] as Map)['afterSnapshot'] = '{}';
      receipts[receipts.length - 1] = DurableCommandReceipt(
        identity: old.identity,
        status: old.status,
        outcomePayload: jsonEncode(outcome),
        committedRevision: old.committedRevision,
        sequence: old.sequence,
        fence: old.fence,
      );
      expect(
        RestaurantJournalPaymentHistory.validate(
          state: edited.copyWith(receipts: receipts),
          paymentId: 'payment',
          mapper: RestaurantJournalMapper(),
        ),
        false,
      );
      expect(
        RestaurantJournalPaymentHistory.validate(
          state: edited,
          paymentId: 'payment',
          mapper: RestaurantJournalMapper(
            profile: const RestaurantAccountProfile(
              cashboxAccountId: 'foreign-cash',
            ),
          ),
        ),
        false,
      );
    },
  );
}
