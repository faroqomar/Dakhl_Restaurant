import 'dart:convert';

import 'correction_batch_receipts.dart';
import 'deleted_party_restoration.dart';
import 'source_record_order.dart';
import 'restaurant_journal_invoice_correction_commands.dart';

import 'package:madar_application/madar_application.dart';
import 'package:madar_domain/madar_domain.dart';

import '../accounts/portable_journal_state.dart';
import 'journal_command_host.dart';
import 'restaurant_journal_payment_correction_commands.dart';
import 'restaurant_journal_mapper.dart';
import 'restaurant_journal_spending_commands.dart';

/// Rebuilds one payment's complete linear history from captured receipt intent.
/// No journal metadata or source row acts as independent posting authority.
final class RestaurantJournalPaymentHistory {
  const RestaurantJournalPaymentHistory._();
  static bool hasCorrections(PortableJournalState state, String id) {
    final roots = state.journals
        .where(
          (j) =>
              j.sourceRecordId == id &&
              j.sourceType == RestaurantJournalSourceType.supplierPayment.name,
        )
        .map((j) => j.journal.id)
        .toSet();
    if (state.journals.any(
      (j) =>
          (j.metadata['paymentId'] == id &&
              j.metadata['targetJournalId'] != null) ||
          roots.contains(j.journal.reversesId) ||
          roots.contains(j.correctedFromJournalId),
    )) {
      return true;
    }
    for (final receipt in correctionReceiptViews(state)) {
      try {
        final intent = jsonDecode(receipt.identity.canonicalPayloadIdentity);
        if (intent is Map &&
            intent['paymentId'] == id &&
            [
              'edit_supplier_payment',
              'delete_supplier_payment',
            ].contains(intent['commandType'])) {
          return true;
        }
      } on FormatException {
        /* Other command families can use opaque identities. */
      }
    }
    return false;
  }

  /// Source snapshots are complete canonical standalone payment records.
  static List<Map<String, Object?>> sourceRows(
    PortableJournalState state,
    String id,
  ) => (state.account.toJson()['payments'] as List)
      .cast<Map<String, Object?>>()
      .where((p) => p['id'] == id)
      .toList();

  static Map<String, Object?> replacementSource(
    EditSupplierPaymentCommand command,
    Map<String, Object?> before,
  ) => {
    'id': command.paymentId,
    'supplierId': command.supplierId,
    'invoiceId': command.invoiceId,
    'categoryId': command.categoryId,
    'date': command.date.toString(),
    'amount': command.amount.toInt(),
    'invoiceAmount': command.invoiceAmount.toInt(),
    'debtAmount': command.debtAmount.toInt(),
    'note': LegacyText.trimJavaScript(command.note),
    'funding': {
      'source': command.fundingSource.name,
      'dailyAmount': command.dailyAmount.toInt(),
      'cashAmount': command.cashAmount.toInt(),
    },
    'createdAt': before['createdAt'],
  };

  static List<PortableJournalEntry> correctionEntries({
    required SupplierPaymentCorrectionCommand command,
    required PortableJournalEntry target,
    required Map<String, Object?> beforeSnapshot,
    required RestaurantJournalMapper mapper,
  }) {
    final original = RestaurantJournalProposal(
      journal: target.journal,
      sourceType: RestaurantJournalSourceType.values.byName(target.sourceType),
      sourceRecordId: command.paymentId,
      sourceVersion: target.metadata['sourceVersion'] as int,
      metadata: target.metadata,
    );
    final inverse = mapper.mapOriginalDateVoid(
      originalProposal: original,
      reversalJournalId: command.inverseJournalId,
      reason: command.reason.trim(),
      isEligible: true,
      voidRecordId: command.paymentId,
    );
    final after = command is EditSupplierPaymentCommand
        ? replacementSource(command, beforeSnapshot)
        : <String, Object?>{'deleted': true, 'id': command.paymentId};
    final history = <String, Object?>{
      'operationId': command.operationId,
      'paymentId': command.paymentId,
      'targetJournalId': target.journal.id,
      'inverseJournalId': command.inverseJournalId,
      if (command is EditSupplierPaymentCommand)
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
        sourceRecordId: command.paymentId,
        replacementJournalId: command is EditSupplierPaymentCommand
            ? command.replacementJournalId
            : null,
        recordedAt: command.recordedAt,
        metadata: history,
      ),
    ];
    if (command is EditSupplierPaymentCommand) {
      final replacement = mapper.mapReplacementProposal(
        newProposal: mapper.mapSupplierPayment(
          supplierId: command.supplierId,
          invoiceId: command.invoiceId,
          invoiceSettledAmount: command.invoiceAmount,
          debtSettledAmount: command.debtAmount,
          journalId: command.replacementJournalId,
          paymentId: command.paymentId,
          effectiveDate: command.date,
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
          sourceRecordId: command.paymentId,
          correctedFromJournalId: target.journal.id,
          recordedAt: command.recordedAt,
          metadata: {
            ...history,
            'categoryId': command.categoryId,
            'supplierId': command.supplierId,
            'invoiceAmount': command.invoiceAmount.toString(),
            'debtAmount': command.debtAmount.toString(),
            'amount': command.amount.toString(),
            'dailyAmount': command.dailyAmount.toString(),
            'cashAmount': command.cashAmount.toString(),
          },
        ),
      );
    }
    return List.unmodifiable(result);
  }

  static RestaurantJournalPaymentCorrectionOutcome outcome({
    required SupplierPaymentCorrectionCommand command,
    required PortableJournalEntry target,
    required List<PortableJournalEntry> entries,
  }) => RestaurantJournalPaymentCorrectionOutcome(
    commandType: command.commandType,
    operationId: command.operationId,
    paymentId: command.paymentId,
    targetJournalId: target.journal.id,
    inverseJournalId: command.inverseJournalId,
    replacementJournalId: command is EditSupplierPaymentCommand
        ? command.replacementJournalId
        : null,
    effectiveDate: command is EditSupplierPaymentCommand
        ? command.date.toString()
        : target.journal.effectiveDate.toString(),
    netAmount:
        (command is EditSupplierPaymentCommand
                ? command.amount
                : target.journal.totalUnits)
            .toString(),
    metadata: entries.last.metadata,
  );

  /// Verifies root source/posting/outcome, receipt intent, ordered correction
  /// edges, profile/policy and terminal source, including historical replay.
  static bool validate({
    required PortableJournalState state,
    required String paymentId,
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
                j.sourceRecordId == paymentId &&
                j.sourceType ==
                    RestaurantJournalSourceType.supplierPayment.name,
          )
          .toList();
      if (roots.length != 1) return false;
      final root = roots.single;
      final createReceipt = _receipt(state, root.metadata['operationId']);
      final intent = _intent(createReceipt, state, paymentId);
      var source = (jsonDecode(
        root.metadata['sourceSnapshot'] as String,
      ) as Map).cast<String, Object?>();
      final inline = intent['commandType'] == 'purchase_invoice'
          ? RestaurantJournalInvoiceHistory.createFromIntent(intent)
          : null;
      final create = inline == null
          ? CreateSupplierPaymentCommand(
              operationId: intent['operationId'] as String,
              payloadVersion: intent['payloadVersion'] as int,
              accountLineage: intent['accountLineage'] as String,
              expectedFence: _fence(intent),
              paymentId: paymentId,
              journalId: intent['journalId'] as String,
              supplierId: intent['supplierId'] as String,
              invoiceId: intent['invoiceId'] as String?,
              categoryId: intent['categoryId'] as String?,
              date: _date(intent['date']),
              amount: BigInt.parse(intent['amount'] as String),
              fundingSource: FundingSource.values.byName(
                intent['fundingSource'] as String,
              ),
              dailyAmount: BigInt.parse(intent['dailyAmount'] as String),
              cashAmount: BigInt.parse(intent['cashAmount'] as String),
              note: intent['note'] as String,
              recordedAt: intent['recordedAt'] as String,
              policy: _policy(intent['policy']),
            )
          : CreateSupplierPaymentCommand(
              operationId: inline.operationId,
              payloadVersion: inline.payloadVersion,
              accountLineage: inline.accountLineage,
              expectedFence: inline.expectedFence,
              paymentId: paymentId,
              journalId: inline.paymentJournalId!,
              supplierId: inline.supplierId,
              invoiceId: inline.invoiceId,
              categoryId: source['categoryId']! as String,
              date: inline.date,
              amount: BigInt.from(inline.immediatePayment!.amount),
              fundingSource: FundingSource.values.byName(
                inline.immediatePayment!.source,
              ),
              dailyAmount: BigInt.from(
                inline.immediatePayment!.source == 'daily'
                    ? inline.immediatePayment!.amount
                    : inline.immediatePayment!.source == 'cash'
                    ? 0
                    : inline.immediatePayment!.dailyAmount,
              ),
              cashAmount: BigInt.from(
                inline.immediatePayment!.source == 'cash'
                    ? inline.immediatePayment!.amount
                    : inline.immediatePayment!.source == 'daily'
                    ? 0
                    : inline.immediatePayment!.cashAmount,
              ),
              note: '',
              recordedAt: inline.recordedAt,
              policy: inline.policy,
            );
      if ((inline == null
              ? create.identity != createReceipt.identity ||
                    create.commandType != intent['commandType']
              : inline.identity != createReceipt.identity ||
                    inline.immediatePayment?.id != paymentId ||
                    inline.paymentJournalId != root.journal.id) ||
          (initialIdentity != null &&
              (inline?.identity ?? create.identity) != initialIdentity) ||
          create.journalId != root.journal.id ||
          create.date.compareTo(cutover) < 0) {
        return false;
      }
      if (inline != null) {
        final invoiceRoot = state.journals.singleWhere(
          (j) => j.journal.id == inline.invoiceJournalId,
        );
        if (!RestaurantJournalSpendingCommandCoordinator.validateInvoiceCreateSnapshot(
          inline,
          RestaurantJournalSpendingOutcome.fromOutcomePayload(
            createReceipt.outcomePayload!,
          ),
          state,
          mapper,
          (jsonDecode(invoiceRoot.metadata['sourceSnapshot']! as String) as Map)
              .cast<String, Object?>(),
        )) {
          return false;
        }
      }
      if (source['categoryId'] is! String ||
          (source['categoryId'] as String).isEmpty ||
          (source['categoryId'] as String).trim() != source['categoryId']) {
        return false;
      }
      final expectedSource = <String, Object?>{
        'id': paymentId,
        'supplierId': create.supplierId,
        'invoiceId': create.invoiceId,
        'categoryId': create.categoryId ?? source['categoryId'],
        'date': create.date.toString(),
        'amount': create.amount.toInt(),
        'invoiceAmount': source['invoiceAmount'],
        'debtAmount': source['debtAmount'],
        'funding': {
          'source': create.fundingSource.name,
          'dailyAmount': create.dailyAmount.toInt(),
          'cashAmount': create.cashAmount.toInt(),
        },
        'note': LegacyText.trimJavaScript(create.note),
        'createdAt': create.recordedAt,
      };
      if (!_same(source, expectedSource)) return false;
      final mapped = mapper.mapSupplierPayment(
        journalId: create.journalId,
        paymentId: paymentId,
        supplierId: create.supplierId,
        invoiceId: create.invoiceId,
        effectiveDate: create.date,
        amount: create.amount,
        dailyAmount: create.dailyAmount,
        cashboxAmount: create.cashAmount,
        invoiceSettledAmount: BigInt.from(source['invoiceAmount'] as int),
        debtSettledAmount: BigInt.from(source['debtAmount'] as int),
        policy: create.policy,
      );
      final metadata = <String, Object?>{
        'supplierId': source['supplierId'],
        if (source['invoiceId'] != null) 'invoiceId': source['invoiceId'],
        'amount': create.amount.toString(),
        'invoiceSettledAmount': '${source['invoiceAmount']}',
        'debtSettledAmount': '${source['debtAmount']}',
        'dailyAmount': create.dailyAmount.toString(),
        if (inline != null)
          'cashboxAmount': create.cashAmount.toString()
        else
          'cashAmount': create.cashAmount.toString(),
        'sourceVersion': mapped.sourceVersion,
        'operationId': create.operationId,
        'paymentId': paymentId,
        'sourceSnapshot': canonicalIdentity(source),
      };
      final expectedRoot = PortableJournalEntry(
        journal: mapped.journal,
        sourceType: mapped.sourceType.name,
        sourceRecordId: paymentId,
        recordedAt: create.recordedAt,
        metadata: metadata,
      );
      final createOutcome = RestaurantJournalSpendingOutcome(
        commandType: create.commandType,
        operationId: create.operationId,
        paymentId: paymentId,
        supplierId: create.supplierId,
        invoiceId: create.invoiceId,
        journalId: create.journalId,
        effectiveDate: create.date.toString(),
        netAmount: create.amount.toString(),
        metadata: metadata,
      );
      if (!_same(root.toJson(), expectedRoot.toJson()) ||
          (inline == null &&
              !_same(_outcome(createReceipt), createOutcome.toJson()))) {
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
        final correctionIntent = _intent(receipt, state, paymentId);
        final correction = commandFromIntent(correctionIntent);
        if (correction.identity != receipt.identity ||
            correction.expectedActiveJournalId != active.journal.id ||
            correction.expectedSourceVersion !=
                active.metadata['sourceVersion'] ||
            !_same(correction.expectedSource, source) ||
            correction.inverseJournalId != inverse.journal.id ||
            receipt.sequence <= previousSequence ||
            !receipts.add(correction.operationId) ||
            !_same(
              paymentProfileIdentity(correction.profile),
              paymentProfileIdentity(mapper.profile),
            ) ||
            !_same(
              paymentPolicyIdentity(correction.mapperDefaultPolicy),
              paymentPolicyIdentity(mapper.defaultPolicy),
            ) ||
            (correction is EditSupplierPaymentCommand &&
                correction.date.compareTo(cutover) < 0)) {
          return false;
        }
        if (correction is DeleteSupplierPaymentCommand &&
            correction.policy != null &&
            !_same(
              paymentPolicyIdentity(correction.policy!),
              paymentPolicyIdentity(active.journal.policy),
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
        if (correction is EditSupplierPaymentCommand) {
          active = expected.last;
          source = replacementSource(correction, source);
        } else {
          final restored = DeletedPartyRestorationHistory.afterDelete(
            state: state,
            kind: DeletedPartyKind.payment,
            recordId: paymentId,
            deleted: active,
            inverse: expected.single,
            deletion: receipt,
            source: source,
            mapper: mapper,
          );
          active = restored?.entry;
          if (restored != null) {
            if (!entries.add(restored.entry.journal.id) ||
                !receipts.add(restored.receipt.identity.operationId)) {
              return false;
            }
            previousSequence = restored.receipt.sequence;
            previousIndex = state.journals.indexOf(restored.entry);
          }
        }
      }
      if (expectedActiveJournalId != null &&
          active?.journal.id != expectedActiveJournalId) {
        return false;
      }
      for (final entry in state.journals) {
        final owned =
            entry.metadata['paymentId'] == paymentId ||
            (entry.sourceRecordId == paymentId &&
                entry.sourceType ==
                    RestaurantJournalSourceType.supplierPayment.name);
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
            extra['paymentId'] == paymentId &&
            !receipts.contains(receipt.identity.operationId)) {
          return false;
        }
      }
      final rows = sourceRows(state, paymentId);
      return active == null
          ? rows.isEmpty
          : rows.length == 1 && _same(rows.single, source);
    } catch (_) {
      return false;
    }
  }

  static SupplierPaymentCorrectionCommand commandFromIntent(
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
    if (intent['commandType'] == 'edit_supplier_payment') {
      return EditSupplierPaymentCommand(
        operationId: intent['operationId'] as String,
        payloadVersion: intent['payloadVersion'] as int,
        accountLineage: intent['accountLineage'] as String,
        expectedFence: _fence(intent),
        paymentId: intent['paymentId'] as String,
        expectedActiveJournalId: intent['expectedActiveJournalId'] as String,
        expectedSourceVersion: intent['expectedSourceVersion'] as int,
        expectedSource: (intent['expectedSource'] as Map)
            .cast<String, Object?>(),
        inverseJournalId: intent['inverseJournalId'] as String,
        replacementJournalId: intent['replacementJournalId'] as String,
        date: _date(intent['date']),
        categoryId: intent['categoryId'] as String,
        supplierId: intent['supplierId'] as String,
        invoiceId: intent['invoiceId'] as String?,
        invoiceAmount: BigInt.parse(intent['invoiceAmount'] as String),
        debtAmount: BigInt.parse(intent['debtAmount'] as String),
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
    if (intent['commandType'] != 'delete_supplier_payment') {
      throw const FormatException('invalid_payment_correction_type');
    }
    return DeleteSupplierPaymentCommand(
      operationId: intent['operationId'] as String,
      payloadVersion: intent['payloadVersion'] as int,
      accountLineage: intent['accountLineage'] as String,
      expectedFence: _fence(intent),
      paymentId: intent['paymentId'] as String,
      expectedActiveJournalId: intent['expectedActiveJournalId'] as String,
      expectedSourceVersion: intent['expectedSourceVersion'] as int,
      expectedSource: (intent['expectedSource'] as Map).cast<String, Object?>(),
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
        (map['paymentId'] != id &&
            !(map['commandType'] == 'purchase_invoice' &&
                (map['immediatePayment'] as Map?)?['id'] == id)) ||
        map['operationId'] != receipt.identity.operationId ||
        map['payloadVersion'] != receipt.identity.payloadVersion ||
        _fence(map) == null ||
        _fence(map) != receipt.fence) {
      throw const FormatException('invalid_payment_intent');
    }
    return map;
  }

  static StorageFence? _fence(Map<String, Object?> intent) {
    final value = intent['expectedFence'];
    if (value == null) return null;
    final map = (value as Map).cast<String, Object?>();
    if (map.length != 2) throw const FormatException('invalid_payment_fence');
    return StorageFence(
      storeId: map['storeId'] as String,
      generation: map['generation'] as String,
    );
  }

  static JournalPolicy? _policy(Object? value) {
    if (value == null) return null;
    final p = (value as Map).cast<String, Object?>();
    if (p.length != 6) throw const FormatException('invalid_payment_policy');
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
