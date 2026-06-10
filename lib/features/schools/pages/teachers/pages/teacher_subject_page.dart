import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../../../core/services/session_service.dart';
import '../services/teacher_subject_service.dart';

class TeacherSubjectPage extends StatefulWidget {
  final String teacherId;
  final String teacherName;

  const TeacherSubjectPage({
    super.key,
    required this.teacherId,
    required this.teacherName,
  });

  @override
  State<TeacherSubjectPage> createState() => _TeacherSubjectPageState();
}

class _TeacherSubjectPageState extends State<TeacherSubjectPage> {
  final service = TeacherSubjectService();

  List<String> assigned = [];

  bool loading = true;

  @override
  void initState() {
    super.initState();
    loadAssigned();
  }

  Future<void> loadAssigned() async {
    assigned = await service.getAssignedSubjects(widget.teacherId);

    setState(() {
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final schoolId = SessionService.currentUser!.schoolId;

    return Scaffold(
      appBar: AppBar(title: Text('Mapel ${widget.teacherName}')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('subjects')
                  .where('schoolId', isEqualTo: schoolId)
                  .snapshots(),
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
                  itemBuilder: (context, index) {
                    final subject = docs[index].data() as Map<String, dynamic>;

                    final subjectId = subject['subjectId'];

                    final checked = assigned.contains(subjectId);

                    return CheckboxListTile(
                      value: checked,
                      title: Text(subject['namaMapel']),
                      subtitle: Text(subject['kodeMapel']),
                      onChanged: (value) async {
                        if (value == true) {
                          await service.assignSubject(
                            schoolId: schoolId,
                            teacherId: widget.teacherId,
                            teacherName: widget.teacherName,
                            subjectId: subjectId,
                            subjectName: subject['namaMapel'],
                          );

                          assigned.add(subjectId);
                        } else {
                          await service.removeSubject(
                            teacherId: widget.teacherId,
                            subjectId: subjectId,
                          );

                          assigned.remove(subjectId);
                        }

                        setState(() {});
                      },
                    );
                  },
                );
              },
            ),
    );
  }
}
