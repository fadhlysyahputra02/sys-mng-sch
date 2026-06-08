class UserModel {
  final String uid;
  final String nama;
  final String email;
  final String role;
  final String schoolId;
  final bool aktif;

  UserModel({
    required this.uid,
    required this.nama,
    required this.email,
    required this.role,
    required this.schoolId,
    required this.aktif,
  });

  factory UserModel.fromMap(String uid, Map<String, dynamic> map) {
    return UserModel(
      uid: uid,
      nama: map['nama'] ?? '',
      email: map['email'] ?? '',
      role: map['role'] ?? '',
      schoolId: map['schoolId'] ?? '',
      aktif: map['aktif'] ?? false,
    );
  }
}
