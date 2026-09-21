from pathlib import Path
import json, hashlib
root=Path(__file__).resolve().parents[1]
for old,new in [('run_godot_v018.py','run_godot_v0181.py'),('export_v018.py','export_v0181.py'),('verify_export_v018.py','verify_export_v0181.py')]:
    text=(root/'work'/old).read_text(encoding='utf-8').replace('v018','v0181').replace('v0.18.0','v0.18.1')
    (root/'work'/new).write_text(text,encoding='utf-8')
text=(root/'tests/test_v018_ui.gd').read_text(encoding='utf-8').replace('v018/','v0181/').replace('V018 UI','V0181 UI')
text='\n'.join(line for line in text.splitlines() if 'authority_session.series.state.chooser' not in line)+'\n'
text=text.replace(' await capture("lan-room")', ''' await until(func():return client_session.metrics.local_ms>=0 and client_session.metrics.remote_ms>=0)
 await capture("lan-room")''')
text=text.replace(' expect(view.local_seat==1', ''' expect(is_instance_valid(view.network_latency_label) and "ms" in view.network_latency_label.text,"battle shows measured latency for both players")
 expect(view.local_seat==1''')
text=text.replace(' app.online();await process_frame;await capture("lan-in-match-room")', ''' view.settings_menu()
 expect(find_button(view.ui,"本局投降")!=null,"settings clearly exposes single-game surrender")
 await press("本局投降");await press("本局投降")
 expect(await until(func():return client_session.room.status=="between" and view.engine.winner!=-2),"surrender finishes only current game")
 await settle()
 expect(find_button(view.ui,"下一局")!=null,"BO3 result offers next game")
 await capture("single-game-result")
 await press("下一局");await process_frame;await capture("next-game-room")
 expect(find_button(app.screen,"调整主副卡组")!=null and find_button(app.screen,"准备")!=null,"next game keeps sideboard and ready flow")
 expect(find_button(app.screen,"整场认输")==null and find_button(app.screen,"先手")==null,"lobby has no entire-series surrender or manual first-player control")''')
(root/'tests/test_v0181_ui.gd').write_text(text,encoding='utf-8')
files=sorted(list((root/'scripts/rules').glob('*.gd'))+[root/'scripts/card_database.gd']+list((root/'net').glob('*.gd')))
manifest={'files':{p.relative_to(root).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in files},'version':'0.18.1'}
(root/'net/rules_manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,sort_keys=True),encoding='utf-8')
print('Prepared v0.18.1 tests, exporters and rule fingerprint')
