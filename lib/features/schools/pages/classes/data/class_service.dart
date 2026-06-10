import 'package:cloud_firestore/cloud_firestore.dart';

class ClassService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _classes =>
      _firestore.collection('classes');

  Future<void> addClass({
    required String schoolId,
    required String namaKelas,
  }) async {
    await _classes.add({
      'schoolId': schoolId,
      'namaKelas': namaKelas,
      'teacherId': null,
      'teacherName': null,
      'aktif': true,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateClass({
    required String classId,
    required String namaKelas,
  }) async {
    await _classes.doc(classId).update({'namaKelas': namaKelas});
  }

  Future<void> deleteClass(String classId) async {
    await _classes.doc(classId).delete();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> getClasses(String schoolId) {
    return _firestore
        .collection('classes')
        .where('schoolId', isEqualTo: schoolId)
        .snapshots();
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> getClassById(String classId) {
    return _firestore.collection('classes').doc(classId).snapshots();
  }

  Future<void> assignWaliKelas({
    required String classId,
    required String teacherId,
    required String teacherName,
  }) async {
    await _firestore.collection('classes').doc(classId).update({
      'teacherId': teacherId,
      'teacherName': teacherName,
    });
  }
}
