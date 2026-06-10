import 'package:cloud_firestore/cloud_firestore.dart';

import '../model/student_model.dart';

class StudentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<StudentModel?> getStudentByUid(String uid) {
    return _firestore
        .collection('students')
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

  // TAMBAHKAN DI SINI

  Stream<QuerySnapshot<Map<String, dynamic>>> getStudentsWithoutClass(
    String schoolId,
  ) {
    return _firestore
        .collection('students')
        .where('schoolId', isEqualTo: schoolId)
        .where('classId', isNull: true)
        .snapshots();
  }

  Future<void> assignStudentToClass({
    required String studentId,
    required String classId,
  }) async {
    await _firestore.collection('students').doc(studentId).update({
      'classId': classId,
    });
  }
}
