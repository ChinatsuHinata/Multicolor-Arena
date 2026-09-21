from pathlib import Path
import zipfile,xml.etree.ElementTree as E
p=Path('recourse/极彩全牌表 - （圣版可检索）25-12-17.xlsx');z=zipfile.ZipFile(p);ns={'m':'http://schemas.openxmlformats.org/spreadsheetml/2006/main','r':'http://schemas.openxmlformats.org/officeDocument/2006/relationships'}
print(z.read('xl/worksheets/_rels/sheet5.xml.rels').decode())
