from pathlib import Path
import json,re,sys
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools'))
from import_precons_v010 import EFFECTS

def edit(file,changes):
 p=ROOT/file; s=p.read_text('utf-8-sig')
 for old,new in changes:
  assert old in s,(file,old[:100])
  s=s.replace(old,new)
 p.write_text(s,encoding='utf-8')

edit('scripts/card_database.gd',[
 ('# Registered, implemented card pool.', '# Registered, implemented card pool.'),
 ('const COLORS=', 'const PRECON_EFFECTS='+json.dumps(sorted(set(sum(EFFECTS.values(),[]))),ensure_ascii=False)+'\nconst COLORS='),
 ('"turn_buff","extension"]','"turn_buff","extension","precon"]'),
 ('if not d.get("颜色") is Array or d["颜色"].is_empty():','if not d.get("颜色") is Array or d["颜色"].is_empty() and not d.get("衍生物",false):'),
 ('  if handler=="extension"', '  if handler=="precon" and (not params is Dictionary or params.get("效果","") not in PRECON_EFFECTS): return "未登记的预组效果"\n  if handler=="extension"'),
 ('"time":int(d.get("计时",0))}', '"time":int(d.get("计时",0)),"variable_cost":d.get("可变费用",""),"aliases":d.get("别名",[]),"token":d.get("衍生物",false)}'),
])

edit('scripts/rules/expanded_abilities.gd',[
 ('return k in e.cards[c.card_id].get("keywords",[])', 'return e.Pack.dynamic_keyword(e,c,k) or k in e.cards[c.card_id].get("keywords",[])'),
 (' var n=0\n for v in e.cards[c.card_id].cost.values(): n+=int(v)', ' var n=int(c.get("cast_x",0)) if c.zone=="stack" else 0\n for v in e.cards[c.card_id].cost.values(): n+=int(v)'),
 ('static func spell_options(e,id: String,who: int) -> Variant:\n', 'static func spell_options(e,id: String,who: int) -> Variant:\n var precon=e.Pack.spell_options(e,id,who)\n if precon!=null: return precon\n'),
 ('static func valid(e,t: Dictionary) -> bool:\n', 'static func valid(e,t: Dictionary) -> bool:\n if t.has("picks"):\n  var list=e.Pack.flatten(t); return list.is_empty() or list.any(func(x): return valid(e,x))\n'),
 (' e.triggers.append({"extended":true', ' if e.Pack.response_locked(e): return\n e.triggers.append({"extended":true'),
 ('static func on_enter(e,c: Dictionary):\n', 'static func on_enter(e,c: Dictionary):\n e.Pack.on_enter(e,c)\n'),
 ('static func on_leave(e,c: Dictionary):\n', 'static func on_leave(e,c: Dictionary):\n e.Pack.on_leave(e,c)\n'),
 ('static func on_death(e,c: Dictionary,before: Dictionary):\n', 'static func on_death(e,c: Dictionary,before: Dictionary):\n e.Pack.on_death(e,c,before)\n'),
 ('static func trigger_options(e,t: Dictionary) -> Array:\n', 'static func trigger_options(e,t: Dictionary) -> Array:\n if t.get("precon",false): return e.Pack.trigger_options(e,t)\n'),
 ('static func resolve_trigger(e,t: Dictionary):\n', 'static func resolve_trigger(e,t: Dictionary):\n if t.get("precon",false): e.Pack.resolve_trigger(e,t); return\n'),
 ('static func spell_resolve(e,entry: Dictionary) -> bool:\n', 'static func spell_resolve(e,entry: Dictionary) -> bool:\n if e.Pack.spell_resolve(e,entry): return true\n'),
 ('static func activation_kind(info: Dictionary) -> String:\n', 'static func activation_kind(info: Dictionary) -> String:\n var precon=preload("res://scripts/rules/precon_abilities.gd").activation_kind(info)\n if not precon.is_empty(): return precon\n'),
 ('static func activation_options(e,c: Dictionary,key: String) -> Array:\n', 'static func activation_options(e,c: Dictionary,key: String) -> Array:\n if key in e.Pack.ACTIVATIONS: return e.Pack.activation_options(e,c,key)\n'),
 ('static func activation_cost(key: String) -> Dictionary:\n', 'static func activation_cost(key: String) -> Dictionary:\n var pack=preload("res://scripts/rules/precon_abilities.gd")\n if key in pack.ACTIVATIONS: return pack.activation_cost(key)\n'),
 ('static func resolve_activation(e,entry: Dictionary):\n', 'static func resolve_activation(e,entry: Dictionary):\n if entry.effect in e.Pack.ACTIVATIONS: e.Pack.resolve_activation(e,entry); return\n'),
 ('e.find_card(target.uid).tapped=true','e.tap_card(e.find_card(target.uid))'),
 ('e.find_card(part.uid).tapped=true','e.tap_card(e.find_card(part.uid))'),
 ('e.players[who].life+=1','e.gain_life(who,1)'),
 ('e.players[entry.owner].life+=1','e.gain_life(entry.owner,1)'),
])

edit('scripts/rules/duel_engine.gd',[
 ('const DB=', 'const Pack=preload("res://scripts/rules/precon_abilities.gd")\nconst DB='),
 ('var zone_replacements=[]','var zone_replacements=[]\nvar damage_context={}\nvar unpreventable_turn=-1'),
 ('var c={"uid":next_uid,','var c={"original_owner":owner,"token":cards[id].get("token",false),"uid":next_uid,'),
 (' zone_replacements.clear()',' zone_replacements.clear(); damage_context={}; unpreventable_turn=-1'),
 (' c.leader_counters=0',' c.leader_counters=0\n for key in ["wards","color_counters","free_exile_owner","devour_owner","base_override","lock_sources","castle_exiles","medicine","skip_reset","tapped_turn"]: c.erase(key)\n if old!="stack" or location!="field": c.erase("cast_x")'),
 (' for c in players[who].field+players[who].palette: c.tapped=false; c.attacked=false', ' for c in players[who].field+players[who].palette:\n  if Pack.reset_allowed(self,c): c.tapped=false\n  c.attacked=false'),
 (' run_delayed("prepare")',' run_delayed("prepare")\n Pack.on_phase(self,"prepare")'),
 ('"colors":cards[c.card_id].colors,"weight":cards[c.card_id].colors.size()*10','"colors":Pack.colors(self,c),"weight":Pack.colors(self,c).size()*10'),
 (' if priority!=who: return "等待执行权"',' if priority!=who: return "等待执行权"\n if Pack.response_locked(self): return "该牌不能被响应"'),
 ('if c.is_empty() or c.owner!=who or c.zone not in ["hand","leader"] and not (c.zone=="deck" and Extra.has(cards[c.card_id],"deck_damage")): return "无法从该区域使用"', 'if c.is_empty(): return "无法从该区域使用"\n if not Pack.cast_from(self,c,who) and (c.owner!=who or c.zone not in ["hand","leader"] and not (c.zone=="deck" and Extra.has(cards[c.card_id],"deck_damage"))): return "无法从该区域使用"'),
 ('if not info.fast and (phase!=','if not Pack.fast(self,c,who) and (phase!='),
 ('for color in cards[permanent.card_id].colors:', 'for color in Pack.colors(self,permanent):'),
 ('  if not present: return "需要操控"+info.requires_character', '  if "支援" in info.get("keywords",[]) and players[who].leader.zone=="leader" and cards[players[who].leader.card_id].character==info.requires_character: present=true\n  if not present: return "需要操控"+info.requires_character'),
 ('if info.kind=="符卡":\n  if target not in targets_for(c.card_id,who): return "目标已失效"', 'if info.kind=="符卡" or not info.get("variable_cost","").is_empty():\n  if not Pack.choice_valid(self,targets_for(c.card_id,who),target): return "目标已失效"'),
 ('payment_valid(who,cast_cost(who,c),plan)','payment_valid(who,cast_cost(who,c,target),plan)'),
 ('else: find_card(reservation.uid).tapped=true','else: tap_card(find_card(reservation.uid))'),
 (' shift(c,"stack")\n stack.append', ' var reveal=Pack.picked(target) if Pack.has(info,"reveal_counter") else []\n for r in reveal:\n  var shown=find_card(r.uid); record_history("展示 · "+cards[shown.card_id].name,history_art(shown))\n shift(c,"stack"); c.owner=who\n stack.append'),
 (' if info.kind=="符卡": Effects.spell_used(self,who)', ' Pack.on_cast(self,c,who,target)\n if info.kind=="符卡": Effects.spell_used(self,who)'),
 ('func queue_trigger(who: int,source: Dictionary,amount: int,title: String):\n', 'func queue_trigger(who: int,source: Dictionary,amount: int,title: String):\n if Pack.response_locked(self): return\n'),
 (' var value=int(cards[c.card_id][key])+int(c.get("plus_counters",0))', ' var value=Pack.base_stat(self,c,key)+int(c.get("plus_counters",0))'),
 ('func judge():\n', 'func judge():\n Pack.state_checks(self)\n'),
 ('  var e=stack.pop_back()\n', '  var e=stack.pop_back()\n  var source=e.get("card",e.get("source",{}))\n  damage_context={"source":source,"single":Pack.flatten(e.target).size()==1,"combat":false}\n'),
 ('  judge(); priority=active; pump_choices()', '  judge(); damage_context={}; priority=active; pump_choices()'),
 ('   run_delayed("end")','   run_delayed("end")\n   Pack.on_phase(self,"end")'),
 ('c.attacked and DB.has_ability(cards[c.card_id],"brave")','c.attacked and (DB.has_ability(cards[c.card_id],"brave") or Extra.keyword(self,c,"英勇")) and not Pack.response_locked(self)'),
 ('  pump_choices()\n  if not pending.is_empty() or not stack.is_empty() or winner!=-2: return','  judge(); pump_choices()\n  if not pending.is_empty() or not stack.is_empty() or winner!=-2: return'),
 ('  for c in p.field: c.damage=0; c.modifiers=[]; c.spell_damage=false', '  p.wards=[]; p.wine=[]\n  for c in p.field: c.damage=0; c.modifiers=[]; c.spell_damage=false; c.wards=[]; c.base_override={}; c.medicine=[]'),
 ('func attack(who: int,uid: int):','func attack(who: int,uid: int,target: Dictionary={}):'),
 (' var c=find_card(uid); c.tapped=true; c.attacked=true', ' var c=find_card(uid)\n if not target.is_empty() and (not Pack.direct_attack(self,c) or not target_valid(target,true) or find_card(target.uid).owner==who): return\n tap_card(c); c.attacked=true'),
 (' priority=1-who; passes=0; note("宣言攻击："+cards[c.card_id].name,history_art(c))', ' if not target.is_empty():\n  combat.blockers=[target]; combat.blocked=true; combat.direct=true; c.skip_reset=true\n Pack.on_attack_or_block(self,c,true)\n priority=1-who; passes=0; note("宣言攻击："+cards[c.card_id].name,history_art(c)); pump_choices()'),
 ('m.get("不可阻挡颜色","") in cards[c.card_id].colors','m.get("不可阻挡颜色","") in Pack.colors(self,c)'),
 ('if DB.has_ability(cards[attacker.card_id],"exterminate") and has_leader_ability(attacker) and "人类" not in cards[c.card_id].race:', 'if (DB.has_ability(cards[attacker.card_id],"exterminate") and has_leader_ability(attacker) or Extra.keyword(self,attacker,"退治")) and "人类" not in cards[c.card_id].race:'),
 (' for c in chosen: c.tapped=true; combat.blockers.append(ref_target(c))',' for c in chosen: tap_card(c); combat.blockers.append(ref_target(c)); Pack.on_attack_or_block(self,c,false)'),
 (' note("不阻挡" if chosen.is_empty() else "宣言阻挡 · %d 个单位" % chosen.size())',' note("不阻挡" if chosen.is_empty() else "宣言阻挡 · %d 个单位" % chosen.size()); pump_choices()'),
 ('  "attack_window":\n   pending=', '  "attack_window":\n   if combat.get("direct",false): combat.step="block_window"; priority=active; passes=0; revision+=1; return\n   pending='),
 ('if deals_combat_damage(attacker): players[1-combat.owner].life-=stat(attacker,"spirit")','if deals_combat_damage(attacker): combat_hit(attacker,{"player":1-combat.owner},stat(attacker,"spirit"))'),
 ('   damage_target(t,amount)','   var dealt=combat_hit(attacker,t,amount)'),
 ('   if deals_combat_damage(blocker): retaliation+=stat(blocker,"power")', '   if deals_combat_damage(blocker): retaliation+=combat_hit(blocker,combat.attacker,stat(blocker,"power"))'),
 ('if amount>0 and not Extra.keyword(self,blocker,"防止伤害") and combat_exiles(attacker):','if dealt>0 and combat_exiles(attacker):'),
 ('if deals_combat_damage(blocker) and stat(blocker,"power")>0 and not Extra.keyword(self,attacker,"防止伤害") and combat_exiles(blocker):','if deals_combat_damage(blocker) and retaliation>0 and combat_exiles(blocker):'),
 ('  damage_target(combat.attacker,retaliation)\n',''),
 ('    players[1-combat.owner].life-=stat(attacker,"spirit")','    combat_hit(attacker,{"player":1-combat.owner},stat(attacker,"spirit"))'),
 (' options.append_array(players[who].deck.filter', ' options.append_array((players[0].exile+players[1].exile).filter(func(c): return Pack.cast_from(self,c,who)))\n options.append_array(players[who].deck.filter'),
 ('if fast_only and not cards[c.card_id].fast:', 'if fast_only and not Pack.fast(self,c,who):'),
 ('"effect_choice": choose_effect(pending.options[0])','"effect_choice": choose_effect(Pack.ai_target(self,who,pending.options,pending.trigger.get("effect","")))'),
 ('if not info.fast: continue','if not Pack.fast(self,c,who): continue'),
 ('commit_cast(who,c.uid,target,payment(who,cast_cost(who,c)).plan)','commit_cast(who,c.uid,target,payment(who,cast_cost(who,c,target)).plan)'),
 (' if c.zone!="field": return result',' if c.zone!="field": return result\n if Pack.direct_attack(self,c) and not units(1-who).is_empty() and can_attack(who,c.uid):\n  result.append({"type":"direct_attack","uid":uid,"label":"攻击对手单位","enabled":true})'),
 ('if params.get("横置",false): c.tapped=true','if params.get("横置",false): tap_card(c)'),
 ('func cast_cost(who: int,c: Dictionary) -> Dictionary:\n var cost=cards[c.card_id].cost.duplicate()', 'func cast_cost(who: int,c: Dictionary,target: Dictionary={}) -> Dictionary:\n var cost=Pack.cost(self,c,who,cards[c.card_id].cost,target)'),
 (' shift(c,zone)\n if zone!="leader":',' c.owner=c.get("original_owner",c.owner)\n shift(c,zone)\n if zone!="leader":'),
 ('if not target.is_empty() and target not in Extra.trigger_options(self,t): return', 'if not target.is_empty() and not Pack.choice_valid(self,Extra.trigger_options(self,t),target): return'),
 (' if not target.is_empty(): complete_trigger_target(t,target)\n pending={}\n revision+=1; pump_choices()', ' if t.get("continuation",false):\n  pending={}\n  if not target.is_empty(): t.target=target; Pack.resolve_trigger(self,t)\n  judge()\n else:\n  if not target.is_empty(): complete_trigger_target(t,target)\n  pending={}\n revision+=1; pump_choices()'),
 ('"label":labels[key]','"label":labels.get(key,Pack.text(cards[c.card_id],key))'),
 ('if winner!=-2 or phase=="mulligan" or not pending.is_empty() or priority!=who or c.owner!=who:','if winner!=-2 or phase=="mulligan" or not pending.is_empty() or priority!=who or c.owner!=who or Pack.response_locked(self):'),
 (' if c.zone!=zone: return "区域不符"',' if c.zone!=zone: return "区域不符"\n if key in Pack.ACTIVATIONS:\n  var reason=Pack.activation_error(self,c,key)\n  if not reason.is_empty(): return reason'),
 ('if target not in Extra.activation_options(self,c,key):','if not Pack.choice_valid(self,Extra.activation_options(self,c,key),target):'),
 ('else: find_card(item.uid).tapped=true','else: tap_card(find_card(item.uid))'),
 ('if key=="exile_grave": c.tapped=true','if key=="exile_grave": tap_card(c)'),
 (' var source=c.duplicate(true)\n if key==',' var source=c.duplicate(true)\n if key in Pack.ACTIVATIONS: Pack.pay_activation(self,c,key,target)\n if key=='),
 (' next_stack+=1; passes=0; priority=1-who; note("发动 "+cards[c.card_id].name); pump_choices()', ' if key in Pack.ACTIVATIONS: stack.back().ability_text=Pack.text(cards[c.card_id],key)\n next_stack+=1; passes=0; priority=1-who; note("发动 "+cards[c.card_id].name); judge(); pump_choices()'),
 ('not Extra.has(cards[c.card_id],"timed_life"): return "该符卡不能留在战场"','not Extra.has(cards[c.card_id],"timed_life") and not ("时符" in cards[c.card_id].get("spell_type","") or "乐章" in cards[c.card_id].get("spell_type","")): return "该符卡不能留在战场"'),
 ('func spell_target_valid(id: String,target: Dictionary) -> bool:\n', 'func spell_target_valid(id: String,target: Dictionary) -> bool:\n if not Pack.key(cards[id],Pack.SPELLS).is_empty(): return Pack.target_survives(self,id,target)\n'),
 (' var id=c.card_id\n var candidates=', ' var id=c.card_id\n var effect=Pack.key(cards[id],Pack.SPELLS)\n if not effect.is_empty() or Pack.has(cards[id],"byakuren_x"): return Pack.ai_target(self,who,options,effect)\n var candidates='),
 ('  if key not in ["exile_grave","grave_return","grave_reanimate"]: continue', '  if key in Pack.ACTIVATIONS:\n   if key=="minoriko_untap" and not players[who].palette.any(func(p): return p.tapped): continue\n   if key in ["letty_shield","wine_discount","medicine_return","standing_blast"] and combat.is_empty(): continue\n   if key=="keine_devour": continue\n   var options=Extra.activation_options(self,c,key)\n   var target=Pack.ai_target(self,who,options,key)\n   if not target.is_empty() and commit_extension(who,c.uid,target,payment(who,Extra.activation_cost(key)).plan).is_empty(): return true\n   continue\n  if key not in ["exile_grave","grave_return","grave_reanimate"]: continue'),
])
p=ROOT/'scripts/rules/duel_engine.gd';s=p.read_text('utf-8')
a=s.index('func damage_target(');b=s.index('func stat(',a)
s=s[:a]+'''func tap_card(c: Dictionary):
 if c.is_empty() or c.tapped: return
 c.tapped=true; Pack.on_tap(self,c)
func gain_life(who: int,amount: int):
 if amount<=0: return
 players[who].life+=amount; Pack.on_gain_life(self,who,amount)
func damage_target(target: Dictionary,amount: int) -> int:
 if amount<=0 or not target_valid(target): return 0
 amount=Pack.adjusted_damage(self,target,amount)
 if amount<=0: return 0
 if target.has("player"): players[int(target.player)].life-=amount
 else:
  var c=find_card(target.uid); c.damage+=amount
  record_history(cards[c.card_id].name+"受到%d点伤害" % amount,history_art(c))
  c.spell_damage=resolving_spell
 Pack.on_damage(self,target,amount)
 return amount
func combat_hit(source: Dictionary,target: Dictionary,amount: int) -> int:
 var old=damage_context
 damage_context={"source":source,"combat":true,"single":true}
 var result=damage_target(target,amount); damage_context=old
 return result
'''+s[b:]
p.write_text(s,encoding='utf-8')
