import 'package:cloud_firestore/cloud_firestore.dart';

class ClassModel {
  final String id;
  final String schoolId;
  final String namaKelas;
  final String? waliKelasId;
  final bool aktif;
  final Timestamp? createdAt;

  ClassModel({
    required this.id,
    required this.schoolId,
    required this.namaKelas,
    this.waliKelasId,
    required this.aktif,
    this.createdAt,
  });

  factory ClassModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;

    return ClassModel(
      id: doc.id,
      schoolId: data['schoolId'] ?? '',
      namaKelas: data['namaKelas'] ?? '',
      waliKelasId: data['waliKelasId'],
      aktif: data['aktif'] ?? true,
      createdAt: data['createdAt'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'schoolId': schoolId,
      'namaKelas': namaKelas,
      'waliKelasId': waliKelasId,
      'aktif': aktif,
      'createdAt': createdAt,
    };
  }
}
