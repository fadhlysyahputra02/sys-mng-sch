import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../../core/services/session_service.dart';
import '../../authentication/widgets/auth_background.dart';
import '../../tasks/models/task_model.dart';
import '../../tasks/services/task_service.dart';
import 'student_submit_task_page.dart';

class StudentTasksPage extends StatefulWidget {
  final String studentDocId;
  final Map<String, dynamic> studentData;
  final String className;
  final String tahunAjaran;
  final String semester;
  final bool isParent;

  const StudentTasksPage({
    super.key,
    required this.studentDocId,
    required this.studentData,
    required this.className,
    required this.tahunAjaran,
    required this.semester,
    this.isParent = false,
  });

  @override
  State<StudentTasksPage> createState() => _StudentTasksPageState();
}

class _StudentTasksPageState extends State<StudentTasksPage> with SingleTickerProviderStateMixin {
  final _taskService = TaskService();
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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

  @override
  Widget build(BuildContext context) {
    final user = SessionService.currentUser!;
    final classId = widget.studentData['classId'] ?? '';

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
            child: NestedScrollView(
              physics: const BouncingScrollPhysics(),
              headerSliverBuilder: (context, innerBoxIsScrolled) => [
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
                    widget.isParent ? 'Tugas Anak' : 'Tugas Saya',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: titleColor),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Kelas: ${widget.className}',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: titleColor),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Tahun Ajaran: ${widget.tahunAjaran} - ${widget.semester}',
                          style: TextStyle(fontSize: 12, color: subTextColor),
                        ),
                      ],
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
                        Tab(text: 'Belum Selesai'),
                        Tab(text: 'Terlambat'),
                        Tab(text: 'Selesai'),
                      ],
                    ),
                    isDark,
                  ),
                ),
              ],
              body: StreamBuilder<List<Task>>(
                stream: _taskService.getTasksByClass(
                  schoolId: user.schoolId,
                  classId: classId,
                  tahunAjaran: widget.tahunAjaran,
                  semester: widget.semester,
                ),
                builder: (context, taskSnapshot) {
                  if (taskSnapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: Color(0xFF8B5CF6)));
                  }

                  final tasks = taskSnapshot.data ?? [];

                  return StreamBuilder<List<TaskSubmission>>(
                    stream: _taskService.getSubmissionsByStudent(
                      schoolId: user.schoolId,
                      studentId: widget.studentDocId,
                    ),
                    builder: (context, subSnapshot) {
                      if (subSnapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator(color: Color(0xFF8B5CF6)));
                      }

                      final submissions = subSnapshot.data ?? [];
                      final Map<String, TaskSubmission> submissionMap = {
                        for (var sub in submissions) sub.taskId: sub
                      };

                      final now = DateTime.now();

                      // Categorize tasks
                      final todoTasks = <Task>[];
                      final lateTasks = <Task>[];
                      final completedTasks = <Task>[];

                      for (final task in tasks) {
                        final submission = submissionMap[task.id];
                        if (submission != null) {
                          completedTasks.add(task);
                        } else {
                          if (task.dueDate.isBefore(now)) {
                            lateTasks.add(task);
                          } else {
                            todoTasks.add(task);
                          }
                        }
                      }

                      // Sort by due date (closest deadline first for todo/late, most recently completed first for completed)
                      todoTasks.sort((a, b) => a.dueDate.compareTo(b.dueDate));
                      lateTasks.sort((a, b) => b.dueDate.compareTo(a.dueDate));
                      completedTasks.sort((a, b) {
                        final subA = submissionMap[a.id]?.submittedAt ?? DateTime.now();
                        final subB = submissionMap[b.id]?.submittedAt ?? DateTime.now();
                        return subB.compareTo(subA);
                      });

                      return TabBarView(
                        controller: _tabController,
                        children: [
                          // Tab 1: Belum Selesai
                          _buildTaskList(todoTasks, submissionMap, 'todo', cardBgColor, cardBorderColor, titleColor, subTextColor, isDark),

                          // Tab 2: Terlambat
                          _buildTaskList(lateTasks, submissionMap, 'late', cardBgColor, cardBorderColor, titleColor, subTextColor, isDark),

                          // Tab 3: Selesai
                          _buildTaskList(completedTasks, submissionMap, 'completed', cardBgColor, cardBorderColor, titleColor, subTextColor, isDark),
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

  Widget _buildTaskList(
    List<Task> tasks,
    Map<String, TaskSubmission> submissionMap,
    String type,
    Color cardBgColor,
    Color cardBorderColor,
    Color titleColor,
    Color subTextColor,
    bool isDark,
  ) {
    if (tasks.isEmpty) {
      IconData icon;
      String message;
      Color iconColor;

      if (type == 'todo') {
        icon = Icons.assignment_turned_in_rounded;
        message = 'Hebat! Semua tugas telah diselesaikan.';
        iconColor = const Color(0xFF10B981);
      } else if (type == 'late') {
        icon = Icons.error_outline_rounded;
        message = 'Tidak ada tugas yang terlambat.';
        iconColor = const Color(0xFF10B981);
      } else {
        icon = Icons.folder_open_rounded;
        message = 'Belum ada tugas yang diselesaikan.';
        iconColor = subTextColor;
      }

      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 48, color: iconColor),
            const SizedBox(height: 12),
            Text(
              message,
              style: TextStyle(color: subTextColor, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(24),
      itemCount: tasks.length,
      separatorBuilder: (context, index) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final task = tasks[index];
        final submission = submissionMap[task.id];

        return Container(
          decoration: BoxDecoration(
            color: cardBgColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: cardBorderColor),
          ),
          child: ExpansionTile(
            title: Text(
              task.title,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: titleColor),
            ),
            subtitle: Text(
              '${task.subjectName} • Oleh: ${task.teacherName}',
              style: TextStyle(fontSize: 11, color: subTextColor),
            ),
            trailing: _buildTrailingIndicator(task, submission, type),
            childrenPadding: const EdgeInsets.all(16),
            expandedAlignment: Alignment.topLeft,
            textColor: titleColor,
            iconColor: titleColor,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tenggat Pengumpulan:',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: titleColor),
                  ),
                  Text(
                    _formatDateTime(task.dueDate),
                    style: TextStyle(
                      fontSize: 12,
                      color: type == 'late' ? const Color(0xFFEF4444) : titleColor,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Deskripsi/Instruksi:',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: titleColor),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    task.description,
                    style: TextStyle(fontSize: 12, color: titleColor.withValues(alpha: 0.9), height: 1.4),
                  ),
                  if (task.attachmentLink != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withValues(alpha: 0.02) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.link_rounded, size: 14, color: Color(0xFF3B82F6)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              task.attachmentLink!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 11, color: subTextColor),
                            ),
                          ),
                          GestureDetector(
                            onTap: () => _copyToClipboard(task.attachmentLink!, 'Link materi'),
                            child: const Text(
                              'Salin Link',
                              style: TextStyle(fontSize: 11, color: Color(0xFF3B82F6), fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Divider(color: cardBorderColor),
                  const SizedBox(height: 12),
                  _buildBottomAction(task, submission, type, isDark, cardBorderColor, subTextColor, titleColor),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTrailingIndicator(Task task, TaskSubmission? submission, String type) {
    if (type == 'completed' && submission != null) {
      final isGraded = submission.status == 'graded';
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isGraded
              ? const Color(0xFF10B981).withValues(alpha: 0.15)
              : const Color(0xFF3B82F6).withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          isGraded ? 'Nilai: ${submission.grade!.toStringAsFixed(0)}' : 'Terkirim',
          style: TextStyle(
            color: isGraded ? const Color(0xFF10B981) : const Color(0xFF3B82F6),
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    if (type == 'late') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFEF4444).withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text(
          'Terlambat',
          style: TextStyle(
            color: Color(0xFFEF4444),
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    // Default todo (sisa waktu hari ini atau besok)
    final difference = task.dueDate.difference(DateTime.now());
    String timeText;
    Color color;

    if (difference.inDays > 0) {
      timeText = '${difference.inDays} Hari Lagi';
      color = const Color(0xFF8B5CF6);
    } else if (difference.inHours > 0) {
      timeText = '${difference.inHours} Jam Lagi';
      color = const Color(0xFFF59E0B);
    } else {
      timeText = 'Segera Berakhir';
      color = const Color(0xFFEF4444);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        timeText,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildBottomAction(
    Task task,
    TaskSubmission? submission,
    String type,
    bool isDark,
    Color cardBorder,
    Color subTextColor,
    Color titleColor,
  ) {
    if (type == 'completed' && submission != null) {
      final isGraded = submission.status == 'graded';
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 14),
              const SizedBox(width: 6),
              Text(
                'Sudah dikumpulkan pada ${DateFormat('dd MMM yyyy, HH:mm').format(submission.submittedAt.toLocal())}',
                style: const TextStyle(fontSize: 11, color: Color(0xFF10B981), fontWeight: FontWeight.w600),
              ),
            ],
          ),
          if (submission.studentNotes != null && submission.studentNotes!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Jawaban/Catatan Anda:',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: titleColor),
            ),
            Text(
              submission.studentNotes!,
              style: TextStyle(fontSize: 12, color: titleColor.withValues(alpha: 0.8)),
            ),
          ],
          if (submission.answerLink != null && submission.answerLink!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.02) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.link_rounded, size: 14, color: Color(0xFF3B82F6)),
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
                    onTap: () => _copyToClipboard(submission.answerLink!, 'Link jawaban'),
                    child: const Icon(Icons.copy_rounded, size: 16, color: Color(0xFF3B82F6)),
                  ),
                ],
              ),
            ),
          ],
          if (isGraded) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.grade_rounded, color: Color(0xFF10B981), size: 16),
                      const SizedBox(width: 6),
                      Text(
                        'Nilai Tugas Anda: ${submission.grade!.toStringAsFixed(0)} / 100',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF10B981)),
                      ),
                    ],
                  ),
                  if (submission.teacherFeedback != null && submission.teacherFeedback!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Catatan Guru: "${submission.teacherFeedback}"',
                      style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: titleColor.withValues(alpha: 0.8)),
                    ),
                  ],
                ],
              ),
            ),
          ] else ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(Icons.hourglass_empty_rounded, color: Color(0xFF3B82F6), size: 14),
                  SizedBox(width: 6),
                  Text(
                    'Menunggu pemeriksaan & penilaian oleh Guru.',
                    style: TextStyle(fontSize: 11, color: Color(0xFF3B82F6), fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ],
        ],
      );
    }

    // Unsubmitted tasks (todo / late)
    if (widget.isParent) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: Colors.grey.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Center(
          child: Text(
            'Tugas belum dikumpulkan oleh anak.',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
          ),
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () => Get.to(() => StudentSubmitTaskPage(
              studentDocId: widget.studentDocId,
              studentName: widget.studentData['nama'] ?? 'Siswa',
              task: task,
            )),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF8B5CF6),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          elevation: 0,
        ),
        child: Text(
          type == 'late' ? 'Kumpulkan Terlambat' : 'Kumpulkan Tugas',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
      ),
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
