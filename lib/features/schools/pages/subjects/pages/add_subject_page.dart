import 'package:flutter/material.dart';

import '../../../../../core/services/session_service.dart';
import '../data/subject_service.dart';

class AddSubjectPage extends StatefulWidget {
  const AddSubjectPage({super.key});

  @override
  State<AddSubjectPage> createState() => _AddSubjectPageState();
}

class _AddSubjectPageState extends State<AddSubjectPage> {
  final service = SubjectService();

  final kodeController = TextEditingController();

  final namaController = TextEditingController();

  String kategori = 'Wajib';

  Future<void> save() async {
    await service.addSubject(
      schoolId: SessionService.currentUser!.schoolId,
      kodeMapel: kodeController.text.trim(),
      namaMapel: namaController.text.trim(),
      kategori: kategori,
    );

    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tambah Mata Pelajaran')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: kodeController,
              decoration: const InputDecoration(labelText: 'Kode Mapel'),
            ),

            const SizedBox(height: 16),

            TextField(
              controller: namaController,
              decoration: const InputDecoration(labelText: 'Nama Mapel'),
            ),

            const SizedBox(height: 16),

            DropdownButtonFormField(
              initialValue: kategori,
              items: const [
                DropdownMenuItem(value: 'Wajib', child: Text('Wajib')),
                DropdownMenuItem(value: 'Pilihan', child: Text('Pilihan')),
              ],
              onChanged: (v) {
                kategori = v!;
              },
            ),

            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: save,
                child: const Text('Simpan'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
