import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/services/session_service.dart';
import '../../authentication/widgets/auth_background.dart';
import '../data/officer_repository.dart';

class ManualAttendancePage extends StatefulWidget {
  const ManualAttendancePage({super.key});

  @override
  State<ManualAttendancePage> createState() => _ManualAttendancePageState();
}

class _ManualAttendancePageState extends State<ManualAttendancePage> {
  final OfficerRepository _repo = OfficerRepository();
  final TextEditingController _searchController = TextEditingController();
  
  String _searchQuery = '';
  bool _isLoading = false;

  // Stats state
  int? _totalStudentsCount;
  int? _attendedStudentsCount;
  bool _isLoadingCounts = true;

  // Local memory for students to enable instant substring search
  List<Map<String, dynamic>> _allStudents = [];
  bool _isLoadingStudents = false;

  @override
  void initState() {
    super.initState();
    _fetchCounts();
    _loadAllStudents();
  }

  Future<void> _fetchCounts() async {
    if (!mounted) return;
    setState(() => _isLoadingCounts = true);
    try {
      final user = SessionService.currentUser!;
      final dateStr = '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}';

      // 1. Hitung total siswa aktif
      final totalQuery = await FirebaseFirestore.instance
          .collection('schools')
          .doc(user.schoolId)
          .collection('students')
          .where('aktif', isEqualTo: true)
          .count()
          .get();

      // 2. Hitung siswa yang sudah absen hari ini
      final attendedQuery = await FirebaseFirestore.instance
          .collection('schools')
          .doc(user.schoolId)
          .collection('daily_attendance')
          .where('date', isEqualTo: dateStr)
          .count()
          .get();

      if (mounted) {
        setState(() {
          _totalStudentsCount = totalQuery.count;
          _attendedStudentsCount = attendedQuery.count;
          _isLoadingCounts = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching counts: $e');
      if (mounted) {
        setState(() => _isLoadingCounts = false);
      }
    }
  }

  Future<void> _loadAllStudents() async {
    if (!mounted) return;
    setState(() => _isLoadingStudents = true);
    try {
      final user = SessionService.currentUser!;
      final query = await FirebaseFirestore.instance
          .collection('schools')
          .doc(user.schoolId)
          .collection('students')
          .where('aktif', isEqualTo: true)
          .get();

      final list = query.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          ...data,
        };
      }).toList();

      // Sort alphabetically by name
      list.sort((a, b) {
        final nameA = (a['nama'] ?? '').toString().toLowerCase();
        final nameB = (b['nama'] ?? '').toString().toLowerCase();
        return nameA.compareTo(nameB);
      });

      if (mounted) {
        setState(() {
          _allStudents = list;
          _isLoadingStudents = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading all students: $e');
      if (mounted) {
        setState(() => _isLoadingStudents = false);
      }
    }
  }

  void _showAttendanceDialog(Map<String, dynamic> student, String studentId) {
    final statuses = ['hadir', 'terlambat', 'alpha', 'izin', 'sakit'];
    String selectedStatus = 'hadir';

    Get.dialog(
      StatefulBuilder(
        builder: (context, setStateDialog) {
          final isDark = AuthBackground.isDarkMode.value;
          final textColor = isDark ? Colors.white : const Color(0xFF1E1B4B);

          return Dialog(
            backgroundColor: isDark ? const Color(0xFF1E1B4B) : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Absen Manual',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Siswa: ${student['nama'] ?? '-'}',
                    style: TextStyle(fontSize: 14, color: textColor),
                  ),
                  Text(
                    'Kelas: ${student['className'] ?? '-'}',
                    style: TextStyle(fontSize: 14, color: textColor.withValues(alpha: 0.7)),
                  ),
                  const SizedBox(height: 24),
                  Text('Pilih Status:', style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: selectedStatus,
                    dropdownColor: isDark ? const Color(0xFF1E1B4B) : Colors.white,
                    style: TextStyle(color: textColor),
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: textColor.withValues(alpha: 0.3)),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    items: statuses.map((status) {
                      return DropdownMenuItem(
                        value: status,
                        child: Text(status.toUpperCase(), style: TextStyle(color: textColor)),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setStateDialog(() => selectedStatus = val);
                      }
                    },
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Get.back(),
                        child: const Text('Batal'),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: () async {
                          Get.back();
                          _submitManual(student, studentId, selectedStatus);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6366F1),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Simpan', style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }
      ),
    );
  }

  Future<void> _submitManual(Map<String, dynamic> student, String studentId, String status) async {
    setState(() => _isLoading = true);
    try {
      final user = SessionService.currentUser!;
      
      final hasScanned = await _repo.hasStudentScannedToday(user.schoolId, studentId);
      if (hasScanned) {
        Get.snackbar(
          'Peringatan', 
          'Siswa ini sudah melakukan scan/absen hari ini.',
          backgroundColor: Colors.amber,
          colorText: Colors.black,
        );
        return;
      }

      await _repo.markManualAttendance(
        schoolId: user.schoolId,
        studentId: studentId,
        studentName: student['nama'] ?? '-',
        classId: student['classId'] ?? '',
        className: student['className'] ?? '-',
        officerId: user.uid,
        status: status,
      );

      Get.snackbar(
        'Berhasil', 
        'Absen manual berhasil disimpan.',
        backgroundColor: const Color(0xFF10B981),
        colorText: Colors.white,
      );

      // Refresh stats
      _fetchCounts();

    } catch (e) {
      Get.snackbar('Error', e.toString(), backgroundColor: Colors.red, colorText: Colors.white);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = SessionService.currentUser!;

    return ValueListenableBuilder<bool>(
      valueListenable: AuthBackground.isDarkMode,
      builder: (context, isDark, _) {
        final textColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
        final subTextColor = isDark
            ? Colors.white.withValues(alpha: 0.5)
            : const Color(0xFF1E1B4B).withValues(alpha: 0.5);
        final cardBg = isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white;
        final cardBorder = isDark
            ? Colors.white.withValues(alpha: 0.1)
            : Colors.black.withValues(alpha: 0.08);

        return Scaffold(
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            iconTheme: IconThemeData(color: textColor),
            title: Text(
              'Absensi Manual',
              style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
            ),
          ),
          body: AuthBackground(
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    TextField(
                      controller: _searchController,
                      style: TextStyle(color: textColor),
                      onChanged: (val) {
                        setState(() => _searchQuery = val.trim());
                      },
                      decoration: InputDecoration(
                        hintText: 'Cari nama siswa...',
                        hintStyle: TextStyle(color: subTextColor),
                        prefixIcon: Icon(Icons.search_rounded, color: subTextColor),
                        filled: true,
                        fillColor: isDark ? Colors.white.withValues(alpha: 0.02) : Colors.black.withValues(alpha: 0.02),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: cardBorder),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    if (_isLoading || (_isLoadingStudents && _allStudents.isEmpty))
                      const LinearProgressIndicator(color: Color(0xFF6366F1)),
                      
                    Expanded(
                      child: _searchQuery.isEmpty
                          ? _buildStatsOverview(isDark, textColor, subTextColor, cardBg, cardBorder)
                          : _buildSearchResultsList(user.schoolId, isDark, textColor, subTextColor, cardBg, cardBorder),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatsOverview(
    bool isDark,
    Color textColor,
    Color subTextColor,
    Color cardBg,
    Color cardBorder,
  ) {
    if (_isLoadingCounts) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF6366F1)),
      );
    }

    final total = _totalStudentsCount ?? 0;
    final attended = _attendedStudentsCount ?? 0;
    final absent = total - attended;

    return RefreshIndicator(
      onRefresh: () async {
        await _fetchCounts();
        await _loadAllStudents();
      },
      color: const Color(0xFF6366F1),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        children: [
          const SizedBox(height: 16),
          // Ringkasan Statistik Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: cardBorder),
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.analytics_rounded,
                  color: Color(0xFF6366F1),
                  size: 48,
                ),
                const SizedBox(height: 16),
                Text(
                  'Statistik Absensi Hari Ini',
                  style: TextStyle(
                    color: textColor,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildStatItem('Total Siswa', total.toString(), const Color(0xFF8B5CF6)),
                    _buildStatItem('Sudah Absen', attended.toString(), const Color(0xFF10B981)),
                    _buildStatItem('Belum Absen', absent.toString(), const Color(0xFFEF4444)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          // Panduan
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  Icon(
                    Icons.search_rounded,
                    color: subTextColor.withValues(alpha: 0.5),
                    size: 40,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Pencarian Siswa',
                    style: TextStyle(
                      color: textColor.withValues(alpha: 0.8),
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Ketik nama siswa pada kolom pencarian di atas untuk melakukan absensi manual.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: subTextColor,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    final isDark = AuthBackground.isDarkMode.value;
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 28,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: isDark ? Colors.white.withValues(alpha: 0.6) : const Color(0xFF1E1B4B).withValues(alpha: 0.6),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildSearchResultsList(
    String schoolId,
    bool isDark,
    Color textColor,
    Color subTextColor,
    Color cardBg,
    Color cardBorder,
  ) {
    final queryStr = _searchQuery.toLowerCase();
    
    // Substring filter in memory
    final filtered = _allStudents.where((student) {
      final name = (student['nama'] ?? '').toString().toLowerCase();
      final nis = (student['nis'] ?? '').toString().toLowerCase();
      return name.contains(queryStr) || nis.contains(queryStr);
    }).toList();

    // Limit display item for high performance rendering
    final limit = filtered.length > 50 ? 50 : filtered.length;
    final displayList = filtered.sublist(0, limit);

    if (displayList.isEmpty) {
      return Center(
        child: Text(
          'Tidak ada siswa yang ditemukan',
          style: TextStyle(color: subTextColor),
        ),
      );
    }

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      itemCount: displayList.length,
      itemBuilder: (context, index) {
        final student = displayList[index];
        final studentId = student['id'] ?? '';

        return FutureBuilder<bool>(
          future: _repo.hasStudentScannedToday(schoolId, studentId),
          builder: (context, attendanceSnapshot) {
            final hasCheckedIn = attendanceSnapshot.data ?? false;

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: cardBorder),
              ),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: const Color(0xFF8B5CF6).withValues(alpha: 0.2),
                  child: const Icon(Icons.person, color: Color(0xFF8B5CF6)),
                ),
                title: Text(
                  student['nama'] ?? '-',
                  style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  'Kelas: ${student['className'] ?? '-'}',
                  style: TextStyle(color: subTextColor, fontSize: 12),
                ),
                trailing: hasCheckedIn
                    ? Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: const Color(0xFF10B981).withValues(alpha: 0.3),
                          ),
                        ),
                        child: const Text(
                          'Sudah Absen',
                          style: TextStyle(
                            color: Color(0xFF10B981),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      )
                    : ElevatedButton(
                        onPressed: () => _showAttendanceDialog(student, studentId),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6366F1),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                        ),
                        child: const Text('Absen', style: TextStyle(color: Colors.white, fontSize: 12)),
                      ),
              ),
            );
          },
        );
      },
    );
  }
}
