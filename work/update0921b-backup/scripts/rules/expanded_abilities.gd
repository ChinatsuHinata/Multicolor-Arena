extends RefCounted
## Explicit event/choice handlers. Card text is display data, never executable code.
static func has(info: Dictionary,effect: String) -> bool:
 return info.abilities.any(func(a): return a.get("实现")=="extension" and a.get("参数",{}).get("效果")==effect)
static func parameters(info: Dictionary,effect: String) -> Dictionary:
 for binding in info.abilities:
  if binding.get("实现")=="extension" and binding.get("参数",{}).get("效果")==effect: return binding["参数"]
 return {}
static func keyword(e,c: Dictionary,k: String) -> bool:
 if c.is_empty(): return false
 return e.Roster.keyword(e,c,k) or e.Pack.dynamic_keyword(e,c,k) or k in e.cards[c.card_id].get("keywords",[]) or c.get("modifiers",[]).any(func(m): return m.get(k,false))
static func cost_value(e,c: Dictionary) -> int:
 var n=int(c.get("cast_x",0))*int(e.cards[c.card_id].get("variable_multiplier",1)) if c.zone=="stack" else 0
 for v in e.cards[c.card_id].cost.values(): n+=int(v)
 return n
static func refs(e,list: Array) -> Array:
 return list.map(func(c): return e.ref_target(c))
static func unit_refs(e,who: int=-1) -> Array:
 return refs(e,e.units(0)+e.units(1) if who<0 else e.units(who))
static func zone_refs(e,zone: String,who: int=-1) -> Array:
 var result=[]
 for p in range(2):
  if who>=0 and who!=p: continue
  for c in e.players[p][zone]:
   var t=e.ref_target(c); t.zone=zone; result.append(t)
 return result
static func no_target() -> Array: return [{"none":true}]
static func add_mode(options: Array,mode: String) -> Array:
 return options.map(func(t): var result=t.duplicate(true); result.mode=mode; return result)
static func spell_options(e,id: String,who: int) -> Variant:
 var roster=e.Roster.spell_options(e,id,who)
 if roster!=null:return roster
 var precon=e.Pack.spell_options(e,id,who)
 if precon!=null: return precon
 var all_units=unit_refs(e)
 match id:
  "133":
   var result=[]
   for a in unit_refs(e,who):
    for b in unit_refs(e,1-who): result.append({"parts":[a,b]})
   return result
  "94","163":
   var result=[]
   for u in e.units(who):
    var candidates=all_units if id=="94" else zone_refs(e,"grave",who).filter(func(t): var c=e.find_card(t.uid); return e.is_unit(c) and cost_value(e,c)<=cost_value(e,u))
    for t in candidates:
     if id=="94" and t.uid==u.uid: continue
     var pick=t.duplicate(); pick.sacrifice=e.ref_target(u); pick.sacrifice_value=cost_value(e,u); result.append(pick)
   return result
  "106","120","141","174": return no_target()
  "110": return add_mode(all_units,"先制")+add_mode(all_units,"歼灭")
  "118":
   var result=[]
   for entry in e.stack:
    if entry.owner==who: continue
    var targets=[entry.target]+entry.target.get("parts",[])
    var hits=targets.any(func(t):
     var c=e.find_card(t.get("uid",-1))
     return not c.is_empty() and c.owner==who and c.zone=="field" and (e.cards[c.card_id].character=="魂魄妖梦" or c.card_id=="token_halfghost"))
    if hits: result.append({"stack_id":entry.id})
   return result
  "130": return all_units.filter(func(t): return e.stat(e.find_card(t.uid),"spirit")>=3)
  "131":
   var result=add_mode(all_units,"不会被消灭")+[{"player":0,"mode":"移除墓地"},{"player":1,"mode":"移除墓地"}]
   for entry in e.stack:
    if entry.kind=="card" and "非符" in e.cards[entry.card.card_id].get("spell_type",""): result.append({"stack_id":entry.id,"mode":"反制非符"})
   return result
  "139": return all_units.filter(func(t): return e.cards[e.find_card(t.uid).card_id].kind!="自机")
  "143": return add_mode(zone_refs(e,"grave",who).filter(func(t): return e.is_unit(e.find_card(t.uid)) and cost_value(e,e.find_card(t.uid))<=3),"移回战场")+[{"player":1-who,"mode":"牺牲单位"},{"player":1-who,"mode":"失去生命"}]
  "147","177": return all_units
  "162": return e.ability_targets()
  "176":
   var choices=add_mode(all_units,"造成2点伤害")+add_mode(all_units,"横置")+[{"none":true,"mode":"抓一张牌"}]
   var result=[]
   for a in choices:
    for b in choices: result.append({"parts":[a,b]})
   return result
 return null

static func valid(e,t: Dictionary) -> bool:
 if t.has("picks"):
  var list=e.Pack.flatten(t); return list.is_empty() or list.any(func(x): return valid(e,x))
 if t.has("parts"): return t.parts.any(func(x): return valid(e,x))
 if t.has("none") or t.has("color") and not t.has("uid"): return true
 if t.has("stack_id"): return e.stack.any(func(s): return s.id==t.stack_id)
 if t.has("zone"):
  var c=e.find_card(t.get("uid",-1))
  return not c.is_empty() and c.zone==t.zone and c.epoch==t.epoch
 return e.target_valid(t)
static func event(e,c: Dictionary,effect: String,optional: bool=false,data: Dictionary={}):
 if e.Pack.trigger_locked(e): return
 e.Cat.enqueue(e,{"extended":true,"owner":c.owner,"source":c.duplicate(true),"effect":effect,"optional":optional,"data":data.duplicate(true),"name":e.cards[c.card_id].name})
static func on_enter(e,c: Dictionary):
 e.Roster.on_enter(e,c)
 e.Pack.on_enter(e,c)
 var info=e.cards[c.card_id]
 if e.DB.has_ability(info,"marisa_enter"):e.queue_trigger(c.owner,c,int(e.DB.ability(info,"marisa_enter")["数值"]),"进战场能力")
 if has(info,"leader_enter_modes") and e.has_leader_ability(c): event(e,c,"leader_enter_modes",true)
 for key in ["enter_haste","enter_drain","enter_grave_damage","enter_sweep","enter_color_evasion","enter_blink","enter_fight","enter_palette_replace","enter_unblockable","enter_halfghost"]:
  if has(info,key): event(e,c,key,key in ["enter_grave_damage","enter_blink","enter_palette_replace"])
 if e.is_unit(c) and info.colors.any(func(color): return color in ["红","黄"]):
  for hand in e.players[c.owner].hand:
   if has(e.cards[hand.card_id],"hand_autumn"): event(e,hand,"hand_autumn",true,{"ref":e.ref_target(hand)})
static func on_leave(e,c: Dictionary):
 e.Pack.on_leave(e,c)
 if has(e.cards[c.card_id],"leave_ufo"): event(e,c,"leave_ufo",true)
static func on_death(e,c: Dictionary,before: Dictionary):
 var old_owner=e.catalogue_death_owner;e.catalogue_death_owner=before.owner
 e.catalogue_death_depth+=1
 _on_death_core(e,c,before)
 e.catalogue_death_depth-=1;e.catalogue_death_owner=old_owner
static func _on_death_core(e,c: Dictionary,before: Dictionary):
 e.Roster.on_death(e,c,before)
 e.Pack.on_death(e,c,before)
 if not e.is_unit(before): return
 var info=e.cards[before.card_id]
 var data={"ref":e.ref_target(c)}
 data.ref.zone="grave"
 for key in ["death_draw_life","death_drain","death_palette","death_damage","death_poverty","death_six"]:
  if has(info,key): event(e,before,key,key in ["death_draw_life","death_damage","death_poverty"],data)
 if keyword(e,before,"结晶"): event(e,before,"crystal",true,data)
 if has(info,"death_undying") and before.get("plus_counters",0)==0: event(e,before,"death_undying",true,data)
 if has(info,"spell_rebirth") and before.get("spell_damage",false) and e.has_leader_ability(before): event(e,before,"spell_rebirth",true,data)
 for unit in e.death_observers if not e.death_observers.is_empty() else e.units(0)+e.units(1):
  if has(e.cards[unit.card_id],"death_devour") and not before.get("token",false): event(e,unit,"death_devour",true,data)
 # A dying leader sees its own death; retain last known information.
 var observers=(e.death_observers.filter(func(u): return u.owner==c.owner) if not e.death_observers.is_empty() else e.units(c.owner)).duplicate()
 if has(info,"leader_death_damage") and not observers.any(func(u): return u.uid==before.uid): observers.append(before)
 for unit in observers:
  if has(e.cards[unit.card_id],"leader_death_damage") and e.has_leader_ability(unit):
   # A single death must offer this observer exactly one activation, even if
   # cleanup sees the same death again. A new field epoch is a new death.
   var key="%d:%d/%d:%d" % [unit.uid,unit.epoch,before.uid,before.epoch]
   if e.death_trigger_events.has(key): continue
   e.death_trigger_events[key]=true
   var params=parameters(e.cards[unit.card_id],"leader_death_damage")
   event(e,unit,"leader_death_damage",true,{"amount":int(params.get("伤害",1)),"limit":int(params.get("每回合次数",2)),"death":e.ref_target(before)})

static func trigger_options(e,t: Dictionary) -> Array:
 if t.get("roster",false):return e.Roster.trigger_options(e,t)
 if t.get("precon",false): return e.Pack.trigger_options(e,t)
 var who=t.owner; var source=t.source; var all_units=unit_refs(e)
 match t.effect:
  "end_grave_return": return zone_refs(e,"grave",who).filter(func(x): return e.cards[e.find_card(x.uid).card_id].kind=="单位")
  "leader_enter_modes": return add_mode(all_units,"造成2点伤害")+add_mode(all_units,"横置")+[{"none":true,"mode":"抓一张牌"}]
  "enter_haste": return all_units
  "enter_grave_damage":
   var result=[]
   for dead in zone_refs(e,"grave",who).filter(func(x): return e.is_unit(e.find_card(x.uid))):
    for aim in e.ability_targets(): result.append({"parts":[dead,aim]})
   return result
  "returned_spirit_damage","death_damage","leader_death_damage","counter_six":
   if t.effect=="leader_death_damage" and e.usage_count(source.uid,"death_ping")>=int(t.get("data",{}).get("limit",2)): return []
   return e.ability_targets()
  "enter_color_evasion":
   var result=[]
   for target in unit_refs(e,who):
    for color in e.COLORS:
     var x=target.duplicate(); x.color=color; result.append(x)
   return result
  "enter_blink": return unit_refs(e,who).filter(func(x): return x.uid!=source.uid)
  "enter_fight": return unit_refs(e,1-who)
  "enter_palette_replace": return zone_refs(e,"palette",1-who)
  "death_poverty":
   var cards=zone_refs(e,"palette",1-who); var result=cards.duplicate(true)
   for a in range(cards.size()):
    for b in range(a+1,cards.size()): result.append({"parts":[cards[a],cards[b]]})
   return result
  "crystal": return zone_refs(e,"palette",who).filter(func(x): return e.find_card(x.uid).tapped)
  "sacrifice_choice": return unit_refs(e,who)
 return no_target()

static func resolve_trigger(e,t: Dictionary):
 if t.get("roster",false):e.Roster.resolve_trigger(e,t);return
 if t.get("precon",false): e.Pack.resolve_trigger(e,t); return
 var effect=t.effect; var who=t.owner; var target=t.target; var source=t.source; var data=t.get("data",{})
 var c=e.find_card(source.uid)
 var original=not c.is_empty() and c.epoch==source.epoch and c.zone=="field"
 var dead=e.find_card(data.get("ref",{}).get("uid",-1))
 var dead_valid=data.has("ref") and valid(e,data.ref)
 match effect:
  "end_grave_return":
   if valid(e,target): e.move_to(e.find_card(target.uid),"hand")
  "leader_enter_modes":
   match target.mode:
    "造成2点伤害": e.damage_target(target,2)
    "横置":
     if valid(e,target): e.tap_card(e.find_card(target.uid))
    "抓一张牌": e.draw(who)
  "enter_haste": e.apply_turn_buff(target,{"疾行":true})
  "enter_drain": e.players[1-who].life-=1
  "enter_sweep":
   for u in e.units(1-who): e.damage_target(e.ref_target(u),1)
  "enter_grave_damage":
   if valid(e,target.parts[0]):
    var picked=e.find_card(target.parts[0].uid); var spirit=e.stat(picked,"spirit")
    e.move_to(picked,"hand")
    e.damage_target(target.parts[1],spirit)
  "returned_spirit_damage": e.damage_target(target,data.amount)
  "enter_color_evasion": e.apply_turn_buff(target,{"不可阻挡颜色":target.color})
  "enter_blink":
   if valid(e,target):
    var u=e.find_card(target.uid); e.move_to(u,"exile")
    e.delayed.append({"owner":who,"phase":"end","effect":"return_exile","ref":e.ref_target(u),"zone":"exile"})
  "enter_fight":
   if original and valid(e,target) and e.combat.is_empty():
    e.combat_queue.append({"attacker":e.ref_target(c),"owner":who,"blockers":[target],"blocked":true,"step":"block_window","forced":true})
  "enter_palette_replace":
   if valid(e,target):
    e.move_to(e.find_card(target.uid),"grave")
    if not e.players[1-who].deck.is_empty():
     var u=e.players[1-who].deck[0]; e.move_to(u,"palette"); u.poverty=1
  "enter_unblockable":
   if original: e.apply_turn_buff(e.ref_target(c),{"不能被阻挡":true})
  "hand_autumn":
   if not c.is_empty() and c.zone=="hand" and c.epoch==data.ref.epoch and e.field_error(c,who).is_empty(): e.reveal_card(c);e.detach(c); e.enter_field(c,who)
  "death_draw_life": e.draw(who); e.gain_life(who,1)
  "death_drain": e.players[1-who].life-=2; e.gain_life(who,1)
  "death_damage": e.damage_target(target,2)
  "death_palette":
   if dead_valid: e.move_to(dead,"palette"); dead.tapped=true
  "death_poverty":
   for chosen in target.get("parts",[target]):
    if valid(e,chosen): e.find_card(chosen.uid).poverty=1
  "death_undying":
   if dead_valid and e.field_error(dead,who).is_empty():
    e.detach(dead)
    if e.enter_field(dead,who): e.Roster.plus(e,dead,1,who)
  "death_devour":
   if dead_valid:
    e.move_to(dead,"exile")
    if original: e.Roster.plus(e,c,1,who)
  "death_six":
   for u in e.units(0)+e.units(1): e.damage_target(e.ref_target(u),6)
  "spell_rebirth":
   if dead_valid: e.delayed.append({"owner":who,"phase":"prepare","effect":"return_grave","ref":e.ref_target(dead),"zone":"grave"})
  "crystal":
   if dead_valid and valid(e,target) and e.find_card(target.uid).tapped:
    var palette=e.find_card(target.uid); e.move_to(palette,"grave"); e.move_to(dead,"palette"); dead.tapped=false
  "leave_ufo": create_token(e,who,"token_ufo")
  "enter_halfghost": create_token(e,who,"token_halfghost")
  "leader_death_damage": e.damage_target(target,int(data.get("amount",1)))
  "counter_six": e.damage_target(target,6)
  "sacrifice_choice":
   if valid(e,target): e.sacrifice(e.find_card(target.uid))
  "delayed_return":
   var u=e.find_card(data.ref.uid)
   if not u.is_empty() and u.epoch==data.ref.epoch and u.zone==data.zone and e.field_error(u,u.owner).is_empty(): e.detach(u); e.enter_field(u,u.owner)
  "combat_exile_target":
   # Do not follow the damaged unit into the graveyard or a new field epoch.
   if e.target_valid(data.ref,true): e.move_to(e.find_card(data.ref.uid),"exile")
  "token_sacrifice":
   if e.Cat.character(e,source,"半灵") and not e.Cat.with_key(e,who,"spell-fdn-012").is_empty():return
   if original: e.sacrifice(c)
  "miracle":
   if not c.is_empty() and c.zone=="hand" and c.epoch==source.epoch:
    e.detach(c); e.shift(c,"stack")
    e.stack.append({"id":e.next_stack,"kind":"card","card":c,"owner":who,"target":{"none":true},"name":e.cards[c.card_id].name})
    e.next_stack+=1; e.priority=1-who; e.passes=0
    e.note("奇迹 · "+e.cards[c.card_id].name)
    e.Roster.on_cast(e,c,who,"hand")
    e.Pack.on_cast(e,c,who,{"none":true})
    if e.cards[c.card_id].kind=="符卡":e.Effects.spell_used(e,who)

static func spell_resolve(e,entry: Dictionary) -> bool:
 if e.Roster.spell_resolve(e,entry):return true
 if e.Pack.spell_resolve(e,entry): return true
 var id=entry.card.card_id; var t=entry.target; var who=entry.owner
 if spell_options(e,id,who)==null: return false
 e.resolving_spell=true
 match id:
  "133":
   if t.parts.all(func(x): return valid(e,x)):
    e.combat_queue.append({"attacker":t.parts[0],"owner":who,"blockers":[t.parts[1]],"blocked":true,"step":"block_window","forced":true})
  "94": e.damage_target(t,5)
  "106": e.draw(who,2)
  "110": e.apply_turn_buff(t,{t.mode:true})
  "118":
   if valid(e,t):
    e.counter_entry(t.stack_id)
    event(e,entry.card,"counter_six")
  "120":
   e.enter_field(entry.card,who); e.add_timer(entry.card,3); e.resolving_spell=false; return true
  "130":
   if valid(e,t) and e.stat(e.find_card(t.uid),"spirit")>=3: e.destroy(e.find_card(t.uid)); e.players[who].life-=2
  "131":
   match t.mode:
    "不会被消灭": e.apply_turn_buff(t,{"不会被消灭":true})
    "移除墓地":
     for c in e.players[t.player].grave.duplicate(): e.move_to(c,"exile")
    "反制非符": e.counter_entry(t.stack_id)
  "139": e.draw(who); e.damage_target(t,e.players[who].hand.size())
  "141":
   for p in e.players:
    for c in p.field.duplicate():
     if e.cards[c.card_id].kind!="符卡": e.move_to(c,"exile")
  "143":
   match t.mode:
    "移回战场":
     if valid(e,t):
      var c=e.find_card(t.uid)
      if e.field_error(c,who).is_empty(): e.detach(c); e.enter_field(c,who)
    "牺牲单位":
     var dummy=entry.card.duplicate(); dummy.owner=t.player; event(e,dummy,"sacrifice_choice")
    "失去生命": e.players[t.player].life-=3
  "147": e.apply_turn_buff(t,{"攻击力":-1,"血量":-1,"灵力":3})
  "162": e.damage_target(t,3)
  "163":
   if valid(e,t):
    var c=e.find_card(t.uid)
    if e.field_error(c,who).is_empty(): e.detach(c); e.enter_field(c,who)
  "176":
   for part in t.parts:
    if not valid(e,part): continue
    match part.mode:
     "造成2点伤害": e.damage_target(part,2)
     "横置": e.tap_card(e.find_card(part.uid))
     "抓一张牌": e.draw(who)
  "177": e.apply_turn_buff(t,{"攻击力":2,"血量":-1,"灵力":1,"防止伤害":true})
 e.judge()
 e.resolving_spell=false
 e.to_grave(entry.card)
 return true

static func create_token(e,who: int,id: String):
 var c=e.make_card(id,who,"token"); c.token=true
 if e.enter_field(c,who): e.delayed.append({"owner":-1,"phase":"end","effect":"token_sacrifice","ref":e.ref_target(c),"zone":"field"})
static func register_tokens(e):
 e.Roster.register_tokens(e)
 for id in ["token_ufo","token_halfghost"]:
  var half=id=="token_halfghost"
  e.cards[id]={"name":"半灵" if half else "飞碟","kind":"单位","colors":["黑","绿"] if half else ["红","黑"],"cost":{},"character":"半灵" if half else "飞碟","title":"","race":["半灵"] if half else ["飞碟"],"power":4 if half else 2,"health":2 if half else 1,"spirit":2 if half else 1,"keywords":["疾行","先制"] if half else ["疾行"],"fast":false,"requires_character":"","abilities":[],"rules_text":"疾行、先制。下个结束阶段开始时牺牲。" if half else "疾行。下个结束阶段开始时牺牲。"}
static func activation_kind(info: Dictionary) -> String:
 var roster=preload("res://scripts/rules/excel_abilities.gd")
 var k=roster.key(info,roster.ACTIVATIONS)
 if not k.is_empty():return k
 var precon=preload("res://scripts/rules/precon_abilities.gd").activation_kind(info)
 if not precon.is_empty(): return precon
 for key in ["grave_return","grave_reanimate","exile_grave","sacrifice_buff","leader_bounce"]:
  if has(info,key): return key
 return ""
static func activation_options(e,c: Dictionary,key: String) -> Array:
 if key in e.Roster.ACTIVATIONS:return e.Roster.filter_options(e,e.Roster.activation_options(e,c,key),c.owner,false)
 if key in e.Pack.ACTIVATIONS: return e.Pack.activation_options(e,c,key)
 match key:
  "grave_return": return no_target()
  "grave_reanimate": return zone_refs(e,"hand",c.owner)
  "exile_grave": return zone_refs(e,"grave")
  "sacrifice_buff","leader_bounce": return unit_refs(e,c.owner)
 return []
static func activation_cost(key: String) -> Dictionary:
 var roster=preload("res://scripts/rules/excel_abilities.gd")
 if key in roster.ACTIVATIONS:return roster.activation_cost(key)
 var pack=preload("res://scripts/rules/precon_abilities.gd")
 if key in pack.ACTIVATIONS: return pack.activation_cost(key)
 return {"红":1} if key=="grave_return" else {"绿":1,"黑":1} if key=="grave_reanimate" else {}
static func resolve_activation(e,entry: Dictionary):
 if entry.effect in e.Roster.ACTIVATIONS:e.Roster.resolve_activation(e,entry);return
 if entry.effect in e.Pack.ACTIVATIONS: e.Pack.resolve_activation(e,entry); return
 var c=e.find_card(entry.source.uid); var t=entry.target
 var same=not c.is_empty() and c.epoch==entry.source.epoch
 match entry.effect:
  "grave_return":
   if same and c.zone=="grave": e.move_to(c,"hand")
  "grave_reanimate":
   if same and c.zone=="grave" and e.field_error(c,c.owner).is_empty():
    e.detach(c)
    if e.enter_field(c,c.owner): c.tapped=true
  "exile_grave":
   if valid(e,t):
    var picked=e.find_card(t.uid); var unit=e.is_unit(picked); e.move_to(picked,"exile")
    if unit: e.gain_life(entry.owner,1); e.players[1-entry.owner].life-=1
  "sacrifice_buff":
   if same and c.zone=="field": e.apply_turn_buff(e.ref_target(c),{"攻击力":1,"血量":1})
  "leader_bounce":
   if valid(e,t): e.move_to(e.find_card(t.uid),"hand")
