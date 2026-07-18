import 'package:cloud_firestore/cloud_firestore.dart';

class RaporService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Mendapatkan referensi koleksi laporan siswa
  CollectionReference<Map<String, dynamic>> _reportsRef(String schoolId) =>
      _firestore.collection('schools').doc(schoolId).collection('student_reports');

  /// Mendapatkan referensi dokumen pengaturan PDF Rapor
  DocumentReference<Map<String, dynamic>> _settingsRef(String schoolId) =>
      _firestore.collection('schools').doc(schoolId).collection('rapor_settings').doc('config');

  /// Menyimpan pengaturan PDF Rapor
  Future<void> saveRaporPdfSettings(String schoolId, Map<String, dynamic> settingsMap) async {
    await _settingsRef(schoolId).set(settingsMap, SetOptions(merge: true));
  }

  /// Mengambil pengaturan PDF Rapor
  Future<DocumentSnapshot<Map<String, dynamic>>> getRaporPdfSettings(String schoolId) async {
    return await _settingsRef(schoolId).get();
  }

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

  /// Menghitung rekap ketidakhadiran dari koleksi daily_attendance.
  /// Otomatis menghitung "Alfa" untuk hari-hari sekolah (Senin-Jumat)
  /// yang tidak memiliki catatan absensi, terhitung dari tanggal mulai semester
  /// hingga hari ini (atau sampai semester ditutup jika sudah tutup).
  Future<Map<String, int>> calculateAttendanceStats({
    required String schoolId,
    required String studentId,
    required String tahunAjaran,
    required String semester,
  }) async {
    try {
      // 1. Ambil metadata tanggal mulai & tutup semester dari dokumen sekolah
      final schoolDoc = await _firestore.collection('schools').doc(schoolId).get();
      DateTime? tanggalMulai;
      DateTime? tanggalTutup;

      if (schoolDoc.exists) {
        final schoolData = schoolDoc.data() ?? {};
        final tsMulai = schoolData['tanggalMulaiSemester'];
        if (tsMulai is Timestamp) {
          tanggalMulai = tsMulai.toDate();
        }
        final tsTutup = schoolData['tanggalSemesterDitutup'];
        if (tsTutup is Timestamp) {
          tanggalTutup = tsTutup.toDate();
        }
      }

      // 2. Ambil semua absensi harian yang ada
      final snapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('daily_attendance')
          .where('studentId', isEqualTo: studentId)
          .where('tahunAjaran', isEqualTo: tahunAjaran)
          .where('semester', isEqualTo: semester)
          .get();

      final Map<String, String> dateToStatus = {};
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final date = data['date']?.toString() ?? '';
        final status = data['status']?.toString().toLowerCase() ?? '';
        if (date.isNotEmpty) {
          dateToStatus[date] = status;
        }
      }

      int sakit = 0;
      int izin = 0;
      int alpa = 0;
      int hadir = 0;

      // 3. Jika tanggal mulai semester diset, hitung secara otomatis per hari sekolah
      if (tanggalMulai != null) {
        final start = DateTime(tanggalMulai.year, tanggalMulai.month, tanggalMulai.day);
        final now = DateTime.now();
        final end = tanggalTutup != null
            ? DateTime(tanggalTutup.year, tanggalTutup.month, tanggalTutup.day)
            : DateTime(now.year, now.month, now.day);

        DateTime current = start;
        while (!current.isAfter(end)) {
          // Hanya hitung hari sekolah (Senin - Jumat)
          if (current.weekday != DateTime.saturday && current.weekday != DateTime.sunday) {
            final dateStr = '${current.year}-${current.month.toString().padLeft(2, '0')}-${current.day.toString().padLeft(2, '0')}';
            
            if (dateToStatus.containsKey(dateStr)) {
              final status = dateToStatus[dateStr]!;
              if (status == 'sakit') {
                sakit++;
              } else if (status == 'izin') {
                izin++;
              } else if (status == 'alpa' || status == 'absen' || status == 'tanpa keterangan') {
                alpa++;
              } else if (status == 'hadir' || status == 'terlambat') {
                hadir++;
              }
            } else {
              // Jika tidak ada record absensi sama sekali pada hari sekolah -> Auto Alfa!
              alpa++;
            }
          }
          // Tambah 1 hari secara aman
          current = DateTime(current.year, current.month, current.day + 1);
        }
      } else {
        // Fallback jika tanggalMulaiSemester belum di-set (hitung manual dari data yang ada saja)
        for (final status in dateToStatus.values) {
          if (status == 'sakit') {
            sakit++;
          } else if (status == 'izin') {
            izin++;
          } else if (status == 'alpa' || status == 'absen' || status == 'tanpa keterangan') {
            alpa++;
          } else if (status == 'hadir' || status == 'terlambat') {
            hadir++;
          }
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
