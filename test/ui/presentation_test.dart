import 'package:dakhl_restaurant/ui/dakhl_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

Widget host(Widget child, {double scale = 1}) => MaterialApp(
  theme: DakhlTheme.light,
  locale: const Locale('ar'),
  supportedLocales: const [Locale('ar')],
  localizationsDelegates: GlobalMaterialLocalizations.delegates,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: child!,
  ),
  home: Scaffold(body: child),
);

void main() {
  testWidgets('invalid values and busy actions announce state, retain input', (
    tester,
  ) async {
    var taps = 0;
    final controller = TextEditingController(text: '25,000');
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      host(
        Column(
          children: [
            DakhlField(
              label: 'المبلغ',
              controller: controller,
              kind: DakhlFieldKind.money,
              errorText: 'يرجى مراجعة القيمة',
            ),
            DakhlButton(
              label: 'حفظ التغييرات',
              busy: true,
              onPressed: () => taps++,
            ),
            const DakhlStatus(
              message: 'تعذر الحفظ. أعد المحاولة.',
              kind: DakhlStatusKind.error,
            ),
          ],
        ),
      ),
    );
    expect(find.text('يرجى مراجعة القيمة'), findsOneWidget);
    expect(find.text('25,000'), findsOneWidget);
    await tester.tap(find.byType(DakhlButton));
    expect(taps, 0);
    expect(find.bySemanticsLabel(RegExp('جار.*حفظ')), findsWidgets);
    expect(find.text('تعذر الحفظ. أعد المحاولة.'), findsOneWidget);
  });

  testWidgets(
    'hidden menu has no semantics; Escape dismisses and restores opener',
    (tester) async {
      await tester.pumpWidget(
        host(
          DakhlShellView(
            routeId: 'sales',
            shortcuts: const ['sales', '', '', '', '', 'settings'],
            destinations: const [
              DakhlDestination(id: 'sales', label: 'المبيعات', group: 'العمل'),
              DakhlDestination(
                id: 'settings',
                label: 'الإعدادات',
                group: 'الإدارة',
              ),
              DakhlDestination(
                id: 'invoices',
                label: 'قوائم الشراء',
                group: 'العمل',
              ),
            ],
            onNavigate: (_) {},
            child: const Text('محتوى تجريبي'),
          ),
        ),
      );
      expect(find.text('قوائم الشراء'), findsNothing);
      await tester.tap(find.byTooltip('القائمة الرئيسية'));
      await tester.pumpAndSettle();
      expect(find.text('قوائم الشراء'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text('قوائم الشراء'), findsNothing);
      expect(
        FocusManager.instance.primaryFocus?.debugLabel,
        'main-menu-opener',
      );
    },
  );

  testWidgets(
    '320 wide 200 percent dialog keeps save and cancel reachable with keyboard',
    (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        host(
          Builder(
            builder: (context) => Center(
              child: DakhlButton(
                label: 'فتح',
                onPressed: () => showDakhlDialog<void>(
                  context: context,
                  title: 'قائمة جديدة',
                  wide: true,
                  body: const Column(
                    children: [
                      DakhlField(label: 'المورد'),
                      DakhlField(label: 'رقم القائمة'),
                      DakhlField(
                        label: 'تاريخ القائمة',
                        kind: DakhlFieldKind.date,
                      ),
                      DakhlField(label: 'المادة'),
                      DakhlField(
                        label: 'الكمية',
                        kind: DakhlFieldKind.quantity,
                      ),
                    ],
                  ),
                  actions: [
                    DakhlButton(label: 'حفظ', onPressed: () {}),
                    DakhlButton(
                      label: 'إلغاء',
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
            ),
          ),
          scale: 2,
        ),
      );
      await tester.tap(find.text('فتح'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('حفظ'));
      await tester.pumpAndSettle();
      expect(find.text('حفظ').hitTestable(), findsOneWidget);
      await tester.ensureVisible(find.text('إلغاء'));
      expect(find.text('إلغاء').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('discard cancellation preserves current form', (tester) async {
    bool? result;
    await tester.pumpWidget(
      host(
        Builder(
          builder: (context) => DakhlButton(
            label: 'مغادرة',
            onPressed: () async {
              result = await showDakhlDiscardDialog(context);
            },
          ),
        ),
      ),
    );
    await tester.tap(find.text('مغادرة'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('متابعة التعديل'));
    await tester.pumpAndSettle();
    expect(result, false);
  });

  testWidgets('sales catalog stays left and bill right on desktop', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(host(const Phase01RouteSurface(routeId: 'sales')));
    expect(
      tester.getCenter(find.byKey(const ValueKey('sales-catalog'))).dx,
      lessThan(tester.getCenter(find.byKey(const ValueKey('sales-bill'))).dx),
    );
    expect(find.text('25,000'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dialog focus cycles inside modal and returns after Escape', (
    tester,
  ) async {
    final opener = FocusNode(debugLabel: 'dialog-opener');
    final inside = FocusNode(debugLabel: 'inside-field');
    addTearDown(opener.dispose);
    addTearDown(inside.dispose);
    await tester.pumpWidget(
      host(
        Builder(
          builder: (context) => DakhlButton(
            label: 'فتح نافذة',
            focusNode: opener,
            onPressed: () => showDakhlDialog<void>(
              context: context,
              title: 'نافذة',
              body: DakhlField(
                label: 'اسم',
                focusNode: inside,
                autofocus: true,
              ),
              actions: [DakhlButton(label: 'حفظ', onPressed: () {})],
            ),
          ),
        ),
      ),
    );
    opener.requestFocus();
    await tester.tap(find.text('فتح نافذة'));
    await tester.pumpAndSettle();
    for (var i = 0; i < 8; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(opener.hasFocus, isFalse);
    }
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(opener.hasFocus, isTrue);
  });

  testWidgets(
    'keyboard insets leave invoice actions reachable and input intact',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      var values = <String, String>{};
      await tester.pumpWidget(
        host(
          Phase01RouteSurface(
            routeId: 'invoices',
            onFormChanged: (v) => values = v,
          ),
        ),
      );
      await tester.tap(find.text('قائمة جديدة'));
      await tester.pumpAndSettle();
      final material = find.widgetWithText(
        TextFormField,
        'اختار أو اكتب اسم المادة',
      );
      await tester.ensureVisible(material);
      await tester.enterText(material, 'مادة توضيحية');
      tester.view.viewInsets = const FakeViewPadding(bottom: 276);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('حفظ القائمة والتسديد'));
      await tester.pumpAndSettle();
      expect(find.text('حفظ القائمة والتسديد').hitTestable(), findsOneWidget);
      expect(
        tester.getBottomRight(find.text('حفظ القائمة والتسديد')).dy,
        lessThan(844 - 276),
      );
      await tester.ensureVisible(find.text('إلغاء'));
      await tester.tap(find.text('إلغاء'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('متابعة التعديل'));
      await tester.tap(find.text('متابعة التعديل'));
      await tester.pumpAndSettle();
      expect(values['material'], 'مادة توضيحية');
      expect(find.byType(DakhlDialog), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('narrow and desktop sales and gallery have no layout overflow', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1;
    for (final size in [
      const Size(390, 844),
      const Size(1024, 768),
      const Size(1920, 1080),
      const Size(320, 700),
    ]) {
      tester.view.physicalSize = size;
      final scale = size.width == 320 ? 2.0 : 1.0;
      await tester.pumpWidget(
        host(const Phase01RouteSurface(routeId: 'sales'), scale: scale),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('تأكيد البيع النقدي'));
      expect(find.text('تأكيد البيع النقدي').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull, reason: '$size sales');
      await tester.pumpWidget(
        host(const Phase01ComponentGallery(), scale: scale),
      );
      await tester.pump(const Duration(milliseconds: 250));
      expect(tester.takeException(), isNull, reason: '$size gallery');
    }
  });

  testWidgets('shortcut editor preserves duplicates and empty choices', (
    tester,
  ) async {
    var saved = false;
    var choices = ['sales', 'sales', '', 'sales', '', 'settings'];
    await tester.pumpWidget(
      host(
        StatefulBuilder(
          builder: (context, setState) => SingleChildScrollView(
            child: DakhlShortcutEditor(
              choices: choices,
              destinations: const [
                DakhlDestination(
                  id: 'sales',
                  label: 'المبيعات',
                  group: 'العمل',
                ),
                DakhlDestination(
                  id: 'settings',
                  label: 'الإعدادات',
                  group: 'الإدارة',
                ),
              ],
              onChanged: (i, value) => setState(() {
                choices = [...choices]..[i] = value;
              }),
              onSave: () => saved = true,
              onCancel: () {},
            ),
          ),
        ),
      ),
    );
    expect(find.text('المبيعات'), findsWidgets);
    await tester.ensureVisible(find.text('حفظ الاختصارات'));
    await tester.tap(find.text('حفظ الاختصارات'));
    expect(saved, isTrue);
    expect(choices, ['sales', 'sales', '', 'sales', '', 'settings']);
  });

  testWidgets(
    'complete six-shortcut shell remains usable at 320 and 200 percent',
    (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
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
            onEditShortcuts: () {},
            onUndo: () {},
            child: const Phase01RouteSurface(routeId: 'sales'),
          ),
          scale: 2,
        ),
      );
      await tester.pump(const Duration(milliseconds: 250));
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('تأكيد البيع النقدي'));
      expect(find.text('تأكيد البيع النقدي').hitTestable(), findsOneWidget);
    },
  );

  testWidgets('icon-only control exposes a named button and 44px target', (
    tester,
  ) async {
    var tapped = false;
    await tester.pumpWidget(
      host(
        Center(
          child: DakhlIconButton(
            label: 'القائمة الرئيسية',
            icon: DakhlIconKind.menu,
            onPressed: () => tapped = true,
          ),
        ),
      ),
    );
    final semantics = tester.getSemantics(
      find.bySemanticsLabel('القائمة الرئيسية').first,
    );
    expect(semantics.getSemanticsData().flagsCollection.isButton, isTrue);
    expect(
      tester.getSize(find.byType(DakhlIconButton)).shortestSide,
      greaterThanOrEqualTo(44),
    );
    await tester.tap(find.byType(DakhlIconButton));
    expect(tapped, isTrue);
  });

  testWidgets('quantity stepper emits intent without doing money arithmetic', (
    tester,
  ) async {
    var step = 0;
    var value = '';
    await tester.pumpWidget(
      host(
        Center(
          child: SizedBox(
            width: 200,
            child: DakhlQuantityControl(
              label: 'كمية كباب لحم',
              value: '2',
              onChanged: (v) => value = v,
              onStep: (delta) => step = delta,
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.bySemanticsLabel('زيادة كمية كباب لحم').first);
    expect(step, 1);
    await tester.tap(find.bySemanticsLabel('تقليل كمية كباب لحم').first);
    expect(step, -1);
    await tester.enterText(find.byType(TextFormField), '3');
    expect(value, '3');
  });

  test('page gutter follows narrow source boundary through 760', () {
    expect(DakhlTokens.gutter(700), 14);
    expect(DakhlTokens.gutter(760), 14);
    expect(DakhlTokens.gutter(761), 24);
  });

  testWidgets(
    'desktop shortcut hints preserve slot numbers and hide on narrow',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final shell = DakhlShellView(
        routeId: 'sales',
        shortcuts: const ['sales', '', 'inventory', '', '', 'settings'],
        destinations: const [
          DakhlDestination(id: 'sales', label: 'المبيعات', group: 'العمل'),
          DakhlDestination(id: 'inventory', label: 'المخزن', group: 'العمل'),
          DakhlDestination(
            id: 'settings',
            label: 'الإعدادات',
            group: 'الإدارة',
          ),
        ],
        onNavigate: (_) {},
        child: const SizedBox(),
      );
      tester.view.physicalSize = const Size(1440, 1000);
      await tester.pumpWidget(host(shell));
      expect(find.text('⌘1'), findsOneWidget);
      expect(find.text('⌘3'), findsOneWidget);
      expect(find.text('⌘6'), findsOneWidget);
      expect(find.text('⌘2'), findsNothing);
      tester.view.physicalSize = const Size(760, 844);
      await tester.pump();
      expect(find.text('⌘1'), findsNothing);
      expect(find.text('المبيعات'), findsOneWidget);
    },
  );

  testWidgets('popover restores frozen brand subtitle and route icon paths', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        DakhlShellView(
          routeId: 'sales',
          shortcuts: const ['sales'],
          destinations: const [
            DakhlDestination(
              id: 'sales',
              label: 'المبيعات',
              group: 'البيع والمخزن',
            ),
            DakhlDestination(
              id: 'settings',
              label: 'الإعدادات',
              navigationLabel: 'الإعدادات والنسخ',
              group: 'الإدارة',
            ),
          ],
          onNavigate: (_) {},
          child: const SizedBox(),
        ),
      ),
    );
    await tester.tap(find.byTooltip('القائمة الرئيسية'));
    await tester.pumpAndSettle();
    expect(find.text('دفتر'), findsOneWidget);
    expect(find.text('حسابات المطعم'), findsOneWidget);
    expect(find.text('الإعدادات والنسخ'), findsOneWidget);
    expect(
      find.descendant(
        of: find
            .byWidgetPredicate((w) => w is DakhlButton && w.label == 'المبيعات')
            .last,
        matching: find.byWidgetPredicate(
          (w) => w is DakhlIcon && w.kind == DakhlIconKind.grid,
        ),
      ),
      findsOneWidget,
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('حسابات المطعم'), findsNothing);
  });

  testWidgets(
    'protected shortcut editor disables save and exposes explicit reread',
    (tester) async {
      var saves = 0, retries = 0, cancels = 0;
      await tester.pumpWidget(
        host(
          SingleChildScrollView(
            child: DakhlShortcutEditor(
              choices: const ['sales', '', '', '', '', ''],
              destinations: const [
                DakhlDestination(
                  id: 'sales',
                  label: 'المبيعات',
                  group: 'العمل',
                ),
              ],
              onChanged: (_, _) {},
              onSave: () => saves++,
              onCancel: () => cancels++,
              canSave: false,
              onRetry: () => retries++,
              retryLabel: 'إعادة قراءة الإعدادات',
              errorMessage: 'تغيرت الإعدادات. أعد قراءتها.',
            ),
          ),
        ),
      );
      await tester.ensureVisible(find.text('حفظ الاختصارات'));
      await tester.tap(find.text('حفظ الاختصارات'));
      expect(saves, 0);
      await tester.ensureVisible(find.text('إعادة قراءة الإعدادات'));
      await tester.tap(find.text('إعادة قراءة الإعدادات'));
      expect(retries, 1);
      await tester.tap(find.text('إلغاء'));
      expect(cancels, 1);
    },
  );

  testWidgets(
    'sales layout uses the same inclusive narrow boundary as gutters',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      for (final width in [700.0, 760.0, 761.0]) {
        tester.view.physicalSize = Size(width, 1000);
        await tester.pumpWidget(
          host(const Phase01RouteSurface(routeId: 'sales')),
        );
        final catalog = tester.getTopLeft(
          find.byKey(const ValueKey('sales-catalog')),
        );
        final bill = tester.getTopLeft(
          find.byKey(const ValueKey('sales-bill')),
        );
        expect(catalog.dx, width <= 760 ? 14 : 24);
        if (width <= 760) {
          expect(bill.dy, greaterThan(catalog.dy));
        } else {
          expect(bill.dy, catalog.dy);
        }
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets(
    'explicitly named icon buttons announce exactly one accessible label',
    (tester) async {
      const labels = [
        'القائمة الرئيسية',
        'تخصيص الاختصارات',
        'تراجع',
        'إضافة كباب لحم',
      ];
      await tester.pumpWidget(
        host(
          Column(
            children: [
              DakhlIconButton(
                label: labels[0],
                icon: DakhlIconKind.menu,
                onPressed: () {},
              ),
              DakhlIconButton(
                label: labels[1],
                icon: DakhlIconKind.settings,
                onPressed: () {},
              ),
              DakhlIconButton(
                label: labels[2],
                icon: DakhlIconKind.undo,
                onPressed: () {},
              ),
              SizedBox(
                width: 180,
                child: DakhlProductCard(
                  item: phase01CatalogFixture.first,
                  onAdd: () {},
                ),
              ),
            ],
          ),
        ),
      );
      int accessibleOccurrences(SemanticsNode node, String label) {
        final data = node.getSemanticsData();
        final pattern = RegExp(RegExp.escape(label));
        var count =
            pattern.allMatches(data.label).length +
            pattern.allMatches(data.tooltip).length;
        node.visitChildren((child) {
          count += accessibleOccurrences(child, label);
          return true;
        });
        return count;
      }

      final root = tester.getSemantics(find.byType(Scaffold));
      for (final label in labels) {
        expect(accessibleOccurrences(root, label), 1);
        final data = tester
            .getSemantics(find.bySemanticsLabel(label).first)
            .getSemanticsData();
        expect(data.label, label);
        expect(data.tooltip, isEmpty);
        expect(data.flagsCollection.isButton, isTrue);
      }
      expect(tester.takeException(), isNull);
    },
  );
}
