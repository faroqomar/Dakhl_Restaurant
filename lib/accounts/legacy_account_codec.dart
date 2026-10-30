import 'dart:convert';
import 'dart:typed_data';

import 'package:madar_domain/madar_domain.dart';

import 'account_document.dart';

part 'legacy_v8_timestamp.dart';

final class AccountCodecException implements Exception {
  const AccountCodecException(this.code);
  final String code;
  @override
  String toString() => 'AccountCodecException($code)';
}

/// Consumer-owned schema1–11 compatibility, backed by Madar exact validation.
/// Never opens a file, mutates a source map, or writes a persistence snapshot.
final class LegacyAccountCodec {
  const LegacyAccountCodec();
  static const maxPayloadBytes = 20 * 1024 * 1024;
  static const defaultShortcuts = [
    'sales',
    'inventory',
    'sale-history',
    'expenses',
    'cash',
    'settings',
  ];
  static const _core = {
    'samoon': 'الصمون',
    'bread': 'الخبز',
    'falafel': 'الفلافل',
    'market': 'الأسواق',
  };
  static final _safe = BigInt.from(9007199254740991);
  static final _moneyLimit = BigInt.from(1000000000000);
  static const _destinations = [
    'sales',
    'sale-history',
    'inventory',
    'expenses',
    'statement',
    'suppliers',
    'invoices',
    'materials',
    'payments',
    'cash',
    'categories',
    'settings',
  ];
  static const _photos = [
    'beef-kebab',
    'chicken-kebab',
    'grilled-chicken',
    'dulaimiya',
    'red-rice',
    'appetizers',
    'water',
    'cola',
  ];

  AccountDocument decodeBytes(List<int> bytes) {
    if (bytes.length > maxPayloadBytes) {
      throw const AccountCodecException('payload_too_large');
    }
    try {
      final raw = jsonDecode(utf8.decode(bytes, allowMalformed: false));
      return decodeJson(_map(raw));
    } on AccountCodecException {
      rethrow;
    } catch (_) {
      throw const AccountCodecException('invalid_payload');
    }
  }

  AccountDocument decodeJson(Map<String, Object?> raw) {
    try {
      final version = raw['version'];
      if (version is num &&
          version.isFinite &&
          version == version.truncate() &&
          version > 11) {
        throw const AccountCodecException('unsupported_version');
      }
      _require(
        version is num &&
            version >= 1 &&
            version <= 11 &&
            version == version.truncate(),
      );
      final canonical = _validate(raw, (version as num).toInt());
      // The normalized-output boundary is independent from the incoming bytes.
      if (utf8
              .encode(const JsonEncoder.withIndent('  ').convert(canonical))
              .length >
          maxPayloadBytes) {
        throw const AccountCodecException('payload_too_large');
      }
      return AccountDocument.canonical(
        canonical,
        sourceVersion: version.toInt(),
      );
    } on AccountCodecException {
      rethrow;
    } catch (_) {
      throw const AccountCodecException('invalid_payload');
    }
  }

  Uint8List encode(AccountDocument document) {
    // Revalidate even externally constructed canonical documents.
    final validated = decodeJson(document.toJson());
    final bytes = utf8.encode(
      const JsonEncoder.withIndent('  ').convert(validated.toJson()),
    );
    if (bytes.length > maxPayloadBytes) {
      throw const AccountCodecException('payload_too_large');
    }
    return Uint8List.fromList(bytes);
  }

  AccountDocument empty() => decodeJson({
    'version': 11,
    'categories': [
      for (final e in _core.entries)
        {'id': e.key, 'name': e.value, 'type': 'primary'},
    ],
    'days': <String, Object?>{},
    'transactions': <Object?>[],
    'transfers': <Object?>[],
    'products': <Object?>[],
    'stockEntries': <Object?>[],
    'sales': <Object?>[],
    'saleReturns': <Object?>[],
    'suppliers': <Object?>[],
    'materials': <Object?>[],
    'invoices': <Object?>[],
    'payments': <Object?>[],
    'debts': <Object?>[],
    'workers': <Object?>[],
    'savingsEntries': <Object?>[],
    'preferences': {
      'shortcuts': defaultShortcuts,
      'orderTypes': ['صالة', 'سفري', 'توصيل'],
      'restaurant': {'name': '', 'contact': '', 'footer': ''},
    },
  });

  static void _require(bool condition) {
    if (!condition) throw const AccountCodecException('invalid_payload');
  }

  static Map<String, Object?> _map(Object? value) {
    _require(value is Map<String, Object?>);
    return value as Map<String, Object?>;
  }

  static List<Object?> _list(
    Object? value,
    int limit, {
    bool optional = false,
  }) {
    if (optional && value == null) return [];
    _require(value is List && value.length <= limit);
    return value as List<Object?>;
  }

  static String _string(Object? value, [int max = 2000]) {
    _require(value is String && value.length <= max);
    return value as String;
  }

  static String _id(Object? value) {
    final s = _string(value, 80);
    Identifier.parse(s, maxLength: 80, allowEmpty: false);
    _require(RegExp(r'^[a-zA-Z0-9_-]{1,80}$').hasMatch(s));
    return s;
  }

  static int _money(Object? value, {bool signed = false}) => ExactIntegerPolicy(
    maxAbs: _moneyLimit,
    signed: signed,
    positive: false,
    maxSafeInteger: _safe,
  ).validate(value).toInt();
  static int _sum(Iterable<int> values, {BigInt? limit}) =>
      ExactMath.checkedSum(
        values.map(BigInt.from),
        maxAbs: limit ?? _safe,
        maxSafeInteger: _safe,
      ).toInt();
  static bool _date(Object? value) {
    if (value is! String) return false;
    try {
      DateOnly.parse(value, minimumYear: 1000, maximumYear: 9999);
      return true;
    } catch (_) {
      return false;
    }
  }

  static String _dateValue(Object? value) {
    _require(_date(value));
    return value as String;
  }

  static String _stamp(Object? value) {
    final s = _string(value, 40);
    _require(_legacyTimestamp(s));
    return s;
  }

  // Source-specific compatibility only; the parser never rewrites history.
  static bool _legacyTimestamp(String value) =>
      _FrozenV8Timestamp.accepts(value);

  static String _jsString(Object? value) {
    if (value is num && value.isFinite && value == value.truncate()) {
      return value.toInt().toString();
    }
    return '$value';
  }

  static int _units(Object? value, {bool positive = false}) =>
      ExactDecimal.parse(
        _jsString(value),
        scale: 3,
        maxAbsUnits: BigInt.from(1000000000000),
        signed: false,
        positive: positive,
        normalizeDigits: true,
        allowGrouping: true,
        allowArabicDecimal: true,
      ).units.toInt();
  static num _quantity(Object? value, {bool positive = false}) {
    final u = _units(value, positive: positive);
    return u % 1000 == 0 ? u ~/ 1000 : u / 1000;
  }

  static int _lineTotal(Map<String, Object?> line) {
    if (line.containsKey('quantityCartons') ||
        line.containsKey('quantityPieces')) {
      final a = ExactMath.roundProduct(
        BigInt.from(_units(line['quantityCartons'] ?? 0)),
        BigInt.from(_money(line['priceCarton'] ?? 0)),
        scale: 3,
        maxAbsResult: _safe,
        maxSafeInteger: _safe,
        checkIntermediate: false,
        rounding: DecimalRounding.halfTowardPositiveInfinity,
      ).toInt();
      final b = ExactMath.roundProduct(
        BigInt.from(_units(line['quantityPieces'] ?? 0)),
        BigInt.from(_money(line['pricePiece'] ?? 0)),
        scale: 3,
        maxAbsResult: _safe,
        maxSafeInteger: _safe,
        checkIntermediate: false,
        rounding: DecimalRounding.halfTowardPositiveInfinity,
      ).toInt();
      return _money(_sum([a, b]));
    }
    return ExactMath.roundProduct(
      BigInt.from(_units(line['quantity'], positive: true)),
      BigInt.from(_money(line['price'])),
      scale: 3,
      maxAbsResult: _moneyLimit,
      maxSafeInteger: _safe,
      checkIntermediate: true,
      rounding: DecimalRounding.halfTowardPositiveInfinity,
    ).toInt();
  }

  static int _invoiceTotal(Map<String, Object?> invoice) => _money(
    _sum(
      (invoice['lines'] as List).cast<Map<String, Object?>>().map(_lineTotal),
    ),
  );
  static int _saleTotal(Map<String, Object?> sale) {
    final sub = _invoiceTotal(sale), discount = _money(sale['discount']);
    _require(discount <= sub);
    return sub - discount;
  }

  static Map<String, Object?> _allocation(int amount, Object? raw) {
    final f = _map(raw), source = f['source'];
    _require(['daily', 'cash', 'shared'].contains(source));
    final daily = _money(f['dailyAmount']), cash = _money(f['cashAmount']);
    ExactMath.validateAllocation(
      BigInt.from(amount),
      [BigInt.from(daily), BigInt.from(cash)],
      nonnegative: true,
      maxAbs: _moneyLimit,
      maxSafeInteger: _safe,
    );
    _require(source != 'daily' || cash == 0);
    _require(source != 'cash' || daily == 0);
    return {'source': source, 'dailyAmount': daily, 'cashAmount': cash};
  }

  static void _unique(Set<String> used, String value) {
    _require(used.add(value));
  }

  Map<String, Object?> _validate(Map<String, Object?> raw, int version) {
    final categories = <Map<String, Object?>>[],
        ids = <String>{},
        names = <String>{};
    final rawCategories = _list(raw['categories'], 500);
    _require(rawCategories.length >= 4);
    for (final item in rawCategories) {
      final c = _map(item),
          id = _id(c['id']),
          name = _string(c['name'], 80).trim();
      final type = c.containsKey('type')
          ? c['type']
          : (_core.containsKey(id) ? 'primary' : 'additional');
      _require(['primary', 'additional'].contains(type) && name.isNotEmpty);
      _unique(ids, id);
      _unique(names, name);
      categories.add({
        'id': id,
        'name': name,
        'type': type,
        if (c['archived'] == true && !_core.containsKey(id)) 'archived': true,
      });
    }
    _require(
      _core.entries.every(
        (c) => categories.any((x) => x['id'] == c.key && x['name'] == c.value),
      ),
    );
    final rawDays = _map(raw['days']);
    _require(rawDays.length <= 50000);
    final days = <String, Object?>{}, expenseIds = <String>{};
    for (final entry in rawDays.entries) {
      _require(_date(entry.key));
      final d = _map(entry.value), expenses = <Map<String, Object?>>[];
      for (final item in _list(d['expenses'], 10000)) {
        final e = _map(item), id = _id(e['id']);
        _unique(expenseIds, id);
        _require(ids.contains(e['categoryId']));
        final amount = _money(e['amount']);
        expenses.add({
          'id': id,
          'categoryId': e['categoryId'],
          'amount': amount,
          'note': _string(e['note']),
          'funding': _allocation(
            amount,
            e['funding'] ??
                {'source': 'daily', 'dailyAmount': amount, 'cashAmount': 0},
          ),
          if (e.containsKey('createdAt')) 'createdAt': _stamp(e['createdAt']),
        });
      }
      _sum(expenses.map((e) => e['amount'] as int));
      Map<String, Object?>? snapshot;
      if (d['remaining'] != null) {
        final r = _map(d['remaining']);
        final spent = _safeUnsigned(r['dailySpent']),
            transferred = _safeUnsigned(r['transferred']);
        snapshot = {
          'amount': _money(r['amount']),
          'dailySpent': spent,
          'transferred': transferred,
          if (r.containsKey('salesTotal'))
            'salesTotal': _money(r['salesTotal'], signed: true),
        };
      }
      final corrections = <Map<String, Object?>>[];
      if (d['corrections'] is String) {
        _require((d['corrections'] as String).isEmpty);
      }
      if (d['corrections'] is List) {
        for (final item in _list(d['corrections'], maxPayloadBytes)) {
          final c = _map(item);
          _require(['balance', 'total'].contains(c['field']));
          final reason = _string(c['reason'], 500);
          _require(reason.trim().isNotEmpty);
          corrections.add({
            'field': c['field'],
            'date': _dateValue(c['date']),
            'before': c['before'] == null
                ? null
                : _money(c['before'], signed: true),
            'after': c['after'] == null
                ? null
                : _money(c['after'], signed: true),
            'reason': reason,
            'createdAt': _stamp(c['createdAt']),
          });
        }
      }
      days[entry.key] = {
        'expenses': expenses,
        'chickenUsed': _money(d['chickenUsed']),
        'chickenLeft': _money(d['chickenLeft']),
        'balance': d['balance'] == null && d.containsKey('balance')
            ? null
            : _money(d['balance'], signed: true),
        'totalOverride':
            d['totalOverride'] == null && d.containsKey('totalOverride')
            ? null
            : _money(d['totalOverride']),
        'remaining': snapshot,
        if (corrections.isNotEmpty) 'corrections': corrections,
      };
    }
    final transactions = <Map<String, Object?>>[], txIds = <String>{};
    for (final item in _list(raw['transactions'], 100000)) {
      final t = _map(item), id = _id(t['id']);
      _unique(txIds, id);
      final amount = _money(t['amount']);
      _require(amount > 0 && ['deposit', 'withdrawal'].contains(t['type']));
      transactions.add({
        'id': id,
        'date': _dateValue(t['date']),
        'type': t['type'],
        'amount': amount,
        'note': _string(t['note']),
        'createdAt': _stamp(t['createdAt']),
      });
    }
    final transfers = <Map<String, Object?>>[], transferIds = <String>{};
    for (final item in _list(raw['transfers'], 100000, optional: true)) {
      final t = _map(item), id = _id(t['id']), date = _dateValue(t['date']);
      _unique(transferIds, id);
      _require(days[date] != null && _map(days[date])['remaining'] != null);
      final amount = _money(t['amount']);
      _require(amount > 0);
      transfers.add({
        'id': id,
        'date': date,
        'amount': amount,
        'createdAt': _stamp(t['createdAt']),
      });
    }
    final materials = _materials(raw, version);
    final commerce = _commerce(raw);
    final supplier = _suppliers(
      raw,
      ids,
      materials.map((m) => m['id'] as String).toSet(),
    );
    final savings = _savings(raw);
    final clean = <String, Object?>{
      'version': 11,
      ...commerce,
      'categories': categories,
      'days': days,
      'transactions': transactions,
      'transfers': transfers,
      ...supplier,
      'materials': materials,
      ...savings,
    };
    _validateAggregates(clean, version);
    return clean;
  }

  static int _safeUnsigned(Object? value) => ExactIntegerPolicy(
    maxAbs: _safe,
    signed: false,
    positive: false,
    maxSafeInteger: _safe,
  ).validate(value).toInt();

  List<Map<String, Object?>> _materials(Map<String, Object?> raw, int version) {
    Object? input = raw['materials'];
    if (!raw.containsKey('materials') || version < 7) {
      final merged = <String, Map<String, Object?>>{}, used = <String>{};
      var serial = 1;
      for (final s in _list(raw['suppliers'], 5000, optional: true)) {
        for (final m in _list(_map(s)['materials'], 1000, optional: true)) {
          final id = _map(m)['id'];
          if (id is String) used.add(id);
        }
      }
      for (final s in _list(raw['suppliers'], 5000, optional: true)) {
        for (final item in _list(_map(s)['materials'], 1000, optional: true)) {
          final m = _map(item), name = m['name'];
          final key = (name == null ? '' : _jsString(name))
              .trim()
              .toLowerCase();
          if (key.isEmpty || merged.containsKey(key)) continue;
          String id;
          do {
            id = 'catalog-${serial++}';
          } while (used.contains(id));
          used.add(id);
          merged[key] = {
            'id': id,
            'name': name,
            'unit': m['unit'],
            'priceCarton': 0,
            'pricePiece': m['price'],
            'archived': m['archived'] == true,
          };
        }
      }
      input = merged.values.toList();
    }
    final ids = <String>{},
        names = <String>{},
        result = <Map<String, Object?>>[];
    for (final item in _list(input, 5000)) {
      final m = _map(item),
          id = _id(m['id']),
          name = _string(m['name'], 100).trim(),
          unit = _string(m['unit'], 30).trim();
      _require(name.isNotEmpty && unit.isNotEmpty && m['archived'] is bool);
      _unique(ids, id);
      _unique(names, name.toLowerCase());
      result.add({
        'id': id,
        'name': name,
        'unit': unit,
        'priceCarton': _money(m['priceCarton'] ?? 0),
        'pricePiece': _money(m['pricePiece'] ?? m['price'] ?? 0),
        'archived': m['archived'],
      });
    }
    return result;
  }

  Map<String, Object?> _suppliers(
    Map<String, Object?> raw,
    Set<String> categoryIds,
    Set<String> catalogIds,
  ) {
    final suppliers = <Map<String, Object?>>[],
        supplierIds = <String>{},
        supplierNames = <String>{};
    for (final item in _list(raw['suppliers'], 5000, optional: true)) {
      final s = _map(item),
          id = _id(s['id']),
          name = _string(s['name'], 100).trim();
      _require(name.isNotEmpty);
      _unique(supplierIds, id);
      _unique(supplierNames, name.toLowerCase());
      _require(categoryIds.contains(s['categoryId']));
      final materials = <Map<String, Object?>>[],
          matIds = <String>{},
          names = <String>{};
      for (final item in _list(s['materials'], 1000, optional: true)) {
        final m = _map(item),
            id = _id(m['id']),
            name = _string(m['name'], 100).trim(),
            unit = _string(m['unit'], 30).trim();
        _require(name.isNotEmpty && unit.isNotEmpty && m['archived'] is bool);
        _unique(matIds, id);
        _unique(names, name.toLowerCase());
        materials.add({
          'id': id,
          'name': name,
          'unit': unit,
          'price': _money(m['price']),
          'archived': m['archived'],
        });
      }
      suppliers.add({
        'id': id,
        'name': name,
        'phone': _string(s['phone'], 80),
        'note': _string(s['note']),
        'categoryId': s['categoryId'],
        'openingBalance': _money(s['openingBalance']),
        if (s['archived'] == true) 'archived': true,
        'materials': materials,
      });
    }
    final invoices = <Map<String, Object?>>[],
        invoiceIds = <String>{},
        numbers = <String>{};
    for (final item in _list(raw['invoices'], 100000, optional: true)) {
      final i = _map(item),
          id = _id(i['id']),
          number = _string(i['number'], 80).trim(),
          date = _dateValue(i['date']);
      _unique(invoiceIds, id);
      _require(supplierIds.contains(i['supplierId']) && number.isNotEmpty);
      _unique(numbers, '${i['supplierId']}:$number');
      final supplier = suppliers.firstWhere((s) => s['id'] == i['supplierId']);
      final lines = <Map<String, Object?>>[];
      final rawLines = _list(i['lines'], 200);
      _require(rawLines.isNotEmpty);
      for (final item in rawLines) {
        final l = _map(item);
        _require(
          catalogIds.contains(l['materialId']) ||
              (supplier['materials'] as List).any(
                (m) => m['id'] == l['materialId'],
              ),
        );
        final name = _string(l['name'], 100).trim(),
            unit = _string(l['unit'], 30).trim();
        _require(name.isNotEmpty && unit.isNotEmpty);
        final line = <String, Object?>{
          'materialId': l['materialId'],
          'name': name,
          'unit': unit,
        };
        if (l.containsKey('quantityCartons') ||
            l.containsKey('quantityPieces')) {
          final cartons = _quantity(l['quantityCartons'] ?? 0),
              pieces = _quantity(l['quantityPieces'] ?? 0),
              cartonPrice = _money(l['priceCarton'] ?? 0),
              piecePrice = _money(l['pricePiece'] ?? 0);
          _require(cartons + pieces > 0);
          line.addAll({
            'quantityCartons': cartons,
            'quantityPieces': pieces,
            'priceCarton': cartonPrice,
            'pricePiece': piecePrice,
            'quantity': pieces,
            'price': piecePrice,
          });
        } else {
          line.addAll({
            'quantity': _quantity(l['quantity'], positive: true),
            'price': _money(l['price']),
          });
        }
        _lineTotal(line);
        lines.add(line);
      }
      final invoice = <String, Object?>{
        'id': id,
        'supplierId': i['supplierId'],
        'number': number,
        'date': date,
        'lines': lines,
        'note': _string(i['note']),
        'createdAt': _stamp(i['createdAt']),
      };
      _require(_invoiceTotal(invoice) > 0);
      invoices.add(invoice);
    }
    final debts = <Map<String, Object?>>[], debtIds = <String>{};
    for (final item in _list(raw['debts'], 100000, optional: true)) {
      final d = _map(item), id = _id(d['id']), amount = _money(d['amount']);
      _unique(debtIds, id);
      _require(supplierIds.contains(d['supplierId']) && amount > 0);
      debts.add({
        'id': id,
        'supplierId': d['supplierId'],
        'date': _dateValue(d['date']),
        'amount': amount,
        'note': _string(d['note']),
        'createdAt': _stamp(d['createdAt']),
      });
    }
    final payments = <Map<String, Object?>>[], paymentIds = <String>{};
    for (final item in _list(raw['payments'], 100000, optional: true)) {
      final p = _map(item),
          id = _id(p['id']),
          date = _dateValue(p['date']),
          amount = _money(p['amount']);
      _unique(paymentIds, id);
      _require(
        supplierIds.contains(p['supplierId']) &&
            categoryIds.contains(p['categoryId']) &&
            amount > 0,
      );
      final invoiceId = p['invoiceId'];
      _require(p.containsKey('invoiceId'));
      if (invoiceId != null) {
        final matching = invoices
            .where(
              (i) => i['id'] == invoiceId && i['supplierId'] == p['supplierId'],
            )
            .toList();
        _require(
          matching.length == 1 &&
              date.compareTo(matching.single['date'] as String) >= 0,
        );
      }
      final inv = _money(
        p.containsKey('invoiceAmount')
            ? p['invoiceAmount']
            : (invoiceId != null ? amount : 0),
      );
      final debt = _money(
        p.containsKey('debtAmount')
            ? p['debtAmount']
            : (invoiceId != null ? 0 : amount),
      );
      ExactMath.validateAllocation(
        BigInt.from(amount),
        [BigInt.from(inv), BigInt.from(debt)],
        nonnegative: true,
        maxAbs: _moneyLimit,
        maxSafeInteger: _safe,
      );
      _require(invoiceId != null || inv == 0);
      payments.add({
        'id': id,
        'supplierId': p['supplierId'],
        'invoiceId': invoiceId,
        'invoiceAmount': inv,
        'debtAmount': debt,
        'categoryId': p['categoryId'],
        'date': date,
        'amount': amount,
        'funding': _allocation(amount, p['funding']),
        'note': _string(p['note']),
        'createdAt': _stamp(p['createdAt']),
      });
    }
    for (final i in invoices) {
      _require(
        _sum(
              payments
                  .where((p) => p['invoiceId'] == i['id'])
                  .map((p) => p['invoiceAmount'] as int),
            ) <=
            _invoiceTotal(i),
      );
    }
    for (final s in suppliers) {
      final relatedDebts = debts
              .where((d) => d['supplierId'] == s['id'])
              .toList(),
          relatedPayments = payments
              .where((p) => p['supplierId'] == s['id'])
              .toList(),
          relatedInvoices = invoices
              .where((i) => i['supplierId'] == s['id'])
              .toList();
      _require(
        _sum([
              s['openingBalance'] as int,
              ...relatedDebts.map((d) => d['amount'] as int),
              ...relatedPayments.map((p) => -(p['debtAmount'] as int)),
            ]) >=
            0,
      );
      final timeline =
          <Map<String, Object?>>[
            for (final d in relatedDebts) {...d, 'credit': true},
            for (final p in relatedPayments) {...p, 'credit': false},
          ]..sort((a, b) {
            final date = (a['date'] as String).compareTo(b['date'] as String);
            return date != 0
                ? date
                : (a['credit'] == b['credit']
                      ? 0
                      : (a['credit'] == true ? -1 : 1));
          });
      var balance = s['openingBalance'] as int;
      for (final e in timeline) {
        balance = _sum([
          balance,
          e['credit'] == true ? e['amount'] as int : -(e['debtAmount'] as int),
        ]);
        _require(balance >= 0);
      }
      final events =
          <Map<String, Object?>>[
            for (final i in relatedInvoices)
              {...i, 'event': 'invoice', 'amount': _invoiceTotal(i)},
            for (final d in relatedDebts) {...d, 'event': 'debt'},
            for (final p in relatedPayments) {...p, 'event': 'payment'},
          ]..sort((a, b) {
            var c = (a['date'] as String).compareTo(b['date'] as String);
            if (c != 0) return c;
            c = (a['createdAt'] as String).compareTo(b['createdAt'] as String);
            if (c != 0) return c;
            c =
                (a['event'] == 'payment' ? 1 : 0) -
                (b['event'] == 'payment' ? 1 : 0);
            return c != 0
                ? c
                : (a['id'] as String).compareTo(b['id'] as String);
          });
      balance = s['openingBalance'] as int;
      for (final e in events) {
        balance = _sum([
          balance,
          (e['event'] == 'payment' ? -1 : 1) * (e['amount'] as int),
        ]);
      }
    }
    return {
      'suppliers': suppliers,
      'invoices': invoices,
      'payments': payments,
      'debts': debts,
    };
  }

  Map<String, Object?> _commerce(Map<String, Object?> raw) {
    final products = <Map<String, Object?>>[],
        productIds = <String>{},
        names = <String>{},
        codes = <String>{};
    for (final item in _list(raw['products'], 10000, optional: true)) {
      final p = _map(item),
          id = _id(p['id']),
          name = _string(p['name'], 100).trim(),
          code = _string(p['code'], 80).trim(),
          unit = _string(p['unit'], 30).trim();
      _require(
        name.isNotEmpty &&
            unit.isNotEmpty &&
            p['trackStock'] is bool &&
            p['archived'] is bool,
      );
      _unique(productIds, id);
      _unique(names, name.toLowerCase());
      if (code.isNotEmpty) _unique(codes, code.toLowerCase());
      _require(
        !p.containsKey('photo') ||
            p['photo'] == '' ||
            _photos.contains(p['photo']),
      );
      products.add({
        if (p['photo'] != null && p['photo'] != '') 'photo': p['photo'],
        'id': id,
        'name': name,
        'code': code,
        'unit': unit,
        'price': _money(p['price']),
        'group': _string(p['group'], 60).trim(),
        'minStock': _quantity(p['minStock']),
        'trackStock': p['trackStock'],
        'archived': p['archived'],
      });
    }
    final index = {for (final p in products) p['id']: p};
    final stock = <Map<String, Object?>>[], entryIds = <String>{};
    for (final item in _list(raw['stockEntries'], 100000, optional: true)) {
      final e = _map(item), id = _id(e['id']), q = e['quantity'];
      _unique(entryIds, id);
      _require(
        productIds.contains(e['productId']) && q is num && q.isFinite && q != 0,
      );
      _units((q as num).abs());
      _require(
        ['opening', 'restock', 'adjustment'].contains(e['kind']) &&
            (e['kind'] == 'adjustment' || q > 0) &&
            index[e['productId']]!['trackStock'] == true,
      );
      stock.add({
        'id': id,
        'productId': e['productId'],
        'date': _dateValue(e['date']),
        'quantity': q,
        'kind': e['kind'],
        'note': _string(e['note']),
        'createdAt': _stamp(e['createdAt']),
        if (e['reversesId'] != null && e['reversesId'] != '')
          'reversesId': _id(e['reversesId']),
      });
    }
    final reversed = <String>{};
    for (final e in stock.where((e) => e.containsKey('reversesId'))) {
      final found = stock.where((old) => old['id'] == e['reversesId']).toList();
      _require(found.length == 1);
      final old = found.single;
      _require(
        !old.containsKey('reversesId') &&
            old['productId'] == e['productId'] &&
            e['quantity'] == -(old['quantity'] as num) &&
            e['date'] == old['date'] &&
            (e['note'] as String).trim().isNotEmpty,
      );
      _unique(reversed, old['id'] as String);
    }
    final sales = <Map<String, Object?>>[],
        saleIds = <String>{},
        numbers = <String>{};
    for (final item in _list(raw['sales'], 100000, optional: true)) {
      final s = _map(item),
          id = _id(s['id']),
          number = _string(s['number'], 80).trim();
      _unique(saleIds, id);
      _unique(numbers, number);
      _require(
        number.isNotEmpty && ['completed', 'void'].contains(s['status']),
      );
      final lines = <Map<String, Object?>>[], used = <String>{};
      final rawLines = _list(s['lines'], 200);
      _require(rawLines.isNotEmpty);
      for (final item in rawLines) {
        final l = _map(item), product = index[l['productId']];
        _require(
          product != null &&
              l['trackStock'] is bool &&
              l['trackStock'] == product['trackStock'],
        );
        _unique(used, l['productId'] as String);
        final name = _string(l['name'], 100).trim(),
            unit = _string(l['unit'], 30).trim();
        _require(name.isNotEmpty && unit.isNotEmpty);
        final line = <String, Object?>{
          'productId': l['productId'],
          'name': name,
          'unit': unit,
          'quantity': _quantity(l['quantity'], positive: true),
          'price': _money(l['price']),
          'trackStock': l['trackStock'],
        };
        _lineTotal(line);
        lines.add(line);
      }
      final sale = <String, Object?>{
        'id': id,
        'number': number,
        'date': _dateValue(s['date']),
        'status': s['status'],
        'lines': lines,
        'discount': _money(s['discount']),
        'paid': _money(s['paid']),
        'note': _string(s['note']),
        'createdAt': _stamp(s['createdAt']),
      };
      if (s.containsKey('orderType')) {
        final type = _string(s['orderType'], 60).trim();
        _require(type.isNotEmpty);
        sale['orderType'] = type;
      }
      _require((sale['paid'] as int) >= _saleTotal(sale));
      if (s['status'] == 'void') {
        final reason = _string(s['voidReason'], 500).trim();
        _require(reason.isNotEmpty);
        sale.addAll({'voidReason': reason, 'voidedAt': _stamp(s['voidedAt'])});
      }
      sales.add(sale);
    }
    final returns = _returns(raw, sales);
    final events = <String, Map<String, int>>{};
    void movement(Object? id, Object? date, int units) {
      final dates = events.putIfAbsent(id as String, () => {});
      dates[date as String] = _sum([dates[date] ?? 0, units]);
    }

    for (final e in stock) {
      movement(e['productId'], e['date'], _signedUnits(e['quantity'] as num));
    }
    for (final s in sales.where((s) => s['status'] == 'completed')) {
      for (final l in (s['lines'] as List).cast<Map<String, Object?>>().where(
        (l) => l['trackStock'] == true,
      )) {
        movement(l['productId'], s['date'], -_units(l['quantity']));
      }
    }
    for (final r in returns) {
      for (final l in (r['lines'] as List).cast<Map<String, Object?>>().where(
        (l) => l['restock'] == true,
      )) {
        movement(l['productId'], r['date'], _units(l['quantity']));
      }
    }
    for (final dates in events.values) {
      var available = 0;
      for (final date in dates.keys.toList()..sort()) {
        available = _sum([available, dates[date]!]);
        _require(available >= 0 && available <= 1000000000000);
      }
    }
    for (final date in {
      ...sales.map((s) => s['date'] as String),
      ...returns.map((r) => r['date'] as String),
    }) {
      _salesTotal(sales, returns, date);
    }
    final pref = raw['preferences'] is Map<String, Object?>
        ? _map(raw['preferences'])
        : <String, Object?>{};
    final shortcuts = _list(pref['shortcuts'] ?? defaultShortcuts, 6);
    _require(
      shortcuts.length == 6 &&
          shortcuts.every(
            (s) => s == '' || s == 'savings' || _destinations.contains(s),
          ),
    );
    final active = _list(
      pref['orderTypes'] ?? ['صالة', 'سفري', 'توصيل'],
      20,
    ).map((t) => _string(t, 60).trim()).toList();
    final disabled = _list(
      pref['disabledOrderTypes'],
      20,
      optional: true,
    ).map((t) => _string(t, 60).trim()).toList();
    _require(active.isNotEmpty && active.length + disabled.length <= 20);
    final all = [...active, ...disabled];
    _require(
      all.every((s) => s.isNotEmpty) &&
          all.map((s) => s.toLowerCase()).toSet().length == all.length,
    );
    final restaurant = pref['restaurant'] is Map<String, Object?>
        ? _map(pref['restaurant'])
        : <String, Object?>{};
    Object? orEmpty(Object? x) => x == null || x == false || x == 0 ? '' : x;
    return {
      'products': products,
      'stockEntries': stock,
      'sales': sales,
      'saleReturns': returns,
      'preferences': {
        'shortcuts': shortcuts.map((s) => s == 'savings' ? '' : s).toList(),
        'orderTypes': active,
        if (disabled.isNotEmpty) 'disabledOrderTypes': disabled,
        'restaurant': {
          'name': _string(orEmpty(restaurant['name']), 100),
          'contact': _string(orEmpty(restaurant['contact']), 160),
          'footer': _string(orEmpty(restaurant['footer']), 300),
        },
      },
    };
  }

  static int _signedUnits(num value) =>
      (value < 0 ? -1 : 1) * _units(value.abs());
  static int _salesTotal(
    List<Map<String, Object?>> sales,
    List<Map<String, Object?>> returns,
    String date,
  ) => _money(
    _sum([
      ...sales
          .where((s) => s['date'] == date && s['status'] == 'completed')
          .map(_saleTotal),
      ...returns
          .where((r) => r['date'] == date)
          .map((r) => -(r['amount'] as int)),
    ]),
    signed: true,
  );
  List<Map<String, Object?>> _returns(
    Map<String, Object?> raw,
    List<Map<String, Object?>> sales,
  ) {
    final records = <Map<String, Object?>>[], ids = <String>{};
    for (final item in _list(raw['saleReturns'], 100000, optional: true)) {
      final r = _map(item), id = _id(r['id']), date = _dateValue(r['date']);
      _unique(ids, id);
      final found = sales.where((s) => s['id'] == r['saleId']).toList();
      _require(found.length == 1);
      final sale = found.single;
      _require(
        sale['status'] == 'completed' &&
            date.compareTo(sale['date'] as String) >= 0,
      );
      final reason = _string(r['reason'], 500).trim();
      _require(reason.isNotEmpty);
      final saleLines = (sale['lines'] as List).cast<Map<String, Object?>>();
      final subtotal = _invoiceTotal(sale),
          net = _saleTotal(sale),
          budgets = <Object?, int>{};
      var gross = 0;
      for (final line in saleLines) {
        final amount = _lineTotal(line);
        budgets[line['productId']] = subtotal == 0
            ? 0
            : ExactMath.cumulativeFloorAllocation(
                total: BigInt.from(net),
                priorUnits: BigInt.from(gross),
                additionalUnits: BigInt.from(amount),
                allUnits: BigInt.from(subtotal),
              ).toInt();
        gross += amount;
      }
      final rawLines = _list(r['lines'], saleLines.length);
      _require(rawLines.isNotEmpty);
      final used = <String>{}, lines = <Map<String, Object?>>[];
      for (final item in rawLines) {
        final l = _map(item);
        final matching = saleLines
            .where((line) => line['productId'] == l['productId'])
            .toList();
        _require(matching.length == 1);
        final original = matching.single;
        _unique(used, l['productId'] as String);
        final units = _units(l['quantity'], positive: true),
            sold = _units(original['quantity'], positive: true);
        final prior = _sum(
          records
              .where((old) => old['saleId'] == sale['id'])
              .expand(
                (old) => (old['lines'] as List).cast<Map<String, Object?>>(),
              )
              .where((old) => old['productId'] == l['productId'])
              .map((old) => _units(old['quantity'])),
        );
        _require(
          units <= sold - prior &&
              l['restock'] is bool &&
              (l['restock'] != true || original['trackStock'] == true),
        );
        final amount = ExactMath.cumulativeFloorAllocation(
          total: BigInt.from(budgets[l['productId']]!),
          priorUnits: BigInt.from(prior),
          additionalUnits: BigInt.from(units),
          allUnits: BigInt.from(sold),
        ).toInt();
        _require(l['amount'] is num && l['amount'] == amount);
        lines.add({
          'productId': l['productId'],
          'quantity': _quantity(l['quantity'], positive: true),
          'restock': l['restock'],
          'amount': amount,
        });
      }
      final amount = _money(_sum(lines.map((l) => l['amount'] as int)));
      _require(r['amount'] is num && r['amount'] == amount);
      records.add({
        'id': id,
        'saleId': r['saleId'],
        'date': date,
        'reason': reason,
        'createdAt': _stamp(r['createdAt']),
        'lines': lines,
        'amount': amount,
      });
    }
    return records;
  }

  Map<String, Object?> _savings(Map<String, Object?> raw) {
    final workers = <Map<String, Object?>>[],
        ids = <String>{},
        names = <String>{};
    for (final item in _list(raw['workers'], 500, optional: true)) {
      final w = _map(item),
          id = _id(w['id']),
          name = _string(w['name'], 100).trim(),
          amount = _money(w['amount']);
      _unique(ids, id);
      _unique(names, name.toLowerCase());
      _require(
        name.isNotEmpty &&
            amount > 0 &&
            ['daily', 'weekly', 'monthly'].contains(w['frequency']) &&
            w['archived'] is bool,
      );
      workers.add({
        'id': id,
        'name': name,
        'amount': amount,
        'frequency': w['frequency'],
        'startDate': _dateValue(w['startDate']),
        'archived': w['archived'],
        'note': _string(w['note']),
      });
    }
    final entries = <Map<String, Object?>>[],
        entryIds = <String>{},
        periods = <String, ({int due, int paid})>{};
    for (final item in _list(raw['savingsEntries'], 100000, optional: true)) {
      final e = _map(item),
          id = _id(e['id']),
          date = _dateValue(e['date']),
          amount = _money(e['amount']);
      _unique(entryIds, id);
      _require(
        ids.contains(e['workerId']) &&
            ['contribution', 'receipt'].contains(e['type']) &&
            amount > 0,
      );
      final clean = <String, Object?>{
        'id': id,
        'workerId': e['workerId'],
        'type': e['type'],
        'date': date,
        'amount': amount,
        'note': _string(e['note']),
        'createdAt': _stamp(e['createdAt']),
      };
      if (e['type'] == 'contribution') {
        final worker = workers.firstWhere((w) => w['id'] == e['workerId']),
            period = _savingsPeriod(worker, date);
        _require(
          period != null &&
              e['periodStart'] == period.$1 &&
              e['periodEnd'] == period.$2,
        );
        final due = _money(e['dueAmount']);
        _require(due > 0);
        final key = '${e['workerId']}:${period!.$1}',
            previous = periods[key] ?? (due: due, paid: 0);
        _require(previous.due == due);
        final paid = _sum([previous.paid, amount]);
        _require(paid <= due);
        periods[key] = (due: due, paid: paid);
        clean.addAll({
          'periodStart': period.$1,
          'periodEnd': period.$2,
          'dueAmount': due,
        });
      }
      entries.add(clean);
    }
    var balance = 0, contributed = 0, received = 0;
    final ordered = [...entries]
      ..sort((a, b) {
        final date = (a['date'] as String).compareTo(b['date'] as String);
        if (date != 0) return date;
        final type =
            (a['type'] == 'contribution' ? 0 : 1) -
            (b['type'] == 'contribution' ? 0 : 1);
        return type != 0
            ? type
            : (a['id'] as String).compareTo(b['id'] as String);
      });
    for (final e in ordered) {
      if (e['type'] == 'contribution') {
        contributed = _sum([contributed, e['amount'] as int]);
        balance = _sum([balance, e['amount'] as int]);
      } else {
        received = _sum([received, e['amount'] as int]);
        balance = _sum([balance, -(e['amount'] as int)]);
      }
      _require(balance >= 0);
    }
    return {'workers': workers, 'savingsEntries': entries};
  }

  static (String, String)? _savingsPeriod(
    Map<String, Object?> worker,
    String date,
  ) {
    final start = DateTime.parse('${worker['startDate']}T00:00:00Z'),
        target = DateTime.parse('${date}T00:00:00Z');
    if (target.isBefore(start)) return null;
    String key(DateTime value) =>
        '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
    if (worker['frequency'] == 'monthly') {
      DateTime at(int months) {
        final last = DateTime.utc(start.year, start.month + months + 1, 0).day;
        return DateTime.utc(
          start.year,
          start.month + months,
          start.day > last ? last : start.day,
        );
      }

      var months = (target.year - start.year) * 12 + target.month - start.month;
      if (at(months).isAfter(target)) months--;
      final end = at(months + 1);
      return (
        key(at(months)),
        end.year > 9999
            ? '9999-12-31'
            : key(end.subtract(const Duration(days: 1))),
      );
    }
    final interval = worker['frequency'] == 'weekly' ? 7 : 1,
        offset = target.difference(start).inDays ~/ interval * interval;
    final end = start.add(Duration(days: offset + interval - 1));
    return (
      key(start.add(Duration(days: offset))),
      end.year > 9999 ? '9999-12-31' : key(end),
    );
  }

  static void _validateAggregates(
    Map<String, Object?> state,
    int sourceVersion,
  ) {
    final days = _map(state['days']),
        payments = (state['payments'] as List).cast<Map<String, Object?>>(),
        transfers = (state['transfers'] as List).cast<Map<String, Object?>>(),
        transactions = (state['transactions'] as List)
            .cast<Map<String, Object?>>(),
        sales = (state['sales'] as List).cast<Map<String, Object?>>(),
        returns = (state['saleReturns'] as List).cast<Map<String, Object?>>();
    List<Map<String, Object?>> expenses(String date) => [
      if (days[date] != null)
        ...(_map(days[date])['expenses'] as List).cast<Map<String, Object?>>(),
      ...payments.where((p) => p['date'] == date),
    ];
    int daily(String date) => _sum(
      expenses(date).map((e) => _map(e['funding'])['dailyAmount'] as int),
    );
    int transferred(String date) => _sum(
      transfers.where((t) => t['date'] == date).map((t) => t['amount'] as int),
    );
    for (final date in {
      ...days.keys,
      ...payments.map((p) => p['date'] as String),
    }) {
      _sum(expenses(date).map((e) => e['amount'] as int));
    }
    var cash = 0;
    for (final t in transactions) {
      cash = _sum([
        cash,
        (t['type'] == 'withdrawal' ? -1 : 1) * (t['amount'] as int),
      ]);
    }
    // Preserve the source movements ordering: explicit transactions, then cash
    // shares in day/payment insertion order, then daily-to-cashbox transfers.
    for (final date in {
      ...days.keys,
      ...payments.map((p) => p['date'] as String),
    }) {
      for (final e in expenses(date)) {
        final share = _map(e['funding'])['cashAmount'] as int;
        if (share != 0) cash = _sum([cash, -share]);
      }
    }
    for (final t in transfers) {
      cash = _sum([cash, t['amount'] as int]);
    }
    for (final entry in days.entries) {
      final day = _map(entry.value), r = day['remaining'];
      final transfer = transferred(entry.key);
      if (r == null) continue;
      final snapshot = _map(r);
      // Preserve the frozen source's operator grouping and binary64 integer
      // rounding acceptance profile. Madar simulates nearest-even53bit rounding
      // with BigInt; no floating-point monetary arithmetic is introduced here.
      final remaining = ExactMath.checkedBinary64IntegerSum(
        [
          BigInt.from(snapshot['amount'] as int),
          -(BigInt.from(daily(entry.key)) -
              BigInt.from(snapshot['dailySpent'] as int)),
          -(BigInt.from(transfer) -
              BigInt.from(snapshot['transferred'] as int)),
          BigInt.from(_salesTotal(sales, returns, entry.key)) -
              BigInt.from(snapshot['salesTotal'] as int? ?? 0),
        ],
        maxAbs: _safe,
        maxSafeInteger: _safe,
      ).toInt();
      if (sourceVersion < 5 && day['balance'] == null) {
        final total = day['totalOverride'] as int? ?? daily(entry.key);
        final sum =
            BigInt.from(total) + BigInt.from(remaining) + BigInt.from(transfer);
        if (sum.abs() <= _moneyLimit && sum.abs() <= _safe) {
          day['balance'] = sum.toInt();
        }
      }
    }
  }
}
