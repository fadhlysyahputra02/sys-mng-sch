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
  Future<String> createExam({
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
      teacherIds: [teacherId],
      teacherNames: [teacherName],
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
    return docRef.id;
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

  /// Stream list ujian untuk guru tertentu (dengan client-side filtering untuk multi-corrector)
  Stream<List<Exam>> getExamsForTeacher(String schoolId, String teacherId) {
    return _examsRef(schoolId)
        .where('status', isEqualTo: 'active')
        .snapshots()
        .map((snapshot) {
          final list = snapshot.docs.map((doc) => Exam.fromFirestore(doc)).toList();
          return list.where((exam) {
            final isSemester = exam.gradeCategory == 'UTS' || exam.gradeCategory == 'UAS';
            final isMyExam = exam.teacherIds.contains(teacherId) || exam.teacherId == teacherId;
            return isMyExam && !isSemester;
          }).toList();
        });
  }

  /// Stream list ujian semester (UTS/UAS) untuk guru pengoreksi tertentu
  Stream<List<Exam>> getSemesterExamsForTeacher(String schoolId, String teacherId) {
    return _examsRef(schoolId)
        .where('status', isEqualTo: 'active')
        .snapshots()
        .map((snapshot) {
          final list = snapshot.docs.map((doc) => Exam.fromFirestore(doc)).toList();
          return list.where((exam) {
            final isSemester = exam.gradeCategory == 'UTS' || exam.gradeCategory == 'UAS';
            final isMyExam = exam.teacherIds.contains(teacherId) || exam.teacherId == teacherId;
            return isMyExam && isSemester;
          }).toList();
        });
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
    required Map<String, String> essayAnswers,
  }) async {
    int correctCount = 0;
    int incorrectCount = 0;
    int pointsObtained = 0;
    int totalMaxPoints = 0;
    bool hasEssay = false;

    for (final q in exam.questions) {
      totalMaxPoints += q.points;
      if (q.type == 'essay') {
        hasEssay = true;
      } else {
        final studentAnswer = answers[q.id];
        if (studentAnswer == q.correctOptionIndex) {
          correctCount++;
          pointsObtained += q.points;
        } else {
          incorrectCount++;
        }
      }
    }

    // Skor akhir = total poin yang diraih secara langsung (bukan persentase)
    // Untuk PG saja: score = jumlah poin PG yang benar
    // Untuk PG+Essay: score sementara dari PG, akan ditambah nilai essay manual oleh guru
    final double score = pointsObtained.toDouble();

    final isGraded = !hasEssay;
    final submissionId = '${exam.id}_$studentId';
    final submission = ExamSubmission(
      id: submissionId,
      examId: exam.id,
      studentId: studentId,
      studentName: studentName,
      answers: answers,
      essayAnswers: essayAnswers,
      essayScores: {},
      correctCount: correctCount,
      incorrectCount: incorrectCount,
      score: score,
      isGraded: isGraded,
      submittedAt: DateTime.now(),
      tahunAjaran: exam.tahunAjaran,
      semester: exam.semester,
    );

    // 1. Simpan dokumen submission pengerjaan ujian
    await _submissionsRef(schoolId).doc(submissionId).set(submission.toFirestore());

    // 2. Jika diaktifkan dan sudah selesai dinilai (tidak ada essay), otomatis sinkronisasikan nilai ke Buku Nilai (/grades)
    if (exam.syncToGrades && isGraded) {
      // Split classId kalau sesi ini menggabungkan beberapa kelas (comma-separated)
      final classIdParts = exam.classId.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
      final classNameParts = exam.className.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();

      for (int i = 0; i < classIdParts.length; i++) {
        final singleClassId = classIdParts[i];
        final singleClassName = i < classNameParts.length ? classNameParts[i] : classNameParts.last;

        // Gunakan ID: examId_classId agar setiap kelas punya dokumen sendiri
        final gradeDocId = classIdParts.length > 1 ? '${exam.id}_$singleClassId' : exam.id;
        final gradeDocRef = _firestore
            .collection('schools')
            .doc(schoolId)
            .collection('grades')
            .doc(gradeDocId);

        // Tulis metadata utama buku nilai (jika belum ada)
        await gradeDocRef.set({
          'gradeId': gradeDocId,
          'schoolId': schoolId,
          'classId': singleClassId,
          'className': singleClassName,
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
  }

  /// Guru menilai hasil pengerjaan essay secara manual
  Future<void> gradeSubmission({
    required String schoolId,
    required String submissionId,
    required Exam exam,
    required Map<String, int> essayScores,
  }) async {
    // 1. Ambil submission yang ada
    final docSnapshot = await _submissionsRef(schoolId).doc(submissionId).get();
    if (!docSnapshot.exists) {
      throw Exception('Submission tidak ditemukan.');
    }
    
    final submission = ExamSubmission.fromFirestore(docSnapshot);
    
    // 2. Hitung total poin
    int pointsObtained = 0;
    int totalMaxPoints = 0;

    // Validasi kritis: pastikan ID soal PG cocok dengan submission.answers.
    // Jika tidak ada satupun yang cocok, penilaian PG akan 0 semua (salah kaprah).
    // Ini bisa terjadi jika exam.questions berasal dari sumber berbeda dengan
    // soal yang digunakan murid saat mengerjakan.
    final pgQuestionsInExam = exam.questions.where((q) => q.type != 'essay').toList();
    final bool pgIdsMatchSubmission = pgQuestionsInExam.isEmpty ||
        pgQuestionsInExam.any((q) => submission.answers.containsKey(q.id));

    if (!pgIdsMatchSubmission && submission.answers.isNotEmpty) {
      // Ini adalah kondisi yang tidak diharapkan — ID tidak cocok.
      // Lempar exception agar pemanggil bisa menangani / fallback.
      throw Exception(
        'Mismatch antara ID soal PG dan jawaban submission. '
        'Pastikan exam.questions yang dikirim ke gradeSubmission '
        'menggunakan soal yang sama dengan saat murid mengerjakan.',
      );
    }

    for (final q in exam.questions) {
      totalMaxPoints += q.points;
      if (q.type == 'essay') {
        final score = essayScores[q.id] ?? 0;
        pointsObtained += score;
      } else {
        // PG: hitung poin hanya jika jawaban murid benar
        final studentAnswer = submission.answers[q.id];
        if (studentAnswer != null && studentAnswer == q.correctOptionIndex) {
          pointsObtained += q.points;
        }
      }
    }
    
    // Skor akhir = total poin diraih secara langsung (bukan persentase)
    double finalScore = pointsObtained.toDouble();
        
    // 3. Update dokumen submission di Firestore
    await _submissionsRef(schoolId).doc(submissionId).update({
      'essayScores': essayScores,
      'score': finalScore,
      'isGraded': true,
    });
    
    // 4. Jika diaktifkan, sinkronisasikan nilai akhir ke Buku Nilai (/grades)
    if (exam.syncToGrades) {
      // Split classId kalau sesi ini menggabungkan beberapa kelas (comma-separated)
      final classIdParts = exam.classId.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
      final classNameParts = exam.className.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();

      for (int i = 0; i < classIdParts.length; i++) {
        final singleClassId = classIdParts[i];
        final singleClassName = i < classNameParts.length ? classNameParts[i] : classNameParts.last;
        final gradeDocId = classIdParts.length > 1 ? '${exam.id}_$singleClassId' : exam.id;

        final gradeDocRef = _firestore
            .collection('schools')
            .doc(schoolId)
            .collection('grades')
            .doc(gradeDocId);

        await gradeDocRef.set({
          'gradeId': gradeDocId,
          'schoolId': schoolId,
          'classId': singleClassId,
          'className': singleClassName,
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

        final bool isUjianSemester = exam.gradeCategory == 'UTS' || exam.gradeCategory == 'UAS';

        await gradeDocRef.update({
          'scores.${submission.studentId}': {
            'score': finalScore,
            'notes': isUjianSemester ? 'Hasil Ujian Online' : 'Hasil Ujian Online (Termasuk Essay): ${exam.title}',
          },
        });
      }
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

  /// Memperbarui daftar murid yang diizinkan mengikuti ujian susulan
  Future<void> updateSusulanStudents(
      String schoolId, String examId, List<String> studentIds) async {
    await _examsRef(schoolId).doc(examId).update({
      'susulanStudentIds': studentIds,
    });
  }
}
