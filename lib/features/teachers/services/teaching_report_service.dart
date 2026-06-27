import 'package:cloud_firestore/cloud_firestore.dart';

class TeachingReportService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> submitReport({
    required String schoolId,
    required String teacherId,
    required String teacherName,
    required String classId,
    required String className,
    required String subjectName,
    required String scheduleId,
    required String dateStr,
    required String tahunAjaran,
    required String semester,
    required String materi,
    required String catatan,
  }) async {
    try {
      final docRef = _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('teaching_reports')
          .doc();

      await docRef.set({
        'teacherId': teacherId,
        'teacherName': teacherName,
        'classId': classId,
        'className': className,
        'subjectName': subjectName,
        'scheduleId': scheduleId,
        'date': dateStr,
        'timestamp': FieldValue.serverTimestamp(),
        'tahunAjaran': tahunAjaran,
        'semester': semester,
        'materi': materi,
        'catatan': catatan,
      });
    } catch (e) {
      throw ('Gagal menyimpan laporan mengajar: $e');
    }
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> getReportsStream(String schoolId) {
    return _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('teaching_reports')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  Future<void> deleteOldReports(String schoolId) async {
    try {
      final threeYearsAgo = DateTime.now().subtract(const Duration(days: 365 * 3));
      final snapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('teaching_reports')
          .where('timestamp', isLessThan: Timestamp.fromDate(threeYearsAgo))
          .get();

      if (snapshot.docs.isNotEmpty) {
        final batch = _firestore.batch();
        for (var doc in snapshot.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();
      }
    } catch (e) {
      // Ignored for background cleanup
    }
  }
}
