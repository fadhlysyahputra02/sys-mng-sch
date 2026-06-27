import 'package:cloud_firestore/cloud_firestore.dart';

class ExamSubmission {
  final String id;
  final String examId;
  final String studentId;
  final String studentName;
  final Map<String, int> answers;
  final int correctCount;
  final int incorrectCount;
  final double score;
  final DateTime submittedAt;
  final String tahunAjaran;
  final String semester;

  ExamSubmission({
    required this.id,
    required this.examId,
    required this.studentId,
    required this.studentName,
    required this.answers,
    required this.correctCount,
    required this.incorrectCount,
    required this.score,
    required this.submittedAt,
    required this.tahunAjaran,
    required this.semester,
  });

  factory ExamSubmission.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final rawAnswers = data['answers'] as Map? ?? {};
    final answersMap = rawAnswers.map((key, val) => MapEntry(key.toString(), val as int));

    return ExamSubmission(
      id: doc.id,
      examId: data['examId'] ?? '',
      studentId: data['studentId'] ?? '',
      studentName: data['studentName'] ?? '',
      answers: answersMap,
      correctCount: data['correctCount'] ?? 0,
      incorrectCount: data['incorrectCount'] ?? 0,
      score: (data['score'] ?? 0.0) as double,
      submittedAt: (data['submittedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      tahunAjaran: data['tahunAjaran'] ?? '',
      semester: data['semester'] ?? '',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'examId': examId,
      'studentId': studentId,
      'studentName': studentName,
      'answers': answers,
      'correctCount': correctCount,
      'incorrectCount': incorrectCount,
      'score': score,
      'submittedAt': Timestamp.fromDate(submittedAt),
      'tahunAjaran': tahunAjaran,
      'semester': semester,
    };
  }
}
