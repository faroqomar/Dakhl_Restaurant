import 'dart:convert';

import 'package:madar_application/madar_application.dart';
import 'package:madar_domain/madar_domain.dart';

import '../accounts/account_document.dart';
import '../accounts/legacy_account_codec.dart';
import '../accounts/portable_journal_codec.dart';
import '../accounts/portable_journal_state.dart';
import '../parties/purchase_proposal.dart';
import '../parties/supplier_ledger.dart';
import 'journal_command_host.dart';
import 'restaurant_journal_expense_history.dart';
import 'restaurant_journal_mapper.dart';

/// Error codes emitted by the restaurant spending command layer.
abstract final class RestaurantJournalSpendingErrorCodes {
  static const accountLineageMismatch = 'account_lineage_mismatch';
  static const cutoverGated = 'cutover_gated';
  static const preCutoverOperationRejected = 'pre_cutover_operation_rejected';
  static const crossCutoverSourceHasNoPostCutoverJournal =
      'cross_cutover_source_has_no_post_cutover_journal';
  static const missingSupplier = 'missing_supplier';
  static const missingCategory = 'missing_category';
  static const invoiceNotFound = 'invoice_not_found';
  static const invalidInvoiceReference = 'invalid_invoice_reference';
  static const duplicateInvoiceNumber = 'duplicate_invoice_number';
  static const duplicateRecordId = 'duplicate_record_id';
  static const paymentExceedsLiability = 'payment_exceeds_liability';
  static const unverifiedHistoricalDebt = 'unverified_historical_debt';
  static const invalidPaymentDate = 'invalid_payment_date';
  static const invalidExpenseProposal = 'invalid_expense_proposal';
  static const invalidInvoiceProposal = 'invalid_invoice_proposal';
  static const invalidPaymentProposal = 'invalid_payment_proposal';
  static const expenseMappingFailed = 'expense_mapping_failed';
  static const invoiceMappingFailed = 'invoice_mapping_failed';
  static const paymentMappingFailed = 'payment_mapping_failed';
  static const zeroValueRequiresAllowZeroPolicy =
      'zero_value_requires_allow_zero_policy';
  static const invalidFundingSource = 'invalid_funding_source';
  static const invalidFundingAllocation = 'invalid_funding_allocation';
  static const negativePayment = 'negative_payment';
  static const invalidInvoicePosting = 'invoice_source_journal_mismatch';
  static const invalidPaymentPosting = 'payment_source_journal_mismatch';
  static const alreadyReversed = 'already_reversed';
}

/// Frozen, validated outcome of a committed or replayed spending command.
final class RestaurantJournalSpendingOutcome {
  RestaurantJournalSpendingOutcome({
    required this.commandType,
    required this.operationId,
    this.expenseId,
    this.invoiceId,
    this.invoiceNumber,
    this.supplierId,
    this.paymentId,
    required this.journalId,
    this.paymentJournalId,
    required this.effectiveDate,
    required this.netAmount,
    Map<String, Object?> metadata = const {},
  }) : metadata = freezeMap(metadata) {
    _metadataIdentity = canonicalIdentity(this.metadata);
  }

  final String commandType;
  final String operationId;
  final String? expenseId;
  final String? invoiceId;
  final String? invoiceNumber;
  final String? supplierId;
  final String? paymentId;
  final String journalId;
  final String? paymentJournalId;
  final String effectiveDate;
  final String netAmount;
  final Map<String, Object?> metadata;
  late final String _metadataIdentity;

  Map<String, Object?> toJson() => {
    'commandType': commandType,
    'operationId': operationId,
    'expenseId': ?expenseId,
    'invoiceId': ?invoiceId,
    'invoiceNumber': ?invoiceNumber,
    'supplierId': ?supplierId,
    'paymentId': ?paymentId,
    'journalId': journalId,
    'paymentJournalId': ?paymentJournalId,
    'effectiveDate': effectiveDate,
    'netAmount': netAmount,
    if (metadata.isNotEmpty) 'metadata': metadata,
  };

  String toOutcomePayload() => jsonEncode(toJson());

  factory RestaurantJournalSpendingOutcome.fromJson(Map<String, Object?> json) {
    const allowed = {
      'commandType',
      'operationId',
      'expenseId',
      'invoiceId',
      'invoiceNumber',
      'supplierId',
      'paymentId',
      'journalId',
      'paymentJournalId',
      'effectiveDate',
      'netAmount',
      'metadata',
    };
    if (!json.keys.every(allowed.contains)) {
      throw const FormatException('invalid_spending_outcome');
    }
    String text(String key) {
      final value = json[key];
      if (value is! String || value.isEmpty || value.trim() != value) {
        throw const FormatException('invalid_spending_outcome');
      }
      return value;
    }

    String? optional(String key) => json[key] == null ? null : text(key);
    final type = text('commandType'),
        date = text('effectiveDate'),
        amount = text('netAmount');
    if (!const {
          'operating_expense',
          'purchase_invoice',
          'supplier_payment',
        }.contains(type) ||
        !RegExp(r'^(0|[1-9][0-9]*)$').hasMatch(amount)) {
      throw const FormatException('invalid_spending_outcome');
    }
    DateOnly.parse(date, minimumYear: 1000, maximumYear: 9999);
    final metadata = json['metadata'];
    if (metadata != null && metadata is! Map<String, Object?>) {
      throw const FormatException('invalid_spending_outcome');
    }
    return RestaurantJournalSpendingOutcome(
      commandType: type,
      operationId: text('operationId'),
      expenseId: optional('expenseId'),
      invoiceId: optional('invoiceId'),
      invoiceNumber: optional('invoiceNumber'),
      supplierId: optional('supplierId'),
      paymentId: optional('paymentId'),
      journalId: text('journalId'),
      paymentJournalId: optional('paymentJournalId'),
      effectiveDate: date,
      netAmount: amount,
      metadata: metadata as Map<String, Object?>? ?? const {},
    );
  }

  factory RestaurantJournalSpendingOutcome.fromOutcomePayload(String payload) {
    final decoded = jsonDecode(payload) as Map<String, Object?>;
    return RestaurantJournalSpendingOutcome.fromJson(decoded);
  }

  @override
  bool operator ==(Object other) =>
      other is RestaurantJournalSpendingOutcome &&
      other.commandType == commandType &&
      other.operationId == operationId &&
      other.expenseId == expenseId &&
      other.invoiceId == invoiceId &&
      other.invoiceNumber == invoiceNumber &&
      other.supplierId == supplierId &&
      other.paymentId == paymentId &&
      other.journalId == journalId &&
      other.paymentJournalId == paymentJournalId &&
      other.effectiveDate == effectiveDate &&
      other.netAmount == netAmount &&
      other._metadataIdentity == _metadataIdentity;

  @override
  int get hashCode => Object.hash(
    commandType,
    operationId,
    expenseId,
    invoiceId,
    invoiceNumber,
    supplierId,
    paymentId,
    journalId,
    paymentJournalId,
    effectiveDate,
    netAmount,
    _metadataIdentity,
  );

  @override
  String toString() =>
      'RestaurantJournalSpendingOutcome(type: $commandType, details: redacted)';
}

/// Base sealed class for all durable spending operations.
sealed class RestaurantJournalSpendingCommand {
  const RestaurantJournalSpendingCommand({
    required this.operationId,
    required this.payloadVersion,
    required this.accountLineage,
    this.expectedFence,
    required this.recordedAt,
    this.policy,
  });

  final String operationId;
  final int payloadVersion;
  final String accountLineage;
  final StorageFence? expectedFence;
  final String recordedAt;
  final JournalPolicy? policy;

  String get commandType;
  String get canonicalPayloadIdentity;

  DurableCommandIdentity get identity => DurableCommandIdentity(
    operationId: operationId,
    payloadVersion: payloadVersion,
    canonicalPayloadIdentity: canonicalPayloadIdentity,
  );
}

/// Durable command to create an operating expense funded by daily cash, cashbox safe, or shared.
final class CreateOperatingExpenseCommand
    extends RestaurantJournalSpendingCommand {
  CreateOperatingExpenseCommand({
    required super.operationId,
    super.payloadVersion = 1,
    required super.accountLineage,
    super.expectedFence,
    required this.expenseId,
    required this.journalId,
    required this.date,
    required this.categoryId,
    required this.amount,
    required this.fundingSource,
    BigInt? dailyAmount,
    BigInt? cashAmount,
    this.note = '',
    required super.recordedAt,
    super.policy,
  }) : dailyAmount =
           dailyAmount ??
           (fundingSource == FundingSource.daily
               ? amount
               : fundingSource == FundingSource.cash
               ? BigInt.zero
               : throw const FormatException(
                   'dailyAmount required for shared funding',
                 )),
       cashAmount =
           cashAmount ??
           (fundingSource == FundingSource.cash
               ? amount
               : fundingSource == FundingSource.daily
               ? BigInt.zero
               : throw const FormatException(
                   'cashAmount required for shared funding',
                 )) {
    if (operationId.isEmpty || operationId.trim() != operationId) {
      throw const FormatException('Invalid operationId');
    }
    if (payloadVersion <= 0) {
      throw const FormatException('Payload version must be positive');
    }
    if (accountLineage.isEmpty || accountLineage.trim() != accountLineage) {
      throw const FormatException('Invalid accountLineage');
    }
    if (expenseId.isEmpty || expenseId.trim() != expenseId) {
      throw const FormatException('Invalid expenseId');
    }
    if (journalId.isEmpty || journalId.trim() != journalId) {
      throw const FormatException('Invalid journalId');
    }
    if (categoryId.isEmpty || categoryId.trim() != categoryId) {
      throw const FormatException('Invalid categoryId');
    }
    if (recordedAt.isEmpty || recordedAt.trim() != recordedAt) {
      throw const FormatException('Invalid recordedAt');
    }
    if (amount < BigInt.zero) {
      throw const FormatException('amount must be non-negative');
    }
    if (this.dailyAmount < BigInt.zero || this.cashAmount < BigInt.zero) {
      throw const FormatException('funding amounts must be non-negative');
    }
    if (this.dailyAmount + this.cashAmount != amount) {
      throw const FormatException(
        'dailyAmount + cashAmount must equal total amount',
      );
    }
    if (fundingSource == FundingSource.daily &&
        this.cashAmount != BigInt.zero) {
      throw const FormatException('Daily funding cannot have cash amount');
    }
    if (fundingSource == FundingSource.cash &&
        this.dailyAmount != BigInt.zero) {
      throw const FormatException('Cash funding cannot have daily amount');
    }

    canonicalPayloadIdentity = _computeCanonicalPayload(
      operationId: operationId,
      payloadVersion: payloadVersion,
      accountLineage: accountLineage,
      expectedFence: expectedFence,
      expenseId: expenseId,
      journalId: journalId,
      date: date,
      categoryId: categoryId,
      amount: amount,
      fundingSource: fundingSource,
      dailyAmount: this.dailyAmount,
      cashAmount: this.cashAmount,
      note: note,
      recordedAt: recordedAt,
      policy: policy,
    );
  }

  final String expenseId;
  final String journalId;
  final DateOnly date;
  final String categoryId;
  final BigInt amount;
  final FundingSource fundingSource;
  final BigInt dailyAmount;
  final BigInt cashAmount;
  final String note;

  @override
  late final String canonicalPayloadIdentity;

  @override
  String get commandType => 'operating_expense';

  static String _computeCanonicalPayload({
    required String operationId,
    required int payloadVersion,
    required String accountLineage,
    StorageFence? expectedFence,
    required String expenseId,
    required String journalId,
    required DateOnly date,
    required String categoryId,
    required BigInt amount,
    required FundingSource fundingSource,
    required BigInt dailyAmount,
    required BigInt cashAmount,
    required String note,
    required String recordedAt,
    JournalPolicy? policy,
  }) {
    final map = <String, Object?>{
      'accountLineage': accountLineage,
      'amount': amount.toString(),
      'cashAmount': cashAmount.toString(),
      'categoryId': categoryId,
      'commandType': 'operating_expense',
      'dailyAmount': dailyAmount.toString(),
      'date': date.toString(),
      if (expectedFence != null)
        'expectedFence': {
          'generation': expectedFence.generation,
          'storeId': expectedFence.storeId,
        },
      'expenseId': expenseId,
      'fundingSource': fundingSource.name,
      'journalId': journalId,
      'note': note,
      'operationId': operationId,
      'payloadVersion': payloadVersion,
      if (policy != null)
        'policy': {
          'allowZeroLines': policy.allowZeroLines,
          'currency': policy.currency,
          'maximumLines': policy.maximumLines,
          'maximumLineUnits': policy.maximumLineUnits.toString(),
          'maximumSideUnits': policy.maximumSideUnits.toString(),
          'scale': policy.scale,
        },
      'recordedAt': recordedAt,
    };
    return canonicalIdentity(map);
  }
}

/// Durable command to create a purchase invoice with independent carton/piece
/// pricing and optional immediate payment and inline materials.
final class CreatePurchaseInvoiceCommand
    extends RestaurantJournalSpendingCommand {
  CreatePurchaseInvoiceCommand({
    required super.operationId,
    super.payloadVersion = 1,
    required super.accountLineage,
    super.expectedFence,
    required this.invoiceId,
    required this.invoiceJournalId,
    required this.supplierId,
    required this.invoiceNumber,
    required this.date,
    required Iterable<PurchaseLine> lines,
    this.note = '',
    this.immediatePayment,
    this.paymentJournalId,
    required super.recordedAt,
    super.policy,
  }) : lines = freezeList(
         lines,
         maxCount: 200,
         errorCode: 'invalid_invoice_lines_count',
       ) {
    if (operationId.isEmpty || operationId.trim() != operationId) {
      throw const FormatException('Invalid operationId');
    }
    if (payloadVersion <= 0) {
      throw const FormatException('Payload version must be positive');
    }
    if (accountLineage.isEmpty || accountLineage.trim() != accountLineage) {
      throw const FormatException('Invalid accountLineage');
    }
    if (invoiceId.isEmpty || invoiceId.trim() != invoiceId) {
      throw const FormatException('Invalid invoiceId');
    }
    if (invoiceJournalId.isEmpty ||
        invoiceJournalId.trim() != invoiceJournalId) {
      throw const FormatException('Invalid invoiceJournalId');
    }
    if (supplierId.isEmpty || supplierId.trim() != supplierId) {
      throw const FormatException('Invalid supplierId');
    }
    if (invoiceNumber.trim().isEmpty) {
      throw const FormatException('Invalid invoiceNumber');
    }
    if (recordedAt.isEmpty || recordedAt.trim() != recordedAt) {
      throw const FormatException('Invalid recordedAt');
    }
    if (this.lines.isEmpty) {
      throw const FormatException('Invoice lines cannot be empty');
    }
    for (final line in this.lines) {
      if (line.name.trim().isEmpty || line.unit.trim().isEmpty) {
        throw const FormatException('Material name and unit required');
      }
      if (line.quantityCartons < 0 || line.quantityPieces < 0) {
        throw const FormatException('Line quantities must be non-negative');
      }
      if (line.priceCarton < 0 || line.pricePiece < 0) {
        throw const FormatException('Line prices must be non-negative');
      }
      if (line.quantityCartons + line.quantityPieces <= 0) {
        throw const FormatException(
          'Line must have positive quantity in cartons or pieces',
        );
      }
    }

    if (immediatePayment != null && immediatePayment!.amount > 0) {
      if (paymentJournalId == null ||
          paymentJournalId!.trim().isEmpty ||
          paymentJournalId!.trim() != paymentJournalId) {
        throw const FormatException(
          'paymentJournalId required for immediate payment',
        );
      }
      if (paymentJournalId == invoiceJournalId) {
        throw const FormatException(
          'paymentJournalId must differ from invoiceJournalId',
        );
      }
      if (immediatePayment!.id.isEmpty ||
          immediatePayment!.id.trim() != immediatePayment!.id) {
        throw const FormatException('Invalid immediate payment id');
      }
      if (immediatePayment!.amount < 0) {
        throw const FormatException(
          'immediate payment amount cannot be negative',
        );
      }
    }

    canonicalPayloadIdentity = _computeCanonicalPayload(
      operationId: operationId,
      payloadVersion: payloadVersion,
      accountLineage: accountLineage,
      expectedFence: expectedFence,
      invoiceId: invoiceId,
      invoiceJournalId: invoiceJournalId,
      supplierId: supplierId,
      invoiceNumber: invoiceNumber,
      date: date,
      lines: this.lines,
      note: note,
      immediatePayment: immediatePayment,
      paymentJournalId: paymentJournalId,
      recordedAt: recordedAt,
      policy: policy,
    );
  }

  final String invoiceId;
  final String invoiceJournalId;
  final String supplierId;
  final String invoiceNumber;
  final DateOnly date;
  final List<PurchaseLine> lines;
  final String note;
  final PurchasePayment? immediatePayment;
  final String? paymentJournalId;

  @override
  late final String canonicalPayloadIdentity;

  @override
  String get commandType => 'purchase_invoice';

  static String _computeCanonicalPayload({
    required String operationId,
    required int payloadVersion,
    required String accountLineage,
    StorageFence? expectedFence,
    required String invoiceId,
    required String invoiceJournalId,
    required String supplierId,
    required String invoiceNumber,
    required DateOnly date,
    required Iterable<PurchaseLine> lines,
    required String note,
    PurchasePayment? immediatePayment,
    String? paymentJournalId,
    required String recordedAt,
    JournalPolicy? policy,
  }) {
    final map = <String, Object?>{
      'accountLineage': accountLineage,
      'commandType': 'purchase_invoice',
      'date': date.toString(),
      if (expectedFence != null)
        'expectedFence': {
          'generation': expectedFence.generation,
          'storeId': expectedFence.storeId,
        },
      if (immediatePayment != null)
        'immediatePayment': {
          'amount': immediatePayment.amount,
          'cashAmount': immediatePayment.cashAmount,
          'dailyAmount': immediatePayment.dailyAmount,
          'id': immediatePayment.id,
          'source': immediatePayment.source,
        },
      'invoiceId': invoiceId,
      'invoiceJournalId': invoiceJournalId,
      'invoiceNumber': invoiceNumber,
      'lines': [
        for (final l in lines)
          {
            'materialIdForCreation': l.materialIdForCreation,
            'name': l.name,
            'priceCarton': l.priceCarton,
            'pricePiece': l.pricePiece,
            'quantityCartons': l.quantityCartons.toString(),
            'quantityPieces': l.quantityPieces.toString(),
            'unit': l.unit,
          },
      ],
      'note': note,
      'operationId': operationId,
      'payloadVersion': payloadVersion,
      'paymentJournalId': ?paymentJournalId,
      if (policy != null)
        'policy': {
          'allowZeroLines': policy.allowZeroLines,
          'currency': policy.currency,
          'maximumLines': policy.maximumLines,
          'maximumLineUnits': policy.maximumLineUnits.toString(),
          'maximumSideUnits': policy.maximumSideUnits.toString(),
          'scale': policy.scale,
        },
      'recordedAt': recordedAt,
      'supplierId': supplierId,
    };
    return canonicalIdentity(map);
  }
}

/// Durable command to create a separate supplier payment settling invoice liability
/// or verified historical debt without recognizing a second purchase expense.
final class CreateSupplierPaymentCommand
    extends RestaurantJournalSpendingCommand {
  CreateSupplierPaymentCommand({
    required super.operationId,
    super.payloadVersion = 1,
    required super.accountLineage,
    super.expectedFence,
    required this.paymentId,
    required this.journalId,
    required this.supplierId,
    this.invoiceId,
    required this.date,
    required this.amount,
    required this.fundingSource,
    BigInt? dailyAmount,
    BigInt? cashAmount,
    this.note = '',
    required super.recordedAt,
    super.policy,
  }) : dailyAmount =
           dailyAmount ??
           (fundingSource == FundingSource.daily
               ? amount
               : fundingSource == FundingSource.cash
               ? BigInt.zero
               : throw const FormatException(
                   'dailyAmount required for shared funding',
                 )),
       cashAmount =
           cashAmount ??
           (fundingSource == FundingSource.cash
               ? amount
               : fundingSource == FundingSource.daily
               ? BigInt.zero
               : throw const FormatException(
                   'cashAmount required for shared funding',
                 )) {
    if (operationId.isEmpty || operationId.trim() != operationId) {
      throw const FormatException('Invalid operationId');
    }
    if (payloadVersion <= 0) {
      throw const FormatException('Payload version must be positive');
    }
    if (accountLineage.isEmpty || accountLineage.trim() != accountLineage) {
      throw const FormatException('Invalid accountLineage');
    }
    if (paymentId.isEmpty || paymentId.trim() != paymentId) {
      throw const FormatException('Invalid paymentId');
    }
    if (journalId.isEmpty || journalId.trim() != journalId) {
      throw const FormatException('Invalid journalId');
    }
    if (supplierId.isEmpty || supplierId.trim() != supplierId) {
      throw const FormatException('Invalid supplierId');
    }
    if (invoiceId != null &&
        (invoiceId!.isEmpty || invoiceId!.trim() != invoiceId)) {
      throw const FormatException('Invalid invoiceId');
    }
    if (recordedAt.isEmpty || recordedAt.trim() != recordedAt) {
      throw const FormatException('Invalid recordedAt');
    }
    if (amount < BigInt.zero) {
      throw const FormatException('amount must be non-negative');
    }
    if (this.dailyAmount < BigInt.zero || this.cashAmount < BigInt.zero) {
      throw const FormatException('funding amounts must be non-negative');
    }
    if (this.dailyAmount + this.cashAmount != amount) {
      throw const FormatException(
        'dailyAmount + cashAmount must equal total amount',
      );
    }
    if (fundingSource == FundingSource.daily &&
        this.cashAmount != BigInt.zero) {
      throw const FormatException('Daily funding cannot have cash amount');
    }
    if (fundingSource == FundingSource.cash &&
        this.dailyAmount != BigInt.zero) {
      throw const FormatException('Cash funding cannot have daily amount');
    }

    canonicalPayloadIdentity = _computeCanonicalPayload(
      operationId: operationId,
      payloadVersion: payloadVersion,
      accountLineage: accountLineage,
      expectedFence: expectedFence,
      paymentId: paymentId,
      journalId: journalId,
      supplierId: supplierId,
      invoiceId: invoiceId,
      date: date,
      amount: amount,
      fundingSource: fundingSource,
      dailyAmount: this.dailyAmount,
      cashAmount: this.cashAmount,
      note: note,
      recordedAt: recordedAt,
      policy: policy,
    );
  }

  final String paymentId;
  final String journalId;
  final String supplierId;
  final String? invoiceId;
  final DateOnly date;
  final BigInt amount;
  final FundingSource fundingSource;
  final BigInt dailyAmount;
  final BigInt cashAmount;
  final String note;

  @override
  late final String canonicalPayloadIdentity;

  @override
  String get commandType => 'supplier_payment';

  static String _computeCanonicalPayload({
    required String operationId,
    required int payloadVersion,
    required String accountLineage,
    StorageFence? expectedFence,
    required String paymentId,
    required String journalId,
    required String supplierId,
    String? invoiceId,
    required DateOnly date,
    required BigInt amount,
    required FundingSource fundingSource,
    required BigInt dailyAmount,
    required BigInt cashAmount,
    required String note,
    required String recordedAt,
    JournalPolicy? policy,
  }) {
    final map = <String, Object?>{
      'accountLineage': accountLineage,
      'amount': amount.toString(),
      'cashAmount': cashAmount.toString(),
      'commandType': 'supplier_payment',
      'dailyAmount': dailyAmount.toString(),
      'date': date.toString(),
      if (expectedFence != null)
        'expectedFence': {
          'generation': expectedFence.generation,
          'storeId': expectedFence.storeId,
        },
      'fundingSource': fundingSource.name,
      'invoiceId': ?invoiceId,
      'journalId': journalId,
      'note': note,
      'operationId': operationId,
      'payloadVersion': payloadVersion,
      'paymentId': paymentId,
      if (policy != null)
        'policy': {
          'allowZeroLines': policy.allowZeroLines,
          'currency': policy.currency,
          'maximumLines': policy.maximumLines,
          'maximumLineUnits': policy.maximumLineUnits.toString(),
          'maximumSideUnits': policy.maximumSideUnits.toString(),
          'scale': policy.scale,
        },
      'recordedAt': recordedAt,
      'supplierId': supplierId,
    };
    return canonicalIdentity(map);
  }
}

/// Coordinates atomic execution, idempotency, lineage enforcement, and
/// cutover gating for restaurant spending commands against a single store owner.
final class RestaurantJournalSpendingCommandCoordinator {
  RestaurantJournalSpendingCommandCoordinator({
    required this.store,
    DurableCommandCoordinator? coordinator,
    RestaurantJournalMapper? mapper,
    PortableJournalCodec? codec,
    JournalCommandHost? host,
  }) : host =
           host ??
           JournalCommandHost(
             store: store,
             coordinator: coordinator,
             codec: codec,
           ),
       mapper = mapper ?? RestaurantJournalMapper() {
    if (!identical(this.host.store, store)) {
      throw ArgumentError('Command host must use the same store owner.');
    }
  }

  final LocalDocumentWorkspaceStore store;
  final JournalCommandHost host;
  final RestaurantJournalMapper mapper;
  PortableJournalCodec get codec => host.codec;
  DurableCommandCoordinator get coordinator => host.coordinator;

  /// Executes any [RestaurantJournalSpendingCommand].
  Future<DurableCommandResult<RestaurantJournalSpendingOutcome>> execute(
    RestaurantJournalSpendingCommand command,
  ) {
    return host.execute<RestaurantJournalSpendingOutcome>(
      identity: command.identity,
      accountLineage: command.accountLineage,
      expectedFence: command.expectedFence,
      missingAuthorityFenceMessage:
          'Capture account authority before submitting a spending command.',
      accountLineageMismatchCode:
          RestaurantJournalSpendingErrorCodes.accountLineageMismatch,
      cutoverGatedCode: RestaurantJournalSpendingErrorCodes.cutoverGated,
      validateReplayOutcome: (payload, state) {
        try {
          final outcome = RestaurantJournalSpendingOutcome.fromOutcomePayload(
            payload,
          );
          return _replayMatchesSource(command, outcome, state, mapper);
        } catch (_) {
          return false;
        }
      },
      parseOutcome: RestaurantJournalSpendingOutcome.fromOutcomePayload,
      evaluateProposal: (state, fence) => evaluateCommand(
        command: command,
        state: state,
        cutoverDate: state.cutoverState.cutoverDate!,
        mapper: mapper,
      ),
    );
  }

  /// Convenience method for operating expense.
  Future<DurableCommandResult<RestaurantJournalSpendingOutcome>> executeExpense(
    CreateOperatingExpenseCommand command,
  ) => execute(command);

  /// Convenience method for purchase invoice.
  Future<DurableCommandResult<RestaurantJournalSpendingOutcome>> executeInvoice(
    CreatePurchaseInvoiceCommand command,
  ) => execute(command);

  /// Convenience method for supplier payment.
  Future<DurableCommandResult<RestaurantJournalSpendingOutcome>> executePayment(
    CreateSupplierPaymentCommand command,
  ) => execute(command);

  static DurableProposalEvaluation<
    PortableJournalState,
    RestaurantJournalSpendingOutcome
  >
  evaluateCommand({
    required RestaurantJournalSpendingCommand command,
    required PortableJournalState state,
    required DateOnly cutoverDate,
    required RestaurantJournalMapper mapper,
  }) {
    switch (command) {
      case CreateOperatingExpenseCommand():
        return evaluateExpense(
          command: command,
          state: state,
          cutoverDate: cutoverDate,
          mapper: mapper,
        );
      case CreatePurchaseInvoiceCommand():
        return evaluateInvoice(
          command: command,
          state: state,
          cutoverDate: cutoverDate,
          mapper: mapper,
        );
      case CreateSupplierPaymentCommand():
        return evaluatePayment(
          command: command,
          state: state,
          cutoverDate: cutoverDate,
          mapper: mapper,
        );
    }
  }

  static DurableProposalEvaluation<
    PortableJournalState,
    RestaurantJournalSpendingOutcome
  >
  evaluateExpense({
    required CreateOperatingExpenseCommand command,
    required PortableJournalState state,
    required DateOnly cutoverDate,
    required RestaurantJournalMapper mapper,
  }) {
    if (command.date.compareTo(cutoverDate) < 0) {
      return const DurableProposalEvaluation.reject(
        rejectionCode:
            RestaurantJournalSpendingErrorCodes.preCutoverOperationRejected,
        rejectionMessage: 'Expense date precedes established cutover date.',
      );
    }

    final categories = state.account.categories;
    if (!categories.any((c) => c['id'] == command.categoryId)) {
      return const DurableProposalEvaluation.reject(
        rejectionCode: RestaurantJournalSpendingErrorCodes.missingCategory,
        rejectionMessage: 'Category not found.',
      );
    }

    final accountJson = state.account.toJson();
    final rawDays = (accountJson['days'] as Map).cast<String, Object?>();
    for (final entry in rawDays.entries) {
      final d = entry.value as Map<String, Object?>;
      final expenses = (d['expenses'] as List).cast<Map<String, Object?>>();
      if (expenses.any((e) => e['id'] == command.expenseId)) {
        return const DurableProposalEvaluation.reject(
          rejectionCode: RestaurantJournalSpendingErrorCodes.duplicateRecordId,
          rejectionMessage: 'Expense id already exists.',
        );
      }
    }

    if (state.journals.any((j) => j.journal.id == command.journalId)) {
      return const DurableProposalEvaluation.reject(
        rejectionCode: RestaurantJournalSpendingErrorCodes.duplicateRecordId,
        rejectionMessage: 'Journal id already exists.',
      );
    }

    RestaurantJournalProposal journalProposal;
    try {
      journalProposal = mapper.mapOperatingExpense(
        journalId: command.journalId,
        expenseId: command.expenseId,
        effectiveDate: command.date,
        categoryId: command.categoryId,
        amount: command.amount,
        dailyAmount: command.dailyAmount,
        cashboxAmount: command.cashAmount,
        policy: command.policy,
      );
    } on RestaurantJournalMappingException catch (e) {
      return DurableProposalEvaluation.reject(
        rejectionCode: e.code,
        rejectionMessage: e.toString(),
      );
    } catch (e) {
      return DurableProposalEvaluation.reject(
        rejectionCode: RestaurantJournalSpendingErrorCodes.expenseMappingFailed,
        rejectionMessage: e.toString(),
      );
    }

    final dateKey = command.date.toString();
    final dayMap = rawDays.containsKey(dateKey)
        ? Map<String, Object?>.from(rawDays[dateKey]! as Map<String, Object?>)
        : <String, Object?>{
            'expenses': <Map<String, Object?>>[],
            'chickenUsed': 0,
            'chickenLeft': 0,
            'balance': null,
            'totalOverride': null,
            'remaining': null,
            'corrections': <Object?>[],
          };

    final dayExpenses = [
      ...(dayMap['expenses'] as List).cast<Map<String, Object?>>(),
      <String, Object?>{
        'id': command.expenseId,
        'categoryId': command.categoryId,
        'amount': command.amount.toInt(),
        'note': LegacyText.trimJavaScript(command.note),
        'funding': {
          'source': command.fundingSource.name,
          'dailyAmount': command.dailyAmount.toInt(),
          'cashAmount': command.cashAmount.toInt(),
        },
        'createdAt': command.recordedAt,
      },
    ];

    dayMap['expenses'] = dayExpenses;
    final updatedDays = Map<String, Object?>.from(rawDays)..[dateKey] = dayMap;

    AccountDocument candidateAccount;
    try {
      candidateAccount = const LegacyAccountCodec().decodeJson({
        ...accountJson,
        'days': updatedDays,
      });
    } catch (e) {
      return DurableProposalEvaluation.reject(
        rejectionCode:
            RestaurantJournalSpendingErrorCodes.invalidExpenseProposal,
        rejectionMessage: e.toString(),
      );
    }

    final metadata = _expenseMetadata(
      command,
      _expenseRecord(candidateAccount, command.date, command.expenseId),
      journalProposal.sourceVersion,
    );

    final entry = PortableJournalEntry(
      journal: journalProposal.journal,
      sourceType: journalProposal.sourceType.name,
      sourceRecordId: command.expenseId,
      recordedAt: command.recordedAt,
      metadata: metadata,
    );

    final candidateState = state.copyWith(
      account: candidateAccount,
      journals: [...state.journals, entry],
    );

    final outcome = RestaurantJournalSpendingOutcome(
      commandType: command.commandType,
      operationId: command.operationId,
      expenseId: command.expenseId,
      journalId: command.journalId,
      effectiveDate: command.date.toString(),
      netAmount: command.amount.toString(),
      metadata: metadata,
    );

    return DurableProposalEvaluation.accept(
      candidateState: candidateState,
      outcome: outcome,
      outcomePayload: outcome.toOutcomePayload(),
    );
  }

  static DurableProposalEvaluation<
    PortableJournalState,
    RestaurantJournalSpendingOutcome
  >
  evaluateInvoice({
    required CreatePurchaseInvoiceCommand command,
    required PortableJournalState state,
    required DateOnly cutoverDate,
    required RestaurantJournalMapper mapper,
  }) {
    if (command.date.compareTo(cutoverDate) < 0) {
      return const DurableProposalEvaluation.reject(
        rejectionCode:
            RestaurantJournalSpendingErrorCodes.preCutoverOperationRejected,
        rejectionMessage: 'Invoice date precedes established cutover date.',
      );
    }

    final suppliers = (state.account.toJson()['suppliers'] as List)
        .cast<Map<String, Object?>>();
    final matchingSupplier = suppliers
        .where((s) => s['id'] == command.supplierId)
        .toList();
    if (matchingSupplier.isEmpty) {
      return const DurableProposalEvaluation.reject(
        rejectionCode: RestaurantJournalSpendingErrorCodes.missingSupplier,
        rejectionMessage: 'Supplier not found.',
      );
    }

    final invoices = (state.account.toJson()['invoices'] as List)
        .cast<Map<String, Object?>>();
    if (invoices.any((i) => i['id'] == command.invoiceId)) {
      return const DurableProposalEvaluation.reject(
        rejectionCode: RestaurantJournalSpendingErrorCodes.duplicateRecordId,
        rejectionMessage: 'Invoice id already exists.',
      );
    }

    final payments = (state.account.toJson()['payments'] as List)
        .cast<Map<String, Object?>>();
    if (command.immediatePayment != null &&
        payments.any((p) => p['id'] == command.immediatePayment!.id)) {
      return const DurableProposalEvaluation.reject(
        rejectionCode: RestaurantJournalSpendingErrorCodes.duplicateRecordId,
        rejectionMessage: 'Immediate payment id already exists.',
      );
    }

    if (state.journals.any((j) => j.journal.id == command.invoiceJournalId)) {
      return const DurableProposalEvaluation.reject(
        rejectionCode: RestaurantJournalSpendingErrorCodes.duplicateRecordId,
        rejectionMessage: 'Invoice journal id already exists.',
      );
    }

    if (command.paymentJournalId != null &&
        state.journals.any((j) => j.journal.id == command.paymentJournalId)) {
      return const DurableProposalEvaluation.reject(
        rejectionCode: RestaurantJournalSpendingErrorCodes.duplicateRecordId,
        rejectionMessage: 'Payment journal id already exists.',
      );
    }

    final normalizedNumber = _normalizedInvoiceNumber(command.invoiceNumber);
    if (invoices.any(
      (i) =>
          i['supplierId'] == command.supplierId &&
          _normalizedInvoiceNumber(i['number'] as String) == normalizedNumber,
    )) {
      return const DurableProposalEvaluation.reject(
        rejectionCode:
            RestaurantJournalSpendingErrorCodes.duplicateInvoiceNumber,
        rejectionMessage: 'Duplicate invoice number for supplier.',
      );
    }
    final ledgerQueries = _unorderedQueries(state.account);

    final rawInvoiceLines = [
      for (final l in command.lines)
        {
          'materialId': l.materialIdForCreation,
          'name': l.name,
          'unit': l.unit,
          'quantityCartons': l.quantityCartons,
          'quantityPieces': l.quantityPieces,
          'priceCarton': l.priceCarton,
          'pricePiece': l.pricePiece,
        },
    ];

    final invoiceTotal = ledgerQueries.invoiceTotal({'lines': rawInvoiceLines});

    if (invoiceTotal == BigInt.zero && command.policy?.allowZeroLines != true) {
      return const DurableProposalEvaluation.reject(
        rejectionCode: RestaurantJournalSpendingErrorCodes
            .zeroValueRequiresAllowZeroPolicy,
        rejectionMessage: 'Zero invoice total requires allowZeroLines policy.',
      );
    }

    if (command.immediatePayment != null) {
      if (command.immediatePayment!.amount < 0) {
        return const DurableProposalEvaluation.reject(
          rejectionCode: RestaurantJournalSpendingErrorCodes.negativePayment,
          rejectionMessage: 'Immediate payment amount cannot be negative.',
        );
      }
      if (BigInt.from(command.immediatePayment!.amount) > invoiceTotal) {
        return const DurableProposalEvaluation.reject(
          rejectionCode:
              RestaurantJournalSpendingErrorCodes.paymentExceedsLiability,
          rejectionMessage: 'Immediate payment exceeds invoice liability.',
        );
      }
    }

    AccountDocument candidateAccount;
    try {
      candidateAccount = PurchaseProposals(state.account).invoice(
        id: command.invoiceId,
        supplierId: command.supplierId,
        number: command.invoiceNumber,
        date: command.date.toString(),
        createdAt: command.recordedAt,
        lines: command.lines,
        note: command.note,
        immediatePayment: command.immediatePayment,
      );
    } on FormatException catch (e) {
      final code = e.message;
      return DurableProposalEvaluation.reject(
        rejectionCode: code == 'duplicate_invoice_number'
            ? RestaurantJournalSpendingErrorCodes.duplicateInvoiceNumber
            : code == 'missing_supplier'
            ? RestaurantJournalSpendingErrorCodes.missingSupplier
            : code == 'payment_exceeds_liability'
            ? RestaurantJournalSpendingErrorCodes.paymentExceedsLiability
            : RestaurantJournalSpendingErrorCodes.invalidInvoiceProposal,
        rejectionMessage: e.toString(),
      );
    } catch (e) {
      return DurableProposalEvaluation.reject(
        rejectionCode:
            RestaurantJournalSpendingErrorCodes.invalidInvoiceProposal,
        rejectionMessage: e.toString(),
      );
    }

    final savedInvoice = _sourceRecord(
      candidateAccount,
      'invoices',
      command.invoiceId,
    );
    final hasPayment =
        command.immediatePayment != null &&
        command.immediatePayment!.amount > 0;
    final savedPayment = hasPayment
        ? _sourceRecord(
            candidateAccount,
            'payments',
            command.immediatePayment!.id,
          )
        : null;

    RestaurantJournalProposal invoiceJournalProposal;
    try {
      invoiceJournalProposal = mapper.mapPurchaseInvoice(
        journalId: command.invoiceJournalId,
        invoiceId: command.invoiceId,
        invoiceNumber: savedInvoice['number'] as String,
        supplierId: command.supplierId,
        effectiveDate: command.date,
        amount: invoiceTotal,
        policy: command.policy,
      );
    } on RestaurantJournalMappingException catch (e) {
      return DurableProposalEvaluation.reject(
        rejectionCode: e.code,
        rejectionMessage: e.toString(),
      );
    } catch (e) {
      return DurableProposalEvaluation.reject(
        rejectionCode: RestaurantJournalSpendingErrorCodes.invoiceMappingFailed,
        rejectionMessage: e.toString(),
      );
    }

    final invoiceMetadata = _invoiceMetadata(
      command,
      savedInvoice,
      savedPayment,
      invoiceTotal,
      invoiceJournalProposal.sourceVersion,
    );

    final invoiceEntry = PortableJournalEntry(
      journal: invoiceJournalProposal.journal,
      sourceType: invoiceJournalProposal.sourceType.name,
      sourceRecordId: command.invoiceId,
      recordedAt: command.recordedAt,
      metadata: invoiceMetadata,
    );

    final newJournals = <PortableJournalEntry>[invoiceEntry];

    if (command.immediatePayment != null &&
        command.immediatePayment!.amount > 0) {
      final p = command.immediatePayment!;
      final source = FundingSource.values
          .where((s) => s.name == p.source)
          .single;
      final funding = CommerceCalculations.fundingSplit(
        amount: BigInt.from(p.amount),
        daily: BigInt.from(
          p.source == 'daily'
              ? p.amount
              : p.source == 'cash'
              ? 0
              : p.dailyAmount,
        ),
        cash: BigInt.from(
          p.source == 'cash'
              ? p.amount
              : p.source == 'daily'
              ? 0
              : p.cashAmount,
        ),
        source: source,
        policy: CommercePolicy(
          quantityScale: 3,
          maximumQuantityUnits: RestaurantJournalPolicies.defaultLimit,
          maximumMoney: RestaurantJournalPolicies.defaultLimit,
          maximumSafeInteger: RestaurantJournalPolicies.maximumSafeAggregate,
          rounding: DecimalRounding.halfTowardPositiveInfinity,
        ),
      );

      RestaurantJournalProposal paymentJournalProposal;
      try {
        paymentJournalProposal = mapper.mapSupplierPayment(
          journalId: command.paymentJournalId!,
          paymentId: p.id,
          supplierId: command.supplierId,
          effectiveDate: command.date,
          amount: BigInt.from(p.amount),
          dailyAmount: funding.daily,
          cashboxAmount: funding.cash,
          invoiceSettledAmount: BigInt.from(p.amount),
          debtSettledAmount: BigInt.zero,
          invoiceId: command.invoiceId,
          policy: command.policy,
        );
      } on RestaurantJournalMappingException catch (e) {
        return DurableProposalEvaluation.reject(
          rejectionCode: e.code,
          rejectionMessage: e.toString(),
        );
      } catch (e) {
        return DurableProposalEvaluation.reject(
          rejectionCode:
              RestaurantJournalSpendingErrorCodes.paymentMappingFailed,
          rejectionMessage: e.toString(),
        );
      }

      final paymentMetadata = _paymentMetadata(
        command.operationId,
        savedPayment!,
        paymentJournalProposal.sourceVersion,
        immediate: true,
      );

      final paymentEntry = PortableJournalEntry(
        journal: paymentJournalProposal.journal,
        sourceType: paymentJournalProposal.sourceType.name,
        sourceRecordId: p.id,
        recordedAt: command.recordedAt,
        metadata: paymentMetadata,
      );

      newJournals.add(paymentEntry);
    }

    final candidateState = state.copyWith(
      account: candidateAccount,
      journals: [...state.journals, ...newJournals],
    );

    final outcome = RestaurantJournalSpendingOutcome(
      commandType: command.commandType,
      operationId: command.operationId,
      invoiceId: command.invoiceId,
      invoiceNumber: savedInvoice['number'] as String,
      supplierId: command.supplierId,
      paymentId: hasPayment ? command.immediatePayment!.id : null,
      journalId: command.invoiceJournalId,
      paymentJournalId: hasPayment ? command.paymentJournalId : null,
      effectiveDate: command.date.toString(),
      netAmount: invoiceTotal.toString(),
      metadata: invoiceMetadata,
    );

    return DurableProposalEvaluation.accept(
      candidateState: candidateState,
      outcome: outcome,
      outcomePayload: outcome.toOutcomePayload(),
    );
  }

  static DurableProposalEvaluation<
    PortableJournalState,
    RestaurantJournalSpendingOutcome
  >
  evaluatePayment({
    required CreateSupplierPaymentCommand command,
    required PortableJournalState state,
    required DateOnly cutoverDate,
    required RestaurantJournalMapper mapper,
  }) {
    if (command.date.compareTo(cutoverDate) < 0) {
      return const DurableProposalEvaluation.reject(
        rejectionCode:
            RestaurantJournalSpendingErrorCodes.preCutoverOperationRejected,
        rejectionMessage: 'Payment date precedes established cutover date.',
      );
    }

    final suppliers = (state.account.toJson()['suppliers'] as List)
        .cast<Map<String, Object?>>();
    final matchingSupplier = suppliers
        .where((s) => s['id'] == command.supplierId)
        .toList();
    if (matchingSupplier.isEmpty) {
      return const DurableProposalEvaluation.reject(
        rejectionCode: RestaurantJournalSpendingErrorCodes.missingSupplier,
        rejectionMessage: 'Supplier not found.',
      );
    }

    final payments = (state.account.toJson()['payments'] as List)
        .cast<Map<String, Object?>>();
    if (payments.any((p) => p['id'] == command.paymentId)) {
      return const DurableProposalEvaluation.reject(
        rejectionCode: RestaurantJournalSpendingErrorCodes.duplicateRecordId,
        rejectionMessage: 'Payment id already exists.',
      );
    }

    if (state.journals.any((j) => j.journal.id == command.journalId)) {
      return const DurableProposalEvaluation.reject(
        rejectionCode: RestaurantJournalSpendingErrorCodes.duplicateRecordId,
        rejectionMessage: 'Payment journal id already exists.',
      );
    }

    if (command.invoiceId != null) {
      final matchingInvoice = _sourceRows(
        state.account,
        'invoices',
      ).where((i) => i['id'] == command.invoiceId).toList();
      if (matchingInvoice.length != 1 ||
          matchingInvoice.single['supplierId'] != command.supplierId) {
        return const DurableProposalEvaluation.reject(
          rejectionCode:
              RestaurantJournalSpendingErrorCodes.invalidInvoiceReference,
          rejectionMessage:
              'Target invoice not found or belongs to another supplier.',
        );
      }
      final invoice = matchingInvoice.single;
      if (command.date.toString().compareTo(invoice['date'] as String) < 0) {
        return const DurableProposalEvaluation.reject(
          rejectionCode: RestaurantJournalSpendingErrorCodes.invalidPaymentDate,
          rejectionMessage: 'Payment date cannot precede invoice date.',
        );
      }
      final postings = state.journals
          .where(
            (j) =>
                j.sourceRecordId == command.invoiceId &&
                j.sourceType ==
                    RestaurantJournalSourceType.purchaseInvoice.name &&
                j.journal.reversesId == null &&
                j.journal.effectiveDate.compareTo(cutoverDate) >= 0,
          )
          .toList();
      if (postings.isEmpty) {
        return const DurableProposalEvaluation.reject(
          rejectionCode: RestaurantJournalSpendingErrorCodes
              .crossCutoverSourceHasNoPostCutoverJournal,
          rejectionMessage:
              'Target invoice has no eligible post-cutover posting.',
        );
      }
      if (postings.length != 1 ||
          !_invoicePostingMatchesSource(
            postings.single,
            invoice,
            mapper,
            state.account,
          )) {
        return const DurableProposalEvaluation.reject(
          rejectionCode:
              RestaurantJournalSpendingErrorCodes.invalidInvoicePosting,
          rejectionMessage:
              'Invoice source does not match a unique liability posting.',
        );
      }
      if (_isReversed(state, postings.single)) {
        return const DurableProposalEvaluation.reject(
          rejectionCode: RestaurantJournalSpendingErrorCodes.alreadyReversed,
          rejectionMessage:
              'Invoice liability posting has already been reversed.',
        );
      }
      for (final prior in payments.where(
        (p) => p['invoiceId'] == command.invoiceId,
      )) {
        if (!_paymentHasValidPosting(state, prior, mapper)) {
          return const DurableProposalEvaluation.reject(
            rejectionCode:
                RestaurantJournalSpendingErrorCodes.invalidPaymentPosting,
            rejectionMessage:
                'A source settlement lacks a matching active payment posting.',
          );
        }
      }
    }

    if (command.amount == BigInt.zero &&
        command.policy?.allowZeroLines != true) {
      return const DurableProposalEvaluation.reject(
        rejectionCode: RestaurantJournalSpendingErrorCodes
            .zeroValueRequiresAllowZeroPolicy,
        rejectionMessage: 'Zero payment requires allowZeroLines policy.',
      );
    }

    AccountDocument candidateAccount;
    try {
      candidateAccount = PurchaseProposals(state.account).payment(
        payment: PurchasePayment(
          id: command.paymentId,
          amount: command.amount.toInt(),
          source: command.fundingSource.name,
          dailyAmount: command.dailyAmount.toInt(),
          cashAmount: command.cashAmount.toInt(),
        ),
        supplierId: command.supplierId,
        invoiceId: command.invoiceId,
        categoryId: matchingSupplier.first['categoryId']! as String,
        date: command.date.toString(),
        createdAt: command.recordedAt,
        note: command.note,
      );
    } on DomainValidationException catch (e) {
      return DurableProposalEvaluation.reject(
        rejectionCode: e.code == 'payment_exceeds_liability'
            ? RestaurantJournalSpendingErrorCodes.paymentExceedsLiability
            : RestaurantJournalSpendingErrorCodes.invalidPaymentProposal,
        rejectionMessage: e.code,
      );
    } on FormatException catch (e) {
      final code = e.message;
      return DurableProposalEvaluation.reject(
        rejectionCode: code == 'payment_exceeds_liability'
            ? RestaurantJournalSpendingErrorCodes.paymentExceedsLiability
            : code == 'invalid_invoice_reference'
            ? RestaurantJournalSpendingErrorCodes.invalidInvoiceReference
            : RestaurantJournalSpendingErrorCodes.invalidPaymentProposal,
        rejectionMessage: e.toString(),
      );
    } catch (e) {
      return DurableProposalEvaluation.reject(
        rejectionCode:
            RestaurantJournalSpendingErrorCodes.invalidPaymentProposal,
        rejectionMessage: e.toString(),
      );
    }

    final savedPayment = _sourceRecord(
      candidateAccount,
      'payments',
      command.paymentId,
    );
    final invoiceSettled = BigInt.from(savedPayment['invoiceAmount'] as int);
    final debtSettled = BigInt.from(savedPayment['debtAmount'] as int);
    if (debtSettled > BigInt.zero) {
      final openings = state.journals
          .where((j) => j.journal.id == state.cutoverState.openingJournalId)
          .toList();
      if (openings.length != 1 || _isReversed(state, openings.single)) {
        return const DurableProposalEvaluation.reject(
          rejectionCode:
              RestaurantJournalSpendingErrorCodes.unverifiedHistoricalDebt,
          rejectionMessage: 'No verified opening liability is available.',
        );
      }
      final opening = openings.single;
      final liabilityAccount = mapper.profile.supplierLiabilityAccountId(
        command.supplierId,
      );
      var availableDebt = ExactMath.checkedSum(
        opening.journal.lines
            .where((l) => l.accountId == liabilityAccount)
            .map(
              (l) =>
                  l.side == JournalSide.credit ? l.amountUnits : -l.amountUnits,
            ),
        maxAbs: RestaurantJournalPolicies.maximumSafeAggregate,
        maxSafeInteger: RestaurantJournalPolicies.maximumSafeAggregate,
      );
      // The opening already includes all pre-cutover settlements. Reserve all
      // recorded post-cutover payments, including future dates, as the source
      // allocator does; ignoring them would authorize a second settlement.
      for (final prior in payments.where(
        (p) =>
            p['supplierId'] == command.supplierId &&
            (p['date'] as String).compareTo(cutoverDate.toString()) >= 0,
      )) {
        final settled = BigInt.from(prior['debtAmount'] as int);
        if (settled > BigInt.zero) {
          if (!_paymentHasValidPosting(state, prior, mapper)) {
            return const DurableProposalEvaluation.reject(
              rejectionCode:
                  RestaurantJournalSpendingErrorCodes.invalidPaymentPosting,
              rejectionMessage: 'A source debt settlement lacks a matching active payment posting.',
            );
          }
          availableDebt -= settled;
        }
      }
      if (availableDebt <= BigInt.zero) {
        return const DurableProposalEvaluation.reject(
          rejectionCode:
              RestaurantJournalSpendingErrorCodes.unverifiedHistoricalDebt,
          rejectionMessage: 'Debt settlement requires an available verified opening liability.',
        );
      }
      if (debtSettled > availableDebt) {
        return const DurableProposalEvaluation.reject(
          rejectionCode:
              RestaurantJournalSpendingErrorCodes.paymentExceedsLiability,
          rejectionMessage:
              'Payment exceeds remaining verified opening liability.',
        );
      }
    }

    RestaurantJournalProposal journalProposal;
    try {
      journalProposal = mapper.mapSupplierPayment(
        journalId: command.journalId,
        paymentId: command.paymentId,
        supplierId: command.supplierId,
        effectiveDate: command.date,
        amount: command.amount,
        dailyAmount: command.dailyAmount,
        cashboxAmount: command.cashAmount,
        invoiceSettledAmount: invoiceSettled,
        debtSettledAmount: debtSettled,
        invoiceId: command.invoiceId,
        policy: command.policy,
      );
    } on RestaurantJournalMappingException catch (e) {
      return DurableProposalEvaluation.reject(
        rejectionCode: e.code,
        rejectionMessage: e.toString(),
      );
    } catch (e) {
      return DurableProposalEvaluation.reject(
        rejectionCode: RestaurantJournalSpendingErrorCodes.paymentMappingFailed,
        rejectionMessage: e.toString(),
      );
    }

    final metadata = _paymentMetadata(
      command.operationId,
      savedPayment,
      journalProposal.sourceVersion,
    );

    final entry = PortableJournalEntry(
      journal: journalProposal.journal,
      sourceType: journalProposal.sourceType.name,
      sourceRecordId: command.paymentId,
      recordedAt: command.recordedAt,
      metadata: metadata,
    );

    final candidateState = state.copyWith(
      account: candidateAccount,
      journals: [...state.journals, entry],
    );

    final outcome = RestaurantJournalSpendingOutcome(
      commandType: command.commandType,
      operationId: command.operationId,
      paymentId: command.paymentId,
      supplierId: command.supplierId,
      invoiceId: command.invoiceId,
      journalId: command.journalId,
      effectiveDate: command.date.toString(),
      netAmount: command.amount.toString(),
      metadata: metadata,
    );

    return DurableProposalEvaluation.accept(
      candidateState: candidateState,
      outcome: outcome,
      outcomePayload: outcome.toOutcomePayload(),
    );
  }
}

SupplierLedgerQueries _unorderedQueries(AccountDocument account) =>
    SupplierLedgerQueries(
      account,
      compareText: (_, _) =>
          throw StateError('No ordered queries in spending commands.'),
    );
List<Map<String, Object?>> _sourceRows(AccountDocument account, String key) =>
    (account.toJson()[key] as List).cast<Map<String, Object?>>();
Map<String, Object?> _sourceRecord(
  AccountDocument account,
  String key,
  String id,
) => _sourceRows(account, key).singleWhere((r) => r['id'] == id);
Map<String, Object?> _expenseRecord(
  AccountDocument account,
  DateOnly date,
  String id,
) =>
    ((((account.toJson()['days'] as Map)[date.toString()] as Map)['expenses']
                as List)
            .cast<Map<String, Object?>>())
        .singleWhere((r) => r['id'] == id);
String _normalizedInvoiceNumber(String value) => LegacyText.trimJavaScript(
  value.replaceAllMapped(RegExp('[\u0660-\u0669\u06f0-\u06f9]'), (m) {
    final c = m[0]!.codeUnitAt(0);
    return '${c >= 0x6f0 ? c - 0x6f0 : c - 0x660}';
  }),
);
bool _sameValue(Object? a, Object? b) =>
    canonicalIdentity({'value': a}) == canonicalIdentity({'value': b});
bool _isReversed(PortableJournalState state, PortableJournalEntry entry) =>
    state.journals.any((j) => j.journal.reversesId == entry.journal.id);

Map<String, Object?> _expenseMetadata(
  CreateOperatingExpenseCommand command,
  Map<String, Object?> source,
  int sourceVersion,
) => {
  'categoryId': command.categoryId,
  'amount': command.amount.toString(),
  'dailyAmount': command.dailyAmount.toString(),
  'cashAmount': command.cashAmount.toString(),
  'sourceVersion': sourceVersion,
  'operationId': command.operationId,
  'expenseId': command.expenseId,
  'sourceSnapshot': canonicalIdentity(source),
};
Map<String, Object?> _invoiceMetadata(
  CreatePurchaseInvoiceCommand command,
  Map<String, Object?> source,
  Map<String, Object?>? payment,
  BigInt amount,
  int sourceVersion,
) => {
  'supplierId': command.supplierId,
  'invoiceNumber': source['number'],
  'amount': amount.toString(),
  'sourceVersion': sourceVersion,
  'operationId': command.operationId,
  'invoiceId': command.invoiceId,
  'sourceSnapshot': canonicalIdentity(source),
  if (payment != null) 'immediatePaymentSnapshot': canonicalIdentity(payment),
};
Map<String, Object?> _paymentMetadata(
  String operationId,
  Map<String, Object?> source,
  int sourceVersion, {
  bool immediate = false,
}) {
  final funding = source['funding'] as Map;
  return {
    'supplierId': source['supplierId'],
    if (source['invoiceId'] != null) 'invoiceId': source['invoiceId'],
    'amount': '${source['amount']}',
    'invoiceSettledAmount': '${source['invoiceAmount']}',
    'debtSettledAmount': '${source['debtAmount']}',
    'dailyAmount': '${funding['dailyAmount']}',
    if (immediate)
      'cashboxAmount': '${funding['cashAmount']}'
    else
      'cashAmount': '${funding['cashAmount']}',
    'sourceVersion': sourceVersion,
    'operationId': operationId,
    'paymentId': source['id'],
    'sourceSnapshot': canonicalIdentity(source),
  };
}

bool _samePosting(BalancedJournal a, BalancedJournal b) {
  final p = a.policy, q = b.policy;
  if (a.id != b.id ||
      a.effectiveDate != b.effectiveDate ||
      a.reversesId != b.reversesId ||
      a.totalUnits != b.totalUnits ||
      a.lines.length != b.lines.length ||
      p.currency != q.currency ||
      p.scale != q.scale ||
      p.maximumLines != q.maximumLines ||
      p.maximumLineUnits != q.maximumLineUnits ||
      p.maximumSideUnits != q.maximumSideUnits ||
      p.allowZeroLines != q.allowZeroLines) {
    return false;
  }
  for (var i = 0; i < a.lines.length; i++) {
    final x = a.lines[i], y = b.lines[i];
    if (x.accountId != y.accountId ||
        x.side != y.side ||
        x.amountUnits != y.amountUnits ||
        x.currency != y.currency ||
        x.scale != y.scale) {
      return false;
    }
  }
  return true;
}

bool _entryMatches(
  PortableJournalEntry entry,
  RestaurantJournalProposal expected,
  String sourceId,
  String recordedAt,
  Map<String, Object?> metadata,
) =>
    entry.sourceType == expected.sourceType.name &&
    entry.sourceRecordId == sourceId &&
    entry.recordedAt == recordedAt &&
    entry.correctedFromJournalId == null &&
    entry.replacementJournalId == null &&
    _samePosting(entry.journal, expected.journal) &&
    _sameValue(entry.metadata, metadata);

bool _invoicePostingMatchesSource(
  PortableJournalEntry entry,
  Map<String, Object?> source,
  RestaurantJournalMapper mapper,
  AccountDocument account,
) {
  try {
    final expected = mapper.mapPurchaseInvoice(
      journalId: entry.journal.id,
      invoiceId: source['id'] as String,
      invoiceNumber: source['number'] as String,
      supplierId: source['supplierId'] as String,
      effectiveDate: DateOnly.parse(
        source['date'] as String,
        minimumYear: 1000,
        maximumYear: 9999,
      ),
      amount: _unorderedQueries(account).invoiceTotal(source),
      policy: entry.journal.policy,
    );
    return entry.sourceType == expected.sourceType.name &&
        entry.sourceRecordId == source['id'] &&
        entry.recordedAt == source['createdAt'] &&
        entry.correctedFromJournalId == null &&
        entry.replacementJournalId == null &&
        _samePosting(entry.journal, expected.journal) &&
        (!entry.metadata.containsKey('sourceSnapshot') ||
            entry.metadata['sourceSnapshot'] == canonicalIdentity(source));
  } catch (_) {
    return false;
  }
}

bool _paymentPostingMatchesSource(
  PortableJournalEntry entry,
  Map<String, Object?> source,
  RestaurantJournalMapper mapper,
) {
  try {
    final funding = source['funding'] as Map;
    final expected = mapper.mapSupplierPayment(
      journalId: entry.journal.id,
      paymentId: source['id'] as String,
      supplierId: source['supplierId'] as String,
      invoiceId: source['invoiceId'] as String?,
      effectiveDate: DateOnly.parse(
        source['date'] as String,
        minimumYear: 1000,
        maximumYear: 9999,
      ),
      amount: BigInt.from(source['amount'] as int),
      dailyAmount: BigInt.from(funding['dailyAmount'] as int),
      cashboxAmount: BigInt.from(funding['cashAmount'] as int),
      invoiceSettledAmount: BigInt.from(source['invoiceAmount'] as int),
      debtSettledAmount: BigInt.from(source['debtAmount'] as int),
      policy: entry.journal.policy,
    );
    return entry.sourceType == expected.sourceType.name &&
        entry.sourceRecordId == source['id'] &&
        entry.recordedAt == source['createdAt'] &&
        entry.correctedFromJournalId == null &&
        entry.replacementJournalId == null &&
        _samePosting(entry.journal, expected.journal) &&
        (!entry.metadata.containsKey('sourceSnapshot') ||
            entry.metadata['sourceSnapshot'] == canonicalIdentity(source));
  } catch (_) {
    return false;
  }
}

bool _paymentHasValidPosting(
  PortableJournalState state,
  Map<String, Object?> source,
  RestaurantJournalMapper mapper,
) {
  final postings = state.journals
      .where(
        (j) =>
            j.sourceRecordId == source['id'] &&
            j.sourceType == RestaurantJournalSourceType.supplierPayment.name &&
            j.journal.reversesId == null,
      )
      .toList();
  return postings.length == 1 &&
      !_isReversed(state, postings.single) &&
      _paymentPostingMatchesSource(postings.single, source, mapper);
}

bool _invoiceSourceMatchesCommand(
  Map<String, Object?> source,
  CreatePurchaseInvoiceCommand command,
) {
  if (source['id'] != command.invoiceId ||
      source['supplierId'] != command.supplierId ||
      source['number'] != _normalizedInvoiceNumber(command.invoiceNumber) ||
      source['date'] != command.date.toString() ||
      source['createdAt'] != command.recordedAt ||
      source['note'] != LegacyText.trimJavaScript(command.note)) {
    return false;
  }
  final lines = (source['lines'] as List).cast<Map<String, Object?>>();
  if (lines.length != command.lines.length) return false;
  BigInt units(Object? value) => ExactDecimal.parse(
    value.toString(),
    scale: 3,
    maxAbsUnits: RestaurantJournalPolicies.defaultLimit,
    signed: false,
    positive: false,
  ).units;
  for (var i = 0; i < lines.length; i++) {
    final actual = lines[i], submitted = command.lines[i];
    if (actual['name'] != LegacyText.trimJavaScript(submitted.name) ||
        actual['unit'] != LegacyText.trimJavaScript(submitted.unit) ||
        units(actual['quantityCartons']) != units(submitted.quantityCartons) ||
        units(actual['quantityPieces']) != units(submitted.quantityPieces) ||
        actual['priceCarton'] != submitted.priceCarton ||
        actual['pricePiece'] != submitted.pricePiece ||
        units(actual['quantity']) != units(submitted.quantityPieces) ||
        actual['price'] != submitted.pricePiece) {
      return false;
    }
  }
  return true;
}

bool _replayMatchesSource(
  RestaurantJournalSpendingCommand command,
  RestaurantJournalSpendingOutcome outcome,
  PortableJournalState state,
  RestaurantJournalMapper mapper,
) {
  try {
    final entry = state.journals.singleWhere(
      (j) => j.journal.id == outcome.journalId,
    );
    switch (command) {
      case CreateOperatingExpenseCommand():
        return RestaurantJournalExpenseHistory.validate(
              state: state,
              expenseId: command.expenseId,
              mapper: mapper,
              initialIdentity: command.identity,
            ) &&
            canonicalIdentity(outcome.toJson()) ==
                canonicalIdentity(
                  RestaurantJournalSpendingOutcome.fromOutcomePayload(
                    state.receipts
                        .singleWhere(
                          (r) =>
                              r.identity == command.identity &&
                              r.status == DurableCommandStatus.committed,
                        )
                        .outcomePayload!,
                  ).toJson(),
                );
      case CreatePurchaseInvoiceCommand():
        final source = _sourceRecord(
          state.account,
          'invoices',
          command.invoiceId,
        );
        if (!_invoiceSourceMatchesCommand(source, command)) return false;
        final amount = _unorderedQueries(state.account).invoiceTotal(source);
        final expected = mapper.mapPurchaseInvoice(
          journalId: command.invoiceJournalId,
          invoiceId: command.invoiceId,
          invoiceNumber: source['number'] as String,
          supplierId: command.supplierId,
          effectiveDate: command.date,
          amount: amount,
          policy: command.policy,
        );
        final hasPayment =
            command.immediatePayment != null &&
            command.immediatePayment!.amount > 0;
        final payment = hasPayment
            ? _sourceRecord(
                state.account,
                'payments',
                command.immediatePayment!.id,
              )
            : null;
        final metadata = _invoiceMetadata(
          command,
          source,
          payment,
          amount,
          expected.sourceVersion,
        );
        if (payment != null) {
          final p = command.immediatePayment!;
          final funding = CommerceCalculations.fundingSplit(
            amount: BigInt.from(p.amount),
            source: FundingSource.values.singleWhere((s) => s.name == p.source),
            daily: BigInt.from(
              p.source == 'daily'
                  ? p.amount
                  : p.source == 'cash'
                  ? 0
                  : p.dailyAmount,
            ),
            cash: BigInt.from(
              p.source == 'cash'
                  ? p.amount
                  : p.source == 'daily'
                  ? 0
                  : p.cashAmount,
            ),
            policy: CommercePolicy(
              quantityScale: 3,
              maximumQuantityUnits: RestaurantJournalPolicies.defaultLimit,
              maximumMoney: RestaurantJournalPolicies.defaultLimit,
              maximumSafeInteger:
                  RestaurantJournalPolicies.maximumSafeAggregate,
              rounding: DecimalRounding.halfTowardPositiveInfinity,
            ),
          );
          final expectedSource = <String, Object?>{
            'id': p.id,
            'supplierId': command.supplierId,
            'invoiceId': command.invoiceId,
            'categoryId': payment['categoryId'],
            'date': command.date.toString(),
            'amount': p.amount,
            'invoiceAmount': p.amount,
            'debtAmount': 0,
            'funding': {
              'source': p.source,
              'dailyAmount': funding.daily.toInt(),
              'cashAmount': funding.cash.toInt(),
            },
            'note': '',
            'createdAt': command.recordedAt,
          };
          if (!_sameValue(payment, expectedSource)) return false;
          final paymentEntry = state.journals.singleWhere(
            (j) => j.journal.id == command.paymentJournalId,
          );
          final paymentExpected = mapper.mapSupplierPayment(
            journalId: command.paymentJournalId!,
            paymentId: p.id,
            supplierId: command.supplierId,
            invoiceId: command.invoiceId,
            effectiveDate: command.date,
            amount: BigInt.from(p.amount),
            dailyAmount: funding.daily,
            cashboxAmount: funding.cash,
            invoiceSettledAmount: BigInt.from(p.amount),
            debtSettledAmount: BigInt.zero,
            policy: command.policy,
          );
          if (!_entryMatches(
            paymentEntry,
            paymentExpected,
            p.id,
            command.recordedAt,
            _paymentMetadata(
              command.operationId,
              payment,
              paymentExpected.sourceVersion,
              immediate: true,
            ),
          )) {
            return false;
          }
        }
        final expectedOutcome = RestaurantJournalSpendingOutcome(
          commandType: command.commandType,
          operationId: command.operationId,
          invoiceId: command.invoiceId,
          invoiceNumber: source['number'] as String,
          supplierId: command.supplierId,
          paymentId: hasPayment ? command.immediatePayment!.id : null,
          journalId: command.invoiceJournalId,
          paymentJournalId: hasPayment ? command.paymentJournalId : null,
          effectiveDate: command.date.toString(),
          netAmount: amount.toString(),
          metadata: metadata,
        );
        return outcome == expectedOutcome &&
            _entryMatches(
              entry,
              expected,
              command.invoiceId,
              command.recordedAt,
              metadata,
            );
      case CreateSupplierPaymentCommand():
        final source = _sourceRecord(
          state.account,
          'payments',
          command.paymentId,
        );
        final expectedSource = <String, Object?>{
          'id': command.paymentId,
          'supplierId': command.supplierId,
          'invoiceId': command.invoiceId,
          'categoryId': source['categoryId'],
          'date': command.date.toString(),
          'amount': command.amount.toInt(),
          'invoiceAmount': source['invoiceAmount'],
          'debtAmount': source['debtAmount'],
          'funding': {
            'source': command.fundingSource.name,
            'dailyAmount': command.dailyAmount.toInt(),
            'cashAmount': command.cashAmount.toInt(),
          },
          'note': LegacyText.trimJavaScript(command.note),
          'createdAt': command.recordedAt,
        };
        if (!_sameValue(source, expectedSource)) return false;
        final expected = mapper.mapSupplierPayment(
          journalId: command.journalId,
          paymentId: command.paymentId,
          supplierId: command.supplierId,
          invoiceId: command.invoiceId,
          effectiveDate: command.date,
          amount: command.amount,
          dailyAmount: command.dailyAmount,
          cashboxAmount: command.cashAmount,
          invoiceSettledAmount: BigInt.from(source['invoiceAmount'] as int),
          debtSettledAmount: BigInt.from(source['debtAmount'] as int),
          policy: command.policy,
        );
        final metadata = _paymentMetadata(
          command.operationId,
          source,
          expected.sourceVersion,
        );
        final expectedOutcome = RestaurantJournalSpendingOutcome(
          commandType: command.commandType,
          operationId: command.operationId,
          paymentId: command.paymentId,
          supplierId: command.supplierId,
          invoiceId: command.invoiceId,
          journalId: command.journalId,
          effectiveDate: command.date.toString(),
          netAmount: command.amount.toString(),
          metadata: metadata,
        );
        return outcome == expectedOutcome &&
            _entryMatches(
              entry,
              expected,
              command.paymentId,
              command.recordedAt,
              metadata,
            );
    }
  } catch (_) {
    return false;
  }
}
