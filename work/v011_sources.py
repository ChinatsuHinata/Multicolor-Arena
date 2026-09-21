from pathlib import Path, PurePosixPath
from zipfile import ZipFile
from lxml import etree as ET
import hashlib, json, shutil, openpyxl

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'work/v011'
OUT.mkdir(exist_ok=True)
def dump(name,data): (OUT/name).write_text(json.dumps(data,ensure_ascii=False,indent=2),encoding='utf-8')
def sha(path): return hashlib.sha256(path.read_bytes()).hexdigest()
queue=ROOT/'recourse/新增卡片'
files=sorted(p for p in queue.iterdir() if p.suffix.lower() in ['.jpg','.png','.jpeg','.webp'])
snapshot=[{'file':p.name,'bytes':p.stat().st_size,'sha256':sha(p)} for p in files]
if not (OUT/'queue.json').exists(): dump('queue.json',snapshot)
else: assert json.loads((OUT/'queue.json').read_text(encoding='utf-8'))==snapshot,'Queue changed; review new files separately'
backup=ROOT/'work/v011-backup'
if not backup.exists():
    backup.mkdir()
    for folder in ['scripts','cards','data','docs','saves','tests']:
        shutil.copytree(ROOT/folder,backup/folder)
    shutil.copytree(queue,backup/'新增卡片')
    for file in ['使用说明.md','开发者日志.md']: shutil.copy2(ROOT/file,backup/file)
rows=[]; drawings=[]
for path in [ROOT/'recourse/极彩全牌表 - （圣版可检索）25-12-17.xlsx',ROOT/'recourse/极彩新牌表.xlsx']:
    book=openpyxl.load_workbook(path,read_only=True,data_only=True)
    for sheet in book:
        for index,values in enumerate(sheet.values,1):
            if any(v is not None for v in values):
                rows.append({'book':path.name,'sheet':sheet.title,'row':index,'values':list(values)})
    book.close()
    with ZipFile(path) as z:
        for name in z.namelist():
            if not name.startswith('xl/drawings/') or not name.endswith('.vml'): continue
            relname=str(PurePosixPath(name).parent/'_rels'/(PurePosixPath(name).name+'.rels'))
            if relname not in z.namelist(): continue
            rels={n.get('Id'):n.get('Target') for n in ET.fromstring(z.read(relname))}
            for shape in ET.fromstring(z.read(name)).findall('{urn:schemas-microsoft-com:vml}shape'):
                fill=shape.find('{urn:schemas-microsoft-com:vml}fill')
                at=shape.find('{urn:schemas-microsoft-com:office:excel}ClientData')
                if fill is None or at is None: continue
                rid=fill.get('{urn:schemas-microsoft-com:office:office}relid')
                if rid not in rels: continue
                drawings.append({'book':path.name,'drawing':name,'file':PurePosixPath(rels[rid]).name,'row':int(at.find('{*}Row').text)+1,'col':int(at.find('{*}Column').text)+1})
        for name in z.namelist():
            if not name.startswith('xl/drawings/drawing') or not name.endswith('.xml'): continue
            relname=str(PurePosixPath(name).parent/'_rels'/(PurePosixPath(name).name+'.rels'))
            if relname not in z.namelist(): continue
            rels={n.get('Id'):n.get('Target') for n in ET.fromstring(z.read(relname))}
            for anchor in ET.fromstring(z.read(name)):
                at=anchor.find('{*}from')
                blip=anchor.find('.//{*}blip')
                if at is None or blip is None: continue
                rid=blip.get('{http://schemas.openxmlformats.org/officeDocument/2006/relationships}embed')
                target=rels.get(rid,'')
                file=PurePosixPath(target).name
                drawings.append({'book':path.name,'drawing':name,'file':file,'row':int(at.find('{*}row').text)+1,'col':int(at.find('{*}col').text)+1})
dump('excel-rows.json',rows);dump('drawings.json',drawings)
print('Batch image count:',len(files),'Excel rows:',len(rows),'embedded references:',len(drawings))
for book in sorted(set(r['book'] for r in rows)):
    print('WORKBOOK',book)
    for sheet in dict.fromkeys(r['sheet'] for r in rows if r['book']==book):
        print('SHEET',sheet,'HEADERS',next(r['values'] for r in rows if r['book']==book and r['sheet']==sheet))
print('IMAGE ROWS:')
for f in snapshot:
    refs=[d for d in drawings if d['file']==f['file'] and d['book']=='极彩新牌表.xlsx']
    rr=[r for r in rows if r['book']=='极彩新牌表.xlsx' and any(d['row']==r['row'] for d in refs)]
    print(f['file'],[(r['row'],r['values'][:9]) for r in rr])
