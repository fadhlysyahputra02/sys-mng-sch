import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'add_student_page.dart';
import 'student_detail_page.dart';

class StudentListPage extends StatelessWidget {
  final String schoolId;

  const StudentListPage({super.key, required this.schoolId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Data Murid')),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AddStudentPage(schoolId: schoolId),
            ),
          );
        },
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('students')
            .where('schoolId', isEqualTo: schoolId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Terjadi kesalahan'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return const Center(child: Text('Belum ada data murid'));
          }

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final student = docs[index].data() as Map<String, dynamic>;

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.school)),

                  title: Text(student['nama'] ?? '-'),

                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('NIS : ${student['nis'] ?? '-'}'),

                      if ((student['email'] ?? '').toString().isNotEmpty)
                        Text(student['email']),
                    ],
                  ),

                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),

                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => StudentDetailPage(student: student),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
