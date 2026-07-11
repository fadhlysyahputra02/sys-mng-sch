import 'package:cloud_firestore/cloud_firestore.dart';

class ExamBehaviorService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _behaviorRef(String schoolId) =>
      _firestore.collection('schools').doc(schoolId).collection('exam_behavior_records');

  /// Membuat atau memperbarui status behavior murid selama ujian
  Future<void> reportExamBehavior({
    required String schoolId,
    required String studentId,
    required String studentName,
    required String className,
    required String sessionId,
    required String subjectName,
    required String roomName,
    required int seatNumber,
    required String type,
    required String description,
    required String tahunAjaran,
    required String semester,
  }) async {
    final docId = '${studentId}_$sessionId';
    final now = Timestamp.now();
    final logEntry = {
      'type': type,
      'description': description,
      'timestamp': now,
    };

    await _behaviorRef(schoolId).doc(docId).set({
      'recordId': docId,
      'studentId': studentId,
      'studentName': studentName,
      'className': className,
      'sessionId': sessionId,
      'subjectName': subjectName,
      'roomName': roomName,
      'seatNumber': seatNumber,
      'type': type,
      'description': description,
      'timestamp': FieldValue.serverTimestamp(),
      'tahunAjaran': tahunAjaran,
      'semester': semester,
      'activityLog': FieldValue.arrayUnion([logEntry]),
    }, SetOptions(merge: true));
  }

  /// Memantau behavior seluruh murid pada suatu sesi ujian secara realtime
  Stream<QuerySnapshot<Map<String, dynamic>>> getExamBehaviorStream({
    required String schoolId,
    required String sessionId,
  }) {
    return _behaviorRef(schoolId)
        .where('sessionId', isEqualTo: sessionId)
        .snapshots();
  }

  /// Menghapus semua behavior records untuk satu sesi ujian tertentu (saat sesi diakhiri/dihapus)
  Future<void> deleteExamBehaviorForSession({
    required String schoolId,
    required String sessionId,
  }) async {
    try {
      final snapshot = await _behaviorRef(schoolId)
          .where('sessionId', isEqualTo: sessionId)
          .get();

      if (snapshot.docs.isEmpty) return;

      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    } catch (e) {
      // ignore
    }
  }

  /// Menghapus behavior record untuk murid tertentu pada sesi ujian tertentu (saat murid selesai mengumpulkan)
  Future<void> deleteStudentExamBehavior({
    required String schoolId,
    required String studentId,
    required String sessionId,
  }) async {
    final docId = '${studentId}_$sessionId';
    await _behaviorRef(schoolId).doc(docId).delete();
  }
}
