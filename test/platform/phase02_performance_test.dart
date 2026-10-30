import 'dart:async';
import 'dart:convert';
import 'dart:ui' show FrameTiming;

import 'package:flutter/material.dart';
import 'package:dakhl_restaurant/platform/phase02_performance_main.dart'
    show phase02RasterizedFrame, phase02IsRequestedRasterFrame;

import 'package:flutter_test/flutter_test.dart';
import 'package:dakhl_restaurant/accounts/accounts_repository.dart';
import 'package:dakhl_restaurant/accounts/accounts_view_model.dart';
import 'package:dakhl_restaurant/platform/phase02_performance_scenarios.dart';

import '../accounts/accounts_view_model_test.dart' show FixtureStore;

void main() {
  test('matching raster frame ID accepts earlier vsync and rejects stale IDs', () {
    FrameTiming timing(int id, {int finish = 19000}) => FrameTiming(
      vsyncStart: 1000,
      buildStart: 2000,
      buildFinish: 3000,
      rasterStart: 4000,
      rasterFinish: finish,
      rasterFinishWallTime: 1000000,
      frameNumber: id,
    );
    // Presentation target can be 16000 while this same frame's vsync starts
    // at 1000. Frame identity, rather than cross-phase time, proves freshness.
    expect(phase02IsRequestedRasterFrame(timing(42), 42), isTrue);
    for (final id in [-1, 0, 41, 43]) {
      expect(phase02IsRequestedRasterFrame(timing(id), 42), isFalse);
    }
    expect(phase02IsRequestedRasterFrame(timing(-1), -1), isFalse);
    expect(phase02IsRequestedRasterFrame(timing(42), null), isFalse);
    expect(
      phase02IsRequestedRasterFrame(timing(42, finish: 3999), 42),
      isFalse,
    );
  });
  testWidgets('unchanged benchmark surface paints before raster completion', (
    tester,
  ) async {
    var paints = 0;
    await tester.pumpWidget(
      CustomPaint(
        painter: _CountPaint(() => paints++),
        child: const SizedBox.expand(),
      ),
    );
    final before = paints;
    var frameNumber = 10;
    final pending = phase02RasterizedFrame(
      frameNumberForTesting: () => frameNumber,
    );
    frameNumber = 11;
    await tester.pump(const Duration(milliseconds: 20));
    final stamp = tester.binding.currentSystemFrameTimeStamp.inMicroseconds;
    // Test binding has no native GPU: synthesize timing only to settle the
    // helper future. The actual paint count is the regression assertion.
    tester.binding.platformDispatcher.onReportTimings!([
      FrameTiming(
        vsyncStart: stamp - 16000,
        buildStart: stamp - 15000,
        buildFinish: stamp,
        rasterStart: stamp,
        rasterFinish: stamp + 1,
        rasterFinishWallTime: stamp + 1,
        frameNumber: 11,
      ),
    ]);
    await pending;
    expect(paints, greaterThan(before));
  });
  testWidgets('warm-up and missing IDs wait for a fresh actual frame ID', (
    tester,
  ) async {
    await tester.pumpWidget(const SizedBox.expand());
    var frameNumber = -1;
    var finished = false;
    final pending =
        phase02RasterizedFrame(frameNumberForTesting: () => frameNumber)
            .then((value) {
              finished = true;
              return value;
            });
    await tester.pump(const Duration(milliseconds: 20));
    expect(tester.binding.hasScheduledFrame, isTrue);
    frameNumber = 8;
    await tester.pump(const Duration(milliseconds: 20));
    FrameTiming timing(int id) => FrameTiming(
      vsyncStart: 1000,
      buildStart: 2000,
      buildFinish: 3000,
      rasterStart: 4000,
      rasterFinish: 5000,
      rasterFinishWallTime: 5000,
      frameNumber: id,
    );
    // Synthetic timings settle only this unit binding; native uses real IDs.
    tester.binding.platformDispatcher.onReportTimings!([timing(-1), timing(7)]);
    await tester.pump();
    expect(finished, isFalse);
    tester.binding.platformDispatcher.onReportTimings!([timing(8)]);
    expect(await pending, 5000);
    expect(finished, isTrue);
  });
  testWidgets('missing native frame IDs time out and stop rescheduling', (
    tester,
  ) async {
    await tester.pumpWidget(const SizedBox.expand());
    final pending = phase02RasterizedFrame(frameNumberForTesting: () => -1);
    final expectation = expectLater(pending, throwsA(isA<TimeoutException>()));
    await tester.pump(const Duration(milliseconds: 20));
    await tester.pump(const Duration(seconds: 11));
    await expectation;
    await tester.pump();
    expect(tester.binding.hasScheduledFrame, isFalse);
  });
  test(
    'benchmark diagnostics retain only bounded safe stage/type/state/code',
    () {
      final secret = '/private/account-token?auth=secret';
      final safe = phase02BenchmarkFailure(
        stage: Phase02BenchmarkStage.finalRender,
        error: TimeoutException(secret),
        state: AccountsState.saved,
        failureCode: secret,
      );
      expect(safe, {
        'stage': 'finalRender',
        'errorKind': 'timeout',
        'state': 'saved',
        'failureCode': 'redacted',
      });
      expect(jsonEncode(safe), isNot(contains(secret)));
      expect(
        phase02BenchmarkFailure(
          stage: Phase02BenchmarkStage.operation,
          error: StateError(secret),
          state: AccountsState.commitUnknown,
          failureCode: 'commit_unknown',
        ),
        {
          'stage': 'operation',
          'errorKind': 'state',
          'state': 'commitUnknown',
          'failureCode': 'commit_unknown',
        },
      );
    },
  );
  test('Phase02 arguments reject fabricated cases/unsafe fixture identity', () {
    expect(
      Phase02PerformanceOptions.parse([
        '--case',
        'accounts.save',
        '--iterations',
        '20',
        '--run-id',
        'abc',
        '--fixture',
        'medium',
      ]).fixtureName,
      'medium',
    );
    for (final args in [
      ['--case', 'orders.process'],
      ['--iterations', '0'],
      ['--run-id', '../accounts'],
      ['--fixture', 'real-restaurant'],
    ]) {
      expect(
        () => Phase02PerformanceOptions.parse(args),
        throwsFormatException,
      );
    }
  });
  test('synthetic small/medium fixtures are valid and measurable manifest matches bytes', () {
    for (final name in ['small', 'medium']) {
      final fixture = Phase02Workload.create(name, 'unitfixture');
      expect(fixture.recordCount, name == 'small' ? 10 : 1000);
      expect(fixture.document.sourceVersion, 11);
      expect(fixture.manifest['canonicalBytes'], fixture.canonicalBytes.length);
      expect(jsonDecode(utf8.decode(fixture.legacyBytes))['version'], 1);
      expect(fixture.workspace.held.length, 40);
      expect(fixture.workspace.active, isNotEmpty);
    }
  });
  test(
    'largest bounded synthetic fixture fits independent input/output limits',
    () {
      final fixture = Phase02Workload.create('largest', 'unitfixture');
      expect(fixture.canonicalBytes.length, greaterThan(19 * 1024 * 1024));
      expect(
        fixture.canonicalBytes.length,
        lessThanOrEqualTo(20 * 1024 * 1024),
      );
      expect(fixture.legacyBytes.length, lessThanOrEqualTo(20 * 1024 * 1024));
      expect(fixture.recordCount, 10000);
    },
  );
  test('all six scenarios call actual consumer commands and verify durable outcome', () async {
    for (final operation in phase02PerformanceCases) {
      final fixture = Phase02Workload.create('small', 'unitfixture');
      final store = FixtureStore();
      final model = AccountsViewModel(
        repository: AccountsRepository(store: store),
      );
      await preparePhase02Operation(model, operation, fixture);
      await runPhase02Operation(model, operation, fixture);
      expect(model.state, AccountsState.saved, reason: operation);
      if (operation == 'workspace.save_restore') {
        expect(model.workspace.held.length, 40);
      }
      if (operation == 'accounts.migrate_legacy') {
        expect(model.document!.migrated, isTrue);
      }
      model.dispose();
    }
  });
}

final class _CountPaint extends CustomPainter {
  _CountPaint(this.onPaint);
  final VoidCallback onPaint;
  @override
  void paint(Canvas canvas, Size size) => onPaint();
  @override
  bool shouldRepaint(_CountPaint oldDelegate) => false;
}
