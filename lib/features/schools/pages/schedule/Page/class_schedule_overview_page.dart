import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../../core/services/session_service.dart';
import '../../classes/data/class_service.dart';
import '../Service/class_schedule_service.dart';
import 'class_schedule_page.dart';

class ClassScheduleOverviewPage extends StatelessWidget {
  ClassScheduleOverviewPage({super.key});

  final ClassService _classService = ClassService();
  final ClassScheduleService _scheduleService = ClassScheduleService();

  @override
  Widget build(BuildContext context) {
    final schoolId = SessionService.currentUser!.schoolId;
    const primaryColor = Color(0xFF4F46E5);
    const surfaceColor = Color(0xFFF8F7FF);

    return Scaffold(
      backgroundColor: surfaceColor,
      appBar: AppBar(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Jadwal Kelas',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _classService.getClasses(schoolId),
        builder: (context, classSnapshot) {
          if (classSnapshot.hasError) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline_rounded, size: 48, color: Colors.red),
                  SizedBox(height: 12),
                  Text('Terjadi kesalahan memuat data kelas.', style: TextStyle(color: Color(0xFF64748B))),
                ],
              ),
            );
          }

          if (!classSnapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
              ),
            );
          }

          final classDocs = classSnapshot.data!.docs;

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _scheduleService.getSchedulesBySchool(schoolId),
            builder: (context, scheduleSnapshot) {
              if (scheduleSnapshot.hasError) {
                return const Center(child: Text('Gagal memuat jadwal.'));
              }

              if (!scheduleSnapshot.hasData) {
                return const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                  ),
                );
              }

              final scheduleDocs = scheduleSnapshot.data!.docs;
              final scheduleMap = <String, List<Map<String, dynamic>>>{};

              for (final doc in scheduleDocs) {
                final data = doc.data();
                final classId = (data['classId'] ?? '').toString();
                if (classId.isEmpty) continue;
                scheduleMap.putIfAbsent(classId, () => []).add(data);
              }

              final classesWithSchedule = classDocs
                  .where((doc) => scheduleMap.containsKey(doc.id))
                  .toList();

              final classesWithoutSchedule = classDocs
                  .where((doc) => !scheduleMap.containsKey(doc.id))
                  .toList();

              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
                children: [
                  // Stat Cards Row
                  Row(
                    children: [
                      Expanded(
                        child: _statCard(
                          title: 'Total Kelas',
                          value: '${classDocs.length}',
                          icon: Icons.class_rounded,
                          gradient: const LinearGradient(
                            colors: [Color(0xFF4F46E5), Color(0xFF6366F1)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _statCard(
                          title: 'Ada Jadwal',
                          value: '${classesWithSchedule.length}',
                          icon: Icons.event_available_rounded,
                          gradient: const LinearGradient(
                            colors: [Color(0xFF059669), Color(0xFF34D399)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _statCard(
                          title: 'Belum Ada',
                          value: '${classesWithoutSchedule.length}',
                          icon: Icons.event_busy_rounded,
                          gradient: const LinearGradient(
                            colors: [Color(0xFFDC2626), Color(0xFFF87171)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 28),

                  // Section: Classes with schedule
                  _sectionHeader(
                    'Sudah Ada Jadwal',
                    Icons.check_circle_rounded,
                    const Color(0xFF059669),
                  ),
                  const SizedBox(height: 12),

                  if (classesWithSchedule.isEmpty)
                    _emptyStateCard(
                      icon: Icons.event_note_rounded,
                      message: 'Belum ada kelas yang memiliki jadwal.',
                    )
                  else
                    ...classesWithSchedule.map((doc) {
                      final data = doc.data();
                      final schedules = scheduleMap[doc.id] ?? [];
                      final firstSchedule = schedules.first;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _classCard(
                          classname: data['namaKelas'] ?? '-',
                          subtitle: '${schedules.length} jadwal  •  ${firstSchedule['hari'] ?? ''}, ${firstSchedule['jamMulai'] ?? ''} – ${firstSchedule['jamSelesai'] ?? ''}',
                          hasSchedule: true,
                          onTap: () {
                            Get.to(() => ClassSchedulePage(
                              classId: doc.id,
                              className: data['namaKelas'] ?? '',
                            ));
                          },
                        ),
                      );
                    }),

                  const SizedBox(height: 24),

                  // Section: Classes without schedule
                  _sectionHeader(
                    'Belum Ada Jadwal',
                    Icons.pending_actions_rounded,
                    const Color(0xFFDC2626),
                  ),
                  const SizedBox(height: 12),

                  if (classesWithoutSchedule.isEmpty)
                    _emptyStateCard(
                      icon: Icons.celebration_rounded,
                      message: 'Semua kelas sudah memiliki jadwal. 🎉',
                    )
                  else
                    ...classesWithoutSchedule.map((doc) {
                      final data = doc.data();

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _classCard(
                          classname: data['namaKelas'] ?? '-',
                          subtitle: 'Tap untuk mulai isi jadwal kelas ini',
                          hasSchedule: false,
                          onTap: () {
                            Get.to(() => ClassSchedulePage(
                              classId: doc.id,
                              className: data['namaKelas'] ?? '',
                            ));
                          },
                        ),
                      );
                    }),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _statCard({
    required String title,
    required String value,
    required IconData icon,
    required Gradient gradient,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.10),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white.withOpacity(0.85), size: 22),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: TextStyle(
              fontSize: 11,
              color: Colors.white.withOpacity(0.85),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _emptyStateCard({required IconData icon, required String message}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey.shade400, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Color(0xFF94A3B8),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _classCard({
    required String classname,
    required String subtitle,
    required bool hasSchedule,
    required VoidCallback onTap,
  }) {
    const primaryColor = Color(0xFF4F46E5);
    final badgeColor = hasSchedule ? const Color(0xFF059669) : const Color(0xFFDC2626);
    final badgeBg = hasSchedule ? const Color(0xFFD1FAE5) : const Color(0xFFFEE2E2);
    final badgeText = hasSchedule ? 'Ada Jadwal' : 'Belum Ada';

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFEDE9FE),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.class_rounded, color: primaryColor, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      classname,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Color(0xFF1E1B4B),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  badgeText,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: badgeColor,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right_rounded, color: Color(0xFFCBD5E1)),
            ],
          ),
        ),
      ),
    );
  }
}

