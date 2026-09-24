extends RefCounted
const Roster=preload("res://scripts/rules/excel_abilities.gd")
const Cat=Roster.Cat
const Pack=preload("res://scripts/rules/precon_abilities.gd")
const DB=preload("res://scripts/card_database.gd")
const Extra=preload("res://scripts/rules/expanded_abilities.gd")
const Effects=preload("res://scripts/rules/demo_abilities.gd")
const ColorCost=preload("res://scripts/rules/color_cost.gd")
const COLORS=["红","蓝","绿","黄","黑"]
var player_names=["你","人机"]
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
var next_buff_order=0
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
var damage_context={}
var unpreventable_turn=-1
var forced_cast={}
var extra_turns=[]
var catalogue_death_depth=0
var catalogue_death_owner=-1
var catalogue_serial=0
var catalogue_target_fast=false
var catalogue_x_override=0
var catalogue_retargeting=false
var presentation_events: Array=[]
var reveal_serial=0
# Private declaration preference; cleared on commit/cancel, never a paid action.
var paid_cast_uid=-1
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
func reveal_card(c: Dictionary,edge: String=""):
 if c.is_empty(): return
 reveal_serial+=1
 presentation_events.append({"type":"reveal","serial":reveal_serial,"card":c.duplicate(true),"edge":edge})
 record_history("展示 · "+cards[c.card_id].name,history_art(c))
 revision+=1

func show_result(message: String,source: Dictionary={}):
 note(message,history_art(source))
 presentation_events.append({"type":"result","text":message,"card":source.duplicate(true)})
func record_declaration(who: int,target: Dictionary,source: Dictionary):
 var parts=[]
 for key in ["card_name","color","guess","declaration"]:
  if target.has(key):parts.append(str(target[key]))
 if not parts.is_empty():show_result(player_names[who]+"宣言 · "+" / ".join(parts),source)
func present_move(c: Dictionary,destination: String,to_owner: int=-1):
 if c.get("zone","") in ["", "void"]:return
 var before=c.duplicate(true);before.owner=c.get("motion_from_owner",c.owner);before.erase("motion_from_owner");c.erase("motion_from_owner")
 presentation_events.append({"type":"move","card":before,"from":c.zone,"to":destination,"to_owner":c.owner if to_owner<0 else to_owner})
func history_art(c: Dictionary) -> Array:
 return [{"card_id":c.card_id,"owner":c.owner,"hidden":false}] if c.has("card_id") else []
func make_card(id: String, owner: int, location: String, leader: bool=false) -> Dictionary:
 var c={"original_owner":owner,"token":cards[id].get("token",false),"uid":next_uid,"epoch":0,"card_id":id,"owner":owner,"zone":location,"leader":leader,"tapped":false,"damage":0,"timer":0,"entered":0,"attacked":false}
 next_uid+=1
 return c
func flip_coin(who: int) -> bool:
 var heads=rng.randi_range(0,1)==1
 show_result(player_names[who]+"掷硬币 · "+("正面" if heads else "反面"))
 Roster.on_coin(self,who);Cat.State.on_coin(self,who,heads)
 return heads
func shuffle(cards_to_shuffle: Array):
 for i in range(cards_to_shuffle.size()-1,0,-1):
  var j=rng.randi_range(0,i)
  var tmp=cards_to_shuffle[i]
  cards_to_shuffle[i]=cards_to_shuffle[j]
  cards_to_shuffle[j]=tmp
func start(a: Dictionary,b: Dictionary, first_player: int, seed_value: int=0):
 forced_cast={};paid_cast_uid=-1;extra_turns=[];presentation_events.clear();reveal_serial=0
 delayed.clear(); combat_queue.clear(); timer_changes.clear(); turn_usage.clear(); death_trigger_events.clear(); cleanup_done=false
 zone_replacements.clear(); damage_context={}; unpreventable_turn=-1
 recorded_life=[20,20]
 next_damage_batch=1
 next_buff_order=0
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
 Roster.New.start(self)
 for i in range(2): draw(i,4)
 note("对局开始，双方起手 4 张")
func shift(c: Dictionary, location: String):
 var old=c.get("zone","")
 present_move(c,location)
 if c.has("copy_original") or c.has("habitat_base"):
  c.card_id=c.get("copy_original",c.get("habitat_base",c.card_id));c.erase("copy_original");c.erase("habitat_base");c.erase("inherited_self")
 if old!=location and old not in ["token","void",""]:
  var names={"hand":"手牌","deck":"牌库","field":"战场","palette":"颜色盘","grave":"墓地","exile":"除外","leader":"自机区","stack":"堆叠","return_pending":"自机返回","void":"消失","outside":"本局游戏外"}
  var hidden=old in ["hand","deck"] and location in ["hand","deck"]
  var caption=player_names[c.owner]+" · "+names.get(old,old)+" → "+names.get(location,location)
  if not hidden: caption+="\n"+cards[c.card_id].name
  record_history(caption,[{"card_id":c.card_id,"owner":c.owner,"hidden":hidden}])
 c.zone=location; c.epoch+=1; c.tapped=false; c.damage=0; c.timer=0; c.attacked=false; c.modifiers=[]; c.plus_counters=0; c.poverty=0; c.spell_damage=false
 c.leader_counters=0
 for k in ["sanae_used","brave_attack_turn","locked_name","rank_target","imp_growth","reisen_illusion","catalogue_access","catalogue_castle","dream","madness","noncombat_damage_turn"]:c.erase(k)
 if old!="stack" or location!="field":
  for k in ["ichirin_paid","top_free_damage","haste_on_enter","exiled_hand","paid_dolls"]:c.erase(k)
 for key in ["wards","color_counters","free_exile_owner","devour_owner","base_override","lock_sources","castle_exiles","medicine","skip_reset","tapped_turn"]: c.erase(key)
 for k in ["history_spent","drunk_counters","n21_drunk_triggered","n21_suika_return","n21_spirit","courage","moods","minus_counters","scare","freeze_until","perfect_lock","control_return","died_turn","excel_access"]:c.erase(k)
 if old!="stack" or location!="field": c.erase("cast_x");c.erase("exile_on_grave")
func draw(who: int,count: int=1):
 for i in range(count):
  if players[who].deck.is_empty(): lose(who,"牌库不足，无法抓牌"); return
  var c=players[who].deck.pop_front()
  shift(c,"hand"); players[who].hand.append(c);Cat.State.on_draw(self,who)
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
 note(player_names[who]+"完成调度")
 if players[0].mulligan_done and players[1].mulligan_done: start_turn(first)
func start_turn(who: int):
 if winner!=-2: return
 active=who; priority=who; passes=0; turn+=1; players[who].turns+=1
 players[who].possession_count=0
 phase="reset"; turn_usage.clear(); death_trigger_events.clear(); cleanup_done=false
 for c in players[who].field+players[who].palette:
  if Pack.reset_allowed(self,c): c.tapped=false
  c.attacked=false
 if players[who].palette.size()<8 and not players[who].deck.is_empty():
  var c=players[who].deck.pop_front(); shift(c,"palette"); players[who].palette.append(c);Cat.State.on_palette(self,c)
 phase="prepare"
 run_delayed("prepare")
 Pack.on_phase(self,"prepare");Roster.on_phase(self,"prepare")
 pump_choices()
 note("第 %d 回合 · %s" % [turn,player_names[who]])
func leaders(who: int) -> Array:return [players[who].leader]+players[who].get("extra_leaders",[])
func find_card(uid: int) -> Dictionary:
 for p in players:
  for leader in [p.leader]+p.get("extra_leaders",[]):
   if leader.uid==uid:return leader
  for z in ["deck","hand","field","palette","grave","exile"]:
   for c in p[z]:
    if c.uid==uid: return c
 for e in stack:
  if e.has("card") and e.card.uid==uid: return e.card
 return {}
func stackable_signature(c: Dictionary) -> String:
 if c.is_empty() or c.get("zone","")!="field" or not cards.get(c.card_id,{}).get("stackable",false):return ""
 var state=c.duplicate(true)
 for field in ["uid","epoch","entered","entered_turns"]:state.erase(field)
 return JSON.stringify(state)
func stackable_members(c: Dictionary) -> Array:
 var signature=stackable_signature(c)
 if signature.is_empty():return []
 return players[c.owner].field.filter(func(u):return stackable_signature(u)==signature)
func can_batch_stackable_sacrifice(c: Dictionary,key: String) -> bool:
 if c.is_empty() or not cards.get(c.card_id,{}).get("stackable",false):return false
 # 要石有目标，每次只启动一张；无牺牲异能的新闻素材只合并显示。
 return c.card_id=="token-fdf-127" and key=="token-fdf-127" or c.card_id=="token-fdf-128" and key=="wine_discount"
func has_leader_ability(c: Dictionary) -> bool:
 if c.is_empty(): return false
 if Cat.State.grant_self(self,c) or c.get("leader",false) or c.get("leader_counters",0)>0: return true
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
  if not c.tapped: sources.append({"uid":c.uid,"colors":Pack.colors(self,c),"weight":Pack.colors(self,c).size()*10,"kind":"palette"})
 for c in players[who].field:
  if not c.tapped and DB.has_ability(cards[c.card_id],"mana"):
   sources.append({"uid":c.uid,"colors":[DB.ability(cards[c.card_id],"mana")["颜色"]],"weight":8,"kind":"item"})
  elif Cat.enabled(self,c,"character-fdf-098") and not Cat.State.activation_locked(self,c) and not Roster.Batch.locked(self,c) and Roster.activation_error(self,c,"character-fdf-098").is_empty():
   # This unit pays yellow and green together. It is one tap, never two separate sources.
   sources.append({"uid":c.uid,"colors":["黄/绿"],"pair":["黄","绿"],"weight":18,"kind":"unit"})
 sources.append_array(players[who].get("mana",[]))
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
 if sources[index].has("pair"):
  var pair=sources[index].pair
  for first_group in range(needs.size()):
   if needs[first_group]<=0 or pair[0] not in payment_groups[first_group]:continue
   var first_needs=needs.duplicate();first_needs[first_group]-=1
   for second_group in range(needs.size()):
    if first_needs[second_group]<=0 or pair[1] not in payment_groups[second_group]:continue
    var remaining=first_needs.duplicate();remaining[second_group]-=1
    var tail=payment_search(sources,index+1,remaining)
    if tail.ways==0:continue
    var ways=mini(2,best.ways+tail.ways)
    var score=tail.score+sources[index].weight
    if score<best.score:best={"ways":ways,"score":score,"plan":[{"uid":sources[index].uid,"color":"黄/绿"}]+tail.plan}
    else:best.ways=ways
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
 if Pack.response_locked(self): return "该牌不能被响应"
 var c=find_card(uid)
 if c.is_empty(): return "无法从该区域使用"
 if c.zone=="exile" and c.get("history_spent",false):return "该牌结算后不能再次使用"
 if not Pack.cast_from(self,c,who) and (c.owner!=who or c.zone not in ["hand","leader"] and not (c.zone=="deck" and Extra.has(cards[c.card_id],"deck_damage"))): return "无法从该区域使用"
 var info=cards[c.card_id]
 var catalogue_error=Cat.State.cast_error(self,c,who)
 if not catalogue_error.is_empty():return catalogue_error
 if not Pack.fast(self,c,who) and (phase!="main" or not stack.is_empty() or not combat.is_empty() or active!=who): return "只能在自己主要阶段的空对抗时使用"
 if c.zone=="leader" and c.timer>0: return "自机仍在计时"
 if is_unit(c):
  if field_slots(who)>=Cat.field_limit(self,who) and not Extra.keyword(self,c,"不占战场格"): return "单位战场格已满"
  for u in units(who):
   if cards[u.card_id].title==info.title and not info.title.is_empty(): return "同称号单位已经在场"
  if info.kind=="自机" and not Roster.bypass(self,c,who):
   var provided=[]
   if Cat.race(self,c,"吸血鬼") and units(who).any(func(u):return Cat.has(self,u,"character-fdn-014")):provided=COLORS.duplicate()
   for permanent in players[who].field:
    if cards[permanent.card_id].kind=="符卡": continue
    for color in Pack.colors(self,permanent):
     if color not in provided: provided.append(color)
   var requirements=info.cost.keys() if info.cost.keys().any(func(k):return "/" in k) else info.colors
   for requirement in requirements:
    if not Array(str(requirement).split("/")).any(func(color):return color in provided): return "战场永久物尚未满足自机颜色约束"
 if not info.requires_character.is_empty() and not Roster.bypass(self,c,who):
  var present=Cat.State.role_present(self,c,who)
  for u in units(who):
   if Roster.character_matches(cards[u.card_id].character,info.requires_character): present=true
  if "支援" in info.get("keywords",[]) and leaders(who).any(func(leader):return leader.zone=="leader" and Roster.character_matches(cards[leader.card_id].character,info.requires_character)): present=true
  if not present: return "需要操控"+info.requires_character
 var can_pay=payment(who,cast_cost(who,c)).ways>0
 if not can_pay and c.card_id=="spell-fdf-082":
  for ignored in ["蓝","黄"]:
   if payment(who,cast_cost(who,c,{"ignore_color":ignored})).ways>0:can_pay=true;break
 if not can_pay and not Cat.alternative_affordable(self,c,who): return "可用颜色费用不足"
 if info.kind=="符卡" and targets_for(c.card_id,who).is_empty(): return "没有合法目标"
 return ""
func targets_for(id: String,acting: int=-1,source_uid: int=-1) -> Array:
 if acting<0: acting=priority
 catalogue_target_fast=cards[id].fast
 var extended=Extra.spell_options(self,id,acting)
 if extended!=null:
  if source_uid>=0 and Roster.free_cast(self,find_card(source_uid),acting):extended=extended.filter(func(t):return int(t.get("x",0))==0)
  if source_uid>=0:
   for spec in extended:
    for g in spec.get("selection",[]):
     if g.get("cost",false):g.pool=g.pool.filter(func(r):return r.get("uid",-1)!=source_uid)
  return Roster.filter_options(self,extended,acting,true)
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
 return Roster.filter_options(self,targets,acting,true)
func ref_target(c: Dictionary) -> Dictionary: return {"uid":c.uid,"epoch":c.epoch}
func target_valid(target: Dictionary,unit_only: bool=false) -> bool:
 if target.has("player"): return not unit_only and int(target.player) in [0,1]
 if target.has("stack_id"):
  if unit_only:return false
  for e in stack:
   if e.id==target.stack_id: return true
  return false
 var c=find_card(int(target.get("uid",-1)))
 return not c.is_empty() and c.zone=="field" and is_unit(c) and c.epoch==target.get("epoch",-1)
func commit_cast(who: int,uid: int,target: Dictionary,plan: Array) -> String:
 var error=cast_error(who,uid)
 if not error.is_empty(): return error
 var c=find_card(uid); var info=cards[c.card_id]
 var target_spec={}
 if info.kind=="符卡" or not info.get("variable_cost","").is_empty() or c.card_id=="character-fdf-046":
  var legal_options=targets_for(c.card_id,who,uid)
  if not Pack.choice_valid(self,legal_options,target): return "目标已失效"
  # A paid sacrifice/discard may remove a cost choice before an opponent can
  # redirect the spell. Keep only the matching declaration-time specification.
  for spec in legal_options:
   if spec.has("selection") and spec.selection.any(func(g):return g.get("cost",false)) and Pack.choice_valid(self,[spec],target):target_spec=spec.duplicate(true);break
 if Roster.free_cast(self,c,who) and int(target.get("x",0))!=0:return "不支付颜色值使用时，X为0"
 if not payment_valid(who,cast_cost(who,c,target),plan): return "支付方案已失效"
 if Roster.key(info,["discard_draw","door_reveal"])!="" and Pack.picked(target).any(func(r):return r.uid==uid):return "不能弃置正在使用的牌"
 var old_zone=c.zone
 catalogue_serial+=1
 # All validation completes before any public mutation.
 if Roster.key(info,["discard_draw","door_reveal"])!="":
  for r in Pack.picked(target):move_to(find_card(r.uid),"grave")
 Cat.pay(self,who,plan)
 var catalogue_paid=Cat.paid_cast(self,c,target,who)
 if target.has("sacrifice"):
  sacrifice(find_card(target.sacrifice.uid))
 detach(c)
 var reveal=Pack.picked(target) if Pack.has(info,"reveal_counter") else []
 for r in reveal:
  var shown=find_card(r.uid); reveal_card(shown)
 shift(c,"stack");presentation_events.back().to_owner=who; c.owner=who;c.merge(catalogue_paid,true)
 stack.append({"id":next_stack,"kind":"card","card":c,"owner":who,"target":target.duplicate(),"name":info.name})
 if not target_spec.is_empty():stack.back().target_spec=target_spec
 next_stack+=1; passes=0; priority=1-who
 note(player_names[who]+"使用 "+info.name,history_art(c))
 Roster.on_cast(self,c,who,old_zone)
 Pack.on_cast(self,c,who,target);Roster.New.on_target(self,target)
 if info.kind=="符卡": Effects.spell_used(self,who)
 judge();pump_choices()
 return ""
func queue_trigger(who: int,source: Dictionary,amount: int,title: String):
 if Pack.trigger_locked(self): return
 Cat.enqueue(self,{"owner":who,"source":source.duplicate(true),"amount":amount,"optional":true,"name":cards[source.card_id].name+" · "+title})
func trigger_options(t: Dictionary) -> Array:
 catalogue_target_fast=false
 if t.get("continuation",false):return Extra.trigger_options(self,t)
 if t.get("extended",false): return Roster.filter_options(self,Extra.trigger_options(self,t),t.owner,false)
 if t.get("effect","")=="untap": return [{"none":true}]
 return Roster.filter_options(self,(units(0)+units(1)).map(func(c): return ref_target(c)),t.owner,false)
func begin_trigger(t: Dictionary):
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
 if entry.get("effect","")=="leader_death_damage" and not entry.get("no_legal_targets",false):use_once(entry.source.uid,"death_ping")
 if not entry.get("no_legal_targets",false):Roster.on_ability_announced(self,entry);Roster.New.on_target(self,entry.target)
func choose_trigger_order(index: int):
 if pending.get("kind","")!="trigger_order" or index<0 or index>=pending.options.size(): return
 var t=pending.options[index]
 triggers.erase(t); pending={}
 begin_trigger(t); revision+=1; pump_choices()
func pump_choices():
 judge()
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
 if target.is_empty() and not t.get("optional",true): return
 if not target.is_empty() and target not in pending.options: return
 if not target.is_empty(): complete_trigger_target(t,target)
 else:decline_stacked_trigger()
 pending={}; revision+=1; pump_choices()
func choose_return(yes: bool):
 if pending.get("kind","")!="leader_return": return
 var c=pending.card
 var destination=c.get("return_destination","grave")
 var before=c.get("return_snapshot",c.duplicate(true)).duplicate(true)
 var observers=c.get("return_death_observers",[])
 var blink_owner=int(c.get("blink_return_owner",-1));c.erase("blink_return_owner")
 var suika_return=bool(c.get("n21_pending_suika_return",false));c.erase("n21_pending_suika_return")
 var stay_in_exile=bool(c.get("return_stay",false));c.erase("return_stay")
 var shuffle_on_return_deck=bool(c.get("shuffle_on_return_deck",false));c.erase("shuffle_on_return_deck")
 var wind_bounce_spell=int(c.get("wind_bounce_spell",-1));c.erase("wind_bounce_spell")
 var wind_bounce_value=int(c.get("wind_bounce_value",0));c.erase("wind_bounce_value")
 pending={}
 if yes:
  if stay_in_exile:detach(c)
  shift(c,"leader"); add_timer(c,0 if Roster.enabled(self,before,"cirno_return") else maxi(0,2-(Cat.with_key(self,c.owner,"field-fdf-107").size() if Cat.race(self,c,"神") else 0)))
  note("自机返回自机区 · 计时 2")
 elif not stay_in_exile:
  shift(c,destination); players[c.owner][destination].append(c)
  if destination=="deck" and shuffle_on_return_deck:shuffle(players[c.owner].deck)
  if suika_return and destination=="exile":c.n21_suika_return=true
 if wind_bounce_spell>=0:
  var wind_spell=find_card(wind_bounce_spell)
  if not wind_spell.is_empty() and wind_spell.has("wind_bounce"):
   var wind=wind_spell.wind_bounce
   if c.zone=="hand":wind.total+=wind_bounce_value
   wind.remaining-=1
   if wind.remaining<=0:
    players[wind.target].life-=int(wind.total/2)
    wind_spell.erase("wind_bounce")
    judge()
 # Returning home after death does not erase the death event. Retain the
 # field observers from before the move, including simultaneous casualties.
 if destination=="grave" and before.zone=="field":
  var previous_observers=death_observers
  death_observers=observers
  Extra.on_death(self,c,before)
  death_observers=previous_observers
 if before.zone=="field":Roster.on_leave(self,before,c)
 if not yes and blink_owner>=0 and destination=="exile":Roster.field_many(self,[c],blink_owner)
 c.erase("return_snapshot"); c.erase("return_destination"); c.erase("return_death_observers")
 revision+=1; pump_choices()
func enter_field(c: Dictionary,who: int) -> bool:
 if not field_error(c,who).is_empty(): to_grave(c); return false
 shift(c,"field"); c.entered=turn; c.entered_turns=players[who].turns; players[who].field.append(c)
 replace_melody(c)
 Extra.on_enter(self,c)
 return true
func is_melody(c: Dictionary) -> bool:
 return not c.is_empty() and "乐章" in cards[c.card_id].get("spell_type","")
func replace_melody(incoming: Dictionary,silent: bool=false):
 if not is_melody(incoming): return
 # 2.34f: a rule action, never a destroy effect or a separate stack object.
 for old in (players[0].field+players[1].field).duplicate():
  if old.uid==incoming.uid or not is_melody(old): continue
  note("规则动作 · 乐章替换 · "+cards[old.card_id].name,history_art(old))
  history.back().rule_action=true
  if silent:
   detach(old);old.owner=old.get("original_owner",old.owner);shift(old,"grave");players[old.owner].grave.append(old)
  else: move_to(old,"grave",false)
func to_grave(c: Dictionary):
 move_to(c,"grave")
func counter_entry(id: int):
 for e in stack:
  if e.id==id:
   stack.erase(e)
   if e.kind=="card": to_grave(e.card)
   else:failed_delayed_return(e)
   note(e.name+"被反制"); return
func failed_delayed_return(entry: Dictionary):
 # CR 1.216b: a designated leader may return home when its blink return fails.
 if entry.get("effect","")!="delayed_return":return
 var data=entry.get("data",{});var target=data.get("ref",{});var c=find_card(target.get("uid",-1))
 if c.is_empty() or not c.get("leader",false) or c.zone!="exile" or c.epoch!=target.get("epoch",-1):return
 if c.has("return_destination"):return
 c.return_destination="exile";c.return_snapshot=c.duplicate(true);c.return_stay=true
 returns.append(c)
func tap_card(c: Dictionary):
 if c.is_empty() or c.tapped: return
 c.tapped=true; Pack.on_tap(self,c);Roster.New.on_tap(self,c)
func gain_life(who: int,amount: int):
 if amount<=0 or not Cat.with_key(self,-1,"spell-fdn-002").is_empty(): return
 players[who].life+=amount; Pack.on_gain_life(self,who,amount);Cat.State.on_gain(self,who,amount)
func add_coin(who: int,amount: int=1):
 if amount<=0:return
 var p=players[who]
 if int(p.get("coins",0))<=0:
  next_buff_order+=1;p.coin_order=next_buff_order
 p.coins=int(p.get("coins",0))+amount
func damage_target(target: Dictionary,amount: int) -> int:
 if amount<=0 or not target_valid(target): return 0
 amount=Pack.adjusted_damage(self,target,amount)
 if amount<=0: return 0
 var remaining=0 if target.has("player") else stat(find_card(target.uid),"health")-find_card(target.uid).damage
 if target.has("player"): players[int(target.player)].life-=amount
 else:
  var c=find_card(target.uid)
  if Roster.wither(self):Roster.Batch.counter(self,c,"minus_counters",amount,damage_context.get("source",{}).get("owner",1-c.owner))
  else:c.damage+=amount
  record_history(cards[c.card_id].name+"受到%d点伤害" % amount,history_art(c))
  c.spell_damage=resolving_spell
 Pack.on_damage(self,target,amount)
 Roster.on_damage(self,target,amount);Cat.State.on_damage(self,target,amount,remaining)
 return amount
func combat_hit(source: Dictionary,target: Dictionary,amount: int) -> int:
 var old=damage_context
 damage_context={"source":source,"combat":true,"single":true}
 var result=damage_target(target,amount); damage_context=old
 return result
func stat(c: Dictionary,key: String) -> int:
 var value=Pack.base_stat(self,c,key)+int(c.get("plus_counters",0))+Roster.stat_adjust(self,c,key)
 if key=="spirit" and c.zone=="field":
  for permanent in players[c.owner].field:
   if Extra.has(cards[permanent.card_id],"spirit_aura"): value+=1
 var fields={"power":"攻击力","health":"血量","spirit":"灵力"}
 for modifier in c.get("modifiers",[]): value+=int(modifier.get(fields[key],0))
 return value if key=="health" else maxi(0,value)
func has_haste(c: Dictionary) -> bool:
 return Extra.keyword(self,c,"疾行")
func apply_turn_buff(target: Dictionary,params: Dictionary):
 if not target_valid(target,true): return
 var c=find_card(target.uid)
 if not c.has("modifiers"): c.modifiers=[]
 c.modifiers.append(params.duplicate(true))
var judging=false
func judge():
 if judging or players.size()!=2 or winner!=-2:return
 judging=true
 Cat.State.state_checks(self)
 Pack.state_checks(self)
 for who in range(2):
  var life=players[who].life
  if life!=recorded_life[who]:
   record_history(player_names[who]+" · 生命 %d → %d" % [recorded_life[who],life])
   recorded_life[who]=life
 for batch in range(64):
  Cat.State.state_checks(self);Pack.state_checks(self)
  var dying=(units(0)+units(1)).filter(func(c):return stat(c,"health")<=0 or c.damage>=stat(c,"health") and not Extra.keyword(self,c,"不会被消灭"))
  if dying.is_empty():break
  death_observers=(units(0)+units(1)).duplicate(true)
  for c in dying:
   if resolving_spell:c.spell_damage=true
   to_grave(c);note(cards[c.card_id].name+"离开战场")
 death_observers=[]
 var dead=[]
 for who in range(2):
  if players[who].life<=0 and not cannot_lose(who): dead.append(who)
 if dead.size()==2: winner=-1; phase="over"; pending={}; note("平局")
 elif dead.size()==1: lose(dead[0],"生命归零")
 judging=false
func lose(who: int,reason: String,forced: bool=false):
 if winner!=-2: return
 if not forced and reason!="投降" and cannot_lose(who): return
 winner=1-who; phase="over"; pending={}; note(player_names[who]+reason)
func surrender(who: int): lose(who,"投降")
func pass_priority(who: int):
 if winner!=-2 or not pending.is_empty() or phase=="mulligan" or priority!=who: return
 passes+=1
 if passes<2: priority=1-who; revision+=1; return
 passes=0
 if not stack.is_empty():
  catalogue_serial+=1
  var e=stack.pop_back()
  catalogue_target_fast=cards[e.card.card_id].fast if e.kind=="card" else false
  e.target=Roster.invalidate(self,e.target,e.owner,e.kind=="card")
  var source=e.get("card",e.get("source",{}))
  damage_context={"source":source,"single":Pack.single_damage_target(e),"combat":false}
  if e.kind=="ability":
   if e.get("no_legal_targets",false):pass
   elif e.get("extended",false): Extra.resolve_trigger(self,e)
   elif e.get("activation",false): Extra.resolve_activation(self,e)
   elif e.get("effect","")=="untap":
    if target_valid(e.target,true): find_card(e.target.uid).tapped=false
   else: damage_target(e.target,e.amount)
   note(e.name+"结算",history_art(e.get("source",{})))
  elif e.get("rewritten_fairy",false):Roster.Batch.rewritten_resolve(self,e);note(e.name+"改写效果结算",history_art(e.card))
  elif cards[e.card.card_id].kind=="符卡" and not spell_target_valid(e.card.card_id,e.target):
   to_grave(e.card); note("目标失效，"+e.name+"不结算")
  else: Effects.resolved(self,e); note(e.name+"结算",history_art(e.card))
  judge(); damage_context={}; priority=active; pump_choices()
 elif not combat.is_empty(): advance_combat()
 else: advance_phase()
 revision+=1
func advance_phase():
 if winner!=-2: return
 var old_phase=phase
 for p in players:p.mana=[]
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
  "possession": phase="main";Roster.on_phase(self,"main");pump_choices()
  "main":
   priority=active
   if units(active).any(func(c):return c.get("madness",0)>0 and not c.attacked and can_attack(active,c.uid)):
    priority=active;passes=0;note("仍有必须攻击的单位");return
   phase="end"
   run_delayed("end")
   Pack.on_phase(self,"end");Roster.on_phase(self,"end")
   for c in units(active):
    if Extra.has(cards[c.card_id],"end_grave_return"): Extra.event(self,c,"end_grave_return",true)
    if c.get("brave_attack_turn",-1)==turn and (DB.has_ability(cards[c.card_id],"brave") or Extra.keyword(self,c,"英勇")) and Roster.reset_allowed(self,c):
     c.tapped=false
     note(cards[c.card_id].name+" · 英勇重置",history_art(c))
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
  players[who].hand.append(p); players[who].palette.append(h);Cat.State.on_palette(self,h);Roster.New.on_palette(self,h,"hand")
  note("凭依完成")
  players[who].possession_count=int(players[who].get("possession_count",0))+1
 pending={}; priority=active; passes=0; revision+=1
 if palette_uid>=0 and players[who].get("possession_count",0)<(3 if not Cat.with_key(self,who,"spell-htk-004").is_empty() else 1):offer_possession()
 pump_choices()
func cleanup_end():
 if not cleanup_done:
  cleanup_done=true
  for c in players[active].field+leaders(active):
   if c.zone not in ["field","leader"] or c.timer<=0: continue
   c.timer=maxi(0,c.timer-1)
   if c.zone=="field" and Extra.has(cards[c.card_id],"timed_life") and c.timer==0: move_to(c,"grave"); lose(active,"反魂蝶计时归零",true)
  judge(); pump_choices()
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
 Roster.cleanup(self)
 for p in players:
  p.wards=[]; p.wine=[];p.mana=[]
  for c in p.field: c.damage=0; c.modifiers=[]; c.spell_damage=false; c.wards=c.get("wards",[]).filter(func(w):return w.turn==-1); c.base_override={}; c.medicine=[]
 start_turn(extra_turns.pop_front() if not extra_turns.is_empty() else 1-active)
func can_attack(who: int,uid: int) -> bool:
 var c=find_card(uid)
 return winner==-2 and pending.is_empty() and priority==who and active==who and phase=="main" and stack.is_empty() and combat.is_empty() and not c.is_empty() and c.owner==who and c.zone=="field" and is_unit(c) and not c.tapped and Cat.State.can_combat(self,c) and payment(who,attack_cost(who)).ways>0 and (not summoning_sick(c) or has_haste(c))
func attack(who: int,uid: int,target: Dictionary={},plan: Array=[]):
 if not can_attack(who,uid): return
 var c=find_card(uid)
 if not target.is_empty() and (not (Pack.direct_attack(self,c) or find_card(target.get("uid",-1)).has("rank_target")) or not target_valid(target,true) or find_card(target.uid).owner==who): return
 var required=attack_cost(who)
 if plan.is_empty():plan=payment(who,required).plan
 if not payment_valid(who,required,plan):return
 Cat.pay(self,who,plan)
 if DB.has_ability(cards[c.card_id],"brave") or Extra.keyword(self,c,"英勇"):c.brave_attack_turn=turn
 tap_card(c); c.attacked=true
 if target.is_empty():players[who].attacked_player_turn=turn
 combat={"attacker":ref_target(c),"owner":who,"blockers":[],"blocked":false,"step":"attack_window"}
 if not target.is_empty():
  combat.blockers=[target]; combat.blocked=true; combat.direct=true; c.skip_reset=true
 Pack.on_attack_or_block(self,c,true);Roster.on_attack(self,c)
 priority=1-who; passes=0; note("宣言攻击："+cards[c.card_id].name,history_art(c)); pump_choices()
func legal_blockers() -> Array:
 if combat.is_empty(): return []
 var attacker=find_card(combat.attacker.uid)
 if attacker.is_empty(): return []
 var result=[]
 for c in units(1-combat.owner):
  if c.tapped or not Cat.State.can_combat(self,c): continue
  if Cat.has(self,attacker,"character-fdn-035") and cards[c.card_id].kind!="自机":continue
  if Roster.enabled(self,attacker,"kogasa_boost") and c.get("scare",0)>0:continue
  if Roster.has(cards[attacker.card_id],"wriggle_evasion") and Pack.colors(self,c).any(func(color):return color in ["黑","绿"]):continue
  if Extra.keyword(self,attacker,"不能被阻挡"): continue
  if attacker.get("modifiers",[]).any(func(m): return m.get("不可阻挡颜色","") in Pack.colors(self,c)): continue
  if (DB.has_ability(cards[attacker.card_id],"exterminate") and has_leader_ability(attacker) or Extra.keyword(self,attacker,"退治")) and not Cat.race(self,c,"人类"): continue
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
 if chosen.is_empty() and not valid.is_empty() and Cat.has(self,find_card(combat.attacker.uid),"character-fdf-090"):return
 for c in chosen:
  if not Cat.enabled(self,c,"character-ucs-061:self"):tap_card(c)
  combat.blockers.append(ref_target(c));Pack.on_attack_or_block(self,c,false);Cat.Units.on_block(self,c)
 if not chosen.is_empty():Cat.Units.on_blocked(self,find_card(combat.attacker.uid))
 combat.blocked=not chosen.is_empty(); combat.step="block_window"
 pending={}; priority=active; passes=0
 note("不阻挡" if chosen.is_empty() else "宣言阻挡 · %d 个单位" % chosen.size()); pump_choices()
func advance_combat():
 if not target_valid(combat.attacker,true): end_combat(); return
 var surviving=combat.blockers.filter(func(t): return target_valid(t,true))
 if combat.blocked and surviving.is_empty(): end_combat(); return
 combat.blockers=surviving
 match combat.step:
  "attack_window":
   if combat.get("direct",false): combat.step="block_window"; priority=active; passes=0; revision+=1; return
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
  if deals_combat_damage(attacker): combat_hit(attacker,{"player":1-combat.owner},stat(attacker,"spirit"))
 else:
  var retaliation=0;var counter_power={}
  for r in combat.blockers:
   var b=find_card(r.uid);counter_power[b.uid]=stat(b,"power") if deals_combat_damage(b) else 0
  for t in combat.blockers:
   var blocker=find_card(t.uid)
   var amount=power if combat.blockers.size()==1 else int(allocation.get(str(t.uid),0)) if power>0 else 0
   var dealt=combat_hit(attacker,t,amount)
   var counter_damage=combat_hit(blocker,combat.attacker,counter_power[blocker.uid])
   retaliation+=counter_damage
   if dealt>0 and combat_exiles(attacker):
    Extra.event(self,attacker,"combat_exile_target",false,{"ref":t})
   if counter_damage>0 and combat_exiles(blocker):
    Extra.event(self,blocker,"combat_exile_target",false,{"ref":combat.attacker})
  if active==combat.owner and phase=="main" and (DB.has_ability(cards[attacker.card_id],"annihilate") or Extra.keyword(self,attacker,"歼灭")):
   if combat.blockers.any(func(t): return find_card(t.uid).damage>=stat(find_card(t.uid),"health") and not Extra.keyword(self,find_card(t.uid),"不会被消灭")):
    combat_hit(attacker,{"player":1-combat.owner},stat(attacker,"spirit"))
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
 # Lethal damage/death events precede putting combat triggers on the stack.
 # Youmu exiles only surviving field instances when her trigger resolves;
 # advance_combat rechecks those instances before ordinary damage (6.4.2a).
 note("战斗伤害结算"); judge(); pump_choices()
func end_combat():
 combat={}; priority=active; passes=0; revision+=1
func legal_casts(who: int,fast_only: bool=false) -> Array:
 var result=[]
 var options=players[who].hand.duplicate()
 options.append_array(players[who].grave.filter(func(c):return Roster.permission(self,c,who)))
 options.append_array((players[0].exile+players[1].exile).filter(func(c): return Pack.cast_from(self,c,who)))
 options.append_array(players[who].palette.filter(func(c):return Cat.State.permission(self,c,who)))
 options.append_array(players[who].deck.filter(func(c): return Extra.has(cards[c.card_id],"deck_damage") or Cat.State.permission(self,c,who)))
 for leader in leaders(who):
  if leader.zone=="leader":options.append(leader)
 for c in options:
  if fast_only and not Pack.fast(self,c,who): continue
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
   "effect_choice": choose_effect(Pack.ai_target(self,who,pending.options,pending.trigger.get("effect","")))
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
   if commit_cast(who,c.uid,target,payment(who,cast_cost(who,c,target)).plan).is_empty(): return
  for c in units(who):
   if can_attack(who,c.uid): attack(who,c.uid); return
 if ai_fast_action(who,choices): return
 pass_priority(who)
func ai_spell_target(who: int,c: Dictionary) -> Dictionary:
 if c.card_id=="character-fdf-046":return {"none":true,"mode":"不额外支付","extra_green":false}
 if Pack.has(cards[c.card_id],"byakuren_x"):
  var options=targets_for(c.card_id,who); options.reverse()
  for t in options:
   if payment(who,cast_cost(who,c,t)).ways>0: return t
  return {}
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
  if not Pack.fast(self,c,who): continue
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
  if commit_cast(who,c.uid,target,payment(who,cast_cost(who,c,target)).plan).is_empty(): return true
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
  if cards[permanent.card_id].kind=="符卡": continue
  for color in Pack.colors(self,permanent):
   if color not in colors: colors.append(color)
 for color in ["红","蓝","黄"]:
  if payment(who,{color:1}).ways>0: score+=10
  if payment(who,{color:2}).ways>0: score+=12
 var options=players[who].hand.duplicate()
 for leader in leaders(who):
  if leader.zone=="leader" and leader.timer==0:options.append(leader)
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
 if c.is_empty() or c.zone!="field" or not is_unit(c) or has_haste(c): return false
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
 if Pack.response_locked(self): return "该牌不能被响应"
 var c=find_card(uid)
 if c.is_empty() or c.owner!=who or c.zone!="field": return "需要操控该永久物"
 if Cat.State.activation_locked(self,c):return "该对象的启动能力被禁止"
 if Roster.Batch.locked(self,c):return "绵月丰姬：只能在自己的回合启动单位能力"
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
 if not extra.is_empty() and extra.key not in Roster.ACTIVATIONS:
  extra.enabled=extension_activation_error(who,c).is_empty()
  if extra.enabled or include_disabled: result.append(extra)
 for k in Roster.ACTIVATIONS:
  if not Roster.has(cards[c.card_id],k):continue
  var reason=extension_activation_error(who,c,k)
  if reason.is_empty() or include_disabled:result.append({"type":"extension","uid":uid,"key":k,"label":Roster.text(cards[c.card_id],k),"enabled":reason.is_empty(),"reason":reason})
 if c.zone!="field": return result
 if (Pack.direct_attack(self,c) or units(1-who).any(func(u):return u.has("rank_target"))) and not units(1-who).is_empty() and can_attack(who,c.uid):
  result.append({"type":"direct_attack","uid":uid,"label":"攻击对手单位","enabled":true})
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
 return Roster.filter_options(self,result,priority,false)

func commit_ability(who: int,uid: int,index: int,target: Dictionary,plan: Array) -> String:
 var error=activation_error(who,uid,index)
 if not error.is_empty(): return error
 var count=target.get("stackable_count",1)
 if not count is int or count<1:return "启动数量无效"
 var clean_target=target.duplicate(true);clean_target.erase("stackable_count")
 if clean_target not in ability_targets(): return "目标已失效"
 var params=ability_parameters(uid,index)
 var members=[find_card(uid)]
 if count>1:
  if not cards[members[0].card_id].get("stackable",false):return "该牌不能批量启动"
  members=stackable_members(members[0])
  if count>members.size():return "可启动数量不足"
  var first=find_card(uid);members.erase(first);members.push_front(first)
  members=members.slice(0,count)
  for member in members:
   if not activation_error(who,member.uid,index).is_empty():return "有对象不能启动"
 if not payment_valid(who,ability_cost(who,uid,index,target),plan): return "支付方案已失效"
 if params.get("横置",false) and plan.any(func(r):return members.any(func(member):return r.uid==member.uid)):return "不能重复横置同一来源"
 Cat.pay(self,who,plan)
 for member in members:
  if params.get("横置",false):tap_card(member)
  stack.append({"id":next_stack,"kind":"ability","source":member.duplicate(true),"owner":who,"amount":int(params["数值"]),"target":clean_target.duplicate(true),"name":cards[member.card_id].name+" · 启动异能"})
  stack.back().generic_activation=true
  stack.back().ability_text=cards[member.card_id].abilities[index].get("名称","对目标造成%d点伤害。" % int(params["数值"]))
  next_stack+=1
  Roster.on_ability_announced(self,stack.back());Roster.New.on_target(self,stack.back().target)
 passes=0; priority=1-who
 note("发动 "+cards[members[0].card_id].name+"的异能"+(" ×%d" % count if count>1 else ""))
 pump_choices()
 return ""

func field_slots(who: int) -> int:
 return units(who).filter(func(c): return not Extra.keyword(self,c,"不占战场格")).size()
func field_error(c: Dictionary,who: int) -> String:
 if is_unit(c):
  if field_slots(who)>=Cat.field_limit(self,who) and not Extra.keyword(self,c,"不占战场格"): return "单位战场格已满"
  for u in units(who):
   if u.uid!=c.uid and not cards[c.card_id].title.is_empty() and cards[u.card_id].title==cards[c.card_id].title: return "同称号单位已经在场"
 return ""
func offers_free_cast(who: int,c: Dictionary) -> bool:
 if c.is_empty():return false
 var previous=paid_cast_uid;paid_cast_uid=-1
 var offered=Roster.free_cast(self,c,who) or c.zone=="exile" and c.get("free_exile_owner",-1)==who
 paid_cast_uid=previous
 return offered and cards[c.card_id].cost.values().any(func(n):return n>0)
func set_granted_payment(pay_colors: bool):
 if pending.get("kind","")!="effect_choice" or pending.trigger.effect!="cat:grant":return
 var t=pending.trigger;var c=find_card(t.data.ref.uid)
 if c.is_empty():return
 paid_cast_uid=c.uid if pay_colors else -1
 var previous=forced_cast.duplicate(true)
 forced_cast={"owner":t.owner,"uid":c.uid,"free":t.data.free,"cost":t.data.cost,"ignore":false}
 pending.options=targets_for(c.card_id,t.owner,c.uid)
 if pending.options.is_empty() and cards[c.card_id].kind!="符卡":pending.options=Pack.none()
 forced_cast=previous
 t.data.payment_chosen=true
 revision+=1
func cast_cost(who: int,c: Dictionary,target: Dictionary={}) -> Dictionary:
 var cost=Pack.cost(self,c,who,cards[c.card_id].cost,target)
 var tax=Cat.target_tax(self,who,target)
 if tax>0:cost["红/蓝/绿/黄/黑"]=int(cost.get("红/蓝/绿/黄/黑",0))+tax
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
 if c.get("stack_copy",false) and c.zone=="stack" and zone!="field":detach(c);shift(c,"void");return
 if allow_replacement and c.zone=="grave" and zone=="hand" and not grave_replacement_sources(c).is_empty():
  if not zone_replacements.any(func(r): return r.target==ref_target(c)): zone_replacements.append({"target":ref_target(c)})
  return
 if zone=="grave" and c.card_id in ["new-eto-008","new-eto-010","new-eto-012"]:zone="outside"
 if zone=="grave" and (c.get("exile_on_grave",false) or c.card_id in ["new-loc-002","new-eto-005"]):zone="exile"
 var before=c.duplicate(true)
 var return_death_observers=[]
 if c.leader and offer_return and before.zone=="field" and zone=="grave":
  return_death_observers=(death_observers if not death_observers.is_empty() else units(0)+units(1)).duplicate(true)
 var from_top=c.zone=="deck" and not players[c.owner].deck.is_empty() and players[c.owner].deck[0].uid==c.uid
 detach(c)
 if before.zone=="field": Extra.on_leave(self,before)
 if c.get("token",false) and before.zone=="field":
  # Tokens still die and trigger death abilities, then cease to exist.
  if zone=="grave": Extra.on_death(self,c,before)
  present_move(c,zone);c.zone=zone;Roster.on_leave(self,before,c)
  shift(c,"void"); return
 if c.leader and before.zone!="leader" and offer_return and zone in ["hand","deck","grave","exile","palette"]:
  c.owner=c.get("original_owner",c.owner)
  c.return_death_observers=return_death_observers
  present_move(c,"return_pending");c.zone="return_pending"; c.epoch+=1; c.return_destination=zone; c.return_snapshot=before; returns.append(c); return
 var from_owner=c.owner
 c.owner=c.get("original_owner",c.owner)
 shift(c,zone)
 if not presentation_events.is_empty() and presentation_events.back().type=="move":presentation_events.back().card.owner=from_owner
 if zone not in ["leader","outside"]: players[c.owner][zone].append(c)
 if zone=="palette":Cat.State.on_palette(self,c);Roster.New.on_palette(self,c,before.zone)
 if from_top and zone=="grave":Cat.milled(self,c)
 if before.zone=="field" and zone=="grave": Extra.on_death(self,c,before)
 if before.zone=="field":Roster.on_leave(self,before,c)
func grave_replacement_sources(c: Dictionary) -> Array:
 if not is_unit(c) or c.zone!="grave" or not field_error(c,c.owner).is_empty(): return []
 if Cat.character(self,c,"藤原妹红") and not Cat.with_key(self,c.owner,"spell-fdn-001").is_empty():return Cat.with_key(self,c.owner,"spell-fdn-001")
 return units(c.owner).filter(func(u): return Extra.has(cards[u.card_id],"grave_return_replace") and has_leader_ability(u) and stat(c,"power")<=stat(u,"power"))
func choose_grave_replacement(to_field: bool):
 if pending.get("kind","")!="grave_replacement": return
 var target=pending.target; pending={}
 var c=find_card(target.uid)
 if not c.is_empty() and c.zone=="grave" and c.epoch==target.epoch:
  if to_field and not grave_replacement_sources(c).is_empty():
   var moon=Cat.character(self,c,"藤原妹红") and not Cat.with_key(self,c.owner,"spell-fdn-001").is_empty();detach(c);enter_field(c,c.owner)
   if moon and active==c.owner:c.tapped=true
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
 note(t.name+" · 触发能力",history_art(t.source))
 if not target.is_empty():accept_trigger(entry)
 return entry.id
func push_extended_trigger(t: Dictionary,target: Dictionary):
 push_trigger(t,target)
func complete_trigger_target(t: Dictionary,target: Dictionary):
 if pending.has("stack_id"):
  for entry in stack:
   if entry.id==pending.stack_id:
    entry.target=target.duplicate(true); entry.erase("awaiting_target");accept_trigger(entry); return
 else: push_trigger(t,target)
func choose_effect(target: Dictionary):
 if pending.get("kind","")!="effect_choice": return
 var t=pending.trigger
 if target.is_empty() and not t.optional: return
 var checked_target=target.duplicate(true);checked_target.erase("payment")
 if not target.is_empty() and not Pack.choice_valid(self,pending.options,checked_target): return
 if target.has("payment"):
  var cost=Cat.granted_cost(self,t,target) if t.effect=="cat:grant" else t.data.get("cost",{})
  if not payment_valid(t.owner,cost,target.payment):return
 record_declaration(t.owner,target,t.source)
 if t.get("continuation",false):
  pending={}
  var previous_context=damage_context;var previous_spell=resolving_spell
  if not target.is_empty():
   t.target=target;damage_context={"source":t.source,"combat":false,"single":Pack.single_damage_target(t)}
   resolving_spell=t.get("kind","")=="card" and cards[t.source.card_id].kind=="符卡"
   Extra.resolve_trigger(self,t)
  judge();damage_context=previous_context;resolving_spell=previous_spell
 else:
  if not target.is_empty(): complete_trigger_target(t,target)
  else:decline_stacked_trigger()
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
  if d.get("catalogue",false):
   if Cat.resolve_delay(self,d):delayed.erase(d)
   continue
  delayed.erase(d)
  if d.get("roster",false):Roster.event(self,d.source,d.effect,false);continue
  var c=find_card(d.ref.uid)
  if c.is_empty() or c.epoch!=d.ref.epoch or c.zone!=d.zone: continue
  var source=c.duplicate(true)
  if d.owner>=0: source.owner=d.owner
  var effect="token_sacrifice" if d.effect=="token_sacrifice" else "delayed_return"
  Extra.event(self,source,effect,false,d)
  if effect=="delayed_return" and not triggers.is_empty():
   triggers.back().ability_text="将 "+cards[c.card_id].name+" 在拥有者操控下移回战场。"
func add_timer(c: Dictionary,amount: int):
 Roster.Batch.counter(self,c,"timer",amount,c.owner)
 if amount>0 and c.zone in ["field","leader"]:
  for f in Cat.with_key(self,c.owner,"spell-fdf-017"):Cat.events(self,f,"cat:murder_dolls",true,{"amount":amount})
 if amount<=0 or c.zone not in ["field","leader"]:return
 for unit in units(0)+units(1):
  if Extra.has(cards[unit.card_id],"timer_replace") and has_leader_ability(unit):timer_changes.append({"owner":unit.owner,"ref":ref_target(c),"source":ref_target(unit),"source_name":cards[unit.card_id].name,"amount":amount})
func choose_timer(delta: int):
 if pending.get("kind","")!="timer" or delta not in [-1,0,1]: return
 var change=pending.change; var c=find_card(change.ref.uid)
 var source=find_card(change.get("source",{}).get("uid",0))
 if not source.is_empty() and source.epoch==change.source.epoch and Extra.has(cards[source.card_id],"timer_replace") and has_leader_ability(source) and change.amount>0 and not c.is_empty() and c.epoch==change.ref.epoch:
  c.timer=maxi(0,c.timer+delta)
  if delta!=0:note(change.source_name+" · 计时指示物 "+("+1" if delta>0 else "−1"),history_art(c))
 pending={}; judge(); revision+=1; pump_choices()
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
 return {"type":"extension","uid":c.uid,"label":labels.get(key,Pack.text(cards[c.card_id],key)),"key":key,"enabled":true}
func extension_activation_error(who: int,c: Dictionary,key: String="") -> String:
 if winner!=-2 or phase=="mulligan" or not pending.is_empty() or priority!=who or c.owner!=who or Pack.response_locked(self): return "当前不能发动"
 if Cat.State.activation_locked(self,c):return "该对象的启动能力被禁止"
 if Roster.Batch.locked(self,c):return "绵月丰姬：只能在自己的回合启动单位能力"
 if key.is_empty():key=Extra.activation_kind(cards[c.card_id])
 if key.is_empty(): return "没有该异能"
 if key in Roster.ACTIVATIONS:
  var reason=Roster.activation_error(self,c,key)
  if not reason.is_empty():return reason
 var zone="grave" if key in ["grave_return","grave_reanimate","spell-fdf-059","character-fdf-111"] else "field"
 if c.zone!=zone: return "区域不符"
 if key in Pack.ACTIVATIONS:
  var reason=Pack.activation_error(self,c,key)
  if not reason.is_empty(): return reason
 if key=="exile_grave" and (c.tapped or summoning_sick(c)): return "不能横置"
 if key=="leader_bounce" and (not has_leader_ability(c) or usage_count(c.uid,key)>0): return "本回合不能发动"
 if payment(who,Extra.activation_cost(key)).ways==0: return "费用不足"
 if Extra.activation_options(self,c,key).is_empty(): return "没有合法目标"
 return ""
func commit_extension(who: int,uid: int,target: Dictionary,plan: Array,key: String="") -> String:
 var c=find_card(uid)
 if c.is_empty(): return "牌已离开"
 if key.is_empty():key=Extra.activation_kind(cards[c.card_id])
 var error=extension_activation_error(who,c,key)
 if not error.is_empty(): return error
 var count=target.get("stackable_count",1)
 if not count is int or count<1:return "启动数量无效"
 var clean_target=target.duplicate(true);clean_target.erase("stackable_count")
 var members=[c]
 if count>1:
  if not can_batch_stackable_sacrifice(c,key):return "该牌不能批量牺牲"
  members=stackable_members(c)
  if count>members.size():return "可牺牲数量不足"
  members.erase(c);members.push_front(c)
  members=members.slice(0,count)
  for member in members:
   if not extension_activation_error(who,member,key).is_empty():return "有对象不能牺牲"
 var legal_options=Extra.activation_options(self,c,key)
 if not Pack.choice_valid(self,legal_options,clean_target): return "选择已失效"
 var target_spec={}
 for spec in legal_options:
  if spec.has("selection") and spec.selection.any(func(g):return g.get("cost",false)) and Pack.choice_valid(self,[spec],clean_target):target_spec=spec.duplicate(true);break
 if not payment_valid(who,extension_cost(who,c,key,target),plan): return "支付方案已失效"
 Cat.pay(self,who,plan)
 for member in members:
  record_declaration(who,clean_target,member)
  catalogue_serial+=1
  var source=member.duplicate(true)
  if key in Roster.ACTIVATIONS:Roster.pay_activation(self,member,key,clean_target)
  if key in Pack.ACTIVATIONS: Pack.pay_activation(self,member,key,clean_target)
  if key=="exile_grave": tap_card(member)
  if key=="grave_reanimate": move_to(find_card(clean_target.uid),"grave")
  if key=="sacrifice_buff": sacrifice(find_card(clean_target.uid))
  if key=="leader_bounce": use_once(member.uid,key)
  if key=="character-fdf-098":
   Cat.add_paired_mana(self,who,["黄","绿"]);revision+=1;return ""
  stack.append({"id":next_stack,"kind":"ability","activation":true,"effect":key,"source":source,"owner":who,"target":clean_target.duplicate(true),"name":cards[member.card_id].name})
  if not target_spec.is_empty():stack.back().target_spec=target_spec.duplicate(true)
  if key=="courage_die":
   stack.back().die=rng.randi_range(1,6);show_result("D6 · %d" % stack.back().die,member)
  if key in Roster.ACTIVATIONS:stack.back().ability_text=Roster.text(cards[member.card_id],key)
  if key in Pack.ACTIVATIONS: stack.back().ability_text=Pack.text(cards[member.card_id],key)
  if key=="laser": stack.back().ability_text="支付黄并移去一个计时指示物："+clean_target.mode+"。"
  Roster.on_ability_announced(self,stack.back());Roster.New.on_target(self,stack.back().target)
  next_stack+=1
 passes=0; priority=1-who; note("发动 "+cards[c.card_id].name+(" ×%d" % count if count>1 else "")); judge(); pump_choices()
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
  if cards[c.card_id].kind=="符卡" and not Extra.has(cards[c.card_id],"timed_life") and not ("时符" in cards[c.card_id].get("spell_type","") or "乐章" in cards[c.card_id].get("spell_type","")): return "该符卡不能留在战场"
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
   c.timer=int(cards[c.card_id].get("time",0));replace_melody(c,true)
 passes=0
 note("调试移动："+cards[c.card_id].name+" → "+{"deck":"牌库","hand":"手牌","field":"战场","palette":"颜色盘","grave":"墓地","exile":"除外区","leader":"自机区"}[destination])
 revision+=1
 return ""

func spell_target_valid(id: String,target: Dictionary) -> bool:
 if not Roster.key(cards[id],Roster.SPELLS+Roster.UCS_SPELLS).is_empty():return Roster.target_survives(self,id,target)
 if not Pack.key(cards[id],Pack.SPELLS).is_empty(): return Pack.target_survives(self,id,target)
 if not Extra.valid(self,target): return false
 if id=="130": return target_valid(target,true) and stat(find_card(target.uid),"spirit")>=3
 if id=="139": return target_valid(target,true) and cards[find_card(target.uid).card_id].kind!="自机"
 return true

func ai_expanded_target(who: int,c: Dictionary,options: Array) -> Dictionary:
 if options.is_empty(): return {}
 var id=c.card_id
 var roster=Roster.key(cards[id],Roster.SPELLS+Roster.UCS_SPELLS)
 if not roster.is_empty():return Roster.ai_target(self,who,c,options)
 var effect=Pack.key(cards[id],Pack.SPELLS)
 if not effect.is_empty() or Pack.has(cards[id],"byakuren_x"): return Pack.ai_target(self,who,options,effect)
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
 for c in players[who].field:
  for a in available_actions(who,c.uid):
   if a.type!="extension" or a.key not in Roster.ACTIVATIONS or usage_count(c.uid,"ai_"+a.key)>0:continue
   if a.key in ["hatate_return","kaguya_end","clown_sweep"]:continue
   var target=Pack.ai_target(self,who,Extra.activation_options(self,c,a.key),a.key)
   if not target.is_empty() and commit_extension(who,c.uid,target,payment(who,extension_cost(who,c,a.key,target)).plan,a.key).is_empty():use_once(c.uid,"ai_"+a.key);return true
 for c in players[who].field+players[who].grave:
  if not extension_activation_error(who,c).is_empty(): continue
  var key=Extra.activation_kind(cards[c.card_id])
  if key in Pack.ACTIVATIONS:
   if key=="minoriko_untap" and not players[who].palette.any(func(p): return p.tapped): continue
   if key in ["letty_shield","wine_discount","medicine_return","standing_blast"] and combat.is_empty(): continue
   if key=="keine_devour": continue
   var options=Extra.activation_options(self,c,key)
   var target=Pack.ai_target(self,who,options,key)
   if not target.is_empty() and commit_extension(who,c.uid,target,payment(who,extension_cost(who,c,key,target)).plan).is_empty(): return true
   continue
  if key not in ["exile_grave","grave_return","grave_reanimate"]: continue
  if key in ["grave_return","grave_reanimate"] and (active!=who or phase!="main" or not stack.is_empty() or not combat.is_empty()): continue
  var choices=Extra.activation_options(self,c,key)
  if key=="exile_grave": choices=choices.filter(func(t): return find_card(t.uid).owner!=who)
  if choices.is_empty(): continue
  if commit_extension(who,c.uid,choices[0],payment(who,extension_cost(who,c,key,choices[0])).plan).is_empty(): return true
 return false

func can_sacrifice(c: Dictionary) -> bool:
 if c.is_empty() or c.zone!="field":return false
 return not (phase=="end" and c.get("token",false) and Cat.character(self,c,"半灵") and not Cat.with_key(self,c.owner,"spell-fdn-012").is_empty())
func sacrifice(c: Dictionary):
 if not can_sacrifice(c):return
 var before=c.duplicate(true);move_to(c,"grave");Cat.Units.on_sacrifice_or_exile(self,before)
 if is_unit(before):
  for u in players[before.owner].grave:
   if Cat.has(self,u,"spell-fdf-047") and units(before.owner).any(func(v):return Cat.character(self,v,"西行寺幽幽子")):Cat.events(self,u,"cat:sacrifice_recover",true)

func attack_cost(who: int) -> Dictionary:
 var n=Cat.with_key(self,1-who,"spell-ucs-031").size()
 return {"红/蓝/绿/黄/黑":n} if n>0 else {}
func extension_cost(who: int,c: Dictionary,key: String,target: Dictionary={}) -> Dictionary:
 var cost=Extra.activation_cost(key).duplicate();var tax=Cat.target_tax(self,who,target)
 if tax>0:cost["红/蓝/绿/黄/黑"]=int(cost.get("红/蓝/绿/黄/黑",0))+tax
 if can_batch_stackable_sacrifice(c,key):
  var count=maxi(1,int(target.get("stackable_count",1)))
  for color in cost:cost[color]=int(cost[color])*count
 return cost

func ability_cost(who: int,uid: int,index: int,target: Dictionary={}) -> Dictionary:
 var cost=ability_parameters(uid,index).get("费用",{}).duplicate();var tax=Cat.target_tax(self,who,target)
 if tax>0:cost["红/蓝/绿/黄/黑"]=int(cost.get("红/蓝/绿/黄/黑",0))+tax
 var count=maxi(1,int(target.get("stackable_count",1)))
 for color in cost:cost[color]=int(cost[color])*count
 return cost
func must_block() -> bool:
 if combat.is_empty():return false
 var c=find_card(combat.attacker.uid)
 return Cat.has(self,c,"character-fdf-090") and not legal_blockers().is_empty()

func activation_options(c: Dictionary,key: String) -> Array:return Extra.activation_options(self,c,key)
