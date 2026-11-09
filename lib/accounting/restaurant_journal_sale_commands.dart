import 'dart:convert';

import 'package:madar_application/madar_application.dart';
import 'package:madar_domain/madar_domain.dart';

import '../accounts/account_document.dart';
import '../accounts/legacy_account_codec.dart';
import '../accounts/portable_journal_codec.dart';
import '../accounts/portable_journal_state.dart';
import '../sales/return_proposal.dart';
import '../sales/sale_proposal.dart';
import 'journal_command_host.dart';
import 'restaurant_journal_mapper.dart';

/// Error codes emitted by the restaurant sales command layer.
abstract final class RestaurantJournalSaleErrorCodes {
  static const accountLineageMismatch = 'account_lineage_mismatch';
  static const cutoverGated = 'cutover_gated';
  static const preCutoverOperationRejected = 'pre_cutover_operation_rejected';
  static const crossCutoverSourceHasNoPostCutoverJournal =
      'cross_cutover_source_has_no_post_cutover_journal';
  static const saleNotFound = 'sale_not_found';
  static const saleUnavailableForReturn = 'sale_unavailable_for_return';
  static const saleAlreadyVoid = 'sale_already_void';
  static const voidIneligibleSaleHasReturns =
      'void_ineligible_sale_has_returns';
  static const alreadyReversed = 'already_reversed';
  static const invalidSaleProposal = 'invalid_sale_proposal';
  static const invalidReturnProposal = 'invalid_return_proposal';
  static const voidIneligibleSourceRejection =
      'void_ineligible_source_rejection';
  static const saleMappingFailed = 'sale_mapping_failed';
  static const returnMappingFailed = 'return_mapping_failed';
  static const voidMappingFailed = 'void_mapping_failed';
  static const zeroValueRequiresAllowZeroPolicy =
      'zero_value_requires_allow_zero_policy';
}

/// Frozen, validated outcome of a committed or replayed sales command.
final class RestaurantJournalSaleOutcome {
  RestaurantJournalSaleOutcome({
    required this.commandType,
    required this.operationId,
    required this.saleId,
    required this.journalId,
    this.returnId,
    this.receiptNumber,
    required this.effectiveDate,
    required this.netAmount,
    Map<String, Object?> metadata = const {},
  }) : metadata = _freezeMap(metadata) {
    _metadataIdentity = _canonicalIdentity(this.metadata);
  }

  final String commandType;
  final String operationId;
  final String saleId;
  final String journalId;
  final String? returnId;
  final String? receiptNumber;
  final String effectiveDate;
  final String netAmount;
  final Map<String, Object?> metadata;
  late final String _metadataIdentity;

  Map<String, Object?> toJson() => {
    'commandType': commandType,
    'operationId': operationId,
    'saleId': saleId,
    'journalId': journalId,
    'returnId': ?returnId,
    'receiptNumber': ?receiptNumber,
    'effectiveDate': effectiveDate,
    'netAmount': netAmount,
    if (metadata.isNotEmpty) 'metadata': metadata,
  };

  String toOutcomePayload() => jsonEncode(toJson());

  factory RestaurantJournalSaleOutcome.fromJson(Map<String, Object?> json) {
    const allowed = {
      'commandType',
      'operationId',
      'saleId',
      'journalId',
      'returnId',
      'receiptNumber',
      'effectiveDate',
      'netAmount',
      'metadata',
    };
    if (!json.keys.every(allowed.contains)) {
      throw const FormatException('invalid_sales_outcome');
    }
    String text(String key) {
      final value = json[key];
      if (value is! String || value.isEmpty || value.trim() != value) {
        throw const FormatException('invalid_sales_outcome');
      }
      return value;
    }

    String? optional(String key) => json[key] == null ? null : text(key);
    final type = text('commandType'),
        date = text('effectiveDate'),
        amount = text('netAmount');
    if (!const {'complete_sale', 'sale_return', 'sale_void'}.contains(type) ||
        !RegExp(r'^(0|[1-9][0-9]*)$').hasMatch(amount)) {
      throw const FormatException('invalid_sales_outcome');
    }
    DateOnly.parse(date, minimumYear: 1000, maximumYear: 9999);
    final metadata = json['metadata'];
    if (metadata != null && metadata is! Map<String, Object?>) {
      throw const FormatException('invalid_sales_outcome');
    }
    return RestaurantJournalSaleOutcome(
      commandType: type,
      operationId: text('operationId'),
      saleId: text('saleId'),
      journalId: text('journalId'),
      returnId: optional('returnId'),
      receiptNumber: optional('receiptNumber'),
      effectiveDate: date,
      netAmount: amount,
      metadata: metadata as Map<String, Object?>? ?? const {},
    );
  }

  factory RestaurantJournalSaleOutcome.fromOutcomePayload(String payload) {
    final decoded = jsonDecode(payload) as Map<String, Object?>;
    return RestaurantJournalSaleOutcome.fromJson(decoded);
  }

  @override
  bool operator ==(Object other) =>
      other is RestaurantJournalSaleOutcome &&
      other.commandType == commandType &&
      other.operationId == operationId &&
      other.saleId == saleId &&
      other.journalId == journalId &&
      other.returnId == returnId &&
      other.receiptNumber == receiptNumber &&
      other.effectiveDate == effectiveDate &&
      other.netAmount == netAmount &&
      other._metadataIdentity == _metadataIdentity;

  @override
  int get hashCode => Object.hash(
    commandType,
    operationId,
    saleId,
    journalId,
    returnId,
    receiptNumber,
    effectiveDate,
    netAmount,
    _metadataIdentity,
  );

  @override
  String toString() =>
      'RestaurantJournalSaleOutcome(type: $commandType, details: redacted)';
}

/// Deeply freezes maps and nested collections using shared host utilities.
Map<String, Object?> _freezeMap(Map<String, Object?> map) => freezeMap(map);

List<ReturnLineRequest> _freezeReturnLines(
  Iterable<ReturnLineRequest> values,
) => freezeList(values, maxCount: 200, errorCode: 'invalid_return_line_count');

String _canonicalIdentity(Map<String, Object?> values) =>
    canonicalIdentity(values);

/// Base class for all durable sales operations.
sealed class RestaurantJournalSaleCommand {
  const RestaurantJournalSaleCommand({
    required this.operationId,
    required this.payloadVersion,
    required this.accountLineage,
    this.expectedFence,
    required this.saleId,
    required this.journalId,
    required this.recordedAt,
    this.policy,
  });

  final String operationId;
  final int payloadVersion;
  final String accountLineage;
  final StorageFence? expectedFence;
  final String saleId;
  final String journalId;
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

/// Durable command to post and complete a sale ticket.
final class CompleteSaleCommand extends RestaurantJournalSaleCommand {
  CompleteSaleCommand({
    required super.operationId,
    super.payloadVersion = 1,
    required super.accountLineage,
    super.expectedFence,
    required super.saleId,
    required super.journalId,
    required Map<String, Object?> draft,
    this.receiptNumber,
    required super.recordedAt,
    super.policy,
  }) : draft = _freezeMap(draft) {
    canonicalPayloadIdentity = _computeCanonicalPayload(
      operationId: operationId,
      payloadVersion: payloadVersion,
      accountLineage: accountLineage,
      expectedFence: expectedFence,
      saleId: saleId,
      journalId: journalId,
      draft: this.draft,
      receiptNumber: receiptNumber,
      recordedAt: recordedAt,
      policy: policy,
    );
    if (operationId.isEmpty || operationId.trim() != operationId) {
      throw const FormatException('Invalid operationId');
    }
    if (payloadVersion <= 0) {
      throw const FormatException('Payload version must be positive');
    }
    if (accountLineage.isEmpty || accountLineage.trim() != accountLineage) {
      throw const FormatException('Invalid accountLineage');
    }
    if (saleId.isEmpty || saleId.trim() != saleId) {
      throw const FormatException('Invalid saleId');
    }
    if (journalId.isEmpty || journalId.trim() != journalId) {
      throw const FormatException('Invalid journalId');
    }
    if (recordedAt.isEmpty || recordedAt.trim() != recordedAt) {
      throw const FormatException('Invalid recordedAt');
    }
  }

  final Map<String, Object?> draft;
  final String? receiptNumber;

  @override
  late final String canonicalPayloadIdentity;

  @override
  String get commandType => 'complete_sale';

  static String _computeCanonicalPayload({
    required String operationId,
    required int payloadVersion,
    required String accountLineage,
    StorageFence? expectedFence,
    required String saleId,
    required String journalId,
    required Map<String, Object?> draft,
    String? receiptNumber,
    required String recordedAt,
    JournalPolicy? policy,
  }) {
    final map = <String, Object?>{
      'accountLineage': accountLineage,
      'commandType': 'complete_sale',
      'draft': draft,
      if (expectedFence != null)
        'expectedFence': {
          'generation': expectedFence.generation,
          'storeId': expectedFence.storeId,
        },
      'journalId': journalId,
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
      'receiptNumber': ?receiptNumber,
      'recordedAt': recordedAt,
      'saleId': saleId,
    };
    return _canonicalIdentity(map);
  }
}

/// Durable command to post a partial or full return against a completed sale.
final class SaleReturnCommand extends RestaurantJournalSaleCommand {
  SaleReturnCommand({
    required super.operationId,
    super.payloadVersion = 1,
    required super.accountLineage,
    super.expectedFence,
    required this.returnId,
    required super.saleId,
    required super.journalId,
    required this.returnDate,
    required this.reason,
    required super.recordedAt,
    required this.today,
    required Iterable<ReturnLineRequest> lines,
    super.policy,
  }) : lines = _freezeReturnLines(lines) {
    canonicalPayloadIdentity = _computeCanonicalPayload(
      operationId: operationId,
      payloadVersion: payloadVersion,
      accountLineage: accountLineage,
      expectedFence: expectedFence,
      returnId: returnId,
      saleId: saleId,
      journalId: journalId,
      returnDate: returnDate,
      reason: reason,
      recordedAt: recordedAt,
      today: today,
      lines: this.lines,
      policy: policy,
    );
    if (operationId.isEmpty || operationId.trim() != operationId) {
      throw const FormatException('Invalid operationId');
    }
    if (payloadVersion <= 0) {
      throw const FormatException('Payload version must be positive');
    }
    if (accountLineage.isEmpty || accountLineage.trim() != accountLineage) {
      throw const FormatException('Invalid accountLineage');
    }
    if (returnId.isEmpty || returnId.trim() != returnId) {
      throw const FormatException('Invalid returnId');
    }
    if (saleId.isEmpty || saleId.trim() != saleId) {
      throw const FormatException('Invalid saleId');
    }
    if (journalId.isEmpty || journalId.trim() != journalId) {
      throw const FormatException('Invalid journalId');
    }
    if (reason.trim().isEmpty) {
      throw const FormatException('Return reason is required');
    }
    if (recordedAt.isEmpty || recordedAt.trim() != recordedAt) {
      throw const FormatException('Invalid recordedAt');
    }
    if (this.lines.isEmpty) {
      throw const FormatException('Return lines cannot be empty');
    }
  }

  final String returnId;
  final DateOnly returnDate;
  final String reason;
  final DateOnly today;
  final List<ReturnLineRequest> lines;

  @override
  late final String canonicalPayloadIdentity;

  @override
  String get commandType => 'sale_return';

  static String _computeCanonicalPayload({
    required String operationId,
    required int payloadVersion,
    required String accountLineage,
    StorageFence? expectedFence,
    required String returnId,
    required String saleId,
    required String journalId,
    required DateOnly returnDate,
    required String reason,
    required String recordedAt,
    required DateOnly today,
    required Iterable<ReturnLineRequest> lines,
    JournalPolicy? policy,
  }) {
    final map = <String, Object?>{
      'accountLineage': accountLineage,
      'commandType': 'sale_return',
      if (expectedFence != null)
        'expectedFence': {
          'generation': expectedFence.generation,
          'storeId': expectedFence.storeId,
        },
      'journalId': journalId,
      'lines': [
        for (final l in lines)
          {
            'productId': l.productId,
            'quantityUnits': l.quantityUnits.toString(),
            'restock': l.restock,
          },
      ],
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
      'reason': reason,
      'recordedAt': recordedAt,
      'returnDate': returnDate.toString(),
      'returnId': returnId,
      'saleId': saleId,
      'today': today.toString(),
    };
    return _canonicalIdentity(map);
  }
}

/// Durable command to void an eligible completed sale on its original date.
final class SaleVoidCommand extends RestaurantJournalSaleCommand {
  SaleVoidCommand({
    required super.operationId,
    super.payloadVersion = 1,
    required super.accountLineage,
    super.expectedFence,
    required super.saleId,
    required this.reversalJournalId,
    this.voidRecordId,
    required this.reason,
    required this.voidedAt,
    super.policy,
  }) : canonicalPayloadIdentity = _computeCanonicalPayload(
         operationId: operationId,
         payloadVersion: payloadVersion,
         accountLineage: accountLineage,
         expectedFence: expectedFence,
         saleId: saleId,
         reversalJournalId: reversalJournalId,
         voidRecordId: voidRecordId,
         reason: reason,
         voidedAt: voidedAt,
         policy: policy,
       ),
       super(journalId: reversalJournalId, recordedAt: voidedAt) {
    if (operationId.isEmpty || operationId.trim() != operationId) {
      throw const FormatException('Invalid operationId');
    }
    if (payloadVersion <= 0) {
      throw const FormatException('Payload version must be positive');
    }
    if (accountLineage.isEmpty || accountLineage.trim() != accountLineage) {
      throw const FormatException('Invalid accountLineage');
    }
    if (saleId.isEmpty || saleId.trim() != saleId) {
      throw const FormatException('Invalid saleId');
    }
    if (reversalJournalId.isEmpty ||
        reversalJournalId.trim() != reversalJournalId) {
      throw const FormatException('Invalid reversalJournalId');
    }
    if (reason.trim().isEmpty) {
      throw const FormatException('Void reason is required');
    }
    if (voidedAt.isEmpty || voidedAt.trim() != voidedAt) {
      throw const FormatException('Invalid voidedAt');
    }
  }

  final String reversalJournalId;
  final String? voidRecordId;
  final String reason;
  final String voidedAt;

  @override
  final String canonicalPayloadIdentity;

  @override
  String get commandType => 'sale_void';

  static String _computeCanonicalPayload({
    required String operationId,
    required int payloadVersion,
    required String accountLineage,
    StorageFence? expectedFence,
    required String saleId,
    required String reversalJournalId,
    String? voidRecordId,
    required String reason,
    required String voidedAt,
    JournalPolicy? policy,
  }) {
    final map = <String, Object?>{
      'accountLineage': accountLineage,
      'commandType': 'sale_void',
      if (expectedFence != null)
        'expectedFence': {
          'generation': expectedFence.generation,
          'storeId': expectedFence.storeId,
        },
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
      'reason': reason,
      'reversalJournalId': reversalJournalId,
      'saleId': saleId,
      'voidRecordId': ?voidRecordId,
      'voidedAt': voidedAt,
    };
    return _canonicalIdentity(map);
  }
}

/// Coordinates atomic execution, idempotency, lineage enforcement, and
/// cutover gating for restaurant sale commands against a single store owner.
final class RestaurantJournalSaleCommandCoordinator {
  RestaurantJournalSaleCommandCoordinator({
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

  /// Executes any [RestaurantJournalSaleCommand].
  Future<DurableCommandResult<RestaurantJournalSaleOutcome>> execute(
    RestaurantJournalSaleCommand command,
  ) {
    return host.execute<RestaurantJournalSaleOutcome>(
      identity: command.identity,
      accountLineage: command.accountLineage,
      expectedFence: command.expectedFence,
      missingAuthorityFenceMessage:
          'Capture account authority before submitting a sales command.',
      accountLineageMismatchCode:
          RestaurantJournalSaleErrorCodes.accountLineageMismatch,
      cutoverGatedCode: RestaurantJournalSaleErrorCodes.cutoverGated,
      validateReplayOutcome: (payload, state) {
        try {
          final outcome = RestaurantJournalSaleOutcome.fromOutcomePayload(
            payload,
          );
          return _replayMatchesSource(command, outcome, state, mapper);
        } catch (_) {
          return false;
        }
      },
      parseOutcome: RestaurantJournalSaleOutcome.fromOutcomePayload,
      evaluateProposal: (state, fence) => evaluateCommand(
        command: command,
        state: state,
        cutoverDate: state.cutoverState.cutoverDate!,
        mapper: mapper,
      ),
    );
  }

  /// Convenience method for completed sales.
  Future<DurableCommandResult<RestaurantJournalSaleOutcome>> executeSale(
    CompleteSaleCommand command,
  ) => execute(command);

  /// Convenience method for sale returns.
  Future<DurableCommandResult<RestaurantJournalSaleOutcome>> executeReturn(
    SaleReturnCommand command,
  ) => execute(command);

  /// Convenience method for sale voids.
  Future<DurableCommandResult<RestaurantJournalSaleOutcome>> executeVoid(
    SaleVoidCommand command,
  ) => execute(command);

  static DurableProposalEvaluation<
    PortableJournalState,
    RestaurantJournalSaleOutcome
  >
  evaluateCommand({
    required RestaurantJournalSaleCommand command,
    required PortableJournalState state,
    required DateOnly cutoverDate,
    required RestaurantJournalMapper mapper,
  }) {
    switch (command) {
      case CompleteSaleCommand():
        return evaluateSale(
          command: command,
          state: state,
          cutoverDate: cutoverDate,
          mapper: mapper,
        );
      case SaleReturnCommand():
        return evaluateReturn(
          command: command,
          state: state,
          cutoverDate: cutoverDate,
          mapper: mapper,
        );
      case SaleVoidCommand():
        return evaluateVoid(
          command: command,
          state: state,
          cutoverDate: cutoverDate,
          mapper: mapper,
        );
    }
  }

  static DurableProposalEvaluation<
    PortableJournalState,
    RestaurantJournalSaleOutcome
  >
  evaluateSale({
    required CompleteSaleCommand command,
    required PortableJournalState state,
    required DateOnly cutoverDate,
    required RestaurantJournalMapper mapper,
  }) {
    final rawDate = command.draft['date'];
    if (rawDate is! String) {
      return const DurableProposalEvaluation.reject(
        rejectionCode: RestaurantJournalSaleErrorCodes.invalidSaleProposal,
        rejectionMessage: 'Sale draft date is missing or invalid.',
      );
    }

    DateOnly saleDate;
    try {
      saleDate = DateOnly.parse(rawDate, minimumYear: 1000, maximumYear: 9999);
    } catch (_) {
      return const DurableProposalEvaluation.reject(
        rejectionCode: RestaurantJournalSaleErrorCodes.invalidSaleProposal,
        rejectionMessage: 'Invalid sale date format.',
      );
    }

    if (saleDate.compareTo(cutoverDate) < 0) {
      return const DurableProposalEvaluation.reject(
        rejectionCode:
            RestaurantJournalSaleErrorCodes.preCutoverOperationRejected,
        rejectionMessage: 'Sale date precedes established cutover date.',
      );
    }

    SaleProposal proposal;
    try {
      proposal = SaleProposal.build(
        state.account,
        draft: command.draft,
        saleId: command.saleId,
        createdAt: command.recordedAt,
      );
    } catch (e) {
      return DurableProposalEvaluation.reject(
        rejectionCode: RestaurantJournalSaleErrorCodes.invalidSaleProposal,
        rejectionMessage: e.toString(),
      );
    }

    final quote = _sourceSaleQuote(proposal.sale);
    final grossAmount = quote.subtotal;
    final discountAmount = quote.discount;
    final netAmount = quote.net;

    final receiptNumber = proposal.sale['number'] as String;
    if (command.receiptNumber != null &&
        command.receiptNumber != receiptNumber) {
      return const DurableProposalEvaluation.reject(
        rejectionCode: 'receipt_number_mismatch',
        rejectionMessage: 'Receipt must match the persisted sale number.',
      );
    }

    RestaurantJournalProposal journalProposal;
    try {
      journalProposal = mapper.mapSaleTicket(
        journalId: command.journalId,
        saleId: command.saleId,
        receiptNumber: receiptNumber,
        effectiveDate: saleDate,
        grossAmount: grossAmount,
        discountAmount: discountAmount,
        netAmount: netAmount,
        policy: command.policy,
      );
    } on RestaurantJournalMappingException catch (e) {
      return DurableProposalEvaluation.reject(
        rejectionCode: e.code,
        rejectionMessage: e.toString(),
      );
    } catch (e) {
      return DurableProposalEvaluation.reject(
        rejectionCode: RestaurantJournalSaleErrorCodes.saleMappingFailed,
        rejectionMessage: e.toString(),
      );
    }

    final metadata = <String, Object?>{
      'gross': grossAmount.toString(),
      'discount': discountAmount.toString(),
      'net': netAmount.toString(),
      'sourceVersion': journalProposal.sourceVersion,
      'receiptNumber': receiptNumber,
      'operationId': command.operationId,
      'saleId': command.saleId,
    };

    final entry = PortableJournalEntry(
      journal: journalProposal.journal,
      sourceType: journalProposal.sourceType.name,
      sourceRecordId: command.saleId,
      recordedAt: command.recordedAt,
      metadata: metadata,
    );

    final candidateState = state.copyWith(
      account: proposal.candidate,
      journals: [...state.journals, entry],
    );

    final outcome = RestaurantJournalSaleOutcome(
      commandType: command.commandType,
      operationId: command.operationId,
      saleId: command.saleId,
      journalId: command.journalId,
      receiptNumber: receiptNumber,
      effectiveDate: saleDate.toString(),
      netAmount: netAmount.toString(),
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
    RestaurantJournalSaleOutcome
  >
  evaluateReturn({
    required SaleReturnCommand command,
    required PortableJournalState state,
    required DateOnly cutoverDate,
    required RestaurantJournalMapper mapper,
  }) {
    if (command.returnDate.compareTo(cutoverDate) < 0) {
      return const DurableProposalEvaluation.reject(
        rejectionCode:
            RestaurantJournalSaleErrorCodes.preCutoverOperationRejected,
        rejectionMessage: 'Return date precedes established cutover date.',
      );
    }

    final sales = (state.account.toJson()['sales'] as List)
        .cast<Map<String, Object?>>();
    final matches = sales.where((s) => s['id'] == command.saleId).toList();
    if (matches.isEmpty) {
      return const DurableProposalEvaluation.reject(
        rejectionCode: RestaurantJournalSaleErrorCodes.saleNotFound,
        rejectionMessage: 'Target sale not found.',
      );
    }

    final targetSale = matches.first;
    if (targetSale['status'] != 'completed') {
      return const DurableProposalEvaluation.reject(
        rejectionCode: RestaurantJournalSaleErrorCodes.saleUnavailableForReturn,
        rejectionMessage: 'Target sale is not completed.',
      );
    }

    // Historical source must have an eligible post-cutover journal.
    final postCutoverJournals = state.journals
        .where(
          (j) =>
              j.sourceRecordId == command.saleId &&
              j.sourceType == RestaurantJournalSourceType.sale.name &&
              j.journal.reversesId == null &&
              j.journal.effectiveDate.compareTo(cutoverDate) >= 0,
        )
        .toList();

    if (postCutoverJournals.isEmpty) {
      return const DurableProposalEvaluation.reject(
        rejectionCode: RestaurantJournalSaleErrorCodes
            .crossCutoverSourceHasNoPostCutoverJournal,
        rejectionMessage: 'Historical sale has no eligible post-cutover journal under cross-cutover gate.',
      );
    }
    if (postCutoverJournals.length != 1 ||
        !_postingMatchesSale(postCutoverJournals.first, targetSale, mapper)) {
      return const DurableProposalEvaluation.reject(
        rejectionCode: 'sale_posting_mismatch',
        rejectionMessage: 'Saved sale and its posting do not reconcile.',
      );
    }

    if (postCutoverJournals.length != 1 ||
        state.journals.any(
          (j) => j.journal.reversesId == postCutoverJournals.first.journal.id,
        )) {
      return const DurableProposalEvaluation.reject(
        rejectionCode: RestaurantJournalSaleErrorCodes.alreadyReversed,
        rejectionMessage: 'Sale posting is unavailable for return.',
      );
    }

    ReturnProposal proposal;
    try {
      proposal = ReturnProposal.build(
        state.account,
        saleId: command.saleId,
        returnId: command.returnId,
        date: command.returnDate.toString(),
        reason: command.reason,
        createdAt: command.recordedAt,
        today: command.today.toString(),
        lines: command.lines,
      );
    } catch (e) {
      return DurableProposalEvaluation.reject(
        rejectionCode: RestaurantJournalSaleErrorCodes.invalidReturnProposal,
        rejectionMessage: e.toString(),
      );
    }

    RestaurantJournalProposal journalProposal;
    try {
      journalProposal = mapper.mapSaleReturn(
        journalId: command.journalId,
        returnId: command.returnId,
        originalSaleId: command.saleId,
        returnDate: command.returnDate,
        amount: proposal.amount,
        reason: command.reason,
        policy: command.policy,
      );
    } on RestaurantJournalMappingException catch (e) {
      return DurableProposalEvaluation.reject(
        rejectionCode: e.code,
        rejectionMessage: e.toString(),
      );
    } catch (e) {
      return DurableProposalEvaluation.reject(
        rejectionCode: RestaurantJournalSaleErrorCodes.returnMappingFailed,
        rejectionMessage: e.toString(),
      );
    }

    final originalSaleJournal = postCutoverJournals.first;
    final receiptNumber =
        (originalSaleJournal.metadata['receiptNumber'] as String?) ??
        (targetSale['number'] as String?) ??
        '';

    final metadata = <String, Object?>{
      'originalSaleId': command.saleId,
      'reason': command.reason.trim(),
      'amount': proposal.amount.toString(),
      'sourceVersion': journalProposal.sourceVersion,
      'receiptNumber': receiptNumber,
      'operationId': command.operationId,
      'returnId': command.returnId,
    };

    final entry = PortableJournalEntry(
      journal: journalProposal.journal,
      sourceType: journalProposal.sourceType.name,
      sourceRecordId: command.returnId,
      recordedAt: command.recordedAt,
      metadata: metadata,
    );

    final candidateState = state.copyWith(
      account: proposal.candidate,
      journals: [...state.journals, entry],
    );

    final outcome = RestaurantJournalSaleOutcome(
      commandType: command.commandType,
      operationId: command.operationId,
      saleId: command.saleId,
      journalId: command.journalId,
      returnId: command.returnId,
      receiptNumber: receiptNumber,
      effectiveDate: command.returnDate.toString(),
      netAmount: proposal.amount.toString(),
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
    RestaurantJournalSaleOutcome
  >
  evaluateVoid({
    required SaleVoidCommand command,
    required PortableJournalState state,
    required DateOnly cutoverDate,
    required RestaurantJournalMapper mapper,
  }) {
    final sales = (state.account.toJson()['sales'] as List)
        .cast<Map<String, Object?>>();
    final matches = sales.where((s) => s['id'] == command.saleId).toList();
    if (matches.isEmpty) {
      return const DurableProposalEvaluation.reject(
        rejectionCode: RestaurantJournalSaleErrorCodes.saleNotFound,
        rejectionMessage: 'Target sale not found.',
      );
    }

    final targetSale = matches.first;
    if (targetSale['status'] != 'completed') {
      return const DurableProposalEvaluation.reject(
        rejectionCode: RestaurantJournalSaleErrorCodes.saleAlreadyVoid,
        rejectionMessage: 'Target sale is already void or not completed.',
      );
    }

    // Voids strictly reject any sale with returns in source or journals.
    final returns = (state.account.toJson()['saleReturns'] as List)
        .cast<Map<String, Object?>>();
    if (returns.any((r) => r['saleId'] == command.saleId)) {
      return const DurableProposalEvaluation.reject(
        rejectionCode:
            RestaurantJournalSaleErrorCodes.voidIneligibleSaleHasReturns,
        rejectionMessage:
            'Sale cannot be voided because returns exist for this sale.',
      );
    }

    if (state.journals.any(
      (j) =>
          j.sourceType == RestaurantJournalSourceType.saleReturn.name &&
          j.metadata['originalSaleId'] == command.saleId,
    )) {
      return const DurableProposalEvaluation.reject(
        rejectionCode:
            RestaurantJournalSaleErrorCodes.voidIneligibleSaleHasReturns,
        rejectionMessage: 'Sale cannot be voided because return journals exist for this sale.',
      );
    }

    // Historical source must have an eligible post-cutover journal.
    final postCutoverJournals = state.journals
        .where(
          (j) =>
              j.sourceRecordId == command.saleId &&
              j.sourceType == RestaurantJournalSourceType.sale.name &&
              j.journal.reversesId == null &&
              j.journal.effectiveDate.compareTo(cutoverDate) >= 0,
        )
        .toList();

    if (postCutoverJournals.isEmpty) {
      return const DurableProposalEvaluation.reject(
        rejectionCode: RestaurantJournalSaleErrorCodes
            .crossCutoverSourceHasNoPostCutoverJournal,
        rejectionMessage: 'Historical sale has no eligible post-cutover journal under cross-cutover gate.',
      );
    }
    if (postCutoverJournals.length != 1 ||
        !_postingMatchesSale(postCutoverJournals.first, targetSale, mapper)) {
      return const DurableProposalEvaluation.reject(
        rejectionCode: 'sale_posting_mismatch',
        rejectionMessage: 'Saved sale and its posting do not reconcile.',
      );
    }

    final originalEntry = postCutoverJournals.first;

    if (state.journals.any(
      (j) => j.journal.reversesId == originalEntry.journal.id,
    )) {
      return const DurableProposalEvaluation.reject(
        rejectionCode: RestaurantJournalSaleErrorCodes.alreadyReversed,
        rejectionMessage: 'Sale journal has already been reversed.',
      );
    }

    // Update source record: mark status as 'void'.
    final accountJson = state.account.toJson();
    final updatedSales = <Map<String, Object?>>[];
    for (final s
        in (accountJson['sales'] as List).cast<Map<String, Object?>>()) {
      if (s['id'] == command.saleId) {
        final updated = Map<String, Object?>.from(s);
        updated['status'] = 'void';
        updated['voidReason'] = command.reason.trim();
        updated['voidedAt'] = command.voidedAt;
        updatedSales.add(updated);
      } else {
        updatedSales.add(s);
      }
    }

    AccountDocument candidateAccount;
    try {
      candidateAccount = const LegacyAccountCodec().decodeJson({
        ...accountJson,
        'sales': updatedSales,
      });
    } catch (e) {
      return DurableProposalEvaluation.reject(
        rejectionCode:
            RestaurantJournalSaleErrorCodes.voidIneligibleSourceRejection,
        rejectionMessage: e.toString(),
      );
    }

    final receiptNumber =
        (originalEntry.metadata['receiptNumber'] as String?) ??
        (targetSale['number'] as String?) ??
        originalEntry.journal.id;

    final originalProposal = RestaurantJournalProposal(
      journal: originalEntry.journal,
      sourceType: RestaurantJournalSourceType.sale,
      sourceRecordId: command.saleId,
      receiptNumber: receiptNumber,
      sourceVersion: (originalEntry.metadata['sourceVersion'] as int?) ?? 11,
      metadata: originalEntry.metadata,
    );

    RestaurantJournalProposal voidProposal;
    try {
      voidProposal = mapper.mapOriginalDateVoid(
        originalProposal: originalProposal,
        reversalJournalId: command.reversalJournalId,
        reason: command.reason.trim(),
        isEligible: true,
        voidRecordId: command.voidRecordId ?? command.saleId,
      );
    } on RestaurantJournalMappingException catch (e) {
      return DurableProposalEvaluation.reject(
        rejectionCode: e.code,
        rejectionMessage: e.toString(),
      );
    } catch (e) {
      return DurableProposalEvaluation.reject(
        rejectionCode: RestaurantJournalSaleErrorCodes.voidMappingFailed,
        rejectionMessage: e.toString(),
      );
    }

    final composedMetadata = <String, Object?>{
      ...originalEntry.metadata,
      'reversalReason': command.reason.trim(),
      'originalJournalId': originalEntry.journal.id,
      'sourceVersion': voidProposal.sourceVersion,
      'receiptNumber': receiptNumber,
      'operationId': command.operationId,
      'saleId': command.saleId,
    };

    for (final key in composedMetadata.keys.toList()) {
      final v = composedMetadata[key];
      if (v is BigInt) {
        composedMetadata[key] = v.toString();
      }
    }

    final entry = PortableJournalEntry(
      journal: voidProposal.journal,
      sourceType: voidProposal.sourceType.name,
      sourceRecordId: command.voidRecordId ?? command.saleId,
      recordedAt: command.voidedAt,
      metadata: composedMetadata,
    );

    final candidateState = state.copyWith(
      account: candidateAccount,
      journals: [...state.journals, entry],
    );

    final outcome = RestaurantJournalSaleOutcome(
      commandType: command.commandType,
      operationId: command.operationId,
      saleId: command.saleId,
      journalId: command.reversalJournalId,
      receiptNumber: receiptNumber,
      effectiveDate: voidProposal.journal.effectiveDate.toString(),
      netAmount: voidProposal.journal.totalUnits.toString(),
      metadata: composedMetadata,
    );

    return DurableProposalEvaluation.accept(
      candidateState: candidateState,
      outcome: outcome,
      outcomePayload: outcome.toOutcomePayload(),
    );
  }
}

/// Restaurant source-record mapping delegates all financial arithmetic to Madar.
SaleCalculation _sourceSaleQuote(Map<String, Object?> sale) {
  final policy = CommercePolicy(
    quantityScale: 3,
    maximumQuantityUnits: RestaurantJournalPolicies.defaultLimit,
    maximumMoney: RestaurantJournalPolicies.defaultLimit,
    maximumSafeInteger: RestaurantJournalPolicies.maximumSafeAggregate,
    rounding: DecimalRounding.halfTowardPositiveInfinity,
  );
  return CommerceCalculations.saleQuote(
    (sale['lines'] as List).cast<Map<String, Object?>>().map(
      (line) => CommerceCalculations.lineTotal(
        QuantityPrice(
          quantityUnits: ExactDecimal.parse(
            '${line['quantity']}',
            scale: 3,
            maxAbsUnits: RestaurantJournalPolicies.defaultLimit,
            signed: false,
            positive: true,
            allowExponent: true,
          ).units,
          price: BigInt.from(line['price'] as int),
        ),
        policy: policy,
      ),
    ),
    discount: BigInt.from(sale['discount'] as int),
    policy: policy,
  );
}

bool _samePosting(BalancedJournal a, BalancedJournal b) {
  if (a.id != b.id ||
      a.effectiveDate != b.effectiveDate ||
      a.totalUnits != b.totalUnits ||
      a.lines.length != b.lines.length) {
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

bool _postingMatchesSale(
  PortableJournalEntry entry,
  Map<String, Object?> sale,
  RestaurantJournalMapper mapper,
) {
  try {
    final quote = _sourceSaleQuote(sale);
    final version = entry.metadata['sourceVersion'];
    if (entry.recordedAt != sale['createdAt'] ||
        entry.metadata['receiptNumber'] != sale['number'] ||
        entry.metadata['gross'] != quote.subtotal.toString() ||
        entry.metadata['discount'] != quote.discount.toString() ||
        entry.metadata['net'] != quote.net.toString() ||
        version is! int ||
        version < 1 ||
        version > 12) {
      return false;
    }
    final expected = mapper.mapSaleTicket(
      journalId: entry.journal.id,
      saleId: sale['id'] as String,
      receiptNumber: sale['number'] as String,
      effectiveDate: DateOnly.parse(
        sale['date'] as String,
        minimumYear: 1000,
        maximumYear: 9999,
      ),
      grossAmount: quote.subtotal,
      discountAmount: quote.discount,
      netAmount: quote.net,
      policy: entry.journal.policy,
    );
    return _samePosting(entry.journal, expected.journal);
  } catch (_) {
    return false;
  }
}

bool _replayMatchesSource(
  RestaurantJournalSaleCommand command,
  RestaurantJournalSaleOutcome outcome,
  PortableJournalState state,
  RestaurantJournalMapper mapper,
) {
  try {
    if (outcome.operationId != command.operationId ||
        outcome.commandType != command.commandType ||
        outcome.saleId != command.saleId ||
        outcome.journalId != command.journalId) {
      return false;
    }
    final journals = state.journals
        .where((j) => j.journal.id == outcome.journalId)
        .toList();
    final sales = (state.account.toJson()['sales'] as List)
        .cast<Map<String, Object?>>()
        .where((sale) => sale['id'] == command.saleId)
        .toList();
    if (journals.length != 1 || sales.length != 1) {
      return false;
    }
    final entry = journals.single, sale = sales.single;
    if (entry.metadata['operationId'] != command.operationId ||
        outcome.netAmount != entry.journal.totalUnits.toString() ||
        outcome.effectiveDate != entry.journal.effectiveDate.toString() ||
        outcome.receiptNumber != sale['number'] ||
        _canonicalIdentity(outcome.metadata) !=
            _canonicalIdentity(entry.metadata)) {
      return false;
    }
    switch (command) {
      case CompleteSaleCommand():
        return outcome.returnId == null &&
            entry.sourceType == 'sale' &&
            entry.sourceRecordId == command.saleId &&
            _postingMatchesSale(entry, sale, mapper);
      case SaleReturnCommand():
        final returns = (state.account.toJson()['saleReturns'] as List)
            .cast<Map<String, Object?>>()
            .where((r) => r['id'] == command.returnId)
            .toList();
        return outcome.returnId == command.returnId &&
            entry.sourceType == 'saleReturn' &&
            entry.sourceRecordId == command.returnId &&
            returns.length == 1 &&
            returns.single['saleId'] == command.saleId &&
            returns.single['date'] == outcome.effectiveDate &&
            BigInt.from(returns.single['amount'] as int).toString() ==
                outcome.netAmount;
      case SaleVoidCommand():
        return outcome.returnId == null &&
            entry.sourceType == 'voidReversal' &&
            entry.sourceRecordId == (command.voidRecordId ?? command.saleId) &&
            entry.journal.reversesId != null &&
            sale['date'] == outcome.effectiveDate &&
            _sourceSaleQuote(sale).net.toString() == outcome.netAmount;
    }
  } catch (_) {
    return false;
  }
}
