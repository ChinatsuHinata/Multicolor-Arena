from pathlib import Path
p=Path(__file__).resolve().parent.parent/'scripts/rules/duel_engine.gd'
s=p.read_text('utf-8')
s=s.replace('const Effects=', 'const Extra=preload("res://scripts/rules/expanded_abilities.gd")\nconst Effects=',1)
s=s.replace('var payment_memo={}','var payment_memo={}\nvar debug_enabled=false\nvar delayed=[]\nvar combat_queue=[]\nvar timer_changes=[]\nvar turn_usage={}\nvar resolving_spell=false\nvar cleanup_done=false')
s=s.replace('func _init(): cards=DB.load_cards()','func _init():\n cards=DB.load_cards()\n Extra.register_tokens(self)')
s=s.replace('players.clear(); stack.clear();','delayed.clear(); combat_queue.clear(); timer_changes.clear(); turn_usage.clear(); cleanup_done=false\n players.clear(); stack.clear();',1)
s=s.replace('"grave":[],"leader":','"grave":[],"exile":[],"leader":',1)
s=s.replace('c.modifiers=[]\nfunc draw','c.modifiers=[]; c.plus_counters=0; c.poverty=0; c.spell_damage=false\nfunc draw',1)
s=s.replace('phase="reset"','phase="reset"; turn_usage.clear(); cleanup_done=false',1)
s=s.replace('phase="prepare"\n note','phase="prepare"\n run_delayed("prepare")\n pump_choices()\n note',1)
s=s.replace('["deck","hand","field","palette","grave"]','["deck","hand","field","palette","grave","exile"]')
s=s.replace('c.zone not in ["hand","leader"]','c.zone not in ["hand","leader"] and not (c.zone=="deck" and Extra.has(cards[c.card_id],"deck_damage"))',1)
s=s.replace('if units(who).size()>=6: return "单位战场格已满"','if field_slots(who)>=6 and not Extra.keyword(self,c,"不占战场格"): return "单位战场格已满"',1)
s=s.replace('payment(who,info.cost).ways==0','payment(who,cast_cost(who,c)).ways==0',1)
s=s.replace('targets_for(c.card_id).is_empty()','targets_for(c.card_id,who).is_empty()',1)
s=s.replace('func targets_for(id: String) -> Array:\n var targets=[]','func targets_for(id: String,who: int=-1) -> Array:\n if who<0: who=priority\n var extended=Extra.spell_options(self,id,who)\n if extended!=null: return extended\n var targets=[]')
s=s.replace('target not in targets_for(c.card_id)','target not in targets_for(c.card_id,who)',1)
s=s.replace('payment_valid(who,info.cost,plan)','payment_valid(who,cast_cost(who,c),plan)',1)
s=s.replace('if c.zone=="hand": players[who].hand.erase(c)','if target.has("sacrifice"):\n  move_to(find_card(target.sacrifice.uid),"grave")\n detach(c)',1)
s=s.replace('func pump_choices():\n if not pending.is_empty() or winner!=-2: return','func pump_choices():\n if not pending.is_empty() or winner!=-2: return\n if not timer_changes.is_empty():\n  var change=timer_changes.pop_front()\n  pending={"kind":"timer","owner":change.owner,"change":change}; return',1)
s=s.replace('var t=triggers.pop_front()\n  if units','var t=triggers.pop_front()\n  if t.get("extended",false):\n   var options=Extra.trigger_options(self,t)\n   if options.is_empty(): continue\n   if options==[{"none":true}] and not t.optional:\n    push_extended_trigger(t,options[0]); continue\n   pending={"kind":"effect_choice","owner":t.owner,"trigger":t,"options":options}; return\n  if units',1)
s=s.replace('pending={"kind":"trigger","owner":t.owner,"trigger":t}; return','pending={"kind":"trigger","owner":t.owner,"trigger":t}; return\n if combat.is_empty() and not combat_queue.is_empty(): combat=combat_queue.pop_front(); priority=active; passes=0',1)
start=s.index('func choose_return(');end=s.index('func counter_entry(',start)
s=s[:start]+'''func choose_return(yes: bool):
 if pending.get("kind","")!="leader_return": return
 var c=pending.card
 var destination=c.get("return_destination","grave")
 var before=c.get("return_snapshot",c.duplicate(true)).duplicate(true)
 pending={}
 if yes:
  shift(c,"leader"); add_timer(c,2)
  note("自机返回自机区 · 计时 2")
 else:
  shift(c,destination); players[c.owner][destination].append(c)
  if destination=="grave" and before.zone=="field": Extra.on_death(self,c,before)
 c.erase("return_snapshot"); c.erase("return_destination")
 revision+=1; pump_choices()
func enter_field(c: Dictionary,who: int) -> bool:
 if not field_error(c,who).is_empty(): to_grave(c); return false
 shift(c,"field"); c.entered=turn; c.entered_turns=players[who].turns; players[who].field.append(c)
 Extra.on_enter(self,c)
 return true
func to_grave(c: Dictionary):
 move_to(c,"grave")
''' +s[end:]
s=s.replace('if e.id==id and e.kind=="card":\n   stack.erase(e); to_grave(e.card); note(e.name+"被反制"); return','if e.id==id:\n   stack.erase(e)\n   if e.kind=="card": to_grave(e.card)\n   note(e.name+"被反制"); return')
s=s.replace('else: find_card(target.uid).damage+=amount','else:\n  var c=find_card(target.uid)\n  if Extra.keyword(self,c,"防止伤害"): return\n  c.damage+=amount\n  if resolving_spell and amount>0: c.spell_damage=true',1)
s=s.replace('var value=int(cards[c.card_id][key])','var value=int(cards[c.card_id][key])+int(c.get("plus_counters",0))\n if key=="spirit" and c.zone=="field":\n  for permanent in players[c.owner].field:\n   if Extra.has(cards[permanent.card_id],"spirit_aura"): value+=1',1)
s=s.replace('return c.get("modifiers",[]).any(func(m): return m.get("疾行",false))','return Extra.keyword(self,c,"疾行")',1)
s=s.replace('if is_unit(c) and c.damage>=stat(c,"health"):\n    players[who].field.erase(c); to_grave(c); note(cards[c.card_id].name+"离开战场")','if is_unit(c) and (stat(c,"health")==0 or c.damage>=stat(c,"health") and not Extra.keyword(self,c,"不会被消灭")):\n    to_grave(c); note(cards[c.card_id].name+"离开战场")',1)
s=s.replace('if players[who].life<=0: dead.append(who)','if players[who].life<=0 and not cannot_lose(who): dead.append(who)',1)
s=s.replace('func lose(who: int,reason: String):\n if winner!=-2: return','func lose(who: int,reason: String,forced: bool=false):\n if winner!=-2: return\n if not forced and reason!="投降" and cannot_lose(who): return',1)
s=s.replace('if e.kind=="ability":\n   if e.get("effect","")=="untap":','if e.kind=="ability":\n   if e.get("extended",false): Extra.resolve_trigger(self,e)\n   elif e.get("activation",false): Extra.resolve_activation(self,e)\n   elif e.get("effect","")=="untap":',1)
s=s.replace('not target_valid(e.target):','not Extra.valid(self,e.target):',1)
s=s.replace('else: phase="draw"; draw(active)','else:\n    phase="draw"; draw(active)\n    if not players[active].hand.is_empty():\n     var drawn=players[active].hand.back()\n     if Extra.keyword(self,drawn,"奇迹"): Extra.event(self,drawn,"miracle",true)\n    pump_choices()',1)
s=s.replace('phase="end"\n   for c','phase="end"\n   run_delayed("end")\n   for c',1)
s=s.replace('if not stack.is_empty(): note("英勇进入堆叠")','if not stack.is_empty(): note("英勇进入堆叠")\n   pump_choices()',1)
s=s.replace('not c.tapped): pending={"kind":"possession"','not c.tapped and can_possess(c)): pending={"kind":"possession"',1)
s=s.replace('or p.tapped: return','or p.tapped or not can_possess(p) or not can_possess(h): return',1)
s=s.replace('var leader=players[active].leader\n if leader.zone=="leader": leader.timer=maxi(0,leader.timer-1)','if not cleanup_done:\n  cleanup_done=true\n  for c in players[active].field+[players[active].leader]:\n   if c.zone not in ["field","leader"] or c.timer<=0: continue\n   c.timer=maxi(0,c.timer-1)\n   if c.zone=="field" and Extra.has(cards[c.card_id],"timed_life") and c.timer==0: move_to(c,"grave"); lose(active,"反魂蝶计时归零",true)\n  pump_choices()\n  if not pending.is_empty() or not stack.is_empty() or winner!=-2: return',1)
s=s.replace('for c in p.field: c.damage=0; c.modifiers=[]','for c in p.field: c.damage=0; c.modifiers=[]; c.spell_damage=false',1)
s=s.replace('if c.tapped: continue\n  if DB.has_ability','if c.tapped: continue\n  if Extra.keyword(self,attacker,"不能被阻挡"): continue\n  if attacker.get("modifiers",[]).any(func(m): return m.get("不可阻挡颜色","") in cards[c.card_id].colors): continue\n  if DB.has_ability',1)
s=s.replace('"block_window":\n   if surviving.size()>1:', '''"block_window":
   if not combat.has("strike_round"):
    var fighters=[find_card(combat.attacker.uid)]+surviving.map(func(t): return find_card(t.uid))
    combat.first_strikers=fighters.filter(func(c): return Extra.keyword(self,c,"先制")).map(func(c): return c.uid)
    combat.strike_round="first" if not combat.first_strikers.is_empty() else "normal"
   if surviving.size()>1 and deals_combat_damage(find_card(combat.attacker.uid)):''',1)
s=s.replace('"damage_window": end_combat()','"first_damage_window":\n   combat.step="block_window"; combat.strike_round="second"; advance_combat()\n  "damage_window": end_combat()',1)
s=s.replace('var power=stat(attacker,"power")','var power=stat(attacker,"power") if deals_combat_damage(attacker) else 0',1)
s=s.replace('if combat.blockers.size()>1:\n  var total','if combat.blockers.size()>1 and power>0:\n  var total',1)
s=s.replace('if not combat.blocked: players[1-combat.owner].life-=stat(attacker,"spirit")','if not combat.blocked:\n  if deals_combat_damage(attacker): players[1-combat.owner].life-=stat(attacker,"spirit")',1)
s=s.replace('blocker.damage+=power if combat.blockers.size()==1 else int(allocation.get(str(t.uid),0))\n   retaliation+=stat(blocker,"power")','var amount=power if combat.blockers.size()==1 else int(allocation.get(str(t.uid),0)) if power>0 else 0\n   damage_target(t,amount)\n   if deals_combat_damage(blocker): retaliation+=stat(blocker,"power")\n   if amount>0 and not Extra.keyword(self,blocker,"防止伤害") and combat_exiles(attacker):\n    Extra.event(self,attacker,"combat_exile_target",false,{"ref":t})\n   if deals_combat_damage(blocker) and stat(blocker,"power")>0 and not Extra.keyword(self,attacker,"防止伤害") and combat_exiles(blocker):\n    Extra.event(self,blocker,"combat_exile_target",false,{"ref":combat.attacker})',1)
s=s.replace('attacker.damage+=retaliation','damage_target(combat.attacker,retaliation)',1)
s=s.replace('DB.has_ability(cards[attacker.card_id],"annihilate")','(DB.has_ability(cards[attacker.card_id],"annihilate") or Extra.keyword(self,attacker,"歼灭"))',1)
s=s.replace('find_card(t.uid).damage>=stat(find_card(t.uid),"health")','find_card(t.uid).damage>=stat(find_card(t.uid),"health") and not Extra.keyword(self,find_card(t.uid),"不会被消灭")',1)
s=s.replace('combat.step="damage_window"; priority=active','combat.step="first_damage_window" if combat.get("strike_round","")=="first" else "damage_window"; priority=active',1)
s=s.replace('var options=players[who].hand.duplicate()','var options=players[who].hand.duplicate()\n options.append_array(players[who].deck.filter(func(c): return Extra.has(cards[c.card_id],"deck_damage")))',1)
s=s.replace('"possession": ai_possession(who)','"effect_choice": choose_effect(pending.options[0])\n   "timer": choose_timer(0)\n   "possession": ai_possession(who)',1)
s=s.replace('payment(who,cards[c.card_id].cost)','payment(who,cast_cost(who,c))')
s=s.replace('payment(who,info.cost).plan','payment(who,cast_cost(who,c)).plan')
s=s.replace('func ai_spell_target(who: int,c: Dictionary) -> Dictionary:\n var info','func ai_spell_target(who: int,c: Dictionary) -> Dictionary:\n var expanded=Extra.spell_options(self,c.card_id,who)\n if expanded!=null: return expanded[0] if not expanded.is_empty() else {}\n var info',1)
s=s.replace('if palette[pi].tapped: continue','if palette[pi].tapped or not can_possess(palette[pi]): continue',1)
s=s.replace('for hi in range(hand.size()):\n   var trial','for hi in range(hand.size()):\n   if not can_possess(hand[hi]): continue\n   var trial',1)
s=s.replace('if c.is_empty() or c.owner!=who or c.zone!="field": return result','if c.is_empty() or c.owner!=who: return result\n var extra=extra_action(c)\n if not extra.is_empty():\n  extra.enabled=extension_activation_error(who,c).is_empty()\n  if extra.enabled or include_disabled: result.append(extra)\n if c.zone!="field": return result',1)
s=s.replace('for c in players[who].field:\n  if available_actions','for c in players[who].field+players[who].grave:\n  if available_actions',1).replace('a.type=="ability"','a.type in ["ability","extension"]',1)
s+='''
func field_slots(who: int) -> int:
 return units(who).filter(func(c): return not Extra.keyword(self,c,"不占战场格")).size()
func field_error(c: Dictionary,who: int) -> String:
 if is_unit(c):
  if field_slots(who)>=6 and not Extra.keyword(self,c,"不占战场格"): return "单位战场格已满"
  for u in units(who):
   if u.uid!=c.uid and not cards[c.card_id].title.is_empty() and cards[u.card_id].title==cards[c.card_id].title: return "同称号单位已经在场"
 return ""
func cast_cost(who: int,c: Dictionary) -> Dictionary:
 var cost=cards[c.card_id].cost.duplicate()
 if not Extra.has(cards[c.card_id],"unit_discount"): return cost
 var options=[cost]
 for i in range(units(who).size()):
  var next=[]
  for candidate in options:
   for color in candidate:
    if candidate[color]>0:
     var copy=candidate.duplicate(); copy[color]-=1
     if copy not in next: next.append(copy)
  if next.is_empty(): break
  options=next
 var best=options[0]; var score=9999999
 for candidate in options:
  var solution=payment(who,candidate)
  if solution.ways>0 and solution.score<score: best=candidate; score=solution.score
 return best
func detach(c: Dictionary):
 for p in players:
  for zone in ["deck","hand","field","palette","grave","exile"]: p[zone].erase(c)
 for entry in stack.duplicate():
  if entry.kind=="card" and entry.card.uid==c.uid: stack.erase(entry)
func move_to(c: Dictionary,zone: String,offer_return: bool=true):
 if c.is_empty(): return
 var before=c.duplicate(true)
 detach(c)
 if before.zone=="field": Extra.on_leave(self,before)
 if c.get("token",false) and before.zone=="field":
  # Tokens still die and trigger death abilities, then cease to exist.
  if zone=="grave": Extra.on_death(self,c,before)
  shift(c,"void"); return
 if c.leader and before.zone!="leader" and offer_return and zone in ["hand","deck","grave","exile","palette"]:
  c.zone="return_pending"; c.epoch+=1; c.return_destination=zone; c.return_snapshot=before; returns.append(c); return
 shift(c,zone)
 if zone!="leader": players[c.owner][zone].append(c)
 if before.zone=="field" and zone=="grave": Extra.on_death(self,c,before)
func destroy(c: Dictionary):
 if c.is_empty() or Extra.keyword(self,c,"不会被消灭"): return
 if resolving_spell: c.spell_damage=true
 move_to(c,"grave")
func can_possess(c: Dictionary) -> bool:
 return not Extra.has(cards[c.card_id],"no_possession") and c.get("poverty",0)==0
func push_extended_trigger(t: Dictionary,target: Dictionary):
 var entry=t.duplicate(true)
 entry.id=next_stack; entry.kind="ability"; entry.target=target.duplicate(true)
 stack.append(entry); next_stack+=1; passes=0; priority=1-t.owner
 if t.effect=="leader_death_damage": use_once(t.source.uid,"death_ping")
 note(t.name+" · 触发能力")
func choose_effect(target: Dictionary):
 if pending.get("kind","")!="effect_choice": return
 var t=pending.trigger
 if target.is_empty() and not t.optional: return
 if not target.is_empty() and target not in Extra.trigger_options(self,t): return
 pending={}
 if not target.is_empty(): push_extended_trigger(t,target)
 revision+=1; pump_choices()
func use_once(uid: int,key: String):
 var k=str(uid)+":"+key; turn_usage[k]=turn_usage.get(k,0)+1
func usage_count(uid: int,key: String) -> int: return turn_usage.get(str(uid)+":"+key,0)
func cannot_lose(who: int) -> bool:
 return players[who].field.any(func(c): return Extra.has(cards[c.card_id],"timed_life") and c.timer>0)
func run_delayed(at_phase: String):
 for d in delayed.duplicate():
  if d.phase!=at_phase or d.owner not in [-1,active]: continue
  delayed.erase(d)
  var c=find_card(d.ref.uid)
  if c.is_empty() or c.epoch!=d.ref.epoch or c.zone!=d.zone: continue
  Extra.event(self,c,"token_sacrifice" if d.effect=="token_sacrifice" else "delayed_return",false,d)
func add_timer(c: Dictionary,amount: int):
 c.timer+=amount
 for unit in units(0)+units(1):
  if Extra.has(cards[unit.card_id],"timer_replace") and has_leader_ability(unit): timer_changes.append({"owner":unit.owner,"ref":ref_target(c),"amount":amount})
func choose_timer(delta: int):
 if pending.get("kind","")!="timer" or delta not in [-1,0,1]: return
 var change=pending.change; var c=find_card(change.ref.uid)
 if not c.is_empty() and c.epoch==change.ref.epoch: c.timer=maxi(0,c.timer+delta)
 pending={}; revision+=1; pump_choices()
func deals_combat_damage(c: Dictionary) -> bool:
 var stage=combat.get("strike_round","normal")
 if stage=="normal": return true
 return (c.uid in combat.get("first_strikers",[])) if stage=="first" else (c.uid not in combat.get("first_strikers",[]))
func combat_exiles(c: Dictionary) -> bool:
 if Extra.has(cards[c.card_id],"combat_exile") and has_leader_ability(c): return true
 return c.card_id=="token_halfghost" and units(c.owner).any(func(u): return Extra.has(cards[u.card_id],"combat_exile") and has_leader_ability(u))
func extra_action(c: Dictionary) -> Dictionary:
 var key=Extra.activation_kind(cards[c.card_id])
 if key.is_empty(): return {}
 var labels={"grave_return":"支付红 1：移回手牌","grave_reanimate":"支付绿 1 黑 1，弃一张牌：横置移回战场","exile_grave":"横置：移除墓地中的牌","sacrifice_buff":"牺牲一个单位：+1/+1","leader_bounce":"自机能力：单位移回手牌"}
 return {"type":"extension","uid":c.uid,"label":labels[key],"key":key,"enabled":true}
func extension_activation_error(who: int,c: Dictionary) -> String:
 if winner!=-2 or phase=="mulligan" or not pending.is_empty() or priority!=who or c.owner!=who: return "当前不能发动"
 var key=Extra.activation_kind(cards[c.card_id])
 if key.is_empty(): return "没有该异能"
 var zone="grave" if key in ["grave_return","grave_reanimate"] else "field"
 if c.zone!=zone: return "区域不符"
 if key=="exile_grave" and (c.tapped or summoning_sick(c)): return "不能横置"
 if key=="leader_bounce" and (not has_leader_ability(c) or usage_count(c.uid,key)>0): return "本回合不能发动"
 if payment(who,Extra.activation_cost(key)).ways==0: return "费用不足"
 if Extra.activation_options(self,c,key).is_empty(): return "没有合法目标"
 return ""
func commit_extension(who: int,uid: int,target: Dictionary,plan: Array) -> String:
 var c=find_card(uid)
 if c.is_empty(): return "牌已离开"
 var error=extension_activation_error(who,c)
 if not error.is_empty(): return error
 var key=Extra.activation_kind(cards[c.card_id])
 if target not in Extra.activation_options(self,c,key): return "选择已失效"
 if not payment_valid(who,Extra.activation_cost(key),plan): return "支付方案已失效"
 for item in plan:
  if item.uid<0: players[who].potato=false
  else: find_card(item.uid).tapped=true
 var source=c.duplicate(true)
 if key=="exile_grave": c.tapped=true
 if key in ["grave_reanimate","sacrifice_buff"]: move_to(find_card(target.uid),"grave")
 if key=="leader_bounce": use_once(c.uid,key)
 stack.append({"id":next_stack,"kind":"ability","activation":true,"effect":key,"source":source,"owner":who,"target":target.duplicate(true),"name":cards[c.card_id].name})
 next_stack+=1; passes=0; priority=1-who; note("发动 "+cards[c.card_id].name); pump_choices()
 return ""
func debug_move(uid: int,destination: String) -> String:
 if not debug_enabled: return "调试模式未开启"
 if not pending.is_empty(): return "请先完成当前选择"
 if winner!=-2: return "对局已经结束"
 if destination not in ["deck","hand","field","palette","grave","exile","leader"]: return "该区域不能直接放入卡牌"
 var c=find_card(uid)
 if c.is_empty() or c.zone=="return_pending": return "卡牌不存在或正在移动"
 if c.zone==destination: return ""
 if c.get("token",false) and destination!="exile": return "衍生物离开战场后会消失"
 if destination=="leader" and not c.leader: return "只有本局自机可放入自机区"
 if destination=="field":
  if cards[c.card_id].kind=="符卡" and not Extra.has(cards[c.card_id],"timed_life"): return "该符卡不能留在战场"
  var error=field_error(c,c.owner)
  if not error.is_empty(): return error
  detach(c); enter_field(c,c.owner)
  if cards[c.card_id].get("time",0)>0: add_timer(c,cards[c.card_id].time)
 else: move_to(c,destination,false)
 note("调试移动："+cards[c.card_id].name+" → "+destination)
 judge(); pump_choices(); revision+=1
 return ""
'''
p.write_text(s,'utf-8')
p=p.parent/'demo_abilities.gd';s=p.read_text('utf-8');s=s.replace('for binding in card.abilities:\n  match','if engine.Extra.spell_resolve(engine,entry): return\n engine.resolving_spell=true\n for binding in card.abilities:\n  match',1).replace('engine.to_grave(entry.card)','engine.judge()\n engine.resolving_spell=false\n engine.to_grave(entry.card)',1);p.write_text(s,'utf-8')
