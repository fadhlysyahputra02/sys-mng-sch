import 'package:flutter/material.dart';

class MotifCard extends StatelessWidget {
  final Widget child;
  final bool isDark;
  final EdgeInsetsGeometry padding;
  final Color? cardColor;
  final Gradient? gradient;
  final Color cardBorderColor;
  final Color cardShadowColor;
  final double borderRadius;

  const MotifCard({
    super.key,
    required this.child,
    required this.isDark,
    this.padding = const EdgeInsets.all(20),
    this.cardColor,
    this.gradient,
    required this.cardBorderColor,
    required this.cardShadowColor,
    this.borderRadius = 24.0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        gradient: gradient,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: cardBorderColor),
        boxShadow: [
          BoxShadow(
            color: cardShadowColor,
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: Stack(
          children: [
            // Corak motif mandala/damask (tampil di light mode maupun dark mode)
            Positioned.fill(
              child: Opacity(
                opacity: isDark 
                    ? 0.15 // Naikkan opasitas agar terlihat di atas efek glass
                    : (gradient != null ? 0.80 : 0.75), // Diperbesar untuk light mode
                child: Image.asset(
                  'assets/images/motif_mandala.png',
                  fit: BoxFit.cover,
                  alignment: Alignment.center,
                  // Menggunakan softLight atau overlay untuk blending natural dengan background gelap
                  color: isDark ? Colors.white : null,
                  colorBlendMode: isDark ? BlendMode.softLight : null,
                ),
              ),
            ),
            // Konten asli card
            Padding(
              padding: padding,
              child: child,
            ),
          ],
        ),
      ),
    );
  }
}
