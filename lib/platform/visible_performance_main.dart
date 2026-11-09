import 'dart:convert';
import 'dart:developer' show Timeline;
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../ui/theme.dart';
import 'phase02_performance_main.dart' show phase02RasterizedFrame;
import 'visible_performance_scenarios.dart';

/// Opt-in real-surface producer. Never resolves normal restaurant storage.
Future<void> main(List<String> arguments) async {
  VisiblePerformanceFixture? fixture;
  var operation = 'invalid';
  final previousErrorHandler = FlutterError.onError;
  var renderingFailed = false;
  void marker(String event, {int? elapsedUs}) => stdout.writeln(
    'DAKHL_BENCH ${jsonEncode({'event': event, 'operationId': operation, 'elapsedUs': ?elapsedUs})}',
  );
  try {
    final options = VisiblePerformanceOptions.parse(arguments);
    operation = options.operationId;
    WidgetsFlutterBinding.ensureInitialized();
    FlutterError.onError = (details) {
      renderingFailed = true;
      previousErrorHandler?.call(details);
    };
    // One unmeasured warm-up uses the same command/render/reopen lifecycle.
    for (var iteration = -1; iteration < options.iterations; iteration++) {
      fixture = await VisiblePerformanceFixture.create(
        options.runId,
        operation,
      );
      runApp(
        MaterialApp(
          key: ValueKey(iteration),
          theme: DakhlTheme.light,
          locale: const Locale('ar'),
          supportedLocales: const [Locale('ar')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: Scaffold(body: fixture.surface()),
        ),
      );
      await phase02RasterizedFrame(bootstrap: true);
      _verifyViewport();
      if (renderingFailed) {
        throw StateError('Visible surface failed to render.');
      }
      if (iteration == 0) {
        marker('ready');
        marker('start');
      }
      final started = Timeline.now;
      await fixture.run();
      final finished = await phase02RasterizedFrame();
      _verifyViewport();
      if (renderingFailed) {
        throw StateError('Visible surface failed to render.');
      }
      if (finished < started || finished > Timeline.now) {
        throw StateError('Incompatible visible raster clock.');
      }
      fixture.verifyRendered();
      runApp(const SizedBox.shrink());
      await WidgetsBinding.instance.endOfFrame;
      await fixture.verifyDurable();
      if (iteration >= 0) marker('sample', elapsedUs: finished - started);
      await fixture.close();
      fixture = null;
    }
    marker('end');
    await stdout.flush();
    await Future<void>.delayed(const Duration(milliseconds: 100));
    FlutterError.onError = previousErrorHandler;
    exit(0);
  } on Object {
    marker('error');
    await stdout.flush();
    try {
      runApp(const SizedBox.shrink());
      await fixture?.close().timeout(const Duration(seconds: 10));
    } on Object {
      /* Preserve the original protocol failure. */
    }
    FlutterError.onError = previousErrorHandler;
    exit(1);
  }
}

/// Finite current macOS fixture: the project XIB opens an 800×600 content view.
/// Refuse a resized/non-Retina viewport rather than compare different raster work.
void _verifyViewport() {
  final views = WidgetsBinding.instance.platformDispatcher.views;
  if (views.length != 1) {
    throw StateError('Ambiguous benchmark viewport.');
  }
  final view = views.single;
  final logical = view.physicalSize / view.devicePixelRatio;
  if (logical != const Size(800, 600) || view.devicePixelRatio != 2) {
    throw StateError('Unsupported visible benchmark viewport.');
  }
}
