import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dakhl_restaurant/accounting/categories_surface.dart';
import 'package:dakhl_restaurant/ui/theme.dart';

import 'categories_view_model_test.dart' show setupFixture;

void main() {
  testWidgets('category route saves custom category through its editor', (
    tester,
  ) async {
    final (store, repository, model) = await setupFixture();
    await tester.pumpWidget(
      MaterialApp(
        theme: DakhlTheme.light,
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: CategoriesSurface(model: model, canWrite: () => true),
          ),
        ),
      ),
    );
    await tester.tap(find.text('إضافة خانة'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'تنظيف خاص');
    await tester.tap(find.text('حفظ الخانة'));
    await tester.pumpAndSettle();
    expect(
      model.allCategories.where((row) => row.name == 'تنظيف خاص'),
      hasLength(1),
    );
    expect(repository.document, isNotNull);
    expect(store.writes, 1);
    expect(find.text('تنظيف خاص'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    model.dispose();
  });
}
