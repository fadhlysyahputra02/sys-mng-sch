import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../app/routes/app_routes.dart';
import '../../../core/services/app_auth_service.dart';
import '../../../core/services/session_service.dart';
import '../../authentication/widgets/auth_background.dart';
import '../../librarian/pages/librarian_dashboard_page.dart';
import '../../chat/teacher_chat_selector_page.dart';
import '../../chat/widgets/chat_unread_badge.dart';
import '../../schools/pages/schedule/Service/class_schedule_service.dart';
import '../../schools/pages/teachers/data/teacher_service.dart';
import '../../schools/pages/teachers/data/teacher_subject_service.dart';
import '../../schools/services/school_service.dart';
import 'teacher_schedule_page.dart';
import 'teacher_settings_page.dart';
import 'teacher_attendance_schedule_page.dart';
import 'teacher_behavior_records_page.dart';
import 'teacher_grades_page.dart';
import 'teacher_reports_page.dart';
import 'teacher_daily_attendance_page.dart';
import 'teacher_tasks_page.dart';
import '../../../core/widgets/flip_card.dart';
import 'teacher_permits_page.dart';
import '../../exams/pages/teacher_exams_page.dart';
import '../../exams/models/exam_event_model.dart';
import '../../exams/pages/teacher_proctor_dashboard_page.dart';
import '../../exams/services/exam_session_service.dart';
import 'teacher_student_violations_page.dart';
import 'teacher_my_students_page.dart';
import '../../librarian/services/library_service.dart';
import '../../students/pages/student_qr_scanner_page.dart';
import '../../officer/pages/officer_dashboard_page.dart';
import '../../schools/pages/notifications/notifications_page.dart';
import '../../../core/localization/app_localization.dart';


import '../../../core/widgets/motif_card.dart';

class TeacherDashboard extends StatefulWidget {
  const TeacherDashboard({super.key});

  @override
  State<TeacherDashboard> createState() => _TeacherDashboardState();
}

class _TeacherDashboardState extends State<TeacherDashboard> {
  final _teacherService = TeacherService();
  final _scheduleService = ClassScheduleService();
  final _teacherSubjectService = TeacherSubjectService();
  final _libraryService = LibraryService();

  // Teacher Firestore doc ID (berbeda dengan Firebase Auth UID)
  String? _teacherDocId;
  Map<String, dynamic>? _teacherData;
  bool _isLoadingTeacher = true;


  // --- Library Visitor Scan ---
  Future<void> _scanLibraryVisitor(BuildContext context) async {
    final result = await Get.to<String>(() => const StudentQrScannerPage(
          title: 'Scan QR Buku Tamu Perpustakaan',
          subtitle: 'Arahkan kamera ke QR Kartu Siswa/Guru untuk mencatat kunjungan',
        ));

    if (result != null && result.isNotEmpty) {
      try {
        final Map<String, dynamic> payload = jsonDecode(result);
        final isTeacher = payload['role']?.toString().toLowerCase() == 'teacher';

        final id = isTeacher 
            ? (payload['teacherId']?.toString() ?? '')
            : (payload['studentId']?.toString() ?? '');
        final nis = isTeacher
            ? (payload['nip']?.toString() ?? '')
            : (payload['nis']?.toString() ?? '');
        final name = payload['nama']?.toString() ?? '';
        final className = isTeacher ? 'GURU' : (payload['className']?.toString() ?? '-');
        final role = isTeacher ? 'teacher' : 'student';

        if (id.isEmpty || name.isEmpty) {
          Get.snackbar('Gagal', 'Data QR tidak valid.',
              backgroundColor: Colors.red, colorText: Colors.white,
              snackPosition: SnackPosition.TOP, margin: const EdgeInsets.all(16));
          return;
        }

        await _libraryService.recordVisitor(
          studentId: id,
          studentNis: nis,
          studentName: name,
          className: className,
          role: role,
        );

        Get.snackbar(
          'Berhasil Mencatat Kunjungan',
          'Selamat datang di perpustakaan, $name!',
          backgroundColor: const Color(0xFF10B981),
          colorText: Colors.white,
          snackPosition: SnackPosition.TOP,
          margin: const EdgeInsets.all(16),
          borderRadius: 12,
        );
      } catch (e) {
        Get.snackbar('Gagal', 'Format QR Code tidak dikenali.',
            backgroundColor: Colors.red, colorText: Colors.white,
            snackPosition: SnackPosition.TOP, margin: const EdgeInsets.all(16));
      }
    }
  }
  Set<String> _teacherClassIds = {};
  StreamSubscription? _waliClassesSub;
  StreamSubscription? _scheduleClassesSub;

  String? _schoolName;
  String _plan = 'FREE';
  bool _isLoadingSchool = true;
  bool _hasUnsubmittedExamQuestions = false; // ← red dot for Ujian Semester sidebar
  String? _tahunAjaran;
  String? _activeSemester;
  String? _schoolLogoBase64;
  int _selectedMenuIndex = 0;
  Map<String, String> _classIdToAngkatan = {};

  @override
  void initState() {
    super.initState();
    _resolveTeacherDocId();
  }

  @override
  void dispose() {
    _waliClassesSub?.cancel();
    _scheduleClassesSub?.cancel();
    super.dispose();
  }

  Future<void> _loadAngkatanMapping() async {
    final user = SessionService.currentUser;
    if (user == null) return;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('schools')
          .doc(user.schoolId)
          .collection('students')
          .get();

      final Map<String, Map<String, int>> classAngkatanCounts = {};
      for (final doc in snap.docs) {
        final data = doc.data();
        final cid = data['classId'] as String? ?? '';
        final angkatan = (data['angkatan'] ?? '').toString().trim();
        final isLulus = data['lulus'] == true;
        final isAktif = data['aktif'] ?? true;
        if (cid.isNotEmpty && angkatan.isNotEmpty && !isLulus && isAktif) {
          classAngkatanCounts.putIfAbsent(cid, () => {});
          classAngkatanCounts[cid]![angkatan] = (classAngkatanCounts[cid]![angkatan] ?? 0) + 1;
        }
      }

      final Map<String, String> mapping = {};
      classAngkatanCounts.forEach((cid, counts) {
        if (counts.isNotEmpty) {
          mapping[cid] = counts.entries.reduce((a, b) => a.value > b.value ? a : b).key;
        }
      });

      if (mounted) {
        setState(() {
          _classIdToAngkatan = mapping;
        });
      }
    } catch (_) {}
  }

  /// Langkah paling penting: cari dokumen guru di subcollection teachers
  /// berdasarkan Firebase Auth UID, lalu simpan teacherId (doc.id)
  Future<void> _resolveTeacherDocId() async {
    if (SessionService.currentUser == null) return;
    final user = SessionService.currentUser!;
    await _loadAngkatanMapping();

    // Load school and teacher in parallel
    final results = await Future.wait([
      SchoolService().getSchoolByDomain(user.schoolId),
      _teacherService.getTeacherByUid(user.schoolId, user.uid),
    ]);

    final schoolData = results[0] as Map<String, dynamic>?;
    final doc = results[1] as DocumentSnapshot<Map<String, dynamic>>?;

    if (mounted) {
      setState(() {
        if (schoolData != null) {
          _schoolName = schoolData['namaSekolah'];
          _plan = (schoolData['plan'] ?? 'FREE').toString().toUpperCase();
          _tahunAjaran = schoolData['tahunAjaran'];
          _activeSemester = schoolData['semester'];
          _schoolLogoBase64 = schoolData['logoBase64'] as String?;
        }
        _teacherDocId = doc?.id;
        _teacherData = doc?.data();
        _isLoadingTeacher = false;
        _isLoadingSchool = false;
      });
    }

    if (doc != null) {
      _loadTeacherClassIds(user.schoolId, doc.id);
    }
  }

  void _loadTeacherClassIds(String schoolId, String teacherDocId) {
    _waliClassesSub?.cancel();
    _waliClassesSub = FirebaseFirestore.instance
        .collection('schools')
        .doc(schoolId)
        .collection('classes')
        .where('teacherId', isEqualTo: teacherDocId)
        .snapshots()
        .listen((snap) {
      if (mounted) {
        setState(() {
          final waliIds = snap.docs.map((d) => d.id).toSet();
          _teacherClassIds = {..._teacherClassIds, ...waliIds};
        });
      }
    });

    _scheduleClassesSub?.cancel();
    _scheduleClassesSub = FirebaseFirestore.instance
        .collection('schools')
        .doc(schoolId)
        .collection('class_schedules')
        .where('teacherId', isEqualTo: teacherDocId)
        .snapshots()
        .listen((snap) {
      if (mounted) {
        setState(() {
          final scheduleIds = snap.docs
              .map((d) => d.data()['classId'] as String?)
              .where((id) => id != null && id.isNotEmpty)
              .cast<String>()
              .toSet();
          _teacherClassIds = {..._teacherClassIds, ...scheduleIds};
        });
      }
    });
  }

  int _timeToMinutes(String time) {
    final parts = time.split(':');
    if (parts.length != 2) return 0;
    return (int.tryParse(parts[0]) ?? 0) * 60 + (int.tryParse(parts[1]) ?? 0);
  }

  String _getCurrentDay() {
    switch (DateTime.now().weekday) {
      case DateTime.monday:
        return 'Senin';
      case DateTime.tuesday:
        return 'Selasa';
      case DateTime.wednesday:
        return 'Rabu';
      case DateTime.thursday:
        return 'Kamis';
      case DateTime.friday:
        return 'Jumat';
      case DateTime.saturday:
        return 'Sabtu';
      case DateTime.sunday:
        return 'Minggu';
      default:
        return 'Senin';
    }
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour >= 0 && hour <= 10) return AppLocalization.greetingMorning;
    if (hour <= 14) return AppLocalization.greetingAfternoon;
    if (hour <= 18) return AppLocalization.greetingEvening;
    return AppLocalization.greetingNight;
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final bool isDark = AuthBackground.isDarkMode.value;
    final bool? confirm = await showDialog<bool>(
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
          'Apakah Anda yakin ingin keluar dari akun guru Anda?',
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

    return ValueListenableBuilder<bool>(
      valueListenable: AuthBackground.isDarkMode,
      builder: (context, isDark, _) {
        if (_isLoadingTeacher || _isLoadingSchool) {
          return Scaffold(
            body: AuthBackground(
              child: Center(
                child: CircularProgressIndicator(
                  color: isDark ? Colors.white : const Color(0xFF8B5CF6),
                ),
              ),
            ),
          );
        }

        if (_teacherDocId == null) {
          final infoTextColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
          final infoSubtitleColor = isDark
              ? Colors.white.withValues(alpha: 0.7)
              : const Color(0xFF1E1B4B).withValues(alpha: 0.8);
          final infoBorderColor = isDark
              ? Colors.white.withValues(alpha: 0.3)
              : const Color(0xFF1E1B4B).withValues(alpha: 0.3);

          return Scaffold(
            body: AuthBackground(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        color: Colors.amber,
                        size: 64,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Akun Anda belum terhubung',
                        style: TextStyle(
                          color: infoTextColor,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Data guru Anda tidak ditemukan di sekolah ini. Hubungi Admin Sekolah untuk menghubungkan akun Anda.',
                        style: TextStyle(
                          color: infoSubtitleColor,
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      OutlinedButton.icon(
                        onPressed: () => _confirmLogout(context),
                        icon: Icon(Icons.logout_rounded, color: infoTextColor),
                        label: Text(
                          'Keluar',
                          style: TextStyle(color: infoTextColor),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: infoBorderColor),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }

        return ValueListenableBuilder<String>(
          valueListenable: AppLocalization.currentLocale,
          builder: (context, locale, _) {
            return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(SessionService.currentUser!.uid)
                  .snapshots(),
              builder: (context, userSnapshot) {
                final userData = userSnapshot.data?.data();
                final isGateOfficer = userData?['isGateOfficer'] as bool? ?? false;
                final isLibrarian = userData?['isLibrarian'] as bool? ?? false;

                return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _teacherService.getClassesByTeacher(
                    SessionService.currentUser!.schoolId,
                    _teacherDocId!,
                  ),
                  builder: (context, classSnapshot) {
                    final waliKelasClasses = classSnapshot.data?.docs ?? [];

                    return LayoutBuilder(
                      builder: (context, constraints) {
                        if (constraints.maxWidth < 850) {
                          return _buildMobileLayout(isDark, isGateOfficer, isLibrarian, waliKelasClasses);
                        } else {
                          return _buildDesktopLayout(isDark, isGateOfficer, isLibrarian, waliKelasClasses);
                        }
                      },
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildMobileLayout(bool isDark, bool isGateOfficer, bool isLibrarian, List<QueryDocumentSnapshot<Map<String, dynamic>>> waliKelasClasses) {
    final user = SessionService.currentUser!;
    final teacherId = _teacherDocId!;
    final teacherNama = _teacherData?['nama'] ?? user.nama;
    final teacherNip = _teacherData?['nip'] ?? '-';
    final titleColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
    final iconBgColor = isDark
        ? Colors.white.withValues(alpha: 0.1)
        : Colors.black.withValues(alpha: 0.05);
    final iconColor = isDark ? Colors.white : const Color(0xFF1E1B4B);

    return Scaffold(
      body: AuthBackground(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _scheduleService.getSchedulesByTeacher(
                user.schoolId,
                teacherId,
              ),
              builder: (context, scheduleSnapshot) {
                final schedules =
                    scheduleSnapshot.data?.docs
                        .map((e) => e.data())
                        .toList() ??
                    [];

                final Set<String> teacherClassIds = schedules
                    .map((e) => (e['classId'] ?? '') as String)
                    .where((id) => id.isNotEmpty)
                    .toSet();

                final currentDay = _getCurrentDay();
                final todaySchedules = schedules
                    .where((s) => s['hari'] == currentDay)
                    .toList();
                todaySchedules.sort((a, b) {
                  return _timeToMinutes(
                    a['jamMulai'] ?? '',
                  ).compareTo(_timeToMinutes(b['jamMulai'] ?? ''));
                });

                return StreamBuilder<
                  QuerySnapshot<Map<String, dynamic>>
                >(
                  stream: _teacherSubjectService.getSubjectsByTeacher(
                    user.schoolId,
                    teacherId,
                  ),
                  builder: (context, subjectSnapshot) {
                        final teacherSubjects =
                            subjectSnapshot.data?.docs
                                .map((e) => e.data())
                                .toList() ??
                            [];

                        return RefreshIndicator(
                          onRefresh: _resolveTeacherDocId,
                          child: CustomScrollView(
                            physics: const AlwaysScrollableScrollPhysics(
                              parent: BouncingScrollPhysics(),
                            ),
                            slivers: [
                              SliverAppBar(
                                backgroundColor: Colors.transparent,
                                elevation: 0,
                                pinned: true,
                                toolbarHeight: 56,
                                title: Row(
                                  children: [
                                     if (_schoolLogoBase64 != null &&
                                         _schoolLogoBase64!.isNotEmpty) ...[
                                       Container(
                                         width: 42,
                                         height: 42,
                                         decoration: BoxDecoration(
                                           borderRadius: BorderRadius.circular(10),
                                           boxShadow: [
                                             BoxShadow(
                                               color: const Color(
                                                 0xFF8B5CF6,
                                               ).withValues(alpha: 0.15),
                                               blurRadius: 8,
                                             ),
                                           ],
                                         ),
                                         child: ClipRRect(
                                           borderRadius: BorderRadius.circular(9),
                                           child: Image.memory(
                                             base64Decode(
                                               _schoolLogoBase64!,
                                             ),
                                             fit: BoxFit.cover,
                                             errorBuilder: (_, __, ___) =>
                                                 Icon(
                                                   Icons.school_rounded,
                                                   size: 22,
                                                   color: titleColor,
                                                 ),
                                           ),
                                         ),
                                       ),
                                       const SizedBox(width: 12),
                                     ],
                                    Expanded(
                                      child: Text(
                                        _getGreeting(),
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: titleColor,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                actions: [
                                  Container(
                                    decoration: BoxDecoration(
                                      color: iconBgColor,
                                      shape: BoxShape.circle,
                                    ),
                                    child: IconButton(
                                      icon: Icon(
                                        Icons.notifications_rounded,
                                        color: iconColor,
                                        size: 20,
                                      ),
                                      tooltip: 'Notifikasi',
                                      onPressed: () => Get.toNamed(
                                        AppRoutes.notifications,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    decoration: BoxDecoration(
                                      color: iconBgColor,
                                      shape: BoxShape.circle,
                                    ),
                                    child: IconButton(
                                      icon: Icon(
                                        Icons.settings_rounded,
                                        color: iconColor,
                                        size: 20,
                                      ),
                                      tooltip: 'Pengaturan',
                                      onPressed: () async {
                                        await Get.to(
                                          () => const TeacherSettingsPage(),
                                        );
                                        _resolveTeacherDocId();
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    margin: const EdgeInsets.only(
                                      right: 16,
                                    ),
                                    decoration: BoxDecoration(
                                      color: iconBgColor,
                                      shape: BoxShape.circle,
                                    ),
                                    child: IconButton(
                                      icon: Icon(
                                        Icons.logout_rounded,
                                        color: iconColor,
                                        size: 20,
                                      ),
                                      tooltip: AppLocalization.logout,
                                      onPressed: () =>
                                          _confirmLogout(context),
                                    ),
                                  ),
                                ],
                              ),

                              SliverToBoxAdapter(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 8,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      _buildProfileHeader(
                                        teacherNama,
                                        user.email,
                                        teacherNip,
                                        waliKelasClasses,
                                        isDark,
                                      ),
                                      const SizedBox(height: 24),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: _buildStatCard(
                                              title: AppLocalization.classesTaught,
                                              value: teacherClassIds.length
                                                  .toString(),
                                              icon: Icons.class_rounded,
                                              color: const Color(
                                                0xFF6366F1,
                                              ),
                                              isDark: isDark,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: _buildStatCard(
                                              title: AppLocalization.menuSubjects,
                                              value: teacherSubjects.length
                                                  .toString(),
                                              icon: Icons.menu_book_rounded,
                                              color: const Color(
                                                0xFF10B981,
                                              ),
                                              isDark: isDark,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 28),
                                      _buildSectionTitle(
                                        AppLocalization.mySubjects,
                                        Icons.menu_book_rounded,
                                        isDark,
                                      ),
                                      const SizedBox(height: 16),
                                      _buildSubjectsList(
                                        teacherSubjects,
                                        isDark,
                                      ),
                                      const SizedBox(height: 28),
                                      _buildSectionTitle(
                                        '${AppLocalization.todaySchedule} ($currentDay)',
                                        Icons.calendar_today_rounded,
                                        isDark,
                                      ),
                                      const SizedBox(height: 16),
                                      _buildTodaySchedule(
                                        todaySchedules,
                                        isDark,
                                      ),
                                      const SizedBox(height: 28),
                                      _buildExamSemesterSection(
                                        isDark: isDark,
                                        teacherId: teacherId,
                                        schoolId: user.schoolId,
                                      ),
                                      _buildSectionTitle(
                                        AppLocalization.menuStudentMain,
                                        Icons.dashboard_rounded,
                                        isDark,
                                      ),
                                      const SizedBox(height: 16),
                                      _buildMenuGrid(isDark, isGateOfficer, isLibrarian, waliKelasClasses),
                                      const SizedBox(height: 40),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
          ),
        ),
      ),
    );
  }

  void _showFullScreenQr(BuildContext context, String qrData) {
    final isDark = AuthBackground.isDarkMode.value;
    final textColor = isDark ? Colors.white : const Color(0xFF1E1B4B);

    String? teacherId;
    String? schoolId;
    try {
      final decoded = jsonDecode(qrData);
      teacherId = decoded['teacherId'];
      schoolId = decoded['schoolId'];
    } catch (_) {}

    StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? listener;

    if (schoolId != null && teacherId != null) {
      final now = DateTime.now();
      final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final docRef = FirebaseFirestore.instance
          .collection('schools')
          .doc(schoolId)
          .collection('teacher_daily_attendance')
          .doc('${dateStr}_$teacherId');

      bool isFirstEmit = true;
      Timestamp? initialCheckIn;
      Timestamp? initialCheckOut;

      listener = docRef.snapshots().listen((snapshot) {
        if (isFirstEmit) {
          isFirstEmit = false;
          if (snapshot.exists && snapshot.data() != null) {
            final data = snapshot.data()!;
            initialCheckIn = data['checkInTime'] as Timestamp?;
            initialCheckOut = data['checkOutTime'] as Timestamp?;
          }
          return;
        }

        if (snapshot.exists && snapshot.data() != null) {
          final data = snapshot.data()!;
          final currentCheckIn = data['checkInTime'] as Timestamp?;
          final currentCheckOut = data['checkOutTime'] as Timestamp?;

          bool isNewCheckIn = initialCheckIn == null && currentCheckIn != null;
          bool isNewCheckOut = initialCheckOut == null && currentCheckOut != null;

          if (isNewCheckIn || isNewCheckOut) {
            if (Get.isDialogOpen ?? false) {
              Get.back();
            }
            final titleStr = isNewCheckOut ? 'Berhasil Absen Pulang' : 'Berhasil Absen Masuk';
            final messageStr = isNewCheckOut
                ? 'Anda berhasil melakukan absensi pulang.'
                : 'Anda berhasil melakukan absensi masuk.';
            Get.snackbar(
              titleStr,
              messageStr,
              backgroundColor: const Color(0xFF10B981),
              colorText: Colors.white,
              snackPosition: SnackPosition.TOP,
              margin: const EdgeInsets.all(16),
              borderRadius: 12,
            );
            listener?.cancel();
          }
        }
      });
    }

    Get.dialog(
      Dialog(
        backgroundColor: isDark ? const Color(0xFF0F0C20) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'QR Saya',
                style: TextStyle(
                  color: textColor,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 15,
                    ),
                  ],
                ),
                child: QrImageView(
                  data: qrData,
                  version: QrVersions.auto,
                  size: 240,
                  backgroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Get.back(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8B5CF6),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text(
                    'Tutup',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ).then((_) {
      listener?.cancel();
    });
  }

  // --- WIDGETS ---

  Widget _buildProfileHeader(
    String nama,
    String email,
    String nip,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> waliKelasClasses,
    bool isDark,
  ) {
    // Ambil nama kelas wali kelas (jika ada)
    final waliKelasNames = waliKelasClasses
        .map((doc) => doc.data()['namaKelas'] ?? 'Kelas')
        .toList();
    final cardColor = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.white;
    final cardBorder = isDark
        ? Colors.white.withValues(alpha: 0.12)
        : Colors.black.withValues(alpha: 0.08);
    final cardShadow = isDark
        ? Colors.black.withValues(alpha: 0.2)
        : Colors.black.withValues(alpha: 0.05);
    final titleColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
    final nipColor = isDark
        ? Colors.white.withValues(alpha: 0.5)
        : const Color(0xFF1E1B4B).withValues(alpha: 0.5);

    final user = SessionService.currentUser!;
    final qrPayload = jsonEncode({
      'teacherId': _teacherDocId ?? '',
      'schoolId': user.schoolId,
      'nip': nip,
      'nama': nama,
      'role': 'teacher',
    });

    return MotifCard(
      isDark: isDark,
      cardColor: cardColor,
      cardBorderColor: cardBorder,
      cardShadowColor: cardShadow,
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              FlipCard(
                isDark: isDark,
                front: Container(
                  padding: const EdgeInsets.all(4), // gradient frame thickness
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF8B5CF6), Color(0xFF3B82F6)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF8B5CF6).withValues(alpha: 0.35),
                        blurRadius: 15,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Container(
                    width: 102,
                    height: 102,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: GestureDetector(
                        onTap: () => _showFullScreenQr(context, qrPayload),
                        child: QrImageView(
                          data: qrPayload,
                          version: QrVersions.auto,
                          backgroundColor: Colors.white,
                          padding: const EdgeInsets.all(8.0),
                          eyeStyle: const QrEyeStyle(
                            eyeShape: QrEyeShape.square,
                            color: Color(0xFF1E1B4B),
                          ),
                          dataModuleStyle: const QrDataModuleStyle(
                            dataModuleShape: QrDataModuleShape.square,
                            color: Color(0xFF1E1B4B),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                back: Container(
                  padding: const EdgeInsets.all(4), // gradient frame thickness
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF8B5CF6), Color(0xFF3B82F6)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF8B5CF6).withValues(alpha: 0.35),
                        blurRadius: 15,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Container(
                    width: 102,
                    height: 102,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: _teacherData?['fotoBase64'] != null && _teacherData!['fotoBase64'].toString().isNotEmpty
                          ? Image.memory(
                              base64Decode(_teacherData!['fotoBase64']),
                              fit: BoxFit.cover,
                            )
                          : const Center(
                              child: Icon(
                                Icons.person_rounded,
                                color: Color(0xFF8B5CF6),
                                size: 40,
                              ),
                            ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nama,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: titleColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'NIP: $nip',
                      style: TextStyle(fontSize: 12, color: nipColor),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.school_rounded, color: nipColor, size: 14),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _schoolName ?? 'Sekolah',
                            style: TextStyle(
                              fontSize: 12,
                              color: nipColor,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),

                  ],
                ),
              ),
            ],
          ),

          // Wali Kelas (di dalam card yang sama)
          if (waliKelasNames.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.school_rounded,
                    color: Color(0xFFF59E0B),
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${AppLocalization.homeroomLabel}: ${waliKelasNames.join(", ")}',
                      style: const TextStyle(
                        color: Color(0xFFF59E0B),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (_tahunAjaran != null || _activeSemester != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.calendar_today_rounded,
                    color: Color(0xFF6366F1),
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${AppLocalization.academicYearLabel}: ${_tahunAjaran ?? "-"}  |  ${_activeSemester ?? "-"}',
                      style: const TextStyle(
                        color: Color(0xFF6366F1),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPlanBadge() {
    Color badgeColor;
    Gradient badgeGradient;
    IconData icon;
    String label = _plan;

    if (label == 'PRO') {
      badgeColor = const Color(0xFFD97706);
      badgeGradient = const LinearGradient(
        colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
      icon = Icons.workspace_premium_rounded;
    } else if (label == 'BASIC') {
      badgeColor = const Color(0xFF2563EB);
      badgeGradient = const LinearGradient(
        colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
      icon = Icons.star_rounded;
    } else {
      badgeColor = const Color(0xFF4B5563);
      badgeGradient = const LinearGradient(
        colors: [Color(0xFF9CA3AF), Color(0xFF6B7280)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
      icon = Icons.shield_outlined;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        gradient: badgeGradient,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: badgeColor.withValues(alpha: 0.3),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 10),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 9,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required bool isDark,
  }) {
    final cardBg = isDark
        ? color.withValues(alpha: 0.1)
        : color.withValues(alpha: 0.08);
    final cardBorderColor = isDark
        ? color.withValues(alpha: 0.3)
        : color.withValues(alpha: 0.2);
    final valueColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
    final titleColor = isDark
        ? Colors.white.withValues(alpha: 0.6)
        : const Color(0xFF1E1B4B).withValues(alpha: 0.6);
    final shadowColor = isDark
        ? Colors.transparent
        : Colors.black.withValues(alpha: 0.04);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cardBorderColor),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: shadowColor,
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: valueColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(title, style: TextStyle(fontSize: 13, color: titleColor)),
        ],
      ),
    );
  }

  /// Section Ujian Semester — muncul jika ada active/planning exam event dengan tugas untuk guru ini
  Widget _buildExamSemesterSection({
    required bool isDark,
    required String teacherId,
    required String schoolId,
  }) {
    final examService = ExamSessionService();
    final cardColor = isDark ? Colors.white.withValues(alpha: 0.06) : Colors.white;
    final cardBorder = isDark ? Colors.white.withValues(alpha: 0.10) : Colors.black.withValues(alpha: 0.08);
    final subtitleColor = isDark ? Colors.white.withValues(alpha: 0.55) : const Color(0xFF1E1B4B).withValues(alpha: 0.6);
    final titleColor = isDark ? Colors.white : const Color(0xFF1E1B4B);

    return StreamBuilder<List<ExamSession>>(
      stream: examService.getSessionsByProctor(schoolId, teacherId),
      builder: (context, proctorSnap) {
        return StreamBuilder<List<ExamSession>>(
          stream: examService.getSessionsByAuthor(schoolId, teacherId),
          builder: (context, authorSnap) {
            final proctorSessions = proctorSnap.data ?? [];
            final authorSessions = authorSnap.data ?? [];
            final totalSessions = proctorSessions.length + authorSessions.length;

            // Hitung sesi mendatang pengawas
            final upcomingProctor = proctorSessions
                .where((s) => s.examStatus != 'Finished')
                .length;
            final activeSession = proctorSessions
                .where((s) => s.examStatus == 'Active')
                .firstOrNull;

            if (totalSessions == 0 &&
                proctorSnap.connectionState != ConnectionState.waiting &&
                authorSnap.connectionState != ConnectionState.waiting) {
              return const SizedBox.shrink(); // Tidak ada tugas/event
            }

            // Kumpulkan unique eventId+subjectId+gradeLevel combos dari authorSessions
            final uniqueAuthorKeys = authorSessions
                .map((s) {
                  final rawGrade = _classIdToAngkatan[s.classId] ?? _getGradeLevelForDashboard(s.className);
                  final grade = rawGrade == '3' ? '2020' : (rawGrade == '2' ? '2021' : (rawGrade == '1' ? '2022' : rawGrade));
                  return '${s.eventId}_${s.subjectId}_$grade';
                })
                .toSet();

            // Stream exam_questions untuk semua event yang terlibat
            final authorEventIds = authorSessions.map((s) => s.eventId).toSet();

            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: authorEventIds.isEmpty
                  ? const Stream.empty()
                  : FirebaseFirestore.instance
                      .collection('schools')
                      .doc(schoolId)
                      .collection('exam_questions')
                      .where('authorTeacherId', isEqualTo: teacherId)
                      .snapshots(),
              builder: (context, qSnap) {
                // subjectId yang sudah punya soal
                final Set<String> keysWithQuestions = {};
                for (final doc in qSnap.data?.docs ?? []) {
                  final data = doc.data();
                  final qList = data['questions'] as List?;
                  if (qList != null && qList.isNotEmpty) {
                    final docId = doc.id;
                    final eid = data['eventId'] as String? ?? '';
                    final sid = data['subjectId'] as String? ?? '';
                    if (eid.isNotEmpty && sid.isNotEmpty) {
                      // Jika id doc mengandung suffix gradeLevel (e.g. eventId_subjectId_X)
                      if (docId.startsWith('${eid}_${sid}_')) {
                        final grade = docId.substring('${eid}_${sid}_'.length);
                        keysWithQuestions.add('${eid}_${sid}_$grade');
                      } else {
                        // Support fallback/legacy key
                        keysWithQuestions.add('${eid}_$sid');
                        // Juga daftarkan ke all grade levels supaya tidak dianggap missing
                        keysWithQuestions.add('${eid}_${sid}_X');
                        keysWithQuestions.add('${eid}_${sid}_XI');
                        keysWithQuestions.add('${eid}_${sid}_XII');
                      }
                    }
                  }
                }

                final missingCount = uniqueAuthorKeys
                    .where((k) => !keysWithQuestions.contains(k))
                    .length;
                final hasMissingQuestions = missingCount > 0 && authorEventIds.isNotEmpty;

                // Perbarui state untuk sidebar badge
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted && _hasUnsubmittedExamQuestions != hasMissingQuestions) {
                    setState(() => _hasUnsubmittedExamQuestions = hasMissingQuestions);
                  }
                });

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionTitle(
                  AppLocalization.isIndonesian ? 'Ujian Semester' : 'Semester Exam',
                  Icons.assignment_turned_in_rounded,
                  isDark,
                ),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: () => Get.to(() => TeacherProctorDashboardPage(teacherId: teacherId)),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: hasMissingQuestions
                            ? const Color(0xFFEF4444).withValues(alpha: 0.5)
                            : activeSession != null
                                ? const Color(0xFF10B981).withValues(alpha: 0.5)
                                : cardBorder,
                        width: (hasMissingQuestions || activeSession != null) ? 1.5 : 1,
                      ),
                      boxShadow: hasMissingQuestions ? [
                        BoxShadow(
                          color: const Color(0xFFEF4444).withValues(alpha: 0.10),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        )
                      ] : activeSession != null ? [
                        BoxShadow(
                          color: const Color(0xFF10B981).withValues(alpha: 0.12),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        )
                      ] : null,
                    ),
                    child: Row(
                      children: [
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: activeSession != null
                                      ? [const Color(0xFF10B981), const Color(0xFF06B6D4)]
                                      : hasMissingQuestions
                                          ? [const Color(0xFFEF4444), const Color(0xFFF59E0B)]
                                          : [const Color(0xFF8B5CF6), const Color(0xFFEC4899)],
                                ),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(Icons.assignment_turned_in_rounded,
                                  color: Colors.white, size: 24),
                            ),
                            // Red dot badge jika ada soal belum dibuat
                            if (hasMissingQuestions)
                              Positioned(
                                top: -4,
                                right: -4,
                                child: Container(
                                  width: 16,
                                  height: 16,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFEF4444),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Text(
                                      '$missingCount',
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
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                AppLocalization.isIndonesian ? 'Ujian Semester' : 'Semester Exam',
                                style: TextStyle(
                                  color: titleColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 4),
                              if (activeSession != null)
                                Text(
                                  AppLocalization.isIndonesian
                                      ? '🔴 Sesi aktif: ${activeSession.subjectName}'
                                      : '🔴 Active session: ${activeSession.subjectName}',
                                  style: const TextStyle(
                                      color: Color(0xFF10B981),
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold),
                                )
                              else if (hasMissingQuestions)
                                Text(
                                  AppLocalization.isIndonesian
                                      ? '⚠️ $missingCount soal belum dibuat'
                                      : '⚠️ $missingCount questions not created yet',
                                  style: const TextStyle(
                                      color: Color(0xFFEF4444),
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold),
                                )
                              else
                                Text(
                                  AppLocalization.isIndonesian
                                      ? '${upcomingProctor > 0 ? '$upcomingProctor sesi pengawas' : ''}${upcomingProctor > 0 && authorSessions.isNotEmpty ? ' • ' : ''}${authorSessions.isNotEmpty ? '${authorSessions.map((s) => s.subjectId).toSet().length} mapel soal' : ''}'
                                      : '${upcomingProctor > 0 ? '$upcomingProctor proctor sessions' : ''}${upcomingProctor > 0 && authorSessions.isNotEmpty ? ' • ' : ''}${authorSessions.isNotEmpty ? '${authorSessions.map((s) => s.subjectId).toSet().length} subjects' : ''}',
                                  style: TextStyle(color: subtitleColor, fontSize: 12),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                            ],
                          ),
                        ),
                        Icon(Icons.arrow_forward_ios_rounded,
                            size: 14, color: subtitleColor),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 28),
              ],
            );
              }, // end qSnap builder
            ); // end exam_questions StreamBuilder
          },
        );
      },
    );
  }

  Widget _buildSectionTitle(String title, IconData icon, bool isDark) {
    final iconColor = isDark
        ? Colors.white.withValues(alpha: 0.8)
        : const Color(0xFF1E1B4B).withValues(alpha: 0.8);
    final textColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
    return Row(
      children: [
        Icon(icon, color: iconColor, size: 20),
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

  Widget _buildSubjectsList(List<Map<String, dynamic>> subjects, bool isDark) {
    if (subjects.isEmpty) {
      final emptyBg = isDark
          ? Colors.white.withValues(alpha: 0.05)
          : Colors.white;
      final emptyBorder = isDark
          ? Colors.white.withValues(alpha: 0.1)
          : Colors.black.withValues(alpha: 0.08);
      final emptyTextColor = isDark
          ? Colors.white.withValues(alpha: 0.7)
          : const Color(0xFF1E1B4B).withValues(alpha: 0.6);

      return Container(
        height: 80,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: emptyBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: emptyBorder),
        ),
        child: Text(
          AppLocalization.noSubjectsYet,
          style: TextStyle(color: emptyTextColor, fontSize: 14),
        ),
      );
    }

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: subjects.map((s) {
        final name = s['subjectName'] ?? 'Mapel';
        final textLabelColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
        final itemBg = isDark
            ? const Color(0xFF10B981).withValues(alpha: 0.12)
            : const Color(0xFF10B981).withValues(alpha: 0.1);
        final itemBorder = isDark
            ? const Color(0xFF10B981).withValues(alpha: 0.3)
            : const Color(0xFF10B981).withValues(alpha: 0.25);

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: itemBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: itemBorder),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.menu_book_rounded,
                color: Color(0xFF10B981),
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                name,
                style: TextStyle(
                  color: textLabelColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTodaySchedule(
    List<Map<String, dynamic>> schedules,
    bool isDark,
  ) {
    if (schedules.isEmpty) {
      final emptyBg = isDark
          ? Colors.white.withValues(alpha: 0.05)
          : Colors.white;
      final emptyBorder = isDark
          ? Colors.white.withValues(alpha: 0.1)
          : Colors.black.withValues(alpha: 0.08);
      final emptyTextColor = isDark
          ? Colors.white.withValues(alpha: 0.7)
          : const Color(0xFF1E1B4B).withValues(alpha: 0.6);

      return Container(
        height: 100,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: emptyBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: emptyBorder),
        ),
        child: Text(
          '${AppLocalization.noScheduleToday} 🎉',
          style: TextStyle(color: emptyTextColor, fontSize: 16),
        ),
      );
    }

    return SizedBox(
      height: 130,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: schedules.length,
        itemBuilder: (context, index) {
          final s = schedules[index];
          return Container(
            width: 260,
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF3B82F6).withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${s['jamMulai'] ?? '-'} - ${s['jamSelesai'] ?? '-'}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  s['subjectName'] ?? 'Pelajaran',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.class_outlined,
                      color: Colors.white.withValues(alpha: 0.8),
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        s['className'] ?? 'Kelas',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildMenuGrid(bool isDark, bool isGateOfficer, bool isLibrarian, List<QueryDocumentSnapshot<Map<String, dynamic>>> waliKelasClasses) {
    final menus = [
      {
        'id': 'teaching_schedule',
        'title': AppLocalization.menuTeachingSchedule,
        'icon': Icons.calendar_month_rounded,
        'color': const Color(0xFFF59E0B),
      },
      if (waliKelasClasses.isNotEmpty) ...[
        {
          'id': 'student_list',
          'title': AppLocalization.menuStudentList,
          'icon': Icons.groups_rounded,
          'color': const Color(0xFF0EA5E9),
        },
      ],
      {
        'id': 'student_attendance',
        'title': AppLocalization.menuStudentAttendance,
        'icon': Icons.fact_check_rounded,
        'color': const Color(0xFF10B981),
      },
      {
        'id': 'daily_attendance',
        'title': AppLocalization.menuDailyAttendance,
        'icon': Icons.co_present_rounded,
        'color': const Color(0xFF6366F1),
      },
      if (isGateOfficer) ...[
        {
          'id': 'scan_daily_attendance',
          'title': AppLocalization.menuScanDailyAttendance,
          'icon': Icons.qr_code_scanner_rounded,
          'color': const Color(0xFF10B981),
        },
      ],
      if (isLibrarian) ...[
        {
          'id': 'library_dashboard',
          'title': AppLocalization.menuLibraryDashboard,
          'icon': Icons.menu_book_rounded,
          'color': const Color(0xFF6366F1),
        },
      ],
      {
        'id': 'input_grades',
        'title': AppLocalization.menuInputGrades,
        'icon': Icons.grade_rounded,
        'color': const Color(0xFF8B5CF6),
      },
      {
        'id': 'task_management',
        'title': AppLocalization.menuTaskManagement,
        'icon': Icons.assignment_rounded,
        'color': const Color(0xFF3B82F6),
      },
      {
        'id': 'online_exam',
        'title': AppLocalization.menuOnlineExam,
        'icon': Icons.quiz_rounded,
        'color': const Color(0xFF8B5CF6),
      },

      {
        'id': 'chat',
        'title': AppLocalization.menuChat,
        'icon': Icons.chat_rounded,
        'color': const Color(0xFF8B5CF6),
      },
      {
        'id': 'reports_and_cards',
        'title': AppLocalization.menuReportsAndCards,
        'icon': Icons.bar_chart_rounded,
        'color': const Color(0xFFEC4899),
      },
      {
        'id': 'student_permit',
        'title': AppLocalization.menuStudentPermit,
        'icon': Icons.mark_email_read_rounded,
        'color': const Color(0xFF8B5CF6),
      },
      {
        'id': 'notifications',
        'title': AppLocalization.menuNotifications,
        'icon': Icons.campaign_rounded,
        'color': const Color(0xFFEF4444),
      },
      {
        'id': 'input_violation',
        'title': AppLocalization.menuInputViolation,
        'icon': Icons.report_problem_rounded,
        'color': const Color(0xFFEF4444),
      },

      {
        'id': 'realtime_control',
        'title': AppLocalization.menuRealtimeControl,
        'icon': Icons.settings_remote_rounded,
        'color': const Color(0xFF84CC16),
      },

      {
        'id': 'profile_settings',
        'title': AppLocalization.menuProfileSettings,
        'icon': Icons.manage_accounts_rounded,
        'color': const Color(0xFF64748B),
        'badge': null,
      },
    ];

    final screenWidth = MediaQuery.of(context).size.width;
    int crossAxisCount = 2;
    double childAspectRatio = 1.1;

    if (screenWidth >= 900) {
      crossAxisCount = 4;
      childAspectRatio = 1.4;
    } else if (screenWidth >= 600) {
      crossAxisCount = 3;
      childAspectRatio = 1.25;
    }

    final cardBg = isDark ? Colors.white.withValues(alpha: 0.03) : Colors.white;
    final cardBorder = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.06);
    final textColor = isDark ? Colors.white : const Color(0xFF1E1B4B);

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: childAspectRatio,
      ),
      itemCount: menus.length,
      itemBuilder: (context, index) {
        final menu = menus[index];
        final color = menu['color'] as Color;
        final badge = menu['badge'] as String?;
        final isScanCard = menu['id'] == 'scan_daily_attendance';
        final isDisabled = isScanCard && !isGateOfficer;

        return Opacity(
          opacity: isDisabled ? 0.5 : 1.0,
          child: Container(
            decoration: BoxDecoration(
              color: isDisabled ? (isDark ? Colors.white.withValues(alpha: 0.02) : Colors.black.withValues(alpha: 0.02)) : cardBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: isDisabled ? Colors.grey.withValues(alpha: 0.3) : cardBorder),
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
                onTap: () async {
                  final user = SessionService.currentUser!;
                  if (isScanCard) {
                    if (!isGateOfficer) {
                      Get.snackbar(
                        AppLocalization.isIndonesian ? 'Akses Ditolak' : 'Access Denied',
                        AppLocalization.isIndonesian
                            ? 'Anda tidak memiliki izin sebagai petugas scan.'
                            : 'You do not have permission as a scan officer.',
                        backgroundColor: Colors.amber,
                        colorText: Colors.black,
                      );
                    } else {
                      Get.toNamed(AppRoutes.officerDashboard);
                    }
                  } else if (menu['id'] == 'library_dashboard') {
                    Get.to(() => const LibrarianDashboardPage());
                  } else if (menu['id'] == 'teaching_schedule') {
                    Get.to(() => TeacherSchedulePage(teacherId: _teacherDocId!));
                  } else if (menu['id'] == 'student_attendance') {
                    Get.to(
                      () =>
                          TeacherAttendanceSchedulePage(teacherId: _teacherDocId!),
                    );
                  } else if (menu['id'] == 'daily_attendance') {
                    Get.to(
                      () => TeacherDailyAttendancePage(
                        teacherId: _teacherDocId!,
                        teacherName: _teacherData?['nama'] ?? user.nama,
                        nip: _teacherData?['nip'] ?? '',
                      ),
                    );
                  } else if (menu['id'] == 'realtime_control') {
                    Get.to(
                      () => TeacherBehaviorRecordsPage(teacherId: _teacherDocId!),
                    );
                  } else if (menu['id'] == 'input_grades') {
                    Get.to(() => TeacherGradesPage(teacherId: _teacherDocId!));
                  } else if (menu['id'] == 'task_management') {
                    Get.to(() => TeacherTasksPage(teacherId: _teacherDocId!));
                  } else if (menu['id'] == 'online_exam') {
                    Get.to(() => TeacherExamsPage(teacherId: _teacherDocId!));
                  } else if (menu['id'] == 'reports_and_cards') {
                    Get.to(
                      () => TeacherReportsPage(
                        schoolId: user.schoolId,
                        teacherId: _teacherDocId!,
                      ),
                    );
                  } else if (menu['id'] == 'student_permit') {
                    if (_teacherDocId == null) {
                      Get.snackbar(
                        AppLocalization.isIndonesian ? 'Error' : 'Error',
                        AppLocalization.isIndonesian
                            ? 'Data guru belum dimuat sepenuhnya.'
                            : 'Teacher data is not fully loaded.',
                        backgroundColor: Colors.redAccent,
                        colorText: Colors.white,
                      );
                    } else {
                      Get.toNamed(
                        AppRoutes.teacherPermits,
                        arguments: {
                          'teacherDocId': _teacherDocId,
                          'schoolId': user.schoolId,
                        },
                      );
                    }
                  } else if (menu['id'] == 'chat') {
                    Get.to(
                      () => TeacherChatSelectorPage(
                        schoolId: user.schoolId,
                        teacherDocId: _teacherDocId!,
                        teacherName: _teacherData?['nama'] ?? user.nama,
                      ),
                    );
                  } else if (menu['id'] == 'notifications') {
                    Get.toNamed(AppRoutes.notifications);
                  } else if (menu['id'] == 'profile_settings') {
                    await Get.to(() => const TeacherSettingsPage());
                    _resolveTeacherDocId();
                  } else if (menu['id'] == 'input_violation') {
                    Get.to(() => TeacherStudentViolationsPage(teacherId: _teacherDocId!));
                  } else if (menu['id'] == 'student_list') {
                    Get.to(
                      () => TeacherMyStudentsPage(
                        schoolId: user.schoolId,
                        teacherId: _teacherDocId!,
                        waliKelasClasses: waliKelasClasses,
                      ),
                    );
                  } else {
                    Get.snackbar(
                      AppLocalization.isIndonesian ? 'Info' : 'Info',
                      AppLocalization.isIndonesian
                          ? 'Fitur "${menu['title']}" sedang dalam pengembangan.'
                          : 'Feature "${menu['title']}" is currently in development.',
                      snackPosition: SnackPosition.BOTTOM,
                      backgroundColor: Colors.amber,
                      colorText: Colors.black,
                      margin: const EdgeInsets.all(16),
                      borderRadius: 12,
                      icon: const Icon(Icons.info_outline, color: Colors.black),
                    );
                  }
                },
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

                            if (menu['title'] == 'Chat' && _teacherDocId != null) {
                              return ChatUnreadBadge(
                                schoolId: SessionService.currentUser!.schoolId,
                                userId: _teacherDocId!,
                                role: 'teacher',
                                top: -2,
                                right: -2,
                                child: container,
                              );
                            }

                            if (menu['title'] == 'Surat Izin Siswa' && _teacherDocId != null) {
                              return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                                stream: FirebaseFirestore.instance
                                    .collection('schools')
                                    .doc(SessionService.currentUser!.schoolId)
                                    .collection('permits')
                                    .snapshots(),
                                builder: (context, snapshot) {
                                  final docs = snapshot.data?.docs ?? [];
                                  final filteredDocs = docs.where((doc) {
                                    final data = doc.data();
                                    final permitTeacherId = data['teacherId']?.toString() ?? '';
                                    final permitClassId = data['classId']?.toString() ?? '';
                                    return permitTeacherId == _teacherDocId || _teacherClassIds.contains(permitClassId);
                                  }).toList();

                                  final pendingCount = filteredDocs
                                      .where((d) => d.data()['status'] == 'Pending')
                                      .length;

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
                  if (isScanCard && !isGateOfficer)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.lock_rounded,
                          color: Colors.redAccent,
                          size: 14,
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

  Widget _buildDesktopLayout(bool isDark, bool isGateOfficer, bool isLibrarian, List<QueryDocumentSnapshot<Map<String, dynamic>>> waliKelasClasses) {
    final panelBg = isDark ? const Color(0xFF0B081B) : const Color(0xFFF8FAFC);

    return Scaffold(
      body: Row(
        children: [
          // Sidebar
          _buildTeacherSidebar(isDark, isGateOfficer, isLibrarian, waliKelasClasses),
          // Main Panel Content
          Expanded(
            child: Container(
              color: panelBg,
              child: _buildDesktopContent(isDark, isGateOfficer, isLibrarian, waliKelasClasses),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTeacherSidebar(bool isDark, bool isGateOfficer, bool isLibrarian, List<QueryDocumentSnapshot<Map<String, dynamic>>> waliKelasClasses) {
    final sidebarBg = isDark ? const Color(0xFF110E24) : Colors.white;
    final borderRightColor = isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06);
    final miniLogoBorder = isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.06);
    final schoolNameColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
    final dividerColor = isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06);

    return Container(
      width: 260,
      decoration: BoxDecoration(
        color: sidebarBg,
        border: Border(
          right: BorderSide(
            color: borderRightColor,
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          // Sidebar Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Row(
              children: [
                // Mini Logo
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    gradient: _schoolLogoBase64 != null
                        ? null
                        : const LinearGradient(
                            colors: [Color(0xFF8B5CF6), Color(0xFFD946EF)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: miniLogoBorder,
                      width: 1,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(15),
                    child: _schoolLogoBase64 != null
                        ? Image.memory(
                            base64Decode(_schoolLogoBase64!),
                            fit: BoxFit.cover,
                          )
                        : const Icon(
                            Icons.school_rounded,
                            color: Colors.white,
                            size: 32,
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _isLoadingSchool
                          ? SizedBox(
                              height: 12,
                              width: 80,
                              child: LinearProgressIndicator(
                                backgroundColor: isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.08),
                                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF8B5CF6)),
                              ),
                            )
                          : Text(
                              _schoolName ?? 'Sekolah Baru',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: schoolNameColor,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF8B5CF6).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'GURU',
                          style: TextStyle(
                            color: Color(0xFF8B5CF6),
                            fontWeight: FontWeight.bold,
                            fontSize: 8,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Divider(
            color: dividerColor,
            height: 1,
          ),
          // Sidebar Navigation Items
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
              children: [
                _buildSidebarItem(AppLocalization.menuDashboard, Icons.dashboard_rounded, 0, const Color(0xFF8B5CF6), isDark),
                const SizedBox(height: 4),
                _buildSidebarItem(AppLocalization.menuTeachingSchedule, Icons.calendar_month_rounded, 1, const Color(0xFFF59E0B), isDark),
                if (waliKelasClasses.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  _buildSidebarItem(AppLocalization.menuStudentList, Icons.groups_rounded, 17, const Color(0xFF0EA5E9), isDark),
                ],
                const SizedBox(height: 4),
                _buildSidebarItem(AppLocalization.menuStudentAttendance, Icons.fact_check_rounded, 2, const Color(0xFF10B981), isDark),
                const SizedBox(height: 4),
                _buildSidebarItem(AppLocalization.menuDailyAttendance, Icons.co_present_rounded, 3, const Color(0xFF6366F1), isDark),
                if (isGateOfficer) ...[
                  const SizedBox(height: 4),
                  _buildSidebarItem(AppLocalization.menuScanDailyAttendance, Icons.qr_code_scanner_rounded, 13, const Color(0xFF10B981), isDark, isGateOfficer: isGateOfficer),
                ],
                if (isLibrarian) ...[
                  const SizedBox(height: 4),
                  _buildSidebarItem(AppLocalization.menuLibrary, Icons.menu_book_rounded, 14, const Color(0xFF8B5CF6), isDark),
                ],
                const SizedBox(height: 4),
                _buildSidebarItem(AppLocalization.menuInputGrades, Icons.grade_rounded, 4, const Color(0xFF8B5CF6), isDark),
                const SizedBox(height: 4),
                _buildSidebarItem(AppLocalization.menuTaskManagement, Icons.assignment_rounded, 5, const Color(0xFF3B82F6), isDark),
                const SizedBox(height: 4),
                _buildSidebarItem(AppLocalization.menuOnlineExam, Icons.quiz_rounded, 6, const Color(0xFF8B5CF6), isDark),
                const SizedBox(height: 4),
                _buildSidebarItem(AppLocalization.menuSemesterExam, Icons.assignment_rounded, 15, const Color(0xFF8B5CF6), isDark),
                const SizedBox(height: 4),
                _buildSidebarItem(AppLocalization.menuRealtimeControl, Icons.settings_remote_rounded, 7, const Color(0xFF84CC16), isDark),
                const SizedBox(height: 4),
                _buildSidebarItem(AppLocalization.menuChat, Icons.chat_rounded, 8, const Color(0xFF8B5CF6), isDark, isChat: true),
                const SizedBox(height: 4),
                _buildSidebarItem(AppLocalization.menuReportsAndCards, Icons.bar_chart_rounded, 9, const Color(0xFFEC4899), isDark),
                const SizedBox(height: 4),
                _buildSidebarItem(AppLocalization.menuStudentPermit, Icons.mark_email_read_rounded, 10, const Color(0xFF8B5CF6), isDark, isPermit: true),
                const SizedBox(height: 4),
                _buildSidebarItem(AppLocalization.menuInputViolation, Icons.report_problem_rounded, 12, const Color(0xFFEF4444), isDark),
                const SizedBox(height: 4),
                _buildSidebarItem(AppLocalization.menuNotifications, Icons.notifications_rounded, 16, const Color(0xFFEF4444), isDark),
                const SizedBox(height: 4),

                _buildSidebarItem(AppLocalization.menuProfileSettings, Icons.settings_rounded, 11, const Color(0xFF64748B), isDark),
              ],
            ),
          ),
          Divider(
            color: dividerColor,
            height: 1,
          ),

          // Logout Item at the bottom
          Padding(
            padding: const EdgeInsets.all(12),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _confirmLogout(context),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.logout_rounded,
                        color: Colors.red.shade400,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        AppLocalization.logout,
                        style: TextStyle(
                          color: Colors.red.shade400,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarItem(String title, IconData icon, int index, Color color, bool isDark, {bool isChat = false, bool isPermit = false, bool isGateOfficer = true}) {
    final bool isDisabled = index == 13 && !isGateOfficer;
    final bool isSelected = _selectedMenuIndex == index;
    final itemBg = isSelected ? color.withValues(alpha: isDark ? 0.15 : 0.08) : Colors.transparent;
    final itemBorder = isSelected ? color.withValues(alpha: isDark ? 0.3 : 0.2) : Colors.transparent;
    final iconColor = isDisabled
        ? Colors.grey
        : (isSelected ? color : (isDark ? Colors.white.withValues(alpha: 0.5) : const Color(0xFF1E1B4B).withValues(alpha: 0.5)));
    final textColor = isDisabled
        ? Colors.grey
        : (isSelected ? (isDark ? Colors.white : const Color(0xFF1E1B4B)) : (isDark ? Colors.white.withValues(alpha: 0.7) : const Color(0xFF1E1B4B).withValues(alpha: 0.7)));

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isDisabled
            ? () {
                Get.snackbar(
                  'Akses Ditolak',
                  'Anda tidak memiliki izin sebagai petugas scan.',
                  backgroundColor: Colors.amber,
                  colorText: Colors.black,
                );
              }
            : () {
                setState(() {
                  _selectedMenuIndex = index;
                });
              },
        borderRadius: BorderRadius.circular(12),
        child: Opacity(
          opacity: isDisabled ? 0.5 : 1.0,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: itemBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: itemBorder,
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(
                      icon,
                      color: iconColor,
                      size: 20,
                    ),
                    if (isChat && _teacherDocId != null)
                      Positioned(
                        top: -4,
                        right: -4,
                        child: ChatUnreadBadge(
                          schoolId: SessionService.currentUser!.schoolId,
                          userId: _teacherDocId!,
                          role: 'teacher',
                          top: 0,
                          right: 0,
                          child: const SizedBox(width: 8, height: 8),
                        ),
                      ),
                    if (isPermit && _teacherDocId != null)
                      Positioned(
                        top: -4,
                        right: -4,
                        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                          stream: FirebaseFirestore.instance
                              .collection('schools')
                              .doc(SessionService.currentUser!.schoolId)
                              .collection('permits')
                              .snapshots(),
                          builder: (context, snapshot) {
                            final docs = snapshot.data?.docs ?? [];
                            final filteredDocs = docs.where((doc) {
                              final data = doc.data();
                              final permitTeacherId = data['teacherId']?.toString() ?? '';
                              final permitClassId = data['classId']?.toString() ?? '';
                              return permitTeacherId == _teacherDocId || _teacherClassIds.contains(permitClassId);
                            }).toList();

                            final pendingCount = filteredDocs.where((d) => d.data()['status'] == 'Pending').length;
                            if (pendingCount > 0) {
                              return Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: Colors.redAccent,
                                  shape: BoxShape.circle,
                                ),
                              );
                            }
                            return const SizedBox.shrink();
                          },
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: textColor,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      fontSize: 13,
                    ),
                  ),
                ),
                if (isPermit && _teacherDocId != null)
                  StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: FirebaseFirestore.instance
                        .collection('schools')
                        .doc(SessionService.currentUser!.schoolId)
                        .collection('permits')
                        .snapshots(),
                    builder: (context, snapshot) {
                      final docs = snapshot.data?.docs ?? [];
                      final filteredDocs = docs.where((doc) {
                        final data = doc.data();
                        final permitTeacherId = data['teacherId']?.toString() ?? '';
                        final permitClassId = data['classId']?.toString() ?? '';
                        return permitTeacherId == _teacherDocId || _teacherClassIds.contains(permitClassId);
                      }).toList();

                      final pendingCount = filteredDocs.where((d) => d.data()['status'] == 'Pending').length;
                      if (pendingCount > 0) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.redAccent,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '$pendingCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                if (isDisabled)
                  const Icon(
                    Icons.lock_outline_rounded,
                    color: Colors.grey,
                    size: 16,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopContent(bool isDark, bool isGateOfficer, bool isLibrarian, List<QueryDocumentSnapshot<Map<String, dynamic>>> waliKelasClasses) {
    switch (_selectedMenuIndex) {
      case 0:
        return _buildDesktopDashboardHome(isDark);
      case 1:
        return TeacherSchedulePage(teacherId: _teacherDocId!, hideBackButton: true);
      case 2:
        return TeacherAttendanceSchedulePage(teacherId: _teacherDocId!, hideBackButton: true);
      case 3:
        return TeacherDailyAttendancePage(
          teacherId: _teacherDocId!,
          teacherName: _teacherData?['nama'] ?? SessionService.currentUser!.nama,
          nip: _teacherData?['nip'] ?? '',
          hideBackButton: true,
        );
      case 4:
        return TeacherGradesPage(teacherId: _teacherDocId!, hideBackButton: true);
      case 5:
        return TeacherTasksPage(teacherId: _teacherDocId!, hideBackButton: true);
      case 6:
        return TeacherExamsPage(teacherId: _teacherDocId!, hideBackButton: true);
      case 7:
        return TeacherBehaviorRecordsPage(teacherId: _teacherDocId!, hideBackButton: true);
      case 8:
        return TeacherChatSelectorPage(
          schoolId: SessionService.currentUser!.schoolId,
          teacherDocId: _teacherDocId!,
          teacherName: _teacherData?['nama'] ?? SessionService.currentUser!.nama,
        );
      case 9:
        return TeacherReportsPage(
          schoolId: SessionService.currentUser!.schoolId,
          teacherId: _teacherDocId!,
          hideBackButton: true,
        );
      case 10:
        return TeacherPermitsPage(
          teacherDocId: _teacherDocId!,
          schoolId: SessionService.currentUser!.schoolId,
          hideBackButton: true,
        );
      case 11:
        return TeacherSettingsPage(hideBackButton: true);
      case 12:
        return TeacherStudentViolationsPage(teacherId: _teacherDocId!);
      case 13:
        if (isGateOfficer) {
          return const OfficerDashboardPage();
        } else {
          return const Center(child: Text("Akses ditolak. Anda bukan petugas scan."));
        }
      case 14:
        if (isLibrarian) {
          return const LibrarianDashboardPage();
        } else {
          return const Center(child: Text("Akses ditolak. Anda bukan petugas perpustakaan."));
        }
      case 15:
        return TeacherProctorDashboardPage(
          teacherId: _teacherDocId!,
          hideBackButton: true,
        );
      case 16:
        return NotificationsPage(hideBackButton: true);
      case 17:
        return TeacherMyStudentsPage(
          schoolId: SessionService.currentUser!.schoolId,
          teacherId: _teacherDocId!,
          waliKelasClasses: waliKelasClasses,
          hideBackButton: true,
        );
      default:
        return _buildDesktopDashboardHome(isDark);
    }
  }

  Widget _buildDesktopDashboardHome(bool isDark) {
    final user = SessionService.currentUser!;
    final teacherId = _teacherDocId!;
    final teacherNama = _teacherData?['nama'] ?? user.nama;
    final teacherNip = _teacherData?['nip'] ?? '-';
    final titleColor = isDark ? Colors.white : const Color(0xFF1E1B4B);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _scheduleService.getSchedulesByTeacher(
        user.schoolId,
        teacherId,
      ),
      builder: (context, scheduleSnapshot) {
        final schedules =
            scheduleSnapshot.data?.docs.map((e) => e.data()).toList() ?? [];

        final Set<String> teacherClassIds = schedules
            .map((e) => (e['classId'] ?? '') as String)
            .where((id) => id.isNotEmpty)
            .toSet();

        final currentDay = _getCurrentDay();
        final todaySchedules = schedules
            .where((s) => s['hari'] == currentDay)
            .toList();
        todaySchedules.sort((a, b) {
          return _timeToMinutes(
            a['jamMulai'] ?? '',
          ).compareTo(_timeToMinutes(b['jamMulai'] ?? ''));
        });

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _teacherService.getClassesByTeacher(
            user.schoolId,
            teacherId,
          ),
          builder: (context, classSnapshot) {
            final waliKelasClasses = classSnapshot.data?.docs ?? [];

            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _teacherSubjectService.getSubjectsByTeacher(
                user.schoolId,
                teacherId,
              ),
              builder: (context, subjectSnapshot) {
                final teacherSubjects =
                    subjectSnapshot.data?.docs.map((e) => e.data()).toList() ?? [];

                return Scaffold(
                  backgroundColor: Colors.transparent,
                  appBar: AppBar(
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                    automaticallyImplyLeading: false,
                    title: Text(
                      _getGreeting(),
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: titleColor,
                      ),
                    ),
                  ),
                  body: RefreshIndicator(
                    onRefresh: _resolveTeacherDocId,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics(),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildProfileHeader(
                            teacherNama,
                            user.email,
                            teacherNip,
                            waliKelasClasses,
                            isDark,
                          ),
                          const SizedBox(height: 24),
                          Row(
                            children: [
                              Expanded(
                                child: _buildStatCard(
                                  title: AppLocalization.classesTaught,
                                  value: teacherClassIds.length.toString(),
                                  icon: Icons.class_rounded,
                                  color: const Color(0xFF6366F1),
                                  isDark: isDark,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _buildStatCard(
                                  title: AppLocalization.menuSubjects,
                                  value: teacherSubjects.length.toString(),
                                  icon: Icons.menu_book_rounded,
                                  color: const Color(0xFF10B981),
                                  isDark: isDark,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 32),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 3,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildSectionTitle(
                                      '${AppLocalization.todaySchedule} ($currentDay)',
                                      Icons.calendar_today_rounded,
                                      isDark,
                                    ),
                                    const SizedBox(height: 16),
                                    _buildTodaySchedule(
                                      todaySchedules,
                                      isDark,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 32),
                              Expanded(
                                flex: 2,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildSectionTitle(
                                      AppLocalization.mySubjects,
                                      Icons.menu_book_rounded,
                                      isDark,
                                    ),
                                    const SizedBox(height: 16),
                                    _buildSubjectsList(
                                      teacherSubjects,
                                      isDark,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

String _getGradeLevelForDashboard(String className) {
  final cleanName = className.toUpperCase().trim();
  if (cleanName.startsWith('XII') || cleanName.contains('12')) return '3';
  if (cleanName.startsWith('XI') || cleanName.contains('11')) {
    if (!cleanName.startsWith('XII')) return '2';
  }
  if (cleanName.startsWith('X') || cleanName.contains('10')) {
    if (!cleanName.startsWith('XII') && !cleanName.startsWith('XI')) return '1';
  }
  if (cleanName.startsWith('IX') || cleanName.contains('9')) return '3';
  if (cleanName.startsWith('VIII') || cleanName.contains('8')) return '2';
  if (cleanName.startsWith('VII') || cleanName.contains('7')) {
    if (!cleanName.startsWith('VIII')) return '1';
  }
  if (cleanName.contains('6')) return '6';
  if (cleanName.contains('5')) return '5';
  if (cleanName.contains('4')) return '4';
  if (cleanName.contains('3')) return '3';
  if (cleanName.contains('2')) return '2';
  return '1';
}
