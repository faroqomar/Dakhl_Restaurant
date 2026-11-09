import 'package:madar_domain/madar_domain.dart';

import '../accounts/account_document.dart';
import '../reports/source_event_order.dart';
import 'purchase_proposal.dart';
import 'supplier_ledger.dart';

final class PurchaseUnitSummary {
  PurchaseUnitSummary(this.name, this.unit);
  final String name, unit;
  BigInt cartons = BigInt.zero, pieces = BigInt.zero;
}

final class PurchasePriceChange {
  const PurchasePriceChange({
    required this.date,
    required this.supplierId,
    required this.name,
    required this.cartonPrice,
    required this.piecePrice,
    required this.cartonDelta,
    required this.pieceDelta,
  });
  final String date, supplierId, name;
  final int cartonPrice, piecePrice, cartonDelta, pieceDelta;
}

/// Read-only frozen purchase-page projection. Each saved name/unit keeps its
/// independent carton and piece quantities; prices never rewrite saved lines.
final class PurchaseAnalysis {
  PurchaseAnalysis._(this.units, this.changes, this.amount, this.invoiceCount);
  final List<PurchaseUnitSummary> units;
  final List<PurchasePriceChange> changes;
  final BigInt amount;
  final int invoiceCount;

  static PurchaseAnalysis build(
    AccountDocument account, {
    String supplierId = '',
    String material = '',
    String from = '',
    String to = '',
    required int Function(String, String)? compareText,
    Set<String>? visibleInvoiceIds,
  }) {
    final invoices = (account.toJson()['invoices']! as List)
        .cast<Map<String, Object?>>();
    bool inRange(String date) =>
        (from.isEmpty || date.compareTo(from) >= 0) &&
        (to.isEmpty || date.compareTo(to) <= 0);
    bool matchingLine(Map<String, Object?> line) =>
        material.isEmpty ||
        PurchaseProposals.sourceMaterialNameKey(line['name']! as String) ==
            PurchaseProposals.sourceMaterialNameKey(material);
    final scoped = invoices.where(
      (i) => supplierId.isEmpty || i['supplierId'] == supplierId,
    );
    final visible = scoped
        .where(
          (i) =>
              inRange(i['date']! as String) &&
              (visibleInvoiceIds == null ||
                  visibleInvoiceIds.contains(i['id'])) &&
              (i['lines']! as List).cast<Map<String, Object?>>().any(
                matchingLine,
              ),
        )
        .toList();
    final groups = <(String, String), PurchaseUnitSummary>{};
    final totals = <BigInt>[];
    final queries = SupplierLedgerQueries(
      account,
      compareText:
          compareText ??
          (a, b) => throw const FormatException('collation_unavailable'),
    );
    BigInt quantity(Object? value) => ExactDecimal.parse(
      '${value ?? 0}',
      scale: 3,
      maxAbsUnits: BigInt.from(1000000000000),
      signed: false,
      positive: false,
    ).units;
    for (final invoice in visible) {
      final lines = (invoice['lines']! as List)
          .cast<Map<String, Object?>>()
          .where(matchingLine)
          .toList();
      totals.add(queries.invoiceTotal({'lines': lines}));
      for (final line in lines) {
        final name = line['name']! as String, unit = line['unit']! as String;
        final group = groups.putIfAbsent((
          name,
          unit,
        ), () => PurchaseUnitSummary(name, unit));
        group.cartons += quantity(line['quantityCartons']);
        group.pieces += quantity(line['quantityPieces'] ?? line['quantity']);
      }
    }
    // Compare against purchases before the lower date boundary too. Applying the
    // date filter first would hide the first price change inside the interval.
    final history = orderSourceEvents(
      [
        for (final invoice in scoped)
          for (final line
              in (invoice['lines']! as List).cast<Map<String, Object?>>().where(
                matchingLine,
              ))
            <String, Object?>{
              ...line,
              'date': invoice['date'],
              'supplierId': invoice['supplierId'],
            },
      ],
      keys: const ['date'],
      descending: false,
      compareText: compareText,
    );
    final previous = <String, Map<String, Object?>>{};
    final changes = <PurchasePriceChange>[];
    for (final line in history) {
      final name = line['name']! as String;
      final old = previous[name];
      final carton = line['priceCarton'] as int? ?? 0;
      final piece = line['pricePiece'] as int? ?? line['price'] as int? ?? 0;
      if (old != null) {
        final cartonDelta = carton - (old['priceCarton'] as int? ?? 0);
        final pieceDelta =
            piece - (old['pricePiece'] as int? ?? old['price'] as int? ?? 0);
        if ((cartonDelta != 0 || pieceDelta != 0) &&
            inRange(line['date']! as String)) {
          changes.add(
            PurchasePriceChange(
              date: line['date']! as String,
              supplierId: line['supplierId']! as String,
              name: name,
              cartonPrice: carton,
              piecePrice: piece,
              cartonDelta: cartonDelta,
              pieceDelta: pieceDelta,
            ),
          );
        }
      }
      previous[name] = line;
    }
    return PurchaseAnalysis._(
      List.unmodifiable(groups.values),
      List.unmodifiable(changes),
      ExactMath.binary64IntegerSum(totals),
      visible.length,
    );
  }
}
