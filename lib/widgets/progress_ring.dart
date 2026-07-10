import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme.dart';

/// A circular progress ring with an optional centred child.
class ProgressRing extends StatelessWidget {
  final double value; // 0..1
  final double size;
  final double stroke;
  final Color color;
  final Widget? center;

  const ProgressRing({
    super.key,
    required this.value,
    this.size = 104,
    this.stroke = 11,
    this.color = const Color(0xFF2E86AB),
    this.center,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _RingPainter(value.clamp(0, 1).toDouble(), stroke, color),
        child: center == null ? null : Center(child: center),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double frac;
  final double stroke;
  final Color color;
  _RingPainter(this.frac, this.stroke, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - stroke) / 2;
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = AppColors.line;
    canvas.drawCircle(center, radius, track);
    if (frac > 0) {
      final arc = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..color = color;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        2 * math.pi * frac,
        false,
        arc,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.frac != frac || old.color != color || old.stroke != stroke;
}
