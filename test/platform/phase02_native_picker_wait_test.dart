import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import '../../integration_test/support/native_picker_wait.dart';

final class _Frames implements NativePickerFrames {
  @override
  LiveTestWidgetsFlutterBindingFramePolicy framePolicy =
      LiveTestWidgetsFlutterBindingFramePolicy.fadePointers;
  bool get live =>
      framePolicy == LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  bool get restored =>
      framePolicy == LiveTestWidgetsFlutterBindingFramePolicy.fadePointers &&
      !shouldPropagateDevicePointerEvents;
  bool enabled = true;
  bool pending = false;
  @override
  bool shouldPropagateDevicePointerEvents = false;
  void Function()? afterSchedule;
  void Function()? onFramesEnabledRead;
  int requests = 0;
  @override
  bool get framesEnabled {
    onFramesEnabledRead?.call();
    return enabled;
  }

  @override
  bool get framePending => pending;
  @override
  void scheduleFrame() {
    requests++;
    pending = true;
    afterSchedule?.call();
  }
}

Future<void> _withTrackedRealTimers(
  Future<void> Function(List<Timer> timers) body,
) => runZoned(() async {
  final timers = <Timer>[];
  await runZoned(
    () => body(timers),
    zoneSpecification: ZoneSpecification(
      createTimer: (self, parent, zone, duration, callback) {
        final timer = parent.createTimer(zone, duration, callback);
        timers.add(timer);
        return timer;
      },
      createPeriodicTimer: (self, parent, zone, duration, callback) {
        final timer = parent.createPeriodicTimer(zone, duration, callback);
        timers.add(timer);
        return timer;
      },
    ),
  );
  expect(timers.where((timer) => timer.isActive), isEmpty);
});

void main() {
  // Plain tests deliberately use the actual event loop and Stopwatch, rather
  // than testWidgets/FakeAsync's simulated pump clock.
  for (final previous in [false, true]) {
    for (final outcome in ['success', 'error', 'timeout']) {
      test(
        'manual touch enabled then restores $previous after $outcome',
        () => _withTrackedRealTimers((timers) async {
          final frames = _Frames()
            ..shouldPropagateDevicePointerEvents = previous
            ..framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.onlyPumps;
          frames.afterSchedule = () => Timer.run(() => frames.pending = false);
          final failure = StateError('native confirmation observation failed');
          final pending = waitForNativePickerCondition(
            frames: frames,
            settled: () {
              expect(frames.shouldPropagateDevicePointerEvents, isTrue);
              expect(
                frames.framePolicy,
                LiveTestWidgetsFlutterBindingFramePolicy.fullyLive,
              );
              if (outcome == 'error') throw failure;
              return outcome == 'success';
            },
            label: 'manual confirmation',
            timeout: outcome == 'timeout'
                ? const Duration(milliseconds: 20)
                : const Duration(seconds: 1),
            pollInterval: const Duration(milliseconds: 2),
          );
          if (outcome == 'error') {
            await expectLater(pending, throwsA(same(failure)));
          } else if (outcome == 'timeout') {
            await expectLater(pending, throwsA(isA<TimeoutException>()));
          } else {
            await pending;
          }
          expect(frames.shouldPropagateDevicePointerEvents, previous);
          expect(
            frames.framePolicy,
            LiveTestWidgetsFlutterBindingFramePolicy.onlyPumps,
          );
          expect(frames.live, isFalse);
        }),
      );
    }
  }

  test(
    'paused engine frame cannot hold the wait beyond its real budget',
    () => _withTrackedRealTimers((timers) async {
      final frames = _Frames();
      final wall = Stopwatch()..start();
      await expectLater(
        waitForNativePickerCondition(
          frames: frames,
          settled: () => true,
          label: 'blocked engine frame',
          timeout: const Duration(milliseconds: 60),
          pollInterval: const Duration(milliseconds: 5),
        ),
        throwsA(isA<TimeoutException>()),
      );
      expect(
        wall.elapsed,
        greaterThanOrEqualTo(const Duration(milliseconds: 60)),
      );
      expect(wall.elapsed, lessThan(const Duration(seconds: 2)));
      expect(frames.requests, 1);
      expect(frames.pending, isTrue);
      expect(frames.restored, isTrue);
      expect(frames.live, isFalse);
    }),
  );

  test(
    'an early deadline callback waits for the monotonic budget',
    () => _withTrackedRealTimers((timers) async {
      final frames = _Frames();
      final wall = Stopwatch()..start();
      var deliveredEarly = false;
      final future = runZoned(
        () => waitForNativePickerCondition(
          frames: frames,
          settled: () => true,
          label: 'early platform timer',
          timeout: const Duration(milliseconds: 60),
          pollInterval: const Duration(milliseconds: 5),
        ),
        zoneSpecification: ZoneSpecification(
          createTimer: (self, parent, zone, duration, callback) {
            if (!deliveredEarly) {
              deliveredEarly = true;
              return parent.createTimer(
                zone,
                const Duration(milliseconds: 10),
                callback,
              );
            }
            return parent.createTimer(zone, duration, callback);
          },
        ),
      );
      await expectLater(future, throwsA(isA<TimeoutException>()));
      expect(deliveredEarly, isTrue);
      expect(
        wall.elapsed,
        greaterThanOrEqualTo(const Duration(milliseconds: 60)),
      );
      expect(wall.elapsed, lessThan(const Duration(seconds: 2)));
      expect(frames.requests, 1);
      expect(frames.restored, isTrue);
    }),
  );

  test(
    'late success is rejected even before a delayed timer callback runs',
    () => _withTrackedRealTimers((timers) async {
      final frames = _Frames();
      await expectLater(
        waitForNativePickerCondition(
          frames: frames,
          settled: () {
            // Deliberately occupy the real isolate beyond the budget. The
            // deadline callback cannot run until this returns true.
            final blockedEventLoop = Stopwatch()..start();
            while (blockedEventLoop.elapsed <
                const Duration(milliseconds: 40)) {}
            return true;
          },
          label: 'late cancellation',
          timeout: const Duration(milliseconds: 20),
        ),
        throwsA(isA<TimeoutException>()),
      );
      expect(frames.requests, 0);
      expect(frames.restored, isTrue);
    }),
  );

  test(
    'timely result waits for a real frame acknowledgement before success',
    () => _withTrackedRealTimers((timers) async {
      final frames = _Frames();
      var settled = false;
      var completed = false;
      final scheduled = Completer<void>();
      frames.afterSchedule = () => scheduled.complete();
      final pending = waitForNativePickerCondition(
        frames: frames,
        settled: () => settled,
        label: 'native result',
        timeout: const Duration(seconds: 1),
        pollInterval: const Duration(milliseconds: 2),
      ).then((_) => completed = true);
      expect(frames.live, isTrue);
      settled = true;
      await scheduled.future.timeout(const Duration(seconds: 2));
      expect(frames.requests, 1);
      expect(completed, isFalse);
      frames.pending = false;
      await pending;
      expect(completed, isTrue);
      expect(frames.restored, isTrue);
    }),
  );

  test(
    'paused lifecycle must resume before the frame can be requested',
    () => _withTrackedRealTimers((timers) async {
      final frames = _Frames()..enabled = false;
      final pausedObserved = Completer<void>();
      final scheduled = Completer<void>();
      frames.onFramesEnabledRead = () {
        if (!frames.enabled && !pausedObserved.isCompleted) {
          pausedObserved.complete();
        }
      };
      frames.afterSchedule = () => scheduled.complete();
      final pending = waitForNativePickerCondition(
        frames: frames,
        settled: () => true,
        label: 'activity resume',
        timeout: const Duration(seconds: 1),
        pollInterval: const Duration(milliseconds: 2),
      );
      await pausedObserved.future.timeout(const Duration(seconds: 2));
      expect(frames.requests, 0);
      frames.enabled = true;
      await scheduled.future.timeout(const Duration(seconds: 2));
      expect(frames.requests, 1);
      frames.pending = false;
      await pending;
    }),
  );

  test(
    'condition errors propagate and retire timers and live frame scope',
    () => _withTrackedRealTimers((timers) async {
      final frames = _Frames();
      final failure = StateError('condition failed');
      await expectLater(
        waitForNativePickerCondition(
          frames: frames,
          settled: () => throw failure,
          label: 'failed transfer',
        ),
        throwsA(same(failure)),
      );
      expect(frames.restored, isTrue);
    }),
  );

  test(
    'timeout retires polling before a later native result arrives',
    () => _withTrackedRealTimers((timers) async {
      final frames = _Frames();
      var reads = 0;
      var settled = false;
      await expectLater(
        waitForNativePickerCondition(
          frames: frames,
          settled: () {
            reads++;
            return settled;
          },
          label: 'native result never arrives',
          timeout: const Duration(milliseconds: 30),
          pollInterval: const Duration(milliseconds: 2),
        ),
        throwsA(isA<TimeoutException>()),
      );
      final readsAtTimeout = reads;
      expect(timers.where((timer) => timer.isActive), isEmpty);
      settled = true;
      await Future<void>.microtask(() {});
      expect(reads, readsAtTimeout);
      expect(frames.requests, 0);
      expect(frames.restored, isTrue);
    }),
  );
}
