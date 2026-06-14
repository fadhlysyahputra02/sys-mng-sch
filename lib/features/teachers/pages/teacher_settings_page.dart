import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import '../../../core/services/session_service.dart';
import '../../authentication/widgets/auth_background.dart';

class TeacherSettingsPage extends StatefulWidget {
  const TeacherSettingsPage({super.key});

  @override
  State<TeacherSettingsPage> createState() => _TeacherSettingsPageState();
}

class _TeacherSettingsPageState extends State<TeacherSettingsPage> {
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
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
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
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
          color: (isSuccess ? const Color(0xFF10B981) : const Color(0xFFEF4444)).withValues(alpha: 0.3),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  Future<void> _changePassword() async {
    final currentPassword = _currentPasswordController.text.trim();
    final newPassword = _newPasswordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (currentPassword.isEmpty || newPassword.isEmpty || confirmPassword.isEmpty) {
      _showNotification(title: 'Gagal', message: 'Semua field wajib diisi', isSuccess: false);
      return;
    }

    if (newPassword.length < 6) {
      _showNotification(title: 'Gagal', message: 'Password baru minimal 6 karakter', isSuccess: false);
      return;
    }

    if (newPassword != confirmPassword) {
      _showNotification(title: 'Gagal', message: 'Konfirmasi password tidak cocok', isSuccess: false);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser!;
      final email = user.email!;

      // Re-authenticate dengan password saat ini
      final credential = EmailAuthProvider.credential(email: email, password: currentPassword);
      await user.reauthenticateWithCredential(credential);

      // Update password
      await user.updatePassword(newPassword);

      // Update password di Firestore agar sinkron
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
        'password': newPassword,
      });

      _currentPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();

      if (mounted) {
        _showNotification(title: 'Berhasil', message: 'Password berhasil diubah!', isSuccess: true);
      }
    } on FirebaseAuthException catch (e) {
      String msg;
      switch (e.code) {
        case 'wrong-password':
        case 'invalid-credential':
          msg = 'Password saat ini salah';
          break;
        case 'weak-password':
          msg = 'Password baru terlalu lemah';
          break;
        default:
          msg = e.message ?? 'Terjadi kesalahan';
      }
      if (mounted) {
        _showNotification(title: 'Gagal', message: msg, isSuccess: false);
      }
    } catch (e) {
      if (mounted) {
        _showNotification(title: 'Gagal', message: e.toString(), isSuccess: false);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = SessionService.currentUser!;

    return Scaffold(
      body: AuthBackground(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // AppBar
            SliverAppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              pinned: true,
              leading: Container(
                margin: const EdgeInsets.only(left: 16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              title: const Text(
                'Pengaturan',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
              ),
            ),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Info Akun
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF8B5CF6).withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.person_rounded, color: Color(0xFF8B5CF6), size: 28),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  user.nama,
                                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  user.email,
                                  style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 28),

                    // Section Ubah Password
                    Row(
                      children: [
                        Icon(Icons.lock_rounded, color: Colors.white.withValues(alpha: 0.8), size: 20),
                        const SizedBox(width: 8),
                        const Text(
                          'Ubah Password',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 0.5),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          // Password Saat Ini
                          _buildPasswordField(
                            controller: _currentPasswordController,
                            label: 'Password Saat Ini',
                            icon: Icons.lock_outline_rounded,
                            obscure: _obscureCurrent,
                            onToggle: () => setState(() => _obscureCurrent = !_obscureCurrent),
                          ),

                          const SizedBox(height: 18),

                          // Password Baru
                          _buildPasswordField(
                            controller: _newPasswordController,
                            label: 'Password Baru',
                            icon: Icons.lock_reset_rounded,
                            obscure: _obscureNew,
                            onToggle: () => setState(() => _obscureNew = !_obscureNew),
                          ),

                          const SizedBox(height: 18),

                          // Konfirmasi Password Baru
                          _buildPasswordField(
                            controller: _confirmPasswordController,
                            label: 'Konfirmasi Password Baru',
                            icon: Icons.lock_rounded,
                            obscure: _obscureConfirm,
                            onToggle: () => setState(() => _obscureConfirm = !_obscureConfirm),
                          ),

                          const SizedBox(height: 28),

                          // Tombol Simpan
                          Container(
                            height: 52,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              gradient: const LinearGradient(
                                colors: [Color(0xFF8B5CF6), Color(0xFFD946EF)],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.35),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _changePassword,
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
                                      'SIMPAN PASSWORD',
                                      style: TextStyle(
                                        fontSize: 15,
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

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required bool obscure,
    required VoidCallback onToggle,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
        prefixIcon: Icon(icon, color: Colors.white.withValues(alpha: 0.6)),
        suffixIcon: IconButton(
          icon: Icon(
            obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            color: Colors.white.withValues(alpha: 0.6),
          ),
          onPressed: onToggle,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF6366F1), width: 1.5),
        ),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.02),
      ),
    );
  }
}
