import 'package:dakhl_restaurant/accounts/account_document.dart';
import 'package:dakhl_restaurant/accounts/legacy_account_codec.dart';
import 'package:dakhl_restaurant/sales/sale_proposal.dart';
import 'package:dakhl_restaurant/sales/sales_history_surface.dart';
import 'package:dakhl_restaurant/ui/components.dart';
import 'package:dakhl_restaurant/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

AccountDocument savedAccount() {
  const codec = LegacyAccountCodec();
  final source = codec.decodeJson({
    ...codec.empty().toJson(),
    'products': [
      {
        'id': 'p',
        'name': 'Captured name',
        'code': '',
        'unit': 'piece',
        'price': 1000,
        'group': '',
        'minStock': 0,
        'trackStock': false,
        'archived': false,
      },
    ],
  });
  return SaleProposal.build(
    source,
    saleId: 'saved',
    createdAt: '2026-11-07T12:00:00Z',
    draft: {
      'date': '2026-11-07',
      'discount': 100,
      'lines': [
        {'productId': 'p', 'quantity': 2, 'price': 1000},
      ],
    },
  ).candidate;
}

Widget mount(AccountDocument source) => MaterialApp(
  theme: DakhlTheme.light,
  home: Directionality(
    textDirection: TextDirection.rtl,
    child: Scaffold(body: SalesHistorySurface(document: source)),
  ),
);
void main() {
  testWidgets(
    'schema11 history displays saved receipt snapshots without posting controls',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final account = savedAccount();
      await tester.pumpWidget(mount(account));
      await tester.pumpAndSettle();
      expect(find.text('S-000001'), findsOneWidget);
      await tester.tap(find.widgetWithText(DakhlButton, 'عرض الوصل'));
      await tester.pumpAndSettle();
      expect(find.text('وصل بيع محفوظ'), findsOneWidget);
      expect(find.text('Captured name'), findsOneWidget);
      expect(find.text('طباعة الوصل'), findsOneWidget);
      expect(find.text('حفظ PDF'), findsOneWidget);
      expect(find.text('فتح PDF'), findsOneWidget);
      expect(find.widgetWithText(DakhlButton, 'إلغاء الوصل'), findsNothing);
      expect((account.toJson()['sales'] as List).length, 1);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'schema11 return preview accepts input while financial posting stays disabled',
    (tester) async {
      final account = savedAccount();
      await tester.pumpWidget(mount(account));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.widgetWithText(DakhlButton, 'عرض الوصل'));
      await tester.tap(find.widgetWithText(DakhlButton, 'عرض الوصل'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.widgetWithText(DakhlButton, 'إرجاع أصناف'),
      );
      await tester.tap(find.widgetWithText(DakhlButton, 'إرجاع أصناف'));
      await tester.pumpAndSettle();
      final submit = tester.widget<DakhlButton>(
        find.widgetWithText(DakhlButton, 'تسجيل المرتجع ورد المبلغ'),
      );
      expect(submit.onPressed, isNull);
      final quantity = tester.widget<DakhlField>(
        find.widgetWithText(DakhlField, 'كمية Captured name'),
      );
      expect(quantity.controller!.text, '0');
      expect(quantity.readOnly, false);
      expect((account.toJson()['saleReturns'] as List), isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
}
