import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:dakhl_restaurant/accounts/legacy_account_codec.dart';
import 'package:dakhl_restaurant/accounting/daily_cash_queries.dart';

void main() {
  test('daily cash and refund dates match frozen source', () {
    final oracle = jsonDecode(
      File('test/fixtures/legacy/daily_cash.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final doc = const LegacyAccountCodec().decodeJson(
      oracle['state'] as Map<String, dynamic>,
    );
    final queries = DailyCashQueries(doc);
    for (final expected in oracle['results'] as List) {
      final day = queries.day(expected['date'] as String);
      expect(day.dailySpent.toString(), '${expected['dailySpent']}');
      expect(day.transferred.toString(), '${expected['transferred']}');
      expect(day.remaining?.toString(), expected['remaining']?.toString());
      expect(day.total.toString(), '${expected['total']}');
      expect(day.netSales.toString(), '${expected['salesTotal']}');
      expect(queries.cashBalance.toString(), '${expected['cash']}');
      expect(
        queries.expenses(expected['date'] as String).length,
        expected['expenseCount'],
      );
    }
    expect(queries.cashMovements, oracle['movements']);
    expect(
      () => queries.cashMovements.first['amount'] = 0,
      throwsUnsupportedError,
    );
    expect(queries.day('2026-01-01').remaining, BigInt.from(102000));
    expect(queries.day('2026-01-01').recordedBalance, BigInt.from(125000));
    final cash = queries.statement(source: SpendingSource.cash);
    expect(cash.total, BigInt.from(15000));
    expect(cash.dailyShare, BigInt.zero);
    expect(cash.cashShare, BigInt.from(15000));
    expect(cash.rows.length, 2);
    expect(
      queries.statement(source: SpendingSource.daily).total,
      BigInt.from(23000),
    );
    expect(queries.statement(categoryId: 'absent').rows, isEmpty);
    expect(queries.statement(from: '2026-01-02').total, BigInt.zero);
    expect(
      () => queries.statement(from: '2026-02-01', to: '2026-01-01'),
      throwsFormatException,
    );
    expect(() => queries.day('0999-01-01'), throwsA(isA<Exception>()));
    expect(() => cash.rows.add({}), throwsUnsupportedError);
    expect(
      () => cash.byCategory['market'] = BigInt.zero,
      throwsUnsupportedError,
    );
    expect(
      queries.expenses('2026-01-01').last['note'],
      'تسديد Supplier · الديون',
    );
    final changed =
        jsonDecode(jsonEncode(oracle['state'])) as Map<String, dynamic>;
    final rawDay = (changed['days'] as Map)['2026-01-01'] as Map;
    rawDay['chickenUsed'] = 90;
    rawDay['chickenLeft'] = 80;
    rawDay['totalOverride'] = 45000;
    final changedQueries = DailyCashQueries(
      const LegacyAccountCodec().decodeJson(changed),
    );
    expect(changedQueries.day('2026-01-01').dailySpent, BigInt.from(23000));
    expect(changedQueries.day('2026-01-01').total, BigInt.from(45000));
    expect(changedQueries.cashBalance, queries.cashBalance);
    expect(changedQueries.day('2026-01-01').remaining, BigInt.from(102000));
  });
}
