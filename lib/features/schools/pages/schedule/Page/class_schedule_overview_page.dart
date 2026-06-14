import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../../core/services/session_service.dart';
import '../../../../authentication/widgets/auth_background.dart';
import '../../classes/data/class_service.dart';
import '../Service/class_schedule_service.dart';
import 'class_schedule_page.dart';

class ClassScheduleOverviewPage extends StatelessWidget {
  final bool hideBackButton;
  ClassScheduleOverviewPage({super.key, this.hideBackButton = false});

  final ClassService _classService = ClassService();
  final ClassScheduleService _scheduleService = ClassScheduleService();

  @override
  Widget build(BuildContext context) {
    final schoolId = SessionService.currentUser!.schoolId;

    return Scaffold(
      body: AuthBackground(
        child: Column(
          children: [
            // AppBar Area
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
                child: Row(
                  children: [
                    if (!hideBackButton)
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                      ),
                    const SizedBox(width: 4),
                    const Expanded(
                      child: Text(
                        'Jadwal Kelas',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Body
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _classService.getClasses(schoolId),
                builder: (context, classSnapshot) {
                  if (classSnapshot.hasError) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.error_outline_rounded, size: 40, color: Colors.red),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Terjadi kesalahan memuat data kelas.',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    );
                  }

                  if (!classSnapshot.hasData) {
                    return const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFEC4899)),
                      ),
                    );
                  }

                  final classDocs = classSnapshot.data!.docs;

                  return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: _scheduleService.getSchedulesBySchool(schoolId),
                    builder: (context, scheduleSnapshot) {
                      if (scheduleSnapshot.hasError) {
                        return const Center(child: Text('Gagal memuat jadwal.', style: TextStyle(color: Colors.white)));
                      }

                      if (!scheduleSnapshot.hasData) {
                        return const Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFEC4899)),
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
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                        children: [
                          // Stat Cards Row
                          Row(
                            children: [
                              Expanded(
                                child: _statCard(
                                  title: 'Total Kelas',
                                  value: '${classDocs.length}',
                                  icon: Icons.class_rounded,
                                  colors: const [Color(0xFFEC4899), Color(0xFFF472B6)],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _statCard(
                                  title: 'Ada Jadwal',
                                  value: '${classesWithSchedule.length}',
                                  icon: Icons.event_available_rounded,
                                  colors: const [Color(0xFF059669), Color(0xFF34D399)],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _statCard(
                                  title: 'Belum Ada',
                                  value: '${classesWithoutSchedule.length}',
                                  icon: Icons.event_busy_rounded,
                                  colors: const [Color(0xFFDC2626), Color(0xFFF87171)],
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 28),

                          // Section: Classes with schedule
                          _sectionHeader('Sudah Ada Jadwal', Icons.check_circle_rounded, const Color(0xFF10B981)),
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
                          _sectionHeader('Belum Ada Jadwal', Icons.pending_actions_rounded, const Color(0xFFEF4444)),
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
            ),
          ],
        ),
      ),
    );
  }

  Widget _statCard({
    required String title,
    required String value,
    required IconData icon,
    required List<Color> colors,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: colors.first.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white.withValues(alpha: 0.85), size: 22),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.85), fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
        ),
      ],
    );
  }

  Widget _emptyStateCard({required IconData icon, required String message}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white.withValues(alpha: 0.3), size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.45), fontWeight: FontWeight.w500),
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
    final badgeColor = hasSchedule ? const Color(0xFF10B981) : const Color(0xFFEF4444);
    final badgeText = hasSchedule ? 'Ada Jadwal' : 'Belum Ada';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFEC4899), Color(0xFFF472B6)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.class_rounded, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        classname,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.5)),
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
                    color: badgeColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: badgeColor.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    badgeText,
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: badgeColor),
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.chevron_right_rounded, color: Colors.white.withValues(alpha: 0.3)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
