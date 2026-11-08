import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar_application/madar_application.dart';
import 'package:madar_domain/madar_domain.dart';
import 'package:dakhl_restaurant/accounts/accounts_repository.dart';
import 'package:dakhl_restaurant/accounts/accounts_view_model.dart';
import 'package:dakhl_restaurant/catalog/catalog_view_model.dart';
import 'package:dakhl_restaurant/catalog/product_form_dialog.dart';
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

Widget buildDialogTestWidget({required Widget child}) => MaterialApp(
  locale: const Locale('ar'),
  supportedLocales: const [Locale('ar')],
  localizationsDelegates: GlobalMaterialLocalizations.delegates,
  theme: DakhlTheme.light,
  home: Scaffold(body: Center(child: child)),
);

Future<void> pumpDialog(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(1000, 1200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(buildDialogTestWidget(child: child));
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

void main() {
  testWidgets(
    'create product with reference photo, unit, price and opening movement persists atomically',
    (tester) async {
      final (repo, accountsVm, catalogVm, shellVm) = await setupWorkflow();

      await pumpDialog(
        tester,
        ProductFormDialog(
          viewModel: catalogVm,
          productId: null, // New product
          shell: shellVm,
          today: DateOnly.parse(
            '2026-11-07',
            minimumYear: 1000,
            maximumYear: 9999,
          ),
        ),
      );

      // Fill form fields
      final fields = find.byType(TextFormField);
      // Field 0: Name
      await tester.enterText(fields.at(0), 'كباب غنم ممتاز');
      // Field 1: Code
      await tester.enterText(fields.at(1), 'KB-01');
      // Field 2: Unit
      await tester.enterText(fields.at(2), 'نفر');
      // Field 3: Group
      await tester.enterText(fields.at(3), 'مشاوي');
      // Field 4: Price
      await tester.enterText(fields.at(4), '14,000');
      // Field 5: Opening Qty
      await tester.enterText(fields.at(5), '25');
      // Field 6: Opening Date
      await tester.enterText(fields.at(6), '2026-11-07');
      // Field 7: Min Stock
      await tester.enterText(fields.at(7), '5');

      // Select reference photo: beef-kebab
      final beefPhoto = find.bySemanticsLabel('اختيار صورة كباب لحم');
      expect(beefPhoto, findsOneWidget);
      await tester.tap(beefPhoto);
      await tester.pumpAndSettle();

      // Verify photo preview label updated
      expect(find.text('الصورة المختارة: كباب لحم'), findsOneWidget);
      expect(shellVm.dirtyForm, true);

      // Save product
      final saveBtn = find.text('حفظ التغيير');
      await tester.tap(saveBtn);
      await tester.pumpAndSettle();

      // Verify product and opening movement saved in repository
      final doc = repo.document!;
      final products = (doc.toJson()['products'] as List)
          .cast<Map<String, Object?>>();
      final entries = (doc.toJson()['stockEntries'] as List)
          .cast<Map<String, Object?>>();

      expect(products.length, 1);
      expect(products.first['name'], 'كباب غنم ممتاز');
      expect(products.first['photo'], 'beef-kebab');
      expect(products.first['unit'], 'نفر');
      expect(products.first['price'], 14000);

      expect(entries.length, 1);
      expect(entries.first['productId'], products.first['id']);
      expect(entries.first['quantity'], 25);
      expect(entries.first['kind'], 'opening');
      expect(entries.first['date'], '2026-11-07');

      catalogVm.dispose();
      accountsVm.dispose();
      shellVm.dispose();
    },
  );

  testWidgets(
    'edit product locks unit and trackStock when stock history exists',
    (tester) async {
      final (repo, accountsVm, catalogVm, shellVm) = await setupWorkflow();

      // Create a product with opening stock so it has history
      final session = catalogVm.beginEdit();
      final res = await catalogVm.createProduct(
        {
          'id': 'p_locked',
          'name': 'دجاج مشوي قديم',
          'code': 'CK-01',
          'unit': 'كيلو',
          'group': 'دجاج',
          'price': 10000,
          'minStock': 3,
          'trackStock': true,
          'archived': false,
        },
        session: session,
        opening: InventoryMovement(
          id: 'open_ck',
          productId: 'p_locked',
          quantityUnits: BigInt.from(10000), // 10 units
          effectiveDate: DateOnly.parse(
            '2026-11-01',
            minimumYear: 1000,
            maximumYear: 9999,
          ),
          kind: StockEntryKind.opening,
          createdAt: '2026-11-01T10:00:00Z',
        ),
      );
      expect(res, isA<CapabilitySuccess>());

      // Open edit dialog
      await pumpDialog(
        tester,
        ProductFormDialog(
          viewModel: catalogVm,
          productId: 'p_locked',
          shell: shellVm,
          today: DateOnly.parse(
            '2026-11-07',
            minimumYear: 1000,
            maximumYear: 9999,
          ),
        ),
      );

      // Verify history lock messages appear
      expect(find.text('الوحدة ثابتة لوجود حركات سابقة'), findsOneWidget);
      expect(
        find.text('التتبّع ثابت لوجود حركات أو مبيعات مسجلة.'),
        findsOneWidget,
      );

      // Verify unit field is disabled
      final unitField = find.widgetWithText(DakhlField, 'الوحدة');
      expect(unitField, findsOneWidget);
      final fieldWidget = tester.widget<DakhlField>(unitField);
      expect(fieldWidget.enabled, false);

      catalogVm.dispose();
      accountsVm.dispose();
      shellVm.dispose();
    },
  );

  testWidgets(
    'validation failure retains input and displays Arabic error banner',
    (tester) async {
      final (_, accountsVm, catalogVm, shellVm) = await setupWorkflow();

      await pumpDialog(
        tester,
        ProductFormDialog(
          viewModel: catalogVm,
          productId: null,
          shell: shellVm,
          today: DateOnly.parse(
            '2026-11-07',
            minimumYear: 1000,
            maximumYear: 9999,
          ),
        ),
      );

      // Leave name empty and tap save
      final saveBtn = find.text('حفظ التغيير');
      await tester.tap(saveBtn);
      await tester.pumpAndSettle();

      expect(find.text('اسم الصنف مطلوب.'), findsOneWidget);

      // Enter name and negative price
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'شوربة عدس');
      await tester.enterText(fields.at(4), '-500');
      await tester.tap(saveBtn);
      await tester.pumpAndSettle();

      expect(find.text('سعر البيع لا يمكن أن يكون سالباً.'), findsOneWidget);
      // Name is retained
      expect(find.text('شوربة عدس'), findsOneWidget);

      catalogVm.dispose();
      accountsVm.dispose();
      shellVm.dispose();
    },
  );

  testWidgets('archive and restore product toggles status correctly', (
    tester,
  ) async {
    final (repo, accountsVm, catalogVm, shellVm) = await setupWorkflow();

    final session = catalogVm.beginEdit();
    await catalogVm.createProduct({
      'id': 'p_toggle',
      'name': 'شاي مهيل',
      'code': 'TEA',
      'unit': 'استكان',
      'group': 'مشروبات',
      'price': 1000,
      'minStock': 0,
      'trackStock': false,
      'archived': false,
    }, session: session);

    // Open edit dialog
    await pumpDialog(
      tester,
      ProductFormDialog(
        viewModel: catalogVm,
        productId: 'p_toggle',
        shell: shellVm,
        today: DateOnly.parse(
          '2026-11-07',
          minimumYear: 1000,
          maximumYear: 9999,
        ),
      ),
    );

    // Tap archive button
    final archiveBtn = find.text('إيقاف الصنف مؤقتاً');
    expect(archiveBtn, findsOneWidget);
    await tester.tap(archiveBtn);
    await tester.pumpAndSettle();

    // Verify it is archived in repo
    final product = (repo.document!.toJson()['products'] as List)
        .cast<Map<String, Object?>>()
        .first;
    expect(product['archived'], true);
    expect(find.text('استعادة الصنف للبيع'), findsOneWidget);

    // Tap restore button
    final restoreBtn = find.text('استعادة الصنف للبيع');
    await tester.tap(restoreBtn);
    await tester.pumpAndSettle();

    final productRestored = (repo.document!.toJson()['products'] as List)
        .cast<Map<String, Object?>>()
        .first;
    expect(productRestored['archived'], false);

    catalogVm.dispose();
    accountsVm.dispose();
    shellVm.dispose();
  });

  testWidgets(
    'photo removal updates draft to null and persists without photo',
    (tester) async {
      final (repo, accountsVm, catalogVm, shellVm) = await setupWorkflow();

      final session = catalogVm.beginEdit();
      await catalogVm.createProduct({
        'id': 'p_photo',
        'name': 'ماء معدني',
        'code': 'WAT',
        'unit': 'قنينة',
        'group': 'مشروبات',
        'price': 500,
        'photo': 'water',
        'minStock': 10,
        'trackStock': true,
        'archived': false,
      }, session: session);

      // Open edit dialog
      await pumpDialog(
        tester,
        ProductFormDialog(
          viewModel: catalogVm,
          productId: 'p_photo',
          shell: shellVm,
          today: DateOnly.parse(
            '2026-11-07',
            minimumYear: 1000,
            maximumYear: 9999,
          ),
        ),
      );

      expect(find.text('الصورة المختارة: ماء'), findsOneWidget);

      // Tap "بدون صورة"
      final noPhoto = find.bySemanticsLabel('بدون صورة');
      expect(noPhoto, findsOneWidget);
      await tester.tap(noPhoto);
      await tester.pumpAndSettle();

      expect(find.text('بدون صورة مرجعية'), findsOneWidget);

      // Save
      await tester.tap(find.text('حفظ التغيير'));
      await tester.pumpAndSettle();

      final product = (repo.document!.toJson()['products'] as List)
          .cast<Map<String, Object?>>()
          .first;
      expect(product['photo'], isNull);

      catalogVm.dispose();
      accountsVm.dispose();
      shellVm.dispose();
    },
  );
}
