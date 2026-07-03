import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import '../services/library_service.dart';
import '../../../core/widgets/motif_card.dart';
import '../../students/pages/student_qr_scanner_page.dart';

class DashboardHomeTab extends StatelessWidget {
  final bool isDark;
  final Function(int) onTabChange;

  DashboardHomeTab({
    super.key,
    required this.isDark,
    required this.onTabChange,
  });

  final LibraryService _libraryService = LibraryService();

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

  void _scanVisitor(BuildContext context) async {
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

  bool _isToday(DateTime dateTime) {
    final now = DateTime.now();
    return dateTime.year == now.year &&
        dateTime.month == now.month &&
        dateTime.day == now.day;
  }

  @override
  Widget build(BuildContext context) {
    final textColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
    final subtitleColor = isDark ? Colors.white70 : const Color(0xFF1E1B4B).withOpacity(0.7);
    final cardBg = isDark ? Colors.white.withOpacity(0.06) : Colors.white;
    final borderCol = isDark ? Colors.white.withOpacity(0.1) : const Color(0xFF1E1B4B).withOpacity(0.08);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Welcome Card
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 24),
            child: MotifCard(
              isDark: isDark,
              cardBorderColor: Colors.transparent,
              cardShadowColor: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
              gradient: const LinearGradient(
                colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Layanan Perpustakaan Digital',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Kelola katalog buku, sirkulasi peminjaman, serta kehadiran pengunjung dengan mudah dan efisien.',
                    style: TextStyle(fontSize: 13, color: Colors.black.withOpacity(0.85)),
                  ),
                  const SizedBox(height: 18),
                  Center(
                    child: Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 12,
                      runSpacing: 10,
                      children: [
                        ElevatedButton.icon(
                          onPressed: () => _scanVisitor(context),
                          icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
                          label: const Text('Scan QR Pengunjung'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => onTabChange(2),
                          icon: const Icon(Icons.swap_horiz_rounded, size: 18, color: Colors.black),
                          label: const Text('Catat Peminjaman', style: TextStyle(color: Colors.black)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.black, width: 1.5),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Metrics
          StreamBuilder<QuerySnapshot>(
            stream: _libraryService.getBooks(),
            builder: (context, booksSnapshot) {
              return StreamBuilder<QuerySnapshot>(
                stream: _libraryService.getLoans(),
                builder: (context, loansSnapshot) {
                  return StreamBuilder<QuerySnapshot>(
                    stream: _libraryService.getVisitors(),
                    builder: (context, visitorsSnapshot) {
                      final totalBooks = booksSnapshot.data?.docs.length ?? 0;
                      final activeLoans = (loansSnapshot.data?.docs ?? [])
                          .where((doc) => doc['status'] == 'Dipinjam')
                          .length;
                      final todayVisitors = (visitorsSnapshot.data?.docs ?? [])
                          .where((doc) {
                            final ts = doc['timestamp'] as Timestamp?;
                            if (ts == null) return false;
                            return _isToday(ts.toDate());
                          })
                          .length;

                      return GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: MediaQuery.of(context).size.width > 600 ? 3 : 1,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: 2.2,
                        children: [
                          _buildMetricCard(title: 'Katalog Buku', value: '$totalBooks Buku', icon: Icons.menu_book_rounded, color: const Color(0xFF6366F1)),
                          _buildMetricCard(title: 'Peminjaman Aktif', value: '$activeLoans Transaksi', icon: Icons.swap_horiz_rounded, color: const Color(0xFF10B981)),
                          _buildMetricCard(title: 'Pengunjung Hari Ini', value: '$todayVisitors Siswa', icon: Icons.people_rounded, color: const Color(0xFFF59E0B)),
                        ],
                      );
                    },
                  );
                },
              );
            },
          ),

          const SizedBox(height: 32),

          // Notifikasi Buku Terlambat
          StreamBuilder<QuerySnapshot>(
            stream: _libraryService.getLoans(),
            builder: (context, snapshot) {
              final overdue = (snapshot.data?.docs ?? []).where((doc) {
                final d = doc.data() as Map<String, dynamic>;
                if (d['status'] != 'Dipinjam') return false;
                final dueDate = (d['dueDate'] as Timestamp?)?.toDate();
                return dueDate != null && DateTime.now().isAfter(dueDate);
              }).toList();

              if (overdue.isEmpty) return const SizedBox.shrink();

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.notifications_active_rounded, color: Colors.red, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Buku Belum Dikembalikan (${overdue.length})',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.red),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Buku berikut telah melewati tanggal pengembalian.',
                    style: TextStyle(fontSize: 12, color: subtitleColor),
                  ),
                  const SizedBox(height: 12),
                  ...overdue.map((doc) {
                    final d = doc.data() as Map<String, dynamic>;
                    final dueDate = (d['dueDate'] as Timestamp?)!.toDate();
                    final daysLate = DateTime.now().difference(dueDate).inDays;
                    return _buildOverdueBanner(
                      bookTitle: d['bookTitle'] ?? '-',
                      studentName: d['studentName'] ?? '-',
                      className: d['className'] ?? '-',
                      daysLate: daysLate < 1 ? 1 : daysLate,
                      textColor: textColor,
                    );
                  }),
                  const SizedBox(height: 20),
                ],
              );
            },
          ),

          // Kunjungan Hari Ini
          Text(
            'Kunjungan Hari Ini',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor),
          ),
          const SizedBox(height: 12),

          StreamBuilder<QuerySnapshot>(
            stream: _libraryService.getVisitors(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final docs = (snapshot.data?.docs ?? []).where((doc) {
                final timestamp = doc['timestamp'] as Timestamp?;
                if (timestamp == null) return false;
                return _isToday(timestamp.toDate());
              }).take(5).toList();

              if (docs.isEmpty) {
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: borderCol),
                  ),
                  child: Center(
                    child: Text(
                      'Belum ada pengunjung perpustakaan hari ini.',
                      style: TextStyle(color: subtitleColor, fontSize: 13),
                    ),
                  ),
                );
              }

              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final data = docs[index].data() as Map<String, dynamic>;
                  final name = data['studentName'] ?? '-';
                  final nis = data['studentNis'] ?? '-';
                  final className = data['className'] ?? '-';
                  final time = data['timestamp'] as Timestamp?;
                  final formattedTime = time != null
                      ? '${time.toDate().hour.toString().padLeft(2, '0')}:${time.toDate().minute.toString().padLeft(2, '0')}'
                      : '--:--';

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: borderCol),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF59E0B).withOpacity(0.12),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.person_outline_rounded, color: Color(0xFFF59E0B), size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: textColor)),
                              const SizedBox(height: 2),
                              Text('NIS: $nis • Kelas $className', style: TextStyle(fontSize: 12, color: subtitleColor)),
                            ],
                          ),
                        ),
                        Text(formattedTime, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: subtitleColor)),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildOverdueBanner({
    required String bookTitle,
    required String studentName,
    required String className,
    required int daysLate,
    required Color textColor,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: Colors.red.withOpacity(0.12), shape: BoxShape.circle),
            child: const Icon(Icons.alarm_off_rounded, color: Colors.red, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  bookTitle,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.red),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text('$studentName • Kelas $className', style: TextStyle(fontSize: 12, color: textColor.withOpacity(0.7))),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: Colors.red.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
            child: Text('+$daysLate hari', style: const TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    final borderCol = isDark ? Colors.white.withOpacity(0.1) : const Color(0xFF1E1B4B).withOpacity(0.08);
    final cardBg = isDark ? Colors.white.withOpacity(0.04) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1E1B4B);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderCol),
        boxShadow: isDark ? [] : [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(16)),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : const Color(0xFF1E1B4B).withOpacity(0.6))),
                const SizedBox(height: 4),
                Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
