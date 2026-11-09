part of 'daily_register_snapshot_controller.dart';

/// Captured session-only snapshot compensation. The complete envelope is never
/// restored: this command may change only one day's observed register fields.
final class RestoreDailyRegisterCommand extends DailyRegisterCommand {
  RestoreDailyRegisterCommand({
    required super.operationId,
    required super.date,
    required super.accountLineage,
    required super.expectedFence,
    required super.recordedAt,
    required this.expectedRevision,
    required this.originalIdentity,
    required Map<String, Object?> expectedAccount,
    required Map<String, Object?> beforeAccount,
    required Map<String, Object?> afterAccount,
    this.reason = 'تراجع عن التصحيح السابق',
  }) : expectedAccount = freezeMap(expectedAccount),
       beforeAccount = freezeMap(beforeAccount),
       afterAccount = freezeMap(afterAccount) {
    // Refuse an oversized captured intent before the owner marks any write
    // pending; this failure cannot have reached storage.
    canonicalIdentity(toCanonicalMap());
  }
  final int expectedRevision;
  final DurableCommandIdentity originalIdentity;
  final Map<String, Object?> expectedAccount, beforeAccount, afterAccount;
  final String reason;
  @override
  Map<String, Object?> toCanonicalMap() => {
    'type': 'restore_daily_register',
    'operationId': operationId,
    'date': date,
    'accountLineage': accountLineage,
    'fenceStoreId': expectedFence.storeId,
    'fenceGeneration': expectedFence.generation,
    'recordedAt': recordedAt,
    'expectedRevision': expectedRevision,
    'reason': reason,
    'originalIdentity': {
      'operationId': originalIdentity.operationId,
      'payloadVersion': originalIdentity.payloadVersion,
      'canonicalPayloadIdentity': originalIdentity.canonicalPayloadIdentity,
    },
    'expectedAccount': expectedAccount,
    'beforeAccount': beforeAccount,
    'afterAccount': afterAccount,
  };
}

Map<String, Object?> dailyRegisterComparableSource(AccountDocument account) {
  final result = Map<String, Object?>.from(account.toJson());
  result['days'] = {
    for (final e in account.days.entries)
      e.key: Map<String, Object?>.from(e.value! as Map)..remove('corrections'),
  };
  final days = result['days']! as Map<String, Object?>;
  days.removeWhere((_, value) {
    final d = value! as Map;
    return (d['expenses']! as List).isEmpty &&
        d['chickenUsed'] == 0 &&
        d['chickenLeft'] == 0 &&
        d['balance'] == null &&
        d['totalOverride'] == null &&
        d['remaining'] == null;
  });
  return result;
}

Map<String, Object?> _registerScope(AccountDocument account, String date) {
  final raw = account.toJson(), days = Map<String, Object?>.from(account.days);
  final day = Map<String, Object?>.from(days[date] as Map? ?? const {});
  for (final key in ['balance', 'totalOverride', 'remaining', 'corrections']) {
    day.remove(key);
  }
  if (day.isEmpty ||
      ((day['expenses'] as List?)?.isEmpty != false &&
          (day['chickenUsed'] ?? 0) == 0 &&
          (day['chickenLeft'] ?? 0) == 0)) {
    days.remove(date);
  } else {
    days[date] = day;
  }
  return {...raw, 'days': days};
}

DurableProposalEvaluation<PortableJournalState, DailyRegisterSnapshotOutcome>
evaluateDailyRegisterRestore({
  required RestoreDailyRegisterCommand command,
  required PortableJournalState state,
  required StorageFence fence,
}) {
  DurableProposalEvaluation<PortableJournalState, DailyRegisterSnapshotOutcome>
  reject(String code) => DurableProposalEvaluation.reject(
    rejectionCode: code,
    rejectionMessage: 'Register undo was not applied.',
  );
  try {
    if (command.accountLineage != state.accountLineage ||
        command.expectedFence != fence) {
      return reject('stale_authority_fence');
    }
    if (command.reason.trim().isEmpty ||
        command.reason.length > 500 ||
        command.expectedRevision < 0) {
      return reject('invalid_undo_intent');
    }
    if (canonicalIdentity(command.expectedAccount) !=
        canonicalIdentity(state.account.toJson())) {
      return reject('undo_source_changed');
    }
    final old = const LegacyAccountCodec().decodeJson(command.beforeAccount),
        acknowledged = const LegacyAccountCodec().decodeJson(
          command.afterAccount,
        );
    if (canonicalIdentity(_registerScope(old, command.date)) !=
        canonicalIdentity(_registerScope(acknowledged, command.date))) {
      return reject('undo_source_changed');
    }
    final receipt = state.receipts.singleWhere(
      (r) =>
          r.identity == command.originalIdentity &&
          r.status == DurableCommandStatus.committed,
    );
    final intent = (jsonDecode(
      receipt.identity.canonicalPayloadIdentity,
    ) as Map).cast<String, Object?>();
    if (intent['date'] != command.date ||
        intent['accountLineage'] != command.accountLineage) {
      return reject('undo_original_mismatch');
    }
    final originalFence = StorageFence(
      storeId: intent['fenceStoreId']! as String,
      generation: intent['fenceGeneration']! as String,
    );
    if (originalFence != receipt.fence) return reject('undo_original_mismatch');
    final touched = switch (intent['type']) {
      'record_balance' => ['balance'],
      'record_total' => ['totalOverride'],
      'record_remaining' => ['remaining', 'balance'],
      _ => throw const FormatException('undo_original_mismatch'),
    };
    final currentDay = state.account.days[command.date] as Map? ?? const {},
        expectedDay = acknowledged.days[command.date] as Map? ?? const {};
    for (final key in touched) {
      if (canonicalIdentity({'value': currentDay[key]}) !=
          canonicalIdentity({'value': expectedDay[key]})) {
        return reject('undo_source_changed');
      }
    }
    final original = switch (intent['type']) {
      'record_remaining' => RecordRemainingCommand(
        operationId: intent['operationId']! as String,
        date: command.date,
        accountLineage: command.accountLineage,
        expectedFence: originalFence,
        recordedAt: intent['recordedAt']! as String,
        amount: BigInt.parse(intent['amount']! as String),
      ),
      'record_balance' => RecordBalanceCommand(
        operationId: intent['operationId']! as String,
        date: command.date,
        accountLineage: command.accountLineage,
        expectedFence: originalFence,
        recordedAt: intent['recordedAt']! as String,
        amount: intent['amount'] == null
            ? null
            : BigInt.parse(intent['amount']! as String),
        reason: intent['reason']! as String,
      ),
      'record_total' => RecordTotalCommand(
        operationId: intent['operationId']! as String,
        date: command.date,
        accountLineage: command.accountLineage,
        expectedFence: originalFence,
        recordedAt: intent['recordedAt']! as String,
        amount: intent['amount'] == null
            ? null
            : BigInt.parse(intent['amount']! as String),
        reason: intent['reason']! as String,
      ),
      _ => throw const FormatException('undo_original_mismatch'),
    };
    if (canonicalIdentity(original.toCanonicalMap()) !=
        receipt.identity.canonicalPayloadIdentity) {
      return reject('undo_original_mismatch');
    }
    final proof = DailyRegisterSnapshotController.evaluateProposal(
      command: original,
      state: state.copyWith(account: old),
      fence: originalFence,
    );
    if (proof.rejected ||
        proof.candidateState == null ||
        canonicalIdentity(proof.candidateState!.account.toJson()) !=
            canonicalIdentity(acknowledged.toJson()) ||
        canonicalIdentity(proof.outcome!.toJson()) !=
            canonicalIdentity(
              (jsonDecode(receipt.outcomePayload!) as Map)
                  .cast<String, Object?>(),
            )) {
      return reject('undo_original_mismatch');
    }
    final raw = state.account.toJson(),
        days = Map<String, Object?>.from(state.account.days);
    final oldDay = old.days[command.date] as Map<String, Object?>?;
    final current = Map<String, Object?>.from(
      days[command.date] as Map? ??
          const {
            'expenses': <Object?>[],
            'chickenUsed': 0,
            'chickenLeft': 0,
            'balance': null,
            'totalOverride': null,
            'remaining': null,
          },
    );
    final target = Map<String, Object?>.from(current);
    for (final key in touched) {
      target[key] = oldDay?[key];
    }
    final history = (current['corrections'] as List? ?? const [])
        .cast<Map<String, Object?>>();
    final prior = (oldDay?['corrections'] as List? ?? const [])
        .cast<Map<String, Object?>>();
    target.remove('corrections');
    if (prior.isNotEmpty) target['corrections'] = prior;
    if (history.isNotEmpty) {
      final retained = <Map<String, Object?>>[...history];
      if (canonicalIdentity({'history': prior}) !=
          canonicalIdentity({'history': history})) {
        for (final entry in [
          ('balance', 'balance'),
          ('total', 'totalOverride'),
        ]) {
          if (current[entry.$2] != target[entry.$2]) {
            retained.add({
              'field': entry.$1,
              'date': command.date,
              'before': current[entry.$2],
              'after': target[entry.$2],
              'reason': command.reason.trim(),
              'createdAt': command.recordedAt,
            });
          }
        }
      }
      target['corrections'] = retained;
    }
    if (oldDay == null &&
        history.isEmpty &&
        (target['expenses']! as List).isEmpty &&
        target['chickenUsed'] == 0 &&
        target['chickenLeft'] == 0 &&
        target['balance'] == null &&
        target['totalOverride'] == null &&
        target['remaining'] == null) {
      days.remove(command.date);
    } else {
      days[command.date] = target;
    }
    final account = const LegacyAccountCodec().decodeJson({
      ...raw,
      'days': days,
    });
    final outcome = DailyRegisterSnapshotOutcome(
      kind: 'restore',
      date: command.date,
      recordedBalance: target['balance'] == null
          ? null
          : BigInt.from(target['balance']! as int),
      totalOverride: target['totalOverride'] == null
          ? null
          : BigInt.from(target['totalOverride']! as int),
      remainingAmount: target['remaining'] == null
          ? null
          : BigInt.from((target['remaining']! as Map)['amount']! as int),
      reason: command.reason.trim(),
      recordedAt: command.recordedAt,
    );
    return DurableProposalEvaluation.accept(
      candidateState: state.copyWith(account: account),
      outcome: outcome,
      outcomePayload: jsonEncode(outcome.toJson()),
    );
  } on Object {
    return reject('invalid_register_undo');
  }
}
