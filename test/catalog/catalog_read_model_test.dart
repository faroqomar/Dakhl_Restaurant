import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:dakhl_restaurant/accounts/legacy_account_codec.dart';
import 'package:dakhl_restaurant/catalog/catalog_read_model.dart';

void main() {
  const codec = LegacyAccountCodec();
  test(
    'frozen JavaScript filters and paging agree on synthetic oracle cases',
    () {
      final oracle = jsonDecode(
        File('test/catalog/oracle.json').readAsStringSync(),
      ) as Map<String, dynamic>;
      final account = codec.decodeJson({
        ...codec.empty().toJson(),
        'products': oracle['products'],
      });
      final model = CatalogReadModel.fromAccount(
        account,
        balanceUnitsByProduct: {
          'p0': BigInt.from(1500),
          'p1': BigInt.from(2000),
        },
      );
      for (final c in (oracle['cases'] as List).cast<Map<String, dynamic>>()) {
        final result = c['kind'] == 'sales'
            ? model.sales(query: c['query'], group: c['group'], page: c['page'])
            : model.inventory(
                query: c['query'],
                group: c['group'],
                page: c['page'],
                status: InventoryStatus.values.byName(c['status']),
              );
        expect(
          result.items.map((p) => p.id).toList(),
          c['expected']['ids'],
          reason: c.toString(),
        );
        expect(result.total, c['expected']['total']);
        expect(result.page, c['expected']['page']);
      }
    },
  );

  final raw = {
    ...codec.empty().toJson(),
    'products': [
      for (var i = 0; i < 85; i++)
        {
          'id': 'p$i',
          'name': 'صنف $i',
          'code': 'SKU$i',
          'group': i.isEven ? 'مشاوي' : 'مشروبات',
          'unit': 'قطعة',
          'price': 1000,
          'minStock': 1.5,
          'trackStock': i != 3,
          'archived': i == 2,
        },
    ],
  };
  CatalogReadModel catalog() => CatalogReadModel.fromAccount(
    codec.decodeJson(raw),
    balanceUnitsByProduct: {'p0': BigInt.from(1500), 'p1': BigInt.from(2000)},
  );
  test(
    'inventory filters exact low boundary, archive and untracked status',
    () {
      final model = catalog();
      expect(
        model.inventory(status: InventoryStatus.archived).items.single.id,
        'p2',
      );
      expect(
        model.inventory(status: InventoryStatus.low).items.map((p) => p.id),
        contains('p0'),
      );
      expect(
        model.inventory(status: InventoryStatus.low).items.map((p) => p.id),
        isNot(contains('p3')),
      );
      expect(
        model.inventory(query: 'sKu1').items.map((p) => p.id),
        contains('p1'),
      );
      expect(model.inventory(query: 'مشروبات').total, 42);
    },
  );
  test(
    'pagination preserves source order and clamps pages without sorting',
    () {
      final model = catalog();
      expect(model.sales().items.length, 80);
      expect(model.sales(page: 99).page, 2);
      expect(model.sales(page: 99).items.length, 4);
      expect(model.inventory(page: 0).page, 1);
      expect(model.inventory(query: 'absent', page: 9).page, 1);
      expect(() => model.sales().items.clear(), throwsUnsupportedError);
    },
  );
  test(
    'sales search excludes group while groups preserve first appearance',
    () {
      final model = catalog();
      expect(model.sales(query: 'مشاوي').total, 0);
      expect(model.sales(group: 'مشروبات').total, 42);
      expect(model.groups, ['مشاوي', 'مشروبات']);
      expect(
        model.inventory(status: InventoryStatus.all).items[3].statusLabel,
        'بدون تتبّع',
      );
    },
  );
}
