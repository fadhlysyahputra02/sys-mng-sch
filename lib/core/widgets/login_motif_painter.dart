import 'dart:math' as math;
import 'package:flutter/material.dart';

class LoginMotifPainter extends CustomPainter {
  final Color color;

  LoginMotifPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    const double hexSize = 40.0;
    const double hexWidth = hexSize * 2;
    final double hexHeight = math.sqrt(3) * hexSize;
    
    // Draw repeating hexagons
    for (double x = -hexWidth; x < size.width + hexWidth; x += hexWidth * 0.75) {
      // Shift every other column to interlock hexagons
      final int colIndex = (x / (hexWidth * 0.75)).round();
      final double yOffset = (colIndex.isOdd) ? hexHeight / 2 : 0;
      
      for (double y = -hexHeight; y < size.height + hexHeight; y += hexHeight) {
        final center = Offset(x, y + yOffset);
        _drawHexagon(canvas, center, hexSize, paint);
        
        // Add subtle dots at centers
        canvas.drawCircle(center, 2.0, Paint()..color = color..style = PaintingStyle.fill);
      }
    }
  }

  void _drawHexagon(Canvas canvas, Offset center, double size, Paint paint) {
    final path = Path();
    for (int i = 0; i < 6; i++) {
      final double angle = (math.pi / 3) * i;
      final double x = center.dx + size * math.cos(angle);
      final double y = center.dy + size * math.sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
