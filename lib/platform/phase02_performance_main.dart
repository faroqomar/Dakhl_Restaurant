import 'dart:async';
import 'dart:convert';
import 'dart:developer' show Timeline;
import 'dart:io';
import 'dart:ui' show FramePhase, FrameTiming;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../accounts/accounts_surface.dart';
import '../ui/theme.dart';
import 'phase02_performance_scenarios.dart';

/// Opt-in synthetic Phase02 profile process, never the normal app entrypoint.
Future<void> main(List<String> arguments) async {
  var operation = 'invalid';
  var stage = Phase02BenchmarkStage.arguments;
  Phase02PerformanceFixture? current;
  void marker(String event, {int? elapsedUs}) => stdout.writeln(
    'DAKHL_BENCH ${jsonEncode({'event': event, 'operationId': operation, 'elapsedUs': ?elapsedUs})}',
  );
  try {
    final options = Phase02PerformanceOptions.parse(arguments);
    operation = options.operationId;
    WidgetsFlutterBinding.ensureInitialized();
    stage = Phase02BenchmarkStage.workload;
    final workload = Phase02Workload.create(options.fixtureName, options.runId);
    if (options.manifestPath case final String path) {
      stage = Phase02BenchmarkStage.manifest;
      final file = File(path);
      await file.create(exclusive: true);
      await file.writeAsString(jsonEncode(workload.manifest), flush: true);
    }
    for (var i = 0; i < options.iterations; i++) {
      stage = Phase02BenchmarkStage.prepare;
      current = await Phase02PerformanceFixture.create(
        options.runId,
        operation,
        workload,
      );
      runApp(
        MaterialApp(
          key: ValueKey(i),
          theme: DakhlTheme.light,
          locale: const Locale('ar'),
          supportedLocales: const [Locale('ar')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: Scaffold(body: AccountsSurface(model: current.model)),
        ),
      );
      stage = Phase02BenchmarkStage.initialRender;
      await phase02RasterizedFrame();
      if (i == 0) {
        marker('ready');
        marker('start');
      }
      stage = Phase02BenchmarkStage.operation;
      final started = Timeline.now;
      await runPhase02Operation(current.model, operation, workload);
      stage = Phase02BenchmarkStage.finalRender;
      final finished = await phase02RasterizedFrame();
      if (finished < started || finished > Timeline.now) {
        throw StateError('Incompatible raster clock.');
      }
      marker('sample', elapsedUs: finished - started);
      stage = Phase02BenchmarkStage.teardown;
      runApp(const SizedBox.shrink());
      await WidgetsBinding.instance.endOfFrame;
      await current.close();
      current = null;
    }
    stage = Phase02BenchmarkStage.finish;
    marker('end');
    await stdout.flush();
    await Future<void>.delayed(const Duration(milliseconds: 100));
    exit(0);
  } on Object catch (error) {
    stderr.writeln(
      'PHASE02_BENCH_DIAGNOSTIC ${jsonEncode(phase02BenchmarkFailure(stage: stage, error: error, state: current?.model.state, failureCode: current?.model.failureCode))}',
    );
    await stderr.flush();
    marker('error');
    await stdout.flush();
    await current?.close();
    exit(1);
  }
}

Future<int> phase02RasterizedFrame() async {
  final completed = Completer<int>();
  int? requested;
  void timings(List<FrameTiming> values) {
    final target = requested;
    if (target == null || completed.isCompleted) return;
    for (final frame in values) {
      if (frame.timestampInMicroseconds(FramePhase.vsyncStart) >= target) {
        completed.complete(
          frame.timestampInMicroseconds(FramePhase.rasterFinish),
        );
        break;
      }
    }
  }

  WidgetsBinding.instance.addTimingsCallback(timings);
  try {
    // A completed command can leave identical visible state. Force a real
    // final paint so its raster completion exists even when builds coalesce.
    for (final view in WidgetsBinding.instance.renderViews) {
      view.markNeedsPaint();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      requested =
          WidgetsBinding.instance.currentSystemFrameTimeStamp.inMicroseconds;
    });
    await WidgetsBinding.instance.endOfFrame;
    return await completed.future.timeout(const Duration(seconds: 10));
  } finally {
    WidgetsBinding.instance.removeTimingsCallback(timings);
  }
}
