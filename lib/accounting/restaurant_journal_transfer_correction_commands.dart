import 'dart:convert';

import 'package:madar_application/madar_application.dart';
import 'package:madar_domain/madar_domain.dart';

import '../accounts/account_document.dart';
import '../accounts/legacy_account_codec.dart';
import '../accounts/portable_journal_codec.dart';
import '../accounts/portable_journal_state.dart';
import 'daily_cash_queries.dart';
import 'journal_command_host.dart';
import 'source_record_order.dart';
import 'restaurant_journal_mapper.dart';
import 'restaurant_journal_transfer_history.dart';

/// Error codes emitted by the restaurant transfer correction command layer.
abstract final class RestaurantJournalTransferCorrectionErrorCodes {
  static const accountLineageMismatch = 'account_lineage_mismatch';
  static const cutoverGated = 'cutover_gated';
  static const preCutoverOperationRejected = 'pre_cutover_operation_rejected';
  static const transferNotFound = 'transfer_not_found';
  static const staleTargetJournal = 'stale_target_journal';
  static const transferAlreadyReversed = 'transfer_already_reversed';
  static const crossCutoverSourceHasNoPostCutoverJournal =
      'cross_cutover_source_has_no_post_cutover_journal';
  static const transferPostingMismatch = 'transfer_posting_mismatch';
  static const missingRemainingSnapshot = 'missing_remaining_snapshot';
  static const excessiveTransferAmount = 'excessive_transfer_amount';
  static const zeroOrNegativeAmount = 'zero_or_negative_amount';
  static const duplicateJournalId = 'duplicate_journal_id';
  static const invalidTransferProposal = 'invalid_transfer_proposal';
  static const transferMappingFailed = 'transfer_mapping_failed';
  static const staleAuthorityFence = 'stale_authority_fence';
  static const tamperedCorrectionChain = 'tampered_correction_chain';
  static const zeroValueRequiresAllowZeroPolicy =
      'zero_value_requires_allow_zero_policy';
}

/// Frozen, validated outcome of a committed or replayed transfer correction command.
final class RestaurantJournalTransferCorrectionOutcome {
  RestaurantJournalTransferCorrectionOutcome({
    required this.commandType,
    required this.operationId,
    required this.transferId,
    required this.targetJournalId,
    required this.inverseJournalId,
    this.replacementJournalId,
    required this.effectiveDate,
    required this.netAmount,
    Map<String, Object?> metadata = const {},
  }) : metadata = RestaurantJournalTransferHistory.freezeMetadata(metadata) {
    _metadataIdentity = RestaurantJournalTransferHistory.canonicalIdentity(
      this.metadata,
    );
  }

  final String commandType;
  final String operationId;
  final String transferId;
  final String targetJournalId;
  final String inverseJournalId;
  final String? replacementJournalId;
  final String effectiveDate;
  final String netAmount;
  final Map<String, Object?> metadata;
  late final String _metadataIdentity;

  Map<String, Object?> toJson() => {
    'commandType': commandType,
    'operationId': operationId,
    'transferId': transferId,
    'targetJournalId': targetJournalId,
    'inverseJournalId': inverseJournalId,
    if (replacementJournalId != null)
      'replacementJournalId': replacementJournalId,
    'effectiveDate': effectiveDate,
    'netAmount': netAmount,
    if (metadata.isNotEmpty) 'metadata': metadata,
  };

  String toOutcomePayload() => jsonEncode(toJson());

  factory RestaurantJournalTransferCorrectionOutcome.fromJson(
    Map<String, Object?> json,
  ) {
    const allowed = {
      'commandType',
      'operationId',
      'transferId',
      'targetJournalId',
      'inverseJournalId',
      'replacementJournalId',
      'effectiveDate',
      'netAmount',
      'metadata',
    };
    if (!json.keys.every(allowed.contains)) {
      throw const FormatException('invalid_transfer_correction_outcome');
    }
    String text(String key) {
      final value = json[key];
      if (value is! String || value.isEmpty || value.trim() != value) {
        throw const FormatException('invalid_transfer_correction_outcome');
      }
      return value;
    }

    String? optional(String key) {
      final value = json[key];
      if (value == null) return null;
      if (value is! String || value.isEmpty || value.trim() != value) {
        throw const FormatException('invalid_transfer_correction_outcome');
      }
      return value;
    }

    final type = text('commandType');
    if (type != 'edit_daily_transfer' && type != 'delete_daily_transfer') {
      throw const FormatException('invalid_transfer_correction_outcome');
    }

    final date = text('effectiveDate');
    final amount = text('netAmount');
    if (!RegExp(r'^(0|[1-9][0-9]*)$').hasMatch(amount)) {
      throw const FormatException('invalid_transfer_correction_outcome');
    }
    DateOnly.parse(date, minimumYear: 1000, maximumYear: 9999);

    final replId = optional('replacementJournalId');
    if (type == 'edit_daily_transfer' && replId == null) {
      throw const FormatException('invalid_transfer_correction_outcome');
    }
    if (type == 'delete_daily_transfer' && replId != null) {
      throw const FormatException('invalid_transfer_correction_outcome');
    }

    final metadata = json['metadata'];
    if (metadata != null && metadata is! Map<String, Object?>) {
      throw const FormatException('invalid_transfer_correction_outcome');
    }

    return RestaurantJournalTransferCorrectionOutcome(
      commandType: type,
      operationId: text('operationId'),
      transferId: text('transferId'),
      targetJournalId: text('targetJournalId'),
      inverseJournalId: text('inverseJournalId'),
      replacementJournalId: replId,
      effectiveDate: date,
      netAmount: amount,
      metadata: metadata as Map<String, Object?>? ?? const {},
    );
  }

  factory RestaurantJournalTransferCorrectionOutcome.fromOutcomePayload(
    String payload,
  ) {
    final decoded = jsonDecode(payload) as Map<String, Object?>;
    return RestaurantJournalTransferCorrectionOutcome.fromJson(decoded);
  }

  @override
  bool operator ==(Object other) =>
      other is RestaurantJournalTransferCorrectionOutcome &&
      other.commandType == commandType &&
      other.operationId == operationId &&
      other.transferId == transferId &&
      other.targetJournalId == targetJournalId &&
      other.inverseJournalId == inverseJournalId &&
      other.replacementJournalId == replacementJournalId &&
      other.effectiveDate == effectiveDate &&
      other.netAmount == netAmount &&
      other._metadataIdentity == _metadataIdentity;

  @override
  int get hashCode => Object.hash(
    commandType,
    operationId,
    transferId,
    targetJournalId,
    inverseJournalId,
    replacementJournalId,
    effectiveDate,
    netAmount,
    _metadataIdentity,
  );

  @override
  String toString() =>
      'RestaurantJournalTransferCorrectionOutcome(type: $commandType, details: redacted)';
}

/// Durable command to edit an active daily-to-cashbox transfer on its original date.
final class EditDailyTransferCommand {
  EditDailyTransferCommand({
    required this.operationId,
    this.payloadVersion = 1,
    required this.accountLineage,
    this.expectedFence,
    required this.transferId,
    required this.expectedActiveJournalId,
    required this.inverseJournalId,
    required this.replacementJournalId,
    required this.newAmount,
    this.newDate,
    this.sourceOrder,
    required this.reason,
    required this.recordedAt,
    this.policy,
  }) {
    if (operationId.isEmpty || operationId.trim() != operationId) {
      throw const FormatException('Invalid operationId');
    }
    if (payloadVersion <= 0) {
      throw const FormatException('Payload version must be positive');
    }
    if (accountLineage.isEmpty || accountLineage.trim() != accountLineage) {
      throw const FormatException('Invalid accountLineage');
    }
    if (transferId.isEmpty || transferId.trim() != transferId) {
      throw const FormatException('Invalid transferId');
    }
    if (expectedActiveJournalId.isEmpty ||
        expectedActiveJournalId.trim() != expectedActiveJournalId) {
      throw const FormatException('Invalid expectedActiveJournalId');
    }
    if (inverseJournalId.isEmpty ||
        inverseJournalId.trim() != inverseJournalId) {
      throw const FormatException('Invalid inverseJournalId');
    }
    if (replacementJournalId.isEmpty ||
        replacementJournalId.trim() != replacementJournalId) {
      throw const FormatException('Invalid replacementJournalId');
    }
    if (inverseJournalId == replacementJournalId) {
      throw const FormatException(
        'inverseJournalId and replacementJournalId must be distinct',
      );
    }
    if (expectedActiveJournalId == inverseJournalId ||
        expectedActiveJournalId == replacementJournalId) {
      throw const FormatException(
        'expectedActiveJournalId cannot match correction journal IDs',
      );
    }
    if (reason.trim().isEmpty) {
      throw const FormatException('Edit reason is required');
    }
    if (recordedAt.isEmpty || recordedAt.trim() != recordedAt) {
      throw const FormatException('Invalid recordedAt');
    }
    if (newAmount <= BigInt.zero) {
      throw const FormatException('New transfer amount must be positive');
    }
    if (newAmount.abs() > RestaurantJournalPolicies.defaultLimit) {
      throw const FormatException('New transfer amount exceeds allowed limit');
    }

    canonicalPayloadIdentity = _computeCanonicalPayload(
      operationId: operationId,
      payloadVersion: payloadVersion,
      accountLineage: accountLineage,
      expectedFence: expectedFence,
      transferId: transferId,
      expectedActiveJournalId: expectedActiveJournalId,
      inverseJournalId: inverseJournalId,
      replacementJournalId: replacementJournalId,
      newAmount: newAmount,
      newDate: newDate,
      sourceOrder: sourceOrder,
      reason: reason,
      recordedAt: recordedAt,
      policy: policy,
    );
  }

  final String operationId;
  final int payloadVersion;
  final String accountLineage;
  final StorageFence? expectedFence;
  final String transferId;
  final String expectedActiveJournalId;
  final String inverseJournalId;
  final String replacementJournalId;
  final BigInt newAmount;
  final DateOnly? newDate;
  final SourceRecordOrder? sourceOrder;
  final String reason;
  final String recordedAt;
  final JournalPolicy? policy;

  late final String canonicalPayloadIdentity;

  String get commandType => 'edit_daily_transfer';

  DurableCommandIdentity get identity => DurableCommandIdentity(
    operationId: operationId,
    payloadVersion: payloadVersion,
    canonicalPayloadIdentity: canonicalPayloadIdentity,
  );

  static String _computeCanonicalPayload({
    required String operationId,
    required int payloadVersion,
    required String accountLineage,
    StorageFence? expectedFence,
    required String transferId,
    required String expectedActiveJournalId,
    required String inverseJournalId,
    required String replacementJournalId,
    required BigInt newAmount,
    DateOnly? newDate,
    SourceRecordOrder? sourceOrder,
    required String reason,
    required String recordedAt,
    JournalPolicy? policy,
  }) {
    final map = <String, Object?>{
      'accountLineage': accountLineage,
      'commandType': 'edit_daily_transfer',
      if (expectedFence != null)
        'expectedFence': {
          'generation': expectedFence.generation,
          'storeId': expectedFence.storeId,
        },
      'expectedActiveJournalId': expectedActiveJournalId,
      'inverseJournalId': inverseJournalId,
      'newAmount': newAmount.toString(),
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
      if (newDate != null) 'newDate': newDate.toString(),
      if (sourceOrder != null) 'sourceOrder': sourceOrder.toJson(),
      'reason': reason,
      'recordedAt': recordedAt,
      'replacementJournalId': replacementJournalId,
      'transferId': transferId,
    };
    return RestaurantJournalTransferHistory.canonicalIdentity(map);
  }
}

/// Durable command to delete an active daily-to-cashbox transfer on its original date.
final class DeleteDailyTransferCommand {
  DeleteDailyTransferCommand({
    required this.operationId,
    this.payloadVersion = 1,
    required this.accountLineage,
    this.expectedFence,
    required this.transferId,
    required this.expectedActiveJournalId,
    required this.inverseJournalId,
    required this.reason,
    required this.recordedAt,
    this.policy,
  }) {
    if (operationId.isEmpty || operationId.trim() != operationId) {
      throw const FormatException('Invalid operationId');
    }
    if (payloadVersion <= 0) {
      throw const FormatException('Payload version must be positive');
    }
    if (accountLineage.isEmpty || accountLineage.trim() != accountLineage) {
      throw const FormatException('Invalid accountLineage');
    }
    if (transferId.isEmpty || transferId.trim() != transferId) {
      throw const FormatException('Invalid transferId');
    }
    if (expectedActiveJournalId.isEmpty ||
        expectedActiveJournalId.trim() != expectedActiveJournalId) {
      throw const FormatException('Invalid expectedActiveJournalId');
    }
    if (inverseJournalId.isEmpty ||
        inverseJournalId.trim() != inverseJournalId) {
      throw const FormatException('Invalid inverseJournalId');
    }
    if (expectedActiveJournalId == inverseJournalId) {
      throw const FormatException(
        'expectedActiveJournalId cannot match inverseJournalId',
      );
    }
    if (reason.trim().isEmpty) {
      throw const FormatException('Delete reason is required');
    }
    if (recordedAt.isEmpty || recordedAt.trim() != recordedAt) {
      throw const FormatException('Invalid recordedAt');
    }

    canonicalPayloadIdentity = _computeCanonicalPayload(
      operationId: operationId,
      payloadVersion: payloadVersion,
      accountLineage: accountLineage,
      expectedFence: expectedFence,
      transferId: transferId,
      expectedActiveJournalId: expectedActiveJournalId,
      inverseJournalId: inverseJournalId,
      reason: reason,
      recordedAt: recordedAt,
      policy: policy,
    );
  }

  final String operationId;
  final int payloadVersion;
  final String accountLineage;
  final StorageFence? expectedFence;
  final String transferId;
  final String expectedActiveJournalId;
  final String inverseJournalId;
  final String reason;
  final String recordedAt;
  final JournalPolicy? policy;

  late final String canonicalPayloadIdentity;

  String get commandType => 'delete_daily_transfer';

  DurableCommandIdentity get identity => DurableCommandIdentity(
    operationId: operationId,
    payloadVersion: payloadVersion,
    canonicalPayloadIdentity: canonicalPayloadIdentity,
  );

  static String _computeCanonicalPayload({
    required String operationId,
    required int payloadVersion,
    required String accountLineage,
    StorageFence? expectedFence,
    required String transferId,
    required String expectedActiveJournalId,
    required String inverseJournalId,
    required String reason,
    required String recordedAt,
    JournalPolicy? policy,
  }) {
    final map = <String, Object?>{
      'accountLineage': accountLineage,
      'commandType': 'delete_daily_transfer',
      if (expectedFence != null)
        'expectedFence': {
          'generation': expectedFence.generation,
          'storeId': expectedFence.storeId,
        },
      'expectedActiveJournalId': expectedActiveJournalId,
      'inverseJournalId': inverseJournalId,
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
      'transferId': transferId,
    };
    return RestaurantJournalTransferHistory.canonicalIdentity(map);
  }
}

/// Coordinates atomic execution, lineage validation, fence checks, and replay
/// reconciliation for transfer edit and delete correction commands.
final class RestaurantJournalTransferCorrectionCommandCoordinator {
  RestaurantJournalTransferCorrectionCommandCoordinator({
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

  /// Executes an [EditDailyTransferCommand].
  Future<DurableCommandResult<RestaurantJournalTransferCorrectionOutcome>>
  executeEdit(EditDailyTransferCommand command) {
    return host.execute<RestaurantJournalTransferCorrectionOutcome>(
      identity: command.identity,
      accountLineage: command.accountLineage,
      expectedFence: command.expectedFence,
      missingAuthorityFenceMessage: 'Capture account authority before submitting a transfer edit command.',
      accountLineageMismatchCode:
          RestaurantJournalTransferCorrectionErrorCodes.accountLineageMismatch,
      cutoverGatedCode:
          RestaurantJournalTransferCorrectionErrorCodes.cutoverGated,
      validateReplayOutcome: (payload, state) {
        try {
          final outcome =
              RestaurantJournalTransferCorrectionOutcome.fromOutcomePayload(
                payload,
              );
          return _replayMatchesSourceForEdit(command, outcome, state, mapper);
        } catch (_) {
          return false;
        }
      },
      parseOutcome:
          RestaurantJournalTransferCorrectionOutcome.fromOutcomePayload,
      evaluateProposal: (state, fence) => evaluateEdit(
        command: command,
        state: state,
        cutoverDate: state.cutoverState.cutoverDate!,
        mapper: mapper,
      ),
    );
  }

  /// Executes a [DeleteDailyTransferCommand].
  Future<DurableCommandResult<RestaurantJournalTransferCorrectionOutcome>>
  executeDelete(DeleteDailyTransferCommand command) {
    return host.execute<RestaurantJournalTransferCorrectionOutcome>(
      identity: command.identity,
      accountLineage: command.accountLineage,
      expectedFence: command.expectedFence,
      missingAuthorityFenceMessage: 'Capture account authority before submitting a transfer delete command.',
      accountLineageMismatchCode:
          RestaurantJournalTransferCorrectionErrorCodes.accountLineageMismatch,
      cutoverGatedCode:
          RestaurantJournalTransferCorrectionErrorCodes.cutoverGated,
      validateReplayOutcome: (payload, state) {
        try {
          final outcome =
              RestaurantJournalTransferCorrectionOutcome.fromOutcomePayload(
                payload,
              );
          return _replayMatchesSourceForDelete(command, outcome, state, mapper);
        } catch (_) {
          return false;
        }
      },
      parseOutcome:
          RestaurantJournalTransferCorrectionOutcome.fromOutcomePayload,
      evaluateProposal: (state, fence) => evaluateDelete(
        command: command,
        state: state,
        cutoverDate: state.cutoverState.cutoverDate!,
        mapper: mapper,
      ),
    );
  }

  /// Evaluates an [EditDailyTransferCommand] proposal against current state.
  static DurableProposalEvaluation<
    PortableJournalState,
    RestaurantJournalTransferCorrectionOutcome
  >
  evaluateEdit({
    required EditDailyTransferCommand command,
    required PortableJournalState state,
    required DateOnly cutoverDate,
    required RestaurantJournalMapper mapper,
  }) {
    if (command.newDate != null) {
      return const DurableProposalEvaluation.reject(
        rejectionCode: 'date_shift_batch_required',
        rejectionMessage:
            'Transfer date changes require an atomic day-date batch.',
      );
    }
    final accountJson = state.account.toJson();
    final rawTransfers = (accountJson['transfers'] as List? ?? const [])
        .cast<Map<String, Object?>>();

    final targetMatches = rawTransfers
        .where((t) => t['id'] == command.transferId)
        .toList();
    if (targetMatches.isEmpty) {
      return const DurableProposalEvaluation.reject(
        rejectionCode:
            RestaurantJournalTransferCorrectionErrorCodes.transferNotFound,
        rejectionMessage: 'Target transfer does not exist in source records.',
      );
    }
    final targetTransfer = targetMatches.single;

    final dateStr = targetTransfer['date'] as String;
    final transferDate = DateOnly.parse(
      dateStr,
      minimumYear: 1000,
      maximumYear: 9999,
    );

    // 1. Cutover date gate
    if (transferDate.compareTo(cutoverDate) < 0) {
      return const DurableProposalEvaluation.reject(
        rejectionCode: RestaurantJournalTransferCorrectionErrorCodes
            .preCutoverOperationRejected,
        rejectionMessage: 'Target transfer date precedes cutover date.',
      );
    }

    // 2. Validate amount limits
    if (command.newAmount <= BigInt.zero) {
      return const DurableProposalEvaluation.reject(
        rejectionCode:
            RestaurantJournalTransferCorrectionErrorCodes.zeroOrNegativeAmount,
        rejectionMessage: 'New transfer amount must be positive.',
      );
    }
    if (command.newAmount.abs() > RestaurantJournalPolicies.defaultLimit) {
      return const DurableProposalEvaluation.reject(
        rejectionCode: RestaurantJournalTransferCorrectionErrorCodes
            .invalidTransferProposal,
        rejectionMessage: 'New transfer amount exceeds allowed limit.',
      );
    }

    // 3. Duplicate journal check
    if (state.journals.any((j) => j.journal.id == command.inverseJournalId) ||
        state.journals.any(
          (j) => j.journal.id == command.replacementJournalId,
        )) {
      return const DurableProposalEvaluation.reject(
        rejectionCode:
            RestaurantJournalTransferCorrectionErrorCodes.duplicateJournalId,
        rejectionMessage: 'Correction journal ID already exists.',
      );
    }

    // 4. Expected active journal check
    final activeMatches = state.journals
        .where((j) => j.journal.id == command.expectedActiveJournalId)
        .toList();
    if (activeMatches.isEmpty) {
      return const DurableProposalEvaluation.reject(
        rejectionCode:
            RestaurantJournalTransferCorrectionErrorCodes.staleTargetJournal,
        rejectionMessage: 'Expected active journal entry not found.',
      );
    }
    final targetEntry = activeMatches.single;

    if (targetEntry.sourceRecordId != command.transferId ||
        targetEntry.journal.reversesId != null ||
        targetEntry.journal.effectiveDate != transferDate ||
        targetEntry.journal.totalUnits.toInt() !=
            (targetTransfer['amount'] as int)) {
      return const DurableProposalEvaluation.reject(
        rejectionCode:
            RestaurantJournalTransferCorrectionErrorCodes.staleTargetJournal,
        rejectionMessage: 'Expected active journal does not match the active transfer record.',
      );
    }

    if (state.journals.any(
      (j) => j.journal.reversesId == targetEntry.journal.id,
    )) {
      return const DurableProposalEvaluation.reject(
        rejectionCode: RestaurantJournalTransferCorrectionErrorCodes
            .transferAlreadyReversed,
        rejectionMessage: 'Target journal has already been reversed.',
      );
    }

    if (!RestaurantJournalTransferHistory.validateTransferLineage(
      state: state,
      transferId: command.transferId,
      expectedActiveJournalId: command.expectedActiveJournalId,
      mapper: mapper,
    )) {
      return const DurableProposalEvaluation.reject(
        rejectionCode: RestaurantJournalTransferCorrectionErrorCodes
            .tamperedCorrectionChain,
        rejectionMessage:
            'Transfer history does not reconcile with captured intent.',
      );
    }

    // 5. Remaining snapshot requirement
    final rawDays = (accountJson['days'] as Map<String, Object?>?) ?? const {};
    final dayData = rawDays[dateStr] as Map<String, Object?>?;
    if (dayData == null || dayData['remaining'] == null) {
      return const DurableProposalEvaluation.reject(
        rejectionCode: RestaurantJournalTransferCorrectionErrorCodes
            .missingRemainingSnapshot,
        rejectionMessage:
            'Daily cash register has no recorded remaining snapshot.',
      );
    }

    // 6. Available remaining calculation
    final dailyQueries = DailyCashQueries(state.account);
    final dailySnapshot = dailyQueries.day(dateStr);
    final available = dailySnapshot.remaining;
    if (available == null) {
      return const DurableProposalEvaluation.reject(
        rejectionCode: RestaurantJournalTransferCorrectionErrorCodes
            .missingRemainingSnapshot,
        rejectionMessage: 'Daily remaining snapshot is not recorded.',
      );
    }

    // model.js transferRemaining parity:
    // assert(amount <= available + (old?.amount || 0), 'مبلغ الإيداع أكبر من الرصيد المتبقي.');
    final oldAmount = BigInt.from(targetTransfer['amount'] as num);
    final maxAllowed = available + oldAmount;
    if (command.newAmount > maxAllowed) {
      return const DurableProposalEvaluation.reject(
        rejectionCode: RestaurantJournalTransferCorrectionErrorCodes
            .excessiveTransferAmount,
        rejectionMessage: 'New transfer amount exceeds available remaining.',
      );
    }

    // 7. Recover unset total if balance is null
    final dayMap = Map<String, Object?>.from(dayData);
    if (dayMap['balance'] == null) {
      final totalSpent = dailySnapshot.total;
      final sum = totalSpent + available + dailySnapshot.transferred;
      if (sum.abs() > RestaurantJournalPolicies.defaultLimit ||
          sum.abs() > RestaurantJournalPolicies.maximumSafeAggregate) {
        return const DurableProposalEvaluation.reject(
          rejectionCode: RestaurantJournalTransferCorrectionErrorCodes
              .invalidTransferProposal,
          rejectionMessage: 'Recovered total balance exceeds safe bounds.',
        );
      }
      dayMap['balance'] = sum.toInt();
    }

    // 8. Update source records: keep ID, date, createdAt; remove old row and append updated row
    final newTransferRow = <String, Object?>{
      'id': targetTransfer['id'],
      'date': dateStr,
      'amount': command.newAmount.toInt(),
      'createdAt': targetTransfer['createdAt'],
    };

    final updatedTransfers = [
      ...rawTransfers.where((t) => t['id'] != command.transferId),
      newTransferRow,
    ];
    if (command.sourceOrder != null) {
      try {
        final ordered = command.sourceOrder!.applyRows(
          updatedTransfers.cast<Map<String, Object?>>(),
          command.transferId,
        );
        updatedTransfers
          ..clear()
          ..addAll(ordered);
      } on FormatException catch (error) {
        return DurableProposalEvaluation.reject(
          rejectionCode: error.message,
          rejectionMessage: 'Transfer source ordering changed.',
        );
      }
    }
    final updatedDays = Map<String, Object?>.from(rawDays)..[dateStr] = dayMap;

    AccountDocument candidateAccount;
    try {
      candidateAccount = const LegacyAccountCodec().decodeJson({
        ...accountJson,
        'days': updatedDays,
        'transfers': updatedTransfers,
      });
    } catch (e) {
      return DurableProposalEvaluation.reject(
        rejectionCode: RestaurantJournalTransferCorrectionErrorCodes
            .invalidTransferProposal,
        rejectionMessage: e.toString(),
      );
    }

    // 9. Snapshots for metadata
    final beforeSnapshot = <String, Object?>{
      'id': targetTransfer['id'],
      'date': dateStr,
      'amount': targetTransfer['amount'],
      'createdAt': targetTransfer['createdAt'],
    };

    late final List<PortableJournalEntry> entries;
    try {
      entries = RestaurantJournalTransferHistory.correctionEntries(
        target: targetEntry,
        transferId: command.transferId,
        operationId: command.operationId,
        inverseJournalId: command.inverseJournalId,
        replacementJournalId: command.replacementJournalId,
        newAmount: command.newAmount,
        reason: command.reason,
        recordedAt: command.recordedAt,
        beforeSnapshot: beforeSnapshot,
        mapper: mapper,
        policy: command.policy,
      );
    } on RestaurantJournalMappingException catch (error) {
      return DurableProposalEvaluation.reject(
        rejectionCode: error.code,
        rejectionMessage: 'Transfer correction mapping rejected.',
      );
    } catch (_) {
      return const DurableProposalEvaluation.reject(
        rejectionCode:
            RestaurantJournalTransferCorrectionErrorCodes.transferMappingFailed,
        rejectionMessage: 'Transfer correction cannot be mapped.',
      );
    }
    final inverseEntry = entries.first;
    final replacementEntry = entries.last;
    final replacementMetadata = replacementEntry.metadata;

    final candidateState = state.copyWith(
      account: candidateAccount,
      journals: [...state.journals, inverseEntry, replacementEntry],
    );

    final outcome = RestaurantJournalTransferCorrectionOutcome(
      commandType: command.commandType,
      operationId: command.operationId,
      transferId: command.transferId,
      targetJournalId: targetEntry.journal.id,
      inverseJournalId: command.inverseJournalId,
      replacementJournalId: command.replacementJournalId,
      effectiveDate: dateStr,
      netAmount: command.newAmount.toString(),
      metadata: replacementMetadata,
    );

    return DurableProposalEvaluation.accept(
      candidateState: candidateState,
      outcome: outcome,
      outcomePayload: outcome.toOutcomePayload(),
    );
  }

  /// Evaluates a [DeleteDailyTransferCommand] proposal against current state.
  static DurableProposalEvaluation<
    PortableJournalState,
    RestaurantJournalTransferCorrectionOutcome
  >
  evaluateDelete({
    required DeleteDailyTransferCommand command,
    required PortableJournalState state,
    required DateOnly cutoverDate,
    required RestaurantJournalMapper mapper,
  }) {
    final accountJson = state.account.toJson();
    final rawTransfers = (accountJson['transfers'] as List? ?? const [])
        .cast<Map<String, Object?>>();

    final targetMatches = rawTransfers
        .where((t) => t['id'] == command.transferId)
        .toList();
    if (targetMatches.isEmpty) {
      return const DurableProposalEvaluation.reject(
        rejectionCode:
            RestaurantJournalTransferCorrectionErrorCodes.transferNotFound,
        rejectionMessage: 'Target transfer does not exist in source records.',
      );
    }
    final targetTransfer = targetMatches.single;

    final dateStr = targetTransfer['date'] as String;
    final transferDate = DateOnly.parse(
      dateStr,
      minimumYear: 1000,
      maximumYear: 9999,
    );

    // 1. Cutover date gate
    if (transferDate.compareTo(cutoverDate) < 0) {
      return const DurableProposalEvaluation.reject(
        rejectionCode: RestaurantJournalTransferCorrectionErrorCodes
            .preCutoverOperationRejected,
        rejectionMessage: 'Target transfer date precedes cutover date.',
      );
    }

    // 2. Duplicate journal check
    if (state.journals.any((j) => j.journal.id == command.inverseJournalId)) {
      return const DurableProposalEvaluation.reject(
        rejectionCode:
            RestaurantJournalTransferCorrectionErrorCodes.duplicateJournalId,
        rejectionMessage: 'Inverse journal ID already exists.',
      );
    }

    // 3. Expected active journal check
    final activeMatches = state.journals
        .where((j) => j.journal.id == command.expectedActiveJournalId)
        .toList();
    if (activeMatches.isEmpty) {
      return const DurableProposalEvaluation.reject(
        rejectionCode:
            RestaurantJournalTransferCorrectionErrorCodes.staleTargetJournal,
        rejectionMessage: 'Expected active journal entry not found.',
      );
    }
    final targetEntry = activeMatches.single;

    if (targetEntry.sourceRecordId != command.transferId ||
        targetEntry.journal.reversesId != null ||
        targetEntry.journal.effectiveDate != transferDate ||
        targetEntry.journal.totalUnits.toInt() !=
            (targetTransfer['amount'] as int)) {
      return const DurableProposalEvaluation.reject(
        rejectionCode:
            RestaurantJournalTransferCorrectionErrorCodes.staleTargetJournal,
        rejectionMessage: 'Expected active journal does not match the active transfer record.',
      );
    }

    if (state.journals.any(
      (j) => j.journal.reversesId == targetEntry.journal.id,
    )) {
      return const DurableProposalEvaluation.reject(
        rejectionCode: RestaurantJournalTransferCorrectionErrorCodes
            .transferAlreadyReversed,
        rejectionMessage: 'Target journal has already been reversed.',
      );
    }

    if (!RestaurantJournalTransferHistory.validateTransferLineage(
      state: state,
      transferId: command.transferId,
      expectedActiveJournalId: command.expectedActiveJournalId,
      mapper: mapper,
    )) {
      return const DurableProposalEvaluation.reject(
        rejectionCode: RestaurantJournalTransferCorrectionErrorCodes
            .tamperedCorrectionChain,
        rejectionMessage:
            'Transfer history does not reconcile with captured intent.',
      );
    }

    // 4. Remaining snapshot requirement check
    final rawDays = (accountJson['days'] as Map<String, Object?>?) ?? const {};
    final dayData = rawDays[dateStr] as Map<String, Object?>?;
    if (dayData == null || dayData['remaining'] == null) {
      return const DurableProposalEvaluation.reject(
        rejectionCode: RestaurantJournalTransferCorrectionErrorCodes
            .missingRemainingSnapshot,
        rejectionMessage:
            'Daily cash register has no recorded remaining snapshot.',
      );
    }

    // 5. Update source records: remove transfer from source; preserve saved total and remaining snapshot
    final updatedTransfers = rawTransfers
        .where((t) => t['id'] != command.transferId)
        .toList();

    AccountDocument candidateAccount;
    try {
      candidateAccount = const LegacyAccountCodec().decodeJson({
        ...accountJson,
        'transfers': updatedTransfers,
      });
    } catch (e) {
      return DurableProposalEvaluation.reject(
        rejectionCode: RestaurantJournalTransferCorrectionErrorCodes
            .invalidTransferProposal,
        rejectionMessage: e.toString(),
      );
    }

    // 6. Snapshots for metadata
    final beforeSnapshot = <String, Object?>{
      'id': targetTransfer['id'],
      'date': dateStr,
      'amount': targetTransfer['amount'],
      'createdAt': targetTransfer['createdAt'],
    };

    late final PortableJournalEntry inverseEntry;
    try {
      inverseEntry = RestaurantJournalTransferHistory.correctionEntries(
        target: targetEntry,
        transferId: command.transferId,
        operationId: command.operationId,
        inverseJournalId: command.inverseJournalId,
        reason: command.reason,
        recordedAt: command.recordedAt,
        beforeSnapshot: beforeSnapshot,
        mapper: mapper,
        policy: command.policy,
      ).single;
    } on RestaurantJournalMappingException catch (error) {
      return DurableProposalEvaluation.reject(
        rejectionCode: error.code,
        rejectionMessage: 'Transfer correction mapping rejected.',
      );
    } catch (_) {
      return const DurableProposalEvaluation.reject(
        rejectionCode:
            RestaurantJournalTransferCorrectionErrorCodes.transferMappingFailed,
        rejectionMessage: 'Transfer correction cannot be mapped.',
      );
    }
    final inverseMetadata = inverseEntry.metadata;

    final candidateState = state.copyWith(
      account: candidateAccount,
      journals: [...state.journals, inverseEntry],
    );

    final outcome = RestaurantJournalTransferCorrectionOutcome(
      commandType: command.commandType,
      operationId: command.operationId,
      transferId: command.transferId,
      targetJournalId: targetEntry.journal.id,
      inverseJournalId: command.inverseJournalId,
      replacementJournalId: null,
      effectiveDate: dateStr,
      netAmount: targetEntry.journal.totalUnits.toString(),
      metadata: inverseMetadata,
    );

    return DurableProposalEvaluation.accept(
      candidateState: candidateState,
      outcome: outcome,
      outcomePayload: outcome.toOutcomePayload(),
    );
  }
}

bool _replayMatchesSourceForEdit(
  EditDailyTransferCommand command,
  RestaurantJournalTransferCorrectionOutcome outcome,
  PortableJournalState state,
  RestaurantJournalMapper mapper,
) => _replayMatchesCapturedIntent(
  command.identity,
  command.transferId,
  state,
  mapper,
);

bool _replayMatchesSourceForDelete(
  DeleteDailyTransferCommand command,
  RestaurantJournalTransferCorrectionOutcome outcome,
  PortableJournalState state,
  RestaurantJournalMapper mapper,
) => _replayMatchesCapturedIntent(
  command.identity,
  command.transferId,
  state,
  mapper,
);

bool _replayMatchesCapturedIntent(
  DurableCommandIdentity identity,
  String transferId,
  PortableJournalState state,
  RestaurantJournalMapper mapper,
) =>
    state.receipts.any(
      (receipt) =>
          receipt.identity == identity &&
          receipt.status == DurableCommandStatus.committed,
    ) &&
    RestaurantJournalTransferHistory.validateTransferLineage(
      state: state,
      transferId: transferId,
      mapper: mapper,
    );
