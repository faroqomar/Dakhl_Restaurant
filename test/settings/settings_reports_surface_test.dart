import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dakhl_restaurant/accounts/accounts_repository.dart';
import 'package:dakhl_restaurant/accounts/legacy_account_codec.dart';
import 'package:dakhl_restaurant/reports/reports_surface.dart';
import 'package:dakhl_restaurant/reports/reports_view_model.dart';
import 'package:dakhl_restaurant/settings/account_settings_controller.dart';
import 'package:dakhl_restaurant/settings/settings_surface.dart';
import 'package:dakhl_restaurant/ui/theme.dart';

import '../accounts/accounts_view_model_test.dart' show FixtureStore;

Widget host(Widget child) => MaterialApp(
  theme: DakhlTheme.light,
  home: Directionality(
    textDirection: TextDirection.rtl,
    child: Scaffold(body: child),
  ),
);

void main() {
  testWidgets('workflow settings preserve valid unassigned shortcut slots', (
    tester,
  ) async {
    final repository = AccountsRepository(store: FixtureStore());
    await repository.open();
    final codec = const LegacyAccountCodec();
    final raw = codec.empty().toJson();
    final preferences = Map<String, Object?>.from(raw['preferences']! as Map);
    preferences['shortcuts'] = ['', '', 'sales', '', 'cash', ''];
    await repository.save(
      codec.decodeJson({...raw, 'preferences': preferences}),
    );
    final controller = AccountSettingsController(repository);
    await tester.pumpWidget(
      host(
        SettingsSurface(
          controller: controller,
          dataSurface: const SizedBox.shrink(),
        ),
      ),
    );
    await tester.tap(find.text('البيع والاختصارات'));
    await tester.pumpAndSettle();
    expect(find.text('بدون اختصار'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'narrow settings stage identity, save once and retain account data surface',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final store = FixtureStore();
      final accounts = AccountsRepository(store: store);
      await accounts.open();
      await accounts.save(const LegacyAccountCodec().empty());
      final controller = AccountSettingsController(accounts);
      final pending = <bool>[];
      await tester.pumpWidget(
        host(
          SettingsSurface(
            controller: controller,
            dataSurface: const Center(child: Text('existing-account-recovery')),
            onPendingChanged: pending.add,
          ),
        ),
      );
      await tester.enterText(
        find.byKey(const Key('settings-name')),
        'مطعم محفوظ',
      );
      expect(accounts.document!.preferences.restaurant['name'], '');
      expect(pending.last, true);
      final writes = store.writes;
      await tester.pump();
      await tester.tap(find.byKey(const Key('settings-save')));
      await tester.pumpAndSettle();
      expect(accounts.document!.preferences.restaurant['name'], 'مطعم محفوظ');
      expect(store.writes, writes + 1);
      expect(pending.last, false);
      await tester.ensureVisible(find.text('النسخ والبيانات'));
      await tester.tap(find.text('النسخ والبيانات'));
      await tester.pumpAndSettle();
      expect(find.text('existing-account-recovery'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'narrow statement handles empty data and invalid filters without collation fallback',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repository = AccountsRepository(store: FixtureStore());
      await repository.open();
      await repository.save(const LegacyAccountCodec().empty());
      final model = ReportsViewModel(
        repository,
        compareText: (_, _) => throw StateError('collation_unavailable'),
      );
      addTearDown(model.dispose);
      await tester.pumpWidget(
        host(ReportsSurface(model: model, selectedDate: '2026-11-08')),
      );
      await tester.enterText(find.byType(TextField).first, 'invalid');
      await tester.ensureVisible(find.text('تطبيق التصفية'));
      await tester.tap(find.text('تطبيق التصفية'));
      await tester.pumpAndSettle();
      expect(find.text('اختار فترة صحيحة للتقرير.'), findsOneWidget);
      expect(model.from, '');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('day review checks change no saved record or write count', (
    tester,
  ) async {
    final store = FixtureStore();
    final repository = AccountsRepository(store: store);
    await repository.open();
    await repository.save(const LegacyAccountCodec().empty());
    final model = ReportsViewModel(
      repository,
      compareText: (_, _) => throw StateError('collation_unavailable'),
    );
    addTearDown(model.dispose);
    await tester.pumpWidget(
      host(
        Builder(
          builder: (context) => TextButton(
            onPressed: () =>
                showDayReview(context, model: model, date: '2026-11-08'),
            child: const Text('review'),
          ),
        ),
      ),
    );
    final before = jsonEncode(repository.document!.toJson()),
        writes = store.writes;
    await tester.tap(find.text('review'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Checkbox).first);
    await tester.pump();
    expect(store.writes, writes);
    expect(jsonEncode(repository.document!.toJson()), before);
    expect(tester.takeException(), isNull);
  });
}
