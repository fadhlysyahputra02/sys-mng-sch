import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../app/routes/app_routes.dart';
import '../../../core/models/user_model.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/session_service.dart';
import '../../../core/services/user_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final authService = AuthService();
  final userService = UserService();

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('SYS MNG SCH')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: emailController,
              decoration: const InputDecoration(labelText: 'Email'),
            ),

            const SizedBox(height: 16),

            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Password'),
            ),

            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  try {
                    final credential = await authService.login(
                      email: emailController.text.trim(),
                      password: passwordController.text.trim(),
                    );

                    debugPrint('LOGIN BERHASIL UID: ${credential.user?.uid}');
                    final uid = credential.user!.uid;

                    final userData = await userService.getUserById(uid);

                    SessionService.currentUser = UserModel.fromMap(
                      uid,
                      userData!,
                    );

                    debugPrint('USER DATA: $userData');

                    final role = userData['role'];

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

                      default:
                        throw Exception('Role tidak dikenal');
                    }
                    if (mounted) {
                      // ignore: use_build_context_synchronously
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Login berhasil')),
                      );
                    }
                  } catch (e) {
                    debugPrint('LOGIN ERROR: $e');
                    debugPrint(emailController.text.trim());
                    debugPrint(passwordController.text.trim());

                    if (mounted) {
                      // ignore: use_build_context_synchronously
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Login gagal')),
                      );
                    }
                  }
                },
                child: const Text('LOGIN'),
              ),
            ),
            const SizedBox(height: 16),

            TextButton(
              onPressed: () {
                Get.toNamed(AppRoutes.register);
              },
              child: const Text('Belum punya akun? Register'),
            ),
          ],
        ),
      ),
    );
  }
}
