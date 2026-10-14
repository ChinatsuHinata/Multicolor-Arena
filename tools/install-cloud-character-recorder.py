"""Install the optional cloud character recorder after explicit authorization."""
import argparse
import base64
import importlib.util
import json
from pathlib import Path
import subprocess

spec = importlib.util.spec_from_file_location('rank_report',Path(__file__).with_name('download-cloud-rank-report.py'))
rank_report = importlib.util.module_from_spec(spec)
spec.loader.exec_module(rank_report)

DECLARATION = 'var character_log=preload("match_character_log.gd").new()\n'
LOG_PATH = ' character_log.log_path=character_log.get_script().resource_path.get_base_dir().path_join("data/match_leaders-"+("websocket" if websocket else "enet")+".jsonl")\n'
FORWARD = '  if not room.is_empty() and target in room.slots and target!=id:send_raw(target,data.slice(12),channel)\n'
OBSERVED_FORWARD = '  if not room.is_empty() and target in room.slots and target!=id:\n   character_log.observe(room,target,data.slice(12))\n   send_raw(target,data.slice(12),channel)\n'


def patch_source(source):
    if DECLARATION in source:
        if LOG_PATH not in source or OBSERVED_FORWARD not in source:
            raise ValueError('An incomplete recorder patch is already present')
        return source
    anchors = [('var last_match_tick=0\n','var last_match_tick=0\n'+DECLARATION),
               (' if account_port<1024 or account_port>65535:',LOG_PATH+' if account_port<1024 or account_port>65535:'),
               (FORWARD,OBSERVED_FORWARD)]
    for old,new in anchors:
        if source.count(old)!=1:
            raise ValueError('Online relay source differs from the verified recorder patch anchors')
        source=source.replace(old,new,1)
    return source


def remote_install(helper):
    patch_function = __import__('inspect').getsource(patch_source)
    constants = '\n'.join(f'{name} = {globals()[name]!r}' for name in ('DECLARATION','LOG_PATH','FORWARD','OBSERVED_FORWARD'))
    return r'''
import base64
from datetime import datetime, timezone, timedelta
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import uuid
''' + constants + '\n' + patch_function + '\nHELPER = ' + repr(base64.b64encode(helper).decode()) + r'''
root=Path.home()/'.local/share/multicolor-relay'
server=root/'server.gd'
helper_path=root/'match_character_log.gd'
original=server.read_bytes()
source=original.decode('utf-8')
patched=patch_source(source).encode('utf-8')
recorder=base64.b64decode(HELPER)
if original==patched and helper_path.is_file() and helper_path.read_bytes()==recorder:
    print(json.dumps({'mode':'recorder_install','status':'already_installed','restarted':False},ensure_ascii=True))
else:
    operation=uuid.uuid4().hex
    stage=root/('.character-recorder-'+operation)
    stage.mkdir(mode=0o700)
    (stage/'project.godot').write_text('[application]\nconfig/name="Character recorder validation"\n')
    (stage/'server.gd').write_bytes(patched)
    (stage/'match_character_log.gd').write_bytes(recorder)
    shutil.copyfile(root/'match_queue.gd',stage/'match_queue.gd')
    service='multicolor-relay-user.service'
    command=subprocess.check_output(['systemctl','--user','show',service,'-p','ExecStart','--value'],text=True)
    executable=re.search(r'path=([^ ;}]+)',command)
    if not executable:
        raise RuntimeError('Cannot determine the deployed Godot executable')
    check=subprocess.run([executable.group(1),'--headless','--path',str(stage),'--check-only','--script','res://server.gd'],capture_output=True,text=True,timeout=30)
    (stage/'validation.log').write_text(check.stdout+check.stderr)
    if check.returncode or 'SCRIPT ERROR:' in check.stdout+check.stderr:
        raise RuntimeError('Recorder patch failed Godot validation: '+(check.stdout+check.stderr)[-2000:])
    if server.read_bytes()!=original:
        raise RuntimeError('Online relay changed during validation; retry after reviewing the new source')
    backup=root/'backups'/('character-recorder-'+datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%SZ')+'-'+operation)
    backup.mkdir(mode=0o700,parents=True)
    (backup/'server.gd').write_bytes(original)
    old_helper=helper_path.read_bytes() if helper_path.exists() else None
    if old_helper is not None:(backup/'match_character_log.gd').write_bytes(old_helper)
    services=['multicolor-relay-user.service','multicolor-relay-ws-user.service']
    def replace(path,data):
        temporary=path.with_name(path.name+'.'+operation+'.new')
        temporary.write_bytes(data)
        os.chmod(temporary,0o600)
        temporary.replace(path)
    try:
        replace(helper_path,recorder)
        replace(server,patched)
        subprocess.run(['systemctl','--user','restart',*services],check=True,capture_output=True,timeout=30)
        active=subprocess.run(['systemctl','--user','is-active',*services],check=True,capture_output=True,text=True,timeout=10)
        if active.stdout.splitlines()!=['active','active']:
            raise RuntimeError('Both relay services did not become active')
    except Exception:
        replace(server,original)
        if old_helper is not None:replace(helper_path,old_helper)
        else:helper_path.unlink(missing_ok=True)
        subprocess.run(['systemctl','--user','restart',*services],check=True,capture_output=True,timeout=30)
        raise
    print(json.dumps({'mode':'recorder_install','status':'installed','restarted':True,'backup':str(backup),
                      'server_sha256':hashlib.sha256(patched).hexdigest(),
                      'timestamp_china':datetime.now(timezone(timedelta(hours=8))).isoformat(timespec='seconds')},ensure_ascii=True))
'''


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--server',default='8.137.122.187')
    parser.add_argument('--user',default='codex')
    parser.add_argument('--ssh-port',type=int,default=22)
    parser.add_argument('--key-path',default=str(Path.home()/'.ssh/id_ed25519_multicolor_ecs'))
    parser.add_argument('--ssh-exe',default=r'C:\Windows\System32\OpenSSH\ssh.exe')
    parser.add_argument('--askpass-exe')
    parser.add_argument('--output-dir')
    parser.add_argument('--confirm-service-restart',action='store_true')
    parser.add_argument('--prepare-from',help='Prepare a local relay candidate without SSH or restarting services')
    parser.add_argument('--candidate-dir')
    args=parser.parse_args()
    helper=Path(__file__).resolve().parents[1]/'relay/match_character_log.gd'
    if args.prepare_from:
        folder=Path(args.candidate_dir)
        folder.mkdir(parents=True,exist_ok=True)
        (folder/'server.gd').write_text(patch_source(Path(args.prepare_from).read_text(encoding='utf-8')),encoding='utf-8')
        (folder/'match_character_log.gd').write_bytes(helper.read_bytes())
        return
    if not args.confirm_service_restart:
        parser.error('Explicit --confirm-service-restart is required; ongoing relay connections will disconnect')
    # Installation includes a check-only Godot validation and service restart.
    result=rank_report.download(args,remote_install(helper.read_bytes()),timeout=120)
    target=Path(__file__).resolve().parents[1]/'work/cloud-character-report/recorder-installation.json'
    target.parent.mkdir(parents=True,exist_ok=True)
    rank_report.write_atomic(target,json.dumps(result,ensure_ascii=False,indent=2)+'\n','utf-8')
    print(json.dumps(result,ensure_ascii=True))


if __name__=='__main__':
    try:
        main()
    except (OSError,ValueError,RuntimeError,subprocess.TimeoutExpired) as error:
        raise SystemExit('Recorder installation failed: '+str(error))
