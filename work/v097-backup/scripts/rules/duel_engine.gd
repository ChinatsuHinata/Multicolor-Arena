extends RefCounted
const DB=preload("res://scripts/card_database.gd")
const Extra=preload("res://scripts/rules/expanded_abilities.gd")
const Effects=preload("res://scripts/rules/demo_abilities.gd")
const ColorCost=preload("res://scripts/rules/color_cost.gd")
const COLORS=["红","蓝","绿","黄","黑"]
var cards: Dictionary
var players: Array=[]
var stack: Array=[]
var triggers: Array=[]
var returns: Array=[]
var pending: Dictionary={}
var combat: Dictionary={}
var active=0
var priority=0
var phase="mulligan"
var turn=0
var first=0
var passes=0
var winner=-2
var revision=0
var log: Array=[]
var history: Array=[]
var recorded_life=[20,20]
var next_uid=1
var next_stack=1
var rng=RandomNumberGenerator.new()
var payment_memo={}
var payment_groups=[]
var next_damage_batch=1
var debug_enabled=false
var delayed=[]
var combat_queue=[]
var timer_changes=[]
var turn_usage={}
var resolving_spell=false
var cleanup_done=false
var death_observers=[]
var death_trigger_events={}
var zone_replacements=[]
func _init():
 cards=DB.load_cards()
 Extra.register_tokens(self)
func note(message: String,art: Array=[]):
 log.append(message)
 if log.size()>160: log.pop_front()
 record_history(message,art)
 revision+=1
func record_history(message: String,art: Array=[]):
 history.append({"turn":turn,"phase":phase,"text":message,"art":art.duplicate(true)})
func history_art(c: Dictionary) -> Array:
 return [{"card_id":c.card_id,"owner":c.owner,"hidden":false}] if c.has("card_id") else []
func make_card(id: String, owner: int, location: String, leader: bool=false) -> Dictionary:
 var c={"uid":next_uid,"epoch":0,"card_id":id,"owner":owner,"zone":location,"leader":leader,"tapped":false,"damage":0,"timer":0,"entered":0,"attacked":false}
 next_uid+=1
 return c
func shuffle(cards_to_shuffle: Array):
 for i in range(cards_to_shuffle.size()-1,0,-1):
  var j=rng.randi_range(0,i)
  var tmp=cards_to_shuffle[i]
  cards_to_shuffle[i]=cards_to_shuffle[j]
  cards_to_shuffle[j]=tmp
func start(a: Dictionary,b: Dictionary, first_player: int, seed_value: int=0):
 delayed.clear(); combat_queue.clear(); timer_changes.clear(); turn_usage.clear(); death_trigger_events.clear(); cleanup_done=false
 zone_replacements.clear()
 recorded_life=[20,20]
 next_damage_batch=1
 players.clear(); stack.clear(); triggers.clear(); returns.clear(); pending.clear(); combat.clear(); log.clear(); history.clear()
 next_uid=1; next_stack=1; winner=-2; turn=0; revision=0; phase="mulligan"; first=first_player; active=first; priority=first; passes=0
 if seed_value==0: rng.randomize()
 else: rng.seed=seed_value
 for i in range(2):
  var deck=a if i==0 else b
  var p={"life":20,"deck":[],"hand":[],"field":[],"palette":[],"grave":[],"exile":[],"leader":make_card(deck.leader,i,"leader",true),"potato":i!=first,"mulligan_done":false,"turns":0}
  for id in deck.main: p.deck.append(make_card(id,i,"deck"))
  shuffle(p.deck)
  players.append(p)
 for i in range(2): draw(i,4)
 note("对局开始，双方起手 4 张")
func shift(c: Dictionary, location: String):
 var old=c.get("zone","")
 if old!=location and old not in ["token","void",""]:
  var names={"hand":"手牌","deck":"牌库","field":"战场","palette":"颜色盘","grave":"墓地","exile":"除外","leader":"自机区","stack":"堆叠","return_pending":"自机返回","void":"消失"}
  var hidden=old in ["hand","deck"] and location in ["hand","deck"]
  var caption=("你" if c.owner==0 else "人机")+" · "+names.get(old,old)+" → "+names.get(location,location)
  if not hidden: caption+="\n"+cards[c.card_id].name
  record_history(caption,[{"card_id":c.card_id,"owner":c.owner,"hidden":hidden}])
 c.zone=location; c.epoch+=1; c.tapped=false; c.damage=0; c.timer=0; c.attacked=false; c.modifiers=[]; c.plus_counters=0; c.poverty=0; c.spell_damage=false
 c.leader_counters=0
func draw(who: int,count: int=1):
 for i in range(count):
  if players[who].deck.is_empty(): lose(who,"牌库不足，无法抓牌"); return
  var c=players[who].deck.pop_front()
  shift(c,"hand"); players[who].hand.append(c)
func mulligan(who: int,uids: Array):
 if phase!="mulligan" or players[who].mulligan_done or winner!=-2: return
 var chosen=[]
 for c in players[who].hand:
  if c.uid in uids: chosen.append(c)
 for c in chosen: players[who].hand.erase(c); shift(c,"deck")
 shuffle(chosen)
 players[who].deck.append_array(chosen)
 draw(who,chosen.size())
 players[who].mulligan_done=true
 note(("你" if who==0 else "人机")+"完成调度")
 if players[0].mulligan_done and players[1].mulligan_done: start_turn(first)
func start_turn(who: int):
 if winner!=-2: return
 active=who; priority=who; passes=0; turn+=1; players[who].turns+=1
 phase="reset"; turn_usage.clear(); death_trigger_events.clear(); cleanup_done=false
 for c in players[who].field+players[who].palette: c.tapped=false; c.attacked=false
 if players[who].palette.size()<8 and not players[who].deck.is_empty():
  var c=players[who].deck.pop_front(); shift(c,"palette"); players[who].palette.append(c)
 phase="prepare"
 run_delayed("prepare")
 pump_choices()
 note("第 %d 回合 · %s" % [turn,"你" if who==0 else "人机"])
func find_card(uid: int) -> Dictionary:
 for p in players:
  if p.leader.uid==uid: return p.leader
  for z in ["deck","hand","field","palette","grave","exile"]:
   for c in p[z]:
    if c.uid==uid: return c
 for e in stack:
  if e.has("card") and e.card.uid==uid: return e.card
 return {}
func has_leader_ability(c: Dictionary) -> bool:
 if c.is_empty(): return false
 if c.get("leader",false) or c.get("leader_counters",0)>0: return true
 if c.get("zone","")!="field" or cards[c.card_id].kind!="自机": return false
 for permanent in players[c.owner].field:
  if DB.has_ability(cards[permanent.card_id],"grant_leader_abilities"): return true
 return false
func is_unit(c: Dictionary) -> bool: return cards[c.card_id].kind in ["自机","单位"]
func units(who: int) -> Array:
 return players[who].field.filter(func(c): return is_unit(c))
func source_resources(who: int) -> Array:
 var sources=[]
 for c in players[who].palette:
  if not c.tapped: sources.append({"uid":c.uid,"colors":cards[c.card_id].colors,"weight":cards[c.card_id].colors.size()*10,"kind":"palette"})
 for c in players[who].field:
  if not c.tapped and DB.has_ability(cards[c.card_id],"mana"):
   sources.append({"uid":c.uid,"colors":[DB.ability(cards[c.card_id],"mana")["颜色"]],"weight":8,"kind":"item"})
 if players[who].potato: sources.append({"uid":-100-who,"colors":COLORS,"weight":1000,"kind":"potato"})
 return sources
func payment_search(sources: Array,index: int,needs: Array) -> Dictionary:
 var key=str(index)+":"+str(needs)
 if payment_memo.has(key): return payment_memo[key]
 if needs.all(func(n): return n==0): return {"ways":1,"score":0,"plan":[]}
 if index>=sources.size(): return {"ways":0,"score":999999,"plan":[]}
 var best=payment_search(sources,index+1,needs).duplicate(true)
 for color in sources[index].colors:
  for ci in range(needs.size()):
   if needs[ci]<=0 or color not in payment_groups[ci]: continue
   var remaining=needs.duplicate(); remaining[ci]-=1
   var tail=payment_search(sources,index+1,remaining)
   if tail.ways==0: continue
   var ways=mini(2,best.ways+tail.ways)
   var score=tail.score+sources[index].weight
   if score<best.score:
    best={"ways":ways,"score":score,"plan":[{"uid":sources[index].uid,"color":color}]+tail.plan}
   else: best.ways=ways
 payment_memo[key]=best
 return best
func payment(who: int, cost: Dictionary, excluded: Array=[]) -> Dictionary:
 payment_memo.clear()
 var needs=[]; payment_groups=[]
 for color in cost:
  needs.append(int(cost[color])); payment_groups.append(color.split("/"))
 return payment_search(source_resources(who).filter(func(r): return r.uid not in excluded),0,needs)
func payment_valid(who: int,cost: Dictionary,plan: Array) -> bool:
 var used=[]; var resources=source_resources(who)
 for reservation in plan:
  if reservation.uid in used: return false
  var matched=false
  for source in resources:
   if source.uid==reservation.uid and reservation.color in source.colors: matched=true; break
  if not matched: return false
  used.append(reservation.uid)
 var result=ColorCost.remaining(cost,plan)
 return result.ok and result.remaining.values().all(func(n): return n==0)
func cast_error(who: int,uid: int) -> String:
 if winner!=-2: return "对局已结束"
 if not pending.is_empty() or phase=="mulligan": return "请先完成当前选择"
 if priority!=who: return "等待执行权"
 var c=find_card(uid)
 if c.is_empty() or c.owner!=who or c.zone not in ["hand","leader"] and not (c.zone=="deck" and Extra.has(cards[c.card_id],"deck_damage")): return "无法从该区域使用"
 var info=cards[c.card_id]
 if not info.fast and (phase!="main" or not stack.is_empty() or not combat.is_empty() or active!=who): return "只能在自己主要阶段的空对抗时使用"
 if c.zone=="leader" and c.timer>0: return "自机仍在计时"
 if is_unit(c):
  if field_slots(who)>=6 and not Extra.keyword(self,c,"不占战场格"): return "单位战场格已满"
  for u in units(who):
   if cards[u.card_id].title==info.title and not info.title.is_empty(): return "同称号单位已经在场"
  if info.kind=="自机":
   var provided=[]
   for permanent in players[who].field:
    for color in cards[permanent.card_id].colors:
     if color not in provided: provided.append(color)
   for color in info.colors:
    if color not in provided: return "战场永久物尚未满足自机颜色约束"
 if not info.requires_character.is_empty():
  var present=false
  for u in units(who):
   if cards[u.card_id].character==info.requires_character: present=true
  if not present: return "需要操控"+info.requires_character
 if payment(who,cast_cost(who,c)).ways==0: return "可用颜色费用不足"
 if info.kind=="符卡" and targets_for(c.card_id,who).is_empty(): return "没有合法目标"
 return ""
func targets_for(id: String,acting: int=-1) -> Array:
 if acting<0: acting=priority
 var extended=Extra.spell_options(self,id,acting)
 if extended!=null: return extended
 var targets=[]
 if DB.has_ability(cards[id],"counter_card"):
  for e in stack:
   if e.kind=="card": targets.append({"stack_id":e.id})
 elif DB.has_ability(cards[id],"turn_buff"):
  for who in range(2):
   for c in units(who): targets.append(ref_target(c))
 elif DB.has_ability(cards[id],"damage"):
  for who in range(2):
   targets.append({"player":who})
   for c in units(who): targets.append(ref_target(c))
 return targets
func ref_target(c: Dictionary) -> Dictionary: return {"uid":c.uid,"epoch":c.epoch}
func target_valid(target: Dictionary,unit_only: bool=false) -> bool:
 if target.has("player"): return not unit_only and int(target.player) in [0,1]
 if target.has("stack_id"):
  for e in stack:
   if e.id==target.stack_id and e.kind=="card": return true
  return false
 var c=find_card(int(target.get("uid",-1)))
 return not c.is_empty() and c.zone=="field" and is_unit(c) and c.epoch==target.get("epoch",-1)
func commit_cast(who: int,uid: int,target: Dictionary,plan: Array) -> String:
 var error=cast_error(who,uid)
 if not error.is_empty(): return error
 var c=find_card(uid); var info=cards[c.card_id]
 if info.kind=="符卡":
  if target not in targets_for(c.card_id,who): return "目标已失效"
 if not payment_valid(who,cast_cost(who,c),plan): return "支付方案已失效"
 # All validation completes before any public mutation.
 for reservation in plan:
  if reservation.uid<0: players[who].potato=false
  else: find_card(reservation.uid).tapped=true
 if target.has("sacrifice"):
  move_to(find_card(target.sacrifice.uid),"grave")
 detach(c)
 shift(c,"stack")
 stack.append({"id":next_stack,"kind":"card","card":c,"owner":who,"target":target.duplicate(),"name":info.name})
 next_stack+=1; passes=0; priority=1-who
 note(("你" if who==0 else "人机")+"使用 "+info.name,history_art(c))
 if info.kind=="符卡": Effects.spell_used(self,who)
 pump_choices()
 return ""
func queue_trigger(who: int,source: Dictionary,amount: int,title: String):
 triggers.append({"owner":who,"source":source.duplicate(true),"amount":amount,"optional":true,"name":cards[source.card_id].name+" · "+title})
func trigger_options(t: Dictionary) -> Array:
 if t.get("extended",false): return Extra.trigger_options(self,t)
 if t.get("effect","")=="untap": return [{"none":true}]
 return (units(0)+units(1)).map(func(c): return ref_target(c))
func begin_trigger(t: Dictionary):
 var options=trigger_options(t)
 if options.is_empty(): return
 if t.get("effect","")=="untap":
  push_trigger(t,ref_target(t.source)); return
 var kind="effect_choice" if t.get("extended",false) else "trigger"
 if t.get("optional",true):
  pending={"kind":kind,"owner":t.owner,"trigger":t,"options":options}; return
 # Publish the mandatory ability before target selection. Pending prevents
 # priority passing, responses and resolution until its target is committed.
 var id=push_trigger(t,options[0] if options==[{"none":true}] else {})
 if options!=[{"none":true}]:
  stack.back().awaiting_target=true
  pending={"kind":kind,"owner":t.owner,"trigger":t,"options":options,"stack_id":id}
func choose_trigger_order(index: int):
 if pending.get("kind","")!="trigger_order" or index<0 or index>=pending.options.size(): return
 var t=pending.options[index]
 triggers.erase(t); pending={}
 begin_trigger(t); revision+=1; pump_choices()
func pump_choices():
 if not pending.is_empty() or winner!=-2: return
 if not timer_changes.is_empty():
  var change=timer_changes.pop_front()
  pending={"kind":"timer","owner":change.owner,"change":change}; return
 if not returns.is_empty(): pending={"kind":"leader_return","owner":returns[0].owner,"card":returns.pop_front()}; return
 while not zone_replacements.is_empty():
  var request=zone_replacements.pop_front()
  var c=find_card(request.target.uid)
  if c.is_empty() or c.zone!="grave" or c.epoch!=request.target.epoch: continue
  if grave_replacement_sources(c).is_empty(): move_to(c,"hand",true,false); continue
  pending={"kind":"grave_replacement","owner":c.owner,"target":request.target}; return
 while not triggers.is_empty():
  triggers=triggers.filter(func(t): return not trigger_options(t).is_empty())
  if triggers.is_empty(): break
  # 1.12 / 1.142a: active player chooses first; each controller orders
  # their simultaneous triggers before either player receives priority.
  var who=active if triggers.any(func(t): return t.owner==active) else 1-active
  var options=triggers.filter(func(t): return t.owner==who)
  if options.size()>1:
   pending={"kind":"trigger_order","owner":who,"options":options}; return
  var t=options[0]; triggers.erase(t); begin_trigger(t)
  if not pending.is_empty(): return
 if combat.is_empty() and not combat_queue.is_empty(): combat=combat_queue.pop_front(); priority=active; passes=0
func choose_trigger(target: Dictionary):
 if pending.get("kind","")!="trigger": return
 var t=pending.trigger
 if target.is_empty() and (not t.get("optional",true) or pending.has("stack_id")): return
 if not target.is_empty() and target not in trigger_options(t): return
 if not target.is_empty(): complete_trigger_target(t,target)
 pending={}; revision+=1; pump_choices()
func choose_return(yes: bool):
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
func counter_entry(id: int):
 for e in stack:
  if e.id==id:
   stack.erase(e)
   if e.kind=="card": to_grave(e.card)
   note(e.name+"被反制"); return
func damage_target(target: Dictionary,amount: int):
 if amount<=0 or not target_valid(target): return
 if target.has("player"): players[int(target.player)].life-=amount
 else:
  var c=find_card(target.uid)
  if Extra.keyword(self,c,"防止伤害"): return
  c.damage+=amount
  record_history(cards[c.card_id].name+"受到%d点伤害" % amount,history_art(c))
  if amount>0: c.spell_damage=resolving_spell
func stat(c: Dictionary,key: String) -> int:
 var value=int(cards[c.card_id][key])+int(c.get("plus_counters",0))
 if key=="spirit" and c.zone=="field":
  for permanent in players[c.owner].field:
   if Extra.has(cards[permanent.card_id],"spirit_aura"): value+=1
 var fields={"power":"攻击力","health":"血量","spirit":"灵力"}
 for modifier in c.get("modifiers",[]): value+=int(modifier.get(fields[key],0))
 return maxi(0,value)
func has_haste(c: Dictionary) -> bool:
 return Extra.keyword(self,c,"疾行")
func apply_turn_buff(target: Dictionary,params: Dictionary):
 if not target_valid(target,true): return
 var c=find_card(target.uid)
 if not c.has("modifiers"): c.modifiers=[]
 c.modifiers.append(params.duplicate(true))
func judge():
 for who in range(2):
  var life=players[who].life
  if life!=recorded_life[who]:
   record_history(("你" if who==0 else "人机")+" · 生命 %d → %d" % [recorded_life[who],life])
   recorded_life[who]=life
 death_observers=(units(0)+units(1)).duplicate(true)
 for who in range(2):
  for c in players[who].field.duplicate():
   if is_unit(c) and (stat(c,"health")==0 or c.damage>=stat(c,"health") and not Extra.keyword(self,c,"不会被消灭")):
    if resolving_spell: c.spell_damage=true
    to_grave(c); note(cards[c.card_id].name+"离开战场")
 death_observers=[]
 var dead=[]
 for who in range(2):
  if players[who].life<=0 and not cannot_lose(who): dead.append(who)
 if dead.size()==2: winner=-1; phase="over"; pending={}; note("平局")
 elif dead.size()==1: lose(dead[0],"生命归零")
func lose(who: int,reason: String,forced: bool=false):
 if winner!=-2: return
 if not forced and reason!="投降" and cannot_lose(who): return
 winner=1-who; phase="over"; pending={}; note(("你" if who==0 else "人机")+reason)
func surrender(who: int): lose(who,"投降")
func pass_priority(who: int):
 if winner!=-2 or not pending.is_empty() or phase=="mulligan" or priority!=who: return
 passes+=1
 if passes<2: priority=1-who; revision+=1; return
 passes=0
 if not stack.is_empty():
  var e=stack.pop_back()
  if e.kind=="ability":
   if e.get("extended",false): Extra.resolve_trigger(self,e)
   elif e.get("activation",false): Extra.resolve_activation(self,e)
   elif e.get("effect","")=="untap":
    if target_valid(e.target,true): find_card(e.target.uid).tapped=false
   else: damage_target(e.target,e.amount)
   note(e.name+"结算",history_art(e.get("source",{})))
  elif cards[e.card.card_id].kind=="符卡" and not spell_target_valid(e.card.card_id,e.target):
   to_grave(e.card); note("目标失效，"+e.name+"不结算")
  else: Effects.resolved(self,e); note(e.name+"结算",history_art(e.card))
  judge(); priority=active; pump_choices()
 elif not combat.is_empty(): advance_combat()
 else: advance_phase()
 revision+=1
func advance_phase():
 if winner!=-2: return
 var old_phase=phase
 priority=active; passes=0
 match phase:
  "prepare":
   if turn==1: phase="possession"
   else:
    phase="draw"; draw(active)
    if not players[active].hand.is_empty():
     var drawn=players[active].hand.back()
     if Extra.keyword(self,drawn,"奇迹"): Extra.event(self,drawn,"miracle",true)
    pump_choices()
   if phase=="possession": offer_possession()
  "draw": phase="possession"; offer_possession()
  "possession": phase="main"
  "main":
   phase="end"
   run_delayed("end")
   for c in units(active):
    if Extra.has(cards[c.card_id],"end_grave_return"): Extra.event(self,c,"end_grave_return",true)
    if c.attacked and DB.has_ability(cards[c.card_id],"brave"):
     triggers.append({"source":c.duplicate(true),"owner":active,"effect":"untap","optional":false,"name":cards[c.card_id].name+" · 英勇"})
   pump_choices()
  "end": cleanup_end()
 if phase!=old_phase:
  var names={"prepare":"准备阶段","draw":"抓牌阶段","possession":"凭依阶段","main":"主要阶段","end":"结束阶段","over":"对局结束"}
  record_history(names.get(phase,phase))
func offer_possession():
 if not players[active].hand.is_empty() and players[active].palette.any(func(c): return not c.tapped and can_possess(c)): pending={"kind":"possession","owner":active}
func possession(palette_uid: int=-1,hand_uid: int=-1):
 if pending.get("kind","")!="possession": return
 var who=pending.owner
 if palette_uid>=0 and hand_uid>=0:
  var p=find_card(palette_uid); var h=find_card(hand_uid)
  if p.is_empty() or h.is_empty() or p.zone!="palette" or h.zone!="hand" or p.owner!=who or h.owner!=who or p.tapped or not can_possess(p) or not can_possess(h): return
  players[who].palette.erase(p); players[who].hand.erase(h)
  shift(p,"hand"); shift(h,"palette")
  players[who].hand.append(p); players[who].palette.append(h)
  note("凭依完成")
 pending={}; priority=active; passes=0; revision+=1
func cleanup_end():
 if not cleanup_done:
  cleanup_done=true
  for c in players[active].field+[players[active].leader]:
   if c.zone not in ["field","leader"] or c.timer<=0: continue
   c.timer=maxi(0,c.timer-1)
   if c.zone=="field" and Extra.has(cards[c.card_id],"timed_life") and c.timer==0: move_to(c,"grave"); lose(active,"反魂蝶计时归零",true)
  pump_choices()
  if not pending.is_empty() or not stack.is_empty() or winner!=-2: return
 if players[active].hand.size()>7: pending={"kind":"discard","owner":active,"count":players[active].hand.size()-7}; return
 finish_turn()
func discard(uids: Array):
 if pending.get("kind","")!="discard" or uids.size()!=pending.count: return
 var who=pending.owner; var picked=[]
 for uid in uids:
  var c=find_card(uid)
  if c.is_empty() or c.zone!="hand" or c.owner!=who or c in picked: return
  picked.append(c)
 pending={}
 for c in picked: players[who].hand.erase(c); to_grave(c)
 finish_turn()
func finish_turn():
 for p in players:
  for c in p.field: c.damage=0; c.modifiers=[]; c.spell_damage=false
 start_turn(1-active)
func can_attack(who: int,uid: int) -> bool:
 var c=find_card(uid)
 return winner==-2 and pending.is_empty() and priority==who and active==who and phase=="main" and stack.is_empty() and combat.is_empty() and not c.is_empty() and c.owner==who and c.zone=="field" and is_unit(c) and not c.tapped and (not summoning_sick(c) or has_haste(c))
func attack(who: int,uid: int):
 if not can_attack(who,uid): return
 var c=find_card(uid); c.tapped=true; c.attacked=true
 combat={"attacker":ref_target(c),"owner":who,"blockers":[],"blocked":false,"step":"attack_window"}
 priority=1-who; passes=0; note("宣言攻击："+cards[c.card_id].name,history_art(c))
func legal_blockers() -> Array:
 if combat.is_empty(): return []
 var attacker=find_card(combat.attacker.uid)
 if attacker.is_empty(): return []
 var result=[]
 for c in units(1-combat.owner):
  if c.tapped: continue
  if Extra.keyword(self,attacker,"不能被阻挡"): continue
  if attacker.get("modifiers",[]).any(func(m): return m.get("不可阻挡颜色","") in cards[c.card_id].colors): continue
  if DB.has_ability(cards[attacker.card_id],"exterminate") and has_leader_ability(attacker) and "人类" not in cards[c.card_id].race: continue
  result.append(c)
 if Extra.keyword(self,attacker,"威吓") and result.size()<2: return []
 return result
func block(uids: Array):
 if pending.get("kind","")!="block": return
 var valid=legal_blockers(); var chosen=[]
 for uid in uids:
  var c=find_card(uid)
  if c not in valid or c in chosen: return
  chosen.append(c)
 if chosen.size()==1 and Extra.keyword(self,find_card(combat.attacker.uid),"威吓"): return
 for c in chosen: c.tapped=true; combat.blockers.append(ref_target(c))
 combat.blocked=not chosen.is_empty(); combat.step="block_window"
 pending={}; priority=active; passes=0
 note("不阻挡" if chosen.is_empty() else "宣言阻挡 · %d 个单位" % chosen.size())
func advance_combat():
 if not target_valid(combat.attacker,true): end_combat(); return
 var surviving=combat.blockers.filter(func(t): return target_valid(t,true))
 if combat.blocked and surviving.is_empty(): end_combat(); return
 combat.blockers=surviving
 match combat.step:
  "attack_window":
   pending={"kind":"block","owner":1-combat.owner}
   # Check after attack responses resolve: only offer a choice if a legal blocker exists.
   if legal_blockers().is_empty(): block([])
  "block_window":
   if not combat.has("strike_round"):
    var fighters=[find_card(combat.attacker.uid)]+surviving.map(func(t): return find_card(t.uid))
    combat.first_strikers=fighters.filter(func(c): return Extra.keyword(self,c,"先制")).map(func(c): return c.uid)
    combat.strike_round="first" if not combat.first_strikers.is_empty() else "normal"
   if surviving.size()>1 and deals_combat_damage(find_card(combat.attacker.uid)):
    pending={"kind":"damage_assignment","owner":combat.owner,"total":stat(find_card(combat.attacker.uid),"power")}
   else: combat_damage({})
  "first_damage_window":
   combat.step="block_window"; combat.strike_round="second"
   var fighters=[find_card(combat.attacker.uid)]+surviving.map(func(t): return find_card(t.uid))
   if not fighters.any(func(c): return deals_combat_damage(c)): end_combat(); return
   advance_combat()
  "damage_window": end_combat()
func combat_damage(allocation: Dictionary):
 if combat.is_empty() or combat.get("step","")!="block_window": return
 var attacker=find_card(combat.attacker.uid)
 if not target_valid(combat.attacker,true): end_combat(); return
 var power=stat(attacker,"power") if deals_combat_damage(attacker) else 0
 if combat.blockers.size()>1 and power>0:
  var total=0
  for t in combat.blockers:
   var amount=int(allocation.get(str(t.uid),0))
   if amount<0: return
   total+=amount
  if total!=power: return
 pending={}
 if not combat.blocked:
  if deals_combat_damage(attacker): players[1-combat.owner].life-=stat(attacker,"spirit")
 else:
  var retaliation=0
  for t in combat.blockers:
   var blocker=find_card(t.uid)
   var amount=power if combat.blockers.size()==1 else int(allocation.get(str(t.uid),0)) if power>0 else 0
   damage_target(t,amount)
   if deals_combat_damage(blocker): retaliation+=stat(blocker,"power")
   if amount>0 and not Extra.keyword(self,blocker,"防止伤害") and combat_exiles(attacker):
    Extra.event(self,attacker,"combat_exile_target",false,{"ref":t})
   if deals_combat_damage(blocker) and stat(blocker,"power")>0 and not Extra.keyword(self,attacker,"防止伤害") and combat_exiles(blocker):
    Extra.event(self,blocker,"combat_exile_target",false,{"ref":combat.attacker})
  damage_target(combat.attacker,retaliation)
  if active==combat.owner and phase=="main" and (DB.has_ability(cards[attacker.card_id],"annihilate") or Extra.keyword(self,attacker,"歼灭")):
   if combat.blockers.any(func(t): return find_card(t.uid).damage>=stat(find_card(t.uid),"health") and not Extra.keyword(self,find_card(t.uid),"不会被消灭")):
    players[1-combat.owner].life-=stat(attacker,"spirit")
    note("歼灭造成 %d 点战斗伤害" % stat(attacker,"spirit"))
 # Capture every participant after simultaneous damage and before zone changes.
 # Presentation uses this snapshot to show negative health during its one-second hold.
 combat.damage_snapshot={}
 for c in units(0)+units(1):
  var snapshot=c.duplicate(true)
  snapshot.display_stats={"power":stat(c,"power"),"health":stat(c,"health")-c.damage,"spirit":stat(c,"spirit")}
  combat.damage_snapshot[c.uid]=snapshot
 combat.damage_batch=next_damage_batch; next_damage_batch+=1
 combat.step="first_damage_window" if combat.get("strike_round","")=="first" else "damage_window"; priority=active; passes=0
 note("战斗伤害结算"); judge(); pump_choices()
func end_combat():
 combat={}; priority=active; passes=0; revision+=1
func legal_casts(who: int,fast_only: bool=false) -> Array:
 var result=[]
 var options=players[who].hand.duplicate()
 options.append_array(players[who].deck.filter(func(c): return Extra.has(cards[c.card_id],"deck_damage")))
 if players[who].leader.zone=="leader": options.append(players[who].leader)
 for c in options:
  if fast_only and not cards[c.card_id].fast: continue
  if cast_error(who,c.uid).is_empty(): result.append(c)
 return result
func ai_step(who: int=1):
 var opponent=1-who
 if winner!=-2: return
 if phase=="mulligan": mulligan(who,[]); return
 if not pending.is_empty():
  if pending.owner!=who: return
  match pending.kind:
   "trigger_order": choose_trigger_order(0)
   "grave_replacement": choose_grave_replacement(true)
   "effect_choice": choose_effect(pending.options[0])
   "timer": choose_timer(0)
   "possession": ai_possession(who)
   "leader_return": choose_return(true)
   "discard": discard(players[who].hand.slice(0,pending.count).map(func(c): return c.uid))
   "trigger":
    var target={}
    var enemies=units(opponent)
    if not enemies.is_empty(): target=ref_target(enemies[0])
    choose_trigger(target)
   "block":
    var available=legal_blockers(); var chosen=[]
    if not available.is_empty():
     chosen=[available[0].uid]
     if Extra.keyword(self,find_card(combat.attacker.uid),"威吓") and available.size()>1: chosen.append(available[1].uid)
    block(chosen)
   "damage_assignment":
    var allocation={}; var left=pending.total
    for t in combat.blockers:
     var c=find_card(t.uid); var amount=mini(left,stat(c,"health")-c.damage)
     allocation[str(t.uid)]=amount; left-=amount
    if left>0: allocation[str(combat.blockers[0].uid)]+=left
    combat_damage(allocation)
  return
 if priority!=who: return
 var choices=legal_casts(who)
 # Respond to opposing cards when possible; never spend a counter on our own card.
 if not stack.is_empty():
  for c in choices:
   if DB.has_ability(cards[c.card_id],"counter_card") and stack.back().owner==opponent and stack.back().kind=="card":
    commit_cast(who,c.uid,{"stack_id":stack.back().id},payment(who,cast_cost(who,c)).plan); return
  if ai_fast_action(who,choices): return
  pass_priority(who); return
 if active==who and phase=="main" and combat.is_empty():
  # Build colored permanents first, then units and damage spells.
  choices.sort_custom(func(a,b): return ai_card_score(a)>ai_card_score(b))
  for c in choices:
   if DB.has_ability(cards[c.card_id],"counter_card"): continue
   var target=ai_spell_target(who,c)
   if cards[c.card_id].kind=="符卡" and target.is_empty(): continue
   if commit_cast(who,c.uid,target,payment(who,cast_cost(who,c)).plan).is_empty(): return
  for c in units(who):
   if can_attack(who,c.uid): attack(who,c.uid); return
 if ai_fast_action(who,choices): return
 pass_priority(who)
func ai_spell_target(who: int,c: Dictionary) -> Dictionary:
 var expanded=Extra.spell_options(self,c.card_id,who)
 if expanded!=null: return ai_expanded_target(who,c,expanded)
 var info=cards[c.card_id]
 if DB.has_ability(info,"damage"):
  var amount=int(DB.ability(info,"damage")["数值"])
  if c.card_id=="99":
   return ref_target(units(1-who)[0]) if players[1-who].life>5 and not units(1-who).is_empty() else {"player":1-who}
  if players[1-who].life<=amount: return {"player":1-who}
  var enemies=units(1-who)
  for enemy in enemies:
   if stat(enemy,"health")-enemy.damage<=amount: return ref_target(enemy)
  if not enemies.is_empty(): return ref_target(enemies[0])
  return {"player":1-who}
 if DB.has_ability(info,"turn_buff"):
  for unit in units(who):
   if not combat.is_empty() and (combat.attacker.uid==unit.uid or combat.blockers.any(func(t): return t.uid==unit.uid)): return ref_target(unit)
  for unit in units(who):
   if not unit.tapped: return ref_target(unit)
 return {}
func ai_fast_action(who: int,choices: Array) -> bool:
 for c in choices:
  var info=cards[c.card_id]
  if not info.fast: continue
  var target={}
  var expanded=Extra.spell_options(self,c.card_id,who)
  if expanded!=null:
   if c.card_id in ["110","147","177"] and combat.is_empty(): continue
   if c.card_id=="120" and players[who].life>7: continue
   target=ai_expanded_target(who,c,expanded)
   if target.is_empty(): continue
  elif DB.has_ability(info,"damage"):
   var amount=int(DB.ability(info,"damage")["数值"])
   if players[1-who].life<=amount: target={"player":1-who}
   else:
    for enemy in units(1-who):
     if stat(enemy,"health")-enemy.damage<=amount: target=ref_target(enemy); break
   if target.is_empty(): continue
  elif DB.has_ability(info,"turn_buff"):
   if combat.is_empty(): continue
   target=ai_spell_target(who,c)
   if target.is_empty(): continue
  elif is_unit(c):
   if combat.is_empty() or combat.owner==who or combat.step!="attack_window": continue
  else: continue
  if commit_cast(who,c.uid,target,payment(who,cast_cost(who,c)).plan).is_empty(): return true
 return ai_extended_ability(who)
func ai_card_score(c: Dictionary) -> int:
 var info=cards[c.card_id]
 if is_unit(c): return 100
 if info.kind=="道具": return 70
 if info.kind=="结界": return 50
 return 30
func ai_position_score(who: int) -> int:
 # Evaluate only our own hand, available resources and public permanents.
 var score=0
 var colors=[]
 for permanent in players[who].field:
  for color in cards[permanent.card_id].colors:
   if color not in colors: colors.append(color)
 for color in ["红","蓝","黄"]:
  if payment(who,{color:1}).ways>0: score+=10
  if payment(who,{color:2}).ways>0: score+=12
 var options=players[who].hand.duplicate()
 if players[who].leader.zone=="leader" and players[who].leader.timer==0: options.append(players[who].leader)
 var evaluated=[]
 for c in options:
  if c.card_id in evaluated: continue
  evaluated.append(c.card_id)
  var info=cards[c.card_id]
  if is_unit(c):
   if not info.title.is_empty() and units(who).any(func(u): return cards[u.card_id].title==info.title): continue
   if info.kind=="自机" and info.colors.any(func(color): return color not in colors): continue
  if not info.requires_character.is_empty() and not units(who).any(func(u): return cards[u.card_id].character==info.requires_character): continue
  if payment(who,info.cost).ways==0: continue
  var value=ai_card_score(c)
  if info.kind=="道具" and players[who].field.any(func(u): return u.card_id==c.card_id): value=15
  score+=value
 return score
func ai_possession(who: int=1):
 # Compare legal one-card exchanges without emitting an action or revealing opposing hidden cards.
 var hand=players[who].hand
 var palette=players[who].palette
 var best=ai_position_score(who)
 var best_palette=-1
 var best_hand=-1
 for pi in range(palette.size()):
  if palette[pi].tapped or not can_possess(palette[pi]): continue
  for hi in range(hand.size()):
   if not can_possess(hand[hi]): continue
   var trial_hand=hand.duplicate()
   var trial_palette=palette.duplicate()
   trial_hand[hi]=palette[pi]
   trial_palette[pi]=hand[hi]
   players[who].hand=trial_hand
   players[who].palette=trial_palette
   var score=ai_position_score(who)
   if score>best:
    best=score; best_palette=palette[pi].uid; best_hand=hand[hi].uid
 players[who].hand=hand
 players[who].palette=palette
 possession(best_palette,best_hand)

func summoning_sick(c: Dictionary) -> bool:
 if c.is_empty() or c.zone!="field" or not is_unit(c): return false
 if c.has("entered_turns"): return c.entered_turns>=players[c.owner].turns
 return c.entered>=turn

func ability_parameters(uid: int,index: int) -> Dictionary:
 var c=find_card(uid)
 if c.is_empty(): return {}
 var bindings=cards[c.card_id].abilities
 if index<0 or index>=bindings.size(): return {}
 return bindings[index].get("参数",{})

func activation_error(who: int,uid: int,index: int) -> String:
 if winner!=-2 or phase=="mulligan" or not pending.is_empty(): return "当前不能发动"
 if priority!=who: return "等待执行权"
 var c=find_card(uid)
 if c.is_empty() or c.owner!=who or c.zone!="field": return "需要操控该永久物"
 var bindings=cards[c.card_id].abilities
 if index<0 or index>=bindings.size() or bindings[index].get("实现")!="activated_damage": return "不是可启动的异能"
 var params=ability_parameters(uid,index)
 if params.get("横置",false):
  if c.tapped: return "已经横置"
  if summoning_sick(c): return "召唤失调"
 var excluded=[uid] if params.get("横置",false) else []
 if payment(who,params.get("费用",{}),excluded).ways==0: return "可用颜色费用不足"
 return ""

func available_actions(who: int,uid: int,include_disabled: bool=false) -> Array:
 var result=[]
 var c=find_card(uid)
 if c.is_empty() or c.owner!=who: return result
 var extra=extra_action(c)
 if not extra.is_empty():
  extra.enabled=extension_activation_error(who,c).is_empty()
  if extra.enabled or include_disabled: result.append(extra)
 if c.zone!="field": return result
 if is_unit(c):
  var enabled=can_attack(who,uid)
  if enabled or include_disabled:
   result.append({"type":"attack","uid":uid,"label":"攻击","enabled":enabled,"reason":"召唤失调" if summoning_sick(c) else "当前不能攻击" if not enabled else ""})
 var bindings=cards[c.card_id].abilities
 for index in range(bindings.size()):
  if bindings[index].get("实现")!="activated_damage": continue
  var error=activation_error(who,uid,index)
  if error.is_empty() or include_disabled:
   result.append({"type":"ability","uid":uid,"index":index,"label":bindings[index].get("名称","对目标造成 %d 点伤害" % bindings[index]["参数"]["数值"]),"enabled":error.is_empty(),"reason":error})
 return result

func has_response(who: int) -> bool:
 if not legal_casts(who,true).is_empty(): return true
 for c in players[who].field+players[who].grave:
  if available_actions(who,c.uid).any(func(a): return a.type in ["ability","extension"]): return true
 return false

func ability_targets() -> Array:
 var result=[{"player":0},{"player":1}]
 for who in range(2):
  for c in units(who): result.append(ref_target(c))
 return result

func commit_ability(who: int,uid: int,index: int,target: Dictionary,plan: Array) -> String:
 var error=activation_error(who,uid,index)
 if not error.is_empty(): return error
 if target not in ability_targets(): return "目标已失效"
 var params=ability_parameters(uid,index)
 if not payment_valid(who,params.get("费用",{}),plan): return "支付方案已失效"
 if params.get("横置",false) and plan.any(func(r): return r.uid==uid): return "不能重复横置同一来源"
 var c=find_card(uid)
 for reservation in plan:
  if reservation.uid<0: players[who].potato=false
  else: find_card(reservation.uid).tapped=true
 if params.get("横置",false): c.tapped=true
 stack.append({"id":next_stack,"kind":"ability","source":c.duplicate(true),"owner":who,"amount":int(params["数值"]),"target":target.duplicate(),"name":cards[c.card_id].name+" · 启动异能"})
 stack.back().ability_text=cards[c.card_id].abilities[index].get("名称","对目标造成%d点伤害。" % int(params["数值"]))
 next_stack+=1; passes=0; priority=1-who
 note("发动 "+cards[c.card_id].name+"的异能")
 return ""

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
func move_to(c: Dictionary,zone: String,offer_return: bool=true,allow_replacement: bool=true):
 if c.is_empty(): return
 if allow_replacement and c.zone=="grave" and zone=="hand" and not grave_replacement_sources(c).is_empty():
  if not zone_replacements.any(func(r): return r.target==ref_target(c)): zone_replacements.append({"target":ref_target(c)})
  return
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
func grave_replacement_sources(c: Dictionary) -> Array:
 if not is_unit(c) or c.zone!="grave" or not field_error(c,c.owner).is_empty(): return []
 return units(c.owner).filter(func(u): return Extra.has(cards[u.card_id],"grave_return_replace") and has_leader_ability(u) and stat(c,"power")<=stat(u,"power"))
func choose_grave_replacement(to_field: bool):
 if pending.get("kind","")!="grave_replacement": return
 var target=pending.target; pending={}
 var c=find_card(target.uid)
 if not c.is_empty() and c.zone=="grave" and c.epoch==target.epoch:
  if to_field and not grave_replacement_sources(c).is_empty(): detach(c); enter_field(c,c.owner)
  else: move_to(c,"hand",true,false)
 revision+=1; pump_choices()
func destroy(c: Dictionary):
 if c.is_empty() or Extra.keyword(self,c,"不会被消灭"): return
 if resolving_spell: c.spell_damage=true
 move_to(c,"grave")
func can_possess(c: Dictionary) -> bool:
 return not Extra.has(cards[c.card_id],"no_possession") and c.get("poverty",0)==0
func push_trigger(t: Dictionary,target: Dictionary) -> int:
 var entry=t.duplicate(true)
 entry.id=next_stack; entry.kind="ability"; entry.target=target.duplicate(true)
 stack.append(entry); next_stack+=1; passes=0; priority=1-t.owner
 if t.get("effect","")=="leader_death_damage": use_once(t.source.uid,"death_ping")
 note(t.name+" · 触发能力",history_art(t.source))
 return entry.id
func push_extended_trigger(t: Dictionary,target: Dictionary):
 push_trigger(t,target)
func complete_trigger_target(t: Dictionary,target: Dictionary):
 if pending.has("stack_id"):
  for entry in stack:
   if entry.id==pending.stack_id:
    entry.target=target.duplicate(true); entry.erase("awaiting_target"); return
 else: push_trigger(t,target)
func choose_effect(target: Dictionary):
 if pending.get("kind","")!="effect_choice": return
 var t=pending.trigger
 if target.is_empty() and (not t.optional or pending.has("stack_id")): return
 if not target.is_empty() and target not in Extra.trigger_options(self,t): return
 if not target.is_empty(): complete_trigger_target(t,target)
 pending={}
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
 if c.zone==destination and destination!="deck": return ""
 if c.get("token",false) and destination!="exile": return "衍生物离开战场后会消失"
 if destination=="leader" and not c.leader: return "只有本局自机可放入自机区"
 if destination=="field":
  if cards[c.card_id].kind=="符卡" and not Extra.has(cards[c.card_id],"timed_life"): return "该符卡不能留在战场"
  var error=field_error(c,c.owner)
  if not error.is_empty(): return error
 # Debug placement changes state directly. No enter/leave/death events, stack,
 # return choices, timer replacement, or state-based deaths are dispatched here.
 detach(c)
 if c.get("token",false): shift(c,"void")
 else:
  shift(c,destination)
  if destination=="deck": players[c.owner].deck.push_front(c)
  elif destination!="leader": players[c.owner][destination].append(c)
  if destination=="field":
   c.entered=turn; c.entered_turns=players[c.owner].turns
   c.timer=int(cards[c.card_id].get("time",0))
 passes=0
 note("调试移动："+cards[c.card_id].name+" → "+{"deck":"牌库","hand":"手牌","field":"战场","palette":"颜色盘","grave":"墓地","exile":"除外区","leader":"自机区"}[destination])
 revision+=1
 return ""

func spell_target_valid(id: String,target: Dictionary) -> bool:
 if not Extra.valid(self,target): return false
 if id=="130": return target_valid(target,true) and stat(find_card(target.uid),"spirit")>=3
 if id=="139": return target_valid(target,true) and cards[find_card(target.uid).card_id].kind!="自机"
 return true

func ai_expanded_target(who: int,c: Dictionary,options: Array) -> Dictionary:
 if options.is_empty(): return {}
 var id=c.card_id
 var candidates=options.duplicate()
 if id in ["94","130","139","147"]:
  candidates=candidates.filter(func(t): return find_card(t.uid).owner!=who)
 elif id in ["110","177"]:
  candidates=candidates.filter(func(t): return find_card(t.uid).owner==who and (id!="177" or stat(find_card(t.uid),"health")>1))
 elif id=="131":
  var counters=candidates.filter(func(t): return t.get("mode")=="反制非符" and stack.any(func(entry): return entry.id==t.stack_id and entry.owner!=who))
  if not counters.is_empty(): return counters[0]
  if not combat.is_empty():
   candidates=candidates.filter(func(t): return t.get("mode")=="不会被消灭" and find_card(t.uid).owner==who)
  else: return {}
 elif id=="143":
  var returnable=candidates.filter(func(t): return t.mode=="移回战场" and field_error(find_card(t.uid),who).is_empty())
  if not returnable.is_empty(): return returnable[0]
  return {"player":1-who,"mode":"失去生命"}
 elif id=="162": return {"player":1-who}
 elif id=="176":
  var enemies=units(1-who)
  if enemies.is_empty(): return {"parts":[{"none":true,"mode":"抓一张牌"},{"none":true,"mode":"抓一张牌"}]}
  var hit=ref_target(enemies[0]); hit.mode="造成2点伤害"
  return {"parts":[hit,hit.duplicate()]}
 return candidates[0] if not candidates.is_empty() else {}

func ai_extended_ability(who: int) -> bool:
 for c in players[who].field+players[who].grave:
  if not extension_activation_error(who,c).is_empty(): continue
  var key=Extra.activation_kind(cards[c.card_id])
  if key not in ["exile_grave","grave_return","grave_reanimate"]: continue
  if key in ["grave_return","grave_reanimate"] and (active!=who or phase!="main" or not stack.is_empty() or not combat.is_empty()): continue
  var choices=Extra.activation_options(self,c,key)
  if key=="exile_grave": choices=choices.filter(func(t): return find_card(t.uid).owner!=who)
  if choices.is_empty(): continue
  if commit_extension(who,c.uid,choices[0],payment(who,Extra.activation_cost(key)).plan).is_empty(): return true
 return false
