import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../../core/services/session_service.dart';
import '../../authentication/widgets/auth_background.dart';
import '../../students/pages/student_qr_scanner_page.dart';
import '../models/exam_event_model.dart';
import '../services/exam_session_service.dart';
import '../services/exam_behavior_service.dart';
import 'teacher_exam_questions_page.dart';

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
    extends State<TeacherProctorDashboardPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _service = ExamSessionService();

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

  @override
  Widget build(BuildContext context) {
    final schoolId = SessionService.currentUser!.schoolId;

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

        return Scaffold(
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
                          'Ujian Semester',
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
                      controller: _tabController,
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
                      tabs: const [
                        Tab(
                          icon: Icon(Icons.supervisor_account_rounded, size: 18),
                          text: 'Pengawas',
                          iconMargin: EdgeInsets.only(bottom: 2),
                        ),
                        Tab(
                          icon: Icon(Icons.edit_document, size: 18),
                          text: 'Pembuat Soal',
                          iconMargin: EdgeInsets.only(bottom: 2),
                        ),
                      ],
                    ),
                  ),
                ),

                // Tab Content
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      // Tab 1: Pengawas
                      _buildProctorTab(
                          schoolId, isDark, cardColor, cardBorder,
                          titleColor, subtitleColor),

                      // Tab 2: Pembuat Soal
                      _buildAuthorTab(
                          schoolId, isDark, cardColor, cardBorder,
                          titleColor, subtitleColor),
                    ],
                  ),
                ),
              ],
            ),
          ),
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
            'Tidak Ada Tugas Mengawas',
            'Anda belum ditugaskan sebagai pengawas ujian.',
          );
        }

        return ListView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
          children: [
            if (upcoming.isNotEmpty) ...[
              _buildSectionHeader('Jadwal Mendatang', Icons.upcoming_rounded,
                  const Color(0xFF8B5CF6), isDark, titleColor),
              const SizedBox(height: 10),
              ...upcoming.map((s) => _buildProctorSessionCard(
                  s, isDark, cardColor, cardBorder, titleColor, subtitleColor,
                  schoolId,
                  effectiveStatus: computeEffectiveStatus(s))),
            ],
            if (past.isNotEmpty) ...[
              const SizedBox(height: 20),
              _buildSectionHeader('Selesai', Icons.history_rounded,
                  const Color(0xFF64748B), isDark, titleColor),
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
                    _buildStatusBadge(resolvedStatus, isToday: isToday),
                    const SizedBox(width: 8),
                    if (isToday && !isFinished)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text('Hari Ini',
                            style: TextStyle(
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
                  '${DateFormat('EEEE, dd MMMM yyyy', 'id').format(session.date)} • ${session.startTime}–${session.endTime}',
                  style: TextStyle(color: subtitleColor, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text('Kelas: ${session.className.isEmpty ? session.classId : session.className}',
                    style: TextStyle(color: subtitleColor, fontSize: 12)),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => Get.to(() => ProctorRoomSeatingPage(
                        schoolId: schoolId,
                        session: session,
                      )),
                  icon: const Icon(Icons.grid_on_rounded, size: 16, color: Color(0xFF8B5CF6)),
                  label: const Text('Denah Tempat Duduk',
                      style: TextStyle(color: Color(0xFF8B5CF6))),
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
                if (!isFinished) ...[
                  const SizedBox(height: 14),
                  // Action Buttons
                  Row(
                    children: [
                      // Future session — show info chip only
                      if (!isToday)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF64748B).withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: const Color(0xFF64748B).withValues(alpha: 0.2),
                            ),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.event_rounded,
                                  size: 14, color: Color(0xFF64748B)),
                              SizedBox(width: 6),
                              Text('Scan QR hanya bisa dilakukan pada hari H',
                                  style: TextStyle(
                                    color: Color(0xFF64748B),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  )),
                            ],
                          ),
                        ),
                      if (isToday) ...[
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              if (!isActive) {
                                // Aktifkan secara otomatis di background
                                try {
                                  await _service.activateSessionQr(
                                      schoolId: schoolId, sessionId: session.id);
                                } catch (_) {}
                              }
                              if (context.mounted) {
                                _scanStudentQrForSession(context, session.copyWith(isQrActive: true));
                              }
                            },
                            icon: const Icon(Icons.qr_code_scanner_rounded, size: 16),
                            label: const Text('Scan QR Murid'),
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
                        if (isActive) ...[
                          const SizedBox(width: 10),
                          OutlinedButton.icon(
                            onPressed: () => _finishSession(schoolId, session),
                            icon: const Icon(Icons.stop_circle_rounded,
                                color: Color(0xFFEF4444), size: 16),
                            label: const Text('Selesai',
                                style: TextStyle(color: Color(0xFFEF4444))),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(
                                  color: Color(0xFFEF4444), width: 1),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 10),
                            ),
                          ),
                        ],
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status, {bool isToday = false}) {
    Color color;
    String label;
    IconData icon;
    switch (status) {
      case 'Active':
        color = const Color(0xFF10B981);
        label = 'Sedang Berlangsung';
        icon = Icons.play_circle_rounded;
        break;
      case 'Finished':
        color = const Color(0xFF64748B);
        label = 'Selesai';
        icon = Icons.check_circle_rounded;
        break;
      default:
        if (isToday) {
          color = const Color(0xFF8B5CF6);
          label = 'Hari Ini';
          icon = Icons.today_rounded;
        } else {
          color = const Color(0xFFF59E0B);
          label = 'Terjadwal';
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

        // Grup unique per subjectId
        final Map<String, ExamSession> uniqueSubjects = {};
        for (final s in sessions) {
          uniqueSubjects.putIfAbsent(s.subjectId, () => s);
        }
        final subjects = uniqueSubjects.values.toList();

        if (subjects.isEmpty) {
          return _buildEmptyState(
            isDark,
            titleColor,
            subtitleColor,
            Icons.edit_document,
            'Tidak Ada Penugasan Soal',
            'Anda belum ditugaskan sebagai pembuat soal untuk event ujian apapun.',
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
                      'Anda adalah pembuat soal untuk mata pelajaran berikut. Siapkan dan upload bank soal sebelum pelaksanaan ujian.',
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
                    .where((s) => s.subjectId == session.subjectId)
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
    return GestureDetector(
      onTap: () => Get.to(() => TeacherExamQuestionsPage(
            eventId: session.eventId,
            subjectId: session.subjectId,
            subjectName: session.subjectName,
            teacherId: widget.teacherId,
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
                  Text('$sessionCount kelas menggunakan soal ini',
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
              child: const Text('Author',
                  style: TextStyle(
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
        Get.snackbar('Berhasil', 'QR Presensi Ujian berhasil diaktifkan.',
            backgroundColor: const Color(0xFF10B981),
            colorText: Colors.white,
            snackPosition: SnackPosition.TOP,
            margin: const EdgeInsets.all(16));
        _scanStudentQrForSession(context, session.copyWith(isQrActive: true));
      }
    } catch (e) {
      Get.snackbar('Gagal', 'Tidak dapat mengaktifkan QR: $e',
          backgroundColor: const Color(0xFFEF4444),
          colorText: Colors.white,
          snackPosition: SnackPosition.TOP,
          margin: const EdgeInsets.all(16));
    }
  }

  Future<void> _finishSession(String schoolId, ExamSession session) async {
    final isDark = AuthBackground.isDarkMode.value;
    final dialogBg = isDark ? const Color(0xFF1E1B4B) : Colors.white;
    final titleColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
    final contentColor = isDark
        ? Colors.white.withValues(alpha: 0.8)
        : const Color(0xFF1E1B4B).withValues(alpha: 0.75);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: dialogBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.stop_circle_rounded,
                color: Color(0xFFEF4444), size: 22),
            const SizedBox(width: 8),
            Text('Selesaikan Sesi?',
                style: TextStyle(
                    fontWeight: FontWeight.bold, color: titleColor)),
          ],
        ),
        content: Text(
          'QR akan dinonaktifkan dan sesi ditandai selesai. Siswa tidak dapat scan lagi.',
          style: TextStyle(color: contentColor, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Batal',
                style: TextStyle(
                    color: titleColor.withValues(alpha: 0.6),
                    fontWeight: FontWeight.w500)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Selesaikan',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _service.finishSession(
          schoolId: schoolId, sessionId: session.id);
    }
  }
  Future<void> _scanStudentQrForSession(BuildContext context, ExamSession session) async {
    final result = await Get.to<String>(() => const StudentQrScannerPage(
          title: 'Scan QR Murid',
          subtitle: 'Arahkan kamera ke QR di kartu ujian murid',
        ));

    if (result == null || result.isEmpty) return;

    try {
      final decoded = jsonDecode(result);
      if (decoded['type'] != 'exam_attendance') {
        _showErrorDialogGlobal('Format QR tidak valid untuk presensi ujian!');
        return;
      }

      final studentId = decoded['studentId']?.toString() ?? '';
      final studentName = decoded['studentName']?.toString() ?? 'Murid';

      if (studentId.isEmpty) {
        _showErrorDialogGlobal('ID Murid tidak ditemukan dalam QR!');
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
        'Berhasil',
        'Presensi berhasil dicatat untuk $studentName.',
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
            Text('Presensi Gagal',
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
    return ValueListenableBuilder<bool>(
      valueListenable: AuthBackground.isDarkMode,
      builder: (context, isDark, _) {
        final titleColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
        final subtitleColor = isDark
            ? Colors.white.withValues(alpha: 0.6)
            : const Color(0xFF1E1B4B).withValues(alpha: 0.6);
        final scaffoldBg = isDark ? const Color(0xFF0F0C20) : Colors.white;
        final service = ExamSessionService();

        return Scaffold(
          backgroundColor: scaffoldBg,
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Denah & Monitor Ruang',
                  style: TextStyle(color: titleColor, fontSize: 15, fontWeight: FontWeight.bold),
                ),
                Text(
                  widget.session.roomName.isNotEmpty ? widget.session.roomName : 'Ruang Ujian',
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
                      items: const [
                        DropdownMenuItem(value: 3, child: Text('3 Pasang Meja')),
                        DropdownMenuItem(value: 4, child: Text('4 Pasang Meja')),
                        DropdownMenuItem(value: 5, child: Text('5 Pasang Meja')),
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
                    child: Text('Belum ada alokasi kursi untuk sesi ini.',
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
                            child: Text('PAPAN TULIS / MEJA PENGAWAS',
                              style: TextStyle(color: subtitleColor, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 2)),
                          ),
                        ),

                        // ── Legend ─────────────────────────────────────────
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                          child: Wrap(spacing: 10, runSpacing: 4, children: [
                            ...angkatans.map((a) => _legendItem(cohortColor(a), 'Angkatan $a', subtitleColor)),
                            _legendItem(Colors.green, 'Standby', subtitleColor),
                            _legendItem(Colors.redAccent, 'Keluar', subtitleColor),
                            _legendItem(Colors.orange, 'Screen Off', subtitleColor),
                            _legendItem(Colors.cyan, 'Selesai', subtitleColor),
                          ]),
                        ),

                        // ── Seating Grid ───────────────────────────────────
                        Expanded(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(12, 8, 12, 80),
                            child: Column(
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
                      ],
                    );
                  },
                );
              },
            ),
          ),
          floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _scanStudentQr(context),
            backgroundColor: const Color(0xFF8B5CF6),
            foregroundColor: Colors.white,
            icon: const Icon(Icons.qr_code_scanner_rounded),
            label: const Text('Scan QR Murid', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
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
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _statChip('Total', total, Colors.blueAccent),
          _statChip('Standby', standby, Colors.green),
          _statChip('Keluar', keluar, Colors.redAccent),
          _statChip('Screen Off', screenOff, Colors.orange),
          _statChip('Selesai', selesai, Colors.cyan),
          _statChip('Belum', belum, Colors.grey),
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
  }) {
    // Empty slot
    if (student == null) {
      return Container(
        width: 68, height: 78, margin: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04)),
        ),
        child: Center(child: Text('#$seatNum\n(Kosong)',
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
      statusLabel = 'Selesai';
      statusIcon  = Icons.task_alt_rounded;
    } else if (behavior != null) {
      final t = (behavior['type']?.toString() ?? '').toLowerCase();
      if (t.contains('keluar')) {
        statusColor = Colors.redAccent; statusLabel = 'Keluar'; statusIcon = Icons.exit_to_app_rounded;
      } else if (t.contains('off') || t.contains('kunci') || t.contains('mati')) {
        statusColor = Colors.orange; statusLabel = 'Screen Off'; statusIcon = Icons.screen_lock_portrait_rounded;
      } else {
        statusColor = Colors.green; statusLabel = 'Standby'; statusIcon = Icons.play_arrow_rounded;
      }
    } else if (isScanned) {
      statusColor = cohortColor; statusLabel = 'Hadir'; statusIcon = Icons.check_circle_rounded;
    } else {
      statusColor = cohortColor.withValues(alpha: 0.35); statusLabel = 'Belum'; statusIcon = Icons.radio_button_unchecked_rounded;
    }

    // Short name
    final parts = student.studentName.split(' ');
    final shortName = parts.length > 1 ? '${parts[0]} ${parts[1][0]}.' : student.studentName;

    return GestureDetector(
      onTap: () => _showStudentLog(student, behavior, isDark, subtitleColor),
      child: Container(
        width: 68, height: 78, margin: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: statusColor.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: statusColor.withValues(alpha: 0.35), width: 1.5),
          boxShadow: [BoxShadow(color: statusColor.withValues(alpha: 0.07), blurRadius: 4, offset: const Offset(0, 2))],
        ),
        padding: const EdgeInsets.all(5),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('#$seatNum', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: statusColor)),
              Icon(statusIcon, size: 9, color: statusColor),
            ]),
            Text(shortName, maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center,
              style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF1E1B4B))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
              decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)),
              child: Text(statusLabel, style: TextStyle(fontSize: 7, fontWeight: FontWeight.bold, color: statusColor)),
            ),
          ],
        ),
      ),
    );
  }

  void _showStudentLog(ExamParticipation student, Map<String, dynamic>? behavior, bool isDark, Color subTextColor) {
    final titleColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
    final activityLog = behavior?['activityLog'] as List<dynamic>? ?? [];
    final sortedLog = List<dynamic>.from(activityLog)
      ..sort((a, b) {
        final dA = a['timestamp'] is Timestamp ? (a['timestamp'] as Timestamp).toDate() : DateTime(0);
        final dB = b['timestamp'] is Timestamp ? (b['timestamp'] as Timestamp).toDate() : DateTime(0);
        return dB.compareTo(dA);
      });

    Get.bottomSheet(
      Container(
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
                Text('Bangku #${student.seatNumber} • NIS: ${student.nis}', style: TextStyle(fontSize: 11, color: subTextColor)),
              ])),
              if (student.submittedAt != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.cyan.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.cyan.withValues(alpha: 0.3)),
                  ),
                  child: const Text('✓ Selesai', style: TextStyle(color: Colors.cyan, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
            ]),
            if (student.submittedAt == null) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: student.scannedAt != null
                        ? OutlinedButton.icon(
                            onPressed: () async {
                              Get.back(); // close bottom sheet
                              Get.dialog(
                                const Center(child: CircularProgressIndicator(color: Color(0xFF8B5CF6))),
                                barrierDismissible: false,
                              );
                              try {
                                final service = ExamSessionService();
                                await service.cancelProctorScanAttendance(
                                  schoolId: widget.schoolId,
                                  sessionId: widget.session.id,
                                  studentId: student.studentId,
                                );
                                Get.back(); // close progress
                                Get.snackbar(
                                  'Sukses',
                                  'Kehadiran manual dibatalkan.',
                                  backgroundColor: Colors.amber,
                                  colorText: Colors.white,
                                );
                              } catch (e) {
                                Get.back(); // close progress
                                Get.snackbar(
                                  'Error',
                                  e.toString(),
                                  backgroundColor: Colors.redAccent,
                                  colorText: Colors.white,
                                );
                              }
                            },
                            icon: const Icon(Icons.close_rounded, size: 16, color: Colors.orange),
                            label: const Text('Batalkan Kehadiran', style: TextStyle(color: Colors.orange)),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.orange),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          )
                        : ElevatedButton.icon(
                            onPressed: () async {
                              Get.back(); // close bottom sheet
                              Get.dialog(
                                const Center(child: CircularProgressIndicator(color: Color(0xFF8B5CF6))),
                                barrierDismissible: false,
                              );
                              try {
                                final service = ExamSessionService();
                                await service.recordProctorScanAttendance(
                                  schoolId: widget.schoolId,
                                  sessionId: widget.session.id,
                                  studentId: student.studentId,
                                );
                                Get.back(); // close progress
                                Get.snackbar(
                                  'Sukses',
                                  'Murid berhasil diabsen manual.',
                                  backgroundColor: Colors.green,
                                  colorText: Colors.white,
                                );
                              } catch (e) {
                                Get.back(); // close progress
                                Get.snackbar(
                                  'Error',
                                  e.toString(),
                                  backgroundColor: Colors.redAccent,
                                  colorText: Colors.white,
                                );
                              }
                            },
                            icon: const Icon(Icons.check_circle_outline_rounded, size: 16),
                            label: const Text('Absen Manual (Tandai Hadir)'),
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
            Text('Riwayat Log Aktivitas', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: titleColor)),
            const Divider(height: 16),
            if (sortedLog.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Center(child: Text(
                  student.submittedAt != null
                      ? 'Murid telah menyelesaikan dan mengumpulkan ujian.'
                      : 'Belum ada aktivitas (murid belum mulai mengerjakan ujian).',
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
              child: const Text('Tutup', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            ),
          ],
        ),
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


