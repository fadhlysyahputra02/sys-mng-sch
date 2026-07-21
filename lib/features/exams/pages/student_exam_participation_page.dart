import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../core/services/session_service.dart';
import '../../authentication/widgets/auth_background.dart';
import '../models/exam_event_model.dart';
import '../services/exam_session_service.dart';
import '../models/exam_model.dart';
import '../services/exam_service.dart';
import 'student_take_exam_page.dart';

// ─────────────────────────────────────────────────────────────
//  StudentExamParticipationPage
//  Halaman siswa untuk melihat jadwal ujian semester & scan QR
// ─────────────────────────────────────────────────────────────
// Global memory caches to persist schedule and event data during app session per student
final Map<String, List<ExamSession>> _globalSessionsCache = {};
final Map<String, ExamEvent> _globalEventCache = {};
// Participation cache keyed by "schoolId_sessionId_studentId"
final Map<String, ExamParticipation?> _globalParticipationCache = {};

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

  late Stream<List<ExamSession>> _sessionsStream;
  Stream<ExamEvent?>? _eventStream;
  String? _lastEventId;
  bool _prefetchDone = false;
  String? _studentAngkatan;

  @override
  void initState() {
    super.initState();
    final schoolId = SessionService.currentUser!.schoolId;
    _sessionsStream = _service.getSessionsByClass(schoolId, widget.classId);

    FirebaseFirestore.instance
        .collection('schools')
        .doc(schoolId)
        .collection('students')
        .doc(widget.studentDocId)
        .get()
        .then((doc) {
      if (doc.exists && doc.data() != null && mounted) {
        setState(() {
          _studentAngkatan = (doc.data()?['angkatan'] ?? '').toString().trim();
        });
      }
    });

    final cachedEvent = _globalEventCache[widget.studentDocId];
    if (cachedEvent != null) {
      _lastEventId = cachedEvent.id;
      _eventStream = _service.getExamEventById(schoolId, cachedEvent.id);
    }

    // Prefetch participation for cached sessions once on init
    final cachedSessions = _globalSessionsCache[widget.studentDocId];
    if (cachedSessions != null && cachedSessions.isNotEmpty) {
      _prefetchDone = true;
      _prefetchParticipation(schoolId, cachedSessions);
    }
  }

  void _initEventStream(String schoolId, String eventId) {
    if (_lastEventId == eventId && _eventStream != null) return;
    _lastEventId = eventId;
    _eventStream = _service.getExamEventById(schoolId, eventId);
  }

  void _maybeInitPrefetch(String schoolId, List<ExamSession> sessions) {
    if (_prefetchDone) return;
    _prefetchDone = true;
    _prefetchParticipation(schoolId, sessions);
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
                    stream: _sessionsStream,
                    initialData: _globalSessionsCache[widget.studentDocId],
                    builder: (context, snap) {
                      if (!snap.hasData && snap.connectionState == ConnectionState.waiting) {
                        return Center(
                          child: CircularProgressIndicator(
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF8B5CF6),
                          ),
                        );
                      }

                      final sessions = snap.data ?? [];

                      if (sessions.isNotEmpty) {
                        _globalSessionsCache[widget.studentDocId] = sessions;
                        // Prefetch participation only once per page visit
                        _maybeInitPrefetch(schoolId, sessions);
                      }

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

                      return CustomScrollView(
                        slivers: [
                          // Event Info
                          if (sessions.isNotEmpty)
                            SliverToBoxAdapter(
                              child: Builder(
                                builder: (context) {
                                  _initEventStream(schoolId, sessions.first.eventId);
                                  return StreamBuilder<ExamEvent?>(
                                    stream: _eventStream,
                                    initialData: _globalEventCache[widget.studentDocId],
                                    builder: (context, eventSnap) {
                                      final event = eventSnap.data;
                                      if (event != null) {
                                        _globalEventCache[widget.studentDocId] = event;
                                      }
                                      if (event == null) return const SizedBox.shrink();
                                      return Padding(
                                        padding: const EdgeInsets.fromLTRB(24, 20, 24, 4),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              event.title,
                                              style: TextStyle(
                                                color: titleColor,
                                                fontSize: 20,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              '${event.examType} • ${DateFormat('dd MMM').format(event.startDate)} - ${DateFormat('dd MMM yyyy').format(event.endDate)}',
                                              style: TextStyle(
                                                color: subtitleColor,
                                                fontSize: 13,
                                                fontWeight: FontWeight.w500,
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

                          // Info Banner
                          SliverToBoxAdapter(
                            child: Padding(
                              padding:
                                  const EdgeInsets.fromLTRB(24, 16, 24, 8),
                              child: _buildInfoBanner(isDark),
                            ),
                          ),

                          // QR Code Utama
                          SliverToBoxAdapter(
                            child: Padding(
                              padding:
                                  const EdgeInsets.fromLTRB(24, 8, 24, 8),
                              child: _buildMainQrCard(isDark, cardColor, cardBorder, titleColor, subtitleColor),
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

  Future<void> _prefetchParticipation(
      String schoolId, List<ExamSession> sessions) async {
    for (final s in sessions) {
      final cacheKey = '${schoolId}_${s.id}_${widget.studentDocId}';
      if (_globalParticipationCache.containsKey(cacheKey)) continue;
      try {
        final p = await _service.getParticipationOnce(
          schoolId: schoolId,
          sessionId: s.id,
          studentId: widget.studentDocId,
        );
        _globalParticipationCache[cacheKey] = p;
      } catch (_) {}
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

  Widget _buildMainQrCard(bool isDark, Color cardColor, Color cardBorder, Color titleColor, Color subtitleColor) {
    final qrData = jsonEncode({
      'type': 'exam_attendance',
      'studentId': widget.studentDocId,
      'studentName': widget.studentName,
      'nis': widget.studentNis,
    });

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
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
        children: [
          Text(
            'KARTU QR PRESENSI UTAMA',
            style: TextStyle(
              color: titleColor,
              fontWeight: FontWeight.bold,
              fontSize: 13,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Tunjukkan QR ini ke Pengawas untuk presensi ujian',
            style: TextStyle(color: subtitleColor, fontSize: 11),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () => _showFullScreenQr(
              context,
              qrData,
              'QR Ujian Murid',
              isDark,
            ),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                    blurRadius: 12,
                  ),
                ],
              ),
              child: QrImageView(
                data: qrData,
                version: QrVersions.auto,
                size: 140,
                backgroundColor: Colors.white,
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
          const SizedBox(height: 10),
          Text(
            'Ketuk QR untuk Memperbesar',
            style: TextStyle(
              color: subtitleColor,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  void _showFullScreenQr(BuildContext context, String qrData, String name, bool isDark) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(24),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A1730) : Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF8B5CF6).withValues(alpha: 0.3),
                blurRadius: 30,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.qr_code_rounded,
                        color: Color(0xFF10B981), size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('QR Presensi Ujian',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 14)),
                        Text(name,
                            style: const TextStyle(
                                color: Color(0xFF10B981), fontSize: 12)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(ctx),
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.5)
                        : Colors.black45,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF8B5CF6).withValues(alpha: 0.2),
                      blurRadius: 20,
                    ),
                  ],
                ),
                child: QrImageView(
                  data: qrData,
                  version: QrVersions.auto,
                  size: 260,
                  backgroundColor: Colors.white,
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
              const SizedBox(height: 16),
              Text(
                'Tunjukkan QR ini ke Pengawas untuk presensi',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isDark ? Colors.white70 : Colors.black87,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
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
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Container(
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: cardBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: cardBorder)),
                    color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
                  ),
                  child: Row(
                    children: [
                      SizedBox(width: 150, child: Text('Mata Pelajaran', style: TextStyle(color: titleColor, fontSize: 12, fontWeight: FontWeight.bold))),
                      SizedBox(width: 90, child: Text('Waktu', style: TextStyle(color: titleColor, fontSize: 12, fontWeight: FontWeight.bold))),
                      SizedBox(width: 110, child: Text('Ruangan', style: TextStyle(color: titleColor, fontSize: 12, fontWeight: FontWeight.bold))),
                      SizedBox(width: 120, child: Text('Status', style: TextStyle(color: titleColor, fontSize: 12, fontWeight: FontWeight.bold))),
                      SizedBox(width: 130, child: Text('Aksi', style: TextStyle(color: titleColor, fontSize: 12, fontWeight: FontWeight.bold))),
                    ],
                  ),
                ),
                // Rows
                ..._groupAndDeduplicate(sessions).asMap().entries.map((entry) {
                  final candidates = entry.value;
                  final isLast = entry.key == _groupAndDeduplicate(sessions).length - 1;
                  return ResolvedSessionTableRow(
                    candidates: candidates,
                    studentDocId: widget.studentDocId,
                    studentName: widget.studentName,
                    studentNis: widget.studentNis,
                    schoolId: schoolId,
                    isDark: isDark,
                    cardBorder: cardBorder,
                    titleColor: titleColor,
                    subtitleColor: subtitleColor,
                    isLastRow: isLast,
                  );
                }),
              ],
            ),
          ),
        ),
      ],
    );
  }

  List<List<ExamSession>> _groupAndDeduplicate(List<ExamSession> sessions) {
    final Map<String, List<ExamSession>> groups = {};
    for (final s in sessions) {
      final key = '${s.subjectId}_${s.slotName}';
      groups.putIfAbsent(key, () => []).add(s);
    }
    return groups.values.toList();
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

class ResolvedSessionTableRow extends StatefulWidget {
  final List<ExamSession> candidates;
  final String studentDocId;
  final String studentName;
  final String studentNis;
  final String schoolId;
  final bool isDark;
  final Color cardBorder;
  final Color titleColor;
  final Color subtitleColor;
  final bool isLastRow;

  const ResolvedSessionTableRow({
    super.key,
    required this.candidates,
    required this.studentDocId,
    required this.studentName,
    required this.studentNis,
    required this.schoolId,
    required this.isDark,
    required this.cardBorder,
    required this.titleColor,
    required this.subtitleColor,
    this.isLastRow = false,
  });

  @override
  State<ResolvedSessionTableRow> createState() => _ResolvedSessionTableRowState();
}

class _ResolvedSessionTableRowState extends State<ResolvedSessionTableRow> {
  ExamSession? _resolvedSession;
  late Stream<ExamParticipation?> _participationStream;
  Stream<DocumentSnapshot<Map<String, dynamic>>>? _examStream;
  Stream<DocumentSnapshot>? _submissionStream;
  String? _lastExamDocId;
  String? _lastSubmissionDocId;
  String? _studentAngkatan;

  @override
  void initState() {
    super.initState();
    _resolvedSession = widget.candidates.first;
    _resolve();
    _initParticipationStream();
    
    FirebaseFirestore.instance
        .collection('schools')
        .doc(widget.schoolId)
        .collection('students')
        .doc(widget.studentDocId)
        .get()
        .then((doc) {
      if (doc.exists && doc.data() != null && mounted) {
        setState(() {
          _studentAngkatan = (doc.data()?['angkatan'] ?? '').toString().trim();
        });
      }
    });

    // ⏰ Refresh setiap 30 detik agar tombol muncul tepat waktu
    _clockTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  Timer? _clockTimer;

  @override
  void didUpdateWidget(ResolvedSessionTableRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.candidates != oldWidget.candidates) {
      _resolve();
    }
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    super.dispose();
  }

  void _initParticipationStream() {
    final session = _resolvedSession ?? widget.candidates.first;
    _participationStream = ExamSessionService().getParticipationStream(
      schoolId: widget.schoolId,
      sessionId: session.id,
      studentId: widget.studentDocId,
    );
    // Also warm up the global cache key for this row
    _cacheKey = '${widget.schoolId}_${session.id}_${widget.studentDocId}';
  }

  String _cacheKey = '';

  void _initExamStream(ExamSession session) {
    final examDocId = '${session.eventId}_${session.subjectId}_${session.classId}';
    if (_lastExamDocId == examDocId && _examStream != null) return;
    _lastExamDocId = examDocId;
    _examStream = FirebaseFirestore.instance
        .collection('schools')
        .doc(widget.schoolId)
        .collection('exams')
        .doc(examDocId)
        .snapshots();
  }

  void _initSubmissionStream(String examId) {
    final submissionDocId = '${examId}_${widget.studentDocId}';
    if (_lastSubmissionDocId == submissionDocId && _submissionStream != null) return;
    _lastSubmissionDocId = submissionDocId;
    _submissionStream = FirebaseFirestore.instance
        .collection('schools')
        .doc(widget.schoolId)
        .collection('exam_submissions')
        .doc(submissionDocId)
        .snapshots();
  }

  Future<void> _resolve() async {
    if (widget.candidates.length <= 1) return;

    final db = FirebaseFirestore.instance;
    ExamSession? found;

    for (final s in widget.candidates) {
      final doc = await db
          .collection('schools')
          .doc(widget.schoolId)
          .collection('exam_sessions')
          .doc(s.id)
          .collection('participations')
          .doc(widget.studentDocId)
          .get();
      if (doc.exists) {
        final roomName = doc.data()?['roomName']?.toString() ?? '';
        if (roomName.isNotEmpty) {
          found = s;
          break;
        }
      }
    }

    if (mounted && found != null) {
      setState(() {
        _resolvedSession = found;
        _initParticipationStream();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = _resolvedSession ?? widget.candidates.first;
    final isActive = session.isQrActive;
    final isToday = DateFormat('yyyy-MM-dd').format(session.date) == DateFormat('yyyy-MM-dd').format(DateTime.now());

    return StreamBuilder<ExamParticipation?>(
      stream: _participationStream,
      // Use cached data as initialData to avoid flicker
      initialData: _globalParticipationCache[_cacheKey],
      builder: (context, partSnap) {
        // During initial load: use cached data if available, otherwise show nothing
        if (partSnap.connectionState == ConnectionState.waiting &&
            partSnap.data == null) {
          return const SizedBox.shrink();
        }
        final participation = partSnap.data;
        // Update global cache with fresh data
        if (participation != null && _cacheKey.isNotEmpty) {
          _globalParticipationCache[_cacheKey] = participation;
        }
        if (participation == null || (participation.roomName ?? '').isEmpty) {
          return const SizedBox.shrink();
        }
        final roomName = participation.roomName ?? '';
        final seatNumber = participation.seatNumber;
        final hasScan = participation.scannedAt != null;

        Color accentColor = hasScan
            ? const Color(0xFF10B981)
            : (isActive ? const Color(0xFF8B5CF6) : const Color(0xFF64748B));

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            border: widget.isLastRow
                ? null
                : Border(bottom: BorderSide(color: widget.cardBorder)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Mata Pelajaran
              SizedBox(
                width: 150,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      session.subjectName,
                      style: TextStyle(
                        color: widget.titleColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        session.slotName,
                        style: TextStyle(
                          color: accentColor,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Waktu
              SizedBox(
                width: 90,
                child: Text(
                  '${session.startTime}\n${session.endTime}',
                  style: TextStyle(color: widget.subtitleColor, fontSize: 12),
                ),
              ),
              // Ruangan & Kursi
              SizedBox(
                width: 110,
                child: roomName.isEmpty
                    ? Text('-', style: TextStyle(color: widget.subtitleColor))
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('R: $roomName', style: TextStyle(color: widget.subtitleColor, fontSize: 11)),
                          if (seatNumber > 0)
                            Text(
                              'No. Ujian:\n${ExamUtils.buildExamNumber(
                                roomName: roomName,
                                seatNumber: seatNumber,
                                angkatan: _studentAngkatan ?? '',
                              )}',
                              style: TextStyle(
                                color: widget.subtitleColor,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                        ],
                      ),
              ),
              // Status
              SizedBox(
                width: 120,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: hasScan
                        ? const Color(0xFF10B981).withValues(alpha: 0.12)
                        : const Color(0xFF64748B).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
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
                        hasScan ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
                        size: 11,
                        color: hasScan ? const Color(0xFF10B981) : const Color(0xFF64748B),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        hasScan ? 'Sudah Scan' : 'Belum Scan',
                        style: TextStyle(
                          color: hasScan ? const Color(0xFF10B981) : const Color(0xFF64748B),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Aksi
              SizedBox(
                width: 130,
                child: Builder(
                  builder: (context) {
                    // Cek terlebih dahulu apakah waktu ujian sudah berakhir
                    bool isExamTimeOver = false;
                    final now = DateTime.now();
                    final todayDateStr = DateFormat('yyyy-MM-dd').format(now);
                    final sessionDateStr = DateFormat('yyyy-MM-dd').format(session.date);

                    if (session.examStatus == 'Finished') {
                      isExamTimeOver = true;
                    } else {
                      final cmp = sessionDateStr.compareTo(todayDateStr);
                      if (cmp < 0) {
                        isExamTimeOver = true;
                      } else if (cmp == 0) {
                        try {
                          final endParts = session.endTime.split(':');
                          final sessionEnd = DateTime(
                            now.year, now.month, now.day,
                            int.parse(endParts[0]), int.parse(endParts[1]),
                          );
                          isExamTimeOver = now.isAfter(sessionEnd);
                        } catch (_) {
                          isExamTimeOver = false;
                        }
                      }
                    }

                    if (isExamTimeOver && !hasScan) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.cancel_rounded, size: 12, color: Color(0xFFEF4444)),
                            const SizedBox(width: 4),
                            Text('Tidak Mengikuti Ujian', style: TextStyle(color: Color(0xFFEF4444), fontSize: 10, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      );
                    }

                    if (!hasScan) {
                      if (isToday && isActive) {
                        return const Text('Menunggu Scan', style: TextStyle(color: Color(0xFF8B5CF6), fontSize: 11, fontStyle: FontStyle.italic));
                      } else if (isToday && !isActive) {
                        return Text('Belum Mulai', style: TextStyle(color: widget.subtitleColor, fontSize: 11, fontStyle: FontStyle.italic));
                      }
                      return Text('Bukan Hari Ini', style: TextStyle(color: widget.subtitleColor, fontSize: 11, fontStyle: FontStyle.italic));
                    }

                    // ── Validasi waktu ujian ─────────────────────────────────────
                    // Waktu SELALU dicek — tidak ada bypass via examStatus.
                    // Tombol baru aktif ketika jam sekarang >= jam mulai sesi.
                    bool isExamTimeReached = false;
                    if (isToday) {
                      try {
                        final parts = session.startTime.split(':');
                        final now = DateTime.now();
                        final sessionStart = DateTime(
                          now.year, now.month, now.day,
                          int.parse(parts[0]), int.parse(parts[1]),
                        );
                        isExamTimeReached = !now.isBefore(sessionStart);
                      } catch (_) {
                        // Jika parse gagal, tolak akses (fail-safe)
                        isExamTimeReached = false;
                      }
                    }


                    if (!isExamTimeReached) {
                      // Sudah scan, tapi waktu ujian belum tiba
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: const Color(0xFFF59E0B).withValues(alpha: 0.35),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.access_time_rounded, size: 11, color: Color(0xFFF59E0B)),
                                const SizedBox(width: 4),
                                Text(
                                  'Mulai ${session.startTime}',
                                  style: const TextStyle(
                                    color: Color(0xFFF59E0B),
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 3),
                          const Text(
                            'Scan OK • Tunggu waktu',
                            style: TextStyle(
                              color: Color(0xFF10B981),
                              fontSize: 9,
                            ),
                          ),
                        ],
                      );
                    }
                    // ── Waktu sudah tiba, lanjut ke pengecekan soal ──────────
                    _initExamStream(session);
                    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                      stream: _examStream,
                      builder: (context, examSnap) {
                        if (examSnap.connectionState == ConnectionState.waiting) {
                          return const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2));
                        }
                        final doc = examSnap.data;
                        if (doc == null || !doc.exists || doc.data() == null) {
                          return const Text('Soal Belum Siap', style: TextStyle(color: Color(0xFFEF4444), fontSize: 11, fontWeight: FontWeight.bold));
                        }

                        final exam = Exam.fromFirestore(doc);

                        // Cocokkan soal langsung dengan angkatan murid tersebut
                        return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                          future: FirebaseFirestore.instance
                              .collection('schools')
                              .doc(widget.schoolId)
                              .collection('exam_questions')
                              .doc('${session.eventId}_${session.subjectId}_${_studentAngkatan ?? ""}')
                              .get(),
                          builder: (context, qSnap) {
                            List<ExamQuestion> finalQuestions = exam.questions;
                            bool finalShufflePg = exam.shufflePg;
                            bool finalShuffleEssay = exam.shuffleEssay;
                            
                            if (qSnap.hasData && qSnap.data!.exists && qSnap.data!.data() != null) {
                              final qData = qSnap.data!.data()!;
                              final qList = (qData['questions'] as List? ?? [])
                                  .map((q) => ExamQuestion.fromMap(Map<String, dynamic>.from(q)))
                                  .toList();
                              if (qList.isNotEmpty) {
                                finalQuestions = qList;
                                finalShufflePg = qData['shufflePg'] as bool? ?? false;
                                finalShuffleEssay = qData['shuffleEssay'] as bool? ?? false;
                              }
                            }

                            if (finalQuestions.isEmpty) {
                              return const Text('Soal Kosong', style: TextStyle(color: Color(0xFFF59E0B), fontSize: 11, fontWeight: FontWeight.bold));
                            }

                            final overriddenExam = exam.copyWith(
                              questions: finalQuestions,
                              shufflePg: finalShufflePg,
                              shuffleEssay: finalShuffleEssay,
                            );

                            _initSubmissionStream(overriddenExam.id);
                            return StreamBuilder<DocumentSnapshot>(
                              stream: _submissionStream,
                              builder: (context, subSnap) {
                                if (subSnap.connectionState == ConnectionState.waiting) {
                                  return const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2));
                                }
                                final isSubmitted = subSnap.data?.exists ?? false;

                                if (isSubmitted) {
                                  return Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF10B981).withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.check_circle_rounded, size: 12, color: Color(0xFF10B981)),
                                        SizedBox(width: 4),
                                        Text('Selesai', style: TextStyle(color: Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                  );
                                }

                                if (isExamTimeOver) {
                                  ExamService().checkAndAutoSubmitExpiredSemesterExam(
                                    schoolId: widget.schoolId,
                                    studentId: widget.studentDocId,
                                    studentName: widget.studentName,
                                    exam: overriddenExam,
                                    sessionId: session.id,
                                  );
                                  return Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.cancel_rounded, size: 12, color: Color(0xFFEF4444)),
                                        SizedBox(width: 4),
                                        Text('Tidak Mengikuti Ujian', style: TextStyle(color: Color(0xFFEF4444), fontSize: 10, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                  );
                                }

                                return ElevatedButton.icon(
                                  onPressed: () {
                                    // Set flag SEBELUM navigate agar lifecycle observer di dashboard
                                    // tidak sempat menulis ke behavior_records saat transisi route
                                    SessionService.isTakingExam = true;
                                    final cachedEvent = _globalEventCache[widget.studentDocId];
                                    Get.to(() => StudentTakeExamPage(
                                      exam: overriddenExam,
                                      studentDocId: widget.studentDocId,
                                      sessionId: session.id,
                                      schoolId: widget.schoolId,
                                      sessionStartTime: session.startTime,
                                      sessionEndTime: session.endTime,
                                      sessionDate: session.date,
                                      sessionExamStatus: session.examStatus,
                                      seatNumber: partSnap.data?.seatNumber,
                                      roomName: partSnap.data?.roomName ?? session.roomName,
                                      examType: cachedEvent?.examType,
                                    ));
                                  },
                                  icon: const Icon(Icons.play_arrow_rounded, size: 14),
                                  label: const Text('Mulai Ujian', style: TextStyle(fontSize: 10)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF10B981),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                                    minimumSize: const Size(0, 32),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                  ),
                                );
                              },
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

