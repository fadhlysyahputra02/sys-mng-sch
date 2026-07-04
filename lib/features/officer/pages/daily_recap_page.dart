import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:excel/excel.dart' hide Border;
import 'dart:io';
import 'package:path_provider/path_provider.dart';

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
              title: const Row(
                children: [
                  Icon(Icons.lock_rounded, color: Colors.amber),
                  SizedBox(width: 8),
                  Text('Fitur Terkunci', style: TextStyle(color: Colors.white)),
                ],
              ),
              content: const Text(
                'Fitur Rekap Absensi Siswa dinonaktifkan oleh Super Admin. Silakan hubungi Super Admin untuk mengaktifkan akses.',
                style: TextStyle(color: Colors.white70),
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
        // Sort by time
        _recapData.sort((a, b) {
          final ta = a['timestamp'] as dynamic;
          final tb = b['timestamp'] as dynamic;
          if (ta == null || tb == null) return 0;
          return tb.compareTo(ta); // Descending
        });
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
    final pdf = pw.Document();
    
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Laporan Kehadiran Harian', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 8),
              pw.Text('Tanggal: ${DateFormat('dd MMMM yyyy').format(_selectedDate)}'),
              pw.SizedBox(height: 24),
              pw.Table.fromTextArray(
                headers: ['No', 'Nama Siswa', 'Kelas', 'Masuk', 'Pulang', 'Status', 'Metode'],
                data: List<List<String>>.generate(_recapData.length, (index) {
                  final item = _recapData[index];
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
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Rekap_Kehadiran_${DateFormat('yyyyMMdd').format(_selectedDate)}.pdf',
    );
  }

  Future<void> _exportExcel() async {
    try {
      var excelFile = Excel.createExcel();
      Sheet sheetObject = excelFile['Sheet1'];
      
      // Header
      sheetObject.appendRow([
        TextCellValue('No'),
        TextCellValue('Nama Siswa'),
        TextCellValue('Kelas'),
        TextCellValue('Masuk'),
        TextCellValue('Pulang'),
        TextCellValue('Status'),
        TextCellValue('Metode'),
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
      final fileName = 'rekap absensi harian siswa ($schoolName) tanggal ${DateFormat('yyyyMMdd').format(_selectedDate)}.xlsx';

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
              'Rekap Harian Murid',
              style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.picture_as_pdf_rounded),
                onPressed: _recapData.isEmpty ? null : _exportPdf,
                tooltip: 'Export PDF',
              ),
              IconButton(
                icon: const Icon(Icons.table_view_rounded),
                onPressed: _recapData.isEmpty ? null : _exportExcel,
                tooltip: 'Export Excel',
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
                              child: const Center(
                                child: Text(
                                  'Presensi Harian',
                                  style: TextStyle(
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
                                    'Rekap Bulanan',
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
                              Icon(Icons.calendar_month_rounded, color: const Color(0xFF6366F1), size: 24),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Tanggal', style: TextStyle(color: subTextColor, fontSize: 12)),
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
                            child: const Text('Ubah'),
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
                          Expanded(flex: 2, child: Text('Siswa', style: TextStyle(color: textColor, fontWeight: FontWeight.bold))),
                          Expanded(flex: 1, child: Text('Kelas', style: TextStyle(color: textColor, fontWeight: FontWeight.bold))),
                          Expanded(flex: 1, child: Text('Masuk', style: TextStyle(color: textColor, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                          Expanded(flex: 1, child: Text('Pulang', style: TextStyle(color: textColor, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                          Expanded(flex: 1, child: Text('Status', style: TextStyle(color: textColor, fontWeight: FontWeight.bold), textAlign: TextAlign.end)),
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
                            ? Center(child: Text('Tidak ada data kehadiran.', style: TextStyle(color: subTextColor)))
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
  }
}
