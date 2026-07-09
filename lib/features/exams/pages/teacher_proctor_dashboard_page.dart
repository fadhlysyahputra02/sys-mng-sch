import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../../core/services/session_service.dart';
import '../../authentication/widgets/auth_background.dart';
import '../../students/pages/student_qr_scanner_page.dart';
import '../models/exam_event_model.dart';
import '../services/exam_session_service.dart';
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
        final upcoming = sessions
            .where((s) => s.examStatus != 'Finished')
            .toList();
        final past = sessions
            .where((s) => s.examStatus == 'Finished')
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
                  schoolId)),
            ],
            if (past.isNotEmpty) ...[
              const SizedBox(height: 20),
              _buildSectionHeader('Selesai', Icons.history_rounded,
                  const Color(0xFF64748B), isDark, titleColor),
              const SizedBox(height: 10),
              ...past.map((s) => _buildProctorSessionCard(
                  s, isDark, cardColor, cardBorder, titleColor, subtitleColor,
                  schoolId,
                  isFinished: true)),
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
  }) {
    final isToday = DateFormat('yyyy-MM-dd').format(session.date) ==
        DateFormat('yyyy-MM-dd').format(DateTime.now());
    // Active only if status is Active AND it's actually today
    final isActive = session.examStatus == 'Active' && isToday;

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
                    _buildStatusBadge(session.examStatus, isToday: isToday),
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
                      // Only allow activation on the actual session date
                      if (!isActive && isToday)
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _activateQr(schoolId, session),
                            icon: const Icon(Icons.qr_code_rounded, size: 16),
                            label: const Text('Aktifkan QR'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF10B981),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              textStyle: const TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      // Future session — show info chip only
                      if (!isActive && !isToday)
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
                              Text('QR hanya bisa diaktifkan pada hari H',
                                  style: TextStyle(
                                    color: Color(0xFF64748B),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  )),
                            ],
                          ),
                        ),
                      if (isActive) ...[
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _scanStudentQrForSession(context, session),
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
//  ProctorRoomSeatingPage — Denah Tempat Duduk Pengawas
// ─────────────────────────────────────────────────────────────
class ProctorRoomSeatingPage extends StatelessWidget {
  final String schoolId;
  final ExamSession session;

  const ProctorRoomSeatingPage({
    super.key,
    required this.schoolId,
    required this.session,
  });

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
            title: Text(
              'Denah Kursi: ${session.roomName.isNotEmpty ? session.roomName : "Ruang Ujian"}',
              style: TextStyle(
                  color: titleColor, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            backgroundColor: scaffoldBg,
            surfaceTintColor: Colors.transparent,
            scrolledUnderElevation: 0,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back_rounded, color: titleColor),
              onPressed: () => Get.back(),
            ),
          ),
          body: AuthBackground(
            child: StreamBuilder<List<ExamParticipation>>(
              stream: service.getParticipations(
                  schoolId: schoolId, sessionId: session.id),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final participations = snap.data ?? [];
                if (participations.isEmpty) {
                  return Center(
                    child: Text(
                      'Belum ada alokasi kursi untuk sesi ini.',
                      style: TextStyle(color: subtitleColor),
                    ),
                  );
                }

                // Sort by seatNumber
                participations.sort((a, b) => a.seatNumber.compareTo(b.seatNumber));

                // Get unique angkatan for color assignments
                final angkatans =
                    participations.map((p) => p.angkatan).toSet().toList();
                angkatans.sort(); // Sort A-Z

                // Assign colors
                Color getCohortColor(String angkatan) {
                  if (angkatans.isEmpty) return const Color(0xFF8B5CF6);
                  final index = angkatans.indexOf(angkatan);
                  if (index == 0) return const Color(0xFF8B5CF6); // Purple
                  if (index == 1) return const Color(0xFF10B981); // Emerald/Green
                  if (index == 2) return const Color(0xFFF59E0B); // Orange
                  return const Color(0xFF3B82F6); // Blue
                }

                // Determine grid layout
                final maxSeat = participations.map((p) => p.seatNumber).fold(0, (max, e) => e > max ? e : max);
                const columns = 4;
                final rows = (maxSeat / columns).ceil();

                // Map for quick seat lookup
                final seatMap = {for (var p in participations) p.seatNumber: p};

                return Column(
                  children: [
                    // Proctor Desk / Board Banner
                    Container(
                      margin: const EdgeInsets.all(16),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : Colors.black.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.1)
                              : Colors.black.withValues(alpha: 0.1),
                        ),
                      ),
                      child: Center(
                        child: Text(
                          'PAPAN TULIS / MEJA PENGAWAS',
                          style: TextStyle(
                            color: subtitleColor,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2,
                          ),
                        ),
                      ),
                    ),

                    // Legend
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Wrap(
                        spacing: 12,
                        runSpacing: 6,
                        children: [
                          ...angkatans.map((a) {
                            final color = getCohortColor(a);
                            return Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    color: color,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Angkatan $a',
                                  style: TextStyle(color: subtitleColor, fontSize: 11),
                                ),
                              ],
                            );
                          }),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  border: Border.all(color: subtitleColor.withValues(alpha: 0.5)),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Belum Hadir (Redup)',
                                style: TextStyle(color: subtitleColor, fontSize: 11),
                              ),
                            ],
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade500,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Hadir (Solid)',
                                style: TextStyle(color: subtitleColor, fontSize: 11),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Grid of Seats
                    Expanded(
                      child: GridView.builder(
                        padding: const EdgeInsets.all(16),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: columns,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 0.85,
                        ),
                        itemCount: rows * columns,
                        itemBuilder: (context, i) {
                          final seatNum = i + 1;
                          final student = seatMap[seatNum];

                          if (student == null) {
                            // Seat exists in layout but no student assigned
                            return Container(
                              decoration: BoxDecoration(
                                color: Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.08)
                                      : Colors.black.withValues(alpha: 0.06),
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  'Kursi $seatNum\n(Kosong)',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: subtitleColor.withValues(alpha: 0.3),
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                            );
                          }

                          final isPresent = student.scannedAt != null;
                          final cohortColor = getCohortColor(student.angkatan);
                          final seatColor = isPresent
                              ? cohortColor
                              : cohortColor.withValues(alpha: 0.12);
                          final seatBorderColor = isPresent
                              ? cohortColor
                              : cohortColor.withValues(alpha: 0.4);
                          final textColor = isPresent
                              ? Colors.white
                              : isDark
                                  ? Colors.white.withValues(alpha: 0.7)
                                  : const Color(0xFF1E1B4B).withValues(alpha: 0.8);
                          final subTextColor = isPresent
                              ? Colors.white.withValues(alpha: 0.8)
                              : subtitleColor;

                          return Container(
                            decoration: BoxDecoration(
                              color: seatColor,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: seatBorderColor,
                                width: isPresent ? 1.5 : 1,
                              ),
                              boxShadow: isPresent
                                  ? [
                                      BoxShadow(
                                        color: cohortColor.withValues(alpha: 0.15),
                                        blurRadius: 6,
                                        offset: const Offset(0, 2),
                                      )
                                    ]
                                  : null,
                            ),
                            padding: const EdgeInsets.all(6),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // Seat Icon / Badge
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 5, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: isPresent
                                            ? Colors.white.withValues(alpha: 0.2)
                                            : cohortColor.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        '#$seatNum',
                                        style: TextStyle(
                                          color: isPresent ? Colors.white : cohortColor,
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    Icon(
                                      isPresent
                                          ? Icons.check_circle_rounded
                                          : Icons.radio_button_unchecked_rounded,
                                      size: 12,
                                      color: isPresent ? Colors.white : cohortColor,
                                    ),
                                  ],
                                ),
                                const Spacer(),
                                Text(
                                  student.studentName,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: textColor,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  student.nis,
                                  style: TextStyle(
                                    color: subTextColor,
                                    fontSize: 9,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  isPresent ? 'Hadir' : 'Belum Hadir',
                                  style: TextStyle(
                                    color: isPresent ? Colors.white : cohortColor,
                                    fontSize: 8,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
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

      // Show loading
      Get.dialog(
        const Center(child: CircularProgressIndicator()),
        barrierDismissible: false,
      );

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
      _showErrorDialog(errMsg);
    }
  }

  void _showErrorDialog(String message) {
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
}
