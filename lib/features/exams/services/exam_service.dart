import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
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
    await _submissionsRef(schoolId).doc(submissionId).set(submission.toFirestore(), SetOptions(merge: true));

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

    // 5. Kirim push notifikasi personal ke murid
    try {
      final studentDoc = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('students')
          .doc(submission.studentId)
          .get();
      final studentUid = studentDoc.data()?['uid'] as String?;
      if (studentUid != null && studentUid.isNotEmpty) {
        final language = studentDoc.data()?['language'] as String? ?? 'id';
        final isEnglish = language == 'en';
        final title = isEnglish ? 'Exam Grading Completed' : 'Hasil Koreksi Ujian';
        final content = isEnglish
            ? 'Your score for ${exam.subjectName} has been updated to ${finalScore.toInt()}'
            : 'Nilai kamu dengan mapel ${exam.subjectName} sudah diupdate dengan nilai ${finalScore.toInt()}';

        await _firestore
            .collection('schools')
            .doc(schoolId)
            .collection('notifications')
            .add({
          'title': title,
          'content': content,
          'targetType': 'personal',
          'targetId': studentUid,
          'senderId': exam.teacherId,
          'senderName': exam.teacherName,
          'senderRole': 'teacher',
          'category': 'grade',
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      // Don't crash the main grading flow if push notification fails
      print('Gagal mengirim push notifikasi koreksi ujian: $e');
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

  /// Memeriksa draf ujian lokal yang tersimpan di SharedPreferences.
  /// Jika ada draf ujian yang sudah mulai ('started') tetapi batas deadline/waktu
  /// ujian sudah habis (expired), maka sistem akan mengumpulkannya secara otomatis di latar belakang.
  Future<void> checkAndAutoSubmitExpiredExams({
    required String schoolId,
    required String studentId,
    required String studentName,
    required List<Exam> exams,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final exam in exams) {
        final startedKey = 'exam_draft_started_${studentId}_${exam.id}';
        final draftStarted = prefs.getBool(startedKey) ?? false;
        
        if (!draftStarted) continue;

        // Cek apakah deadline ujian sudah lewat
        final isExpired = DateTime.now().isAfter(exam.dueDate);
        if (isExpired) {
          // Load draf jawaban
          final mcKey = 'exam_draft_mc_${studentId}_${exam.id}';
          final essayKey = 'exam_draft_essay_${studentId}_${exam.id}';
          final mcRaw = prefs.getString(mcKey);
          final essayRaw = prefs.getString(essayKey);

          final Map<String, int> selectedAnswers = {};
          final Map<String, String> essayAnswers = {};

          if (mcRaw != null && mcRaw.isNotEmpty) {
            final Map<String, dynamic> decoded = jsonDecode(mcRaw);
            decoded.forEach((key, val) {
              if (val is int) {
                selectedAnswers[key] = val;
              }
            });
          }
          if (essayRaw != null && essayRaw.isNotEmpty) {
            final Map<String, dynamic> decoded = jsonDecode(essayRaw);
            decoded.forEach((key, val) {
              if (val is String) {
                essayAnswers[key] = val;
              }
            });
          }

          debugPrint('Auto-submitting expired exam in background: ${exam.title}');
          
          // Submit
          await submitExam(
            schoolId: schoolId,
            exam: exam,
            studentId: studentId,
            studentName: studentName,
            answers: selectedAnswers,
            essayAnswers: essayAnswers,
          );

          // Clear draf
          await prefs.remove(mcKey);
          await prefs.remove(essayKey);
          await prefs.remove(startedKey);
        }
      }
    } catch (e) {
      debugPrint('Error in checkAndAutoSubmitExpiredExams: $e');
    }
  }

  /// Memeriksa draf ujian semester lokal yang tersimpan di SharedPreferences.
  /// Jika ada draf yang sudah mulai, tetapi sesi ujian semester tersebut sudah habis (expired),
  /// maka sistem akan mengumpulkannya secara otomatis di latar belakang.
  Future<void> checkAndAutoSubmitExpiredSemesterExam({
    required String schoolId,
    required String studentId,
    required String studentName,
    required Exam exam,
    required String sessionId,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final startedKey = 'exam_draft_started_${studentId}_${exam.id}';
      final draftStarted = prefs.getBool(startedKey) ?? false;
      
      if (!draftStarted) return;

      // Submit ke submissions & participations
      final mcKey = 'exam_draft_mc_${studentId}_${exam.id}';
      final essayKey = 'exam_draft_essay_${studentId}_${exam.id}';
      final mcRaw = prefs.getString(mcKey);
      final essayRaw = prefs.getString(essayKey);

      final Map<String, int> selectedAnswers = {};
      final Map<String, String> essayAnswers = {};

      if (mcRaw != null && mcRaw.isNotEmpty) {
        final Map<String, dynamic> decoded = jsonDecode(mcRaw);
        decoded.forEach((key, val) {
          if (val is int) {
            selectedAnswers[key] = val;
          }
        });
      }
      if (essayRaw != null && essayRaw.isNotEmpty) {
        final Map<String, dynamic> decoded = jsonDecode(essayRaw);
        decoded.forEach((key, val) {
          if (val is String) {
            essayAnswers[key] = val;
          }
        });
      }

      debugPrint('Auto-submitting expired semester exam in background: ${exam.title}');
      
      // Submit ke submissions
      await submitExam(
        schoolId: schoolId,
        exam: exam,
        studentId: studentId,
        studentName: studentName,
        answers: selectedAnswers,
        essayAnswers: essayAnswers,
      );

      // Update submittedAt di participations (denah tempat duduk)
      await FirebaseFirestore.instance
          .collection('schools')
          .doc(schoolId)
          .collection('exam_sessions')
          .doc(sessionId)
          .collection('participations')
          .doc(studentId)
          .set({'submittedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));

      // Clear draf
      await prefs.remove(mcKey);
      await prefs.remove(essayKey);
      await prefs.remove(startedKey);
    } catch (e) {
      debugPrint('Error in checkAndAutoSubmitExpiredSemesterExam: $e');
    }
  }

  /// Memeriksa semua draf ujian online kelas dan ujian semester milik murid yang tersimpan.
  /// Jika ada draf yang sudah dimulai tapi ujiannya telah berakhir/kedaluwarsa,
  /// maka sistem secara otomatis mengumpulkannya di latar belakang.
  /// Dipanggil saat inisialisasi aplikasi (misal di Dashboard Murid) agar langsung terkirim
  /// tanpa harus menunggu murid membuka halaman Ujian.
  Future<void> checkAndAutoSubmitAllExpiredExamsForStudent({
    required String schoolId,
    required String studentId,
    required String studentName,
    required String classId,
  }) async {
    try {
      final db = FirebaseFirestore.instance;
      final now = DateTime.now();

      // 1. Ambil semua ujian online kelas
      final examsSnapshot = await db
          .collection('schools')
          .doc(schoolId)
          .collection('exams')
          .where('classId', isEqualTo: classId)
          .get();

      final exams = examsSnapshot.docs.map((doc) => Exam.fromFirestore(doc)).toList();
      
      // Auto-submit untuk ujian online kelas yang kedaluwarsa
      await checkAndAutoSubmitExpiredExams(
        schoolId: schoolId,
        studentId: studentId,
        studentName: studentName,
        exams: exams,
      );

      // 2. Ambil sesi ujian semester hari ini
      final todayDateStr = DateFormat('yyyy-MM-dd').format(now);
      final sessionsSnapshot = await db
          .collection('schools')
          .doc(schoolId)
          .collection('exam_sessions')
          .where('classId', isEqualTo: classId)
          .get();

      for (final doc in sessionsSnapshot.docs) {
        final sessionData = doc.data();
        final sessionDate = (sessionData['date'] as Timestamp?)?.toDate();
        if (sessionDate == null) continue;

        final sessionDateStr = DateFormat('yyyy-MM-dd').format(sessionDate);
        
        // Hanya cek untuk sesi hari ini atau sesi di hari-hari sebelumnya yang sudah lewat
        final cmp = sessionDateStr.compareTo(todayDateStr);
        bool isExamTimeOver = false;
        
        if (sessionData['examStatus'] == 'Finished') {
          isExamTimeOver = true;
        } else if (cmp < 0) {
          isExamTimeOver = true;
        } else if (cmp == 0) {
          try {
            final endParts = (sessionData['endTime'] as String? ?? '00:00').split(':');
            final sessionEnd = DateTime(
              now.year, now.month, now.day,
              int.parse(endParts[0]), int.parse(endParts[1]),
            );
            isExamTimeOver = now.isAfter(sessionEnd);
          } catch (_) {}
        }

        if (isExamTimeOver) {
          // Ambil detail ujian semester terkait
          final examId = sessionData['examId'] as String?;
          if (examId == null) continue;

          final examDoc = await db
              .collection('schools')
              .doc(schoolId)
              .collection('exams')
              .doc(examId)
              .get();

          if (!examDoc.exists) continue;
          final exam = Exam.fromFirestore(examDoc);

          // Cek angkatan murid jika ada pertanyaan khusus angkatan (sama seperti logika di participation page)
          final studentDoc = await db
              .collection('schools')
              .doc(schoolId)
              .collection('students')
              .doc(studentId)
              .get();
          final studentAngkatan = studentDoc.data()?['angkatan']?.toString() ?? '';

          final qDoc = await db
              .collection('schools')
              .doc(schoolId)
              .collection('exam_questions')
              .doc('${sessionData['eventId']}_${sessionData['subjectId']}_$studentAngkatan')
              .get();

          List<ExamQuestion> finalQuestions = exam.questions;
          bool finalShufflePg = exam.shufflePg;
          bool finalShuffleEssay = exam.shuffleEssay;

          if (qDoc.exists && qDoc.data() != null) {
            final qData = qDoc.data()!;
            final qList = (qData['questions'] as List? ?? [])
                .map((q) => ExamQuestion.fromMap(Map<String, dynamic>.from(q)))
                .toList();
            if (qList.isNotEmpty) {
              finalQuestions = qList;
              finalShufflePg = qData['shufflePg'] as bool? ?? false;
              finalShuffleEssay = qData['shuffleEssay'] as bool? ?? false;
            }
          }

          final overriddenExam = exam.copyWith(
            questions: finalQuestions,
            shufflePg: finalShufflePg,
            shuffleEssay: finalShuffleEssay,
          );

          await checkAndAutoSubmitExpiredSemesterExam(
            schoolId: schoolId,
            studentId: studentId,
            studentName: studentName,
            exam: overriddenExam,
            sessionId: doc.id,
          );
        }
      }
    } catch (e) {
      debugPrint('Error in checkAndAutoSubmitAllExpiredExamsForStudent: $e');
    }
  }

  /// Dipanggil oleh guru/admin untuk memeriksa dan mengumpulkan draf ujian yang sudah kedaluwarsa
  /// milik seluruh murid di sekolah tersebut (jika murid tidak membuka aplikasi lagi).
  Future<void> checkAndAutoSubmitAllExpiredDraftsForSchool({
    required String schoolId,
    required List<Exam> exams,
  }) async {
    try {
      final db = FirebaseFirestore.instance;
      final now = DateTime.now();

      for (final exam in exams) {
        // Cek apakah deadline ujian sudah lewat
        final isExpired = now.isAfter(exam.dueDate);
        if (!isExpired) continue;

        // Ambil semua draf di Firestore untuk examId ini
        final draftsSnapshot = await db
            .collection('schools')
            .doc(schoolId)
            .collection('exam_drafts')
            .where('examId', isEqualTo: exam.id)
            .get();

        for (final doc in draftsSnapshot.docs) {
          final draftData = doc.data();
          final studentId = draftData['studentId'] as String?;
          final studentName = draftData['studentName'] as String? ?? 'Murid';
          
          if (studentId == null) continue;

          // Cek apakah submission sudah ada di Firestore
          final submissionId = '${exam.id}_$studentId';
          final subDoc = await db
              .collection('schools')
              .doc(schoolId)
              .collection('exam_submissions')
              .doc(submissionId)
              .get();

          // Jika belum disubmit, lakukan auto-submit
          if (!subDoc.exists) {
            final rawAnswers = draftData['answers'] as Map? ?? {};
            final Map<String, int> selectedAnswers = rawAnswers.map(
              (key, val) => MapEntry(key.toString(), (val as num? ?? 0).toInt())
            );

            final rawEssayAnswers = draftData['essayAnswers'] as Map? ?? {};
            final Map<String, String> essayAnswers = rawEssayAnswers.map(
              (key, val) => MapEntry(key.toString(), val.toString())
            );

            debugPrint('Auto-submitting draft on behalf of student $studentName for exam ${exam.title}');
            await submitExam(
              schoolId: schoolId,
              exam: exam,
              studentId: studentId,
              studentName: studentName,
              answers: selectedAnswers,
              essayAnswers: essayAnswers,
            );
          }

          // Hapus dokumen draf karena sudah diproses
          await doc.reference.delete();
        }
      }
    } catch (e) {
      debugPrint('Error in checkAndAutoSubmitAllExpiredDraftsForSchool: $e');
    }
  }

  /// Dipanggil oleh guru/admin untuk memeriksa dan mengumpulkan draf ujian semester yang sudah kedaluwarsa
  /// milik seluruh murid di sekolah tersebut.
  Future<void> checkAndAutoSubmitAllExpiredSemesterDraftsForSchool({
    required String schoolId,
    required String classId,
  }) async {
    try {
      final db = FirebaseFirestore.instance;
      final now = DateTime.now();
      final todayDateStr = DateFormat('yyyy-MM-dd').format(now);

      // Ambil sesi ujian semester hari ini
      final sessionsSnapshot = await db
          .collection('schools')
          .doc(schoolId)
          .collection('exam_sessions')
          .where('classId', isEqualTo: classId)
          .get();

      for (final doc in sessionsSnapshot.docs) {
        final sessionData = doc.data();
        final sessionDate = (sessionData['date'] as Timestamp?)?.toDate();
        if (sessionDate == null) continue;

        final sessionDateStr = DateFormat('yyyy-MM-dd').format(sessionDate);
        
        final cmp = sessionDateStr.compareTo(todayDateStr);
        bool isExamTimeOver = false;
        
        if (sessionData['examStatus'] == 'Finished') {
          isExamTimeOver = true;
        } else if (cmp < 0) {
          isExamTimeOver = true;
        } else if (cmp == 0) {
          try {
            final endParts = (sessionData['endTime'] as String? ?? '00:00').split(':');
            final sessionEnd = DateTime(
              now.year, now.month, now.day,
              int.parse(endParts[0]), int.parse(endParts[1]),
            );
            isExamTimeOver = now.isAfter(sessionEnd);
          } catch (_) {}
        }

        if (isExamTimeOver) {
          final examId = sessionData['examId'] as String?;
          if (examId == null) continue;

          // Ambil draf di Firestore untuk examId ini
          final draftsSnapshot = await db
              .collection('schools')
              .doc(schoolId)
              .collection('exam_drafts')
              .where('examId', isEqualTo: examId)
              .get();

          if (draftsSnapshot.docs.isEmpty) continue;

          final examDoc = await db
              .collection('schools')
              .doc(schoolId)
              .collection('exams')
              .doc(examId)
              .get();

          if (!examDoc.exists) continue;
          final exam = Exam.fromFirestore(examDoc);

          for (final draftDoc in draftsSnapshot.docs) {
            final draftData = draftDoc.data();
            final studentId = draftData['studentId'] as String?;
            final studentName = draftData['studentName'] as String? ?? 'Murid';
            
            if (studentId == null) continue;

            final submissionId = '${examId}_$studentId';
            final subDoc = await db
                .collection('schools')
                .doc(schoolId)
                .collection('exam_submissions')
                .doc(submissionId)
                .get();

            if (!subDoc.exists) {
              final rawAnswers = draftData['answers'] as Map? ?? {};
              final Map<String, int> selectedAnswers = rawAnswers.map(
                (key, val) => MapEntry(key.toString(), (val as num? ?? 0).toInt())
              );

              final rawEssayAnswers = draftData['essayAnswers'] as Map? ?? {};
              final Map<String, String> essayAnswers = rawEssayAnswers.map(
                (key, val) => MapEntry(key.toString(), val.toString())
              );

              // Cek angkatan murid
              final studentDoc = await db
                  .collection('schools')
                  .doc(schoolId)
                  .collection('students')
                  .doc(studentId)
                  .get();
              final studentAngkatan = studentDoc.data()?['angkatan']?.toString() ?? '';

              final qDoc = await db
                  .collection('schools')
                  .doc(schoolId)
                  .collection('exam_questions')
                  .doc('${sessionData['eventId']}_${sessionData['subjectId']}_$studentAngkatan')
                  .get();

              List<ExamQuestion> finalQuestions = exam.questions;
              bool finalShufflePg = exam.shufflePg;
              bool finalShuffleEssay = exam.shuffleEssay;

              if (qDoc.exists && qDoc.data() != null) {
                final qData = qDoc.data()!;
                final qList = (qData['questions'] as List? ?? [])
                    .map((q) => ExamQuestion.fromMap(Map<String, dynamic>.from(q)))
                    .toList();
                if (qList.isNotEmpty) {
                  finalQuestions = qList;
                  finalShufflePg = qData['shufflePg'] as bool? ?? false;
                  finalShuffleEssay = qData['shuffleEssay'] as bool? ?? false;
                }
              }

              final overriddenExam = exam.copyWith(
                questions: finalQuestions,
                shufflePg: finalShufflePg,
                shuffleEssay: finalShuffleEssay,
              );

              debugPrint('Auto-submitting semester draft on behalf of student $studentName for exam ${exam.title}');
              await submitExam(
                schoolId: schoolId,
                exam: overriddenExam,
                studentId: studentId,
                studentName: studentName,
                answers: selectedAnswers,
                essayAnswers: essayAnswers,
              );

              // Update submittedAt di participations (denah tempat duduk)
              await db
                  .collection('schools')
                  .doc(schoolId)
                  .collection('exam_sessions')
                  .doc(doc.id)
                  .collection('participations')
                  .doc(studentId)
                  .set({'submittedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
            }

            // Hapus dokumen draf
            await draftDoc.reference.delete();
          }
        }
      }
    } catch (e) {
      debugPrint('Error in checkAndAutoSubmitAllExpiredSemesterDraftsForSchool: $e');
    }
  }
}
