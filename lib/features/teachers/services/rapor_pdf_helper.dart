import 'dart:convert';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

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
        pageFormat: pageFormat,
        footer: (context) {
          return pw.Container(
            alignment: pw.Alignment.centerRight,
            margin: const pw.EdgeInsets.only(top: 15),
            child: pw.Text(
              'Halaman ${context.pageNumber} dari ${context.pagesCount}',
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
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.center,
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        pw.Container(
                          width: 50,
                          height: 50,
                          child: pw.Image(
                            pw.MemoryImage(base64Decode(logoBase64)),
                            fit: pw.BoxFit.contain,
                          ),
                        ),
                        pw.SizedBox(width: 12),
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              'LAPORAN HASIL BELAJAR (RAPOR)',
                              style: pw.TextStyle(
                                fontSize: 14,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColor.fromInt(0xFF1E1B4B),
                              ),
                            ),
                            pw.SizedBox(height: 2),
                            pw.Text(
                              schoolName.toUpperCase(),
                              style: pw.TextStyle(
                                fontSize: 11,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColor.fromInt(0xFF4B5563),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ] else ...[
                    pw.Text(
                      'LAPORAN HASIL BELAJAR (RAPOR)',
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColor.fromInt(0xFF1E1B4B),
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      schoolName.toUpperCase(),
                      style: pw.TextStyle(
                        fontSize: 11,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColor.fromInt(0xFF4B5563),
                      ),
                    ),
                  ],
                  pw.SizedBox(height: 10),
                  pw.Container(
                    height: 1.5,
                    color: PdfColor.fromInt(0xFF1E1B4B),
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
                    _buildInfoRow('Nama Siswa', studentName),
                    _buildInfoRow('NISN / NIS', studentNis),
                    _buildInfoRow('Sekolah', schoolName),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _buildInfoRow('Kelas', className),
                    _buildInfoRow('Semester', semester),
                    _buildInfoRow('Tahun Ajaran', yearInfo),
                  ],
                ),
              ],
            ),

            pw.SizedBox(height: 20),

            // 3. CAPAIAN SIKAP (Dinamis)
            _buildSectionHeader('A. PENILAIAN SIKAP'),
            pw.SizedBox(height: 6),
            pw.Table(
              border: pw.TableBorder.all(
                color: PdfColor.fromInt(0xFFCBD5E1),
                width: 0.5,
              ),
              columnWidths: {
                0: const pw.FixedColumnWidth(100),
                1: const pw.FixedColumnWidth(55),
                2: const pw.FlexColumnWidth(1),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(
                    color: PdfColor.fromInt(0xFFF1F5F9),
                  ),
                  children: [
                    _buildTableHeaderCell('Aspek Sikap'),
                    _buildTableHeaderCell('Predikat'),
                    _buildTableHeaderCell('Deskripsi / Keterangan'),
                  ],
                ),
                ...List.generate(attitudeAspects.length, (index) {
                  final aspect = attitudeAspects[index];
                  final name = aspect['name']?.toString() ?? '';
                  final pred = aspect['predikat']?.toString() ?? 'B';
                  final desc = aspect['deskripsi']?.toString() ?? '';
                  final defaultDesc =
                      'Menunjukkan sikap ${name.toLowerCase()} yang baik.';
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
            _buildSectionHeader('B. PENILAIAN AKADEMIK'),
            pw.SizedBox(height: 6),
            pw.Table(
              border: pw.TableBorder.all(
                color: PdfColor.fromInt(0xFFCBD5E1),
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
                  decoration: const pw.BoxDecoration(
                    color: PdfColor.fromInt(0xFFF1F5F9),
                  ),
                  children: [
                    _buildTableHeaderCell('No'),
                    _buildTableHeaderCell('Mata Pelajaran', alignLeft: true),
                    _buildTableHeaderCell('KKM'),
                    _buildTableHeaderCell('Nilai'),
                    _buildTableHeaderCell('Predikat'),
                    _buildTableHeaderCell(
                      'Deskripsi Pencapaian',
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
                    desc =
                        'Menunjukkan penguasaan materi yang baik pada mata pelajaran ini.';
                  } else if (scoreVal == 0.0) {
                    desc = 'Belum ada penilaian hasil belajar.';
                  }

                  return pw.TableRow(
                    decoration: pw.BoxDecoration(
                      color: idx % 2 == 0
                          ? PdfColors.white
                          : PdfColor.fromInt(0xFFF8FAFC),
                    ),
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
                      _buildSectionHeader('C. KETIDAKHADIRAN'),
                      pw.SizedBox(height: 6),
                      pw.Table(
                        border: pw.TableBorder.all(
                          color: PdfColor.fromInt(0xFFCBD5E1),
                          width: 0.5,
                        ),
                        columnWidths: {
                          0: const pw.FlexColumnWidth(2),
                          1: const pw.FixedColumnWidth(60),
                        },
                        children: [
                          pw.TableRow(
                            decoration: const pw.BoxDecoration(
                              color: PdfColor.fromInt(0xFFF1F5F9),
                            ),
                            children: [
                              _buildTableHeaderCell(
                                'Alasan Absensi',
                                alignLeft: true,
                              ),
                              _buildTableHeaderCell('Jumlah'),
                            ],
                          ),
                          pw.TableRow(
                            children: [
                              _buildTableCell('1. Sakit (S)', alignLeft: true),
                              _buildTableCell('$sakit Hari'),
                            ],
                          ),
                          pw.TableRow(
                            children: [
                              _buildTableCell('2. Izin (I)', alignLeft: true),
                              _buildTableCell('$izin Hari'),
                            ],
                          ),
                          pw.TableRow(
                            children: [
                              _buildTableCell(
                                '3. Tanpa Keterangan (A)',
                                alignLeft: true,
                              ),
                              _buildTableCell('$alpa Hari'),
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
                      _buildSectionHeader('D. CATATAN WALI KELAS'),
                      pw.SizedBox(height: 6),
                      pw.Container(
                        width: double.infinity,
                        height: 80,
                        padding: const pw.EdgeInsets.all(10),
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(
                            color: PdfColor.fromInt(0xFFCBD5E1),
                            width: 0.5,
                          ),
                          color: PdfColor.fromInt(0xFFF8FAFC),
                          borderRadius: const pw.BorderRadius.all(
                            pw.Radius.circular(6),
                          ),
                        ),
                        child: pw.Text(
                          catatanWali.trim().isEmpty
                              ? 'Pertahankan prestasimu dan teruslah belajar dengan giat agar cita-citamu tercapai.'
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
                      'Orang Tua/Wali Murid,',
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
                      'Mengetahui,',
                      style: pw.TextStyle(
                        fontSize: 9,
                        color: PdfColor.fromInt(0xFF4B5563),
                      ),
                    ),
                    pw.Text(
                      'Wali Kelas',
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

  /// Helper untuk baris informasi biodata
  static pw.Widget _buildInfoRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Row(
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          pw.SizedBox(
            width: 75,
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
    return pw.Text(
      title,
      style: pw.TextStyle(
        fontSize: 10,
        fontWeight: pw.FontWeight.bold,
        color: PdfColor.fromInt(0xFF1E1B4B),
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
