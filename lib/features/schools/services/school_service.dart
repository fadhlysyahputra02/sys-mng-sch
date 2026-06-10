import 'package:cloud_firestore/cloud_firestore.dart';

class SchoolService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<Map<String, dynamic>?> getTeacherByNip({
    required String schoolId,
    required String nip,
  }) async {
    final result = await FirebaseFirestore.instance
        .collection('teachers')
        .where('schoolId', isEqualTo: schoolId)
        .where('nip', isEqualTo: nip)
        .limit(1)
        .get();

    if (result.docs.isEmpty) {
      return null;
    }

    return result.docs.first.data();
  }

  Future<Map<String, dynamic>?> getStudentByNis({
    required String schoolId,
    required String nis,
  }) async {
    final result = await FirebaseFirestore.instance
        .collection('students')
        .where('schoolId', isEqualTo: schoolId)
        .where('nis', isEqualTo: nis)
        .limit(1)
        .get();

    if (result.docs.isEmpty) {
      return null;
    }

    final doc = result.docs.first;

    final data = doc.data();

    data['docId'] = doc.id;

    return data;
  }

  Future<void> updateTeacherRegistration({
    required String teacherId,
    required String uid,
    required String email,
    required String nama,
  }) async {
    await FirebaseFirestore.instance
        .collection('teachers')
        .doc(teacherId)
        .update({'uid': uid, 'email': email, 'sudahRegister': true});
  }

  Future<void> updateStudentRegistration({
    required String studentId,
    required String uid,
    required String email,
    required String nama,
  }) async {
    await FirebaseFirestore.instance
        .collection('students')
        .doc(studentId)
        .update({'uid': uid, 'email': email, 'sudahRegister': true});
  }

  Future<void> createSchool({
    required String schoolId,
    required String namaSekolah,
    required String domain,
    required String kodeAdmin,
  }) async {
    final docRef = _firestore.collection('schools').doc(domain);
    final doc = await docRef.get();

    if (doc.exists) {
      throw Exception('Domain sudah digunakan');
    }

    await docRef.set({
      'schoolId': schoolId,
      'namaSekolah': namaSekolah,
      'domain': domain,
      'kodeAdmin': kodeAdmin,
      'aktif': true,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<Map<String, dynamic>?> getSchoolByDomain(String domain) async {
    final doc = await _firestore.collection('schools').doc(domain).get();
    if (!doc.exists) return null;
    return doc.data();
  }

  // Ambil semua sekolah untuk dropdown di halaman register guru/murid
  Future<List<Map<String, dynamic>>> getAllSchools() async {
    final snapshot = await _firestore
        .collection('schools')
        .where('aktif', isEqualTo: true)
        .get();

    return snapshot.docs.map((doc) => doc.data()).toList();
  }

  // Validasi NIP guru: pastikan terdaftar di sekolah tersebut dan aktif
  Future<bool> validateTeacher({
    required String schoolId,
    required String nip,
  }) async {
    final snapshot = await _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('teachers')
        .where('nip', isEqualTo: nip)
        .where('aktif', isEqualTo: true)
        .get();

    return snapshot.docs.isNotEmpty;
  }

  // Validasi NIS murid: pastikan terdaftar di sekolah tersebut dan aktif
  Future<bool> validateStudent({
    required String schoolId,
    required String nis,
  }) async {
    final snapshot = await _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('students')
        .where('nis', isEqualTo: nis)
        .where('aktif', isEqualTo: true)
        .get();

    return snapshot.docs.isNotEmpty;
  }
}
