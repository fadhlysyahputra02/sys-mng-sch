import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../core/services/session_service.dart';
import '../../authentication/widgets/auth_background.dart';
import '../../students/data/student_service.dart';

class TeacherQrAttendancePage extends StatefulWidget {
  final Map<String, dynamic> scheduleData;
  final String? dateStr; // Format: YYYY-MM-DD
  const TeacherQrAttendancePage({super.key, required this.scheduleData, this.dateStr});

  @override
  State<TeacherQrAttendancePage> createState() => _TeacherQrAttendancePageState();
}

class _TeacherQrAttendancePageState extends State<TeacherQrAttendancePage> {
  final _studentService = StudentService();

  String _getTodayDateStr() {
    final now = DateTime.now();
    return "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
  }

  String _getFormattedIndonesianDate(String dateStr) {
    try {
      final parts = dateStr.split('-');
      if (parts.length == 3) {
        final year = int.parse(parts[0]);
        final month = int.parse(parts[1]);
        final day = int.parse(parts[2]);
        final date = DateTime(year, month, day);
        final days = ['Minggu', 'Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu'];
        final months = [
          'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
          'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
        ];
        final dayName = days[date.weekday % 7];
        final monthName = months[date.month - 1];
        return '$dayName, $day $monthName $year';
      }
    } catch (_) {}
    return dateStr;
  }

  String _formatTime(Timestamp? timestamp) {
    if (timestamp == null) return '--:--';
    final dt = timestamp.toDate().toLocal();
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$hour:$minute WIB';
  }

  bool _isSchedulePassed(String dateStr, String jamSelesai) {
    final now = DateTime.now();
    final todayStr = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
    
    // Compare date parts
    if (dateStr.compareTo(todayStr) < 0) {
      return true; // Past date
    } else if (dateStr.compareTo(todayStr) > 0) {
      return false; // Future date
    } else {
      // Same day, check time
      final nowMinutes = now.hour * 60 + now.minute;
      final parts = jamSelesai.split(':');
      if (parts.length == 2) {
        final endHours = int.tryParse(parts[0]) ?? 0;
        final endMinutes = int.tryParse(parts[1]) ?? 0;
        final scheduleEndMinutes = endHours * 60 + endMinutes;
        return nowMinutes > scheduleEndMinutes;
      }
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = SessionService.currentUser!;
    final scheduleId = widget.scheduleData['scheduleId'] ?? '';
    final subjectName = widget.scheduleData['subjectName'] ?? 'Pelajaran';
    final className = widget.scheduleData['className'] ?? 'Kelas';
    final dateStr = widget.dateStr ?? _getTodayDateStr();
    final jamSelesai = widget.scheduleData['jamSelesai'] ?? '00:00';
    final isPassed = _isSchedulePassed(dateStr, jamSelesai);
    final isToday = dateStr == _getTodayDateStr();

    // Create the unique verification payload
    final qrPayload = 'sys_mng_school_attendance:{"schoolId":"${user.schoolId}","scheduleId":"$scheduleId","date":"$dateStr","className":"$className","subjectName":"$subjectName"}';
    

    return Scaffold(
      body: AuthBackground(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
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
                'QR Code Absensi',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    // Header info card
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                      ),
                      child: Column(
                        children: [
                          Text(
                            subjectName,
                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Kelas: $className',
                            style: const TextStyle(fontSize: 16, color: Color(0xFF10B981), fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _getFormattedIndonesianDate(dateStr),
                            style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.5)),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // QR Code Box (Only display if schedule has not passed)
                    if (!isPassed)
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF8B5CF6).withValues(alpha: 0.25),
                              blurRadius: 24,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            QrImageView(
                              data: qrPayload,
                              version: QrVersions.auto,
                              size: 200.0,
                              gapless: false,
                              foregroundColor: const Color(0xFF0F0C20),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Scan QR Code di atas untuk absen',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
                            ),
                          ],
                        ),
                      )
                    else
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                        ),
                        child: Column(
                          children: [
                            const Icon(Icons.history_toggle_off_rounded, color: Colors.amber, size: 48),
                            const SizedBox(height: 12),
                            const Text(
                              'Presensi Selesai / Terlewat',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Pembuatan QR Code dinonaktifkan karena jam pelajaran telah selesai atau tanggal pelaksanaan telah berlalu.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.5)),
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 32),

                    // Real-time Check-in Title
                    Row(
                      children: [
                        const Icon(Icons.people_alt_rounded, color: Colors.white, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          isToday ? 'Murid Hadir (Real-time)' : 'Murid Hadir (Riwayat)',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        const Spacer(),
                        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                          stream: _studentService.getScheduleAttendanceListStream(
                            schoolId: user.schoolId,
                            scheduleId: scheduleId,
                            dateStr: dateStr,
                          ),
                          builder: (context, snapshot) {
                            final count = snapshot.data?.docs.length ?? 0;
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
                              ),
                              child: Text(
                                '$count Murid',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
                              ),
                            );
                          },
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Stream List
                    StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: _studentService.getScheduleAttendanceListStream(
                        schoolId: user.schoolId,
                        scheduleId: scheduleId,
                        dateStr: dateStr,
                      ),
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return Container(
                            padding: const EdgeInsets.all(16),
                            child: const Text(
                              'Gagal memuat daftar murid hadir',
                              style: TextStyle(color: Colors.redAccent),
                            ),
                          );
                        }

                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.all(24.0),
                              child: CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            ),
                          );
                        }

                        final docs = snapshot.data?.docs ?? [];
                        // Sort di sisi Dart: terbaru di atas
                        final sorted = List.of(docs)
                          ..sort((a, b) {
                            final ta = (a.data()['timestamp'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
                            final tb = (b.data()['timestamp'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
                            return tb.compareTo(ta);
                          });
                        if (sorted.isEmpty) {
                          return Container(
                            padding: const EdgeInsets.symmetric(vertical: 40),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.03),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                            ),
                            child: const Center(
                              child: Column(
                                children: [
                                  Icon(Icons.hourglass_empty_rounded, size: 40, color: Colors.white24),
                                  SizedBox(height: 12),
                                  Text(
                                    'Belum ada murid yang melakukan absensi',
                                    style: TextStyle(color: Colors.white30, fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }

                        return ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: sorted.length,
                          itemBuilder: (context, index) {
                            final data = sorted[index].data();
                            final studentName = data['studentName'] ?? 'Murid';
                            final timestamp = data['timestamp'] as Timestamp?;
                            final method = data['method'] ?? 'QR Scan';

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.04),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: const Color(0xFF10B981).withValues(alpha: 0.2),
                                    child: const Icon(Icons.person_rounded, color: Color(0xFF10B981)),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          studentName,
                                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 15),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Metode: $method',
                                          style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.4)),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    _formatTime(timestamp),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF10B981),
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
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
      ),
    );
  }
}
