import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../schools/pages/schedule/Service/class_schedule_service.dart';
import '../data/student_service.dart';
import '../services/student_attendance_recap_helper.dart';

class MonthlyAttendanceTableSection extends StatefulWidget {
  final String schoolId;
  final String studentId;
  final String className;
  final String studentName;
  final bool isDark;
  final Color textColor;
  final Color subTextColor;
  final Color cardBg;
  final Color cardBorder;
  final bool showTitle;
  final bool embedded;

  const MonthlyAttendanceTableSection({
    super.key,
    required this.schoolId,
    required this.studentId,
    required this.className,
    required this.studentName,
    required this.isDark,
    required this.textColor,
    required this.subTextColor,
    required this.cardBg,
    required this.cardBorder,
    this.showTitle = true,
    this.embedded = false,
  });

  @override
  State<MonthlyAttendanceTableSection> createState() =>
      _MonthlyAttendanceTableSectionState();
}

class _MonthlyAttendanceTableSectionState
    extends State<MonthlyAttendanceTableSection> {
  final _studentService = StudentService();
  final _scheduleService = ClassScheduleService();

  late DateTime _selectedMonth;
  late List<DateTime> _monthOptions;
  String? _resolvedClassName;
  bool _isResolvingClass = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = DateTime(now.year, now.month, 1);
    _monthOptions = List.generate(
      12,
      (i) => DateTime(now.year, now.month - i, 1),
    );
    _resolvedClassName = widget.className;
    _resolveClassForSelectedMonth();
  }

  Future<void> _resolveClassForSelectedMonth() async {
    setState(() => _isResolvingClass = true);
    try {
      String calculatedTahunAjaran;
      String calculatedSemester;
      if (_selectedMonth.month >= 7 && _selectedMonth.month <= 12) {
        calculatedTahunAjaran = '${_selectedMonth.year}/${_selectedMonth.year + 1}';
        calculatedSemester = 'Semester 1';
      } else {
        calculatedTahunAjaran = '${_selectedMonth.year - 1}/${_selectedMonth.year}';
        calculatedSemester = 'Semester 2';
      }

      final cleanYear = calculatedTahunAjaran.replaceAll('/', '_');
      final enrollmentId = '${widget.studentId}_${cleanYear}_$calculatedSemester';
      final doc = await FirebaseFirestore.instance
          .collection('schools')
          .doc(widget.schoolId)
          .collection('class_enrollments')
          .doc(enrollmentId)
          .get();

      if (doc.exists) {
        if (mounted) {
          setState(() {
            _resolvedClassName = doc.data()?['className']?.toString() ?? widget.className;
            _isResolvingClass = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _resolvedClassName = widget.className;
            _isResolvingClass = false;
          });
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _resolvedClassName = widget.className;
          _isResolvingClass = false;
        });
      }
    }
  }

  String _monthName(int month) {
    const months = [
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember',
    ];
    return months[month - 1];
  }

  @override
  Widget build(BuildContext context) {
    final inputFill = widget.isDark
        ? Colors.white.withValues(alpha: 0.05)
        : Colors.black.withValues(alpha: 0.04);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.showTitle) ...[
          Row(
            children: [
              Expanded(
                child: Text(
                  'Rekapitulasi Kehadiran',
                  style: TextStyle(
                    color: widget.textColor,
                    fontWeight: FontWeight.bold,
                    fontSize: widget.embedded ? 15 : 16,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => setState(() {}),
                icon: Icon(Icons.refresh_rounded,
                    color: widget.subTextColor, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: inputFill,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: widget.cardBorder),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<DateTime>(
              value: _selectedMonth,
              isExpanded: true,
              dropdownColor:
                  widget.isDark ? const Color(0xFF0F0C20) : Colors.white,
              icon: Icon(Icons.calendar_month_rounded,
                  color: widget.subTextColor),
              style: TextStyle(
                color: widget.textColor,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
              items: _monthOptions.map((date) {
                return DropdownMenuItem<DateTime>(
                  value: date,
                  child: Text('${_monthName(date.month)} ${date.year}'),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selectedMonth = value);
                  _resolveClassForSelectedMonth();
                }
              },
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '${widget.studentName} • Kelas ${_resolvedClassName ?? widget.className}',
          style: TextStyle(color: widget.subTextColor, fontSize: 12),
        ),
        const SizedBox(height: 16),
        _isResolvingClass
            ? Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Center(
                  child: CircularProgressIndicator(
                    color: widget.isDark
                        ? Colors.white
                        : const Color(0xFF8B5CF6),
                  ),
                ),
              )
            : (_resolvedClassName ?? '').isEmpty
                ? _emptyBox(
                    'Siswa tidak terdaftar di kelas manapun pada periode ${_monthName(_selectedMonth.month)} ${_selectedMonth.year}.',
                  )
                : StreamBuilder(
                    stream: _scheduleService.getSchedulesByClassName(
                      widget.schoolId,
                      _resolvedClassName!,
                    ),
                    builder: (context, scheduleSnap) {
                      return StreamBuilder<List<Map<String, dynamic>>>(
                        stream: _studentService.getStudentAttendanceHistoryStream(
                          schoolId: widget.schoolId,
                          studentId: widget.studentId,
                          year: _selectedMonth.year,
                          month: _selectedMonth.month,
                        ),
                        builder: (context, recordSnap) {
                          if (scheduleSnap.connectionState == ConnectionState.waiting ||
                              recordSnap.connectionState == ConnectionState.waiting) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 32),
                              child: Center(
                                child: CircularProgressIndicator(
                                  color: widget.isDark
                                      ? Colors.white
                                      : const Color(0xFF8B5CF6),
                                ),
                              ),
                            );
                          }

                          final schedules =
                              scheduleSnap.data?.docs.map((e) => e.data()).toList() ??
                                  [];
                          final records = recordSnap.data ?? [];

                          final recaps = StudentAttendanceRecapHelper.buildRecaps(
                            className: _resolvedClassName!,
                            year: _selectedMonth.year,
                            month: _selectedMonth.month,
                            schedules: schedules,
                            records: records,
                          );

                          if (recaps.isEmpty) {
                            return _emptyBox(
                              'Belum ada data absensi ${_monthName(_selectedMonth.month)} ${_selectedMonth.year}.',
                            );
                          }

                          return Column(
                            children: recaps
                                .map(
                                  (recap) => _buildSubjectCard(recap),
                                )
                                .toList(),
                          );
                        },
                      );
                    },
                  ),
      ],
    );
  }

  Widget _emptyBox(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: widget.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: widget.cardBorder),
      ),
      child: Column(
        children: [
          Icon(Icons.event_busy_rounded,
              size: 40, color: widget.subTextColor.withValues(alpha: 0.4)),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: widget.subTextColor, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildSubjectCard(SubjectAttendanceRecap recap) {
    final shadowColor = widget.isDark
        ? Colors.transparent
        : Colors.black.withValues(alpha: 0.04);

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: widget.cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: widget.cardBorder),
        boxShadow: widget.isDark
            ? []
            : [
                BoxShadow(
                  color: shadowColor,
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: widget.isDark
                  ? Colors.white.withValues(alpha: 0.02)
                  : const Color(0xFFF8FAFC),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
              border: Border(bottom: BorderSide(color: widget.cardBorder)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.book_rounded,
                      color: Color(0xFF8B5CF6), size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        recap.subjectName,
                        style: TextStyle(
                          color: widget.textColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        'Kelas ${recap.className}',
                        style: TextStyle(
                            color: widget.subTextColor, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: _buildSummaryChart(recap),
          ),
          Divider(color: widget.cardBorder, height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Detail Kehadiran Harian',
                  style: TextStyle(
                    color: widget.textColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 12),
                _buildDataTable(recap),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryChart(SubjectAttendanceRecap recap) {
    final total =
        recap.totalHadir + recap.totalIzin + recap.totalSakit + recap.totalAlpa;
    if (total == 0) {
      return Text(
        'Belum ada data absensi',
        style: TextStyle(color: widget.subTextColor, fontSize: 12),
      );
    }

    Widget legend(String label, Color color, int count) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            '$label ($count)',
            style: TextStyle(
              fontSize: 11,
              color: widget.textColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      );
    }

    final hadirPct = recap.totalHadir / total;
    final izinPct = recap.totalIzin / total;
    final sakitPct = recap.totalSakit / total;
    final alpaPct = recap.totalAlpa / total;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          height: 20,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(10)),
          child: Row(
            children: [
              if (hadirPct > 0)
                Expanded(
                  flex: (hadirPct * 1000).toInt(),
                  child: Container(color: const Color(0xFF10B981)),
                ),
              if (izinPct > 0)
                Expanded(
                  flex: (izinPct * 1000).toInt(),
                  child: Container(color: const Color(0xFF3B82F6)),
                ),
              if (sakitPct > 0)
                Expanded(
                  flex: (sakitPct * 1000).toInt(),
                  child: Container(color: const Color(0xFFF59E0B)),
                ),
              if (alpaPct > 0)
                Expanded(
                  flex: (alpaPct * 1000).toInt(),
                  child: Container(color: const Color(0xFFEF4444)),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            legend('Hadir', const Color(0xFF10B981), recap.totalHadir),
            legend('Izin', const Color(0xFF3B82F6), recap.totalIzin),
            legend('Sakit', const Color(0xFFF59E0B), recap.totalSakit),
            legend('Alpa', const Color(0xFFEF4444), recap.totalAlpa),
          ],
        ),
      ],
    );
  }

  Widget _buildDataTable(SubjectAttendanceRecap recap) {
    final borderColor = widget.isDark
        ? Colors.white.withValues(alpha: 0.1)
        : Colors.black.withValues(alpha: 0.1);
    final headerColor = widget.isDark
        ? Colors.white.withValues(alpha: 0.05)
        : const Color(0xFFF1F5F9);

    final columns = <DataColumn>[
      DataColumn(
        label: Text(
          'Nama',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: widget.textColor,
            fontSize: 12,
          ),
        ),
      ),
    ];

    for (int d = 1; d <= 31; d++) {
      Color bgCol = Colors.transparent;
      Color txtCol = widget.textColor;

      if (d <= recap.daysInMonth) {
        final date =
            DateTime(_selectedMonth.year, _selectedMonth.month, d);
        if (recap.scheduledWeekdays.contains(date.weekday)) {
          bgCol = const Color(0xFF3B82F6);
          txtCol = Colors.white;
        } else {
          bgCol = widget.isDark
              ? Colors.white24
              : const Color(0xFFE2E8F0);
        }
      }

      columns.add(
        DataColumn(
          label: Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: bgCol,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '$d',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 10,
                color: txtCol,
              ),
            ),
          ),
        ),
      );
    }

    columns.add(
      DataColumn(
        label: Text(
          'Total',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: widget.textColor,
            fontSize: 12,
          ),
        ),
      ),
    );

    final cells = <DataCell>[
      DataCell(
        Text(
          widget.studentName,
          style: TextStyle(
            color: widget.textColor,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
      ),
    ];

    for (int d = 1; d <= 31; d++) {
      final status = recap.dailyAttendance[d];
      Widget content;
      Color cellBg = Colors.transparent;

      if (status == 'H') {
        content = Container(
          padding: const EdgeInsets.all(2),
          decoration: const BoxDecoration(
            color: Color(0xFF10B981),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check_rounded, color: Colors.white, size: 12),
        );
      } else if (status == 'I') {
        content = const Text('I',
            style: TextStyle(
                color: Color(0xFF3B82F6), fontWeight: FontWeight.bold));
      } else if (status == 'S') {
        content = const Text('S',
            style: TextStyle(
                color: Color(0xFFF59E0B), fontWeight: FontWeight.bold));
      } else if (status == 'A') {
        content = const Text('A',
            style: TextStyle(
                color: Color(0xFFEF4444), fontWeight: FontWeight.bold));
      } else if (status == '-') {
        content = const Text('-',
            style: TextStyle(
                color: Color(0xFFEF4444), fontWeight: FontWeight.bold));
      } else {
        cellBg = widget.isDark
            ? Colors.white.withValues(alpha: 0.03)
            : const Color(0xFFF1F5F9);
        content = const SizedBox.shrink();
      }

      cells.add(
        DataCell(
          Container(
            width: double.infinity,
            height: double.infinity,
            color: cellBg,
            alignment: Alignment.center,
            child: content,
          ),
        ),
      );
    }

    cells.add(
      DataCell(
        Text(
          '${recap.totalHadir}',
          style: TextStyle(
            color: widget.textColor,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(headerColor),
            dataRowColor: WidgetStateProperty.all(Colors.transparent),
            dividerThickness: 1,
            columnSpacing: 10,
            horizontalMargin: 12,
            columns: columns,
            rows: [DataRow(cells: cells)],
          ),
        ),
      ),
    );
  }
}
