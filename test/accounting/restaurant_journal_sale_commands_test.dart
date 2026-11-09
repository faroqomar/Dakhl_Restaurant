import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:madar_domain/madar_domain.dart';
import 'package:dakhl_restaurant/accounting/restaurant_journal_mapper.dart';
import 'package:dakhl_restaurant/accounting/restaurant_journal_sale_commands.dart';
import 'package:dakhl_restaurant/accounts/account_document.dart';
import 'package:dakhl_restaurant/accounts/legacy_account_codec.dart';
import 'package:dakhl_restaurant/accounts/portable_journal_codec.dart';
import 'package:dakhl_restaurant/accounts/portable_journal_state.dart';
import 'package:dakhl_restaurant/sales/return_proposal.dart';

void main() {
  const legacyCodec = LegacyAccountCodec();
  const codec = PortableJournalCodec();
  final mapper = RestaurantJournalMapper();

  AccountDocument buildSampleAccount() {
    final oracle = jsonDecode(
      File('test/sales/sale_proposal_oracle.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final defaultCase = (oracle['cases'] as List).first as Map<String, dynamic>;
    final stateJson = defaultCase['state'] as Map<String, dynamic>;
    return legacyCodec.decodeJson(Map<String, Object?>.from(stateJson));
  }

  DateOnly d(String iso) =>
      DateOnly.parse(iso, minimumYear: 1000, maximumYear: 9999);

  PortableJournalState buildSyntheticState({
    required AccountDocument account,
    required String accountLineage,
    bool isGated = false,
    DateOnly? cutoverDate,
    String? openingJournalId,
    List<PortableJournalEntry>? journals,
  }) {
    final cutover = isGated
        ? PortableJournalCutoverState.gated()
        : PortableJournalCutoverState.established(
            cutoverDate: cutoverDate ?? d('2026-01-01'),
            openingJournalId: openingJournalId ?? 'open-jnl-1',
          );

    final openingEntry = isGated
        ? null
        : PortableJournalEntry(
            journal: BalancedJournal.validate(
              id: openingJournalId ?? 'open-jnl-1',
              effectiveDate: cutoverDate ?? d('2026-01-01'),
              policy: RestaurantJournalPolicies.opening,
              lines: [
                JournalLine(
                  accountId: 'asset:cash:daily',
                  side: JournalSide.debit,
                  amountUnits: BigInt.from(50000),
                  currency: 'IQD',
                  scale: 0,
                ),
                JournalLine(
                  accountId: 'equity:opening_balance',
                  side: JournalSide.credit,
                  amountUnits: BigInt.from(50000),
                  currency: 'IQD',
                  scale: 0,
                ),
              ],
            ),
            sourceType: RestaurantJournalSourceType.cutoverOpening.name,
            sourceRecordId: 'cutover-record',
            recordedAt: '2026-01-01T00:00:00.000Z',
          );

    return PortableJournalState(
      accountLineage: accountLineage,
      account: account,
      sourceProvenance: PortableJournalSourceProvenance(
        sourceVersion: 11,
        enrolledAt: '2026-01-01T00:00:00.000Z',
        migrated: false,
      ),
      cutoverState: cutover,
      journals: [?openingEntry, ...?journals],
      receipts: const [],
    );
  }

  group('CompleteSaleCommand unit tests', () {
    test('freezes draft input and prevents external mutation', () {
      final mutableDraft = <String, Object?>{
        'date': '2026-01-03',
        'discount': 100,
        'lines': [
          {'productId': 'p', 'quantity': 2, 'price': 1000},
        ],
      };

      final cmd = CompleteSaleCommand(
        operationId: 'op-sale-1',
        accountLineage: 'lineage-1',
        saleId: 'sale-1',
        journalId: 'jnl-sale-1',
        draft: mutableDraft,
        recordedAt: '2026-01-03T12:00:00.000Z',
      );

      // Mutate original caller map:
      mutableDraft['discount'] = 500;
      (mutableDraft['lines']! as List).clear();

      // Command's internal copy remains unchanged:
      expect(cmd.draft['discount'], 100);
      expect((cmd.draft['lines']! as List).length, 1);

      // Direct mutation on command's draft throws UnsupportedError:
      expect(() => cmd.draft['discount'] = 999, throwsUnsupportedError);
      expect(
        () => (cmd.draft['lines']! as List).clear(),
        throwsUnsupportedError,
      );
    });

    test('deterministic canonical payload identity responds to financial and intent changes', () {
      final draft1 = {
        'date': '2026-01-03',
        'discount': 100,
        'lines': [
          {'productId': 'p', 'quantity': 2, 'price': 1000},
        ],
      };

      final cmd1 = CompleteSaleCommand(
        operationId: 'op-sale-1',
        accountLineage: 'lineage-1',
        saleId: 'sale-1',
        journalId: 'jnl-sale-1',
        draft: draft1,
        recordedAt: '2026-01-03T12:00:00.000Z',
      );

      final cmdDuplicate = CompleteSaleCommand(
        operationId: 'op-sale-1',
        accountLineage: 'lineage-1',
        saleId: 'sale-1',
        journalId: 'jnl-sale-1',
        draft: draft1,
        recordedAt: '2026-01-03T12:00:00.000Z',
      );

      expect(
        cmd1.canonicalPayloadIdentity,
        cmdDuplicate.canonicalPayloadIdentity,
      );

      // Financial change: discount
      final cmdFinancial = CompleteSaleCommand(
        operationId: 'op-sale-1',
        accountLineage: 'lineage-1',
        saleId: 'sale-1',
        journalId: 'jnl-sale-1',
        draft: {
          'date': '2026-01-03',
          'discount': 200, // changed!
          'lines': [
            {'productId': 'p', 'quantity': 2, 'price': 1000},
          ],
        },
        recordedAt: '2026-01-03T12:00:00.000Z',
      );
      expect(
        cmdFinancial.canonicalPayloadIdentity,
        isNot(cmd1.canonicalPayloadIdentity),
      );

      // Financial change: quantity
      final cmdQty = CompleteSaleCommand(
        operationId: 'op-sale-1',
        accountLineage: 'lineage-1',
        saleId: 'sale-1',
        journalId: 'jnl-sale-1',
        draft: {
          'date': '2026-01-03',
          'discount': 100,
          'lines': [
            {'productId': 'p', 'quantity': 3, 'price': 1000}, // changed!
          ],
        },
        recordedAt: '2026-01-03T12:00:00.000Z',
      );
      expect(
        cmdQty.canonicalPayloadIdentity,
        isNot(cmd1.canonicalPayloadIdentity),
      );

      // Intent change: date
      final cmdDate = CompleteSaleCommand(
        operationId: 'op-sale-1',
        accountLineage: 'lineage-1',
        saleId: 'sale-1',
        journalId: 'jnl-sale-1',
        draft: {
          'date': '2026-01-04', // changed!
          'discount': 100,
          'lines': [
            {'productId': 'p', 'quantity': 2, 'price': 1000},
          ],
        },
        recordedAt: '2026-01-03T12:00:00.000Z',
      );
      expect(
        cmdDate.canonicalPayloadIdentity,
        isNot(cmd1.canonicalPayloadIdentity),
      );

      // Version change
      final cmdVersion = CompleteSaleCommand(
        operationId: 'op-sale-1',
        payloadVersion: 2, // changed!
        accountLineage: 'lineage-1',
        saleId: 'sale-1',
        journalId: 'jnl-sale-1',
        draft: draft1,
        recordedAt: '2026-01-03T12:00:00.000Z',
      );
      expect(
        cmdVersion.canonicalPayloadIdentity,
        isNot(cmd1.canonicalPayloadIdentity),
      );
    });

    test('BigInt metadata snapshots are composed as exact decimal strings with source version and receipt links', () {
      final doc = buildSampleAccount();
      final state = buildSyntheticState(
        account: doc,
        accountLineage: 'lineage-meta',
      );

      final cmd = CompleteSaleCommand(
        operationId: 'op-meta-1',
        accountLineage: 'lineage-meta',
        saleId: 'sale-meta-1',
        journalId: 'jnl-meta-1',
        draft: {
          'date': '2026-01-03',
          'discount': 100,
          'lines': [
            {'productId': 'p', 'quantity': 2},
          ],
        },
        recordedAt: '2026-01-03T12:00:00.000Z',
      );

      final eval = RestaurantJournalSaleCommandCoordinator.evaluateSale(
        command: cmd,
        state: state,
        cutoverDate: d('2026-01-01'),
        mapper: mapper,
      );

      expect(eval.rejected, isFalse);
      final candidateState = eval.candidateState!;
      final saleEntry = candidateState.journals.last;

      expect(saleEntry.metadata['gross'], '2000');
      expect(saleEntry.metadata['discount'], '100');
      expect(saleEntry.metadata['net'], '1900');
      expect(saleEntry.metadata['sourceVersion'], 11);
      expect(saleEntry.metadata['receiptNumber'], 'S-000001');
      expect(saleEntry.metadata['operationId'], 'op-meta-1');
      expect(saleEntry.metadata['saleId'], 'sale-meta-1');

      // Check candidate state encodes cleanly to JSON without BigInt conversion error
      expect(() => codec.encodeState(candidateState), returnsNormally);
    });

    test('zero net sale is rejected under standard policy but accepted under allowZero policy', () {
      final doc = buildSampleAccount();
      final state = buildSyntheticState(
        account: doc,
        accountLineage: 'lineage-zero',
      );

      // 1000 gross - 1000 discount = 0 net
      final zeroDraft = {
        'date': '2026-01-03',
        'discount': 1000,
        'lines': [
          {'productId': 'p', 'quantity': 1},
        ],
      };

      // Under standard policy (default): rejected
      final cmdStandard = CompleteSaleCommand(
        operationId: 'op-zero-std',
        accountLineage: 'lineage-zero',
        saleId: 'sale-zero-1',
        journalId: 'jnl-zero-1',
        draft: zeroDraft,
        recordedAt: '2026-01-03T12:00:00.000Z',
      );
      final evalStandard = RestaurantJournalSaleCommandCoordinator.evaluateSale(
        command: cmdStandard,
        state: state,
        cutoverDate: d('2026-01-01'),
        mapper: mapper,
      );
      expect(evalStandard.rejected, isTrue);
      expect(
        evalStandard.rejectionCode,
        RestaurantJournalSaleErrorCodes.zeroValueRequiresAllowZeroPolicy,
      );

      // Under explicit allowZero policy: accepted
      final cmdAllowZero = CompleteSaleCommand(
        operationId: 'op-zero-allow',
        accountLineage: 'lineage-zero',
        saleId: 'sale-zero-2',
        journalId: 'jnl-zero-2',
        draft: zeroDraft,
        recordedAt: '2026-01-03T12:00:00.000Z',
        policy: RestaurantJournalPolicies.allowZero,
      );
      final evalAllow = RestaurantJournalSaleCommandCoordinator.evaluateSale(
        command: cmdAllowZero,
        state: state,
        cutoverDate: d('2026-01-01'),
        mapper: mapper,
      );
      expect(evalAllow.rejected, isFalse);
      expect(
        evalAllow.candidateState!.journals.last.journal.totalUnits,
        BigInt.zero,
      );
    });

    test('pre-cutover sale date fails closed under cross-cutover gate', () {
      final doc = buildSampleAccount();
      final state = buildSyntheticState(
        account: doc,
        accountLineage: 'lineage-cutover',
        cutoverDate: d('2026-01-02'),
      );

      final cmdPre = CompleteSaleCommand(
        operationId: 'op-pre-cutover',
        accountLineage: 'lineage-cutover',
        saleId: 'sale-pre',
        journalId: 'jnl-pre',
        draft: {
          'date': '2026-01-01', // Before cutover date 2026-01-02!
          'discount': 0,
          'lines': [
            {'productId': 'p', 'quantity': 1},
          ],
        },
        recordedAt: '2026-01-01T12:00:00.000Z',
      );

      final eval = RestaurantJournalSaleCommandCoordinator.evaluateSale(
        command: cmdPre,
        state: state,
        cutoverDate: d('2026-01-02'),
        mapper: mapper,
      );

      expect(eval.rejected, isTrue);
      expect(
        eval.rejectionCode,
        RestaurantJournalSaleErrorCodes.preCutoverOperationRejected,
      );
    });
  });

  group('SaleReturnCommand unit tests', () {
    test(
      'valid return evaluates cumulative allocation and maps return journal',
      () {
        final doc = buildSampleAccount();
        // First, post a sale of 2 units of p
        final saleCmd = CompleteSaleCommand(
          operationId: 'op-sale-for-ret',
          accountLineage: 'lineage-ret',
          saleId: 'sale-for-ret',
          journalId: 'jnl-sale-ret',
          draft: {
            'date': '2026-01-03',
            'discount': 0,
            'lines': [
              {'productId': 'p', 'quantity': 2},
            ],
          },
          recordedAt: '2026-01-03T12:00:00.000Z',
        );

        final initial = buildSyntheticState(
          account: doc,
          accountLineage: 'lineage-ret',
        );
        final saleEval = RestaurantJournalSaleCommandCoordinator.evaluateSale(
          command: saleCmd,
          state: initial,
          cutoverDate: d('2026-01-01'),
          mapper: mapper,
        );
        final stateWithSale = saleEval.candidateState!;

        // Now return 1 unit on return date 2026-01-04
        final returnCmd = SaleReturnCommand(
          operationId: 'op-return-1',
          accountLineage: 'lineage-ret',
          returnId: 'ret-1',
          saleId: 'sale-for-ret',
          journalId: 'jnl-ret-1',
          returnDate: d('2026-01-04'),
          reason: 'Customer requested refund',
          recordedAt: '2026-01-04T12:00:00.000Z',
          today: d('2026-01-04'),
          lines: [
            ReturnLineRequest(
              productId: 'p',
              quantityUnits: BigInt.from(1000), // 1 unit in milli-units
              restock: true,
            ),
          ],
        );

        final returnEval =
            RestaurantJournalSaleCommandCoordinator.evaluateReturn(
              command: returnCmd,
              state: stateWithSale,
              cutoverDate: d('2026-01-01'),
              mapper: mapper,
            );

        expect(returnEval.rejected, isFalse);
        final returnState = returnEval.candidateState!;
        final returnEntry = returnState.journals.last;
        expect(
          returnEntry.sourceType,
          RestaurantJournalSourceType.saleReturn.name,
        );
        expect(
          returnEntry.journal.effectiveDate,
          d('2026-01-04'),
        ); // return date!
        expect(returnEntry.metadata['amount'], '1000');
        expect(returnEntry.metadata['originalSaleId'], 'sale-for-ret');
        expect(returnEntry.metadata['reason'], 'Customer requested refund');
        expect(returnEntry.metadata['receiptNumber'], 'S-000001');

        // Verify debit contra revenue, credit daily cash
        final debit = returnEntry.journal.lines.firstWhere(
          (l) => l.side == JournalSide.debit,
        );
        expect(debit.accountId, 'contra_revenue:sales_return');
        expect(debit.amountUnits, BigInt.from(1000));

        final credit = returnEntry.journal.lines.firstWhere(
          (l) => l.side == JournalSide.credit,
        );
        expect(credit.accountId, 'asset:cash:daily');
        expect(credit.amountUnits, BigInt.from(1000));
      },
    );

    test('return fails closed if historical sale has no eligible post-cutover journal', () {
      final doc = buildSampleAccount();
      // An account with a sale in source records, but NO post-cutover journal in journals list
      final stateWithoutJournal = buildSyntheticState(
        account: doc,
        accountLineage: 'lineage-cross',
        cutoverDate: d('2026-01-01'),
      );

      final returnCmd = SaleReturnCommand(
        operationId: 'op-return-cross',
        accountLineage: 'lineage-cross',
        returnId: 'ret-cross',
        saleId: 'nonexistent-or-pre-cutover-sale',
        journalId: 'jnl-ret-cross',
        returnDate: d('2026-01-04'),
        reason: 'Refund',
        recordedAt: '2026-01-04T12:00:00.000Z',
        today: d('2026-01-04'),
        lines: [
          ReturnLineRequest(
            productId: 'p',
            quantityUnits: BigInt.from(1000),
            restock: false,
          ),
        ],
      );

      final eval = RestaurantJournalSaleCommandCoordinator.evaluateReturn(
        command: returnCmd,
        state: stateWithoutJournal,
        cutoverDate: d('2026-01-01'),
        mapper: mapper,
      );

      expect(eval.rejected, isTrue);
      expect(eval.rejectionCode, RestaurantJournalSaleErrorCodes.saleNotFound);
    });

    test(
      'over-return exceeding sold quantity is rejected by proposal builder',
      () {
        final doc = buildSampleAccount();
        final saleCmd = CompleteSaleCommand(
          operationId: 'op-sale-qty',
          accountLineage: 'lineage-qty',
          saleId: 'sale-qty',
          journalId: 'jnl-sale-qty',
          draft: {
            'date': '2026-01-03',
            'discount': 0,
            'lines': [
              {'productId': 'p', 'quantity': 1}, // only 1 unit sold
            ],
          },
          recordedAt: '2026-01-03T12:00:00.000Z',
        );

        final initial = buildSyntheticState(
          account: doc,
          accountLineage: 'lineage-qty',
        );
        final saleEval = RestaurantJournalSaleCommandCoordinator.evaluateSale(
          command: saleCmd,
          state: initial,
          cutoverDate: d('2026-01-01'),
          mapper: mapper,
        );
        final stateWithSale = saleEval.candidateState!;

        // Attempt to return 2 units when only 1 was sold:
        final overReturnCmd = SaleReturnCommand(
          operationId: 'op-over-ret',
          accountLineage: 'lineage-qty',
          returnId: 'ret-over',
          saleId: 'sale-qty',
          journalId: 'jnl-ret-over',
          returnDate: d('2026-01-04'),
          reason: 'Attempting excess return',
          recordedAt: '2026-01-04T12:00:00.000Z',
          today: d('2026-01-04'),
          lines: [
            ReturnLineRequest(
              productId: 'p',
              quantityUnits: BigInt.from(2000), // 2 units! Exceeds sold!
              restock: true,
            ),
          ],
        );

        final eval = RestaurantJournalSaleCommandCoordinator.evaluateReturn(
          command: overReturnCmd,
          state: stateWithSale,
          cutoverDate: d('2026-01-01'),
          mapper: mapper,
        );

        expect(eval.rejected, isTrue);
        expect(
          eval.rejectionCode,
          RestaurantJournalSaleErrorCodes.invalidReturnProposal,
        );
      },
    );
  });

  group('SaleVoidCommand unit tests', () {
    test('eligible void strictly uses original date and links inversesId', () {
      final doc = buildSampleAccount();
      final saleCmd = CompleteSaleCommand(
        operationId: 'op-sale-for-void',
        accountLineage: 'lineage-void',
        saleId: 'sale-to-void',
        journalId: 'jnl-sale-void',
        draft: {
          'date': '2026-01-03',
          'discount': 0,
          'lines': [
            {'productId': 'p', 'quantity': 2},
          ],
        },
        recordedAt: '2026-01-03T12:00:00.000Z',
      );

      final initial = buildSyntheticState(
        account: doc,
        accountLineage: 'lineage-void',
      );
      final saleEval = RestaurantJournalSaleCommandCoordinator.evaluateSale(
        command: saleCmd,
        state: initial,
        cutoverDate: d('2026-01-01'),
        mapper: mapper,
      );
      final stateWithSale = saleEval.candidateState!;

      // Execute void
      final voidCmd = SaleVoidCommand(
        operationId: 'op-void-1',
        accountLineage: 'lineage-void',
        saleId: 'sale-to-void',
        reversalJournalId: 'jnl-void-reversal-1',
        reason: 'Cashier mistake',
        voidedAt: '2026-01-04T10:00:00.000Z',
      );

      final voidEval = RestaurantJournalSaleCommandCoordinator.evaluateVoid(
        command: voidCmd,
        state: stateWithSale,
        cutoverDate: d('2026-01-01'),
        mapper: mapper,
      );

      expect(voidEval.rejected, isFalse);
      final voidState = voidEval.candidateState!;
      final voidEntry = voidState.journals.last;

      expect(
        voidEntry.sourceType,
        RestaurantJournalSourceType.voidReversal.name,
      );
      expect(voidEntry.journal.id, 'jnl-void-reversal-1');
      expect(
        voidEntry.journal.effectiveDate,
        d('2026-01-03'),
      ); // strictly original date!
      expect(voidEntry.journal.reversesId, 'jnl-sale-void');
      expect(voidEntry.journal.reason, 'Cashier mistake');
      expect(voidEntry.metadata['reversalReason'], 'Cashier mistake');
      expect(voidEntry.metadata['originalJournalId'], 'jnl-sale-void');
      expect(voidEntry.metadata['receiptNumber'], 'S-000001');

      // Check source record updated to status == 'void'
      final rawSales = (voidState.account.toJson()['sales'] as List)
          .cast<Map<String, Object?>>();
      final voidedSourceSale = rawSales.firstWhere(
        (s) => s['id'] == 'sale-to-void',
      );
      expect(voidedSourceSale['status'], 'void');
      expect(voidedSourceSale['voidReason'], 'Cashier mistake');
      expect(voidedSourceSale['voidedAt'], '2026-01-04T10:00:00.000Z');

      // Check PortableJournalState validates cleanly with this reversal
      expect(() => voidState.validate(), returnsNormally);
      expect(() => codec.encodeState(voidState), returnsNormally);
    });

    test('void rejects any sale that has returns', () {
      final doc = buildSampleAccount();
      final saleCmd = CompleteSaleCommand(
        operationId: 'op-sale-returns-void',
        accountLineage: 'lineage-void-ret',
        saleId: 'sale-with-returns',
        journalId: 'jnl-sale-w-ret',
        draft: {
          'date': '2026-01-03',
          'discount': 0,
          'lines': [
            {'productId': 'p', 'quantity': 2},
          ],
        },
        recordedAt: '2026-01-03T12:00:00.000Z',
      );

      final initial = buildSyntheticState(
        account: doc,
        accountLineage: 'lineage-void-ret',
      );
      final saleEval = RestaurantJournalSaleCommandCoordinator.evaluateSale(
        command: saleCmd,
        state: initial,
        cutoverDate: d('2026-01-01'),
        mapper: mapper,
      );

      // Add a return
      final returnCmd = SaleReturnCommand(
        operationId: 'op-return-before-void',
        accountLineage: 'lineage-void-ret',
        returnId: 'ret-before-void',
        saleId: 'sale-with-returns',
        journalId: 'jnl-ret-before-void',
        returnDate: d('2026-01-04'),
        reason: 'Partial return',
        recordedAt: '2026-01-04T12:00:00.000Z',
        today: d('2026-01-04'),
        lines: [
          ReturnLineRequest(
            productId: 'p',
            quantityUnits: BigInt.from(1000),
            restock: false,
          ),
        ],
      );

      final returnEval = RestaurantJournalSaleCommandCoordinator.evaluateReturn(
        command: returnCmd,
        state: saleEval.candidateState!,
        cutoverDate: d('2026-01-01'),
        mapper: mapper,
      );

      final stateWithReturn = returnEval.candidateState!;

      // Now attempt to void the sale: MUST REJECT!
      final voidCmd = SaleVoidCommand(
        operationId: 'op-void-rejected',
        accountLineage: 'lineage-void-ret',
        saleId: 'sale-with-returns',
        reversalJournalId: 'jnl-void-rejected',
        reason: 'Attempting to void sale with returns',
        voidedAt: '2026-01-05T10:00:00.000Z',
      );

      final voidEval = RestaurantJournalSaleCommandCoordinator.evaluateVoid(
        command: voidCmd,
        state: stateWithReturn,
        cutoverDate: d('2026-01-01'),
        mapper: mapper,
      );

      expect(voidEval.rejected, isTrue);
      expect(
        voidEval.rejectionCode,
        RestaurantJournalSaleErrorCodes.voidIneligibleSaleHasReturns,
      );
    });

    test('void rejects already voided sale', () {
      final doc = buildSampleAccount();
      final saleCmd = CompleteSaleCommand(
        operationId: 'op-sale-twice',
        accountLineage: 'lineage-twice',
        saleId: 'sale-twice',
        journalId: 'jnl-sale-twice',
        draft: {
          'date': '2026-01-03',
          'discount': 0,
          'lines': [
            {'productId': 'p', 'quantity': 1},
          ],
        },
        recordedAt: '2026-01-03T12:00:00.000Z',
      );

      final initial = buildSyntheticState(
        account: doc,
        accountLineage: 'lineage-twice',
      );
      final saleEval = RestaurantJournalSaleCommandCoordinator.evaluateSale(
        command: saleCmd,
        state: initial,
        cutoverDate: d('2026-01-01'),
        mapper: mapper,
      );

      final voidCmd1 = SaleVoidCommand(
        operationId: 'op-void-1',
        accountLineage: 'lineage-twice',
        saleId: 'sale-twice',
        reversalJournalId: 'jnl-void-reversal-1',
        reason: 'First void',
        voidedAt: '2026-01-04T10:00:00.000Z',
      );

      final voidEval1 = RestaurantJournalSaleCommandCoordinator.evaluateVoid(
        command: voidCmd1,
        state: saleEval.candidateState!,
        cutoverDate: d('2026-01-01'),
        mapper: mapper,
      );
      expect(voidEval1.rejected, isFalse);

      final stateVoided = voidEval1.candidateState!;

      // Attempt second void:
      final voidCmd2 = SaleVoidCommand(
        operationId: 'op-void-2',
        accountLineage: 'lineage-twice',
        saleId: 'sale-twice',
        reversalJournalId: 'jnl-void-reversal-2',
        reason: 'Second void attempt',
        voidedAt: '2026-01-04T11:00:00.000Z',
      );

      final voidEval2 = RestaurantJournalSaleCommandCoordinator.evaluateVoid(
        command: voidCmd2,
        state: stateVoided,
        cutoverDate: d('2026-01-01'),
        mapper: mapper,
      );

      expect(voidEval2.rejected, isTrue);
      expect(
        voidEval2.rejectionCode,
        RestaurantJournalSaleErrorCodes.saleAlreadyVoid,
      );
    });
  });

  group('RestaurantJournalSaleOutcome tests', () {
    test('roundtrips payload cleanly', () {
      final outcome = RestaurantJournalSaleOutcome(
        commandType: 'complete_sale',
        operationId: 'op-roundtrip',
        saleId: 'sal-1',
        journalId: 'jnl-1',
        returnId: null,
        receiptNumber: 'S-000001',
        effectiveDate: '2026-01-03',
        netAmount: '1900',
        metadata: {'gross': '2000', 'discount': '100'},
      );

      final payload = outcome.toOutcomePayload();
      final decoded = RestaurantJournalSaleOutcome.fromOutcomePayload(payload);

      expect(decoded.commandType, outcome.commandType);
      expect(decoded.operationId, outcome.operationId);
      expect(decoded.saleId, outcome.saleId);
      expect(decoded.journalId, outcome.journalId);
      expect(decoded.returnId, isNull);
      expect(decoded.receiptNumber, outcome.receiptNumber);
      expect(decoded.effectiveDate, outcome.effectiveDate);
      expect(decoded.netAmount, outcome.netAmount);
      expect(decoded.metadata['gross'], '2000');
    });
  });
}
