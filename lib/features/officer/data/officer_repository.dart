import 'package:cloud_firestore/cloud_firestore.dart';
import 'scan_log_model.dart';
import '../../../core/services/semester_state_service.dart';


class OfficerRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // 1. Catat absensi Masuk via QR Scan
  Future<bool> scanAttendance({
    required String schoolId,
    required String studentId,
    required String studentName,
    required String classId,
    required String className,
    required String officerId,
  }) async {
    final now = DateTime.now();
    final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    
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

        // ── Validasi status semester ──
        final data = schoolDoc.data()!;
        final semesterDitutup = (data['semesterDitutup'] as bool?) ?? false;
        final tanggalMulaiTs = data['tanggalMulaiSemester'];
        final tanggalMulai = tanggalMulaiTs is Timestamp ? tanggalMulaiTs.toDate() : null;

        if (semesterDitutup) {
          throw SemesterValidationException('Semester telah ditutup oleh Admin 🔒. Input absensi tidak dapat dilakukan.');
        }
        if (tanggalMulai != null) {
          final now2 = DateTime.now();
          final today = DateTime(now2.year, now2.month, now2.day);
          final start = DateTime(tanggalMulai.year, tanggalMulai.month, tanggalMulai.day);
          if (today.isBefore(start)) {
            final d = start.day.toString().padLeft(2, '0');
            final m = start.month.toString().padLeft(2, '0');
            final y = start.year;
            throw SemesterValidationException('Masa liburan sekolah sedang berlangsung 🏖️. Input absensi baru tersedia mulai $d/$m/$y.');
          }
        }
      }
    } catch (e) {
      if (e is Exception) rethrow;
    }

    // Cek apakah sudah check-in hari ini
    final dailyRef = _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('daily_attendance')
        .doc('${dateStr}_$studentId');
    final existing = await dailyRef.get();
    if (existing.exists && existing.data()?['checkInTime'] != null) {
      throw Exception('$studentName sudah melakukan absen masuk hari ini.');
    }

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

  // 1b. Catat absensi Pulang via QR Scan
  Future<void> scanStudentCheckOut({
    required String schoolId,
    required String studentId,
    required String studentName,
    required String officerId,
  }) async {
    final now = DateTime.now();
    final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    // Validasi semester
    try {
      final schoolDoc = await _firestore.collection('schools').doc(schoolId).get();
      if (schoolDoc.exists) {
        final data = schoolDoc.data()!;
        final semesterDitutup = (data['semesterDitutup'] as bool?) ?? false;
        if (semesterDitutup) {
          throw SemesterValidationException('Semester telah ditutup oleh Admin 🔒. Input absensi tidak dapat dilakukan.');
        }
      }
    } catch (e) {
      if (e is Exception) rethrow;
    }

    final dailyRef = _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('daily_attendance')
        .doc('${dateStr}_$studentId');
    final doc = await dailyRef.get();

    if (!doc.exists || doc.data()?['checkInTime'] == null) {
      throw Exception('$studentName belum melakukan absen masuk hari ini.');
    }
    if (doc.data()?['checkOutTime'] != null) {
      throw Exception('$studentName sudah melakukan absen masuk dan pulang hari ini.');
    }

    await dailyRef.update({
      'checkOutTime': Timestamp.fromDate(now),
      'checkOutMethod': 'qr_scan',
      'checkOutOfficerId': officerId,
    });
  }

  // 2. Catat absensi Manual Masuk Siswa
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

        // ── Validasi status semester ──
        final data = schoolDoc.data()!;
        final semesterDitutup = (data['semesterDitutup'] as bool?) ?? false;
        final tanggalMulaiTs = data['tanggalMulaiSemester'];
        final tanggalMulai = tanggalMulaiTs is Timestamp ? tanggalMulaiTs.toDate() : null;

        if (semesterDitutup) {
          throw SemesterValidationException('Semester telah ditutup oleh Admin 🔒. Input absensi tidak dapat dilakukan.');
        }
        if (tanggalMulai != null) {
          final now = DateTime.now();
          final today = DateTime(now.year, now.month, now.day);
          final start = DateTime(tanggalMulai.year, tanggalMulai.month, tanggalMulai.day);
          if (today.isBefore(start)) {
            final d = start.day.toString().padLeft(2, '0');
            final m = start.month.toString().padLeft(2, '0');
            final y = start.year;
            throw SemesterValidationException('Masa liburan sekolah sedang berlangsung 🏖️. Input absensi baru tersedia mulai $d/$m/$y.');
          }
        }
      }
    } catch (e) {
      if (e is Exception) rethrow;
    }

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

  // 2b. Catat absensi Manual Pulang Siswa
  Future<void> markManualCheckOut({
    required String schoolId,
    required String studentId,
    required String studentName,
    required String officerId,
  }) async {
    final now = DateTime.now();
    final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    // Validasi semester
    try {
      final schoolDoc = await _firestore.collection('schools').doc(schoolId).get();
      if (schoolDoc.exists) {
        final data = schoolDoc.data()!;
        final semesterDitutup = (data['semesterDitutup'] as bool?) ?? false;
        if (semesterDitutup) {
          throw SemesterValidationException('Semester telah ditutup oleh Admin 🔒. Input absensi tidak dapat dilakukan.');
        }
      }
    } catch (e) {
      if (e is Exception) rethrow;
    }

    final dailyRef = _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('daily_attendance')
        .doc('${dateStr}_$studentId');
    final doc = await dailyRef.get();

    if (!doc.exists || doc.data()?['checkInTime'] == null) {
      throw Exception('$studentName belum melakukan absen masuk hari ini.');
    }
    if (doc.data()?['checkOutTime'] != null) {
      throw Exception('$studentName sudah melakukan absen pulang hari ini.');
    }

    await dailyRef.update({
      'checkOutTime': Timestamp.fromDate(now),
      'checkOutMethod': 'manual',
      'checkOutOfficerId': officerId,
    });
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
      'checkInTime': Timestamp.fromDate(timeScanned),
      'checkOutTime': null,
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

  // 5a. Cek apakah sudah absen masuk hari ini
  Future<bool> hasStudentCheckedInToday(String schoolId, String studentId) async {
    final now = DateTime.now();
    final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    
    final docRef = _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('daily_attendance')
        .doc('${dateStr}_$studentId');
    final doc = await docRef.get();
    return doc.exists && doc.data()?['checkInTime'] != null;
  }

  // 5b. Cek apakah sudah absen pulang hari ini
  Future<bool> hasStudentCheckedOutToday(String schoolId, String studentId) async {
    final now = DateTime.now();
    final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    
    final docRef = _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('daily_attendance')
        .doc('${dateStr}_$studentId');
    final doc = await docRef.get();
    return doc.exists && doc.data()?['checkOutTime'] != null;
  }

  // 5c. Ambil data absensi siswa hari ini (full document)
  Future<Map<String, dynamic>?> getStudentTodayAttendance(String schoolId, String studentId) async {
    final now = DateTime.now();
    final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    
    final docRef = _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('daily_attendance')
        .doc('${dateStr}_$studentId');
    final doc = await docRef.get();
    return doc.exists ? doc.data() : null;
  }

  // 5d. Legacy alias — cek sudah absen masuk (digunakan di bagian lama)
  Future<bool> hasStudentScannedToday(String schoolId, String studentId) =>
      hasStudentCheckedInToday(schoolId, studentId);

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

  // 7. Ambil status absensi guru hari ini (Berdasarkan field 'date')
  Future<Map<String, dynamic>?> getTeacherTodayAttendance(String schoolId, String teacherId) async {
    final now = DateTime.now();
    final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    
    final query = await _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('teacher_daily_attendance')
        .where('teacherId', isEqualTo: teacherId)
        .where('date', isEqualTo: dateStr)
        .limit(1)
        .get();
        
    return query.docs.isNotEmpty ? query.docs.first.data() : null;
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
