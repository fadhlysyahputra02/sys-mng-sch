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

  bool _isSecured = false;

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

    // Dynamic state transitions
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          _isSecured = true;
        });
      }
    });

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
    final Color activeColor = _isSecured ? const Color(0xFF10B981) : const Color(0xFFF43F5E); // Emerald vs Rose

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
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 400),
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
                                child: Center(
                                  child: AnimatedCrossFade(
                                    firstChild: const Icon(
                                      Icons.lock_open_rounded,
                                      size: 40,
                                      color: Color(0xFFF43F5E),
                                    ),
                                    secondChild: const Icon(
                                      Icons.lock_rounded,
                                      size: 40,
                                      color: Color(0xFF10B981),
                                    ),
                                    crossFadeState: _isSecured
                                        ? CrossFadeState.showSecond
                                        : CrossFadeState.showFirst,
                                    duration: const Duration(milliseconds: 300),
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

                // 4. Secure Status Text with Animated Switcher
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  transitionBuilder: (child, animation) {
                    return FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0.0, 0.25),
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      ),
                    );
                  },
                  child: Text(
                    _isSecured
                        ? (isIndo ? 'Sesi Aman. Sampai Jumpa!' : 'Session Secured. Goodbye!')
                        : (isIndo ? 'Mengamankan Sesi...' : 'Securing Session...'),
                    key: ValueKey<bool>(_isSecured),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                Text(
                  isIndo ? 'Menghapus session data secara aman' : 'Clearing session credentials securely',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.4),
                    fontSize: 12,
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
