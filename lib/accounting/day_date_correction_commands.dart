import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:madar_application/madar_application.dart';
import 'package:madar_domain/madar_domain.dart';

import '../accounts/legacy_account_codec.dart';
import '../accounts/portable_journal_state.dart';
import 'correction_batch_receipts.dart';
import 'day_date_plan.dart';
import 'journal_command_host.dart';
import 'restaurant_journal_expense_correction_commands.dart';
import 'restaurant_journal_external_cash_commands.dart';
import 'restaurant_journal_expense_history.dart';
import 'restaurant_journal_mapper.dart';
import 'restaurant_journal_payment_correction_commands.dart';
import 'restaurant_journal_payment_history.dart';
import 'restaurant_journal_transfer_correction_commands.dart';
import 'restaurant_journal_transfer_history.dart';

DateOnly _date(String value) =>
    DateOnly.parse(value, minimumYear: 1000, maximumYear: 9999);
String _digest(PortableJournalState state) =>
    sha256.convert(utf8.encode(canonicalIdentity(state.toJson()))).toString();

final class DayDateCorrectionCommand {
  DayDateCorrectionCommand.fromIntent(Map<String, Object?> value)
    : intent = freezeMap(value) {
    if (intent['commandType'] != 'day_date_correction' ||
        intent['payloadVersion'] != 1 ||
        (intent['reason']! as String).trim().isEmpty) {
      throw const FormatException('invalid_day_date_intent');
    }
    const keys = {
      'commandType',
      'operationId',
      'payloadVersion',
      'accountLineage',
      'expectedFence',
      'expectedRevision',
      'expectedStateDigest',
      'expectedAccount',
      'from',
      'to',
      'end',
      'reason',
      'recordedAt',
      'profile',
      'mapperDefaultPolicy',
      'children',
    };
    if (intent.length !=
            keys.length + (intent.containsKey('inverseOf') ? 2 : 0) ||
        intent.containsKey('inverseOf') != intent.containsKey('exactMapping') ||
        !intent.keys.toSet().containsAll(keys) ||
        intent['expectedRevision'] is! int ||
        (intent['expectedRevision']! as int) < 0 ||
        !RegExp(r'^[a-f0-9]{64}$')
            .hasMatch(intent['expectedStateDigest']! as String)) {
      throw const FormatException('invalid_day_date_intent');
    }
    for (final key in ['operationId', 'accountLineage', 'recordedAt']) {
      final value = intent[key]! as String;
      if (value.isEmpty || value.trim() != value) {
        throw const FormatException('invalid_day_date_identity');
      }
    }
    final stamp = intent['recordedAt']! as String;
    if (!stamp.endsWith('Z') || DateTime.tryParse(stamp) == null) {
      throw const FormatException('invalid_day_date_timestamp');
    }
    canonicalPayloadIdentity = canonicalIdentity(intent);
  }
  factory DayDateCorrectionCommand.capture({
    required PortableJournalState state,
    required StorageFence fence,
    required int expectedRevision,
    required String operationId,
    required String from,
    required String to,
    String? end,
    required String reason,
    required String recordedAt,
    RestaurantJournalMapper? mapper,
    String? acceptedCounterAccountId,
    DurableCommandIdentity? inverseOf,
  }) {
    final m = mapper ?? RestaurantJournalMapper();
    Map<String, String>? exactMapping;
    if (inverseOf != null) {
      final receipt = state.receipts.singleWhere(
        (r) =>
            r.identity == inverseOf &&
            r.status == DurableCommandStatus.committed,
      );
      final output = (jsonDecode(receipt.outcomePayload!) as Map)
          .cast<String, Object?>();
      exactMapping = {
        for (final e
            in (output['mapping']! as Map).cast<String, String>().entries)
          e.value: e.key,
      };
    }
    final planIntent = <String, Object?>{
      'from': from,
      'to': to,
      'end': end ?? from,
      'expectedAccount': state.account.toJson(),
      'operationId': operationId,
      'reason': reason,
      'recordedAt': recordedAt,
      if (inverseOf != null)
        'inverseOf': {
          'operationId': inverseOf.operationId,
          'payloadVersion': inverseOf.payloadVersion,
          'canonicalPayloadIdentity': inverseOf.canonicalPayloadIdentity,
        },
      'exactMapping': ?exactMapping,
    };
    if (inverseOf != null) {
      validateDayDateInverseBinding(
        state,
        planIntent,
        parentSequence: state.receipts.length + 1,
      );
    }
    final plan = DayDatePlan.forIntent(state.account, planIntent);
    final after = applyDayDateIntent(state.account, planIntent);
    final children = <Map<String, Object?>>[];
    var index = 0;
    String next() => '$operationId-child-${index++}';
    final json = state.account.toJson();
    for (final row
        in (json['transactions']! as List).cast<Map<String, Object?>>()) {
      final targetDate = plan.mapping[row['date']];
      if (targetDate == null) continue;
      if (acceptedCounterAccountId == null) {
        throw const FormatException('unmapped_financial_gap');
      }
      final id = row['id']! as String,
          child = next(),
          target = _active(state, id, 'cash', m);
      final prior = correctionReceiptViews(state).singleWhere(
        (r) => r.identity.operationId == target.metadata['operationId'],
      );
      final priorIntent =
          jsonDecode(prior.identity.canonicalPayloadIdentity) as Map;
      if (priorIntent['acceptedCounterAccountId'] != acceptedCounterAccountId) {
        throw const FormatException('cash_mapping_changed');
      }
      final command = ExternalCashCommand.edit(
        operationId: child,
        accountLineage: state.accountLineage,
        expectedFence: fence,
        transactionId: id,
        journalId: '$child-replacement',
        inverseJournalId: '$child-inverse',
        expectedActiveJournalId: target.journal.id,
        expectedSource: row,
        reason: reason,
        recordedAt: recordedAt,
        acceptedCounterAccountId: acceptedCounterAccountId,
        mapper: m,
        date: _date(targetDate),
        amount: BigInt.from(row['amount']! as int),
        type: row['type']! as String,
        note: row['note']! as String,
      );
      if (canonicalIdentity(command.sourceAfter(row)!) !=
          canonicalIdentity({...row, 'date': targetDate})) {
        throw const FormatException('day_shift_source_normalization');
      }
      children.add(command.toJson());
    }
    for (final day in (json['days']! as Map).entries) {
      final targetDate = plan.mapping[day.key];
      if (targetDate == null) continue;
      for (final row
          in ((day.value as Map)['expenses']! as List)
              .cast<Map<String, Object?>>()) {
        final id = row['id']! as String;
        final target = _active(state, id, 'expense', m);
        final child = next();
        final funding =
            row['funding'] as Map? ??
            {'source': 'daily', 'dailyAmount': row['amount'], 'cashAmount': 0};
        final command = EditOperatingExpenseCommand(
          operationId: child,
          accountLineage: state.accountLineage,
          expectedFence: fence,
          expenseId: id,
          expectedActiveJournalId: target.journal.id,
          inverseJournalId: '$child-inverse',
          replacementJournalId: '$child-replacement',
          date: _date(targetDate),
          categoryId: row['categoryId']! as String,
          amount: BigInt.from(row['amount']! as int),
          fundingSource: FundingSource.values.byName(
            funding['source']! as String,
          ),
          dailyAmount: BigInt.from(funding['dailyAmount']! as int),
          cashAmount: BigInt.from(funding['cashAmount']! as int),
          note: row['note']! as String,
          reason: reason,
          recordedAt: recordedAt,
          profile: m.profile,
          policy: target.journal.policy,
          mapperDefaultPolicy: m.defaultPolicy,
        );
        if (canonicalIdentity(
              RestaurantJournalExpenseHistory.replacementSource(command, {
                'date': day.key,
                'expense': row,
              }),
            ) !=
            canonicalIdentity(row)) {
          throw const FormatException('day_shift_source_normalization');
        }
        children.add(
          (jsonDecode(command.canonicalPayloadIdentity) as Map)
              .cast<String, Object?>(),
        );
      }
    }
    for (final row
        in (json['payments']! as List).cast<Map<String, Object?>>()) {
      final targetDate = plan.mapping[row['date']];
      if (targetDate == null) continue;
      final id = row['id']! as String, child = next();
      final target = _active(state, id, 'payment', m),
          funding = row['funding']! as Map;
      final command = EditSupplierPaymentCommand(
        operationId: child,
        accountLineage: state.accountLineage,
        expectedFence: fence,
        paymentId: id,
        expectedSource: row,
        expectedActiveJournalId: target.journal.id,
        inverseJournalId: '$child-inverse',
        replacementJournalId: '$child-replacement',
        date: _date(targetDate),
        categoryId: row['categoryId']! as String,
        supplierId: row['supplierId']! as String,
        invoiceId: row['invoiceId'] as String?,
        invoiceAmount: BigInt.from(row['invoiceAmount']! as int),
        debtAmount: BigInt.from(row['debtAmount']! as int),
        amount: BigInt.from(row['amount']! as int),
        fundingSource: FundingSource.values.byName(
          funding['source']! as String,
        ),
        dailyAmount: BigInt.from(funding['dailyAmount']! as int),
        cashAmount: BigInt.from(funding['cashAmount']! as int),
        note: row['note']! as String,
        reason: reason,
        recordedAt: recordedAt,
        profile: m.profile,
        policy: target.journal.policy,
        mapperDefaultPolicy: m.defaultPolicy,
      );
      final expected = {...row, 'date': targetDate};
      if (canonicalIdentity(
            RestaurantJournalPaymentHistory.replacementSource(command, row),
          ) !=
          canonicalIdentity(expected)) {
        throw const FormatException('day_shift_source_normalization');
      }
      children.add(
        (jsonDecode(command.canonicalPayloadIdentity) as Map)
            .cast<String, Object?>(),
      );
    }
    for (final row
        in (json['transfers']! as List).cast<Map<String, Object?>>()) {
      final targetDate = plan.mapping[row['date']];
      if (targetDate == null) continue;
      final id = row['id']! as String,
          child = next(),
          target = _active(state, id, 'transfer', m);
      final command = EditDailyTransferCommand(
        operationId: child,
        accountLineage: state.accountLineage,
        expectedFence: fence,
        transferId: id,
        expectedActiveJournalId: target.journal.id,
        inverseJournalId: '$child-inverse',
        replacementJournalId: '$child-replacement',
        newAmount: BigInt.from(row['amount']! as int),
        newDate: _date(targetDate),
        reason: reason,
        recordedAt: recordedAt,
        policy: target.journal.policy,
      );
      children.add(
        (jsonDecode(command.canonicalPayloadIdentity) as Map)
            .cast<String, Object?>(),
      );
    }
    // The complete source validator, rather than a loop of per-record commits,
    // checks invoice/debt timelines after every date has moved together.
    after.toJson();
    return DayDateCorrectionCommand.fromIntent({
      'commandType': 'day_date_correction',
      'operationId': operationId,
      'payloadVersion': 1,
      'accountLineage': state.accountLineage,
      'expectedFence': {
        'storeId': fence.storeId,
        'generation': fence.generation,
      },
      'expectedRevision': expectedRevision,
      'expectedStateDigest': _digest(state),
      'expectedAccount': json,
      'from': from,
      'to': to,
      'end': end ?? from,
      'reason': reason,
      'recordedAt': recordedAt,
      'profile': expenseProfileIdentity(m.profile),
      'mapperDefaultPolicy': expensePolicyIdentity(m.defaultPolicy),
      'children': children,
      if (inverseOf != null) 'inverseOf': planIntent['inverseOf'],
      'exactMapping': ?exactMapping,
    });
  }
  final Map<String, Object?> intent;
  late final String canonicalPayloadIdentity;
  String get operationId => intent['operationId']! as String;
  String get accountLineage => intent['accountLineage']! as String;
  StorageFence get fence {
    final f = intent['expectedFence']! as Map;
    return StorageFence(
      storeId: f['storeId']! as String,
      generation: f['generation']! as String,
    );
  }

  DurableCommandIdentity get identity => DurableCommandIdentity(
    operationId: operationId,
    payloadVersion: 1,
    canonicalPayloadIdentity: canonicalPayloadIdentity,
  );
}

PortableJournalEntry _active(
  PortableJournalState state,
  String id,
  String family,
  RestaurantJournalMapper mapper,
) {
  if (family == 'cash') {
    final active = RestaurantJournalExternalCashHistory.activePosting(
      state,
      id,
      mapper,
    );
    if (active == null) {
      throw const FormatException('missing_or_invalid_original_posting_cash');
    }
    return active;
  }
  final valid = switch (family) {
    'expense' => RestaurantJournalExpenseHistory.validate(
      state: state,
      expenseId: id,
      mapper: mapper,
    ),
    'payment' => RestaurantJournalPaymentHistory.validate(
      state: state,
      paymentId: id,
      mapper: mapper,
    ),
    _ => RestaurantJournalTransferHistory.validateTransferLineage(
      state: state,
      transferId: id,
      mapper: mapper,
    ),
  };
  if (!valid) {
    throw FormatException('missing_or_invalid_original_posting_$family');
  }
  final candidates = state.journals
      .where(
        (j) =>
            j.sourceRecordId == id &&
            !state.journals.any((r) => r.journal.reversesId == j.journal.id) &&
            (j.sourceType ==
                    switch (family) {
                      'expense' => RestaurantJournalSourceType.expense.name,
                      'payment' =>
                        RestaurantJournalSourceType.supplierPayment.name,
                      _ => RestaurantJournalSourceType.cashboxTransfer.name,
                    } ||
                j.sourceType ==
                    RestaurantJournalSourceType.correctionReplacement.name),
      )
      .toList();
  if (candidates.length != 1) {
    throw const FormatException('ambiguous_active_posting');
  }
  return candidates.single;
}

final class DayDateCorrectionOutcome {
  DayDateCorrectionOutcome(Map<String, Object?> values)
    : values = freezeMap(values);
  final Map<String, Object?> values;
  String toOutcomePayload() => canonicalIdentity(values);
  factory DayDateCorrectionOutcome.fromOutcomePayload(String value) =>
      DayDateCorrectionOutcome(
        (jsonDecode(value) as Map).cast<String, Object?>(),
      );
}

final class DayDateCorrectionCoordinator {
  DayDateCorrectionCoordinator({
    required this.host,
    RestaurantJournalMapper? mapper,
  }) : mapper = mapper ?? RestaurantJournalMapper();
  final JournalCommandHost host;
  final RestaurantJournalMapper mapper;
  Future<DurableCommandResult<DayDateCorrectionOutcome>> execute(
    DayDateCorrectionCommand command,
  ) => host.execute(
    identity: command.identity,
    accountLineage: command.accountLineage,
    expectedFence: command.fence,
    expectedRevision: command.intent['expectedRevision']! as int,
    parseOutcome: DayDateCorrectionOutcome.fromOutcomePayload,
    validateReplayOutcome: (payload, state) {
      try {
        final receipt = state.receipts.singleWhere(
          (r) =>
              r.identity == command.identity &&
              r.status == DurableCommandStatus.committed,
        );
        final output = DayDateCorrectionOutcome.fromOutcomePayload(payload);
        validateDayDateBatchEnvelope(
          state,
          receipt,
          command.intent,
          output.values,
        );
        final rebuilt = _materialize(command, state, validateActive: false);
        if (canonicalIdentity(rebuilt.$2.values) !=
            canonicalIdentity(output.values)) {
          return false;
        }
        _validateFamilies(command, state);
        return true;
      } on Object {
        return false;
      }
    },
    evaluateProposal: (state, fence) {
      try {
        if (_digest(state) != command.intent['expectedStateDigest']) {
          throw const FormatException('day_shift_source_changed');
        }
        if (canonicalIdentity(state.account.toJson()) !=
            canonicalIdentity(
              (command.intent['expectedAccount']! as Map)
                  .cast<String, Object?>(),
            )) {
          throw const FormatException('day_shift_source_changed');
        }
        final result = _materialize(command, state, validateActive: true);
        final outcome = result.$2;
        final view = DurableCommandReceipt(
          identity: command.identity,
          status: DurableCommandStatus.committed,
          outcomePayload: outcome.toOutcomePayload(),
          committedRevision: (command.intent['expectedRevision']! as int) + 1,
          fence: fence,
          sequence: state.receipts.length + 1,
        );
        _validateFamilies(
          command,
          result.$1.copyWith(receipts: [...state.receipts, view]),
        );
        return DurableProposalEvaluation.accept(
          candidateState: result.$1,
          outcome: outcome,
          outcomePayload: outcome.toOutcomePayload(),
        );
      } on FormatException catch (e) {
        return DurableProposalEvaluation.reject(
          rejectionCode: e.message.toString(),
          rejectionMessage: 'Day-date correction refused.',
        );
      } on Object {
        return const DurableProposalEvaluation.reject(
          rejectionCode: 'invalid_day_date_batch',
          rejectionMessage: 'Day-date correction refused.',
        );
      }
    },
  );
  void _validateFamilies(
    DayDateCorrectionCommand command,
    PortableJournalState state,
  ) {
    for (final raw in command.intent['children']! as List) {
      final c = raw as Map;
      final family = c['commandType'] == 'edit_operating_expense'
          ? 'expense'
          : c['commandType'] == 'edit_supplier_payment'
          ? 'payment'
          : c['commandType'] == 'external_cash_edit'
          ? 'cash'
          : 'transfer';
      _active(
        state,
        c[family == 'expense'
                ? 'expenseId'
                : family == 'payment'
                ? 'paymentId'
                : family == 'cash'
                ? 'transactionId'
                : 'transferId']!
            as String,
        family,
        mapper,
      );
    }
  }

  (PortableJournalState, DayDateCorrectionOutcome) _materialize(
    DayDateCorrectionCommand command,
    PortableJournalState state, {
    required bool validateActive,
  }) {
    final before = const LegacyAccountCodec().decodeJson(
      (command.intent['expectedAccount']! as Map).cast<String, Object?>(),
    );
    if (command.intent['inverseOf'] != null) {
      final existing = state.receipts.where(
        (r) => r.identity == command.identity,
      );
      validateDayDateInverseBinding(
        state,
        command.intent,
        parentSequence: existing.isEmpty
            ? state.receipts.length + 1
            : existing.single.sequence,
      );
    }
    final plan = DayDatePlan.forIntent(before, command.intent);
    final coverage = <String, String>{};
    final beforeJson = before.toJson();
    for (final row
        in (beforeJson['transactions']! as List).cast<Map<String, Object?>>()) {
      final destination = plan.mapping[row['date']];
      if (destination != null) {
        coverage['external_cash_edit:${row['id']}'] = destination;
      }
    }
    for (final day in (beforeJson['days']! as Map).entries) {
      final destination = plan.mapping[day.key];
      if (destination != null) {
        for (final row
            in ((day.value as Map)['expenses']! as List)
                .cast<Map<String, Object?>>()) {
          coverage['edit_operating_expense:${row['id']}'] = destination;
        }
      }
    }
    for (final key in ['payments', 'transfers']) {
      for (final row
          in (beforeJson[key]! as List).cast<Map<String, Object?>>()) {
        final destination = plan.mapping[row['date']];
        if (destination != null) {
          coverage['${key == 'payments' ? 'edit_supplier_payment' : 'edit_daily_transfer'}:${row['id']}'] =
              destination;
        }
      }
    }
    for (final raw in command.intent['children']! as List) {
      final c = raw as Map, type = c['commandType'];
      final id =
          c[type == 'edit_operating_expense'
              ? 'expenseId'
              : type == 'edit_supplier_payment'
              ? 'paymentId'
              : type == 'external_cash_edit'
              ? 'transactionId'
              : 'transferId'];
      if (coverage.remove('$type:$id') != (c['date'] ?? c['newDate'])) {
        throw const FormatException('invalid_day_shift_coverage');
      }
    }
    if (coverage.isNotEmpty) {
      throw const FormatException('incomplete_day_shift_coverage');
    }
    final after = applyDayDateIntent(before, command.intent),
        entries = <PortableJournalEntry>[],
        children = <Map<String, Object?>>[];
    if (canonicalIdentity(expenseProfileIdentity(mapper.profile)) !=
            canonicalIdentity(
              (command.intent['profile']! as Map).cast<String, Object?>(),
            ) ||
        canonicalIdentity(expensePolicyIdentity(mapper.defaultPolicy)) !=
            canonicalIdentity(
              (command.intent['mapperDefaultPolicy']! as Map)
                  .cast<String, Object?>(),
            )) {
      throw const FormatException('mapper_context_mismatch');
    }
    for (final raw in command.intent['children']! as List) {
      final ci = (raw as Map).cast<String, Object?>(), type = ci['commandType'];
      final target = state.journals.singleWhere(
        (j) => j.journal.id == ci['expectedActiveJournalId'],
      );
      final cutover = state.cutoverState.cutoverDate!;
      final destination = _date((ci['date'] ?? ci['newDate'])! as String);
      if (target.journal.effectiveDate.compareTo(cutover) < 0 ||
          destination.compareTo(cutover) < 0) {
        throw const FormatException('pre_cutover_operation_rejected');
      }
      late final List<PortableJournalEntry> mapped;
      late final Map<String, Object?> output;
      if (type == 'edit_operating_expense') {
        final c = RestaurantJournalExpenseHistory.commandFromIntent(
          ci,
        ) as EditOperatingExpenseCommand;
        if (c.canonicalPayloadIdentity != canonicalIdentity(ci)) {
          throw const FormatException('invalid_child_intent');
        }
        if (validateActive) _active(state, c.expenseId, 'expense', mapper);
        final source = RestaurantJournalExpenseHistory.sourceRows(
          state.copyWith(account: before),
          c.expenseId,
        ).single;
        mapped = RestaurantJournalExpenseHistory.correctionEntries(
          command: c,
          target: target,
          beforeSnapshot: source,
          mapper: mapper,
        );
        output = RestaurantJournalExpenseHistory.outcome(
          command: c,
          target: target,
          entries: mapped,
        ).toJson();
      } else if (type == 'edit_supplier_payment') {
        final c = RestaurantJournalPaymentHistory.commandFromIntent(
          ci,
        ) as EditSupplierPaymentCommand;
        if (c.canonicalPayloadIdentity != canonicalIdentity(ci)) {
          throw const FormatException('invalid_child_intent');
        }
        if (validateActive) _active(state, c.paymentId, 'payment', mapper);
        mapped = RestaurantJournalPaymentHistory.correctionEntries(
          command: c,
          target: target,
          beforeSnapshot: c.expectedSource,
          mapper: mapper,
        );
        output = RestaurantJournalPaymentHistory.outcome(
          command: c,
          target: target,
          entries: mapped,
        ).toJson();
      } else if (type == 'edit_daily_transfer') {
        final c = EditDailyTransferCommand(
          operationId: ci['operationId']! as String,
          accountLineage: command.accountLineage,
          expectedFence: command.fence,
          transferId: ci['transferId']! as String,
          expectedActiveJournalId: ci['expectedActiveJournalId']! as String,
          inverseJournalId: ci['inverseJournalId']! as String,
          replacementJournalId: ci['replacementJournalId']! as String,
          newAmount: BigInt.parse(ci['newAmount']! as String),
          newDate: destination,
          reason: ci['reason']! as String,
          recordedAt: ci['recordedAt']! as String,
          policy: target.journal.policy,
        );
        if (c.canonicalPayloadIdentity != canonicalIdentity(ci)) {
          throw const FormatException('invalid_transfer_batch_intent');
        }
        if (validateActive) _active(state, c.transferId, 'transfer', mapper);
        final source = (before.toJson()['transfers']! as List)
            .cast<Map<String, Object?>>()
            .singleWhere((r) => r['id'] == c.transferId);
        mapped = RestaurantJournalTransferHistory.correctionEntries(
          target: target,
          transferId: c.transferId,
          operationId: c.operationId,
          inverseJournalId: c.inverseJournalId,
          replacementJournalId: c.replacementJournalId,
          newAmount: c.newAmount,
          newDate: c.newDate,
          reason: c.reason,
          recordedAt: c.recordedAt,
          beforeSnapshot: source,
          mapper: mapper,
          policy: c.policy,
        );
        output = RestaurantJournalTransferCorrectionOutcome(
          commandType: c.commandType,
          operationId: c.operationId,
          transferId: c.transferId,
          targetJournalId: target.journal.id,
          inverseJournalId: c.inverseJournalId,
          replacementJournalId: c.replacementJournalId,
          effectiveDate: destination.toString(),
          netAmount: c.newAmount.toString(),
          metadata: mapped.last.metadata,
        ).toJson();
      } else if (type == 'external_cash_edit') {
        final c = ExternalCashCommand.fromIntent(ci, mapper);
        final prior = correctionReceiptViews(state).singleWhere(
          (r) => r.identity.operationId == target.metadata['operationId'],
        );
        final priorIntent =
            jsonDecode(prior.identity.canonicalPayloadIdentity) as Map;
        if (priorIntent['acceptedCounterAccountId'] !=
            c.acceptedCounterAccountId) {
          throw const FormatException('cash_mapping_changed');
        }
        if (c.canonicalPayloadIdentity != canonicalIdentity(ci)) {
          throw const FormatException('invalid_cash_batch_intent');
        }
        if (validateActive) _active(state, c.transactionId, 'cash', mapper);
        mapped = RestaurantJournalExternalCashHistory.entries(
          c,
          mapper,
          c.expectedSource,
          target,
        );
        output = RestaurantJournalExternalCashHistory.outcome(
          c,
          mapped,
        ).toJson();
      } else {
        throw const FormatException('unsupported_day_shift_record');
      }
      entries.addAll(mapped);
      children.add({
        'intent': ci,
        'entries': [for (final e in mapped) e.toJson()],
        'outcome': output,
      });
    }
    final candidate = validateActive
        ? state.copyWith(
            account: after,
            journals: [...state.journals, ...entries],
          )
        : state;
    return (
      candidate,
      DayDateCorrectionOutcome({
        'commandType': 'day_date_correction',
        'operationId': command.operationId,
        'afterAccount': after.toJson(),
        'mapping': plan.mapping,
        'children': children,
      }),
    );
  }
}
