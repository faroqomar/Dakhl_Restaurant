import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:madar_domain/madar_domain.dart';
import 'package:madar_application/madar_application.dart';
import 'package:dakhl_restaurant/accounting/daily_cash_queries.dart';
import 'package:dakhl_restaurant/accounting/restaurant_journal_mapper.dart';
import 'package:dakhl_restaurant/accounting/restaurant_journal_spending_commands.dart';
import 'package:dakhl_restaurant/accounts/account_document.dart';
import 'package:dakhl_restaurant/accounts/legacy_account_codec.dart';
import 'package:dakhl_restaurant/accounts/portable_journal_state.dart';
import 'package:dakhl_restaurant/parties/purchase_proposal.dart';

void main() {
  const legacyCodec = LegacyAccountCodec();
  final mapper = RestaurantJournalMapper();
  final cutoverDate = DateOnly.parse(
    '2026-01-01',
    minimumYear: 1000,
    maximumYear: 9999,
  );
  final postDate = DateOnly.parse(
    '2026-01-10',
    minimumYear: 1000,
    maximumYear: 9999,
  );
  final preDate = DateOnly.parse(
    '2025-12-31',
    minimumYear: 1000,
    maximumYear: 9999,
  );

  AccountDocument buildSampleAccount({
    int openingBalance = 10000,
    List<Map<String, Object?>> suppliers = const [],
    List<Map<String, Object?>> invoices = const [],
    List<Map<String, Object?>> payments = const [],
    List<Map<String, Object?>> debts = const [],
  }) {
    final raw = Map<String, Object?>.from(legacyCodec.empty().toJson());
    raw['suppliers'] = [
      {
        'id': 'supp-1',
        'name': 'المورد الأول',
        'phone': '123456',
        'note': '',
        'categoryId': 'samoon',
        'openingBalance': openingBalance,
        'materials': <Map<String, Object?>>[
          {
            'id': 'mat-1',
            'name': 'Meat',
            'unit': 'kg',
            'price': 5000,
            'archived': false,
          },
        ],
      },
      ...suppliers,
    ];
    raw['invoices'] = invoices;
    raw['payments'] = payments;
    raw['debts'] = debts;
    return legacyCodec.decodeJson(raw);
  }

  PortableJournalState buildSyntheticState({
    required AccountDocument account,
    String accountLineage = 'lineage-1',
    bool isGated = false,
    BigInt? verifiedSupplierDebt,
    List<PortableJournalEntry>? extraJournals,
  }) {
    final cutover = isGated
        ? PortableJournalCutoverState.gated()
        : PortableJournalCutoverState.established(
            cutoverDate: cutoverDate,
            openingJournalId: 'open-jnl',
          );

    final openingLines = [
      JournalLine(
        accountId: 'asset:cash:daily',
        side: JournalSide.debit,
        amountUnits: BigInt.from(100000),
        currency: 'IQD',
        scale: 0,
      ),
      if (verifiedSupplierDebt != null && verifiedSupplierDebt > BigInt.zero)
        JournalLine(
          accountId: 'liability:supplier:supp-1',
          side: JournalSide.credit,
          amountUnits: verifiedSupplierDebt,
          currency: 'IQD',
          scale: 0,
        ),
      JournalLine(
        accountId: 'equity:opening_balance',
        side: JournalSide.credit,
        amountUnits:
            BigInt.from(100000) - (verifiedSupplierDebt ?? BigInt.zero),
        currency: 'IQD',
        scale: 0,
      ),
    ];

    final openEntry = isGated
        ? null
        : PortableJournalEntry(
            journal: BalancedJournal.validate(
              id: 'open-jnl',
              effectiveDate: cutoverDate,
              policy: RestaurantJournalPolicies.opening,
              lines: openingLines,
            ),
            sourceType: RestaurantJournalSourceType.cutoverOpening.name,
            sourceRecordId: 'cutover-record',
            recordedAt: '2026-01-01T00:00:00.000Z',
          );

    return PortableJournalState(
      accountLineage: accountLineage,
      account: account,
      sourceProvenance: const PortableJournalSourceProvenance(
        sourceVersion: 11,
        enrolledAt: '2026-01-01T00:00:00.000Z',
        migrated: false,
      ),
      cutoverState: cutover,
      journals: [?openEntry, ...?extraJournals],
      receipts: const [],
    );
  }

  group('CreateOperatingExpenseCommand Unit Tests', () {
    test(
      'freezes constructor parameters and computes canonical payload identity',
      () {
        final cmd = CreateOperatingExpenseCommand(
          operationId: 'op-exp-1',
          accountLineage: 'lineage-1',
          expectedFence: const StorageFence(storeId: 's', generation: 'g'),
          expenseId: 'exp-1',
          journalId: 'jnl-exp-1',
          date: postDate,
          categoryId: 'samoon',
          amount: BigInt.from(5000),
          fundingSource: FundingSource.daily,
          recordedAt: '2026-01-10T12:00:00.000Z',
          note: '   Test note   ',
        );

        expect(cmd.commandType, 'operating_expense');
        expect(cmd.dailyAmount, BigInt.from(5000));
        expect(cmd.cashAmount, BigInt.zero);

        final decoded =
            jsonDecode(cmd.canonicalPayloadIdentity) as Map<String, Object?>;
        expect(
          decoded['note'],
          '   Test note   ',
        ); // exact note preserved in identity
        expect(decoded['amount'], '5000');
        expect(decoded['fundingSource'], 'daily');
      },
    );

    test('validates funding allocation consistency on construction', () {
      expect(
        () => CreateOperatingExpenseCommand(
          operationId: 'op-1',
          accountLineage: 'l',
          expenseId: 'e',
          journalId: 'j',
          date: postDate,
          categoryId: 'samoon',
          amount: BigInt.from(5000),
          fundingSource: FundingSource.shared,
          dailyAmount: BigInt.from(2000),
          cashAmount: BigInt.from(2000), // sums to 4000 != 5000
          recordedAt: '2026-01-10T12:00:00.000Z',
        ),
        throwsFormatException,
      );

      expect(
        () => CreateOperatingExpenseCommand(
          operationId: 'op-1',
          accountLineage: 'l',
          expenseId: 'e',
          journalId: 'j',
          date: postDate,
          categoryId: 'samoon',
          amount: BigInt.from(5000),
          fundingSource: FundingSource.daily,
          dailyAmount: BigInt.from(4000),
          cashAmount: BigInt.from(1000), // daily cannot have cashAmount
          recordedAt: '2026-01-10T12:00:00.000Z',
        ),
        throwsFormatException,
      );
    });

    test('proposal evaluation rejects date preceding cutover date', () {
      final state = buildSyntheticState(account: buildSampleAccount());
      final cmd = CreateOperatingExpenseCommand(
        operationId: 'op-1',
        accountLineage: 'lineage-1',
        expenseId: 'exp-pre',
        journalId: 'jnl-pre',
        date: preDate, // 2025-12-31 < 2026-01-01
        categoryId: 'samoon',
        amount: BigInt.from(2000),
        fundingSource: FundingSource.daily,
        recordedAt: '2025-12-31T12:00:00.000Z',
      );

      final eval = RestaurantJournalSpendingCommandCoordinator.evaluateExpense(
        command: cmd,
        state: state,
        cutoverDate: cutoverDate,
        mapper: mapper,
      );

      expect(eval.rejected, isTrue);
      expect(
        eval.rejectionCode,
        RestaurantJournalSpendingErrorCodes.preCutoverOperationRejected,
      );
    });

    test('proposal evaluation rejects non-existent category', () {
      final state = buildSyntheticState(account: buildSampleAccount());
      final cmd = CreateOperatingExpenseCommand(
        operationId: 'op-1',
        accountLineage: 'lineage-1',
        expenseId: 'exp-bad-cat',
        journalId: 'jnl-1',
        date: postDate,
        categoryId: 'non_existent_category',
        amount: BigInt.from(2000),
        fundingSource: FundingSource.daily,
        recordedAt: '2026-01-10T12:00:00.000Z',
      );

      final eval = RestaurantJournalSpendingCommandCoordinator.evaluateExpense(
        command: cmd,
        state: state,
        cutoverDate: cutoverDate,
        mapper: mapper,
      );

      expect(eval.rejected, isTrue);
      expect(
        eval.rejectionCode,
        RestaurantJournalSpendingErrorCodes.missingCategory,
      );
    });

    test('proposal evaluation rejects duplicate expenseId or journalId', () {
      final account = buildSampleAccount();
      // Add existing expense to account
      final dayMap = {
        'expenses': [
          {
            'id': 'exp-existing',
            'categoryId': 'samoon',
            'amount': 1000,
            'note': '',
            'funding': {
              'source': 'daily',
              'dailyAmount': 1000,
              'cashAmount': 0,
            },
            'createdAt': '2026-01-05T00:00:00.000Z',
          },
        ],
        'chickenUsed': 0,
        'chickenLeft': 0,
        'balance': null,
        'totalOverride': null,
        'remaining': null,
        'corrections': <Object?>[],
      };
      final raw = Map<String, Object?>.from(account.toJson());
      final days = Map<String, Object?>.from(raw['days'] as Map? ?? {});
      days['2026-01-05'] = dayMap;
      raw['days'] = days;
      final updatedAccount = legacyCodec.decodeJson(raw);
      final state = buildSyntheticState(account: updatedAccount);

      final cmd = CreateOperatingExpenseCommand(
        operationId: 'op-dup',
        accountLineage: 'lineage-1',
        expenseId: 'exp-existing',
        journalId: 'jnl-new',
        date: postDate,
        categoryId: 'samoon',
        amount: BigInt.from(2000),
        fundingSource: FundingSource.daily,
        recordedAt: '2026-01-10T12:00:00.000Z',
      );

      final eval = RestaurantJournalSpendingCommandCoordinator.evaluateExpense(
        command: cmd,
        state: state,
        cutoverDate: cutoverDate,
        mapper: mapper,
      );

      expect(eval.rejected, isTrue);
      expect(
        eval.rejectionCode,
        RestaurantJournalSpendingErrorCodes.duplicateRecordId,
      );
    });

    test('zero amount expense requires allowZeroLines policy', () {
      final state = buildSyntheticState(account: buildSampleAccount());
      final cmdWithoutZeroPolicy = CreateOperatingExpenseCommand(
        operationId: 'op-zero',
        accountLineage: 'lineage-1',
        expenseId: 'exp-zero',
        journalId: 'jnl-zero',
        date: postDate,
        categoryId: 'samoon',
        amount: BigInt.zero,
        fundingSource: FundingSource.daily,
        dailyAmount: BigInt.zero,
        cashAmount: BigInt.zero,
        recordedAt: '2026-01-10T12:00:00.000Z',
      );

      final evalReject =
          RestaurantJournalSpendingCommandCoordinator.evaluateExpense(
            command: cmdWithoutZeroPolicy,
            state: state,
            cutoverDate: cutoverDate,
            mapper: mapper,
          );
      expect(evalReject.rejected, isTrue);
      expect(evalReject.rejectionCode, 'zero_value_requires_allow_zero_policy');

      final cmdWithZeroPolicy = CreateOperatingExpenseCommand(
        operationId: 'op-zero-ok',
        accountLineage: 'lineage-1',
        expenseId: 'exp-zero-ok',
        journalId: 'jnl-zero-ok',
        date: postDate,
        categoryId: 'samoon',
        amount: BigInt.zero,
        fundingSource: FundingSource.daily,
        dailyAmount: BigInt.zero,
        cashAmount: BigInt.zero,
        recordedAt: '2026-01-10T12:00:00.000Z',
        policy: RestaurantJournalPolicies.allowZero,
      );

      final evalAccept =
          RestaurantJournalSpendingCommandCoordinator.evaluateExpense(
            command: cmdWithZeroPolicy,
            state: state,
            cutoverDate: cutoverDate,
            mapper: mapper,
          );
      expect(evalAccept.rejected, isFalse);
    });

    test('successful expense evaluation updates candidate account and records journal', () {
      final state = buildSyntheticState(account: buildSampleAccount());
      final cmd = CreateOperatingExpenseCommand(
        operationId: 'op-exp-success',
        accountLineage: 'lineage-1',
        expenseId: 'exp-succ-1',
        journalId: 'jnl-exp-succ',
        date: postDate,
        categoryId: 'samoon',
        amount: BigInt.from(15000),
        fundingSource: FundingSource.shared,
        dailyAmount: BigInt.from(10000),
        cashAmount: BigInt.from(5000),
        note: 'Flour purchase',
        recordedAt: '2026-01-10T12:00:00.000Z',
      );

      final eval = RestaurantJournalSpendingCommandCoordinator.evaluateExpense(
        command: cmd,
        state: state,
        cutoverDate: cutoverDate,
        mapper: mapper,
      );

      expect(eval.rejected, isFalse);
      final candidateState = eval.candidateState!;
      expect(candidateState.journals, hasLength(2)); // opening + expense
      final expenseEntry = candidateState.journals.last;
      expect(expenseEntry.sourceType, 'expense');
      expect(expenseEntry.journal.totalUnits, BigInt.from(15000));
      expect(expenseEntry.metadata['amount'], '15000');
      expect(expenseEntry.metadata['dailyAmount'], '10000');
      expect(expenseEntry.metadata['cashAmount'], '5000');

      // Verify visible paid spending register reflects the expense
      final statement = DailyCashQueries(candidateState.account).statement();
      expect(statement.total, BigInt.from(15000));
      expect(statement.dailyShare, BigInt.from(10000));
      expect(statement.cashShare, BigInt.from(5000));
    });
  });

  group('CreatePurchaseInvoiceCommand Unit Tests', () {
    test('computes carton and piece quantities and independent pricing', () {
      final cmd = CreatePurchaseInvoiceCommand(
        operationId: 'op-inv-1',
        accountLineage: 'lineage-1',
        invoiceId: 'inv-1',
        invoiceJournalId: 'jnl-inv-1',
        supplierId: 'supp-1',
        invoiceNumber: 'INV-101',
        date: postDate,
        lines: [
          const PurchaseLine(
            materialIdForCreation: 'mat-flour',
            name: 'Flour',
            unit: 'bag',
            quantityCartons: 2,
            quantityPieces: 5,
            priceCarton: 10000,
            pricePiece: 1000,
          ),
        ],
        recordedAt: '2026-01-10T12:00:00.000Z',
      );

      expect(cmd.commandType, 'purchase_invoice');
      expect(cmd.lines, hasLength(1));
      expect(cmd.lines.first.quantityCartons, 2);
      expect(cmd.lines.first.quantityPieces, 5);
      // 2 * 10000 + 5 * 1000 = 25000
    });

    test('unpaid invoice recognizes internal expense and supplier liability, no paid spending', () {
      final state = buildSyntheticState(account: buildSampleAccount());
      final cmd = CreatePurchaseInvoiceCommand(
        operationId: 'op-inv-unpaid',
        accountLineage: 'lineage-1',
        invoiceId: 'inv-unpaid',
        invoiceJournalId: 'jnl-inv-unpaid',
        supplierId: 'supp-1',
        invoiceNumber: 'INV-201',
        date: postDate,
        lines: [
          const PurchaseLine(
            materialIdForCreation: 'mat-oil',
            name: 'Cooking Oil',
            unit: 'can',
            quantityCartons: 1,
            quantityPieces: 0,
            priceCarton: 30000,
            pricePiece: 0,
          ),
        ],
        recordedAt: '2026-01-10T12:00:00.000Z',
      );

      final eval = RestaurantJournalSpendingCommandCoordinator.evaluateInvoice(
        command: cmd,
        state: state,
        cutoverDate: cutoverDate,
        mapper: mapper,
      );

      expect(eval.rejected, isFalse);
      final candidateState = eval.candidateState!;
      expect(candidateState.journals, hasLength(2)); // opening + invoice
      final invJournal = candidateState.journals.last;
      expect(invJournal.sourceType, 'purchaseInvoice');
      expect(invJournal.journal.totalUnits, BigInt.from(30000));

      // Invariant: Debit purchases expense, Credit supplier liability
      expect(invJournal.journal.lines[0].accountId, 'expense:purchases');
      expect(invJournal.journal.lines[0].side, JournalSide.debit);
      expect(
        invJournal.journal.lines[1].accountId,
        'liability:supplier:supp-1',
      );
      expect(invJournal.journal.lines[1].side, JournalSide.credit);

      // Invariant: unpaid invoice never creates visible paid spending
      final statement = DailyCashQueries(candidateState.account).statement();
      expect(statement.total, BigInt.zero);
      expect(statement.rows, isEmpty);
    });

    test('invoice with atomic immediate payment creates invoice, payment, and both journals without second expense', () {
      final state = buildSyntheticState(account: buildSampleAccount());
      final cmd = CreatePurchaseInvoiceCommand(
        operationId: 'op-inv-paid',
        accountLineage: 'lineage-1',
        invoiceId: 'inv-atomic',
        invoiceJournalId: 'jnl-inv-atomic',
        paymentJournalId: 'jnl-pay-atomic',
        supplierId: 'supp-1',
        invoiceNumber: 'INV-301',
        date: postDate,
        lines: [
          const PurchaseLine(
            materialIdForCreation: 'mat-sugar',
            name: 'Sugar',
            unit: 'bag',
            quantityCartons: 1,
            quantityPieces: 0,
            priceCarton: 40000,
            pricePiece: 0,
          ),
        ],
        immediatePayment: const PurchasePayment(
          id: 'pay-atomic-1',
          amount: 25000,
          source: 'daily',
        ),
        recordedAt: '2026-01-10T12:00:00.000Z',
      );

      final eval = RestaurantJournalSpendingCommandCoordinator.evaluateInvoice(
        command: cmd,
        state: state,
        cutoverDate: cutoverDate,
        mapper: mapper,
      );

      expect(eval.rejected, isFalse);
      final candidateState = eval.candidateState!;
      expect(
        candidateState.journals,
        hasLength(3),
      ); // opening + invoice + payment

      final invEntry = candidateState.journals[1];
      expect(invEntry.sourceType, 'purchaseInvoice');
      expect(invEntry.journal.totalUnits, BigInt.from(40000));
      expect(invEntry.journal.lines[0].accountId, 'expense:purchases');
      expect(invEntry.journal.lines[0].side, JournalSide.debit);
      expect(invEntry.journal.lines[1].accountId, 'liability:supplier:supp-1');
      expect(invEntry.journal.lines[1].side, JournalSide.credit);

      final payEntry = candidateState.journals[2];
      expect(payEntry.sourceType, 'supplierPayment');
      expect(payEntry.journal.totalUnits, BigInt.from(25000));
      // Invariant: payment debits supplier liability, credits cash - NO second expense
      expect(payEntry.journal.lines[0].accountId, 'liability:supplier:supp-1');
      expect(payEntry.journal.lines[0].side, JournalSide.debit);
      expect(payEntry.journal.lines[1].accountId, 'asset:cash:daily');
      expect(payEntry.journal.lines[1].side, JournalSide.credit);

      // Visible paid spending reflects ONLY the payment amount, not the unpaid remainder or the full invoice
      final statement = DailyCashQueries(candidateState.account).statement();
      expect(statement.total, BigInt.from(25000));
      expect(statement.rows, hasLength(1));
      expect(statement.rows.first['kind'], 'supplier-payment');
    });

    test('rejects immediate payment exceeding invoice total', () {
      final state = buildSyntheticState(account: buildSampleAccount());
      final cmd = CreatePurchaseInvoiceCommand(
        operationId: 'op-inv-overpay',
        accountLineage: 'lineage-1',
        invoiceId: 'inv-overpay',
        invoiceJournalId: 'jnl-inv-overpay',
        paymentJournalId: 'jnl-pay-overpay',
        supplierId: 'supp-1',
        invoiceNumber: 'INV-401',
        date: postDate,
        lines: [
          const PurchaseLine(
            materialIdForCreation: 'mat-rice',
            name: 'Rice',
            unit: 'bag',
            quantityCartons: 1,
            quantityPieces: 0,
            priceCarton: 10000,
            pricePiece: 0,
          ),
        ],
        immediatePayment: const PurchasePayment(
          id: 'pay-over-1',
          amount: 15000, // exceeds invoice total (10000)
          source: 'daily',
        ),
        recordedAt: '2026-01-10T12:00:00.000Z',
      );

      final eval = RestaurantJournalSpendingCommandCoordinator.evaluateInvoice(
        command: cmd,
        state: state,
        cutoverDate: cutoverDate,
        mapper: mapper,
      );

      expect(eval.rejected, isTrue);
      expect(
        eval.rejectionCode,
        RestaurantJournalSpendingErrorCodes.paymentExceedsLiability,
      );
    });
  });

  group('CreateSupplierPaymentCommand Unit Tests', () {
    test('settling post-cutover invoice allocates to invoice liability without second expense', () {
      final invoice = {
        'id': 'inv-post',
        'supplierId': 'supp-1',
        'number': 'INV-501',
        'date': '2026-01-05',
        'lines': [
          {
            'materialId': 'mat-1',
            'name': 'Meat',
            'unit': 'kg',
            'quantityCartons': 0,
            'quantityPieces': 10,
            'priceCarton': 0,
            'pricePiece': 5000,
            'quantity': 10,
            'price': 5000,
          },
        ],
        'note': '',
        'createdAt': '2026-01-05T00:00:00.000Z',
      };

      final invoiceJournal = PortableJournalEntry(
        journal: BalancedJournal.validate(
          id: 'jnl-inv-post',
          effectiveDate: DateOnly.parse(
            '2026-01-05',
            minimumYear: 1000,
            maximumYear: 9999,
          ),
          policy: RestaurantJournalPolicies.standard,
          lines: [
            JournalLine(
              accountId: 'expense:purchases',
              side: JournalSide.debit,
              amountUnits: BigInt.from(50000),
              currency: 'IQD',
              scale: 0,
            ),
            JournalLine(
              accountId: 'liability:supplier:supp-1',
              side: JournalSide.credit,
              amountUnits: BigInt.from(50000),
              currency: 'IQD',
              scale: 0,
            ),
          ],
        ),
        sourceType: RestaurantJournalSourceType.purchaseInvoice.name,
        sourceRecordId: 'inv-post',
        recordedAt: '2026-01-05T00:00:00.000Z',
      );

      final state = buildSyntheticState(
        account: buildSampleAccount(invoices: [invoice]),
        extraJournals: [invoiceJournal],
      );

      final cmd = CreateSupplierPaymentCommand(
        operationId: 'op-pay-inv',
        accountLineage: 'lineage-1',
        paymentId: 'pay-inv-1',
        journalId: 'jnl-pay-inv-1',
        supplierId: 'supp-1',
        invoiceId: 'inv-post',
        date: postDate,
        amount: BigInt.from(30000),
        fundingSource: FundingSource.daily,
        recordedAt: '2026-01-10T12:00:00.000Z',
      );

      final eval = RestaurantJournalSpendingCommandCoordinator.evaluatePayment(
        command: cmd,
        state: state,
        cutoverDate: cutoverDate,
        mapper: mapper,
      );

      expect(eval.rejected, isFalse);
      final candidateState = eval.candidateState!;
      final payEntry = candidateState.journals.last;
      expect(payEntry.sourceType, 'supplierPayment');
      expect(payEntry.journal.lines[0].accountId, 'liability:supplier:supp-1');
      expect(payEntry.journal.lines[0].side, JournalSide.debit);
      expect(payEntry.journal.lines[1].accountId, 'asset:cash:daily');
      expect(payEntry.journal.lines[1].side, JournalSide.credit);

      final statement = DailyCashQueries(candidateState.account).statement();
      expect(statement.total, BigInt.from(30000));
      expect(statement.rows.single['kind'], 'supplier-payment');
    });

    test(
      'cross-cutover gate rejects target invoice lacking post-cutover journal',
      () {
        final preCutoverInvoice = {
          'id': 'inv-pre',
          'supplierId': 'supp-1',
          'number': 'INV-PRE-1',
          'date': '2025-12-25',
          'lines': [
            {
              'materialId': 'mat-1',
              'name': 'Meat',
              'unit': 'kg',
              'quantityCartons': 0,
              'quantityPieces': 2,
              'priceCarton': 0,
              'pricePiece': 5000,
              'quantity': 2,
              'price': 5000,
            },
          ],
          'note': '',
          'createdAt': '2025-12-25T00:00:00.000Z',
        };

        // Notice: NO post-cutover journal added for inv-pre
        final state = buildSyntheticState(
          account: buildSampleAccount(invoices: [preCutoverInvoice]),
        );

        final cmd = CreateSupplierPaymentCommand(
          operationId: 'op-pay-cross',
          accountLineage: 'lineage-1',
          paymentId: 'pay-cross-1',
          journalId: 'jnl-pay-cross-1',
          supplierId: 'supp-1',
          invoiceId: 'inv-pre',
          date: postDate,
          amount: BigInt.from(10000),
          fundingSource: FundingSource.daily,
          recordedAt: '2026-01-10T12:00:00.000Z',
        );

        final eval =
            RestaurantJournalSpendingCommandCoordinator.evaluatePayment(
              command: cmd,
              state: state,
              cutoverDate: cutoverDate,
              mapper: mapper,
            );

        expect(eval.rejected, isTrue);
        expect(
          eval.rejectionCode,
          RestaurantJournalSpendingErrorCodes
              .crossCutoverSourceHasNoPostCutoverJournal,
        );
      },
    );

    test('historical debt payment without verified opening liability is rejected', () {
      // Synthetic state where opening journal has ZERO verified debt for supp-1
      final state = buildSyntheticState(
        account: buildSampleAccount(),
        verifiedSupplierDebt: BigInt.zero, // no verified opening liability!
      );

      final cmd = CreateSupplierPaymentCommand(
        operationId: 'op-pay-unverified-debt',
        accountLineage: 'lineage-1',
        paymentId: 'pay-unverified-1',
        journalId: 'jnl-pay-unverified',
        supplierId: 'supp-1',
        invoiceId: null, // paying general debt
        date: postDate,
        amount: BigInt.from(5000),
        fundingSource: FundingSource.daily,
        recordedAt: '2026-01-10T12:00:00.000Z',
      );

      final eval = RestaurantJournalSpendingCommandCoordinator.evaluatePayment(
        command: cmd,
        state: state,
        cutoverDate: cutoverDate,
        mapper: mapper,
      );

      expect(eval.rejected, isTrue);
      expect(
        eval.rejectionCode,
        RestaurantJournalSpendingErrorCodes.unverifiedHistoricalDebt,
      );
    });

    test('historical debt payment with verified opening liability succeeds up to verified amount', () {
      // Opening journal verified 20,000 IQD opening debt for supp-1
      final state = buildSyntheticState(
        account: buildSampleAccount(openingBalance: 20000),
        verifiedSupplierDebt: BigInt.from(20000),
      );

      final cmdValid = CreateSupplierPaymentCommand(
        operationId: 'op-pay-verified-debt',
        accountLineage: 'lineage-1',
        paymentId: 'pay-verified-1',
        journalId: 'jnl-pay-verified-1',
        supplierId: 'supp-1',
        invoiceId: null,
        date: postDate,
        amount: BigInt.from(12000), // <= 20000 verified debt
        fundingSource: FundingSource.daily,
        recordedAt: '2026-01-10T12:00:00.000Z',
      );

      final evalValid =
          RestaurantJournalSpendingCommandCoordinator.evaluatePayment(
            command: cmdValid,
            state: state,
            cutoverDate: cutoverDate,
            mapper: mapper,
          );
      expect(evalValid.rejected, isFalse);

      final cmdOverpay = CreateSupplierPaymentCommand(
        operationId: 'op-pay-overpay-debt',
        accountLineage: 'lineage-1',
        paymentId: 'pay-overpay-1',
        journalId: 'jnl-pay-overpay-1',
        supplierId: 'supp-1',
        invoiceId: null,
        date: postDate,
        amount: BigInt.from(25000), // > 20000 verified debt!
        fundingSource: FundingSource.daily,
        recordedAt: '2026-01-10T12:00:00.000Z',
      );

      final evalOverpay =
          RestaurantJournalSpendingCommandCoordinator.evaluatePayment(
            command: cmdOverpay,
            state: state,
            cutoverDate: cutoverDate,
            mapper: mapper,
          );
      expect(evalOverpay.rejected, isTrue);
      expect(
        evalOverpay.rejectionCode,
        RestaurantJournalSpendingErrorCodes.paymentExceedsLiability,
      );
    });
  });

  group('RestaurantJournalSpendingOutcome Tests', () {
    test('roundtrips payload cleanly and preserves metadata equality', () {
      final outcome = RestaurantJournalSpendingOutcome(
        commandType: 'purchase_invoice',
        operationId: 'op-out-1',
        invoiceId: 'inv-1',
        invoiceNumber: 'INV-101',
        supplierId: 'supp-1',
        paymentId: 'pay-1',
        journalId: 'jnl-1',
        paymentJournalId: 'jnl-pay-1',
        effectiveDate: '2026-01-10',
        netAmount: '25000',
        metadata: {'key': 'val', 'count': 42},
      );

      final payload = outcome.toOutcomePayload();
      final roundtripped = RestaurantJournalSpendingOutcome.fromOutcomePayload(
        payload,
      );

      expect(roundtripped, equals(outcome));
      expect(roundtripped.hashCode, equals(outcome.hashCode));
      expect(roundtripped.toString(), contains('redacted'));
      expect(roundtripped.toString(), isNot(contains('25000')));
    });

    test('rejects unexpected keys in payload', () {
      final badPayload = jsonEncode({
        'commandType': 'operating_expense',
        'operationId': 'op-1',
        'journalId': 'jnl-1',
        'effectiveDate': '2026-01-10',
        'netAmount': '1000',
        'unsupportedKey': 'malicious',
      });

      expect(
        () => RestaurantJournalSpendingOutcome.fromOutcomePayload(badPayload),
        throwsFormatException,
      );
    });
  });
}
