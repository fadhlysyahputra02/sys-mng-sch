import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import '../model/student_model.dart';

class StudentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Fetch student document by UID from school subcollection (returns Future<DocumentSnapshot>)
  Future<DocumentSnapshot<Map<String, dynamic>>?> getStudentDocByUid(String schoolId, String uid) async {
    final querySnapshot = await _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('students')
        .where('uid', isEqualTo: uid)
        .limit(1)
        .get();
    if (querySnapshot.docs.isEmpty) {
      return null;
    }
    return querySnapshot.docs.first;
  }

  /// Existing stream method for real‑time updates
  Stream<StudentModel?> getStudentByUid(String uid) {
    return _firestore
        .collectionGroup('students')
        .where('uid', isEqualTo: uid)
        .limit(1)
        .snapshots()
        .map((snapshot) {
          if (snapshot.docs.isEmpty) {
            return null;
          }
          final doc = snapshot.docs.first;
          return StudentModel.fromMap(doc.id, doc.data());
        });
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> getStudentsByClass(
    String classId, {
    String? schoolId,
  }) {
    if (schoolId != null) {
      return _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('students')
          .where('classId', isEqualTo: classId)
          .snapshots();
    }
    return _firestore
        .collectionGroup('students')
        .where('classId', isEqualTo: classId)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> getStudentsWithoutClass(
    String schoolId,
  ) {
    return _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('students')
        .where('classId', isNull: true)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> getStudentsBySchool(
    String schoolId,
  ) {
    return _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('students')
        .snapshots();
  }

  Future<void> assignStudentToClass({
    required String studentId,
    required String classId,
    required String schoolId,
  }) async {
    await _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('students')
        .doc(studentId)
        .update({
      'classId': classId,
    });
  }

  Future<void> removeStudentFromClass(
    String studentId, {
    required String schoolId,
  }) async {
    await _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('students')
        .doc(studentId)
        .update({
      'classId': null,
    });
  }

  /// Menghapus (mengosongkan) seluruh murid dari suatu kelas sekaligus menggunakan WriteBatch
  Future<void> emptyClass({
    required String classId,
    required String schoolId,
  }) async {
    final querySnapshot = await _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('students')
        .where('classId', isEqualTo: classId)
        .get();

    if (querySnapshot.docs.isEmpty) return;

    final batch = _firestore.batch();
    for (var doc in querySnapshot.docs) {
      batch.update(doc.reference, {'classId': null});
    }
    await batch.commit();
  }

  /// Menambahkan sekumpulan murid ke suatu kelas sekaligus menggunakan WriteBatch
  Future<void> assignMultipleStudentsToClass({
    required List<String> studentIds,
    required String classId,
    required String schoolId,
  }) async {
    if (studentIds.isEmpty) return;
    
    final batch = _firestore.batch();
    for (var studentId in studentIds) {
      final docRef = _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('students')
          .doc(studentId);
      batch.update(docRef, {'classId': classId});
    }
    await batch.commit();
  }
  /// Fetch student document by UID within a specific school subcollection (returns Future<DocumentSnapshot>)
  Future<DocumentSnapshot<Map<String, dynamic>>?> getStudentDocByUidInSchool(String schoolId, String uid) async {
    final querySnapshot = await _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('students')
        .where('uid', isEqualTo: uid)
        .limit(1)
        .get();
    if (querySnapshot.docs.isEmpty) {
      return null;
    }
    return querySnapshot.docs.first;
  }

  /// Stream of today's attendance for a specific student
  Stream<DocumentSnapshot<Map<String, dynamic>>?> getTodayAttendanceStream({
    required String schoolId,
    required String studentId,
    required String dateStr,
  }) {
    return _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('attendance')
        .doc('${studentId}_$dateStr')
        .snapshots()
        .map((doc) => doc.exists ? doc : null);
  }

  /// Check in attendance for a student
  Future<void> checkInAttendance({
    required String schoolId,
    required String studentId,
    required String studentName,
    required String? classId,
    required String? className,
    required String dateStr,
    required String tahunAjaran,
    required String semester,
  }) async {
    await _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('attendance')
        .doc('${studentId}_$dateStr')
        .set({
      'studentId': studentId,
      'studentName': studentName,
      'classId': classId,
      'className': className,
      'date': dateStr,
      'timestamp': FieldValue.serverTimestamp(),
      'status': 'Hadir',
      'tahunAjaran': tahunAjaran,
      'semester': semester,
    });
  }

  /// Stream of check-in status for a specific schedule, student, and date
  Stream<DocumentSnapshot<Map<String, dynamic>>?> getScheduleAttendanceStream({
    required String schoolId,
    required String studentId,
    required String scheduleId,
    required String dateStr,
  }) {
    return _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('attendance')
        .doc('${studentId}_${scheduleId}_$dateStr')
        .snapshots()
        .map((doc) => doc.exists ? doc : null);
  }

  /// Stream of all checked-in students for a specific schedule and date (used by the teacher)
  Stream<QuerySnapshot<Map<String, dynamic>>> getScheduleAttendanceListStream({
    required String schoolId,
    required String scheduleId,
    required String dateStr,
  }) {
    return _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('attendance')
        .where('scheduleId', isEqualTo: scheduleId)
        .where('date', isEqualTo: dateStr)
        .snapshots();
  }

  /// Check-in specifically for a class schedule session (QR or Code check-in)
  Future<void> checkInScheduleAttendance({
    required String schoolId,
    required String studentId,
    required String studentName,
    required String? classId,
    required String? className,
    required String scheduleId,
    required String subjectName,
    required String dateStr,
    required String checkInMethod,
    required String tahunAjaran,
    required String semester,
    String status = 'Hadir',
  }) async {
    await _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('attendance')
        .doc('${studentId}_${scheduleId}_$dateStr')
        .set({
      'studentId': studentId,
      'studentName': studentName,
      'classId': classId,
      'className': className,
      'scheduleId': scheduleId,
      'subjectName': subjectName,
      'date': dateStr,
      'timestamp': FieldValue.serverTimestamp(),
      'status': status,
      'method': checkInMethod,
      'tahunAjaran': tahunAjaran,
      'semester': semester,
    });
  }

  /// Report student app focus or behavior violation
  Future<void> reportBehaviorViolation({
    required String schoolId,
    required String studentId,
    required String studentName,
    required String className,
    required String scheduleId,
    required String subjectName,
    required String type,
    required String description,
    required String tahunAjaran,
    required String semester,
  }) async {
    final docId = '${studentId}_${scheduleId}';
    final now = Timestamp.now();
    final logEntry = {
      'type': type,
      'description': description,
      'timestamp': now,
    };
    await _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('behavior_records')
        .doc(docId)
        .set({
      'recordId': docId,
      'studentId': studentId,
      'studentName': studentName,
      'className': className,
      'scheduleId': scheduleId,
      'subjectName': subjectName,
      'type': type,
      'description': description,
      'timestamp': FieldValue.serverTimestamp(),
      'tahunAjaran': tahunAjaran,
      'semester': semester,
      'activityLog': FieldValue.arrayUnion([logEntry]),
    }, SetOptions(merge: true));
  }


  /// Stream behavioral violations sorted by timestamp descending
  Stream<QuerySnapshot<Map<String, dynamic>>> getBehaviorRecords(String schoolId) {
    return _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('behavior_records')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  /// Riwayat absensi murid per bulan (filter client-side, no composite index)
  Stream<List<Map<String, dynamic>>> getStudentAttendanceHistoryStream({
    required String schoolId,
    required String studentId,
    required int year,
    required int month,
  }) {
    final startDate = '${year}-${month.toString().padLeft(2, '0')}-01';
    final lastDay = DateTime(year, month + 1, 0).day;
    final endDate =
        '${year}-${month.toString().padLeft(2, '0')}-${lastDay.toString().padLeft(2, '0')}';

    return _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('attendance')
        .where('studentId', isEqualTo: studentId)
        .snapshots()
        .map((snapshot) {
          final records = snapshot.docs
              .map((doc) => {...doc.data(), 'id': doc.id})
              .where((data) {
                final date = (data['date'] ?? '').toString();
                return date.compareTo(startDate) >= 0 &&
                    date.compareTo(endDate) <= 0;
              })
              .toList();

          records.sort((a, b) {
            final dateCompare =
                (b['date'] ?? '').toString().compareTo((a['date'] ?? '').toString());
            if (dateCompare != 0) return dateCompare;

            final aTime = a['timestamp'];
            final bTime = b['timestamp'];
            if (aTime is Timestamp && bTime is Timestamp) {
              return bTime.compareTo(aTime);
            }
            return 0;
          });

          return records;
        });
  }

  /// Stream of today's attendance records for the school
  Stream<QuerySnapshot<Map<String, dynamic>>> getTodayAttendanceListStream({
    required String schoolId,
    required String dateStr,
  }) {
    return _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('attendance')
        .where('date', isEqualTo: dateStr)
        .snapshots();
  }

  /// Delete a single behavioral violation record
  Future<void> deleteBehaviorRecord(String schoolId, String recordId) async {
    await _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('behavior_records')
        .doc(recordId)
        .delete();
  }

  /// Delete all behavioral violation records for the school
  Future<void> clearAllBehaviorRecords(String schoolId) async {
    final snapshot = await _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('behavior_records')
        .get();
    
    final batch = _firestore.batch();
    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  /// Tambahkan catatan pelanggaran baru untuk murid
  Future<void> addStudentViolation({
    required String schoolId,
    required String studentId,
    required String studentName,
    required String className,
    required String jenis,
    required int poin,
    required String keterangan,
    required DateTime date,
    required String recordedBy,
    XFile? imageFile,
  }) async {
    String? imageUrl;

    if (imageFile != null) {
      try {
        final fileName = 'violation_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('schools')
            .child(schoolId)
            .child('violations')
            .child(studentId)
            .child(fileName);

        final bytes = await imageFile.readAsBytes();
        final uploadTask = storageRef.putData(
          bytes,
          SettableMetadata(contentType: 'image/jpeg'),
        );
        final snapshot = await uploadTask;
        imageUrl = await snapshot.ref.getDownloadURL();
      } catch (e) {
        debugPrint('Error uploading violation image: $e');
      }
    }

    await _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('violations')
        .add({
      'studentId': studentId,
      'studentName': studentName,
      'className': className,
      'jenis': jenis,
      'poin': poin,
      'keterangan': keterangan,
      'date': Timestamp.fromDate(date),
      'recordedBy': recordedBy,
      'createdAt': FieldValue.serverTimestamp(),
      if (imageUrl != null) 'imageUrl': imageUrl,
    });
  }

  /// Mengambil seluruh data pelanggaran di sekolah (untuk Admin)
  Stream<QuerySnapshot<Map<String, dynamic>>> getViolationsBySchool(String schoolId) {
    return _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('violations')
        .orderBy('date', descending: true)
        .snapshots();
  }

  /// Menghapus satu data pelanggaran
  Future<void> deleteViolation(String schoolId, String violationId) async {
    await _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('violations')
        .doc(violationId)
        .delete();
  }
}

