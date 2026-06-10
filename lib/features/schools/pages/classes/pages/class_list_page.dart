import 'package:flutter/material.dart';

import '../../../../../core/services/session_service.dart';
import '../data/class_service.dart';
import 'class_info_page.dart';

class ClassListPage extends StatelessWidget {
  ClassListPage({super.key});

  final ClassService _service = ClassService();

  @override
  Widget build(BuildContext context) {
    final schoolId = SessionService.currentUser!.schoolId;

    return Scaffold(
      appBar: AppBar(title: const Text('Data Kelas')),
      body: StreamBuilder(
        stream: _service.getClasses(schoolId),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;

          if (docs.isEmpty) {
            return const Center(child: Text('Belum ada kelas'));
          }

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (_, index) {
              final data = docs[index].data();

              return Card(
                child: ListTile(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ClassInfoPage(
                          classId: docs[index].id,
                          className: data['namaKelas'],
                        ),
                      ),
                    );
                  },
                  title: Text(data['namaKelas'] ?? ''),
                  subtitle: Text(
                    'Wali Kelas: ${data['teacherName'] ?? 'Belum ditentukan'}',
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () {
          _showAddClassDialog(context, schoolId);
        },
      ),
    );
  }

  //method untuk menampilkan dialog tambah kelas
  Future<void> _showAddClassDialog(
    BuildContext context,
    String schoolId,
  ) async {
    final controller = TextEditingController();

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Tambah Kelas'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'Nama Kelas',
              hintText: 'Contoh: X IPA 1',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () async {
                final namaKelas = controller.text.trim();

                if (namaKelas.isEmpty) {
                  return;
                }

                await _service.addClass(
                  schoolId: schoolId,
                  namaKelas: namaKelas,
                );

                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext);
                }
              },
              child: const Text('Simpan'),
            ),
          ],
        );
      },
    );
  }
}
