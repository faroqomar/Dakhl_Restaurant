import 'package:madar_domain/madar_domain.dart';

/// Symbolic restaurant chart-of-accounts profile accepted under ADR 0021 / F-01.
final class RestaurantAccountProfile {
  const RestaurantAccountProfile({
    this.dailyCashAccountId = 'asset:cash:daily',
    this.cashboxAccountId = 'asset:cash:cashbox',
    this.salesRevenueAccountId = 'revenue:sales',
    this.salesReturnContraAccountId = 'contra_revenue:sales_return',
    this.purchasesExpenseAccountId = 'expense:purchases',
    this.openingEquityAccountId = 'equity:opening_balance',
    this.supplierLiabilityPrefix = 'liability:supplier:',
    this.categoryExpensePrefix = 'expense:category:',
  });

  final String dailyCashAccountId;
  final String cashboxAccountId;
  final String salesRevenueAccountId;
  final String salesReturnContraAccountId;
  final String purchasesExpenseAccountId;
  final String openingEquityAccountId;
  final String supplierLiabilityPrefix;
  final String categoryExpensePrefix;

  String supplierLiabilityAccountId(String supplierId) =>
      '$supplierLiabilityPrefix$supplierId';

  String categoryExpenseAccountId(String categoryId) =>
      '$categoryExpensePrefix$categoryId';
}

/// Standard journal policies for the single-restaurant offline IQD ledger.
abstract final class RestaurantJournalPolicies {
  static final BigInt defaultLimit = BigInt.from(1000000000000); // 10^12 dinars

  /// Standard policy (IQD, scale 0, zero lines prohibited).
  static final JournalPolicy standard = JournalPolicy(
    currency: 'IQD',
    scale: 0,
    maximumLineUnits: defaultLimit,
    maximumSideUnits: defaultLimit,
    maximumLines: 500,
    allowZeroLines: false,
  );

  static final BigInt maximumSafeAggregate = BigInt.parse('9007199254740991');
  static const maximumOpeningSuppliers =
      5000; // Supported account supplier bound.

  /// Opening assets/liabilities are verified aggregates, not transactions.
  static final JournalPolicy opening = JournalPolicy(
    currency: 'IQD',
    scale: 0,
    maximumLineUnits: maximumSafeAggregate,
    maximumSideUnits: maximumSafeAggregate,
    maximumLines: maximumOpeningSuppliers + 3,
    allowZeroLines: false,
  );

  /// Explicit policy permitting zero-value lines for source compatibility.
  static final JournalPolicy allowZero = JournalPolicy(
    currency: 'IQD',
    scale: 0,
    maximumLineUnits: defaultLimit,
    maximumSideUnits: defaultLimit,
    maximumLines: 500,
    allowZeroLines: true,
  );
}

/// Source type tag for the consumer journal proposal envelope.
enum RestaurantJournalSourceType {
  sale,
  saleReturn,
  expense,
  purchaseInvoice,
  supplierPayment,
  cashboxTransfer,
  cutoverOpening,
  voidReversal,
  correctionReplacement,
  externalCashAdjustment,
  manualDebt,
}

/// App-owned envelope wrapping a pure [BalancedJournal] with source metadata.
///
/// Under F-04 / ADR 0021, link fields such as [correctedFromId], [receiptNumber],
/// and source versioning remain app-owned and are not injected into Madar contracts.
final class RestaurantJournalProposal {
  RestaurantJournalProposal({
    required this.journal,
    required this.sourceType,
    required this.sourceRecordId,
    this.receiptNumber,
    this.correctedFromId,
    this.sourceVersion = 11,
    Map<String, Object?> metadata = const {},
  }) : metadata = _snapshotMetadata(
         metadata,
         Set<Object>.identity(),
       ) as Map<String, Object?>;

  final BalancedJournal journal;
  final RestaurantJournalSourceType sourceType;
  final String sourceRecordId;
  final String? receiptNumber;
  final String? correctedFromId;
  final int sourceVersion;
  final Map<String, Object?> metadata;

  // App-owned envelope values: exact scalars and JSON-like containers only.
  // Snapshot borrowed containers so proposal history cannot change afterward.
  static Object? _snapshotMetadata(Object? value, Set<Object> active) {
    if (value == null ||
        value is String ||
        value is bool ||
        value is int ||
        value is BigInt) {
      return value;
    }
    if (value is! Map && value is! List) {
      throw const RestaurantJournalMappingException('invalid_journal_metadata');
    }
    if (!active.add(value)) {
      throw const RestaurantJournalMappingException('invalid_journal_metadata');
    }
    try {
      if (value is List) {
        return List<Object?>.unmodifiable(
          value.map((item) => _snapshotMetadata(item, active)),
        );
      }
      final result = <String, Object?>{};
      for (final entry in (value as Map).entries) {
        if (entry.key is! String) {
          throw const RestaurantJournalMappingException(
            'invalid_journal_metadata',
          );
        }
        result[entry.key as String] = _snapshotMetadata(entry.value, active);
      }
      return Map<String, Object?>.unmodifiable(result);
    } finally {
      active.remove(value);
    }
  }
}

/// Deterministic domain mapping failure for restaurant journal proposals.
/// Never contains private payloads.
final class RestaurantJournalMappingException implements Exception {
  const RestaurantJournalMappingException(this.code, {this.details = ''});

  final String code;
  final String details;

  @override
  String toString() =>
      'RestaurantJournalMappingException($code${details.isEmpty ? '' : ': $details'})';
}

/// Stateless pure consumer mapper from validated restaurant records/intents
/// to Madar double-entry [BalancedJournal] values under accepted ADR 0021 semantics.
///
/// Features:
/// - Sales R1: Debit daily cash, Credit net sales revenue. Original snapshots preserved.
/// - Operating Expense: Debit category expense, Credit daily/cashbox cash assets.
/// - Purchases 1A-P: Debit purchase expense, Credit supplier liability at invoice date.
/// - Supplier Settlement: Debit supplier liability, Credit daily/cashbox funding;
///   STRICTLY NO second purchase expense recognized.
/// - Customer Return T1: Debit sales return contra-revenue, Credit daily cash on return date.
/// - Daily Transfer: Debit cashbox asset, Credit daily cash asset. No expense.
/// - Reversal 3A: Original-date inverse with required eligibility verification.
/// - Replacement Envelope: App-level correctedFromId linking.
/// - Cutover Opening 2A: Caller-supplied verified cash and debt reconciliation.
/// - Unmapped Gaps: Explicit rejection for unmapped counteraccounts.
final class RestaurantJournalMapper {
  RestaurantJournalMapper({
    this.profile = const RestaurantAccountProfile(),
    JournalPolicy? defaultPolicy,
    JournalPolicy? openingPolicy,
  }) : defaultPolicy = defaultPolicy ?? RestaurantJournalPolicies.standard,
       openingPolicy =
           openingPolicy ?? defaultPolicy ?? RestaurantJournalPolicies.opening;

  final RestaurantAccountProfile profile;
  final JournalPolicy defaultPolicy;
  final JournalPolicy openingPolicy;

  static void _require(bool condition, String code, [String details = '']) {
    if (!condition) {
      throw RestaurantJournalMappingException(code, details: details);
    }
  }

  static void _checkIdentity(String id, String field) {
    _require(
      id.isNotEmpty && id.trim() == id,
      'invalid_identity',
      '$field must be a non-empty trimmed string',
    );
  }

  /// Maps a sale ticket proposal/record under ADR 0021 Net Revenue R1 semantics.
  ///
  /// Debits [RestaurantAccountProfile.dailyCashAccountId] and
  /// credits [RestaurantAccountProfile.salesRevenueAccountId] for the net amount.
  /// Original gross and discount snapshots are preserved in proposal metadata.
  RestaurantJournalProposal mapSaleTicket({
    required String journalId,
    required String saleId,
    required String receiptNumber,
    required DateOnly effectiveDate,
    required BigInt grossAmount,
    required BigInt discountAmount,
    required BigInt netAmount,
    JournalPolicy? policy,
  }) {
    final activePolicy = policy ?? defaultPolicy;
    _checkIdentity(journalId, 'journalId');
    _checkIdentity(saleId, 'saleId');
    _checkIdentity(receiptNumber, 'receiptNumber');

    _require(
      !discountAmount.isNegative && !grossAmount.isNegative,
      'negative_amount',
      'gross and discount amounts must be non-negative',
    );
    _require(
      discountAmount <= grossAmount,
      'invalid_discount',
      'discount cannot exceed gross amount',
    );
    _require(
      grossAmount - discountAmount == netAmount,
      'inconsistent_net',
      'netAmount must equal grossAmount - discountAmount',
    );
    _require(
      !netAmount.isNegative,
      'negative_net',
      'net amount cannot be negative',
    );

    if (netAmount == BigInt.zero && !activePolicy.allowZeroLines) {
      throw const RestaurantJournalMappingException(
        'zero_value_requires_allow_zero_policy',
        details: 'Zero-net sales ticket requires an explicit JournalPolicy with allowZeroLines=true',
      );
    }

    final lines = [
      JournalLine(
        accountId: profile.dailyCashAccountId,
        side: JournalSide.debit,
        amountUnits: netAmount,
        currency: activePolicy.currency,
        scale: activePolicy.scale,
      ),
      JournalLine(
        accountId: profile.salesRevenueAccountId,
        side: JournalSide.credit,
        amountUnits: netAmount,
        currency: activePolicy.currency,
        scale: activePolicy.scale,
      ),
    ];

    final journal = BalancedJournal.validate(
      id: journalId,
      effectiveDate: effectiveDate,
      lines: lines,
      policy: activePolicy,
    );

    return RestaurantJournalProposal(
      journal: journal,
      sourceType: RestaurantJournalSourceType.sale,
      sourceRecordId: saleId,
      receiptNumber: receiptNumber,
      metadata: {
        'gross': grossAmount,
        'discount': discountAmount,
        'net': netAmount,
      },
    );
  }

  /// Maps an operating expense funded from daily drawer, cashbox, or shared.
  ///
  /// Debits [RestaurantAccountProfile.categoryExpenseAccountId] for total amount.
  /// Credits [RestaurantAccountProfile.dailyCashAccountId] and/or
  /// [RestaurantAccountProfile.cashboxAccountId] matching funding breakdown.
  RestaurantJournalProposal mapOperatingExpense({
    required String journalId,
    required String expenseId,
    required DateOnly effectiveDate,
    required String categoryId,
    required BigInt amount,
    required BigInt dailyAmount,
    required BigInt cashboxAmount,
    JournalPolicy? policy,
  }) {
    final activePolicy = policy ?? defaultPolicy;
    _checkIdentity(journalId, 'journalId');
    _checkIdentity(expenseId, 'expenseId');
    _checkIdentity(categoryId, 'categoryId');

    _require(
      !amount.isNegative &&
          !dailyAmount.isNegative &&
          !cashboxAmount.isNegative,
      'negative_amount',
      'expense amounts must be non-negative',
    );
    _require(
      dailyAmount + cashboxAmount == amount,
      'invalid_funding_allocation',
      'dailyAmount + cashboxAmount must equal total expense amount',
    );

    if (amount == BigInt.zero && !activePolicy.allowZeroLines) {
      throw const RestaurantJournalMappingException(
        'zero_value_requires_allow_zero_policy',
        details: 'Zero-amount expense requires an explicit JournalPolicy with allowZeroLines=true',
      );
    }

    final lines = <JournalLine>[
      JournalLine(
        accountId: profile.categoryExpenseAccountId(categoryId),
        side: JournalSide.debit,
        amountUnits: amount,
        currency: activePolicy.currency,
        scale: activePolicy.scale,
      ),
    ];

    if (amount == BigInt.zero && activePolicy.allowZeroLines) {
      lines.add(
        JournalLine(
          accountId: profile.dailyCashAccountId,
          side: JournalSide.credit,
          amountUnits: BigInt.zero,
          currency: activePolicy.currency,
          scale: activePolicy.scale,
        ),
      );
    } else {
      if (dailyAmount > BigInt.zero) {
        lines.add(
          JournalLine(
            accountId: profile.dailyCashAccountId,
            side: JournalSide.credit,
            amountUnits: dailyAmount,
            currency: activePolicy.currency,
            scale: activePolicy.scale,
          ),
        );
      }
      if (cashboxAmount > BigInt.zero) {
        lines.add(
          JournalLine(
            accountId: profile.cashboxAccountId,
            side: JournalSide.credit,
            amountUnits: cashboxAmount,
            currency: activePolicy.currency,
            scale: activePolicy.scale,
          ),
        );
      }
    }

    final journal = BalancedJournal.validate(
      id: journalId,
      effectiveDate: effectiveDate,
      lines: lines,
      policy: activePolicy,
    );

    return RestaurantJournalProposal(
      journal: journal,
      sourceType: RestaurantJournalSourceType.expense,
      sourceRecordId: expenseId,
      metadata: {
        'categoryId': categoryId,
        'amount': amount,
        'dailyAmount': dailyAmount,
        'cashboxAmount': cashboxAmount,
      },
    );
  }

  /// Maps an unpaid purchase invoice under ADR 0021 Option 1A-P semantics.
  ///
  /// Internally debits [RestaurantAccountProfile.purchasesExpenseAccountId] and
  /// credits [RestaurantAccountProfile.supplierLiabilityAccountId].
  /// No cash is disbursed; no paid-spending source entry is created.
  RestaurantJournalProposal mapPurchaseInvoice({
    required String journalId,
    required String invoiceId,
    required String invoiceNumber,
    required String supplierId,
    required DateOnly effectiveDate,
    required BigInt amount,
    JournalPolicy? policy,
  }) {
    final activePolicy = policy ?? defaultPolicy;
    _checkIdentity(journalId, 'journalId');
    _checkIdentity(invoiceId, 'invoiceId');
    _checkIdentity(supplierId, 'supplierId');

    _require(
      !amount.isNegative,
      'negative_amount',
      'invoice amount must be non-negative',
    );

    if (amount == BigInt.zero && !activePolicy.allowZeroLines) {
      throw const RestaurantJournalMappingException(
        'zero_value_requires_allow_zero_policy',
        details: 'Zero-amount invoice requires an explicit JournalPolicy with allowZeroLines=true',
      );
    }

    final lines = [
      JournalLine(
        accountId: profile.purchasesExpenseAccountId,
        side: JournalSide.debit,
        amountUnits: amount,
        currency: activePolicy.currency,
        scale: activePolicy.scale,
      ),
      JournalLine(
        accountId: profile.supplierLiabilityAccountId(supplierId),
        side: JournalSide.credit,
        amountUnits: amount,
        currency: activePolicy.currency,
        scale: activePolicy.scale,
      ),
    ];

    final journal = BalancedJournal.validate(
      id: journalId,
      effectiveDate: effectiveDate,
      lines: lines,
      policy: activePolicy,
    );

    return RestaurantJournalProposal(
      journal: journal,
      sourceType: RestaurantJournalSourceType.purchaseInvoice,
      sourceRecordId: invoiceId,
      metadata: {
        'invoiceNumber': invoiceNumber,
        'supplierId': supplierId,
        'amount': amount,
      },
    );
  }

  /// Maps supplier payment settlement under ADR 0021 Option 1A-P semantics.
  ///
  /// Debits [RestaurantAccountProfile.supplierLiabilityAccountId].
  /// Credits [RestaurantAccountProfile.dailyCashAccountId] and/or
  /// [RestaurantAccountProfile.cashboxAccountId].
  ///
  /// STRICT INVARIANT: Does NOT recognize purchase expense again, because the
  /// invoice already recognized purchase expense at invoice date.
  RestaurantJournalProposal mapSupplierPayment({
    required String journalId,
    required String paymentId,
    required String supplierId,
    required DateOnly effectiveDate,
    required BigInt amount,
    required BigInt dailyAmount,
    required BigInt cashboxAmount,
    required BigInt invoiceSettledAmount,
    required BigInt debtSettledAmount,
    String? invoiceId,
    JournalPolicy? policy,
  }) {
    final activePolicy = policy ?? defaultPolicy;
    _checkIdentity(journalId, 'journalId');
    _checkIdentity(paymentId, 'paymentId');
    _checkIdentity(supplierId, 'supplierId');

    _require(
      !amount.isNegative &&
          !dailyAmount.isNegative &&
          !cashboxAmount.isNegative &&
          !invoiceSettledAmount.isNegative &&
          !debtSettledAmount.isNegative,
      'negative_amount',
      'payment and settlement amounts must be non-negative',
    );
    _require(
      dailyAmount + cashboxAmount == amount,
      'invalid_funding_allocation',
      'dailyAmount + cashboxAmount must equal total payment amount',
    );
    _require(
      invoiceSettledAmount + debtSettledAmount == amount,
      'invalid_settlement_allocation',
      'invoiceSettledAmount + debtSettledAmount must equal total payment amount',
    );

    if (amount == BigInt.zero && !activePolicy.allowZeroLines) {
      throw const RestaurantJournalMappingException(
        'zero_value_requires_allow_zero_policy',
        details: 'Zero-amount payment requires an explicit JournalPolicy with allowZeroLines=true',
      );
    }

    final lines = <JournalLine>[
      JournalLine(
        accountId: profile.supplierLiabilityAccountId(supplierId),
        side: JournalSide.debit,
        amountUnits: amount,
        currency: activePolicy.currency,
        scale: activePolicy.scale,
      ),
    ];

    if (amount == BigInt.zero && activePolicy.allowZeroLines) {
      lines.add(
        JournalLine(
          accountId: profile.dailyCashAccountId,
          side: JournalSide.credit,
          amountUnits: BigInt.zero,
          currency: activePolicy.currency,
          scale: activePolicy.scale,
        ),
      );
    } else {
      if (dailyAmount > BigInt.zero) {
        lines.add(
          JournalLine(
            accountId: profile.dailyCashAccountId,
            side: JournalSide.credit,
            amountUnits: dailyAmount,
            currency: activePolicy.currency,
            scale: activePolicy.scale,
          ),
        );
      }
      if (cashboxAmount > BigInt.zero) {
        lines.add(
          JournalLine(
            accountId: profile.cashboxAccountId,
            side: JournalSide.credit,
            amountUnits: cashboxAmount,
            currency: activePolicy.currency,
            scale: activePolicy.scale,
          ),
        );
      }
    }

    final journal = BalancedJournal.validate(
      id: journalId,
      effectiveDate: effectiveDate,
      lines: lines,
      policy: activePolicy,
    );

    return RestaurantJournalProposal(
      journal: journal,
      sourceType: RestaurantJournalSourceType.supplierPayment,
      sourceRecordId: paymentId,
      metadata: {
        'supplierId': supplierId,
        'invoiceId': invoiceId,
        'invoiceSettledAmount': invoiceSettledAmount,
        'debtSettledAmount': debtSettledAmount,
        'dailyAmount': dailyAmount,
        'cashboxAmount': cashboxAmount,
      },
    );
  }

  /// Maps a customer sales return / refund under ADR 0021 Option T1 semantics.
  ///
  /// Debits [RestaurantAccountProfile.salesReturnContraAccountId] and
  /// credits [RestaurantAccountProfile.dailyCashAccountId] on [returnDate].
  /// Original sale is preserved; optional tracked inventory restocking is handled
  /// outside the double-entry journal.
  RestaurantJournalProposal mapSaleReturn({
    required String journalId,
    required String returnId,
    required String originalSaleId,
    required DateOnly returnDate,
    required BigInt amount,
    required String reason,
    JournalPolicy? policy,
  }) {
    final activePolicy = policy ?? defaultPolicy;
    _checkIdentity(journalId, 'journalId');
    _checkIdentity(returnId, 'returnId');
    _checkIdentity(originalSaleId, 'originalSaleId');
    _require(reason.trim().isNotEmpty, 'invalid_reason', 'reason is required');
    _require(
      !amount.isNegative,
      'negative_amount',
      'return amount must be non-negative',
    );

    if (amount == BigInt.zero && !activePolicy.allowZeroLines) {
      throw const RestaurantJournalMappingException(
        'zero_value_requires_allow_zero_policy',
        details: 'Zero-amount return requires an explicit JournalPolicy with allowZeroLines=true',
      );
    }

    final lines = [
      JournalLine(
        accountId: profile.salesReturnContraAccountId,
        side: JournalSide.debit,
        amountUnits: amount,
        currency: activePolicy.currency,
        scale: activePolicy.scale,
      ),
      JournalLine(
        accountId: profile.dailyCashAccountId,
        side: JournalSide.credit,
        amountUnits: amount,
        currency: activePolicy.currency,
        scale: activePolicy.scale,
      ),
    ];

    final journal = BalancedJournal.validate(
      id: journalId,
      effectiveDate: returnDate,
      lines: lines,
      policy: activePolicy,
    );

    return RestaurantJournalProposal(
      journal: journal,
      sourceType: RestaurantJournalSourceType.saleReturn,
      sourceRecordId: returnId,
      metadata: {
        'originalSaleId': originalSaleId,
        'reason': reason.trim(),
        'amount': amount,
      },
    );
  }

  /// Maps daily drawer to cashbox safe transfer.
  ///
  /// Debits [RestaurantAccountProfile.cashboxAccountId] and
  /// credits [RestaurantAccountProfile.dailyCashAccountId].
  /// Does not recognize an expense.
  RestaurantJournalProposal mapDailyToCashboxTransfer({
    required String journalId,
    required String transferId,
    required DateOnly effectiveDate,
    required BigInt amount,
    JournalPolicy? policy,
  }) {
    final activePolicy = policy ?? defaultPolicy;
    _checkIdentity(journalId, 'journalId');
    _checkIdentity(transferId, 'transferId');

    _require(
      !amount.isNegative,
      'negative_amount',
      'transfer amount must be non-negative',
    );

    if (amount == BigInt.zero && !activePolicy.allowZeroLines) {
      throw const RestaurantJournalMappingException(
        'zero_value_requires_allow_zero_policy',
        details: 'Zero-amount transfer requires an explicit JournalPolicy with allowZeroLines=true',
      );
    }

    final lines = [
      JournalLine(
        accountId: profile.cashboxAccountId,
        side: JournalSide.debit,
        amountUnits: amount,
        currency: activePolicy.currency,
        scale: activePolicy.scale,
      ),
      JournalLine(
        accountId: profile.dailyCashAccountId,
        side: JournalSide.credit,
        amountUnits: amount,
        currency: activePolicy.currency,
        scale: activePolicy.scale,
      ),
    ];

    final journal = BalancedJournal.validate(
      id: journalId,
      effectiveDate: effectiveDate,
      lines: lines,
      policy: activePolicy,
    );

    return RestaurantJournalProposal(
      journal: journal,
      sourceType: RestaurantJournalSourceType.cashboxTransfer,
      sourceRecordId: transferId,
      metadata: {'amount': amount},
    );
  }

  /// Maps an eligible original-date reversal/void under ADR 0021 Option 3A semantics.
  ///
  /// Reverses the journal lines on the original entry's effective date, retaining
  /// receipt number and linking through [BalancedJournal.reversesId].
  /// Requires caller-verified eligibility (e.g. sale has no partial returns).
  RestaurantJournalProposal mapOriginalDateVoid({
    required RestaurantJournalProposal originalProposal,
    required String reversalJournalId,
    required String reason,
    required bool isEligible,
    String? voidRecordId,
  }) {
    _require(
      originalProposal.journal.reversesId == null &&
          originalProposal.sourceType !=
              RestaurantJournalSourceType.voidReversal,
      'already_reversed',
      'An inverse journal cannot be voided again',
    );
    _require(
      isEligible,
      'void_ineligible',
      'Original record is not eligible for void/reversal',
    );
    _checkIdentity(reversalJournalId, 'reversalJournalId');
    _require(
      reason.trim().isNotEmpty,
      'journal_reason_required',
      'reversal reason is required',
    );
    _require(
      reversalJournalId != originalProposal.journal.id,
      'invalid_identity',
      'Reversal journal ID cannot match original journal ID',
    );

    final reversedJournal = originalProposal.journal.reversed(
      id: reversalJournalId,
      effectiveDate:
          originalProposal.journal.effectiveDate, // strictly original date
      reason: reason.trim(),
    );

    return RestaurantJournalProposal(
      journal: reversedJournal,
      sourceType: RestaurantJournalSourceType.voidReversal,
      sourceRecordId: voidRecordId ?? originalProposal.sourceRecordId,
      receiptNumber: originalProposal.receiptNumber,
      sourceVersion: originalProposal.sourceVersion,
      metadata: {
        ...originalProposal.metadata,
        'reversalReason': reason.trim(),
        'originalJournalId': originalProposal.journal.id,
      },
    );
  }

  /// Envelopes a replacement journal proposal linked via [RestaurantJournalProposal.correctedFromId].
  ///
  /// Preserves current BalancedJournal contracts (which expose reversesId/reason only)
  /// while tracking app-owned correction lineage.
  RestaurantJournalProposal mapReplacementProposal({
    required RestaurantJournalProposal newProposal,
    required String correctedFromId,
  }) {
    _checkIdentity(correctedFromId, 'correctedFromId');
    return RestaurantJournalProposal(
      journal: newProposal.journal,
      sourceType: RestaurantJournalSourceType.correctionReplacement,
      sourceRecordId: newProposal.sourceRecordId,
      receiptNumber: newProposal.receiptNumber,
      correctedFromId: correctedFromId,
      sourceVersion: newProposal.sourceVersion,
      metadata: {...newProposal.metadata, 'correctedFromId': correctedFromId},
    );
  }

  /// Maps caller-supplied verified cutover opening balances under ADR 0021 Option 2A semantics.
  ///
  /// Reconciles verified physical register cash, cashbox safe balance, and
  /// supplier liabilities against [RestaurantAccountProfile.openingEquityAccountId].
  /// Never infers opening values from incomplete registers.
  RestaurantJournalProposal mapVerifiedCutoverOpening({
    required String journalId,
    required DateOnly effectiveDate,
    required BigInt verifiedPhysicalRegisterCash,
    required BigInt verifiedCashboxBalance,
    required Map<String, BigInt> verifiedSupplierDebts,
    JournalPolicy? policy,
  }) {
    final activePolicy = policy ?? openingPolicy;
    _require(
      verifiedSupplierDebts.length <=
          RestaurantJournalPolicies.maximumOpeningSuppliers,
      'opening_supplier_limit',
      'Opening supplier count exceeds the supported source bound',
    );
    _checkIdentity(journalId, 'journalId');

    for (final entry in verifiedSupplierDebts.entries) {
      _checkIdentity(entry.key, 'supplierId');
      _require(
        !entry.value.isNegative,
        'negative_debt',
        'supplier debt cannot be negative',
      );
    }

    final lines = <JournalLine>[];
    var totalAssets = BigInt.zero;
    var totalLiabilities = BigInt.zero;

    if (verifiedPhysicalRegisterCash != BigInt.zero) {
      lines.add(
        JournalLine(
          accountId: profile.dailyCashAccountId,
          side: verifiedPhysicalRegisterCash.isNegative
              ? JournalSide.credit
              : JournalSide.debit,
          amountUnits: verifiedPhysicalRegisterCash.abs(),
          currency: activePolicy.currency,
          scale: activePolicy.scale,
        ),
      );
      totalAssets += verifiedPhysicalRegisterCash;
    }

    if (verifiedCashboxBalance != BigInt.zero) {
      lines.add(
        JournalLine(
          accountId: profile.cashboxAccountId,
          side: verifiedCashboxBalance.isNegative
              ? JournalSide.credit
              : JournalSide.debit,
          amountUnits: verifiedCashboxBalance.abs(),
          currency: activePolicy.currency,
          scale: activePolicy.scale,
        ),
      );
      totalAssets += verifiedCashboxBalance;
    }

    for (final entry in verifiedSupplierDebts.entries) {
      if (entry.value > BigInt.zero) {
        lines.add(
          JournalLine(
            accountId: profile.supplierLiabilityAccountId(entry.key),
            side: JournalSide.credit,
            amountUnits: entry.value,
            currency: activePolicy.currency,
            scale: activePolicy.scale,
          ),
        );
        totalLiabilities += entry.value;
      }
    }

    final residual = totalAssets - totalLiabilities;
    if (residual > BigInt.zero) {
      lines.add(
        JournalLine(
          accountId: profile.openingEquityAccountId,
          side: JournalSide.credit,
          amountUnits: residual,
          currency: activePolicy.currency,
          scale: activePolicy.scale,
        ),
      );
    } else if (residual < BigInt.zero) {
      lines.add(
        JournalLine(
          accountId: profile.openingEquityAccountId,
          side: JournalSide.debit,
          amountUnits: residual.abs(),
          currency: activePolicy.currency,
          scale: activePolicy.scale,
        ),
      );
    }

    if (lines.length < 2) {
      _require(
        activePolicy.allowZeroLines,
        'cutover_zero_lines',
        'Zero-balance opening requires allowZeroLines=true',
      );
      lines.add(
        JournalLine(
          accountId: profile.dailyCashAccountId,
          side: JournalSide.debit,
          amountUnits: BigInt.zero,
          currency: activePolicy.currency,
          scale: activePolicy.scale,
        ),
      );
      lines.add(
        JournalLine(
          accountId: profile.openingEquityAccountId,
          side: JournalSide.credit,
          amountUnits: BigInt.zero,
          currency: activePolicy.currency,
          scale: activePolicy.scale,
        ),
      );
    }

    late BalancedJournal journal;
    try {
      journal = BalancedJournal.validate(
        id: journalId,
        effectiveDate: effectiveDate,
        lines: lines,
        policy: activePolicy,
      );
    } on DomainValidationException catch (error) {
      throw RestaurantJournalMappingException(
        error.code == 'journal_line_out_of_range' ||
                error.code == 'journal_total_out_of_range'
            ? 'opening_balance_limit_exceeded'
            : error.code,
      );
    }

    return RestaurantJournalProposal(
      journal: journal,
      sourceType: RestaurantJournalSourceType.cutoverOpening,
      sourceRecordId: journalId,
      metadata: {
        'verifiedRegisterCash': verifiedPhysicalRegisterCash,
        'verifiedCashbox': verifiedCashboxBalance,
        'totalSupplierDebts': totalLiabilities,
        'equityResidual': residual,
      },
    );
  }

  /// Maps an external cash deposit or withdrawal.
  ///
  /// STRICT POLICY CHECK: Rejects with [unmapped_financial_gap] if no explicit
  /// accepted counteraccount is provided. Does NOT silently choose equity,
  /// revenue, or purchase expense.
  RestaurantJournalProposal mapExternalCashAdjustment({
    required String journalId,
    required String recordId,
    required DateOnly effectiveDate,
    required String targetCashAccount,
    required BigInt amount,
    required bool isDeposit,
    required String? acceptedCounterAccountId,
    JournalPolicy? policy,
  }) {
    final activePolicy = policy ?? defaultPolicy;
    _checkIdentity(journalId, 'journalId');
    _checkIdentity(recordId, 'recordId');
    _checkIdentity(targetCashAccount, 'targetCashAccount');

    if (acceptedCounterAccountId == null ||
        acceptedCounterAccountId.trim().isEmpty) {
      throw const RestaurantJournalMappingException(
        'unmapped_financial_gap',
        details:
            'External cash adjustments require an explicit owner-accepted counteraccount; '
            'silently choosing equity, revenue or purchase expense is prohibited under ADR 0021.',
      );
    }

    _require(
      !amount.isNegative,
      'negative_amount',
      'adjustment amount must be non-negative',
    );

    final lines = isDeposit
        ? [
            JournalLine(
              accountId: targetCashAccount,
              side: JournalSide.debit,
              amountUnits: amount,
              currency: activePolicy.currency,
              scale: activePolicy.scale,
            ),
            JournalLine(
              accountId: acceptedCounterAccountId.trim(),
              side: JournalSide.credit,
              amountUnits: amount,
              currency: activePolicy.currency,
              scale: activePolicy.scale,
            ),
          ]
        : [
            JournalLine(
              accountId: acceptedCounterAccountId.trim(),
              side: JournalSide.debit,
              amountUnits: amount,
              currency: activePolicy.currency,
              scale: activePolicy.scale,
            ),
            JournalLine(
              accountId: targetCashAccount,
              side: JournalSide.credit,
              amountUnits: amount,
              currency: activePolicy.currency,
              scale: activePolicy.scale,
            ),
          ];

    final journal = BalancedJournal.validate(
      id: journalId,
      effectiveDate: effectiveDate,
      lines: lines,
      policy: activePolicy,
    );

    return RestaurantJournalProposal(
      journal: journal,
      sourceType: RestaurantJournalSourceType.externalCashAdjustment,
      sourceRecordId: recordId,
      metadata: {
        'isDeposit': isDeposit,
        'counterAccount': acceptedCounterAccountId.trim(),
      },
    );
  }

  /// Maps a manual additional debt record.
  ///
  /// STRICT POLICY CHECK: Rejects with [unmapped_financial_gap] if no explicit
  /// accepted counteraccount is provided. Does NOT silently choose equity,
  /// revenue, or purchase expense.
  RestaurantJournalProposal mapManualAdditionalDebt({
    required String journalId,
    required String debtId,
    required String supplierId,
    required DateOnly effectiveDate,
    required BigInt amount,
    required String? acceptedCounterAccountId,
    JournalPolicy? policy,
  }) {
    final activePolicy = policy ?? defaultPolicy;
    _checkIdentity(journalId, 'journalId');
    _checkIdentity(debtId, 'debtId');
    _checkIdentity(supplierId, 'supplierId');

    if (acceptedCounterAccountId == null ||
        acceptedCounterAccountId.trim().isEmpty) {
      throw const RestaurantJournalMappingException(
        'unmapped_financial_gap',
        details:
            'Manual additional supplier debt requires an explicit owner-accepted counteraccount; '
            'silently choosing equity, revenue or purchase expense is prohibited under ADR 0021.',
      );
    }

    _require(
      !amount.isNegative,
      'negative_amount',
      'debt amount must be non-negative',
    );

    final lines = [
      JournalLine(
        accountId: acceptedCounterAccountId.trim(),
        side: JournalSide.debit,
        amountUnits: amount,
        currency: activePolicy.currency,
        scale: activePolicy.scale,
      ),
      JournalLine(
        accountId: profile.supplierLiabilityAccountId(supplierId),
        side: JournalSide.credit,
        amountUnits: amount,
        currency: activePolicy.currency,
        scale: activePolicy.scale,
      ),
    ];

    final journal = BalancedJournal.validate(
      id: journalId,
      effectiveDate: effectiveDate,
      lines: lines,
      policy: activePolicy,
    );

    return RestaurantJournalProposal(
      journal: journal,
      sourceType: RestaurantJournalSourceType.manualDebt,
      sourceRecordId: debtId,
      metadata: {
        'supplierId': supplierId,
        'counterAccount': acceptedCounterAccountId.trim(),
      },
    );
  }
}
