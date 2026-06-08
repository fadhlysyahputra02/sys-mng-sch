import 'package:flutter/material.dart';

import '../../../core/services/auth_service.dart';
import '../../../core/services/user_service.dart';
import '../../schools/data/school_service.dart';
import 'login_page.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  String selectedRole = 'school_admin';

  final domainController = TextEditingController();
  final kodeController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final authService = AuthService();
  final userService = UserService();
  final schoolService = SchoolService();

  @override
  void dispose() {
    domainController.dispose();
    kodeController.dispose();
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Register')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            const Text(
              'Daftar Sebagai',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 12),

            DropdownButtonFormField<String>(
              value: selectedRole,
              items: const [
                DropdownMenuItem(
                  value: 'school_admin',
                  child: Text('Admin Sekolah'),
                ),
                DropdownMenuItem(
                  value: 'teacher',
                  child: Text('Guru (Segera Hadir)'),
                ),
                DropdownMenuItem(
                  value: 'student',
                  child: Text('Murid (Segera Hadir)'),
                ),
              ],
              onChanged: (value) {
                setState(() {
                  selectedRole = value!;
                });
              },
            ),

            const SizedBox(height: 16),

            TextField(
              controller: domainController,
              decoration: const InputDecoration(
                labelText: 'Domain Sekolah',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 16),

            TextField(
              controller: kodeController,
              decoration: const InputDecoration(
                labelText: 'Kode Registrasi',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 16),

            TextField(
              controller: emailController,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 16),

            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 24),

            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: () async {
                  if (selectedRole != 'school_admin') {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Role ini belum tersedia')),
                    );
                    return;
                  }

                  await registerAdmin();
                },
                child: const Text('REGISTER'),
              ),
            ),
            const SizedBox(height: 12),

            SizedBox(
              height: 50,
              child: OutlinedButton(
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginPage()),
                  );
                },
                child: const Text('KEMBALI KE LOGIN'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> registerAdmin() async {
    try {
      final domain = domainController.text.trim().toLowerCase();

      final school = await schoolService.getSchoolByDomain(domain);

      if (school == null) {
        throw Exception('Domain sekolah tidak ditemukan');
      }

      if (school['kodeAdmin'] != kodeController.text.trim()) {
        throw Exception('Kode admin tidak valid');
      }

      final credential = await authService.register(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      await userService.createUser(
        uid: credential.user!.uid,
        email: emailController.text.trim(),
        role: 'school_admin',
        schoolId: school['schoolId'],
      );

      debugPrint('REGISTER ADMIN BERHASIL UID: ${credential.user!.uid}');

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Register berhasil')));

        Navigator.pop(context);
      }
    } catch (e, stackTrace) {
      debugPrint('===== REGISTER ERROR =====');
      debugPrint(e.toString());
      debugPrint(stackTrace.toString());

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }
}
