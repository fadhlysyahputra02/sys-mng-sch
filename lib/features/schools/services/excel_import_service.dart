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

      int totalRows = 0;
      for (var table in excel.tables.keys) {
        var sheet = excel.tables[table];
        if (sheet != null) {
          totalRows += (sheet.maxRows > 1) ? (sheet.maxRows - 1) : 0;
        }
      }

      int success = 0;
      int duplicate = 0;
      int failed = 0;
      List<String> errors = [];
      int processed = 0;

      for (var table in excel.tables.keys) {
        var sheet = excel.tables[table];
        if (sheet == null) continue;

        // Skip header row at index 0, start at index 1
        for (int i = 1; i < sheet.maxRows; i++) {
          var row = sheet.rows[i];
          processed++;
          onProgress?.call(processed, totalRows);
          if (row.isEmpty) continue;

          final nama = row.isNotEmpty ? _cleanValue(row[0]?.value) : '';
          final nip = row.length > 1 ? _cleanValue(row[1]?.value) : '';

          // Skip completely empty rows silently (don't treat as failure)
          if (nama.isEmpty && nip.isEmpty) {
            continue;
          }

          if (nama.isEmpty || nip.isEmpty) {
            failed++;
            errors.add('Baris ${i + 1}: Nama atau NIP kosong.');
            continue;
          }

          // Check if NIP is already registered
          final existing = await _db
              .collection('schools')
              .doc(schoolId)
              .collection('teachers')
              .where('nip', isEqualTo: nip)
              .get();

          if (existing.docs.isNotEmpty) {
            duplicate++;
            continue;
          }

          // Insert teacher record
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
            'nip': nip,
            'nama': nama,
            'aktif': true,
            'sudahRegister': false,
            'createdAt': FieldValue.serverTimestamp(),
          });

          success++;
        }
      }

      return ExcelImportResult(
        successCount: success,
        duplicateCount: duplicate,
        failedCount: failed,
        errors: errors,
      );
    } catch (e) {
      debugPrint('Error importing teachers: $e');
      return ExcelImportResult(
        successCount: 0,
        duplicateCount: 0,
        failedCount: 0,
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

      int totalRows = 0;
      for (var table in excel.tables.keys) {
        var sheet = excel.tables[table];
        if (sheet != null) {
          totalRows += (sheet.maxRows > 1) ? (sheet.maxRows - 1) : 0;
        }
      }

      int success = 0;
      int duplicate = 0;
      int failed = 0;
      List<String> errors = [];
      int processed = 0;

      for (var table in excel.tables.keys) {
        var sheet = excel.tables[table];
        if (sheet == null) continue;

        // Skip header row at index 0, start at index 1
        for (int i = 1; i < sheet.maxRows; i++) {
          var row = sheet.rows[i];
          processed++;
          onProgress?.call(processed, totalRows);
          if (row.isEmpty) continue;

          final nama = row.isNotEmpty ? _cleanValue(row[0]?.value) : '';
          final nis = row.length > 1 ? _cleanValue(row[1]?.value) : '';

          // Skip completely empty rows silently (don't treat as failure)
          if (nama.isEmpty && nis.isEmpty) {
            continue;
          }

          if (nama.isEmpty || nis.isEmpty) {
            failed++;
            errors.add('Baris ${i + 1}: Nama atau NIS kosong.');
            continue;
          }

          // Check if NIS is already registered
          final existing = await _db
              .collection('schools')
              .doc(schoolId)
              .collection('students')
              .where('nis', isEqualTo: nis)
              .get();

          if (existing.docs.isNotEmpty) {
            duplicate++;
            continue;
          }

          // Insert student record
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
            'nis': nis,
            'nama': nama,
            'classId': null,
            'aktif': true,
            'sudahRegister': false,
            'createdAt': FieldValue.serverTimestamp(),
          });

          success++;
        }
      }

      return ExcelImportResult(
        successCount: success,
        duplicateCount: duplicate,
        failedCount: failed,
        errors: errors,
      );
    } catch (e) {
      debugPrint('Error importing students: $e');
      return ExcelImportResult(
        successCount: 0,
        duplicateCount: 0,
        failedCount: 0,
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
        ]);
        sheetObject.appendRow([
          TextCellValue('Budi Santoso'),
          TextCellValue('199012345678901'),
        ]);
      } else {
        sheetObject.appendRow([
          TextCellValue('Nama'),
          TextCellValue('NIS'),
        ]);
        sheetObject.appendRow([
          TextCellValue('Adi Pratama'),
          TextCellValue('12345'),
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
