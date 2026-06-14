import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class AttendancePdfHelper {
  /// Mengonversi format nama bulan Indonesia
  static String _formatMonthYear(DateTime date) {
    const months = [
      'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
    ];
    return '${months[date.month - 1]} ${date.year}';
  }

  /// Mengonversi DateTime ke format panjang bahasa Indonesia, misal "13 Juni 2026"
  static String _formatLongDate(DateTime date) {
    final months = [
      'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  /// Helper bersama untuk menyusun dokumen PDF rekapitulasi kehadiran per-siswa
  static Future<pw.Document> _buildPdfDocument({
    required String teacherName,
    required DateTime startDate,
    required DateTime endDate,
    required List<Map<String, dynamic>> records,
    required List<Map<String, dynamic>> schedules,
  }) async {
    final pdf = pw.Document();

    // 1. Group records by student
    final Map<String, List<Map<String, dynamic>>> studentRecords = {};
    for (var r in records) {
      final studentName = r['studentName'] as String?;
      if (studentName != null) {
        studentRecords.putIfAbsent(studentName, () => []).add(r);
      }
    }

    final List<String> sortedStudents = studentRecords.keys.toList()..sort();

    // Generate list of months in the period
    final List<DateTime> monthsInPeriod = [];
    DateTime temp = DateTime(startDate.year, startDate.month, 1);
    final endLimit = DateTime(endDate.year, endDate.month, 1);
    while (temp.isBefore(endLimit) || temp.isAtSameMomentAs(endLimit)) {
      monthsInPeriod.add(DateTime(temp.year, temp.month));
      temp = DateTime(temp.year, temp.month + 1, 1);
    }

    // A4 Landscape format
    final pageFormat = PdfPageFormat.a4.copyWith(
      marginLeft: 24,
      marginRight: 24,
      marginTop: 24,
      marginBottom: 24,
    );

    // 2. Add a page per student
    for (final studentName in sortedStudents) {
      final sRecords = studentRecords[studentName]!;
      final className = sRecords.first['className'] as String? ?? 'Kelas';

      // Find all unique subjects for this student's class from schedule, fallback to records
      final Set<String> studentSubjects = {};
      for (var s in schedules) {
        if (s['className'] == className) {
          final sub = s['subjectName'] as String?;
          if (sub != null) {
            studentSubjects.add(sub);
          }
        }
      }
      if (studentSubjects.isEmpty) {
        for (var r in sRecords) {
          final sub = r['subjectName'] as String?;
          if (sub != null) {
            studentSubjects.add(sub);
          }
        }
      }
      final List<String> sortedSubjects = studentSubjects.toList()..sort();

      pdf.addPage(
        pw.Page(
          pageFormat: pageFormat,
          orientation: pw.PageOrientation.landscape,
          build: (context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                // Header (Kop & Info)
                pw.Container(
                  decoration: const pw.BoxDecoration(
                    border: pw.Border(bottom: pw.BorderSide(color: PdfColor.fromInt(0xFF4F46E5), width: 1.5)),
                  ),
                  padding: const pw.EdgeInsets.only(bottom: 6),
                  margin: const pw.EdgeInsets.only(bottom: 12),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'LAPORAN REKAPITULASI KEHADIRAN SISWA',
                            style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: PdfColor.fromInt(0xFF1E1B4B)),
                          ),
                          pw.SizedBox(height: 1),
                          pw.Text(
                            'Periode: ${_formatLongDate(startDate)} s/d ${_formatLongDate(endDate)}',
                            style: pw.TextStyle(fontSize: 8, color: PdfColor.fromInt(0xFF4B5563)),
                          ),
                        ],
                      ),
                      pw.Text(
                        'SISTEM MANAJEMEN SEKOLAH',
                        style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColor.fromInt(0xFF4F46E5)),
                      ),
                    ],
                  ),
                ),

                // Info Siswa
                pw.Container(
                  margin: const pw.EdgeInsets.only(bottom: 12),
                  padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 12),
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
                                pw.TextSpan(text: 'Nama Murid: ', style: pw.TextStyle(fontSize: 9, color: PdfColor.fromInt(0xFF64748B))),
                                pw.TextSpan(text: studentName, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColor.fromInt(0xFF1E293B))),
                              ],
                            ),
                          ),
                          pw.SizedBox(height: 2),
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
                          pw.SizedBox(height: 2),
                          pw.RichText(
                            text: pw.TextSpan(
                              children: [
                                pw.TextSpan(text: 'Total Mapel: ', style: pw.TextStyle(fontSize: 9, color: PdfColor.fromInt(0xFF64748B))),
                                pw.TextSpan(text: '${sortedSubjects.length} Mata Pelajaran', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColor.fromInt(0xFF1E293B))),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // List of Subject Tables
                pw.Expanded(
                  child: pw.ListView.builder(
                    itemCount: sortedSubjects.length,
                    itemBuilder: (context, index) {
                      final subjectName = sortedSubjects[index];

                      // Header cells for table
                      final List<pw.Widget> headerCells = [
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                          alignment: pw.Alignment.centerLeft,
                          child: pw.Text('Bulan', style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 8)),
                        ),
                      ];
                      for (int d = 1; d <= 31; d++) {
                        headerCells.add(
                          pw.Container(
                            padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                            alignment: pw.Alignment.center,
                            child: pw.Text(d.toString(), style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 8)),
                          ),
                        );
                      }
                      headerCells.add(
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                          alignment: pw.Alignment.center,
                          child: pw.Text('Hadir', style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 8)),
                        ),
                      );

                      // Table rows (Month rows)
                      final List<pw.TableRow> tableRows = [
                        pw.TableRow(
                          decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFF4F46E5)),
                          children: headerCells,
                        ),
                      ];

                      // Column widths
                      final Map<int, pw.TableColumnWidth> columnWidths = {
                        0: const pw.FixedColumnWidth(80), // Month
                      };
                      for (int d = 1; d <= 31; d++) {
                        columnWidths[d] = const pw.FixedColumnWidth(20);
                      }
                      columnWidths[32] = const pw.FixedColumnWidth(50); // Total Hadir

                      for (int mIdx = 0; mIdx < monthsInPeriod.length; mIdx++) {
                        final month = monthsInPeriod[mIdx];
                        final List<pw.Widget> rowCells = [];

                        // Col 0: Month Name
                        rowCells.add(
                          pw.Container(
                            padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                            alignment: pw.Alignment.centerLeft,
                            child: pw.Text(_formatMonthYear(month), style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColor.fromInt(0xFF1E293B))),
                          ),
                        );

                        int monthPresentCount = 0;
                        int daysInMonth = DateTime(month.year, month.month + 1, 0).day;

                        // Col 1 to 31: Attendance status
                        for (int d = 1; d <= 31; d++) {
                          final dateStr = "${month.year}-${month.month.toString().padLeft(2, '0')}-${d.toString().padLeft(2, '0')}";
                          final date = DateTime(month.year, month.month, d);
                          
                          // Check if day exists in month
                          if (d > daysInMonth) {
                            rowCells.add(
                              pw.Container(
                                color: PdfColor.fromInt(0xFFE2E8F0),
                                child: pw.SizedBox(height: 16),
                              ),
                            );
                            continue;
                          }

                          // Check range limits
                          final isOutOfRange = date.isBefore(DateTime(startDate.year, startDate.month, startDate.day)) ||
                                               date.isAfter(DateTime(endDate.year, endDate.month, endDate.day));
                          
                          if (isOutOfRange) {
                            rowCells.add(
                              pw.Container(
                                color: PdfColor.fromInt(0xFFF1F5F9),
                                child: pw.SizedBox(height: 16),
                              ),
                            );
                          } else if (date.weekday == DateTime.sunday) {
                            // Sunday (greyed out)
                            rowCells.add(
                              pw.Container(
                                color: PdfColor.fromInt(0xFFE2E8F0),
                                alignment: pw.Alignment.center,
                                child: pw.Text('-', style: pw.TextStyle(fontSize: 7, color: PdfColor.fromInt(0xFF94A3B8))),
                              ),
                            );
                          } else {
                            final hasCheckedIn = sRecords.any((r) =>
                                r['subjectName'] == subjectName && r['date'] == dateStr);

                            if (hasCheckedIn) {
                              rowCells.add(
                                pw.Container(
                                  alignment: pw.Alignment.center,
                                  child: pw.Text('V', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColor.fromInt(0xFF10B981))),
                                ),
                              );
                              monthPresentCount++;
                            } else {
                              rowCells.add(
                                pw.Container(
                                  alignment: pw.Alignment.center,
                                  child: pw.Text('-', style: pw.TextStyle(fontSize: 8, color: PdfColor.fromInt(0xFF94A3B8))),
                                ),
                              );
                            }
                          }
                        }

                        // Col 32: Total Present in month
                        rowCells.add(
                          pw.Container(
                            padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                            alignment: pw.Alignment.center,
                            child: pw.Text(monthPresentCount.toString(), style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColor.fromInt(0xFF1E293B))),
                          ),
                        );

                        tableRows.add(
                          pw.TableRow(
                            decoration: pw.BoxDecoration(
                              color: mIdx % 2 == 0 ? PdfColors.white : PdfColor.fromInt(0xFFF8FAFC),
                            ),
                            children: rowCells,
                          ),
                        );
                      }

                      return pw.Container(
                        margin: const pw.EdgeInsets.only(bottom: 14),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Container(
                              padding: const pw.EdgeInsets.symmetric(vertical: 2, horizontal: 6),
                              decoration: const pw.BoxDecoration(
                                color: PdfColor.fromInt(0xFFEEF2FF),
                                borderRadius: pw.BorderRadius.all(pw.Radius.circular(4)),
                              ),
                              child: pw.Text(
                                'Mata Pelajaran: $subjectName',
                                style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColor.fromInt(0xFF4F46E5)),
                              ),
                            ),
                            pw.SizedBox(height: 4),
                            pw.Table(
                              border: pw.TableBorder.all(color: PdfColor.fromInt(0xFFE2E8F0), width: 0.5),
                              columnWidths: columnWidths,
                              children: tableRows,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),

                pw.SizedBox(height: 10),

                // Signature block
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.end,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        pw.Text('Mengetahui,', style: pw.TextStyle(fontSize: 8, color: PdfColor.fromInt(0xFF4B5563))),
                        pw.Text('Guru Pengajar', style: pw.TextStyle(fontSize: 8, color: PdfColor.fromInt(0xFF1E293B), fontWeight: pw.FontWeight.bold)),
                        pw.SizedBox(height: 35),
                        pw.Container(
                          width: 120,
                          decoration: const pw.BoxDecoration(
                            border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black, width: 0.8)),
                          ),
                        ),
                        pw.SizedBox(height: 3),
                        pw.Text(
                          teacherName,
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8, color: PdfColor.fromInt(0xFF1E293B)),
                        ),
                      ],
                    ),
                    pw.SizedBox(width: 20),
                  ],
                ),
              ],
            );
          },
        ),
      );
    }

    return pdf;
  }

  /// Membuat dokumen PDF dan membuka Print Preview untuk kelas tunggal (format per-siswa)
  static Future<void> generateAndShowPdf({
    required String subjectName,
    required String className,
    required String teacherName,
    required DateTime startDate,
    required DateTime endDate,
    required List<Map<String, dynamic>> records,
    required List<Map<String, dynamic>> schedules,
  }) async {
    final pdf = await _buildPdfDocument(
      teacherName: teacherName,
      startDate: startDate,
      endDate: endDate,
      records: records,
      schedules: schedules,
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Rekap_Absen_${subjectName.replaceAll(' ', '_')}_$className.pdf',
    );
  }

  /// Membuat dokumen PDF gabungan untuk semua kelas & mapel (format per-siswa)
  static Future<void> generateAndShowAllPdf({
    required String teacherName,
    required DateTime startDate,
    required DateTime endDate,
    required List<Map<String, dynamic>> records,
    required List<Map<String, dynamic>> schedules,
  }) async {
    final pdf = await _buildPdfDocument(
      teacherName: teacherName,
      startDate: startDate,
      endDate: endDate,
      records: records,
      schedules: schedules,
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Rekap_Absensi_Guru_${teacherName.replaceAll(' ', '_')}.pdf',
    );
  }
}
