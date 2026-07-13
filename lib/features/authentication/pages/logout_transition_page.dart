import 'dart:math';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../app/routes/app_routes.dart';
import '../../../core/localization/app_localization.dart';

class LogoutTransitionPage extends StatefulWidget {
  const LogoutTransitionPage({super.key});

  @override
  State<LogoutTransitionPage> createState() => _LogoutTransitionPageState();
}

class _LogoutTransitionPageState extends State<LogoutTransitionPage>
    with TickerProviderStateMixin {
  late AnimationController _ringController;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    _ringController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.10).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Exit transition to login
    Future.delayed(const Duration(milliseconds: 1900), () {
      if (mounted) {
        Get.offAllNamed(AppRoutes.login);
      }
    });
  }

  @override
  void dispose() {
    _ringController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isIndo = AppLocalization.isIndonesian;
    final Color activeColor = const Color(0xFFF43F5E); // Rose

    return Scaffold(
      body: Stack(
        children: [
          // 1. Premium Dark Ambient Background
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFF0A0714),
                    Color(0xFF030107),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
          ),

          // 2. Pulse background light
          Align(
            alignment: Alignment.center,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: activeColor.withOpacity(0.04),
                boxShadow: [
                  BoxShadow(
                    color: activeColor.withOpacity(0.08),
                    blurRadius: 100,
                    spreadRadius: 20,
                  ),
                ],
              ),
            ),
          ),

          // 3. Central Secure Lock & Rotating Rings
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedBuilder(
                  animation: Listenable.merge([_ringController, _pulseAnimation]),
                  builder: (context, child) {
                    final double rotationAngle = _ringController.value * 2 * pi;

                    return Transform.scale(
                      scale: _pulseAnimation.value,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Outer Ring: rotating counter-clockwise
                          Transform.rotate(
                            angle: -rotationAngle,
                            child: Container(
                              width: 140,
                              height: 140,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: activeColor.withOpacity(0.12),
                                  width: 2,
                                ),
                              ),
                            ),
                          ),
                          // Inner Ring: rotating clockwise
                          Transform.rotate(
                            angle: rotationAngle * 1.5,
                            child: Container(
                              width: 116,
                              height: 116,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: activeColor.withOpacity(0.24),
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: activeColor.withOpacity(0.15),
                                    blurRadius: 16,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          // Center Core Shield/Lock Circle
                          Container(
                            width: 88,
                            height: 88,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [
                                  activeColor,
                                  activeColor.withOpacity(0.7),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: activeColor.withOpacity(0.4),
                                  blurRadius: 24,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: ClipOval(
                              child: Container(
                                padding: const EdgeInsets.all(3),
                                color: const Color(0xFF0A0716),
                                child: const Center(
                                  child: Icon(
                                    Icons.power_settings_new_rounded,
                                    size: 40,
                                    color: Color(0xFFF43F5E),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 48),

                // 4. Secure Status Text
                Text(
                  isIndo ? 'Keluar...' : 'Logging out...',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
