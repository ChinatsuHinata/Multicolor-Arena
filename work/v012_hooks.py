from pathlib import Path
R=Path(__file__).resolve().parents[1]
def edit(file,changes):
 p=R/file;s=p.read_text(encoding='utf-8')
 for a,b in changes:
  assert a in s,(file,a)
  s=s.replace(a,b,1)
 p.write_text(s,encoding='utf-8')
edit('scripts/rules/excel_abilities.gd',[
 ('const ACTIVATIONS=[','const Batch=preload("res://scripts/rules/mask_abilities.gd")\nconst ACTIVATIONS=["courage_ping","courage_die","tokiko_copy","mask_joy","mask_anger","mask_sorrow",'),
 ('const SPELLS=[','const SPELLS=["peach_modes","fairy_rewrite","night_sakura","blue_flower","icicle_tide","emotions","angry_mask",'),
 ('const LEADER=[','const LEADER=["sanae_miracle","courage_die","kokoro_self","tokiko_discount",'),
 ('static func plus(e,c: Dictionary,n: int):','static func plus(e,c: Dictionary,n: int,placer: int=-1):'),
 (' c.plus_counters=int(c.get("plus_counters",0))+n',' Batch.counter(e,c,"plus_counters",n,c.owner if placer<0 else placer)'),
 (' return result\nstatic func protected',' return Batch.cost(e,c,who,result)\nstatic func protected'),
 ('static func spell_options(e,id: String,who: int) -> Variant:\n','static func spell_options(e,id: String,who: int) -> Variant:\n var batch=Batch.spell_options(e,id,who)\n if batch!=null:return batch\n'),
 ('static func on_enter(e,c: Dictionary):\n','static func on_enter(e,c: Dictionary):\n Batch.on_enter(e,c)\n'),
 ('static func on_cast(e,c: Dictionary,who: int,old_zone: String):\n','static func on_cast(e,c: Dictionary,who: int,old_zone: String):\n Batch.on_cast(e,c,who)\n'),
 ('static func on_phase(e,phase: String):\n','static func on_phase(e,phase: String):\n Batch.on_phase(e,phase)\n'),
 (' if t.get("continuation",false):return e.pending.get("options",[])',' if t.get("continuation",false):return e.pending.get("options",[])\n var batch=Batch.trigger_options(e,t)\n if batch!=null:return batch'),
 ('static func resolve_trigger(e,t: Dictionary):\n','static func resolve_trigger(e,t: Dictionary):\n if Batch.resolve_trigger(e,t):return\n'),
 ('if unit(e,aim):e.find_card(aim.uid).scare=int(e.find_card(aim.uid).get("scare",0))+1','if unit(e,aim):Batch.counter(e,e.find_card(aim.uid),"scare",1,who)'),
 ('if unit(e,data.ref):e.find_card(data.ref.uid).minus_counters=int(e.find_card(data.ref.uid).get("minus_counters",0))+3','if unit(e,data.ref):Batch.counter(e,e.find_card(data.ref.uid),"minus_counters",3,who)'),
 ('static func spell_resolve(e,entry: Dictionary) -> bool:\n','static func spell_resolve(e,entry: Dictionary) -> bool:\n if Batch.spell_resolve(e,entry):return true\n'),
 ('if unit(e,t):var u=e.find_card(t.uid);u.leader_counters=int(u.get("leader_counters",0))+1','if unit(e,t):Batch.counter(e,e.find_card(t.uid),"leader_counters",1,who)'),
 ('static func activation_error(e,c: Dictionary,k: String) -> String:\n','static func activation_error(e,c: Dictionary,k: String) -> String:\n if k in Batch.ACTIVATIONS:return Batch.activation_error(e,c,k)\n'),
 ('static func activation_options(e,c: Dictionary,k: String) -> Array:\n','static func activation_options(e,c: Dictionary,k: String) -> Array:\n if k in Batch.ACTIVATIONS:return Batch.activation_options(e,c,k)\n'),
 ('static func pay_activation(e,c: Dictionary,k: String,t: Dictionary):\n','static func pay_activation(e,c: Dictionary,k: String,t: Dictionary):\n if k in Batch.ACTIVATIONS:Batch.pay_activation(e,c,k);return\n'),
 ('static func resolve_activation(e,entry: Dictionary):\n','static func resolve_activation(e,entry: Dictionary):\n if entry.effect in Batch.ACTIVATIONS:Batch.resolve_activation(e,entry);return\n'),
 ('static func target_survives(e,id: String,t: Dictionary) -> bool:\n','static func target_survives(e,id: String,t: Dictionary) -> bool:\n if has(e.cards[id],"emotions") and e.Pack.flatten(t).is_empty():return true\n')
])
edit('scripts/rules/duel_engine.gd',[
 ('"minus_counters","scare","freeze_until"','"courage","moods","minus_counters","scare","freeze_until"'),
 (' Pack.on_phase(self,"prepare")',' Pack.on_phase(self,"prepare");Roster.on_phase(self,"prepare")'),
 ('if Roster.wither(self):c.minus_counters=int(c.get("minus_counters",0))+amount','if Roster.wither(self):Roster.Batch.counter(self,c,"minus_counters",amount,damage_context.get("source",{}).get("owner",1-c.owner))'),
 ('  elif cards[e.card.card_id].kind=="符卡" and not spell_target_valid','  elif e.get("rewritten_fairy",false):Roster.Batch.rewritten_resolve(self,e);note(e.name+"改写效果结算",history_art(e.card))\n  elif cards[e.card.card_id].kind=="符卡" and not spell_target_valid'),
 (' if c.is_empty() or c.owner!=who or c.zone!="field": return "需要操控该永久物"',' if c.is_empty() or c.owner!=who or c.zone!="field": return "需要操控该永久物"\n if Roster.Batch.locked(self,c):return "绵月丰姬：只能在自己的回合启动单位能力"'),
 (' if key.is_empty():key=Extra.activation_kind(cards[c.card_id])\n if key.is_empty(): return "没有该异能"',' if Roster.Batch.locked(self,c):return "绵月丰姬：只能在自己的回合启动单位能力"\n if key.is_empty():key=Extra.activation_kind(cards[c.card_id])\n if key.is_empty(): return "没有该异能"'),
 (' if key in Roster.ACTIVATIONS:stack.back().ability_text=Roster.text(cards[c.card_id],key)',' if key=="courage_die":\n  stack.back().die=rng.randi_range(1,6);note("D6 · %d" % stack.back().die)\n if key in Roster.ACTIVATIONS:stack.back().ability_text=Roster.text(cards[c.card_id],key)'),
 (' c.timer+=amount',' Roster.Batch.counter(self,c,"timer",amount,c.owner)')
])
edit('scripts/rules/precon_abilities.gd',[
 ('  if e.Extra.keyword(e,c,"防止伤害"): return 0','  if e.Extra.keyword(e,c,"防止伤害"): return 0\n  if not combat and e.Roster.has(e.cards[c.card_id],"sannyo_prevent"):return 0'),
 ('c.plus_counters=int(c.get("cast_x",0)); event(e,c,"byakuren_x",false,{"x":c.plus_counters})','e.Roster.plus(e,c,int(c.get("cast_x",0))); event(e,c,"byakuren_x",false,{"x":int(c.get("cast_x",0))})'),
 ('c.color_counters=c.get("color_counters",[])+[t.color]','e.Roster.Batch.color_counter(e,c,t.color,who)')
])
edit('scripts/rules/expanded_abilities.gd',[
 ('if e.enter_field(dead,who): dead.plus_counters=1','if e.enter_field(dead,who): e.Roster.plus(e,dead,1,who)'),
 ('if original: c.plus_counters=c.get("plus_counters",0)+1','if original: e.Roster.plus(e,c,1,who)')
])
runner=(R/'work/run_godot_v011.py').read_text(encoding='utf-8').replace('work/v011','work/v012')
(R/'work/run_godot_v012.py').write_text(runner,encoding='utf-8')
