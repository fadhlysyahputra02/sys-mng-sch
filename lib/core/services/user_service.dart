import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sys_mng_school/core/utils/doc_id_util.dart';

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<Map<String, dynamic>?> getUserById(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();

    if (!doc.exists) {
      final query = await _firestore
          .collection('users')
          .where('uid', isEqualTo: uid)
          .limit(1)
          .get();
      if (query.docs.isNotEmpty) {
        final userData = query.docs.first.data();
        final docId = query.docs.first.id;
        // Self-heal user_uids document if missing
        try {
          await _firestore.collection('user_uids').doc(uid).set({
            ...userData,
            'userDocId': docId,
          }, SetOptions(merge: true));
        } catch (e) {
          // ignore background sync errors
        }
        return userData;
      }
      return null;
    }

    return doc.data();
  }

  Future<void> createUser({
    required String uid,
    required String email,
    required String nama,
    required String role,
    required String schoolId,
    String? password,
  }) async {
    final docId = generateFormattedDocId(nama);
    final userData = {
      'uid': uid,
      'email': email,
      'nama': nama,
      'role': role,
      'schoolId': schoolId,
      'aktif': true,
      'userDocId': docId,
      if (password != null) 'password': password,
      'createdAt': FieldValue.serverTimestamp(),
    };

    final batch = _firestore.batch();
    batch.set(_firestore.collection('users').doc(docId), userData);
    batch.set(_firestore.collection('user_uids').doc(uid), userData);
    await batch.commit();
  }
}
