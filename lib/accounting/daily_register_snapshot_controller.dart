import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:madar_application/madar_application.dart';
import 'package:madar_domain/madar_domain.dart';

import '../accounts/account_document.dart';
import '../accounts/legacy_account_codec.dart';
import '../accounts/portable_journal_codec.dart';
import '../accounts/portable_journal_state.dart';
import 'daily_cash_queries.dart';
import 'journal_command_host.dart'
    show LineageScopedJournalCodec, canonicalIdentity, freezeMap;

part 'daily_register_undo_commands.dart';

/// Result outcome for daily register snapshot commands.
final class DailyRegisterSnapshotOutcome {
  const DailyRegisterSnapshotOutcome({
    required this.kind,
    required this.date,
    this.remainingAmount,
    this.recordedBalance,
    this.totalOverride,
    this.reason,
    required this.recordedAt,
  });

  final String kind;
  final String date;
  final BigInt? remainingAmount;
  final BigInt? recordedBalance;
  final BigInt? totalOverride;
  final String? reason;
  final String recordedAt;

  Map<String, Object?> toJson() => {
    'kind': kind,
    'date': date,
    if (remainingAmount != null) 'remainingAmount': remainingAmount.toString(),
    if (recordedBalance != null) 'recordedBalance': recordedBalance.toString(),
    if (totalOverride != null) 'totalOverride': totalOverride.toString(),
    if (reason != null) 'reason': reason,
    'recordedAt': recordedAt,
  };

  static DailyRegisterSnapshotOutcome fromJson(Map<String, Object?> json) =>
      DailyRegisterSnapshotOutcome(
        kind: json['kind']! as String,
        date: json['date']! as String,
        remainingAmount: json['remainingAmount'] != null
            ? BigInt.parse(json['remainingAmount']! as String)
            : null,
        recordedBalance: json['recordedBalance'] != null
            ? BigInt.parse(json['recordedBalance']! as String)
            : null,
        totalOverride: json['totalOverride'] != null
            ? BigInt.parse(json['totalOverride']! as String)
            : null,
        reason: json['reason'] as String?,
        recordedAt: json['recordedAt']! as String,
      );
}

/// Abstract command for daily register operations.
sealed class DailyRegisterCommand {
  const DailyRegisterCommand({
    required this.operationId,
    required this.date,
    required this.accountLineage,
    required this.expectedFence,
    required this.recordedAt,
  });

  final String operationId;
  final String date;
  final String accountLineage;
  final StorageFence expectedFence;
  final String recordedAt;

  Map<String, Object?> toCanonicalMap();
}

/// Command to record end-of-day remaining cash snapshot and compute total balance.
final class RecordRemainingCommand extends DailyRegisterCommand {
  const RecordRemainingCommand({
    required super.operationId,
    required super.date,
    required super.accountLineage,
    required super.expectedFence,
    required super.recordedAt,
    required this.amount,
  });

  final BigInt amount;

  @override
  Map<String, Object?> toCanonicalMap() => {
    'type': 'record_remaining',
    'operationId': operationId,
    'accountLineage': accountLineage,
    'fenceStoreId': expectedFence.storeId,
    'fenceGeneration': expectedFence.generation,
    'date': date,
    'amount': amount.toString(),
    'recordedAt': recordedAt,
  };
}

/// Command to manually record or clear the registered balance for a day.
final class RecordBalanceCommand extends DailyRegisterCommand {
  const RecordBalanceCommand({
    required super.operationId,
    required super.date,
    required super.accountLineage,
    required super.expectedFence,
    required super.recordedAt,
    required this.amount,
    required this.reason,
  });

  final BigInt? amount;
  final String reason;

  @override
  Map<String, Object?> toCanonicalMap() => {
    'type': 'record_balance',
    'operationId': operationId,
    'accountLineage': accountLineage,
    'fenceStoreId': expectedFence.storeId,
    'fenceGeneration': expectedFence.generation,
    'date': date,
    if (amount != null) 'amount': amount.toString(),
    'reason': reason.trim(),
    'recordedAt': recordedAt,
  };
}

/// Command to override or restore automatic calculation of the daily total.
final class RecordTotalCommand extends DailyRegisterCommand {
  const RecordTotalCommand({
    required super.operationId,
    required super.date,
    required super.accountLineage,
    required super.expectedFence,
    required super.recordedAt,
    required this.amount,
    required this.reason,
  });

  final BigInt? amount;
  final String reason;

  @override
  Map<String, Object?> toCanonicalMap() => {
    'type': 'record_total',
    'operationId': operationId,
    'accountLineage': accountLineage,
    'fenceStoreId': expectedFence.storeId,
    'fenceGeneration': expectedFence.generation,
    'date': date,
    if (amount != null) 'amount': amount.toString(),
    'reason': reason.trim(),
    'recordedAt': recordedAt,
  };
}

/// Operational controller for daily register snapshots: recorded remaining,
/// recorded balance, manual/automatic total snapshots, and retained correction history.
///
/// These operations are register/display snapshots, NOT profit, new cash flows
/// or authority to fabricate opening/journal postings.
final class DailyRegisterSnapshotController extends ChangeNotifier {
  DailyRegisterSnapshotController({
    required this.store,
    required DocumentSnapshot snapshot,
    this.codec = const PortableJournalCodec(),
    this.isWriteBlocked,
    DurableCommandCoordinator? coordinator,
  }) : authorityFence = snapshot.fence,
       _snapshot = snapshot,
       _state = codec.decodeState(snapshot.payload),
       coordinator = coordinator ?? DurableCommandCoordinator(store: store) {
    _lineage = _state.accountLineage;
  }

  final LocalDocumentWorkspaceStore store;
  final PortableJournalCodec codec;
  final bool Function()? isWriteBlocked;
  final StorageFence authorityFence;
  final DurableCommandCoordinator coordinator;

  static final _moneyLimit = BigInt.from(1000000000000);
  static final _maxSafeInteger = BigInt.parse('9007199254740991');

  late final String _lineage;
  DocumentSnapshot _snapshot;
  late PortableJournalState _state;

  bool _busy = false;
  bool _disposed = false;
  int _notificationDepth = 0;
  String? _error;
  DailyRegisterCommand? _pending;

  bool get busy => _busy;
  bool get needsReadback => _pending != null;
  bool get pending => needsReadback;
  DailyRegisterCommand? get pendingCommand => _pending;
  String? get error => _error;
  String? get errorCode => _error;

  DocumentSnapshot get snapshot => _snapshot;
  AccountDocument get account => _state.account;
  String get accountLineage => _lineage;

  bool get externallyBlocked => isWriteBlocked?.call() ?? false;

  DailyCashSnapshot daySnapshot(String date) {
    DateOnly.parse(date, minimumYear: 1000, maximumYear: 9999);
    return DailyCashQueries(_state.account).day(date);
  }

  List<Map<String, Object?>> corrections(String date) {
    DateOnly.parse(date, minimumYear: 1000, maximumYear: 9999);
    final day =
        (_state.account.days[date] as Map<String, Object?>?) ?? const {};
    final list = day['corrections'] as List?;
    if (list == null) return const [];
    return List.unmodifiable(list.cast<Map<String, Object?>>());
  }

  void _notify() {
    if (_disposed) return;
    _notificationDepth++;
    try {
      notifyListeners();
    } finally {
      _notificationDepth--;
      if (_disposed && _notificationDepth == 0) super.dispose();
    }
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    if (_notificationDepth == 0) super.dispose();
  }

  CapabilityResult<void> acceptSnapshot(DocumentSnapshot snapshot) {
    if (_disposed) {
      return const CapabilityFailure('disposed', 'Controller disposed.');
    }
    if (_busy) {
      return const CapabilityFailure('busy', 'Controller busy.');
    }
    if (needsReadback) {
      return const CapabilityFailure('commit_unknown', 'Pending readback.');
    }
    try {
      _accept(snapshot);
      _error = null;
      _notify();
      return const CapabilitySuccess(null);
    } on PortableJournalException catch (error) {
      return CapabilityFailure(error.code, error.message);
    } on Object {
      return const CapabilityFailure('invalid_snapshot', 'Invalid snapshot.');
    }
  }

  void _accept(DocumentSnapshot next) {
    if (next.fence != authorityFence) {
      throw const FormatException('stale_generation');
    }
    if (next.revision < _snapshot.revision ||
        (next.revision == _snapshot.revision &&
            (next.payload != _snapshot.payload ||
                next.writeToken != _snapshot.writeToken))) {
      throw const FormatException('stale_snapshot');
    }
    final state = codec.decodeState(next.payload);
    if (state.accountLineage != _lineage) {
      throw const FormatException('account_lineage_mismatch');
    }
    _snapshot = next;
    _state = state;
  }

  static String _defaultOpId(String prefix, String date) =>
      '$prefix-$date-${DateTime.now().toUtc().microsecondsSinceEpoch}';

  static String _defaultTimestamp() => DateTime.now().toUtc().toIso8601String();

  Future<DurableCommandResult<DailyRegisterSnapshotOutcome>> recordRemaining({
    required String date,
    required BigInt amount,
    String? operationId,
    String? recordedAt,
  }) {
    final command = RecordRemainingCommand(
      operationId: operationId ?? _defaultOpId('op-remaining', date),
      date: date,
      accountLineage: _lineage,
      expectedFence: authorityFence,
      recordedAt: recordedAt ?? _defaultTimestamp(),
      amount: amount,
    );
    return _submit(command);
  }

  Future<DurableCommandResult<DailyRegisterSnapshotOutcome>> recordBalance({
    required String date,
    BigInt? amount,
    required String reason,
    String? operationId,
    String? recordedAt,
  }) {
    final command = RecordBalanceCommand(
      operationId: operationId ?? _defaultOpId('op-balance', date),
      date: date,
      accountLineage: _lineage,
      expectedFence: authorityFence,
      recordedAt: recordedAt ?? _defaultTimestamp(),
      amount: amount,
      reason: reason,
    );
    return _submit(command);
  }

  Future<DurableCommandResult<DailyRegisterSnapshotOutcome>> recordTotal({
    required String date,
    BigInt? amount,
    required String reason,
    String? operationId,
    String? recordedAt,
  }) {
    final command = RecordTotalCommand(
      operationId: operationId ?? _defaultOpId('op-total', date),
      date: date,
      accountLineage: _lineage,
      expectedFence: authorityFence,
      recordedAt: recordedAt ?? _defaultTimestamp(),
      amount: amount,
      reason: reason,
    );
    return _submit(command);
  }

  Future<DurableCommandResult<DailyRegisterSnapshotOutcome>> submitRestoration(
    RestoreDailyRegisterCommand command,
  ) => _submit(command);

  Future<DurableCommandResult<DailyRegisterSnapshotOutcome>> retry() {
    final pending = _pending;
    if (pending == null) {
      return Future.value(
        const DurableCommandFailure(
          code: 'nothing_to_retry',
          message: 'No pending command to retry.',
        ),
      );
    }
    return _submit(pending);
  }

  Future<DurableCommandResult<DailyRegisterSnapshotOutcome>> _submit(
    DailyRegisterCommand command,
  ) async {
    if (_disposed) {
      return const DurableCommandFailure(
        code: 'disposed',
        message: 'Controller disposed.',
      );
    }
    if (_busy || externallyBlocked) {
      return const DurableCommandFailure(
        code: 'busy',
        message: 'Store is busy with another operation.',
      );
    }
    if (_pending != null && !identical(_pending, command)) {
      return const DurableCommandFailure(
        code: DurableCommandErrorCodes.commitUnknown,
        message: 'A previous command outcome is uncertain.',
      );
    }
    if (command.accountLineage != _lineage ||
        command.expectedFence != authorityFence) {
      return const DurableCommandFailure(
        code: DurableCommandErrorCodes.staleAuthorityFence,
        message: 'Command authority fence or lineage mismatch.',
      );
    }

    _busy = true;
    _error = null;
    _notify();

    try {
      if (_disposed) {
        return const DurableCommandFailure(
          code: 'disposed',
          message: 'Controller disposed.',
        );
      }
      _pending = command;
      final identity = DurableCommandIdentity(
        operationId: command.operationId,
        payloadVersion: 1,
        canonicalPayloadIdentity: canonicalIdentity(command.toCanonicalMap()),
      );

      final scoped = LineageScopedJournalCodec(
        inner: codec,
        accountLineage: _lineage,
        targetIdentity: identity,
        expectedRevision: command is RestoreDailyRegisterCommand
            ? command.expectedRevision
            : null,
        validateReplayOutcome: (payload, state) {
          if (command is! RestoreDailyRegisterCommand) return true;
          try {
            final replay = evaluateDailyRegisterRestore(
              command: command,
              state: state.copyWith(
                account: const LegacyAccountCodec().decodeJson(
                  command.expectedAccount,
                ),
              ),
              fence: command.expectedFence,
            );
            return !replay.rejected &&
                canonicalIdentity(replay.outcome!.toJson()) ==
                    canonicalIdentity(
                      (jsonDecode(payload) as Map).cast<String, Object?>(),
                    );
          } on Object {
            return false;
          }
        },
      );

      final result = await coordinator
          .executeCommand<PortableJournalState, DailyRegisterSnapshotOutcome>(
            identity: identity,
            codec: scoped,
            expectedFence: authorityFence,
            replayedOutcomeMapper: (receipt) {
              final payload = receipt.outcomePayload;
              if (payload == null) {
                throw const FormatException('missing_outcome_payload');
              }
              return DailyRegisterSnapshotOutcome.fromJson(
                jsonDecode(payload) as Map<String, Object?>,
              );
            },
            proposal: (state, fence) {
              if (state == null) {
                return const DurableProposalEvaluation.reject(
                  rejectionCode: 'account_missing',
                  rejectionMessage: 'Account is missing.',
                );
              }
              return evaluateProposal(
                command: command,
                state: state,
                fence: fence ?? authorityFence,
              );
            },
          );

      if (_disposed) return result;

      switch (result) {
        case DurableCommandSuccess(:final snapshot):
          _accept(snapshot);
          _pending = null;
          _error = null;
        case DurableCommandReplayed(:final snapshot):
          _accept(snapshot);
          _pending = null;
          _error = null;
        case DurableCommandFailure(
          :final code,
          :final latestSnapshot,
          :final receipt,
        ):
          if (latestSnapshot != null &&
              receipt?.status == DurableCommandStatus.rejected) {
            _accept(latestSnapshot);
          }
          _error = code;
          if (code != DurableCommandErrorCodes.commitUnknown &&
              code != DocumentErrorCodes.pendingWrite) {
            _pending = null;
          }
      }
      return result;
    } on Object {
      _error = DurableCommandErrorCodes.commitUnknown;
      return const DurableCommandFailure(
        code: DurableCommandErrorCodes.commitUnknown,
        message: 'Commit outcome unknown.',
      );
    } finally {
      _busy = false;
      _notify();
    }
  }

  /// Evaluates proposal against the complete portable journal state.
  static DurableProposalEvaluation<
    PortableJournalState,
    DailyRegisterSnapshotOutcome
  >
  evaluateProposal({
    required DailyRegisterCommand command,
    required PortableJournalState state,
    required StorageFence fence,
  }) {
    if (state.accountLineage != command.accountLineage) {
      return const DurableProposalEvaluation.reject(
        rejectionCode: 'account_lineage_mismatch',
        rejectionMessage: 'Account lineage mismatch in proposal.',
      );
    }
    if (fence != command.expectedFence) {
      return const DurableProposalEvaluation.reject(
        rejectionCode: DurableCommandErrorCodes.staleAuthorityFence,
        rejectionMessage: 'Storage fence mismatch in proposal.',
      );
    }
    try {
      DateOnly.parse(command.date, minimumYear: 1000, maximumYear: 9999);
    } catch (_) {
      return const DurableProposalEvaluation.reject(
        rejectionCode: 'invalid_date',
        rejectionMessage: 'Date format is invalid.',
      );
    }

    final account = state.account;
    final days = Map<String, Object?>.from(account.days);
    final day = Map<String, Object?>.from(
      (days[command.date] as Map<String, Object?>?) ??
          const {
            'expenses': <Object?>[],
            'chickenUsed': 0,
            'chickenLeft': 0,
            'balance': null,
            'totalOverride': null,
            'remaining': null,
          },
    );

    if (command is RestoreDailyRegisterCommand) {
      return evaluateDailyRegisterRestore(
        command: command,
        state: state,
        fence: fence,
      );
    }
    switch (command) {
      case RestoreDailyRegisterCommand():
        return evaluateDailyRegisterRestore(
          command: command,
          state: state,
          fence: fence,
        );
      case RecordRemainingCommand(:final amount):
        if (amount < BigInt.zero || amount > _moneyLimit) {
          return const DurableProposalEvaluation.reject(
            rejectionCode: 'invalid_amount',
            rejectionMessage: 'Remaining amount out of bounds.',
          );
        }
        final snapshot = DailyCashQueries(account).day(command.date);
        final sum = snapshot.total + amount + snapshot.transferred;
        if (sum.abs() > _moneyLimit || sum > _maxSafeInteger) {
          return const DurableProposalEvaluation.reject(
            rejectionCode: 'balance_overflow',
            rejectionMessage: 'Total balance exceeds maximum allowed limit.',
          );
        }
        day['remaining'] = {
          'amount': amount.toInt(),
          'dailySpent': snapshot.dailySpent.toInt(),
          'transferred': snapshot.transferred.toInt(),
          'salesTotal': snapshot.netSales.toInt(),
        };
        day['balance'] = sum.toInt();
        days[command.date] = day;

        final updatedAccount = const LegacyAccountCodec().decodeJson({
          ...account.toJson(),
          'days': days,
        });
        final outcome = DailyRegisterSnapshotOutcome(
          kind: 'remaining',
          date: command.date,
          remainingAmount: amount,
          recordedBalance: sum,
          totalOverride: day['totalOverride'] == null
              ? null
              : BigInt.from(day['totalOverride'] as int),
          recordedAt: command.recordedAt,
        );
        return DurableProposalEvaluation.accept(
          candidateState: state.copyWith(account: updatedAccount),
          outcome: outcome,
          outcomePayload: jsonEncode(outcome.toJson()),
        );

      case RecordBalanceCommand(:final amount, :final reason):
        if (amount != null &&
            (amount.abs() > _moneyLimit || amount.abs() > _maxSafeInteger)) {
          return const DurableProposalEvaluation.reject(
            rejectionCode: 'invalid_amount',
            rejectionMessage: 'Balance amount out of bounds.',
          );
        }
        final trimmedReason = reason.trim();
        if (trimmedReason.isEmpty || trimmedReason.length > 500) {
          return const DurableProposalEvaluation.reject(
            rejectionCode: 'invalid_reason',
            rejectionMessage:
                'Reason must be non-empty and at most 500 characters.',
          );
        }
        final before = day['balance'] as int?;
        final after = amount?.toInt();
        final correction = {
          'field': 'balance',
          'date': command.date,
          'before': before,
          'after': after,
          'reason': trimmedReason,
          'createdAt': command.recordedAt,
        };
        day['balance'] = after;
        final existing = (day['corrections'] as List? ?? [])
            .cast<Map<String, Object?>>();
        day['corrections'] = [...existing, correction];
        days[command.date] = day;

        final updatedAccount = const LegacyAccountCodec().decodeJson({
          ...account.toJson(),
          'days': days,
        });
        final outcome = DailyRegisterSnapshotOutcome(
          kind: 'balance',
          date: command.date,
          recordedBalance: amount,
          reason: trimmedReason,
          recordedAt: command.recordedAt,
        );
        return DurableProposalEvaluation.accept(
          candidateState: state.copyWith(account: updatedAccount),
          outcome: outcome,
          outcomePayload: jsonEncode(outcome.toJson()),
        );

      case RecordTotalCommand(:final amount, :final reason):
        if (amount != null &&
            (amount < BigInt.zero ||
                amount > _moneyLimit ||
                amount > _maxSafeInteger)) {
          return const DurableProposalEvaluation.reject(
            rejectionCode: 'invalid_amount',
            rejectionMessage: 'Total override amount out of bounds.',
          );
        }
        final trimmedReason = reason.trim();
        if (trimmedReason.isEmpty || trimmedReason.length > 500) {
          return const DurableProposalEvaluation.reject(
            rejectionCode: 'invalid_reason',
            rejectionMessage:
                'Reason must be non-empty and at most 500 characters.',
          );
        }
        final before = day['totalOverride'] as int?;
        final after = amount?.toInt();
        final correction = {
          'field': 'total',
          'date': command.date,
          'before': before,
          'after': after,
          'reason': trimmedReason,
          'createdAt': command.recordedAt,
        };
        day['totalOverride'] = after;
        final existing = (day['corrections'] as List? ?? [])
            .cast<Map<String, Object?>>();
        day['corrections'] = [...existing, correction];
        days[command.date] = day;

        final updatedAccount = const LegacyAccountCodec().decodeJson({
          ...account.toJson(),
          'days': days,
        });
        final outcome = DailyRegisterSnapshotOutcome(
          kind: 'total',
          date: command.date,
          totalOverride: amount,
          reason: trimmedReason,
          recordedAt: command.recordedAt,
        );
        return DurableProposalEvaluation.accept(
          candidateState: state.copyWith(account: updatedAccount),
          outcome: outcome,
          outcomePayload: jsonEncode(outcome.toJson()),
        );
    }
  }
}
