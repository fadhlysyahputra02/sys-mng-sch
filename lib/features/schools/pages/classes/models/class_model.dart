import 'package:cloud_firestore/cloud_firestore.dart';

class ClassModel {
  final String id;
  final String schoolId;
  final String namaKelas;
  // Field di Firestore adalah 'teacherId' (lihat class_service.dart)
  final String? teacherId;
  final String? teacherName;
  final bool aktif;
  final Timestamp? createdAt;

  // Backward compat getter
  String? get waliKelasId => teacherId;

  ClassModel({
    required this.id,
    required this.schoolId,
    required this.namaKelas,
    this.teacherId,
    this.teacherName,
    required this.aktif,
    this.createdAt,
  });

  factory ClassModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;

    return ClassModel(
      id: doc.id,
      schoolId: data['schoolId'] ?? '',
      namaKelas: data['namaKelas'] ?? '',
      teacherId: data['teacherId'],
      teacherName: data['teacherName'],
      aktif: data['aktif'] ?? true,
      createdAt: data['createdAt'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'schoolId': schoolId,
      'namaKelas': namaKelas,
      'teacherId': teacherId,
      'teacherName': teacherName,
      'aktif': aktif,
      'createdAt': createdAt,
    };
  }
}
