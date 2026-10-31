import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Test-only native frame observation; global animation quiescence is irrelevant.
abstract interface class NativeAppReadinessFrames {
  LiveTestWidgetsFlutterBindingFramePolicy get framePolicy;
  set framePolicy(LiveTestWidgetsFlutterBindingFramePolicy value);
  bool get framesEnabled;
  void requestFrame(void Function() onRenderedFrame);
}

final class LiveNativeAppReadinessFrames implements NativeAppReadinessFrames {
  LiveNativeAppReadinessFrames(this.binding);
  final LiveTestWidgetsFlutterBinding binding;
  @override
  LiveTestWidgetsFlutterBindingFramePolicy get framePolicy =>
      binding.framePolicy;
  @override
  set framePolicy(LiveTestWidgetsFlutterBindingFramePolicy value) =>
      binding.framePolicy = value;
  @override
  bool get framesEnabled => binding.framesEnabled;
  @override
  void requestFrame(void Function() onRenderedFrame) {
    binding.addPostFrameCallback((_) => onRenderedFrame());
    binding.scheduleFrame();
  }
}

/// Public framework attachment does not create WidgetTester's private pump
/// future. The readiness observer below owns the bounded frame acknowledgement.
void mountNativeAppRoot(Widget root) => runApp(root);

/// Mount and observe an actual ready root plus a subsequently rendered frame.
///
/// The monotonic budget includes mount, lifecycle suspension, observation and
/// frame acknowledgement. A cursor/animation may continue scheduling frames.
/// Root attachment is synchronous and uses public runApp rather than an awaited
/// tester pump. Timers and frame policy retire on every exit; late frame
/// callbacks cannot request work or turn a timeout into success.
Future<void> waitForNativeAppReadiness({
  required NativeAppReadinessFrames frames,
  required void Function() mount,
  required bool Function() ready,
  Duration timeout = const Duration(seconds: 45),
  Duration pollInterval = const Duration(milliseconds: 100),
}) async {
  if (timeout <= Duration.zero || timeout > const Duration(seconds: 45)) {
    throw ArgumentError.value(timeout, 'timeout', 'Must be within 45 seconds.');
  }
  if (pollInterval <= Duration.zero) {
    throw ArgumentError.value(
      pollInterval,
      'pollInterval',
      'Must be positive.',
    );
  }
  final previous = frames.framePolicy;
  final elapsed = Stopwatch()..start();
  final completed = Completer<void>();
  Timer? deadlineTimer, pollTimer;
  var active = true, requested = false, rendered = false;
  var frameGeneration = 0;

  void finish([Object? error, StackTrace? stack]) {
    if (completed.isCompleted) return;
    deadlineTimer?.cancel();
    pollTimer?.cancel();
    if (error == null) {
      completed.complete();
    } else {
      completed.completeError(error, stack);
    }
  }

  bool expired() {
    if (elapsed.elapsed < timeout) return false;
    finish(
      TimeoutException(
        'Native app readiness exceeded its frame budget.',
        timeout,
      ),
    );
    return true;
  }

  void observe() {
    if (!active || completed.isCompleted || expired()) return;
    try {
      final rootReady = ready();
      if (expired()) return;
      if (!rootReady) {
        requested = rendered = false;
        frameGeneration++;
        return;
      }
      if (!frames.framesEnabled) return;
      if (!requested) {
        requested = true;
        final generation = ++frameGeneration;
        frames.requestFrame(() {
          if (!active ||
              completed.isCompleted ||
              generation != frameGeneration) {
            return;
          }
          rendered = true;
          observe();
        });
        return;
      }
      if (rendered && !expired()) finish();
    } catch (error, stack) {
      finish(error, stack);
    }
  }

  void armDeadline() {
    if (completed.isCompleted || expired()) return;
    final remaining = timeout - elapsed.elapsed;
    // Timer delivery is only a wakeup; the monotonic clock owns the budget.
    deadlineTimer = Timer(
      remaining < const Duration(milliseconds: 1)
          ? const Duration(milliseconds: 1)
          : remaining,
      armDeadline,
    );
  }

  try {
    frames.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
    armDeadline();
    pollTimer = Timer.periodic(pollInterval, (_) => observe());
    mount();
    observe();
    await completed.future;
  } finally {
    active = false;
    deadlineTimer?.cancel();
    pollTimer?.cancel();
    elapsed.stop();
    frames.framePolicy = previous;
  }
}
