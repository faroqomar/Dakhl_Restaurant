import 'dart:convert';

import 'package:madar_domain/madar_domain.dart';

import '../accounts/account_document.dart';

/// Restaurant schema mapping only. Madar owns all quantity arithmetic/query
/// expression profiles. Input must be a codec-validated account snapshot.
final class RestaurantStockProjection {
  RestaurantStockProjection(this.account);
  final AccountDocument account;
  static const _profile = StockSummation.legacyBinary64Integer;
  static final _limit = BigInt.from(1000000000000);
  List<Map<String, Object?>> _records(String key) =>
      (account.toJson()[key] as List).cast<Map<String, Object?>>();
  DateOnly _date(Object? value) =>
      DateOnly.parse(value as String, minimumYear: 1000, maximumYear: 9999);
  BigInt _units(Object? value) => ExactDecimal.parse(
    value.toString(),
    scale: 3,
    maxAbsUnits: _limit,
    signed: true,
    positive: false,
    allowExponent: true,
  ).units;
  List<Map<String, Object?>> _lines(Map<String, Object?> record) =>
      (record['lines'] as List).cast<Map<String, Object?>>();

  Iterable<StockMovement> _movements(String productId) sync* {
    for (final entry in _records('stockEntries')) {
      if (entry['productId'] == productId) {
        yield StockMovement(
          id: jsonEncode(['entry', entry['id']]),
          effectiveDate: _date(entry['date']),
          deltaUnits: _units(entry['quantity']),
        );
      }
    }
    for (final sale in _records('sales')) {
      if (sale['status'] != 'completed') continue;
      final lines = _lines(sale);
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        if (line['productId'] == productId && line['trackStock'] == true) {
          yield StockMovement(
            id: jsonEncode(['sale', sale['id'], i]),
            effectiveDate: _date(sale['date']),
            deltaUnits: -_units(line['quantity']),
          );
        }
      }
    }
    for (final record in _records('saleReturns')) {
      final lines = _lines(record);
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        if (line['productId'] == productId && line['restock'] == true) {
          yield StockMovement(
            id: jsonEncode(['return', record['id'], i]),
            effectiveDate: _date(record['date']),
            deltaUnits: _units(line['quantity']),
          );
        }
      }
    }
  }

  /// Matches source stockBalances() for catalog inventory presentation.
  Map<String, BigInt> balancesAt(DateOnly through) => Map.unmodifiable({
    for (final product in _records('products'))
      product['id'] as String: StockQueries.sequentialBalance(
        _movements(product['id'] as String),
        through: through,
        summation: _profile,
      ),
  });

  /// Matches source stock() used by single-item availability checks. Its
  /// grouping intentionally differs from stockBalances() at numeric extremes.
  BigInt balanceFor(String productId, {required DateOnly through}) {
    bool eligible(Map<String, Object?> record) =>
        _date(record['date']).compareTo(through) <= 0;
    return StockQueries.groupedBalance(
      incoming: _records('stockEntries')
          .where((e) => e['productId'] == productId && eligible(e))
          .map((e) => _units(e['quantity'])),
      outgoingGroups: _records('sales')
          .where((s) => s['status'] == 'completed' && eligible(s))
          .map(
            (s) => _lines(s)
                .where(
                  (l) => l['productId'] == productId && l['trackStock'] == true,
                )
                .map((l) => _units(l['quantity'])),
          ),
      returned: _records('saleReturns')
          .where(eligible)
          .expand(_lines)
          .where((l) => l['productId'] == productId && l['restock'] == true)
          .map((l) => _units(l['quantity'])),
      summation: _profile,
    );
  }

  void validateHistory() {
    for (final product in _records('products')) {
      StockHistory.validate(
        _movements(product['id'] as String),
        summation: _profile,
        minimumBalance: BigInt.zero,
        maximumBalance: _limit,
      );
    }
  }
}
