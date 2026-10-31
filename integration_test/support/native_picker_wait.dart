import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

/// Test-only frame control. No operation creates an awaited tester pump.
abstract interface class NativePickerFrames {
  LiveTestWidgetsFlutterBindingFramePolicy get framePolicy;
  set framePolicy(LiveTestWidgetsFlutterBindingFramePolicy value);
  bool get shouldPropagateDevicePointerEvents;
  set shouldPropagateDevicePointerEvents(bool value);
  bool get framesEnabled;
  void requestFrame(void Function() onRenderedFrame);
}

/// Let the real framework render native-return/confirmation UI while polling.
/// In the live binding, pump() instead creates a private pending-frame future
/// that cannot be cancelled when a native Activity suspends engine frames.
final class LiveNativePickerFrames implements NativePickerFrames {
  LiveNativePickerFrames(this.binding);

  final LiveTestWidgetsFlutterBinding binding;

  @override
  LiveTestWidgetsFlutterBindingFramePolicy get framePolicy =>
      binding.framePolicy;
  @override
  set framePolicy(LiveTestWidgetsFlutterBindingFramePolicy value) =>
      binding.framePolicy = value;
  @override
  bool get shouldPropagateDevicePointerEvents =>
      binding.shouldPropagateDevicePointerEvents;
  @override
  set shouldPropagateDevicePointerEvents(bool value) =>
      binding.shouldPropagateDevicePointerEvents = value;

  @override
  bool get framesEnabled => binding.framesEnabled;
  @override
  void requestFrame(void Function() onRenderedFrame) {
    binding.addPostFrameCallback((_) => onRenderedFrame());
    binding.scheduleFrame();
  }
}

/// A real, monotonic native handoff budget, including its final rendered frame.
///
/// Call from the live integration binding's real timer zone. There is no
/// awaited pump or frame future. Timers retire on every exit. A registered
/// public post-frame callback cannot be removed, so it becomes inert on exit.
/// A stopped native Activity may suspend frames while Dart timers still run.
/// Both the timer and checks around synchronous observation reject late success
/// if an event-loop delay prevents the timer callback from firing on time.
/// Device touch input is enabled only for this manual handoff; both binding
/// settings are restored to their exact prior values on every exit.
Future<void> waitForNativePickerCondition({
  required NativePickerFrames frames,
  required bool Function() settled,
  required String label,
  Duration timeout = const Duration(seconds: 120),
  Duration pollInterval = const Duration(milliseconds: 100),
}) async {
  if (timeout <= Duration.zero || timeout > const Duration(seconds: 120)) {
    throw ArgumentError.value(
      timeout,
      'timeout',
      'Must be within 120 seconds.',
    );
  }
  if (pollInterval <= Duration.zero) {
    throw ArgumentError.value(
      pollInterval,
      'pollInterval',
      'Must be positive.',
    );
  }
  final previousFramePolicy = frames.framePolicy;
  final previousDevicePointers = frames.shouldPropagateDevicePointerEvents;
  final elapsed = Stopwatch()..start();
  final done = Completer<void>();
  Timer? deadlineTimer;
  Timer? pollTimer;
  var active = true, frameRequested = false, frameRendered = false;
  var frameGeneration = 0;

  void finish([Object? error, StackTrace? stack]) {
    if (done.isCompleted) return;
    deadlineTimer?.cancel();
    pollTimer?.cancel();
    if (error == null) {
      done.complete();
    } else {
      done.completeError(error, stack);
    }
  }

  bool expired() {
    if (elapsed.elapsed < timeout) return false;
    finish(TimeoutException('Timed out waiting for $label.', timeout));
    return true;
  }

  void armDeadline() {
    if (done.isCompleted || expired()) return;
    final remaining = timeout - elapsed.elapsed;
    // Platform timers can round a fractional millisecond down. The same
    // monotonic clock that rejects late success must also authorize timeout.
    // A one-millisecond floor prevents a zero-delay rearm loop.
    deadlineTimer = Timer(
      remaining < const Duration(milliseconds: 1)
          ? const Duration(milliseconds: 1)
          : remaining,
      armDeadline,
    );
  }

  void observe() {
    if (!active || done.isCompleted || expired()) return;
    try {
      final ready = settled();
      if (expired()) return;
      if (!ready) {
        frameRequested = frameRendered = false;
        frameGeneration++;
        return;
      }
      if (!frames.framesEnabled) {
        frameRequested = frameRendered = false;
        frameGeneration++;
        return;
      }
      if (!frameRequested) {
        frameRequested = true;
        final generation = ++frameGeneration;
        frames.requestFrame(() {
          if (!active || done.isCompleted || generation != frameGeneration) {
            return;
          }
          frameRendered = true;
          observe();
        });
        return;
      }
      if (frameRendered && !expired()) finish();
    } catch (error, stack) {
      finish(error, stack);
    }
  }

  try {
    frames.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
    frames.shouldPropagateDevicePointerEvents = true;
    armDeadline();
    pollTimer = Timer.periodic(pollInterval, (_) => observe());
    observe();
    await done.future;
  } finally {
    active = false;
    deadlineTimer?.cancel();
    pollTimer?.cancel();
    elapsed.stop();
    try {
      frames.shouldPropagateDevicePointerEvents = previousDevicePointers;
    } finally {
      frames.framePolicy = previousFramePolicy;
    }
  }
}
