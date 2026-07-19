import 'dart:io';
import 'package:excel/excel.dart';

void main() {
  var excel = Excel.createExcel();
  Sheet sheet = excel['Sheet1'];
  
  var blueStyle = CellStyle(
    backgroundColorHex: ExcelColor.fromHexString('#0A58CA'),
    fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
    bold: true,
    horizontalAlign: HorizontalAlign.Center,
    verticalAlign: VerticalAlign.Center,
  );
  
  sheet.merge(
    CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0),
    CellIndex.indexByColumnRow(columnIndex: 26, rowIndex: 1),
    customValue: TextCellValue("TEMPLATE IMPOR DATA MURID\n(NAMA SEKOLAH)")
  );
  
  for (int r = 0; r <= 1; r++) {
    for (int c = 0; c <= 26; c++) {
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r)).cellStyle = blueStyle;
    }
  }

  File('test_merge.xlsx').writeAsBytesSync(excel.encode()!);
}
