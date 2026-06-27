import 'package:flutter/material.dart';
import '../../authentication/widgets/auth_background.dart';

class TeacherAttendancePreviewPage extends StatefulWidget {
  final String teacherName;
  final DateTime startDate;
  final DateTime endDate;
  final List<Map<String, dynamic>> records;
  final List<Map<String, dynamic>> schedules;
  final List<Map<String, dynamic>> students;
  final Map<String, String> classIdToName;
  final String schoolName;
  final String tahunAjaran;
  final String semester;

  const TeacherAttendancePreviewPage({
    super.key,
    required this.teacherName,
    required this.startDate,
    required this.endDate,
    required this.records,
    required this.schedules,
    required this.students,
    required this.classIdToName,
    required this.schoolName,
    required this.tahunAjaran,
    required this.semester,
  });

  @override
  State<TeacherAttendancePreviewPage> createState() => _TeacherAttendancePreviewPageState();
}

class _TeacherAttendancePreviewPageState extends State<TeacherAttendancePreviewPage> {
  late List<_AttendanceGroup> _groups;

  @override
  void initState() {
    super.initState();
    _processData();
  }

  void _processData() {
    _groups = [];

    // Sort schedules
    final sortedSchedules = List<Map<String, dynamic>>.from(widget.schedules);
    sortedSchedules.sort((a, b) {
      final classA = a['className']?.toString() ?? '';
      final classB = b['className']?.toString() ?? '';
      final compClass = classA.compareTo(classB);
      if (compClass != 0) return compClass;

      final subjA = a['subjectName']?.toString() ?? '';
      final subjB = b['subjectName']?.toString() ?? '';
      final compSubj = subjA.compareTo(subjB);
      if (compSubj != 0) return compSubj;

      final timeA = a['jamMulai']?.toString() ?? '';
      final timeB = b['jamMulai']?.toString() ?? '';
      return timeA.compareTo(timeB);
    });

    final Set<String> processedPairs = {};
    final int daysInMonth = DateTime(widget.startDate.year, widget.startDate.month + 1, 0).day;

    for (var schedule in sortedSchedules) {
      final scheduleId = schedule['scheduleId']?.toString() ?? '';
      final classId = schedule['classId']?.toString() ?? '';
      final subjectName = schedule['subjectName']?.toString() ?? 'Pelajaran';
      final className = widget.classIdToName[classId] ?? schedule['className']?.toString() ?? 'Kelas';

      if (scheduleId.isEmpty || classId.isEmpty) continue;

      final pairKey = '${classId}_$subjectName';
      if (processedPairs.contains(pairKey)) continue;
      processedPairs.add(pairKey);

      final cleanClassName = className.trim().toLowerCase();
      final cleanSubjectName = subjectName.trim().toLowerCase();

      // Find scheduled weekdays for this class & subject
      final Set<int> scheduledWeekdays = {};
      for (var s in sortedSchedules) {
        final sClassName = s['className']?.toString().trim().toLowerCase();
        final sSubjectName = s['subjectName']?.toString().trim().toLowerCase();
        if (sClassName == cleanClassName && sSubjectName == cleanSubjectName) {
          final sHari = s['hari']?.toString().trim().toLowerCase();
          if (sHari == 'senin') scheduledWeekdays.add(1);
          if (sHari == 'selasa') scheduledWeekdays.add(2);
          if (sHari == 'rabu') scheduledWeekdays.add(3);
          if (sHari == 'kamis') scheduledWeekdays.add(4);
          if (sHari == 'jumat') scheduledWeekdays.add(5);
          if (sHari == 'sabtu') scheduledWeekdays.add(6);
          if (sHari == 'minggu') scheduledWeekdays.add(7);
        }
      }

      // Cari semua scheduleId yang merupakan mapel ini dan di kelas ini
      final matchingScheduleIds = sortedSchedules
          .where((s) => s['classId'] == classId && s['subjectName'] == subjectName)
          .map((s) => s['scheduleId']?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toSet();

      // Rekap absensi untuk kombinasi ini
      final classStudents = widget.students.where((s) => s['classId'] == classId || (s['className'] == className && className.isNotEmpty && className != 'Kelas')).toList();
      classStudents.sort((a, b) {
        final nameA = a['nama']?.toString() ?? '';
        final nameB = b['nama']?.toString() ?? '';
        return nameA.toLowerCase().compareTo(nameB.toLowerCase());
      });

      final relevantRecords = widget.records
          .where((r) => matchingScheduleIds.contains(r['scheduleId']?.toString() ?? ''))
          .toList();

      final List<_StudentSummary> studentSummaries = [];
      int totalHadir = 0;
      int totalIzin = 0;
      int totalSakit = 0;
      int totalAlpa = 0;

      for (var student in classStudents) {
        final studentId = student['studentId']?.toString() ?? '';
        final studentRecords = relevantRecords.where((r) => r['studentId'] == studentId).toList();

        int hadirCountForChart = 0;
        int izinCountForChart = 0;
        int sakitCountForChart = 0;
        int alpaCountForChart = 0;

        for (var rec in studentRecords) {
          final status = (rec['status'] ?? '').toString().toLowerCase();
          if (status == 'hadir') {
            hadirCountForChart++;
          } else if (status == 'izin') {
            izinCountForChart++;
          } else if (status == 'sakit') {
            sakitCountForChart++;
          } else if (status == 'alpa' || status == 'absen') {
            alpaCountForChart++;
          }
        }

        totalHadir += hadirCountForChart;
        totalIzin += izinCountForChart;
        totalSakit += sakitCountForChart;
        totalAlpa += alpaCountForChart;

        int totalHadirForGrid = 0;
        final Map<int, String?> dailyAttendance = {};

        for (int d = 1; d <= 31; d++) {
          if (d > daysInMonth) {
            dailyAttendance[d] = null;
            continue;
          }

          final date = DateTime(widget.startDate.year, widget.startDate.month, d);
          final dateStr = "${widget.startDate.year}-${widget.startDate.month.toString().padLeft(2, '0')}-${d.toString().padLeft(2, '0')}";
          final isScheduled = scheduledWeekdays.contains(date.weekday);

          if (isScheduled) {
            final recordList = studentRecords.where((r) => r['date']?.toString() == dateStr).toList();
            if (recordList.isNotEmpty) {
              final status = (recordList.first['status'] ?? '').toString().toLowerCase();
              if (status == 'izin') {
                dailyAttendance[d] = 'I';
              } else if (status == 'sakit') {
                dailyAttendance[d] = 'S';
              } else if (status == 'alpa' || status == 'absen') {
                dailyAttendance[d] = 'A';
              } else {
                dailyAttendance[d] = 'H';
                totalHadirForGrid++;
              }
            } else {
              dailyAttendance[d] = '-';
            }
          } else {
            dailyAttendance[d] = null;
          }
        }

        studentSummaries.add(_StudentSummary(
          name: student['nama']?.toString() ?? '-',
          nis: student['nis']?.toString() ?? '-',
          totalHadir: totalHadirForGrid,
          dailyAttendance: dailyAttendance,
        ));
      }

      _groups.add(_AttendanceGroup(
        className: className,
        subjectName: subjectName,
        scheduledWeekdays: scheduledWeekdays,
        daysInMonth: daysInMonth,
        totalHadir: totalHadir,
        totalIzin: totalIzin,
        totalSakit: totalSakit,
        totalAlpa: totalAlpa,
        students: studentSummaries,
      ));
    }
  }

  String _formatMonthYear(DateTime date) {
    const months = ['Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni', 'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'];
    return '${months[date.month - 1]} ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: AuthBackground.isDarkMode,
      builder: (context, isDark, _) {
        final titleColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
        final backButtonBgColor = isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05);
        final backButtonIconColor = isDark ? Colors.white : const Color(0xFF1E1B4B);

        return Scaffold(
          backgroundColor: isDark ? const Color(0xFF0F0C20) : Colors.white,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: Container(
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
              'Preview Rekapan',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: titleColor),
            ),
            centerTitle: true,
          ),
          body: AuthBackground(
            child: _groups.isEmpty
                ? const Center(child: Text('Tidak ada data absensi untuk ditampilkan.'))
                : ListView.builder(
                    padding: const EdgeInsets.all(24),
                    itemCount: _groups.length,
                    itemBuilder: (context, index) {
                      return _buildGroupCard(_groups[index], isDark);
                    },
                  ),
          ),
        );
      },
    );
  }

  Widget _buildGroupCard(_AttendanceGroup group, bool isDark) {
    final cardBg = isDark ? Colors.white.withValues(alpha: 0.04) : Colors.white;
    final cardBorder = isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.08);
    final shadowColor = isDark ? Colors.transparent : Colors.black.withValues(alpha: 0.04);
    final textColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
    final subTextColor = isDark ? Colors.white.withValues(alpha: 0.6) : const Color(0xFF1E1B4B).withValues(alpha: 0.6);

    return Container(
      margin: const EdgeInsets.only(bottom: 32),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cardBorder),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: 12,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Group
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.02) : const Color(0xFFF8FAFC),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              border: Border(bottom: BorderSide(color: cardBorder)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.class_rounded, color: Color(0xFF8B5CF6)),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Kelas ${group.className}',
                        style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        group.subjectName,
                        style: TextStyle(color: subTextColor, fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Periode: ${_formatMonthYear(widget.startDate)}',
                        style: TextStyle(color: subTextColor, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),



          // Table Section
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Detail Kehadiran Harian',
                  style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 12),
                _buildDataTable(group, isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }



  Widget _buildDataTable(_AttendanceGroup group, bool isDark) {
    final borderColor = isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.1);
    final headerColor = isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF1F5F9);
    final textColor = isDark ? Colors.white : const Color(0xFF1E1B4B);

    final List<DataColumn> columns = [
      DataColumn(label: Text('Nama Siswa', style: TextStyle(fontWeight: FontWeight.bold, color: textColor))),
    ];

    for (int d = 1; d <= 31; d++) {
      Color bgCol = Colors.transparent;
      Color txtCol = textColor;
      
      if (d <= group.daysInMonth) {
        final date = DateTime(widget.startDate.year, widget.startDate.month, d);
        if (group.scheduledWeekdays.contains(date.weekday)) {
          bgCol = const Color(0xFF3B82F6); // Biru untuk yang ada jadwal
          txtCol = Colors.white;
        } else {
          bgCol = isDark ? Colors.white24 : const Color(0xFFE2E8F0); // Abu untuk tidak ada jadwal
        }
      }

      columns.add(DataColumn(
        label: Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: bgCol,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text('$d', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: txtCol)),
        ),
      ));
    }

    columns.add(DataColumn(label: Text('Total Hadir', style: TextStyle(fontWeight: FontWeight.bold, color: textColor))));

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Scrollbar(
          thumbVisibility: true,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(headerColor),
              dataRowColor: WidgetStateProperty.all(Colors.transparent),
              dividerThickness: 1,
              columnSpacing: 16,
              horizontalMargin: 16,
              columns: columns,
              rows: List<DataRow>.generate(
                group.students.length,
                (index) {
                  final s = group.students[index];
                  final List<DataCell> cells = [
                    DataCell(Text(s.name, style: TextStyle(color: textColor, fontWeight: FontWeight.w600))),
                  ];

                  for (int d = 1; d <= 31; d++) {
                    final status = s.dailyAttendance[d];
                    Widget content;
                    Color cellBg = Colors.transparent;

                    if (status == 'H') {
                      content = Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: Color(0xFF10B981),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.check_rounded, color: Colors.white, size: 14),
                      );
                    } else if (status == 'I') {
                      content = const Text('I', style: TextStyle(color: Color(0xFF3B82F6), fontWeight: FontWeight.bold));
                    } else if (status == 'S') {
                      content = const Text('S', style: TextStyle(color: Color(0xFFF59E0B), fontWeight: FontWeight.bold));
                    } else if (status == 'A') {
                      content = const Text('A', style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.bold));
                    } else if (status == '-') {
                      content = const Text('-', style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.bold));
                    } else {
                      cellBg = isDark ? Colors.white.withValues(alpha: 0.03) : const Color(0xFFF1F5F9);
                      content = const SizedBox.shrink();
                    }

                    cells.add(DataCell(
                      Container(
                        width: double.infinity,
                        height: double.infinity,
                        color: cellBg,
                        alignment: Alignment.center,
                        child: content,
                      )
                    ));
                  }

                  cells.add(DataCell(
                    Container(
                      alignment: Alignment.center,
                      child: Text('${s.totalHadir}', style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
                    ),
                  ));

                  return DataRow(cells: cells);
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AttendanceGroup {
  final String className;
  final String subjectName;
  final Set<int> scheduledWeekdays;
  final int daysInMonth;
  final int totalHadir;
  final int totalIzin;
  final int totalSakit;
  final int totalAlpa;
  final List<_StudentSummary> students;

  _AttendanceGroup({
    required this.className,
    required this.subjectName,
    required this.scheduledWeekdays,
    required this.daysInMonth,
    required this.totalHadir,
    required this.totalIzin,
    required this.totalSakit,
    required this.totalAlpa,
    required this.students,
  });
}

class _StudentSummary {
  final String name;
  final String nis;
  final int totalHadir;
  final Map<int, String?> dailyAttendance;

  _StudentSummary({
    required this.name,
    required this.nis,
    required this.totalHadir,
    required this.dailyAttendance,
  });
}
