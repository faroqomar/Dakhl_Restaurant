import 'package:dakhl_restaurant/catalog/stock_history_dialog.dart';
import 'package:dakhl_restaurant/inventory/inventory_commands.dart';
import 'package:dakhl_restaurant/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar_application/madar_application.dart';
import 'package:madar_domain/madar_domain.dart';

import 'stock_movement_workflow_test.dart'
    show createTestProduct, getProduct, setupWorkflow;

void main() {
  for (final (size, scale) in [
    (const Size(466, 678), 1.0),
    (const Size(390, 844), 1.0),
    (const Size(320, 700), 2.0),
  ]) {
    testWidgets(
      'history retains long reversal details at ${size.width}px and ${scale}x text',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final (_, accounts, catalog, shell) = await setupWorkflow();
        addTearDown(accounts.dispose);
        addTearDown(catalog.dispose);
        addTearDown(shell.dispose);
        final today = DateOnly.parse(
          '2026-11-07',
          minimumYear: 1000,
          maximumYear: 9999,
        );
        await createTestProduct(
          catalog,
          id: 'history-phone',
          name: 'مندي دجاج',
          openingUnits: BigInt.from(10000),
          asOf: today,
        );
        const movementId = '6c35f5c4-441a-4c3d-9a0f-a6f21c2a3d5e';
        expect(
          await catalog.postMovement(
            InventoryMovement(
              id: movementId,
              productId: 'history-phone',
              quantityUnits: BigInt.from(3000),
              effectiveDate: today,
              kind: StockEntryKind.restock,
              createdAt: '2026-11-07T10:00:00Z',
            ),
            session: catalog.beginEdit(),
          ),
          isA<CapabilitySuccess>(),
        );
        expect(
          await catalog.reverseMovement(
            movementId,
            session: catalog.beginEdit(),
            newId: 'c48b8e4e-2c21-4bc6-a589-7a001ac18400',
            reason: 'C1 accepted correction',
            createdAt: '2026-11-07T11:00:00Z',
          ),
          isA<CapabilitySuccess>(),
        );
        expect(
          await catalog.postMovement(
            InventoryMovement(
              id: 'future-history-phone',
              productId: 'history-phone',
              quantityUnits: BigInt.from(5000),
              effectiveDate: DateOnly.parse(
                '2026-11-08',
                minimumYear: 1000,
                maximumYear: 9999,
              ),
              kind: StockEntryKind.restock,
              createdAt: '2026-11-07T12:00:00Z',
            ),
            session: catalog.beginEdit(),
          ),
          isA<CapabilitySuccess>(),
        );
        final product = getProduct(catalog, 'history-phone', today);
        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('ar'),
            supportedLocales: const [Locale('ar')],
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            theme: DakhlTheme.light,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => showStockHistoryDialog(
                    context,
                    viewModel: catalog,
                    product: product,
                    shell: shell,
                    today: today,
                  ),
                  child: const Text('history'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('history'));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.textContaining(movementId), findsOneWidget);
        expect(find.textContaining('C1 accepted correction'), findsOneWidget);
        expect(find.text('حركة مستقبلية'), findsOneWidget);
        final detail = find.textContaining(movementId);
        await tester.ensureVisible(detail);
        await tester.pumpAndSettle();
        expect(detail.hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
