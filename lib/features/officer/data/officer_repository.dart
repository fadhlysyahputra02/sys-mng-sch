import 'package:cloud_firestore/cloud_firestore.dart';
import 'scan_log_model.dart';

class OfficerRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // 1. Catat absensi via QR Scan
  Future<void> scanAttendance({
    required String schoolId,
    required String studentId,
    required String studentName,
    required String classId,
    required String className,
    required String officerId,
  }) async {
    final now = DateTime.now();
    // Jika lewat dari 07:15, maka terlambat
    final isLate = now.hour > 7 || (now.hour == 7 && now.minute > 15);
    final status = isLate ? 'terlambat' : 'hadir';

    await _saveAttendance(
      schoolId: schoolId,
      studentId: studentId,
      studentName: studentName,
      classId: classId,
      className: className,
      officerId: officerId,
      status: status,
      method: 'qr_scan',
      timeScanned: now,
    );
  }

  // 2. Catat absensi Manual
  Future<void> markManualAttendance({
    required String schoolId,
    required String studentId,
    required String studentName,
    required String classId,
    required String className,
    required String officerId,
    required String status,
  }) async {
    await _saveAttendance(
      schoolId: schoolId,
      studentId: studentId,
      studentName: studentName,
      classId: classId,
      className: className,
      officerId: officerId,
      status: status,
      method: 'manual',
      timeScanned: DateTime.now(),
    );
  }

  // Internal: Save to daily_attendance and scan_logs
  Future<void> _saveAttendance({
    required String schoolId,
    required String studentId,
    required String studentName,
    required String classId,
    required String className,
    required String officerId,
    required String status,
    required String method,
    required DateTime timeScanned,
  }) async {
    final batch = _firestore.batch();
    
    // a. Simpan ke scan_logs (Sub-collection under schools)
    final logRef = _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('scan_logs')
        .doc();
    final logModel = ScanLogModel(
      logId: logRef.id,
      studentId: studentId,
      studentName: studentName,
      classId: classId,
      className: className,
      timeScanned: timeScanned,
      status: status,
      method: method,
      officerId: officerId,
      schoolId: schoolId,
    );
    batch.set(logRef, logModel.toMap());

    // b. Simpan ke daily_attendance
    // Format docId: date_studentId supaya mudah di query & mencegah duplicate entry
    final dateStr = '${timeScanned.year}-${timeScanned.month.toString().padLeft(2, '0')}-${timeScanned.day.toString().padLeft(2, '0')}';
    final dailyRef = _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('daily_attendance')
        .doc('${dateStr}_$studentId');
        
    batch.set(dailyRef, {
      'studentId': studentId,
      'studentName': studentName,
      'classId': classId,
      'className': className,
      'date': dateStr,
      'timestamp': Timestamp.fromDate(timeScanned),
      'status': status,
      'method': method,
      'officerId': officerId,
    }, SetOptions(merge: true));

    await batch.commit();
  }

  // 3. Ambil log hari ini
  Stream<List<ScanLogModel>> getTodayScanLogs(String schoolId) {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);

    return _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('scan_logs')
        .where('timeScanned', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('timeScanned', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
        .orderBy('timeScanned', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => ScanLogModel.fromFirestore(doc)).toList();
    });
  }

  // 4. Ambil rekap harian
  Future<List<Map<String, dynamic>>> getDailyRecap(String schoolId, DateTime date) async {
    final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    
    final query = await _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('daily_attendance')
        .where('date', isEqualTo: dateStr)
        .get();
        
    return query.docs.map((doc) => doc.data()).toList();
  }

  // 5. Cek apakah sudah absen hari ini
  Future<bool> hasStudentScannedToday(String schoolId, String studentId) async {
    final now = DateTime.now();
    final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    
    final docRef = _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('daily_attendance')
        .doc('${dateStr}_$studentId');
        
    final doc = await docRef.get();
    return doc.exists;
  }
}
