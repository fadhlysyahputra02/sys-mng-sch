import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';


import '../../../core/services/session_service.dart';
import '../../authentication/widgets/auth_background.dart';
import '../../students/data/student_service.dart';
import '../../schools/pages/schedule/Service/class_schedule_service.dart';

class TeacherBehaviorRecordsPage extends StatefulWidget {
  final String teacherId;
  final bool hideBackButton;
  const TeacherBehaviorRecordsPage({super.key, required this.teacherId, this.hideBackButton = false});

  @override
  State<TeacherBehaviorRecordsPage> createState() => _TeacherBehaviorRecordsPageState();
}

class _TeacherBehaviorRecordsPageState extends State<TeacherBehaviorRecordsPage> {
  final _studentService = StudentService();
  final _searchController = TextEditingController();
  String _searchQuery = '';
  Timer? _cleanupTimer;
  Map<String, Map<String, dynamic>>? _cachedSchedules;

  late final Stream<QuerySnapshot<Map<String, dynamic>>> _schedulesStream;
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _attendanceStream;
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _behaviorStream;

  String _getTodayDateStr() {
    final now = DateTime.now();
    return "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
  }

  String _getTodayHariIndonesian() {
    final now = DateTime.now();
    final days = ['Minggu', 'Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu'];
    return days[now.weekday % 7];
  }

  int _timeToMinutes(String time) {
    final parts = time.split(':');
    if (parts.length != 2) return 0;
    return (int.tryParse(parts[0]) ?? 0) * 60 + (int.tryParse(parts[1]) ?? 0);
  }

  bool _isActiveNow(Map<String, dynamic> s) {
    final jamMulai = s['jamMulai'] ?? '00:00';
    final jamSelesai = s['jamSelesai'] ?? '00:00';
    final now = DateTime.now();
    final nowMinutes = now.hour * 60 + now.minute;
    final startMinutes = _timeToMinutes(jamMulai);
    final endMinutes = _timeToMinutes(jamSelesai);
    return nowMinutes >= startMinutes && nowMinutes <= endMinutes;
  }

  @override
  void initState() {
    super.initState();
    final user = SessionService.currentUser!;
    _schedulesStream = ClassScheduleService().getSchedulesByTeacher(user.schoolId, widget.teacherId);
    _attendanceStream = _studentService.getTodayAttendanceListStream(
      schoolId: user.schoolId,
      dateStr: _getTodayDateStr(),
    );
    _behaviorStream = _studentService.getBehaviorRecords(user.schoolId);

    _startAutoCleanup();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _cleanupTimer?.cancel();
    super.dispose();
  }

  void _startAutoCleanup() {
    final user = SessionService.currentUser;
    if (user == null) return;

    // Run first check immediately after page loads
    WidgetsBinding.instance.addPostFrameCallback((_) => _runCleanup(user.schoolId));

    // Then run every 10 seconds
    _cleanupTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (mounted) setState(() {}); // Trigger rebuild to update active schedules in real-time
      _runCleanup(user.schoolId);
    });
  }

  Future<void> _runCleanup(String schoolId) async {
    try {
      // 1. Fetch and cache all class schedules of the school once
      if (_cachedSchedules == null) {
        final schedulesSnapshot = await FirebaseFirestore.instance
            .collection('schools')
            .doc(schoolId)
            .collection('class_schedules')
            .get();
        _cachedSchedules = {};
        for (final doc in schedulesSnapshot.docs) {
          _cachedSchedules![doc.id] = doc.data();
        }
        debugPrint('Auto-cleanup: Cached ${_cachedSchedules!.length} class schedules.');
      }

      // 2. Fetch all behavior records
      final snapshot = await FirebaseFirestore.instance
          .collection('schools')
          .doc(schoolId)
          .collection('behavior_records')
          .get();

      debugPrint('Auto-cleanup: Fetched ${snapshot.docs.length} behavior records from Firestore.');

      final now = DateTime.now();
      const ttlDuration = Duration(hours: 24);

      final batch = FirebaseFirestore.instance.batch();
      bool hasDeletions = false;

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final scheduleId = data['scheduleId'] as String?;
        final timestamp = data['timestamp'] as Timestamp?;

        bool shouldDelete = false;
        String reason = 'Keep';

        debugPrint('Auto-cleanup check for Record ID: ${doc.id}');
        debugPrint('  - scheduleId: $scheduleId');
        debugPrint('  - timestamp: $timestamp');

        if (timestamp != null) {
          final recordDate = timestamp.toDate();
          final isToday = recordDate.year == now.year &&
                          recordDate.month == now.month &&
                          recordDate.day == now.day;

          debugPrint('  - recordDate: $recordDate, isToday: $isToday');

          if (!isToday) {
            shouldDelete = true;
            reason = 'Not created today (Created on $recordDate)';
          } else {
            // Created today: check if class hours have finished
            if (scheduleId != null && scheduleId != 'general') {
              final schedule = _cachedSchedules![scheduleId];
              if (schedule != null) {
                final jamMulai = schedule['jamMulai'] ?? '00:00';
                final jamSelesai = schedule['jamSelesai'] ?? '00:00';
                final nowMinutes = now.hour * 60 + now.minute;
                final endMinutes = _timeToMinutes(jamSelesai);
                debugPrint('  - Schedule found: $jamMulai - $jamSelesai. nowMinutes: $nowMinutes, endMinutes: $endMinutes');
                if (nowMinutes > endMinutes) {
                  shouldDelete = true;
                  reason = 'Today\'s class ended at $jamSelesai (now: ${now.hour}:${now.minute})';
                } else {
                  reason = 'Today\'s class is ongoing or hasn\'t started yet (ends at $jamSelesai)';
                }
              } else {
                shouldDelete = true;
                reason = 'Schedule ID $scheduleId not found in cached schedules';
              }
            } else {
              reason = 'Schedule ID is general or null, keeping until 24h fallback';
            }
          }
        } else {
          // If timestamp is null, we should delete it to avoid leaving orphaned records forever
          shouldDelete = true;
          reason = 'Timestamp is null (orphaned/corrupted record)';
        }

        // Fallback TTL: older than 24 hours
        if (!shouldDelete && timestamp != null) {
          final timeDiff = now.difference(timestamp.toDate());
          if (timeDiff > ttlDuration) {
            shouldDelete = true;
            reason = 'Older than 24 hours (age: ${timeDiff.inHours} hours)';
          }
        }

        debugPrint('  -> Outcome: shouldDelete = $shouldDelete, Reason: $reason');

        if (shouldDelete) {
          batch.delete(doc.reference);
          hasDeletions = true;
        }
      }

      if (hasDeletions) {
        await batch.commit();
        debugPrint('Auto-cleanup: Committed deletions batch successfully.');
      } else {
        debugPrint('Auto-cleanup: No records to delete.');
      }
    } catch (e, stackTrace) {
      debugPrint('Auto-cleanup error: $e');
      debugPrint('Auto-cleanup stack trace: $stackTrace');
    }
  }

  Future<void> _confirmClearAll(BuildContext context, String schoolId) async {
    final bool isDark = AuthBackground.isDarkMode.value;
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF0F0C20) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.1),
          ),
        ),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444)),
            const SizedBox(width: 10),
            Text(
              'Hapus Semua Catatan',
              style: TextStyle(
                color: isDark ? Colors.white : const Color(0xFF1E1B4B),
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
        content: Text(
          'Apakah Anda yakin ingin menghapus semua catatan perilaku murid? Tindakan ini tidak dapat dibatalkan.',
          style: TextStyle(
            color: isDark ? Colors.white70 : const Color(0xFF1E1B4B).withValues(alpha: 0.8),
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Hapus Semua', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _studentService.clearAllBehaviorRecords(schoolId);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Semua catatan perilaku berhasil dihapus.'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menghapus catatan: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = SessionService.currentUser!;

    return ValueListenableBuilder<bool>(
      valueListenable: AuthBackground.isDarkMode,
      builder: (context, isDark, _) {
        final textColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
        final subTextColor = isDark ? Colors.white.withValues(alpha: 0.5) : const Color(0xFF1E1B4B).withValues(alpha: 0.6);
        final cardBgColor = isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white;
        final cardBorderColor = isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.08);
        final iconBgColor = isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05);
        final iconColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
        final inputFillColor = isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04);
        final shadowColor = isDark ? Colors.transparent : Colors.black.withValues(alpha: 0.04);
        final tableHeaderBg = isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05);
        final tableHeaderBorder = isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.08);
        final tableRowBg = isDark ? Colors.white.withValues(alpha: 0.03) : Colors.white;
        final tableRowBorder = isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04);
        final tableRowBorderRight = isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06);

        return Scaffold(
          body: AuthBackground(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _schedulesStream,
              builder: (context, scheduleSnapshot) {
                final teacherSchedules = scheduleSnapshot.data?.docs.map((e) => e.data()).toList() ?? [];
                final todayHari = _getTodayHariIndonesian();

                // Filter schedules for today
                final todaySchedules = teacherSchedules
                    .where((s) => s['hari'] == todayHari && s['jenisJadwal'] != 'istirahat')
                    .toList();

                // Find currently active schedules
                final activeSchedules = todaySchedules.where(_isActiveNow).toList();
                final activeScheduleIds = activeSchedules.map((s) => s['scheduleId'] as String).toList();
                final todayScheduleIds = todaySchedules.map((s) => s['scheduleId'] as String).toList();

                debugPrint('=== DEBUG Realtime Control ===');
                debugPrint('Teacher ID: ${widget.teacherId}');
                debugPrint('Today Hari: $todayHari');
                debugPrint('Teacher Schedules total count: ${teacherSchedules.length}');
                debugPrint('Today Schedules count: ${todaySchedules.length}');
                debugPrint('Active Schedules count: ${activeSchedules.length}');
                debugPrint('Active Schedule IDs: $activeScheduleIds');
                debugPrint('Today Schedule IDs: $todayScheduleIds');

                return CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    // AppBar
                    SliverAppBar(
                      backgroundColor: Colors.transparent,
                      elevation: 0,
                      pinned: true,
                      automaticallyImplyLeading: !widget.hideBackButton,
                      leading: widget.hideBackButton
                          ? null
                          : Container(
                              margin: const EdgeInsets.only(left: 16),
                              decoration: BoxDecoration(
                                color: iconBgColor,
                                shape: BoxShape.circle,
                              ),
                              child: IconButton(
                                icon: Icon(Icons.arrow_back_ios_new_rounded, color: iconColor, size: 18),
                                onPressed: () => Navigator.pop(context),
                              ),
                            ),
                      title: Text(
                        'Realtime Control',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: textColor),
                      ),
                      actions: [
                        Container(
                          margin: const EdgeInsets.only(right: 16),
                          decoration: BoxDecoration(
                            color: iconBgColor,
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            icon: Icon(Icons.delete_sweep_rounded, color: iconColor, size: 20),
                            tooltip: 'Bersihkan Semua',
                            onPressed: () => _confirmClearAll(context, user.schoolId),
                          ),
                        ),
                      ],
                    ),

                    // Active Subject Information Card
                    if (activeSchedules.isNotEmpty)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.3),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.menu_book_rounded, color: Colors.white, size: 18),
                                    const SizedBox(width: 8),
                                    Text(
                                      activeSchedules.length > 1 ? 'Mata Pelajaran Aktif' : 'Mata Pelajaran Aktif Saat Ini',
                                      style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                ...activeSchedules.map((s) {
                                  final name = s['subjectName'] ?? 'Pelajaran';
                                  final cName = s['className'] ?? 'Kelas';
                                  final start = s['jamMulai'] ?? '00:00';
                                  final end = s['jamSelesai'] ?? '00:00';
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      '$name ($cName) • $start - $end WIB',
                                      style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                                    ),
                                  );
                                }),
                              ],
                            ),
                          ),
                        ),
                      )
                    else
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: cardBgColor,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: cardBorderColor),
                              boxShadow: isDark ? [] : [
                                BoxShadow(
                                  color: shadowColor,
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.info_outline_rounded, color: Colors.amber, size: 18),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Tidak ada mata pelajaran yang sedang aktif saat ini.',
                                    style: TextStyle(color: subTextColor, fontSize: 12, fontWeight: FontWeight.w500),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                    // Search Box
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        child: TextField(
                          controller: _searchController,
                          onChanged: (value) {
                            setState(() {
                              _searchQuery = value.toLowerCase();
                            });
                          },
                          style: TextStyle(color: textColor, fontSize: 14),
                          decoration: InputDecoration(
                            hintText: 'Cari nama murid...',
                            hintStyle: TextStyle(color: subTextColor, fontSize: 14),
                            prefixIcon: Icon(Icons.search_rounded, color: subTextColor),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: Icon(Icons.clear_rounded, color: subTextColor, size: 18),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() {
                                        _searchQuery = '';
                                      });
                                    },
                                  )
                                : null,
                            fillColor: inputFillColor,
                            filled: true,
                            contentPadding: const EdgeInsets.symmetric(vertical: 14),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(color: cardBorderColor),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(color: Color(0xFF8B5CF6)),
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Combined Attendance and Behavior Status Table
                    StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: _attendanceStream,
                      builder: (context, attendanceSnapshot) {
                        if (attendanceSnapshot.hasError) {
                          return const SliverFillRemaining(
                            child: Center(
                              child: Text(
                                'Gagal memuat data absensi',
                                style: TextStyle(color: Colors.redAccent),
                              ),
                            ),
                          );
                        }

                        if (attendanceSnapshot.connectionState == ConnectionState.waiting) {
                          return SliverFillRemaining(
                            child: Center(
                              child: CircularProgressIndicator(color: isDark ? Colors.white : const Color(0xFF8B5CF6)),
                            ),
                          );
                        }

                        final attendanceDocs = attendanceSnapshot.data?.docs ?? [];

                        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                          stream: _behaviorStream,
                          builder: (context, behaviorSnapshot) {
                            if (behaviorSnapshot.hasError) {
                              return const SliverFillRemaining(
                                child: Center(
                                  child: Text(
                                    'Gagal memuat catatan perilaku',
                                    style: TextStyle(color: Colors.redAccent),
                                  ),
                                ),
                              );
                            }

                            if (behaviorSnapshot.connectionState == ConnectionState.waiting) {
                              return SliverFillRemaining(
                                child: Center(
                                  child: CircularProgressIndicator(color: isDark ? Colors.white : const Color(0xFF8B5CF6)),
                                ),
                              );
                            }

                            final behaviorDocs = behaviorSnapshot.data?.docs ?? [];

                            // Filter attendance by Search query and active schedules only
                            final targetScheduleIds = activeScheduleIds;
                            final filteredAttendance = attendanceDocs.where((doc) {
                              final data = doc.data();
                              final studentName = (data['studentName'] ?? '').toString().toLowerCase();
                              final scheduleId = (data['scheduleId'] ?? '').toString();

                              final matchesSearch = studentName.contains(_searchQuery);
                              final matchesSchedule = targetScheduleIds.contains(scheduleId);

                              return matchesSearch && matchesSchedule;
                            }).toList();

                            if (filteredAttendance.isEmpty) {
                              return SliverFillRemaining(
                                hasScrollBody: false,
                                child: Padding(
                                  padding: const EdgeInsets.all(32.0),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.people_outline_rounded,
                                        size: 64,
                                        color: subTextColor.withValues(alpha: 0.3),
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        activeScheduleIds.isNotEmpty
                                            ? 'Belum ada murid yang absen pada pelajaran yang berlangsung'
                                            : 'Tidak ada pelajaran yang sedang aktif sekarang',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: subTextColor,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }

                            return SliverPadding(
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                              sliver: SliverMainAxisGroup(
                                slivers: [
                                  // Table Header
                                  SliverToBoxAdapter(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                      decoration: BoxDecoration(
                                        color: tableHeaderBg,
                                        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                                        border: Border.all(color: tableHeaderBorder),
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            flex: 3,
                                            child: Text(
                                              'NAMA MURID',
                                              style: TextStyle(
                                                color: isDark ? Colors.white70 : const Color(0xFF1E1B4B).withValues(alpha: 0.7),
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                letterSpacing: 0.5,
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            flex: 2,
                                            child: Text(
                                              'KELAS',
                                              style: TextStyle(
                                                color: isDark ? Colors.white70 : const Color(0xFF1E1B4B).withValues(alpha: 0.7),
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                letterSpacing: 0.5,
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            flex: 2,
                                            child: Text(
                                              'PELAJARAN',
                                              style: TextStyle(
                                                color: isDark ? Colors.white70 : const Color(0xFF1E1B4B).withValues(alpha: 0.7),
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                letterSpacing: 0.5,
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            flex: 3,
                                            child: Text(
                                              'STATUS',
                                              style: TextStyle(
                                                color: isDark ? Colors.white70 : const Color(0xFF1E1B4B).withValues(alpha: 0.7),
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                letterSpacing: 0.5,
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),

                                  // Table Body
                                  SliverList(
                                    delegate: SliverChildBuilderDelegate(
                                      (context, index) {
                                        final doc = filteredAttendance[index];
                                        final data = doc.data();
                                        final studentId = data['studentId'] ?? '';
                                        final studentName = data['studentName'] ?? 'Murid';
                                        final className = data['className'] ?? 'Kelas';
                                        final subjectName = data['subjectName'] ?? 'Pelajaran';
                                        final scheduleId = data['scheduleId'] ?? '';

                                        // Find the latest behavior record for this student and specific schedule
                                        Map<String, dynamic>? latestRecord;
                                        for (final bDoc in behaviorDocs) {
                                          final bData = bDoc.data();
                                          if (bData['studentId'] == studentId && bData['scheduleId'] == scheduleId) {
                                            latestRecord = bData;
                                            break;
                                          }
                                        }

                                        final type = latestRecord?['type']?.toString() ?? '';
                                        final isKeluar = type.toLowerCase().contains('meninggalkan') ||
                                            type.toLowerCase().contains('keluar') ||
                                            type.toLowerCase().contains('logout');
                                        final isScreenOff = type.toLowerCase().contains('layar mati') || type.toLowerCase().contains('terkunci');
                                        final isStandby = !isKeluar && !isScreenOff;

                                        final borderThemeColor = isKeluar ? const Color(0xFFEF4444) : const Color(0xFF10B981);
                                        final isLastRow = index == filteredAttendance.length - 1;

                                        final rowWidget = Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                          decoration: BoxDecoration(
                                            color: tableRowBg,
                                            border: Border(
                                              left: BorderSide(color: borderThemeColor.withValues(alpha: 0.6), width: 4),
                                              right: BorderSide(color: tableRowBorderRight),
                                              bottom: BorderSide(
                                                color: isLastRow
                                                    ? tableRowBorderRight
                                                    : tableRowBorder,
                                              ),
                                              top: index == 0
                                                  ? BorderSide.none
                                                  : BorderSide(color: tableRowBorder),
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              Expanded(
                                                flex: 3,
                                                child: Text(
                                                  studentName,
                                                  style: TextStyle(
                                                    color: textColor,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 13,
                                                  ),
                                                ),
                                              ),
                                              Expanded(
                                                flex: 2,
                                                child: Text(
                                                  className,
                                                  style: TextStyle(
                                                    color: subTextColor,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ),
                                              Expanded(
                                                flex: 2,
                                                child: Text(
                                                  subjectName,
                                                  style: TextStyle(
                                                    color: subTextColor,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ),
                                              Expanded(
                                                flex: 3,
                                                child: FittedBox(
                                                  fit: BoxFit.scaleDown,
                                                  child: Row(
                                                    mainAxisAlignment: MainAxisAlignment.center,
                                                    children: [
                                                      if (isStandby) ...[
                                                        const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 16),
                                                        const SizedBox(width: 4),
                                                        const Text(
                                                          'Standby',
                                                          style: TextStyle(
                                                            color: Color(0xFF10B981),
                                                            fontSize: 12,
                                                            fontWeight: FontWeight.bold,
                                                          ),
                                                        ),
                                                      ] else if (isKeluar) ...[
                                                        const Icon(Icons.cancel_rounded, color: Color(0xFFEF4444), size: 16),
                                                        const SizedBox(width: 4),
                                                        const Text(
                                                          'Keluar',
                                                          style: TextStyle(
                                                            color: Color(0xFFEF4444),
                                                            fontSize: 12,
                                                            fontWeight: FontWeight.bold,
                                                          ),
                                                        ),
                                                      ] else if (isScreenOff) ...[
                                                        const SizedBox(width: 4),
                                                        const Text(
                                                          'Screen Off',
                                                          style: TextStyle(
                                                            color: Color(0xFF10B981),
                                                            fontSize: 11,
                                                            fontWeight: FontWeight.bold,
                                                          ),
                                                        ),
                                                      ],
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        );

                                        if (isLastRow) {
                                          return ClipRRect(
                                            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                                            child: rowWidget,
                                          );
                                        }
                                        return rowWidget;
                                      },
                                      childCount: filteredAttendance.length,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                      },
                    ),
                    const SliverToBoxAdapter(
                      child: SizedBox(height: 40),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }
}
