import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

class LinkService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const linkDuration = Duration(minutes: 10);

  CollectionReference<Map<String, dynamic>> _tokensRef(String schoolId) =>
      _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('parent_link_tokens');

  CollectionReference<Map<String, dynamic>> _parentsRef(String schoolId) =>
      _firestore.collection('schools').doc(schoolId).collection('parents');

  String _generateToken() {
    const chars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random.secure();
    return List.generate(32, (_) => chars[random.nextInt(chars.length)]).join();
  }

  /// Generate token + simpan ke Firestore, return payload JSON untuk QR.
  Future<Map<String, dynamic>> generateLinkPayload({
    required String schoolId,
    required String studentId,
    required String studentName,
  }) async {
    final token = _generateToken();
    final expiresAt = DateTime.now().add(linkDuration);

    await _tokensRef(schoolId).doc(token).set({
      'token': token,
      'schoolId': schoolId,
      'studentId': studentId,
      'studentName': studentName,
      'expiresAt': Timestamp.fromDate(expiresAt),
      'used': false,
      'createdAt': FieldValue.serverTimestamp(),
    });

    return {
      'schoolId': schoolId,
      'studentId': studentId,
      'studentName': studentName,
      'token': token,
      'expiresAt': expiresAt.toUtc().toIso8601String(),
    };
  }

  String encodePayload(Map<String, dynamic> payload) => jsonEncode(payload);

  Map<String, dynamic> decodePayload(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      throw ('Format QR tidak valid.');
    }
    return decoded;
  }

  /// Verifikasi token lalu hubungkan orang tua ke murid.
  Future<void> linkParentToStudent({
    required String parentUid,
    required String parentName,
    required String parentEmail,
    required String qrRaw,
  }) async {
    final payload = decodePayload(qrRaw);

    final schoolId = (payload['schoolId'] ?? '').toString();
    final studentId = (payload['studentId'] ?? '').toString();
    final studentName = (payload['studentName'] ?? '').toString();
    final token = (payload['token'] ?? '').toString();

    if (schoolId.isEmpty || studentId.isEmpty || token.isEmpty) {
      throw ('Data QR tidak lengkap.');
    }

    final tokenDoc = await _tokensRef(schoolId).doc(token).get();
    if (!tokenDoc.exists) {
      throw ('Token tidak ditemukan atau sudah tidak berlaku.');
    }

    final tokenData = tokenDoc.data()!;
    if (tokenData['used'] == true) {
      throw ('QR Code sudah digunakan.');
    }

    final expiresAt = tokenData['expiresAt'] as Timestamp?;
    if (expiresAt == null || expiresAt.toDate().isBefore(DateTime.now())) {
      throw ('QR Code sudah kedaluwarsa. Minta anak buat QR baru.');
    }

    if (tokenData['studentId'] != studentId) {
      throw ('Token tidak cocok dengan data murid.');
    }

    final studentRef = _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('students')
        .doc(studentId);

    final studentDoc = await studentRef.get();
    if (!studentDoc.exists) {
      throw ('Data murid tidak ditemukan.');
    }

    final studentData = studentDoc.data()!;
    if (studentData['parentLinked'] == true) {
      throw ('Murid ini sudah terhubung dengan orang tua.');
    }

    final parentDocRef = _parentsRef(schoolId).doc(parentUid);
    final batch = _firestore.batch();

    batch.set(parentDocRef, {
      'parentId': parentUid,
      'uid': parentUid,
      'nama': parentName,
      'email': parentEmail,
      'studentId': studentId,
      'studentName': studentName.isNotEmpty
          ? studentName
          : (studentData['nama'] ?? 'Murid'),
      'className': studentData['className'] ?? '',
      'schoolId': schoolId,
      'aktif': true,
      'createdAt': FieldValue.serverTimestamp(),
    });

    batch.update(studentRef, {
      'parentLinked': true,
      'parentId': parentUid,
    });

    batch.update(_tokensRef(schoolId).doc(token), {'used': true});

    batch.update(_firestore.collection('users').doc(parentUid), {
      'schoolId': schoolId,
      'aktif': true,
    });

    await batch.commit();
  }
}
