import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../../core/services/session_service.dart';

class TeacherSubjectService {
  final _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _teacherSubjectsRef(
      String schoolId) =>
      _db
          .collection('schools')
          .doc(schoolId)
          .collection('teacher_subjects');

  Future<List<String>> getAssignedSubjects(String teacherId) async {
    final schoolId = SessionService.currentUser!.schoolId;
    final result = await _teacherSubjectsRef(schoolId)
        .where('teacherId', isEqualTo: teacherId)
        .get();

    return result.docs.map((e) => e['subjectId'] as String).toList();
  }

  /// Stream real-time semua mata pelajaran yang di-assign ke guru
  Stream<QuerySnapshot<Map<String, dynamic>>> getSubjectsByTeacher(
    String schoolId,
    String teacherId,
  ) {
    return _teacherSubjectsRef(schoolId)
        .where('teacherId', isEqualTo: teacherId)
        .snapshots();
  }

  Future<void> assignSubject({
    required String schoolId,
    required String teacherId,
    required String teacherName,
    required String subjectId,
    required String subjectName,
  }) async {
    final exists = await _teacherSubjectsRef(schoolId)
        .where('teacherId', isEqualTo: teacherId)
        .where('subjectId', isEqualTo: subjectId)
        .limit(1)
        .get();

    if (exists.docs.isNotEmpty) return;

    final doc = _teacherSubjectsRef(schoolId).doc();

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
    final schoolId = SessionService.currentUser!.schoolId;
    final result = await _teacherSubjectsRef(schoolId)
        .where('teacherId', isEqualTo: teacherId)
        .where('subjectId', isEqualTo: subjectId)
        .get();

    for (final doc in result.docs) {
      await doc.reference.delete();
    }
  }
}
