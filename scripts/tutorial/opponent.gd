extends RefCounted
## Deterministic finite rules; never changes engine state to imitate a move.
const Actions=preload("res://scripts/tutorial/opponent_actions.gd")
const Sequence=preload("res://scripts/tutorial/sequence.gd")
const Commands=preload("res://scripts/tutorial/battle_commands.gd")
const BlockPriorities=preload("res://scripts/tutorial/block_priorities.gd")
const Automatic=preload("res://scripts/tutorial/automatic_response.gd")
var config: Dictionary={"strategy":"paused"}
var counts: Dictionary={}
var events: Array=[]
var sequence=Sequence.new()
var active: Dictionary={}
var blocking: Dictionary={}
var block_decided=false

func configure(value: Dictionary):
 config=value.duplicate(true);counts={};events=[];sequence.playing=false;active={};blocking={};block_decided=false

func observe(event: Dictionary):
 if config.get("strategy","paused")=="rules" and config.get("rules",[]).any(func(rule):return rule.event==event.type):events.append(event.duplicate(true))

func tick(adapter,completed: Array,delta: float=1.0/60.0,busy: bool=false) -> String:
 if sequence.playing:return sequence.tick(adapter,active,delta,busy,true)
 if busy:return ""
 if events.is_empty():return pass_response(adapter)
 var event=events.pop_front()
 var deferred=false
 for rule in config.get("rules",[]):
  if rule.event!=event.type:continue
  var matched=counts.get(rule.id,0)<int(rule.max_times) and adapter.evaluate(rule.when,completed)
  if not matched and rule.get("otherwise","")!="no_block":continue
  if rule.has("on_action") and not Commands.matches(adapter,rule.on_action,event.get("action",{})):continue
  if rule.has("sequence"):
   active=rule.sequence.duplicate(true);sequence.start(adapter,active,true)
   counts[rule.id]=counts.get(rule.id,0)+1
   return ""
  # Resolving a card can hand priority to the opponent while a player-owned
  # entry/trigger choice is still pending. Keep this response for after the
  # choice; pass_priority is not legal until the choice has finished.
  var action=({"type":rule.action} if rule.action is String else rule.action) if matched else {"type":"block","cards":[]}
  var command={"name":action.type,"args":[]}
  if action.type=="pass_priority":
   var e=adapter.engine
   if e==null or e.winner!=-2 or e.phase=="mulligan" or e.priority!=1:continue
   if not e.pending.is_empty() and e.pending.get("owner",-1)==1:
    # Blocking is a separate choice, not a priority action. Let its rule
    # handle the choice even if it listens to a different queued event.
    if e.pending.get("kind","")=="block":continue
    if config.get("auto_response",false):continue
    return "opponent.rules.%s.action：对手有待完成的选择，不能让过执行权" % rule.id
   if not e.pending.is_empty() or not e.entry_choices.is_empty():
    deferred=true;continue
  elif action.type=="block":
   var e=adapter.engine
   if (action.has("priorities") or rule.has("otherwise")) and e!=null and e.winner==-2 and e.combat.get("step","")=="attack_window" and e.pending.get("kind","")!="block" and e.combat.get("owner",-1)==0 and not e.combat.get("direct",false):
    blocking=e.combat.attacker.duplicate(true);block_decided=false
    # Keep the decision unconsumed until the defender's actual block choice.
    continue
   # The defending seat owns this choice regardless of current priority.
   if e==null or e.winner!=-2 or e.pending.get("kind","")!="block" or e.pending.get("owner",-1)!=1:continue
   var uids=[];var legal=e.legal_blockers()
   if action.has("priorities"):
    var prepared=BlockPriorities.prepare(adapter,action.priorities)
    if not prepared.available:continue
    uids=prepared.uids;blocking=e.combat.attacker.duplicate(true);block_decided=true
   else:
    if not matched and not legal.is_empty() and e.Cat.has(e,e.find_card(e.combat.attacker.uid),"character-fdf-090"):continue
    for selection in action.cards:
     var card=adapter.resolve_card(selection)
     if card.is_empty() or card not in legal:
      return "opponent.rules.%s.action.cards：单位 %s 当前不能阻挡" % [rule.id,selection.get("alias",str(selection))]
     if card.uid in uids:return "opponent.rules.%s.action.cards：不能重复选择同一阻挡单位" % rule.id
     uids.append(int(card.uid))
    if rule.has("otherwise"):blocking=e.combat.attacker.duplicate(true);block_decided=true
   command.args=[uids]
  elif action.type in ["cast","ability"]:
   var e=adapter.engine
   if e==null or e.winner!=-2 or e.phase=="mulligan" or e.priority!=1:continue
   if not e.pending.is_empty() or not e.entry_choices.is_empty():
    if e.pending.get("owner",-1)!=1:deferred=true
    continue
   var prepared=Actions.prepare(adapter,action)
   if not prepared.error.is_empty():return "opponent.rules.%s.action.%s" % [rule.id,prepared.error]
   # Unaffordable or unavailable moves do not consume the rule or block a
   # later fallback response; a future event can try them again.
   if not prepared.available:continue
   command=prepared.command
  var reason=adapter.submit(1,command)
  if not reason.is_empty():return "opponent.rules.%s.action：%s" % [rule.id,reason]
  if matched:counts[rule.id]=counts.get(rule.id,0)+1
  # At most one response per tick; follow-up events run on later ticks.
  return ""
 if deferred:events.push_front(event)
 return pass_response(adapter)

func pass_response(adapter) -> String:
 var e=adapter.engine
 if e==null or e.winner!=-2:return ""
 if not blocking.is_empty() and (e.combat.get("attacker",{})!=blocking or block_decided and e.combat.get("step","")=="attack_window"):
  blocking={};block_decided=false
 if config.get("auto_response",false) and events.is_empty():return Automatic.tick(adapter)
 if blocking.is_empty():
  # A blocking shortcut also lets the student resolve cards before attacking.
  # Drain explicit responses first; only pass an actual stack response, never
  # an unmatched attack or an idle phase that would end the student's turn.
  if not events.is_empty() or not e.combat.is_empty() or e.stack.is_empty() or config.get("strategy","paused")!="rules":return ""
  if not config.get("rules",[]).any(func(rule):return rule.get("action") is Dictionary and rule.action.get("type")=="block" and rule.action.has("priorities")):return ""
 if e.priority!=1 or e.phase=="mulligan" or not e.pending.is_empty() or not e.entry_choices.is_empty():return ""
 return adapter.submit(1,{"name":"pass_priority","args":[]})

func capture() -> Dictionary:
 return {"config":config.duplicate(true),"counts":counts.duplicate(true),"events":events.duplicate(true),"sequence":sequence.capture(),"active":active.duplicate(true),"blocking":blocking.duplicate(true),"block_decided":block_decided}

func restore(snapshot: Dictionary):
 config=snapshot.config.duplicate(true);counts=snapshot.counts.duplicate(true);events=snapshot.events.duplicate(true)
 sequence.restore(snapshot.get("sequence",{}));active=snapshot.get("active",{}).duplicate(true)
 blocking=snapshot.get("blocking",{}).duplicate(true)
 block_decided=snapshot.get("block_decided",false)
