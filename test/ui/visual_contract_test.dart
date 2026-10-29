@Tags(['golden'])
library;

import 'package:dakhl_restaurant/ui/dakhl_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

// Initial Phase01 baselines: macOS host, Flutter3.47.8 engine cf636b1dfb,
// 1 logical pixel/device pixel, locale ar, bundled Amiri/Inter, no font download.
// Changes require visual review; CI compares only and never updates these files.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    await (FontLoader(
      'Amiri',
    )..addFont(rootBundle.load('assets/fonts/Amiri-Regular.ttf'))).load();
    await (FontLoader(
      'Inter',
    )..addFont(rootBundle.load('assets/fonts/Inter.ttf'))).load();
  });
  Widget host(Widget child, {double scale = 1}) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: DakhlTheme.light,
    locale: const Locale('ar'),
    supportedLocales: const [Locale('ar')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(scale), disableAnimations: true),
      child: child!,
    ),
    home: Scaffold(
      body: RepaintBoundary(
        key: const ValueKey('golden-surface'),
        child: ColoredBox(color: DakhlTokens.background, child: child),
      ),
    ),
  );
  void size(WidgetTester tester, Size size) {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('controlled component states and focused field', (tester) async {
    size(tester, const Size(900, 760));
    final focus = FocusNode();
    addTearDown(focus.dispose);
    await tester.pumpWidget(
      host(
        Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'المكونات وحالات التفاعل',
                style: DakhlTheme.light.textTheme.headlineMedium,
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: DakhlPanel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          DakhlField(
                            label: 'المبلغ · دينار عراقي',
                            kind: DakhlFieldKind.money,
                            initialValue: '25,000',
                            focusNode: focus,
                          ),
                          const DakhlField(
                            label: 'التاريخ',
                            kind: DakhlFieldKind.date,
                            initialValue: '2026/10/27',
                          ),
                          const DakhlField(
                            label: 'قيمة غير صالحة',
                            initialValue: 'غير صالح',
                            errorText: 'يرجى مراجعة القيمة',
                          ),
                          const DakhlButton(label: 'غير متاح'),
                          const SizedBox(height: 12),
                          DakhlButton(
                            label: 'حفظ التغييرات',
                            kind: DakhlButtonKind.primary,
                            onPressed: () {},
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const DakhlStatus(
                          message: 'محفوظ على جهازك',
                          kind: DakhlStatusKind.saved,
                        ),
                        const SizedBox(height: 12),
                        const DakhlStatus(
                          message: 'جارٍ الحفظ...',
                          kind: DakhlStatusKind.saving,
                        ),
                        const SizedBox(height: 12),
                        DakhlStatus(
                          message: 'تعذر الحفظ. أعد المحاولة.',
                          kind: DakhlStatusKind.error,
                          onRetry: () {},
                          onCancel: () {},
                        ),
                        const SizedBox(height: 12),
                        const DakhlEmptyState(),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const DakhlTable(
                columns: ['التاريخ', 'البيان', 'المبلغ · د.ع'],
                numericColumns: {0, 2},
                rows: [
                  ['2026/10/27', 'بيان توضيحي', '125,000'],
                ],
              ),
            ],
          ),
        ),
      ),
    );
    focus.requestFocus();
    await tester.pump(const Duration(milliseconds: 250));
    // Hide the editable cursor while retaining the focused border contract.
    await tester.pump(const Duration(milliseconds: 250));
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byKey(const ValueKey('golden-surface')),
      matchesGoldenFile('goldens/controls-900.png'),
    );
  });
  testWidgets('controlled 390px invoice dialog', (tester) async {
    size(tester, const Size(390, 844));
    await tester.pumpWidget(
      host(const Phase01RouteSurface(routeId: 'invoices')),
    );
    await tester.tap(find.text('قائمة جديدة'));
    await tester.pumpAndSettle();
    expect(find.text('137,500'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/invoice-390.png'),
    );
  });
  testWidgets('controlled desktop sales composition', (tester) async {
    size(tester, const Size(1440, 1000));
    await tester.pumpWidget(
      host(
        DakhlShellView(
          routeId: 'sales',
          shortcuts: const [
            'sales',
            'inventory',
            'sale-history',
            'expenses',
            'cash',
            'settings',
          ],
          destinations: [
            for (final e in Phase01RouteSurface.labels.entries)
              DakhlDestination(id: e.key, label: e.value, group: 'العمل'),
          ],
          onNavigate: (_) {},
          child: Phase01RouteSurface(routeId: 'sales', onTicketChanged: (_) {}),
        ),
      ),
    );
    await tester.runAsync(() async {
      final context = tester.element(find.byType(DakhlSalesExample));
      for (final item in phase01CatalogFixture) {
        await precacheImage(AssetImage(item.photoAsset), context);
      }
    });
    await tester.pumpAndSettle();
    expect(find.text('25,000'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byKey(const ValueKey('golden-surface')),
      matchesGoldenFile('goldens/sales-1440.png'),
    );
  });

  testWidgets('controlled 320px invoice at 200 percent retains actions', (
    tester,
  ) async {
    size(tester, const Size(320, 700));
    await tester.pumpWidget(
      host(const Phase01RouteSurface(routeId: 'invoices'), scale: 2),
    );
    await tester.tap(find.text('قائمة جديدة'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('إلغاء'));
    await tester.pumpAndSettle();
    expect(find.text('حفظ القائمة والتسديد').hitTestable(), findsOneWidget);
    expect(find.text('إلغاء').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/invoice-320-200.png'),
    );
  });

  testWidgets(
    'controlled desktop open navigation preserves source identity and icons',
    (tester) async {
      size(tester, const Size(1440, 1000));
      // Render the actual popover shadow rather than the widget-test hard edge.
      final previousShadows = debugDisableShadows;
      debugDisableShadows = false;
      try {
        const destinations = [
          DakhlDestination(
            id: 'sales',
            label: 'المبيعات',
            group: 'البيع والمخزن',
          ),
          DakhlDestination(
            id: 'sale-history',
            label: 'سجل المبيعات',
            group: 'البيع والمخزن',
          ),
          DakhlDestination(
            id: 'inventory',
            label: 'المخزن',
            group: 'البيع والمخزن',
          ),
          DakhlDestination(
            id: 'suppliers',
            label: 'الموردون',
            group: 'المشتريات والموردون',
          ),
          DakhlDestination(
            id: 'invoices',
            label: 'فواتير المشتريات',
            group: 'المشتريات والموردون',
          ),
          DakhlDestination(
            id: 'materials',
            label: 'المواد والأسعار',
            group: 'المشتريات والموردون',
          ),
          DakhlDestination(
            id: 'payments',
            label: 'التسديدات',
            group: 'المشتريات والموردون',
          ),
          DakhlDestination(
            id: 'expenses',
            label: 'المصاريف اليومية',
            group: 'الحسابات',
          ),
          DakhlDestination(
            id: 'statement',
            label: 'كشف الحساب',
            group: 'الحسابات',
          ),
          DakhlDestination(id: 'cash', label: 'القاصة', group: 'الحسابات'),
          DakhlDestination(
            id: 'categories',
            label: 'الخانات',
            group: 'الإدارة',
          ),
          DakhlDestination(
            id: 'settings',
            label: 'الإعدادات',
            navigationLabel: 'الإعدادات والنسخ',
            group: 'الإدارة',
          ),
        ];
        await tester.pumpWidget(
          host(
            DakhlShellView(
              routeId: 'sales',
              shortcuts: const [
                'sales',
                'inventory',
                'sale-history',
                'expenses',
                'cash',
                'settings',
              ],
              destinations: destinations,
              onNavigate: (_) {},
              child: Phase01RouteSurface(
                routeId: 'sales',
                onTicketChanged: (_) {},
              ),
            ),
          ),
        );
        await tester.runAsync(() async {
          final context = tester.element(find.byType(DakhlSalesExample));
          for (final item in phase01CatalogFixture) {
            await precacheImage(AssetImage(item.photoAsset), context);
          }
        });
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('القائمة الرئيسية'));
        await tester.pumpAndSettle();
        expect(find.text('دفتر'), findsOneWidget);
        expect(find.text('حسابات المطعم'), findsOneWidget);
        expect(find.text('الإعدادات والنسخ').hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/navigation-open-1440.png'),
        );
      } finally {
        debugDisableShadows = previousShadows;
      }
    },
  );
}
