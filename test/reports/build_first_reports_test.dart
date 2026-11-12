import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/foundation.dart';
import 'package:madar_application/madar_application.dart';
import 'package:dakhl_restaurant/accounts/accounts_repository.dart';
import 'package:dakhl_restaurant/accounts/legacy_account_codec.dart';
import 'package:dakhl_restaurant/accounting/daily_cash_queries.dart';
import 'package:dakhl_restaurant/reports/restaurant_report.dart';
import 'package:dakhl_restaurant/reports/restaurant_report_pdf.dart';
import 'package:dakhl_restaurant/reports/reports_view_model.dart';
import 'package:dakhl_restaurant/settings/account_settings_controller.dart';

import '../accounts/accounts_view_model_test.dart' show FixtureStore;

void main() {
  test('seven saved report kinds compose and generate offline PDF bytes', () async {
    final document = const LegacyAccountCodec().decodeJson(
      (jsonDecode(
        File('test/fixtures/legacy/report_account.json').readAsStringSync(),
      ) as Map).cast<String, Object?>(),
    );
    // Fixture has ASCII timestamp/ID keys; this bounded smoke does not qualify
    // the required production ICU comparator or mobile native adapter.
    final composer = RestaurantReportComposer(
      document,
      compareText: (a, b) => a.compareTo(b),
    );
    final reports = [
      composer.daily('2026-10-04'),
      composer.invoice('invoice'),
      composer.sale('sale'),
      composer.sales(),
      composer.statement(source: SpendingSource.cash),
      composer.cash(),
      composer.payment('payment'),
    ];
    expect(
      reports.map((r) => r.kind).toSet(),
      RestaurantReportKind.values.toSet(),
    );
    expect(
      reports[4].sections.first.rows.singleWhere(
        (r) => r[0] == 'حصة اليومي',
      )[1],
      '0',
    );
    final before = jsonEncode(document.toJson());
    final pdf = RestaurantReportPdf(
      loadFont: () async => ByteData.sublistView(
        await File('assets/fonts/Amiri-Regular.ttf').readAsBytes(),
      ),
    );
    for (final report in reports) {
      expect(report.sections, isNotEmpty);
      final generated = await pdf.generate(report);
      expect(
        generated,
        isA<CapabilitySuccess<Uint8List>>(),
        reason: '${report.kind}',
      );
      final bytes = (generated as CapabilitySuccess<Uint8List>).value;
      expect(ascii.decode(bytes.take(5).toList()), '%PDF-');
      expect(bytes.length, greaterThan(1000));
    }
    expect(jsonEncode(document.toJson()), before);
    final repository = AccountsRepository(store: FixtureStore());
    await repository.open();
    await repository.save(const LegacyAccountCodec().empty());
    var projectedAccount = document;
    final updates = ChangeNotifier();
    final reportsModel = ReportsViewModel(
      repository,
      compareText: (a, b) => a.compareTo(b),
      readAccount: () => projectedAccount,
      updates: updates,
    );
    expect(reportsModel.statement.total, greaterThan(BigInt.zero));
    reportsModel.setReviewed('expenses', true);
    projectedAccount = const LegacyAccountCodec().empty();
    updates.notifyListeners();
    expect(reportsModel.statement.total, BigInt.zero);
    expect(reportsModel.reviewedSteps, isEmpty);
    reportsModel.dispose();
    updates.notifyListeners();
    updates.dispose();
  });

  test('workflow operations validate before changing draft and preserve saved data', () async {
    final repository = AccountsRepository(store: FixtureStore());
    await repository.open();
    await repository.save(const LegacyAccountCodec().empty());
    final controller = AccountSettingsController(repository);
    expect(controller.addOrderType(' جديد '), isA<CapabilitySuccess<void>>());
    expect(
      controller.makeDefaultOrderType('جديد'),
      isA<CapabilitySuccess<void>>(),
    );
    expect(controller.defaultOrderType, 'جديد');
    expect(
      controller.renameOrderType('جديد', 'صالة'),
      isA<CapabilityFailure<void>>(),
    );
    expect(controller.defaultOrderType, 'جديد');
    expect(
      controller.setOrderTypeEnabled('جديد', false),
      isA<CapabilitySuccess<void>>(),
    );
    expect(controller.values.disabledOrderTypes, contains('جديد'));
    expect(await controller.save(), isA<CapabilitySuccess<void>>());
    expect(
      repository.document!.preferences.disabledOrderTypes,
      contains('جديد'),
    );
    expect(controller.setShortcut(9, ''), isA<CapabilityFailure<void>>());
  });
}
