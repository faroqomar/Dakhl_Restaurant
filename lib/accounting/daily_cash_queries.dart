import 'package:madar_domain/madar_domain.dart' hide PaidSpendingStatement;
import 'package:madar_domain/madar_domain.dart' as paid;

import '../accounts/account_document.dart';
import '../reports/source_event_order.dart';

enum SpendingSource { all, daily, cash }

final class DailyCashSnapshot {
  const DailyCashSnapshot({
    required this.dailySpent,
    required this.transferred,
    required this.netSales,
    required this.total,
    required this.remaining,
    required this.recordedBalance,
  });
  final BigInt dailySpent, transferred, netSales, total;
  final BigInt? remaining, recordedBalance;
}

final class PaidSpendingStatement {
  PaidSpendingStatement._(List<Map<String, Object?>> rows, this.domain)
    : rows = List.unmodifiable(rows);
  final List<Map<String, Object?>> rows;

  /// Shared query results, including stable category ranks and pagination.
  final paid.PaidSpendingStatement domain;
  BigInt get total => domain.total;
  BigInt get dailyShare => domain.dailyShare;
  BigInt get cashShare => domain.cashShare;

  /// Insertion order is the frozen source tie-break for equal ranked amounts.
  Map<String, BigInt> get byCategory => domain.byCategory;
}

/// Read-only projections of codec-validated historical records. These values are
/// cash/spending snapshots, never profit. No journal mapping or writes occur.
final class DailyCashQueries {
  DailyCashQueries(AccountDocument document) : _state = document.toJson();
  final Map<String, Object?> _state;
  static BigInt _n(Object? value) => BigInt.from(value! as int);
  static BigInt _sum(Iterable<BigInt> values) =>
      ExactMath.binary64IntegerSum(values);
  static BigInt _add(BigInt a, BigInt b) => _sum([a, b]);
  List<Map<String, Object?>> _rows(String key) =>
      (_state[key]! as List).cast<Map<String, Object?>>();
  Map<String, Object?> _day(String date) =>
      ((_state['days']! as Map)[date] as Map<String, Object?>?) ?? const {};
  static Map<String, Object?> _funding(Map<String, Object?> row) =>
      row['funding'] as Map<String, Object?>? ??
      {'source': 'daily', 'dailyAmount': row['amount'], 'cashAmount': 0};
  static void _date(String date) =>
      DateOnly.parse(date, minimumYear: 1000, maximumYear: 9999);

  /// Original expense snapshots followed by supplier payments, once each.
  List<Map<String, Object?>> expenses(String date) {
    _date(date);
    return List.unmodifiable([
      ...((_day(date)['expenses'] as List?) ?? []).cast<Map<String, Object?>>(),
      for (final row in _rows('payments'))
        if (row['date'] == date)
          Map<String, Object?>.unmodifiable({
            ...row,
            'kind': 'supplier-payment',
            'note': _paymentNote(row),
          }),
    ]);
  }

  String _paymentNote(Map<String, Object?> payment) {
    final suppliers = _rows('suppliers')
        .where((s) => s['id'] == payment['supplierId']);
    final invoices = _rows('invoices')
        .where((i) => i['id'] == payment['invoiceId']);
    final name = suppliers.isEmpty ? 'مورد' : suppliers.first['name'];
    final debt =
        payment['debtAmount'] ??
        (payment['invoiceId'] == null ? payment['amount'] : 0);
    final target = invoices.isEmpty
        ? 'الديون'
        : 'قائمة ${invoices.first['number']}${debt != 0 ? ' · ديون $debt د.ع' : ''}';
    final note = payment['note'] as String? ?? '';
    return 'تسديد $name · $target${note.isNotEmpty ? ' · $note' : ''}';
  }

  static final _money = BigInt.from(1000000000000);
  static final _policy = CommercePolicy(
    quantityScale: 3,
    maximumQuantityUnits: _money,
    maximumMoney: _money,
    maximumSafeInteger: BigInt.parse('9007199254740991'),
    rounding: DecimalRounding.halfTowardPositiveInfinity,
  );
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
              price: _n(line['price']),
            ),
            policy: _policy,
          ),
        ),
        discount: _n(sale['discount']),
        policy: _policy,
      ).net;

  BigInt netSales(String date) {
    _date(date);
    final sales = _sum(
      _rows('sales')
          .where((s) => s['date'] == date && s['status'] == 'completed')
          .map(_saleTotal),
    );
    final refunds = _sum(
      _rows('saleReturns')
          .where((r) => r['date'] == date)
          .map((r) => _n(r['amount'])),
    );
    final result = _add(sales, -refunds);
    if (result.abs() > _money) {
      throw const FormatException(
        'Daily net sales exceed source money bounds.',
      );
    }
    return result;
  }

  DailyCashSnapshot day(String date) {
    _date(date);
    final d = _day(date);
    final spent = _sum(
      expenses(date).map((e) => _n(_funding(e)['dailyAmount'])),
    );
    final transferred = _sum(
      _rows('transfers')
          .where((t) => t['date'] == date)
          .map((t) => _n(t['amount'])),
    );
    final sales = netSales(date);
    final r = d['remaining'] as Map<String, Object?>?;
    // Preserve source binary64 grouping at every subtraction/addition.
    final remaining = r == null
        ? null
        : _add(
            _add(
              _add(_n(r['amount']), -_add(spent, -_n(r['dailySpent']))),
              -_add(transferred, -_n(r['transferred'])),
            ),
            _add(sales, -_n(r['salesTotal'] ?? 0)),
          );
    return DailyCashSnapshot(
      dailySpent: spent,
      transferred: transferred,
      netSales: sales,
      total: d['totalOverride'] == null ? spent : _n(d['totalOverride']),
      remaining: remaining,
      recordedBalance: d['balance'] == null ? null : _n(d['balance']),
    );
  }

  /// Explicit cash entries followed by derived funding withdrawals and transfers.
  /// Rows preserve source identity so callers can distinguish editable entries
  /// from effects owned by an expense, supplier payment or transfer.
  List<Map<String, Object?>> get cashMovements {
    final rows = <Map<String, Object?>>[
      for (final transaction in _rows('transactions'))
        Map.unmodifiable({...transaction, 'kind': 'cash'}),
    ];
    final dates = <String>{
      ...(_state['days']! as Map).keys.cast<String>(),
      ..._rows('payments').map((p) => p['date']! as String),
    };
    for (final date in dates) {
      for (final expense in expenses(date)) {
        final amount = _funding(expense)['cashAmount'];
        if (_n(amount) == BigInt.zero) continue;
        rows.add(
          Map.unmodifiable({
            'id': expense['id'],
            'date': date,
            'type': 'withdrawal',
            'kind': expense['kind'] ?? 'expense',
            if (expense.containsKey('supplierId'))
              'supplierId': expense['supplierId'],
            'amount': amount,
            'note': expense['note'],
            'categoryId': expense['categoryId'],
            'createdAt': expense['createdAt'] ?? '${date}T12:00:00.000Z',
          }),
        );
      }
    }
    rows.addAll(
      _rows('transfers').map(
        (t) => Map<String, Object?>.unmodifiable({
          ...t,
          'type': 'deposit',
          'kind': 'transfer',
        }),
      ),
    );
    return List.unmodifiable(rows);
  }

  /// renderer.js orderedTransactions: descending date, createdAt, id; exact
  /// ties retain the original merged movement encounter order.
  List<Map<String, Object?>> orderedCashMovements(
    int Function(String, String)? compareText,
  ) => orderSourceEvents(
    cashMovements,
    keys: const ['date', 'createdAt', 'id'],
    descending: true,
    compareText: compareText,
  );

  BigInt get cashBalance => _sum(
    cashMovements.map(
      (row) =>
          row['type'] == 'withdrawal' ? -_n(row['amount']) : _n(row['amount']),
    ),
  );

  PaidSpendingStatement statement({
    String from = '',
    String to = '',
    String categoryId = '',
    SpendingSource source = SpendingSource.all,
  }) {
    if (from.isNotEmpty) _date(from);
    if (to.isNotEmpty) _date(to);
    if (from.isNotEmpty && to.isNotEmpty && from.compareTo(to) > 0) {
      throw const FormatException('Reversed date range.');
    }
    final dates = <String>{
      ...(_state['days']! as Map).keys.cast<String>(),
      ..._rows('payments').map((payment) => payment['date']! as String),
    }.toList()..sort();
    final records = <paid.PaidSpendingRecord>[];
    final originals = <(String, String), Map<String, Object?>>{};
    for (final date in dates) {
      for (final entry in expenses(date)) {
        final amount = _n(entry['amount']);
        // Legacy zero expenses are valid history but absent from statements.
        // Liabilities never enter this stream; expenses() supplies paid rows.
        if (amount == BigInt.zero) continue;
        final funding = _funding(entry);
        final kind = entry['kind'] as String? ?? 'expense';
        final id = entry['id']! as String;
        originals[(kind, id)] = entry;
        records.add(
          paid.PaidSpendingRecord(
            id: id,
            date: DateOnly.parse(date, minimumYear: 1000, maximumYear: 9999),
            categoryId: entry['categoryId']! as String,
            amount: amount,
            dailyAmount: _n(funding['dailyAmount']),
            cashAmount: _n(funding['cashAmount']),
            note: entry['note'] as String? ?? '',
            sourceKind: kind,
          ),
        );
      }
    }
    final statement = paid.PaidSpendingQueries.execute(
      records: records,
      filter: paid.PaidSpendingFilter(
        from: from.isEmpty
            ? null
            : DateOnly.parse(from, minimumYear: 1000, maximumYear: 9999),
        to: to.isEmpty
            ? null
            : DateOnly.parse(to, minimumYear: 1000, maximumYear: 9999),
        categoryId: categoryId,
        source: switch (source) {
          SpendingSource.all => paid.PaidSpendingSourceFilter.all,
          SpendingSource.daily => paid.PaidSpendingSourceFilter.daily,
          SpendingSource.cash => paid.PaidSpendingSourceFilter.cash,
        },
      ),
      summation: paid.PaidSpendingSummation.legacyBinary64Integer,
      maximumMoney: _money,
      maximumSafeInteger: _policy.maximumSafeInteger,
    );
    return PaidSpendingStatement._([
      for (final row in statement.rows)
        Map<String, Object?>.unmodifiable({
          ...originals[(row.sourceKind, row.id)]!,
          'date': row.date.toString(),
          'originalAmount': row.originalAmount.toInt(),
          'funding': Map<String, Object?>.unmodifiable(
            _funding(originals[(row.sourceKind, row.id)]!),
          ),
          'amount': row.amount.toInt(),
        }),
    ], statement);
  }
}
