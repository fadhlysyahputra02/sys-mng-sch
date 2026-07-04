import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../authentication/widgets/auth_background.dart';
import '../../tasks/models/task_model.dart';
import '../../tasks/services/task_service.dart';

class TeacherTaskDetailPage extends StatefulWidget {
  final String schoolId;
  final Task task;

  const TeacherTaskDetailPage({
    super.key,
    required this.schoolId,
    required this.task,
  });

  @override
  State<TeacherTaskDetailPage> createState() => _TeacherTaskDetailPageState();
}

class _TeacherTaskDetailPageState extends State<TeacherTaskDetailPage> with SingleTickerProviderStateMixin {
  final _taskService = TaskService();
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    Get.snackbar(
      'Salin Link',
      '$label berhasil disalin ke clipboard!',
      snackPosition: SnackPosition.TOP,
      backgroundColor: const Color(0xFF10B981),
      colorText: Colors.white,
      margin: const EdgeInsets.all(16),
      borderRadius: 12,
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final days = ['Minggu', 'Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu'];
    final months = [
      'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
    ];
    return '${days[dateTime.weekday % 7]}, ${dateTime.day} ${months[dateTime.month - 1]} ${dateTime.year} - ${DateFormat('HH:mm').format(dateTime.toLocal())} WIB';
  }

  void _showGradingDialog(TaskSubmission submission) {
    final isDark = AuthBackground.isDarkMode.value;
    final scoreController = TextEditingController(
      text: submission.grade != null ? submission.grade!.toStringAsFixed(0) : '',
    );
    final feedbackController = TextEditingController(
      text: submission.teacherFeedback ?? '',
    );

    final formKey = GlobalKey<FormState>();
    bool isSavingGrade = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final titleColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
            final subTextColor = isDark ? Colors.white.withValues(alpha: 0.7) : const Color(0xFF1E1B4B).withValues(alpha: 0.8);
            final inputFill = isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04);

            return AlertDialog(
              backgroundColor: isDark ? const Color(0xFF0F0C20) : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: BorderSide(
                  color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.1),
                ),
              ),
              title: Row(
                children: [
                  const Icon(Icons.grade_rounded, color: Color(0xFF8B5CF6)),
                  const SizedBox(width: 10),
                  Text(
                    'Beri Nilai',
                    style: TextStyle(
                      color: titleColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Siswa: ${submission.studentName}',
                        style: TextStyle(color: titleColor, fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                      const SizedBox(height: 16),
                      // Input Nilai
                      Text(
                        'Nilai (0 - 100)',
                        style: TextStyle(color: subTextColor, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: scoreController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: TextStyle(color: titleColor, fontSize: 15),
                        decoration: InputDecoration(
                          hintText: 'Masukkan nilai (contoh: 85)',
                          hintStyle: TextStyle(color: subTextColor.withValues(alpha: 0.6), fontSize: 13),
                          fillColor: inputFill,
                          filled: true,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) return 'Nilai wajib diisi';
                          final numVal = double.tryParse(val);
                          if (numVal == null || numVal < 0 || numVal > 100) {
                            return 'Nilai harus di antara 0 dan 100';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      // Input Feedback
                      Text(
                        'Feedback / Catatan Guru',
                        style: TextStyle(color: subTextColor, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: feedbackController,
                        maxLines: 3,
                        style: TextStyle(color: titleColor, fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'Tulis feedback atau catatan evaluasi...',
                          hintStyle: TextStyle(color: subTextColor.withValues(alpha: 0.6), fontSize: 13),
                          fillColor: inputFill,
                          filled: true,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSavingGrade ? null : () => Navigator.pop(context),
                  child: Text(
                    'Batal',
                    style: TextStyle(
                      color: isDark ? Colors.white.withValues(alpha: 0.5) : const Color(0xFF1E1B4B).withValues(alpha: 0.5),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: isSavingGrade
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          setModalState(() {
                            isSavingGrade = true;
                          });

                          try {
                            final score = double.parse(scoreController.text);
                            await _taskService.gradeSubmission(
                              schoolId: widget.schoolId,
                              taskId: widget.task.id,
                              studentId: submission.studentId,
                              grade: score,
                              feedback: feedbackController.text.trim().isNotEmpty
                                  ? feedbackController.text.trim()
                                  : null,
                            );
                            if (context.mounted) {
                              Navigator.pop(context);
                              Get.snackbar(
                                'Sukses',
                                'Nilai berhasil disimpan!',
                                snackPosition: SnackPosition.TOP,
                                backgroundColor: const Color(0xFF10B981),
                                colorText: Colors.white,
                                borderRadius: 12,
                                margin: const EdgeInsets.all(16),
                              );
                            }
                          } catch (e) {
                            Get.snackbar(
                              'Gagal',
                              'Gagal menyimpan nilai: $e',
                              snackPosition: SnackPosition.TOP,
                              backgroundColor: const Color(0xFFEF4444),
                              colorText: Colors.white,
                              borderRadius: 12,
                              margin: const EdgeInsets.all(16),
                            );
                          } finally {
                            setModalState(() {
                              isSavingGrade = false;
                            });
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8B5CF6),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: isSavingGrade
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text('Simpan', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
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
        final shadowColor = isDark ? Colors.transparent : Colors.black.withValues(alpha: 0.04);

        return Scaffold(
          body: AuthBackground(
            child: NestedScrollView(
              physics: const BouncingScrollPhysics(),
              headerSliverBuilder: (context, innerBoxIsScrolled) => [
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
                    'Detail Tugas',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: titleColor),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: cardBgColor,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: cardBorderColor),
                        boxShadow: isDark ? [] : [
                          BoxShadow(
                            color: shadowColor,
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: const Color(0xFF8B5CF6).withValues(alpha: 0.3)),
                                ),
                                child: Text(
                                  widget.task.subjectName,
                                  style: const TextStyle(
                                    color: Color(0xFF8B5CF6),
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Text(
                                widget.task.className,
                                style: const TextStyle(
                                  color: Color(0xFF10B981),
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            widget.task.title,
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: titleColor),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Dibuat: ${_formatDateTime(widget.task.createdAt)}',
                            style: TextStyle(fontSize: 11, color: subTextColor),
                          ),
                          Text(
                            'Tenggat: ${_formatDateTime(widget.task.dueDate)}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: widget.task.dueDate.isBefore(DateTime.now())
                                  ? const Color(0xFFEF4444)
                                  : const Color(0xFFF59E0B),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Divider(color: cardBorderColor),
                          const SizedBox(height: 12),
                          Text(
                            'Instruksi:',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: titleColor),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            widget.task.description,
                            style: TextStyle(fontSize: 13, color: titleColor.withValues(alpha: 0.9), height: 1.4),
                          ),
                          if (widget.task.attachmentLink != null) ...[
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: isDark ? Colors.white.withValues(alpha: 0.02) : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: cardBorderColor),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.link_rounded, color: Color(0xFF3B82F6), size: 18),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      widget.task.attachmentLink!,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(fontSize: 12, color: subTextColor),
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () => _copyToClipboard(widget.task.attachmentLink!, 'Link materi'),
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 10),
                                      minimumSize: Size.zero,
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    child: const Text(
                                      'Salin',
                                      style: TextStyle(fontSize: 12, color: Color(0xFF3B82F6), fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _SliverAppBarDelegate(
                    TabBar(
                      controller: _tabController,
                      labelColor: const Color(0xFF8B5CF6),
                      unselectedLabelColor: subTextColor,
                      indicatorColor: const Color(0xFF8B5CF6),
                      indicatorSize: TabBarIndicatorSize.tab,
                      tabs: const [
                        Tab(text: 'Sudah Mengumpulkan'),
                        Tab(text: 'Belum Mengumpulkan'),
                      ],
                    ),
                    isDark,
                  ),
                ),
              ],
              body: StreamBuilder<List<TaskSubmission>>(
                stream: _taskService.getSubmissionsForTask(
                  schoolId: widget.schoolId,
                  taskId: widget.task.id,
                ),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: Color(0xFF8B5CF6)));
                  }

                  final submissions = snapshot.data ?? [];

                  // Get class students to figure out who hasn't submitted
                  return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: FirebaseFirestore.instance
                        .collection('schools')
                        .doc(widget.schoolId)
                        .collection('students')
                        .where('classId', isEqualTo: widget.task.classId)
                        .snapshots(),
                    builder: (context, studentsSnapshot) {
                      if (studentsSnapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator(color: Color(0xFF8B5CF6)));
                      }

                      final studentDocs = studentsSnapshot.data?.docs ?? [];
                      final submittedStudentIds = submissions.map((s) => s.studentId).toSet();

                      // Filter unsubmitted students
                      final unsubmittedStudents = studentDocs.where((doc) {
                        return !submittedStudentIds.contains(doc.id);
                      }).toList();

                      return TabBarView(
                        controller: _tabController,
                        children: [
                          // Tab: Sudah Mengumpulkan
                          _buildSubmittedList(submissions, cardBgColor, cardBorderColor, titleColor, subTextColor, isDark),

                          // Tab: Belum Mengumpulkan
                          _buildUnsubmittedList(unsubmittedStudents, cardBgColor, cardBorderColor, titleColor, subTextColor),
                        ],
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

  Widget _buildSubmittedList(
    List<TaskSubmission> submissions,
    Color cardBgColor,
    Color cardBorderColor,
    Color titleColor,
    Color subTextColor,
    bool isDark,
  ) {
    if (submissions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline_rounded, size: 48, color: subTextColor),
            const SizedBox(height: 12),
            Text(
              'Belum ada siswa yang mengumpulkan.',
              style: TextStyle(color: subTextColor, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(24),
      itemCount: submissions.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final submission = submissions[index];
        final bool isGraded = submission.status == 'graded';

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardBgColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: cardBorderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    submission.studentName,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: titleColor),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isGraded
                          ? const Color(0xFF10B981).withValues(alpha: 0.15)
                          : const Color(0xFF3B82F6).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      isGraded ? 'Sudah Dinilai' : 'Perlu Diperiksa',
                      style: TextStyle(
                        color: isGraded ? const Color(0xFF10B981) : const Color(0xFF3B82F6),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(
                    'Kirim: ${DateFormat('dd MMM yyyy, HH:mm').format(submission.submittedAt.toLocal())}',
                    style: TextStyle(fontSize: 10, color: subTextColor),
                  ),
                  if (submission.submittedAt.isAfter(widget.task.dueDate)) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'Terlambat',
                        style: TextStyle(
                          color: Color(0xFFEF4444),
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              if (submission.studentNotes != null && submission.studentNotes!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  'Catatan Siswa:',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: titleColor),
                ),
                Text(
                  submission.studentNotes!,
                  style: TextStyle(fontSize: 12, color: titleColor.withValues(alpha: 0.8)),
                ),
              ],
              if (submission.answerLink != null && submission.answerLink!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withValues(alpha: 0.02) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.attachment_rounded, size: 14, color: Color(0xFF3B82F6)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          submission.answerLink!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 11, color: subTextColor),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => _copyToClipboard(submission.answerLink!, 'Link tugas siswa'),
                        child: const Icon(Icons.copy_rounded, size: 16, color: Color(0xFF3B82F6)),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Divider(color: cardBorderColor),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (isGraded)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Nilai: ',
                              style: TextStyle(fontSize: 12, color: subTextColor),
                            ),
                            Text(
                              submission.grade!.toStringAsFixed(0),
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
                            ),
                          ],
                        ),
                        if (submission.teacherFeedback != null && submission.teacherFeedback!.isNotEmpty)
                          Text(
                            'Feedback: "${submission.teacherFeedback}"',
                            style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: subTextColor),
                          ),
                      ],
                    )
                  else
                    Text(
                      'Belum dinilai',
                      style: TextStyle(fontSize: 12, color: subTextColor),
                    ),
                  ElevatedButton(
                    onPressed: () => _showGradingDialog(submission),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8B5CF6),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      elevation: 0,
                    ),
                    child: Text(
                      isGraded ? 'Edit Nilai' : 'Beri Nilai',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildUnsubmittedList(
    List<DocumentSnapshot<Map<String, dynamic>>> students,
    Color cardBgColor,
    Color cardBorderColor,
    Color titleColor,
    Color subTextColor,
  ) {
    if (students.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle_outline_rounded, size: 48, color: Color(0xFF10B981)),
            const SizedBox(height: 12),
            Text(
              'Semua siswa telah mengumpulkan!',
              style: TextStyle(color: subTextColor, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(24),
      itemCount: students.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final data = students[index].data() ?? {};
        final name = data['nama'] ?? 'Siswa';
        final nis = data['nis'] ?? '-';

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: cardBgColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: cardBorderColor),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close_rounded, color: Colors.red, size: 16),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: titleColor),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'NIS: $nis',
                      style: TextStyle(fontSize: 11, color: subTextColor),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar _tabBar;
  final bool _isDark;

  _SliverAppBarDelegate(this._tabBar, this._isDark);

  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: _isDark ? const Color(0xFF0B0914) : const Color(0xFFF8FAFC),
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return false;
  }
}
