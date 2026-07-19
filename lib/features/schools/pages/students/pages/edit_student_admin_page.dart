import 'package:flutter/material.dart';
import '../../../../authentication/widgets/auth_background.dart';
import '../data/student_admin_service.dart';
import 'package:sys_mng_school/core/localization/app_localization.dart';

class EditStudentAdminPage extends StatefulWidget {
  final Map<String, dynamic> student;

  const EditStudentAdminPage({super.key, required this.student});

  @override
  State<EditStudentAdminPage> createState() => _EditStudentAdminPageState();
}

class _EditStudentAdminPageState extends State<EditStudentAdminPage> {
  final _formKey = GlobalKey<FormState>();

  // Data Pribadi
  late TextEditingController namaController;
  late TextEditingController nisController;
  late TextEditingController nisnController;
  late TextEditingController tempatLahirController;
  late TextEditingController addressController;
  late TextEditingController tanggalLahirController;
  late TextEditingController angkatanController;
  late TextEditingController noHpController;
  late TextEditingController tanggalDiterimaController;

  String? _selectedGender;
  String? _selectedAgama;
  String? _selectedKewarganegaraan;
  String? _selectedJalurMasuk;

  // Data Ayah
  late TextEditingController namaAyahController;
  late TextEditingController nikAyahController;
  late TextEditingController pekerjaanAyahController;
  late TextEditingController pendidikanAyahController;
  late TextEditingController noHpAyahController;

  // Data Ibu
  late TextEditingController namaIbuController;
  late TextEditingController nikIbuController;
  late TextEditingController pekerjaanIbuController;
  late TextEditingController pendidikanIbuController;
  late TextEditingController noHpIbuController;

  // Data Wali
  late TextEditingController namaWaliController;
  late TextEditingController hubunganWaliController;
  late TextEditingController noHpWaliController;
  late TextEditingController alamatWaliController;

  bool isLoading = false;

  final List<String> agamaOptions = ['Islam', 'Kristen', 'Katolik', 'Hindu', 'Buddha', 'Konghucu'];
  final List<String> kewarganegaraanOptions = ['WNI', 'WNA'];
  final List<String> jalurMasukOptions = ['Zonasi', 'Prestasi', 'Afirmasi', 'Pindah Tugas', 'Umum/Reguler'];

  @override
  void initState() {
    super.initState();
    final student = widget.student;

    namaController = TextEditingController(text: student['nama'] ?? '');
    nisController = TextEditingController(text: student['nis'] ?? '');
    nisnController = TextEditingController(text: student['nisn'] ?? '');
    tempatLahirController = TextEditingController(text: student['tempatLahir'] ?? '');
    addressController = TextEditingController(text: student['alamat'] ?? '');
    tanggalLahirController = TextEditingController(text: student['tanggalLahir'] ?? '');
    angkatanController = TextEditingController(text: student['angkatan'] ?? '');
    noHpController = TextEditingController(text: student['noHp'] ?? '');
    tanggalDiterimaController = TextEditingController(text: student['tanggalDiterima'] ?? '');

    _selectedGender = (student['gender'] == 'Laki-laki' || student['gender'] == 'Perempuan') ? student['gender'] : null;
    _selectedAgama = agamaOptions.contains(student['agama']) ? student['agama'] : null;
    _selectedKewarganegaraan = kewarganegaraanOptions.contains(student['kewarganegaraan']) ? student['kewarganegaraan'] : null;
    _selectedJalurMasuk = jalurMasukOptions.contains(student['jalurMasuk']) ? student['jalurMasuk'] : null;

    namaAyahController = TextEditingController(text: student['namaAyah'] ?? '');
    nikAyahController = TextEditingController(text: student['nikAyah'] ?? '');
    pekerjaanAyahController = TextEditingController(text: student['pekerjaanAyah'] ?? '');
    pendidikanAyahController = TextEditingController(text: student['pendidikanAyah'] ?? '');
    noHpAyahController = TextEditingController(text: student['noHpAyah'] ?? '');

    namaIbuController = TextEditingController(text: student['namaIbu'] ?? '');
    nikIbuController = TextEditingController(text: student['nikIbu'] ?? '');
    pekerjaanIbuController = TextEditingController(text: student['pekerjaanIbu'] ?? '');
    pendidikanIbuController = TextEditingController(text: student['pendidikanIbu'] ?? '');
    noHpIbuController = TextEditingController(text: student['noHpIbu'] ?? '');

    namaWaliController = TextEditingController(text: student['namaWali'] ?? '');
    hubunganWaliController = TextEditingController(text: student['hubunganWali'] ?? '');
    noHpWaliController = TextEditingController(text: student['noHpWali'] ?? '');
    alamatWaliController = TextEditingController(text: student['alamatWali'] ?? '');
  }

  Future<void> updateStudent() async {
    if (!_formKey.currentState!.validate()) return;

    final studentId = widget.student['studentId'] as String? ?? '';
    if (studentId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: studentId tidak ditemukan. Tidak dapat menyimpan.')),
      );
      return;
    }

    try {
      setState(() {
        isLoading = true;
      });

      debugPrint('Updating student ID: $studentId');
      await StudentService().updateStudent(
        studentId: studentId,
        nis: nisController.text.trim(),
        nama: namaController.text.trim(),
        gender: _selectedGender ?? '',
        alamat: addressController.text.trim(),
        tanggalLahir: tanggalLahirController.text.trim(),
        angkatan: angkatanController.text.trim(),
        nisn: nisnController.text.trim(),
        tempatLahir: tempatLahirController.text.trim(),
        agama: _selectedAgama,
        kewarganegaraan: _selectedKewarganegaraan,
        noHp: noHpController.text.trim(),
        jalurMasuk: _selectedJalurMasuk,
        tanggalDiterima: tanggalDiterimaController.text.trim(),
        namaAyah: namaAyahController.text.trim(),
        nikAyah: nikAyahController.text.trim(),
        pekerjaanAyah: pekerjaanAyahController.text.trim(),
        pendidikanAyah: pendidikanAyahController.text.trim(),
        noHpAyah: noHpAyahController.text.trim(),
        namaIbu: namaIbuController.text.trim(),
        nikIbu: nikIbuController.text.trim(),
        pekerjaanIbu: pekerjaanIbuController.text.trim(),
        pendidikanIbu: pendidikanIbuController.text.trim(),
        noHpIbu: noHpIbuController.text.trim(),
        namaWali: namaWaliController.text.trim(),
        hubunganWali: hubunganWaliController.text.trim(),
        noHpWali: noHpWaliController.text.trim(),
        alamatWali: alamatWaliController.text.trim(),
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalization.isIndonesian ? 'Data murid berhasil diperbarui' : 'Student data successfully updated')),
      );

      // Return the updated data so the detail page can reflect it
      Navigator.pop(context, {
        ...widget.student,
        'nis': nisController.text.trim(),
        'nama': namaController.text.trim(),
        'gender': _selectedGender ?? '',
        'alamat': addressController.text.trim(),
        'tanggalLahir': tanggalLahirController.text.trim(),
        'angkatan': angkatanController.text.trim(),
        'nisn': nisnController.text.trim(),
        'tempatLahir': tempatLahirController.text.trim(),
        'agama': _selectedAgama,
        'kewarganegaraan': _selectedKewarganegaraan,
        'noHp': noHpController.text.trim(),
        'jalurMasuk': _selectedJalurMasuk,
        'tanggalDiterima': tanggalDiterimaController.text.trim(),
        'namaAyah': namaAyahController.text.trim(),
        'nikAyah': nikAyahController.text.trim(),
        'pekerjaanAyah': pekerjaanAyahController.text.trim(),
        'pendidikanAyah': pendidikanAyahController.text.trim(),
        'noHpAyah': noHpAyahController.text.trim(),
        'namaIbu': namaIbuController.text.trim(),
        'nikIbu': nikIbuController.text.trim(),
        'pekerjaanIbu': pekerjaanIbuController.text.trim(),
        'pendidikanIbu': pendidikanIbuController.text.trim(),
        'noHpIbu': noHpIbuController.text.trim(),
        'namaWali': namaWaliController.text.trim(),
        'hubunganWali': hubunganWaliController.text.trim(),
        'noHpWali': noHpWaliController.text.trim(),
        'alamatWali': alamatWaliController.text.trim(),
      });
    } catch (e) {
      debugPrint(e.toString());

      if (mounted) {
        final errorMsg = e.toString().replaceAll('Exception: ', '').replaceAll('Exception ', '');
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMsg)));
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
    nisController.dispose();
    nisnController.dispose();
    tempatLahirController.dispose();
    addressController.dispose();
    tanggalLahirController.dispose();
    angkatanController.dispose();
    noHpController.dispose();
    tanggalDiterimaController.dispose();
    namaAyahController.dispose();
    nikAyahController.dispose();
    pekerjaanAyahController.dispose();
    pendidikanAyahController.dispose();
    noHpAyahController.dispose();
    namaIbuController.dispose();
    nikIbuController.dispose();
    pekerjaanIbuController.dispose();
    pendidikanIbuController.dispose();
    noHpIbuController.dispose();
    namaWaliController.dispose();
    hubunganWaliController.dispose();
    noHpWaliController.dispose();
    alamatWaliController.dispose();
    super.dispose();
  }

  Widget _buildSectionHeader(String title, Color textColor) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 12),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 20,
            decoration: BoxDecoration(
              color: const Color(0xFF0EA5E9),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
        ],
      ),
    );
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
                            AppLocalization.isIndonesian ? 'Edit Data Murid' : 'Edit Student Data',
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
                          
                          _buildSectionHeader(AppLocalization.isIndonesian ? 'Data Pribadi' : 'Personal Data', textColor),

                          _buildField(
                            controller: namaController,
                            label: AppLocalization.isIndonesian ? 'Nama Lengkap *' : 'Full Name *',
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
                            label: AppLocalization.isIndonesian ? 'Nomor Induk Siswa (NIS) *' : 'Student ID Number (NIS) *',
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

                          _buildField(
                            controller: nisnController,
                            label: 'NISN',
                            icon: Icons.credit_card_rounded,
                            keyboardType: TextInputType.number,
                            isDark: isDark,
                            textColor: textColor,
                            subTextColor: subTextColor,
                            cardBgColor: cardBgColor,
                            borderColor: borderColor,
                          ),
                          const SizedBox(height: 16),

                          _buildField(
                            controller: tempatLahirController,
                            label: AppLocalization.isIndonesian ? 'Tempat Lahir *' : 'Place of Birth *',
                            icon: Icons.location_city_rounded,
                            isDark: isDark,
                            textColor: textColor,
                            subTextColor: subTextColor,
                            cardBgColor: cardBgColor,
                            borderColor: borderColor,
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) {
                                return AppLocalization.isIndonesian ? 'Tempat lahir tidak boleh kosong' : 'Place of birth cannot be empty';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          _buildField(
                            controller: tanggalLahirController,
                            label: AppLocalization.isIndonesian ? 'Tanggal Lahir (DD-MM-YYYY) *' : 'Date of Birth (DD-MM-YYYY) *',
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
                              final reg = RegExp(r'^\d{2}-\d{2}-\d{4}$');
                              if (!reg.hasMatch(val.trim())) {
                                return AppLocalization.isIndonesian ? 'Format harus DD-MM-YYYY (contoh: 15-08-2008)' : 'Format must be DD-MM-YYYY (e.g. 15-08-2008)';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          _buildDropdown(
                            value: _selectedGender,
                            items: ['Laki-laki', 'Perempuan'],
                            label: AppLocalization.isIndonesian ? 'Jenis Kelamin *' : 'Gender *',
                            icon: Icons.wc_rounded,
                            isDark: isDark,
                            textColor: textColor,
                            subTextColor: subTextColor,
                            cardBgColor: cardBgColor,
                            borderColor: borderColor,
                            onChanged: (val) => setState(() => _selectedGender = val),
                            validator: (val) => val == null ? (AppLocalization.isIndonesian ? 'Pilih jenis kelamin' : 'Select gender') : null,
                          ),
                          const SizedBox(height: 16),

                          _buildDropdown(
                            value: _selectedAgama,
                            items: agamaOptions,
                            label: AppLocalization.isIndonesian ? 'Agama *' : 'Religion *',
                            icon: Icons.mosque_rounded,
                            isDark: isDark,
                            textColor: textColor,
                            subTextColor: subTextColor,
                            cardBgColor: cardBgColor,
                            borderColor: borderColor,
                            onChanged: (val) => setState(() => _selectedAgama = val),
                            validator: (val) => val == null ? (AppLocalization.isIndonesian ? 'Pilih agama' : 'Select religion') : null,
                          ),
                          const SizedBox(height: 16),
                          
                          _buildDropdown(
                            value: _selectedKewarganegaraan,
                            items: kewarganegaraanOptions,
                            label: AppLocalization.isIndonesian ? 'Kewarganegaraan' : 'Citizenship',
                            icon: Icons.flag_rounded,
                            isDark: isDark,
                            textColor: textColor,
                            subTextColor: subTextColor,
                            cardBgColor: cardBgColor,
                            borderColor: borderColor,
                            onChanged: (val) => setState(() => _selectedKewarganegaraan = val),
                          ),
                          const SizedBox(height: 16),

                          _buildField(
                            controller: addressController,
                            label: AppLocalization.isIndonesian ? 'Alamat Rumah *' : 'Home Address *',
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
                          const SizedBox(height: 16),

                          _buildField(
                            controller: noHpController,
                            label: AppLocalization.isIndonesian ? 'Nomor HP' : 'Phone Number',
                            icon: Icons.phone_rounded,
                            keyboardType: TextInputType.phone,
                            isDark: isDark,
                            textColor: textColor,
                            subTextColor: subTextColor,
                            cardBgColor: cardBgColor,
                            borderColor: borderColor,
                          ),
                          const SizedBox(height: 16),

                          _buildField(
                            controller: angkatanController,
                            label: AppLocalization.isIndonesian ? 'Tahun Angkatan *' : 'Batch Year *',
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

                          _buildDropdown(
                            value: _selectedJalurMasuk,
                            items: jalurMasukOptions,
                            label: AppLocalization.isIndonesian ? 'Jalur Masuk' : 'Admission Path',
                            icon: Icons.login_rounded,
                            isDark: isDark,
                            textColor: textColor,
                            subTextColor: subTextColor,
                            cardBgColor: cardBgColor,
                            borderColor: borderColor,
                            onChanged: (val) => setState(() => _selectedJalurMasuk = val),
                          ),
                          const SizedBox(height: 16),

                          _buildField(
                            controller: tanggalDiterimaController,
                            label: AppLocalization.isIndonesian ? 'Tanggal Diterima (DD-MM-YYYY)' : 'Admission Date (DD-MM-YYYY)',
                            icon: Icons.event_available_rounded,
                            isDark: isDark,
                            textColor: textColor,
                            subTextColor: subTextColor,
                            cardBgColor: cardBgColor,
                            borderColor: borderColor,
                          ),

                          _buildSectionHeader(AppLocalization.isIndonesian ? 'Data Ayah' : 'Father\'s Data', textColor),
                          _buildField(controller: namaAyahController, label: 'Nama Ayah', icon: Icons.person_outline_rounded, isDark: isDark, textColor: textColor, subTextColor: subTextColor, cardBgColor: cardBgColor, borderColor: borderColor),
                          const SizedBox(height: 16),
                          _buildField(controller: nikAyahController, label: 'NIK Ayah', icon: Icons.badge_outlined, keyboardType: TextInputType.number, isDark: isDark, textColor: textColor, subTextColor: subTextColor, cardBgColor: cardBgColor, borderColor: borderColor),
                          const SizedBox(height: 16),
                          _buildField(controller: pekerjaanAyahController, label: 'Pekerjaan Ayah', icon: Icons.work_outline_rounded, isDark: isDark, textColor: textColor, subTextColor: subTextColor, cardBgColor: cardBgColor, borderColor: borderColor),
                          const SizedBox(height: 16),
                          _buildField(controller: pendidikanAyahController, label: 'Pendidikan Ayah', icon: Icons.school_outlined, isDark: isDark, textColor: textColor, subTextColor: subTextColor, cardBgColor: cardBgColor, borderColor: borderColor),
                          const SizedBox(height: 16),
                          _buildField(controller: noHpAyahController, label: 'No. HP Ayah', icon: Icons.phone_outlined, keyboardType: TextInputType.phone, isDark: isDark, textColor: textColor, subTextColor: subTextColor, cardBgColor: cardBgColor, borderColor: borderColor),

                          _buildSectionHeader(AppLocalization.isIndonesian ? 'Data Ibu' : 'Mother\'s Data', textColor),
                          _buildField(controller: namaIbuController, label: 'Nama Ibu', icon: Icons.person_outline_rounded, isDark: isDark, textColor: textColor, subTextColor: subTextColor, cardBgColor: cardBgColor, borderColor: borderColor),
                          const SizedBox(height: 16),
                          _buildField(controller: nikIbuController, label: 'NIK Ibu', icon: Icons.badge_outlined, keyboardType: TextInputType.number, isDark: isDark, textColor: textColor, subTextColor: subTextColor, cardBgColor: cardBgColor, borderColor: borderColor),
                          const SizedBox(height: 16),
                          _buildField(controller: pekerjaanIbuController, label: 'Pekerjaan Ibu', icon: Icons.work_outline_rounded, isDark: isDark, textColor: textColor, subTextColor: subTextColor, cardBgColor: cardBgColor, borderColor: borderColor),
                          const SizedBox(height: 16),
                          _buildField(controller: pendidikanIbuController, label: 'Pendidikan Ibu', icon: Icons.school_outlined, isDark: isDark, textColor: textColor, subTextColor: subTextColor, cardBgColor: cardBgColor, borderColor: borderColor),
                          const SizedBox(height: 16),
                          _buildField(controller: noHpIbuController, label: 'No. HP Ibu', icon: Icons.phone_outlined, keyboardType: TextInputType.phone, isDark: isDark, textColor: textColor, subTextColor: subTextColor, cardBgColor: cardBgColor, borderColor: borderColor),

                          _buildSectionHeader(AppLocalization.isIndonesian ? 'Data Wali (Jika Ada)' : 'Guardian\'s Data (If Any)', textColor),
                          _buildField(controller: namaWaliController, label: 'Nama Wali', icon: Icons.person_outline_rounded, isDark: isDark, textColor: textColor, subTextColor: subTextColor, cardBgColor: cardBgColor, borderColor: borderColor),
                          const SizedBox(height: 16),
                          _buildField(controller: hubunganWaliController, label: 'Hubungan dengan Siswa', icon: Icons.family_restroom_rounded, isDark: isDark, textColor: textColor, subTextColor: subTextColor, cardBgColor: cardBgColor, borderColor: borderColor),
                          const SizedBox(height: 16),
                          _buildField(controller: noHpWaliController, label: 'No. HP Wali', icon: Icons.phone_outlined, keyboardType: TextInputType.phone, isDark: isDark, textColor: textColor, subTextColor: subTextColor, cardBgColor: cardBgColor, borderColor: borderColor),
                          const SizedBox(height: 16),
                          _buildField(controller: alamatWaliController, label: 'Alamat Wali', icon: Icons.home_outlined, maxLines: 2, isDark: isDark, textColor: textColor, subTextColor: subTextColor, cardBgColor: cardBgColor, borderColor: borderColor),

                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          bottomNavigationBar: SafeArea(
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F0C20) : Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 12,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Container(
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
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: isLoading ? null : updateStudent,
                  child: isLoading
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                        )
                      : Text(
                          AppLocalization.isIndonesian ? 'Simpan Perubahan' : 'Save Changes',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                ),
              ),
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

  Widget _buildDropdown({
    required String? value,
    required List<String> items,
    required String label,
    required IconData icon,
    required bool isDark,
    required Color textColor,
    required Color subTextColor,
    required Color cardBgColor,
    required Color borderColor,
    required void Function(String?) onChanged,
    String? Function(String?)? validator,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: cardBgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: DropdownButtonFormField<String>(
        value: value,
        style: TextStyle(color: textColor, fontSize: 15),
        dropdownColor: isDark ? const Color(0xFF151026) : Colors.white,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: subTextColor, fontSize: 14),
          prefixIcon: Icon(icon, color: const Color(0xFF0EA5E9), size: 20),
          border: InputBorder.none,
        ),
        items: items.map((item) => DropdownMenuItem(
          value: item,
          child: Text(item, style: TextStyle(color: textColor)),
        )).toList(),
        onChanged: onChanged,
        validator: validator,
      ),
    );
  }
}
