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

    var activeSettings = settings ?? RaporPdfSettings.defaultSettings(schoolName);

    // Migration logic for older databases where Kop height is < 8 or Info starts before row 9
    final positions = Map<String, List<int>>.from(activeSettings.elementPositions);
    final int oldKopHeight = positions['kop'] != null ? positions['kop']![3] : 6;
    final int oldInfoStart = positions['info'] != null ? positions['info']![1] : 7;

    if (oldKopHeight < 8 || oldInfoStart < 9) {
      positions['kop'] = [0, 0, 12, 8];
      positions['info'] = [0, 9, 12, 3];
      positions['attitude'] = [0, 14, 12, 5];
      positions['academic'] = [0, 20, 12, 11];
      positions['legend'] = [0, 32, 5, 11];
      positions['attendance'] = [6, 32, 6, 5];
      positions['notes'] = [6, 38, 6, 5];
      positions['signatures'] = [0, 44, 12, 6];
      
      activeSettings = activeSettings.copyWith(elementPositions: positions);
    }

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

    // Date text for sig_date element
    final sigDateDisplay = activeSettings.sigDateText.isNotEmpty
        ? '${activeSettings.sigDateText}, $dateStr'
        : 'Kota, $dateStr';

    pw.Widget buildSigColWidget({required String title, required String name, required String nip}) {
      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(
              fontSize: fSize,
              color: PdfColor.fromInt(0xFF1E293B),
              fontWeight: pw.FontWeight.bold,
            ),
            textAlign: pw.TextAlign.center,
          ),
          pw.SizedBox(height: 48),
          pw.Container(
            width: 130,
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
            name.isNotEmpty ? name : ' ',
            style: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              fontSize: fSize,
              color: PdfColor.fromInt(0xFF1E293B),
            ),
            textAlign: pw.TextAlign.center,
          ),
          if (nip.isNotEmpty)
            pw.Text(
              nip,
              style: pw.TextStyle(
                fontSize: fSize - 1,
                color: PdfColor.fromInt(0xFF4B5563),
              ),
              textAlign: pw.TextAlign.center,
            ),
        ],
      );
    }

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
                        fontSize: activeSettings.titleFontSize.toDouble(),
                        fontWeight: activeSettings.titleIsBold ? pw.FontWeight.bold : pw.FontWeight.normal,
                        color: PdfColor(primaryColor.red, primaryColor.green, primaryColor.blue, activeSettings.titleOpacity),
                      ),
                      textAlign: pw.TextAlign.center,
                    ),
                    if (activeSettings.headerSubtitle.isNotEmpty) ...[
                      pw.SizedBox(height: 1),
                      pw.Text(
                        activeSettings.headerSubtitle.toUpperCase(),
                        style: pw.TextStyle(
                            fontSize: activeSettings.subtitleFontSize.toDouble(),
                            fontWeight: activeSettings.subtitleIsBold ? pw.FontWeight.bold : pw.FontWeight.normal,
                            color: PdfColor(primaryColor.red, primaryColor.green, primaryColor.blue, activeSettings.subtitleOpacity),
                          ),
                        textAlign: pw.TextAlign.center,
                      ),
                    ],
                    pw.SizedBox(height: 2),
                    pw.Text(
                      activeSettings.schoolName.toUpperCase(),
                      style: pw.TextStyle(
                        fontSize: activeSettings.schoolNameFontSize.toDouble(),
                        fontWeight: activeSettings.schoolNameIsBold ? pw.FontWeight.bold : pw.FontWeight.normal,
                        color: PdfColor(primaryColor.red, primaryColor.green, primaryColor.blue, activeSettings.schoolNameOpacity),
                      ),
                      textAlign: pw.TextAlign.center,
                    ),
                    if (activeSettings.schoolAddress.isNotEmpty) ...[
                      pw.SizedBox(height: 1),
                      pw.Text(
                        activeSettings.schoolAddress,
                        style: pw.TextStyle(
                          fontSize: activeSettings.addressFontSize.toDouble(),
                          fontWeight: activeSettings.addressIsBold ? pw.FontWeight.bold : pw.FontWeight.normal,
                          color: PdfColor(primaryColor.red, primaryColor.green, primaryColor.blue, activeSettings.addressOpacity),
                        ),
                        textAlign: pw.TextAlign.center,
                      ),
                    ],
                    if (activeSettings.schoolPhone.isNotEmpty) ...[
                      pw.SizedBox(height: 1),
                      pw.Text(
                        activeSettings.schoolPhone,
                        style: pw.TextStyle(
                          fontSize: activeSettings.phoneFontSize.toDouble(),
                          fontWeight: activeSettings.phoneIsBold ? pw.FontWeight.bold : pw.FontWeight.normal,
                          color: PdfColor(primaryColor.red, primaryColor.green, primaryColor.blue, activeSettings.phoneOpacity),
                        ),
                        textAlign: pw.TextAlign.center,
                      ),
                    ],
                  ],
                ),
              ),

              // Right Logo
              if (activeSettings.showLogoRight && activeSettings.logoRightBase64 != null)
                pw.Container(
                  width: 50,
                  height: 50,
                  child: pw.Image(
                    pw.MemoryImage(base64Decode(activeSettings.logoRightBase64!)),
                    fit: pw.BoxFit.contain,
                  ),
                )
              else
                pw.SizedBox(width: 50, height: 50),
            ],
          ),
          pw.SizedBox(height: 6),
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
          pw.SizedBox(height: 8),
          pw.Align(
            alignment: pw.Alignment.center,
            child: pw.Text(
              'LAPORAN PENILAIAN HASIL BELAJAR SISWA',
              style: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
                color: primaryColor,
              ),
              textAlign: pw.TextAlign.center,
            ),
          ),
        ],
      ),
      'info': pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          infoRow(AppLocalization.isIndonesian ? 'Nama Siswa' : 'Student Name', studentName),
          infoRow(AppLocalization.isIndonesian ? 'NISN / NIS' : 'Student ID / NISN', studentNis),
          infoRow(AppLocalization.isIndonesian ? 'Kelas' : 'Class', className),
          infoRow(AppLocalization.isIndonesian ? 'Sekolah' : 'School', schoolName),
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
            columnWidths: const {
              0: pw.FractionColumnWidth(0.2),
              1: pw.FractionColumnWidth(0.1),
              2: pw.FractionColumnWidth(0.7),
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
              }),
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
      'sig_date': pw.Text(
        sigDateDisplay,
        style: pw.TextStyle(
          fontSize: fSize,
          color: PdfColor.fromInt(0xFF1E293B),
        ),
        textAlign: pw.TextAlign.center,
      ),
      'sig_ortu': buildSigColWidget(
        title: AppLocalization.isIndonesian ? 'Orang Tua/Wali Murid,' : 'Parent / Guardian,',
        name: '',
        nip: '',
      ),
      'sig_wali': buildSigColWidget(
        title: AppLocalization.isIndonesian ? 'Wali Kelas,' : 'Homeroom Teacher,',
        name: teacherName,
        nip: '',
      ),
      'sig_kepsek': buildSigColWidget(
        title: AppLocalization.isIndonesian ? 'Kepala Sekolah,' : 'Headmaster,',
        name: activeSettings.kepsekName,
        nip: activeSettings.kepsekNip.isNotEmpty ? 'NIP. ${activeSettings.kepsekNip}' : '',
      ),
    };

    // Calculate actual heights (in grid rows) dynamically
    final Map<String, int> actualHeights = {};
    actualHeights['kop'] = activeSettings.elementPositions['kop']![3];
    actualHeights['info'] = activeSettings.elementPositions['info']![3];

    actualHeights['attitude'] = activeSettings.showSpiritualAttitude ? (4 + attitudeAspects.length * 2) : 0;
    actualHeights['academic'] = 4 + subjectScores.length * 2;
    actualHeights['legend'] = activeSettings.showPredikat ? 24 : 0;
    actualHeights['attendance'] = activeSettings.showAttendance ? 10 : 0;
    actualHeights['notes'] = activeSettings.showNotes ? 9 : 0;
    actualHeights['sig_date'] = activeSettings.showSigDate ? (activeSettings.elementPositions['sig_date']?[3] ?? 2) : 0;
    actualHeights['sig_ortu'] = activeSettings.showSigOrtu ? (activeSettings.elementPositions['sig_ortu']?[3] ?? 5) : 0;
    actualHeights['sig_wali'] = activeSettings.showSigWali ? (activeSettings.elementPositions['sig_wali']?[3] ?? 5) : 0;
    actualHeights['sig_kepsek'] = activeSettings.showSigKepsek ? (activeSettings.elementPositions['sig_kepsek']?[3] ?? 5) : 0;

    // Filter visible keys
    final List<String> visibleKeys = ['kop', 'info', 'attitude', 'academic', 'legend', 'attendance', 'notes', 'sig_date', 'sig_ortu', 'sig_wali', 'sig_kepsek']
        .where((key) {
          if (key == 'attitude') return activeSettings.showSpiritualAttitude;
          if (key == 'legend') return activeSettings.showPredikat;
          if (key == 'attendance') return activeSettings.showAttendance;
          if (key == 'notes') return activeSettings.showNotes;
          if (key == 'sig_date') return activeSettings.showSigDate;
          if (key == 'sig_ortu') return activeSettings.showSigOrtu;
          if (key == 'sig_wali') return activeSettings.showSigWali;
          if (key == 'sig_kepsek') return activeSettings.showSigKepsek;
          return true;
        }).toList();

    // Helper to calculate gap based on original element positions
    double getGap(String above, String below) {
      final posAbove = activeSettings.elementPositions[above] ?? [0, 0, 12, 5];
      final posBelow = activeSettings.elementPositions[below] ?? [0, 0, 12, 5];
      final int endAbove = posAbove[1] + posAbove[3];
      final int startBelow = posBelow[1];
      return (startBelow > endAbove) ? (startBelow - endAbove).toDouble() * 11.0 : 0.0;
    }

    final Map<String, double> y = {};
    y['kop'] = 0.0;

    // 1. Info Y
    y['info'] = y['kop']! + (actualHeights['kop'] ?? 8) * 11.0 + getGap('kop', 'info');

    // 2. Attitude Y
    double currentBottom = y['info']! + (actualHeights['info'] ?? 3) * 11.0;
    if (activeSettings.showSpiritualAttitude) {
      y['attitude'] = currentBottom + getGap('info', 'attitude');
      currentBottom = y['attitude']! + (actualHeights['attitude'] ?? 5) * 11.0;
    }

    // 3. Academic Y
    final String lastAboveAcademic = activeSettings.showSpiritualAttitude ? 'attitude' : 'info';
    y['academic'] = currentBottom + getGap(lastAboveAcademic, 'academic');
    final double academicBottom = y['academic']! + (actualHeights['academic'] ?? 11) * 11.0;

    // 4. Parallel Left and Right Columns Y
    // Left column: legend
    double legendBottom = academicBottom;
    if (activeSettings.showPredikat) {
      y['legend'] = academicBottom + getGap('academic', 'legend');
      legendBottom = y['legend']! + (actualHeights['legend'] ?? 11) * 11.0;
    }

    // Right column: attendance and notes
    double rightBottom = academicBottom;
    if (activeSettings.showAttendance) {
      y['attendance'] = academicBottom + getGap('academic', 'attendance');
      rightBottom = y['attendance']! + (actualHeights['attendance'] ?? 5) * 11.0;
    }
    if (activeSettings.showNotes) {
      final double gapAbove = activeSettings.showAttendance ? getGap('attendance', 'notes') : getGap('academic', 'notes');
      y['notes'] = rightBottom + gapAbove;
      rightBottom = y['notes']! + (actualHeights['notes'] ?? 5) * 11.0;
    }

    // 5. Signature Y coordinates — each sig element is positioned independently based on elementPositions
    final double maxMiddleBottom = (legendBottom > rightBottom) ? legendBottom : rightBottom;
    final int maxOriginalMiddleEnd = () {
      int legendEnd = (activeSettings.elementPositions['legend']?[1] ?? 32) + (activeSettings.elementPositions['legend']?[3] ?? 11);
      int notesEnd = (activeSettings.elementPositions['notes']?[1] ?? 38) + (activeSettings.elementPositions['notes']?[3] ?? 5);
      return legendEnd > notesEnd ? legendEnd : notesEnd;
    }();

    // For each sig element, Y = maxMiddleBottom + offset based on their grid row relative to maxOriginalMiddleEnd
    for (final sigKey in ['sig_date', 'sig_ortu', 'sig_wali', 'sig_kepsek']) {
      if (activeSettings.elementPositions.containsKey(sigKey)) {
        final int sigGridY = activeSettings.elementPositions[sigKey]![1];
        final double sigGap = (sigGridY > maxOriginalMiddleEnd)
            ? (sigGridY - maxOriginalMiddleEnd).toDouble() * 11.0
            : 0.0;
        y[sigKey] = maxMiddleBottom + sigGap;
      }
    }

    // Sort visible keys by calculated Y coordinate so we page-split sequentially
    visibleKeys.sort((a, b) => y[a]!.compareTo(y[b]!));

    // Split elements across multiple pages dynamically
    final Map<String, int> elementPages = {};
    final Map<String, double> elementLocalY = {};

    const double pageHeightLimit = 700.0; // max printable content height in points
    int currentPage = 0;
    double pageStartY = 0.0;

    for (var key in visibleKeys) {
      final double yInPoints = y[key]!;
      final double hInPoints = (actualHeights[key] ?? (activeSettings.elementPositions[key]?[3] ?? 5)) * 11.0;

      // Move to next page if element bottom exceeds page limit and it's not the first element on the current page
      if (yInPoints + hInPoints - pageStartY > pageHeightLimit && yInPoints > pageStartY) {
        currentPage++;
        pageStartY = yInPoints;
      }

      elementPages[key] = currentPage;
      elementLocalY[key] = yInPoints - pageStartY;
    }

    final int totalPages = currentPage + 1;

    for (int p = 0; p < totalPages; p++) {
      pdf.addPage(
        pw.Page(
          pageTheme: pageTheme,
          build: (context) {
            final List<String> pageKeys = visibleKeys.where((key) => elementPages[key] == p).toList();
            final List<pw.Widget> pageChildren = [];
            final Set<String> processedKeys = {};

            for (int i = 0; i < pageKeys.length; i++) {
              final key = pageKeys[i];
              if (processedKeys.contains(key)) continue;

              // Calculate gap to next element
              double gapAfter = 15.0;
              if (i < pageKeys.length - 1) {
                final nextKey = pageKeys[i + 1];
                gapAfter = getGap(key, nextKey);
              }

              if (key == 'kop') {
                pageChildren.add(sections['kop']!);
                pageChildren.add(pw.SizedBox(height: gapAfter));
                processedKeys.add('kop');
              } else if (key == 'info') {
                pageChildren.add(sections['info']!);
                pageChildren.add(pw.SizedBox(height: gapAfter));
                processedKeys.add('info');
              } else if (key == 'attitude') {
                pageChildren.add(sections['attitude']!);
                pageChildren.add(pw.SizedBox(height: gapAfter));
                processedKeys.add('attitude');
              } else if (key == 'academic') {
                pageChildren.add(sections['academic']!);
                pageChildren.add(pw.SizedBox(height: gapAfter));
                processedKeys.add('academic');
              } else if (key == 'legend' || key == 'attendance' || key == 'notes') {
                final bool hasLegend = pageKeys.contains('legend') && activeSettings.showPredikat;
                final bool hasAttendance = pageKeys.contains('attendance') && activeSettings.showAttendance;
                final bool hasNotes = pageKeys.contains('notes') && activeSettings.showNotes;

                pageChildren.add(
                  pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      if (hasLegend)
                        pw.Expanded(
                          flex: 5,
                          child: sections['legend']!,
                        ),
                      if (hasLegend && (hasAttendance || hasNotes))
                        pw.SizedBox(width: 15),
                      if (hasAttendance || hasNotes)
                        pw.Expanded(
                          flex: 6,
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              if (hasAttendance) ...[
                                sections['attendance']!,
                                pw.SizedBox(height: 10),
                              ],
                              if (hasNotes)
                                sections['notes']!,
                            ],
                          ),
                        ),
                    ],
                  ),
                );

                pageChildren.add(pw.SizedBox(height: gapAfter));

                if (hasLegend) processedKeys.add('legend');
                if (hasAttendance) processedKeys.add('attendance');
                if (hasNotes) processedKeys.add('notes');
              } else if (key == 'sig_date' || key == 'sig_ortu' || key == 'sig_wali' || key == 'sig_kepsek') {
                // Group all signature elements on this page and render using Stack
                final pageSigs = pageKeys.where((k) => (k == 'sig_date' || k == 'sig_ortu' || k == 'sig_wali' || k == 'sig_kepsek') && !processedKeys.contains(k)).toList();
                if (pageSigs.isNotEmpty) {
                  int minY = 9999;
                  int maxY = 0;
                  for (final sigKey in pageSigs) {
                    final pos = activeSettings.elementPositions[sigKey] ?? [0, 44, 4, 5];
                    final int startY = pos[1];
                    final int endY = pos[1] + pos[3];
                    if (startY < minY) minY = startY;
                    if (endY > maxY) maxY = endY;
                  }

                  final double groupHeight = (maxY - minY).toDouble() * 11.0 + 45.0;
                  final double printableWidth = pageFormat.availableWidth;

                  final List<pw.Widget> stackedWidgets = [];
                  for (final sigKey in pageSigs) {
                    final pos = activeSettings.elementPositions[sigKey] ?? [0, 44, 4, 5];
                    final double left = (pos[0].toDouble() / 12.0) * printableWidth;
                    final double top = (pos[1] - minY).toDouble() * 11.0;
                    final double w = (pos[2].toDouble() / 12.0) * printableWidth;
                    final double h = pos[3].toDouble() * 11.0 + 45.0;

                    stackedWidgets.add(
                      pw.Positioned(
                        left: left,
                        top: top,
                        child: pw.SizedBox(
                          width: w,
                          height: h,
                          child: pw.Container(
                            width: w,
                            height: h,
                            alignment: pw.Alignment.topCenter,
                            child: sections[sigKey]!,
                          ),
                        ),
                      ),
                    );
                  }

                  pageChildren.add(
                    pw.Container(
                      width: printableWidth,
                      height: groupHeight,
                      child: pw.Stack(
                        children: stackedWidgets,
                      ),
                    ),
                  );

                  pageChildren.add(pw.SizedBox(height: gapAfter));
                  processedKeys.addAll(pageSigs);
                }
              }
            }

            // Remove trailing spacer if any
            if (pageChildren.isNotEmpty && pageChildren.last is pw.SizedBox) {
              pageChildren.removeLast();
            }

            return pw.Stack(
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                  children: pageChildren,
                ),
                pw.Positioned(
                  bottom: 0,
                  right: 0,
                  child: pw.Text(
                    AppLocalization.isIndonesian
                        ? 'Halaman ${p + 1} dari $totalPages'
                        : 'Page ${p + 1} of $totalPages',
                    style: pw.TextStyle(
                      fontSize: fSize - 1,
                      color: secondaryColor,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      );
    }

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


