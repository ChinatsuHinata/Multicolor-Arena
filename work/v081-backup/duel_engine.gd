extends RefCounted
const DB=preload("res://scripts/card_database.gd")
const Effects=preload("res://scripts/rules/demo_abilities.gd")
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
var next_uid=1
var next_stack=1
var rng=RandomNumberGenerator.new()
var payment_memo={}
func _init(): cards=DB.load_cards()
func note(message: String):
 log.append(message)
 if log.size()>160: log.pop_front()
 revision+=1
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
 players.clear(); stack.clear(); triggers.clear(); returns.clear(); pending.clear(); combat.clear(); log.clear()
 next_uid=1; next_stack=1; winner=-2; turn=0; revision=0; phase="mulligan"; first=first_player; active=first; priority=first; passes=0
 if seed_value==0: rng.randomize()
 else: rng.seed=seed_value
 for i in range(2):
  var deck=a if i==0 else b
  var p={"life":20,"deck":[],"hand":[],"field":[],"palette":[],"grave":[],"leader":make_card(deck.leader,i,"leader",true),"potato":i!=first,"mulligan_done":false,"turns":0}
  for id in deck.main: p.deck.append(make_card(id,i,"deck"))
  shuffle(p.deck)
  players.append(p)
 for i in range(2): draw(i,4)
 note("对局开始，双方起手 4 张")
func shift(c: Dictionary, location: String):
 c.zone=location; c.epoch+=1; c.tapped=false; c.damage=0; c.timer=0; c.attacked=false; c.modifiers=[]
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
 phase="reset"
 for c in players[who].field+players[who].palette: c.tapped=false; c.attacked=false
 if players[who].palette.size()<8 and not players[who].deck.is_empty():
  var c=players[who].deck.pop_front(); shift(c,"palette"); players[who].palette.append(c)
 phase="prepare"
 note("第 %d 回合 · %s" % [turn,"你" if who==0 else "人机"])
func find_card(uid: int) -> Dictionary:
 for p in players:
  if p.leader.uid==uid: return p.leader
  for z in ["deck","hand","field","palette","grave"]:
   for c in p[z]:
    if c.uid==uid: return c
 for e in stack:
  if e.has("card") and e.card.uid==uid: return e.card
 return {}
func has_leader_ability(c: Dictionary) -> bool:
 if c.leader: return true
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
  var ci=COLORS.find(color)
  if needs[ci]<=0: continue
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
 var needs=[]
 for color in COLORS: needs.append(int(cost.get(color,0)))
 return payment_search(source_resources(who).filter(func(r): return r.uid not in excluded),0,needs)
func payment_valid(who: int,cost: Dictionary,plan: Array) -> bool:
 var remaining=cost.duplicate(); var used=[]; var resources=source_resources(who)
 for reservation in plan:
  if reservation.uid in used: return false
  var matched=false
  for source in resources:
   if source.uid==reservation.uid and reservation.color in source.colors: matched=true; break
  if not matched or remaining.get(reservation.color,0)<=0: return false
  remaining[reservation.color]-=1; used.append(reservation.uid)
 return remaining.values().all(func(n): return n==0)
func cast_error(who: int,uid: int) -> String:
 if winner!=-2: return "对局已结束"
 if not pending.is_empty() or phase=="mulligan": return "请先完成当前选择"
 if priority!=who: return "等待执行权"
 var c=find_card(uid)
 if c.is_empty() or c.owner!=who or c.zone not in ["hand","leader"]: return "无法从该区域使用"
 var info=cards[c.card_id]
 if not info.fast and (phase!="main" or not stack.is_empty() or not combat.is_empty() or active!=who): return "只能在自己主要阶段的空对抗时使用"
 if c.zone=="leader" and c.timer>0: return "自机仍在计时"
 if is_unit(c):
  if units(who).size()>=6: return "单位战场格已满"
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
 if payment(who,info.cost).ways==0: return "可用颜色费用不足"
 if info.kind=="符卡" and targets_for(c.card_id).is_empty(): return "没有合法目标"
 return ""
func targets_for(id: String) -> Array:
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
  if target not in targets_for(c.card_id): return "目标已失效"
 if not payment_valid(who,info.cost,plan): return "支付方案已失效"
 # All validation completes before any public mutation.
 for reservation in plan:
  if reservation.uid<0: players[who].potato=false
  else: find_card(reservation.uid).tapped=true
 if c.zone=="hand": players[who].hand.erase(c)
 shift(c,"stack")
 stack.append({"id":next_stack,"kind":"card","card":c,"owner":who,"target":target.duplicate(),"name":info.name})
 next_stack+=1; passes=0; priority=1-who
 note(("你" if who==0 else "人机")+"使用 "+info.name)
 if info.kind=="符卡": Effects.spell_used(self,who)
 pump_choices()
 return ""
func queue_trigger(who: int,source: Dictionary,amount: int,title: String):
 triggers.append({"owner":who,"source":source.duplicate(true),"amount":amount,"name":cards[source.card_id].name+" · "+title})
func pump_choices():
 if not pending.is_empty() or winner!=-2: return
 if not returns.is_empty(): pending={"kind":"leader_return","owner":returns[0].owner,"card":returns.pop_front()}; return
 while not triggers.is_empty():
  var t=triggers.pop_front()
  if units(0).is_empty() and units(1).is_empty(): continue
  pending={"kind":"trigger","owner":t.owner,"trigger":t}; return
func choose_trigger(target: Dictionary):
 if pending.get("kind","")!="trigger": return
 var t=pending.trigger
 if not target.is_empty() and target_valid(target,true):
  stack.append({"id":next_stack,"kind":"ability","source":t.source,"owner":t.owner,"amount":t.amount,"target":target.duplicate(),"name":t.name})
  next_stack+=1; passes=0; priority=1-t.owner
  note("触发能力进入对抗")
 pending={}; revision+=1; pump_choices()
func choose_return(yes: bool):
 if pending.get("kind","")!="leader_return": return
 var c=pending.card
 if yes:
  shift(c,"leader"); c.timer=2
  note("自机返回自机区 · 计时 2")
 else: shift(c,"grave"); players[c.owner].grave.append(c)
 pending={}; revision+=1; pump_choices()
func enter_field(c: Dictionary,who: int) -> bool:
 if is_unit(c):
  if units(who).size()>=6: to_grave(c); return false
  for u in units(who):
   if cards[u.card_id].title==cards[c.card_id].title and not cards[c.card_id].title.is_empty():
    to_grave(c); return false
 shift(c,"field"); c.entered=turn; c.entered_turns=players[who].turns; players[who].field.append(c)
 return true
func to_grave(c: Dictionary):
 if c.leader:
  c.zone="return_pending"; c.epoch+=1; returns.append(c)
 else: shift(c,"grave"); players[c.owner].grave.append(c)
func counter_entry(id: int):
 for e in stack:
  if e.id==id and e.kind=="card":
   stack.erase(e); to_grave(e.card); note(e.name+"被反制"); return
func damage_target(target: Dictionary,amount: int):
 if not target_valid(target): return
 if target.has("player"): players[int(target.player)].life-=amount
 else: find_card(target.uid).damage+=amount
func stat(c: Dictionary,key: String) -> int:
 var value=int(cards[c.card_id][key])
 var fields={"power":"攻击力","health":"血量","spirit":"灵力"}
 for modifier in c.get("modifiers",[]): value+=int(modifier.get(fields[key],0))
 return maxi(0,value)
func has_haste(c: Dictionary) -> bool:
 return c.get("modifiers",[]).any(func(m): return m.get("疾行",false))
func apply_turn_buff(target: Dictionary,params: Dictionary):
 if not target_valid(target,true): return
 var c=find_card(target.uid)
 if not c.has("modifiers"): c.modifiers=[]
 c.modifiers.append(params.duplicate(true))
func judge():
 for who in range(2):
  for c in players[who].field.duplicate():
   if is_unit(c) and c.damage>=stat(c,"health"):
    players[who].field.erase(c); to_grave(c); note(cards[c.card_id].name+"离开战场")
 var dead=[]
 for who in range(2):
  if players[who].life<=0: dead.append(who)
 if dead.size()==2: winner=-1; phase="over"; pending={}; note("平局")
 elif dead.size()==1: lose(dead[0],"生命归零")
func lose(who: int,reason: String):
 if winner!=-2: return
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
   if e.get("effect","")=="untap":
    if target_valid(e.target,true): find_card(e.target.uid).tapped=false
   else: damage_target(e.target,e.amount)
   note(e.name+"结算")
  elif cards[e.card.card_id].kind=="符卡" and not target_valid(e.target):
   to_grave(e.card); note("目标失效，"+e.name+"不结算")
  else: Effects.resolved(self,e); note(e.name+"结算")
  judge(); priority=active; pump_choices()
 elif not combat.is_empty(): advance_combat()
 else: advance_phase()
 revision+=1
func advance_phase():
 if winner!=-2: return
 priority=active; passes=0
 match phase:
  "prepare":
   if turn==1: phase="possession"
   else: phase="draw"; draw(active)
   if phase=="possession": offer_possession()
  "draw": phase="possession"; offer_possession()
  "possession": phase="main"
  "main":
   phase="end"
   for c in units(active):
    if c.attacked and DB.has_ability(cards[c.card_id],"brave"):
     stack.append({"id":next_stack,"kind":"ability","source":c.duplicate(true),"owner":active,"effect":"untap","target":ref_target(c),"name":cards[c.card_id].name+" · 英勇"})
     next_stack+=1
   if not stack.is_empty(): note("英勇进入堆叠")
  "end": cleanup_end()
func offer_possession():
 if not players[active].hand.is_empty() and players[active].palette.any(func(c): return not c.tapped): pending={"kind":"possession","owner":active}
func possession(palette_uid: int=-1,hand_uid: int=-1):
 if pending.get("kind","")!="possession": return
 var who=pending.owner
 if palette_uid>=0 and hand_uid>=0:
  var p=find_card(palette_uid); var h=find_card(hand_uid)
  if p.is_empty() or h.is_empty() or p.zone!="palette" or h.zone!="hand" or p.owner!=who or h.owner!=who or p.tapped: return
  players[who].palette.erase(p); players[who].hand.erase(h)
  shift(p,"hand"); shift(h,"palette")
  players[who].hand.append(p); players[who].palette.append(h)
  note("凭依完成")
 pending={}; priority=active; passes=0; revision+=1
func cleanup_end():
 var leader=players[active].leader
 if leader.zone=="leader": leader.timer=maxi(0,leader.timer-1)
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
  for c in p.field: c.damage=0; c.modifiers=[]
 start_turn(1-active)
func can_attack(who: int,uid: int) -> bool:
 var c=find_card(uid)
 return winner==-2 and pending.is_empty() and priority==who and active==who and phase=="main" and stack.is_empty() and combat.is_empty() and not c.is_empty() and c.owner==who and c.zone=="field" and is_unit(c) and not c.tapped and (not summoning_sick(c) or has_haste(c))
func attack(who: int,uid: int):
 if not can_attack(who,uid): return
 var c=find_card(uid); c.tapped=true; c.attacked=true
 combat={"attacker":ref_target(c),"owner":who,"blockers":[],"blocked":false,"step":"attack_window"}
 priority=1-who; passes=0; note("宣言攻击："+cards[c.card_id].name)
func legal_blockers() -> Array:
 if combat.is_empty(): return []
 var attacker=find_card(combat.attacker.uid)
 if attacker.is_empty(): return []
 var result=[]
 for c in units(1-combat.owner):
  if c.tapped: continue
  if DB.has_ability(cards[attacker.card_id],"exterminate") and has_leader_ability(attacker) and "人类" not in cards[c.card_id].race: continue
  result.append(c)
 return result
func block(uids: Array):
 if pending.get("kind","")!="block": return
 var valid=legal_blockers(); var chosen=[]
 for uid in uids:
  var c=find_card(uid)
  if c not in valid or c in chosen: return
  chosen.append(c)
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
  "attack_window": pending={"kind":"block","owner":1-combat.owner}
  "block_window":
   if surviving.size()>1:
    pending={"kind":"damage_assignment","owner":combat.owner,"total":stat(find_card(combat.attacker.uid),"power")}
   else: combat_damage({})
  "damage_window": end_combat()
func combat_damage(allocation: Dictionary):
 if combat.is_empty(): return
 var attacker=find_card(combat.attacker.uid)
 if not target_valid(combat.attacker,true): end_combat(); return
 var power=stat(attacker,"power")
 if combat.blockers.size()>1:
  var total=0
  for t in combat.blockers:
   var amount=int(allocation.get(str(t.uid),0))
   if amount<0: return
   total+=amount
  if total!=power: return
 pending={}
 if not combat.blocked: players[1-combat.owner].life-=stat(attacker,"spirit")
 else:
  var retaliation=0
  for t in combat.blockers:
   var blocker=find_card(t.uid)
   blocker.damage+=power if combat.blockers.size()==1 else int(allocation.get(str(t.uid),0))
   retaliation+=stat(blocker,"power")
  attacker.damage+=retaliation
  if active==combat.owner and phase=="main" and DB.has_ability(cards[attacker.card_id],"annihilate"):
   if combat.blockers.any(func(t): return find_card(t.uid).damage>=stat(find_card(t.uid),"health")):
    players[1-combat.owner].life-=stat(attacker,"spirit")
    note("歼灭造成 %d 点战斗伤害" % stat(attacker,"spirit"))
 combat.step="damage_window"; priority=active; passes=0
 note("战斗伤害结算"); judge(); pump_choices()
func end_combat():
 combat={}; priority=active; passes=0; revision+=1
func legal_casts(who: int,fast_only: bool=false) -> Array:
 var result=[]
 var options=players[who].hand.duplicate()
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
    if not available.is_empty(): chosen=[available[0].uid]
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
    commit_cast(who,c.uid,{"stack_id":stack.back().id},payment(who,cards[c.card_id].cost).plan); return
  if ai_fast_action(who,choices): return
  pass_priority(who); return
 if active==who and phase=="main" and combat.is_empty():
  # Build colored permanents first, then units and damage spells.
  choices.sort_custom(func(a,b): return ai_card_score(a)>ai_card_score(b))
  for c in choices:
   if DB.has_ability(cards[c.card_id],"counter_card"): continue
   var target=ai_spell_target(who,c)
   if cards[c.card_id].kind=="符卡" and target.is_empty(): continue
   if commit_cast(who,c.uid,target,payment(who,cards[c.card_id].cost).plan).is_empty(): return
  for c in units(who):
   if can_attack(who,c.uid): attack(who,c.uid); return
 if ai_fast_action(who,choices): return
 pass_priority(who)
func ai_spell_target(who: int,c: Dictionary) -> Dictionary:
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
  if DB.has_ability(info,"damage"):
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
  if commit_cast(who,c.uid,target,payment(who,info.cost).plan).is_empty(): return true
 return false
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
  if palette[pi].tapped: continue
  for hi in range(hand.size()):
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
 if c.is_empty() or c.owner!=who or c.zone!="field": return result
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
 for c in players[who].field:
  if available_actions(who,c.uid).any(func(a): return a.type=="ability"): return true
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
 next_stack+=1; passes=0; priority=1-who
 note("发动 "+cards[c.card_id].name+"的异能")
 return ""
