import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:excel/excel.dart' hide Border;
import 'dart:io';
import 'package:path_provider/path_provider.dart';

import '../../../core/services/session_service.dart';
import '../../authentication/widgets/auth_background.dart';
import '../../schools/pages/classes/models/class_model.dart';

class MonthlyRecapPage extends StatefulWidget {
  const MonthlyRecapPage({super.key});

  @override
  State<MonthlyRecapPage> createState() => _MonthlyRecapPageState();
}

class _MonthlyRecapPageState extends State<MonthlyRecapPage> {
  // Dropdown list data
  List<ClassModel> _classes = [];
  String? _selectedClassId;
  String? _selectedClassName;

  // Selected date parameters
  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;

  // Process states
  bool _isLoadingClasses = true;
  bool _isLoadingData = false;

  // Data maps
  List<Map<String, dynamic>> _students = [];
  // Map of studentId -> { dateStr: status }
  Map<String, Map<String, String>> _attendanceMap = {};

  final List<String> _monthNames = [
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
    'Desember'
  ];

  final List<int> _years = List<int>.generate(7, (i) => DateTime.now().year - 3 + i);

  @override
  void initState() {
    super.initState();
    _fetchClasses();
  }

  Future<void> _fetchClasses() async {
    setState(() => _isLoadingClasses = true);
    try {
      final user = SessionService.currentUser!;
      final query = await FirebaseFirestore.instance
          .collection('schools')
          .doc(user.schoolId)
          .collection('classes')
          .where('aktif', isEqualTo: true)
          .get();

      final list = query.docs.map((doc) => ClassModel.fromFirestore(doc)).toList();
      list.sort((a, b) => a.namaKelas.compareTo(b.namaKelas));

      setState(() {
        _classes = list;
        if (_classes.isNotEmpty) {
          _selectedClassId = _classes.first.id;
          _selectedClassName = _classes.first.namaKelas;
        }
        _isLoadingClasses = false;
      });

      if (_selectedClassId != null) {
        _fetchMonthlyData();
      }
    } catch (e) {
      setState(() => _isLoadingClasses = false);
      Get.snackbar('Error', 'Gagal memuat kelas: $e',
          backgroundColor: Colors.red, colorText: Colors.white);
    }
  }

  Future<void> _fetchMonthlyData() async {
    if (_selectedClassId == null) return;

    setState(() => _isLoadingData = true);
    try {
      final user = SessionService.currentUser!;
      final schoolId = user.schoolId;

      // 1. Fetch all students in the selected class
      final studentsQuery = await FirebaseFirestore.instance
          .collection('schools')
          .doc(schoolId)
          .collection('students')
          .where('classId', isEqualTo: _selectedClassId)
          .get();

      final studentsList = studentsQuery.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'nama': data['nama'] ?? '-',
          'className': data['className'] ?? '-',
        };
      }).toList();

      studentsList.sort((a, b) => a['nama'].toString().compareTo(b['nama'].toString()));

      // 2. Fetch monthly attendance data safely
      // Start of month: YYYY-MM-01, End of month: YYYY-MM-31
      final monthPrefix = '$_selectedYear-${_selectedMonth.toString().padLeft(2, '0')}';
      final startOfDate = '$monthPrefix-01';
      final endOfDate = '$monthPrefix-31';

      final attendanceQuery = await FirebaseFirestore.instance
          .collection('schools')
          .doc(schoolId)
          .collection('daily_attendance')
          .where('date', isGreaterThanOrEqualTo: startOfDate)
          .where('date', isLessThanOrEqualTo: endOfDate)
          .get();

      // Filter by studentId in memory using the class student list
      final studentIdsInClass = studentsList.map((s) => s['id'] as String).toSet();
      final filteredDocs = attendanceQuery.docs
          .map((doc) => doc.data())
          .where((data) {
            final studentId = data['studentId'] as String?;
            return studentId != null && studentIdsInClass.contains(studentId);
          })
          .toList();

      // Build attendanceMap: studentId -> { dateStr -> status }
      final Map<String, Map<String, String>> tempMap = {};
      for (final doc in filteredDocs) {
        final studentId = doc['studentId'] as String?;
        final date = doc['date'] as String?;
        final status = doc['status'] as String?;

        if (studentId != null && date != null && status != null) {
          tempMap.putIfAbsent(studentId, () => {});
          tempMap[studentId]![date] = status.toLowerCase();
        }
      }

      setState(() {
        _students = studentsList;
        _attendanceMap = tempMap;
        _isLoadingData = false;
      });
    } catch (e) {
      setState(() => _isLoadingData = false);
      Get.snackbar('Error', 'Gagal memuat rekap: $e',
          backgroundColor: Colors.red, colorText: Colors.white);
    }
  }

  // Helper to count statuses for a student
  Map<String, int> _calculateCounts(String studentId) {
    int hadir = 0;
    int terlambat = 0;
    int alpha = 0;
    int izin = 0;
    int sakit = 0;

    final records = _attendanceMap[studentId] ?? {};
    for (final status in records.values) {
      switch (status) {
        case 'hadir':
          hadir++;
          break;
        case 'terlambat':
          terlambat++;
          break;
        case 'alpha':
          alpha++;
          break;
        case 'izin':
          izin++;
          break;
        case 'sakit':
          sakit++;
          break;
      }
    }

    return {
      'hadir': hadir,
      'terlambat': terlambat,
      'alpha': alpha,
      'izin': izin,
      'sakit': sakit,
    };
  }

  int _getDaysInMonth() {
    return DateTime(_selectedYear, _selectedMonth + 1, 0).day;
  }

  Future<void> _exportPdf() async {
    final pdf = pw.Document();
    final monthName = _monthNames[_selectedMonth - 1];

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        build: (pw.Context context) {
          return [
            pw.Text(
              'Laporan Rekap Bulanan Kehadiran',
              style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              'Kelas: ${_selectedClassName ?? '-'}  |  Bulan: $monthName $_selectedYear',
              style: const pw.TextStyle(fontSize: 12),
            ),
            pw.SizedBox(height: 16),
            pw.TableHelper.fromTextArray(
              headers: [
                'No',
                'Nama Siswa',
                'Hadir (H)',
                'Terlambat (T)',
                'Izin (I)',
                'Sakit (S)',
                'Alpha (A)',
                'Total Tidak Hadir'
              ],
              data: List<List<String>>.generate(_students.length, (index) {
                final student = _students[index];
                final studentId = student['id'] ?? '';
                final counts = _calculateCounts(studentId);
                final totalAbsen = counts['alpha']! + counts['izin']! + counts['sakit']!;

                return [
                  (index + 1).toString(),
                  student['nama'] ?? '-',
                  counts['hadir'].toString(),
                  counts['terlambat'].toString(),
                  counts['izin'].toString(),
                  counts['sakit'].toString(),
                  counts['alpha'].toString(),
                  totalAbsen.toString(),
                ];
              }),
            ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Rekap_Bulanan_${_selectedClassName}_${_selectedYear}_${_selectedMonth.toString().padLeft(2, '0')}.pdf',
    );
  }

  Future<void> _exportExcel() async {
    try {
      final excelFile = Excel.createExcel();
      final sheetObject = excelFile['Sheet1'];
      final daysInMonth = _getDaysInMonth();
      final monthName = _monthNames[_selectedMonth - 1];

      // Sheet title
      sheetObject.appendRow([
        TextCellValue('Laporan Kehadiran Bulanan Kelas ${_selectedClassName ?? "-"}'),
      ]);
      sheetObject.appendRow([
        TextCellValue('Periode: $monthName $_selectedYear'),
      ]);
      sheetObject.appendRow([]); // Empty spacer row

      // Headers (Columns: No, Nama Siswa, 1 - 31, H, T, I, S, A)
      List<CellValue> headers = [
        TextCellValue('No'),
        TextCellValue('Nama Siswa'),
      ];
      for (int d = 1; d <= daysInMonth; d++) {
        headers.add(TextCellValue(d.toString()));
      }
      headers.addAll([
        TextCellValue('H (Hadir)'),
        TextCellValue('T (Terlambat)'),
        TextCellValue('I (Izin)'),
        TextCellValue('S (Sakit)'),
        TextCellValue('A (Alpha)'),
      ]);
      sheetObject.appendRow(headers);

      // Student rows
      for (int i = 0; i < _students.length; i++) {
        final student = _students[i];
        final studentId = student['id'] ?? '';
        final counts = _calculateCounts(studentId);
        final studentRecords = _attendanceMap[studentId] ?? {};

        List<CellValue> row = [
          IntCellValue(i + 1),
          TextCellValue(student['nama'] ?? '-'),
        ];

        // Populate days
        for (int d = 1; d <= daysInMonth; d++) {
          final dateKey = '$_selectedYear-${_selectedMonth.toString().padLeft(2, '0')}-${d.toString().padLeft(2, '0')}';
          final status = studentRecords[dateKey];

          String code = '-';
          if (status != null) {
            switch (status) {
              case 'hadir':
                code = 'H';
                break;
              case 'terlambat':
                code = 'T';
                break;
              case 'izin':
                code = 'I';
                break;
              case 'sakit':
                code = 'S';
                break;
              case 'alpha':
                code = 'A';
                break;
            }
          }
          row.add(TextCellValue(code));
        }

        // Totals
        row.addAll([
          IntCellValue(counts['hadir'] ?? 0),
          IntCellValue(counts['terlambat'] ?? 0),
          IntCellValue(counts['izin'] ?? 0),
          IntCellValue(counts['sakit'] ?? 0),
          IntCellValue(counts['alpha'] ?? 0),
        ]);

        sheetObject.appendRow(row);
      }

      final bytes = excelFile.save();
      if (bytes == null) throw Exception('Gagal generate file Excel');

      final dir = await getApplicationDocumentsDirectory();
      final fileName = 'Rekap_Bulanan_${_selectedClassName}_${_selectedYear}_${_selectedMonth.toString().padLeft(2, '0')}.xlsx';
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(bytes);

      Get.snackbar(
        'Berhasil',
        'File Excel disimpan di: ${file.path}',
        backgroundColor: const Color(0xFF10B981),
        colorText: Colors.white,
        duration: const Duration(seconds: 5),
      );
    } catch (e) {
      Get.snackbar('Error', 'Gagal export excel: $e',
          backgroundColor: Colors.red, colorText: Colors.white);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: AuthBackground.isDarkMode,
      builder: (context, isDark, _) {
        final textColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
        final subTextColor = isDark
            ? Colors.white.withValues(alpha: 0.5)
            : const Color(0xFF1E1B4B).withValues(alpha: 0.5);
        final cardBg = isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white;
        final cardBorder = isDark
            ? Colors.white.withValues(alpha: 0.1)
            : Colors.black.withValues(alpha: 0.08);

        return Scaffold(
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            iconTheme: IconThemeData(color: textColor),
            title: Text(
              'Rekap Bulanan',
              style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.picture_as_pdf_rounded),
                onPressed: _students.isEmpty || _isLoadingData ? null : _exportPdf,
                tooltip: 'Export PDF',
              ),
              IconButton(
                icon: const Icon(Icons.table_view_rounded),
                onPressed: _students.isEmpty || _isLoadingData ? null : _exportExcel,
                tooltip: 'Export Excel',
              ),
            ],
          ),
          body: AuthBackground(
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
                child: Column(
                  children: [
                    // Selectors Container
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: cardBorder),
                      ),
                      child: Column(
                        children: [
                          // Class selector
                          _isLoadingClasses
                              ? const SizedBox(
                                  height: 48,
                                  child: Center(
                                      child: CircularProgressIndicator(strokeWidth: 2)),
                                )
                              : _classes.isEmpty
                                  ? Text('Belum ada kelas aktif.',
                                      style: TextStyle(color: textColor))
                                  : DropdownButtonFormField<String>(
                                      initialValue: _selectedClassId,
                                      dropdownColor:
                                          isDark ? const Color(0xFF1E1B4B) : Colors.white,
                                      style: TextStyle(color: textColor),
                                      decoration: InputDecoration(
                                        labelText: 'Pilih Kelas',
                                        labelStyle: TextStyle(color: subTextColor),
                                        contentPadding:
                                            const EdgeInsets.symmetric(horizontal: 16),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                          borderSide: BorderSide(color: cardBorder),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                          borderSide: BorderSide(color: cardBorder),
                                        ),
                                      ),
                                      items: _classes.map((cls) {
                                        return DropdownMenuItem(
                                          value: cls.id,
                                          child: Text(cls.namaKelas),
                                        );
                                      }).toList(),
                                      onChanged: (val) {
                                        if (val != null) {
                                          final found =
                                              _classes.firstWhereOrNull((c) => c.id == val);
                                          setState(() {
                                            _selectedClassId = val;
                                            _selectedClassName = found?.namaKelas;
                                          });
                                          _fetchMonthlyData();
                                        }
                                      },
                                    ),
                          const SizedBox(height: 16),

                          // Month and Year selector
                          Row(
                            children: [
                              // Month Dropdown
                              Expanded(
                                flex: 3,
                                child: DropdownButtonFormField<int>(
                                  initialValue: _selectedMonth,
                                  dropdownColor:
                                      isDark ? const Color(0xFF1E1B4B) : Colors.white,
                                  style: TextStyle(color: textColor),
                                  decoration: InputDecoration(
                                    labelText: 'Bulan',
                                    labelStyle: TextStyle(color: subTextColor),
                                    contentPadding:
                                        const EdgeInsets.symmetric(horizontal: 12),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(color: cardBorder),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(color: cardBorder),
                                    ),
                                  ),
                                  items: List.generate(12, (index) {
                                    return DropdownMenuItem(
                                      value: index + 1,
                                      child: Text(_monthNames[index]),
                                    );
                                  }),
                                  onChanged: (val) {
                                    if (val != null) {
                                      setState(() => _selectedMonth = val);
                                      _fetchMonthlyData();
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),

                              // Year Dropdown
                              Expanded(
                                flex: 2,
                                child: DropdownButtonFormField<int>(
                                  initialValue: _selectedYear,
                                  dropdownColor:
                                      isDark ? const Color(0xFF1E1B4B) : Colors.white,
                                  style: TextStyle(color: textColor),
                                  decoration: InputDecoration(
                                    labelText: 'Tahun',
                                    labelStyle: TextStyle(color: subTextColor),
                                    contentPadding:
                                        const EdgeInsets.symmetric(horizontal: 12),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(color: cardBorder),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(color: cardBorder),
                                    ),
                                  ),
                                  items: _years.map((yr) {
                                    return DropdownMenuItem(
                                      value: yr,
                                      child: Text(yr.toString()),
                                    );
                                  }).toList(),
                                  onChanged: (val) {
                                    if (val != null) {
                                      setState(() => _selectedYear = val);
                                      _fetchMonthlyData();
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Results table/list
                    Expanded(
                      child: _isLoadingData
                          ? const Center(child: CircularProgressIndicator())
                          : _students.isEmpty
                              ? Center(
                                  child: Text(
                                    'Tidak ada data siswa atau absensi.',
                                    style: TextStyle(color: subTextColor),
                                  ),
                                )
                              : ListView.separated(
                                  itemCount: _students.length,
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(height: 12),
                                  itemBuilder: (context, index) {
                                    final student = _students[index];
                                    final studentId = student['id'] ?? '';
                                    final counts = _calculateCounts(studentId);

                                    return Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 14),
                                      decoration: BoxDecoration(
                                        color: cardBg,
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(color: cardBorder),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          // Student Name
                                          Text(
                                            student['nama'] ?? '-',
                                            style: TextStyle(
                                              color: textColor,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                          const SizedBox(height: 8),

                                          // Green, Yellow, Red badge info
                                          SingleChildScrollView(
                                            scrollDirection: Axis.horizontal,
                                            child: Row(
                                              children: [
                                                // Green (Hadir)
                                                _buildInfoPill(
                                                  label: 'Hadir',
                                                  count: counts['hadir']!,
                                                  color: const Color(0xFF10B981),
                                                ),
                                                const SizedBox(width: 8),

                                                // Yellow (Terlambat)
                                                _buildInfoPill(
                                                  label: 'Terlambat',
                                                  count: counts['terlambat']!,
                                                  color: const Color(0xFFF59E0B),
                                                ),
                                                const SizedBox(width: 8),

                                                // Blue (Izin)
                                                _buildInfoPill(
                                                  label: 'Izin',
                                                  count: counts['izin']!,
                                                  color: const Color(0xFF3B82F6),
                                                ),
                                                const SizedBox(width: 8),

                                                // Purple (Sakit)
                                                _buildInfoPill(
                                                  label: 'Sakit',
                                                  count: counts['sakit']!,
                                                  color: const Color(0xFF8B5CF6),
                                                ),
                                                const SizedBox(width: 8),

                                                // Red (Alpha)
                                                _buildInfoPill(
                                                  label: 'Alpha',
                                                  count: counts['alpha']!,
                                                  color: const Color(0xFFEF4444),
                                                ),
                                              ],
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
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoPill({
    required String label,
    required int count,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '$label: $count',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
