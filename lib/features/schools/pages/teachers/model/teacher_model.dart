class TeacherModel {
  final String teacherId;
  final String schoolId;
  final String uid;
  final String email;
  final String nip;
  final String nama;
  final bool aktif;
  final bool sudahRegister;

  TeacherModel({
    required this.teacherId,
    required this.schoolId,
    required this.uid,
    required this.email,
    required this.nip,
    required this.nama,
    required this.aktif,
    required this.sudahRegister,
  });

  factory TeacherModel.fromMap(Map<String, dynamic> map) {
    return TeacherModel(
      teacherId: map['teacherId'] ?? '',
      schoolId: map['schoolId'] ?? '',
      uid: map['uid'] ?? '',
      email: map['email'] ?? '',
      nip: map['nip'] ?? '',
      nama: map['nama'] ?? '',
      aktif: map['aktif'] ?? true,
      sudahRegister: map['sudahRegister'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'teacherId': teacherId,
      'schoolId': schoolId,
      'uid': uid,
      'email': email,
      'nip': nip,
      'nama': nama,
      'aktif': aktif,
      'sudahRegister': sudahRegister,
    };
  }
}
