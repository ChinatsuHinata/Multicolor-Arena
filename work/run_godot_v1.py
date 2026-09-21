from pathlib import Path
import subprocess,os,sys,time,json
root=Path(__file__).resolve().parents[1]
env=os.environ.copy();env['APPDATA']=str(root/'work/appdata')
exe=r'C:\Users\tzx20\Desktop\Godot_v4.7.2-stable_win64.exe'
results=[]
for name in sys.argv[1:]:
 visual=name.endswith(':visual');name=name.removesuffix(':visual')
 path=name if name.startswith('res://') else 'res://tests/'+name+'.gd'
 label=Path(path).stem;log=root/'work/v1'/f'{label}.log'
 if visual:log=root/'work/v1'/f'{label}-visual.log'
 args=[exe]+([] if visual else ['--headless'])+['--path',str(root),'--script',path,'--log-file',str(log)]
 try:
  p=subprocess.run(args,env=env,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=180 if label=="test_v015_rules" else 45,creationflags=subprocess.CREATE_NO_WINDOW)
  text=p.stdout.decode('utf-8',errors='replace');log.write_text(text,encoding='utf-8')
  errors=[line for line in text.splitlines() if ('SCRIPT ERROR' in line or 'ERROR:' in line) and 'root certificate' not in line]
  print(label,'exit',p.returncode,'errors',len(errors));print('\n'.join(errors[:18]));print('\n'.join(text.splitlines()[-3:]))
  results.append({'test':name,'exit':p.returncode,'errors':errors})
 except subprocess.TimeoutExpired as ex:
  log.write_bytes(ex.stdout or b'');print(label,'TIMEOUT');results.append({'test':name,'timeout':True})
(root/'work/v1/last-results.json').write_text(json.dumps(results,ensure_ascii=False,indent=2),encoding='utf-8')

