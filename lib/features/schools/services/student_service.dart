import 'package:cloud_firestore/cloud_firestore.dart';

class StudentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> createStudent({
    required String schoolId,
    required String nis,
    required String nama,
    bool aktif = true,
  }) async {
    // Cek apakah NIS sudah terdaftar di sekolah ini
    final existing = await _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('students')
        .where('nis', isEqualTo: nis)
        .get();

    if (existing.docs.isNotEmpty) {
      throw Exception('NIS $nis sudah terdaftar di sekolah ini');
    }

    await _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('students')
        .add({
          'nis': nis,
          'nama': nama,
          'aktif': aktif,
          'createdAt': FieldValue.serverTimestamp(),
        });
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> getStudents(String schoolId) {
    return _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('students')
        .orderBy('nama')
        .snapshots();
  }
}
