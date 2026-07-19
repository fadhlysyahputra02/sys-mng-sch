import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart' as fp;
import 'package:flutter/foundation.dart';
import '../../../../core/services/session_service.dart';
import 'file_helper.dart';

class ExcelImportResult {
  final int successCount;
  final int duplicateCount;
  final int failedCount;
  final List<String> errors;

  ExcelImportResult({
    required this.successCount,
    required this.duplicateCount,
    required this.failedCount,
    required this.errors,
  });
}

class ExcelImportService {
  final _db = FirebaseFirestore.instance;

  String _cleanValue(dynamic val) {
    if (val == null) return '';
    String str = val.toString().trim();
    if (str.endsWith('.0')) {
      str = str.substring(0, str.length - 2);
    }
    return str;
  }

  String _parseGender(String val) {
    final lower = val.toLowerCase().trim();
    if (lower == 'l' || lower == 'laki-laki' || lower == 'laki') {
      return 'Laki-laki';
    } else if (lower == 'p' || lower == 'perempuan') {
      return 'Perempuan';
    }
    return '';
  }

  Future<ExcelImportResult?> importTeachers(
    String schoolId, {
    void Function()? onFileSelected,
    void Function(int current, int total)? onProgress,
  }) async {
    try {
      fp.FilePickerResult? result = await fp.FilePicker.pickFiles(
        type: fp.FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
        withData: true,
      );

      if (result == null) return null;

      final file = result.files.single;
      Uint8List bytes;
      if (kIsWeb) {
        if (file.bytes == null) return null;
        bytes = file.bytes!;
      } else {
        if (file.bytes != null) {
          bytes = file.bytes!;
        } else if (file.path != null) {
          bytes = FileHelper.readBytes(file.path!);
        } else {
          return null;
        }
      }

      onFileSelected?.call();
      final excel = Excel.decodeBytes(bytes);

      List<Map<String, dynamic>> validatedTeachers = [];
      List<String> errors = [];
      Set<String> fileNips = {};

      // The new template has 5 header rows (title, title, empty, note, columns).
      // Data starts from row index 5 (0-based) = Excel row 6.
      const int dataStartRowIndex = 5;

      int totalRows = 0;
      for (var table in excel.tables.keys) {
        var sheet = excel.tables[table];
        if (sheet != null && sheet.maxRows > dataStartRowIndex) {
          totalRows += sheet.maxRows - dataStartRowIndex;
        }
      }

      int processed = 0;

      // Pass 1: Validation — read all 35 columns
      for (var table in excel.tables.keys) {
        var sheet = excel.tables[table];
        if (sheet == null) continue;

        for (int i = dataStartRowIndex; i < sheet.maxRows; i++) {
          var row = sheet.rows[i];
          processed++;
          onProgress?.call(processed, totalRows * 2);
          if (row.isEmpty) continue;

          String col_(int idx) => row.length > idx ? _cleanValue(row[idx]?.value) : '';

          // --- Read all columns ---
          final nama            = col_(0);   // A
          final nip             = col_(1);   // B

          // Skip header row if accidentally read
          if (nama == 'Nama Lengkap *' || nama == 'Nama Lengkap') continue;
          final nuptk           = col_(2);   // C
          final noPegawai       = col_(3);   // D
          final gelarDepan      = col_(4);   // E
          final gelarBelakang   = col_(5);   // F
          final genderRaw       = col_(6);   // G
          final tempatLahir     = col_(7);   // H
          final tanggalLahir    = col_(8);   // I
          final agamaRaw        = col_(9);   // J
          final statusPernikahan= col_(10);  // K
          final kewarganegaraanRaw = col_(11); // L
          final golonganDarah   = col_(12);  // M
          final alamat          = col_(13);  // N
          final noHp            = col_(14);  // O
          final kontakDarurat   = col_(15);  // P
          final nik             = col_(16);  // Q
          final npwp            = col_(17);  // R
          final bpjsKesehatan   = col_(18);  // S
          final bpjsKetenagakerjaan = col_(19); // T
          final nomorKk         = col_(20);  // U
          final nomorRekening   = col_(21);  // V
          final namaBank        = col_(22);  // W
          final statusGuruRaw   = col_(23);  // X
          final jabatan         = col_(24);  // Y
          final pangkatGolongan = col_(25);  // Z
          final tmt             = col_(26);  // AA
          final tanggalBergabung= col_(27);  // AB
          final masaKerja       = col_(28);  // AC
          final pendidikanTerakhir = col_(29); // AD
          final jurusan         = col_(30);  // AE
          final universitas     = col_(31);  // AF
          final tahunLulus      = col_(32);  // AG
          final sertifikasiGuru = col_(33);  // AH
          final bidangSertifikasi = col_(34); // AI

          // Skip truly empty rows
          if (nama.isEmpty && nip.isEmpty) continue;

          final int excelRow = i + 1;

          // --- Validate mandatory fields ---
          if (nama.isEmpty) {
            errors.add('Baris $excelRow: Nama guru tidak boleh kosong.');
            continue;
          }
          if (nip.isEmpty) {
            errors.add('Baris $excelRow (Nama: $nama): NIP tidak boleh kosong.');
            continue;
          }
          if (tempatLahir.isEmpty) {
            errors.add('Baris $excelRow (Nama: $nama): Tempat Lahir tidak boleh kosong.');
            continue;
          }
          if (tanggalLahir.isEmpty) {
            errors.add('Baris $excelRow (Nama: $nama): Tanggal Lahir tidak boleh kosong.');
            continue;
          }
          if (noHp.isEmpty) {
            errors.add('Baris $excelRow (Nama: $nama): Nomor HP tidak boleh kosong.');
            continue;
          }
          if (nik.isEmpty) {
            errors.add('Baris $excelRow (Nama: $nama): NIK tidak boleh kosong.');
            continue;
          }
          if (nomorKk.isEmpty) {
            errors.add('Baris $excelRow (Nama: $nama): Nomor KK tidak boleh kosong.');
            continue;
          }
          if (pendidikanTerakhir.isEmpty) {
            errors.add('Baris $excelRow (Nama: $nama): Pendidikan Terakhir tidak boleh kosong.');
            continue;
          }

          // --- Validate dropdown values ---
          final gender = _parseGender(genderRaw);
          if (genderRaw.isEmpty) {
            errors.add('Baris $excelRow (Nama: $nama): Jenis Kelamin tidak boleh kosong (harus Laki-laki atau Perempuan).');
            continue;
          }
          if (gender.isEmpty) {
            errors.add('Baris $excelRow (Nama: $nama): Jenis Kelamin "$genderRaw" tidak valid (gunakan dropdown: Laki-laki / Perempuan).');
            continue;
          }

          const validAgama = ['Islam', 'Kristen', 'Katolik', 'Hindu', 'Buddha', 'Konghucu'];
          if (agamaRaw.isEmpty) {
            errors.add('Baris $excelRow (Nama: $nama): Agama tidak boleh kosong.');
            continue;
          }
          if (!validAgama.contains(agamaRaw)) {
            errors.add('Baris $excelRow (Nama: $nama): Agama "$agamaRaw" tidak valid. Pilih dari: ${validAgama.join(", ")}.');
            continue;
          }

          const validKewarganegaraan = ['WNI', 'WNA'];
          if (kewarganegaraanRaw.isEmpty) {
            errors.add('Baris $excelRow (Nama: $nama): Kewarganegaraan tidak boleh kosong.');
            continue;
          }
          if (!validKewarganegaraan.contains(kewarganegaraanRaw)) {
            errors.add('Baris $excelRow (Nama: $nama): Kewarganegaraan "$kewarganegaraanRaw" tidak valid (WNI / WNA).');
            continue;
          }

          // --- Check NIP duplicate within file ---
          if (fileNips.contains(nip)) {
            errors.add('Baris $excelRow (Nama: $nama, NIP: $nip): NIP duplikat di dalam file Excel.');
            continue;
          }
          fileNips.add(nip);

          // --- Check NIP duplicate in Firestore ---
          final existing = await _db
              .collection('schools').doc(schoolId).collection('teachers')
              .where('nip', isEqualTo: nip).get();
          if (existing.docs.isNotEmpty) {
            final existingName = existing.docs.first.data()['nama'] ?? 'Guru Lain';
            errors.add('Baris $excelRow (Nama: $nama, NIP: $nip): NIP sudah terdaftar atas nama "$existingName".');
            continue;
          }

          // Normalise optional dropdown fields
          const validStatus = ['Tetap', 'Honorer', 'PPPK', 'PNS', 'Kontrak'];
          final statusGuru = validStatus.contains(statusGuruRaw) ? statusGuruRaw : '';
          const validStatusPernikahan = ['Belum Menikah', 'Menikah', 'Duda/Janda'];
          final statusPernikahanFinal = validStatusPernikahan.contains(statusPernikahan) ? statusPernikahan : '';
          const validGolDarah = ['A', 'B', 'AB', 'O', 'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];
          final golonganDarahFinal = validGolDarah.contains(golonganDarah) ? golonganDarah : '';

          validatedTeachers.add({
            'nama': nama, 'nip': nip, 'nuptk': nuptk,
            'noPegawai': noPegawai, 'gelarDepan': gelarDepan, 'gelarBelakang': gelarBelakang,
            'gender': gender, 'tempatLahir': tempatLahir, 'tanggalLahir': tanggalLahir,
            'agama': agamaRaw, 'statusPernikahan': statusPernikahanFinal,
            'kewarganegaraan': kewarganegaraanRaw, 'golonganDarah': golonganDarahFinal,
            'alamat': alamat, 'noHp': noHp, 'kontakDarurat': kontakDarurat,
            'nik': nik, 'npwp': npwp, 'bpjsKesehatan': bpjsKesehatan,
            'bpjsKetenagakerjaan': bpjsKetenagakerjaan, 'nomorKk': nomorKk,
            'nomorRekening': nomorRekening, 'namaBank': namaBank,
            'statusGuru': statusGuru, 'jabatan': jabatan, 'pangkatGolongan': pangkatGolongan,
            'tmt': tmt, 'tanggalBergabung': tanggalBergabung, 'masaKerja': masaKerja,
            'pendidikanTerakhir': pendidikanTerakhir, 'jurusan': jurusan,
            'universitas': universitas, 'tahunLulus': tahunLulus,
            'sertifikasiGuru': sertifikasiGuru, 'bidangSertifikasi': bidangSertifikasi,
          });
        }
      }

      if (errors.isNotEmpty) {
        return ExcelImportResult(
          successCount: 0, duplicateCount: 0,
          failedCount: errors.length, errors: errors,
        );
      }

      // Cek kuota guru
      final schoolDoc = await _db.collection('schools').doc(schoolId).get();
      if (schoolDoc.exists) {
        final teacherQuota = schoolDoc.data()?['teacherQuota'] as int?;
        if (teacherQuota != null && teacherQuota > 0) {
          final countSnap = await _db.collection('schools').doc(schoolId)
              .collection('teachers').count().get();
          final currentCount = countSnap.count ?? 0;
          if (currentCount + validatedTeachers.length > teacherQuota) {
            final slotsLeft = teacherQuota - currentCount;
            errors.add(
              '🔒 Batas kuota Guru tercapai!\n'
              '   • Kapasitas: $teacherQuota guru\n'
              '   • Terdaftar saat ini: $currentCount guru\n'
              '   • Slot tersisa: $slotsLeft slot\n'
              '   • Mencoba mengimpor: ${validatedTeachers.length} guru\n\n'
              '   Kurangi jumlah data atau minta Super Admin meningkatkan kuota.',
            );
            return ExcelImportResult(
              successCount: 0, duplicateCount: 0,
              failedCount: errors.length, errors: errors,
            );
          }
        }
      }

      // Pass 2: Insert all to Firestore
      int success = 0;
      for (int i = 0; i < validatedTeachers.length; i++) {
        final t = validatedTeachers[i];
        final docRef = _db.collection('schools').doc(schoolId).collection('teachers').doc();
        await docRef.set({
          'teacherId': docRef.id,
          'schoolId': schoolId,
          'uid': '', 'email': '',
          ...t,
          'aktif': true,
          'sudahRegister': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
        success++;
        onProgress?.call(totalRows + success, totalRows * 2);
      }

      return ExcelImportResult(
        successCount: success, duplicateCount: 0,
        failedCount: 0, errors: [],
      );
    } catch (e) {
      debugPrint('Error importing teachers: $e');
      return ExcelImportResult(
        successCount: 0, duplicateCount: 0,
        failedCount: 1,
        errors: ['Terjadi kesalahan saat memproses file: $e'],
      );
    }
  }


  Future<ExcelImportResult?> importStudents(
    String schoolId, {
    void Function()? onFileSelected,
    void Function(int current, int total)? onProgress,
  }) async {
    try {
      fp.FilePickerResult? result = await fp.FilePicker.pickFiles(
        type: fp.FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
        withData: true,
      );

      if (result == null) {
        return null;
      }

      final file = result.files.single;
      Uint8List bytes;
      if (kIsWeb) {
        if (file.bytes == null) return null;
        bytes = file.bytes!;
      } else {
        if (file.bytes != null) {
          bytes = file.bytes!;
        } else if (file.path != null) {
          bytes = FileHelper.readBytes(file.path!);
        } else {
          return null;
        }
      }

      onFileSelected?.call();
      final excel = Excel.decodeBytes(bytes);

      List<Map<String, dynamic>> validatedStudents = [];
      List<String> errors = [];
      Set<String> fileNiss = {};

      int totalRows = 0;
      for (var table in excel.tables.keys) {
        var sheet = excel.tables[table];
        if (sheet != null) {
          totalRows += (sheet.maxRows > 1) ? (sheet.maxRows - 1) : 0;
        }
      }

      int processed = 0;

      // Pass 1: Validation
      for (var table in excel.tables.keys) {
        var sheet = excel.tables[table];
        if (sheet == null) continue;

        // Pada template baru, baris 0-2 adalah header/kosong, baris 3 instruksi, baris 4 judul kolom
        // Data dimulai pada baris 5 (index 5)
        for (int i = 5; i < sheet.maxRows; i++) {
          var row = sheet.rows[i];
          processed++;
          onProgress?.call(processed, totalRows * 2);
          if (row.isEmpty) continue;

          final nama = row.isNotEmpty ? _cleanValue(row[0]?.value) : '';
          final nis = row.length > 1 ? _cleanValue(row[1]?.value) : '';

          // Skip header row if accidentally read
          if (nama == 'Nama Lengkap *' || nama == 'Nama Lengkap') continue;
          final nisn = row.length > 2 ? _cleanValue(row[2]?.value) : '';
          final genderRaw = row.length > 3 ? _cleanValue(row[3]?.value) : '';
          final gender = _parseGender(genderRaw);
          final tempatLahir = row.length > 4 ? _cleanValue(row[4]?.value) : '';
          final tanggalLahir = row.length > 5 ? _cleanValue(row[5]?.value) : '';
          final agama = row.length > 6 ? _cleanValue(row[6]?.value) : '';
          final kewarganegaraan = row.length > 7 ? _cleanValue(row[7]?.value) : '';
          final alamat = row.length > 8 ? _cleanValue(row[8]?.value) : '';
          final noHp = row.length > 9 ? _cleanValue(row[9]?.value) : '';
          final angkatan = row.length > 10 ? _cleanValue(row[10]?.value) : '';
          final jalurMasuk = row.length > 11 ? _cleanValue(row[11]?.value) : '';
          final tanggalDiterima = row.length > 12 ? _cleanValue(row[12]?.value) : '';
          final namaAyah = row.length > 13 ? _cleanValue(row[13]?.value) : '';
          final nikAyah = row.length > 14 ? _cleanValue(row[14]?.value) : '';
          final pekerjaanAyah = row.length > 15 ? _cleanValue(row[15]?.value) : '';
          final pendidikanAyah = row.length > 16 ? _cleanValue(row[16]?.value) : '';
          final noHpAyah = row.length > 17 ? _cleanValue(row[17]?.value) : '';
          final namaIbu = row.length > 18 ? _cleanValue(row[18]?.value) : '';
          final nikIbu = row.length > 19 ? _cleanValue(row[19]?.value) : '';
          final pekerjaanIbu = row.length > 20 ? _cleanValue(row[20]?.value) : '';
          final pendidikanIbu = row.length > 21 ? _cleanValue(row[21]?.value) : '';
          final noHpIbu = row.length > 22 ? _cleanValue(row[22]?.value) : '';
          final namaWali = row.length > 23 ? _cleanValue(row[23]?.value) : '';
          final hubunganWali = row.length > 24 ? _cleanValue(row[24]?.value) : '';
          final noHpWali = row.length > 25 ? _cleanValue(row[25]?.value) : '';
          final alamatWali = row.length > 26 ? _cleanValue(row[26]?.value) : '';

          // Skip completely empty rows silently
          if (nama.isEmpty && nis.isEmpty) {
            continue;
          }

          if (nama.isEmpty) {
            errors.add('Baris ${i + 1} (NIS: ${nis.isEmpty ? "-" : nis}): Nama siswa tidak boleh kosong.');
            continue;
          }

          if (nis.isEmpty) {
            errors.add('Baris ${i + 1} (Nama: $nama): NIS tidak boleh kosong.');
            continue;
          }

          if (tempatLahir.isEmpty) {
            errors.add('Baris ${i + 1} (Nama: $nama, NIS: $nis): Tempat Lahir tidak boleh kosong (wajib diisi).');
            continue;
          }

          if (agama.isEmpty) {
            errors.add('Baris ${i + 1} (Nama: $nama, NIS: $nis): Agama tidak boleh kosong (wajib diisi).');
            continue;
          }

          if (fileNiss.contains(nis)) {
            errors.add('Baris ${i + 1} (Nama: $nama, NIS: $nis): NIS duplikat di dalam file Excel.');
            continue;
          }
          fileNiss.add(nis);

          // Check if NIS is registered in Firestore
          final existing = await _db
              .collection('schools')
              .doc(schoolId)
              .collection('students')
              .where('nis', isEqualTo: nis)
              .get();

          if (existing.docs.isNotEmpty) {
            final existingName = existing.docs.first.data()['nama'] ?? 'Siswa Lain';
            errors.add('Baris ${i + 1} (Nama: $nama, NIS: $nis): NIS sudah terdaftar di database atas nama "$existingName".');
            continue;
          }

          if (genderRaw.isNotEmpty && gender.isEmpty) {
            errors.add('Baris ${i + 1} (Nama: $nama, NIS: $nis): Jenis Kelamin "$genderRaw" tidak valid (silakan pilih Laki-laki / Perempuan dari Dropdown).');
            continue;
          }

          validatedStudents.add({
            'nama': nama,
            'nis': nis,
            'nisn': nisn,
            'gender': gender,
            'tempatLahir': tempatLahir,
            'tanggalLahir': tanggalLahir,
            'agama': agama,
            'kewarganegaraan': kewarganegaraan,
            'alamat': alamat,
            'noHp': noHp,
            'angkatan': angkatan,
            'jalurMasuk': jalurMasuk,
            'tanggalDiterima': tanggalDiterima,
            'namaAyah': namaAyah,
            'nikAyah': nikAyah,
            'pekerjaanAyah': pekerjaanAyah,
            'pendidikanAyah': pendidikanAyah,
            'noHpAyah': noHpAyah,
            'namaIbu': namaIbu,
            'nikIbu': nikIbu,
            'pekerjaanIbu': pekerjaanIbu,
            'pendidikanIbu': pendidikanIbu,
            'noHpIbu': noHpIbu,
            'namaWali': namaWali,
            'hubunganWali': hubunganWali,
            'noHpWali': noHpWali,
            'alamatWali': alamatWali,
          });
        }
      }

      // If there are any validation errors, abort the entire process and return failures
      if (errors.isNotEmpty) {
        return ExcelImportResult(
          successCount: 0,
          duplicateCount: 0,
          failedCount: errors.length,
          errors: errors,
        );
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

          if (activeCount + validatedStudents.length > studentQuota) {
            final slotsLeft = studentQuota - activeCount;
            errors.add(
              '🔒 Batas kuota Murid aktif tercapai!\n'
              '   • Kapasitas: $studentQuota murid aktif\n'
              '   • Aktif saat ini: $activeCount murid\n'
              '   • Slot tersisa: $slotsLeft slot\n'
              '   • Mencoba mengimpor: ${validatedStudents.length} murid\n\n'
              '   Kurangi jumlah data di file Excel atau minta Super Admin untuk meningkatkan kuota.',
            );
            return ExcelImportResult(
              successCount: 0,
              duplicateCount: 0,
              failedCount: errors.length,
              errors: errors,
            );
          }
        }
      }

      // Pass 2: Firestore Insertions
      int success = 0;
      for (int i = 0; i < validatedStudents.length; i++) {
        final studentData = validatedStudents[i];
        final docRef = _db
            .collection('schools')
            .doc(schoolId)
            .collection('students')
            .doc();

        await docRef.set({
          'studentId': docRef.id,
          'schoolId': schoolId,
          'uid': '',
          'email': '',
          'nis': studentData['nis'],
          'nisn': studentData['nisn'] ?? '',
          'nama': studentData['nama'],
          'gender': studentData['gender'],
          'tempatLahir': studentData['tempatLahir'] ?? '',
          'tanggalLahir': studentData['tanggalLahir'],
          'agama': studentData['agama'] ?? '',
          'kewarganegaraan': studentData['kewarganegaraan'] ?? '',
          'alamat': studentData['alamat'],
          'noHp': studentData['noHp'] ?? '',
          'angkatan': studentData['angkatan'],
          'jalurMasuk': studentData['jalurMasuk'] ?? '',
          'tanggalDiterima': studentData['tanggalDiterima'] ?? '',
          'namaAyah': studentData['namaAyah'] ?? '',
          'nikAyah': studentData['nikAyah'] ?? '',
          'pekerjaanAyah': studentData['pekerjaanAyah'] ?? '',
          'pendidikanAyah': studentData['pendidikanAyah'] ?? '',
          'noHpAyah': studentData['noHpAyah'] ?? '',
          'namaIbu': studentData['namaIbu'] ?? '',
          'nikIbu': studentData['nikIbu'] ?? '',
          'pekerjaanIbu': studentData['pekerjaanIbu'] ?? '',
          'pendidikanIbu': studentData['pendidikanIbu'] ?? '',
          'noHpIbu': studentData['noHpIbu'] ?? '',
          'namaWali': studentData['namaWali'] ?? '',
          'hubunganWali': studentData['hubunganWali'] ?? '',
          'noHpWali': studentData['noHpWali'] ?? '',
          'alamatWali': studentData['alamatWali'] ?? '',
          'classId': null,
          'aktif': true,
          'sudahRegister': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
        success++;
        onProgress?.call(totalRows + success, totalRows * 2);
      }

      return ExcelImportResult(
        successCount: success,
        duplicateCount: 0,
        failedCount: 0,
        errors: [],
      );
    } catch (e) {
      debugPrint('Error importing students: $e');
      return ExcelImportResult(
        successCount: 0,
        duplicateCount: 0,
        failedCount: 1,
        errors: ['Terjadi kesalahan saat memproses file: $e'],
      );
    }
  }


  // =========================================================
  // Helper: set style on a specific cell by column index (0-based), row index (0-based)
  // =========================================================
  void _setCellStyle(Sheet sheet, int row, int col, CellStyle style) {
    final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row));
    cell.cellStyle = style;
  }

  // =========================================================
  // Helper: inject data-validation XML into .xlsx bytes so that
  // dropdown lists appear in Excel/LibreOffice for certain columns.
  // =========================================================
  List<int> _injectDataValidations(List<int> excelBytes, {String type = 'siswa'}) {
    try {
      final archive = ZipDecoder().decodeBytes(excelBytes);

      final String dvXml;
      if (type == 'guru') {
        // Guru template: 35 columns, data starts row 6
        // G=Jenis Kelamin, J=Agama, K=Status Pernikahan, L=Kewarganegaraan, M=Golongan Darah, X=Status Guru
        dvXml = '<dataValidations count="6">'
            '<dataValidation type="list" allowBlank="1" sqref="G6:G2000">'
            '<formula1>&quot;Laki-laki,Perempuan&quot;</formula1>'
            '</dataValidation>'
            '<dataValidation type="list" allowBlank="1" sqref="J6:J2000">'
            '<formula1>&quot;Islam,Kristen,Katolik,Hindu,Buddha,Konghucu&quot;</formula1>'
            '</dataValidation>'
            '<dataValidation type="list" allowBlank="1" sqref="K6:K2000">'
            '<formula1>&quot;Belum Menikah,Menikah,Duda/Janda&quot;</formula1>'
            '</dataValidation>'
            '<dataValidation type="list" allowBlank="1" sqref="L6:L2000">'
            '<formula1>&quot;WNI,WNA&quot;</formula1>'
            '</dataValidation>'
            '<dataValidation type="list" allowBlank="1" sqref="M6:M2000">'
            '<formula1>&quot;A,B,AB,O,A+,A-,B+,B-,AB+,AB-,O+,O-&quot;</formula1>'
            '</dataValidation>'
            '<dataValidation type="list" allowBlank="1" sqref="X6:X2000">'
            '<formula1>&quot;Tetap,Honorer,PPPK,PNS,Kontrak&quot;</formula1>'
            '</dataValidation>'
            '</dataValidations>';
      } else {
        // Siswa template: 27 columns, data starts row 6
        // D=Jenis Kelamin, G=Agama, H=Kewarganegaraan, L=Jalur Masuk
        dvXml = '<dataValidations count="4">'
            '<dataValidation type="list" allowBlank="1" sqref="D6:D2000">'
            '<formula1>&quot;Laki-laki,Perempuan&quot;</formula1>'
            '</dataValidation>'
            '<dataValidation type="list" allowBlank="1" sqref="G6:G2000">'
            '<formula1>&quot;Islam,Kristen,Katolik,Hindu,Buddha,Konghucu&quot;</formula1>'
            '</dataValidation>'
            '<dataValidation type="list" allowBlank="1" sqref="H6:H2000">'
            '<formula1>&quot;WNI,WNA&quot;</formula1>'
            '</dataValidation>'
            '<dataValidation type="list" allowBlank="1" sqref="L6:L2000">'
            '<formula1>&quot;Zonasi,Prestasi,Afirmasi,Pindah Tugas,Umum/Reguler&quot;</formula1>'
            '</dataValidation>'
            '</dataValidations>';
      }

      final newArchive = Archive();

      for (final file in archive) {
        if (file.name == 'xl/worksheets/sheet1.xml') {
          String sheetXml = utf8.decode(file.content as List<int>);

          // OOXML schema: dataValidations must come AFTER mergeCells and BEFORE drawing
          if (sheetXml.contains('<drawing ')) {
            sheetXml = sheetXml.replaceFirst('<drawing ', '$dvXml<drawing ');
          } else {
            sheetXml = sheetXml.replaceFirst('</worksheet>', '$dvXml</worksheet>');
          }

          final newBytes = utf8.encode(sheetXml);
          newArchive.addFile(ArchiveFile(file.name, newBytes.length, newBytes));
        } else {
          newArchive.addFile(file);
        }
      }

      return ZipEncoder().encode(newArchive) ?? excelBytes;
    } catch (e) {
      debugPrint('_injectDataValidations error: $e');
      return excelBytes;
    }
  }

  Future<bool?> downloadTemplate(String type) async {
    try {
      final String defaultName = type == 'guru' ? 'template_guru.xlsx' : 'template_siswa.xlsx';
      final String title = type == 'guru' ? 'Simpan Template Data Guru' : 'Simpan Template Data Siswa';
      
      String schoolName = '(NAMA SEKOLAH)';
      final user = SessionService.currentUser;
      if (user != null && user.schoolId.isNotEmpty) {
        try {
          final doc = await FirebaseFirestore.instance.collection('schools').doc(user.schoolId).get();
          if (doc.exists) {
            schoolName = (doc.data()?['namaSekolah'] ?? doc.data()?['nama'] ?? doc.data()?['name'] ?? schoolName).toString().toUpperCase();
          }
        } catch (_) {}
      }

      var excel = Excel.createExcel();
      Sheet sheetObject = excel['Sheet1'];
      
      // Tambahkan Kolom header dan dummy data
      if (type == 'guru') {
        // ===== TEMPLATE GURU =====
        final thinBorder = Border(borderStyle: BorderStyle.Thin);

        final titleStyle = CellStyle(
          backgroundColorHex: ExcelColor.fromHexString('#1F3864'),
          fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
          bold: true, fontSize: 12,
          horizontalAlign: HorizontalAlign.Center,
          verticalAlign: VerticalAlign.Center,
          textWrapping: TextWrapping.WrapText,
        );
        final noteStyle = CellStyle(
          backgroundColorHex: ExcelColor.fromHexString('#FFF2CC'),
          fontColorHex: ExcelColor.fromHexString('#000000'),
          italic: true, fontSize: 10,
          horizontalAlign: HorizontalAlign.Left,
          verticalAlign: VerticalAlign.Center,
        );
        // Section header styles
        // Section styles removed
        final mandatoryHeaderStyle = CellStyle(
          backgroundColorHex: ExcelColor.fromHexString('#D9D9D9'),
          fontColorHex: ExcelColor.fromHexString('#000000'),
          bold: true, fontSize: 9,
          horizontalAlign: HorizontalAlign.Center,
          verticalAlign: VerticalAlign.Center,
          textWrapping: TextWrapping.WrapText,
          leftBorder: thinBorder, rightBorder: thinBorder,
          topBorder: thinBorder, bottomBorder: thinBorder,
        );
        final optionalHeaderStyle = CellStyle(
          backgroundColorHex: ExcelColor.fromHexString('#D9D9D9'),
          fontColorHex: ExcelColor.fromHexString('#000000'),
          bold: true, fontSize: 9,
          horizontalAlign: HorizontalAlign.Center,
          verticalAlign: VerticalAlign.Center,
          textWrapping: TextWrapping.WrapText,
          leftBorder: thinBorder, rightBorder: thinBorder,
          topBorder: thinBorder, bottomBorder: thinBorder,
        );
        final mandatoryDataStyle = CellStyle(
          backgroundColorHex: ExcelColor.fromHexString('#FFF2CC'),
          horizontalAlign: HorizontalAlign.Left,
          verticalAlign: VerticalAlign.Center, fontSize: 10,
          leftBorder: thinBorder, rightBorder: thinBorder,
          topBorder: thinBorder, bottomBorder: thinBorder,
        );
        final optionalDataStyle = CellStyle(
          backgroundColorHex: ExcelColor.fromHexString('#EBF3FB'),
          horizontalAlign: HorizontalAlign.Left,
          verticalAlign: VerticalAlign.Center, fontSize: 10,
          leftBorder: thinBorder, rightBorder: thinBorder,
          topBorder: thinBorder, bottomBorder: thinBorder,
        );

        // Column definitions: (label, isMandatory, section)
        // Section: 0=Pribadi, 1=Identitas, 2=Kepegawaian, 3=Akademik
        const colDefs = [
          // A-F: Data Pribadi
          ('Nama Lengkap *', true, 0),
          ('NIP *', true, 0),
          ('NUPTK', false, 0),
          ('No. Pegawai Internal', false, 0),
          ('Gelar Depan', false, 0),
          ('Gelar Belakang', false, 0),
          // G-P: Data Pribadi cont.
          ('Jenis Kelamin *\n(Laki-laki/Perempuan)', true, 0),
          ('Tempat Lahir *', true, 0),
          ('Tanggal Lahir *\n(dd-MM-yyyy)', true, 0),
          ('Agama *\n(pilih dropdown)', true, 0),
          ('Status Pernikahan\n(pilih dropdown)', false, 0),
          ('Kewarganegaraan *\n(pilih dropdown)', true, 0),
          ('Golongan Darah\n(pilih dropdown)', false, 0),
          ('Alamat', false, 0),
          ('Nomor HP *', true, 0),
          ('Kontak Darurat', false, 0),
          // Q-W: Data Identitas
          ('NIK *', true, 1),
          ('NPWP', false, 1),
          ('BPJS Kesehatan', false, 1),
          ('BPJS Ketenagakerjaan', false, 1),
          ('Nomor KK *', true, 1),
          ('Nomor Rekening', false, 1),
          ('Nama Bank', false, 1),
          // X-AC: Data Kepegawaian
          ('Status Guru\n(pilih dropdown)', false, 2),
          ('Jabatan', false, 2),
          ('Pangkat/Golongan', false, 2),
          ('TMT\n(dd-MM-yyyy)', false, 2),
          ('Tanggal Bergabung\n(dd-MM-yyyy)', false, 2),
          ('Masa Kerja', false, 2),
          // AD-AI: Data Akademik
          ('Pendidikan Terakhir *', true, 3),
          ('Jurusan', false, 3),
          ('Universitas/Institusi', false, 3),
          ('Tahun Lulus', false, 3),
          ('Sertifikasi Guru', false, 3),
          ('Bidang Sertifikasi', false, 3),
        ];

        final int totalCols = colDefs.length; // 35

        // ---- Row 1-2: Title merged ----
        sheetObject.merge(
          CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0),
          CellIndex.indexByColumnRow(columnIndex: totalCols - 1, rowIndex: 1),
          customValue: TextCellValue('TEMPLATE IMPOR DATA GURU\n$schoolName'),
        );
        for (int r = 0; r <= 1; r++) {
          for (int c = 0; c < totalCols; c++) {
            _setCellStyle(sheetObject, r, c, titleStyle);
          }
        }
        sheetObject.setRowHeight(0, 28);
        sheetObject.setRowHeight(1, 18);

        // ---- Row 3: Empty ----
        sheetObject.appendRow([TextCellValue('')]);

        // ---- Row 4: Instruction note merged ----
        sheetObject.merge(
          CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 3),
          CellIndex.indexByColumnRow(columnIndex: totalCols - 1, rowIndex: 3),
          customValue: TextCellValue(
            '📌 PETUNJUK: Kolom KUNING = WAJIB diisi. Kolom BIRU MUDA = opsional. '
            'Untuk kolom Jenis Kelamin, Agama, Status Pernikahan, Kewarganegaraan, Golongan Darah, dan Status Guru → gunakan DROPDOWN (klik sel lalu pilih). '
            'Jangan ubah baris 1-4. Data dimulai dari baris 6.',
          ),
        );
        for (int c = 0; c < totalCols; c++) {
          _setCellStyle(sheetObject, 3, c, noteStyle);
        }
        sheetObject.setRowHeight(3, 30);

        // ---- Row 5: Column headers ----
        final List<CellValue> headerRow = [];
        for (int c = 0; c < totalCols; c++) {
          headerRow.add(TextCellValue(colDefs[c].$1));
        }
        sheetObject.appendRow(headerRow);
        final List<int> mandatoryColIndexes = [];
        for (int c = 0; c < totalCols; c++) {
          final isMandatory = colDefs[c].$2;
          if (isMandatory) mandatoryColIndexes.add(c);
          _setCellStyle(sheetObject, 4, c, isMandatory ? mandatoryHeaderStyle : optionalHeaderStyle);
        }

        // ---- Row 6: Example data ----
        sheetObject.appendRow([
          /* A  */ TextCellValue('Budi Santoso'),
          /* B  */ TextCellValue('199012345678901'),
          /* C  */ TextCellValue(''),
          /* D  */ TextCellValue(''),
          /* E  */ TextCellValue('Dr.'),
          /* F  */ TextCellValue('M.Pd.'),
          /* G  */ TextCellValue('Laki-laki'),
          /* H  */ TextCellValue('Surabaya'),
          /* I  */ TextCellValue('15-05-1990'),
          /* J  */ TextCellValue('Islam'),
          /* K  */ TextCellValue('Menikah'),
          /* L  */ TextCellValue('WNI'),
          /* M  */ TextCellValue('O'),
          /* N  */ TextCellValue('Jl. Merdeka No. 1, Surabaya'),
          /* O  */ TextCellValue('08123456789'),
          /* P  */ TextCellValue('08987654321'),
          /* Q  */ TextCellValue('3578123456789001'),
          /* R  */ TextCellValue(''),
          /* S  */ TextCellValue(''),
          /* T  */ TextCellValue(''),
          /* U  */ TextCellValue('3578123456789999'),
          /* V  */ TextCellValue(''),
          /* W  */ TextCellValue(''),
          /* X  */ TextCellValue('PNS'),
          /* Y  */ TextCellValue('Guru Mata Pelajaran'),
          /* Z  */ TextCellValue('III/c'),
          /* AA */ TextCellValue('01-01-2015'),
          /* AB */ TextCellValue('15-07-2014'),
          /* AC */ TextCellValue('10 tahun'),
          /* AD */ TextCellValue('S1'),
          /* AE */ TextCellValue('Pendidikan Matematika'),
          /* AF */ TextCellValue('Universitas Negeri Malang'),
          /* AG */ TextCellValue('2013'),
          /* AH */ TextCellValue(''),
          /* AI */ TextCellValue(''),
        ]);
        for (int c = 0; c < totalCols; c++) {
          final dStyle = mandatoryColIndexes.contains(c) ? mandatoryDataStyle : optionalDataStyle;
          _setCellStyle(sheetObject, 5, c, dStyle);
        }

        // ---- Column widths ----
        const colWidths = [
          26.0, 20.0, 16.0, 22.0, 14.0, 14.0, // A-F
          20.0, 18.0, 20.0, 14.0, 20.0, 18.0, 14.0, 30.0, 16.0, 18.0, // G-P
          20.0, 16.0, 18.0, 22.0, 20.0, 18.0, 16.0, // Q-W
          18.0, 18.0, 18.0, 18.0, 20.0, 16.0, // X-AC
          22.0, 18.0, 24.0, 14.0, 20.0, 20.0, // AD-AI
        ];
        for (int c = 0; c < colWidths.length; c++) {
          sheetObject.setColumnWidth(c, colWidths[c]);
        }

      } else {
        // ===== TEMPLATE MURID =====

        // ---- Define Styles ----
        final thinBorder = Border(borderStyle: BorderStyle.Thin);
        
        final titleStyle = CellStyle(
          backgroundColorHex: ExcelColor.fromHexString('#0A58CA'),
          fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
          bold: true,
          fontSize: 12,
          horizontalAlign: HorizontalAlign.Center,
          verticalAlign: VerticalAlign.Center,
          textWrapping: TextWrapping.WrapText,
        );
        
        final noteStyle = CellStyle(
          backgroundColorHex: ExcelColor.fromHexString('#FFF2CC'),
          fontColorHex: ExcelColor.fromHexString('#000000'),
          italic: true,
          fontSize: 10,
          horizontalAlign: HorizontalAlign.Left,
          verticalAlign: VerticalAlign.Center,
        );
        
        final headerStyle = CellStyle(
          backgroundColorHex: ExcelColor.fromHexString('#D9D9D9'),
          fontColorHex: ExcelColor.fromHexString('#000000'),
          bold: true,
          horizontalAlign: HorizontalAlign.Center,
          verticalAlign: VerticalAlign.Center,
          fontSize: 10,
          textWrapping: TextWrapping.WrapText,
          leftBorder: thinBorder,
          rightBorder: thinBorder,
          topBorder: thinBorder,
          bottomBorder: thinBorder,
        );
        
        final mandatoryDataStyle = CellStyle(
          backgroundColorHex: ExcelColor.fromHexString('#FFF2CC'),
          horizontalAlign: HorizontalAlign.Left,
          verticalAlign: VerticalAlign.Center,
          fontSize: 10,
          leftBorder: thinBorder,
          rightBorder: thinBorder,
          topBorder: thinBorder,
          bottomBorder: thinBorder,
        );
        
        final optionalDataStyle = CellStyle(
          backgroundColorHex: ExcelColor.fromHexString('#EBF3FB'),
          horizontalAlign: HorizontalAlign.Left,
          verticalAlign: VerticalAlign.Center,
          fontSize: 10,
          leftBorder: thinBorder,
          rightBorder: thinBorder,
          topBorder: thinBorder,
          bottomBorder: thinBorder,
        );

        // ---- Baris 1-2: Judul Merged ----
        sheetObject.merge(
          CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0),
          CellIndex.indexByColumnRow(columnIndex: 26, rowIndex: 1),
          customValue: TextCellValue('TEMPLATE IMPOR DATA MURID\n$schoolName'),
        );
        for (int r = 0; r <= 1; r++) {
          for (int c = 0; c <= 26; c++) {
            _setCellStyle(sheetObject, r, c, titleStyle);
          }
        }

        // ---- Baris 3: Kosong ----
        sheetObject.appendRow([TextCellValue('')]);
        
        // ---- Baris 4: Instruksi Merged ----
        sheetObject.merge(
          CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 3),
          CellIndex.indexByColumnRow(columnIndex: 26, rowIndex: 3),
          customValue: TextCellValue('Kolom KUNING = WAJIB diisi. Kolom biru = opsional. Untuk Jenis Kelamin, Agama, Kewarganegaraan, dan Jalur Masuk gunakan dropdown (klik sel untuk memilih).'),
        );
        for (int c = 0; c <= 26; c++) {
          _setCellStyle(sheetObject, 3, c, noteStyle);
        }

        // ---- Baris 5: Header ----
        sheetObject.appendRow([
          /* A  */ TextCellValue('Nama Lengkap *'),
          /* B  */ TextCellValue('NIS *'),
          /* C  */ TextCellValue('NISN'),
          /* D  */ TextCellValue('Jenis Kelamin *'),
          /* E  */ TextCellValue('Tempat Lahir *'),
          /* F  */ TextCellValue('Tanggal Lahir (DD-MM-YYYY) *'),
          /* G  */ TextCellValue('Agama *'),
          /* H  */ TextCellValue('Kewarganegaraan'),
          /* I  */ TextCellValue('Alamat *'),
          /* J  */ TextCellValue('Nomor HP'),
          /* K  */ TextCellValue('Tahun Angkatan *'),
          /* L  */ TextCellValue('Jalur Masuk'),
          /* M  */ TextCellValue('Tanggal Diterima (DD-MM-YYYY)'),
          /* N  */ TextCellValue('Nama Ayah'),
          /* O  */ TextCellValue('NIK Ayah'),
          /* P  */ TextCellValue('Pekerjaan Ayah'),
          /* Q  */ TextCellValue('Pendidikan Ayah'),
          /* R  */ TextCellValue('No. HP Ayah'),
          /* S  */ TextCellValue('Nama Ibu'),
          /* T  */ TextCellValue('NIK Ibu'),
          /* U  */ TextCellValue('Pekerjaan Ibu'),
          /* V  */ TextCellValue('Pendidikan Ibu'),
          /* W  */ TextCellValue('No. HP Ibu'),
          /* X  */ TextCellValue('Nama Wali'),
          /* Y  */ TextCellValue('Hubungan dengan Siswa'),
          /* Z  */ TextCellValue('No. HP Wali'),
          /* AA */ TextCellValue('Alamat Wali'),
        ]);

        final mandatoryColIndexes = [0, 1, 3, 4, 5, 6, 8, 10];
        
        for (int c = 0; c < 27; c++) {
          _setCellStyle(sheetObject, 4, c, headerStyle);
        }

        // ---- Baris 6: Contoh Data (1 baris saja) ----
        for (int i = 0; i < 1; i++) {
          int startYear = 2010;
          int acceptYear = 2024;
          sheetObject.appendRow([
            /* A  */ TextCellValue('Adi Pratama'),
            /* B  */ TextCellValue('12345'),
            /* C  */ TextCellValue('0012345678'),
            /* D  */ TextCellValue('Laki-laki'),
            /* E  */ TextCellValue('Jakarta'),
            /* F  */ TextCellValue('15-05-$startYear'),
            /* G  */ TextCellValue('Islam'),
            /* H  */ TextCellValue('WNI'),
            /* I  */ TextCellValue('Jl. Pahlawan No. 2, Jakarta'),
            /* J  */ TextCellValue('08123456789'),
            /* K  */ TextCellValue('$acceptYear'),
            /* L  */ TextCellValue('Zonasi'),
            /* M  */ TextCellValue('01-07-$acceptYear'),
            /* N  */ TextCellValue('Budi Pratama'),
            /* O  */ TextCellValue('3171234567890001'),
            /* P  */ TextCellValue('Wiraswasta'),
            /* Q  */ TextCellValue('S1'),
            /* R  */ TextCellValue('08111222333'),
            /* S  */ TextCellValue('Siti Pratama'),
            /* T  */ TextCellValue('3171234567890002'),
            /* U  */ TextCellValue('Ibu Rumah Tangga'),
            /* V  */ TextCellValue('SMA'),
            /* W  */ TextCellValue('08444555666'),
            /* X  */ TextCellValue(''),
            /* Y  */ TextCellValue(''),
            /* Z  */ TextCellValue(''),
            /* AA */ TextCellValue(''),
          ]);

          for (int c = 0; c < 27; c++) {
            final dStyle = mandatoryColIndexes.contains(c) ? mandatoryDataStyle : optionalDataStyle;
            _setCellStyle(sheetObject, 5 + i, c, dStyle);
          }
        }

        // ---- Set column widths ----
        sheetObject.setColumnWidth(0, 22);   // A  Nama
        sheetObject.setColumnWidth(1, 14);   // B  NIS
        sheetObject.setColumnWidth(2, 14);   // C  NISN
        sheetObject.setColumnWidth(3, 16);   // D  Jenis Kelamin
        sheetObject.setColumnWidth(4, 16);   // E  Tempat Lahir
        sheetObject.setColumnWidth(5, 20);   // F  Tanggal Lahir
        sheetObject.setColumnWidth(6, 14);   // G  Agama
        sheetObject.setColumnWidth(7, 18);   // H  Kewarganegaraan
        sheetObject.setColumnWidth(8, 30);   // I  Alamat
        sheetObject.setColumnWidth(9, 16);   // J  No HP
        sheetObject.setColumnWidth(10, 14);  // K  Angkatan
        sheetObject.setColumnWidth(11, 16);  // L  Jalur Masuk
        sheetObject.setColumnWidth(12, 20);  // M  Tanggal Diterima
        sheetObject.setColumnWidth(13, 22);  // N  Nama Ayah
        sheetObject.setColumnWidth(14, 20);  // O  NIK Ayah
        sheetObject.setColumnWidth(15, 18);  // P  Pekerjaan Ayah
        sheetObject.setColumnWidth(16, 16);  // Q  Pendidikan Ayah
        sheetObject.setColumnWidth(17, 16);  // R  HP Ayah
        sheetObject.setColumnWidth(18, 22);  // S  Nama Ibu
        sheetObject.setColumnWidth(19, 20);  // T  NIK Ibu
        sheetObject.setColumnWidth(20, 18);  // U  Pekerjaan Ibu
        sheetObject.setColumnWidth(21, 16);  // V  Pendidikan Ibu
        sheetObject.setColumnWidth(22, 16);  // W  HP Ibu
        sheetObject.setColumnWidth(23, 22);  // X  Nama Wali
        sheetObject.setColumnWidth(24, 24);  // Y  Hubungan
        sheetObject.setColumnWidth(25, 16);  // Z  HP Wali
        sheetObject.setColumnWidth(26, 30);  // AA Alamat Wali
      }

      var bytes = excel.encode();
      if (bytes == null) {
        return false;
      }

      // Inject data validation dropdowns
      bytes = _injectDataValidations(bytes, type: type);

      final uint8ListBytes = Uint8List.fromList(bytes);

      String? outputFile = await fp.FilePicker.saveFile(
        dialogTitle: title,
        fileName: defaultName,
        bytes: uint8ListBytes,
      );

      if (outputFile == null) return null; // Batal memilih lokasi

      // For safety on desktop platforms where saveFile might just return path without writing bytes.
      // On mobile (Android & iOS), the plugin already writes the bytes, and manual write will fail due to sandbox/storage restrictions.
      if (!kIsWeb && !FileHelper.isMobile()) {
        await FileHelper.writeBytes(outputFile, bytes);
      }
      return true;
    } catch (e) {
      debugPrint('Error generating template: $e');
      return false;
    }
  }
}
