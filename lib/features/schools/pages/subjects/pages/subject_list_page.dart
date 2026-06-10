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
              final data = docs[i].data() as Map<String, dynamic>;

              return Card(
                child: ListTile(
                  title: Text(data['namaMapel']),
                  subtitle: Text('${data['kodeMapel']} • ${data['kategori']}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: () {
                      service.deleteSubject(data['subjectId']);
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
