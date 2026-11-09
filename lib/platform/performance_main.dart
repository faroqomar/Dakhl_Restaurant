import 'dart:async';
import 'dart:convert';
import 'dart:developer' show Timeline;
import 'dart:io';
import 'dart:ui' show FramePhase, FrameTiming;

import 'package:flutter/widgets.dart';

import '../app/app.dart';
import '../shell/shell_view_model.dart';
import 'performance_scenarios.dart';

/// Opt-in profile entrypoint, never used by the normal application.
Future<void> main(List<String> arguments) async {
  PerformanceFixture? fixture;
  var operationId = 'invalid';
  void marker(String event, {int? elapsedUs}) {
    stdout.writeln(
      'DAKHL_BENCH ${jsonEncode({'event': event, 'operationId': operationId, 'elapsedUs': ?elapsedUs})}',
    );
  }

  try {
    final options = PerformanceOptions.parse(arguments);
    operationId = options.operationId;
    WidgetsFlutterBinding.ensureInitialized();
    fixture = await PerformanceFixture.create(options.runId);
    final ready = Completer<ShellViewModel>();
    runApp(
      DakhlRestaurantApp(
        preferencesStore: fixture.preferences,
        onShellReady: ready.complete,
      ),
    );
    final model = await ready.future.timeout(const Duration(seconds: 20));
    if (model.bootstrapState != ShellBootstrapState.ready ||
        !model.canNavigate) {
      throw StateError('Shell did not become usable.');
    }
    // The second frame includes routing changes queued by bootstrap. Raster
    // completion is awaited, so ready never denotes a blank/loading frame.
    await _renderedFrame();
    marker('ready');
    marker('start');
    if (operationId == 'app.startup') {
      // Host process spawn->ready is authoritative for startup, not this zero
      // sentinel. The protocol deliberately does not invent Dart launch time.
      marker('sample', elapsedUs: 0);
    } else {
      for (var i = 0; i < options.iterations; i++) {
        final startedUs = Timeline.now;
        int? rasterFinishUs;
        await runPerformanceIteration(
          model,
          operationId,
          i,
          afterFrame: () async {
            rasterFinishUs = await _renderedFrame();
          },
        );
        final finishedUs = rasterFinishUs;
        if (finishedUs == null ||
            finishedUs < startedUs ||
            finishedUs > Timeline.now) {
          throw StateError('Incompatible frame timing clock.');
        }
        marker('sample', elapsedUs: finishedUs - startedUs);
      }
    }
    marker('end');
    await stdout.flush();
    await Future<void>.delayed(const Duration(milliseconds: 100));
    runApp(const SizedBox.shrink());
    await fixture.close();
    fixture = null;
    exit(0);
  } on Object {
    marker('error');
    await stdout.flush();
    await fixture?.close();
    exit(1);
  }
}

Future<int> _renderedFrame() async {
  // endOfFrame waits for the Flutter build/layout/paint pipeline. Raster timings
  // confirm a submitted frame completed on the raster thread too.
  final rasterized = Completer<int>();
  int? requestedVsyncUs;
  void timings(List<FrameTiming> timings) {
    final target = requestedVsyncUs;
    if (target != null &&
        timings.any(
          (frame) =>
              frame.timestampInMicroseconds(FramePhase.vsyncStart) >= target,
        ) &&
        !rasterized.isCompleted) {
      final frame = timings.firstWhere(
        (frame) =>
            frame.timestampInMicroseconds(FramePhase.vsyncStart) >= target,
      );
      rasterized.complete(
        frame.timestampInMicroseconds(FramePhase.rasterFinish),
      );
    }
  }

  WidgetsBinding.instance.addTimingsCallback(timings);
  try {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      requestedVsyncUs =
          WidgetsBinding.instance.currentSystemFrameTimeStamp.inMicroseconds;
    });
    await WidgetsBinding.instance.endOfFrame;
    return await rasterized.future.timeout(const Duration(seconds: 5));
  } finally {
    WidgetsBinding.instance.removeTimingsCallback(timings);
  }
}
