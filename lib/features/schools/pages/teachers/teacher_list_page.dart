import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'add_teacher_page.dart';
import '../../data/teacher_service.dart';

class TeacherListPage extends StatelessWidget {
  final String schoolId;

  TeacherListPage({super.key, required this.schoolId});

  final teacherService = TeacherService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Data Guru')),

      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AddTeacherPage(schoolId: schoolId),
            ),
          );
        },
      ),

      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: teacherService.getTeachers(schoolId),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;

          if (docs.isEmpty) {
            return const Center(child: Text('Belum ada guru'));
          }

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data();

              return ListTile(
                leading: const Icon(Icons.person),
                title: Text(data['nama']),
                subtitle: Text(data['nip']),
                trailing: Icon(
                  data['sudahRegister'] ? Icons.check_circle : Icons.pending,
                ),
              );
            },
          );
        },
      ),
    );
  }
}
