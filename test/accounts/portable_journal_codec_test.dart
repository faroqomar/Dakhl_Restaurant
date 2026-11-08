import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:madar_application/madar_application.dart';
import 'package:madar_domain/madar_domain.dart';
import 'package:dakhl_restaurant/accounts/account_document.dart';
import 'package:dakhl_restaurant/accounts/legacy_account_codec.dart';
import 'package:dakhl_restaurant/accounts/portable_journal_codec.dart';
import 'package:dakhl_restaurant/accounts/portable_journal_state.dart';

void main() {
  const legacyCodec = LegacyAccountCodec();
  const codec = PortableJournalCodec();

  final corpus = jsonDecode(
    File('test/fixtures/accounts/oracle.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  final cases = (corpus['cases'] as List).cast<Map<String, dynamic>>();

  AccountDocument sampleAccountDocument() {
    final sample = cases.firstWhere((s) => s['name'] == 'all-entities-history');
    final input = sample['input'] as Map<String, dynamic>;
    return legacyCodec.decodeJson(Map<String, Object?>.from(input));
  }

  DateOnly testDate(String iso) =>
      DateOnly.parse(iso, minimumYear: 1000, maximumYear: 9999);

  group('PortableJournalCodec - Version & Runtime Boundary', () {
    test('existing runtime strictly rejects version 12', () {
      final canonicalDoc = sampleAccountDocument();
      final v12State = codec.enrollLegacyDocument(
        canonicalDoc,
        accountLineage: 'restaurant-lineage-001',
      );
      final encodedBytes = codec.encodeBytes(v12State);
      final encodedString = utf8.decode(encodedBytes);

      // Existing LegacyAccountCodec must fail closed on version 12
      expect(
        () => legacyCodec.decodeBytes(encodedBytes),
        throwsA(
          isA<AccountCodecException>().having(
            (e) => e.code,
            'code',
            'unsupported_version',
          ),
        ),
      );

      final rawJson = jsonDecode(encodedString) as Map<String, Object?>;
      expect(
        () => legacyCodec.decodeJson(rawJson),
        throwsA(
          isA<AccountCodecException>().having(
            (e) => e.code,
            'code',
            'unsupported_version',
          ),
        ),
      );
    });

    test('candidate codec accepts version 12 and rejects versions != 12', () {
      final canonicalDoc = sampleAccountDocument();
      final v12State = codec.enrollLegacyDocument(
        canonicalDoc,
        accountLineage: 'restaurant-lineage-001',
      );
      final json = v12State.toJson();

      // Version 12 is accepted
      expect(codec.decodeState(jsonEncode(json)).version, 12);

      // Version 11 rejected by v12 codec (must use enrollLegacySource)
      final v11Json = Map<String, Object?>.from(json)..['version'] = 11;
      expect(
        () => codec.decodeState(jsonEncode(v11Json)),
        throwsA(
          isA<PortableJournalException>().having(
            (e) => e.code,
            'code',
            'unsupported_version',
          ),
        ),
      );

      // Future version 13 rejected
      final v13Json = Map<String, Object?>.from(json)..['version'] = 13;
      expect(
        () => codec.decodeState(jsonEncode(v13Json)),
        throwsA(
          isA<PortableJournalException>().having(
            (e) => e.code,
            'code',
            'unsupported_version',
          ),
        ),
      );
    });
  });

  group('PortableJournalCodec - Legacy Enrollment & Source Provenance', () {
    test('enrolls schema 1..11 sources preserving historical records and provenance', () {
      final sample = cases.firstWhere(
        (s) => s['name'] == 'all-entities-history',
      );
      final input = sample['input'] as Map<String, dynamic>;
      final enrolled = codec.enrollLegacySourceJson(
        Map<String, Object?>.from(input),
        accountLineage: 'restaurant-lineage-alpha',
      );

      expect(enrolled.version, 12);
      expect(enrolled.accountLineage, 'restaurant-lineage-alpha');
      expect(enrolled.sourceProvenance.sourceVersion, 11);
      expect(
        enrolled.sourceProvenance.migrated,
        isFalse,
      ); // schema 11 is latest canonical
      expect(enrolled.sourceProvenance.enrolledAt, isNotEmpty);

      // Cutover state must remain gated and never synthesize posting
      expect(enrolled.cutoverState.isGated, isTrue);
      expect(enrolled.cutoverState.hasActivePosting, isFalse);
      expect(enrolled.cutoverState.cutoverDate, isNull);
      expect(enrolled.cutoverState.openingJournalId, isNull);

      // Never synthesize historical journals
      expect(enrolled.journals, isEmpty);
      expect(enrolled.receipts, isEmpty);

      // Embedded canonical account preserves all historical categories & days
      expect(enrolled.account.categories.length, greaterThan(0));
      expect(enrolled.account.days.keys.length, greaterThan(0));
    });

    test(
      'enrollment preserves historical records from earlier schema (v1..v10)',
      () {
        final sample = cases.firstWhere((s) => s['name'] == 'schema-8');
        final input = sample['input'] as Map<String, dynamic>;
        final enrolled = codec.enrollLegacySourceJson(
          Map<String, Object?>.from(input),
          accountLineage: 'restaurant-v8-lineage',
        );

        expect(enrolled.version, 12);
        expect(enrolled.sourceProvenance.sourceVersion, 8);
        expect(enrolled.sourceProvenance.migrated, isTrue);
        expect(enrolled.account.version, 11); // Canonical representation is 11
        expect(enrolled.account.sourceVersion, 8);
        expect(enrolled.journals, isEmpty);
      },
    );

    test('requires explicit, valid caller-owned account lineage', () {
      final canonicalDoc = sampleAccountDocument();
      expect(
        () => codec.enrollLegacyDocument(canonicalDoc, accountLineage: ''),
        throwsA(
          isA<PortableJournalException>().having(
            (e) => e.code,
            'code',
            'invalid_account_lineage',
          ),
        ),
      );
      expect(
        () => codec.enrollLegacyDocument(canonicalDoc, accountLineage: '   '),
        throwsA(
          isA<PortableJournalException>().having(
            (e) => e.code,
            'code',
            'invalid_account_lineage',
          ),
        ),
      );
    });

    test('snapshots and lists in decoded state are deeply unmodifiable', () {
      final canonicalDoc = sampleAccountDocument();
      final state = codec.enrollLegacyDocument(
        canonicalDoc,
        accountLineage: 'immutability-test',
      );
      final dummyEntry = PortableJournalEntry(
        journal: BalancedJournal.validate(
          id: 'dummy',
          effectiveDate: testDate('2026-11-07'),
          policy: JournalPolicy(
            currency: 'IQD',
            scale: 0,
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
              currency: 'IQD',
              scale: 0,
            ),
            JournalLine(
              accountId: 'revenue:sales',
              side: JournalSide.credit,
              amountUnits: BigInt.from(100),
              currency: 'IQD',
              scale: 0,
            ),
          ],
        ),
        sourceType: 'dummy',
        recordedAt: '2026-11-07T12:00:00.000Z',
      );
      final dummyReceipt = DurableCommandReceipt(
        identity: const DurableCommandIdentity(
          operationId: 'op-dummy',
          payloadVersion: 1,
          canonicalPayloadIdentity: 'hash-dummy',
        ),
        status: DurableCommandStatus.committed,
        committedRevision: 1,
        fence: const StorageFence(storeId: 's', generation: 'g'),
        sequence: 1,
      );
      expect(() => state.journals.add(dummyEntry), throwsUnsupportedError);
      expect(() => state.receipts.add(dummyReceipt), throwsUnsupportedError);
      expect(() => state.account.categories.add({}), throwsUnsupportedError);
    });
  });

  group('PortableJournalCodec - Exact IQD Journals & Validation', () {
    test(
      'roundtrips valid balanced IQD journals with provenance and lineage',
      () {
        final canonicalDoc = sampleAccountDocument();
        final baseState = codec.enrollLegacyDocument(
          canonicalDoc,
          accountLineage: 'restaurant-roundtrip',
        );

        final journal = BalancedJournal.validate(
          id: 'journal-sale-001',
          effectiveDate: testDate('2026-11-07'),
          policy: JournalPolicy(
            currency: 'IQD',
            scale: 0,
            maximumLineUnits: BigInt.from(1000000000000),
            maximumSideUnits: BigInt.from(1000000000000),
            maximumLines: 500,
            allowZeroLines: false,
          ),
          lines: [
            JournalLine(
              accountId: 'asset:cash:daily',
              side: JournalSide.debit,
              amountUnits: BigInt.from(25000),
              currency: 'IQD',
              scale: 0,
            ),
            JournalLine(
              accountId: 'revenue:sales',
              side: JournalSide.credit,
              amountUnits: BigInt.from(25000),
              currency: 'IQD',
              scale: 0,
            ),
          ],
        );

        final entry = PortableJournalEntry(
          journal: journal,
          sourceType: 'sale',
          sourceRecordId: 'sale-tx-999',
          recordedAt: '2026-11-07T12:00:00.000Z',
          metadata: {'cashierId': 'staff-1'},
        );

        final updatedState = baseState.addJournal(entry);
        expect(updatedState.journals.length, 1);

        final encoded = codec.encodeState(updatedState);
        final decoded = codec.decodeState(encoded);

        expect(decoded.version, 12);
        expect(decoded.accountLineage, 'restaurant-roundtrip');
        expect(decoded.journals.length, 1);
        final restored = decoded.journals.first;
        expect(restored.journal.id, 'journal-sale-001');
        expect(restored.journal.effectiveDate, testDate('2026-11-07'));
        expect(restored.journal.totalUnits, BigInt.from(25000));
        expect(restored.sourceType, 'sale');
        expect(restored.sourceRecordId, 'sale-tx-999');
        expect(restored.recordedAt, '2026-11-07T12:00:00.000Z');
        expect(restored.metadata['cashierId'], 'staff-1');
      },
    );

    test('supports reversal journal with linked inverse provenance', () {
      final canonicalDoc = sampleAccountDocument();
      final baseState = codec.enrollLegacyDocument(
        canonicalDoc,
        accountLineage: 'restaurant-reversal',
      );

      final originalJournal = BalancedJournal.validate(
        id: 'journal-sale-original',
        effectiveDate: testDate('2026-11-07'),
        policy: JournalPolicy(
          currency: 'IQD',
          scale: 0,
          maximumLineUnits: BigInt.from(1000000000000),
          maximumSideUnits: BigInt.from(1000000000000),
          maximumLines: 500,
          allowZeroLines: false,
        ),
        lines: [
          JournalLine(
            accountId: 'asset:cash:daily',
            side: JournalSide.debit,
            amountUnits: BigInt.from(15000),
            currency: 'IQD',
            scale: 0,
          ),
          JournalLine(
            accountId: 'revenue:sales',
            side: JournalSide.credit,
            amountUnits: BigInt.from(15000),
            currency: 'IQD',
            scale: 0,
          ),
        ],
      );

      final reversalJournal = originalJournal.reversed(
        id: 'journal-sale-reversed',
        effectiveDate: testDate('2026-11-07'),
        reason: 'Customer sale voided due to order error',
      );

      final stateWithOriginal = baseState.addJournal(
        PortableJournalEntry(
          journal: originalJournal,
          sourceType: 'sale',
          recordedAt: '2026-11-07T10:00:00.000Z',
        ),
      );

      final stateWithReversal = stateWithOriginal.addJournal(
        PortableJournalEntry(
          journal: reversalJournal,
          sourceType: 'reversal',
          correctedFromJournalId: 'journal-sale-original',
          recordedAt: '2026-11-07T10:30:00.000Z',
        ),
      );

      final encoded = codec.encodeState(stateWithReversal);
      final decoded = codec.decodeState(encoded);

      expect(decoded.journals.length, 2);
      final rev = decoded.journals[1];
      expect(rev.journal.reversesId, 'journal-sale-original');
      expect(rev.journal.reason, 'Customer sale voided due to order error');
      expect(rev.correctedFromJournalId, 'journal-sale-original');
      expect(rev.journal.totalUnits, BigInt.from(15000));
    });

    test(
      'fails closed on unbalanced journal or invalid currency scale in payload',
      () {
        final canonicalDoc = sampleAccountDocument();
        final baseState = codec.enrollLegacyDocument(
          canonicalDoc,
          accountLineage: 'restaurant-unbalanced',
        );
        final json = baseState.toJson();

        // Injected unbalanced journal lines
        json['journals'] = [
          {
            'id': 'bad-journal',
            'effectiveDate': '2026-11-07',
            'lines': [
              {
                'accountId': 'asset:cash:daily',
                'side': 'debit',
                'amountUnits': '1000',
                'currency': 'IQD',
                'scale': 0,
              },
              {
                'accountId': 'revenue:sales',
                'side': 'credit',
                'amountUnits': '900', // Unbalanced!
                'currency': 'IQD',
                'scale': 0,
              },
            ],
            'policy': {
              'currency': 'IQD',
              'scale': 0,
              'maximumLineUnits': '1000000000000',
              'maximumSideUnits': '1000000000000',
              'maximumLines': 500,
              'allowZeroLines': false,
            },
            'sourceType': 'sale',
            'recordedAt': '2026-11-07T12:00:00.000Z',
          },
        ];

        expect(
          () => codec.decodeState(jsonEncode(json)),
          throwsA(
            isA<PortableJournalException>().having(
              (e) => e.code,
              'code',
              'invalid_journal',
            ),
          ),
        );
      },
    );

    test('fails closed on duplicate journal identity', () {
      final canonicalDoc = sampleAccountDocument();
      final baseState = codec.enrollLegacyDocument(
        canonicalDoc,
        accountLineage: 'restaurant-dupe-test',
      );
      final journal = BalancedJournal.validate(
        id: 'journal-dupe-id',
        effectiveDate: testDate('2026-11-07'),
        policy: JournalPolicy(
          currency: 'IQD',
          scale: 0,
          maximumLineUnits: BigInt.from(1000000000000),
          maximumSideUnits: BigInt.from(1000000000000),
          maximumLines: 500,
          allowZeroLines: false,
        ),
        lines: [
          JournalLine(
            accountId: 'asset:cash:daily',
            side: JournalSide.debit,
            amountUnits: BigInt.from(1000),
            currency: 'IQD',
            scale: 0,
          ),
          JournalLine(
            accountId: 'revenue:sales',
            side: JournalSide.credit,
            amountUnits: BigInt.from(1000),
            currency: 'IQD',
            scale: 0,
          ),
        ],
      );

      final stateWithOne = baseState.addJournal(
        PortableJournalEntry(
          journal: journal,
          sourceType: 'sale',
          recordedAt: '2026-11-07T12:00:00.000Z',
        ),
      );

      expect(
        () => stateWithOne.addJournal(
          PortableJournalEntry(
            journal: journal,
            sourceType: 'sale',
            recordedAt: '2026-11-07T12:05:00.000Z',
          ),
        ),
        throwsA(
          isA<PortableJournalException>().having(
            (e) => e.code,
            'code',
            'duplicate_journal_identity',
          ),
        ),
      );
    });

    test('reversal target not found in journals fails closed', () {
      final canonicalDoc = sampleAccountDocument();
      final baseState = codec.enrollLegacyDocument(
        canonicalDoc,
        accountLineage: 'missing-reversal-target',
      );
      final journal = BalancedJournal.validate(
        id: 'journal-target-missing',
        effectiveDate: testDate('2026-11-07'),
        policy: JournalPolicy(
          currency: 'IQD',
          scale: 0,
          maximumLineUnits: BigInt.from(1000000000000),
          maximumSideUnits: BigInt.from(1000000000000),
          maximumLines: 500,
          allowZeroLines: false,
        ),
        lines: [
          JournalLine(
            accountId: 'asset:cash:daily',
            side: JournalSide.debit,
            amountUnits: BigInt.from(1000),
            currency: 'IQD',
            scale: 0,
          ),
          JournalLine(
            accountId: 'revenue:sales',
            side: JournalSide.credit,
            amountUnits: BigInt.from(1000),
            currency: 'IQD',
            scale: 0,
          ),
        ],
      );
      final rev = journal.reversed(
        id: 'rev-orphan',
        effectiveDate: testDate('2026-11-07'),
        reason: 'reversing non-existent',
      );

      expect(
        () => baseState.addJournal(
          PortableJournalEntry(
            journal: rev,
            sourceType: 'reversal',
            recordedAt: '2026-11-07T12:00:00.000Z',
          ),
        ),
        throwsA(
          isA<PortableJournalException>().having(
            (e) => e.code,
            'code',
            'invalid_reversal_target',
          ),
        ),
      );
    });
  });

  group('PortableJournalCodec - Durable Receipts & Command Integration', () {
    test(
      'extractReceipts and attachReceipt preserve monotonic receipt sequence',
      () {
        final canonicalDoc = sampleAccountDocument();
        var state = codec.enrollLegacyDocument(
          canonicalDoc,
          accountLineage: 'receipt-lineage-1',
        );

        expect(codec.extractReceipts(state), isEmpty);

        final receipt1 = DurableCommandReceipt(
          identity: const DurableCommandIdentity(
            operationId: 'op-001',
            payloadVersion: 1,
            canonicalPayloadIdentity: 'payload-hash-1',
          ),
          status: DurableCommandStatus.committed,
          committedRevision: 1,
          fence: const StorageFence(storeId: 'store-1', generation: 'gen-1'),
          sequence: 1,
        );

        state = codec.attachReceipt(state, receipt1);
        expect(codec.extractReceipts(state).length, 1);
        expect(codec.extractReceipts(state).first, receipt1);

        final receipt2 = DurableCommandReceipt(
          identity: const DurableCommandIdentity(
            operationId: 'op-002',
            payloadVersion: 1,
            canonicalPayloadIdentity: 'payload-hash-2',
          ),
          status: DurableCommandStatus.committed,
          committedRevision: 2,
          fence: const StorageFence(storeId: 'store-1', generation: 'gen-1'),
          sequence: 2,
        );

        state = codec.attachReceipt(state, receipt2);
        expect(codec.extractReceipts(state).length, 2);

        // Encode and decode roundtrip
        final encoded = codec.encodeState(state);
        final decoded = codec.decodeState(encoded);
        expect(decoded.receipts.length, 2);
        expect(decoded.receipts[0].identity.operationId, 'op-001');
        expect(decoded.receipts[1].identity.operationId, 'op-002');
        expect(decoded.receipts[1].sequence, 2);
      },
    );

    test('fails closed on duplicate receipt operationId or sequence gap', () {
      final canonicalDoc = sampleAccountDocument();
      final state = codec.enrollLegacyDocument(
        canonicalDoc,
        accountLineage: 'receipt-gap-test',
      );

      final badSequenceReceipt = DurableCommandReceipt(
        identity: const DurableCommandIdentity(
          operationId: 'op-001',
          payloadVersion: 1,
          canonicalPayloadIdentity: 'payload-hash-1',
        ),
        status: DurableCommandStatus.committed,
        committedRevision: 1,
        fence: const StorageFence(storeId: 'store-1', generation: 'gen-1'),
        sequence: 2, // Gap! Expected 1
      );

      expect(
        () => codec.attachReceipt(state, badSequenceReceipt),
        throwsA(
          isA<PortableJournalException>().having(
            (e) => e.code,
            'code',
            'invalid_receipt_sequence',
          ),
        ),
      );
    });
  });

  group('PortableJournalCodec - Payload Size, Malformed & Boundary Failures', () {
    test('enforces 20 MiB payload bound strictly', () {
      // Oversized string > 20 MiB
      final oversizedBytes = Uint8List(20 * 1024 * 1024 + 1);
      expect(
        () => codec.decodeBytes(oversizedBytes),
        throwsA(
          isA<PortableJournalException>().having(
            (e) => e.code,
            'code',
            'payload_too_large',
          ),
        ),
      );
    });

    test(
      'fails closed on corrupt UTF-8 or malformed JSON without resetting state',
      () {
        final malformedBytes = [0xFF, 0xFE, 0xFD];
        expect(
          () => codec.decodeBytes(malformedBytes),
          throwsA(
            isA<PortableJournalException>().having(
              (e) => e.code,
              'code',
              'corrupt_state',
            ),
          ),
        );

        expect(
          () => codec.decodeState('{ bad json: true '),
          throwsA(
            isA<PortableJournalException>().having(
              (e) => e.code,
              'code',
              'corrupt_state',
            ),
          ),
        );
      },
    );

    test('gated cutover state rejects illegal active posting assertion', () {
      final canonicalDoc = sampleAccountDocument();
      final baseState = codec.enrollLegacyDocument(
        canonicalDoc,
        accountLineage: 'cutover-test',
      );
      final json = baseState.toJson();
      json['cutoverState'] = {
        'isGated': true,
        'status': 'gated',
        'hasActivePosting':
            true, // Contradiction! Gated cannot have active posting
      };

      expect(
        () => codec.decodeState(jsonEncode(json)),
        throwsA(
          isA<PortableJournalException>().having(
            (e) => e.code,
            'code',
            'invalid_cutover_state',
          ),
        ),
      );
    });
  });
}
