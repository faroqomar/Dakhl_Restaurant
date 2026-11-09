import 'dart:convert';
import 'dart:io';

import 'package:madar_application/madar_application.dart';
import 'package:madar_domain/madar_domain.dart';
import 'package:dakhl_restaurant/accounting/restaurant_journal_mapper.dart';
import 'package:dakhl_restaurant/accounts/legacy_account_codec.dart';
import 'package:dakhl_restaurant/accounts/portable_journal_codec.dart';
import 'package:dakhl_restaurant/accounts/portable_journal_state.dart';

void require(bool value, String message) {
  if (!value) throw StateError(message);
}

void main() {
  final checks = <String>[];
  final mapper = RestaurantJournalMapper();
  final d0 = DateOnly.parse('2026-11-02', minimumYear: 1000, maximumYear: 9999);
  final d1 = DateOnly.parse('2026-11-03', minimumYear: 1000, maximumYear: 9999);
  BigInt b(int n) => BigInt.from(n);
  RestaurantJournalProposal expense(
    String id,
    int total,
    int daily,
    DateOnly d,
  ) => mapper.mapOperatingExpense(
    journalId: id,
    expenseId: 'expense-01',
    effectiveDate: d,
    categoryId: 'market',
    amount: b(total),
    dailyAmount: b(daily),
    cashboxAmount: b(10000),
  );
  final original = expense('journal-expense-01-v1', 30000, 20000, d0);
  final inverse = mapper.mapOriginalDateVoid(
    originalProposal: original,
    reversalJournalId: 'journal-expense-01-inverse',
    reason: 'Synthetic amount correction',
    isEligible: true,
  );
  final replacement = mapper.mapReplacementProposal(
    newProposal: expense('journal-expense-01-v2', 32000, 22000, d0),
    correctedFromId: original.journal.id,
  );
  require(
    inverse.journal.reversesId == original.journal.id &&
        inverse.journal.effectiveDate == d0 &&
        replacement.correctedFromId == original.journal.id,
    'Original-date lineage',
  );
  require(
    original.journal.totalUnits == b(30000) &&
        inverse.journal.totalUnits == b(30000) &&
        replacement.journal.totalUnits == b(32000),
    'Exact totals',
  );
  checks.add(
    'Public mapper balances 30000 original/inverse and 32000 linked replacement',
  );
  final shifted = mapper.mapReplacementProposal(
    newProposal: expense('journal-expense-01-shifted', 30000, 20000, d1),
    correctedFromId: original.journal.id,
  );
  require(
    shifted.journal.effectiveDate == d1 && inverse.journal.effectiveDate == d0,
    'Different effective dates',
  );
  checks.add(
    'Date-shift replacement uses target date while inverse stays on original date',
  );
  final payment = mapper.mapSupplierPayment(
    journalId: 'journal-payment-01-v1',
    paymentId: 'payment-01',
    supplierId: 'supplier-01',
    effectiveDate: d0,
    amount: b(20000),
    dailyAmount: b(15000),
    cashboxAmount: b(5000),
    invoiceSettledAmount: b(12500),
    debtSettledAmount: b(7500),
    invoiceId: 'invoice-01',
  );
  final paymentInverse = mapper.mapOriginalDateVoid(
    originalProposal: payment,
    reversalJournalId: 'journal-payment-01-inverse',
    reason: 'Synthetic payment deletion',
    isEligible: true,
  );
  require(
    paymentInverse.journal.lines.any(
      (l) =>
          l.accountId == 'liability:supplier:supplier-01' &&
          l.side == JournalSide.credit &&
          l.amountUnits == b(20000),
    ),
    'Liability inverse',
  );
  checks.add(
    'Payment inverse restores supplier liability without recognizing another expense',
  );
  try {
    mapper.mapOriginalDateVoid(
      originalProposal: inverse,
      reversalJournalId: 'invalid-second-inverse',
      reason: 'invalid',
      isEligible: true,
    );
    throw StateError('Accepted inverse-of-inverse');
  } on RestaurantJournalMappingException catch (e) {
    require(e.code == 'already_reversed', 'Stable inverse guard');
  }
  checks.add(
    'Mapper rejects inverse-of-inverse; undo must compensate the current active posting',
  );
  final corpus = jsonDecode(
    File('test/fixtures/accounts/oracle.json').readAsStringSync(),
  ) as Map;
  final legacyCase = (corpus['cases'] as List).cast<Map>().firstWhere(
    (c) => c['name'] == 'schema-11-rich-history',
  );
  const codec = PortableJournalCodec();
  final enrolled = codec.enrollLegacySourceJson(
    Map<String, Object?>.from(legacyCase['input'] as Map),
    accountLineage: 'synthetic-lineage-01',
    enrolledAt: DateTime.utc(2026, 11, 8, 4),
  );
  PortableJournalEntry entry(
    RestaurantJournalProposal p, {
    String? replacedBy,
  }) => PortableJournalEntry(
    journal: p.journal,
    sourceType: p.sourceType.name,
    sourceRecordId: p.sourceRecordId,
    recordedAt: '2026-11-08T04:00:00.000Z',
    correctedFromJournalId: p.correctedFromId,
    replacementJournalId: replacedBy,
    metadata: {
      'correctionId': 'correction-01',
      'purpose': 'synthetic representation probe only',
    },
  );
  final oldEntry = entry(original);
  final oldBytes = jsonEncode(oldEntry.toJson());
  final state = enrolled.copyWith(
    journals: [
      oldEntry,
      entry(inverse, replacedBy: replacement.journal.id),
      entry(replacement),
    ],
  );
  final receipt = DurableCommandReceipt(
    identity: const DurableCommandIdentity(
      operationId: 'operation-correction-01',
      payloadVersion: 1,
      canonicalPayloadIdentity: 'synthetic-intent-v1',
    ),
    status: DurableCommandStatus.committed,
    outcomePayload: '{"correctionId":"correction-01"}',
    committedRevision: 4,
    fence: const StorageFence(
      storeId: 'synthetic-store',
      generation: 'generation-01',
    ),
    sequence: 1,
  );
  final complete = state.attachReceipt(receipt);
  final payload = codec.encodeState(complete),
      roundtrip = codec.decodeState(payload);
  require(
    codec.encodeState(roundtrip) == payload &&
        jsonEncode(roundtrip.journals.first.toJson()) == oldBytes &&
        roundtrip.receipts.single == receipt,
    'Complete-state roundtrip',
  );
  checks.add(
    'Portable codec preserves original entry, inverse/replacement links, lineage and receipt across exact roundtrip',
  );
  require(
    enrolled.journals.isEmpty &&
        enrolled.receipts.isEmpty &&
        enrolled.cutoverState.isGated,
    'No inferred history',
  );
  checks.add(
    'Legacy schema11 enrollment remains gated and synthesizes no journal/receipt',
  );
  try {
    const LegacyAccountCodec().decodeJson(
      jsonDecode(payload) as Map<String, Object?>,
    );
    throw StateError('Old reader accepted schema12');
  } catch (e) {
    require(
      e.toString().contains('unsupported_version'),
      'Old reader stable rejection',
    );
  }
  checks.add(
    'Legacy runtime reader rejects complete schema12 rather than dropping history',
  );
  final receiptResult = {
    'scope': 'Public mapper and portable representation only; no store transaction or source reconciliation proof',
    'checksPassed': checks.length,
    'checks': checks,
    'journalExamples':
        [original, inverse, replacement, payment, paymentInverse, shifted]
            .map(
              (p) => {
                'journalId': p.journal.id,
                'sourceRecordId': p.sourceRecordId,
                'effectiveDate': p.journal.effectiveDate.toString(),
                'reversesId': p.journal.reversesId,
                'correctedFromId': p.correctedFromId,
                'balancedTotal': p.journal.totalUnits.toString(),
                'lines': p.journal.lines
                    .map(
                      (l) => {
                        'accountId': l.accountId,
                        'side': l.side.name,
                        'amount': l.amountUnits.toString(),
                      },
                    )
                    .toList(),
              },
            )
            .toList(),
    'limitations': [
      'Synthetic journals are attached to a synthetic oracle account for structural validation only; this is not a reconciled command execution',
      'No runtime schema12 activation, import implementation or arbitrary crash proof',
    ],
  };
  File(
    'outputs/completion-review/remaining-correction-examples/mapper-probe-result.json',
  ).writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert(receiptResult)}\n',
  );
  stdout.writeln(
    jsonEncode({
      'checksPassed': checks.length,
      'receipt': 'mapper-probe-result.json',
    }),
  );
}
