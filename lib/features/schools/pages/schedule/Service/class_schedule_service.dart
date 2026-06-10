import 'package:cloud_firestore/cloud_firestore.dart';

class ClassScheduleService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

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
    String classId,
  ) {
    return _db
        .collection('class_schedules')
        .where('classId', isEqualTo: classId)
        .snapshots();
  }

  // Hapus jadwal
  Future<void> deleteSchedule(String scheduleId) async {
    await _db.collection('class_schedules').doc(scheduleId).delete();
  }

  // Tambahkan jadwal baru
  Future<void> addSchedule({
    required String schoolId,
    required String classId,
    required String className,
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

    final existingSchedules = await _db
        .collection('class_schedules')
        .where('classId', isEqualTo: classId)
        .get();

    for (final doc in existingSchedules.docs) {
      final data = doc.data();

      if ((data['hari'] ?? '') != hari) {
        continue;
      }

      final existingStart = _timeToMinutes((data['jamMulai'] ?? '').toString());
      final existingEnd = _timeToMinutes((data['jamSelesai'] ?? '').toString());

      if (_isOverlapping(
        startA: newStart,
        endA: newEnd,
        startB: existingStart,
        endB: existingEnd,
      )) {
        throw Exception('jadwal bentrok');
      }
    }

    final doc = _db.collection('class_schedules').doc();

    await doc.set({
      'scheduleId': doc.id,

      'schoolId': schoolId,

      'classId': classId,
      'className': className,

      'subjectId': subjectId,
      'subjectName': subjectName,

      'teacherId': teacherId,
      'teacherName': teacherName,

      'hari': hari,
      'jamMulai': jamMulai,
      'jamSelesai': jamSelesai,

      'aktif': true,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
