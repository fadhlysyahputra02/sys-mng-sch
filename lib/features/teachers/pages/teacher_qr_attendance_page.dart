import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  String _resolvedClassId = '';
  String _tahunAjaran = '-';
  String _semester = '-';
  StreamSubscription<QuerySnapshot>? _attendanceSubscription;
  int? _previousAttendanceCount;

  static const _feedbackChannel = MethodChannel('com.sysmngsch.sys_mng_school/feedback');

  @override
  void initState() {
    super.initState();
    _resolvedClassId = widget.scheduleData['classId']?.toString() ?? '';
    if (_resolvedClassId.isEmpty) {
      _resolveClassId();
    }
    _fetchSchoolData();
    _listenToAttendance();
  }

  Future<void> _fetchSchoolData() async {
    try {
      final user = SessionService.currentUser!;
      final doc = await FirebaseFirestore.instance.collection('schools').doc(user.schoolId).get();
      if (doc.exists) {
        if (mounted) {
          setState(() {
            _tahunAjaran = doc.data()?['tahunAjaran'] ?? '-';
            _semester = doc.data()?['semester'] ?? '-';
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching school data: $e');
    }
  }

  Future<void> _resolveClassId() async {
    try {
      final user = SessionService.currentUser!;
      final className = widget.scheduleData['className'] ?? '';
      if (className.isNotEmpty) {
        final querySnapshot = await FirebaseFirestore.instance
            .collection('schools')
            .doc(user.schoolId)
            .collection('classes')
            .where('namaKelas', isEqualTo: className)
            .limit(1)
            .get();
        if (querySnapshot.docs.isNotEmpty) {
          if (mounted) {
            setState(() {
              _resolvedClassId = querySnapshot.docs.first.id;
            });
          }
        }
      }
    } catch (e) {
      debugPrint('Error resolving classId: $e');
    }
  }

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
  @override
  Widget build(BuildContext context) {
    final user = SessionService.currentUser!;
    final scheduleId = widget.scheduleData['scheduleId'] ?? '';
    final subjectName = widget.scheduleData['subjectName'] ?? 'Pelajaran';
    final className = widget.scheduleData['className'] ?? 'Kelas';
    final dateStr = widget.dateStr ?? _getTodayDateStr();
    final jamSelesai = widget.scheduleData['jamSelesai'] ?? '00:00';
    final classId = _resolvedClassId.isNotEmpty ? _resolvedClassId : (widget.scheduleData['classId'] ?? '');
    final isPassed = _isSchedulePassed(dateStr, jamSelesai);
    final isToday = dateStr == _getTodayDateStr();

    // Create the unique verification payload
    final qrPayload = 'sys_mng_school_attendance:{"schoolId":"${user.schoolId}","scheduleId":"$scheduleId","date":"$dateStr","className":"$className","subjectName":"$subjectName"}';

    return ValueListenableBuilder<bool>(
      valueListenable: AuthBackground.isDarkMode,
      builder: (context, isDark, _) {
        final titleColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
        final subTextColor = isDark ? Colors.white.withValues(alpha: 0.5) : const Color(0xFF1E1B4B).withValues(alpha: 0.6);
        final cardBgColor = isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white;
        final cardBorderColor = isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.08);
        final iconBgColor = isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05);
        final iconColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
        final progressColor = isDark ? Colors.white : const Color(0xFF8B5CF6);
        final shadowColor = isDark ? Colors.transparent : Colors.black.withValues(alpha: 0.04);

        return Scaffold(
          body: AuthBackground(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverAppBar(
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  pinned: true,
                  iconTheme: IconThemeData(color: iconColor),
                  leading: Container(
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
                    'QR Code Absensi',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: titleColor),
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
                            color: cardBgColor,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: cardBorderColor),
                            boxShadow: isDark ? [] : [
                              BoxShadow(
                                color: shadowColor,
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              Text(
                                subjectName,
                                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: titleColor),
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
                                style: TextStyle(fontSize: 13, color: subTextColor),
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
                              color: cardBgColor,
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(color: cardBorderColor),
                              boxShadow: isDark ? [] : [
                                BoxShadow(
                                  color: shadowColor,
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                const Icon(Icons.history_toggle_off_rounded, color: Colors.amber, size: 48),
                                const SizedBox(height: 12),
                                Text(
                                  'Presensi Selesai / Terlewat',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: titleColor),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Pembuatan QR Code dinonaktifkan karena jam pelajaran telah selesai atau tanggal pelaksanaan telah berlalu.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 12, color: subTextColor),
                                ),
                              ],
                            ),
                          ),

                        const SizedBox(height: 32),

                        // Real-time Check-in Title
                        Row(
                          children: [
                            Icon(Icons.people_alt_rounded, color: iconColor, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              isToday ? 'Murid Hadir (Real-time)' : 'Murid Hadir (Riwayat)',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: titleColor),
                            ),
                            const Spacer(),
                            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                              stream: FirebaseFirestore.instance
                                  .collection('schools')
                                  .doc(user.schoolId)
                                  .collection('students')
                                  .where('classId', isEqualTo: classId)
                                  .snapshots(),
                              builder: (context, classSnapshot) {
                                final total = classSnapshot.data?.docs.length ?? 0;
                                return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
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
                                        total > 0 ? '$count / $total Murid' : '$count Murid',
                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // Stream List
                        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                          stream: FirebaseFirestore.instance
                              .collection('schools')
                              .doc(user.schoolId)
                              .collection('students')
                              .where('classId', isEqualTo: classId)
                              .snapshots(),
                          builder: (context, classSnapshot) {
                            if (classSnapshot.hasError) {
                              return Container(
                                padding: const EdgeInsets.all(16),
                                child: Text(
                                  'Gagal memuat daftar murid kelas: ${classSnapshot.error}',
                                  style: const TextStyle(color: Colors.redAccent),
                                ),
                              );
                            }

                            if (classSnapshot.connectionState == ConnectionState.waiting) {
                              return Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(24.0),
                                  child: CircularProgressIndicator(
                                    valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                                  ),
                                ),
                              );
                            }

                            final allStudents = classSnapshot.data?.docs ?? [];

                            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                              stream: _studentService.getScheduleAttendanceListStream(
                                schoolId: user.schoolId,
                                scheduleId: scheduleId,
                                dateStr: dateStr,
                              ),
                              builder: (context, attendanceSnapshot) {
                                if (attendanceSnapshot.hasError) {
                                  return Container(
                                    padding: const EdgeInsets.all(16),
                                    child: const Text(
                                      'Gagal memuat daftar kehadiran',
                                      style: TextStyle(color: Colors.redAccent),
                                    ),
                                  );
                                }

                                if (attendanceSnapshot.connectionState == ConnectionState.waiting) {
                                  return Center(
                                    child: Padding(
                                      padding: const EdgeInsets.all(24.0),
                                      child: CircularProgressIndicator(
                                        valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                                      ),
                                    ),
                                  );
                                }

                                final attendanceDocs = attendanceSnapshot.data?.docs ?? [];
                                
                                // Map studentId -> attendance data
                                final Map<String, Map<String, dynamic>> attendanceMap = {};
                                for (var doc in attendanceDocs) {
                                  final data = doc.data();
                                  final studentId = data['studentId'] ?? '';
                                  if (studentId.isNotEmpty) {
                                    attendanceMap[studentId] = data;
                                  }
                                }

                                // Build the combined list
                                final List<Map<String, dynamic>> combinedList = [];
                                if (allStudents.isNotEmpty) {
                                  for (var studentDoc in allStudents) {
                                    final studentData = studentDoc.data();
                                    final studentId = studentDoc.id;
                                    final hasCheckedIn = attendanceMap.containsKey(studentId);
                                    
                                    combinedList.add({
                                      'studentId': studentId,
                                      'nama': studentData['nama'] ?? 'Murid',
                                      'nis': studentData['nis'] ?? '-',
                                      'hasCheckedIn': hasCheckedIn,
                                      'attendanceData': hasCheckedIn ? attendanceMap[studentId] : null,
                                    });
                                  }
                                } else {
                                  // Fallback for empty students list (e.g. legacy schedules or classId not set)
                                  for (var doc in attendanceDocs) {
                                    final data = doc.data();
                                    final studentId = data['studentId'] ?? '';
                                    combinedList.add({
                                      'studentId': studentId,
                                      'nama': data['studentName'] ?? 'Murid',
                                      'nis': '-',
                                      'hasCheckedIn': true,
                                      'attendanceData': data,
                                    });
                                  }
                                }

                                if (combinedList.isEmpty) {
                                  return Container(
                                    padding: const EdgeInsets.symmetric(vertical: 40),
                                    decoration: BoxDecoration(
                                      color: cardBgColor,
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: cardBorderColor),
                                    ),
                                    child: Center(
                                      child: Column(
                                        children: [
                                          Icon(Icons.hourglass_empty_rounded, size: 40, color: subTextColor.withValues(alpha: 0.5)),
                                          const SizedBox(height: 12),
                                          Text(
                                            'Belum ada murid di kelas ini',
                                            style: TextStyle(color: subTextColor, fontSize: 13),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }

                                // Sort: Checked in first (sorted by timestamp descending), then not checked in (alphabetically)
                                combinedList.sort((a, b) {
                                  final aChecked = a['hasCheckedIn'] as bool;
                                  final bChecked = b['hasCheckedIn'] as bool;
                                  
                                  if (aChecked && !bChecked) return -1;
                                  if (!aChecked && bChecked) return 1;
                                  
                                  if (aChecked && bChecked) {
                                    final ta = (a['attendanceData']['timestamp'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
                                    final tb = (b['attendanceData']['timestamp'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
                                    return tb.compareTo(ta); // latest first
                                  } else {
                                    final String na = a['nama'] as String;
                                    final String nb = b['nama'] as String;
                                    return na.compareTo(nb); // alphabetical
                                  }
                                });

                                return ListView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: combinedList.length,
                                  itemBuilder: (context, index) {
                                    final item = combinedList[index];
                                    final studentName = item['nama'];
                                    final hasCheckedIn = item['hasCheckedIn'] as bool;

                                    if (hasCheckedIn) {
                                      final attData = item['attendanceData'] as Map<String, dynamic>;
                                      final timestamp = attData['timestamp'] as Timestamp?;
                                      final method = attData['method'] ?? 'QR Scan';
                                      final status = attData['status'] ?? 'Hadir';
                                      
                                      Color statusColor = const Color(0xFF10B981); // Hadir
                                      if (status == 'Izin') statusColor = const Color(0xFF3B82F6);
                                      if (status == 'Sakit') statusColor = const Color(0xFFF59E0B);

                                      return Container(
                                        margin: const EdgeInsets.only(bottom: 12),
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                        decoration: BoxDecoration(
                                          color: cardBgColor,
                                          borderRadius: BorderRadius.circular(16),
                                          border: Border.all(color: cardBorderColor),
                                        ),
                                        child: Row(
                                          children: [
                                            CircleAvatar(
                                              backgroundColor: statusColor.withValues(alpha: 0.2),
                                              child: Icon(Icons.person_rounded, color: statusColor),
                                            ),
                                            const SizedBox(width: 14),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    studentName,
                                                    style: TextStyle(fontWeight: FontWeight.bold, color: titleColor, fontSize: 15),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    'Status: $status • Metode: $method',
                                                    style: TextStyle(fontSize: 11, color: subTextColor),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Text(
                                              _formatTime(timestamp),
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: statusColor,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    } else {
                                      return Container(
                                        margin: const EdgeInsets.only(bottom: 12),
                                        decoration: BoxDecoration(
                                          color: isDark ? Colors.white.withValues(alpha: 0.02) : Colors.black.withValues(alpha: 0.02),
                                          borderRadius: BorderRadius.circular(16),
                                          border: Border.all(
                                            color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.04),
                                          ),
                                        ),
                                        child: Material(
                                          color: Colors.transparent,
                                          child: InkWell(
                                            onTap: () {
                                              _showManualAttendanceDialog(
                                                context,
                                                user.schoolId,
                                                item['studentId'],
                                                studentName,
                                                scheduleId,
                                                widget.scheduleData['subjectName'] ?? '',
                                                widget.scheduleData['className'] ?? '',
                                                classId,
                                                dateStr,
                                              );
                                            },
                                            borderRadius: BorderRadius.circular(16),
                                            child: Padding(
                                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                              child: Row(
                                                children: [
                                                  CircleAvatar(
                                                    backgroundColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
                                                    child: Icon(Icons.person_outline_rounded, color: subTextColor),
                                                  ),
                                                  const SizedBox(width: 14),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        Text(
                                                          studentName,
                                                          style: TextStyle(
                                                            fontWeight: FontWeight.bold, 
                                                            color: titleColor.withValues(alpha: 0.7), 
                                                            fontSize: 15,
                                                          ),
                                                        ),
                                                        const SizedBox(height: 2),
                                                        Text(
                                                          'Belum melakukan presensi (Klik untuk atur)',
                                                          style: TextStyle(
                                                            fontSize: 11, 
                                                            color: Colors.orangeAccent.withValues(alpha: 0.8),
                                                            fontWeight: FontWeight.w500,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  Icon(
                                                    Icons.touch_app_rounded,
                                                    size: 16,
                                                    color: Colors.orangeAccent.withValues(alpha: 0.6),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      );
                                    }
                                  },
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
      },
    );
  }

  void _listenToAttendance() {
    final user = SessionService.currentUser!;
    final scheduleId = widget.scheduleData['scheduleId'] ?? '';
    final dateStr = widget.dateStr ?? _getTodayDateStr();

    _attendanceSubscription = _studentService
        .getScheduleAttendanceListStream(
          schoolId: user.schoolId,
          scheduleId: scheduleId,
          dateStr: dateStr,
        )
        .listen((snapshot) {
      final currentCount = snapshot.docs.length;
      if (_previousAttendanceCount != null && currentCount > _previousAttendanceCount!) {
        _playBeepAndVibrate();
      }
      _previousAttendanceCount = currentCount;
    });
  }

  Future<void> _playBeepAndVibrate() async {
    try {
      await HapticFeedback.vibrate();
      await _feedbackChannel.invokeMethod('playBeep');
    } catch (e) {
      debugPrint('Error playing beep/vibrate: $e');
    }
  }


  void _showManualAttendanceDialog(
    BuildContext context,
    String schoolId,
    String studentId,
    String studentName,
    String scheduleId,
    String subjectName,
    String className,
    String classId,
    String dateStr,
  ) {
    final tahunAjaran = _tahunAjaran;
    final semester = _semester;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Beri Keterangan', style: TextStyle(fontWeight: FontWeight.bold)),
          content: Text('Atur kehadiran untuk $studentName:'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal', style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _studentService.checkInScheduleAttendance(
                  schoolId: schoolId,
                  studentId: studentId,
                  studentName: studentName,
                  classId: classId,
                  className: className,
                  scheduleId: scheduleId,
                  subjectName: subjectName,
                  dateStr: dateStr,
                  checkInMethod: 'Manual (Guru)',
                  tahunAjaran: tahunAjaran,
                  semester: semester,
                  status: 'Hadir',
                );
              },
              child: const Text('Hadir', style: TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold)),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _studentService.checkInScheduleAttendance(
                  schoolId: schoolId,
                  studentId: studentId,
                  studentName: studentName,
                  classId: classId,
                  className: className,
                  scheduleId: scheduleId,
                  subjectName: subjectName,
                  dateStr: dateStr,
                  checkInMethod: 'Manual (Guru)',
                  tahunAjaran: tahunAjaran,
                  semester: semester,
                  status: 'Izin',
                );
              },
              child: const Text('Izin', style: TextStyle(color: Color(0xFF3B82F6), fontWeight: FontWeight.bold)),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _studentService.checkInScheduleAttendance(
                  schoolId: schoolId,
                  studentId: studentId,
                  studentName: studentName,
                  classId: classId,
                  className: className,
                  scheduleId: scheduleId,
                  subjectName: subjectName,
                  dateStr: dateStr,
                  checkInMethod: 'Manual (Guru)',
                  tahunAjaran: tahunAjaran,
                  semester: semester,
                  status: 'Sakit',
                );
              },
              child: const Text('Sakit', style: TextStyle(color: Color(0xFFF59E0B), fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _attendanceSubscription?.cancel();
    super.dispose();
  }
}

