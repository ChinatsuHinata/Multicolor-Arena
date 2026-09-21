extends RefCounted
## Reviewed v0.10 card contracts. All choices stay inside the duel state machine.
const ACTIVATIONS=["standing_blast","watch_counter","minoriko_untap","letty_shield","laser","marisa_recover","yukari_active","keine_devour","wine_discount","medicine_return"]
const SPELLS=["ramp_one","ramp_two","cloud_modes","reveal_counter","scarlet_anthem","promise","shuffle_field","spirit_four","double_spark","laser","escape","meteor","barrier_base","dream_orbs","counter_three","palette_three","spread_damage","silent_spark","stardust","shoot_moon","spring","paranoid"]
static func has(info: Dictionary,key: String) -> bool:
 return info.get("abilities",[]).any(func(a): return a.get("实现")=="precon" and a.get("参数",{}).get("效果")==key)
static func key(info: Dictionary,keys: Array) -> String:
 for k in keys:
  if has(info,k): return k
 return ""
static func text(info: Dictionary,effect: String) -> String:
 for a in info.get("abilities",[]):
  if a.get("实现")=="precon" and a.get("参数",{}).get("效果")==effect: return a.get("名称","")
 return {"chase":"追击","old_city_heal":"掷一枚硬币，正面获得3点生命。","medicine_revive":"将该单位从你的墓地移回战场。","standing_palette":"将你颜色盘中的一张牌移回手牌。","watch_draw":"抓一张牌。","mike_return":"将等量牌从颜色盘移回手牌。","reimu_search":"搜寻一张黄色结界放进战场，然后洗牌。"}.get(effect,effect)
static func event(e,c: Dictionary,effect: String,optional: bool=false,data: Dictionary={}):
 if trigger_locked(e): return
 e.triggers.append({"precon":true,"extended":true,"owner":c.owner,"source":c.duplicate(true),"effect":effect,"optional":optional,"data":data.duplicate(true),"name":e.cards[c.card_id].name,"ability_text":text(e.cards[c.card_id],effect)})
static func trigger_locked(e) -> bool:
 return e.stack.any(func(s):return s.kind=="card" and has(e.cards[s.card.card_id],"silent_spark"))
static func response_locked(e,who: int=-1) -> bool:
 if who<0:who=e.priority
 return trigger_locked(e) or e.stack.any(func(s):return s.kind=="card" and s.owner!=who and e.Roster.has(e.cards[s.card.card_id],"gungnir"))
static func ref(e,c: Dictionary) -> Dictionary:
 var t=e.ref_target(c)
 if c.zone!="field" or not e.is_unit(c): t.zone=c.zone
 return t
static func refs(e,list: Array) -> Array: return list.map(func(c): return ref(e,c))
static func zone(e,who: int,z: String) -> Array: return refs(e,e.players[who][z])
static func all_units(e,who: int=-1) -> Array: return refs(e,e.units(0)+e.units(1) if who<0 else e.units(who))
static func objects(e,kinds: Array,who: int=-1) -> Array:
 var list=[]
 for p in range(2):
  if who>=0 and who!=p: continue
  list.append_array(e.players[p].field.filter(func(c): return e.cards[c.card_id].kind in kinds))
 return refs(e,list)
static func none() -> Array: return [{"none":true}]
static func group(pool: Array,minimum: int,maximum: int,title: String="",distinct_names: bool=false) -> Dictionary:
 return {"pool":pool,"min":minimum,"max":maximum,"title":title,"distinct_names":distinct_names}
static func selection(groups: Array,tag: String="") -> Array:
 for g in groups:
  if g.pool.size()<g.min: return []
 return [{"selection":groups,"selection_id":tag}]
static func picked(t: Dictionary,index: int=0) -> Array:
 return t.get("picks",[])[index] if t.get("picks",[]).size()>index else []
static func flatten(t: Dictionary) -> Array:
 var out=[]
 if t.has("picks"):
  for g in t.picks: out.append_array(g)
 elif t.has("parts"):
  for p in t.parts: out.append_array(flatten(p))
 elif not t.has("none"): out.append(t)
 return out
static func choice_valid(e,options: Array,t: Dictionary) -> bool:
 if t in options: return true
 if not t.get("picks") is Array: return false
 for spec in options:
  if not spec.has("selection") or spec.get("selection_id","")!=t.get("selection_id","") or spec.selection.size()!=t.picks.size(): continue
  var good=true; var all_seen=[]
  for i in range(spec.selection.size()):
   var g=spec.selection[i]; var list=t.picks[i]; var seen=[]; var names=[]
   if not list is Array or list.size()<g.min or list.size()>g.max: good=false; break
   for p in list:
    var identity=JSON.stringify(p)
    if p not in g.pool or identity in seen or identity in all_seen and g.get("exclude_previous",false): good=false; break
    seen.append(identity)
    if g.get("distinct_names",false):
     var c=e.find_card(p.get("uid",-1))
     if c.is_empty() or e.cards[c.card_id].name in names: good=false; break
     names.append(e.cards[c.card_id].name)
   all_seen.append_array(seen)
  if good: return true
 return false
static func name_is(info: Dictionary,name: String) -> bool:
 return info.name==name or name in info.get("aliases",[])
static func spark(info: Dictionary) -> bool: return name_is(info,"恋符「极限火花」")
static func role(info: Dictionary) -> bool: return info.kind=="符卡" and not info.requires_character.is_empty()
static func has_character(e,who: int,name: String) -> bool:
 return e.units(who).any(func(c): return e.cards[c.card_id].character==name)
static func colors(e,c: Dictionary) -> Array:
 if c.zone in ["field","palette"] and has(e.cards[c.card_id],"all_colors"): return e.COLORS.duplicate()
 var result=c.get("token_colors",e.cards[c.card_id].colors).duplicate()
 for color in c.get("color_counters",[]):
  if color not in result: result.append(color)
 return result
static func dynamic_keyword(e,c: Dictionary,k: String) -> bool:
 var info=e.cards[c.card_id]
 if k=="英勇" and c.zone=="field" and e.is_unit(c) and e.players[c.owner].field.any(func(u): return has(e.cards[u.card_id],"brave_aura")): return true
 if not e.has_leader_ability(c): return false
 if k=="退治" and (has(info,"byakuren_leader") or has(info,"reimu_leader")): return true
 if k=="疾行":
  if has(info,"flandre_direct"): return true
  if has(info,"reimu_leader"):
   return e.players[c.owner].palette.filter(func(p): return e.cards[p.card_id].requires_character=="博丽灵梦").size()>=3
 return false
static func fast(e,c: Dictionary,who: int) -> bool:
 if e.Roster.fast(e,c,who):return true
 var info=e.cards[c.card_id]
 if info.fast: return true
 if has(info,"shou_shield") and e.active!=who: return true
 if has(info,"bind_field") and has_character(e,who,"博丽灵梦"): return true
 return info.kind=="符卡" and e.players[who].field.any(func(u): return has(e.cards[u.card_id],"iku_flash"))
static func cast_from(e,c: Dictionary,who: int) -> bool:
 if e.Roster.permission(e,c,who):return true
 if c.zone!="exile": return false
 if c.get("free_exile_owner",-1)==who: return true
 return c.get("devour_owner",-1)==who and e.units(who).any(func(u): return has(e.cards[u.card_id],"keine_devour") and e.has_leader_ability(u))
static func chromatic(e,c: Dictionary,who: int) -> bool:
 if c.get("devour_owner",-1)==who and cast_from(e,c,who): return true
 if "极彩" in e.cards[c.card_id].get("keywords",[]): return true
 return e.cards[c.card_id].kind=="符卡" and e.units(who).any(func(u): return has(e.cards[u.card_id],"patch_chromatic") and e.has_leader_ability(u))
static func cost(e,c: Dictionary,who: int,base: Dictionary,target: Dictionary) -> Dictionary:
 if c.zone=="exile" and c.get("free_exile_owner",-1)==who: return {}
 var result=base.duplicate(); var info=e.cards[c.card_id]
 if not info.get("variable_cost","").is_empty(): result[info.variable_cost]=result.get(info.variable_cost,0)+int(target.get("x",0))*int(info.get("variable_multiplier",1))
 if has(info,"promise"):
  var leaders=e.units(who).filter(func(u): return e.cards[u.card_id].kind=="自机")
  if leaders.size()==2 and e.cards[leaders[0].card_id].name!=e.cards[leaders[1].card_id].name: result["黄"]=maxi(0,result.get("黄",0)-2)
 if spark(info):
  var n=e.players[who].field.filter(func(u): return has(e.cards[u.card_id],"shop_discount")).size()
  if n>0: result["黄"]=maxi(0,result.get("黄",0)-2*n)
 if role(info):
  for discount in e.players[who].get("wine",[]): result[discount]=maxi(0,result.get(discount,0)-1)
 result=e.Roster.cost(e,c,who,result)
 if chromatic(e,c,who):
  var amount=0
  for n in result.values(): amount+=int(n)
  result={"红/蓝/绿/黄/黑":amount}
 return result
static func spell_options(e,id: String,who: int) -> Variant:
 var info=e.cards[id]; var k=key(info,SPELLS); var units=all_units(e)
 if has(info,"byakuren_x"):
  var options=[]
  for x in range(e.source_resources(who).size()+1): options.append({"none":true,"x":x,"mode":"X = %d" % x})
  return options
 if k.is_empty(): return null
 match k:
  "cloud_modes": return e.Extra.add_mode(units,"造成2点伤害")+e.Extra.add_mode(units,"造成1点伤害，抓1张牌")
  "shuffle_field": return objects(e,["结界"])
  "spirit_four","escape","dream_orbs": return units
  "meteor","silent_spark": return e.ability_targets()
  "counter_three":
   return e.stack.filter(func(s): return s.kind=="card" and e.Extra.cost_value(e,s.card)<=3).map(func(s): return {"stack_id":s.id})
  "reveal_counter":
   var leader=e.cards[e.players[who].leader.card_id].character
   var reveal=e.players[who].hand.filter(func(c): return e.cards[c.card_id].requires_character==leader)
   var counters=e.stack.filter(func(s): return s.kind=="card" and (e.cards[s.card.card_id].kind=="道具" or role(e.cards[s.card.card_id]))).map(func(s): return {"stack_id":s.id})
   return selection([group(refs(e,reveal),1,1,"展示一张角色符卡"),group(counters,1,1,"反制目标")],k)
  "double_spark": return selection([group(e.ability_targets(),0,2,"选择至多两个目标")],k)
  "spread_damage":
   var count=e.players[who].field.filter(func(c): return e.cards[c.card_id].kind=="结界").size()
   return selection([group(e.ability_targets(),0,count,"按伤害1、2、3…的顺序选目标")],k)
  "palette_three": return selection([group(zone(e,1-who,"palette"),3,3,"选择三张颜色盘牌")],k)
  "shoot_moon": return selection([group(e.ability_targets(),0,1,"选择至多一个目标")],k)
  "spring":
   var options=[]
   for t in units:
    for color in e.COLORS:
     var p=t.duplicate(); p.color=color; options.append(p)
   return options
 return none()
static func continue_choice(e,t: Dictionary,effect: String,options: Array,data: Dictionary={},optional: bool=false):
 if options.is_empty(): return
 var continuation=t.duplicate(true); continuation.effect=effect; continuation.data=data; continuation.optional=optional; continuation.continuation=true; continuation.precon=true
 e.pending={"kind":"effect_choice","owner":t.owner,"trigger":continuation,"options":options}
 e.revision+=1
static func on_enter(e,c: Dictionary):
 var info=e.cards[c.card_id]
 if has(info,"byakuren_x"):
  c.plus_counters=int(c.get("cast_x",0)); event(e,c,"byakuren_x",false,{"x":c.plus_counters})
 for k in ["ramp_enter","sand_add","tewi_counters","shou_shield","kosuzu_destroy","yukari_blink","eirin_return","mike_swap","bind_field","castle_exile","marisa_search","seiran_exile","koakuma_palette","tokiko_search","patch_topthree"]:
  if not has(info,k): continue
  if k=="shou_shield" and e.active==c.owner: continue
  if k=="sand_add" and e.players[c.owner].palette.size()<8: continue
  event(e,c,k,k in ["tewi_counters","shou_shield","kosuzu_destroy","yukari_blink","marisa_search","seiran_exile","koakuma_palette","tokiko_search","mike_swap"])
static func on_leave(e,c: Dictionary):
 for permanent in e.players[0].field+e.players[1].field:
  permanent.lock_sources=permanent.get("lock_sources",[]).filter(func(r): return r.uid!=c.uid or r.epoch!=c.epoch)
 for r in c.get("castle_exiles",[]):
  var u=e.find_card(r.uid)
  if not u.is_empty() and u.zone=="exile" and u.epoch==r.epoch and e.field_error(u,u.owner).is_empty(): e.detach(u); e.enter_field(u,u.owner)
static func on_death(e,c: Dictionary,before: Dictionary):
 if has(e.cards[before.card_id],"larva_draw"): event(e,before,"larva_draw")
 for medicine in before.get("medicine",[]):
  if c.zone=="grave" and medicine.owner==c.owner: event(e,medicine.source,"medicine_revive",false,{"ref":ref(e,c)})
static func on_phase(e,phase: String):
 for c in e.players[e.active].field.duplicate():
  if phase=="prepare" and has(e.cards[c.card_id],"miyoi_wine"): event(e,c,"miyoi_wine")
  if phase=="end":
   for k in ["sanae_end","marisa_untap","patch_exchange"]:
    if has(e.cards[c.card_id],k): event(e,c,k,k=="patch_exchange")
static func on_cast(e,c: Dictionary,who: int,target: Dictionary):
 c.cast_x=int(target.get("x",0))
 if role(e.cards[c.card_id]): e.players[who].wine=[]
 if has(e.cards[c.card_id],"eirin_medicine") and e.has_leader_ability(c): event(e,c,"eirin_medicine")
static func on_attack_or_block(e,c: Dictionary,attack: bool):
 if has(e.cards[c.card_id],"tenshi_tap"): event(e,c,"tenshi_tap",true)
 if attack and has(e.cards[c.card_id],"oni_attack"): event(e,c,"oni_attack")
static func on_tap(e,c: Dictionary):
 c.tapped_turn=e.turn
 if c.zone!="field" or not e.is_unit(c): return
 for u in e.units(1-c.owner):
  if has(e.cards[u.card_id],"tenshi_ping") and e.has_leader_ability(u): event(e,u,"tenshi_ping",true)
static func reset_allowed(e,c: Dictionary) -> bool:
 if not e.Roster.reset_allowed(e,c):return false
 if c.get("skip_reset",false): c.skip_reset=false; return false
 return not c.get("lock_sources",[]).any(func(r): return e.Extra.valid(e,r))
static func base_stat(e,c: Dictionary,k: String) -> int:
 var n=int(c.get("base_override",{}).get(k,e.cards[c.card_id][k]))
 if c.zone=="field": n+=e.players[c.owner].field.filter(func(p): return has(e.cards[p.card_id],"brave_aura")).size()
 return n
static func ramp(e,who: int,n: int,tapped: bool=true):
 for i in range(n):
  if e.players[who].deck.is_empty(): break
  var c=e.players[who].deck[0]; e.move_to(c,"palette"); c.tapped=tapped
static func field_return(e,t: Dictionary,who: int=-1):
 if not e.Extra.valid(e,t): return
 var c=e.find_card(t.uid); var controller=c.owner if who<0 else who
 if not e.field_error(c,controller).is_empty(): return
 e.detach(c); c.owner=controller; e.enter_field(c,controller)
static func future_zone_ref(e,c: Dictionary,z: String) -> Dictionary:
 var r=ref(e,c); r.zone=z
 if c.zone=="return_pending": r.epoch+=1
 return r
static func blink(e,c: Dictionary,who: int):
 e.move_to(c,"exile")
 e.delayed.append({"owner":who,"phase":"prepare","effect":"return_exile","ref":future_zone_ref(e,c,"exile"),"zone":"exile"})
static func token(e,who: int,id: String):
 var c=e.make_card(id,who,"token"); c.token=true; e.enter_field(c,who)
static func trigger_options(e,t: Dictionary) -> Array:
 var who=t.owner; var k=t.effect
 if t.get("continuation",false): return e.pending.get("options",[])
 match k:
  "tewi_counters": return selection([group(all_units(e,who),0,3,"选择至多三个己方单位")],k)
  "shou_shield": return [{"player":who}]+all_units(e,who)
  "kosuzu_destroy": return objects(e,["结界","道具"])
  "eirin_return": return zone(e,who,"grave").filter(func(r): return e.cards[e.find_card(r.uid).card_id].kind=="符卡")
  "yukari_blink": return all_units(e).filter(func(r): return r.uid!=t.source.uid)
  "bind_field": return objects(e,["单位","自机","道具"])
  "castle_exile": return selection([group(objects(e,["单位"]),0,1,"选择至多一个非自机单位")],k)
  "sanae_end": return all_units(e,who)
  "tenshi_tap","tenshi_ping": return all_units(e)
  "marisa_untap":
   return selection([group(objects(e,["单位","自机","结界","道具"],who),0,2,"重置永久物")],"permanents")+selection([group(zone(e,who,"palette"),0,2,"重置颜色盘")],"palette")
  "scarlet_anthem": return zone(e,who,"grave").filter(func(r): return e.cards[e.find_card(r.uid).card_id].race.any(func(race): return race in ["吸血鬼","人类"]))
 return none()
static func resolve_trigger(e,t: Dictionary):
 var who=t.owner; var target=t.target; var data=t.get("data",{}); var c=e.find_card(t.source.uid)
 var original=not c.is_empty() and c.epoch==t.source.epoch and c.zone=="field"
 match t.effect:
  "ramp_enter": ramp(e,who,1)
  "sand_add":
   if original and e.players[who].palette.size()>=8: e.Roster.plus(e,c,2)
  "tewi_counters":
   for r in picked(target):
    if e.target_valid(r,true): var u=e.find_card(r.uid); e.Roster.plus(e,u,1)
  "shou_shield": shield(e,target,[999999],true)
  "kosuzu_destroy":
   if e.Extra.valid(e,target): e.destroy(e.find_card(target.uid))
  "eirin_return":
   if e.Extra.valid(e,target): e.move_to(e.find_card(target.uid),"hand")
  "yukari_blink":
   if e.Extra.valid(e,target): blink(e,e.find_card(target.uid),who)
  "bind_field":
   if original and e.Extra.valid(e,target):
    var u=e.find_card(target.uid); u.lock_sources=u.get("lock_sources",[])+[ref(e,c)]
  "castle_exile":
   if original:
    for r in picked(target):
     if e.Extra.valid(e,r):
      var u=e.find_card(r.uid); e.move_to(u,"exile")
      c.castle_exiles=c.get("castle_exiles",[])+[future_zone_ref(e,u,"exile")]
  "sanae_end":
   if e.target_valid(target,true): var u=e.find_card(target.uid); e.Roster.plus(e,u,1)
  "tenshi_tap":
   if e.target_valid(target,true): e.tap_card(e.find_card(target.uid))
  "tenshi_ping": e.damage_target(target,1)
  "marisa_untap":
   for r in picked(target):
    if e.Extra.valid(e,r): e.find_card(r.uid).tapped=false
  "larva_draw": e.draw(who,2)
  "byakuren_x": e.gain_life(who,int(data.get("x",0)))
  "chase":
   if original: c.tapped=false
  "oni_attack":
   if original: e.Roster.plus(e,c,2)
  "miyoi_wine": token(e,who,"token-fdf-128")
  "eirin_medicine": token(e,who,"token-ucs-093")
  "scarlet_anthem","medicine_revive": field_return(e,data.ref if t.effect=="medicine_revive" else target,who)
  "old_city_heal":
   var heads=e.flip_coin(who); e.note("旧都 · "+("正面" if heads else "反面"))
   if heads: e.gain_life(who,3)
  "marisa_search","reimu_search","tokiko_search":
   var pool=zone(e,who,"deck").filter(func(r):
    var u=e.find_card(r.uid); var info=e.cards[u.card_id]
    return spark(info) if t.effect=="marisa_search" else (info.kind=="结界" and "黄" in info.colors) if t.effect=="reimu_search" else (info.kind=="道具" and e.Extra.cost_value(e,u)==2))
   continue_choice(e,t,"search_resolve",selection([group(pool,0,1,"检索")],"search"),{"field":t.effect=="reimu_search"})
  "search_resolve":
   for r in picked(target):
    if e.Extra.valid(e,r):
     var u=e.find_card(r.uid); e.record_history("展示 · "+e.cards[u.card_id].name,e.history_art(u))
     if data.get("field",false): field_return(e,r,who)
     else: e.move_to(u,"hand")
   e.shuffle(e.players[who].deck); e.note("洗牌")
  "patch_exchange": continue_choice(e,t,"exchange_resolve",selection([group(zone(e,who,"hand"),1,1,"选择手牌"),group(zone(e,who,"palette"),1,1,"选择颜色盘")],"exchange"),{},true)
  "exchange_resolve":
   if picked(target,0).is_empty() or picked(target,1).is_empty(): return
   var a=picked(target,0)[0]; var b=picked(target,1)[0]
   if e.Extra.valid(e,a) and e.Extra.valid(e,b): e.move_to(e.find_card(a.uid),"palette"); e.move_to(e.find_card(b.uid),"hand")
  "seiran_exile":
   var pool=zone(e,who,"hand").filter(func(r): var u=e.find_card(r.uid); return e.cards[u.card_id].kind=="符卡" and "蓝" in e.cards[u.card_id].colors and e.Extra.cost_value(e,u)<=2)
   continue_choice(e,t,"seiran_resolve",selection([group(pool,0,1,"选择蓝色符卡")],"seiran"))
  "seiran_resolve":
   for r in picked(target):
    if e.Extra.valid(e,r): var u=e.find_card(r.uid); e.move_to(u,"exile"); u.free_exile_owner=who
  "koakuma_palette": continue_choice(e,t,"koakuma_resolve",selection([group(zone(e,who,"palette"),0,1,"送去墓地")],"koakuma"))
  "koakuma_resolve":
   for r in picked(target):
    if e.Extra.valid(e,r): e.move_to(e.find_card(r.uid),"grave"); ramp(e,who,1,false)
  "mike_swap": continue_choice(e,t,"mike_add",selection([group(zone(e,who,"hand"),0,2,"横置放入颜色盘")],"mike_add"))
  "mike_add":
   var n=0; var draw=false
   for r in picked(target):
    if e.Extra.valid(e,r):
     var u=e.find_card(r.uid); draw=draw or role(e.cards[u.card_id]); e.move_to(u,"palette"); u.tapped=true; n+=1
   if n>0: continue_choice(e,t,"mike_return",selection([group(zone(e,who,"palette"),n,n,"移回手牌")],"mike_return"),{"draw":draw})
  "mike_return":
   for r in picked(target):
    if e.Extra.valid(e,r): e.move_to(e.find_card(r.uid),"hand")
   if data.get("draw",false): e.draw(who)
  "patch_topthree":
   var top=refs(e,e.players[who].deck.slice(0,3))
   for r in top:
    var u=e.find_card(r.uid); e.record_history("展示 · "+e.cards[u.card_id].name,e.history_art(u))
   var spells=top.filter(func(r): return e.cards[e.find_card(r.uid).card_id].kind=="符卡")
   continue_choice(e,t,"patch_top_resolve",selection([group(spells,0,1,"选择一张符卡")],"topthree"),{"top":top})
  "patch_top_resolve":
   var chosen=picked(target)
   for r in chosen:
    if e.Extra.valid(e,r): e.move_to(e.find_card(r.uid),"hand")
   var bottom=[]
   for r in data.top:
    if e.Extra.valid(e,r): var u=e.find_card(r.uid); e.players[u.owner].deck.erase(u); bottom.append(u)
   e.shuffle(bottom); e.players[who].deck.append_array(bottom)
  "watch_draw": e.draw(who)
  "standing_palette":
   for r in picked(target):
    if e.Extra.valid(e,r): e.move_to(e.find_card(r.uid),"hand")

static func spell_resolve(e,entry: Dictionary) -> bool:
 var info=e.cards[entry.card.card_id]; var k=key(info,SPELLS)
 if k.is_empty(): return false
 var who=entry.owner; var t=entry.target
 e.resolving_spell=true
 match k:
  "ramp_one": ramp(e,who,1)
  "ramp_two": ramp(e,who,2)
  "promise": e.draw(who,3)
  "cloud_modes":
   e.damage_target(t,2 if t.mode=="造成2点伤害" else 1)
   if t.mode!="造成2点伤害": e.draw(who)
  "reveal_counter":
   for r in picked(t,1):
    if e.Extra.valid(e,r): e.counter_entry(r.stack_id)
  "shuffle_field":
   if e.Extra.valid(e,t):
    var c=e.find_card(t.uid); var owner=c.get("original_owner",c.owner)
    e.move_to(c,"deck"); e.shuffle(e.players[owner].deck)
  "spirit_four":
   if e.target_valid(t,true):
    e.apply_turn_buff(t,{"灵力":4})
    var c=e.find_card(t.uid)
    if e.cards[c.card_id].character=="博丽灵梦": e.gain_life(who,e.stat(c,"spirit"))
  "double_spark":
   for r in picked(t): e.damage_target(r,6)
  "spread_damage":
   var count=e.players[who].field.filter(func(c): return e.cards[c.card_id].kind=="结界").size()
   var amount=0
   for r in picked(t).slice(0,count): amount+=1; e.damage_target(r,amount)
  "silent_spark": e.unpreventable_turn=e.turn; e.damage_target(t,5)
  "meteor":
   e.damage_target(t,2)
   var leader=e.players[who].leader
   if leader.zone=="leader": leader.timer=maxi(0,leader.timer-1)
  "escape": shield(e,t,[3,3]); e.draw(who)
  "dream_orbs":
   var count=(e.players[0].palette+e.players[1].palette).filter(func(c): return role(e.cards[c.card_id])).size()
   e.damage_target(t,count*2)
  "counter_three":
   if e.stack.any(func(s): return s.id==t.get("stack_id",-1) and s.kind=="card" and e.Extra.cost_value(e,s.card)<=3): e.counter_entry(t.stack_id)
  "palette_three":
   for r in picked(t):
    if e.Extra.valid(e,r): e.move_to(e.find_card(r.uid),"grave")
  "barrier_base":
   for p in range(2):
    for c in e.units(p):
     var n=4 if p==who else 2
     c.base_override={"power":n,"health":n,"spirit":n}
  "stardust":
   for c in e.units(0)+e.units(1):
    var n=e.Extra.cost_value(e,c)
    e.damage_target(e.ref_target(c),3 if n<4 else 5 if n>4 else 0)
  "shoot_moon":
   for r in picked(t): e.damage_target(r,1)
   var n=e.players[who].grave.filter(func(c): return name_is(e.cards[c.card_id],info.name)).size()
   e.draw(who,n+1)
  "spring":
   if e.target_valid(t,true):
    var c=e.find_card(t.uid); c.color_counters=c.get("color_counters",[])+[t.color]; e.draw(who)
  "laser","paranoid","scarlet_anthem":
   if k=="scarlet_anthem":
    for c in (e.players[0].field+e.players[1].field).duplicate():
     if "乐章" in e.cards[c.card_id].get("spell_type",""): e.move_to(c,"grave")
   if e.enter_field(entry.card,who) and int(info.get("time",0))>0: e.add_timer(entry.card,info.time)
   e.resolving_spell=false; return true
 e.judge(); e.resolving_spell=false; e.to_grave(entry.card)
 return true

static func activation_kind(info: Dictionary) -> String: return key(info,ACTIVATIONS)
static func activation_cost(k: String) -> Dictionary:
 return {"黄":1} if k=="laser" else {"黄":2} if k=="yukari_active" else {}
static func activation_error(e,c: Dictionary,k: String) -> String:
 if c.zone!="field": return "需要操控该永久物"
 if k in ["marisa_recover","yukari_active","keine_devour"]:
  if k!="keine_devour" and not e.has_leader_ability(c): return "没有自机能力"
 if k=="yukari_active" and e.usage_count(c.uid,k)>0: return "本回合已经发动"
 if k=="minoriko_untap" and (c.tapped or e.summoning_sick(c)): return "不能横置"
 if k=="laser" and c.timer<=0: return "没有计时指示物"
 return ""
static func activation_options(e,c: Dictionary,k: String) -> Array:
 var who=c.owner
 match k:
  "minoriko_untap": return zone(e,who,"palette")
  "letty_shield","medicine_return": return all_units(e) if k=="medicine_return" else e.ability_targets()
  "laser": return e.Extra.add_mode(e.ability_targets(),"防避4")+e.Extra.add_mode(objects(e,["结界","道具"]),"消灭结界或道具")
  "yukari_active": return all_units(e,who)
  "standing_blast": return all_units(e)
  "watch_counter": return e.stack.filter(func(s): return s.kind=="ability" and (s.get("activation",false) or not s.get("extended",false) and s.has("amount") and "启动" in s.get("name",""))).map(func(s): return {"stack_id":s.id})
  "wine_discount": return [{"color":"蓝"},{"color":"黄"}]
  "keine_devour":
   if e.players[1-who].deck.is_empty(): return []
   return selection([group(all_units(e,who),1,1,"牺牲一个单位")],k)
  "marisa_recover":
   var spells=zone(e,who,"grave").filter(func(r): return e.cards[e.find_card(r.uid).card_id].kind=="符卡")
   for r in spells: r.choice_name=e.cards[e.find_card(r.uid).card_id].name
   var names=[]
   for r in spells:
    var name=e.cards[e.find_card(r.uid).card_id].name
    if name not in names: names.append(name)
   if names.size()<3 or spells.size()<4: return []
   var sparks=spells.filter(func(r):
    if not spark(e.cards[e.find_card(r.uid).card_id]): return false
    var other_names=[]
    for other in spells:
     if other.uid!=r.uid and other.choice_name not in other_names: other_names.append(other.choice_name)
    return other_names.size()>=3)
   var recovery=group(sparks,1,1,"移回一张极限火花"); recovery.exclude_previous=true
   return selection([group(spells,3,3,"除外三张不同名符卡",true),recovery],k)
 return []
static func pay_activation(e,c: Dictionary,k: String,t: Dictionary):
 if k=="minoriko_untap": e.tap_card(c)
 if k=="yukari_active": e.use_once(c.uid,k)
 if k=="laser": c.timer-=1
 if k in ["standing_blast","watch_counter","letty_shield","wine_discount","medicine_return"]: e.move_to(c,"grave")
 if k=="keine_devour":
  for r in picked(t): e.move_to(e.find_card(r.uid),"grave")
 if k=="marisa_recover":
  for r in picked(t): e.move_to(e.find_card(r.uid),"exile")
static func resolve_activation(e,entry: Dictionary):
 var t=entry.target; var who=entry.owner; var k=entry.effect
 match k:
  "minoriko_untap":
   if e.Extra.valid(e,t): e.find_card(t.uid).tapped=false
  "letty_shield": shield(e,t,[1,1,1,1,1])
  "laser":
   if t.mode=="防避4": shield(e,t,[4])
   elif e.Extra.valid(e,t): e.destroy(e.find_card(t.uid))
  "yukari_active":
   if e.target_valid(t,true): blink(e,e.find_card(t.uid),who)
  "standing_blast":
   if e.target_valid(t,true) and e.find_card(t.uid).get("tapped_turn",-1)==e.turn: e.damage_target(t,4)
   if has_character(e,who,"博丽灵梦"):
    continue_choice(e,entry,"standing_palette",selection([group(zone(e,who,"palette"),0,1,"移回手牌")],"standing"))
  "watch_counter":
   if e.Extra.valid(e,t): e.counter_entry(t.stack_id)
   if has_character(e,who,"博丽灵梦"): continue_choice(e,entry,"watch_draw",none(),{},true)
  "wine_discount": e.players[who].wine=e.players[who].get("wine",[])+[t.color]
  "medicine_return":
   if e.target_valid(t,true):
    var u=e.find_card(t.uid); u.medicine=u.get("medicine",[])+[{"owner":who,"source":entry.source.duplicate(true)}]
  "keine_devour":
   if not e.players[1-who].deck.is_empty():
    var u=e.players[1-who].deck[0]; e.move_to(u,"exile"); u.devour_owner=who
  "marisa_recover":
   for r in picked(t,1):
    if e.Extra.valid(e,r): e.move_to(e.find_card(r.uid),"hand")
static func shield(e,t: Dictionary,amounts: Array,next_damage: bool=false):
 if not e.target_valid(t): return
 var c=e.players[t.player] if t.has("player") else e.find_card(t.uid)
 for amount in amounts: c.wards=c.get("wards",[])+[{"amount":amount,"turn":e.turn,"next":next_damage}]
static func adjusted_damage(e,t: Dictionary,amount: int) -> int:
 var context=e.damage_context; var source=context.get("source",{}); var combat=context.get("combat",false)
 if not combat and not source.is_empty() and context.get("single",false):
  var info=e.cards[source.card_id]
  if info.kind in ["单位","自机"] or role(info): amount+=e.players[source.owner].field.filter(func(c): return has(e.cards[c.card_id],"furnace")).size()
 if e.unpreventable_turn==e.turn: return amount
 var c=e.players[t.player] if t.has("player") else e.find_card(t.uid)
 if not t.has("player"):
  if e.Extra.keyword(e,c,"防止伤害"): return 0
  if not combat and e.cards[c.card_id].kind=="自机" and e.players[c.owner].field.any(func(u): return has(e.cards[u.card_id],"paranoid")): return 0
 var wards=c.get("wards",[])
 for w in wards.duplicate():
  if amount<=0: break
  if w.turn!=e.turn: wards.erase(w); continue
  amount=maxi(0,amount-int(w.amount)); wards.erase(w)
 c.wards=wards
 return amount
static func on_damage(e,t: Dictionary,amount: int):
 if amount<=0: return
 if t.has("player") and amount>=3:
  for c in e.players[t.player].field:
   if has(e.cards[c.card_id],"old_city"): event(e,c,"old_city_heal")
 var context=e.damage_context; var source=context.get("source",{})
 if source.is_empty() or not context.get("combat",false): return
 var info=e.cards[source.card_id]
 if "追击" in info.get("keywords",[]) and source.owner==e.active and e.usage_count(source.uid,"chase")==0:
  e.use_once(source.uid,"chase"); event(e,source,"chase")
 var lifesteal=e.Roster.lifesteal(e,source)
 if lifesteal>0 and e.usage_count(source.uid,"lifesteal_%d" % e.next_damage_batch)==0:
  e.use_once(source.uid,"lifesteal_%d" % e.next_damage_batch); e.gain_life(source.owner,lifesteal)
 if t.has("player") and has(info,"reimu_search"): event(e,source,"reimu_search",true)
static func on_gain_life(e,who: int,amount: int):
 if amount<=0 or e.active!=who: return
 for c in e.players[who].field:
  if has(e.cards[c.card_id],"scarlet_anthem"): event(e,c,"scarlet_anthem",true)
static func state_checks(e):
 for c in (e.players[0].field+e.players[1].field).duplicate():
  var info=e.cards[c.card_id]
  if info.kind=="符卡" and "时符" in info.get("spell_type","") and c.timer<=0: e.move_to(c,"grave")
  elif has(info,"illusion_check") and not e.units(c.owner).any(func(u): return "铃仙" in e.cards[u.card_id].name): e.move_to(c,"exile")
static func direct_attack(e,c: Dictionary) -> bool:
 return has(e.cards[c.card_id],"flandre_direct") and e.has_leader_ability(c)
static func target_survives(e,id: String,t: Dictionary) -> bool:
 if not t.has("picks"): return e.Extra.valid(e,t)
 var k=key(e.cards[id],SPELLS)
 var targets=picked(t,1) if k=="reveal_counter" else flatten(t)
 return targets.is_empty() or targets.any(func(r): return e.Extra.valid(e,r))
static func single_damage_target(entry: Dictionary) -> bool:
 # Selecting a card to recover is not a second recipient of damage.
 var t=entry.target
 if entry.get("effect","")=="enter_grave_damage": return t.get("parts",[]).size()==2
 return flatten(t).size()==1
static func ai_target(e,who: int,options: Array,effect: String="") -> Dictionary:
 if options.is_empty(): return {}
 var beneficial=effect in ["tewi_counters","shou_shield","sanae_end","escape","spring","spirit_four","letty_shield","medicine_return","laser"]
 var harmful=effect in ["spread_damage","double_spark","silent_spark","meteor","dream_orbs","cloud_modes","shoot_moon","tenshi_ping","tenshi_tap","standing_blast","kosuzu_destroy","castle_exile","shuffle_field","bind_field"]
 var scores=func(t):
  if t.has("stack_id"):
   return 100 if e.stack.any(func(s): return s.id==t.stack_id and s.owner!=who) else -100
  var owner=t.get("player",-1)
  var value=0
  if t.has("uid"):
   var c=e.find_card(t.uid)
   if not c.is_empty(): owner=c.owner; value=e.Extra.cost_value(e,c)
  if harmful: return 100+value if owner==1-who else -100
  if beneficial: return 100+value if owner==who else -100
  return value+1
 var specs=options.filter(func(t): return t.has("selection"))
 if not specs.is_empty():
  var spec=specs[0]; var result={"selection_id":spec.get("selection_id",""),"picks":[]}; var seen=[]
  for g in spec.selection:
   var pool=g.pool.duplicate(); pool.sort_custom(func(a,b): return scores.call(a)>scores.call(b))
   var list=[]; var names=[]
   for r in pool:
    if list.size()>=g.max: break
    if r in seen and g.get("exclude_previous",false): continue
    if harmful and scores.call(r)<0 and list.size()>=g.min: continue
    if g.get("distinct_names",false):
     var name=e.cards[e.find_card(r.uid).card_id].name
     if name in names: continue
     # Keep one Spark for the recovery target.
     if effect=="marisa_recover" and spark(e.cards[e.find_card(r.uid).card_id]) and spec.selection[1].pool.size()==1: continue
     names.append(name)
    list.append(r)
   result.picks.append(list); seen.append_array(list)
  return result if choice_valid(e,options,result) else {}
 var list=options.duplicate(); list.sort_custom(func(a,b): return scores.call(a)>scores.call(b))
 if effect in ["counter_three","watch_counter"] and scores.call(list[0])<0: return {}
 return list[0]
