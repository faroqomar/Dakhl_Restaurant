import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:madar_domain/madar_domain.dart' as domain;
import 'package:dakhl_restaurant/accounts/legacy_account_codec.dart';
import 'package:dakhl_restaurant/accounting/daily_cash_queries.dart';
import 'package:dakhl_restaurant/parties/purchase_proposal.dart';

Map<String, dynamic> fixture() =>
    (jsonDecode(File('test/fixtures/legacy/daily_cash.json').readAsStringSync())
            as Map<String, dynamic>)['state']
        as Map<String, dynamic>;

void main() {
  test('unpaid positive purchase invoice never creates paid spending', () {
    final base = const LegacyAccountCodec().decodeJson(fixture());
    final invoiced = PurchaseProposals(base).invoice(
      id: 'unpaid-invoice',
      supplierId: 's',
      number: '2',
      date: '2026-01-01',
      createdAt: '2026-01-01T12:00:00.000Z',
      note: '',
      lines: [
        const PurchaseLine(
          materialIdForCreation: 'material',
          name: 'Rice',
          unit: 'kg',
          quantityCartons: 0,
          quantityPieces: 2,
          priceCarton: 0,
          pricePiece: 100,
        ),
      ],
    );
    expect(invoiced.toJson()['invoices'], hasLength(1));
    final before = DailyCashQueries(base).statement();
    final after = DailyCashQueries(invoiced).statement();
    expect(after.rows, before.rows);
    expect(after.total, before.total);
    expect(after.domain.rows.map((row) => row.sourceKind), [
      'expense',
      'supplier-payment',
    ]);
    expect(after.total, BigInt.from(38000));
  });

  test('consumer uses public engine query with separate expense/payment identities', () {
    final raw = fixture();
    final expenses =
        ((raw['days'] as Map)['2026-01-01'] as Map)['expenses'] as List;
    (expenses.single as Map)['id'] = 'p'; // Valid separate source namespace.
    expenses.add({
      'id': 'zero',
      'categoryId': 'samoon',
      'amount': 0,
      'note': '',
    });
    final statement = DailyCashQueries(
      const LegacyAccountCodec().decodeJson(raw),
    ).statement();
    expect(statement.domain.rows.map((row) => (row.sourceKind, row.id)), [
      ('expense', 'p'),
      ('supplier-payment', 'p'),
    ]);
    expect(statement.total, BigInt.from(38000));
    expect(statement.rows.map((row) => row['id']), ['p', 'p']);
    expect(statement.domain.ranks.single.categoryId, 'market');
    expect(statement.domain.ranks.single.amount, statement.total);
    expect(statement.rows.last['kind'], 'supplier-payment');
    expect(statement.rows.last['supplierId'], 's');
    expect(statement.rows.last['originalAmount'], 8000);
    expect(statement.rows.last['note'], 'تسديد Supplier · الديون');
    expect(() => statement.rows.last['funding'] = {}, throwsUnsupportedError);
  });
  test(
    'shared payment funding obeys all daily and cash filter source oracle',
    () {
      final queries = DailyCashQueries(
        const LegacyAccountCodec().decodeJson(fixture()),
      );
      for (final (source, total, daily, cash) in [
        (SpendingSource.all, 38000, 23000, 15000),
        (SpendingSource.daily, 23000, 23000, 0),
        (SpendingSource.cash, 15000, 0, 15000),
      ]) {
        final statement = queries.statement(source: source);
        expect(statement.total, BigInt.from(total));
        expect(statement.dailyShare, BigInt.from(daily));
        expect(statement.cashShare, BigInt.from(cash));
        expect(statement.domain.total, statement.total);
        expect(statement.domain.dailyShare, statement.dailyShare);
      }
      expect(queries.statement(from: '2026-01-02').domain.rows, isEmpty);
      expect(queries.statement(categoryId: 'missing').domain.rows, isEmpty);
    },
  );
  test(
    'valid period totals exceed entry cap and paging preserves identity',
    () {
      final raw = Map<String, Object?>.of(
        const LegacyAccountCodec().empty().toJson(),
      );
      raw['days'] = {
        '2026-01-01': {
          'expenses': [
            for (var i = 0; i < 101; i++)
              {
                'id': 'expense-$i',
                'categoryId': 'market',
                'amount': 20000000000,
                'note': '',
                'funding': {
                  'source': 'daily',
                  'dailyAmount': 20000000000,
                  'cashAmount': 0,
                },
              },
          ],
          'chickenUsed': 0,
          'chickenLeft': 0,
          'balance': null,
          'totalOverride': null,
          'remaining': null,
          'corrections': <Object?>[],
        },
      };
      final statement = DailyCashQueries(
        const LegacyAccountCodec().decodeJson(raw),
      ).statement();
      expect(statement.total, BigInt.from(2020000000000));
      final pages = [
        for (var i = 1; i <= 3; i++) statement.domain.page(pageNumber: i),
      ];
      expect(pages.map((p) => p.items.length), [50, 50, 1]);
      expect(pages.expand((p) => p.items).map((r) => r.id).toSet().length, 101);
      expect(statement.domain.page(pageNumber: -1).pageNumber, 1);
      expect(statement.domain.page(pageNumber: 999).pageNumber, 3);
      expect(
        statement.domain.page(pageNumber: 1).items.first.id,
        'expense-100',
      );
      expect(
        statement.domain.rows.first.date,
        domain.DateOnly.parse(
          '2026-01-01',
          minimumYear: 1000,
          maximumYear: 9999,
        ),
      );
    },
  );
}
