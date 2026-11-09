import 'dart:convert';

import 'package:madar_application/madar_application.dart';
import 'package:madar_domain/madar_domain.dart';

import '../accounts/legacy_account_codec.dart';
import '../accounts/portable_journal_codec.dart';
import '../accounts/portable_journal_state.dart';
import 'journal_command_host.dart';
import 'correction_batch_receipts.dart';
import 'deleted_spending_restoration.dart';
import 'source_record_order.dart';
import 'restaurant_journal_mapper.dart';
import 'restaurant_journal_payment_correction_commands.dart'
    show paymentProfileIdentity, paymentPolicyIdentity;

/// Source transaction intent. Counteraccount acceptance is supplied by the
/// caller; this layer does not select a financial classification.
final class ExternalCashCommand {
  ExternalCashCommand._({
    required this.kind,
    required this.operationId,
    required this.accountLineage,
    required this.expectedFence,
    required this.transactionId,
    required this.journalId,
    required this.recordedAt,
    required this.acceptedCounterAccountId,
    required RestaurantJournalMapper mapper,
    this.date,
    this.amount,
    this.type,
    this.note = '',
    this.sourceOrder,
    this.expectedActiveJournalId,
    Map<String, Object?>? expectedSource,
    this.inverseJournalId,
    this.reason = '',
  }) : expectedSource = expectedSource == null
           ? null
           : freezeMap(expectedSource),
       context = freezeMap({
         'profile': paymentProfileIdentity(mapper.profile),
         'policy': paymentPolicyIdentity(mapper.defaultPolicy),
       }) {
    for (final id in [
      operationId,
      accountLineage,
      transactionId,
      journalId,
      recordedAt,
    ]) {
      if (id.isEmpty || id.trim() != id) {
        throw const FormatException('invalid_external_cash_identity');
      }
    }
    if (kind != 'delete' &&
        (date == null ||
            amount == null ||
            amount! <= BigInt.zero ||
            amount! > RestaurantJournalPolicies.defaultLimit ||
            !['deposit', 'withdrawal'].contains(type))) {
      throw const FormatException('invalid_external_cash_source');
    }
    if (kind != 'create' &&
        (reason.trim().isEmpty ||
            this.expectedSource == null ||
            expectedActiveJournalId == null ||
            expectedActiveJournalId!.isEmpty ||
            inverseJournalId == null ||
            inverseJournalId!.isEmpty)) {
      throw const FormatException('invalid_external_cash_correction');
    }
    if (kind != 'create' &&
        (inverseJournalId == expectedActiveJournalId ||
            (kind == 'edit' &&
                {journalId, inverseJournalId, expectedActiveJournalId}.length !=
                    3))) {
      throw const FormatException('duplicate_journal_id');
    }
    if (sourceOrder != null && kind != 'edit') {
      throw const FormatException('invalid_external_cash_order');
    }
    canonicalPayloadIdentity = canonicalIdentity(toJson());
  }
  factory ExternalCashCommand.create({
    required String operationId,
    required String accountLineage,
    required StorageFence? expectedFence,
    required String transactionId,
    required String journalId,
    required String recordedAt,
    required String? acceptedCounterAccountId,
    required RestaurantJournalMapper mapper,
    required DateOnly date,
    required BigInt amount,
    required String type,
    String note = '',
  }) => ExternalCashCommand._(
    kind: 'create',
    operationId: operationId,
    accountLineage: accountLineage,
    expectedFence: expectedFence,
    transactionId: transactionId,
    journalId: journalId,
    recordedAt: recordedAt,
    acceptedCounterAccountId: acceptedCounterAccountId,
    mapper: mapper,
    date: date,
    amount: amount,
    type: type,
    note: note,
  );
  factory ExternalCashCommand.edit({
    required String operationId,
    required String accountLineage,
    required StorageFence? expectedFence,
    required String transactionId,
    required String journalId,
    required String inverseJournalId,
    required String expectedActiveJournalId,
    required Map<String, Object?> expectedSource,
    required String reason,
    required String recordedAt,
    required String? acceptedCounterAccountId,
    required RestaurantJournalMapper mapper,
    required DateOnly date,
    required BigInt amount,
    required String type,
    String note = '',
    SourceRecordOrder? sourceOrder,
  }) => ExternalCashCommand._(
    kind: 'edit',
    operationId: operationId,
    accountLineage: accountLineage,
    expectedFence: expectedFence,
    transactionId: transactionId,
    journalId: journalId,
    inverseJournalId: inverseJournalId,
    expectedActiveJournalId: expectedActiveJournalId,
    expectedSource: expectedSource,
    reason: reason,
    recordedAt: recordedAt,
    acceptedCounterAccountId: acceptedCounterAccountId,
    mapper: mapper,
    date: date,
    amount: amount,
    type: type,
    note: note,
    sourceOrder: sourceOrder,
  );
  factory ExternalCashCommand.delete({
    required String operationId,
    required String accountLineage,
    required StorageFence? expectedFence,
    required String transactionId,
    required String inverseJournalId,
    required String expectedActiveJournalId,
    required Map<String, Object?> expectedSource,
    required String reason,
    required String recordedAt,
    required String? acceptedCounterAccountId,
    required RestaurantJournalMapper mapper,
  }) => ExternalCashCommand._(
    kind: 'delete',
    operationId: operationId,
    accountLineage: accountLineage,
    expectedFence: expectedFence,
    transactionId: transactionId,
    journalId: inverseJournalId,
    inverseJournalId: inverseJournalId,
    expectedActiveJournalId: expectedActiveJournalId,
    expectedSource: expectedSource,
    reason: reason,
    recordedAt: recordedAt,
    acceptedCounterAccountId: acceptedCounterAccountId,
    mapper: mapper,
  );
  final String kind,
      operationId,
      accountLineage,
      transactionId,
      journalId,
      recordedAt,
      note,
      reason;
  final String? acceptedCounterAccountId,
      type,
      expectedActiveJournalId,
      inverseJournalId;
  final SourceRecordOrder? sourceOrder;
  final StorageFence? expectedFence;
  final DateOnly? date;
  final BigInt? amount;
  final Map<String, Object?>? expectedSource;
  final Map<String, Object?> context;
  late final String canonicalPayloadIdentity;
  DurableCommandIdentity get identity => DurableCommandIdentity(
    operationId: operationId,
    payloadVersion: 1,
    canonicalPayloadIdentity: canonicalPayloadIdentity,
  );
  Map<String, Object?> toJson() => {
    'commandType': 'external_cash_$kind',
    'operationId': operationId,
    'payloadVersion': 1,
    'accountLineage': accountLineage,
    'expectedFence': expectedFence == null
        ? null
        : {
            'storeId': expectedFence!.storeId,
            'generation': expectedFence!.generation,
          },
    'transactionId': transactionId,
    'journalId': journalId,
    'recordedAt': recordedAt,
    'acceptedCounterAccountId': acceptedCounterAccountId,
    'context': context,
    if (sourceOrder != null) 'sourceOrder': sourceOrder!.toJson(),
    if (kind != 'delete') ...{
      'date': date.toString(),
      'amount': amount.toString(),
      'type': type,
      'note': note,
    },
    if (kind != 'create') ...{
      'expectedActiveJournalId': expectedActiveJournalId,
      'expectedSource': expectedSource,
      'expectedSourceVersion': 11,
      'inverseJournalId': inverseJournalId,
      'reason': reason,
    },
  };
  Map<String, Object?>? sourceAfter(Map<String, Object?>? before) =>
      kind == 'delete'
      ? null
      : {
          'id': transactionId,
          'type': type,
          'amount': amount!.toInt(),
          'note': note.trim(),
          'date': date.toString(),
          'createdAt': before?['createdAt'] ?? recordedAt,
        };
  static ExternalCashCommand fromIntent(
    Map<String, Object?> i,
    RestaurantJournalMapper mapper,
  ) {
    if (!_same(_map(i['context']), {
          'profile': paymentProfileIdentity(mapper.profile),
          'policy': paymentPolicyIdentity(mapper.defaultPolicy),
        }) ||
        i['payloadVersion'] != 1) {
      throw const FormatException('external_cash_context_mismatch');
    }
    final f = i['expectedFence'] == null ? null : _map(i['expectedFence']);
    final kind = (i['commandType']! as String).replaceFirst(
      'external_cash_',
      '',
    );
    if (!['create', 'edit', 'delete'].contains(kind) ||
        (kind != 'create' && i['expectedSourceVersion'] != 11)) {
      throw const FormatException('invalid_external_cash_intent');
    }
    return ExternalCashCommand._(
      kind: kind,
      operationId: i['operationId']! as String,
      accountLineage: i['accountLineage']! as String,
      expectedFence: f == null
          ? null
          : StorageFence(
              storeId: f['storeId']! as String,
              generation: f['generation']! as String,
            ),
      transactionId: i['transactionId']! as String,
      journalId: i['journalId']! as String,
      recordedAt: i['recordedAt']! as String,
      acceptedCounterAccountId: i['acceptedCounterAccountId'] as String?,
      mapper: mapper,
      date: kind == 'delete'
          ? null
          : DateOnly.parse(
              i['date']! as String,
              minimumYear: 1000,
              maximumYear: 9999,
            ),
      amount: kind == 'delete' ? null : BigInt.parse(i['amount']! as String),
      type: i['type'] as String?,
      note: i['note'] as String? ?? '',
      sourceOrder: i['sourceOrder'] == null
          ? null
          : SourceRecordOrder.fromJson(_map(i['sourceOrder'])),
      expectedActiveJournalId: i['expectedActiveJournalId'] as String?,
      expectedSource: i['expectedSource'] == null
          ? null
          : _map(i['expectedSource']),
      inverseJournalId: i['inverseJournalId'] as String?,
      reason: i['reason'] as String? ?? '',
    );
  }
}

final class ExternalCashOutcome {
  ExternalCashOutcome(Map<String, Object?> values) : values = freezeMap(values);
  final Map<String, Object?> values;
  String get transactionId => values['transactionId']! as String;
  Map<String, Object?> toJson() => values;
  String toOutcomePayload() => canonicalIdentity(values);
  factory ExternalCashOutcome.fromOutcomePayload(String payload) =>
      ExternalCashOutcome(_map(jsonDecode(payload)));
  @override
  String toString() => 'ExternalCashOutcome(details: redacted)';
}

/// Validates the complete receipt-backed transaction family, including deleted
/// families, so old create/edit receipts remain replayable after corrections.
abstract final class RestaurantJournalExternalCashHistory {
  static List<Map<String, Object?>> sourceRows(
    PortableJournalState state,
    String id,
  ) => (state.account.toJson()['transactions']! as List)
      .map(_map)
      .where((r) => r['id'] == id)
      .toList();
  static List<PortableJournalEntry> entries(
    ExternalCashCommand command,
    RestaurantJournalMapper mapper,
    Map<String, Object?>? before,
    PortableJournalEntry? target,
  ) {
    final after = command.sourceAfter(before);
    final metadata = <String, Object?>{
      'externalCash': true,
      'operationId': command.operationId,
      'sourceVersion': 11,
      'beforeSnapshot': before == null ? null : canonicalIdentity(before),
      'afterSnapshot': after == null ? null : canonicalIdentity(after),
      'reason': command.reason.trim(),
    };
    final result = <PortableJournalEntry>[];
    if (command.kind != 'create') {
      final inverse = mapper.mapOriginalDateVoid(
        originalProposal: RestaurantJournalProposal(
          journal: target!.journal,
          sourceType: RestaurantJournalSourceType.values.byName(
            target.sourceType,
          ),
          sourceRecordId: command.transactionId,
          sourceVersion: 11,
        ),
        reversalJournalId: command.inverseJournalId!,
        reason: command.reason.trim(),
        isEligible: true,
        voidRecordId: command.transactionId,
      );
      result.add(
        PortableJournalEntry(
          journal: inverse.journal,
          sourceType: inverse.sourceType.name,
          sourceRecordId: command.transactionId,
          replacementJournalId: command.kind == 'edit'
              ? command.journalId
              : null,
          recordedAt: command.recordedAt,
          metadata: metadata,
        ),
      );
    }
    if (after != null) {
      var proposal = mapper.mapExternalCashAdjustment(
        journalId: command.journalId,
        recordId: command.transactionId,
        effectiveDate: command.date!,
        targetCashAccount: mapper.profile.cashboxAccountId,
        amount: command.amount!,
        isDeposit: command.type == 'deposit',
        acceptedCounterAccountId: command.acceptedCounterAccountId,
      );
      if (target != null) {
        proposal = mapper.mapReplacementProposal(
          newProposal: proposal,
          correctedFromId: target.journal.id,
        );
      }
      result.add(
        PortableJournalEntry(
          journal: proposal.journal,
          sourceType: proposal.sourceType.name,
          sourceRecordId: command.transactionId,
          correctedFromJournalId: target?.journal.id,
          recordedAt: command.recordedAt,
          metadata: {...metadata, 'sourceSnapshot': canonicalIdentity(after)},
        ),
      );
    }
    return result;
  }

  static ExternalCashOutcome outcome(
    ExternalCashCommand c,
    List<PortableJournalEntry> entries,
  ) => ExternalCashOutcome({
    'commandType': 'external_cash_${c.kind}',
    'operationId': c.operationId,
    'transactionId': c.transactionId,
    'journalIds': entries.map((e) => e.journal.id).toList(),
    'beforeSnapshot': entries.first.metadata['beforeSnapshot'],
    'afterSnapshot': entries.first.metadata['afterSnapshot'],
  });
  static PortableJournalEntry? activePosting(
    PortableJournalState state,
    String id,
    RestaurantJournalMapper mapper,
  ) => _validate(state, id, mapper)?.active;
  static bool validate(
    PortableJournalState state,
    String id,
    RestaurantJournalMapper mapper,
  ) => _validate(state, id, mapper) != null;
  static ({PortableJournalEntry? active})? _validate(
    PortableJournalState state,
    String id,
    RestaurantJournalMapper mapper,
  ) {
    try {
      final cutover = state.cutoverState.cutoverDate;
      if (cutover == null ||
          state.cutoverState.isGated ||
          !state.cutoverState.hasActivePosting) {
        return null;
      }
      final receipts = correctionReceiptViews(state).where((r) {
        if (r.status != DurableCommandStatus.committed) return false;
        try {
          final i = _map(jsonDecode(r.identity.canonicalPayloadIdentity));
          return i['transactionId'] == id &&
              [
                'external_cash_create',
                'external_cash_edit',
                'external_cash_delete',
                'restore_deleted_external_cash',
              ].contains(i['commandType']);
        } on Object {
          return false;
        }
      }).toList()..sort((a, b) => a.sequence.compareTo(b.sequence));
      if (receipts.isEmpty) return null;
      Map<String, Object?>? source;
      PortableJournalEntry? active, deletedTarget, deletedInverse;
      DurableCommandReceipt? deletionReceipt;
      Map<String, Object?>? deletedSource;
      var lastSequence = 0, lastIndex = -1;
      final owned = <String>{};
      for (var n = 0; n < receipts.length; n++) {
        final restorationIntent = _map(
          jsonDecode(receipts[n].identity.canonicalPayloadIdentity),
        );
        if (restorationIntent['commandType'] ==
            'restore_deleted_external_cash') {
          if (active != null ||
              deletedTarget == null ||
              deletedInverse == null ||
              deletionReceipt == null ||
              deletedSource == null) {
            return null;
          }
          final restored = DeletedSpendingRestorationHistory.afterDelete(
            state: state,
            kind: DeletedSpendingKind.externalCash,
            recordId: id,
            deleted: deletedTarget,
            inverse: deletedInverse,
            deletion: deletionReceipt,
            source: deletedSource,
            mapper: mapper,
          );
          if (restored == null ||
              restored.receipt.identity != receipts[n].identity ||
              !owned.add(restored.entry.journal.id) ||
              restored.receipt.sequence <= lastSequence ||
              state.journals.indexOf(restored.entry) <= lastIndex) {
            return null;
          }
          source = deletedSource;
          active = restored.entry;
          lastSequence = restored.receipt.sequence;
          lastIndex = state.journals.indexOf(restored.entry);
          continue;
        }
        final r = receipts[n],
            c = ExternalCashCommand.fromIntent(
              _map(jsonDecode(receipts[n].identity.canonicalPayloadIdentity)),
              mapper,
            );
        if (c.identity != r.identity ||
            c.accountLineage != state.accountLineage ||
            c.expectedFence != r.fence ||
            r.committedRevision <= 0 ||
            r.sequence <= lastSequence ||
            c.acceptedCounterAccountId == null ||
            c.acceptedCounterAccountId!.trim().isEmpty ||
            (n == 0
                ? c.kind != 'create'
                : c.kind == 'create' ||
                      active == null ||
                      !_same(c.expectedSource!, source!) ||
                      c.expectedActiveJournalId != active.journal.id)) {
          return null;
        }
        if (c.date != null && c.date!.compareTo(cutover) < 0) return null;
        final expected = entries(c, mapper, source, active);
        for (final entry in expected) {
          final found = state.journals
              .where((e) => e.journal.id == entry.journal.id)
              .toList();
          if (found.length != 1 ||
              !_same(found.single.toJson(), entry.toJson()) ||
              !owned.add(entry.journal.id)) {
            return null;
          }
          final index = state.journals.indexOf(found.single);
          if (index <= lastIndex) return null;
          lastIndex = index;
        }
        if (r.outcomePayload == null ||
            !_same(
              _map(jsonDecode(r.outcomePayload!)),
              outcome(c, expected).toJson(),
            )) {
          return null;
        }
        if (c.kind == 'delete') {
          deletedSource = source;
          deletedTarget = active;
          deletedInverse = expected.first;
          deletionReceipt = r;
        }
        source = c.sourceAfter(source);
        active = c.kind == 'delete' ? null : expected.last;
        lastSequence = r.sequence;
      }
      for (final j in state.journals) {
        if (((j.sourceRecordId == id &&
                    (j.metadata['externalCash'] == true ||
                        j.sourceType ==
                            RestaurantJournalSourceType
                                .externalCashAdjustment
                                .name)) ||
                owned.contains(j.journal.reversesId) ||
                owned.contains(j.correctedFromJournalId) ||
                owned.contains(j.replacementJournalId)) &&
            !owned.contains(j.journal.id)) {
          return null;
        }
      }
      final rows = sourceRows(state, id);
      if (source == null
          ? rows.isNotEmpty
          : rows.length != 1 || !_same(rows.single, source)) {
        return null;
      }
      return (active: active);
    } on Object {
      return null;
    }
  }
}

final class RestaurantJournalExternalCashCoordinator {
  RestaurantJournalExternalCashCoordinator({
    required LocalDocumentWorkspaceStore store,
    JournalCommandHost? host,
    RestaurantJournalMapper? mapper,
    PortableJournalCodec? codec,
  }) : host = host ?? JournalCommandHost(store: store, codec: codec),
       mapper = mapper ?? RestaurantJournalMapper() {
    if (!identical(this.host.store, store)) {
      throw ArgumentError('Command host must use the same store owner.');
    }
  }
  final JournalCommandHost host;
  final RestaurantJournalMapper mapper;
  Future<DurableCommandResult<ExternalCashOutcome>> execute(
    ExternalCashCommand command,
  ) {
    // A missing mapping must not even persist a rejection receipt.
    if (command.acceptedCounterAccountId == null ||
        command.acceptedCounterAccountId!.trim().isEmpty) {
      return Future.value(
        const DurableCommandFailure(
          code: 'unmapped_financial_gap',
          message: 'External cash requires an accepted counteraccount.',
        ),
      );
    }
    return host.execute(
      identity: command.identity,
      accountLineage: command.accountLineage,
      expectedFence: command.expectedFence,
      validateReplayOutcome: (payload, state) {
        try {
          return state.receipts
                      .singleWhere(
                        (r) =>
                            r.identity == command.identity &&
                            r.status == DurableCommandStatus.committed,
                      )
                      .outcomePayload ==
                  payload &&
              RestaurantJournalExternalCashHistory.validate(
                state,
                command.transactionId,
                mapper,
              );
        } on Object {
          return false;
        }
      },
      parseOutcome: ExternalCashOutcome.fromOutcomePayload,
      evaluateProposal: (state, _) =>
          evaluate(command: command, state: state, mapper: mapper),
    );
  }

  static DurableProposalEvaluation<PortableJournalState, ExternalCashOutcome>
  evaluate({
    required ExternalCashCommand command,
    required PortableJournalState state,
    required RestaurantJournalMapper mapper,
  }) {
    DurableProposalEvaluation<PortableJournalState, ExternalCashOutcome> reject(
      String code,
    ) => DurableProposalEvaluation.reject(
      rejectionCode: code,
      rejectionMessage: 'External cash operation refused.',
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
      if (!_same(command.context, {
        'profile': paymentProfileIdentity(mapper.profile),
        'policy': paymentPolicyIdentity(mapper.defaultPolicy),
      })) {
        return reject('external_cash_context_mismatch');
      }
      if (command.acceptedCounterAccountId == null ||
          command.acceptedCounterAccountId!.trim().isEmpty) {
        return reject('unmapped_financial_gap');
      }
      final rows = RestaurantJournalExternalCashHistory.sourceRows(
        state,
        command.transactionId,
      );
      Map<String, Object?>? before;
      PortableJournalEntry? target;
      if (command.kind == 'create') {
        if (rows.isNotEmpty ||
            state.journals.any(
              (j) =>
                  j.sourceRecordId == command.transactionId &&
                  (j.metadata['externalCash'] == true ||
                      j.sourceType ==
                          RestaurantJournalSourceType
                              .externalCashAdjustment
                              .name),
            )) {
          return reject('duplicate_transaction_id');
        }
      } else {
        if (rows.length != 1) {
          return reject('transaction_not_found_or_ambiguous');
        }
        before = rows.single;
        if (!_same(before, command.expectedSource!)) {
          return reject('transaction_source_changed');
        }
        if ((before['date']! as String).compareTo(cutover.toString()) < 0) {
          return reject('pre_cutover_operation_rejected');
        }
        target = RestaurantJournalExternalCashHistory.activePosting(
          state,
          command.transactionId,
          mapper,
        );
        if (target == null ||
            target.journal.id != command.expectedActiveJournalId) {
          return reject('cross_cutover_source_has_no_post_cutover_journal');
        }
      }
      if (command.date != null && command.date!.compareTo(cutover) < 0) {
        return reject('pre_cutover_operation_rejected');
      }
      final entries = RestaurantJournalExternalCashHistory.entries(
        command,
        mapper,
        before,
        target,
      );
      if (entries.any(
        (e) => state.journals.any((j) => j.journal.id == e.journal.id),
      )) {
        return reject('duplicate_journal_id');
      }
      final after = command.sourceAfter(before);
      final raw = <String, Object?>{...state.account.toJson()};
      raw['transactions'] = [
        ...(raw['transactions']! as List)
            .map(_map)
            .where((r) => r['id'] != command.transactionId),
        ?after,
      ];
      var account = const LegacyAccountCodec().decodeJson(raw);
      if (command.sourceOrder != null) {
        account = command.sourceOrder!.apply(
          account,
          'transactions',
          command.transactionId,
        );
      }
      final outcome = RestaurantJournalExternalCashHistory.outcome(
        command,
        entries,
      );
      return DurableProposalEvaluation.accept(
        candidateState: state.copyWith(
          account: account,
          journals: [...state.journals, ...entries],
        ),
        outcome: outcome,
        outcomePayload: outcome.toOutcomePayload(),
      );
    } on RestaurantJournalMappingException catch (e) {
      return reject(e.code);
    } on FormatException catch (e) {
      return reject(e.message);
    } on Object {
      return reject('invalid_external_cash_proposal');
    }
  }
}

Map<String, Object?> _map(Object? v) => (v! as Map).cast<String, Object?>();
bool _same(Map<String, Object?> a, Map<String, Object?> b) =>
    canonicalIdentity(a) == canonicalIdentity(b);
