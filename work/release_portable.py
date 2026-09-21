from pathlib import Path
import hashlib, json, os, re, subprocess, sys, zipfile

sys.stdout.reconfigure(encoding='utf-8')
root = Path(__file__).resolve().parents[1]
work = root / 'work/portable'
out = root / 'builds/Windows-portable'
archive = root / 'builds/MulticolorArena-1.0-portable-win64.zip'
env = os.environ.copy()
report = {'version': '1.0', 'real_two_computers_tested': False, 'usb_tested': False, 'tests': []}

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
for name in ['test_portable', 'test_portable_ui-visual', 'test_v0182_rules', 'test_v0181_series', 'test_v0181_ui-visual', 'test_v1_network', 'test_v1_ui-visual']:
    text = (root/'work/v1'/(name+'.log')).read_text(encoding='utf-8', errors='replace')
    assert not errors(text), (name, errors(text))
    assert '0 failures' in text or 'failures=[]' in text or '[] failures' in text, text[-1000:]
    report['tests'].append({'name': name, 'checks': int(re.findall(r'(\d+) checks', text)[-1])})
report['checks'] = sum(t['checks'] for t in report['tests'])

text = (work/'export/verify-first.log').read_text(encoding='utf-8')
assert '0 failures' in text, text[-1000:]
report['release_first_checks'] = int(re.findall(r'(\d+) checks', text)[-1])
print('Release verification passed:', report['release_first_checks'], flush=True)

if '--package-only' not in sys.argv:
    subprocess.run([sys.executable, str(root/'work/export_portable.py')], cwd=root, timeout=300, check=True)
export_text = (work/'export/export.log').read_text(encoding='utf-8', errors='replace')
assert not errors(export_text), errors(export_text)
assert 'BUNDLED_DECKS: 4; REGISTERED_CARDS: 486' in export_text

guide = 'multicolor:arena 1.0 · Windows 64 位（卡组/观战/回放更新）\n\n完整解压到可写入的本地文件夹，再运行 MulticolorArena.exe。\nMulticolorArena.exe 和 MulticolorArena.pck 保持同目录，无需安装 Godot。\n包含486种卡牌及卡图、四副保存卡组，未包含开发者的联机身份和回放。\n\n首次运行会在 EXE 旁创建 deck/预设卡组（四个 .mdeck）和 replay 文件夹。\n分享卡组：把 .mdeck 发给对方，放入 deck 后重新进入编辑牌组即可看到。\n保存卡组后更新对应文件；旧个人卡组首次自动迁移，原文件保留。\n回放：单局人机、BO1 或整场 BO3 结束后询问保存；主界面“对局回放”播放。\n.mreply 保存在 replay 文件夹，记录录制端可见信息，用同一版游戏播放。\n\n联机：两名玩家使用同一包，房主建房，另一人加入并获得房主接受。\n观众点击“观战”，最多4人，隐藏双方手牌和牌库，不能操作对局。\n观战端口为对战端口+1（默认47862），独立限速，不等待观众确认。\n检测掉线后锁住操作，30秒内重连继续；超时掉线方整场判负。\n房主失联时客机结果注明“本地记录”；朋友间网络互断可能有结果分歧。\n详见 Portable-Guide.md、LAN-Guide.md、VPN-Guide.md。\n真实双机/三机与异地网络仍需在实际设备验证。\n\n传输检查：ZIP旁 CheckTransfer-portable.cmd 检查压缩包；\n完整解压后 VerifyFiles.cmd 检查 EXE/PCK。均为只读检查。\n若本地通过、U盘或接收电脑失败，请重新复制并排查传输/存储环节。\n'
(out/'README.txt').write_text(guide, encoding='utf-8-sig')
for name, source in [('LAN-Guide.md','局域网双机测试.md'), ('VPN-Guide.md','虚拟局域网异地联机.md'), ('Portable-Guide.md','卡组分享、观战与回放.md')]:
    (out/name).write_text((root/'docs'/source).read_text(encoding='utf-8').replace('卡组分享、观战与回放.md','Portable-Guide.md').replace('虚拟局域网异地联机.md','VPN-Guide.md').replace('局域网双机测试.md','LAN-Guide.md'),encoding='utf-8')

payload = {name: {'bytes': (out/name).stat().st_size, 'sha256': digest(out/name)}
           for name in ['MulticolorArena.exe', 'MulticolorArena.pck']}
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
    "$bad=$false; foreach($name in @('MulticolorArena.exe','MulticolorArena.pck')) { "
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
(fixture/'MulticolorArena.exe').write_bytes(b'deliberately truncated fixture, not an executable')
negative = checker(fixture/'VerifyFiles.cmd', 1, 'checker-damaged')
assert 'FAIL MulticolorArena.exe' in negative and 'MISSING/UNREADABLE MulticolorArena.pck' in negative

names = ['MulticolorArena.exe','MulticolorArena.pck','README.txt','LAN-Guide.md','VPN-Guide.md','Portable-Guide.md','SHA256SUMS.json','VerifyFiles.cmd']
with zipfile.ZipFile(archive, 'w', compression=zipfile.ZIP_DEFLATED, compresslevel=6) as z:
    for name in names:
        z.write(out/name, 'MulticolorArena-1.0/'+name)
with zipfile.ZipFile(archive) as z:
    assert z.testzip() is None
    assert sorted(z.namelist()) == sorted('MulticolorArena-1.0/'+name for name in names)
    # Local transfer rehearsal: extract into a new directory and verify bytes.
    z.extractall(work/'extracted')
extracted = work/'extracted/MulticolorArena-1.0'
for name in names:
    assert digest(extracted/name) == digest(out/name), name
assert checker(extracted/'VerifyFiles.cmd', 0, 'checker-extracted').count('PASS ') == 2

archive_hash = digest(archive)
(archive.with_suffix('.zip.sha256.txt')).write_text(archive_hash+'  '+archive.name+'\n', encoding='ascii')
transfer_tool = root/'builds/CheckTransfer-portable.cmd'
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
proc = subprocess.run([str(extracted/'MulticolorArena.exe'), '--headless', '--quit-after', '20'],
                      cwd=extracted, env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                      timeout=60, creationflags=subprocess.CREATE_NO_WINDOW)
text = proc.stdout.decode('utf-8', errors='replace')
(work/'export/final-startup.log').write_text(text, encoding='utf-8')
assert proc.returncode == 0 and not errors(text), (proc.returncode, errors(text))
actual=list((extracted/'deck').rglob('*.mdeck'));assert len(actual)==4
actual_decks=[json.loads(p.read_text(encoding='utf-8'))['deck'] for p in actual]
source=json.loads((root/'saves/decks.json').read_text(encoding='utf-8'))['decks']
assert sorted(actual_decks,key=lambda d:d['id'])==sorted(source,key=lambda d:d['id'])
assert (extracted/'replay').is_dir()
report.update({'archive_crc_validated': True, 'extracted_bytes_identical': True,
               'checksum_tools_positive_and_negative_passed': True,
               'final_extracted_startup': {'exit': 0, 'errors': [], 'bundled_decks': 4}})
report['artifacts'] = [{'path': p.relative_to(root).as_posix(), 'bytes': p.stat().st_size, 'sha256': digest(p)}
                       for p in [out/'MulticolorArena.exe', out/'MulticolorArena.pck', archive, transfer_tool]]
(work/'validation.json').write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding='utf-8')
print(json.dumps(report, ensure_ascii=False), flush=True)
