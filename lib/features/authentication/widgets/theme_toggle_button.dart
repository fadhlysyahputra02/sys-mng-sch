import 'package:flutter/material.dart';
import 'auth_background.dart';

class ThemeToggleButton extends StatelessWidget {
  const ThemeToggleButton({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: AuthBackground.isDarkMode,
      builder: (context, isDark, _) {
        final buttonColor = isDark ? const Color(0xFF151026) : Colors.white;
        final borderGradient = isDark
            ? const LinearGradient(
                colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
              )
            : LinearGradient(
                colors: [Colors.black.withValues(alpha: 0.06), Colors.black.withValues(alpha: 0.12)],
              );
        
        final shadowColors = isDark
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  offset: const Offset(3, 3),
                  blurRadius: 6,
                ),
                BoxShadow(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.2),
                  offset: const Offset(-2, -2),
                  blurRadius: 5,
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  offset: const Offset(3, 3),
                  blurRadius: 6,
                ),
                const BoxShadow(
                  color: Colors.white,
                  offset: Offset(-3, -3),
                  blurRadius: 6,
                ),
              ];

        return Container(
          margin: const EdgeInsets.only(right: 16, top: 8),
          child: Center(
            child: GestureDetector(
              onTap: () {
                AuthBackground.isDarkMode.value = !isDark;
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: buttonColor,
                  shape: BoxShape.circle,
                  boxShadow: shadowColors,
                ),
                child: CustomPaint(
                  painter: CircleBorderPainter(gradient: borderGradient, strokeWidth: 1.5),
                  child: Center(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 400),
                      transitionBuilder: (child, animation) {
                        return RotationTransition(
                          turns: animation,
                          child: FadeTransition(
                            opacity: animation,
                            child: ScaleTransition(
                              scale: animation,
                              child: child,
                            ),
                          ),
                        );
                      },
                      child: Icon(
                        isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                        key: ValueKey<bool>(isDark),
                        color: isDark ? const Color(0xFFFBBF24) : const Color(0xFF1E1B4B),
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class CircleBorderPainter extends CustomPainter {
  final Gradient gradient;
  final double strokeWidth;

  CircleBorderPainter({required this.gradient, required this.strokeWidth});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(
      strokeWidth / 2,
      strokeWidth / 2,
      size.width - strokeWidth,
      size.height - strokeWidth,
    );
    final paint = Paint()
      ..shader = gradient.createShader(rect)
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    canvas.drawArc(rect, 0, 2 * 3.141592653589793, false, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
