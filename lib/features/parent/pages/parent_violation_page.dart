import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../authentication/widgets/auth_background.dart';
import '../../../../core/services/session_service.dart';

class ParentViolationPage extends StatelessWidget {
  const ParentViolationPage({super.key});

  @override
  Widget build(BuildContext context) {
    final schoolId = Get.arguments?['schoolId'] as String? ?? '';
    final studentId = Get.arguments?['studentId'] as String? ?? '';

    return ValueListenableBuilder<bool>(
      valueListenable: AuthBackground.isDarkMode,
      builder: (context, isDark, _) {
        final textColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
        final subTextColor = isDark
            ? Colors.white.withValues(alpha: 0.5)
            : const Color(0xFF1E1B4B).withValues(alpha: 0.5);
        final cardBg =
            isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white;
        final cardBorder = isDark
            ? Colors.white.withValues(alpha: 0.1)
            : Colors.black.withValues(alpha: 0.08);

        return AuthBackground(
          child: Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              iconTheme: IconThemeData(color: textColor),
              title: Text(
                'Laporan Pelanggaran',
                style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            body: SafeArea(
              bottom: true,
              top: false,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: _buildViolationContent(
                  schoolId: schoolId,
                  studentId: studentId,
                  textColor: textColor,
                  subTextColor: subTextColor,
                  cardBg: cardBg,
                  cardBorder: cardBorder,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildViolationContent({
    required String schoolId,
    required String studentId,
    required Color textColor,
    required Color subTextColor,
    required Color cardBg,
    required Color cardBorder,
  }) {
    if (studentId.isEmpty) {
      return _emptyCard('Data pelanggaran belum tersedia.', subTextColor, cardBg, cardBorder);
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('schools')
          .doc(schoolId)
          .collection('violations')
          .where('studentId', isEqualTo: studentId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Terjadi kesalahan saat memuat data: ${snapshot.error}',
                style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data?.docs ?? [];

        // Calculate points
        int totalPoin = 0;
        for (final doc in docs) {
          final data = doc.data() as Map<String, dynamic>?;
          final p = data?['poin'] ?? data?['points'] ?? 0;
          totalPoin += (p is int) ? p : (int.tryParse(p.toString()) ?? 0);
        }
        
        final bool isParent = SessionService.currentUser?.role == 'parent';
        final targetSubjectText = isParent ? 'Anak Anda' : 'Anda';

        // Sort client-side by date descending
        final sortedDocs = docs.toList()..sort((a, b) {
          final aData = a.data() as Map<String, dynamic>?;
          final bData = b.data() as Map<String, dynamic>?;
          final aDate = aData?['date'] as Timestamp?;
          final bDate = bData?['date'] as Timestamp?;
          if (aDate == null) return 1;
          if (bDate == null) return -1;
          return bDate.compareTo(aDate);
        });

        // Limit to 10 latest
        final displayDocs = sortedDocs.take(10).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // GORGEOUS SUMMARY CARD FOR POINTS
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFEF4444), Color(0xFFB91C1C)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.25),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'POIN PELANGGARAN ${targetSubjectText.toUpperCase()}',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Total Poin', style: TextStyle(color: Colors.white70, fontSize: 11)),
                            const SizedBox(height: 4),
                            Text('$totalPoin Poin', style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Total Pelanggaran', style: TextStyle(color: Colors.white70, fontSize: 11)),
                            const SizedBox(height: 4),
                            Text('${docs.length} Kali', style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            Text(
              'Detail Riwayat Pelanggaran',
              style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 12),

            if (docs.isEmpty)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: cardBorder),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 32),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Tidak Ada Pelanggaran',
                            style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isParent
                                ? 'Anak Anda memiliki catatan pelanggaran yang bersih.'
                                : 'Anda memiliki catatan pelanggaran yang bersih.',
                            style: TextStyle(color: subTextColor, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              )
            else
              ...displayDocs.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final date = data['date'] != null ? (data['date'] as Timestamp).toDate() : null;
                final dateStr = date != null ? '${date.day}/${date.month}/${date.year}' : '-';
                final poin = data['poin'] ?? data['points'] ?? 0;
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.report_rounded, color: Color(0xFFEF4444), size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              data['jenis'] ?? data['type'] ?? 'Pelanggaran',
                              style: TextStyle(color: textColor, fontWeight: FontWeight.w600, fontSize: 13),
                            ),
                            if ((data['keterangan'] ?? data['description'] ?? '').toString().isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                data['keterangan'] ?? data['description'] ?? '',
                                style: TextStyle(color: subTextColor, fontSize: 11),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(dateStr, style: TextStyle(color: subTextColor, fontSize: 10)),
                          const SizedBox(height: 4),
                          Text(
                            '-$poin poin',
                            style: const TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }),
          ],
        );
      },
    );
  }

  Widget _emptyCard(String msg, Color subTextColor, Color cardBg, Color cardBorder) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cardBorder),
      ),
      child: Text(msg,
          textAlign: TextAlign.center,
          style: TextStyle(color: subTextColor, fontSize: 13)),
    );
  }
}
