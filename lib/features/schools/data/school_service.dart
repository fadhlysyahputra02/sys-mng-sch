import 'package:cloud_firestore/cloud_firestore.dart';

class SchoolService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

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

    if (!doc.exists) {
      return null;
    }

    return doc.data();
  }
}
