import 'package:cloud_firestore/cloud_firestore.dart';

import '../model/student_model.dart';

class StudentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Cari murid berdasarkan UID menggunakan collectionGroup (tidak perlu schoolId)
  Stream<StudentModel?> getStudentByUid(String uid) {
    return _firestore
        .collectionGroup('students')
        .where('uid', isEqualTo: uid)
        .limit(1)
        .snapshots()
        .map((snapshot) {
          if (snapshot.docs.isEmpty) {
            return null;
          }

          final doc = snapshot.docs.first;

          return StudentModel.fromMap(doc.id, doc.data());
        });
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> getStudentsByClass(
    String classId,
  ) {
    return _firestore
        .collectionGroup('students')
        .where('classId', isEqualTo: classId)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> getStudentsWithoutClass(
    String schoolId,
  ) {
    return _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('students')
        .where('classId', isNull: true)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> getStudentsBySchool(
    String schoolId,
  ) {
    return _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('students')
        .snapshots();
  }

  Future<void> assignStudentToClass({
    required String studentId,
    required String classId,
    required String schoolId,
  }) async {
    await _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('students')
        .doc(studentId)
        .update({
      'classId': classId,
    });
  }

  Future<void> removeStudentFromClass(
    String studentId, {
    required String schoolId,
  }) async {
    await _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('students')
        .doc(studentId)
        .update({
      'classId': null,
    });
  }
}
