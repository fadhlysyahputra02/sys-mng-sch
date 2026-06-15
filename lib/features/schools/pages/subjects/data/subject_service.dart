import 'package:cloud_firestore/cloud_firestore.dart';

class SubjectService {
  final _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _subjectsRef(String schoolId) =>
      _db.collection('schools').doc(schoolId).collection('subjects');

  Stream<QuerySnapshot<Map<String, dynamic>>> getSubjects(String schoolId) {
    return _subjectsRef(schoolId).snapshots();
  }

  Future<void> addSubject({
    required String schoolId,
    required String kodeMapel,
    required String namaMapel,
    required String kategori,
    required int kkm,
  }) async {
    final doc = _subjectsRef(schoolId).doc();

    await doc.set({
      'subjectId': doc.id,
      'schoolId': schoolId,
      'kodeMapel': kodeMapel,
      'namaMapel': namaMapel,
      'kategori': kategori,
      'kkm': kkm,
      'aktif': true,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteSubject({
    required String schoolId,
    required String subjectId,
  }) async {
    await _subjectsRef(schoolId).doc(subjectId).delete();
  }

  Future<void> updateSubject({
    required String schoolId,
    required String subjectId,
    required String namaMapel,
    required String kodeMapel,
    required String kategori,
    required int kkm,
  }) async {
    await _subjectsRef(schoolId).doc(subjectId).update({
      'namaMapel': namaMapel,
      'kodeMapel': kodeMapel,
      'kategori': kategori,
      'kkm': kkm,
    });
  }
}
