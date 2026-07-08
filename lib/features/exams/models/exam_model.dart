import 'package:cloud_firestore/cloud_firestore.dart';

class ExamQuestion {
  final String id;
  final String questionText;
  final List<String> options;
  final int correctOptionIndex;
  final String type; // 'multiple_choice' or 'essay'
  final int points;

  ExamQuestion({
    required this.id,
    required this.questionText,
    required this.options,
    required this.correctOptionIndex,
    this.type = 'multiple_choice',
    this.points = 10,
  });

  factory ExamQuestion.fromMap(Map<String, dynamic> map) {
    return ExamQuestion(
      id: map['id'] ?? '',
      questionText: map['questionText'] ?? '',
      options: List<String>.from(map['options'] ?? []),
      correctOptionIndex: map['correctOptionIndex'] ?? 0,
      type: map['type'] ?? 'multiple_choice',
      points: map['points'] ?? 10,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'questionText': questionText,
      'options': options,
      'correctOptionIndex': correctOptionIndex,
      'type': type,
      'points': points,
    };
  }
}
class Exam {
  final String id;
  final String title;
  final String description;
  final String classId;
  final String className;
  final String subjectId;
  final String subjectName;
  final String teacherId;
  final String teacherName;
  final List<String> teacherIds;
  final List<String> teacherNames;
  final int durationMinutes;
  final bool syncToGrades;
  final String gradeCategory;
  final String tahunAjaran;
  final String semester;
  final DateTime createdAt;
  final DateTime dueDate;
  final String status;
  final List<ExamQuestion> questions;
  final List<String> susulanStudentIds;

  Exam({
    required this.id,
    required this.title,
    required this.description,
    required this.classId,
    required this.className,
    required this.subjectId,
    required this.subjectName,
    required this.teacherId,
    required this.teacherName,
    required this.teacherIds,
    required this.teacherNames,
    required this.durationMinutes,
    this.syncToGrades = false,
    required this.gradeCategory,
    required this.tahunAjaran,
    required this.semester,
    required this.createdAt,
    required this.dueDate,
    required this.status,
    required this.questions,
    this.susulanStudentIds = const [],
  });

  factory Exam.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final questionsList = (data['questions'] as List? ?? [])
        .map((q) => ExamQuestion.fromMap(Map<String, dynamic>.from(q)))
        .toList();

    final List<String> tIds = data['teacherIds'] != null
        ? List<String>.from(data['teacherIds'])
        : (data['teacherId'] != null && data['teacherId'].toString().isNotEmpty
            ? [data['teacherId'].toString()]
            : []);

    final List<String> tNames = data['teacherNames'] != null
        ? List<String>.from(data['teacherNames'])
        : (data['teacherName'] != null && data['teacherName'].toString().isNotEmpty
            ? [data['teacherName'].toString()]
            : []);

    return Exam(
      id: doc.id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      classId: data['classId'] ?? '',
      className: data['className'] ?? '',
      subjectId: data['subjectId'] ?? '',
      subjectName: data['subjectName'] ?? '',
      teacherId: tIds.isNotEmpty ? tIds.first : (data['teacherId'] ?? ''),
      teacherName: tNames.isNotEmpty ? tNames.join(', ') : (data['teacherName'] ?? ''),
      teacherIds: tIds,
      teacherNames: tNames,
      durationMinutes: data['durationMinutes'] ?? 0,
      syncToGrades: data['syncToGrades'] as bool? ?? false,
      gradeCategory: data['gradeCategory'] ?? 'Kuis',
      tahunAjaran: data['tahunAjaran'] ?? '',
      semester: data['semester'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      dueDate: (data['dueDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: data['status'] ?? 'active',
      questions: questionsList,
      susulanStudentIds: List<String>.from(data['susulanStudentIds'] ?? []),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'description': description,
      'classId': classId,
      'className': className,
      'subjectId': subjectId,
      'subjectName': subjectName,
      'teacherId': teacherIds.isNotEmpty ? teacherIds.first : teacherId,
      'teacherName': teacherNames.isNotEmpty ? teacherNames.join(', ') : teacherName,
      'teacherIds': teacherIds,
      'teacherNames': teacherNames,
      'durationMinutes': durationMinutes,
      'syncToGrades': syncToGrades,
      'gradeCategory': gradeCategory,
      'tahunAjaran': tahunAjaran,
      'semester': semester,
      'createdAt': Timestamp.fromDate(createdAt),
      'dueDate': Timestamp.fromDate(dueDate),
      'status': status,
      'questions': questions.map((q) => q.toMap()).toList(),
      'susulanStudentIds': susulanStudentIds,
    };
  }
}
