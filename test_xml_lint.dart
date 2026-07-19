import 'dart:io';
import 'package:excel/excel.dart';
import 'package:archive/archive.dart';
import 'dart:convert';

void main() {
  var excel = Excel.createExcel();
  Sheet sheetObject = excel['Sheet1'];
  sheetObject.appendRow([TextCellValue('Test')]);
  sheetObject.merge(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0), CellIndex.indexByColumnRow(columnIndex: 26, rowIndex: 1));
  var bytes = excel.encode()!;
  
  final archive = ZipDecoder().decodeBytes(bytes);
  const String dvXml = '<dataValidations count="4">'
          '<dataValidation type="list" allowBlank="1" sqref="D6:D2000">'
          '<formula1>&quot;Laki-laki,Perempuan&quot;</formula1>'
          '</dataValidation>'
          '</dataValidations>';

  final newArchive = Archive();
  for (final file in archive) {
    if (file.name == 'xl/worksheets/sheet1.xml') {
      String sheetXml = utf8.decode(file.content as List<int>);
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

  File('test_lint.xlsx').writeAsBytesSync(ZipEncoder().encode(newArchive)!);
}
