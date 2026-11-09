import 'dart:ui' show Tristate;

import 'package:dakhl_restaurant/sales/sales_surface.dart';
import 'package:dakhl_restaurant/accounts/legacy_account_codec.dart';
import 'package:dakhl_restaurant/sales/sales_view_model.dart';
import 'package:dakhl_restaurant/ui/components.dart';
import 'package:dakhl_restaurant/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../accounts/accounts_view_model_test.dart' show FixtureStore;
import 'sales_view_model_test.dart' show repository, fresh, product;

void main() {
  testWidgets(
    'group counts cover eligible catalog independently of search and pagination',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final semantics = tester.ensureSemantics();
      try {
        final repo = await repository(FixtureStore());
        await repo.save(
          const LegacyAccountCodec().decodeJson({
            ...const LegacyAccountCodec().empty().toJson(),
            'products': [
              product('p0', group: 'food'),
              product('p1', group: 'drink', tracked: true),
              product('archived', group: 'food', archived: true),
              product('p3', group: 'food'),
              for (var i = 0; i < 87; i++) product('ungrouped-$i', group: ''),
            ],
          }),
        );
        final model = SalesViewModel(repo);
        addTearDown(model.dispose);
        await model.load(fresh('active'));
        await tester.pumpWidget(
          MaterialApp(
            theme: DakhlTheme.light,
            home: Directionality(
              textDirection: TextDirection.rtl,
              child: Scaffold(body: SalesSurface(model: model)),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.widgetWithText(DakhlButton, 'كل الأصناف · 90'),
          findsOneWidget,
        );
        expect(find.widgetWithText(DakhlButton, 'food · 2'), findsOneWidget);
        expect(find.widgetWithText(DakhlButton, 'drink · 1'), findsOneWidget);
        expect(
          tester
                  .getSemantics(
                    find.widgetWithText(DakhlButton, 'كل الأصناف · 90'),
                  )
                  .flagsCollection
                  .isSelected ==
              Tristate.isTrue,
          isTrue,
        );
        expect(
          tester
                  .getSemantics(find.widgetWithText(DakhlButton, 'drink · 1'))
                  .flagsCollection
                  .isSelected ==
              Tristate.isTrue,
          isFalse,
        );
        expect(find.text('Product archived'), findsNothing);
        expect(model.catalog!.items, hasLength(80));
        expect(model.catalog!.pageCount, 2);
        final unavailable = tester.widget<DakhlButton>(
          find.widgetWithText(DakhlButton, 'إضافة Product p1'),
        );
        expect(unavailable.onPressed, isNull);
        await tester.tap(find.widgetWithText(DakhlButton, 'drink · 1'));
        await tester.pumpAndSettle();
        expect(model.catalog!.total, 1);
        expect(
          tester
                  .getSemantics(find.widgetWithText(DakhlButton, 'drink · 1'))
                  .flagsCollection
                  .isSelected ==
              Tristate.isTrue,
          isTrue,
        );
        expect(
          tester
                  .getSemantics(
                    find.widgetWithText(DakhlButton, 'كل الأصناف · 90'),
                  )
                  .flagsCollection
                  .isSelected ==
              Tristate.isTrue,
          isFalse,
        );
        expect(find.text('Product p0'), findsNothing);
        await tester.enterText(find.byType(TextField).first, 'codep0');
        await tester.pumpAndSettle();
        expect(model.catalog!.items, isEmpty);
        expect(
          find.widgetWithText(DakhlButton, 'كل الأصناف · 90'),
          findsOneWidget,
        );
        expect(find.widgetWithText(DakhlButton, 'food · 2'), findsOneWidget);
        expect(find.widgetWithText(DakhlButton, 'drink · 1'), findsOneWidget);
        await tester.tap(find.widgetWithText(DakhlButton, 'كل الأصناف · 90'));
        await tester.pumpAndSettle();
        expect(model.catalog!.items.single.id, 'p0');
        expect(tester.takeException(), isNull);
      } finally {
        semantics.dispose();
      }
    },
  );

  testWidgets('untracked product card retains current in-cart quantity', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = await repository(FixtureStore());
    final model = SalesViewModel(repo);
    addTearDown(model.dispose);
    await model.load(fresh('active'));
    await tester.pumpWidget(
      MaterialApp(
        theme: DakhlTheme.light,
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(body: SalesSurface(model: model)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(DakhlButton, 'إضافة Product p0'));
    await tester.pumpAndSettle();
    expect(find.text('بالطلب 1 piece'), findsOneWidget);
    await tester.tap(find.widgetWithText(DakhlButton, 'إضافة Product p0'));
    await tester.pumpAndSettle();
    expect(find.text('بالطلب 2 piece'), findsOneWidget);
    expect(model.active!.lines.single.quantityUnits, BigInt.from(2000));
    expect((repo.document!.toJson()['sales'] as List), isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('schema11 sales mounts real draft and refuses checkout', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = FixtureStore();
    final repo = await repository(store);
    final model = SalesViewModel(repo);
    addTearDown(model.dispose);
    await model.load(fresh('active'));
    await tester.pumpWidget(
      MaterialApp(
        theme: DakhlTheme.light,
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(body: SalesSurface(model: model)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(DakhlButton, 'إضافة Product p0'));
    await tester.pumpAndSettle();
    expect(model.active!.lines.single.productId, 'p0');
    final checkout = tester.widget<DakhlButton>(
      find.widgetWithText(DakhlButton, 'تأكيد البيع النقدي'),
    );
    expect(checkout.onPressed, isNull);
    expect(
      find.text('تأكيد البيع غير متاح حتى تفعيل الحسابات المالية.'),
      findsOneWidget,
    );
    expect((repo.document!.toJson()['sales'] as List), isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('populated held list resumes saved draft', (tester) async {
    final store = FixtureStore();
    final repo = await repository(store);
    final model = SalesViewModel(repo);
    addTearDown(model.dispose);
    await model.load(fresh('held-draft'));
    await model.addProduct('p0');
    await model.hold(
      label: 'Saved order',
      heldId: 'held',
      fresh: fresh('new'),
      savedAt: '2026-11-07T12:00:00Z',
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: DakhlTheme.light,
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(body: SalesSurface(model: model)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(DakhlButton, 'الطلبات المعلقة · 1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Saved order'));
    await tester.pumpAndSettle();
    expect(model.active!.id, 'held-draft');
    expect(model.active!.lines.single.productId, 'p0');
    expect(model.held, isEmpty);
    expect(tester.takeException(), isNull);
  });
}
