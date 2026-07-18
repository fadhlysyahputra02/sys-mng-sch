import 'dart:convert';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../core/localization/app_localization.dart';
import '../../schools/pages/rapor/models/rapor_pdf_settings.dart';

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
    RaporPdfSettings? settings,
  }) {
    final pdf = pw.Document();

    final activeSettings = settings ?? RaporPdfSettings.defaultSettings(schoolName);

    int parseHexColor(String hex) {
      try {
        final cleanHex = hex.replaceAll('#', '');
        return int.parse('FF$cleanHex', radix: 16);
      } catch (_) {
        return 0xFF1E1B4B;
      }
    }

    final primaryColor = PdfColor.fromInt(parseHexColor(activeSettings.primaryColorHex));
    final secondaryColor = PdfColor.fromInt(parseHexColor(activeSettings.secondaryColorHex));
    final double fSize = activeSettings.fontSize.toDouble();

    final pageFormat = PdfPageFormat.a4.copyWith(
      marginLeft: 36,
      marginRight: 36,
      marginTop: 36,
      marginBottom: 36,
    );

    final pageTheme = pw.PageTheme(
      pageFormat: pageFormat,
      buildBackground: (context) {
        final watermarkLogo = activeSettings.showWatermark
            ? (activeSettings.logoRightBase64 ?? logoBase64)
            : null;
        if (watermarkLogo != null && watermarkLogo.isNotEmpty) {
          try {
            return pw.FullPage(
              ignoreMargins: true,
              child: pw.Center(
                child: pw.Opacity(
                  opacity: 0.08,
                  child: pw.Container(
                    width: 350,
                    height: 350,
                    child: pw.Image(
                      pw.MemoryImage(base64Decode(watermarkLogo)),
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
                fontSize: fSize - 1,
                color: secondaryColor,
              ),
            ),
          );
        },
        build: (context) {
          // Local helpers utilizing primaryColor, secondaryColor, and fSize
          pw.Widget infoRow(String label, String value) {
            return _buildInfoRow(label, value, fontSize: fSize);
          }
          pw.Widget sectionHeader(String title) {
            return _buildSectionHeader(title, primaryColor: primaryColor, fontSize: fSize + 1);
          }
          pw.Widget tableHeaderCell(String text, {bool alignLeft = false}) {
            return _buildTableHeaderCell(text, alignLeft: alignLeft, fontSize: fSize - 1);
          }
          pw.Widget tableCell(String text, {bool alignLeft = false, bool isBold = false}) {
            return _buildTableCell(text, alignLeft: alignLeft, isBold: isBold, fontSize: fSize - 1.5);
          }

          // Date formatting
          final dateStr = '${DateTime.now().day} ${AppLocalization.isIndonesian ? _getIndonesianMonth(DateTime.now().month) : _getEnglishMonth(DateTime.now().month)} ${DateTime.now().year}';

          // Helper class for signatures
          final sigCols = <_SignatureCol>[];
          if (activeSettings.ttdOrtuPosition != 'none') {
            sigCols.add(_SignatureCol(
              title: AppLocalization.isIndonesian ? 'Orang Tua/Wali Murid,' : 'Parent / Guardian,',
              subTitle: '',
              name: '',
              position: activeSettings.ttdOrtuPosition,
            ));
          }
          if (activeSettings.ttdWaliPosition != 'none') {
            sigCols.add(_SignatureCol(
              title: AppLocalization.isIndonesian ? 'Wali Kelas' : 'Homeroom Teacher',
              subTitle: AppLocalization.isIndonesian ? 'Mengetahui,' : 'Acknowledged,',
              name: teacherName,
              position: activeSettings.ttdWaliPosition,
              showDate: (activeSettings.ttdWaliPosition == 'right' && activeSettings.ttdKepsekPosition != 'right') ||
                        (activeSettings.ttdWaliPosition == 'center' && activeSettings.ttdKepsekPosition != 'center' && activeSettings.ttdOrtuPosition != 'center'),
            ));
          }
          if (activeSettings.ttdKepsekPosition != 'none') {
            sigCols.add(_SignatureCol(
              title: AppLocalization.isIndonesian ? 'Kepala Sekolah' : 'Headmaster',
              subTitle: AppLocalization.isIndonesian ? 'Mengetahui,' : 'Acknowledged,',
              name: activeSettings.kepsekName,
              nip: activeSettings.kepsekNip,
              position: activeSettings.ttdKepsekPosition,
              showDate: true,
            ));
          }

          pw.Widget buildSigWidget(_SignatureCol col) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              mainAxisSize: pw.MainAxisSize.min,
              children: [
                if (col.showDate) ...[
                  pw.Text(
                    dateStr,
                    style: pw.TextStyle(
                      fontSize: fSize,
                      color: PdfColor.fromInt(0xFF1E293B),
                    ),
                  ),
                  pw.SizedBox(height: 2),
                ] else ...[
                  pw.SizedBox(height: 12),
                ],
                if (col.subTitle.isNotEmpty)
                  pw.Text(
                    col.subTitle,
                    style: pw.TextStyle(
                      fontSize: fSize - 1,
                      color: PdfColor.fromInt(0xFF4B5563),
                    ),
                  ),
                pw.Text(
                  col.title,
                  style: pw.TextStyle(
                    fontSize: fSize,
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
                if (col.name.isNotEmpty) ...[
                  pw.SizedBox(height: 4),
                  pw.Text(
                    col.name,
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: fSize,
                      color: PdfColor.fromInt(0xFF1E293B),
                    ),
                  ),
                ],
                if (col.nip != null && col.nip!.isNotEmpty) ...[
                  pw.SizedBox(height: 2),
                  pw.Text(
                    'NIP. ${col.nip}',
                    style: pw.TextStyle(
                      fontSize: fSize - 1,
                      color: PdfColor.fromInt(0xFF4B5563),
                    ),
                  ),
                ],
              ],
            );
          }

          final leftSigs = sigCols.where((c) => c.position == 'left').map(buildSigWidget).toList();
          final centerSigs = sigCols.where((c) => c.position == 'center').map(buildSigWidget).toList();
          final rightSigs = sigCols.where((c) => c.position == 'right').map(buildSigWidget).toList();

          final Map<String, pw.Widget> sections = {
            'kop': pw.Column(
              mainAxisSize: pw.MainAxisSize.min,
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    // Left Logo
                    if (activeSettings.showLogoLeft && activeSettings.logoLeftBase64 != null)
                      pw.Container(
                        width: 50,
                        height: 50,
                        child: pw.Image(
                          pw.MemoryImage(base64Decode(activeSettings.logoLeftBase64!)),
                          fit: pw.BoxFit.contain,
                        ),
                      )
                    else
                      pw.SizedBox(width: 50, height: 50),

                    // Center text info
                    pw.Expanded(
                      child: pw.Column(
                        mainAxisAlignment: pw.MainAxisAlignment.center,
                        crossAxisAlignment: pw.CrossAxisAlignment.center,
                        children: [
                          pw.Text(
                            activeSettings.headerTitle.toUpperCase(),
                            style: pw.TextStyle(
                              fontSize: fSize + 3,
                              fontWeight: pw.FontWeight.bold,
                              color: primaryColor,
                            ),
                            textAlign: pw.TextAlign.center,
                          ),
                          if (activeSettings.headerSubtitle.isNotEmpty) ...[
                            pw.SizedBox(height: 1),
                            pw.Text(
                              activeSettings.headerSubtitle.toUpperCase(),
                              style: pw.TextStyle(
                                  fontSize: fSize - 1,
                                  color: secondaryColor,
                                ),
                              textAlign: pw.TextAlign.center,
                            ),
                          ],
                          pw.SizedBox(height: 2),
                          pw.Text(
                            activeSettings.schoolName.toUpperCase(),
                            style: pw.TextStyle(
                              fontSize: fSize + 1,
                              fontWeight: pw.FontWeight.bold,
                              color: secondaryColor,
                            ),
                            textAlign: pw.TextAlign.center,
                          ),
                          if (activeSettings.schoolAddress.isNotEmpty) ...[
                            pw.SizedBox(height: 1),
                            pw.Text(
                              activeSettings.schoolAddress,
                              style: pw.TextStyle(
                                fontSize: fSize - 1.5,
                                color: secondaryColor,
                              ),
                              textAlign: pw.TextAlign.center,
                            ),
                          ],
                          if (activeSettings.schoolPhone.isNotEmpty) ...[
                            pw.SizedBox(height: 1),
                            pw.Text(
                              activeSettings.schoolPhone,
                              style: pw.TextStyle(
                                fontSize: fSize - 1.5,
                                color: secondaryColor,
                              ),
                              textAlign: pw.TextAlign.center,
                            ),
                          ],
                        ],
                      ),
                    ),

                    // Right Logo
                    if (activeSettings.showLogoRight && (activeSettings.logoRightBase64 ?? logoBase64) != null)
                      pw.Container(
                        width: 50,
                        height: 50,
                        child: pw.Image(
                          pw.MemoryImage(base64Decode(activeSettings.logoRightBase64 ?? logoBase64!)),
                          fit: pw.BoxFit.contain,
                        ),
                      )
                    else
                      pw.SizedBox(width: 50, height: 50),
                  ],
                ),
                pw.SizedBox(height: 8),
                pw.Container(
                  height: 3,
                  child: pw.Column(
                    children: [
                      pw.Container(height: 1.5, color: primaryColor),
                      pw.SizedBox(height: 1),
                      pw.Container(height: 0.5, color: primaryColor),
                    ],
                  ),
                ),
              ],
            ),
            'info': pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    infoRow(AppLocalization.isIndonesian ? 'Nama Siswa' : 'Student Name', studentName),
                    infoRow(AppLocalization.isIndonesian ? 'NISN / NIS' : 'Student ID / NISN', studentNis),
                    infoRow(AppLocalization.isIndonesian ? 'Sekolah' : 'School', schoolName),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    infoRow(AppLocalization.isIndonesian ? 'Kelas' : 'Class', className),
                    infoRow(AppLocalization.isIndonesian ? 'Semester' : 'Semester', AppLocalization.isIndonesian ? semester : semester.replaceAll('Ganjil', 'Odd').replaceAll('Genap', 'Even')),
                    infoRow(AppLocalization.isIndonesian ? 'Tahun Ajaran' : 'Academic Year', yearInfo),
                  ],
                ),
              ],
            ),
            'attitude': pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              mainAxisSize: pw.MainAxisSize.min,
              children: [
                sectionHeader(AppLocalization.isIndonesian ? 'A. PENILAIAN SIKAP' : 'A. ATTITUDE ASSESSMENT'),
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
                        tableHeaderCell(AppLocalization.isIndonesian ? 'Aspek Sikap' : 'Attitude Aspect'),
                        tableHeaderCell(AppLocalization.isIndonesian ? 'Predikat' : 'Grade'),
                        tableHeaderCell(AppLocalization.isIndonesian ? 'Deskripsi / Keterangan' : 'Description / Notes'),
                      ],
                    ),
                    ...List.generate(attitudeAspects.length, (index) {
                      final aspect = attitudeAspects[index];
                      final aspectName = aspect['name']?.toString() ?? '';
                      final isSpiritual = aspectName.toLowerCase().contains('spiritual');
                      final isSocial = aspectName.toLowerCase().contains('sosial') || aspectName.toLowerCase().contains('social');

                      if (isSpiritual && !activeSettings.showSpiritualAttitude) return null;
                      if (isSocial) return null;

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
                          tableCell('${index + 1}. $name', alignLeft: true),
                          tableCell(pred, isBold: true),
                          tableCell(
                            desc.isEmpty ? defaultDesc : desc,
                            alignLeft: true,
                          ),
                        ],
                      );
                    }).whereType<pw.TableRow>().toList(),
                  ],
                ),
              ],
            ),
            'academic': pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              mainAxisSize: pw.MainAxisSize.min,
              children: [
                sectionHeader(AppLocalization.isIndonesian ? 'B. PENILAIAN AKADEMIK' : 'B. ACADEMIC ASSESSMENT'),
                pw.SizedBox(height: 6),
                pw.Table(
                  border: pw.TableBorder.all(
                    color: PdfColor(0.796, 0.835, 0.882, 0.90),
                    width: 0.5,
                  ),
                  columnWidths: {
                    for (int i = 0; i < activeSettings.academicColWidths.length; i++)
                      i: pw.FractionColumnWidth(activeSettings.academicColWidths[i]),
                  },
                  children: [
                    // Header
                    pw.TableRow(
                      decoration: null,
                      children: [
                        tableHeaderCell('No'),
                        tableHeaderCell(AppLocalization.isIndonesian ? 'Mata Pelajaran' : 'Subject', alignLeft: true),
                        tableHeaderCell('KKM'),
                        tableHeaderCell(AppLocalization.isIndonesian ? 'Nilai' : 'Grade'),
                        tableHeaderCell(AppLocalization.isIndonesian ? 'Predikat' : 'Predicate'),
                        tableHeaderCell(
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
                          tableCell((idx + 1).toString()),
                          tableCell(name, alignLeft: true, isBold: true),
                          tableCell(kkm),
                          tableCell(scoreStr, isBold: true),
                          tableCell(pred, isBold: true),
                          tableCell(desc, alignLeft: true),
                        ],
                      );
                    }),
                  ],
                ),
              ],
            ),
            'legend': pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                sectionHeader(AppLocalization.isIndonesian ? 'KETERANGAN PREDIKAT' : 'GRADE PREDICATE LEGEND'),
                pw.SizedBox(height: 6),
                pw.Table(
                  border: pw.TableBorder.all(
                    color: PdfColor(0.796, 0.835, 0.882, 0.90),
                    width: 0.5,
                  ),
                  columnWidths: {
                    for (int i = 0; i < activeSettings.legendColWidths.length; i++)
                      i: pw.FractionColumnWidth(activeSettings.legendColWidths[i]),
                  },
                  children: [
                    pw.TableRow(
                      decoration: null,
                      children: [
                        tableHeaderCell(AppLocalization.isIndonesian ? 'Rentang Nilai' : 'Score Range'),
                        tableHeaderCell(AppLocalization.isIndonesian ? 'Predikat' : 'Predicate'),
                      ],
                    ),
                    pw.TableRow(
                      children: [
                        tableCell('${gt['aplus'] ?? 95} - 100'),
                        tableCell('A+', isBold: true),
                      ],
                    ),
                    pw.TableRow(
                      children: [
                        tableCell('${gt['a'] ?? 90} - ${(gt['aplus'] ?? 95) - 1}'),
                        tableCell('A', isBold: true),
                      ],
                    ),
                    pw.TableRow(
                      children: [
                        tableCell('${gt['aminus'] ?? 85} - ${(gt['a'] ?? 90) - 1}'),
                        tableCell('A-', isBold: true),
                      ],
                    ),
                    pw.TableRow(
                      children: [
                        tableCell('${gt['bplus'] ?? 80} - ${(gt['aminus'] ?? 85) - 1}'),
                        tableCell('B+', isBold: true),
                      ],
                    ),
                    pw.TableRow(
                      children: [
                        tableCell('${gt['b'] ?? 75} - ${(gt['bplus'] ?? 80) - 1}'),
                        tableCell('B', isBold: true),
                      ],
                    ),
                    pw.TableRow(
                      children: [
                        tableCell('${gt['bminus'] ?? 70} - ${(gt['b'] ?? 75) - 1}'),
                        tableCell('B-', isBold: true),
                      ],
                    ),
                    pw.TableRow(
                      children: [
                        tableCell('${gt['cplus'] ?? 65} - ${(gt['bminus'] ?? 70) - 1}'),
                        tableCell('C+', isBold: true),
                      ],
                    ),
                    pw.TableRow(
                      children: [
                        tableCell('${gt['c'] ?? 60} - ${(gt['cplus'] ?? 65) - 1}'),
                        tableCell('C', isBold: true),
                      ],
                    ),
                    pw.TableRow(
                      children: [
                        tableCell('${gt['cminus'] ?? 55} - ${(gt['c'] ?? 60) - 1}'),
                        tableCell('C-', isBold: true),
                      ],
                    ),
                    pw.TableRow(
                      children: [
                        tableCell('< ${gt['cminus'] ?? 55}'),
                        tableCell('D', isBold: true),
                      ],
                    ),
                  ],
                ),
              ],
            ),
            'attendance': pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                sectionHeader(AppLocalization.isIndonesian ? 'C. KETIDAKHADIRAN' : 'C. ABSENCE / ATTENDANCE'),
                pw.SizedBox(height: 6),
                pw.Table(
                  border: pw.TableBorder.all(
                    color: PdfColor(0.796, 0.835, 0.882, 0.90),
                    width: 0.5,
                  ),
                  columnWidths: {
                    for (int i = 0; i < activeSettings.attendanceColWidths.length; i++)
                      i: pw.FractionColumnWidth(activeSettings.attendanceColWidths[i]),
                  },
                  children: [
                    pw.TableRow(
                      decoration: null,
                      children: [
                        tableHeaderCell(
                          AppLocalization.isIndonesian ? 'Alasan Absensi' : 'Absence Reason',
                          alignLeft: true,
                        ),
                        tableHeaderCell(AppLocalization.isIndonesian ? 'Jumlah' : 'Total'),
                      ],
                    ),
                    pw.TableRow(
                      children: [
                        tableCell(AppLocalization.isIndonesian ? '1. Sakit (S)' : '1. Sick (S)', alignLeft: true),
                        tableCell(AppLocalization.isIndonesian ? '$sakit Hari' : '$sakit Days'),
                      ],
                    ),
                    pw.TableRow(
                      children: [
                        tableCell(AppLocalization.isIndonesian ? '2. Izin (I)' : '2. Permit (P)', alignLeft: true),
                        tableCell(AppLocalization.isIndonesian ? '$izin Hari' : '$izin Days'),
                      ],
                    ),
                    pw.TableRow(
                      children: [
                        tableCell(
                          AppLocalization.isIndonesian ? '3. Tanpa Keterangan (A)' : '3. Unexcused Absence (A)',
                          alignLeft: true,
                        ),
                        tableCell(AppLocalization.isIndonesian ? '$alpa Hari' : '$alpa Days'),
                      ],
                    ),
                  ],
                ),
              ],
            ),
            'notes': pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                sectionHeader(AppLocalization.isIndonesian ? 'D. CATATAN WALI KELAS' : 'D. HOMEROOM TEACHER NOTES'),
                pw.SizedBox(height: 6),
                pw.Container(
                  width: double.infinity,
                  height: 60,
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
                      fontSize: fSize,
                      height: 1.4,
                      color: PdfColor.fromInt(0xFF1E293B),
                    ),
                  ),
                ),
              ],
            ),
            'signatures': pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                if (leftSigs.isNotEmpty)
                  pw.Column(
                    mainAxisSize: pw.MainAxisSize.min,
                    children: leftSigs.map((w) => pw.Padding(padding: const pw.EdgeInsets.only(bottom: 12), child: w)).toList(),
                  )
                else
                  pw.SizedBox(width: 140),

                if (centerSigs.isNotEmpty)
                  pw.Column(
                    mainAxisSize: pw.MainAxisSize.min,
                    children: centerSigs.map((w) => pw.Padding(padding: const pw.EdgeInsets.only(bottom: 12), child: w)).toList(),
                  )
                else
                  pw.SizedBox(width: 140),

                if (rightSigs.isNotEmpty)
                  pw.Column(
                    mainAxisSize: pw.MainAxisSize.min,
                    children: rightSigs.map((w) => pw.Padding(padding: const pw.EdgeInsets.only(bottom: 12), child: w)).toList(),
                  )
                else
                  pw.SizedBox(width: 140),
              ],
            ),
          };

          final List<pw.Widget> stackChildren = [];

          void addPositioned(String id, pw.Widget child, bool isVisible) {
            if (!isVisible) return;
            final pos = activeSettings.elementPositions[id] ?? [0, 0, 12, 5];
            final int gridX = pos[0];
            final int gridY = pos[1];
            final int gridW = pos[2];

            final double colWidth = 523.27 / 12.0;
            const double rowHeight = 11.0;

            stackChildren.add(
              pw.Positioned(
                left: gridX * colWidth,
                top: gridY * rowHeight,
                child: pw.SizedBox(
                  width: gridW * colWidth,
                  child: child,
                ),
              ),
            );
          }

          addPositioned('kop', sections['kop']!, true);
          addPositioned('info', sections['info']!, true);
          addPositioned('attitude', sections['attitude']!, activeSettings.showSpiritualAttitude);
          addPositioned('academic', sections['academic']!, true);
          addPositioned('legend', sections['legend']!, activeSettings.showPredikat);
          addPositioned('attendance', sections['attendance']!, activeSettings.showAttendance);
          addPositioned('notes', sections['notes']!, activeSettings.showNotes);
          addPositioned('signatures', sections['signatures']!, true);

          return [
            pw.Stack(
              children: stackChildren,
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
  static pw.Widget _buildInfoRow(String label, String value, {double? fontSize}) {
    final double f = fontSize ?? 9;
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
                fontSize: f,
                color: PdfColor.fromInt(0xFF64748B),
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
          pw.Text(': ', style: pw.TextStyle(fontSize: f)),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: f,
              fontWeight: pw.FontWeight.bold,
              color: PdfColor.fromInt(0xFF1E293B),
            ),
          ),
        ],
      ),
    );
  }

  /// Helper judul section
  static pw.Widget _buildSectionHeader(String title, {PdfColor? primaryColor, double? fontSize}) {
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
            decoration: pw.BoxDecoration(
              color: primaryColor ?? PdfColor.fromInt(0xFF4F46E5), // dynamic primary color
              borderRadius: const pw.BorderRadius.only(
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
                  fontSize: fontSize ?? 10,
                  fontWeight: pw.FontWeight.bold,
                  color: primaryColor ?? PdfColor.fromInt(0xFF312E81),
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
    double? fontSize,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(6),
      alignment: alignLeft ? pw.Alignment.centerLeft : pw.Alignment.center,
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontWeight: pw.FontWeight.bold,
          fontSize: fontSize ?? 8,
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
    double? fontSize,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(6),
      alignment: alignLeft ? pw.Alignment.centerLeft : pw.Alignment.center,
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: fontSize ?? 8,
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
    RaporPdfSettings? settings,
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
      settings: settings,
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Rapor_${studentName.replaceAll(' ', '_')}.pdf',
    );
  }
}

class _SignatureCol {
  final String title;
  final String subTitle;
  final String name;
  final String? nip;
  final String position;
  final bool showDate;

  _SignatureCol({
    required this.title,
    required this.subTitle,
    required this.name,
    this.nip,
    required this.position,
    this.showDate = false,
  });
}
