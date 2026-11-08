import 'dart:convert';

import 'package:madar_application/madar_application.dart';
import 'package:madar_domain/madar_domain.dart';

import '../accounts/legacy_account_codec.dart';
import '../accounts/portable_journal_codec.dart';
import '../accounts/portable_journal_state.dart';
import 'journal_command_host.dart';
import 'source_record_order.dart';
import 'restaurant_journal_expense_history.dart';
import 'restaurant_journal_mapper.dart';

/// Receipt-backed corrections of eligible operating expenses, without UI or
/// schema activation. Capture a fence before constructing either command.
sealed class OperatingExpenseCorrectionCommand {
  OperatingExpenseCorrectionCommand({
    required this.operationId,
    this.payloadVersion = 1,
    required this.accountLineage,
    this.expectedFence,
    required this.expenseId,
    required this.expectedActiveJournalId,
    required this.inverseJournalId,
    required this.reason,
    required this.recordedAt,
    this.profile = const RestaurantAccountProfile(),
    this.policy,
    JournalPolicy? mapperDefaultPolicy,
  }) : mapperDefaultPolicy =
           mapperDefaultPolicy ?? RestaurantJournalPolicies.standard {
    for (final value in [
      operationId,
      accountLineage,
      expenseId,
      expectedActiveJournalId,
      inverseJournalId,
      recordedAt,
    ]) {
      if (value.isEmpty || value.trim() != value) {
        throw const FormatException('invalid_expense_correction_identity');
      }
    }
    if (payloadVersion <= 0 ||
        reason.trim().isEmpty ||
        inverseJournalId == expectedActiveJournalId) {
      throw const FormatException('invalid_expense_correction_intent');
    }
  }

  final String operationId;
  final int payloadVersion;
  final String accountLineage;
  final StorageFence? expectedFence;
  final String expenseId;
  final String expectedActiveJournalId;
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
    'expenseId': expenseId,
    'expectedActiveJournalId': expectedActiveJournalId,
    'inverseJournalId': inverseJournalId,
    'reason': reason,
    'recordedAt': recordedAt,
    'profile': expenseProfileIdentity(profile),
    'mapperDefaultPolicy': expensePolicyIdentity(mapperDefaultPolicy),
    if (policy != null) 'policy': expensePolicyIdentity(policy!),
  };
}

/// Replaces a current expense at the chosen post-cutover date. Funding defaults
/// match create-expense; shared funding requires both shares. Raw note/reason
/// remain part of identity even though the source stores a trimmed note.
final class EditOperatingExpenseCommand
    extends OperatingExpenseCorrectionCommand {
  EditOperatingExpenseCommand({
    required super.operationId,
    super.payloadVersion,
    required super.accountLineage,
    super.expectedFence,
    required super.expenseId,
    required super.expectedActiveJournalId,
    required super.inverseJournalId,
    required this.replacementJournalId,
    required this.date,
    required this.categoryId,
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
        amount.isNegative ||
        this.dailyAmount.isNegative ||
        this.cashAmount.isNegative ||
        this.dailyAmount + this.cashAmount != amount ||
        (fundingSource == FundingSource.daily &&
            this.cashAmount != BigInt.zero) ||
        (fundingSource == FundingSource.cash &&
            this.dailyAmount != BigInt.zero)) {
      throw const FormatException('invalid_expense_correction_intent');
    }
    canonicalPayloadIdentity = canonicalIdentity({
      ...commonIntent,
      'replacementJournalId': replacementJournalId,
      'date': date.toString(),
      'categoryId': categoryId,
      'amount': amount.toString(),
      'fundingSource': fundingSource.name,
      'dailyAmount': this.dailyAmount.toString(),
      'cashAmount': this.cashAmount.toString(),
      'note': note,
      if (sourceOrder != null) 'sourceOrder': sourceOrder!.toJson(),
    });
  }
  final String replacementJournalId;
  final DateOnly date;
  final String categoryId;
  final BigInt amount;
  final FundingSource fundingSource;
  final BigInt dailyAmount;
  final BigInt cashAmount;
  final String note;
  final SourceRecordOrder? sourceOrder;
  @override
  String get commandType => 'edit_operating_expense';
}

/// Removes only the source projection and appends an original-date inverse.
final class DeleteOperatingExpenseCommand
    extends OperatingExpenseCorrectionCommand {
  DeleteOperatingExpenseCommand({
    required super.operationId,
    super.payloadVersion,
    required super.accountLineage,
    super.expectedFence,
    required super.expenseId,
    required super.expectedActiveJournalId,
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
  String get commandType => 'delete_operating_expense';
}

/// Frozen receipt outcome; source snapshots and correction links live in the
/// corresponding immutable journal envelopes rather than a second store.
final class RestaurantJournalExpenseCorrectionOutcome {
  RestaurantJournalExpenseCorrectionOutcome({
    required this.commandType,
    required this.operationId,
    required this.expenseId,
    required this.targetJournalId,
    required this.inverseJournalId,
    this.replacementJournalId,
    required this.effectiveDate,
    required this.netAmount,
    required Map<String, Object?> metadata,
  }) : metadata = freezeMap(metadata);
  final String commandType,
      operationId,
      expenseId,
      targetJournalId,
      inverseJournalId,
      effectiveDate,
      netAmount;
  final String? replacementJournalId;
  final Map<String, Object?> metadata;
  Map<String, Object?> toJson() => {
    'commandType': commandType,
    'operationId': operationId,
    'expenseId': expenseId,
    'targetJournalId': targetJournalId,
    'inverseJournalId': inverseJournalId,
    'replacementJournalId': ?replacementJournalId,
    'effectiveDate': effectiveDate,
    'netAmount': netAmount,
    'metadata': metadata,
  };
  String toOutcomePayload() => jsonEncode(toJson());
  factory RestaurantJournalExpenseCorrectionOutcome.fromOutcomePayload(
    String payload,
  ) {
    final json = (jsonDecode(payload) as Map).cast<String, Object?>();
    final result = RestaurantJournalExpenseCorrectionOutcome(
      commandType: json['commandType'] as String,
      operationId: json['operationId'] as String,
      expenseId: json['expenseId'] as String,
      targetJournalId: json['targetJournalId'] as String,
      inverseJournalId: json['inverseJournalId'] as String,
      replacementJournalId: json['replacementJournalId'] as String?,
      effectiveDate: json['effectiveDate'] as String,
      netAmount: json['netAmount'] as String,
      metadata: (json['metadata'] as Map).cast<String, Object?>(),
    );
    if (canonicalIdentity(json) != canonicalIdentity(result.toJson())) {
      throw const FormatException('invalid_expense_correction_outcome');
    }
    return result;
  }
}

/// All persistence, CAS/fencing, receipt attachment and unknown-acknowledgement
/// recovery delegate to the public command host and Madar coordinator/store.
final class RestaurantJournalExpenseCorrectionCoordinator {
  RestaurantJournalExpenseCorrectionCoordinator({
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
  Future<DurableCommandResult<RestaurantJournalExpenseCorrectionOutcome>>
  execute(OperatingExpenseCorrectionCommand command) => host.execute(
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
            canonicalIdentity(expenseProfileIdentity(command.profile)) ==
                canonicalIdentity(expenseProfileIdentity(mapper.profile)) &&
            RestaurantJournalExpenseHistory.validate(
              state: state,
              expenseId: command.expenseId,
              mapper: mapper,
            );
      } catch (_) {
        return false;
      }
    },
    parseOutcome: RestaurantJournalExpenseCorrectionOutcome.fromOutcomePayload,
    evaluateProposal: (state, fence) =>
        evaluate(command: command, state: state, mapper: mapper),
  );

  static DurableProposalEvaluation<
    PortableJournalState,
    RestaurantJournalExpenseCorrectionOutcome
  >
  evaluate({
    required OperatingExpenseCorrectionCommand command,
    required PortableJournalState state,
    required RestaurantJournalMapper mapper,
  }) {
    DurableProposalEvaluation<
      PortableJournalState,
      RestaurantJournalExpenseCorrectionOutcome
    >
    reject(String code) => DurableProposalEvaluation.reject(
      rejectionCode: code,
      rejectionMessage: 'Operating-expense correction rejected.',
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
      if (canonicalIdentity(expenseProfileIdentity(command.profile)) !=
          canonicalIdentity(expenseProfileIdentity(mapper.profile))) {
        return reject('expense_profile_mismatch');
      }
      if (canonicalIdentity(
            expensePolicyIdentity(command.mapperDefaultPolicy),
          ) !=
          canonicalIdentity(expensePolicyIdentity(mapper.defaultPolicy))) {
        return reject('expense_policy_context_mismatch');
      }
      final rows = RestaurantJournalExpenseHistory.sourceRows(
        state,
        command.expenseId,
      );
      if (rows.length != 1) return reject('expense_not_found_or_ambiguous');
      final source = rows.single;
      final date = DateOnly.parse(
        source['date'] as String,
        minimumYear: 1000,
        maximumYear: 9999,
      );
      if (date.compareTo(cutover) < 0 ||
          (command is EditOperatingExpenseCommand &&
              command.date.compareTo(cutover) < 0)) {
        return reject('pre_cutover_operation_rejected');
      }
      final ids = [
        command.inverseJournalId,
        if (command is EditOperatingExpenseCommand)
          command.replacementJournalId,
      ];
      if (state.journals.any((j) => ids.contains(j.journal.id))) {
        return reject('duplicate_journal_id');
      }
      if (!RestaurantJournalExpenseHistory.validate(
        state: state,
        expenseId: command.expenseId,
        mapper: mapper,
        expectedActiveJournalId: command.expectedActiveJournalId,
      )) {
        return reject('expense_history_mismatch');
      }
      final target = state.journals.singleWhere(
        (j) => j.journal.id == command.expectedActiveJournalId,
      );
      // Delete policy is also captured and checked. The inverse must retain the
      // validated original journal policy, rather than quietly changing it.
      if (command is DeleteOperatingExpenseCommand &&
          command.policy != null &&
          canonicalIdentity(expensePolicyIdentity(command.policy!)) !=
              canonicalIdentity(expensePolicyIdentity(target.journal.policy))) {
        return reject('expense_policy_mismatch');
      }
      if (command is EditOperatingExpenseCommand &&
          !state.account.categories.any((c) => c['id'] == command.categoryId)) {
        return reject('missing_category');
      }
      final entries = RestaurantJournalExpenseHistory.correctionEntries(
        command: command,
        target: target,
        beforeSnapshot: source,
        mapper: mapper,
      );
      final raw = state.account.toJson();
      final days = Map<String, Object?>.from(raw['days'] as Map);
      final oldDay = Map<String, Object?>.from(days[date.toString()]! as Map);
      oldDay['expenses'] = (oldDay['expenses'] as List)
          .where((e) => (e as Map)['id'] != command.expenseId)
          .toList();
      days[date.toString()] = oldDay;
      if (command is EditOperatingExpenseCommand) {
        final newDate = command.date.toString();
        final day = days[newDate] == null
            ? <String, Object?>{
                'expenses': <Object?>[],
                'chickenUsed': 0,
                'chickenLeft': 0,
                'balance': null,
                'totalOverride': null,
                'remaining': null,
              }
            : Map<String, Object?>.from(days[newDate]! as Map);
        day['expenses'] = [
          ...day['expenses'] as List,
          RestaurantJournalExpenseHistory.replacementSource(command, source),
        ];
        if (command.sourceOrder != null) {
          day['expenses'] = command.sourceOrder!.applyRows(
            (day['expenses']! as List).cast<Map<String, Object?>>(),
            command.expenseId,
          );
        }
        days[newDate] = day;
      }
      final candidate = state.copyWith(
        account: const LegacyAccountCodec().decodeJson({...raw, 'days': days}),
        journals: [...state.journals, ...entries],
      );
      final outcome = RestaurantJournalExpenseHistory.outcome(
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
      return reject('invalid_expense_correction_proposal');
    }
  }
}

/// Complete mapper context captured in correction identity, including fields
/// outside the expense chart so changing context cannot reuse an operation ID.
Map<String, Object?> expenseProfileIdentity(RestaurantAccountProfile p) => {
  'dailyCashAccountId': p.dailyCashAccountId,
  'cashboxAccountId': p.cashboxAccountId,
  'salesRevenueAccountId': p.salesRevenueAccountId,
  'salesReturnContraAccountId': p.salesReturnContraAccountId,
  'purchasesExpenseAccountId': p.purchasesExpenseAccountId,
  'openingEquityAccountId': p.openingEquityAccountId,
  'supplierLiabilityPrefix': p.supplierLiabilityPrefix,
  'categoryExpensePrefix': p.categoryExpensePrefix,
};
Map<String, Object?> expensePolicyIdentity(JournalPolicy p) => {
  'currency': p.currency,
  'scale': p.scale,
  'maximumLines': p.maximumLines,
  'maximumLineUnits': p.maximumLineUnits.toString(),
  'maximumSideUnits': p.maximumSideUnits.toString(),
  'allowZeroLines': p.allowZeroLines,
};
