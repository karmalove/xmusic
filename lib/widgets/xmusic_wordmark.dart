import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// SpaceX 风格品牌字标：几何无衬线 + 加宽字距 + 交叉 X。
class XmusicWordmark extends StatelessWidget {
  final double height;
  final Color color;
  final bool compact;

  const XmusicWordmark({
    super.key,
    this.height = 22,
    this.color = AppColors.textPrimary,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final xSize = height * 1.15;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: xSize,
          height: xSize,
          child: CustomPaint(painter: _SpaceXStyleXPainter(color: color)),
        ),
        SizedBox(width: compact ? 4 : 6),
        Padding(
          padding: EdgeInsets.only(top: height * 0.06),
          child: Text(
            'MUSIC',
            style: TextStyle(
              fontFamily: 'Syncopate',
              fontWeight: FontWeight.w700,
              fontSize: height * 0.92,
              letterSpacing: compact ? 3.2 : 5.5,
              color: color,
              height: 1,
            ),
          ),
        ),
      ],
    );
  }
}

class _SpaceXStyleXPainter extends CustomPainter {
  final Color color;

  _SpaceXStyleXPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.22;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    Path bar(Offset a, Offset b) {
      final dx = b.dx - a.dx;
      final dy = b.dy - a.dy;
      final len = math.sqrt(dx * dx + dy * dy);
      if (len == 0) return Path();
      final nx = -dy / len * stroke / 2;
      final ny = dx / len * stroke / 2;
      return Path()
        ..moveTo(a.dx + nx, a.dy + ny)
        ..lineTo(b.dx + nx, b.dy + ny)
        ..lineTo(b.dx - nx, b.dy - ny)
        ..lineTo(a.dx - nx, a.dy - ny)
        ..close();
    }

    final inset = size.width * 0.06;
    final tl = Offset(inset, inset);
    final tr = Offset(size.width - inset, inset);
    final bl = Offset(inset, size.height - inset);
    final br = Offset(size.width - inset, size.height - inset);

    canvas.drawPath(bar(tl, br), paint);
    canvas.drawPath(bar(tr, bl), paint);
  }

  @override
  bool shouldRepaint(covariant _SpaceXStyleXPainter oldDelegate) =>
      oldDelegate.color != color;
}
