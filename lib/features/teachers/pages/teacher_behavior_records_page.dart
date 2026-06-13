import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';


import '../../../core/services/session_service.dart';
import '../../authentication/widgets/auth_background.dart';
import '../../students/data/student_service.dart';

class TeacherBehaviorRecordsPage extends StatefulWidget {
  const TeacherBehaviorRecordsPage({super.key});

  @override
  State<TeacherBehaviorRecordsPage> createState() => _TeacherBehaviorRecordsPageState();
}

class _TeacherBehaviorRecordsPageState extends State<TeacherBehaviorRecordsPage> {
  final _studentService = StudentService();
  final _searchController = TextEditingController();
  String _selectedClass = 'Semua Kelas';
  String _searchQuery = '';
  Timer? _cleanupTimer;

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

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return '--:--';
    final dt = timestamp.toDate().toLocal();
    final days = ['Minggu', 'Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu'];
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
      'Jul', 'Ags', 'Sep', 'Okt', 'Nov', 'Des'
    ];
    final dayName = days[dt.weekday % 7];
    final monthName = months[dt.month - 1];
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');

    return '$dayName, ${dt.day} $monthName ${dt.year} pukul $hour:$minute WIB';
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
        child: CustomScrollView(
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
                'Catatan Perilaku Murid',
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
                      stream: _studentService.getBehaviorRecords(user.schoolId),
                      builder: (context, snapshot) {
                        final records = snapshot.data?.docs.map((doc) => doc.data()).toList() ?? [];
                        
                        // Extract unique class names
                        final classNames = records
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

            // Behavior logs list
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _studentService.getBehaviorRecords(user.schoolId),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const SliverFillRemaining(
                    child: Center(
                      child: Text(
                        'Gagal memuat catatan perilaku',
                        style: TextStyle(color: Colors.redAccent),
                      ),
                    ),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SliverFillRemaining(
                    child: Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    ),
                  );
                }

                final rawRecords = snapshot.data?.docs.map((doc) => doc.data()).toList() ?? [];
                
                // Filter by Class and Search query
                final filteredRecords = rawRecords.where((r) {
                  final sName = (r['studentName'] ?? '').toString().toLowerCase();
                  final cName = (r['className'] ?? '').toString();

                  final matchesClass = _selectedClass == 'Semua Kelas' || cName == _selectedClass;
                  final matchesSearch = sName.contains(_searchQuery);

                  return matchesClass && matchesSearch;
                }).toList();

                if (filteredRecords.isEmpty) {
                  return SliverFillRemaining(
                    hasScrollBody: false,
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.check_circle_outline_rounded,
                            size: 64,
                            color: Colors.white.withValues(alpha: 0.15),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Tidak ada catatan perilaku mencurigakan',
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
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final r = filteredRecords[index];
                        final studentName = r['studentName'] ?? 'Murid';
                        final className = r['className'] ?? 'Kelas';
                        final subjectName = r['subjectName'] ?? 'Pelajaran';
                        final description = r['description'] ?? '-';
                        final timestamp = r['timestamp'] as Timestamp?;
                        final type = r['type'] ?? 'Meninggalkan Layar Absensi';
                        final recordId = r['recordId'] ?? '${studentName}_$index';

                        final isViolation = !type.toString().toLowerCase().contains('kembali') && 
                                            !type.toString().toLowerCase().contains('standby');
                        final themeColor = isViolation ? const Color(0xFFEF4444) : const Color(0xFF10B981);
                        final descTextColor = isViolation ? Colors.amberAccent : const Color(0xFF10B981);

                        return Dismissible(
                          key: Key(recordId),
                          direction: DismissDirection.horizontal,
                          background: Container(
                            margin: const EdgeInsets.only(bottom: 14),
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEF4444).withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.3)),
                            ),
                            alignment: Alignment.centerLeft,
                            child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
                          ),
                          secondaryBackground: Container(
                            margin: const EdgeInsets.only(bottom: 14),
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEF4444).withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.3)),
                            ),
                            alignment: Alignment.centerRight,
                            child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
                          ),
                          confirmDismiss: (direction) async {
                            return await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                backgroundColor: const Color(0xFF0F0C20),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                  side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                                ),
                                title: const Row(
                                  children: [
                                    Icon(Icons.delete_rounded, color: Color(0xFFEF4444)),
                                    SizedBox(width: 10),
                                    Text(
                                      'Hapus Catatan',
                                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                                    ),
                                  ],
                                ),
                                content: const Text(
                                  'Apakah Anda yakin ingin menghapus catatan perilaku ini?',
                                  style: TextStyle(color: Colors.white70, fontSize: 14),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context, false),
                                    child: Text(
                                      'Batal',
                                      style: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
                                    ),
                                  ),
                                  ElevatedButton(
                                    onPressed: () => Navigator.pop(context, true),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFFEF4444),
                                      foregroundColor: Colors.white,
                                    ),
                                    child: const Text('Hapus', style: TextStyle(fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ),
                            );
                          },
                          onDismissed: (direction) async {
                            try {
                              await _studentService.deleteBehaviorRecord(user.schoolId, recordId);
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
                          },
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 14),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: themeColor.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: themeColor.withValues(alpha: 0.25)),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.15),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Top Row: Student Name and Class Name Badge
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        studentName,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: themeColor.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: themeColor.withValues(alpha: 0.4)),
                                      ),
                                      child: Text(
                                        isViolation ? 'Keluar' : 'Standby',
                                        style: TextStyle(
                                          color: themeColor,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: const Color(0xFF8B5CF6).withValues(alpha: 0.4)),
                                      ),
                                      child: Text(
                                        className,
                                        style: const TextStyle(
                                          color: Color(0xFF8B5CF6),
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),

                                // Pelajaran / Subject
                                Row(
                                  children: [
                                    Icon(Icons.menu_book_rounded, color: Colors.white.withValues(alpha: 0.4), size: 14),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Pelajaran: $subjectName',
                                      style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.7),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),

                                // Description of warning
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    description,
                                    style: TextStyle(
                                      color: descTextColor,
                                      fontSize: 12,
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 10),

                                // Timestamp footer
                                Row(
                                  children: [
                                    Icon(Icons.access_time_rounded, color: Colors.white.withValues(alpha: 0.35), size: 12),
                                    const SizedBox(width: 6),
                                    Text(
                                      _formatTimestamp(timestamp),
                                      style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.35),
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                      childCount: filteredRecords.length,
                    ),
                  ),
                );
              },
            ),
            
            const SliverToBoxAdapter(
              child: SizedBox(height: 40),
            ),
          ],
        ),
      ),
    );
  }
}
