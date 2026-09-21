from pathlib import Path
import json
R=Path.cwd()
def edit(path,f):
 p=R/path;s=p.read_text(encoding='utf-8');p.write_text(f(s),encoding='utf-8')
p=R/'cards/character-fdf-115.json';d=json.loads(p.read_text(encoding='utf-8'));d['别名']=['不明物体'];p.write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
def ui(s):
 s=s.replace('if action.type=="attack": selection=[]; engine.attack(acting_player(),action.uid); render()','if action.type=="attack": begin_attack_payment(action.uid)')
 s=s.replace('if engine.can_attack(acting_player(),uid): engine.attack(acting_player(),uid)','if engine.can_attack(acting_player(),uid): begin_attack_payment(uid)')
 s=s.replace('if local.get("action","")=="direct_attack": return {}','if local.get("action","") in ["attack","direct_attack"]: return engine.attack_cost(acting_player())')
 s=s.replace('return engine.Extra.activation_cost(local.key)','return engine.extension_cost(acting_player(),engine.find_card(local.uid),local.key,local.get("target",{}))')
 s=s.replace('return engine.ability_parameters(local.uid,local.index).get("费用",{})','return engine.ability_cost(acting_player(),local.uid,local.index,local.get("target",{}))')
 s=s.replace('if local.get("action","")=="direct_attack": return engine.Pack.all_units(engine,1-acting_player())','if local.get("action","")=="direct_attack": return engine.Pack.all_units(engine,1-acting_player()).filter(func(r):return engine.Pack.direct_attack(engine,engine.find_card(local.uid)) or engine.find_card(r.uid).has("rank_target"))')
 s=s.replace('if local.get("action","")=="direct_attack":\n  engine.attack(acting_player(),local.uid,local.target);','if local.get("action","") in ["attack","direct_attack"]:\n  engine.attack(acting_player(),local.uid,local.target,local.plan);')
 s=s.replace(' for c in cards:\n  var tile=Control.new(); tile.custom_minimum_size=Vector2(83,117);',' for c in cards:\n  var card_hidden=hidden and not (zone=="deck" and who==acting_player() and not cards.is_empty() and cards[0].uid==c.uid and engine.Cat.may_peek(engine,who))\n  var tile=Control.new(); tile.custom_minimum_size=Vector2(83,117);')
 a=s.index(' for c in cards:\n  var card_hidden');b=s.index(' if cards.is_empty():',a);chunk=s[a:b].replace('if hidden else','if card_hidden else').replace('("hidden",hidden)','("hidden",card_hidden)').replace('elif not hidden:','elif not card_hidden:');s=s[:a]+chunk+s[b:]
 s=s.replace('if atom.kind!="target": options.append(atom); continue','if atom.kind!="target" or not atom.value.has("uid") and not atom.value.has("player") and not atom.value.has("stack_id") or atom.value.has("counter"): options.append(atom); continue')
 s=s.replace('  for atom in options:\n   var row=Button.new();', '  var search: LineEdit\n  if options.size()>16:\n   search=LineEdit.new(); search.placeholder_text="检索名称"; search.custom_minimum_size=Vector2(215,36); column.add_child(search)\n   search.text_changed.connect(func(value):\n    for child in column.get_children():\n     if child is Button: child.visible=value.is_empty() or value.to_lower() in child.text.to_lower())\n  for atom in options:\n   var row=Button.new();')
 s=s.replace('row.text=target_caption(atom.value) if atom.kind=="target" else str(atom.value)','row.text=(engine.cards[atom.value.outside_id].name if atom.value.has("outside_id") else target_caption(atom.value)) if atom.kind=="target" else str(atom.value)\n   if atom.kind=="target" and atom.value.has("counter"):row.text+=" · "+str(atom.value.counter)+" "+str(atom.value.counter_index+1)')
 s=s.replace('   btn("重选费用",Rect2(1330,761,237,43),func(): local.plan=[]; render())','   btn("重选费用",Rect2(1330,761,237,43),func(): local.plan=[]; render())\n   render_floating_resources()')
 s=s.replace('confirm.disabled=selection.size()==1 and engine.Extra.keyword(engine,engine.find_card(engine.combat.attacker.uid),"威吓")','confirm.disabled=(selection.size()==1 and engine.Extra.keyword(engine,engine.find_card(engine.combat.attacker.uid),"威吓")) or (selection.is_empty() and engine.must_block())')
 s+='''
func begin_attack_payment(uid: int):
 local={"uid":uid,"action":"attack","mode":"payment","target":{},"plan":[]}
 selection=[];picker.reset();start_payment()
func render_floating_resources():
 var pool=payment_sources().filter(func(r):return r.get("kind","")=="floating")
 if pool.is_empty():return
 var scroll=ScrollContainer.new();scroll.position=Vector2(1330,480);scroll.size=Vector2(237,118);hud.add_child(scroll)
 var rows=VBoxContainer.new();rows.size_flags_horizontal=Control.SIZE_EXPAND_FILL;scroll.add_child(rows)
 for resource in pool:
  var button=Button.new();button.text="%s 1%s" % [resource.colors[0]," ✓" if local.plan.any(func(p):return p.uid==resource.uid) else ""]
  button.custom_minimum_size=Vector2(215,34);rows.add_child(button);button.pressed.connect(func():reserve_resource(resource.uid))
'''
 return s
edit('scripts/duel_view.gd',ui)
def engine(s):
 s=s.replace('targets_for(c.card_id,who),target','targets_for(c.card_id,who,uid),target')
 s=s.replace('  move_to(find_card(target.sacrifice.uid),"grave")','  sacrifice(find_card(target.sacrifice.uid))')
 s=s.replace('if key in ["grave_reanimate","sacrifice_buff"]: move_to(find_card(target.uid),"grave")','if key=="grave_reanimate": move_to(find_card(target.uid),"grave")\n if key=="sacrifice_buff": sacrifice(find_card(target.uid))')
 s=s.replace('payment_valid(who,params.get("费用",{}),plan)','payment_valid(who,ability_cost(who,uid,index,target),plan)')
 s=s.replace('payment(who,Extra.activation_cost(a.key)).plan','payment(who,extension_cost(who,c,a.key,target)).plan')
 s=s.replace('payment(who,Extra.activation_cost(key)).plan).is_empty(): return true','payment(who,extension_cost(who,c,key,target)).plan).is_empty(): return true')
 s=s.replace('payment(who,Extra.activation_cost(key)).plan).is_empty(): return true','payment(who,extension_cost(who,c,key,choices[0])).plan).is_empty(): return true') if False else s
 s=s.replace('commit_extension(who,c.uid,choices[0],payment(who,extension_cost(who,c,key,target)).plan)','commit_extension(who,c.uid,choices[0],payment(who,extension_cost(who,c,key,choices[0])).plan)')
 s=s.replace('     triggers.append({"source":c.duplicate(true),"owner":active,"effect":"untap","optional":false,"name":cards[c.card_id].name+" · 英勇"})','     Cat.enqueue(self,{"source":c.duplicate(true),"owner":active,"effect":"untap","optional":false,"name":cards[c.card_id].name+" · 英勇"})')
 s=s.replace('  "main":\n   if units(active).any','  "main":\n   priority=active\n   if units(active).any')
 s+='''
func ability_cost(who: int,uid: int,index: int,target: Dictionary={}) -> Dictionary:
 var cost=ability_parameters(uid,index).get("费用",{}).duplicate();var tax=Cat.target_tax(self,who,target)
 if tax>0:cost["红/蓝/绿/黄/黑"]=int(cost.get("红/蓝/绿/黄/黑",0))+tax
 return cost
func must_block() -> bool:
 if combat.is_empty():return false
 var c=find_card(combat.attacker.uid)
 return Cat.has(self,c,"character-fdn-027") and not legal_blockers(1-combat.owner).is_empty()
'''
 # actual legal blockers signature checked in following validation
 return s
edit('scripts/rules/duel_engine.gd',engine)
def state(s):
 s=s.replace('static func keyword(e,c,k):\n if c.zone!="field":return false\n var C=e.Cat;var who=c.owner','static func keyword(e,c,k):\n var C=e.Cat;var who=c.owner')
 s=s.replace(' if k=="不会被消灭":',' if c.zone!="field":return false\n if k=="不会被消灭":')
 return s
edit('scripts/rules/catalogue_state.gd',state)
edit('scripts/rules/excel_abilities.gd',lambda s:s.replace('return forced(e,c,who) or Cat.State.bypass','return (forced(e,c,who) and e.forced_cast.get("ignore",true)) or Cat.State.bypass'))
def cat(s):
 s=s.replace('"free":free,"cost":cost_override','"free":free,"cost":cost_override,"ignore":false')
 s=s.replace(' if choices.is_empty():return\n var source=', ' if choices.is_empty() or not error.is_empty():return\n var source=')
 return s
edit('scripts/rules/catalogue_abilities.gd',cat)
edit('scripts/rules/catalogue_spells.gd',lambda s:s.replace('"free":d.free,"cost":d.cost','"free":d.free,"cost":d.cost,"ignore":false'))
