extends RefCounted
## Explicit Excel contracts for the v0.13 catalogue. Card prose is never executed.
const CAPTIONS={"cat:element_reveal": "牌库顶展示：移除该牌，并选择是否使用。", "cat:flower_cast": "进入颜色盘：可以不支付颜色值使用本牌。", "cat:god_damage": "神子造成伤害：对至多一个目标玩家造成等量伤害。", "cat:hypnosis": "每位玩家弃一张牌，然后对手失去生命。", "cat:imp_growth": "攻击：放置两个+1/+1与+1指示物。", "cat:lie_damage": "硬币反面：对至多一个目标造成1点伤害。", "cat:murder_dolls": "放置计时指示物：对至多一个目标单位造成等量伤害。", "cat:night_timer": "对手单位死去：放置一个计时指示物。", "cat:nuclear_return": "自机单位进场：可以支付1红1黑将本牌从墓地移回手上。", "cat:rank_death": "该单位死去：失去3点生命。", "cat:rank_return": "自机单位攻击：将本牌从墓地移回手上。", "cat:sacrifice_recover": "牺牲单位：可支付1黄1黑抓牌并将本牌横置放入颜色盘。", "cat:tengu_watch": "对手本回合攻击过你：可以检索天狗放进战场。", "cat:top_free_damage": "从牌库顶进场：对目标其他单位造成等同于攻击力的伤害。", "cat:unconscious_return": "硬币反面：将本牌从墓地移回手上。", "cat:utsuho_return": "死去：在下个准备阶段将该牌移回战场。", "cat:delayed": "结算延迟触发效果。"}
const BOOST_COUNTERS=["plus_counters","drunk_counters","madness"]
const COUNTER_KEYS=["drunk_counters","plus_counters","minus_counters","leader_counters","courage","scare","poverty","timer","dream","madness"]
const Spells=preload("res://scripts/rules/catalogue_spells.gd")
const State=preload("res://scripts/rules/catalogue_state.gd")
const Units=preload("res://scripts/rules/catalogue_units.gd")
const ACTIVATIONS=["item-fdn-044","item-lof-009","item-ucs-017","item-fdf-096","item-ucs-013","item-htk-008","character-fdn-036:self","character-fdn-038","character-fdn-006","character-fdn-043","character-smm05","character-fdf-098","character-fdf-112","character-fdf-102","character-fdn-027","character-fdf-113","character-fdf-111","character-fdn-041","character-ucs-065:health","character-ucs-065:spirit","spell-fdn-032","spell-fdf-059","spell-fdn-019","token-fdf-127","token-fdf-129"]
const SPELLS=["spell-fdn-017", "spell-fdf-085", "spell-fdf-064", "spell-fdn-005", "spell-fdf-088", "spell-fdn-009", "spell-ucs-022", "spell-fdf-086", "spell-fdf-042", "spell-fdn-022", "spell-fdn-040", "spell-lof-006", "spell-fdf-044", "spell-fdf-005", "spell-fdf-120", "spell-htk-004", "spell-fdf-084", "spell-fdf-072", "spell-fdf-026", "spell-fdn-032", "spell-fdn-010", "spell-ucs-059", "spell-fdf-080", "spell-fdf-039", "spell-fdn-029", "spell-fdf-081", "spell-ucs-009", "spell-fdn-030", "spell-ucs-054", "spell-fdf-060", "spell-fdf-071", "spell-fdf-066", "spell-fdn-020", "spell-ucs-015", "spell-ucs-033", "spell-ucs-037", "spell-ucs-004", "spell-fdf-003", "spell-ucs-052", "spell-fdn-001", "spell-ucs-018", "spell-fdn-003", "spell-fdf-047", "spell-fdf-049", "spell-fdf-122", "spell-ucs-057", "spell-fdf-038", "spell-fdf-018", "spell-fdf-002", "spell-ucs-043", "spell-fdn-033", "spell-fdf-076", "spell-rec-056", "spell-kmo-003", "spell-fdn-008", "spell-fdf-037", "spell-fdn-031", "spell-fdf-017", "spell-fdf-059", "spell-fdn-046", "spell-fdn-023", "spell-rec-054", "spell-smm-002", "spell-fdf-055", "spell-soi-119", "spell-fdf-052", "spell-fdf-040", "spell-smm-003", "spell-rec-055", "spell-fdf-033", "spell-fdf-073", "spell-fdf-056", "spell-fdf-016", "spell-fdf-030", "spell-fdf-050", "spell-fdf-009", "spell-ucs-041", "spell-ucs-031", "spell-fdf-024", "spell-fdf-079", "spell-fdf-028", "spell-fdf-048", "spell-fdn-019", "spell-fdn-018", "spell-fdf-006", "spell-fdf-077", "spell-fdf-022", "spell-fdf-078", "spell-fdf-027", "spell-fdf-057", "spell-fdf-012", "spell-fdn-028", "spell-ucs-039", "spell-fdf-074", "spell-fdf-015", "spell-fdf-051", "spell-fdf-058", "spell-fdf-067", "spell-fdf-061", "spell-fdf-087", "spell-fdf-063", "spell-fdn-039", "spell-fdf-035", "spell-fdf-082", "spell-fdf-014", "spell-fdn-011", "spell-fdf-032", "spell-fdf-031", "spell-ucs-035", "spell-fdf-043", "spell-fdn-002", "spell-fdf-010", "spell-fdf-021", "spell-fdf-013", "spell-fdf-025", "spell-fdf-121", "spell-fdf-001", "spell-fdf-075", "spell-fdf-068", "spell-ucs-050", "spell-fdf-123", "spell-fdn-015", "spell-fdf-062", "spell-fdf-045", "spell-fdn-012", "spell-fdf-053", "spell-fdf-008"]
static func has(e,c,k):return not c.is_empty() and e.Roster.has(e.cards[c.card_id],k)
static func enabled(e,c,k):return has(e,c,k) and (not k.ends_with(":self") or e.has_leader_ability(c))
static func key(e,c):return e.Roster.key(e.cards[c.card_id],SPELLS)
static func field(e,who=-1):return e.players[0].field+e.players[1].field if who<0 else e.players[who].field
static func refs(e,list):return e.Roster.refs(e,list)
static func ref(e,c):return e.Pack.ref(e,c)
static func valid(e,r):return e.Roster.valid(e,r)
static func unit(e,r):return e.Roster.unit(e,r)
static func picked(e,t,n=0):return e.Pack.picked(t,n)
static func selected(e,t,n=0):return picked(e,t,n).filter(func(r):return valid(e,r)).map(func(r):return e.find_card(r.uid))
static func group(e,list,low,high,title,cost=false):
 var pool=refs(e,list.filter(func(c):return e.can_sacrifice(c)) if "牺牲" in title else list)
 var g=e.Pack.group(pool,0 if cost and e.catalogue_retargeting else low,high,title);g.cost=cost;return g
static func pick(e,list,low,high,title,tag=""):return e.Pack.selection([group(e,list,low,high,title)],tag)
static func character(e,c,name):
 var actual=e.cards[c.card_id].get("character","")
 return normalized(name) in normalized(actual)
static func normalized(s):return s.replace("·","").replace("・","").replace("洛","罗").replace("鵺","ぬえ").replace("隐崎","隐岐").replace("磷","燐").replace("伊","依").replace("洩","泄").replace("雷特","蕾特").replace("侘","诧")
static func role(e,c,name=""):
 var required=e.cards[c.card_id].get("requires_character","")
 return not required.is_empty() and (name.is_empty() or normalized(name) in normalized(required))
static func race(e,c,r):return e.Roster.race(e,c,r)
static func with_key(e,who,k):return field(e,who).filter(func(c):return enabled(e,c,k))
static func opponents():return [{"player":0},{"player":1}]
static func events(e,c,k,optional=false,data={}):e.Roster.event(e,c,k,optional,data)
static func choose(e,t,k,options,data={},owner=-1):
 e.Roster.continue_choice(e,t,k,options,data,false,owner)
 if not e.pending.is_empty() and e.pending.has("trigger") and not e.pending.trigger.has("ability_text"):
  e.pending.trigger.ability_text=t.get("ability_text",t.get("name",e.cards[t.get("source",t.get("card",{})).get("card_id",e.DB.IDS[0])].name))
static func buff(e,c,p=0,h=0,s=0,words=[]):
 var d={"攻击力":p,"血量":h,"灵力":s}
 for k in words:
  if k.begins_with("防避"):e.Pack.shield(e,e.ref_target(c),[int(k.trim_prefix("防避"))])
  else:d[k]=true
 e.apply_turn_buff(e.ref_target(c),d)
static func damage(e,t,n):return e.damage_target(t,n)
static func fight(e,a,b):
 if not unit(e,a) or not unit(e,b):return
 var x=e.find_card(a.uid);var y=e.find_card(b.uid);var xp=e.stat(x,"power");var yp=e.stat(y,"power");var context=e.damage_context
 e.damage_context={"source":x,"combat":false,"single":true};damage(e,b,xp)
 e.damage_context={"source":y,"combat":false,"single":true};damage(e,a,yp);e.damage_context=context
static func mill(e,who,n):
 var amount=mini(n,e.players[who].deck.size())
 for i in range(amount):e.move_to(e.players[who].deck[0],"grave")
static func random_discard(e,who,n):
 for i in range(mini(n,e.players[who].hand.size())):e.move_to(e.players[who].hand[e.rng.randi_range(0,e.players[who].hand.size()-1)],"grave")
static func token(e,who,name,p,h,s,colors,words=[],abilities=[],art=""):
 var id="catalogue_token_"+str(e.next_uid)
 var info={"name":name,"kind":"单位","character":name,"title":"","race":[name],"colors":colors,"cost":{},"power":p,"health":h,"spirit":s,"keywords":words,"abilities":abilities,"fast":false,"requires_character":"","rules_text":"、".join(words),"token":true,"constructible":false}
 if not art.is_empty():info.copy_source_id=art
 e.cards[id]=info;var c=e.make_card(id,who,"token")
 return c if e.enter_field(c,who) else {}
static func printed_token(e,who,id):
 var c=e.make_card(id,who,"token")
 if not e.enter_field(c,who):return {}
 return c
static func delay(e,c,effect="sacrifice",owner=-1,phase="end",data={}):
 e.delayed.append({"catalogue":true,"owner":owner,"phase":phase,"effect":effect,"ref":ref(e,c),"source":c.duplicate(true),"data":data})
static func resolve_delay(e,d):
 var c=e.find_card(d.ref.uid)
 if d.get("after_turn",-1)>=e.turn:return false
 if not c.is_empty() and c.epoch==d.ref.epoch:
  events(e,d.source,"cat:delayed",false,{"ref":d.ref,"op":d.effect,"data":d.get("data",{})})
 return true
static func reveal(e,list,from_top=true,edge=""):
 var order=list.duplicate()
 if edge=="bottom":order.reverse()
 for c in order:
  e.reveal_card(c,"top" if from_top and c.zone=="deck" else edge)
  if from_top and c.zone=="deck" and c.card_id in ["spell-fdf-075","spell-fdf-076","spell-fdf-077","spell-fdf-078","spell-fdf-079"]:events(e,c,"cat:element_reveal",true,{"ref":ref(e,c)})
static func continued_move(e,t,list,low,high,zone,title,after={},owner=-1):
 choose(e,t,"cat:move",pick(e,list,low,high,title),{"zone":zone,"after":after},owner)
static func continuation(e,t):
 var d=t.get("data",{});var aim=t.target;var who=t.owner
 match t.effect:
  "cat:move":
   var chosen=selected(e,aim)
   for c in chosen:
    if d.zone=="field":e.Roster.field_many(e,[c],d.get("controller",who),d.get("tapped",false))
    elif d.zone=="top":e.Roster.to_top(e,c)
    elif d.zone=="sacrifice":
      e.sacrifice(c)
    else:e.move_to(c,d.zone)
   if d.get("shuffle",false):e.shuffle(e.players[who].deck)
   if not d.get("after",{}).is_empty():
    var next=t.duplicate(true);next.effect=d.after.effect;next.data=d.after.duplicate(true);next.data.chosen=chosen;resolve_trigger(e,next)
  "cat:delayed":
   var c=e.find_card(d.ref.uid)
   if not c.is_empty() and c.epoch==d.ref.epoch:
    match d.op:
     "sacrifice":
      e.sacrifice(c)
     "hand","exile":e.move_to(c,d.op)
     "return":e.Roster.field_many(e,[c],who)
     "youmu_fight":choose(e,t,"cat:fight",e.Pack.all_units(e,1-who),{"ref":ref(e,c)})
  "cat:fight":forced_battle(e,d.ref,aim)
  "cat:distribution":
   var counts={}
   for r in e.Pack.flatten(aim):
    var k=str(r);counts[k]={"ref":r,"amount":int(counts.get(k,{}).get("amount",0))+1}
   for value in counts.values():
    if d.get("counter",false):
     if unit(e,value.ref):e.Roster.plus(e,e.find_card(value.ref.uid),value.amount,who)
    else:damage(e,value.ref,value.amount)
   if d.has("life"):e.players[who].life=d.life
  _:return false
 return true
static func distribution(e,t,pool,n,counter=false,life=-1):
 if n<=0 or pool.is_empty():
  if life>=0:e.players[t.owner].life=life
  return
 var groups=[]
 for i in range(n):groups.append(e.Pack.group(pool,1,1,"分配第 %d / %d 点" % [i+1,n]))
 var data={"counter":counter}
 if life>=0:data.life=life
 choose(e,t,"cat:distribution",e.Pack.selection(groups,"distribution"),data)
static func spell_options(e,id,who):
 var extra=extra_cast_options(e,id,who)
 return extra if extra!=null else Spells.options(e,id,who) if id in SPELLS else null
static func spell_resolve(e,t):
 if t.card.card_id not in SPELLS:return false
 var previous=e.resolving_spell;var result=Spells.resolve(e,t);e.resolving_spell=previous;return result
static func trigger_options(e,t):
 var choices=Units.options(e,t)
 if choices!=null:return choices
 return Spells.trigger_options(e,t)
static func resolve_trigger(e,t):
 return continuation(e,t) or Units.resolve(e,t) or Spells.resolve_choice(e,t)
static func on_enter(e,c):Units.on_enter(e,c)
static func on_leave(e,before,c):Units.on_leave(e,before,c)
static func on_death(e,c,before):Units.on_death(e,c,before)
static func on_phase(e,phase):Units.on_phase(e,phase)
static func on_cast(e,c,who,old_zone):Units.on_cast(e,c,who,old_zone)
static func on_attack(e,c):Units.on_attack(e,c)
static func activation_cost(k):return Units.activation_cost(k)
static func activation_error(e,c,k):return Units.activation_error(e,c,k)
static func activation_options(e,c,k):return Units.activation_options(e,c,k)
static func pay_activation(e,c,k,t):Units.pay_activation(e,c,k,t)
static func resolve_activation(e,t):Units.resolve_activation(e,t)
static func is_unknown(e,c):return e.cards[c.card_id].name=="不明物体" or has(e,c,"character-fdf-115")
static func counter_refs(e,list):
 var result=[]
 for c in list:
  for k in COUNTER_KEYS:
   for i in range(int(c.get(k,0))):var r=ref(e,c);r.counter=k;r.counter_index=i;result.append(r)
  for i in range(c.get("color_counters",[]).size()):var r=ref(e,c);r.counter="color_counters";r.counter_index=i;result.append(r)
 return result
static func counter_total(e,list):return counter_refs(e,list).size()
static func grant_cast(e,c,who,free=false,cost_override={}):
 e.forced_cast={"owner":who,"uid":c.uid,"free":free,"cost":cost_override,"ignore":false}
 var choices=e.targets_for(c.card_id,who,c.uid) if e.cards[c.card_id].kind=="符卡" else e.Pack.none()
 var old_priority=e.priority;e.priority=who
 var error=e.cast_error(who,c.uid);e.forced_cast={};e.priority=old_priority
 if choices.is_empty() or not error.is_empty():return
 var source={"owner":who,"source":c.duplicate(true),"effect":"cat:grant","name":e.cards[c.card_id].name,"optional":true}
 e.Roster.continue_choice(e,source,"cat:grant",choices,{"ref":ref(e,c),"free":free,"cost":cost_override,"ignore":false},true)
static func copy_unit(e,c,template,keep_name=false):
 var old=e.cards[c.card_id];var id="catalogue_copy_"+str(c.uid)+"_"+str(e.revision);var info=e.cards[template.card_id].duplicate(true)
 info.copy_source_id=template.card_id
 if keep_name:info.name=old.name;info.character=old.character;info.title=old.title
 c.copy_original=c.get("copy_original",c.card_id);e.cards[id]=info;c.card_id=id
static func copy_token(e,who,template,copy_counters=false):
 var id="catalogue_clone_"+str(e.next_uid);var info=e.cards[template.card_id].duplicate(true);info.token=true;info.constructible=false;info.copy_source_id=template.card_id;e.cards[id]=info
 var c=e.make_card(id,who,"token")
 if not e.enter_field(c,who):return {}
 if copy_counters:c.plus_counters=int(template.get("plus_counters",0))
 return c
static func copy_spell(e,t,x=-1,copy_menu=false):
 var source=t.get("card",t.get("source",{}));var c=e.make_card(source.card_id,t.owner,"stack");c.stack_copy=true;c.token=true;c.cast_x=int(source.get("cast_x",0)) if x<0 else x
 e.catalogue_x_override=maxi(0,x)
 var choices=retarget_options(e,t,x);e.catalogue_x_override=0
 for property in ["paid_dolls","exiled_hand","ichirin_paid"]:
  if source.has(property):c[property]=source[property]
 var wrapper=t.duplicate(true);wrapper.source=source
 var data={"card":c}
 if copy_menu:
  data.copy_menu_entry=t.duplicate(true)
  choices.append({"none":true,"mode":"返回","copy_back":true})
 if t.get("rewritten_fairy",false):data.rewritten_fairy=true
 choose(e,wrapper,"cat:spell_copy",choices,data)
static func name_options(e):
 var names=[];var pool=[]
 for id in e.DB.IDS:
  var name=e.cards[id].name
  if name not in names:names.append(name);pool.append({"card_name":name,"mode":name,"none":true})
 return pool
static func rename(e,c,name):
 var id="catalogue_rename_"+str(c.uid)+"_"+str(e.revision);var info=e.cards[c.card_id].duplicate(true);info.name=name;info.character=name;info.copy_source_id=c.card_id
 c.copy_original=c.get("copy_original",c.card_id);e.cards[id]=info;c.card_id=id
static func unknown(e,c):
 var old=e.cards[c.card_id];var id="catalogue_unknown_"+str(c.uid)+"_"+str(e.revision);var info=e.cards["token-fdf-131"].duplicate(true)
 info.colors=old.colors.duplicate();info.cost=old.cost.duplicate();info.token=c.get("token",false);info.copy_source_id="token-fdf-131"
 c.copy_original=c.get("copy_original",c.card_id);e.cards[id]=info;c.card_id=id
static func pay_options(e,who,cost):return [{"none":true,"mode":"支付费用","pay":true},{"none":true,"mode":"不支付","pay":false}] if e.payment(who,cost).ways>0 else [{"none":true,"mode":"不支付","pay":false}]
static func pay(e,who,plan):
 for r in plan:
  if r.uid<=-1000:e.players[who].mana=e.players[who].get("mana",[]).filter(func(m):return m.uid!=r.uid)
  elif r.uid<0:e.players[who].potato=false
  else:e.tap_card(e.find_card(r.uid))
static func add_mana(e,who,colors):
 var pool=e.players[who].get("mana",[])
 for color in colors:
  pool.append({"uid":-1000-e.next_uid,"colors":[color],"weight":0,"kind":"floating"});e.next_uid+=1
 e.players[who].mana=pool
static func remove_counters(e,list):
 var colors={}
 for r in list:
  if not valid(e,r):continue
  var c=e.find_card(r.uid)
  if r.counter=="color_counters":
   if not colors.has(c.uid):colors[c.uid]=[]
   colors[c.uid].append(r.counter_index)
  else:c[r.counter]=maxi(0,int(c.get(r.counter,0))-1)
 for uid in colors:
  var c=e.find_card(uid);var indexes=colors[uid];indexes.sort();indexes.reverse()
  for i in indexes:c.color_counters.remove_at(i)
static func enqueue(e,t):
 var who=t.owner;var c=t.source
 if e.stack.any(func(s):return s.kind=="card" and s.owner!=who and e.Roster.has(e.cards[s.card.card_id],"gungnir")):return
 if t.get("effect","")=="field-ucs-064":
  var entering=e.find_card(t.data.ref.uid)
  if not entering.is_empty():
   t.ability_text="由 "+e.cards[entering.card_id].name+" 进场触发：\n"+t.get("ability_text","")
   t.name+=" · "+e.cards[entering.card_id].name
 if e.players[who].get("night_lock",-1)==e.turn:return
 if e.stack.any(func(s):return s.kind=="card" and has(e,s.card,"spell-fdn-008")):return
 if has(e,c,"character-fdn-045") and not e.units(who).any(func(u):return character(e,u,"爱丽丝")):return
 t.catalogue_serial=e.catalogue_serial
 if t.get("effect","") in ["character-htk-005","cat:nuclear_return","cat:god_damage","spell-fdf-123","character-ucs-044"]:
  var coalesced=false
  for queued in e.triggers:
   if queued.get("catalogue_serial",-1)==e.catalogue_serial and queued.source.uid==c.uid and queued.get("effect")==t.effect and (t.effect!="spell-fdf-123" or queued.data.get("milled_owner",-1)==t.data.get("milled_owner",-1)):
    coalesced=true
    if t.effect in ["cat:god_damage","spell-fdf-123"]:queued.data.amount+=t.data.amount
  if coalesced:return
 var count=1
 if e.catalogue_death_depth>0:
  var observers=field(e)+e.death_observers
  if observers.any(func(u):return has(e,u,"character-ucs-066")):return
  if who==e.catalogue_death_owner:count+=with_key(e,who,"spell-fdn-019").size()
 if "时符" in e.cards[c.card_id].get("spell_type",""):count+=with_key(e,who,"character-fdf-041").size()
 for i in range(count):e.triggers.append(t.duplicate(true))
static func field_limit(e,who):return 6+3*with_key(e,who,"character-ucs-053").size()
static func extra_cast_options(e,id,who):
 if id=="character-fdf-046":return [{"none":true,"mode":"不额外支付","extra_green":false},{"none":true,"mode":"额外支付1绿","extra_green":true}]
 if id=="spell-fdf-030":
  var spec=pick(e,e.players[who].hand.filter(func(u):return race(e,u,"人偶")),1,1,"弃置人偶代替颜色费用",id)
  for s in spec:s.pitch=true;s.selection[0].cost=true
  return spec+[{"none":true,"mode":"支付颜色费用"}]
 return null
static func paid_cast(e,c,t,controller=-1):
 var meta={};var id=c.card_id;var who=c.owner if controller<0 else controller
 if id in ["spell-fdf-025","spell-fdn-046"]:
  var list=selected(e,t);e.shuffle(list);meta.paid_dolls=list.size()
  for u in list:e.move_to(u,"deck")
  if id=="spell-fdn-046":e.shuffle(e.players[who].deck)
 if id=="spell-fdf-048":
  var list=selected(e,t,1);meta.exiled_hand=list.size()
  for u in list:e.move_to(u,"exile")
 if id in ["spell-fdf-012","spell-fdf-072"] and t.has("picks"):
  for u in selected(e,t):e.sacrifice(u)
 if id=="spell-fdf-030" and t.get("pitch",false):
  for u in selected(e,t):e.move_to(u,"grave")
 if id=="spell-fdf-053":
  var counters=[]
  for i in range(1,t.picks.size()):counters.append_array(t.picks[i])
  remove_counters(e,counters)
 if id=="character-fdf-046":meta.ichirin_paid=t.get("extra_green",false)
 return meta
static func target_survives(e,id,t):
 if id in ["spell-fdn-046","spell-fdf-030","spell-fdf-072"] and t.has("picks"):return true
 var targets=e.Pack.flatten(t)
 if id=="spell-fdf-025":targets=picked(e,t,1)
 if id=="spell-fdf-048" or id=="spell-fdf-053":targets=picked(e,t)
 if id=="spell-fdf-012":
  targets=[]
  for i in range(1,t.get("picks",[]).size()):targets.append_array(t.picks[i])
 return targets.is_empty() or targets.any(func(r):return valid(e,r))
static func alternative_affordable(e,c,who):
 if c.card_id not in ["spell-fdf-030","spell-fdf-082","spell-fdf-053"]:return false
 for spec in e.targets_for(c.card_id,who,c.uid):
  if e.payment(who,e.cast_cost(who,c,spec)).ways>0:return true
 return false
static func extra_choice_valid(e,t):
 if not e.Roster.New.valid_choice(e,t):return false
 if t.get("selection_id","").begins_with("spell-fdf-012"):
  var counts={}
  for i in range(1,t.picks.size()):
   for r in t.picks[i]:
    var key=str(r);counts[key]=int(counts.get(key,0))+1
    if counts[key]>2:return false
 if t.get("selection_id","") in ["spell-ucs-057","spell-fdn-039"] and t.picks[0][0].uid==t.picks[1][0].uid:return false
 return true
static func forced_battle(e,a,b):
 if not e.combat.is_empty() or not unit(e,a) or not unit(e,b) or a.uid==b.uid:return
 e.combat_queue.append({"attacker":a,"owner":e.find_card(a.uid).owner,"blockers":[b],"blocked":true,"step":"block_window","forced":true})
static func target_tax(e,who,target):
 if not e.Pack.flatten(target).any(func(r):return unit(e,r) and e.find_card(r.uid).owner!=who and race(e,e.find_card(r.uid),"鬼")):return 0
 return 3*with_key(e,1-who,"spell-fdn-015").size()
static func may_peek(e,who):return not with_key(e,who,"character-ucs-068").is_empty() or not with_key(e,who,"character-fdn-071").is_empty()

static func milled(e,c):
 for u in field(e):
  if has(e,u,"spell-fdf-123"):events(e,u,"spell-fdf-123",true,{"amount":1,"milled_owner":c.owner})

static func retarget_options(e,entry,x=-1):
 var old=entry.target;var options=[]
 e.catalogue_retargeting=true
 if entry.kind=="card":options=e.targets_for(entry.card.card_id,entry.owner)
 elif entry.get("activation",false):options=e.Extra.activation_options(e,entry.source,entry.effect)
 elif entry.get("generic_activation",false):
  var previous=e.priority;e.priority=entry.owner;options=e.ability_targets();e.priority=previous
 else:options=e.trigger_options(entry)
 e.catalogue_retargeting=false
 var result=[]
 for option in options:
  if x>=0 and int(option.get("x",0))!=x:continue
  var matches=true
  for k in ["mode","x","ignore_color","pitch","counter_payment"]:
   if x>=0 and k in ["mode","x"]:continue
   if old.has(k) and option.get(k)!=old[k]:matches=false
  if not matches:continue
  var candidate=option.duplicate(true)
  if candidate.has("selection"):
   if not old.has("picks") or candidate.selection.size()!=old.picks.size():continue
   if x<0 and candidate.get("selection_id","")!=old.get("selection_id",""):continue
   var groups=[];var indexes=[]
   for i in range(candidate.selection.size()):
    if candidate.selection[i].get("cost",false):continue
    var g=candidate.selection[i];g.min=old.picks[i].size();g.max=old.picks[i].size()
    groups.append(g);indexes.append(i)
   candidate.selection=groups;candidate.retarget_indices=indexes;candidate.retarget_base=old.duplicate(true)
   if x>=0:candidate.retarget_base.x=x
  result.append(candidate)
 return result if not result.is_empty() else [old.duplicate(true)]
static func retarget_result(a):
 if not a.has("retarget_indices"):return a
 var result=a.retarget_base.duplicate(true)
 for i in range(a.retarget_indices.size()):result.picks[a.retarget_indices[i]]=a.picks[i]
 return result

static func granted_cost(e,t,target):
 var previous=e.forced_cast.duplicate(true);var c=e.find_card(t.data.ref.uid)
 if c.is_empty():return {}
 e.forced_cast={"owner":t.owner,"uid":c.uid,"free":t.data.free,"cost":t.data.cost,"ignore":false}
 var cost=e.cast_cost(t.owner,c,target);e.forced_cast=previous;return cost
