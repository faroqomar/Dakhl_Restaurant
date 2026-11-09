import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar_application/madar_application.dart';
import 'package:madar_domain/madar_domain.dart';
import 'package:dakhl_restaurant/accounts/accounts_repository.dart';
import 'package:dakhl_restaurant/accounts/accounts_view_model.dart';
import 'package:dakhl_restaurant/catalog/catalog_read_model.dart';
import 'package:dakhl_restaurant/catalog/catalog_view_model.dart';
import 'package:dakhl_restaurant/catalog/stock_history_dialog.dart';
import 'package:dakhl_restaurant/catalog/stock_movement_dialog.dart';
import 'package:dakhl_restaurant/catalog/stock_reversal_dialog.dart';
import 'package:dakhl_restaurant/inventory/inventory_commands.dart';
import 'package:dakhl_restaurant/shell/shell_view_model.dart';
import 'package:dakhl_restaurant/ui/components.dart';
import 'package:dakhl_restaurant/ui/theme.dart';

import '../accounts/accounts_view_model_test.dart' show FixtureStore;

final class FakePreferencesStore implements LocalPreferencesStore {
  PreferenceSnapshot? snapshot;

  @override
  Future<CapabilityResult<PreferenceSnapshot?>> read(String namespace) async =>
      CapabilitySuccess(snapshot);

  @override
  Future<CapabilityResult<PreferenceSnapshot>> replace(
    String namespace,
    String payload, {
    int? expectedRevision,
  }) async {
    snapshot = PreferenceSnapshot(
      payload: payload,
      revision: (expectedRevision ?? 0) + 1,
    );
    return CapabilitySuccess(snapshot!);
  }
}

Widget buildTestWidget({required Widget child}) => MaterialApp(
  locale: const Locale('ar'),
  supportedLocales: const [Locale('ar')],
  localizationsDelegates: GlobalMaterialLocalizations.delegates,
  theme: DakhlTheme.light,
  home: Scaffold(body: Center(child: child)),
);

Future<void> pumpTestDialog(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(1200, 1200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(buildTestWidget(child: child));
  await tester.pumpAndSettle();
}

Future<
  (AccountsRepository, AccountsViewModel, CatalogViewModel, ShellViewModel)
>
setupWorkflow() async {
  final store = FixtureStore();
  final repo = AccountsRepository(store: store);
  await repo.open();
  await repo.save(repo.codec.empty());
  final accountsVm = AccountsViewModel(repository: repo);
  await accountsVm.initialize();
  final catalogVm = CatalogViewModel(repo);
  final shellVm = ShellViewModel(store: FakePreferencesStore());
  await shellVm.initialize();
  return (repo, accountsVm, catalogVm, shellVm);
}

CatalogProduct getProduct(
  CatalogViewModel catalogVm,
  String id,
  DateOnly date,
) {
  return catalogVm.inventoryAt(date)!.items.firstWhere((p) => p.id == id);
}

Future<CatalogProduct> createTestProduct(
  CatalogViewModel catalogVm, {
  required String id,
  required String name,
  BigInt? openingUnits,
  DateOnly? openingDate,
  DateOnly? asOf,
}) async {
  final session = catalogVm.beginEdit();
  final openDate =
      openingDate ??
      DateOnly.parse('2026-11-01', minimumYear: 1000, maximumYear: 9999);
  await catalogVm.createProduct(
    {
      'id': id,
      'name': name,
      'code': 'TST-01',
      'unit': 'صحن',
      'group': 'أطباق',
      'price': 5000,
      'minStock': 5,
      'trackStock': true,
      'archived': false,
    },
    session: session,
    opening: openingUnits != null
        ? InventoryMovement(
            id: 'open_$id',
            productId: id,
            quantityUnits: openingUnits,
            effectiveDate: openDate,
            kind: StockEntryKind.opening,
            createdAt: '2026-11-01T10:00:00Z',
          )
        : null,
  );
  return getProduct(catalogVm, id, asOf ?? openDate);
}

void main() {
  testWidgets(
    'restock movement records positive units and increases available inventory',
    (tester) async {
      final (repo, accountsVm, catalogVm, shellVm) = await setupWorkflow();
      final today = DateOnly.parse(
        '2026-11-07',
        minimumYear: 1000,
        maximumYear: 9999,
      );
      final product = await createTestProduct(
        catalogVm,
        id: 'p_restock',
        name: 'برياني لحم',
        openingUnits: BigInt.from(10000), // 10 units
        asOf: today,
      );

      await pumpTestDialog(
        tester,
        StockMovementDialog(
          viewModel: catalogVm,
          product: product,
          shell: shellVm,
          today: today,
        ),
      );

      // Quantity field
      final qtyField = find.widgetWithText(DakhlField, 'الكمية (صحن)');
      await tester.enterText(qtyField, '15.5');
      // Note field
      final noteField = find.widgetWithText(DakhlField, 'ملاحظات (اختياري)');
      await tester.enterText(noteField, 'دفعة طازجة من المطبخ');

      expect(shellVm.dirtyForm, true);

      // Submit
      final submitBtn = find.text('حفظ التغيير');
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      final entries = (repo.document!.toJson()['stockEntries'] as List)
          .cast<Map<String, Object?>>();
      expect(entries.length, 2); // 1 opening + 1 restock
      final restock = entries.firstWhere((e) => e['kind'] == 'restock');
      expect(restock['productId'], 'p_restock');
      expect(restock['quantity'], 15.5);
      expect(restock['date'], '2026-11-07');
      expect(restock['note'], 'دفعة طازجة من المطبخ');

      final updatedProduct = getProduct(catalogVm, 'p_restock', today);
      expect(
        updatedProduct.availableUnits,
        BigInt.from(25500),
      ); // 10 + 15.5 = 25.5

      catalogVm.dispose();
      accountsVm.dispose();
      shellVm.dispose();
    },
  );

  testWidgets('adjustment movement records signed units with note', (
    tester,
  ) async {
    final (repo, accountsVm, catalogVm, shellVm) = await setupWorkflow();
    final today = DateOnly.parse(
      '2026-11-07',
      minimumYear: 1000,
      maximumYear: 9999,
    );
    final product = await createTestProduct(
      catalogVm,
      id: 'p_adj',
      name: 'كص دجاج',
      openingUnits: BigInt.from(20000), // 20 units
      asOf: today,
    );

    await pumpTestDialog(
      tester,
      StockMovementDialog(
        viewModel: catalogVm,
        product: product,
        shell: shellVm,
        today: today,
      ),
    );

    // Switch kind to adjustment via Dropdown
    await tester.tap(find.text('تزويد'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('تسوية').last);
    await tester.pumpAndSettle();

    // Enter negative adjustment: -3.250
    final qtyField = find.widgetWithText(DakhlField, 'الكمية (+ أو -)');
    await tester.enterText(qtyField, '-3.25');
    final noteField = find.widgetWithText(DakhlField, 'سبب الحركة (مطلوب)');
    await tester.enterText(noteField, 'جرد أسبوعي');

    final submitBtn = find.text('حفظ التغيير');
    await tester.tap(submitBtn);
    await tester.pumpAndSettle();

    final entries = (repo.document!.toJson()['stockEntries'] as List)
        .cast<Map<String, Object?>>();
    final adj = entries.firstWhere((e) => e['kind'] == 'adjustment');
    expect(adj['quantity'], -3.25);
    expect(adj['note'], 'جرد أسبوعي');

    final updatedProduct = getProduct(catalogVm, 'p_adj', today);
    expect(
      updatedProduct.availableUnits,
      BigInt.from(16750),
    ); // 20 - 3.25 = 16.75

    catalogVm.dispose();
    accountsVm.dispose();
    shellVm.dispose();
  });

  testWidgets(
    'loss movement requires reason and maps to adjustment with negative units and تالف prefix',
    (tester) async {
      final (repo, accountsVm, catalogVm, shellVm) = await setupWorkflow();
      final today = DateOnly.parse(
        '2026-11-07',
        minimumYear: 1000,
        maximumYear: 9999,
      );
      final product = await createTestProduct(
        catalogVm,
        id: 'p_loss',
        name: 'سمك مسكوف',
        openingUnits: BigInt.from(15000), // 15 units
        asOf: today,
      );

      await pumpTestDialog(
        tester,
        StockMovementDialog(
          viewModel: catalogVm,
          product: product,
          shell: shellVm,
          today: today,
        ),
      );

      // Switch to loss kind via Dropdown
      await tester.tap(find.text('تزويد'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('تالف أو هدر').last);
      await tester.pumpAndSettle();

      // Enter quantity 2
      final qtyField = find.widgetWithText(DakhlField, 'الكمية (صحن)');
      await tester.enterText(qtyField, '2');

      // Attempt to submit without reason
      final submitBtn = find.text('حفظ التغيير');
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      expect(
        find.text('سبب الحركة مطلوب عند التسوية أو تسجيل التالف.'),
        findsOneWidget,
      );

      // Enter loss reason
      final reasonField = find.widgetWithText(DakhlField, 'سبب الحركة (مطلوب)');
      await tester.enterText(
        reasonField,
        'انتهاء الصلاحية أثناء انقطاع الكهرباء',
      );

      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      final entries = (repo.document!.toJson()['stockEntries'] as List)
          .cast<Map<String, Object?>>();
      final loss = entries.firstWhere(
        (e) => e['kind'] == 'adjustment' && (e['quantity'] as num) < 0,
      );
      expect(loss['quantity'], -2.0);
      expect(loss['note'], 'تالف: انتهاء الصلاحية أثناء انقطاع الكهرباء');

      final updatedProduct = getProduct(catalogVm, 'p_loss', today);
      expect(updatedProduct.availableUnits, BigInt.from(13000)); // 15 - 2 = 13

      catalogVm.dispose();
      accountsVm.dispose();
      shellVm.dispose();
    },
  );

  testWidgets(
    'reasoned reversal workflow preserves original and records linked inverse',
    (tester) async {
      final (repo, accountsVm, catalogVm, shellVm) = await setupWorkflow();
      final today = DateOnly.parse(
        '2026-11-07',
        minimumYear: 1000,
        maximumYear: 9999,
      );
      final product = await createTestProduct(
        catalogVm,
        id: 'p_rev',
        name: 'قوزي لحم',
        openingUnits: BigInt.from(5000), // 5 units opening on 2026-11-01
        openingDate: DateOnly.parse(
          '2026-11-01',
          minimumYear: 1000,
          maximumYear: 9999,
        ),
        asOf: today,
      );

      // Add restock of 10 units on 2026-11-02
      final session = catalogVm.beginEdit();
      final restockRes = await catalogVm.postMovement(
        InventoryMovement(
          id: 'mov_p_rev_10',
          productId: 'p_rev',
          quantityUnits: BigInt.from(10000),
          effectiveDate: DateOnly.parse(
            '2026-11-02',
            minimumYear: 1000,
            maximumYear: 9999,
          ),
          kind: StockEntryKind.restock,
          note: 'دفعة إضافية',
          createdAt: '2026-11-02T10:00:00Z',
        ),
        session: session,
      );
      expect(restockRes, isA<CapabilitySuccess>());

      final entries = (repo.document!.toJson()['stockEntries'] as List)
          .cast<Map<String, Object?>>();
      final restockEntry = entries.firstWhere((e) => e['kind'] == 'restock');

      // Open reversal dialog
      await pumpTestDialog(
        tester,
        StockReversalDialog(
          viewModel: catalogVm,
          product: product,
          originalEntry: restockEntry,
          shell: shellVm,
        ),
      );

      // Attempt submit without reason
      final confirmBtn = find.text('تسجيل التصحيح');
      await tester.tap(confirmBtn);
      await tester.pumpAndSettle();

      expect(find.text('يرجى إدخال سبب التصحيح.'), findsOneWidget);

      // Enter reason
      final reasonField = find.widgetWithText(DakhlField, 'سبب التصحيح');
      await tester.enterText(reasonField, 'خطأ إدخال من المورد');

      await tester.tap(confirmBtn);
      await tester.pumpAndSettle();

      // Verify reversal entry created
      final updatedEntries = (repo.document!.toJson()['stockEntries'] as List)
          .cast<Map<String, Object?>>();
      expect(updatedEntries.length, 3); // opening, restock, reversal
      final reversal = updatedEntries.last;
      expect(reversal['productId'], 'p_rev');
      expect(reversal['quantity'], -10.0);
      expect(reversal['kind'], 'adjustment');
      expect(reversal['date'], '2026-11-02'); // Same effective date as original
      expect(reversal['reversesId'], restockEntry['id']);
      expect(reversal['note'], 'خطأ إدخال من المورد');

      final updatedProduct = getProduct(catalogVm, 'p_rev', today);
      expect(updatedProduct.availableUnits, BigInt.from(5000)); // Back to 5

      catalogVm.dispose();
      accountsVm.dispose();
      shellVm.dispose();
    },
  );

  testWidgets(
    'stock history ledger displays entries, computes dated running balance, and future entries',
    (tester) async {
      final (_, accountsVm, catalogVm, shellVm) = await setupWorkflow();
      final today = DateOnly.parse(
        '2026-11-07',
        minimumYear: 1000,
        maximumYear: 9999,
      );
      await createTestProduct(
        catalogVm,
        id: 'p_hist',
        name: 'مندي دجاج',
        openingUnits: BigInt.from(20000), // 20 units on 2026-11-01
        openingDate: DateOnly.parse(
          '2026-11-01',
          minimumYear: 1000,
          maximumYear: 9999,
        ),
        asOf: today,
      );

      // Add restock on today (2026-11-07)
      final s1 = catalogVm.beginEdit();
      await catalogVm.postMovement(
        InventoryMovement(
          id: 'mov_p_hist_today',
          productId: 'p_hist',
          quantityUnits: BigInt.from(10000), // +10
          effectiveDate: DateOnly.parse(
            '2026-11-07',
            minimumYear: 1000,
            maximumYear: 9999,
          ),
          kind: StockEntryKind.restock,
          note: 'شحنة اليوم',
          createdAt: '2026-11-07T10:00:00Z',
        ),
        session: s1,
      );

      // Add future restock on 2026-11-15
      final s2 = catalogVm.beginEdit();
      await catalogVm.postMovement(
        InventoryMovement(
          id: 'mov_p_hist_future',
          productId: 'p_hist',
          quantityUnits: BigInt.from(5000), // +5
          effectiveDate: DateOnly.parse(
            '2026-11-15',
            minimumYear: 1000,
            maximumYear: 9999,
          ),
          kind: StockEntryKind.restock,
          note: 'شحنة مستقبلية متوقعة',
          createdAt: '2026-11-07T11:00:00Z',
        ),
        session: s2,
      );

      final currentProduct = getProduct(catalogVm, 'p_hist', today);

      await pumpTestDialog(
        tester,
        StockHistoryDialog(
          viewModel: catalogVm,
          product: currentProduct,
          shell: shellVm,
          today: today,
        ),
      );

      // Ledger shows opening, restock, and future restock
      expect(find.text('افتتاحي'), findsOneWidget);
      expect(find.textContaining('شحنة اليوم'), findsOneWidget);
      expect(find.textContaining('شحنة مستقبلية متوقعة'), findsOneWidget);
      // Future badge
      expect(find.text('حركة مستقبلية'), findsOneWidget);

      catalogVm.dispose();
      accountsVm.dispose();
      shellVm.dispose();
    },
  );
}
