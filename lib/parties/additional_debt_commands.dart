import 'dart:convert';

import 'package:madar_application/madar_application.dart';
import 'package:madar_domain/madar_domain.dart';

import '../accounts/legacy_account_codec.dart';
import '../accounts/portable_journal_codec.dart';
import '../accounts/portable_journal_state.dart';
import '../accounting/journal_command_host.dart';
import '../accounting/source_record_order.dart';
import '../accounting/restaurant_journal_mapper.dart';
import 'supplier_opening_commands.dart';
import '../accounting/restaurant_journal_payment_correction_commands.dart'
    show paymentProfileIdentity, paymentPolicyIdentity;

/// Restaurant-specific debt intent. Shared persistence/replay belongs to Madar.
final class AdditionalDebtCommand {
  AdditionalDebtCommand({
    required this.kind,
    required this.operationId,
    required this.accountLineage,
    required this.fence,
    required this.debtId,
    required this.recordedAt,
    required this.acceptedCounterAccountId,
    required RestaurantJournalMapper mapper,
    this.supplierId,
    this.date,
    this.amount,
    this.note = '',
    this.reason = '',
    this.expectedActiveJournalId,
    this.sourceOrder,
    this.restoreOf,
    Map<String, Object?>? expectedSource,
  }) : expectedSource = expectedSource == null
           ? null
           : freezeMap(expectedSource),
       context = freezeMap({
         'profile': paymentProfileIdentity(mapper.profile),
         'policy': paymentPolicyIdentity(mapper.defaultPolicy),
       }) {
    if (!['create', 'edit', 'delete', 'restore'].contains(kind) ||
        [
          operationId,
          accountLineage,
          debtId,
          recordedAt,
        ].any((s) => s.trim().isEmpty || s.trim() != s) ||
        note.length > 500 ||
        reason.length > 500) {
      throw const FormatException('invalid_debt_intent');
    }
    if (kind != 'delete' &&
        (supplierId == null ||
            supplierId!.trim().isEmpty ||
            date == null ||
            amount == null ||
            amount! <= BigInt.zero ||
            amount! > RestaurantJournalPolicies.defaultLimit)) {
      throw const FormatException('invalid_debt_source');
    }
    if (kind != 'create' &&
        (reason.trim().isEmpty ||
            this.expectedSource == null ||
            expectedActiveJournalId == null)) {
      throw const FormatException('invalid_debt_correction');
    }
    if ((kind == 'restore') != (restoreOf != null) ||
        (sourceOrder != null && !['delete', 'restore'].contains(kind))) {
      throw const FormatException('invalid_debt_restoration');
    }
    if (kind == 'restore' &&
        (sourceOrder == null ||
            expectedSource!['id'] != debtId ||
            expectedSource['supplierId'] != supplierId ||
            expectedSource['date'] != date.toString() ||
            expectedSource['amount'] != amount!.toInt() ||
            expectedSource['note'] != note.trim())) {
      throw const FormatException('restored_debt_source_mismatch');
    }
  }
  final String kind,
      operationId,
      accountLineage,
      debtId,
      recordedAt,
      note,
      reason;
  final StorageFence fence;
  final String? supplierId, acceptedCounterAccountId, expectedActiveJournalId;
  final DateOnly? date;
  final BigInt? amount;
  final Map<String, Object?>? expectedSource;
  final Map<String, Object?> context;
  final SourceRecordOrder? sourceOrder;
  final String? restoreOf;
  String get journalId => '$operationId:debt';
  String get inverseJournalId => '$operationId:inverse';
  DurableCommandIdentity get identity => DurableCommandIdentity(
    operationId: operationId,
    payloadVersion: 1,
    canonicalPayloadIdentity: canonicalIdentity(toJson()),
  );
  Map<String, Object?> toJson() => {
    'commandType': 'additional_debt_$kind',
    'operationId': operationId,
    'accountLineage': accountLineage,
    'fence': {'storeId': fence.storeId, 'generation': fence.generation},
    'debtId': debtId,
    'recordedAt': recordedAt,
    'context': context,
    'acceptedCounterAccountId': acceptedCounterAccountId,
    'supplierId': supplierId,
    'date': date?.toString(),
    'amount': amount?.toString(),
    'note': note,
    'reason': reason,
    'expectedSource': expectedSource,
    'expectedActiveJournalId': expectedActiveJournalId,
    if (sourceOrder != null) 'sourceOrder': sourceOrder!.toJson(),
    if (restoreOf != null) 'restoreOf': restoreOf,
  };
  factory AdditionalDebtCommand.fromIntent(
    Map<String, Object?> i,
    RestaurantJournalMapper mapper,
  ) {
    final f = _map(i['fence']);
    final command = AdditionalDebtCommand(
      kind: (i['commandType']! as String).replaceFirst('additional_debt_', ''),
      operationId: i['operationId']! as String,
      accountLineage: i['accountLineage']! as String,
      fence: StorageFence(
        storeId: f['storeId']! as String,
        generation: f['generation']! as String,
      ),
      debtId: i['debtId']! as String,
      recordedAt: i['recordedAt']! as String,
      acceptedCounterAccountId: i['acceptedCounterAccountId'] as String?,
      mapper: mapper,
      supplierId: i['supplierId'] as String?,
      date: i['date'] == null
          ? null
          : DateOnly.parse(
              i['date']! as String,
              minimumYear: 1000,
              maximumYear: 9999,
            ),
      amount: i['amount'] == null ? null : BigInt.parse(i['amount']! as String),
      note: i['note']! as String,
      reason: i['reason']! as String,
      expectedSource: i['expectedSource'] == null
          ? null
          : _map(i['expectedSource']),
      expectedActiveJournalId: i['expectedActiveJournalId'] as String?,
      sourceOrder: i['sourceOrder'] == null
          ? null
          : SourceRecordOrder.fromJson(_map(i['sourceOrder'])),
      restoreOf: i['restoreOf'] as String?,
    );
    if (canonicalIdentity(command.toJson()) != canonicalIdentity(i)) {
      throw const FormatException('debt_context_mismatch');
    }
    return command;
  }
  Map<String, Object?>? after(Map<String, Object?>? before) => kind == 'delete'
      ? null
      : kind == 'restore'
      ? expectedSource!
      : {
          'id': debtId,
          'supplierId': supplierId,
          'date': date.toString(),
          'amount': amount!.toInt(),
          'note': note.trim(),
          'createdAt': before?['createdAt'] ?? recordedAt,
        };
}

final class AdditionalDebtOutcome {
  AdditionalDebtOutcome(Map<String, Object?> value) : values = freezeMap(value);
  final Map<String, Object?> values;
  String get debtId => values['debtId']! as String;
  String get payload => canonicalIdentity(values);
  factory AdditionalDebtOutcome.parse(String payload) =>
      AdditionalDebtOutcome(_map(jsonDecode(payload)));
}

abstract final class AdditionalDebtHistory {
  static List<Map<String, Object?>> rows(
    PortableJournalState state,
    String id,
  ) => (state.account.toJson()['debts']! as List)
      .map(_map)
      .where((r) => r['id'] == id)
      .toList();

  static List<PortableJournalEntry> entries(
    AdditionalDebtCommand c,
    RestaurantJournalMapper mapper,
    Map<String, Object?>? before,
    PortableJournalEntry? target,
  ) {
    final after = c.after(before);
    final metadata = <String, Object?>{
      'additionalDebt': true,
      'operationId': c.operationId,
      'beforeSnapshot': before == null ? null : canonicalIdentity(before),
      'afterSnapshot': after == null ? null : canonicalIdentity(after),
      'reason': c.reason.trim(),
      if (c.kind == 'restore') 'restoresDeletion': c.restoreOf,
    };
    final result = <PortableJournalEntry>[];
    if (target != null && c.kind != 'restore') {
      final inverse = mapper.mapOriginalDateVoid(
        originalProposal: RestaurantJournalProposal(
          journal: target.journal,
          sourceType: RestaurantJournalSourceType.manualDebt,
          sourceRecordId: c.debtId,
        ),
        reversalJournalId: c.inverseJournalId,
        reason: c.reason.trim(),
        isEligible: true,
        voidRecordId: c.debtId,
      );
      result.add(
        PortableJournalEntry(
          journal: inverse.journal,
          sourceType: inverse.sourceType.name,
          sourceRecordId: c.debtId,
          replacementJournalId: c.kind == 'edit' ? c.journalId : null,
          recordedAt: c.recordedAt,
          metadata: metadata,
        ),
      );
    }
    if (after != null) {
      var proposal = mapper.mapManualAdditionalDebt(
        journalId: c.journalId,
        debtId: c.debtId,
        supplierId: c.supplierId!,
        effectiveDate: c.date!,
        amount: c.amount!,
        acceptedCounterAccountId: c.acceptedCounterAccountId,
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
          sourceRecordId: c.debtId,
          correctedFromJournalId: target?.journal.id,
          recordedAt: c.recordedAt,
          metadata: {...metadata, 'sourceSnapshot': canonicalIdentity(after)},
        ),
      );
    }
    return result;
  }

  static AdditionalDebtOutcome outcome(
    AdditionalDebtCommand c,
    List<PortableJournalEntry> entries,
  ) => AdditionalDebtOutcome({
    'debtId': c.debtId,
    'operationId': c.operationId,
    'kind': c.kind,
    'journalIds': entries.map((e) => e.journal.id).toList(),
  });

  /// Recognized liability uses the verified posting, including its debit side.
  /// A source amount alone cannot establish settlement capacity.
  static BigInt liability(
    PortableJournalEntry entry,
    String supplierId,
    RestaurantJournalMapper mapper,
  ) => ExactMath.checkedSum(
    entry.journal.lines
        .where(
          (line) =>
              line.accountId ==
              mapper.profile.supplierLiabilityAccountId(supplierId),
        )
        .map(
          (line) => line.side == JournalSide.credit
              ? line.amountUnits
              : -line.amountUnits,
        ),
    maxAbs: RestaurantJournalPolicies.maximumSafeAggregate,
    maxSafeInteger: RestaurantJournalPolicies.maximumSafeAggregate,
  );

  /// Proves each affected supplier still covers retained post-cutover debt
  /// settlements at every settlement date. Source-only legacy debt is excluded.
  static bool preservesSettlements({
    required PortableJournalState state,
    required AdditionalDebtCommand command,
    required Map<String, Object?>? before,
    required Map<String, Object?>? after,
    required List<PortableJournalEntry> entries,
    required RestaurantJournalMapper mapper,
  }) {
    final cutover = state.cutoverState.cutoverDate!;
    final affected = <String>{
      if (before != null) before['supplierId']! as String,
      if (after != null) after['supplierId']! as String,
    };
    final source = state.account.toJson();
    final opening = state.journals
        .where((j) => j.journal.id == state.cutoverState.openingJournalId)
        .toList();
    if (opening.length != 1 ||
        state.journals.any(
          (j) => j.journal.reversesId == opening.single.journal.id,
        )) {
      return false;
    }
    for (final supplier in affected) {
      final payments = (source['payments']! as List)
          .map(_map)
          .where(
            (row) =>
                row['supplierId'] == supplier &&
                (row['date']! as String).compareTo(cutover.toString()) >= 0 &&
                (row['debtAmount']! as int) > 0,
          )
          .toList();
      final dates = payments.map((row) => row['date']! as String).toSet();
      if (dates.isEmpty) continue;
      final credits = <({String date, BigInt amount})>[];
      for (final row in (source['debts']! as List).map(_map)) {
        if (row['id'] == command.debtId ||
            row['supplierId'] != supplier ||
            (row['date']! as String).compareTo(cutover.toString()) < 0) {
          continue;
        }
        final active = validate(state, row['id']! as String, mapper)?.active;
        if (active != null) {
          credits.add((
            date: row['date']! as String,
            amount: liability(active, supplier, mapper),
          ));
        }
      }
      if (after != null && after['supplierId'] == supplier) {
        credits.add((
          date: after['date']! as String,
          amount: liability(entries.last, supplier, mapper),
        ));
      }
      final initial = SupplierOpeningHistory.recognizedOpening(
        state,
        supplier,
        mapper,
      );
      for (final date in dates) {
        final available = ExactMath.checkedSum(
          [
            initial,
            ...credits
                .where((credit) => credit.date.compareTo(date) <= 0)
                .map((credit) => credit.amount),
            ...payments
                .where(
                  (payment) =>
                      (payment['date']! as String).compareTo(date) <= 0,
                )
                .map((payment) => -BigInt.from(payment['debtAmount']! as int)),
          ],
          maxAbs: RestaurantJournalPolicies.maximumSafeAggregate,
          maxSafeInteger: RestaurantJournalPolicies.maximumSafeAggregate,
        );
        if (available.isNegative) return false;
      }
    }
    return true;
  }

  static ({
    PortableJournalEntry? active,
    PortableJournalEntry? deletedTarget,
    AdditionalDebtCommand? deletion,
    AdditionalDebtCommand? deletedIntent,
  })?
  validate(
    PortableJournalState state,
    String id,
    RestaurantJournalMapper mapper,
  ) {
    try {
      final receipts = state.receipts.where((r) {
        if (r.status != DurableCommandStatus.committed) return false;
        try {
          final i = _map(jsonDecode(r.identity.canonicalPayloadIdentity));
          return i['debtId'] == id &&
              (i['commandType'] as String? ?? '').startsWith(
                'additional_debt_',
              );
        } on Object {
          return false;
        }
      }).toList()..sort((a, b) => a.sequence.compareTo(b.sequence));
      if (receipts.isEmpty) return null;
      Map<String, Object?>? source;
      PortableJournalEntry? active, deletedTarget;
      AdditionalDebtCommand? activeIntent, deletion, deletedIntent;
      final owned = <String>{};
      var sequence = 0, journalIndex = -1;
      for (var n = 0; n < receipts.length; n++) {
        final receipt = receipts[n];
        final c = AdditionalDebtCommand.fromIntent(
          _map(jsonDecode(receipt.identity.canonicalPayloadIdentity)),
          mapper,
        );
        if (c.identity != receipt.identity ||
            c.fence != receipt.fence ||
            receipt.committedRevision <= 0 ||
            receipt.sequence <= sequence ||
            c.accountLineage != state.accountLineage ||
            c.acceptedCounterAccountId == null ||
            c.acceptedCounterAccountId!.trim().isEmpty ||
            (c.date != null &&
                c.date!.compareTo(state.cutoverState.cutoverDate!) < 0) ||
            (n == 0
                ? c.kind != 'create'
                : c.kind == 'restore'
                ? active != null ||
                      deletion == null ||
                      deletedTarget == null ||
                      deletedIntent == null ||
                      c.restoreOf !=
                          deletion.identity.canonicalPayloadIdentity ||
                      c.expectedActiveJournalId != deletedTarget.journal.id ||
                      c.acceptedCounterAccountId !=
                          deletedIntent.acceptedCounterAccountId ||
                      canonicalIdentity(c.expectedSource!) !=
                          canonicalIdentity(deletion.expectedSource!) ||
                      canonicalIdentity(c.sourceOrder!.toJson()) !=
                          canonicalIdentity(deletion.sourceOrder!.toJson())
                : c.kind == 'create' ||
                      active == null ||
                      canonicalIdentity(c.expectedSource!) !=
                          canonicalIdentity(source!) ||
                      c.expectedActiveJournalId != active.journal.id)) {
          return null;
        }
        final target = c.kind == 'restore' ? deletedTarget : active;
        final expected = entries(c, mapper, source, target);
        for (final e in expected) {
          final found = state.journals
              .where((j) => j.journal.id == e.journal.id)
              .toList();
          if (found.length != 1 ||
              canonicalIdentity(found.single.toJson()) !=
                  canonicalIdentity(e.toJson()) ||
              !owned.add(e.journal.id) ||
              state.journals.indexOf(found.single) <= journalIndex) {
            return null;
          }
          journalIndex = state.journals.indexOf(found.single);
        }
        if (receipt.outcomePayload != outcome(c, expected).payload) return null;
        if (c.kind == 'delete') {
          deletion = c;
          deletedTarget = active;
          deletedIntent = activeIntent;
        }
        source = c.after(source);
        active = c.kind == 'delete' ? null : expected.last;
        activeIntent = c.kind == 'delete' ? null : c;
        sequence = receipt.sequence;
      }
      if (state.journals.any(
        (j) =>
            ((j.sourceRecordId == id &&
                    (j.sourceType ==
                            RestaurantJournalSourceType.manualDebt.name ||
                        j.metadata['additionalDebt'] == true)) ||
                owned.contains(j.journal.reversesId) ||
                owned.contains(j.correctedFromJournalId) ||
                owned.contains(j.replacementJournalId)) &&
            !owned.contains(j.journal.id),
      )) {
        return null;
      }
      final current = rows(state, id);
      if (source == null
          ? current.isNotEmpty
          : current.length != 1 ||
                canonicalIdentity(current.single) !=
                    canonicalIdentity(source)) {
        return null;
      }
      return (
        active: active,
        deletedTarget: deletedTarget,
        deletion: deletion,
        deletedIntent: deletedIntent,
      );
    } on Object {
      return null;
    }
  }
}

final class AdditionalDebtCoordinator {
  AdditionalDebtCoordinator({
    required this.host,
    RestaurantJournalMapper? mapper,
  }) : mapper = mapper ?? RestaurantJournalMapper();
  final JournalCommandHost host;
  final RestaurantJournalMapper mapper;
  Future<DurableCommandResult<AdditionalDebtOutcome>> execute(
    AdditionalDebtCommand c,
  ) async {
    if (c.acceptedCounterAccountId == null ||
        c.acceptedCounterAccountId!.trim().isEmpty) {
      return Future.value(
        const DurableCommandFailure(
          code: 'unmapped_financial_gap',
          message: 'Additional debt requires an owner-accepted counteraccount.',
        ),
      );
    }
    // Reject a known capacity violation before even a rejection receipt is
    // written. The atomic host proposal repeats this check after its own read.
    // Existing identities bypass preflight so historical replay remains valid.
    try {
      final read = await host.store.readDocument();
      if (read is CapabilitySuccess<DocumentSnapshot?> && read.value != null) {
        final state = const PortableJournalCodec().decodeState(
          read.value!.payload,
        );
        if (read.value!.fence == c.fence &&
            state.accountLineage == c.accountLineage &&
            !state.receipts.any((receipt) => receipt.identity == c.identity)) {
          final proposal = evaluate(c, state);
          if (proposal.rejectionCode ==
              'debt_correction_exceeds_recognized_liability') {
            return const DurableCommandFailure(
              code: 'debt_correction_exceeds_recognized_liability',
              message:
                  'The correction would remove recognized settlement capacity.',
            );
          }
        }
      }
    } on Object {
      // The host owns protected read errors, fencing and unknown outcomes.
    }
    return host.execute(
      identity: c.identity,
      accountLineage: c.accountLineage,
      expectedFence: c.fence,
      parseOutcome: AdditionalDebtOutcome.parse,
      validateReplayOutcome: (payload, state) =>
          AdditionalDebtHistory.validate(state, c.debtId, mapper) != null &&
          state.receipts.any(
            (r) => r.identity == c.identity && r.outcomePayload == payload,
          ),
      evaluateProposal: (state, _) => evaluate(c, state),
    );
  }

  DurableProposalEvaluation<PortableJournalState, AdditionalDebtOutcome>
  evaluate(AdditionalDebtCommand c, PortableJournalState state) {
    DurableProposalEvaluation<PortableJournalState, AdditionalDebtOutcome>
    reject(String code) => DurableProposalEvaluation.reject(
      rejectionCode: code,
      rejectionMessage: 'Additional debt refused.',
    );
    try {
      if (canonicalIdentity(c.context) !=
          canonicalIdentity({
            'profile': paymentProfileIdentity(mapper.profile),
            'policy': paymentPolicyIdentity(mapper.defaultPolicy),
          })) {
        return reject('debt_context_mismatch');
      }
      final cutover = state.cutoverState.cutoverDate!;
      final rows = AdditionalDebtHistory.rows(state, c.debtId);
      Map<String, Object?>? before;
      PortableJournalEntry? active;
      if (c.kind == 'create') {
        if (rows.isNotEmpty ||
            state.journals.any(
              (j) =>
                  j.sourceRecordId == c.debtId &&
                  (j.metadata['additionalDebt'] == true ||
                      j.sourceType ==
                          RestaurantJournalSourceType.manualDebt.name),
            )) {
          return reject('duplicate_debt_id');
        }
      } else if (c.kind == 'restore') {
        final family = AdditionalDebtHistory.validate(state, c.debtId, mapper);
        if (rows.isNotEmpty ||
            family == null ||
            family.active != null ||
            family.deletion == null ||
            family.deletedTarget == null ||
            family.deletedIntent == null ||
            c.restoreOf != family.deletion!.identity.canonicalPayloadIdentity ||
            c.expectedActiveJournalId != family.deletedTarget!.journal.id ||
            c.acceptedCounterAccountId !=
                family.deletedIntent!.acceptedCounterAccountId ||
            canonicalIdentity(c.expectedSource!) !=
                canonicalIdentity(family.deletion!.expectedSource!) ||
            canonicalIdentity(c.sourceOrder!.toJson()) !=
                canonicalIdentity(family.deletion!.sourceOrder!.toJson())) {
          return reject('deleted_debt_family_mismatch');
        }
        active = family.deletedTarget;
      } else {
        if (rows.length != 1 ||
            canonicalIdentity(rows.single) !=
                canonicalIdentity(c.expectedSource!)) {
          return reject('debt_source_changed');
        }
        before = rows.single;
        if ((before['date']! as String).compareTo(cutover.toString()) < 0) {
          return reject('pre_cutover_operation_rejected');
        }
        active = AdditionalDebtHistory.validate(
          state,
          c.debtId,
          mapper,
        )?.active;
        if (active == null || active.journal.id != c.expectedActiveJournalId) {
          return reject('cross_cutover_source_has_no_post_cutover_journal');
        }
      }
      if (c.date != null && c.date!.compareTo(cutover) < 0) {
        return reject('pre_cutover_operation_rejected');
      }
      if (c.kind == 'delete' &&
          c.sourceOrder != null &&
          canonicalIdentity(
                c.sourceOrder!.apply(state.account, 'debts', c.debtId).toJson(),
              ) !=
              canonicalIdentity(state.account.toJson())) {
        return reject('source_order_changed');
      }
      final after = c.after(before);
      final entries = AdditionalDebtHistory.entries(c, mapper, before, active);
      if (entries.any(
        (e) => state.journals.any((j) => j.journal.id == e.journal.id),
      )) {
        return reject('duplicate_journal_id');
      }
      final raw = <String, Object?>{...state.account.toJson()};
      raw['debts'] = [
        for (final row in raw['debts']! as List)
          if (_map(row)['id'] == c.debtId) ...[?after] else row,
        if (c.kind == 'create' || c.kind == 'restore') ?after,
      ];
      if (!AdditionalDebtHistory.preservesSettlements(
        state: state,
        command: c,
        before: before,
        after: after,
        entries: entries,
        mapper: mapper,
      )) {
        return reject('debt_correction_exceeds_recognized_liability');
      }
      var account = const LegacyAccountCodec().decodeJson(raw);
      if (c.kind == 'restore') {
        account = c.sourceOrder!.apply(account, 'debts', c.debtId);
      }
      final outcome = AdditionalDebtHistory.outcome(c, entries);
      return DurableProposalEvaluation.accept(
        candidateState: state.copyWith(
          account: account,
          journals: [...state.journals, ...entries],
        ),
        outcome: outcome,
        outcomePayload: outcome.payload,
      );
    } on RestaurantJournalMappingException catch (e) {
      return reject(e.code);
    } on FormatException catch (e) {
      return reject(e.message);
    } on Object {
      return reject('invalid_debt_proposal');
    }
  }
}

Map<String, Object?> _map(Object? value) =>
    (value! as Map).cast<String, Object?>();
