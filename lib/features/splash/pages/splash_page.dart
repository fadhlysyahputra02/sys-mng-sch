import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/routes/app_routes.dart';
import '../../../core/models/user_model.dart';
import '../../../core/services/session_service.dart';
import '../../../core/services/user_service.dart';
import '../../../core/services/notification_listener_service.dart';
import '../../../core/services/push_notification_service.dart';
import '../../authentication/widgets/auth_background.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> with SingleTickerProviderStateMixin {
  final userService = UserService();
  late AnimationController _rotationController;
  final List<String> _logs = [];

  void _addLog(String msg) {
    debugPrint(msg);
    if (mounted) {
      setState(() {
        _logs.add(msg);
      });
    }
  }

  @override
  void initState() {
    super.initState();

    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    Future.delayed(const Duration(milliseconds: 2000), checkLogin);
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  Future<void> checkLogin() async {
    _addLog('SPLASH: checkLogin started');
    try {
      // Pada Flutter Web, Firebase Auth memulihkan session secara asinkron dari IndexedDB/localStorage.
      // Event pertama dari authStateChanges() selalu null (synchronous initial value).
      // Kita mendengarkan stream selama beberapa saat untuk melihat apakah ada session yang dipulihkan.
      User? firebaseUser;
      final completer = Completer<User?>();
      
      final subscription = FirebaseAuth.instance.authStateChanges().listen((user) {
        _addLog('SPLASH: authStateChanges emitted: ${user?.email ?? 'null (no user)'}');
        if (user != null && !completer.isCompleted) {
          completer.complete(user);
        }
      });

      // Tunggu hingga 1.5 detik. Jika tidak ada user non-null, anggap user memang belum login.
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (!completer.isCompleted) {
          _addLog('SPLASH: checkLogin timeout reached, completing with null');
          completer.complete(null);
        }
      });

      firebaseUser = await completer.future;
      await subscription.cancel();
      _addLog('SPLASH: Resolved firebaseUser: ${firebaseUser?.email ?? 'null'}');

      if (firebaseUser == null) {
        _addLog('SPLASH: firebaseUser is null, redirecting to login in 4s...');
        await Future.delayed(const Duration(seconds: 4));
        Get.offAllNamed(AppRoutes.login);
        return;
      }

      final userData = await userService.getUserById(firebaseUser.uid);
      _addLog('SPLASH: Fetched userData: $userData');

      if (userData == null) {
        _addLog('SPLASH: userData is null in firestore, redirecting to login in 4s...');
        await Future.delayed(const Duration(seconds: 4));
        Get.offAllNamed(AppRoutes.login);
        return;
      }

      SessionService.currentUser = UserModel.fromMap(
        firebaseUser.uid,
        userData,
      );
      _addLog('SPLASH: Session user set: ${SessionService.currentUser?.nama}');

      // Mulai mendengarkan notifikasi secara real-time
      NotificationListenerService().startListening();

      // Daftar perangkat untuk push notification
      PushNotificationService().registerUserDevice();

      final role = userData['role'];
      _addLog('SPLASH: User role: $role');

      switch (role) {
        case 'super_admin':
          Get.offAllNamed(AppRoutes.superAdmin);
          break;

        case 'school_admin':
          Get.offAllNamed(AppRoutes.schoolAdmin);
          break;

        case 'teacher':
          Get.offAllNamed(AppRoutes.teacher);
          break;

        case 'student':
          Get.offAllNamed(AppRoutes.student);
          break;

        default:
          _addLog('SPLASH: Unknown role, redirecting to login in 4s...');
          await Future.delayed(const Duration(seconds: 4));
          Get.offAllNamed(AppRoutes.login);
      }
    } catch (e) {
      _addLog('SPLASH ERROR: $e');
      await Future.delayed(const Duration(seconds: 4));
      Get.offAllNamed(AppRoutes.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ValueListenableBuilder<bool>(
        valueListenable: AuthBackground.isDarkMode,
        builder: (context, isDark, _) {
          final textColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
          final subTextColor = isDark ? Colors.white.withValues(alpha: 0.5) : const Color(0xFF1E1B4B).withValues(alpha: 0.65);
          final iconColor = isDark ? Colors.white : const Color(0xFF6366F1);
          final logoBgColor = isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04);
          final logoBorderColor = isDark ? Colors.white.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.08);

          return AuthBackground(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Spinning App Logo
                  RotationTransition(
                    turns: _rotationController,
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: logoBgColor,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: logoBorderColor,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF6366F1).withValues(alpha: 0.25),
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
                  ),
                  const SizedBox(height: 32),
                  
                  // App Title
                  Text(
                    'SYS MNG SCH',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                      letterSpacing: 3.0,
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  // Subtitle/Status
                  Text(
                    'Memuat Sistem Manajemen Sekolah...',
                    style: TextStyle(
                      fontSize: 14,
                      color: subTextColor,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 48),
                  
                  // Tiny progress indicator to show loading
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF8B5CF6)),
                    ),
                  ),

                  // Render debug logs on screen
                  const SizedBox(height: 32),
                  Container(
                    constraints: const BoxConstraints(maxHeight: 180),
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: _logs.map((log) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            log,
                            style: const TextStyle(
                              fontSize: 12,
                              fontFamily: 'monospace',
                              color: Colors.redAccent,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        )).toList(),
                      ),
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
