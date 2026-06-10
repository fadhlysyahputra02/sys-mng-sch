import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AddStudentPage extends StatefulWidget {
  final String schoolId;

  const AddStudentPage({super.key, required this.schoolId});

  @override
  State<AddStudentPage> createState() => _AddStudentPageState();
}

class _AddStudentPageState extends State<AddStudentPage> {
  final _formKey = GlobalKey<FormState>();

  final namaController = TextEditingController();
  final nisController = TextEditingController();

  bool isLoading = false;

  Future<void> saveStudent() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      setState(() {
        isLoading = true;
      });

      final doc = FirebaseFirestore.instance.collection('students').doc();

      await doc.set({
        'studentId': doc.id,
        'schoolId': widget.schoolId,
        'uid': '',
        'email': '',
        'nis': nisController.text.trim(),
        'nama': namaController.text.trim(),
        'aktif': true,
        'sudahRegister': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      Navigator.pop(context);
    } catch (e) {
      debugPrint(e.toString());
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    namaController.dispose();
    nisController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tambah Murid')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: namaController,
                decoration: const InputDecoration(
                  labelText: 'Nama Murid',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Nama wajib diisi';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              TextFormField(
                controller: nisController,
                decoration: const InputDecoration(
                  labelText: 'NIS',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'NIS wajib diisi';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 24),

              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: isLoading ? null : saveStudent,
                  child: isLoading
                      ? const CircularProgressIndicator()
                      : const Text('Simpan'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
