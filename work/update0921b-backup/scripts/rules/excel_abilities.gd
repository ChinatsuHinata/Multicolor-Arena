extends RefCounted
## v0.11 contracts transcribed from workbook rows. No ability executes from prose.
const Cat=preload("res://scripts/rules/catalogue_abilities.gd")
const Batch=preload("res://scripts/rules/mask_abilities.gd")
const ACTIVATIONS=["courage_ping","courage_die","tokiko_copy","mask_joy","mask_anger","mask_sorrow","hatate_return","hina_redirect","clown_sweep","satori_discard","alice_search","alice_recycle","kanako_blast","kaguya_end","suika_counter","sanae_search"]+Cat.ACTIVATIONS
const SPELLS=["peach_modes","fairy_rewrite","night_sakura","blue_flower","icicle_tide","emotions","angry_mask","fairy_revive","tengu_pair","leader_mark","kaleidoscope","grave_top","destroy_any","tap_all","discard_draw","gungnir","draw_x","activity","blink_two","sweep_three","history_exile","extra_turn","hand_army","counter_ability","counters_x","unblock_reset","lake_mill","waterfall","philosopher","two_bats","ghost_imp","destroy_item_field","exile_permanent","counter_targeting","gather_counters","bounce_small","steal_turn","search_leader","crimson_modes","quiet_modes","grave_palette","flower_damage","door_reveal","grace_reset","frogs_x","fire_scry","doll_army","tap_destroy","fairy_festival","perfect_freeze","memory_cast","palette_army","end_turn","untargetable","wheel_modes","cloud_attack","rest_life","snow_time","survivors","death_return"]+Cat.SPELLS
const LEADER=["sanae_miracle","courage_die","kokoro_self","tokiko_discount","koishi_evasion","remilia_aura","satori_discard","alice_recycle","cirno_return","kanako_blast","kaguya_end","yuuka_ramp","suika_counter","suwako_haste","komachi_coins","shinmy_counter","sanae_search"]
const UCS_SPELLS=["coin_anthem","free_anthem","all_counters","kill_small","palette_wipe","reset_four","color_damage"]
static func has(info: Dictionary,k: String) -> bool:
 return info.get("abilities",[]).any(func(a): return a.get("实现")=="roster" and a.get("参数",{}).get("效果")==k)
static func key(info: Dictionary,keys: Array) -> String:
 for k in keys:
  if has(info,k): return k
 return ""
static func text(info: Dictionary,k: String) -> String:
 if Cat.CAPTIONS.has(k):return Cat.CAPTIONS[k]
 k={"activity_draw":"activity","medicine_destroy":"medicine_kill","komachi_counters":"komachi_minus","komachi_coin":"komachi_coins","coin_damage":"coin_anthem","backpack_tax":"backpack","fairy_return":"fairy_festival"}.get(k,k)
 for a in info.get("abilities",[]):
  if a.get("实现")=="roster" and a.get("参数",{}).get("效果")==k: return a.get("名称","")
 return {"scry_grave":"选择送去墓地的牌","scry_order":"按顺序选择剩余牌（第一张在牌库顶）","search_take":"选择检索的牌","discard_choice":"选择要弃置的牌","nasrin_bottom":"选择一张手牌放在牌库底","mist_choose":"选择要放入战场的牌","grant_cast":"使用这张符卡","return_fairies":"将妖精单位移回手牌","nether_ghost":"创造一个亡灵衍生物","snow_damage":"对所有单位各造成1点伤害","time_draw":"抓一张牌，然后交换手牌与颜色盘"}.get(k,k)
static func enabled(e,c: Dictionary,k: String) -> bool:
 return has(e.cards[c.card_id],k) and (k not in LEADER+["kanako_ten","kogasa_boost","miko_discount"] or e.has_leader_ability(c))
static func event(e,c: Dictionary,k: String,optional: bool=false,data: Dictionary={}):
 if e.Pack.trigger_locked(e): return
 e.Cat.enqueue(e,{"roster":true,"extended":true,"owner":c.owner,"source":c.duplicate(true),"effect":k,"optional":optional,"data":data.duplicate(true),"name":e.cards[c.card_id].name,"ability_text":text(e.cards[c.card_id],k)})
static func continue_choice(e,entry: Dictionary,k: String,options: Array,data: Dictionary={},optional: bool=false,owner: int=-1):
 if options.is_empty(): return
 var t=entry.duplicate(true); t.roster=true; t.precon=false; t.extended=true; t.continuation=true; t.effect=k; t.data=data; t.optional=optional
 if not t.has("source"):t.source=t.card.duplicate(true)
 if owner>=0: t.owner=owner
 e.pending={"kind":"effect_choice","owner":t.owner,"trigger":t,"options":options}; e.revision+=1
static func pick(e,pool: Array,minimum: int,maximum: int,title: String,tag: String="",distinct: bool=false) -> Array:
 if distinct:
  for r in pool: r.choice_name=e.cards[e.find_card(r.uid).card_id].name
 return e.Pack.selection([e.Pack.group(pool,minimum,maximum,title,distinct)],tag)
static func field(e,kinds: Array,who: int=-1) -> Array: return e.Pack.objects(e,kinds,who)
static func race(e,c: Dictionary,r: String) -> bool: return r in e.cards[c.card_id].race or "全部" in e.cards[c.card_id].race or r=="神" and "八百万之神" in e.cards[c.card_id].race
static func refs(e,cards: Array) -> Array: return e.Pack.refs(e,cards)
static func valid(e,t: Dictionary) -> bool: return e.Extra.valid(e,t)
static func unit(e,t: Dictionary) -> bool: return t.has("uid") and e.target_valid(t,true)
static func named_character(e,who: int,name: String) -> bool: return e.Pack.has_character(e,who,name)
static func character_matches(actual: String,required: String) -> bool:
 return not required.is_empty() and Cat.normalized(actual).contains(Cat.normalized(required))
static func permanent(e,c: Dictionary) -> bool: return e.cards[c.card_id].kind in ["自机","单位","道具","结界"]
static func to_top(e,c: Dictionary):
 e.move_to(c,"deck")
 if c.zone=="deck": e.players[c.owner].deck.erase(c); e.players[c.owner].deck.push_front(c)
static func field_many(e,list: Array,who: int,tapped: bool=false):
 var eligible=list.filter(func(c): return e.field_error(c,who).is_empty()); var names={}; var slots=0
 for c in eligible:
  var title=e.cards[c.card_id].title
  if not title.is_empty(): names[title]=int(names.get(title,0))+1
 eligible=eligible.filter(func(c): return e.cards[c.card_id].title.is_empty() or names[e.cards[c.card_id].title]==1)
 for c in eligible:
  if e.is_unit(c) and not e.Extra.keyword(e,c,"不占战场格") and not (e.players[who].get("dolls_free",false) and race(e,c,"人偶")): slots+=1
 var full=e.field_slots(who)+slots>Cat.field_limit(e,who)
 var entered=[]
 for c in eligible:
  if full and e.is_unit(c) and not e.Extra.keyword(e,c,"不占战场格") and not (e.players[who].get("dolls_free",false) and race(e,c,"人偶")): continue
  e.detach(c);c.motion_from_owner=c.owner; c.owner=who
  e.shift(c,"field");c.entered=e.turn;c.entered_turns=e.players[who].turns;c.tapped=tapped;e.players[who].field.append(c);e.replace_melody(c);entered.append(c)
 for c in entered:e.Extra.on_enter(e,c)
static func plus(e,c: Dictionary,n: int,placer: int=-1):
 if c.is_empty() or c.zone!="field" or n<=0: return
 Batch.counter(e,c,"plus_counters",n,c.owner if placer<0 else placer)
 if enabled(e,c,"akyuu_counter") and e.usage_count(c.uid,"akyuu_counter")==0:
  e.use_once(c.uid,"akyuu_counter"); event(e,c,"akyuu_counter",true)
static func freeze_next(e,c: Dictionary): c.freeze_until=e.players[c.owner].turns+1
static func reset_allowed(e,c: Dictionary) -> bool:
 if c.get("freeze_until",-1)>=e.players[c.owner].turns: return false
 var lock=c.get("perfect_lock",{})
 return lock.is_empty() or e.players[lock.owner].get("freeze_serial",0)!=lock.serial
static func stat_adjust(e,c: Dictionary,k: String) -> int:
 if c.zone!="field": return 0
 var n=Cat.State.stat_adjust(e,c,k)
 if has(e.cards[c.card_id],"france_doll") and named_character(e,c.owner,"爱丽丝·玛格特洛依德"):n+=e.units(c.owner).filter(func(u):return race(e,u,"人偶")).size()
 if enabled(e,c,"kogasa_boost") and k in ["power","spirit"]:
  for u in e.units(0)+e.units(1):n+=int(u.get("scare",0))
 if k in ["power","health"]: n-=int(c.get("minus_counters",0))
 if has(e.cards[c.card_id],"kasen_ramp_stats") and e.players[c.owner].palette.size()>=12: n+=3
 for u in e.units(c.owner):
  if u.uid==c.uid: continue
  if enabled(e,u,"remilia_aura") and "黑" in e.Pack.colors(e,c): n+=1
  if has(e.cards[u.card_id],"cirno_aura") and race(e,c,"妖精") and k in ["power","spirit"]: n+=1
 if k in ["power","health"]:
  n-=e.units(1-c.owner).filter(func(u): return has(e.cards[u.card_id],"murasa_aura")).size()
 return n
static func keyword(e,c: Dictionary,k: String) -> bool:
 if Cat.State.keyword(e,c,k):return true
 var info=e.cards[c.card_id]
 if k=="不占战场格" and e.players[c.owner].get("dolls_free",false) and race(e,c,"人偶"): return true
 if c.zone!="field": return false
 if k=="不能被阻挡" and enabled(e,c,"koishi_evasion"): return true
 if k=="歼灭":
  if has(info,"kasen_ramp_stats") and e.players[c.owner].palette.size()>=12: return true
  if e.players[c.owner].field.any(func(u): return has(e.cards[u.card_id],"annihilate_aura")): return true
 if k=="疾行" and "绿" in e.Pack.colors(e,c):
  return e.units(c.owner).any(func(u): return u.uid!=c.uid and enabled(e,u,"suwako_haste"))
 if k=="不占战场格" and e.players[c.owner].get("dolls_free",false) and race(e,c,"人偶"): return true
 return k in c.get("extra_keywords",[])
static func fast(e,c: Dictionary,who: int) -> bool:
 return (Cat.enabled(e,c,"character-fdn-036:self")) or (has(e.cards[c.card_id],"kogasa_flash") and not e.combat.is_empty() and e.combat.owner!=who) or forced(e,c,who)
static func forced(e,c: Dictionary,who: int) -> bool: return e.forced_cast.get("uid",-1)==c.uid and e.forced_cast.get("owner",-1)==who
static func permission(e,c: Dictionary,who: int) -> bool:
 if forced(e,c,who) or Cat.State.permission(e,c,who): return true
 if c.zone=="exile" and c.get("excel_access",{}).get("owner",-1)==who and c.excel_access.turn==e.turn: return true
 return c.owner==who and c.zone=="grave" and e.active==who and e.cards[c.card_id].kind=="符卡" and e.Extra.cost_value(e,c)<=2 and e.players[who].field.any(func(u): return has(e.cards[u.card_id],"heart_grave")) and not e.players[who].get("heart_used_turn",-1)==e.turn
static func bypass(e,c: Dictionary,who: int) -> bool:
 return (forced(e,c,who) and e.forced_cast.get("ignore",true)) or Cat.State.bypass(e,c,who) or permission(e,c,who) and c.get("excel_access",{}).get("ignore",false)
static func free_cast(e,c: Dictionary,who: int) -> bool:
 if e.paid_cast_uid==c.uid:return false
 return (c.zone=="exile" and c.get("free_exile_owner",-1)==who) or (forced(e,c,who) and e.forced_cast.get("free",true)) or Cat.State.free_cast(e,c,who) or (c.get("excel_access",{}).get("owner",-1)==who and c.excel_access.turn==e.turn) or e.players[who].field.any(func(u):return has(e.cards[u.card_id],"free_anthem"))
static func cost(e,c: Dictionary,who: int,base: Dictionary) -> Dictionary:
 if free_cast(e,c,who): return {}
 var result=base.duplicate()
 if has(e.cards[c.card_id],"end_turn") and e.active==who: return {"蓝":1}
 if enabled(e,c,"miko_discount"):result["黄"]=maxi(0,int(result.get("黄",0))-(e.units(0).size()+e.units(1).size())/2)
 if int(result.get("蓝",0))>0:
  var discount=e.units(who).filter(func(u): return has(e.cards[u.card_id],"ran_discount")).size()
  result["蓝"]=maxi(0,int(result.get("蓝",0))-discount)
 return Batch.cost(e,c,who,result)
static func protected(e,t: Dictionary,who: int,spell: bool) -> bool:
 if Cat.State.protected(e,t,who,spell):return true
 if not t.has("uid"): return false
 var c=e.find_card(t.uid)
 if c.is_empty() or c.zone!="field": return false
 return e.players[c.owner].get("shroud_turn",-1)==e.turn or spell and who!=c.owner and has(e.cards[c.card_id],"nitori_ward")
static func filter_options(e,options: Array,who: int,spell: bool) -> Array:
 var result=[]
 for o in options:
  if o.has("selection"):
   var copy=o.duplicate(true); var good=true
   for g in copy.selection:
    if g.get("cost",false): continue
    g.pool=g.pool.filter(func(t): return not protected(e,t,who,spell))
    if g.pool.size()<g.min: good=false
   if good:result.append(copy)
  elif o.has("parts"):
   if o.parts.all(func(t): return not protected(e,t,who,spell)): result.append(o)
  elif not protected(e,o,who,spell): result.append(o)
 return result
static func invalidate(e,t: Dictionary,who: int,spell: bool) -> Dictionary:
 var out=t.duplicate(true)
 if out.has("picks"):
  for i in range(out.picks.size()): out.picks[i]=out.picks[i].map(func(r): return invalidate(e,r,who,spell))
 elif out.has("parts"): out.parts=out.parts.map(func(r): return invalidate(e,r,who,spell))
 elif protected(e,out,who,spell): return {"invalid":true}
 return out
static func extra_cost(e,id: String,who: int,options: Array) -> Array:
 if key(e.cards[id],["discard_draw","door_reveal"]).is_empty(): return options
 var pool=refs(e,e.players[who].hand.filter(func(c): return c.card_id!=id or e.players[who].hand.filter(func(other): return other.card_id==id).size()>1))
 # Source UID is excluded again during commit, even when copies share a name.
 if pool.is_empty(): return []
 var g=e.Pack.group(pool,1,1,"弃置一张手牌"); g.cost=true
 return e.Pack.selection([g],"additional_discard")
static func spell_options(e,id: String,who: int) -> Variant:
 var cat=Cat.spell_options(e,id,who)
 if cat!=null:return cat
 var batch=Batch.spell_options(e,id,who)
 if batch!=null:return batch
 var k=key(e.cards[id],SPELLS+UCS_SPELLS+["miko_divide"])
 if k.is_empty():return null
 var units=e.Pack.all_units(e); var own=e.Pack.all_units(e,who); var options=[]
 match k:
  "kill_small":options=units.filter(func(r):return e.Extra.cost_value(e,e.find_card(r.uid))<=3)
  "reset_four":options=e.Pack.none()
  "color_damage":options=e.ability_targets()
  "leader_mark","unblock_reset","gather_counters": options=own
  "destroy_any","exile_permanent": options=field(e,["单位","自机","道具","结界"])
  "gungnir","counters_x","flower_damage","perfect_freeze","tap_destroy": options=units
  "destroy_item_field":options=field(e,["道具","结界"])
  "grave_top","grave_palette":options=e.Pack.zone(e,who,"grave")
  "bounce_small":options=units.filter(func(t):return e.Extra.cost_value(e,e.find_card(t.uid))<=4)
  "steal_turn":options=e.Pack.all_units(e,1-who)
  "draw_x":options=[{"player":0},{"player":1}]
  "fairy_revive":options=pick(e,refs(e,e.players[who].grave.filter(func(c):return e.is_unit(c) and race(e,c,"妖精"))),0,3,"选择至多三张不同名妖精",k,true)
  "blink_two":options=pick(e,own,0,2,"选择至多两个己方单位",k)
  "tengu_pair":
   for a in own:
    for b in e.Pack.all_units(e,1-who):
     if e.cards[e.find_card(a.uid).card_id].kind==e.cards[e.find_card(b.uid).card_id].kind:options.append({"parts":[a,b]})
  "counter_ability":options=e.stack.filter(func(s):return s.kind=="ability").map(func(s):return {"stack_id":s.id})
  "counter_targeting":options=e.stack.filter(func(s):return (s.kind=="ability" or e.cards[s.card.card_id].kind=="符卡") and e.Pack.flatten(s.target).any(func(t):return unit(e,t) and e.find_card(t.uid).owner==who)).map(func(s):return {"stack_id":s.id})
  "lake_mill":
   for p in range(2):
    for u in units:options.append({"parts":[{"player":p},u]})
  "waterfall":
   for a in own:
    for b in units:
     if a.uid!=b.uid:options.append({"parts":[a,b]})
  "ghost_imp":options=refs(e,(e.players[0].grave+e.players[1].grave).filter(func(c):return e.is_unit(c)))
  "memory_cast":options=refs(e,e.players[1-who].grave.filter(func(c):return e.cards[c.card_id].kind=="符卡"))
  "death_return":options=refs(e,(e.players[0].grave+e.players[1].grave).filter(func(c):return e.is_unit(c) and c.get("died_turn",-1)==e.turn))
  "crimson_modes":options=e.Extra.add_mode(units,"造成3点伤害")+[{"mode":"红色单位获得歼灭","none":true}]+e.Extra.add_mode(own,"重置单位")
  "quiet_modes":options=e.Extra.add_mode(units,"移回手牌")+[{"mode":"抓三张再弃两张","none":true}]+e.Extra.add_mode(units,"横置并锁定")
  "wheel_modes":
   var modes=[[{"mode":"全体强化","none":true}],e.Extra.add_mode(refs(e,e.players[who].grave.filter(func(c):return e.is_unit(c))),"回收单位"),e.Extra.add_mode(field(e,["结界"]),"消灭结界"),e.Extra.add_mode(e.ability_targets(),"造成2点伤害")]
   for i in range(4):
    for j in range(i+1,4):
     for a in modes[i]:
      for b in modes[j]:options.append({"parts":[a,b]})
  "cloud_attack":
   if not e.combat.is_empty() and unit(e,e.combat.attacker):options=[e.combat.attacker]
  _:options=e.Pack.none()
 if not e.cards[id].get("variable_cost","").is_empty():
  var limit=e.source_resources(who).size(); var expanded=[]
  if has(e.cards[id],"miko_discount"):limit+=(e.units(0).size()+e.units(1).size())/2
  if (not e.forced_cast.is_empty() and e.forced_cast.get("free",true) and e.paid_cast_uid!=e.forced_cast.uid) or (e.paid_cast_uid<0 and e.players[who].field.any(func(u):return has(e.cards[u.card_id],"free_anthem"))):limit=0
  for x in range(limit+1):
   for o in options:
    var copy=o.duplicate(true);copy.x=x;copy.mode="X = %d" % x;expanded.append(copy)
  options=expanded
 return extra_cost(e,id,who,options)

static func on_enter(e,c: Dictionary):
 Cat.on_enter(e,c)
 Batch.on_enter(e,c)
 for k in ["orin_discard","miko_divide","parsee_catchup"]:
  if has(e.cards[c.card_id],k):event(e,c,k,k=="orin_discard")
 if e.is_unit(c):
  for observer in e.units(0)+e.units(1):
   if has(e.cards[observer.card_id],"sakuya_timer"):event(e,observer,"sakuya_timer")
 for k in ["luna_life","star_destroy","hourai_ping","letty_freeze","dai_search","komachi_exile","keiki_copy","chen_counter","nazrin_draw","kyouko_shuffle","satori_scry","suwako_top"]:
  if has(e.cards[c.card_id],k) and (k!="hourai_ping" or named_character(e,c.owner,"爱丽丝·玛格特洛依德")):event(e,c,k,k not in ["luna_life","keiki_copy","suwako_top"])
 if enabled(e,c,"yuuka_ramp"):event(e,c,"yuuka_ramp",true)
 for u in e.players[c.owner].field:
  if has(e.cards[u.card_id],"activity") and e.is_unit(c) and not e.units(c.owner).any(func(other):return other.uid!=c.uid and e.cards[other.card_id].name==e.cards[c.card_id].name):event(e,u,"activity_draw")
  if u.uid!=c.uid and enabled(e,u,"shinmy_counter") and race(e,c,"小人"):event(e,u,"shinmy_counter",true)
static func on_leave(e,before: Dictionary,c: Dictionary):
 Cat.on_leave(e,before,c)
 if has(e.cards[before.card_id],"hatate_replace") and c.zone=="hand":event(e,before,"hatate_replace",true)
static func on_death(e,c: Dictionary,before: Dictionary):
 Cat.on_death(e,c,before)
 c.died_turn=e.turn
 var observers=e.death_observers if not e.death_observers.is_empty() else e.units(before.owner)
 for u in observers:
  if u.owner==before.owner and has(e.cards[u.card_id],"mystia_life"):event(e,u,"mystia_life")
 for f in e.players[before.owner].field:
  if has(e.cards[f.card_id],"nether_ghost") and not before.get("token",false):event(e,f,"nether_ghost")
 if has(e.cards[before.card_id],"shanghai_draw") and named_character(e,before.owner,"爱丽丝·玛格特洛依德"):event(e,before,"shanghai_draw",true)
 if has(e.cards[before.card_id],"seiga_death"):event(e,before,"seiga_death")
static func on_cast(e,c: Dictionary,who: int,old_zone: String):
 Cat.on_cast(e,c,who,old_zone)
 Batch.on_cast(e,c,who)
 if has(e.cards[c.card_id],"kanako_cast"):event(e,c,"kanako_cast")
 if old_zone=="grave" and not forced(e,c,who):e.players[who].heart_used_turn=e.turn;c.exile_on_grave=true
 if has(e.cards[c.card_id],"perfect_freeze"):e.players[who].freeze_serial=int(e.players[who].get("freeze_serial",0))+1
 for u in e.units(who):
  if e.cards[c.card_id].kind=="符卡" and has(e.cards[u.card_id],"meiling_spell"):event(e,u,"meiling_spell")
  if e.is_unit(c) and has(e.cards[u.card_id],"shinmy_cast"):event(e,u,"shinmy_cast",true)
static func on_phase(e,phase: String):
 Cat.on_phase(e,phase)
 Batch.on_phase(e,phase)
 for c in e.players[e.active].field.duplicate():
  if phase=="main" and has(e.cards[c.card_id],"koishi_coin"):event(e,c,"koishi_coin")
  if phase!="end":continue
  if has(e.cards[c.card_id],"kogasa_scare"):event(e,c,"kogasa_scare")
  if enabled(e,c,"kanako_ten") and e.units(c.owner).size()>=10:event(e,c,"kanako_ten")
  for k in ["seiga_imp","kanako_pillar","mist_lake","kaleidoscope","snow_time","extra_turn"]:
   if not has(e.cards[c.card_id],k):continue
   if k=="seiga_imp" and e.units(c.owner).any(func(u):return u.get("token",false) and e.cards[u.card_id].character=="小鬼"):continue
   event(e,c,k,k in ["seiga_imp","kanako_pillar"])
static func on_attack(e,c: Dictionary):
 Cat.on_attack(e,c)
 if has(e.cards[c.card_id],"suika_attack"):event(e,c,"suika_attack",true)
 if enabled(e,c,"yuuka_ramp"):event(e,c,"yuuka_ramp",true)
static func trigger_options(e,t: Dictionary) -> Array:
 var cat=Cat.trigger_options(e,t)
 if cat!=null:return cat
 if t.get("continuation",false):return e.pending.get("options",[])
 var batch=Batch.trigger_options(e,t)
 if batch!=null:return batch
 var who=t.owner
 match t.effect:
  "coin_damage":return e.ability_targets()
  "kogasa_scare":return e.Pack.all_units(e,1-who)
  "orin_discard":return e.Pack.all_units(e,1-who).filter(func(r):return e.cards[e.find_card(r.uid).card_id].kind=="单位")
  "miko_divide":
   var x=int(t.source.get("cast_x",0));var pool=e.Pack.all_units(e);var groups=[]
   if x==0 or pool.is_empty():return e.Pack.none()
   for i in range(x):groups.append(e.Pack.group(pool,1,1,"分配第 %d / %d 点伤害" % [i+1,x]))
   return e.Pack.selection(groups,"miko_divide")
  "star_destroy":return field(e,["道具"])
  "hourai_ping":return e.ability_targets()
  "letty_freeze","shinmy_counter":return e.Pack.all_units(e)
  "chen_counter":return e.Pack.all_units(e,who)
  "akyuu_counter","keiki_copy":return e.Pack.all_units(e,who).filter(func(r):return r.uid!=t.source.uid)
  "komachi_exile":return pick(e,refs(e,(e.players[0].grave+e.players[1].grave).filter(func(c):return e.is_unit(c))),0,2,"除外至多两张单位牌",t.effect)
  "kyouko_shuffle":return pick(e,e.Pack.zone(e,who,"grave"),3,3,"选择三张牌洗回牌库",t.effect)
  "satori_scry":return [{"player":0},{"player":1}]
 return e.Pack.none()
static func resolve_trigger(e,t: Dictionary):
 if t.effect=="reset_four_choose":
  for r in e.Pack.picked(t.target):
   if valid(e,r) and e.find_card(r.uid).zone=="palette":e.find_card(r.uid).tapped=false
  return
 if Cat.resolve_trigger(e,t):return
 if Batch.resolve_trigger(e,t):return
 var who=t.owner;var aim=t.target;var data=t.get("data",{});var source=e.find_card(t.source.uid)
 var same=not source.is_empty() and source.epoch==t.source.epoch and source.zone=="field"
 match t.effect:
  "sakuya_timer":
   var leader=e.players[who].leader
   if leader.zone=="leader" and leader.timer>0:continue_choice(e,t,"sakuya_remove",[{"none":true,"mode":"移去一个计时指示物"},{"none":true,"mode":"不移去"}])
  "sakuya_remove":
   if aim.mode=="移去一个计时指示物" and e.players[who].leader.zone=="leader":e.players[who].leader.timer=maxi(0,e.players[who].leader.timer-1)
  "parsee_catchup":
   if e.players[1-who].life>e.players[who].life:e.gain_life(who,2)
   if e.players[1-who].hand.size()>e.players[who].hand.size():e.draw(who)
  "kanako_cast":
   for i in range(4):create_token(e,who,"pillar",2,["绿"],["不占战场格"])
  "kanako_ten":
   if e.units(who).size()>=10:
    for u in e.units(who):plus(e,u,1)
  "kogasa_scare":
   if unit(e,aim):Batch.counter(e,e.find_card(aim.uid),"scare",1,who)
   for p in range(2):
    if not e.players[p].deck.is_empty():e.move_to(e.players[p].deck[0],"grave")
  "orin_discard":continue_choice(e,t,"orin_kill",pick(e,e.Pack.zone(e,who,"hand"),1,1,"弃置一张手牌"),{"ref":aim},true)
  "orin_kill":
   for r in e.Pack.picked(aim):
    if valid(e,r):e.move_to(e.find_card(r.uid),"grave")
   if unit(e,data.ref):e.destroy(e.find_card(data.ref.uid))
  "miko_divide":
   var counts={};var targets={}
   for r in e.Pack.flatten(aim):
    if unit(e,r):counts[r.uid]=int(counts.get(r.uid,0))+1;targets[r.uid]=r
   e.damage_context.single=counts.size()==1
   for uid in counts:e.damage_target(targets[uid],counts[uid])
  "coin_damage":e.damage_target(aim,2)
  "backpack_tax":
   if e.stack.any(func(s):return s.id==data.id):continue_choice(e,t,"backpack_pay",tax_options(e,data.payer),data,false,data.payer)
  "backpack_pay":
   if not e.stack.any(func(s):return s.id==data.id):return
   var plan=[{"uid":aim.get("uid",-1),"color":aim.get("color","")}] if aim.has("color") else []
   if not e.payment_valid(who,{"红/蓝/绿/黄/黑":1},plan):e.counter_entry(data.id)
   elif plan[0].uid<0:e.players[who].potato=false
   else:e.tap_card(e.find_card(plan[0].uid))
  "medicine_destroy":
   if unit(e,data.ref):e.destroy(e.find_card(data.ref.uid))
  "komachi_counters":
   if unit(e,data.ref):Batch.counter(e,e.find_card(data.ref.uid),"minus_counters",3,who)
  "komachi_coin":
   var p=e.players[data.player];p.coins=int(p.get("coins",0))+1
   if p.coins>=3:e.lose(data.player,"获得三个铜钱指示物",true)
  "luna_life":e.gain_life(who,e.units(who).filter(func(c):return race(e,c,"妖精")).size())
  "star_destroy":
   if valid(e,aim):e.destroy(e.find_card(aim.uid))
  "hourai_ping":e.damage_target(aim,1)
  "letty_freeze":
   if unit(e,aim):
    var c=e.find_card(aim.uid)
    if c.tapped:freeze_next(e,c)
    else:e.tap_card(c)
  "chen_counter","akyuu_counter","shinmy_counter":
   if unit(e,aim):plus(e,e.find_card(aim.uid),1,who)
  "komachi_exile":
   var n=0
   for r in e.Pack.picked(aim):
    if valid(e,r):e.move_to(e.find_card(r.uid),"exile");n+=1
   if n>0:e.gain_life(who,2)
  "keiki_copy":
   if unit(e,aim):copy_idol(e,who,e.find_card(aim.uid))
  "dai_search","alice_search","search_leader","sanae_search":
   var k=t.effect
   var pool=e.players[who].deck.filter(func(c):return (e.is_unit(c) and race(e,c,"妖精")) if k=="dai_search" else (e.is_unit(c) and race(e,c,"人偶") and e.Extra.cost_value(e,c)==1) if k=="alice_search" else e.cards[c.card_id].kind=="自机" if k=="search_leader" else "绿" in e.cards[c.card_id].colors)
   continue_choice(e,t,"search_take",pick(e,refs(e,pool),0,1,"检索",k),{"field":k=="alice_search","top":k=="sanae_search"})
  "search_take":
   var chosen=[]
   for r in e.Pack.picked(aim):
    if valid(e,r):chosen.append(e.find_card(r.uid))
   for c in chosen:e.reveal_card(c)
   if data.get("field",false):field_many(e,chosen,who)
   elif not data.get("top",false):
    for c in chosen:e.move_to(c,"hand")
   e.shuffle(e.players[who].deck)
   if data.get("top",false):
    for c in chosen:e.players[who].deck.erase(c);e.players[who].deck.push_front(c)
  "nazrin_draw":
   e.draw(who,2);continue_choice(e,t,"nasrin_bottom",pick(e,e.Pack.zone(e,who,"hand"),1,1,"放在牌库底"))
  "nasrin_bottom":
   for r in e.Pack.picked(aim):
    if valid(e,r):e.move_to(e.find_card(r.uid),"deck")
  "kyouko_shuffle":
   for r in e.Pack.picked(aim):
    if valid(e,r):e.move_to(e.find_card(r.uid),"deck")
   e.shuffle(e.players[who].deck);e.gain_life(who,1)
  "shanghai_draw","activity_draw":e.draw(who)
  "mystia_life":e.gain_life(who,1)
  "seiga_death":
   var enemy=e.units(1-who);var highest=-999
   for c in enemy:highest=maxi(highest,e.stat(c,"power"))
   if enemy.is_empty():e.players[who].life-=2
   else:continue_choice(e,t,"seiga_sacrifice",pick(e,refs(e,enemy.filter(func(c):return e.stat(c,"power")==highest)),1,1,"牺牲攻击力最高的单位"),{"controller":who},false,1-who)
  "seiga_sacrifice":
   for r in e.Pack.picked(aim):
    if unit(e,r):e.sacrifice(e.find_card(r.uid))
   e.players[data.controller].life-=2
  "meiling_spell":
   if same:source.tapped=false;e.apply_turn_buff(e.ref_target(source),{"攻击力":1,"血量":1})
  "suika_attack":
   if same:plus(e,source,2)
  "hatate_replace":continue_choice(e,t,"hand_tapped",pick(e,refs(e,e.players[who].hand.filter(func(c):var i=e.cards[c.card_id];return i.kind=="单位" and i.character!="姬海棠果" and e.Extra.cost_value(e,c)<=4 and i.colors.any(func(color):return color in ["红","绿"]))),0,1,"选择放入战场的单位"))
  "hand_tapped":field_many(e,e.Pack.picked(aim).filter(func(r):return valid(e,r)).map(func(r):return e.find_card(r.uid)),who,true)
  "koishi_coin":
   var heads=e.flip_coin(who)
   if same:
    if heads:e.apply_turn_buff(e.ref_target(source),{"灵力":2})
    else:e.tap_card(source)
  "yuuka_ramp":e.Pack.ramp(e,who,1)
  "seiga_imp":create_token(e,who,"imp",1,["黑"])
  "kanako_pillar":create_token(e,who,"pillar",2,["绿"])
  "shinmy_cast":create_token(e,who,"kobito",1,["黄","绿"])
  "nether_ghost":create_token(e,who,"ghost",1,["黄"])
  "satori_scry":begin_scry(e,t,aim.player,3,false)
  "scry_grave":
   var rest=[]
   for r in data.top:
    if not valid(e,r):continue
    if r in e.Pack.picked(aim):e.move_to(e.find_card(r.uid),"grave")
    else:rest.append(r)
   if rest.size()<=1:finish_scry(e,t,rest,data)
   else:continue_choice(e,t,"scry_order",pick(e,rest,rest.size(),rest.size(),"按牌库顶到底的顺序点选"),data)
  "scry_order":finish_scry(e,t,e.Pack.picked(aim),data)
  "suwako_top","mist_lake":
   var top=refs(e,e.players[who].deck.slice(0,4));var options=[]
   for r in top:
    var c=e.find_card(r.uid);e.reveal_card(c)
    if t.effect=="mist_lake":
     if e.is_unit(c) and race(e,c,"妖精"):options.append(r)
    elif (e.is_unit(c) and "绿" in e.cards[c.card_id].colors and e.Extra.cost_value(e,c)<=4) or character_matches("洩矢诹访子",e.cards[c.card_id].requires_character) and not e.cards[c.card_id].requires_character.is_empty():options.append(r)
   continue_choice(e,t,"mist_choose",pick(e,options,0,1,"选择要放入战场或手牌的牌"),{"top":top})
  "mist_choose":
   for r in e.Pack.picked(aim):
    if not valid(e,r):continue
    var c=e.find_card(r.uid)
    if e.is_unit(c):field_many(e,[c],who)
    else:e.move_to(c,"hand")
   bottom_rest(e,data.top,who)
  "kaleidoscope":
   e.draw(who)
   var groups=[e.Pack.group(e.Pack.zone(e,who,"hand"),1,1,"选择手牌"),e.Pack.group(e.Pack.zone(e,who,"palette"),1,1,"选择颜色盘")]
   continue_choice(e,t,"time_exchange",e.Pack.selection(groups,"time_exchange"))
  "time_exchange":
   var a=e.Pack.picked(aim,0)[0];var b=e.Pack.picked(aim,1)[0]
   if valid(e,a) and valid(e,b):e.move_to(e.find_card(a.uid),"palette");e.move_to(e.find_card(b.uid),"hand")
  "snow_time":
   for c in e.units(0)+e.units(1):e.damage_target(e.ref_target(c),1)
  "extra_turn":e.extra_turns.push_front(who);e.note("获得一个额外回合")
  "discard_choice","satori_discard_choice":
   for r in e.Pack.picked(aim):
    if valid(e,r):e.move_to(e.find_card(r.uid),"grave")
  "hand_army","palette_army","doll_army":
   var chosen=e.Pack.picked(aim).filter(func(r):return valid(e,r)).map(func(r):return e.find_card(r.uid))
   field_many(e,chosen,who)
   if t.effect=="doll_army":e.shuffle(e.players[who].deck)
  "fairy_return":
   for c in e.units(who).duplicate():
    if race(e,c,"妖精"):e.move_to(c,"hand")
  "survivor_first":
   var keep=e.Pack.picked(aim);var p=1-who;var pool=e.Pack.all_units(e,p)
   if pool.is_empty():sacrifice_others(e,keep)
   else:continue_choice(e,t,"survivor_second",pick(e,pool,1,1,"选择保留的单位"),{"keep":keep},false,p)
  "survivor_second":sacrifice_others(e,data.keep+e.Pack.picked(aim))
  "grant_cast":
   if valid(e,data.ref):
    var c=e.find_card(data.ref.uid);e.forced_cast={"owner":who,"uid":c.uid};e.priority=who
    var error=e.commit_cast(who,c.uid,aim,[]);e.forced_cast={}
    if not error.is_empty():e.note("无法使用："+error)
  "cloud_blink":
   for r in e.Pack.picked(aim):
    if unit(e,r):blink_now(e,[e.find_card(r.uid)])
static func begin_scry(e,t: Dictionary,owner: int,count: int,draw_after: bool):
 var top=refs(e,e.players[owner].deck.slice(0,count))
 continue_choice(e,t,"scry_grave",pick(e,top,0,top.size(),"选择送去墓地的牌"),{"top":top,"owner":owner,"draw":draw_after})
static func finish_scry(e,t: Dictionary,ordered: Array,data: Dictionary):
 var list=ordered.filter(func(r):return valid(e,r)).map(func(r):return e.find_card(r.uid))
 for c in list:e.players[c.owner].deck.erase(c)
 list.reverse()
 for c in list:e.players[c.owner].deck.push_front(c)
 if data.draw:e.draw(t.owner)
static func bottom_rest(e,top: Array,who: int):
 var list=[]
 for r in top:
  if valid(e,r):var c=e.find_card(r.uid);e.players[c.owner].deck.erase(c);list.append(c)
 e.shuffle(list);e.players[who].deck.append_array(list)
static func sacrifice_others(e,keep: Array):
 e.death_observers=(e.units(0)+e.units(1)).duplicate(true)
 for c in (e.units(0)+e.units(1)).duplicate():
  if not keep.any(func(r):return r.get("uid")==c.uid and r.get("epoch")==c.epoch):e.sacrifice(c)
 e.death_observers=[]
static func blink_now(e,list: Array):
 var moved=[]
 for c in list:
  e.move_to(c,"exile")
  if c.zone=="return_pending":c.blink_return_owner=c.original_owner
  else:moved.append(e.Pack.future_zone_ref(e,c,"exile"))
 for p in range(2):field_many(e,moved.filter(func(r):return valid(e,r) and e.find_card(r.uid).get("original_owner")==p).map(func(r):return e.find_card(r.uid)),p)

static func spell_resolve(e,entry: Dictionary) -> bool:
 if Cat.spell_resolve(e,entry):return true
 if Batch.spell_resolve(e,entry):return true
 var c=entry.card;var k=key(e.cards[c.card_id],SPELLS+UCS_SPELLS)
 if k.is_empty():return false
 var who=entry.owner;var t=entry.target;var x=int(t.get("x",0));var exile=false
 e.resolving_spell=true
 match k:
  "coin_anthem","free_anthem":e.enter_field(c,who);e.resolving_spell=false;return true
  "all_counters":
   for u in e.units(who):plus(e,u,1)
  "kill_small":
   if unit(e,t) and e.Extra.cost_value(e,e.find_card(t.uid))<=3:e.destroy(e.find_card(t.uid))
  "palette_wipe":
   for p in range(2):
    for u in e.players[p].palette.duplicate():e.move_to(u,"grave")
  "reset_four":
   continue_choice(e,entry,"reset_four_choose",pick(e,e.Pack.zone(e,who,"palette"),0,4,"重置至多四张颜色盘中的牌"))
  "color_damage":
   var colors=[]
   for u in e.players[who].field:
    if permanent(e,u):
     for color in e.Pack.colors(e,u):
      if color not in colors:colors.append(color)
   e.damage_target(t,colors.size())
  "kaleidoscope","activity","extra_turn","snow_time":
   e.enter_field(c,who);c.timer=int(e.cards[c.card_id].time);e.resolving_spell=false;return true
  "fairy_revive":field_many(e,e.Pack.picked(t).filter(func(r):return valid(e,r)).map(func(r):return e.find_card(r.uid)),who)
  "tengu_pair":
   for r in t.parts:
    if unit(e,r):e.move_to(e.find_card(r.uid),"hand")
  "leader_mark":
   if unit(e,t):Batch.counter(e,e.find_card(t.uid),"leader_counters",1,who)
  "grave_top":
   if valid(e,t):to_top(e,e.find_card(t.uid))
  "destroy_any","destroy_item_field":
   if valid(e,t):e.destroy(e.find_card(t.uid))
  "exile_permanent":
   if valid(e,t):e.move_to(e.find_card(t.uid),"exile")
  "tap_all":
   for u in e.units(1-who):e.tap_card(u)
  "discard_draw":e.draw(who,3)
  "gungnir":e.damage_target(t,4)
  "draw_x":e.draw(t.player,x)
  "blink_two":blink_now(e,e.Pack.picked(t).filter(func(r):return unit(e,r)).map(func(r):return e.find_card(r.uid)))
  "sweep_three":
   for u in e.units(0)+e.units(1):e.damage_target(e.ref_target(u),3)
  "history_exile":
   for u in e.players[who].grave.duplicate():
    if e.cards[u.card_id].kind=="符卡":e.move_to(u,"exile");u.excel_access={"owner":who,"turn":e.turn,"ignore":false}
   exile=true
  "hand_army","palette_army","doll_army":
   var z="hand" if k=="hand_army" else "palette" if k=="palette_army" else "deck"
   if k=="doll_army":e.players[who].dolls_free=true
   var pool=e.players[who][z].filter(func(u):return permanent(e,u) if k=="palette_army" else e.is_unit(u) and (k!="doll_army" or race(e,u,"人偶")))
   continue_choice(e,entry,k,pick(e,refs(e,pool),0,pool.size(),"选择进入战场的牌"))
  "counter_ability","counter_targeting":e.counter_entry(t.get("stack_id",-1))
  "counters_x":
   if unit(e,t):plus(e,e.find_card(t.uid),x,who);e.apply_turn_buff(t,{"英勇":true})
  "unblock_reset":
   if unit(e,t):e.find_card(t.uid).tapped=false;e.apply_turn_buff(t,{"不能被阻挡":true})
  "lake_mill":
   var p=t.parts[0].player
   if not e.players[p].deck.is_empty():e.move_to(e.players[p].deck[0],"grave")
   e.damage_target(t.parts[1],e.players[who].grave.size())
  "waterfall":
   if unit(e,t.parts[0]):e.damage_target(t.parts[1],e.stat(e.find_card(t.parts[0].uid),"power"))
  "philosopher":
   var top=refs(e,e.players[who].deck.slice(0,7))
   for r in top:
    var u=e.find_card(r.uid);e.reveal_card(u)
    if e.cards[u.card_id].kind=="符卡":e.move_to(u,"exile");u.excel_access={"owner":who,"turn":e.turn,"ignore":true}
   bottom_rest(e,top,who);exile=true
  "two_bats":
   for i in range(2):create_token(e,who,"bat",1,["红","黑"])
  "ghost_imp":
   if valid(e,t):
    var victim=e.find_card(t.uid);var n=e.Extra.cost_value(e,victim);e.move_to(victim,"exile")
    var token=create_token(e,who,"imp",n,["黑"],["疾行"])
    if not token.is_empty():e.delayed.append({"owner":who,"phase":"end","effect":"token_sacrifice","ref":e.ref_target(token),"zone":"field"})
  "gather_counters":
   var total=0
   for u in e.units(0)+e.units(1):total+=int(u.get("plus_counters",0));u.plus_counters=0
   if unit(e,t):plus(e,e.find_card(t.uid),total,who)
  "bounce_small":
   if unit(e,t):e.move_to(e.find_card(t.uid),"hand")
  "steal_turn":
   if unit(e,t):
    var u=e.find_card(t.uid);var prior=u.owner;e.present_move(u,"field",who);e.players[prior].field.erase(u);u.owner=who;e.players[who].field.append(u)
    u.control_return={"owner":prior,"turn":e.turn};u.tapped=false;u.entered_turns=e.players[who].turns;e.apply_turn_buff(e.ref_target(u),{"疾行":true})
  "search_leader":resolve_trigger(e,{"effect":k,"source":c,"owner":who,"target":t})
  "crimson_modes":
   match t.mode:
    "造成3点伤害":e.damage_target(t,3)
    "重置单位":
     if unit(e,t):e.find_card(t.uid).tapped=false
    _:
     for u in e.units(who):
      if "红" in e.Pack.colors(e,u):e.apply_turn_buff(e.ref_target(u),{"歼灭":true})
  "quiet_modes":
   match t.mode:
    "移回手牌":
     if unit(e,t):e.move_to(e.find_card(t.uid),"hand")
    "横置并锁定":
     if unit(e,t):var u=e.find_card(t.uid);e.tap_card(u);freeze_next(e,u)
    _:
     e.draw(who,3);continue_choice(e,entry,"discard_choice",pick(e,e.Pack.zone(e,who,"hand"),mini(2,e.players[who].hand.size()),mini(2,e.players[who].hand.size()),"弃置两张牌"))
  "grave_palette":
   if valid(e,t):var u=e.find_card(t.uid);e.move_to(u,"palette");u.tapped=true
  "flower_damage":
   if unit(e,t):e.damage_target(t,5 if e.find_card(t.uid).damage>0 else 2)
  "door_reveal":
   var top=[];var chosen={}
   for u in e.players[who].deck:
    top.append(e.Pack.ref(e,u));e.reveal_card(u)
    if e.cards[u.card_id].kind=="自机":chosen=u;break
   if not chosen.is_empty():field_many(e,[chosen],who)
   bottom_rest(e,top,who)
  "grace_reset":
   for u in e.players[who].grave.duplicate():e.move_to(u,"palette");u.tapped=true
   e.players[who].life=20;exile=true
  "frogs_x":
   for i in range(x):create_token(e,who,"frog",x,["蓝","绿"],["不占战场格"])
   if x>=3:
    for u in e.units(who):e.apply_turn_buff(e.ref_target(u),{"英勇":true,"歼灭":true})
  "fire_scry":begin_scry(e,entry,who,2,true)
  "tap_destroy":
   if unit(e,t):e.tap_card(e.find_card(t.uid))
   for u in e.units(1-who).duplicate():
    if u.tapped:e.destroy(u)
  "fairy_festival":
   for u in e.units(who):
    if race(e,u,"妖精"):e.apply_turn_buff(e.ref_target(u),{"攻击力":3,"血量":3,"灵力":3})
   e.delayed.append({"roster":true,"owner":who,"phase":"end","effect":"fairy_return","source":c.duplicate(true)})
  "perfect_freeze":
   if unit(e,t):var u=e.find_card(t.uid);e.tap_card(u);u.perfect_lock={"owner":who,"serial":e.players[who].get("freeze_serial",0)}
  "memory_cast":
   if valid(e,t):
    var u=e.find_card(t.uid);e.forced_cast={"owner":who,"uid":u.uid};var options=e.targets_for(u.card_id,who);e.forced_cast={}
    continue_choice(e,entry,"grant_cast",options,{"ref":t},true)
  "end_turn":
   e.move_to(c,"exile");end_now(e);e.resolving_spell=false;return true
  "untargetable":e.players[who].shroud_turn=e.turn
  "wheel_modes":
   for r in t.parts:
    match r.mode:
     "全体强化":
      for u in e.units(who):e.apply_turn_buff(e.ref_target(u),{"攻击力":1,"灵力":1})
     "回收单位":
      if valid(e,r):e.move_to(e.find_card(r.uid),"hand")
     "消灭结界":
      if valid(e,r):e.destroy(e.find_card(r.uid))
     "造成2点伤害":e.damage_target(r,2)
  "cloud_attack":
   if unit(e,t):
    var u=e.find_card(t.uid);var can_destroy=not e.Extra.keyword(e,u,"不会被消灭");e.destroy(u)
    if can_destroy:continue_choice(e,entry,"cloud_blink",pick(e,e.Pack.all_units(e,who),0,1,"选择一个单位暂时除外"))
  "rest_life":e.gain_life(who,8 if e.players[who].life<=5 else 4)
  "survivors":
   var first=e.active;var pool=e.Pack.all_units(e,first)
   if pool.is_empty():
    first=1-first;pool=e.Pack.all_units(e,first)
    if pool.is_empty():sacrifice_others(e,[])
    else:continue_choice(e,entry,"survivor_second",pick(e,pool,1,1,"选择保留的单位"),{"keep":[]},false,first)
   else:continue_choice(e,entry,"survivor_first",pick(e,pool,1,1,"选择保留的单位"),{},false,first)
  "death_return":
   if valid(e,t):field_many(e,[e.find_card(t.uid)],who)
 e.judge();e.resolving_spell=false
 e.move_to(c,"exile" if exile else "grave")
 return true

static func activation_cost(k: String) -> Dictionary:
 if k in Cat.ACTIVATIONS:return Cat.activation_cost(k)
 return {"红":1,"绿":1} if k=="hatate_return" else {"红":1} if k=="alice_search" else {"黄":1} if k=="alice_recycle" else {}
static func activation_error(e,c: Dictionary,k: String) -> String:
 if k in Cat.ACTIVATIONS:return Cat.activation_error(e,c,k)
 if k in Batch.ACTIVATIONS:return Batch.activation_error(e,c,k)
 if not enabled(e,c,k):return "没有该异能"
 if k in ["clown_sweep","kaguya_end"] and (c.tapped or e.summoning_sick(c)):return "不能横置"
 if k=="kaguya_end" and e.active!=c.owner:return "只能在自己回合发动"
 if k=="hina_redirect" and e.players[c.owner].life<2:return "生命不足"
 if k=="suika_counter" and c.get("plus_counters",0)<1:return "没有指示物"
 if k=="sanae_search" and c.get("sanae_used",false):return "本局已经发动"
 return ""
static func activation_options(e,c: Dictionary,k: String) -> Array:
 if k in Cat.ACTIVATIONS:return Cat.activation_options(e,c,k)
 if k in Batch.ACTIVATIONS:return Batch.activation_options(e,c,k)
 var who=c.owner
 match k:
  "hatate_return","clown_sweep","alice_search","kaguya_end":return e.Pack.none()
  "satori_discard":return [{"player":0},{"player":1}]
  "suika_counter":return e.Pack.all_units(e,who).filter(func(r):return r.uid!=c.uid)
  "kanako_blast":
   var g=e.Pack.group(refs(e,e.units(who).filter(func(u):return e.cards[u.card_id].character=="御柱")),1,1,"牺牲一个御柱");g.cost=true
   return e.Pack.selection([g,e.Pack.group(e.Pack.all_units(e),1,1,"目标单位")],k)
  "alice_recycle":
   var g=e.Pack.group(e.Pack.all_units(e,who).filter(func(r):return r.uid!=c.uid),1,1,"牺牲另一个单位");g.cost=true
   return e.Pack.selection([g,e.Pack.group(e.Pack.zone(e,who,"grave"),1,1,"放到牌库底")],k)
  "sanae_search":
   var g=e.Pack.group(refs(e,e.players[who].hand.filter(func(u):return "绿" in e.cards[u.card_id].colors)),1,1,"弃置一张绿色牌");g.cost=true
   return e.Pack.selection([g],k)
  "hina_redirect":
   var result=[]
   for s in e.stack:
    var info=e.cards[s.get("card",s.get("source")).card_id]
    if info.kind!="符卡" and not (s.kind=="ability" and info.kind in ["单位","自机"]):continue
    for r in e.Pack.flatten(s.target):
     if not r.has("uid") and not r.has("player"):continue
     var substituted=replace_target(s.target,r,e.ref_target(c))
     var choices=e.targets_for(s.card.card_id,s.owner) if s.kind=="card" else e.Extra.activation_options(e,s.source,s.effect) if s.get("activation",false) else e.trigger_options(s)
     if e.Pack.choice_valid(e,choices,substituted):result.append({"stack_id":s.id,"redirect":r})
   return result
 return []
static func replace_target(t: Dictionary,old: Dictionary,replacement: Dictionary) -> Dictionary:
 if t==old:return replacement.duplicate(true)
 var copy=t.duplicate(true)
 if copy.has("parts"):copy.parts=copy.parts.map(func(r):return replace_target(r,old,replacement))
 if copy.has("picks"):
  for i in range(copy.picks.size()):copy.picks[i]=copy.picks[i].map(func(r):return replace_target(r,old,replacement))
 return copy
static func pay_activation(e,c: Dictionary,k: String,t: Dictionary):
 if k in Cat.ACTIVATIONS:Cat.pay_activation(e,c,k,t);return
 if k in Batch.ACTIVATIONS:Batch.pay_activation(e,c,k);return
 if k=="hina_redirect":e.players[c.owner].life-=2
 if k in ["clown_sweep","kaguya_end"]:e.tap_card(c)
 if k=="suika_counter":c.plus_counters-=1
 if k=="satori_discard":e.move_to(c,"exile")
 if k in ["alice_recycle","kanako_blast"]:
  for r in e.Pack.picked(t):e.sacrifice(e.find_card(r.uid))
 if k=="sanae_search":
  for r in e.Pack.picked(t):e.move_to(e.find_card(r.uid),"grave")
 if k=="sanae_search":c.sanae_used=true
static func resolve_activation(e,entry: Dictionary):
 if entry.effect in Cat.ACTIVATIONS:Cat.resolve_activation(e,entry);return
 if entry.effect in Batch.ACTIVATIONS:Batch.resolve_activation(e,entry);return
 var k=entry.effect;var who=entry.owner;var t=entry.target;var c=e.find_card(entry.source.uid)
 var same=not c.is_empty() and c.zone=="field" and c.epoch==entry.source.epoch
 match k:
  "hatate_return":
   if same:e.move_to(c,"hand")
  "hina_redirect":
   if same:
    for s in e.stack:
     if s.id==t.stack_id:s.target=replace_target(s.target,t.redirect,e.ref_target(c))
  "clown_sweep":
   for u in e.units(0)+e.units(1):e.damage_target(e.ref_target(u),1)
  "satori_discard":continue_choice(e,entry,"satori_discard_choice",pick(e,e.Pack.zone(e,t.player,"hand"),mini(1,e.players[t.player].hand.size()),1,"选择弃置的手牌"))
  "alice_search","sanae_search":resolve_trigger(e,entry)
  "alice_recycle":
   for r in e.Pack.picked(t,1):
    if valid(e,r):e.move_to(e.find_card(r.uid),"deck")
  "kanako_blast":
   for r in e.Pack.picked(t,1):
    if unit(e,r) and e.find_card(r.uid).damage==0:e.damage_target(r,2)
  "kaguya_end":e.draw(who);end_now(e)
  "suika_counter":
   if unit(e,t):plus(e,e.find_card(t.uid),1)
static func wither(e) -> bool:
 var source=e.damage_context.get("source",{})
 return not source.is_empty() and has(e.cards[source.card_id],"momoyo_wither")
static func lifesteal(e,c: Dictionary) -> int:
 var amount=0
 for k in e.cards[c.card_id].get("keywords",[]):
  if k.begins_with("吸血"):amount+=int(k.trim_prefix("吸血"))
 if "红" in e.Pack.colors(e,c):amount+=e.units(c.owner).filter(func(u):return has(e.cards[u.card_id],"remilia_lifelink")).size()
 return amount
static func on_damage(e,t: Dictionary,amount: int):
 var source=e.damage_context.get("source",{})
 if source.is_empty() or not e.damage_context.get("combat",false) or amount<=0:return
 if unit(e,t):
  if has(e.cards[source.card_id],"medicine_kill"):event(e,source,"medicine_destroy",false,{"ref":t})
  if has(e.cards[source.card_id],"komachi_minus"):event(e,source,"komachi_counters",false,{"ref":t})
 elif t.has("player") and t.player!=source.owner and enabled(e,source,"komachi_coins"):
  event(e,source,"komachi_coin",false,{"player":t.player})
static func cleanup(e):
 for c in (e.players[0].field+e.players[1].field).duplicate():
  var control=c.get("control_return",{})
  if not control.is_empty():
   e.present_move(c,"field",control.owner);e.players[c.owner].field.erase(c);c.owner=control.owner;e.players[c.owner].field.append(c);c.erase("control_return");c.entered_turns=e.players[c.owner].turns
static func end_now(e):
 for s in e.stack.duplicate():
  if s.kind=="card":e.move_to(s.card,"exile")
 e.stack.clear();e.triggers.clear();e.pending={};e.combat={};e.passes=0
 # The jade branch sacrifice is consumed by this skipped end step.
 e.delayed=e.delayed.filter(func(d):return int(d.get("expires_turn",2147483647))>e.turn)
 # Finishing immediately skips end-step events but still performs cleanup/discard.
 e.phase="end";e.cleanup_end()
static func register_tokens(e):
 for kind in ["imp","pillar","kobito","ghost","bat","frog"]:
  var names={"imp":"小鬼","pillar":"御柱","kobito":"小人","ghost":"亡灵","bat":"蝙蝠","frog":"青蛙"}
  e.cards["roster_token_"+kind]={"name":names[kind],"kind":"单位","character":names[kind],"title":"","race":[names[kind]],"colors":["黑"],"cost":{},"power":1,"health":1,"spirit":1,"keywords":[],"abilities":[],"fast":false,"requires_character":"","rules_text":"","token":true,"constructible":false}
static func create_token(e,who: int,kind: String,n: int,colors: Array,keywords: Array=[]) -> Dictionary:
 var id="roster_token_"+kind+"_"+str(e.next_uid);var info=e.cards["roster_token_"+kind].duplicate(true)
 info.power=n;info.health=n;info.spirit=n;info.colors=colors;info.keywords=keywords.duplicate()
 if kind=="pillar":info.spirit=1;info.keywords.append("英勇")
 if kind=="ghost":info.spirit=0;info.keywords.append("不占战场格")
 e.cards[id]=info
 var c=e.make_card(id,who,"token")
 return c if e.enter_field(c,who) else {}
static func copy_idol(e,who: int,source: Dictionary) -> Dictionary:
 var id="roster_copy_"+str(e.next_uid);var info=e.cards[source.card_id].duplicate(true)
 info.name="偶像";info.character="偶像";info.title="";info.race=["埴轮"];info.token=true;info.constructible=false;info.copy_source_id=source.card_id
 e.cards[id]=info
 var c=e.make_card(id,who,"token")
 return c if e.enter_field(c,who) else {}
static func target_survives(e,id: String,t: Dictionary) -> bool:
 if id in Cat.SPELLS:return Cat.target_survives(e,id,t)
 if has(e.cards[id],"emotions") and e.Pack.flatten(t).is_empty():return true
 if key(e.cards[id],["discard_draw","door_reveal"])!="":return true
 var targets=e.Pack.flatten(t)
 return targets.is_empty() or targets.any(func(r):return valid(e,r))
static func ai_target(e,who: int,c: Dictionary,options: Array) -> Dictionary:
 var k=key(e.cards[c.card_id],SPELLS+UCS_SPELLS);var choices=options.filter(func(t):return e.payment(who,e.cast_cost(who,c,t)).ways>0)
 if choices.is_empty():return {}
 if not e.cards[c.card_id].get("variable_cost","").is_empty():
  choices.sort_custom(func(a,b):return int(a.get("x",0))>int(b.get("x",0)))
  choices=choices.filter(func(t):return t.get("x",0)==choices[0].get("x",0))
 var helpful=k in ["counters_x","draw_x","leader_mark","unblock_reset","gather_counters"]
 var harmful=k in ["destroy_any","gungnir","destroy_item_field","exile_permanent","bounce_small","flower_damage","tap_destroy","perfect_freeze"]
 if helpful or harmful:
  var preferred=choices.filter(func(t):return t.get("player",-1)==(who if helpful else 1-who) if t.has("player") else t.has("uid") and e.find_card(t.uid).owner==(who if helpful else 1-who))
  if not preferred.is_empty():choices=preferred
 if k in ["discard_draw","door_reveal"]:
  choices=choices.duplicate(true)
  for spec in choices:
   for g in spec.get("selection",[]):g.pool=g.pool.filter(func(r):return r.uid!=c.uid)
 return e.Pack.ai_target(e,who,choices,k)
static func on_coin(e,who: int):
 for c in e.players[who].field:
  if has(e.cards[c.card_id],"coin_anthem"):event(e,c,"coin_damage")
static func on_ability_announced(e,entry: Dictionary):
 if entry.get("tax_announced",false) or entry.kind!="ability" or entry.get("awaiting_target",false):return
 entry.tax_announced=true
 var opponent=1-entry.owner
 if not e.Pack.flatten(entry.target).any(func(r):return r.get("player",-1)==opponent or unit(e,r) and e.find_card(r.uid).owner==opponent):return
 for c in e.players[opponent].field:
  if has(e.cards[c.card_id],"backpack"):event(e,c,"backpack_tax",false,{"id":entry.id,"payer":entry.owner})
static func tax_options(e,who: int) -> Array:
 var result=[{"none":true,"mode":"不支付"}]
 for resource in e.source_resources(who):
  for color in resource.colors:
   var t={"color":color,"mode":"支付1点"}
   if resource.uid<0:t.none=true;t.mode="使用红薯支付1点"
   else:t.merge(e.Pack.ref(e,e.find_card(resource.uid)))
   result.append(t)
 return result

