import 'package:madar_domain/madar_domain.dart';

import '../accounts/account_document.dart';

/// Immutable presentation row; payments reduce liabilities, invoices increase them.
final class SupplierLedgerRow {
  const SupplierLedgerRow({
    required this.id,
    required this.type,
    required this.date,
    required this.createdAt,
    required this.amount,
    required this.before,
    required this.balance,
  });
  final String id, type, date, createdAt;
  final BigInt amount, before, balance;
}

/// Read-only schema11 mapping. No journal policy, posting or storage mutation.
/// [compareText] must reproduce the selected reference localeCompare profile;
/// lexical comparison is deliberately not an implicit fallback.
final class SupplierLedgerQueries {
  SupplierLedgerQueries(AccountDocument document, {required this.compareText})
    : _data = document.toJson();
  final Map<String, Object?> _data;
  final int Function(String, String) compareText;
  static final _safe = BigInt.from(9007199254740991);
  static final _money = BigInt.from(1000000000000);
  static final _policy = CommercePolicy(
    quantityScale: 3,
    maximumQuantityUnits: BigInt.from(1000000000000),
    maximumMoney: _money,
    maximumSafeInteger: _safe,
    rounding: DecimalRounding.halfTowardPositiveInfinity,
  );
  List<Map<String, Object?>> _rows(String key) =>
      (_data[key]! as List).cast<Map<String, Object?>>();
  BigInt _n(Object? value) => BigInt.from(value! as int);
  BigInt _sum(Iterable<BigInt> values) => ExactMath.binary64IntegerSum(values);
  BigInt _opening(String id) {
    for (final row in _rows('suppliers')) {
      if (row['id'] == id) return _n(row['openingBalance']);
    }
    return BigInt.zero;
  }

  BigInt _quantity(Object? value) => ExactDecimal.parse(
    '${value ?? 0}',
    scale: 3,
    maxAbsUnits: BigInt.from(1000000000000),
    signed: false,
    positive: false,
  ).units;
  BigInt invoiceTotal(Map<String, Object?> invoice) =>
      CommerceCalculations.invoiceTotal(
        (invoice['lines']! as List).cast<Map<String, Object?>>().map((line) {
          if (line.containsKey('quantityCartons') ||
              line.containsKey('quantityPieces')) {
            return CommerceCalculations.independentUnitLineTotal([
              QuantityPrice(
                quantityUnits: _quantity(line['quantityCartons']),
                price: _n(line['priceCarton'] ?? 0),
              ),
              QuantityPrice(
                quantityUnits: _quantity(line['quantityPieces']),
                price: _n(line['pricePiece'] ?? 0),
              ),
            ], policy: _policy);
          }
          return CommerceCalculations.lineTotal(
            QuantityPrice(
              quantityUnits: _quantity(line['quantity']),
              price: _n(line['price']),
            ),
            policy: _policy,
          );
        }),
        policy: _policy,
      );
  BigInt _allocation(Map<String, Object?> payment, {required bool invoice}) {
    final field = invoice ? 'invoiceAmount' : 'debtAmount';
    if (payment.containsKey(field)) return _n(payment[field]);
    final hasInvoice =
        payment['invoiceId'] != null && payment['invoiceId'] != '';
    return hasInvoice == invoice ? _n(payment['amount']) : BigInt.zero;
  }

  BigInt invoicePaid(String invoiceId) => _sum(
    _rows('payments')
        .where((p) => p['invoiceId'] == invoiceId)
        .map((p) => _allocation(p, invoice: true)),
  );
  BigInt invoiceDue(String invoiceId) {
    for (final invoice in _rows('invoices')) {
      if (invoice['id'] == invoiceId) {
        return _sum([invoiceTotal(invoice), -invoicePaid(invoiceId)]);
      }
    }
    return BigInt.zero;
  }

  BigInt debtAvailable(
    String supplierId, {
    String date = '9999-12-31',
    String? excludePaymentId,
  }) => _sum([
    _opening(supplierId),
    _sum(
      _rows('debts')
          .where(
            (d) =>
                d['supplierId'] == supplierId &&
                (d['date']! as String).compareTo(date) <= 0,
          )
          .map((d) => _n(d['amount'])),
    ),
    -_sum(
      _rows('payments')
          .where(
            (p) => p['supplierId'] == supplierId && p['id'] != excludePaymentId,
          )
          .map((p) => _allocation(p, invoice: false)),
    ),
  ]);
  BigInt supplierBalance(String supplierId) => _sum([
    _opening(supplierId),
    _sum(
      _rows('debts')
          .where((d) => d['supplierId'] == supplierId)
          .map((d) => _n(d['amount'])),
    ),
    _sum(
      _rows('invoices')
          .where((i) => i['supplierId'] == supplierId)
          .map(invoiceTotal),
    ),
    -_sum(
      _rows('payments')
          .where((p) => p['supplierId'] == supplierId)
          .map((p) => _n(p['amount'])),
    ),
  ]);
  List<Map<String, Object?>> _events(String id) {
    final events = <Map<String, Object?>>[
      for (final i in _rows('invoices'))
        if (i['supplierId'] == id)
          {...i, 'type': 'invoice', 'amountValue': invoiceTotal(i)},
      for (final d in _rows('debts'))
        if (d['supplierId'] == id)
          {...d, 'type': 'debt', 'amountValue': _n(d['amount'])},
      for (final p in _rows('payments'))
        if (p['supplierId'] == id)
          {...p, 'type': 'payment', 'amountValue': _n(p['amount'])},
    ];
    // Final ordinal preserves JavaScript stable-sort ties.
    final indexed = events.indexed.toList();
    indexed.sort((a, b) {
      for (final key in ['date', 'createdAt']) {
        final c = compareText(a.$2[key]! as String, b.$2[key]! as String);
        if (c != 0) return c;
      }
      final payment =
          (a.$2['type'] == 'payment' ? 1 : 0) -
          (b.$2['type'] == 'payment' ? 1 : 0);
      if (payment != 0) return payment;
      final idOrder = compareText(a.$2['id']! as String, b.$2['id']! as String);
      return idOrder != 0 ? idOrder : a.$1.compareTo(b.$1);
    });
    return indexed.map((e) => e.$2).toList();
  }

  List<SupplierLedgerRow> ledger(String supplierId) {
    var balance = _opening(supplierId);
    return List.unmodifiable(
      _events(supplierId).map((e) {
        final before = balance, amount = e['amountValue']! as BigInt;
        balance = _sum([balance, e['type'] == 'payment' ? -amount : amount]);
        return SupplierLedgerRow(
          id: e['id']! as String,
          type: e['type']! as String,
          date: e['date']! as String,
          createdAt: e['createdAt']! as String,
          amount: amount,
          before: before,
          balance: balance,
        );
      }),
    );
  }

  BigInt balanceBefore(
    String supplierId, {
    required String date,
    required String createdAt,
    String? excludeId,
  }) => _sum([
    _opening(supplierId),
    _sum(
      _events(supplierId)
          .where((e) {
            final d = e['date']! as String, t = e['createdAt']! as String;
            return e['id'] != excludeId &&
                (d.compareTo(date) < 0 ||
                    (d == date &&
                        (t.compareTo(createdAt) < 0 ||
                            (t == createdAt && e['type'] != 'payment'))));
          })
          .map(
            (e) => e['type'] == 'payment'
                ? -(e['amountValue']! as BigInt)
                : e['amountValue']! as BigInt,
          ),
    ),
  ]);
}
