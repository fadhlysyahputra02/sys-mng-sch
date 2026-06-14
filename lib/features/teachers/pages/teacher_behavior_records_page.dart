import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';


import '../../../core/services/session_service.dart';
import '../../authentication/widgets/auth_background.dart';
import '../../students/data/student_service.dart';
import '../../schools/pages/schedule/Service/class_schedule_service.dart';

class TeacherBehaviorRecordsPage extends StatefulWidget {
  final String teacherId;
  const TeacherBehaviorRecordsPage({super.key, required this.teacherId});

  @override
  State<TeacherBehaviorRecordsPage> createState() => _TeacherBehaviorRecordsPageState();
}

class _TeacherBehaviorRecordsPageState extends State<TeacherBehaviorRecordsPage> {
  final _studentService = StudentService();
  final _searchController = TextEditingController();
  String _selectedClass = 'Semua Kelas';
  String _searchQuery = '';
  Timer? _cleanupTimer;

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
      _runCleanup(user.schoolId);
    });
  }

  Future<void> _runCleanup(String schoolId) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('schools')
          .doc(schoolId)
          .collection('behavior_records')
          .get();

      final now = DateTime.now();
      // 24 hours for auto-cleanup.
      const ttlDuration = Duration(hours: 24);

      final batch = FirebaseFirestore.instance.batch();
      bool hasDeletions = false;

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final timestamp = data['timestamp'] as Timestamp?;
        if (timestamp != null) {
          final timeDiff = now.difference(timestamp.toDate());
          if (timeDiff > ttlDuration) {
            batch.delete(doc.reference);
            hasDeletions = true;
            debugPrint('Auto-cleanup: Queued deletion for record ${doc.id} (age: ${timeDiff.inSeconds}s)');
          }
        }
      }

      if (hasDeletions) {
        await batch.commit();
        debugPrint('Auto-cleanup: Committed deletions batch successfully.');
      }
    } catch (e) {
      debugPrint('Auto-cleanup error: $e');
    }
  }

  Future<void> _confirmClearAll(BuildContext context, String schoolId) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0F0C20),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444)),
            SizedBox(width: 10),
            Text(
              'Hapus Semua Catatan',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        content: const Text(
          'Apakah Anda yakin ingin menghapus semua catatan perilaku murid? Tindakan ini tidak dapat dibatalkan.',
          style: TextStyle(color: Colors.white70, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Batal',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontWeight: FontWeight.w600),
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

    return Scaffold(
      body: AuthBackground(
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: ClassScheduleService().getSchedulesByTeacher(user.schoolId, widget.teacherId),
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
                  iconTheme: const IconThemeData(color: Colors.white),
                  leading: Container(
                    margin: const EdgeInsets.only(left: 16),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  title: const Text(
                    'Realtime Control',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
                  ),
                  actions: [
                    Container(
                      margin: const EdgeInsets.only(right: 16),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.delete_sweep_rounded, color: Colors.white, size: 20),
                        tooltip: 'Bersihkan Semua',
                        onPressed: () => _confirmClearAll(context, user.schoolId),
                      ),
                    ),
                  ],
                ),

                // Filters & Search Box
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Search Bar
                        TextField(
                          controller: _searchController,
                          onChanged: (value) {
                            setState(() {
                              _searchQuery = value.toLowerCase();
                            });
                          },
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                          decoration: InputDecoration(
                            hintText: 'Cari nama murid...',
                            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.45), fontSize: 14),
                            prefixIcon: Icon(Icons.search_rounded, color: Colors.white.withValues(alpha: 0.6)),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear_rounded, color: Colors.white54, size: 18),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() {
                                        _searchQuery = '';
                                      });
                                    },
                                  )
                                : null,
                            fillColor: Colors.white.withValues(alpha: 0.05),
                            filled: true,
                            contentPadding: const EdgeInsets.symmetric(vertical: 14),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(color: Color(0xFF8B5CF6)),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Filter dropdown
                        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                          stream: _studentService.getTodayAttendanceListStream(
                            schoolId: user.schoolId,
                            dateStr: _getTodayDateStr(),
                          ),
                          builder: (context, snapshot) {
                            final records = snapshot.data?.docs.map((doc) => doc.data()).toList() ?? [];
                            
                            // Extract unique class names only for teacher's today's schedules
                            final classNames = records
                                .where((r) => todayScheduleIds.contains(r['scheduleId']))
                                .map((r) => r['className'] as String?)
                                .whereType<String>()
                                .toSet()
                                .toList();
                            classNames.sort();

                            return Row(
                              children: [
                                Icon(Icons.filter_list_rounded, color: Colors.white.withValues(alpha: 0.5), size: 16),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.04),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                                    ),
                                    child: DropdownButtonHideUnderline(
                                      child: DropdownButton<String>(
                                        value: _selectedClass,
                                        dropdownColor: const Color(0xFF0F0C20),
                                        icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white54),
                                        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                                        items: [
                                          const DropdownMenuItem(
                                            value: 'Semua Kelas',
                                            child: Text('Semua Kelas'),
                                          ),
                                          ...classNames.map((cName) => DropdownMenuItem(
                                                value: cName,
                                                child: Text(cName),
                                              )),
                                        ],
                                        onChanged: (val) {
                                          if (val != null) {
                                            setState(() {
                                              _selectedClass = val;
                                            });
                                          }
                                        },
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),

                // Combined Attendance and Behavior Status Table
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _studentService.getTodayAttendanceListStream(
                    schoolId: user.schoolId,
                    dateStr: _getTodayDateStr(),
                  ),
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
                      return const SliverFillRemaining(
                        child: Center(
                          child: CircularProgressIndicator(color: Colors.white),
                        ),
                      );
                    }

                    final attendanceDocs = attendanceSnapshot.data?.docs ?? [];

                    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: _studentService.getBehaviorRecords(user.schoolId),
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
                          return const SliverFillRemaining(
                            child: Center(
                              child: CircularProgressIndicator(color: Colors.white),
                            ),
                          );
                        }

                        final behaviorDocs = behaviorSnapshot.data?.docs ?? [];

                        // Filter attendance by Class, Search query, and active schedules (or today's schedules if none active)
                        final targetScheduleIds = activeScheduleIds.isNotEmpty ? activeScheduleIds : todayScheduleIds;
                        final filteredAttendance = attendanceDocs.where((doc) {
                          final data = doc.data();
                          final studentName = (data['studentName'] ?? '').toString().toLowerCase();
                          final className = (data['className'] ?? '').toString();
                          final scheduleId = (data['scheduleId'] ?? '').toString();

                          final matchesClass = _selectedClass == 'Semua Kelas' || className == _selectedClass;
                          final matchesSearch = studentName.contains(_searchQuery);
                          final matchesSchedule = targetScheduleIds.contains(scheduleId);

                          return matchesClass && matchesSearch && matchesSchedule;
                        }).toList();

                        debugPrint('Target Schedule IDs: $targetScheduleIds');
                        debugPrint('Raw Attendance Docs count: ${attendanceDocs.length}');
                        for (final doc in attendanceDocs) {
                          final d = doc.data();
                          debugPrint('  * Student: ${d['studentName']}, scheduleId: ${d['scheduleId']}, date: ${d['date']}, class: ${d['className']}');
                        }
                        debugPrint('Filtered Attendance Docs: ${filteredAttendance.length}');

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
                                    color: Colors.white.withValues(alpha: 0.15),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    activeScheduleIds.isNotEmpty
                                        ? 'Belum ada murid yang absen pada pelajaran yang berlangsung'
                                        : 'Belum ada murid yang melakukan absensi hari ini',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.white.withValues(alpha: 0.5),
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
                                    color: Colors.white.withValues(alpha: 0.08),
                                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                                    border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                                  ),
                                  child: const Row(
                                    children: [
                                      Expanded(
                                        flex: 3,
                                        child: Text(
                                          'NAMA MURID',
                                          style: TextStyle(
                                            color: Colors.white70,
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
                                            color: Colors.white70,
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
                                            color: Colors.white70,
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
                                            color: Colors.white70,
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

                                    // Find the latest behavior record for this student
                                    Map<String, dynamic>? latestRecord;
                                    for (final bDoc in behaviorDocs) {
                                      final bData = bDoc.data();
                                      if (bData['studentId'] == studentId) {
                                        latestRecord = bData;
                                        break;
                                      }
                                    }

                                    final type = latestRecord?['type']?.toString() ?? '';
                                    final isKeluar = type.toLowerCase().contains('meninggalkan');
                                    final isScreenOff = type.toLowerCase().contains('layar mati') || type.toLowerCase().contains('terkunci');
                                    final isStandby = !isKeluar && !isScreenOff;

                                    final borderThemeColor = isKeluar ? const Color(0xFFEF4444) : const Color(0xFF10B981);
                                    final isLastRow = index == filteredAttendance.length - 1;

                                    final rowWidget = Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.03),
                                        border: Border(
                                          left: BorderSide(color: borderThemeColor.withValues(alpha: 0.6), width: 4),
                                          right: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                                          bottom: BorderSide(
                                            color: isLastRow
                                                ? Colors.white.withValues(alpha: 0.08)
                                                : Colors.white.withValues(alpha: 0.05),
                                          ),
                                          top: index == 0
                                              ? BorderSide.none
                                              : BorderSide(color: Colors.white.withValues(alpha: 0.05)),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            flex: 3,
                                            child: Text(
                                              studentName,
                                              style: const TextStyle(
                                                color: Colors.white,
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
                                                color: Colors.white.withValues(alpha: 0.7),
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            flex: 2,
                                            child: Text(
                                              subjectName,
                                              style: TextStyle(
                                                color: Colors.white.withValues(alpha: 0.7),
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
  }
}
