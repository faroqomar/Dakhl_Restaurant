import 'package:dakhl_restaurant/accounts/legacy_account_codec.dart';
import 'package:dakhl_restaurant/catalog/inventory_surface.dart';
import 'package:dakhl_restaurant/sales/return_proposal.dart';
import 'package:dakhl_restaurant/sales/sale_proposal.dart';
import 'package:dakhl_restaurant/sales/sales_history_surface.dart';
import 'package:dakhl_restaurant/ui/components.dart';
import 'package:dakhl_restaurant/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar_domain/madar_domain.dart';

import 'stock_movement_workflow_test.dart'
    show setupWorkflow, createTestProduct;
import '../sales/sales_history_surface_test.dart' show savedAccount;

DateOnly date(String value) =>
    DateOnly.parse(value, minimumYear: 1000, maximumYear: 9999);
void main() {
  for (final source in ['sale', 'return']) {
    testWidgets(
      'stock $source opens exact saved parent receipt once without a write',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final (repo, accounts, catalog, shell) = await setupWorkflow();
        addTearDown(accounts.dispose);
        addTearDown(catalog.dispose);
        addTearDown(shell.dispose);
        await createTestProduct(
          catalog,
          id: 'p',
          name: 'Tracked snapshot',
          openingUnits: BigInt.from(10000),
          asOf: date('2026-11-08'),
        );
        final sale = SaleProposal.build(
          repo.document!,
          saleId: 'saved-sale',
          createdAt: '2026-11-07T12:00:00Z',
          draft: {
            'date': '2026-11-07',
            'discount': 0,
            'lines': [
              {'productId': 'p', 'quantity': 2},
            ],
          },
        ).candidate;
        final returned = ReturnProposal.build(
          sale,
          saleId: 'saved-sale',
          returnId: 'saved-return',
          date: '2026-11-08',
          reason: 'Saved return',
          createdAt: '2026-11-08T12:00:00Z',
          today: '2026-11-08',
          lines: [
            ReturnLineRequest(
              productId: 'p',
              quantityUnits: BigInt.from(1000),
              restock: true,
            ),
          ],
        ).candidate;
        await repo.save(returned);
        await accounts.initialize();
        final before = repo.snapshot!.payload;
        String? pending;
        var history = false;
        final opened = <String>[], handled = <String>[];
        late StateSetter rebuild;
        await tester.pumpWidget(
          MaterialApp(
            theme: DakhlTheme.light,
            home: Directionality(
              textDirection: TextDirection.rtl,
              child: Scaffold(
                body: StatefulBuilder(
                  builder: (context, set) {
                    rebuild = set;
                    return history
                        ? SalesHistorySurface(
                            document: repo.document,
                            initialSaleId: pending,
                            onInitialSaleHandled: (id) {
                              handled.add(id);
                              set(() => pending = null);
                            },
                          )
                        : InventorySurface(
                            model: catalog,
                            accounts: accounts,
                            shell: shell,
                            today: date('2026-11-08'),
                            onOpenSale: (id) {
                              opened.add(id);
                              set(() {
                                pending = id;
                                history = true;
                              });
                            },
                          );
                  },
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.widgetWithText(DakhlButton, 'الحركة'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(DakhlButton, 'الحركة'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(
          find.text(source == 'sale' ? 'saved-sale' : 'saved-return').first,
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.text(source == 'sale' ? 'saved-sale' : 'saved-return').first,
        );
        await tester.pumpAndSettle();
        expect(opened, ['saved-sale']);
        expect(handled, ['saved-sale']);
        expect(find.text('وصل بيع محفوظ'), findsOneWidget);
        expect(find.text('Tracked snapshot'), findsWidgets);
        expect(find.text('حركة الصنف'), findsNothing);
        expect(repo.snapshot!.payload, before);
        await tester.tap(
          find.byWidgetPredicate(
            (widget) =>
                widget is DakhlIconButton && widget.label == 'إغلاق النافذة',
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));
        await tester.pumpAndSettle();
        rebuild(() {});
        await tester.pumpAndSettle();
        expect(find.text('وصل بيع محفوظ'), findsNothing);
        expect(handled, ['saved-sale']);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets('missing saved ID fails visibly without creating a receipt', (
    tester,
  ) async {
    final account = savedAccount();
    final handled = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: DakhlTheme.light,
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: SalesHistorySurface(
              document: account,
              initialSaleId: 'missing',
              onInitialSaleHandled: handled.add,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('تعذّر العثور على الفاتورة المحفوظة المطلوبة.'),
      findsOneWidget,
    );
    expect(find.text('وصل بيع محفوظ'), findsNothing);
    expect(handled, ['missing']);
    expect((account.toJson()['sales'] as List).length, 1);
    expect(tester.takeException(), isNull);
  });
  testWidgets('saved void receipt opens by its original identity read-only', (
    tester,
  ) async {
    final source = savedAccount();
    final sale =
        (source.toJson()['sales']! as List).single as Map<String, Object?>;
    final account = const LegacyAccountCodec().decodeJson({
      ...source.toJson(),
      'sales': [
        {
          ...sale,
          'status': 'void',
          'voidReason': 'Saved void',
          'voidedAt': '2026-11-08T12:00:00Z',
        },
      ],
    });
    await tester.pumpWidget(
      MaterialApp(
        theme: DakhlTheme.light,
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: SalesHistorySurface(
              document: account,
              initialSaleId: sale['id']! as String,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('فاتورة ملغاة'), findsOneWidget);
    expect(find.text('Saved void'), findsOneWidget);
    expect(find.widgetWithText(DakhlButton, 'إلغاء الوصل'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
