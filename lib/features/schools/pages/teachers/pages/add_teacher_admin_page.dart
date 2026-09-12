import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../../../authentication/widgets/auth_background.dart';
import 'package:sys_mng_school/core/localization/app_localization.dart';
import 'package:sys_mng_school/core/utils/doc_id_util.dart';

class AddTeacherPage extends StatefulWidget {
  final String schoolId;

  const AddTeacherPage({super.key, required this.schoolId});

  @override
  State<AddTeacherPage> createState() => _AddTeacherPageState();
}

class _AddTeacherPageState extends State<AddTeacherPage> {
  final _formKey = GlobalKey<FormState>();

  // Data Pribadi
  final namaController = TextEditingController();
  final nipController = TextEditingController();
  final nuptKController = TextEditingController();
  final noPegawaiController = TextEditingController();
  final gelarDepanController = TextEditingController();
  final gelarBelakangController = TextEditingController();
  final tempatLahirController = TextEditingController();
  final tanggalLahirController = TextEditingController();
  final alamatController = TextEditingController();
  final noHpController = TextEditingController();
  final kontakDaruratController = TextEditingController();

  // Data Identitas
  final nikController = TextEditingController();
  final npwpController = TextEditingController();
  final bpjsKesehatanController = TextEditingController();
  final bpjsKetenagakerjaanController = TextEditingController();
  final nomorKkController = TextEditingController();
  final nomorRekeningController = TextEditingController();
  final namaBankController = TextEditingController();

  // Data Kepegawaian
  final jabatanController = TextEditingController();
  final pangkatGolonganController = TextEditingController();
  final tmtController = TextEditingController();
  final tanggalBergabungController = TextEditingController();
  final masaKerjaController = TextEditingController();

  // Data Akademik
  final pendidikanTerakhirController = TextEditingController();
  final jurusanController = TextEditingController();
  final universitasController = TextEditingController();
  final tahunLulusController = TextEditingController();
  final sertifikasiGuruController = TextEditingController();
  final bidangSertifikasiController = TextEditingController();

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
  void dispose() {
    namaController.dispose();
    nipController.dispose();
    nuptKController.dispose();
    noPegawaiController.dispose();
    gelarDepanController.dispose();
    gelarBelakangController.dispose();
    tempatLahirController.dispose();
    tanggalLahirController.dispose();
    alamatController.dispose();
    noHpController.dispose();
    kontakDaruratController.dispose();
    nikController.dispose();
    npwpController.dispose();
    bpjsKesehatanController.dispose();
    bpjsKetenagakerjaanController.dispose();
    nomorKkController.dispose();
    nomorRekeningController.dispose();
    namaBankController.dispose();
    jabatanController.dispose();
    pangkatGolonganController.dispose();
    tmtController.dispose();
    tanggalBergabungController.dispose();
    masaKerjaController.dispose();
    pendidikanTerakhirController.dispose();
    jurusanController.dispose();
    universitasController.dispose();
    tahunLulusController.dispose();
    sertifikasiGuruController.dispose();
    bidangSertifikasiController.dispose();
    super.dispose();
  }

  Future<void> saveTeacher() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      setState(() => isLoading = true);

      final nip = nipController.text.trim();

      // Cek kuota guru
      final schoolDoc = await FirebaseFirestore.instance
          .collection('schools')
          .doc(widget.schoolId)
          .get();
      if (schoolDoc.exists) {
        final teacherQuota = schoolDoc.data()?['teacherQuota'] as int?;
        if (teacherQuota != null && teacherQuota > 0) {
          final countSnap = await FirebaseFirestore.instance
              .collection('schools')
              .doc(widget.schoolId)
              .collection('teachers')
              .count()
              .get();
          if ((countSnap.count ?? 0) >= teacherQuota) {
            if (mounted) _showQuotaFullDialog(context: context, userType: 'Guru', quota: teacherQuota);
            return;
          }
        }
      }

      // Cek NIP duplikat
      final existing = await FirebaseFirestore.instance
          .collection('schools')
          .doc(widget.schoolId)
          .collection('teachers')
          .where('nip', isEqualTo: nip)
          .get();
      if (existing.docs.isNotEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppLocalization.isIndonesian ? 'NIP sudah terdaftar!' : 'NIP already registered!')),
          );
        }
        return;
      }

      final namaTeacher = namaController.text.trim();
      final docId = generateFormattedDocId(namaTeacher);
      final doc = FirebaseFirestore.instance
          .collection('schools')
          .doc(widget.schoolId)
          .collection('teachers')
          .doc(docId);

      await doc.set({
        'teacherId': doc.id,
        'schoolId': widget.schoolId,
        'uid': '',
        'email': '',
        // Data Pribadi
        'nama': namaTeacher,
        'nip': nip,
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
        // Data Identitas
        'nik': nikController.text.trim(),
        'npwp': npwpController.text.trim(),
        'bpjsKesehatan': bpjsKesehatanController.text.trim(),
        'bpjsKetenagakerjaan': bpjsKetenagakerjaanController.text.trim(),
        'nomorKk': nomorKkController.text.trim(),
        'nomorRekening': nomorRekeningController.text.trim(),
        'namaBank': namaBankController.text.trim(),
        // Data Kepegawaian
        'statusGuru': _selectedStatusGuru ?? '',
        'jabatan': jabatanController.text.trim(),
        'pangkatGolongan': pangkatGolonganController.text.trim(),
        'tmt': tmtController.text.trim(),
        'tanggalBergabung': tanggalBergabungController.text.trim(),
        'masaKerja': masaKerjaController.text.trim(),
        // Data Akademik
        'pendidikanTerakhir': pendidikanTerakhirController.text.trim(),
        'jurusan': jurusanController.text.trim(),
        'universitas': universitasController.text.trim(),
        'tahunLulus': tahunLulusController.text.trim(),
        'sertifikasiGuru': sertifikasiGuruController.text.trim(),
        'bidangSertifikasi': bidangSertifikasiController.text.trim(),
        'aktif': true,
        'sudahRegister': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalization.isIndonesian ? 'Data guru berhasil disimpan!' : 'Teacher data saved!')),
      );
      Navigator.pop(context);
    } catch (e) {
      debugPrint(e.toString());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppLocalization.isIndonesian ? "Terjadi kesalahan" : "An error occurred"}: $e')),
        );
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
                          const SizedBox(height: 8),

                          // ── SECTION 1: DATA PRIBADI ──
                          _buildSectionHeader('Data Pribadi', textColor),
                          _buildField(controller: namaController, label: 'Nama Lengkap *', icon: Icons.person_outline_rounded, isDark: isDark, textColor: textColor, subTextColor: subTextColor, cardBgColor: cardBgColor, borderColor: borderColor,
                            validator: (v) => (v == null || v.isEmpty) ? 'Nama wajib diisi' : null),
                          const SizedBox(height: 14),
                          _buildField(controller: nipController, label: 'NIP (Nomor Induk Pegawai) *', icon: Icons.badge_outlined, isDark: isDark, textColor: textColor, subTextColor: subTextColor, cardBgColor: cardBgColor, borderColor: borderColor,
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
                          _buildField(controller: masaKerjaController, label: 'Masa Kerja (misal: 5 tahun)', icon: Icons.timer_outlined, isDark: isDark, textColor: textColor, subTextColor: subTextColor, cardBgColor: cardBgColor, borderColor: borderColor),

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
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 12, offset: const Offset(0, -4)),
                ],
              ),
              child: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)]),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: const Color(0xFF6366F1).withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 5))],
                ),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: isLoading ? null : saveTeacher,
                  child: isLoading
                      ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                      : Text(
                          AppLocalization.isIndonesian ? 'Simpan Data' : 'Save Data',
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
      decoration: BoxDecoration(color: cardBgColor, borderRadius: BorderRadius.circular(16), border: Border.all(color: borderColor)),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
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
      decoration: BoxDecoration(color: cardBgColor, borderRadius: BorderRadius.circular(16), border: Border.all(color: borderColor)),
      child: DropdownButtonFormField<String>(
        value: value,
        style: TextStyle(color: textColor, fontSize: 15),
        dropdownColor: isDark ? const Color(0xFF151026) : Colors.white,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: subTextColor, fontSize: 14),
          prefixIcon: Icon(icon, color: const Color(0xFF6366F1), size: 20),
          border: InputBorder.none,
        ),
        items: items.map((item) => DropdownMenuItem(value: item, child: Text(item, style: TextStyle(color: textColor)))).toList(),
        onChanged: onChanged,
        validator: validator,
      ),
    );
  }

  void _showQuotaFullDialog({required BuildContext context, required String userType, required int quota}) {
    showDialog(
      context: context,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final textColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
        final subTextColor = isDark ? Colors.white70 : const Color(0xFF1E1B4B).withValues(alpha: 0.65);
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          backgroundColor: isDark ? const Color(0xFF151026) : Colors.white,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(padding: const EdgeInsets.all(18), decoration: BoxDecoration(color: const Color(0xFFEF4444).withValues(alpha: 0.12), shape: BoxShape.circle),
                  child: const Icon(Icons.lock_outline_rounded, color: Color(0xFFEF4444), size: 44)),
                const SizedBox(height: 20),
                Text('Batas Kuota Guru Tercapai', style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                const SizedBox(height: 12),
                Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(color: const Color(0xFFEF4444).withValues(alpha: 0.08), borderRadius: BorderRadius.circular(30), border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.3))),
                  child: Text('Kapasitas: $quota Guru', style: const TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.w600, fontSize: 13))),
                const SizedBox(height: 16),
                Text('Sekolah Anda telah mencapai batas maksimal guru. Minta Super Admin untuk meningkatkan kuota.', style: TextStyle(color: subTextColor, fontSize: 13, height: 1.6), textAlign: TextAlign.center),
                const SizedBox(height: 24),
                SizedBox(width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444).withValues(alpha: 0.1), foregroundColor: const Color(0xFFEF4444), shadowColor: Colors.transparent, elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: const Color(0xFFEF4444).withValues(alpha: 0.3))), padding: const EdgeInsets.symmetric(vertical: 14)),
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Mengerti', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  )),
              ],
            ),
          ),
        );
      },
    );
  }
}
