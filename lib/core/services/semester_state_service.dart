import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Status semester saat ini.
enum SemesterStatus {
  /// Belum ada konfigurasi tanggal mulai — dianggap aktif (backward compatible).
  aktif,

  /// Sebelum tanggal mulai semester — masa liburan, input data ditolak.
  liburan,

  /// Admin telah menutup semester — input data ditolak.
  ditutup,
}

/// Singleton service yang me-listen dokumen sekolah dan menyimpan status
/// semester di memori agar tidak perlu baca Firestore pada setiap write.
class SemesterStateService {
  SemesterStateService._();

  static StreamSubscription<DocumentSnapshot>? _sub;

  static DateTime? _tanggalMulai;
  static bool _ditutup = false;

  // ── Public API ────────────────────────────────────────────────────────

  /// Panggil ini sesegera mungkin setelah login (misalnya di splash page).
  static void listen(String schoolId) {
    _sub?.cancel();
    _sub = FirebaseFirestore.instance
        .collection('schools')
        .doc(schoolId)
        .snapshots()
        .listen((doc) {
      if (!doc.exists) return;
      final data = doc.data() ?? {};
      final ts = data['tanggalMulaiSemester'];
      _tanggalMulai = ts is Timestamp ? ts.toDate() : null;
      _ditutup = (data['semesterDitutup'] as bool?) ?? false;
    });
  }

  /// Hentikan listener — panggil saat logout.
  static void dispose() {
    _sub?.cancel();
    _sub = null;
    _tanggalMulai = null;
    _ditutup = false;
  }

  /// Status semester saat ini berdasarkan nilai Firestore.
  static SemesterStatus get status {
    if (_ditutup) return SemesterStatus.ditutup;
    if (_tanggalMulai != null) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final start = DateTime(
          _tanggalMulai!.year, _tanggalMulai!.month, _tanggalMulai!.day);
      if (today.isBefore(start)) return SemesterStatus.liburan;
    }
    return SemesterStatus.aktif;
  }

  static DateTime? get tanggalMulai => _tanggalMulai;
  static bool get ditutup => _ditutup;

  /// Cek apakah input data diizinkan.
  /// Mengembalikan `null` jika OK, atau pesan error jika ditolak.
  static String? validateInput() {
    switch (status) {
      case SemesterStatus.ditutup:
        return 'Semester telah ditutup oleh Admin 🔒. '
            'Semua data absensi, nilai, dan perizinan tidak dapat diubah atau ditambahkan.';
      case SemesterStatus.liburan:
        final start = _tanggalMulai!;
        final d = start.day.toString().padLeft(2, '0');
        final m = start.month.toString().padLeft(2, '0');
        final y = start.year;
        return 'Masa liburan sekolah sedang berlangsung 🏖️. '
            'Akses input data baru akan dibuka secara otomatis pada tanggal $d/$m/$y seiring dimulainya semester baru.';
      case SemesterStatus.aktif:
        return null;
    }
  }

  /// Label status untuk ditampilkan di UI.
  static String get statusLabel {
    switch (status) {
      case SemesterStatus.aktif:
        return 'Aktif';
      case SemesterStatus.liburan:
        return 'Masa Liburan';
      case SemesterStatus.ditutup:
        return 'Ditutup';
    }
  }
}

/// Custom Exception untuk kegagalan input data akibat validasi semester.
/// Override toString() agar tidak menyertakan prefiks "Exception: " di UI.
class SemesterValidationException implements Exception {
  final String message;
  SemesterValidationException(this.message);

  @override
  String toString() => message;
}

