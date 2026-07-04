import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/routes/app_routes.dart';
import '../../../core/services/app_auth_service.dart';
import '../../../core/services/session_service.dart';
import '../../authentication/widgets/auth_background.dart';
import '../../authentication/widgets/theme_toggle_button.dart';
import '../../chat/widgets/chat_unread_badge.dart';
import '../../schools/services/school_service.dart';
import '../../students/pages/student_tasks_page.dart';
import '../../exams/pages/student_exams_page.dart';

import '../../../core/widgets/motif_card.dart';
import 'parent_payment_page.dart';

class ParentDashboardPage extends StatefulWidget {
  const ParentDashboardPage({super.key});

  @override
  State<ParentDashboardPage> createState() => _ParentDashboardPageState();
}

class _ParentDashboardPageState extends State<ParentDashboardPage> {
  final _scrollController = ScrollController();
  final _infoKey = GlobalKey();

  Map<String, dynamic>? _parentData;
  String? _schoolName;
  String? _tahunAjaran;
  String? _semester;
  String? _studentClassId;
  String? _studentClassName;
  String? _waliKelas;
  String? _waliKelasId;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final user = SessionService.currentUser;
    if (user == null) return;

    try {
      final parentDocFuture = FirebaseFirestore.instance
          .collection('schools')
          .doc(user.schoolId)
          .collection('parents')
          .doc(user.uid)
          .get();
      final schoolDataFuture = SchoolService().getSchoolByDomain(user.schoolId);

      final parentDoc = await parentDocFuture;
      final schoolData = await schoolDataFuture;
      final parentData = parentDoc.data();
      final studentId = (parentData?['studentId'] ?? '').toString();

      String? classId;
      String? namaKelas;
      String? waliKelas;
      String? waliKelasId;
      if (studentId.isNotEmpty) {
        final studentDoc = await FirebaseFirestore.instance
            .collection('schools')
            .doc(user.schoolId)
            .collection('students')
            .doc(studentId)
            .get();
        classId = studentDoc.data()?['classId'] as String?;

        if (classId != null && classId.isNotEmpty) {
          final classDoc = await FirebaseFirestore.instance
              .collection('schools')
              .doc(user.schoolId)
              .collection('classes')
              .doc(classId)
              .get();
          
          final teacherId = classDoc.data()?['teacherId'] as String?;
          namaKelas = classDoc.data()?['namaKelas'] as String?;
          waliKelasId = teacherId;
          waliKelas = classDoc.data()?['teacherName'] as String?;
          // Jika teacherName kosong, ambil dari koleksi teachers berdasarkan teacherId
          if ((waliKelas == null || waliKelas.isEmpty) &&
              teacherId != null &&
              teacherId.isNotEmpty) {
            final teacherDoc = await FirebaseFirestore.instance
                .collection('schools')
                .doc(user.schoolId)
                .collection('teachers')
                .doc(teacherId)
                .get();
            waliKelas = teacherDoc.data()?['nama'] as String?;
          }
        }
      }

      if (mounted) {
        setState(() {
          _parentData = parentData;
          _schoolName = schoolData?['namaSekolah'] as String?;
          _tahunAjaran = schoolData?['tahunAjaran'] as String?;
          _semester = schoolData?['semester'] as String?;
          _studentClassId = classId;
          _studentClassName = namaKelas;
          _waliKelas = waliKelas;
          _waliKelasId = waliKelasId;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour <= 10) return 'Selamat Pagi';
    if (hour <= 14) return 'Selamat Siang';
    if (hour <= 18) return 'Selamat Sore';
    return 'Selamat Malam';
  }

  Future<void> _logout() async {
    final isDark = AuthBackground.isDarkMode.value;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF0F0C20) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.1)
                : Colors.black.withValues(alpha: 0.1),
          ),
        ),
        title: Row(
          children: [
            const Icon(Icons.logout_rounded, color: Color(0xFFEF4444)),
            const SizedBox(width: 10),
            Text(
              'Konfirmasi Keluar',
              style: TextStyle(
                color: isDark ? Colors.white : const Color(0xFF1E1B4B),
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
        content: Text(
          'Apakah Anda yakin ingin keluar dari akun Anda?',
          style: TextStyle(
            color: isDark
                ? Colors.white70
                : const Color(0xFF1E1B4B).withValues(alpha: 0.8),
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
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              'Keluar',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await AppAuthService.logout();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (SessionService.currentUser == null) {
      Future.microtask(() => Get.offAllNamed(AppRoutes.splash));
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final user = SessionService.currentUser!;

    return ValueListenableBuilder<bool>(
      valueListenable: AuthBackground.isDarkMode,
      builder: (context, isDark, _) {
        final textColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
        final subTextColor = isDark
            ? Colors.white.withValues(alpha: 0.5)
            : const Color(0xFF1E1B4B).withValues(alpha: 0.5);
        final cardBg =
            isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white;
        final cardBorder = isDark
            ? Colors.white.withValues(alpha: 0.1)
            : Colors.black.withValues(alpha: 0.08);

        return Scaffold(
          body: AuthBackground(
            child: SafeArea(
              child: _isLoading
                  ? Center(
                      child: CircularProgressIndicator(
                        color: isDark ? Colors.white : const Color(0xFF8B5CF6),
                      ),
                    )
                  : CustomScrollView(
                      controller: _scrollController,
                      physics: const BouncingScrollPhysics(),
                      slivers: [
                        // --- HEADER SECTION ---
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _getGreeting(),
                                        style: TextStyle(
                                          color: subTextColor,
                                          fontSize: 13,
                                        ),
                                      ),
                                      Text(
                                        user.nama,
                                        style: TextStyle(
                                          color: textColor,
                                          fontSize: 22,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const ThemeToggleButton(),
                                IconButton(
                                  onPressed: _logout,
                                  icon: const Icon(Icons.logout_rounded, color: Color(0xFFEF4444)),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // --- HERO STUDENT CARD ---
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: MotifCard(
                              isDark: isDark,
                              padding: const EdgeInsets.all(24),
                              cardColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
                              borderRadius: 28,
                              cardBorderColor: Colors.transparent,
                              cardShadowColor: isDark ? Colors.black.withValues(alpha: 0.3) : Colors.black.withValues(alpha: 0.06),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 32,
                                        backgroundColor:
                                            textColor.withValues(alpha: 0.1),
                                        child: Text(
                                          (_parentData?['studentName']?[0] ??
                                              'A'),
                                          style: TextStyle(
                                            color: textColor,
                                            fontSize: 28,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 10,
                                                vertical: 4,
                                              ),
                                              decoration: BoxDecoration(
                                                color: textColor.withValues(alpha: 0.05),
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                              ),
                                              child: Text(
                                                'Siswa Terhubung',
                                                style: TextStyle(
                                                  color: textColor,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              _parentData?['studentName'] ?? '-',
                                              style: TextStyle(
                                                color: textColor,
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            Text(
                                              'Kelas ${_studentClassName ?? _parentData?['className'] ?? '-'}',
                                              style: TextStyle(
                                                color: textColor.withValues(alpha: 0.8),
                                                fontSize: 13,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 20),
                                  Divider(
                                      color:
                                          textColor.withValues(alpha: 0.1)),
                                  const SizedBox(height: 12),
                                  Center(
                                    child: _heroSmallInfo(
                                        Icons.business_rounded,
                                        _schoolName ?? 'Sekolah',
                                        textColor),
                                  ),
                                  const SizedBox(height: 10),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: textColor.withValues(alpha: 0.05),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      '${_semester ?? '-'} • Tahun Ajaran ${_tahunAjaran ?? '-'}',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: textColor,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        // --- MENU GRID ---
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildSectionTitle(
                                  'Menu Utama',
                                  Icons.dashboard_rounded,
                                  textColor,
                                  subTextColor,
                                ),
                                const SizedBox(height: 16),
                                _buildMenuGrid(
                                  isDark,
                                  textColor,
                                  cardBg,
                                  cardBorder,
                                  user.schoolId,
                                  (_parentData?['studentId'] ?? '').toString(),
                                  _studentClassId,
                                  _studentClassName ?? _parentData?['className'],
                                  (_parentData?['studentName'] ?? 'Anak'),
                                  _tahunAjaran,
                                  _semester,
                                ),
                              ],
                            ),
                          ),
                        ),

                        // --- DETAIL INFO SECTION ---
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(24, 32, 24, 0),
                            child: Column(
                              key: _infoKey,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildSectionTitle(
                                  'Informasi Tambahan',
                                  Icons.info_outline_rounded,
                                  textColor,
                                  subTextColor,
                                ),
                                const SizedBox(height: 16),
                                _gridCard(
                                  icon: Icons.person_pin_rounded,
                                  label: 'Wali Kelas',
                                  value: _waliKelas ?? 'Belum tersedia',
                                  color: const Color(0xFF6366F1),
                                  isDark: isDark,
                                  cardBg: cardBg,
                                  cardBorder: cardBorder,
                                  textColor: textColor,
                                  subTextColor: subTextColor,
                                  fullWidth: true,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SliverToBoxAdapter(child: SizedBox(height: 40)),
                      ],
                    ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSectionTitle(
    String title,
    IconData icon,
    Color textColor,
    Color subTextColor,
  ) {
    return Row(
      children: [
        Icon(icon, color: subTextColor, size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: textColor,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  void _scrollToSection(GlobalKey key) {
    final context = key.currentContext;
    if (context == null) return;
    Scrollable.ensureVisible(
      context,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
      alignment: 0.05,
    );
  }

  Widget _buildMenuGrid(
    bool isDark,
    Color textColor,
    Color cardBg,
    Color cardBorder,
    String schoolId,
    String studentId,
    String? classId,
    String? className,
    String? studentName,
    String? tahunAjaran,
    String? semester,
  ) {
    final menus = [
      {
        'title': 'Daftar Hadir',
        'icon': Icons.fact_check_rounded,
        'color': const Color(0xFF10B981),
        'onTap': () => Get.toNamed(AppRoutes.parentAttendance, arguments: {
              'schoolId': schoolId,
              'studentId': studentId,
              'className': className,
              'studentName': studentName,
            }),
      },
      {
        'title': 'Jadwal Kelas',
        'icon': Icons.calendar_month_rounded,
        'color': const Color(0xFFF59E0B),
        'onTap': () => Get.toNamed(AppRoutes.parentSchedule, arguments: {
              'className': className,
            }),
      },
      {
        'title': 'Pelanggaran',
        'icon': Icons.warning_amber_rounded,
        'color': const Color(0xFFEF4444),
        'onTap': () => Get.toNamed(AppRoutes.parentViolations, arguments: {
              'schoolId': schoolId,
              'studentId': studentId,
            }),
      },
      {
        'title': 'Nilai Anak',
        'icon': Icons.grade_rounded,
        'color': const Color(0xFF8B5CF6),
        'onTap': () => Get.toNamed(AppRoutes.parentGrades, arguments: {
              'schoolId': schoolId,
              'studentId': studentId,
              'classId': classId,
              'className': className,
              'tahunAjaran': tahunAjaran,
              'semester': semester,
            }),
      },
      {
        'title': 'Tugas Anak',
        'icon': Icons.assignment_rounded,
        'color': const Color(0xFF6366F1),
        'onTap': () => Get.to(
              () => StudentTasksPage(
                studentDocId: studentId,
                studentData: {
                  'classId': classId ?? '',
                  'nama': studentName ?? 'Anak',
                },
                className: className ?? '',
                tahunAjaran: tahunAjaran ?? '-',
                semester: semester ?? '-',
                isParent: true,
              ),
            ),
      },
      {
        'title': 'Ujian Online Anak',
        'icon': Icons.quiz_rounded,
        'color': const Color(0xFF8B5CF6),
        'onTap': () {
          if (classId == null || classId.isEmpty) {
            Get.snackbar(
              'Informasi',
              'Anak Anda belum terdaftar di kelas manapun.',
              snackPosition: SnackPosition.BOTTOM,
              backgroundColor: Colors.amber,
              colorText: Colors.black,
            );
          } else {
            Get.to(() => StudentExamsPage(classId: classId));
          }
        },
      },
      {
        'title': 'Chat Guru',
        'icon': Icons.chat_bubble_outline_rounded,
        'color': const Color(0xFFF97316),
        'onTap': () => Get.toNamed(AppRoutes.parentChat, arguments: {
              'schoolId': schoolId,
              'parentDocId': SessionService.currentUser?.uid ?? '',
              'parentName': SessionService.currentUser?.nama ?? '',
              'studentName': studentName,
              'className': className,
            }),
      },
      {
        'title': 'Informasi',
        'icon': Icons.info_outline_rounded,
        'color': const Color(0xFF6366F1),
        'onTap': () => _scrollToSection(_infoKey),
        'badge': null,
      },
      {
        'title': 'Surat Izin Digital',
        'icon': Icons.mark_email_read_rounded,
        'color': const Color(0xFF8B5CF6),
        'onTap': () => Get.toNamed(
              AppRoutes.parentPermit,
              arguments: {
                'studentId': studentId,
                'studentName': studentName,
                'classId': classId,
                'className': className,
                'waliKelasId': _waliKelasId ?? '',
                'waliKelasName': _waliKelas ?? 'Wali Kelas',
              },
            ),
      },

      {
        'title': 'Tagihan SPP & Keuangan',
        'icon': Icons.payments_rounded,
        'color': const Color(0xFF10B981),
        'onTap': () {
          if (studentId.isEmpty) {
            Get.snackbar(
              'Informasi',
              'Akun Anda belum terhubung dengan data murid manapun.',
              snackPosition: SnackPosition.BOTTOM,
              backgroundColor: Colors.amber,
              colorText: Colors.black,
            );
          } else {
            Get.to(() => ParentPaymentPage(
              schoolId: schoolId,
              studentId: studentId,
              studentName: studentName ?? 'Anak',
            ));
          }
        },
      },
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.1,
      ),
      itemCount: menus.length,
      itemBuilder: (context, index) {
        final menu = menus[index];
        final color = menu['color'] as Color;
        final onTap = menu['onTap'] as VoidCallback;
        final badge = menu['badge'] as String?;
        return Container(
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: cardBorder),
            boxShadow: isDark
                ? []
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(20),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Builder(
                          builder: (context) {
                            final container = Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                menu['icon'] as IconData,
                                color: color,
                                size: 32,
                              ),
                            );

                            if (menu['title'] == 'Chat Guru' && SessionService.currentUser?.uid != null) {
                              return ChatUnreadBadge(
                                schoolId: schoolId,
                                userId: SessionService.currentUser!.uid,
                                role: 'parent',
                                top: -2,
                                right: -2,
                                child: container,
                              );
                            }

                            if (menu['title'] == 'Tagihan SPP & Keuangan' && studentId.isNotEmpty) {
                              return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                                stream: FirebaseFirestore.instance
                                    .collection('schools')
                                    .doc(schoolId)
                                    .collection('student_bills')
                                    .where('studentId', isEqualTo: studentId)
                                    .where('status', isEqualTo: 'unpaid')
                                    .snapshots(),
                                builder: (context, billsSnapshot) {
                                  final unpaidCount = billsSnapshot.data?.docs.length ?? 0;
                                  if (unpaidCount == 0) return container;

                                  return Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      container,
                                      Positioned(
                                        top: -4,
                                        right: -4,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.redAccent,
                                            borderRadius: BorderRadius.circular(10),
                                            border: Border.all(
                                              color: isDark ? const Color(0xFF0F0C20) : Colors.white,
                                              width: 1.5,
                                            ),
                                          ),
                                          constraints: const BoxConstraints(
                                            minWidth: 18,
                                            minHeight: 18,
                                          ),
                                          child: Center(
                                            child: Text(
                                              '$unpaidCount',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 9,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              );
                            }

                            if (menu['title'] == 'Tugas Anak' &&
                                studentId.isNotEmpty &&
                                classId != null &&
                                classId.isNotEmpty) {
                              return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                                stream: FirebaseFirestore.instance
                                    .collection('schools')
                                    .doc(schoolId)
                                    .collection('tasks')
                                    .where('classId', isEqualTo: classId)
                                    .snapshots(),
                                builder: (context, tasksSnapshot) {
                                  final tasks = tasksSnapshot.data?.docs ?? [];
                                  if (tasks.isEmpty) return container;

                                  return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                                    stream: FirebaseFirestore.instance
                                        .collection('schools')
                                        .doc(schoolId)
                                        .collection('task_submissions')
                                        .where('studentId', isEqualTo: studentId)
                                        .snapshots(),
                                    builder: (context, submissionsSnapshot) {
                                      final submissions = submissionsSnapshot.data?.docs ?? [];
                                      final submittedTaskIds = submissions
                                          .map((doc) => doc.data()['taskId']?.toString())
                                          .toSet();

                                      final pendingCount = tasks.where((taskDoc) {
                                        final taskId = taskDoc.id;
                                        final taskData = taskDoc.data();
                                        final status = taskData['status']?.toString() ?? 'active';
                                        final taskTahunAjaran = taskData['tahunAjaran']?.toString();
                                        final taskSemester = taskData['semester']?.toString();

                                        if (status != 'active') return false;
                                        if (taskTahunAjaran != tahunAjaran ||
                                            taskSemester != semester) {
                                          return false;
                                        }

                                        // Jika tugas belum dikerjakan, tapi sudah melewati tenggat waktu (dueDate), jangan dihitung
                                        final dueDateObj = taskData['dueDate'];
                                        if (dueDateObj != null && dueDateObj is Timestamp) {
                                          final dueDate = dueDateObj.toDate();
                                          if (dueDate.isBefore(DateTime.now())) {
                                            return false;
                                          }
                                        }

                                        return !submittedTaskIds.contains(taskId);
                                      }).length;

                                      if (pendingCount > 0) {
                                        return Stack(
                                          clipBehavior: Clip.none,
                                          children: [
                                            container,
                                            Positioned(
                                              top: -4,
                                              right: -4,
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: Colors.redAccent,
                                                  borderRadius: BorderRadius.circular(10),
                                                  border: Border.all(
                                                    color: isDark ? const Color(0xFF0F0C20) : Colors.white,
                                                    width: 1.5,
                                                  ),
                                                ),
                                                constraints: const BoxConstraints(
                                                  minWidth: 18,
                                                  minHeight: 18,
                                                ),
                                                child: Center(
                                                  child: Text(
                                                    '$pendingCount',
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 9,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        );
                                      }
                                      return container;
                                    },
                                  );
                                },
                              );
                            }

                            return container;
                          },
                        ),
                        const SizedBox(height: 12),
                        Text(
                          menu['title'] as String,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: textColor,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (badge != null)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: _buildPackageBadge(badge),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }


  Widget _buildPackageBadge(String badge) {
    final isBasic = badge == 'BASIC';
    final gradient = isBasic
        ? const LinearGradient(
            colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
        : const LinearGradient(
            colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: (isBasic ? const Color(0xFF3B82F6) : const Color(0xFFF59E0B))
                .withValues(alpha: 0.4),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        badge,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 8,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _heroSmallInfo(IconData icon, String text, Color textColor) {
    return Row(
      children: [
        Icon(icon, color: textColor.withValues(alpha: 0.7), size: 16),
        const SizedBox(width: 8),
        Text(
          text,
          style: TextStyle(
            color: textColor,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _gridCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required bool isDark,
    required Color cardBg,
    required Color cardBorder,
    required Color textColor,
    required Color subTextColor,
    bool fullWidth = false,
  }) {
    return Container(
      width: fullWidth ? double.infinity : null,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cardBorder),
      ),
      child: fullWidth
          ? Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label,
                          style:
                              TextStyle(color: subTextColor, fontSize: 11)),
                      const SizedBox(height: 4),
                      Text(
                        value,
                        style: TextStyle(
                          color: textColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(height: 12),
                Text(label,
                    style: TextStyle(color: subTextColor, fontSize: 11)),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
    );
  }
}