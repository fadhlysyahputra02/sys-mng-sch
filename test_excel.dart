import 'dart:io';
import 'package:excel/excel.dart';
import 'package:archive/archive.dart';
import 'dart:convert';

void main() {
  var excel = Excel.createExcel();
  Sheet sheetObject = excel['Sheet1'];
  sheetObject.appendRow([TextCellValue('Test')]);
  var bytes = excel.encode()!;
  
  final archive = ZipDecoder().decodeBytes(bytes);
  const String dvXml = '<dataValidations count="4">'
      '<dataValidation type="list" allowBlank="1" showDropDown="1" sqref="D5:D2000">'
      '<formula1>&quot;Laki-laki,Perempuan&quot;</formula1>'
      '</dataValidation>'
      '<dataValidation type="list" allowBlank="1" showDropDown="1" sqref="G5:G2000">'
      '<formula1>&quot;Islam,Kristen,Katolik,Hindu,Buddha,Konghucu&quot;</formula1>'
      '</dataValidation>'
      '<dataValidation type="list" allowBlank="1" showDropDown="1" sqref="H5:H2000">'
      '<formula1>&quot;WNI,WNA&quot;</formula1>'
      '</dataValidation>'
      '<dataValidation type="list" allowBlank="1" showDropDown="1" sqref="L5:L2000">'
      '<formula1>&quot;Zonasi,Prestasi,Afirmasi,Pindah Tugas,Umum/Reguler&quot;</formula1>'
      '</dataValidation>'
      '</dataValidations>';

  final newArchive = Archive();
  for (final file in archive) {
    if (file.name == 'xl/worksheets/sheet1.xml') {
      String sheetXml = utf8.decode(file.content as List<int>);
      sheetXml = sheetXml.replaceFirst('</sheetData>', '</sheetData>$dvXml');
      final newBytes = utf8.encode(sheetXml);
      newArchive.addFile(ArchiveFile(file.name, newBytes.length, newBytes));
    } else {
      newArchive.addFile(file);
    }
  }

  var newBytes = ZipEncoder().encode(newArchive)!;
  File('test2.xlsx').writeAsBytesSync(newBytes);
  print("Done");
}
