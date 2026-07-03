import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart' as fp;
import 'package:flutter/foundation.dart';
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

      List<Map<String, dynamic>> validatedTeachers = [];
      List<String> errors = [];
      Set<String> fileNips = {};

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

        for (int i = 1; i < sheet.maxRows; i++) {
          var row = sheet.rows[i];
          processed++;
          onProgress?.call(processed, totalRows * 2);
          if (row.isEmpty) continue;

          final nama = row.isNotEmpty ? _cleanValue(row[0]?.value) : '';
          final nip = row.length > 1 ? _cleanValue(row[1]?.value) : '';
          final genderRaw = row.length > 2 ? _cleanValue(row[2]?.value) : '';
          final gender = _parseGender(genderRaw);
          final alamat = row.length > 3 ? _cleanValue(row[3]?.value) : '';

          // Skip completely empty rows silently
          if (nama.isEmpty && nip.isEmpty) {
            continue;
          }

          if (nama.isEmpty) {
            errors.add('Baris ${i + 1} (NIP: ${nip.isEmpty ? "-" : nip}): Nama guru tidak boleh kosong.');
            continue;
          }

          if (nip.isEmpty) {
            errors.add('Baris ${i + 1} (Nama: $nama): NIP tidak boleh kosong.');
            continue;
          }

          if (fileNips.contains(nip)) {
            errors.add('Baris ${i + 1} (Nama: $nama, NIP: $nip): NIP duplikat di dalam file Excel.');
            continue;
          }
          fileNips.add(nip);

          // Check if NIP is registered in Firestore
          final existing = await _db
              .collection('schools')
              .doc(schoolId)
              .collection('teachers')
              .where('nip', isEqualTo: nip)
              .get();

          if (existing.docs.isNotEmpty) {
            final existingName = existing.docs.first.data()['nama'] ?? 'Guru Lain';
            errors.add('Baris ${i + 1} (Nama: $nama, NIP: $nip): NIP sudah terdaftar di database atas nama "$existingName".');
            continue;
          }

          if (genderRaw.isNotEmpty && gender.isEmpty) {
            errors.add('Baris ${i + 1} (Nama: $nama, NIP: $nip): Jenis Kelamin "$genderRaw" tidak valid (harus L atau P).');
            continue;
          }

          validatedTeachers.add({
            'nama': nama,
            'nip': nip,
            'gender': gender,
            'alamat': alamat,
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

      // Cek kuota guru di sekolah jika diset
      final schoolDoc = await _db.collection('schools').doc(schoolId).get();
      if (schoolDoc.exists) {
        final schoolData = schoolDoc.data();
        final teacherQuota = schoolData?['teacherQuota'] as int?;
        if (teacherQuota != null && teacherQuota > 0) {
          final countSnap = await _db
              .collection('schools')
              .doc(schoolId)
              .collection('teachers')
              .count()
              .get();
          final currentCount = countSnap.count ?? 0;
          if (currentCount + validatedTeachers.length > teacherQuota) {
            final slotsLeft = teacherQuota - currentCount;
            errors.add(
              '🔒 Batas kuota Guru tercapai!\n'
              '   • Kapasitas: $teacherQuota guru\n'
              '   • Terdaftar saat ini: $currentCount guru\n'
              '   • Slot tersisa: $slotsLeft slot\n'
              '   • Mencoba mengimpor: ${validatedTeachers.length} guru\n\n'
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
      for (int i = 0; i < validatedTeachers.length; i++) {
        final teacherData = validatedTeachers[i];
        final docRef = _db
            .collection('schools')
            .doc(schoolId)
            .collection('teachers')
            .doc();

        await docRef.set({
          'teacherId': docRef.id,
          'schoolId': schoolId,
          'uid': '',
          'email': '',
          'nip': teacherData['nip'],
          'nama': teacherData['nama'],
          'gender': teacherData['gender'],
          'alamat': teacherData['alamat'],
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
      debugPrint('Error importing teachers: $e');
      return ExcelImportResult(
        successCount: 0,
        duplicateCount: 0,
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

        for (int i = 1; i < sheet.maxRows; i++) {
          var row = sheet.rows[i];
          processed++;
          onProgress?.call(processed, totalRows * 2);
          if (row.isEmpty) continue;

          final nama = row.isNotEmpty ? _cleanValue(row[0]?.value) : '';
          final nis = row.length > 1 ? _cleanValue(row[1]?.value) : '';
          final genderRaw = row.length > 2 ? _cleanValue(row[2]?.value) : '';
          final gender = _parseGender(genderRaw);
          final alamat = row.length > 3 ? _cleanValue(row[3]?.value) : '';
          final tanggalLahir = row.length > 4 ? _cleanValue(row[4]?.value) : '';
          final angkatan = row.length > 5 ? _cleanValue(row[5]?.value) : '';

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
            errors.add('Baris ${i + 1} (Nama: $nama, NIS: $nis): Jenis Kelamin "$genderRaw" tidak valid (harus L atau P).');
            continue;
          }

          validatedStudents.add({
            'nama': nama,
            'nis': nis,
            'gender': gender,
            'alamat': alamat,
            'tanggalLahir': tanggalLahir,
            'angkatan': angkatan,
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
          'nama': studentData['nama'],
          'gender': studentData['gender'],
          'alamat': studentData['alamat'],
          'tanggalLahir': studentData['tanggalLahir'],
          'angkatan': studentData['angkatan'],
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

  Future<bool?> downloadTemplate(String type) async {
    try {
      final String defaultName = type == 'guru' ? 'template_guru.xlsx' : 'template_siswa.xlsx';
      final String title = type == 'guru' ? 'Simpan Template Data Guru' : 'Simpan Template Data Siswa';
      
      var excel = Excel.createExcel();
      Sheet sheetObject = excel['Sheet1'];
      
      // Tambahkan Kolom header dan dummy data
      if (type == 'guru') {
        sheetObject.appendRow([
          TextCellValue('Nama'),
          TextCellValue('NIP'),
          TextCellValue('Jenis Kelamin (L/P)'),
          TextCellValue('Alamat'),
        ]);
        sheetObject.appendRow([
          TextCellValue('Budi Santoso'),
          TextCellValue('199012345678901'),
          TextCellValue('L'),
          TextCellValue('Jl. Merdeka No. 1'),
        ]);
      } else {
        sheetObject.appendRow([
          TextCellValue('Nama'),
          TextCellValue('NIS'),
          TextCellValue('Jenis Kelamin (L/P)'),
          TextCellValue('Alamat'),
          TextCellValue('Tanggal Lahir (DD-MM-YYYY)'),
          TextCellValue('Angkatan (Tahun)'),
        ]);
        sheetObject.appendRow([
          TextCellValue('Adi Pratama'),
          TextCellValue('12345'),
          TextCellValue('L'),
          TextCellValue('Jl. Pahlawan No. 2'),
          TextCellValue('15-05-2010'),
          TextCellValue('2024'),
        ]);
      }

      final bytes = excel.encode();
      if (bytes == null) {
        return false;
      }

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
