import 'package:flutter/material.dart';
import '../../../core/localization/app_localization.dart';
import 'auth_background.dart';

/// Tombol toggle bahasa (Bendera Indonesia 🇮🇩 / Inggris 🇬🇧)
/// Diletakkan di sebelah kiri ThemeToggleButton di AppBar halaman login/register.
class LanguageToggleButton extends StatelessWidget {
  const LanguageToggleButton({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: AppLocalization.currentLocale,
      builder: (context, locale, _) {
        final isDark = AuthBackground.isDarkMode.value;
        final buttonColor = isDark ? const Color(0xFF151026) : Colors.white;

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

        final isIndonesian = locale == AppLocalization.langId;

        return ValueListenableBuilder<bool>(
          valueListenable: AuthBackground.isDarkMode,
          builder: (context, dark, _) {
            return GestureDetector(
              onTap: () {
                AppLocalization.toggle();
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.only(top: 8),
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: buttonColor,
                  shape: BoxShape.circle,
                  boxShadow: shadowColors,
                  border: Border.all(
                    color: dark
                        ? const Color(0xFF6366F1).withValues(alpha: 0.4)
                        : Colors.black.withValues(alpha: 0.08),
                    width: 1.5,
                  ),
                ),
                child: Center(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 350),
                    transitionBuilder: (child, animation) {
                      return ScaleTransition(
                        scale: animation,
                        child: FadeTransition(opacity: animation, child: child),
                      );
                    },
                    child: Text(
                      isIndonesian ? '🇮🇩' : '🇬🇧',
                      key: ValueKey<String>(locale),
                      style: const TextStyle(fontSize: 20),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
