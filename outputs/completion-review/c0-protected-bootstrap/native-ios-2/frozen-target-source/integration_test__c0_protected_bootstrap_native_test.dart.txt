import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'support/c0_protected_bootstrap_scenarios.dart';
import 'support/native_app_readiness.dart';

/// Only marked synthetic temporary stores. No normal main/location factory.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final results = <Map<String, Object?>>[];
  for (final id in c0BootstrapCases) {
    testWidgets('C0 protected real-store bootstrap: $id', (tester) async {
      final result = await runC0BootstrapCase(
        tester,
        id,
        nativeFrames: LiveNativeAppReadinessFrames(binding),
      );
      results.add(result);
      binding.reportData = {
        'cases': results,
        'surface': 'native;marked isolated fixtures only',
      };
      debugPrint('C0_BOOTSTRAP_RESULT ${jsonEncode(result)}');
    }, timeout: const Timeout(Duration(minutes: 3)));
  }
}
