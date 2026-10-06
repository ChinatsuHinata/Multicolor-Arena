extends RefCounted
## Submit one prescribed intention at a time, after the previous presentation.
const Actions=preload("res://scripts/tutorial/opponent_actions.gd")
const ACTION_PAUSE_SECONDS=0.2
var playing=false
var index=0
var delay_remaining=0.0
var isolated_random=false
var random_used=0

func start(adapter,config: Dictionary,isolate_random: bool=false):
 playing=not config.is_empty();index=0;delay_remaining=0.0
 isolated_random=isolate_random;random_used=0
 if adapter.engine!=null and not isolated_random:
  adapter.engine.scripted_random=false
  if playing:adapter.engine.begin_random(config.get("random_results",[]),config.get("advance_rng",false))

func tick(adapter,config: Dictionary,delta: float,busy: bool,wait_available: bool=false) -> String:
 if not playing or busy:return ""
 if delay_remaining>0:
  delay_remaining=maxf(0,delay_remaining-delta)
  return ""
 var e=adapter.engine
 if index==config.actions.size():
  var used=random_used if isolated_random else e.random_cursor
  if used!=config.get("random_results",[]).size():return "random_results.%d：预设结果未被使用" % used
  e.scripted_random=false;playing=false
  return ""
 var action=config.actions[index]
 if action.type=="delay":
  delay_remaining=float(action.seconds);index+=1;return ""
 var seat=int(action.player)
 var prepared=prepare(adapter,action,seat)
 if not prepared.error.is_empty():return "actions.%d.%s" % [index,prepared.error]
 if not prepared.available:return "" if wait_available else "actions.%d：动作 %s 当前不合法、目标不唯一或费用不足" % [index,action.type]
 if isolated_random:
  e.begin_random(config.get("random_results",[]),config.get("advance_rng",false));e.random_cursor=random_used
 var reason=adapter.submit(seat,prepared.command)
 if isolated_random:random_used=e.random_cursor;e.scripted_random=false
 if not e.random_error.is_empty():return e.random_error
 if not reason.is_empty():return "actions.%d：%s" % [index,reason]
 index+=1
 if index<config.actions.size():delay_remaining=ACTION_PAUSE_SECONDS
 return ""

static func prepare(adapter,action: Dictionary,seat: int) -> Dictionary:
 var e=adapter.engine;var old_paid=e.paid_cast_uid;var old_revision=e.revision;var old_pending=e.pending
 if action.get("pay_colors",false):
  e.paid_cast_uid=int(adapter.resolve_card(action.card).get("uid",-1))
 if action.has("grant_payment") and e.pending.get("trigger",{}).get("effect")=="cat:grant":
  e.pending=e.pending.duplicate(true);e.set_granted_payment(action.grant_payment)
 var prepared=prepare_intent(adapter,action,seat)
 var chosen_paid=e.paid_cast_uid
 e.paid_cast_uid=old_paid;e.revision=old_revision;e.pending=old_pending
 if prepared.available and action.get("pay_colors",false):prepared.command.paid_uid=chosen_paid
 if prepared.available and action.has("payment"):
  var plan=payment_plan(adapter,action.payment)
  if not plan.available:return Actions.skipped()
  var command=prepared.command
  command.args[3 if command.name=="commit_ability" else 2]=plan.value
 return prepared

static func payment_plan(adapter,items: Array) -> Dictionary:
 return preload("res://scripts/tutorial/battle_commands.gd").payment_plan(adapter,items)

static func prepare_intent(adapter,action: Dictionary,seat: int) -> Dictionary:
 var e=adapter.engine
 var pending_kinds={"possession":"possession","discard":"discard","block":"block","combat_damage":"damage_assignment","choose_trigger_order":"trigger_order","choose_ward":"ward_order","choose_trigger":"trigger","choose_return":"leader_return","choose_grave_replacement":"grave_replacement","choose_effect":"effect_choice","choose_timer":"timer"}
 if pending_kinds.has(action.type) and (e.pending.get("kind")!=pending_kinds[action.type] or e.pending.get("owner",-1)!=seat):return Actions.skipped()
 if action.type=="pass_priority" and (e.priority!=seat or not e.pending.is_empty() or not e.entry_choices.is_empty() or e.phase=="mulligan"):return Actions.skipped()
 if action.type=="attack" and not e.can_attack(seat,int(adapter.resolve_card(action.card).get("uid",-1))):return Actions.skipped()
 if action.type=="mulligan" and (e.phase!="mulligan" or e.players[seat].mulligan_done):return Actions.skipped()
 # Aliases can leave play during earlier actions; report an unavailable move
 # instead of dereferencing a vanished token or selecting a different copy.
 for key in ["card","source","palette","hand"]:
  if action.has(key) and not action[key].has("card_id") and adapter.resolve_card(action[key]).is_empty():return Actions.skipped()
 for card in action.get("cards",[]):
  if adapter.resolve_card(card).is_empty():return Actions.skipped()
 for item in action.get("assignments",[]):
  if adapter.resolve_card(item.card).is_empty():return Actions.skipped()
 if action.type in ["cast","ability"]:return Actions.prepare(adapter,action,seat)
 var command={"name":action.type,"args":[]}
 match action.type:
  "possession":
   command.args=[int(adapter.resolve_card(action.palette).uid),int(adapter.resolve_card(action.hand).uid)] if action.has("palette") else [-1,-1]
  "attack":
   var selected=Actions.selector(adapter,action.get("target",{}))
   if not selected.available:return Actions.skipped()
   var payment=e.payment(seat,e.attack_cost(seat))
   if payment.ways==0:return Actions.skipped()
   command.args=[int(adapter.resolve_card(action.card).uid),selected.value,payment.plan]
  "toggle_ran_discount","toggle_murder_dolls_skip":command.args=[int(adapter.resolve_card(action.card).uid)]
  "block","discard","mulligan":
   command.args=[action.cards.map(func(card):return int(adapter.resolve_card(card).uid))]
  "choose_trigger","choose_effect":
   var requested=action.get("target",{})
   if requested.is_empty():command.args=[{}]
   else:
    var selected=Actions.target(adapter,requested,e.pending.get("options",[]))
    if not selected.available:return selected
    command.args=[selected.target]
   if action.has("grant_payment"):command.grant_payment=action.grant_payment
  "choose_trigger_order","choose_ward":command.args=[int(action.index)]
  "choose_return","choose_grave_replacement":command.args=[action.yes]
  "choose_timer":command.args=[int(action.value)]
  "combat_damage":
   var allocation={}
   for item in action.assignments:allocation[str(adapter.resolve_card(item.card).uid)]=int(item.amount)
   command.args=[allocation]
 return Actions.ready(command)

func capture() -> Dictionary:
 return {"playing":playing,"index":index,"delay_remaining":delay_remaining,"isolated_random":isolated_random,"random_used":random_used}

func restore(state: Dictionary):
 playing=state.get("playing",false);index=int(state.get("index",0));delay_remaining=float(state.get("delay_remaining",0))
 isolated_random=state.get("isolated_random",false);random_used=int(state.get("random_used",0))
