from pathlib import Path
root=Path(__file__).resolve().parent.parent
p=root/'scripts/duel_view.gd';s=p.read_text('utf-8')
s=s.replace('and (modal or not local.is_empty()','and (debug_open or modal or not local.is_empty()',1)
s=s.replace('ui.move_child(observe_button,-1)','ui.move_child(inspection,-1)\n ui.move_child(observe_button,-1)',1)
s=s.replace('if is_instance_valid(modal_root): modal_root.visible=not observing','if is_instance_valid(modal_root): modal_root.visible=not observing\n if is_instance_valid(debug_root): debug_root.visible=not observing',1)
s=s.replace('debug_root=null; debug_open=false','debug_root=null; debug_open=false\n if observing:\n  observing=false\n  if is_instance_valid(modal_root): modal_root.visible=true\n  for widget in hud.get_children():\n   if widget.has_meta("choice_widget"): widget.visible=true\n refresh_observation()',1)
s=s.replace('tile.custom_minimum_size=Vector2(162,286)','tile.custom_minimum_size=Vector2(162,354)',1)
s=s.replace('Rect2(0,230,160,50)','Rect2(0,230,160,74)',1)
s=s.replace('Rect2(30,232,100,40)','Rect2(30,309,100,40)')
s=s.replace('for key in table.piles:\n  var root','for key in table.piles:\n  if "exile" in key and engine.players[0 if key.begins_with("p") else 1].exile.is_empty(): continue\n  var root',1)
# Preserve an independent inspector while a choice is suspended underneath it.
p.write_text(s,'utf-8')
p=root/'scripts/duel_table.gd';s=p.read_text('utf-8').replace('hit.set_meta("caption",("墓地" if face_up else "牌库")','hit.collision_layer=0 if "exile" in key and count==0 else 1\n hit.set_meta("caption",("除外区" if "exile" in key else "墓地" if face_up else "牌库")',1);p.write_text(s,'utf-8')
p=root/'scripts/rules/duel_engine.gd';s=p.read_text('utf-8').replace('note("调试移动："','passes=0\n note("调试移动："',1);p.write_text(s,'utf-8')
# Reject unsupported extension names at load time, rather than accepting inert abilities.
p=root/'scripts/card_database.gd';s=p.read_text('utf-8')
import json
effects=set()
for card in (root/'cards').glob('*.json'):
 for a in json.loads(card.read_text('utf-8'))['能力绑定']:
  if a['实现']=='extension': effects.add(a['参数']['效果'])
s=s.replace('const COLORS=', 'const EXTENSION_EFFECTS='+json.dumps(sorted(effects),ensure_ascii=False)+'\nconst COLORS=',1)
s=s.replace('if handler=="turn_buff":','if handler=="extension" and (not params is Dictionary or params.get("效果","") not in EXTENSION_EFFECTS): return "未登记的扩展效果"\n  if handler=="turn_buff":',1)
p.write_text(s,'utf-8')
# Improve runtime-owned token art without touching source images; cached at common card dimensions.
p=root/'tests/test_v09_ui.gd';s=p.read_text('utf-8').replace('expect(view.debug_open,"opposing entire deck inspector opens")','expect(view.debug_open,"opposing entire deck inspector opens")\n view.toggle_observation(); expect(view.observing and not view.debug_root.visible,"inspector supports observe battlefield")\n view.toggle_observation(); expect(not view.observing and view.debug_root.visible,"return from observing restores inspector")',1)
# Include an opposing face-up card in the rendered battle evidence.
s=s.replace('put("21","grave",1); put("96","hand",0);','put("21","grave",1); put("29","hand",1); put("1","hand",1); put("96","hand",0);',1)
p.write_text(s,'utf-8')
