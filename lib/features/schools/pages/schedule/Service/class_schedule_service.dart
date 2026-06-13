import 'package:cloud_firestore/cloud_firestore.dart';

class ClassScheduleService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

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

  // Hapus jadwal
  Future<void> deleteSchedule({
    required String schoolId,
    required String scheduleId,
  }) async {
    await _schedulesRef(schoolId).doc(scheduleId).delete();
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
  }) async {
    final newStart = _timeToMinutes(jamMulai);
    final newEnd = _timeToMinutes(jamSelesai);

    final existingSchedules = await _schedulesRef(schoolId).get();

    for (final doc in existingSchedules.docs) {
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
        throw Exception('jadwal bentrok');
      }

      if (data['teacherId'] == teacherId) {
        throw Exception(
          'Guru sudah mengajar di kelas lain pada hari dan jam yang sama',
        );
      }
    }

    final doc = _schedulesRef(schoolId).doc();

    await doc.set({
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
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
