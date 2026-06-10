import 'package:cloud_firestore/cloud_firestore.dart';

class ClassScheduleService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<QuerySnapshot<Map<String, dynamic>>> getSchedulesByClass(
    String classId,
  ) {
    return _db
        .collection('class_schedules')
        .where('classId', isEqualTo: classId)
        .snapshots();
  }

  Future<void> deleteSchedule(String scheduleId) async {
    await _db.collection('class_schedules').doc(scheduleId).delete();
  }
}
