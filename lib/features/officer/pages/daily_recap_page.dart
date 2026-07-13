import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter/services.dart';
import 'package:excel/excel.dart' hide Border;
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:sys_mng_school/core/localization/app_localization.dart';

import '../../../core/services/session_service.dart';
import '../../authentication/widgets/auth_background.dart';
import '../data/officer_repository.dart';
import 'monthly_recap_page.dart';

class DailyRecapPage extends StatefulWidget {
  const DailyRecapPage({super.key});

  @override
  State<DailyRecapPage> createState() => _DailyRecapPageState();
}

class _DailyRecapPageState extends State<DailyRecapPage> {
  final OfficerRepository _repo = OfficerRepository();
  DateTime _selectedDate = DateTime.now();
  List<Map<String, dynamic>> _recapData = [];
  bool _isLoading = false;
  bool _isAccessChecking = false;
  bool _isAccessGranted = true;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _accessSubscription;
  bool _lockDialogShown = false;

  @override
  void initState() {
    super.initState();
    _listenToAccess();
  }

  @override
  void dispose() {
    _accessSubscription?.cancel();
    super.dispose();
  }

  void _listenToAccess() {
    final user = SessionService.currentUser;
    if (user?.role != 'school_admin' && user?.role != 'tu') {
      // Non-restricted roles: load data directly
      setState(() {
        _isAccessChecking = false;
        _isAccessGranted = true;
      });
      _fetchData();
      return;
    }

    setState(() => _isAccessChecking = true);

    _accessSubscription = FirebaseFirestore.instance
        .collection('schools')
        .doc(user!.schoolId)
        .snapshots()
        .listen((snap) {
      if (!mounted) return;
      final bool enabled = snap.data()?['enableStudentAttendanceRecap'] ?? false;

      if (!enabled) {
        setState(() {
          _isAccessChecking = false;
          _isAccessGranted = false;
        });
        if (!_lockDialogShown) {
          _lockDialogShown = true;
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              backgroundColor: const Color(0xFF151026),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  const Icon(Icons.lock_rounded, color: Colors.amber),
                  const SizedBox(width: 8),
                  Text(
                    AppLocalization.isIndonesian ? 'Fitur Terkunci' : 'Feature Locked',
                    style: const TextStyle(color: Colors.white),
                  ),
                ],
              ),
              content: Text(
                AppLocalization.isIndonesian
                    ? 'Fitur Rekap Absensi Siswa dinonaktifkan oleh Super Admin. Silakan hubungi Super Admin untuk mengaktifkan akses.'
                    : 'The Student Attendance Recap feature is disabled by the Super Admin. Please contact Super Admin to enable access.',
                style: const TextStyle(color: Colors.white70),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Get.back();
                  },
                  child: const Text('OK', style: TextStyle(color: Color(0xFF8B5CF6))),
                ),
              ],
            ),
          ).then((_) => _lockDialogShown = false);
        }
      } else {
        final wasBlocked = !_isAccessGranted;
        setState(() {
          _isAccessChecking = false;
          _isAccessGranted = true;
        });
        if (wasBlocked) {
          // Re-enabled: reload data
          _fetchData();
        } else if (_recapData.isEmpty && !_isLoading) {
          _fetchData();
        }
      }
    }, onError: (e) {
      // On error, grant access to prevent false lockouts
      setState(() {
        _isAccessChecking = false;
        _isAccessGranted = true;
      });
      _fetchData();
    });
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      final user = SessionService.currentUser!;
      final data = await _repo.getDailyRecap(user.schoolId, _selectedDate);
      setState(() {
        _recapData = data;
        // Sort: attended (hadir/terlambat/izin/sakit) first by check-in time desc,
        // then absent (alfa) sorted A-Z by name
        final attended = _recapData
            .where((e) => (e['status'] ?? 'alfa') != 'alfa')
            .toList()
          ..sort((a, b) {
            final ta = a['checkInTime'] ?? a['timestamp'];
            final tb = b['checkInTime'] ?? b['timestamp'];
            if (ta == null && tb == null) return 0;
            if (ta == null) return 1;
            if (tb == null) return -1;
            return (tb as Timestamp).compareTo(ta as Timestamp);
          });
        final absent = _recapData
            .where((e) => (e['status'] ?? 'alfa') == 'alfa')
            .toList()
          ..sort((a, b) =>
              (a['studentName']?.toString().toLowerCase() ?? '')
                  .compareTo(b['studentName']?.toString().toLowerCase() ?? ''));
        _recapData = [...attended, ...absent];
      });
    } catch (e) {
      Get.snackbar('Error', e.toString(), backgroundColor: Colors.red, colorText: Colors.white);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
      _fetchData();
    }
  }

  Future<void> _exportPdf() async {
    if (!mounted) return;
    final ctx = context;
    final user = SessionService.currentUser!;
    final schoolDoc = await FirebaseFirestore.instance
        .collection('schools')
        .doc(user.schoolId)
        .get();
    final schoolName = schoolDoc.data()?['namaSekolah'] ?? 'Sekolah';
    final dateLabel = DateFormat(
      AppLocalization.isIndonesian ? 'dd MMMM yyyy' : 'MMMM dd, yyyy',
    ).format(_selectedDate);
    final recapSnapshot = List<Map<String, dynamic>>.from(_recapData)
      ..sort((a, b) => (a['studentName']?.toString().toLowerCase() ?? '')
          .compareTo(b['studentName']?.toString().toLowerCase() ?? ''));
    if (!mounted) return;

      Future<Uint8List> buildPdf(PdfPageFormat format) async {
        final pdf = pw.Document();
        pdf.addPage(
          pw.MultiPage(
            pageFormat: format,
            margin: const pw.EdgeInsets.all(32),
            build: (pw.Context ctx) => [
              // ── Header banner ──────────────────────────────────────
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                      schoolName,
                      style: pw.TextStyle(
                        fontSize: 13,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.grey800,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      AppLocalization.isIndonesian
                          ? 'Laporan Kehadiran Harian Siswa'
                          : 'Student Daily Attendance Report',
                      style: pw.TextStyle(
                        fontSize: 20,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.black,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      '${AppLocalization.isIndonesian ? "Tanggal" : "Date"}: $dateLabel',
                      style: const pw.TextStyle(
                        fontSize: 11,
                        color: PdfColors.grey600,
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 20),
                // ── Summary chips ──────────────────────────────────────
                pw.Row(
                  children: [
                    _pdfChip(
                      AppLocalization.isIndonesian ? 'Total Siswa' : 'Total Students',
                      recapSnapshot.length.toString(),
                      PdfColors.indigo700,
                    ),
                    pw.SizedBox(width: 8),
                    _pdfChip(
                      AppLocalization.isIndonesian ? 'Hadir' : 'Present',
                      recapSnapshot.where((e) => (e['status'] ?? '') == 'hadir').length.toString(),
                      PdfColors.green700,
                    ),
                    pw.SizedBox(width: 8),
                    _pdfChip(
                      AppLocalization.isIndonesian ? 'Tidak Hadir' : 'Absent',
                      recapSnapshot.where((e) => (e['status'] ?? '') != 'hadir').length.toString(),
                      PdfColors.red700,
                    ),
                  ],
                ),
                pw.SizedBox(height: 16),
                // ── Table ──────────────────────────────────────────────
                pw.TableHelper.fromTextArray(
                  headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
                  headerStyle: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.black,
                    fontSize: 10,
                  ),
                  cellStyle: const pw.TextStyle(fontSize: 9),
                  cellAlignment: pw.Alignment.centerLeft,
                  oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
                  border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
                  columnWidths: {
                    0: const pw.FixedColumnWidth(28),
                    1: const pw.FlexColumnWidth(3),
                    2: const pw.FlexColumnWidth(1.5),
                    3: const pw.FixedColumnWidth(40),
                    4: const pw.FixedColumnWidth(40),
                    5: const pw.FixedColumnWidth(52),
                    6: const pw.FixedColumnWidth(55),
                  },
                  headers: [
                    'No',
                    AppLocalization.isIndonesian ? 'Nama Siswa' : 'Student Name',
                    AppLocalization.isIndonesian ? 'Kelas' : 'Class',
                    AppLocalization.isIndonesian ? 'Masuk' : 'In',
                    AppLocalization.isIndonesian ? 'Pulang' : 'Out',
                    'Status',
                    AppLocalization.isIndonesian ? 'Metode' : 'Method',
                  ],
                  data: List<List<String>>.generate(recapSnapshot.length, (index) {
                    final item = recapSnapshot[index];
                    final checkInTimestamp = item['checkInTime'] ?? item['timestamp'];
                    final checkInTime = (checkInTimestamp as Timestamp?)?.toDate();
                    final checkInStr = checkInTime != null ? DateFormat('HH:mm').format(checkInTime) : '-';
                    final checkOutTimestamp = item['checkOutTime'];
                    final checkOutTime = (checkOutTimestamp as Timestamp?)?.toDate();
                    final checkOutStr = checkOutTime != null ? DateFormat('HH:mm').format(checkOutTime) : '-';
                    return [
                      (index + 1).toString(),
                      item['studentName'] ?? '-',
                      item['className'] ?? '-',
                      checkInStr,
                      checkOutStr,
                      (item['status'] ?? '-').toString().toUpperCase(),
                      item['method'] == 'qr_scan' ? 'QR Code' : 'Manual',
                    ];
                  }),
                ),
            ],
            footer: (pw.Context ctx) {
              return pw.Column(
                children: [
                  pw.Divider(color: PdfColors.grey300),
                  pw.SizedBox(height: 4),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        '${AppLocalization.isIndonesian ? "Dicetak" : "Printed"}: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
                        style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                      ),
                      pw.Text(
                        '${AppLocalization.isIndonesian ? "Hal" : "Page"} ${ctx.pageNumber} / ${ctx.pagesCount}',
                        style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        );
        return pdf.save();
      }

    final pdfName = AppLocalization.isIndonesian
        ? 'Rekap_Kehadiran_Siswa_${DateFormat('yyyyMMdd').format(_selectedDate)}.pdf'
        : 'Student_Daily_Attendance_${DateFormat('yyyyMMdd').format(_selectedDate)}.pdf';

    if (kIsWeb) {
      await Printing.layoutPdf(onLayout: buildPdf, name: pdfName);
    } else {
      await showDialog(
        context: ctx,
        builder: (dialogCtx) => Dialog(
          insetPadding: const EdgeInsets.all(12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: SizedBox(
            width: double.maxFinite,
            height: MediaQuery.of(dialogCtx).size.height * 0.85,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    children: [
                      const Icon(Icons.picture_as_pdf_rounded, color: Color(0xFF8B5CF6)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          AppLocalization.isIndonesian ? 'Preview PDF' : 'PDF Preview',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(dialogCtx),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: PdfPreview(
                    build: buildPdf,
                    pdfFileName: pdfName,
                    allowPrinting: true,
                    allowSharing: true,
                    canChangeOrientation: false,
                    canChangePageFormat: false,
                    canDebug: false,
                    loadingWidget: const Center(
                      child: CircularProgressIndicator(color: Color(0xFF8B5CF6)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
  }

  pw.Widget _pdfChip(String label, String value, PdfColor color) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: color, width: 1),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
          pw.Text(value, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  Future<void> _exportExcel() async {
    try {
      var excelFile = Excel.createExcel();
      Sheet sheetObject = excelFile['Sheet1'];
      
      // Header
      sheetObject.appendRow([
        TextCellValue('No'),
        TextCellValue(AppLocalization.isIndonesian ? 'Nama Siswa' : 'Student Name'),
        TextCellValue(AppLocalization.isIndonesian ? 'Kelas' : 'Class'),
        TextCellValue(AppLocalization.isIndonesian ? 'Masuk' : 'In'),
        TextCellValue(AppLocalization.isIndonesian ? 'Pulang' : 'Out'),
        TextCellValue('Status'),
        TextCellValue(AppLocalization.isIndonesian ? 'Metode' : 'Method'),
      ]);

      for (int i = 0; i < _recapData.length; i++) {
        final item = _recapData[i];
        final checkInTimestamp = item['checkInTime'] ?? item['timestamp'];
        final checkInTime = (checkInTimestamp as Timestamp?)?.toDate();
        final checkInStr = checkInTime != null ? DateFormat('HH:mm').format(checkInTime) : '-';

        final checkOutTimestamp = item['checkOutTime'];
        final checkOutTime = (checkOutTimestamp as Timestamp?)?.toDate();
        final checkOutStr = checkOutTime != null ? DateFormat('HH:mm').format(checkOutTime) : '-';
        
        sheetObject.appendRow([
          IntCellValue(i + 1),
          TextCellValue(item['studentName'] ?? '-'),
          TextCellValue(item['className'] ?? '-'),
          TextCellValue(checkInStr),
          TextCellValue(checkOutStr),
          TextCellValue((item['status'] ?? '-').toString().toUpperCase()),
          TextCellValue(item['method'] == 'qr_scan' ? 'QR Code' : 'Manual'),
        ]);
      }

      final user = SessionService.currentUser!;
      final schoolDoc = await FirebaseFirestore.instance.collection('schools').doc(user.schoolId).get();
      final schoolName = schoolDoc.data()?['namaSekolah'] ?? 'Sekolah';
      final fileName = AppLocalization.isIndonesian 
          ? 'rekap absensi harian siswa ($schoolName) tanggal ${DateFormat('yyyyMMdd').format(_selectedDate)}.xlsx'
          : 'student daily attendance ($schoolName) date ${DateFormat('yyyyMMdd').format(_selectedDate)}.xlsx';

      if (kIsWeb) {
        excelFile.save(fileName: fileName);
        Get.snackbar(
          'Berhasil',
          'File Excel berhasil diunduh.',
          backgroundColor: const Color(0xFF10B981),
          colorText: Colors.white,
          duration: const Duration(seconds: 5),
        );
      } else {
        final bytes = excelFile.save();
        if (bytes == null) throw ('Gagal generate file Excel');
        final dir = await getApplicationDocumentsDirectory();
        final file = File('${dir.path}/$fileName');
        await file.writeAsBytes(bytes);

        Get.snackbar(
          'Berhasil',
          'File Excel disimpan di: ${file.path}',
          backgroundColor: const Color(0xFF10B981),
          colorText: Colors.white,
          duration: const Duration(seconds: 5),
        );
      }
    } catch (e) {
      Get.snackbar('Error', 'Gagal export excel: $e', backgroundColor: Colors.red, colorText: Colors.white);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isAccessChecking) {
      return const Scaffold(
        backgroundColor: Color(0xFF0F0B1E),
        body: Center(child: CircularProgressIndicator(color: Color(0xFF8B5CF6))),
      );
    }
    if (!_isAccessGranted) {
      return const Scaffold(
        backgroundColor: Color(0xFF0F0B1E),
        body: SizedBox.shrink(),
      );
    }

    return ValueListenableBuilder<bool>(
      valueListenable: AuthBackground.isDarkMode,
      builder: (context, isDark, _) {
        return ValueListenableBuilder<String>(
          valueListenable: AppLocalization.currentLocale,
          builder: (context, locale, _) {
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
                  AppLocalization.isIndonesian ? 'Rekap Harian Murid' : 'Daily Student Recap',
                  style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
                ),
                actions: [
                  IconButton(
                    icon: Icon(Icons.picture_as_pdf_rounded, color: textColor),
                    onPressed: _isLoading ? null : _exportPdf,
                    tooltip: AppLocalization.isIndonesian ? 'Ekspor PDF' : 'Export PDF',
                  ),
                  IconButton(
                    icon: Icon(Icons.table_view_rounded, color: textColor),
                    onPressed: _isLoading ? null : _exportExcel,
                    tooltip: AppLocalization.isIndonesian ? 'Ekspor Excel' : 'Export Excel',
                  ),
                ],
              ),
              body: AuthBackground(
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
                    child: Column(
                      children: [
                        // Pill segmented control
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: cardBorder),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF8B5CF6),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Center(
                                    child: Text(
                                      AppLocalization.isIndonesian ? 'Presensi Harian' : 'Daily Attendance',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => Get.off(
                                    () => const MonthlyRecapPage(),
                                    transition: Transition.noTransition,
                                  ),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    decoration: const BoxDecoration(
                                      color: Colors.transparent,
                                    ),
                                    child: Center(
                                      child: Text(
                                        AppLocalization.isIndonesian ? 'Rekap Bulanan' : 'Monthly Recap',
                                        style: TextStyle(
                                          color: textColor,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Date picker bar
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: cardBorder),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.calendar_month_rounded, color: Color(0xFF6366F1), size: 24),
                                  const SizedBox(width: 12),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        AppLocalization.isIndonesian ? 'Tanggal' : 'Date',
                                        style: TextStyle(color: subTextColor, fontSize: 12),
                                      ),
                                      Text(
                                        DateFormat('dd MMM yyyy').format(_selectedDate),
                                        style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 16),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              TextButton(
                                onPressed: _selectDate,
                                child: Text(AppLocalization.isIndonesian ? 'Ubah' : 'Change'),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        
                        // Table header
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white.withValues(alpha: 0.1) : const Color(0xFF1E1B4B).withValues(alpha: 0.05),
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: Text(
                                  AppLocalization.isIndonesian ? 'Siswa' : 'Student',
                                  style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
                                ),
                              ),
                              Expanded(
                                flex: 1,
                                child: Text(
                                  AppLocalization.isIndonesian ? 'Kelas' : 'Class',
                                  style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
                                ),
                              ),
                              Expanded(
                                flex: 1,
                                child: Text(
                                  AppLocalization.isIndonesian ? 'Masuk' : 'In',
                                  style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              Expanded(
                                flex: 1,
                                child: Text(
                                  AppLocalization.isIndonesian ? 'Pulang' : 'Out',
                                  style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              Expanded(
                                flex: 1,
                                child: Text(
                                  AppLocalization.isIndonesian ? 'Status' : 'Status',
                                  style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
                                  textAlign: TextAlign.end,
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        // Data list
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: cardBg,
                              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                              border: Border.all(color: cardBorder),
                            ),
                            child: _isLoading 
                              ? const Center(child: CircularProgressIndicator())
                              : _recapData.isEmpty
                                ? Center(
                                    child: Text(
                                      AppLocalization.isIndonesian ? 'Belum ada data siswa.' : 'No student data.',
                                      style: TextStyle(color: subTextColor),
                                    ),
                                  )
                                : ListView.separated(
                                    itemCount: _recapData.length,
                                    separatorBuilder: (_, __) => Divider(color: cardBorder, height: 1),
                                    itemBuilder: (context, index) {
                                      final item = _recapData[index];
                                      final isHadir = item['status'] == 'hadir';
                                      
                                      final checkInTimestamp = item['checkInTime'] ?? item['timestamp'];
                                      final checkInTime = (checkInTimestamp as Timestamp?)?.toDate();
                                      final checkInStr = checkInTime != null ? DateFormat('HH:mm').format(checkInTime) : '-';

                                      final checkOutTimestamp = item['checkOutTime'];
                                      final checkOutTime = (checkOutTimestamp as Timestamp?)?.toDate();
                                      final checkOutStr = checkOutTime != null ? DateFormat('HH:mm').format(checkOutTime) : '-';
                                      
                                      return Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              flex: 2,
                                              child: Text(
                                                item['studentName'] ?? '-',
                                                style: TextStyle(color: textColor, fontWeight: FontWeight.w500),
                                              ),
                                            ),
                                            Expanded(
                                              flex: 1,
                                              child: Text(
                                                item['className'] ?? '-',
                                                style: TextStyle(color: subTextColor),
                                              ),
                                            ),
                                            Expanded(
                                              flex: 1,
                                              child: Text(
                                                checkInStr,
                                                style: TextStyle(color: subTextColor),
                                                textAlign: TextAlign.center,
                                              ),
                                            ),
                                            Expanded(
                                              flex: 1,
                                              child: Text(
                                                checkOutStr,
                                                style: TextStyle(color: subTextColor),
                                                textAlign: TextAlign.center,
                                              ),
                                            ),
                                            Expanded(
                                              flex: 1,
                                              child: Text(
                                                (item['status'] ?? '-').toString().toUpperCase(),
                                                style: TextStyle(
                                                  color: isHadir ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 12,
                                                ),
                                                textAlign: TextAlign.end,
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
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
      },
    );
  }
}
