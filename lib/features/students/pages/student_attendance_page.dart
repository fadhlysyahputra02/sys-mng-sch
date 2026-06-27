import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/services/session_service.dart';
import '../../authentication/widgets/auth_background.dart';
import '../../schools/pages/schedule/Service/class_schedule_service.dart';
import '../data/student_service.dart';
import 'student_qr_scanner_page.dart';
import 'student_attendance_history_page.dart';

class StudentAttendancePage extends StatefulWidget {
  final String studentDocId;
  final Map<String, dynamic> studentData;
  final String className;
  final String tahunAjaran;
  final String semester;

  const StudentAttendancePage({
    super.key,
    required this.studentDocId,
    required this.studentData,
    required this.className,
    required this.tahunAjaran,
    required this.semester,
  });

  @override
  State<StudentAttendancePage> createState() => _StudentAttendancePageState();
}

class _StudentAttendancePageState extends State<StudentAttendancePage> {
  final _studentService = StudentService();
  final _scheduleService = ClassScheduleService();

  String _getTodayDateStr() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  String _getFormattedIndonesianDate() {
    final now = DateTime.now();
    final days = ['Minggu', 'Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu'];
    final months = [
      'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
    ];
    final dayName = days[now.weekday % 7];
    final monthName = months[now.month - 1];
    return '$dayName, ${now.day} $monthName ${now.year}';
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

  /// Cek apakah jam pelajaran sudah lewat berdasarkan jamSelesai
  bool _isTimeExpired(String jamSelesai) {
    final now = DateTime.now();
    final nowMinutes = now.hour * 60 + now.minute;
    final endMinutes = _timeToMinutes(jamSelesai);
    return nowMinutes > endMinutes;
  }

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return '--:--';
    final dt = timestamp.toDate().toLocal();
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$hour:$minute WIB';
  }

  void _openScanModal(
    BuildContext pageContext,
    String scheduleId,
    String subjectName,
    String jamSelesai,
  ) {
    final user = SessionService.currentUser!;
    final dateStr = _getTodayDateStr();
    final name = widget.studentData['nama'] ?? 'Murid';

    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Color(0xFF0F0C20),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Absensi Kelas',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subjectName,
                          style: const TextStyle(fontSize: 14, color: Color(0xFF10B981), fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white60),
                    onPressed: () => Get.back(),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Arahkan kamera ke QR Code yang ditampilkan guru',
                style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.5)),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () async {
                  Get.back();

                  // Cek apakah jam pelajaran sudah lewat sebelum scan
                  if (_isTimeExpired(jamSelesai)) {
                    _showErrorSnackbar('Waktu absensi sudah berakhir pukul $jamSelesai');
                    return;
                  }

                  final scanned = await Navigator.push<String?>(
                    pageContext,
                    MaterialPageRoute(builder: (_) => const StudentQrScannerPage()),
                  );
                  if (scanned == null || scanned.isEmpty) return;

                  // Cek apakah jam pelajaran sudah lewat setelah scan selesai
                  if (_isTimeExpired(jamSelesai)) {
                    _showErrorSnackbar('Waktu absensi sudah berakhir pukul $jamSelesai');
                    return;
                  }

                  // Parse JSON payload dari QR guru
                  String? scannedScheduleId;
                  try {
                    const prefix = 'sys_mng_school_attendance:';
                    if (scanned.startsWith(prefix)) {
                      final jsonStr = scanned.substring(prefix.length);
                      final Map<String, dynamic> payload = jsonDecode(jsonStr);
                      scannedScheduleId = payload['scheduleId'] as String?;
                    }
                  } catch (_) {
                    scannedScheduleId = null;
                  }

                  if (scannedScheduleId == null || scannedScheduleId != scheduleId) {
                    _showErrorSnackbar('QR tidak valid untuk pelajaran ini');
                    return;
                  }

                  try {
                    await _studentService.checkInScheduleAttendance(
                      schoolId: user.schoolId,
                      studentId: widget.studentDocId,
                      studentName: name,
                      classId: widget.studentData['classId'] as String?,
                      className: widget.className,
                      scheduleId: scheduleId,
                      subjectName: subjectName,
                      dateStr: dateStr,
                      checkInMethod: 'QR Scan',
                      tahunAjaran: widget.tahunAjaran,
                      semester: widget.semester,
                    );
                    _showSuccessSnackbar();
                  } catch (e) {
                    _showErrorSnackbar(e.toString());
                  }
                },
                icon: const Icon(Icons.qr_code_scanner_rounded, color: Colors.white, size: 20),
                label: const Text('BUKA KAMERA SCAN QR', style: TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8B5CF6),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
      ),
      isScrollControlled: true,
    );
  }

  void _showSuccessSnackbar() {
    Get.rawSnackbar(
      titleText: const Text('Absen Berhasil', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
      messageText: const Text('Kehadiran Anda hari ini telah tercatat!', style: TextStyle(color: Colors.white70, fontSize: 14)),
      icon: const Icon(Icons.check_circle_outline_rounded, color: Colors.white, size: 28),
      margin: const EdgeInsets.all(16),
      borderRadius: 16,
      backgroundColor: const Color(0xFF10B981),
      duration: const Duration(seconds: 3),
      snackPosition: SnackPosition.TOP,
      barBlur: 8,
      boxShadows: [BoxShadow(color: const Color(0xFF10B981).withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4))],
    );
  }

  void _showErrorSnackbar(String error) {
    Get.rawSnackbar(
      titleText: const Text('Absen Gagal', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
      messageText: Text(error, style: const TextStyle(color: Colors.white70, fontSize: 14)),
      icon: const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 28),
      margin: const EdgeInsets.all(16),
      borderRadius: 16,
      backgroundColor: const Color(0xFFEF4444),
      duration: const Duration(seconds: 3),
      snackPosition: SnackPosition.TOP,
      barBlur: 8,
      boxShadows: [BoxShadow(color: const Color(0xFFEF4444).withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4))],
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = SessionService.currentUser!;
    final dateStr = _getTodayDateStr();
    final todayHari = _getTodayHariIndonesian();

    return Scaffold(
      body: ValueListenableBuilder<bool>(
        valueListenable: AuthBackground.isDarkMode,
        builder: (context, isDark, _) {
          final textColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
          final iconColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
          final btnBg = isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05);

          return AuthBackground(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                // AppBar
                SliverAppBar(
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  pinned: true,
                  iconTheme: IconThemeData(color: iconColor),
                  leading: Container(
                    margin: const EdgeInsets.only(left: 16),
                    decoration: BoxDecoration(
                      color: btnBg,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: Icon(Icons.arrow_back_ios_new_rounded, color: iconColor, size: 18),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  title: Text(
                    'Absensi Hari Ini',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: textColor),
                  ),
                  actions: [
                    Container(
                      margin: const EdgeInsets.only(right: 16),
                      decoration: BoxDecoration(
                        color: btnBg,
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: Icon(Icons.history_rounded, color: iconColor, size: 20),
                        tooltip: 'Riwayat Absensi',
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => StudentAttendanceHistoryPage(
                                studentDocId: widget.studentDocId,
                                className: widget.className,
                                studentName: (widget.studentData['nama'] ?? 'Murid')
                                    .toString(),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header Tanggal & Kelas
                    _buildDateAndClassHeader(),
                    const SizedBox(height: 16),
                    _buildHistoryButton(context),
                    const SizedBox(height: 24),

                    // Daftar jadwal + status absensi
                    StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: _scheduleService.getSchedulesByClassName(user.schoolId, widget.className),
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return _buildInfoBox('Gagal memuat jadwal', isError: true);
                        }
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          final isDark = AuthBackground.isDarkMode.value;
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.all(40),
                              child: CircularProgressIndicator(color: isDark ? Colors.white : const Color(0xFF1E1B4B)),
                            ),
                          );
                        }

                        final allSchedules = snapshot.data?.docs.map((e) => e.data()).toList() ?? [];
                        final todaySchedules = allSchedules
                            .where((s) => s['hari'] == todayHari && s['jenisJadwal'] != 'istirahat')
                            .toList();

                        bool isActiveNow(Map<String, dynamic> s) {
                          final jamMulai = s['jamMulai'] ?? '00:00';
                          final jamSelesai = s['jamSelesai'] ?? '00:00';
                          final now = DateTime.now();
                          final nowMinutes = now.hour * 60 + now.minute;
                          final startMinutes = _timeToMinutes(jamMulai);
                          final endMinutes = _timeToMinutes(jamSelesai);
                          return nowMinutes >= startMinutes && nowMinutes <= endMinutes;
                        }

                        todaySchedules.sort((a, b) {
                          final aActive = isActiveNow(a);
                          final bActive = isActiveNow(b);
                          if (aActive && !bActive) {
                            return -1;
                          } else if (!aActive && bActive) {
                            return 1;
                          } else {
                            return _timeToMinutes(a['jamMulai'] ?? '').compareTo(_timeToMinutes(b['jamMulai'] ?? ''));
                          }
                        });

                        if (todaySchedules.isEmpty) {
                          return _buildInfoBox('Tidak ada jadwal pelajaran untuk hari ini');
                        }

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildSectionLabel('Jadwal Pelajaran'),
                            const SizedBox(height: 12),
                            ...todaySchedules.map((s) {
                              final scheduleId = s['scheduleId'] ?? '';
                              final subjectName = s['subjectName'] ?? 'Pelajaran';
                              final jamMulai = s['jamMulai'] ?? '00:00';
                              final jamSelesai = s['jamSelesai'] ?? '00:00';
                              final expired = _isTimeExpired(jamSelesai);
                              final active = isActiveNow(s);

                              return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>?>(
                                stream: _studentService.getScheduleAttendanceStream(
                                  schoolId: user.schoolId,
                                  studentId: widget.studentDocId,
                                  scheduleId: scheduleId,
                                  dateStr: dateStr,
                                ),
                                builder: (context, attSnapshot) {
                                  final attDoc = attSnapshot.data;
                                  final isCheckedIn = attDoc != null;
                                  final attData = attDoc?.data();
                                  final timestamp = isCheckedIn && attData != null
                                      ? attData['timestamp'] as Timestamp?
                                      : null;

                                  return _buildScheduleItem(
                                    context: context,
                                    scheduleId: scheduleId,
                                    subjectName: subjectName,
                                    jamMulai: jamMulai,
                                    jamSelesai: jamSelesai,
                                    isCheckedIn: isCheckedIn,
                                    timestamp: timestamp,
                                    method: attData?['method'],
                                    expired: expired,
                                    isActive: active,
                                  );
                                },
                              );
                            }),
                          ],
                        );
                      },
                    ),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
      },
      ),
    );
  }

  Widget _buildHistoryButton(BuildContext context) {
    final isDark = AuthBackground.isDarkMode.value;
    final textColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
    final subTextColor = isDark ? Colors.white54 : const Color(0xFF1E1B4B).withValues(alpha: 0.5);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => StudentAttendanceHistoryPage(
                studentDocId: widget.studentDocId,
                className: widget.className,
                studentName: (widget.studentData['nama'] ?? 'Murid').toString(),
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFF8B5CF6).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFF8B5CF6).withValues(alpha: 0.35),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.history_rounded,
                  color: Color(0xFF8B5CF6),
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Riwayat Absensi',
                      style: TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Lihat absensi per bulan',
                      style: TextStyle(
                        color: subTextColor,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFF8B5CF6),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDateAndClassHeader() {
    final isDark = AuthBackground.isDarkMode.value;
    final textColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
    final subTextColor = isDark ? Colors.white.withValues(alpha: 0.45) : const Color(0xFF1E1B4B).withValues(alpha: 0.5);
    final cardColor = isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white;
    final cardBorder = isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05);
    final shadowColor = isDark ? Colors.black.withValues(alpha: 0.2) : Colors.black.withValues(alpha: 0.05);
    final dividerColor = isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05);

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
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.calendar_today_rounded, color: Color(0xFF10B981), size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getFormattedIndonesianDate(),
                      style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Absensi harian berbasis QR Code',
                      style: TextStyle(color: subTextColor, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Divider(color: dividerColor, height: 1),
          const SizedBox(height: 14),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.class_rounded, color: Color(0xFF6366F1), size: 14),
                    const SizedBox(width: 6),
                    Text(
                      widget.className,
                      style: const TextStyle(color: Color(0xFF6366F1), fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Text(
                'Hari ini',
                style: TextStyle(color: subTextColor, fontSize: 12, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    final isDark = AuthBackground.isDarkMode.value;
    final textColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
    final iconColor = isDark ? Colors.white54 : const Color(0xFF1E1B4B).withValues(alpha: 0.5);

    return Row(
      children: [
        Icon(Icons.list_alt_rounded, color: iconColor, size: 16),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 15, letterSpacing: 0.4),
        ),
      ],
    );
  }

  Widget _buildInfoBox(String message, {bool isError = false}) {
    final isDark = AuthBackground.isDarkMode.value;
    final textColor = isDark ? Colors.white.withValues(alpha: 0.45) : const Color(0xFF1E1B4B).withValues(alpha: 0.5);
    final bgColor = isDark ? Colors.white.withValues(alpha: 0.04) : Colors.white;
    final borderColor = isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      child: Center(
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isError ? Colors.redAccent.withValues(alpha: 0.8) : textColor,
            fontSize: 13,
            fontStyle: FontStyle.italic,
          ),
        ),
      ),
    );
  }

  Widget _buildScheduleItem({
    required BuildContext context,
    required String scheduleId,
    required String subjectName,
    required String jamMulai,
    required String jamSelesai,
    required bool isCheckedIn,
    required Timestamp? timestamp,
    required String? method,
    required bool expired,
    required bool isActive,
  }) {
    final isDark = AuthBackground.isDarkMode.value;
    final titleColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
    final subColor = isDark ? Colors.white.withValues(alpha: 0.45) : const Color(0xFF1E1B4B).withValues(alpha: 0.5);

    // Tentukan state visual
    Color borderColor;
    Color bgColor;
    Color iconColor;
    IconData statusIcon;

    if (isCheckedIn) {
      borderColor = isDark ? const Color(0xFF10B981).withValues(alpha: 0.4) : const Color(0xFF10B981).withValues(alpha: 0.3);
      bgColor = isDark ? const Color(0xFF10B981).withValues(alpha: 0.07) : const Color(0xFFECFDF5);
      iconColor = const Color(0xFF10B981);
      statusIcon = Icons.check_circle_rounded;
    } else if (expired) {
      borderColor = isDark ? const Color(0xFFEF4444).withValues(alpha: 0.3) : const Color(0xFFEF4444).withValues(alpha: 0.3);
      bgColor = isDark ? const Color(0xFFEF4444).withValues(alpha: 0.05) : const Color(0xFFFEF2F2);
      iconColor = const Color(0xFFEF4444);
      statusIcon = Icons.cancel_rounded;
    } else if (isActive) {
      borderColor = isDark ? const Color(0xFF10B981).withValues(alpha: 0.5) : const Color(0xFF10B981).withValues(alpha: 0.4);
      bgColor = isDark ? const Color(0xFF10B981).withValues(alpha: 0.08) : const Color(0xFFF0FDF4);
      iconColor = const Color(0xFF10B981);
      statusIcon = Icons.sensors_rounded;
    } else {
      borderColor = isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.08);
      bgColor = isDark ? Colors.white.withValues(alpha: 0.03) : const Color(0xFFF9FAFB);
      iconColor = isDark ? Colors.white30 : const Color(0xFF1E1B4B).withValues(alpha: 0.3);
      statusIcon = Icons.radio_button_unchecked_rounded;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(statusIcon, color: iconColor, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      subjectName,
                      style: TextStyle(fontWeight: FontWeight.bold, color: titleColor, fontSize: 15),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Icon(Icons.schedule_rounded, color: subColor, size: 12),
                        const SizedBox(width: 4),
                        Text(
                          '$jamMulai – $jamSelesai',
                          style: TextStyle(fontSize: 12, color: subColor),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Status badge kanan atas
              if (isCheckedIn)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
                  ),
                  child: const Text('Hadir', style: TextStyle(color: Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.bold)),
                )
              else if (expired)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.35)),
                  ),
                  child: const Text('Tidak Hadir', style: TextStyle(color: Color(0xFFEF4444), fontSize: 11, fontWeight: FontWeight.bold)),
                )
              else if (isActive)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
                  ),
                  child: const Text('Aktif', style: TextStyle(color: Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.bold)),
                ),
            ],
          ),

          // Detail bawah
          if (isCheckedIn) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.access_time_rounded, color: Color(0xFF10B981), size: 14),
                  const SizedBox(width: 6),
                  Text(
                    'Hadir pukul ${_formatTimestamp(timestamp)}',
                    style: const TextStyle(color: Color(0xFF10B981), fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  
                ],
              ),
            ),
          ] else if (expired) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lock_clock_rounded, color: Color(0xFFEF4444), size: 14),
                  const SizedBox(width: 6),
                  Text(
                    'Waktu absensi sudah berakhir pukul $jamSelesai',
                    style: const TextStyle(color: Color(0xFFEF4444), fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ] else ...[
            if (isActive) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.play_circle_filled_rounded, color: Color(0xFF10B981), size: 14),
                    SizedBox(width: 6),
                    Text(
                      'Kelas yang sedang berlangsung',
                      style: TextStyle(color: Color(0xFF10B981), fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () => _openScanModal(context, scheduleId, subjectName, jamSelesai),
                icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
                label: const Text('SCAN QR ABSEN', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  textStyle: const TextStyle(fontSize: 13),
                ),
              ),
            ] else ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(Icons.hourglass_empty_rounded, color: subColor, size: 14),
                    const SizedBox(width: 6),
                    Text(
                      'Belum dimulai',
                      style: TextStyle(color: subColor, fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
