import 'dart:convert';

import 'package:madar_application/madar_application.dart';

import '../accounts/legacy_account_codec.dart';
import '../accounts/portable_journal_state.dart';
import 'day_date_plan.dart';
import 'party_session_compensation.dart';
import 'journal_command_host.dart';

/// Read-only views of nested correction evidence. Only the parent receipt is
/// persisted. Views retain its revision, sequence and authority provenance.
Iterable<DurableCommandReceipt> correctionReceiptViews(
  PortableJournalState state,
) sync* {
  for (final receipt in state.receipts) {
    yield receipt;
    if (receipt.status != DurableCommandStatus.committed) continue;
    Object? decoded;
    try {
      decoded = jsonDecode(receipt.identity.canonicalPayloadIdentity);
    } on FormatException {
      continue;
    }
    if (decoded is! Map) continue;
    final intent = decoded.cast<String, Object?>();
    if (![
      'day_date_correction',
      'party_session_compensation',
    ].contains(intent['commandType'])) {
      continue;
    }
    final output = (jsonDecode(receipt.outcomePayload!) as Map)
        .cast<String, Object?>();
    if (intent['commandType'] == 'day_date_correction') {
      validateDayDateBatchEnvelope(state, receipt, intent, output);
    } else {
      validatePartyCompensationEnvelope(state, receipt, intent, output);
    }
    for (final raw in output['children']! as List) {
      final child = (raw as Map).cast<String, Object?>();
      final childIntent = (child['intent']! as Map).cast<String, Object?>();
      yield DurableCommandReceipt(
        identity: DurableCommandIdentity(
          operationId: childIntent['operationId']! as String,
          payloadVersion: childIntent['payloadVersion']! as int,
          canonicalPayloadIdentity: canonicalIdentity(childIntent),
        ),
        status: DurableCommandStatus.committed,
        outcomePayload: canonicalIdentity(
          (child['outcome']! as Map).cast<String, Object?>(),
        ),
        committedRevision: receipt.committedRevision,
        fence: receipt.fence,
        sequence: receipt.sequence,
      );
    }
  }
}

void validateDayDateBatchEnvelope(
  PortableJournalState state,
  DurableCommandReceipt receipt,
  Map<String, Object?> intent,
  Map<String, Object?> output,
) {
  void require(bool ok) {
    if (!ok) throw const FormatException('invalid_day_date_batch_evidence');
  }

  require(
    intent['accountLineage'] == state.accountLineage &&
        intent['operationId'] == receipt.identity.operationId &&
        intent['payloadVersion'] == receipt.identity.payloadVersion,
  );
  require(
    canonicalIdentity(
          (intent['expectedFence']! as Map).cast<String, Object?>(),
        ) ==
        canonicalIdentity({
          'storeId': receipt.fence.storeId,
          'generation': receipt.fence.generation,
        }),
  );
  require(
    receipt.committedRevision == (intent['expectedRevision']! as int) + 1,
  );
  final reserved = <String>{};
  for (final other in state.receipts) {
    if (other.identity == receipt.identity) continue;
    reserved.add(other.identity.operationId);
    try {
      final map = jsonDecode(other.identity.canonicalPayloadIdentity);
      if (map is Map &&
          [
            'day_date_correction',
            'party_session_compensation',
          ].contains(map['commandType'])) {
        for (final child in map['children'] as List) {
          reserved.add((child as Map)['operationId']! as String);
        }
      }
    } on Object {
      /* Opaque unrelated command identities are not batch intent. */
    }
  }
  final before = const LegacyAccountCodec().decodeJson(
    (intent['expectedAccount']! as Map).cast<String, Object?>(),
  );
  if (intent['inverseOf'] != null) {
    validateDayDateInverseBinding(
      state,
      intent,
      parentSequence: receipt.sequence,
    );
  }
  final plan = DayDatePlan.forIntent(before, intent);
  require(
    canonicalIdentity(
          (output['afterAccount']! as Map).cast<String, Object?>(),
        ) ==
        canonicalIdentity(applyDayDateIntent(before, intent).toJson()),
  );
  require(
    canonicalIdentity((output['mapping']! as Map).cast<String, Object?>()) ==
        canonicalIdentity(plan.mapping),
  );
  require(
    output['operationId'] == intent['operationId'] &&
        output['commandType'] == intent['commandType'],
  );
  final expected = intent['children']! as List,
      actual = output['children']! as List;
  require(expected.length == actual.length);
  final seen = <String>{};
  for (var i = 0; i < actual.length; i++) {
    final child = (actual[i] as Map).cast<String, Object?>();
    final ci = (child['intent']! as Map).cast<String, Object?>();
    require(
      canonicalIdentity(ci) ==
          canonicalIdentity((expected[i] as Map).cast<String, Object?>()),
    );
    require(
      ci['accountLineage'] == state.accountLineage &&
          ci['expectedFence'] != null &&
          canonicalIdentity(
                (ci['expectedFence']! as Map).cast<String, Object?>(),
              ) ==
              canonicalIdentity(
                (intent['expectedFence']! as Map).cast<String, Object?>(),
              ),
    );
    require(
      seen.add(ci['operationId']! as String) &&
          !reserved.contains(ci['operationId']) &&
          ci['operationId'] != receipt.identity.operationId,
    );
    require(
      [
        'edit_operating_expense',
        'edit_supplier_payment',
        'edit_daily_transfer',
        'external_cash_edit',
      ].contains(ci['commandType']),
    );
    final outcome = (child['outcome']! as Map).cast<String, Object?>();
    require(
      outcome['operationId'] == ci['operationId'] &&
          outcome['commandType'] == ci['commandType'],
    );
    for (final entry in child['entries']! as List) {
      final map = (entry as Map).cast<String, Object?>();
      final id = map['id'];
      final matching = state.journals.where((j) => j.journal.id == id);
      require(
        matching.length == 1 &&
            canonicalIdentity(matching.single.toJson()) ==
                canonicalIdentity(map),
      );
    }
  }
}

/// An exact mapping is executable only as the inverse of retained committed
/// evidence. Backward receipt sequence forbids cyclic inverse proofs.
void validateDayDateInverseBinding(
  PortableJournalState state,
  Map<String, Object?> intent, {
  required int parentSequence,
}) {
  final inverse = intent['inverseOf']! as Map;
  final identity = DurableCommandIdentity(
    operationId: inverse['operationId']! as String,
    payloadVersion: inverse['payloadVersion']! as int,
    canonicalPayloadIdentity: inverse['canonicalPayloadIdentity']! as String,
  );
  final receipt = state.receipts.singleWhere(
    (r) => r.identity == identity && r.status == DurableCommandStatus.committed,
  );
  if (receipt.sequence >= parentSequence ||
      identity.operationId == intent['operationId']) {
    throw const FormatException('invalid_inverse_day_receipt');
  }
  final original = (jsonDecode(identity.canonicalPayloadIdentity) as Map)
          .cast<String, Object?>(),
      outcome = (jsonDecode(receipt.outcomePayload!) as Map)
          .cast<String, Object?>();
  if (original['commandType'] != 'day_date_correction' ||
      original['accountLineage'] != state.accountLineage) {
    throw const FormatException('invalid_inverse_day_receipt');
  }
  validateDayDateBatchEnvelope(state, receipt, original, outcome);
  final mapping = (outcome['mapping']! as Map).cast<String, String>();
  final expected = {for (final e in mapping.entries) e.value: e.key},
      actual = (intent['exactMapping']! as Map).cast<String, String>();
  final keys = expected.keys.toList()..sort();
  if (canonicalIdentity(expected) != canonicalIdentity(actual) ||
      intent['from'] != keys.first ||
      intent['to'] != expected[keys.first] ||
      intent['end'] != keys.last) {
    throw const FormatException('invalid_inverse_day_mapping');
  }
  final current = const LegacyAccountCodec().decodeJson(
        (intent['expectedAccount']! as Map).cast<String, Object?>(),
      ),
      after = const LegacyAccountCodec().decodeJson(
        (outcome['afterAccount']! as Map).cast<String, Object?>(),
      );
  if (canonicalIdentity(dayDateTouchedSource(current, expected.keys)) !=
      canonicalIdentity(dayDateTouchedSource(after, expected.keys))) {
    throw const FormatException('undo_source_changed');
  }
  final before = const LegacyAccountCodec().decodeJson(
    (original['expectedAccount']! as Map).cast<String, Object?>(),
  );
  final restored = applyDayDateIntent(current, intent);
  if (canonicalIdentity(dayDateTouchedSource(restored, expected.values)) !=
      canonicalIdentity(dayDateTouchedSource(before, expected.values))) {
    throw const FormatException('undo_complete_source_restore_required');
  }
}
