import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class GradePdfHelper {
  /// Membuat dokumen PDF untuk Rekapitulasi Nilai Kelas (Buku Nilai)
  static Future<pw.Document> _buildPdfDocument({
    required String schoolName,
    required String className,
    required String teacherName,
    required List<Map<String, dynamic>> students,
    required List<Map<String, String>> subjects,
    required Map<String, Map<String, double>> studentGrades,
    required String tahunAjaran,
    required String semester,
  }) async {
    final pdf = pw.Document();

    // Gunakan A4 Landscape agar kolom mata pelajaran yang banyak muat dengan baik
    final pageFormat = PdfPageFormat.a4.landscape.copyWith(
      marginLeft: 24,
      marginRight: 24,
      marginTop: 24,
      marginBottom: 24,
    );

    // 1. Siapkan header tabel
    final List<pw.Widget> headerCells = [
      pw.Container(
        padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        alignment: pw.Alignment.center,
        child: pw.Text('No', style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 8)),
      ),
      pw.Container(
        padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        alignment: pw.Alignment.center,
        child: pw.Text('NIS', style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 8)),
      ),
      pw.Container(
        padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 6),
        alignment: pw.Alignment.centerLeft,
        child: pw.Text('Nama Murid', style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 8)),
      ),
    ];

    // Tambah kolom mata pelajaran
    for (final subject in subjects) {
      headerCells.add(
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          alignment: pw.Alignment.center,
          child: pw.Text(
            subject['name'] ?? '',
            style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 7),
            textAlign: pw.TextAlign.center,
          ),
        ),
      );
    }

    // Kolom Rata-rata akhir
    headerCells.add(
      pw.Container(
        padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        alignment: pw.Alignment.center,
        child: pw.Text('Rerata', style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 8)),
      ),
    );

    // 2. Siapkan baris tabel data siswa
    final List<pw.TableRow> tableRows = [
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFF4F46E5)), // Indigo
        children: headerCells,
      ),
    ];

    // Konfigurasi lebar kolom secara proporsional
    final Map<int, pw.TableColumnWidth> columnWidths = {
      0: const pw.FixedColumnWidth(25),  // No
      1: const pw.FixedColumnWidth(45),  // NIS
      2: const pw.FixedColumnWidth(120), // Nama Murid
    };

    int colIdx = 3;
    for (int i = 0; i < subjects.length; i++) {
      columnWidths[colIdx] = const pw.FlexColumnWidth(1); // Kolom Mapel elastis
      colIdx++;
    }
    columnWidths[colIdx] = const pw.FixedColumnWidth(40); // Rata-rata

    // Isi data siswa
    for (int idx = 0; idx < students.length; idx++) {
      final student = students[idx];
      final studentId = student['studentId']?.toString() ?? '';
      final studentName = student['nama']?.toString() ?? '-';
      final studentNis = student['nis']?.toString() ?? '-';

      final List<pw.Widget> rowCells = [
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 4),
          alignment: pw.Alignment.center,
          child: pw.Text((idx + 1).toString(), style: const pw.TextStyle(fontSize: 8)),
        ),
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 4),
          alignment: pw.Alignment.center,
          child: pw.Text(studentNis, style: const pw.TextStyle(fontSize: 8)),
        ),
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 6),
          alignment: pw.Alignment.centerLeft,
          child: pw.Text(
            studentName,
            style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColor.fromInt(0xFF1E293B)),
            maxLines: 1,
            overflow: pw.TextOverflow.clip,
          ),
        ),
      ];

      // Ambil nilai per mapel untuk siswa ini
      final mapelGrades = studentGrades[studentId] ?? {};
      double sum = 0.0;
      int count = 0;

      for (final subject in subjects) {
        final subjectId = subject['id'] ?? '';
        final score = mapelGrades[subjectId];

        if (score != null) {
          sum += score;
          count++;
          rowCells.add(
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 4),
              alignment: pw.Alignment.center,
              child: pw.Text(score.toStringAsFixed(1), style: const pw.TextStyle(fontSize: 8)),
            ),
          );
        } else {
          rowCells.add(
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 4),
              alignment: pw.Alignment.center,
              child: pw.Text('-', style: pw.TextStyle(fontSize: 8, color: PdfColor.fromInt(0xFF94A3B8))),
            ),
          );
        }
      }

      // Rata-rata akhir siswa
      final double average = count > 0 ? sum / count : 0.0;
      rowCells.add(
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 4),
          alignment: pw.Alignment.center,
          child: pw.Text(
            count > 0 ? average.toStringAsFixed(1) : '-',
            style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColor.fromInt(0xFF4F46E5)),
          ),
        ),
      );

      tableRows.add(
        pw.TableRow(
          decoration: pw.BoxDecoration(
            color: idx % 2 == 0 ? PdfColors.white : PdfColor.fromInt(0xFFF8FAFC),
          ),
          children: rowCells,
        ),
      );
    }

    // Tambah halaman ke PDF
    pdf.addPage(
      pw.MultiPage(
        pageFormat: pageFormat,
        orientation: pw.PageOrientation.landscape,
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
            // Kop & Header Laporan
            pw.Container(
              decoration: const pw.BoxDecoration(
                border: pw.Border(bottom: pw.BorderSide(color: PdfColor.fromInt(0xFF4F46E5), width: 2.0)),
              ),
              padding: const pw.EdgeInsets.only(bottom: 6),
              margin: const pw.EdgeInsets.only(bottom: 16),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'LAPORAN REKAPITULASI HASIL BELAJAR SISWA (BUKU NILAI)',
                        style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColor.fromInt(0xFF1E1B4B)),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        schoolName.toUpperCase(),
                        style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColor.fromInt(0xFF4B5563)),
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

            // Kotak Informasi Kelas & Wali Kelas
            pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 16),
              padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromInt(0xFFF8FAFC),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                border: pw.Border.all(color: PdfColor.fromInt(0xFFE2E8F0), width: 0.5),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.RichText(
                    text: pw.TextSpan(
                      children: [
                        pw.TextSpan(text: 'Kelas: ', style: pw.TextStyle(fontSize: 9, color: PdfColor.fromInt(0xFF64748B))),
                        pw.TextSpan(text: className, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColor.fromInt(0xFF1E293B))),
                      ],
                    ),
                  ),
                  pw.RichText(
                    text: pw.TextSpan(
                      children: [
                        pw.TextSpan(text: 'Tahun Ajaran: ', style: pw.TextStyle(fontSize: 9, color: PdfColor.fromInt(0xFF64748B))),
                        pw.TextSpan(text: '$tahunAjaran ($semester)', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColor.fromInt(0xFF1E293B))),
                      ],
                    ),
                  ),
                  pw.RichText(
                    text: pw.TextSpan(
                      children: [
                        pw.TextSpan(text: 'Wali Kelas: ', style: pw.TextStyle(fontSize: 9, color: PdfColor.fromInt(0xFF64748B))),
                        pw.TextSpan(text: teacherName, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColor.fromInt(0xFF1E293B))),
                      ],
                    ),
                  ),
                  pw.RichText(
                    text: pw.TextSpan(
                      children: [
                        pw.TextSpan(text: 'Jumlah Murid: ', style: pw.TextStyle(fontSize: 9, color: PdfColor.fromInt(0xFF64748B))),
                        pw.TextSpan(text: '${students.length} Murid', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColor.fromInt(0xFF1E293B))),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Tabel Rekapitulasi Nilai
            pw.Table(
              border: pw.TableBorder.all(color: PdfColor.fromInt(0xFFE2E8F0), width: 0.5),
              columnWidths: columnWidths,
              children: tableRows,
            ),

            pw.SizedBox(height: 30),

            // Kolom Tanda Tangan Wali Kelas
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.end,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Text('Mengetahui,', style: pw.TextStyle(fontSize: 9, color: PdfColor.fromInt(0xFF4B5563))),
                    pw.Text('Wali Kelas', style: pw.TextStyle(fontSize: 9, color: PdfColor.fromInt(0xFF1E293B), fontWeight: pw.FontWeight.bold)),
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

    return pdf;
  }

  /// Membuat dan meluncurkan dialog cetak/layout PDF
  static Future<void> generateAndShowPdf({
    required String schoolName,
    required String className,
    required String teacherName,
    required List<Map<String, dynamic>> students,
    required List<Map<String, String>> subjects,
    required Map<String, Map<String, double>> studentGrades,
    required String tahunAjaran,
    required String semester,
  }) async {
    final pdf = await _buildPdfDocument(
      schoolName: schoolName,
      className: className,
      teacherName: teacherName,
      students: students,
      subjects: subjects,
      studentGrades: studentGrades,
      tahunAjaran: tahunAjaran,
      semester: semester,
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Buku_Nilai_Kelas_${className.replaceAll(' ', '_')}.pdf',
    );
  }
}
