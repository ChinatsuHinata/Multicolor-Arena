import openpyxl
from pathlib import Path
r=Path(r'C:\Users\tzx20\Documents\test')
w=openpyxl.load_workbook(r/'recourse'/'极彩全牌表 - （圣版可检索）25-12-17.xlsx',data_only=True)
for s in w:
 if s.title.startswith('CAPACITY'):
  print(s.title, len(s._images))
  for i,im in enumerate(s._images):
   p=r/'work'/'rules_review'/('CAPACITY'+str(i)+'.'+im.format);p.write_bytes(im._data());print(p,im.width,im.height)
 for i,row in enumerate(s.values,1):
  if any(v and '红薯' in str(v) for v in row): print(s.title,i,row)
