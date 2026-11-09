import 'dart:convert';

import 'package:madar_application/madar_application.dart';
import 'package:madar_domain/madar_domain.dart';

import '../accounts/account_document.dart';
import '../accounts/legacy_account_codec.dart';
import '../accounts/portable_journal_codec.dart';
import '../accounts/portable_journal_state.dart';
import 'daily_cash_queries.dart';
import 'journal_command_host.dart';
import 'restaurant_journal_mapper.dart';
import 'restaurant_journal_transfer_history.dart';

/// Error codes emitted by the restaurant transfer command layer.
abstract final class RestaurantJournalTransferErrorCodes {
  static const accountLineageMismatch = 'account_lineage_mismatch';
  static const cutoverGated = 'cutover_gated';
  static const preCutoverOperationRejected = 'pre_cutover_operation_rejected';
  static const missingRemainingSnapshot = 'missing_remaining_snapshot';
  static const excessiveTransferAmount = 'excessive_transfer_amount';
  static const zeroOrNegativeAmount = 'zero_or_negative_amount';
  static const duplicateTransferId = 'duplicate_transfer_id';
  static const duplicateJournalId = 'duplicate_journal_id';
  static const transferMappingFailed = 'transfer_mapping_failed';
  static const invalidTransferProposal = 'invalid_transfer_proposal';
  static const staleAuthorityFence = 'stale_authority_fence';
  static const zeroValueRequiresAllowZeroPolicy =
      'zero_value_requires_allow_zero_policy';
}

/// Frozen, validated outcome of a committed or replayed transfer command.
final class RestaurantJournalTransferOutcome {
  RestaurantJournalTransferOutcome({
    required this.commandType,
    required this.operationId,
    required this.transferId,
    required this.journalId,
    required this.effectiveDate,
    required this.netAmount,
    Map<String, Object?> metadata = const {},
  }) : metadata = _freezeMap(metadata) {
    _metadataIdentity = _canonicalIdentity(this.metadata);
  }

  final String commandType;
  final String operationId;
  final String transferId;
  final String journalId;
  final String effectiveDate;
  final String netAmount;
  final Map<String, Object?> metadata;
  late final String _metadataIdentity;

  Map<String, Object?> toJson() => {
    'commandType': commandType,
    'operationId': operationId,
    'transferId': transferId,
    'journalId': journalId,
    'effectiveDate': effectiveDate,
    'netAmount': netAmount,
    if (metadata.isNotEmpty) 'metadata': metadata,
  };

  String toOutcomePayload() => jsonEncode(toJson());

  factory RestaurantJournalTransferOutcome.fromJson(Map<String, Object?> json) {
    const allowed = {
      'commandType',
      'operationId',
      'transferId',
      'journalId',
      'effectiveDate',
      'netAmount',
      'metadata',
    };
    if (!json.keys.every(allowed.contains)) {
      throw const FormatException('invalid_transfer_outcome');
    }
    String text(String key) {
      final value = json[key];
      if (value is! String || value.isEmpty || value.trim() != value) {
        throw const FormatException('invalid_transfer_outcome');
      }
      return value;
    }

    final type = text('commandType'),
        date = text('effectiveDate'),
        amount = text('netAmount');
    if (type != 'daily_to_cashbox_transfer' ||
        !RegExp(r'^(0|[1-9][0-9]*)$').hasMatch(amount)) {
      throw const FormatException('invalid_transfer_outcome');
    }
    DateOnly.parse(date, minimumYear: 1000, maximumYear: 9999);
    final metadata = json['metadata'];
    if (metadata != null && metadata is! Map<String, Object?>) {
      throw const FormatException('invalid_transfer_outcome');
    }
    return RestaurantJournalTransferOutcome(
      commandType: type,
      operationId: text('operationId'),
      transferId: text('transferId'),
      journalId: text('journalId'),
      effectiveDate: date,
      netAmount: amount,
      metadata: metadata as Map<String, Object?>? ?? const {},
    );
  }

  factory RestaurantJournalTransferOutcome.fromOutcomePayload(String payload) {
    final decoded = jsonDecode(payload) as Map<String, Object?>;
    return RestaurantJournalTransferOutcome.fromJson(decoded);
  }

  @override
  bool operator ==(Object other) =>
      other is RestaurantJournalTransferOutcome &&
      other.commandType == commandType &&
      other.operationId == operationId &&
      other.transferId == transferId &&
      other.journalId == journalId &&
      other.effectiveDate == effectiveDate &&
      other.netAmount == netAmount &&
      other._metadataIdentity == _metadataIdentity;

  @override
  int get hashCode => Object.hash(
    commandType,
    operationId,
    transferId,
    journalId,
    effectiveDate,
    netAmount,
    _metadataIdentity,
  );

  @override
  String toString() =>
      'RestaurantJournalTransferOutcome(type: $commandType, details: redacted)';
}

Map<String, Object?> _freezeMap(Map<String, Object?> map) => freezeMap(map);

String _canonicalIdentity(Map<String, Object?> values) =>
    canonicalIdentity(values);

/// Durable command to execute an atomic daily-to-cashbox cash transfer.
final class DailyToCashboxTransferCommand {
  DailyToCashboxTransferCommand({
    required this.operationId,
    this.payloadVersion = 1,
    required this.accountLineage,
    this.expectedFence,
    required this.transferId,
    required this.journalId,
    required this.date,
    required this.amount,
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
    if (journalId.isEmpty || journalId.trim() != journalId) {
      throw const FormatException('Invalid journalId');
    }
    if (recordedAt.isEmpty || recordedAt.trim() != recordedAt) {
      throw const FormatException('Invalid recordedAt');
    }
    if (amount <= BigInt.zero) {
      throw const FormatException('Transfer amount must be positive');
    }
    if (amount.abs() > RestaurantJournalPolicies.defaultLimit) {
      throw const FormatException('Transfer amount exceeds allowed limit');
    }
    canonicalPayloadIdentity = _computeCanonicalPayload(
      operationId: operationId,
      payloadVersion: payloadVersion,
      accountLineage: accountLineage,
      expectedFence: expectedFence,
      transferId: transferId,
      journalId: journalId,
      date: date,
      amount: amount,
      recordedAt: recordedAt,
      policy: policy,
    );
  }

  final String operationId;
  final int payloadVersion;
  final String accountLineage;
  final StorageFence? expectedFence;
  final String transferId;
  final String journalId;
  final DateOnly date;
  final BigInt amount;
  final String recordedAt;
  final JournalPolicy? policy;

  late final String canonicalPayloadIdentity;

  String get commandType => 'daily_to_cashbox_transfer';

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
    required String journalId,
    required DateOnly date,
    required BigInt amount,
    required String recordedAt,
    JournalPolicy? policy,
  }) {
    final map = <String, Object?>{
      'accountLineage': accountLineage,
      'amount': amount.toString(),
      'commandType': 'daily_to_cashbox_transfer',
      'date': date.toString(),
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
      'recordedAt': recordedAt,
      'transferId': transferId,
    };
    return _canonicalIdentity(map);
  }
}

/// Coordinates atomic execution, idempotency, lineage enforcement, and
/// cutover gating for restaurant transfer commands against a single store owner.
final class RestaurantJournalTransferCommandCoordinator {
  RestaurantJournalTransferCommandCoordinator({
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

  /// Executes a [DailyToCashboxTransferCommand].
  Future<DurableCommandResult<RestaurantJournalTransferOutcome>> execute(
    DailyToCashboxTransferCommand command,
  ) {
    return host.execute<RestaurantJournalTransferOutcome>(
      identity: command.identity,
      accountLineage: command.accountLineage,
      expectedFence: command.expectedFence,
      missingAuthorityFenceMessage:
          'Capture account authority before submitting a transfer command.',
      accountLineageMismatchCode:
          RestaurantJournalTransferErrorCodes.accountLineageMismatch,
      cutoverGatedCode: RestaurantJournalTransferErrorCodes.cutoverGated,
      validateReplayOutcome: (payload, state) {
        try {
          final outcome = RestaurantJournalTransferOutcome.fromOutcomePayload(
            payload,
          );
          return _replayMatchesSource(command, outcome, state, mapper);
        } catch (_) {
          return false;
        }
      },
      parseOutcome: RestaurantJournalTransferOutcome.fromOutcomePayload,
      evaluateProposal: (state, fence) => evaluateTransfer(
        command: command,
        state: state,
        cutoverDate: state.cutoverState.cutoverDate!,
        mapper: mapper,
      ),
    );
  }

  /// Convenience alias for executing daily-to-cashbox transfers.
  Future<DurableCommandResult<RestaurantJournalTransferOutcome>>
  executeTransfer(DailyToCashboxTransferCommand command) => execute(command);

  /// Pure proposal evaluation for a daily-to-cashbox cash transfer.
  static DurableProposalEvaluation<
    PortableJournalState,
    RestaurantJournalTransferOutcome
  >
  evaluateTransfer({
    required DailyToCashboxTransferCommand command,
    required PortableJournalState state,
    required DateOnly cutoverDate,
    required RestaurantJournalMapper mapper,
  }) {
    // 1. Cutover date gate
    if (command.date.compareTo(cutoverDate) < 0) {
      return const DurableProposalEvaluation.reject(
        rejectionCode:
            RestaurantJournalTransferErrorCodes.preCutoverOperationRejected,
        rejectionMessage: 'Transfer date precedes established cutover date.',
      );
    }

    // 2. Positive amount check
    if (command.amount <= BigInt.zero) {
      return const DurableProposalEvaluation.reject(
        rejectionCode: RestaurantJournalTransferErrorCodes.zeroOrNegativeAmount,
        rejectionMessage: 'Transfer amount must be positive.',
      );
    }
    if (command.amount.abs() > RestaurantJournalPolicies.defaultLimit) {
      return const DurableProposalEvaluation.reject(
        rejectionCode:
            RestaurantJournalTransferErrorCodes.invalidTransferProposal,
        rejectionMessage: 'Transfer amount exceeds allowed limit.',
      );
    }

    final accountJson = state.account.toJson();
    final rawTransfers = (accountJson['transfers'] as List? ?? const [])
        .cast<Map<String, Object?>>();

    // 3. Duplicate transferId check
    if (rawTransfers.any((t) => t['id'] == command.transferId)) {
      return const DurableProposalEvaluation.reject(
        rejectionCode: RestaurantJournalTransferErrorCodes.duplicateTransferId,
        rejectionMessage: 'Transfer ID already exists in source records.',
      );
    }

    // 4. Duplicate journalId check
    if (state.journals.any((j) => j.journal.id == command.journalId)) {
      return const DurableProposalEvaluation.reject(
        rejectionCode: RestaurantJournalTransferErrorCodes.duplicateJournalId,
        rejectionMessage: 'Journal ID already exists in journal entries.',
      );
    }

    final dateKey = command.date.toString();
    final rawDays = (accountJson['days'] as Map<String, Object?>?) ?? const {};
    final dayData = rawDays[dateKey] as Map<String, Object?>?;

    // 5. Remaining snapshot requirement
    if (dayData == null || dayData['remaining'] == null) {
      return const DurableProposalEvaluation.reject(
        rejectionCode:
            RestaurantJournalTransferErrorCodes.missingRemainingSnapshot,
        rejectionMessage: 'Daily cash register has no recorded remaining snapshot for this date.',
      );
    }

    // 6. Available remaining calculation
    final dailyQueries = DailyCashQueries(state.account);
    final dailySnapshot = dailyQueries.day(dateKey);
    final available = dailySnapshot.remaining;

    if (available == null) {
      return const DurableProposalEvaluation.reject(
        rejectionCode:
            RestaurantJournalTransferErrorCodes.missingRemainingSnapshot,
        rejectionMessage:
            'Daily cash register remaining snapshot is not recorded.',
      );
    }

    if (command.amount > available) {
      return const DurableProposalEvaluation.reject(
        rejectionCode:
            RestaurantJournalTransferErrorCodes.excessiveTransferAmount,
        rejectionMessage:
            'Transfer amount exceeds available daily remaining cash.',
      );
    }

    // 7. Recover unset total on older/manual records (model.js transferRemaining parity)
    final dayMap = Map<String, Object?>.from(dayData);
    if (dayMap['balance'] == null) {
      final totalSpent = dailySnapshot.total;
      final sum = totalSpent + available + dailySnapshot.transferred;
      if (sum.abs() > RestaurantJournalPolicies.defaultLimit ||
          sum.abs() > RestaurantJournalPolicies.maximumSafeAggregate) {
        return const DurableProposalEvaluation.reject(
          rejectionCode:
              RestaurantJournalTransferErrorCodes.invalidTransferProposal,
          rejectionMessage: 'Recovered total balance exceeds safe bounds.',
        );
      }
      dayMap['balance'] = sum.toInt();
    }

    // 8. Update source records
    final newTransfer = <String, Object?>{
      'id': command.transferId,
      'date': dateKey,
      'amount': command.amount.toInt(),
      'createdAt': command.recordedAt,
    };

    final updatedTransfers = [...rawTransfers, newTransfer];
    final updatedDays = Map<String, Object?>.from(rawDays)..[dateKey] = dayMap;

    AccountDocument candidateAccount;
    try {
      candidateAccount = const LegacyAccountCodec().decodeJson({
        ...accountJson,
        'days': updatedDays,
        'transfers': updatedTransfers,
      });
    } catch (e) {
      return DurableProposalEvaluation.reject(
        rejectionCode:
            RestaurantJournalTransferErrorCodes.invalidTransferProposal,
        rejectionMessage: e.toString(),
      );
    }

    // 9. Map journal proposal
    RestaurantJournalProposal journalProposal;
    try {
      journalProposal = mapper.mapDailyToCashboxTransfer(
        journalId: command.journalId,
        transferId: command.transferId,
        effectiveDate: command.date,
        amount: command.amount,
        policy: command.policy,
      );
    } catch (e) {
      return DurableProposalEvaluation.reject(
        rejectionCode:
            RestaurantJournalTransferErrorCodes.transferMappingFailed,
        rejectionMessage: e.toString(),
      );
    }

    final metadata = _transferMetadata(command, journalProposal);

    final entry = PortableJournalEntry(
      journal: journalProposal.journal,
      sourceType: journalProposal.sourceType.name,
      sourceRecordId: command.transferId,
      recordedAt: command.recordedAt,
      metadata: metadata,
    );

    final candidateState = state.copyWith(
      account: candidateAccount,
      journals: [...state.journals, entry],
    );

    final outcome = RestaurantJournalTransferOutcome(
      commandType: command.commandType,
      operationId: command.operationId,
      transferId: command.transferId,
      journalId: command.journalId,
      effectiveDate: dateKey,
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

Map<String, Object?> _transferMetadata(
  DailyToCashboxTransferCommand command,
  RestaurantJournalProposal proposal,
) => {
  'operationId': command.operationId,
  'transferId': command.transferId,
  'date': command.date.toString(),
  'amount': command.amount.toString(),
  'sourceVersion': proposal.sourceVersion.toString(),
};

bool _replayMatchesSource(
  DailyToCashboxTransferCommand command,
  RestaurantJournalTransferOutcome outcome,
  PortableJournalState state,
  RestaurantJournalMapper mapper,
) {
  try {
    if (outcome.operationId != command.operationId ||
        outcome.commandType != command.commandType ||
        outcome.transferId != command.transferId ||
        outcome.journalId != command.journalId ||
        outcome.effectiveDate != command.date.toString() ||
        outcome.netAmount != command.amount.toString()) {
      return false;
    }

    // Check journals
    final journals = state.journals
        .where((j) => j.journal.id == command.journalId)
        .toList();
    if (journals.length != 1) return false;
    final entry = journals.single;

    final expected = mapper.mapDailyToCashboxTransfer(
      journalId: command.journalId,
      transferId: command.transferId,
      effectiveDate: command.date,
      amount: command.amount,
      policy: command.policy,
    );
    final expectedMetadata = _transferMetadata(command, expected);
    final expectedEntry = PortableJournalEntry(
      journal: expected.journal,
      sourceType: expected.sourceType.name,
      sourceRecordId: command.transferId,
      recordedAt: command.recordedAt,
      metadata: expectedMetadata,
    );
    if (_canonicalIdentity(entry.toJson()) !=
        _canonicalIdentity(expectedEntry.toJson())) {
      return false;
    }

    // Outcome metadata matches entry metadata
    if (_canonicalIdentity(expectedMetadata) != outcome._metadataIdentity) {
      return false;
    }

    return RestaurantJournalTransferHistory.validateTransferLineage(
      state: state,
      transferId: command.transferId,
      mapper: mapper,
      initialJournalId: command.journalId,
      initialAmount: command.amount,
      initialDate: command.date,
      initialRecordedAt: command.recordedAt,
    );
  } catch (_) {
    return false;
  }
}
