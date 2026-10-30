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
  Phase02PerformanceOptions? options;
  Phase02FailureBinding? failureBinding;
  var attemptedIteration = 0, completedSampleCount = 0;
  void marker(String event, {int? elapsedUs}) => stdout.writeln(
    'DAKHL_BENCH ${jsonEncode({'event': event, 'operationId': operation, 'elapsedUs': ?elapsedUs})}',
  );
  try {
    options = Phase02PerformanceOptions.parse(arguments);
    operation = options.operationId;
    WidgetsFlutterBinding.ensureInitialized();
    stage = Phase02BenchmarkStage.workload;
    final workload = Phase02Workload.create(options.fixtureName, options.runId);
    if (options.manifestPath != null) {
      stage = Phase02BenchmarkStage.manifest;
      failureBinding = await writePhase02FixtureManifest(options, workload);
    }
    for (var i = 0; i < options.iterations; i++) {
      attemptedIteration = i + 1;
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
      completedSampleCount++;
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
    // Opt-in failure sidecar only. Never let diagnostic capture mask the
    // original protocol error or change successful measurement semantics.
    try {
      if (options != null) {
        await writePhase02FailureArtifact(
          options,
          phase02FailureArtifact(
            options: options,
            stage: stage,
            error: error,
            attemptedIteration: attemptedIteration,
            completedSampleCount: completedSampleCount,
            state: current?.model.state,
            failureCode: current?.model.failureCode,
          ),
          binding: failureBinding,
        );
      }
    } on Object {
      // Retain the original failure even if bounded metadata cannot be built.
    }
    marker('error');
    await stdout.flush();
    await current?.close();
    exit(1);
  }
}

/// Match the engine recorder identity and ordered phases of the requested real
/// frame. Presentation-target time is a different phase from vsync start.
bool phase02IsRequestedRasterFrame(FrameTiming frame, int? requested) {
  if (requested == null || requested < 0 || frame.frameNumber != requested) {
    return false;
  }
  final timestamps = [
    for (final phase in [
      FramePhase.vsyncStart,
      FramePhase.buildStart,
      FramePhase.buildFinish,
      FramePhase.rasterStart,
      FramePhase.rasterFinish,
    ])
      frame.timestampInMicroseconds(phase),
  ];
  return timestamps.first >= 0 &&
      List.generate(
        timestamps.length - 1,
        (i) => timestamps[i] <= timestamps[i + 1],
      ).every((ordered) => ordered);
}

/// Native callers use the SDK's actual frameData identity. The optional ID
/// provider supports test bindings which do not have an engine/GPU recorder.
Future<int> phase02RasterizedFrame({
  int Function()? frameNumberForTesting,
}) async {
  final binding = WidgetsBinding.instance;
  final frameNumber =
      frameNumberForTesting ??
      () => binding.platformDispatcher.frameData.frameNumber;
  final previous = frameNumber();
  final completed = Completer<int>();
  int? requested;
  var active = true;
  void repaint() {
    // A completed command can leave identical visible state. Force a real
    // final paint so its raster completion exists even when builds coalesce.
    for (final view in binding.renderViews) {
      view.markNeedsPaint();
    }
  }

  void requestFrame(Duration _) {
    if (!active || completed.isCompleted) return;
    final current = frameNumber();
    if (current >= 0 && current > previous) {
      requested = current;
      return;
    }
    // A warm-up frame has no new native recorder ID. Request a real frame;
    // the whole wait remains bounded, including this retry.
    repaint();
    binding.addPostFrameCallback(requestFrame);
    binding.scheduleFrame();
  }

  void timings(List<FrameTiming> values) {
    if (!active || completed.isCompleted) return;
    for (final frame in values) {
      if (phase02IsRequestedRasterFrame(frame, requested)) {
        completed.complete(
          frame.timestampInMicroseconds(FramePhase.rasterFinish),
        );
        break;
      }
    }
  }

  binding.addTimingsCallback(timings);
  try {
    repaint();
    binding.addPostFrameCallback(requestFrame);
    return await (() async {
      await binding.endOfFrame;
      return completed.future;
    })().timeout(const Duration(seconds: 10));
  } finally {
    active = false;
    binding.removeTimingsCallback(timings);
  }
}
