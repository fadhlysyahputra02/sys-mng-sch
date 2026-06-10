import 'package:cloud_firestore/cloud_firestore.dart';

class SubjectService {
  final _db = FirebaseFirestore.instance;

  Stream<QuerySnapshot> getSubjects(String schoolId) {
    return _db
        .collection('subjects')
        .where('schoolId', isEqualTo: schoolId)
        .snapshots();
  }

  Future<void> addSubject({
    required String schoolId,
    required String kodeMapel,
    required String namaMapel,
    required String kategori,
  }) async {
    final doc = _db.collection('subjects').doc();

    await doc.set({
      'subjectId': doc.id,
      'schoolId': schoolId,
      'kodeMapel': kodeMapel,
      'namaMapel': namaMapel,
      'kategori': kategori,
      'aktif': true,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteSubject(String subjectId) async {
    await _db.collection('subjects').doc(subjectId).delete();
  }
}
