import 'package:cloud_firestore/cloud_firestore.dart';

class TeacherSubjectService {
  final _db = FirebaseFirestore.instance;

  Future<List<String>> getAssignedSubjects(String teacherId) async {
    final result = await _db
        .collection('teacher_subjects')
        .where('teacherId', isEqualTo: teacherId)
        .get();

    return result.docs.map((e) => e['subjectId'] as String).toList();
  }

  Future<void> assignSubject({
    required String schoolId,
    required String teacherId,
    required String teacherName,
    required String subjectId,
    required String subjectName,
  }) async {
    final exists = await _db
        .collection('teacher_subjects')
        .where('teacherId', isEqualTo: teacherId)
        .where('subjectId', isEqualTo: subjectId)
        .limit(1)
        .get();

    if (exists.docs.isNotEmpty) return;

    final doc = _db.collection('teacher_subjects').doc();

    await doc.set({
      'id': doc.id,
      'schoolId': schoolId,
      'teacherId': teacherId,
      'teacherName': teacherName,
      'subjectId': subjectId,
      'subjectName': subjectName,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> removeSubject({
    required String teacherId,
    required String subjectId,
  }) async {
    final result = await _db
        .collection('teacher_subjects')
        .where('teacherId', isEqualTo: teacherId)
        .where('subjectId', isEqualTo: subjectId)
        .get();

    for (final doc in result.docs) {
      await doc.reference.delete();
    }
  }
}
