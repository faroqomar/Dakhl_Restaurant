import 'package:madar_domain/madar_domain.dart';

import '../accounts/account_document.dart';

final class CatalogStockHistoryItem {
  const CatalogStockHistoryItem({
    required this.id,
    required this.effectiveDate,
    required this.createdAt,
    required this.deltaUnits,
    required this.runningBalanceUnits,
    required this.kindLabel,
    required this.detail,
    required this.isFuture,
    required this.isReversible,
    this.rawStockEntry,
    this.saleId,
    this.returnId,
  });

  final String id;
  final DateOnly effectiveDate;
  final String createdAt;
  final BigInt deltaUnits;
  final BigInt runningBalanceUnits;
  final String kindLabel;
  final String detail;
  final bool isFuture;
  final bool isReversible;
  final Map<String, Object?>? rawStockEntry;
  final String? saleId;
  final String? returnId;
}

/// Presentation pagination preserves chronological balances on newest-first rows.
final class CatalogStockHistoryPage {
  CatalogStockHistoryPage(
    List<CatalogStockHistoryItem> history,
    int requestedPage,
  ) {
    pageCount = history.isEmpty ? 1 : (history.length + 49) ~/ 50;
    page = requestedPage.clamp(1, pageCount);
    items = List.unmodifiable(history.reversed.skip((page - 1) * 50).take(50));
  }
  late final int page, pageCount;
  late final List<CatalogStockHistoryItem> items;
}

/// Restaurant record presentation; Madar owns quantity arithmetic.
abstract final class CatalogStockHistory {
  static DateOnly _date(String value) =>
      DateOnly.parse(value, minimumYear: 1000, maximumYear: 9999);
  static BigInt _quantity(
    String value, {
    bool signed = false,
    bool positive = false,
  }) => ExactDecimal.parse(
    value,
    scale: 3,
    maxAbsUnits: BigInt.from(1000000000000),
    signed: signed,
    positive: positive,
    allowExponent: true,
  ).units;
  static List<CatalogStockHistoryItem> compose(
    AccountDocument account, {
    required String productId,
    required DateOnly today,
  }) {
    final rawEntries =
        (account.toJson()['stockEntries'] as List?)
            ?.cast<Map<String, Object?>>()
            .where((e) => e['productId'] == productId)
            .toList() ??
        [];
    final allRawEntries =
        (account.toJson()['stockEntries'] as List?)
            ?.cast<Map<String, Object?>>() ??
        [];
    final rawSales =
        (account.toJson()['sales'] as List?)?.cast<Map<String, Object?>>() ??
        [];
    final rawReturns =
        (account.toJson()['saleReturns'] as List?)
            ?.cast<Map<String, Object?>>() ??
        [];

    // Set of entry IDs that have already been reversed by another entry
    final reversedIds = <String>{
      for (final e in allRawEntries)
        if (e['reversesId'] != null) e['reversesId'] as String,
    };

    final rawMovements = <_RawHistoryMovement>[];

    for (final e in rawEntries) {
      final date = _date(e['date'] as String);
      final units = _quantity(e['quantity'].toString(), signed: true);
      final kindStr = e['kind'] as String? ?? 'adjustment';
      final kindLabel = switch (kindStr) {
        'opening' => 'افتتاحي',
        'restock' => 'تزويد',
        'adjustment' => 'تسوية',
        'loss' => 'تالف أو هدر',
        _ => kindStr,
      };
      final note = (e['note'] as String?)?.trim() ?? '';
      final reversesId = e['reversesId'] as String?;
      final isReversal = reversesId != null;
      final displayKind = isReversal ? 'عكس حركة' : kindLabel;
      final detail = isReversal
          ? 'تصحيح للحركة: $reversesId${note.isNotEmpty ? ' · $note' : ''}'
          : note;
      final isReversible = !isReversal && !reversedIds.contains(e['id']);

      rawMovements.add(
        _RawHistoryMovement(
          id: e['id'] as String,
          effectiveDate: date,
          createdAt: e['createdAt'] as String? ?? '',
          deltaUnits: units,
          kindLabel: displayKind,
          detail: detail,
          isReversible: isReversible,
          rawStockEntry: e,
        ),
      );
    }

    for (final sale in rawSales) {
      if (sale['status'] != 'completed') continue;
      final lines =
          (sale['lines'] as List?)?.cast<Map<String, Object?>>() ?? [];
      for (final line in lines) {
        if (line['productId'] == productId && line['trackStock'] == true) {
          final date = _date(sale['date'] as String);
          final units = _quantity(line['quantity'].toString(), positive: true);
          final saleId = sale['id'] as String;
          rawMovements.add(
            _RawHistoryMovement(
              id: saleId,
              effectiveDate: date,
              createdAt: sale['createdAt'] as String? ?? '',
              deltaUnits: -units,
              kindLabel: 'بيع',
              detail: 'فاتورة بيع رقم: $saleId',
              isReversible: false,
              saleId: saleId,
            ),
          );
        }
      }
    }

    for (final ret in rawReturns) {
      final lines = (ret['lines'] as List?)?.cast<Map<String, Object?>>() ?? [];
      for (final line in lines) {
        if (line['productId'] == productId && line['restock'] == true) {
          final date = _date(ret['date'] as String);
          final units = _quantity(line['quantity'].toString(), positive: true);
          final returnId = ret['id'] as String;
          rawMovements.add(
            _RawHistoryMovement(
              id: returnId,
              effectiveDate: date,
              createdAt: ret['createdAt'] as String? ?? '',
              deltaUnits: units,
              kindLabel: 'مرتجع',
              detail: 'مرتجع بيع رقم: $returnId',
              isReversible: false,
              returnId: returnId,
            ),
          );
        }
      }
    }

    // Sort chronologically by date, then createdAt
    final encounter = {
      for (var i = 0; i < rawMovements.length; i++) rawMovements[i]: i,
    };
    rawMovements.sort((a, b) {
      final cmp = a.effectiveDate.compareTo(b.effectiveDate);
      if (cmp != 0) return cmp;
      final recorded = a.createdAt.compareTo(b.createdAt);
      if (recorded != 0) return recorded;
      final id = a.id.compareTo(b.id);
      if (id != 0) return id;
      // Source encounter order is returns, stock, then completed sales.
      int rank(_RawHistoryMovement item) => item.returnId != null
          ? 0
          : item.rawStockEntry != null
          ? 1
          : 2;
      final source = rank(a).compareTo(rank(b));
      if (source != 0) return source;
      return encounter[a]!.compareTo(encounter[b]!);
    });

    // Compute running balance
    var running = BigInt.zero;
    final items = <CatalogStockHistoryItem>[];

    for (final m in rawMovements) {
      running = ExactMath.binary64IntegerSum([running, m.deltaUnits]);
      final isFuture = m.effectiveDate.compareTo(today) > 0;

      items.add(
        CatalogStockHistoryItem(
          id: m.id,
          effectiveDate: m.effectiveDate,
          createdAt: m.createdAt,
          deltaUnits: m.deltaUnits,
          runningBalanceUnits: running,
          kindLabel: m.kindLabel,
          detail: m.detail,
          isFuture: isFuture,
          isReversible: m.isReversible,
          rawStockEntry: m.rawStockEntry,
          saleId: m.saleId,
          returnId: m.returnId,
        ),
      );
    }

    return List.unmodifiable(items);
  }
}

class _RawHistoryMovement {
  const _RawHistoryMovement({
    required this.id,
    required this.effectiveDate,
    required this.createdAt,
    required this.deltaUnits,
    required this.kindLabel,
    required this.detail,
    required this.isReversible,
    this.rawStockEntry,
    this.saleId,
    this.returnId,
  });

  final String id;
  final DateOnly effectiveDate;
  final String createdAt;
  final BigInt deltaUnits;
  final String kindLabel;
  final String detail;
  final bool isReversible;
  final Map<String, Object?>? rawStockEntry;
  final String? saleId;
  final String? returnId;
}
