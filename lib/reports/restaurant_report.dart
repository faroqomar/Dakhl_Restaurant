import 'package:madar_domain/madar_domain.dart';

import '../accounts/account_document.dart';
import '../accounting/daily_cash_queries.dart';
import '../parties/supplier_ledger.dart';
import 'sales_report.dart';

enum RestaurantReportKind {
  daily,
  invoice,
  sale,
  sales,
  statement,
  cash,
  payment,
}

/// Immutable report content composed from a single validated saved snapshot.
/// Native delivery can retry this content without posting another transaction.
final class RestaurantReport {
  RestaurantReport({
    required this.kind,
    required this.title,
    required this.reference,
    required this.period,
    required this.filename,
    required Map<String, String> identity,
    required Iterable<ReportSection> sections,
  }) : identity = Map.unmodifiable(identity),
       sections = List.unmodifiable(sections);
  final RestaurantReportKind kind;
  final String title, reference, period, filename;
  final Map<String, String> identity;
  final List<ReportSection> sections;
}

final class ReportSection {
  ReportSection(
    this.title,
    Iterable<String> headers,
    Iterable<Iterable<String>> rows,
  ) : headers = List.unmodifiable(headers),
      rows = List.unmodifiable(rows.map((r) => List<String>.unmodifiable(r)));
  final String title;
  final List<String> headers;
  final List<List<String>> rows;
}

/// Restaurant-only document composition. Shared arithmetic and paid-spending
/// queries remain in Madar. The comparator must use the reviewed locale profile;
/// there is deliberately no lexical or ambient-locale substitute.
final class RestaurantReportComposer {
  RestaurantReportComposer(this.document, {required this.compareText})
    : _state = document.toJson(),
      _cash = DailyCashQueries(document),
      _ledger = SupplierLedgerQueries(document, compareText: compareText);
  final AccountDocument document;
  final int Function(String, String) compareText;
  final Map<String, Object?> _state;
  final DailyCashQueries _cash;
  final SupplierLedgerQueries _ledger;
  static final _bound = BigInt.from(1000000000000);
  static final _policy = CommercePolicy(
    quantityScale: 3,
    maximumQuantityUnits: _bound,
    maximumMoney: _bound,
    maximumSafeInteger: BigInt.parse('9007199254740991'),
    rounding: DecimalRounding.halfTowardPositiveInfinity,
  );
  List<Map<String, Object?>> _rows(String key) =>
      (_state[key]! as List).cast<Map<String, Object?>>();
  Map<String, Object?> _find(String key, String id) => _rows(key).firstWhere(
    (r) => r['id'] == id,
    orElse: () => throw const FormatException('Saved report record not found.'),
  );
  String _text(Object? value) => value?.toString() ?? '—';
  BigInt _n(Object? value) => BigInt.from(value! as int);
  BigInt _sum(Iterable<BigInt> values) => ExactMath.binary64IntegerSum(values);
  String _category(Object? id) =>
      document.categories
          .where((c) => c['id'] == id)
          .map((c) => c['name']! as String)
          .firstOrNull ??
      'خانة';
  Map<String, Object?> _funding(Map<String, Object?> row) =>
      row['funding'] as Map<String, Object?>? ??
      {'source': 'daily', 'dailyAmount': row['amount'], 'cashAmount': 0};
  String _fundingText(Map<String, Object?> row) {
    final f = _funding(row);
    return switch (f['source']) {
      'daily' => 'الرصيد اليومي',
      'cash' => 'القاصة',
      _ => 'مشترك · يومي ${f['dailyAmount']} · قاصة ${f['cashAmount']}',
    };
  }

  void _range(String from, String to) {
    for (final date in [from, to]) {
      if (date.isNotEmpty) {
        DateOnly.parse(date, minimumYear: 1000, maximumYear: 9999);
      }
    }
    if (from.isNotEmpty && to.isNotEmpty && from.compareTo(to) > 0) {
      throw const FormatException('Reversed report period.');
    }
  }

  bool _within(Map<String, Object?> row, String from, String to) {
    final date = row['date']! as String;
    return (from.isEmpty || date.compareTo(from) >= 0) &&
        (to.isEmpty || date.compareTo(to) <= 0);
  }

  List<Map<String, Object?>> _sorted(
    Iterable<Map<String, Object?>> rows,
    List<String> keys,
  ) {
    final indexed = rows.indexed.toList();
    indexed.sort((a, b) {
      for (final key in keys) {
        final result = compareText(a.$2[key]! as String, b.$2[key]! as String);
        if (result != 0) return result;
      }
      return a.$1.compareTo(b.$1);
    });
    return indexed.map((r) => r.$2).toList();
  }

  String _safe(String value) => value
      .replaceAll(RegExp(r'[\x00-\x1f\x7f<>:"/\\|?*]'), '-')
      .split('')
      .take(90)
      .join();
  RestaurantReport _report(
    RestaurantReportKind kind,
    String title,
    String reference,
    String period,
    List<ReportSection> sections,
  ) => RestaurantReport(
    kind: kind,
    title: title,
    reference: reference,
    period: period,
    filename: 'Dakhl-${kind.name}-${_safe(reference)}.pdf',
    identity: document.preferences.restaurant,
    sections: sections,
  );
  ReportSection _facts(Iterable<(String, Object?)> rows) => ReportSection('', [
    'البيان',
    'القيمة',
  ], rows.map((r) => [r.$1, _text(r.$2)]));
  BigInt _line(
    Map<String, Object?> row, {
    String quantity = 'quantity',
    String price = 'price',
  }) => CommerceCalculations.lineTotal(
    QuantityPrice(
      quantityUnits: ExactDecimal.parse(
        '${row[quantity] ?? 0}',
        scale: 3,
        maxAbsUnits: _bound,
        signed: false,
        positive: false,
      ).units,
      price: _n(row[price] ?? 0),
    ),
    policy: _policy,
  );
  BigInt _saleSubtotal(Map<String, Object?> sale) =>
      _sum((sale['lines']! as List).cast<Map<String, Object?>>().map(_line));
  BigInt _saleTotal(Map<String, Object?> sale) =>
      CommerceCalculations.saleQuote(
        (sale['lines']! as List).cast<Map<String, Object?>>().map(_line),
        discount: _n(sale['discount']),
        policy: _policy,
      ).net;
  BigInt _invoiceLine(Map<String, Object?> line) =>
      line.containsKey('quantityCartons')
      ? CommerceCalculations.independentUnitLineTotal([
          QuantityPrice(
            quantityUnits: ExactDecimal.parse(
              '${line['quantityCartons']}',
              scale: 3,
              maxAbsUnits: _bound,
              signed: false,
              positive: false,
            ).units,
            price: _n(line['priceCarton']),
          ),
          QuantityPrice(
            quantityUnits: ExactDecimal.parse(
              '${line['quantityPieces']}',
              scale: 3,
              maxAbsUnits: _bound,
              signed: false,
              positive: false,
            ).units,
            price: _n(line['pricePiece']),
          ),
        ], policy: _policy)
      : _line(line);

  RestaurantReport daily(String date) {
    _range(date, date);
    if (!document.days.containsKey(date) &&
        !_rows('payments').any((p) => p['date'] == date)) {
      throw const FormatException('No saved daily accounting record.');
    }
    final day = _cash.day(date),
        raw = document.days[date] as Map<String, Object?>? ?? {};
    final expenseRows = _cash.expenses(date);
    final movements = _sorted(
      _cash.cashMovements.where((m) => m['date'] == date),
      ['createdAt', 'id'],
    );
    ReportSection expenses(String source, String title) {
      final field = source == 'daily' ? 'dailyAmount' : 'cashAmount';
      final selected = expenseRows
          .where((e) => _n(_funding(e)[field]) > BigInt.zero)
          .toList();
      return ReportSection(
        title,
        ['الخانة', 'المبلغ · د.ع', 'مصدر الدفع', 'الملاحظات'],
        [
          for (final e in selected)
            [
              _category(e['categoryId']),
              _text(_funding(e)[field]),
              _fundingText(e),
              _text(e['note']),
            ],
          [
            'المجموع',
            _text(_sum(selected.map((e) => _n(_funding(e)[field])))),
            '',
            '',
          ],
        ],
      );
    }

    final closing = _sum(
      _cash.cashMovements
          .where((m) => (m['date']! as String).compareTo(date) <= 0)
          .map(
            (m) =>
                m['type'] == 'withdrawal' ? -_n(m['amount']) : _n(m['amount']),
          ),
    );
    return _report(
      RestaurantReportKind.daily,
      'فاتورة المصاريف اليومية',
      date,
      date,
      [
        _facts([
          ('مجموع المصاريف', day.total),
          ('الرصيد الكلي', day.recordedBalance ?? 'غير مسجّل'),
          ('الرصيد المتبقي من اليومي', day.remaining ?? 'غير مسجّل'),
          ('من اليومي', day.dailySpent),
          ('المودع من اليومي بالقاصة', day.transferred),
          ('الدجاج المصروف', raw['chickenUsed'] ?? 0),
          ('الدجاج المتبقي', raw['chickenLeft'] ?? 0),
        ]),
        expenses('daily', 'مصاريف الرصيد اليومي'),
        expenses('cash', 'مصاريف القاصة'),
        ReportSection(
          'حركات القاصة لهذا اليوم',
          ['الحركة', 'المبلغ · د.ع', 'التفاصيل'],
          [
            for (final m in movements)
              [
                m['type'] == 'deposit' ? 'إيداع' : 'سحب',
                _text(m['amount']),
                _text(m['note']),
              ],
          ],
        ),
        _facts([('القاصة بنهاية اليوم', closing)]),
      ],
    );
  }

  RestaurantReport invoice(String id) {
    final invoice = _find('invoices', id),
        supplier = _find('suppliers', invoice['supplierId']! as String);
    final payments = _sorted(
      _rows('payments').where((p) => p['invoiceId'] == id),
      ['date', 'createdAt'],
    );
    return _report(
      RestaurantReportKind.invoice,
      'قائمة ${invoice['number']}',
      _text(invoice['number']),
      _text(invoice['date']),
      [
        _facts([
          ('المورد', supplier['name']),
          ('الهاتف', supplier['phone']),
          ('قيمة القائمة', _ledger.invoiceTotal(invoice)),
          ('المسدّد من القائمة', _ledger.invoicePaid(id)),
          ('المتبقي من القائمة', _ledger.invoiceDue(id)),
        ]),
        ReportSection(
          'مواد القائمة',
          [
            'المادة',
            'الوحدة',
            'الكمية · كارتون / قطعة',
            'السعر · كارتون / قطعة',
            'الإجمالي · د.ع',
          ],
          [
            for (final line
                in (invoice['lines']! as List).cast<Map<String, Object?>>())
              [
                _text(line['name']),
                _text(line['unit']),
                line.containsKey('quantityCartons')
                    ? '${line['quantityCartons']} / ${line['quantityPieces']}'
                    : _text(line['quantity']),
                line.containsKey('quantityCartons')
                    ? '${line['priceCarton']} / ${line['pricePiece']}'
                    : _text(line['price']),
                _text(_invoiceLine(line)),
              ],
          ],
        ),
        ReportSection(
          'تسديدات هذه القائمة',
          [
            'التاريخ',
            'المدفوع · د.ع',
            'للقائمة',
            'للديون',
            'المصدر / الملاحظات',
          ],
          [
            for (final p in payments)
              [
                _text(p['date']),
                _text(p['amount']),
                _text(p['invoiceAmount'] ?? p['amount']),
                _text(p['debtAmount'] ?? 0),
                '${_fundingText(p)} · ${p['note']}',
              ],
          ],
        ),
        _facts([
          ('ملاحظات القائمة', invoice['note']),
          (
            'الحساب قبل هذه القائمة',
            _ledger.balanceBefore(
              supplier['id']! as String,
              date: invoice['date']! as String,
              createdAt: invoice['createdAt']! as String,
              excludeId: id,
            ),
          ),
          (
            'الديون الباقية وقت التصدير',
            _ledger.debtAvailable(supplier['id']! as String),
          ),
          (
            'إجمالي الحساب عليك وقت التصدير',
            _ledger.supplierBalance(supplier['id']! as String),
          ),
        ]),
      ],
    );
  }

  RestaurantReport sale(String id) {
    final sale = _find('sales', id), total = _saleTotal(_find('sales', id));
    final refunds = _rows('saleReturns')
        .where((r) => r['saleId'] == id)
        .toList();
    return _report(
      RestaurantReportKind.sale,
      'فاتورة بيع ${sale['number']}',
      _text(sale['number']),
      _text(sale['date']),
      [
        _facts([
          ('نوع الطلب', sale['orderType']),
          ('الحالة', sale['status'] == 'void' ? 'ملغاة' : 'مكتملة'),
          if (sale['status'] == 'void') ('سبب الإلغاء', sale['voidReason']),
          ('ملاحظة', sale['note']),
        ]),
        ReportSection(
          'أصناف البيع',
          ['الصنف', 'الوحدة', 'الكمية', 'سعر البيع · د.ع', 'المجموع · د.ع'],
          [
            for (final line
                in (sale['lines']! as List).cast<Map<String, Object?>>())
              [
                _text(line['name']),
                _text(line['unit']),
                _text(line['quantity']),
                _text(line['price']),
                _text(_line(line)),
              ],
          ],
        ),
        _facts([
          ('المجموع قبل الخصم', _saleSubtotal(sale)),
          ('الخصم', sale['discount']),
          ('إجمالي البيع', total),
          ('النقد المستلم', sale['paid']),
          ('الباقي للزبون', _sum([_n(sale['paid']), -total])),
        ]),
        ReportSection(
          'المرتجعات المسجلة',
          ['التاريخ', 'السبب', 'المبلغ المرتجع · د.ع'],
          [
            for (final r in refunds)
              [_text(r['date']), _text(r['reason']), _text(r['amount'])],
          ],
        ),
        _facts([
          (
            'المتبقي بعد المرتجعات',
            _sum([total, -_sum(refunds.map((r) => _n(r['amount'])))]),
          ),
        ]),
      ],
    );
  }

  RestaurantReport sales({
    SalesHistoryFilter filter = const SalesHistoryFilter(),
  }) {
    final result = SalesReport.build(
      document,
      filter: filter,
      compareText: compareText,
    );
    final selectedIds = result.sales.map((s) => s.snapshot['id']).toSet();
    final rows = _sorted(
      _rows('sales').where((s) => selectedIds.contains(s['id'])),
      ['date', 'createdAt'],
    );
    return _report(
      RestaurantReportKind.sales,
      'ملخص المبيعات',
      '${filter.from}-${filter.to}',
      '${filter.from} — ${filter.to}',
      [
        _facts([
          ('الحالة', filter.status),
          ('نوع الطلب', filter.orderType),
          ('البحث', filter.query),
          ('المبيعات بعد الخصم', result.completedTotal),
          ('مرتجعات الفترة', result.refunded),
          ('صافي التحصيل، ليس صافي الربح', result.netMovement),
        ]),
        ReportSection(
          'المبيعات',
          [
            'الفاتورة',
            'التاريخ / الوقت',
            'نوع الطلب',
            'الحالة',
            'الإجمالي · د.ع',
          ],
          [
            for (final s in rows)
              [
                _text(s['number']),
                '${s['date']} · ${s['createdAt']}',
                _text(s['orderType']),
                s['status'] == 'void' ? 'ملغاة' : 'مكتملة',
                _text(_saleTotal(s)),
              ],
          ],
        ),
        ReportSection(
          'مرتجعات الفترة',
          ['الفاتورة', 'التاريخ', 'السبب', 'المبلغ · د.ع'],
          [
            for (final r in result.returns)
              [
                _text(_find('sales', r['saleId']! as String)['number']),
                _text(r['date']),
                _text(r['reason']),
                _text(r['amount']),
              ],
          ],
        ),
      ],
    );
  }

  RestaurantReport statement({
    String from = '',
    String to = '',
    String categoryId = '',
    SpendingSource source = SpendingSource.all,
  }) {
    final result = _cash.statement(
      from: from,
      to: to,
      categoryId: categoryId,
      source: source,
    );
    return _report(
      RestaurantReportKind.statement,
      'كشف المصروفات',
      '$from-$to',
      '$from — $to',
      [
        _facts([
          ('الخانة', categoryId.isEmpty ? 'الكل' : _category(categoryId)),
          ('المصدر', source.name),
          ('حصة اليومي', result.dailyShare),
          ('حصة القاصة', result.cashShare),
          ('المجموع', result.total),
        ]),
        ReportSection(
          'المصروفات المدفوعة',
          ['التاريخ', 'الخانة', 'المبلغ · د.ع', 'المصدر الأصلي', 'التفاصيل'],
          [
            for (final e in result.rows)
              [
                _text(e['date']),
                _category(e['categoryId']),
                _text(e['amount']),
                _fundingText(e),
                _text(e['note']),
              ],
          ],
        ),
      ],
    );
  }

  RestaurantReport cash({String from = '', String to = '', String kind = ''}) {
    _range(from, to);
    if (![
      '',
      'cash',
      'transfer',
      'expense',
      'supplier-payment',
    ].contains(kind)) {
      throw const FormatException('Invalid cash movement filter.');
    }
    var balance = BigInt.zero, opening = BigInt.zero, closing = BigInt.zero;
    final rows = <List<String>>[];
    for (final m in _sorted(_cash.cashMovements, ['date', 'createdAt', 'id'])) {
      balance = _sum([
        balance,
        m['type'] == 'withdrawal' ? -_n(m['amount']) : _n(m['amount']),
      ]);
      final date = m['date']! as String;
      if (from.isNotEmpty && date.compareTo(from) < 0) opening = balance;
      if (to.isEmpty || date.compareTo(to) <= 0) closing = balance;
      if (_within(m, from, to) && (kind.isEmpty || m['kind'] == kind)) {
        rows.add([
          date,
          m['type'] == 'deposit' ? 'إيداع' : 'سحب',
          _text(m['amount']),
          '$balance',
          m['kind'] == 'transfer' ? 'تحويل من اليومي' : _text(m['note']),
        ]);
      }
    }
    return _report(
      RestaurantReportKind.cash,
      'كشف القاصة',
      '$from-$to',
      '$from — $to',
      [
        _facts([
          ('افتتاح الفترة', opening),
          ('إغلاق الفترة', closing),
          ('نوع الحركة', kind),
          ('ملاحظة', 'الرصيد يشمل كل المصادر حتى لو كانت الحركات مصفاة.'),
        ]),
        ReportSection('حركات القاصة', [
          'التاريخ',
          'الحركة',
          'المبلغ · د.ع',
          'الرصيد بعدها',
          'التفاصيل',
        ], rows),
      ],
    );
  }

  RestaurantReport payment(String id) {
    final p = _find('payments', id),
        supplier = _find('suppliers', p['supplierId']! as String);
    final invoiceId = p['invoiceId'] as String?;
    final hasInvoice = invoiceId != null && invoiceId.isNotEmpty;
    final ledger = _ledger
        .ledger(p['supplierId']! as String)
        .firstWhere((e) => e.type == 'payment' && e.id == id);
    return _report(
      RestaurantReportKind.payment,
      'وصل تسديد',
      id,
      _text(p['date']),
      [
        _facts([
          ('المورد', supplier['name']),
          (
            'المرجع',
            hasInvoice
                ? 'قائمة ${_find('invoices', invoiceId)['number']}'
                : 'تسديد ديون',
          ),
          ('المبلغ المسدد', p['amount']),
          ('للقائمة', p['invoiceAmount'] ?? (hasInvoice ? p['amount'] : 0)),
          ('للديون', p['debtAmount'] ?? (hasInvoice ? 0 : p['amount'])),
          ('الرصيد بعد هذه الدفعة', ledger.balance),
          ('مصدر الدفع', _fundingText(p)),
          ('ملاحظة', p['note']),
        ]),
      ],
    );
  }
}
