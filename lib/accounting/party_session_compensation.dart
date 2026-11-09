import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:madar_application/madar_application.dart';

import '../accounts/account_document.dart';
import '../accounts/legacy_account_codec.dart';
import '../accounts/portable_journal_state.dart';
import '../accounts/portable_metadata_validation.dart';
import 'journal_command_host.dart';
import 'restaurant_journal_invoice_correction_commands.dart';
import 'restaurant_journal_mapper.dart';
import 'restaurant_journal_payment_correction_commands.dart';
import 'restaurant_journal_payment_history.dart';

Map<String, Object?> _map(Object? v) => (v! as Map).cast<String, Object?>();
bool _same(Object? a, Object? b) =>
    canonicalIdentity({'value': a}) == canonicalIdentity({'value': b});
String _digest(PortableJournalState s) =>
    sha256.convert(utf8.encode(canonicalIdentity(s.toJson()))).toString();

/// One real durable parent compensates an invoice and its optional original
/// inline payment. Captured child evidence is exposed only as read-only views.
final class PartySessionCompensationCommand {
  PartySessionCompensationCommand.fromIntent(Map<String, Object?> value)
    : intent = freezeMap(value) {
    if (intent['commandType'] != 'party_session_compensation' ||
        intent['payloadVersion'] != 1 ||
        intent['expectedRevision'] is! int ||
        (intent['expectedRevision']! as int) < 0 ||
        !RegExp(r'^[0-9a-f]{64}$')
            .hasMatch(intent['expectedStateDigest']! as String) ||
        (intent['reason']! as String).trim().isEmpty) {
      throw const FormatException('invalid_party_compensation');
    }
    canonicalPayloadIdentity = canonicalIdentity(intent);
  }
  final Map<String, Object?> intent;
  late final String canonicalPayloadIdentity;
  String get operationId => intent['operationId']! as String;
  String get accountLineage => intent['accountLineage']! as String;
  StorageFence get fence => StorageFence(
    storeId: _map(intent['expectedFence'])['storeId']! as String,
    generation: _map(intent['expectedFence'])['generation']! as String,
  );
  DurableCommandIdentity get identity => DurableCommandIdentity(
    operationId: operationId,
    payloadVersion: 1,
    canonicalPayloadIdentity: canonicalPayloadIdentity,
  );
  factory PartySessionCompensationCommand.capture({
    required String operationId,
    required DocumentSnapshot snapshot,
    required PortableJournalState state,
    required AccountDocument restoredAccount,
    required DurableCommandIdentity originalIdentity,
    required List<Map<String, Object?>> children,
    required String reason,
  }) => PartySessionCompensationCommand.fromIntent({
    'commandType': 'party_session_compensation',
    'payloadVersion': 1,
    'operationId': operationId,
    'accountLineage': state.accountLineage,
    'expectedFence': {
      'storeId': snapshot.fence.storeId,
      'generation': snapshot.fence.generation,
    },
    'expectedRevision': snapshot.revision,
    'expectedStateDigest': _digest(state),
    'expectedAccount': state.account.toJson(),
    'restoredAccount': restoredAccount.toJson(),
    'originalOperationId': originalIdentity.operationId,
    'originalCanonicalIdentity': originalIdentity.canonicalPayloadIdentity,
    'children': children,
    'reason': reason,
  });
}

final class PartySessionCompensationOutcome {
  PartySessionCompensationOutcome(Map<String, Object?> value)
    : values = freezeMap(value);
  final Map<String, Object?> values;
  String toOutcomePayload() => canonicalIdentity(values);
  factory PartySessionCompensationOutcome.parse(String payload) =>
      PartySessionCompensationOutcome(_map(jsonDecode(payload)));
}

/// Structural source and parent-child binding only. Family mappers validate
/// posting proofs separately, preventing recursion through receipt views.
void validatePartyCompensationEnvelope(
  PortableJournalState state,
  DurableCommandReceipt receipt,
  Map<String, Object?> intent,
  Map<String, Object?> output,
) {
  void require(bool value) {
    if (!value) {
      throw const FormatException('invalid_party_compensation_evidence');
    }
  }

  require(
    intent['commandType'] == 'party_session_compensation' &&
        intent['accountLineage'] == state.accountLineage &&
        intent['operationId'] == receipt.identity.operationId &&
        intent['payloadVersion'] == receipt.identity.payloadVersion &&
        _same(intent['expectedFence'], {
          'storeId': receipt.fence.storeId,
          'generation': receipt.fence.generation,
        }) &&
        receipt.committedRevision == (intent['expectedRevision']! as int) + 1 &&
        output['commandType'] == intent['commandType'] &&
        output['operationId'] == intent['operationId'],
  );
  final original = state.receipts.singleWhere(
    (r) =>
        r.identity.operationId == intent['originalOperationId'] &&
        r.status == DurableCommandStatus.committed,
  );
  require(
    original.identity.canonicalPayloadIdentity ==
        intent['originalCanonicalIdentity'],
  );
  final creation = _map(jsonDecode(original.identity.canonicalPayloadIdentity));
  require(creation['commandType'] == 'purchase_invoice');
  final invoiceId = creation['invoiceId'];
  final immediate = (creation['immediatePayment'] as Map?)
      ?.cast<String, Object?>();
  final hasPayment = immediate != null && (immediate['amount']! as int) > 0;
  final expected = (intent['children']! as List).map(_map).toList(),
      actual = (output['children']! as List).map(_map).toList();
  require(
    expected.length == (hasPayment ? 2 : 1) && actual.length == expected.length,
  );
  require(
    expected.last['commandType'] == 'delete_purchase_invoice' &&
        expected.last['invoiceId'] == invoiceId,
  );
  if (hasPayment) {
    require(
      expected.first['commandType'] == 'delete_supplier_payment' &&
          expected.first['paymentId'] == immediate['id'],
    );
  }
  final reserved = <String>{};
  for (final other in state.receipts) {
    if (other.identity == receipt.identity) continue;
    reserved.add(other.identity.operationId);
    try {
      final map = _map(jsonDecode(other.identity.canonicalPayloadIdentity));
      if ([
        'day_date_correction',
        'party_session_compensation',
      ].contains(map['commandType'])) {
        for (final child in map['children']! as List) {
          reserved.add(_map(child)['operationId']! as String);
        }
      }
    } on Object {
      /* Unrelated opaque identities. */
    }
  }
  final before = const LegacyAccountCodec().decodeJson(
    _map(intent['expectedAccount']),
  );
  final target = const LegacyAccountCodec().decodeJson(
    _map(intent['restoredAccount']),
  );
  final raw = {...before.toJson()};
  final seen = <String>{};
  for (var index = 0; index < expected.length; index++) {
    final ci = expected[index],
        child = actual[index],
        proof = _map(child['intent']);
    require(
      _same(ci, proof) &&
          ci['accountLineage'] == state.accountLineage &&
          _same(ci['expectedFence'], intent['expectedFence']) &&
          seen.add(ci['operationId']! as String) &&
          !reserved.contains(ci['operationId']) &&
          ci['operationId'] != receipt.identity.operationId,
    );
    final key = ci['commandType'] == 'delete_supplier_payment'
            ? 'payments'
            : 'invoices',
        id = ci[key == 'payments' ? 'paymentId' : 'invoiceId'];
    final rows = (raw[key]! as List).map(_map).toList(),
        matching = rows.where((r) => r['id'] == id).toList();
    require(
      matching.length == 1 && _same(matching.single, ci['expectedSource']),
    );
    raw[key] = rows.where((r) => r['id'] != id).toList();
    final outcome = _map(child['outcome']);
    require(
      outcome['operationId'] == ci['operationId'] &&
          outcome['commandType'] == ci['commandType'],
    );
    final entries = (child['entries']! as List).map(_map).toList();
    require(entries.length == 1);
    for (final entry in entries) {
      final matching = state.journals
          .where((j) => j.journal.id == entry['id'])
          .toList();
      require(matching.length == 1 && _same(matching.single.toJson(), entry));
    }
  }
  // Only inline material metadata may accompany the financial compensation.
  final financiallyRestored = const LegacyAccountCodec().decodeJson(raw);
  validatePortableMetadataChange(financiallyRestored, target);
  require(
    _same({...raw, 'materials': target.toJson()['materials']}, target.toJson()),
  );
  require(_same(output['afterAccount'], target.toJson()));
}

final class PartySessionCompensationCoordinator {
  PartySessionCompensationCoordinator({
    required this.host,
    required this.mapper,
  });
  final JournalCommandHost host;
  final RestaurantJournalMapper mapper;
  void _families(PartySessionCompensationCommand c, PortableJournalState s) {
    for (final raw in c.intent['children']! as List) {
      final ci = _map(raw);
      final valid = ci['commandType'] == 'delete_supplier_payment'
          ? RestaurantJournalPaymentHistory.validate(
              state: s,
              paymentId: ci['paymentId']! as String,
              mapper: mapper,
            )
          : RestaurantJournalInvoiceHistory.validate(
              state: s,
              invoiceId: ci['invoiceId']! as String,
              mapper: mapper,
            );
      if (!valid) {
        throw const FormatException('party_compensation_history_mismatch');
      }
    }
  }

  (PortableJournalState, PartySessionCompensationOutcome) materialize(
    PartySessionCompensationCommand c,
    PortableJournalState state, {
    required bool validateActive,
  }) {
    final before = const LegacyAccountCodec().decodeJson(
      _map(c.intent['expectedAccount']),
    );
    final targetAccount = const LegacyAccountCodec().decodeJson(
      _map(c.intent['restoredAccount']),
    );
    final entries = <PortableJournalEntry>[],
        children = <Map<String, Object?>>[];
    if (validateActive && !_same(before.toJson(), state.account.toJson())) {
      throw const FormatException('party_compensation_source_changed');
    }
    for (final raw in c.intent['children']! as List) {
      final ci = _map(raw),
          target = state.journals.singleWhere(
            (j) => j.journal.id == ci['expectedActiveJournalId'],
          );
      final source = _map(ci['expectedSource']);
      late List<PortableJournalEntry> mapped;
      late Map<String, Object?> output;
      if (ci['commandType'] == 'delete_supplier_payment') {
        final command = RestaurantJournalPaymentHistory.commandFromIntent(
          ci,
        ) as DeleteSupplierPaymentCommand;
        if (command.identity.canonicalPayloadIdentity !=
            canonicalIdentity(ci)) {
          throw const FormatException('invalid_party_child');
        }
        if (validateActive &&
            !RestaurantJournalPaymentHistory.validate(
              state: state,
              paymentId: command.paymentId,
              mapper: mapper,
              expectedActiveJournalId: target.journal.id,
            )) {
          throw const FormatException('invalid_payment_history');
        }
        mapped = RestaurantJournalPaymentHistory.correctionEntries(
          command: command,
          target: target,
          beforeSnapshot: source,
          mapper: mapper,
        );
        output = RestaurantJournalPaymentHistory.outcome(
          command: command,
          target: target,
          entries: mapped,
        ).toJson();
      } else if (ci['commandType'] == 'delete_purchase_invoice') {
        final command = RestaurantJournalInvoiceHistory.commandFromIntent(
          ci,
          mapper,
        ) as DeletePurchaseInvoiceCommand;
        if (command.identity.canonicalPayloadIdentity !=
            canonicalIdentity(ci)) {
          throw const FormatException('invalid_party_child');
        }
        if (validateActive &&
            !RestaurantJournalInvoiceHistory.validate(
              state: state,
              invoiceId: command.invoiceId,
              mapper: mapper,
              expectedActiveJournalId: target.journal.id,
            )) {
          throw const FormatException('invalid_invoice_history');
        }
        mapped = RestaurantJournalInvoiceHistory.entries(
          command: command,
          target: target,
          before: source,
          after: null,
          state: state.copyWith(account: before),
          mapper: mapper,
        );
        output = RestaurantJournalInvoiceHistory.outcome(
          command,
          mapped,
        ).toJson();
      } else {
        throw const FormatException('invalid_party_child_kind');
      }
      if (mapped.any(
            (j) => state.journals.any((old) => old.journal.id == j.journal.id),
          ) &&
          validateActive) {
        throw const FormatException('duplicate_journal_id');
      }
      entries.addAll(mapped);
      children.add({
        'intent': ci,
        'outcome': output,
        'entries': mapped.map((j) => j.toJson()).toList(),
      });
    }
    final outcome = PartySessionCompensationOutcome({
      'commandType': 'party_session_compensation',
      'operationId': c.operationId,
      'afterAccount': targetAccount.toJson(),
      'children': children,
    });
    return (
      state.copyWith(
        account: targetAccount,
        journals: validateActive
            ? [...state.journals, ...entries]
            : state.journals,
      ),
      outcome,
    );
  }

  DurableProposalEvaluation<
    PortableJournalState,
    PartySessionCompensationOutcome
  >
  evaluate(
    PartySessionCompensationCommand c,
    PortableJournalState state,
    StorageFence fence,
  ) {
    try {
      if (c.accountLineage != state.accountLineage || c.fence != fence) {
        throw const FormatException('stale_authority_fence');
      }
      if (state.cutoverState.isGated || !state.cutoverState.hasActivePosting) {
        throw const FormatException('cutover_gated');
      }
      if (_digest(state) != c.intent['expectedStateDigest']) {
        throw const FormatException('party_compensation_source_changed');
      }
      final result = materialize(c, state, validateActive: true);
      final receipt = DurableCommandReceipt(
        identity: c.identity,
        status: DurableCommandStatus.committed,
        outcomePayload: result.$2.toOutcomePayload(),
        committedRevision: (c.intent['expectedRevision']! as int) + 1,
        fence: fence,
        sequence: state.receipts.length + 1,
      );
      final proof = result.$1.copyWith(receipts: [...state.receipts, receipt]);
      validatePartyCompensationEnvelope(
        proof,
        receipt,
        c.intent,
        result.$2.values,
      );
      _families(c, proof);
      return DurableProposalEvaluation.accept(
        candidateState: result.$1,
        outcome: result.$2,
        outcomePayload: result.$2.toOutcomePayload(),
      );
    } on FormatException catch (e) {
      return DurableProposalEvaluation.reject(
        rejectionCode: e.message,
        rejectionMessage: 'Atomic party compensation refused.',
      );
    } on Object {
      return const DurableProposalEvaluation.reject(
        rejectionCode: 'invalid_party_compensation',
        rejectionMessage: 'Atomic party compensation refused.',
      );
    }
  }

  Future<DurableCommandResult<PartySessionCompensationOutcome>> execute(
    PartySessionCompensationCommand c,
  ) => host.execute(
    identity: c.identity,
    accountLineage: c.accountLineage,
    expectedFence: c.fence,
    expectedRevision: c.intent['expectedRevision']! as int,
    parseOutcome: PartySessionCompensationOutcome.parse,
    validateReplayOutcome: (payload, state) {
      try {
        final receipt = state.receipts.singleWhere(
              (r) =>
                  r.identity == c.identity &&
                  r.status == DurableCommandStatus.committed,
            ),
            output = PartySessionCompensationOutcome.parse(payload);
        validatePartyCompensationEnvelope(
          state,
          receipt,
          c.intent,
          output.values,
        );
        final rebuilt = materialize(c, state, validateActive: false);
        if (!_same(rebuilt.$2.values, output.values)) return false;
        _families(c, state);
        return true;
      } on Object {
        return false;
      }
    },
    evaluateProposal: (state, fence) => evaluate(c, state, fence),
  );
}
