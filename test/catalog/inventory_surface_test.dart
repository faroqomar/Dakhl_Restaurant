import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dakhl_restaurant/accounts/accounts_repository.dart';
import 'package:dakhl_restaurant/accounts/accounts_view_model.dart';
import 'package:dakhl_restaurant/catalog/catalog_read_model.dart';
import 'package:dakhl_restaurant/catalog/catalog_view_model.dart';
import 'package:dakhl_restaurant/catalog/inventory_surface.dart';
import 'package:dakhl_restaurant/ui/theme.dart';

import '../accounts/accounts_view_model_test.dart' show FixtureStore;

Widget buildTestWidget({
  required Widget child,
  double width = 1200,
  double height = 800,
  double textScaleFactor = 1.0,
}) => MaterialApp(
  locale: const Locale('ar'),
  supportedLocales: const [Locale('ar')],
  localizationsDelegates: GlobalMaterialLocalizations.delegates,
  theme: DakhlTheme.light,
  home: MediaQuery(
    data: MediaQueryData(
      size: Size(width, height),
      textScaler: TextScaler.linear(textScaleFactor),
    ),
    child: Scaffold(
      body: SizedBox(width: width, height: height, child: child),
    ),
  ),
);

Future<(AccountsRepository, AccountsViewModel, CatalogViewModel)> setupCatalog({
  int productCount = 0,
}) async {
  final store = FixtureStore();
  final repo = AccountsRepository(store: store);
  await repo.open();
  var initialDoc = repo.codec.empty();
  if (productCount > 0) {
    final raw = Map<String, Object?>.from(initialDoc.toJson());
    final products = <Map<String, Object?>>[];
    for (var i = 1; i <= productCount; i++) {
      products.add({
        'id': 'p$i',
        'name': 'صنف اختبار $i',
        'code': 'CODE$i',
        'unit': 'قطعة',
        'group': i % 2 == 0 ? 'مشاوي' : 'مشروبات',
        'price': 1000 * i,
        'minStock': 5,
        'trackStock': true,
        'archived': i > 90, // Some archived
      });
    }
    raw['products'] = products;
    initialDoc = repo.codec.decodeJson(raw);
  }
  await repo.save(initialDoc);
  final accountsVm = AccountsViewModel(repository: repo);
  await accountsVm.initialize();
  final catalogVm = CatalogViewModel(repo);
  return (repo, accountsVm, catalogVm);
}

void main() {
  testWidgets(
    'inventory route displays loading state when accounts are loading',
    (tester) async {
      final store = FixtureStore();
      final repo = AccountsRepository(store: store);
      final accountsVm = AccountsViewModel(repository: repo);
      // Not initialized -> state is loading
      final catalogVm = CatalogViewModel(repo);

      await tester.pumpWidget(
        buildTestWidget(
          child: InventorySurface(model: catalogVm, accounts: accountsVm),
        ),
      );

      expect(find.text('جارٍ تحميل بيانات المخزن…'), findsOneWidget);
      catalogVm.dispose();
      accountsVm.dispose();
    },
  );

  testWidgets(
    'inventory route displays empty-inventory panel when account has 0 products',
    (tester) async {
      final (_, accountsVm, catalogVm) = await setupCatalog(productCount: 0);

      await tester.pumpWidget(
        buildTestWidget(
          child: InventorySurface(model: catalogVm, accounts: accountsVm),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('أضف أول صنف للمخزن'), findsOneWidget);
      expect(
        find.text('سجّل الاسم وسعر البيع والكمية، ويصير جاهز للبيع.'),
        findsOneWidget,
      );
      expect(find.text('إضافة صنف'), findsWidgets);

      catalogVm.dispose();
      accountsVm.dispose();
    },
  );

  testWidgets(
    'inventory route mounts account data, displays table and status badges',
    (tester) async {
      final (_, accountsVm, catalogVm) = await setupCatalog(productCount: 5);

      await tester.pumpWidget(
        buildTestWidget(
          child: InventorySurface(model: catalogVm, accounts: accountsVm),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('المخزن'), findsOneWidget);
      expect(find.text('صنف اختبار 1'), findsOneWidget);
      expect(find.text('صنف اختبار 2'), findsOneWidget);
      expect(find.text('نافد'), findsWidgets); // Stock is 0, minimum is 5

      catalogVm.dispose();
      accountsVm.dispose();
    },
  );

  testWidgets('search filters by name and resets properly', (tester) async {
    final (_, accountsVm, catalogVm) = await setupCatalog(productCount: 10);

    await tester.pumpWidget(
      buildTestWidget(
        child: InventorySurface(model: catalogVm, accounts: accountsVm),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('صنف اختبار 1'), findsOneWidget);
    expect(find.text('صنف اختبار 7'), findsOneWidget);

    // Enter search text
    await tester.enterText(find.byType(TextFormField).first, 'اختبار 7');
    await tester.pumpAndSettle();

    expect(find.text('صنف اختبار 7'), findsOneWidget);
    expect(find.text('صنف اختبار 1'), findsNothing);

    // Click reset filter button
    final resetBtn = find.text('إعادة ضبط التصفية');
    expect(resetBtn, findsOneWidget);
    await tester.tap(resetBtn);
    await tester.pumpAndSettle();

    expect(find.text('صنف اختبار 1'), findsOneWidget);

    catalogVm.dispose();
    accountsVm.dispose();
  });

  testWidgets('pagination handles > 100 products across 50-item pages', (
    tester,
  ) async {
    final (_, accountsVm, catalogVm) = await setupCatalog(productCount: 120);

    await tester.pumpWidget(
      buildTestWidget(
        child: InventorySurface(model: catalogVm, accounts: accountsVm),
      ),
    );
    await tester.pumpAndSettle();

    // Products 1..90 are active, so 90 active products / 50 per page = 2 pages
    expect(find.text('صفحة 1 من 2 (إجمالي 90 صنف)'), findsOneWidget);
    expect(find.text('صنف اختبار 1'), findsOneWidget);

    // Navigate through the actual rendered pager.
    await tester.ensureVisible(find.text('التالي'));
    await tester.tap(find.text('التالي'));
    await tester.pumpAndSettle();

    expect(find.text('صفحة 2 من 2 (إجمالي 90 صنف)'), findsOneWidget);
    expect(find.text('صنف اختبار 51'), findsOneWidget);
    expect(find.text('صنف اختبار 1'), findsNothing);

    // Navigate back to previous page
    await tester.ensureVisible(find.text('السابق'));
    await tester.tap(find.text('السابق'));
    await tester.pumpAndSettle();

    expect(find.text('صفحة 1 من 2 (إجمالي 90 صنف)'), findsOneWidget);
    expect(find.text('صنف اختبار 1'), findsOneWidget);

    catalogVm.dispose();
    accountsVm.dispose();
  });

  testWidgets('status filter selects archived products', (tester) async {
    final (_, accountsVm, catalogVm) = await setupCatalog(productCount: 100);

    await tester.pumpWidget(
      buildTestWidget(
        child: InventorySurface(model: catalogVm, accounts: accountsVm),
      ),
    );
    await tester.pumpAndSettle();

    // Products 91..100 are archived (10 items)
    catalogVm.filter(status: InventoryStatus.archived);
    await tester.pumpAndSettle();

    expect(find.text('صنف اختبار 91'), findsOneWidget);
    expect(find.text('موقوف'), findsWidgets);
    expect(find.text('صنف اختبار 1'), findsNothing);

    catalogVm.dispose();
    accountsVm.dispose();
  });

  testWidgets(
    'responsive layout renders without overflow at 320px width and 200% text scale',
    (tester) async {
      final (_, accountsVm, catalogVm) = await setupCatalog(productCount: 4);

      await tester.pumpWidget(
        buildTestWidget(
          width: 320,
          height: 800,
          textScaleFactor: 2.0,
          child: InventorySurface(model: catalogVm, accounts: accountsVm),
        ),
      );
      await tester.pumpAndSettle();

      // Verify it renders card view on narrow screens
      expect(find.text('المخزن'), findsOneWidget);
      expect(find.text('صنف اختبار 1'), findsOneWidget);
      expect(tester.takeException(), isNull); // Zero layout overflows!

      catalogVm.dispose();
      accountsVm.dispose();
    },
  );
}
