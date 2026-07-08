import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/services/session_service.dart';
import '../../authentication/widgets/auth_background.dart';
import '../../students/pages/student_qr_scanner_page.dart';
import '../models/exam_event_model.dart';
import '../services/exam_session_service.dart';
import '../models/exam_model.dart';
import 'student_take_exam_page.dart';

// ─────────────────────────────────────────────────────────────
//  StudentExamParticipationPage
//  Halaman siswa untuk melihat jadwal ujian semester & scan QR
// ─────────────────────────────────────────────────────────────
class StudentExamParticipationPage extends StatefulWidget {
  final String classId;
  final String studentDocId;
  final String studentName;
  final String studentNis;

  const StudentExamParticipationPage({
    super.key,
    required this.classId,
    required this.studentDocId,
    required this.studentName,
    required this.studentNis,
  });

  @override
  State<StudentExamParticipationPage> createState() =>
      _StudentExamParticipationPageState();
}

class _StudentExamParticipationPageState
    extends State<StudentExamParticipationPage> {
  final _service = ExamSessionService();

  // Cache status scan per sessionId
  final Map<String, bool> _scanStatusCache = {};
  bool _isScanning = false;

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
                        IconButton(
                          icon: Icon(Icons.arrow_back_rounded,
                              color: titleColor),
                          onPressed: () => Get.back(),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Jadwal Ujian Semester',
                                style: TextStyle(
                                    color: titleColor,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold),
                              ),
                              Text(
                                widget.studentName,
                                style: TextStyle(
                                    color: subtitleColor, fontSize: 12),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Content
                Expanded(
                  child: StreamBuilder<List<ExamSession>>(
                    stream: _service.getSessionsByClass(schoolId, widget.classId),
                    builder: (context, snap) {
                      if (snap.connectionState == ConnectionState.waiting) {
                        return Center(
                          child: CircularProgressIndicator(
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF8B5CF6),
                          ),
                        );
                      }

                      final sessions = snap.data ?? [];

                      if (sessions.isEmpty) {
                        return _buildEmptyState(
                            isDark, titleColor, subtitleColor);
                      }

                      // Group by date
                      final Map<String, List<ExamSession>> grouped = {};
                      for (final s in sessions) {
                        final key = DateFormat('yyyy-MM-dd').format(s.date);
                        grouped.putIfAbsent(key, () => []).add(s);
                      }
                      final sortedDates = grouped.keys.toList()..sort();

                      // Preload scan status
                      _prefetchScanStatus(schoolId, sessions);

                      return CustomScrollView(
                        slivers: [
                          // Info Banner
                          SliverToBoxAdapter(
                            child: Padding(
                              padding:
                                  const EdgeInsets.fromLTRB(24, 16, 24, 8),
                              child: _buildInfoBanner(isDark),
                            ),
                          ),

                          // Session Groups
                          SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (_, i) {
                                final dateKey = sortedDates[i];
                                final daySessions = grouped[dateKey]!;
                                final date =
                                    DateFormat('yyyy-MM-dd').parse(dateKey);
                                return Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                      24, 8, 24, 0),
                                  child: _buildDayGroup(
                                    date,
                                    daySessions,
                                    isDark,
                                    cardColor,
                                    cardBorder,
                                    titleColor,
                                    subtitleColor,
                                    schoolId,
                                  ),
                                );
                              },
                              childCount: sortedDates.length,
                            ),
                          ),
                          const SliverToBoxAdapter(child: SizedBox(height: 40)),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _prefetchScanStatus(
      String schoolId, List<ExamSession> sessions) async {
    for (final s in sessions) {
      if (!_scanStatusCache.containsKey(s.id)) {
        final hasScanned = await _service.hasStudentScanned(
          schoolId: schoolId,
          sessionId: s.id,
          studentId: widget.studentDocId,
        );
        if (mounted) {
          setState(() => _scanStatusCache[s.id] = hasScanned);
        }
      }
    }
  }

  Widget _buildInfoBanner(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF8B5CF6).withValues(alpha: isDark ? 0.2 : 0.1),
            const Color(0xFFEC4899).withValues(alpha: isDark ? 0.1 : 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: const Color(0xFF8B5CF6).withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_rounded, color: Color(0xFF8B5CF6), size: 18),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Scan QR yang ditampilkan pengawas sebelum memulai ujian. Tombol "Mulai Ujian" hanya aktif setelah scan berhasil.',
              style: TextStyle(
                color: Color(0xFF8B5CF6),
                fontSize: 12,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayGroup(
    DateTime date,
    List<ExamSession> sessions,
    bool isDark,
    Color cardColor,
    Color cardBorder,
    Color titleColor,
    Color subtitleColor,
    String schoolId,
  ) {
    final isToday = DateFormat('yyyy-MM-dd').format(date) ==
        DateFormat('yyyy-MM-dd').format(DateTime.now());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Row(
          children: [
            Container(
              width: 4,
              height: 16,
              decoration: BoxDecoration(
                color: isToday
                    ? const Color(0xFF10B981)
                    : const Color(0xFF8B5CF6),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              DateFormat('EEEE, dd MMMM yyyy', 'id').format(date),
              style: TextStyle(
                color: isToday ? const Color(0xFF10B981) : titleColor,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
            if (isToday) ...[
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text('Hari Ini',
                    style: TextStyle(
                        color: Color(0xFF10B981),
                        fontSize: 10,
                        fontWeight: FontWeight.bold)),
              ),
            ],
          ],
        ),
        const SizedBox(height: 10),
        ...sessions.map((s) => _buildSessionCard(
            s, isDark, cardColor, cardBorder, titleColor, subtitleColor,
            schoolId)),
      ],
    );
  }

  Widget _buildSessionCard(
    ExamSession session,
    bool isDark,
    Color cardColor,
    Color cardBorder,
    Color titleColor,
    Color subtitleColor,
    String schoolId,
  ) {
    final hasScan = _scanStatusCache[session.id] ?? false;
    final isActive = session.isQrActive;
    final isToday = DateFormat('yyyy-MM-dd').format(session.date) ==
        DateFormat('yyyy-MM-dd').format(DateTime.now());

    Color accentColor;
    if (hasScan) {
      accentColor = const Color(0xFF10B981);
    } else if (isActive) {
      accentColor = const Color(0xFF8B5CF6);
    } else {
      accentColor = const Color(0xFF64748B);
    }

    return StreamBuilder<ExamParticipation?>(
      stream: _service.getParticipationStream(
        schoolId: schoolId,
        sessionId: session.id,
        studentId: widget.studentDocId,
      ),
      builder: (context, partSnap) {
        final participation = partSnap.data;
        final roomName = participation?.roomName ?? '';
        final seatNumber = participation?.seatNumber ?? 0;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: hasScan
                  ? const Color(0xFF10B981).withValues(alpha: 0.4)
                  : isActive
                      ? const Color(0xFF8B5CF6).withValues(alpha: 0.4)
                      : cardBorder,
              width: (hasScan || isActive) ? 1.5 : 1,
            ),
          ),
          child: Column(
            children: [
          // Top accent strip
          Container(
            height: 3,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.6),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(18)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Subject + Slot
                Row(
                  children: [
                    Expanded(
                      child: Text(session.subjectName,
                          style: TextStyle(
                              color: titleColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 15)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(session.slotName,
                          style: TextStyle(
                              color: accentColor,
                              fontSize: 11,
                              fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '${session.startTime} – ${session.endTime}',
                  style: TextStyle(color: subtitleColor, fontSize: 12),
                ),
                if (roomName.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.meeting_room_rounded,
                          size: 13, color: subtitleColor),
                      const SizedBox(width: 4),
                      Text('Ruang: $roomName',
                          style:
                              TextStyle(color: subtitleColor, fontSize: 12)),
                      if (seatNumber > 0) ...[
                        const SizedBox(width: 12),
                        Icon(Icons.event_seat_rounded,
                            size: 13, color: subtitleColor),
                        const SizedBox(width: 4),
                        Text('Kursi: $seatNumber',
                            style:
                                TextStyle(color: subtitleColor, fontSize: 12)),
                      ],
                    ],
                  ),
                ],
                const SizedBox(height: 12),

                // Scan status + action row
                Row(
                  children: [
                    // Scan status chip
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: hasScan
                            ? const Color(0xFF10B981).withValues(alpha: 0.12)
                            : const Color(0xFF64748B).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: hasScan
                              ? const Color(0xFF10B981).withValues(alpha: 0.4)
                              : const Color(0xFF64748B).withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            hasScan
                                ? Icons.check_circle_rounded
                                : Icons.radio_button_unchecked,
                            size: 13,
                            color: hasScan
                                ? const Color(0xFF10B981)
                                : const Color(0xFF64748B),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            hasScan ? 'Sudah Scan' : 'Belum Scan',
                            style: TextStyle(
                              color: hasScan
                                  ? const Color(0xFF10B981)
                                  : const Color(0xFF64748B),
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),

                    // Action buttons
                    if (hasScan)
                      StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                        stream: FirebaseFirestore.instance
                            .collection('schools')
                            .doc(schoolId)
                            .collection('exams')
                            .doc('${session.eventId}_${session.subjectId}_${session.classId}')
                            .snapshots(),
                        builder: (context, examSnap) {
                          if (examSnap.connectionState == ConnectionState.waiting) {
                            return const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            );
                          }
                          final doc = examSnap.data;
                          if (doc == null || !doc.exists || doc.data() == null) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.warning_amber_rounded,
                                      size: 13, color: Color(0xFFEF4444)),
                                  SizedBox(width: 4),
                                  Text('Soal Belum Siap',
                                      style: TextStyle(
                                          color: Color(0xFFEF4444),
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold)),
                                ],
                              ),
                            );
                          }

                          final exam = Exam.fromFirestore(doc);

                          if (exam.questions.isEmpty) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.warning_amber_rounded,
                                      size: 13, color: Color(0xFFEF4444)),
                                  SizedBox(width: 4),
                                  Text('Soal Masih Kosong',
                                      style: TextStyle(
                                          color: Color(0xFFEF4444),
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold)),
                                ],
                              ),
                            );
                          }

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              if (roomName.isNotEmpty && seatNumber > 0) ...[
                                Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: const Color(0xFF8B5CF6).withValues(alpha: 0.3),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.event_seat_rounded,
                                        color: Color(0xFF8B5CF6),
                                        size: 14,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Ruang: $roomName | Kursi: $seatNumber',
                                        style: const TextStyle(
                                          color: Color(0xFF8B5CF6),
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              ElevatedButton.icon(
                                onPressed: () => Get.to(() => StudentTakeExamPage(
                                      exam: exam,
                                      studentDocId: widget.studentDocId,
                                    )),
                                icon: const Icon(Icons.play_arrow_rounded, size: 16),
                                label: const Text('Mulai Ujian'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF10B981),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10)),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 8),
                                  textStyle: const TextStyle(
                                      fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          );
                        },
                      )
                    else if (isToday && isActive)
                      ElevatedButton.icon(
                        onPressed: _isScanning
                            ? null
                            : () => _scanQr(context, session, schoolId),
                        icon: const Icon(Icons.qr_code_scanner_rounded,
                            size: 16),
                        label: const Text('Scan QR'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF8B5CF6),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          textStyle: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      )
                    else if (isToday && !isActive)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B)
                              .withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.hourglass_empty_rounded,
                                size: 13, color: Color(0xFFF59E0B)),
                            SizedBox(width: 4),
                            Text('QR Belum Aktif',
                                style: TextStyle(
                                    color: Color(0xFFF59E0B),
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold)),
                          ],
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF64748B)
                              .withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.calendar_month_rounded,
                                size: 13, color: Color(0xFF64748B)),
                            SizedBox(width: 4),
                            Text('Bukan Hari Ini',
                                style: TextStyle(
                                    color: Color(0xFF64748B),
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                  ],
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

  Future<void> _scanQr(
      BuildContext context, ExamSession session, String schoolId) async {
    setState(() => _isScanning = true);

    try {
      final result = await Get.to<String>(() => const StudentQrScannerPage(
            title: 'Scan QR Presensi Ujian',
            subtitle: 'Arahkan kamera ke QR yang ditampilkan pengawas',
          ));

      if (result == null || result.isEmpty) {
        setState(() => _isScanning = false);
        return;
      }

      final trimmedResult = result.trim();
      final isJson = trimmedResult.startsWith('{') && trimmedResult.endsWith('}');

      if (!isJson) {
        // Treat as desk code: roomName-seatNumber-angkatan
        // Fetch student's designated participation
        final db = FirebaseFirestore.instance;
        final partDoc = await db
            .collection('schools')
            .doc(schoolId)
            .collection('exam_sessions')
            .doc(session.id)
            .collection('participations')
            .doc(widget.studentDocId)
            .get();

        if (!partDoc.exists) {
          _showError('Anda tidak terdaftar dalam sesi ujian ini.');
          setState(() => _isScanning = false);
          return;
        }

        final data = partDoc.data()!;
        final assignedRoom = data['roomName'] as String? ?? '';
        final assignedSeat = data['seatNumber'] as int? ?? 0;
        final assignedAngkatan = data['angkatan'] as String? ?? '';

        final expectedCode = '$assignedRoom-$assignedSeat-$assignedAngkatan';

        if (trimmedResult != expectedCode) {
          _showError('Meja tidak sesuai! Meja Anda adalah di $assignedRoom - Nomor $assignedSeat.');
          setState(() => _isScanning = false);
          return;
        }

        // Cek sesi masih aktif
        if (!session.isQrActive) {
          _showError('Sesi ujian belum diaktifkan pengawas');
          setState(() => _isScanning = false);
          return;
        }

        // Catat participation
        await _service.recordParticipation(
          schoolId: schoolId,
          sessionId: session.id,
          studentId: widget.studentDocId,
          studentName: widget.studentName,
          nis: widget.studentNis,
        );

        setState(() {
          _scanStatusCache[session.id] = true;
          _isScanning = false;
        });

        Get.snackbar(
          '✅ Presensi Berhasil',
          'Scan Meja $expectedCode Berhasil! Silakan mulai ujian.',
          backgroundColor: const Color(0xFF10B981),
          colorText: Colors.white,
          snackPosition: SnackPosition.TOP,
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 3),
        );
        return;
      }

      // Parse QR payload
      Map<String, dynamic> payload;
      try {
        payload = jsonDecode(trimmedResult) as Map<String, dynamic>;
      } catch (_) {
        _showError('Format QR tidak valid');
        setState(() => _isScanning = false);
        return;
      }

      final type = payload['type'] as String?;

      if (type == 'exam_desk') {
        final scannedRoom = payload['roomName'] as String?;
        final scannedSeat = payload['seatNumber'];
        
        if (scannedRoom == null || scannedSeat == null) {
          _showError('Detail meja QR tidak lengkap');
          setState(() => _isScanning = false);
          return;
        }

        final seatInt = int.tryParse(scannedSeat.toString());
        if (seatInt == null) {
          _showError('Nomor meja tidak valid');
          setState(() => _isScanning = false);
          return;
        }

        // Fetch student's designated participation
        final db = FirebaseFirestore.instance;
        final partDoc = await db
            .collection('schools')
            .doc(schoolId)
            .collection('exam_sessions')
            .doc(session.id)
            .collection('participations')
            .doc(widget.studentDocId)
            .get();

        if (!partDoc.exists) {
          _showError('Anda tidak terdaftar dalam sesi ujian ini.');
          setState(() => _isScanning = false);
          return;
        }

        final data = partDoc.data()!;
        final assignedRoom = data['roomName'] as String? ?? '';
        final assignedSeat = data['seatNumber'] as int? ?? 0;

        // Check if assigned room and seat match
        if (assignedRoom != scannedRoom || assignedSeat != seatInt) {
          _showError('Meja tidak sesuai! Anda terdaftar di $assignedRoom - Meja $assignedSeat.');
          setState(() => _isScanning = false);
          return;
        }

        // Cek sesi masih aktif
        if (!session.isQrActive) {
          _showError('Sesi ujian belum diaktifkan pengawas');
          setState(() => _isScanning = false);
          return;
        }

        // Catat participation
        await _service.recordParticipation(
          schoolId: schoolId,
          sessionId: session.id,
          studentId: widget.studentDocId,
          studentName: widget.studentName,
          nis: widget.studentNis,
        );

        setState(() {
          _scanStatusCache[session.id] = true;
          _isScanning = false;
        });

        Get.snackbar(
          '✅ Presensi Berhasil',
          'Scan Meja $scannedRoom - No. $seatInt Berhasil! Silakan mulai ujian.',
          backgroundColor: const Color(0xFF10B981),
          colorText: Colors.white,
          snackPosition: SnackPosition.TOP,
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 3),
        );
        return;
      }

      final sessionId = payload['sessionId'] as String?;
      final qrToken = payload['qrToken'] as String?;

      // Validasi tipe dan session
      if (type != 'exam_session' || sessionId != session.id) {
        _showError('QR bukan untuk sesi ujian ini');
        setState(() => _isScanning = false);
        return;
      }

      // Validasi token
      if (qrToken != session.qrToken) {
        _showError('Token QR tidak valid atau sudah kadaluarsa');
        setState(() => _isScanning = false);
        return;
      }

      // Cek sesi masih aktif
      if (!session.isQrActive) {
        _showError('Sesi ujian belum diaktifkan pengawas');
        setState(() => _isScanning = false);
        return;
      }

      // Catat participation
      await _service.recordParticipation(
        schoolId: schoolId,
        sessionId: session.id,
        studentId: widget.studentDocId,
        studentName: widget.studentName,
        nis: widget.studentNis,
      );

      setState(() {
        _scanStatusCache[session.id] = true;
        _isScanning = false;
      });

      Get.snackbar(
        '✅ Presensi Berhasil',
        'Scan QR ${session.subjectName} berhasil! Anda dapat memulai ujian.',
        backgroundColor: const Color(0xFF10B981),
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      );
    } catch (e) {
      setState(() => _isScanning = false);
      _showError('Gagal memproses scan: $e');
    }
  }

  void _showError(String msg) {
    Get.snackbar('Gagal', msg,
        backgroundColor: const Color(0xFFEF4444),
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
        margin: const EdgeInsets.all(16));
  }

  Widget _buildEmptyState(
      bool isDark, Color titleColor, Color subtitleColor) {
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
              child: Icon(
                Icons.event_available_rounded,
                size: 36,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.3)
                    : Colors.black26,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Belum Ada Jadwal Ujian',
              style: TextStyle(
                  color: titleColor,
                  fontSize: 18,
                  fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Jadwal ujian semester untuk kelas Anda akan muncul di sini saat Admin telah membuat jadwal.',
              style:
                  TextStyle(color: subtitleColor, fontSize: 14, height: 1.5),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
