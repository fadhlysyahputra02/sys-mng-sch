import 'package:cloud_firestore/cloud_firestore.dart';

class StudentService {
  final _db = FirebaseFirestore.instance;

  Future<void> createStudent({
    required String schoolId,
    required String nis,
    required String nama,
  }) async {
    // Cek NIS sudah ada atau belum dalam sekolah yang sama
    final existing = await _db
        .collection('students')
        .where('schoolId', isEqualTo: schoolId)
        .where('nis', isEqualTo: nis)
        .get();

    if (existing.docs.isNotEmpty) {
      throw Exception('NIS sudah terdaftar');
    }

    final doc = _db.collection('students').doc();

    await doc.set({
      'studentId': doc.id,
      'schoolId': schoolId,
      'uid': '',
      'email': '',
      'nis': nis,
      'nama': nama,
      'classId': null,
      'aktif': true,
      'sudahRegister': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> getStudentsByClass(
    String classId,
  ) {
    return _db
        .collection('students')
        .where('classId', isEqualTo: classId)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> getStudentsWithoutClass(
    String schoolId,
  ) {
    return _db
        .collection('students')
        .where('schoolId', isEqualTo: schoolId)
        .where('classId', isNull: true)
        .snapshots();
  }

  Future<void> assignStudentToClass({
    required String studentId,
    required String classId,
  }) async {
    final classDoc = await _db.collection('classes').doc(classId).get();

    if (!classDoc.exists) {
      throw Exception('Kelas tidak ditemukan');
    }

    final className = classDoc.data()?['namaKelas'] ?? '';

    await _db.collection('students').doc(studentId).update({
      'classId': classId,
      'className': className,
    });
  }

  Future<void> removeStudentFromClass(String studentId) async {
    await _db.collection('students').doc(studentId).update({'classId': null});
  }

  Future<void> deleteStudent(String studentId) async {
    await _db.collection('students').doc(studentId).delete();
  }
}
