import 'package:cloud_firestore/cloud_firestore.dart';

class GradeService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _gradesRef(String schoolId) =>
      _firestore.collection('schools').doc(schoolId).collection('grades');

  /// Menyimpan atau memperbarui data penilaian siswa
  Future<void> saveGrade({
    required String schoolId,
    required String? gradeId,
    required String classId,
    required String className,
    required String subjectId,
    required String subjectName,
    required String teacherId,
    required String teacherName,
    required String title,
    required String category,
    required double maxScore,
    required DateTime date,
    required Map<String, Map<String, dynamic>> scores,
    required String tahunAjaran,
    required String semester,
  }) async {
    final docRef = gradeId == null || gradeId.isEmpty
        ? _gradesRef(schoolId).doc()
        : _gradesRef(schoolId).doc(gradeId);

    final String finalGradeId = docRef.id;

    // Bersihkan map scores agar format tipe score konsisten (double)
    final Map<String, Map<String, dynamic>> formattedScores = {};
    scores.forEach((studentId, detail) {
      final double scoreVal = (detail['score'] ?? 0.0) as double;
      final String notesVal = (detail['notes'] ?? '').toString();
      formattedScores[studentId] = {
        'score': scoreVal,
        'notes': notesVal,
      };
    });

    await docRef.set({
      'gradeId': finalGradeId,
      'schoolId': schoolId,
      'classId': classId,
      'className': className,
      'subjectId': subjectId,
      'subjectName': subjectName,
      'teacherId': teacherId,
      'teacherName': teacherName,
      'title': title,
      'category': category,
      'maxScore': maxScore,
      'date': date.toIso8601String().split('T')[0],
      'scores': formattedScores,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'tahunAjaran': tahunAjaran,
      'semester': semester,
    }, SetOptions(merge: true));
  }

  /// Menyimpan konfigurasi bobot kategori global per kelas & mata pelajaran
  Future<void> saveCategoryWeights({
    required String schoolId,
    required String classId,
    required String subjectId,
    required String teacherId,
    required Map<String, double> weights,
    required String tahunAjaran,
    required String semester,
  }) async {
    final docId = '${classId}_${subjectId}_${tahunAjaran.replaceAll('/', '_')}_$semester';
    await _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('subject_weights')
        .doc(docId)
        .set({
      'classId': classId,
      'subjectId': subjectId,
      'teacherId': teacherId,
      'weights': weights,
      'updatedAt': FieldValue.serverTimestamp(),
      'tahunAjaran': tahunAjaran,
      'semester': semester,
    }, SetOptions(merge: true));
  }

  /// Mendapatkan stream konfigurasi bobot kategori global
  Stream<DocumentSnapshot<Map<String, dynamic>>> getCategoryWeights({
    required String schoolId,
    required String classId,
    required String subjectId,
    required String tahunAjaran,
    required String semester,
  }) {
    final docId = '${classId}_${subjectId}_${tahunAjaran.replaceAll('/', '_')}_$semester';
    return _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('subject_weights')
        .doc(docId)
        .snapshots();
  }

  /// Mendapatkan semua data penilaian yang dibuat oleh guru tertentu (dengan filter opsional)
  Stream<QuerySnapshot<Map<String, dynamic>>> getGradesByTeacher(
    String schoolId,
    String teacherId, {
    String? classId,
    String? subjectId,
    required String tahunAjaran,
    required String semester,
  }) {
    Query<Map<String, dynamic>> query = _gradesRef(schoolId)
        .where('teacherId', isEqualTo: teacherId)
        .where('tahunAjaran', isEqualTo: tahunAjaran)
        .where('semester', isEqualTo: semester);
    if (classId != null && classId.isNotEmpty) {
      query = query.where('classId', isEqualTo: classId);
    }
    if (subjectId != null && subjectId.isNotEmpty) {
      query = query.where('subjectId', isEqualTo: subjectId);
    }
    return query.snapshots();
  }

  /// Menghapus dokumen penilaian
  Future<void> deleteGrade(String schoolId, String gradeId) async {
    await _gradesRef(schoolId).doc(gradeId).delete();
  }

  /// Mendapatkan data siswa berdasarkan kelas untuk proses penilaian
  Stream<QuerySnapshot<Map<String, dynamic>>> getStudentsByClass(
    String schoolId,
    String classId,
  ) {
    return _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('students')
        .where('classId', isEqualTo: classId)
        .snapshots();
  }

  /// Mendapatkan semua data penilaian dalam suatu kelas (untuk Rekap Nilai oleh Wali Kelas atau Admin)
  Stream<QuerySnapshot<Map<String, dynamic>>> getGradesByClass({
    required String schoolId,
    required String classId,
    required String tahunAjaran,
    required String semester,
  }) {
    return _gradesRef(schoolId)
        .where('classId', isEqualTo: classId)
        .where('tahunAjaran', isEqualTo: tahunAjaran)
        .where('semester', isEqualTo: semester)
        .snapshots();
  }

  /// Menyimpan deskripsi pencapaian siswa per mata pelajaran dan semester
  Future<void> saveSubjectDescription({
    required String schoolId,
    required String subjectId,
    required String studentId,
    required String tahunAjaran,
    required String semester,
    required String deskripsi,
    required String updatedBy,
  }) async {
    final docId = '${subjectId}_${studentId}_${tahunAjaran.replaceAll('/', '_')}_$semester';
    await _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('subject_descriptions')
        .doc(docId)
        .set({
      'subjectId': subjectId,
      'studentId': studentId,
      'tahunAjaran': tahunAjaran,
      'semester': semester,
      'deskripsi': deskripsi,
      'updatedBy': updatedBy,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Mendapatkan semua deskripsi pencapaian mata pelajaran untuk satu siswa di satu semester
  Future<Map<String, String>> getSubjectDescriptions({
    required String schoolId,
    required String studentId,
    required String tahunAjaran,
    required String semester,
  }) async {
    final snapshot = await _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('subject_descriptions')
        .where('studentId', isEqualTo: studentId)
        .where('tahunAjaran', isEqualTo: tahunAjaran)
        .where('semester', isEqualTo: semester)
        .get();

    final Map<String, String> results = {};
    for (var doc in snapshot.docs) {
      final data = doc.data();
      final String? subjectId = data['subjectId'] as String?;
      final String? deskripsi = data['deskripsi'] as String?;
      if (subjectId != null && deskripsi != null) {
        results[subjectId] = deskripsi;
      }
    }
    return results;
  }

  /// Mendapatkan deskripsi pencapaian mata pelajaran untuk siswa tertentu per mata pelajaran dan semester
  Future<String?> getSingleSubjectDescription({
    required String schoolId,
    required String subjectId,
    required String studentId,
    required String tahunAjaran,
    required String semester,
  }) async {
    final docId = '${subjectId}_${studentId}_${tahunAjaran.replaceAll('/', '_')}_$semester';
    final doc = await _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('subject_descriptions')
        .doc(docId)
        .get();
    if (doc.exists) {
      return doc.data()?['deskripsi'] as String?;
    }
    return null;
  }

  /// Mendapatkan semua deskripsi pencapaian untuk mata pelajaran tertentu di satu semester
  Future<Map<String, String>> getSubjectDescriptionsBySubject({
    required String schoolId,
    required String subjectId,
    required String tahunAjaran,
    required String semester,
  }) async {
    final snapshot = await _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('subject_descriptions')
        .where('subjectId', isEqualTo: subjectId)
        .where('tahunAjaran', isEqualTo: tahunAjaran)
        .where('semester', isEqualTo: semester)
        .get();

    final Map<String, String> results = {};
    for (var doc in snapshot.docs) {
      final data = doc.data();
      final String? studentId = data['studentId'] as String?;
      final String? deskripsi = data['deskripsi'] as String?;
      if (studentId != null && deskripsi != null) {
        results[studentId] = deskripsi;
      }
    }
    return results;
  }
}


