import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';

import '../../../app/routes/app_routes.dart';
import '../../../core/services/session_service.dart';
import '../../../core/services/app_auth_service.dart';
import '../../authentication/widgets/auth_background.dart';
import '../../schools/services/school_service.dart';
import '../../teachers/pages/teacher_settings_page.dart';
import 'package:is_lock_screen2/is_lock_screen2.dart';

import '../data/student_service.dart';
import 'student_schedule_page.dart';
import 'student_attendance_page.dart';

class StudentDashboard extends StatefulWidget {
  const StudentDashboard({super.key});

  @override
  State<StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard> with WidgetsBindingObserver {
  final _studentService = StudentService();

  String? _studentDocId;
  Map<String, dynamic>? _studentData;
  bool _isLoadingStudent = true;

  String? _schoolName;
  String? _className;
  String _plan = 'FREE';
  bool _isLoadingSchool = true;
  String? _tahunAjaran;
  String? _activeSemester;

  // Behavior check cache to prevent background async calls from being suspended
  List<Map<String, dynamic>> _todaySchedules = [];
  bool _hasCheckedInToday = false;
  List<DocumentSnapshot<Map<String, dynamic>>> _todayAttendanceDocs = [];
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _attendanceSubscription;

  @override
  void initState() {
    super.initState();
    // Reset static trackers on initialization (e.g. after login)
    _lastReportedScheduleId = null;
    _lastReportedTime = null;
    _lastReportedState = null;
    _lastReportedIsLocked = null;

    WidgetsBinding.instance.addObserver(this);
    _resolveStudentDocId();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _attendanceSubscription?.cancel();
    super.dispose();
  }

  // Track last reported violations to avoid spamming Firestore
  static String? _lastReportedScheduleId;
  static DateTime? _lastReportedTime;
  static String? _lastReportedState; // 'paused' or 'resumed'
  static bool? _lastReportedIsLocked;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    debugPrint('=== AppLifecycleState changed to: $state ===');
    if (state == AppLifecycleState.inactive) {
      debugPrint('App inactive (losing focus) - reporting leaving immediately');
      _checkAndReportBehaviorViolation(isLocked: false);
    } else if (state == AppLifecycleState.paused) {
      debugPrint('App paused - checking lock screen status');
      bool isLocked = false;
      try {
        final locked = await isLockScreen();
        if (locked == true) {
          isLocked = true;
        }
      } catch (e) {
        debugPrint('Error checking lock screen status: $e');
      }
      if (isLocked) {
        _checkAndReportBehaviorViolation(isLocked: true);
      }
    } else if (state == AppLifecycleState.resumed) {
      debugPrint('App resumed - refreshing behavior cache and checking return');
      final user = SessionService.currentUser;
      if (user != null) {
        _loadTodaySchedulesAndStartAttendanceListener(user.schoolId);
        _checkAndReportBehaviorReturn();
      }
    }
  }

  int _timeToMinutes(String time) {
    final parts = time.split(':');
    if (parts.length != 2) return 0;
    return (int.tryParse(parts[0]) ?? 0) * 60 + (int.tryParse(parts[1]) ?? 0);
  }

  String _getTodayDateStr() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  String _getTodayHariIndonesian() {
    final now = DateTime.now();
    final days = ['Minggu', 'Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu'];
    return days[now.weekday % 7];
  }

  Future<void> _checkAndReportBehaviorViolation({bool isLocked = false}) async {
    final user = SessionService.currentUser;
    debugPrint('Behavior violation check initiated: User: ${user?.uid}, DocId: $_studentDocId, Class: $_className');
    if (user == null || _studentDocId == null || _className == null) {
      debugPrint('Behavior check aborted: missing user, docId, or className.');
      return;
    }

    final todayHari = _getTodayHariIndonesian();
    final dateStr = _getTodayDateStr();
    debugPrint('Current dateStr: $dateStr, day: $todayHari, cached hasCheckedIn: $_hasCheckedInToday, cached schedules: ${_todaySchedules.length}');

    // Synchronously check active schedule from cached today schedules
    Map<String, dynamic>? activeSchedule;
    final nowTime = DateTime.now();
    final nowMinutes = nowTime.hour * 60 + nowTime.minute;

    for (final s in _todaySchedules) {
      final jamMulai = s['jamMulai'] ?? '00:00';
      final jamSelesai = s['jamSelesai'] ?? '00:00';
      final startMinutes = _timeToMinutes(jamMulai);
      final endMinutes = _timeToMinutes(jamSelesai);
      if (nowMinutes >= startMinutes && nowMinutes <= endMinutes) {
        activeSchedule = s;
        debugPrint('Found active schedule synchronously: ${s['subjectName']}');
        break;
      }
    }

    // If neither is true, then do not report
    if (activeSchedule == null && !_hasCheckedInToday) {
      debugPrint('Behavior check: No active schedule right now and no check-ins today. Aborting report.');
      return;
    }

    String scheduleId = 'general';
    String subjectName = 'Absensi Hari Ini';

    if (activeSchedule != null) {
      scheduleId = activeSchedule['scheduleId'] ?? 'general';
      subjectName = activeSchedule['subjectName'] ?? 'Pelajaran';
    } else if (_todayAttendanceDocs.isNotEmpty) {
      final firstAtt = _todayAttendanceDocs.first.data();
      scheduleId = firstAtt?['scheduleId'] ?? 'general';
      subjectName = firstAtt?['subjectName'] ?? 'Absensi Hari Ini';
    }

    // Avoid double reporting within 5 minutes unless state or lock status has changed
    if (_lastReportedState == 'paused' &&
        _lastReportedIsLocked == isLocked &&
        _lastReportedScheduleId == scheduleId &&
        _lastReportedTime != null &&
        nowTime.difference(_lastReportedTime!).inMinutes < 5) {
      debugPrint('Behavior check: Already reported violation for $scheduleId within 5 minutes with lock state $isLocked. Skipping.');
      return;
    }

    _lastReportedScheduleId = scheduleId;
    _lastReportedTime = nowTime;
    _lastReportedState = 'paused';
    _lastReportedIsLocked = isLocked;

    final name = _studentData?['nama'] ?? 'Murid';
    debugPrint('Reporting violation synchronously/immediately to Firestore for student $name (Class $_className)...');
    try {
      await _studentService.reportBehaviorViolation(
        schoolId: user.schoolId,
        studentId: _studentDocId!,
        studentName: name,
        className: _className!,
        scheduleId: scheduleId,
        subjectName: subjectName,
        type: isLocked ? 'Layar Mati / Device Terkunci' : 'Meninggalkan Layar Absensi',
        description: isLocked
            ? (activeSchedule != null
                ? 'Device murid mati atau layar terkunci saat jam pelajaran $subjectName sedang berlangsung.'
                : 'Device murid mati atau layar terkunci setelah melakukan absensi pelajaran $subjectName hari ini.')
            : (activeSchedule != null
                ? 'Murid terdeteksi meninggalkan aplikasi absensi saat jam pelajaran $subjectName sedang berlangsung.'
                : 'Murid terdeteksi meninggalkan aplikasi absensi setelah melakukan absensi pelajaran $subjectName hari ini.'),
        tahunAjaran: _tahunAjaran ?? '-',
        semester: _activeSemester ?? '-',
      );
      debugPrint('Successfully reported behavior violation to Firestore.');
    } catch (e) {
      debugPrint('Exception in behavior violation check: $e');
    }
  }

  Future<void> _checkAndReportBehaviorReturn() async {
    final user = SessionService.currentUser;
    debugPrint('Behavior return check initiated: User: ${user?.uid}, DocId: $_studentDocId, Class: $_className');
    if (user == null || _studentDocId == null || _className == null) {
      debugPrint('Behavior return check aborted: missing user, docId, or className.');
      return;
    }

    final todayHari = _getTodayHariIndonesian();
    final dateStr = _getTodayDateStr();
    debugPrint('Current dateStr: $dateStr, day: $todayHari, cached hasCheckedIn: $_hasCheckedInToday, cached schedules: ${_todaySchedules.length}');

    // Synchronously check active schedule from cached today schedules
    Map<String, dynamic>? activeSchedule;
    final nowTime = DateTime.now();
    final nowMinutes = nowTime.hour * 60 + nowTime.minute;

    for (final s in _todaySchedules) {
      final jamMulai = s['jamMulai'] ?? '00:00';
      final jamSelesai = s['jamSelesai'] ?? '00:00';
      final startMinutes = _timeToMinutes(jamMulai);
      final endMinutes = _timeToMinutes(jamSelesai);
      if (nowMinutes >= startMinutes && nowMinutes <= endMinutes) {
        activeSchedule = s;
        debugPrint('Found active schedule synchronously: ${s['subjectName']}');
        break;
      }
    }

    // If neither is true, then do not report
    if (activeSchedule == null && !_hasCheckedInToday) {
      debugPrint('Behavior return check: No active schedule right now and no check-ins today. Aborting report.');
      return;
    }

    String scheduleId = 'general';
    String subjectName = 'Absensi Hari Ini';

    if (activeSchedule != null) {
      scheduleId = activeSchedule['scheduleId'] ?? 'general';
      subjectName = activeSchedule['subjectName'] ?? 'Pelajaran';
    } else if (_todayAttendanceDocs.isNotEmpty) {
      final firstAtt = _todayAttendanceDocs.first.data();
      scheduleId = firstAtt?['scheduleId'] ?? 'general';
      subjectName = firstAtt?['subjectName'] ?? 'Absensi Hari Ini';
    }

    // Avoid double reporting return unless state has changed
    if (_lastReportedState == 'resumed' && _lastReportedScheduleId == scheduleId) {
      debugPrint('Behavior return check: Already reported standby for $scheduleId. Skipping.');
      return;
    }

    _lastReportedScheduleId = scheduleId;
    _lastReportedTime = nowTime;
    _lastReportedState = 'resumed';
    _lastReportedIsLocked = null;

    final name = _studentData?['nama'] ?? 'Murid';
    debugPrint('Reporting return/standby synchronously/immediately to Firestore for student $name (Class $_className)...');
    try {
      await _studentService.reportBehaviorViolation(
        schoolId: user.schoolId,
        studentId: _studentDocId!,
        studentName: name,
        className: _className!,
        scheduleId: scheduleId,
        subjectName: subjectName,
        type: 'Kembali ke Aplikasi (Standby)',
        description: activeSchedule != null
            ? 'Murid terdeteksi kembali membuka aplikasi absensi (standby) saat jam pelajaran $subjectName sedang berlangsung.'
            : 'Murid terdeteksi kembali membuka aplikasi absensi (standby) setelah melakukan absensi pelajaran $subjectName hari ini.',
        tahunAjaran: _tahunAjaran ?? '-',
        semester: _activeSemester ?? '-',
      );
      debugPrint('Successfully reported behavior return/standby to Firestore.');
    } catch (e) {
      debugPrint('Exception in behavior return check: $e');
    }
  }

  Future<void> _reportLogoutBehavior() async {
    final user = SessionService.currentUser;
    if (user == null || _studentDocId == null || _className == null) {
      return;
    }

    // Synchronously check active schedule from cached today schedules
    Map<String, dynamic>? activeSchedule;
    final nowTime = DateTime.now();
    final nowMinutes = nowTime.hour * 60 + nowTime.minute;

    for (final s in _todaySchedules) {
      final jamMulai = s['jamMulai'] ?? '00:00';
      final jamSelesai = s['jamSelesai'] ?? '00:00';
      final startMinutes = _timeToMinutes(jamMulai);
      final endMinutes = _timeToMinutes(jamSelesai);
      if (nowMinutes >= startMinutes && nowMinutes <= endMinutes) {
        activeSchedule = s;
        break;
      }
    }

    if (activeSchedule == null && !_hasCheckedInToday) {
      return;
    }

    String scheduleId = 'general';
    String subjectName = 'Absensi Hari Ini';

    if (activeSchedule != null) {
      scheduleId = activeSchedule['scheduleId'] ?? 'general';
      subjectName = activeSchedule['subjectName'] ?? 'Pelajaran';
    } else if (_todayAttendanceDocs.isNotEmpty) {
      final firstAtt = _todayAttendanceDocs.first.data();
      scheduleId = firstAtt?['scheduleId'] ?? 'general';
      subjectName = firstAtt?['subjectName'] ?? 'Absensi Hari Ini';
    }

    final name = _studentData?['nama'] ?? 'Murid';
    try {
      await _studentService.reportBehaviorViolation(
        schoolId: user.schoolId,
        studentId: _studentDocId!,
        studentName: name,
        className: _className!,
        scheduleId: scheduleId,
        subjectName: subjectName,
        type: 'Meninggalkan Layar Absensi (Logout)',
        description: activeSchedule != null
            ? 'Murid terdeteksi melakukan logout saat jam pelajaran $subjectName sedang berlangsung.'
            : 'Murid terdeteksi melakukan logout setelah melakukan absensi pelajaran $subjectName hari ini.',
        tahunAjaran: _tahunAjaran ?? '-',
        semester: _activeSemester ?? '-',
      ).timeout(const Duration(seconds: 2));
      debugPrint('Successfully reported logout behavior to Firestore.');
    } catch (e) {
      debugPrint('Error reporting logout behavior: $e');
    }
  }

  Future<void> _loadTodaySchedulesAndStartAttendanceListener(String schoolId) async {
    if (_studentDocId == null || _className == null) return;

    final todayHari = _getTodayHariIndonesian();
    final dateStr = _getTodayDateStr();

    // 1. Fetch schedules once
    try {
      final schedSnapshot = await FirebaseFirestore.instance
          .collection('schools')
          .doc(schoolId)
          .collection('class_schedules')
          .where('className', isEqualTo: _className)
          .get();

      final schedules = schedSnapshot.docs.map((e) => e.data()).toList();
      if (mounted) {
        setState(() {
          _todaySchedules = schedules
              .where((s) => s['hari'] == todayHari && s['jenisJadwal'] != 'istirahat')
              .toList();
        });
        debugPrint('Behavior Cache: Loaded ${_todaySchedules.length} schedules today for class $_className');
      }
    } catch (e) {
      debugPrint('Behavior Cache error loading schedules: $e');
    }

    // 2. Set up real-time attendance stream listener
    _attendanceSubscription?.cancel();
    _attendanceSubscription = FirebaseFirestore.instance
        .collection('schools')
        .doc(schoolId)
        .collection('attendance')
        .where('studentId', isEqualTo: _studentDocId)
        .where('date', isEqualTo: dateStr)
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        setState(() {
          _hasCheckedInToday = snapshot.docs.isNotEmpty;
          _todayAttendanceDocs = snapshot.docs;
        });
        debugPrint('Behavior Cache: Updated hasCheckedInToday = $_hasCheckedInToday (${snapshot.docs.length} attendance records)');
        _checkAndReportBehaviorReturn();
      }
    }, onError: (e) {
      debugPrint('Behavior Cache attendance stream error: $e');
    });
  }

  Future<void> _resolveStudentDocId() async {
    final user = SessionService.currentUser!;
    final results = await Future.wait([
      SchoolService().getSchoolByDomain(user.schoolId),
      _studentService.getStudentDocByUid(user.schoolId, user.uid),
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
        }
        _studentDocId = doc?.id;
        _studentData = doc?.data();
        _className = doc?.data()?['className'] as String?;
        _isLoadingStudent = false;
        _isLoadingSchool = false;
      });

      if (_studentDocId != null && _className != null) {
        _loadTodaySchedulesAndStartAttendanceListener(user.schoolId);
      }
    }
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour >= 0 && hour <= 10) return 'Selamat Pagi';
    if (hour <= 14) return 'Selamat Siang';
    if (hour <= 18) return 'Selamat Sore';
    return 'Selamat Malam';
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: AuthBackground.isDarkMode,
      builder: (context, isDark, _) {
        if (_isLoadingStudent || _isLoadingSchool) {
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
        if (_studentDocId == null) {
          final infoTextColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
          final infoSubtitleColor = isDark ? Colors.white.withValues(alpha: 0.7) : const Color(0xFF1E1B4B).withValues(alpha: 0.8);
          final infoBorderColor = isDark ? Colors.white.withValues(alpha: 0.3) : const Color(0xFF1E1B4B).withValues(alpha: 0.3);
          
          return Scaffold(
            body: AuthBackground(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 64),
                      const SizedBox(height: 16),
                      Text(
                        'Akun Anda belum terhubung',
                        style: TextStyle(color: infoTextColor, fontSize: 20, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Data murid Anda tidak ditemukan di sekolah ini. Hubungi Admin Sekolah untuk menghubungkan akun Anda.',
                        style: TextStyle(color: infoSubtitleColor, fontSize: 14),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      OutlinedButton.icon(
                        onPressed: () async => await _logout(),
                        icon: Icon(Icons.logout_rounded, color: infoTextColor),
                        label: Text('Keluar', style: TextStyle(color: infoTextColor)),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: infoBorderColor),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }

        final student = _studentData ?? {};
        final name = student['nama'] ?? 'Murid';
        final email = student['email'] ?? '';
        final nis = student['nis'] ?? '-';
        
        final titleColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
        final iconBgColor = isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05);
        final iconColor = isDark ? Colors.white : const Color(0xFF1E1B4B);

        return Scaffold(
          body: AuthBackground(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverAppBar(
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  pinned: true,
                  toolbarHeight: 56,
                  title: Text(
                    _getGreeting(),
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: titleColor),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  actions: [
                    Container(
                      decoration: BoxDecoration(
                        color: iconBgColor,
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: Icon(Icons.notifications_rounded, color: iconColor, size: 20),
                        tooltip: 'Notifikasi',
                        onPressed: () => Get.toNamed(AppRoutes.notifications),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: iconBgColor,
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: Icon(Icons.settings_rounded, color: iconColor, size: 20),
                        tooltip: 'Pengaturan',
                        onPressed: () => Get.to(() => const TeacherSettingsPage()),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      margin: const EdgeInsets.only(right: 16),
                      decoration: BoxDecoration(
                        color: iconBgColor,
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: Icon(Icons.logout_rounded, color: iconColor, size: 20),
                        tooltip: 'Keluar',
                        onPressed: () async => await _logout(),
                      ),
                    ),
                  ],
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildProfileHeader(name, email, nis, isDark),
                        const SizedBox(height: 28),
                        _buildSectionTitle('Menu Utama', Icons.dashboard_rounded, isDark),
                        const SizedBox(height: 16),
                        _buildMenuGrid(isDark),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildProfileHeader(String name, String email, String nis, bool isDark) {
    final cardColor = isDark ? Colors.white.withValues(alpha: 0.06) : Colors.white;
    final cardBorder = isDark ? Colors.white.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.08);
    final cardShadow = isDark ? Colors.black.withValues(alpha: 0.2) : Colors.black.withValues(alpha: 0.05);
    final titleColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
    final subtitleColor = isDark ? Colors.white.withValues(alpha: 0.7) : const Color(0xFF1E1B4B).withValues(alpha: 0.6);
    final emailColor = isDark ? Colors.white.withValues(alpha: 0.5) : const Color(0xFF1E1B4B).withValues(alpha: 0.5);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: cardBorder),
        boxShadow: [
          BoxShadow(
            color: cardShadow,
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.2),
                  border: Border.all(color: const Color(0xFF8B5CF6), width: 2),
                ),
                child: const Icon(Icons.person_rounded, size: 36, color: Color(0xFF8B5CF6)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: titleColor)),
                    const SizedBox(height: 4),
                    Text(email, style: TextStyle(fontSize: 13, color: subtitleColor)),
                    const SizedBox(height: 4),
                    Text('NIS: $nis', style: TextStyle(fontSize: 12, color: emailColor)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.school_rounded, color: emailColor, size: 14),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _schoolName ?? 'Sekolah',
                            style: TextStyle(
                              fontSize: 12,
                              color: emailColor,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.class_rounded, color: emailColor, size: 14),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _className != null ? 'Kelas: $_className' : 'Belum masuk kelas',
                            style: TextStyle(
                              fontSize: 12,
                              color: emailColor,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF6366F1).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.5)),
                          ),
                          child: const Text(
                            'Murid',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF6366F1)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _buildPlanBadge(),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_tahunAjaran != null || _activeSemester != null) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.25)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today_rounded, color: Color(0xFF6366F1), size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Tahun Ajaran: ${_tahunAjaran ?? "-"}  |  ${_activeSemester ?? "-"}',
                      style: const TextStyle(color: Color(0xFF6366F1), fontSize: 13, fontWeight: FontWeight.w600),
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

  Widget _buildSectionTitle(String title, IconData icon, bool isDark) {
    final iconColor = isDark ? Colors.white.withValues(alpha: 0.8) : const Color(0xFF1E1B4B).withValues(alpha: 0.8);
    final textColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
    return Row(
      children: [
        Icon(icon, color: iconColor, size: 20),
        const SizedBox(width: 8),
        Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor, letterSpacing: 0.5)),
      ],
    );
  }

  Widget _buildMenuGrid(bool isDark) {
    final menus = [
      {'title': 'Absensi', 'icon': Icons.qr_code_scanner_rounded, 'color': const Color(0xFF8B5CF6)},
      {'title': 'Jadwal Saya', 'icon': Icons.calendar_month_rounded, 'color': const Color(0xFFF59E0B)},
      {'title': 'Nilai', 'icon': Icons.grade_rounded, 'color': const Color(0xFF10B981)},
      {'title': 'Chat Guru', 'icon': Icons.chat_rounded, 'color': const Color(0xFFF97316)},
      {'title': 'Fitur Premium', 'icon': Icons.workspace_premium_rounded, 'color': const Color(0xFFF97316)},
    ];
    final cardBg = isDark ? Colors.white.withValues(alpha: 0.03) : Colors.white;
    final cardBorder = isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06);
    final textColor = isDark ? Colors.white : const Color(0xFF1E1B4B);

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
        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _handleMenuTap(menu['title'] as String),
            borderRadius: BorderRadius.circular(20),
            child: Container(
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
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(menu['icon'] as IconData, color: color, size: 32),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    menu['title'] as String,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: textColor, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _handleMenuTap(String title) {
    final user = SessionService.currentUser!;
    switch (title) {
      case 'Absensi':
        if (_studentDocId == null || _studentData == null || _className == null || _className!.trim().isEmpty) {
          Get.snackbar(
            'Informasi',
            'Anda belum terhubung ke kelas manapun. Hubungi admin sekolah.',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.amber,
            colorText: Colors.black,
            margin: const EdgeInsets.all(16),
            borderRadius: 12,
            icon: const Icon(Icons.info_outline, color: Colors.black),
          );
        } else {
          Get.to(() => StudentAttendancePage(
                studentDocId: _studentDocId!,
                studentData: _studentData!,
                className: _className!,
                tahunAjaran: _tahunAjaran ?? '-',
                semester: _activeSemester ?? '-',
              ));
        }
        break;
      case 'Jadwal Saya':
        if (_className == null || _className!.trim().isEmpty) {
          Get.snackbar(
            'Informasi',
            'Anda belum masuk ke kelas manapun. Hubungi admin sekolah.',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.amber,
            colorText: Colors.black,
            margin: const EdgeInsets.all(16),
            borderRadius: 12,
            icon: const Icon(Icons.info_outline, color: Colors.black),
          );
        } else {
          Get.to(() => StudentSchedulePage(className: _className!));
        }
        break;
      case 'Fitur Premium':
        Get.toNamed(AppRoutes.premiumFeatures, arguments: {'plan': _plan, 'schoolId': user.schoolId});
        break;
      default:
        break;
    }
  }

  Future<void> _logout() async {
    final isDark = AuthBackground.isDarkMode.value;
    final bool? confirm = await Get.dialog<bool>(
      AlertDialog(
        backgroundColor: isDark ? const Color(0xFF0F0C20) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.08),
          ),
        ),
        title: Row(
          children: [
            const Icon(Icons.logout_rounded, color: Color(0xFFEF4444)),
            const SizedBox(width: 10),
            Text(
              'Keluar Akun',
              style: TextStyle(
                color: isDark ? Colors.white : const Color(0xFF1E1B4B),
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
        content: Text(
          'Apakah Anda yakin ingin keluar dari aplikasi?',
          style: TextStyle(
            color: isDark ? Colors.white.withValues(alpha: 0.7) : const Color(0xFF1E1B4B).withValues(alpha: 0.6),
            fontSize: 14,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: Text(
              'Batal',
              style: TextStyle(
                color: isDark ? Colors.white.withValues(alpha: 0.5) : const Color(0xFF1E1B4B).withValues(alpha: 0.5),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Get.back(result: true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              elevation: 0,
            ),
            child: const Text('Keluar', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _reportLogoutBehavior();
      await AppAuthService.logout();
      SessionService.logout();
      Get.offAllNamed('/login');
    } catch (e) {
      // ignore errors
    }
  }
}

