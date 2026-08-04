import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart' hide Border, TextSpan;
import 'package:file_picker/file_picker.dart' as fp;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:sys_mng_school/core/localization/app_localization.dart';
import 'package:sys_mng_school/features/exams/services/exam_session_service.dart';
import '../../../core/services/session_service.dart';
import '../../authentication/widgets/auth_background.dart';
import '../models/exam_model.dart';

class TeacherExamQuestionsPage extends StatefulWidget {
  final String eventId;
  final String subjectId;
  final String subjectName;
  final String teacherId;
  final String? gradeLevel;

  const TeacherExamQuestionsPage({
    super.key,
    required this.eventId,
    required this.subjectId,
    required this.subjectName,
    required this.teacherId,
    this.gradeLevel,
  });

  @override
  State<TeacherExamQuestionsPage> createState() => _TeacherExamQuestionsPageState();
}

class _TeacherExamQuestionsPageState extends State<TeacherExamQuestionsPage> {
  final _db = FirebaseFirestore.instance;
  bool _isLoading = true;
  int _durationMinutes = 90;
  List<ExamQuestion> _questions = [];
  bool _hasUnsavedChanges = false;
  bool _shufflePg = false;
  bool _shuffleEssay = false;

  int get _totalPoints {
    return _questions.fold(0, (sum, q) => sum + q.points);
  }

  // Lock state: true saat jam ujian sudah tiba atau sedang berlangsung
  bool _isExamLocked = false;
  String? _lockedSessionInfo; // Pesan info sesi yang sedang berlangsung

  final List<String> _availableGrades = [];
  late String _selectedGrade;
  Map<String, String> _classIdToAngkatan = {};

  @override
  void initState() {
    super.initState();
    _selectedGrade = widget.gradeLevel ?? '';
    _loadAvailableGradesAndData();
  }

  Future<void> _loadAvailableGradesAndData() async {
    final schoolId = SessionService.currentUser!.schoolId;
    try {
      // 1. Fetch active students to build classId -> angkatan mapping and list all active cohorts
      final studentsSnap = await _db
          .collection('schools')
          .doc(schoolId)
          .collection('students')
          .get();

      final Set<String> allActiveAngkatans = {};
      final Map<String, Map<String, int>> classAngkatanCounts = {};
      for (final doc in studentsSnap.docs) {
        final data = doc.data();
        final cid = data['classId'] as String? ?? '';
        final angkatan = (data['angkatan'] ?? '').toString().trim();
        final isLulus = data['lulus'] == true;
        final isAktif = data['aktif'] ?? true;
        if (angkatan.isNotEmpty && !isLulus && isAktif) {
          allActiveAngkatans.add(angkatan);
        }
        if (cid.isNotEmpty && angkatan.isNotEmpty && !isLulus && isAktif) {
          classAngkatanCounts.putIfAbsent(cid, () => {});
          classAngkatanCounts[cid]![angkatan] = (classAngkatanCounts[cid]![angkatan] ?? 0) + 1;
        }
      }

      final Map<String, String> mapping = {};
      classAngkatanCounts.forEach((cid, counts) {
        if (counts.isNotEmpty) {
          mapping[cid] = counts.entries.reduce((a, b) => a.value > b.value ? a : b).key;
        }
      });
      _classIdToAngkatan = mapping;

      setState(() {
        _availableGrades.clear();
        _availableGrades.addAll(allActiveAngkatans.toList()..sort());
        
        // Fallback jika tidak ada angkatan terdeteksi
        if (_availableGrades.isEmpty) {
          _availableGrades.addAll(['2020', '2021', '2022']);
        }

        if (_selectedGrade.isEmpty || !_availableGrades.contains(_selectedGrade)) {
          _selectedGrade = _availableGrades.contains(widget.gradeLevel) 
              ? widget.gradeLevel! 
              : _availableGrades.first;
        }
      });
    } catch (_) {
      setState(() {
        _availableGrades.clear();
        _availableGrades.addAll(['2020', '2021', '2022']);
      });
    }
    await _loadQuestionsData();
    await _checkExamLock();
  }

  Future<void> _changeGrade(String newGrade) async {
    if (_selectedGrade == newGrade) return;
    if (_hasUnsavedChanges) {
      final confirm = await _showDiscardConfirmation();
      if (confirm != true) return;
    }
    setState(() {
      _selectedGrade = newGrade;
      _isLoading = true;
      _questions.clear();
      _hasUnsavedChanges = false;
    });
    await _loadQuestionsData();
    await _checkExamLock();
  }

  Future<bool> _showDiscardConfirmation() async {
    final isDark = AuthBackground.isDarkMode.value;
    final titleColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
    final res = await Get.dialog<bool>(
      AlertDialog(
        backgroundColor: isDark ? const Color(0xFF0F0C20) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Color(0xFFF59E0B), size: 22),
            const SizedBox(width: 8),
            Text(AppLocalization.isIndonesian ? 'Buang Perubahan?' : 'Discard Changes?', style: TextStyle(color: titleColor, fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Text(
          AppLocalization.isIndonesian
              ? 'Anda memiliki perubahan soal yang belum disimpan untuk Angkatan $_selectedGrade. Apakah Anda yakin ingin membuang perubahan tersebut?'
              : 'You have unsaved question changes for Cohort $_selectedGrade. Are you sure you want to discard these changes?',
          style: TextStyle(color: titleColor.withValues(alpha: 0.8), height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: Text(AppLocalization.cancel, style: const TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Get.back(result: true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(AppLocalization.isIndonesian ? 'Buang' : 'Discard', style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    return res ?? false;
  }

  /// Mengecek apakah sudah ada sesi ujian mapel ini yang waktunya sudah tiba,
  /// ATAU event sudah diaktifkan (examStatus == 'Active').
  /// Jika ya, lock semua aksi edit.
  Future<void> _checkExamLock() async {
    final schoolId = SessionService.currentUser!.schoolId;
    setState(() {
      _isExamLocked = false;
      _lockedSessionInfo = null;
    });
    try {
      // ── Cek 1: status event. Jika sudah Active, langsung lock. ──────────
      final eventDoc = await _db
          .collection('schools')
          .doc(schoolId)
          .collection('exam_events')
          .doc(widget.eventId)
          .get();

      if (eventDoc.exists) {
        final eventStatus = (eventDoc.data()?['examStatus'] ?? '').toString();
        if (eventStatus == 'Active' || eventStatus == 'Finished') {
          setState(() {
            _isExamLocked = true;
            _lockedSessionInfo = AppLocalization.isIndonesian
                ? 'Event ujian sudah diaktifkan. Soal tidak dapat diubah selama event berlangsung.'
                : 'Exam event is already active. Questions cannot be modified during the event.';
          });
          return;
        }
      }

      // ── Cek 2: waktu sesi sudah tiba ────────────────────────────────────
      final snapshot = await _db
          .collection('schools')
          .doc(schoolId)
          .collection('exam_sessions')
          .where('eventId', isEqualTo: widget.eventId)
          .where('subjectId', isEqualTo: widget.subjectId)
          .get();

      if (snapshot.docs.isEmpty) return;

      final now = DateTime.now();
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final classId = data['classId']?.toString() ?? '';
        final sessionAngkatan = _classIdToAngkatan[classId] ?? '';

        // Skip if this session is not for the currently selected grade level
        if (sessionAngkatan != _selectedGrade) continue;

        final dateStr = data['date']?.toString() ?? '';
        final startTimeStr = data['startTime']?.toString() ?? '';
        if (dateStr.isEmpty || startTimeStr.isEmpty) continue;

        try {
          final parts = startTimeStr.split(':');
          final date = DateTime.tryParse(dateStr);
          if (date == null || parts.length < 2) continue;

          final sessionStart = DateTime(
            date.year,
            date.month,
            date.day,
            int.parse(parts[0]),
            int.parse(parts[1]),
          );

          if (!now.isBefore(sessionStart)) {
            // Waktu ujian sudah tiba atau sudah lewat — kunci editing
            final roomName = data['roomName']?.toString() ?? 'Ruangan Tidak Diketahui';
            final classInfo = data['className']?.toString() ?? 'Kelas Tidak Diketahui';
            setState(() {
              _isExamLocked = true;
              _lockedSessionInfo = AppLocalization.isIndonesian
                  ? 'Ujian $classInfo di $roomName dimulai pukul $startTimeStr. Soal tidak dapat diubah.'
                  : 'Exam $classInfo in $roomName starts at $startTimeStr. Questions cannot be modified.';
            });
            return; // Cukup satu sesi yang sudah mulai
          }
        } catch (_) {
          continue;
        }
      }
    } catch (e) {
      // Jika gagal cek, biarkan halaman tetap bisa diedit (fail-open)
    }
  }

  Future<void> _loadQuestionsData() async {
    final schoolId = SessionService.currentUser!.schoolId;
    final docId = '${widget.eventId}_${widget.subjectId}_$_selectedGrade';

    try {
      final doc = await _db
          .collection('schools')
          .doc(schoolId)
          .collection('exam_questions')
          .doc(docId)
          .get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        _durationMinutes = data['durationMinutes'] ?? 90;
        _shufflePg = data['shufflePg'] as bool? ?? false;
        _shuffleEssay = data['shuffleEssay'] as bool? ?? false;
        final qList = (data['questions'] as List? ?? [])
            .map((q) => ExamQuestion.fromMap(Map<String, dynamic>.from(q)))
            .toList();
        setState(() {
          _questions = qList;
          _isLoading = false;
        });
      } else {
        setState(() {
          _shufflePg = false;
          _shuffleEssay = false;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
      Get.snackbar(AppLocalization.isIndonesian ? 'Error' : 'Error', AppLocalization.isIndonesian ? 'Gagal memuat soal: $e' : 'Failed to load questions: $e',
          backgroundColor: Colors.redAccent, colorText: Colors.white);
    }
  }

  Future<void> _saveData() async {
    final schoolId = SessionService.currentUser!.schoolId;
    final docId = '${widget.eventId}_${widget.subjectId}_$_selectedGrade';

    Get.dialog(
      const Center(child: CircularProgressIndicator(color: Color(0xFF8B5CF6))),
      barrierDismissible: false,
    );

    try {
      final qListMap = _questions.map((q) => q.toMap()).toList();
      await _db
          .collection('schools')
          .doc(schoolId)
          .collection('exam_questions')
          .doc(docId)
          .set({
        'eventId': widget.eventId,
        'subjectId': widget.subjectId,
        'subjectName': widget.subjectName,
        'authorTeacherId': widget.teacherId,
        'durationMinutes': _durationMinutes,
        'shufflePg': _shufflePg,
        'shuffleEssay': _shuffleEssay,
        'questions': qListMap,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Sinkronkan ke koleksi /exams untuk murid
      final sessionService = ExamSessionService();
      await sessionService.syncQuestionsToExams(
        schoolId: schoolId,
        eventId: widget.eventId,
        subjectId: widget.subjectId,
        questionsList: qListMap,
        gradeLevel: _selectedGrade,
        shufflePg: _shufflePg,
        shuffleEssay: _shuffleEssay,
      );

      Get.back(); // Close loading dialog
      Get.snackbar(AppLocalization.isIndonesian ? 'Sukses' : 'Success', AppLocalization.isIndonesian ? 'Bank soal berhasil disimpan!' : 'Question bank successfully saved!',
          backgroundColor: const Color(0xFF10B981), colorText: Colors.white);
      setState(() => _hasUnsavedChanges = false);
    } catch (e) {
      Get.back(); // Close loading dialog
      Get.snackbar(AppLocalization.isIndonesian ? 'Error' : 'Error', AppLocalization.isIndonesian ? 'Gagal menyimpan soal: $e' : 'Failed to save questions: $e',
          backgroundColor: Colors.redAccent, colorText: Colors.white);
    }
  }

  void _addOrEditQuestion({ExamQuestion? existing, int? index}) {
    final isEdit = existing != null;
    final textCtrl = TextEditingController(text: existing?.questionText ?? '');
    final pointsCtrl = TextEditingController(text: (existing?.points ?? 10).toString());
    final typeObs = (existing?.type ?? 'multiple_choice').obs;
    final correctOptObs = (existing?.correctOptionIndex ?? 0).obs;
    final optionsCtrls = <TextEditingController>[].obs;
    if (existing != null && existing.type == 'multiple_choice') {
      optionsCtrls.addAll(
        existing.options.map((opt) => TextEditingController(text: opt)),
      );
    } else {
      optionsCtrls.addAll(
        List.generate(4, (_) => TextEditingController()),
      );
    }

    Get.bottomSheet(
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      ValueListenableBuilder<bool>(
        valueListenable: AuthBackground.isDarkMode,
        builder: (context, isDark, _) {
          final titleColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
          final sheetBg = isDark ? const Color(0xFF1A1730) : Colors.white;
          final border = isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06);

          return DraggableScrollableSheet(
            initialChildSize: 0.85,
            maxChildSize: 0.95,
            builder: (_, scrollController) => Container(
              decoration: BoxDecoration(
                color: sheetBg,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.all(24),
              child: ListView(
                controller: scrollController,
                children: [
                  Text(
                      isEdit
                          ? (AppLocalization.isIndonesian ? 'Edit Pertanyaan' : 'Edit Question')
                          : (AppLocalization.isIndonesian ? 'Tambah Pertanyaan' : 'Add Question'),
                      style: TextStyle(
                          color: titleColor,
                          fontSize: 18,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),

                  // Tipe Pertanyaan
                  Text(AppLocalization.isIndonesian ? 'Tipe Pertanyaan' : 'Question Type',
                      style: TextStyle(
                          color: titleColor.withValues(alpha: 0.6),
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Obx(() => DropdownButtonFormField<String>(
                        value: typeObs.value,
                        dropdownColor: isDark ? const Color(0xFF1A1730) : Colors.white,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.02),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: border)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: border)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: const Color(0xFF8B5CF6))),
                        ),
                        style: TextStyle(color: titleColor, fontSize: 13),
                        items: [
                          DropdownMenuItem(value: 'multiple_choice', child: Text(AppLocalization.isIndonesian ? 'Pilihan Ganda' : 'Multiple Choice')),
                          DropdownMenuItem(value: 'essay', child: Text(AppLocalization.isIndonesian ? 'Essay' : 'Essay')),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            typeObs.value = val;
                          }
                        },
                      )),
                  const SizedBox(height: 16),

                  // Teks Pertanyaan
                  Text(AppLocalization.isIndonesian ? 'Pertanyaan' : 'Question',
                      style: TextStyle(
                          color: titleColor.withOpacity(0.6),
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: textCtrl,
                    maxLines: 3,
                    style: TextStyle(color: titleColor),
                    decoration: InputDecoration(
                      hintText: AppLocalization.isIndonesian ? 'Tulis teks pertanyaan di sini...' : 'Write question text here...',
                      hintStyle: TextStyle(color: titleColor.withOpacity(0.4)),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Opsi Pilihan Ganda (Hanya jika tipe MC)
                  Obx(() {
                    if (typeObs.value != 'multiple_choice') {
                      return const SizedBox.shrink();
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(AppLocalization.isIndonesian ? 'Pilihan Jawaban' : 'Answer Options',
                                style: TextStyle(
                                    color: titleColor.withOpacity(0.6),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600)),
                            TextButton.icon(
                              onPressed: () {
                                if (optionsCtrls.length < 10) {
                                  optionsCtrls.add(TextEditingController());
                                } else {
                                  Get.snackbar(
                                      AppLocalization.isIndonesian ? 'Batas Maksimal' : 'Max Limit',
                                      AppLocalization.isIndonesian ? 'Maksimal 10 pilihan jawaban' : 'Maximum 10 answer options');
                                }
                              },
                              icon: const Icon(Icons.add, size: 16, color: Color(0xFF8B5CF6)),
                              label: Text(AppLocalization.isIndonesian ? 'Tambah Opsi' : 'Add Option',
                                  style: const TextStyle(color: Color(0xFF8B5CF6), fontSize: 12)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ...List.generate(optionsCtrls.length, (optIdx) {
                          final char = String.fromCharCode(65 + optIdx); // A, B, C, D, E...
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: Row(
                              children: [
                                Radio<int>(
                                  value: optIdx,
                                  groupValue: correctOptObs.value,
                                  onChanged: (val) {
                                    if (val != null) correctOptObs.value = val;
                                  },
                                ),
                                Expanded(
                                  child: TextFormField(
                                    controller: optionsCtrls[optIdx],
                                    style: TextStyle(color: titleColor),
                                    decoration: InputDecoration(
                                      hintText: '${AppLocalization.isIndonesian ? 'Opsi' : 'Option'} $char',
                                      hintStyle: TextStyle(color: titleColor.withOpacity(0.4)),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                  ),
                                ),
                                if (optionsCtrls.length > 2)
                                  IconButton(
                                    icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent, size: 20),
                                    onPressed: () {
                                      optionsCtrls.removeAt(optIdx);
                                      if (correctOptObs.value >= optionsCtrls.length) {
                                        correctOptObs.value = optionsCtrls.length - 1;
                                      }
                                    },
                                  ),
                              ],
                            ),
                          );
                        }),
                        const SizedBox(height: 16),
                      ],
                    );
                  }),

                  // Bobot Poin (Untuk Pilihan Ganda & Essay)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Obx(() {
                        final isEssay = typeObs.value == 'essay';
                        return Text(isEssay ? (AppLocalization.isIndonesian ? 'Skor Maksimal' : 'Maximum Score') : (AppLocalization.isIndonesian ? 'Bobot Nilai (Poin)' : 'Question Points'),
                            style: TextStyle(
                                color: titleColor.withValues(alpha: 0.6),
                                fontSize: 12,
                                fontWeight: FontWeight.w600));
                      }),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: pointsCtrl,
                        keyboardType: TextInputType.number,
                        style: TextStyle(color: titleColor),
                        decoration: InputDecoration(
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),

                  // Button Simpan Pertanyaan
                  ElevatedButton(
                    onPressed: () {
                      if (textCtrl.text.trim().isEmpty) {
                        Get.snackbar(AppLocalization.isIndonesian ? 'Error' : 'Error', AppLocalization.isIndonesian ? 'Teks pertanyaan tidak boleh kosong' : 'Question text cannot be empty');
                        return;
                      }

                      final type = typeObs.value;
                      final points = int.tryParse(pointsCtrl.text) ?? 10;
                      final List<String> options = [];

                      if (type == 'multiple_choice') {
                        for (final c in optionsCtrls) {
                          if (c.text.trim().isEmpty) {
                            Get.snackbar(AppLocalization.isIndonesian ? 'Error' : 'Error', AppLocalization.isIndonesian ? 'Semua opsi pilihan harus diisi' : 'All answer options must be filled');
                            return;
                          }
                          options.add(c.text.trim());
                        }
                      }

                      final currentTeacherName = SessionService.currentUser?.nama ?? 'Guru';
                      final newQ = ExamQuestion(
                        id: existing?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
                        questionText: textCtrl.text.trim(),
                        options: options,
                        correctOptionIndex: type == 'multiple_choice' ? correctOptObs.value : 0,
                        type: type,
                        points: points,
                        createdByTeacherId: existing?.createdByTeacherId ?? widget.teacherId,
                        createdByTeacherName: existing?.createdByTeacherName ?? currentTeacherName,
                        updatedByTeacherId: isEdit ? widget.teacherId : null,
                        updatedByTeacherName: isEdit ? currentTeacherName : null,
                      );

                      setState(() {
                        if (isEdit && index != null) {
                          _questions[index] = newQ;
                        } else {
                          _questions.add(newQ);
                        }
                        _hasUnsavedChanges = true;
                      });

                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8B5CF6),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(isEdit ? (AppLocalization.isIndonesian ? 'Perbarui Pertanyaan' : 'Update Question') : (AppLocalization.isIndonesian ? 'Tambahkan Pertanyaan' : 'Add Question')),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// ── Unduh Template Excel Soal (PG & Essay) ─────────────────
  Future<void> _downloadExcelTemplate() async {
    try {
      final excel = Excel.createExcel();
      const sheetName = 'Template Soal';
      final sheet = excel[sheetName];
      excel.setDefaultSheet(sheetName);
      if (excel.sheets.containsKey('Sheet1')) {
        excel.delete('Sheet1');
      }

      final headerStyle = CellStyle(
        backgroundColorHex: ExcelColor.fromHexString('#8B5CF6'),
        fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
        bold: true,
        fontSize: 10,
        horizontalAlign: HorizontalAlign.Center,
        verticalAlign: VerticalAlign.Center,
      );

      final headers = [
        'No',
        'Tipe Soal',
        'Pertanyaan',
        'Bobot Poin',
        'Pilihan A',
        'Pilihan B',
        'Pilihan C',
        'Pilihan D',
        'Pilihan E',
        'Kunci Jawaban'
      ];

      sheet.appendRow(headers.map((h) => TextCellValue(h)).toList());

      for (int c = 0; c < headers.length; c++) {
        final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 0));
        cell.cellStyle = headerStyle;
      }

      // Sample Row 1: Soal PG
      sheet.appendRow([
        IntCellValue(1),
        TextCellValue('PG'),
        TextCellValue('Berapakah hasil dari 15 + 25?'),
        IntCellValue(10),
        TextCellValue('30'),
        TextCellValue('35'),
        TextCellValue('40'),
        TextCellValue('45'),
        TextCellValue('50'),
        TextCellValue('C'),
      ]);

      // Sample Row 2: Soal Essay
      sheet.appendRow([
        IntCellValue(2),
        TextCellValue('Essay'),
        TextCellValue('Jelaskan fungsi utama dari sistem kekebalan tubuh manusia!'),
        IntCellValue(20),
        TextCellValue(''),
        TextCellValue(''),
        TextCellValue(''),
        TextCellValue(''),
        TextCellValue(''),
        TextCellValue('Melindungi tubuh dari infeksi kuman dan penyakit.'),
      ]);

      // Sample Row 3: Soal PG 2
      sheet.appendRow([
        IntCellValue(3),
        TextCellValue('PG'),
        TextCellValue('Pancasila Sila Pertama berbunyi...'),
        IntCellValue(10),
        TextCellValue('Ketuhanan Yang Maha Esa'),
        TextCellValue('Kemanusiaan yang adil dan beradab'),
        TextCellValue('Persatuan Indonesia'),
        TextCellValue('Keadilan sosial bagi seluruh rakyat Indonesia'),
        TextCellValue(''),
        TextCellValue('A'),
      ]);

      sheet.setColumnWidth(0, 8);   // No
      sheet.setColumnWidth(1, 14);  // Tipe Soal
      sheet.setColumnWidth(2, 45);  // Pertanyaan
      sheet.setColumnWidth(3, 14);  // Bobot Poin
      sheet.setColumnWidth(4, 25);  // Opsi A
      sheet.setColumnWidth(5, 25);  // Opsi B
      sheet.setColumnWidth(6, 25);  // Opsi C
      sheet.setColumnWidth(7, 25);  // Opsi D
      sheet.setColumnWidth(8, 25);  // Opsi E
      sheet.setColumnWidth(9, 18);  // Kunci Jawaban

      final bytes = excel.encode();
      if (bytes == null) return;

      final uint8Bytes = Uint8List.fromList(bytes);
      await fp.FilePicker.saveFile(
        dialogTitle: AppLocalization.isIndonesian ? 'Unduh Template Excel Soal' : 'Download Exam Questions Excel Template',
        fileName: 'Template_Import_Soal_Ujian.xlsx',
        bytes: uint8Bytes,
      );

      Get.snackbar(
        AppLocalization.isIndonesian ? 'Berhasil' : 'Success',
        AppLocalization.isIndonesian
            ? 'Template Excel berhasil diunduh!'
            : 'Excel template downloaded successfully!',
        backgroundColor: const Color(0xFF10B981),
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar(
        AppLocalization.isIndonesian ? 'Error' : 'Error',
        AppLocalization.isIndonesian ? 'Gagal mengunduh template: $e' : 'Failed to download template: $e',
        backgroundColor: Colors.redAccent,
        colorText: Colors.white,
      );
    }
  }

  /// ── Impor Soal dari File Excel ──────────────────────────────
  Future<void> _importQuestionsFromExcel() async {
    try {
      final result = await fp.FilePicker.pickFiles(
        type: fp.FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      final fileBytes = result.files.first.bytes;
      if (fileBytes == null) {
        Get.snackbar(
          AppLocalization.isIndonesian ? 'Error' : 'Error',
          AppLocalization.isIndonesian ? 'Gagal membaca file Excel' : 'Failed to read Excel file',
          backgroundColor: Colors.redAccent,
          colorText: Colors.white,
        );
        return;
      }

      final excel = Excel.decodeBytes(fileBytes);
      final List<ExamQuestion> importedQuestions = [];

      String cellToString(Data? cell) {
        if (cell == null || cell.value == null) return '';
        final val = cell.value;
        if (val is TextCellValue) return val.value.toString().trim();
        if (val is IntCellValue) return val.value.toString();
        if (val is DoubleCellValue) return val.value.toString();
        if (val is BoolCellValue) return val.value.toString();
        return val.toString().trim();
      }

      for (final table in excel.tables.keys) {
        final rows = excel.tables[table]?.rows ?? [];
        if (rows.isEmpty) continue;

        int startRow = 0;
        for (int r = 0; r < rows.length; r++) {
          final row = rows[r];
          final col0 = cellToString(row.length > 0 ? row[0] : null).toUpperCase();
          final col1 = cellToString(row.length > 1 ? row[1] : null).toUpperCase();
          final col2 = cellToString(row.length > 2 ? row[2] : null).toUpperCase();

          if (col0 == 'NO' || col1.contains('TIPE') || col2.contains('PERTANYAAN')) {
            startRow = r + 1;
            break;
          }
        }

        final teacherName = SessionService.currentUser?.nama ?? 'Guru';

        for (int r = startRow; r < rows.length; r++) {
          final row = rows[r];
          if (row.isEmpty) continue;

          final tipeStr = cellToString(row.length > 1 ? row[1] : null).toUpperCase();
          final qText = cellToString(row.length > 2 ? row[2] : null);

          if (qText.isEmpty) continue;

          final pointsStr = cellToString(row.length > 3 ? row[3] : null);
          final points = int.tryParse(pointsStr) ?? 10;

          // Cari kolom Kunci Jawaban (sel non-kosong paling kanan di baris ini mulai dari kolom 4)
          String keyAnswer = '';
          int keyColIndex = row.length - 1;
          while (keyColIndex > 3) {
            final val = cellToString(row[keyColIndex]).toUpperCase();
            if (val.isNotEmpty) {
              keyAnswer = val;
              break;
            }
            keyColIndex--;
          }

          // Baca seluruh opsi dari kolom 4 hingga sebelum kolom kunci jawaban (atau max kolom 8 jika kunci jawaban ada di kolom 9)
          final List<String> rawOptions = [];
          final int maxOptCol = keyColIndex > 4 ? keyColIndex : row.length;
          for (int c = 4; c < maxOptCol; c++) {
            final opt = cellToString(row[c]);
            if (opt.isNotEmpty) {
              rawOptions.add(opt);
            }
          }

          // Identifikasi Tipe Soal:
          // 1. Cek dari kolom Tipe Soal (PG / Essay)
          // 2. Smart Fallback: Jika opsi terisi minimal 2 -> PG, jika tidak -> Essay
          bool isPg = false;
          if (tipeStr.contains('PG') || tipeStr.contains('PILIHAN') || tipeStr.contains('CHOICE') || tipeStr.contains('MC')) {
            isPg = true;
          } else if (tipeStr.contains('ESSAY') || tipeStr.contains('ESAI') || tipeStr.contains('URAIAN') || tipeStr.contains('ISIAN')) {
            isPg = false;
          } else {
            isPg = rawOptions.isNotEmpty;
          }

          if (isPg) {
            final List<String> options = List.from(rawOptions);

            if (options.length < 2) {
              if (options.isEmpty) options.add('Pilihan A');
              if (options.length < 2) options.add('Pilihan B');
            }

            int correctIndex = 0;
            if (keyAnswer.isNotEmpty) {
              final cleanKey = keyAnswer.replaceAll(RegExp(r'[^A-Z0-9]'), '');
              if (cleanKey.isNotEmpty) {
                final code = cleanKey.codeUnitAt(0);
                if (code >= 65 && code <= 90) { // 'A' - 'Z'
                  correctIndex = code - 65;
                } else if (int.tryParse(cleanKey) != null) {
                  correctIndex = (int.tryParse(cleanKey) ?? 1) - 1;
                }
              }
            }

            if (correctIndex < 0 || correctIndex >= options.length) {
              correctIndex = 0;
            }

            importedQuestions.add(ExamQuestion(
              id: '${DateTime.now().millisecondsSinceEpoch}_$r',
              questionText: qText,
              options: options,
              correctOptionIndex: correctIndex,
              type: 'multiple_choice',
              points: points,
              createdByTeacherId: widget.teacherId,
              createdByTeacherName: teacherName,
            ));
          } else {
            importedQuestions.add(ExamQuestion(
              id: '${DateTime.now().millisecondsSinceEpoch}_$r',
              questionText: qText,
              options: [],
              correctOptionIndex: 0,
              type: 'essay',
              points: points,
              createdByTeacherId: widget.teacherId,
              createdByTeacherName: teacherName,
            ));
          }
        }
      }

      if (importedQuestions.isEmpty) {
        Get.snackbar(
          AppLocalization.isIndonesian ? 'Informasi' : 'Information',
          AppLocalization.isIndonesian ? 'Tidak ada soal valid yang ditemukan dalam file Excel tersebut.' : 'No valid questions found in the Excel file.',
          backgroundColor: Colors.amber,
          colorText: Colors.black87,
        );
        return;
      }

      final countPg = importedQuestions.where((q) => q.type == 'multiple_choice').length;
      final countEssay = importedQuestions.where((q) => q.type == 'essay').length;

      _showImportConfirmationModal(
        importedQuestions: importedQuestions,
        countPg: countPg,
        countEssay: countEssay,
      );
    } catch (e) {
      Get.snackbar(
        AppLocalization.isIndonesian ? 'Error' : 'Error',
        AppLocalization.isIndonesian ? 'Gagal mengimpor file Excel: $e' : 'Failed to import Excel file: $e',
        backgroundColor: Colors.redAccent,
        colorText: Colors.white,
      );
    }
  }

  /// ── Modal Konfirmasi Impor Excel ───────────────────────────
  void _showImportConfirmationModal({
    required List<ExamQuestion> importedQuestions,
    required int countPg,
    required int countEssay,
  }) {
    final isDark = AuthBackground.isDarkMode.value;
    final titleColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
    final bg = isDark ? const Color(0xFF1A1730) : Colors.white;

    Get.dialog(
      AlertDialog(
        backgroundColor: bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.file_download_done_rounded, color: Color(0xFF10B981), size: 24),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                AppLocalization.isIndonesian ? 'Impor Soal Excel' : 'Import Excel Questions',
                style: TextStyle(color: titleColor, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppLocalization.isIndonesian
                  ? 'Berhasil mengidentifikasi ${importedQuestions.length} soal dari file Excel:'
                  : 'Successfully identified ${importedQuestions.length} questions from Excel file:',
              style: TextStyle(color: titleColor.withValues(alpha: 0.8), fontSize: 13),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF8B5CF6).withValues(alpha: 0.2)),
                    ),
                    child: Column(
                      children: [
                        Text('$countPg', style: const TextStyle(color: Color(0xFF8B5CF6), fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 2),
                        Text(AppLocalization.isIndonesian ? 'Pilihan Ganda' : 'Multiple Choice', style: TextStyle(color: titleColor.withValues(alpha: 0.7), fontSize: 11)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.2)),
                    ),
                    child: Column(
                      children: [
                        Text('$countEssay', style: const TextStyle(color: Color(0xFFF59E0B), fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 2),
                        Text('Essay', style: TextStyle(color: titleColor.withValues(alpha: 0.7), fontSize: 11)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              AppLocalization.isIndonesian
                  ? 'Pilih opsi impor data soal:'
                  : 'Choose how to import question data:',
              style: TextStyle(color: titleColor.withValues(alpha: 0.6), fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text(AppLocalization.cancel, style: const TextStyle(color: Colors.grey)),
          ),
          OutlinedButton(
            onPressed: () {
              Get.back();
              setState(() {
                _questions.addAll(importedQuestions);
                _hasUnsavedChanges = true;
              });
              Get.snackbar(
                AppLocalization.isIndonesian ? 'Sukses' : 'Success',
                AppLocalization.isIndonesian ? 'Berhasil menambahkan ${importedQuestions.length} soal!' : 'Successfully added ${importedQuestions.length} questions!',
                backgroundColor: const Color(0xFF10B981), colorText: Colors.white,
              );
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF8B5CF6),
              side: const BorderSide(color: Color(0xFF8B5CF6)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(AppLocalization.isIndonesian ? 'Tambahkan Soal' : 'Append Questions'),
          ),
          ElevatedButton(
            onPressed: () {
              Get.back();
              setState(() {
                _questions = importedQuestions;
                _hasUnsavedChanges = true;
              });
              Get.snackbar(
                AppLocalization.isIndonesian ? 'Sukses' : 'Success',
                AppLocalization.isIndonesian ? 'Berhasil mengganti soal dengan ${importedQuestions.length} soal baru!' : 'Replaced all questions with ${importedQuestions.length} new questions!',
                backgroundColor: const Color(0xFF10B981), colorText: Colors.white,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8B5CF6),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(AppLocalization.isIndonesian ? 'Gantikan Semua' : 'Replace All'),
          ),
        ],
      ),
    );
  }

  /// ── Modal Petunjuk Cara Pembuatan Format Excel & Impor ─────
  void _showImportGuideModal() {
    final isDark = AuthBackground.isDarkMode.value;
    final titleColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
    final subtitleColor = isDark ? Colors.white70 : const Color(0xFF1E1B4B).withValues(alpha: 0.7);
    final bg = isDark ? const Color(0xFF1A1730) : Colors.white;

    Get.dialog(
      AlertDialog(
        backgroundColor: bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.description_rounded, color: Color(0xFF8B5CF6), size: 22),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                AppLocalization.isIndonesian ? 'Petunjuk Format Excel Soal' : 'Excel Question Format Guide',
                style: TextStyle(color: titleColor, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalization.isIndonesian
                      ? 'Format file Excel (.xlsx) untuk membuat bank soal:'
                      : 'Excel file format (.xlsx) for importing question bank:',
                  style: TextStyle(color: titleColor, fontSize: 12, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                _buildGuidePoint('1. Kolom No', 'Nomor urut soal (1, 2, 3...)', titleColor, subtitleColor),
                _buildGuidePoint('2. Kolom Tipe Soal', 'Isi "PG" (Pilihan Ganda) atau "Essay" (Uraian/Isian). Jika dikosongkan, sistem otomatis mengenali dari ketersediaan opsi.', titleColor, subtitleColor),
                _buildGuidePoint('3. Kolom Pertanyaan', 'Teks soal / pertanyaan ujian.', titleColor, subtitleColor),
                _buildGuidePoint('4. Kolom Bobot Poin', 'Bobot nilai (contoh: 10, 20). Jika kosong, default 10.', titleColor, subtitleColor),
                _buildGuidePoint('5. Kolom Pilihan A s.d E (atau lebih)', 'Opsi pilihan jawaban untuk soal PG. Kosongkan sel untuk membuat 4 opsi (A-D), atau tambah kolom untuk opsi F, G, dst.', titleColor, subtitleColor),
                _buildGuidePoint('6. Kolom Kunci Jawaban', 'Untuk PG isi huruf A, B, C, D, E... Untuk Essay diisi panduan kunci/dikosongkan.', titleColor, subtitleColor),
              ],
            ),
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              OutlinedButton.icon(
                onPressed: () {
                  Get.back();
                  _downloadExcelTemplate();
                },
                icon: const Icon(Icons.download_rounded, color: Color(0xFF10B981), size: 18),
                label: Text(
                  AppLocalization.isIndonesian ? 'Unduh Template Excel' : 'Download Excel Template',
                  style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  side: const BorderSide(color: Color(0xFF10B981)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Get.back(),
                      child: Text(AppLocalization.cancel, style: const TextStyle(color: Colors.grey)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Get.back();
                        _importQuestionsFromExcel();
                      },
                      icon: const Icon(Icons.file_upload_rounded, size: 18),
                      label: Text(
                        AppLocalization.isIndonesian ? 'Pilih File & Impor' : 'Select File & Import',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF8B5CF6),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGuidePoint(String title, String desc, Color titleColor, Color subtitleColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle_outline_rounded, size: 14, color: Color(0xFF8B5CF6)),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(fontSize: 11.5, height: 1.4),
                children: [
                  TextSpan(text: '$title: ', style: TextStyle(fontWeight: FontWeight.bold, color: titleColor)),
                  TextSpan(text: desc, style: TextStyle(color: subtitleColor)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleBack() async {
    if (!_hasUnsavedChanges) {
      Navigator.pop(context);
      return;
    }
    final isDark = AuthBackground.isDarkMode.value;
    final titleColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
    final confirm = await Get.dialog<bool>(
      AlertDialog(
        backgroundColor: isDark ? const Color(0xFF0F0C20) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded,
                color: Color(0xFFF59E0B), size: 22),
            const SizedBox(width: 8),
            Text(AppLocalization.isIndonesian ? 'Soal Belum Tersimpan' : 'Unsaved Questions',
                style: TextStyle(
                    color: titleColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 16)),
          ],
        ),
        content: Text(
          AppLocalization.isIndonesian
              ? 'Anda memiliki perubahan soal yang belum disimpan. Apakah Anda yakin ingin kembali?\n\nPerubahan akan hilang jika Anda keluar sekarang.'
              : 'You have unsaved question changes. Are you sure you want to go back?\n\nChanges will be lost if you leave now.',
          style: TextStyle(
              color: titleColor.withValues(alpha: 0.8), height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: Text(AppLocalization.isIndonesian ? 'Tetap di Sini' : 'Stay Here',
                style: const TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Get.back(result: true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(AppLocalization.isIndonesian ? 'Keluar Tanpa Simpan' : 'Leave Without Saving',
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (confirm == true && context.mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: AuthBackground.isDarkMode,
      builder: (context, isDark, _) {
        final titleColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
        final subTextColor = isDark ? Colors.white70 : const Color(0xFF1E1B4B).withOpacity(0.6);
        final cardColor = isDark ? Colors.white.withOpacity(0.04) : Colors.white;
        final border = isDark ? Colors.white10 : Colors.black.withOpacity(0.06);

        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) _handleBack();
          },
          child: Scaffold(
            backgroundColor: isDark ? const Color(0xFF0F0C20) : Colors.white,
            appBar: AppBar(
              backgroundColor: isDark
                  ? const Color(0xFF0F0C20)
                  : Colors.white,
              surfaceTintColor: Colors.transparent,
              scrolledUnderElevation: 0,
              elevation: 0,
              leading: IconButton(
                icon: Icon(Icons.arrow_back_ios_new_rounded, color: titleColor),
                onPressed: _handleBack,
              ),
              title: Text(
                '${AppLocalization.isIndonesian ? 'Bank Soal' : 'Question Bank'}: ${widget.subjectName}',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: titleColor),
              ),
              actions: [
                if (!_isExamLocked && _hasUnsavedChanges)
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFFF59E0B),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _isExamLocked
                      ? TextButton.icon(
                          onPressed: null,
                          icon: Icon(
                            Icons.lock_rounded,
                            size: 15,
                            color: Colors.redAccent.withValues(alpha: 0.6),
                          ),
                          label: Text(
                            AppLocalization.isIndonesian ? 'Terkunci' : 'Locked',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.redAccent.withValues(alpha: 0.6),
                            ),
                          ),
                          style: TextButton.styleFrom(
                            backgroundColor: Colors.redAccent.withValues(alpha: 0.08),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        )
                      : TextButton.icon(
                          onPressed: _saveData,
                          icon: const Icon(
                            Icons.save_rounded,
                            size: 15,
                            color: Color(0xFF10B981),
                          ),
                          label: Text(
                            AppLocalization.isIndonesian ? 'Simpan Soal' : 'Save Questions',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF10B981),
                            ),
                          ),
                          style: TextButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981).withValues(alpha: 0.1),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                ),

              ],
            ),
            body: AuthBackground(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    // Tab Selector
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.03),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: _availableGrades.map((grade) {
                          final isSelected = _selectedGrade == grade;
                          return Expanded(
                            child: GestureDetector(
                              onTap: () => _changeGrade(grade),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? const Color(0xFF8B5CF6)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Center(
                                  child: Text(
                                    '${AppLocalization.isIndonesian ? 'Angkatan' : 'Cohort'} $grade',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                      color: isSelected
                                          ? Colors.white
                                          : (isDark ? Colors.white70 : Colors.black87),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (!_isLoading) ...[
                      // Toggle Acak Soal
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: border),
                        ),
                        child: Column(
                          children: [
                            // Toggle 1: Pilihan Ganda
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.shuffle_rounded,
                                      color: _shufflePg
                                          ? const Color(0xFF8B5CF6)
                                          : titleColor.withValues(alpha: 0.6),
                                    ),
                                    const SizedBox(width: 12),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          AppLocalization.isIndonesian ? 'Acak Pilihan Ganda' : 'Shuffle Multiple Choice',
                                          style: TextStyle(
                                            color: titleColor,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          AppLocalization.isIndonesian
                                              ? 'Urutan soal pilihan ganda diacak untuk setiap siswa'
                                              : 'Multiple choice questions order shuffled for each student',
                                          style: TextStyle(
                                            color: subTextColor,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                Switch(
                                  value: _shufflePg,
                                  activeColor: const Color(0xFF8B5CF6),
                                  onChanged: _isExamLocked
                                      ? null
                                      : (val) {
                                          setState(() {
                                            _shufflePg = val;
                                            _hasUnsavedChanges = true;
                                          });
                                        },
                                ),
                              ],
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8.0),
                              child: Divider(color: border),
                            ),
                            // Toggle 2: Essay
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.shuffle_on_outlined,
                                      color: _shuffleEssay
                                          ? const Color(0xFF8B5CF6)
                                          : titleColor.withValues(alpha: 0.6),
                                    ),
                                    const SizedBox(width: 12),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          AppLocalization.isIndonesian ? 'Acak Essay' : 'Shuffle Essay',
                                          style: TextStyle(
                                            color: titleColor,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          AppLocalization.isIndonesian
                                              ? 'Urutan soal essay diacak untuk setiap siswa'
                                              : 'Essay questions order shuffled for each student',
                                          style: TextStyle(
                                            color: subTextColor,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                Switch(
                                  value: _shuffleEssay,
                                  activeColor: const Color(0xFF8B5CF6),
                                  onChanged: _isExamLocked
                                      ? null
                                      : (val) {
                                          setState(() {
                                            _shuffleEssay = val;
                                            _hasUnsavedChanges = true;
                                          });
                                        },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    if (_isLoading)
                      const Expanded(child: Center(child: CircularProgressIndicator()))
                    else ...[
                      // Banner kunci: tampil saat ujian sudah dimulai
                      if (_isExamLocked) ...[
                        Container(
                          margin: const EdgeInsets.only(top: 8, bottom: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.redAccent.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.redAccent.withValues(alpha: 0.35)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.lock_rounded, color: Colors.redAccent, size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      AppLocalization.isIndonesian ? 'Soal Terkunci — Ujian Sedang Berlangsung' : 'Questions Locked — Exam Ongoing',
                                      style: const TextStyle(
                                        color: Colors.redAccent,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                    if (_lockedSessionInfo != null) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        _lockedSessionInfo!,
                                        style: TextStyle(
                                          color: Colors.redAccent.withValues(alpha: 0.8),
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 16),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                  '${AppLocalization.isIndonesian ? 'Pertanyaan' : 'Questions'} (${_questions.length})',
                                  style: TextStyle(
                                      color: titleColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16)),
                              const SizedBox(height: 2),
                              Text(
                                  '${AppLocalization.isIndonesian ? 'Total Skor Soal' : 'Total Score'}: $_totalPoints ${AppLocalization.isIndonesian ? 'Poin' : 'Points'}',
                                  style: const TextStyle(
                                      color: Color(0xFF10B981),
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12)),
                            ],
                          ),
                          if (!_isExamLocked)
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              alignment: WrapAlignment.end,
                              children: [
                                OutlinedButton.icon(
                                  onPressed: _showImportGuideModal,
                                  icon: const Icon(Icons.file_upload_rounded, size: 15),
                                  label: Text(
                                    AppLocalization.isIndonesian ? 'Impor Excel' : 'Import Excel',
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFF8B5CF6),
                                    side: const BorderSide(color: Color(0xFF8B5CF6)),
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                ),
                                ElevatedButton.icon(
                                  onPressed: () => _addOrEditQuestion(),
                                  icon: const Icon(Icons.add, size: 15),
                                  label: Text(
                                    AppLocalization.isIndonesian ? 'Tambah' : 'Add',
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF8B5CF6),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      Expanded(
                        child: _questions.isEmpty
                            ? Center(
                                child: Text(
                                    AppLocalization.isIndonesian
                                        ? 'Belum ada pertanyaan. Ketuk "Tambah" untuk membuat soal.'
                                        : 'No questions yet. Tap "Add" to create questions.',
                                    style: TextStyle(color: subTextColor, fontSize: 12),
                                    textAlign: TextAlign.center),
                              )
                            : ListView.builder(
                                itemCount: _questions.length,
                                itemBuilder: (context, idx) {
                                  final q = _questions[idx];
                                  final isMc = q.type == 'multiple_choice';

                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: cardColor,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: border),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            CircleAvatar(
                                              radius: 12,
                                              backgroundColor: const Color(0xFF8B5CF6).withOpacity(0.1),
                                              child: Text('${idx + 1}',
                                                  style: const TextStyle(
                                                      color: Color(0xFF8B5CF6),
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.bold)),
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Text(q.questionText,
                                                  style: TextStyle(
                                                      color: titleColor,
                                                      fontWeight: FontWeight.w600,
                                                      fontSize: 14)),
                                            ),
                                            if (!_isExamLocked) ...[
                                              Container(
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                child: IconButton(
                                                  icon: const Icon(Icons.edit_rounded, color: Color(0xFF8B5CF6), size: 16),
                                                  onPressed: () => _addOrEditQuestion(existing: q, index: idx),
                                                  constraints: const BoxConstraints(),
                                                  padding: const EdgeInsets.all(6),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Container(
                                                decoration: BoxDecoration(
                                                  color: Colors.redAccent.withValues(alpha: 0.1),
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                child: IconButton(
                                                  icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 16),
                                                  onPressed: () {
                                                    setState(() {
                                                      _questions.removeAt(idx);
                                                      _hasUnsavedChanges = true;
                                                    });
                                                  },
                                                  constraints: const BoxConstraints(),
                                                  padding: const EdgeInsets.all(6),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                        if (isMc) ...[
                                          const SizedBox(height: 12),
                                          ...List.generate(q.options.length, (optIdx) {
                                            final char = String.fromCharCode(65 + optIdx);
                                            final isCorrect = q.correctOptionIndex == optIdx;
                                            return Padding(
                                              padding: const EdgeInsets.only(bottom: 6.0, left: 34),
                                              child: Row(
                                                children: [
                                                  Text('$char. ',
                                                      style: TextStyle(
                                                          color: isCorrect ? const Color(0xFF10B981) : subTextColor,
                                                          fontWeight: isCorrect ? FontWeight.bold : FontWeight.normal)),
                                                  Expanded(
                                                    child: Text(q.options[optIdx],
                                                        style: TextStyle(
                                                            color: isCorrect ? titleColor : subTextColor,
                                                            fontWeight: isCorrect ? FontWeight.bold : FontWeight.normal)),
                                                  ),
                                                  if (isCorrect)
                                                    const Icon(Icons.check_rounded, color: Color(0xFF10B981), size: 16),
                                                ],
                                              ),
                                            );
                                          }),
                                        ],
                                        const SizedBox(height: 8),
                                        Padding(
                                          padding: const EdgeInsets.only(left: 34),
                                          child: Text(
                                              isMc
                                                  ? (AppLocalization.isIndonesian
                                                      ? 'Tipe: Pilihan Ganda • Poin: ${q.points}'
                                                      : 'Type: Multiple Choice • Points: ${q.points}')
                                                  : (AppLocalization.isIndonesian
                                                      ? 'Tipe: Essay • Poin: ${q.points}'
                                                      : 'Type: Essay • Points: ${q.points}'),
                                              style: TextStyle(color: subTextColor, fontSize: 11)),
                                        ),
                                        if (q.createdByTeacherName != null || q.updatedByTeacherName != null) ...[
                                          const SizedBox(height: 4),
                                          Padding(
                                            padding: const EdgeInsets.only(left: 34),
                                            child: Row(
                                              children: [
                                                if (q.createdByTeacherName != null) ...[
                                                  Icon(Icons.person_outline_rounded, size: 10, color: subTextColor),
                                                  const SizedBox(width: 3),
                                                  Text(
                                                    AppLocalization.isIndonesian
                                                        ? 'Dibuat: ${q.createdByTeacherName}'
                                                        : 'Created: ${q.createdByTeacherName}',
                                                    style: TextStyle(color: subTextColor, fontSize: 10),
                                                  ),
                                                ],
                                                if (q.createdByTeacherName != null && q.updatedByTeacherName != null)
                                                  Text(' • ', style: TextStyle(color: subTextColor, fontSize: 10)),
                                                if (q.updatedByTeacherName != null) ...[
                                                  Icon(Icons.edit_note_rounded, size: 10, color: subTextColor),
                                                  const SizedBox(width: 3),
                                                  Text(
                                                    AppLocalization.isIndonesian
                                                        ? 'Diedit: ${q.updatedByTeacherName}'
                                                        : 'Edited: ${q.updatedByTeacherName}',
                                                    style: TextStyle(color: subTextColor, fontSize: 10),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
