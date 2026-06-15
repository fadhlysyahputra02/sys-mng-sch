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

  /// Helper bersama untuk menyusun dokumen PDF rekapitulasi kehadiran per-mapel (per-halaman)
  static Future<pw.Document> _buildPdfDocument({
    required String teacherName,
    required DateTime startDate,
    required DateTime endDate,
    required List<Map<String, dynamic>> records,
    required List<Map<String, dynamic>> schedules,
    required List<Map<String, dynamic>> students,
    required Map<String, String> classIdToName,
    required String schoolName,
  }) async {
    final pdf = pw.Document();

    // Dapatkan daftar nama kelas dari jadwal guru yang terpilih
    final Set<String> targetClassNames = schedules
        .map((s) => s['className'] as String?)
        .whereType<String>()
        .toSet();
    final List<String> sortedClassNames = targetClassNames.toList()..sort();

    // A4 Portrait format
    final pageFormat = PdfPageFormat.a4.copyWith(
      marginLeft: 24,
      marginRight: 24,
      marginTop: 24,
      marginBottom: 24,
    );

    for (final className in sortedClassNames) {
      // 1. Filter murid di kelas ini
      final classStudents = students.where((s) {
        final sClassId = s['classId']?.toString() ?? '';
        final sClassName = classIdToName[sClassId] ?? '';
        return sClassName == className;
      }).toList()..sort((a, b) => (a['nama']?.toString() ?? '').compareTo(b['nama']?.toString() ?? ''));

      if (classStudents.isEmpty) continue;

      // 2. Dapatkan mapel di kelas ini yang diajar oleh guru ini
      final classSubjects = schedules
          .where((s) => s['className'] == className)
          .map((s) => s['subjectName'] as String?)
          .whereType<String>()
          .toSet()
          .toList()..sort();

      for (final subjectName in classSubjects) {
        // Find what weekdays this subject is scheduled for this class
        final Set<int> scheduledWeekdays = {};
        final cleanClassName = className.trim().toLowerCase();
        final cleanSubjectName = subjectName.trim().toLowerCase();
        for (var s in schedules) {
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

        // Header cells for table
        final List<pw.Widget> headerCells = [
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 4),
            alignment: pw.Alignment.centerLeft,
            child: pw.Text('Nama Murid', style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 7)),
          ),
        ];

        final int daysInMonth = DateTime(startDate.year, startDate.month + 1, 0).day;
        for (int d = 1; d <= 31; d++) {
          final date = DateTime(startDate.year, startDate.month, d);
          final isValidDay = d <= daysInMonth;
          bool isScheduled = false;
          if (isValidDay) {
            isScheduled = scheduledWeekdays.contains(date.weekday);
          }

          final headerCellColor = isValidDay
              ? (isScheduled ? PdfColor.fromInt(0xFF2563EB) : PdfColor.fromInt(0xFF94A3B8))
              : PdfColor.fromInt(0xFFCBD5E1);

          headerCells.add(
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 1),
              alignment: pw.Alignment.center,
              color: headerCellColor,
              child: pw.Text(d.toString(), style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 7)),
            ),
          );
        }

        headerCells.add(
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 2),
            alignment: pw.Alignment.center,
            child: pw.Text('Hadir', style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 7)),
          ),
        );

        // Table rows
        final List<pw.TableRow> tableRows = [
          pw.TableRow(
            decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFF4F46E5)),
            children: headerCells,
          ),
        ];

        // Column widths
        final Map<int, pw.TableColumnWidth> columnWidths = {
          0: const pw.FixedColumnWidth(120), // Nama Murid
        };
        for (int d = 1; d <= 31; d++) {
          columnWidths[d] = const pw.FixedColumnWidth(11);
        }
        columnWidths[32] = const pw.FixedColumnWidth(35); // Hadir

        for (int sIdx = 0; sIdx < classStudents.length; sIdx++) {
          final student = classStudents[sIdx];
          final studentName = student['nama']?.toString() ?? 'Murid';
          final studentId = student['studentId']?.toString() ?? '';
          final List<pw.Widget> rowCells = [];

          // Col 0: Student Name
          rowCells.add(
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 4),
              alignment: pw.Alignment.centerLeft,
              child: pw.Text(
                studentName,
                style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: PdfColor.fromInt(0xFF1E293B)),
                maxLines: 1,
                overflow: pw.TextOverflow.clip,
              ),
            ),
          );

          int presentCount = 0;

          // Col 1 to 31: Attendance status
          for (int d = 1; d <= 31; d++) {
            final dateStr = "${startDate.year}-${startDate.month.toString().padLeft(2, '0')}-${d.toString().padLeft(2, '0')}";
            final date = DateTime(startDate.year, startDate.month, d);
            
            // Check if day exists in month
            if (d > daysInMonth) {
              rowCells.add(
                pw.Container(
                  color: PdfColor.fromInt(0xFFE2E8F0),
                  child: pw.SizedBox(height: 12),
                ),
              );
              continue;
            }

            // Check if this day is a scheduled day (including Sunday)
            final bool isDayScheduled = scheduledWeekdays.contains(date.weekday);

            if (isDayScheduled) {
              // This is a scheduled day, check attendance
              final hasCheckedIn = records.any((r) {
                final rStudentId = r['studentId']?.toString();
                final rSubjectName = r['subjectName']?.toString().trim().toLowerCase();
                final rDate = r['date']?.toString();
                return rStudentId == studentId &&
                       rSubjectName == cleanSubjectName &&
                       rDate == dateStr;
              });

              if (hasCheckedIn) {
                rowCells.add(
                  pw.Container(
                    alignment: pw.Alignment.center,
                    child: pw.Text('\u2714', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: PdfColor.fromInt(0xFF10B981))),
                  ),
                );
                presentCount++;
              } else {
                rowCells.add(
                  pw.Container(
                    alignment: pw.Alignment.center,
                    child: pw.Text('-', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: PdfColor.fromInt(0xFFEF4444))),
                  ),
                );
              }
            } else {
              // Not a scheduled day (no class on this day)
              rowCells.add(
                pw.Container(
                  color: PdfColor.fromInt(0xFFF1F5F9),
                  child: pw.SizedBox(height: 12),
                ),
              );
            }
          }

          // Col 32: Total Present in month
          rowCells.add(
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 2),
              alignment: pw.Alignment.center,
              child: pw.Text(presentCount.toString(), style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: PdfColor.fromInt(0xFF1E293B))),
            ),
          );

          tableRows.add(
            pw.TableRow(
              decoration: pw.BoxDecoration(
                color: sIdx % 2 == 0 ? PdfColors.white : PdfColor.fromInt(0xFFF8FAFC),
              ),
              children: rowCells,
            ),
          );
        }

        // Add a MultiPage for each class + subject
        pdf.addPage(
          pw.MultiPage(
            pageFormat: pageFormat,
            orientation: pw.PageOrientation.portrait,
            footer: (context) {
              return pw.Container(
                alignment: pw.Alignment.centerRight,
                margin: const pw.EdgeInsets.only(top: 10),
                child: pw.Text(
                  'Halaman ${context.pageNumber} dari ${context.pagesCount}',
                  style: pw.TextStyle(fontSize: 8, color: PdfColor.fromInt(0xFF94A3B8)),
                ),
              );
            },
            build: (context) {
              return [
                // Kop & Info
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
                            'LAPORAN REKAPITULASI KEHADIRAN SISWA ${schoolName.toUpperCase()}',
                            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColor.fromInt(0xFF1E1B4B)),
                          ),
                          pw.SizedBox(height: 1),
                          pw.Text(
                            'Bulan: ${_formatMonthYear(startDate)}',
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

                // Info Box
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
                                pw.TextSpan(text: 'Kelas: ', style: pw.TextStyle(fontSize: 9, color: PdfColor.fromInt(0xFF64748B))),
                                pw.TextSpan(text: className, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColor.fromInt(0xFF1E293B))),
                              ],
                            ),
                          ),
                          pw.SizedBox(height: 2),
                          pw.RichText(
                            text: pw.TextSpan(
                              children: [
                                pw.TextSpan(text: 'Mata Pelajaran: ', style: pw.TextStyle(fontSize: 9, color: PdfColor.fromInt(0xFF64748B))),
                                pw.TextSpan(text: subjectName, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColor.fromInt(0xFF1E293B))),
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
                                pw.TextSpan(text: 'Jumlah Murid: ', style: pw.TextStyle(fontSize: 9, color: PdfColor.fromInt(0xFF64748B))),
                                pw.TextSpan(text: '${classStudents.length} Murid', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColor.fromInt(0xFF1E293B))),
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

                pw.SizedBox(height: 20),

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
              ];
            },
          ),
        );
      }
    }

    return pdf;
  }

  /// Membuat dokumen PDF gabungan untuk semua kelas & mapel
  static Future<void> generateAndShowAllPdf({
    required String teacherName,
    required DateTime startDate,
    required DateTime endDate,
    required List<Map<String, dynamic>> records,
    required List<Map<String, dynamic>> schedules,
    required List<Map<String, dynamic>> students,
    required Map<String, String> classIdToName,
    required String schoolName,
  }) async {
    final pdf = await _buildPdfDocument(
      teacherName: teacherName,
      startDate: startDate,
      endDate: endDate,
      records: records,
      schedules: schedules,
      students: students,
      classIdToName: classIdToName,
      schoolName: schoolName,
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Rekap_Absensi_Guru_${teacherName.replaceAll(' ', '_')}.pdf',
    );
  }
}
