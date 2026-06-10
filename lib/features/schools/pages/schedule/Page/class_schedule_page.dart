import 'package:flutter/material.dart';

import '../Service/class_schedule_service.dart';

class ClassSchedulePage extends StatelessWidget {
  final String classId;
  final String className;

  ClassSchedulePage({
    super.key,
    required this.classId,
    required this.className,
  });

  final _service = ClassScheduleService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Jadwal $className')),
      body: StreamBuilder(
        stream: _service.getSchedulesByClass(classId),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('${snapshot.error}'));
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;

          if (docs.isEmpty) {
            return const Center(child: Text('Belum ada jadwal'));
          }

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (_, index) {
              final data = docs[index].data();

              return Card(
                child: ListTile(
                  title: Text(data['subjectName']),
                  subtitle: Text(
                    '${data['hari']} | '
                    '${data['jamMulai']} - ${data['jamSelesai']}\n'
                    '${data['teacherName']}',
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
