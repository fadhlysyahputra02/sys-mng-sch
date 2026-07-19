import '../../exams/models/exam_event_model.dart';

class SubjectAttendanceRecap {
  final String subjectName;
  final String className;
  final Set<int> scheduledWeekdays;
  final int daysInMonth;
  final Map<int, String?> dailyAttendance;
  final int totalHadir;
  final int totalIzin;
  final int totalSakit;
  final int totalAlpa;

  const SubjectAttendanceRecap({
    required this.subjectName,
    required this.className,
    required this.scheduledWeekdays,
    required this.daysInMonth,
    required this.dailyAttendance,
    required this.totalHadir,
    required this.totalIzin,
    required this.totalSakit,
    required this.totalAlpa,
  });
}

class StudentAttendanceRecapHelper {
  static int _weekdayFromHari(String? hari) {
    switch (hari?.trim().toLowerCase()) {
      case 'senin':
        return 1;
      case 'selasa':
        return 2;
      case 'rabu':
        return 3;
      case 'kamis':
        return 4;
      case 'jumat':
        return 5;
      case 'sabtu':
        return 6;
      case 'minggu':
        return 7;
      default:
        return 0;
    }
  }

  static String _dateStr(int year, int month, int day) {
    return '$year-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
  }

  static List<SubjectAttendanceRecap> buildRecaps({
    required String className,
    required int year,
    required int month,
    required List<Map<String, dynamic>> schedules,
    required List<Map<String, dynamic>> records,
    List<ExamEvent> examEvents = const [],
  }) {
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final cleanClassName = className.trim().toLowerCase();

    final sortedSchedules = schedules
        .where((s) {
          final jenis = (s['jenisJadwal'] ?? '').toString();
          if (jenis == 'istirahat') return false;
          final sClass = (s['className'] ?? '').toString().trim().toLowerCase();
          return sClass == cleanClassName;
        })
        .toList()
      ..sort((a, b) {
        final subjA = (a['subjectName'] ?? '').toString();
        final subjB = (b['subjectName'] ?? '').toString();
        return subjA.compareTo(subjB);
      });

    final Set<String> processedSubjects = {};
    final List<SubjectAttendanceRecap> recaps = [];

    for (final schedule in sortedSchedules) {
      final subjectName = (schedule['subjectName'] ?? 'Pelajaran').toString();
      final pairKey = subjectName.trim().toLowerCase();
      if (processedSubjects.contains(pairKey)) continue;
      processedSubjects.add(pairKey);

      final matchingScheduleIds = sortedSchedules
          .where((s) =>
              (s['subjectName'] ?? '').toString().trim().toLowerCase() ==
              pairKey)
          .map((s) => (s['scheduleId'] ?? '').toString())
          .where((id) => id.isNotEmpty)
          .toSet();

      final scheduledWeekdays = <int>{};
      for (final s in sortedSchedules) {
        if ((s['subjectName'] ?? '').toString().trim().toLowerCase() ==
            pairKey) {
          final wd = _weekdayFromHari(s['hari']?.toString());
          if (wd > 0) scheduledWeekdays.add(wd);
        }
      }

      final subjectRecords = records
          .where((r) =>
              matchingScheduleIds.contains((r['scheduleId'] ?? '').toString()))
          .toList();

      int totalHadir = 0;
      int totalIzin = 0;
      int totalSakit = 0;
      int totalAlpa = 0;
      final dailyAttendance = <int, String?>{};

      for (int d = 1; d <= 31; d++) {
        if (d > daysInMonth) {
          dailyAttendance[d] = null;
          continue;
        }

        final date = DateTime(year, month, d);
        final dateStr = _dateStr(year, month, d);
        final isScheduled = scheduledWeekdays.contains(date.weekday);

        if (!isScheduled) {
          dailyAttendance[d] = null;
          continue;
        }

        final dayRecords =
            subjectRecords.where((r) => (r['date'] ?? '').toString() == dateStr);

        // Check if the current date falls within any exam event
        String? examTypeOnThisDay;
        for (final exam in examEvents) {
          // Normalize to local midnight to prevent timezone shift issues
          final localStart = exam.startDate.toLocal();
          final localEnd = exam.endDate.toLocal();
          final eStart = DateTime(localStart.year, localStart.month, localStart.day);
          final eEnd = DateTime(localEnd.year, localEnd.month, localEnd.day);
          // date is already local midnight (DateTime(year, month, d))
          if (!date.isBefore(eStart) && !date.isAfter(eEnd)) {
            examTypeOnThisDay = exam.examType.isNotEmpty ? exam.examType : 'Ujian';
            break;
          }
        }

        if (dayRecords.isEmpty) {
          if (examTypeOnThisDay != null) {
            dailyAttendance[d] = examTypeOnThisDay;
          } else {
            dailyAttendance[d] = '-';
            totalAlpa++;
          }
          continue;
        }

        final status = (dayRecords.first['status'] ?? 'Hadir')
            .toString()
            .toLowerCase();

        if (status == 'izin') {
          dailyAttendance[d] = 'I';
          totalIzin++;
        } else if (status == 'sakit') {
          dailyAttendance[d] = 'S';
          totalSakit++;
        } else if (status == 'alpa' ||
            status == 'absen' ||
            status == 'alpha') {
          if (examTypeOnThisDay != null) {
            dailyAttendance[d] = examTypeOnThisDay;
          } else {
            dailyAttendance[d] = 'A';
            totalAlpa++;
          }
        } else {
          dailyAttendance[d] = 'H';
          totalHadir++;
        }
      }

      recaps.add(
        SubjectAttendanceRecap(
          subjectName: subjectName,
          className: className,
          scheduledWeekdays: scheduledWeekdays,
          daysInMonth: daysInMonth,
          dailyAttendance: dailyAttendance,
          totalHadir: totalHadir,
          totalIzin: totalIzin,
          totalSakit: totalSakit,
          totalAlpa: totalAlpa,
        ),
      );
    }

    return recaps;
  }
}
