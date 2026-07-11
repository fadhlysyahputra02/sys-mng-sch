import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../../core/services/session_service.dart';
import '../../authentication/widgets/auth_background.dart';
import '../models/exam_event_model.dart';
import '../services/exam_behavior_service.dart';
import '../services/exam_session_service.dart';

class ProctorExamMonitorPage extends StatefulWidget {
  final String sessionId;
  final String subjectName;
  final String roomName;
  final String className;

  const ProctorExamMonitorPage({
    super.key,
    required this.sessionId,
    required this.subjectName,
    required this.roomName,
    required this.className,
  });

  @override
  State<ProctorExamMonitorPage> createState() => _ProctorExamMonitorPageState();
}

class _ProctorExamMonitorPageState extends State<ProctorExamMonitorPage>
    with SingleTickerProviderStateMixin {
  final _sessionService = ExamSessionService();
  final _behaviorService = ExamBehaviorService();
  late final Stream<List<ExamParticipation>> _participationsStream;
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _behaviorStream;

  // View state
  bool _showGrid = true;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  // Layout configuration
  // Options: 3, 4, or 5 pairs of desks per row
  int _pairsPerRow = 3; 

  @override
  void initState() {
    super.initState();
    final schoolId = SessionService.currentUser!.schoolId;
    _participationsStream = _sessionService.getParticipations(
      schoolId: schoolId,
      sessionId: widget.sessionId,
    );
    _behaviorStream = _behaviorService.getExamBehaviorStream(
      schoolId: schoolId,
      sessionId: widget.sessionId,
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  int _getColumnsCount() => _pairsPerRow * 2;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: AuthBackground.isDarkMode,
      builder: (context, isDark, _) {
        final titleColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
        final subTextColor = isDark
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
                // Custom AppBar
                SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
                    child: Row(
                      children: [
                        IconButton(
                          icon: Icon(Icons.arrow_back_rounded, color: titleColor),
                          onPressed: () => Navigator.pop(context),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Monitor Ruang Ujian',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: titleColor,
                                ),
                              ),
                              Text(
                                '${widget.subjectName} • ${widget.className} • ${widget.roomName}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: subTextColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Layout Selector
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: cardColor,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: cardBorder),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<int>(
                              value: _pairsPerRow,
                              dropdownColor: isDark ? const Color(0xFF15122F) : Colors.white,
                              style: TextStyle(color: titleColor, fontSize: 12, fontWeight: FontWeight.bold),
                              items: const [
                                DropdownMenuItem(value: 3, child: Text('3 Pasang Meja (6 Baris)')),
                                DropdownMenuItem(value: 4, child: Text('4 Pasang Meja (8 Baris)')),
                                DropdownMenuItem(value: 5, child: Text('5 Pasang Meja (10 Baris)')),
                              ],
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() {
                                    _pairsPerRow = val;
                                  });
                                }
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Live Streams Builder
                Expanded(
                  child: StreamBuilder<List<ExamParticipation>>(
                    stream: _participationsStream,
                    builder: (context, partSnap) {
                      if (partSnap.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (partSnap.hasError) {
                        return Center(
                          child: Text(
                            'Gagal memuat peserta ujian: ${partSnap.error}',
                            style: const TextStyle(color: Colors.redAccent),
                          ),
                        );
                      }

                      final participations = partSnap.data ?? [];

                      return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: _behaviorStream,
                        builder: (context, behaviorSnap) {
                          if (behaviorSnap.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator());
                          }

                          final behaviorDocs = behaviorSnap.data?.docs ?? [];
                          final Map<String, Map<String, dynamic>> behaviorByStudent = {};
                          for (final doc in behaviorDocs) {
                            final data = doc.data();
                            final sid = data['studentId']?.toString() ?? '';
                            if (sid.isNotEmpty) {
                              behaviorByStudent[sid] = data;
                            }
                          }

                          // Compute Summary Stats
                          int countStandby = 0;
                          int countKeluar = 0;
                          int countScreenOff = 0;
                          int countSelesai = 0;
                          int countBelum = 0;

                          for (final p in participations) {
                            final bRecord = behaviorByStudent[p.studentId];
                            if (p.submittedAt != null) {
                              countSelesai++;
                            } else if (bRecord == null) {
                              countBelum++;
                            } else {
                              final type = bRecord['type']?.toString().toLowerCase() ?? '';
                              if (type.contains('keluar') || type.contains('meninggalkan')) {
                                countKeluar++;
                              } else if (type.contains('mati') || type.contains('kunci') || type.contains('off')) {
                                countScreenOff++;
                              } else {
                                countStandby++;
                              }
                            }
                          }

                          return Column(
                            children: [
                              // Summary Stats Bar
                              _buildStatsBar(
                                isDark: isDark,
                                cardColor: cardColor,
                                cardBorder: cardBorder,
                                total: participations.length,
                                standby: countStandby,
                                keluar: countKeluar,
                                screenOff: countScreenOff,
                                selesai: countSelesai,
                                belum: countBelum,
                              ),

                              // View Toggle and Search
                              _buildControlsBar(
                                isDark: isDark,
                                cardColor: cardColor,
                                cardBorder: cardBorder,
                                titleColor: titleColor,
                                subTextColor: subTextColor,
                              ),

                              // Content View
                              Expanded(
                                child: _showGrid
                                    ? _buildSeatingGrid(
                                        isDark: isDark,
                                        participations: participations,
                                        behaviorByStudent: behaviorByStudent,
                                      )
                                    : _buildListView(
                                        isDark: isDark,
                                        titleColor: titleColor,
                                        subTextColor: subTextColor,
                                        cardColor: cardColor,
                                        cardBorder: cardBorder,
                                        participations: participations,
                                        behaviorByStudent: behaviorByStudent,
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
    );
  }

  Widget _buildStatsBar({
    required bool isDark,
    required Color cardColor,
    required Color cardBorder,
    required int total,
    required int standby,
    required int keluar,
    required int screenOff,
    required int selesai,
    required int belum,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorder),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem('Total', total.toString(), Colors.blueAccent),
          _buildStatItem('Standby', standby.toString(), Colors.green),
          _buildStatItem('Keluar', keluar.toString(), Colors.redAccent),
          _buildStatItem('Screen Off', screenOff.toString(), Colors.orange),
          _buildStatItem('Selesai', selesai.toString(), Colors.cyan),
          _buildStatItem('Belum', belum.toString(), Colors.grey),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildControlsBar({
    required bool isDark,
    required Color cardColor,
    required Color cardBorder,
    required Color titleColor,
    required Color subTextColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          // Search Input
          Expanded(
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: cardBorder),
              ),
              child: TextField(
                controller: _searchController,
                style: TextStyle(color: titleColor, fontSize: 13),
                onChanged: (val) {
                  setState(() {
                    _searchQuery = val.trim().toLowerCase();
                  });
                },
                decoration: InputDecoration(
                  hintText: 'Cari murid...',
                  hintStyle: TextStyle(color: subTextColor, fontSize: 13),
                  prefixIcon: Icon(Icons.search_rounded, color: subTextColor, size: 18),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.clear_rounded, color: subTextColor, size: 16),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _searchQuery = '';
                            });
                          },
                        )
                      : null,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // View Toggle Buttons
          Container(
            height: 40,
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: cardBorder),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(Icons.grid_view_rounded,
                      color: _showGrid ? const Color(0xFF8B5CF6) : subTextColor, size: 18),
                  onPressed: () => setState(() => _showGrid = true),
                ),
                VerticalDivider(width: 1, color: cardBorder, indent: 8, endIndent: 8),
                IconButton(
                  icon: Icon(Icons.list_alt_rounded,
                      color: !_showGrid ? const Color(0xFF8B5CF6) : subTextColor, size: 18),
                  onPressed: () => setState(() => _showGrid = false),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSeatingGrid({
    required bool isDark,
    required List<ExamParticipation> participations,
    required Map<String, Map<String, dynamic>> behaviorByStudent,
  }) {
    if (participations.isEmpty) {
      return const Center(child: Text('Belum ada data peserta untuk sesi ini'));
    }


    // Find the maximum seat number to size our grid
    int maxSeat = 0;
    final Map<int, ExamParticipation> participationBySeat = {};
    for (final p in participations) {
      participationBySeat[p.seatNumber] = p;
      if (p.seatNumber > maxSeat) {
        maxSeat = p.seatNumber;
      }
    }

    if (maxSeat == 0) maxSeat = 30; // fallback default sizing

    final cols = _getColumnsCount();
    final rowsCount = (maxSeat / cols).ceil();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: Column(
          children: [
            // Papan Tulis / Front indicator
            Container(
              width: 180,
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: isDark ? Colors.white24 : Colors.black12),
              ),
              child: const Text(
                'DEPAN / PAPAN TULIS',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1),
              ),
            ),

            // Desk Grid with realistic gaps
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: rowsCount,
              itemBuilder: (context, rIndex) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(cols, (cIndex) {
                      final seatNum = (rIndex * cols) + cIndex + 1;
                      final student = participationBySeat[seatNum];
                      final behavior = student != null ? behaviorByStudent[student.studentId] : null;

                      // Insert gaps between pairs of tables
                      final isGapAfter = cIndex % 2 == 1 && cIndex < cols - 1;

                      final widgetSeat = _buildSeatCard(
                        isDark: isDark,
                        seatNumber: seatNum,
                        student: student,
                        behavior: behavior,
                        isFilteredOut: student != null &&
                            _searchQuery.isNotEmpty &&
                            !student.studentName.toLowerCase().contains(_searchQuery),
                      );

                      if (isGapAfter) {
                        return Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            widgetSeat,
                            const SizedBox(width: 24), // Gap size between pairs
                          ],
                        );
                      }

                      return widgetSeat;
                    }),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSeatCard({
    required bool isDark,
    required int seatNumber,
    required ExamParticipation? student,
    required Map<String, dynamic>? behavior,
    required bool isFilteredOut,
  }) {
    final titleColor = isDark ? Colors.white : const Color(0xFF1E1B4B);

    if (student == null) {
      // Empty Desk
      return Container(
        width: 75,
        height: 75,
        margin: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.02) : Colors.black.withValues(alpha: 0.02),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? Colors.white12 : Colors.black12,
            style: BorderStyle.solid,
          ),
        ),
        child: Center(
          child: Text(
            '#$seatNumber',
            style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold),
          ),
        ),
      );
    }

    // Determine status colors
    Color statusColor = Colors.grey;
    String statusLabel = 'Belum Mulai';
    IconData statusIcon = Icons.remove_circle_outline_rounded;

    if (student.submittedAt != null) {
      statusColor = Colors.cyan;
      statusLabel = 'Selesai';
      statusIcon = Icons.check_circle_rounded;
    } else if (behavior == null) {
      statusColor = Colors.grey;
      statusLabel = 'Belum Mulai';
      statusIcon = Icons.access_time_rounded;
    } else {
      final type = behavior['type']?.toString().toLowerCase() ?? '';
      if (type.contains('keluar') || type.contains('meninggalkan')) {
        statusColor = Colors.redAccent;
        statusLabel = 'Keluar';
        statusIcon = Icons.exit_to_app_rounded;
      } else if (type.contains('mati') || type.contains('kunci') || type.contains('off')) {
        statusColor = Colors.orange;
        statusLabel = 'Screen Off';
        statusIcon = Icons.screen_lock_portrait_rounded;
      } else {
        statusColor = Colors.green;
        statusLabel = 'Standby';
        statusIcon = Icons.play_arrow_rounded;
      }
    }

    final nameParts = student.studentName.split(' ');
    final displayName = nameParts.length > 1 ? '${nameParts[0]} ${nameParts[1][0]}.' : student.studentName;

    return Opacity(
      opacity: isFilteredOut ? 0.2 : 1.0,
      child: GestureDetector(
        onTap: () => _showStudentLogs(student, behavior),
        child: Container(
          width: 75,
          height: 75,
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: statusColor.withValues(alpha: 0.3), width: 1.5),
            boxShadow: isDark
                ? []
                : [
                    BoxShadow(
                      color: statusColor.withValues(alpha: 0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    )
                  ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Header row
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '#$seatNumber',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                    Icon(statusIcon, size: 10, color: statusColor),
                  ],
                ),
              ),
              // Student short name
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  displayName,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: titleColor,
                  ),
                ),
              ),
              // Status label badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    fontSize: 7,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildListView({
    required bool isDark,
    required Color titleColor,
    required Color subTextColor,
    required Color cardColor,
    required Color cardBorder,
    required List<ExamParticipation> participations,
    required Map<String, Map<String, dynamic>> behaviorByStudent,
  }) {
    final filtered = participations.where((p) {
      return p.studentName.toLowerCase().contains(_searchQuery);
    }).toList();

    if (filtered.isEmpty) {
      return const Center(child: Text('Murid tidak ditemukan'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final student = filtered[index];
        final behavior = behaviorByStudent[student.studentId];

        // Determine status colors
        Color statusColor = Colors.grey;
        String statusLabel = 'Belum Mulai';
        IconData statusIcon = Icons.access_time_rounded;

        if (student.submittedAt != null) {
          statusColor = Colors.cyan;
          statusLabel = 'Selesai';
          statusIcon = Icons.check_circle_rounded;
        } else if (behavior == null) {
          statusColor = Colors.grey;
          statusLabel = 'Belum Mulai';
          statusIcon = Icons.access_time_rounded;
        } else {
          final type = behavior['type']?.toString().toLowerCase() ?? '';
          if (type.contains('keluar') || type.contains('meninggalkan')) {
            statusColor = Colors.redAccent;
            statusLabel = 'Keluar';
            statusIcon = Icons.exit_to_app_rounded;
          } else if (type.contains('mati') || type.contains('kunci') || type.contains('off')) {
            statusColor = Colors.orange;
            statusLabel = 'Screen Off';
            statusIcon = Icons.screen_lock_portrait_rounded;
          } else {
            statusColor = Colors.green;
            statusLabel = 'Standby';
            statusIcon = Icons.play_arrow_rounded;
          }
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: cardBorder),
          ),
          child: Row(
            children: [
              // Seat Number Badge
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    student.seatNumber.toString(),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Student Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      student.studentName,
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: titleColor),
                    ),
                    Text(
                      'NIS: ${student.nis} • ${student.angkatan}',
                      style: TextStyle(fontSize: 11, color: subTextColor),
                    ),
                  ],
                ),
              ),
              // Status Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: statusColor.withValues(alpha: 0.2)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, size: 12, color: statusColor),
                    const SizedBox(width: 4),
                    Text(
                      statusLabel,
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Action View Log
              IconButton(
                icon: Icon(Icons.assignment_rounded, color: subTextColor, size: 18),
                onPressed: () => _showStudentLogs(student, behavior),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showStudentLogs(ExamParticipation student, Map<String, dynamic>? behavior) {
    final isDark = AuthBackground.isDarkMode.value;
    final titleColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
    final subTextColor = isDark
        ? Colors.white.withValues(alpha: 0.55)
        : const Color(0xFF1E1B4B).withValues(alpha: 0.6);

    final activityLog = behavior?['activityLog'] as List<dynamic>? ?? [];

    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF100C22) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle Bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: subTextColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Header Info
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.deepPurple.shade900,
                  radius: 20,
                  child: Text(
                    student.seatNumber.toString(),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        student.studentName,
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: titleColor),
                      ),
                      Text(
                        'Bangku #${student.seatNumber} • Kelas ${student.angkatan}',
                        style: TextStyle(fontSize: 12, color: subTextColor),
                      ),
                    ],
                  ),
                ),
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
              ],
            ),
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
                                final schoolId = SessionService.currentUser!.schoolId;
                                final service = ExamSessionService();
                                await service.cancelProctorScanAttendance(
                                  schoolId: schoolId,
                                  sessionId: widget.sessionId,
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
                                final schoolId = SessionService.currentUser!.schoolId;
                                final service = ExamSessionService();
                                await service.recordProctorScanAttendance(
                                  schoolId: schoolId,
                                  sessionId: widget.sessionId,
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
            Text(
              'Riwayat Log Aktivitas',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: titleColor),
            ),
            const SizedBox(height: 12),

            // Timeline Logs
            if (activityLog.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    'Belum ada aktivitas tercatat (murid belum mulai ujian)',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: subTextColor),
                  ),
                ),
              )
            else
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  physics: const BouncingScrollPhysics(),
                  itemCount: activityLog.length,
                  itemBuilder: (context, idx) {
                    // Sort descending: most recent log first
                    final sortedLog = List<dynamic>.from(activityLog);
                    sortedLog.sort((a, b) {
                      final ta = a['timestamp'];
                      final tb = b['timestamp'];
                      final dateA = ta is Timestamp ? ta.toDate() : DateTime(0);
                      final dateB = tb is Timestamp ? tb.toDate() : DateTime(0);
                      return dateB.compareTo(dateA);
                    });

                    final log = sortedLog[idx] as Map<String, dynamic>;
                    final logType = log['type']?.toString() ?? 'Unknown';
                    final logDesc = log['description']?.toString() ?? '-';
                    final logTs = log['timestamp'];
                    final logTime = logTs is Timestamp ? logTs.toDate() : null;

                    Color logColor = Colors.grey;
                    if (logType.toLowerCase().contains('standby')) {
                      logColor = Colors.green;
                    } else if (logType.toLowerCase().contains('keluar')) {
                      logColor = Colors.redAccent;
                    } else if (logType.toLowerCase().contains('mati') || logType.toLowerCase().contains('kunci') || logType.toLowerCase().contains('off')) {
                      logColor = Colors.orange;
                    }

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Time
                          Text(
                            logTime != null ? DateFormat('HH:mm:ss').format(logTime) : '--:--:--',
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 11,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Bullet
                          Container(
                            margin: const EdgeInsets.only(top: 4),
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(color: logColor, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 12),
                          // Message
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  logType,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: logColor,
                                  ),
                                ),
                                Text(
                                  logDesc,
                                  style: TextStyle(fontSize: 10, color: subTextColor),
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
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => Get.back(),
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.05),
                foregroundColor: titleColor,
                elevation: 0,
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
}
