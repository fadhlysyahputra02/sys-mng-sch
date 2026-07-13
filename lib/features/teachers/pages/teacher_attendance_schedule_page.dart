import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/localization/app_localization.dart';
import '../../../core/services/session_service.dart';
import '../../authentication/widgets/auth_background.dart';
import '../../schools/pages/schedule/Service/class_schedule_service.dart';
import '../../students/data/student_service.dart';
import '../services/attendance_pdf_helper.dart';
import 'teacher_attendance_preview_page.dart';
import 'teacher_qr_attendance_page.dart';
import '../../schools/services/school_service.dart';

class TeacherAttendanceSchedulePage extends StatefulWidget {
  final String teacherId;
  final bool hideBackButton;
  const TeacherAttendanceSchedulePage({
    super.key,
    required this.teacherId,
    this.hideBackButton = false,
  });

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
      return AppLocalization.classStatusDone;
    } else if (selected.isAfter(today)) {
      return AppLocalization.classStatusUpcoming;
    } else {
      final nowMinutes = now.hour * 60 + now.minute;
      final startMinutes = _timeToMinutes(jamMulai);
      final endMinutes = _timeToMinutes(jamSelesai);

      if (nowMinutes < startMinutes) {
        return AppLocalization.classStatusUpcoming;
      } else if (nowMinutes > endMinutes) {
        return AppLocalization.classStatusDone;
      } else {
        return AppLocalization.classStatusOngoing;
      }
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final isDark = AuthBackground.isDarkMode.value;
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: isDark
                ? const ColorScheme.dark(
                    primary: Color(0xFF8B5CF6),
                    onPrimary: Colors.white,
                    surface: Color(0xFF0F0C20),
                    onSurface: Colors.white,
                  )
                : const ColorScheme.light(
                    primary: Color(0xFF8B5CF6),
                    onPrimary: Colors.white,
                    surface: Colors.white,
                    onSurface: Color(0xFF1E1B4B),
                  ),
            dialogBackgroundColor: isDark ? const Color(0xFF0F0C20) : Colors.white,
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



  String _getMonthNameIndonesian(int month) {
    const months = [
      'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
    ];
    return months[month - 1];
  }

  Future<void> _showDateRangeDialog(BuildContext context, List<Map<String, dynamic>> allSchedules) async {
    final now = DateTime.now();
    final List<DateTime> monthOptions = [];
    // Generate options for the last 12 months
    for (int i = 0; i < 12; i++) {
      monthOptions.add(DateTime(now.year, now.month - i, 1));
    }

    DateTime selectedMonth = monthOptions.first;

    final List<String> classOptions = [AppLocalization.isIndonesian ? 'Semua Kelas' : 'All Classes'];
    final uniqueClasses = allSchedules
        .map((s) => s['className']?.toString() ?? '')
        .where((name) => name.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    classOptions.addAll(uniqueClasses);

    String selectedClass = classOptions.first;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return ValueListenableBuilder<bool>(
              valueListenable: AuthBackground.isDarkMode,
              builder: (context, isDark, _) {
                final dialogBg = isDark ? const Color(0xFF0F0C20) : Colors.white;
                final dialogBorder = isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.08);
                final dialogTextColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
                final dialogSubTextColor = isDark ? Colors.white.withValues(alpha: 0.5) : const Color(0xFF1E1B4B).withValues(alpha: 0.6);
                final inputBg = isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04);
                final inputBorderColor = isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.08);
                final dropBg = isDark ? const Color(0xFF0F0C20) : Colors.white;

                return Dialog(
                  backgroundColor: dialogBg,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                    side: BorderSide(color: dialogBorder),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          AppLocalization.downloadRecap,
                          style: TextStyle(
                            color: dialogTextColor,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          AppLocalization.selectMonthClassForRecap,
                          style: TextStyle(color: dialogSubTextColor, fontSize: 12),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),

                        // Label Bulan
                        Text(
                          AppLocalization.monthLabel,
                          style: TextStyle(color: dialogTextColor.withValues(alpha: 0.75), fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          decoration: BoxDecoration(
                            color: inputBg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: inputBorderColor),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<DateTime>(
                              value: selectedMonth,
                              dropdownColor: dropBg,
                              icon: Icon(Icons.keyboard_arrow_down_rounded, color: dialogTextColor.withValues(alpha: 0.45)),
                              isExpanded: true,
                              style: TextStyle(color: dialogTextColor, fontSize: 14, fontWeight: FontWeight.bold),
                              items: monthOptions.map((date) {
                                final monthName = AppLocalization.monthNames[date.month - 1];
                                final year = date.year;
                                return DropdownMenuItem<DateTime>(
                                  value: date,
                                  child: Text('$monthName $year'),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setDialogState(() {
                                    selectedMonth = val;
                                  });
                                }
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Label Kelas
                        Text(
                          AppLocalization.classLabel,
                          style: TextStyle(color: dialogTextColor.withValues(alpha: 0.75), fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          decoration: BoxDecoration(
                            color: inputBg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: inputBorderColor),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: selectedClass,
                              dropdownColor: dropBg,
                              icon: Icon(Icons.keyboard_arrow_down_rounded, color: dialogTextColor.withValues(alpha: 0.45)),
                              isExpanded: true,
                              style: TextStyle(color: dialogTextColor, fontSize: 14, fontWeight: FontWeight.bold),
                              items: classOptions.map((className) {
                                return DropdownMenuItem<String>(
                                  value: className,
                                  child: Text(className),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setDialogState(() {
                                    selectedClass = val;
                                  });
                                }
                              },
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () {
                                  Navigator.pop(context);
                                  final startDate = DateTime(selectedMonth.year, selectedMonth.month, 1);
                                  final endDate = DateTime(selectedMonth.year, selectedMonth.month + 1, 0);
                                  _exportAllRecapPdfWithRange(context, allSchedules, startDate, endDate, selectedClass, isPreview: true);
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF10B981),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  elevation: 0,
                                ),
                                child: Text(
                                  AppLocalization.previewRecap,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 0.5),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () {
                                  Navigator.pop(context);
                                  final startDate = DateTime(selectedMonth.year, selectedMonth.month, 1);
                                  final endDate = DateTime(selectedMonth.year, selectedMonth.month + 1, 0);
                                  _exportAllRecapPdfWithRange(context, allSchedules, startDate, endDate, selectedClass, isPreview: false);
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
                                child: Text(
                                  AppLocalization.download,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 0.5),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          style: TextButton.styleFrom(
                            foregroundColor: dialogSubTextColor,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: Text(AppLocalization.cancel, style: const TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),
                );
              },
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
    String selectedClass,
    {bool isPreview = false}
  ) async {
    final user = SessionService.currentUser!;
    final teacherName = user.nama;
    final schoolData = await SchoolService().getSchoolByDomain(user.schoolId);
    final schoolName = schoolData?['namaSekolah']?.toString() ?? 'Sekolah';
    final tahunAjaran = schoolData?['tahunAjaran']?.toString() ?? '${DateTime.now().year}/${DateTime.now().year + 1}';
    final semester = schoolData?['semester']?.toString() ?? 'Semester 1';

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

      // Fetch classes to map classId to className
      final classesSnapshot = await FirebaseFirestore.instance
          .collection('schools')
          .doc(user.schoolId)
          .collection('classes')
          .get();
      
      final Map<String, String> classIdToName = {};
      for (var doc in classesSnapshot.docs) {
        final data = doc.data();
        final name = data['namaKelas']?.toString() ?? '';
        if (name.isNotEmpty) {
          classIdToName[doc.id] = name;
        }
      }

      // Dapatkan semua kelas dan mata pelajaran yang diajar oleh guru ini
      final teacherClassNames = allSchedules
          .map((s) => s['className'] as String?)
          .whereType<String>()
          .toSet();

      final teacherSubjectNames = allSchedules
          .map((s) => s['subjectName'] as String?)
          .whereType<String>()
          .toSet();

      // Filter berdasarkan kelas yang dipilih
      final Set<String> targetClasses = (selectedClass == 'Semua Kelas' || selectedClass == 'All Classes')
          ? teacherClassNames
          : {selectedClass};

      final targetSchedules = allSchedules
          .where((s) => targetClasses.contains(s['className'] as String?))
          .toList();

      // Filter data absensi untuk murid yang berada di kelas dan mapel yang diampu guru ini
      final filteredRecords = allRecords
          .where((r) =>
              targetClasses.contains(r['className'] as String?) &&
              teacherSubjectNames.contains(r['subjectName'] as String?))
          .toList();

      // Gunakan tahun ajaran dan semester dari data absensi yang difetch, jika tersedia
      String recordTahunAjaran = tahunAjaran;
      String recordSemester = semester;
      if (filteredRecords.isNotEmpty) {
        // Ambil dari record pertama yang valid
        final firstValid = filteredRecords.firstWhere(
          (r) => r['tahunAjaran'] != null && r['tahunAjaran'] != '-', 
          orElse: () => <String, dynamic>{}
        );
        if (firstValid.isNotEmpty) {
          recordTahunAjaran = firstValid['tahunAjaran']?.toString() ?? tahunAjaran;
          recordSemester = firstValid['semester']?.toString() ?? semester;
        }
      } else {
        // Fallback to calculated term from the month/year
        if (start.month >= 7 && start.month <= 12) {
          recordTahunAjaran = '${start.year}/${start.year + 1}';
          recordSemester = 'Semester 1';
        } else {
          recordTahunAjaran = '${start.year - 1}/${start.year}';
          recordSemester = 'Semester 2';
        }
      }

      final activeTahunAjaran = schoolData?['tahunAjaran']?.toString() ?? '';
      final activeSemester = schoolData?['semester']?.toString() ?? '';

      List<Map<String, dynamic>> targetStudents = [];

      if (recordTahunAjaran == activeTahunAjaran && recordSemester == activeSemester) {
        // Fetch active students in the school
        final studentsSnapshot = await FirebaseFirestore.instance
            .collection('schools')
            .doc(user.schoolId)
            .collection('students')
            .get();

        final List<Map<String, dynamic>> allStudents = studentsSnapshot.docs.map((doc) {
          final data = doc.data();
          return {
            ...data,
            'studentId': doc.id,
          };
        }).toList();

        targetStudents = allStudents.where((student) {
          final sClassId = student['classId']?.toString() ?? '';
          final sClassName = classIdToName[sClassId] ?? '';
          return targetClasses.contains(sClassName);
        }).toList();
      } else {
        // Query class_enrollments for the historical term
        final enrollmentSnapshot = await FirebaseFirestore.instance
            .collection('schools')
            .doc(user.schoolId)
            .collection('class_enrollments')
            .where('tahunAjaran', isEqualTo: recordTahunAjaran)
            .where('semester', isEqualTo: recordSemester)
            .get();

        targetStudents = enrollmentSnapshot.docs.map((doc) {
          final data = doc.data();
          return {
            ...data,
            'studentId': data['studentId'] ?? doc.id, // clean studentId
          };
        }).where((student) {
          final sClassName = student['className']?.toString() ?? '';
          return targetClasses.contains(sClassName);
        }).toList();

        // Fallback to active students if historical enrollments are empty
        if (targetStudents.isEmpty) {
          final studentsSnapshot = await FirebaseFirestore.instance
              .collection('schools')
              .doc(user.schoolId)
              .collection('students')
              .get();

          final List<Map<String, dynamic>> allStudents = studentsSnapshot.docs.map((doc) {
            final data = doc.data();
            return {
              ...data,
              'studentId': doc.id,
            };
          }).toList();

          targetStudents = allStudents.where((student) {
            final sClassId = student['classId']?.toString() ?? '';
            final sClassName = classIdToName[sClassId] ?? '';
            return targetClasses.contains(sClassName);
          }).toList();
        }
      }

      // Tutup loading dialog
      Get.back();

      if (targetStudents.isEmpty) {
        Get.snackbar(
          'Informasi',
          'Tidak ada murid pada kelas yang dipilih.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.amber,
          colorText: Colors.black,
          margin: const EdgeInsets.all(16),
          borderRadius: 12,
        );
        return;
      }

      if (isPreview) {
        Get.to(() => TeacherAttendancePreviewPage(
          teacherName: teacherName,
          startDate: start,
          endDate: end,
          records: filteredRecords,
          schedules: targetSchedules,
          students: targetStudents,
          classIdToName: classIdToName,
          schoolName: schoolName,
          tahunAjaran: recordTahunAjaran,
          semester: recordSemester,
        ));
      } else {
        // Panggil PDF Helper untuk generate rekap gabungan dengan jadwal guru saja
        await AttendancePdfHelper.generateAndShowAllPdf(
          teacherName: teacherName,
          startDate: start,
          endDate: end,
          records: filteredRecords,
          schedules: targetSchedules,
          students: targetStudents,
          classIdToName: classIdToName,
          schoolName: schoolName,
          tahunAjaran: recordTahunAjaran,
          semester: recordSemester,
        );
      }

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
        AppLocalization.isIndonesian ? 'Informasi' : 'Information',
        AppLocalization.noScheduleForRecap,
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
  @override
  Widget build(BuildContext context) {
    final user = SessionService.currentUser!;
    final todayHari = _getTodayHariIndonesian();
    final recapHari = _getHariIndonesianFor(_selectedDate);
    final recapDateStr = _getDateStrFor(_selectedDate);

    return ValueListenableBuilder<String>(
      valueListenable: AppLocalization.currentLocale,
      builder: (context, locale, _) {
        return ValueListenableBuilder<bool>(
          valueListenable: AuthBackground.isDarkMode,
          builder: (context, isDark, _) {
        final titleColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
        final backButtonBgColor = isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05);
        final backButtonIconColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
        final progressColor = isDark ? Colors.white : const Color(0xFF8B5CF6);

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
                    automaticallyImplyLeading: !widget.hideBackButton,
                    iconTheme: IconThemeData(color: backButtonIconColor),
                    leading: widget.hideBackButton
                        ? null
                        : Container(
                            margin: const EdgeInsets.only(left: 16),
                            decoration: BoxDecoration(
                              color: backButtonBgColor,
                              shape: BoxShape.circle,
                            ),
                            child: IconButton(
                              icon: Icon(Icons.arrow_back_ios_new_rounded, color: backButtonIconColor, size: 18),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ),
                    title: Text(
                      AppLocalization.studentAttendanceTitle,
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: titleColor),
                    ),
                    actions: [
                      if (snapshot.connectionState != ConnectionState.waiting && !snapshot.hasError)
                        Padding(
                          padding: const EdgeInsets.only(right: 16, top: 10, bottom: 10),
                          child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                            stream: FirebaseFirestore.instance.collection('schools').doc(user.schoolId).snapshots(),
                            builder: (context, schoolSnap) {
                              final bool isRecapEnabled = schoolSnap.data?.data()?['enableERapor'] ?? false;
                              return TextButton(
                                onPressed: () {
                                  if (!isRecapEnabled && schoolSnap.connectionState != ConnectionState.waiting) {
                                    showDialog(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        backgroundColor: isDark ? const Color(0xFF151026) : Colors.white,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                        title: Row(
                                          children: [
                                            const Icon(Icons.lock_rounded, color: Colors.amber),
                                            const SizedBox(width: 8),
                                            Text(AppLocalization.featureLocked, style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
                                          ],
                                        ),
                                        content: Text(
                                          AppLocalization.featureLockedDesc,
                                          style: TextStyle(color: isDark ? Colors.white70 : Colors.black87),
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(context),
                                            child: const Text('OK', style: TextStyle(color: Color(0xFF8B5CF6))),
                                          ),
                                        ],
                                      ),
                                    );
                                  } else if (isRecapEnabled) {
                                    _exportAllRecapPdf(context, allSchedules);
                                  }
                                },
                                style: TextButton.styleFrom(
                                  backgroundColor: (!isRecapEnabled && schoolSnap.connectionState != ConnectionState.waiting) 
                                      ? Colors.grey.shade800 
                                      : const Color(0xFF8B5CF6),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (!isRecapEnabled && schoolSnap.connectionState != ConnectionState.waiting)
                                      const Padding(
                                        padding: EdgeInsets.only(right: 4),
                                        child: Icon(Icons.lock_rounded, size: 14, color: Colors.white70),
                                      ),
                                    Text(
                                      AppLocalization.downloadRecap,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                  body: snapshot.hasError
                      ? _buildErrorBox('Terjadi kesalahan memuat jadwal', isDark)
                      : snapshot.connectionState == ConnectionState.waiting
                          ? Center(
                              child: CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                              ),
                            )
                          : RefreshIndicator(
                              onRefresh: () async {
                                setState(() {});
                              },
                              color: const Color(0xFF8B5CF6),
                              backgroundColor: isDark ? const Color(0xFF0F0C20) : Colors.white,
                              child: SingleChildScrollView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    // Clock / Date card
                                    _buildDateHeaderCard(isDark),
                                    const SizedBox(height: 24),

                                    // Active Subject Section
                                    _buildSectionHeader(AppLocalization.activeSubjectNow, Icons.sensors_rounded, isDark),
                                    const SizedBox(height: 12),
                                    _buildActiveScheduleSection(activeSchedules, isDark),
                                    const SizedBox(height: 28),

                                    // Today's/Past Recap Section
                                    _buildRecapSectionHeader(recapDateStr, isDark),
                                    const SizedBox(height: 12),
                                    _buildTodayRecapSection(recapSchedules, user.schoolId, recapDateStr, _selectedDate, isDark),
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
          },
        );
      },
    );
  }

  Widget _buildDateHeaderCard(bool isDark) {
    final cardBg = isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white;
    final cardBorder = isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.08);
    final cardShadow = isDark ? Colors.transparent : Colors.black.withValues(alpha: 0.03);
    final textColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
    final subTextColor = isDark ? Colors.white.withValues(alpha: 0.5) : const Color(0xFF1E1B4B).withValues(alpha: 0.6);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: cardBorder),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: cardShadow,
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
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
                  style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 4),
                Text(
                  '${AppLocalization.serverTimeLabel}: ${_getFormattedTime()} WIB',
                  style: TextStyle(color: subTextColor, fontSize: 12, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, bool isDark) {
    final headerColor = isDark ? Colors.white70 : const Color(0xFF1E1B4B).withValues(alpha: 0.75);
    final iconColor = isDark ? Colors.white54 : const Color(0xFF1E1B4B).withValues(alpha: 0.55);

    return Row(
      children: [
        Icon(icon, color: iconColor, size: 18),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            color: headerColor,
            fontWeight: FontWeight.bold,
            fontSize: 13,
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
  }

  Widget _buildRecapSectionHeader(String dateStr, bool isDark) {
    final now = DateTime.now();
    final todayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final isToday = dateStr == todayStr;
    final headerColor = isDark ? Colors.white70 : const Color(0xFF1E1B4B).withValues(alpha: 0.75);
    final iconColor = isDark ? Colors.white54 : const Color(0xFF1E1B4B).withValues(alpha: 0.55);

    return Row(
      children: [
        Icon(Icons.summarize_rounded, color: iconColor, size: 18),
        const SizedBox(width: 8),
        Text(
          isToday ? AppLocalization.todayAttendanceRecap : AppLocalization.attendanceRecapDate,
          style: TextStyle(
            color: headerColor,
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
            isToday ? AppLocalization.chooseDate : _getFormattedDateFor(_selectedDate),
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

  Widget _buildActiveScheduleSection(List<Map<String, dynamic>> activeSchedules, bool isDark) {
    final cardBg = isDark ? Colors.white.withValues(alpha: 0.03) : Colors.white;
    final cardBorder = isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.06);
    final cardShadow = isDark ? Colors.transparent : Colors.black.withValues(alpha: 0.03);
    final emptyTextColor = isDark ? Colors.white.withValues(alpha: 0.38) : const Color(0xFF1E1B4B).withValues(alpha: 0.5);

    if (activeSchedules.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: cardBorder),
          boxShadow: isDark
              ? []
              : [
                  BoxShadow(
                    color: cardShadow,
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.query_builder_rounded, color: isDark ? Colors.white30 : const Color(0xFF1E1B4B).withValues(alpha: 0.3), size: 36),
              const SizedBox(height: 10),
              Text(
                AppLocalization.noActiveSubjectNow,
                textAlign: TextAlign.center,
                style: TextStyle(color: emptyTextColor, fontSize: 13, fontStyle: FontStyle.italic),
              ),
            ],
          ),
        ),
      );
    }

    final textColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
    final subTextColor = isDark ? Colors.white.withValues(alpha: 0.7) : const Color(0xFF1E1B4B).withValues(alpha: 0.8);

    return Column(
      children: activeSchedules.map((s) {
        final subjectName = s['subjectName'] ?? AppLocalization.subjectLabel;
        final className = s['className'] ?? AppLocalization.classLabel;
        final jamMulai = s['jamMulai'] ?? '00:00';
        final jamSelesai = s['jamSelesai'] ?? '00:00';

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? [
                      const Color(0xFF6366F1).withValues(alpha: 0.15),
                      const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                    ]
                  : [
                      Colors.white,
                      Colors.white,
                    ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: isDark ? const Color(0xFF8B5CF6).withValues(alpha: 0.3) : const Color(0xFF8B5CF6).withValues(alpha: 0.15)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF8B5CF6).withValues(alpha: isDark ? 0.1 : 0.08),
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
                    child: Text(
                      AppLocalization.classStatusOngoing,
                      style: const TextStyle(color: Color(0xFF10B981), fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                subjectName,
                style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 20),
              ),
              const SizedBox(height: 4),
              Text(
                '${AppLocalization.classLabel}: $className',
                style: TextStyle(color: subTextColor, fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.schedule_rounded, color: isDark ? Colors.white38 : const Color(0xFF1E1B4B).withValues(alpha: 0.4), size: 14),
                  const SizedBox(width: 6),
                  Text(
                    '$jamMulai – $jamSelesai WIB',
                    style: TextStyle(color: isDark ? Colors.white.withValues(alpha: 0.5) : const Color(0xFF1E1B4B).withValues(alpha: 0.6), fontSize: 13),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () => Get.to(() => TeacherQrAttendancePage(scheduleData: s)),
                icon: const Icon(Icons.qr_code_2_rounded, size: 20),
                label: Text(AppLocalization.openQrAttendance, style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5)),
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

  Widget _buildTodayRecapSection(List<Map<String, dynamic>> todaySchedules, String schoolId, String dateStr, DateTime selectedDate, bool isDark) {
    final cardBg = isDark ? Colors.white.withValues(alpha: 0.03) : Colors.white;
    final cardBorder = isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.06);
    final cardShadow = isDark ? Colors.transparent : Colors.black.withValues(alpha: 0.03);
    final emptyTextColor = isDark ? Colors.white.withValues(alpha: 0.38) : const Color(0xFF1E1B4B).withValues(alpha: 0.5);

    if (todaySchedules.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: cardBorder),
          boxShadow: isDark
              ? []
              : [
                  BoxShadow(
                    color: cardShadow,
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Center(
          child: Text(
            AppLocalization.noTeachingScheduleDate,
            textAlign: TextAlign.center,
            style: TextStyle(color: emptyTextColor, fontSize: 13, fontStyle: FontStyle.italic),
          ),
        ),
      );
    }

    final textColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
    final subTextColor = isDark ? Colors.white.withValues(alpha: 0.6) : const Color(0xFF1E1B4B).withValues(alpha: 0.7);

    return Column(
      children: todaySchedules.map((s) {
        final scheduleId = s['scheduleId'] ?? '';
        final subjectName = s['subjectName'] ?? AppLocalization.subjectLabel;
        final className = s['className'] ?? AppLocalization.classLabel;
        final jamMulai = s['jamMulai'] ?? '00:00';
        final jamSelesai = s['jamSelesai'] ?? '00:00';

        final status = _getClassStatus(selectedDate, jamMulai, jamSelesai);

        Color accentColor;
        Color statusColor;
        if (status == AppLocalization.classStatusOngoing) {
          accentColor = const Color(0xFF10B981);
          statusColor = const Color(0xFF10B981);
        } else if (status == AppLocalization.classStatusUpcoming) {
          accentColor = const Color(0xFFF59E0B);
          statusColor = const Color(0xFFF59E0B);
        } else {
          accentColor = isDark ? Colors.white24 : const Color(0xFF1E1B4B).withValues(alpha: 0.2);
          statusColor = isDark ? Colors.white38 : const Color(0xFF1E1B4B).withValues(alpha: 0.4);
        }

        final tileBg = isDark ? Colors.white.withValues(alpha: 0.04) : Colors.white;
        final tileBorder = isDark
            ? (status == AppLocalization.classStatusOngoing
                ? const Color(0xFF8B5CF6).withValues(alpha: 0.3)
                : Colors.white.withValues(alpha: 0.08))
            : (status == AppLocalization.classStatusOngoing
                ? const Color(0xFF8B5CF6).withValues(alpha: 0.4)
                : Colors.black.withValues(alpha: 0.06));

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: tileBg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: tileBorder),
            boxShadow: isDark
                ? []
                : [
                    BoxShadow(
                      color: cardShadow,
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
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
                                      style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 15),
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
                                '${AppLocalization.classLabel}: $className',
                                style: TextStyle(color: subTextColor, fontSize: 12, fontWeight: FontWeight.w500),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(Icons.schedule_rounded, color: isDark ? Colors.white30 : const Color(0xFF1E1B4B).withValues(alpha: 0.3), size: 12),
                                  const SizedBox(width: 4),
                                  Text(
                                    '$jamMulai - $jamSelesai',
                                    style: TextStyle(color: isDark ? Colors.white.withValues(alpha: 0.4) : const Color(0xFF1E1B4B).withValues(alpha: 0.5), fontSize: 11),
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
                                              color: count > 0 ? const Color(0xFF10B981) : (isDark ? Colors.white30 : const Color(0xFF1E1B4B).withValues(alpha: 0.3)),
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              '$count ${AppLocalization.studentsPresent}',
                                              style: TextStyle(
                                                color: count > 0 ? const Color(0xFF10B981) : (isDark ? Colors.white38 : const Color(0xFF1E1B4B).withValues(alpha: 0.4)),
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

                      Icon(Icons.chevron_right_rounded, color: isDark ? Colors.white30 : const Color(0xFF1E1B4B).withValues(alpha: 0.3)),
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

  Widget _buildErrorBox(String message, bool isDark) {
    final textColor = isDark ? Colors.white : const Color(0xFF1E1B4B);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline_rounded, size: 48, color: Colors.redAccent),
          const SizedBox(height: 12),
          Text(
            message,
            style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
