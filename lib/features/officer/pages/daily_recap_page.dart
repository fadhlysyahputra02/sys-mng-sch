import 'package:flutter/material.dart';
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

  @override
  void initState() {
    super.initState();
    _fetchData();
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
                headers: ['No', 'Nama Siswa', 'Kelas', 'Waktu', 'Status', 'Metode'],
                data: List<List<String>>.generate(_recapData.length, (index) {
                  final item = _recapData[index];
                  final time = (item['timestamp'] as dynamic)?.toDate();
                  final timeStr = time != null ? DateFormat('HH:mm').format(time) : '-';
                  return [
                    (index + 1).toString(),
                    item['studentName'] ?? '-',
                    item['className'] ?? '-',
                    timeStr,
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
        TextCellValue('Waktu'),
        TextCellValue('Status'),
        TextCellValue('Metode'),
      ]);

      for (int i = 0; i < _recapData.length; i++) {
        final item = _recapData[i];
        final time = (item['timestamp'] as dynamic)?.toDate();
        final timeStr = time != null ? DateFormat('HH:mm').format(time) : '-';
        
        sheetObject.appendRow([
          IntCellValue(i + 1),
          TextCellValue(item['studentName'] ?? '-'),
          TextCellValue(item['className'] ?? '-'),
          TextCellValue(timeStr),
          TextCellValue((item['status'] ?? '-').toString().toUpperCase()),
          TextCellValue(item['method'] == 'qr_scan' ? 'QR Code' : 'Manual'),
        ]);
      }

      final bytes = excelFile.save();
      if (bytes == null) throw ('Gagal generate file Excel');
      
      // Simpan ke direktori dokumen
      final dir = await getApplicationDocumentsDirectory();
      final fileName = 'Rekap_Kehadiran_${DateFormat('yyyyMMdd').format(_selectedDate)}.xlsx';
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(bytes);

      Get.snackbar(
        'Berhasil',
        'File Excel disimpan di: ${file.path}',
        backgroundColor: const Color(0xFF10B981),
        colorText: Colors.white,
        duration: const Duration(seconds: 5),
      );
    } catch (e) {
      Get.snackbar('Error', 'Gagal export excel: $e', backgroundColor: Colors.red, colorText: Colors.white);
    }
  }

  @override
  Widget build(BuildContext context) {
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
              'Rekap Harian',
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
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
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
                          Expanded(flex: 1, child: Text('Jam', style: TextStyle(color: textColor, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
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
                                  final time = (item['timestamp'] as dynamic)?.toDate();
                                  final timeStr = time != null ? DateFormat('HH:mm').format(time) : '-';
                                  
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
                                            timeStr,
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
