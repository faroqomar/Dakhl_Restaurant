import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../integration_test/support/c0_protected_bootstrap_scenarios.dart';

void main() {
  for (final id in c0BootstrapCases) {
    testWidgets('C0 protected real-store HOST preparation: $id', (
      tester,
    ) async {
      final result = await runC0BootstrapCase(tester, id);
      debugPrint('C0_BOOTSTRAP_HOST_RESULT ${jsonEncode(result)}');
      expect(result['status'], anyOf('passed', 'unavailable'));
    }, timeout: const Timeout(Duration(minutes: 3)));
  }
}
