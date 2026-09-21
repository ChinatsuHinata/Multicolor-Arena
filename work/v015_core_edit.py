from pathlib import Path
root=Path('.')
def edit(name,old,new):
 p=root/name;s=p.read_text('utf-8');assert old in s,(name,old[:100]);p.write_text(s.replace(old,new),encoding='utf-8')
e='scripts/rules/duel_engine.gd'
edit(e,'var reveal_serial=0','var reveal_serial=0\n# Private declaration preference; cleared on commit/cancel, never a paid action.\nvar paid_cast_uid=-1')
edit(e,'func history_art(c: Dictionary) -> Array:', '''func show_result(message: String,source: Dictionary={}):
 note(message,history_art(source))
 presentation_events.append({"type":"result","text":message,"card":source.duplicate(true)})
func record_declaration(who: int,target: Dictionary,source: Dictionary):
 var parts=[]
 for key in ["card_name","color","guess","declaration"]:
  if target.has(key):parts.append(str(target[key]))
 if not parts.is_empty():show_result(("你" if who==0 else "人机")+"宣言 · "+" / ".join(parts),source)
func present_move(c: Dictionary,destination: String,to_owner: int=-1):
 if c.get("zone","") in ["", "void"]:return
 presentation_events.append({"type":"move","card":c.duplicate(true),"from":c.zone,"to":destination,"to_owner":c.owner if to_owner<0 else to_owner})
func history_art(c: Dictionary) -> Array:''')
edit(e,' Roster.on_coin(self,who);Cat.State.on_coin(self,who,heads)',' show_result(("你" if who==0 else "人机")+"掷硬币 · "+("正面" if heads else "反面"))\n Roster.on_coin(self,who);Cat.State.on_coin(self,who,heads)')
edit(e,' forced_cast={};extra_turns=[];presentation_events.clear();reveal_serial=0',' forced_cast={};paid_cast_uid=-1;extra_turns=[];presentation_events.clear();reveal_serial=0')
edit(e,' var old=c.get("zone","")\n',' var old=c.get("zone","")\n present_move(c,location)\n')
start=Path(e).read_text('utf-8'); a=start.index('func begin_trigger(');b=start.index('func choose_trigger_order(',a)
edit(e,start[a:b],'''func begin_trigger(t: Dictionary):
 var options=trigger_options(t)
 # A lack of legal targets does not erase a triggered event.
 var no_targets=options.is_empty()
 if no_targets:options=[{"none":true}]
 if t.get("effect","")=="untap":
  push_trigger(t,ref_target(t.source));return
 var kind="effect_choice" if t.get("extended",false) else "trigger"
 var optional=t.get("optional",true)
 var id=push_trigger(t,{} if optional or options!=[{"none":true}] else options[0])
 stack.back().no_legal_targets=no_targets
 if optional or options!=[{"none":true}]:
  stack.back().awaiting_target=true
  pending={"kind":kind,"owner":t.owner,"trigger":t,"options":options,"stack_id":id,"no_legal_targets":no_targets}
func decline_stacked_trigger():
 if not pending.has("stack_id"):return
 for entry in stack.duplicate():
  if entry.id==pending.stack_id:
   stack.erase(entry)
   note("不发动 · "+entry.name,history_art(entry.source))
func accept_trigger(entry: Dictionary):
 if entry.get("announced",false):return
 entry.announced=true
 if entry.get("effect","")=="leader_death_damage":use_once(entry.source.uid,"death_ping")
 if not entry.get("no_legal_targets",false):Roster.on_ability_announced(self,entry)
''')
edit(e,'   triggers=triggers.filter(func(t): return not trigger_options(t).is_empty())\n','') if '   triggers=triggers.filter' in Path(e).read_text('utf-8') else None
edit(e,'  triggers=triggers.filter(func(t): return not trigger_options(t).is_empty())\n  if triggers.is_empty(): break\n','')
edit(e,' if target.is_empty() and (not t.get("optional",true) or pending.has("stack_id")): return',' if target.is_empty() and not t.get("optional",true): return')
edit(e,' if not target.is_empty() and target not in trigger_options(t): return\n if not target.is_empty(): complete_trigger_target(t,target)',' if not target.is_empty() and target not in pending.options: return\n if not target.is_empty(): complete_trigger_target(t,target)\n else:decline_stacked_trigger()')
edit(e,'   if e.kind=="ability":\n    if e.get("extended",false):','   if e.kind=="ability":\n    if e.get("no_legal_targets",false):pass\n    elif e.get("extended",false):')
edit(e,' if t.get("effect","")=="leader_death_damage": use_once(t.source.uid,"death_ping")\n','')
edit(e,' if not target.is_empty():Roster.on_ability_announced(self,entry)',' if not target.is_empty():accept_trigger(entry)')
edit(e,'     entry.target=target.duplicate(true); entry.erase("awaiting_target");Roster.on_ability_announced(self,entry); return','     entry.target=target.duplicate(true); entry.erase("awaiting_target");accept_trigger(entry); return')
edit(e,' if target.is_empty() and (not t.optional or pending.has("stack_id")): return',' if target.is_empty() and not t.optional: return')
edit(e,'  else:\n   if not target.is_empty(): complete_trigger_target(t,target)\n   pending={}','  else:\n   if not target.is_empty(): complete_trigger_target(t,target)\n   else:decline_stacked_trigger()\n   pending={}') if '  else:\n   if not target.is_empty(): complete_trigger_target(t,target)' in Path(e).read_text('utf-8') else edit(e,' else:\n  if not target.is_empty(): complete_trigger_target(t,target)\n  pending={}',' else:\n  if not target.is_empty(): complete_trigger_target(t,target)\n  else:decline_stacked_trigger()\n  pending={}')
edit(e,' if t.get("continuation",false):\n  pending={}\n',' record_declaration(t.owner,target,t.source)\n if t.get("continuation",false):\n  pending={}\n')
edit(e,' if c.is_empty() or c.zone!="field" or not is_unit(c): return false',' if c.is_empty() or c.zone!="field" or not is_unit(c) or has_haste(c): return false')
edit(e,'  stack.back().die=rng.randi_range(1,6);note("D6 · %d" % stack.back().die)','  stack.back().die=rng.randi_range(1,6);show_result("D6 · %d" % stack.back().die,c)')
edit(e,' Cat.pay(self,who,plan)\n catalogue_serial+=1\n var source=c.duplicate(true)',' Cat.pay(self,who,plan)\n record_declaration(who,target,c)\n catalogue_serial+=1\n var source=c.duplicate(true)')
# Timer replacement is only offered by an actual authorized ability and positive placement.
edit(e,' for unit in units(0)+units(1):\n  if Extra.has(cards[unit.card_id],"timer_replace") and has_leader_ability(unit): timer_changes.append({"owner":unit.owner,"ref":ref_target(c),"amount":amount})',' if amount<=0 or c.zone not in ["field","leader"]:return\n for unit in units(0)+units(1):\n  if Extra.has(cards[unit.card_id],"timer_replace") and has_leader_ability(unit):timer_changes.append({"owner":unit.owner,"ref":ref_target(c),"source":ref_target(unit),"source_name":cards[unit.card_id].name,"amount":amount})')
edit(e,' if not c.is_empty() and c.epoch==change.ref.epoch: c.timer=maxi(0,c.timer+delta)',' var source=find_card(change.get("source",{}).get("uid",0))\n if not source.is_empty() and source.epoch==change.source.epoch and Extra.has(cards[source.card_id],"timer_replace") and has_leader_ability(source) and change.amount>0 and not c.is_empty() and c.epoch==change.ref.epoch:\n  c.timer=maxi(0,c.timer+delta)\n  if delta!=0:note(change.source_name+" · 计时指示物 "+("+1" if delta>0 else "−1"),history_art(c))')
# Keep original visual source when owner changes; token and returning leader also emit moves.
edit(e,'  c.zone=zone;Roster.on_leave(self,before,c)','  present_move(c,zone);c.zone=zone;Roster.on_leave(self,before,c)')
edit(e,'  c.zone="return_pending"; c.epoch+=1;','  present_move(c,"return_pending");c.zone="return_pending"; c.epoch+=1;')
# Central cast-mode preference is consulted by every free-cost provider.
for f,needle in [('scripts/rules/excel_abilities.gd','static func free_cast(e,c: Dictionary,who: int) -> bool:\n'),('scripts/rules/catalogue_state.gd','static func free_cast(e,c,who):\n')]:edit(f,needle,needle+' if e.paid_cast_uid==c.uid:return false\n')
edit('scripts/rules/precon_abilities.gd',' if c.zone=="exile" and c.get("free_exile_owner",-1)==who: return {}',' if e.paid_cast_uid!=c.uid and c.zone=="exile" and c.get("free_exile_owner",-1)==who: return {}')
edit('scripts/rules/excel_abilities.gd',' if not e.forced_cast.is_empty() or e.players[who].field.any(func(u):return has(e.cards[u.card_id],"free_anthem")):limit=0',' if (not e.forced_cast.is_empty() and e.forced_cast.get("free",true) and e.paid_cast_uid!=e.forced_cast.uid) or (e.paid_cast_uid<0 and e.players[who].field.any(func(u):return has(e.cards[u.card_id],"free_anthem"))):limit=0')
# ETB entry event must also work when moved by effects.
edit('scripts/rules/demo_abilities.gd','  var entered=engine.enter_field(entry.card,entry.owner)\n  if entered and DB.has_ability(card,"marisa_enter"):\n   engine.queue_trigger(entry.owner,entry.card,int(DB.ability(card,"marisa_enter")["数值"]),"进战场能力")','  engine.enter_field(entry.card,entry.owner)')
edit('scripts/rules/expanded_abilities.gd',' var info=e.cards[c.card_id]\n if has(info,"leader_enter_modes")',' var info=e.cards[c.card_id]\n if e.DB.has_ability(info,"marisa_enter"):e.queue_trigger(c.owner,c,int(e.DB.ability(info,"marisa_enter")["数值"]),"进战场能力")\n if has(info,"leader_enter_modes")')
edit('scripts/rules/catalogue_units.gd','  C.choose(e,{"owner":who,"source":c.duplicate(true)},"cat:momiji_name",C.name_options(e),{"ref":C.ref(e,c)})','  C.events(e,c,"cat:momiji_name",false,{"ref":C.ref(e,c)})')
edit('scripts/rules/catalogue_units.gd',' match k:\n  "character-lof-004","character-htk-005":',' match k:\n  "cat:momiji_name":return C.name_options(e)\n  "cat:etb_curse":return e.Pack.none()\n  "character-lof-004","character-htk-005":')
edit('scripts/rules/catalogue_units.gd','   if int(p.get("etb_curse",0))>0:e.players[1-e.players.find(p)].life-=2*int(p.etb_curse)','   for source in p.get("etb_curse_sources",[]):C.events(e,source,"cat:etb_curse")')
edit('scripts/rules/catalogue_units.gd',' match k:\n  "character-lof-004":',' match k:\n  "cat:etb_curse":e.players[1-who].life-=2\n  "character-lof-004":')
edit('scripts/rules/catalogue_spells.gd','  "spell-fdf-014":p.etb_curse=int(p.get("etb_curse",0))+1','  "spell-fdf-014":\n   p.etb_curse=int(p.get("etb_curse",0))+1\n   p.etb_curse_sources=p.get("etb_curse_sources",[])+[c.duplicate(true)]')
# Centralized coin result includes player and history; don't duplicate.
edit('scripts/rules/excel_abilities.gd','var heads=e.flip_coin(who);e.note("古明地恋 · "+("正面" if heads else "反面"))','var heads=e.flip_coin(who)')
edit('scripts/rules/precon_abilities.gd','var heads=e.flip_coin(who); e.note("旧都 · "+("正面" if heads else "反面"))','var heads=e.flip_coin(who)')
print('core edited')
