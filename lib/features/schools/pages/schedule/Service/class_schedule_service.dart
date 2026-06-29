import 'package:cloud_firestore/cloud_firestore.dart';

class ClassScheduleService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> _checkIfSemesterIsActive(String schoolId) async {
    final schoolDoc = await _db.collection('schools').doc(schoolId).get();
    if (!schoolDoc.exists) return;

    final schoolData = schoolDoc.data() ?? {};
    final bool allowBypass = schoolData['allowBypassScheduleLock'] ?? false;
    if (allowBypass) return; // Bypass locks if enabled by Super Admin

    final String tahunAjaran = schoolData['tahunAjaran'] ?? '';
    final String semester = schoolData['semester'] ?? '';

    if (tahunAjaran.isEmpty || semester.isEmpty) return;

    // 1. Cek absensi murid
    final studentAttendanceQuery = await _db
        .collection('schools')
        .doc(schoolId)
        .collection('attendance')
        .where('tahunAjaran', isEqualTo: tahunAjaran)
        .where('semester', isEqualTo: semester)
        .limit(1)
        .get();

    if (studentAttendanceQuery.docs.isNotEmpty) {
      throw 'Jadwal tidak dapat diubah/dihapus karena semester sedang berjalan (sudah ada absensi murid).';
    }

    // 2. Cek absensi guru
    final teacherAttendanceQuery = await _db
        .collection('schools')
        .doc(schoolId)
        .collection('teacher_daily_attendance')
        .where('tahunAjaran', isEqualTo: tahunAjaran)
        .where('semester', isEqualTo: semester)
        .limit(1)
        .get();

    if (teacherAttendanceQuery.docs.isNotEmpty) {
      throw 'Jadwal tidak dapat diubah/dihapus karena semester sedang berjalan (sudah ada absensi guru).';
    }
  }

  CollectionReference<Map<String, dynamic>> _schedulesRef(String schoolId) =>
      _db.collection('schools').doc(schoolId).collection('class_schedules');

  int _timeToMinutes(String value) {
    final parts = value.split(':');

    if (parts.length != 2) {
      return 0;
    }

    final hours = int.tryParse(parts[0]) ?? 0;
    final minutes = int.tryParse(parts[1]) ?? 0;

    return (hours * 60) + minutes;
  }

  bool _isOverlapping({
    required int startA,
    required int endA,
    required int startB,
    required int endB,
  }) {
    return startA < endB && endA > startB;
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> getSchedulesByClass(
    String schoolId,
    String classId,
  ) {
    return _schedulesRef(schoolId)
        .where('classId', isEqualTo: classId)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> getSchedulesByClassName(
    String schoolId,
    String className,
  ) {
    return _schedulesRef(schoolId)
        .where('className', isEqualTo: className)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> getSchedulesBySchool(
    String schoolId,
  ) {
    return _schedulesRef(schoolId).snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> getSchedulesByTeacher(
    String schoolId,
    String teacherId,
  ) {
    return _schedulesRef(schoolId)
        .where('teacherId', isEqualTo: teacherId)
        .snapshots();
  }

  // Hapus jadwal beserta relasinya (Absensi & Catatan Sikap)
  Future<void> deleteSchedule({
    required String schoolId,
    required String scheduleId,
  }) async {
    await _checkIfSemesterIsActive(schoolId);
    final batch = _db.batch();

    // 1. Cari dan hapus semua absensi yang terikat dengan jadwal ini
    final attendanceSnapshot = await _db
        .collection('schools')
        .doc(schoolId)
        .collection('attendance')
        .where('scheduleId', isEqualTo: scheduleId)
        .get();
        
    for (final doc in attendanceSnapshot.docs) {
      batch.delete(doc.reference);
    }

    // 2. Cari dan hapus semua catatan sikap (behavior records) yang terikat
    final behaviorSnapshot = await _db
        .collection('schools')
        .doc(schoolId)
        .collection('behavior_records')
        .where('scheduleId', isEqualTo: scheduleId)
        .get();
        
    for (final doc in behaviorSnapshot.docs) {
      batch.delete(doc.reference);
    }

    // 3. Hapus jadwal utamanya
    batch.delete(_schedulesRef(schoolId).doc(scheduleId));

    // Eksekusi semua proses hapus secara bersamaan
    await batch.commit();
  }

  // Tambahkan jadwal baru
  Future<void> addSchedule({
    required String schoolId,
    required String classId,
    required String className,
    required String jenisJadwal,
    required String subjectId,
    required String subjectName,
    required String teacherId,
    required String teacherName,
    required String hari,
    required String jamMulai,
    required String jamSelesai,
    String? scheduleId, // Optional parameter for editing
  }) async {
    await _checkIfSemesterIsActive(schoolId);
    final newStart = _timeToMinutes(jamMulai);
    final newEnd = _timeToMinutes(jamSelesai);

    final existingSchedules = await _schedulesRef(schoolId).get();

    for (final doc in existingSchedules.docs) {
      if (scheduleId != null && doc.id == scheduleId) {
        continue; // Lewati pengecekan bentrok dengan diri sendiri
      }

      final data = doc.data();

      if ((data['hari'] ?? '') != hari) {
        continue;
      }

      final existingStart = _timeToMinutes((data['jamMulai'] ?? '').toString());
      final existingEnd = _timeToMinutes((data['jamSelesai'] ?? '').toString());
      final isOverlapping = _isOverlapping(
        startA: newStart,
        endA: newEnd,
        startB: existingStart,
        endB: existingEnd,
      );

      if (!isOverlapping) {
        continue;
      }

      if (data['classId'] == classId) {
        throw ('jadwal bentrok');
      }

      // Bypass pengecekan konflik guru jika jenis jadwal adalah istirahat
      // atau jika ID guru tidak valid/kosong
      if (jenisJadwal != 'istirahat' &&
          data['jenisJadwal'] != 'istirahat' &&
          teacherId.isNotEmpty &&
          teacherId != '-' &&
          data['teacherId'] != null &&
          data['teacherId'].toString().isNotEmpty &&
          data['teacherId'].toString() != '-' &&
          data['teacherId'] == teacherId) {
        throw (
          'Guru sudah mengajar di kelas lain pada hari dan jam yang sama',
        );
      }

    }

    final doc = scheduleId != null 
        ? _schedulesRef(schoolId).doc(scheduleId) 
        : _schedulesRef(schoolId).doc();

    final dataToSave = {
      'scheduleId': doc.id,

      'schoolId': schoolId,

      'classId': classId,
      'className': className,

      'jenisJadwal': jenisJadwal,

      'subjectId': subjectId,
      'subjectName': jenisJadwal == 'istirahat' ? 'Jam Istirahat' : subjectName,

      'teacherId': teacherId,
      'teacherName': jenisJadwal == 'istirahat' ? '-' : teacherName,

      'hari': hari,
      'jamMulai': jamMulai,
      'jamSelesai': jamSelesai,

      'aktif': true,
      'createdAt': scheduleId != null ? FieldValue.serverTimestamp() : FieldValue.serverTimestamp(),
    };

    if (scheduleId != null) {
      dataToSave.remove('createdAt');
      dataToSave['updatedAt'] = FieldValue.serverTimestamp();
      await doc.update(dataToSave);
    } else {
      await doc.set(dataToSave);
    }
  }

  // Hapus semua jadwal lama dan masukkan yang baru (Batch Write)
  Future<void> replaceAllSchedulesBySchool({
    required String schoolId,
    required List<Map<String, dynamic>> schedules,
  }) async {
    await _checkIfSemesterIsActive(schoolId);
    final existingSchedules = await _schedulesRef(schoolId).get();
    
    WriteBatch batch = _db.batch();
    int opsCount = 0;

    // Delete existing
    for (final doc in existingSchedules.docs) {
      batch.delete(doc.reference);
      opsCount++;
      if (opsCount >= 400) {
        await batch.commit();
        batch = _db.batch();
        opsCount = 0;
      }
    }

    // Add new
    for (final schedule in schedules) {
      final doc = _schedulesRef(schoolId).doc();
      batch.set(doc, {
        'scheduleId': doc.id,
        'schoolId': schoolId,
        'classId': schedule['classId'],
        'className': schedule['className'],
        'jenisJadwal': schedule['jenisJadwal'] ?? 'pelajaran',
        'subjectId': schedule['subjectId'],
        'subjectName': schedule['subjectName'],
        'teacherId': schedule['teacherId'],
        'teacherName': schedule['teacherName'],
        'hari': schedule['hari'],
        'jamMulai': schedule['jamMulai'],
        'jamSelesai': schedule['jamSelesai'],
        'aktif': true,
        'createdAt': FieldValue.serverTimestamp(),
      });
      opsCount++;
      if (opsCount >= 400) {
        await batch.commit();
        batch = _db.batch();
        opsCount = 0;
      }
    }

    if (opsCount > 0) {
      await batch.commit();
    }
  }

  Future<void> deleteAllSchedules(String schoolId) async {
    await _checkIfSemesterIsActive(schoolId);
    final existingSchedules = await _schedulesRef(schoolId).get();
    WriteBatch batch = _db.batch();
    int opsCount = 0;
    for (final doc in existingSchedules.docs) {
      batch.delete(doc.reference);
      opsCount++;
      if (opsCount >= 400) {
        await batch.commit();
        batch = _db.batch();
        opsCount = 0;
      }
    }
    if (opsCount > 0) await batch.commit();
  }

  Future<void> deleteSchedulesByClass(String schoolId, String classId) async {
    await _checkIfSemesterIsActive(schoolId);
    final existingSchedules = await _schedulesRef(schoolId).where('classId', isEqualTo: classId).get();
    WriteBatch batch = _db.batch();
    int opsCount = 0;
    for (final doc in existingSchedules.docs) {
      batch.delete(doc.reference);
      opsCount++;
      if (opsCount >= 400) {
        await batch.commit();
        batch = _db.batch();
        opsCount = 0;
      }
    }
    if (opsCount > 0) await batch.commit();
  }

  Future<void> deleteSchedulesByClassAndDay(String schoolId, String classId, String hari) async {
    await _checkIfSemesterIsActive(schoolId);
    final existingSchedules = await _schedulesRef(schoolId)
        .where('classId', isEqualTo: classId)
        .where('hari', isEqualTo: hari)
        .get();
    WriteBatch batch = _db.batch();
    int opsCount = 0;
    for (final doc in existingSchedules.docs) {
      batch.delete(doc.reference);
      opsCount++;
      if (opsCount >= 400) {
        await batch.commit();
        batch = _db.batch();
        opsCount = 0;
      }
    }
    if (opsCount > 0) await batch.commit();
  }
}
