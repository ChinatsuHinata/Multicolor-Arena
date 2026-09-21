from pathlib import Path
import subprocess,os,time,json,random,sys
sys.stdout.reconfigure(encoding="utf-8")
root=Path(__file__).resolve().parents[1];work=root/'work/v018'
exe=r'C:\Users\tzx20\Desktop\Godot_v4.7.2-stable_win64.exe'
procs=[]
port=str(random.randrange(49160,59990))
for role in ["host","guest"]:
 (work/("process-"+role+"-result.json")).unlink(missing_ok=True)
for role in ['host','guest']:
 env=os.environ.copy();env['APPDATA']=str(work/('appdata-'+role))
 log=(work/('process-'+role+'.log')).open('wb')
 p=subprocess.Popen([exe,'--headless','--path',str(root),'--script','res://tests/test_v018_process.gd','--log-file',str(work/('process-'+role+'-engine.log')),'--',role,port],env=env,stdout=log,stderr=subprocess.STDOUT,creationflags=subprocess.CREATE_NO_WINDOW)
 procs.append((role,p,log))
 time.sleep(0.4)
try:
 deadline=time.monotonic()+195
 while any(p.poll() is None for _,p,_ in procs) and time.monotonic()<deadline:
  if any(p.poll() is not None and p.returncode!=0 for _,p,_ in procs):
   for _,p,_ in procs:
    if p.poll() is None:p.kill()
   break
  time.sleep(0.1)
 for role,p,log in procs:
  p.wait(timeout=10);log.close();text=(work/('process-'+role+'.log')).read_text(encoding='utf-8',errors='replace')
  print(role,'EXIT',p.returncode);print('\n'.join(text.splitlines()[-12:]))
 for role in ['host','guest']:
  path=work/('process-'+role+'-result.json')
  if path.exists():
   d=json.loads(path.read_text(encoding='utf-8'));print(role,{k:d[k] for k in ['score','winner','sequence','turn','life','actions','errors']})
finally:
 for role,p,log in procs:
  if p.poll() is None:p.kill()
  log.close()
