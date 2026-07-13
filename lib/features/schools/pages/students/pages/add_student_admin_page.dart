import 'package:flutter/material.dart';
import '../../../../authentication/widgets/auth_background.dart';
import '../data/student_admin_service.dart';
import 'package:sys_mng_school/core/localization/app_localization.dart';

class AddStudentPage extends StatefulWidget {
  final String schoolId;

  const AddStudentPage({super.key, required this.schoolId});

  @override
  State<AddStudentPage> createState() => _AddStudentPageState();
}

class _AddStudentPageState extends State<AddStudentPage> {
  final _formKey = GlobalKey<FormState>();

  final namaController = TextEditingController();
  final nisController = TextEditingController();
  final addressController = TextEditingController();
  final tanggalLahirController = TextEditingController();
  final angkatanController = TextEditingController();
  String? _selectedGender;

  bool isLoading = false;

  Future<void> saveStudent() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      setState(() {
        isLoading = true;
      });

      await StudentService().createStudent(
        schoolId: widget.schoolId,
        nis: nisController.text.trim(),
        nama: namaController.text.trim(),
        gender: _selectedGender ?? '',
        alamat: addressController.text.trim(),
        tanggalLahir: tanggalLahirController.text.trim(),
        angkatan: angkatanController.text.trim(),
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalization.isIndonesian ? 'Murid berhasil ditambahkan' : 'Student successfully added')),
      );

      Navigator.pop(context);
    } catch (e) {
      debugPrint(e.toString());

      if (mounted) {
        final errorMsg = e.toString().replaceAll('Exception: ', '').replaceAll('Exception ', '');
        if (errorMsg.contains('Kuota murid')) {
          final match = RegExp(r'\((\d+)\)').firstMatch(errorMsg);
          final quotaVal = match != null ? int.tryParse(match.group(1) ?? '0') ?? 0 : 0;
          _showQuotaFullDialog(context: context, userType: 'Murid', quota: quotaVal);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMsg)));
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
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
            : (userType == 'Murid' ? 'Student' : userType);

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

                // Quota capacity pill
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
                        ? 'Kapasitas: $quota $translatedUserType Aktif'
                        : 'Capacity: $quota Active $translatedUserType',
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

  @override
  void dispose() {
    namaController.dispose();
    nisController.dispose();
    addressController.dispose();
    tanggalLahirController.dispose();
    angkatanController.dispose();
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
                            AppLocalization.isIndonesian ? 'Tambah Murid' : 'Add Student',
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
                                      colors: [Color(0xFF0EA5E9), Color(0xFF38BDF8)],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: const Icon(Icons.groups_rounded, color: Colors.white, size: 28),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        AppLocalization.isIndonesian ? 'Registrasi Murid Baru' : 'New Student Registration',
                                        style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 16),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        AppLocalization.isIndonesian ? 'Masukkan detail identitas siswa di bawah ini.' : 'Enter student identity details below.',
                                        style: TextStyle(color: subTextColor, fontSize: 11),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),

                          _buildField(
                            controller: namaController,
                            label: AppLocalization.isIndonesian ? 'Nama Lengkap' : 'Full Name',
                            icon: Icons.person_rounded,
                            isDark: isDark,
                            textColor: textColor,
                            subTextColor: subTextColor,
                            cardBgColor: cardBgColor,
                            borderColor: borderColor,
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) {
                                return AppLocalization.isIndonesian ? 'Nama tidak boleh kosong' : 'Name cannot be empty';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          _buildField(
                            controller: nisController,
                            label: AppLocalization.isIndonesian ? 'Nomor Induk Siswa (NIS)' : 'Student ID Number (NIS)',
                            icon: Icons.badge_rounded,
                            keyboardType: TextInputType.number,
                            isDark: isDark,
                            textColor: textColor,
                            subTextColor: subTextColor,
                            cardBgColor: cardBgColor,
                            borderColor: borderColor,
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) {
                                return AppLocalization.isIndonesian ? 'NIS tidak boleh kosong' : 'NIS cannot be empty';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // Dropdown gender
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            decoration: BoxDecoration(
                              color: cardBgColor,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: borderColor),
                            ),
                            child: DropdownButtonFormField<String>(
                              value: _selectedGender,
                              style: TextStyle(color: textColor, fontSize: 15),
                              dropdownColor: isDark ? const Color(0xFF151026) : Colors.white,
                              decoration: InputDecoration(
                                labelText: AppLocalization.isIndonesian ? 'Jenis Kelamin' : 'Gender',
                                labelStyle: TextStyle(color: subTextColor, fontSize: 14),
                                prefixIcon: const Icon(Icons.wc_rounded, color: Color(0xFF0EA5E9), size: 20),
                                border: InputBorder.none,
                              ),
                              items: [
                                DropdownMenuItem(
                                  value: 'Laki-laki',
                                  child: Text(AppLocalization.isIndonesian ? 'Laki-laki' : 'Male', style: TextStyle(color: textColor)),
                                ),
                                DropdownMenuItem(
                                  value: 'Perempuan',
                                  child: Text(AppLocalization.isIndonesian ? 'Perempuan' : 'Female', style: TextStyle(color: textColor)),
                                ),
                              ],
                              onChanged: (val) {
                                setState(() {
                                  _selectedGender = val;
                                });
                              },
                              validator: (val) => val == null ? (AppLocalization.isIndonesian ? 'Pilih jenis kelamin' : 'Select gender') : null,
                            ),
                          ),
                          const SizedBox(height: 16),

                          _buildField(
                            controller: tanggalLahirController,
                            label: AppLocalization.isIndonesian ? 'Tanggal Lahir (DD-MM-YYYY)' : 'Date of Birth (DD-MM-YYYY)',
                            icon: Icons.calendar_today_rounded,
                            isDark: isDark,
                            textColor: textColor,
                            subTextColor: subTextColor,
                            cardBgColor: cardBgColor,
                            borderColor: borderColor,
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) {
                                return AppLocalization.isIndonesian ? 'Tanggal lahir tidak boleh kosong' : 'Date of birth cannot be empty';
                              }
                              // Simple date regex check (DD-MM-YYYY)
                              final reg = RegExp(r'^\d{2}-\d{2}-\d{4}$');
                              if (!reg.hasMatch(val.trim())) {
                                return AppLocalization.isIndonesian ? 'Format harus DD-MM-YYYY (contoh: 15-08-2008)' : 'Format must be DD-MM-YYYY (e.g. 15-08-2008)';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          _buildField(
                            controller: angkatanController,
                            label: AppLocalization.isIndonesian ? 'Tahun Angkatan' : 'Batch Year',
                            icon: Icons.school_rounded,
                            keyboardType: TextInputType.number,
                            isDark: isDark,
                            textColor: textColor,
                            subTextColor: subTextColor,
                            cardBgColor: cardBgColor,
                            borderColor: borderColor,
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) {
                                return AppLocalization.isIndonesian ? 'Tahun angkatan tidak boleh kosong' : 'Batch year cannot be empty';
                              }
                              final year = int.tryParse(val.trim());
                              if (year == null || year < 1900 || year > 2100) {
                                return AppLocalization.isIndonesian ? 'Tahun angkatan tidak valid' : 'Invalid batch year';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          _buildField(
                            controller: addressController,
                            label: AppLocalization.isIndonesian ? 'Alamat Rumah' : 'Home Address',
                            icon: Icons.home_rounded,
                            maxLines: 3,
                            isDark: isDark,
                            textColor: textColor,
                            subTextColor: subTextColor,
                            cardBgColor: cardBgColor,
                            borderColor: borderColor,
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) {
                                return AppLocalization.isIndonesian ? 'Alamat tidak boleh kosong' : 'Address cannot be empty';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 32),

                          // Button
                          Container(
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF0EA5E9), Color(0xFF6366F1)],
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF0EA5E9).withValues(alpha: 0.3),
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
                              onPressed: isLoading ? null : saveStudent,
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

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
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
        keyboardType: keyboardType,
        validator: validator,
        maxLines: maxLines,
        style: TextStyle(color: textColor, fontSize: 15),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: subTextColor, fontSize: 14),
          prefixIcon: Icon(icon, color: const Color(0xFF0EA5E9), size: 20),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: maxLines > 1 ? 12 : 16),
        ),
      ),
    );
  }
}
