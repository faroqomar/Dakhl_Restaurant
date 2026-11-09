import 'package:madar_domain/madar_domain.dart';

import '../accounts/account_document.dart';
import '../accounts/legacy_account_codec.dart';

/// Validated source-record proposal only. It does not persist, reserve stock,
/// allocate durable operation identity, or produce a financial journal.
final class SaleProposal {
  SaleProposal._(this.base, this.candidate, this.sale);
  final AccountDocument base, candidate;
  final Map<String, Object?> sale;
  static final _limit = BigInt.from(1000000000000);
  static final _policy = CommercePolicy(
    quantityScale: 3,
    maximumQuantityUnits: _limit,
    maximumMoney: _limit,
    maximumSafeInteger: BigInt.parse('9007199254740991'),
    rounding: DecimalRounding.halfTowardPositiveInfinity,
  );

  static SaleProposal build(
    AccountDocument base, {
    required Map<String, Object?> draft,
    required String saleId,
    required String createdAt,
  }) {
    final data = base.toJson();
    final sales = (data['sales']! as List).cast<Map<String, Object?>>();
    if (sales.any((s) => s['id'] == saleId)) {
      throw const FormatException('Sale identity already exists');
    }
    final input = draft['lines'];
    if (input is! List || input.isEmpty) {
      throw const FormatException('Sale requires lines');
    }
    final orderType = draft['orderType'] ?? base.preferences.orderTypes.first;
    if (!base.preferences.orderTypes.contains(orderType)) {
      throw const FormatException('Order type is unavailable');
    }
    final products = (data['products']! as List).cast<Map<String, Object?>>();
    final lines = <Map<String, Object?>>[];
    for (final raw in input) {
      if (raw is! Map) throw const FormatException('Invalid sale line');
      final matches = products.where((p) => p['id'] == raw['productId']);
      if (matches.isEmpty || matches.first['archived'] == true) {
        throw const FormatException('Product is unavailable');
      }
      final product = matches.first;
      lines.add({
        'productId': product['id'],
        'name': product['name'],
        'unit': product['unit'],
        'trackStock': product['trackStock'],
        'price': raw.containsKey('price') ? raw['price'] : product['price'],
        'quantity': raw['quantity'],
      });
    }
    final moneyPolicy = ExactIntegerPolicy(
      maxAbs: _limit,
      signed: false,
      positive: false,
      maxSafeInteger: BigInt.parse('9007199254740991'),
    );
    final discount = moneyPolicy.validate(draft['discount']);
    final quote = CommerceCalculations.saleQuote(
      lines.map(
        (line) => CommerceCalculations.lineTotal(
          QuantityPrice(
            quantityUnits: ExactDecimal.parse(
              '${line['quantity']}',
              scale: 3,
              maxAbsUnits: _limit,
              signed: false,
              positive: true,
              allowExponent: true,
            ).units,
            price: moneyPolicy.validate(line['price']),
          ),
          policy: _policy,
        ),
      ),
      discount: discount,
      policy: _policy,
    );
    var next = 0.0;
    final pattern = RegExp(r'^S-([0-9]+)$');
    for (final sale in sales) {
      final match = pattern.firstMatch(sale['number']! as String);
      if (match != null) {
        final value = double.parse(match.group(1)!);
        if (value > next) next = value;
      }
    }
    next += 1;
    final digits = LegacyNumberFormat.nonnegativeInteger(next);
    final sale = <String, Object?>{
      'id': saleId,
      'number': 'S-${digits.padLeft(6, '0')}',
      'date': draft['date'],
      'status': 'completed',
      'orderType': orderType,
      'discount': draft['discount'],
      'paid': draft['paid'] ?? quote.net.toInt(),
      'note': draft['note'] ?? '',
      'createdAt': createdAt,
      'lines': lines,
    };
    final candidate = const LegacyAccountCodec().decodeJson({
      ...data,
      'sales': [...sales, sale],
    });
    return SaleProposal._(
      base,
      candidate,
      (candidate.toJson()['sales']! as List).last as Map<String, Object?>,
    );
  }
}
