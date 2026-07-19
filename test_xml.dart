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

  for (final file in archive) {
    if (file.name == 'xl/worksheets/sheet1.xml') {
      String sheetXml = utf8.decode(file.content as List<int>);
      print("Original end: " + sheetXml.substring(sheetXml.length - 200));
      sheetXml = sheetXml.replaceFirst('</sheetData>', '</sheetData>$dvXml');
      print("Modified end: " + sheetXml.substring(sheetXml.length - 200 - dvXml.length));
    }
  }
}
