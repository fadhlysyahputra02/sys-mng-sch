import 'package:flutter/material.dart';

class StudentDetailPage extends StatelessWidget {
  final Map<String, dynamic> student;

  const StudentDetailPage({super.key, required this.student});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Detail Murid')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: ListTile(
                title: Text(
                  student['nama'] ?? '-',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text('NIS : ${student['nis'] ?? '-'}'),
              ),
            ),

            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Mata Pelajaran',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),

            const SizedBox(height: 10),

            // Expanded(
            //   child: StreamBuilder<QuerySnapshot>(
            //     stream: FirebaseFirestore.instance
            //         .collection('student_subjects')
            //         .where('studentId', isEqualTo: student['studentId'])
            //         .snapshots(),
            //     builder: (context, snapshot) {
            //       if (!snapshot.hasData) {
            //         return const Center(child: CircularProgressIndicator());
            //       }

            //       final docs = snapshot.data!.docs;

            //       if (docs.isEmpty) {
            //         return const Center(
            //           child: Text('Belum ada mata pelajaran'),
            //         );
            //       }

            //       return ListView.builder(
            //         itemCount: docs.length,
            //         itemBuilder: (context, index) {
            //           final mapel = docs[index].data() as Map<String, dynamic>;

            //           return Card(
            //             child: ListTile(
            //               leading: const Icon(Icons.menu_book),
            //               title: Text(mapel['subjectName'] ?? '-'),
            //             ),
            //           );
            //         },
            //       );
            //     },
            //   ),
            // ),
            // SizedBox(
            //   width: double.infinity,
            //   child: ElevatedButton.icon(
            //     icon: const Icon(Icons.menu_book),
            //     label: const Text('Atur Mata Pelajaran'),
            //     onPressed: () {
            //       Navigator.push(
            //         context,
            //         MaterialPageRoute(
            //           builder: (_) => StudentSubjectPage(
            //             studentId: student['studentId'],
            //             studentName: student['nama'],
            //           ),
            //         ),
            //       );
            //     },
            //   ),
            // ),
          ],
        ),
      ),
    );
  }
}
