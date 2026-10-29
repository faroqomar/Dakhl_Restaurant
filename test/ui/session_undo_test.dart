import 'package:dakhl_restaurant/app/app.dart';
import 'package:dakhl_restaurant/ui/dakhl_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/preferences_store.dart';

void main() {
  testWidgets(
    'session Undo restores visible date and discount and survives away/back',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        DakhlRestaurantApp(preferencesStore: MemoryPreferencesStore()),
      );
      await tester.pumpAndSettle();
      Finder field(String label) => find.descendant(
        of: find.byWidgetPredicate((w) => w is DakhlField && w.label == label),
        matching: find.byType(TextFormField),
      );
      String text(String label) =>
          tester.widget<TextFormField>(field(label)).controller?.text ?? '';
      Map<String, String> model() => tester
          .widget<Phase01RouteSurface>(find.byType(Phase01RouteSurface))
          .ticketPresentation;
      await tester.enterText(field('خصم · د.ع'), '2,000');
      await tester.pump();
      expect(model()['discount'], '2,000');
      await tester.tap(find.text('تفاصيل الطلب'));
      await tester.tap(find.byTooltip('تراجع'));
      await tester.pumpAndSettle();
      expect(model().containsKey('discount'), isFalse);
      expect(find.widgetWithText(TextFormField, '1,000'), findsOneWidget);
      await tester.enterText(field('تاريخ البيع'), '2026/10/28');
      await tester.pump();
      expect(model()['date'], '2026/10/28');
      await tester.tap(find.text('تفاصيل الطلب'));
      await tester.tap(find.byTooltip('تراجع'));
      await tester.pumpAndSettle();
      expect(model().containsKey('date'), isFalse);
      expect(find.widgetWithText(TextFormField, '2026/10/27'), findsOneWidget);
      await tester.tap(find.widgetWithText(DakhlButton, 'المخزن').first);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(DakhlButton, 'المبيعات').first);
      await tester.pumpAndSettle();
      expect(text('خصم · د.ع'), '1,000');
      expect(text('تاريخ البيع'), '2026/10/27');
      expect(model().containsKey('discount'), isFalse);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'unchanged controlled value does not reset active edits on unrelated rebuild',
    (tester) async {
      var supplied = 'original';
      var status = 'ready';
      late StateSetter update;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                update = setState;
                return Column(
                  children: [
                    DakhlField(
                      label: 'حقل',
                      value: supplied,
                      onChanged: (_) {},
                    ),
                    Text(status),
                  ],
                );
              },
            ),
          ),
        ),
      );
      await tester.enterText(find.byType(TextFormField), 'active edit');
      final editable = tester.widget<EditableText>(find.byType(EditableText));
      editable.controller.selection = const TextSelection.collapsed(offset: 3);
      update(() => status = 'saved');
      await tester.pump();
      expect(find.text('active edit'), findsOneWidget);
      expect(editable.controller.selection.baseOffset, 3);
      update(() => supplied = 'restored');
      await tester.pump();
      expect(find.text('restored'), findsOneWidget);
    },
  );
}
