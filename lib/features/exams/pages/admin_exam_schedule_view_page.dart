import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:sys_mng_school/core/localization/app_localization.dart';
import '../../../core/services/session_service.dart';
import '../../authentication/widgets/auth_background.dart';
import '../models/exam_event_model.dart';
import '../services/exam_session_service.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

// ─────────────────────────────────────────────────────────────
//  AdminExamScheduleViewPage — Kalender jadwal + manual override
// ─────────────────────────────────────────────────────────────
class AdminExamScheduleViewPage extends StatefulWidget {
  final String eventId;
  const AdminExamScheduleViewPage({super.key, required this.eventId});

  @override
  State<AdminExamScheduleViewPage> createState() =>
      _AdminExamScheduleViewPageState();
}

class _AdminExamScheduleViewPageState
    extends State<AdminExamScheduleViewPage> {
  final _service = ExamSessionService();
  DateTime? _selectedDate;
  List<ExamSession> _cachedSessions = [];
  ExamEvent? _cachedEvent;

  @override
  Widget build(BuildContext context) {
    final schoolId = SessionService.currentUser!.schoolId;

    return ValueListenableBuilder<bool>(
      valueListenable: AuthBackground.isDarkMode,
      builder: (context, isDark, _) {
        return ValueListenableBuilder<String>(
          valueListenable: AppLocalization.currentLocale,
          builder: (context, locale, _) {
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
            child: StreamBuilder<ExamEvent?>(
              stream: _service.getExamEventById(schoolId, widget.eventId),
              builder: (context, eventSnap) {
                final event = eventSnap.data;
                if (event != null && _cachedEvent?.id != event.id) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) setState(() => _cachedEvent = event);
                  });
                }

                return Column(
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
                                    event?.title ?? (AppLocalization.isIndonesian ? 'Jadwal Ujian' : 'Exam Schedules'),
                                    style: TextStyle(
                                        color: titleColor,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (event != null)
                                    Text(
                                      '${DateFormat('dd MMM', AppLocalization.isIndonesian ? 'id' : 'en').format(event.startDate)} – ${DateFormat('dd MMM yyyy', AppLocalization.isIndonesian ? 'id' : 'en').format(event.endDate)}',
                                      style: TextStyle(
                                          color: subtitleColor, fontSize: 12),
                                    ),
                                ],
                              ),
                            ),
                            // Rooms info chip
                            if (event != null && event.rooms.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF8B5CF6)
                                      .withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                      color: const Color(0xFF8B5CF6)
                                          .withValues(alpha: 0.3)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.meeting_room_rounded,
                                        size: 12,
                                        color: Color(0xFF8B5CF6)),
                                    const SizedBox(width: 4),
                                    Text(
                                      AppLocalization.isIndonesian ? '${event.rooms.length} Ruang' : '${event.rooms.length} Rooms',
                                      style: const TextStyle(
                                          color: Color(0xFF8B5CF6),
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                            if (event != null && event.subjectConfigs.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: () => _showAuthorsBottomSheet(context, event, isDark, cardColor, cardBorder, titleColor, subtitleColor),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10B981)
                                        .withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                        color: const Color(0xFF10B981)
                                            .withValues(alpha: 0.3)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.people_rounded,
                                          size: 12,
                                          color: Color(0xFF10B981)),
                                      const SizedBox(width: 4),
                                      Text(
                                        AppLocalization.isIndonesian ? 'Pembuat Soal' : 'Authors',
                                        style: const TextStyle(
                                            color: Color(0xFF10B981),
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                            // ── Print / Download button ──
                            if (event != null) ...[
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: () => _showPrintOptions(),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF6366F1)
                                        .withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                        color: const Color(0xFF6366F1)
                                            .withValues(alpha: 0.3)),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.print_rounded,
                                          size: 12,
                                          color: Color(0xFF6366F1)),
                                      SizedBox(width: 4),
                                      Text(
                                        'Cetak & Unduh',
                                        style: TextStyle(
                                            color: Color(0xFF6366F1),
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      child: StreamBuilder<List<ExamSession>>(
                        stream: _service.getSessionsByEvent(
                            schoolId, widget.eventId),
                        builder: (context, snap) {
                          if (snap.connectionState ==
                              ConnectionState.waiting) {
                            return Center(
                              child: CircularProgressIndicator(
                                color: isDark
                                    ? Colors.white
                                    : const Color(0xFF8B5CF6),
                              ),
                            );
                          }

                          final sessions = snap.data ?? [];
                          if (sessions.length != _cachedSessions.length) {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (mounted) setState(() => _cachedSessions = sessions);
                            });
                          }
                          if (sessions.isEmpty) {
                            return Center(
                              child: Text(
                                AppLocalization.isIndonesian ? 'Belum ada sesi ujian' : 'No exam sessions yet',
                                style: TextStyle(color: subtitleColor),
                              ),
                            );
                          }

                          // ─── Bungkus dengan StreamBuilder exam_questions ───
                          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                            stream: FirebaseFirestore.instance
                                .collection('schools')
                                .doc(schoolId)
                                .collection('exam_questions')
                                .where('eventId', isEqualTo: widget.eventId)
                                .snapshots(),
                            builder: (context, qSnap) {
                              // subjectId yang sudah punya soal (questions tidak kosong)
                              final Set<String> subjectsWithQuestions = {};
                              for (final doc in qSnap.data?.docs ?? []) {
                                final data = doc.data();
                                final qList = (data['questions'] as List?);
                                if (qList != null && qList.isNotEmpty) {
                                  final sid = data['subjectId'] as String? ?? '';
                                  final eid = data['eventId'] as String? ?? '';
                                  if (sid.isNotEmpty && (eid == widget.eventId || doc.id.startsWith('${widget.eventId}_'))) {
                                    subjectsWithQuestions.add(sid);
                                  }
                                }
                              }

                              // Kumpulkan unique subjectIds dalam event ini
                              final allSubjectIds = sessions.map((s) => s.subjectId).toSet();
                              final missingQuestionsSubjectIds = allSubjectIds
                                  .where((id) => !subjectsWithQuestions.contains(id))
                                  .toSet();

                          // Group by date
                          final Map<String, List<ExamSession>> grouped = {};
                          for (final s in sessions) {
                            final key = DateFormat('yyyy-MM-dd').format(s.date);
                            grouped.putIfAbsent(key, () => []).add(s);
                          }

                          final sortedDates = grouped.keys.toList()..sort();

                          // Filter jika ada tanggal dipilih
                          final displayDates = _selectedDate == null
                              ? sortedDates
                              : sortedDates
                                  .where((k) =>
                                      k ==
                                      DateFormat('yyyy-MM-dd')
                                          .format(_selectedDate!))
                                  .toList();

                          return CustomScrollView(
                            slivers: [
                              // Mini Calendar (date chips)
                              SliverToBoxAdapter(
                                child: _buildDateFilterStrip(
                                    sortedDates,
                                    isDark,
                                    titleColor,
                                    subtitleColor),
                              ),

                              // Stats Row
                              SliverToBoxAdapter(
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                      24, 8, 24, 4),
                                  child: _buildStatsRow(
                                      sessions, isDark, titleColor,
                                      subtitleColor,
                                      missingQuestionsSubjectIds: missingQuestionsSubjectIds),
                                ),
                              ),

                              // Session Groups
                              SliverList(
                                delegate: SliverChildBuilderDelegate(
                                  (_, i) {
                                    final dateKey = displayDates[i];
                                    final daySessions = grouped[dateKey]!;
                                    final date =
                                        DateFormat('yyyy-MM-dd').parse(dateKey);
                                    return _buildDayGroup(
                                      date,
                                      daySessions,
                                      isDark,
                                      cardColor,
                                      cardBorder,
                                      titleColor,
                                      subtitleColor,
                                      schoolId,
                                      event,
                                      missingQuestionsSubjectIds: missingQuestionsSubjectIds,
                                    );
                                  },
                                  childCount: displayDates.length,
                                ),
                              ),
                              const SliverToBoxAdapter(
                                  child: SizedBox(height: 40)),
                            ],
                          );
                            }, // end exam_questions builder
                          ); // end exam_questions StreamBuilder
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  },
);
  }


  void _showPrintOptions() {
    showDialog(
      context: context,
      builder: (context) {
        final isDark = AuthBackground.isDarkMode.value;
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E2D) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Pilih Format Cetak',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF1E1B4B),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close_rounded,
                          color: isDark ? Colors.white60 : Colors.grey.shade600),
                      onPressed: () => Navigator.pop(context),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _buildPrintOptionTile(
                  icon: Icons.assignment_ind_rounded,
                  title: 'Jadwal Pengawas (Per Ruangan)',
                  subtitle: 'Format jadwal untuk pengawas dengan info ruangan.',
                  onTap: () {
                    Navigator.pop(context);
                    _printSchedule();
                  },
                  isDark: isDark,
                ),
                const SizedBox(height: 8),
                _buildPrintOptionTile(
                  icon: Icons.class_rounded,
                  title: 'Jadwal Ujian (Per Kelas)',
                  subtitle: 'Format jadwal ujian untuk dibagikan ke murid.',
                  onTap: () {
                    Navigator.pop(context);
                    _printSchedulePerClass();
                  },
                  isDark: isDark,
                ),
                const SizedBox(height: 8),
                _buildPrintOptionTile(
                  icon: Icons.checklist_rtl_rounded,
                  title: 'Daftar Murid (Per-Ruangan)',
                  subtitle: 'Daftar absensi murid per ruangan untuk sesi ujian.',
                  onTap: () {
                    Navigator.pop(context);
                    _printRoomRoster();
                  },
                  isDark: isDark,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPrintOptionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(
            color: isDark ? Colors.white12 : Colors.grey.shade200,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: const Color(0xFF6366F1), size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: isDark ? Colors.white : const Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white54 : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                color: isDark ? Colors.white38 : Colors.grey.shade400),
          ],
        ),
      ),
    );
  }

  Future<void> _printSchedulePerClass() async {
    final sessions = _cachedSessions;
    final event = _cachedEvent;

    if (sessions.isEmpty || event == null) {
      Get.snackbar('Perhatian', 'Tidak ada sesi jadwal untuk dicetak.',
          backgroundColor: const Color(0xFFF59E0B), colorText: Colors.white);
      return;
    }

    final doc = pw.Document();

    const PdfColor accent    = PdfColor.fromInt(0xFF5C6BC0);
    const PdfColor rowEvenBg = PdfColor.fromInt(0xFFF8F9FA);
    const PdfColor border    = PdfColor.fromInt(0xFFDEE2E6);
    const double fontSize    = 8.0;

    // ── Group sessions strictly by individual className (split by comma) ──
    final Map<String, List<ExamSession>> byClass = {};
    for (final s in sessions) {
      final parts = s.className
          .split(',')
          .map((c) => c.trim())
          .where((c) => c.isNotEmpty)
          .toList();
      for (final cls in parts) {
        byClass.putIfAbsent(cls, () => []).add(s);
      }
    }

    final sortedClasses = byClass.keys.toList()..sort();

    for (final className in sortedClasses) {
      final classSessions = List<ExamSession>.from(byClass[className]!)
        ..sort((a, b) {
          final d = a.date.compareTo(b.date);
          return d != 0 ? d : a.startTime.compareTo(b.startTime);
        });

      // Group by date (yyyy-MM-dd)
      final Map<String, List<ExamSession>> byDate = {};
      for (final s in classSessions) {
        final k = DateFormat('yyyy-MM-dd').format(s.date);
        byDate.putIfAbsent(k, () => []).add(s);
      }
      final sortedDates = byDate.keys.toList()..sort();

      final List<pw.TableRow> tableRows = [];

      // Add Header Row
      tableRows.add(
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: accent),
          children: [
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              child: pw.Text('No',
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(
                      fontSize: fontSize,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.white)),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 8),
              child: pw.Text('Hari / Tanggal',
                  style: pw.TextStyle(
                      fontSize: fontSize,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.white)),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 8),
              child: pw.Text('Sesi & Waktu',
                  style: pw.TextStyle(
                      fontSize: fontSize,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.white)),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 8),
              child: pw.Text('Mata Pelajaran',
                  style: pw.TextStyle(
                      fontSize: fontSize,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.white)),
            ),
          ],
        ),
      );

      int dayNo = 0;
      for (final dateKey in sortedDates) {
        dayNo++;
        final daySessions = byDate[dateKey]!;
        final dateStr =
            DateFormat('EEEE, dd MMM yyyy', 'id').format(DateTime.parse(dateKey));
        final rowBg = dayNo.isEven ? rowEvenBg : PdfColors.white;

        // Build list of widgets for Sesi & Waktu and Mata Pelajaran
        final List<pw.Widget> slotWidgets = [];
        final List<pw.Widget> subjectWidgets = [];

        for (int si = 0; si < daySessions.length; si++) {
          final s = daySessions[si];
          final slotStr = '${s.slotName} (${s.startTime} - ${s.endTime})';

          slotWidgets.add(
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
              child: pw.Text(slotStr,
                  style: const pw.TextStyle(fontSize: fontSize, color: PdfColors.black)),
            ),
          );

          if (si < daySessions.length - 1) {
            slotWidgets.add(
              pw.Container(
                height: 0.5,
                color: border,
              ),
            );
          }

          subjectWidgets.add(
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
              child: pw.Text(s.subjectName,
                  style: pw.TextStyle(
                      fontSize: fontSize,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.black)),
            ),
          );

          if (si < daySessions.length - 1) {
            subjectWidgets.add(
              pw.Container(
                height: 0.5,
                color: border,
              ),
            );
          }
        }

        tableRows.add(
          pw.TableRow(
            decoration: pw.BoxDecoration(color: rowBg),
            verticalAlignment: pw.TableCellVerticalAlignment.middle,
            children: [
              // No
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                child: pw.Text('$dayNo',
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(fontSize: fontSize, color: PdfColors.grey800)),
              ),
              // Hari / Tanggal
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                child: pw.Text(dateStr,
                    style: const pw.TextStyle(fontSize: fontSize, color: PdfColors.black)),
              ),
              // Sesi & Waktu (stacked vertically)
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: slotWidgets,
              ),
              // Mata Pelajaran (stacked vertically)
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: subjectWidgets,
              ),
            ],
          ),
        );
      }

      final String capturedClass = className;
      final List<pw.TableRow> capturedTableRows = List.from(tableRows);

      doc.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          header: (_) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Center(
                  child: pw.Text('JADWAL UJIAN SEMESTER',
                      style: pw.TextStyle(
                          fontSize: 13, fontWeight: pw.FontWeight.bold))),
              pw.Center(
                  child: pw.Text(event.title,
                      style: pw.TextStyle(
                          fontSize: 10, fontWeight: pw.FontWeight.bold))),
              pw.SizedBox(height: 10),
              pw.Row(children: [
                pw.SizedBox(
                    width: 80,
                    child: pw.Text('Kelas',
                        style: const pw.TextStyle(fontSize: 9))),
                pw.Text(': $capturedClass',
                    style: pw.TextStyle(
                        fontSize: 9, fontWeight: pw.FontWeight.bold)),
              ]),
              pw.SizedBox(height: 10),
            ],
          ),
          footer: (ctx) => pw.Column(children: [
            pw.Divider(color: border, thickness: 0.5),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Dicetak: ${DateFormat('dd MMM yyyy, HH:mm', 'id').format(DateTime.now())}',
                  style: const pw.TextStyle(
                      fontSize: 6.5, color: PdfColors.grey500),
                ),
                pw.Text(
                  'Jadwal Ujian – $capturedClass  |  Hal ${ctx.pageNumber}',
                  style: const pw.TextStyle(
                      fontSize: 6.5, color: PdfColors.grey500),
                ),
              ],
            ),
          ]),
          build: (_) => [
            pw.Table(
              border: pw.TableBorder.all(color: border, width: 0.8),
              columnWidths: const {
                0: pw.FixedColumnWidth(28),
                1: pw.FlexColumnWidth(4),
                2: pw.FlexColumnWidth(4),
                3: pw.FlexColumnWidth(6),
              },
              children: capturedTableRows,
            ),
          ],
        ),
      );
    }

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => doc.save(),
      name: '${event.title.replaceAll(' ', '_')}_Jadwal_Per_Kelas.pdf',
    );
  }


  Future<void> _printRoomRoster() async {
    final sessions = _cachedSessions;
    final event = _cachedEvent;
    final schoolId = SessionService.currentUser?.schoolId;

    if (sessions.isEmpty || event == null || schoolId == null) {
      Get.snackbar(
        'Perhatian',
        'Tidak ada sesi jadwal atau data sekolah tidak ditemukan.',
        backgroundColor: const Color(0xFFF59E0B),
        colorText: Colors.white,
      );
      return;
    }

    // Show loading dialog
    Get.dialog(
      const Center(
        child: CircularProgressIndicator(
          color: Color(0xFF8B5CF6),
        ),
      ),
      barrierDismissible: false,
    );

    final doc = pw.Document();

    const PdfColor accentColor = PdfColor.fromInt(0xFF5C6BC0);
    const PdfColor rowEven = PdfColor.fromInt(0xFFF8F9FA);
    const PdfColor borderColor = PdfColor.fromInt(0xFFDEE2E6);
    const double fontSize = 8.0;

    final sortedRooms = event.rooms.map((r) => r.name).toList()..sort();
    final Map<String, Map<String, ExamParticipation>> studentsByRoom = {};
    
    for (final roomName in sortedRooms) {
      studentsByRoom[roomName] = {};
    }

    try {
      final db = FirebaseFirestore.instance;
      for (final s in sessions) {
        final partsSnap = await db
            .collection('schools')
            .doc(schoolId)
            .collection('exam_sessions')
            .doc(s.id)
            .collection('participations')
            .get();

        for (final docSnap in partsSnap.docs) {
          final p = ExamParticipation.fromFirestore(docSnap);
          if (studentsByRoom.containsKey(p.roomName)) {
            studentsByRoom[p.roomName]![p.studentId] = p;
          }
        }
      }
    } catch (e) {
      Get.back(); // close loading indicator
      Get.snackbar('Error', 'Gagal memuat data murid dari database: $e');
      return;
    }

    Get.back(); // close loading indicator after successful fetch

    for (final roomName in sortedRooms) {
      final roomStudents = studentsByRoom[roomName]!.values.toList()
        ..sort((a, b) => a.seatNumber.compareTo(b.seatNumber));
        
      if (roomStudents.isEmpty) continue;
      
      final List<pw.TableRow> tableRows = [];

      // Table Header Row
      tableRows.add(
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: accentColor),
          children: [
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              child: pw.Text('No Kursi',
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(
                      fontSize: fontSize,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.white)),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 8),
              child: pw.Text('Nomor Ujian',
                  style: pw.TextStyle(
                      fontSize: fontSize,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.white)),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 8),
              child: pw.Text('Nama Murid',
                  style: pw.TextStyle(
                      fontSize: fontSize,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.white)),
            ),
          ],
        ),
      );

      int rowIdx = 0;
      for (final student in roomStudents) {
        rowIdx++;
        final rowBg = rowIdx.isEven ? rowEven : PdfColors.white;
        final examNumber = ExamUtils.buildExamNumber(
          roomName: roomName,
          seatNumber: student.seatNumber,
          angkatan: student.angkatan,
        );
        
        tableRows.add(
          pw.TableRow(
            decoration: pw.BoxDecoration(color: rowBg),
            verticalAlignment: pw.TableCellVerticalAlignment.middle,
            children: [
              // No Kursi
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                child: pw.Text('${student.seatNumber}',
                    textAlign: pw.TextAlign.center,
                    style: const pw.TextStyle(fontSize: fontSize, color: PdfColors.grey800)),
              ),
              // Nomor Ujian
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                child: pw.Text(examNumber,
                    style: const pw.TextStyle(fontSize: fontSize, color: PdfColors.black)),
              ),
              // Nama Murid
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                child: pw.Text(student.studentName,
                    style: pw.TextStyle(
                        fontSize: fontSize,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.black)),
              ),
            ],
          ),
        );
      }

      final String capturedRoomName = roomName;
      final List<pw.TableRow> capturedTableRows = List.from(tableRows);

      doc.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          header: (_) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Center(
                child: pw.Text(
                  'DAFTAR MURID RUANG UJIAN',
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.Center(
                child: pw.Text(
                  event.title,
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(height: 16),
              pw.Row(
                children: [
                  pw.SizedBox(width: 80, child: pw.Text('Ruangan', style: const pw.TextStyle(fontSize: 9))),
                  pw.Text(': $capturedRoomName', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                ]
              ),
              pw.SizedBox(height: 12),
            ],
          ),
          footer: (ctx) => pw.Column(
            children: [
              pw.Divider(color: borderColor, thickness: 0.5),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Dicetak: ${DateFormat('dd MMM yyyy, HH:mm', 'id').format(DateTime.now())}',
                    style: const pw.TextStyle(
                        fontSize: 6.5, color: PdfColors.grey500),
                  ),
                  pw.Text(
                    'Daftar Murid – $capturedRoomName  |  Hal ${ctx.pageNumber}',
                    style: const pw.TextStyle(
                        fontSize: 6.5, color: PdfColors.grey500),
                  ),
                ],
              ),
            ],
          ),
          build: (_) => [
            pw.Table(
              border: pw.TableBorder.all(color: borderColor, width: 0.8),
              columnWidths: const {
                0: pw.FixedColumnWidth(55), // No Kursi width
                1: pw.FlexColumnWidth(4),
                2: pw.FlexColumnWidth(8),
              },
              children: capturedTableRows,
            ),
          ],
        ),
      );
    }

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => doc.save(),
      name: '${event.title.replaceAll(' ', '_')}_Daftar_Murid_Per_Ruangan.pdf',
    );
  }

  Future<void> _printSchedule() async {
    final sessions = _cachedSessions;
    final event = _cachedEvent;

    if (sessions.isEmpty) {
      Get.snackbar(
        'Perhatian',
        'Tidak ada sesi jadwal untuk dicetak.',
        backgroundColor: const Color(0xFFF59E0B),
        colorText: Colors.white,
      );
      return;
    }

    final doc = pw.Document();

    // Colour tokens
    const PdfColor accentColor   = PdfColor.fromInt(0xFF5C6BC0);
    const PdfColor slotBandColor = PdfColor.fromInt(0xFF7986CB);
    const PdfColor rowEven       = PdfColor.fromInt(0xFFF5F5FF);
    const PdfColor borderColor   = PdfColor.fromInt(0xFFBBBEE8);

    // Helper: header cell fixed width
    pw.Widget hdrFixed(String text, double w) => pw.Container(
          width: w,
          padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 7),
          color: accentColor,
          child: pw.Text(text,
              style: pw.TextStyle(
                  fontSize: 8,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white)),
        );

    // Helper: header cell flex
    pw.Widget hdrFlex(String text, int flex) => pw.Expanded(
          flex: flex,
          child: pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 7),
            color: accentColor,
            child: pw.Text(text,
                style: pw.TextStyle(
                    fontSize: 8,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white)),
          ),
        );

    // Group sessions by date
    final Map<String, List<ExamSession>> sessionsByDay = {};
    for (final s in sessions) {
      final dayStr = DateFormat('yyyy-MM-dd').format(s.date);
      sessionsByDay.putIfAbsent(dayStr, () => []).add(s);
    }
    final sortedDays = sessionsByDay.keys.toList()..sort();

    for (final dayStr in sortedDays) {
      final daySessions = sessionsByDay[dayStr]!;
      final parsedDate  = DateTime.parse(dayStr);

      // Group by slot
      final Map<String, List<ExamSession>> sessionsBySlot = {};
      for (final s in daySessions) {
        sessionsBySlot.putIfAbsent(s.slotName, () => []).add(s);
      }
      final sortedSlots = sessionsBySlot.keys.toList()..sort();

      // Build table row widgets
      int rowIdx = 0;
      final List<pw.Widget> tableRows = [];

      // Column header row
      tableRows.add(
        pw.Container(
          decoration: const pw.BoxDecoration(
            color: accentColor,
            border: pw.Border(
                bottom: pw.BorderSide(color: PdfColors.white, width: 1.5)),
          ),
          child: pw.Row(children: [
            hdrFixed('No', 22),
            hdrFixed('Ruangan', 54),
            hdrFlex('Kelas : Mata Pelajaran', 3),
            hdrFlex('Pengawas', 2),
          ]),
        ),
      );

      for (final slotName in sortedSlots) {
        final slotSessions = sessionsBySlot[slotName]!
          ..sort((a, b) => a.roomName.compareTo(b.roomName));

        final sample = slotSessions.first;
        final timeRange = '${sample.startTime} s.d. ${sample.endTime}';

        // Slot band row
        tableRows.add(
          pw.Container(
            color: slotBandColor,
            padding:
                const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            child: pw.Row(children: [
              pw.Text(
                '$slotName   |   $timeRange',
                style: pw.TextStyle(
                    fontSize: 7.5,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white),
              ),
            ]),
          ),
        );

        // Group by room
        final Map<String, List<ExamSession>> byRoom = {};
        for (final s in slotSessions) {
          byRoom.putIfAbsent(s.roomName, () => []).add(s);
        }
        final sortedRooms = byRoom.keys.toList()..sort();

        for (final roomName in sortedRooms) {
          rowIdx++;
          final roomSessions = byRoom[roomName]!;
          final sampleRoom   = roomSessions.first;
          final rowBg        = rowIdx.isEven ? rowEven : PdfColors.white;
          final hasProctor   = sampleRoom.proctorId.isNotEmpty;

          final subjectLines = roomSessions.map((s) {
            return '${s.className} : ${s.subjectName}';
          }).join('\n');

          tableRows.add(
            pw.Container(
              decoration: pw.BoxDecoration(
                color: rowBg,
                border: const pw.Border(
                    bottom: pw.BorderSide(color: borderColor, width: 0.4)),
              ),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // No
                  pw.Container(
                    width: 22,
                    padding: const pw.EdgeInsets.symmetric(
                        horizontal: 4, vertical: 7),
                    color: rowBg,
                    child: pw.Text('$rowIdx',
                        textAlign: pw.TextAlign.center,
                        style: const pw.TextStyle(
                            fontSize: 7, color: PdfColors.grey600)),
                  ),
                  // Room
                  pw.Container(
                    width: 54,
                    padding: const pw.EdgeInsets.symmetric(
                        horizontal: 6, vertical: 7),
                    color: rowBg,
                    child: pw.Text(roomName,
                        style: pw.TextStyle(
                            fontSize: 8,
                            fontWeight: pw.FontWeight.bold,
                            color: const PdfColor.fromInt(0xFF3949AB))),
                  ),
                  // Subject / class
                  pw.Expanded(
                    flex: 3,
                    child: pw.Container(
                      padding: const pw.EdgeInsets.symmetric(
                          horizontal: 6, vertical: 7),
                      color: rowBg,
                      child: pw.Text(subjectLines,
                          style: const pw.TextStyle(fontSize: 7.5)),
                    ),
                  ),
                  // Proctor
                  pw.Expanded(
                    flex: 2,
                    child: pw.Container(
                      padding: const pw.EdgeInsets.symmetric(
                          horizontal: 6, vertical: 7),
                      color: hasProctor
                          ? rowBg
                          : const PdfColor.fromInt(0xFFFFF8E1),
                      child: pw.Text(
                        hasProctor
                            ? sampleRoom.proctorName
                            : 'Belum ditugaskan',
                        style: pw.TextStyle(
                          fontSize: 7.5,
                          color: hasProctor
                              ? const PdfColor.fromInt(0xFF1B5E20)
                              : const PdfColor.fromInt(0xFFB45309),
                          fontStyle: hasProctor
                              ? pw.FontStyle.normal
                              : pw.FontStyle.italic,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }
      }

      // Build the page
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          build: (pw.Context ctx) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [

                // ── Branded header ─────────────────────────────────
                pw.Container(
                  decoration: const pw.BoxDecoration(
                    color: accentColor,
                    borderRadius: pw.BorderRadius.all(pw.Radius.circular(6)),
                  ),
                  padding: const pw.EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      // Left: title block
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              'JADWAL PELAKSANAAN UJIAN',
                              style: pw.TextStyle(
                                fontSize: 8,
                                fontWeight: pw.FontWeight.bold,
                                color: const PdfColor.fromInt(0xB3FFFFFF),
                                letterSpacing: 1.5,
                              ),
                            ),
                            pw.SizedBox(height: 4),
                            pw.Text(
                              event?.title ?? 'Jadwal Ujian',
                              style: pw.TextStyle(
                                fontSize: 18,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.white,
                              ),
                            ),
                            if (event != null) ...[
                              pw.SizedBox(height: 3),
                              pw.Text(
                                '${DateFormat('dd MMM yyyy', 'id').format(event.startDate)} s.d. ${DateFormat('dd MMM yyyy', 'id').format(event.endDate)}',
                                style: const pw.TextStyle(
                                    fontSize: 8, color: const PdfColor.fromInt(0xB3FFFFFF)),
                              ),
                            ],
                          ],
                        ),
                      ),
                      pw.SizedBox(width: 10),
                      // Right: day badge
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: const pw.BoxDecoration(
                          color: PdfColors.white,
                          borderRadius:
                              pw.BorderRadius.all(pw.Radius.circular(6)),
                        ),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.center,
                          children: [
                            pw.Text(
                              DateFormat('EEEE', 'id')
                                  .format(parsedDate)
                                  .toUpperCase(),
                              style: pw.TextStyle(
                                fontSize: 7,
                                fontWeight: pw.FontWeight.bold,
                                color: accentColor,
                                letterSpacing: 1,
                              ),
                            ),
                            pw.Text(
                              DateFormat('dd', 'id').format(parsedDate),
                              style: pw.TextStyle(
                                fontSize: 24,
                                fontWeight: pw.FontWeight.bold,
                                color: accentColor,
                              ),
                            ),
                            pw.Text(
                              DateFormat('MMMM yyyy', 'id').format(parsedDate),
                              style:
                                  pw.TextStyle(fontSize: 7, color: accentColor),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                pw.SizedBox(height: 14),

                // ── Table ──────────────────────────────────────────
                pw.Container(
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: borderColor, width: 0.8),
                    borderRadius:
                        const pw.BorderRadius.all(pw.Radius.circular(4)),
                  ),
                  child: pw.Column(children: tableRows),
                ),

                pw.Spacer(),

                // ── Signature ──────────────────────────────────────
                pw.Align(
                  alignment: pw.Alignment.centerRight,
                  child: pw.SizedBox(
                    width: 180,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        pw.Text('Mengetahui,',
                            style: const pw.TextStyle(fontSize: 8)),
                        pw.Text('Kepala Sekolah',
                            style: pw.TextStyle(
                                fontSize: 8,
                                fontWeight: pw.FontWeight.bold)),
                        pw.SizedBox(height: 44),
                        pw.Container(height: 0.5, color: PdfColors.grey500),
                        pw.SizedBox(height: 3),
                        pw.Text('(................................)',
                            style: const pw.TextStyle(fontSize: 8)),
                      ],
                    ),
                  ),
                ),

                pw.SizedBox(height: 10),

                // ── Footer ─────────────────────────────────────────
                pw.Divider(color: borderColor, thickness: 0.5),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'Dicetak: ${DateFormat('dd MMM yyyy, HH:mm', 'id').format(DateTime.now())}',
                      style: const pw.TextStyle(
                          fontSize: 6.5, color: PdfColors.grey500),
                    ),
                    pw.Text(
                      'Hal ${sortedDays.indexOf(dayStr) + 1} dari ${sortedDays.length}',
                      style: const pw.TextStyle(
                          fontSize: 6.5, color: PdfColors.grey500),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      );
    }

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => doc.save(),
      name: '${(event?.title ?? 'Jadwal_Ujian').replaceAll(' ', '_')}.pdf',
    );
  }

  Widget _buildDateFilterStrip(
    List<String> sortedDates,
    bool isDark,
    Color titleColor,
    Color subtitleColor,
  ) {
    return SizedBox(
      height: 72,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
        itemCount: sortedDates.length + 1,
        itemBuilder: (_, i) {
          if (i == 0) {
            final isSelected = _selectedDate == null;
            return GestureDetector(
              onTap: () => setState(() => _selectedDate = null),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFF8B5CF6)
                      : isDark
                          ? Colors.white.withValues(alpha: 0.06)
                          : Colors.black.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFF8B5CF6)
                        : Colors.transparent,
                  ),
                ),
                child: Center(
                  child: Text(
                    'Semua',
                    style: TextStyle(
                      color: isSelected ? Colors.white : subtitleColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            );
          }

          final date = DateFormat('yyyy-MM-dd').parse(sortedDates[i - 1]);
          final isSelected = _selectedDate != null &&
              DateFormat('yyyy-MM-dd').format(_selectedDate!) ==
                  sortedDates[i - 1];

          return GestureDetector(
            onTap: () => setState(() => _selectedDate = date),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFF8B5CF6)
                    : isDark
                        ? Colors.white.withValues(alpha: 0.06)
                        : Colors.black.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFF8B5CF6)
                      : Colors.transparent,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    DateFormat('EEE', AppLocalization.isIndonesian ? 'id' : 'en').format(date),
                    style: TextStyle(
                      color: isSelected ? Colors.white70 : subtitleColor,
                      fontSize: 10,
                    ),
                  ),
                  Text(
                    DateFormat('dd').format(date),
                    style: TextStyle(
                      color: isSelected ? Colors.white : titleColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatsRow(
    List<ExamSession> sessions,
    bool isDark,
    Color titleColor,
    Color subtitleColor, {
    Set<String> missingQuestionsSubjectIds = const {},
  }) {
    final unassigned = sessions.where((s) => s.proctorId.isEmpty).length;
    final noRoom = sessions.where((s) => s.roomName.isEmpty || s.roomName == '-').length;
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: [
        _buildStatPill(
            AppLocalization.isIndonesian ? '${sessions.length} Sesi Total' : '${sessions.length} Sessions Total', Icons.event_rounded,
            const Color(0xFF8B5CF6), isDark),
        _buildStatPill(
            AppLocalization.isIndonesian ? '${sessions.length - unassigned} Terassign' : '${sessions.length - unassigned} Assigned',
            Icons.person_rounded, const Color(0xFF10B981), isDark),
        if (unassigned > 0)
          _buildStatPill(
              AppLocalization.isIndonesian ? '$unassigned Tanpa Pengawas' : '$unassigned No Proctor',
              Icons.warning_amber_rounded,
              const Color(0xFFF59E0B),
              isDark),
        if (noRoom > 0)
          _buildStatPill(
              AppLocalization.isIndonesian ? '$noRoom Tanpa Ruang' : '$noRoom No Room',
              Icons.meeting_room_outlined,
              const Color(0xFFEF4444),
              isDark),
        if (missingQuestionsSubjectIds.isNotEmpty)
          _buildStatPill(
              AppLocalization.isIndonesian
                  ? '${missingQuestionsSubjectIds.length} Soal Belum Ada'
                  : '${missingQuestionsSubjectIds.length} No Questions',
              Icons.quiz_outlined,
              const Color(0xFFEF4444),
              isDark),
      ],
    );
  }

  Widget _buildStatPill(
      String label, IconData icon, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  color: color, fontSize: 11, fontWeight: FontWeight.bold)),
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
    ExamEvent? event, {
    Set<String> missingQuestionsSubjectIds = const {},
  }) {
    // Group sessions of this day by slotName
    final Map<String, List<ExamSession>> sessionsBySlot = {};
    for (final s in sessions) {
      sessionsBySlot.putIfAbsent(s.slotName, () => []).add(s);
    }

    final sortedSlotNames = sessionsBySlot.keys.toList()..sort();

    final Color headerBg = isDark
        ? const Color(0xFF1E1B4B)
        : const Color(0xFF6366F1).withValues(alpha: 0.07);
    final Color headerText = isDark ? Colors.white70 : const Color(0xFF6366F1);

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Day Header
          Row(
            children: [
              Container(
                width: 4,
                height: 16,
                decoration: BoxDecoration(
                  color: const Color(0xFF8B5CF6),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                DateFormat('EEEE, dd MMMM yyyy', AppLocalization.isIndonesian ? 'id' : 'en').format(date),
                style: TextStyle(
                    color: titleColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Table Card
          LayoutBuilder(
            builder: (context, constraints) {
              const double minWidth = 550;
              final double tableWidth = constraints.maxWidth > minWidth ? constraints.maxWidth : minWidth;

              return Container(
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: cardBorder),
                  boxShadow: [
                    BoxShadow(
                      color: isDark ? Colors.black26 : Colors.black.withValues(alpha: 0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: tableWidth,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Table header row
                        Container(
                          color: headerBg,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 75,
                                child: Text(AppLocalization.isIndonesian ? 'Ruangan' : 'Room', style: TextStyle(color: headerText, fontSize: 10, fontWeight: FontWeight.bold)),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 4,
                                child: Text(AppLocalization.isIndonesian ? 'Mata Pelajaran' : 'Subject', style: TextStyle(color: headerText, fontSize: 10, fontWeight: FontWeight.bold)),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 3,
                                child: Text(AppLocalization.isIndonesian ? 'Pengawas' : 'Proctor', style: TextStyle(color: headerText, fontSize: 10, fontWeight: FontWeight.bold)),
                              ),
                              const SizedBox(width: 8),
                              SizedBox(
                                width: 50,
                                child: Text(AppLocalization.isIndonesian ? 'Aksi' : 'Action', style: TextStyle(color: headerText, fontSize: 10, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                              ),
                            ],
                          ),
                        ),

                        // Slots & Data rows
                        ...sortedSlotNames.expand((slotName) {
                          final slotSessions = sessionsBySlot[slotName]!
                            ..sort((a, b) => a.roomName.compareTo(b.roomName));
                          final sampleSession = slotSessions.first;

                          return [
                            // Slot separator band
                            Container(
                              color: isDark
                                  ? const Color(0xFF8B5CF6).withValues(alpha: 0.06)
                                  : const Color(0xFF8B5CF6).withValues(alpha: 0.04),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              child: Row(
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Color(0xFF8B5CF6),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    slotName,
                                    style: const TextStyle(
                                      color: Color(0xFF8B5CF6),
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '(${sampleSession.startTime} – ${sampleSession.endTime})',
                                    style: TextStyle(
                                      color: isDark ? Colors.white38 : Colors.black38,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Rows for each session
                            ...slotSessions.map((s) {
                              final hasProctor = s.proctorId.isNotEmpty;
                              final hasRoom = s.roomName.isNotEmpty && s.roomName != '-';

                              return Container(
                                decoration: BoxDecoration(
                                  border: Border(
                                    bottom: BorderSide(color: cardBorder, width: 0.5),
                                  ),
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    // Room column (badge, clickable to view seat map if room is set)
                                    SizedBox(
                                      width: 75,
                                      child: hasRoom
                                          ? InkWell(
                                              onTap: () => Get.to(() => AdminRoomSeatingPage(
                                                    schoolId: schoolId,
                                                    session: s,
                                                  )),
                                              borderRadius: BorderRadius.circular(6),
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFF6366F1).withValues(alpha: 0.08),
                                                  borderRadius: BorderRadius.circular(6),
                                                  border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.2)),
                                                ),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  children: [
                                                    const Icon(Icons.grid_on_rounded, size: 10, color: Color(0xFF6366F1)),
                                                    const SizedBox(width: 3),
                                                    Expanded(
                                                      child: Text(
                                                        s.roomName,
                                                        style: const TextStyle(
                                                          color: Color(0xFF6366F1),
                                                          fontSize: 10,
                                                          fontWeight: FontWeight.bold,
                                                        ),
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            )
                                          : Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFEF4444).withValues(alpha: 0.08),
                                                borderRadius: BorderRadius.circular(6),
                                                border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.2)),
                                              ),
                                              child: Center(
                                                child: Text(
                                                  AppLocalization.isIndonesian ? 'Belum ada' : 'None yet',
                                                  style: const TextStyle(
                                                    color: Color(0xFFEF4444),
                                                    fontSize: 9,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            ),
                                    ),
                                    const SizedBox(width: 8),

                                    // Subject column
                                    Expanded(
                                      flex: 4,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            s.subjectName,
                                            style: TextStyle(
                                              color: titleColor,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 2),
                                          (() {
                                            final matches = event?.subjectConfigs.where((c) => c.subjectId == s.subjectId);
                                            final config = matches != null && matches.isNotEmpty ? matches.first : null;
                                            final authorNames = config?.authorTeacherNames.isNotEmpty == true
                                                ? config!.authorTeacherNames.join(', ')
                                                : (AppLocalization.isIndonesian ? 'Belum ditentukan' : 'Not assigned');
                                            return Text(
                                              '${AppLocalization.isIndonesian ? 'Pembuat' : 'Author'}: $authorNames',
                                              style: TextStyle(
                                                color: subtitleColor.withValues(alpha: 0.8),
                                                fontSize: 9,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            );
                                          })(),
                                          // ── Badge soal belum ada ──────────────────
                                          if (missingQuestionsSubjectIds.contains(s.subjectId))
                                            Padding(
                                              padding: const EdgeInsets.only(top: 4),
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFEF4444).withValues(alpha: 0.10),
                                                  borderRadius: BorderRadius.circular(6),
                                                  border: Border.all(
                                                    color: const Color(0xFFEF4444).withValues(alpha: 0.35),
                                                  ),
                                                ),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    const Icon(
                                                      Icons.warning_rounded,
                                                      size: 9,
                                                      color: Color(0xFFEF4444),
                                                    ),
                                                    const SizedBox(width: 3),
                                                    Text(
                                                      AppLocalization.isIndonesian
                                                          ? 'Soal Belum Dibuat'
                                                          : 'No Questions Yet',
                                                      style: const TextStyle(
                                                        color: Color(0xFFEF4444),
                                                        fontSize: 8,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),

                                    // Proctor column
                                    Expanded(
                                      flex: 3,
                                      child: Text(
                                        hasProctor ? s.proctorName : (AppLocalization.isIndonesian ? 'Belum ada pengawas' : 'No proctor yet'),
                                        style: TextStyle(
                                          color: hasProctor
                                              ? const Color(0xFF10B981)
                                              : const Color(0xFFF59E0B),
                                          fontSize: 11,
                                          fontStyle: hasProctor ? FontStyle.normal : FontStyle.italic,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 8),

                                    // Action column
                                    SizedBox(
                                      width: 50,
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          // Override Proctor
                                          IconButton(
                                            icon: const Icon(Icons.person_search_rounded, size: 16),
                                            color: const Color(0xFF8B5CF6).withValues(alpha: 0.7),
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(),
                                            onPressed: () => _showOverrideProctorDialog(
                                                s, isDark, titleColor, subtitleColor, schoolId),
                                            tooltip: 'Override Pengawas',
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ];
                        }),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ── Dialog: Override Pengawas ────────────────────────────────
  Future<void> _showOverrideProctorDialog(
    ExamSession session,
    bool isDark,
    Color titleColor,
    Color subtitleColor,
    String schoolId,
  ) async {
    final teachers = await FirebaseFirestore.instance
        .collection('schools')
        .doc(schoolId)
        .collection('teachers')
        .where('aktif', isEqualTo: true)
        .get();

    if (!mounted) return;

    String? selectedId = session.proctorId.isEmpty ? null : session.proctorId;
    String? selectedName =
        session.proctorName.isEmpty ? null : session.proctorName;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Container(
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A1730) : Colors.white,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Override Pengawas',
                  style: TextStyle(
                      color: titleColor,
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('${session.subjectName} • ${session.slotName}',
                  style: TextStyle(color: subtitleColor, fontSize: 13)),
              const SizedBox(height: 20),
              Expanded(
                child: ListView.builder(
                  itemCount: teachers.docs.length,
                  itemBuilder: (_, i) {
                    final doc = teachers.docs[i];
                    final data = doc.data();

                    final teacherName = data['nama'] ?? '';
                    final isAuthor = session.authorTeacherId.split(',').contains(doc.id);
                    final isSelected = doc.id == selectedId;

                    return ListTile(
                      dense: true,
                      enabled: !isAuthor,
                      title: Text(
                        teacherName,
                        style: TextStyle(
                          color: isAuthor
                              ? subtitleColor.withValues(alpha: 0.4)
                              : titleColor,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                      subtitle: isAuthor
                          ? Text(
                              'Pembuat Soal — tidak dapat ditugaskan',
                              style: TextStyle(
                                  color: const Color(0xFFEF4444)
                                      .withValues(alpha: 0.7),
                                  fontSize: 11))
                          : null,
                      leading: CircleAvatar(
                        radius: 16,
                        backgroundColor: isSelected
                            ? const Color(0xFF8B5CF6)
                            : isDark
                                ? Colors.white.withValues(alpha: 0.1)
                                : Colors.black.withValues(alpha: 0.05),
                        child: isSelected
                            ? const Icon(Icons.check,
                                size: 14, color: Colors.white)
                            : Icon(Icons.person_rounded,
                                size: 14, color: subtitleColor),
                      ),
                      onTap: isAuthor
                          ? null
                          : () {
                              setModalState(() {
                                selectedId = doc.id;
                                selectedName = teacherName;
                              });
                            },
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: selectedId == null
                    ? null
                    : () async {
                        await _service.updateSessionProctor(
                          schoolId: schoolId,
                          sessionId: session.id,
                          newProctorId: selectedId!,
                          newProctorName: selectedName!,
                        );
                        if (ctx.mounted) Navigator.pop(ctx);
                        Get.snackbar(
                          'Berhasil',
                          'Pengawas diperbarui: $selectedName',
                          backgroundColor: const Color(0xFF10B981),
                          colorText: Colors.white,
                          snackPosition: SnackPosition.TOP,
                          margin: const EdgeInsets.all(16),
                        );
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8B5CF6),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Simpan Perubahan',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Dialog: Atur Ruang & Kursi Selang-Seling ────────────────
  Future<void> _showRoomSeatingDialog(
    ExamSession session,
    bool isDark,
    Color titleColor,
    Color subtitleColor,
    String schoolId,
    ExamEvent? event,
  ) async {
    final availableRooms = event?.rooms ?? [];
    if (availableRooms.isEmpty) {
      Get.snackbar(
        'Tidak Ada Ruangan',
        'Event ini belum memiliki konfigurasi ruangan. Buat ulang event melalui wizard.',
        backgroundColor: const Color(0xFFF59E0B),
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
        margin: const EdgeInsets.all(16),
      );
      return;
    }

    // Pre-select rooms already assigned to this session
    final currentRoomNames = session.roomName
        .split(',')
        .map((r) => r.trim())
        .where((r) => r.isNotEmpty)
        .toSet();
    final Set<String> selectedRoomNames = Set.from(
      availableRooms
          .where((r) => currentRoomNames.contains(r.name))
          .map((r) => r.name),
    );
    if (selectedRoomNames.isEmpty && availableRooms.isNotEmpty) {
      selectedRoomNames.add(availableRooms.first.name);
    }

    bool isGenerating = false;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final selectedRooms = availableRooms
              .where((r) => selectedRoomNames.contains(r.name))
              .toList();
          final totalCapacity =
              selectedRooms.fold<int>(0, (sum, r) => sum + r.capacity);

          return Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1A1730) : Colors.white,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: EdgeInsets.fromLTRB(
                24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.chair_alt_rounded,
                          color: Color(0xFF8B5CF6), size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Atur Ruang & Kursi',
                              style: TextStyle(
                                  color: titleColor,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold)),
                          Text(
                              '${session.subjectName} • ${session.className.isEmpty ? session.classId : session.className}',
                              style: TextStyle(
                                  color: subtitleColor, fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Info box
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3B82F6).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color:
                            const Color(0xFF3B82F6).withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline_rounded,
                          color: Color(0xFF3B82F6), size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Pilih ruangan untuk sesi ini. Siswa 2 angkatan berbeda akan diinterleave (selang-seling) berdasarkan nomor kursi ganjil/genap.',
                          style: TextStyle(
                              color: const Color(0xFF3B82F6)
                                  .withValues(alpha: 0.9),
                              fontSize: 11,
                              height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Room list
                Text('Pilih Ruangan:',
                    style: TextStyle(
                        color: titleColor,
                        fontSize: 13,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                ...availableRooms.map((room) {
                  final isChecked = selectedRoomNames.contains(room.name);
                  return CheckboxListTile(
                    dense: true,
                    value: isChecked,
                    title: Text(room.name,
                        style: TextStyle(color: titleColor, fontSize: 13)),
                    subtitle: Text('Kapasitas: ${room.capacity} kursi',
                        style: TextStyle(
                            color: subtitleColor, fontSize: 11)),
                    activeColor: const Color(0xFF8B5CF6),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    onChanged: (val) {
                      setModalState(() {
                        if (val == true) {
                          selectedRoomNames.add(room.name);
                        } else {
                          selectedRoomNames.remove(room.name);
                        }
                      });
                    },
                  );
                }),
                const SizedBox(height: 8),

                // Total capacity info
                if (selectedRooms.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: const Color(0xFF10B981)
                              .withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.event_seat_rounded,
                            color: Color(0xFF10B981), size: 14),
                        const SizedBox(width: 8),
                        Text(
                          'Total kapasitas: $totalCapacity kursi di ${selectedRooms.length} ruangan',
                          style: const TextStyle(
                              color: Color(0xFF10B981),
                              fontSize: 12,
                              fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 16),

                // Generate button
                ElevatedButton.icon(
                  onPressed: (selectedRoomNames.isEmpty || isGenerating)
                      ? null
                      : () async {
                          setModalState(() => isGenerating = true);
                          try {
                            await _service.distributeSeatsForExistingSession(
                              schoolId: schoolId,
                              sessionId: session.id,
                              classId: session.classId,
                              rooms: selectedRooms,
                            );
                            if (ctx.mounted) Navigator.pop(ctx);
                            Get.snackbar(
                              'Berhasil!',
                              'Tempat duduk selang-seling berhasil digenerate untuk ${session.subjectName}',
                              backgroundColor: const Color(0xFF10B981),
                              colorText: Colors.white,
                              snackPosition: SnackPosition.TOP,
                              margin: const EdgeInsets.all(16),
                              duration: const Duration(seconds: 3),
                            );
                          } catch (e) {
                            setModalState(() => isGenerating = false);
                            Get.snackbar(
                              'Gagal',
                              'Error: $e',
                              backgroundColor: const Color(0xFFEF4444),
                              colorText: Colors.white,
                              snackPosition: SnackPosition.TOP,
                              margin: const EdgeInsets.all(16),
                            );
                          }
                        },
                  icon: isGenerating
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.shuffle_rounded, size: 16),
                  label: Text(isGenerating
                      ? 'Membuat Denah...'
                      : 'Generate Tempat Duduk Selang-Seling'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8B5CF6),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    textStyle: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  AdminRoomSeatingPage — Denah Tempat Duduk (Admin / TU view)
// ─────────────────────────────────────────────────────────────
class AdminRoomSeatingPage extends StatelessWidget {
  final String schoolId;
  final ExamSession session;

  const AdminRoomSeatingPage({
    super.key,
    required this.schoolId,
    required this.session,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AuthBackground.isDarkMode.value;
    final titleColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
    final subtitleColor = isDark
        ? Colors.white.withValues(alpha: 0.6)
        : const Color(0xFF1E1B4B).withValues(alpha: 0.6);

    final service = ExamSessionService();

    return ValueListenableBuilder<bool>(
      valueListenable: AuthBackground.isDarkMode,
      builder: (context, isDarkMode, _) {
        final tColor = isDarkMode ? Colors.white : const Color(0xFF1E1B4B);
        final sColor = isDarkMode
            ? Colors.white.withValues(alpha: 0.6)
            : const Color(0xFF1E1B4B).withValues(alpha: 0.6);

        return Scaffold(
          body: AuthBackground(
            child: Scaffold(
              backgroundColor: Colors.transparent,
              appBar: AppBar(
                title: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Denah Kursi',
                      style: TextStyle(
                          color: tColor,
                          fontSize: 16,
                          fontWeight: FontWeight.bold),
                    ),
                    Text(
                      session.subjectName,
                      style: TextStyle(color: sColor, fontSize: 11),
                    ),
                  ],
                ),
                backgroundColor: Colors.transparent,
                elevation: 0,
                leading: IconButton(
                  icon: Icon(Icons.arrow_back_rounded, color: tColor),
                  onPressed: () => Get.back(),
                ),
              ),
              body: StreamBuilder<List<ExamParticipation>>(
            stream: service.getParticipations(
                schoolId: schoolId, sessionId: session.id),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final participations = snap.data ?? [];
              if (participations.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(40),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chair_alt_outlined,
                            size: 64, color: sColor.withValues(alpha: 0.3)),
                        const SizedBox(height: 16),
                        Text(
                          'Belum Ada Distribusi Kursi',
                          style: TextStyle(
                              color: tColor,
                              fontSize: 16,
                              fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Gunakan tombol "Atur Ruang & Kursi" di halaman jadwal untuk generate tempat duduk.',
                          style: TextStyle(
                              color: sColor, fontSize: 13, height: 1.5),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                );
              }

              // Sort by seatNumber
              participations.sort(
                  (a, b) => a.seatNumber.compareTo(b.seatNumber));

              // Group by room
              final Map<String, List<ExamParticipation>> byRoom = {};
              for (final p in participations) {
                byRoom.putIfAbsent(p.roomName, () => []).add(p);
              }
              final sortedRooms = byRoom.keys.toList()..sort();

              // Get unique angkatans for color
              final angkatans =
                  participations.map((p) => p.angkatan).toSet().toList()
                    ..sort();

              Color getCohortColor(String angkatan) {
                final index = angkatans.indexOf(angkatan);
                if (index == 0) return const Color(0xFF8B5CF6);
                if (index == 1) return const Color(0xFF10B981);
                if (index == 2) return const Color(0xFFF59E0B);
                return const Color(0xFF3B82F6);
              }

              // Stats
              final present =
                  participations.where((p) => p.scannedAt != null).length;
              final total = participations.length;

              return Column(
                children: [
                  // Stats & Legend banner
                  Container(
                    margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDarkMode
                          ? Colors.white.withValues(alpha: 0.05)
                          : Colors.black.withValues(alpha: 0.03),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      children: [
                        // Attendance stats
                        Row(
                          children: [
                            _statChip('$total Siswa',
                                Icons.people_rounded, const Color(0xFF8B5CF6)),
                            const SizedBox(width: 8),
                            _statChip('$present Hadir',
                                Icons.check_circle_rounded, const Color(0xFF10B981)),
                            const SizedBox(width: 8),
                            _statChip('${total - present} Absen',
                                Icons.radio_button_unchecked_rounded,
                                const Color(0xFFEF4444)),
                          ],
                        ),
                        const SizedBox(height: 10),
                        // Legend per angkatan
                        Wrap(
                          spacing: 12,
                          runSpacing: 6,
                          children: angkatans.map((a) {
                            final color = getCohortColor(a);
                            return Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color: color,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Angkatan $a',
                                  style: TextStyle(
                                      color: sColor, fontSize: 11),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Room tabs / sections
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                      itemCount: sortedRooms.length,
                      itemBuilder: (_, roomIdx) {
                        final roomName = sortedRooms[roomIdx];
                        final roomParticipants = byRoom[roomName]!;

                        final maxSeat = roomParticipants
                            .map((p) => p.seatNumber)
                            .fold(0, (max, e) => e > max ? e : max);
                        const columns = 4;
                        final rows = (maxSeat / columns).ceil();
                        final seatMap = {
                          for (var p in roomParticipants) p.seatNumber: p
                        };

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Room header
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 12),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 5),
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(colors: [
                                        Color(0xFF8B5CF6),
                                        Color(0xFF6D28D9),
                                      ]),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                            Icons.meeting_room_rounded,
                                            size: 13,
                                            color: Colors.white),
                                        const SizedBox(width: 5),
                                        Text(
                                          roomName,
                                          style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${roomParticipants.length} siswa',
                                    style: TextStyle(
                                        color: sColor, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),

                            // Papan tulis
                            Container(
                              width: double.infinity,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 6),
                              decoration: BoxDecoration(
                                color: isDarkMode
                                    ? Colors.white.withValues(alpha: 0.06)
                                    : Colors.black.withValues(alpha: 0.04),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Center(
                                child: Text(
                                  'PAPAN TULIS / MEJA PENGAWAS',
                                  style: TextStyle(
                                    color: sColor,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),

                            // Seat grid
                            GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: columns,
                                mainAxisSpacing: 8,
                                crossAxisSpacing: 8,
                                childAspectRatio: 0.85,
                              ),
                              itemCount: rows * columns,
                              itemBuilder: (_, i) {
                                final seatNum = i + 1;
                                final student = seatMap[seatNum];

                                if (student == null) {
                                  return Container(
                                    decoration: BoxDecoration(
                                      color: Colors.transparent,
                                      borderRadius:
                                          BorderRadius.circular(10),
                                      border: Border.all(
                                        color: isDarkMode
                                            ? Colors.white
                                                .withValues(alpha: 0.08)
                                            : Colors.black
                                                .withValues(alpha: 0.06),
                                      ),
                                    ),
                                  );
                                }

                                final isPresent = student.scannedAt != null;
                                final isSubmitted = student.submittedAt != null;
                                final cohortColor =
                                    getCohortColor(student.angkatan);
                                final seatColor = isSubmitted
                                    ? const Color(0xFF10B981)
                                    : (isPresent
                                        ? cohortColor
                                        : cohortColor.withValues(alpha: 0.12));
                                final seatBorderColor = isSubmitted
                                    ? const Color(0xFF059669)
                                    : (isPresent
                                        ? cohortColor
                                        : cohortColor.withValues(alpha: 0.4));
                                final textColor = (isSubmitted || isPresent)
                                    ? Colors.white
                                    : isDarkMode
                                        ? Colors.white.withValues(alpha: 0.7)
                                        : const Color(0xFF1E1B4B)
                                            .withValues(alpha: 0.8);

                                return Container(
                                  decoration: BoxDecoration(
                                    color: seatColor,
                                    borderRadius:
                                        BorderRadius.circular(10),
                                    border: Border.all(
                                      color: seatBorderColor,
                                      width: (isSubmitted || isPresent) ? 1.5 : 1,
                                    ),
                                    boxShadow: (isSubmitted || isPresent)
                                        ? [
                                            BoxShadow(
                                              color: (isSubmitted ? const Color(0xFF10B981) : cohortColor)
                                                  .withValues(alpha: 0.15),
                                              blurRadius: 6,
                                              offset: const Offset(0, 2),
                                            )
                                          ]
                                        : null,
                                  ),
                                  padding: const EdgeInsets.all(5),
                                  child: Column(
                                    mainAxisAlignment:
                                        MainAxisAlignment.center,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Container(
                                            padding:
                                                const EdgeInsets.symmetric(
                                                    horizontal: 4,
                                                    vertical: 2),
                                            decoration: BoxDecoration(
                                              color: (isSubmitted || isPresent)
                                                  ? Colors.white
                                                      .withValues(alpha: 0.2)
                                                  : cohortColor
                                                      .withValues(alpha: 0.15),
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              '#$seatNum',
                                              style: TextStyle(
                                                color: (isSubmitted || isPresent)
                                                    ? Colors.white
                                                    : cohortColor,
                                                fontSize: 8,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          Icon(
                                            isSubmitted
                                                ? Icons.task_alt_rounded
                                                : (isPresent
                                                    ? Icons.check_circle_rounded
                                                    : Icons.radio_button_unchecked_rounded),
                                            size: 11,
                                            color: (isSubmitted || isPresent)
                                                ? Colors.white
                                                : cohortColor,
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
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Angkatan ${student.angkatan}',
                                        style: TextStyle(
                                          color: (isSubmitted || isPresent)
                                              ? Colors.white
                                                  .withValues(alpha: 0.8)
                                              : sColor,
                                          fontSize: 8,
                                        ),
                                      ),
                                      const Spacer(),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 4, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: (isSubmitted || isPresent)
                                              ? Colors.white
                                                  .withValues(alpha: 0.15)
                                              : Colors.transparent,
                                          borderRadius:
                                              BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          isSubmitted ? '✓ Selesai' : (isPresent ? '✓ Hadir' : 'Absen'),
                                          style: TextStyle(
                                            color: (isSubmitted || isPresent)
                                                ? Colors.white
                                                : cohortColor,
                                            fontSize: 8,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 8),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
      },
    );
  }

  Widget _statChip(String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  color: color, fontSize: 11, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

  // ── Manual Session Creation Dialog ───────────────────────────
  Future<void> _showAddSessionDialog(
    BuildContext context,
    ExamEvent event,
    bool isDark,
    Color titleColor,
    Color subtitleColor,
    String schoolId,
  ) async {
    final db = FirebaseFirestore.instance;
    final subjectsSnap = await db
        .collection('schools')
        .doc(schoolId)
        .collection('subjects')
        .get();
    final classesSnap = await db
        .collection('schools')
        .doc(schoolId)
        .collection('classes')
        .get();
    final teachersSnap = await db
        .collection('schools')
        .doc(schoolId)
        .collection('teachers')
        .where('aktif', isEqualTo: true)
        .get();

    final List<Map<String, dynamic>> subjectsList = subjectsSnap.docs.map((d) {
      return {'id': d.id, 'name': d.data()['name'] ?? ''};
    }).toList()..sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));

    final List<Map<String, dynamic>> classesList = classesSnap.docs.map((d) {
      return {'id': d.id, 'name': d.data()['nama'] ?? ''};
    }).toList()..sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));

    final List<Map<String, dynamic>> teachersList = teachersSnap.docs.map((d) {
      return {'id': d.id, 'name': d.data()['nama'] ?? ''};
    }).toList()..sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));

    final List<DateTime> availableDates = [];
    DateTime temp = DateTime(event.startDate.year, event.startDate.month, event.startDate.day);
    final endDay = DateTime(event.endDate.year, event.endDate.month, event.endDate.day);
    while (temp.isBefore(endDay) || temp.isAtSameMomentAs(endDay)) {
      availableDates.add(temp);
      temp = temp.add(const Duration(days: 1));
    }

    if (!context.mounted) return;

    DateTime? selectedDate = availableDates.isNotEmpty ? availableDates.first : null;
    ExamSlot? selectedSlot = event.dailySlots.isNotEmpty ? event.dailySlots.first : null;
    Map<String, dynamic>? selectedSubject = subjectsList.isNotEmpty ? subjectsList.first : null;
    Map<String, dynamic>? selectedClass = classesList.isNotEmpty ? classesList.first : null;
    ExamRoom? selectedRoom = event.rooms.isNotEmpty ? event.rooms.first : null;
    Map<String, dynamic>? selectedTeacher = teachersList.isNotEmpty ? teachersList.first : null;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final dialogBg = isDark ? const Color(0xFF1E1B4B) : Colors.white;
          final borderCol = isDark ? Colors.white24 : Colors.black12;

          return Container(
            padding: EdgeInsets.fromLTRB(24, 20, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
            decoration: BoxDecoration(
              color: dialogBg,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: borderCol,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Tambah Sesi Ujian Manual',
                    style: TextStyle(
                      color: titleColor,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),

                  Text('Pilih Tanggal', style: TextStyle(color: subtitleColor, fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<DateTime>(
                    value: selectedDate,
                    dropdownColor: dialogBg,
                    decoration: _dialogInputDecoration(isDark, borderCol),
                    items: availableDates.map((date) {
                      return DropdownMenuItem<DateTime>(
                        value: date,
                        child: Text(DateFormat('EEEE, dd MMM yyyy', 'id').format(date), style: TextStyle(color: titleColor, fontSize: 13)),
                      );
                    }).toList(),
                    onChanged: (val) => setDialogState(() => selectedDate = val),
                  ),
                  const SizedBox(height: 12),

                  Text('Pilih Sesi/Slot Waktu', style: TextStyle(color: subtitleColor, fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  if (event.dailySlots.isEmpty)
                    Text('Belum ada slot waktu di event ini.', style: TextStyle(color: Colors.red, fontSize: 12))
                  else
                    DropdownButtonFormField<ExamSlot>(
                      value: selectedSlot,
                      dropdownColor: dialogBg,
                      decoration: _dialogInputDecoration(isDark, borderCol),
                      items: event.dailySlots.map((slot) {
                        return DropdownMenuItem<ExamSlot>(
                          value: slot,
                          child: Text('${slot.name} (${slot.startTime} - ${slot.endTime})', style: TextStyle(color: titleColor, fontSize: 13)),
                        );
                      }).toList(),
                      onChanged: (val) => setDialogState(() => selectedSlot = val),
                    ),
                  const SizedBox(height: 12),

                  Text('Mata Pelajaran', style: TextStyle(color: subtitleColor, fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<Map<String, dynamic>>(
                    value: selectedSubject,
                    dropdownColor: dialogBg,
                    decoration: _dialogInputDecoration(isDark, borderCol),
                    items: subjectsList.map((sub) {
                      return DropdownMenuItem<Map<String, dynamic>>(
                        value: sub,
                        child: Text(sub['name'], style: TextStyle(color: titleColor, fontSize: 13)),
                      );
                    }).toList(),
                    onChanged: (val) => setDialogState(() => selectedSubject = val),
                  ),
                  const SizedBox(height: 12),

                  Text('Kelas Peserta', style: TextStyle(color: subtitleColor, fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<Map<String, dynamic>>(
                    value: selectedClass,
                    dropdownColor: dialogBg,
                    decoration: _dialogInputDecoration(isDark, borderCol),
                    items: classesList.map((c) {
                      return DropdownMenuItem<Map<String, dynamic>>(
                        value: c,
                        child: Text(c['name'], style: TextStyle(color: titleColor, fontSize: 13)),
                      );
                    }).toList(),
                    onChanged: (val) => setDialogState(() => selectedClass = val),
                  ),
                  const SizedBox(height: 12),

                  Text('Ruang Ujian', style: TextStyle(color: subtitleColor, fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  if (event.rooms.isEmpty)
                    Text('Belum ada ruangan di event ini.', style: TextStyle(color: Colors.red, fontSize: 12))
                  else
                    DropdownButtonFormField<ExamRoom>(
                      value: selectedRoom,
                      dropdownColor: dialogBg,
                      decoration: _dialogInputDecoration(isDark, borderCol),
                      items: event.rooms.map((room) {
                        return DropdownMenuItem<ExamRoom>(
                          value: room,
                          child: Text('${room.name} (Kapasitas: ${room.capacity})', style: TextStyle(color: titleColor, fontSize: 13)),
                        );
                      }).toList(),
                      onChanged: (val) => setDialogState(() => selectedRoom = val),
                    ),
                  const SizedBox(height: 12),

                  Text('Pengawas (Guru)', style: TextStyle(color: subtitleColor, fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<Map<String, dynamic>>(
                    value: selectedTeacher,
                    dropdownColor: dialogBg,
                    decoration: _dialogInputDecoration(isDark, borderCol),
                    items: teachersList.map((t) {
                      return DropdownMenuItem<Map<String, dynamic>>(
                        value: t,
                        child: Text(t['name'], style: TextStyle(color: titleColor, fontSize: 13)),
                      );
                    }).toList(),
                    onChanged: (val) => setDialogState(() => selectedTeacher = val),
                  ),
                  const SizedBox(height: 24),

                  ElevatedButton(
                    onPressed: () async {
                      if (selectedDate == null ||
                          selectedSlot == null ||
                          selectedSubject == null ||
                          selectedClass == null ||
                          selectedRoom == null ||
                          selectedTeacher == null) {
                        Get.snackbar('Error', 'Harap lengkapi semua field',
                            backgroundColor: Colors.red, colorText: Colors.white);
                        return;
                      }

                      Get.back();

                      Get.dialog(
                        const Center(child: CircularProgressIndicator(color: Color(0xFF8B5CF6))),
                        barrierDismissible: false,
                      );

                      try {
                        final studSnap = await db
                            .collection('schools')
                            .doc(schoolId)
                            .collection('students')
                            .where('classId', isEqualTo: selectedClass!['id'])
                            .get();

                        final List<Map<String, dynamic>> students = studSnap.docs.map((d) {
                          final data = d.data();
                          return {
                            'id': d.id,
                            'name': data['nama'] ?? '',
                            'nis': data['nis'] ?? '',
                            'angkatan': (data['angkatan'] ?? '').toString(),
                          };
                        }).toList()..sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));

                        final sessionsSnap = await db
                            .collection('schools')
                            .doc(schoolId)
                            .collection('exam_sessions')
                            .where('eventId', isEqualTo: event.id)
                            .get();

                        final allSessions = sessionsSnap.docs.map((d) {
                          final data = d.data();
                          final sDate = (data['date'] as Timestamp).toDate();
                          final sRooms = (data['roomName'] as String? ?? '').split(',').map((r) => r.trim()).toList();
                          final sParts = (data['previewParticipations'] as List? ?? []).map((p) {
                            final pMap = Map<String, dynamic>.from(p);
                            return ExamParticipation(
                              studentId: pMap['studentId'] ?? '',
                              studentName: pMap['studentName'] ?? '',
                              nis: pMap['nis'] ?? '',
                              hasStarted: pMap['hasStarted'] ?? false,
                              seatNumber: pMap['seatNumber'] ?? 0,
                              roomName: pMap['roomName'] ?? '',
                              angkatan: pMap['angkatan'] ?? '',
                            );
                          }).toList();

                          return ExamSession(
                            id: d.id,
                            eventId: data['eventId'] ?? '',
                            subjectId: data['subjectId'] ?? '',
                            subjectName: data['subjectName'] ?? '',
                            classId: data['classId'] ?? '',
                            className: data['className'] ?? '',
                            date: sDate,
                            slotName: data['slotName'] ?? '',
                            startTime: data['startTime'] ?? '',
                            endTime: data['endTime'] ?? '',
                            roomName: data['roomName'] ?? '',
                            proctorId: data['proctorId'] ?? '',
                            proctorName: data['proctorName'] ?? '',
                            authorTeacherId: data['authorTeacherId'] ?? '',
                            qrToken: data['qrToken'] ?? '',
                            isQrActive: data['isQrActive'] ?? false,
                            examStatus: data['examStatus'] ?? '',
                            previewParticipations: sParts,
                          );
                        }).toList();

                        final existingSessionsInRoom = allSessions.where((s) =>
                            s.roomName.split(',').map((r) => r.trim()).contains(selectedRoom!.name) &&
                            DateFormat('yyyy-MM-dd').format(s.date) == DateFormat('yyyy-MM-dd').format(selectedDate!) &&
                            s.slotName == selectedSlot!.name
                        ).toList();

                        int maxSeat = 0;
                        for (var es in existingSessionsInRoom) {
                          for (var part in es.previewParticipations ?? []) {
                            if (part.roomName == selectedRoom!.name && part.seatNumber > maxSeat) {
                              maxSeat = part.seatNumber;
                            }
                          }
                        }
                        int nextSeatStart = maxSeat + 1;

                        final List<ExamParticipation> parts = [];
                        for (final std in students) {
                          parts.add(ExamParticipation(
                            studentId: std['id'],
                            studentName: std['name'],
                            nis: std['nis'],
                            hasStarted: false,
                            seatNumber: nextSeatStart++,
                            roomName: selectedRoom!.name,
                            angkatan: std['angkatan'],
                          ));
                        }

                        final newSessionDoc = db
                            .collection('schools')
                            .doc(schoolId)
                            .collection('exam_sessions')
                            .doc();

                        final newSession = ExamSession(
                          id: newSessionDoc.id,
                          eventId: event.id,
                          subjectId: selectedSubject!['id'],
                          subjectName: selectedSubject!['name'],
                          classId: selectedClass!['id'],
                          className: selectedClass!['name'],
                          date: selectedDate!,
                          slotName: selectedSlot!.name,
                          startTime: selectedSlot!.startTime,
                          endTime: selectedSlot!.endTime,
                          roomName: selectedRoom!.name,
                          proctorId: selectedTeacher!['id'],
                          proctorName: selectedTeacher!['name'],
                          authorTeacherId: '',
                          qrToken: ExamSessionService.generateQrToken(),
                          isQrActive: false,
                          examStatus: 'Scheduled',
                          previewParticipations: parts,
                        );

                        await newSessionDoc.set(newSession.toFirestore());

                        Get.back();

                        Get.snackbar(
                          'Sukses',
                          'Sesi ujian manual berhasil ditambahkan.',
                          backgroundColor: const Color(0xFF10B981),
                          colorText: Colors.white,
                        );
                      } catch (e) {
                        Get.back();

                        Get.snackbar(
                          'Error',
                          'Gagal menambahkan sesi: $e',
                          backgroundColor: Colors.red,
                          colorText: Colors.white,
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8B5CF6),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 46),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Simpan Sesi', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
  InputDecoration _dialogInputDecoration(bool isDark, Color border) {
    return InputDecoration(
      filled: true,
      fillColor: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.02),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: border)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: border)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: const Color(0xFF8B5CF6))),
    );
  }

  void _showAuthorsBottomSheet(
    BuildContext context,
    ExamEvent event,
    bool isDark,
    Color cardColor,
    Color cardBorder,
    Color titleColor,
    Color subtitleColor,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1730) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(Icons.assignment_ind_rounded, color: titleColor, size: 24),
                const SizedBox(width: 8),
                Text(
                  AppLocalization.isIndonesian ? 'Daftar Pembuat Soal' : 'Subject Authors',
                  style: TextStyle(
                      color: titleColor,
                      fontSize: 18,
                      fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: event.subjectConfigs.length,
                separatorBuilder: (_, __) => Divider(color: cardBorder, height: 1),
                itemBuilder: (_, idx) {
                  final config = event.subjectConfigs[idx];
                  final teacherNames = config.authorTeacherNames.isNotEmpty
                      ? config.authorTeacherNames.join(', ')
                      : 'Belum dipilih';

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.menu_book_rounded,
                              color: Color(0xFF8B5CF6), size: 18),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                config.subjectName,
                                style: TextStyle(
                                    color: titleColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                AppLocalization.isIndonesian
                                    ? 'Pembuat Soal: $teacherNames'
                                    : 'Authors: $teacherNames',
                                style: TextStyle(
                                    color: subtitleColor,
                                    fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
