import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../../../authentication/widgets/auth_background.dart';
import 'package:sys_mng_school/core/localization/app_localization.dart';

class AddTeacherPage extends StatefulWidget {
  final String schoolId;

  const AddTeacherPage({super.key, required this.schoolId});

  @override
  State<AddTeacherPage> createState() => _AddTeacherPageState();
}

class _AddTeacherPageState extends State<AddTeacherPage> {
  final _formKey = GlobalKey<FormState>();

  final namaController = TextEditingController();
  final nipController = TextEditingController();
  final addressController = TextEditingController();
  String? _selectedGender;

  bool isLoading = false;

  Future<void> saveTeacher() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      setState(() {
        isLoading = true;
      });

      final nip = nipController.text.trim();

      // Cek kuota guru di sekolah jika diset
      final schoolDoc = await FirebaseFirestore.instance
          .collection('schools')
          .doc(widget.schoolId)
          .get();
      if (schoolDoc.exists) {
        final schoolData = schoolDoc.data();
        final teacherQuota = schoolData?['teacherQuota'] as int?;
        if (teacherQuota != null && teacherQuota > 0) {
          final countSnap = await FirebaseFirestore.instance
              .collection('schools')
              .doc(widget.schoolId)
              .collection('teachers')
              .count()
              .get();
          final currentCount = countSnap.count ?? 0;
          if (currentCount >= teacherQuota) {
            if (mounted) {
              _showQuotaFullDialog(
                context: context,
                userType: 'Guru',
                quota: teacherQuota,
              );
            }
            return;
          }
        }
      }

      final existingTeacher = await FirebaseFirestore.instance
          .collection('schools')
          .doc(widget.schoolId)
          .collection('teachers')
          .where('nip', isEqualTo: nip)
          .get();

      if (existingTeacher.docs.isNotEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                AppLocalization.isIndonesian
                    ? 'Gagal menambah guru: NIP sudah terdaftar!'
                    : 'Failed to add teacher: NIP is already registered!',
              ),
            ),
          );
        }
        return;
      }

      final doc = FirebaseFirestore.instance
          .collection('schools')
          .doc(widget.schoolId)
          .collection('teachers')
          .doc();

      await doc.set({
        'teacherId': doc.id,
        'schoolId': widget.schoolId,
        'uid': '',
        'email': '',
        'nip': nip,
        'nama': namaController.text.trim(),
        'gender': _selectedGender ?? '',
        'alamat': addressController.text.trim(),
        'aktif': true,
        'sudahRegister': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      Navigator.pop(context);
    } catch (e) {
      debugPrint(e.toString());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalization.isIndonesian
                  ? 'Terjadi kesalahan: $e'
                  : 'An error occurred: $e',
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    namaController.dispose();
    nipController.dispose();
    addressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: Icon(Icons.arrow_back_ios_new_rounded, color: textColor, size: 20),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            AppLocalization.isIndonesian ? 'Tambah Guru' : 'Add Teacher',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 8),

                          // Header card
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: cardBgColor,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: borderColor),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: const Icon(Icons.person_rounded, color: Colors.white, size: 28),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        AppLocalization.isIndonesian ? 'Registrasi Guru Baru' : 'New Teacher Registration',
                                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        AppLocalization.isIndonesian
                                            ? 'Guru terdaftar dapat login menggunakan NIP ini.'
                                            : 'Registered teachers can log in using this NIP.',
                                        style: TextStyle(fontSize: 12, color: subTextColor),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 20),

                          // Form fields
                          _buildField(
                            controller: namaController,
                            label: AppLocalization.isIndonesian ? 'Nama Lengkap' : 'Full Name',
                            icon: Icons.person_outline_rounded,
                            isDark: isDark,
                            textColor: textColor,
                            subTextColor: subTextColor,
                            cardBgColor: cardBgColor,
                            borderColor: borderColor,
                            validator: (v) => (v == null || v.isEmpty)
                                ? (AppLocalization.isIndonesian ? 'Nama wajib diisi' : 'Name is required')
                                : null,
                          ),
                          const SizedBox(height: 14),
                          _buildField(
                            controller: nipController,
                            label: AppLocalization.isIndonesian ? 'NIP (Nomor Induk Pegawai)' : 'NIP (Employee ID Number)',
                            icon: Icons.badge_outlined,
                            isDark: isDark,
                            textColor: textColor,
                            subTextColor: subTextColor,
                            cardBgColor: cardBgColor,
                            borderColor: borderColor,
                            validator: (v) => (v == null || v.isEmpty)
                                ? (AppLocalization.isIndonesian ? 'NIP wajib diisi' : 'NIP is required')
                                : null,
                          ),
                          const SizedBox(height: 14),
                          Container(
                            decoration: BoxDecoration(
                              color: cardBgColor,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: borderColor),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            child: DropdownButtonFormField<String>(
                              value: _selectedGender,
                              decoration: InputDecoration(
                                labelText: AppLocalization.isIndonesian ? 'Jenis Kelamin' : 'Gender',
                                labelStyle: TextStyle(color: subTextColor, fontSize: 14),
                                prefixIcon: const Icon(Icons.wc_rounded, color: Color(0xFF6366F1), size: 20),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              ),
                              dropdownColor: isDark ? const Color(0xFF1E1B4B) : Colors.white,
                              style: TextStyle(color: textColor, fontSize: 15),
                              items: [
                                DropdownMenuItem<String>(
                                  value: 'Laki-laki',
                                  child: Text(AppLocalization.isIndonesian ? 'Laki-laki' : 'Male'),
                                ),
                                DropdownMenuItem<String>(
                                  value: 'Perempuan',
                                  child: Text(AppLocalization.isIndonesian ? 'Perempuan' : 'Female'),
                                ),
                              ],
                              onChanged: (newValue) {
                                setState(() {
                                  _selectedGender = newValue;
                                });
                              },
                              validator: (v) => (v == null || v.isEmpty)
                                  ? (AppLocalization.isIndonesian ? 'Pilih jenis kelamin' : 'Select gender')
                                  : null,
                            ),
                          ),
                          const SizedBox(height: 14),
                          _buildField(
                            controller: addressController,
                            label: AppLocalization.isIndonesian ? 'Alamat' : 'Address',
                            icon: Icons.home_outlined,
                            isDark: isDark,
                            textColor: textColor,
                            subTextColor: subTextColor,
                            cardBgColor: cardBgColor,
                            borderColor: borderColor,
                            maxLines: 3,
                          ),

                          const SizedBox(height: 32),

                          // Submit button
                          Container(
                            height: 54,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF6366F1).withValues(alpha: 0.3),
                                  blurRadius: 12,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                              onPressed: isLoading ? null : saveTeacher,
                              child: isLoading
                                  ? const SizedBox(
                                      height: 24,
                                      width: 24,
                                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                                    )
                                  : Text(
                                      AppLocalization.isIndonesian ? 'Simpan Data' : 'Save Data',
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                                    ),
                            ),
                          ),
                        ],
                      ),
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

  void _showQuotaFullDialog({
    required BuildContext context,
    required String userType,
    required int quota,
  }) {
    showDialog(
      context: context,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final textColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
        final subTextColor = isDark
            ? Colors.white70
            : const Color(0xFF1E1B4B).withOpacity(0.65);
        final translatedUserType = AppLocalization.isIndonesian
            ? userType
            : (userType == 'Guru' ? 'Teacher' : userType);

        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          backgroundColor: isDark ? const Color(0xFF151026) : Colors.white,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icon badge
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.lock_outline_rounded,
                    color: Color(0xFFEF4444),
                    size: 44,
                  ),
                ),
                const SizedBox(height: 20),

                // Title
                Text(
                  AppLocalization.isIndonesian
                      ? 'Batas Kuota $translatedUserType Tercapai'
                      : '$translatedUserType Quota Limit Reached',
                  style: TextStyle(
                    color: textColor,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),

                // Quota badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: const Color(0xFFEF4444).withOpacity(0.3),
                    ),
                  ),
                  child: Text(
                    AppLocalization.isIndonesian
                        ? 'Kapasitas: $quota $translatedUserType'
                        : 'Capacity: $quota $translatedUserType',
                    style: const TextStyle(
                      color: Color(0xFFEF4444),
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Description
                Text(
                  AppLocalization.isIndonesian
                      ? 'Sekolah Anda telah mencapai batas maksimal pengguna $translatedUserType yang ditetapkan oleh Super Admin. Pendaftaran $translatedUserType baru tidak dapat dilakukan saat ini.'
                      : 'Your school has reached the maximum user limit for $translatedUserType set by the Super Admin. New $translatedUserType registration cannot be completed at this time.',
                  style: TextStyle(
                    color: subTextColor,
                    fontSize: 13,
                    height: 1.6,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),

                // Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEF4444).withOpacity(0.1),
                      foregroundColor: const Color(0xFFEF4444),
                      shadowColor: Colors.transparent,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(
                          color: const Color(0xFFEF4444).withOpacity(0.3),
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      AppLocalization.isIndonesian ? 'Mengerti' : 'Understood',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
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

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required bool isDark,
    required Color textColor,
    required Color subTextColor,
    required Color cardBgColor,
    required Color borderColor,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: cardBgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: TextFormField(
        controller: controller,
        validator: validator,
        maxLines: maxLines,
        style: TextStyle(color: textColor, fontSize: 15),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: subTextColor, fontSize: 14),
          prefixIcon: Icon(icon, color: const Color(0xFF6366F1), size: 20),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: maxLines > 1 ? 12 : 16),
        ),
      ),
    );
  }
}
