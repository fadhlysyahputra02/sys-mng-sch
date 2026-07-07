import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../../core/services/session_service.dart';
import '../../authentication/widgets/auth_background.dart';
import '../models/exam_model.dart';
import '../models/exam_submission_model.dart';
import '../services/exam_service.dart';
import '../services/exam_session_service.dart';
import '../models/exam_event_model.dart';
import 'student_exam_participation_page.dart';
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
  final Map<String, Stream<ExamSubmission?>> _submissionStreams = {};
  
  StreamSubscription<DocumentSnapshot>? _schoolSub;
  bool _lockDialogShown = false;

  Stream<ExamSubmission?> _getSubmissionStream(String schoolId, String examId, String studentId) {
    final key = '${examId}_$studentId';
    if (!_submissionStreams.containsKey(key)) {
      _submissionStreams[key] = _examService.getExamSubmissionStream(schoolId, examId, studentId);
    }
    return _submissionStreams[key]!;
  }

  @override
  void initState() {
    super.initState();
    final user = SessionService.currentUser!;
    _studentDocIdFuture = StudentService()
        .getStudentDocByUid(user.schoolId, user.uid)
        .then((doc) => doc?.id ?? user.uid);
    _listenToAccess();
  }

  void _listenToAccess() {
    final user = SessionService.currentUser!;
    _schoolSub = FirebaseFirestore.instance
        .collection('schools')
        .doc(user.schoolId)
        .snapshots()
        .listen((doc) {
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        final bool enabled = data['enableOnlineExam'] ?? false;
        if (!enabled && !_lockDialogShown && mounted) {
          _lockDialogShown = true;
          _showPremiumDialogAndExit();
        }
      }
    });
  }

  void _showPremiumDialogAndExit() {
    final isDark = AuthBackground.isDarkMode.value;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF0F0C20) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.lock_rounded, color: Colors.amber),
              SizedBox(width: 8),
              Text('Fitur Terkunci', style: TextStyle(color: Colors.amber)),
            ],
          ),
          content: Text(
            'Sekolah belum berlangganan untuk mengaktifkan fitur ini.',
            style: TextStyle(color: isDark ? Colors.white70 : Colors.black87),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext); // Close dialog
                if (mounted) {
                  final role = SessionService.currentUser?.role;
                  if (role == 'parent') {
                    Get.offAllNamed('/parent');
                  } else {
                    Get.offAllNamed('/student');
                  }
                }
              },
              child: const Text('Tutup', style: TextStyle(color: Color(0xFF6366F1))),
            ),
          ],
        );
      },
    );
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

                  return StreamBuilder<ExamEvent?>(
                    stream: ExamSessionService().getActiveExamEvent(user.schoolId),
                    builder: (context, activeEventSnap) {
                      final activeEvent = activeEventSnap.data;

                      return ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        physics: const BouncingScrollPhysics(),
                        itemCount: exams.length + (activeEvent != null ? 1 : 0),
                        itemBuilder: (context, index) {
                          // Card Ujian Semester (hanya saat ada event aktif, di posisi pertama)
                          if (activeEvent != null && index == 0) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: GestureDetector(
                                onTap: () => Get.to(() => StudentExamParticipationPage(
                                  classId: widget.classId,
                                  studentDocId: studentDocId,
                                  studentName: user.nama,
                                  studentNis: '',
                                )),
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        const Color(0xFF8B5CF6).withValues(alpha: isDark ? 0.25 : 0.12),
                                        const Color(0xFFEC4899).withValues(alpha: isDark ? 0.15 : 0.06),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: const Color(0xFF8B5CF6).withValues(alpha: 0.4),
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 46,
                                        height: 46,
                                        decoration: BoxDecoration(
                                          gradient: const LinearGradient(
                                            colors: [Color(0xFF8B5CF6), Color(0xFFEC4899)],
                                          ),
                                          borderRadius: BorderRadius.circular(13),
                                        ),
                                        child: const Icon(Icons.assignment_rounded,
                                            color: Colors.white, size: 24),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              activeEvent.title,
                                              style: TextStyle(
                                                color: titleColor,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 3),
                                            Row(
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFF10B981).withValues(alpha: 0.15),
                                                    borderRadius: BorderRadius.circular(6),
                                                  ),
                                                  child: const Text('Sedang Berlangsung',
                                                      style: TextStyle(
                                                          color: Color(0xFF10B981),
                                                          fontSize: 10,
                                                          fontWeight: FontWeight.bold)),
                                                ),
                                                const SizedBox(width: 6),
                                                Text(activeEvent.examType,
                                                    style: const TextStyle(
                                                        color: Color(0xFF8B5CF6),
                                                        fontSize: 11,
                                                        fontWeight: FontWeight.bold)),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      Icon(Icons.arrow_forward_ios_rounded,
                                          size: 14, color: subTextColor),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }

                          final examIndex = activeEvent != null ? index - 1 : index;
                          final exam = exams[examIndex];
                          final isSusulan = exam.susulanStudentIds.contains(studentDocId);
                          final isExpired = DateTime.now().isAfter(exam.dueDate) && !isSusulan;
                          final dateStr = DateFormat('dd MMM yyyy, HH:mm').format(exam.dueDate);

                      return StreamBuilder<ExamSubmission?>(
                        stream: _getSubmissionStream(user.schoolId, exam.id, studentDocId),
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
                                            color: (exam.questions.any((q) => q.type == 'essay') && !submission.isGraded)
                                                ? Colors.amber.withValues(alpha: 0.15)
                                                : const Color(0xFF10B981).withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            (exam.questions.any((q) => q.type == 'essay') && !submission.isGraded)
                                                ? 'Sedang Dikoreksi'
                                                : 'Selesai',
                                            style: TextStyle(
                                              color: (exam.questions.any((q) => q.type == 'essay') && !submission.isGraded)
                                                  ? Colors.amber
                                                  : const Color(0xFF10B981),
                                              fontWeight: FontWeight.bold,
                                              fontSize: 10,
                                            ),
                                          ),
                                        )
                                      else if (isSusulan && DateTime.now().isAfter(exam.dueDate))
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: const Text(
                                            'Susulan',
                                            style: TextStyle(color: Color(0xFF8B5CF6), fontWeight: FontWeight.bold, fontSize: 10),
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
                                          Expanded(
                                            child: Text(
                                              (exam.questions.any((q) => q.type == 'essay') && !submission.isGraded)
                                                  ? 'Jawaban terkirim, menunggu penilaian essay.'
                                                  : 'Jawaban Benar: ${submission.correctCount} / ${exam.questions.where((q) => q.type != 'essay').length} PG',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: titleColor,
                                                fontWeight: FontWeight.w600,
                                                fontStyle: (exam.questions.any((q) => q.type == 'essay') && !submission.isGraded)
                                                    ? FontStyle.italic
                                                    : FontStyle.normal,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Text(
                                            (exam.questions.any((q) => q.type == 'essay') && !submission.isGraded)
                                                ? 'Skor: --'
                                                : 'Skor: ${submission.score.toInt()}',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: (exam.questions.any((q) => q.type == 'essay') && !submission.isGraded)
                                                  ? Colors.amber
                                                  : (submission.score >= 70 ? const Color(0xFF10B981) : Colors.redAccent),
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
                                              bool isPermittedOrSick = false;
                                              String blockedReason = '';

                                              // 1. Check daily attendance record
                                              for (final doc in attendanceSnapshot.docs) {
                                                if (doc.id == '${studentDocId}_$dateStr') {
                                                  final status = (doc.data()['status'] ?? '').toString().toLowerCase();
                                                  if (status == 'sakit' || status == 'izin') {
                                                    isPermittedOrSick = true;
                                                    blockedReason = status == 'sakit' ? 'Sakit' : 'Izin';
                                                  }
                                                  break;
                                                }
                                              }

                                              // 2. Check subject-specific attendance record
                                              if (!isPermittedOrSick) {
                                                for (final doc in attendanceSnapshot.docs) {
                                                  final data = doc.data();
                                                  if (data['subjectName'] != null &&
                                                      data['subjectName'].toString().trim().toLowerCase() == exam.subjectName.trim().toLowerCase()) {
                                                    final status = (data['status'] ?? '').toString().toLowerCase();
                                                    if (status == 'sakit' || status == 'izin') {
                                                      isPermittedOrSick = true;
                                                      blockedReason = status == 'sakit' ? 'Sakit' : 'Izin';
                                                    }
                                                    break;
                                                  }
                                                }
                                              }

                                              if (isPermittedOrSick) {
                                                Get.snackbar(
                                                  'Akses Ditolak',
                                                  'Anda tidak dapat mengikuti ujian online karena status Anda hari ini atau di mata pelajaran ini adalah: $blockedReason.',
                                                  snackPosition: SnackPosition.TOP,
                                                  backgroundColor: Colors.redAccent,
                                                  colorText: Colors.white,
                                                  margin: const EdgeInsets.all(16),
                                                  borderRadius: 12,
                                                  icon: const Icon(Icons.block_rounded, color: Colors.white),
                                                );
                                              } else {
                                                Get.to(() => StudentTakeExamPage(
                                                  exam: exam,
                                                  studentDocId: studentDocId,
                                                ));
                                              }
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
          );
        },
      ),
    ),
  ),
);
      },
    );
  }
  
  @override
  void dispose() {
    _schoolSub?.cancel();
    super.dispose();
  }
}
