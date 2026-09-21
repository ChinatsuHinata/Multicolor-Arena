from pathlib import Path
import subprocess,os,re,sys
sys.stdout.reconfigure(encoding="utf-8")
root=Path(__file__).resolve().parents[1]
work=root/'work/v018/export'
env=os.environ.copy()
templates=Path(env['APPDATA'])/'Godot/export_templates/4.7.2.stable'
env['APPDATA']=str(work/'editor-appdata')
exe=r'C:\Users\tzx20\Desktop\Godot_v4.7.2-stable_win64.exe'
preset=root/'export_presets.cfg';saved=preset.read_text(encoding='utf-8')
try:
 configured=saved.replace('custom_template/release=""','custom_template/release="'+(templates/'windows_release_x86_64.exe').as_posix()+'"')
 preset.write_text(configured,encoding='utf-8')
 with (work/'export.log').open('wb') as log:
  proc=subprocess.run([exe,'--headless','--path',str(root),'--export-release','Windows Desktop',str(root/'builds/Windows-v0.18.0/Multicolour.exe'),'--log-file',str(work/'export-engine.log')],env=env,stdout=log,stderr=subprocess.STDOUT,timeout=300,creationflags=subprocess.CREATE_NO_WINDOW)
 print('EXPORT_EXIT:',proc.returncode)
finally:
 preset.write_text(saved,encoding='utf-8')
text=(work/'export.log').read_text(encoding='utf-8',errors='replace')
for line in text.splitlines():
 if any(key in line for key in ['ERROR','Error','WARNING','BUNDLED_DECKS','REGISTERED_CARDS','export: end','export: Export']): print(line)
for p in (root/'builds/Windows-v0.18.0').iterdir():
 if p.is_file():print(p.name,p.stat().st_size)
