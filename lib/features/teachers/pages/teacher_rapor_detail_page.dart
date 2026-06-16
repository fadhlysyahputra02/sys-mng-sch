import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../authentication/widgets/auth_background.dart';
import '../../schools/services/school_service.dart';
import '../services/grade_service.dart';
import '../services/rapor_service.dart';
import '../services/rapor_pdf_helper.dart';

class TeacherRaporDetailPage extends StatefulWidget {
  final String schoolId;
  final String classId;
  final String className;
  final String teacherId;
  final String studentId;
  final String studentName;
  final String studentNis;

  const TeacherRaporDetailPage({
    super.key,
    required this.schoolId,
    required this.classId,
    required this.className,
    required this.teacherId,
    required this.studentId,
    required this.studentName,
    required this.studentNis,
  });

  @override
  State<TeacherRaporDetailPage> createState() => _TeacherRaporDetailPageState();
}

class AttitudeAspectItem {
  final TextEditingController nameController;
  final TextEditingController descController;
  String predikat;

  AttitudeAspectItem({
    required String name,
    required String desc,
    required this.predikat,
  }) : nameController = TextEditingController(text: name),
       descController = TextEditingController(text: desc);

  void dispose() {
    nameController.dispose();
    descController.dispose();
  }

  Map<String, dynamic> toMap() {
    return {
      'name': nameController.text.trim(),
      'predikat': predikat,
      'deskripsi': descController.text.trim(),
    };
  }
}

class _TeacherRaporDetailPageState extends State<TeacherRaporDetailPage> {
  final _raporService = RaporService();
  final _gradeService = GradeService();

  // Controllers
  final _sakitController = TextEditingController(text: '0');
  final _izinController = TextEditingController(text: '0');
  final _alpaController = TextEditingController(text: '0');
  final _catatanController = TextEditingController();

  List<AttitudeAspectItem> _attitudeAspects = [];
  String _activeSemester = 'Semester 1';
  String _tahunAjaran = '${DateTime.now().year}/${DateTime.now().year + 1}';

  bool _isSaving = false;
  bool _isLoadingReportData = true;

  // Metadata sekolah & wali kelas untuk cetak PDF
  String _schoolName = 'Sekolah';
  String _teacherName = 'Wali Kelas';
  Map<String, int> _gradeTemplates = {};

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  @override
  void dispose() {
    for (final aspect in _attitudeAspects) {
      aspect.dispose();
    }
    _sakitController.dispose();
    _izinController.dispose();
    _alpaController.dispose();
    _catatanController.dispose();
    super.dispose();
  }

  Future<void> _loadAllData() async {
    try {
      // 1. Ambil Metadata Sekolah & Wali Kelas secara sekuensial terlebih dahulu
      final schoolData = await SchoolService().getSchoolByDomain(widget.schoolId);
      final teacherDoc = await FirebaseFirestore.instance
          .collection('schools')
          .doc(widget.schoolId)
          .collection('teachers')
          .doc(widget.teacherId)
          .get();

      if (schoolData != null) {
        _schoolName = schoolData['namaSekolah'] ?? 'Sekolah';
        if (schoolData['semester'] != null) {
          _activeSemester = schoolData['semester'] as String;
        }
        if (schoolData['tahunAjaran'] != null) {
          _tahunAjaran = schoolData['tahunAjaran'] as String;
        }
        final temp = schoolData['grade_templates'] as Map<String, dynamic>? ?? {};
        _gradeTemplates = {};
        temp.forEach((k, v) {
          _gradeTemplates[k] = (v as num).toInt();
        });
      }
      if (teacherDoc.exists) {
        _teacherName = teacherDoc.data()?['nama'] ?? 'Wali Kelas';
      }

      // 2. Ambil absensi auto-hitung dari system & data rapor tersimpan jika ada menggunakan semester aktif
      final results = await Future.wait([
        _raporService.calculateAttendanceStats(
          schoolId: widget.schoolId,
          studentId: widget.studentId,
          tahunAjaran: _tahunAjaran,
          semester: _activeSemester,
        ),
        _raporService.getStudentReport(
          schoolId: widget.schoolId,
          studentId: widget.studentId,
          tahunAjaran: _tahunAjaran,
          semester: _activeSemester,
        ),
      ]);
      
      final calculatedAbs = results[0] as Map<String, int>;
      final reportDoc = results[1] as DocumentSnapshot<Map<String, dynamic>>;

      if (mounted) {
        setState(() {
          // Isi default absensi dari kalkulasi sistem
          _sakitController.text = calculatedAbs['sakit'].toString();
          _izinController.text = calculatedAbs['izin'].toString();
          _alpaController.text = calculatedAbs['alpa'].toString();

          // Jika data rapor sudah pernah disimpan sebelumnya, timpa isian form
          if (reportDoc.exists) {
            final data = reportDoc.data()!;
            final List<dynamic>? savedAspects = data['attitudeAspects'] as List<dynamic>?;
            if (savedAspects != null && savedAspects.isNotEmpty) {
              _attitudeAspects = savedAspects.map((aspect) {
                final m = aspect as Map<String, dynamic>;
                return AttitudeAspectItem(
                  name: m['name']?.toString() ?? '',
                  desc: m['deskripsi']?.toString() ?? '',
                  predikat: m['predikat']?.toString() ?? 'B',
                );
              }).toList();
            } else {
              // Backward compatibility / Fallback
              final spiritualPred = data['sikapSpiritualPredikat'] ?? 'B';
              final spiritualDesc = data['sikapSpiritualDeskripsi'] ?? '';
              final sosialPred = data['sikapSosialPredikat'] ?? 'B';
              final sosialDesc = data['sikapSosialDeskripsi'] ?? '';

              _attitudeAspects = [
                AttitudeAspectItem(name: 'Spiritual', desc: spiritualDesc, predikat: spiritualPred),
                AttitudeAspectItem(name: 'Sosial', desc: sosialDesc, predikat: sosialPred),
              ];
            }
            _sakitController.text = (data['sakit'] ?? calculatedAbs['sakit']).toString();
            _izinController.text = (data['izin'] ?? calculatedAbs['izin']).toString();
            _alpaController.text = (data['alpa'] ?? calculatedAbs['alpa']).toString();
            _catatanController.text = data['catatanWali'] ?? '';
          } else {
            // New report, populate default aspects
            _attitudeAspects = [
              AttitudeAspectItem(name: 'Spiritual', desc: '', predikat: 'B'),
              AttitudeAspectItem(name: 'Sosial', desc: '', predikat: 'B'),
            ];
          }

          _isLoadingReportData = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading rapor data: $e');
      if (mounted) {
        setState(() {
          _isLoadingReportData = false;
        });
      }
    }
  }

  Future<void> _saveReport() async {
    setState(() {
      _isSaving = true;
    });

    try {
      final int sakit = int.tryParse(_sakitController.text) ?? 0;
      final int izin = int.tryParse(_izinController.text) ?? 0;
      final int alpa = int.tryParse(_alpaController.text) ?? 0;

      final serializedAspects = _attitudeAspects.map((e) => e.toMap()).toList();

      await _raporService.saveStudentReport(
        schoolId: widget.schoolId,
        studentId: widget.studentId,
        tahunAjaran: _tahunAjaran,
        semester: _activeSemester,
        attitudeAspects: serializedAspects,
        sakit: sakit,
        izin: izin,
        alpa: alpa,
        catatanWali: _catatanController.text.trim(),
        updatedBy: _teacherName,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('E-Rapor berhasil disimpan!'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menyimpan rapor: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  /// Memuat nilai akademik dan mencetak Rapor PDF
  Future<void> _printRapor(List<QueryDocumentSnapshot<Map<String, dynamic>>> gradeDocs) async {
    // 1. Ambil list mata pelajaran dari sekolah
    final subjectsSnapshot = await FirebaseFirestore.instance
        .collection('schools')
        .doc(widget.schoolId)
        .collection('subjects')
        .get();

    final Map<String, String> subjectIdToName = {};
    final Map<String, int> subjectIdToKkm = {};
    for (final sDoc in subjectsSnapshot.docs) {
      final data = sDoc.data();
      final id = data['subjectId']?.toString() ?? sDoc.id;
      final name = data['namaMapel']?.toString() ?? 'Mapel';
      final kkmVal = data['kkm'] is int ? data['kkm'] as int : (int.tryParse(data['kkm']?.toString() ?? '75') ?? 75);
      subjectIdToName[id] = name;
      subjectIdToKkm[id] = kkmVal;
    }

    // 2. Ambil bobot mapel
    final weightsSnapshot = await FirebaseFirestore.instance
        .collection('schools')
        .doc(widget.schoolId)
        .collection('subject_weights')
        .where('classId', isEqualTo: widget.classId)
        .where('tahunAjaran', isEqualTo: _tahunAjaran)
        .where('semester', isEqualTo: _activeSemester)
        .get();

    final Map<String, Map<String, double>> subjectWeightsMap = {};
    for (final wDoc in weightsSnapshot.docs) {
      final data = wDoc.data();
      final subjectId = data['subjectId']?.toString() ?? '';
      final weightsData = data['weights'] as Map<String, dynamic>?;
      if (subjectId.isNotEmpty && weightsData != null) {
        final Map<String, double> parsed = {};
        weightsData.forEach((k, v) {
          parsed[k] = (v as num).toDouble();
        });
        subjectWeightsMap[subjectId] = parsed;
      }
    }

    // 3. Kelompokkan nilai per mapel dan kategori
    final Map<String, Map<String, List<Map<String, dynamic>>>> subjectCategoryGrades = {};
    for (final gDoc in gradeDocs) {
      final data = gDoc.data();
      final subjectId = data['subjectId']?.toString() ?? '';
      final category = data['category']?.toString() ?? 'Tugas';
      final scores = data['scores'] as Map<String, dynamic>? ?? {};

      if (subjectId.isEmpty) continue;

      subjectCategoryGrades.putIfAbsent(subjectId, () => {});
      subjectCategoryGrades[subjectId]!.putIfAbsent(category, () => []);

      subjectCategoryGrades[subjectId]![category]!.add({
        widget.studentId: scores[widget.studentId],
      });
    }

    // 4. Hitung nilai akhir per mapel untuk siswa ini
    final List<Map<String, dynamic>> subjectScores = [];
    final descMap = await _gradeService.getSubjectDescriptions(
      schoolId: widget.schoolId,
      studentId: widget.studentId,
      tahunAjaran: _tahunAjaran,
      semester: _activeSemester,
    );

    subjectIdToName.forEach((subjectId, subjectName) {
      final catGrades = subjectCategoryGrades[subjectId] ?? {};
      final Map<String, double> categoryAverages = {};

      catGrades.forEach((category, listScores) {
        double sum = 0.0;
        int count = 0;
        for (final scores in listScores) {
          final detail = scores[widget.studentId];
          if (detail != null && detail is Map) {
            final scoreVal = (detail['score'] ?? 0.0) as num;
            sum += scoreVal.toDouble();
            count++;
          }
        }
        if (count > 0) {
          categoryAverages[category] = sum / count;
        }
      });

      // Ambil bobot aktif
      final weights = subjectWeightsMap[subjectId] ?? {
        'Tugas': 20.0,
        'Kuis': 20.0,
        'Ulangan Harian': 20.0,
        'UTS': 20.0,
        'UAS': 20.0,
      };

      double weightedSum = 0.0;
      double activeWeightSum = 0.0;
      categoryAverages.forEach((category, avg) {
        final w = weights[category] ?? 20.0;
        weightedSum += avg * w;
        activeWeightSum += w;
      });

      final double finalScore = activeWeightSum > 0 ? weightedSum / activeWeightSum : 0.0;

      // Masukkan ke data cetak dengan KKM dinamis
      subjectScores.add({
        'name': subjectName,
        'kkm': (subjectIdToKkm[subjectId] ?? 75).toString(),
        'score': finalScore,
        'deskripsi': descMap[subjectId] ?? '',
      });
    });

    // Urutkan mapel agar alfabetis
    subjectScores.sort((a, b) => a['name'].toString().compareTo(b['name'].toString()));

    // 5. Kirim data ke helper cetak PDF
    await RaporPdfHelper.generateAndShowRaporPdf(
      schoolName: _schoolName,
      className: widget.className,
      teacherName: _teacherName,
      studentName: widget.studentName,
      studentNis: widget.studentNis,
      semester: _activeSemester,
      yearInfo: _tahunAjaran,
      subjectScores: subjectScores,
      attitudeAspects: _attitudeAspects.map((e) => e.toMap()).toList(),
      sakit: int.tryParse(_sakitController.text) ?? 0,
      izin: int.tryParse(_izinController.text) ?? 0,
      alpa: int.tryParse(_alpaController.text) ?? 0,
      catatanWali: _catatanController.text,
      gradeTemplates: _gradeTemplates,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: AuthBackground.isDarkMode,
      builder: (context, isDark, _) {
        final titleColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
        final subTextColor = isDark ? Colors.white.withValues(alpha: 0.5) : const Color(0xFF1E1B4B).withValues(alpha: 0.6);
        final cardBgColor = isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white;
        final cardBorderColor = isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.08);
        final iconBgColor = isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05);
        final iconColor = isDark ? Colors.white : const Color(0xFF1E1B4B);

        return Scaffold(
          body: AuthBackground(
            child: _isLoadingReportData
                ? Center(
                    child: CircularProgressIndicator(
                      color: isDark ? Colors.white : const Color(0xFF8B5CF6),
                    ),
                  )
                : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: _gradeService.getGradesByClass(
                      schoolId: widget.schoolId, 
                      classId: widget.classId,
                      tahunAjaran: _tahunAjaran,
                      semester: _activeSemester,
                    ),
                    builder: (context, gradeSnap) {
                      final gradeDocs = gradeSnap.data?.docs ?? [];

                      return CustomScrollView(
                        physics: const BouncingScrollPhysics(),
                        slivers: [
                          // AppBar
                          SliverAppBar(
                            backgroundColor: Colors.transparent,
                            elevation: 0,
                            pinned: true,
                            iconTheme: IconThemeData(color: iconColor),
                            leading: Container(
                              margin: const EdgeInsets.only(left: 16),
                              decoration: BoxDecoration(
                                color: iconBgColor,
                                shape: BoxShape.circle,
                              ),
                              child: IconButton(
                                icon: Icon(Icons.arrow_back_ios_new_rounded, color: iconColor, size: 18),
                                onPressed: () => Navigator.pop(context),
                              ),
                            ),
                            title: Text(
                              'Pengisian E-Rapor',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: titleColor),
                            ),
                            actions: [
                              Padding(
                                padding: const EdgeInsets.only(right: 16),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: iconBgColor,
                                    shape: BoxShape.circle,
                                  ),
                                  child: IconButton(
                                    icon: const Icon(Icons.print_rounded, color: Color(0xFF8B5CF6), size: 20),
                                    onPressed: () => _printRapor(gradeDocs),
                                    tooltip: 'Cetak PDF Rapor',
                                  ),
                                ),
                              ),
                            ],
                          ),

                          // Header Profil Murid
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              child: Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: cardBgColor,
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(color: cardBorderColor),
                                ),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 28,
                                      backgroundColor: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                                      child: Icon(Icons.person_rounded, color: isDark ? Colors.white : const Color(0xFF8B5CF6), size: 28),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            widget.studentName,
                                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: titleColor),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'NIS: ${widget.studentNis} • Kelas: ${widget.className}',
                                            style: TextStyle(fontSize: 13, color: subTextColor),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          // Form Konten Input E-Rapor
                          SliverPadding(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                            sliver: SliverList(
                              delegate: SliverChildListDelegate([
                                // 1. Penilaian Sikap
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    _buildSectionHeader('1. Penilaian Sikap', titleColor),
                                    TextButton.icon(
                                      onPressed: () {
                                        setState(() {
                                          _attitudeAspects.add(
                                            AttitudeAspectItem(
                                              name: '',
                                              desc: '',
                                              predikat: 'B',
                                            ),
                                          );
                                        });
                                      },
                                      icon: const Icon(Icons.add_circle_outline_rounded, size: 20, color: Color(0xFF8B5CF6)),
                                      label: const Text(
                                        'Tambah Aspek',
                                        style: TextStyle(color: Color(0xFF8B5CF6), fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                ...List.generate(_attitudeAspects.length, (index) {
                                  final item = _attitudeAspects[index];
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 16),
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: cardBgColor,
                                      borderRadius: BorderRadius.circular(24),
                                      border: Border.all(color: cardBorderColor),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: TextField(
                                                controller: item.nameController,
                                                style: TextStyle(color: titleColor, fontWeight: FontWeight.bold),
                                                decoration: InputDecoration(
                                                  hintText: 'Nama Aspek Sikap (misal: Spiritual, Sosial, Kedisiplinan)',
                                                  hintStyle: TextStyle(color: subTextColor, fontSize: 13),
                                                  labelText: 'Nama Aspek #${index + 1}',
                                                  labelStyle: TextStyle(color: titleColor.withValues(alpha: 0.6), fontSize: 13),
                                                  filled: true,
                                                  fillColor: isDark ? Colors.white.withValues(alpha: 0.02) : Colors.black.withValues(alpha: 0.01),
                                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: cardBorderColor)),
                                                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: cardBorderColor)),
                                                  focusedBorder: OutlineInputBorder(
                                                    borderRadius: BorderRadius.circular(16),
                                                    borderSide: BorderSide(color: isDark ? Colors.white.withValues(alpha: 0.3) : const Color(0xFF8B5CF6)),
                                                  ),
                                                ),
                                              ),
                                            ),
                                            if (_attitudeAspects.length > 1) ...[
                                              const SizedBox(width: 8),
                                              Container(
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                                                  shape: BoxShape.circle,
                                                ),
                                                child: IconButton(
                                                  icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444)),
                                                  onPressed: () {
                                                    setState(() {
                                                      item.dispose();
                                                      _attitudeAspects.removeAt(index);
                                                    });
                                                  },
                                                  tooltip: 'Hapus Aspek',
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        _buildPredikatDropdown(
                                          value: item.predikat,
                                          onChanged: (val) => setState(() => item.predikat = val!),
                                          isDark: isDark,
                                          cardBg: isDark ? Colors.white.withValues(alpha: 0.02) : Colors.black.withValues(alpha: 0.01),
                                          border: cardBorderColor,
                                          textColor: titleColor,
                                        ),
                                        const SizedBox(height: 12),
                                        _buildDescriptionTextField(
                                          controller: item.descController,
                                          hint: 'Deskripsikan sikap tersebut untuk siswa...',
                                          isDark: isDark,
                                          cardBg: isDark ? Colors.white.withValues(alpha: 0.02) : Colors.black.withValues(alpha: 0.01),
                                          border: cardBorderColor,
                                          textColor: titleColor,
                                          subText: subTextColor,
                                        ),
                                      ],
                                    ),
                                  );
                                }),

                                const SizedBox(height: 24),

                                // 3. Ketidakhadiran (Absensi)
                                _buildSectionHeader('3. Ketidakhadiran (Absensi)', titleColor),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildNumberInputField(
                                        controller: _sakitController,
                                        label: 'Sakit (Hari)',
                                        isDark: isDark,
                                        cardBg: cardBgColor,
                                        border: cardBorderColor,
                                        textColor: titleColor,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _buildNumberInputField(
                                        controller: _izinController,
                                        label: 'Izin (Hari)',
                                        isDark: isDark,
                                        cardBg: cardBgColor,
                                        border: cardBorderColor,
                                        textColor: titleColor,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _buildNumberInputField(
                                        controller: _alpaController,
                                        label: 'Alpa (Hari)',
                                        isDark: isDark,
                                        cardBg: cardBgColor,
                                        border: cardBorderColor,
                                        textColor: titleColor,
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 24),

                                // 4. Catatan Wali Kelas
                                _buildSectionHeader('4. Catatan Wali Kelas', titleColor),
                                const SizedBox(height: 12),
                                _buildDescriptionTextField(
                                  controller: _catatanController,
                                  hint: 'Berikan motivasi atau catatan saran bagi perkembangan siswa ke depan...',
                                  isDark: isDark,
                                  cardBg: cardBgColor,
                                  border: cardBorderColor,
                                  textColor: titleColor,
                                  subText: subTextColor,
                                  maxLines: 4,
                                ),

                                const SizedBox(height: 32),

                                // Tombol Simpan Rapor
                                SizedBox(
                                  width: double.infinity,
                                  height: 54,
                                  child: ElevatedButton(
                                    onPressed: _isSaving ? null : _saveReport,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF8B5CF6),
                                      foregroundColor: Colors.white,
                                      disabledBackgroundColor: const Color(0xFF8B5CF6).withValues(alpha: 0.5),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                    ),
                                    child: _isSaving
                                        ? const CircularProgressIndicator(color: Colors.white)
                                        : const Text(
                                            'Simpan E-Rapor',
                                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                          ),
                                  ),
                                ),
                                const SizedBox(height: 48),
                              ]),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(String title, Color textColor) {
    return Text(
      title,
      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor),
    );
  }

  Widget _buildPredikatDropdown({
    required String value,
    required ValueChanged<String?> onChanged,
    required bool isDark,
    required Color cardBg,
    required Color border,
    required Color textColor,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      dropdownColor: isDark ? const Color(0xFF0F0C20) : Colors.white,
      style: TextStyle(color: textColor),
      decoration: InputDecoration(
        labelText: 'Predikat Sikap',
        labelStyle: TextStyle(color: textColor.withValues(alpha: 0.6)),
        filled: true,
        fillColor: cardBg,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: border)),
      ),
      items: ['A+', 'A', 'A-', 'B+', 'B', 'B-', 'C+', 'C', 'C-', 'D'].map((p) {
        return DropdownMenuItem<String>(
          value: p,
          child: Text('Predikat $p'),
        );
      }).toList(),
      onChanged: onChanged,
    );
  }

  Widget _buildDescriptionTextField({
    required TextEditingController controller,
    required String hint,
    required bool isDark,
    required Color cardBg,
    required Color border,
    required Color textColor,
    required Color subText,
    int maxLines = 3,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: TextStyle(color: textColor),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: subText, fontSize: 13),
        filled: true,
        fillColor: cardBg,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: border)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: isDark ? Colors.white.withValues(alpha: 0.3) : const Color(0xFF8B5CF6)),
        ),
      ),
    );
  }

  Widget _buildNumberInputField({
    required TextEditingController controller,
    required String label,
    required bool isDark,
    required Color cardBg,
    required Color border,
    required Color textColor,
  }) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      style: TextStyle(color: textColor),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: textColor.withValues(alpha: 0.6), fontSize: 13),
        filled: true,
        fillColor: cardBg,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: border)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: isDark ? Colors.white.withValues(alpha: 0.3) : const Color(0xFF8B5CF6)),
        ),
      ),
    );
  }
}
