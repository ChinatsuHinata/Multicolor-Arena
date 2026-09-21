from pathlib import Path
import json,re
R=Path(__file__).resolve().parents[1]
def patch(path,changes):
 p=R/path;s=p.read_text(encoding='utf-8-sig')
 for old,new in changes:
  assert old in s,(path,old[:120]);s=s.replace(old,new,1)
 p.write_text(s,encoding='utf-8')
patch('scripts/rules/expanded_abilities.gd',[
 ('return e.Pack.dynamic_keyword(e,c,k)','return e.Roster.keyword(e,c,k) or e.Pack.dynamic_keyword(e,c,k)'),
 ('int(c.get("cast_x",0)) if c.zone=="stack"','int(c.get("cast_x",0))*int(e.cards[c.card_id].get("variable_multiplier",1)) if c.zone=="stack"'),
 ('static func spell_options(e,id: String,who: int) -> Variant:\n','static func spell_options(e,id: String,who: int) -> Variant:\n var roster=e.Roster.spell_options(e,id,who)\n if roster!=null:return roster\n'),
 ('static func on_enter(e,c: Dictionary):\n','static func on_enter(e,c: Dictionary):\n e.Roster.on_enter(e,c)\n'),
 ('static func on_death(e,c: Dictionary,before: Dictionary):\n','static func on_death(e,c: Dictionary,before: Dictionary):\n e.Roster.on_death(e,c,before)\n'),
 ('static func trigger_options(e,t: Dictionary) -> Array:\n','static func trigger_options(e,t: Dictionary) -> Array:\n if t.get("roster",false):return e.Roster.trigger_options(e,t)\n'),
 ('static func resolve_trigger(e,t: Dictionary):\n','static func resolve_trigger(e,t: Dictionary):\n if t.get("roster",false):e.Roster.resolve_trigger(e,t);return\n'),
 ('static func spell_resolve(e,entry: Dictionary) -> bool:\n','static func spell_resolve(e,entry: Dictionary) -> bool:\n if e.Roster.spell_resolve(e,entry):return true\n'),
 ('static func register_tokens(e):\n','static func register_tokens(e):\n e.Roster.register_tokens(e)\n'),
 ('static func activation_kind(info: Dictionary) -> String:\n','static func activation_kind(info: Dictionary) -> String:\n var roster=preload("res://scripts/rules/excel_abilities.gd")\n var k=roster.key(info,roster.ACTIVATIONS)\n if not k.is_empty():return k\n'),
 ('static func activation_options(e,c: Dictionary,key: String) -> Array:\n','static func activation_options(e,c: Dictionary,key: String) -> Array:\n if key in e.Roster.ACTIVATIONS:return e.Roster.filter_options(e,e.Roster.activation_options(e,c,key),c.owner,false)\n'),
 ('static func activation_cost(key: String) -> Dictionary:\n','static func activation_cost(key: String) -> Dictionary:\n var roster=preload("res://scripts/rules/excel_abilities.gd")\n if key in roster.ACTIVATIONS:return roster.activation_cost(key)\n'),
 ('static func resolve_activation(e,entry: Dictionary):\n','static func resolve_activation(e,entry: Dictionary):\n if entry.effect in e.Roster.ACTIVATIONS:e.Roster.resolve_activation(e,entry);return\n'),
])
patch('scripts/rules/precon_abilities.gd',[
 ('static func fast(e,c: Dictionary,who: int) -> bool:\n','static func fast(e,c: Dictionary,who: int) -> bool:\n if e.Roster.fast(e,c,who):return true\n'),
 ('static func cast_from(e,c: Dictionary,who: int) -> bool:\n','static func cast_from(e,c: Dictionary,who: int) -> bool:\n if e.Roster.permission(e,c,who):return true\n'),
 ('+int(target.get("x",0))','+int(target.get("x",0))*int(info.get("variable_multiplier",1))'),
 (' if chromatic(e,c,who):',' result=e.Roster.cost(e,c,who,result)\n if chromatic(e,c,who):'),
 ('static func reset_allowed(e,c: Dictionary) -> bool:\n','static func reset_allowed(e,c: Dictionary) -> bool:\n if not e.Roster.reset_allowed(e,c):return false\n'),
 (' if "吸血1" in info.get("keywords",[]) and',' var lifesteal=e.Roster.lifesteal(e,source)\n if lifesteal>0 and'),
 ('e.gain_life(source.owner,1)','e.gain_life(source.owner,lifesteal)'),
])
patch('scripts/rules/duel_engine.gd',[
 ('const Pack=','const Roster=preload("res://scripts/rules/excel_abilities.gd")\nconst Pack='),
 ('var unpreventable_turn=-1','var unpreventable_turn=-1\nvar forced_cast={}\nvar extra_turns=[]'),
 (' recorded_life=[20,20]\n',' forced_cast={};extra_turns=[]\n recorded_life=[20,20]\n'),
 (' if old!="stack" or location!="field": c.erase("cast_x")',' for k in ["minus_counters","freeze_until","perfect_lock","control_return","died_turn","excel_access","exile_on_grave"]:c.erase(k)\n if old!="stack" or location!="field": c.erase("cast_x")'),
 ('if info.kind=="自机":\n   var provided','if info.kind=="自机" and not Roster.bypass(self,c,who):\n   var provided'),
 (' if not info.requires_character.is_empty():',' if not info.requires_character.is_empty() and not Roster.bypass(self,c,who):'),
 (' if extended!=null: return extended',' if extended!=null: return Roster.filter_options(self,extended,acting,true)'),
 (' return targets\nfunc ref_target',' return Roster.filter_options(self,targets,acting,true)\nfunc ref_target'),
 (' # All validation completes before any public mutation.',' if Roster.key(info,["discard_draw","door_reveal"])!="" and Pack.picked(target).any(func(r):return r.uid==uid):return "不能弃置正在使用的牌"\n var old_zone=c.zone\n # All validation completes before any public mutation.\n if Roster.key(info,["discard_draw","door_reveal"])!="":\n  for r in Pack.picked(target):move_to(find_card(r.uid),"grave")'),
 (' Pack.on_cast(self,c,who,target)',' Roster.on_cast(self,c,who,old_zone)\n Pack.on_cast(self,c,who,target)'),
 ('shift(c,"leader"); add_timer(c,2)','shift(c,"leader"); add_timer(c,0 if Roster.enabled(self,before,"cirno_return") else 2)'),
 ('  if destination=="grave" and before.zone=="field": Extra.on_death(self,c,before)','  if destination=="grave" and before.zone=="field": Extra.on_death(self,c,before)\n  if before.zone=="field":Roster.on_leave(self,before,c)'),
 ('  var c=find_card(target.uid); c.damage+=amount','  var c=find_card(target.uid)\n  if Roster.wither(self):c.minus_counters=int(c.get("minus_counters",0))+amount\n  else:c.damage+=amount'),
 (' Pack.on_damage(self,target,amount)',' Pack.on_damage(self,target,amount)\n Roster.on_damage(self,target,amount)'),
 ('var value=Pack.base_stat(self,c,key)+int(c.get("plus_counters",0))','var value=Pack.base_stat(self,c,key)+int(c.get("plus_counters",0))+Roster.stat_adjust(self,c,key)'),
 ('return maxi(0,value)','return value if key=="health" else maxi(0,value)'),
 ('stat(c,"health")==0','stat(c,"health")<=0'),
 ('  var source=e.get("card",e.get("source",{}))','  e.target=Roster.invalidate(self,e.target,e.owner,e.kind=="card")\n  var source=e.get("card",e.get("source",{}))'),
 ('  "possession": phase="main"','  "possession": phase="main";Roster.on_phase(self,"main");pump_choices()'),
 ('   Pack.on_phase(self,"end")','   Pack.on_phase(self,"end");Roster.on_phase(self,"end")'),
 ('func finish_turn():\n','func finish_turn():\n Roster.cleanup(self)\n'),
 (' start_turn(1-active)',' start_turn(extra_turns.pop_front() if not extra_turns.is_empty() else 1-active)'),
 (' var options=players[who].hand.duplicate()',' var options=players[who].hand.duplicate()\n options.append_array(players[who].grave.filter(func(c):return Roster.permission(self,c,who)))'),
 (' var extra=extra_action(c)\n if not extra.is_empty():\n  extra.enabled=extension_activation_error(who,c).is_empty()\n  if extra.enabled or include_disabled: result.append(extra)',' var extra=extra_action(c)\n if not extra.is_empty() and extra.key not in Roster.ACTIVATIONS:\n  extra.enabled=extension_activation_error(who,c).is_empty()\n  if extra.enabled or include_disabled: result.append(extra)\n for k in Roster.ACTIVATIONS:\n  if not Roster.has(cards[c.card_id],k):continue\n  var reason=extension_activation_error(who,c,k)\n  if reason.is_empty() or include_disabled:result.append({"type":"extension","uid":uid,"key":k,"label":Roster.text(cards[c.card_id],k),"enabled":reason.is_empty(),"reason":reason})'),
 (' var before=c.duplicate(true)\n detach(c)',' if zone=="grave" and c.get("exile_on_grave",false):zone="exile"\n var before=c.duplicate(true)\n detach(c)'),
 (' if before.zone=="field" and zone=="grave": Extra.on_death(self,c,before)',' if before.zone=="field" and zone=="grave": Extra.on_death(self,c,before)\n if before.zone=="field":Roster.on_leave(self,before,c)'),
 ('t.target=target; Pack.resolve_trigger(self,t)','t.target=target; Extra.resolve_trigger(self,t)'),
 ('  delayed.erase(d)\n  var c=find_card(d.ref.uid)','  delayed.erase(d)\n  if d.get("roster",false):Roster.event(self,d.source,d.effect,false);continue\n  var c=find_card(d.ref.uid)'),
 ('func extension_activation_error(who: int,c: Dictionary) -> String:','func extension_activation_error(who: int,c: Dictionary,key: String="") -> String:'),
 (' var key=Extra.activation_kind(cards[c.card_id])\n if key.is_empty(): return "没有该异能"',' if key.is_empty():key=Extra.activation_kind(cards[c.card_id])\n if key.is_empty(): return "没有该异能"\n if key in Roster.ACTIVATIONS:\n  var reason=Roster.activation_error(self,c,key)\n  if not reason.is_empty():return reason'),
 ('func commit_extension(who: int,uid: int,target: Dictionary,plan: Array) -> String:','func commit_extension(who: int,uid: int,target: Dictionary,plan: Array,key: String="") -> String:'),
 (' var error=extension_activation_error(who,c)\n if not error.is_empty(): return error\n var key=Extra.activation_kind(cards[c.card_id])',' if key.is_empty():key=Extra.activation_kind(cards[c.card_id])\n var error=extension_activation_error(who,c,key)\n if not error.is_empty(): return error'),
 (' if key in Pack.ACTIVATIONS: Pack.pay_activation(self,c,key,target)',' if key in Roster.ACTIVATIONS:Roster.pay_activation(self,c,key,target)\n if key in Pack.ACTIVATIONS: Pack.pay_activation(self,c,key,target)'),
 (' if key in Pack.ACTIVATIONS: stack.back().ability_text',' if key in Roster.ACTIVATIONS:stack.back().ability_text=Roster.text(cards[c.card_id],key)\n if key in Pack.ACTIVATIONS: stack.back().ability_text'),
 ('func spell_target_valid(id: String,target: Dictionary) -> bool:\n','func spell_target_valid(id: String,target: Dictionary) -> bool:\n if not Roster.key(cards[id],Roster.SPELLS).is_empty():return Roster.target_survives(self,id,target)\n'),
 (' var effect=Pack.key(cards[id],Pack.SPELLS)',' var roster=Roster.key(cards[id],Roster.SPELLS)\n if not roster.is_empty():return Roster.ai_target(self,who,c,options)\n var effect=Pack.key(cards[id],Pack.SPELLS)'),
])
# Registry is generated from reviewed, explicit bindings, never from arbitrary prose.
p=R/'scripts/card_database.gd';s=p.read_text(encoding='utf-8-sig')
ids=json.loads(re.search(r'const IDS=(\[.*\])',s)[1]);ids+=json.loads((R/'work/v011/new-ids.json').read_text())
s=re.sub(r'const IDS=\[.*\]', 'const IDS='+json.dumps(ids,ensure_ascii=False),s)
effects=sorted({a['参数']['效果'] for f in (R/'cards').glob('*.json') for a in json.loads(f.read_text(encoding='utf-8-sig'))['能力绑定'] if a['实现']=='roster'})
s=s.replace('const COLORS=','const ROSTER_EFFECTS='+json.dumps(effects,ensure_ascii=False)+'\nconst COLORS=',1)
s=s.replace('"extension","precon"]','"extension","precon","roster"]',1)
s=s.replace('  if handler=="precon"','  if handler=="roster" and (not params is Dictionary or params.get("效果","") not in ROSTER_EFFECTS):return "未登记的Excel效果"\n  if handler=="precon"',1)
s=s.replace('"variable_cost":d.get("可变费用","")','"variable_multiplier":int(d.get("X费用倍率",1)),"variable_cost":d.get("可变费用","")',1)
p.write_text(s,encoding='utf-8')
print('Integrated Excel rules and registered',len(ids),'cards.')
