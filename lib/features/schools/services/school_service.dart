import 'package:cloud_firestore/cloud_firestore.dart';

class SchoolService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<Map<String, dynamic>?> getTeacherByNip({
    required String schoolId,
    required String nip,
  }) async {
    final result = await _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('teachers')
        .where('nip', isEqualTo: nip)
        .limit(1)
        .get();

    if (result.docs.isEmpty) {
      return null;
    }

    final doc = result.docs.first;
    final data = doc.data();
    data['teacherId'] = doc.id;
    return data;
  }

  Future<Map<String, dynamic>?> getStudentByNis({
    required String schoolId,
    required String nis,
  }) async {
    final result = await _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('students')
        .where('nis', isEqualTo: nis)
        .limit(1)
        .get();

    if (result.docs.isEmpty) {
      return null;
    }

    final doc = result.docs.first;
    final data = doc.data();
    data['studentId'] = doc.id;
    data['docId'] = doc.id;
    return data;
  }

  Future<void> updateTeacherRegistration({
    required String schoolId,
    required String teacherId,
    required String uid,
    required String email,
    required String nama,
  }) async {
    await _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('teachers')
        .doc(teacherId)
        .update({'uid': uid, 'email': email, 'sudahRegister': true});
  }

  Future<void> updateStudentRegistration({
    required String schoolId,
    required String studentId,
    required String uid,
    required String email,
    required String nama,
  }) async {
    await _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('students')
        .doc(studentId)
        .update({'uid': uid, 'email': email, 'sudahRegister': true});
  }

  Future<void> createSchool({
    required String schoolId,
    required String namaSekolah,
    required String domain,
    required String kodeAdmin,
    required String plan,
  }) async {
    final docRef = _firestore.collection('schools').doc(domain);
    final doc = await docRef.get();

    if (doc.exists) {
      throw ('Domain sudah digunakan');
    }

    await docRef.set({
      'schoolId': schoolId,
      'namaSekolah': namaSekolah,
      'domain': domain,
      'kodeAdmin': kodeAdmin,
      'plan': plan,
      'aktif': true,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<Map<String, dynamic>?> getSchoolByDomain(String domain) async {
    final doc = await _firestore.collection('schools').doc(domain).get();
    if (!doc.exists) return null;
    return doc.data();
  }

  // Ambil semua sekolah untuk dropdown di halaman register guru/murid
  Future<List<Map<String, dynamic>>> getAllSchools() async {
    final snapshot = await _firestore
        .collection('schools')
        .where('aktif', isEqualTo: true)
        .get();

    return snapshot.docs.map((doc) => doc.data()).toList();
  }

  // Validasi NIP guru: pastikan terdaftar di sekolah tersebut dan aktif
  Future<bool> validateTeacher({
    required String schoolId,
    required String nip,
  }) async {
    final snapshot = await _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('teachers')
        .where('nip', isEqualTo: nip)
        .where('aktif', isEqualTo: true)
        .get();

    return snapshot.docs.isNotEmpty;
  }

  // Validasi NIS murid: pastikan terdaftar di sekolah tersebut dan aktif
  Future<bool> validateStudent({
    required String schoolId,
    required String nis,
  }) async {
    final snapshot = await _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('students')
        .where('nis', isEqualTo: nis)
        .where('aktif', isEqualTo: true)
        .get();

    return snapshot.docs.isNotEmpty;
  }

  // Stream all schools for super admin dashboard
  Stream<List<Map<String, dynamic>>> getSchoolsStream() {
    return _firestore.collection('schools').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    });
  }

  // Update subscription package plan of a school
  Future<void> updateSchoolPlan({
    required String domain,
    required String plan,
  }) async {
    await _firestore.collection('schools').doc(domain).update({
      'plan': plan,
    });
  }

  // Delete school and associated admin users
  Future<void> deleteSchool(String domain) async {
    await _firestore.collection('schools').doc(domain).delete();

    // Delete users associated with this school (school_admin, teacher, student, parent)
    final usersSnapshot = await _firestore
        .collection('users')
        .where('schoolId', isEqualTo: domain)
        .get();

    for (var doc in usersSnapshot.docs) {
      await doc.reference.delete();
    }
  }

  // Get admin user for a school domain
  Future<Map<String, dynamic>?> getSchoolAdmin(String domain) async {
    final result = await _firestore
        .collection('users')
        .where('schoolId', isEqualTo: domain)
        .where('role', isEqualTo: 'school_admin')
        .limit(1)
        .get();

    if (result.docs.isEmpty) {
      return null;
    }

    final doc = result.docs.first;
    final data = doc.data();
    data['uid'] = doc.id;
    return data;
  }

  // Update bypass schedule lock flag
  Future<void> updateBypassScheduleLock({
    required String domain,
    required bool allowBypass,
  }) async {
    await _firestore.collection('schools').doc(domain).update({
      'allowBypassScheduleLock': allowBypass,
    });
  }

  // Update import excel teacher toggle
  Future<void> updateImportExcelTeacherToggle({
    required String domain,
    required bool enabled,
  }) async {
    await _firestore.collection('schools').doc(domain).update({
      'enableImportExcelTeacher': enabled,
    });
  }

  // Update import excel student toggle
  Future<void> updateImportExcelStudentToggle({
    required String domain,
    required bool enabled,
  }) async {
    await _firestore.collection('schools').doc(domain).update({
      'enableImportExcelStudent': enabled,
    });
  }

  // Update schedule features toggle
  Future<void> updateScheduleFeaturesToggle({
    required String domain,
    required bool enabled,
  }) async {
    await _firestore.collection('schools').doc(domain).update({
      'enableScheduleFeatures': enabled,
    });
  }

  // Update student attendance recap toggle
  Future<void> updateStudentAttendanceRecapToggle({
    required String domain,
    required bool enabled,
  }) async {
    await _firestore.collection('schools').doc(domain).update({
      'enableStudentAttendanceRecap': enabled,
    });
  }

  // Update teacher attendance recap toggle
  Future<void> updateTeacherAttendanceRecapToggle({
    required String domain,
    required bool enabled,
  }) async {
    await _firestore.collection('schools').doc(domain).update({
      'enableTeacherAttendanceRecap': enabled,
    });
  }

  // Update e-rapor toggle
  Future<void> updateERaporToggle({
    required String domain,
    required bool enabled,
  }) async {
    await _firestore.collection('schools').doc(domain).update({
      'enableERapor': enabled,
    });
  }

  // Update realtime control toggle
  Future<void> updateRealtimeControlToggle({
    required String domain,
    required bool enabled,
  }) async {
    await _firestore.collection('schools').doc(domain).update({
      'enableRealtimeControl': enabled,
    });
  }

  // Update online exam toggle
  Future<void> updateOnlineExamToggle({
    required String domain,
    required bool enabled,
  }) async {
    await _firestore.collection('schools').doc(domain).update({
      'enableOnlineExam': enabled,
    });
  }

  // Update chat toggle
  Future<void> updateChatToggle({
    required String domain,
    required bool enabled,
  }) async {
    await _firestore.collection('schools').doc(domain).update({
      'enableChat': enabled,
    });
  }

  // Update student leave request toggle
  Future<void> updateStudentLeaveRequestToggle({
    required String domain,
    required bool enabled,
  }) async {
    await _firestore.collection('schools').doc(domain).update({
      'enableStudentLeaveRequest': enabled,
    });
  }

  // Update school quotas
  Future<void> updateSchoolQuotas({
    required String domain,
    required int? teacherQuota,
    required int? studentQuota,
  }) async {
    // 1. Validasi kuota guru
    if (teacherQuota != null) {
      final countSnap = await _firestore
          .collection('schools')
          .doc(domain)
          .collection('teachers')
          .count()
          .get();
      final currentTeachers = countSnap.count ?? 0;
      if (teacherQuota < currentTeachers) {
        throw Exception('Tidak dapat mengubah kuota guru di bawah jumlah guru terdaftar saat ini ($currentTeachers guru).');
      }
    }

    // 2. Validasi kuota murid aktif
    if (studentQuota != null) {
      final totalSnap = await _firestore
          .collection('schools')
          .doc(domain)
          .collection('students')
          .count()
          .get();
      final totalCount = totalSnap.count ?? 0;

      final graduatedSnap = await _firestore
          .collection('schools')
          .doc(domain)
          .collection('students')
          .where('lulus', isEqualTo: true)
          .count()
          .get();
      final graduatedCount = graduatedSnap.count ?? 0;

      final activeStudents = totalCount - graduatedCount;

      if (studentQuota < activeStudents) {
        throw Exception('Tidak dapat mengubah kuota murid di bawah jumlah murid aktif saat ini ($activeStudents murid).');
      }
    }

    await _firestore.collection('schools').doc(domain).update({
      'teacherQuota': teacherQuota,
      'studentQuota': studentQuota,
    });
  }
}
