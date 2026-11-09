import 'package:dakhl_restaurant/parties/parties_surface.dart';
import 'package:dakhl_restaurant/parties/additional_debt_controller.dart';
import 'package:dakhl_restaurant/ui/components.dart';
import 'package:dakhl_restaurant/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'parties_view_model_test.dart' show setup;
import 'additional_debt_controller_test.dart' show seed, accepted;

Finder input(String label) => find.descendant(
  of: find.widgetWithText(DakhlField, label),
  matching: find.byType(TextFormField),
);
void main() {
  testWidgets(
    'saved payment intent opens its exact source once and missing identity fails visibly',
    (tester) async {
      final (store, repo, metadata) = await setup();
      addTearDown(metadata.dispose);
      final handled = <String>[];
      Widget frame(String id) => MaterialApp(
        theme: DakhlTheme.light,
        home: Scaffold(
          body: PartiesSurface(
            routeId: 'payments',
            account: repo.document,
            metadata: metadata,
            compareText: (a, b) => a.compareTo(b),
            initialPaymentId: id,
            onInitialPaymentHandled: handled.add,
          ),
        ),
      );
      await tester.pumpWidget(frame('payment'));
      await tester.pumpAndSettle();
      expect(input('مبلغ التسديد'), findsOneWidget);
      expect(
        tester.widget<TextFormField>(input('مبلغ التسديد')).initialValue,
        '50',
      );
      expect(handled, ['payment']);
      await tester.tap(find.byTooltip('إغلاق النافذة'));
      await tester.pumpAndSettle();
      await tester.pumpWidget(frame('payment'));
      await tester.pumpAndSettle();
      expect(input('مبلغ التسديد'), findsNothing);
      expect(handled, ['payment']);
      await tester.pumpWidget(frame('missing-payment'));
      await tester.pumpAndSettle();
      expect(
        find.text('تعذّر فتح التسديد المحفوظ؛ أعد التحقق من مصدر الحركة.'),
        findsOneWidget,
      );
      expect(handled, ['payment', 'missing-payment']);
      expect(store.writes, 0);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'all archived suppliers retain readable ledger and debt browsing',
    (tester) async {
      final (_, repo, metadata) = await setup();
      addTearDown(metadata.dispose);
      final raw = repo.document!.toJson();
      final suppliers = (raw['suppliers']! as List)
          .map((s) => {...(s as Map).cast<String, Object?>(), 'archived': true})
          .toList();
      await repo.save(repo.codec.decodeJson({...raw, 'suppliers': suppliers}));
      await tester.pumpWidget(
        MaterialApp(
          theme: DakhlTheme.light,
          home: Scaffold(
            body: PartiesSurface(
              routeId: 'suppliers',
              account: repo.document,
              metadata: metadata,
              compareText: (a, b) => a.compareTo(b),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('لا يوجد موردون'), findsNothing);
      await tester.ensureVisible(
        find.widgetWithText(DakhlButton, 'كشف الحساب'),
      );
      await tester.tap(find.widgetWithText(DakhlButton, 'كشف الحساب'));
      await tester.pumpAndSettle();
      expect(find.textContaining('الرصيد السابق'), findsWidgets);
      await tester.ensureVisible(find.widgetWithText(DakhlButton, 'الديون'));
      await tester.tap(find.widgetWithText(DakhlButton, 'الديون'));
      await tester.pumpAndSettle();
      expect(find.textContaining('historical'), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'repeated archived saved materials open with unique editor rows',
    (tester) async {
      final (_, repo, metadata) = await setup();
      addTearDown(metadata.dispose);
      final raw = repo.document!.toJson();
      final materials = (raw['materials']! as List)
          .map((m) => {...(m as Map).cast<String, Object?>(), 'archived': true})
          .toList();
      final invoices = (raw['invoices']! as List).map((i) {
        final invoice = (i as Map).cast<String, Object?>();
        final line = (invoice['lines']! as List).first;
        return {
          ...invoice,
          'lines': [line, line],
        };
      }).toList();
      await repo.save(
        repo.codec.decodeJson({
          ...raw,
          'materials': materials,
          'invoices': invoices,
        }),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: DakhlTheme.light,
          home: Scaffold(
            body: PartiesSurface(
              routeId: 'invoices',
              account: repo.document,
              metadata: metadata,
              compareText: (a, b) => a.compareTo(b),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final edit = find.widgetWithText(DakhlButton, 'تفاصيل وتعديل القائمة');
      await tester.ensureVisible(edit);
      await tester.tap(edit);
      await tester.pumpAndSettle();
      final selectors = find.byWidgetPredicate(
        (w) => w is DakhlSelect<String> && w.label == 'مادة محفوظة',
      );
      expect(selectors, findsNWidgets(2));
      for (final select in tester.widgetList<DakhlSelect<String>>(selectors)) {
        expect(select.value, 'material');
        expect(
          select.items.where((item) => item.value == 'material'),
          hasLength(1),
        );
      }
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'saved material selection survives rebuild and clears for a renamed material',
    (tester) async {
      final (_, repo, metadata) = await setup();
      addTearDown(metadata.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: DakhlTheme.light,
          home: Scaffold(
            body: PartiesSurface(
              routeId: 'invoices',
              account: repo.document,
              metadata: metadata,
              compareText: (a, b) => a.compareTo(b),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(DakhlButton, 'إضافة فاتورة'));
      await tester.pumpAndSettle();
      Finder selector() => find.byWidgetPredicate(
        (w) => w is DakhlSelect<String> && w.label == 'مادة محفوظة',
      );
      tester.widget<DakhlSelect<String>>(selector()).onChanged!('material');
      await tester.pumpAndSettle();
      expect(tester.widget<DakhlSelect<String>>(selector()).value, 'material');
      await tester.enterText(input('اسم المادة'), 'New independent material');
      await tester.pumpAndSettle();
      expect(tester.widget<DakhlSelect<String>>(selector()).value, isNull);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'mapped additional debt form creates one source and one posting',
    (tester) async {
      final (store, snapshot) = await seed();
      final owner = AdditionalDebtController(
        store: store,
        snapshot: snapshot,
        isWriteBlocked: () => false,
        acceptedCounterAccountId: accepted,
      );
      addTearDown(owner.dispose);
      final writes = store.writes;
      await tester.pumpWidget(
        MaterialApp(
          theme: DakhlTheme.light,
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: PartiesSurface(
                routeId: 'suppliers',
                additionalDebts: owner,
                compareText: (a, b) => a.compareTo(b),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.widgetWithText(DakhlButton, 'الديون'));
      await tester.tap(find.widgetWithText(DakhlButton, 'الديون'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.widgetWithText(DakhlButton, 'إضافة دين'));
      await tester.tap(find.widgetWithText(DakhlButton, 'إضافة دين'));
      await tester.pumpAndSettle();
      await tester.enterText(input('تاريخ الدين'), '2026-11-08');
      await tester.enterText(input('مبلغ الدين'), '750');
      await tester.enterText(input('ملاحظة الدين'), 'Supplier adjustment');
      await tester.ensureVisible(find.widgetWithText(DakhlButton, 'حفظ الدين'));
      await tester.tap(find.widgetWithText(DakhlButton, 'حفظ الدين'));
      await tester.pumpAndSettle();
      expect((owner.account.toJson()['debts']! as List).single['amount'], 750);
      expect(store.writes, writes + 1);
      expect(find.text('750 د.ع'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('additional debt unmapped form cannot mutate source', (
    tester,
  ) async {
    final (store, repo, metadata) = await setup();
    addTearDown(metadata.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: DakhlTheme.light,
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: PartiesSurface(
              routeId: 'suppliers',
              account: repo.document,
              metadata: metadata,
              compareText: (a, b) => a.compareTo(b),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.widgetWithText(DakhlButton, 'الديون'));
    await tester.tap(find.widgetWithText(DakhlButton, 'الديون'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.widgetWithText(DakhlButton, 'إضافة دين'));
    await tester.tap(find.widgetWithText(DakhlButton, 'إضافة دين'));
    await tester.pumpAndSettle();
    expect(input('تاريخ الدين'), findsOneWidget);
    expect(input('مبلغ الدين'), findsOneWidget);
    expect(
      tester
          .widget<DakhlButton>(find.widgetWithText(DakhlButton, 'حفظ الدين'))
          .onPressed,
      isNull,
    );
    expect(store.writes, 0);
    expect(tester.takeException(), isNull);
  });
  testWidgets('ledger dates filter display and expose saved event edits', (
    tester,
  ) async {
    final (store, repo, metadata) = await setup();
    addTearDown(metadata.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: DakhlTheme.light,
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: PartiesSurface(
              routeId: 'suppliers',
              account: repo.document,
              metadata: metadata,
              compareText: (a, b) => a.compareTo(b),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.widgetWithText(DakhlButton, 'كشف الحساب'));
    await tester.tap(find.widgetWithText(DakhlButton, 'كشف الحساب'));
    await tester.pumpAndSettle();
    expect(find.textContaining('الرصيد السابق 900'), findsOneWidget);
    expect(find.byTooltip('تعديل الحركة'), findsNWidgets(3));
    await tester.ensureVisible(input('من تاريخ'));
    await tester.enterText(input('من تاريخ'), '2026-02-01');
    await tester.ensureVisible(
      find.widgetWithText(DakhlButton, 'تطبيق التصفية'),
    );
    await tester.tap(find.widgetWithText(DakhlButton, 'تطبيق التصفية'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('تعديل الحركة'), findsNothing);
    expect(store.writes, 0);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'purchase analysis saved lines and delivery controls are reachable',
    (tester) async {
      final (_, repo, metadata) = await setup();
      addTearDown(metadata.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: DakhlTheme.light,
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: PartiesSurface(
                routeId: 'invoices',
                account: repo.document,
                metadata: metadata,
                compareText: (a, b) => a.compareTo(b),
                compareMaterialNames: (a, b) => a.compareTo(b),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('تحليل المشتريات'), findsOneWidget);
      expect(find.text('المورد في القوائم'), findsOneWidget);
      expect(
        find.textContaining('Historic rice · old bag: 0 كارتون · 2 old bag'),
        findsOneWidget,
      );
      await tester.ensureVisible(find.text('بنود القائمة المحفوظة'));
      await tester.tap(find.text('بنود القائمة المحفوظة'));
      await tester.pumpAndSettle();
      expect(find.text('Historic rice · old bag'), findsOneWidget);
      expect(find.text('مشاركة PDF'), findsOneWidget);
      expect(find.text('طباعة PDF'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'source payment create and expanded carton controls are reachable',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final (_, repo, metadata) = await setup();
      addTearDown(metadata.dispose);
      Future<void> mount(String route) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: DakhlTheme.light,
            home: Directionality(
              textDirection: TextDirection.rtl,
              child: Scaffold(
                body: PartiesSurface(
                  key: ValueKey(route),
                  routeId: route,
                  account: repo.document,
                  metadata: metadata,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      await mount('payments');
      await tester.tap(find.widgetWithText(DakhlButton, 'تسجيل تسديد'));
      await tester.pumpAndSettle();
      expect(input('مبلغ التسديد'), findsOneWidget);
      expect(find.textContaining('أقصى مبلغ متاح للتسديد'), findsOneWidget);
      await tester.tap(find.byTooltip('إغلاق النافذة'));
      await tester.pumpAndSettle();
      await mount('invoices');
      await tester.tap(find.widgetWithText(DakhlButton, 'إضافة فاتورة'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('كارتون / وحدة القياس'));
      await tester.tap(find.text('كارتون / وحدة القياس'));
      await tester.pumpAndSettle();
      expect(input('الكمية كارتون'), findsOneWidget);
      expect(input('سعر الكارتون · د.ع'), findsOneWidget);
      expect(input('وحدة القياس'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'supplier creation saves metadata with zero new opening and retained history',
    (tester) async {
      final (store, repo, metadata) = await setup();
      addTearDown(metadata.dispose);
      final oldInvoices = repo.document!.toJson()['invoices'];
      await tester.pumpWidget(
        MaterialApp(
          theme: DakhlTheme.light,
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: PartiesSurface(
                routeId: 'suppliers',
                account: repo.document,
                metadata: metadata,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(DakhlButton, 'إضافة مورد'));
      await tester.pumpAndSettle();
      await tester.enterText(input('اسم المورد'), 'New supplier');
      await tester.enterText(input('الهاتف'), '123');
      await tester.ensureVisible(find.widgetWithText(DakhlButton, 'حفظ'));
      await tester.tap(find.widgetWithText(DakhlButton, 'حفظ'));
      await tester.pumpAndSettle();
      final added = (repo.document!.toJson()['suppliers'] as List)
          .cast<Map<String, Object?>>()
          .last;
      expect(added['name'], 'New supplier');
      expect(added['openingBalance'], 0);
      expect(repo.document!.toJson()['invoices'], oldInvoices);
      expect(store.writes, 1);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('material default-price edit preserves saved invoice snapshots', (
    tester,
  ) async {
    final (_, repo, metadata) = await setup();
    addTearDown(metadata.dispose);
    final oldInvoices = repo.document!.toJson()['invoices'];
    await tester.pumpWidget(
      MaterialApp(
        theme: DakhlTheme.light,
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: PartiesSurface(
              routeId: 'materials',
              account: repo.document,
              metadata: metadata,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(DakhlButton, 'تعديل المادة'));
    await tester.pumpAndSettle();
    await tester.enterText(input('سعر القطعة · د.ع'), '175');
    await tester.ensureVisible(find.widgetWithText(DakhlButton, 'حفظ'));
    await tester.tap(find.widgetWithText(DakhlButton, 'حفظ'));
    await tester.pumpAndSettle();
    expect(
      (repo.document!.toJson()['materials'] as List).single['pricePiece'],
      175,
    );
    expect(repo.document!.toJson()['invoices'], oldInvoices);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'schema11 invoice editor presents saved data with financial save disabled',
    (tester) async {
      final (_, repo, metadata) = await setup();
      addTearDown(metadata.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: DakhlTheme.light,
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: PartiesSurface(
                routeId: 'invoices',
                account: repo.document,
                metadata: metadata,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.widgetWithText(DakhlButton, 'تفاصيل وتعديل القائمة'),
      );
      await tester.tap(
        find.widgetWithText(DakhlButton, 'تفاصيل وتعديل القائمة'),
      );
      await tester.pumpAndSettle();
      expect(input('اسم المادة'), findsOneWidget);
      expect(
        tester
            .widget<DakhlButton>(
              find.widgetWithText(DakhlButton, 'حفظ القائمة'),
            )
            .onPressed,
        isNull,
      );
      expect(
        find.text(
          'الحفظ المالي غير متاح حالياً؛ البيانات المحفوظة تبقى دون تغيير.',
        ),
        findsOneWidget,
      );
      expect((repo.document!.toJson()['invoices'] as List).length, 1);
      expect(tester.takeException(), isNull);
    },
  );
}
