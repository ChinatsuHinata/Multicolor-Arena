from pathlib import Path
import hashlib,json

root=Path(__file__).resolve().parents[1]
(root/'work/bugfix0921/export').mkdir(parents=True,exist_ok=True)
(root/'builds/Windows-1.0-bugfix0921').mkdir(parents=True,exist_ok=True)
for source,destination in [('export_portable.py','export_bugs0921.py'),('verify_export_portable.py','verify_export_bugs0921.py'),('release_portable.py','release_bugs0921.py')]:
    text=(root/'work'/source).read_text(encoding='utf-8')
    for old,new in [('work/portable','work/bugfix0921'),('Windows-portable','Windows-1.0-bugfix0921'),('Verify-portable','Verify-bugfix0921'),('MulticolorArena-1.0-portable-win64','MulticolorArena-1.0-bugfix0921-win64'),('CheckTransfer-portable','CheckTransfer-bugfix0921'),('work/export_portable.py','work/export_bugs0921.py')]:
        text=text.replace(old,new)
    if source=='release_portable.py':
        text=text.replace("['test_portable',", "['test_bugs0921_rules', 'test_bugs0921_ui-visual', 'test_bugs0921_network', 'test_portable',")
        text=text.replace('Windows 64 位（卡组/观战/回放更新）','Windows 64 位（2026-09-21 测试问题修复）')
        text=text.replace('包含486种卡牌及卡图','包含486条卡牌记录及卡图（含兼容旧卡组的异版记录）')
        text=text.replace('联机：两名玩家使用同一包', '本次修复卡牌颜色费用、异能时机、死亡检查、指示物与要石显示、联机入房提示。\\n新版规则与旧发行包不兼容，双方与观众都需使用这一份完整更新包。\\n\\n联机：两名玩家使用同一包')
    (root/'work'/destination).write_text(text,encoding='utf-8')
preset=root/'export_presets.cfg'
preset.write_text(preset.read_text(encoding='utf-8').replace('builds/Windows-portable/MulticolorArena.exe','builds/Windows-1.0-bugfix0921/MulticolorArena.exe'),encoding='utf-8')
paths=list((root/'net').glob('*.gd'))+list((root/'scripts/rules').glob('*.gd'))+[root/'scripts/card_database.gd',root/'scripts/deck_store.gd',root/'scripts/replay_archive.gd']
files={p.relative_to(root).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(paths)}
(root/'net/rules_manifest.json').write_text(json.dumps({'version':'1.0-bugfix0921','files':files},ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print('Prepared fresh release paths and manifest:',len(files),'files')
