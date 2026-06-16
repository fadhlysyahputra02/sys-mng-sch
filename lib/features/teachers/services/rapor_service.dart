import 'package:cloud_firestore/cloud_firestore.dart';

class RaporService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Mendapatkan referensi koleksi laporan siswa
  CollectionReference<Map<String, dynamic>> _reportsRef(String schoolId) =>
      _firestore.collection('schools').doc(schoolId).collection('student_reports');

  /// Menyimpan data kustom rapor siswa
  Future<void> saveStudentReport({
    required String schoolId,
    required String studentId,
    required String tahunAjaran,
    required String semester,
    required List<Map<String, dynamic>> attitudeAspects,
    required int sakit,
    required int izin,
    required int alpa,
    required String catatanWali,
    required String updatedBy,
  }) async {
    final cleanYear = tahunAjaran.replaceAll('/', '-');
    final docId = '${studentId}_${cleanYear}_$semester';

    // Extract default/legacy aspects for backward compatibility if present in the dynamic list
    String spiritualPredikat = 'B';
    String spiritualDeskripsi = '';
    String sosialPredikat = 'B';
    String sosialDeskripsi = '';

    for (final aspect in attitudeAspects) {
      final name = aspect['name']?.toString().toLowerCase() ?? '';
      if (name.contains('spiritual')) {
        spiritualPredikat = aspect['predikat']?.toString() ?? 'B';
        spiritualDeskripsi = aspect['deskripsi']?.toString() ?? '';
      } else if (name.contains('sosial')) {
        sosialPredikat = aspect['predikat']?.toString() ?? 'B';
        sosialDeskripsi = aspect['deskripsi']?.toString() ?? '';
      }
    }

    await _reportsRef(schoolId).doc(docId).set({
      'studentId': studentId,
      'tahunAjaran': tahunAjaran,
      'semester': semester,
      'attitudeAspects': attitudeAspects,
      'sikapSpiritualPredikat': spiritualPredikat,
      'sikapSpiritualDeskripsi': spiritualDeskripsi,
      'sikapSosialPredikat': sosialPredikat,
      'sikapSosialDeskripsi': sosialDeskripsi,
      'sakit': sakit,
      'izin': izin,
      'alpa': alpa,
      'catatanWali': catatanWali,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': updatedBy,
    }, SetOptions(merge: true));
  }

  /// Mengambil data kustom rapor siswa (Stream)
  Stream<DocumentSnapshot<Map<String, dynamic>>> getStudentReportStream({
    required String schoolId,
    required String studentId,
    required String tahunAjaran,
    required String semester,
  }) {
    final cleanYear = tahunAjaran.replaceAll('/', '-');
    final docId = '${studentId}_${cleanYear}_$semester';
    return _reportsRef(schoolId).doc(docId).snapshots();
  }

  /// Mengambil data kustom rapor siswa (Future)
  Future<DocumentSnapshot<Map<String, dynamic>>> getStudentReport({
    required String schoolId,
    required String studentId,
    required String tahunAjaran,
    required String semester,
  }) async {
    final cleanYear = tahunAjaran.replaceAll('/', '-');
    final docId = '${studentId}_${cleanYear}_$semester';
    return await _reportsRef(schoolId).doc(docId).get();
  }

  /// Menghitung rekap data absensi dari Firestore secara realtime / cepat
  /// Format tanggal: YYYY-MM-DD
  Future<Map<String, int>> calculateAttendanceStats({
    required String schoolId,
    required String studentId,
    required String tahunAjaran,
    required String semester,
  }) async {
    try {
      final snapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('attendance')
          .where('studentId', isEqualTo: studentId)
          .where('tahunAjaran', isEqualTo: tahunAjaran)
          .where('semester', isEqualTo: semester)
          .get();

      int sakit = 0;
      int izin = 0;
      int alpa = 0;
      int hadir = 0;

      for (final doc in snapshot.docs) {
        final status = doc.data()['status']?.toString().toLowerCase() ?? '';
        if (status == 'sakit') {
          sakit++;
        } else if (status == 'izin') {
          izin++;
        } else if (status == 'alpa' || status == 'absen' || status == 'tanpa keterangan') {
          alpa++;
        } else if (status == 'hadir') {
          hadir++;
        }
      }

      return {
        'sakit': sakit,
        'izin': izin,
        'alpa': alpa,
        'hadir': hadir,
      };
    } catch (e) {
      return {
        'sakit': 0,
        'izin': 0,
        'alpa': 0,
        'hadir': 0,
      };
    }
  }
}
