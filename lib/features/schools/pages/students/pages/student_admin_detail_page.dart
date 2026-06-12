import 'package:flutter/material.dart';

import '../data/student_admin_service.dart';

class StudentDetailPage extends StatefulWidget {
  final Map<String, dynamic> student;

  const StudentDetailPage({super.key, required this.student});

  @override
  State<StudentDetailPage> createState() => _StudentDetailPageState();
}

class _StudentDetailPageState extends State<StudentDetailPage> {
  late Map<String, dynamic> student;
  final _studentService = StudentService();

  @override
  void initState() {
    super.initState();
    student = Map<String, dynamic>.from(widget.student);
  }

  void _showEditDialog() {
    final namaController = TextEditingController(text: student['nama']);
    final nisController = TextEditingController(text: student['nis']);

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Edit Data Murid'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: namaController,
                decoration: const InputDecoration(
                  labelText: 'Nama Murid',
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nisController,
                decoration: const InputDecoration(
                  labelText: 'NIS',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () async {
                final newNama = namaController.text.trim();
                final newNis = nisController.text.trim();
                if (newNama.isEmpty || newNis.isEmpty) return;

                await _studentService.updateStudent(
                  studentId: student['studentId'],
                  nama: newNama,
                  nis: newNis,
                );

                setState(() {
                  student['nama'] = newNama;
                  student['nis'] = newNis;
                });

                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Data murid berhasil diperbarui')),
                  );
                }
              },
              child: const Text('Simpan'),
            ),
          ],
        );
      },
    );
  }

  void _showDeleteDialog() {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Hapus Murid'),
          content: Text(
            'Apakah Anda yakin ingin menghapus "${student['nama']}"? Data ini tidak dapat dikembalikan.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                await _studentService.deleteStudent(student['studentId']);

                if (ctx.mounted) {
                  Navigator.pop(ctx); // Tutup dialog
                  Navigator.pop(context); // Kembali ke daftar murid
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Murid berhasil dihapus')),
                  );
                }
              },
              child: const Text('Hapus'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detail Murid'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: _showEditDialog,
            tooltip: 'Edit Murid',
          ),
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.redAccent),
            onPressed: _showDeleteDialog,
            tooltip: 'Hapus Murid',
          ),
        ],
      ),
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
