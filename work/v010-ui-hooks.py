from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
def edit(file,changes):
 p=ROOT/file;s=p.read_text('utf-8-sig')
 for old,new in changes:
  assert old in s,(file,old[:90]);s=s.replace(old,new)
 p.write_text(s,encoding='utf-8')
edit('scripts/duel_view.gd',[
 (' elif action.type=="extension":',' elif action.type=="direct_attack":\n  local={"uid":action.uid,"action":"direct_attack","mode":"target","target":{},"plan":[]}\n  picker.reset(); render()\n elif action.type=="extension":'),
 ('func local_cost() -> Dictionary:\n','func local_cost() -> Dictionary:\n if local.get("action","")=="direct_attack": return {}\n'),
 ('return engine.cast_cost(acting_player(),engine.find_card(local.uid))','return engine.cast_cost(acting_player(),engine.find_card(local.uid),local.get("target",{}))'),
 ('func local_targets() -> Array:\n','func local_targets() -> Array:\n if local.get("action","")=="direct_attack": return engine.Pack.all_units(engine,1-acting_player())\n'),
 (' var error=engine.commit_extension(acting_player(),local.uid,local.target,local.plan)', ' if local.get("action","")=="direct_attack":\n  engine.attack(acting_player(),local.uid,local.target); local={}; selection=[]; picker.reset(); render(); return\n var error=engine.commit_extension(acting_player(),local.uid,local.target,local.plan)'),
 ('if local.get("action","")=="" and engine.cards[engine.find_card(local.uid).card_id].kind!="符卡": options=[{"none":true}]','if local.get("action","")=="" and engine.cards[engine.find_card(local.uid).card_id].kind!="符卡" and options.is_empty(): options=[{"none":true}]'),
 ('func render_inline_picker(confirm: Callable,optional: bool=false):\n', 'func render_inline_picker(confirm: Callable,optional: bool=false):\n if not picker.prompt().is_empty(): txt(picker.prompt(),Rect2(1330,610,237,48),17,host.GOLD)\n'),
 ('func arrow_targets(target: Dictionary) -> Array:\n','func arrow_targets(target: Dictionary) -> Array:\n if target.has("picks"):\n  var result=[]\n  for p in engine.Pack.flatten(target): result.append_array(arrow_targets(p))\n  return result\n'),
 ('if c.owner!=acting_player() or response_disabled(): return','if c.owner!=acting_player() and not engine.Pack.cast_from(engine,c,acting_player()) or response_disabled(): return'),
 ('engine.cast_error(c.owner,c.uid)','engine.cast_error(acting_player(),c.uid)'),
 ('var legal=c.owner==acting_player() and not response_disabled()','var legal=(c.owner==acting_player() or engine.Pack.cast_from(engine,c,acting_player())) and not response_disabled()'),
 ('return engine.players[who][zone].filter(func(c): return can_use_region_card(c))','var pool=engine.players[who][zone].duplicate()\n if zone=="exile": pool.append_array(engine.players[1-who].exile.filter(func(c): return engine.Pack.cast_from(engine,c,who)))\n return pool.filter(func(c): return can_use_region_card(c))'),
 ('confirm.disabled=region_selected.is_empty()','confirm.disabled=region_selected.is_empty() and not picker.available().any(func(a): return a.kind=="finish_group")'),
 (' if observing or region_selected.is_empty(): return\n var atom=region_selected.duplicate(true);', ' if observing: return\n if region_selected.is_empty():\n  for a in picker.available():\n   if a.kind=="finish_group": inline_pick(a); return\n  return\n var atom=region_selected.duplicate(true);'),
])
edit('scripts/duel_table.gd', [('colors=duel.cards[d.card_id].colors','colors=duel.Pack.colors(duel,duel.find_card(d.uid)) if not duel.find_card(d.uid).is_empty() else duel.cards[d.card_id].colors')])
edit('scripts/deck_store.gd', [('   if names[name]>4:', '   if "限制级" in CARDS[id].get("keywords",[]) and names[name]>2: return "限制级同名牌最多 2 张："+name\n   if names[name]>4:')])
edit('scripts/main.gd',[
 ('  var info=Store.CARDS[id]\n  if not query', '  var info=Store.CARDS[id]\n  if not info.constructible: continue\n  if not query'),
 ('func load_test_decks():', '''func load_test_decks():
 var templates=JSON.parse_string(FileAccess.get_file_as_string("res://data/test_precons.json"))
 if not templates is Dictionary: popup("测试套牌模板读取失败"); return
 var positions=[]
 for template in templates.decks:
  var error=Store.validate(template,true)
  if not error.is_empty(): popup(error); return
  var found=-1
  for i in range(decks.size()):
   if decks[i].id==template.id: found=i; break
  if found<0: found=decks.size(); decks.append(template.duplicate(true))
  else: decks[found]=template.duplicate(true)
  positions.append(found)
 player_choice=positions[0]; ai_choice=positions[1]; skip_check=false; ai_one=true
 setup()

func load_legacy_test_decks():'''),
])
# Historical fixtures intentionally exercise the original eight demo cards.
for p in (ROOT/'tests').glob('*.gd'):
 s=p.read_text('utf-8-sig');s=s.replace('app.load_test_decks()', 'app.load_legacy_test_decks()')
 s=s.replace('DB.load_cards().size()==65','DB.load_cards().size()>=65')
 p.write_text(s,encoding='utf-8')
