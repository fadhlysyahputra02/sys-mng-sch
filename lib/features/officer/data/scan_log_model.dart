import 'package:cloud_firestore/cloud_firestore.dart';

class ScanLogModel {
  final String logId;
  final String studentId;
  final String studentName;
  final String classId;
  final String className;
  final DateTime timeScanned;
  final String status; // 'hadir', 'terlambat', 'alpha', 'izin', 'sakit'
  final String method; // 'qr_scan', 'manual'
  final String officerId;
  final String schoolId;

  ScanLogModel({
    required this.logId,
    required this.studentId,
    required this.studentName,
    required this.classId,
    required this.className,
    required this.timeScanned,
    required this.status,
    required this.method,
    required this.officerId,
    required this.schoolId,
  });

  factory ScanLogModel.fromFirestore(DocumentSnapshot doc) {
    final map = doc.data() as Map<String, dynamic>;
    return ScanLogModel(
      logId: doc.id,
      studentId: map['studentId'] ?? '',
      studentName: map['studentName'] ?? '',
      classId: map['classId'] ?? '',
      className: map['className'] ?? '',
      timeScanned: (map['timeScanned'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: map['status'] ?? 'hadir',
      method: map['method'] ?? 'qr_scan',
      officerId: map['officerId'] ?? '',
      schoolId: map['schoolId'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'studentId': studentId,
      'studentName': studentName,
      'classId': classId,
      'className': className,
      'timeScanned': Timestamp.fromDate(timeScanned),
      'status': status,
      'method': method,
      'officerId': officerId,
      'schoolId': schoolId,
    };
  }
}
