from openpyxl import Workbook
from openpyxl.worksheet.datavalidation import DataValidation

wb = Workbook()
ws = wb.active
dv = DataValidation(type="list", formula1='"Laki-laki,Perempuan"', allow_blank=True)
ws.add_data_validation(dv)
dv.add('D6:D2000')

wb.save('test_py.xlsx')
