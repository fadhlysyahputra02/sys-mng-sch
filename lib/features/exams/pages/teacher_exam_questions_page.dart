import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
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
        'questions': _questions.map((q) => q.toMap()).toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      Get.back(); // Close loading dialog
      Get.snackbar('Sukses', 'Bank soal berhasil disimpan!',
          backgroundColor: const Color(0xFF10B981), colorText: Colors.white);
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
                          color: titleColor.withOpacity(0.6),
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Obx(() => Row(
                        children: [
                          ChoiceChip(
                            label: const Text('Pilihan Ganda'),
                            selected: typeObs.value == 'multiple_choice',
                            onSelected: (val) {
                              if (val) typeObs.value = 'multiple_choice';
                            },
                          ),
                          const SizedBox(width: 12),
                          ChoiceChip(
                            label: const Text('Essay / Isian'),
                            selected: typeObs.value == 'essay',
                            onSelected: (val) {
                              if (val) typeObs.value = 'essay';
                            },
                          ),
                        ],
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

                  // Bobot Poin
                  Text('Bobot Nilai (Poin)',
                      style: TextStyle(
                          color: titleColor.withOpacity(0.6),
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

                  // Button Simpan Pertanyaan
                  ElevatedButton(
                    onPressed: () {
                      if (textCtrl.text.trim().isEmpty) {
                        Get.snackbar('Error', 'Teks pertanyaan tidak boleh kosong');
                        return;
                      }

                      final points = int.tryParse(pointsCtrl.text) ?? 10;
                      final type = typeObs.value;
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

                      final newQ = ExamQuestion(
                        id: existing?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
                        questionText: textCtrl.text.trim(),
                        options: options,
                        correctOptionIndex: type == 'multiple_choice' ? correctOptObs.value : 0,
                        type: type,
                        points: points,
                      );

                      setState(() {
                        if (isEdit && index != null) {
                          _questions[index] = newQ;
                        } else {
                          _questions.add(newQ);
                        }
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

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: AuthBackground.isDarkMode,
      builder: (context, isDark, _) {
        final titleColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
        final subTextColor = isDark ? Colors.white70 : const Color(0xFF1E1B4B).withOpacity(0.6);
        final cardColor = isDark ? Colors.white.withOpacity(0.04) : Colors.white;
        final border = isDark ? Colors.white10 : Colors.black.withOpacity(0.06);

        return Scaffold(
          body: AuthBackground(
            child: Scaffold(
              backgroundColor: Colors.transparent,
              appBar: AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                leading: IconButton(
                  icon: Icon(Icons.arrow_back_ios_new_rounded, color: titleColor),
                  onPressed: () => Navigator.pop(context),
                ),
                title: Text(
                  'Bank Soal: ${widget.subjectName}',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: titleColor),
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.save_rounded, color: Color(0xFF10B981)),
                    onPressed: _saveData,
                  ),
                ],
              ),
              body: _isLoading
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
                              TextButton.icon(
                                onPressed: () => _addOrEditQuestion(),
                                icon: const Icon(Icons.add, size: 16),
                                label: const Text('Tambah'),
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
                                                IconButton(
                                                  icon: const Icon(Icons.edit_rounded, size: 18),
                                                  onPressed: () => _addOrEditQuestion(existing: q, index: idx),
                                                ),
                                                IconButton(
                                                  icon: const Icon(Icons.delete_rounded, size: 18, color: Colors.redAccent),
                                                  onPressed: () {
                                                    setState(() {
                                                      _questions.removeAt(idx);
                                                    });
                                                  },
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
                                              child: Text('Tipe: ${isMc ? 'Pilihan Ganda' : 'Essay'} • Poin: ${q.points}',
                                                  style: TextStyle(color: subTextColor, fontSize: 11)),
                                            ),
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
