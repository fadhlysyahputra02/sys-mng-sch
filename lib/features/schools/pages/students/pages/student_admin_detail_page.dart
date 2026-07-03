import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

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

  void _showEditDialog() {
    final formKey = GlobalKey<FormState>();
    final namaController = TextEditingController(text: student['nama']);
    final nisController = TextEditingController(text: student['nis']);
    final alamatController = TextEditingController(text: student['alamat']);
    final tanggalLahirController = TextEditingController(text: student['tanggalLahir'] ?? '');
    final angkatanController = TextEditingController(text: student['angkatan'] ?? '');
    String? selectedGender = (student['gender'] == 'Laki-laki' || student['gender'] == 'Perempuan') ? student['gender'] : null;
    final isDark = AuthBackground.isDarkMode.value;
    final textColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
    final borderColor = isDark ? Colors.white.withValues(alpha: 0.10) : Colors.black.withValues(alpha: 0.08);
    final dialogBg = isDark ? const Color(0xFF0F0C20) : Colors.white;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            bool isLoading = false;

            return AlertDialog(
              backgroundColor: dialogBg,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: BorderSide(color: borderColor, width: 1.5),
              ),
              contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
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
                      Text(
                        'Edit Data Murid',
                        style: TextStyle(fontWeight: FontWeight.bold, color: textColor, fontSize: 18),
                      ),
                      const SizedBox(height: 20),
                      _buildDialogField(
                        controller: namaController,
                        label: 'Nama Murid',
                        icon: Icons.person_outline_rounded,
                        capitalization: TextCapitalization.words,
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Nama wajib diisi' : null,
                      ),
                      const SizedBox(height: 12),
                      _buildDialogField(
                        controller: nisController,
                        label: 'NIS',
                        icon: Icons.badge_outlined,
                        keyboardType: TextInputType.number,
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'NIS wajib diisi' : null,
                      ),
                      const SizedBox(height: 12),
                      Container(
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: borderColor),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        child: DropdownButtonFormField<String>(
                          value: selectedGender,
                          decoration: InputDecoration(
                            labelText: 'Jenis Kelamin',
                            labelStyle: TextStyle(color: isDark ? Colors.white.withValues(alpha: 0.55) : const Color(0xFF1E1B4B).withValues(alpha: 0.65)),
                            prefixIcon: Icon(Icons.wc_rounded, color: isDark ? Colors.white.withValues(alpha: 0.55) : const Color(0xFF1E1B4B).withValues(alpha: 0.65), size: 20),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                          dropdownColor: dialogBg,
                          style: TextStyle(color: textColor, fontSize: 15),
                          items: ['Laki-laki', 'Perempuan'].map((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(value),
                            );
                          }).toList(),
                          onChanged: (newValue) {
                            setStateDialog(() {
                              selectedGender = newValue;
                            });
                          },
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildDialogField(
                        controller: alamatController,
                        label: 'Alamat',
                        icon: Icons.home_outlined,
                        capitalization: TextCapitalization.sentences,
                      ),
                      const SizedBox(height: 12),
                      GestureDetector(
                        onTap: () async {
                          final pickedDate = await showDatePicker(
                            context: context,
                            initialDate: DateTime(2010),
                            firstDate: DateTime(1990),
                            lastDate: DateTime.now(),
                            builder: (context, child) {
                              return Theme(
                                data: Theme.of(context).copyWith(
                                  colorScheme: ColorScheme.fromSeed(
                                    seedColor: const Color(0xFF0EA5E9),
                                    brightness: isDark ? Brightness.dark : Brightness.light,
                                  ),
                                ),
                                child: child!,
                              );
                            },
                          );
                          if (pickedDate != null) {
                            tanggalLahirController.text = "${pickedDate.day.toString().padLeft(2, '0')}-${pickedDate.month.toString().padLeft(2, '0')}-${pickedDate.year}";
                          }
                        },
                        child: AbsorbPointer(
                          child: _buildDialogField(
                            controller: tanggalLahirController,
                            label: 'Tanggal Lahir',
                            icon: Icons.calendar_month_rounded,
                            validator: (v) => (v == null || v.trim().isEmpty) ? 'Tanggal lahir wajib diisi' : null,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildDialogField(
                        controller: angkatanController,
                        label: 'Angkatan Masuk (Tahun)',
                        icon: Icons.calendar_today_rounded,
                        keyboardType: TextInputType.number,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Angkatan wajib diisi';
                          if (int.tryParse(v.trim()) == null) return 'Angkatan harus berupa tahun (angka)';
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
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
                      child: StatefulBuilder(
                        builder: (context, setSaveState) {
                          return ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0EA5E9),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: isLoading ? null : () async {
                              if (!formKey.currentState!.validate()) return;

                              final newNama = namaController.text.trim();
                              final newNis = nisController.text.trim();
                              final newAlamat = alamatController.text.trim();
                              final newGender = selectedGender ?? '';
                              final newTanggalLahir = tanggalLahirController.text.trim();
                              final newAngkatan = angkatanController.text.trim();

                              setSaveState(() => isLoading = true);
                              try {
                                await _studentService.updateStudent(
                                  studentId: student['studentId'],
                                  nama: newNama,
                                  nis: newNis,
                                  gender: newGender,
                                  alamat: newAlamat,
                                  tanggalLahir: newTanggalLahir,
                                  angkatan: newAngkatan,
                                );

                                setState(() {
                                  student['nama'] = newNama;
                                  student['nis'] = newNis;
                                  student['gender'] = newGender;
                                  student['alamat'] = newAlamat;
                                  student['tanggalLahir'] = newTanggalLahir;
                                  student['angkatan'] = newAngkatan;
                                });

                                if (ctx.mounted) {
                                  Navigator.pop(ctx);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Data murid berhasil diperbarui')),
                                  );
                                }
                              } catch (e) {
                                setSaveState(() => isLoading = false);
                                if (ctx.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(e.toString().replaceAll('Exception: ', '')),
                                      backgroundColor: const Color(0xFFEF4444),
                                    ),
                                  );
                                }
                              }
                            },
                            child: isLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                  )
                                : const Text('Simpan', style: TextStyle(fontWeight: FontWeight.bold)),
                          );
                        },
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
    String? Function(String?)? validator,
  }) {
    final isDark = AuthBackground.isDarkMode.value;
    final textColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
    final subTextColor = isDark ? Colors.white.withValues(alpha: 0.55) : const Color(0xFF1E1B4B).withValues(alpha: 0.65);
    final cardBgColor = isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04);
    final borderColor = isDark ? Colors.white.withValues(alpha: 0.10) : Colors.black.withValues(alpha: 0.08);

    return Container(
      decoration: BoxDecoration(
        color: cardBgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: TextFormField(
        controller: controller,
        style: TextStyle(color: textColor),
        textCapitalization: capitalization,
        keyboardType: keyboardType,
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: subTextColor),
          prefixIcon: Icon(icon, color: subTextColor, size: 20),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          errorStyle: const TextStyle(fontSize: 11),
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

    return ValueListenableBuilder<bool>(
      valueListenable: AuthBackground.isDarkMode,
      builder: (context, isDark, _) {
        final textColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
        final subTextColor = isDark ? Colors.white.withValues(alpha: 0.55) : const Color(0xFF1E1B4B).withValues(alpha: 0.65);
        final cardBgColor = isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04);
        final borderColor = isDark ? Colors.white.withValues(alpha: 0.10) : Colors.black.withValues(alpha: 0.08);
        final dividerColor = isDark ? Colors.white.withValues(alpha: 0.07) : Colors.black.withValues(alpha: 0.05);

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
                            Text(
                              'Informasi Akademik',
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

                        // ── Info Cards ───────────────────────────────────────────
                        Container(
                          decoration: BoxDecoration(
                            color: cardBgColor,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: borderColor),
                            boxShadow: isDark
                                ? [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.15),
                                      blurRadius: 14,
                                      offset: const Offset(0, 5),
                                    ),
                                  ]
                                : [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.04),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
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
                                valueColor: hasClass ? textColor : subTextColor.withValues(alpha: 0.5),
                                textColor: textColor,
                                subTextColor: subTextColor,
                                showDivider: true,
                                dividerColor: dividerColor,
                              ),
                              // Jenis Kelamin
                              _infoTile(
                                icon: Icons.wc_rounded,
                                iconColor: const Color(0xFF8B5CF6),
                                label: 'Jenis Kelamin',
                                value: (student['gender'] ?? '').toString().isEmpty ? '-' : student['gender'],
                                valueColor: textColor,
                                textColor: textColor,
                                subTextColor: subTextColor,
                                showDivider: true,
                                dividerColor: dividerColor,
                              ),
                              // Alamat
                              _infoTile(
                                icon: Icons.home_outlined,
                                iconColor: const Color(0xFFF59E0B),
                                label: 'Alamat',
                                value: (student['alamat'] ?? '').toString().isEmpty ? '-' : student['alamat'],
                                valueColor: textColor,
                                textColor: textColor,
                                subTextColor: subTextColor,
                                showDivider: true,
                                dividerColor: dividerColor,
                              ),
                              // Tanggal Lahir
                              _infoTile(
                                icon: Icons.calendar_month_rounded,
                                iconColor: const Color(0xFFEC4899),
                                label: 'Tanggal Lahir',
                                value: (student['tanggalLahir'] ?? '').toString().isEmpty ? '-' : student['tanggalLahir'],
                                valueColor: textColor,
                                textColor: textColor,
                                subTextColor: subTextColor,
                                showDivider: true,
                                dividerColor: dividerColor,
                              ),
                              // Angkatan
                              _infoTile(
                                icon: Icons.calendar_today_rounded,
                                iconColor: const Color(0xFF10B981),
                                label: 'Angkatan',
                                value: (student['angkatan'] ?? '').toString().isEmpty ? '-' : student['angkatan'],
                                valueColor: textColor,
                                textColor: textColor,
                                subTextColor: subTextColor,
                                showDivider: true,
                                dividerColor: dividerColor,
                              ),
                              // Email
                              _infoTile(
                                icon: Icons.email_outlined,
                                iconColor: const Color(0xFF0EA5E9),
                                label: 'Email',
                                value: (student['email'] ?? '').toString().isEmpty ? '-' : student['email'],
                                valueColor: textColor,
                                textColor: textColor,
                                subTextColor: subTextColor,
                                showDivider: true,
                                dividerColor: dividerColor,
                              ),
                              // Status Keaktifan
                              _infoTile(
                                icon: student['lulus'] == true
                                    ? Icons.school_rounded
                                    : (isAktif ? Icons.check_circle_outline_rounded : Icons.cancel_outlined),
                                iconColor: student['lulus'] == true
                                    ? const Color(0xFF6366F1)
                                    : (isAktif ? const Color(0xFF10B981) : const Color(0xFFEF4444)),
                                label: 'Status Keaktifan',
                                value: student['lulus'] == true
                                    ? 'Alumni (Lulus)'
                                    : (isAktif ? 'Aktif' : 'Tidak Aktif'),
                                valueColor: student['lulus'] == true
                                    ? const Color(0xFF6366F1)
                                    : (isAktif ? const Color(0xFF10B981) : const Color(0xFFEF4444)),
                                textColor: textColor,
                                subTextColor: subTextColor,
                                showDivider: false,
                                dividerColor: dividerColor,
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

  Widget _infoTile({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    required Color textColor,
    required Color subTextColor,
    Color? valueColor,
    required bool showDivider,
    required Color dividerColor,
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
                        color: subTextColor,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      value,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: valueColor ?? textColor,
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
            color: dividerColor,
          ),
      ],
    );
  }
}
