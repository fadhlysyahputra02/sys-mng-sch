import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../../authentication/widgets/auth_background.dart';
import '../data/student_admin_service.dart';

class StudentDetailPage extends StatefulWidget {
  final Map<String, dynamic> student;

  const StudentDetailPage({super.key, required this.student});

  @override
  State<StudentDetailPage> createState() => _StudentDetailPageState();
}

class _StudentDetailPageState extends State<StudentDetailPage> {
  late Map<String, dynamic> student;
  final _studentService = StudentService();

  @override
  void initState() {
    super.initState();
    student = Map<String, dynamic>.from(widget.student);
  }

  void _showEditDialog() {
    final namaController = TextEditingController(text: student['nama']);
    final nisController = TextEditingController(text: student['nis']);

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF0F0C20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.1), width: 1.5),
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
                    colors: [Color(0xFF0EA5E9), Color(0xFF38BDF8)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.edit_rounded, color: Colors.white, size: 26),
              ),
              const SizedBox(height: 16),
              const Text(
                'Edit Data Murid',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 18),
              ),
              const SizedBox(height: 20),
              _buildDialogField(
                controller: namaController,
                label: 'Nama Murid',
                icon: Icons.person_outline_rounded,
                capitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 12),
              _buildDialogField(
                controller: nisController,
                label: 'NIS',
                icon: Icons.badge_outlined,
                keyboardType: TextInputType.number,
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
                      side: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Batal', style: TextStyle(color: Colors.white)),
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
                    onPressed: () async {
                      final newNama = namaController.text.trim();
                      final newNis = nisController.text.trim();
                      if (newNama.isEmpty || newNis.isEmpty) return;

                      await _studentService.updateStudent(
                        studentId: student['studentId'],
                        nama: newNama,
                        nis: newNis,
                      );

                      setState(() {
                        student['nama'] = newNama;
                        student['nis'] = newNis;
                      });

                      if (ctx.mounted) {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Data murid berhasil diperbarui')),
                        );
                      }
                    },
                    child: const Text('Simpan', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  void _showDeleteDialog() {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF0F0C20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.1), width: 1.5),
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
              const Text(
                'Hapus Murid',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 18),
              ),
              const SizedBox(height: 12),
              Text(
                'Apakah Anda yakin ingin menghapus "${student['nama']}"? Data ini tidak dapat dikembalikan.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 13, height: 1.5),
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
                      side: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Batal', style: TextStyle(color: Colors.white)),
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
  }

  Future<void> _handleResetPassword(BuildContext context, String? email, bool isRegistered) async {
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
          backgroundColor: const Color(0xFF0F0C20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
          ),
          title: const Row(
            children: [
              Icon(Icons.info_outline_rounded, color: Colors.orange),
              SizedBox(width: 10),
              Text(
                'Akun Belum Terdaftar',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ],
          ),
          content: Text(
            'Akun dengan email $email belum melakukan registrasi di aplikasi. Reset password hanya dapat dilakukan untuk akun yang sudah aktif/terdaftar.',
            style: const TextStyle(color: Colors.white70, fontSize: 14),
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
        builder: (context, setState) => AlertDialog(
          backgroundColor: const Color(0xFF0F0C20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.1), width: 1.5),
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
              const Text(
                'Reset Password Murid',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 18),
              ),
              const SizedBox(height: 12),
              Text(
                'Masukkan password baru untuk murid ${student['nama']}. Murid dapat langsung login menggunakan password baru ini.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 13, height: 1.5),
              ),
              const SizedBox(height: 20),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
                ),
                child: TextField(
                  controller: newPasswordController,
                  obscureText: obscurePassword,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Password Baru',
                    labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
                    prefixIcon: Icon(Icons.lock_outline_rounded, color: Colors.white.withValues(alpha: 0.5)),
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        color: Colors.white.withValues(alpha: 0.4),
                      ),
                      onPressed: () => setState(() => obscurePassword = !obscurePassword),
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
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
                      side: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text('Batal', style: TextStyle(color: Colors.white)),
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
                    onPressed: () {
                      final pass = newPasswordController.text.trim();
                      if (pass.length < 6) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Password minimal 6 karakter.'),
                            backgroundColor: Color(0xFFEF4444),
                          ),
                        );
                        return;
                      }
                      Navigator.pop(dialogContext, pass);
                    },
                    child: const Text('Simpan', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ],
        ),
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

  Widget _buildDialogField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextCapitalization capitalization = TextCapitalization.none,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: TextField(
        controller: controller,
        style: const TextStyle(color: Colors.white),
        textCapitalization: capitalization,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
          prefixIcon: Icon(icon, color: Colors.white.withValues(alpha: 0.45), size: 20),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
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
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 4),
                    const Expanded(
                      child: Text(
                        'Detail Murid',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                    // Edit button
                    Container(
                      margin: const EdgeInsets.only(right: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.edit_outlined, color: Colors.white, size: 20),
                        tooltip: 'Edit Murid',
                        constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                        padding: EdgeInsets.zero,
                        onPressed: _showEditDialog,
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
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF0EA5E9), Color(0xFF6366F1)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF0EA5E9).withValues(alpha: 0.35),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Avatar
                          Container(
                            width: 66,
                            height: 66,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 2),
                            ),
                            child: Center(
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
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 28),

                    // ── Section Header ───────────────────────────────────────
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0EA5E9).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFF0EA5E9).withValues(alpha: 0.3)),
                          ),
                          child: const Icon(Icons.info_outline_rounded, color: Color(0xFF0EA5E9), size: 18),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'Informasi Akademik',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // ── Info Cards ───────────────────────────────────────────
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 14,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          // Kelas
                          _infoTile(
                            icon: Icons.class_outlined,
                            iconColor: const Color(0xFF6366F1),
                            label: 'Kelas',
                            value: hasClass ? className : 'Belum ditentukan',
                            valueColor: hasClass ? Colors.white : Colors.white.withValues(alpha: 0.4),
                            showDivider: true,
                          ),
                          // Email
                          _infoTile(
                            icon: Icons.email_outlined,
                            iconColor: const Color(0xFF0EA5E9),
                            label: 'Email',
                            value: (student['email'] ?? '').toString().isEmpty ? '-' : student['email'],
                            showDivider: true,
                          ),
                          // Status Keaktifan
                          _infoTile(
                            icon: isAktif ? Icons.check_circle_outline_rounded : Icons.cancel_outlined,
                            iconColor: isAktif ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                            label: 'Status Keaktifan',
                            value: isAktif ? 'Aktif' : 'Tidak Aktif',
                            valueColor: isAktif ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                            showDivider: false,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ── Reset Password Button ────────────────────────────────
                    Container(
                      width: double.infinity,
                      height: 54,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                      ),
                      child: TextButton.icon(
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        icon: const Icon(Icons.lock_reset_rounded, color: Colors.white),
                        label: const Text(
                          'Reset Password Akun',
                          style: TextStyle(
                            color: Colors.white,
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
  }

  Widget _infoTile({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    Color valueColor = Colors.white,
    required bool showDivider,
  }) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: iconColor.withValues(alpha: 0.25)),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withValues(alpha: 0.5),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      value,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: valueColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            indent: 70,
            endIndent: 16,
            color: Colors.white.withValues(alpha: 0.07),
          ),
      ],
    );
  }
}
