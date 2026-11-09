import 'dart:convert';

import 'package:madar_application/madar_application.dart';
import 'package:madar_domain/madar_domain.dart';

import '../accounts/legacy_account_codec.dart';
import '../accounts/portable_journal_state.dart';
import 'correction_batch_receipts.dart';
import 'daily_cash_queries.dart';
import 'journal_command_host.dart';
import 'restaurant_journal_expense_history.dart';
import 'restaurant_journal_external_cash_commands.dart';
import 'restaurant_journal_mapper.dart';
import 'restaurant_journal_payment_correction_commands.dart'
    show paymentProfileIdentity, paymentPolicyIdentity;
import 'restaurant_journal_transfer_history.dart';

enum DeletedSpendingKind { expense, transfer, externalCash }

String _kind(DeletedSpendingKind kind) => switch (kind) {
  DeletedSpendingKind.expense => 'expense',
  DeletedSpendingKind.transfer => 'transfer',
  DeletedSpendingKind.externalCash => 'external_cash',
};
String _idKey(DeletedSpendingKind kind) => switch (kind) {
  DeletedSpendingKind.expense => 'expenseId',
  DeletedSpendingKind.transfer => 'transferId',
  DeletedSpendingKind.externalCash => 'transactionId',
};

/// A new posting/source version restoring an exact retained deleted record.
/// Neither the old posting nor its deletion inverse is removed or reversed.
final class RestoreDeletedSpendingCommand {
  RestoreDeletedSpendingCommand({
    required this.kind,
    required this.operationId,
    required this.accountLineage,
    required this.expectedFence,
    required this.recordId,
    required this.deletedJournalId,
    required this.deleteInverseJournalId,
    required this.deleteOperationId,
    required this.replacementJournalId,
    required Map<String, Object?> sourceSnapshot,
    required this.position,
    required Iterable<String> expectedSiblingIds,
    required this.reason,
    required this.recordedAt,
    required RestaurantJournalMapper mapper,
    this.acceptedCounterAccountId,
  }) : sourceSnapshot = freezeMap(sourceSnapshot),
       expectedSiblingIds = List.unmodifiable(expectedSiblingIds),
       context = freezeMap({
         'profile': paymentProfileIdentity(mapper.profile),
         'policy': paymentPolicyIdentity(mapper.defaultPolicy),
       }) {
    for (final id in [
      operationId,
      accountLineage,
      recordId,
      deletedJournalId,
      deleteInverseJournalId,
      deleteOperationId,
      replacementJournalId,
      recordedAt,
    ]) {
      if (id.isEmpty || id.trim() != id) {
        throw const FormatException('invalid_restoration_identity');
      }
    }
    if (reason.trim().isEmpty ||
        position < 0 ||
        position > this.expectedSiblingIds.length ||
        this.expectedSiblingIds.contains(recordId) ||
        this.expectedSiblingIds.toSet().length !=
            this.expectedSiblingIds.length ||
        {
              deletedJournalId,
              deleteInverseJournalId,
              replacementJournalId,
            }.length !=
            3) {
      throw const FormatException('invalid_restoration_intent');
    }
    canonicalPayloadIdentity = canonicalIdentity(toJson());
  }
  final DeletedSpendingKind kind;
  final String operationId,
      accountLineage,
      recordId,
      deletedJournalId,
      deleteInverseJournalId,
      deleteOperationId,
      replacementJournalId,
      reason,
      recordedAt;
  final String? acceptedCounterAccountId;
  final StorageFence? expectedFence;
  final int position;
  final List<String> expectedSiblingIds;
  final Map<String, Object?> sourceSnapshot, context;
  late final String canonicalPayloadIdentity;
  String get commandType => 'restore_deleted_${_kind(kind)}';
  DurableCommandIdentity get identity => DurableCommandIdentity(
    operationId: operationId,
    payloadVersion: 1,
    canonicalPayloadIdentity: canonicalPayloadIdentity,
  );
  Map<String, Object?> toJson() => {
    'commandType': commandType,
    'payloadVersion': 1,
    'operationId': operationId,
    'accountLineage': accountLineage,
    'expectedFence': expectedFence == null
        ? null
        : {
            'storeId': expectedFence!.storeId,
            'generation': expectedFence!.generation,
          },
    _idKey(kind): recordId,
    'deletedJournalId': deletedJournalId,
    'deleteInverseJournalId': deleteInverseJournalId,
    'deleteOperationId': deleteOperationId,
    'replacementJournalId': replacementJournalId,
    'sourceSnapshot': sourceSnapshot,
    'sourceVersion': 11,
    'position': position,
    'expectedSiblingIds': expectedSiblingIds,
    'reason': reason,
    'recordedAt': recordedAt,
    'acceptedCounterAccountId': acceptedCounterAccountId,
    'context': context,
  };
  static RestoreDeletedSpendingCommand fromIntent(
    Map<String, Object?> i,
    RestaurantJournalMapper mapper,
  ) {
    final kind = DeletedSpendingKind.values.singleWhere(
      (k) => 'restore_deleted_${_kind(k)}' == i['commandType'],
    );
    if (i['payloadVersion'] != 1 ||
        i['sourceVersion'] != 11 ||
        !_same(_map(i['context']), {
          'profile': paymentProfileIdentity(mapper.profile),
          'policy': paymentPolicyIdentity(mapper.defaultPolicy),
        })) {
      throw const FormatException('restoration_context_mismatch');
    }
    final f = i['expectedFence'] == null ? null : _map(i['expectedFence']);
    return RestoreDeletedSpendingCommand(
      kind: kind,
      operationId: i['operationId']! as String,
      accountLineage: i['accountLineage']! as String,
      expectedFence: f == null
          ? null
          : StorageFence(
              storeId: f['storeId']! as String,
              generation: f['generation']! as String,
            ),
      recordId: i[_idKey(kind)]! as String,
      deletedJournalId: i['deletedJournalId']! as String,
      deleteInverseJournalId: i['deleteInverseJournalId']! as String,
      deleteOperationId: i['deleteOperationId']! as String,
      replacementJournalId: i['replacementJournalId']! as String,
      sourceSnapshot: _map(i['sourceSnapshot']),
      position: i['position']! as int,
      expectedSiblingIds: (i['expectedSiblingIds']! as List).cast<String>(),
      reason: i['reason']! as String,
      recordedAt: i['recordedAt']! as String,
      mapper: mapper,
      acceptedCounterAccountId: i['acceptedCounterAccountId'] as String?,
    );
  }

  @override
  String toString() => 'RestoreDeletedSpendingCommand(details: redacted)';
}

final class SpendingRestorationOutcome {
  SpendingRestorationOutcome(Map<String, Object?> values)
    : values = freezeMap(values);
  final Map<String, Object?> values;
  Map<String, Object?> toJson() => values;
  String toOutcomePayload() => canonicalIdentity(values);
  factory SpendingRestorationOutcome.fromOutcomePayload(String payload) =>
      SpendingRestorationOutcome(_map(jsonDecode(payload)));
}

abstract final class DeletedSpendingRestorationHistory {
  static Map<String, Object?> outcome(RestoreDeletedSpendingCommand c) => {
    'commandType': c.commandType,
    'operationId': c.operationId,
    _idKey(c.kind): c.recordId,
    'replacementJournalId': c.replacementJournalId,
    'deletedJournalId': c.deletedJournalId,
    'deleteInverseJournalId': c.deleteInverseJournalId,
    'deleteOperationId': c.deleteOperationId,
    'sourceSnapshot': c.sourceSnapshot,
    'position': c.position,
  };
  static PortableJournalEntry entry(
    RestoreDeletedSpendingCommand c,
    PortableJournalEntry target,
    RestaurantJournalMapper mapper,
  ) {
    final wrapped = c.sourceSnapshot,
        row = c.kind == DeletedSpendingKind.expense
            ? _map(wrapped['expense'])
            : wrapped;
    final date = DateOnly.parse(
      wrapped['date']! as String,
      minimumYear: 1000,
      maximumYear: 9999,
    );
    RestaurantJournalProposal proposal;
    if (c.kind == DeletedSpendingKind.expense) {
      final f = _map(row['funding']);
      proposal = mapper.mapOperatingExpense(
        journalId: c.replacementJournalId,
        expenseId: c.recordId,
        effectiveDate: date,
        categoryId: row['categoryId']! as String,
        amount: BigInt.from(row['amount']! as int),
        dailyAmount: BigInt.from(f['dailyAmount']! as int),
        cashboxAmount: BigInt.from(f['cashAmount']! as int),
        policy: target.journal.policy,
      );
    } else if (c.kind == DeletedSpendingKind.transfer) {
      proposal = mapper.mapDailyToCashboxTransfer(
        journalId: c.replacementJournalId,
        transferId: c.recordId,
        effectiveDate: date,
        amount: BigInt.from(row['amount']! as int),
        policy: target.journal.policy,
      );
    } else {
      proposal = mapper.mapExternalCashAdjustment(
        journalId: c.replacementJournalId,
        recordId: c.recordId,
        effectiveDate: date,
        targetCashAccount: mapper.profile.cashboxAccountId,
        amount: BigInt.from(row['amount']! as int),
        isDeposit: row['type'] == 'deposit',
        acceptedCounterAccountId: c.acceptedCounterAccountId,
        policy: target.journal.policy,
      );
    }
    // Restoration repeats the deleted source's exact financial value/context.
    if (proposal.journal.effectiveDate != target.journal.effectiveDate ||
        !_same(
          {
            'lines': proposal.journal.lines.map(_line).toList(),
            'policy': paymentPolicyIdentity(proposal.journal.policy),
          },
          {
            'lines': target.journal.lines.map(_line).toList(),
            'policy': paymentPolicyIdentity(target.journal.policy),
          },
        )) {
      throw const FormatException('restoration_posting_changed');
    }
    proposal = mapper.mapReplacementProposal(
      newProposal: proposal,
      correctedFromId: target.journal.id,
    );
    return PortableJournalEntry(
      journal: proposal.journal,
      sourceType: proposal.sourceType.name,
      sourceRecordId: c.recordId,
      correctedFromJournalId: target.journal.id,
      recordedAt: c.recordedAt,
      metadata: {
        'undoRestoration': true,
        'operationId': c.operationId,
        _idKey(c.kind): c.recordId,
        'sourceVersion': 11,
        'deletedJournalId': c.deletedJournalId,
        'deleteInverseJournalId': c.deleteInverseJournalId,
        'deleteOperationId': c.deleteOperationId,
        'sourceSnapshot': canonicalIdentity(
          c.kind == DeletedSpendingKind.expense ? row : wrapped,
        ),
        'restoredSourceSnapshot': canonicalIdentity(wrapped),
        'reason': c.reason.trim(),
      },
    );
  }

  /// Called only after the predecessor create/correction/delete family edge was
  /// validated. Returns the next explicit restoration, if one exists.
  static ({PortableJournalEntry entry, DurableCommandReceipt receipt})?
  afterDelete({
    required PortableJournalState state,
    required DeletedSpendingKind kind,
    required String recordId,
    required PortableJournalEntry deleted,
    required PortableJournalEntry inverse,
    required DurableCommandReceipt deletion,
    required Map<String, Object?> source,
    required RestaurantJournalMapper mapper,
  }) {
    final candidates = state.journals
        .where(
          (j) =>
              j.metadata['undoRestoration'] == true &&
              j.correctedFromJournalId == deleted.journal.id,
        )
        .toList();
    if (candidates.isEmpty) return null;
    if (candidates.length != 1) {
      throw const FormatException('ambiguous_restoration');
    }
    final actual = candidates.single,
        receipt = correctionReceiptViews(state).singleWhere(
          (r) =>
              r.status == DurableCommandStatus.committed &&
              r.identity.operationId ==
                  candidates.single.metadata['operationId'],
        );
    final c = RestoreDeletedSpendingCommand.fromIntent(
      _map(jsonDecode(receipt.identity.canonicalPayloadIdentity)),
      mapper,
    );
    if (c.identity != receipt.identity ||
        c.kind != kind ||
        c.recordId != recordId ||
        c.accountLineage != state.accountLineage ||
        c.expectedFence != receipt.fence ||
        c.deletedJournalId != deleted.journal.id ||
        c.deleteInverseJournalId != inverse.journal.id ||
        c.deleteOperationId != deletion.identity.operationId ||
        !_same(c.sourceSnapshot, source) ||
        receipt.sequence <= deletion.sequence ||
        state.journals.indexOf(actual) <= state.journals.indexOf(inverse) ||
        c.replacementJournalId != actual.journal.id ||
        !_same(actual.toJson(), entry(c, deleted, mapper).toJson()) ||
        receipt.outcomePayload == null ||
        !_same(_map(jsonDecode(receipt.outcomePayload!)), outcome(c))) {
      throw const FormatException('invalid_restoration_history');
    }
    return (entry: actual, receipt: receipt);
  }

  static Map<String, Object?> _line(JournalLine l) => {
    'accountId': l.accountId,
    'side': l.side.name,
    'amount': l.amountUnits.toString(),
    'currency': l.currency,
    'scale': l.scale,
  };
}

final class DeletedSpendingRestorationCoordinator {
  DeletedSpendingRestorationCoordinator({
    required this.host,
    required this.mapper,
  });
  final JournalCommandHost host;
  final RestaurantJournalMapper mapper;
  Future<DurableCommandResult<SpendingRestorationOutcome>> execute(
    RestoreDeletedSpendingCommand c,
  ) {
    if (c.kind == DeletedSpendingKind.externalCash &&
        (c.acceptedCounterAccountId == null ||
            c.acceptedCounterAccountId!.trim().isEmpty)) {
      return Future.value(
        const DurableCommandFailure(
          code: 'unmapped_financial_gap',
          message: 'Accepted cash mapping required.',
        ),
      );
    }
    return host.execute(
      identity: c.identity,
      accountLineage: c.accountLineage,
      expectedFence: c.expectedFence,
      validateReplayOutcome: (payload, state) {
        try {
          return state.receipts
                      .singleWhere(
                        (r) =>
                            r.identity == c.identity &&
                            r.status == DurableCommandStatus.committed,
                      )
                      .outcomePayload ==
                  payload &&
              _validate(state, c.kind, c.recordId);
        } on Object {
          return false;
        }
      },
      parseOutcome: SpendingRestorationOutcome.fromOutcomePayload,
      evaluateProposal: (state, _) => evaluate(c, state),
    );
  }

  bool _validate(
    PortableJournalState state,
    DeletedSpendingKind kind,
    String id,
  ) => switch (kind) {
    DeletedSpendingKind.expense => RestaurantJournalExpenseHistory.validate(
      state: state,
      expenseId: id,
      mapper: mapper,
    ),
    DeletedSpendingKind.transfer =>
      RestaurantJournalTransferHistory.validateTransferLineage(
        state: state,
        transferId: id,
        mapper: mapper,
      ),
    DeletedSpendingKind.externalCash =>
      RestaurantJournalExternalCashHistory.validate(state, id, mapper),
  };
  DurableProposalEvaluation<PortableJournalState, SpendingRestorationOutcome>
  evaluate(RestoreDeletedSpendingCommand c, PortableJournalState state) {
    DurableProposalEvaluation<PortableJournalState, SpendingRestorationOutcome>
    reject(String code) => DurableProposalEvaluation.reject(
      rejectionCode: code,
      rejectionMessage: 'Deleted source restoration refused.',
    );
    try {
      if (c.expectedFence == null) return reject('missing_authority_fence');
      if (c.accountLineage != state.accountLineage) {
        return reject('account_lineage_mismatch');
      }
      final cutover = state.cutoverState.cutoverDate;
      if (cutover == null ||
          state.cutoverState.isGated ||
          !state.cutoverState.hasActivePosting) {
        return reject('cutover_gated');
      }
      if (!_same(c.context, {
        'profile': paymentProfileIdentity(mapper.profile),
        'policy': paymentPolicyIdentity(mapper.defaultPolicy),
      })) {
        return reject('restoration_context_mismatch');
      }
      if (DateOnly.parse(
            c.sourceSnapshot['date']! as String,
            minimumYear: 1000,
            maximumYear: 9999,
          ).compareTo(cutover) <
          0) {
        return reject('pre_cutover_operation_rejected');
      }
      if (!_validate(state, c.kind, c.recordId)) {
        return reject('invalid_deleted_family');
      }
      final target = state.journals.singleWhere(
            (j) => j.journal.id == c.deletedJournalId,
          ),
          inverse = state.journals.singleWhere(
            (j) => j.journal.id == c.deleteInverseJournalId,
          );
      final receipt = correctionReceiptViews(state).singleWhere(
        (r) =>
            r.identity.operationId == c.deleteOperationId &&
            r.status == DurableCommandStatus.committed,
      );
      final intent = _map(
        jsonDecode(receipt.identity.canonicalPayloadIdentity),
      );
      final expectedDelete = switch (c.kind) {
        DeletedSpendingKind.expense => 'delete_operating_expense',
        DeletedSpendingKind.transfer => 'delete_daily_transfer',
        DeletedSpendingKind.externalCash => 'external_cash_delete',
      };
      if (intent['commandType'] != expectedDelete ||
          intent[_idKey(c.kind)] != c.recordId ||
          intent['expectedActiveJournalId'] != c.deletedJournalId ||
          intent['inverseJournalId'] != c.deleteInverseJournalId ||
          inverse.journal.reversesId != target.journal.id ||
          inverse.metadata['operationId'] != c.deleteOperationId ||
          target.sourceRecordId != c.recordId ||
          state.journals.any(
            (j) =>
                j.metadata['undoRestoration'] == true &&
                j.correctedFromJournalId == target.journal.id,
          )) {
        return reject('restoration_delete_changed');
      }
      final retainedRaw = inverse.metadata['beforeSnapshot'];
      final retained = retainedRaw is String
          ? _map(jsonDecode(retainedRaw))
          : _map(retainedRaw);
      if (!_same(retained, c.sourceSnapshot)) {
        return reject('restoration_source_changed');
      }
      final raw = <String, Object?>{...state.account.toJson()};
      final date = c.sourceSnapshot['date']! as String;
      List<Map<String, Object?>> rows;
      Map<String, Object?>? days, day;
      final key = c.kind == DeletedSpendingKind.transfer
          ? 'transfers'
          : 'transactions';
      if (c.kind == DeletedSpendingKind.expense) {
        days = {...raw['days']! as Map<String, Object?>};
        if (days[date] == null) return reject('restoration_day_missing');
        day = {...days[date]! as Map<String, Object?>};
        rows = (day['expenses']! as List).map(_map).toList();
      } else {
        rows = (raw[key]! as List).map(_map).toList();
      }
      if (rows.any((r) => r['id'] == c.recordId) ||
          canonicalIdentity({'ids': rows.map((r) => r['id']).toList()}) !=
              canonicalIdentity({'ids': c.expectedSiblingIds})) {
        return reject('restoration_source_changed');
      }
      if (c.kind == DeletedSpendingKind.transfer) {
        final remaining = DailyCashQueries(state.account).day(date).remaining;
        if (remaining == null ||
            remaining < BigInt.from(c.sourceSnapshot['amount']! as int)) {
          return reject('excessive_transfer_amount');
        }
      }
      rows.insert(
        c.position,
        c.kind == DeletedSpendingKind.expense
            ? _map(c.sourceSnapshot['expense'])
            : c.sourceSnapshot,
      );
      if (day != null) {
        day['expenses'] = rows;
        days![date] = day;
        raw['days'] = days;
      } else {
        raw[key] = rows;
      }
      final account = const LegacyAccountCodec().decodeJson(raw),
          journal = DeletedSpendingRestorationHistory.entry(c, target, mapper);
      if (state.journals.any((j) => j.journal.id == journal.journal.id)) {
        return reject('duplicate_journal_id');
      }
      final outcome = SpendingRestorationOutcome(
        DeletedSpendingRestorationHistory.outcome(c),
      );
      return DurableProposalEvaluation.accept(
        candidateState: state.copyWith(
          account: account,
          journals: [...state.journals, journal],
        ),
        outcome: outcome,
        outcomePayload: outcome.toOutcomePayload(),
      );
    } on RestaurantJournalMappingException catch (e) {
      return reject(e.code);
    } on FormatException catch (e) {
      return reject(e.message);
    } on Object {
      return reject('invalid_restoration_proposal');
    }
  }
}

Map<String, Object?> _map(Object? v) => (v! as Map).cast<String, Object?>();
bool _same(Map<String, Object?> a, Map<String, Object?> b) =>
    canonicalIdentity(a) == canonicalIdentity(b);
