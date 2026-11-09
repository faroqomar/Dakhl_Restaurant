import 'supplier_opening_controller.dart';

import 'package:flutter/foundation.dart';
import 'package:madar_application/madar_application.dart';
import 'package:madar_domain/madar_domain.dart';

import '../accounts/account_document.dart';
import '../accounts/portable_journal_codec.dart';
import '../accounting/restaurant_journal_mapper.dart';
import '../accounting/restaurant_journal_payment_history.dart';
import '../catalog/catalog_formatters.dart';
import 'parties_operations_view_model.dart';
import 'parties_view_model.dart';
import 'purchase_proposal.dart';
import 'supplier_ledger.dart';

/// Captured invoice editor submission. The original saved row is supplied to a
/// separately composed durable correction owner; this controller never writes
/// an invoice source rewrite through the metadata repository.
final class InvoiceEditorSubmission {
  InvoiceEditorSubmission({
    required this.id,
    required this.supplierId,
    required this.number,
    required this.date,
    required this.note,
    this.reason = '',
    required Iterable<PurchaseLine> lines,
    this.immediatePayment,
    this.expectedSource,
  }) : lines = List.unmodifiable(lines);
  final String id, supplierId, number, date, note, reason;
  final List<PurchaseLine> lines;
  final PurchasePayment? immediatePayment;
  final Map<String, Object?>? expectedSource;
}

typedef SaveInvoiceCorrection = Future<CapabilityResult<void>> Function(
  InvoiceEditorSubmission submission,
);

final class InvoiceLineForm {
  InvoiceLineForm({
    String? id,
    this.name = '',
    this.unit = 'قطعة',
    this.pieces = '0',
    this.piecePrice = '0',
    this.cartons = '0',
    this.cartonPrice = '0',
  }) : id = CatalogFormatters.generateId('line'),
       selectedMaterialId = id,
       creationMaterialId = CatalogFormatters.generateId('material');
  final String id;
  String? selectedMaterialId;
  final String creationMaterialId;
  String get materialId => selectedMaterialId ?? creationMaterialId;
  String name, unit, pieces, piecePrice, cartons, cartonPrice;
  PurchaseLine capture() => PurchaseLine(
    materialIdForCreation: materialId,
    name: name,
    unit: unit,
    quantityCartons: PartiesSurfaceController.quantity(cartons),
    quantityPieces: PartiesSurfaceController.quantity(pieces),
    priceCarton: PartiesSurfaceController.money(cartonPrice),
    pricePiece: PartiesSurfaceController.money(piecePrice),
  );
}

/// Consumer composition only. Financial submissions use existing durable
/// commands, while metadata uses the existing fenced metadata ViewModel.
final class PartiesSurfaceController extends ChangeNotifier {
  PartiesSurfaceController({
    this.metadata,
    this.operations,
    this.supplierOpenings,
    this.readAccount,
    this.compareText,
    this.onEditInvoice,
  }) {
    metadata?.addListener(_changed);
    operations?.addListener(_changed);
    supplierOpenings?.addListener(_changed);
  }
  final PartiesViewModel? metadata;
  final PartiesOperationsViewModel? operations;
  final SupplierOpeningController? supplierOpenings;
  final AccountDocument? Function()? readAccount;
  final int Function(String, String)? compareText;
  final SaveInvoiceCorrection? onEditInvoice;
  AccountDocument? get account =>
      operations?.account ??
      supplierOpenings?.account ??
      readAccount?.call() ??
      metadata?.repository.document;
  bool get busy =>
      (metadata?.busy ?? false) ||
      (operations?.busy ?? false) ||
      (supplierOpenings?.busy ?? false);
  bool get postingEnabled => operations?.postingEnabled ?? false;
  String? _pendingKind;
  bool _disposed = false;
  bool get needsReadback =>
      (operations?.needsReadback ?? false) ||
      (supplierOpenings?.needsReadback ?? false);
  bool get canEditInvoice => onEditInvoice != null || postingEnabled;
  static final _bound = BigInt.from(1000000000000);
  static final _money = ExactIntegerPolicy(
    maxAbs: _bound,
    signed: false,
    positive: false,
    maxSafeInteger: BigInt.parse('9007199254740991'),
  );
  static bool matches(String value, String query) =>
      LegacyCase.lower(
        value,
        profile: LegacyCaseProfile.ecmascriptUnicode17,
      ).contains(
        LegacyCase.lower(query, profile: LegacyCaseProfile.ecmascriptUnicode17),
      );
  static int money(String value) => _money
      .parse(
        value.trim().isEmpty ? '0' : value,
        normalizeDigits: true,
        allowGrouping: true,
      )
      .toInt();
  static num quantity(String value) => num.parse(
    ExactDecimal.parse(
      value.trim().isEmpty ? '0' : value,
      scale: 3,
      maxAbsUnits: _bound,
      signed: false,
      positive: false,
      normalizeDigits: true,
      allowGrouping: true,
      allowArabicDecimal: true,
    ).toString(),
  );
  static DateOnly date(String value) =>
      DateOnly.parse(value, minimumYear: 1000, maximumYear: 9999);
  List<Map<String, Object?>> rows(String key) => account == null
      ? const []
      : (account!.toJson()[key]! as List).cast<Map<String, Object?>>();
  List<SupplierRecord> get suppliers =>
      rows('suppliers').map(SupplierRecord.fromMap).toList(growable: false);
  List<MaterialRecord> get materials =>
      rows('materials').map(MaterialRecord.fromMap).toList(growable: false);
  static int _noSort(String a, String b) =>
      throw const FormatException('collation_unavailable');
  SupplierLedgerQueries get queries =>
      SupplierLedgerQueries(account!, compareText: compareText ?? _noSort);
  String supplierName(String id) =>
      suppliers.where((s) => s.id == id).map((s) => s.name).firstOrNull ?? id;
  BigInt supplierBalance(String id) => queries.supplierBalance(id);
  List<SupplierLedgerRow>? ledger(String id) {
    if (compareText == null) return null;
    try {
      return queries.ledger(id);
    } on Object {
      return null;
    }
  }

  BigInt invoiceTotal(Map<String, Object?> row) => queries.invoiceTotal(row);
  BigInt invoicePaid(String id) => queries.invoicePaid(id);
  BigInt invoiceDue(String id) => queries.invoiceDue(id);

  BigInt lineTotal(InvoiceLineForm form) {
    final line = form.capture();
    return queries.invoiceTotal({
      'lines': [
        {
          'quantityCartons': line.quantityCartons,
          'quantityPieces': line.quantityPieces,
          'priceCarton': line.priceCarton,
          'pricePiece': line.pricePiece,
        },
      ],
    });
  }

  /// Uses the source-compatible proposal for an editor preview only. Persisting
  /// this source proposal directly would omit the immutable journal contract.
  AccountDocument previewInvoice(InvoiceEditorSubmission value) =>
      PurchaseProposals(account!).invoice(
        id: value.id,
        supplierId: value.supplierId,
        number: value.number,
        date: value.date,
        createdAt:
            value.expectedSource?['createdAt'] as String? ??
            CatalogFormatters.currentIsoTimestamp(),
        lines: value.lines,
        note: value.note,
        immediatePayment: value.immediatePayment,
        editing: value.expectedSource != null,
      );
  BigInt previewInvoiceTotal(InvoiceEditorSubmission value) {
    final candidate = previewInvoice(value);
    final row = (candidate.toJson()['invoices']! as List)
        .cast<Map<String, Object?>>()
        .firstWhere((r) => r['id'] == value.id);
    return SupplierLedgerQueries(
      candidate,
      compareText: _noSort,
    ).invoiceTotal(row);
  }

  Future<CapabilityResult<void>> saveInvoice(
    InvoiceEditorSubmission value,
  ) async {
    if (busy) {
      return const CapabilityFailure(
        'busy',
        'Another operation is in progress.',
      );
    }
    if (value.expectedSource != null) {
      final save = onEditInvoice;
      if (save != null) return save(value);
      final owner = operations;
      if (owner == null) {
        return const CapabilityFailure(
          'invoice_correction_unavailable',
          'Durable invoice correction is unavailable.',
        );
      }
      if (owner.needsReadback) return retry('invoice-edit');
      try {
        final active = owner.activeInvoicePosting(value.id);
        if (active == null) {
          return const CapabilityFailure(
            'missing_original_posting',
            'Original invoice posting is unavailable.',
          );
        }
        final intent = owner.editInvoiceIntent(
          operationId: CatalogFormatters.generateId('invoice-edit-op'),
          invoiceId: value.id,
          expectedSource: value.expectedSource!,
          expectedActiveJournalId: active.journal.id,
          inverseJournalId: CatalogFormatters.generateId('invoice-inverse'),
          replacementJournalId: CatalogFormatters.generateId(
            'invoice-replacement',
          ),
          supplierId: value.supplierId,
          invoiceNumber: value.number,
          date: date(value.date),
          lines: value.lines,
          note: value.note,
          reason: value.reason,
          recordedAt: CatalogFormatters.currentIsoTimestamp(),
        );
        _pendingKind = 'invoice-edit';
        return _result(await owner.submitInvoiceCorrection(intent));
      } on Object {
        return const CapabilityFailure(
          'invalid_invoice_correction',
          'Invoice correction values are invalid.',
        );
      }
    }
    final owner = operations;
    if (owner == null) {
      return const CapabilityFailure(
        'posting_unavailable',
        'Financial posting is not active.',
      );
    }
    if (owner.needsReadback) return retry('invoice');
    try {
      final intent = owner.purchaseInvoiceIntent(
        operationId: CatalogFormatters.generateId('invoice-op'),
        invoiceId: value.id,
        invoiceJournalId: CatalogFormatters.generateId('invoice-journal'),
        supplierId: value.supplierId,
        invoiceNumber: value.number,
        date: date(value.date),
        lines: value.lines,
        note: value.note,
        immediatePayment: value.immediatePayment,
        paymentJournalId: value.immediatePayment == null
            ? null
            : CatalogFormatters.generateId('payment-journal'),
        recordedAt: CatalogFormatters.currentIsoTimestamp(),
      );
      _pendingKind = 'invoice';
      return _result(await owner.submitInvoice(intent));
    } on Object {
      return const CapabilityFailure(
        'invalid_invoice',
        'Invoice values are invalid.',
      );
    }
  }

  String? activePaymentJournal(String id) {
    final owner = operations;
    if (owner == null) return null;
    final state = const PortableJournalCodec().decodeState(
      owner.snapshot.payload,
    );
    for (final entry in state.journals) {
      if (entry.sourceRecordId == id &&
          [
            RestaurantJournalSourceType.supplierPayment.name,
            RestaurantJournalSourceType.correctionReplacement.name,
          ].contains(entry.sourceType) &&
          RestaurantJournalPaymentHistory.validate(
            state: state,
            paymentId: id,
            mapper: owner.spendingCommands.mapper,
            expectedActiveJournalId: entry.journal.id,
          )) {
        return entry.journal.id;
      }
    }
    return null;
  }

  SupplierLedgerQueries paymentQueries({String? excluding}) =>
      SupplierLedgerQueries(
        AccountDocument.canonical({
          ...account!.toJson(),
          'payments': rows('payments')
              .where((p) => p['id'] != excluding)
              .toList(),
        }, sourceVersion: 11),
        compareText: _noSort,
      );

  Future<CapabilityResult<void>> savePaymentCreate({
    required String supplierId,
    required String? invoiceId,
    required String categoryId,
    required String dateText,
    required String amountText,
    required String source,
    required String dailyText,
    required String cashText,
    required String note,
  }) async {
    final owner = operations;
    if (busy) {
      return const CapabilityFailure(
        'busy',
        'Another operation is in progress.',
      );
    }
    if (owner == null) {
      return const CapabilityFailure(
        'posting_unavailable',
        'Financial posting is not active.',
      );
    }
    if (owner.needsReadback) return retry('payment-create');
    try {
      final amount = money(amountText);
      final intent = owner.supplierPaymentIntent(
        operationId: CatalogFormatters.generateId('payment-op'),
        paymentId: CatalogFormatters.generateId('payment'),
        journalId: CatalogFormatters.generateId('payment-journal'),
        supplierId: supplierId,
        invoiceId: invoiceId,
        categoryId: categoryId,
        date: date(dateText),
        amount: BigInt.from(amount),
        fundingSource: FundingSource.values.byName(source),
        dailyAmount: BigInt.from(
          source == 'daily'
              ? amount
              : source == 'cash'
              ? 0
              : money(dailyText),
        ),
        cashAmount: BigInt.from(
          source == 'cash'
              ? amount
              : source == 'daily'
              ? 0
              : money(cashText),
        ),
        note: note,
        recordedAt: CatalogFormatters.currentIsoTimestamp(),
      );
      _pendingKind = 'payment-create';
      return _result(await owner.submitPayment(intent));
    } on Object {
      return const CapabilityFailure(
        'invalid_payment',
        'Payment values are invalid.',
      );
    }
  }

  Future<CapabilityResult<void>> savePaymentEdit({
    required Map<String, Object?> original,
    required String supplierId,
    required String? invoiceId,
    required String categoryId,
    required String dateText,
    required String amountText,
    required String source,
    required String dailyText,
    required String cashText,
    required String note,
    required String reason,
  }) async {
    final owner = operations;
    if (busy) {
      return const CapabilityFailure(
        'busy',
        'Another operation is in progress.',
      );
    }
    if (owner == null) {
      return const CapabilityFailure(
        'posting_unavailable',
        'Financial posting is not active.',
      );
    }
    if (owner.needsReadback) return retry('payment-edit');
    try {
      final id = original['id']! as String;
      final active = activePaymentJournal(id);
      if (active == null) {
        return const CapabilityFailure(
          'missing_original_posting',
          'Original posting is unavailable.',
        );
      }
      final amount = money(amountText);
      final payment = PurchasePayment(
        id: id,
        amount: amount,
        source: source,
        dailyAmount: source == 'daily'
            ? amount
            : source == 'cash'
            ? 0
            : money(dailyText),
        cashAmount: source == 'cash'
            ? amount
            : source == 'daily'
            ? 0
            : money(cashText),
      );
      final candidate = PurchaseProposals(account!).payment(
        payment: payment,
        supplierId: supplierId,
        invoiceId: invoiceId,
        categoryId: categoryId,
        date: dateText,
        createdAt: original['createdAt']! as String,
        note: note,
        editing: true,
      );
      final replacement = (candidate.toJson()['payments']! as List)
          .cast<Map<String, Object?>>()
          .firstWhere((p) => p['id'] == id);
      final intent = owner.editPaymentIntent(
        operationId: CatalogFormatters.generateId('payment-edit-op'),
        paymentId: id,
        expectedActiveJournalId: active,
        expectedSource: original,
        inverseJournalId: CatalogFormatters.generateId('payment-inverse'),
        replacementJournalId: CatalogFormatters.generateId(
          'payment-replacement',
        ),
        date: date(dateText),
        categoryId: categoryId,
        supplierId: supplierId,
        invoiceId: invoiceId,
        invoiceAmount: BigInt.from(replacement['invoiceAmount']! as int),
        debtAmount: BigInt.from(replacement['debtAmount']! as int),
        amount: BigInt.from(amount),
        fundingSource: FundingSource.values.byName(source),
        dailyAmount: BigInt.from(payment.dailyAmount),
        cashAmount: BigInt.from(payment.cashAmount),
        note: note,
        reason: reason,
        recordedAt: CatalogFormatters.currentIsoTimestamp(),
      );
      _pendingKind = 'payment-edit';
      return _result(await owner.submitPaymentCorrection(intent));
    } on Object {
      return const CapabilityFailure(
        'invalid_payment',
        'Payment correction values are invalid.',
      );
    }
  }

  Future<CapabilityResult<void>> deleteFinancial({
    required Map<String, Object?> original,
    required bool invoice,
    required String reason,
  }) async {
    final owner = operations;
    if (busy) {
      return const CapabilityFailure(
        'busy',
        'Another operation is in progress.',
      );
    }
    if (owner == null) {
      return const CapabilityFailure(
        'posting_unavailable',
        'Financial posting is not active.',
      );
    }
    final kind = invoice ? 'invoice-delete' : 'payment-delete';
    if (owner.needsReadback) return retry(kind);
    try {
      final id = original['id']! as String;
      final active = invoice
          ? owner.activeInvoicePosting(id)?.journal.id
          : activePaymentJournal(id);
      if (active == null) {
        return const CapabilityFailure(
          'missing_original_posting',
          'Original posting is unavailable.',
        );
      }
      _pendingKind = kind;
      if (invoice) {
        return _result(
          await owner.submitInvoiceCorrection(
            owner.deleteInvoiceIntent(
              operationId: CatalogFormatters.generateId(kind),
              invoiceId: id,
              expectedSource: original,
              expectedActiveJournalId: active,
              inverseJournalId: CatalogFormatters.generateId('invoice-inverse'),
              reason: reason,
              recordedAt: CatalogFormatters.currentIsoTimestamp(),
            ),
          ),
        );
      }
      return _result(
        await owner.submitPaymentCorrection(
          owner.deletePaymentIntent(
            operationId: CatalogFormatters.generateId(kind),
            paymentId: id,
            expectedSource: original,
            expectedActiveJournalId: active,
            inverseJournalId: CatalogFormatters.generateId('payment-inverse'),
            reason: reason,
            recordedAt: CatalogFormatters.currentIsoTimestamp(),
          ),
        ),
      );
    } on Object {
      return const CapabilityFailure(
        'invalid_correction',
        'Deletion was not confirmed.',
      );
    }
  }

  Future<CapabilityResult<void>> retry(String kind) async {
    if (_pendingKind != kind || operations == null) {
      return const CapabilityFailure(
        'other_pending_operation',
        'Resolve the existing operation first.',
      );
    }
    return _result(await operations!.retry());
  }

  CapabilityResult<void> _result(DurableCommandResult<dynamic> result) {
    switch (result) {
      case DurableCommandSuccess() || DurableCommandReplayed():
        _pendingKind = null;
        return const CapabilitySuccess(null);
      case DurableCommandFailure(:final code):
        if (!needsReadback) _pendingKind = null;
        return CapabilityFailure(
          code,
          'Financial operation was not confirmed.',
        );
    }
  }

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    metadata?.removeListener(_changed);
    operations?.removeListener(_changed);
    supplierOpenings?.removeListener(_changed);
    super.dispose();
  }
}
