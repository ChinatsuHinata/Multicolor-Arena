from pathlib import Path
import hashlib,json,os,re,subprocess,sys,zipfile
sys.stdout.reconfigure(encoding='utf-8')
root=Path(__file__).resolve().parents[1]
work=root/'work/v0181'
out=root/'builds/Windows-v0.18.1'
env=os.environ.copy()
report={'version':'0.18.1','real_two_computers_tested':False,'virtual_network_tested':False,'tests':[]}
manifest=json.loads((root/'net/rules_manifest.json').read_text(encoding='utf-8'))
for path,digest in manifest['files'].items():
    assert hashlib.sha256((root/path).read_bytes()).hexdigest()==digest,path
def errors(text):
    return [s for s in text.splitlines() if ('SCRIPT ERROR' in s or 'ERROR:' in s) and 'root certificate' not in s]
for name in ['test_v0181_latency','test_v0181_series','test_v0181_ui-visual']:
    text=(work/(name+'.log')).read_text(encoding='utf-8',errors='replace')
    assert not errors(text),(name,errors(text))
    assert 'failures=[]' in text or '[] failures' in text
    count=int(re.findall(r'(\d+) checks',text)[-1])
    report['tests'].append({'name':name,'checks':count,'errors':[]})
report['checks']=sum(t['checks'] for t in report['tests'])
env['APPDATA']=str(work/'export/release-profile')
proc=subprocess.run([str(root/'builds/Verify-v0.18.1/Multicolour.exe'),'--headless','--','first'],cwd=root,env=env,
                    stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=75,creationflags=subprocess.CREATE_NO_WINDOW)
text=proc.stdout.decode('utf-8',errors='replace');(work/'export/verify-first.log').write_text(text,encoding='utf-8')
assert proc.returncode==0 and not errors(text),(proc.returncode,errors(text))
assert '0 failures' in text,text[-1000:]
report['release_first_checks']=int(re.findall(r'(\d+) checks',text)[-1])
print('Release verification passed:',report['release_first_checks'],flush=True)
proc=subprocess.run([sys.executable,str(root/'work/export_v0181.py')],cwd=root,timeout=300)
assert proc.returncode==0
env['APPDATA']=str(work/'export/final-profile')
proc=subprocess.run([str(out/'Multicolour.exe'),'--headless','--quit-after','20'],cwd=out,env=env,
                    stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=60,creationflags=subprocess.CREATE_NO_WINDOW)
text=proc.stdout.decode('utf-8',errors='replace');(work/'export/final-startup.log').write_text(text,encoding='utf-8')
assert proc.returncode==0 and not errors(text),(proc.returncode,errors(text))
actual=list(Path(env['APPDATA']).rglob('decks.json'));assert len(actual)==1
assert json.loads(actual[0].read_text(encoding='utf-8'))['decks']==json.loads((root/'saves/decks.json').read_text(encoding='utf-8'))['decks']
report['final_startup']={'exit':0,'errors':[],'bundled_decks':4}
guide='''极彩 Multicolour v0.18.1 · 局域网测试版

完整解压后双击 Multicolour.exe，Multicolour.pck 必须保持同目录，无需安装 Godot。
含486种已登记卡牌及卡图、当前4副卡组及两套测试预组模板。
个人已有卡组不会被覆盖。双方必须使用相同版本；旧版未结束联机对局不能在新版恢复。

联网对战：一方建房，另一方点击房间或输入IP加入，房主接受申请。
双方选择卡组并准备。每局投一次硬币决定先后手，正面房主先手、反面客机先手。
硬币结果会展示并进入记录，重连不会重投。
本局投降只结束当前一局。BO3未达到两胜时点“下一局”进入准备，保留换备牌。
房间和战场右上角显示双方往返延迟（ms），约每2秒更新，断线时显示“已断开”。

跨不同网络可使用通用虚拟局域网，填房主虚拟IP加入。无需将游戏上架平台。
详见同目录《局域网双机测试.md》和《虚拟局域网异地联机.md》。
真实双机/异地网络仍待验证，本次没有安装组网工具或修改系统防火墙。

个人存档：%APPDATA%/Godot/app_userdata/极彩 Multicolour/
decks.json为个人卡组，lan目录为身份及对局恢复信息，请保留在各自本机。
'''
(out/'游玩说明.txt').write_text(guide,encoding='utf-8-sig')
for name in ['局域网双机测试.md','虚拟局域网异地联机.md']:(out/name).write_bytes((root/'docs'/name).read_bytes())
archive=root/'builds/极彩Multicolour-Windows-v0.18.1-LAN.zip'
names=['Multicolour.exe','Multicolour.pck','游玩说明.txt','局域网双机测试.md','虚拟局域网异地联机.md']
with zipfile.ZipFile(archive,'w',compression=zipfile.ZIP_DEFLATED,compresslevel=6) as z:
    for name in names:z.write(out/name,'Multicolour-v0.18.1/'+name)
with zipfile.ZipFile(archive) as z:
    assert z.testzip() is None
    assert len(z.namelist())==len(names)
report['artifacts']=[{'path':p.relative_to(root).as_posix(),'bytes':p.stat().st_size,'sha256':hashlib.sha256(p.read_bytes()).hexdigest()} for p in [out/'Multicolour.exe',out/'Multicolour.pck',archive]]
report['archive_validated']=True
(work/'validation.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps(report,ensure_ascii=False),flush=True)
