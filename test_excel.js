const ExcelJS = require('exceljs');

async function main() {
  const workbook = new ExcelJS.Workbook();
  const worksheet = workbook.addWorksheet('Sheet1');
  
  worksheet.getCell('A1').value = 'Test';
  worksheet.getCell('D6').dataValidation = {
    type: 'list',
    allowBlank: true,
    formulae: ['"Laki-laki,Perempuan"']
  };

  await workbook.xlsx.writeFile('test_js.xlsx');
}
main();
