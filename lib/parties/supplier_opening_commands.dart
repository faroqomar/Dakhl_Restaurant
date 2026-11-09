import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:madar_application/madar_application.dart';
import 'package:madar_domain/madar_domain.dart';

import '../accounts/legacy_account_codec.dart';
import '../accounts/portable_journal_codec.dart';
import '../accounts/portable_journal_state.dart';
import '../accounting/journal_command_host.dart';
import '../accounting/restaurant_journal_mapper.dart';
import '../accounting/restaurant_journal_payment_correction_commands.dart'
    show paymentProfileIdentity, paymentPolicyIdentity;
import '../accounting/restaurant_journal_spending_commands.dart'
    show hasValidSupplierPaymentPosting;
import 'additional_debt_commands.dart';

/// Owner-approved supplier opening revision. It never rewrites the cutover.
final class SupplierOpeningCommand {
  SupplierOpeningCommand({
    required this.operationId,
    required this.accountLineage,
    required this.fence,
    required this.supplierId,
    required this.recordedAt,
    required this.reason,
    required this.cutoverDate,
    required this.baseOpeningJournalId,
    required this.baseOpeningSha256,
    required this.acceptedOpeningEquityAccountId,
    required RestaurantJournalMapper mapper,
    required Map<String, Object?> supplierAfter,
    Map<String, Object?>? supplierBefore,
    this.previousOperationId,
  }) : supplierAfter = freezeMap(supplierAfter),
       supplierBefore = supplierBefore == null
           ? null
           : freezeMap(supplierBefore),
       context = freezeMap({
         'profile': paymentProfileIdentity(mapper.profile),
         'policy': paymentPolicyIdentity(mapper.defaultPolicy),
       }) {
    if ([
          operationId,
          accountLineage,
          supplierId,
          recordedAt,
          baseOpeningJournalId,
        ].any((v) => v.isEmpty || v.trim() != v) ||
        DateTime.tryParse(recordedAt) == null ||
        reason.trim().isEmpty ||
        reason.length > 500 ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(baseOpeningSha256) ||
        this.supplierAfter['id'] != supplierId ||
        (this.supplierBefore != null &&
            this.supplierBefore!['id'] != supplierId) ||
        this.supplierAfter['openingBalance'] is! int ||
        (this.supplierBefore != null &&
            this.supplierBefore!['openingBalance'] is! int)) {
      throw const FormatException('invalid_supplier_opening_intent');
    }
    for (final amount in [beforeAmount, afterAmount]) {
      if (amount.isNegative ||
          amount > RestaurantJournalPolicies.defaultLimit) {
        throw const FormatException('invalid_supplier_opening_amount');
      }
    }
    if (supplierBefore != null && delta == BigInt.zero) {
      throw const FormatException('supplier_opening_unchanged');
    }
    final beforeMaterials = supplierBefore?['materials'] ?? const <Object?>[];
    final afterMaterials = supplierAfter['materials'] ?? const <Object?>[];
    if (jsonEncode(beforeMaterials) != jsonEncode(afterMaterials)) {
      throw const FormatException('supplier_opening_material_change');
    }
  }

  static const commandType = 'supplier_opening_amendment';
  static const sourceType = 'supplierOpeningAmendment';
  final String operationId, accountLineage, supplierId, recordedAt, reason;
  final String baseOpeningJournalId, baseOpeningSha256;
  final String? acceptedOpeningEquityAccountId, previousOperationId;
  final StorageFence fence;
  final DateOnly cutoverDate;
  final Map<String, Object?> supplierAfter, context;
  final Map<String, Object?>? supplierBefore;
  BigInt get beforeAmount =>
      BigInt.from(supplierBefore?['openingBalance'] as int? ?? 0);
  BigInt get afterAmount =>
      BigInt.from(supplierAfter['openingBalance']! as int);
  BigInt get delta => afterAmount - beforeAmount;
  String get journalId => '$operationId:opening-amendment';
  DurableCommandIdentity get identity => DurableCommandIdentity(
    operationId: operationId,
    payloadVersion: 1,
    canonicalPayloadIdentity: canonicalIdentity(toJson()),
  );
  Map<String, Object?> toJson() => {
    'commandType': commandType,
    'operationId': operationId,
    'accountLineage': accountLineage,
    'fence': {'storeId': fence.storeId, 'generation': fence.generation},
    'supplierId': supplierId,
    'recordedAt': recordedAt,
    'reason': reason,
    'cutoverDate': cutoverDate.toString(),
    'baseOpeningJournalId': baseOpeningJournalId,
    'baseOpeningSha256': baseOpeningSha256,
    'acceptedOpeningEquityAccountId': acceptedOpeningEquityAccountId,
    'previousOperationId': previousOperationId,
    'supplierBefore': supplierBefore,
    'supplierAfter': supplierAfter,
    'context': context,
  };
  factory SupplierOpeningCommand.fromIntent(
    Map<String, Object?> i,
    RestaurantJournalMapper mapper,
  ) {
    final f = _map(i['fence']);
    final c = SupplierOpeningCommand(
      operationId: i['operationId']! as String,
      accountLineage: i['accountLineage']! as String,
      fence: StorageFence(
        storeId: f['storeId']! as String,
        generation: f['generation']! as String,
      ),
      supplierId: i['supplierId']! as String,
      recordedAt: i['recordedAt']! as String,
      reason: i['reason']! as String,
      cutoverDate: DateOnly.parse(
        i['cutoverDate']! as String,
        minimumYear: 1000,
        maximumYear: 9999,
      ),
      baseOpeningJournalId: i['baseOpeningJournalId']! as String,
      baseOpeningSha256: i['baseOpeningSha256']! as String,
      acceptedOpeningEquityAccountId:
          i['acceptedOpeningEquityAccountId'] as String?,
      previousOperationId: i['previousOperationId'] as String?,
      supplierBefore: i['supplierBefore'] == null
          ? null
          : _map(i['supplierBefore']),
      supplierAfter: _map(i['supplierAfter']),
      mapper: mapper,
    );
    if (canonicalIdentity(c.toJson()) != canonicalIdentity(i)) {
      throw const FormatException('supplier_opening_context_mismatch');
    }
    return c;
  }
}

final class SupplierOpeningOutcome {
  SupplierOpeningOutcome(Map<String, Object?> value)
    : values = freezeMap(value);
  final Map<String, Object?> values;
  String get payload => canonicalIdentity(values);
  factory SupplierOpeningOutcome.parse(String payload) =>
      SupplierOpeningOutcome(_map(jsonDecode(payload)));
}

abstract final class SupplierOpeningHistory {
  static List<Map<String, Object?>> suppliers(
    PortableJournalState s,
    String id,
  ) => (s.account.toJson()['suppliers']! as List)
      .map(_map)
      .where((r) => r['id'] == id)
      .toList();
  static String openingHash(PortableJournalEntry entry) =>
      sha256.convert(utf8.encode(canonicalIdentity(entry.toJson()))).toString();
  static PortableJournalEntry baseOpening(PortableJournalState s) {
    final matches = s.journals
        .where((j) => j.journal.id == s.cutoverState.openingJournalId)
        .toList();
    if (s.cutoverState.isGated ||
        !s.cutoverState.hasActivePosting ||
        matches.length != 1 ||
        matches.single.journal.effectiveDate != s.cutoverState.cutoverDate ||
        matches.single.sourceType !=
            RestaurantJournalSourceType.cutoverOpening.name ||
        s.journals.any(
          (j) => j.journal.reversesId == matches.single.journal.id,
        )) {
      throw const FormatException('unverified_supplier_opening');
    }
    return matches.single;
  }

  static BigInt liability(
    PortableJournalEntry e,
    String id,
    RestaurantJournalMapper mapper,
  ) => AdditionalDebtHistory.liability(e, id, mapper);

  static List<PortableJournalEntry> entries(
    SupplierOpeningCommand c,
    RestaurantJournalMapper mapper,
  ) {
    if (c.delta == BigInt.zero) return const [];
    final amount = c.delta.abs();
    final liabilityId = mapper.profile.supplierLiabilityAccountId(c.supplierId);
    if (c.acceptedOpeningEquityAccountId == null ||
        c.acceptedOpeningEquityAccountId !=
            mapper.profile.openingEquityAccountId ||
        c.acceptedOpeningEquityAccountId == liabilityId) {
      throw const FormatException('unmapped_supplier_opening_equity');
    }
    final journal = BalancedJournal.validate(
      id: c.journalId,
      effectiveDate: c.cutoverDate,
      policy: mapper.defaultPolicy,
      lines: [
        JournalLine(
          accountId: liabilityId,
          side: c.delta.isNegative ? JournalSide.debit : JournalSide.credit,
          amountUnits: amount,
          currency: mapper.defaultPolicy.currency,
          scale: mapper.defaultPolicy.scale,
        ),
        JournalLine(
          accountId: c.acceptedOpeningEquityAccountId!,
          side: c.delta.isNegative ? JournalSide.credit : JournalSide.debit,
          amountUnits: amount,
          currency: mapper.defaultPolicy.currency,
          scale: mapper.defaultPolicy.scale,
        ),
      ],
    );
    return [
      PortableJournalEntry(
        journal: journal,
        sourceType: SupplierOpeningCommand.sourceType,
        sourceRecordId: c.supplierId,
        recordedAt: c.recordedAt,
        metadata: {
          'operationId': c.operationId,
          'baseOpeningJournalId': c.baseOpeningJournalId,
          'baseOpeningSha256': c.baseOpeningSha256,
          'previousOperationId': c.previousOperationId,
          'beforeOpening': c.beforeAmount.toString(),
          'afterOpening': c.afterAmount.toString(),
          'reason': c.reason.trim(),
        },
      ),
    ];
  }

  static SupplierOpeningOutcome outcome(
    SupplierOpeningCommand c,
    List<PortableJournalEntry> entries,
  ) => SupplierOpeningOutcome({
    'supplierId': c.supplierId,
    'operationId': c.operationId,
    'beforeOpening': c.beforeAmount.toString(),
    'afterOpening': c.afterAmount.toString(),
    'journalIds': entries.map((e) => e.journal.id).toList(),
  });

  /// Full receipt/journal chain, independent of mutable supplier name/phone.
  static ({BigInt amendment, String? lastOperationId}) validate(
    PortableJournalState s,
    String id,
    RestaurantJournalMapper mapper,
  ) {
    final base = baseOpening(s);
    final receipts = <DurableCommandReceipt>[];
    for (final r in s.receipts.where(
      (r) => r.status == DurableCommandStatus.committed,
    )) {
      try {
        final intent = _map(jsonDecode(r.identity.canonicalPayloadIdentity));
        if (intent['commandType'] == SupplierOpeningCommand.commandType &&
            intent['supplierId'] == id) {
          receipts.add(r);
        }
      } on Object {
        if (r.identity.canonicalPayloadIdentity.contains(
          SupplierOpeningCommand.commandType,
        )) {
          throw const FormatException('invalid_supplier_opening_history');
        }
      }
    }
    receipts.sort((a, b) => a.sequence.compareTo(b.sequence));
    if (receipts.isNotEmpty &&
        !s.requiredFeatures.contains(
          PortableJournalState.supplierOpeningFeature,
        )) {
      throw const FormatException('missing_required_feature');
    }
    BigInt amendment = BigInt.zero;
    BigInt? priorAmount;
    String? priorOperation;
    var priorSequence = 0, lastJournalIndex = s.journals.indexOf(base);
    final owned = <String>{};
    for (final r in receipts) {
      try {
        final c = SupplierOpeningCommand.fromIntent(
          _map(jsonDecode(r.identity.canonicalPayloadIdentity)),
          mapper,
        );
        if (c.identity != r.identity ||
            c.fence != r.fence ||
            c.accountLineage != s.accountLineage ||
            r.sequence <= priorSequence ||
            c.cutoverDate != s.cutoverState.cutoverDate ||
            c.baseOpeningJournalId != base.journal.id ||
            c.baseOpeningSha256 != openingHash(base) ||
            c.acceptedOpeningEquityAccountId !=
                mapper.profile.openingEquityAccountId ||
            c.previousOperationId != priorOperation ||
            (priorAmount != null && c.beforeAmount != priorAmount) ||
            (priorOperation != null && c.supplierBefore == null) ||
            (c.supplierBefore == null &&
                liability(base, id, mapper) != BigInt.zero)) {
          throw const FormatException('invalid_supplier_opening_history');
        }
        final expected = entries(c, mapper);
        for (final entry in expected) {
          final found = s.journals
              .where((j) => j.journal.id == entry.journal.id)
              .toList();
          if (found.length != 1 ||
              canonicalIdentity(found.single.toJson()) !=
                  canonicalIdentity(entry.toJson()) ||
              !owned.add(entry.journal.id) ||
              s.journals.indexOf(found.single) <= lastJournalIndex) {
            throw const FormatException('invalid_supplier_opening_history');
          }
          lastJournalIndex = s.journals.indexOf(found.single);
        }
        if (r.outcomePayload != outcome(c, expected).payload) {
          throw const FormatException('invalid_supplier_opening_history');
        }
        amendment += c.delta;
        priorAmount = c.afterAmount;
        priorOperation = c.operationId;
        priorSequence = r.sequence;
      } on Object {
        throw const FormatException('invalid_supplier_opening_history');
      }
    }
    if (s.journals.any(
      (j) =>
          (j.sourceType == SupplierOpeningCommand.sourceType &&
              j.sourceRecordId == id &&
              !owned.contains(j.journal.id)) ||
          owned.contains(j.journal.reversesId) ||
          owned.contains(j.correctedFromJournalId) ||
          owned.contains(j.replacementJournalId),
    )) {
      throw const FormatException('invalid_supplier_opening_history');
    }
    if (priorAmount != null) {
      final rows = suppliers(s, id);
      if (rows.length != 1 ||
          BigInt.from(rows.single['openingBalance']! as int) != priorAmount) {
        throw const FormatException('invalid_supplier_opening_history');
      }
    }
    return (amendment: amendment, lastOperationId: priorOperation);
  }

  static BigInt recognizedOpening(
    PortableJournalState s,
    String id,
    RestaurantJournalMapper mapper,
  ) {
    final family = validate(s, id, mapper);
    return ExactMath.checkedSum(
      [liability(baseOpening(s), id, mapper), family.amendment],
      maxAbs: RestaurantJournalPolicies.maximumSafeAggregate,
      maxSafeInteger: RestaurantJournalPolicies.maximumSafeAggregate,
    );
  }

  static bool preservesSettlements(
    PortableJournalState s,
    SupplierOpeningCommand c,
    RestaurantJournalMapper mapper,
  ) {
    final cutover = s.cutoverState.cutoverDate!.toString();
    final raw = s.account.toJson();
    final payments = (raw['payments']! as List)
        .map(_map)
        .where(
          (p) =>
              p['supplierId'] == c.supplierId &&
              (p['date']! as String).compareTo(cutover) >= 0 &&
              (p['debtAmount']! as int) > 0,
        )
        .toList();
    if (payments.any((p) => !hasValidSupplierPaymentPosting(s, p, mapper))) {
      return false;
    }
    final credits = <({String date, BigInt amount})>[];
    for (final debt in (raw['debts']! as List).map(_map)) {
      if (debt['supplierId'] != c.supplierId ||
          (debt['date']! as String).compareTo(cutover) < 0) {
        continue;
      }
      final active = AdditionalDebtHistory.validate(
        s,
        debt['id']! as String,
        mapper,
      )?.active;
      if (active != null) {
        credits.add((
          date: debt['date']! as String,
          amount: liability(active, c.supplierId, mapper),
        ));
      }
    }
    BigInt bounded(Iterable<BigInt> values) => ExactMath.checkedSum(
      values,
      maxAbs: RestaurantJournalPolicies.maximumSafeAggregate,
      maxSafeInteger: RestaurantJournalPolicies.maximumSafeAggregate,
    );
    final opening = bounded([
      recognizedOpening(s, c.supplierId, mapper),
      c.delta,
    ]);
    if (opening.isNegative) return false;
    for (final date in payments.map((p) => p['date']! as String).toSet()) {
      final available = bounded([
        opening,
        ...credits
            .where((x) => x.date.compareTo(date) <= 0)
            .map((x) => x.amount),
        ...payments
            .where((p) => (p['date']! as String).compareTo(date) <= 0)
            .map((p) => -BigInt.from(p['debtAmount']! as int)),
      ]);
      if (available.isNegative) return false;
    }
    return true;
  }
}

final class SupplierOpeningCoordinator {
  SupplierOpeningCoordinator({
    required this.host,
    RestaurantJournalMapper? mapper,
  }) : mapper = mapper ?? RestaurantJournalMapper();
  final JournalCommandHost host;
  final RestaurantJournalMapper mapper;
  Future<DurableCommandResult<SupplierOpeningOutcome>> execute(
    SupplierOpeningCommand c,
  ) async {
    if (c.acceptedOpeningEquityAccountId !=
        mapper.profile.openingEquityAccountId) {
      return const DurableCommandFailure(
        code: 'unmapped_supplier_opening_equity',
        message: 'Accept an opening-equity mapping first.',
      );
    }
    try {
      final read = await host.store.readDocument();
      if (read is CapabilitySuccess<DocumentSnapshot?> &&
          read.value != null &&
          read.value!.fence == c.fence) {
        final state = const PortableJournalCodec().decodeState(
          read.value!.payload,
        );
        if (state.accountLineage == c.accountLineage &&
            !state.receipts.any((r) => r.identity == c.identity)) {
          final proposal = evaluate(c, state);
          if (proposal.rejectionCode ==
              'supplier_opening_underfunds_settlement') {
            return const DurableCommandFailure(
              code: 'supplier_opening_underfunds_settlement',
              message: 'Retained settlements require this liability.',
            );
          }
        }
      }
    } on Object {
      // The durable host owns failed/uncertain reads and fenced publication.
    }
    return host.execute(
      identity: c.identity,
      accountLineage: c.accountLineage,
      expectedFence: c.fence,
      parseOutcome: SupplierOpeningOutcome.parse,
      validateReplayOutcome: (payload, state) {
        try {
          SupplierOpeningHistory.validate(state, c.supplierId, mapper);
          return state.receipts.any(
            (r) => r.identity == c.identity && r.outcomePayload == payload,
          );
        } on Object {
          return false;
        }
      },
      evaluateProposal: (state, _) => evaluate(c, state),
    );
  }

  DurableProposalEvaluation<PortableJournalState, SupplierOpeningOutcome>
  evaluate(SupplierOpeningCommand c, PortableJournalState state) {
    DurableProposalEvaluation<PortableJournalState, SupplierOpeningOutcome>
    reject(String code) => DurableProposalEvaluation.reject(
      rejectionCode: code,
      rejectionMessage: 'Supplier opening refused.',
    );
    try {
      final base = SupplierOpeningHistory.baseOpening(state);
      if (canonicalIdentity(c.context) !=
              canonicalIdentity({
                'profile': paymentProfileIdentity(mapper.profile),
                'policy': paymentPolicyIdentity(mapper.defaultPolicy),
              }) ||
          c.cutoverDate != state.cutoverState.cutoverDate ||
          c.baseOpeningJournalId != base.journal.id ||
          c.baseOpeningSha256 != SupplierOpeningHistory.openingHash(base)) {
        return reject('supplier_opening_context_mismatch');
      }
      final rows = SupplierOpeningHistory.suppliers(state, c.supplierId);
      if (c.supplierBefore == null
          ? rows.isNotEmpty ||
                SupplierOpeningHistory.liability(base, c.supplierId, mapper) !=
                    BigInt.zero
          : rows.length != 1 ||
                canonicalIdentity(rows.single) !=
                    canonicalIdentity(c.supplierBefore!)) {
        return reject('supplier_opening_source_changed');
      }
      final history = SupplierOpeningHistory.validate(
        state,
        c.supplierId,
        mapper,
      );
      if (history.lastOperationId != c.previousOperationId) {
        return reject('supplier_opening_history_changed');
      }
      if (!SupplierOpeningHistory.preservesSettlements(state, c, mapper)) {
        return reject('supplier_opening_underfunds_settlement');
      }
      final entries = SupplierOpeningHistory.entries(c, mapper);
      if (entries.any(
        (e) => state.journals.any((j) => j.journal.id == e.journal.id),
      )) {
        return reject('duplicate_journal_id');
      }
      final raw = <String, Object?>{...state.account.toJson()};
      raw['suppliers'] = [
        for (final row in raw['suppliers']! as List)
          if (_map(row)['id'] == c.supplierId) c.supplierAfter else row,
        if (c.supplierBefore == null) c.supplierAfter,
      ];
      final account = const LegacyAccountCodec().decodeJson(raw);
      final outcome = SupplierOpeningHistory.outcome(c, entries);
      return DurableProposalEvaluation.accept(
        candidateState: state.copyWith(
          account: account,
          journals: [...state.journals, ...entries],
          requiredFeatures: {
            ...state.requiredFeatures,
            PortableJournalState.supplierOpeningFeature,
          },
        ),
        outcome: outcome,
        outcomePayload: outcome.payload,
      );
    } on FormatException catch (e) {
      return reject(e.message);
    } on Object {
      return reject('invalid_supplier_opening_proposal');
    }
  }
}

Map<String, Object?> _map(Object? value) =>
    (value! as Map).cast<String, Object?>();
