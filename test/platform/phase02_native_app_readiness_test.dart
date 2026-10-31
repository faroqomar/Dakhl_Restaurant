import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../integration_test/support/native_app_readiness.dart';

final class _Frames implements NativeAppReadinessFrames {
  @override
  LiveTestWidgetsFlutterBindingFramePolicy framePolicy =
      LiveTestWidgetsFlutterBindingFramePolicy.onlyPumps;
  bool enabled = true;
  bool unrelatedAnimationStillScheduled = true;
  void Function()? onEnabledRead;
  void Function()? onRequest;
  final callbacks = <void Function()>[];
  int requests = 0;
  @override
  bool get framesEnabled {
    onEnabledRead?.call();
    return enabled;
  }

  @override
  void requestFrame(void Function() onRenderedFrame) {
    requests++;
    callbacks.add(onRenderedFrame);
    onRequest?.call();
  }

  void acknowledge() => callbacks.removeAt(0)();
}

Future<void> _tracked(Future<void> Function() body) async {
  final timers = <Timer>[];
  await runZoned(
    body,
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
}

void main() {
  testWidgets(
    'public native root attachment leaves no outstanding tester pump',
    (tester) async {
      mountNativeAppRoot(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: Text('public native root fixture'),
        ),
      );
      await tester.pump();
      expect(find.text('public native root fixture'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  test(
    'actual ready root plus requested frame succeeds while unrelated animation continues',
    () => _tracked(() async {
      final frames = _Frames();
      final requested = Completer<void>();
      frames.onRequest = requested.complete;
      var complete = false;
      final pending = waitForNativeAppReadiness(
        frames: frames,
        mount: () {},
        ready: () => true,
        timeout: const Duration(seconds: 5),
        pollInterval: const Duration(milliseconds: 2),
      ).then((_) => complete = true);
      await requested.future.timeout(const Duration(seconds: 2));
      expect(complete, isFalse);
      expect(frames.unrelatedAnimationStillScheduled, isTrue);
      frames.acknowledge();
      await pending;
      expect(complete, isTrue);
      expect(frames.unrelatedAnimationStillScheduled, isTrue);
      expect(
        frames.framePolicy,
        LiveTestWidgetsFlutterBindingFramePolicy.onlyPumps,
      );
    }),
  );

  test(
    'public attachment returns while native frames are paused without creating a pump wait',
    () => _tracked(() async {
      final frames = _Frames()..enabled = false;
      var attachments = 0;
      final elapsed = Stopwatch()..start();
      final pending = waitForNativeAppReadiness(
        frames: frames,
        mount: () => attachments++,
        ready: () => true,
        timeout: const Duration(milliseconds: 40),
        pollInterval: const Duration(milliseconds: 2),
      );
      expect(attachments, 1);
      await expectLater(pending, throwsA(isA<TimeoutException>()));
      expect(
        elapsed.elapsed,
        greaterThanOrEqualTo(const Duration(milliseconds: 40)),
      );
      expect(elapsed.elapsed, lessThan(const Duration(seconds: 2)));
      expect(frames.requests, 0);
      expect(
        frames.framePolicy,
        LiveTestWidgetsFlutterBindingFramePolicy.onlyPumps,
      );
    }),
  );

  test(
    'unready root does not become success merely because a frame could render',
    () => _tracked(() async {
      final frames = _Frames();
      await expectLater(
        waitForNativeAppReadiness(
          frames: frames,
          mount: () {},
          ready: () => false,
          timeout: const Duration(milliseconds: 30),
          pollInterval: const Duration(milliseconds: 2),
        ),
        throwsA(isA<TimeoutException>()),
      );
      expect(frames.requests, 0);
    }),
  );

  test(
    'late synchronous readiness is rejected before a delayed timeout callback can run',
    () => _tracked(() async {
      final frames = _Frames();
      await expectLater(
        waitForNativeAppReadiness(
          frames: frames,
          mount: () {},
          ready: () {
            final blocked = Stopwatch()..start();
            while (blocked.elapsed < const Duration(milliseconds: 40)) {}
            return true;
          },
          timeout: const Duration(milliseconds: 20),
        ),
        throwsA(isA<TimeoutException>()),
      );
      expect(frames.requests, 0);
    }),
  );

  test(
    'readiness exception retains its identity and restores live policy',
    () => _tracked(() async {
      final frames = _Frames();
      final failure = StateError('fixture observation failure');
      await expectLater(
        waitForNativeAppReadiness(
          frames: frames,
          mount: () {},
          ready: () => throw failure,
        ),
        throwsA(same(failure)),
      );
      expect(
        frames.framePolicy,
        LiveTestWidgetsFlutterBindingFramePolicy.onlyPumps,
      );
    }),
  );

  test(
    'paused lifecycle resumes before requesting the acknowledged root frame',
    () => _tracked(() async {
      final frames = _Frames()..enabled = false;
      final paused = Completer<void>();
      final requested = Completer<void>();
      frames.onEnabledRead = () {
        if (!frames.enabled && !paused.isCompleted) paused.complete();
      };
      frames.onRequest = requested.complete;
      final pending = waitForNativeAppReadiness(
        frames: frames,
        mount: () {},
        ready: () => true,
        timeout: const Duration(seconds: 5),
        pollInterval: const Duration(milliseconds: 2),
      );
      await paused.future.timeout(const Duration(seconds: 2));
      expect(frames.requests, 0);
      frames.enabled = true;
      await requested.future.timeout(const Duration(seconds: 2));
      frames.acknowledge();
      await pending;
    }),
  );

  test(
    'mount exception is not replaced by readiness timeout',
    () => _tracked(() async {
      final frames = _Frames();
      final failure = StateError('fixture mount failure');
      await expectLater(
        waitForNativeAppReadiness(
          frames: frames,
          mount: () => throw failure,
          ready: () => true,
        ),
        throwsA(same(failure)),
      );
      expect(frames.requests, 0);
    }),
  );

  test(
    'missing frame acknowledgement times out and retires late callbacks',
    () => _tracked(() async {
      final frames = _Frames();
      var reads = 0;
      await expectLater(
        waitForNativeAppReadiness(
          frames: frames,
          mount: () {},
          ready: () {
            reads++;
            return true;
          },
          timeout: const Duration(milliseconds: 30),
          pollInterval: const Duration(milliseconds: 2),
        ),
        throwsA(isA<TimeoutException>()),
      );
      final atTimeout = reads;
      frames.acknowledge();
      expect(reads, atTimeout);
      expect(
        frames.framePolicy,
        LiveTestWidgetsFlutterBindingFramePolicy.onlyPumps,
      );
    }),
  );

  test('native readiness never accepts a budget above the existing 45-second bound', () async {
    await expectLater(
      waitForNativeAppReadiness(
        frames: _Frames(),
        mount: () {},
        ready: () => true,
        timeout: const Duration(seconds: 46),
      ),
      throwsArgumentError,
    );
  });
}
