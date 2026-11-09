import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:dakhl_restaurant/accounts/legacy_account_codec.dart';
import 'package:dakhl_restaurant/inventory/stock_projection.dart';
import 'package:madar_domain/madar_domain.dart';

DateOnly day(String value) =>
    DateOnly.parse(value, minimumYear: 1000, maximumYear: 9999);
const codec = LegacyAccountCodec();
Map<String, Object?> fixture() => {
  ...codec.empty().toJson(),
  'products': [
    {
      'id': 'p',
      'name': 'صنف',
      'code': 'P',
      'group': '',
      'unit': 'قطعة',
      'price': 1000,
      'minStock': 1,
      'trackStock': true,
      'archived': false,
    },
  ],
  'stockEntries': [
    {
      'id': 'open',
      'productId': 'p',
      'date': '2026-01-01',
      'quantity': 3.5,
      'kind': 'opening',
      'note': '',
      'createdAt': '2026-01-01T00:00:00Z',
    },
    {
      'id': 'future',
      'productId': 'p',
      'date': '2026-02-01',
      'quantity': 2,
      'kind': 'restock',
      'note': '',
      'createdAt': '2026-01-01T00:00:00Z',
    },
  ],
  'sales': [
    {
      'id': 's',
      'number': 'S-000001',
      'date': '2026-01-02',
      'status': 'completed',
      'createdAt': '2026-01-02T00:00:00Z',
      'lines': [
        {
          'productId': 'p',
          'name': 'قديم',
          'unit': 'قطعة',
          'trackStock': true,
          'price': 1000,
          'quantity': 1.25,
        },
      ],
      'discount': 0,
      'paid': 1250,
      'note': '',
    },
  ],
};
void main() {
  test(
    'source oracle corpus passes through validated consumer record mapping',
    () {
      final corpus = jsonDecode(
        File('test/inventory/stock_parity.json').readAsStringSync(),
      ) as Map;
      for (final c in (corpus['cases'] as List).cast<Map>()) {
        final raw = <String, Object?>{...codec.empty().toJson()};
        raw['products'] = fixture()['products'];
        final entries = <Map<String, Object?>>[],
            sales = <Map<String, Object?>>[],
            returns = <Map<String, Object?>>[];
        var index = 0;
        String? lastSale;
        for (final segment in (c['segments'] as List).cast<Map>()) {
          for (var i = 0; i < (segment['count'] as int); i++) {
            final id = 'e${index++}', date = segment['date'];
            final quantity = (segment['units'] as num) / 1000;
            final stamp = '2026-01-01T00:00:00.000Z';
            if (segment['bucket'] == 'incoming') {
              entries.add({
                'id': id,
                'productId': 'p',
                'date': date,
                'quantity': quantity,
                'kind': 'adjustment',
                'note': '',
                'createdAt': stamp,
              });
            }
            if (segment['bucket'] == 'outgoing') {
              lastSale = id;
              sales.add({
                'id': id,
                'number': id,
                'date': date,
                'status': 'completed',
                'lines': [
                  {
                    'productId': 'p',
                    'name': 'Synthetic',
                    'unit': 'piece',
                    'quantity': quantity,
                    'price': 0,
                    'trackStock': true,
                  },
                ],
                'discount': 0,
                'paid': 0,
                'note': '',
                'createdAt': stamp,
              });
            }
            if (segment['bucket'] == 'returned') {
              returns.add({
                'id': id,
                'saleId': lastSale,
                'date': date,
                'reason': 'synthetic',
                'createdAt': stamp,
                'lines': [
                  {
                    'productId': 'p',
                    'quantity': quantity,
                    'restock': true,
                    'amount': 0,
                  },
                ],
                'amount': 0,
              });
            }
          }
        }
        raw['stockEntries'] = entries;
        raw['sales'] = sales;
        raw['saleReturns'] = returns;
        if (c['valid'] != true) {
          expect(
            () => codec.decodeJson(raw),
            throwsA(isA<AccountCodecException>()),
            reason: c['name'] as String,
          );
          continue;
        }
        final projection = RestaurantStockProjection(codec.decodeJson(raw));
        final through = day(c['through'] as String);
        expect(
          projection.balanceFor('p', through: through).toString(),
          c['groupedUnits'],
          reason: c['name'] as String,
        );
        expect(
          projection.balancesAt(through)['p'].toString(),
          c['sequentialUnits'],
          reason: c['name'] as String,
        );
        projection.validateHistory();
      }
    },
  );
  test(
    'returns restore only selected stock on their inclusive effective date',
    () {
      final raw = fixture();
      raw['saleReturns'] = [
        for (final (id, date, restock) in [
          ('r1', '2026-01-03', true),
          ('r2', '2026-01-04', false),
        ])
          {
            'id': id,
            'saleId': 's',
            'date': date,
            'reason': 'synthetic',
            'createdAt': '2026-01-04T00:00:00Z',
            'lines': [
              {
                'productId': 'p',
                'quantity': 0.25,
                'restock': restock,
                'amount': 250,
              },
            ],
            'amount': 250,
          },
      ];
      final projection = RestaurantStockProjection(codec.decodeJson(raw));
      for (final (date, units) in [
        ('2026-01-02', 2250),
        ('2026-01-03', 2500),
        ('2026-01-04', 2500),
      ]) {
        expect(
          projection.balanceFor('p', through: day(date)),
          BigInt.from(units),
        );
        expect(projection.balancesAt(day(date))['p'], BigInt.from(units));
      }
      projection.validateHistory();
    },
  );

  test('validated restaurant records feed source-specific engine queries', () {
    final account = codec.decodeJson(fixture());
    final projection = RestaurantStockProjection(account);
    expect(projection.balancesAt(day('2026-01-02'))['p'], BigInt.from(2250));
    expect(
      projection.balanceFor('p', through: day('2026-02-01')),
      BigInt.from(4250),
    );
    expect(
      projection.balanceFor('missing', through: day('2026-02-01')),
      BigInt.zero,
    );
    projection.validateHistory();
    expect(
      (account.toJson()['sales'] as List).first['lines'][0]['name'],
      'قديم',
    );
  });
  test(
    'catalog balance query result is immutable and excludes future dates',
    () {
      final projection = RestaurantStockProjection(codec.decodeJson(fixture()));
      final balances = projection.balancesAt(day('2025-12-31'));
      expect(balances['p'], BigInt.zero);
      expect(() => balances['p'] = BigInt.one, throwsUnsupportedError);
    },
  );
  test('void sales do not reduce quantity', () {
    final raw = fixture();
    final sale = (raw['sales'] as List).first as Map;
    sale['status'] = 'void';
    sale['voidReason'] = 'خطأ';
    sale['voidedAt'] = '2026-01-03T00:00:00Z';
    expect(
      RestaurantStockProjection(codec.decodeJson(raw))
          .balancesAt(day('2026-01-02'))['p'],
      BigInt.from(3500),
    );
  });
}
