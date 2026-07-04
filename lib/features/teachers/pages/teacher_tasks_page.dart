import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../../core/services/session_service.dart';
import '../../authentication/widgets/auth_background.dart';
import '../../schools/services/school_service.dart';
import '../../tasks/models/task_model.dart';
import '../../tasks/services/task_service.dart';
import 'teacher_create_task_page.dart';
import 'teacher_task_detail_page.dart';

class TeacherTasksPage extends StatefulWidget {
  final String teacherId;
  final bool hideBackButton;
  const TeacherTasksPage({
    super.key,
    required this.teacherId,
    this.hideBackButton = false,
  });

  @override
  State<TeacherTasksPage> createState() => _TeacherTasksPageState();
}

class _TeacherTasksPageState extends State<TeacherTasksPage> {
  final _taskService = TaskService();

  bool _isLoadingSchedules = true;
  Map<String, Map<String, dynamic>> _classMap = {};
  String? _selectedFilterClassId;
  String? _selectedFilterSubjectId;
  String? _tahunAjaran;
  String? _activeSemester;

  @override
  void initState() {
    super.initState();
    _loadTeacherSchedules();
  }

  Future<void> _loadTeacherSchedules() async {
    final user = SessionService.currentUser!;
    try {
      final schoolData = await SchoolService().getSchoolByDomain(user.schoolId);
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

      if (mounted) {
        setState(() {
          _classMap = tempClassMap;
          _tahunAjaran = schoolData?['tahunAjaran'];
          _activeSemester = schoolData?['semester'];
          _isLoadingSchedules = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading schedules: $e');
      if (mounted) {
        setState(() {
          _isLoadingSchedules = false;
        });
      }
    }
  }

  String _getFormattedIndonesianDate(DateTime dateTime) {
    final days = ['Minggu', 'Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu'];
    final months = [
      'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
    ];
    final dayName = days[dateTime.weekday % 7];
    final monthName = months[dateTime.month - 1];
    return '$dayName, ${dateTime.day} $monthName ${dateTime.year} - ${DateFormat('HH:mm').format(dateTime.toLocal())} WIB';
  }

  Future<void> _confirmDelete(BuildContext context, String schoolId, Task task) async {
    final isDark = AuthBackground.isDarkMode.value;

    try {
      final query = await FirebaseFirestore.instance
          .collection('schools')
          .doc(schoolId)
          .collection('taskDeleteRequests')
          .where('taskId', isEqualTo: task.id)
          .where('status', isEqualTo: 'pending')
          .get();
          
      if (query.docs.isNotEmpty) {
        if (context.mounted) {
          Get.snackbar(
            'Info',
            'Pengajuan hapus tugas sedang menunggu persetujuan Admin/TU.',
            snackPosition: SnackPosition.TOP,
            backgroundColor: const Color(0xFFF59E0B),
            colorText: Colors.white,
            borderRadius: 12,
            margin: const EdgeInsets.all(16),
          );
        }
        return;
      }
    } catch (e) {
      // Ignore
    }

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF0F0C20) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.1),
          ),
        ),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Color(0xFFF59E0B)),
            const SizedBox(width: 10),
            Text(
              'Ajukan Hapus Tugas',
              style: TextStyle(
                color: isDark ? Colors.white : const Color(0xFF1E1B4B),
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
        content: Text(
          'Apakah Anda yakin ingin mengajukan penghapusan tugas "${task.title}" ke Admin/TU? Penghapusan akan menghapus seluruh file jawaban murid.',
          style: TextStyle(
            color: isDark ? Colors.white70 : const Color(0xFF1E1B4B).withValues(alpha: 0.8),
            fontSize: 14,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Batal',
              style: TextStyle(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.5)
                    : const Color(0xFF1E1B4B).withValues(alpha: 0.5),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF59E0B),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Ajukan', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await FirebaseFirestore.instance
            .collection('schools')
            .doc(schoolId)
            .collection('taskDeleteRequests')
            .add({
          'taskId': task.id,
          'taskTitle': task.title,
          'className': task.className,
          'subjectName': task.subjectName,
          'requestedBy': task.teacherId,
          'requestedByName': SessionService.currentUser?.nama ?? task.teacherName,
          'requestedAt': FieldValue.serverTimestamp(),
          'status': 'pending',
        });
        
        if (context.mounted) {
          Get.snackbar(
            'Sukses',
            'Pengajuan penghapusan tugas berhasil dikirim.',
            snackPosition: SnackPosition.TOP,
            backgroundColor: const Color(0xFF10B981),
            colorText: Colors.white,
            borderRadius: 12,
            margin: const EdgeInsets.all(16),
          );
        }
      } catch (e) {
        if (context.mounted) {
          Get.snackbar(
            'Gagal',
            'Gagal mengirim pengajuan: $e',
            snackPosition: SnackPosition.TOP,
            backgroundColor: const Color(0xFFEF4444),
            colorText: Colors.white,
            borderRadius: 12,
            margin: const EdgeInsets.all(16),
          );
        }
      }
    }
  }

  Widget _buildDeleteRequestBadge(String status) {
    final isPending = status == 'pending';
    final isRejected = status == 'rejected';
    if (!isPending && !isRejected) return const SizedBox.shrink();

    final color = isPending ? const Color(0xFFF59E0B) : const Color(0xFFEF4444);
    final text = isPending ? 'Menunggu Persetujuan' : 'Hapus Ditolak';
    final icon = isPending ? Icons.hourglass_empty_rounded : Icons.cancel_outlined;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
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
        final cardBorderColor = isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.08);
        final iconBgColor = isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05);
        final iconColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
        final inputFillColor = isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04);
        final shadowColor = isDark ? Colors.transparent : Colors.black.withValues(alpha: 0.04);

        return Scaffold(
          body: AuthBackground(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                // AppBar
                SliverAppBar(
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  pinned: true,
                  automaticallyImplyLeading: !widget.hideBackButton,
                  iconTheme: IconThemeData(color: iconColor),
                  leading: widget.hideBackButton
                      ? null
                      : Container(
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
                    'Manajemen Tugas',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: titleColor),
                  ),
                ),

                if (_isLoadingSchedules)
                  SliverFillRemaining(
                    child: Center(
                      child: CircularProgressIndicator(
                        color: isDark ? Colors.white : const Color(0xFF8B5CF6),
                      ),
                    ),
                  ),

                if (!_isLoadingSchedules)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: cardBgColor,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: cardBorderColor),
                          boxShadow: isDark ? [] : [
                            BoxShadow(
                              color: shadowColor,
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.filter_alt_rounded, color: Color(0xFF3B82F6), size: 18),
                                const SizedBox(width: 8),
                                Text(
                                  'Filter Tugas',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: titleColor,
                                  ),
                                ),
                                const Spacer(),
                                if (_selectedFilterClassId != null || _selectedFilterSubjectId != null)
                                  GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _selectedFilterClassId = null;
                                        _selectedFilterSubjectId = null;
                                      });
                                    },
                                    child: const Text(
                                      'Reset',
                                      style: TextStyle(
                                        color: Color(0xFFEF4444),
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                // Dropdown Kelas
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    isExpanded: true,
                                    value: _selectedFilterClassId,
                                    dropdownColor: isDark ? const Color(0xFF0F0C20) : Colors.white,
                                    decoration: InputDecoration(
                                      labelText: 'Kelas',
                                      labelStyle: TextStyle(color: subTextColor, fontSize: 11),
                                      fillColor: inputFillColor,
                                      filled: true,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(color: cardBorderColor),
                                      ),
                                    ),
                                    style: TextStyle(color: titleColor, fontSize: 13),
                                    items: [
                                      const DropdownMenuItem<String>(
                                        value: null,
                                        child: Text('Semua Kelas'),
                                      ),
                                      ..._classMap.keys.map((classId) {
                                        return DropdownMenuItem<String>(
                                          value: classId,
                                          child: Text(_classMap[classId]?['className']?.toString() ?? ''),
                                        );
                                      })
                                    ],
                                    onChanged: (val) {
                                      setState(() {
                                        _selectedFilterClassId = val;
                                        _selectedFilterSubjectId = null; // Reset mapel
                                      });
                                    },
                                  ),
                                ),
                                const SizedBox(width: 10),
                                // Dropdown Mapel
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    isExpanded: true,
                                    value: _selectedFilterSubjectId,
                                    dropdownColor: isDark ? const Color(0xFF0F0C20) : Colors.white,
                                    decoration: InputDecoration(
                                      labelText: 'Mata Pelajaran',
                                      labelStyle: TextStyle(color: subTextColor, fontSize: 11),
                                      fillColor: inputFillColor,
                                      filled: true,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(color: cardBorderColor),
                                      ),
                                    ),
                                    style: TextStyle(color: titleColor, fontSize: 13),
                                    items: () {
                                      Map<String, String> subjectsList = {};
                                      if (_selectedFilterClassId != null) {
                                        final classData = _classMap[_selectedFilterClassId];
                                        if (classData != null && classData['subjects'] != null) {
                                          subjectsList = Map<String, String>.from(classData['subjects'] as Map);
                                        }
                                      } else {
                                        for (final classId in _classMap.keys) {
                                          final classData = _classMap[classId];
                                          if (classData != null && classData['subjects'] != null) {
                                            subjectsList.addAll(Map<String, String>.from(classData['subjects'] as Map));
                                          }
                                        }
                                      }
                                      return [
                                        const DropdownMenuItem<String>(
                                          value: null,
                                          child: Text('Semua Mapel'),
                                        ),
                                        ...subjectsList.keys.map((subjectId) {
                                          return DropdownMenuItem<String>(
                                            value: subjectId,
                                            child: Text(subjectsList[subjectId] ?? ''),
                                          );
                                        })
                                      ];
                                    }(),
                                    onChanged: (val) {
                                      setState(() {
                                        _selectedFilterSubjectId = val;
                                      });
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                // List Data
                if (!_isLoadingSchedules)
                  StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: FirebaseFirestore.instance
                        .collection('schools')
                        .doc(user.schoolId)
                        .collection('taskDeleteRequests')
                        .where('requestedBy', isEqualTo: widget.teacherId)
                        .snapshots(),
                    builder: (context, requestsSnapshot) {
                      final requestsDocs = requestsSnapshot.data?.docs ?? [];
                      final Map<String, String> requestStatusMap = {};
                      
                      // Sort ascending by requestedAt so the latest overrides
                      final sortedRequests = List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(requestsDocs)
                        ..sort((a, b) {
                          final ta = a.data()['requestedAt'] as Timestamp?;
                          final tb = b.data()['requestedAt'] as Timestamp?;
                          if (ta == null && tb == null) return 0;
                          if (ta == null) return -1;
                          if (tb == null) return 1;
                          return ta.compareTo(tb);
                        });

                      for (final doc in sortedRequests) {
                        final data = doc.data();
                        final taskId = data['taskId'] as String?;
                        final status = data['status'] as String?;
                        if (taskId != null && status != null) {
                          requestStatusMap[taskId] = status;
                        }
                      }

                      return StreamBuilder<List<Task>>(
                        stream: _taskService.getTasksByTeacher(
                          schoolId: user.schoolId,
                          teacherId: widget.teacherId,
                          classId: _selectedFilterClassId,
                          subjectId: _selectedFilterSubjectId,
                          tahunAjaran: _tahunAjaran ?? '-',
                          semester: _activeSemester ?? '-',
                        ),
                        builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return SliverFillRemaining(
                          child: Center(
                            child: Text(
                              'Gagal memuat data tugas: ${snapshot.error}',
                              style: const TextStyle(color: Colors.redAccent),
                            ),
                          ),
                        );
                      }

                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return SliverFillRemaining(
                          child: Center(
                            child: CircularProgressIndicator(
                              color: isDark ? Colors.white : const Color(0xFF8B5CF6),
                            ),
                          ),
                        );
                      }

                      final tasks = snapshot.data ?? [];

                      if (tasks.isEmpty) {
                        return SliverFillRemaining(
                          hasScrollBody: false,
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.assignment_rounded,
                                  size: 64,
                                  color: subTextColor.withValues(alpha: 0.3),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Belum ada tugas yang dibuat',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: titleColor,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Tekan tombol "+" di bawah untuk membuat tugas baru.',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: subTextColor,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      // Sort tasks by due date descending in memory
                      final sortedTasks = tasks..sort((a, b) => b.dueDate.compareTo(a.dueDate));

                      return SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final task = sortedTasks[index];

                              return Container(
                                margin: const EdgeInsets.only(bottom: 16),
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
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(24),
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: () => Get.to(() => TeacherTaskDetailPage(
                                            schoolId: user.schoolId,
                                            task: task,
                                          )),
                                      child: Padding(
                                        padding: const EdgeInsets.all(20),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                // Category/Subject Tag & Request Status Badge
                                                Row(
                                                  children: [
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                      decoration: BoxDecoration(
                                                        color: const Color(0xFF3B82F6).withValues(alpha: 0.15),
                                                        borderRadius: BorderRadius.circular(10),
                                                        border: Border.all(color: const Color(0xFF3B82F6).withValues(alpha: 0.3)),
                                                      ),
                                                      child: Text(
                                                        task.subjectName,
                                                        style: const TextStyle(
                                                          color: Color(0xFF3B82F6),
                                                          fontSize: 11,
                                                          fontWeight: FontWeight.bold,
                                                        ),
                                                      ),
                                                    ),
                                                    if (requestStatusMap[task.id] != null) ...[
                                                      const SizedBox(width: 8),
                                                      _buildDeleteRequestBadge(requestStatusMap[task.id]!),
                                                    ],
                                                  ],
                                                ),
                                                IconButton(
                                                  icon: const Icon(Icons.delete_rounded, color: Color(0xFFEF4444), size: 20),
                                                  tooltip: 'Hapus Tugas',
                                                  onPressed: () => _confirmDelete(context, user.schoolId, task),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              task.title,
                                              style: TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                                color: titleColor,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              'Kelas: ${task.className}',
                                              style: const TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                                color: Color(0xFF10B981),
                                              ),
                                            ),
                                            const SizedBox(height: 12),
                                            Divider(color: cardBorderColor),
                                            const SizedBox(height: 12),
                                            Row(
                                              children: [
                                                Icon(Icons.access_time_rounded, color: subTextColor, size: 14),
                                                const SizedBox(width: 6),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        'Tenggat Waktu',
                                                        style: TextStyle(fontSize: 10, color: subTextColor),
                                                      ),
                                                      Text(
                                                        _getFormattedIndonesianDate(task.dueDate),
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          fontWeight: FontWeight.w600,
                                                          color: task.dueDate.isBefore(DateTime.now())
                                                              ? const Color(0xFFEF4444)
                                                              : titleColor,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                // Realtime submission count indicator
                                                StreamBuilder<List<TaskSubmission>>(
                                                  stream: _taskService.getSubmissionsForTask(
                                                    schoolId: user.schoolId,
                                                    taskId: task.id,
                                                  ),
                                                  builder: (context, subSnapshot) {
                                                    final count = subSnapshot.data?.length ?? 0;
                                                    return Column(
                                                      crossAxisAlignment: CrossAxisAlignment.end,
                                                      children: [
                                                        Text(
                                                          'Mengumpulkan',
                                                          style: TextStyle(fontSize: 10, color: subTextColor),
                                                        ),
                                                        Text(
                                                          '$count Pengumpulan',
                                                          style: TextStyle(
                                                            fontSize: 12,
                                                            fontWeight: FontWeight.bold,
                                                            color: count > 0 ? const Color(0xFF10B981) : subTextColor,
                                                          ),
                                                        ),
                                                      ],
                                                    );
                                                  },
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                            childCount: sortedTasks.length,
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
          ],
            ),
          ),
          floatingActionButton: FloatingActionButton(
            backgroundColor: const Color(0xFF8B5CF6),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            onPressed: () {
              if (_classMap.isEmpty) {
                Get.snackbar(
                  'Info',
                  'Anda tidak memiliki jadwal mengajar terdaftar.',
                  snackPosition: SnackPosition.TOP,
                  backgroundColor: Colors.amber,
                  colorText: Colors.black,
                  margin: const EdgeInsets.all(16),
                );
                return;
              }
              Get.to(() => TeacherCreateTaskPage(
                    teacherId: widget.teacherId,
                    classMap: _classMap,
                    tahunAjaran: _tahunAjaran ?? '-',
                    semester: _activeSemester ?? '-',
                  ));
            },
            child: const Icon(Icons.add_rounded, size: 28),
          ),
        );
      },
    );
  }
}
