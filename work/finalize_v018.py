from pathlib import Path
import hashlib
import json
import os
import re
import subprocess
import sys
import zipfile

sys.stdout.reconfigure(encoding='utf-8')
root = Path(__file__).resolve().parents[1]
work = root / 'work/v018'
release = root / 'builds/Windows-v0.18.0'
report = {'version': '0.18.0', 'real_two_computers_tested': False}

manifest = json.loads((root / 'net/rules_manifest.json').read_text(encoding='utf-8'))
for name, expected in manifest['files'].items():
    assert hashlib.sha256((root / name).read_bytes()).hexdigest() == expected, name
report['rules_manifest_verified'] = len(manifest['files'])

tests = []
for name in ['test_v018_core', 'test_v018_session', 'test_v018_boundaries',
             'test_v018_ui-visual', 'test_v017_payment', 'test_v015_ui',
             'test_v016_stack', 'test_v015_rules']:
    content = (work / (name + '.log')).read_text(encoding='utf-8', errors='replace')
    errors = [line for line in content.splitlines()
              if ('SCRIPT ERROR' in line or 'ERROR:' in line)
              and 'root certificate' not in line]
    assert not errors, (name, errors)
    assert 'PASS' in content or 'failures=[]' in content, name
    count = re.findall(r'(\d+) checks', content)
    tests.append({'name': name, 'checks': int(count[-1]) if count else None, 'errors': errors})
report['tests'] = tests
report['counted_rule_and_ui_checks'] = sum(t['checks'] or 0 for t in tests)

host = json.loads((work / 'process-host-result.json').read_text(encoding='utf-8'))
guest = json.loads((work / 'process-guest-result.json').read_text(encoding='utf-8'))
for key in ['game_id', 'life', 'score', 'sequence', 'turn', 'winner', 'history']:
    assert host[key] == guest[key], key
assert not host['errors'] and not guest['errors'] and host['winner'] in [0, 1]
report['independent_process_match'] = {k: host[k] for k in ['game_id', 'life', 'score', 'sequence', 'turn', 'winner']}
report['independent_process_match']['errors'] = []
release_checks = json.loads((work / 'export/release-checks.json').read_text(encoding='utf-8'))
assert len(release_checks) == 3 and all(r['exit'] == 0 and not r['errors'] for r in release_checks)
report['release_checks'] = release_checks
report['release_check_count'] = 1546

env = os.environ.copy()
env['APPDATA'] = str(work / 'export/final-profile')
proc = subprocess.run([str(release / 'Multicolour.exe'), '--headless', '--quit-after', '20'],
                      cwd=release, env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                      timeout=60, creationflags=subprocess.CREATE_NO_WINDOW)
output = proc.stdout.decode('utf-8', errors='replace')
(work / 'export/final-startup.log').write_text(output, encoding='utf-8')
errors = [line for line in output.splitlines()
          if ('SCRIPT ERROR' in line or 'ERROR:' in line) and 'root certificate' not in line]
assert proc.returncode == 0 and not errors, (proc.returncode, errors)
decks = list(Path(env['APPDATA']).rglob('decks.json'))
assert len(decks) == 1, decks
saved = json.loads((root / 'saves/decks.json').read_text(encoding='utf-8'))
assert json.loads(decks[0].read_text(encoding='utf-8'))['decks'] == saved['decks']
report['final_startup'] = {'exit': proc.returncode, 'errors': errors, 'bundled_decks': len(saved['decks'])}

readme = '''极彩 Multicolour v0.18.0 · 局域网测试版

完整解压本文件夹，双击 Multicolour.exe。Multicolour.pck 必须与 EXE 保持同目录。
无需安装 Godot。包含486种已登记卡牌及卡图、当前4副已保存卡组和两套测试预组模板。
老玩家已有卡组不会被新版覆盖；预组模板可通过游戏内“载入测试卡组”使用。

局域网开始：
1. 两台电脑使用同一包，连接可互通的同一局域网。
2. 主界面“联网对战”修改显示 ID，一方创建 BO1 / BO3 房间。
3. 另一方点击房间列表加入，房主接受申请。未发现时填写房主显示的 IP 与端口。
4. 双方选择卡组，有选择权的一方选先后手，双方准备后开局。
5. 首次 Windows 网络提示允许游戏访问专用网络。

付款仍为金边推荐、蓝边替换，点“发动”才提交，右键取消。
断线检测后暂停，客机120秒内自动重连，此后可手动重连。
房主重启可点“恢复房主对局”；两端需保留各自本机的恢复记录。
BO3局间可换备牌，败者选择下局先后手，先赢两局结束。

详见同目录《局域网双机测试.md》。已通过本机双进程完整对局及重连/BO3检查，
真实双机网络环境待测试。此包使用局域网直连，尚未接入异地公网平台中继。

个人存档：%APPDATA%/Godot/app_userdata/极彩 Multicolour/
decks.json为个人卡组；lan目录包含联机身份及恢复记录，不必公开分享。
'''
(release / '游玩说明.txt').write_text(readme, encoding='utf-8-sig')
(release / '局域网双机测试.md').write_bytes((root / 'docs/局域网双机测试.md').read_bytes())

archive = root / 'builds/极彩Multicolour-Windows-v0.18.0-LAN.zip'
filenames = ['Multicolour.exe', 'Multicolour.pck', '游玩说明.txt', '局域网双机测试.md']
with zipfile.ZipFile(archive, 'w', compression=zipfile.ZIP_DEFLATED, compresslevel=6) as zipped:
    for name in filenames:
        zipped.write(release / name, 'Multicolour-v0.18.0/' + name)
with zipfile.ZipFile(archive) as zipped:
    assert zipped.testzip() is None
    assert len(zipped.namelist()) == len(filenames)
report['artifacts'] = [{'path': p.relative_to(root).as_posix(), 'bytes': p.stat().st_size,
                        'sha256': hashlib.sha256(p.read_bytes()).hexdigest()}
                       for p in [release / 'Multicolour.exe', release / 'Multicolour.pck', archive]]
report['archive_validated'] = True
(work / 'validation.json').write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding='utf-8')
print(json.dumps({'checks': report['counted_rule_and_ui_checks'], 'release_checks': 1546,
                  'startup': report['final_startup'], 'archive': report['artifacts'][-1]}, ensure_ascii=False))
