import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../app/routes/app_routes.dart';
import '../../../core/localization/app_localization.dart';
import '../widgets/auth_background.dart';

class LogoutTransitionPage extends StatefulWidget {
  const LogoutTransitionPage({super.key});

  @override
  State<LogoutTransitionPage> createState() => _LogoutTransitionPageState();
}

class _LogoutTransitionPageState extends State<LogoutTransitionPage> {
  @override
  void initState() {
    super.initState();
    // Exit transition to login after a short delay
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) {
        Get.offAllNamed(AppRoutes.login);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isIndo = AppLocalization.isIndonesian;

    return Scaffold(
      body: ValueListenableBuilder<bool>(
        valueListenable: AuthBackground.isDarkMode,
        builder: (context, isDark, _) {
          final textColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
          final iconColor = isDark ? Colors.white : const Color(0xFF6366F1);
          final logoBgColor = isDark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.black.withValues(alpha: 0.04);
          final logoBorderColor = isDark
              ? Colors.white.withValues(alpha: 0.12)
              : Colors.black.withValues(alpha: 0.08);

          return AuthBackground(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: logoBgColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: logoBorderColor),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF6366F1)
                              .withValues(alpha: 0.25),
                          blurRadius: 32,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.school_rounded,
                      size: 72,
                      color: iconColor,
                    ),
                  ),
                  const SizedBox(height: 32),
                  Text(
                    isIndo ? 'Keluar...' : 'Logging out...',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: 30,
                    height: 30,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      valueColor: AlwaysStoppedAnimation<Color>(iconColor),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
