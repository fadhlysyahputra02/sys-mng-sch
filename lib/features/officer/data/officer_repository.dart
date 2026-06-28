import 'package:cloud_firestore/cloud_firestore.dart';
import 'scan_log_model.dart';

class OfficerRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // 1. Catat absensi via QR Scan
  Future<bool> scanAttendance({
    required String schoolId,
    required String studentId,
    required String studentName,
    required String classId,
    required String className,
    required String officerId,
  }) async {
    final now = DateTime.now();
    
    // Ambil jamMasuk dari database sekolah
    String jamMasukLimit = '07:15';
    String tahunAjaran = '${DateTime.now().year}/${DateTime.now().year + 1}';
    String semester = 'Semester 1';
    try {
      final schoolDoc = await _firestore.collection('schools').doc(schoolId).get();
      if (schoolDoc.exists) {
        jamMasukLimit = schoolDoc.data()?['jamMasuk'] ?? '07:15';
        tahunAjaran = schoolDoc.data()?['tahunAjaran'] ?? tahunAjaran;
        semester = schoolDoc.data()?['semester'] ?? semester;
      }
    } catch (_) {}

    // Hitung apakah terlambat berdasarkan jamMasukLimit
    bool isLate = false;
    try {
      final parts = jamMasukLimit.split(':');
      if (parts.length == 2) {
        final limitHour = int.parse(parts[0]);
        final limitMinute = int.parse(parts[1]);
        
        final currentMinutes = now.hour * 60 + now.minute;
        final limitMinutes = limitHour * 60 + limitMinute;
        
        isLate = currentMinutes > limitMinutes;
      } else {
        isLate = now.hour > 7 || (now.hour == 7 && now.minute > 15);
      }
    } catch (_) {
      isLate = now.hour > 7 || (now.hour == 7 && now.minute > 15);
    }

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
      tahunAjaran: tahunAjaran,
      semester: semester,
    );
    
    return isLate;
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
    String tahunAjaran = '${DateTime.now().year}/${DateTime.now().year + 1}';
    String semester = 'Semester 1';
    try {
      final schoolDoc = await _firestore.collection('schools').doc(schoolId).get();
      if (schoolDoc.exists) {
        tahunAjaran = schoolDoc.data()?['tahunAjaran'] ?? tahunAjaran;
        semester = schoolDoc.data()?['semester'] ?? semester;
      }
    } catch (_) {}

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
      tahunAjaran: tahunAjaran,
      semester: semester,
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
    required String tahunAjaran,
    required String semester,
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
    final logData = logModel.toMap();
    logData['tahunAjaran'] = tahunAjaran;
    logData['semester'] = semester;
    logData['expireAt'] = Timestamp.fromDate(
      DateTime.now().add(const Duration(days: 365 * 5)),
    );
    batch.set(logRef, logData);

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
      'tahunAjaran': tahunAjaran,
      'semester': semester,
      'expireAt': Timestamp.fromDate(
        DateTime.now().add(const Duration(days: 365 * 5)),
      ),
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

  // 6. Catat absensi Guru via QR Scan (Harian)
  Future<Map<String, dynamic>> scanTeacherAttendance({
    required String schoolId,
    required String teacherId,
    required String teacherName,
    required String nip,
    required String officerId,
    String? forcedAction,
  }) async {
    final now = DateTime.now();
    final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    
    final docRef = _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('teacher_daily_attendance')
        .doc('${dateStr}_$teacherId');
        
    final doc = await docRef.get();
    
    String jamMasukLimit = '07:15';
    String tahunAjaran = '${DateTime.now().year}/${DateTime.now().year + 1}';
    String semester = 'Semester 1';
    try {
      final schoolDoc = await _firestore.collection('schools').doc(schoolId).get();
      if (schoolDoc.exists) {
        jamMasukLimit = schoolDoc.data()?['jamMasuk'] ?? '07:15';
        tahunAjaran = schoolDoc.data()?['tahunAjaran'] ?? tahunAjaran;
        semester = schoolDoc.data()?['semester'] ?? semester;
      }
    } catch (_) {}

    // Hitung apakah terlambat berdasarkan jamMasukLimit
    bool isLate = false;
    try {
      final parts = jamMasukLimit.split(':');
      if (parts.length == 2) {
        final limitHour = int.parse(parts[0]);
        final limitMinute = int.parse(parts[1]);
        
        final currentMinutes = now.hour * 60 + now.minute;
        final limitMinutes = limitHour * 60 + limitMinute;
        
        isLate = currentMinutes > limitMinutes;
      } else {
        isLate = now.hour > 7 || (now.hour == 7 && now.minute > 15);
      }
    } catch (_) {
      isLate = now.hour > 7 || (now.hour == 7 && now.minute > 15);
    }

    final bool isAfter1821 = now.hour > 18 || (now.hour == 18 && now.minute >= 21);
    final status = isAfter1821 ? 'alfa' : (isLate ? 'terlambat' : 'hadir');

    // Jika forcedAction adalah check_in
    if (forcedAction == 'check_in') {
      if (doc.exists) {
        throw ('$teacherName sudah melakukan absen masuk hari ini.');
      }
      final checkInTime = Timestamp.fromDate(now);
      await docRef.set({
        'teacherId': teacherId,
        'teacherName': teacherName,
        'nip': nip,
        'date': dateStr,
        'checkInTime': checkInTime,
        'checkOutTime': null,
        'status': status,
        'method': 'qr_scan',
        'officerId': officerId,
        'tahunAjaran': tahunAjaran,
        'semester': semester,
        'expireAt': Timestamp.fromDate(DateTime.now().add(const Duration(days: 365 * 3))),
      }, SetOptions(merge: true));
      
      return {
        'action': 'check_in',
        'isLate': isLate,
        'status': status,
        'time': now,
      };
    }
    
    // Jika forcedAction adalah check_out
    if (forcedAction == 'check_out') {
      if (!doc.exists) {
        throw ('$teacherName belum melakukan absen masuk hari ini.');
      }
      final data = doc.data()!;
      final checkInTime = data['checkInTime'] as Timestamp?;
      final checkOutTime = data['checkOutTime'] as Timestamp?;
      if (checkOutTime != null) {
        throw ('$teacherName sudah melakukan absen masuk dan pulang hari ini.');
      }
      final newCheckOutTime = Timestamp.fromDate(now);
      await docRef.update({
        'checkOutTime': newCheckOutTime,
      });
      
      return {
        'action': 'check_out',
        'isLate': data['status'] == 'terlambat',
        'status': data['status'] ?? 'hadir',
        'time': now,
        'checkInTime': checkInTime?.toDate(),
      };
    }

    // Fallback original auto check-in/check-out logic
    if (!doc.exists) {
      final checkInTime = Timestamp.fromDate(now);
      await docRef.set({
        'teacherId': teacherId,
        'teacherName': teacherName,
        'nip': nip,
        'date': dateStr,
        'checkInTime': checkInTime,
        'checkOutTime': null,
        'status': status,
        'method': 'qr_scan',
        'officerId': officerId,
        'tahunAjaran': tahunAjaran,
        'semester': semester,
        'expireAt': Timestamp.fromDate(DateTime.now().add(const Duration(days: 365 * 3))),
      }, SetOptions(merge: true));
      
      return {
        'action': 'check_in',
        'isLate': isLate,
        'status': status,
        'time': now,
      };
    } else {
      final data = doc.data()!;
      final checkInTime = data['checkInTime'] as Timestamp?;
      final checkOutTime = data['checkOutTime'] as Timestamp?;
      
      if (checkOutTime != null) {
        throw ('$teacherName sudah melakukan absen masuk dan pulang hari ini.');
      }
      
      final newCheckOutTime = Timestamp.fromDate(now);
      await docRef.update({
        'checkOutTime': newCheckOutTime,
      });
      
      return {
        'action': 'check_out',
        'isLate': data['status'] == 'terlambat',
        'status': data['status'] ?? 'hadir',
        'time': now,
        'checkInTime': checkInTime?.toDate(),
      };
    }
  }

  // 7. Ambil status absensi guru hari ini
  Future<Map<String, dynamic>?> getTeacherTodayAttendance(String schoolId, String teacherId) async {
    final now = DateTime.now();
    final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    
    final doc = await _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('teacher_daily_attendance')
        .doc('${dateStr}_$teacherId')
        .get();
        
    return doc.exists ? doc.data() : null;
  }

  // 8. Catat absensi Guru Manual oleh Admin
  Future<void> markTeacherAttendanceManual({
    required String schoolId,
    required String teacherId,
    required String teacherName,
    required String nip,
    required String dateStr,
    required String status, // 'hadir', 'terlambat', 'sakit', 'izin', 'alfa'
    DateTime? checkInTime,
    DateTime? checkOutTime,
  }) async {
    String tahunAjaran = '${DateTime.now().year}/${DateTime.now().year + 1}';
    String semester = 'Semester 1';
    try {
      final schoolDoc = await _firestore.collection('schools').doc(schoolId).get();
      if (schoolDoc.exists) {
        tahunAjaran = schoolDoc.data()?['tahunAjaran'] ?? tahunAjaran;
        semester = schoolDoc.data()?['semester'] ?? semester;
      }
    } catch (_) {}

    final docRef = _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('teacher_daily_attendance')
        .doc('${dateStr}_$teacherId');

    await docRef.set({
      'teacherId': teacherId,
      'teacherName': teacherName,
      'nip': nip,
      'date': dateStr,
      'checkInTime': checkInTime != null ? Timestamp.fromDate(checkInTime) : null,
      'checkOutTime': checkOutTime != null ? Timestamp.fromDate(checkOutTime) : null,
      'status': status,
      'method': 'manual',
      'officerId': 'admin',
      'tahunAjaran': tahunAjaran,
      'semester': semester,
      'expireAt': Timestamp.fromDate(DateTime.now().add(const Duration(days: 365 * 3))),
    }, SetOptions(merge: true));
  }
}
