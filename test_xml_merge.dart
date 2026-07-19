import 'dart:io';
import 'package:excel/excel.dart';

void main() {
  var excel = Excel.createExcel();
  Sheet sheetObject = excel['Sheet1'];
  sheetObject.appendRow([TextCellValue('Test')]);
  sheetObject.merge(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0), CellIndex.indexByColumnRow(columnIndex: 26, rowIndex: 1));
  var bytes = excel.encode()!;
  File('test_merge_output.xlsx').writeAsBytesSync(bytes);
}
