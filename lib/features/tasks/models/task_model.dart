import 'package:cloud_firestore/cloud_firestore.dart';

class Task {
  final String id;
  final String title;
  final String description;
  final String subjectId;
  final String subjectName;
  final String classId;
  final String className;
  final String teacherId;
  final String teacherName;
  final DateTime createdAt;
  final DateTime dueDate;
  final String? attachmentLink;
  final String status; // 'active', 'archived'
  final String tahunAjaran;
  final String semester;
  final bool syncToGrades;

  Task({
    required this.id,
    required this.title,
    required this.description,
    required this.subjectId,
    required this.subjectName,
    required this.classId,
    required this.className,
    required this.teacherId,
    required this.teacherName,
    required this.createdAt,
    required this.dueDate,
    this.attachmentLink,
    required this.status,
    required this.tahunAjaran,
    required this.semester,
    this.syncToGrades = false,
  });

  factory Task.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return Task(
      id: doc.id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      subjectId: data['subjectId'] ?? '',
      subjectName: data['subjectName'] ?? '',
      classId: data['classId'] ?? '',
      className: data['className'] ?? '',
      teacherId: data['teacherId'] ?? '',
      teacherName: data['teacherName'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      dueDate: (data['dueDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      attachmentLink: data['attachmentLink'],
      status: data['status'] ?? 'active',
      tahunAjaran: data['tahunAjaran'] ?? '',
      semester: data['semester'] ?? '',
      syncToGrades: data['syncToGrades'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'description': description,
      'subjectId': subjectId,
      'subjectName': subjectName,
      'classId': classId,
      'className': className,
      'teacherId': teacherId,
      'teacherName': teacherName,
      'createdAt': Timestamp.fromDate(createdAt),
      'dueDate': Timestamp.fromDate(dueDate),
      'attachmentLink': attachmentLink,
      'status': status,
      'tahunAjaran': tahunAjaran,
      'semester': semester,
      'syncToGrades': syncToGrades,
    };
  }
}

class TaskSubmission {
  final String id;
  final String taskId;
  final String studentId;
  final String studentName;
  final DateTime submittedAt;
  final String status; // 'submitted', 'graded', 'late'
  final String? studentNotes;
  final String? answerLink;
  final double? grade;
  final String? teacherFeedback;
  final DateTime? gradedAt;

  TaskSubmission({
    required this.id,
    required this.taskId,
    required this.studentId,
    required this.studentName,
    required this.submittedAt,
    required this.status,
    this.studentNotes,
    this.answerLink,
    this.grade,
    this.teacherFeedback,
    this.gradedAt,
  });

  factory TaskSubmission.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return TaskSubmission(
      id: doc.id,
      taskId: data['taskId'] ?? '',
      studentId: data['studentId'] ?? '',
      studentName: data['studentName'] ?? '',
      submittedAt: (data['submittedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: data['status'] ?? 'submitted',
      studentNotes: data['studentNotes'],
      answerLink: data['answerLink'],
      grade: data['grade'] != null ? (data['grade'] as num).toDouble() : null,
      teacherFeedback: data['teacherFeedback'],
      gradedAt: (data['gradedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'taskId': taskId,
      'studentId': studentId,
      'studentName': studentName,
      'submittedAt': Timestamp.fromDate(submittedAt),
      'status': status,
      'studentNotes': studentNotes,
      'answerLink': answerLink,
      'grade': grade,
      'teacherFeedback': teacherFeedback,
      'gradedAt': gradedAt != null ? Timestamp.fromDate(gradedAt!) : null,
    };
  }
}
