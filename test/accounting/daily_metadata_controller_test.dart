import 'package:flutter_test/flutter_test.dart';
import 'package:madar_application/madar_application.dart';
import 'package:dakhl_restaurant/accounting/daily_metadata_controller.dart';
import 'package:dakhl_restaurant/accounting/daily_cash_queries.dart';

import 'categories_view_model_test.dart' show setupFixture;

void main() {
  test(
    'chicken update preserves financial records and rejects stale editor',
    () async {
      final (store, repository, model) = await setupFixture();
      addTearDown(model.dispose);
      final before = repository.document!;
      final controller = DailyMetadataController(repository);
      final stale = DailyMetadataController(repository);
      expect(
        await controller.saveChicken(date: '2026-03-01', used: '١٢', left: '٨'),
        isA<CapabilitySuccess<void>>(),
      );
      final after = repository.document!;
      expect(after.days['2026-03-01'], containsPair('chickenUsed', 12));
      expect(after.days['2026-03-01'], containsPair('chickenLeft', 8));
      final oldDay = Map<String, Object?>.from(
        before.days['2026-03-01']! as Map,
      );
      final newDay = Map<String, Object?>.from(
        after.days['2026-03-01']! as Map,
      );
      for (final key in ['chickenUsed', 'chickenLeft']) {
        oldDay.remove(key);
        newDay.remove(key);
      }
      expect(newDay, oldDay);
      for (final entry in before.toJson().entries) {
        if (entry.key != 'days') expect(after.toJson()[entry.key], entry.value);
      }
      expect(
        DailyCashQueries(after).day('2026-03-01').dailySpent,
        DailyCashQueries(before).day('2026-03-01').dailySpent,
      );
      final writes = store.writes;
      expect(
        (await stale.saveChicken(
          date: '2026-03-01',
          used: '1',
          left: '1',
        ) as CapabilityFailure).code,
        'stale_revision',
      );
      expect(store.writes, writes);
    },
  );
}
