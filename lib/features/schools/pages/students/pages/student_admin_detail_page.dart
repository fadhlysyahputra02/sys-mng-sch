import 'package:flutter/material.dart';

class StudentDetailPage extends StatelessWidget {
  final Map<String, dynamic> student;

  const StudentDetailPage({super.key, required this.student});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Detail Murid')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Card(
              child: ListTile(
                leading: const CircleAvatar(child: Icon(Icons.person)),
                title: Text(
                  student['nama'] ?? '-',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text('NIS : ${student['nis'] ?? '-'}'),
              ),
            ),

            const SizedBox(height: 16),

            Card(
              child: Column(
                children: [
                  const Divider(height: 1),

                  ListTile(
                    leading: const Icon(Icons.class_),
                    title: const Text('Kelas'),
                    subtitle: Text(student['className'] ?? 'Belum ditentukan'),
                  ),

                  const Divider(height: 1),

                  ListTile(
                    leading: const Icon(Icons.email),
                    title: const Text('Email'),
                    subtitle: Text(
                      (student['email'] ?? '').toString().isEmpty
                          ? '-'
                          : student['email'],
                    ),
                  ),

                  const Divider(height: 1),

                  ListTile(
                    leading: const Icon(Icons.verified_user),
                    title: const Text('Status'),
                    subtitle: Text(
                      student['aktif'] == true ? 'Aktif' : 'Tidak Aktif',
                    ),
                  ),

                  const Divider(height: 1),

                  ListTile(
                    leading: const Icon(Icons.login),
                    title: const Text('Registrasi'),
                    subtitle: Text(
                      student['sudahRegister'] == true
                          ? 'Sudah Register'
                          : 'Belum Register',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
