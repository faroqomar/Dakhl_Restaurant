import 'dart:convert';

import 'package:madar_application/madar_application.dart';
import 'package:madar_domain/madar_domain.dart';

import '../accounts/legacy_account_codec.dart';
import '../parties/purchase_proposal.dart';
import 'restaurant_journal_spending_commands.dart';
import '../accounts/portable_journal_codec.dart';
import '../accounts/portable_journal_state.dart';
import 'journal_command_host.dart';
import 'restaurant_journal_payment_history.dart';
import 'source_record_order.dart';
import 'restaurant_journal_mapper.dart';

/// Receipt-backed corrections of eligible standalone supplier payments, without UI or
/// schema activation. Capture a fence before constructing either command.
sealed class SupplierPaymentCorrectionCommand {
  SupplierPaymentCorrectionCommand({
    required this.operationId,
    this.payloadVersion = 1,
    required this.accountLineage,
    this.expectedFence,
    required this.paymentId,
    required this.expectedActiveJournalId,
    this.expectedSourceVersion = 11,
    required Map<String, Object?> expectedSource,
    required this.inverseJournalId,
    required this.reason,
    required this.recordedAt,
    this.profile = const RestaurantAccountProfile(),
    this.policy,
    JournalPolicy? mapperDefaultPolicy,
  }) : expectedSource = freezeMap(expectedSource),
       mapperDefaultPolicy =
           mapperDefaultPolicy ?? RestaurantJournalPolicies.standard {
    for (final value in [
      operationId,
      accountLineage,
      paymentId,
      expectedActiveJournalId,
      inverseJournalId,
      recordedAt,
    ]) {
      if (value.isEmpty || value.trim() != value) {
        throw const FormatException('invalid_payment_correction_identity');
      }
    }
    if (payloadVersion <= 0 ||
        expectedSourceVersion <= 0 ||
        reason.trim().isEmpty ||
        inverseJournalId == expectedActiveJournalId) {
      throw const FormatException('invalid_payment_correction_intent');
    }
  }

  final String operationId;
  final int payloadVersion;
  final String accountLineage;
  final StorageFence? expectedFence;
  final String paymentId;
  final String expectedActiveJournalId;
  final int expectedSourceVersion;
  final Map<String, Object?> expectedSource;
  final String inverseJournalId;
  final String reason;
  final String recordedAt;
  final RestaurantAccountProfile profile;
  final JournalPolicy? policy;
  final JournalPolicy mapperDefaultPolicy;
  String get commandType;
  late final String canonicalPayloadIdentity;
  DurableCommandIdentity get identity => DurableCommandIdentity(
    operationId: operationId,
    payloadVersion: payloadVersion,
    canonicalPayloadIdentity: canonicalPayloadIdentity,
  );

  Map<String, Object?> get commonIntent => {
    'commandType': commandType,
    'operationId': operationId,
    'payloadVersion': payloadVersion,
    'accountLineage': accountLineage,
    if (expectedFence != null)
      'expectedFence': {
        'storeId': expectedFence!.storeId,
        'generation': expectedFence!.generation,
      },
    'paymentId': paymentId,
    'expectedActiveJournalId': expectedActiveJournalId,
    'expectedSourceVersion': expectedSourceVersion,
    'expectedSource': expectedSource,
    'inverseJournalId': inverseJournalId,
    'reason': reason,
    'recordedAt': recordedAt,
    'profile': paymentProfileIdentity(profile),
    'mapperDefaultPolicy': paymentPolicyIdentity(mapperDefaultPolicy),
    if (policy != null) 'policy': paymentPolicyIdentity(policy!),
  };
}

/// Replaces a current payment at the chosen post-cutover date. Funding defaults
/// match create-payment; shared funding requires both shares. Raw note/reason
/// remain part of identity even though the source stores a trimmed note.
final class EditSupplierPaymentCommand
    extends SupplierPaymentCorrectionCommand {
  EditSupplierPaymentCommand({
    required super.operationId,
    super.payloadVersion,
    required super.accountLineage,
    super.expectedFence,
    required super.paymentId,
    required super.expectedActiveJournalId,
    super.expectedSourceVersion,
    required super.expectedSource,
    required super.inverseJournalId,
    required this.replacementJournalId,
    required this.date,
    required this.categoryId,
    required this.supplierId,
    this.invoiceId,
    required this.invoiceAmount,
    required this.debtAmount,
    required this.amount,
    required this.fundingSource,
    BigInt? dailyAmount,
    BigInt? cashAmount,
    this.note = '',
    this.sourceOrder,
    required super.reason,
    required super.recordedAt,
    super.profile,
    super.policy,
    super.mapperDefaultPolicy,
  }) : dailyAmount =
           dailyAmount ??
           (fundingSource == FundingSource.daily
               ? amount
               : fundingSource == FundingSource.cash
               ? BigInt.zero
               : throw const FormatException('missing_shared_funding')),
       cashAmount =
           cashAmount ??
           (fundingSource == FundingSource.cash
               ? amount
               : fundingSource == FundingSource.daily
               ? BigInt.zero
               : throw const FormatException('missing_shared_funding')) {
    if (replacementJournalId.isEmpty ||
        replacementJournalId.trim() != replacementJournalId ||
        categoryId.isEmpty ||
        categoryId.trim() != categoryId ||
        {
              expectedActiveJournalId,
              inverseJournalId,
              replacementJournalId,
            }.length !=
            3 ||
        amount <= BigInt.zero ||
        invoiceAmount.isNegative ||
        debtAmount.isNegative ||
        invoiceAmount + debtAmount != amount ||
        supplierId.isEmpty ||
        supplierId.trim() != supplierId ||
        (invoiceId != null &&
            (invoiceId!.isEmpty || invoiceId!.trim() != invoiceId)) ||
        this.dailyAmount.isNegative ||
        this.cashAmount.isNegative ||
        this.dailyAmount + this.cashAmount != amount ||
        (fundingSource == FundingSource.daily &&
            this.cashAmount != BigInt.zero) ||
        (fundingSource == FundingSource.cash &&
            this.dailyAmount != BigInt.zero)) {
      throw const FormatException('invalid_payment_correction_intent');
    }
    canonicalPayloadIdentity = canonicalIdentity({
      ...commonIntent,
      if (sourceOrder != null) 'sourceOrder': sourceOrder!.toJson(),
      'replacementJournalId': replacementJournalId,
      'date': date.toString(),
      'categoryId': categoryId,
      'supplierId': supplierId,
      'invoiceId': invoiceId,
      'invoiceAmount': invoiceAmount.toString(),
      'debtAmount': debtAmount.toString(),
      'amount': amount.toString(),
      'fundingSource': fundingSource.name,
      'dailyAmount': this.dailyAmount.toString(),
      'cashAmount': this.cashAmount.toString(),
      'note': note,
    });
  }
  final String replacementJournalId;
  final DateOnly date;
  final String categoryId;
  final String supplierId;
  final String? invoiceId;
  final BigInt invoiceAmount;
  final BigInt debtAmount;
  final BigInt amount;
  final FundingSource fundingSource;
  final BigInt dailyAmount;
  final BigInt cashAmount;
  final String note;
  final SourceRecordOrder? sourceOrder;
  @override
  String get commandType => 'edit_supplier_payment';
}

/// Removes only the source projection and appends an original-date inverse.
final class DeleteSupplierPaymentCommand
    extends SupplierPaymentCorrectionCommand {
  DeleteSupplierPaymentCommand({
    required super.operationId,
    super.payloadVersion,
    required super.accountLineage,
    super.expectedFence,
    required super.paymentId,
    required super.expectedActiveJournalId,
    super.expectedSourceVersion,
    required super.expectedSource,
    required super.inverseJournalId,
    required super.reason,
    required super.recordedAt,
    super.profile,
    super.policy,
    super.mapperDefaultPolicy,
  }) {
    canonicalPayloadIdentity = canonicalIdentity(commonIntent);
  }
  @override
  String get commandType => 'delete_supplier_payment';
}

/// Frozen receipt outcome; source snapshots and correction links live in the
/// corresponding immutable journal envelopes rather than a second store.
final class RestaurantJournalPaymentCorrectionOutcome {
  RestaurantJournalPaymentCorrectionOutcome({
    required this.commandType,
    required this.operationId,
    required this.paymentId,
    required this.targetJournalId,
    required this.inverseJournalId,
    this.replacementJournalId,
    required this.effectiveDate,
    required this.netAmount,
    required Map<String, Object?> metadata,
  }) : metadata = freezeMap(metadata);
  final String commandType,
      operationId,
      paymentId,
      targetJournalId,
      inverseJournalId,
      effectiveDate,
      netAmount;
  final String? replacementJournalId;
  final Map<String, Object?> metadata;
  Map<String, Object?> toJson() => {
    'commandType': commandType,
    'operationId': operationId,
    'paymentId': paymentId,
    'targetJournalId': targetJournalId,
    'inverseJournalId': inverseJournalId,
    'replacementJournalId': ?replacementJournalId,
    'effectiveDate': effectiveDate,
    'netAmount': netAmount,
    'metadata': metadata,
  };
  String toOutcomePayload() => jsonEncode(toJson());
  @override
  String toString() =>
      'RestaurantJournalPaymentCorrectionOutcome(type: $commandType, details: redacted)';
  factory RestaurantJournalPaymentCorrectionOutcome.fromOutcomePayload(
    String payload,
  ) {
    final json = (jsonDecode(payload) as Map).cast<String, Object?>();
    final result = RestaurantJournalPaymentCorrectionOutcome(
      commandType: json['commandType'] as String,
      operationId: json['operationId'] as String,
      paymentId: json['paymentId'] as String,
      targetJournalId: json['targetJournalId'] as String,
      inverseJournalId: json['inverseJournalId'] as String,
      replacementJournalId: json['replacementJournalId'] as String?,
      effectiveDate: json['effectiveDate'] as String,
      netAmount: json['netAmount'] as String,
      metadata: (json['metadata'] as Map).cast<String, Object?>(),
    );
    if (canonicalIdentity(json) != canonicalIdentity(result.toJson())) {
      throw const FormatException('invalid_payment_correction_outcome');
    }
    return result;
  }
}

/// All persistence, CAS/fencing, receipt attachment and unknown-acknowledgement
/// recovery delegate to the public command host and Madar coordinator/store.
final class RestaurantJournalPaymentCorrectionCoordinator {
  RestaurantJournalPaymentCorrectionCoordinator({
    required LocalDocumentWorkspaceStore store,
    JournalCommandHost? host,
    RestaurantJournalMapper? mapper,
    PortableJournalCodec? codec,
    DurableCommandCoordinator? coordinator,
  }) : host =
           host ??
           JournalCommandHost(
             store: store,
             codec: codec,
             coordinator: coordinator,
           ),
       mapper = mapper ?? RestaurantJournalMapper() {
    if (!identical(this.host.store, store)) {
      throw ArgumentError('Command host must use the same store owner.');
    }
  }
  final JournalCommandHost host;
  final RestaurantJournalMapper mapper;
  Future<DurableCommandResult<RestaurantJournalPaymentCorrectionOutcome>>
  execute(SupplierPaymentCorrectionCommand command) => host.execute(
    identity: command.identity,
    accountLineage: command.accountLineage,
    expectedFence: command.expectedFence,
    validateReplayOutcome: (payload, state) {
      try {
        final receipts = state.receipts.where(
          (r) =>
              r.identity == command.identity &&
              r.status == DurableCommandStatus.committed,
        );
        return receipts.length == 1 &&
            receipts.single.outcomePayload == payload &&
            canonicalIdentity(paymentProfileIdentity(command.profile)) ==
                canonicalIdentity(paymentProfileIdentity(mapper.profile)) &&
            RestaurantJournalPaymentHistory.validate(
              state: state,
              paymentId: command.paymentId,
              mapper: mapper,
            );
      } catch (_) {
        return false;
      }
    },
    parseOutcome: RestaurantJournalPaymentCorrectionOutcome.fromOutcomePayload,
    evaluateProposal: (state, fence) =>
        evaluate(command: command, state: state, mapper: mapper),
  );

  static DurableProposalEvaluation<
    PortableJournalState,
    RestaurantJournalPaymentCorrectionOutcome
  >
  evaluate({
    required SupplierPaymentCorrectionCommand command,
    required PortableJournalState state,
    required RestaurantJournalMapper mapper,
  }) {
    DurableProposalEvaluation<
      PortableJournalState,
      RestaurantJournalPaymentCorrectionOutcome
    >
    reject(String code) => DurableProposalEvaluation.reject(
      rejectionCode: code,
      rejectionMessage: 'Supplier-payment correction rejected.',
    );
    try {
      if (command.expectedFence == null) {
        return reject('missing_authority_fence');
      }
      if (command.accountLineage != state.accountLineage) {
        return reject('account_lineage_mismatch');
      }
      final cutover = state.cutoverState.cutoverDate;
      if (cutover == null ||
          state.cutoverState.isGated ||
          !state.cutoverState.hasActivePosting) {
        return reject('cutover_gated');
      }
      if (canonicalIdentity(paymentProfileIdentity(command.profile)) !=
          canonicalIdentity(paymentProfileIdentity(mapper.profile))) {
        return reject('payment_profile_mismatch');
      }
      if (canonicalIdentity(
            paymentPolicyIdentity(command.mapperDefaultPolicy),
          ) !=
          canonicalIdentity(paymentPolicyIdentity(mapper.defaultPolicy))) {
        return reject('payment_policy_context_mismatch');
      }
      final rows = RestaurantJournalPaymentHistory.sourceRows(
        state,
        command.paymentId,
      );
      if (rows.length != 1) return reject('payment_not_found_or_ambiguous');
      final source = rows.single;
      if (canonicalIdentity(source) !=
          canonicalIdentity(command.expectedSource)) {
        return reject('payment_source_changed');
      }
      final date = DateOnly.parse(
        source['date'] as String,
        minimumYear: 1000,
        maximumYear: 9999,
      );
      if (date.compareTo(cutover) < 0 ||
          (command is EditSupplierPaymentCommand &&
              command.date.compareTo(cutover) < 0)) {
        return reject('pre_cutover_operation_rejected');
      }
      final ids = [
        command.inverseJournalId,
        if (command is EditSupplierPaymentCommand) command.replacementJournalId,
      ];
      if (state.journals.any((j) => ids.contains(j.journal.id))) {
        return reject('duplicate_journal_id');
      }
      if (!RestaurantJournalPaymentHistory.validate(
        state: state,
        paymentId: command.paymentId,
        mapper: mapper,
        expectedActiveJournalId: command.expectedActiveJournalId,
      )) {
        return reject('payment_history_mismatch');
      }
      final target = state.journals.singleWhere(
        (j) => j.journal.id == command.expectedActiveJournalId,
      );
      if (target.metadata['sourceVersion'] != command.expectedSourceVersion) {
        return reject('payment_source_version_changed');
      }
      if (command is DeleteSupplierPaymentCommand &&
          command.policy != null &&
          canonicalIdentity(paymentPolicyIdentity(command.policy!)) !=
              canonicalIdentity(paymentPolicyIdentity(target.journal.policy))) {
        return reject('payment_policy_mismatch');
      }
      final raw = state.account.toJson();
      final reducedAccount = const LegacyAccountCodec().decodeJson({
        ...raw,
        'payments': (raw['payments'] as List)
            .where((p) => (p as Map)['id'] != command.paymentId)
            .toList(),
      });
      var candidateAccount = reducedAccount;
      if (command is EditSupplierPaymentCommand) {
        if (!state.account.categories.any(
          (c) => c['id'] == command.categoryId,
        )) {
          return reject('missing_category');
        }
        // The established create evaluator proves recognized invoice/opening
        // capacity against every other recorded payment, including future ones.
        // It is a pure eligibility check; its temporary journal is not persisted.
        final check =
            RestaurantJournalSpendingCommandCoordinator.evaluatePayment(
              command: CreateSupplierPaymentCommand(
                operationId: command.operationId,
                payloadVersion: command.payloadVersion,
                accountLineage: command.accountLineage,
                expectedFence: command.expectedFence,
                paymentId: command.paymentId,
                journalId: command.replacementJournalId,
                supplierId: command.supplierId,
                invoiceId: command.invoiceId,
                date: command.date,
                amount: command.amount,
                fundingSource: command.fundingSource,
                dailyAmount: command.dailyAmount,
                cashAmount: command.cashAmount,
                note: command.note,
                recordedAt: source['createdAt'] as String,
                policy: command.policy,
              ),
              state: state,
              excludingPaymentId: command.paymentId,
              cutoverDate: cutover,
              mapper: mapper,
            );
        if (check.rejected) return reject(check.rejectionCode!);
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
          categoryId: command.categoryId,
          date: command.date.toString(),
          createdAt: source['createdAt'] as String,
          note: command.note,
          editing: true,
        );
        if (command.sourceOrder != null) {
          candidateAccount = command.sourceOrder!.apply(
            candidateAccount,
            'payments',
            command.paymentId,
          );
        }
        final saved = (candidateAccount.toJson()['payments'] as List)
            .cast<Map<String, Object?>>()
            .singleWhere((p) => p['id'] == command.paymentId);
        if (saved['invoiceAmount'] != command.invoiceAmount.toInt() ||
            saved['debtAmount'] != command.debtAmount.toInt()) {
          return reject('payment_allocation_intent_mismatch');
        }
      }
      final entries = RestaurantJournalPaymentHistory.correctionEntries(
        command: command,
        target: target,
        beforeSnapshot: source,
        mapper: mapper,
      );
      final candidate = state.copyWith(
        account: candidateAccount,
        journals: [...state.journals, ...entries],
      );
      final outcome = RestaurantJournalPaymentHistory.outcome(
        command: command,
        target: target,
        entries: entries,
      );
      return DurableProposalEvaluation.accept(
        candidateState: candidate,
        outcome: outcome,
        outcomePayload: outcome.toOutcomePayload(),
      );
    } on RestaurantJournalMappingException catch (error) {
      return reject(error.code);
    } catch (_) {
      return reject('invalid_payment_correction_proposal');
    }
  }
}

/// Complete mapper context captured in correction identity, including fields
/// outside the payment chart so changing context cannot reuse an operation ID.
Map<String, Object?> paymentProfileIdentity(RestaurantAccountProfile p) => {
  'dailyCashAccountId': p.dailyCashAccountId,
  'cashboxAccountId': p.cashboxAccountId,
  'salesRevenueAccountId': p.salesRevenueAccountId,
  'salesReturnContraAccountId': p.salesReturnContraAccountId,
  'purchasesExpenseAccountId': p.purchasesExpenseAccountId,
  'openingEquityAccountId': p.openingEquityAccountId,
  'supplierLiabilityPrefix': p.supplierLiabilityPrefix,
  'categoryExpensePrefix': p.categoryExpensePrefix,
};
Map<String, Object?> paymentPolicyIdentity(JournalPolicy p) => {
  'currency': p.currency,
  'scale': p.scale,
  'maximumLines': p.maximumLines,
  'maximumLineUnits': p.maximumLineUnits.toString(),
  'maximumSideUnits': p.maximumSideUnits.toString(),
  'allowZeroLines': p.allowZeroLines,
};
