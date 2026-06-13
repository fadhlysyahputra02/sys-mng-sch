import 'dart:math' as math;
import 'package:flutter/material.dart';

class AuthBackground extends StatelessWidget {
  final Widget child;

  const AuthBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            Color(0xFF1E1B4B), // Deep indigo
            Color(0xFF0F0C20), // Dark indigo-purple
            Color(0xFF090514), // Midnight black
          ],
          stops: [0.0, 0.5, 1.0],
        ),
      ),
      child: Stack(
        children: [
          // Aura Cahaya 1 (Top Right Glow)
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 350,
              height: 350,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF6366F1).withOpacity(0.18), // Violet glow
                    const Color(0xFF6366F1).withOpacity(0.0),
                  ],
                ),
              ),
            ),
          ),
          // Aura Cahaya 2 (Bottom Left Glow)
          Positioned(
            bottom: -150,
            left: -150,
            child: Container(
              width: 450,
              height: 450,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFFD946EF).withOpacity(0.12), // Pink/Magenta glow
                    const Color(0xFFD946EF).withOpacity(0.0),
                  ],
                ),
              ),
            ),
          ),
          // Motif / Corak Garis Geometris & Grid
          Positioned.fill(
            child: CustomPaint(
              painter: AuthPatternPainter(),
            ),
          ),
          // Konten utama
          SafeArea(child: child),
        ],
      ),
    );
  }
}

class AuthPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // 1. Menggambar Grid Halus (Polanya Sekolah/Teknologi)
    final gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.018)
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;

    const double gridSpacing = 40.0;
    for (double x = 0; x < size.width; x += gridSpacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += gridSpacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // 2. Menggambar Ornamen Gelombang Abstrak Melengkung
    final pathPaint = Paint()
      ..color = Colors.white.withOpacity(0.035)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    // Gelombang 1
    final wave1 = Path();
    wave1.moveTo(0, size.height * 0.25);
    wave1.cubicTo(
      size.width * 0.3,
      size.height * 0.15,
      size.width * 0.6,
      size.height * 0.35,
      size.width,
      size.height * 0.2,
    );
    canvas.drawPath(wave1, pathPaint);

    // Gelombang 2 (Sejajar)
    final wave2 = Path();
    wave2.moveTo(0, size.height * 0.28);
    wave2.cubicTo(
      size.width * 0.3,
      size.height * 0.18,
      size.width * 0.6,
      size.height * 0.38,
      size.width,
      size.height * 0.23,
    );
    canvas.drawPath(wave2, pathPaint);

    // 3. Menggambar Motif Titik-Titik Halus (Dot Pattern) di pojok kiri atas & kanan bawah
    final dotPaint = Paint()
      ..color = Colors.white.withOpacity(0.06)
      ..style = PaintingStyle.fill;

    // Grid Dot Kiri Atas
    const int rows = 5;
    const int cols = 5;
    const double dotSpacing = 15.0;
    const double startX = 30.0;
    const double startY = 60.0;
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        canvas.drawCircle(
          Offset(startX + c * dotSpacing, startY + r * dotSpacing),
          1.5,
          dotPaint,
        );
      }
    }

    // Grid Dot Kanan Bawah
    final double endX = size.width - 100.0;
    final double endY = size.height - 130.0;
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        canvas.drawCircle(
          Offset(endX + c * dotSpacing, endY + r * dotSpacing),
          1.5,
          dotPaint,
        );
      }
    }

    // 4. Garis Diagonal Dinamis Menyilang
    final accentPaint = Paint()
      ..color = const Color(0xFF6366F1).withOpacity(0.12)
      ..strokeWidth = 1.0;
    
    canvas.drawLine(
      Offset(size.width * 0.1, size.height * 0.85),
      Offset(size.width * 0.4, size.height * 0.55),
      accentPaint,
    );
    canvas.drawCircle(
      Offset(size.width * 0.4, size.height * 0.55),
      3.0,
      Paint()..color = const Color(0xFF6366F1).withOpacity(0.25)..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
