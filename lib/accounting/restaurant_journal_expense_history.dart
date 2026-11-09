import 'dart:convert';

import 'correction_batch_receipts.dart';
import 'deleted_spending_restoration.dart';
import 'source_record_order.dart';

import 'package:madar_application/madar_application.dart';
import 'package:madar_domain/madar_domain.dart';

import '../accounts/portable_journal_state.dart';
import 'journal_command_host.dart';
import 'restaurant_journal_expense_correction_commands.dart';
import 'restaurant_journal_mapper.dart';
import 'restaurant_journal_spending_commands.dart';

/// Rebuilds one expense's complete linear history from captured receipt intent.
/// No journal metadata or source row acts as independent posting authority.
final class RestaurantJournalExpenseHistory {
  const RestaurantJournalExpenseHistory._();

  /// Current rows include their containing source day, which is not a field on
  /// the legacy expense itself. This wrapper also serves as a history snapshot.
  static List<Map<String, Object?>> sourceRows(
    PortableJournalState state,
    String id,
  ) => [
    for (final day in (state.account.toJson()['days'] as Map).entries)
      for (final row in (day.value as Map)['expenses'] as List)
        if ((row as Map)['id'] == id)
          {
            'date': day.key as String,
            'expense': Map<String, Object?>.from(row),
          },
  ];

  static Map<String, Object?> replacementSource(
    EditOperatingExpenseCommand command,
    Map<String, Object?> before,
  ) => {
    'id': command.expenseId,
    'categoryId': command.categoryId,
    'amount': command.amount.toInt(),
    'note': LegacyText.trimJavaScript(command.note),
    'funding': {
      'source': command.fundingSource.name,
      'dailyAmount': command.dailyAmount.toInt(),
      'cashAmount': command.cashAmount.toInt(),
    },
    'createdAt': (before['expense'] as Map)['createdAt'],
  };

  static List<PortableJournalEntry> correctionEntries({
    required OperatingExpenseCorrectionCommand command,
    required PortableJournalEntry target,
    required Map<String, Object?> beforeSnapshot,
    required RestaurantJournalMapper mapper,
  }) {
    final original = RestaurantJournalProposal(
      journal: target.journal,
      sourceType: RestaurantJournalSourceType.values.byName(target.sourceType),
      sourceRecordId: command.expenseId,
      sourceVersion: target.metadata['sourceVersion'] as int,
      metadata: target.metadata,
    );
    final inverse = mapper.mapOriginalDateVoid(
      originalProposal: original,
      reversalJournalId: command.inverseJournalId,
      reason: command.reason.trim(),
      isEligible: true,
      voidRecordId: command.expenseId,
    );
    final after = command is EditOperatingExpenseCommand
        ? <String, Object?>{
            'date': command.date.toString(),
            'expense': replacementSource(command, beforeSnapshot),
          }
        : <String, Object?>{'deleted': true, 'id': command.expenseId};
    final history = <String, Object?>{
      'operationId': command.operationId,
      'expenseId': command.expenseId,
      'targetJournalId': target.journal.id,
      'inverseJournalId': command.inverseJournalId,
      if (command is EditOperatingExpenseCommand)
        'replacementJournalId': command.replacementJournalId,
      'beforeSnapshot': canonicalIdentity(beforeSnapshot),
      'afterSnapshot': canonicalIdentity(after),
      'reason': command.reason.trim(),
      'sourceVersion': original.sourceVersion,
    };
    final result = <PortableJournalEntry>[
      PortableJournalEntry(
        journal: inverse.journal,
        sourceType: inverse.sourceType.name,
        sourceRecordId: command.expenseId,
        replacementJournalId: command is EditOperatingExpenseCommand
            ? command.replacementJournalId
            : null,
        recordedAt: command.recordedAt,
        metadata: history,
      ),
    ];
    if (command is EditOperatingExpenseCommand) {
      final replacement = mapper.mapReplacementProposal(
        newProposal: mapper.mapOperatingExpense(
          journalId: command.replacementJournalId,
          expenseId: command.expenseId,
          effectiveDate: command.date,
          categoryId: command.categoryId,
          amount: command.amount,
          dailyAmount: command.dailyAmount,
          cashboxAmount: command.cashAmount,
          policy: command.policy,
        ),
        correctedFromId: target.journal.id,
      );
      result.add(
        PortableJournalEntry(
          journal: replacement.journal,
          sourceType: replacement.sourceType.name,
          sourceRecordId: command.expenseId,
          correctedFromJournalId: target.journal.id,
          recordedAt: command.recordedAt,
          metadata: {
            ...history,
            'categoryId': command.categoryId,
            'amount': command.amount.toString(),
            'dailyAmount': command.dailyAmount.toString(),
            'cashAmount': command.cashAmount.toString(),
          },
        ),
      );
    }
    return List.unmodifiable(result);
  }

  static RestaurantJournalExpenseCorrectionOutcome outcome({
    required OperatingExpenseCorrectionCommand command,
    required PortableJournalEntry target,
    required List<PortableJournalEntry> entries,
  }) => RestaurantJournalExpenseCorrectionOutcome(
    commandType: command.commandType,
    operationId: command.operationId,
    expenseId: command.expenseId,
    targetJournalId: target.journal.id,
    inverseJournalId: command.inverseJournalId,
    replacementJournalId: command is EditOperatingExpenseCommand
        ? command.replacementJournalId
        : null,
    effectiveDate: command is EditOperatingExpenseCommand
        ? command.date.toString()
        : target.journal.effectiveDate.toString(),
    netAmount:
        (command is EditOperatingExpenseCommand
                ? command.amount
                : target.journal.totalUnits)
            .toString(),
    metadata: entries.last.metadata,
  );

  /// Verifies root source/posting/outcome, receipt intent, ordered correction
  /// edges, profile/policy and terminal source, including historical replay.
  static bool validate({
    required PortableJournalState state,
    required String expenseId,
    required RestaurantJournalMapper mapper,
    String? expectedActiveJournalId,
    DurableCommandIdentity? initialIdentity,
  }) {
    try {
      final cutover = state.cutoverState.cutoverDate;
      if (cutover == null ||
          state.cutoverState.isGated ||
          !state.cutoverState.hasActivePosting) {
        return false;
      }
      final roots = state.journals
          .where(
            (j) =>
                j.sourceRecordId == expenseId &&
                j.sourceType == RestaurantJournalSourceType.expense.name,
          )
          .toList();
      if (roots.length != 1) return false;
      final root = roots.single;
      final createReceipt = _receipt(state, root.metadata['operationId']);
      final intent = _intent(createReceipt, state, expenseId);
      final create = CreateOperatingExpenseCommand(
        operationId: intent['operationId'] as String,
        payloadVersion: intent['payloadVersion'] as int,
        accountLineage: intent['accountLineage'] as String,
        expectedFence: _fence(intent),
        expenseId: expenseId,
        journalId: intent['journalId'] as String,
        date: _date(intent['date']),
        categoryId: intent['categoryId'] as String,
        amount: BigInt.parse(intent['amount'] as String),
        fundingSource: FundingSource.values.byName(
          intent['fundingSource'] as String,
        ),
        dailyAmount: BigInt.parse(intent['dailyAmount'] as String),
        cashAmount: BigInt.parse(intent['cashAmount'] as String),
        note: intent['note'] as String,
        recordedAt: intent['recordedAt'] as String,
        policy: _policy(intent['policy']),
      );
      if (create.identity != createReceipt.identity ||
          create.commandType != intent['commandType'] ||
          (initialIdentity != null && create.identity != initialIdentity) ||
          create.journalId != root.journal.id ||
          create.date.compareTo(cutover) < 0) {
        return false;
      }
      var source = <String, Object?>{
        'date': create.date.toString(),
        'expense': <String, Object?>{
          'id': expenseId,
          'categoryId': create.categoryId,
          'amount': create.amount.toInt(),
          'note': LegacyText.trimJavaScript(create.note),
          'funding': {
            'source': create.fundingSource.name,
            'dailyAmount': create.dailyAmount.toInt(),
            'cashAmount': create.cashAmount.toInt(),
          },
          'createdAt': create.recordedAt,
        },
      };
      final mapped = mapper.mapOperatingExpense(
        journalId: create.journalId,
        expenseId: expenseId,
        effectiveDate: create.date,
        categoryId: create.categoryId,
        amount: create.amount,
        dailyAmount: create.dailyAmount,
        cashboxAmount: create.cashAmount,
        policy: create.policy,
      );
      final metadata = <String, Object?>{
        'categoryId': create.categoryId,
        'amount': create.amount.toString(),
        'dailyAmount': create.dailyAmount.toString(),
        'cashAmount': create.cashAmount.toString(),
        'sourceVersion': mapped.sourceVersion,
        'operationId': create.operationId,
        'expenseId': expenseId,
        'sourceSnapshot': canonicalIdentity(
          source['expense']! as Map<String, Object?>,
        ),
      };
      final expectedRoot = PortableJournalEntry(
        journal: mapped.journal,
        sourceType: mapped.sourceType.name,
        sourceRecordId: expenseId,
        recordedAt: create.recordedAt,
        metadata: metadata,
      );
      final createOutcome = RestaurantJournalSpendingOutcome(
        commandType: create.commandType,
        operationId: create.operationId,
        expenseId: expenseId,
        journalId: create.journalId,
        effectiveDate: create.date.toString(),
        netAmount: create.amount.toString(),
        metadata: metadata,
      );
      if (!_same(root.toJson(), expectedRoot.toJson()) ||
          !_same(_outcome(createReceipt), createOutcome.toJson())) {
        return false;
      }
      final entries = <String>{root.journal.id},
          receipts = <String>{create.operationId};
      // Receipt sequence orders corrections across restored authorities.
      // PortableJournalState validates revision ordering within each fence.
      var previousSequence = createReceipt.sequence;
      var previousIndex = state.journals.indexOf(root);
      PortableJournalEntry? active = root;
      while (active != null) {
        final reversals = state.journals
            .where((j) => j.journal.reversesId == active!.journal.id)
            .toList();
        if (reversals.isEmpty) break;
        if (reversals.length != 1) return false;
        final inverse = reversals.single;
        final receipt = _receipt(state, inverse.metadata['operationId']);
        final correctionIntent = _intent(receipt, state, expenseId);
        final correction = commandFromIntent(correctionIntent);
        if (correction.identity != receipt.identity ||
            correction.expectedActiveJournalId != active.journal.id ||
            correction.inverseJournalId != inverse.journal.id ||
            receipt.sequence <= previousSequence ||
            !receipts.add(correction.operationId) ||
            !_same(
              expenseProfileIdentity(correction.profile),
              expenseProfileIdentity(mapper.profile),
            ) ||
            !_same(
              expensePolicyIdentity(correction.mapperDefaultPolicy),
              expensePolicyIdentity(mapper.defaultPolicy),
            ) ||
            (correction is EditOperatingExpenseCommand &&
                correction.date.compareTo(cutover) < 0)) {
          return false;
        }
        if (correction is DeleteOperatingExpenseCommand &&
            correction.policy != null &&
            !_same(
              expensePolicyIdentity(correction.policy!),
              expensePolicyIdentity(active.journal.policy),
            )) {
          return false;
        }
        previousSequence = receipt.sequence;
        final expected = correctionEntries(
          command: correction,
          target: active,
          beforeSnapshot: source,
          mapper: mapper,
        );
        for (final entry in expected) {
          final actual = state.journals
              .where((j) => j.journal.id == entry.journal.id)
              .toList();
          if (actual.length != 1 ||
              !entries.add(entry.journal.id) ||
              !_same(actual.single.toJson(), entry.toJson())) {
            return false;
          }
          final index = state.journals.indexOf(actual.single);
          if (index <= previousIndex) return false;
          previousIndex = index;
        }
        if (!_same(
          _outcome(receipt),
          outcome(
            command: correction,
            target: active,
            entries: expected,
          ).toJson(),
        )) {
          return false;
        }
        final deletedTarget = active;
        active = correction is EditOperatingExpenseCommand
            ? expected.last
            : null;
        if (correction is DeleteOperatingExpenseCommand) {
          final restored = DeletedSpendingRestorationHistory.afterDelete(
            state: state,
            kind: DeletedSpendingKind.expense,
            recordId: expenseId,
            deleted: deletedTarget,
            inverse: expected.first,
            deletion: receipt,
            source: source,
            mapper: mapper,
          );
          if (restored != null) {
            if (!entries.add(restored.entry.journal.id) ||
                !receipts.add(restored.receipt.identity.operationId) ||
                restored.receipt.sequence <= previousSequence ||
                state.journals.indexOf(restored.entry) <= previousIndex) {
              return false;
            }
            previousSequence = restored.receipt.sequence;
            previousIndex = state.journals.indexOf(restored.entry);
            active = restored.entry;
          }
        }
        if (correction is EditOperatingExpenseCommand) {
          source = {
            'date': correction.date.toString(),
            'expense': replacementSource(correction, source),
          };
        }
      }
      if (expectedActiveJournalId != null &&
          active?.journal.id != expectedActiveJournalId) {
        return false;
      }
      for (final entry in state.journals) {
        final owned =
            entry.metadata['expenseId'] == expenseId ||
            (entry.sourceRecordId == expenseId &&
                entry.sourceType == RestaurantJournalSourceType.expense.name);
        final linked =
            entries.contains(entry.journal.reversesId) ||
            entries.contains(entry.correctedFromJournalId) ||
            entries.contains(entry.replacementJournalId);
        if ((owned || linked) && !entries.contains(entry.journal.id)) {
          return false;
        }
      }
      for (final receipt in correctionReceiptViews(state)) {
        if (receipt.status != DurableCommandStatus.committed) continue;
        Object? extra;
        try {
          extra = jsonDecode(receipt.identity.canonicalPayloadIdentity);
        } on FormatException {
          continue;
        }
        if (extra is Map &&
            extra['expenseId'] == expenseId &&
            !receipts.contains(receipt.identity.operationId)) {
          return false;
        }
      }
      final rows = sourceRows(state, expenseId);
      return active == null
          ? rows.isEmpty
          : rows.length == 1 && _same(rows.single, source);
    } catch (_) {
      return false;
    }
  }

  static OperatingExpenseCorrectionCommand commandFromIntent(
    Map<String, Object?> intent,
  ) {
    final p = (intent['profile'] as Map).cast<String, Object?>();
    final profile = RestaurantAccountProfile(
      dailyCashAccountId: p['dailyCashAccountId'] as String,
      cashboxAccountId: p['cashboxAccountId'] as String,
      salesRevenueAccountId: p['salesRevenueAccountId'] as String,
      salesReturnContraAccountId: p['salesReturnContraAccountId'] as String,
      purchasesExpenseAccountId: p['purchasesExpenseAccountId'] as String,
      openingEquityAccountId: p['openingEquityAccountId'] as String,
      supplierLiabilityPrefix: p['supplierLiabilityPrefix'] as String,
      categoryExpensePrefix: p['categoryExpensePrefix'] as String,
    );
    if (intent['commandType'] == 'edit_operating_expense') {
      return EditOperatingExpenseCommand(
        operationId: intent['operationId'] as String,
        payloadVersion: intent['payloadVersion'] as int,
        accountLineage: intent['accountLineage'] as String,
        expectedFence: _fence(intent),
        expenseId: intent['expenseId'] as String,
        expectedActiveJournalId: intent['expectedActiveJournalId'] as String,
        inverseJournalId: intent['inverseJournalId'] as String,
        replacementJournalId: intent['replacementJournalId'] as String,
        date: _date(intent['date']),
        categoryId: intent['categoryId'] as String,
        amount: BigInt.parse(intent['amount'] as String),
        fundingSource: FundingSource.values.byName(
          intent['fundingSource'] as String,
        ),
        dailyAmount: BigInt.parse(intent['dailyAmount'] as String),
        cashAmount: BigInt.parse(intent['cashAmount'] as String),
        note: intent['note'] as String,
        sourceOrder: intent['sourceOrder'] == null
            ? null
            : SourceRecordOrder.fromJson(
                (intent['sourceOrder']! as Map).cast<String, Object?>(),
              ),
        reason: intent['reason'] as String,
        recordedAt: intent['recordedAt'] as String,
        profile: profile,
        policy: _policy(intent['policy']),
        mapperDefaultPolicy: _policy(intent['mapperDefaultPolicy']),
      );
    }
    if (intent['commandType'] != 'delete_operating_expense') {
      throw const FormatException('invalid_expense_correction_type');
    }
    return DeleteOperatingExpenseCommand(
      operationId: intent['operationId'] as String,
      payloadVersion: intent['payloadVersion'] as int,
      accountLineage: intent['accountLineage'] as String,
      expectedFence: _fence(intent),
      expenseId: intent['expenseId'] as String,
      expectedActiveJournalId: intent['expectedActiveJournalId'] as String,
      inverseJournalId: intent['inverseJournalId'] as String,
      reason: intent['reason'] as String,
      recordedAt: intent['recordedAt'] as String,
      profile: profile,
      policy: _policy(intent['policy']),
      mapperDefaultPolicy: _policy(intent['mapperDefaultPolicy']),
    );
  }

  static DurableCommandReceipt _receipt(
    PortableJournalState state,
    Object? operationId,
  ) => correctionReceiptViews(state).singleWhere(
    (r) =>
        r.identity.operationId == operationId &&
        r.status == DurableCommandStatus.committed,
  );
  static Map<String, Object?> _intent(
    DurableCommandReceipt receipt,
    PortableJournalState state,
    String id,
  ) {
    final map = (jsonDecode(receipt.identity.canonicalPayloadIdentity) as Map)
        .cast<String, Object?>();
    if (map['accountLineage'] != state.accountLineage ||
        map['expenseId'] != id ||
        map['operationId'] != receipt.identity.operationId ||
        map['payloadVersion'] != receipt.identity.payloadVersion ||
        _fence(map) == null ||
        _fence(map) != receipt.fence) {
      throw const FormatException('invalid_expense_intent');
    }
    return map;
  }

  static StorageFence? _fence(Map<String, Object?> intent) {
    final value = intent['expectedFence'];
    if (value == null) return null;
    final map = (value as Map).cast<String, Object?>();
    if (map.length != 2) throw const FormatException('invalid_expense_fence');
    return StorageFence(
      storeId: map['storeId'] as String,
      generation: map['generation'] as String,
    );
  }

  static JournalPolicy? _policy(Object? value) {
    if (value == null) return null;
    final p = (value as Map).cast<String, Object?>();
    if (p.length != 6) throw const FormatException('invalid_expense_policy');
    return JournalPolicy(
      currency: p['currency'] as String,
      scale: p['scale'] as int,
      maximumLines: p['maximumLines'] as int,
      maximumLineUnits: BigInt.parse(p['maximumLineUnits'] as String),
      maximumSideUnits: BigInt.parse(p['maximumSideUnits'] as String),
      allowZeroLines: p['allowZeroLines'] as bool,
    );
  }

  static DateOnly _date(Object? date) =>
      DateOnly.parse(date as String, minimumYear: 1000, maximumYear: 9999);
  static Map<String, Object?> _outcome(DurableCommandReceipt r) =>
      (jsonDecode(r.outcomePayload!) as Map).cast<String, Object?>();
  static bool _same(Map<String, Object?> a, Map<String, Object?> b) =>
      canonicalIdentity(a) == canonicalIdentity(b);
}
