class StudentModel {
  final String studentId;
  final String schoolId;
  final String uid;
  final String email;
  final String nis;
  final String nama;
  final bool aktif;
  final bool sudahRegister;
  final String? classId;

  StudentModel({
    required this.studentId,
    required this.schoolId,
    required this.uid,
    required this.email,
    required this.nis,
    required this.nama,
    required this.aktif,
    required this.sudahRegister,
    this.classId,
  });

  factory StudentModel.fromMap(String id, Map<String, dynamic> data) {
    return StudentModel(
      studentId: id,
      schoolId: data['schoolId'] ?? '',
      uid: data['uid'] ?? '',
      email: data['email'] ?? '',
      nis: data['nis'] ?? '',
      nama: data['nama'] ?? '',
      aktif: data['aktif'] ?? true,
      sudahRegister: data['sudahRegister'] ?? false,
      classId: data['classId'],
    );
  }
}
