import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:excel/excel.dart' hide Border;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:sys_mng_school/core/localization/app_localization.dart';

import '../../../../../core/services/session_service.dart';
import '../../../../authentication/widgets/auth_background.dart';
import '../../../../officer/data/officer_repository.dart';
import '../data/teacher_service.dart';

class AdminTeacherAttendancePage extends StatefulWidget {
  final bool isMonthly;
  const AdminTeacherAttendancePage({super.key, this.isMonthly = false});

  @override
  State<AdminTeacherAttendancePage> createState() => _AdminTeacherAttendancePageState();
}

class _AdminTeacherAttendancePageState extends State<AdminTeacherAttendancePage> {
  final _teacherService = TeacherService();
  final _repo = OfficerRepository();
  
  late bool _isMonthlyRecap;
  int _selectedYear = DateTime.now().year;
  int _selectedMonth = DateTime.now().month;
  bool _isAccessChecking = false;
  bool _isAccessGranted = true;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _accessSubscription;
  bool _lockDialogShown = false;

  List<String> get _monthNames => AppLocalization.isIndonesian
      ? ['Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni', 'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember']
      : ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];

  @override
  void initState() {
    super.initState();
    _isMonthlyRecap = widget.isMonthly;
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
      setState(() {
        _isAccessChecking = false;
        _isAccessGranted = true;
      });
      return;
    }

    setState(() => _isAccessChecking = true);

    _accessSubscription = FirebaseFirestore.instance
        .collection('schools')
        .doc(user!.schoolId)
        .snapshots()
        .listen((snap) {
      if (!mounted) return;
      final bool enabled = snap.data()?['enableTeacherAttendanceRecap'] ?? false;

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
                    ? 'Fitur Rekap Absensi Guru dinonaktifkan oleh Super Admin. Silakan hubungi Super Admin untuk mengaktifkan akses.'
                    : 'The Teacher Attendance Recap feature is disabled by the Super Admin. Please contact Super Admin to enable access.',
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
        setState(() {
          _isAccessChecking = false;
          _isAccessGranted = true;
        });
      }
    }, onError: (e) {
      setState(() {
        _isAccessChecking = false;
        _isAccessGranted = true;
      });
    });
  }

  DateTime _selectedDate = DateTime.now();
  String _searchQuery = '';
  String _selectedStatusFilter = 'Semua'; // 'Semua', 'Hadir', 'Terlambat', 'Sakit', 'Izin', 'Alfa'

  String _getDateStr(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  String _getFormattedIndonesianDate(DateTime date) {
    if (!AppLocalization.isIndonesian) {
      final days = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
      final months = [
        'January', 'February', 'March', 'April', 'May', 'June',
        'July', 'August', 'September', 'October', 'November', 'December'
      ];
      return '${days[date.weekday % 7]}, ${months[date.month - 1]} ${date.day}, ${date.year}';
    }
    final days = ['Minggu', 'Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu'];
    final months = [
      'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
    ];
    return '${days[date.weekday % 7]}, ${date.day} ${months[date.month - 1]} ${date.year}';
  }

  String _formatTime(Timestamp? timestamp) {
    if (timestamp == null) return '--:--';
    final date = timestamp.toDate().toLocal();
    return DateFormat('HH:mm').format(date);
  }

  void _showDatePicker() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365 * 3)),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      builder: (context, child) {
        final isDark = AuthBackground.isDarkMode.value;
        return Theme(
          data: isDark
              ? ThemeData.dark().copyWith(
                  colorScheme: const ColorScheme.dark(
                    primary: Color(0xFF8B5CF6),
                    onPrimary: Colors.white,
                    surface: Color(0xFF1E1B4B),
                    onSurface: Colors.white,
                  ),
                  dialogBackgroundColor: const Color(0xFF0F0C20),
                )
              : ThemeData.light().copyWith(
                  colorScheme: const ColorScheme.light(
                    primary: Color(0xFF8B5CF6),
                    onPrimary: Colors.white,
                    surface: Colors.white,
                    onSurface: Color(0xFF1E1B4B),
                  ),
                ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    String label;
    switch (status.toLowerCase()) {
      case 'hadir':
        color = const Color(0xFF10B981);
        label = AppLocalization.isIndonesian ? 'Hadir' : 'Present';
        break;
      case 'terlambat':
        color = const Color(0xFFF59E0B);
        label = AppLocalization.isIndonesian ? 'Terlambat' : 'Late';
        break;
      case 'sakit':
        color = const Color(0xFF3B82F6);
        label = AppLocalization.isIndonesian ? 'Sakit' : 'Sick';
        break;
      case 'izin':
        color = const Color(0xFF8B5CF6);
        label = AppLocalization.isIndonesian ? 'Izin' : 'Permitted';
        break;
      case 'alfa':
        color = const Color(0xFFEF4444);
        label = AppLocalization.isIndonesian ? 'Alfa' : 'Absent';
        break;
      default:
        color = Colors.grey;
        label = status.toUpperCase();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildCountBadge(String label, int count, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(color: color.withValues(alpha: 0.8), fontSize: 10, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
          ),
          child: Text(
            '$count',
            style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
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

  Future<void> _exportDailyPdf() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: Color(0xFF8B5CF6)),
      ),
    );

    try {
      final schoolId = SessionService.currentUser!.schoolId;
      final dateStr = _getDateStr(_selectedDate);

      // Fetch teachers
      final teachersSnap = await _teacherService.getTeachers(schoolId).first;
      // Fetch attendance
      final attendanceSnap = await FirebaseFirestore.instance
          .collection('schools')
          .doc(schoolId)
          .collection('teacher_daily_attendance')
          .where('date', isEqualTo: dateStr)
          .get();

      final Map<String, Map<String, dynamic>> attMap = {};
      for (var doc in attendanceSnap.docs) {
        final d = doc.data();
        final tId = d['teacherId'] as String?;
        if (tId != null) {
          attMap[tId] = d;
        }
      }

      final processedList = <Map<String, dynamic>>[];
      for (var doc in teachersSnap.docs) {
        final tData = doc.data();
        final tId = doc.id;
        final name = tData['nama'] ?? 'Guru';
        final nip = tData['nip'] ?? '';
        
        final attendance = attMap[tId];
        final status = attendance != null ? (attendance['status'] ?? 'hadir') : 'alfa';

        if (_searchQuery.isNotEmpty &&
            !name.toLowerCase().contains(_searchQuery.toLowerCase())) {
          continue;
        }
        if (_selectedStatusFilter != 'Semua') {
          if (_selectedStatusFilter == 'Hadir' && status != 'hadir') continue;
          if (_selectedStatusFilter == 'Terlambat' && status != 'terlambat') continue;
          if (_selectedStatusFilter == 'Sakit' && status != 'sakit') continue;
          if (_selectedStatusFilter == 'Izin' && status != 'izin') continue;
          if (_selectedStatusFilter == 'Alfa' && status != 'alfa') continue;
        }

        processedList.add({
          'teacherId': tId,
          'teacherName': name,
          'nip': nip,
          'status': status,
          'attendance': attendance,
        });
      }
      // PDF: pure A-Z sort
      processedList.sort((a, b) => (a['teacherName'] as String).toLowerCase().compareTo((b['teacherName'] as String).toLowerCase()));

      String schoolName = 'Sekolah';
      try {
        final schoolDoc = await FirebaseFirestore.instance.collection('schools').doc(schoolId).get();
        if (schoolDoc.exists) {
          schoolName = schoolDoc.data()?['schoolName'] ?? 'Sekolah';
        }
      } catch (_) {}

      // Calculate statistics
      int countHadir = 0;
      int countTerlambat = 0;
      int countIzinSakit = 0;
      int countAlfa = 0;

      for (var item in processedList) {
        final status = (item['status'] as String).toLowerCase();
        if (status == 'hadir') countHadir++;
        else if (status == 'terlambat') countTerlambat++;
        else if (status == 'sakit' || status == 'izin') countIzinSakit++;
        else countAlfa++;
      }

      final dateLabel = _getFormattedIndonesianDate(_selectedDate);
      final pdfName = 'Rekap_Harian_Guru_${DateFormat('yyyyMMdd').format(_selectedDate)}.pdf';
      final ctx = context;

      if (mounted) Navigator.pop(context); // Pop spinner

      Future<Uint8List> buildPdf(PdfPageFormat format) async {
        final pdf = pw.Document();
        pdf.addPage(
          pw.MultiPage(
            pageFormat: format,
            margin: const pw.EdgeInsets.all(32),
            build: (pw.Context context) => [
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
                            ? 'Laporan Kehadiran Harian Guru'
                            : 'Teacher Daily Attendance Report',
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
                        AppLocalization.isIndonesian ? 'Total Guru' : 'Total Teachers',
                        processedList.length.toString(),
                        PdfColors.indigo700,
                      ),
                      pw.SizedBox(width: 8),
                      _pdfChip(
                        AppLocalization.isIndonesian ? 'Hadir' : 'Present',
                        countHadir.toString(),
                        PdfColors.green700,
                      ),
                      pw.SizedBox(width: 8),
                      _pdfChip(
                        AppLocalization.isIndonesian ? 'Terlambat' : 'Late',
                        countTerlambat.toString(),
                        PdfColors.orange700,
                      ),
                      pw.SizedBox(width: 8),
                      _pdfChip(
                        AppLocalization.isIndonesian ? 'Izin/Sakit' : 'Permitted/Sick',
                        countIzinSakit.toString(),
                        PdfColors.blue700,
                      ),
                      pw.SizedBox(width: 8),
                      _pdfChip(
                        AppLocalization.isIndonesian ? 'Belum Absen' : 'Absent',
                        countAlfa.toString(),
                        PdfColors.red700,
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 16),
                  // ── Table ──────────────────────────────────────────────
                  pw.TableHelper.fromTextArray(
                    headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
                    headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.black, fontSize: 10),
                    cellStyle: const pw.TextStyle(fontSize: 9),
                    cellAlignment: pw.Alignment.centerLeft,
                    oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
                    border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
                    columnWidths: {
                      0: const pw.FixedColumnWidth(28),
                      1: const pw.FlexColumnWidth(3),
                      2: const pw.FlexColumnWidth(2),
                      3: const pw.FixedColumnWidth(40),
                      4: const pw.FixedColumnWidth(40),
                      5: const pw.FixedColumnWidth(55),
                    },
                    headers: [
                      'No', 
                      AppLocalization.isIndonesian ? 'Nama Guru' : 'Teacher Name', 
                      'NIP', 
                      AppLocalization.isIndonesian ? 'Masuk' : 'In', 
                      AppLocalization.isIndonesian ? 'Pulang' : 'Out',
                      'Status'
                    ],
                    data: List<List<String>>.generate(processedList.length, (index) {
                      final item = processedList[index];
                      final att = item['attendance'] as Map<String, dynamic>?;
                      final checkInTime = att != null ? att['checkInTime'] as Timestamp? : null;
                      final checkOutTime = att != null ? att['checkOutTime'] as Timestamp? : null;
                      
                      return [
                        (index + 1).toString(),
                        item['teacherName'] ?? '-',
                        item['nip'] ?? '-',
                        checkInTime != null ? _formatTime(checkInTime) : '--:--',
                        checkOutTime != null ? _formatTime(checkOutTime) : '--:--',
                        (item['status'] ?? '-').toString().toUpperCase(),
                      ];
                    }),
                  ),
            ],
            footer: (pw.Context context) {
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
                        '${AppLocalization.isIndonesian ? "Halaman" : "Page"} ${context.pageNumber} / ${context.pagesCount}',
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
    } catch (e) {
      if (mounted && Navigator.canPop(context)) Navigator.pop(context); // Pop spinner if still showing
      Get.snackbar('Error', 'Gagal export PDF: $e', backgroundColor: Colors.red, colorText: Colors.white);
    }
  }

  Future<void> _exportDailyExcel() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: Color(0xFF8B5CF6)),
      ),
    );

    try {
      final schoolId = SessionService.currentUser!.schoolId;
      final dateStr = _getDateStr(_selectedDate);

      // Fetch teachers
      final teachersSnap = await _teacherService.getTeachers(schoolId).first;
      // Fetch attendance
      final attendanceSnap = await FirebaseFirestore.instance
          .collection('schools')
          .doc(schoolId)
          .collection('teacher_daily_attendance')
          .where('date', isEqualTo: dateStr)
          .get();

      final Map<String, Map<String, dynamic>> attMap = {};
      for (var doc in attendanceSnap.docs) {
        final d = doc.data();
        final tId = d['teacherId'] as String?;
        if (tId != null) {
          attMap[tId] = d;
        }
      }

      final processedList = <Map<String, dynamic>>[];
      for (var doc in teachersSnap.docs) {
        final tData = doc.data();
        final tId = doc.id;
        final name = tData['nama'] ?? 'Guru';
        final nip = tData['nip'] ?? '';
        
        final attendance = attMap[tId];
        final status = attendance != null ? (attendance['status'] ?? 'hadir') : 'alfa';

        if (_searchQuery.isNotEmpty &&
            !name.toLowerCase().contains(_searchQuery.toLowerCase())) {
          continue;
        }
        if (_selectedStatusFilter != 'Semua') {
          if (_selectedStatusFilter == 'Hadir' && status != 'hadir') continue;
          if (_selectedStatusFilter == 'Terlambat' && status != 'terlambat') continue;
          if (_selectedStatusFilter == 'Sakit' && status != 'sakit') continue;
          if (_selectedStatusFilter == 'Izin' && status != 'izin') continue;
          if (_selectedStatusFilter == 'Alfa' && status != 'alfa') continue;
        }

        processedList.add({
          'teacherId': tId,
          'teacherName': name,
          'nip': nip,
          'status': status,
          'attendance': attendance,
        });
      }

      processedList.sort((a, b) => (a['teacherName'] as String).compareTo(b['teacherName'] as String));

      final excelFile = Excel.createExcel();
      final sheetObject = excelFile['Sheet1'];
      
      sheetObject.appendRow([
        TextCellValue('No'),
        TextCellValue(AppLocalization.isIndonesian ? 'Nama Guru' : 'Teacher Name'),
        TextCellValue('NIP'),
        TextCellValue('Status'),
        TextCellValue(AppLocalization.isIndonesian ? 'Jam Masuk' : 'Clock In'),
        TextCellValue(AppLocalization.isIndonesian ? 'Jam Pulang' : 'Clock Out'),
      ]);

      for (int i = 0; i < processedList.length; i++) {
        final item = processedList[i];
        final att = item['attendance'] as Map<String, dynamic>?;
        final checkInTime = att != null ? att['checkInTime'] as Timestamp? : null;
        final checkOutTime = att != null ? att['checkOutTime'] as Timestamp? : null;

        sheetObject.appendRow([
          IntCellValue(i + 1),
          TextCellValue(item['teacherName'] ?? '-'),
          TextCellValue(item['nip'] ?? '-'),
          TextCellValue((item['status'] ?? '-').toString().toUpperCase()),
          TextCellValue(checkInTime != null ? _formatTime(checkInTime) : '--:--'),
          TextCellValue(checkOutTime != null ? _formatTime(checkOutTime) : '--:--'),
        ]);
      }

      final schoolDoc = await FirebaseFirestore.instance.collection('schools').doc(schoolId).get();
      final schoolName = schoolDoc.data()?['namaSekolah'] ?? 'Sekolah';
      final fileName = AppLocalization.isIndonesian 
          ? 'rekap absensi harian guru ($schoolName) tanggal ${DateFormat('yyyyMMdd').format(_selectedDate)}.xlsx'
          : 'teacher daily attendance ($schoolName) date ${DateFormat('yyyyMMdd').format(_selectedDate)}.xlsx';

      if (kIsWeb) {
        excelFile.save(fileName: fileName);
        if (mounted) Navigator.pop(context); // Pop spinner
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
        if (mounted) Navigator.pop(context); // Pop spinner
        Get.snackbar(
          'Berhasil',
          'File Excel disimpan di: ${file.path}',
          backgroundColor: const Color(0xFF10B981),
          colorText: Colors.white,
          duration: const Duration(seconds: 5),
        );
      }
    } catch (e) {
      if (mounted) Navigator.pop(context); // Pop spinner
      Get.snackbar('Error', 'Gagal export excel: $e', backgroundColor: Colors.red, colorText: Colors.white);
    }
  }

  Future<void> _exportMonthlyPdf() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: Color(0xFF8B5CF6)),
      ),
    );

    try {
      final schoolId = SessionService.currentUser!.schoolId;
      final teachersSnap = await _teacherService.getTeachers(schoolId).first;
      
      final year = _selectedYear;
      final monthStr = _selectedMonth.toString().padLeft(2, '0');
      final startOfDate = '$year-$monthStr-01';
      final endOfDate = '$year-$monthStr-31';

      final attendanceSnap = await FirebaseFirestore.instance
          .collection('schools')
          .doc(schoolId)
          .collection('teacher_daily_attendance')
          .where('date', isGreaterThanOrEqualTo: startOfDate)
          .where('date', isLessThanOrEqualTo: endOfDate)
          .get();

      final Map<String, Map<String, int>> recapMap = {};
      for (var doc in attendanceSnap.docs) {
        final d = doc.data();
        final tId = d['teacherId'] as String?;
        final status = d['status'] as String?;
        final checkOutTime = d['checkOutTime'];
        if (tId != null && status != null) {
          recapMap.putIfAbsent(tId, () => {
            'hadir': 0,
            'terlambat': 0,
            'sakit': 0,
            'izin': 0,
            'alfa': 0,
            'pulang': 0,
          });
          final normStatus = status.toLowerCase();
          if (recapMap[tId]!.containsKey(normStatus)) {
            recapMap[tId]![normStatus] = recapMap[tId]![normStatus]! + 1;
          } else if (normStatus == 'alfa' || normStatus == 'alpha') {
            recapMap[tId]!['alfa'] = recapMap[tId]!['alfa']! + 1;
          }
          if (checkOutTime != null) {
            recapMap[tId]!['pulang'] = recapMap[tId]!['pulang']! + 1;
          }
        }
      }

      final teachersList = teachersSnap.docs;
      final sortedTeachers = List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(teachersList);
      sortedTeachers.sort((a, b) {
        final nameA = (a.data()['nama'] ?? 'Guru').toString();
        final nameB = (b.data()['nama'] ?? 'Guru').toString();
        return nameA.compareTo(nameB);
      });

      final pdf = pw.Document();
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return [
              pw.Text(
                AppLocalization.isIndonesian ? 'Laporan Kehadiran Bulanan Guru' : 'Teacher Monthly Attendance Report', 
                style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: PdfColors.black)
              ),
              pw.SizedBox(height: 8),
              pw.Text(
                '${AppLocalization.isIndonesian ? 'Periode' : 'Period'}: ${_monthNames[_selectedMonth - 1]} $_selectedYear',
                style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700)
              ),
              pw.SizedBox(height: 20),
              pw.TableHelper.fromTextArray(
                headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.black),
                cellAlignment: pw.Alignment.centerLeft,
                oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
                border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
                headers: [
                  'No', 
                  AppLocalization.isIndonesian ? 'Nama Guru' : 'Teacher Name', 
                  'NIP', 
                  AppLocalization.isIndonesian ? 'Hadir' : 'Present', 
                  AppLocalization.isIndonesian ? 'Telat' : 'Late', 
                  AppLocalization.isIndonesian ? 'Pulang' : 'Left', 
                  AppLocalization.isIndonesian ? 'Sakit' : 'Sick', 
                  AppLocalization.isIndonesian ? 'Izin' : 'Permit', 
                  'Alfa'
                ],
                data: List<List<String>>.generate(sortedTeachers.length, (index) {
                  final doc = sortedTeachers[index];
                  final tData = doc.data();
                  final tId = doc.id;
                  final name = tData['nama'] ?? 'Guru';
                  final nip = tData['nip'] ?? '-';
                  
                  final counts = recapMap[tId] ?? {
                    'hadir': 0,
                    'terlambat': 0,
                    'sakit': 0,
                    'izin': 0,
                    'alfa': 0,
                    'pulang': 0,
                  };

                  return [
                    (index + 1).toString(),
                    name,
                    nip,
                    counts['hadir'].toString(),
                    counts['terlambat'].toString(),
                    counts['pulang'].toString(),
                    counts['sakit'].toString(),
                    counts['izin'].toString(),
                    counts['alfa'].toString(),
                  ];
                }),
              ),
            ];
          },
        ),
      );

      if (mounted) Navigator.pop(context); // Pop spinner

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
        name: 'Rekap_Bulanan_Guru_${_monthNames[_selectedMonth - 1]}_$_selectedYear.pdf',
      );
    } catch (e) {
      if (mounted) Navigator.pop(context); // Pop spinner
      Get.snackbar('Error', 'Gagal export PDF: $e', backgroundColor: Colors.red, colorText: Colors.white);
    }
  }

  Future<void> _exportMonthlyExcel() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: Color(0xFF8B5CF6)),
      ),
    );

    try {
      final schoolId = SessionService.currentUser!.schoolId;
      final teachersSnap = await _teacherService.getTeachers(schoolId).first;
      
      final year = _selectedYear;
      final monthStr = _selectedMonth.toString().padLeft(2, '0');
      final startOfDate = '$year-$monthStr-01';
      final endOfDate = '$year-$monthStr-31';

      final attendanceSnap = await FirebaseFirestore.instance
          .collection('schools')
          .doc(schoolId)
          .collection('teacher_daily_attendance')
          .where('date', isGreaterThanOrEqualTo: startOfDate)
          .where('date', isLessThanOrEqualTo: endOfDate)
          .get();

      final Map<String, Map<String, int>> recapMap = {};
      for (var doc in attendanceSnap.docs) {
        final d = doc.data();
        final tId = d['teacherId'] as String?;
        final status = d['status'] as String?;
        final checkOutTime = d['checkOutTime'];
        if (tId != null && status != null) {
          recapMap.putIfAbsent(tId, () => {
            'hadir': 0,
            'terlambat': 0,
            'sakit': 0,
            'izin': 0,
            'alfa': 0,
            'pulang': 0,
          });
          final normStatus = status.toLowerCase();
          if (recapMap[tId]!.containsKey(normStatus)) {
            recapMap[tId]![normStatus] = recapMap[tId]![normStatus]! + 1;
          } else if (normStatus == 'alfa' || normStatus == 'alpha') {
            recapMap[tId]!['alfa'] = recapMap[tId]!['alfa']! + 1;
          }
          if (checkOutTime != null) {
            recapMap[tId]!['pulang'] = recapMap[tId]!['pulang']! + 1;
          }
        }
      }

      final teachersList = teachersSnap.docs;
      final sortedTeachers = List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(teachersList);
      sortedTeachers.sort((a, b) {
        final nameA = (a.data()['nama'] ?? 'Guru').toString();
        final nameB = (b.data()['nama'] ?? 'Guru').toString();
        return nameA.compareTo(nameB);
      });

      final excelFile = Excel.createExcel();
      final sheetObject = excelFile['Sheet1'];
      
      sheetObject.appendRow([
        TextCellValue('No'),
        TextCellValue(AppLocalization.isIndonesian ? 'Nama Guru' : 'Teacher Name'),
        TextCellValue('NIP'),
        TextCellValue(AppLocalization.isIndonesian ? 'Hadir' : 'Present'),
        TextCellValue(AppLocalization.isIndonesian ? 'Telat' : 'Late'),
        TextCellValue(AppLocalization.isIndonesian ? 'Pulang' : 'Left'),
        TextCellValue(AppLocalization.isIndonesian ? 'Sakit' : 'Sick'),
        TextCellValue(AppLocalization.isIndonesian ? 'Izin' : 'Permit'),
        TextCellValue('Alfa'),
      ]);

      for (int i = 0; i < sortedTeachers.length; i++) {
        final doc = sortedTeachers[i];
        final tData = doc.data();
        final tId = doc.id;
        final name = tData['nama'] ?? 'Guru';
        final nip = tData['nip'] ?? '-';

        final counts = recapMap[tId] ?? {
          'hadir': 0,
          'terlambat': 0,
          'sakit': 0,
          'izin': 0,
          'alfa': 0,
          'pulang': 0,
        };

        sheetObject.appendRow([
          IntCellValue(i + 1),
          TextCellValue(name),
          TextCellValue(nip),
          IntCellValue(counts['hadir']!),
          IntCellValue(counts['terlambat']!),
          IntCellValue(counts['pulang']!),
          IntCellValue(counts['sakit']!),
          IntCellValue(counts['izin']!),
          IntCellValue(counts['alfa']!),
        ]);
      }

      final schoolDoc = await FirebaseFirestore.instance.collection('schools').doc(schoolId).get();
      final schoolName = schoolDoc.data()?['namaSekolah'] ?? 'Sekolah';
      final monthName = _monthNames[_selectedMonth - 1];

      final fileName = AppLocalization.isIndonesian 
          ? 'rekap absensi bulanan guru ($schoolName) bulan ($monthName).xlsx'
          : 'teacher monthly attendance ($schoolName) month ($monthName).xlsx';

      if (kIsWeb) {
        excelFile.save(fileName: fileName);
        if (mounted) Navigator.pop(context); // Pop spinner
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
        if (mounted) Navigator.pop(context); // Pop spinner
        Get.snackbar(
          'Berhasil',
          'File Excel disimpan di: ${file.path}',
          backgroundColor: const Color(0xFF10B981),
          colorText: Colors.white,
          duration: const Duration(seconds: 5),
        );
      }
    } catch (e) {
      if (mounted) Navigator.pop(context); // Pop spinner
      Get.snackbar('Error', 'Gagal export excel: $e', backgroundColor: Colors.red, colorText: Colors.white);
    }
  }

  void _showEditAttendanceModal({
    required String schoolId,
    required String teacherId,
    required String teacherName,
    required String nip,
    required Map<String, dynamic>? currentData,
  }) {
    final isDark = AuthBackground.isDarkMode.value;
    final textThemeColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
    final cardBg = isDark ? const Color(0xFF1A162B) : const Color(0xFFF8FAFC);
    
    String tempStatus = currentData != null ? (currentData['status'] ?? 'hadir') : 'alfa';
    DateTime? tempCheckIn = (currentData?['checkInTime'] as Timestamp?)?.toDate();
    DateTime? tempCheckOut = (currentData?['checkOutTime'] as Timestamp?)?.toDate();
    final reasonController = TextEditingController(text: currentData?['reason'] ?? '');

    Get.bottomSheet(
      StatefulBuilder(
        builder: (context, setModalState) {
          final isCheckInEnabled = tempStatus == 'hadir' || tempStatus == 'terlambat';
          return Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F0C20) : Colors.white,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(28),
                topRight: Radius.circular(28),
              ),
              border: Border(
                top: BorderSide(
                  color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.08),
                ),
              ),
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Edit Presensi Manual',
                              style: TextStyle(color: textThemeColor, fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '$teacherName (NIP: $nip)',
                              style: TextStyle(color: textThemeColor.withValues(alpha: 0.6), fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close_rounded, color: textThemeColor.withValues(alpha: 0.6)),
                        onPressed: () => Get.back(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Status Dropdown
                  Text(
                    'Status Kehadiran',
                    style: TextStyle(color: textThemeColor, fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: tempStatus.toLowerCase(),
                        dropdownColor: isDark ? const Color(0xFF0F0C20) : Colors.white,
                        style: TextStyle(color: textThemeColor, fontSize: 14, fontWeight: FontWeight.w600),
                        icon: Icon(Icons.arrow_drop_down_rounded, color: textThemeColor),
                        items: const [
                          DropdownMenuItem(value: 'hadir', child: Text('Hadir')),
                          DropdownMenuItem(value: 'terlambat', child: Text('Terlambat')),
                          DropdownMenuItem(value: 'sakit', child: Text('Sakit')),
                          DropdownMenuItem(value: 'izin', child: Text('Izin')),
                          DropdownMenuItem(value: 'alfa', child: Text('Alfa (Belum Absen)')),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setModalState(() {
                              tempStatus = val;
                              if (val == 'hadir' || val == 'terlambat') {
                                tempCheckIn ??= DateTime(
                                  _selectedDate.year,
                                  _selectedDate.month,
                                  _selectedDate.day,
                                  7,
                                  0,
                                );
                              } else {
                                tempCheckIn = null;
                                tempCheckOut = null;
                              }
                            });
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Jam Masuk & Pulang
                  if (isCheckInEnabled) ...[
                    Row(
                      children: [
                        // Jam Masuk Picker
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Jam Masuk',
                                style: TextStyle(color: textThemeColor, fontSize: 13, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              InkWell(
                                onTap: () async {
                                  final time = await showTimePicker(
                                    context: context,
                                    initialTime: TimeOfDay.fromDateTime(tempCheckIn ?? DateTime.now()),
                                  );
                                  if (time != null) {
                                    setModalState(() {
                                      tempCheckIn = DateTime(
                                        _selectedDate.year,
                                        _selectedDate.month,
                                        _selectedDate.day,
                                        time.hour,
                                        time.minute,
                                      );
                                    });
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                                  decoration: BoxDecoration(
                                    color: cardBg,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.access_time_rounded, color: textThemeColor.withValues(alpha: 0.6), size: 18),
                                      const SizedBox(width: 8),
                                      Text(
                                        tempCheckIn != null ? DateFormat('HH:mm').format(tempCheckIn!) : '--:--',
                                        style: TextStyle(color: textThemeColor, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),

                        // Jam Pulang Picker
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Jam Pulang',
                                style: TextStyle(color: textThemeColor, fontSize: 13, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              InkWell(
                                onTap: () async {
                                  final time = await showTimePicker(
                                    context: context,
                                    initialTime: TimeOfDay.fromDateTime(tempCheckOut ?? DateTime.now()),
                                  );
                                  if (time != null) {
                                    setModalState(() {
                                      tempCheckOut = DateTime(
                                        _selectedDate.year,
                                        _selectedDate.month,
                                        _selectedDate.day,
                                        time.hour,
                                        time.minute,
                                      );
                                    });
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                                  decoration: BoxDecoration(
                                    color: cardBg,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.access_time_rounded, color: textThemeColor.withValues(alpha: 0.6), size: 18),
                                      const SizedBox(width: 8),
                                      Text(
                                        tempCheckOut != null ? DateFormat('HH:mm').format(tempCheckOut!) : '--:--',
                                        style: TextStyle(color: textThemeColor, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Catatan / Keterangan
                  Text(
                    'Catatan / Alasan',
                    style: TextStyle(color: textThemeColor, fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: reasonController,
                    style: TextStyle(color: textThemeColor),
                    decoration: InputDecoration(
                      hintText: 'Tulis keterangan (misal: Sakit Flu, Dispensasi)...',
                      hintStyle: TextStyle(color: textThemeColor.withValues(alpha: 0.4)),
                      filled: true,
                      fillColor: cardBg,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: isDark ? BorderSide.none : const BorderSide(color: Colors.black12),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Simpan Button
                  ElevatedButton(
                    onPressed: () async {
                      try {
                        final dateStr = _getDateStr(_selectedDate);
                        await _repo.markTeacherAttendanceManual(
                          schoolId: schoolId,
                          teacherId: teacherId,
                          teacherName: teacherName,
                          nip: nip,
                          dateStr: dateStr,
                          status: tempStatus,
                          checkInTime: tempCheckIn,
                          checkOutTime: tempCheckOut,
                        );

                        // Simpan reason ke document attendance jika ada reason
                        if (reasonController.text.isNotEmpty) {
                          await FirebaseFirestore.instance
                              .collection('schools')
                              .doc(schoolId)
                              .collection('teacher_daily_attendance')
                              .doc('${dateStr}_$teacherId')
                              .update({
                            'reason': reasonController.text,
                          });
                        }

                        Get.back();
                        Get.snackbar(
                          'Sukses',
                          'Presensi guru berhasil diperbarui.',
                          backgroundColor: const Color(0xFF10B981),
                          colorText: Colors.white,
                          snackPosition: SnackPosition.BOTTOM,
                          margin: const EdgeInsets.all(16),
                          borderRadius: 12,
                        );
                      } catch (e) {
                        Get.snackbar(
                          'Gagal',
                          e.toString(),
                          backgroundColor: Colors.red,
                          colorText: Colors.white,
                          snackPosition: SnackPosition.BOTTOM,
                          margin: const EdgeInsets.all(16),
                          borderRadius: 12,
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8B5CF6),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text(
                      'Simpan Perubahan',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
      isScrollControlled: true,
    );
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

    final user = SessionService.currentUser!;
    final schoolId = user.schoolId;
    final dateStr = _getDateStr(_selectedDate);
    final isAdmin = user.role == 'school_admin';

    return ValueListenableBuilder<bool>(
      valueListenable: AuthBackground.isDarkMode,
      builder: (context, isDark, child) {
        return ValueListenableBuilder<String>(
          valueListenable: AppLocalization.currentLocale,
          builder: (context, locale, child) {
            final textColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
            final subTextColor = isDark ? Colors.white.withValues(alpha: 0.6) : const Color(0xFF1E1B4B).withValues(alpha: 0.6);
            final cardColor = isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white;
            final cardBorder = isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.06);
            final shadowColor = isDark ? Colors.black.withValues(alpha: 0.2) : Colors.black.withValues(alpha: 0.04);
            final searchBg = isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF1F5F9);

            return Scaffold(
              backgroundColor: isDark ? const Color(0xFF0B0914) : const Color(0xFFF8FAFC),
              appBar: AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                leading: IconButton(
                  icon: Icon(Icons.arrow_back_ios_new_rounded, color: textColor),
                  onPressed: () => Get.back(),
                ),
                title: Text(
                  _isMonthlyRecap
                      ? (AppLocalization.isIndonesian ? 'Rekap Bulanan Guru' : 'Monthly Teacher Recap')
                      : (AppLocalization.isIndonesian ? 'Absensi Harian Guru' : 'Daily Teacher Attendance'),
                  style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 18),
                ),
                centerTitle: true,
                actions: [
                  if (!_isMonthlyRecap) ...[
                    IconButton(
                      icon: Icon(Icons.calendar_month_rounded, color: textColor),
                      onPressed: _showDatePicker,
                      tooltip: AppLocalization.isIndonesian ? 'Pilih Tanggal' : 'Select Date',
                    ),
                    IconButton(
                      icon: Icon(Icons.picture_as_pdf_rounded, color: textColor),
                      onPressed: _exportDailyPdf,
                      tooltip: AppLocalization.isIndonesian ? 'Ekspor PDF' : 'Export PDF',
                    ),
                    IconButton(
                      icon: Icon(Icons.table_view_rounded, color: textColor),
                      onPressed: _exportDailyExcel,
                      tooltip: AppLocalization.isIndonesian ? 'Ekspor Excel' : 'Export Excel',
                    ),
                  ] else ...[
                    IconButton(
                      icon: Icon(Icons.picture_as_pdf_rounded, color: textColor),
                      onPressed: _exportMonthlyPdf,
                      tooltip: AppLocalization.isIndonesian ? 'Ekspor PDF' : 'Export PDF',
                    ),
                    IconButton(
                      icon: Icon(Icons.table_view_rounded, color: textColor),
                      onPressed: _exportMonthlyExcel,
                      tooltip: AppLocalization.isIndonesian ? 'Ekspor Excel' : 'Export Excel',
                    ),
                  ],
                ],
              ),
              body: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 12),

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
                            child: GestureDetector(
                              onTap: () => setState(() => _isMonthlyRecap = false),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  color: !_isMonthlyRecap ? const Color(0xFF8B5CF6) : Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Center(
                                  child: Text(
                                    AppLocalization.isIndonesian ? 'Presensi Harian' : 'Daily Attendance',
                                    style: TextStyle(
                                      color: !_isMonthlyRecap ? Colors.white : textColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() => _isMonthlyRecap = true),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  color: _isMonthlyRecap ? const Color(0xFF8B5CF6) : Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Center(
                                  child: Text(
                                    AppLocalization.isIndonesian ? 'Rekap Bulanan' : 'Monthly Recap',
                                    style: TextStyle(
                                      color: _isMonthlyRecap ? Colors.white : textColor,
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

                    if (!_isMonthlyRecap) ...[
                      // Selected Date Card Header
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFF8B5CF6).withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.calendar_today_rounded, color: Color(0xFF8B5CF6), size: 18),
                            const SizedBox(width: 10),
                            Text(
                              _getFormattedIndonesianDate(_selectedDate),
                              style: const TextStyle(
                                color: Color(0xFF8B5CF6),
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ] else ...[
                      // Month and Year Selectors Row
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: Container(
                              height: 48,
                              padding: const EdgeInsets.symmetric(horizontal: 14),
                              decoration: BoxDecoration(
                                color: cardColor,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: cardBorder),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<int>(
                                  isExpanded: true,
                                  value: _selectedMonth,
                                  dropdownColor: isDark ? const Color(0xFF0F0C20) : Colors.white,
                                  style: TextStyle(color: textColor, fontSize: 13, fontWeight: FontWeight.bold),
                                  items: List.generate(12, (index) {
                                    return DropdownMenuItem(
                                      value: index + 1,
                                      child: Text(_monthNames[index]),
                                    );
                                  }),
                                  onChanged: (val) {
                                    if (val != null) {
                                      setState(() => _selectedMonth = val);
                                    }
                                  },
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 1,
                            child: Container(
                              height: 48,
                              padding: const EdgeInsets.symmetric(horizontal: 14),
                              decoration: BoxDecoration(
                                color: cardColor,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: cardBorder),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<int>(
                                  isExpanded: true,
                                  value: _selectedYear,
                                  dropdownColor: isDark ? const Color(0xFF0F0C20) : Colors.white,
                                  style: TextStyle(color: textColor, fontSize: 13, fontWeight: FontWeight.bold),
                                  items: List.generate(5, (index) {
                                    final year = DateTime.now().year - 3 + index;
                                    return DropdownMenuItem(
                                      value: year,
                                      child: Text('$year'),
                                    );
                                  }),
                                  onChanged: (val) {
                                    if (val != null) {
                                      setState(() => _selectedYear = val);
                                    }
                                  },
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Search field (shared)
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 48,
                            decoration: BoxDecoration(
                              color: searchBg,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: cardBorder),
                            ),
                            child: TextField(
                              style: TextStyle(color: textColor, fontSize: 14),
                              decoration: InputDecoration(
                                hintText: AppLocalization.isIndonesian ? 'Cari nama guru...' : 'Search teacher name...',
                                hintStyle: TextStyle(color: subTextColor, fontSize: 13),
                                prefixIcon: Icon(Icons.search_rounded, color: subTextColor, size: 18),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                              onChanged: (val) {
                                setState(() {
                                  _searchQuery = val;
                                });
                              },
                            ),
                          ),
                        ),
                        if (!_isMonthlyRecap) ...[
                          const SizedBox(width: 12),
                          // Status Filter Selector (Harian only)
                          Container(
                            height: 48,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: cardColor,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: cardBorder),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _selectedStatusFilter,
                                dropdownColor: isDark ? const Color(0xFF0F0C20) : Colors.white,
                                style: TextStyle(color: textColor, fontSize: 13, fontWeight: FontWeight.bold),
                                icon: Icon(Icons.filter_list_rounded, color: textColor, size: 16),
                                items: [
                                  DropdownMenuItem(value: 'Semua', child: Text(AppLocalization.isIndonesian ? 'Semua' : 'All')),
                                  DropdownMenuItem(value: 'Hadir', child: Text(AppLocalization.isIndonesian ? 'Hadir' : 'Present')),
                                  DropdownMenuItem(value: 'Terlambat', child: Text(AppLocalization.isIndonesian ? 'Terlambat' : 'Late')),
                                  DropdownMenuItem(value: 'Sakit', child: Text(AppLocalization.isIndonesian ? 'Sakit' : 'Sick')),
                                  DropdownMenuItem(value: 'Izin', child: Text(AppLocalization.isIndonesian ? 'Izin' : 'Permitted')),
                                  DropdownMenuItem(value: 'Alfa', child: Text(AppLocalization.isIndonesian ? 'Alfa' : 'Absent')),
                                ],
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() {
                                      _selectedStatusFilter = val;
                                    });
                                  }
                                },
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Streams for Teachers List
                    Expanded(
                      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: _teacherService.getTeachers(schoolId),
                        builder: (context, teacherSnapshot) {
                          if (teacherSnapshot.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator(color: Color(0xFF8B5CF6)));
                          }
                          if (!teacherSnapshot.hasData || teacherSnapshot.data!.docs.isEmpty) {
                            return Center(
                              child: Text(
                                AppLocalization.isIndonesian ? 'Belum ada data guru terdaftar.' : 'No teachers registered.',
                                style: TextStyle(color: subTextColor),
                              ),
                            );
                          }

                      if (!_isMonthlyRecap) {
                        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                          stream: FirebaseFirestore.instance
                              .collection('schools')
                              .doc(schoolId)
                              .collection('teacher_daily_attendance')
                              .where('date', isEqualTo: dateStr)
                              .snapshots(),
                          builder: (context, attendanceSnapshot) {
                            if (attendanceSnapshot.connectionState == ConnectionState.waiting) {
                              return const Center(child: CircularProgressIndicator(color: Color(0xFF8B5CF6)));
                            }

                            // Mapping: teacherId -> attendanceDocData
                            final Map<String, Map<String, dynamic>> attMap = {};
                            if (attendanceSnapshot.hasData) {
                              for (var doc in attendanceSnapshot.data!.docs) {
                                final d = doc.data();
                                final tId = d['teacherId'] as String?;
                                if (tId != null) {
                                  attMap[tId] = d;
                                }
                              }
                            }

                            final teachersList = teacherSnapshot.data!.docs;
                            final processedList = <Map<String, dynamic>>[];

                            // Hitung statistik
                            int countHadir = 0;
                            int countTerlambat = 0;
                            int countIzinSakit = 0;
                            int countAlfa = 0;

                            for (var doc in teachersList) {
                              final tData = doc.data();
                              final tId = doc.id;
                              final name = tData['nama'] ?? 'Guru';
                              final nip = tData['nip'] ?? '';
                              
                              final attendance = attMap[tId];
                              String status = attendance != null ? (attendance['status'] ?? 'hadir').toString().toLowerCase() : 'alfa';
                              if (status == 'alpha') status = 'alfa';

                              if (status == 'hadir') countHadir++;
                              if (status == 'terlambat') countTerlambat++;
                              if (status == 'sakit' || status == 'izin') countIzinSakit++;
                              if (status == 'alfa') countAlfa++;

                              // Filter Pencarian Nama
                              if (_searchQuery.isNotEmpty &&
                                  !name.toLowerCase().contains(_searchQuery.toLowerCase())) {
                                continue;
                              }

                              // Filter Status
                              if (_selectedStatusFilter != 'Semua') {
                                if (_selectedStatusFilter == 'Hadir' && status != 'hadir') continue;
                                if (_selectedStatusFilter == 'Terlambat' && status != 'terlambat') continue;
                                if (_selectedStatusFilter == 'Sakit' && status != 'sakit') continue;
                                if (_selectedStatusFilter == 'Izin' && status != 'izin') continue;
                                if (_selectedStatusFilter == 'Alfa' && status != 'alfa') continue;
                              }

                              processedList.add({
                                'teacherId': tId,
                                'teacherName': name,
                                'nip': nip,
                                'status': status,
                                'attendance': attendance,
                              });
                            }

                            // UI: attended first, then alfa A-Z. Attended are also sorted A-Z.
                            final attendedTeachers = processedList
                                .where((e) => (e['status'] as String).toLowerCase() != 'alfa')
                                .toList()
                              ..sort((a, b) => (a['teacherName'] as String)
                                  .toLowerCase()
                                  .compareTo((b['teacherName'] as String).toLowerCase()));
                            final alfaTeachers = processedList
                                .where((e) => (e['status'] as String).toLowerCase() == 'alfa')
                                .toList()
                              ..sort((a, b) => (a['teacherName'] as String).toLowerCase().compareTo((b['teacherName'] as String).toLowerCase()));
                            final sortedList = [...attendedTeachers, ...alfaTeachers];
                            processedList
                              ..clear()
                              ..addAll(sortedList);

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Statistik Widget Row
                                SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  physics: const BouncingScrollPhysics(),
                                  child: Row(
                                    children: [
                                      _buildStatTile('Hadir', '$countHadir', const Color(0xFF10B981), cardColor, cardBorder),
                                      const SizedBox(width: 10),
                                      _buildStatTile('Terlambat', '$countTerlambat', const Color(0xFFF59E0B), cardColor, cardBorder),
                                      const SizedBox(width: 10),
                                      _buildStatTile('Izin/Sakit', '$countIzinSakit', const Color(0xFF3B82F6), cardColor, cardBorder),
                                      const SizedBox(width: 10),
                                      _buildStatTile('Belum Absen', '$countAlfa', const Color(0xFFEF4444), cardColor, cardBorder),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),

                                // Header list
                                Row(
                                  children: [
                                    Icon(Icons.people_rounded, color: textColor.withValues(alpha: 0.8), size: 16),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Daftar Kehadiran Guru (${processedList.length})',
                                      style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 13),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),

                                // List View
                                Expanded(
                                  child: processedList.isEmpty
                                      ? Center(
                                          child: Text(
                                            'Tidak ada data guru yang sesuai filter.',
                                            style: TextStyle(color: subTextColor, fontSize: 14),
                                          ),
                                        )
                                      : ListView.separated(
                                          itemCount: processedList.length,
                                          physics: const BouncingScrollPhysics(),
                                          separatorBuilder: (context, index) => const SizedBox(height: 10),
                                          itemBuilder: (context, index) {
                                            final item = processedList[index];
                                            final tId = item['teacherId'] as String;
                                            final name = item['teacherName'] as String;
                                            final nip = item['nip'] as String;
                                            final status = item['status'] as String;
                                            final att = item['attendance'] as Map<String, dynamic>?;

                                            final checkInTime = att != null ? att['checkInTime'] as Timestamp? : null;
                                            final checkOutTime = att != null ? att['checkOutTime'] as Timestamp? : null;

                                            return Container(
                                              decoration: BoxDecoration(
                                                color: cardColor,
                                                borderRadius: BorderRadius.circular(16),
                                                border: Border.all(color: cardBorder),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: shadowColor,
                                                    blurRadius: 10,
                                                    offset: const Offset(0, 4),
                                                  ),
                                                ],
                                              ),
                                              child: Material(
                                                color: Colors.transparent,
                                                child: InkWell(
                                                  onTap: isAdmin ? () => _showEditAttendanceModal(
                                                    schoolId: schoolId,
                                                    teacherId: tId,
                                                    teacherName: name,
                                                    nip: nip,
                                                    currentData: att,
                                                  ) : null,
                                                  borderRadius: BorderRadius.circular(16),
                                                  child: Padding(
                                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                                    child: Row(
                                                      children: [
                                                        Expanded(
                                                          child: Column(
                                                            crossAxisAlignment: CrossAxisAlignment.start,
                                                            children: [
                                                              Text(
                                                                name,
                                                                style: TextStyle(
                                                                  color: textColor,
                                                                  fontWeight: FontWeight.bold,
                                                                  fontSize: 14,
                                                                ),
                                                              ),
                                                              const SizedBox(height: 4),
                                                              Text(
                                                                'NIP: $nip',
                                                                style: TextStyle(color: subTextColor, fontSize: 12),
                                                              ),
                                                              if (checkInTime != null) ...[
                                                                const SizedBox(height: 6),
                                                                Row(
                                                                  children: [
                                                                    Icon(Icons.login_rounded, color: const Color(0xFF10B981).withValues(alpha: 0.8), size: 12),
                                                                    const SizedBox(width: 4),
                                                                    Text(
                                                                      _formatTime(checkInTime),
                                                                      style: TextStyle(color: subTextColor, fontSize: 12),
                                                                    ),
                                                                    const SizedBox(width: 12),
                                                                    Icon(Icons.logout_rounded, color: Colors.orange.withValues(alpha: 0.8), size: 12),
                                                                    const SizedBox(width: 4),
                                                                    Text(
                                                                      checkOutTime != null ? _formatTime(checkOutTime) : '--:--',
                                                                      style: TextStyle(color: subTextColor, fontSize: 12),
                                                                    ),
                                                                  ],
                                                                ),
                                                              ],
                                                            ],
                                                          ),
                                                        ),
                                                        _buildStatusBadge(status),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                ),
                              ],
                            );
                          },
                        );
                      } else {
                        final year = _selectedYear;
                        final monthStr = _selectedMonth.toString().padLeft(2, '0');
                        final startOfDate = '$year-$monthStr-01';
                        final endOfDate = '$year-$monthStr-31';

                        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                          stream: FirebaseFirestore.instance
                              .collection('schools')
                              .doc(schoolId)
                              .collection('teacher_daily_attendance')
                              .where('date', isGreaterThanOrEqualTo: startOfDate)
                              .where('date', isLessThanOrEqualTo: endOfDate)
                              .snapshots(),
                          builder: (context, attendanceSnapshot) {
                            if (attendanceSnapshot.connectionState == ConnectionState.waiting) {
                              return const Center(child: CircularProgressIndicator(color: Color(0xFF8B5CF6)));
                            }

                            final Map<String, Map<String, int>> recapMap = {};
                            if (attendanceSnapshot.hasData) {
                              for (var doc in attendanceSnapshot.data!.docs) {
                                final d = doc.data();
                                final tId = d['teacherId'] as String?;
                                final status = d['status'] as String?;
                                final checkOutTime = d['checkOutTime'];
                                if (tId != null && status != null) {
                                  recapMap.putIfAbsent(tId, () => {
                                    'hadir': 0,
                                    'terlambat': 0,
                                    'sakit': 0,
                                    'izin': 0,
                                    'alfa': 0,
                                    'pulang': 0,
                                  });
                                  final normStatus = status.toLowerCase();
                                  if (recapMap[tId]!.containsKey(normStatus)) {
                                    recapMap[tId]![normStatus] = recapMap[tId]![normStatus]! + 1;
                                  } else if (normStatus == 'alfa' || normStatus == 'alpha') {
                                    recapMap[tId]!['alfa'] = recapMap[tId]!['alfa']! + 1;
                                  }
                                  if (checkOutTime != null) {
                                    recapMap[tId]!['pulang'] = recapMap[tId]!['pulang']! + 1;
                                  }
                                }
                              }
                            }

                            final teachersList = teacherSnapshot.data!.docs;
                            final filteredTeachers = teachersList.where((doc) {
                              final tData = doc.data();
                              final name = tData['nama'] ?? 'Guru';
                              if (_searchQuery.isNotEmpty &&
                                  !name.toLowerCase().contains(_searchQuery.toLowerCase())) {
                                return false;
                              }
                              return true;
                            }).toList();

                            if (filteredTeachers.isEmpty) {
                              return Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(24.0),
                                  child: Text(
                                    'Tidak ada data guru yang cocok.',
                                    style: TextStyle(color: subTextColor, fontSize: 13),
                                  ),
                                ),
                              );
                            }

                            // Sort teachers alphabetically
                            filteredTeachers.sort((a, b) {
                              final nameA = (a.data()['nama'] ?? 'Guru').toString();
                              final nameB = (b.data()['nama'] ?? 'Guru').toString();
                              return nameA.compareTo(nameB);
                            });

                            return ListView.builder(
                              padding: const EdgeInsets.only(top: 8, bottom: 24),
                              physics: const BouncingScrollPhysics(),
                              itemCount: filteredTeachers.length,
                              itemBuilder: (context, index) {
                                final doc = filteredTeachers[index];
                                final tData = doc.data();
                                final tId = doc.id;
                                final name = tData['nama'] ?? 'Guru';
                                final nip = tData['nip'] ?? '-';

                                final counts = recapMap[tId] ?? {
                                  'hadir': 0,
                                  'terlambat': 0,
                                  'sakit': 0,
                                  'izin': 0,
                                  'alfa': 0,
                                  'pulang': 0,
                                };

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: cardColor,
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(color: cardBorder),
                                    boxShadow: [
                                      BoxShadow(
                                        color: shadowColor,
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          CircleAvatar(
                                            backgroundColor: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                                            child: const Icon(Icons.person_rounded, color: Color(0xFF8B5CF6)),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  name,
                                                  style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 14),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  'NIP: $nip',
                                                  style: TextStyle(color: subTextColor, fontSize: 12),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 16),
                                      const Divider(height: 1),
                                      const SizedBox(height: 12),
                                      SingleChildScrollView(
                                        scrollDirection: Axis.horizontal,
                                        child: Row(
                                          children: [
                                            _buildCountBadge(AppLocalization.isIndonesian ? 'Hadir' : 'Present', counts['hadir']!, const Color(0xFF10B981)),
                                            const SizedBox(width: 8),
                                            _buildCountBadge(AppLocalization.isIndonesian ? 'Telat' : 'Late', counts['terlambat']!, const Color(0xFFF59E0B)),
                                            const SizedBox(width: 8),
                                            _buildCountBadge(AppLocalization.isIndonesian ? 'Pulang' : 'Checked Out', counts['pulang'] ?? 0, const Color(0xFF0D9488)),
                                            const SizedBox(width: 8),
                                            _buildCountBadge(AppLocalization.isIndonesian ? 'Sakit' : 'Sick', counts['sakit']!, const Color(0xFF3B82F6)),
                                            const SizedBox(width: 8),
                                            _buildCountBadge(AppLocalization.isIndonesian ? 'Izin' : 'Permitted', counts['izin']!, const Color(0xFF8B5CF6)),
                                            const SizedBox(width: 8),
                                            _buildCountBadge(AppLocalization.isIndonesian ? 'Alfa' : 'Absent', counts['alfa']!, const Color(0xFFEF4444)),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            );
                          },
                        );
                      }
                    },
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
            );
          },
        );
      },
    );
  }

  Widget _buildStatTile(String label, String value, Color color, Color cardBg, Color cardBorder) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.grey),
          ),
          Text(
            value,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }
}
