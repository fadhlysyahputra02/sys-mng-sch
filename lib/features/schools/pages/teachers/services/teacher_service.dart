// import 'package:cloud_firestore/cloud_firestore.dart';

// class TeacherService {
//   final _db = FirebaseFirestore.instance;

//   Stream<QuerySnapshot> getTeachers(String schoolId) {
//     return _db
//         .collection('teachers')
//         .where('schoolId', isEqualTo: schoolId)
//         .snapshots();
//   }

//   Future<void> addTeacher({
//     required String schoolId,
//     required String nip,
//     required String nama,
//   }) async {
//     final doc = _db.collection('teachers').doc();

//     await doc.set({
//       'teacherId': doc.id,
//       'schoolId': schoolId,
//       'uid': '',
//       'email': '',
//       'nip': nip,
//       'nama': nama,
//       'aktif': true,
//       'sudahRegister': false,
//       'createdAt': FieldValue.serverTimestamp(),
//     });
//   }

//   Future<void> deleteTeacher(String teacherId) async {
//     await _db.collection('teachers').doc(teacherId).delete();
//   }
// }
