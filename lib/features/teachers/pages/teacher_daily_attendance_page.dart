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
  final bool hideBackButton;
  const TeacherDailyAttendancePage({
    super.key,
    required this.teacherId,
    required this.teacherName,
    required this.nip,
    this.hideBackButton = false,
  });

  @override
  State<TeacherDailyAttendancePage> createState() => _TeacherDailyAttendancePageState();
}

class _TeacherDailyAttendancePageState extends State<TeacherDailyAttendancePage> {
  bool _isLoadingSchoolConfig = true;

  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;
  DateTime? _teacherCreatedAt;

  final List<String> _monthNames = [
    'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
    'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
  ];

  @override
  void initState() {
    super.initState();
    _loadSchoolConfig();
  }

  Future<void> _loadSchoolConfig() async {
    try {
      final schoolId = SessionService.currentUser?.schoolId ?? '';
      final doc = await FirebaseFirestore.instance
          .collection('schools')
          .doc(schoolId)
          .collection('teachers')
          .doc(widget.teacherId)
          .get();
      final data = doc.data();
      if (data != null && data['createdAt'] != null) {
        final ts = data['createdAt'] as Timestamp;
        _teacherCreatedAt = ts.toDate();
      }
    } catch (_) {}
    if (mounted) {
      setState(() {
        _isLoadingSchoolConfig = false;
      });
    }
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

  String _getDayNameIndonesian(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return 'Senin';
      case DateTime.tuesday:
        return 'Selasa';
      case DateTime.wednesday:
        return 'Rabu';
      case DateTime.thursday:
        return 'Kamis';
      case DateTime.friday:
        return 'Jumat';
      case DateTime.saturday:
        return 'Sabtu';
      case DateTime.sunday:
        return 'Minggu';
      default:
        return '';
    }
  }

  int _getDaysInMonth(int year, int month) {
    return DateTime(year, month + 1, 0).day;
  }

  int _compareDateWithToday(int day) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final targetDate = DateTime(_selectedYear, _selectedMonth, day);
    return targetDate.compareTo(today);
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
      case 'tanpa keterangan':
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
            automaticallyImplyLeading: !widget.hideBackButton,
            leading: widget.hideBackButton
                ? null
                : IconButton(
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
                                const Icon(Icons.calendar_month_rounded, color: Color(0xFF8B5CF6), size: 18),
                                const SizedBox(width: 8),
                                Text(
                                  'Pilih Bulan & Tahun',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: textColor),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: DropdownButtonFormField<int>(
                                    isExpanded: true,
                                    initialValue: _selectedMonth,
                                    dropdownColor: isDark ? const Color(0xFF0F0C20) : Colors.white,
                                    decoration: InputDecoration(
                                      labelText: 'Bulan',
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
                                    items: List.generate(12, (index) {
                                      final month = index + 1;
                                      final minMonth = (_teacherCreatedAt != null && _selectedYear == _teacherCreatedAt!.year)
                                          ? _teacherCreatedAt!.month
                                          : 1;
                                      final isDisabled = month < minMonth;
                                      return DropdownMenuItem<int>(
                                        value: month,
                                        enabled: !isDisabled,
                                        child: Text(
                                          _monthNames[index],
                                          style: TextStyle(
                                            color: isDisabled ? Colors.grey.withValues(alpha: 0.4) : null,
                                          ),
                                        ),
                                      );
                                    }),
                                    onChanged: (val) {
                                      if (val != null) {
                                        setState(() => _selectedMonth = val);
                                      }
                                    },
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: DropdownButtonFormField<int>(
                                    isExpanded: true,
                                    initialValue: _selectedYear,
                                    dropdownColor: isDark ? const Color(0xFF0F0C20) : Colors.white,
                                    decoration: InputDecoration(
                                      labelText: 'Tahun',
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
                                    items: () {
                                      final startYear = _teacherCreatedAt?.year ?? (DateTime.now().year - 2);
                                      final endYear = DateTime.now().year;
                                      final count = (endYear - startYear + 1).clamp(1, 20);
                                      return List.generate(count, (index) {
                                        final year = startYear + index;
                                        return DropdownMenuItem<int>(
                                          value: year,
                                          child: Text(year.toString()),
                                        );
                                      });
                                    }(),
                                    onChanged: (val) {
                                      if (val != null) {
                                        final minMonth = (_teacherCreatedAt != null && val == _teacherCreatedAt!.year)
                                            ? _teacherCreatedAt!.month
                                            : 1;
                                        setState(() {
                                          _selectedYear = val;
                                          if (_selectedMonth < minMonth) {
                                            _selectedMonth = minMonth;
                                          }
                                        });
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
                            'Riwayat Kehadiran Bulanan',
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

                            final attendanceMap = <String, Map<String, dynamic>>{};
                            if (snapshot.hasData) {
                              for (final doc in snapshot.data!.docs) {
                                final data = doc.data();
                                final date = data['date'] as String?;
                                if (date != null) {
                                  attendanceMap[date] = data;
                                }
                              }
                            }

                            int maxDayToShow;
                            final now = DateTime.now();
                            if (_selectedYear < now.year) {
                              maxDayToShow = _getDaysInMonth(_selectedYear, _selectedMonth);
                            } else if (_selectedYear > now.year) {
                              maxDayToShow = 0;
                            } else {
                              if (_selectedMonth < now.month) {
                                maxDayToShow = _getDaysInMonth(_selectedYear, _selectedMonth);
                              } else if (_selectedMonth > now.month) {
                                maxDayToShow = 0;
                              } else {
                                maxDayToShow = now.day;
                              }
                            }

                            if (maxDayToShow == 0) {
                              return Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.calendar_today_outlined, color: subTextColor, size: 48),
                                    const SizedBox(height: 12),
                                    Text(
                                      'Tidak ada riwayat absensi untuk periode mendatang.',
                                      style: TextStyle(color: subTextColor, fontSize: 14),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              );
                            }

                            return StreamBuilder<DateTime>(
                              stream: Stream.periodic(const Duration(seconds: 5), (_) => DateTime.now()),
                              initialData: DateTime.now(),
                              builder: (context, timeSnapshot) {
                                final nowTime = timeSnapshot.data ?? DateTime.now();

                                return ListView.separated(
                                  itemCount: maxDayToShow,
                                  physics: const BouncingScrollPhysics(),
                                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                                  itemBuilder: (context, index) {
                                    // Tampilkan dari tanggal paling baru (menurun)
                                    final day = maxDayToShow - index;
                                    final dateKey = '$_selectedYear-${_selectedMonth.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
                                    final dateObj = DateTime(_selectedYear, _selectedMonth, day);
                                    final weekdayStr = _getDayNameIndonesian(dateObj.weekday);
                                    final hasAttendance = attendanceMap.containsKey(dateKey);
                                    final dateText = '$day ${_monthNames[_selectedMonth - 1]} $_selectedYear';

                                    if (hasAttendance) {
                                      final data = attendanceMap[dateKey]!;
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
                                                    '$dateText ($weekdayStr)',
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
                                    }

                                    final dateCompare = _compareDateWithToday(day);

                                    // No attendance recorded
                                    if (dateCompare < 0) {
                                      // Past date -> Alfa (Tanpa Keterangan)
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
                                                    '$dateText ($weekdayStr)',
                                                    style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 14),
                                                  ),
                                                  const SizedBox(height: 6),
                                                  const Text(
                                                    'Tidak Hadir (Tanpa Keterangan)',
                                                    style: TextStyle(color: Colors.redAccent, fontSize: 12),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            _buildStatusBadge('alfa'),
                                          ],
                                        ),
                                      );
                                    } else if (dateCompare == 0) {
                                      // Today -> Check if past 18:21
                                      final bool isAfter1821 = nowTime.hour > 19 || (nowTime.hour == 19 && nowTime.minute >= 11);
                                      if (isAfter1821) {
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
                                                      '$dateText ($weekdayStr)',
                                                      style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 14),
                                                    ),
                                                    const SizedBox(height: 6),
                                                    const Text(
                                                      'Tidak Hadir (Batas Absen Lewat)',
                                                      style: TextStyle(color: Colors.redAccent, fontSize: 12),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              _buildStatusBadge('alfa'),
                                            ],
                                          ),
                                        );
                                      } else {
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
                                                      '$dateText ($weekdayStr)',
                                                      style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 14),
                                                    ),
                                                    const SizedBox(height: 6),
                                                    Text(
                                                      'Hari ini - Belum mencatat absensi (Batas 18:30)',
                                                      style: TextStyle(color: subTextColor, fontSize: 12),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: Colors.orange.withValues(alpha: 0.15),
                                                  borderRadius: BorderRadius.circular(8),
                                                  border: Border.all(color: Colors.orange.withValues(alpha: 0.4)),
                                                ),
                                                child: const Text(
                                                  'Belum Absen',
                                                  style: TextStyle(color: Colors.orange, fontSize: 11, fontWeight: FontWeight.bold),
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      }
                                    } else {
                                      // Future date -> Mendatang
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
                                                    '$dateText ($weekdayStr)',
                                                    style: TextStyle(color: textColor.withValues(alpha: 0.6), fontWeight: FontWeight.bold, fontSize: 14),
                                                  ),
                                                  const SizedBox(height: 6),
                                                  Text(
                                                    'Jadwal Mengajar Mendatang',
                                                    style: TextStyle(color: subTextColor.withValues(alpha: 0.6), fontSize: 12),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: Colors.blue.withValues(alpha: 0.1),
                                                borderRadius: BorderRadius.circular(8),
                                                border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
                                              ),
                                              child: Text(
                                                'Mendatang',
                                                style: TextStyle(color: Colors.blue.withValues(alpha: 0.6), fontSize: 11, fontWeight: FontWeight.bold),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }
                                  },
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
