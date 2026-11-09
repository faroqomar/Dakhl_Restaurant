import 'dart:convert';

import 'package:madar_domain/madar_domain.dart';

import '../accounts/account_document.dart';
import '../accounts/legacy_account_codec.dart';

final class ReturnLineRequest {
  const ReturnLineRequest({
    required this.productId,
    required this.quantityUnits,
    required this.restock,
  });
  final String productId;
  final BigInt quantityUnits;
  final bool restock;
}

/// Pure cumulative refund quote shared by preview and durable proposal building.
final class ReturnQuote {
  ReturnQuote(this.amount, Iterable<Map<String, Object?>> lines)
    : lines = List.unmodifiable(
        lines.map((line) => Map<String, Object?>.unmodifiable(line)),
      );
  final BigInt amount;
  final List<Map<String, Object?>> lines;
}

/// Immutable synthetic candidate only: does not persist, acknowledge cash paid,
/// map journals, reserve inventory or authorize a durable return operation.
final class ReturnProposal {
  ReturnProposal._(this.base, this.candidate, this.amount);
  final AccountDocument base, candidate;
  final BigInt amount;
  static final _money = BigInt.from(1000000000000);
  static final _policy = CommercePolicy(
    quantityScale: 3,
    maximumQuantityUnits: _money,
    maximumMoney: _money,
    maximumSafeInteger: BigInt.parse('9007199254740991'),
    rounding: DecimalRounding.halfTowardPositiveInfinity,
  );
  static BigInt _units(Object? value) => ExactDecimal.parse(
    '$value',
    scale: 3,
    maxAbsUnits: _money,
    signed: false,
    positive: true,
  ).units;
  static void _date(String date) =>
      DateOnly.parse(date, minimumYear: 1000, maximumYear: 9999);

  static ReturnQuote quote(
    AccountDocument base, {
    required String saleId,
    required Iterable<ReturnLineRequest> lines,
  }) {
    final raw = base.toJson();
    final matches = (raw['sales']! as List)
        .cast<Map<String, Object?>>()
        .where((sale) => sale['id'] == saleId)
        .toList(growable: false);
    if (matches.length != 1 || matches.single['status'] != 'completed') {
      throw const FormatException('Sale unavailable for return.');
    }
    final sale = matches.single;
    final requested = lines.toList(growable: false);
    final sold = (sale['lines']! as List).cast<Map<String, Object?>>();
    if (requested.isEmpty || requested.length > sold.length) {
      throw const FormatException('Invalid return lines.');
    }
    final totals = sold.map(
      (l) => CommerceCalculations.lineTotal(
        QuantityPrice(
          quantityUnits: _units(l['quantity']),
          price: BigInt.from(l['price']! as int),
        ),
        policy: _policy,
      ),
    );
    final quote = CommerceCalculations.saleQuote(
      totals,
      discount: BigInt.from(sale['discount']! as int),
      policy: _policy,
    );
    final prior = (raw['saleReturns']! as List)
        .cast<Map<String, Object?>>()
        .where((r) => r['saleId'] == saleId)
        .expand((r) => (r['lines']! as List).cast<Map<String, Object?>>())
        .toList();
    final used = <String>{};
    final result = <Map<String, Object?>>[];
    for (final request in requested) {
      final index = sold.indexWhere((l) => l['productId'] == request.productId);
      if (index < 0 || !used.add(request.productId)) {
        throw const FormatException('Unknown or duplicate return line.');
      }
      final original = sold[index];
      if (request.restock && original['trackStock'] != true) {
        throw const FormatException('Cannot restock untracked item.');
      }
      final already = ExactMath.binary64IntegerSum(
        prior
            .where((l) => l['productId'] == request.productId)
            .map((l) => _units(l['quantity'])),
      );
      final amount = CommerceCalculations.cumulativeRefund(
        lineBudget: quote.lineBudgets[index],
        soldUnits: _units(original['quantity']),
        priorUnits: already,
        additionalUnits: request.quantityUnits,
        policy: _policy,
      );
      result.add({
        'productId': request.productId,
        'quantity': num.parse(
          ExactDecimal.fromUnits(request.quantityUnits, 3).toString(),
        ),
        'restock': request.restock,
        'amount': amount.toInt(),
      });
    }
    final amount = CommerceCalculations.invoiceTotal(
      result.map((l) => BigInt.from(l['amount']! as int)),
      policy: _policy,
    );
    return ReturnQuote(amount, result);
  }

  static ReturnProposal build(
    AccountDocument base, {
    required String saleId,
    required String returnId,
    required String date,
    required String reason,
    required String createdAt,
    required String today,
    required Iterable<ReturnLineRequest> lines,
  }) {
    _date(date);
    _date(today);
    if (date.compareTo(today) > 0) {
      throw const FormatException('Future return date.');
    }
    final raw = base.toJson();
    final matches = (raw['sales']! as List).cast<Map<String, Object?>>().where(
      (s) => s['id'] == saleId,
    );
    if (matches.isEmpty || matches.first['status'] != 'completed') {
      throw const FormatException('Sale unavailable for return.');
    }
    final sale = matches.first;
    if (date.compareTo(sale['date']! as String) < 0) {
      throw const FormatException('Return precedes sale.');
    }
    final calculated = quote(base, saleId: saleId, lines: lines);
    final result = calculated.lines;
    final amount = calculated.amount;
    final next = jsonDecode(jsonEncode(raw)) as Map<String, dynamic>;
    (next['saleReturns'] as List).add({
      'id': returnId,
      'saleId': saleId,
      'date': date,
      'reason': LegacyText.trimJavaScript(reason),
      'createdAt': createdAt,
      'lines': result,
      'amount': amount.toInt(),
    });
    // Codec validates identity uniqueness, reason/timestamp/schema, historical
    // stock and aggregate constraints; caller's base stays untouched.
    final candidate = const LegacyAccountCodec().decodeJson(next);
    return ReturnProposal._(base, candidate, amount);
  }
}
