extends "res://scripts/tutorial/scripted_duel.gd"
## Observe the same entry points used by the native battle UI and command gateway.
signal command_accepted(seat: int,command: Dictionary,action: Dictionary)
signal random_observed(kind: String,value: int)
var command_filter: Callable
var action_encoder: Callable
var command_depth=0
var record_random_without_advance=false

func begin_command(seat: int,command: Dictionary) -> Dictionary:
 if command_depth==0 and command_filter.is_valid() and not command_filter.call(seat,command):return {}
 var action=action_encoder.call(seat,command) if command_depth==0 and action_encoder.is_valid() else {}
 var token={"seat":seat,"command":command.duplicate(true),"action":action,"revision":revision,"outer":command_depth==0}
 command_depth+=1
 return token

func end_command(token: Dictionary):
 command_depth-=1
 if token.outer and revision!=token.revision:command_accepted.emit(token.seat,token.command,token.action)

func roll_coin() -> bool:
 var state=rng.state;var value=super.roll_coin()
 if record_random_without_advance:rng.state=state
 random_observed.emit("coin",int(value));return value

func roll_die() -> int:
 var state=rng.state;var value=super.roll_die()
 if record_random_without_advance:rng.state=state
 random_observed.emit("d6",value);return value

func toggle_ran_discount(who: int,uid: int) -> String:
 var token=begin_command(who,{"name":"toggle_ran_discount","args":[uid]})
 if token.is_empty():return "操作不符合当前录制任务"
 var reason=super.toggle_ran_discount(who,uid);end_command(token);return reason

func toggle_murder_dolls_skip(who: int,uid: int) -> String:
 var token=begin_command(who,{"name":"toggle_murder_dolls_skip","args":[uid]})
 if token.is_empty():return "操作不符合当前录制任务"
 var reason=super.toggle_murder_dolls_skip(who,uid);end_command(token);return reason

func mulligan(who: int,uids: Array):
 var token=begin_command(who,{"name":"mulligan","args":[uids]})
 if token.is_empty():return
 super.mulligan(who,uids)
 end_command(token)

func commit_cast(who: int,uid: int,target: Dictionary,plan: Array) -> String:
 var token=begin_command(who,{"name":"commit_cast","args":[uid,target,plan]})
 if token.is_empty():return "操作不符合当前录制任务"
 var reason=super.commit_cast(who,uid,target,plan)
 end_command(token)
 return reason

func commit_ability(who: int,uid: int,index: int,target: Dictionary,plan: Array) -> String:
 var token=begin_command(who,{"name":"commit_ability","args":[uid,index,target,plan]})
 if token.is_empty():return "操作不符合当前录制任务"
 var reason=super.commit_ability(who,uid,index,target,plan)
 end_command(token)
 return reason

func commit_extension(who: int,uid: int,target: Dictionary,plan: Array,key: String="") -> String:
 var token=begin_command(who,{"name":"commit_extension","args":[uid,target,plan,key]})
 if token.is_empty():return "操作不符合当前录制任务"
 var reason=super.commit_extension(who,uid,target,plan,key)
 end_command(token)
 return reason

func attack(who: int,uid: int,target: Dictionary={},plan: Array=[]):
 var token=begin_command(who,{"name":"attack","args":[uid,target,plan if not plan.is_empty() else payment(who,attack_cost(who)).plan]})
 if token.is_empty():return
 super.attack(who,uid,target,plan)
 end_command(token)

func pass_priority(who: int):
 var token=begin_command(who,{"name":"pass_priority","args":[]})
 if token.is_empty():return
 super.pass_priority(who)
 end_command(token)

func possession(palette_uid: int=-1,hand_uid: int=-1):
 var token=begin_command(int(pending.get("owner",active)),{"name":"possession","args":[palette_uid,hand_uid]})
 if token.is_empty():return
 super.possession(palette_uid,hand_uid)
 end_command(token)

func block(uids: Array):
 var token=begin_command(int(pending.get("owner",1-active)),{"name":"block","args":[uids]})
 if token.is_empty():return
 super.block(uids)
 end_command(token)

func discard(uids: Array):
 var token=begin_command(int(pending.get("owner",active)),{"name":"discard","args":[uids]})
 if token.is_empty():return
 super.discard(uids)
 end_command(token)

func combat_damage(allocation: Dictionary):
 var token=begin_command(int(pending.get("owner",combat.get("owner",active))),{"name":"combat_damage","args":[allocation]})
 if token.is_empty():return
 super.combat_damage(allocation)
 end_command(token)

func choose_trigger(target: Dictionary):
 var token=begin_command(int(pending.get("owner",priority)),{"name":"choose_trigger","args":[target]})
 if token.is_empty():return
 super.choose_trigger(target)
 end_command(token)

func choose_effect(target: Dictionary):
 var token=begin_command(int(pending.get("owner",priority)),{"name":"choose_effect","args":[target]})
 if token.is_empty():return
 super.choose_effect(target)
 end_command(token)

func choose_trigger_order(index: int):
 var token=begin_command(int(pending.get("owner",priority)),{"name":"choose_trigger_order","args":[index]})
 if token.is_empty():return
 super.choose_trigger_order(index)
 end_command(token)

func choose_ward(index: int):
 var token=begin_command(int(pending.get("owner",priority)),{"name":"choose_ward","args":[index]})
 if token.is_empty():return
 super.choose_ward(index)
 end_command(token)

func choose_return(yes: bool):
 var token=begin_command(int(pending.get("owner",priority)),{"name":"choose_return","args":[yes]})
 if token.is_empty():return
 super.choose_return(yes)
 end_command(token)

func choose_grave_replacement(to_field: bool):
 var token=begin_command(int(pending.get("owner",priority)),{"name":"choose_grave_replacement","args":[to_field]})
 if token.is_empty():return
 super.choose_grave_replacement(to_field)
 end_command(token)

func choose_timer(delta: int):
 var token=begin_command(int(pending.get("owner",priority)),{"name":"choose_timer","args":[delta]})
 if token.is_empty():return
 super.choose_timer(delta)
 end_command(token)
