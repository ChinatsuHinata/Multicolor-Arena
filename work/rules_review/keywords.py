from pathlib import Path
import openpyxl
w=openpyxl.load_workbook(r'C:\Users\tzx20\Documents\test\recourse\极彩全牌表 - （圣版可检索）25-12-17.xlsx',read_only=True,data_only=True)
for s in w:
 if s.title.startswith(('CAPACITY','TOKEN')):
  for i,row in enumerate(s.values,1):
   if any(v and any(n in str(v) for n in ['英勇','红薯','疾行','先制']) for v in row): print(s.title,i,row)
