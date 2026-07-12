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
import 'teacher_create_exam_page.dart';
import 'teacher_grade_exam_page.dart';
import '../../students/data/student_service.dart';

class TeacherExamsPage extends StatefulWidget {
  final String teacherId;
  final bool hideBackButton;

  const TeacherExamsPage({
    super.key,
    required this.teacherId,
    this.hideBackButton = false,
  });

  @override
  State<TeacherExamsPage> createState() => _TeacherExamsPageState();
}

class _TeacherExamsPageState extends State<TeacherExamsPage> {
  final _examService = ExamService();

  Map<String, Map<String, dynamic>> _classMap = {};
  bool _isLoadingClasses = true;
  String? _tahunAjaran;
  String? _semester;

  StreamSubscription<DocumentSnapshot>? _schoolSub;
  bool _lockDialogShown = false;

  @override
  void initState() {
    super.initState();
    _loadTeacherClasses();
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
                  Get.offAllNamed('/teacher'); // Exit to Dashboard
                }
              },
              child: const Text('Tutup', style: TextStyle(color: Color(0xFF6366F1))),
            ),
          ],
        );
      },
    );
  }

  Future<void> _loadTeacherClasses() async {
    final user = SessionService.currentUser!;
    try {
      final schoolDoc = await FirebaseFirestore.instance
          .collection('schools')
          .doc(user.schoolId)
          .get();

      if (schoolDoc.exists) {
        final schoolData = schoolDoc.data() ?? {};
        _tahunAjaran = schoolData['tahunAjaran']?.toString();
        _semester = schoolData['semester']?.toString();
      }

      final snapshot = await FirebaseFirestore.instance
          .collection('schools')
          .doc(user.schoolId)
          .collection('class_schedules')
          .where('teacherId', isEqualTo: widget.teacherId)
          .get();

      final Map<String, Map<String, dynamic>> tempClassMap = {};
      for (final doc in snapshot.docs) {
        final s = doc.data();
        final classId = s['classId']?.toString() ?? '';
        final className = s['className']?.toString() ?? '';
        final subjectId = s['subjectId']?.toString() ?? '';
        final subjectName = s['subjectName']?.toString() ?? '';

        if (classId.isEmpty || className.isEmpty) continue;

        if (!tempClassMap.containsKey(classId)) {
          tempClassMap[classId] = {
            'classId': classId,
            'className': className,
            'subjects': <String, String>{},
          };
        }
        if (subjectId.isNotEmpty && subjectName.isNotEmpty) {
          final classData = tempClassMap[classId]!;
          (classData['subjects'] as Map<String, String>)[subjectId] = subjectName;
        }
      }

      setState(() {
        _classMap = tempClassMap;
        _isLoadingClasses = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingClasses = false;
      });
    }
  }

  void _manageSusulanStudents(BuildContext context, Exam exam) {
    final user = SessionService.currentUser!;
    final checkedStudentIds = List<String>.from(exam.susulanStudentIds).obs;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return ValueListenableBuilder<bool>(
          valueListenable: AuthBackground.isDarkMode,
          builder: (context, isDark, _) {
            final titleColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
            final cardBgColor = isDark ? const Color(0xFF0F0C20) : Colors.white;
            final cardBorderColor = isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.08);

            return Container(
              height: MediaQuery.of(context).size.height * 0.7,
              decoration: BoxDecoration(
                color: cardBgColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
                border: Border.all(color: cardBorderColor),
              ),
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Atur Ujian Susulan',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: titleColor),
                      ),
                      IconButton(
                        icon: Icon(Icons.close, color: titleColor),
                        onPressed: () => Get.back(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Pilih murid yang diizinkan mengikuti ujian susulan ini setelah batas waktu berakhir.',
                    style: TextStyle(fontSize: 12, color: titleColor.withValues(alpha: 0.6)),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: StudentService().getStudentsByClass(exam.classId, schoolId: user.schoolId),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        if (snapshot.hasError) {
                          return Center(child: Text('Error: ${snapshot.error}', style: TextStyle(color: titleColor)));
                        }

                        final docs = snapshot.data?.docs ?? [];
                        if (docs.isEmpty) {
                          return Center(
                            child: Text(
                              'Tidak ada murid di kelas ini.',
                              style: TextStyle(color: titleColor.withValues(alpha: 0.5)),
                            ),
                          );
                        }

                        return ListView.builder(
                          physics: const BouncingScrollPhysics(),
                          itemCount: docs.length,
                          itemBuilder: (context, index) {
                            final doc = docs[index];
                            final studentId = doc.id;
                            final name = doc.data()['nama'] ?? '';

                            return Obx(() {
                              final isChecked = checkedStudentIds.contains(studentId);
                              return CheckboxListTile(
                                activeColor: const Color(0xFF8B5CF6),
                                title: Text(name, style: TextStyle(color: titleColor, fontSize: 14)),
                                value: isChecked,
                                onChanged: (val) {
                                  if (val == true) {
                                    checkedStudentIds.add(studentId);
                                  } else {
                                    checkedStudentIds.remove(studentId);
                                  }
                                },
                              );
                            });
                          },
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        try {
                          await _examService.updateSusulanStudents(
                            user.schoolId,
                            exam.id,
                            checkedStudentIds.toList(),
                          );
                          Get.back();
                          Get.snackbar(
                            'Sukses',
                            'Pengaturan ujian susulan berhasil disimpan.',
                            backgroundColor: const Color(0xFF10B981),
                            colorText: Colors.white,
                          );
                        } catch (e) {
                          Get.snackbar(
                            'Gagal',
                            'Gagal menyimpan: $e',
                            backgroundColor: Colors.redAccent,
                            colorText: Colors.white,
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF8B5CF6),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Simpan Pengaturan', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _confirmDeleteExam(BuildContext context, Exam exam) {
    final isDark = AuthBackground.isDarkMode.value;
    final titleColor = isDark ? Colors.white : const Color(0xFF1E1B4B);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF0F0C20) : Colors.white,
          title: Text('Hapus Ujian', style: TextStyle(color: titleColor, fontWeight: FontWeight.bold)),
          content: Text(
            'Apakah Anda yakin ingin menghapus ujian "${exam.title}"? Nilai terkait pada Buku Nilai kelas juga akan ikut terhapus.',
            style: TextStyle(color: titleColor.withValues(alpha: 0.8)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal', style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                try {
                  await _examService.deleteExam(SessionService.currentUser!.schoolId, exam.id);
                  Get.snackbar('Sukses', 'Ujian berhasil diarsipkan.',
                      backgroundColor: const Color(0xFF10B981), colorText: Colors.white);
                } catch (e) {
                  Get.snackbar('Gagal', 'Gagal menghapus: $e',
                      backgroundColor: const Color(0xFFEF4444), colorText: Colors.white);
                }
              },
              child: const Text('Hapus', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  void _showSubmissionsSheet(Exam exam) {
    final isDark = AuthBackground.isDarkMode.value;
    final titleColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
    final cardBgColor = isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white;
    final cardBorderColor = isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.08);
    final user = SessionService.currentUser!;

    Get.bottomSheet(
      DefaultTabController(
        length: 2,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F0C20) : Colors.white,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(28),
              topRight: Radius.circular(28),
            ),
            border: Border(top: BorderSide(color: cardBorderColor)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hasil Ujian Murid',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: titleColor),
                        ),
                        Text(
                          exam.title,
                          style: TextStyle(fontSize: 12, color: titleColor.withValues(alpha: 0.6)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: titleColor),
                    onPressed: () => Get.back(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: StreamBuilder<List<ExamSubmission>>(
                  stream: _examService.getExamSubmissions(user.schoolId, exam.id),
                  builder: (context, submissionSnapshot) {
                    if (submissionSnapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final submissions = submissionSnapshot.data ?? [];

                    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: StudentService().getStudentsByClass(exam.classId, schoolId: user.schoolId),
                      builder: (context, studentSnapshot) {
                        if (studentSnapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }

                        final studentDocs = studentSnapshot.data?.docs ?? [];
                        final Map<String, ExamSubmission> submissionMap = {
                          for (var sub in submissions) sub.studentId: sub
                        };

                        final notSubmittedStudents = studentDocs.where((doc) => !submissionMap.containsKey(doc.id)).toList();
                        notSubmittedStudents.sort((a, b) {
                          final nameA = a.data()['nama']?.toString().toLowerCase() ?? '';
                          final nameB = b.data()['nama']?.toString().toLowerCase() ?? '';
                          return nameA.compareTo(nameB);
                        });

                        return Column(
                          children: [
                            TabBar(
                              labelColor: const Color(0xFF8B5CF6),
                              unselectedLabelColor: titleColor.withValues(alpha: 0.6),
                              indicatorColor: const Color(0xFF8B5CF6),
                              indicatorSize: TabBarIndicatorSize.tab,
                              dividerColor: Colors.transparent,
                              tabs: [
                                Tab(
                                  child: Text(
                                    'Sudah (${submissions.length})',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                ),
                                Tab(
                                  child: Text(
                                    'Belum (${notSubmittedStudents.length})',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Expanded(
                              child: TabBarView(
                                children: [
                                  // TAB 1: SUDAH MENGERJAKAN
                                  submissions.isEmpty
                                      ? Center(
                                          child: Text(
                                            'Belum ada murid yang mengumpulkan ujian.',
                                            style: TextStyle(color: titleColor.withValues(alpha: 0.5), fontSize: 13),
                                            textAlign: TextAlign.center,
                                          ),
                                        )
                                      : ListView.builder(
                                          physics: const BouncingScrollPhysics(),
                                          itemCount: submissions.length,
                                          itemBuilder: (context, index) {
                                            final sub = submissions[index];
                                            final dateStr = DateFormat('dd MMM yyyy, HH:mm').format(sub.submittedAt);
                                            final hasEssay = exam.questions.any((q) => q.type == 'essay');

                                            return Container(
                                              margin: const EdgeInsets.only(bottom: 12),
                                              decoration: BoxDecoration(
                                                color: cardBgColor,
                                                borderRadius: BorderRadius.circular(16),
                                                border: Border.all(color: cardBorderColor),
                                              ),
                                              child: Material(
                                                color: Colors.transparent,
                                                child: InkWell(
                                                  borderRadius: BorderRadius.circular(16),
                                                  onTap: () {
                                                    Get.back(); // Close bottom sheet
                                                    Get.to(() => TeacherGradeExamPage(
                                                          exam: exam,
                                                          submission: sub,
                                                        ));
                                                  },
                                                  child: Padding(
                                                    padding: const EdgeInsets.all(16),
                                                    child: Row(
                                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                      children: [
                                                        Expanded(
                                                          child: Column(
                                                            crossAxisAlignment: CrossAxisAlignment.start,
                                                            children: [
                                                              Text(
                                                                sub.studentName,
                                                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: titleColor),
                                                              ),
                                                              const SizedBox(height: 4),
                                                              Text(
                                                                'Dikumpulkan: $dateStr${exam.questions.any((q) => q.type == 'multiple_choice') ? '\nBenar PG: ${sub.correctCount} | Salah PG: ${sub.incorrectCount}' : ''}',
                                                                style: TextStyle(fontSize: 11, color: titleColor.withValues(alpha: 0.6), height: 1.4),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                        const SizedBox(width: 8),
                                                        if (hasEssay && !sub.isGraded)
                                                          Container(
                                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                            decoration: BoxDecoration(
                                                              color: Colors.amber.withValues(alpha: 0.15),
                                                              borderRadius: BorderRadius.circular(10),
                                                            ),
                                                            child: const Text(
                                                              'Perlu Koreksi',
                                                              style: TextStyle(
                                                                color: Colors.amber,
                                                                fontWeight: FontWeight.bold,
                                                                fontSize: 12,
                                                              ),
                                                            ),
                                                          )
                                                        else
                                                          Container(
                                                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                                            decoration: BoxDecoration(
                                                              color: (sub.score >= 70 ? const Color(0xFF10B981) : Colors.redAccent).withValues(alpha: 0.15),
                                                              borderRadius: BorderRadius.circular(12),
                                                            ),
                                                            child: Text(
                                                              '${sub.score.toInt()}',
                                                              style: TextStyle(
                                                                color: sub.score >= 70 ? const Color(0xFF10B981) : Colors.redAccent,
                                                                fontWeight: FontWeight.bold,
                                                                fontSize: 18,
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
                                        ),

                                  // TAB 2: BELUM MENGERJAKAN
                                  notSubmittedStudents.isEmpty
                                      ? Center(
                                          child: Text(
                                            'Semua murid sudah mengumpulkan ujian.',
                                            style: TextStyle(color: titleColor.withValues(alpha: 0.5), fontSize: 13),
                                            textAlign: TextAlign.center,
                                          ),
                                        )
                                      : ListView.builder(
                                          physics: const BouncingScrollPhysics(),
                                          itemCount: notSubmittedStudents.length,
                                          itemBuilder: (context, index) {
                                            final student = notSubmittedStudents[index].data();
                                            final studentId = notSubmittedStudents[index].id;
                                            final name = student['nama'] ?? 'Murid';
                                            final nis = student['nis'] ?? '-';
                                            final isSusulan = exam.susulanStudentIds.contains(studentId);

                                            return Container(
                                              margin: const EdgeInsets.only(bottom: 12),
                                              decoration: BoxDecoration(
                                                color: cardBgColor,
                                                borderRadius: BorderRadius.circular(16),
                                                border: Border.all(color: cardBorderColor),
                                              ),
                                              child: Padding(
                                                padding: const EdgeInsets.all(16),
                                                child: Row(
                                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                  children: [
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        children: [
                                                          Text(
                                                            name,
                                                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: titleColor),
                                                          ),
                                                          const SizedBox(height: 4),
                                                          Text(
                                                            'NIS: $nis',
                                                            style: TextStyle(fontSize: 11, color: titleColor.withValues(alpha: 0.6)),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    if (isSusulan)
                                                      Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                        decoration: BoxDecoration(
                                                          color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                                                          borderRadius: BorderRadius.circular(8),
                                                        ),
                                                        child: const Text(
                                                          'Susulan',
                                                          style: TextStyle(
                                                            color: Color(0xFF8B5CF6),
                                                            fontWeight: FontWeight.bold,
                                                            fontSize: 10,
                                                          ),
                                                        ),
                                                      )
                                                    else
                                                      Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                        decoration: BoxDecoration(
                                                          color: Colors.redAccent.withValues(alpha: 0.15),
                                                          borderRadius: BorderRadius.circular(8),
                                                        ),
                                                        child: const Text(
                                                          'Belum',
                                                          style: TextStyle(
                                                            color: Colors.redAccent,
                                                            fontWeight: FontWeight.bold,
                                                            fontSize: 10,
                                                          ),
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      isScrollControlled: true,
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
                  'Manajemen Ujian Online',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: titleColor),
                ),
              ),
              floatingActionButton: _isLoadingClasses
                  ? null
                  : FloatingActionButton(
                      backgroundColor: const Color(0xFF8B5CF6),
                      child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
                      onPressed: () {
                        if (_classMap.isEmpty) {
                          Get.snackbar('Info', 'Anda tidak memiliki kelas mengajar aktif.',
                              backgroundColor: Colors.amber, colorText: Colors.black);
                          return;
                        }
                        Get.to(() => TeacherCreateExamPage(
                              teacherId: widget.teacherId,
                              classMap: _classMap,
                              tahunAjaran: _tahunAjaran ?? '',
                              semester: _semester ?? '',
                            ));
                      },
                    ),
              body: _isLoadingClasses
                  ? const Center(child: CircularProgressIndicator())
                  : StreamBuilder<List<Exam>>(
                      stream: _examService.getExamsForTeacher(user.schoolId, widget.teacherId),
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
                                      color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.quiz_rounded, color: Color(0xFF8B5CF6), size: 48),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Belum Ada Ujian Online',
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: titleColor),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Ketuk tombol + di kanan bawah untuk membuat dan menerbitkan ujian online pertama Anda.',
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
                            final dateStr = DateFormat('dd MMM yyyy, HH:mm').format(exam.dueDate);

                            return Container(
                              margin: const EdgeInsets.only(bottom: 16),
                              decoration: BoxDecoration(
                                color: cardBgColor,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: cardBorderColor),
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(20),
                                  onTap: () => _showSubmissionsSheet(exam),
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
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                IconButton(
                                                  icon: const Icon(Icons.people_alt_outlined, color: Color(0xFF8B5CF6), size: 20),
                                                  onPressed: () => _manageSusulanStudents(context, exam),
                                                  tooltip: 'Atur Ujian Susulan',
                                                ),
                                                IconButton(
                                                  icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                                                  onPressed: () => _confirmDeleteExam(context, exam),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Petunjuk: ${exam.description}',
                                          style: TextStyle(fontSize: 12, color: subTextColor),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 16),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Row(
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                                                    borderRadius: BorderRadius.circular(10),
                                                  ),
                                                  child: Text(
                                                    exam.className,
                                                    style: const TextStyle(
                                                      color: Color(0xFF6366F1),
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 11,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFF10B981).withValues(alpha: 0.15),
                                                    borderRadius: BorderRadius.circular(10),
                                                  ),
                                                  child: Text(
                                                    '${exam.questions.length} Soal',
                                                    style: const TextStyle(
                                                      color: Color(0xFF10B981),
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 11,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                                                  stream: FirebaseFirestore.instance
                                                      .collection('schools')
                                                      .doc(user.schoolId)
                                                      .collection('exam_submissions')
                                                      .where('examId', isEqualTo: exam.id)
                                                      .snapshots(),
                                                  builder: (context, subSnap) {
                                                    if (!subSnap.hasData) return const SizedBox.shrink();
                                                    final subs = subSnap.data!.docs;
                                                    final ungradedCount = subs.where((doc) {
                                                      final data = doc.data();
                                                      return data['isGraded'] == false;
                                                    }).length;

                                                    if (ungradedCount > 0) {
                                                      return Padding(
                                                        padding: const EdgeInsets.only(right: 8.0),
                                                        child: Container(
                                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                          decoration: BoxDecoration(
                                                            color: Colors.amber.withValues(alpha: 0.15),
                                                            borderRadius: BorderRadius.circular(10),
                                                            border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                                                          ),
                                                          child: Row(
                                                            mainAxisSize: MainAxisSize.min,
                                                            children: [
                                                              const Icon(Icons.info_outline_rounded, size: 10, color: Colors.amber),
                                                              const SizedBox(width: 4),
                                                              Text(
                                                                '$ungradedCount Belum Dikoreksi',
                                                                style: const TextStyle(
                                                                  color: Colors.amber,
                                                                  fontWeight: FontWeight.bold,
                                                                  fontSize: 9,
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      );
                                                    }
                                                    return const SizedBox.shrink();
                                                  },
                                                ),
                                                Text(
                                                  'Batas: $dateStr',
                                                  style: TextStyle(fontSize: 11, color: subTextColor, fontWeight: FontWeight.w600),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
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
