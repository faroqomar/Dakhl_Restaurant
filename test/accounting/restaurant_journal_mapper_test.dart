import 'package:flutter_test/flutter_test.dart';
import 'package:madar_domain/madar_domain.dart';
import 'package:dakhl_restaurant/accounting/restaurant_journal_mapper.dart';

void main() {
  const profile = RestaurantAccountProfile();
  final mapper = RestaurantJournalMapper(profile: profile);

  final date20261101 = DateOnly.parse(
    '2026-11-01',
    minimumYear: 1000,
    maximumYear: 9999,
  );
  final date20261102 = DateOnly.parse(
    '2026-11-02',
    minimumYear: 1000,
    maximumYear: 9999,
  );

  group('Scenario 1: Sale Ticket Mapping (Net R1)', () {
    test('12,000 net ticket (13,000 gross / 1,000 discount) maps to net revenue and daily cash', () {
      final proposal = mapper.mapSaleTicket(
        journalId: 'jnl_sale_20261101_001',
        saleId: 'sal_001',
        receiptNumber: 'REC-1001',
        effectiveDate: date20261101,
        grossAmount: BigInt.from(13000),
        discountAmount: BigInt.from(1000),
        netAmount: BigInt.from(12000),
      );

      expect(proposal.sourceType, RestaurantJournalSourceType.sale);
      expect(proposal.sourceRecordId, 'sal_001');
      expect(proposal.receiptNumber, 'REC-1001');
      expect(proposal.metadata['gross'], BigInt.from(13000));
      expect(proposal.metadata['discount'], BigInt.from(1000));
      expect(proposal.metadata['net'], BigInt.from(12000));

      final journal = proposal.journal;
      expect(journal.id, 'jnl_sale_20261101_001');
      expect(journal.effectiveDate, date20261101);
      expect(journal.totalUnits, BigInt.from(12000));
      expect(journal.lines.length, 2);

      final debitLine = journal.lines.firstWhere(
        (l) => l.side == JournalSide.debit,
      );
      expect(debitLine.accountId, profile.dailyCashAccountId);
      expect(debitLine.amountUnits, BigInt.from(12000));

      final creditLine = journal.lines.firstWhere(
        (l) => l.side == JournalSide.credit,
      );
      expect(creditLine.accountId, profile.salesRevenueAccountId);
      expect(creditLine.amountUnits, BigInt.from(12000));
    });

    test('rejects sale with inconsistent net calculation or negative net', () {
      expect(
        () => mapper.mapSaleTicket(
          journalId: 'jnl_sale_bad',
          saleId: 'sal_bad',
          receiptNumber: 'REC-BAD',
          effectiveDate: date20261101,
          grossAmount: BigInt.from(13000),
          discountAmount: BigInt.from(1000),
          netAmount: BigInt.from(11500), // inconsistent with 13000 - 1000
        ),
        throwsA(isA<RestaurantJournalMappingException>()),
      );

      expect(
        () => mapper.mapSaleTicket(
          journalId: 'jnl_sale_bad_disc',
          saleId: 'sal_bad_disc',
          receiptNumber: 'REC-BAD2',
          effectiveDate: date20261101,
          grossAmount: BigInt.from(5000),
          discountAmount: BigInt.from(6000), // discount > gross
          netAmount: BigInt.from(-1000),
        ),
        throwsA(isA<RestaurantJournalMappingException>()),
      );
    });
  });

  group('Scenario 2: Shared Operating Expense', () {
    test('30,000 expense split 20k daily drawer / 10k cashbox safe debits category and credits both cash assets', () {
      final proposal = mapper.mapOperatingExpense(
        journalId: 'jnl_exp_20261101_002',
        expenseId: 'exp_002',
        effectiveDate: date20261101,
        categoryId: 'market',
        amount: BigInt.from(30000),
        dailyAmount: BigInt.from(20000),
        cashboxAmount: BigInt.from(10000),
      );

      expect(proposal.sourceType, RestaurantJournalSourceType.expense);
      expect(proposal.sourceRecordId, 'exp_002');
      final journal = proposal.journal;
      expect(journal.totalUnits, BigInt.from(30000));
      expect(journal.lines.length, 3);

      final debitLine = journal.lines.firstWhere(
        (l) => l.side == JournalSide.debit,
      );
      expect(debitLine.accountId, profile.categoryExpenseAccountId('market'));
      expect(debitLine.amountUnits, BigInt.from(30000));

      final creditDaily = journal.lines.firstWhere(
        (l) =>
            l.side == JournalSide.credit &&
            l.accountId == profile.dailyCashAccountId,
      );
      expect(creditDaily.amountUnits, BigInt.from(20000));

      final creditCashbox = journal.lines.firstWhere(
        (l) =>
            l.side == JournalSide.credit &&
            l.accountId == profile.cashboxAccountId,
      );
      expect(creditCashbox.amountUnits, BigInt.from(10000));
    });

    test('100% daily or 100% cashbox expense creates exactly 2 lines', () {
      final dailyOnly = mapper.mapOperatingExpense(
        journalId: 'jnl_exp_daily',
        expenseId: 'exp_daily',
        effectiveDate: date20261101,
        categoryId: 'rent',
        amount: BigInt.from(50000),
        dailyAmount: BigInt.from(50000),
        cashboxAmount: BigInt.zero,
      );
      expect(dailyOnly.journal.lines.length, 2);
      expect(dailyOnly.journal.totalUnits, BigInt.from(50000));

      final cashboxOnly = mapper.mapOperatingExpense(
        journalId: 'jnl_exp_cashbox',
        expenseId: 'exp_cashbox',
        effectiveDate: date20261101,
        categoryId: 'rent',
        amount: BigInt.from(50000),
        dailyAmount: BigInt.zero,
        cashboxAmount: BigInt.from(50000),
      );
      expect(cashboxOnly.journal.lines.length, 2);
      expect(cashboxOnly.journal.totalUnits, BigInt.from(50000));
    });

    test('rejects mismatched funding allocation', () {
      expect(
        () => mapper.mapOperatingExpense(
          journalId: 'jnl_exp_bad',
          expenseId: 'exp_bad',
          effectiveDate: date20261101,
          categoryId: 'market',
          amount: BigInt.from(30000),
          dailyAmount: BigInt.from(20000),
          cashboxAmount: BigInt.from(9000), // sum is 29000 != 30000
        ),
        throwsA(isA<RestaurantJournalMappingException>()),
      );
    });
  });

  group('Scenario 3: Unpaid Purchase Invoice (1A-P)', () {
    test('87,500 invoice debt without cash or paid expense debits purchases expense and credits supplier liability', () {
      final proposal = mapper.mapPurchaseInvoice(
        journalId: 'jnl_inv_20261101_003',
        invoiceId: 'inv_003',
        invoiceNumber: 'INV-SUP1-88',
        supplierId: 'SUP-1',
        effectiveDate: date20261101,
        amount: BigInt.from(87500),
      );

      expect(proposal.sourceType, RestaurantJournalSourceType.purchaseInvoice);
      expect(proposal.sourceRecordId, 'inv_003');
      expect(proposal.metadata['invoiceNumber'], 'INV-SUP1-88');
      expect(proposal.metadata['supplierId'], 'SUP-1');

      final journal = proposal.journal;
      expect(journal.totalUnits, BigInt.from(87500));
      expect(journal.lines.length, 2);

      final debitLine = journal.lines.firstWhere(
        (l) => l.side == JournalSide.debit,
      );
      expect(debitLine.accountId, profile.purchasesExpenseAccountId);
      expect(debitLine.amountUnits, BigInt.from(87500));

      final creditLine = journal.lines.firstWhere(
        (l) => l.side == JournalSide.credit,
      );
      expect(creditLine.accountId, profile.supplierLiabilityAccountId('SUP-1'));
      expect(creditLine.amountUnits, BigInt.from(87500));

      // Invariant: No cash accounts involved in unpaid invoice journal
      expect(
        journal.lines.any(
          (l) =>
              l.accountId == profile.dailyCashAccountId ||
              l.accountId == profile.cashboxAccountId,
        ),
        isFalse,
      );
    });
  });

  group('Scenario 4: Supplier Payment Settlement', () {
    test('separate 20,000 payment selected invoice 12.5k / debt 7.5k funded 15k/5k with NO second purchase-expense recognition', () {
      final proposal = mapper.mapSupplierPayment(
        journalId: 'jnl_pay_20261101_004',
        paymentId: 'pay_004',
        supplierId: 'SUP-1',
        effectiveDate: date20261101,
        amount: BigInt.from(20000),
        dailyAmount: BigInt.from(15000),
        cashboxAmount: BigInt.from(5000),
        invoiceSettledAmount: BigInt.from(12500),
        debtSettledAmount: BigInt.from(7500),
        invoiceId: 'inv_003',
      );

      expect(proposal.sourceType, RestaurantJournalSourceType.supplierPayment);
      expect(proposal.sourceRecordId, 'pay_004');
      expect(proposal.metadata['invoiceSettledAmount'], BigInt.from(12500));
      expect(proposal.metadata['debtSettledAmount'], BigInt.from(7500));

      final journal = proposal.journal;
      expect(journal.totalUnits, BigInt.from(20000));
      expect(journal.lines.length, 3);

      final debitLine = journal.lines.firstWhere(
        (l) => l.side == JournalSide.debit,
      );
      expect(debitLine.accountId, profile.supplierLiabilityAccountId('SUP-1'));
      expect(debitLine.amountUnits, BigInt.from(20000));

      final creditDaily = journal.lines.firstWhere(
        (l) =>
            l.side == JournalSide.credit &&
            l.accountId == profile.dailyCashAccountId,
      );
      expect(creditDaily.amountUnits, BigInt.from(15000));

      final creditCashbox = journal.lines.firstWhere(
        (l) =>
            l.side == JournalSide.credit &&
            l.accountId == profile.cashboxAccountId,
      );
      expect(creditCashbox.amountUnits, BigInt.from(5000));

      // Strict Invariant: NO second purchase-expense recognized at payment
      expect(
        journal.lines.any(
          (l) => l.accountId == profile.purchasesExpenseAccountId,
        ),
        isFalse,
        reason: 'Purchases expense must not be recognized a second time at payment settlement',
      );
    });

    test('rejects mismatched settlement or funding sum', () {
      expect(
        () => mapper.mapSupplierPayment(
          journalId: 'jnl_pay_bad',
          paymentId: 'pay_bad',
          supplierId: 'SUP-1',
          effectiveDate: date20261101,
          amount: BigInt.from(20000),
          dailyAmount: BigInt.from(15000),
          cashboxAmount: BigInt.from(5000),
          invoiceSettledAmount: BigInt.from(12000),
          debtSettledAmount: BigInt.from(7000), // sum 19000 != 20000
        ),
        throwsA(isA<RestaurantJournalMappingException>()),
      );
    });
  });

  group('Scenario 5: Customer Sales Return (Refund T1)', () {
    test('1,000 refund on return-date debits sales-return contra-revenue and credits daily cash', () {
      final proposal = mapper.mapSaleReturn(
        journalId: 'jnl_ret_20261102_005',
        returnId: 'ret_005',
        originalSaleId: 'sal_001',
        returnDate: date20261102,
        amount: BigInt.from(1000),
        reason: 'Customer return of 1 unit',
      );

      expect(proposal.sourceType, RestaurantJournalSourceType.saleReturn);
      expect(proposal.sourceRecordId, 'ret_005');
      expect(proposal.metadata['originalSaleId'], 'sal_001');

      final journal = proposal.journal;
      expect(journal.effectiveDate, date20261102); // on return date!
      expect(journal.totalUnits, BigInt.from(1000));
      expect(journal.lines.length, 2);

      final debitLine = journal.lines.firstWhere(
        (l) => l.side == JournalSide.debit,
      );
      expect(debitLine.accountId, profile.salesReturnContraAccountId);
      expect(debitLine.amountUnits, BigInt.from(1000));

      final creditLine = journal.lines.firstWhere(
        (l) => l.side == JournalSide.credit,
      );
      expect(creditLine.accountId, profile.dailyCashAccountId);
      expect(creditLine.amountUnits, BigInt.from(1000));

      // Invariant: no expense account and no cashbox deduction
      expect(
        journal.lines.any(
          (l) =>
              l.accountId == profile.cashboxAccountId ||
              l.accountId.startsWith('expense:'),
        ),
        isFalse,
      );
    });
  });

  group('Scenario 6: Daily Register to Cashbox Transfer', () {
    test('20,000 transfer from daily drawer to cashbox debits cashbox and credits daily with no expense', () {
      final proposal = mapper.mapDailyToCashboxTransfer(
        journalId: 'jnl_xfer_20261102_006',
        transferId: 'xfer_006',
        effectiveDate: date20261102,
        amount: BigInt.from(20000),
      );

      expect(proposal.sourceType, RestaurantJournalSourceType.cashboxTransfer);
      expect(proposal.sourceRecordId, 'xfer_006');

      final journal = proposal.journal;
      expect(journal.totalUnits, BigInt.from(20000));
      expect(journal.lines.length, 2);

      final debitLine = journal.lines.firstWhere(
        (l) => l.side == JournalSide.debit,
      );
      expect(debitLine.accountId, profile.cashboxAccountId);
      expect(debitLine.amountUnits, BigInt.from(20000));

      final creditLine = journal.lines.firstWhere(
        (l) => l.side == JournalSide.credit,
      );
      expect(creditLine.accountId, profile.dailyCashAccountId);
      expect(creditLine.amountUnits, BigInt.from(20000));

      // Invariant: no expense account involved
      expect(
        journal.lines.any((l) => l.accountId.startsWith('expense:')),
        isFalse,
      );
    });
  });

  group('Scenario 7: Eligible Original-Date Void / Reversal (3A)', () {
    test('original-date void retains receipt, reverses on original date, and requires eligibility', () {
      final saleProposal = mapper.mapSaleTicket(
        journalId: 'jnl_sale_20261101_001',
        saleId: 'sal_001',
        receiptNumber: 'REC-1001',
        effectiveDate: date20261101,
        grossAmount: BigInt.from(13000),
        discountAmount: BigInt.from(1000),
        netAmount: BigInt.from(12000),
      );

      final voidProposal = mapper.mapOriginalDateVoid(
        originalProposal: saleProposal,
        reversalJournalId: 'jnl_void_20261101_001',
        reason: 'Cashier error void ticket',
        isEligible: true,
        voidRecordId: 'void_001',
      );

      expect(voidProposal.sourceType, RestaurantJournalSourceType.voidReversal);
      expect(voidProposal.receiptNumber, 'REC-1001'); // retains receipt number
      expect(voidProposal.sourceRecordId, 'void_001');

      final journal = voidProposal.journal;
      expect(journal.id, 'jnl_void_20261101_001');
      expect(
        journal.effectiveDate,
        date20261101,
      ); // strictly original date (3A)
      expect(journal.reversesId, 'jnl_sale_20261101_001');
      expect(journal.reason, 'Cashier error void ticket');
      expect(journal.totalUnits, BigInt.from(12000));

      // Sides are inverted:
      // Original sale was: Debit dailyCash, Credit salesRevenue
      // Reversal must be: Debit salesRevenue, Credit dailyCash
      final debitLine = journal.lines.firstWhere(
        (l) => l.side == JournalSide.debit,
      );
      expect(debitLine.accountId, profile.salesRevenueAccountId);
      expect(debitLine.amountUnits, BigInt.from(12000));

      final creditLine = journal.lines.firstWhere(
        (l) => l.side == JournalSide.credit,
      );
      expect(creditLine.accountId, profile.dailyCashAccountId);
      expect(creditLine.amountUnits, BigInt.from(12000));
    });

    test('rejects void when eligibility check fails', () {
      final saleProposal = mapper.mapSaleTicket(
        journalId: 'jnl_sale_20261101_001',
        saleId: 'sal_001',
        receiptNumber: 'REC-1001',
        effectiveDate: date20261101,
        grossAmount: BigInt.from(13000),
        discountAmount: BigInt.from(1000),
        netAmount: BigInt.from(12000),
      );

      expect(
        () => mapper.mapOriginalDateVoid(
          originalProposal: saleProposal,
          reversalJournalId: 'jnl_void_ineligible',
          reason: 'Partial return already exists',
          isEligible: false, // Ineligible!
        ),
        throwsA(
          isA<RestaurantJournalMappingException>().having(
            (e) => e.code,
            'code',
            'void_ineligible',
          ),
        ),
      );
    });
  });

  group('Scenario 8: Zero-Value Source Compatibility & Constraints', () {
    test('zero value is rejected under standard policy without allowZeroLines to prevent silent line corruption', () {
      expect(
        () => mapper.mapSaleTicket(
          journalId: 'jnl_sale_zero',
          saleId: 'sal_zero',
          receiptNumber: 'REC-ZERO',
          effectiveDate: date20261101,
          grossAmount: BigInt.from(1000),
          discountAmount: BigInt.from(1000),
          netAmount: BigInt.zero,
          policy: RestaurantJournalPolicies.standard,
        ),
        throwsA(
          isA<RestaurantJournalMappingException>().having(
            (e) => e.code,
            'code',
            'zero_value_requires_allow_zero_policy',
          ),
        ),
      );
    });

    test('zero value produces balanced zero journal when explicit policy permits zero lines', () {
      final proposal = mapper.mapSaleTicket(
        journalId: 'jnl_sale_zero_allowed',
        saleId: 'sal_zero',
        receiptNumber: 'REC-ZERO',
        effectiveDate: date20261101,
        grossAmount: BigInt.from(1000),
        discountAmount: BigInt.from(1000),
        netAmount: BigInt.zero,
        policy: RestaurantJournalPolicies.allowZero,
      );

      expect(proposal.journal.totalUnits, BigInt.zero);
      expect(proposal.journal.lines.length, 2);
      for (final line in proposal.journal.lines) {
        expect(line.amountUnits, BigInt.zero);
      }
    });
  });

  group('Scenario 9: Synthetic Cutover Context (2A)', () {
    test('verified physical cash and debts establish balanced opening journal with explicit equity residual', () {
      final openingProposal = mapper.mapVerifiedCutoverOpening(
        journalId: 'jnl_opening_cutover',
        effectiveDate: date20261101,
        verifiedPhysicalRegisterCash: BigInt.from(250000),
        verifiedCashboxBalance: BigInt.from(750000),
        verifiedSupplierDebts: {
          'SUP-1': BigInt.from(100000),
          'SUP-2': BigInt.from(200000),
        },
      );

      expect(
        openingProposal.sourceType,
        RestaurantJournalSourceType.cutoverOpening,
      );
      final journal = openingProposal.journal;
      // Total Assets = 250k + 750k = 1,000,000
      // Total Liabilities = 100k + 200k = 300,000
      // Equity residual credit = 700,000
      // Total Units = 1,000,000
      expect(journal.totalUnits, BigInt.from(1000000));

      final dailyDebit = journal.lines.firstWhere(
        (l) =>
            l.side == JournalSide.debit &&
            l.accountId == profile.dailyCashAccountId,
      );
      expect(dailyDebit.amountUnits, BigInt.from(250000));

      final cashboxDebit = journal.lines.firstWhere(
        (l) =>
            l.side == JournalSide.debit &&
            l.accountId == profile.cashboxAccountId,
      );
      expect(cashboxDebit.amountUnits, BigInt.from(750000));

      final sup1Credit = journal.lines.firstWhere(
        (l) =>
            l.side == JournalSide.credit &&
            l.accountId == profile.supplierLiabilityAccountId('SUP-1'),
      );
      expect(sup1Credit.amountUnits, BigInt.from(100000));

      final sup2Credit = journal.lines.firstWhere(
        (l) =>
            l.side == JournalSide.credit &&
            l.accountId == profile.supplierLiabilityAccountId('SUP-2'),
      );
      expect(sup2Credit.amountUnits, BigInt.from(200000));

      final equityCredit = journal.lines.firstWhere(
        (l) =>
            l.side == JournalSide.credit &&
            l.accountId == profile.openingEquityAccountId,
      );
      expect(equityCredit.amountUnits, BigInt.from(700000));
    });

    test('negative verified register cash uses positive credit units', () {
      final proposal = mapper.mapVerifiedCutoverOpening(
        journalId: 'jnl_opening_signed',
        effectiveDate: date20261101,
        verifiedPhysicalRegisterCash: BigInt.from(-1000),
        verifiedCashboxBalance: BigInt.from(50000),
        verifiedSupplierDebts: {},
      );
      final cash = proposal.journal.lines.singleWhere(
        (line) => line.accountId == profile.dailyCashAccountId,
      );
      expect(cash.side, JournalSide.credit);
      expect(cash.amountUnits, BigInt.from(1000));
      expect(proposal.metadata['equityResidual'], BigInt.from(49000));
    });
    test(
      'negative safe and total assets use positive credit and equity debit',
      () {
        final proposal = mapper.mapVerifiedCutoverOpening(
          journalId: 'jnl_opening_signed_safe',
          effectiveDate: date20261101,
          verifiedPhysicalRegisterCash: BigInt.from(2000),
          verifiedCashboxBalance: BigInt.from(-3000),
          verifiedSupplierDebts: {},
        );
        final safe = proposal.journal.lines.singleWhere(
          (line) => line.accountId == profile.cashboxAccountId,
        );
        final equity = proposal.journal.lines.singleWhere(
          (line) => line.accountId == profile.openingEquityAccountId,
        );
        expect(safe.side, JournalSide.credit);
        expect(safe.amountUnits, BigInt.from(3000));
        expect(equity.side, JournalSide.debit);
        expect(equity.amountUnits, BigInt.from(1000));
        expect(
          proposal.journal.lines.every(
            (line) => line.amountUnits >= BigInt.zero,
          ),
          true,
        );
      },
    );
  });

  group('Scenario 10: Unmapped Gap Reporting', () {
    test('unmapped external cash deposit without accepted counteraccount throws unmapped gap exception', () {
      expect(
        () => mapper.mapExternalCashAdjustment(
          journalId: 'jnl_ext_dep',
          recordId: 'ext_001',
          effectiveDate: date20261101,
          targetCashAccount: profile.dailyCashAccountId,
          amount: BigInt.from(50000),
          isDeposit: true,
          acceptedCounterAccountId: null, // No accepted counteraccount!
        ),
        throwsA(
          isA<RestaurantJournalMappingException>().having(
            (e) => e.code,
            'code',
            'unmapped_financial_gap',
          ),
        ),
      );
    });

    test('unmapped manual additional debt without accepted counteraccount throws unmapped gap exception', () {
      expect(
        () => mapper.mapManualAdditionalDebt(
          journalId: 'jnl_man_debt',
          debtId: 'debt_001',
          supplierId: 'SUP-1',
          effectiveDate: date20261101,
          amount: BigInt.from(35000),
          acceptedCounterAccountId: null, // No accepted counteraccount!
        ),
        throwsA(
          isA<RestaurantJournalMappingException>().having(
            (e) => e.code,
            'code',
            'unmapped_financial_gap',
          ),
        ),
      );
    });
  });

  group('Scenario 11: Date Correction & App Envelope Replacement', () {
    test('replacement journal links to original via app-owned correctedFromId envelope without modifying BalancedJournal contract', () {
      final originalExpense = mapper.mapOperatingExpense(
        journalId: 'jnl_exp_orig',
        expenseId: 'exp_001',
        effectiveDate: date20261101,
        categoryId: 'market',
        amount: BigInt.from(30000),
        dailyAmount: BigInt.from(20000),
        cashboxAmount: BigInt.from(10000),
      );

      final replacementExpense = mapper.mapReplacementProposal(
        newProposal: mapper.mapOperatingExpense(
          journalId: 'jnl_exp_replacement',
          expenseId: 'exp_001_v2',
          effectiveDate: date20261102, // shifted date
          categoryId: 'market',
          amount: BigInt.from(32000),
          dailyAmount: BigInt.from(22000),
          cashboxAmount: BigInt.from(10000),
        ),
        correctedFromId: originalExpense.journal.id,
      );

      expect(
        replacementExpense.sourceType,
        RestaurantJournalSourceType.correctionReplacement,
      );
      expect(replacementExpense.correctedFromId, 'jnl_exp_orig');
      expect(replacementExpense.journal.id, 'jnl_exp_replacement');
      expect(replacementExpense.journal.totalUnits, BigInt.from(32000));
      expect(replacementExpense.journal.effectiveDate, date20261102);
    });
  });
}
