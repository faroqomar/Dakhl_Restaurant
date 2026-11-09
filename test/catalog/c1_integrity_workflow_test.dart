import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar_domain/madar_domain.dart';
import 'package:dakhl_restaurant/catalog/catalog_formatters.dart';
import 'package:dakhl_restaurant/catalog/inventory_surface.dart';
import 'package:dakhl_restaurant/catalog/product_form_dialog.dart';
import 'package:dakhl_restaurant/catalog/stock_movement_dialog.dart';
import 'package:dakhl_restaurant/catalog/stock_reversal_dialog.dart';
import 'package:dakhl_restaurant/inventory/inventory_commands.dart';
import 'package:dakhl_restaurant/ui/components.dart';

import 'stock_movement_workflow_test.dart' as workflow;
import 'inventory_surface_test.dart' as inventory;

void main() {
  final today = DateOnly.parse(
    '2026-11-07',
    minimumYear: 1000,
    maximumYear: 9999,
  );
  test('catalog identities follow UUIDv4 instead of the wall clock', () {
    final ids = {
      for (var i = 0; i < 500; i++) CatalogFormatters.generateId('p'),
    };
    expect(ids, hasLength(500));
    expect(
      ids.every(
        RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        ).hasMatch,
      ),
      isTrue,
    );
  });

  for (final reversal in [false, true]) {
    testWidgets(
      '${reversal ? 'reversal' : 'movement'} opened before account replacement cannot retarget',
      (tester) async {
        final (repo, accounts, model, shell) = await workflow.setupWorkflow();
        addTearDown(() {
          model.dispose();
          accounts.dispose();
          shell.dispose();
        });
        final product = await workflow.createTestProduct(
          model,
          id: 'p',
          name: 'اختبار',
          openingUnits: BigInt.from(10000),
          asOf: today,
        );
        final original =
            (repo.document!.toJson()['stockEntries'] as List).first
                as Map<String, Object?>;
        await workflow.pumpTestDialog(
          tester,
          reversal
              ? StockReversalDialog(
                  viewModel: model,
                  product: product,
                  originalEntry: original,
                  shell: shell,
                )
              : StockMovementDialog(
                  viewModel: model,
                  product: product,
                  today: today,
                  shell: shell,
                ),
        );
        // Same domain IDs in a replacement account must not confer authority.
        await repo.save(
          repo.codec.decodeJson(repo.document!.toJson()),
          replace: true,
        );
        final before = repo.document;
        final snapshot = repo.snapshot;
        await tester.enterText(
          find.byType(TextFormField).first,
          reversal ? 'تصحيح' : '2',
        );
        final save = find.text(reversal ? 'تسجيل التصحيح' : 'حفظ التغيير');
        await tester.ensureVisible(save);
        await tester.tap(save);
        await tester.pumpAndSettle();
        expect(repo.document, same(before));
        expect(repo.snapshot, snapshot);
        expect(
          find.text(CatalogFormatters.errorMessage('stale_revision')),
          findsOneWidget,
        );
      },
    );
  }

  for (final dismiss in ['close', 'escape', 'back', 'barrier']) {
    testWidgets(
      'dirty product $dismiss dismissal keeps input until confirmed',
      (tester) async {
        final (_, accounts, model, shell) = await workflow.setupWorkflow();
        addTearDown(() {
          model.dispose();
          accounts.dispose();
          shell.dispose();
        });
        await workflow.pumpTestDialog(
          tester,
          Builder(
            builder: (context) => TextButton(
              onPressed: () => showProductCreateDialog(
                context,
                viewModel: model,
                shell: shell,
                today: today,
              ),
              child: const Text('open'),
            ),
          ),
        );
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.widgetWithText(DakhlField, 'اسم الصنف'),
          'مدخل محفوظ في النموذج',
        );
        switch (dismiss) {
          case 'close':
            await tester.tap(find.byTooltip('إغلاق النافذة'));
          case 'escape':
            await tester.sendKeyEvent(LogicalKeyboardKey.escape);
          case 'back':
            await tester.binding.handlePopRoute();
          case 'barrier':
            await tester.tapAt(const Offset(2, 2));
        }
        await tester.pumpAndSettle();
        expect(find.text('هل تريد تجاهل التغييرات؟'), findsOneWidget);
        await tester.tap(find.text('متابعة التعديل'));
        await tester.pumpAndSettle();
        expect(find.text('مدخل محفوظ في النموذج'), findsOneWidget);
        expect(shell.dirtyForm, isTrue);
      },
    );
  }

  testWidgets('archive action cannot retarget after account replacement', (
    tester,
  ) async {
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
    await workflow.pumpTestDialog(
      tester,
      ProductFormDialog(
        viewModel: model,
        productId: 'p',
        shell: shell,
        today: today,
      ),
    );
    await repo.save(
      repo.codec.decodeJson(repo.document!.toJson()),
      replace: true,
    );
    final before = repo.document;
    final snapshot = repo.snapshot;
    final button = find.text('إيقاف الصنف مؤقتاً');
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(repo.document, same(before));
    expect(repo.snapshot, snapshot);
    expect(
      find.text(CatalogFormatters.errorMessage('stale_revision')),
      findsOneWidget,
    );
  });

  testWidgets('stock banner counts all tracked products across pages', (
    tester,
  ) async {
    final (repo, accounts, model) = await inventory.setupCatalog(
      productCount: 120,
    );
    addTearDown(() {
      model.dispose();
      accounts.dispose();
    });
    final raw = Map<String, Object?>.from(repo.document!.toJson());
    raw['stockEntries'] = [
      for (var i = 1; i <= 120; i++)
        {
          'id': 'opening-$i',
          'productId': 'p$i',
          'date': '2026-11-01',
          'kind': 'opening',
          'quantity': 10,
          'note': '',
          'createdAt': '2026-11-01T00:00:00.000Z',
        },
    ];
    await repo.save(repo.codec.decodeJson(raw));
    await accounts.initialize();
    await tester.pumpWidget(
      inventory.buildTestWidget(
        child: InventorySurface(model: model, accounts: accounts, today: today),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('أصناف تحتاج تزويد'), findsNothing);
    final next = find.text('التالي');
    await tester.ensureVisible(next);
    await tester.tap(next);
    await tester.pumpAndSettle();
    expect(find.textContaining('صفحة 2 من 2'), findsOneWidget);
    expect(find.textContaining('أصناف تحتاج تزويد'), findsNothing);
  });

  testWidgets(
    'reversal that would create later negative stock retains input without a write',
    (tester) async {
      final (repo, accounts, model, shell) = await workflow.setupWorkflow();
      addTearDown(() {
        model.dispose();
        accounts.dispose();
        shell.dispose();
      });
      final product = await workflow.createTestProduct(
        model,
        id: 'p',
        name: 'اختبار',
        openingUnits: BigInt.from(5000),
        asOf: today,
      );
      await model.postMovement(
        InventoryMovement(
          id: 'restock',
          productId: 'p',
          quantityUnits: BigInt.from(10000),
          effectiveDate: today,
          kind: StockEntryKind.restock,
          createdAt: '2026-11-07T10:00:00.000Z',
        ),
        session: model.beginEdit(),
      );
      await model.postMovement(
        InventoryMovement(
          id: 'used',
          productId: 'p',
          quantityUnits: BigInt.from(-7000),
          effectiveDate: today,
          kind: StockEntryKind.adjustment,
          note: 'نقص',
          createdAt: '2026-11-07T11:00:00.000Z',
        ),
        session: model.beginEdit(),
      );
      final entry = (repo.document!.toJson()['stockEntries'] as List)
          .cast<Map<String, Object?>>()
          .firstWhere((e) => e['id'] == 'restock');
      final before = repo.document;
      final snapshot = repo.snapshot;
      await workflow.pumpTestDialog(
        tester,
        StockReversalDialog(
          viewModel: model,
          product: product,
          originalEntry: entry,
          shell: shell,
        ),
      );
      await tester.enterText(
        find.byType(TextFormField).first,
        'تصحيح غير صالح',
      );
      final save = find.text('تسجيل التصحيح');
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(repo.document, same(before));
      expect(repo.snapshot, snapshot);
      expect(find.text('تصحيح غير صالح'), findsOneWidget);
      expect(find.byType(DakhlStatus), findsOneWidget);
    },
  );

  testWidgets('invalid product price is rejected instead of saved as zero', (
    tester,
  ) async {
    final (repo, accounts, model, shell) = await workflow.setupWorkflow();
    addTearDown(() {
      model.dispose();
      accounts.dispose();
      shell.dispose();
    });
    await workflow.pumpTestDialog(
      tester,
      ProductFormDialog(
        viewModel: model,
        productId: null,
        shell: shell,
        today: today,
      ),
    );
    await tester.enterText(
      find.widgetWithText(DakhlField, 'اسم الصنف'),
      'اختبار',
    );
    await tester.enterText(
      find.widgetWithText(DakhlField, 'سعر البيع بالدينار · د.ع'),
      'abc',
    );
    final save = find.text('حفظ التغيير');
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(repo.document!.toJson()['products'], isEmpty);
    expect(find.text('abc'), findsOneWidget);
    expect(find.byType(DakhlStatus), findsOneWidget);
  });
}
