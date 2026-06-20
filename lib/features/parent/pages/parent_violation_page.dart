import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../authentication/widgets/auth_background.dart';

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
          .orderBy('date', descending: true)
          .limit(10)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: cardBorder),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle_rounded,
                    color: Color(0xFF10B981), size: 32),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Tidak Ada Pelanggaran',
                          style: TextStyle(
                              color: textColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 14)),
                      const SizedBox(height: 4),
                      Text('Anak Anda memiliki catatan pelanggaran yang bersih.',
                          style:
                              TextStyle(color: subTextColor, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: cardBorder),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${docs.length} Pelanggaran',
                      style: const TextStyle(
                          color: Color(0xFFEF4444),
                          fontWeight: FontWeight.bold,
                          fontSize: 12),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              ...docs.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final date = data['date'] != null
                    ? (data['date'] as Timestamp).toDate()
                    : null;
                final dateStr = date != null
                    ? '${date.day}/${date.month}/${date.year}'
                    : '-';
                final poin = data['poin'] ?? data['points'] ?? 0;
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: const Color(0xFFEF4444).withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.report_rounded,
                          color: Color(0xFFEF4444), size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              data['jenis'] ?? data['type'] ?? 'Pelanggaran',
                              style: TextStyle(
                                  color: textColor,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13),
                            ),
                            if ((data['keterangan'] ?? data['description'] ?? '')
                                .toString()
                                .isNotEmpty)
                              Text(
                                data['keterangan'] ?? data['description'] ?? '',
                                style: TextStyle(
                                    color: subTextColor, fontSize: 11),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(dateStr,
                              style: TextStyle(
                                  color: subTextColor, fontSize: 10)),
                          const SizedBox(height: 2),
                          Text(
                            '-$poin poin',
                            style: const TextStyle(
                                color: Color(0xFFEF4444),
                                fontWeight: FontWeight.bold,
                                fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
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
