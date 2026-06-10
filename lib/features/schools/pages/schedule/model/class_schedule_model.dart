class ClassScheduleModel {
  final String scheduleId;
  final String schoolId;

  final String classId;
  final String className;

  final String subjectId;
  final String subjectName;

  final String teacherId;
  final String teacherName;

  final String hari;
  final String jamMulai;
  final String jamSelesai;

  final bool aktif;

  ClassScheduleModel({
    required this.scheduleId,
    required this.schoolId,
    required this.classId,
    required this.className,
    required this.subjectId,
    required this.subjectName,
    required this.teacherId,
    required this.teacherName,
    required this.hari,
    required this.jamMulai,
    required this.jamSelesai,
    required this.aktif,
  });

  factory ClassScheduleModel.fromMap(String id, Map<String, dynamic> map) {
    return ClassScheduleModel(
      scheduleId: id,
      schoolId: map['schoolId'] ?? '',
      classId: map['classId'] ?? '',
      className: map['className'] ?? '',
      subjectId: map['subjectId'] ?? '',
      subjectName: map['subjectName'] ?? '',
      teacherId: map['teacherId'] ?? '',
      teacherName: map['teacherName'] ?? '',
      hari: map['hari'] ?? '',
      jamMulai: map['jamMulai'] ?? '',
      jamSelesai: map['jamSelesai'] ?? '',
      aktif: map['aktif'] ?? true,
    );
  }
}
