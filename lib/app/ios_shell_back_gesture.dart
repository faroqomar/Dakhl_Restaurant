import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

/// Bridges a deliberate iOS edge swipe to the shell's guarded back operation.
///
/// This adds no navigation history or pop animation. A pop-disabled Cupertino
/// route does not report its gesture, so completion uses the same app callback
/// as Android back. Existing content gestures remain earlier arena claimants.
class IosShellBackGesture extends StatefulWidget {
  const IosShellBackGesture({
    super.key,
    required this.canStart,
    required this.onBack,
    required this.child,
  });

  final bool Function() canStart;
  final Future<void> Function() onBack;
  final Widget child;

  @override
  State<IosShellBackGesture> createState() => _IosShellBackGestureState();
}

class _IosShellBackGestureState extends State<IosShellBackGesture> {
  static const _edgeWidth = 24.0;
  Offset? _start;
  Offset? _latest;
  var _inFlight = false;

  bool _allowed(PointerEvent event) {
    if (event is! PointerDownEvent ||
        event.kind != PointerDeviceKind.touch ||
        _inFlight ||
        _start != null ||
        !widget.canStart()) {
      return false;
    }
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return false;
    final point = box.globalToLocal(event.position);
    final leadingDistance = Directionality.of(context) == TextDirection.rtl
        ? box.size.width - point.dx
        : point.dx;
    return leadingDistance >= 0 &&
        leadingDistance <= _edgeWidth &&
        point.dy >= 0 &&
        point.dy <= box.size.height;
  }

  void _clear() {
    _start = null;
    _latest = null;
  }

  void _finish(double threshold) {
    final start = _start;
    final latest = _latest;
    _clear();
    if (start == null || latest == null || _inFlight || !widget.canStart()) {
      return;
    }
    final delta = latest - start;
    final distance = Directionality.of(context) == TextDirection.rtl
        ? -delta.dx
        : delta.dx;
    if (distance < threshold || delta.dy.abs() > distance * .35) return;
    _inFlight = true;
    unawaited(
      widget.onBack().whenComplete(() {
        _inFlight = false;
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) {
      return widget.child;
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final threshold = math.max(72.0, constraints.maxWidth * .25);
        return RawGestureDetector(
          excludeFromSemantics: true,
          behavior: HitTestBehavior.translucent,
          gestures: {
            _ShellEdgeDrag: GestureRecognizerFactoryWithHandlers<_ShellEdgeDrag>(
              () => _ShellEdgeDrag(debugOwner: this),
              (recognizer) => recognizer
                ..allowed = _allowed
                ..pointerCanceled = _clear
                // Child text/horizontal drags and vertical scrolling can win
                // at normal touch slop before this deliberate shell gesture.
                ..gestureSettings = DeviceGestureSettings(touchSlop: threshold)
                ..dragStartBehavior = DragStartBehavior.down
                ..onDown = (details) {
                  _start = details.globalPosition;
                  _latest = details.globalPosition;
                }
                ..onUpdate = (details) {
                  _latest = details.globalPosition;
                }
                ..onCancel = _clear
                ..onEnd = (_) => _finish(threshold),
            ),
          },
          child: widget.child,
        );
      },
    );
  }
}

class _ShellEdgeDrag extends HorizontalDragGestureRecognizer {
  _ShellEdgeDrag({super.debugOwner});
  bool Function(PointerEvent event)? allowed;
  VoidCallback? pointerCanceled;

  @override
  void handleEvent(PointerEvent event) {
    // Accepted pointer cancellation is also reported through onEnd. Remove
    // completion intent before that callback, so cancellation cannot go back.
    if (event is PointerCancelEvent) pointerCanceled?.call();
    super.handleEvent(event);
  }

  @override
  bool isPointerAllowed(PointerEvent event) =>
      (allowed?.call(event) ?? false) && super.isPointerAllowed(event);
}
