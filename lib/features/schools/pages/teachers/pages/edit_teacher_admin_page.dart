import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../../../authentication/widgets/auth_background.dart';
import 'package:sys_mng_school/core/localization/app_localization.dart';

class EditTeacherAdminPage extends StatefulWidget {
  final Map<String, dynamic> teacher;

  const EditTeacherAdminPage({super.key, required this.teacher});

  @override
  State<EditTeacherAdminPage> createState() => _EditTeacherAdminPageState();
}

class _EditTeacherAdminPageState extends State<EditTeacherAdminPage> {
  final _formKey = GlobalKey<FormState>();

  // Data Pribadi
  late TextEditingController namaController;
  late TextEditingController nipController;
  late TextEditingController nuptKController;
  late TextEditingController noPegawaiController;
  late TextEditingController gelarDepanController;
  late TextEditingController gelarBelakangController;
  late TextEditingController tempatLahirController;
  late TextEditingController tanggalLahirController;
  late TextEditingController alamatController;
  late TextEditingController noHpController;
  late TextEditingController kontakDaruratController;

  // Data Identitas
  late TextEditingController nikController;
  late TextEditingController npwpController;
  late TextEditingController bpjsKesehatanController;
  late TextEditingController bpjsKetenagakerjaanController;
  late TextEditingController nomorKkController;
  late TextEditingController nomorRekeningController;
  late TextEditingController namaBankController;

  // Data Kepegawaian
  late TextEditingController jabatanController;
  late TextEditingController pangkatGolonganController;
  late TextEditingController tmtController;
  late TextEditingController tanggalBergabungController;
  late TextEditingController masaKerjaController;

  // Data Akademik
  late TextEditingController pendidikanTerakhirController;
  late TextEditingController jurusanController;
  late TextEditingController universitasController;
  late TextEditingController tahunLulusController;
  late TextEditingController sertifikasiGuruController;
  late TextEditingController bidangSertifikasiController;

  String? _selectedGender;
  String? _selectedAgama;
  String? _selectedKewarganegaraan;
  String? _selectedStatusPernikahan;
  String? _selectedGolonganDarah;
  String? _selectedStatusGuru;

  final List<String> agamaOptions = ['Islam', 'Kristen', 'Katolik', 'Hindu', 'Buddha', 'Konghucu'];
  final List<String> kewarganegaraanOptions = ['WNI', 'WNA'];
  final List<String> statusPernikahanOptions = ['Belum Menikah', 'Menikah', 'Duda/Janda'];
  final List<String> golonganDarahOptions = ['A', 'B', 'AB', 'O', 'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];
  final List<String> statusGuruOptions = ['Tetap', 'Honorer', 'PPPK', 'PNS', 'Kontrak'];

  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    final t = widget.teacher;
    namaController = TextEditingController(text: t['nama'] ?? '');
    nipController = TextEditingController(text: t['nip'] ?? '');
    nuptKController = TextEditingController(text: t['nuptk'] ?? '');
    noPegawaiController = TextEditingController(text: t['noPegawai'] ?? '');
    gelarDepanController = TextEditingController(text: t['gelarDepan'] ?? '');
    gelarBelakangController = TextEditingController(text: t['gelarBelakang'] ?? '');
    tempatLahirController = TextEditingController(text: t['tempatLahir'] ?? '');
    tanggalLahirController = TextEditingController(text: t['tanggalLahir'] ?? '');
    alamatController = TextEditingController(text: t['alamat'] ?? '');
    noHpController = TextEditingController(text: t['noHp'] ?? '');
    kontakDaruratController = TextEditingController(text: t['kontakDarurat'] ?? '');
    nikController = TextEditingController(text: t['nik'] ?? '');
    npwpController = TextEditingController(text: t['npwp'] ?? '');
    bpjsKesehatanController = TextEditingController(text: t['bpjsKesehatan'] ?? '');
    bpjsKetenagakerjaanController = TextEditingController(text: t['bpjsKetenagakerjaan'] ?? '');
    nomorKkController = TextEditingController(text: t['nomorKk'] ?? '');
    nomorRekeningController = TextEditingController(text: t['nomorRekening'] ?? '');
    namaBankController = TextEditingController(text: t['namaBank'] ?? '');
    jabatanController = TextEditingController(text: t['jabatan'] ?? '');
    pangkatGolonganController = TextEditingController(text: t['pangkatGolongan'] ?? '');
    tmtController = TextEditingController(text: t['tmt'] ?? '');
    tanggalBergabungController = TextEditingController(text: t['tanggalBergabung'] ?? '');
    masaKerjaController = TextEditingController(text: t['masaKerja'] ?? '');
    pendidikanTerakhirController = TextEditingController(text: t['pendidikanTerakhir'] ?? '');
    jurusanController = TextEditingController(text: t['jurusan'] ?? '');
    universitasController = TextEditingController(text: t['universitas'] ?? '');
    tahunLulusController = TextEditingController(text: t['tahunLulus'] ?? '');
    sertifikasiGuruController = TextEditingController(text: t['sertifikasiGuru'] ?? '');
    bidangSertifikasiController = TextEditingController(text: t['bidangSertifikasi'] ?? '');

    _selectedGender = (t['gender'] == 'Laki-laki' || t['gender'] == 'Perempuan') ? t['gender'] : null;
    _selectedAgama = agamaOptions.contains(t['agama']) ? t['agama'] : null;
    _selectedKewarganegaraan = kewarganegaraanOptions.contains(t['kewarganegaraan']) ? t['kewarganegaraan'] : null;
    _selectedStatusPernikahan = statusPernikahanOptions.contains(t['statusPernikahan']) ? t['statusPernikahan'] : null;
    _selectedGolonganDarah = golonganDarahOptions.contains(t['golonganDarah']) ? t['golonganDarah'] : null;
    _selectedStatusGuru = statusGuruOptions.contains(t['statusGuru']) ? t['statusGuru'] : null;
  }

  @override
  void dispose() {
    namaController.dispose(); nipController.dispose(); nuptKController.dispose();
    noPegawaiController.dispose(); gelarDepanController.dispose(); gelarBelakangController.dispose();
    tempatLahirController.dispose(); tanggalLahirController.dispose(); alamatController.dispose();
    noHpController.dispose(); kontakDaruratController.dispose(); nikController.dispose();
    npwpController.dispose(); bpjsKesehatanController.dispose(); bpjsKetenagakerjaanController.dispose();
    nomorKkController.dispose(); nomorRekeningController.dispose(); namaBankController.dispose();
    jabatanController.dispose(); pangkatGolonganController.dispose(); tmtController.dispose();
    tanggalBergabungController.dispose(); masaKerjaController.dispose();
    pendidikanTerakhirController.dispose(); jurusanController.dispose(); universitasController.dispose();
    tahunLulusController.dispose(); sertifikasiGuruController.dispose(); bidangSertifikasiController.dispose();
    super.dispose();
  }

  Future<void> updateTeacher() async {
    if (!_formKey.currentState!.validate()) return;

    final teacherId = widget.teacher['teacherId'] as String? ?? '';
    if (teacherId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error: teacherId tidak ditemukan.')));
      return;
    }

    try {
      setState(() => isLoading = true);

      final schoolId = widget.teacher['schoolId'] as String? ?? '';
      final newNip = nipController.text.trim();

      // Cek NIP duplikat (abaikan jika milik guru ini sendiri)
      final existing = await FirebaseFirestore.instance
          .collection('schools').doc(schoolId).collection('teachers')
          .where('nip', isEqualTo: newNip).get();
      for (final doc in existing.docs) {
        if (doc.id != teacherId) {
          throw Exception('NIP $newNip sudah digunakan oleh guru lain.');
        }
      }

      await FirebaseFirestore.instance
          .collection('schools').doc(schoolId).collection('teachers').doc(teacherId)
          .update({
        'nama': namaController.text.trim(),
        'nip': newNip,
        'nuptk': nuptKController.text.trim(),
        'noPegawai': noPegawaiController.text.trim(),
        'gelarDepan': gelarDepanController.text.trim(),
        'gelarBelakang': gelarBelakangController.text.trim(),
        'gender': _selectedGender ?? '',
        'tempatLahir': tempatLahirController.text.trim(),
        'tanggalLahir': tanggalLahirController.text.trim(),
        'agama': _selectedAgama ?? '',
        'statusPernikahan': _selectedStatusPernikahan ?? '',
        'kewarganegaraan': _selectedKewarganegaraan ?? '',
        'golonganDarah': _selectedGolonganDarah ?? '',
        'alamat': alamatController.text.trim(),
        'noHp': noHpController.text.trim(),
        'kontakDarurat': kontakDaruratController.text.trim(),
        'nik': nikController.text.trim(),
        'npwp': npwpController.text.trim(),
        'bpjsKesehatan': bpjsKesehatanController.text.trim(),
        'bpjsKetenagakerjaan': bpjsKetenagakerjaanController.text.trim(),
        'nomorKk': nomorKkController.text.trim(),
        'nomorRekening': nomorRekeningController.text.trim(),
        'namaBank': namaBankController.text.trim(),
        'statusGuru': _selectedStatusGuru ?? '',
        'jabatan': jabatanController.text.trim(),
        'pangkatGolongan': pangkatGolonganController.text.trim(),
        'tmt': tmtController.text.trim(),
        'tanggalBergabung': tanggalBergabungController.text.trim(),
        'masaKerja': masaKerjaController.text.trim(),
        'pendidikanTerakhir': pendidikanTerakhirController.text.trim(),
        'jurusan': jurusanController.text.trim(),
        'universitas': universitasController.text.trim(),
        'tahunLulus': tahunLulusController.text.trim(),
        'sertifikasiGuru': sertifikasiGuruController.text.trim(),
        'bidangSertifikasi': bidangSertifikasiController.text.trim(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalization.isIndonesian ? 'Data guru berhasil diperbarui!' : 'Teacher data updated!')),
      );

      Navigator.pop(context, {
        ...widget.teacher,
        'nama': namaController.text.trim(),
        'nip': newNip,
        'nuptk': nuptKController.text.trim(),
        'noPegawai': noPegawaiController.text.trim(),
        'gelarDepan': gelarDepanController.text.trim(),
        'gelarBelakang': gelarBelakangController.text.trim(),
        'gender': _selectedGender ?? '',
        'tempatLahir': tempatLahirController.text.trim(),
        'tanggalLahir': tanggalLahirController.text.trim(),
        'agama': _selectedAgama ?? '',
        'statusPernikahan': _selectedStatusPernikahan ?? '',
        'kewarganegaraan': _selectedKewarganegaraan ?? '',
        'golonganDarah': _selectedGolonganDarah ?? '',
        'alamat': alamatController.text.trim(),
        'noHp': noHpController.text.trim(),
        'kontakDarurat': kontakDaruratController.text.trim(),
        'nik': nikController.text.trim(),
        'npwp': npwpController.text.trim(),
        'bpjsKesehatan': bpjsKesehatanController.text.trim(),
        'bpjsKetenagakerjaan': bpjsKetenagakerjaanController.text.trim(),
        'nomorKk': nomorKkController.text.trim(),
        'nomorRekening': nomorRekeningController.text.trim(),
        'namaBank': namaBankController.text.trim(),
        'statusGuru': _selectedStatusGuru ?? '',
        'jabatan': jabatanController.text.trim(),
        'pangkatGolongan': pangkatGolonganController.text.trim(),
        'tmt': tmtController.text.trim(),
        'tanggalBergabung': tanggalBergabungController.text.trim(),
        'masaKerja': masaKerjaController.text.trim(),
        'pendidikanTerakhir': pendidikanTerakhirController.text.trim(),
        'jurusan': jurusanController.text.trim(),
        'universitas': universitasController.text.trim(),
        'tahunLulus': tahunLulusController.text.trim(),
        'sertifikasiGuru': sertifikasiGuruController.text.trim(),
        'bidangSertifikasi': bidangSertifikasiController.text.trim(),
      });
    } catch (e) {
      debugPrint(e.toString());
      if (mounted) {
        final msg = e.toString().replaceAll('Exception: ', '');
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
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
                        IconButton(onPressed: () => Navigator.pop(context), icon: Icon(Icons.arrow_back_ios_new_rounded, color: textColor, size: 20)),
                        const SizedBox(width: 4),
                        Expanded(child: Text(AppLocalization.isIndonesian ? 'Edit Data Guru' : 'Edit Teacher Data', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor))),
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

                          // ── SECTION 1: DATA PRIBADI ──
                          _buildSectionHeader('Data Pribadi', textColor),
                          _buildField(controller: namaController, label: 'Nama Lengkap *', icon: Icons.person_outline_rounded, isDark: isDark, textColor: textColor, subTextColor: subTextColor, cardBgColor: cardBgColor, borderColor: borderColor,
                            validator: (v) => (v == null || v.isEmpty) ? 'Nama wajib diisi' : null),
                          const SizedBox(height: 14),
                          _buildField(controller: nipController, label: 'NIP *', icon: Icons.badge_outlined, isDark: isDark, textColor: textColor, subTextColor: subTextColor, cardBgColor: cardBgColor, borderColor: borderColor,
                            validator: (v) => (v == null || v.isEmpty) ? 'NIP wajib diisi' : null),
                          const SizedBox(height: 14),
                          _buildField(controller: nuptKController, label: 'NUPTK', icon: Icons.numbers_rounded, isDark: isDark, textColor: textColor, subTextColor: subTextColor, cardBgColor: cardBgColor, borderColor: borderColor),
                          const SizedBox(height: 14),
                          _buildField(controller: noPegawaiController, label: 'Nomor Pegawai Internal', icon: Icons.tag_rounded, isDark: isDark, textColor: textColor, subTextColor: subTextColor, cardBgColor: cardBgColor, borderColor: borderColor),
                          const SizedBox(height: 14),
                          _buildField(controller: gelarDepanController, label: 'Gelar Depan', icon: Icons.school_outlined, isDark: isDark, textColor: textColor, subTextColor: subTextColor, cardBgColor: cardBgColor, borderColor: borderColor),
                          const SizedBox(height: 14),
                          _buildField(controller: gelarBelakangController, label: 'Gelar Belakang', icon: Icons.school_outlined, isDark: isDark, textColor: textColor, subTextColor: subTextColor, cardBgColor: cardBgColor, borderColor: borderColor),
                          const SizedBox(height: 14),
                          _buildDropdown(value: _selectedGender, items: const ['Laki-laki', 'Perempuan'], label: 'Jenis Kelamin *', icon: Icons.wc_rounded, isDark: isDark, textColor: textColor, subTextColor: subTextColor, cardBgColor: cardBgColor, borderColor: borderColor,
                            onChanged: (v) => setState(() => _selectedGender = v),
                            validator: (v) => (v == null || v.isEmpty) ? 'Jenis kelamin wajib dipilih' : null),
                          const SizedBox(height: 14),
                          _buildField(controller: tempatLahirController, label: 'Tempat Lahir *', icon: Icons.location_city_rounded, isDark: isDark, textColor: textColor, subTextColor: subTextColor, cardBgColor: cardBgColor, borderColor: borderColor,
                            validator: (v) => (v == null || v.isEmpty) ? 'Tempat lahir wajib diisi' : null),
                          const SizedBox(height: 14),
                          _buildField(controller: tanggalLahirController, label: 'Tanggal Lahir * (dd-MM-yyyy)', icon: Icons.cake_outlined, isDark: isDark, textColor: textColor, subTextColor: subTextColor, cardBgColor: cardBgColor, borderColor: borderColor,
                            keyboardType: TextInputType.datetime,
                            validator: (v) => (v == null || v.isEmpty) ? 'Tanggal lahir wajib diisi' : null),
                          const SizedBox(height: 14),
                          _buildDropdown(value: _selectedAgama, items: agamaOptions, label: 'Agama *', icon: Icons.menu_book_rounded, isDark: isDark, textColor: textColor, subTextColor: subTextColor, cardBgColor: cardBgColor, borderColor: borderColor,
                            onChanged: (v) => setState(() => _selectedAgama = v),
                            validator: (v) => (v == null || v.isEmpty) ? 'Agama wajib dipilih' : null),
                          const SizedBox(height: 14),
                          _buildDropdown(value: _selectedStatusPernikahan, items: statusPernikahanOptions, label: 'Status Pernikahan', icon: Icons.favorite_border_rounded, isDark: isDark, textColor: textColor, subTextColor: subTextColor, cardBgColor: cardBgColor, borderColor: borderColor,
                            onChanged: (v) => setState(() => _selectedStatusPernikahan = v)),
                          const SizedBox(height: 14),
                          _buildDropdown(value: _selectedKewarganegaraan, items: kewarganegaraanOptions, label: 'Kewarganegaraan *', icon: Icons.flag_outlined, isDark: isDark, textColor: textColor, subTextColor: subTextColor, cardBgColor: cardBgColor, borderColor: borderColor,
                            onChanged: (v) => setState(() => _selectedKewarganegaraan = v),
                            validator: (v) => (v == null || v.isEmpty) ? 'Kewarganegaraan wajib dipilih' : null),
                          const SizedBox(height: 14),
                          _buildDropdown(value: _selectedGolonganDarah, items: golonganDarahOptions, label: 'Golongan Darah', icon: Icons.bloodtype_outlined, isDark: isDark, textColor: textColor, subTextColor: subTextColor, cardBgColor: cardBgColor, borderColor: borderColor,
                            onChanged: (v) => setState(() => _selectedGolonganDarah = v)),
                          const SizedBox(height: 14),
                          _buildField(controller: alamatController, label: 'Alamat', icon: Icons.home_outlined, isDark: isDark, textColor: textColor, subTextColor: subTextColor, cardBgColor: cardBgColor, borderColor: borderColor, maxLines: 3),
                          const SizedBox(height: 14),
                          _buildField(controller: noHpController, label: 'Nomor HP *', icon: Icons.phone_outlined, isDark: isDark, textColor: textColor, subTextColor: subTextColor, cardBgColor: cardBgColor, borderColor: borderColor,
                            keyboardType: TextInputType.phone,
                            validator: (v) => (v == null || v.isEmpty) ? 'Nomor HP wajib diisi' : null),
                          const SizedBox(height: 14),
                          _buildField(controller: kontakDaruratController, label: 'Kontak Darurat', icon: Icons.contact_phone_outlined, isDark: isDark, textColor: textColor, subTextColor: subTextColor, cardBgColor: cardBgColor, borderColor: borderColor, keyboardType: TextInputType.phone),

                          // ── SECTION 2: DATA IDENTITAS ──
                          _buildSectionHeader('Data Identitas', textColor),
                          _buildField(controller: nikController, label: 'NIK *', icon: Icons.credit_card_rounded, isDark: isDark, textColor: textColor, subTextColor: subTextColor, cardBgColor: cardBgColor, borderColor: borderColor,
                            keyboardType: TextInputType.number,
                            validator: (v) => (v == null || v.isEmpty) ? 'NIK wajib diisi' : null),
                          const SizedBox(height: 14),
                          _buildField(controller: npwpController, label: 'NPWP', icon: Icons.receipt_long_outlined, isDark: isDark, textColor: textColor, subTextColor: subTextColor, cardBgColor: cardBgColor, borderColor: borderColor, keyboardType: TextInputType.number),
                          const SizedBox(height: 14),
                          _buildField(controller: bpjsKesehatanController, label: 'BPJS Kesehatan', icon: Icons.health_and_safety_outlined, isDark: isDark, textColor: textColor, subTextColor: subTextColor, cardBgColor: cardBgColor, borderColor: borderColor, keyboardType: TextInputType.number),
                          const SizedBox(height: 14),
                          _buildField(controller: bpjsKetenagakerjaanController, label: 'BPJS Ketenagakerjaan', icon: Icons.work_history_outlined, isDark: isDark, textColor: textColor, subTextColor: subTextColor, cardBgColor: cardBgColor, borderColor: borderColor, keyboardType: TextInputType.number),
                          const SizedBox(height: 14),
                          _buildField(controller: nomorKkController, label: 'Nomor KK *', icon: Icons.family_restroom_rounded, isDark: isDark, textColor: textColor, subTextColor: subTextColor, cardBgColor: cardBgColor, borderColor: borderColor,
                            keyboardType: TextInputType.number,
                            validator: (v) => (v == null || v.isEmpty) ? 'Nomor KK wajib diisi' : null),
                          const SizedBox(height: 14),
                          _buildField(controller: nomorRekeningController, label: 'Nomor Rekening', icon: Icons.account_balance_outlined, isDark: isDark, textColor: textColor, subTextColor: subTextColor, cardBgColor: cardBgColor, borderColor: borderColor, keyboardType: TextInputType.number),
                          const SizedBox(height: 14),
                          _buildField(controller: namaBankController, label: 'Nama Bank', icon: Icons.account_balance_wallet_outlined, isDark: isDark, textColor: textColor, subTextColor: subTextColor, cardBgColor: cardBgColor, borderColor: borderColor),

                          // ── SECTION 3: DATA KEPEGAWAIAN ──
                          _buildSectionHeader('Data Kepegawaian', textColor),
                          _buildDropdown(value: _selectedStatusGuru, items: statusGuruOptions, label: 'Status Guru', icon: Icons.work_outline_rounded, isDark: isDark, textColor: textColor, subTextColor: subTextColor, cardBgColor: cardBgColor, borderColor: borderColor,
                            onChanged: (v) => setState(() => _selectedStatusGuru = v)),
                          const SizedBox(height: 14),
                          _buildField(controller: jabatanController, label: 'Jabatan', icon: Icons.business_center_outlined, isDark: isDark, textColor: textColor, subTextColor: subTextColor, cardBgColor: cardBgColor, borderColor: borderColor),
                          const SizedBox(height: 14),
                          _buildField(controller: pangkatGolonganController, label: 'Pangkat/Golongan', icon: Icons.military_tech_outlined, isDark: isDark, textColor: textColor, subTextColor: subTextColor, cardBgColor: cardBgColor, borderColor: borderColor),
                          const SizedBox(height: 14),
                          _buildField(controller: tmtController, label: 'TMT (dd-MM-yyyy)', icon: Icons.event_outlined, isDark: isDark, textColor: textColor, subTextColor: subTextColor, cardBgColor: cardBgColor, borderColor: borderColor, keyboardType: TextInputType.datetime),
                          const SizedBox(height: 14),
                          _buildField(controller: tanggalBergabungController, label: 'Tanggal Bergabung (dd-MM-yyyy)', icon: Icons.calendar_today_outlined, isDark: isDark, textColor: textColor, subTextColor: subTextColor, cardBgColor: cardBgColor, borderColor: borderColor, keyboardType: TextInputType.datetime),
                          const SizedBox(height: 14),
                          _buildField(controller: masaKerjaController, label: 'Masa Kerja', icon: Icons.timer_outlined, isDark: isDark, textColor: textColor, subTextColor: subTextColor, cardBgColor: cardBgColor, borderColor: borderColor),

                          // ── SECTION 4: DATA AKADEMIK ──
                          _buildSectionHeader('Data Akademik', textColor),
                          _buildField(controller: pendidikanTerakhirController, label: 'Pendidikan Terakhir *', icon: Icons.school_rounded, isDark: isDark, textColor: textColor, subTextColor: subTextColor, cardBgColor: cardBgColor, borderColor: borderColor,
                            validator: (v) => (v == null || v.isEmpty) ? 'Pendidikan terakhir wajib diisi' : null),
                          const SizedBox(height: 14),
                          _buildField(controller: jurusanController, label: 'Jurusan', icon: Icons.menu_book_outlined, isDark: isDark, textColor: textColor, subTextColor: subTextColor, cardBgColor: cardBgColor, borderColor: borderColor),
                          const SizedBox(height: 14),
                          _buildField(controller: universitasController, label: 'Universitas/Institusi', icon: Icons.account_balance_outlined, isDark: isDark, textColor: textColor, subTextColor: subTextColor, cardBgColor: cardBgColor, borderColor: borderColor),
                          const SizedBox(height: 14),
                          _buildField(controller: tahunLulusController, label: 'Tahun Lulus', icon: Icons.calendar_month_outlined, isDark: isDark, textColor: textColor, subTextColor: subTextColor, cardBgColor: cardBgColor, borderColor: borderColor, keyboardType: TextInputType.number),
                          const SizedBox(height: 14),
                          _buildField(controller: sertifikasiGuruController, label: 'Sertifikasi Guru (No. Sertifikat)', icon: Icons.verified_outlined, isDark: isDark, textColor: textColor, subTextColor: subTextColor, cardBgColor: cardBgColor, borderColor: borderColor),
                          const SizedBox(height: 14),
                          _buildField(controller: bidangSertifikasiController, label: 'Bidang Sertifikasi', icon: Icons.assignment_outlined, isDark: isDark, textColor: textColor, subTextColor: subTextColor, cardBgColor: cardBgColor, borderColor: borderColor),
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
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 12, offset: const Offset(0, -4))],
              ),
              child: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)]),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: const Color(0xFF6366F1).withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 5))],
                ),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent, shadowColor: Colors.transparent,
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: isLoading ? null : updateTeacher,
                  child: isLoading
                      ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                      : Text(AppLocalization.isIndonesian ? 'Simpan Perubahan' : 'Save Changes', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(String title, Color textColor) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 12),
      child: Row(
        children: [
          Container(width: 4, height: 20, decoration: BoxDecoration(color: const Color(0xFF6366F1), borderRadius: BorderRadius.circular(4))),
          const SizedBox(width: 8),
          Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor)),
        ],
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller, required String label, required IconData icon,
    TextInputType? keyboardType, required bool isDark, required Color textColor,
    required Color subTextColor, required Color cardBgColor, required Color borderColor,
    int maxLines = 1, String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(color: cardBgColor, borderRadius: BorderRadius.circular(16), border: Border.all(color: borderColor)),
      child: TextFormField(
        controller: controller, keyboardType: keyboardType, validator: validator, maxLines: maxLines,
        style: TextStyle(color: textColor, fontSize: 15),
        decoration: InputDecoration(
          labelText: label, labelStyle: TextStyle(color: subTextColor, fontSize: 14),
          prefixIcon: Icon(icon, color: const Color(0xFF6366F1), size: 20),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: maxLines > 1 ? 12 : 16),
        ),
      ),
    );
  }

  Widget _buildDropdown({
    required String? value, required List<String> items, required String label, required IconData icon,
    required bool isDark, required Color textColor, required Color subTextColor,
    required Color cardBgColor, required Color borderColor,
    required void Function(String?) onChanged, String? Function(String?)? validator,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(color: cardBgColor, borderRadius: BorderRadius.circular(16), border: Border.all(color: borderColor)),
      child: DropdownButtonFormField<String>(
        value: value, style: TextStyle(color: textColor, fontSize: 15),
        dropdownColor: isDark ? const Color(0xFF151026) : Colors.white,
        decoration: InputDecoration(labelText: label, labelStyle: TextStyle(color: subTextColor, fontSize: 14), prefixIcon: Icon(icon, color: const Color(0xFF6366F1), size: 20), border: InputBorder.none),
        items: items.map((item) => DropdownMenuItem(value: item, child: Text(item, style: TextStyle(color: textColor)))).toList(),
        onChanged: onChanged, validator: validator,
      ),
    );
  }
}
