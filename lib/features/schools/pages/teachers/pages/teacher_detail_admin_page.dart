import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../../authentication/widgets/auth_background.dart';
import '../../../../teachers/pages/teacher_daily_attendance_page.dart';
import 'teacher_subject_admin_page.dart';

class TeacherDetailPage extends StatefulWidget {
  final Map<String, dynamic> teacher;

  const TeacherDetailPage({super.key, required this.teacher});

  @override
  State<TeacherDetailPage> createState() => _TeacherDetailPageState();
}

class _TeacherDetailPageState extends State<TeacherDetailPage> {
  late Map<String, dynamic> teacher;

  @override
  void initState() {
    super.initState();
    teacher = Map<String, dynamic>.from(widget.teacher);
  }

  void _showEditDialog() {
    final nameController = TextEditingController(text: teacher['nama']);
    final nipController = TextEditingController(text: teacher['nip'] ?? '');
    final isDark = AuthBackground.isDarkMode.value;
    final textColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
    final subTextColor = isDark ? Colors.white.withValues(alpha: 0.55) : const Color(0xFF1E1B4B).withValues(alpha: 0.65);
    final cardBgColor = isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04);
    final borderColor = isDark ? Colors.white.withValues(alpha: 0.10) : Colors.black.withValues(alpha: 0.08);
    final dialogBg = isDark ? const Color(0xFF0F0C20) : Colors.white;

    showDialog(
      context: context,
      builder: (ctx) {
        String? errorMessage;
        bool isLoading = false;

        return StatefulBuilder(
          builder: (context, setModalState) {
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
                        colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.edit_rounded, color: Colors.white, size: 26),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Edit Data Guru',
                    style: TextStyle(fontWeight: FontWeight.bold, color: textColor, fontSize: 18),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    decoration: BoxDecoration(
                      color: cardBgColor,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: borderColor),
                    ),
                    child: TextField(
                      controller: nameController,
                      style: TextStyle(color: textColor),
                      textCapitalization: TextCapitalization.words,
                      enabled: !isLoading,
                      decoration: InputDecoration(
                        labelText: 'Nama Baru',
                        labelStyle: TextStyle(color: subTextColor),
                        prefixIcon: Icon(Icons.person_outline_rounded, color: subTextColor),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: cardBgColor,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: borderColor),
                    ),
                    child: TextField(
                      controller: nipController,
                      style: TextStyle(color: textColor),
                      keyboardType: TextInputType.number,
                      enabled: !isLoading,
                      decoration: InputDecoration(
                        labelText: 'NIP Baru',
                        labelStyle: TextStyle(color: subTextColor),
                        prefixIcon: Icon(Icons.badge_outlined, color: subTextColor),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                    ),
                  ),
                  if (errorMessage != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              errorMessage!,
                              style: const TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
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
                        onPressed: isLoading ? null : () => Navigator.pop(ctx),
                        child: Text('Batal', style: TextStyle(color: textColor)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6366F1),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: isLoading
                            ? null
                            : () async {
                                final newName = nameController.text.trim();
                                final newNip = nipController.text.trim();

                                setModalState(() {
                                  errorMessage = null;
                                });

                                if (newName.isEmpty) {
                                  setModalState(() {
                                    errorMessage = 'Nama tidak boleh kosong';
                                  });
                                  return;
                                }

                                if (newNip.isEmpty) {
                                  setModalState(() {
                                    errorMessage = 'NIP tidak boleh kosong';
                                  });
                                  return;
                                }

                                final messenger = ScaffoldMessenger.of(context);

                                setModalState(() {
                                  isLoading = true;
                                });

                                try {
                                  // Query as string NIP
                                  final existingString = await FirebaseFirestore.instance
                                      .collection('schools')
                                      .doc(teacher['schoolId'])
                                      .collection('teachers')
                                      .where('nip', isEqualTo: newNip)
                                      .get();

                                  // Query as integer NIP (if parseable)
                                  final parsedNipInt = int.tryParse(newNip);
                                  final existingIntDocs = parsedNipInt != null
                                      ? (await FirebaseFirestore.instance
                                          .collection('schools')
                                          .doc(teacher['schoolId'])
                                          .collection('teachers')
                                          .where('nip', isEqualTo: parsedNipInt)
                                          .get()).docs
                                      : <QueryDocumentSnapshot<Map<String, dynamic>>>[];

                                  final allMatches = [
                                    ...existingString.docs,
                                    ...existingIntDocs,
                                  ];

                                  // Filter out current teacher using teacherId
                                  final otherMatches = allMatches.where((doc) {
                                    final data = doc.data();
                                    return data['teacherId'] != teacher['teacherId'];
                                  }).toList();

                                  if (otherMatches.isNotEmpty) {
                                    final existingName = otherMatches.first.data()['nama'] ?? 'Guru Lain';
                                    setModalState(() {
                                      errorMessage = 'NIP sudah terdaftar atas nama "$existingName"';
                                      isLoading = false;
                                    });
                                    return;
                                  }

                                  await FirebaseFirestore.instance
                                      .collection('schools')
                                      .doc(teacher['schoolId'])
                                      .collection('teachers')
                                      .doc(teacher['teacherId'])
                                      .update({
                                    'nama': newName,
                                    'nip': newNip,
                                  });

                                  setState(() {
                                    teacher['nama'] = newName;
                                    teacher['nip'] = newNip;
                                  });

                                  if (context.mounted) {
                                    Navigator.pop(ctx);
                                    messenger.showSnackBar(
                                      const SnackBar(content: Text('Data guru berhasil diubah')),
                                    );
                                  }
                                } catch (e) {
                                  setModalState(() {
                                    errorMessage = 'Gagal menyimpan data: $e';
                                    isLoading = false;
                                  });
                                }
                              },
                        child: isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Simpan', style: TextStyle(fontWeight: FontWeight.bold)),
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

  void _showDeleteDialog() {
    final isDark = AuthBackground.isDarkMode.value;
    final textColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
    final subTextColor = isDark ? Colors.white.withValues(alpha: 0.55) : const Color(0xFF1E1B4B).withValues(alpha: 0.65);
    final borderColor = isDark ? Colors.white.withValues(alpha: 0.10) : Colors.black.withValues(alpha: 0.08);
    final dialogBg = isDark ? const Color(0xFF0F0C20) : Colors.white;

    showDialog(
      context: context,
      builder: (ctx) {
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
                'Hapus Guru',
                style: TextStyle(fontWeight: FontWeight.bold, color: textColor, fontSize: 18),
              ),
              const SizedBox(height: 12),
              Text(
                'Apakah Anda yakin ingin menghapus ${teacher['nama']}? Data ini tidak dapat dikembalikan.',
                textAlign: TextAlign.center,
                style: TextStyle(color: subTextColor, fontSize: 13, height: 1.5),
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
                      // Hapus data guru
                      await FirebaseFirestore.instance
                          .collection('schools')
                          .doc(teacher['schoolId'])
                          .collection('teachers')
                          .doc(teacher['teacherId'])
                          .delete();

                      // Hapus juga relasi mata pelajaran guru ini
                      final subjectsSnapshot = await FirebaseFirestore.instance
                          .collection('schools')
                          .doc(teacher['schoolId'])
                          .collection('teacher_subjects')
                          .where('teacherId', isEqualTo: teacher['teacherId'])
                          .get();

                      for (var doc in subjectsSnapshot.docs) {
                        await doc.reference.delete();
                      }

                      if (ctx.mounted) {
                        Navigator.pop(ctx); // Tutup dialog
                        Navigator.pop(context); // Kembali ke halaman sebelumnya
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Guru berhasil dihapus')),
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
    final isDark = AuthBackground.isDarkMode.value;
    final textColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
    final subTextColor = isDark ? Colors.white.withValues(alpha: 0.55) : const Color(0xFF1E1B4B).withValues(alpha: 0.65);
    final cardBgColor = isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04);
    final borderColor = isDark ? Colors.white.withValues(alpha: 0.10) : Colors.black.withValues(alpha: 0.08);
    final dialogBg = isDark ? const Color(0xFF0F0C20) : Colors.white;

    if (email == null || email.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Guru ini tidak memiliki alamat email yang valid.'),
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
              child: const Text('OK', style: TextStyle(color: Color(0xFF6366F1), fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
      return;
    }

    final String? uid = teacher['uid'];
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
                    colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.lock_reset_rounded, color: Colors.white, size: 26),
              ),
              const SizedBox(height: 16),
              Text(
                'Reset Password Guru',
                style: TextStyle(fontWeight: FontWeight.bold, color: textColor, fontSize: 18),
              ),
              const SizedBox(height: 12),
              Text(
                'Masukkan password baru untuk guru ${teacher['nama']}. Guru dapat langsung login menggunakan password baru ini.',
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
                      backgroundColor: const Color(0xFF6366F1),
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

  @override
  Widget build(BuildContext context) {
    final bool isRegistered = teacher['sudahRegister'] ?? false;
    final String nama = teacher['nama'] ?? '-';
    final String inisial = nama.isNotEmpty ? nama[0].toUpperCase() : '?';

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
                            'Detail Guru',
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
                            tooltip: 'Edit Guru',
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
                            tooltip: 'Hapus Guru',
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
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Profile Card ─────────────────────────────────────
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF6366F1).withValues(alpha: 0.35),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Row(
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
                                          'NIP: ${teacher['nip'] ?? '-'}',
                                          style: TextStyle(
                                            color: Colors.white.withValues(alpha: 0.8),
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    // Status badge
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
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 28),

                        // ── Section header ───────────────────────────────────
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                              ),
                              child: const Icon(Icons.menu_book_rounded, color: Color(0xFF10B981), size: 18),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Mata Pelajaran Diampu',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: textColor,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 14),

                        // ── Subject list ─────────────────────────────────────
                        Expanded(
                          child: StreamBuilder<QuerySnapshot>(
                            stream: FirebaseFirestore.instance
                                .collection('schools')
                                .doc(teacher['schoolId'])
                                .collection('teacher_subjects')
                                .where('teacherId', isEqualTo: teacher['teacherId'])
                                .snapshots(),
                            builder: (context, snapshot) {
                              if (!snapshot.hasData) {
                                return const Center(
                                  child: CircularProgressIndicator(
                                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
                                  ),
                                );
                              }

                              final docs = snapshot.data!.docs;

                              if (docs.isEmpty) {
                                return Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(24),
                                        decoration: BoxDecoration(
                                          color: cardBgColor,
                                          shape: BoxShape.circle,
                                          border: Border.all(color: borderColor),
                                        ),
                                        child: Icon(Icons.menu_book_outlined, size: 48, color: subTextColor),
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        'Belum mengampu mata pelajaran',
                                        style: TextStyle(
                                          color: subTextColor,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        'Tap "Atur Mata Pelajaran" untuk menambahkan',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: subTextColor.withValues(alpha: 0.5),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }

                              return ListView.builder(
                                itemCount: docs.length,
                                itemBuilder: (context, index) {
                                  final mapel = docs[index].data() as Map<String, dynamic>;

                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 10),
                                    decoration: BoxDecoration(
                                      color: cardBgColor,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: borderColor),
                                      boxShadow: isDark
                                          ? [
                                              BoxShadow(
                                                color: Colors.black.withValues(alpha: 0.10),
                                                blurRadius: 8,
                                                offset: const Offset(0, 3),
                                              ),
                                            ]
                                          : [
                                              BoxShadow(
                                                color: Colors.black.withValues(alpha: 0.03),
                                                blurRadius: 6,
                                                offset: const Offset(0, 2),
                                              ),
                                            ],
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 40,
                                            height: 40,
                                            decoration: BoxDecoration(
                                              gradient: const LinearGradient(
                                                colors: [Color(0xFF10B981), Color(0xFF34D399)],
                                                begin: Alignment.topLeft,
                                                end: Alignment.bottomRight,
                                              ),
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: const Icon(Icons.book_rounded, color: Colors.white, size: 20),
                                          ),
                                          const SizedBox(width: 14),
                                          Expanded(
                                            child: Text(
                                              mapel['subjectName'] ?? '-',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w600,
                                                color: textColor,
                                                fontSize: 14,
                                              ),
                                            ),
                                          ),
                                          Icon(
                                            Icons.chevron_right_rounded,
                                            color: subTextColor.withValues(alpha: 0.5),
                                            size: 20,
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                        ),

                        const SizedBox(height: 16),

                        // ── Action Button ────────────────────────────────────
                        Container(
                          width: double.infinity,
                          height: 54,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF6366F1).withValues(alpha: 0.35),
                                blurRadius: 14,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            icon: const Icon(Icons.settings_outlined, color: Colors.white, size: 20),
                            label: const Text(
                              'Atur Mata Pelajaran',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => TeacherSubjectPage(
                                    teacherId: teacher['teacherId'],
                                    teacherName: teacher['nama'],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),

                        const SizedBox(height: 12),

                        // ── Lihat Riwayat Absensi Button ──────────────────────────
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
                            icon: Icon(Icons.co_present_rounded, color: textColor),
                            label: Text(
                              'Lihat Riwayat Absensi',
                              style: TextStyle(
                                color: textColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => TeacherDailyAttendancePage(
                                    teacherId: teacher['teacherId'] ?? '',
                                    teacherName: teacher['nama'] ?? '',
                                    nip: teacher['nip'] ?? '',
                                  ),
                                ),
                              );
                            },
                          ),
                        ),

                        const SizedBox(height: 12),

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
                            onPressed: () => _handleResetPassword(context, teacher['email'] as String?, isRegistered),
                          ),
                        ),

                        const SizedBox(height: 20),
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
