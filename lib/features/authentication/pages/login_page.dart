import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../app/routes/app_routes.dart';
import '../../../core/models/user_model.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/session_service.dart';
import '../../../core/services/user_service.dart';
import '../widgets/auth_background.dart';

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
  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  void _showNotification({
    required String title,
    required String message,
    required bool isSuccess,
  }) {
    Get.rawSnackbar(
      titleText: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
      ),
      messageText: Text(
        message,
        style: const TextStyle(color: Colors.white70, fontSize: 14),
      ),
      icon: Icon(
        isSuccess ? Icons.check_circle_outline_rounded : Icons.warning_amber_rounded,
        color: Colors.white,
        size: 28,
      ),
      margin: const EdgeInsets.all(16),
      borderRadius: 16,
      backgroundColor: isSuccess ? const Color(0xFF10B981) : const Color(0xFFEF4444),
      duration: const Duration(seconds: 3),
      snackPosition: SnackPosition.TOP,
      barBlur: 8,
      boxShadows: [
        BoxShadow(
          color: (isSuccess ? const Color(0xFF10B981) : const Color(0xFFEF4444)).withOpacity(0.3),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  Future<void> _handleLogin() async {
    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showNotification(
        title: 'Form Belum Lengkap',
        message: 'Silakan isi email dan password Anda.',
        isSuccess: false,
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 1. Ambil data user dari Firestore berdasarkan email
      final userQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      UserCredential credential;

      if (userQuery.docs.isNotEmpty) {
        final doc = userQuery.docs.first;
        final userData = doc.data();
        final firestorePassword = userData['password'] as String?;
        final tempPassword = userData['tempPassword'] as String?;

        if (tempPassword != null && tempPassword == password) {
          // Admin telah mereset password, login menggunakan password lama
          credential = await authService.login(
            email: email,
            password: firestorePassword ?? '',
          );

          // Update password di Firebase Auth ke password baru
          await credential.user!.updatePassword(password);

          // Update password di Firestore & hapus tempPassword
          await doc.reference.update({
            'password': password,
            'tempPassword': FieldValue.delete(),
          });
        } else {
          // Jalur login standar
          credential = await authService.login(
            email: email,
            password: password,
          );

          // Sinkronisasi password yang dimasukkan ke Firestore agar selalu updated
          await doc.reference.update({
            'password': password,
          });
        }
      } else {
        // Fallback jika dokumen user belum dibuat di Firestore
        credential = await authService.login(
          email: email,
          password: password,
        );
      }

      debugPrint('LOGIN BERHASIL UID: ${credential.user?.uid}');
      final uid = credential.user!.uid;

      final userData = await userService.getUserById(uid);

      if (userData == null) {
        throw Exception('Data pengguna tidak ditemukan');
      }

      SessionService.currentUser = UserModel.fromMap(
        uid,
        userData,
      );

      debugPrint('USER DATA: $userData');
      final role = userData['role'];

      if (kIsWeb && role != 'super_admin' && role != 'school_admin' && role != 'teacher') {
        await FirebaseAuth.instance.signOut();
        throw Exception('Akses website hanya diperbolehkan untuk Admin dan Guru.');
      }

      if (!mounted) return;

      _showNotification(
        title: 'Login Berhasil',
        message: 'Selamat datang kembali di aplikasi!',
        isSuccess: true,
      );

      // Tambahkan delay kecil agar SnackBar sukses sempat terlihat sebelum pindah halaman
      await Future.delayed(const Duration(milliseconds: 1000));

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
    } catch (e) {
      debugPrint('LOGIN ERROR: $e');
      String errorMessage = 'Email atau password salah.';
      if (e.toString().contains('user-not-found')) {
        errorMessage = 'Akun tidak ditemukan.';
      } else if (e.toString().contains('wrong-password')) {
        errorMessage = 'Password salah.';
      } else if (e.toString().contains('invalid-email')) {
        errorMessage = 'Format email tidak valid.';
      } else if (e.toString().contains('Exception:')) {
        errorMessage = e.toString().replaceFirst('Exception: ', '');
      }

      _showNotification(
        title: 'Login Gagal',
        message: errorMessage,
        isSuccess: false,
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showForgotPasswordDialog() {
    final resetEmailController = TextEditingController(text: emailController.text);
    bool isResetting = false;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              backgroundColor: const Color(0xFF1E1B4B),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.lock_reset_rounded,
                        color: Color(0xFF6366F1),
                        size: 40,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Reset Password',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Masukkan email yang terdaftar untuk menerima tautan reset password.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: resetEmailController,
                      style: const TextStyle(color: Colors.white),
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: 'Email',
                        labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
                        prefixIcon: Icon(
                          Icons.email_outlined,
                          color: Colors.white.withValues(alpha: 0.6),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: Colors.white.withValues(alpha: 0.15),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(
                            color: Color(0xFF6366F1),
                            width: 1.5,
                          ),
                        ),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.02),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: isResetting ? null : () => Navigator.pop(dialogContext),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              'Batal',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.6),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              gradient: const LinearGradient(
                                colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                              ),
                            ),
                            child: ElevatedButton(
                              onPressed: isResetting
                                  ? null
                                  : () async {
                                      final email = resetEmailController.text.trim();
                                      if (email.isEmpty) return;

                                      setState(() => isResetting = true);
                                      try {
                                        await authService.sendPasswordResetEmail(email);
                                        if (dialogContext.mounted) {
                                          Navigator.pop(dialogContext);
                                          _showNotification(
                                            title: 'Email Terkirim',
                                            message: 'Tautan reset password telah dikirim ke $email',
                                            isSuccess: true,
                                          );
                                        }
                                      } catch (e) {
                                        if (dialogContext.mounted) {
                                          setState(() => isResetting = false);
                                          _showNotification(
                                            title: 'Gagal',
                                            message: e.toString().replaceFirst('Exception: ', ''),
                                            isSuccess: false,
                                          );
                                        }
                                      }
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: isResetting
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                      ),
                                    )
                                  : const Text(
                                      'Kirim',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AuthBackground(
        child: Center(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo / Icon Aplikasi Premium Bersinar
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withOpacity(0.12),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF6366F1).withOpacity(0.25),
                        blurRadius: 24,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.school_rounded,
                    size: 56,
                    color: Colors.white,
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Judul
                const Text(
                  'SYS MNG SCH',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 2.5,
                  ),
                ),
                
                const SizedBox(height: 8),
                
                Text(
                  'Sistem Manajemen Sekolah Modern',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.5),
                  ),
                ),
                
                const SizedBox(height: 36),
                
                // Form Card dengan Glassmorphism
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.1),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.35),
                        blurRadius: 24,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'MASUK KE AKUN',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 1.5,
                        ),
                      ),
                      
                      const SizedBox(height: 28),
                      
                      // Email Field
                      TextField(
                        controller: emailController,
                        style: const TextStyle(color: Colors.white),
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          labelText: 'Email',
                          labelStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
                          prefixIcon: Icon(
                            Icons.email_outlined,
                            color: Colors.white.withOpacity(0.6),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                              color: Colors.white.withOpacity(0.15),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(
                              color: Color(0xFF6366F1),
                              width: 1.5,
                            ),
                          ),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.02),
                        ),
                      ),
                      
                      const SizedBox(height: 18),
                      
                      // Password Field
                      TextField(
                        controller: passwordController,
                        obscureText: _obscurePassword,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Password',
                          labelStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
                          prefixIcon: Icon(
                            Icons.lock_outline,
                            color: Colors.white.withOpacity(0.6),
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              color: Colors.white.withOpacity(0.6),
                            ),
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                              color: Colors.white.withOpacity(0.15),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(
                              color: Color(0xFF6366F1),
                              width: 1.5,
                            ),
                          ),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.02),
                        ),
                      ),
                      
                      const SizedBox(height: 12),
                      
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _showForgotPasswordDialog,
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(
                            'Lupa Password?',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Tombol Login dengan Gradasi Modern
                      Container(
                        height: 52,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xFF6366F1), // Indigo
                              Color(0xFF8B5CF6), // Purple
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF6366F1).withOpacity(0.35),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _handleLogin,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  height: 24,
                                  width: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : const Text(
                                  'LOGIN',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 28),
                
                // Link navigasi ke Register
                TextButton(
                  onPressed: () {
                    Get.toNamed(AppRoutes.register);
                  },
                  child: RichText(
                    text: TextSpan(
                      text: 'Belum punya akun? ',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 14,
                      ),
                      children: const [
                        TextSpan(
                          text: 'Daftar Sekarang',
                          style: TextStyle(
                            color: Color(0xFF8B5CF6),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
