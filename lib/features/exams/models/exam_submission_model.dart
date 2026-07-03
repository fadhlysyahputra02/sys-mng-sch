import 'package:cloud_firestore/cloud_firestore.dart';

class ExamSubmission {
  final String id;
  final String examId;
  final String studentId;
  final String studentName;
  final Map<String, int> answers;
  final Map<String, String> essayAnswers;
  final Map<String, int> essayScores;
  final int correctCount;
  final int incorrectCount;
  final double score;
  final bool isGraded;
  final DateTime submittedAt;
  final String tahunAjaran;
  final String semester;

  ExamSubmission({
    required this.id,
    required this.examId,
    required this.studentId,
    required this.studentName,
    required this.answers,
    required this.essayAnswers,
    required this.essayScores,
    required this.correctCount,
    required this.incorrectCount,
    required this.score,
    this.isGraded = true,
    required this.submittedAt,
    required this.tahunAjaran,
    required this.semester,
  });

  factory ExamSubmission.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final rawAnswers = data['answers'] as Map? ?? {};
    final answersMap = rawAnswers.map((key, val) => MapEntry(key.toString(), (val as num? ?? 0).toInt()));

    final rawEssayAnswers = data['essayAnswers'] as Map? ?? {};
    final essayAnswersMap = rawEssayAnswers.map((key, val) => MapEntry(key.toString(), val.toString()));

    final rawEssayScores = data['essayScores'] as Map? ?? {};
    final essayScoresMap = rawEssayScores.map((key, val) => MapEntry(key.toString(), (val as num? ?? 0).toInt()));

    return ExamSubmission(
      id: doc.id,
      examId: data['examId'] ?? '',
      studentId: data['studentId'] ?? '',
      studentName: data['studentName'] ?? '',
      answers: answersMap,
      essayAnswers: essayAnswersMap,
      essayScores: essayScoresMap,
      correctCount: data['correctCount'] ?? 0,
      incorrectCount: data['incorrectCount'] ?? 0,
      score: (data['score'] as num? ?? 0.0).toDouble(),
      isGraded: data['isGraded'] as bool? ?? true,
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
      'essayAnswers': essayAnswers,
      'essayScores': essayScores,
      'correctCount': correctCount,
      'incorrectCount': incorrectCount,
      'score': score,
      'isGraded': isGraded,
      'submittedAt': Timestamp.fromDate(submittedAt),
      'tahunAjaran': tahunAjaran,
      'semester': semester,
    };
  }
}
