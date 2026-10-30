import 'dart:async';
import 'dart:convert';
import 'dart:io';
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
  test('foreign matching-name valid manifest grants no diagnostic ownership', () async {
    final temporary = await Directory.systemTemp.createTemp(
      'phase02-diagnostic-',
    );
    final directory = Directory(await temporary.resolveSymbolicLinks());
    addTearDown(() => directory.delete(recursive: true));
    final file = File(
      '${directory.path}/accounts.open-small-aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.json',
    );
    final workload = Phase02Workload.create(
      'small',
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
    );
    await file.writeAsString(jsonEncode(workload.manifest));
    final original = await file.readAsBytes();
    final options = Phase02PerformanceOptions.parse([
      '--run-id',
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      '--fixture-manifest',
      file.path,
    ]);
    final context = phase02FailureArtifact(
      options: options,
      stage: Phase02BenchmarkStage.manifest,
      error: const FileSystemException('exclusive create refused'),
      attemptedIteration: 0,
      completedSampleCount: 0,
    );
    await expectLater(
      writePhase02FixtureManifest(options, workload),
      throwsA(isA<FileSystemException>()),
    );
    expect(await writePhase02FailureArtifact(options, context), isFalse);
    expect(await file.readAsBytes(), original);
    expect(await File('${file.path}.failure.json').exists(), isFalse);
  });
  test('pre-ownership failure refuses an unproven artifact destination', () async {
    final temporary = await Directory.systemTemp.createTemp(
      'phase02-diagnostic-',
    );
    final directory = Directory(await temporary.resolveSymbolicLinks());
    addTearDown(() => directory.delete(recursive: true));
    final manifest = File(
      '${directory.path}/accounts.open-small-aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.json',
    );
    final options = Phase02PerformanceOptions.parse([
      '--run-id',
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      '--fixture-manifest',
      manifest.path,
    ]);
    final context = phase02FailureArtifact(
      options: options,
      stage: Phase02BenchmarkStage.workload,
      error: const FormatException('secret'),
      attemptedIteration: 0,
      completedSampleCount: 0,
    );
    expect(await writePhase02FailureArtifact(options, context), isFalse);
    expect(await manifest.exists(), isFalse);
    expect(await File('${manifest.path}.failure.json').exists(), isFalse);
  });
  test('failure artifact captures safe attempt context and rejects bounds', () {
    final options = Phase02PerformanceOptions.parse([
      '--case',
      'accounts.migrate_legacy',
      '--fixture',
      'medium',
      '--iterations',
      '20',
      '--run-id',
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
    ]);
    final context = phase02FailureArtifact(
      options: options,
      stage: Phase02BenchmarkStage.finalRender,
      error: TimeoutException('/private/secret?auth=token'),
      attemptedIteration: 3,
      completedSampleCount: 2,
      state: AccountsState.saved,
      failureCode: '/private/secret',
    );
    expect(context['attemptedIteration'], 3);
    expect(context['completedSampleCount'], 2);
    expect(context['errorKind'], 'timeout');
    expect(context['failureCode'], 'redacted');
    expect(jsonEncode(context), isNot(contains('secret')));
    for (final counts in [
      [-1, 0],
      [21, 20],
      [2, 3],
      [3, 0],
    ]) {
      expect(
        () => phase02FailureArtifact(
          options: options,
          stage: Phase02BenchmarkStage.operation,
          error: StateError('secret'),
          attemptedIteration: counts[0],
          completedSampleCount: counts[1],
        ),
        throwsFormatException,
      );
    }
  });
  test('owned failure artifact is exclusive and preserves original manifest', () async {
    final temporary = await Directory.systemTemp.createTemp(
      'phase02-diagnostic-',
    );
    final directory = Directory(await temporary.resolveSymbolicLinks());
    addTearDown(() => directory.delete(recursive: true));
    final file = File(
      '${directory.path}/accounts.migrate_legacy-medium-aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.json',
    );
    final options = Phase02PerformanceOptions.parse([
      '--case',
      'accounts.migrate_legacy',
      '--fixture',
      'medium',
      '--run-id',
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      '--fixture-manifest',
      file.path,
    ]);
    final binding = await writePhase02FixtureManifest(
      options,
      Phase02Workload.create('medium', options.runId),
    );
    final original = await file.readAsBytes();
    final context = phase02FailureArtifact(
      options: options,
      stage: Phase02BenchmarkStage.operation,
      error: StateError('private payload'),
      attemptedIteration: 1,
      completedSampleCount: 0,
      state: AccountsState.failed,
      failureCode: 'unavailable',
    );
    expect(
      await writePhase02FailureArtifact(options, context, binding: binding),
      isTrue,
    );
    final sidecar = File('${file.path}.failure.json');
    final bytes = await sidecar.readAsBytes();
    expect(jsonDecode(utf8.decode(bytes)), context);
    expect(
      await writePhase02FailureArtifact(options, context, binding: binding),
      isFalse,
    );
    expect(await sidecar.readAsBytes(), bytes);
    expect(await file.readAsBytes(), original);
  });
  test('owned failure capture refuses private fields, changed original and links', () async {
    final temporary = await Directory.systemTemp.createTemp(
      'phase02-diagnostic-',
    );
    final directory = Directory(await temporary.resolveSymbolicLinks());
    addTearDown(() => directory.delete(recursive: true));
    final file = File(
      '${directory.path}/accounts.open-small-aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.json',
    );
    final options = Phase02PerformanceOptions.parse([
      '--run-id',
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      '--fixture-manifest',
      file.path,
    ]);
    final binding = await writePhase02FixtureManifest(
      options,
      Phase02Workload.create('small', options.runId),
    );
    final originalBytes = await file.readAsBytes();
    final context = phase02FailureArtifact(
      options: options,
      stage: Phase02BenchmarkStage.prepare,
      error: StateError('secret'),
      attemptedIteration: 1,
      completedSampleCount: 0,
    );
    expect(
      await writePhase02FailureArtifact(options, {
        ...context,
        'payload': 'secret',
      }, binding: binding),
      isFalse,
    );
    final preserved = File('${directory.path}/original');
    await preserved.writeAsString('keep');
    await file.delete();
    final link = Link(file.path);
    await link.create(preserved.path);
    expect(
      await writePhase02FailureArtifact(options, context, binding: binding),
      isFalse,
    );
    expect(await preserved.readAsString(), 'keep');
    await link.delete();
    await file.writeAsBytes(originalBytes);
    await file.writeAsString('foreign changed manifest');
    expect(
      await writePhase02FailureArtifact(options, context, binding: binding),
      isFalse,
    );
    expect(await file.readAsString(), 'foreign changed manifest');
    expect(await File('${file.path}.failure.json').exists(), isFalse);
  });
  test(
    'owned failure artifact refuses foreign names and sidecar/ancestor links',
    () async {
      final temporary = await Directory.systemTemp.createTemp(
        'phase02-diagnostic-',
      );
      final directory = Directory(await temporary.resolveSymbolicLinks());
      addTearDown(() => directory.delete(recursive: true));
      final owned = await Directory('${directory.path}/owned').create();
      final name = 'accounts.save-small-aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.json';
      final file = File('${owned.path}/$name');
      Phase02PerformanceOptions options(String path) =>
          Phase02PerformanceOptions.parse([
            '--case',
            'accounts.save',
            '--run-id',
            'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
            '--fixture-manifest',
            path,
          ]);
      final selected = options(file.path);
      final binding = await writePhase02FixtureManifest(
        selected,
        Phase02Workload.create('small', selected.runId),
      );
      final original = await file.readAsBytes();
      final context = phase02FailureArtifact(
        options: selected,
        stage: Phase02BenchmarkStage.prepare,
        error: StateError('secret'),
        attemptedIteration: 1,
        completedSampleCount: 0,
      );
      final preserved = File('${directory.path}/preserved');
      await preserved.writeAsString('keep');
      final sidecar = Link('${file.path}.failure.json');
      await sidecar.create(preserved.path);
      expect(
        await writePhase02FailureArtifact(selected, context, binding: binding),
        isFalse,
      );
      expect(await preserved.readAsString(), 'keep');
      await sidecar.delete();
      final wrong = File('${directory.path}/foreign.json');
      await wrong.writeAsString('keep');
      expect(
        await writePhase02FailureArtifact(
          options(wrong.path),
          context,
          binding: binding,
        ),
        isFalse,
      );
      expect(await File('${wrong.path}.failure.json').exists(), isFalse);
      final moved = await owned.rename('${directory.path}/moved');
      final alias = Link(owned.path);
      await alias.create(moved.path);
      expect(
        await writePhase02FailureArtifact(selected, context, binding: binding),
        isFalse,
      );
      expect(await File('${moved.path}/$name').readAsBytes(), original);
      await alias.delete();
      await moved.rename(owned.path);
      expect(await File('${file.path}.failure.json').exists(), isFalse);
    },
  );
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
