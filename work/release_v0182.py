from pathlib import Path
import hashlib, json, os, re, subprocess, sys, zipfile

sys.stdout.reconfigure(encoding='utf-8')
root = Path(__file__).resolve().parents[1]
work = root / 'work/v0182'
out = root / 'builds/Windows-v0.18.2'
archive = root / 'builds/Multicolour-v0.18.2-win64.zip'
env = os.environ.copy()
report = {'version': '0.18.2', 'real_two_computers_tested': False, 'usb_tested': False, 'tests': []}

def digest(path):
    h = hashlib.sha256()
    with path.open('rb') as f:
        for chunk in iter(lambda: f.read(4 * 1024 * 1024), b''):
            h.update(chunk)
    return h.hexdigest()

def errors(text):
    return [s for s in text.splitlines() if ('SCRIPT ERROR' in s or 'ERROR:' in s) and 'root certificate' not in s]

manifest = json.loads((root/'net/rules_manifest.json').read_text(encoding='utf-8'))
for path, expected in manifest['files'].items():
    assert digest(root/path) == expected, path
for name in ['test_v0182_rules', 'test_v098_rules', 'test_v0181_series', 'test_v0181_latency']:
    text = (work/(name+'.log')).read_text(encoding='utf-8', errors='replace')
    assert not errors(text), (name, errors(text))
    assert '0 failures' in text or 'failures=[]' in text, text[-1000:]
    report['tests'].append({'name': name, 'checks': int(re.findall(r'(\d+) checks', text)[-1])})
report['checks'] = sum(t['checks'] for t in report['tests'])

if '--package-only' not in sys.argv:
    env['APPDATA'] = str(work/'export/release-profile')
    proc = subprocess.run([str(root/'builds/Verify-v0.18.2/Multicolour.exe'), '--headless', '--', 'first'],
                          cwd=root, env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                          timeout=75, creationflags=subprocess.CREATE_NO_WINDOW)
    text = proc.stdout.decode('utf-8', errors='replace')
    (work/'export/verify-first.log').write_text(text, encoding='utf-8')
    assert proc.returncode == 0 and not errors(text), (proc.returncode, errors(text))
text = (work/'export/verify-first.log').read_text(encoding='utf-8')
assert '0 failures' in text, text[-1000:]
report['release_first_checks'] = int(re.findall(r'(\d+) checks', text)[-1])
print('Release verification passed:', report['release_first_checks'], flush=True)

if '--package-only' not in sys.argv:
    subprocess.run([sys.executable, str(root/'work/export_v0182.py')], cwd=root, timeout=300, check=True)
export_text = (work/'export/export.log').read_text(encoding='utf-8', errors='replace')
assert not errors(export_text), errors(export_text)
assert 'BUNDLED_DECKS: 4; REGISTERED_CARDS: 486' in export_text

guide = '''极彩 Multicolour v0.18.2 · Windows 64 位

完整解压到电脑本地文件夹，双击 Multicolour.exe。
Multicolour.exe 和 Multicolour.pck 必须保持同目录，无需安装 Godot。
包含全部486种已登记卡牌及卡图、当前4副已保存卡组和两套测试预组模板。

本版修复：自机幽幽子死亡后返回自机区仍触发打1，可以选择是否发动，
每回合最多两次；结晶以竖直、未横置状态进入颜色盘。

如果传输后提示文件/目录损坏或无法读取：
1. 在解压前，用压缩包旁的 CheckTransfer-v0.18.2.cmd 检查 ZIP。
   必须将 ZIP 和该校验工具放在同一文件夹。PASS 才表示与本次源包一致。
2. 完整解压到电脑本地，再双击 VerifyFiles.cmd 检查 EXE/PCK。
   两项 PASS 才表示游戏文件完整。FAIL/MISSING/UNREADABLE 时先重新复制。
3. 若源电脑通过、接收电脑不通过，需排查传输或存储环节；当前无法
   仅凭报错判断 U 盘硬件是否损坏。校验只读，不修复或格式化磁盘。
4. 若校验通过仍不能运行，保留完整报错及游戏日志继续排查。

局域网：双方使用同一版本，一方建房，另一方加入或输入房主 IP。
每局硬币决定先手；BO3 本局投降仅结束一局，两胜结束系列赛。
房间及战场显示双方往返延迟。断线检测后暂停并尝试恢复。
详见 LAN-Guide.md、VPN-Guide.md；真实双机和异地网络仍待用户验证。

个人卡组和设置保存在 %APPDATA%/Godot/app_userdata/极彩 Multicolour/。
已有卡组不会被覆盖。联机双方必须更新同一版本；旧版未结束对局不可恢复。
'''
(out/'README.txt').write_text(guide, encoding='utf-8-sig')
for name, source in [('LAN-Guide.md','局域网双机测试.md'), ('VPN-Guide.md','虚拟局域网异地联机.md')]:
    (out/name).write_bytes((root/'docs'/source).read_bytes())

payload = {name: {'bytes': (out/name).stat().st_size, 'sha256': digest(out/name)}
           for name in ['Multicolour.exe', 'Multicolour.pck']}
(out/'SHA256SUMS.json').write_text(json.dumps({'algorithm': 'SHA256', 'files': payload}, indent=2), encoding='ascii')

def write_cmd(path, command):
    text = ('@echo off\r\nsetlocal\r\nset "MULTICOLOUR_VERIFY_DIR=%~dp0"\r\n'
            'powershell.exe -NoLogo -NoProfile -Command "' + command + '"\r\n'
            'set "MULTICOLOUR_VERIFY_RESULT=%ERRORLEVEL%"\r\n'
            'if not defined MULTICOLOUR_CHECK_NO_PAUSE pause\r\n'
            'exit /b %MULTICOLOUR_VERIFY_RESULT%\r\n')
    path.write_bytes(text.encode('ascii'))

hash_function = (
    "function Read-Sha256([string]$p) { $stream=[IO.File]::OpenRead($p); $sha=[Security.Cryptography.SHA256]::Create(); "
    "try { return [BitConverter]::ToString($sha.ComputeHash($stream)).Replace('-','').ToLowerInvariant() } "
    "finally { $stream.Dispose(); $sha.Dispose() } }; ")
file_command = hash_function + (
    "$ErrorActionPreference='Stop'; $base=$env:MULTICOLOUR_VERIFY_DIR; "
    "try { $m=Get-Content -LiteralPath (Join-Path $base 'SHA256SUMS.json') -Raw | ConvertFrom-Json; "
    "$bad=$false; foreach($name in @('Multicolour.exe','Multicolour.pck')) { "
    "try { $expected=$m.files.PSObject.Properties[$name].Value; if($null -eq $expected) { throw 'Missing expected checksum' }; "
    "$p=Join-Path $base $name; $f=Get-Item -LiteralPath $p; $h=Read-Sha256 $p; "
    "if($f.Length -eq $expected.bytes -and $h -eq $expected.sha256) { Write-Host ('PASS '+$name) } "
    "else { $bad=$true; Write-Host ('FAIL '+$name+' - size or SHA256 mismatch') } "
    "} catch { $bad=$true; Write-Host ('MISSING/UNREADABLE '+$name+': '+$_.Exception.Message) } }; "
    "if($bad) { exit 1 }; Write-Host 'All game files match the release.'; exit 0 "
    "} catch { Write-Host ('UNREADABLE manifest: '+$_.Exception.Message); exit 2 }")
write_cmd(out/'VerifyFiles.cmd', file_command)

def checker(path, expected_code, label):
    check_env = env.copy(); check_env['MULTICOLOUR_CHECK_NO_PAUSE'] = '1'
    proc = subprocess.run(['cmd.exe', '/d', '/c', str(path)], env=check_env, cwd=path.parent,
                          stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=45,
                          creationflags=subprocess.CREATE_NO_WINDOW)
    text = proc.stdout.decode('utf-8', errors='replace')
    (work/(label+'.log')).write_text(text, encoding='utf-8')
    assert proc.returncode == expected_code, (label, proc.returncode, text)
    return text

assert checker(out/'VerifyFiles.cmd', 0, 'checker-original').count('PASS ') == 2
fixture = work/'checker-fixture'; fixture.mkdir(exist_ok=True)
for name in ['VerifyFiles.cmd','SHA256SUMS.json']:
    (fixture/name).write_bytes((out/name).read_bytes())
(fixture/'Multicolour.exe').write_bytes(b'deliberately truncated fixture, not an executable')
negative = checker(fixture/'VerifyFiles.cmd', 1, 'checker-damaged')
assert 'FAIL Multicolour.exe' in negative and 'MISSING/UNREADABLE Multicolour.pck' in negative

names = ['Multicolour.exe','Multicolour.pck','README.txt','LAN-Guide.md','VPN-Guide.md','SHA256SUMS.json','VerifyFiles.cmd']
with zipfile.ZipFile(archive, 'w', compression=zipfile.ZIP_DEFLATED, compresslevel=6) as z:
    for name in names:
        z.write(out/name, 'Multicolour-v0.18.2/'+name)
with zipfile.ZipFile(archive) as z:
    assert z.testzip() is None
    assert sorted(z.namelist()) == sorted('Multicolour-v0.18.2/'+name for name in names)
    # Local transfer rehearsal: extract into a new directory and verify bytes.
    z.extractall(work/'extracted')
extracted = work/'extracted/Multicolour-v0.18.2'
for name in names:
    assert digest(extracted/name) == digest(out/name), name
assert checker(extracted/'VerifyFiles.cmd', 0, 'checker-extracted').count('PASS ') == 2

archive_hash = digest(archive)
(archive.with_suffix('.zip.sha256.txt')).write_text(archive_hash+'  '+archive.name+'\n', encoding='ascii')
transfer_tool = root/'builds/CheckTransfer-v0.18.2.cmd'
transfer_command = hash_function + (
    "$ErrorActionPreference='Stop'; try { $p=Join-Path $env:MULTICOLOUR_VERIFY_DIR '"+archive.name+"'; "
    "$h=Read-Sha256 $p; "
    "if($h -eq '"+archive_hash+"') { Write-Host 'PASS - ZIP matches the original release. Extract to a local folder.'; exit 0 }; "
    "Write-Host 'FAIL - ZIP checksum mismatch. Copy again from the verified source.'; exit 1 "
    "} catch { Write-Host ('MISSING/UNREADABLE ZIP: '+$_.Exception.Message); exit 2 }")
write_cmd(transfer_tool, transfer_command)
assert 'PASS - ZIP' in checker(transfer_tool, 0, 'checker-archive')
(fixture/transfer_tool.name).write_bytes(transfer_tool.read_bytes())
(fixture/archive.name).write_bytes(b'intentionally damaged ZIP fixture')
assert 'FAIL - ZIP' in checker(fixture/transfer_tool.name, 1, 'checker-archive-damaged')

env['APPDATA'] = str(work/'export/final-profile')
proc = subprocess.run([str(extracted/'Multicolour.exe'), '--headless', '--quit-after', '20'],
                      cwd=extracted, env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                      timeout=60, creationflags=subprocess.CREATE_NO_WINDOW)
text = proc.stdout.decode('utf-8', errors='replace')
(work/'export/final-startup.log').write_text(text, encoding='utf-8')
assert proc.returncode == 0 and not errors(text), (proc.returncode, errors(text))
actual = list(Path(env['APPDATA']).rglob('decks.json')); assert len(actual) == 1
assert json.loads(actual[0].read_text(encoding='utf-8'))['decks'] == json.loads((root/'saves/decks.json').read_text(encoding='utf-8'))['decks']
report.update({'archive_crc_validated': True, 'extracted_bytes_identical': True,
               'checksum_tools_positive_and_negative_passed': True,
               'final_extracted_startup': {'exit': 0, 'errors': [], 'bundled_decks': 4}})
report['artifacts'] = [{'path': p.relative_to(root).as_posix(), 'bytes': p.stat().st_size, 'sha256': digest(p)}
                       for p in [out/'Multicolour.exe', out/'Multicolour.pck', archive, transfer_tool]]
(work/'validation.json').write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding='utf-8')
print(json.dumps(report, ensure_ascii=False), flush=True)
