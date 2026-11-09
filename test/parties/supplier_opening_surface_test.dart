import 'package:dakhl_restaurant/accounts/accounts_repository.dart';
import 'package:dakhl_restaurant/accounts/portable_metadata_repository_bridge.dart';
import 'package:dakhl_restaurant/parties/parties_surface.dart';
import 'package:dakhl_restaurant/parties/parties_view_model.dart';
import 'package:dakhl_restaurant/parties/supplier_opening_controller.dart';
import 'package:dakhl_restaurant/ui/components.dart';
import 'package:dakhl_restaurant/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'additional_debt_controller_test.dart' show seed;

Finder input(String label) => find.descendant(
  of: find.widgetWithText(DakhlField, label),
  matching: find.byType(TextFormField),
);

void main() {
  testWidgets(
    'supplier opening at 320px and 200 percent saves reasoned delta and retained history',
    (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final (store, initial) = await seed();
      final bridge = PortableMetadataRepositoryBridge(
        inner: store,
        snapshot: initial,
        isWriteBlocked: () => false,
      );
      addTearDown(bridge.dispose);
      final repository = AccountsRepository(store: bridge);
      await repository.open();
      final metadata = PartiesViewModel(repository);
      addTearDown(metadata.dispose);
      final opening = SupplierOpeningController(
        store: store,
        snapshot: initial,
        isWriteBlocked: () => false,
        acceptedOpeningEquityAccountId: 'equity:opening_balance',
      );
      addTearDown(opening.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: DakhlTheme.light,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(2)),
            child: child!,
          ),
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: PartiesSurface(
                routeId: 'suppliers',
                metadata: metadata,
                supplierOpenings: opening,
                compareText: (a, b) => a.compareTo(b),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final edit = find.widgetWithText(DakhlButton, 'تعديل المورد');
      await tester.ensureVisible(edit);
      await tester.pumpAndSettle();
      await tester.tap(edit);
      await tester.pumpAndSettle();
      expect(find.textContaining('ولا يشملها التراجع السريع'), findsOneWidget);
      final amount = input('الديون السابقة عند تسجيل المورد');
      final amountField = tester.widget<TextField>(
        find.descendant(of: amount, matching: find.byType(TextField)),
      );
      expect(
        amountField.keyboardType,
        const TextInputType.numberWithOptions(decimal: true),
      );
      expect(amountField.textDirection, TextDirection.ltr);
      await tester.ensureVisible(amount);
      await tester.enterText(amount, '1000');
      final reason = input('سبب تعديل الدين الافتتاحي');
      await tester.ensureVisible(reason);
      await tester.enterText(reason, 'Reviewed opening');
      final writes = store.writes;
      final save = find.widgetWithText(DakhlButton, 'حفظ');
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(store.writes, writes + 1);
      expect(
        (opening.account.toJson()['suppliers'] as List)
            .single['openingBalance'],
        1000,
      );
      expect(find.text('تعديلات الدين الافتتاحي'), findsOneWidget);
      await tester.ensureVisible(find.text('تعديلات الدين الافتتاحي'));
      await tester.tap(find.text('تعديلات الدين الافتتاحي'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Reviewed opening'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'new supplier with opening is one atomic command and requires an accepted mapping',
    (tester) async {
      final (store, initial) = await seed();
      final bridge = PortableMetadataRepositoryBridge(
        inner: store,
        snapshot: initial,
        isWriteBlocked: () => false,
      );
      addTearDown(bridge.dispose);
      final repository = AccountsRepository(store: bridge);
      await repository.open();
      final metadata = PartiesViewModel(repository);
      addTearDown(metadata.dispose);
      final opening = SupplierOpeningController(
        store: store,
        snapshot: initial,
        isWriteBlocked: () => false,
        acceptedOpeningEquityAccountId: 'equity:opening_balance',
      );
      addTearDown(opening.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: DakhlTheme.light,
          home: Scaffold(
            body: PartiesSurface(
              routeId: 'suppliers',
              metadata: metadata,
              supplierOpenings: opening,
              compareText: (a, b) => a.compareTo(b),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final add = find.widgetWithText(DakhlButton, 'إضافة مورد');
      await tester.ensureVisible(add);
      await tester.tap(add);
      await tester.pumpAndSettle();
      await tester.enterText(input('اسم المورد'), 'New opening supplier');
      await tester.ensureVisible(input('الديون السابقة عند تسجيل المورد'));
      await tester.enterText(input('الديون السابقة عند تسجيل المورد'), '500');
      await tester.ensureVisible(input('سبب تعديل الدين الافتتاحي'));
      await tester.enterText(
        input('سبب تعديل الدين الافتتاحي'),
        'Verified new supplier opening',
      );
      final writes = store.writes;
      final save = find.widgetWithText(DakhlButton, 'حفظ');
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(store.writes, writes + 1);
      final suppliers = (opening.account.toJson()['suppliers'] as List)
          .cast<Map<String, Object?>>();
      expect(
        suppliers.singleWhere(
          (s) => s['name'] == 'New opening supplier',
        )['openingBalance'],
        500,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'unaccepted opening mapping keeps the financial input read-only',
    (tester) async {
      final (store, initial) = await seed();
      final bridge = PortableMetadataRepositoryBridge(
        inner: store,
        snapshot: initial,
        isWriteBlocked: () => false,
      );
      addTearDown(bridge.dispose);
      final repository = AccountsRepository(store: bridge);
      await repository.open();
      final metadata = PartiesViewModel(repository);
      addTearDown(metadata.dispose);
      final opening = SupplierOpeningController(
        store: store,
        snapshot: initial,
        isWriteBlocked: () => false,
      );
      addTearDown(opening.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: DakhlTheme.light,
          home: Scaffold(
            body: PartiesSurface(
              routeId: 'suppliers',
              metadata: metadata,
              supplierOpenings: opening,
              compareText: (a, b) => a.compareTo(b),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(DakhlButton, 'تعديل المورد'));
      await tester.pumpAndSettle();
      final field = tester.widget<TextFormField>(
        input('الديون السابقة عند تسجيل المورد'),
      );
      expect(field.enabled, isFalse);
      expect(input('سبب تعديل الدين الافتتاحي'), findsNothing);
      expect(opening.canWrite, isFalse);
    },
  );
}
