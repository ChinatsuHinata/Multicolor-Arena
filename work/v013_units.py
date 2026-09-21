from pathlib import Path
import subprocess,os,sys
R=Path.cwd();env=os.environ.copy();env['APPDATA']=str(R/'work/appdata');start=sys.argv[1] if len(sys.argv)>1 else '0';label='units-'+start
try:
 p=subprocess.run([r'C:\Users\tzx20\Desktop\Godot_v4.7.2-stable_win64.exe','--headless','--path',str(R),'--script','res://tests/test_v013_units.gd','--',''+start,'40'],env=env,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=60,creationflags=subprocess.CREATE_NO_WINDOW)
 s=p.stdout.decode('utf-8',errors='replace');(R/'work/v013'/f'{label}.log').write_text(s,encoding='utf-8');print('exit',p.returncode);print('\n'.join(x for x in s.splitlines() if 'ERROR' in x or 'NO LEGAL' in x or 'at:' in x or 'V013_' in x)[-12000:])
except subprocess.TimeoutExpired as ex:
 (R/'work/v013'/f'{label}.log').write_bytes(ex.stdout or b'');print('TIMEOUT')

