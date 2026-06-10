import 'package:cloud_firestore/cloud_firestore.dart';

class StudentService {
  final _db = FirebaseFirestore.instance;

  Future<void> addStudent({
    required String schoolId,
    required String nis,
    required String nama,
  }) async {
    final doc = _db.collection('students').doc();

    await doc.set({
      'studentId': doc.id,
      'schoolId': schoolId,
      'uid': '',
      'email': '',
      'nis': nis,
      'nama': nama,
      'aktif': true,
      'sudahRegister': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<QuerySnapshot> getStudents(String schoolId) {
    return _db
        .collection('students')
        .where('schoolId', isEqualTo: schoolId)
        .orderBy('nama')
        .snapshots();
  }

  Future<void> deleteStudent(String studentId) async {
    await _db.collection('students').doc(studentId).delete();
  }
}
