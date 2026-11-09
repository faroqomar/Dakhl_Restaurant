import 'package:flutter/foundation.dart';
import 'package:madar_application/madar_application.dart';
import 'package:madar_domain/madar_domain.dart';

import '../accounting/restaurant_journal_mapper.dart';
import '../accounting/restaurant_journal_invoice_correction_commands.dart';
import '../accounting/restaurant_journal_payment_correction_commands.dart';
import '../accounting/restaurant_journal_spending_commands.dart';
import 'parties_operations_view_model.dart';
import 'parties_view_model.dart';
import 'purchase_proposal.dart';

/// High-level workflow controller for preparing and validating purchase
/// invoices and supplier debt payments against the complete-state account.
final class PurchaseOperationsController extends ChangeNotifier {
  PurchaseOperationsController({
    required this.parties,
    String? initialSupplierId,
    CommercePolicy? policy,
  }) : _selectedSupplierId = initialSupplierId,
       policy = policy ?? _defaultPolicy {
    parties.addListener(_onPartiesChanged);
  }

  final PartiesOperationsViewModel parties;
  final CommercePolicy policy;
  String? _selectedSupplierId;
  bool _disposed = false;

  static final _defaultPolicy = CommercePolicy(
    quantityScale: 3,
    maximumQuantityUnits: BigInt.from(1000000000000),
    maximumMoney: BigInt.from(1000000000000),
    maximumSafeInteger: BigInt.parse('9007199254740991'),
    rounding: DecimalRounding.halfTowardPositiveInfinity,
  );

  String? get selectedSupplierId => _selectedSupplierId;
  bool get busy => parties.busy;
  bool get postingEnabled => parties.postingEnabled;
  String? get errorCode => parties.errorCode;

  List<SupplierRecord> get suppliers => parties.suppliers;
  List<MaterialRecord> get materials => parties.materials;
  List<Map<String, Object?>> get invoices => parties.invoices;
  List<Map<String, Object?>> get payments => parties.payments;

  SupplierRecord? get selectedSupplier {
    final id = _selectedSupplierId;
    if (id == null) return null;
    for (final s in suppliers) {
      if (s.id == id) return s;
    }
    return null;
  }

  void selectSupplier(String? id) {
    if (_disposed || parties.busy) return;
    _selectedSupplierId = id;
    notifyListeners();
  }

  BigInt debtAvailable({required String supplierId, required DateOnly date}) {
    final ledger = parties.supplierLedger(supplierId);
    return ledger.debtAvailable(supplierId, date: date.toString());
  }

  BigInt invoiceDue(String invoiceId) {
    for (final inv in invoices) {
      if (inv['id'] == invoiceId) {
        final supplierId = inv['supplierId'] as String;
        final ledger = parties.supplierLedger(supplierId);
        return ledger.invoiceDue(invoiceId);
      }
    }
    return BigInt.zero;
  }

  BigInt calculateLineTotal(PurchaseLine line) {
    return CommerceCalculations.independentUnitLineTotal([
      QuantityPrice(
        quantityUnits: ExactDecimal.parse(
          '${line.quantityCartons}',
          scale: 3,
          maxAbsUnits: policy.maximumMoney,
          signed: false,
          positive: false,
        ).units,
        price: BigInt.from(line.priceCarton),
      ),
      QuantityPrice(
        quantityUnits: ExactDecimal.parse(
          '${line.quantityPieces}',
          scale: 3,
          maxAbsUnits: policy.maximumMoney,
          signed: false,
          positive: false,
        ).units,
        price: BigInt.from(line.pricePiece),
      ),
    ], policy: policy);
  }

  BigInt calculateInvoiceTotal(Iterable<PurchaseLine> lines) {
    return CommerceCalculations.invoiceTotal(
      lines.map((line) => calculateLineTotal(line)),
      policy: policy,
    );
  }

  PaymentSplit allocatePayment({
    required String supplierId,
    String? invoiceId,
    required BigInt amount,
    required DateOnly date,
  }) {
    final ledger = parties.supplierLedger(supplierId);
    final due = invoiceId == null ? BigInt.zero : ledger.invoiceDue(invoiceId);
    final debt = ledger.debtAvailable(supplierId, date: date.toString());
    return CommerceCalculations.allocatePayment(
      amount: amount,
      selectedLiabilityDue: due,
      eligibleDebt: debt,
      policy: policy,
    );
  }

  FundingSplit calculateFundingSplit({
    required BigInt amount,
    required FundingSource source,
    BigInt? daily,
    BigInt? cash,
  }) {
    return CommerceCalculations.fundingSplit(
      amount: amount,
      daily: daily ?? (source == FundingSource.daily ? amount : BigInt.zero),
      cash: cash ?? (source == FundingSource.cash ? amount : BigInt.zero),
      source: source,
      policy: policy,
    );
  }

  Future<DurableCommandResult<RestaurantJournalSpendingOutcome>> createInvoice({
    required String operationId,
    required String invoiceId,
    required String invoiceJournalId,
    required String supplierId,
    required String invoiceNumber,
    required DateOnly date,
    required Iterable<PurchaseLine> lines,
    String note = '',
    PurchasePayment? immediatePayment,
    String? paymentJournalId,
    required String recordedAt,
    JournalPolicy? journalPolicy,
  }) {
    final intent = parties.purchaseInvoiceIntent(
      operationId: operationId,
      invoiceId: invoiceId,
      invoiceJournalId: invoiceJournalId,
      supplierId: supplierId,
      invoiceNumber: invoiceNumber,
      date: date,
      lines: lines,
      note: note,
      immediatePayment: immediatePayment,
      paymentJournalId: paymentJournalId,
      recordedAt: recordedAt,
      policy: journalPolicy,
    );
    return parties.submitInvoice(intent);
  }

  Future<DurableCommandResult<RestaurantJournalInvoiceCorrectionOutcome>>
  editInvoice({
    required String operationId,
    required String invoiceId,
    required Map<String, Object?> expectedSource,
    required String expectedActiveJournalId,
    required String inverseJournalId,
    required String replacementJournalId,
    required String supplierId,
    required String invoiceNumber,
    required DateOnly date,
    required Iterable<PurchaseLine> lines,
    String note = '',
    required String reason,
    required String recordedAt,
    JournalPolicy? journalPolicy,
  }) => parties.submitInvoiceCorrection(
    parties.editInvoiceIntent(
      operationId: operationId,
      invoiceId: invoiceId,
      expectedSource: expectedSource,
      expectedActiveJournalId: expectedActiveJournalId,
      inverseJournalId: inverseJournalId,
      replacementJournalId: replacementJournalId,
      supplierId: supplierId,
      invoiceNumber: invoiceNumber,
      date: date,
      lines: lines,
      note: note,
      reason: reason,
      recordedAt: recordedAt,
      policy: journalPolicy,
    ),
  );

  Future<DurableCommandResult<RestaurantJournalInvoiceCorrectionOutcome>>
  deleteInvoice({
    required String operationId,
    required String invoiceId,
    required Map<String, Object?> expectedSource,
    required String expectedActiveJournalId,
    required String inverseJournalId,
    required String reason,
    required String recordedAt,
  }) => parties.submitInvoiceCorrection(
    parties.deleteInvoiceIntent(
      operationId: operationId,
      invoiceId: invoiceId,
      expectedSource: expectedSource,
      expectedActiveJournalId: expectedActiveJournalId,
      inverseJournalId: inverseJournalId,
      reason: reason,
      recordedAt: recordedAt,
    ),
  );

  Future<DurableCommandResult<RestaurantJournalSpendingOutcome>> createPayment({
    required String operationId,
    required String paymentId,
    required String journalId,
    required String supplierId,
    String? invoiceId,
    required DateOnly date,
    required BigInt amount,
    required FundingSource fundingSource,
    BigInt? dailyAmount,
    BigInt? cashAmount,
    String note = '',
    required String recordedAt,
    JournalPolicy? journalPolicy,
  }) {
    final intent = parties.supplierPaymentIntent(
      operationId: operationId,
      paymentId: paymentId,
      journalId: journalId,
      supplierId: supplierId,
      invoiceId: invoiceId,
      date: date,
      amount: amount,
      fundingSource: fundingSource,
      dailyAmount: dailyAmount,
      cashAmount: cashAmount,
      note: note,
      recordedAt: recordedAt,
      policy: journalPolicy,
    );
    return parties.submitPayment(intent);
  }

  Future<DurableCommandResult<RestaurantJournalPaymentCorrectionOutcome>>
  editPayment({
    required String operationId,
    required String paymentId,
    required String expectedActiveJournalId,
    required Map<String, Object?> expectedSource,
    required String inverseJournalId,
    required String replacementJournalId,
    required DateOnly date,
    required String categoryId,
    required String supplierId,
    String? invoiceId,
    required BigInt invoiceAmount,
    required BigInt debtAmount,
    required BigInt amount,
    required FundingSource fundingSource,
    BigInt? dailyAmount,
    BigInt? cashAmount,
    String note = '',
    required String reason,
    required String recordedAt,
    RestaurantAccountProfile? profile,
    JournalPolicy? journalPolicy,
  }) {
    final intent = parties.editPaymentIntent(
      operationId: operationId,
      paymentId: paymentId,
      expectedActiveJournalId: expectedActiveJournalId,
      expectedSource: expectedSource,
      inverseJournalId: inverseJournalId,
      replacementJournalId: replacementJournalId,
      date: date,
      categoryId: categoryId,
      supplierId: supplierId,
      invoiceId: invoiceId,
      invoiceAmount: invoiceAmount,
      debtAmount: debtAmount,
      amount: amount,
      fundingSource: fundingSource,
      dailyAmount: dailyAmount,
      cashAmount: cashAmount,
      note: note,
      reason: reason,
      recordedAt: recordedAt,
      profile: profile,
      policy: journalPolicy,
    );
    return parties.submitPaymentCorrection(intent);
  }

  Future<DurableCommandResult<RestaurantJournalPaymentCorrectionOutcome>>
  deletePayment({
    required String operationId,
    required String paymentId,
    required String expectedActiveJournalId,
    required Map<String, Object?> expectedSource,
    required String inverseJournalId,
    required String reason,
    required String recordedAt,
    RestaurantAccountProfile? profile,
    JournalPolicy? journalPolicy,
  }) {
    final intent = parties.deletePaymentIntent(
      operationId: operationId,
      paymentId: paymentId,
      expectedActiveJournalId: expectedActiveJournalId,
      expectedSource: expectedSource,
      inverseJournalId: inverseJournalId,
      reason: reason,
      recordedAt: recordedAt,
      profile: profile,
      policy: journalPolicy,
    );
    return parties.submitPaymentCorrection(intent);
  }

  void _onPartiesChanged() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    parties.removeListener(_onPartiesChanged);
    super.dispose();
  }
}
