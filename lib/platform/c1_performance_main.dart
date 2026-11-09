import 'dart:async';
import 'dart:convert';
import 'dart:developer' show Timeline;
import 'dart:io';

import 'package:flutter/widgets.dart';

import 'c1_performance_scenarios.dart';

/// Opt-in profile producer. Never opens normal app storage or renders UI.
Future<void> main(List<String> arguments) async {
  C1PerformanceFixture? fixture;
  var operation = 'invalid';
  void marker(String event, {int? elapsedUs}) => stdout.writeln(
    'DAKHL_BENCH ${jsonEncode({'event': event, 'operationId': operation, 'elapsedUs': ?elapsedUs})}',
  );
  try {
    final options = C1PerformanceOptions.parse(arguments);
    operation = options.operationId;
    WidgetsFlutterBinding.ensureInitialized();
    fixture = await C1PerformanceFixture.create(options.runId, operation);
    await fixture.run();
    await fixture.verifyDurable();
    await fixture.close();
    fixture = null;
    for (var i = 0; i < options.iterations; i++) {
      fixture = await C1PerformanceFixture.create(options.runId, operation);
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
    // Reviewed host protocol's final native sample, outside reported windows.
    await Future<void>.delayed(const Duration(milliseconds: 100));
    exit(0);
  } on Object {
    marker('error');
    await stdout.flush();
    try {
      await fixture?.close().timeout(const Duration(seconds: 10));
    } on Object {
      // Keep the original measurement failure; no private payload is printed.
    }
    exit(1);
  }
}
