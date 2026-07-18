import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/services/session_service.dart';
import '../../authentication/widgets/auth_background.dart';
import '../models/exam_model.dart';
import '../models/exam_submission_model.dart';
import '../services/exam_service.dart';
import '../../../core/localization/app_localization.dart';

class TeacherGradeExamPage extends StatefulWidget {
  final Exam exam;
  final ExamSubmission submission;

  const TeacherGradeExamPage({
    super.key,
    required this.exam,
    required this.submission,
  });

  @override
  State<TeacherGradeExamPage> createState() => _TeacherGradeExamPageState();
}

class _TeacherGradeExamPageState extends State<TeacherGradeExamPage> {
  final _examService = ExamService();
  final _formKey = GlobalKey<FormState>();

  // Map to hold points for each essay question
  final Map<String, TextEditingController> _essayControllers = {};
  bool _isSaving = false;

  // Live score variables (raw point sum, not percentage)
  int _totalMaxPoints = 0;
  int _pgPointsObtained = 0;
  int _livePointsObtained = 0; // PG + essay raw sum

  bool _isLoadingQuestions = true;
  List<ExamQuestion> _loadedQuestions = [];

  @override
  void initState() {
    super.initState();
    _loadOverriddenQuestions();
  }

  Future<void> _loadOverriddenQuestions() async {
    setState(() {
      _isLoadingQuestions = true;
    });

    final user = SessionService.currentUser!;
    final schoolId = user.schoolId;
    final studentId = widget.submission.studentId;

    try {
      // 1. Fetch student to get angkatan
      final studentSnap = await FirebaseFirestore.instance
          .collection('schools')
          .doc(schoolId)
          .collection('students')
          .doc(studentId)
          .get();

      String angkatan = '';
      if (studentSnap.exists && studentSnap.data() != null) {
        angkatan = (studentSnap.data()?['angkatan'] ?? '').toString().trim();
      }

      // 2. Parse eventId and subjectId from exam id.
      // Format exam ID: "${eventId}_${subjectId}_${classId}"
      // classId bisa mengandung koma (multi-kelas) tapi tidak underscore.
      // subjectId bisa mengandung underscore, sehingga kita harus ambil
      // bagian setelah parts[0] (eventId) dan sebelum classId (bagian terakhir).
      // Cara paling aman: eventId = parts[0], classId = parts.last,
      // subjectId = semua bagian di tengah.
      final parts = widget.exam.id.split('_');
      final eventId = parts.isNotEmpty ? parts[0] : '';
      // subjectId = semua bagian tengah di antara eventId dan classId (parts.last)
      final subjectId = parts.length > 2
          ? parts.sublist(1, parts.length - 1).join('_')
          : (parts.length > 1 ? parts[1] : '');

      List<ExamQuestion> loaded = [];

      // Try loading with angkatan suffix
      if (angkatan.isNotEmpty) {
        final qSnap = await FirebaseFirestore.instance
            .collection('schools')
            .doc(schoolId)
            .collection('exam_questions')
            .doc('${eventId}_${subjectId}_$angkatan')
            .get();

        if (qSnap.exists && qSnap.data() != null) {
          final qList = (qSnap.data()?['questions'] as List? ?? [])
              .map((q) => ExamQuestion.fromMap(Map<String, dynamic>.from(q)))
              .toList();
          if (qList.isNotEmpty) {
            loaded = qList;
          }
        }
      }

      // Fallback 1: load without angkatan suffix
      if (loaded.isEmpty) {
        final qSnap = await FirebaseFirestore.instance
            .collection('schools')
            .doc(schoolId)
            .collection('exam_questions')
            .doc('${eventId}_$subjectId')
            .get();

        if (qSnap.exists && qSnap.data() != null) {
          final qList = (qSnap.data()?['questions'] as List? ?? [])
              .map((q) => ExamQuestion.fromMap(Map<String, dynamic>.from(q)))
              .toList();
          if (qList.isNotEmpty) {
            loaded = qList;
          }
        }
      }

      // Fallback 2: use the base exam questions
      if (loaded.isEmpty) {
        loaded = widget.exam.questions;
      }

      // ── VALIDASI KRITIS ──────────────────────────────────────────────────────
      // Pastikan soal yang di-load memiliki ID yang sesuai dengan jawaban murid
      // di submission.answers. Jika tidak ada satupun soal PG yang ID-nya cocok
      // dengan submission.answers, maka soal dari exam_questions BERBEDA dengan
      // soal yang digunakan murid saat mengerjakan — fallback ke base questions.
      if (loaded != widget.exam.questions && widget.submission.answers.isNotEmpty) {
        final loadedPgIds = loaded
            .where((q) => q.type != 'essay')
            .map((q) => q.id)
            .toSet();
        final submissionAnswerIds = widget.submission.answers.keys.toSet();
        final hasMatchingIds = loadedPgIds.intersection(submissionAnswerIds).isNotEmpty;

        if (!hasMatchingIds) {
          // Soal yang di-load tidak cocok dengan jawaban murid.
          // Gunakan base exam questions agar penilaian PG akurat.
          debugPrint('[GradeExam] WARNING: Loaded questions IDs do not match '
              'submission.answers keys. Falling back to base exam questions. '
              'loadedIds: $loadedPgIds, submissionIds: $submissionAnswerIds');
          loaded = widget.exam.questions;
        }
      }
      // ─────────────────────────────────────────────────────────────────────────

      setState(() {
        _loadedQuestions = loaded;
        _isLoadingQuestions = false;
      });

      // Dipanggil setelah setState selesai assign _loadedQuestions
      _calculateInitialPoints();
    } catch (e) {
      // If error occurs, fallback to base exam questions
      setState(() {
        _loadedQuestions = widget.exam.questions;
        _isLoadingQuestions = false;
      });

      _calculateInitialPoints();
    }
  }

  void _calculateInitialPoints() {
    int totalMax = 0;
    int pgObtained = 0;

    for (final q in _loadedQuestions) {
      totalMax += q.points;
      if (q.type == 'essay') {
        final initialScore = widget.submission.essayScores[q.id]?.toString() ?? '0';
        final controller = TextEditingController(text: initialScore);
        controller.addListener(_updateLiveScore);
        _essayControllers[q.id] = controller;
      } else {
        // PG – tambahkan poin jika jawaban benar
        final studentAnswer = widget.submission.answers[q.id];
        if (studentAnswer == q.correctOptionIndex) {
          pgObtained += q.points;
        }
      }
    }

    _totalMaxPoints = totalMax;
    _pgPointsObtained = pgObtained;
    _updateLiveScore();
  }

  void _updateLiveScore() {
    int essayObtained = 0;
    _essayControllers.forEach((qId, controller) {
      final score = int.tryParse(controller.text.trim()) ?? 0;
      essayObtained += score;
    });
    setState(() {
      _livePointsObtained = _pgPointsObtained + essayObtained;
    });
  }

  Future<void> _submitGrades() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
    });

    final user = SessionService.currentUser!;
    try {
      final Map<String, int> finalEssayScores = {};
      _essayControllers.forEach((qId, controller) {
        finalEssayScores[qId] = int.tryParse(controller.text.trim()) ?? 0;
      });

      await _examService.gradeSubmission(
        schoolId: user.schoolId,
        submissionId: widget.submission.id,
        exam: widget.exam.copyWith(questions: _loadedQuestions),
        essayScores: finalEssayScores,
      );

      Get.back();
      Get.snackbar(
        AppLocalization.isIndonesian ? 'Sukses' : 'Success',
        AppLocalization.isIndonesian
            ? 'Penilaian untuk "${widget.submission.studentName}" berhasil disimpan.'
            : 'Grading for "${widget.submission.studentName}" has been successfully saved.',
        backgroundColor: const Color(0xFF10B981),
        colorText: Colors.white,
        borderRadius: 12,
        margin: const EdgeInsets.all(16),
      );
    } catch (e) {
      Get.snackbar(
        AppLocalization.isIndonesian ? 'Gagal' : 'Failed',
        AppLocalization.isIndonesian ? 'Gagal menyimpan nilai: $e' : 'Failed to save grades: $e',
        backgroundColor: const Color(0xFFEF4444),
        colorText: Colors.white,
      );
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  @override
  void dispose() {
    _essayControllers.forEach((_, controller) {
      controller.dispose();
    });
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: AuthBackground.isDarkMode,
      builder: (context, isDark, _) {
        final titleColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
        final subTextColor = isDark ? Colors.white.withValues(alpha: 0.5) : const Color(0xFF1E1B4B).withValues(alpha: 0.6);
        final cardBgColor = isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white;
        final cardBorderColor = isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.08);
        final iconBgColor = isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05);
        final inputFillColor = isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04);

        return Scaffold(
          body: AuthBackground(
            child: Scaffold(
              backgroundColor: Colors.transparent,
              appBar: AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                leading: Container(
                  margin: const EdgeInsets.only(left: 16),
                  decoration: BoxDecoration(
                    color: iconBgColor,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                title: Text(
                  AppLocalization.isIndonesian ? 'Koreksi Jawaban Ujian' : 'Grade Exam Answers',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: titleColor),
                ),
              ),
              body: _isLoadingQuestions
                  ? const Center(child: CircularProgressIndicator())
                  : Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          // Rangkuman Atas
                          Container(
                            margin: const EdgeInsets.all(24),
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: cardBgColor,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: cardBorderColor),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        widget.submission.studentName,
                                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: titleColor),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        widget.exam.title,
                                        style: TextStyle(fontSize: 12, color: subTextColor),
                                      ),
                                      if (widget.submission.proctorNote != null &&
                                          widget.submission.proctorNote!.isNotEmpty) ...[
                                        const SizedBox(height: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: Colors.redAccent.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: Colors.redAccent.withValues(alpha: 0.2)),
                                          ),
                                          child: Row(
                                            children: [
                                              const Icon(Icons.info_outline_rounded, size: 14, color: Colors.redAccent),
                                              const SizedBox(width: 6),
                                              Expanded(
                                                child: Text(
                                                  '${AppLocalization.isIndonesian ? 'Catatan Pengawas' : 'Proctor Note'}: ${widget.submission.proctorNote}',
                                                  style: const TextStyle(fontSize: 11, color: Colors.redAccent, fontWeight: FontWeight.bold),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: (_livePointsObtained >= 70
                                            ? const Color(0xFF10B981)
                                            : Colors.amber)
                                        .withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Column(
                                    children: [
                                      Text(
                                        AppLocalization.isIndonesian ? 'Skor Akhir' : 'Final Score',
                                        style: TextStyle(fontSize: 10, color: subTextColor, fontWeight: FontWeight.w600),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '$_livePointsObtained / 100',
                                        style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          color: _livePointsObtained >= 70
                                              ? const Color(0xFF10B981)
                                              : Colors.amber,
                                        ),
                                      ),
                                      Text(
                                        AppLocalization.isIndonesian ? 'Poin' : 'Points',
                                        style: TextStyle(fontSize: 10, color: subTextColor),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // List Soal
                          Expanded(
                            child: ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 24),
                              physics: const BouncingScrollPhysics(),
                              itemCount: _loadedQuestions.length,
                              itemBuilder: (context, index) {
                                final q = _loadedQuestions[index];

                          if (q.type == 'essay') {
                            final studentAnswer = widget.submission.essayAnswers[q.id] ?? '';
                            final controller = _essayControllers[q.id];

                            return Container(
                              margin: const EdgeInsets.only(bottom: 20),
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: cardBgColor,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: cardBorderColor),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        AppLocalization.isIndonesian ? 'Soal ${index + 1} (Essay)' : 'Question ${index + 1} (Essay)',
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: titleColor),
                                      ),
                                      Text(
                                        '${AppLocalization.isIndonesian ? 'Maks' : 'Max'} ${q.points} ${AppLocalization.isIndonesian ? 'Poin' : 'Points'}',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF8B5CF6)),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    q.questionText,
                                    style: TextStyle(fontSize: 14, color: titleColor, height: 1.4),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    AppLocalization.isIndonesian ? 'Jawaban Murid:' : 'Student Answer:',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: subTextColor),
                                  ),
                                  const SizedBox(height: 6),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: isDark ? Colors.white.withValues(alpha: 0.02) : Colors.black.withValues(alpha: 0.02),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: cardBorderColor),
                                    ),
                                    child: Text(
                                      studentAnswer.isEmpty
                                          ? (AppLocalization.isIndonesian ? '(Murid tidak menjawab)' : '(Student did not answer)')
                                          : studentAnswer,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: titleColor,
                                        fontStyle: studentAnswer.isEmpty ? FontStyle.italic : FontStyle.normal,
                                        height: 1.4,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Row(
                                    children: [
                                      Text(
                                        '${AppLocalization.isIndonesian ? 'Input Poin Ujian (maks: ${q.points}):' : 'Input Exam Points (max: ${q.points}):'}',
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: titleColor),
                                      ),
                                      const SizedBox(width: 12),
                                      SizedBox(
                                        width: 80,
                                        child: TextFormField(
                                          controller: controller,
                                          keyboardType: TextInputType.number,
                                          textAlign: TextAlign.center,
                                          style: TextStyle(color: titleColor, fontWeight: FontWeight.bold, fontSize: 14),
                                          decoration: InputDecoration(
                                            fillColor: inputFillColor,
                                            filled: true,
                                            contentPadding: const EdgeInsets.symmetric(vertical: 8),
                                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                            enabledBorder: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(10),
                                              borderSide: BorderSide(color: cardBorderColor),
                                            ),
                                          ),
                                          validator: (val) {
                                            final points = int.tryParse(val ?? '');
                                            if (points == null) return AppLocalization.isIndonesian ? 'Angka tidak valid' : 'Invalid number';
                                            final maxAllowed = q.points > 0 ? q.points : 10;
                                            if (points < 0 || points > maxAllowed) return '0-$maxAllowed';
                                            return null;
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          } else {
                            // PG
                            final studentAnswerIdx = widget.submission.answers[q.id];
                            final isCorrect = studentAnswerIdx == q.correctOptionIndex;

                            return Container(
                              margin: const EdgeInsets.only(bottom: 20),
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: cardBgColor,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: cardBorderColor),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        AppLocalization.isIndonesian ? 'Soal ${index + 1} (Pilihan Ganda)' : 'Question ${index + 1} (Multiple Choice)',
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: titleColor),
                                      ),
                                      Text(
                                        isCorrect
                                            ? (AppLocalization.isIndonesian ? '${q.points} / ${q.points} Poin' : '${q.points} / ${q.points} Points')
                                            : (AppLocalization.isIndonesian ? '0 / ${q.points} Poin' : '0 / ${q.points} Points'),
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                          color: isCorrect ? const Color(0xFF10B981) : Colors.redAccent,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    q.questionText,
                                    style: TextStyle(fontSize: 14, color: titleColor, height: 1.4),
                                  ),
                                  const SizedBox(height: 16),
                                  ...List.generate(q.options.length, (optIdx) {
                                    final optionChar = String.fromCharCode(65 + optIdx);
                                    final isSelectedByStudent = studentAnswerIdx == optIdx;
                                    final isCorrectAnswer = q.correctOptionIndex == optIdx;

                                    Color optionColor = titleColor;
                                    FontWeight optionWeight = FontWeight.normal;
                                    IconData? statusIcon;
                                    Color? iconColor;

                                    if (isSelectedByStudent) {
                                      optionColor = isCorrect ? const Color(0xFF10B981) : Colors.redAccent;
                                      optionWeight = FontWeight.bold;
                                      statusIcon = isCorrect ? Icons.check_circle_outline_rounded : Icons.cancel_outlined;
                                      iconColor = optionColor;
                                    } else if (isCorrectAnswer) {
                                      optionColor = const Color(0xFF10B981);
                                      optionWeight = FontWeight.bold;
                                      statusIcon = Icons.check_circle_outline_rounded;
                                      iconColor = optionColor;
                                    }

                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 8.0),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 24,
                                            height: 24,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              border: Border.all(color: cardBorderColor),
                                            ),
                                            child: Center(
                                              child: Text(
                                                optionChar,
                                                style: TextStyle(fontSize: 11, color: titleColor, fontWeight: FontWeight.bold),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Text(
                                              q.options[optIdx],
                                              style: TextStyle(fontSize: 13, color: optionColor, fontWeight: optionWeight),
                                            ),
                                          ),
                                          if (statusIcon != null) ...[
                                            const SizedBox(width: 8),
                                            Icon(statusIcon, size: 16, color: iconColor),
                                          ],
                                        ],
                                      ),
                                    );
                                  }),
                                ],
                              ),
                            );
                          }
                        },
                      ),
                    ),

                    // Tombol Submit
                    Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _submitGrades,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF8B5CF6),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          minimumSize: const Size(double.infinity, 50),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : Text(
                                AppLocalization.isIndonesian ? 'Simpan & Selesaikan Penilaian' : 'Save & Finalize Grading',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
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
