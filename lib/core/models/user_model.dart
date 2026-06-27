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
    String roleVal = (map['role'] ?? '').toString().trim().toLowerCase();
    if (roleVal == 'superadmin' || roleVal == 'super-admin' || roleVal == 'super_admin') {
      roleVal = 'super_admin';
    } else if (roleVal == 'schooladmin' || roleVal == 'school-admin' || roleVal == 'school_admin') {
      roleVal = 'school_admin';
    }
    return UserModel(
      uid: uid,
      nama: map['nama'] ?? '',
      email: map['email'] ?? '',
      role: roleVal,
      schoolId: map['schoolId'] ?? '',
      aktif: map['aktif'] ?? false,
    );
  }
}
