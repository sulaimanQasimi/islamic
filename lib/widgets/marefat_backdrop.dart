import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/marefat_theme.dart';

/// Soft atmospheric background with a subtle geometric manuscript motif.
class MarefatBackdrop extends StatelessWidget {
  const MarefatBackdrop({super.key, required this.child, this.dark = false});

  final Widget child;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final top = dark ? const Color(0xFF0F2421) : MarefatColors.mist;
    final mid = dark ? MarefatColors.night : const Color(0xFFEEF6F2);
    final bottom = dark ? MarefatColors.nightSurface : MarefatColors.surface;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [top, mid, bottom],
          stops: const [0, 0.45, 1],
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _StarLatticePainter(
                color: (dark ? MarefatColors.brassSoft : MarefatColors.forest)
                    .withValues(alpha: dark ? 0.055 : 0.045),
              ),
            ),
          ),
          Positioned(
            top: -80,
            left: -60,
            child: _GlowOrb(
              size: 220,
              color: (dark ? MarefatColors.sage : MarefatColors.brassSoft)
                  .withValues(alpha: dark ? 0.12 : 0.18),
            ),
          ),
          Positioned(
            bottom: 120,
            right: -90,
            child: _GlowOrb(
              size: 260,
              color: (dark ? MarefatColors.brass : MarefatColors.forest)
                  .withValues(alpha: dark ? 0.1 : 0.1),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({required this.size, required this.color});
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
      ),
    ),
  );
}

class _StarLatticePainter extends CustomPainter {
  const _StarLatticePainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    const step = 48.0;
    for (var y = 0.0; y < size.height + step; y += step) {
      for (var x = 0.0; x < size.width + step; x += step) {
        final cx = x + ((y ~/ step) % 2 == 0 ? 0 : step / 2);
        _drawOctagon(canvas, Offset(cx, y), 7, paint);
      }
    }
  }

  void _drawOctagon(Canvas canvas, Offset c, double r, Paint paint) {
    final path = Path();
    for (var i = 0; i < 8; i++) {
      final a = (i * math.pi / 4) - math.pi / 8;
      final p = Offset(c.dx + r * math.cos(a), c.dy + r * math.sin(a));
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _StarLatticePainter oldDelegate) =>
      oldDelegate.color != color;
}
