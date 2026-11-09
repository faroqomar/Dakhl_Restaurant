import 'package:dakhl_restaurant/accounting/daily_cash_queries.dart';
import 'package:dakhl_restaurant/accounting/daily_cash_surface.dart';
import 'package:dakhl_restaurant/accounts/account_document.dart';
import 'package:dakhl_restaurant/accounts/legacy_account_codec.dart';
import 'package:dakhl_restaurant/parties/parties_surface.dart';
import 'package:dakhl_restaurant/reports/sales_report.dart';
import 'package:dakhl_restaurant/reports/source_event_order.dart';
import 'package:dakhl_restaurant/sales/sales_history_surface.dart';
import 'package:dakhl_restaurant/ui/components.dart';
import 'package:dakhl_restaurant/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../parties/parties_view_model_test.dart' show setup;
import 'sales_report_test.dart' show oracle;

// Finite synthetic source-key weights. This checks port forwarding, not ICU
// qualification; runtime comparison comes from an explicitly profiled session.
int sourcePair(String a, String b) {
  if (a == b) return 0;
  const ranks = {'Jan 2, 2026 12:00:00': 1, 'jan 2, 2026 12:00:00': 0};
  if (ranks.containsKey(a) && ranks.containsKey(b)) {
    return ranks[a]!.compareTo(ranks[b]!);
  }
  return a.compareTo(b);
}

AccountDocument salesDocument() {
  final raw = (oracle()['state'] as Map).cast<String, Object?>();
  return const LegacyAccountCodec().decodeJson({
    ...raw,
    'sales': [
      for (final sale in raw['sales']! as List)
        if ((sale as Map)['id'] != 'a')
          {
            ...sale.cast<String, Object?>(),
            'createdAt': sale['id'] == 'b'
                ? 'Jan 2, 2026 12:00:00'
                : 'jan 2, 2026 12:00:00',
          },
    ],
    'saleReturns': <Object?>[],
  });
}

Widget frame(Widget child) => MaterialApp(
  theme: DakhlTheme.light,
  home: Directionality(
    textDirection: TextDirection.rtl,
    child: Scaffold(body: child),
  ),
);
void main() {
  test('source event keys/ties use caller comparison and absent comparison refuses distinct keys', () {
    final doc = salesDocument();
    expect(() => SalesReport.build(doc), throwsFormatException);
    expect(
      SalesReport.build(
        doc,
        compareText: sourcePair,
      ).sales.map((s) => s.snapshot['id']),
      ['b', 'c'],
    );
    final events = <Map<String, Object?>>[
      {'id': 'A', 'date': '2026-01-02', 'createdAt': 'same', 'note': 'first'},
      {'id': 'a', 'date': '2026-01-02', 'createdAt': 'same', 'note': 'second'},
      {'id': 'a', 'date': '2026-01-02', 'createdAt': 'same', 'note': 'third'},
    ];
    final ordered = orderSourceEvents(
      events,
      keys: const ['date', 'createdAt', 'id'],
      descending: true,
      compareText: (a, b) {
        if (a == b) return 0;
        return a == 'A' ? 1 : -1;
      },
    );
    expect(ordered.map((r) => r['note']), ['first', 'second', 'third']);
    expect(
      () => orderSourceEvents(
        events,
        keys: const ['date', 'createdAt', 'id'],
        descending: true,
        compareText: null,
      ),
      throwsFormatException,
    );
    final cash = const LegacyAccountCodec().decodeJson({
      ...const LegacyAccountCodec().empty().toJson(),
      'transactions': [
        {
          'id': 'b',
          'date': '2026-01-02',
          'type': 'deposit',
          'amount': 10,
          'note': 'upper',
          'createdAt': 'Jan 2, 2026 12:00:00',
        },
        {
          'id': 'c',
          'date': '2026-01-02',
          'type': 'deposit',
          'amount': 20,
          'note': 'lower',
          'createdAt': 'jan 2, 2026 12:00:00',
        },
      ],
    });
    expect(
      DailyCashQueries(cash)
          .orderedCashMovements(sourcePair)
          .map((r) => r['id']),
      ['b', 'c'],
    );
  });
  testWidgets(
    'history cash and party lists expose unavailable ordering; separate material-name comparator forwards',
    (tester) async {
      tester.view.physicalSize = const Size(1300, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final sales = salesDocument();
      await tester.pumpWidget(frame(SalesHistorySurface(document: sales)));
      await tester.pumpAndSettle();
      expect(find.text('ترتيب سجل المبيعات غير متاح حالياً'), findsOneWidget);
      await tester.pumpWidget(
        frame(SalesHistorySurface(document: sales, compareText: sourcePair)),
      );
      await tester.pumpAndSettle();
      expect(find.text('ترتيب سجل المبيعات غير متاح حالياً'), findsNothing);
      expect(find.widgetWithText(DakhlButton, 'عرض الوصل'), findsNWidgets(2));
      final cash = const LegacyAccountCodec().decodeJson({
        ...const LegacyAccountCodec().empty().toJson(),
        'transactions': [
          {
            'id': 'b',
            'date': '2026-01-02',
            'type': 'deposit',
            'amount': 10,
            'note': 'upper',
            'createdAt': 'Jan 2, 2026 12:00:00',
          },
          {
            'id': 'c',
            'date': '2026-01-02',
            'type': 'deposit',
            'amount': 20,
            'note': 'lower',
            'createdAt': 'jan 2, 2026 12:00:00',
          },
        ],
      });
      await tester.pumpWidget(
        frame(DailyCashSurface(document: cash, cash: true)),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('ترتيب حركات القاصة غير متاح حالياً. بيانات الحساب محفوظة.'),
        findsOneWidget,
      );
      await tester.pumpWidget(
        frame(
          DailyCashSurface(document: cash, cash: true, compareText: sourcePair),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('الرصيد بعد الحركة: 30 د.ع'), findsOneWidget);
      expect(find.textContaining('الرصيد بعد الحركة: 20 د.ع'), findsOneWidget);
      final (_, repo, metadata) = await setup();
      addTearDown(metadata.dispose);
      final raw = repo.document!.toJson(),
          first = (raw['invoices']! as List).single as Map;
      final invoice2 = {
        ...first.cast<String, Object?>(),
        'id': 'invoice2',
        'number': '2',
        'date': '2026-01-02',
        'lines': [
          for (final line in first['lines'] as List)
            {...(line as Map).cast<String, Object?>(), 'name': 'Wheat'},
        ],
      };
      final party = const LegacyAccountCodec().decodeJson({
        ...raw,
        'invoices': [first, invoice2],
      });
      await tester.pumpWidget(
        frame(PartiesSurface(routeId: 'invoices', account: party)),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('ترتيب قوائم المشتريات غير متاح حالياً. بياناتك محفوظة.'),
        findsOneWidget,
      );
      expect(find.text('ترتيب أسماء المواد غير متاح حالياً.'), findsOneWidget);
      var materialCalls = 0;
      await tester.pumpWidget(
        frame(
          PartiesSurface(
            routeId: 'invoices',
            account: party,
            compareText: (a, b) => a.compareTo(b),
            compareMaterialNames: (a, b) {
              materialCalls++;
              return b.compareTo(a);
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      final choice = tester.widget<DakhlSelect<String>>(
        find.widgetWithText(DakhlSelect<String>, 'المادة في القوائم'),
      );
      expect(choice.items.map((i) => i.value), [
        '',
        'Wheat',
        (first['lines'] as List).first['name'],
      ]);
      expect(materialCalls, greaterThan(0));
      expect(tester.takeException(), isNull);
    },
  );
}
