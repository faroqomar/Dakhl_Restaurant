import 'dart:convert';
import 'dart:io';

import 'package:dakhl_restaurant/app/source_collation_runtime.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:madar_application/madar_application.dart';
import 'package:madar_icu_collation/testing.dart';

/// Native-asset acceptance only. No application store, preferences, account
/// records or copied engine corpus enter this test.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('bundled ICU corpus and restaurant source-profile lifecycle', (
    tester,
  ) async {
    final conformance = verifyBundledIcuConformance();
    expect(conformance.comparedPairs, 1506);
    expect(conformance.oraclePairs, 1384);
    expect(conformance.independentPairs, 122);
    expect(conformance.edgeChecks, 20);

    final runtime = SourceCollationRuntime.loadBundled();
    expect(
      runtime,
      isNotNull,
      reason: 'This target must resolve the reviewed bundled native asset.',
    );
    final value = runtime!;
    addTearDown(value.close);
    expect(value.events.profile, CollationProfile.enUs);
    expect(value.materialNames.profile, CollationProfile.ar);
    expect(identical(value.events, value.materialNames), isFalse);
    expect(value.events.compare('caf\u00e9', 'cafe\u0301'), 0);
    expect(value.materialNames.compare('ماء', 'ماء'), 0);
    expect(value.events.compare('a\u0000b', 'a\u0000c'), lessThan(0));
    expect(
      () => value.materialNames.compare(String.fromCharCode(0xd800), 'ماء'),
      throwsA(isA<CollationInvalidInputException>()),
    );
    value.close();
    value.close();
    expect(
      () => value.events.compare('a', 'b'),
      throwsA(isA<CollationClosedException>()),
    );
    expect(
      () => value.materialNames.compare('ماء', 'ملح'),
      throwsA(isA<CollationClosedException>()),
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: Center(child: Text('ICU: 1506 comparisons, 20 edge checks')),
          ),
        ),
      ),
    );
    expect(find.text('ICU: 1506 comparisons, 20 edge checks'), findsOneWidget);
    expect(tester.takeException(), isNull);
    binding.reportData = {
      'case': 'bundled-icu-native',
      'operatingSystem': Platform.operatingSystem,
      'operatingSystemVersion': Platform.operatingSystemVersion,
      'conformance': conformance.toJson(),
      'consumerProfiles': ['en-US', 'ar'],
      'consumerChecks': [
        'distinct-explicit-profiles',
        'normalization',
        'arabic-comparison',
        'embedded-nul',
        'invalid-utf16-refusal',
        'idempotent-parent-close',
        'both-sessions-closed',
      ],
      'accountStorageAccessed': false,
    };
    debugPrint(jsonEncode(binding.reportData));
  });
}
