extends "res://scripts/rules/duel_engine.gd"
## Read model only. All rule mutations are requests to the room authority.
var session
var seat=0
var queries={}
var grant_payment=false
func apply_snapshot(snapshot: Dictionary):
 for k in snapshot.state:set(k,snapshot.state[k])
 queries=snapshot.queries
 for id in snapshot.definitions:cards[id]=snapshot.definitions[id]
 if not cards.has("back"):
  cards.back=cards.values()[0].duplicate(true)
  cards.back.merge({"name":"未公开","kind":"隐藏","colors":[],"cost":{},"abilities":[],"keywords":[],"rules_text":"","power":0,"health":0,"spirit":0},true)
 paid_cast_uid=-1;payment_memo={};payment_groups=[]
func request(name: String,args: Array=[]) -> String:
 return session.submit({"name":name,"args":args,"paid_uid":paid_cast_uid,"grant_payment":grant_payment})
func find_card(uid: int) -> Dictionary:
 var found=super.find_card(uid)
 return found if not found.is_empty() else queries.get("lookup",{}).get(uid,{})
func source_resources(who: int) -> Array:return queries.get("resources",[]) if who==seat else []
func legal_casts(who: int,fast_only: bool=false) -> Array:return queries.get("fast_legal" if fast_only else "legal",[]).map(func(uid):return find_card(uid)) if who==seat else []
func cast_error(who: int,uid: int) -> String:return queries.get("cast",{}).get(uid,"当前不能使用") if who==seat else "不是你的卡牌"
func targets_for(_id: String,_acting: int=-1,source_uid: int=-1) -> Array:return queries.get("targets",{}).get(str(source_uid)+(":paid" if paid_cast_uid==source_uid else ":free"),[])
func activation_options(c: Dictionary,key: String) -> Array:return queries.get("extension_targets",{}).get(str(c.uid)+":"+key,[])
func available_actions(who: int,uid: int,include_disabled: bool=false) -> Array:
 var actions=queries.get("actions",{}).get(uid,[]) if who==seat else []
 return actions if include_disabled else actions.filter(func(a):return a.enabled)
func extra_action(c: Dictionary) -> Dictionary:return queries.get("extra",{}).get(c.get("uid",0),{})
func extension_activation_error(who: int,c: Dictionary,key: String="") -> String:
 return "" if available_actions(who,c.uid).any(func(a):return a.type=="extension" and (key.is_empty() or a.key==key)) else "当前不能发动"
func has_response(who: int) -> bool:return who==seat and queries.get("response",false)
func ability_targets() -> Array:return queries.get("ability_targets",[])
func legal_blockers() -> Array:return queries.get("blockers",[]).map(func(uid):return find_card(uid))
func stat(c: Dictionary,key: String) -> int:return queries.get("stats",{}).get(c.get("uid",0),{}).get(key,super.stat(c,key))
func summoning_sick(c: Dictionary) -> bool:return queries.get("sick",{}).get(c.get("uid",0),false)
func has_leader_ability(c: Dictionary) -> bool:return queries.get("leader",{}).get(c.get("uid",0),false)
func has_haste(c: Dictionary) -> bool:return queries.get("haste",{}).get(c.get("uid",0),false)
func can_possess(c: Dictionary) -> bool:return queries.get("possess",{}).get(c.get("uid",0),false)
func can_attack(who: int,uid: int) -> bool:return available_actions(who,uid).any(func(a):return a.type=="attack")
func offers_free_cast(_who: int,c: Dictionary) -> bool:return queries.get("free",{}).get(c.get("uid",0),false)
func set_granted_payment(pay_colors: bool):
 if pending.get("kind","")!="effect_choice" or pending.trigger.effect!="cat:grant":return
 grant_payment=pay_colors;pending.trigger.data.payment_chosen=true
 paid_cast_uid=pending.trigger.data.ref.uid if pay_colors else -1
 pending.options=queries.get("grant_options",{}).get(str(pay_colors),[]);revision+=1
func mulligan(_who: int,uids: Array):request("mulligan",[uids])
func pass_priority(_who: int):request("pass_priority")
func possession(palette_uid: int=-1,hand_uid: int=-1):request("possession",[palette_uid,hand_uid])
func discard(uids: Array):request("discard",[uids])
func attack(_who: int,uid: int,target: Dictionary={},plan: Array=[]):request("attack",[uid,target,plan])
func block(uids: Array):request("block",[uids])
func combat_damage(allocation: Dictionary):request("combat_damage",[allocation])
func surrender(_who: int):request("surrender")
func choose_trigger_order(index: int):request("choose_trigger_order",[index])
func choose_trigger(target: Dictionary):request("choose_trigger",[target])
func choose_return(yes: bool):request("choose_return",[yes])
func choose_grave_replacement(to_field: bool):request("choose_grave_replacement",[to_field])
func choose_effect(target: Dictionary):request("choose_effect",[target])
func choose_timer(delta: int):request("choose_timer",[delta])
func commit_cast(_who: int,uid: int,target: Dictionary,plan: Array) -> String:return request("commit_cast",[uid,target,plan])
func commit_ability(_who: int,uid: int,index: int,target: Dictionary,plan: Array) -> String:return request("commit_ability",[uid,index,target,plan])
func commit_extension(_who: int,uid: int,target: Dictionary,plan: Array,key: String="") -> String:return request("commit_extension",[uid,target,plan,key])
func ai_step(_who: int=1):pass
func debug_move(_uid: int,_destination: String) -> String:return "联网对局不开放调试移牌"
