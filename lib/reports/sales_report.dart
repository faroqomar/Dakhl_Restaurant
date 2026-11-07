import 'package:madar_domain/madar_domain.dart';

import '../accounts/account_document.dart';

/// Source history filters. Empty strings disable the corresponding filter.
/// Text searches saved receipt numbers, notes and line names without trimming.
final class SalesHistoryFilter {
  const SalesHistoryFilter({
    this.from = '',
    this.to = '',
    this.status = '',
    this.orderType = '',
    this.query = '',
  });
  final String from, to, status, orderType, query;
}

/// Immutable saved sale, with its original total and all-time refund amount.
final class SaleHistoryRow {
  const SaleHistoryRow._(this.snapshot, this.total, this.lifetimeRefunded);
  final Map<String, Object?> snapshot;
  final BigInt total, lifetimeRefunded;
}

/// Read-only history composition. Net movement is not profit or cashbox balance.
final class SalesReport {
  SalesReport._({
    required Iterable<SaleHistoryRow> sales,
    required Iterable<Map<String, Object?>> returns,
    required this.completedCount,
    required this.voidCount,
    required this.completedTotal,
    required this.refunded,
    required this.netMovement,
  }) : sales = List.unmodifiable(sales),
       returns = List.unmodifiable(returns);

  final List<SaleHistoryRow> sales;
  final List<Map<String, Object?>> returns;
  final int completedCount, voidCount;
  final BigInt completedTotal, refunded, netMovement;

  static final _safe = BigInt.parse('9007199254740991');
  static final _money = BigInt.from(1000000000000);
  static final _policy = CommercePolicy(
    quantityScale: 3,
    maximumQuantityUnits: _money,
    maximumMoney: _money,
    maximumSafeInteger: _safe,
    rounding: DecimalRounding.halfTowardPositiveInfinity,
  );
  static BigInt _sum(Iterable<BigInt> values) =>
      ExactMath.binary64IntegerSum(values);
  static BigInt _saleTotal(Map<String, Object?> sale) =>
      CommerceCalculations.saleQuote(
        (sale['lines']! as List).cast<Map<String, Object?>>().map(
          (line) => CommerceCalculations.lineTotal(
            QuantityPrice(
              quantityUnits: ExactDecimal.parse(
                '${line['quantity']}',
                scale: 3,
                maxAbsUnits: _money,
                signed: false,
                positive: true,
              ).units,
              price: BigInt.from(line['price']! as int),
            ),
            policy: _policy,
          ),
        ),
        discount: BigInt.from(sale['discount']! as int),
        policy: _policy,
      ).net;

  /// Takes a codec-validated snapshot and preserves the frozen history UI
  /// binary64 accumulation order, including representable unsafe aggregates.
  static SalesReport build(
    AccountDocument document, {
    SalesHistoryFilter filter = const SalesHistoryFilter(),
  }) {
    for (final date in [filter.from, filter.to]) {
      if (date.isNotEmpty) {
        DateOnly.parse(date, minimumYear: 1000, maximumYear: 9999);
      }
    }
    if (filter.from.isNotEmpty &&
        filter.to.isNotEmpty &&
        filter.from.compareTo(filter.to) > 0) {
      throw const FormatException('Invalid sales date range');
    }
    if (!['', 'completed', 'void'].contains(filter.status)) {
      throw const FormatException('Invalid sales status filter');
    }
    bool inPeriod(String date) =>
        (filter.from.isEmpty || date.compareTo(filter.from) >= 0) &&
        (filter.to.isEmpty || date.compareTo(filter.to) <= 0);
    final query = LegacyCase.lower(
      filter.query,
      profile: LegacyCaseProfile.ecmascriptUnicode17,
    );
    bool matches(Map<String, Object?> sale) {
      final names = (sale['lines']! as List)
          .cast<Map<String, Object?>>()
          .map((line) => line['name'])
          .join(' ');
      return (filter.status.isEmpty || sale['status'] == filter.status) &&
          (filter.orderType.isEmpty || sale['orderType'] == filter.orderType) &&
          LegacyCase.lower(
            '${sale['number']} ${sale['note']} $names',
            profile: LegacyCaseProfile.ecmascriptUnicode17,
          ).contains(query);
    }

    final raw = document.toJson();
    final allSales = (raw['sales']! as List).cast<Map<String, Object?>>();
    final allReturns = (raw['saleReturns']! as List)
        .cast<Map<String, Object?>>();
    final index = {for (final sale in allSales) sale['id']! as String: sale};
    final lifetime = <String, List<BigInt>>{};
    for (final refund in allReturns) {
      (lifetime[refund['saleId']! as String] ??= []).add(
        BigInt.from(refund['amount']! as int),
      );
    }
    final selected = allSales
        .where((sale) => inPeriod(sale['date']! as String) && matches(sale))
        .toList();
    // Preserve source array order when both source sort keys tie. Dart's sort
    // is not stable, so use the original ordinal as the final comparator.
    final ordinal = {
      for (var i = 0; i < allSales.length; i++) allSales[i]['id']: i,
    };
    selected.sort((a, b) {
      final date = (b['date']! as String).compareTo(a['date']! as String);
      if (date != 0) return date;
      final created = (b['createdAt']! as String).compareTo(
        a['createdAt']! as String,
      );
      return created != 0
          ? created
          : ordinal[a['id']]!.compareTo(ordinal[b['id']]!);
    });
    final rows = [
      for (final sale in selected)
        SaleHistoryRow._(
          sale,
          _saleTotal(sale),
          _sum(lifetime[sale['id']] ?? []),
        ),
    ];
    final returns = allReturns.where((refund) {
      final sale = index[refund['saleId']];
      return inPeriod(refund['date']! as String) &&
          sale != null &&
          matches(sale);
    }).toList();
    final active = rows
        .where((row) => row.snapshot['status'] == 'completed')
        .toList();
    final completedTotal = _sum(active.map((row) => row.total));
    final refunded = _sum(
      returns.map((refund) => BigInt.from(refund['amount']! as int)),
    );
    return SalesReport._(
      sales: rows,
      returns: returns,
      completedCount: active.length,
      voidCount: rows.length - active.length,
      completedTotal: completedTotal,
      refunded: refunded,
      netMovement: _sum([completedTotal, -refunded]),
    );
  }
}
