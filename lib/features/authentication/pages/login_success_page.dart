import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/localization/app_localization.dart';

class VortexParticle3D {
  double angle;
  double radius;
  double speed;
  double radiusSpeed;
  double z; // -1.0 to 1.0 (depth)
  double zSpeed;
  Color color;
  double size;
  double opacity;

  VortexParticle3D({
    required this.angle,
    required this.radius,
    required this.speed,
    required this.radiusSpeed,
    required this.z,
    required this.zSpeed,
    required this.color,
    required this.size,
    required this.opacity,
  });

  void update(bool isExiting) {
    if (isExiting) {
      // Hyperspace exit warp: expand outward rapidly and spin faster
      radius += radiusSpeed * 12.0 + 3.0;
      angle += speed * 4.5;
    } else {
      // Swirling orbit phase
      angle += speed;
      z += zSpeed;
      if (z > 1.0 || z < -1.0) {
        zSpeed = -zSpeed;
      }
      // Gentle spiral inward/outward
      radius += radiusSpeed * 0.1;
      if (radius > 160 || radius < 55) {
        radiusSpeed = -radiusSpeed;
      }
    }
  }
}

class VortexPainter extends CustomPainter {
  final List<VortexParticle3D> particles;
  final bool isExiting;

  VortexPainter(this.particles, this.isExiting);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.translate(size.width / 2, size.height / 2 - 80);

    for (var particle in particles) {
      // 3D perspective projection scale factor
      // Mapping z from [-1.0, 1.0] to perspective [0.6, 1.4]
      double perspectiveScale = (particle.z + 2.5) / 2.5;

      // Elliptical path in 3D perspective space (squashed Y axis)
      double x = cos(particle.angle) * particle.radius * perspectiveScale;
      double y = sin(particle.angle) * particle.radius * 0.40 * perspectiveScale;

      double drawRadius = particle.size * perspectiveScale;
      // Fainter when far (negative z), brighter when close (positive z)
      double depthOpacity = (particle.z + 1.25) / 2.25;

      final paint = Paint()
        ..color = particle.color.withValues(alpha: particle.opacity * depthOpacity)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(Offset(x, y), drawRadius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class LoginSuccessPage extends StatefulWidget {
  final String destinationRoute;
  final dynamic destinationArguments;
  final String userName;
  final String roleName;
  final String? logoBase64;
  final String? schoolName;

  const LoginSuccessPage({
    super.key,
    required this.destinationRoute,
    this.destinationArguments,
    required this.userName,
    required this.roleName,
    this.logoBase64,
    this.schoolName,
  });

  @override
  State<LoginSuccessPage> createState() => _LoginSuccessPageState();
}

class _LoginSuccessPageState extends State<LoginSuccessPage>
    with TickerProviderStateMixin {
  late AnimationController _introController;
  late AnimationController _exitController;
  late AnimationController _pulseController;
  late AnimationController _ringController;

  late Animation<double> _logoScale;
  late Animation<double> _cardOpacity;
  late Animation<Offset> _cardSlide;
  late Animation<double> _cardRotation; // 3D Tilt animation
  late Animation<double> _pulseAnimation;

  late Animation<double> _exitLogoScale;
  late Animation<double> _exitLogoRotation;
  late Animation<double> _exitCardOpacity;

  final List<VortexParticle3D> _particles = [];
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _spawnParticles();

    _introController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    _exitController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    // Constant rotation of rings
    _ringController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat();

    // Intro Animations
    _logoScale = CurvedAnimation(
      parent: _introController,
      curve: const Interval(0.0, 0.45, curve: Curves.elasticOut),
    );

    _cardOpacity = CurvedAnimation(
      parent: _introController,
      curve: const Interval(0.3, 0.75, curve: Curves.easeIn),
    );

    _cardSlide = Tween<Offset>(
      begin: const Offset(0.0, 0.35),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _introController,
        curve: const Interval(0.3, 0.75, curve: Curves.easeOutBack),
      ),
    );

    // 3D Perspective Rotation from 45 degrees (pi/4) down to 0 degrees
    _cardRotation = Tween<double>(begin: pi / 4, end: 0.0).animate(
      CurvedAnimation(
        parent: _introController,
        curve: const Interval(0.3, 0.8, curve: Curves.easeOutCubic),
      ),
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.12).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Exit Animations (Hyperdrive warp rotation & scale expansion)
    _exitLogoScale = Tween<double>(begin: 1.0, end: 40.0).animate(
      CurvedAnimation(
        parent: _exitController,
        curve: Curves.easeInQuint,
      ),
    );

    _exitLogoRotation = Tween<double>(begin: 0.0, end: 8 * pi).animate(
      CurvedAnimation(
        parent: _exitController,
        curve: Curves.easeInOutCubic,
      ),
    );

    _exitCardOpacity = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _exitController,
        curve: const Interval(0.0, 0.35, curve: Curves.easeOut),
      ),
    );

    // Re-draw particles on intro ticks
    _introController.addListener(() {
      if (mounted) {
        setState(() {
          for (var p in _particles) {
            p.update(_exitController.isAnimating);
          }
        });
      }
    });

    _exitController.addListener(() {
      if (mounted) {
        setState(() {
          for (var p in _particles) {
            p.update(true);
          }
        });
      }
    });

    // Run animation timeline
    _introController.forward().then((_) {
      // Hold state for 1200ms, then launch portal zoom
      Future.delayed(const Duration(milliseconds: 1200), () {
        if (mounted) {
          _exitController.forward();
        }
      });
    });

    _exitController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        Get.offAllNamed(widget.destinationRoute, arguments: widget.destinationArguments);
      }
    });
  }

  void _spawnParticles() {
    final colors = [
      const Color(0xFF6366F1), // Indigo
      const Color(0xFF8B5CF6), // Violet
      const Color(0xFF10B981), // Emerald
      const Color(0xFF06B6D4), // Cyan
      const Color(0xFFFFD700), // Gold
    ];
    for (int i = 0; i < 75; i++) {
      _particles.add(
        VortexParticle3D(
          angle: _random.nextDouble() * 2 * pi,
          radius: 50.0 + _random.nextDouble() * 95.0,
          speed: 0.015 + _random.nextDouble() * 0.025,
          radiusSpeed: 0.2 + _random.nextDouble() * 0.5,
          z: -1.0 + _random.nextDouble() * 2.0,
          zSpeed: 0.01 + _random.nextDouble() * 0.02,
          color: colors[_random.nextInt(colors.length)],
          size: 1.5 + _random.nextDouble() * 3.5,
          opacity: 0.4 + _random.nextDouble() * 0.5,
        ),
      );
    }
  }

  @override
  void dispose() {
    _introController.dispose();
    _exitController.dispose();
    _pulseController.dispose();
    _ringController.dispose();
    super.dispose();
  }

  Color _getRoleColor(String role) {
    switch (role.trim().toLowerCase()) {
      case 'super_admin':
      case 'superadmin':
        return const Color(0xFFFFD700); // Gold
      case 'school_admin':
      case 'schooladmin':
        return const Color(0xFF06B6D4); // Cyan
      case 'teacher':
        return const Color(0xFF8B5CF6); // Purple
      case 'student':
        return const Color(0xFF10B981); // Emerald
      case 'parent':
        return const Color(0xFFEC4899); // Pink
      case 'officer':
        return const Color(0xFFEF4444); // Red
      case 'tu':
        return const Color(0xFF3B82F6); // Blue
      case 'librarian':
        return const Color(0xFFF59E0B); // Amber
      default:
        return const Color(0xFF6366F1); // Indigo
    }
  }

  String _getRoleDisplayName(String role) {
    final isIndo = AppLocalization.isIndonesian;
    switch (role.trim().toLowerCase()) {
      case 'super_admin':
      case 'superadmin':
        return 'SUPER ADMIN';
      case 'school_admin':
      case 'schooladmin':
        return isIndo ? 'ADMIN SEKOLAH' : 'SCHOOL ADMIN';
      case 'teacher':
        return isIndo ? 'GURU' : 'TEACHER';
      case 'student':
        return isIndo ? 'MURID' : 'STUDENT';
      case 'parent':
        return isIndo ? 'ORANG TUA' : 'PARENT';
      case 'officer':
        return isIndo ? 'PETUGAS' : 'OFFICER';
      case 'tu':
        return 'TU';
      case 'librarian':
        return isIndo ? 'PUSTAKAWAN' : 'LIBRARIAN';
      default:
        return role.toUpperCase();
    }
  }

  @override
  Widget build(BuildContext context) {
    final roleColor = _getRoleColor(widget.roleName);
    final roleDisplay = _getRoleDisplayName(widget.roleName);
    final isIndo = AppLocalization.isIndonesian;

    return Scaffold(
      body: Stack(
        children: [
          // 1. Dark ambient space gradient background
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFF070514),
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
              width: 380,
              height: 380,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: roleColor.withValues(alpha: 0.05),
                boxShadow: [
                  BoxShadow(
                    color: roleColor.withValues(alpha: 0.10),
                    blurRadius: 120,
                    spreadRadius: 30,
                  ),
                ],
              ),
            ),
          ),

          // 3. 3D Swirling Particles Vortex
          Positioned.fill(
            child: AnimatedBuilder(
              animation: Listenable.merge([_introController, _exitController]),
              builder: (context, _) {
                return CustomPaint(
                  painter: VortexPainter(_particles, _exitController.isAnimating),
                );
              },
            ),
          ),

          // 4. Concentric Energy Rings & Center Portal
          Align(
            alignment: Alignment.center,
            child: Transform.translate(
              offset: const Offset(0, -80),
              child: AnimatedBuilder(
                animation: Listenable.merge([_introController, _exitController, _pulseController, _ringController]),
                builder: (context, child) {
                  // Scale & Rotation computations
                  double currentScale = 0.0;
                  double currentRotation = 0.0;

                  if (_exitController.isAnimating || _exitController.isCompleted) {
                    currentScale = _exitLogoScale.value;
                    currentRotation = _exitLogoRotation.value;
                  } else {
                    currentScale = _logoScale.value * _pulseAnimation.value;
                    currentRotation = _ringController.value * 2 * pi;
                  }

                  // Inside rotation speeds for rings
                  double ring1Rot = currentRotation;
                  double ring2Rot = -currentRotation * 1.6;

                  return Transform.scale(
                    scale: currentScale,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Outer Ring: rotating counter-clockwise
                        Transform.rotate(
                          angle: ring2Rot,
                          child: Container(
                            width: 140,
                            height: 140,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: roleColor.withValues(alpha: 0.18),
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                        // Inner Ring: rotating clockwise
                        Transform.rotate(
                          angle: ring1Rot,
                          child: Container(
                            width: 116,
                            height: 116,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: roleColor.withValues(alpha: 0.35),
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: roleColor.withValues(alpha: 0.25),
                                  blurRadius: 16,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                          ),
                        ),
                        // Center Core Portal Logo
                        Container(
                          width: 90,
                          height: 90,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [
                                roleColor,
                                roleColor.withValues(alpha: 0.7),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: roleColor.withValues(alpha: 0.45),
                                blurRadius: 28,
                                spreadRadius: 3,
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child: Container(
                              padding: const EdgeInsets.all(3),
                              color: const Color(0xFF080617),
                              child: ClipOval(
                                child: widget.logoBase64 != null && widget.logoBase64!.isNotEmpty
                                    ? Image.memory(
                                        base64Decode(widget.logoBase64!),
                                        fit: BoxFit.cover,
                                        width: 84,
                                        height: 84,
                                        errorBuilder: (_, __, ___) => Icon(
                                          Icons.school_rounded,
                                          size: 42,
                                          color: roleColor,
                                        ),
                                      )
                                    : Icon(
                                        Icons.school_rounded,
                                        size: 42,
                                        color: roleColor,
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
            ),
          ),

          // 5. 3D Flipping Welcome Card with Glassmorphic Styling
          Align(
            alignment: const Alignment(0, 0.45),
            child: AnimatedBuilder(
              animation: Listenable.merge([_introController, _exitController]),
              builder: (context, child) {
                double opacity = _cardOpacity.value;
                if (_exitController.isAnimating || _exitController.isCompleted) {
                  opacity = _exitCardOpacity.value;
                }

                // 3D Perspective matrix transformation
                final matrix = Matrix4.identity()
                  ..setEntry(3, 2, 0.0012) // Perspective coefficient
                  ..rotateX(_cardRotation.value); // Rotating down to flat

                return Opacity(
                  opacity: opacity,
                  child: Transform(
                    transform: matrix,
                    alignment: Alignment.center,
                    child: Transform.translate(
                      offset: _cardSlide.value * 120,
                      child: child,
                    ),
                  ),
                );
              },
              child: Container(
                width: min(MediaQuery.of(context).size.width * 0.85, 360),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.035),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.07),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.45),
                      blurRadius: 36,
                      offset: const Offset(0, 18),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Subtle glowing success marker
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.14),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFF10B981).withValues(alpha: 0.3),
                          width: 1.0,
                        ),
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        color: Color(0xFF10B981),
                        size: 22,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Success tag
                    Text(
                      isIndo ? 'LOGIN BERHASIL' : 'LOGIN SUCCESSFUL',
                      style: const TextStyle(
                        color: Color(0xFF10B981),
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2.5,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Greeting
                    Text(
                      isIndo ? 'Selamat Datang Kembali,' : 'Welcome Back,',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.55),
                        fontSize: 14,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 6),

                    // Profile Name
                    Text(
                      widget.userName,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Colored Role Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        color: roleColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(100),
                        border: Border.all(
                          color: roleColor.withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        roleDisplay,
                        style: TextStyle(
                          color: roleColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),

                    if (widget.schoolName != null && widget.schoolName!.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text(
                        widget.schoolName!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.35),
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
