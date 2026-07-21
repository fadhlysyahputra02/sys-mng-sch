import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../authentication/widgets/auth_background.dart';
import '../data/student_admin_service.dart';
import 'edit_student_admin_page.dart';

class StudentDetailPage extends StatefulWidget {
  final Map<String, dynamic> student;

  const StudentDetailPage({super.key, required this.student});

  @override
  State<StudentDetailPage> createState() => _StudentDetailPageState();
}

class _StudentDetailPageState extends State<StudentDetailPage> {
  late Map<String, dynamic> student;
  final _studentService = StudentService();
  bool _isUploadingFoto = false;

  Future<void> _pickAndUploadFoto() async {
    try {
      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 400,
        maxHeight: 400,
        imageQuality: 75,
      );
      if (image == null) return;

      setState(() => _isUploadingFoto = true);

      final bytes = await image.readAsBytes();
      final base64Str = base64Encode(bytes);

      await FirebaseFirestore.instance
          .collection('schools')
          .doc(student['schoolId'])
          .collection('students')
          .doc(student['studentId'])
          .update({'fotoBase64': base64Str});

      final String? uid = student['uid'];
      if (uid != null && uid.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .update({'fotoBase64': base64Str});
      }

      setState(() {
        student['fotoBase64'] = base64Str;
        _isUploadingFoto = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Foto profil murid berhasil diperbarui!'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploadingFoto = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mengupload foto: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  @override
  void initState() {
    super.initState();
    student = Map<String, dynamic>.from(widget.student);
  }

  void _navigateToEditPage() async {
    final updatedStudent = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditStudentAdminPage(student: student),
      ),
    );

    if (updatedStudent != null) {
      setState(() {
        student = updatedStudent as Map<String, dynamic>;
      });
    }
  }

  void _showDeleteDialog() {
    final isDark = AuthBackground.isDarkMode.value;
    final textColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
    final subTextColor = isDark ? Colors.white.withValues(alpha: 0.55) : const Color(0xFF1E1B4B).withValues(alpha: 0.65);
    final borderColor = isDark ? Colors.white.withValues(alpha: 0.10) : Colors.black.withValues(alpha: 0.08);
    final dialogBg = isDark ? const Color(0xFF0F0C20) : Colors.white;
    final inputBgColor = isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04);

    final TextEditingController nisController = TextEditingController();
    String? errorText;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: dialogBg,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: BorderSide(color: borderColor, width: 1.5),
              ),
              contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 30),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Hapus Murid',
                    style: TextStyle(fontWeight: FontWeight.bold, color: textColor, fontSize: 18),
                  ),
                  const SizedBox(height: 12),
                  RichText(
                    textAlign: TextAlign.center,
                    text: TextSpan(
                      style: TextStyle(color: subTextColor, fontSize: 13, height: 1.5),
                      children: [
                        const TextSpan(text: 'Apakah Anda yakin ingin menghapus '),
                        TextSpan(
                          text: '${student['nama']}',
                          style: TextStyle(color: textColor, fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                        const TextSpan(text: '?\nData ini tidak dapat dikembalikan.\n\nKetik NIS '),
                        TextSpan(
                          text: '${student['nis']}',
                          style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
                        ),
                        const TextSpan(text: ' untuk konfirmasi.'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: nisController,
                    style: TextStyle(color: textColor, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Masukkan NIS',
                      hintStyle: TextStyle(color: subTextColor),
                      errorText: errorText,
                      filled: true,
                      fillColor: inputBgColor,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: borderColor),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: borderColor),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.red.withValues(alpha: 0.5)),
                      ),
                    ),
                    onChanged: (val) {
                      if (errorText != null) setState(() => errorText = null);
                    },
                  ),
                ],
              ),
              actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              actions: [
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          side: BorderSide(color: borderColor),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () => Navigator.pop(ctx),
                        child: Text('Batal', style: TextStyle(color: textColor)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () async {
                          if (nisController.text.trim() != student['nis'].toString()) {
                            setState(() {
                              errorText = 'NIS tidak cocok';
                            });
                            return;
                          }
                          await _studentService.deleteStudent(student['studentId']);
                          if (ctx.mounted) {
                            Navigator.pop(ctx);
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Murid berhasil dihapus')),
                            );
                          }
                        },
                        child: const Text('Hapus', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _handleResetPassword(BuildContext context, String? email, bool isRegistered) async {
    final isDark = AuthBackground.isDarkMode.value;
    final textColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
    final subTextColor = isDark ? Colors.white.withValues(alpha: 0.55) : const Color(0xFF1E1B4B).withValues(alpha: 0.65);
    final cardBgColor = isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04);
    final borderColor = isDark ? Colors.white.withValues(alpha: 0.10) : Colors.black.withValues(alpha: 0.08);
    final dialogBg = isDark ? const Color(0xFF0F0C20) : Colors.white;

    if (email == null || email.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Murid ini tidak memiliki alamat email yang valid.'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
      return;
    }

    if (!isRegistered) {
      showDialog(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: dialogBg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: borderColor),
          ),
          title: Row(
            children: [
              const Icon(Icons.info_outline_rounded, color: Colors.orange),
              const SizedBox(width: 10),
              Text(
                'Akun Belum Terdaftar',
                style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ],
          ),
          content: Text(
            'Akun dengan email $email belum melakukan registrasi di aplikasi. Reset password hanya dapat dilakukan untuk akun yang sudah aktif/terdaftar.',
            style: TextStyle(color: subTextColor, fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('OK', style: TextStyle(color: Color(0xFF0EA5E9), fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
      return;
    }

    final String? uid = student['uid'];
    if (uid == null || uid.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ID Pengguna tidak valid.'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
      return;
    }

    final TextEditingController newPasswordController = TextEditingController();
    bool obscurePassword = true;

    final String? newPassword = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) {
          final pass = newPasswordController.text;
          final hasUppercase = RegExp(r'[A-Z]').hasMatch(pass);
          final hasLowercase = RegExp(r'[a-z]').hasMatch(pass);
          final hasNumber = RegExp(r'[0-9]').hasMatch(pass);
          final hasSpecialChar = RegExp(r'[!@#\$%^&*(),.?":{}|<>]').hasMatch(pass);
          final isPasswordValid = pass.length >= 6 && hasUppercase && hasLowercase && hasNumber && hasSpecialChar;

          Widget buildRequirementItem(String label, bool isMet) {
            final activeColor = const Color(0xFF10B981);
            final inactiveColor = isDark ? Colors.white38 : Colors.black38;
            final itemTextColor = isDark ? Colors.white70 : Colors.black87;
            return Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Row(
                children: [
                  Icon(
                    isMet ? Icons.check_circle_rounded : Icons.radio_button_off_rounded,
                    color: isMet ? activeColor : inactiveColor,
                    size: 15,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        color: isMet ? activeColor : itemTextColor,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          return AlertDialog(
            backgroundColor: dialogBg,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: BorderSide(color: borderColor, width: 1.5),
            ),
            contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0EA5E9), Color(0xFF6366F1)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.lock_reset_rounded, color: Colors.white, size: 26),
                ),
                const SizedBox(height: 16),
                Text(
                  'Reset Password Murid',
                  style: TextStyle(fontWeight: FontWeight.bold, color: textColor, fontSize: 18),
                ),
                const SizedBox(height: 12),
                Text(
                  'Masukkan password baru untuk murid ${student['nama']}. Murid dapat langsung login menggunakan password baru ini.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: subTextColor, fontSize: 13, height: 1.5),
                ),
                const SizedBox(height: 20),
                Container(
                  decoration: BoxDecoration(
                    color: cardBgColor,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: borderColor),
                  ),
                  child: TextField(
                    controller: newPasswordController,
                    obscureText: obscurePassword,
                    style: TextStyle(color: textColor),
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: 'Password Baru',
                      labelStyle: TextStyle(color: subTextColor),
                      prefixIcon: Icon(Icons.lock_outline_rounded, color: subTextColor),
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                          color: subTextColor,
                        ),
                        onPressed: () => setState(() => obscurePassword = !obscurePassword),
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      buildRequirementItem('Minimal 6 karakter', pass.length >= 6),
                      buildRequirementItem('Memiliki huruf besar (A-Z)', hasUppercase),
                      buildRequirementItem('Memiliki huruf kecil (a-z)', hasLowercase),
                      buildRequirementItem('Memiliki angka (0-9)', hasNumber),
                      buildRequirementItem('Memiliki karakter khusus (!@#\$%^&* dll)', hasSpecialChar),
                    ],
                  ),
                ),
              ],
            ),
            actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            actions: [
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        side: BorderSide(color: borderColor),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => Navigator.pop(dialogContext),
                      child: Text('Batal', style: TextStyle(color: textColor)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0EA5E9),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: !isPasswordValid
                          ? null
                          : () {
                              Navigator.pop(dialogContext, newPasswordController.text.trim());
                            },
                      child: const Text('Simpan', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    if (newPassword == null) return;

    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'tempPassword': newPassword,
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Password berhasil direset secara manual!'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mereset password: ${e.toString()}'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  Widget _buildDetailSection(String title, IconData icon, List<Widget> children, Color textColor, Color borderColor, Color bgColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: [
                Icon(icon, size: 20, color: const Color(0xFF6366F1)),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1, color: Colors.black12),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: children,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String? value, Color textColor, Color subTextColor) {
    final displayValue = (value == null || value.trim().isEmpty) ? '-' : value;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(color: subTextColor, fontSize: 13),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: Text(
              displayValue,
              style: TextStyle(
                color: textColor,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isRegistered = student['sudahRegister'] == true;
    final bool isAktif = student['aktif'] == true;
    final String nama = student['nama'] ?? '-';
    final String inisial = nama.isNotEmpty ? nama[0].toUpperCase() : '?';
    final String? className = student['className'];
    final bool hasClass = className != null && className.isNotEmpty;

    return ValueListenableBuilder<bool>(
      valueListenable: AuthBackground.isDarkMode,
      builder: (context, isDark, _) {
        final textColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
        final subTextColor = isDark ? Colors.white.withValues(alpha: 0.55) : const Color(0xFF1E1B4B).withValues(alpha: 0.65);
        final cardBgColor = isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04);
        final borderColor = isDark ? Colors.white.withValues(alpha: 0.10) : Colors.black.withValues(alpha: 0.08);

        return Scaffold(
          body: AuthBackground(
            child: Column(
              children: [
                // ── AppBar ─────────────────────────────────────────────────────
                SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: Icon(Icons.arrow_back_ios_new_rounded, color: textColor, size: 20),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            'Detail Murid',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
                          ),
                        ),
                        // Edit button
                        Container(
                          margin: const EdgeInsets.only(right: 4),
                          decoration: BoxDecoration(
                            color: cardBgColor,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: borderColor),
                          ),
                          child: IconButton(
                            icon: Icon(Icons.edit_outlined, color: textColor, size: 20),
                            tooltip: 'Edit Murid',
                            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                            padding: EdgeInsets.zero,
                            onPressed: _navigateToEditPage,
                          ),
                        ),
                        // Delete button
                        Container(
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.red.withValues(alpha: 0.25)),
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                            tooltip: 'Hapus Murid',
                            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                            padding: EdgeInsets.zero,
                            onPressed: _showDeleteDialog,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // ── Body ────────────────────────────────────────────────────────
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Profile Card ────────────────────────────────────────
                        // ── Profile Card ────────────────────────────────────────
                        Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF0EA5E9), Color(0xFF6366F1)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.15), width: 1.5),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF0EA5E9).withValues(alpha: 0.35),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(24),
                            child: Stack(
                              children: [
                                // Decoration circles
                                Positioned(
                                  top: -40,
                                  right: -20,
                                  child: Container(
                                    width: 130,
                                    height: 130,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.white.withValues(alpha: 0.1),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  bottom: -30,
                                  right: 60,
                                  child: Container(
                                    width: 80,
                                    height: 80,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.white.withValues(alpha: 0.1),
                                    ),
                                  ),
                                ),
                                // Content
                                Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Avatar
                                      GestureDetector(
                                        onTap: _isUploadingFoto ? null : _pickAndUploadFoto,
                                        child: Stack(
                                          alignment: Alignment.bottomRight,
                                          children: [
                                            Container(
                                              width: 66,
                                              height: 66,
                                              decoration: BoxDecoration(
                                                color: Colors.white.withValues(alpha: 0.2),
                                                borderRadius: BorderRadius.circular(18),
                                                border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 2),
                                              ),
                                              child: ClipRRect(
                                                borderRadius: BorderRadius.circular(16),
                                                child: student['fotoBase64'] != null && student['fotoBase64'].toString().isNotEmpty
                                                    ? Image.memory(
                                                        base64Decode(student['fotoBase64']),
                                                        fit: BoxFit.cover,
                                                      )
                                                    : Center(
                                                        child: Text(
                                                          inisial,
                                                          style: const TextStyle(
                                                            color: Colors.white,
                                                            fontSize: 28,
                                                            fontWeight: FontWeight.bold,
                                                          ),
                                                        ),
                                                      ),
                                              ),
                                            ),
                                            Container(
                                              decoration: const BoxDecoration(
                                                color: Colors.white,
                                                shape: BoxShape.circle,
                                              ),
                                              padding: const EdgeInsets.all(4),
                                              child: _isUploadingFoto
                                                  ? const SizedBox(
                                                      width: 10,
                                                      height: 10,
                                                      child: CircularProgressIndicator(
                                                        strokeWidth: 1.5,
                                                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0EA5E9)),
                                                      ),
                                                    )
                                                  : const Icon(
                                                      Icons.camera_alt_rounded,
                                                      size: 10,
                                                      color: Color(0xFF0EA5E9),
                                                    ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 18),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              nama,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 20,
                                                color: Colors.white,
                                                letterSpacing: 0.3,
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            Row(
                                              children: [
                                                Icon(Icons.badge_outlined, size: 14, color: Colors.white.withValues(alpha: 0.7)),
                                                const SizedBox(width: 5),
                                                Text(
                                                  'NIS: ${student['nis'] ?? '-'}',
                                                  style: TextStyle(
                                                    color: Colors.white.withValues(alpha: 0.8),
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 10),
                                            // Badges row
                                            Wrap(
                                              spacing: 6,
                                              children: [
                                                // Status registrasi
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color: isRegistered
                                                        ? Colors.white.withValues(alpha: 0.25)
                                                        : Colors.orange.withValues(alpha: 0.3),
                                                    borderRadius: BorderRadius.circular(20),
                                                    border: Border.all(
                                                      color: isRegistered
                                                          ? Colors.white.withValues(alpha: 0.4)
                                                          : Colors.orange.withValues(alpha: 0.5),
                                                    ),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Icon(
                                                        isRegistered ? Icons.verified_rounded : Icons.pending_rounded,
                                                        size: 11,
                                                        color: Colors.white,
                                                      ),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        isRegistered ? 'Terdaftar' : 'Belum Registrasi',
                                                        style: const TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 11,
                                                          fontWeight: FontWeight.bold,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                if (student['lulus'] == true) ...[
                                                  const SizedBox(width: 6),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                    decoration: BoxDecoration(
                                                      color: const Color(0xFF6366F1).withValues(alpha: 0.35),
                                                      borderRadius: BorderRadius.circular(20),
                                                      border: Border.all(
                                                        color: const Color(0xFF6366F1).withValues(alpha: 0.5),
                                                      ),
                                                    ),
                                                    child: const Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        Icon(
                                                          Icons.school_rounded,
                                                          size: 11,
                                                          color: Colors.white,
                                                        ),
                                                        SizedBox(width: 4),
                                                        Text(
                                                          'Lulus (Alumni)',
                                                          style: TextStyle(
                                                            color: Colors.white,
                                                            fontSize: 11,
                                                            fontWeight: FontWeight.bold,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // ── Section Data Pribadi ───────────────────────────────────────
                        _buildDetailSection(
                          'Data Pribadi & Akademik',
                          Icons.person_outline_rounded,
                          [
                            _buildInfoRow('NISN', student['nisn']?.toString(), textColor, subTextColor),
                            _buildInfoRow('Kelas', hasClass ? className : 'Belum ditentukan', textColor, subTextColor),
                            _buildInfoRow('Jenis Kelamin', student['gender']?.toString(), textColor, subTextColor),
                            _buildInfoRow('Tempat Lahir', student['tempatLahir']?.toString(), textColor, subTextColor),
                            _buildInfoRow('Tanggal Lahir', student['tanggalLahir']?.toString(), textColor, subTextColor),
                            _buildInfoRow('Agama', student['agama']?.toString(), textColor, subTextColor),
                            _buildInfoRow('Kewarganegaraan', student['kewarganegaraan']?.toString(), textColor, subTextColor),
                            _buildInfoRow('Alamat', student['alamat']?.toString(), textColor, subTextColor),
                            _buildInfoRow('No. HP', student['noHp']?.toString(), textColor, subTextColor),
                            _buildInfoRow('Angkatan', student['angkatan']?.toString(), textColor, subTextColor),
                            _buildInfoRow('Jalur Masuk', student['jalurMasuk']?.toString(), textColor, subTextColor),
                            _buildInfoRow('Tanggal Diterima', student['tanggalDiterima']?.toString(), textColor, subTextColor),
                            _buildInfoRow('Email', student['email']?.toString(), textColor, subTextColor),
                            _buildInfoRow('Status Keaktifan', student['lulus'] == true ? 'Alumni (Lulus)' : (isAktif ? 'Aktif' : 'Tidak Aktif'), textColor, subTextColor),
                          ],
                          textColor,
                          borderColor,
                          cardBgColor,
                        ),

                        // ── Section Data Ayah ───────────────────────────────────────
                        _buildDetailSection(
                          'Data Ayah',
                          Icons.person_outline_rounded,
                          [
                            _buildInfoRow('Nama Ayah', student['namaAyah']?.toString(), textColor, subTextColor),
                            _buildInfoRow('NIK Ayah', student['nikAyah']?.toString(), textColor, subTextColor),
                            _buildInfoRow('Pekerjaan', student['pekerjaanAyah']?.toString(), textColor, subTextColor),
                            _buildInfoRow('Pendidikan', student['pendidikanAyah']?.toString(), textColor, subTextColor),
                            _buildInfoRow('No. HP', student['noHpAyah']?.toString(), textColor, subTextColor),
                          ],
                          textColor,
                          borderColor,
                          cardBgColor,
                        ),

                        // ── Section Data Ibu ───────────────────────────────────────
                        _buildDetailSection(
                          'Data Ibu',
                          Icons.person_outline_rounded,
                          [
                            _buildInfoRow('Nama Ibu', student['namaIbu']?.toString(), textColor, subTextColor),
                            _buildInfoRow('NIK Ibu', student['nikIbu']?.toString(), textColor, subTextColor),
                            _buildInfoRow('Pekerjaan', student['pekerjaanIbu']?.toString(), textColor, subTextColor),
                            _buildInfoRow('Pendidikan', student['pendidikanIbu']?.toString(), textColor, subTextColor),
                            _buildInfoRow('No. HP', student['noHpIbu']?.toString(), textColor, subTextColor),
                          ],
                          textColor,
                          borderColor,
                          cardBgColor,
                        ),

                        // ── Section Data Wali ───────────────────────────────────────
                        _buildDetailSection(
                          'Data Wali (Jika Ada)',
                          Icons.family_restroom_rounded,
                          [
                            _buildInfoRow('Nama Wali', student['namaWali']?.toString(), textColor, subTextColor),
                            _buildInfoRow('Hubungan', student['hubunganWali']?.toString(), textColor, subTextColor),
                            _buildInfoRow('No. HP', student['noHpWali']?.toString(), textColor, subTextColor),
                            _buildInfoRow('Alamat', student['alamatWali']?.toString(), textColor, subTextColor),
                          ],
                          textColor,
                          borderColor,
                          cardBgColor,
                        ),

                        const SizedBox(height: 24),

                        // ── Reset Password Button ────────────────────────────────
                        Container(
                          width: double.infinity,
                          height: 54,
                          decoration: BoxDecoration(
                            color: cardBgColor,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: borderColor),
                          ),
                          child: TextButton.icon(
                            style: TextButton.styleFrom(
                              foregroundColor: textColor,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            icon: Icon(Icons.lock_reset_rounded, color: textColor),
                            label: Text(
                              'Reset Password Akun',
                              style: TextStyle(
                                color: textColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            onPressed: () => _handleResetPassword(context, student['email'] as String?, isRegistered),
                          ),
                        ),
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
}
