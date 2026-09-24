extends RefCounted
## ETO / LOC / SPX: explicit contracts, independent of printed prose.
const SPELLS=["n21:SPX-006","n21:SPX-004","n21:LOC-004","n21:LOC-003","n21:LOC-002","n21:ETO-006","n21:ETO-004","n21:ETO-011","n21:ETO-012","n21:ETO-009","n21:ETO-010","n21:ETO-008","n21:ETO-007","n21:ETO-005"]
const SELF=["n21:ETO-001:self","n21:SPX-005:self","n21:SPX-003:self","n21:SPX-001:self","n21:LOC-001:self","n21:ETO-003:self","n21:ETO-002:self"]
const ACTIVATIONS=["n21:SPX-005:self","n21:gourd_reset","n21:gourd_counter","n21:frog_tap","n21:frog_counter"]
const CAPTIONS={"n21:frog_fire":"青蛙进场：对另一个目标单位造成等同于该青蛙攻击力的伤害。","n21:frog_search":"从牌库搜寻一张土著神「宝永四年ノ赤蛙」置于手牌，然后洗牌。","n21:suika_return":"未操控鬼衍生物：将以此法除外的萃香移回战场。","n21:drunk_bottom":"醉熏熏：将该单位置于拥有者牌库底。","n21:dream_copy":"复制使用的符卡两次，可以分别选择新的目标。","n21:event_without_recipient":"触发主要能力；没有原事件所涉及的对象或数值。"}
static func id(code):return "new-"+code.to_lower()
static func has(e,c,code):return not c.is_empty() and e.Roster.has(e.cards[c.card_id],"n21:"+code)
static func own(e,who,code):return e.players[who].field.filter(func(c):return has(e,c,code))
static func enabled(e,c,code):return has(e,c,code) and (not code.ends_with(":self") or e.has_leader_ability(c))
static func event(e,c,code,optional=false,data={}):e.Roster.event(e,c,"n21:"+code,optional,data)
static func choose(e,t,code,options,data={}):e.Cat.choose(e,t,"n21:"+code,options,data)
static func create(e,who,code,zone):
 var c=e.make_card(id(code),who,"outside");e.move_to(c,zone,false);return c
static func start(e):
 for who in range(2):
  var c=e.players[who].leader
  if has(e,c,"ETO-001:self"):
   var other=e.make_card(id("ETO-002"),who,"leader",true)
   e.players[who].extra_leaders=[other]
   e.note(e.player_names[who]+"的二重身置于自机区",e.history_art(other))
static func on_enter(e,c):
 var who=c.owner
 if c.card_id in [id("LOC-003"),id("ETO-006"),id("ETO-012")]:e.add_timer(c,e.cards[c.card_id].time)
 if has(e,c,"SPX-001"):e.Roster.plus(e,c,1+e.players[who].palette.filter(func(u):return not u.tapped).size(),who)
 for code in ["SPX-005","SPX-007","ETO-003","ETO-002"]:
  if has(e,c,code):event(e,c,code,code=="ETO-002")
 if e.is_unit(c):
  var frozen=e.players[who].get("n21_frozen_enter",{})
  if e.players[who].turns==frozen.get("turns",-1):tap_effect(e,c,frozen.owner)
  if e.Cat.race(e,c,"青蛙"):
   for source in e.players[who].get("n21_frog_fire",[]):
    if source.turn==e.turn:event(e,c,"frog_fire",false,{"ref":e.Pack.ref(e,c),"power":e.stat(c,"power")})
  if e.cards[c.card_id].kind=="自机":
   for road in own(e,who,"LOC-005"):
    if e.usage_count(road.uid,"n21:LOC-005")==0:
     e.use_once(road.uid,"n21:LOC-005");event(e,road,"LOC-005",false,{"entrant":c.card_id})
static func on_leave(e,before,_c):
 if has(e,before,"SPX-007"):event(e,before,"SPX-007")
static func on_death(e,_c,before):
 if enabled(e,before,"ETO-002:self"):event(e,before,"ETO-002:self")
static func on_cast(e,c,who,_old_zone):
 if has(e,c,"ETO-001"):event(e,c,"ETO-001")
 if e.cards[c.card_id].kind!="符卡":return
 var pending=e.players[who].get("n21_copies",[])
 for rule in pending.duplicate():
  if rule.turn!=e.turn:pending.erase(rule);continue
  if e.cards[c.card_id].name==e.cards[id("ETO-010")].name:continue
  pending.erase(rule)
  var entry=e.stack.filter(func(s):return s.kind=="card" and s.card.uid==c.uid)
  if not entry.is_empty():event(e,rule.source,"dream_copy",false,{"entry":entry[0].duplicate(true)})
 e.players[who].n21_copies=pending
static func on_target(e,target):
 var seen=[]
 for r in e.Pack.flatten(target):
  if not e.Cat.unit(e,r) or r.uid in seen:continue
  seen.append(r.uid);var c=e.find_card(r.uid)
  if enabled(e,c,"SPX-001:self"):event(e,c,"SPX-001:self",true,{"ref":e.Pack.ref(e,c)})
static func on_phase(e,phase):
 if phase=="prepare":
  for c in own(e,e.active,"ETO-006"):event(e,c,"ETO-006")
  for c in e.units(0)+e.units(1):c.n21_spirit=c.get("n21_spirit",[]).filter(func(m):return m.owner!=e.active or e.players[e.active].turns<m.until)
 if phase!="end":return
 for c in e.players[e.active].field.duplicate():
  if enabled(e,c,"SPX-003:self"):event(e,c,"SPX-003:self")
  if has(e,c,"ETO-012"):event(e,c,"ETO-012")
 for who in range(2):
  for c in e.players[who].exile.duplicate():
   if c.get("n21_suika_return",false) and not e.units(who).any(func(u):return u.get("token",false) and e.Cat.race(e,u,"鬼")):event(e,c,"suika_return",false,{"ref":e.Pack.ref(e,c)})
  for c in e.units(who):
   if c.get("drunk_counters",0)>0 and not c.get("n21_drunk_triggered",false):
    c.n21_drunk_triggered=true;event(e,c,"drunk_bottom",false,{"ref":e.Pack.ref(e,c)})
static func on_attack(e,c):
 if has(e,c,"LOC-001"):event(e,c,"LOC-001")
static func on_counter(e,c,n,placer):
 if n>0 and c.zone=="field" and placer==c.owner and enabled(e,c,"LOC-001:self"):event(e,c,"LOC-001:self")
static func on_tap(e,c):
 if not e.is_unit(c):return
 var source=e.damage_context.get("source",{})
 if source.is_empty() or source.owner==c.owner:return
 for timecard in own(e,source.owner,"LOC-003"):
  if e.usage_count(timecard.uid,"n21:LOC-003")==0:
   e.use_once(timecard.uid,"n21:LOC-003");event(e,timecard,"LOC-003")
static func tap_effect(e,c,who):
 var previous=e.damage_context
 e.damage_context={"source":{"owner":who,"card_id":id("LOC-002")},"combat":false}
 e.tap_card(c);e.damage_context=previous
static func on_palette(e,c,old_zone):
 if old_zone=="hand" and has(e,c,"ETO-S001"):event(e,c,"ETO-S001",true,{"ref":e.Pack.ref(e,c)})
static func stat(e,c,k):
 var n=int(c.get("drunk_counters",0))
 if has(e,c,"LOC-001") and k in ["power","spirit"]:n+=e.Cat.counter_total(e,[c])
 if k=="spirit":
  for m in c.get("n21_spirit",[]):n+=m.amount
 return n
static func cost(e,c,who,base):
 if "梦违" not in e.cards[c.card_id].get("keywords",[]):return base
 var n=2*e.units(who).filter(func(u):return enabled(e,u,"ETO-003:self")).size()
 return reduce_cost(e,who,base,n)
static func reduce_cost(e,who,base,n):
 var options=[base]
 for i in range(n):
  var next=[]
  for item in options:
   var found=false
   for color in item:
    if item[color]<=0:continue
    var candidate=item.duplicate();candidate[color]-=1;found=true
    if candidate not in next:next.append(candidate)
   if not found and item not in next:next.append(item)
  options=next
 var best=base;var score=1000000
 for item in options:
  var plan=e.payment(who,item)
  if plan.score<score:score=plan.score;best=item
 return best
static func trigger_options(e,t):
 if not t.effect.begins_with("n21:"):return null
 if t.get("continuation",false):return e.pending.get("options",[])
 var code=t.effect.trim_prefix("n21:");var who=t.owner;var C=e.Cat
 match code:
  "SPX-007","LOC-001:self":return e.Roster.pick(e,e.Pack.all_units(e),0,1,"目标单位",t.effect)
  "LOC-001":return e.Pack.all_units(e,who)
  "frog_fire":return e.Pack.all_units(e).filter(func(r):return r.uid!=t.source.uid)
  "SPX-005":return C.name_options(e)
  "LOC-005":
   var options=[{"none":true,"mode":"抓一张牌，然后弃一张牌"}]
   for r in e.Pack.all_units(e,who):var o=r.duplicate();o.mode="防避2";options.append(o)
   return options
  "ETO-003":
   var groups=[]
   var pool=e.players[who].deck.filter(func(c):return c.card_id in [id("ETO-007"),id("ETO-009"),id("ETO-011")])
   for label in ["置于手牌","置于墓地","横置放入颜色盘"]:groups.append(C.group(e,pool,0,1,label))
   return e.Pack.selection(groups,"n21:three_books")
  "ETO-002":
   var options=[]
   for n in range(own(e,who,"ETO-S001").size()+1):options.append({"none":true,"x":n,"mode":"牺牲%d个灵异珠"%n})
   return options
  "ETO-002:self":
   var pool=[]
   for c in e.leaders(who):
    if c.zone=="leader":
     for i in range(c.timer):var r=e.Pack.ref(e,c);r.counter="timer";r.counter_index=i;pool.append(r)
   return e.Roster.pick(e,pool,0,2,"移除计时指示物",t.effect)
  "ETO-012":return C.refs(e,(e.players[0].grave+e.players[1].grave).filter(func(c):return e.is_unit(c) and e.field_error(c,who).is_empty()))
  "LOC-003":
   var groups=[]
   for i in range(3):groups.append(e.Pack.group(e.Pack.all_units(e),1,1,"分配第%d点伤害"%[i+1]))
   return e.Pack.selection(groups,"distribution")
 return e.Pack.none()
static func valid_choice(e,t):
 if t.get("selection_id","").begins_with("n21:SPX-005:self"):
  return t.get("mode","")==("-3灵力" if t.selection_id.ends_with("-3") else "+3灵力")
 if t.get("selection_id","")!="n21:three_books":return true
 var names=[]
 for r in e.Pack.flatten(t):
  if not e.Cat.valid(e,r):return false
  var name=e.cards[e.find_card(r.uid).card_id].name
  if name in names:return false
  names.append(name)
 return true
static func resolve_trigger(e,t):
 if not t.effect.begins_with("n21:"):return false
 var code=t.effect.trim_prefix("n21:");var who=t.owner;var C=e.Cat;var a=t.target;var d=t.get("data",{});var p=e.players[who]
 var source=t.get("source",t.get("card",{}));var current=e.find_card(source.get("uid",-1))
 match code:
  "ETO-001":
   create(e,who,"ETO-S001","hand");create(e,who,"ETO-S001","hand")
   var options=[]
   for n in range(4):options.append({"none":true,"x":n,"mode":"洗入%d张灵异珠"%n})
   choose(e,t,"add_balls",options)
  "add_balls":
   for i in range(a.x):create(e,who,"ETO-S001","deck")
   e.shuffle(p.deck)
  "LOC-005":
   if a.mode=="防避2":
    if C.unit(e,a):e.Pack.shield(e,a,[2])
   else:
    e.draw(who);C.continued_move(e,t,p.hand,mini(1,p.hand.size()),1,"grave","弃一张牌")
  "SPX-007":
   var n=own(e,who,"SPX-007").size()
   for r in e.Pack.picked(a):
    if C.unit(e,r):
     var u=e.find_card(r.uid);var controller=u.owner;var health=maxi(0,e.stat(u,"health")-u.damage)
     var dealt=e.damage_target(r,n)
     if dealt>health:e.damage_target({"player":controller},dealt-health)
  "SPX-005":e.Roster.field_many(e,p.grave.filter(func(c):return e.cards[c.card_id].kind in ["结界","道具"] and e.cards[c.card_id].name==a.card_name),who)
  "SPX-003:self":C.token(e,who,"青蛙",4,4,2,["蓝","绿"],["不占战场格"])
  "SPX-001:self":
   if C.unit(e,d.ref):
    var c=e.find_card(d.ref.uid);var n=C.counter_total(e,[c])
    for i in range(n):C.token(e,who,"鬼",1,1,1,["红","黄"],["不占战场格"])
    e.move_to(c,"exile")
    if c.zone=="return_pending":c.n21_pending_suika_return=true
    elif c.zone=="exile":c.n21_suika_return=true
  "suika_return":
   if C.valid(e,d.ref) and not e.units(who).any(func(u):return u.get("token",false) and C.race(e,u,"鬼")):e.Roster.field_many(e,[e.find_card(d.ref.uid)],who)
  "drunk_bottom":
   if C.unit(e,d.ref):e.move_to(e.find_card(d.ref.uid),"deck")
  "LOC-001":
   if C.unit(e,a):e.Roster.Batch.counter(e,e.find_card(a.uid),"courage",3,who)
  "LOC-001:self":
   for r in e.Pack.picked(a):
    if C.unit(e,r):e.tap_card(e.find_card(r.uid))
  "LOC-003":
   var totals={}
   for r in e.Pack.flatten(a):
    if C.unit(e,r):totals[r.uid]=int(totals.get(r.uid,0))+1
   for uid in totals:e.damage_target(e.ref_target(e.find_card(uid)),totals[uid])
  "frog_fire":
   if C.unit(e,a):
    var frog=e.find_card(d.ref.uid) if C.unit(e,d.ref) else source
    e.damage_context.source=frog
    e.damage_target(a,e.stat(frog,"power") if C.unit(e,d.ref) else int(d.get("power",e.stat(source,"power"))))
  "frog_search":C.choose(e,t,"cat:move",C.pick(e,p.deck.filter(func(c):return c.card_id==id("SPX-004")),0,1,"搜寻赤蛙"),{"zone":"hand","shuffle":true})
  "ETO-006":e.players[1-who].life-=own(e,who,"ETO-S001").size()
  "ETO-012":
   if C.valid(e,a):e.Roster.field_many(e,[e.find_card(a.uid)],who)
  "ETO-S001":
   if C.valid(e,d.ref):
    var ball=e.find_card(d.ref.uid)
    if ball.zone=="palette" and e.field_error(ball,who).is_empty():
     e.Roster.field_many(e,[ball],who)
     if not p.deck.is_empty():e.move_to(p.deck[0],"palette")
  "ETO-003":
   for i in range(3):
    for c in C.selected(e,a,i):
     e.reveal_card(c);e.move_to(c,["hand","grave","palette"][i]);c.tapped=i==2
   e.shuffle(p.deck)
  "ETO-002":
   var balls=own(e,who,"ETO-S001")
   var count=clampi(int(a.get("x",0)),0,balls.size())
   var sacrificed=0
   for c in balls.slice(0,count):
    if not e.can_sacrifice(c):continue
    e.sacrifice(c)
    if c.zone!="field":sacrificed+=1
   for c in e.units(0)+e.units(1):e.damage_target(e.ref_target(c),sacrificed)
   e.damage_target({"player":1-who},sacrificed)
  "ETO-002:self":
   for r in e.Pack.picked(a):
    if C.valid(e,r):e.find_card(r.uid).timer=maxi(0,e.find_card(r.uid).timer-1)
  "train_search":
   for c in C.selected(e,a):e.Roster.field_many(e,[c],who)
   e.shuffle(p.deck)
   choose(e,t,"train_pay",C.pay_options(e,who,{"黄":2}),{"entry":d.entry,"cost":{"黄":2}})
  "train_pay":
   if a.pay:
    var plan=e.payment(who,{"黄":2})
    if plan.ways>0:C.pay(e,who,a.get("payment",plan.plan));copy_choose(e,t,d.entry,1)
  "dream_copy":copy_choose(e,t,d.entry,2)
  "copy_finish":
   var original=d.entry;var c=e.make_card(original.card.card_id,who,"stack");c.stack_copy=true;c.token=true
   for k in ["cast_x","paid_dolls","exiled_hand","ichirin_paid"]:
    if original.card.has(k):c[k]=original.card[k]
   var copy={"id":e.next_stack,"kind":"card","card":c,"owner":who,"target":C.retarget_result(a),"name":e.cards[c.card_id].name,"copy":true}
   e.next_stack+=1;e.stack.append(copy);on_target(e,copy.target);e.note("复制 · "+copy.name,e.history_art(c));e.priority=e.active;e.passes=0
   if d.remaining>1:copy_choose(e,t,original,d.remaining-1)
  "deer_name":
   for c in C.field(e).duplicate():
    if e.cards[c.card_id].kind in ["道具","结界"] and e.cards[c.card_id].name==a.card_name:e.destroy(c)
 return true
static func copy_choose(e,t,entry,n):choose(e,t,"copy_finish",e.Cat.retarget_options(e,entry),{"entry":entry,"remaining":n})
static func spell_options(e,card_id,who):
 var code=card_id.trim_prefix("new-").to_upper()
 if "n21:"+code not in SPELLS:return null
 match code:
  "ETO-004":return e.Pack.all_units(e)
  "LOC-002":return [{"player":1-who}]
  "ETO-011":
   if e.players[who].grave.any(func(c):return c.card_id==id("ETO-009")):return e.Roster.pick(e,e.Pack.all_units(e),0,1,"目标单位","n21:ETO-011")
  "ETO-008":
   var result=[];var spells=e.stack.filter(func(s):return s.kind=="card" and e.cards[s.card.card_id].kind=="符卡").map(func(s):return {"stack_id":s.id})
   for bits in range(1,8):
    var groups=[];var names=[]
    for i in range(3):
     if bits&(1<<i):groups.append(e.Pack.group(spells if i==2 else e.Pack.all_units(e),1,1,["横置单位","洗回牌库","反制符卡"][i]));names.append(["横置","洗回","反制"][i])
    for option in e.Pack.selection(groups,"n21:sea:"+str(bits)):option.mode="＋".join(names);option.title=option.mode;option.n21_modes=bits;result.append(option)
   return result
 return e.Pack.none()
static func spell_resolve(e,t):
 var code=t.card.card_id.trim_prefix("new-").to_upper()
 if "n21:"+code not in SPELLS:return false
 var C=e.Cat;var p=e.players[t.owner];var who=t.owner;var a=t.target;var c=t.card
 if e.cards[c.card_id].time>0:e.enter_field(c,who);return true
 var previous_spell=e.resolving_spell;e.resolving_spell=true
 match code:
  "SPX-006":choose(e,t,"train_search",C.pick(e,p.deck.filter(func(u):return u.card_id==id("SPX-007")),0,1,"搜寻废弃列车车厢"),{"entry":t.duplicate(true)})
  "SPX-004":
   p.n21_frog_fire=p.get("n21_frog_fire",[])+[{"turn":e.turn,"source":c.duplicate(true)}]
   e.delayed.append({"roster":true,"owner":who,"phase":"end","source":c.duplicate(true),"effect":"n21:frog_search"})
  "LOC-004":choose(e,t,"deer_name",C.name_options(e))
  "LOC-002":
   e.damage_target(a,4)
   for u in e.units(a.player):e.tap_card(u);e.Roster.freeze_next(e,u)
   e.players[a.player].n21_frozen_enter={"turns":e.players[a.player].turns+1,"owner":who}
  "ETO-004":
   if C.unit(e,a):e.damage_target(a,4)
   C.choose(e,t,"cat:move",C.pick(e,p.deck.filter(func(u):return has(e,u,"ETO-S001")),0,2,"搜寻灵异珠"),{"zone":"hand","shuffle":true})
  "ETO-007":
   create(e,who,"ETO-008","hand")
   if p.grave.any(func(u):return u.card_id==id("ETO-011")):e.gain_life(who,3)
  "ETO-009":
   create(e,who,"ETO-010","hand")
   if p.grave.any(func(u):return u.card_id==id("ETO-007")):
    e.draw(who,2);C.continued_move(e,t,p.hand,mini(1,p.hand.size()),1,"grave","弃一张牌")
  "ETO-011":
   create(e,who,"ETO-012","hand")
   if p.grave.any(func(u):return u.card_id==id("ETO-009")):
    for r in e.Pack.picked(a):
     if C.unit(e,r):C.buff(e,e.find_card(r.uid),-2,-2)
  "ETO-010":p.n21_copies=p.get("n21_copies",[])+[{"source":c.duplicate(true),"turn":e.turn}]
  "ETO-008":
   var bits=int(a.get("n21_modes",int(a.get("selection_id","0").get_slice(":",2))));var index=0
   for i in range(3):
    if not bits&(1<<i):continue
    for r in e.Pack.picked(a,index):
     if i==2:
      if C.valid(e,r):e.counter_entry(r.stack_id)
     elif C.unit(e,r):
      var u=e.find_card(r.uid)
      if i==0:e.tap_card(u);e.Roster.freeze_next(e,u)
      else:e.move_to(u,"deck");e.shuffle(e.players[u.original_owner].deck)
    index+=1
  "ETO-005":force_main_triggers(e,who)
 e.judge();e.resolving_spell=previous_spell
 e.move_to(c,"exile" if code in ["LOC-002","ETO-005"] else "grave")
 return true
static func activation_cost(key):return {"红":1,"绿":1} if key=="n21:gourd_reset" else {}
static func activation_error(e,c,key):
 if c.zone!="field" or not e.Roster.has(e.cards[c.card_id],key):return "没有该异能"
 if key.ends_with(":self") and not e.has_leader_ability(c):return "没有自机能力"
 if key=="n21:SPX-005:self" and e.usage_count(c.uid,key)>0:return "本回合已经发动"
 if key=="n21:gourd_counter" and c.tapped:return "道具已经横置"
 return ""
static func activation_options(e,c,key):
 var C=e.Cat;var who=c.owner
 match key:
  "n21:gourd_reset":return e.Pack.none()
  "n21:gourd_counter":return e.Pack.all_units(e,who)
  "n21:SPX-005:self":
   var result=[]
   for amount in [-3,3]:
    var options=e.Pack.selection([C.group(e,pick_kind(e,who,"结界"),1,1,"牺牲结界",true),e.Pack.group(e.Pack.all_units(e),1,1,"目标单位")],key+str(amount))
    for o in options:o.mode=("+3" if amount>0 else "-3")+"灵力";o.title=o.mode;result.append(o)
   return result
  "n21:frog_tap":return e.Pack.selection([C.group(e,e.units(who).filter(func(u):return u.uid!=c.uid),1,1,"牺牲其他单位",true),e.Pack.group(e.Pack.all_units(e),0,1,"横置目标单位")],key)
  "n21:frog_counter":
   var spells=e.stack.filter(func(s):return (s.kind=="ability" or e.cards[s.card.card_id].kind=="符卡") and e.Pack.flatten(s.target).any(func(r):return C.unit(e,r) and e.find_card(r.uid).owner==who and C.race(e,e.find_card(r.uid),"神"))).map(func(s):return {"stack_id":s.id})
   return e.Pack.selection([C.group(e,e.units(who).filter(func(u):return u.get("token",false) and C.race(e,u,"青蛙")),1,1,"牺牲青蛙衍生物",true),e.Pack.group(spells,1,1,"反制符卡或能力")],key)
 return []
static func pick_kind(e,who,kind):return e.players[who].field.filter(func(c):return e.cards[c.card_id].kind==kind)
static func pay_activation(e,c,key,t):
 if key=="n21:gourd_counter":e.tap_card(c)
 if key in ["n21:SPX-005:self","n21:frog_tap","n21:frog_counter"]:
  for u in e.Cat.selected(e,t):e.sacrifice(u)
 if key=="n21:SPX-005:self":e.use_once(c.uid,key)
static func resolve_activation(e,t):
 var C=e.Cat;var c=e.find_card(t.source.uid);var a=t.target;var who=t.owner
 match t.effect:
  "n21:gourd_reset":
   if not c.is_empty() and c.zone=="field" and c.epoch==t.source.epoch:c.tapped=false
  "n21:gourd_counter":
   if C.unit(e,a):
    var u=e.find_card(a.uid);u.n21_drunk_triggered=false
    e.Roster.Batch.counter(e,u,"drunk_counters",1,who)
  "n21:SPX-005:self":
   for r in e.Pack.picked(a,1):
    if C.unit(e,r):
     var u=e.find_card(r.uid);u.n21_spirit=u.get("n21_spirit",[])+[{"owner":who,"until":e.players[who].turns+1,"amount":-3 if a.mode.begins_with("-") else 3}]
  "n21:frog_tap":
   for r in e.Pack.picked(a,1):
    if C.unit(e,r):e.tap_card(e.find_card(r.uid))
  "n21:frog_counter":
   for r in e.Pack.picked(a,1):
    if C.valid(e,r):e.counter_entry(r.stack_id)
static func force_main_triggers(e,who):
 e.Roster.TriggerInventory.force(e,who)
