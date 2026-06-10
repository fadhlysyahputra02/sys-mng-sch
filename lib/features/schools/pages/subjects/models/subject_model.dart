class SubjectModel {
  final String subjectId;
  final String schoolId;
  final String kodeMapel;
  final String namaMapel;
  final String kategori;
  final bool aktif;

  SubjectModel({
    required this.subjectId,
    required this.schoolId,
    required this.kodeMapel,
    required this.namaMapel,
    required this.kategori,
    required this.aktif,
  });

  factory SubjectModel.fromMap(Map<String, dynamic> map) {
    return SubjectModel(
      subjectId: map['subjectId'] ?? '',
      schoolId: map['schoolId'] ?? '',
      kodeMapel: map['kodeMapel'] ?? '',
      namaMapel: map['namaMapel'] ?? '',
      kategori: map['kategori'] ?? '',
      aktif: map['aktif'] ?? true,
    );
  }
}
