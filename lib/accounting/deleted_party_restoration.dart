import 'dart:convert';

import 'package:madar_application/madar_application.dart';
import 'package:madar_domain/madar_domain.dart';

import '../accounts/legacy_account_codec.dart';
import '../accounts/portable_journal_state.dart';
import '../parties/purchase_proposal.dart';
import '../parties/supplier_ledger.dart';
import 'correction_batch_receipts.dart';
import 'journal_command_host.dart';
import 'restaurant_journal_invoice_correction_commands.dart';
import 'restaurant_journal_mapper.dart';
import 'restaurant_journal_payment_correction_commands.dart';
import 'restaurant_journal_payment_history.dart';
import 'restaurant_journal_spending_commands.dart';

Map<String, Object?> _map(Object? v) => (v! as Map).cast<String, Object?>();
bool _same(Object? a, Object? b) =>
    canonicalIdentity({'v': a}) == canonicalIdentity({'v': b});

enum DeletedPartyKind { invoice, payment }

/// Retains the deleted source identity and order; restoration creates a new
/// replacement posting and never reverses or removes the deletion inverse.
final class RestoreDeletedPartyCommand {
  RestoreDeletedPartyCommand({
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
  }) : sourceSnapshot = freezeMap(sourceSnapshot),
       expectedSiblingIds = List.unmodifiable(expectedSiblingIds),
       context = freezeMap({
         'profile': paymentProfileIdentity(mapper.profile),
         'policy': paymentPolicyIdentity(mapper.defaultPolicy),
       }) {
    if ([
          operationId,
          accountLineage,
          recordId,
          deletedJournalId,
          deleteInverseJournalId,
          deleteOperationId,
          replacementJournalId,
          recordedAt,
        ].any((s) => s.isEmpty || s.trim() != s) ||
        reason.trim().isEmpty ||
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
      throw const FormatException('invalid_party_restoration_intent');
    }
    canonicalPayloadIdentity = canonicalIdentity(toJson());
  }
  final DeletedPartyKind kind;
  final String operationId,
      accountLineage,
      recordId,
      deletedJournalId,
      deleteInverseJournalId,
      deleteOperationId,
      replacementJournalId,
      reason,
      recordedAt;
  final StorageFence? expectedFence;
  final int position;
  final List<String> expectedSiblingIds;
  final Map<String, Object?> sourceSnapshot, context;
  late final String canonicalPayloadIdentity;
  String get commandType => kind == DeletedPartyKind.invoice
      ? 'restore_deleted_purchase_invoice'
      : 'restore_deleted_supplier_payment';
  String get idKey =>
      kind == DeletedPartyKind.invoice ? 'invoiceId' : 'paymentId';
  String get collection =>
      kind == DeletedPartyKind.invoice ? 'invoices' : 'payments';
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
    idKey: recordId,
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
    'context': context,
  };
  static RestoreDeletedPartyCommand fromIntent(
    Map<String, Object?> i,
    RestaurantJournalMapper mapper,
  ) {
    final kind = switch (i['commandType']) {
      'restore_deleted_purchase_invoice' => DeletedPartyKind.invoice,
      'restore_deleted_supplier_payment' => DeletedPartyKind.payment,
      _ => throw const FormatException('invalid_party_restoration_kind'),
    };
    if (i['payloadVersion'] != 1 ||
        i['sourceVersion'] != 11 ||
        !_same(i['context'], {
          'profile': paymentProfileIdentity(mapper.profile),
          'policy': paymentPolicyIdentity(mapper.defaultPolicy),
        })) {
      throw const FormatException('restoration_context_mismatch');
    }
    final f = i['expectedFence'] == null ? null : _map(i['expectedFence']);
    return RestoreDeletedPartyCommand(
      kind: kind,
      operationId: i['operationId']! as String,
      accountLineage: i['accountLineage']! as String,
      expectedFence: f == null
          ? null
          : StorageFence(
              storeId: f['storeId']! as String,
              generation: f['generation']! as String,
            ),
      recordId:
          i[kind == DeletedPartyKind.invoice ? 'invoiceId' : 'paymentId']!
              as String,
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
    );
  }
}

final class PartyRestorationOutcome {
  PartyRestorationOutcome(Map<String, Object?> values)
    : values = freezeMap(values);
  final Map<String, Object?> values;
  String toOutcomePayload() => canonicalIdentity(values);
  factory PartyRestorationOutcome.parse(String payload) =>
      PartyRestorationOutcome(_map(jsonDecode(payload)));
}

abstract final class DeletedPartyRestorationHistory {
  static Map<String, Object?> outcome(RestoreDeletedPartyCommand c) => {
    'commandType': c.commandType,
    'operationId': c.operationId,
    c.idKey: c.recordId,
    'replacementJournalId': c.replacementJournalId,
    'deletedJournalId': c.deletedJournalId,
    'deleteInverseJournalId': c.deleteInverseJournalId,
    'deleteOperationId': c.deleteOperationId,
    'sourceSnapshot': c.sourceSnapshot,
    'position': c.position,
  };
  static PortableJournalEntry entry(
    RestoreDeletedPartyCommand c,
    PortableJournalEntry target,
    RestaurantJournalMapper mapper,
    PortableJournalState state,
  ) {
    final row = c.sourceSnapshot,
        date = DateOnly.parse(
          row['date']! as String,
          minimumYear: 1000,
          maximumYear: 9999,
        );
    final funding = c.kind == DeletedPartyKind.payment
        ? _map(row['funding'])
        : null;
    var proposal = c.kind == DeletedPartyKind.invoice
        ? mapper.mapPurchaseInvoice(
            journalId: c.replacementJournalId,
            invoiceId: c.recordId,
            invoiceNumber: row['number']! as String,
            supplierId: row['supplierId']! as String,
            effectiveDate: date,
            amount: SupplierLedgerQueries(
              state.account,
              compareText: (_, _) =>
                  throw StateError('No ordered restoration query'),
            ).invoiceTotal(row),
            policy: target.journal.policy,
          )
        : mapper.mapSupplierPayment(
            journalId: c.replacementJournalId,
            paymentId: c.recordId,
            supplierId: row['supplierId']! as String,
            invoiceId: row['invoiceId'] as String?,
            effectiveDate: date,
            amount: BigInt.from(row['amount']! as int),
            dailyAmount: BigInt.from(funding!['dailyAmount']! as int),
            cashboxAmount: BigInt.from(funding['cashAmount']! as int),
            invoiceSettledAmount: BigInt.from(row['invoiceAmount']! as int),
            debtSettledAmount: BigInt.from(row['debtAmount']! as int),
            policy: target.journal.policy,
          );
    Map<String, Object?> values(BalancedJournal j) => {
      'date': j.effectiveDate.toString(),
      'policy': paymentPolicyIdentity(j.policy),
      'lines': [
        for (final l in j.lines)
          {
            'accountId': l.accountId,
            'side': l.side.name,
            'amount': l.amountUnits.toString(),
            'currency': l.currency,
            'scale': l.scale,
          },
      ],
    };
    if (!_same(values(proposal.journal), values(target.journal))) {
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
        'undoPartyRestoration': true,
        if (c.kind == DeletedPartyKind.invoice) 'invoiceCorrection': true,
        'operationId': c.operationId,
        c.idKey: c.recordId,
        'sourceVersion': 11,
        'deletedJournalId': c.deletedJournalId,
        'deleteInverseJournalId': c.deleteInverseJournalId,
        'deleteOperationId': c.deleteOperationId,
        'sourceSnapshot': canonicalIdentity(row),
        'reason': c.reason.trim(),
      },
    );
  }

  static ({PortableJournalEntry entry, DurableCommandReceipt receipt})?
  afterDelete({
    required PortableJournalState state,
    required DeletedPartyKind kind,
    required String recordId,
    required PortableJournalEntry deleted,
    required PortableJournalEntry inverse,
    required DurableCommandReceipt deletion,
    required Map<String, Object?> source,
    required RestaurantJournalMapper mapper,
  }) {
    final matches = state.journals
        .where(
          (j) =>
              j.metadata['undoPartyRestoration'] == true &&
              j.correctedFromJournalId == deleted.journal.id,
        )
        .toList();
    if (matches.isEmpty) return null;
    if (matches.length != 1) {
      throw const FormatException('ambiguous_party_restoration');
    }
    final actual = matches.single;
    final receipt = correctionReceiptViews(state).singleWhere(
      (r) =>
          r.status == DurableCommandStatus.committed &&
          r.identity.operationId == actual.metadata['operationId'],
    );
    final c = RestoreDeletedPartyCommand.fromIntent(
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
        !_same(actual.toJson(), entry(c, deleted, mapper, state).toJson()) ||
        receipt.outcomePayload == null ||
        !_same(_map(jsonDecode(receipt.outcomePayload!)), outcome(c))) {
      throw const FormatException('invalid_party_restoration_history');
    }
    return (entry: actual, receipt: receipt);
  }
}

final class DeletedPartyRestorationCoordinator {
  DeletedPartyRestorationCoordinator({
    required this.host,
    required this.mapper,
  });
  final JournalCommandHost host;
  final RestaurantJournalMapper mapper;
  bool validate(PortableJournalState state, DeletedPartyKind kind, String id) =>
      kind == DeletedPartyKind.invoice
      ? RestaurantJournalInvoiceHistory.validate(
          state: state,
          invoiceId: id,
          mapper: mapper,
        )
      : RestaurantJournalPaymentHistory.validate(
          state: state,
          paymentId: id,
          mapper: mapper,
        );
  Future<DurableCommandResult<PartyRestorationOutcome>> execute(
    RestoreDeletedPartyCommand c,
  ) => host.execute(
    identity: c.identity,
    accountLineage: c.accountLineage,
    expectedFence: c.expectedFence,
    validateReplayOutcome: (payload, state) =>
        validate(state, c.kind, c.recordId) &&
        state.receipts.any(
          (r) =>
              r.identity == c.identity &&
              r.status == DurableCommandStatus.committed &&
              r.outcomePayload == payload,
        ),
    parseOutcome: PartyRestorationOutcome.parse,
    evaluateProposal: (state, _) => evaluate(c, state),
  );
  DurableProposalEvaluation<PortableJournalState, PartyRestorationOutcome>
  evaluate(RestoreDeletedPartyCommand c, PortableJournalState state) {
    DurableProposalEvaluation<PortableJournalState, PartyRestorationOutcome>
    reject(String code) => DurableProposalEvaluation.reject(
      rejectionCode: code,
      rejectionMessage: 'Deleted party record restoration refused.',
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
      final date = DateOnly.parse(
        c.sourceSnapshot['date']! as String,
        minimumYear: 1000,
        maximumYear: 9999,
      );
      if (date.compareTo(cutover) < 0) {
        return reject('pre_cutover_operation_rejected');
      }
      if (!validate(state, c.kind, c.recordId)) {
        return reject('invalid_deleted_party_family');
      }
      final target = state.journals.singleWhere(
            (j) => j.journal.id == c.deletedJournalId,
          ),
          inverse = state.journals.singleWhere(
            (j) => j.journal.id == c.deleteInverseJournalId,
          );
      final deletion = correctionReceiptViews(state).singleWhere(
        (r) =>
            r.identity.operationId == c.deleteOperationId &&
            r.status == DurableCommandStatus.committed,
      );
      final intent = _map(
        jsonDecode(deletion.identity.canonicalPayloadIdentity),
      );
      if (intent['commandType'] !=
              (c.kind == DeletedPartyKind.invoice
                  ? 'delete_purchase_invoice'
                  : 'delete_supplier_payment') ||
          intent[c.idKey] != c.recordId ||
          intent['expectedActiveJournalId'] != c.deletedJournalId ||
          intent['inverseJournalId'] != c.deleteInverseJournalId ||
          inverse.journal.reversesId != target.journal.id ||
          inverse.metadata['operationId'] != c.deleteOperationId ||
          target.sourceRecordId != c.recordId ||
          state.journals.any(
            (j) =>
                j.metadata['undoPartyRestoration'] == true &&
                j.correctedFromJournalId == target.journal.id,
          )) {
        return reject('restoration_delete_changed');
      }
      final retained = inverse.metadata['beforeSnapshot'];
      if (!_same(
        retained is String ? jsonDecode(retained) : retained,
        c.sourceSnapshot,
      )) {
        return reject('restoration_source_changed');
      }
      final rows = (state.account.toJson()[c.collection]! as List)
          .cast<Map<String, Object?>>();
      if (rows.any((r) => r['id'] == c.recordId) ||
          !_same(rows.map((r) => r['id']).toList(), c.expectedSiblingIds)) {
        return reject('restoration_source_order_changed');
      }
      // Existing create evaluators independently check current liabilities,
      // allocation and source validity; their hypothetical root is not persisted.
      final r = c.sourceSnapshot;
      final DurableProposalEvaluation<PortableJournalState, dynamic> proposal;
      if (c.kind == DeletedPartyKind.invoice) {
        proposal = RestaurantJournalSpendingCommandCoordinator.evaluateInvoice(
          command: CreatePurchaseInvoiceCommand(
            operationId: c.operationId,
            accountLineage: c.accountLineage,
            expectedFence: c.expectedFence,
            invoiceId: c.recordId,
            invoiceJournalId: c.replacementJournalId,
            supplierId: r['supplierId']! as String,
            invoiceNumber: r['number']! as String,
            date: date,
            lines: (r['lines']! as List).map((v) {
              final l = _map(v);
              return PurchaseLine(
                materialIdForCreation: l['materialId']! as String,
                name: l['name']! as String,
                unit: l['unit']! as String,
                quantityCartons: l['quantityCartons'] as num? ?? 0,
                quantityPieces:
                    l['quantityPieces'] as num? ?? l['quantity'] as num? ?? 0,
                priceCarton: l['priceCarton'] as int? ?? 0,
                pricePiece: l['pricePiece'] as int? ?? l['price'] as int? ?? 0,
              );
            }),
            note: r['note']! as String,
            recordedAt: r['createdAt']! as String,
            policy: target.journal.policy,
          ),
          state: state,
          cutoverDate: cutover,
          mapper: mapper,
        );
      } else {
        final funding = _map(r['funding']);
        proposal = RestaurantJournalSpendingCommandCoordinator.evaluatePayment(
          command: CreateSupplierPaymentCommand(
            operationId: c.operationId,
            accountLineage: c.accountLineage,
            expectedFence: c.expectedFence,
            paymentId: c.recordId,
            journalId: c.replacementJournalId,
            supplierId: r['supplierId']! as String,
            invoiceId: r['invoiceId'] as String?,
            categoryId: r['categoryId']! as String,
            date: date,
            amount: BigInt.from(r['amount']! as int),
            fundingSource: FundingSource.values.byName(
              funding['source']! as String,
            ),
            dailyAmount: BigInt.from(funding['dailyAmount']! as int),
            cashAmount: BigInt.from(funding['cashAmount']! as int),
            note: r['note']! as String,
            recordedAt: r['createdAt']! as String,
            policy: target.journal.policy,
          ),
          state: state,
          cutoverDate: cutover,
          mapper: mapper,
        );
      }
      if (proposal.rejected) {
        return reject(proposal.rejectionCode ?? 'party_restoration_rejected');
      }
      final candidate = proposal.candidateState!.account;
      final restored = (candidate.toJson()[c.collection]! as List)
          .cast<Map<String, Object?>>()
          .singleWhere((row) => row['id'] == c.recordId);
      if (!_same(restored, c.sourceSnapshot)) {
        return reject('restoration_allocation_changed');
      }
      final ordered = [...rows]..insert(c.position, restored);
      final account = const LegacyAccountCodec().decodeJson({
        ...candidate.toJson(),
        c.collection: ordered,
      });
      final posting = DeletedPartyRestorationHistory.entry(
        c,
        target,
        mapper,
        state,
      );
      final outcome = PartyRestorationOutcome(
        DeletedPartyRestorationHistory.outcome(c),
      );
      return DurableProposalEvaluation.accept(
        candidateState: state.copyWith(
          account: account,
          journals: [...state.journals, posting],
        ),
        outcome: outcome,
        outcomePayload: outcome.toOutcomePayload(),
      );
    } on RestaurantJournalMappingException catch (e) {
      return reject(e.code);
    } on FormatException catch (e) {
      return reject(e.message);
    } on Object {
      return reject('invalid_party_restoration');
    }
  }
}
