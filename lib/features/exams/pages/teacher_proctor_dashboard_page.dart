import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../../core/services/session_service.dart';
import '../../authentication/widgets/auth_background.dart';
import '../../students/pages/student_qr_scanner_page.dart';
import '../models/exam_event_model.dart';
import '../models/exam_model.dart';
import '../models/exam_submission_model.dart';
import '../services/exam_session_service.dart';
import '../services/exam_service.dart';
import '../services/exam_behavior_service.dart';
import '../../students/data/student_service.dart';
import 'teacher_exam_questions_page.dart';
import 'teacher_grade_exam_page.dart';
import '../../../core/localization/app_localization.dart';

// ─────────────────────────────────────────────────────────────
//  TeacherProctorDashboardPage
//  Tab 1 — Pengawas: Jadwal mengawas + aktivasi QR
//  Tab 2 — Pembuat Soal: Mapel yang ditugaskan untuk upload soal
// ─────────────────────────────────────────────────────────────

class TeacherProctorDashboardPage extends StatefulWidget {
  final String teacherId;
  final bool hideBackButton;
  const TeacherProctorDashboardPage({
    super.key,
    required this.teacherId,
    this.hideBackButton = false,
  });

  @override
  State<TeacherProctorDashboardPage> createState() =>
      _TeacherProctorDashboardPageState();
}

class _TeacherProctorDashboardPageState
    extends State<TeacherProctorDashboardPage> {
  final _service = ExamSessionService();
  final _examService = ExamService();
  Timer? _refreshTimer;
  Map<String, String> _classIdToAngkatan = {};
  bool _isAuthor = false;
  bool _isLoadingAuthorCheck = true;

  @override
  void initState() {
    super.initState();
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted) {
        setState(() {});
      }
    });
    _loadAngkatanMapping();
    _checkIfAuthor();
  }

  Future<void> _loadAngkatanMapping() async {
    final schoolId = SessionService.currentUser!.schoolId;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('schools')
          .doc(schoolId)
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

  Future<void> _checkIfAuthor() async {
    try {
      final schoolId = SessionService.currentUser!.schoolId;
      final sessionsSnap = await FirebaseFirestore.instance
          .collection('schools')
          .doc(schoolId)
          .collection('exam_sessions')
          .get();

      bool isAuthor = false;
      for (final doc in sessionsSnap.docs) {
        final authorTeacherId = doc.data()['authorTeacherId']?.toString() ?? '';
        if (authorTeacherId.split(',').contains(widget.teacherId)) {
          isAuthor = true;
          break;
        }
      }

      if (mounted) {
        setState(() {
          _isAuthor = isAuthor;
          _isLoadingAuthorCheck = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoadingAuthorCheck = false;
        });
      }
    }
  }

  String _resolveAngkatan(String classId, String className) {
    final a = _classIdToAngkatan[classId];
    final rawGrade = (a != null && a.isNotEmpty) ? a : _getGradeLevel(className);
    return rawGrade == '3' ? '2020' : (rawGrade == '2' ? '2021' : (rawGrade == '1' ? '2022' : rawGrade));
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final schoolId = SessionService.currentUser!.schoolId;

    return ValueListenableBuilder<String>(
      valueListenable: AppLocalization.currentLocale,
      builder: (context, _, __) {
        return ValueListenableBuilder<bool>(
          valueListenable: AuthBackground.isDarkMode,
          builder: (context, isDark, _) {
        final titleColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
        final subtitleColor = isDark
            ? Colors.white.withValues(alpha: 0.55)
            : const Color(0xFF1E1B4B).withValues(alpha: 0.6);
        final cardColor =
            isDark ? Colors.white.withValues(alpha: 0.06) : Colors.white;
        final cardBorder = isDark
            ? Colors.white.withValues(alpha: 0.10)
            : Colors.black.withValues(alpha: 0.08);
        final tabBg = isDark
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.black.withValues(alpha: 0.04);

        if (_isLoadingAuthorCheck) {
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

        return DefaultTabController(
          key: ValueKey('proctor_tabs_${_isAuthor ? 3 : 2}'),
          length: _isAuthor ? 3 : 2,
          child: Scaffold(
            body: AuthBackground(
              child: Column(
                children: [
                  // AppBar
                  SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
                      child: Row(
                        children: [
                          if (!widget.hideBackButton)
                            IconButton(
                              icon: Icon(Icons.arrow_back_rounded,
                                  color: titleColor),
                              onPressed: () => Get.back(),
                            ),
                          if (widget.hideBackButton)
                            const SizedBox(width: 16),
                          Text(
                            AppLocalization.isIndonesian ? 'Ujian Semester' : 'Semester Exam',
                            style: TextStyle(
                              color: titleColor,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
  
                  // Tab Bar
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                    child: Container(
                      decoration: BoxDecoration(
                        color: tabBg,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: TabBar(
                        indicator: BoxDecoration(
                          color: const Color(0xFF8B5CF6),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        indicatorSize: TabBarIndicatorSize.tab,
                        dividerColor: Colors.transparent,
                        labelColor: Colors.white,
                        unselectedLabelColor: subtitleColor,
                        labelStyle: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 13),
                        tabs: [
                          Tab(
                            icon: const Icon(Icons.supervisor_account_rounded, size: 18),
                            text: AppLocalization.isIndonesian ? 'Pengawas' : 'Proctor',
                            iconMargin: const EdgeInsets.only(bottom: 2),
                          ),
                          Tab(
                            icon: const Icon(Icons.edit_document, size: 18),
                            text: AppLocalization.isIndonesian ? 'Pembuat Soal' : 'Author',
                            iconMargin: const EdgeInsets.only(bottom: 2),
                          ),
                          if (_isAuthor)
                            Tab(
                              icon: const Icon(Icons.grading_rounded, size: 18),
                              text: AppLocalization.isIndonesian ? 'Koreksi Ujian' : 'Exam Grading',
                              iconMargin: const EdgeInsets.only(bottom: 2),
                            ),
                        ],
                      ),
                    ),
                  ),
  
                  // Tab Content
                  Expanded(
                    child: TabBarView(
                      children: [
                        // Tab 1: Pengawas
                        _buildProctorTab(
                            schoolId, isDark, cardColor, cardBorder,
                            titleColor, subtitleColor),
  
                        // Tab 2: Pembuat Soal
                        _buildAuthorTab(
                            schoolId, isDark, cardColor, cardBorder,
                            titleColor, subtitleColor),
  
                        // Tab 3: Koreksi Ujian
                        if (_isAuthor)
                          _buildGradingTab(
                              schoolId, isDark, cardColor, cardBorder,
                              titleColor, subtitleColor),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
      },
    );
  }

  // ── Tab 1: Pengawas ──────────────────────────────────────────
  Widget _buildProctorTab(
    String schoolId,
    bool isDark,
    Color cardColor,
    Color cardBorder,
    Color titleColor,
    Color subtitleColor,
  ) {
    return StreamBuilder<List<ExamSession>>(
      stream: _service.getSessionsByProctor(schoolId, widget.teacherId),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return Center(
              child: CircularProgressIndicator(
                  color: isDark ? Colors.white : const Color(0xFF8B5CF6)));
        }

        final sessions = snap.data ?? [];
        final now = DateTime.now();
        final todayStr = DateFormat('yyyy-MM-dd').format(now);

        // Hitung status efektif berdasarkan waktu nyata (bukan hanya field Firestore)
        String computeEffectiveStatus(ExamSession s) {
          if (s.examStatus == 'Finished') return 'Finished';
          final sessionDateStr = DateFormat('yyyy-MM-dd').format(s.date);
          if (sessionDateStr == todayStr) {
            // Hari ini: cek apakah endTime sudah lewat
            try {
              final parts = s.endTime.split(':');
              final endDt = DateTime(
                s.date.year, s.date.month, s.date.day,
                int.parse(parts[0]), int.parse(parts[1]),
              );
              if (now.isAfter(endDt)) return 'Finished';
            } catch (_) {}
            return s.examStatus; // 'Active' atau 'Scheduled'
          }
          // Bukan hari ini
          if (s.date.isBefore(DateTime(now.year, now.month, now.day))) {
            return 'Finished'; // Hari lampau
          }
          return s.examStatus;
        }

        final upcoming = sessions
            .where((s) => computeEffectiveStatus(s) != 'Finished')
            .toList();
        final past = sessions
            .where((s) => computeEffectiveStatus(s) == 'Finished')
            .toList();

        if (sessions.isEmpty) {
          return _buildEmptyState(
            isDark,
            titleColor,
            subtitleColor,
            Icons.supervisor_account_rounded,
            AppLocalization.isIndonesian ? 'Tidak Ada Tugas Mengawas' : 'No Proctoring Tasks',
            AppLocalization.isIndonesian
                ? 'Anda belum ditugaskan sebagai pengawas ujian.'
                : 'You have not been assigned as an exam proctor.',
          );
        }

        return ListView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
          children: [
            if (upcoming.isNotEmpty) ...[
              const SizedBox(height: 10),
              _buildSectionHeader(
                  AppLocalization.isIndonesian ? 'Jadwal Mendatang' : 'Upcoming Schedule',
                  Icons.upcoming_rounded,
                  const Color(0xFF8B5CF6),
                  isDark,
                  titleColor),
              const SizedBox(height: 10),
              ...upcoming.map((s) => _buildProctorSessionCard(
                  s, isDark, cardColor, cardBorder, titleColor, subtitleColor,
                  schoolId,
                  effectiveStatus: computeEffectiveStatus(s))),
            ],
            if (past.isNotEmpty) ...[
              const SizedBox(height: 20),
              _buildSectionHeader(
                  AppLocalization.isIndonesian ? 'Selesai' : 'Finished',
                  Icons.history_rounded,
                  const Color(0xFF64748B),
                  isDark,
                  titleColor),
              const SizedBox(height: 10),
              ...past.map((s) => _buildProctorSessionCard(
                  s, isDark, cardColor, cardBorder, titleColor, subtitleColor,
                  schoolId,
                  isFinished: true,
                  effectiveStatus: 'Finished')),
            ],
          ],
        );
      },
    );
  }

  Widget _buildProctorSessionCard(
    ExamSession session,
    bool isDark,
    Color cardColor,
    Color cardBorder,
    Color titleColor,
    Color subtitleColor,
    String schoolId, {
    bool isFinished = false,
    String? effectiveStatus,
  }) {
    final isToday = DateFormat('yyyy-MM-dd').format(session.date) ==
        DateFormat('yyyy-MM-dd').format(DateTime.now());
    final resolvedStatus = effectiveStatus ?? session.examStatus;
    // Active only if status is truly Active AND it's today AND endTime not yet passed
    final isActive = resolvedStatus == 'Active' && isToday;

    // Cek apakah jam ujian sudah dimulai (untuk menampilkan tombol Selesaikan)
    bool isSessionTimeStarted = false;
    if (isToday && resolvedStatus == 'Active') {
      try {
        final parts = session.startTime.split(':');
        if (parts.length >= 2) {
          final now = DateTime.now();
          final sessionStart = DateTime(
            session.date.year, session.date.month, session.date.day,
            int.parse(parts[0]), int.parse(parts[1]),
          );
          isSessionTimeStarted = !now.isBefore(sessionStart);
        }
      } catch (_) {}
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isActive
              ? const Color(0xFF10B981).withValues(alpha: 0.5)
              : isToday
                  ? const Color(0xFF8B5CF6).withValues(alpha: 0.4)
                  : cardBorder,
          width: isActive || isToday ? 1.5 : 1,
        ),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                )
              ]
            : null,
      ),
      child: Column(
        children: [
          // Status strip
          if (isActive)
            Container(
              height: 3,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                    colors: [Color(0xFF10B981), Color(0xFF06B6D4)]),
                borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Status badge
                    _buildStatusBadge(session, resolvedStatus, isToday: isToday),
                    const SizedBox(width: 8),
                    if (isToday && !isFinished && resolvedStatus == 'Active')
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(AppLocalization.isIndonesian ? 'Hari Ini' : 'Today',
                            style: const TextStyle(
                                color: Color(0xFFF59E0B),
                                fontSize: 10,
                                fontWeight: FontWeight.bold)),
                      ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(session.slotName,
                          style: const TextStyle(
                              color: Color(0xFF8B5CF6),
                              fontSize: 10,
                              fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(session.subjectName,
                    style: TextStyle(
                        color: titleColor,
                        fontSize: 15,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(
                  '${AppLocalization.isIndonesian ? DateFormat('EEEE, dd MMMM yyyy', 'id').format(session.date) : DateFormat('EEEE, MMMM dd, yyyy', 'en').format(session.date)} • ${session.startTime}–${session.endTime}',
                  style: TextStyle(color: subtitleColor, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text('${AppLocalization.isIndonesian ? 'Kelas' : 'Class'}: ${session.className.isEmpty ? session.classId : session.className} • ${AppLocalization.isIndonesian ? 'Ruang' : 'Room'}: ${session.roomName.isEmpty ? '-' : session.roomName}',
                    style: TextStyle(color: subtitleColor, fontSize: 12)),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => Get.to(() => ProctorRoomSeatingPage(
                        schoolId: schoolId,
                        session: session,
                      )),
                  icon: const Icon(Icons.grid_on_rounded, size: 16, color: Color(0xFF8B5CF6)),
                  label: Text(AppLocalization.isIndonesian ? 'Denah Tempat Duduk' : 'Seating Plan',
                      style: const TextStyle(color: Color(0xFF8B5CF6))),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF8B5CF6), width: 1),
                    minimumSize: const Size(double.infinity, 38),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    textStyle: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ),
                if (!isToday)
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF64748B).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: const Color(0xFF64748B).withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.event_rounded,
                            size: 14, color: Color(0xFF64748B)),
                        const SizedBox(width: 6),
                        Text(AppLocalization.isIndonesian ? 'Scan QR hanya bisa dilakukan pada hari H' : 'QR scan can only be performed on the day of the exam',
                            style: const TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            )),
                      ],
                    ),
                  ),
                if (isToday)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _activateQr(schoolId, session),
                            icon: const Icon(Icons.qr_code_scanner_rounded, size: 16),
                            label: Text(AppLocalization.isIndonesian ? 'Scan QR Murid' : 'Scan Student QR'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF8B5CF6),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              textStyle: const TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        if (isSessionTimeStarted) ...[
                          const SizedBox(width: 10),
                          OutlinedButton(
                            onPressed: () => _finishSession(schoolId, session),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(
                                  color: Color(0xFFEF4444), width: 1),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                              foregroundColor: const Color(0xFFEF4444),
                            ),
                            child: Text(AppLocalization.isIndonesian ? 'Selesaikan' : 'Finish',
                                style: const TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(ExamSession session, String status, {bool isToday = false}) {
    Color color;
    String label;
    IconData icon;

    // Parse session start time
    final now = DateTime.now();
    DateTime? sessionStart;
    try {
      final parts = session.startTime.split(':');
      if (parts.length >= 2) {
        final hour = int.parse(parts[0]);
        final min = int.parse(parts[1]);
        sessionStart = DateTime(
          session.date.year,
          session.date.month,
          session.date.day,
          hour,
          min,
        );
      }
    } catch (_) {}

    switch (status) {
      case 'Active':
        if (sessionStart != null && now.isBefore(sessionStart)) {
          final diff = sessionStart.difference(now);
          final diffMin = diff.inMinutes;
          final diffSec = diff.inSeconds;

          if (diffMin > 0) {
            label = AppLocalization.isIndonesian ? '$diffMin menit lagi' : '$diffMin mins left';
          } else if (diffSec > 0) {
            label = AppLocalization.isIndonesian ? '1 menit lagi' : '1 min left';
          } else {
            label = AppLocalization.isIndonesian ? 'Sedang Berlangsung' : 'Ongoing';
          }
          color = const Color(0xFFF59E0B);
          icon = Icons.timer_outlined;
        } else {
          color = const Color(0xFF10B981);
          label = AppLocalization.isIndonesian ? 'Sedang Berlangsung' : 'Ongoing';
          icon = Icons.play_circle_rounded;
        }
        break;
      case 'Finished':
        color = const Color(0xFF64748B);
        label = AppLocalization.isIndonesian ? 'Selesai' : 'Finished';
        icon = Icons.check_circle_rounded;
        break;
      default:
        if (isToday) {
          color = const Color(0xFF8B5CF6);
          label = AppLocalization.isIndonesian ? 'Hari Ini' : 'Today';
          icon = Icons.today_rounded;
        } else {
          color = const Color(0xFFF59E0B);
          label = AppLocalization.isIndonesian ? 'Terjadwal' : 'Scheduled';
          icon = Icons.schedule_rounded;
        }
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  color: color, fontSize: 10, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  // ── Tab 2: Pembuat Soal ──────────────────────────────────────
  Widget _buildAuthorTab(
    String schoolId,
    bool isDark,
    Color cardColor,
    Color cardBorder,
    Color titleColor,
    Color subtitleColor,
  ) {
    return StreamBuilder<List<ExamSession>>(
      stream: _service.getSessionsByAuthor(schoolId, widget.teacherId),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return Center(
              child: CircularProgressIndicator(
                  color: isDark ? Colors.white : const Color(0xFF8B5CF6)));
        }

        final sessions = snap.data ?? [];

        // Grup unique per subjectId dan gradeLevel
        final Map<String, ExamSession> uniqueSubjects = {};
        for (final s in sessions) {
          final grade = _resolveAngkatan(s.classId, s.className);
          uniqueSubjects.putIfAbsent('${s.subjectId}_$grade', () => s);
        }
        final subjects = uniqueSubjects.values.toList();

        if (subjects.isEmpty) {
          return _buildEmptyState(
            isDark,
            titleColor,
            subtitleColor,
            Icons.edit_document,
            AppLocalization.isIndonesian ? 'Tidak Ada Penugasan Soal' : 'No Question Assignments',
            AppLocalization.isIndonesian
                ? 'Anda belum ditugaskan sebagai pembuat soal untuk event ujian apapun.'
                : 'You have not been assigned as a question author for any exam events.',
          );
        }

        return ListView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
          children: [
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_rounded,
                      color: Color(0xFFF59E0B), size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      AppLocalization.isIndonesian
                          ? 'Anda adalah pembuat soal untuk mata pelajaran berikut. Siapkan dan upload bank soal sebelum pelaksanaan ujian.'
                          : 'You are the question author for the following subjects. Prepare and upload the question bank before the exam.',
                      style: TextStyle(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.9),
                        fontSize: 12,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            ...subjects.map((session) => _buildAuthorSubjectCard(
                session, isDark, cardColor, cardBorder, titleColor, subtitleColor,
                sessions
                    .where((s) => s.subjectId == session.subjectId && _resolveAngkatan(s.classId, s.className) == _resolveAngkatan(session.classId, session.className))
                    .length)),
          ],
        );
      },
    );
  }

  Widget _buildAuthorSubjectCard(
    ExamSession session,
    bool isDark,
    Color cardColor,
    Color cardBorder,
    Color titleColor,
    Color subtitleColor,
    int sessionCount,
  ) {
    final gradeLevel = _resolveAngkatan(session.classId, session.className);
    return GestureDetector(
      onTap: () => Get.to(() => TeacherExamQuestionsPage(
            eventId: session.eventId,
            subjectId: session.subjectId,
            subjectName: '${session.subjectName} - Kelas $gradeLevel',
            teacherId: widget.teacherId,
            gradeLevel: gradeLevel,
          )),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: cardBorder),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.15)
                  : Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFF59E0B), Color(0xFFEF4444)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.menu_book_rounded,
                  color: Colors.white, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(session.subjectName,
                      style: TextStyle(
                          color: titleColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 14)),
                  const SizedBox(height: 4),
                  Text(
                      AppLocalization.isIndonesian
                          ? '$sessionCount kelas menggunakan soal ini'
                          : '$sessionCount classes use these questions',
                      style: TextStyle(color: subtitleColor, fontSize: 12)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
              ),
              child: Text(AppLocalization.isIndonesian ? 'Penulis' : 'Author',
                  style: const TextStyle(
                      color: Color(0xFFF59E0B),
                      fontSize: 11,
                      fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  // ── Actions ──────────────────────────────────────────────────
  Future<void> _activateQr(String schoolId, ExamSession session) async {
    try {
      await _service.activateSessionQr(
          schoolId: schoolId, sessionId: session.id);
      if (mounted) {
        Get.snackbar(
            AppLocalization.isIndonesian ? 'Berhasil' : 'Success',
            AppLocalization.isIndonesian
                ? 'QR Presensi Ujian berhasil diaktifkan.'
                : 'Exam presence QR successfully activated.',
            backgroundColor: const Color(0xFF10B981),
            colorText: Colors.white,
            snackPosition: SnackPosition.TOP,
            margin: const EdgeInsets.all(16));
        _scanStudentQrForSession(context, session.copyWith(isQrActive: true));
      }
    } catch (e) {
      Get.snackbar(
          AppLocalization.isIndonesian ? 'Gagal' : 'Failed',
          AppLocalization.isIndonesian ? 'Tidak dapat mengaktifkan QR: $e' : 'Cannot activate QR: $e',
          backgroundColor: const Color(0xFFEF4444),
          colorText: Colors.white,
          snackPosition: SnackPosition.TOP,
          margin: const EdgeInsets.all(16));
    }
  }


  void _showSubmissionsSheet(Exam exam) {
    final isDark = AuthBackground.isDarkMode.value;
    final titleColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
    final cardBgColor = isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white;
    final cardBorderColor = isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.08);
    final user = SessionService.currentUser!;
    String selectedAngkatan = 'Semua';

    Get.bottomSheet(
      StatefulBuilder(
        builder: (context, setModalState) {
          return DefaultTabController(
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
                              AppLocalization.isIndonesian ? 'Hasil Ujian Murid' : 'Student Exam Results',
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
                          stream: StudentService().getStudentsBySchool(user.schoolId),
                          builder: (context, studentSnapshot) {
                            if (studentSnapshot.connectionState == ConnectionState.waiting) {
                              return const Center(child: CircularProgressIndicator());
                            }

                            final allStudentDocs = studentSnapshot.data?.docs ?? [];

                            // Build school-wide studentId -> angkatan mapping
                            final Map<String, String> studentIdToAngkatan = {};
                            for (final doc in allStudentDocs) {
                              final data = doc.data();
                              final ang = (data['angkatan'] ?? '').toString().trim();
                              studentIdToAngkatan[doc.id] = ang.isNotEmpty ? ang : 'Lainnya';
                            }

                            // Only students in this exam's class for "Belum" tab
                            final classStudentDocs = allStudentDocs
                                .where((doc) => doc.data()['classId'] == exam.classId)
                                .toList();

                            // Collect unique angkatan values from submissions + class students
                            final submissionAngkatans = submissions
                                .map((s) => studentIdToAngkatan[s.studentId] ?? 'Lainnya')
                                .toSet();
                            final classAngkatans = classStudentDocs
                                .map((d) {
                                  final a = (d.data()['angkatan'] ?? '').toString().trim();
                                  return a.isNotEmpty ? a : 'Lainnya';
                                })
                                .toSet();
                            final allAngkatans = {...submissionAngkatans, ...classAngkatans};
                            final uniqueAngkatans = ['Semua', ...allAngkatans.toList()..sort()];

                            final Map<String, ExamSubmission> submissionMap = {
                              for (var sub in submissions) sub.studentId: sub
                            };

                            final notSubmittedStudents = classStudentDocs
                                .where((doc) => !submissionMap.containsKey(doc.id))
                                .toList();
                            notSubmittedStudents.sort((a, b) {
                              final nameA = a.data()['nama']?.toString().toLowerCase() ?? '';
                              final nameB = b.data()['nama']?.toString().toLowerCase() ?? '';
                              return nameA.compareTo(nameB);
                            });

                            // Filter lists based on selectedAngkatan
                            final filteredSubmissions = submissions.where((sub) {
                              if (selectedAngkatan == 'Semua') return true;
                              return (studentIdToAngkatan[sub.studentId] ?? 'Lainnya') == selectedAngkatan;
                            }).toList();

                            final filteredNotSubmitted = notSubmittedStudents.where((doc) {
                              if (selectedAngkatan == 'Semua') return true;
                              return (studentIdToAngkatan[doc.id] ?? 'Lainnya') == selectedAngkatan;
                            }).toList();

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Angkatan Filter Chips
                                SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  physics: const BouncingScrollPhysics(),
                                  child: Row(
                                    children: uniqueAngkatans.map((ang) {
                                      final isSelected = selectedAngkatan == ang;
                                      return GestureDetector(
                                        onTap: () {
                                          setModalState(() {
                                            selectedAngkatan = ang;
                                          });
                                        },
                                        child: AnimatedContainer(
                                          duration: const Duration(milliseconds: 200),
                                          margin: const EdgeInsets.only(right: 8.0, bottom: 8.0),
                                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                          decoration: BoxDecoration(
                                            color: isSelected
                                                ? const Color(0xFF8B5CF6).withValues(alpha: 0.15)
                                                : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05)),
                                            borderRadius: BorderRadius.circular(10),
                                            border: Border.all(
                                              color: isSelected
                                                  ? const Color(0xFF8B5CF6)
                                                  : (isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.1)),
                                              width: 1,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              if (isSelected) ...[
                                                const Icon(
                                                  Icons.check,
                                                  size: 14,
                                                  color: Color(0xFF8B5CF6),
                                                ),
                                                const SizedBox(width: 6),
                                              ],
                                              Text(
                                                ang == 'Semua' ? (AppLocalization.isIndonesian ? 'Semua Angkatan' : 'All Cohorts') : (AppLocalization.isIndonesian ? 'Angkatan $ang' : 'Cohort $ang'),
                                                style: TextStyle(
                                                  color: isSelected
                                                      ? const Color(0xFF8B5CF6)
                                                      : (isDark ? Colors.white.withValues(alpha: 0.7) : const Color(0xFF1E1B4B).withValues(alpha: 0.7)),
                                                  fontSize: 12,
                                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                TabBar(
                                  labelColor: const Color(0xFF8B5CF6),
                                  unselectedLabelColor: titleColor.withValues(alpha: 0.6),
                                  indicatorColor: const Color(0xFF8B5CF6),
                                  indicatorSize: TabBarIndicatorSize.tab,
                                  dividerColor: Colors.transparent,
                                  tabs: [
                                    Tab(
                                      child: Text(
                                        '${AppLocalization.isIndonesian ? 'Sudah' : 'Submitted'} (${filteredSubmissions.length})',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                      ),
                                    ),
                                    Tab(
                                      child: Text(
                                        '${AppLocalization.isIndonesian ? 'Belum' : 'Unsubmitted'} (${filteredNotSubmitted.length})',
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
                                      filteredSubmissions.isEmpty
                                          ? Center(
                                              child: Text(
                                                AppLocalization.isIndonesian
                                                    ? 'Belum ada murid yang mengumpulkan ujian.'
                                                    : 'No students have submitted the exam yet.',
                                                style: TextStyle(color: titleColor.withValues(alpha: 0.5), fontSize: 13),
                                                textAlign: TextAlign.center,
                                              ),
                                            )
                                          : ListView.builder(
                                              physics: const BouncingScrollPhysics(),
                                              itemCount: filteredSubmissions.length,
                                              itemBuilder: (context, index) {
                                                final sub = filteredSubmissions[index];
                                                final dateStr = DateFormat('dd MMM yyyy, HH:mm').format(sub.submittedAt);
                                                final hasEssay = exam.questions.any((q) => q.type == 'essay');
                                                final studentAngkatan = studentIdToAngkatan[sub.studentId] ?? 'Lainnya';

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
                                                        Get.back();
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
                                                                    '${AppLocalization.isIndonesian ? 'Angkatan' : 'Cohort'}: $studentAngkatan\n${AppLocalization.isIndonesian ? 'Dikumpulkan' : 'Submitted'}: $dateStr${exam.questions.any((q) => q.type == "multiple_choice") ? "\n${AppLocalization.isIndonesian ? 'Benar PG' : 'MC Correct'}: ${sub.correctCount} | ${AppLocalization.isIndonesian ? 'Salah PG' : 'MC Incorrect'}: ${sub.incorrectCount}" : ""}',
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
                                                                child: Text(
                                                                  AppLocalization.isIndonesian ? 'Perlu Koreksi' : 'Needs Grading',
                                                                  style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 12),
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
                                      filteredNotSubmitted.isEmpty
                                          ? Center(
                                              child: Text(
                                                AppLocalization.isIndonesian
                                                    ? 'Semua murid sudah mengumpulkan ujian.'
                                                    : 'All students have submitted the exam.',
                                                style: TextStyle(color: titleColor.withValues(alpha: 0.5), fontSize: 13),
                                                textAlign: TextAlign.center,
                                              ),
                                            )
                                          : ListView.builder(
                                              physics: const BouncingScrollPhysics(),
                                              itemCount: filteredNotSubmitted.length,
                                              itemBuilder: (context, index) {
                                                final student = filteredNotSubmitted[index].data();
                                                final studentId = filteredNotSubmitted[index].id;
                                                final name = student['nama'] ?? 'Murid';
                                                final nis = student['nis'] ?? '-';
                                                final isSusulan = exam.susulanStudentIds.contains(studentId);
                                                final studentAngkatan = studentIdToAngkatan[studentId] ?? 'Lainnya';

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
                                                                '${AppLocalization.isIndonesian ? 'Angkatan' : 'Cohort'}: $studentAngkatan | NIS: $nis',
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
                                                            child: Text(
                                                              AppLocalization.isIndonesian ? 'Susulan' : 'Makeup',
                                                              style: const TextStyle(color: Color(0xFF8B5CF6), fontWeight: FontWeight.bold, fontSize: 10),
                                                            ),
                                                          )
                                                        else
                                                          Container(
                                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                            decoration: BoxDecoration(
                                                              color: Colors.redAccent.withValues(alpha: 0.15),
                                                              borderRadius: BorderRadius.circular(8),
                                                            ),
                                                            child: Text(
                                                              AppLocalization.isIndonesian ? 'Belum' : 'Not yet',
                                                              style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 10),
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
          );
        },
      ),
      isScrollControlled: true,
    );
  }

  Future<void> _finishSession(String schoolId, ExamSession session) async {
    final isDark = AuthBackground.isDarkMode.value;
    final dialogBg = isDark ? const Color(0xFF1E1B4B) : Colors.white;
    final titleColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
    final subtitleColor = isDark
        ? Colors.white.withValues(alpha: 0.65)
        : const Color(0xFF1E1B4B).withValues(alpha: 0.65);
    final roomName = session.roomName.isNotEmpty ? session.roomName : 'Ujian';
    final expectedPhrase = AppLocalization.isIndonesian
        ? 'selesaikan ruangan $roomName'.toLowerCase()
        : 'finish room $roomName'.toLowerCase();
    final inputController = TextEditingController();
    bool isValid = false;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: dialogBg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            AppLocalization.isIndonesian ? 'Selesaikan Sesi?' : 'Finish Session?',
            style: TextStyle(fontWeight: FontWeight.bold, color: titleColor),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppLocalization.isIndonesian
                    ? 'QR akan dinonaktifkan dan sesi "${session.subjectName}" di ruangan $roomName ditandai selesai. Siswa tidak dapat scan lagi.'
                    : 'QR will be disabled and session "${session.subjectName}" in room $roomName will be marked as finished. Students cannot scan anymore.',
                style: TextStyle(color: subtitleColor, height: 1.5, fontSize: 13),
              ),
              const SizedBox(height: 16),
              SelectableText(
                AppLocalization.isIndonesian
                    ? 'Ketik "selesaikan ruangan $roomName" untuk konfirmasi:'
                    : 'Type "finish room $roomName" to confirm:',
                style: TextStyle(color: subtitleColor, fontSize: 12, fontStyle: FontStyle.italic),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: inputController,
                style: TextStyle(color: titleColor, fontSize: 13),
                decoration: InputDecoration(
                  hintText: AppLocalization.isIndonesian ? 'selesaikan ruangan $roomName' : 'finish room $roomName',
                  hintStyle: TextStyle(color: subtitleColor.withValues(alpha: 0.5), fontSize: 12),
                  filled: true,
                  fillColor: isDark
                      ? Colors.white.withValues(alpha: 0.06)
                      : Colors.black.withValues(alpha: 0.04),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                onChanged: (val) {
                  setDialogState(() {
                    isValid = val.trim().toLowerCase() == expectedPhrase;
                  });
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(AppLocalization.cancel,
                  style: TextStyle(
                      color: titleColor.withValues(alpha: 0.6),
                      fontWeight: FontWeight.w500)),
            ),
            ElevatedButton(
              onPressed: isValid ? () => Navigator.pop(ctx, true) : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444),
                disabledBackgroundColor:
                    const Color(0xFFEF4444).withValues(alpha: 0.3),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(AppLocalization.isIndonesian ? 'Selesaikan' : 'Finish',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );

    inputController.dispose();
    if (confirm == true) {
      await _service.finishSession(
          schoolId: schoolId, sessionId: session.id);
    }
  }
  Future<void> _scanStudentQrForSession(BuildContext context, ExamSession session) async {
    final result = await Get.to<String>(() => StudentQrScannerPage(
          title: AppLocalization.isIndonesian ? 'Scan QR Murid' : 'Scan Student QR',
          subtitle: AppLocalization.isIndonesian
              ? 'Arahkan kamera ke QR di kartu ujian murid'
              : 'Point camera at the QR code on the student\'s exam card',
        ));

    if (result == null || result.isEmpty) return;

    try {
      final decoded = jsonDecode(result);
      if (decoded['type'] != 'exam_attendance') {
        _showErrorDialogGlobal(AppLocalization.isIndonesian
            ? 'Format QR tidak valid untuk presensi ujian!'
            : 'Invalid QR code format for exam attendance!');
        return;
      }

      final studentId = decoded['studentId']?.toString() ?? '';
      final studentName = decoded['studentName']?.toString() ?? 'Murid';

      if (studentId.isEmpty) {
        _showErrorDialogGlobal(AppLocalization.isIndonesian
            ? 'ID Murid tidak ditemukan dalam QR!'
            : 'Student ID not found in the QR code!');
        return;
      }

      // Show loading
      Get.dialog(
        const Center(child: CircularProgressIndicator()),
        barrierDismissible: false,
      );

      final schoolId = SessionService.currentUser!.schoolId;
      await ExamSessionService().recordProctorScanAttendance(
        schoolId: schoolId,
        sessionId: session.id,
        studentId: studentId,
      );

      // Dismiss loading
      Get.back();

      // Show success
      Get.snackbar(
        AppLocalization.isIndonesian ? 'Berhasil' : 'Success',
        AppLocalization.isIndonesian
            ? 'Presensi berhasil dicatat untuk $studentName.'
            : 'Attendance successfully recorded for $studentName.',
        backgroundColor: const Color(0xFF10B981),
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
        margin: const EdgeInsets.all(16),
      );
    } catch (e) {
      // Dismiss loading if active
      if (Get.isDialogOpen ?? false) {
        Get.back();
      }

      String errMsg = e.toString();
      if (errMsg.contains('Exception:')) {
        errMsg = errMsg.substring(errMsg.indexOf('Exception:') + 10);
      }
      _showErrorDialogGlobal(errMsg);
    }
  }

  void _showErrorDialogGlobal(String message) {
    final isDark = AuthBackground.isDarkMode.value;
    final dialogBg = isDark ? const Color(0xFF1E1B4B) : Colors.white;
    final titleColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
    final contentColor = isDark
        ? Colors.white.withValues(alpha: 0.8)
        : const Color(0xFF1E1B4B).withValues(alpha: 0.75);
    Get.dialog(
      AlertDialog(
        backgroundColor: dialogBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: Color(0xFFEF4444)),
            const SizedBox(width: 8),
            Text(AppLocalization.isIndonesian ? 'Presensi Gagal' : 'Attendance Failed',
                style: TextStyle(
                    fontWeight: FontWeight.bold, color: titleColor)),
          ],
        ),
        content: Text(message,
            style: TextStyle(color: contentColor, height: 1.5)),
        actions: [
          ElevatedButton(
            onPressed: () => Get.back(),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8B5CF6),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(
      String title, IconData icon, Color color, bool isDark, Color titleColor) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Text(title,
            style: TextStyle(
                color: titleColor,
                fontSize: 14,
                fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildGradingTab(
    String schoolId,
    bool isDark,
    Color cardColor,
    Color cardBorder,
    Color titleColor,
    Color subtitleColor,
  ) {
    return StreamBuilder<List<Exam>>(
      stream: _examService.getSemesterExamsForTeacher(schoolId, widget.teacherId),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return Center(
              child: CircularProgressIndicator(
                  color: isDark ? Colors.white : const Color(0xFF8B5CF6)));
        }

        final exams = snap.data ?? [];

        if (exams.isEmpty) {
          return _buildEmptyState(
            isDark,
            titleColor,
            subtitleColor,
            Icons.grading_rounded,
            AppLocalization.isIndonesian ? 'Tidak Ada Ujian yang Perlu Dikoreksi' : 'No Exams Need Grading',
            AppLocalization.isIndonesian ? 'Belum ada lembar pengerjaan atau data ujian semester aktif untuk Anda koreksi.' : 'There are no exam submissions or active semester exam data for you to grade.',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
          physics: const BouncingScrollPhysics(),
          itemCount: exams.length,
          itemBuilder: (context, index) {
            final exam = exams[index];
            final dateStr = DateFormat('dd MMM yyyy, HH:mm').format(exam.dueDate);

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: cardBorder),
                boxShadow: [
                  BoxShadow(
                    color: isDark
                        ? Colors.black.withValues(alpha: 0.15)
                        : Colors.black.withValues(alpha: 0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            exam.title,
                            style: TextStyle(
                              color: titleColor,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            exam.gradeCategory,
                            style: const TextStyle(
                              color: Color(0xFF8B5CF6),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${AppLocalization.isIndonesian ? 'Mata Pelajaran' : 'Subject'}: ${exam.subjectName}',
                      style: TextStyle(color: subtitleColor, fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${AppLocalization.isIndonesian ? 'Batas Pengerjaan' : 'Deadline'}: $dateStr',
                      style: TextStyle(color: subtitleColor, fontSize: 11),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
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
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${exam.questions.length} ${AppLocalization.isIndonesian ? 'Soal' : 'Questions'}',
                            style: const TextStyle(
                              color: Color(0xFF10B981),
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ),
                        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                          stream: FirebaseFirestore.instance
                              .collection('schools')
                              .doc(schoolId)
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
                              return Container(
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
                                      '$ungradedCount ${AppLocalization.isIndonesian ? 'Belum Dikoreksi' : 'Ungraded'}',
                                      style: const TextStyle(
                                        color: Colors.amber,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 9,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }
                            return const SizedBox.shrink();
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _showSubmissionsSheet(exam),
                        icon: const Icon(Icons.grading_rounded, size: 14),
                        label: Text(AppLocalization.isIndonesian ? 'Koreksi' : 'Grade'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          textStyle: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
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
  }

  Widget _buildEmptyState(
    bool isDark,
    Color titleColor,
    Color subtitleColor,
    IconData icon,
    String title,
    String subtitle,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.black.withValues(alpha: 0.04),
                shape: BoxShape.circle,
              ),
              child: Icon(icon,
                  size: 36,
                  color: isDark ? Colors.white.withValues(alpha: 0.3) : Colors.black26),
            ),
            const SizedBox(height: 20),
            Text(title,
                style: TextStyle(
                    color: titleColor,
                    fontSize: 18,
                    fontWeight: FontWeight.bold),
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(subtitle,
                style:
                    TextStyle(color: subtitleColor, fontSize: 14, height: 1.5),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  ProctorRoomSeatingPage — Denah Tempat Duduk + Monitor Realtime
// ─────────────────────────────────────────────────────────────
class ProctorRoomSeatingPage extends StatefulWidget {
  final String schoolId;
  final ExamSession session;

  const ProctorRoomSeatingPage({
    super.key,
    required this.schoolId,
    required this.session,
  });

  @override
  State<ProctorRoomSeatingPage> createState() => _ProctorRoomSeatingPageState();
}

class _ProctorRoomSeatingPageState extends State<ProctorRoomSeatingPage> {
  final _behaviorService = ExamBehaviorService();
  int _pairsPerRow = 3;
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _behaviorStream;

  @override
  void initState() {
    super.initState();
    _behaviorStream = _behaviorService.getExamBehaviorStream(
      schoolId: widget.schoolId,
      sessionId: widget.session.id,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: AppLocalization.currentLocale,
      builder: (context, _, __) {
        return ValueListenableBuilder<bool>(
          valueListenable: AuthBackground.isDarkMode,
          builder: (context, isDark, _) {
        final titleColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
        final subtitleColor = isDark
            ? Colors.white.withValues(alpha: 0.6)
            : const Color(0xFF1E1B4B).withValues(alpha: 0.6);
        final scaffoldBg = isDark ? const Color(0xFF0F0C20) : Colors.white;
        final service = ExamSessionService();

        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('schools')
              .doc(widget.schoolId)
              .collection('exam_sessions')
              .doc(widget.session.id)
              .snapshots(),
          builder: (context, sessionSnap) {
            final sessionData = sessionSnap.data?.data();
            final currentStatus = sessionData?['examStatus']?.toString() ?? widget.session.examStatus;
            final isSessionFinished = currentStatus == 'Finished';

            return Scaffold(
              backgroundColor: scaffoldBg,
              appBar: AppBar(
                title: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocalization.isIndonesian ? 'Denah & Monitor Ruang' : 'Seating Plan & Monitor',
                      style: TextStyle(color: titleColor, fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      widget.session.roomName.isNotEmpty ? widget.session.roomName : (AppLocalization.isIndonesian ? 'Ruang Ujian' : 'Exam Room'),
                      style: TextStyle(color: subtitleColor, fontSize: 11),
                    ),
                  ],
                ),
                backgroundColor: scaffoldBg,
                surfaceTintColor: Colors.transparent,
                scrolledUnderElevation: 0,
                elevation: 0,
                leading: IconButton(
                  icon: Icon(Icons.arrow_back_rounded, color: titleColor),
                  onPressed: () => Get.back(),
                ),
                actions: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isDark ? Colors.white.withValues(alpha: 0.10) : Colors.black.withValues(alpha: 0.08),
                        ),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          value: _pairsPerRow,
                          dropdownColor: isDark ? const Color(0xFF15122F) : Colors.white,
                          style: TextStyle(color: titleColor, fontSize: 11, fontWeight: FontWeight.bold),
                          items: [
                            DropdownMenuItem(value: 3, child: Text(AppLocalization.isIndonesian ? '3 Pasang Meja' : '3 Desk Pairs')),
                            DropdownMenuItem(value: 4, child: Text(AppLocalization.isIndonesian ? '4 Pasang Meja' : '4 Desk Pairs')),
                            DropdownMenuItem(value: 5, child: Text(AppLocalization.isIndonesian ? '5 Pasang Meja' : '5 Desk Pairs')),
                          ],
                          onChanged: (val) {
                            if (val != null) setState(() => _pairsPerRow = val);
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              body: AuthBackground(
                child: StreamBuilder<List<ExamParticipation>>(
                  stream: service.getParticipations(
                      schoolId: widget.schoolId, sessionId: widget.session.id),
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final participations = snap.data ?? [];
                    if (participations.isEmpty) {
                      return Center(
                        child: Text(AppLocalization.isIndonesian ? 'Belum ada alokasi kursi untuk sesi ini.' : 'No seat allocation for this session yet.',
                            style: TextStyle(color: subtitleColor)),
                      );
                    }

                    participations.sort((a, b) => a.seatNumber.compareTo(b.seatNumber));

                    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: _behaviorStream,
                      builder: (context, behaviorSnap) {
                        final behaviorDocs = behaviorSnap.data?.docs ?? [];
                        final Map<String, Map<String, dynamic>> behaviorByStudent = {};
                        for (final doc in behaviorDocs) {
                          final data = doc.data();
                          final sid = data['studentId']?.toString() ?? '';
                          if (sid.isNotEmpty) behaviorByStudent[sid] = data;
                        }

                        // Compute stats
                        int cStandby = 0, cKeluar = 0, cScreenOff = 0, cSelesai = 0, cBelum = 0;
                        for (final p in participations) {
                          if (p.submittedAt != null) { cSelesai++; continue; }
                          final b = behaviorByStudent[p.studentId];
                          if (b == null) { cBelum++; continue; }
                          final t = (b['type']?.toString() ?? '').toLowerCase();
                          if (t.contains('keluar')) cKeluar++;
                          else if (t.contains('off') || t.contains('kunci') || t.contains('mati')) cScreenOff++;
                          else cStandby++;
                        }

                        // Angkatan color map
                        final angkatans = participations.map((p) => p.angkatan).toSet().toList()..sort();
                        Color cohortColor(String a) {
                          final i = angkatans.indexOf(a);
                          if (i == 0) return const Color(0xFF8B5CF6);
                          if (i == 1) return const Color(0xFF10B981);
                          if (i == 2) return const Color(0xFFF59E0B);
                          return const Color(0xFF3B82F6);
                        }

                        final maxSeat = participations.fold(0, (m, p) => p.seatNumber > m ? p.seatNumber : m);
                        final colCount = _pairsPerRow * 2;
                        final rowCount = (maxSeat / colCount).ceil();
                        final seatMap = {for (var p in participations) p.seatNumber: p};

                        return Column(
                          children: [
                            // ── Stats Bar ──────────────────────────────────────
                            _buildStatsBar(isDark,
                              total: participations.length,
                              standby: cStandby, keluar: cKeluar,
                              screenOff: cScreenOff, selesai: cSelesai, belum: cBelum,
                            ),

                            // ── Board Banner ───────────────────────────────────
                            Container(
                              margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isDark ? Colors.white.withValues(alpha: 0.10) : Colors.black.withValues(alpha: 0.10),
                                ),
                              ),
                              child: Center(
                                child: Text(AppLocalization.isIndonesian ? 'PAPAN TULIS / MEJA PENGAWAS' : 'WHITEBOARD / PROCTOR DESK',
                                  style: TextStyle(color: subtitleColor, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 2)),
                              ),
                            ),

                            // ── Legend ─────────────────────────────────────────
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                              child: Wrap(spacing: 10, runSpacing: 4, children: [
                                ...angkatans.map((a) => _legendItem(cohortColor(a), AppLocalization.isIndonesian ? 'Angkatan $a' : 'Cohort $a', subtitleColor)),
                                _legendItem(Colors.green, 'Standby', subtitleColor),
                                _legendItem(Colors.redAccent, AppLocalization.isIndonesian ? 'Keluar' : 'Exit', subtitleColor),
                                _legendItem(Colors.orange, 'Screen Off', subtitleColor),
                                _legendItem(Colors.cyan, AppLocalization.isIndonesian ? 'Selesai' : 'Finished', subtitleColor),
                              ]),
                            ),

                            // ── Seating Grid ───────────────────────────────────
                            Expanded(
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  final availableWidth = constraints.maxWidth - 24; // 12px padding each side
                                  final aisleCount = _pairsPerRow - 1;
                                  final totalAisleWidth = aisleCount * 14.0;

                                  const double minCardWidth = 60.0;
                                  final calculatedWidth = (availableWidth - totalAisleWidth) / colCount;
                                  final cardWidth = calculatedWidth < minCardWidth ? minCardWidth : calculatedWidth.clamp(60.0, 80.0);
                                  final cardHeight = (cardWidth * 1.15).clamp(65.0, 95.0);

                                  return SingleChildScrollView(
                                    scrollDirection: Axis.vertical,
                                    padding: const EdgeInsets.fromLTRB(0, 8, 0, 80),
                                    child: SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 12),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.center,
                                          children: List.generate(rowCount, (rIdx) {
                                            return Padding(
                                              padding: const EdgeInsets.only(bottom: 8),
                                              child: Row(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: List.generate(colCount, (cIdx) {
                                                  final seatNum = rIdx * colCount + cIdx + 1;
                                                  final student = seatMap[seatNum];
                                                  final behavior = student != null ? behaviorByStudent[student.studentId] : null;
                                                  final cc = student != null ? cohortColor(student.angkatan) : Colors.grey;

                                                  final card = _buildSeatCard(
                                                    isDark: isDark,
                                                    seatNum: seatNum,
                                                    student: student,
                                                    behavior: behavior,
                                                    cohortColor: cc,
                                                    subtitleColor: subtitleColor,
                                                    cardWidth: cardWidth,
                                                    cardHeight: cardHeight,
                                                    isFinished: isSessionFinished,
                                                  );

                                                  // Insert aisle gap after every pair (every 2 seats)
                                                  final isAfterPair = (cIdx % 2 == 1) && (cIdx < colCount - 1);
                                                  if (isAfterPair) {
                                                    return Row(mainAxisSize: MainAxisSize.min, children: [
                                                      card,
                                                      const SizedBox(width: 14),
                                                    ]);
                                                  }
                                                  return card;
                                                }),
                                              ),
                                            );
                                          }),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),
              ),
              floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
              floatingActionButton: isSessionFinished
                  ? null
                  : FloatingActionButton.extended(
                      onPressed: () => _scanStudentQr(context),
                      backgroundColor: const Color(0xFF8B5CF6),
                      foregroundColor: Colors.white,
                      icon: const Icon(Icons.qr_code_scanner_rounded),
                      label: Text(AppLocalization.isIndonesian ? 'Scan QR Murid' : 'Scan Student QR', style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
            );
          },
        );
      },
    );
      },
    );
  }

  // ── Helpers ──────────────────────────────────────────────────

  Widget _buildStatsBar(bool isDark, {
    required int total, required int standby, required int keluar,
    required int screenOff, required int selesai, required int belum,
  }) {
    final bg = isDark ? Colors.white.withValues(alpha: 0.06) : Colors.white;
    final border = isDark ? Colors.white.withValues(alpha: 0.10) : Colors.black.withValues(alpha: 0.08);
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14), border: Border.all(color: border)),
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        alignment: WrapAlignment.spaceAround,
        children: [
          _statChip(AppLocalization.isIndonesian ? 'Total' : 'Total', total, Colors.blueAccent),
          _statChip(AppLocalization.isIndonesian ? 'Standby' : 'Standby', standby, Colors.green),
          _statChip(AppLocalization.isIndonesian ? 'Keluar' : 'Exit', keluar, Colors.redAccent),
          _statChip(AppLocalization.isIndonesian ? 'Screen Off' : 'Screen Off', screenOff, Colors.orange),
          _statChip(AppLocalization.isIndonesian ? 'Selesai' : 'Finished', selesai, Colors.cyan),
          _statChip(AppLocalization.isIndonesian ? 'Belum' : 'Not yet', belum, Colors.grey),
        ],
      ),
    );
  }

  Widget _statChip(String label, int value, Color color) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(value.toString(), style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color)),
      const SizedBox(height: 1),
      Text(label, style: const TextStyle(fontSize: 8, color: Colors.grey, fontWeight: FontWeight.w600)),
    ],
  );

  Widget _legendItem(Color color, String label, Color textColor) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 4),
      Text(label, style: TextStyle(color: textColor, fontSize: 10)),
    ],
  );

  Widget _buildSeatCard({
    required bool isDark,
    required int seatNum,
    required ExamParticipation? student,
    required Map<String, dynamic>? behavior,
    required Color cohortColor,
    required Color subtitleColor,
    double cardWidth = 68,
    double cardHeight = 78,
    bool isFinished = false,
  }) {
    // Empty slot
    if (student == null) {
      return Container(
        width: cardWidth, height: cardHeight, margin: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04)),
        ),
        child: Center(child: Text('#$seatNum\n${AppLocalization.isIndonesian ? '(Kosong)' : '(Empty)'}',
          textAlign: TextAlign.center,
          style: TextStyle(color: subtitleColor.withValues(alpha: 0.25), fontSize: 7.5))),
      );
    }

    // Determine status
    final isSubmitted = student.submittedAt != null;
    final isScanned   = student.scannedAt != null;

    Color statusColor;
    String statusLabel;
    IconData statusIcon;

    if (isSubmitted) {
      statusColor = Colors.cyan;
      statusLabel = AppLocalization.isIndonesian ? 'Selesai' : 'Finished';
      statusIcon  = Icons.task_alt_rounded;
    } else if (behavior != null) {
      final t = (behavior['type']?.toString() ?? '').toLowerCase();
      if (t.contains('keluar')) {
        statusColor = Colors.redAccent; statusLabel = AppLocalization.isIndonesian ? 'Keluar' : 'Exit'; statusIcon = Icons.exit_to_app_rounded;
      } else if (t.contains('off') || t.contains('kunci') || t.contains('mati')) {
        statusColor = Colors.orange; statusLabel = AppLocalization.isIndonesian ? 'Screen Off' : 'Screen Off'; statusIcon = Icons.screen_lock_portrait_rounded;
      } else {
        statusColor = Colors.green; statusLabel = AppLocalization.isIndonesian ? 'Standby' : 'Standby'; statusIcon = Icons.play_arrow_rounded;
      }
    } else if (isScanned) {
      statusColor = cohortColor; statusLabel = AppLocalization.isIndonesian ? 'Hadir' : 'Present'; statusIcon = Icons.check_circle_rounded;
    } else {
      statusColor = cohortColor; statusLabel = AppLocalization.isIndonesian ? 'Belum' : 'Not yet'; statusIcon = Icons.radio_button_unchecked_rounded;
    }

    final isBelum = !isScanned && !isSubmitted && behavior == null;

    final cardBgColor = isBelum
        ? (isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.02))
        : statusColor;

    final cardBorderColor = isBelum
        ? statusColor.withValues(alpha: 0.35)
        : statusColor;

    final textColor = isBelum
        ? (isDark ? Colors.white.withValues(alpha: 0.4) : const Color(0xFF1E1B4B).withValues(alpha: 0.4))
        : Colors.white;

    final seatNumColor = isBelum
        ? statusColor.withValues(alpha: 0.6)
        : Colors.white.withValues(alpha: 0.9);

    final iconColor = isBelum
        ? statusColor.withValues(alpha: 0.5)
        : Colors.white;

    final badgeBgColor = isBelum
        ? statusColor.withValues(alpha: 0.1)
        : Colors.white.withValues(alpha: 0.25);

    final badgeTextColor = isBelum
        ? statusColor
        : Colors.white;

    // Short name
    final parts = student.studentName.split(' ');
    final shortName = parts.length > 1 ? '${parts[0]} ${parts[1][0]}.' : student.studentName;

    return GestureDetector(
      onTap: () => _showStudentLog(student, behavior, isDark, subtitleColor, isFinished: isFinished),
      child: Container(
        width: cardWidth, height: cardHeight, margin: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: cardBgColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: cardBorderColor, width: 1.5),
          boxShadow: isBelum
              ? null
              : [BoxShadow(color: statusColor.withValues(alpha: 0.2), blurRadius: 4, offset: const Offset(0, 2))],
        ),
        padding: const EdgeInsets.all(5),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('#$seatNum', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: seatNumColor)),
              Icon(statusIcon, size: 9, color: iconColor),
            ]),
            Text(shortName, maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center,
              style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: textColor)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
              decoration: BoxDecoration(color: badgeBgColor, borderRadius: BorderRadius.circular(4)),
              child: Text(statusLabel, style: TextStyle(fontSize: 7, fontWeight: FontWeight.bold, color: badgeTextColor)),
            ),
          ],
        ),
      ),
    );
  }

  void _showStudentLog(ExamParticipation student, Map<String, dynamic>? behavior, bool isDark, Color subTextColor, {bool isFinished = false}) {
    final titleColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
    final activityLog = behavior?['activityLog'] as List<dynamic>? ?? [];
    final sortedLog = List<dynamic>.from(activityLog)
      ..sort((a, b) {
        final dA = a['timestamp'] is Timestamp ? (a['timestamp'] as Timestamp).toDate() : DateTime(0);
        final dB = b['timestamp'] is Timestamp ? (b['timestamp'] as Timestamp).toDate() : DateTime(0);
        return dB.compareTo(dA);
      });

    Get.bottomSheet(
      StatefulBuilder(
        builder: (ctx, setSheetState) {
          bool isCancelling = false;
          bool isAbsenting = false;

          return Container(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.65),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF100C22) : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle
                Center(child: Container(width: 40, height: 4,
                  decoration: BoxDecoration(color: subTextColor.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 16),
                // Student header
                Row(children: [
                  CircleAvatar(
                    backgroundColor: const Color(0xFF8B5CF6),
                    radius: 20,
                    child: Text(student.seatNumber.toString(),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(student.studentName, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: titleColor)),
                    Text('${AppLocalization.isIndonesian ? 'Bangku' : 'Desk'} #${student.seatNumber} • NIS: ${student.nis}', style: TextStyle(fontSize: 11, color: subTextColor)),
                  ])),
                  if (student.submittedAt != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.cyan.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.cyan.withValues(alpha: 0.3)),
                      ),
                      child: Text('✓ ${AppLocalization.isIndonesian ? 'Selesai' : 'Finished'}', style: const TextStyle(color: Colors.cyan, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                ]),
                if (student.submittedAt == null && !isFinished) ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: student.scannedAt != null
                            ? OutlinedButton.icon(
                                onPressed: (isCancelling || isAbsenting)
                                    ? null
                                    : () async {
                                        setSheetState(() => isCancelling = true);
                                        try {
                                          await ExamSessionService().cancelProctorScanAttendance(
                                            schoolId: widget.schoolId,
                                            sessionId: widget.session.id,
                                            studentId: student.studentId,
                                          );
                                          Get.back();
                                          Get.snackbar(
                                            AppLocalization.isIndonesian ? 'Sukses' : 'Success',
                                            AppLocalization.isIndonesian ? 'Kehadiran manual dibatalkan.' : 'Manual presence cancelled.',
                                            backgroundColor: Colors.amber, colorText: Colors.white);
                                        } catch (e) {
                                          setSheetState(() => isCancelling = false);
                                          Get.snackbar(
                                            AppLocalization.isIndonesian ? 'Error' : 'Error',
                                            e.toString(),
                                            backgroundColor: Colors.redAccent, colorText: Colors.white);
                                        }
                                      },
                                icon: isCancelling
                                    ? const SizedBox(width: 14, height: 14,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.orange))
                                    : const Icon(Icons.close_rounded, size: 16, color: Colors.orange),
                                label: Text(
                                  isCancelling
                                      ? (AppLocalization.isIndonesian ? 'Memproses...' : 'Processing...')
                                      : (AppLocalization.isIndonesian ? 'Batalkan Kehadiran' : 'Cancel Attendance'),
                                  style: const TextStyle(color: Colors.orange)),
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: Colors.orange),
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                              )
                            : ElevatedButton.icon(
                                onPressed: (isCancelling || isAbsenting)
                                    ? null
                                    : () async {
                                        setSheetState(() => isAbsenting = true);
                                        try {
                                          await ExamSessionService().recordProctorScanAttendance(
                                            schoolId: widget.schoolId,
                                            sessionId: widget.session.id,
                                            studentId: student.studentId,
                                          );
                                          Get.back();
                                          Get.snackbar(
                                            AppLocalization.isIndonesian ? 'Sukses' : 'Success',
                                            AppLocalization.isIndonesian ? 'Murid berhasil diabsen manual.' : 'Student successfully marked present manually.',
                                            backgroundColor: Colors.green, colorText: Colors.white);
                                        } catch (e) {
                                          setSheetState(() => isAbsenting = false);
                                          Get.snackbar(
                                            AppLocalization.isIndonesian ? 'Error' : 'Error',
                                            e.toString(),
                                            backgroundColor: Colors.redAccent, colorText: Colors.white);
                                        }
                                      },
                                icon: isAbsenting
                                    ? const SizedBox(width: 14, height: 14,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                    : const Icon(Icons.check_circle_outline_rounded, size: 16),
                                label: Text(
                                  isAbsenting
                                      ? (AppLocalization.isIndonesian ? 'Memproses...' : 'Processing...')
                                      : (AppLocalization.isIndonesian ? 'Absen Manual (Tandai Hadir)' : 'Manual Presence (Mark Present)')),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF8B5CF6),
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                              ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 20),
                Text(AppLocalization.isIndonesian ? 'Riwayat Log Aktivitas' : 'Activity Log History', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: titleColor)),
                const Divider(height: 16),
                if (activityLog.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Center(child: Text(
                      student.submittedAt != null
                          ? (AppLocalization.isIndonesian ? 'Murid telah menyelesaikan dan mengumpulkan ujian.' : 'Student has completed and submitted the exam.')
                          : (AppLocalization.isIndonesian ? 'Belum ada aktivitas (murid belum mulai mengerjakan ujian).' : 'No activity yet (student has not started the exam).'),
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: subTextColor))),
                  )
                else
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      physics: const BouncingScrollPhysics(),
                      itemCount: sortedLog.length,
                      itemBuilder: (_, idx) {
                        final log = sortedLog[idx] as Map<String, dynamic>;
                        final logType = log['type']?.toString() ?? '';
                        final logDesc = log['description']?.toString() ?? '-';
                        final ts = log['timestamp'];
                        final logTime = ts is Timestamp ? ts.toDate() : null;

                        Color lc = Colors.grey;
                        if (logType.toLowerCase().contains('standby')) lc = Colors.green;
                        else if (logType.toLowerCase().contains('keluar')) lc = Colors.redAccent;
                        else if (logType.toLowerCase().contains('off') || logType.toLowerCase().contains('kunci')) lc = Colors.orange;

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 5),
                          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            SizedBox(width: 58, child: Text(
                              logTime != null ? DateFormat('HH:mm:ss').format(logTime) : '--:--:--',
                              style: const TextStyle(fontFamily: 'monospace', fontSize: 10, color: Colors.grey))),
                            Container(margin: const EdgeInsets.only(top: 4), width: 7, height: 7,
                              decoration: BoxDecoration(color: lc, shape: BoxShape.circle)),
                            const SizedBox(width: 10),
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(logType, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: lc)),
                              Text(logDesc, style: TextStyle(fontSize: 10, color: subTextColor)),
                            ])),
                          ]),
                        );
                      },
                    ),
                  ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () => Get.back(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.05),
                    foregroundColor: titleColor, elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(AppLocalization.isIndonesian ? 'Tutup' : 'Close', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                ),
              ],
            ),
          );
        },
      ),
      isScrollControlled: true,
    );
  }

  Future<void> _scanStudentQr(BuildContext context) async {
    final result = await Get.to<String>(() => const StudentQrScannerPage(
          title: 'Scan QR Murid',
          subtitle: 'Arahkan kamera ke QR di kartu ujian murid',
        ));

    if (result == null || result.isEmpty) return;

    try {
      final decoded = jsonDecode(result);
      if (decoded['type'] != 'exam_attendance') {
        _showErrorDialog('Format QR tidak valid untuk presensi ujian!');
        return;
      }

      final studentId = decoded['studentId']?.toString() ?? '';
      final studentName = decoded['studentName']?.toString() ?? 'Murid';

      if (studentId.isEmpty) {
        _showErrorDialog('ID Murid tidak ditemukan dalam QR!');
        return;
      }

      Get.dialog(const Center(child: CircularProgressIndicator()), barrierDismissible: false);

      await ExamSessionService().recordProctorScanAttendance(
        schoolId: widget.schoolId,
        sessionId: widget.session.id,
        studentId: studentId,
      );

      Get.back();
      Get.snackbar(
        'Berhasil', 'Presensi berhasil dicatat untuk $studentName.',
        backgroundColor: const Color(0xFF10B981), colorText: Colors.white,
        snackPosition: SnackPosition.TOP, margin: const EdgeInsets.all(16),
      );
    } catch (e) {
      if (Get.isDialogOpen ?? false) Get.back();
      String errMsg = e.toString();
      if (errMsg.contains('Exception:')) errMsg = errMsg.substring(errMsg.indexOf('Exception:') + 10);
      _showErrorDialog(errMsg);
    }
  }

  void _showErrorDialog(String message) {
    final isDark = AuthBackground.isDarkMode.value;
    final dialogBg = isDark ? const Color(0xFF1E1B4B) : Colors.white;
    final titleColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
    final contentColor = isDark ? Colors.white.withValues(alpha: 0.8) : const Color(0xFF1E1B4B).withValues(alpha: 0.75);
    Get.dialog(AlertDialog(
      backgroundColor: dialogBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(children: [
        const Icon(Icons.error_outline_rounded, color: Color(0xFFEF4444)),
        const SizedBox(width: 8),
        Text('Presensi Gagal', style: TextStyle(fontWeight: FontWeight.bold, color: titleColor)),
      ]),
      content: Text(message, style: TextStyle(color: contentColor, height: 1.5)),
      actions: [
        ElevatedButton(
          onPressed: () => Get.back(),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF8B5CF6), foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text('OK'),
        ),
      ],
    ));
  }
}

String _getGradeLevel(String className) {
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
