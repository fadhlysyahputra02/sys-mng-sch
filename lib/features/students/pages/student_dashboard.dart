import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../app/routes/app_routes.dart';
import '../../../core/services/session_service.dart';
import '../../../core/services/app_auth_service.dart';
import '../../authentication/widgets/auth_background.dart';
import '../../chat/student_chat_list_page.dart';
import '../../parent_link/pages/student_link_parent_page.dart';
import '../../chat/widgets/chat_unread_badge.dart';
import '../../schools/services/school_service.dart';
import '../../teachers/pages/teacher_settings_page.dart';
import 'package:is_lock_screen2/is_lock_screen2.dart';
import 'student_qr_identity_page.dart';
import '../data/student_service.dart';
import 'student_schedule_page.dart';
import 'student_attendance_page.dart';
import 'student_attendance_history_page.dart';
import 'student_grades_page.dart';
import 'student_tasks_page.dart';
import '../../exams/pages/student_exams_page.dart';
import '../../../core/widgets/motif_card.dart';
import '../../parent/pages/parent_violation_page.dart';
import 'student_payment_page.dart';

class StudentDashboard extends StatefulWidget {
  const StudentDashboard({super.key});

  @override
  State<StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard>
    with WidgetsBindingObserver {
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
  String? _schoolLogoBase64;

  // Behavior check cache to prevent background async calls from being suspended
  List<Map<String, dynamic>> _todaySchedules = [];
  bool _hasCheckedInToday = false;
  List<DocumentSnapshot<Map<String, dynamic>>> _todayAttendanceDocs = [];
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
  _attendanceSubscription;
  Timer? _selfHealTimer;

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

    _selfHealTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted &&
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
        _checkAndReportBehaviorReturn();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _attendanceSubscription?.cancel();
    _selfHealTimer?.cancel();
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

    if (state == AppLifecycleState.paused) {
      debugPrint(
        'App paused - checking lock screen status with delay for iOS brightness animation...',
      );
      // Memberi jeda 500ms agar animasi layar mati di iOS (brightness turun ke 0.0) selesai
      await Future.delayed(const Duration(milliseconds: 500));

      bool isLocked = false;
      try {
        final locked = await isLockScreen();
        if (locked == true) {
          isLocked = true;
        }
      } catch (e) {
        debugPrint('Error checking lock screen status: $e');
      }

      // Apabila isLocked true -> berarti Layar Mati / Terkunci
      // Apabila isLocked false -> berarti Keluar Aplikasi (Home Button / Recent Apps)
      _checkAndReportBehaviorViolation(isLocked: isLocked);
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
    final days = [
      'Minggu',
      'Senin',
      'Selasa',
      'Rabu',
      'Kamis',
      'Jumat',
      'Sabtu',
    ];
    return days[now.weekday % 7];
  }

  Future<void> _checkAndReportBehaviorViolation({bool isLocked = false}) async {
    if (_plan == 'FREE') return;
    if (_studentData?['lulus'] == true) return;
    final user = SessionService.currentUser;
    debugPrint(
      'Behavior violation check initiated: User: ${user?.uid}, DocId: $_studentDocId, Class: $_className',
    );
    if (user == null || _studentDocId == null || _className == null) {
      debugPrint('Behavior check aborted: missing user, docId, or className.');
      return;
    }

    final todayHari = _getTodayHariIndonesian();
    final dateStr = _getTodayDateStr();
    debugPrint(
      'Current dateStr: $dateStr, day: $todayHari, cached hasCheckedIn: $_hasCheckedInToday, cached schedules: ${_todaySchedules.length}',
    );

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
      debugPrint(
        'Behavior check: No active schedule right now and no check-ins today. Aborting report.',
      );
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
      debugPrint(
        'Behavior check: Already reported violation for $scheduleId within 5 minutes with lock state $isLocked. Skipping.',
      );
      return;
    }

    final name = _studentData?['nama'] ?? 'Murid';
    debugPrint(
      'Reporting violation synchronously/immediately to Firestore for student $name (Class $_className)...',
    );
    try {
      await _studentService.reportBehaviorViolation(
        schoolId: user.schoolId,
        studentId: _studentDocId!,
        studentName: name,
        className: _className!,
        scheduleId: scheduleId,
        subjectName: subjectName,
        type: isLocked
            ? 'Layar Mati / Device Terkunci'
            : 'Meninggalkan Layar Absensi',
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

      _lastReportedScheduleId = scheduleId;
      _lastReportedTime = nowTime;
      _lastReportedState = 'paused';
      _lastReportedIsLocked = isLocked;

      debugPrint('Successfully reported behavior violation to Firestore.');
    } catch (e) {
      debugPrint('Exception in behavior violation check: $e');
    }
  }

  Future<void> _checkAndReportBehaviorReturn() async {
    if (_plan == 'FREE') return;
    if (_studentData?['lulus'] == true) return;
    final user = SessionService.currentUser;
    debugPrint(
      'Behavior return check initiated: User: ${user?.uid}, DocId: $_studentDocId, Class: $_className',
    );
    if (user == null || _studentDocId == null || _className == null) {
      debugPrint(
        'Behavior return check aborted: missing user, docId, or className.',
      );
      return;
    }

    final todayHari = _getTodayHariIndonesian();
    final dateStr = _getTodayDateStr();
    debugPrint(
      'Current dateStr: $dateStr, day: $todayHari, cached hasCheckedIn: $_hasCheckedInToday, cached schedules: ${_todaySchedules.length}',
    );

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
      debugPrint(
        'Behavior return check: No active schedule right now and no check-ins today. Aborting report.',
      );
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
    if (_lastReportedState == 'resumed' &&
        _lastReportedScheduleId == scheduleId) {
      debugPrint(
        'Behavior return check: Already reported standby for $scheduleId. Skipping.',
      );
      return;
    }

    final name = _studentData?['nama'] ?? 'Murid';
    debugPrint(
      'Reporting return/standby synchronously/immediately to Firestore for student $name (Class $_className)...',
    );
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

      _lastReportedScheduleId = scheduleId;
      _lastReportedTime = nowTime;
      _lastReportedState = 'resumed';
      _lastReportedIsLocked = null;

      debugPrint('Successfully reported behavior return/standby to Firestore.');
    } catch (e) {
      debugPrint('Exception in behavior return check: $e');
    }
  }

  Future<void> _reportLogoutBehavior() async {
    if (_plan == 'FREE') return;
    if (_studentData?['lulus'] == true) return;
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
      await _studentService
          .reportBehaviorViolation(
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
          )
          .timeout(const Duration(seconds: 2));
      debugPrint('Successfully reported logout behavior to Firestore.');
    } catch (e) {
      debugPrint('Error reporting logout behavior: $e');
    }
  }

  Future<void> _loadTodaySchedulesAndStartAttendanceListener(
    String schoolId,
  ) async {
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
              .where(
                (s) =>
                    s['hari'] == todayHari && s['jenisJadwal'] != 'istirahat',
              )
              .toList();
        });
        debugPrint(
          'Behavior Cache: Loaded ${_todaySchedules.length} schedules today for class $_className',
        );

        // Bersihkan data sampah jadwal yang sudah selesai HANYA setelah jadwal selesai dimuat
        _cleanupMyExpiredBehaviorRecords();
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
        .listen(
          (snapshot) {
            if (mounted) {
              setState(() {
                _hasCheckedInToday = snapshot.docs.isNotEmpty;
                _todayAttendanceDocs = snapshot.docs;
              });
              debugPrint(
                'Behavior Cache: Updated hasCheckedInToday = $_hasCheckedInToday (${snapshot.docs.length} attendance records)',
              );
              _checkAndReportBehaviorReturn();
            }
          },
          onError: (e) {
            debugPrint('Behavior Cache attendance stream error: $e');
          },
        );
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
          _schoolLogoBase64 = schoolData['logoBase64'] as String?;
        }
        _studentDocId = doc?.id;
        _studentData = doc?.data();
        _className = doc?.data()?['className'] as String?;
        _isLoadingStudent = false;
        _isLoadingSchool = false;
      });

      if (_studentDocId != null && _className != null && _studentData?['lulus'] != true) {
        _loadTodaySchedulesAndStartAttendanceListener(user.schoolId);
      }
    }
  }

  Future<void> _cleanupMyExpiredBehaviorRecords() async {
    if (_studentDocId == null) return;
    final user = SessionService.currentUser;
    if (user == null) return;

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('schools')
          .doc(user.schoolId)
          .collection('behavior_records')
          .where('studentId', isEqualTo: _studentDocId)
          .get();

      if (snapshot.docs.isEmpty) return;

      final now = DateTime.now();
      final nowMinutes = now.hour * 60 + now.minute;
      final batch = FirebaseFirestore.instance.batch();
      bool hasDeletions = false;

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final scheduleId = data['scheduleId'] as String?;
        final timestamp = data['timestamp'] as Timestamp?;

        bool shouldDelete = false;

        if (timestamp != null) {
          final recordDate = timestamp.toDate();
          final isToday =
              recordDate.year == now.year &&
              recordDate.month == now.month &&
              recordDate.day == now.day;

          if (!isToday) {
            shouldDelete = true;
          } else if (scheduleId != null && scheduleId != 'general') {
            final schedule = _todaySchedules.firstWhere(
              (s) => s['scheduleId'] == scheduleId,
              orElse: () => <String, dynamic>{},
            );
            if (schedule.isNotEmpty) {
              final jamSelesai = schedule['jamSelesai'] ?? '00:00';
              final endMinutes = _timeToMinutes(jamSelesai);
              if (nowMinutes > endMinutes) {
                shouldDelete = true;
              }
            } else {
              // Not in today's schedules (might be orphaned)
              shouldDelete = true;
            }
          }
        } else {
          shouldDelete = true;
        }

        // Fallback TTL 24h
        if (!shouldDelete && timestamp != null) {
          if (now.difference(timestamp.toDate()).inHours > 24) {
            shouldDelete = true;
          }
        }

        if (shouldDelete) {
          batch.delete(doc.reference);
          hasDeletions = true;
        }
      }

      if (hasDeletions) {
        await batch.commit();
        debugPrint(
          'Student Auto-cleanup: Removed expired behavior records for $_studentDocId',
        );
      }
    } catch (e) {
      debugPrint('Student Auto-cleanup error: $e');
    }
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour >= 0 && hour <= 10) return 'Selamat Pagi';
    if (hour <= 14) return 'Selamat Siang';
    if (hour <= 18) return 'Selamat Sore';
    return 'Selamat Malam';
  }

  void _showFullScreenQr(BuildContext context, String qrData) {
    final isDark = AuthBackground.isDarkMode.value;
    final textColor = isDark ? Colors.white : const Color(0xFF1E1B4B);

    String? studentId;
    String? schoolId;
    try {
      final decoded = jsonDecode(qrData);
      studentId = decoded['studentId'];
      schoolId = decoded['schoolId'];
    } catch (_) {}

    StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? listener;

    if (schoolId != null && studentId != null) {
      final dateStr = _getTodayDateStr();
      final docRef = FirebaseFirestore.instance
          .collection('schools')
          .doc(schoolId)
          .collection('daily_attendance')
          .doc('${dateStr}_$studentId');

      bool isFirstEmit = true;
      Timestamp? initialTimestamp;

      listener = docRef.snapshots().listen((snapshot) {
        if (isFirstEmit) {
          isFirstEmit = false;
          if (snapshot.exists && snapshot.data() != null) {
            final data = snapshot.data()!;
            initialTimestamp = data['timestamp'] as Timestamp?;
          }
          return;
        }

        if (snapshot.exists && snapshot.data() != null) {
          final data = snapshot.data()!;
          final currentTimestamp = data['timestamp'] as Timestamp?;
          final status = data['status'] ?? 'hadir';

          if (currentTimestamp != null && currentTimestamp != initialTimestamp) {
            if (Get.isDialogOpen ?? false) {
              Get.back();
            }
            Get.snackbar(
              'Absensi Berhasil',
              'Anda berhasil melakukan absensi (Status: ${status.toString().toUpperCase()}).',
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
                'QR Absensi Siswa',
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
                  gapless: false,
                  eyeStyle: const QrEyeStyle(
                    eyeShape: QrEyeShape.square,
                    color: Color(0xFF0F0C20),
                  ),
                  dataModuleStyle: const QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.square,
                    color: Color(0xFF0F0C20),
                  ),
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

  @override
  Widget build(BuildContext context) {
    if (SessionService.currentUser == null) {
      Future.microtask(() => Get.offAllNamed(AppRoutes.splash));
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

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
                        'Data murid Anda tidak ditemukan di sekolah ini. Hubungi Admin Sekolah untuk menghubungkan akun Anda.',
                        style: TextStyle(
                          color: infoSubtitleColor,
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      OutlinedButton.icon(
                        onPressed: () async => await _logout(),
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

        final student = _studentData ?? {};
        final name = student['nama'] ?? 'Murid';
        final email = student['email'] ?? '';
        final nis = student['nis'] ?? '-';

        final titleColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
        final iconBgColor = isDark
            ? Colors.white.withValues(alpha: 0.1)
            : Colors.black.withValues(alpha: 0.05);
        final iconColor = isDark ? Colors.white : const Color(0xFF1E1B4B);

        return Scaffold(
          body: AuthBackground(
            child: RefreshIndicator(
              onRefresh: _resolveStudentDocId,
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
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: const Color(
                                  0xFF8B5CF6,
                                ).withValues(alpha: 0.4),
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(
                                    0xFF8B5CF6,
                                  ).withValues(alpha: 0.15),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                            child: ClipOval(
                              child: Image.memory(
                                base64Decode(_schoolLogoBase64!),
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Icon(
                                  Icons.school_rounded,
                                  size: 18,
                                  color: titleColor,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
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
                          icon: Icon(
                            Icons.settings_rounded,
                            color: iconColor,
                            size: 20,
                          ),
                          tooltip: 'Pengaturan',
                          onPressed: () =>
                              Get.to(() => const TeacherSettingsPage()),
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
                          icon: Icon(
                            Icons.logout_rounded,
                            color: iconColor,
                            size: 20,
                          ),
                          tooltip: 'Keluar',
                          onPressed: () async => await _logout(),
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
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildProfileHeader(name, email, nis, isDark),
                          const SizedBox(height: 28),
                          _buildSectionTitle(
                            'Menu Utama',
                            Icons.dashboard_rounded,
                            isDark,
                          ),
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
          ),
        );
      },
    );
  }

  Widget _buildProfileHeader(
    String name,
    String email,
    String nis,
    bool isDark,
  ) {
    final user = SessionService.currentUser!;
    final qrPayload = jsonEncode({
      'studentId': _studentDocId ?? '',
      'schoolId': user.schoolId,
      'nis': nis,
      'nama': name,
      'classId': _studentData?['classId'] ?? '',
      'className': _className ?? '',
    });

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
    final emailColor = isDark
        ? Colors.white.withValues(alpha: 0.5)
        : const Color(0xFF1E1B4B).withValues(alpha: 0.5);

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
              if (_studentData?['lulus'] == true)
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF6366F1).withValues(alpha: 0.35),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.school_rounded,
                      color: Colors.white,
                      size: 50,
                    ),
                  ),
                )
              else
                Container(
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
                    width: 112,
                    height: 112,
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
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: titleColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'NIS: $nis',
                      style: TextStyle(fontSize: 12, color: emailColor),
                    ),
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
                            _className != null
                                ? (_studentData?['lulus'] == true ? 'Kelas: $_className (Alumni)' : 'Kelas: $_className')
                                : 'Belum masuk kelas',
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
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFF6366F1,
                            ).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(
                                0xFF6366F1,
                              ).withValues(alpha: 0.5),
                            ),
                          ),
                          child: Text(
                            _studentData?['lulus'] == true ? 'Alumni' : 'Murid',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF6366F1),
                            ),
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
                      'Tahun Ajaran: ${_tahunAjaran ?? "-"}  |  ${_activeSemester ?? "-"}',
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

  Widget _buildMenuGrid(bool isDark) {
    final parentLinked = _studentData?['parentLinked'] == true;
    final isLulus = _studentData?['lulus'] == true;
    final menus = isLulus
        ? [
            {
              'title': 'Absensi',
              'icon': Icons.qr_code_scanner_rounded,
              'color': const Color(0xFF8B5CF6),
            },
            {
              'title': 'Nilai',
              'icon': Icons.grade_rounded,
              'color': const Color(0xFF10B981),
            },
          ]
        : [
            {
              'title': 'Absensi',
              'icon': Icons.qr_code_scanner_rounded,
              'color': const Color(0xFF8B5CF6),
            },
      {
        'title': 'Jadwal Saya',
        'icon': Icons.calendar_month_rounded,
        'color': const Color(0xFFF59E0B),
      },
      {
        'title': 'Nilai',
        'icon': Icons.grade_rounded,
        'color': const Color(0xFF10B981),
      },
      {
        'title': 'Chat Guru',
        'icon': Icons.chat_rounded,
        'color': const Color(0xFFF97316),
      },
      {
        'title': 'Tugas Saya',
        'icon': Icons.assignment_rounded,
        'color': const Color(0xFF6366F1),
      },
      {
        'title': 'Ujian Online',
        'icon': Icons.quiz_rounded,
        'color': const Color(0xFF8B5CF6),
      },
      {
        'title': 'Pelanggaran',
        'icon': Icons.warning_amber_rounded,
        'color': const Color(0xFFEF4444),
      },
      {
        'title': parentLinked ? 'Sudah Terhubung' : 'Sambungkan ke Orang Tua',
        'icon': parentLinked
            ? Icons.verified_rounded
            : Icons.family_restroom_rounded,
        'color': parentLinked
            ? const Color(0xFF10B981)
            : const Color(0xFF6366F1),
      },

      {
        'title': 'Bank Soal & Quiz',
        'icon': Icons.quiz_rounded,
        'color': const Color(0xFF14B8A6),
        'badge': 'BASIC',
      },
      {
        'title': 'News Feed Sekolah',
        'icon': Icons.newspaper_rounded,
        'color': const Color(0xFF0EA5E9),
        'badge': 'PRO',
      },
      {
        'title': 'Keuangan & SPP',
        'icon': Icons.payments_rounded,
        'color': const Color(0xFF10B981),
      },
    ];
    final cardBg = isDark ? Colors.white.withValues(alpha: 0.03) : Colors.white;
    final cardBorder = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.06);
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
              onTap: () => _handleMenuTap(menu['title'] as String),
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

                            if (menu['title'] == 'Chat Guru' && _studentDocId != null) {
                              return ChatUnreadBadge(
                                schoolId: SessionService.currentUser!.schoolId,
                                userId: _studentDocId!,
                                role: 'student',
                                top: -2,
                                right: -2,
                                child: container,
                              );
                            }

                            if (menu['title'] == 'Keuangan & SPP' && _studentDocId != null) {
                              return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                                stream: FirebaseFirestore.instance
                                    .collection('schools')
                                    .doc(SessionService.currentUser!.schoolId)
                                    .collection('student_bills')
                                    .where('studentId', isEqualTo: _studentDocId)
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

                            if (menu['title'] == 'Tugas Saya' &&
                                _studentDocId != null &&
                                _studentData?['classId'] != null) {
                              final studentClassId = _studentData!['classId'] as String;
                              return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                                stream: FirebaseFirestore.instance
                                    .collection('schools')
                                    .doc(SessionService.currentUser!.schoolId)
                                    .collection('tasks')
                                    .where('classId', isEqualTo: studentClassId)
                                    .snapshots(),
                                builder: (context, tasksSnapshot) {
                                  final tasks = tasksSnapshot.data?.docs ?? [];
                                  if (tasks.isEmpty) return container;

                                  return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                                    stream: FirebaseFirestore.instance
                                        .collection('schools')
                                        .doc(SessionService.currentUser!.schoolId)
                                        .collection('task_submissions')
                                        .where('studentId', isEqualTo: _studentDocId)
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
                                        if (taskTahunAjaran != _tahunAjaran ||
                                            taskSemester != _activeSemester) {
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

  Future<void> _handleMenuTap(String title) async {
    final user = SessionService.currentUser!;
    switch (title) {
      case 'Absensi':
        if (_studentDocId == null || _studentData == null) {
          Get.snackbar(
            'Informasi',
            'Data murid belum lengkap. Hubungi admin sekolah.',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.amber,
            colorText: Colors.black,
            margin: const EdgeInsets.all(16),
            borderRadius: 12,
            icon: const Icon(Icons.info_outline, color: Colors.black),
          );
        } else if (_studentData?['lulus'] == true) {
          Get.to(
            () => StudentAttendanceHistoryPage(
              studentDocId: _studentDocId!,
              className: _className ?? '-',
              studentName: _studentData?['nama'] ?? 'Murid',
            ),
          );
        } else if (_className == null || _className!.trim().isEmpty) {
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
          Get.to(
            () => StudentAttendancePage(
              studentDocId: _studentDocId!,
              studentData: _studentData!,
              className: _className!,
              tahunAjaran: _tahunAjaran ?? '-',
              semester: _activeSemester ?? '-',
            ),
          );
        }
        break;
        case 'Kartu QR Saya':
  if (_studentDocId == null || _studentData == null) {
    Get.snackbar(
      'Informasi',
      'Data murid belum lengkap. Hubungi admin sekolah.',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Colors.amber,
      colorText: Colors.black,
      margin: const EdgeInsets.all(16),
      borderRadius: 12,
    );
  } else {
    Get.to(() => StudentQrIdentityPage(
      studentDocId: _studentDocId!,
      studentData: _studentData!,
      schoolId: user.schoolId,
      schoolName: _schoolName,
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
      case 'Tugas Saya':
        if (_studentDocId == null ||
            _studentData == null ||
            _className == null ||
            _className!.trim().isEmpty) {
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
          Get.to(
            () => StudentTasksPage(
              studentDocId: _studentDocId!,
              studentData: _studentData!,
              className: _className!,
              tahunAjaran: _tahunAjaran ?? '-',
              semester: _activeSemester ?? '-',
            ),
          );
        }
        break;
      case 'Ujian Online':
        if (_studentDocId == null ||
            _studentData == null ||
            _studentData?['classId'] == null) {
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
          final classId = _studentData!['classId'] as String;
          Get.to(() => StudentExamsPage(classId: classId));
        }
        break;
      case 'Pelanggaran':
        if (_studentDocId == null) {
          Get.snackbar(
            'Informasi',
            'Data murid belum lengkap. Hubungi admin sekolah.',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.amber,
            colorText: Colors.black,
            margin: const EdgeInsets.all(16),
            borderRadius: 12,
            icon: const Icon(Icons.info_outline, color: Colors.black),
          );
        } else {
          Get.to(
            () => const ParentViolationPage(),
            arguments: {
              'schoolId': user.schoolId,
              'studentId': _studentDocId!,
            },
          );
        }
        break;
      case 'Nilai':
        if (_studentDocId == null || _className == null) {
          Get.snackbar(
            'Informasi',
            'Data murid belum lengkap. Hubungi admin sekolah.',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.amber,
            colorText: Colors.black,
            margin: const EdgeInsets.all(16),
            borderRadius: 12,
            icon: const Icon(Icons.info_outline, color: Colors.black),
          );
        } else {
          // Ambil classId dari studentData
          final classId = (_studentData?['classId'] as String?) ?? '';
          if (classId.isEmpty) {
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
            Get.to(
              () => StudentGradesPage(
                studentDocId: _studentDocId!,
                className: _className!,
                classId: classId,
                tahunAjaran: _tahunAjaran ?? '-',
                semester: _activeSemester ?? '-',
              ),
            );
          }
        }
        break;
      case 'Chat Guru':
        if (_studentDocId == null || _className == null) {
          Get.snackbar(
            'Informasi',
            'Data murid belum lengkap. Hubungi admin sekolah.',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.amber,
            colorText: Colors.black,
            margin: const EdgeInsets.all(16),
            borderRadius: 12,
            icon: const Icon(Icons.info_outline, color: Colors.black),
          );
        } else {
          Get.to(
            () => StudentChatListPage(
              schoolId: user.schoolId,
              studentDocId: _studentDocId!,
              studentName: _studentData?['nama'] ?? 'Murid',
              className: _className!,
            ),
          );
        }
        break;
      case 'Sambungkan ke Orang Tua':
        if (_studentDocId == null) {
          Get.snackbar(
            'Informasi',
            'Data murid belum lengkap. Hubungi admin sekolah.',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.amber,
            colorText: Colors.black,
            margin: const EdgeInsets.all(16),
            borderRadius: 12,
            icon: const Icon(Icons.info_outline, color: Colors.black),
          );
        } else {
          final linked = await Get.to<bool>(
            () => StudentLinkParentPage(
              schoolId: user.schoolId,
              studentId: _studentDocId!,
              studentName: _studentData?['nama'] ?? 'Murid',
            ),
          );
          if (linked == true && mounted) {
            await _resolveStudentDocId();
            Get.snackbar(
              'Berhasil',
              'Akun orang tua berhasil terhubung.',
              snackPosition: SnackPosition.BOTTOM,
              backgroundColor: const Color(0xFF10B981),
              colorText: Colors.white,
              margin: const EdgeInsets.all(16),
              borderRadius: 12,
              icon: const Icon(Icons.verified_rounded, color: Colors.white),
            );
          }
        }
        break;
      case 'Sudah Terhubung':
        Get.snackbar(
          'Terhubung',
          'Akun Anda sudah terhubung dengan orang tua.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: const Color(0xFF10B981),
          colorText: Colors.white,
          margin: const EdgeInsets.all(16),
          borderRadius: 12,
          icon: const Icon(Icons.verified_rounded, color: Colors.white),
        );
        break;
      case 'Bank Soal & Quiz':
        Get.toNamed(AppRoutes.comingSoonBankSoalMurid);
        break;
      case 'Surat Izin Digital':
        Get.toNamed(AppRoutes.comingSoonSuratIzinMurid);
        break;
      case 'News Feed Sekolah':
        Get.toNamed(AppRoutes.comingSoonNewsFeedMurid);
        break;
      case 'Keuangan & SPP':
        if (_studentDocId == null) {
          Get.snackbar(
            'Informasi',
            'Data murid belum lengkap. Hubungi admin sekolah.',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.amber,
            colorText: Colors.black,
            margin: const EdgeInsets.all(16),
            borderRadius: 12,
            icon: const Icon(Icons.info_outline, color: Colors.black),
          );
        } else {
          Get.to(
            () => StudentPaymentPage(
              schoolId: user.schoolId,
              studentId: _studentDocId!,
              studentName: _studentData?['nama'] ?? 'Murid',
            ),
          );
        }
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
            color: isDark
                ? Colors.white.withValues(alpha: 0.1)
                : Colors.black.withValues(alpha: 0.08),
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
            color: isDark
                ? Colors.white.withValues(alpha: 0.7)
                : const Color(0xFF1E1B4B).withValues(alpha: 0.6),
            fontSize: 14,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
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
            onPressed: () => Get.back(result: true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              elevation: 0,
            ),
            child: const Text(
              'Keluar',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
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
