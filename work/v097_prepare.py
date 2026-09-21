from pathlib import Path
import json, hashlib, re, shutil

root = Path(r'C:\Users\tzx20\Documents\test').resolve()
backup = root/'work/v097-backup'
assert not backup.exists(), 'Migration backup already exists; inspect state before retrying.'
ids=json.loads(re.search(r'^const IDS=(\[[^\]]*\])', (root/'scripts/card_database.gd').read_text(encoding='utf-8-sig'),re.M)[1])
assert len(ids)==65 and len(set(ids))==65
rows=[]
for card_id in ids:
    definition=root/'cards'/f'{card_id}.json'
    data=json.loads(definition.read_text(encoding='utf-8-sig'))
    source=(root/data['图片'].removeprefix('res://')).resolve()
    if not source.is_file():
        assert card_id=='177', f'Unexpected missing image {card_id}'
        source=(root/'recourse/新增卡片/image177.png').resolve()
    destination=(root/'recourse/数据库'/f'{card_id}{source.suffix.lower()}').resolve()
    assert source.is_relative_to(root) and destination.is_relative_to(root)
    assert source.is_file() and not destination.exists()
    rows.append({'id':card_id,'source':str(source),'destination':str(destination),
                 'definition':str(definition),'old_image':data['图片'],
                 'image':'res://'+destination.relative_to(root).as_posix(),
                 'sha256':hashlib.sha256(source.read_bytes()).hexdigest().upper()})
assert len({row['source'] for row in rows})==65 and len({row['destination'] for row in rows})==65
queue=root/'recourse/新增卡片'
pending={p.relative_to(queue).as_posix():hashlib.sha256(p.read_bytes()).hexdigest().upper() for p in queue.rglob('*') if p.is_file()}
backup.mkdir()
for directory in ['cards','scripts','docs']:
    shutil.copytree(root/directory, backup/directory)
for filename in ['使用说明.md','开发者日志.md']:
    shutil.copy2(root/filename,backup/filename)
metadata=backup/'原导入配置'; metadata.mkdir()
for row in rows:
    sidecar=Path(row['source']+'.import')
    if sidecar.exists(): shutil.copy2(sidecar,metadata/(row['id']+sidecar.suffix))
manifest={'root':str(root),'save_sha256':hashlib.sha256((root/'saves/decks.json').read_bytes()).hexdigest().upper(),
          'ids':ids,'pending_before':pending,'moves':rows}
(root/'work/v097-migration.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print('Prepared: 65 registered images, including existing card 177. No files moved yet.')
print('Untouched pending queue files after excluding existing 177 image/metadata:',len(pending)-2)
