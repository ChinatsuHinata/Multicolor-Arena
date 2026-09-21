extends RefCounted
## v0.12: explicit contracts for the LOF/HTK card batch.
const ACTIVATIONS=["courage_ping","courage_die","tokiko_copy","mask_joy","mask_anger","mask_sorrow"]
const SPELLS=["peach_modes","fairy_rewrite","night_sakura","blue_flower","icicle_tide","emotions","angry_mask"]
const LEADERS=["sanae_miracle","courage_die","kokoro_self","tokiko_discount"]
static func has(e,c,k):return e.Roster.has(e.cards[c.card_id],k)
static func enabled(e,c,k):return has(e,c,k) and (k not in LEADERS or e.has_leader_ability(c))
static func counter_amount(e,c,n:int,placer:int) -> int:
 if n<=0 or c.zone!="field" or not e.is_unit(c) or c.owner!=placer:return n
 return n+e.units(placer).filter(func(u):return has(e,u,"sanae_counters")).size()
static func counter(e,c,k:String,n:int,placer:int):
 c[k]=int(c.get(k,0))+counter_amount(e,c,n,placer)
 e.Roster.New.on_counter(e,c,n,placer)
static func color_counter(e,c,color:String,placer:int):
 var list=c.get("color_counters",[]).duplicate()
 for i in range(counter_amount(e,c,1,placer)):list.append(color)
 c.color_counters=list
 e.Roster.New.on_counter(e,c,1,placer)
static func locked(e,c) -> bool:
 return e.is_unit(c) and e.active!=c.owner and (e.units(0)+e.units(1)).any(func(u):return has(e,u,"toyohime_lock"))
static func on_enter(e,c):
 if has(e,c,"lily_color"):e.Roster.event(e,c,"lily_color")
 if has(e,c,"larva_sacrifice"):e.Roster.event(e,c,"larva_sacrifice",true)
static func on_cast(e,c,who):
 if e.cards[c.card_id].kind=="道具":e.players[who].item_cast_turn=e.turn
 if e.Extra.keyword(e,c,"奇迹"):
  for u in e.units(who):
   if enabled(e,u,"sanae_miracle"):e.Roster.event(e,u,"sanae_miracle")
static func on_phase(e,phase):
 for c in e.players[e.active].field.duplicate():
  if phase=="prepare" and has(e,c,"kokoro_mood") and c.get("moods",[]).size()<3:e.Roster.event(e,c,"kokoro_mood",true)
  if phase=="end" and has(e,c,"night_sakura"):e.Roster.event(e,c,"night_sakura")
static func trigger_options(e,t) -> Variant:
 var who=t.owner
 match t.effect:
  "lily_color":return e.COLORS.map(func(color):return {"color":color,"mode":color})
  "sanae_miracle":return e.Roster.pick(e,e.Pack.all_units(e),0,1,"选择至多一个目标单位",t.effect)
  "larva_sacrifice":return e.Roster.refs(e,e.units(who).filter(func(u):return e.Roster.race(e,u,"妖精")))
  "night_sakura":return e.Roster.refs(e,e.players[who].grave.filter(func(u):return e.is_unit(u)))
  "kokoro_mood":return [{"player":1-who}]
 return null
static func resolve_trigger(e,t) -> bool:
 var who=t.owner;var aim=t.target;var data=t.get("data",{});var c=e.find_card(t.source.uid)
 var same=not c.is_empty() and c.zone=="field" and c.epoch==t.source.epoch
 match t.effect:
  "lily_color":
   if same:color_counter(e,c,aim.color,who)
  "sanae_miracle":
   for r in e.Pack.picked(aim):
    if e.Roster.unit(e,r):e.Roster.plus(e,e.find_card(r.uid),1,who)
   e.draw(who)
  "larva_sacrifice":
   var pool=e.Roster.refs(e,e.units(who).filter(func(u):return u.uid!=t.source.uid and e.Roster.race(e,u,"妖精")))
   e.Roster.continue_choice(e,t,"larva_feed",e.Roster.pick(e,pool,0,pool.size(),"选择牺牲的其他妖精"),{"ref":aim})
  "larva_feed":
   var n=0
   for r in e.Pack.picked(aim):
    if e.Roster.unit(e,r) and e.can_sacrifice(e.find_card(r.uid)):e.sacrifice(e.find_card(r.uid));n+=1
   if e.Roster.unit(e,data.ref):e.Roster.plus(e,e.find_card(data.ref.uid),n,who)
  "night_sakura":
   if e.Roster.valid(e,aim):e.Roster.field_many(e,[e.find_card(aim.uid)],who)
  "kokoro_mood":
   if same:
    var options=[]
    for mood in ["喜","怒","忧"]:
     if mood not in c.get("moods",[]):options.append({"mode":mood,"none":true})
    e.Roster.continue_choice(e,t,"mood_choose",options,{"controller":who},false,who if enabled(e,c,"kokoro_self") else aim.player)
  "mood_choose":
   if same:
    c.moods=c.get("moods",[])+[aim.mode]
    mask(e,data.controller,{"喜":"031","怒":"032","忧":"033"}[aim.mode])
  "emotion_pay":
   var payer=t.owner;var plan=[{"uid":aim.get("uid",-100-payer),"color":aim.get("color","")}] if aim.has("color") else []
   if e.stack.any(func(s):return s.id==data.id):
    if not e.payment_valid(payer,{"红/蓝/绿/黄/黑":1},plan):e.counter_entry(data.id)
    elif plan[0].uid<0:e.players[payer].potato=false
    else:e.tap_card(e.find_card(plan[0].uid))
   emotions(e,data.entry,data.remaining)
  _:return false
 return true
static func mask(e,who:int,suffix:String) -> Dictionary:
 var c=e.make_card("token-htk-"+suffix,who,"token")
 return c if e.enter_field(c,who) else {}
static func spells(e) -> Array:
 return e.stack.filter(func(s):return s.kind=="card" and e.cards[s.card.card_id].kind=="符卡").map(func(s):return {"stack_id":s.id})
static func spell_options(e,id,who) -> Variant:
 var k=e.Roster.key(e.cards[id],SPELLS)
 match k:
  "peach_modes":return e.Extra.add_mode(e.Pack.all_units(e),"指示物翻倍")+[{"mode":"回复并抓牌","none":true},{"mode":"牌库顶放入颜色盘","none":true}]
  "fairy_rewrite","blue_flower":return spells(e)
  "night_sakura":return e.Pack.none()
  "icicle_tide":return e.Roster.pick(e,e.Pack.all_units(e),0,2,"选择至多两个单位",k)
  "angry_mask":return e.ability_targets()
  "emotions":
   var pool=e.Extra.add_mode(e.stack.filter(func(s):return s.kind=="card").map(func(s):return {"stack_id":s.id}),"反制，除非支付1点")
   pool.append_array(e.Extra.add_mode(e.Roster.refs(e,e.players[who].grave.filter(func(u):return e.is_unit(u) or e.cards[u.card_id].kind=="道具")),"移回手牌"))
   pool.append_array(e.Extra.add_mode(e.ability_targets(),"造成1点伤害"))
   var groups=[]
   for i in range(e.players[who].field.filter(func(u):return e.cards[u.card_id].kind=="道具").size()):groups.append(e.Pack.group(pool,0,1,"选择第 %d 项效果" % [i+1]))
   return e.Pack.selection(groups,k)
 return null
static func spell_resolve(e,entry) -> bool:
 var c=entry.card;var who=entry.owner;var aim=entry.target;var k=e.Roster.key(e.cards[c.card_id],SPELLS)
 if k.is_empty():return false
 match k:
  "night_sakura":
   if e.enter_field(c,who):e.add_timer(c,int(e.cards[c.card_id].time))
   return true
  "peach_modes":
   if aim.mode=="回复并抓牌":e.gain_life(who,3);e.draw(who)
   elif aim.mode=="牌库顶放入颜色盘":
    if not e.players[who].deck.is_empty():e.move_to(e.players[who].deck[0],"palette")
   elif e.Roster.unit(e,aim):
    var u=e.find_card(aim.uid)
    var amounts={}
    for key in e.Cat.COUNTER_KEYS:amounts[key]=int(u.get(key,0))
    var colors=u.get("color_counters",[]).duplicate()
    for key in amounts:
     if amounts[key]<=0:continue
     if key=="plus_counters":e.Roster.plus(e,u,amounts[key],who)
     elif key=="timer":e.add_timer(u,amounts[key])
     else:counter(e,u,key,amounts[key],who)
    for color in e.COLORS:
     var n=colors.count(color)
     if n>0:
      var list=u.get("color_counters",[])
      for i in range(counter_amount(e,u,n,who)):list.append(color)
      u.color_counters=list
  "fairy_rewrite":
   for s in e.stack:
    if s.id==aim.stack_id:s.rewritten_fairy=true;s.target={"none":true};s.ability_text="你创造一个蓝绿双色的3/3与灵力3且不计战场格的妖精衍生物。"
  "blue_flower":
   for s in e.stack.duplicate():
    if s.id==aim.stack_id:
     var u=s.card;e.move_to(u,"deck")
     if u.zone=="deck":e.players[u.owner].deck.erase(u);e.players[u.owner].deck.insert(mini(2,e.players[u.owner].deck.size()),u)
  "icicle_tide":
   var n=1
   for u in e.units(who):n+=int(u.get("courage",0))
   for r in e.Pack.picked(aim):
    if e.Roster.unit(e,r):e.damage_target(r,n);e.tap_card(e.find_card(r.uid))
  "angry_mask":
   var factor=2 if e.Pack.has_character(e,who,"秦心") else 1
   for i in range(factor):mask(e,who,"032")
   e.damage_target(aim,factor*e.players[who].field.filter(func(u):return e.cards[u.card_id].kind=="道具").size())
  "emotions":emotions(e,entry,e.Pack.flatten(aim))
 e.move_to(c,"grave")
 return true
static func emotions(e,entry,remaining:Array):
 e.damage_context={"source":entry.card,"single":e.Pack.single_damage_target(entry),"combat":false}
 var list=remaining.duplicate(true)
 while not list.is_empty():
  var t=list.pop_front()
  if t.get("mode","")=="移回手牌":
   if e.Roster.valid(e,t):e.move_to(e.find_card(t.uid),"hand")
  elif t.get("mode","")=="造成1点伤害":e.damage_target(t,1)
  elif t.has("stack_id"):
   for s in e.stack:
    if s.id==t.stack_id:
     e.Roster.continue_choice(e,entry,"emotion_pay",e.Roster.tax_options(e,s.owner),{"id":s.id,"entry":entry.duplicate(true),"remaining":list},false,s.owner)
     return
static func rewritten_resolve(e,entry):
 var id="mask_fairy_"+str(e.next_uid)
 e.cards[id]={"name":"妖精衍生物","kind":"单位","character":"妖精","title":"","race":["妖精"],"colors":["蓝","绿"],"cost":{},"power":3,"health":3,"spirit":3,"keywords":["不占战场格"],"abilities":[],"fast":false,"requires_character":"","rules_text":"不计战场格","token":true,"constructible":false}
 e.enter_field(e.make_card(id,entry.owner,"token"),entry.owner)
 var info=e.cards[entry.card.card_id]
 if "时符" in info.get("spell_type","") or "乐章" in info.get("spell_type",""):
  # Fairy Pilgrimage changes only this stack object. A time/melody spell
  # still enters normally and regains its printed abilities in the new zone.
  if e.enter_field(entry.card,entry.owner) and "时符" in info.spell_type and entry.card.card_id not in e.Cat.SPELLS and entry.card.timer==0:
   e.add_timer(entry.card,int(info.get("time",0)))
 else:e.move_to(entry.card,"grave")
static func activation_error(e,c,k) -> String:
 if not enabled(e,c,k):return "没有该异能"
 if k in ["courage_ping","tokiko_copy"] and (c.tapped or e.summoning_sick(c)):return "不能横置"
 if k=="courage_die" and c.get("courage",0)<2:return "勇气等级不足"
 return ""
static func activation_options(e,c,k) -> Array:
 match k:
  "courage_ping":return e.ability_targets()
  "courage_die","mask_joy","mask_anger":return e.Pack.all_units(e)
  "tokiko_copy":return e.Pack.objects(e,["道具"],c.owner)
  "mask_sorrow":
   var result=[]
   for who in range(2):
    var choices=e.Roster.pick(e,e.Pack.zone(e,who,"palette"),0,2,e.player_names[who]+"的颜色盘：至多两张","sorrow_"+str(who))
    result.append_array(choices)
   return result
 return []
static func pay_activation(e,c,k):
 if k in ["courage_ping","tokiko_copy"]:e.tap_card(c)
 if k=="courage_die":c.courage-=2
 if k in ["mask_joy","mask_anger","mask_sorrow"]:e.sacrifice(c)
static func resolve_activation(e,entry):
 var t=entry.target;var k=entry.effect;var who=entry.owner;var c=e.find_card(entry.source.uid)
 var same=not c.is_empty() and c.zone=="field" and c.epoch==entry.source.epoch
 match k:
  "courage_ping":
   if e.Roster.valid(e,t):
    e.damage_target(t,1)
    if same:counter(e,c,"courage",1,who)
  "courage_die":
   if e.Roster.unit(e,t):
    var n=int(entry.get("die",1));e.tap_card(e.find_card(t.uid));e.damage_target(t,n)
  "mask_joy":
   if e.Roster.unit(e,t):
    var u=e.find_card(t.uid);u.tapped=false;u.modifiers=u.get("modifiers",[])+[{"防止伤害":true}]
  "mask_anger":
   if e.Roster.unit(e,t):
    e.apply_turn_buff(t,{"灵力":2});var u=e.find_card(t.uid);u.modifiers=u.get("modifiers",[])+[{"歼灭":true}]
  "mask_sorrow":
   for r in e.Pack.picked(t):
    if e.Roster.valid(e,r):e.tap_card(e.find_card(r.uid))
   e.draw(who)
  "tokiko_copy":
   if e.Roster.valid(e,t):
    var src=e.find_card(t.uid);var id="mask_copy_"+str(e.next_uid);var info=e.cards[src.card_id].duplicate(true)
    info.token=true;info.constructible=false;info.copy_source_id=src.card_id;e.cards[id]=info
    var copy=e.make_card(id,who,"token")
    if e.enter_field(copy,who):e.delayed.append({"phase":"end","owner":-1,"ref":e.ref_target(copy),"zone":"field","effect":"token_sacrifice"})
static func cost(e,c,who,base:Dictionary) -> Dictionary:
 if e.active!=who or e.cards[c.card_id].kind!="道具" or e.players[who].get("item_cast_turn",-1)==e.turn:return base
 var n=2*e.units(who).filter(func(u):return enabled(e,u,"tokiko_discount")).size()
 if n==0:return base
 var candidates=[base]
 for i in range(n):
  var next=[]
  for cost in candidates:
   var found=false
   for color in cost:
    if cost[color]<=0:continue
    found=true;var copy=cost.duplicate();copy[color]-=1
    if copy not in next:next.append(copy)
   if not found and cost not in next:next.append(cost)
  candidates=next
 var best=base;var score=1000000
 for cost in candidates:
  var p=e.payment(who,cost)
  if p.score<score:score=p.score;best=cost
 return best
