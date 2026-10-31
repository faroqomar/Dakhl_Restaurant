import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:dakhl_restaurant/accounts/legacy_account_codec.dart';

void main() {
  const codec = LegacyAccountCodec();
  final corpus = jsonDecode(
    File('test/fixtures/accounts/oracle.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  final cases = (corpus['cases'] as List).cast<Map<String, dynamic>>();
  test(
    'negative zero corpus preserves the raw token at the frozen validator',
    () {
      final sample = cases.singleWhere(
        (sample) => sample['name'] == 'negative-zero',
      );
      expect(sample['rawJson'], isA<String>());
      expect((sample['rawJson'] as String).contains('"price":-0'), isTrue);
      expect(sample['rawNegativeZeroObserved'], isTrue);
    },
  );
  Map<String, dynamic> historyFixture() => jsonDecode(
    jsonEncode(
      cases.singleWhere(
        (sample) => sample['name'] == 'all-entities-history',
      )['input'],
    ),
  ) as Map<String, dynamic>;
  for (final key in ['before', 'after']) {
    test('correction requires explicit $key while allowing null', () {
      final raw = historyFixture();
      final day = (raw['days'] as Map).values.first as Map;
      final correction = (day['corrections'] as List).first as Map;
      correction[key] = null;
      expect(
        () => codec.decodeBytes(utf8.encode(jsonEncode(raw))),
        returnsNormally,
      );
      correction.remove(key);
      expect(
        () => codec.decodeBytes(utf8.encode(jsonEncode(raw))),
        throwsA(
          isA<AccountCodecException>().having(
            (e) => e.code,
            'code',
            'invalid_payload',
          ),
        ),
      );
    });
  }
  test(
    'V8 source word predicate accepts punctuation before separated date',
    () {
      final raw = historyFixture();
      final sale = (raw['sales'] as List).first as Map;
      sale['createdAt'] = 'garbage[ 29 Feb 2024 GMT';
      expect(
        () => codec.decodeBytes(utf8.encode(jsonEncode(raw))),
        returnsNormally,
      );
      sale['createdAt'] = 'garbage[29 Feb 2024 GMT';
      expect(
        () => codec.decodeBytes(utf8.encode(jsonEncode(raw))),
        throwsA(isA<AccountCodecException>()),
      );
    },
  );
  group(
    'frozen model.validate parity, synthetic schema1–11 + seed0x02002610',
    () {
      for (final sample in cases) {
        test(sample['name'] as String, () {
          final bytes = utf8.encode(
            sample['rawJson'] as String? ?? jsonEncode(sample['input']),
          );
          if (sample['accepted'] == true) {
            final actual = codec.decodeBytes(bytes);
            expect(
              actual.toJson(),
              sample['expected'],
              reason: sample['name'] as String,
            );
            expect(actual.sourceVersion, (sample['input'] as Map)['version']);
            final reopened = codec.decodeBytes(codec.encode(actual));
            expect(
              reopened.toJson(),
              actual.toJson(),
              reason: 'canonical roundtrip seed0x02002610',
            );
            expect(
              codec.encode(reopened),
              codec.encode(actual),
              reason: 'normalization idempotence',
            );
          } else {
            expect(
              () => codec.decodeBytes(bytes),
              throwsA(isA<AccountCodecException>()),
            );
          }
        });
      }
    },
  );
  test('pinned frozen V8 timestamp composers: independent matrix + primary grammar', () {
    final timestampCases = (corpus['timestampCases'] as List)
        .cast<Map<String, dynamic>>();
    expect(timestampCases.length, 4127);
    final base = cases.firstWhere(
      (x) => x['name'] == 'all-entities-history',
    )['input'];
    final mismatches = <String>[];
    for (final sample in timestampCases) {
      final input = jsonDecode(jsonEncode(base)) as Map<String, dynamic>;
      final stamp = sample['stamp'] as String;
      (input['sales'] as List).first['createdAt'] = stamp;
      var accepted = false;
      try {
        final document = codec.decodeJson(input);
        accepted = true;
        if ((document.toJson()['sales'] as List).first['createdAt'] != stamp) {
          mismatches.add('text changed: $stamp');
        }
      } on AccountCodecException {
        /* A rejected source input remains rejected. */
      }
      if (accepted != sample['accepted']) {
        mismatches.add('$stamp: source=${sample['accepted']}, codec=$accepted');
      }
    }
    expect(mismatches.length, 0, reason: mismatches.take(12).join('\n'));
  });
  test('independent exact historical relationships and compatibility fields survive', () {
    final sample = cases.firstWhere((x) => x['name'] == 'all-entities-history');
    final document = codec.decodeBytes(
      utf8.encode(jsonEncode(sample['input'])),
    );
    final json = document.toJson();
    expect((json['sales'] as List).first['lines'][0]['name'], 'الاسم التاريخي');
    expect((json['saleReturns'] as List).first['saleId'], 'sale');
    expect((json['stockEntries'] as List).last['reversesId'], 'adjust');
    expect((json['savingsEntries'] as List).first['dueAmount'], 5000);
    expect(document.preferences.shortcuts, [
      'sales',
      '',
      '',
      'expenses',
      'cash',
      'settings',
    ]);
    expect(
      () => document.preferences.shortcuts.add('sales'),
      throwsUnsupportedError,
    );
    expect(() => json['version'] = 12, throwsUnsupportedError);
    expect(
      () => ((json['sales'] as List).first as Map)['id'] = 'changed',
      throwsUnsupportedError,
    );
  });
  test(
    'malformed UTF8, nonobject, invalid version and future version distinct',
    () {
      expect(
        () => codec.decodeBytes([0xff]),
        throwsA(
          isA<AccountCodecException>().having(
            (e) => e.code,
            'code',
            'invalid_payload',
          ),
        ),
      );
      expect(
        () => codec.decodeBytes(utf8.encode('[]')),
        throwsA(
          isA<AccountCodecException>().having(
            (e) => e.code,
            'code',
            'invalid_payload',
          ),
        ),
      );
      final empty = codec.empty().toJson();
      expect(
        () => codec.decodeBytes(
          utf8.encode(jsonEncode({...empty, 'version': 0})),
        ),
        throwsA(
          isA<AccountCodecException>().having(
            (e) => e.code,
            'code',
            'invalid_payload',
          ),
        ),
      );
      expect(
        () => codec.decodeBytes(
          utf8.encode(jsonEncode({...empty, 'version': 12})),
        ),
        throwsA(
          isA<AccountCodecException>().having(
            (e) => e.code,
            'code',
            'unsupported_version',
          ),
        ),
      );
    },
  );
  test(
    'both incoming and normalized serialized output are bounded independently',
    () {
      expect(
        () => codec.decodeBytes(
          Uint8List(LegacyAccountCodec.maxPayloadBytes + 1),
        ),
        throwsA(
          isA<AccountCodecException>().having(
            (e) => e.code,
            'code',
            'payload_too_large',
          ),
        ),
      );
      final empty = codec.empty().toJson();
      final days = <String, Object?>{};
      for (var day = 1; day <= 20; day++) {
        days['2024-01-${day.toString().padLeft(2, '0')}'] = {
          'expenses': [
            for (var index = 0; index < 10000; index++)
              {
                'id': 'e-$day-$index',
                'categoryId': 'bread',
                'amount': 1,
                'note': '',
              },
          ],
          'chickenUsed': 0,
          'chickenLeft': 0,
          'balance': null,
          'totalOverride': null,
          'remaining': null,
        };
      }
      final input = utf8.encode(jsonEncode({...empty, 'days': days}));
      expect(
        input.length,
        lessThanOrEqualTo(LegacyAccountCodec.maxPayloadBytes),
      );
      expect(
        () => codec.decodeBytes(input),
        throwsA(
          isA<AccountCodecException>().having(
            (e) => e.code,
            'normalized bound',
            'payload_too_large',
          ),
        ),
      );
    },
  );
  test(
    'JSON exponent values follow numeric source semantics; strings do not',
    () {
      final empty = codec.empty().toJson();
      final product = {
        'id': 'p',
        'name': 'test',
        'code': '',
        'unit': 'u',
        'group': '',
        'price': 0,
        'minStock': 0,
        'trackStock': false,
        'archived': false,
      };
      final raw = jsonEncode({
        ...empty,
        'products': [product],
      }).replaceFirst('"price":0', '"price":1e3');
      expect(
        (codec.decodeBytes(utf8.encode(raw)).toJson()['products'] as List)
            .first['price'],
        1000,
      );
      expect(
        () => codec.decodeJson({
          ...empty,
          'products': [
            {...product, 'price': '1e3'},
          ],
        }),
        throwsA(isA<AccountCodecException>()),
      );
    },
  );
}
