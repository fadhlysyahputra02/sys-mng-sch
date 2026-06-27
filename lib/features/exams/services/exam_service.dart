import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/exam_model.dart';
import '../models/exam_submission_model.dart';

class ExamService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _examsRef(String schoolId) {
    return _firestore.collection('schools').doc(schoolId).collection('exams');
  }

  CollectionReference<Map<String, dynamic>> _submissionsRef(String schoolId) {
    return _firestore.collection('schools').doc(schoolId).collection('exam_submissions');
  }

  /// Membuat ujian baru
  Future<void> createExam({
    required String schoolId,
    required String title,
    required String description,
    required String classId,
    required String className,
    required String subjectId,
    required String subjectName,
    required String teacherId,
    required String teacherName,
    required int durationMinutes,
    required bool syncToGrades,
    required String gradeCategory,
    required String tahunAjaran,
    required String semester,
    required DateTime dueDate,
    required List<ExamQuestion> questions,
  }) async {
    final docRef = _examsRef(schoolId).doc();
    final exam = Exam(
      id: docRef.id,
      title: title,
      description: description,
      classId: classId,
      className: className,
      subjectId: subjectId,
      subjectName: subjectName,
      teacherId: teacherId,
      teacherName: teacherName,
      durationMinutes: durationMinutes,
      syncToGrades: syncToGrades,
      gradeCategory: gradeCategory,
      tahunAjaran: tahunAjaran,
      semester: semester,
      createdAt: DateTime.now(),
      dueDate: dueDate,
      status: 'active',
      questions: questions,
    );

    await docRef.set(exam.toFirestore());
  }

  /// Stream list ujian untuk kelas tertentu
  Stream<List<Exam>> getExamsForClass(String schoolId, String classId) {
    return _examsRef(schoolId)
        .where('classId', isEqualTo: classId)
        .where('status', isEqualTo: 'active')
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Exam.fromFirestore(doc)).toList());
  }

  /// Stream list ujian untuk guru tertentu
  Stream<List<Exam>> getExamsForTeacher(String schoolId, String teacherId) {
    return _examsRef(schoolId)
        .where('teacherId', isEqualTo: teacherId)
        .where('status', isEqualTo: 'active')
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Exam.fromFirestore(doc)).toList());
  }

  /// Stream seluruh hasil pengerjaan murid untuk ujian tertentu
  Stream<List<ExamSubmission>> getExamSubmissions(String schoolId, String examId) {
    return _submissionsRef(schoolId)
        .where('examId', isEqualTo: examId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ExamSubmission.fromFirestore(doc))
            .toList());
  }

  /// Mengambil data pengerjaan murid tertentu secara real-time
  Stream<ExamSubmission?> getExamSubmissionStream(
      String schoolId, String examId, String studentId) {
    final submissionId = '${examId}_$studentId';
    return _submissionsRef(schoolId)
        .doc(submissionId)
        .snapshots()
        .map((doc) => doc.exists ? ExamSubmission.fromFirestore(doc) : null);
  }

  /// Murid mengumpulkan pengerjaan ujian online, otomatis dinilai, & sinkronisasi nilai
  Future<void> submitExam({
    required String schoolId,
    required Exam exam,
    required String studentId,
    required String studentName,
    required Map<String, int> answers,
  }) async {
    int correctCount = 0;
    int incorrectCount = 0;

    for (final q in exam.questions) {
      final studentAnswer = answers[q.id];
      if (studentAnswer == q.correctOptionIndex) {
        correctCount++;
      } else {
        incorrectCount++;
      }
    }

    final double score = exam.questions.isEmpty
        ? 0.0
        : double.parse(((correctCount / exam.questions.length) * 100).toStringAsFixed(2));

    final submissionId = '${exam.id}_$studentId';
    final submission = ExamSubmission(
      id: submissionId,
      examId: exam.id,
      studentId: studentId,
      studentName: studentName,
      answers: answers,
      correctCount: correctCount,
      incorrectCount: incorrectCount,
      score: score,
      submittedAt: DateTime.now(),
      tahunAjaran: exam.tahunAjaran,
      semester: exam.semester,
    );

    // 1. Simpan dokumen submission pengerjaan ujian
    await _submissionsRef(schoolId).doc(submissionId).set(submission.toFirestore());

    // 2. Jika diaktifkan, otomatis sinkronisasikan nilai ke Buku Nilai (/grades)
    if (exam.syncToGrades) {
      final gradeDocRef = _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('grades')
          .doc(exam.id);

      // Tulis metadata utama buku nilai (jika belum ada)
      await gradeDocRef.set({
        'gradeId': exam.id,
        'schoolId': schoolId,
        'classId': exam.classId,
        'className': exam.className,
        'subjectId': exam.subjectId,
        'subjectName': exam.subjectName,
        'teacherId': exam.teacherId,
        'teacherName': exam.teacherName,
        'title': exam.title,
        'category': exam.gradeCategory,
        'maxScore': 100.0,
        'date': exam.createdAt.toIso8601String().split('T')[0],
        'tahunAjaran': exam.tahunAjaran,
        'semester': exam.semester,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Update skor spesifik murid menggunakan dot path notation
      await gradeDocRef.update({
        'scores.$studentId': {
          'score': score,
          'notes': 'Otomatis dari Ujian Online: ${exam.title}',
        },
      });
    }
  }

  /// Menghapus ujian beserta seluruh hasil pengerjaan & dokumen grades terkait
  Future<void> deleteExam(String schoolId, String examId) async {
    // 1. Update status ujian ke archived
    await _examsRef(schoolId).doc(examId).update({'status': 'archived'});

    // 2. Bersihkan/hapus dokumen grades terkait agar tidak tersisa di buku nilai
    await _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('grades')
        .doc(examId)
        .delete();
  }
}
