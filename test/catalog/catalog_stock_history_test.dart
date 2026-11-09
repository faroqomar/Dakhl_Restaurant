import 'package:flutter_test/flutter_test.dart';
import 'package:madar_domain/madar_domain.dart';
import 'package:dakhl_restaurant/catalog/catalog_stock_history.dart';
import 'package:dakhl_restaurant/inventory/inventory_commands.dart';

import 'stock_movement_workflow_test.dart' as workflow;

void main() {
  final today = DateOnly.parse(
    '2026-11-07',
    minimumYear: 1000,
    maximumYear: 9999,
  );
  test(
    'history sorts equal-date timestamps by raw ID and keeps dated balances',
    () async {
      final (repo, accounts, model, shell) = await workflow.setupWorkflow();
      addTearDown(() {
        model.dispose();
        accounts.dispose();
        shell.dispose();
      });
      await workflow.createTestProduct(
        model,
        id: 'p',
        name: 'اختبار',
        openingUnits: BigInt.from(10000),
        asOf: today,
      );
      for (final row in [('b', 2000), ('a', 1000)]) {
        await model.postMovement(
          InventoryMovement(
            id: row.$1,
            productId: 'p',
            quantityUnits: BigInt.from(row.$2),
            effectiveDate: today,
            kind: StockEntryKind.restock,
            createdAt: '2026-11-07T10:00:00.000Z',
          ),
          session: model.beginEdit(),
        );
      }
      final before = model.stockHistoryAt('p', today: today);
      expect(before.map((e) => e.id), ['open_p', 'a', 'b']);
      expect(
        before.map((e) => e.runningBalanceUnits),
        [10000, 11000, 13000].map(BigInt.from),
      );
      expect(() => before.clear(), throwsUnsupportedError);
      final tomorrow = DateOnly.parse(
        '2026-11-08',
        minimumYear: 1000,
        maximumYear: 9999,
      );
      await model.postMovement(
        InventoryMovement(
          id: 'future',
          productId: 'p',
          quantityUnits: BigInt.from(5000),
          effectiveDate: tomorrow,
          kind: StockEntryKind.restock,
          createdAt: '2026-11-07T11:00:00.000Z',
        ),
        session: model.beginEdit(),
      );
      final history = model.stockHistoryAt('p', today: today);
      expect(history.last.isFuture, isTrue);
      expect(history.last.runningBalanceUnits, BigInt.from(18000));
      expect(
        model.inventoryAt(today)!.items.single.availableUnits,
        BigInt.from(13000),
      );
      expect(before, hasLength(3));
    },
  );

  test(
    'history pagination preserves original running balances across 120 events',
    () async {
      final (repo, accounts, model, shell) = await workflow.setupWorkflow();
      addTearDown(() {
        model.dispose();
        accounts.dispose();
        shell.dispose();
      });
      await workflow.createTestProduct(
        model,
        id: 'p',
        name: 'اختبار',
        asOf: today,
      );
      final raw = Map<String, Object?>.from(repo.document!.toJson());
      raw['stockEntries'] = [
        for (var i = 0; i < 120; i++)
          {
            'id': 'entry-${i.toString().padLeft(3, '0')}',
            'productId': 'p',
            'date': '2026-11-07',
            'createdAt': '2026-11-07T10:00:00.000Z',
            'kind': 'restock',
            'quantity': 1,
            'note': '',
          },
      ];
      await repo.save(repo.codec.decodeJson(raw));
      final history = model.stockHistoryAt('p', today: today);
      final first = CatalogStockHistoryPage(history, 1),
          last = CatalogStockHistoryPage(history, 999);
      expect(first.items.first.id, 'entry-119');
      expect(first.items.first.runningBalanceUnits, BigInt.from(120000));
      expect(first.items.last.runningBalanceUnits, BigInt.from(71000));
      expect(last.page, 3);
      expect(last.items, hasLength(20));
      expect(last.items.last.runningBalanceUnits, BigInt.from(1000));
      expect(CatalogStockHistoryPage(history, 0).page, 1);
    },
  );
}
