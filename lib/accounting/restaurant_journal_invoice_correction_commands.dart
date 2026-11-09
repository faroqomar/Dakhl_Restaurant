import 'dart:convert';

import 'package:madar_application/madar_application.dart';
import 'package:madar_domain/madar_domain.dart';

import '../accounts/portable_journal_codec.dart';
import '../accounts/portable_journal_state.dart';
import '../parties/purchase_proposal.dart';
import '../parties/supplier_ledger.dart';
import 'journal_command_host.dart';
import 'correction_batch_receipts.dart';
import 'deleted_party_restoration.dart';
import 'source_record_order.dart';
import 'source_material_restoration.dart';
import 'restaurant_journal_mapper.dart';
import 'restaurant_journal_payment_history.dart';
import 'restaurant_journal_payment_correction_commands.dart'
    show paymentProfileIdentity, paymentPolicyIdentity;
import 'restaurant_journal_spending_commands.dart';

sealed class PurchaseInvoiceCorrectionCommand {
  PurchaseInvoiceCorrectionCommand({
    required this.operationId,
    this.payloadVersion = 1,
    required this.accountLineage,
    required this.expectedFence,
    required this.invoiceId,
    required this.expectedActiveJournalId,
    required Map<String, Object?> expectedSource,
    this.expectedSourceVersion = 11,
    required this.inverseJournalId,
    required this.reason,
    required this.recordedAt,
    this.profile = const RestaurantAccountProfile(),
    this.policy,
    JournalPolicy? mapperDefaultPolicy,
  }) : expectedSource = freezeMap(expectedSource),
       mapperDefaultPolicy =
           mapperDefaultPolicy ?? RestaurantJournalPolicies.standard {
    for (final id in [
      operationId,
      accountLineage,
      invoiceId,
      expectedActiveJournalId,
      inverseJournalId,
      recordedAt,
    ]) {
      if (id.isEmpty || id.trim() != id) {
        throw const FormatException('invalid_invoice_correction_identity');
      }
    }
    if (reason.trim().isEmpty ||
        payloadVersion <= 0 ||
        expectedSourceVersion != 11 ||
        inverseJournalId == expectedActiveJournalId) {
      throw const FormatException('invalid_invoice_correction_intent');
    }
  }
  final String operationId,
      accountLineage,
      invoiceId,
      expectedActiveJournalId,
      inverseJournalId,
      reason,
      recordedAt;
  final int payloadVersion, expectedSourceVersion;
  final StorageFence? expectedFence;
  final Map<String, Object?> expectedSource;
  final RestaurantAccountProfile profile;
  final JournalPolicy? policy;
  final JournalPolicy mapperDefaultPolicy;
  String get commandType;
  late final String canonicalPayloadIdentity;
  DurableCommandIdentity get identity => DurableCommandIdentity(
    operationId: operationId,
    payloadVersion: payloadVersion,
    canonicalPayloadIdentity: canonicalPayloadIdentity,
  );
  Map<String, Object?> get intent => {
    'commandType': commandType,
    'operationId': operationId,
    'payloadVersion': payloadVersion,
    'accountLineage': accountLineage,
    'invoiceId': invoiceId,
    'expectedFence': expectedFence == null
        ? null
        : {
            'storeId': expectedFence!.storeId,
            'generation': expectedFence!.generation,
          },
    'expectedActiveJournalId': expectedActiveJournalId,
    'expectedSource': expectedSource,
    'expectedSourceVersion': expectedSourceVersion,
    'inverseJournalId': inverseJournalId,
    'reason': reason,
    'recordedAt': recordedAt,
    'profile': paymentProfileIdentity(profile),
    'mapperDefaultPolicy': paymentPolicyIdentity(mapperDefaultPolicy),
    if (policy != null) 'policy': paymentPolicyIdentity(policy!),
  };
}

final class EditPurchaseInvoiceCommand
    extends PurchaseInvoiceCorrectionCommand {
  EditPurchaseInvoiceCommand({
    required super.operationId,
    super.payloadVersion,
    required super.accountLineage,
    required super.expectedFence,
    required super.invoiceId,
    required super.expectedActiveJournalId,
    required super.expectedSource,
    super.expectedSourceVersion,
    required super.inverseJournalId,
    required this.replacementJournalId,
    required this.supplierId,
    required this.invoiceNumber,
    required this.date,
    required Iterable<PurchaseLine> lines,
    this.note = '',
    this.sourceOrder,
    this.materialRestoration,
    required super.reason,
    required super.recordedAt,
    super.profile,
    super.policy,
    super.mapperDefaultPolicy,
  }) : lines = freezeList(lines, maxCount: 200) {
    if ({
          expectedActiveJournalId,
          inverseJournalId,
          replacementJournalId,
        }.length !=
        3) {
      throw const FormatException('duplicate_journal_id');
    }
    canonicalPayloadIdentity = canonicalIdentity({
      ...intent,
      if (sourceOrder != null) 'sourceOrder': sourceOrder!.toJson(),
      if (materialRestoration != null)
        'materialRestoration': materialRestoration!.toJson(),
      'replacementIntent': jsonDecode(
        replacementIntent.canonicalPayloadIdentity,
      ),
    });
  }
  final String replacementJournalId, supplierId, invoiceNumber, note;
  final DateOnly date;
  final List<PurchaseLine> lines;
  final SourceRecordOrder? sourceOrder;
  final SourceMaterialRestoration? materialRestoration;
  @override
  String get commandType => 'edit_purchase_invoice';
  CreatePurchaseInvoiceCommand get replacementIntent =>
      CreatePurchaseInvoiceCommand(
        operationId: operationId,
        payloadVersion: payloadVersion,
        accountLineage: accountLineage,
        expectedFence: expectedFence,
        invoiceId: invoiceId,
        invoiceJournalId: replacementJournalId,
        supplierId: supplierId,
        invoiceNumber: invoiceNumber,
        date: date,
        lines: lines,
        note: note,
        recordedAt: recordedAt,
        policy: policy,
      );
}

final class DeletePurchaseInvoiceCommand
    extends PurchaseInvoiceCorrectionCommand {
  DeletePurchaseInvoiceCommand({
    required super.operationId,
    super.payloadVersion,
    required super.accountLineage,
    required super.expectedFence,
    required super.invoiceId,
    required super.expectedActiveJournalId,
    required super.expectedSource,
    super.expectedSourceVersion,
    required super.inverseJournalId,
    required super.reason,
    required super.recordedAt,
    super.profile,
    super.policy,
    super.mapperDefaultPolicy,
  }) {
    canonicalPayloadIdentity = canonicalIdentity(intent);
  }
  @override
  String get commandType => 'delete_purchase_invoice';
}

final class RestaurantJournalInvoiceCorrectionOutcome {
  RestaurantJournalInvoiceCorrectionOutcome(Map<String, Object?> values)
    : values = freezeMap(values);
  final Map<String, Object?> values;
  String get invoiceId => values['invoiceId']! as String;
  String get inverseJournalId => values['inverseJournalId']! as String;
  String? get replacementJournalId => values['replacementJournalId'] as String?;
  Map<String, Object?> toJson() => values;
  String toOutcomePayload() => canonicalIdentity(values);
  factory RestaurantJournalInvoiceCorrectionOutcome.fromOutcomePayload(
    String payload,
  ) => RestaurantJournalInvoiceCorrectionOutcome(
    (jsonDecode(payload) as Map).cast<String, Object?>(),
  );
  @override
  String toString() =>
      'RestaurantJournalInvoiceCorrectionOutcome(details: redacted)';
}

/// Receipt-backed family reconciliation; no historical reallocation or source
/// mutation. Receipt sequence orders corrections across restored storage fences.
abstract final class RestaurantJournalInvoiceHistory {
  static bool hasCorrections(PortableJournalState state, String id) =>
      state.journals.any(
        (j) =>
            j.metadata['invoiceCorrection'] == true && j.sourceRecordId == id,
      );
  static List<Map<String, Object?>> sourceRows(
    PortableJournalState state,
    String id,
  ) => (state.account.toJson()['invoices']! as List)
      .cast<Map<String, Object?>>()
      .where((r) => r['id'] == id)
      .toList();
  static SupplierLedgerQueries _queries(PortableJournalState state) =>
      SupplierLedgerQueries(
        state.account,
        compareText: (_, _) =>
            throw StateError('No ordered queries in invoice corrections.'),
      );
  static List<PortableJournalEntry> entries({
    required PurchaseInvoiceCorrectionCommand command,
    required PortableJournalEntry target,
    required Map<String, Object?> before,
    required Map<String, Object?>? after,
    required PortableJournalState state,
    required RestaurantJournalMapper mapper,
  }) {
    final inverse = mapper.mapOriginalDateVoid(
      originalProposal: RestaurantJournalProposal(
        journal: target.journal,
        sourceType: RestaurantJournalSourceType.values.byName(
          target.sourceType,
        ),
        sourceRecordId: command.invoiceId,
        sourceVersion: target.metadata['sourceVersion']! as int,
      ),
      reversalJournalId: command.inverseJournalId,
      reason: command.reason.trim(),
      isEligible: true,
      voidRecordId: command.invoiceId,
    );
    final metadata = <String, Object?>{
      'invoiceCorrection': true,
      'operationId': command.operationId,
      'invoiceId': command.invoiceId,
      'targetJournalId': target.journal.id,
      'inverseJournalId': command.inverseJournalId,
      'beforeSnapshot': canonicalIdentity(before),
      'afterSnapshot': canonicalIdentity(
        after ?? {'deleted': true, 'id': command.invoiceId},
      ),
      'reason': command.reason.trim(),
      'sourceVersion': command.expectedSourceVersion,
      if (command is EditPurchaseInvoiceCommand)
        'replacementJournalId': command.replacementJournalId,
    };
    return [
      PortableJournalEntry(
        journal: inverse.journal,
        sourceType: inverse.sourceType.name,
        sourceRecordId: command.invoiceId,
        replacementJournalId: command is EditPurchaseInvoiceCommand
            ? command.replacementJournalId
            : null,
        recordedAt: command.recordedAt,
        metadata: metadata,
      ),
      if (command is EditPurchaseInvoiceCommand)
        PortableJournalEntry(
          journal: mapper
              .mapReplacementProposal(
                newProposal: mapper.mapPurchaseInvoice(
                  journalId: command.replacementJournalId,
                  invoiceId: command.invoiceId,
                  invoiceNumber: after!['number']! as String,
                  supplierId: command.supplierId,
                  effectiveDate: command.date,
                  amount: _queries(state).invoiceTotal(after),
                  policy: command.policy,
                ),
                correctedFromId: target.journal.id,
              )
              .journal,
          sourceType: RestaurantJournalSourceType.correctionReplacement.name,
          sourceRecordId: command.invoiceId,
          correctedFromJournalId: target.journal.id,
          recordedAt: command.recordedAt,
          metadata: {...metadata, 'sourceSnapshot': canonicalIdentity(after)},
        ),
    ];
  }

  static RestaurantJournalInvoiceCorrectionOutcome outcome(
    PurchaseInvoiceCorrectionCommand command,
    List<PortableJournalEntry> entries,
  ) => RestaurantJournalInvoiceCorrectionOutcome({
    'commandType': command.commandType,
    'operationId': command.operationId,
    'invoiceId': command.invoiceId,
    'targetJournalId': command.expectedActiveJournalId,
    'inverseJournalId': command.inverseJournalId,
    if (command is EditPurchaseInvoiceCommand)
      'replacementJournalId': command.replacementJournalId,
    'effectiveDate': entries.last.journal.effectiveDate.toString(),
    'netAmount': entries.last.journal.totalUnits.toString(),
    'metadata': entries.first.metadata,
  });

  static PortableJournalEntry? activePosting(
    PortableJournalState state,
    String id,
    RestaurantJournalMapper mapper,
  ) {
    if (!validate(state: state, invoiceId: id, mapper: mapper)) return null;
    final candidates = state.journals
        .where(
          (j) =>
              j.sourceRecordId == id &&
              (j.sourceType ==
                      RestaurantJournalSourceType.purchaseInvoice.name ||
                  (j.metadata['invoiceCorrection'] == true &&
                      j.sourceType ==
                          RestaurantJournalSourceType
                              .correctionReplacement
                              .name)) &&
              !state.journals.any((r) => r.journal.reversesId == j.journal.id),
        )
        .toList();
    return candidates.length == 1 ? candidates.single : null;
  }

  static bool validate({
    required PortableJournalState state,
    required String invoiceId,
    required RestaurantJournalMapper mapper,
    String? expectedActiveJournalId,
    DurableCommandIdentity? initialIdentity,
  }) {
    try {
      final cutover = state.cutoverState.cutoverDate;
      if (state.cutoverState.isGated ||
          !state.cutoverState.hasActivePosting ||
          cutover == null) {
        return false;
      }
      final roots = state.journals
          .where(
            (j) =>
                j.sourceRecordId == invoiceId &&
                j.sourceType ==
                    RestaurantJournalSourceType.purchaseInvoice.name,
          )
          .toList();
      if (roots.length != 1) return false;
      final root = roots.single;
      final receipt = _receipt(state, root.metadata['operationId']);
      final create = createFromIntent(_intent(receipt, state, invoiceId));
      if (create.identity != receipt.identity ||
          (initialIdentity != null && create.identity != initialIdentity) ||
          create.date.compareTo(cutover) < 0) {
        return false;
      }
      var source = _map(jsonDecode(root.metadata['sourceSnapshot']! as String));
      if (!RestaurantJournalSpendingCommandCoordinator.validateInvoiceCreateSnapshot(
        create,
        RestaurantJournalSpendingOutcome.fromOutcomePayload(
          receipt.outcomePayload!,
        ),
        state,
        mapper,
        source,
      )) {
        return false;
      }
      if (create.immediatePayment != null &&
          create.immediatePayment!.amount > 0 &&
          !RestaurantJournalPaymentHistory.validate(
            state: state,
            paymentId: create.immediatePayment!.id,
            mapper: mapper,
          )) {
        return false;
      }
      final ownedEntries = <String>{root.journal.id},
          ownedReceipts = <String>{receipt.identity.operationId};
      var sequence = receipt.sequence,
          journalIndex = state.journals.indexOf(root);
      PortableJournalEntry? active = root;
      while (active != null) {
        final reversals = state.journals
            .where((j) => j.journal.reversesId == active!.journal.id)
            .toList();
        if (reversals.isEmpty) break;
        if (reversals.length != 1) return false;
        final inverse = reversals.single,
            correctionReceipt = _receipt(
              state,
              reversals.single.metadata['operationId'],
            );
        final correction = commandFromIntent(
          _intent(correctionReceipt, state, invoiceId),
          mapper,
        );
        if (correction.identity != correctionReceipt.identity ||
            correction.expectedActiveJournalId != active.journal.id ||
            correction.expectedSourceVersion !=
                active.metadata['sourceVersion'] ||
            !_same(correction.expectedSource, source) ||
            correctionReceipt.sequence <= sequence ||
            !ownedReceipts.add(correction.operationId)) {
          return false;
        }
        Map<String, Object?>? after;
        if (correction is EditPurchaseInvoiceCommand) {
          after = _map(
            jsonDecode(inverse.metadata['afterSnapshot']! as String),
          );
          final submitted = correction.replacementIntent;
          final historical = CreatePurchaseInvoiceCommand(
            operationId: submitted.operationId,
            payloadVersion: submitted.payloadVersion,
            accountLineage: submitted.accountLineage,
            expectedFence: submitted.expectedFence,
            invoiceId: submitted.invoiceId,
            invoiceJournalId: submitted.invoiceJournalId,
            supplierId: submitted.supplierId,
            invoiceNumber: submitted.invoiceNumber,
            date: submitted.date,
            lines: submitted.lines,
            note: submitted.note,
            recordedAt: source['createdAt']! as String,
            policy: submitted.policy,
          );
          if (correction.date.compareTo(cutover) < 0 ||
              correction.supplierId != source['supplierId'] ||
              !RestaurantJournalSpendingCommandCoordinator.matchesInvoiceSourceSnapshot(
                after,
                historical,
              )) {
            return false;
          }
        }
        final expected = entries(
          command: correction,
          target: active,
          before: source,
          after: after,
          state: state,
          mapper: mapper,
        );
        for (final entry in expected) {
          final actual = state.journals.singleWhere(
            (j) => j.journal.id == entry.journal.id,
          );
          final index = state.journals.indexOf(actual);
          if (!ownedEntries.add(entry.journal.id) ||
              index <= journalIndex ||
              !_same(actual.toJson(), entry.toJson())) {
            return false;
          }
          journalIndex = index;
        }
        if (!_same(
          _map(jsonDecode(correctionReceipt.outcomePayload!)),
          outcome(correction, expected).toJson(),
        )) {
          return false;
        }
        sequence = correctionReceipt.sequence;
        if (correction is EditPurchaseInvoiceCommand) {
          active = expected.last;
          source = after!;
        } else {
          final restored = DeletedPartyRestorationHistory.afterDelete(
            state: state,
            kind: DeletedPartyKind.invoice,
            recordId: invoiceId,
            deleted: active,
            inverse: expected.single,
            deletion: correctionReceipt,
            source: source,
            mapper: mapper,
          );
          active = restored?.entry;
          if (restored != null) {
            if (!ownedEntries.add(restored.entry.journal.id) ||
                !ownedReceipts.add(restored.receipt.identity.operationId)) {
              return false;
            }
            sequence = restored.receipt.sequence;
            journalIndex = state.journals.indexOf(restored.entry);
          }
        }
      }
      if (expectedActiveJournalId != null &&
          active?.journal.id != expectedActiveJournalId) {
        return false;
      }
      for (final entry in state.journals) {
        if (((entry.sourceRecordId == invoiceId &&
                    entry.metadata['invoiceCorrection'] == true) ||
                ownedEntries.contains(entry.journal.reversesId) ||
                ownedEntries.contains(entry.correctedFromJournalId) ||
                ownedEntries.contains(entry.replacementJournalId)) &&
            !ownedEntries.contains(entry.journal.id)) {
          return false;
        }
      }
      for (final receipt in correctionReceiptViews(
        state,
      ).where((r) => r.status == DurableCommandStatus.committed)) {
        Object? intent;
        try {
          intent = jsonDecode(receipt.identity.canonicalPayloadIdentity);
        } on FormatException {
          continue;
        }
        if (intent is Map &&
            intent['invoiceId'] == invoiceId &&
            [
              'purchase_invoice',
              'edit_purchase_invoice',
              'delete_purchase_invoice',
              'restore_deleted_purchase_invoice',
            ].contains(intent['commandType']) &&
            !ownedReceipts.contains(receipt.identity.operationId)) {
          return false;
        }
      }
      final current = sourceRows(state, invoiceId);
      return active == null
          ? current.isEmpty
          : current.length == 1 && _same(current.single, source);
    } on Object {
      return false;
    }
  }

  static PurchaseInvoiceCorrectionCommand commandFromIntent(
    Map<String, Object?> intent,
    RestaurantJournalMapper mapper,
  ) {
    if (!_same(
          _map(intent['profile']),
          paymentProfileIdentity(mapper.profile),
        ) ||
        !_same(
          _map(intent['mapperDefaultPolicy']),
          paymentPolicyIdentity(mapper.defaultPolicy),
        )) {
      throw const FormatException('invoice_context_mismatch');
    }
    final replacement = intent['replacementIntent'] == null
        ? null
        : createFromIntent(_map(intent['replacementIntent']));
    if (intent['commandType'] == 'edit_purchase_invoice' &&
        replacement != null) {
      return EditPurchaseInvoiceCommand(
        operationId: intent['operationId']! as String,
        payloadVersion: intent['payloadVersion']! as int,
        accountLineage: intent['accountLineage']! as String,
        expectedFence: _fence(intent),
        invoiceId: intent['invoiceId']! as String,
        expectedActiveJournalId: intent['expectedActiveJournalId']! as String,
        expectedSource: _map(intent['expectedSource']),
        expectedSourceVersion: intent['expectedSourceVersion']! as int,
        inverseJournalId: intent['inverseJournalId']! as String,
        replacementJournalId: replacement.invoiceJournalId,
        supplierId: replacement.supplierId,
        invoiceNumber: replacement.invoiceNumber,
        date: replacement.date,
        lines: replacement.lines,
        note: replacement.note,
        materialRestoration: intent['materialRestoration'] == null
            ? null
            : SourceMaterialRestoration.fromJson(
                _map(intent['materialRestoration']),
              ),
        sourceOrder: intent['sourceOrder'] == null
            ? null
            : SourceRecordOrder.fromJson(_map(intent['sourceOrder'])),
        reason: intent['reason']! as String,
        recordedAt: intent['recordedAt']! as String,
        profile: mapper.profile,
        mapperDefaultPolicy: mapper.defaultPolicy,
        policy: _policy(intent['policy']),
      );
    }
    if (intent['commandType'] != 'delete_purchase_invoice') {
      throw const FormatException('invalid_invoice_correction_type');
    }
    return DeletePurchaseInvoiceCommand(
      operationId: intent['operationId']! as String,
      payloadVersion: intent['payloadVersion']! as int,
      accountLineage: intent['accountLineage']! as String,
      expectedFence: _fence(intent),
      invoiceId: intent['invoiceId']! as String,
      expectedActiveJournalId: intent['expectedActiveJournalId']! as String,
      expectedSource: _map(intent['expectedSource']),
      expectedSourceVersion: intent['expectedSourceVersion']! as int,
      inverseJournalId: intent['inverseJournalId']! as String,
      reason: intent['reason']! as String,
      recordedAt: intent['recordedAt']! as String,
      profile: mapper.profile,
      mapperDefaultPolicy: mapper.defaultPolicy,
      policy: _policy(intent['policy']),
    );
  }

  static Map<String, Object?> _map(Object? value) =>
      (value! as Map).cast<String, Object?>();
  static bool _same(Map<String, Object?> a, Map<String, Object?> b) =>
      canonicalIdentity(a) == canonicalIdentity(b);
  static DurableCommandReceipt _receipt(
    PortableJournalState state,
    Object? id,
  ) => correctionReceiptViews(state).singleWhere(
    (r) =>
        r.identity.operationId == id &&
        r.status == DurableCommandStatus.committed,
  );
  static Map<String, Object?> _intent(
    DurableCommandReceipt receipt,
    PortableJournalState state,
    String id,
  ) {
    final intent = _map(jsonDecode(receipt.identity.canonicalPayloadIdentity));
    if (intent['accountLineage'] != state.accountLineage ||
        intent['invoiceId'] != id ||
        intent['operationId'] != receipt.identity.operationId ||
        intent['payloadVersion'] != receipt.identity.payloadVersion ||
        _fence(intent) != receipt.fence) {
      throw const FormatException('invalid_invoice_receipt');
    }
    return intent;
  }

  static StorageFence? _fence(Map<String, Object?> intent) =>
      intent['expectedFence'] == null
      ? null
      : StorageFence(
          storeId: _map(intent['expectedFence'])['storeId']! as String,
          generation: _map(intent['expectedFence'])['generation']! as String,
        );
  static JournalPolicy? _policy(Object? value) {
    if (value == null) return null;
    final p = _map(value);
    return JournalPolicy(
      currency: p['currency']! as String,
      scale: p['scale']! as int,
      maximumLines: p['maximumLines']! as int,
      maximumLineUnits: BigInt.parse(p['maximumLineUnits']! as String),
      maximumSideUnits: BigInt.parse(p['maximumSideUnits']! as String),
      allowZeroLines: p['allowZeroLines']! as bool,
    );
  }

  static CreatePurchaseInvoiceCommand createFromIntent(Map<String, Object?> i) {
    final p = i['immediatePayment'] == null
        ? null
        : _map(i['immediatePayment']);
    return CreatePurchaseInvoiceCommand(
      operationId: i['operationId']! as String,
      payloadVersion: i['payloadVersion']! as int,
      accountLineage: i['accountLineage']! as String,
      expectedFence: _fence(i),
      invoiceId: i['invoiceId']! as String,
      invoiceJournalId: i['invoiceJournalId']! as String,
      supplierId: i['supplierId']! as String,
      invoiceNumber: i['invoiceNumber']! as String,
      date: DateOnly.parse(
        i['date']! as String,
        minimumYear: 1000,
        maximumYear: 9999,
      ),
      lines: (i['lines']! as List).map((v) {
        final l = _map(v);
        return PurchaseLine(
          materialIdForCreation: l['materialIdForCreation']! as String,
          name: l['name']! as String,
          unit: l['unit']! as String,
          quantityCartons: num.parse(l['quantityCartons']! as String),
          quantityPieces: num.parse(l['quantityPieces']! as String),
          priceCarton: l['priceCarton']! as int,
          pricePiece: l['pricePiece']! as int,
        );
      }),
      note: i['note']! as String,
      recordedAt: i['recordedAt']! as String,
      policy: _policy(i['policy']),
      immediatePayment: p == null
          ? null
          : PurchasePayment(
              id: p['id']! as String,
              amount: p['amount']! as int,
              source: p['source']! as String,
              dailyAmount: p['dailyAmount']! as int,
              cashAmount: p['cashAmount']! as int,
            ),
      paymentJournalId: i['paymentJournalId'] as String?,
    );
  }
}

final class RestaurantJournalInvoiceCorrectionCoordinator {
  RestaurantJournalInvoiceCorrectionCoordinator({
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
  Future<DurableCommandResult<RestaurantJournalInvoiceCorrectionOutcome>>
  execute(PurchaseInvoiceCorrectionCommand command) => host.execute(
    identity: command.identity,
    accountLineage: command.accountLineage,
    expectedFence: command.expectedFence,
    validateReplayOutcome: (payload, state) {
      try {
        final receipt = state.receipts.singleWhere(
          (r) =>
              r.identity == command.identity &&
              r.status == DurableCommandStatus.committed,
        );
        return receipt.outcomePayload == payload &&
            RestaurantJournalInvoiceHistory.validate(
              state: state,
              invoiceId: command.invoiceId,
              mapper: mapper,
            );
      } on Object {
        return false;
      }
    },
    parseOutcome: RestaurantJournalInvoiceCorrectionOutcome.fromOutcomePayload,
    evaluateProposal: (state, _) =>
        evaluate(command: command, state: state, mapper: mapper),
  );
  static DurableProposalEvaluation<
    PortableJournalState,
    RestaurantJournalInvoiceCorrectionOutcome
  >
  evaluate({
    required PurchaseInvoiceCorrectionCommand command,
    required PortableJournalState state,
    required RestaurantJournalMapper mapper,
  }) {
    DurableProposalEvaluation<
      PortableJournalState,
      RestaurantJournalInvoiceCorrectionOutcome
    >
    reject(String code) => DurableProposalEvaluation.reject(
      rejectionCode: code,
      rejectionMessage: 'Invoice correction rejected.',
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
      if (canonicalIdentity(paymentProfileIdentity(command.profile)) !=
              canonicalIdentity(paymentProfileIdentity(mapper.profile)) ||
          canonicalIdentity(
                paymentPolicyIdentity(command.mapperDefaultPolicy),
              ) !=
              canonicalIdentity(paymentPolicyIdentity(mapper.defaultPolicy))) {
        return reject('invoice_context_mismatch');
      }
      final rows = RestaurantJournalInvoiceHistory.sourceRows(
        state,
        command.invoiceId,
      );
      if (rows.length != 1) return reject('invoice_not_found_or_ambiguous');
      final before = rows.single;
      if (canonicalIdentity(before) !=
          canonicalIdentity(command.expectedSource)) {
        return reject('invoice_source_changed');
      }
      if ((before['date']! as String).compareTo(cutover.toString()) < 0 ||
          (command is EditPurchaseInvoiceCommand &&
              command.date.compareTo(cutover) < 0)) {
        return reject('pre_cutover_operation_rejected');
      }
      if (!RestaurantJournalInvoiceHistory.validate(
        state: state,
        invoiceId: command.invoiceId,
        mapper: mapper,
        expectedActiveJournalId: command.expectedActiveJournalId,
      )) {
        return reject('invoice_history_mismatch');
      }
      final target = state.journals.singleWhere(
        (j) => j.journal.id == command.expectedActiveJournalId,
      );
      if (target.metadata['sourceVersion'] != command.expectedSourceVersion) {
        return reject('invoice_source_version_changed');
      }
      final ids = [
        command.inverseJournalId,
        if (command is EditPurchaseInvoiceCommand) command.replacementJournalId,
      ];
      if (state.journals.any((j) => ids.contains(j.journal.id))) {
        return reject('duplicate_journal_id');
      }
      final proposals = PurchaseProposals(state.account);
      var candidate = command is EditPurchaseInvoiceCommand
          ? proposals.invoice(
              id: command.invoiceId,
              supplierId: command.supplierId,
              number: command.invoiceNumber,
              date: command.date.toString(),
              createdAt: before['createdAt']! as String,
              lines: command.lines,
              note: command.note,
              editing: true,
            )
          : proposals.removeInvoice(command.invoiceId);
      if (command is EditPurchaseInvoiceCommand &&
          command.sourceOrder != null) {
        candidate = command.sourceOrder!.apply(
          candidate,
          'invoices',
          command.invoiceId,
        );
      }
      if (command is EditPurchaseInvoiceCommand &&
          command.materialRestoration != null) {
        candidate = command.materialRestoration!.apply(candidate);
      }
      final after = command is EditPurchaseInvoiceCommand
          ? (candidate.toJson()['invoices']! as List)
                .cast<Map<String, Object?>>()
                .singleWhere((i) => i['id'] == command.invoiceId)
          : null;
      final entries = RestaurantJournalInvoiceHistory.entries(
        command: command,
        target: target,
        before: before,
        after: after,
        state: state,
        mapper: mapper,
      );
      final complete = state.copyWith(
        account: candidate,
        journals: [...state.journals, ...entries],
      );
      return DurableProposalEvaluation.accept(
        candidateState: complete,
        outcome: RestaurantJournalInvoiceHistory.outcome(command, entries),
        outcomePayload: RestaurantJournalInvoiceHistory.outcome(
          command,
          entries,
        ).toOutcomePayload(),
      );
    } on FormatException catch (error) {
      return reject(error.message);
    } on Object {
      return reject('invalid_invoice_correction');
    }
  }
}
