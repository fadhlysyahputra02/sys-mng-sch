import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/services/session_service.dart';
import '../../authentication/widgets/auth_background.dart';

class TeacherSettingsPage extends StatefulWidget {
  final bool hideBackButton;
  const TeacherSettingsPage({super.key, this.hideBackButton = false});

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

  // ── Foto Profil ─────────────────────────────────────────────────
  String? _fotoBase64;
  bool _isUploadingFoto = false;
  String? _userDocId; // doc id di subcollection teachers/students

  @override
  void initState() {
    super.initState();
    _loadFotoProfil();
  }

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  /// Load foto profil dari Firestore sesuai role user
  Future<void> _loadFotoProfil() async {
    final user = SessionService.currentUser;
    if (user == null) return;
    try {
      final role = user.role;
      final schoolId = user.schoolId;
      final uid = user.uid;

      if (role == 'teacher' || role == 'officer' || role == 'librarian') {
        final snap = await FirebaseFirestore.instance
            .collection('schools')
            .doc(schoolId)
            .collection('teachers')
            .where('uid', isEqualTo: uid)
            .limit(1)
            .get();
        if (snap.docs.isNotEmpty && mounted) {
          setState(() {
            _userDocId = snap.docs.first.id;
            _fotoBase64 = snap.docs.first.data()['fotoBase64'] as String?;
          });
        }
      } else if (role == 'student') {
        final snap = await FirebaseFirestore.instance
            .collection('schools')
            .doc(schoolId)
            .collection('students')
            .where('uid', isEqualTo: uid)
            .limit(1)
            .get();
        if (snap.docs.isNotEmpty && mounted) {
          setState(() {
            _userDocId = snap.docs.first.id;
            _fotoBase64 = snap.docs.first.data()['fotoBase64'] as String?;
          });
        }
      }
    } catch (_) {}
  }

  /// Pilih foto & upload ke Firestore
  Future<void> _pickAndUploadFoto() async {
    final user = SessionService.currentUser;
    if (user == null) return;

    try {
      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 400,
        maxHeight: 400,
        imageQuality: 75,
      );
      if (image == null) return;

      final bytes = await image.readAsBytes();
      final base64Str = base64Encode(bytes);

      setState(() => _isUploadingFoto = true);

      final role = user.role;
      final schoolId = user.schoolId;
      final uid = user.uid;

      String? docId = _userDocId;

      if (docId == null) {
        // Cari docId dulu
        final coll = (role == 'student') ? 'students' : 'teachers';
        final snap = await FirebaseFirestore.instance
            .collection('schools')
            .doc(schoolId)
            .collection(coll)
            .where('uid', isEqualTo: uid)
            .limit(1)
            .get();
        if (snap.docs.isNotEmpty) {
          docId = snap.docs.first.id;
          _userDocId = docId;
        }
      }

      if (docId != null) {
        final coll = (role == 'student') ? 'students' : 'teachers';
        await FirebaseFirestore.instance
            .collection('schools')
            .doc(schoolId)
            .collection(coll)
            .doc(docId)
            .update({'fotoBase64': base64Str});

        if (mounted) {
          setState(() {
            _fotoBase64 = base64Str;
            _isUploadingFoto = false;
          });
          _showNotification(
            title: 'Berhasil',
            message: 'Foto profil berhasil diperbarui!',
            isSuccess: true,
          );
        }
      } else {
        if (mounted) setState(() => _isUploadingFoto = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploadingFoto = false);
        _showNotification(
          title: 'Gagal',
          message: 'Gagal mengupload foto: $e',
          isSuccess: false,
        );
      }
    }
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

    return ValueListenableBuilder<bool>(
      valueListenable: AuthBackground.isDarkMode,
      builder: (context, isDark, _) {
        final titleColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
        final backButtonBgColor = isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05);
        final backButtonIconColor = isDark ? Colors.white : const Color(0xFF1E1B4B);

        final cardBg = isDark ? Colors.white.withValues(alpha: 0.06) : Colors.white;
        final cardBorder = isDark ? Colors.white.withValues(alpha: 0.10) : Colors.black.withValues(alpha: 0.08);
        final cardShadow = isDark ? Colors.transparent : Colors.black.withValues(alpha: 0.04);

        final textPrimaryColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
        final textSecondaryColor = isDark ? Colors.white.withValues(alpha: 0.45) : const Color(0xFF1E1B4B).withValues(alpha: 0.6);

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
                  automaticallyImplyLeading: !widget.hideBackButton,
                  leading: widget.hideBackButton
                      ? null
                      : Container(
                          margin: const EdgeInsets.only(left: 16),
                          decoration: BoxDecoration(
                            color: backButtonBgColor,
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            icon: Icon(Icons.arrow_back_ios_new_rounded, color: backButtonIconColor, size: 18),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ),
                  title: Text(
                    'Pengaturan',
                    style: TextStyle(color: titleColor, fontWeight: FontWeight.bold, fontSize: 20),
                  ),
                ),

                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // ── Foto Profil ──────────────────────────────────────
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: cardBorder),
                            boxShadow: isDark
                                ? []
                                : [
                                    BoxShadow(
                                      color: cardShadow,
                                      blurRadius: 16,
                                      offset: const Offset(0, 6),
                                    ),
                                  ],
                          ),
                          child: Column(
                            children: [
                              // Header section title
                              Row(
                                children: [
                                  Icon(Icons.account_circle_rounded, color: const Color(0xFF8B5CF6), size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Foto Profil',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: textPrimaryColor,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              // Avatar + camera button
                              Stack(
                                alignment: Alignment.bottomRight,
                                children: [
                                  Container(
                                    width: 96,
                                    height: 96,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: _fotoBase64 == null
                                          ? const LinearGradient(
                                              colors: [Color(0xFF8B5CF6), Color(0xFF3B82F6)],
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                            )
                                          : null,
                                      border: Border.all(
                                        color: const Color(0xFF8B5CF6).withValues(alpha: 0.5),
                                        width: 2.5,
                                      ),
                                    ),
                                    child: ClipOval(
                                      child: _fotoBase64 != null
                                          ? Image.memory(
                                              base64Decode(_fotoBase64!),
                                              fit: BoxFit.cover,
                                            )
                                          : const Icon(
                                              Icons.person_rounded,
                                              color: Colors.white,
                                              size: 48,
                                            ),
                                    ),
                                  ),
                                  // Camera overlay button
                                  GestureDetector(
                                    onTap: _isUploadingFoto ? null : _pickAndUploadFoto,
                                    child: Container(
                                      width: 32,
                                      height: 32,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: const LinearGradient(
                                          colors: [Color(0xFF8B5CF6), Color(0xFFD946EF)],
                                        ),
                                        border: Border.all(color: isDark ? const Color(0xFF0F0C20) : Colors.white, width: 2),
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(0xFF8B5CF6).withValues(alpha: 0.4),
                                            blurRadius: 8,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: _isUploadingFoto
                                          ? const Padding(
                                              padding: EdgeInsets.all(6),
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                              ),
                                            )
                                          : const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 16),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              Text(
                                user.nama,
                                style: TextStyle(
                                  color: textPrimaryColor,
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                user.email,
                                style: TextStyle(color: textSecondaryColor, fontSize: 13),
                              ),
                              const SizedBox(height: 12),
                              // Upload hint
                              GestureDetector(
                                onTap: _isUploadingFoto ? null : _pickAndUploadFoto,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: const Color(0xFF8B5CF6).withValues(alpha: 0.3),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.upload_rounded,
                                        color: const Color(0xFF8B5CF6),
                                        size: 16,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        _fotoBase64 == null ? 'Upload Foto Profil' : 'Ganti Foto Profil',
                                        style: const TextStyle(
                                          color: Color(0xFF8B5CF6),
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 28),

                        // Section Ubah Password
                        Row(
                          children: [
                            Icon(Icons.lock_rounded, color: textPrimaryColor.withValues(alpha: 0.8), size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'Ubah Password',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textPrimaryColor, letterSpacing: 0.5),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: cardBorder),
                            boxShadow: isDark
                                ? []
                                : [
                                    BoxShadow(
                                      color: cardShadow,
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
                                isDark: isDark,
                              ),

                              const SizedBox(height: 18),

                              // Password Baru
                              _buildPasswordField(
                                controller: _newPasswordController,
                                label: 'Password Baru',
                                icon: Icons.lock_reset_rounded,
                                obscure: _obscureNew,
                                onToggle: () => setState(() => _obscureNew = !_obscureNew),
                                isDark: isDark,
                              ),

                              const SizedBox(height: 18),

                              // Konfirmasi Password Baru
                              _buildPasswordField(
                                controller: _confirmPasswordController,
                                label: 'Konfirmasi Password Baru',
                                icon: Icons.lock_rounded,
                                obscure: _obscureConfirm,
                                onToggle: () => setState(() => _obscureConfirm = !_obscureConfirm),
                                isDark: isDark,
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
      },
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required bool obscure,
    required VoidCallback onToggle,
    required bool isDark,
  }) {
    final fieldBg = isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04);
    final fieldBorder = isDark ? Colors.white.withValues(alpha: 0.10) : Colors.black.withValues(alpha: 0.08);
    final textStyleColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
    final labelColor = isDark ? Colors.white.withValues(alpha: 0.5) : const Color(0xFF1E1B4B).withValues(alpha: 0.6);
    final iconColor = isDark ? Colors.white.withValues(alpha: 0.4) : const Color(0xFF1E1B4B).withValues(alpha: 0.5);

    return Container(
      decoration: BoxDecoration(
        color: fieldBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: fieldBorder),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        style: TextStyle(color: textStyleColor),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: labelColor),
          prefixIcon: Icon(icon, color: const Color(0xFF8B5CF6)),
          suffixIcon: IconButton(
            icon: Icon(
              obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
              color: iconColor,
            ),
            onPressed: onToggle,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }
}
