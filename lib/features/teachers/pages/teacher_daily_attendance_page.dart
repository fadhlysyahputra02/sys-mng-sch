import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../../core/services/session_service.dart';
import '../../authentication/widgets/auth_background.dart';

class TeacherDailyAttendancePage extends StatefulWidget {
  final String teacherId;
  final String teacherName;
  final String nip;
  const TeacherDailyAttendancePage({
    super.key,
    required this.teacherId,
    required this.teacherName,
    required this.nip,
  });

  @override
  State<TeacherDailyAttendancePage> createState() => _TeacherDailyAttendancePageState();
}

class _TeacherDailyAttendancePageState extends State<TeacherDailyAttendancePage> {
  bool _isLoadingSchoolConfig = true;
  String _selectedTahunAjaran = '';
  String _selectedSemester = '';
  List<String> _tahunAjaranOptions = [];
  final List<String> _semesterOptions = ['Semester 1', 'Semester 2'];

  @override
  void initState() {
    super.initState();
    _loadSchoolConfig();
  }

  Future<void> _loadSchoolConfig() async {
    try {
      final user = SessionService.currentUser!;
      final schoolDoc = await FirebaseFirestore.instance
          .collection('schools')
          .doc(user.schoolId)
          .get();

      final data = schoolDoc.data();
      final currentTahunAjaran = data?['tahunAjaran'] ?? '${DateTime.now().year}/${DateTime.now().year + 1}';
      final currentSemester = data?['semester'] ?? 'Semester 1';

      _generateTahunAjaranOptions(currentTahunAjaran);

      setState(() {
        _selectedTahunAjaran = currentTahunAjaran;
        _selectedSemester = currentSemester;
        _isLoadingSchoolConfig = false;
      });
    } catch (e) {
      _generateTahunAjaranOptions('${DateTime.now().year}/${DateTime.now().year + 1}');
      setState(() {
        _selectedTahunAjaran = '${DateTime.now().year}/${DateTime.now().year + 1}';
        _selectedSemester = 'Semester 1';
        _isLoadingSchoolConfig = false;
      });
    }
  }

  void _generateTahunAjaranOptions(String currentVal) {
    final options = <String>{};
    int currentYear = DateTime.now().year;
    int currentMonth = DateTime.now().month;
    int maxStartYear = currentMonth >= 7 ? currentYear : currentYear - 1;
    
    for (int i = maxStartYear - 5; i <= maxStartYear + 1; i++) {
      options.add('$i/${i + 1}');
    }
    options.add(currentVal);
    
    setState(() {
      _tahunAjaranOptions = options.toList()..sort((a, b) => b.compareTo(a));
    });
  }

  String _getFormattedDate() {
    final now = DateTime.now();
    final days = ['Minggu', 'Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu'];
    final months = [
      'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
    ];
    return '${days[now.weekday % 7]}, ${now.day} ${months[now.month - 1]} ${now.year}';
  }

  String _formatTime(Timestamp? timestamp) {
    if (timestamp == null) return '--:--';
    final date = timestamp.toDate().toLocal();
    return '${DateFormat('HH:mm').format(date)} WIB';
  }

  String _formatFullDate(String dateStr) {
    try {
      final parts = dateStr.split('-');
      if (parts.length == 3) {
        final year = int.parse(parts[0]);
        final month = int.parse(parts[1]);
        final day = int.parse(parts[2]);
        final months = [
          'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
          'Jul', 'Agt', 'Sep', 'Okt', 'Nov', 'Des'
        ];
        return '$day ${months[month - 1]} $year';
      }
    } catch (_) {}
    return dateStr;
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    String label;
    switch (status.toLowerCase()) {
      case 'hadir':
        color = const Color(0xFF10B981);
        label = 'Hadir';
        break;
      case 'terlambat':
        color = const Color(0xFFF59E0B);
        label = 'Terlambat';
        break;
      case 'sakit':
        color = const Color(0xFF3B82F6);
        label = 'Sakit';
        break;
      case 'izin':
        color = const Color(0xFF8B5CF6);
        label = 'Izin';
        break;
      case 'alfa':
        color = const Color(0xFFEF4444);
        label = 'Alfa';
        break;
      default:
        color = Colors.grey;
        label = status.toUpperCase();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = SessionService.currentUser!;
    final schoolId = user.schoolId;

    return ValueListenableBuilder<bool>(
      valueListenable: AuthBackground.isDarkMode,
      builder: (context, isDark, child) {
        final textColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
        final subTextColor = isDark ? Colors.white.withValues(alpha: 0.6) : const Color(0xFF1E1B4B).withValues(alpha: 0.6);
        final cardColor = isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white;
        final cardBorder = isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.06);
        final shadowColor = isDark ? Colors.black.withValues(alpha: 0.2) : Colors.black.withValues(alpha: 0.04);

        return Scaffold(
          backgroundColor: isDark ? const Color(0xFF0B0914) : const Color(0xFFF8FAFC),
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back_ios_new_rounded, color: textColor),
              onPressed: () => Get.back(),
            ),
            title: Text(
              SessionService.currentUser?.role == 'teacher'
                  ? 'Absensi Harian Anda'
                  : 'Riwayat Absensi: ${widget.teacherName}',
              style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 18),
            ),
            centerTitle: true,
          ),
          body: _isLoadingSchoolConfig
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF8B5CF6)))
              : Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 12),
                      
                      // Hari Ini Status Card
                      StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                        stream: FirebaseFirestore.instance
                            .collection('schools')
                            .doc(schoolId)
                            .collection('teacher_daily_attendance')
                            .doc('${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}_${widget.teacherId}')
                            .snapshots(),
                        builder: (context, snapshot) {
                          final hasData = snapshot.hasData && snapshot.data != null && snapshot.data!.exists;
                          final data = hasData ? snapshot.data!.data() : null;

                          final checkInStr = data != null ? _formatTime(data['checkInTime'] as Timestamp?) : '--:--';
                          final checkOutStr = data != null && data['checkOutTime'] != null ? _formatTime(data['checkOutTime'] as Timestamp?) : '--:--';
                          final String status = data != null ? data['status'] ?? 'hadir' : 'Belum Absen';

                          return Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: cardColor,
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(color: cardBorder),
                              boxShadow: [
                                BoxShadow(
                                  color: shadowColor,
                                  blurRadius: 15,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.today_rounded, color: Color(0xFF6366F1), size: 18),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Presensi Hari Ini',
                                            style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 15),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            _getFormattedDate(),
                                            style: TextStyle(color: subTextColor, fontSize: 12),
                                          ),
                                        ],
                                      ),
                                    ),
                                    _buildStatusBadge(hasData ? status : 'alfa'),
                                  ],
                                ),
                                const SizedBox(height: 20),
                                Row(
                                  children: [
                                    // Check In Column
                                    Expanded(
                                      child: Container(
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          color: isDark ? Colors.white.withValues(alpha: 0.02) : const Color(0xFFF1F5F9),
                                          borderRadius: BorderRadius.circular(16),
                                          border: Border.all(color: cardBorder),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                const Icon(Icons.login_rounded, color: Color(0xFF10B981), size: 16),
                                                const SizedBox(width: 6),
                                                Text(
                                                  'Jam Masuk',
                                                  style: TextStyle(color: subTextColor, fontSize: 11, fontWeight: FontWeight.w600),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              checkInStr,
                                              style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.bold),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    // Check Out Column
                                    Expanded(
                                      child: Container(
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          color: isDark ? Colors.white.withValues(alpha: 0.02) : const Color(0xFFF1F5F9),
                                          borderRadius: BorderRadius.circular(16),
                                          border: Border.all(color: cardBorder),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                const Icon(Icons.logout_rounded, color: Colors.orange, size: 16),
                                                const SizedBox(width: 6),
                                                Text(
                                                  'Jam Pulang',
                                                  style: TextStyle(color: subTextColor, fontSize: 11, fontWeight: FontWeight.w600),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              checkOutStr,
                                              style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.bold),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      
                      const SizedBox(height: 20),

                      // Filter Card
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: cardBorder),
                          boxShadow: [
                            BoxShadow(
                              color: shadowColor,
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.filter_alt_rounded, color: Color(0xFF8B5CF6), size: 18),
                                const SizedBox(width: 8),
                                Text(
                                  'Filter Riwayat',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: textColor),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    isExpanded: true,
                                    initialValue: _selectedTahunAjaran,
                                    dropdownColor: isDark ? const Color(0xFF0F0C20) : Colors.white,
                                    decoration: InputDecoration(
                                      labelText: 'Tahun Ajaran',
                                      labelStyle: TextStyle(color: subTextColor, fontSize: 11),
                                      fillColor: isDark ? Colors.white.withValues(alpha: 0.02) : Colors.black.withValues(alpha: 0.03),
                                      filled: true,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(color: cardBorder),
                                      ),
                                    ),
                                    style: TextStyle(color: textColor, fontSize: 13),
                                    items: _tahunAjaranOptions.map((tahun) {
                                      return DropdownMenuItem<String>(
                                        value: tahun,
                                        child: Text(tahun),
                                      );
                                    }).toList(),
                                    onChanged: (val) {
                                      if (val != null) {
                                        setState(() => _selectedTahunAjaran = val);
                                      }
                                    },
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    isExpanded: true,
                                    initialValue: _selectedSemester,
                                    dropdownColor: isDark ? const Color(0xFF0F0C20) : Colors.white,
                                    decoration: InputDecoration(
                                      labelText: 'Semester',
                                      labelStyle: TextStyle(color: subTextColor, fontSize: 11),
                                      fillColor: isDark ? Colors.white.withValues(alpha: 0.02) : Colors.black.withValues(alpha: 0.03),
                                      filled: true,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(color: cardBorder),
                                      ),
                                    ),
                                    style: TextStyle(color: textColor, fontSize: 13),
                                    items: _semesterOptions.map((sem) {
                                      return DropdownMenuItem<String>(
                                        value: sem,
                                        child: Text(sem),
                                      );
                                    }).toList(),
                                    onChanged: (val) {
                                      if (val != null) {
                                        setState(() => _selectedSemester = val);
                                      }
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // History Label
                      Row(
                        children: [
                          Icon(Icons.history_rounded, color: textColor.withValues(alpha: 0.8), size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'Riwayat Kehadiran',
                            style: TextStyle(
                              color: textColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 12),
                      
                      // History List
                      Expanded(
                        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                          stream: FirebaseFirestore.instance
                              .collection('schools')
                              .doc(schoolId)
                              .collection('teacher_daily_attendance')
                              .where('teacherId', isEqualTo: widget.teacherId)
                              .limit(60)
                              .snapshots(),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return const Center(child: CircularProgressIndicator(color: Color(0xFF8B5CF6)));
                            }

                            if (snapshot.hasError) {
                              return Center(
                                child: Text(
                                  'Gagal memuat data: ${snapshot.error}',
                                  style: TextStyle(color: subTextColor, fontSize: 13),
                                  textAlign: TextAlign.center,
                                ),
                              );
                            }

                            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                              return Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.calendar_today_outlined, color: subTextColor, size: 48),
                                    const SizedBox(height: 12),
                                    Text(
                                      'Belum ada riwayat absensi harian.',
                                      style: TextStyle(color: subTextColor, fontSize: 14),
                                    ),
                                  ],
                                ),
                              );
                            }

                            // Sort descending in memory
                            final sortedDocs = snapshot.data!.docs.toList()
                              ..sort((a, b) {
                                final dateA = a.data()['date'] ?? '';
                                final dateB = b.data()['date'] ?? '';
                                return dateB.compareTo(dateA);
                              });

                            // Filter by semester — if record has no tahunAjaran/semester, still include it
                            final filteredDocs = sortedDocs.where((doc) {
                              final data = doc.data();
                              final tAjaran = data['tahunAjaran'] as String?;
                              final sem = data['semester'] as String?;
                              // If both fields are missing/empty, always show the record
                              if ((tAjaran == null || tAjaran.isEmpty) &&
                                  (sem == null || sem.isEmpty)) {
                                return true;
                              }
                              return tAjaran == _selectedTahunAjaran && sem == _selectedSemester;
                            }).toList();

                            if (filteredDocs.isEmpty) {
                              return Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.calendar_today_outlined, color: subTextColor, size: 48),
                                    const SizedBox(height: 12),
                                    Text(
                                      'Tidak ada riwayat untuk $_selectedTahunAjaran - $_selectedSemester.',
                                      style: TextStyle(color: subTextColor, fontSize: 14),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              );
                            }

                            return ListView.separated(
                              itemCount: filteredDocs.length,
                              physics: const BouncingScrollPhysics(),
                              separatorBuilder: (context, index) => const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                final data = filteredDocs[index].data();
                                final dateStr = data['date'] ?? '';
                                final checkIn = data['checkInTime'] as Timestamp?;
                                final checkOut = data['checkOutTime'] as Timestamp?;
                                final status = data['status'] ?? 'hadir';
                                final method = data['method'] ?? 'qr_scan';

                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                  decoration: BoxDecoration(
                                    color: cardColor,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: cardBorder),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              _formatFullDate(dateStr),
                                              style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 14),
                                            ),
                                            const SizedBox(height: 6),
                                            Row(
                                              children: [
                                                Icon(Icons.login_rounded, color: const Color(0xFF10B981).withValues(alpha: 0.8), size: 12),
                                                const SizedBox(width: 4),
                                                Text(
                                                  _formatTime(checkIn),
                                                  style: TextStyle(color: subTextColor, fontSize: 12),
                                                ),
                                                const SizedBox(width: 12),
                                                Icon(Icons.logout_rounded, color: Colors.orange.withValues(alpha: 0.8), size: 12),
                                                const SizedBox(width: 4),
                                                Text(
                                                  checkOut != null ? _formatTime(checkOut) : 'Belum Pulang',
                                                  style: TextStyle(color: subTextColor, fontSize: 12),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          _buildStatusBadge(status),
                                          const SizedBox(height: 4),
                                          Text(
                                            method == 'manual' ? 'Oleh Admin' : 'Scan QR',
                                            style: TextStyle(color: subTextColor.withValues(alpha: 0.8), fontSize: 10),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
        );
      },
    );
  }
}
