import 'package:cloud_firestore/cloud_firestore.dart';

class TeacherService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> createTeacher({
    required String schoolId,
    required String nip,
    required String nama,
  }) async {
    final docId = '${schoolId}_$nip';

    await _firestore.collection('teachers').doc(docId).set({
      'schoolId': schoolId,
      'nip': nip,
      'nama': nama,
      'sudahRegister': false,
      'uid': null,
      'aktif': true,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> getTeachers(String schoolId) {
    return _firestore
        .collection('teachers')
        .where('schoolId', isEqualTo: schoolId)
        .snapshots();
  }
}
