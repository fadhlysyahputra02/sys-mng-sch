import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../../../../core/services/session_service.dart';

class StudentService {
  final _db = FirebaseFirestore.instance;

  String get _schoolId => SessionService.currentUser!.schoolId;

  CollectionReference<Map<String, dynamic>> get _studentsRef => _db
      .collection('schools')
      .doc(_schoolId)
      .collection('students');

  Future<void> createStudent({
    required String schoolId,
    required String nis,
    required String nama,
    required String gender,
    required String alamat,
    String? tanggalLahir,
    String? angkatan,
    String? nisn,
    String? tempatLahir,
    String? agama,
    String? kewarganegaraan,
    String? noHp,
    String? jalurMasuk,
    String? tanggalDiterima,
    String? namaAyah,
    String? nikAyah,
    String? pekerjaanAyah,
    String? pendidikanAyah,
    String? noHpAyah,
    String? namaIbu,
    String? nikIbu,
    String? pekerjaanIbu,
    String? pendidikanIbu,
    String? noHpIbu,
    String? namaWali,
    String? hubunganWali,
    String? noHpWali,
    String? alamatWali,
  }) async {
    // Cek NIS sudah ada atau belum dalam sekolah yang sama
    final existing = await _db
        .collection('schools')
        .doc(schoolId)
        .collection('students')
        .where('nis', isEqualTo: nis)
        .get();

    if (existing.docs.isNotEmpty) {
      throw ('NIS sudah terdaftar');
    }

    // Cek kuota murid di sekolah jika diset
    final schoolDoc = await _db.collection('schools').doc(schoolId).get();
    if (schoolDoc.exists) {
      final schoolData = schoolDoc.data();
      final studentQuota = schoolData?['studentQuota'] as int?;
      if (studentQuota != null && studentQuota > 0) {
        // Hitung total murid aktif: Total Murid - Murid Lulus
        final totalSnap = await _db
            .collection('schools')
            .doc(schoolId)
            .collection('students')
            .count()
            .get();
        final totalCount = totalSnap.count ?? 0;

        final graduatedSnap = await _db
            .collection('schools')
            .doc(schoolId)
            .collection('students')
            .where('lulus', isEqualTo: true)
            .count()
            .get();
        final graduatedCount = graduatedSnap.count ?? 0;

        final activeCount = totalCount - graduatedCount;

        if (activeCount >= studentQuota) {
          throw ('Kuota murid aktif untuk sekolah ini sudah penuh ($studentQuota). Silakan hubungi Super Admin.');
        }
      }
    }

    final doc = _db
        .collection('schools')
        .doc(schoolId)
        .collection('students')
        .doc();

    await doc.set({
      'studentId': doc.id,
      'schoolId': schoolId,
      'uid': '',
      'email': '',
      'nis': nis,
      'nisn': nisn ?? '',
      'nama': nama,
      'gender': gender,
      'tempatLahir': tempatLahir ?? '',
      'tanggalLahir': tanggalLahir ?? '',
      'agama': agama ?? '',
      'kewarganegaraan': kewarganegaraan ?? '',
      'alamat': alamat,
      'noHp': noHp ?? '',
      'angkatan': angkatan ?? '',
      'jalurMasuk': jalurMasuk ?? '',
      'tanggalDiterima': tanggalDiterima ?? '',
      'namaAyah': namaAyah ?? '',
      'nikAyah': nikAyah ?? '',
      'pekerjaanAyah': pekerjaanAyah ?? '',
      'pendidikanAyah': pendidikanAyah ?? '',
      'noHpAyah': noHpAyah ?? '',
      'namaIbu': namaIbu ?? '',
      'nikIbu': nikIbu ?? '',
      'pekerjaanIbu': pekerjaanIbu ?? '',
      'pendidikanIbu': pendidikanIbu ?? '',
      'noHpIbu': noHpIbu ?? '',
      'namaWali': namaWali ?? '',
      'hubunganWali': hubunganWali ?? '',
      'noHpWali': noHpWali ?? '',
      'alamatWali': alamatWali ?? '',
      'classId': null,
      'aktif': true,
      'sudahRegister': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> getStudentsByClass(
    String classId,
  ) {
    return _studentsRef
        .where('classId', isEqualTo: classId)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> getStudentsWithoutClass(
    String schoolId,
  ) {
    return _db
        .collection('schools')
        .doc(schoolId)
        .collection('students')
        .where('classId', isNull: true)
        .snapshots();
  }

  Future<void> assignStudentToClass({
    required String studentId,
    required String classId,
  }) async {
    final classDoc = await _db
        .collection('schools')
        .doc(_schoolId)
        .collection('classes')
        .doc(classId)
        .get();

    if (!classDoc.exists) {
      throw ('Kelas tidak ditemukan');
    }

    final className = classDoc.data()?['namaKelas'] ?? '';

    // Ambil detail murid terlebih dahulu untuk dimasukkan ke data histori
    final studentDoc = await _studentsRef.doc(studentId).get();
    if (!studentDoc.exists) {
      throw ('Siswa tidak ditemukan');
    }
    final studentData = studentDoc.data()!;
    final studentName = studentData['nama'] ?? '';
    final studentNis = studentData['nis'] ?? '';

    // Dapatkan tahun ajaran dan semester aktif dari sekolah
    final schoolDoc = await _db.collection('schools').doc(_schoolId).get();
    final schoolData = schoolDoc.data() ?? {};
    final tahunAjaran = schoolData['tahunAjaran'] ?? '${DateTime.now().year}/${DateTime.now().year + 1}';
    final semester = schoolData['semester'] ?? 'Semester 1';

    // 1. Simpan di data murid (seperti sebelumnya untuk compatibility)
    await _studentsRef.doc(studentId).update({
      'classId': classId,
      'className': className,
    });

    // 2. Simpan di koleksi histori class_enrollments
    final cleanYear = tahunAjaran.replaceAll('/', '_');
    final enrollmentId = '${studentId}_${cleanYear}_$semester';
    await _db
        .collection('schools')
        .doc(_schoolId)
        .collection('class_enrollments')
        .doc(enrollmentId)
        .set({
      'studentId': studentId,
      'schoolId': _schoolId,
      'nama': studentName,
      'nis': studentNis,
      'classId': classId,
      'className': className,
      'tahunAjaran': tahunAjaran,
      'semester': semester,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> removeStudentFromClass(String studentId) async {
    // 1. Remove from active student
    await _studentsRef.doc(studentId).update({
      'classId': null,
      'className': null,
    });

    // 2. Hapus data enrollment aktif dari class_enrollments HANYA jika tidak ada riwayat absensi atau nilai
    final schoolDoc = await _db.collection('schools').doc(_schoolId).get();
    final schoolData = schoolDoc.data() ?? {};
    final tahunAjaran = schoolData['tahunAjaran'] ?? '${DateTime.now().year}/${DateTime.now().year + 1}';
    final semester = schoolData['semester'] ?? 'Semester 1';
    final cleanYear = tahunAjaran.replaceAll('/', '_');
    final enrollmentId = '${studentId}_${cleanYear}_$semester';

    // Cek data absensi
    final attendanceQuery = await _db
        .collection('schools')
        .doc(_schoolId)
        .collection('attendance')
        .where('studentId', isEqualTo: studentId)
        .where('tahunAjaran', isEqualTo: tahunAjaran)
        .where('semester', isEqualTo: semester)
        .limit(1)
        .get();

    // Cek data nilai
    final gradesQuery = await _db
        .collection('schools')
        .doc(_schoolId)
        .collection('grades')
        .where('tahunAjaran', isEqualTo: tahunAjaran)
        .where('semester', isEqualTo: semester)
        .get();

    bool hasGrades = false;
    for (final doc in gradesQuery.docs) {
      final scores = doc.data()['scores'] as Map?;
      if (scores != null) {
        if (scores.containsKey(studentId)) {
          hasGrades = true;
          break;
        }
        final fallbackKey = '${studentId}_${cleanYear}_$semester';
        if (scores.containsKey(fallbackKey)) {
          hasGrades = true;
          break;
        }
      }
    }

    if (attendanceQuery.docs.isEmpty && !hasGrades) {
      await _db
          .collection('schools')
          .doc(_schoolId)
          .collection('class_enrollments')
          .doc(enrollmentId)
          .delete();
    }
  }

  Future<void> updateStudent({
    required String studentId,
    required String nama,
    required String nis,
    required String gender,
    required String alamat,
    String? tanggalLahir,
    String? angkatan,
    String? nisn,
    String? tempatLahir,
    String? agama,
    String? kewarganegaraan,
    String? noHp,
    String? jalurMasuk,
    String? tanggalDiterima,
    String? namaAyah,
    String? nikAyah,
    String? pekerjaanAyah,
    String? pendidikanAyah,
    String? noHpAyah,
    String? namaIbu,
    String? nikIbu,
    String? pekerjaanIbu,
    String? pendidikanIbu,
    String? noHpIbu,
    String? namaWali,
    String? hubunganWali,
    String? noHpWali,
    String? alamatWali,
  }) async {
    // Cek duplikasi NIS — abaikan jika NIS milik murid yang sama (studentId sama)
    final existing = await _studentsRef
        .where('nis', isEqualTo: nis)
        .get();

    for (final doc in existing.docs) {
      if (doc.id != studentId) {
        throw ('NIS $nis sudah digunakan oleh murid lain');
      }
    }

    await _studentsRef.doc(studentId).update({
      'nama': nama,
      'nis': nis,
      'nisn': nisn ?? '',
      'gender': gender,
      'tempatLahir': tempatLahir ?? '',
      'tanggalLahir': tanggalLahir ?? '',
      'agama': agama ?? '',
      'kewarganegaraan': kewarganegaraan ?? '',
      'alamat': alamat,
      'noHp': noHp ?? '',
      'angkatan': angkatan ?? '',
      'jalurMasuk': jalurMasuk ?? '',
      'tanggalDiterima': tanggalDiterima ?? '',
      'namaAyah': namaAyah ?? '',
      'nikAyah': nikAyah ?? '',
      'pekerjaanAyah': pekerjaanAyah ?? '',
      'pendidikanAyah': pendidikanAyah ?? '',
      'noHpAyah': noHpAyah ?? '',
      'namaIbu': namaIbu ?? '',
      'nikIbu': nikIbu ?? '',
      'pekerjaanIbu': pekerjaanIbu ?? '',
      'pendidikanIbu': pendidikanIbu ?? '',
      'noHpIbu': noHpIbu ?? '',
      'namaWali': namaWali ?? '',
      'hubunganWali': hubunganWali ?? '',
      'noHpWali': noHpWali ?? '',
      'alamatWali': alamatWali ?? '',
    });

    // Perbarui data histori class_enrollments untuk semester aktif jika ada
    final schoolDoc = await _db.collection('schools').doc(_schoolId).get();
    final schoolData = schoolDoc.data() ?? {};
    final tahunAjaran = schoolData['tahunAjaran'] ?? '${DateTime.now().year}/${DateTime.now().year + 1}';
    final semester = schoolData['semester'] ?? 'Semester 1';
    final cleanYear = tahunAjaran.replaceAll('/', '_');
    final enrollmentId = '${studentId}_${cleanYear}_$semester';

    final enrollmentDoc = _db
        .collection('schools')
        .doc(_schoolId)
        .collection('class_enrollments')
        .doc(enrollmentId);

    final snap = await enrollmentDoc.get();
    if (snap.exists) {
      await enrollmentDoc.update({
        'nama': nama,
        'nis': nis,
      });
    }
  }

  Future<void> deleteStudent(String studentId) async {
    final snap = await _studentsRef.doc(studentId).get();
    if (snap.exists) {
      final data = snap.data();
      final uid = data?['uid'] as String?;
      await _studentsRef.doc(studentId).delete();
      if (uid != null && uid.isNotEmpty) {
        await FirebaseFirestore.instance.collection('users').doc(uid).delete();
      }
    }
  }

  /// Sinkronisasi/Backfill data histori kelas ke `class_enrollments` berdasarkan:
  /// 1. Murid aktif saat ini
  /// 2. Data nilai (grades) historis yang pernah diinput
  Future<void> backfillClassEnrollments(String schoolId) async {
    try {
      final firestore = FirebaseFirestore.instance;
      
      // 1. Dapatkan tahun ajaran & semester aktif sekolah
      final schoolDoc = await firestore.collection('schools').doc(schoolId).get();
      if (!schoolDoc.exists) return;
      final schoolData = schoolDoc.data() ?? {};
      final activeTahun = schoolData['tahunAjaran'] ?? '${DateTime.now().year}/${DateTime.now().year + 1}';
      final activeSemester = schoolData['semester'] ?? 'Semester 1';

      // 2. Backfill dari data murid aktif saat ini
      final studentsSnap = await firestore
          .collection('schools')
          .doc(schoolId)
          .collection('students')
          .get();

      final Map<String, Map<String, dynamic>> studentCache = {};
      
      for (final doc in studentsSnap.docs) {
        final data = doc.data();
        final studentId = doc.id;
        studentCache[studentId] = data;

        final classId = data['classId'] as String?;
        final className = data['className'] as String?;
        
        if (classId != null && classId.isNotEmpty) {
          final cleanYear = activeTahun.replaceAll('/', '_');
          final enrollmentId = '${studentId}_${cleanYear}_$activeSemester';
          
          await firestore
              .collection('schools')
              .doc(schoolId)
              .collection('class_enrollments')
              .doc(enrollmentId)
              .set({
            'studentId': studentId,
            'schoolId': schoolId,
            'nama': data['nama'] ?? '',
            'nis': data['nis'] ?? '',
            'classId': classId,
            'className': className ?? '',
            'tahunAjaran': activeTahun,
            'semester': activeSemester,
            'createdAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }
      }

      // 3. Backfill dari data Nilai (Grades) historis
      final gradesSnap = await firestore
          .collection('schools')
          .doc(schoolId)
          .collection('grades')
          .get();

      for (final doc in gradesSnap.docs) {
        final data = doc.data();
        final classId = data['classId'] as String?;
        final className = data['className'] as String?;
        final tahunAjaran = data['tahunAjaran'] as String?;
        final semester = data['semester'] as String?;
        final scores = data['scores'] as Map<String, dynamic>?;

        if (classId == null || classId.isEmpty || 
            tahunAjaran == null || tahunAjaran.isEmpty || 
            semester == null || semester.isEmpty || 
            scores == null || scores.isEmpty) {
          continue;
        }

        final cleanYear = tahunAjaran.replaceAll('/', '_');

        for (final studentId in scores.keys) {
          final enrollmentId = '${studentId}_${cleanYear}_$semester';
          
          // Cari nama & nis dari cache atau Firestore
          String nama = '';
          String nis = '';
          if (studentCache.containsKey(studentId)) {
            nama = studentCache[studentId]?['nama'] ?? '';
            nis = studentCache[studentId]?['nis'] ?? '';
          } else {
            final sDoc = await firestore
                .collection('schools')
                .doc(schoolId)
                .collection('students')
                .doc(studentId)
                .get();
            if (sDoc.exists) {
              final sData = sDoc.data() ?? {};
              studentCache[studentId] = sData;
              nama = sData['nama'] ?? '';
              nis = sData['nis'] ?? '';
            }
          }

          if (nama.isNotEmpty) {
            await firestore
                .collection('schools')
                .doc(schoolId)
                .collection('class_enrollments')
                .doc(enrollmentId)
                .set({
              'studentId': studentId,
              'schoolId': schoolId,
              'nama': nama,
              'nis': nis,
              'classId': classId,
              'className': className ?? '',
              'tahunAjaran': tahunAjaran,
              'semester': semester,
              'createdAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
          }
        }
      }

      // 4. Backfill dari data Absensi (Attendance) historis
      final attendanceSnap = await firestore
          .collection('schools')
          .doc(schoolId)
          .collection('attendance')
          .get();

      for (final doc in attendanceSnap.docs) {
        final data = doc.data();
        final studentId = data['studentId'] as String?;
        final classId = data['classId'] as String?;
        final className = data['className'] as String?;
        final tahunAjaran = data['tahunAjaran'] as String?;
        final semester = data['semester'] as String?;

        if (studentId == null || studentId.isEmpty ||
            classId == null || classId.isEmpty ||
            tahunAjaran == null || tahunAjaran.isEmpty ||
            semester == null || semester.isEmpty) {
          continue;
        }

        final cleanYear = tahunAjaran.replaceAll('/', '_');
        final enrollmentId = '${studentId}_${cleanYear}_$semester';

        String nama = '';
        String nis = '';
        if (studentCache.containsKey(studentId)) {
          nama = studentCache[studentId]?['nama'] ?? '';
          nis = studentCache[studentId]?['nis'] ?? '';
        } else {
          final sDoc = await firestore
              .collection('schools')
              .doc(schoolId)
              .collection('students')
              .doc(studentId)
              .get();
          if (sDoc.exists) {
            final sData = sDoc.data() ?? {};
            studentCache[studentId] = sData;
            nama = sData['nama'] ?? '';
            nis = sData['nis'] ?? '';
          }
        }

        if (nama.isNotEmpty) {
          await firestore
              .collection('schools')
              .doc(schoolId)
              .collection('class_enrollments')
              .doc(enrollmentId)
              .set({
            'studentId': studentId,
            'schoolId': schoolId,
            'nama': nama,
            'nis': nis,
            'classId': classId,
            'className': className ?? '',
            'tahunAjaran': tahunAjaran,
            'semester': semester,
            'createdAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }
      }

      debugPrint('Class enrollment backfill completed successfully for school $schoolId');
    } catch (e) {
      debugPrint('Error backfilling class enrollments: $e');
    }
  }

  /// Menghapus (mengosongkan) seluruh murid dari suatu kelas sekaligus menggunakan WriteBatch
  Future<void> emptyClass({
    required String classId,
    required String schoolId,
  }) async {
    final querySnapshot = await _db
        .collection('schools')
        .doc(schoolId)
        .collection('students')
        .where('classId', isEqualTo: classId)
        .get();

    if (querySnapshot.docs.isEmpty) return;

    final batch = _db.batch();
    for (var doc in querySnapshot.docs) {
      batch.update(doc.reference, {
        'classId': null,
        'className': null,
      });
    }
    await batch.commit();
  }

  /// Menambahkan beberapa murid sekaligus ke suatu kelas menggunakan WriteBatch dan mencatat riwayat enrollment
  Future<void> assignMultipleStudentsToClass({
    required String classId,
    required List<Map<String, String>> students,
  }) async {
    if (students.isEmpty) return;

    final classDoc = await _db
        .collection('schools')
        .doc(_schoolId)
        .collection('classes')
        .doc(classId)
        .get();

    if (!classDoc.exists) {
      throw ('Kelas tidak ditemukan');
    }

    final className = classDoc.data()?['namaKelas'] ?? '';

    // Dapatkan tahun ajaran dan semester aktif dari sekolah
    final schoolDoc = await _db.collection('schools').doc(_schoolId).get();
    final schoolData = schoolDoc.data() ?? {};
    final tahunAjaran = schoolData['tahunAjaran'] ?? '${DateTime.now().year}/${DateTime.now().year + 1}';
    final semester = schoolData['semester'] ?? 'Semester 1';
    final cleanYear = tahunAjaran.replaceAll('/', '_');

    final batch = _db.batch();

    for (var s in students) {
      final studentId = s['id']!;
      final studentName = s['nama']!;
      final studentNis = s['nis']!;

      // 1. Simpan di data murid
      batch.update(_studentsRef.doc(studentId), {
        'classId': classId,
        'className': className,
      });

      // 2. Simpan di koleksi histori class_enrollments
      final enrollmentId = '${studentId}_${cleanYear}_$semester';
      final enrollmentDocRef = _db
          .collection('schools')
          .doc(_schoolId)
          .collection('class_enrollments')
          .doc(enrollmentId);

      batch.set(enrollmentDocRef, {
        'studentId': studentId,
        'schoolId': _schoolId,
        'nama': studentName,
        'nis': studentNis,
        'classId': classId,
        'className': className,
        'tahunAjaran': tahunAjaran,
        'semester': semester,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
  }

  /// Mengosongkan murid dari semua kelas di sekolah (Format Data Kelas)
  Future<void> formatAllClasses(String schoolId) async {
    final querySnapshot = await _db
        .collection('schools')
        .doc(schoolId)
        .collection('students')
        .where('classId', isNull: false)
        .get();

    if (querySnapshot.docs.isEmpty) return;

    final batch = _db.batch();
    for (var doc in querySnapshot.docs) {
      batch.update(doc.reference, {
        'classId': null,
        'className': null,
      });
    }
    await batch.commit();
  }

  /// Meluluskan seluruh murid dalam suatu kelas (set lulus = true, classId = null)
  /// Serta menonaktifkan/mengubah status lulus akun user di koleksi users (jika ada)
  Future<void> graduateClass({
    required String classId,
    required String schoolId,
  }) async {
    final querySnapshot = await _db
        .collection('schools')
        .doc(schoolId)
        .collection('students')
        .where('classId', isEqualTo: classId)
        .get();

    if (querySnapshot.docs.isEmpty) return;

    final batch = _db.batch();

    for (var doc in querySnapshot.docs) {
      final studentData = doc.data();
      final String? uid = studentData['uid'];

      // Update student document: set lulus to true, classId to null (keep className for history display on dashboard)
      batch.update(doc.reference, {
        'lulus': true,
        'classId': null,
      });

      // Update user document: set lulus to true
      if (uid != null && uid.trim().isNotEmpty) {
        final userRef = _db.collection('users').doc(uid);
        batch.update(userRef, {
          'lulus': true,
        });
      }
    }

    await batch.commit();
  }
}

