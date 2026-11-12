import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:madar_domain/madar_domain.dart';
import 'package:dakhl_restaurant/accounts/account_document.dart';
import 'package:dakhl_restaurant/accounts/legacy_account_codec.dart';
import 'package:dakhl_restaurant/reports/sales_report.dart';

// Test-only comparator for these canonical ASCII date/time fixtures. Runtime
// ordering requires a qualified caller session, never this test helper.
SalesReport fixtureReport(
  AccountDocument document, {
  SalesHistoryFilter filter = const SalesHistoryFilter(),
  int Function(String, String)? compareText,
}) => SalesReport.build(
  document,
  filter: filter,
  compareText: compareText ?? (a, b) => a.compareTo(b),
);

// Frozen synthetic source results captured before retiring the Electron tree.
Map<String, dynamic> oracle() => jsonDecode(
  File('test/fixtures/legacy/sales_history.json').readAsStringSync(),
) as Map<String, dynamic>;

void main() {
  test('report rejects invalid source date bounds and reversed period', () {
    final empty = const LegacyAccountCodec().empty();
    expect(
      () => fixtureReport(
        empty,
        filter: const SalesHistoryFilter(from: '2026-02-01', to: '2026-01-01'),
      ),
      throwsFormatException,
    );
    expect(
      () => fixtureReport(
        empty,
        filter: const SalesHistoryFilter(from: '0999-12-31'),
      ),
      throwsA(isA<DomainValidationException>()),
    );
    expect(
      fixtureReport(
        empty,
        filter: const SalesHistoryFilter(from: '1000-01-01', to: '1000-01-01'),
      ).netMovement,
      BigInt.zero,
    );
  });
  late Map<String, dynamic> source;
  late AccountDocument document;
  setUpAll(() {
    source = oracle();
    document = const LegacyAccountCodec().decodeJson(
      (source['state'] as Map).cast<String, Object?>(),
    );
  });
  test(
    'frozen JS fixture history filtering and period totals agree for ten cases',
    () {
      final filters = source['filters'] as List;
      final expected = source['results'] as List;
      for (var i = 0; i < filters.length; i++) {
        final f = filters[i] as Map;
        if ((source['valid'] as List)[i] != true) {
          expect(
            () => fixtureReport(
              document,
              filter: SalesHistoryFilter(
                from: f['from'] as String? ?? '',
                to: f['to'] as String? ?? '',
              ),
            ),
            throwsFormatException,
          );
          continue;
        }
        final report = fixtureReport(
          document,
          filter: SalesHistoryFilter(
            from: f['from'] as String? ?? '',
            to: f['to'] as String? ?? '',
            query: f['query'] as String? ?? '',
            status: f['status'] as String? ?? '',
            orderType: f['orderType'] as String? ?? '',
          ),
        );
        expect(
          report.sales.map((s) => s.snapshot['id']).toList(),
          expected[i]['ids'],
        );
        expect(
          report.returns.map((r) => r['id']).toList(),
          expected[i]['returns'],
        );
        expect(report.refunded.toString(), '${expected[i]['refunded']}');
        expect(report.netMovement.toString(), '${expected[i]['total']}');
        expect(report.completedCount, expected[i]['completed']);
        expect(report.voidCount, expected[i]['voided']);
      }
    },
  );
  test('return-only period is negative; snapshots are immutable and catalog-independent', () {
    final report = fixtureReport(
      document,
      filter: const SalesHistoryFilter(from: '2026-01-03', to: '2026-01-03'),
    );
    expect(report.sales, isEmpty);
    expect(report.netMovement, BigInt.from(-100));
    final all = fixtureReport(document);
    final sale = all.sales.singleWhere((s) => s.snapshot['id'] == 'a');
    expect(sale.total, BigInt.from(201));
    expect(sale.lifetimeRefunded, BigInt.from(100));
    expect((sale.snapshot['lines'] as List).first['name'], 'Historic Rice');
    expect(() => sale.snapshot['note'] = 'mutate', throwsUnsupportedError);
    expect(() => all.returns.clear(), throwsUnsupportedError);
    expect(
      () => ((sale.snapshot['lines'] as List).first as Map)['price'] = 1,
      throwsUnsupportedError,
    );
  });
  test('invalid date/status filters fail with sanitized errors', () {
    expect(
      () => fixtureReport(
        document,
        filter: const SalesHistoryFilter(from: '2026-02-30'),
      ),
      throwsA(isA<DomainValidationException>()),
    );
    expect(
      () => fixtureReport(
        document,
        filter: const SalesHistoryFilter(status: 'paid'),
      ),
      throwsFormatException,
    );
  });
  test('valid multi-day history preserves frozen binary64 aggregate', () {
    final raw = {...document.toJson()};
    final template = (raw['sales'] as List).first as Map<String, Object?>;
    final line = (template['lines'] as List).first as Map<String, Object?>;
    raw['saleReturns'] = <Object?>[];
    raw['sales'] = [
      for (var i = 0; i < 9008; i++)
        {
          ...template,
          'id': 'large-$i',
          'number': 'L-$i',
          'date': DateTime.utc(
            2000,
            1,
            1,
          ).add(Duration(days: i)).toIso8601String().substring(0, 10),
          'discount': i.isOdd ? 1 : 0,
          'paid': 1000000000000,
          'lines': [
            {...line, 'quantity': 1000, 'price': 1000000000},
          ],
        },
    ];
    final large = const LegacyAccountCodec().decodeJson(raw);
    final expectedTotal = (jsonDecode(
      File('test/fixtures/legacy/sales_large_total.json').readAsStringSync(),
    ) as Map)['expectedTotal'];
    final report = fixtureReport(large);
    expect(report.completedTotal.toString(), expectedTotal);
    expect(report.netMovement, report.completedTotal);
    expect(
      report.completedTotal,
      greaterThan(BigInt.parse('9007199254740991')),
    );
  });
  test('legacy timestamps require injected source weights without lexical fallback', () {
    final raw = {...document.toJson()};
    raw['sales'] = [
      for (final value in raw['sales'] as List)
        {
          ...value as Map<String, Object?>,
          if (value['id'] == 'b') 'createdAt': 'Jan 2, 2026 12:00:00',
          if (value['id'] == 'c') 'createdAt': 'jan 2, 2026 12:00:00',
        },
    ];
    final legacy = const LegacyAccountCodec().decodeJson(raw);
    expect(
      () => SalesReport.build(
        legacy,
        filter: const SalesHistoryFilter(from: '2026-01-02', to: '2026-01-02'),
      ),
      throwsFormatException,
    );
    final report = fixtureReport(
      legacy,
      filter: const SalesHistoryFilter(from: '2026-01-02', to: '2026-01-02'),
      // Captured finite pair weights below, not a production comparator.
      compareText: (a, b) {
        if (a == b) return 0;
        const ranks = {'Jan 2, 2026 12:00:00': 1, 'jan 2, 2026 12:00:00': 0};
        return ranks[a]!.compareTo(ranks[b]!);
      },
    );
    expect(report.sales.map((row) => row.snapshot['id']), ['b', 'c']);
    // The fixture's captured source ordering is ['b', 'c']; this test uses
    // finite source weights and does not qualify a production comparator.
  });
}
