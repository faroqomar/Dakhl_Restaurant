import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:madar_application/madar_application.dart';
import 'package:dakhl_restaurant/platform/review_performance_scenarios.dart';
import 'package:dakhl_restaurant/accounts/portable_journal_codec.dart';
import 'package:dakhl_restaurant/accounts/legacy_account_codec.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'review options reject unknown cases, duplicate keys and unsafe run IDs',
    () {
      for (final args in [
        ['--case', 'review.fake'],
        ['--case', 'review.sales.checkout', '--iterations', '0'],
        ['--case', 'review.sales.checkout', '--case', 'review.sales.refund'],
        ['--case', 'review.sales.checkout', '--run-id', '../foreign'],
      ]) {
        expect(
          () => ReviewPerformanceOptions.parse(args),
          throwsFormatException,
        );
      }
    },
  );
  for (final operation in reviewPerformanceCases) {
    test(
      '$operation executes the real workflow and survives native adapter reopen',
      () async {
        final fixture = await ReviewPerformanceFixture.create(
          'test',
          operation,
        );
        final directory = fixture.directory;
        try {
          expect(
            fixture.state.account.toJson()['products'],
            hasLength(
              operation.startsWith('review.reports.') &&
                      operation.endsWith('.multi')
                  ? 150
                  : 20,
            ),
          );
          expect(
            fixture.state.account.toJson()['transactions'],
            hasLength(200),
          );
          await fixture.run();
          await fixture.verifyDurable();
        } finally {
          await fixture.close();
        }
        expect(await Directory(directory.path).exists(), false);
      },
    );
  }
  for (final damage in ['receipt', 'cash']) {
    test('opening benchmark rejects altered $damage proof', () async {
      final fixture = await ReviewPerformanceFixture.create(
        'opening-negative-$damage',
        'review.suppliers.opening_write',
      );
      try {
        await fixture.run();
        final committed =
            (await fixture.store.readDocument()
                    as CapabilitySuccess<DocumentSnapshot?>)
                .value!;
        const codec = PortableJournalCodec();
        final state = codec.decodeState(committed.payload);
        final raw = <String, Object?>{...state.account.toJson()};
        raw['transactions'] = [
          ...(raw['transactions']! as List),
          {
            'id': 'unexpected-cash',
            'date': '2026-10-01',
            'type': 'deposit',
            'amount': 1,
            'note': '',
            'createdAt': '2026-10-01T00:00:00Z',
          },
        ];
        final damaged = damage == 'receipt'
            ? state.copyWith(receipts: [])
            : state.copyWith(
                account: const LegacyAccountCodec().decodeJson(raw),
              );
        expect(
          await fixture.store.writeDocument(
            codec.encodeState(damaged),
            expected: committed,
            writeToken: 'opening-damaged-$damage',
          ),
          isA<CapabilitySuccess<DocumentSnapshot>>(),
        );
        await expectLater(fixture.verifyDurable(), throwsStateError);
      } finally {
        await fixture.close();
      }
    });
  }
  test(
    'additional-debt benchmark rejects a durable source without its receipt',
    () async {
      final fixture = await ReviewPerformanceFixture.create(
        'missing-debt-proof',
        'review.suppliers.additional_debt',
      );
      try {
        await fixture.run();
        final read = await fixture.store.readDocument();
        final committed = (read as CapabilitySuccess<DocumentSnapshot?>).value!;
        const codec = PortableJournalCodec();
        final state = codec.decodeState(committed.payload);
        final wrong = await fixture.store.writeDocument(
          codec.encodeState(state.copyWith(receipts: [])),
          expected: committed,
          writeToken: 'remove-debt-receipt',
        );
        expect(wrong, isA<CapabilitySuccess<DocumentSnapshot>>());
        await expectLater(fixture.verifyDurable(), throwsStateError);
      } finally {
        await fixture.close();
      }
    },
  );
  for (final operation in [
    'review.portable.import',
    'review.portable.recover',
  ]) {
    test(
      '$operation refuses a new fence containing the wrong current payload',
      () async {
        final fixture = await ReviewPerformanceFixture.create(
          'wrong-payload',
          operation,
        );
        try {
          final expected = fixture.expectedReplacementPayload!;
          expect(expected, isNot(fixture.beforeRun.payload));
          await fixture.run();
          final read = await fixture.store.readDocument();
          final committed =
              (read as CapabilitySuccess<DocumentSnapshot?>).value!;
          expect(committed.payload, expected);
          expect(committed.fence, isNot(fixture.beforeRun.fence));
          final wrong = await fixture.store.writeDocument(
            fixture.beforeRun.payload,
            writeToken: 'wrong-current-payload',
            expected: committed,
            replaceGeneration: true,
          );
          expect(wrong, isA<CapabilitySuccess<DocumentSnapshot>>());
          await expectLater(fixture.verifyDurable(), throwsStateError);
        } finally {
          await fixture.close();
        }
      },
    );
  }
}
