import 'package:cloud_firestore/cloud_firestore.dart';

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<Map<String, dynamic>?> getUserById(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();

    if (!doc.exists) {
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
    await FirebaseFirestore.instance.collection('users').doc(uid).set({
      'email': email,
      'nama': nama,
      'role': role,
      'schoolId': schoolId,
      'aktif': true,
      if (password != null) 'password': password,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
