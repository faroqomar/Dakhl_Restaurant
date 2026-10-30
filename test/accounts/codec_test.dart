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
  group(
    'frozen model.validate parity, synthetic schema1–11 + seed0x02002610',
    () {
      for (final sample in cases) {
        test(sample['name'] as String, () {
          final bytes = utf8.encode(jsonEncode(sample['input']));
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
