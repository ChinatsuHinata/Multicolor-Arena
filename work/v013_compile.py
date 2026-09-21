from pathlib import Path
import json,re,subprocess,os
R=Path.cwd()
for p in (R/'cards').glob('*.json'):
 d=json.loads(p.read_text(encoding='utf-8'));changed=False
 if d.get('衍生物'):
  d['类别']=d['类别'].replace('衍生物','').replace('普通','');changed=True
 if d['类别']=='符卡' and not d.get('计时'):
  m=re.search(r'计时(\d+)',d['能力文字'])
  if m:d['计时']=int(m[1]);changed=True
 if d['卡牌ID']=='character-rei-026' and '弃置一张绿色牌' in d['能力文字']:
  if not any(a.get('参数',{}).get('效果')=='sanae_search' for a in d['能力绑定']):d['能力绑定'].append({'实现':'roster','名称':d['能力文字'].split('自机能力：')[-1],'参数':{'效果':'sanae_search'}});changed=True
 if changed:p.write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
env=os.environ.copy();env['APPDATA']=str(R/'work/appdata')
p=subprocess.run([r'C:\Users\tzx20\Desktop\Godot_v4.7.2-stable_win64.exe','--headless','--path',str(R),'--editor','--import','--log-file',str(R/'work/v013/import.log')],env=env,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=60,creationflags=subprocess.CREATE_NO_WINDOW)
s=p.stdout.decode('utf-8',errors='replace');(R/'work/v013/import-output.log').write_text(s,encoding='utf-8');print('\n'.join(x for x in s.splitlines() if 'Error' in x or 'ERROR' in x or 'at:' in x)[-12000:])
