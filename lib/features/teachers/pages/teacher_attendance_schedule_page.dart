import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/services/session_service.dart';
import '../../authentication/widgets/auth_background.dart';
import '../../schools/pages/schedule/Service/class_schedule_service.dart';
import '../../students/data/student_service.dart';
import '../services/attendance_pdf_helper.dart';
import 'teacher_qr_attendance_page.dart';

class TeacherAttendanceSchedulePage extends StatefulWidget {
  final String teacherId;
  const TeacherAttendanceSchedulePage({super.key, required this.teacherId});

  @override
  State<TeacherAttendanceSchedulePage> createState() => _TeacherAttendanceSchedulePageState();
}

class _TeacherAttendanceSchedulePageState extends State<TeacherAttendanceSchedulePage> {
  final _scheduleService = ClassScheduleService();
  final _studentService = StudentService();

  DateTime _selectedDate = DateTime.now();

  int _timeToMinutes(String time) {
    final parts = time.split(':');
    if (parts.length != 2) return 0;
    return (int.tryParse(parts[0]) ?? 0) * 60 + (int.tryParse(parts[1]) ?? 0);
  }

  String _getTodayHariIndonesian() {
    final now = DateTime.now();
    final days = ['Minggu', 'Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu'];
    return days[now.weekday % 7];
  }

  String _getHariIndonesianFor(DateTime date) {
    final days = ['Minggu', 'Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu'];
    return days[date.weekday % 7];
  }

  String _getFormattedDate() {
    final now = DateTime.now();
    final days = ['Minggu', 'Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu'];
    final months = [
      'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
    ];
    final dayName = days[now.weekday % 7];
    final monthName = months[now.month - 1];
    return '$dayName, ${now.day} $monthName ${now.year}';
  }

  String _getFormattedDateFor(DateTime date) {
    final days = ['Minggu', 'Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu'];
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
      'Jul', 'Agt', 'Sep', 'Okt', 'Nov', 'Des'
    ];
    final dayName = days[date.weekday % 7];
    final monthName = months[date.month - 1];
    return '$dayName, ${date.day} $monthName';
  }

  String _getFormattedTime() {
    final now = DateTime.now();
    final hour = now.hour.toString().padLeft(2, '0');
    final minute = now.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String _getDateStrFor(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  bool _isCurrentTimeInSlot(String jamMulai, String jamSelesai) {
    final now = DateTime.now();
    final nowMinutes = now.hour * 60 + now.minute;
    final startMinutes = _timeToMinutes(jamMulai);
    final endMinutes = _timeToMinutes(jamSelesai);
    return nowMinutes >= startMinutes && nowMinutes <= endMinutes;
  }

  String _getClassStatus(DateTime date, String jamMulai, String jamSelesai) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final selected = DateTime(date.year, date.month, date.day);

    if (selected.isBefore(today)) {
      return 'Selesai';
    } else if (selected.isAfter(today)) {
      return 'Mendatang';
    } else {
      final nowMinutes = now.hour * 60 + now.minute;
      final startMinutes = _timeToMinutes(jamMulai);
      final endMinutes = _timeToMinutes(jamSelesai);

      if (nowMinutes < startMinutes) {
        return 'Mendatang';
      } else if (nowMinutes > endMinutes) {
        return 'Selesai';
      } else {
        return 'Berlangsung';
      }
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 7)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF8B5CF6),
              onPrimary: Colors.white,
              surface: Color(0xFF0F0C20),
              onSurface: Colors.white,
            ),
            dialogBackgroundColor: const Color(0xFF0F0C20),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF8B5CF6),
              ),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }



  Widget _buildDatePickerTheme(BuildContext context, Widget? child) {
    return Theme(
      data: Theme.of(context).copyWith(
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF8B5CF6),
          onPrimary: Colors.white,
          surface: Color(0xFF0F0C20),
          onSurface: Colors.white,
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFF8B5CF6),
          ),
        ),
      ),
      child: child!,
    );
  }

  Future<void> _showDateRangeDialog(BuildContext context, List<Map<String, dynamic>> allSchedules) async {
    DateTime startDate = DateTime.now().subtract(const Duration(days: 7));
    DateTime endDate = DateTime.now();

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              backgroundColor: const Color(0xFF0F0C20),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Unduh Rekap Absen',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: startDate,
                                firstDate: DateTime.now().subtract(const Duration(days: 365)),
                                lastDate: DateTime.now().add(const Duration(days: 7)),
                                builder: _buildDatePickerTheme,
                              );
                              if (picked != null) {
                                setDialogState(() {
                                  startDate = picked;
                                  if (startDate.isAfter(endDate)) {
                                    endDate = startDate;
                                  }
                                });
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Dari Tanggal',
                                    style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _getFormattedDateFor(startDate),
                                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: GestureDetector(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: endDate,
                                firstDate: startDate,
                                lastDate: DateTime.now().add(const Duration(days: 7)),
                                builder: _buildDatePickerTheme,
                              );
                              if (picked != null) {
                                setDialogState(() {
                                  endDate = picked;
                                });
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Sampai Tanggal',
                                    style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _getFormattedDateFor(endDate),
                                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _exportAllRecapPdfWithRange(context, allSchedules, startDate, endDate);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF8B5CF6),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Download Rekapan',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 0.5),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white.withValues(alpha: 0.5),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('Batal', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _exportAllRecapPdfWithRange(
    BuildContext context,
    List<Map<String, dynamic>> allSchedules,
    DateTime start,
    DateTime end,
  ) async {
    final user = SessionService.currentUser!;
    final teacherName = user.nama;

    // Tampilkan loading overlay
    Get.dialog(
      const Center(
        child: CircularProgressIndicator(color: Color(0xFF8B5CF6)),
      ),
      barrierDismissible: false,
    );

    try {
      final startDateStr = _getDateStrFor(start);
      final endDateStr = _getDateStrFor(end);

      // Query data kehadiran dari Firestore untuk rentang tanggal ini
      final querySnapshot = await FirebaseFirestore.instance
          .collection('schools')
          .doc(user.schoolId)
          .collection('attendance')
          .where('date', isGreaterThanOrEqualTo: startDateStr)
          .where('date', isLessThanOrEqualTo: endDateStr)
          .get();

      final allRecords = querySnapshot.docs.map((doc) => doc.data()).toList();

      // Filter berdasarkan scheduleId yang diampu guru ini
      final teacherScheduleIds = allSchedules
          .map((s) => s['scheduleId'] as String?)
          .whereType<String>()
          .toSet();

      final filteredRecords = allRecords
          .where((r) => teacherScheduleIds.contains(r['scheduleId'] as String?))
          .toList();

      // Tutup loading dialog
      Get.back();

      if (filteredRecords.isEmpty) {
        Get.snackbar(
          'Informasi',
          'Tidak ada data absensi pada rentang tanggal yang dipilih.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.amber,
          colorText: Colors.black,
          margin: const EdgeInsets.all(16),
          borderRadius: 12,
        );
        return;
      }

      // Panggil PDF Helper untuk generate rekap gabungan
      await AttendancePdfHelper.generateAndShowAllPdf(
        teacherName: teacherName,
        startDate: start,
        endDate: end,
        records: filteredRecords,
      );

    } catch (e) {
      Get.back(); // Tutup loading dialog
      Get.snackbar(
        'Gagal Ekspor PDF',
        e.toString(),
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.redAccent,
        colorText: Colors.white,
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
      );
    }
  }

  Future<void> _exportAllRecapPdf(BuildContext context, List<Map<String, dynamic>> allSchedules) async {
    if (allSchedules.isEmpty) {
      Get.snackbar(
        'Informasi',
        'Tidak ada jadwal mengajar untuk mengunduh rekap.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.amber,
        colorText: Colors.black,
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
      );
      return;
    }

    await _showDateRangeDialog(context, allSchedules);
  }

  @override
  Widget build(BuildContext context) {
    final user = SessionService.currentUser!;
    final todayHari = _getTodayHariIndonesian();
    final recapHari = _getHariIndonesianFor(_selectedDate);
    final recapDateStr = _getDateStrFor(_selectedDate);

    return Scaffold(
      body: AuthBackground(
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _scheduleService.getSchedulesByTeacher(user.schoolId, widget.teacherId),
          builder: (context, snapshot) {
            final allSchedules = snapshot.data?.docs.map((e) => e.data()).toList() ?? [];

            // Sort chronologically helper
            void sortSchedules(List<Map<String, dynamic>> list) {
              list.sort((a, b) {
                return _timeToMinutes(a['jamMulai'] ?? '').compareTo(_timeToMinutes(b['jamMulai'] ?? ''));
              });
            }

            // Active Subject Section (Always based on current time & today)
            final todaySchedules = allSchedules
                .where((s) => s['hari'] == todayHari && s['jenisJadwal'] != 'istirahat')
                .toList();
            sortSchedules(todaySchedules);

            final activeSchedules = todaySchedules.where((s) {
              final jamMulai = s['jamMulai'] ?? '00:00';
              final jamSelesai = s['jamSelesai'] ?? '00:00';
              return _isCurrentTimeInSlot(jamMulai, jamSelesai);
            }).toList();

            // Recap Section (Based on selected date)
            final recapSchedules = allSchedules
                .where((s) => s['hari'] == recapHari && s['jenisJadwal'] != 'istirahat')
                .toList();
            sortSchedules(recapSchedules);

            return Scaffold(
              backgroundColor: Colors.transparent,
              appBar: AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
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
                  'Absensi Murid',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
                ),
                actions: [
                  if (snapshot.connectionState != ConnectionState.waiting && !snapshot.hasError)
                    Padding(
                      padding: const EdgeInsets.only(right: 16, top: 10, bottom: 10),
                      child: TextButton(
                        onPressed: () => _exportAllRecapPdf(context, allSchedules),
                        style: TextButton.styleFrom(
                          backgroundColor: const Color(0xFF8B5CF6),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        child: const Text(
                          'unduh rekapan absen',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              body: snapshot.hasError
                  ? _buildErrorBox('Terjadi kesalahan memuat jadwal')
                  : snapshot.connectionState == ConnectionState.waiting
                      ? const Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: () async {
                            setState(() {});
                          },
                          color: const Color(0xFF8B5CF6),
                          backgroundColor: const Color(0xFF0F0C20),
                          child: SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Clock / Date card
                                _buildDateHeaderCard(),
                                const SizedBox(height: 24),

                                // Active Subject Section
                                _buildSectionHeader('MATA PELAJARAN AKTIF SEKARANG', Icons.sensors_rounded),
                                const SizedBox(height: 12),
                                _buildActiveScheduleSection(activeSchedules),
                                const SizedBox(height: 28),

                                // Today's/Past Recap Section
                                _buildRecapSectionHeader(recapDateStr),
                                const SizedBox(height: 12),
                                _buildTodayRecapSection(recapSchedules, user.schoolId, recapDateStr, _selectedDate),
                                const SizedBox(height: 40),
                              ],
                            ),
                          ),
                        ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildDateHeaderCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.calendar_today_rounded, color: Color(0xFF8B5CF6), size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getFormattedDate(),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 4),
                Text(
                  'Waktu Server: ${_getFormattedTime()} WIB',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: Colors.white54, size: 18),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            color: Colors.white70,
            fontWeight: FontWeight.bold,
            fontSize: 13,
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
  }

  Widget _buildRecapSectionHeader(String dateStr) {
    final now = DateTime.now();
    final todayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final isToday = dateStr == todayStr;

    return Row(
      children: [
        const Icon(Icons.summarize_rounded, color: Colors.white54, size: 18),
        const SizedBox(width: 8),
        Text(
          isToday ? 'REKAP ABSENSI HARI INI' : 'REKAP ABSENSI TANGGAL',
          style: const TextStyle(
            color: Colors.white70,
            fontWeight: FontWeight.bold,
            fontSize: 13,
            letterSpacing: 0.8,
          ),
        ),
        const Spacer(),
        TextButton.icon(
          onPressed: () => _selectDate(context),
          icon: const Icon(Icons.calendar_month_rounded, size: 16, color: Color(0xFF8B5CF6)),
          label: Text(
            isToday ? 'Pilih Tanggal' : _getFormattedDateFor(_selectedDate),
            style: const TextStyle(color: Color(0xFF8B5CF6), fontSize: 12, fontWeight: FontWeight.bold),
          ),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            backgroundColor: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ],
    );
  }

  Widget _buildActiveScheduleSection(List<Map<String, dynamic>> activeSchedules) {
    if (activeSchedules.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Center(
          child: Column(
            children: [
              const Icon(Icons.query_builder_rounded, color: Colors.white30, size: 36),
              const SizedBox(height: 10),
              Text(
                'Tidak ada mata pelajaran aktif di jam sekarang.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.38), fontSize: 13, fontStyle: FontStyle.italic),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: activeSchedules.map((s) {
        final subjectName = s['subjectName'] ?? 'Pelajaran';
        final className = s['className'] ?? 'Kelas';
        final jamMulai = s['jamMulai'] ?? '00:00';
        final jamSelesai = s['jamSelesai'] ?? '00:00';

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFF6366F1).withValues(alpha: 0.15),
                const Color(0xFF8B5CF6).withValues(alpha: 0.15),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFF8B5CF6).withValues(alpha: 0.3)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                blurRadius: 16,
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
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.sensors_rounded, color: Color(0xFF10B981), size: 18),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
                    ),
                    child: const Text(
                      'Sedang Berlangsung',
                      style: TextStyle(color: Color(0xFF10B981), fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                subjectName,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
              ),
              const SizedBox(height: 4),
              Text(
                'Kelas: $className',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.schedule_rounded, color: Colors.white38, size: 14),
                  const SizedBox(width: 6),
                  Text(
                    '$jamMulai – $jamSelesai WIB',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 13),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () => Get.to(() => TeacherQrAttendancePage(scheduleData: s)),
                icon: const Icon(Icons.qr_code_2_rounded, size: 20),
                label: const Text('BUKA PRESENSI QR & SCAN', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8B5CF6),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  elevation: 4,
                  shadowColor: const Color(0xFF8B5CF6).withValues(alpha: 0.4),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTodayRecapSection(List<Map<String, dynamic>> todaySchedules, String schoolId, String dateStr, DateTime selectedDate) {
    if (todaySchedules.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Center(
          child: Text(
            'Tidak ada jadwal mengajar untuk hari/tanggal ini.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.38), fontSize: 13, fontStyle: FontStyle.italic),
          ),
        ),
      );
    }

    return Column(
      children: todaySchedules.map((s) {
        final scheduleId = s['scheduleId'] ?? '';
        final subjectName = s['subjectName'] ?? 'Pelajaran';
        final className = s['className'] ?? 'Kelas';
        final jamMulai = s['jamMulai'] ?? '00:00';
        final jamSelesai = s['jamSelesai'] ?? '00:00';

        final status = _getClassStatus(selectedDate, jamMulai, jamSelesai);

        Color accentColor;
        Color statusColor;
        if (status == 'Berlangsung') {
          accentColor = const Color(0xFF10B981);
          statusColor = const Color(0xFF10B981);
        } else if (status == 'Mendatang') {
          accentColor = const Color(0xFFF59E0B);
          statusColor = const Color(0xFFF59E0B);
        } else {
          accentColor = Colors.white24;
          statusColor = Colors.white38;
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: status == 'Berlangsung'
                  ? const Color(0xFF8B5CF6).withValues(alpha: 0.3)
                  : Colors.white.withValues(alpha: 0.08),
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => Get.to(() => TeacherQrAttendancePage(scheduleData: s, dateStr: dateStr)),
                child: IntrinsicHeight(
                  child: Row(
                    children: [
                      Container(
                        width: 6,
                        color: accentColor,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      subjectName,
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: statusColor.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: statusColor.withValues(alpha: 0.35)),
                                    ),
                                    child: Text(
                                      status,
                                      style: TextStyle(color: statusColor, fontSize: 9, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Kelas: $className',
                                style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12, fontWeight: FontWeight.w500),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Icon(Icons.schedule_rounded, color: Colors.white30, size: 12),
                                  const SizedBox(width: 4),
                                  Text(
                                    '$jamMulai - $jamSelesai',
                                    style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 11),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                                      stream: _studentService.getScheduleAttendanceListStream(
                                        schoolId: schoolId,
                                        scheduleId: scheduleId,
                                        dateStr: dateStr,
                                      ),
                                      builder: (context, attSnapshot) {
                                        final count = attSnapshot.data?.docs.length ?? 0;
                                        return Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.people_alt_rounded,
                                              size: 12,
                                              color: count > 0 ? const Color(0xFF10B981) : Colors.white30,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              '$count Murid Hadir',
                                              style: TextStyle(
                                                color: count > 0 ? const Color(0xFF10B981) : Colors.white38,
                                                fontSize: 11,
                                                fontWeight: count > 0 ? FontWeight.bold : FontWeight.normal,
                                              ),
                                            ),
                                          ],
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),

                      const Icon(Icons.chevron_right_rounded, color: Colors.white30),
                      const SizedBox(width: 12),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildErrorBox(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline_rounded, size: 48, color: Colors.redAccent),
          const SizedBox(height: 12),
          Text(
            message,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
