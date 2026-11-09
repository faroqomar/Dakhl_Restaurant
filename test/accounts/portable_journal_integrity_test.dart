import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:madar_application/madar_application.dart';
import 'package:madar_domain/madar_domain.dart';
import 'package:dakhl_restaurant/accounts/legacy_account_codec.dart';
import 'package:dakhl_restaurant/accounts/portable_journal_codec.dart';
import 'package:dakhl_restaurant/accounts/portable_journal_state.dart';

void main() {
  const codec = PortableJournalCodec();
  const stamp = '2026-11-07T12:00:00.000Z';
  final date = DateOnly.parse(
    '2026-11-07',
    minimumYear: 1000,
    maximumYear: 9999,
  );
  final corpus = jsonDecode(
    File('test/fixtures/accounts/oracle.json').readAsStringSync(),
  ) as Map;
  final fixture = (corpus['cases'] as List).cast<Map>().firstWhere(
    (c) => c['name'] == 'all-entities-history',
  );
  final account = const LegacyAccountCodec().decodeJson(
    Map<String, Object?>.from(fixture['input'] as Map),
  );
  final error = throwsA(isA<PortableJournalException>());
  PortableJournalState base() => codec.enrollLegacyDocument(
    account,
    accountLineage: 'lineage',
    enrolledAt: DateTime.parse(stamp),
  );
  BalancedJournal journal(
    String id, {
    String currency = 'IQD',
    int scale = 0,
  }) => BalancedJournal.validate(
    id: id,
    effectiveDate: date,
    policy: JournalPolicy(
      currency: currency,
      scale: scale,
      maximumLineUnits: BigInt.from(1000),
      maximumSideUnits: BigInt.from(1000),
      maximumLines: 10,
      allowZeroLines: false,
    ),
    lines: [
      JournalLine(
        accountId: 'asset:cash:daily',
        side: JournalSide.debit,
        amountUnits: BigInt.from(100),
        currency: currency,
        scale: scale,
      ),
      JournalLine(
        accountId: 'revenue:sales',
        side: JournalSide.credit,
        amountUnits: BigInt.from(100),
        currency: currency,
        scale: scale,
      ),
    ],
  );
  PortableJournalEntry entry(
    BalancedJournal j, {
    Map<String, Object?>? metadata,
    String? corrected,
    String? replacement,
  }) => PortableJournalEntry(
    journal: j,
    sourceType: 'sale',
    recordedAt: stamp,
    metadata: metadata,
    correctedFromJournalId: corrected,
    replacementJournalId: replacement,
  );
  PortableJournalState reversedState() {
    final first = journal('original');
    return base().copyWith(
      journals: [
        entry(first),
        entry(
          first.reversed(id: 'inverse', effectiveDate: date, reason: 'void'),
        ),
      ],
    );
  }

  Map<String, Object?> mutableJson(PortableJournalState s) =>
      jsonDecode(codec.encodeState(s)) as Map<String, Object?>;
  Map<String, Object?> lastJournal(Map<String, Object?> json) =>
      (json['journals'] as List).last as Map<String, Object?>;
  DurableCommandReceipt receipt({
    int sequence = 1,
    int revision = 1,
    String op = 'op',
    StorageFence fence = const StorageFence(storeId: 's', generation: 'g'),
  }) => DurableCommandReceipt(
    identity: DurableCommandIdentity(
      operationId: op,
      payloadVersion: 1,
      canonicalPayloadIdentity: 'opaque',
    ),
    status: DurableCommandStatus.committed,
    committedRevision: revision,
    fence: fence,
    sequence: sequence,
  );

  test('legacy source versions 1 through 11 retain rich canonical history', () {
    for (var version = 1; version <= 11; version++) {
      final source = (corpus['cases'] as List).cast<Map>().firstWhere(
        (c) => c['name'] == 'schema-$version-rich-history',
      );
      final enrolled = codec.enrollLegacySourceJson(
        Map<String, Object?>.from(source['input'] as Map),
        accountLineage: 'legacy-$version',
        enrolledAt: DateTime.parse(stamp),
      );
      final decoded = codec.decodeState(codec.encodeState(enrolled));
      expect(decoded.sourceProvenance.sourceVersion, version);
      expect(decoded.toJson(), enrolled.toJson());
      expect(decoded.journals, isEmpty);
      expect(decoded.cutoverState.hasActivePosting, isFalse);
    }
  });

  test(
    'direct reversal decoding requires and verifies the original context',
    () {
      final s = reversedState();
      final json = s.journals.last.toJson();
      expect(() => PortableJournalEntry.fromJson(json), error);
      final decoded = PortableJournalEntry.fromJson(
        json,
        originalJournal: s.journals.first.journal,
      );
      expect(decoded.toJson(), json);
    },
  );

  test('verified synthetic opening can establish a complete cutover', () {
    final opening = PortableJournalEntry(
      journal: journal('opening'),
      sourceType: 'cutoverOpening',
      recordedAt: stamp,
    );
    final s = base().copyWith(
      journals: [opening],
      cutoverState: PortableJournalCutoverState.established(
        cutoverDate: date,
        openingJournalId: 'opening',
        verifiedOpeningValues: {'daily': 100},
      ),
    );
    expect(codec.decodeState(codec.encodeState(s)).toJson(), s.toJson());
    expect(() => s.copyWith(journals: []), error);
  });

  test('roundtrip preserves nullable correction link on a plain void', () {
    final before = reversedState();
    final after = codec.decodeState(codec.encodeState(before));
    expect(after.toJson(), before.toJson());
    expect(after.journals.last.correctedFromJournalId, isNull);
  });

  test('reversal import rejects tampered lines, policy, total and reason', () {
    for (final change in <void Function(Map<String, Object?>)>[
      (j) => ((j['lines'] as List).first as Map)['amountUnits'] = '101',
      (j) => (j['policy'] as Map)['maximumLines'] = 11,
      (j) => j['totalUnits'] = '999',
      (j) => j['lines'] = <Object?>[],
      (j) => j['reason'] = 42,
    ]) {
      final json = mutableJson(reversedState());
      change(lastJournal(json));
      expect(() => codec.decodeState(jsonEncode(json)), error);
    }
  });

  test('ordinary import checks stored total and rejects non-IQD policy', () {
    final json = mutableJson(base().addJournal(entry(journal('one'))));
    lastJournal(json)['totalUnits'] = '101';
    expect(() => codec.decodeState(jsonEncode(json)), error);
    expect(
      () => base().addJournal(entry(journal('usd', currency: 'USD', scale: 2))),
      error,
    );
  });

  test('metadata and opening values freeze borrowed nested containers', () {
    final nested = <Object?>[
      <String, Object?>{'value': 1},
    ];
    final j = entry(journal('one'), metadata: {'nested': nested});
    final opening = PortableJournalCutoverState.gated(
      verifiedOpeningValues: {'nested': nested},
    );
    (nested.first as Map)['value'] = 2;
    expect(((j.metadata['nested'] as List).first as Map)['value'], 1);
    expect(
      ((opening.verifiedOpeningValues!['nested'] as List).first
          as Map)['value'],
      1,
    );
    expect(
      () => (j.metadata['nested'] as List).clear(),
      throwsUnsupportedError,
    );
    expect(
      () =>
          ((opening.verifiedOpeningValues!['nested'] as List).first
                  as Map)['value'] =
              3,
      throwsUnsupportedError,
    );
  });

  test('metadata rejects cyclic, fractional and unsupported values', () {
    final cycle = <String, Object?>{};
    cycle['self'] = cycle;
    for (final value in <Object?>[
      cycle,
      0.5,
      StringBuffer('mutable'),
      BigInt.one,
    ]) {
      expect(() => entry(journal('one'), metadata: {'bad': value}), error);
    }
  });

  test(
    'constructor and copyWith reject duplicate journals and invalid receipts',
    () {
      final j = entry(journal('one'));
      expect(() => base().copyWith(journals: [j, j]), error);
      expect(() => base().copyWith(receipts: [receipt(sequence: 2)]), error);
      expect(
        () => base().copyWith(
          receipts: [
            receipt(),
            receipt(sequence: 2, op: 'op2'),
          ],
        ),
        error,
      );
      expect(
        () => base().copyWith(
          receipts: [receipt(), receipt(sequence: 2, revision: 2)],
        ),
        error,
      );
      expect(() => base().copyWith(accountLineage: ' lineage '), error);
      expect(
        () => base().copyWith(
          receipts: [
            receipt(
              fence: const StorageFence(storeId: '', generation: ''),
            ),
          ],
        ),
        error,
      );
    },
  );

  test('receipt revisions can reset only under a new fence', () {
    final s = base().copyWith(
      receipts: [
        receipt(revision: 5),
        receipt(
          sequence: 2,
          revision: 1,
          op: 'two',
          fence: const StorageFence(storeId: 's', generation: 'g2'),
        ),
      ],
    );
    expect(codec.decodeState(codec.encodeState(s)).toJson(), s.toJson());
  });

  test('cutover import rejects missing opening data and contradictory gated fields', () {
    for (final c in <Map<String, Object?>>[
      {'isGated': false, 'status': 'established', 'hasActivePosting': true},
      {
        'isGated': true,
        'status': 'gated',
        'hasActivePosting': false,
        'cutoverDate': '2026-11-07',
      },
      {
        'isGated': true,
        'status': 'gated',
        'hasActivePosting': false,
        'openingJournalId': 'ghost',
      },
      {
        'isGated': false,
        'status': 'established',
        'hasActivePosting': true,
        'cutoverDate': '2026-11-07',
        'openingJournalId': 'ghost',
      },
    ]) {
      final json = mutableJson(base())..['cutoverState'] = c;
      expect(() => codec.decodeState(jsonEncode(json)), error);
    }
  });

  test('correction and reversal lineage rejects missing targets and duplicate inverses', () {
    expect(
      () => base().copyWith(
        journals: [entry(journal('one'), corrected: 'ghost')],
      ),
      error,
    );
    final first = journal('original');
    expect(
      () => reversedState().addJournal(
        entry(
          first.reversed(id: 'inverse2', effectiveDate: date, reason: 'twice'),
        ),
      ),
      error,
    );
    expect(
      () => base().copyWith(
        journals: [entry(journal('one'), replacement: 'ghost')],
      ),
      error,
    );
  });

  test(
    'unknown durable fields fail closed at envelope and journal boundaries',
    () {
      for (final change in <void Function(Map<String, Object?>)>[
        (j) => j['unrecognizedOperations'] = <Object?>[],
        (j) => lastJournal(j)['futureLineage'] = 'must-not-disappear',
        (j) => (j['sourceProvenance'] as Map)['future'] = true,
        (j) => (j['account'] as Map)['unrecognized'] = 1,
      ]) {
        final json = mutableJson(base().addJournal(entry(journal('one'))));
        change(json);
        expect(() => codec.decodeState(jsonEncode(json)), error);
      }
    },
  );

  test('malformed typed values return stable portable errors', () {
    for (final change in <void Function(Map<String, Object?>)>[
      (j) => lastJournal(j)['reversesId'] = 1,
      (j) => (lastJournal(j)['policy'] as Map)['maximumLineUnits'] = 'NaN',
      (j) => lastJournal(j)['recordedAt'] = 1,
      (j) => (j['sourceProvenance'] as Map)['sourceVersion'] = 99,
      (j) => j['accountLineage'] = ' lineage ',
    ]) {
      final json = mutableJson(base().addJournal(entry(journal('one'))));
      change(json);
      expect(() => codec.decodeState(jsonEncode(json)), error);
    }
  });

  test('capacity override cannot exceed store limits and rejects malformed Unicode', () {
    const excessive = PortableJournalCodec(
      maxPayloadBytes: DocumentLimits.accountBytes + 1,
    );
    expect(() => excessive.encodeState(base()), error);
    final json = mutableJson(base());
    final payload = jsonEncode(json).replaceFirst('lineage', '\uD800');
    expect(() => codec.decodeState(payload), error);
  });
}
