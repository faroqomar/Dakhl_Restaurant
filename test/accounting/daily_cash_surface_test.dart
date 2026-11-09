import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dakhl_restaurant/accounting/daily_cash_surface.dart';
import 'package:dakhl_restaurant/accounts/legacy_account_codec.dart';
import 'package:dakhl_restaurant/ui/theme.dart';

import '../parties/parties_view_model_test.dart' show setup;

void main() {
  for (final cash in [false, true]) {
    testWidgets('derived payment forwards exact saved identity cash=$cash', (
      tester,
    ) async {
      final (store, repository, metadata) = await setup();
      addTearDown(metadata.dispose);
      final raw = repository.document!.toJson();
      final payments = (raw['payments']! as List)
          .map(
            (p) => {
              ...(p as Map).cast<String, Object?>(),
              'funding': <String, Object?>{
                'source': 'cash',
                'dailyAmount': 0,
                'cashAmount': 50,
              },
            },
          )
          .toList();
      final account = repository.codec.decodeJson({
        ...raw,
        'payments': payments,
      });
      final opened = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          theme: DakhlTheme.light,
          home: Scaffold(
            body: DailyCashSurface(
              document: account,
              initialDate: '2026-01-01',
              cash: cash,
              compareText: (a, b) => a.compareTo(b),
              onOpenPayment: opened.add,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final action = find
          .byTooltip(cash ? 'فتح التسديد' : 'تعديل المصروف')
          .first;
      await tester.ensureVisible(action);
      await tester.tap(action);
      await tester.pumpAndSettle();
      expect(opened, ['payment']);
      expect(store.writes, 0);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets(
    'daily view splits saved funding and keeps chicken nonfinancial',
    (tester) async {
      const codec = LegacyAccountCodec();
      final account = codec.decodeJson({
        ...codec.empty().toJson(),
        'days': {
          '2026-11-08': {
            'expenses': [
              {
                'id': 'expense',
                'categoryId': 'samoon',
                'amount': 3000,
                'note': 'split',
                'funding': {
                  'source': 'shared',
                  'dailyAmount': 1000,
                  'cashAmount': 2000,
                },
              },
            ],
            'chickenUsed': 12,
            'chickenLeft': 8,
            'balance': 150000,
            'totalOverride': null,
            'remaining': null,
          },
        },
      });
      await tester.pumpWidget(
        MaterialApp(
          theme: DakhlTheme.light,
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: DailyCashSurface(
                document: account,
                initialDate: '2026-11-08',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('1,000 د.ع'), findsWidgets);
      expect(find.text('2,000 د.ع'), findsWidgets);
      expect(find.text('الدجاج المصروف: 12'), findsOneWidget);
      expect(find.text('الدجاج المتبقي: 8'), findsOneWidget);
      expect(find.text('3,000 د.ع'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
