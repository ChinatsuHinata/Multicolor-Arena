extends RefCounted
## Deterministic finite rules; never changes engine state to imitate a move.
const Actions=preload("res://scripts/tutorial/opponent_actions.gd")
const Sequence=preload("res://scripts/tutorial/sequence.gd")
const Commands=preload("res://scripts/tutorial/battle_commands.gd")
var config: Dictionary={"strategy":"paused"}
var counts: Dictionary={}
var events: Array=[]
var sequence=Sequence.new()
var active: Dictionary={}

func configure(value: Dictionary):
 config=value.duplicate(true);counts={};events=[];sequence.playing=false;active={}

func observe(event: Dictionary):
 if config.get("strategy","paused")=="rules" and config.get("rules",[]).any(func(rule):return rule.event==event.type):events.append(event.duplicate(true))

func tick(adapter,completed: Array,delta: float=1.0/60.0,busy: bool=false) -> String:
 if sequence.playing:return sequence.tick(adapter,active,delta,busy,true)
 if busy:return ""
 if events.is_empty():return ""
 var event=events.pop_front()
 var deferred=false
 for rule in config.get("rules",[]):
  if rule.event!=event.type or counts.get(rule.id,0)>=int(rule.max_times):continue
  if not adapter.evaluate(rule.when,completed):continue
  if rule.has("on_action") and not Commands.matches(adapter,rule.on_action,event.get("action",{})):continue
  if rule.has("sequence"):
   active=rule.sequence.duplicate(true);sequence.start(adapter,active,true)
   counts[rule.id]=counts.get(rule.id,0)+1
   return ""
  # Resolving a card can hand priority to the opponent while a player-owned
  # entry/trigger choice is still pending. Keep this response for after the
  # choice; pass_priority is not legal until the choice has finished.
  var action={"type":rule.action} if rule.action is String else rule.action
  var command={"name":action.type,"args":[]}
  if action.type=="pass_priority":
   var e=adapter.engine
   if e==null or e.winner!=-2 or e.phase=="mulligan" or e.priority!=1:continue
   if not e.pending.is_empty() and e.pending.get("owner",-1)==1:
    # Blocking is a separate choice, not a priority action. Let its rule
    # handle the choice even if it listens to a different queued event.
    if e.pending.get("kind","")=="block":continue
    return "opponent.rules.%s.action：对手有待完成的选择，不能让过执行权" % rule.id
   if not e.pending.is_empty() or not e.entry_choices.is_empty():
    deferred=true;continue
  elif action.type=="block":
   var e=adapter.engine
   # The defending seat owns this choice regardless of current priority.
   if e==null or e.winner!=-2 or e.pending.get("kind","")!="block" or e.pending.get("owner",-1)!=1:continue
   var uids=[];var legal=e.legal_blockers()
   for selection in action.cards:
    var card=adapter.resolve_card(selection)
    if card.is_empty() or card not in legal:
     return "opponent.rules.%s.action.cards：单位 %s 当前不能阻挡" % [rule.id,selection.get("alias",str(selection))]
    if card.uid in uids:return "opponent.rules.%s.action.cards：不能重复选择同一阻挡单位" % rule.id
    uids.append(int(card.uid))
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
  counts[rule.id]=counts.get(rule.id,0)+1
  # At most one response per tick; follow-up events run on later ticks.
  return ""
 if deferred:events.push_front(event)
 return ""

func capture() -> Dictionary:
 return {"config":config.duplicate(true),"counts":counts.duplicate(true),"events":events.duplicate(true),"sequence":sequence.capture(),"active":active.duplicate(true)}

func restore(snapshot: Dictionary):
 config=snapshot.config.duplicate(true);counts=snapshot.counts.duplicate(true);events=snapshot.events.duplicate(true)
 sequence.restore(snapshot.get("sequence",{}));active=snapshot.get("active",{}).duplicate(true)
