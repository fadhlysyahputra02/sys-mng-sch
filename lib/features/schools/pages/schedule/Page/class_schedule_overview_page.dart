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

    return Scaffold(
      appBar: AppBar(title: const Text('Jadwal Kelas')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _classService.getClasses(schoolId),
        builder: (context, classSnapshot) {
          if (classSnapshot.hasError) {
            return Center(child: Text('${classSnapshot.error}'));
          }

          if (!classSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final classDocs = classSnapshot.data!.docs;

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _scheduleService.getSchedulesBySchool(schoolId),
            builder: (context, scheduleSnapshot) {
              if (scheduleSnapshot.hasError) {
                return Center(child: Text('${scheduleSnapshot.error}'));
              }

              if (!scheduleSnapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final scheduleDocs = scheduleSnapshot.data!.docs;
              final scheduleMap = <String, List<Map<String, dynamic>>>{};

              for (final doc in scheduleDocs) {
                final data = doc.data();
                final classId = (data['classId'] ?? '').toString();

                if (classId.isEmpty) {
                  continue;
                }

                scheduleMap.putIfAbsent(classId, () => []).add(data);
              }

              final classesWithSchedule = classDocs
                  .where((doc) => scheduleMap.containsKey(doc.id))
                  .toList();

              final classesWithoutSchedule = classDocs
                  .where((doc) => !scheduleMap.containsKey(doc.id))
                  .toList();

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _statCard(
                          title: 'Total Kelas',
                          value: '${classDocs.length}',
                          icon: Icons.class_,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _statCard(
                          title: 'Sudah Ada Jadwal',
                          value: '${classesWithSchedule.length}',
                          icon: Icons.event_available,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _statCard(
                    title: 'Belum Ada Jadwal',
                    value: '${classesWithoutSchedule.length}',
                    icon: Icons.event_busy,
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Kelas yang Sudah Punya Jadwal',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  if (classesWithSchedule.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('Belum ada kelas yang memiliki jadwal.'),
                      ),
                    )
                  else
                    ...classesWithSchedule.map((doc) {
                      final data = doc.data();
                      final schedules = scheduleMap[doc.id] ?? [];
                      final firstSchedule = schedules.first;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Card(
                          elevation: 2,
                          child: ListTile(
                            leading: const CircleAvatar(
                              child: Icon(Icons.schedule),
                            ),
                            title: Text(data['namaKelas'] ?? ''),
                            subtitle: Text(
                              '${schedules.length} jadwal • ${firstSchedule['hari'] ?? ''}, ${firstSchedule['jamMulai'] ?? ''} - ${firstSchedule['jamSelesai'] ?? ''}',
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () {
                              Get.to(
                                () => ClassSchedulePage(
                                  classId: doc.id,
                                  className: data['namaKelas'] ?? '',
                                ),
                              );
                            },
                          ),
                        ),
                      );
                    }),
                  const SizedBox(height: 16),
                  const Text(
                    'Kelas Tanpa Jadwal',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  if (classesWithoutSchedule.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('Semua kelas sudah memiliki jadwal.'),
                      ),
                    )
                  else
                    ...classesWithoutSchedule.map((doc) {
                      final data = doc.data();

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Card(
                          elevation: 2,
                          child: ListTile(
                            leading: const CircleAvatar(
                              child: Icon(Icons.event_busy),
                            ),
                            title: Text(data['namaKelas'] ?? ''),
                            subtitle: const Text(
                              'Belum ada jadwal. Tap untuk isi data jadwal.',
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () {
                              Get.to(
                                () => ClassSchedulePage(
                                  classId: doc.id,
                                  className: data['namaKelas'] ?? '',
                                ),
                              );
                            },
                          ),
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
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon),
            const SizedBox(height: 12),
            Text(title),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
