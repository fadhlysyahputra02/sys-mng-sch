import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import '../services/library_service.dart';
import '../../students/pages/student_qr_scanner_page.dart';

class VisitorLogTab extends StatefulWidget {
  final bool isDark;

  const VisitorLogTab({super.key, required this.isDark});

  @override
  State<VisitorLogTab> createState() => _VisitorLogTabState();
}

class _VisitorLogTabState extends State<VisitorLogTab> {
  final LibraryService _libraryService = LibraryService();
  String _searchQuery = '';

  void _showNotification(String title, String message, bool isSuccess) {
    Get.snackbar(
      title,
      message,
      backgroundColor: isSuccess ? const Color(0xFF10B981) : Colors.red,
      colorText: Colors.white,
      snackPosition: SnackPosition.TOP,
      margin: const EdgeInsets.all(16),
      borderRadius: 12,
    );
  }

  void _scanVisitor() async {
    final result = await Get.to<String>(() => const StudentQrScannerPage(
          title: 'Scan QR Buku Tamu',
          subtitle: 'Arahkan kamera ke QR Kartu Siswa untuk mencatat kunjungan',
        ));

    if (result != null && result.isNotEmpty) {
      try {
        final Map<String, dynamic> payload = jsonDecode(result);
        final studentId = payload['studentId']?.toString() ?? '';
        final studentNis = payload['nis']?.toString() ?? '';
        final studentName = payload['nama']?.toString() ?? '';
        final className = payload['className']?.toString() ?? '-';

        if (studentId.isEmpty || studentName.isEmpty) {
          _showNotification('Gagal', 'Data QR Siswa tidak valid.', false);
          return;
        }

        await _libraryService.recordVisitor(
          studentId: studentId,
          studentNis: studentNis,
          studentName: studentName,
          className: className,
        );

        _showNotification(
          'Berhasil Mencatat Kunjungan',
          'Selamat datang di perpustakaan, $studentName!',
          true,
        );
      } catch (e) {
        _showNotification('Gagal', 'Format QR Code tidak dikenali.', false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final textColor = widget.isDark ? Colors.white : const Color(0xFF1E1B4B);
    final subTextColor = widget.isDark ? Colors.white.withOpacity(0.6) : const Color(0xFF1E1B4B).withOpacity(0.6);
    final fieldFill = widget.isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.02);
    final fieldBorder = widget.isDark ? Colors.white.withOpacity(0.15) : Colors.black.withOpacity(0.12);
    final cardBg = widget.isDark ? Colors.white.withOpacity(0.04) : Colors.white;

    return Column(
      children: [
        // Action Bar (Search + Scan Visitor Button)
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  style: TextStyle(color: textColor, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Cari nama pengunjung atau NIS...',
                    hintStyle: TextStyle(color: subTextColor, fontSize: 14),
                    prefixIcon: Icon(Icons.search_rounded, color: subTextColor, size: 20),
                    filled: true,
                    fillColor: fieldFill,
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: fieldBorder),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Color(0xFF6366F1), width: 1.5),
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  ),
                  onChanged: (v) {
                    setState(() {
                      _searchQuery = v.trim().toLowerCase();
                    });
                  },
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: _scanVisitor,
                icon: const Icon(Icons.qr_code_scanner_rounded, color: Colors.white, size: 18),
                label: const Text('Scan QR', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF59E0B),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
            ],
          ),
        ),

        // Visitors Log List
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _libraryService.getVisitors(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.people_outline_rounded, size: 48, color: subTextColor.withOpacity(0.5)),
                      const SizedBox(height: 12),
                      Text('Belum ada log kunjungan perpustakaan.', style: TextStyle(color: subTextColor)),
                    ],
                  ),
                );
              }

              final visitors = snapshot.data!.docs.where((doc) {
                final d = doc.data() as Map<String, dynamic>;
                final name = (d['studentName'] ?? '').toString().toLowerCase();
                final nis = (d['studentNis'] ?? '').toString().toLowerCase();
                final className = (d['className'] ?? '').toString().toLowerCase();
                return name.contains(_searchQuery) || nis.contains(_searchQuery) || className.contains(_searchQuery);
              }).toList();

              if (visitors.isEmpty) {
                return Center(
                  child: Text('Data kunjungan tidak ditemukan.', style: TextStyle(color: subTextColor)),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                itemCount: visitors.length,
                itemBuilder: (context, index) {
                  final doc = visitors[index];
                  final data = doc.data() as Map<String, dynamic>;
                  final name = data['studentName'] ?? '-';
                  final nis = data['studentNis'] ?? '-';
                  final className = data['className'] ?? '-';
                  final time = data['timestamp'] as Timestamp?;
                  
                  String formattedDate = '-';
                  String formattedTime = '-';
                  if (time != null) {
                    final dt = time.toDate();
                    formattedDate = '${dt.day}/${dt.month}/${dt.year}';
                    formattedTime = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
                  }

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: fieldBorder),
                      boxShadow: widget.isDark
                          ? []
                          : [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.02),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF59E0B).withOpacity(0.12),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.person_outline_rounded,
                            color: Color(0xFFF59E0B),
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: textColor,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'NIS: $nis • Kelas: $className',
                                style: TextStyle(fontSize: 12, color: subTextColor),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              formattedDate,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: textColor,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              formattedTime,
                              style: TextStyle(
                                fontSize: 11,
                                color: subTextColor,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
