import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../app/routes/app_routes.dart';
import '../../../core/models/user_model.dart';
import '../../../core/services/semester_state_service.dart';
import '../../../core/services/session_service.dart';
import '../../../core/services/user_service.dart';
import '../../authentication/widgets/auth_background.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  final userService = UserService();
  late AnimationController _rotationController;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    _checkLogin();
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  Future<void> _checkLogin() async {
    try {
      // ✅ FIX 2 (ROOT CAUSE):
      // Di web, authStateChanges() emit null dulu sebelum Firebase selesai
      // restore session dari IndexedDB. Solusinya: tunggu sampai dapat nilai
      // non-null dalam batas waktu tertentu. Kalau timeout, baru arahkan ke login.
      User? firebaseUser;

      // Beri waktu maksimal 8 detik untuk Firebase restore session
      firebaseUser = await FirebaseAuth.instance
          .authStateChanges()
          .firstWhere(
            (user) => user != null,
            orElse: () => null,
          )
          .timeout(
            const Duration(seconds: 8),
            onTimeout: () => null,
          );

      // Minimal tampilkan splash 2 detik agar tidak terlalu kilat
      await Future.delayed(const Duration(milliseconds: 2000));

      if (!mounted) return;

      if (firebaseUser == null) {
        Get.offAllNamed(AppRoutes.login);
        return;
      }

      final userData = await userService.getUserById(firebaseUser.uid);
      if (userData == null) {
        await FirebaseAuth.instance.signOut();
        SemesterStateService.dispose();
        Get.offAllNamed(AppRoutes.login);
        return;
      }

      // ✅ Isi ulang SessionService dari Firebase Auth
      SessionService.currentUser = UserModel.fromMap(
        firebaseUser.uid,
        userData,
      );

      // ✅ Start semester state listener (jika user punya schoolId)
      final schoolId = (userData['schoolId'] ?? '').toString();
      if (schoolId.isNotEmpty) {
        SemesterStateService.listen(schoolId);
      }

      String role = (userData['role'] ?? '').toString().trim().toLowerCase();
      if (role == 'superadmin' || role == 'super-admin' || role == 'super_admin') {
        role = 'super_admin';
      } else if (role == 'schooladmin' || role == 'school-admin' || role == 'school_admin') {
        role = 'school_admin';
      }

      if (!mounted) return;

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
        case 'parent':
          if (userData['schoolId'] == null || (userData['schoolId'] as String).isEmpty) {
            Get.offAllNamed(AppRoutes.parentRegister, arguments: {'showScanner': true});
          } else {
            Get.offAllNamed(AppRoutes.parent);
          }
          break;
        case 'officer':
          Get.offAllNamed(AppRoutes.officerDashboard);
          break;
        case 'tu':
          Get.offAllNamed(AppRoutes.tuDashboard);
          break;
        case 'librarian':
          Get.offAllNamed(AppRoutes.librarianDashboard);
          break;
        default:
          await FirebaseAuth.instance.signOut();
          Get.offAllNamed(AppRoutes.login);
      }
    } catch (e) {
      debugPrint('SPLASH ERROR: $e');
      if (mounted) {
        Get.offAllNamed(AppRoutes.login);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ValueListenableBuilder<bool>(
        valueListenable: AuthBackground.isDarkMode,
        builder: (context, isDark, _) {
          final textColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
          final subTextColor = isDark
              ? Colors.white.withValues(alpha: 0.5)
              : const Color(0xFF1E1B4B).withValues(alpha: 0.65);
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
                  RotationTransition(
                    turns: _rotationController,
                    child: Container(
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
                  ),
                  const SizedBox(height: 32),
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
                  Text(
                    'Memuat Sistem Manajemen Sekolah...',
                    style: TextStyle(
                      fontSize: 14,
                      color: subTextColor,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 48),
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor:
                          AlwaysStoppedAnimation(Color(0xFF8B5CF6)),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'v1.13.1',
                    style: TextStyle(
                      fontSize: 12,
                      color: subTextColor,
                      letterSpacing: 1.5,
                      fontWeight: FontWeight.w500,
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