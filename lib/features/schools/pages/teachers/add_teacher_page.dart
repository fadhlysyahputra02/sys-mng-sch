import 'package:flutter/material.dart';
import '../../data/teacher_service.dart';

class AddTeacherPage extends StatefulWidget {
  final String schoolId;

  const AddTeacherPage({super.key, required this.schoolId});

  @override
  State<AddTeacherPage> createState() => _AddTeacherPageState();
}

class _AddTeacherPageState extends State<AddTeacherPage> {
  final namaController = TextEditingController();
  final nipController = TextEditingController();

  final teacherService = TeacherService();

  Future<void> simpanGuru() async {
    try {
      await teacherService.createTeacher(
        schoolId: widget.schoolId,
        nip: nipController.text.trim(),
        nama: namaController.text.trim(),
      );

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tambah Guru')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: namaController,
              decoration: const InputDecoration(labelText: 'Nama Guru'),
            ),

            const SizedBox(height: 16),

            TextField(
              controller: nipController,
              decoration: const InputDecoration(labelText: 'NIP'),
            ),

            const SizedBox(height: 24),

            ElevatedButton(onPressed: simpanGuru, child: const Text('SIMPAN')),
          ],
        ),
      ),
    );
  }
}
