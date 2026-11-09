import 'dart:convert';

import 'package:dakhl_restaurant/accounts/accounts_repository.dart';
import 'package:dakhl_restaurant/accounts/accounts_view_model.dart';
import 'package:dakhl_restaurant/catalog/catalog_read_model.dart';
import 'package:dakhl_restaurant/catalog/catalog_view_model.dart';
import 'package:dakhl_restaurant/catalog/inventory_surface.dart';
import 'package:dakhl_restaurant/catalog/product_form_dialog.dart';
import 'package:dakhl_restaurant/catalog/stock_history_dialog.dart';
import 'package:dakhl_restaurant/ui/components.dart';
import 'package:dakhl_restaurant/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar_domain/madar_domain.dart';

import '../accounts/accounts_view_model_test.dart' show FixtureStore;

// Connected widget acceptance over the existing in-memory document adapter.
// These assertions do not claim native execution or process-restart durability.
void main() {
  testWidgets(
    'rendered pages survive add and final-page archive before filtering',
    (tester) async {
      _useDesktopViewport(tester);
      final fixture = await _fixture(tester, products: _products(101));
      await _mount(tester, fixture, _date('2026-11-07'));

      _expectProductPage(tester, 1, 3, 101, _names(1, 50));
      await _tap(tester, find.widgetWithText(DakhlButton, 'التالي'));
      _expectProductPage(tester, 2, 3, 101, _names(51, 100));
      await _tap(tester, find.widgetWithText(DakhlButton, 'التالي'));
      _expectProductPage(tester, 3, 3, 101, _names(101, 101));

      // Add through the mounted dialog while the route is on its last page.
      await _tap(tester, find.widgetWithText(DakhlButton, 'إضافة صنف').first);
      expect(find.byType(ProductFormDialog), findsOneWidget);
      await _enter(tester, 'اسم الصنف', _name(102));
      await _enter(tester, 'سعر البيع بالدينار · د.ع', '12000');
      await _tap(tester, find.widgetWithText(DakhlButton, 'حفظ التغيير'));
      expect(find.byType(ProductFormDialog), findsNothing);
      _expectProductPage(tester, 3, 3, 102, _names(101, 102));
      final created = _records(
        fixture.repository,
        'products',
      ).singleWhere((product) => product['name'] == _name(102));
      final createdId = created['id'];
      expect(createdId, isNotEmpty);

      // Archiving both records removes the last page. The displayed page must
      // clamp to the new last page, rather than rendering an empty third page.
      for (final expectedName in _names(101, 102)) {
        await _tap(tester, find.widgetWithText(DakhlButton, 'تعديل').first);
        final nameField = tester.widget<TextFormField>(
          find.descendant(
            of: find.widgetWithText(DakhlField, 'اسم الصنف'),
            matching: find.byType(TextFormField),
          ),
        );
        expect(nameField.controller!.text, expectedName);
        await _tap(
          tester,
          find.widgetWithText(DakhlButton, 'إيقاف الصنف مؤقتاً'),
        );
        expect(
          _records(fixture.repository, 'products').singleWhere(
            (product) => product['name'] == expectedName,
          )['archived'],
          isTrue,
        );
        expect(
          find.widgetWithText(DakhlButton, 'استعادة الصنف للبيع'),
          findsOneWidget,
        );
        await _tap(tester, find.widgetWithText(DakhlButton, 'إلغاء'));
        expect(find.byType(ProductFormDialog), findsNothing);
      }
      _expectProductPage(tester, 2, 2, 100, _names(51, 100));
      final archived = _records(
        fixture.repository,
        'products',
      ).where((product) => product['archived'] == true).toList();
      expect(archived.map((product) => product['name']), _names(101, 102));
      expect(archived.map((product) => product['id']), ['p101', createdId]);

      // Exercise the actual selectors after the last-page mutation.
      await _selectStatus(tester, 'الموقوفة');
      expect(find.byType(DakhlPagination), findsNothing);
      expect(_renderedNames(tester), _names(101, 102));
      expect(fixture.catalog.page, 1);
      await _tap(tester, find.widgetWithText(DakhlButton, 'إعادة ضبط التصفية'));
      _expectProductPage(tester, 1, 2, 100, _names(1, 50));

      await _tap(tester, find.widgetWithText(DakhlButton, 'التالي'));
      await _selectGroup(tester, 'مجموعة زوجية');
      expect(find.byType(DakhlPagination), findsNothing);
      expect(_renderedNames(tester), [
        for (var i = 2; i <= 100; i += 2) _name(i),
      ]);
      expect(fixture.catalog.page, 1);
      await _tap(tester, find.widgetWithText(DakhlButton, 'إعادة ضبط التصفية'));
      await _tap(tester, find.widgetWithText(DakhlButton, 'التالي'));
      await _enter(tester, 'بحث الأصناف', _name(99));
      expect(_renderedNames(tester), [_name(99)]);
      expect(find.byType(DakhlPagination), findsNothing);
      expect(fixture.catalog.page, 1);
      await _tap(tester, find.widgetWithText(DakhlButton, 'إعادة ضبط التصفية'));

      final seen = [..._renderedNames(tester)];
      await _tap(tester, find.widgetWithText(DakhlButton, 'التالي'));
      seen.addAll(_renderedNames(tester));
      expect(seen, _names(1, 100));
      expect(seen.toSet(), hasLength(100));
      final saved = _records(fixture.repository, 'products');
      expect(saved, hasLength(102));
      expect(saved.map((product) => product['id']).toSet(), hasLength(102));
      expect(_records(fixture.repository, 'stockEntries'), isEmpty);
      expect(tester.takeException(), isNull);
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );

  for (final scenario in [
    (date: '2026-11-01', balance: 31, lastEffectiveOrdinal: 40),
    (date: '2026-11-07', balance: 51, lastEffectiveOrdinal: 80),
    (date: '2026-11-08', balance: 71, lastEffectiveOrdinal: 120),
  ]) {
    testWidgets(
      'rendered120-event history reconciles every page as of ${scenario.date}',
      (tester) async {
        _useDesktopViewport(tester);
        final entries = <Map<String, Object?>>[];
        final expectedBalance = <int, int>{};
        var balance = 0;
        for (var ordinal = 1; ordinal <= 120; ordinal++) {
          final quantity = ordinal == 1 ? 10 : (ordinal.isEven ? 2 : -1);
          // This independent fixture oracle uses explicit integer quantities,
          // rather than the app history model or shared query implementation.
          balance += quantity;
          expectedBalance[ordinal] = balance;
          entries.add({
            'id': 'ledger-${ordinal.toString().padLeft(3, '0')}',
            'productId': 'p001',
            'kind': ordinal == 1
                ? 'opening'
                : (quantity > 0 ? 'restock' : 'adjustment'),
            'quantity': quantity,
            'date': ordinal <= 40
                ? '2026-11-01'
                : (ordinal <= 80 ? '2026-11-07' : '2026-11-08'),
            'createdAt': DateTime.utc(
              2026,
              11,
              1,
              0,
              0,
              ordinal,
            ).toIso8601String(),
            'note': 'oracle-event-${ordinal.toString().padLeft(3, '0')}',
          });
        }
        expect(expectedBalance[40], 31);
        expect(expectedBalance[80], 51);
        expect(expectedBalance[120], 71);
        final fixture = await _fixture(
          tester,
          products: _products(1),
          stockEntries: entries,
        );
        await _mount(tester, fixture, _date(scenario.date));
        expect(find.text('${scenario.balance} قطعة'), findsOneWidget);
        await _tap(tester, find.widgetWithText(DakhlButton, 'الحركة'));
        expect(find.byType(StockHistoryDialog), findsOneWidget);

        final seen = <int>[];
        for (var page = 1; page <= 3; page++) {
          final upper = page == 1 ? 120 : (page == 2 ? 70 : 20);
          final lower = page == 1 ? 71 : (page == 2 ? 21 : 1);
          final ordinals = [for (var i = upper; i >= lower; i--) i];
          expect(
            find.text('صفحة $page من 3 (إجمالي 120 حركة)'),
            findsOneWidget,
          );
          final history = find.byType(StockHistoryDialog);
          final tableFinder = find.descendant(
            of: history,
            matching: find.byType(DataTable),
          );
          expect(tableFinder, findsOneWidget);
          final table = tester.widget<DataTable>(tableFinder);
          expect(table.rows, hasLength(ordinals.length));
          final displayedNotes = tester
              .widgetList<Text>(
                find.descendant(
                  of: history,
                  matching: find.textContaining('oracle-event-'),
                ),
              )
              .map((text) => text.data!.trim());
          expect(displayedNotes, [
            for (final ordinal in ordinals)
              '· oracle-event-${ordinal.toString().padLeft(3, '0')}',
          ]);
          // Read the actual rendered table's balance column for each source
          // row. Page2/3 must retain full-ledger context rather than restarting.
          expect(table.rows.map((row) => (row.cells[2].child as Text).data), [
            for (final ordinal in ordinals) '${expectedBalance[ordinal]}',
          ]);
          expect(
            find.descendant(of: history, matching: find.text('حركة مستقبلية')),
            findsNWidgets(
              ordinals
                  .where((ordinal) => ordinal > scenario.lastEffectiveOrdinal)
                  .length,
            ),
          );
          seen.addAll(ordinals);
          expect(tester.takeException(), isNull);
          if (page < 3) {
            await _tap(
              tester,
              find.descendant(
                of: history,
                matching: find.widgetWithText(DakhlButton, 'التالي'),
              ),
            );
          }
        }
        expect(seen, [for (var i = 120; i >= 1; i--) i]);
        expect(seen.toSet(), hasLength(120));
        await _tap(tester, find.widgetWithText(DakhlButton, 'إغلاق'));
        expect(find.byType(StockHistoryDialog), findsNothing);
        expect(find.text('${scenario.balance} قطعة'), findsOneWidget);
        expect(_records(fixture.repository, 'stockEntries'), hasLength(120));
        expect(tester.takeException(), isNull);
      },
      timeout: const Timeout(Duration(seconds: 30)),
    );
  }
}

final class _Fixture {
  _Fixture(this.repository, this.accounts, this.catalog);
  final AccountsRepository repository;
  final AccountsViewModel accounts;
  final CatalogViewModel catalog;
}

Future<_Fixture> _fixture(
  WidgetTester tester, {
  required List<Map<String, Object?>> products,
  List<Map<String, Object?>> stockEntries = const [],
}) async {
  final repository = AccountsRepository(store: FixtureStore());
  await repository.open();
  final raw = jsonDecode(
    jsonEncode(repository.codec.empty().toJson()),
  ) as Map<String, Object?>;
  raw['products'] = products;
  raw['stockEntries'] = stockEntries;
  await repository.save(repository.codec.decodeJson(raw));
  final accounts = AccountsViewModel(repository: repository);
  await accounts.initialize();
  final catalog = CatalogViewModel(repository);
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    catalog.dispose();
    accounts.dispose();
  });
  return _Fixture(repository, accounts, catalog);
}

List<Map<String, Object?>> _products(int count) => [
  for (var i = 1; i <= count; i++)
    {
      'id': 'p${i.toString().padLeft(3, '0')}',
      'name': _name(i),
      'code': 'CODE${i.toString().padLeft(3, '0')}',
      'unit': 'قطعة',
      'group': i.isEven ? 'مجموعة زوجية' : 'مجموعة فردية',
      'price': 1000,
      'minStock': 5,
      'trackStock': true,
      'archived': false,
    },
];

String _name(int ordinal) =>
    'Paging product ${ordinal.toString().padLeft(3, '0')}';
List<String> _names(int first, int last) => [
  for (var i = first; i <= last; i++) _name(i),
];
DateOnly _date(String value) =>
    DateOnly.parse(value, minimumYear: 1000, maximumYear: 9999);

List<Map<String, Object?>> _records(
  AccountsRepository repository,
  String key,
) => (repository.document!.toJson()[key] as List).cast<Map<String, Object?>>();

void _useDesktopViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(1440, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _mount(
  WidgetTester tester,
  _Fixture fixture,
  DateOnly today,
) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: DakhlTheme.light,
      home: Scaffold(
        body: InventorySurface(
          model: fixture.catalog,
          accounts: fixture.accounts,
          today: today,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

List<String> _renderedNames(WidgetTester tester) => tester
    .widgetList<Text>(
      find.byWidgetPredicate(
        (widget) =>
            widget is Text &&
            (widget.data?.startsWith('Paging product ') ?? false),
      ),
    )
    .map((text) => text.data!)
    .toList();

void _expectProductPage(
  WidgetTester tester,
  int page,
  int pageCount,
  int total,
  List<String> names,
) {
  expect(
    find.text('صفحة $page من $pageCount (إجمالي $total صنف)'),
    findsOneWidget,
  );
  expect(_renderedNames(tester), names);
  expect(tester.takeException(), isNull);
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  expect(finder, findsOneWidget);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  expect(finder.hitTestable(), findsOneWidget);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _enter(WidgetTester tester, String label, String value) async {
  final finder = find.widgetWithText(DakhlField, label);
  expect(finder, findsOneWidget);
  await tester.ensureVisible(finder);
  await tester.enterText(finder, value);
  await tester.pumpAndSettle();
}

Future<void> _selectStatus(WidgetTester tester, String label) async {
  await _tap(
    tester,
    find.byWidgetPredicate(
      (widget) =>
          widget is DakhlSelect<InventoryStatus> && widget.label == 'الحالة',
    ),
  );
  await _tap(tester, find.text(label).last);
}

Future<void> _selectGroup(WidgetTester tester, String label) async {
  await _tap(
    tester,
    find.byWidgetPredicate(
      (widget) => widget is DakhlSelect<String> && widget.label == 'المجموعة',
    ),
  );
  await _tap(tester, find.text(label).last);
}
