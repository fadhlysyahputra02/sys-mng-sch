import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../app/routes/app_routes.dart';
import '../../../core/models/user_model.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/session_service.dart';
import '../../../core/services/user_service.dart';
import '../../../core/services/notification_listener_service.dart';
import '../../../core/services/push_notification_service.dart';
import '../widgets/auth_background.dart';
import '../widgets/theme_toggle_button.dart';


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
  String? _schoolLogoBase64;

  @override
  void initState() {
    super.initState();
    _loadLastEmail();
    _loadCachedSchoolLogo();
  }

  Future<void> _loadLastEmail() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastEmail = prefs.getString('last_logged_in_email');
      if (lastEmail != null && lastEmail.isNotEmpty && mounted) {
        setState(() {
          emailController.text = lastEmail;
        });
      }
    } catch (e) {
      debugPrint('Error loading last email: $e');
    }
  }

  Future<void> _loadCachedSchoolLogo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedSchoolId = prefs.getString('last_school_id');
      if (cachedSchoolId != null && cachedSchoolId.isNotEmpty) {
        final schoolDoc = await FirebaseFirestore.instance
            .collection('schools')
            .doc(cachedSchoolId)
            .get();
        if (schoolDoc.exists && mounted) {
          setState(() {
            _schoolLogoBase64 = schoolDoc.data()?['logoBase64'] as String?;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading cached school logo: $e');
    }
  }

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
        title: 'Formulir Tidak Lengkap',
        message: 'Silakan isi kolom email dan password.',
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
        final bool isActive = userData['isActive'] ?? true;

        // Cek apakah akun dinonaktifkan oleh admin
        if (!isActive) {
          if (mounted) {
            setState(() => _isLoading = false);
          }
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Akun Anda sedang dinonaktifkan. Harap hubungi admin untuk informasi lebih lanjut.',
              ),
              backgroundColor: Color(0xFFEF4444),
              duration: Duration(seconds: 6),
            ),
          );
          return;
        }

        if (tempPassword != null && tempPassword == password) {
          // Admin telah mereset password, login menggunakan password lama di Firebase Auth
          credential = await authService.login(
            email: email,
            password: firestorePassword ?? '',
          );

          // Update password di Firebase Auth ke password baru (tempPassword)
          await credential.user!.updatePassword(password);

          // Update password di Firestore & hapus tempPassword
          await doc.reference.update({
            'password': password,
            'tempPassword': FieldValue.delete(),
          });
        } else if (tempPassword != null && tempPassword != password) {
          // Admin sudah mereset password tapi user mencoba login dengan password lama.
          // Tolak login dan minta user gunakan password baru dari admin.
          if (mounted) {
            setState(() => _isLoading = false);
          }
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Password Anda telah direset oleh admin. Silakan gunakan password baru yang diberikan admin untuk login.',
              ),
              backgroundColor: Color(0xFFEF4444),
              duration: Duration(seconds: 5),
            ),
          );
          return;
        } else {
          // Jalur login standar (tidak ada tempPassword)
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
        throw ('User data not found');
      }

      SessionService.currentUser = UserModel.fromMap(
        uid,
        userData,
      );

      // Mulai mendengarkan notifikasi secara real-time
      NotificationListenerService().startListening();

      // Daftar perangkat untuk push notification
      PushNotificationService().registerUserDevice();

      // Save last logged in email
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('last_logged_in_email', email);
        // Cache schoolId for logo display on next login
        final schoolId = SessionService.currentUser?.schoolId;
        if (schoolId != null) {
          await prefs.setString('last_school_id', schoolId);
        }
      } catch (e) {
        debugPrint('Error saving last email: $e');
      }

      debugPrint('USER DATA: $userData');
      String role = (userData['role'] ?? '').toString().trim().toLowerCase();
      if (role == 'superadmin' || role == 'super-admin' || role == 'super_admin') {
        role = 'super_admin';
      } else if (role == 'schooladmin' || role == 'school-admin' || role == 'school_admin') {
        role = 'school_admin';
      }

      if (kIsWeb && role != 'super_admin' && role != 'school_admin' && role != 'teacher' && role != 'officer' && role != 'tu') {
        await FirebaseAuth.instance.signOut();
        throw ('Website access is only permitted for Admins, Teachers, Officers, and TU.');
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
        default:
          throw ('Unknown role');
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
        final isDark = AuthBackground.isDarkMode.value;
        final dialogBg = isDark ? const Color(0xFF1E1B4B) : Colors.white;
        final dialogBorder = isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.08);
        final titleColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
        final subtitleColor = isDark ? Colors.white.withValues(alpha: 0.6) : const Color(0xFF1E1B4B).withValues(alpha: 0.6);
        final inputBg = isDark ? Colors.white.withValues(alpha: 0.02) : Colors.black.withValues(alpha: 0.02);
        final inputBorder = isDark ? Colors.white.withValues(alpha: 0.15) : Colors.black.withValues(alpha: 0.15);
        final cancelBtnText = isDark ? Colors.white.withValues(alpha: 0.6) : const Color(0xFF1E1B4B).withValues(alpha: 0.6);
        final iconBg = isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03);

        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              backgroundColor: dialogBg,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: BorderSide(color: dialogBorder),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: iconBg,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.lock_reset_rounded,
                        color: Color(0xFF6366F1),
                        size: 40,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Reset Password',
                      style: TextStyle(
                        color: titleColor,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Masukkan email terdaftar Anda untuk menerima tautan reset password.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: subtitleColor,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: resetEmailController,
                      style: TextStyle(color: titleColor),
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: 'Email',
                        labelStyle: TextStyle(color: subtitleColor),
                        prefixIcon: Icon(
                          Icons.email_outlined,
                          color: subtitleColor,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: inputBorder,
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
                        fillColor: inputBg,
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
                                color: cancelBtnText,
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
    return ValueListenableBuilder<bool>(
      valueListenable: AuthBackground.isDarkMode,
      builder: (context, isDark, _) {
        final textColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
        final subtitleColor = isDark ? Colors.white.withOpacity(0.5) : const Color(0xFF1E1B4B).withOpacity(0.6);
        final cardColor = isDark ? Colors.white.withOpacity(0.06) : Colors.white;
        final cardBorderColor = isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.06);
        final fieldFillColor = isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.01);
        final fieldBorderColor = isDark ? Colors.white.withOpacity(0.15) : Colors.black.withOpacity(0.12);
        final labelColor = isDark ? Colors.white.withOpacity(0.6) : const Color(0xFF1E1B4B).withOpacity(0.6);
        final shadowColor = isDark ? Colors.black.withOpacity(0.35) : Colors.black.withOpacity(0.06);

        return Scaffold(
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            automaticallyImplyLeading: false,
            actions: const [
              ThemeToggleButton(),
            ],
          ),
          body: AuthBackground(
            child: Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Logo / Icon Aplikasi Premium Bersinar
                    _schoolLogoBase64 != null && _schoolLogoBase64!.isNotEmpty
                        ? Container(
                            width: 96,
                            height: 96,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isDark ? Colors.white.withOpacity(0.12) : Colors.black.withOpacity(0.08),
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF6366F1).withOpacity(isDark ? 0.25 : 0.1),
                                  blurRadius: 24,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: ClipOval(
                              child: Image.memory(
                                base64Decode(_schoolLogoBase64!),
                                fit: BoxFit.cover,
                                width: 96,
                                height: 96,
                                errorBuilder: (_, __, ___) => Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(Icons.school_rounded, size: 56, color: textColor),
                                ),
                              ),
                            ),
                          )
                        : Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isDark ? Colors.white.withOpacity(0.12) : Colors.black.withOpacity(0.08),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF6366F1).withOpacity(isDark ? 0.25 : 0.1),
                                  blurRadius: 24,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.school_rounded,
                              size: 56,
                              color: textColor,
                            ),
                          ),
                    
                    const SizedBox(height: 24),
                    
                    // Judul
                    Text(
                      'SYS MNG SCH',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                        letterSpacing: 2.5,
                      ),
                    ),
                    
                    const SizedBox(height: 8),
                    
                    Text(
                      'Sistem Manajemen Sekolah Modern',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: subtitleColor,
                      ),
                    ),
                    
                    const SizedBox(height: 36),
                    
                    // Form Card dengan Glassmorphism
                    Container(
                      // Padding dipindah ke dalam Stack
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                          color: cardBorderColor,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: shadowColor,
                            blurRadius: 24,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(28),
                        child: Stack(
                          children: [
                            // Latar belakang motif geometris modern
                            if (!isDark)
                              Positioned.fill(
                                child: Opacity(
                                  opacity: 0.10, // Dipertipis
                                  child: Image.asset(
                                    'assets/images/motif_mandala.png',
                                    fit: BoxFit.cover,
                                    repeat: ImageRepeat.repeat,
                                  ),
                                ),
                              ),
                            // Konten Form
                            Padding(
                              padding: const EdgeInsets.all(24.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(
                                    'MASUK KE AKUN',
                                    textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                              letterSpacing: 1.5,
                            ),
                          ),
                          
                          const SizedBox(height: 28),
                          
                          // Email Field
                          TextField(
                            controller: emailController,
                            style: TextStyle(color: textColor),
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            onSubmitted: (_) {
                              FocusScope.of(context).nextFocus();
                            },
                            decoration: InputDecoration(
                              labelText: 'Email',
                              labelStyle: TextStyle(color: labelColor),
                              prefixIcon: Icon(
                                Icons.email_outlined,
                                color: labelColor,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide(
                                  color: fieldBorderColor,
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
                              fillColor: fieldFillColor,
                            ),
                          ),
                          
                          const SizedBox(height: 18),
                          
                          // Password Field
                          TextField(
                            controller: passwordController,
                            obscureText: _obscurePassword,
                            style: TextStyle(color: textColor),
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) {
                              if (!_isLoading) _handleLogin();
                            },
                            decoration: InputDecoration(
                              labelText: 'Password',
                              labelStyle: TextStyle(color: labelColor),
                              prefixIcon: Icon(
                                Icons.lock_outline,
                                color: labelColor,
                              ),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  color: labelColor,
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
                                  color: fieldBorderColor,
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
                              fillColor: fieldFillColor,
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
                                  color: isDark ? Colors.white.withValues(alpha: 0.8) : const Color(0xFF1E1B4B).withValues(alpha: 0.8),
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
                                  color: const Color(0xFF6366F1).withOpacity(isDark ? 0.35 : 0.15),
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
                                      'MASUK',
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
                  ],
                ),
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
                          text: "Belum punya akun? ",
                          style: TextStyle(
                            color: isDark ? Colors.white.withOpacity(0.6) : const Color(0xFF1E1B4B).withOpacity(0.6),
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
                    TextButton(
                      onPressed: () {
                        Get.toNamed(AppRoutes.parentRegister);
                      },
                      child: RichText(
                        text: TextSpan(
                          text: 'Orang tua? ',
                          style: TextStyle(
                            color: isDark ? Colors.white.withOpacity(0.6) : const Color(0xFF1E1B4B).withOpacity(0.6),
                            fontSize: 14,
                          ),
                          children: const [
                            TextSpan(
                              text: 'Daftar sebagai Orang Tua',
                              style: TextStyle(
                                color: Color(0xFF6366F1),
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
      },
    );
  }
}
