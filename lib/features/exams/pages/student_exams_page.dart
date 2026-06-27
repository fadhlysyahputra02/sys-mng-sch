import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../../core/services/session_service.dart';
import '../../authentication/widgets/auth_background.dart';
import '../models/exam_model.dart';
import '../models/exam_submission_model.dart';
import '../services/exam_service.dart';
import 'student_take_exam_page.dart';
import '../../students/data/student_service.dart';

class StudentExamsPage extends StatefulWidget {
  final String classId;
  final bool hideBackButton;

  const StudentExamsPage({
    super.key,
    required this.classId,
    this.hideBackButton = false,
  });

  @override
  State<StudentExamsPage> createState() => _StudentExamsPageState();
}

class _StudentExamsPageState extends State<StudentExamsPage> {
  final _examService = ExamService();
  late final Future<String> _studentDocIdFuture;

  @override
  void initState() {
    super.initState();
    final user = SessionService.currentUser!;
    _studentDocIdFuture = StudentService()
        .getStudentDocByUid(user.schoolId, user.uid)
        .then((doc) => doc?.id ?? user.uid);
  }

  @override
  Widget build(BuildContext context) {
    final user = SessionService.currentUser!;

    return ValueListenableBuilder<bool>(
      valueListenable: AuthBackground.isDarkMode,
      builder: (context, isDark, _) {
        final titleColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
        final subTextColor = isDark ? Colors.white.withValues(alpha: 0.5) : const Color(0xFF1E1B4B).withValues(alpha: 0.6);
        final cardBgColor = isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white;
        final cardBorderColor = isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.08);
        final iconBgColor = isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05);

        return Scaffold(
          body: AuthBackground(
            child: Scaffold(
              backgroundColor: Colors.transparent,
              appBar: AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                automaticallyImplyLeading: !widget.hideBackButton,
                leading: widget.hideBackButton
                    ? null
                    : Container(
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
                  'Ujian Online Kelas',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: titleColor),
                ),
              ),
              body: FutureBuilder<String>(
                future: _studentDocIdFuture,
                builder: (context, docIdSnapshot) {
                  if (docIdSnapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final studentDocId = docIdSnapshot.data ?? user.uid;

                  return StreamBuilder<List<Exam>>(
                    stream: _examService.getExamsForClass(user.schoolId, widget.classId),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final exams = snapshot.data ?? [];
                  if (exams.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.assignment_turned_in_rounded, color: Color(0xFF10B981), size: 48),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Tidak Ada Ujian Aktif',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: titleColor),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Selamat! Saat ini tidak ada ujian online aktif yang harus dikerjakan untuk kelas Anda.',
                              style: TextStyle(fontSize: 12, color: subTextColor),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    physics: const BouncingScrollPhysics(),
                    itemCount: exams.length,
                    itemBuilder: (context, index) {
                      final exam = exams[index];
                      final isExpired = DateTime.now().isAfter(exam.dueDate);
                      final dateStr = DateFormat('dd MMM yyyy, HH:mm').format(exam.dueDate);

                      return StreamBuilder<ExamSubmission?>(
                        stream: _examService.getExamSubmissionStream(user.schoolId, exam.id, studentDocId),
                        builder: (context, subSnapshot) {
                          final submission = subSnapshot.data;
                          final bool hasCompleted = submission != null;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: cardBgColor,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: cardBorderColor),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          exam.title,
                                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: titleColor),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (hasCompleted)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF10B981).withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: const Text(
                                            'Selesai',
                                            style: TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 10),
                                          ),
                                        )
                                      else if (isExpired)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: Colors.redAccent.withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: const Text(
                                            'Ditutup',
                                            style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 10),
                                          ),
                                        )
                                      else
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: const Text(
                                            'Belum Dikerjakan',
                                            style: TextStyle(color: Color(0xFFF59E0B), fontWeight: FontWeight.bold, fontSize: 10),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    exam.description,
                                    style: TextStyle(fontSize: 12, color: subTextColor),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 16),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Durasi: ${exam.durationMinutes} Menit | ${exam.questions.length} Soal',
                                        style: TextStyle(fontSize: 11, color: subTextColor, fontWeight: FontWeight.w600),
                                      ),
                                      Text(
                                        'Batas: $dateStr',
                                        style: TextStyle(fontSize: 11, color: subTextColor, fontWeight: FontWeight.w600),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  if (hasCompleted)
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                      decoration: BoxDecoration(
                                        color: isDark ? Colors.white.withValues(alpha: 0.02) : Colors.black.withValues(alpha: 0.01),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: cardBorderColor),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            'Jawaban Benar: ${submission.correctCount} / ${exam.questions.length}',
                                            style: TextStyle(fontSize: 12, color: titleColor, fontWeight: FontWeight.w600),
                                          ),
                                          Text(
                                            'Skor: ${submission.score.toInt()}',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: submission.score >= 70 ? const Color(0xFF10B981) : Colors.redAccent,
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                  else if (isExpired)
                                    SizedBox(
                                      width: double.infinity,
                                      child: Text(
                                        'Ujian sudah ditutup dan Anda melewatkan pengerjaan ujian ini.',
                                        style: TextStyle(fontSize: 11, color: Colors.redAccent.withValues(alpha: 0.8), fontStyle: FontStyle.italic),
                                        textAlign: TextAlign.center,
                                      ),
                                    )
                                  else
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton(
                                        onPressed: () async {
                                          Get.dialog(
                                            const Center(
                                              child: CircularProgressIndicator(
                                                color: Color(0xFF8B5CF6),
                                              ),
                                            ),
                                            barrierDismissible: false,
                                          );

                                          try {
                                            final now = DateTime.now();
                                            final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
                                            
                                            final attendanceSnapshot = await FirebaseFirestore.instance
                                                .collection('schools')
                                                .doc(user.schoolId)
                                                .collection('attendance')
                                                .where('studentId', isEqualTo: studentDocId)
                                                .where('date', isEqualTo: dateStr)
                                                .get();

                                            Get.back(); // close loading dialog

                                            if (attendanceSnapshot.docs.isEmpty) {
                                              Get.snackbar(
                                                'Absensi Diperlukan',
                                                'Anda belum melakukan absensi hari ini. Silakan lakukan absensi terlebih dahulu sebelum dapat mengerjakan ujian online.',
                                                snackPosition: SnackPosition.TOP,
                                                backgroundColor: Colors.amber,
                                                colorText: Colors.black,
                                                margin: const EdgeInsets.all(16),
                                                borderRadius: 12,
                                                icon: const Icon(Icons.warning_amber_rounded, color: Colors.black),
                                              );
                                            } else {
                                              Get.to(() => StudentTakeExamPage(
                                                exam: exam,
                                                studentDocId: studentDocId,
                                              ));
                                            }
                                          } catch (e) {
                                            Get.back(); // close loading dialog
                                            Get.snackbar(
                                              'Gagal Verifikasi',
                                              'Gagal memeriksa status absensi: $e',
                                              backgroundColor: Colors.redAccent,
                                              colorText: Colors.white,
                                            );
                                          }
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFF8B5CF6),
                                          foregroundColor: Colors.white,
                                          elevation: 0,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                          padding: const EdgeInsets.symmetric(vertical: 12),
                                        ),
                                        child: const Text(
                                          'Mulai Kerjakan Ujian',
                                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ),
    );
      },
    );
  }
}
