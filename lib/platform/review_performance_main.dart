import 'dart:async';
import 'dart:convert';
import 'dart:developer' show Timeline;
import 'dart:io';

import 'package:flutter/widgets.dart';

import 'review_performance_scenarios.dart';

/// Opt-in macOS profile process, no normal app location or UI measurement.
Future<void> main(List<String> arguments) async {
  ReviewPerformanceFixture? fixture;
  var operation = 'invalid';
  void marker(String event, {int? elapsedUs}) => stdout.writeln(
    'DAKHL_BENCH ${jsonEncode({'event': event, 'operationId': operation, 'elapsedUs': ?elapsedUs})}',
  );
  try {
    final options = ReviewPerformanceOptions.parse(arguments);
    operation = options.operationId;
    WidgetsFlutterBinding.ensureInitialized();
    // One real unmeasured warm-up uses its own disposable adapter. No ready,
    // start or sample marker may escape before verification and cleanup finish.
    fixture = await ReviewPerformanceFixture.create(options.runId, operation);
    await fixture.run();
    await fixture.verifyDurable();
    await fixture.close();
    fixture = null;
    for (var i = 0; i < options.iterations; i++) {
      fixture = await ReviewPerformanceFixture.create(options.runId, operation);
      if (i == 0) {
        marker('ready');
        marker('start');
      }
      final started = Timeline.now;
      await fixture.run();
      final elapsed = Timeline.now - started;
      await fixture.verifyDurable();
      marker('sample', elapsedUs: elapsed);
      await fixture.close();
      fixture = null;
    }
    marker('end');
    await stdout.flush();
    // Host protocol requires time for its final native resource read.
    // This occurs after end and is excluded from operation/resource timing.
    await Future<void>.delayed(const Duration(milliseconds: 100));
    exit(0);
  } on Object {
    marker('error');
    await stdout.flush();
    try {
      await fixture?.close().timeout(const Duration(seconds: 10));
    } on Object {
      /* Preserve failure even when cleanup fails. */
    }
    exit(1);
  }
}
