import 'package:madar_domain/madar_domain.dart';

import '../accounts/account_document.dart';

String _sourceLower(String text) =>
    LegacyCase.lower(text, profile: LegacyCaseProfile.ecmascriptUnicode17);

enum InventoryStatus { active, all, archived, low, out }

/// Consumer presentation of validated records; stock computation stays in Madar.
final class CatalogProduct {
  CatalogProduct._(Map<String, Object?> record, this.availableUnits)
    : id = record['id'] as String,
      name = record['name'] as String,
      code = record['code'] as String,
      group = record['group'] as String,
      unit = record['unit'] as String,
      price = record['price'] as int,
      photo = record['photo'] as String?,
      archived = record['archived'] as bool,
      tracked = record['trackStock'] as bool,
      minimumUnits = ExactDecimal.parse(
        record['minStock'].toString(),
        scale: 3,
        maxAbsUnits: BigInt.from(1000000000000),
        signed: false,
        positive: false,
        allowExponent: true,
      ).units;
  final String id, name, code, group, unit;
  final String? photo;
  final int price;
  final bool archived, tracked;
  final BigInt availableUnits, minimumUnits;
  bool get low => tracked && availableUnits <= minimumUnits;
  String get statusLabel => archived
      ? 'موقوف'
      : !tracked
      ? 'بدون تتبّع'
      : availableUnits == BigInt.zero
      ? 'نافد'
      : low
      ? 'مخزون قليل'
      : 'متوفر';
}

final class CatalogPage {
  CatalogPage._(
    Iterable<CatalogProduct> values,
    int requestedPage,
    this.pageSize,
  ) : _all = List.unmodifiable(values) {
    pageCount = _all.isEmpty ? 1 : (_all.length + pageSize - 1) ~/ pageSize;
    page = requestedPage.clamp(1, pageCount);
    final start = (page - 1) * pageSize;
    items = List.unmodifiable(_all.skip(start).take(pageSize));
  }
  final List<CatalogProduct> _all;
  final int pageSize;
  late final int page, pageCount;
  late final List<CatalogProduct> items;
  int get total => _all.length;
}

final class CatalogReadModel {
  CatalogReadModel.fromAccount(
    AccountDocument account, {
    required Map<String, BigInt> balanceUnitsByProduct,
  }) : products = List.unmodifiable(
         (account.toJson()['products'] as List)
             .cast<Map<String, Object?>>()
             .map(
               (p) => CatalogProduct._(
                 p,
                 balanceUnitsByProduct[p['id']] ?? BigInt.zero,
               ),
             ),
       );
  final List<CatalogProduct> products;
  List<String> get groups => List.unmodifiable({
    for (final p in products)
      if (!p.archived && p.group.isNotEmpty) p.group,
  });
  List<String> get inventoryGroups => List.unmodifiable({
    for (final p in products)
      if (p.group.isNotEmpty) p.group,
  });
  int get lowStockCount => products.where((p) => !p.archived && p.low).length;
  CatalogPage sales({String query = '', String group = '', int page = 1}) =>
      CatalogPage._(
        products.where(
          (p) =>
              !p.archived &&
              (group.isEmpty || p.group == group) &&
              _sourceLower('${p.name} ${p.code}').contains(_sourceLower(query)),
        ),
        page,
        80,
      );
  CatalogPage inventory({
    String query = '',
    String group = '',
    InventoryStatus status = InventoryStatus.active,
    int page = 1,
  }) => CatalogPage._(
    products.where(
      (p) =>
          (group.isEmpty || p.group == group) &&
          _sourceLower('${p.name} ${p.code} ${p.group}')
              .contains(_sourceLower(query)) &&
          switch (status) {
            InventoryStatus.all => true,
            InventoryStatus.archived => p.archived,
            InventoryStatus.active => !p.archived,
            InventoryStatus.low => !p.archived && p.low,
            InventoryStatus.out =>
              !p.archived && p.tracked && p.availableUnits == BigInt.zero,
          },
    ),
    page,
    50,
  );
}
