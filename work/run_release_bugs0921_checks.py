from pathlib import Path
import os,subprocess,sys

root=Path(__file__).resolve().parents[1]
work=root/'work/bugfix0921/export'
out=root/'builds/Verify-bugfix0921-r2'
env=os.environ.copy()
env['APPDATA']=str(work/'verification-profile-r2')
env['MULTICOLOUR_EXPORT_SCREENSHOT']=str(work/'release-battle.png')
for mode in ['first','restart','empty']:
    command=[str(out/'MulticolorArena.exe')]
    if mode!='first':command.append('--headless')
    command+=['--log-file',str(work/('verify-'+mode+'-engine.log')),'--',mode]
    result=subprocess.run(command,cwd=out,env=env,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=60,creationflags=subprocess.CREATE_NO_WINDOW)
    text=result.stdout.decode('utf-8',errors='replace')
    (work/('verify-'+mode+'.log')).write_text(text,encoding='utf-8')
    bad=[line for line in text.splitlines() if ('ERROR:' in line or 'SCRIPT ERROR' in line) and 'root certificate' not in line]
    print(mode,'exit',result.returncode,'errors',bad,flush=True)
    print('\n'.join(line for line in text.splitlines() if 'EXPORT_CHECK' in line),flush=True)
    if result.returncode!=0 or bad or '0 failures' not in text:sys.exit(1)
