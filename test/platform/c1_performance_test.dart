import 'dart:io';

import 'package:dakhl_restaurant/platform/c1_performance_scenarios.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'C1 options reject unsupported cases, unsafe IDs and iteration bounds',
    () {
      for (final arguments in [
        ['--case', 'catalog.lookup'],
        ['--case', 'c1.catalog.lookup', '--iterations', '0'],
        ['--case', 'c1.catalog.lookup', '--iterations', '101'],
        ['--case', 'c1.catalog.lookup', '--run-id', '../unsafe'],
        ['--case', 'c1.catalog.lookup', '--case', 'c1.catalog.page'],
        ['--case', 'c1.catalog.lookup', '--unknown', 'value'],
        ['--case'],
      ]) {
        expect(
          () => C1PerformanceOptions.parse(arguments),
          throwsFormatException,
        );
      }
    },
  );

  for (final operation in c1PerformanceCases) {
    test(
      '$operation verifies complete durable output and isolated cleanup',
      () async {
        final fixture = await C1PerformanceFixture.create('c1-unit', operation);
        final directory = fixture.directory;
        try {
          expect(
            fixture.repository.document!.toJson()['products'],
            hasLength(1000),
          );
          expect(
            fixture.repository.document!.toJson()['stockEntries'],
            hasLength(1200),
          );
          await fixture.run();
          await fixture.verifyDurable();
        } finally {
          await fixture.close();
        }
        expect(await Directory(directory.path).exists(), isFalse);
      },
    );
  }

  for (final operation in c1QueryCases) {
    test(
      '$operation consumes real output and makes no revision change',
      () async {
        final fixture = await C1PerformanceFixture.create(
          'c1-read-only',
          operation,
        );
        try {
          final before = fixture.repository.snapshot;
          await fixture.run();
          expect(fixture.repository.snapshot, same(before));
          expect(fixture.consumedIds, isNotEmpty);
          await fixture.verifyDurable();
        } finally {
          await fixture.close();
        }
      },
    );
  }

  test(
    'photo case reads the selected bundled asset and saves only its key',
    () async {
      final fixture = await C1PerformanceFixture.create(
        'c1-photo',
        'c1.product.photo_select_save',
      );
      try {
        await fixture.run();
        expect(fixture.loadedPhotoBytes, 58554);
        final product =
            (fixture.repository.document!.toJson()['products'] as List)
                .cast<Map<String, Object?>>()
                .singleWhere(
                  (row) => row['id'] == C1PerformanceFixture.targetProductId,
                );
        expect(product['photo'], 'chicken-kebab');
        expect(product.values.any((value) => value is List<int>), isFalse);
        await fixture.verifyDurable();
      } finally {
        await fixture.close();
      }
    },
  );

  test('fixture cannot be reused for a second measured mutation', () async {
    final fixture = await C1PerformanceFixture.create(
      'c1-once',
      'c1.stock.post',
    );
    try {
      await fixture.run();
      await expectLater(fixture.run(), throwsStateError);
      await fixture.verifyDurable();
    } finally {
      await fixture.close();
    }
  });

  test('durable verifier rejects an extra acknowledged mutation', () async {
    final fixture = await C1PerformanceFixture.create(
      'c1-tamper',
      'c1.product.edit',
    );
    try {
      await fixture.run();
      final raw = Map<String, Object?>.from(
        fixture.repository.document!.toJson(),
      );
      final products = (raw['products'] as List)
          .cast<Map<String, Object?>>()
          .toList();
      products[0] = {...products[0], 'price': 999};
      raw['products'] = products;
      await fixture.repository.save(fixture.repository.codec.decodeJson(raw));
      await expectLater(fixture.verifyDurable(), throwsStateError);
    } finally {
      await fixture.close();
    }
  });
}
