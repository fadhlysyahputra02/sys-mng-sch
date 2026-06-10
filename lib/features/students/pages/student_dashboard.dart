import 'package:flutter/material.dart';

import '../../../../core/services/session_service.dart';
import '../../../core/services/app_auth_service.dart';
import '../data/student_service.dart';
import '../model/student_model.dart';

class StudentDashboard extends StatelessWidget {
  const StudentDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final user = SessionService.currentUser!;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard Murid'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _logout(context),
          ),
        ],
      ),
      body: StreamBuilder<StudentModel?>(
        stream: StudentService().getStudentByUid(user.uid),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final student = snapshot.data;

          if (student == null) {
            return const Center(child: Text('Data murid tidak ditemukan'));
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.person)),
                  title: Text(student.nama),
                  subtitle: Text(student.email),
                ),
              ),

              const SizedBox(height: 16),

              Card(
                child: Column(
                  children: [
                    ListTile(
                      title: const Text('NIS'),
                      subtitle: Text(student.nis),
                    ),

                    const Divider(height: 1),

                    ListTile(
                      title: const Text('School ID'),
                      subtitle: Text(student.schoolId),
                    ),

                    const Divider(height: 1),

                    ListTile(
                      title: const Text('Status'),
                      subtitle: Text(student.aktif ? 'Aktif' : 'Tidak Aktif'),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  //method untuk logout
  Future<void> _logout(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Logout'),
          content: const Text('Apakah Anda yakin ingin keluar?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: const Text('Batal'),
            ),

            ElevatedButton(
              onPressed: () {
                Navigator.pop(context, true);
              },
              child: const Text('Logout'),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    try {
      await AppAuthService.logout();

      SessionService.logout();

      if (context.mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gagal logout: $e')));
      }
    }
  }
}
