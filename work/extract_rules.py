from pathlib import Path
from zipfile import ZipFile
from lxml import etree
import openpyxl,json
r=Path(r'C:\Users\tzx20\Documents\test');out=r/'work'/'rules_review';out.mkdir(exist_ok=True)
ns={'w':'http://schemas.openxmlformats.org/wordprocessingml/2006/main'}
p=r/'recourse'/'《极彩multicolour》完整规则2026.6(beta).docx'
with ZipFile(p) as z:
 root=etree.fromstring(z.read('word/document.xml'))
 lines=[''.join(p.itertext()) for p in []]
 for p in root.xpath('//w:body//w:p',namespaces=ns):
  text=''.join(p.xpath('.//w:t/text()',namespaces=ns))
  if text.strip(): lines.append(text)
 (out/'complete_rules.txt').write_text('\n'.join(lines),encoding='utf-8')
 print('DOCX paragraphs',len(lines),'characters',sum(map(len,lines)))
 print('DOCX media',[(n,z.getinfo(n).file_size) for n in z.namelist() if n.startswith('word/media/')])
p=r/'recourse'/'极彩全牌表 - （圣版可检索）25-12-17.xlsx'
w=openpyxl.load_workbook(p,data_only=True)
for s in w:
 if s.title.startswith(('AREA','RULE')):
  print('SHEET',s.title,'rows',s.max_row,'images',len(s._images))
  for row in s.values:
   print(row)
  for i,im in enumerate(s._images):
   dest=out/(s.title.split('（')[0]+str(i)+'.'+im.format)
   dest.write_bytes(im._data());print('IMAGE',str(dest))
