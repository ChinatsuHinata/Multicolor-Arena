import zipfile,xml.etree.ElementTree as E
from pathlib import Path
z=zipfile.ZipFile('recourse/极彩全牌表 - （圣版可检索）25-12-17.xlsx');o=Path('work/v013/keyword-images');o.mkdir(exist_ok=True)
for r in E.fromstring(z.read('xl/drawings/_rels/drawing5.xml.rels')):
 target=r.attrib['Target'];name=target.split('/')[-1];data=z.read('xl/media/'+name);(o/name).write_bytes(data);print(name,len(data))
