import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import '../services/library_service.dart';
import '../../../core/widgets/motif_card.dart';
import '../../students/pages/student_qr_scanner_page.dart';
import '../../../core/localization/app_localization.dart';

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
          subtitle: 'Arahkan kamera ke QR Kartu Siswa/Guru untuk mencatat kunjungan',
        ));

    if (result != null && result.isNotEmpty) {
      try {
        final Map<String, dynamic> payload = jsonDecode(result);
        final isTeacher = payload['role']?.toString().toLowerCase() == 'teacher';

        final id = isTeacher 
            ? (payload['teacherId']?.toString() ?? '')
            : (payload['studentId']?.toString() ?? '');
        final nis = isTeacher
            ? (payload['nip']?.toString() ?? '')
            : (payload['nis']?.toString() ?? '');
        final name = payload['nama']?.toString() ?? '';
        final className = isTeacher ? 'GURU' : (payload['className']?.toString() ?? '-');
        final role = isTeacher ? 'teacher' : 'student';

        if (id.isEmpty || name.isEmpty) {
          _showNotification(
            AppLocalization.isIndonesian ? 'Gagal' : 'Failed',
            AppLocalization.isIndonesian ? 'Data QR tidak valid.' : 'Invalid QR data.',
            false,
          );
          return;
        }

        await _libraryService.recordVisitor(
          studentId: id,
          studentNis: nis,
          studentName: name,
          className: className,
          role: role,
        );

        _showNotification(
          AppLocalization.isIndonesian ? 'Berhasil Mencatat Kunjungan' : 'Visit Recorded Successfully',
          AppLocalization.isIndonesian ? 'Selamat datang di perpustakaan, $name!' : 'Welcome to the library, $name!',
          true,
        );
      } catch (e) {
        _showNotification(
          AppLocalization.isIndonesian ? 'Gagal' : 'Failed',
          AppLocalization.isIndonesian ? 'Format QR Code tidak dikenali.' : 'QR Code format unrecognized.',
          false,
        );
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
              cardShadowColor: Colors.black.withOpacity(isDark ? 0.25 : 0.08),
              gradient: const LinearGradient(
                colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)], // Premium rich indigo-violet gradient
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Elegant Pill Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withOpacity(0.2)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.stars_rounded, color: Colors.amber, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          AppLocalization.isIndonesian ? 'Sirkulasi Digital' : 'Digital Circulation',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    AppLocalization.isIndonesian ? 'Layanan Perpustakaan Digital' : 'Digital Library Services',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    AppLocalization.isIndonesian
                        ? 'Kelola katalog buku, sirkulasi peminjaman, serta kehadiran pengunjung dengan cepat, mudah, dan efisien.'
                        : 'Manage book catalogs, loan circulation, and visitor attendance quickly, easily, and efficiently.',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withOpacity(0.88),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 22),
                  Wrap(
                    spacing: 12,
                    runSpacing: 10,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () => _scanVisitor(context),
                        icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
                        label: Text(
                          AppLocalization.isIndonesian ? 'Scan QR Pengunjung' : 'Scan Visitor QR',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF4F46E5),
                          elevation: 4,
                          shadowColor: Colors.black.withOpacity(0.15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => onTabChange(2),
                        icon: const Icon(Icons.swap_horiz_rounded, size: 18, color: Colors.white),
                        label: Text(
                          AppLocalization.isIndonesian ? 'Catat Peminjaman' : 'Record Loan',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: Colors.white.withOpacity(0.4), width: 1.5),
                          backgroundColor: Colors.white.withOpacity(0.12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        ),
                      ),
                    ],
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
                          _buildMetricCard(
                            title: AppLocalization.isIndonesian ? 'Katalog Buku' : 'Book Catalog',
                            value: '$totalBooks ' + (AppLocalization.isIndonesian ? 'Buku' : 'Books'),
                            icon: Icons.menu_book_rounded,
                            color: const Color(0xFF6366F1),
                          ),
                          _buildMetricCard(
                            title: AppLocalization.isIndonesian ? 'Peminjaman Aktif' : 'Active Loans',
                            value: '$activeLoans ' + (AppLocalization.isIndonesian ? 'Transaksi' : 'Transactions'),
                            icon: Icons.swap_horiz_rounded,
                            color: const Color(0xFF10B981),
                          ),
                          _buildMetricCard(
                            title: AppLocalization.isIndonesian ? 'Pengunjung Hari Ini' : 'Today Visitors',
                            value: '$todayVisitors ' + (AppLocalization.isIndonesian ? 'Siswa' : 'Students'),
                            icon: Icons.people_rounded,
                            color: const Color(0xFFF59E0B),
                          ),
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
                if (dueDate == null) return false;
                final now = DateTime.now();
                final today = DateTime(now.year, now.month, now.day);
                final due = DateTime(dueDate.year, dueDate.month, dueDate.day);
                return today.isAfter(due);
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
                        (AppLocalization.isIndonesian ? 'Buku Belum Dikembalikan' : 'Books Not Returned') + ' (${overdue.length})',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.red),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    AppLocalization.isIndonesian
                        ? 'Buku berikut telah melewati tanggal pengembalian.'
                        : 'The following books have passed the return date.',
                    style: TextStyle(fontSize: 12, color: subtitleColor),
                  ),
                  const SizedBox(height: 12),
                  ...overdue.map((doc) {
                    final d = doc.data() as Map<String, dynamic>;
                    final dueDate = (d['dueDate'] as Timestamp?)!.toDate();
                    final now = DateTime.now();
                    final today = DateTime(now.year, now.month, now.day);
                    final due = DateTime(dueDate.year, dueDate.month, dueDate.day);
                    final daysLate = today.difference(due).inDays;
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
            AppLocalization.isIndonesian ? 'Kunjungan Hari Ini' : "Today's Visits",
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
                      AppLocalization.isIndonesian
                          ? 'Belum ada pengunjung perpustakaan hari ini.'
                          : 'No library visitors today.',
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
                              Text('NIS: $nis • ${AppLocalization.isIndonesian ? 'Kelas' : 'Class'} $className', style: TextStyle(fontSize: 12, color: subtitleColor)),
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
                Text('$studentName • ${AppLocalization.isIndonesian ? 'Kelas' : 'Class'} $className', style: TextStyle(fontSize: 12, color: textColor.withOpacity(0.7))),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: Colors.red.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
            child: Text('+$daysLate ' + (AppLocalization.isIndonesian ? 'hari' : 'days'), style: const TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.bold)),
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
