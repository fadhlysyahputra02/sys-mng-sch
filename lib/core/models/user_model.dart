class UserModel {
  final String uid;
  final String nama;
  final String email;
  final String role;
  final String schoolId;
  final bool aktif;
  final bool isGateOfficer;
  final bool scanGuruEnabled;
  final bool scanMuridEnabled;

  UserModel({
    required this.uid,
    required this.nama,
    required this.email,
    required this.role,
    required this.schoolId,
    required this.aktif,
    this.isGateOfficer = false,
    this.scanGuruEnabled = true,
    this.scanMuridEnabled = true,
  });

  factory UserModel.fromMap(String uid, Map<String, dynamic> map) {
    String roleVal = (map['role'] ?? '').toString().trim().toLowerCase();
    if (roleVal == 'superadmin' || roleVal == 'super-admin' || roleVal == 'super_admin') {
      roleVal = 'super_admin';
    } else if (roleVal == 'schooladmin' || roleVal == 'school-admin' || roleVal == 'school_admin') {
      roleVal = 'school_admin';
    }
    final isGate = map['isGateOfficer'] ?? false;
    final isOfficer = roleVal == 'officer';
    return UserModel(
      uid: uid,
      nama: map['nama'] ?? '',
      email: map['email'] ?? '',
      role: roleVal,
      schoolId: map['schoolId'] ?? '',
      aktif: map['aktif'] ?? false,
      isGateOfficer: isGate,
      scanGuruEnabled: map['scanGuruEnabled'] ?? (isOfficer ? true : isGate),
      scanMuridEnabled: map['scanMuridEnabled'] ?? (isOfficer ? true : isGate),
    );
  }
}
