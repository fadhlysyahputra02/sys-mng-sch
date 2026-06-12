import 'package:flutter/material.dart';

import '../../../../../core/services/session_service.dart';
import '../data/subject_service.dart';
import 'add_subject_page.dart';

class SubjectListPage extends StatelessWidget {
  SubjectListPage({super.key});

  final service = SubjectService();

  @override
  Widget build(BuildContext context) {
    final schoolId = SessionService.currentUser!.schoolId;

    return Scaffold(
      appBar: AppBar(title: const Text('Mata Pelajaran')),

      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddSubjectPage()),
          );
        },
      ),

      body: StreamBuilder(
        stream: service.getSubjects(schoolId),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;

          if (docs.isEmpty) {
            return const Center(child: Text('Belum ada mata pelajaran'));
          }

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (_, i) {
              final data = docs[i].data();

              return Card(
                child: ListTile(
                  title: Text(data['namaMapel']),
                  subtitle: Text('${data['kodeMapel']} • ${data['kategori']}'),
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'edit') {
                        _showEditDialog(context, data);
                      } else if (value == 'delete') {
                        _showDeleteConfirmation(context, data);
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, size: 18), SizedBox(width: 8), Text('Edit')])),
                      PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, size: 18, color: Colors.red), SizedBox(width: 8), Text('Hapus', style: TextStyle(color: Colors.red))])),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showEditDialog(BuildContext context, Map<String, dynamic> data) {
    final namaController = TextEditingController(text: data['namaMapel']);
    final kodeController = TextEditingController(text: data['kodeMapel']);
    String selectedKategori = data['kategori'] ?? 'Wajib';

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: const Text('Edit Mata Pelajaran'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: kodeController,
                    decoration: const InputDecoration(
                      labelText: 'Kode Mapel',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: namaController,
                    decoration: const InputDecoration(
                      labelText: 'Nama Mapel',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: selectedKategori,
                    decoration: const InputDecoration(
                      labelText: 'Kategori',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'Wajib', child: Text('Wajib')),
                      DropdownMenuItem(value: 'Pilihan', child: Text('Pilihan')),
                    ],
                    onChanged: (v) => setDialogState(() => selectedKategori = v!),
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
                    final nama = namaController.text.trim();
                    final kode = kodeController.text.trim();
                    if (nama.isEmpty || kode.isEmpty) return;

                    await service.updateSubject(
                      subjectId: data['subjectId'],
                      namaMapel: nama,
                      kodeMapel: kode,
                      kategori: selectedKategori,
                    );

                    if (ctx.mounted) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Mata pelajaran berhasil diperbarui')),
                      );
                    }
                  },
                  child: const Text('Simpan'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showDeleteConfirmation(BuildContext context, Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Hapus Mata Pelajaran'),
          content: Text(
            'Apakah Anda yakin ingin menghapus "${data['namaMapel']}"? Data ini tidak dapat dikembalikan.',
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
                await service.deleteSubject(data['subjectId']);
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Mata pelajaran berhasil dihapus')),
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
}
