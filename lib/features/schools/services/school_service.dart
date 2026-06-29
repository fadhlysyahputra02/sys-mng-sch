import 'package:cloud_firestore/cloud_firestore.dart';

class SchoolService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<Map<String, dynamic>?> getTeacherByNip({
    required String schoolId,
    required String nip,
  }) async {
    final result = await _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('teachers')
        .where('nip', isEqualTo: nip)
        .limit(1)
        .get();

    if (result.docs.isEmpty) {
      return null;
    }

    final doc = result.docs.first;
    final data = doc.data();
    data['teacherId'] = doc.id;
    return data;
  }

  Future<Map<String, dynamic>?> getStudentByNis({
    required String schoolId,
    required String nis,
  }) async {
    final result = await _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('students')
        .where('nis', isEqualTo: nis)
        .limit(1)
        .get();

    if (result.docs.isEmpty) {
      return null;
    }

    final doc = result.docs.first;
    final data = doc.data();
    data['studentId'] = doc.id;
    data['docId'] = doc.id;
    return data;
  }

  Future<void> updateTeacherRegistration({
    required String schoolId,
    required String teacherId,
    required String uid,
    required String email,
    required String nama,
  }) async {
    await _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('teachers')
        .doc(teacherId)
        .update({'uid': uid, 'email': email, 'sudahRegister': true});
  }

  Future<void> updateStudentRegistration({
    required String schoolId,
    required String studentId,
    required String uid,
    required String email,
    required String nama,
  }) async {
    await _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('students')
        .doc(studentId)
        .update({'uid': uid, 'email': email, 'sudahRegister': true});
  }

  Future<void> createSchool({
    required String schoolId,
    required String namaSekolah,
    required String domain,
    required String kodeAdmin,
    required String plan,
  }) async {
    final docRef = _firestore.collection('schools').doc(domain);
    final doc = await docRef.get();

    if (doc.exists) {
      throw ('Domain sudah digunakan');
    }

    await docRef.set({
      'schoolId': schoolId,
      'namaSekolah': namaSekolah,
      'domain': domain,
      'kodeAdmin': kodeAdmin,
      'plan': plan,
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

  // Stream all schools for super admin dashboard
  Stream<List<Map<String, dynamic>>> getSchoolsStream() {
    return _firestore.collection('schools').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    });
  }

  // Update subscription package plan of a school
  Future<void> updateSchoolPlan({
    required String domain,
    required String plan,
  }) async {
    await _firestore.collection('schools').doc(domain).update({
      'plan': plan,
    });
  }

  // Delete school and associated admin users
  Future<void> deleteSchool(String domain) async {
    await _firestore.collection('schools').doc(domain).delete();

    // Delete users associated with this school (school_admin, teacher, student, parent)
    final usersSnapshot = await _firestore
        .collection('users')
        .where('schoolId', isEqualTo: domain)
        .get();

    for (var doc in usersSnapshot.docs) {
      await doc.reference.delete();
    }
  }

  // Get admin user for a school domain
  Future<Map<String, dynamic>?> getSchoolAdmin(String domain) async {
    final result = await _firestore
        .collection('users')
        .where('schoolId', isEqualTo: domain)
        .where('role', isEqualTo: 'school_admin')
        .limit(1)
        .get();

    if (result.docs.isEmpty) {
      return null;
    }

    final doc = result.docs.first;
    final data = doc.data();
    data['uid'] = doc.id;
    return data;
  }

  // Update bypass schedule lock flag
  Future<void> updateBypassScheduleLock({
    required String domain,
    required bool allowBypass,
  }) async {
    await _firestore.collection('schools').doc(domain).update({
      'allowBypassScheduleLock': allowBypass,
    });
  }
}
