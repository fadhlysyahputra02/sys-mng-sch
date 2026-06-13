import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class AttendancePdfHelper {
  /// Mengonversi format tanggal YYYY-MM-DD ke tampilan pendek, misal "06 Jun"
  static String _shortDate(String dateStr) {
    try {
      final parts = dateStr.split('-');
      if (parts.length == 3) {
        final day = parts[2];
        final monthNum = int.parse(parts[1]);
        const months = [
          'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
          'Jul', 'Agt', 'Sep', 'Okt', 'Nov', 'Des'
        ];
        return '$day ${months[monthNum - 1]}';
      }
    } catch (_) {}
    return dateStr;
  }

  /// Mengonversi DateTime ke format panjang bahasa Indonesia, misal "13 Juni 2026"
  static String _formatLongDate(DateTime date) {
    final months = [
      'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  /// Membuat dokumen PDF dan membuka Print Preview untuk kelas tunggal
  static Future<void> generateAndShowPdf({
    required String subjectName,
    required String className,
    required String teacherName,
    required DateTime startDate,
    required DateTime endDate,
    required List<Map<String, dynamic>> records,
  }) async {
    final pdf = pw.Document();

    final Set<String> uniqueDatesSet = {};
    for (var r in records) {
      final date = r['date'] as String?;
      if (date != null) {
        uniqueDatesSet.add(date);
      }
    }
    final List<String> sortedDates = uniqueDatesSet.toList()
      ..sort((a, b) => a.compareTo(b));

    final Set<String> uniqueStudentsSet = {};
    for (var r in records) {
      final name = r['studentName'] as String?;
      if (name != null) {
        uniqueStudentsSet.add(name);
      }
    }
    final List<String> sortedStudents = uniqueStudentsSet.toList()..sort();

    final bool useLandscape = sortedDates.length > 6;
    final pageFormat = useLandscape
        ? PdfPageFormat.a4.copyWith(marginLeft: 20, marginRight: 20, marginTop: 20, marginBottom: 20)
        : PdfPageFormat.a4.copyWith(marginLeft: 30, marginRight: 30, marginTop: 30, marginBottom: 30);

    // Build manual table columns
    final Map<int, pw.TableColumnWidth> columnWidths = {
      0: const pw.FixedColumnWidth(25), // No
      1: const pw.FlexColumnWidth(3),   // Nama Siswa
    };
    for (int dIdx = 0; dIdx < sortedDates.length; dIdx++) {
      columnWidths[dIdx + 2] = const pw.FlexColumnWidth(1);
    }
    columnWidths[sortedDates.length + 2] = const pw.FixedColumnWidth(60);

    // Header cells
    final List<pw.Widget> headerCells = [
      pw.Container(
        padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        alignment: pw.Alignment.center,
        child: pw.Text('No', style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 8)),
      ),
      pw.Container(
        padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 8),
        alignment: pw.Alignment.centerLeft,
        child: pw.Text('Nama Siswa', style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 8)),
      ),
    ];
    for (var d in sortedDates) {
      headerCells.add(
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          alignment: pw.Alignment.center,
          child: pw.Text(_shortDate(d), style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 8)),
        ),
      );
    }
    headerCells.add(
      pw.Container(
        padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        alignment: pw.Alignment.center,
        child: pw.Text('Total Hadir', style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 8)),
      ),
    );

    // Rows
    final List<pw.TableRow> tableRows = [
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFF4F46E5)),
        children: headerCells,
      ),
    ];

    for (int i = 0; i < sortedStudents.length; i++) {
      final studentName = sortedStudents[i];
      final List<pw.Widget> rowCells = [];

      rowCells.add(
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          alignment: pw.Alignment.center,
          child: pw.Text((i + 1).toString(), style: const pw.TextStyle(fontSize: 8)),
        ),
      );

      rowCells.add(
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 8),
          alignment: pw.Alignment.centerLeft,
          child: pw.Text(studentName, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColor.fromInt(0xFF1E293B))),
        ),
      );

      int presentCount = 0;
      for (var date in sortedDates) {
        final hasCheckedIn = records.any((r) =>
            r['studentName'] == studentName && r['date'] == date);

        if (hasCheckedIn) {
          rowCells.add(
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 4),
              alignment: pw.Alignment.center,
              child: pw.Text('V', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColor.fromInt(0xFF10B981))),
            ),
          );
          presentCount++;
        } else {
          rowCells.add(
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 4),
              alignment: pw.Alignment.center,
              child: pw.Text('-', style: pw.TextStyle(fontSize: 8, color: PdfColor.fromInt(0xFF94A3B8))),
            ),
          );
        }
      }

      rowCells.add(
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          alignment: pw.Alignment.center,
          child: pw.Text('$presentCount/${sortedDates.length}', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColor.fromInt(0xFF1E293B))),
        ),
      );

      tableRows.add(
        pw.TableRow(
          decoration: pw.BoxDecoration(
            color: i % 2 == 0 ? PdfColors.white : PdfColor.fromInt(0xFFF8FAFC),
          ),
          children: rowCells,
        ),
      );
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: pageFormat,
        orientation: useLandscape ? pw.PageOrientation.landscape : pw.PageOrientation.portrait,
        build: (context) {
          return [
            // Kop Laporan
            pw.Container(
              decoration: const pw.BoxDecoration(
                border: pw.Border(bottom: pw.BorderSide(color: PdfColor.fromInt(0xFF4F46E5), width: 2)),
              ),
              padding: const pw.EdgeInsets.only(bottom: 8),
              margin: const pw.EdgeInsets.only(bottom: 16),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'LAPORAN REKAPITULASI ABSENSI SISWA',
                        style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColor.fromInt(0xFF1E1B4B)),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        'Periode: ${_formatLongDate(startDate)} s/d ${_formatLongDate(endDate)}',
                        style: pw.TextStyle(fontSize: 9, color: PdfColor.fromInt(0xFF4B5563)),
                      ),
                    ],
                  ),
                  pw.Text(
                    'SISTEM MANAJEMEN SEKOLAH',
                    style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColor.fromInt(0xFF4F46E5)),
                  ),
                ],
              ),
            ),

            // Metadata card
            pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 16),
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromInt(0xFFF8FAFC),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                border: pw.Border.all(color: PdfColor.fromInt(0xFFE2E8F0), width: 0.5),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.RichText(
                        text: pw.TextSpan(
                          children: [
                            pw.TextSpan(text: 'Mata Pelajaran: ', style: pw.TextStyle(fontSize: 9, color: PdfColor.fromInt(0xFF64748B))),
                            pw.TextSpan(text: subjectName, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColor.fromInt(0xFF1E293B))),
                          ],
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.RichText(
                        text: pw.TextSpan(
                          children: [
                            pw.TextSpan(text: 'Kelas: ', style: pw.TextStyle(fontSize: 9, color: PdfColor.fromInt(0xFF64748B))),
                            pw.TextSpan(text: className, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColor.fromInt(0xFF1E293B))),
                          ],
                        ),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.RichText(
                        text: pw.TextSpan(
                          children: [
                            pw.TextSpan(text: 'Guru Pengajar: ', style: pw.TextStyle(fontSize: 9, color: PdfColor.fromInt(0xFF64748B))),
                            pw.TextSpan(text: teacherName, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColor.fromInt(0xFF1E293B))),
                          ],
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.RichText(
                        text: pw.TextSpan(
                          children: [
                            pw.TextSpan(text: 'Jumlah Siswa: ', style: pw.TextStyle(fontSize: 9, color: PdfColor.fromInt(0xFF64748B))),
                            pw.TextSpan(text: '${sortedStudents.length} Siswa', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColor.fromInt(0xFF1E293B))),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Table
            pw.Table(
              border: pw.TableBorder.all(color: PdfColor.fromInt(0xFFE2E8F0), width: 0.5),
              columnWidths: columnWidths,
              children: tableRows,
            ),

            pw.SizedBox(height: 32),

            // Signature block
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.end,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Text('Mengetahui,', style: pw.TextStyle(fontSize: 9, color: PdfColor.fromInt(0xFF4B5563))),
                    pw.Text('Guru Pengajar', style: pw.TextStyle(fontSize: 9, color: PdfColor.fromInt(0xFF1E293B), fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 45),
                    pw.Container(
                      width: 140,
                      decoration: const pw.BoxDecoration(
                        border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black, width: 0.8)),
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      teacherName,
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: PdfColor.fromInt(0xFF1E293B)),
                    ),
                  ],
                ),
                pw.SizedBox(width: 40),
              ],
            ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Rekap_Absen_${subjectName.replaceAll(' ', '_')}_$className.pdf',
    );
  }

  /// Membuat dokumen PDF gabungan untuk semua kelas & mapel dan membuka Print Preview
  static Future<void> generateAndShowAllPdf({
    required String teacherName,
    required DateTime startDate,
    required DateTime endDate,
    required List<Map<String, dynamic>> records,
  }) async {
    final pdf = pw.Document();

    // 1. Group records by class and subject
    final Map<String, List<Map<String, dynamic>>> groupedRecords = {};
    for (var r in records) {
      final className = r['className'] as String? ?? 'Kelas Lain';
      final subjectName = r['subjectName'] ?? 'Mapel Lain';
      final key = '$className|$subjectName';
      groupedRecords.putIfAbsent(key, () => []).add(r);
    }

    final List<String> sortedGroupKeys = groupedRecords.keys.toList()..sort();

    // 2. Loop through each group and create separate pages/MultiPage layout
    for (var key in sortedGroupKeys) {
      final parts = key.split('|');
      final className = parts[0];
      final subjectName = parts[1];
      final groupRecords = groupedRecords[key]!;

      // Unique dates
      final Set<String> uniqueDatesSet = {};
      for (var r in groupRecords) {
        final date = r['date'] as String?;
        if (date != null) {
          uniqueDatesSet.add(date);
        }
      }
      final List<String> sortedDates = uniqueDatesSet.toList()
        ..sort((a, b) => a.compareTo(b));

      // Unique students
      final Set<String> uniqueStudentsSet = {};
      for (var r in groupRecords) {
        final name = r['studentName'] as String?;
        if (name != null) {
          uniqueStudentsSet.add(name);
        }
      }
      final List<String> sortedStudents = uniqueStudentsSet.toList()..sort();

      final bool useLandscape = sortedDates.length > 6;
      final pageFormat = useLandscape
          ? PdfPageFormat.a4.copyWith(marginLeft: 20, marginRight: 20, marginTop: 20, marginBottom: 20)
          : PdfPageFormat.a4.copyWith(marginLeft: 30, marginRight: 30, marginTop: 30, marginBottom: 30);

      // Build manual table columns
      final Map<int, pw.TableColumnWidth> columnWidths = {
        0: const pw.FixedColumnWidth(25), // No
        1: const pw.FlexColumnWidth(3),   // Nama Siswa
      };
      for (int dIdx = 0; dIdx < sortedDates.length; dIdx++) {
        columnWidths[dIdx + 2] = const pw.FlexColumnWidth(1);
      }
      columnWidths[sortedDates.length + 2] = const pw.FixedColumnWidth(60);

      // Header cells
      final List<pw.Widget> headerCells = [
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          alignment: pw.Alignment.center,
          child: pw.Text('No', style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 8)),
        ),
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 8),
          alignment: pw.Alignment.centerLeft,
          child: pw.Text('Nama Siswa', style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 8)),
        ),
      ];
      for (var d in sortedDates) {
        headerCells.add(
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 4),
            alignment: pw.Alignment.center,
            child: pw.Text(_shortDate(d), style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 8)),
          ),
        );
      }
      headerCells.add(
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          alignment: pw.Alignment.center,
          child: pw.Text('Total Hadir', style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 8)),
        ),
      );

      // Rows
      final List<pw.TableRow> tableRows = [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFF4F46E5)),
          children: headerCells,
        ),
      ];

      for (int i = 0; i < sortedStudents.length; i++) {
        final studentName = sortedStudents[i];
        final List<pw.Widget> rowCells = [];

        rowCells.add(
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 4),
            alignment: pw.Alignment.center,
            child: pw.Text((i + 1).toString(), style: const pw.TextStyle(fontSize: 8)),
          ),
        );

        rowCells.add(
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 8),
            alignment: pw.Alignment.centerLeft,
            child: pw.Text(studentName, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColor.fromInt(0xFF1E293B))),
          ),
        );

        int presentCount = 0;
        for (var date in sortedDates) {
          final hasCheckedIn = groupRecords.any((r) =>
              r['studentName'] == studentName && r['date'] == date);

          if (hasCheckedIn) {
            rowCells.add(
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                alignment: pw.Alignment.center,
                child: pw.Text('V', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColor.fromInt(0xFF10B981))),
              ),
            );
            presentCount++;
          } else {
            rowCells.add(
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                alignment: pw.Alignment.center,
                child: pw.Text('-', style: pw.TextStyle(fontSize: 8, color: PdfColor.fromInt(0xFF94A3B8))),
              ),
            );
          }
        }

        rowCells.add(
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 4),
            alignment: pw.Alignment.center,
            child: pw.Text('$presentCount/${sortedDates.length}', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColor.fromInt(0xFF1E293B))),
          ),
        );

        tableRows.add(
          pw.TableRow(
            decoration: pw.BoxDecoration(
              color: i % 2 == 0 ? PdfColors.white : PdfColor.fromInt(0xFFF8FAFC),
            ),
            children: rowCells,
          ),
        );
      }

      pdf.addPage(
        pw.MultiPage(
          pageFormat: pageFormat,
          orientation: useLandscape ? pw.PageOrientation.landscape : pw.PageOrientation.portrait,
          build: (context) {
            return [
              // Kop Laporan
              pw.Container(
                decoration: const pw.BoxDecoration(
                  border: pw.Border(bottom: pw.BorderSide(color: PdfColor.fromInt(0xFF4F46E5), width: 2)),
                ),
                padding: const pw.EdgeInsets.only(bottom: 8),
                margin: const pw.EdgeInsets.only(bottom: 16),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'LAPORAN REKAPITULASI ABSENSI SISWA',
                          style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColor.fromInt(0xFF1E1B4B)),
                        ),
                        pw.SizedBox(height: 2),
                        pw.Text(
                          'Periode: ${_formatLongDate(startDate)} s/d ${_formatLongDate(endDate)}',
                          style: pw.TextStyle(fontSize: 9, color: PdfColor.fromInt(0xFF4B5563)),
                        ),
                      ],
                    ),
                    pw.Text(
                      'SISTEM MANAJEMEN SEKOLAH',
                      style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColor.fromInt(0xFF4F46E5)),
                    ),
                  ],
                ),
              ),

              // Metadata card
              pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 16),
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromInt(0xFFF8FAFC),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                  border: pw.Border.all(color: PdfColor.fromInt(0xFFE2E8F0), width: 0.5),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.RichText(
                          text: pw.TextSpan(
                            children: [
                              pw.TextSpan(text: 'Mata Pelajaran: ', style: pw.TextStyle(fontSize: 9, color: PdfColor.fromInt(0xFF64748B))),
                              pw.TextSpan(text: subjectName, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColor.fromInt(0xFF1E293B))),
                            ],
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.RichText(
                          text: pw.TextSpan(
                            children: [
                              pw.TextSpan(text: 'Kelas: ', style: pw.TextStyle(fontSize: 9, color: PdfColor.fromInt(0xFF64748B))),
                              pw.TextSpan(text: className, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColor.fromInt(0xFF1E293B))),
                            ],
                          ),
                        ),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.RichText(
                          text: pw.TextSpan(
                            children: [
                              pw.TextSpan(text: 'Guru Pengajar: ', style: pw.TextStyle(fontSize: 9, color: PdfColor.fromInt(0xFF64748B))),
                              pw.TextSpan(text: teacherName, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColor.fromInt(0xFF1E293B))),
                            ],
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.RichText(
                          text: pw.TextSpan(
                            children: [
                              pw.TextSpan(text: 'Jumlah Siswa: ', style: pw.TextStyle(fontSize: 9, color: PdfColor.fromInt(0xFF64748B))),
                              pw.TextSpan(text: '${sortedStudents.length} Siswa', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColor.fromInt(0xFF1E293B))),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Table
              pw.Table(
                border: pw.TableBorder.all(color: PdfColor.fromInt(0xFFE2E8F0), width: 0.5),
                columnWidths: columnWidths,
                children: tableRows,
              ),

              pw.SizedBox(height: 32),

              // Signature block
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Text('Mengetahui,', style: pw.TextStyle(fontSize: 9, color: PdfColor.fromInt(0xFF4B5563))),
                      pw.Text('Guru Pengajar', style: pw.TextStyle(fontSize: 9, color: PdfColor.fromInt(0xFF1E293B), fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 45),
                      pw.Container(
                        width: 140,
                        decoration: const pw.BoxDecoration(
                          border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black, width: 0.8)),
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        teacherName,
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: PdfColor.fromInt(0xFF1E293B)),
                      ),
                    ],
                  ),
                  pw.SizedBox(width: 40),
                ],
              ),
          ];
        },
      ),
    );
  }

  await Printing.layoutPdf(
    onLayout: (PdfPageFormat format) async => pdf.save(),
    name: 'Rekap_Absensi_Guru_${teacherName.replaceAll(' ', '_')}.pdf',
  );
}
}
