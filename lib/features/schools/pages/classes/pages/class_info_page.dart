import 'package:flutter/material.dart';

import '../../../../../core/services/session_service.dart';
import '../../students/data/student_admin_service.dart';
import '../../teachers/data/teacher_service.dart';
import '../data/class_service.dart';

class ClassInfoPage extends StatelessWidget {
  final String classId;
  final String className;
  final StudentService _studentService = StudentService();
  final TeacherService _teacherService = TeacherService();

  final ClassService _classService = ClassService();
  ClassInfoPage({super.key, required this.classId, required this.className});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(className)),

      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Wali Kelas
            StreamBuilder(
              stream: _classService.getClassById(classId),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Card(
                    child: ListTile(title: Text('Memuat wali kelas...')),
                  );
                }

                final data = snapshot.data!.data();

                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.person),
                    title: const Text('Wali Kelas'),
                    subtitle: Text(data?['teacherName'] ?? 'Belum ditentukan'),
                  ),
                );
              },
            ),

            const SizedBox(height: 16),

            const Text(
              'Daftar Siswa',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 8),

            Expanded(
              child: StreamBuilder(
                stream: _studentService.getStudentsByClass(classId),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final docs = snapshot.data!.docs;

                  if (docs.isEmpty) {
                    return const Center(child: Text('Belum ada siswa'));
                  }

                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('NIS')),
                        DataColumn(label: Text('Nama')),
                      ],
                      rows: docs.map((doc) {
                        final student = doc.data();

                        return DataRow(
                          cells: [
                            DataCell(Text(student['nis'] ?? '')),
                            DataCell(Text(student['nama'] ?? '')),
                          ],
                        );
                      }).toList(),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.groups),
                  label: const Text('Tambah Siswa'),
                  onPressed: () {
                    _showAddStudentDialog(context);
                  },
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.person),
                  label: const Text('Wali Kelas'),
                  onPressed: () {
                    _showAddWaliKelasDialog(context);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddStudentDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Tambah Siswa'),
          content: SizedBox(
            width: double.maxFinite,
            height: 300,
            child: StreamBuilder(
              stream: _studentService.getStudentsWithoutClass(
                SessionService.currentUser!.schoolId,
              ),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data!.docs;

                if (docs.isEmpty) {
                  return const Center(child: Text('Tidak ada siswa tersedia'));
                }

                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (_, index) {
                    final student = docs[index].data();

                    return ListTile(
                      title: Text(student['nama'] ?? ''),
                      subtitle: Text(student['nis'] ?? ''),
                      trailing: IconButton(
                        icon: const Icon(Icons.add),
                        onPressed: () async {
                          await _studentService.assignStudentToClass(
                            studentId: docs[index].id,
                            classId: classId,
                          );

                          if (context.mounted) {
                            Navigator.pop(context);
                          }
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }

  void _showAddWaliKelasDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Row(
            children: [
              Icon(Icons.school),
              SizedBox(width: 8),
              Text('Pilih Wali Kelas'),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            height: 450,
            child: StreamBuilder(
              stream: _teacherService.getTeachers(
                SessionService.currentUser!.schoolId,
              ),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Error: ${snapshot.error}',
                      textAlign: TextAlign.center,
                    ),
                  );
                }

                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data!.docs;

                if (docs.isEmpty) {
                  return const Center(child: Text('Belum ada data guru'));
                }

                return ListView.separated(
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, index) {
                    final teacher = docs[index].data();
                    final teacherName = teacher['nama'] ?? '';

                    return Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 24,
                              child: Text(
                                teacherName.isNotEmpty
                                    ? teacherName[0].toUpperCase()
                                    : '?',
                              ),
                            ),

                            const SizedBox(width: 12),

                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    teacherName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            ElevatedButton.icon(
                              icon: const Icon(Icons.check),
                              label: const Text('Pilih'),
                              onPressed: () async {
                                await _classService.assignWaliKelas(
                                  classId: classId,
                                  teacherId: docs[index].id,
                                  teacherName: teacherName,
                                );

                                if (dialogContext.mounted) {
                                  Navigator.pop(dialogContext);
                                }

                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        '$teacherName berhasil menjadi wali kelas',
                                      ),
                                    ),
                                  );
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton.icon(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              icon: const Icon(Icons.close),
              label: const Text('Tutup'),
            ),
          ],
        );
      },
    );
  }
}
