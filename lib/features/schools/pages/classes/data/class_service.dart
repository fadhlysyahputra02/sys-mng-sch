import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../../core/services/session_service.dart';

class ClassService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _classesRef(String schoolId) =>
      _firestore.collection('schools').doc(schoolId).collection('classes');

  Future<void> addClass({
    required String schoolId,
    required String namaKelas,
  }) async {
    await _classesRef(schoolId).add({
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
    final schoolId = SessionService.currentUser!.schoolId;
    await _classesRef(schoolId).doc(classId).update({'namaKelas': namaKelas});
  }

  Future<void> deleteClass(String classId) async {
    final schoolId = SessionService.currentUser!.schoolId;
    await _classesRef(schoolId).doc(classId).delete();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> getClasses(String schoolId) {
    return _classesRef(schoolId).snapshots();
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> getClassById(String classId) {
    final schoolId = SessionService.currentUser!.schoolId;
    return _classesRef(schoolId).doc(classId).snapshots();
  }

  Future<void> assignWaliKelas({
    required String classId,
    required String teacherId,
    required String teacherName,
  }) async {
    final schoolId = SessionService.currentUser!.schoolId;
    await _classesRef(schoolId).doc(classId).update({
      'teacherId': teacherId,
      'teacherName': teacherName,
    });
  }

  Future<void> removeWaliKelas({
    required String classId,
  }) async {
    final schoolId = SessionService.currentUser!.schoolId;
    await _classesRef(schoolId).doc(classId).update({
      'teacherId': null,
      'teacherName': null,
    });
  }
}
