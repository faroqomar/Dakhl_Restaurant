import 'package:flutter/material.dart';

/// Frozen 22-unit renderer.js paths, rendered as vectors without a font dependency.
enum DakhlIconKind {
  menu,
  ledger,
  wallet,
  supplier,
  transfer,
  grid,
  settings,
  plus,
  close,
  left,
  right,
  edit,
  undo,
  check,
}

class DakhlIcon extends StatelessWidget {
  const DakhlIcon(this.kind, {super.key, this.size = 22, this.color});
  final DakhlIconKind kind;
  final double size;
  final Color? color;
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _IconPainter(
          kind,
          color ?? IconTheme.of(context).color ?? const Color(0xFF17382D),
        ),
      ),
    ),
  );
}

class _IconPainter extends CustomPainter {
  _IconPainter(this.kind, this.color);
  final DakhlIconKind kind;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 22, size.height / 22);
    final p = Path();
    switch (kind) {
      case DakhlIconKind.menu:
        p
          ..moveTo(3, 5)
          ..lineTo(19, 5)
          ..moveTo(3, 11)
          ..lineTo(19, 11)
          ..moveTo(3, 17)
          ..lineTo(19, 17);
      case DakhlIconKind.ledger:
        p
          ..addRect(const Rect.fromLTWH(4, 2, 14, 18))
          ..moveTo(8, 7)
          ..lineTo(14, 7)
          ..moveTo(8, 11)
          ..lineTo(14, 11)
          ..moveTo(8, 15)
          ..lineTo(12, 15);
      case DakhlIconKind.wallet:
        p
          ..addRect(const Rect.fromLTWH(2, 5, 16, 14))
          ..moveTo(3, 5)
          ..lineTo(3, 2)
          ..lineTo(15, 2)
          ..addRect(const Rect.fromLTWH(13, 10, 7, 5));
      case DakhlIconKind.supplier:
        p
          ..addRect(const Rect.fromLTWH(2, 8, 16, 12))
          ..moveTo(0, 8)
          ..lineTo(3, 2)
          ..lineTo(17, 2)
          ..lineTo(20, 8)
          ..moveTo(6, 20)
          ..lineTo(6, 13)
          ..lineTo(14, 13)
          ..lineTo(14, 20);
      case DakhlIconKind.transfer:
        p
          ..moveTo(2, 6)
          ..lineTo(18, 6)
          ..moveTo(14, 2)
          ..lineTo(18, 6)
          ..lineTo(14, 10)
          ..moveTo(18, 16)
          ..lineTo(2, 16)
          ..moveTo(6, 12)
          ..lineTo(2, 16)
          ..lineTo(6, 20);
      case DakhlIconKind.grid:
        for (final x in [2.0, 13.0]) {
          for (final y in [2.0, 13.0]) {
            p.addRect(Rect.fromLTWH(x, y, 7, 7));
          }
        }
      case DakhlIconKind.settings:
        p
          ..moveTo(3, 5)
          ..lineTo(19, 5)
          ..moveTo(3, 11)
          ..lineTo(19, 11)
          ..moveTo(3, 17)
          ..lineTo(19, 17)
          ..moveTo(7, 2)
          ..lineTo(7, 8)
          ..moveTo(15, 8)
          ..lineTo(15, 14)
          ..moveTo(9, 14)
          ..lineTo(9, 20);
      case DakhlIconKind.plus:
        p
          ..moveTo(11, 4)
          ..lineTo(11, 18)
          ..moveTo(4, 11)
          ..lineTo(18, 11);
      case DakhlIconKind.close:
        p
          ..moveTo(5, 5)
          ..lineTo(17, 17)
          ..moveTo(17, 5)
          ..lineTo(5, 17);
      case DakhlIconKind.left:
        p
          ..moveTo(14, 4)
          ..lineTo(7, 11)
          ..lineTo(14, 18);
      case DakhlIconKind.right:
        p
          ..moveTo(8, 4)
          ..lineTo(15, 11)
          ..lineTo(8, 18);
      case DakhlIconKind.edit:
        p
          ..moveTo(4, 15)
          ..lineTo(15, 4)
          ..lineTo(19, 8)
          ..lineTo(8, 19)
          ..lineTo(4, 19)
          ..close()
          ..moveTo(13, 6)
          ..lineTo(17, 10);
      case DakhlIconKind.undo:
        p
          ..moveTo(7, 4)
          ..lineTo(2, 9)
          ..lineTo(7, 14)
          ..moveTo(2, 9)
          ..lineTo(12, 9)
          ..arcToPoint(const Offset(19, 16), radius: const Radius.circular(7));
      case DakhlIconKind.check:
        p
          ..moveTo(4, 11)
          ..lineTo(8, 15)
          ..lineTo(18, 4);
    }
    canvas.drawPath(
      p,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_IconPainter oldDelegate) =>
      oldDelegate.kind != kind || oldDelegate.color != color;
}
