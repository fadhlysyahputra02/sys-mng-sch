import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/task_model.dart';

class TaskService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // --- Task Methods (Guru) ---

  /// Membuat tugas baru di sub-koleksi tasks
  Future<void> createTask({
    required String schoolId,
    required String title,
    required String description,
    required String subjectId,
    required String subjectName,
    required String classId,
    required String className,
    required String teacherId,
    required String teacherName,
    required DateTime dueDate,
    String? attachmentLink,
    required String tahunAjaran,
    required String semester,
    bool syncToGrades = false,
  }) async {
    final docRef = _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('tasks')
        .doc();

    final task = Task(
      id: docRef.id,
      title: title,
      description: description,
      subjectId: subjectId,
      subjectName: subjectName,
      classId: classId,
      className: className,
      teacherId: teacherId,
      teacherName: teacherName,
      createdAt: DateTime.now(),
      dueDate: dueDate,
      attachmentLink: attachmentLink,
      status: 'active',
      tahunAjaran: tahunAjaran,
      semester: semester,
      syncToGrades: syncToGrades,
    );

    await docRef.set(task.toFirestore());
  }

  /// Menghapus tugas beserta seluruh submission miliknya
  Future<void> deleteTask(String schoolId, String taskId) async {
    // 1. Hapus dokumen tugas
    await _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('tasks')
        .doc(taskId)
        .delete();

    // 2. Hapus submission terkait (opsional tapi disarankan agar database bersih)
    final submissionsSnapshot = await _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('task_submissions')
        .where('taskId', isEqualTo: taskId)
        .get();

    final batch = _firestore.batch();
    for (final doc in submissionsSnapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();

    // 3. Hapus dokumen nilai terkait di koleksi grades jika ada
    await _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('grades')
        .doc(taskId)
        .delete();
  }

  /// Mengambil aliran data (Stream) daftar tugas untuk Guru
  Stream<List<Task>> getTasksByTeacher({
    required String schoolId,
    required String teacherId,
    String? classId,
    String? subjectId,
    required String tahunAjaran,
    required String semester,
  }) {
    var query = _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('tasks')
        .where('teacherId', isEqualTo: teacherId)
        .where('tahunAjaran', isEqualTo: tahunAjaran)
        .where('semester', isEqualTo: semester);

    if (classId != null && classId.isNotEmpty) {
      query = query.where('classId', isEqualTo: classId);
    }
    if (subjectId != null && subjectId.isNotEmpty) {
      query = query.where('subjectId', isEqualTo: subjectId);
    }

    return query.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => Task.fromFirestore(doc)).toList();
    });
  }

  // --- Submission Methods (Murid) ---

  /// Murid mengumpulkan tugas
  Future<void> submitTask({
    required String schoolId,
    required String taskId,
    required String studentId,
    required String studentName,
    String? studentNotes,
    String? answerLink,
    required bool isLate,
  }) async {
    final submissionId = '${taskId}_$studentId';
    final docRef = _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('task_submissions')
        .doc(submissionId);

    final submission = TaskSubmission(
      id: submissionId,
      taskId: taskId,
      studentId: studentId,
      studentName: studentName,
      submittedAt: DateTime.now(),
      status: isLate ? 'late' : 'submitted',
      studentNotes: studentNotes,
      answerLink: answerLink,
    );

    await docRef.set(submission.toFirestore());
  }

  /// Stream seluruh tugas murid berdasarkan kelasnya
  Stream<List<Task>> getTasksByClass({
    required String schoolId,
    required String classId,
    required String tahunAjaran,
    required String semester,
  }) {
    return _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('tasks')
        .where('classId', isEqualTo: classId)
        .where('tahunAjaran', isEqualTo: tahunAjaran)
        .where('semester', isEqualTo: semester)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => Task.fromFirestore(doc)).toList();
    });
  }

  /// Stream pengumpulan tugas (submission) spesifik murid
  Stream<List<TaskSubmission>> getSubmissionsByStudent({
    required String schoolId,
    required String studentId,
  }) {
    return _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('task_submissions')
        .where('studentId', isEqualTo: studentId)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => TaskSubmission.fromFirestore(doc)).toList();
    });
  }

  /// Stream pengumpulan murid untuk satu tugas tertentu (untuk Guru menilai)
  Stream<List<TaskSubmission>> getSubmissionsForTask({
    required String schoolId,
    required String taskId,
  }) {
    return _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('task_submissions')
        .where('taskId', isEqualTo: taskId)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => TaskSubmission.fromFirestore(doc)).toList();
    });
  }

  /// Guru memberikan nilai & feedback untuk tugas siswa
  Future<void> gradeSubmission({
    required String schoolId,
    required String taskId,
    required String studentId,
    required double grade,
    String? feedback,
  }) async {
    final submissionId = '${taskId}_$studentId';
    await _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('task_submissions')
        .doc(submissionId)
        .update({
      'grade': grade,
      'teacherFeedback': feedback,
      'status': 'graded',
      'gradedAt': FieldValue.serverTimestamp(),
    });

    // Cek apakah tugas disinkronisasikan ke buku nilai akademik utama
    final taskSnapshot = await _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('tasks')
        .doc(taskId)
        .get();

    if (taskSnapshot.exists) {
      final taskData = taskSnapshot.data() ?? {};
      final syncToGrades = taskData['syncToGrades'] as bool? ?? false;
      if (syncToGrades) {
        final classId = taskData['classId']?.toString() ?? '';
        final className = taskData['className']?.toString() ?? '';
        final subjectId = taskData['subjectId']?.toString() ?? '';
        final subjectName = taskData['subjectName']?.toString() ?? '';
        final teacherId = taskData['teacherId']?.toString() ?? '';
        final teacherName = taskData['teacherName']?.toString() ?? '';
        final title = taskData['title']?.toString() ?? 'Tugas';
        final tahunAjaran = taskData['tahunAjaran']?.toString() ?? '';
        final semester = taskData['semester']?.toString() ?? '';
        final createdAt = (taskData['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();

        final gradeDocRef = _firestore
            .collection('schools')
            .doc(schoolId)
            .collection('grades')
            .doc(taskId);

        // Tulis metadata utama buku nilai (jika belum ada)
        await gradeDocRef.set({
          'gradeId': taskId,
          'schoolId': schoolId,
          'classId': classId,
          'className': className,
          'subjectId': subjectId,
          'subjectName': subjectName,
          'teacherId': teacherId,
          'teacherName': teacherName,
          'title': title,
          'category': 'Tugas',
          'maxScore': 100.0,
          'date': createdAt.toIso8601String().split('T')[0],
          'tahunAjaran': tahunAjaran,
          'semester': semester,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        // Update skor spesifik murid menggunakan dot path notation
        await gradeDocRef.update({
          'scores.$studentId': {
            'score': grade,
            'notes': feedback ?? '',
          },
        });
      }
    }
  }
}
