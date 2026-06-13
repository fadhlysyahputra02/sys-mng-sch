import 'package:cloud_firestore/cloud_firestore.dart';

class TeacherService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _teachersRef(String schoolId) =>
      _db.collection('schools').doc(schoolId).collection('teachers');

  Stream<QuerySnapshot<Map<String, dynamic>>> getTeachers(String schoolId) {
    return _teachersRef(schoolId).snapshots();
  }

  /// Cari dokumen guru berdasarkan Firebase Auth UID
  Future<QueryDocumentSnapshot<Map<String, dynamic>>?> getTeacherByUid(
    String schoolId,
    String uid,
  ) async {
    final result = await _teachersRef(schoolId)
        .where('uid', isEqualTo: uid)
        .limit(1)
        .get();

    if (result.docs.isEmpty) return null;
    return result.docs.first;
  }

  /// Ambil kelas-kelas yang dipercayakan sebagai wali kelas
  Stream<QuerySnapshot<Map<String, dynamic>>> getClassesByTeacher(
    String schoolId,
    String teacherId,
  ) {
    return _db
        .collection('schools')
        .doc(schoolId)
        .collection('classes')
        .where('teacherId', isEqualTo: teacherId)
        .snapshots();
  }
}
