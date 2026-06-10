import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/routes/app_routes.dart';
import '../../../core/models/user_model.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/session_service.dart';
import '../../../core/services/user_service.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  final authService = AuthService();
  final userService = UserService();

  @override
  void initState() {
    super.initState();

    Future.delayed(const Duration(milliseconds: 500), checkLogin);
  }

  Future<void> checkLogin() async {
    try {
      final firebaseUser = authService.currentUser;

      if (firebaseUser == null) {
        Get.offAllNamed(AppRoutes.login);
        return;
      }

      final userData = await userService.getUserById(firebaseUser.uid);

      if (userData == null) {
        Get.offAllNamed(AppRoutes.login);
        return;
      }

      SessionService.currentUser = UserModel.fromMap(
        firebaseUser.uid,
        userData,
      );

      final role = userData['role'];

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
          Get.offAllNamed(AppRoutes.login);
      }
    } catch (e) {
      debugPrint('SPLASH ERROR: $e');
      Get.offAllNamed(AppRoutes.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
