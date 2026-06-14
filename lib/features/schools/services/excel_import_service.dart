import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart' as fp;
import 'package:flutter/foundation.dart';

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

  Future<ExcelImportResult?> importTeachers(String schoolId) async {
    try {
      fp.FilePickerResult? result = await fp.FilePicker.pickFiles(
        type: fp.FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
      );

      if (result == null || result.files.single.path == null) {
        return null;
      }

      final file = File(result.files.single.path!);
      final bytes = file.readAsBytesSync();
      final excel = Excel.decodeBytes(bytes);

      int success = 0;
      int duplicate = 0;
      int failed = 0;
      List<String> errors = [];

      for (var table in excel.tables.keys) {
        var sheet = excel.tables[table];
        if (sheet == null) continue;

        // Skip header row at index 0, start at index 1
        for (int i = 1; i < sheet.maxRows; i++) {
          var row = sheet.rows[i];
          if (row.isEmpty) continue;

          // We expect Column 0: Nama, Column 1: NIP
          if (row.length < 2) {
            failed++;
            errors.add('Baris ${i + 1}: Data tidak lengkap (kurang kolom).');
            continue;
          }

          final nama = _cleanValue(row[0]?.value);
          final nip = _cleanValue(row[1]?.value);

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

  Future<ExcelImportResult?> importStudents(String schoolId) async {
    try {
      fp.FilePickerResult? result = await fp.FilePicker.pickFiles(
        type: fp.FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
      );

      if (result == null || result.files.single.path == null) {
        return null;
      }

      final file = File(result.files.single.path!);
      final bytes = file.readAsBytesSync();
      final excel = Excel.decodeBytes(bytes);

      int success = 0;
      int duplicate = 0;
      int failed = 0;
      List<String> errors = [];

      for (var table in excel.tables.keys) {
        var sheet = excel.tables[table];
        if (sheet == null) continue;

        // Skip header row at index 0, start at index 1
        for (int i = 1; i < sheet.maxRows; i++) {
          var row = sheet.rows[i];
          if (row.isEmpty) continue;

          // We expect Column 0: Nama, Column 1: NIS
          if (row.length < 2) {
            failed++;
            errors.add('Baris ${i + 1}: Data tidak lengkap (kurang kolom).');
            continue;
          }

          final nama = _cleanValue(row[0]?.value);
          final nis = _cleanValue(row[1]?.value);

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
}
