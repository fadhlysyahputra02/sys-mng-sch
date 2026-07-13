import 'dart:convert';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../core/localization/app_localization.dart';

class RaporPdfHelper {
  /// Membuat dokumen PDF untuk E-Rapor Siswa
  static pw.Document _buildPdfDocument({
    required String schoolName,
    required String className,
    required String teacherName,
    required String studentName,
    required String studentNis,
    required String semester,
    required String yearInfo,
    required List<Map<String, dynamic>>
    subjectScores, // List berisi: {name, score, predikat, deskripsi, kkm}
    required List<Map<String, dynamic>> attitudeAspects,
    required int sakit,
    required int izin,
    required int alpa,
    required String catatanWali,
    Map<String, int>? gradeTemplates,
    String? logoBase64,
  }) {
    final pdf = pw.Document();

    final pageFormat = PdfPageFormat.a4.copyWith(
      marginLeft: 36,
      marginRight: 36,
      marginTop: 36,
      marginBottom: 36,
    );

    final pageTheme = pw.PageTheme(
      pageFormat: pageFormat,
      buildBackground: (context) {
        if (logoBase64 != null && logoBase64.isNotEmpty) {
          try {
            return pw.FullPage(
              ignoreMargins: true,
              child: pw.Center(
                child: pw.Opacity(
                  opacity: 0.10,
                  child: pw.Container(
                    width: 350,
                    height: 350,
                    child: pw.Image(
                      pw.MemoryImage(base64Decode(logoBase64)),
                      fit: pw.BoxFit.contain,
                    ),
                  ),
                ),
              ),
            );
          } catch (_) {
            return pw.SizedBox();
          }
        }
        return pw.SizedBox();
      },
    );

    // Fallback template jika null
    final Map<String, int> gt =
        gradeTemplates ??
        {
          'aplus': 95,
          'a': 90,
          'aminus': 85,
          'bplus': 80,
          'b': 75,
          'bminus': 70,
          'cplus': 65,
          'c': 60,
          'cminus': 55,
        };

    pdf.addPage(
      pw.MultiPage(
        pageTheme: pageTheme,
        footer: (context) {
          return pw.Container(
            alignment: pw.Alignment.centerRight,
            margin: const pw.EdgeInsets.only(top: 15),
            child: pw.Text(
              AppLocalization.isIndonesian
                  ? 'Halaman ${context.pageNumber}'
                  : 'Page ${context.pageNumber}',
              style: pw.TextStyle(
                fontSize: 8,
                color: PdfColor.fromInt(0xFF94A3B8),
              ),
            ),
          );
        },
        build: (context) {
          return [
            // 1. KOP LAPORAN HASIL BELAJAR (dengan Logo)
            pw.Center(
              child: pw.Column(
                children: [
                   if (logoBase64 != null && logoBase64.isNotEmpty) ...[
                    pw.Container(
                      height: 50,
                      child: pw.Stack(
                        alignment: pw.Alignment.center,
                        children: [
                          pw.Align(
                            alignment: pw.Alignment.centerLeft,
                            child: pw.Container(
                              width: 50,
                              height: 50,
                              child: pw.Image(
                                pw.MemoryImage(base64Decode(logoBase64)),
                                fit: pw.BoxFit.contain,
                              ),
                            ),
                          ),
                          pw.Column(
                            mainAxisAlignment: pw.MainAxisAlignment.center,
                            crossAxisAlignment: pw.CrossAxisAlignment.center,
                            children: [
                              pw.Text(
                                AppLocalization.isIndonesian
                                    ? 'LAPORAN HASIL BELAJAR (RAPOR)'
                                    : 'STUDENT PROGRESS REPORT',
                                style: pw.TextStyle(
                                  fontSize: 12,
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColor.fromInt(0xFF1E1B4B),
                                ),
                              ),
                              pw.SizedBox(height: 2),
                              pw.Text(
                                schoolName.toUpperCase(),
                                style: pw.TextStyle(
                                  fontSize: 10,
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColor.fromInt(0xFF4B5563),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        pw.Text(
                          AppLocalization.isIndonesian
                              ? 'LAPORAN HASIL BELAJAR (RAPOR)'
                              : 'STUDENT PROGRESS REPORT',
                          style: pw.TextStyle(
                            fontSize: 12,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColor.fromInt(0xFF1E1B4B),
                          ),
                        ),
                        pw.SizedBox(height: 2),
                        pw.Text(
                          schoolName.toUpperCase(),
                          style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColor.fromInt(0xFF4B5563),
                          ),
                        ),
                      ],
                    ),
                  ],
                  pw.SizedBox(height: 10),
                  pw.Container(
                    height: 3,
                    child: pw.Column(
                      children: [
                        pw.Container(height: 1.5, color: PdfColor.fromInt(0xFF1E1B4B)),
                        pw.SizedBox(height: 1),
                        pw.Container(height: 0.5, color: PdfColor.fromInt(0xFF1E1B4B)),
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 16),
                ],
              ),
            ),

            // 2. BIODATA SISWA & INFORMASI KELAS
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _buildInfoRow(AppLocalization.isIndonesian ? 'Nama Siswa' : 'Student Name', studentName),
                    _buildInfoRow(AppLocalization.isIndonesian ? 'NISN / NIS' : 'Student ID / NISN', studentNis),
                    _buildInfoRow(AppLocalization.isIndonesian ? 'Sekolah' : 'School', schoolName),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _buildInfoRow(AppLocalization.isIndonesian ? 'Kelas' : 'Class', className),
                    _buildInfoRow(AppLocalization.isIndonesian ? 'Semester' : 'Semester', AppLocalization.isIndonesian ? semester : semester.replaceAll('Ganjil', 'Odd').replaceAll('Genap', 'Even')),
                    _buildInfoRow(AppLocalization.isIndonesian ? 'Tahun Ajaran' : 'Academic Year', yearInfo),
                  ],
                ),
              ],
            ),

            pw.SizedBox(height: 20),

            // 3. CAPAIAN SIKAP (Dinamis)
            _buildSectionHeader(AppLocalization.isIndonesian ? 'A. PENILAIAN SIKAP' : 'A. ATTITUDE ASSESSMENT'),
            pw.SizedBox(height: 6),
            pw.Table(
              border: pw.TableBorder.all(
                color: PdfColor(0.796, 0.835, 0.882, 0.90),
                width: 0.5,
              ),
              columnWidths: {
                0: const pw.FixedColumnWidth(100),
                1: const pw.FixedColumnWidth(55),
                2: const pw.FlexColumnWidth(1),
              },
              children: [
                pw.TableRow(
                  decoration: null,
                  children: [
                    _buildTableHeaderCell(AppLocalization.isIndonesian ? 'Aspek Sikap' : 'Attitude Aspect'),
                    _buildTableHeaderCell(AppLocalization.isIndonesian ? 'Predikat' : 'Grade'),
                    _buildTableHeaderCell(AppLocalization.isIndonesian ? 'Deskripsi / Keterangan' : 'Description / Notes'),
                  ],
                ),
                ...List.generate(attitudeAspects.length, (index) {
                  final aspect = attitudeAspects[index];
                  final aspectName = aspect['name']?.toString() ?? '';
                  final name = AppLocalization.isIndonesian
                      ? aspectName
                      : (aspectName == 'Spiritual'
                          ? 'Spiritual'
                          : aspectName == 'Sosial'
                              ? 'Social'
                              : aspectName);
                  final pred = aspect['predikat']?.toString() ?? 'B';
                  final desc = aspect['deskripsi']?.toString() ?? '';
                  final defaultDesc = AppLocalization.isIndonesian
                      ? 'Menunjukkan sikap ${name.toLowerCase()} yang baik.'
                      : 'Shows good ${name.toLowerCase()} attitude.';
                  return pw.TableRow(
                    children: [
                      _buildTableCell('${index + 1}. $name', alignLeft: true),
                      _buildTableCell(pred, isBold: true),
                      _buildTableCell(
                        desc.isEmpty ? defaultDesc : desc,
                        alignLeft: true,
                      ),
                    ],
                  );
                }),
              ],
            ),

            pw.SizedBox(height: 20),

            // 4. PENILAIAN PENGETAHUAN & KETERAMPILAN
            _buildSectionHeader(AppLocalization.isIndonesian ? 'B. PENILAIAN AKADEMIK' : 'B. ACADEMIC ASSESSMENT'),
            pw.SizedBox(height: 6),
            pw.Table(
              border: pw.TableBorder.all(
                color: PdfColor(0.796, 0.835, 0.882, 0.90),
                width: 0.5,
              ),
              columnWidths: {
                0: const pw.FixedColumnWidth(30),
                1: const pw.FlexColumnWidth(3),
                2: const pw.FixedColumnWidth(45),
                3: const pw.FixedColumnWidth(45),
                4: const pw.FixedColumnWidth(55),
                5: const pw.FlexColumnWidth(5),
              },
              children: [
                // Header
                pw.TableRow(
                  decoration: null,
                  children: [
                    _buildTableHeaderCell('No'),
                    _buildTableHeaderCell(AppLocalization.isIndonesian ? 'Mata Pelajaran' : 'Subject', alignLeft: true),
                    _buildTableHeaderCell('KKM'),
                    _buildTableHeaderCell(AppLocalization.isIndonesian ? 'Nilai' : 'Grade'),
                    _buildTableHeaderCell(AppLocalization.isIndonesian ? 'Predikat' : 'Grade'),
                    _buildTableHeaderCell(
                      AppLocalization.isIndonesian ? 'Deskripsi Pencapaian' : 'Achievement Description',
                      alignLeft: true,
                    ),
                  ],
                ),
                // Mapel Rows
                ...List.generate(subjectScores.length, (idx) {
                  final item = subjectScores[idx];
                  final name = item['name']?.toString() ?? '-';
                  final kkm = item['kkm']?.toString() ?? '75';
                  final double scoreVal =
                      (item['score'] as num?)?.toDouble() ?? 0.0;
                  final String scoreStr = scoreVal > 0
                      ? scoreVal.toStringAsFixed(1)
                      : '-';

                  // Hitung predikat dinamis menggunakan konfigurasi template dari sekolah
                  String pred = item['predikat']?.toString() ?? '';
                  if (pred.isEmpty && scoreVal > 0) {
                    if (scoreVal >= (gt['aplus'] ?? 95)) {
                      pred = 'A+';
                    } else if (scoreVal >= (gt['a'] ?? 90)) {
                      pred = 'A';
                    } else if (scoreVal >= (gt['aminus'] ?? 85)) {
                      pred = 'A-';
                    } else if (scoreVal >= (gt['bplus'] ?? 80)) {
                      pred = 'B+';
                    } else if (scoreVal >= (gt['b'] ?? 75)) {
                      pred = 'B';
                    } else if (scoreVal >= (gt['bminus'] ?? 70)) {
                      pred = 'B-';
                    } else if (scoreVal >= (gt['cplus'] ?? 65)) {
                      pred = 'C+';
                    } else if (scoreVal >= (gt['c'] ?? 60)) {
                      pred = 'C';
                    } else if (scoreVal >= (gt['cminus'] ?? 55)) {
                      pred = 'C-';
                    } else {
                      pred = 'D';
                    }
                  } else if (scoreVal == 0.0) {
                    pred = '-';
                  }

                  String desc = item['deskripsi']?.toString() ?? '';
                  if (desc.isEmpty && scoreVal > 0) {
                    desc = AppLocalization.isIndonesian
                        ? 'Menunjukkan penguasaan materi yang baik pada mata pelajaran ini.'
                        : 'Shows good mastery of the material in this subject.';
                  } else if (scoreVal == 0.0) {
                    desc = AppLocalization.isIndonesian
                        ? 'Belum ada penilaian hasil belajar.'
                        : 'No assessment records yet.';
                  }

                  return pw.TableRow(
                    decoration: null,
                    children: [
                      _buildTableCell((idx + 1).toString()),
                      _buildTableCell(name, alignLeft: true, isBold: true),
                      _buildTableCell(kkm),
                      _buildTableCell(scoreStr, isBold: true),
                      _buildTableCell(pred, isBold: true),
                      _buildTableCell(desc, alignLeft: true),
                    ],
                  );
                }),
              ],
            ),

            pw.SizedBox(height: 20),

            // 5. KEHADIRAN (Sakit, Izin, Alpa) & CATATAN WALI KELAS
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Absensi (Kiri)
                pw.Expanded(
                  flex: 4,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      _buildSectionHeader(AppLocalization.isIndonesian ? 'C. KETIDAKHADIRAN' : 'C. ABSENCE / ATTENDANCE'),
                      pw.SizedBox(height: 6),
                      pw.Table(
                        border: pw.TableBorder.all(
                          color: PdfColor(0.796, 0.835, 0.882, 0.90),
                          width: 0.5,
                        ),
                        columnWidths: {
                          0: const pw.FlexColumnWidth(2),
                          1: const pw.FixedColumnWidth(60),
                        },
                        children: [
                          pw.TableRow(
                            decoration: null,
                            children: [
                              _buildTableHeaderCell(
                                AppLocalization.isIndonesian ? 'Alasan Absensi' : 'Absence Reason',
                                alignLeft: true,
                              ),
                              _buildTableHeaderCell(AppLocalization.isIndonesian ? 'Jumlah' : 'Total'),
                            ],
                          ),
                          pw.TableRow(
                            children: [
                              _buildTableCell(AppLocalization.isIndonesian ? '1. Sakit (S)' : '1. Sick (S)', alignLeft: true),
                              _buildTableCell(AppLocalization.isIndonesian ? '$sakit Hari' : '$sakit Days'),
                            ],
                          ),
                          pw.TableRow(
                            children: [
                              _buildTableCell(AppLocalization.isIndonesian ? '2. Izin (I)' : '2. Permit (P)', alignLeft: true),
                              _buildTableCell(AppLocalization.isIndonesian ? '$izin Hari' : '$izin Days'),
                            ],
                          ),
                          pw.TableRow(
                            children: [
                              _buildTableCell(
                                AppLocalization.isIndonesian ? '3. Tanpa Keterangan (A)' : '3. Unexcused Absence (A)',
                                alignLeft: true,
                              ),
                              _buildTableCell(AppLocalization.isIndonesian ? '$alpa Hari' : '$alpa Days'),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(width: 24),
                // Catatan (Kanan)
                pw.Expanded(
                  flex: 6,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      _buildSectionHeader(AppLocalization.isIndonesian ? 'D. CATATAN WALI KELAS' : 'D. HOMEROOM TEACHER NOTES'),
                      pw.SizedBox(height: 6),
                      pw.Container(
                        width: double.infinity,
                        height: 80,
                        padding: const pw.EdgeInsets.all(10),
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(
                            color: PdfColor(0.796, 0.835, 0.882, 0.90),
                            width: 0.5,
                          ),
                          borderRadius: const pw.BorderRadius.all(
                            pw.Radius.circular(6),
                          ),
                        ),
                        child: pw.Text(
                          catatanWali.trim().isEmpty
                              ? (AppLocalization.isIndonesian
                                  ? 'Pertahankan prestasimu dan teruslah belajar dengan giat agar cita-citamu tercapai.'
                                  : 'Keep up your achievements and study hard to reach your goals.')
                              : catatanWali,
                          style: pw.TextStyle(
                            fontSize: 9,
                            height: 1.4,
                            color: PdfColor.fromInt(0xFF1E293B),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            pw.SizedBox(height: 20),

            // 7. AREA TANDA TANGAN
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Text(
                      AppLocalization.isIndonesian ? 'Orang Tua/Wali Murid,' : 'Parent / Guardian,',
                      style: pw.TextStyle(
                        fontSize: 9,
                        color: PdfColor.fromInt(0xFF4B5563),
                      ),
                    ),
                    pw.SizedBox(height: 45),
                    pw.Container(
                      width: 140,
                      decoration: const pw.BoxDecoration(
                        border: pw.Border(
                          bottom: pw.BorderSide(
                            color: PdfColors.black,
                            width: 0.8,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Text(
                      '${DateTime.now().day} ${AppLocalization.isIndonesian ? _getIndonesianMonth(DateTime.now().month) : _getEnglishMonth(DateTime.now().month)} ${DateTime.now().year}',
                      style: pw.TextStyle(
                        fontSize: 9,
                        color: PdfColor.fromInt(0xFF1E293B),
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      AppLocalization.isIndonesian ? 'Mengetahui,' : 'Acknowledged,',
                      style: pw.TextStyle(
                        fontSize: 9,
                        color: PdfColor.fromInt(0xFF4B5563),
                      ),
                    ),
                    pw.Text(
                      AppLocalization.isIndonesian ? 'Wali Kelas' : 'Homeroom Teacher',
                      style: pw.TextStyle(
                        fontSize: 9,
                        color: PdfColor.fromInt(0xFF1E293B),
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 45),
                    pw.Container(
                      width: 140,
                      decoration: const pw.BoxDecoration(
                        border: pw.Border(
                          bottom: pw.BorderSide(
                            color: PdfColors.black,
                            width: 0.8,
                          ),
                        ),
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      teacherName,
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 9,
                        color: PdfColor.fromInt(0xFF1E293B),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ];
        },
      ),
    );

    return pdf;
  }

  static String _getIndonesianMonth(int month) {
    const months = [
      'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
    ];
    return months[month - 1];
  }

  static String _getEnglishMonth(int month) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return months[month - 1];
  }

  /// Helper untuk baris informasi biodata
  static pw.Widget _buildInfoRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Row(
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          pw.SizedBox(
            width: 105,
            child: pw.Text(
              label,
              style: pw.TextStyle(
                fontSize: 9,
                color: PdfColor.fromInt(0xFF64748B),
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
          pw.Text(': ', style: const pw.TextStyle(fontSize: 9)),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
              color: PdfColor.fromInt(0xFF1E293B),
            ),
          ),
        ],
      ),
    );
  }

  /// Helper judul section
  static pw.Widget _buildSectionHeader(String title) {
    return pw.Container(
      width: double.infinity,
      decoration: const pw.BoxDecoration(
        borderRadius: pw.BorderRadius.all(pw.Radius.circular(4)),
      ),
      child: pw.Row(
        children: [
          pw.Container(
            width: 3,
            height: 18,
            decoration: const pw.BoxDecoration(
              color: PdfColor.fromInt(0xFF4F46E5), // indigo indicator
              borderRadius: pw.BorderRadius.only(
                topLeft: pw.Radius.circular(4),
                bottomLeft: pw.Radius.circular(4),
              ),
            ),
          ),
          pw.SizedBox(width: 8),
          pw.Expanded(
            child: pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 4),
              child: pw.Text(
                title,
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColor.fromInt(0xFF312E81), // deep indigo
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Helper header cell
  static pw.Widget _buildTableHeaderCell(
    String text, {
    bool alignLeft = false,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(6),
      alignment: alignLeft ? pw.Alignment.centerLeft : pw.Alignment.center,
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontWeight: pw.FontWeight.bold,
          fontSize: 8,
          color: PdfColor.fromInt(0xFF1E293B),
        ),
      ),
    );
  }

  /// Helper body cell
  static pw.Widget _buildTableCell(
    String text, {
    bool alignLeft = false,
    bool isBold = false,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(6),
      alignment: alignLeft ? pw.Alignment.centerLeft : pw.Alignment.center,
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 8,
          fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: PdfColor.fromInt(0xFF334155),
        ),
      ),
    );
  }

  /// Mengeluarkan print layout PDF
  static Future<void> generateAndShowRaporPdf({
    required String schoolName,
    required String className,
    required String teacherName,
    required String studentName,
    required String studentNis,
    required String semester,
    required String yearInfo,
    required List<Map<String, dynamic>> subjectScores,
    required List<Map<String, dynamic>> attitudeAspects,
    required int sakit,
    required int izin,
    required int alpa,
    required String catatanWali,
    Map<String, int>? gradeTemplates,
    String? logoBase64,
  }) async {
    final pdf = _buildPdfDocument(
      schoolName: schoolName,
      className: className,
      teacherName: teacherName,
      studentName: studentName,
      studentNis: studentNis,
      semester: semester,
      yearInfo: yearInfo,
      subjectScores: subjectScores,
      attitudeAspects: attitudeAspects,
      sakit: sakit,
      izin: izin,
      alpa: alpa,
      catatanWali: catatanWali,
      gradeTemplates: gradeTemplates,
      logoBase64: logoBase64,
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Rapor_${studentName.replaceAll(' ', '_')}.pdf',
    );
  }
}
