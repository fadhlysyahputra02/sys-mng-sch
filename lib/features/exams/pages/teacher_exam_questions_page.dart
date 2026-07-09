import 'package:cloud_firestore/cloud_firestore.dart';
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

  const TeacherExamQuestionsPage({
    super.key,
    required this.eventId,
    required this.subjectId,
    required this.subjectName,
    required this.teacherId,
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

  @override
  void initState() {
    super.initState();
    _loadQuestionsData();
  }

  Future<void> _loadQuestionsData() async {
    final schoolId = SessionService.currentUser!.schoolId;
    final docId = '${widget.eventId}_${widget.subjectId}';

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
        final qList = (data['questions'] as List? ?? [])
            .map((q) => ExamQuestion.fromMap(Map<String, dynamic>.from(q)))
            .toList();
        setState(() {
          _questions = qList;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      Get.snackbar('Error', 'Gagal memuat soal: $e',
          backgroundColor: Colors.redAccent, colorText: Colors.white);
    }
  }

  Future<void> _saveData() async {
    final schoolId = SessionService.currentUser!.schoolId;
    final docId = '${widget.eventId}_${widget.subjectId}';

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
      );

      Get.back(); // Close loading dialog
      Get.snackbar('Sukses', 'Bank soal berhasil disimpan!',
          backgroundColor: const Color(0xFF10B981), colorText: Colors.white);
      setState(() => _hasUnsavedChanges = false);
    } catch (e) {
      Get.back(); // Close loading dialog
      Get.snackbar('Error', 'Gagal menyimpan soal: $e',
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
                  Text(isEdit ? 'Edit Pertanyaan' : 'Tambah Pertanyaan',
                      style: TextStyle(
                          color: titleColor,
                          fontSize: 18,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),

                  // Tipe Pertanyaan
                  Text('Tipe Pertanyaan',
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
                        items: const [
                          DropdownMenuItem(value: 'multiple_choice', child: Text('Pilihan Ganda')),
                          DropdownMenuItem(value: 'essay', child: Text('Essay')),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            typeObs.value = val;
                          }
                        },
                      )),
                  const SizedBox(height: 16),

                  // Teks Pertanyaan
                  Text('Pertanyaan',
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
                      hintText: 'Tulis teks pertanyaan di sini...',
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
                            Text('Pilihan Jawaban',
                                style: TextStyle(
                                    color: titleColor.withOpacity(0.6),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600)),
                            TextButton.icon(
                              onPressed: () {
                                if (optionsCtrls.length < 10) {
                                  optionsCtrls.add(TextEditingController());
                                } else {
                                  Get.snackbar('Batas Maksimal', 'Maksimal 10 pilihan jawaban');
                                }
                              },
                              icon: const Icon(Icons.add, size: 16, color: Color(0xFF8B5CF6)),
                              label: const Text('Tambah Opsi',
                                  style: TextStyle(color: Color(0xFF8B5CF6), fontSize: 12)),
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
                                      hintText: 'Opsi $char',
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

                  // Bobot Poin (Hanya untuk Pilihan Ganda)
                  Obx(() {
                    if (typeObs.value != 'multiple_choice') {
                      return const SizedBox.shrink();
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Bobot Nilai (Poin)',
                            style: TextStyle(
                                color: titleColor.withValues(alpha: 0.6),
                                fontSize: 12,
                                fontWeight: FontWeight.w600)),
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
                    );
                  }),

                  // Button Simpan Pertanyaan
                  ElevatedButton(
                    onPressed: () {
                      if (textCtrl.text.trim().isEmpty) {
                        Get.snackbar('Error', 'Teks pertanyaan tidak boleh kosong');
                        return;
                      }

                      final type = typeObs.value;
                      final points = type == 'essay' ? 0 : (int.tryParse(pointsCtrl.text) ?? 10);
                      final List<String> options = [];

                      if (type == 'multiple_choice') {
                        for (final c in optionsCtrls) {
                          if (c.text.trim().isEmpty) {
                            Get.snackbar('Error', 'Semua opsi pilihan harus diisi');
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
                    child: Text(isEdit ? 'Perbarui Pertanyaan' : 'Tambahkan Pertanyaan'),
                  ),
                ],
              ),
            ),
          );
        },
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
            Text('Soal Belum Tersimpan',
                style: TextStyle(
                    color: titleColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 16)),
          ],
        ),
        content: Text(
          'Anda memiliki perubahan soal yang belum disimpan. Apakah Anda yakin ingin kembali?\n\nPerubahan akan hilang jika Anda keluar sekarang.',
          style: TextStyle(
              color: titleColor.withValues(alpha: 0.8), height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('Tetap di Sini',
                style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Get.back(result: true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Keluar Tanpa Simpan',
                style: TextStyle(fontWeight: FontWeight.bold)),
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
                'Bank Soal: ${widget.subjectName}',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: titleColor),
              ),
              actions: [
                if (_hasUnsavedChanges)
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
                IconButton(
                  icon: const Icon(Icons.save_rounded,
                      color: Color(0xFF10B981)),
                  tooltip: 'Simpan Soal',
                  onPressed: _saveData,
                ),
              ],
            ),
            body: AuthBackground(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 8),
                          const SizedBox(height: 20),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Pertanyaan (${_questions.length})',
                                  style: TextStyle(
                                      color: titleColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16)),
                              ElevatedButton.icon(
                                onPressed: () => _addOrEditQuestion(),
                                icon: const Icon(Icons.add, size: 16),
                                label: const Text('Tambah', style: TextStyle(fontWeight: FontWeight.bold)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF8B5CF6),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),

                          Expanded(
                            child: _questions.isEmpty
                                ? Center(
                                    child: Text('Belum ada pertanyaan. Ketuk "Tambah" untuk membuat soal.',
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
                                                Container(
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                                                    shape: BoxShape.circle,
                                                  ),
                                                  child: IconButton(
                                                    icon: const Icon(Icons.edit_rounded, size: 16, color: Color(0xFF8B5CF6)),
                                                    onPressed: () => _addOrEditQuestion(existing: q, index: idx),
                                                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                                    padding: EdgeInsets.zero,
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Container(
                                                  decoration: BoxDecoration(
                                                    color: Colors.redAccent.withValues(alpha: 0.1),
                                                    shape: BoxShape.circle,
                                                  ),
                                                  child: IconButton(
                                                    icon: const Icon(Icons.delete_rounded, size: 16, color: Colors.redAccent),
                                                    onPressed: () {
                                                      setState(() {
                                                        _questions.removeAt(idx);
                                                      });
                                                    },
                                                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                                    padding: EdgeInsets.zero,
                                                  ),
                                                ),
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
                                                      ? 'Tipe: Pilihan Ganda • Poin: ${q.points}'
                                                      : 'Tipe: Essay',
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
                      ),
                    ),
            ),
          ),
        );
      },
    );
  }
}
