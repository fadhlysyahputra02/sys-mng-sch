import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthBackground extends StatelessWidget {
  final Widget child;
  static final ValueNotifier<bool> isDarkMode = ValueNotifier<bool>(true);

  static Future<void> initTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      isDarkMode.value = prefs.getBool('is_dark_mode') ?? true;
    } catch (e) {
      debugPrint('Failed to load theme preference: \$e');
    }
    isDarkMode.addListener(() async {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('is_dark_mode', isDarkMode.value);
      } catch (e) {
        debugPrint('Failed to save theme preference: \$e');
      }
    });
  }

  const AuthBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: isDarkMode,
      builder: (context, isDark, _) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: isDark
                  ? [
                      const Color(0xFF1E1B4B), // Deep indigo
                      const Color(0xFF0F0C20), // Dark indigo-purple
                      const Color(0xFF090514), // Midnight black
                    ]
                  : [
                      const Color(0xFFEEF2F6), // Light slate gray
                      const Color(0xFFF8FAFC), // Off white
                      const Color(0xFFFFFFFF), // Pure white
                    ],
              stops: const [0.0, 0.5, 1.0],
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
                        const Color(0xFF6366F1).withValues(alpha: isDark ? 0.18 : 0.08), // Violet glow
                        const Color(0xFF6366F1).withValues(alpha: 0.0),
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
                        const Color(0xFFD946EF).withValues(alpha: isDark ? 0.12 : 0.06), // Pink/Magenta glow
                        const Color(0xFFD946EF).withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ),
              // Motif / Corak Garis Geometris & Grid
              Positioned.fill(
                child: CustomPaint(
                  painter: AuthPatternPainter(isDarkMode: isDark),
                ),
              ),
              
              // Konten utama
              SafeArea(child: child),
            ],
          ),
        );
      },
    );
  }
}

class AuthPatternPainter extends CustomPainter {
  final bool isDarkMode;

  AuthPatternPainter({required this.isDarkMode});

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Menggambar Grid Halus
    final gridPaint = Paint()
      ..color = isDarkMode ? Colors.white.withValues(alpha: 0.018) : Colors.black.withValues(alpha: 0.025)
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
      ..color = isDarkMode ? Colors.white.withValues(alpha: 0.035) : Colors.black.withValues(alpha: 0.04)
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

    // 3. Menggambar Motif Titik-Titik Halus (Dot Pattern)
    final dotPaint = Paint()
      ..color = isDarkMode ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.05)
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
      ..color = const Color(0xFF6366F1).withValues(alpha: isDarkMode ? 0.12 : 0.08)
      ..strokeWidth = 1.0;
    
    canvas.drawLine(
      Offset(size.width * 0.1, size.height * 0.85),
      Offset(size.width * 0.4, size.height * 0.55),
      accentPaint,
    );
    canvas.drawCircle(
      Offset(size.width * 0.4, size.height * 0.55),
      3.0,
      Paint()
        ..color = const Color(0xFF6366F1).withValues(alpha: isDarkMode ? 0.25 : 0.15)
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
