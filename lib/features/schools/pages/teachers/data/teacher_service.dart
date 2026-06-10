import 'package:cloud_firestore/cloud_firestore.dart';

class TeacherService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<QuerySnapshot<Map<String, dynamic>>> getTeachers(String schoolId) {
    return _db
        .collection('teachers')
        .where('schoolId', isEqualTo: schoolId)
        .snapshots();
  }
}
