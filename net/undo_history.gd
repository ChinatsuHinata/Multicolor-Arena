extends RefCounted
## Authoritative, bounded checkpoints; never sent to a player or spectator.
const Codec=preload("res://net/state_codec.gd")
const LIMIT=32
var entries: Array=[]
func settled(engine) -> bool:
 # A popped spell can still be resolving a search, a payment or a return choice.
 # Do not split that single stack chain into several undo checkpoints.
 # Combat responses, blocks and damage belong to the same undo operation.
 # Replay snapshots remain independent and still record every command.
 return engine!=null and engine.winner==-2 and engine.combat.is_empty() and engine.combat_queue.is_empty() and engine.stack.is_empty() and engine.pending.get("kind","") in ["","possession","discard"] and engine.entry_choices.is_empty() and engine.damage_queue.is_empty() and engine.reveal_resolution.is_empty() and engine.triggers.is_empty() and engine.returns.is_empty() and engine.timer_changes.is_empty() and engine.zone_replacements.is_empty()

func can_decide(engine) -> bool:
 if not settled(engine) or engine.players.size()!=2:return false
 if engine.pending.get("kind","") in ["possession","discard"]:return true
 if engine.phase=="mulligan":return engine.players.any(func(player):return not player.mulligan_done)
 # The turn player can always choose to end an empty-stack main phase.
 if engine.phase=="main":return true
 # Either player can receive priority before this response window ends.
 # Preserve the rules queries' scratch fields and payment caches.
 var saved={}
 for key in ["priority","catalogue_target_fast","catalogue_x_override","catalogue_x_source","catalogue_retargeting","paid_cast_uid","forced_cast","revision"]:saved[key]=engine.get(key)
 var memo=engine.payment_memo.duplicate(true);var groups=engine.payment_groups.duplicate(true)
 engine.paid_cast_uid=-1
 var result=false
 for who in range(2):
  engine.priority=who
  if engine.has_response(who):result=true;break
 for key in saved:engine.set(key,saved[key])
 engine.payment_memo=memo;engine.payment_groups=groups
 return result

func remember(engine,game: String,sequence: int):
 if not settled(engine):return
 if not entries.is_empty() and entries.back().game!=game:entries.clear()
 var decision=can_decide(engine)
 var raw=var_to_bytes(Codec.capture(engine))
 var checkpoint={"game":game,"sequence":sequence,"size":raw.size(),"bytes":raw.compress(FileAccess.COMPRESSION_ZSTD),"can_decide":decision}
 # Keep the current state as a cursor, while passive transitions share one slot.
 if not decision and not entries.is_empty() and entries.back().get("can_decide",true)==false:entries[-1]=checkpoint
 else:entries.append(checkpoint)
 if entries.size()>LIMIT:entries.pop_front()
func available(engine,game: String) -> bool:
 return settled(engine) and previous_index(engine,game)>=0

func checkpoint_graph(checkpoint: Dictionary) -> Dictionary:
 var raw=checkpoint.bytes.decompress(checkpoint.size,FileAccess.COMPRESSION_ZSTD)
 if raw.size()!=checkpoint.size:return {}
 var graph=bytes_to_var(raw)
 return graph if graph is Dictionary else {}

func previous_index(engine=null,game: String="") -> int:
 if entries.size()<2:return -1
 if game.is_empty():game=str(entries.back().game)
 if entries.back().game!=game:return -1
 var scratch=null
 for index in range(entries.size()-2,-1,-1):
  var entry=entries[index]
  if entry.game!=game:break
  # Persisted histories created before the decision marker use the same rule.
  if not entry.has("can_decide"):
   if engine==null:continue
   var graph=checkpoint_graph(entry)
   if graph.is_empty():entry.can_decide=false;continue
   if scratch==null:scratch=engine.get_script().new(engine.cards)
   Codec.restore(scratch,graph)
   entry.can_decide=can_decide(scratch)
  if entry.can_decide:return index
 return -1

func previous(engine=null,game: String="") -> Dictionary:
 var index=previous_index(engine,game)
 return entries[index] if index>=0 else {}

func restore_previous(engine,game: String="") -> Dictionary:
 if not settled(engine):return {}
 var index=previous_index(engine,game)
 if index<0:return {}
 var checkpoint=entries[index]
 var graph=checkpoint_graph(checkpoint)
 if graph.is_empty():return {}
 Codec.restore(engine,graph);engine.presentation_events=[];engine.paid_cast_uid=-1
 entries.resize(index+1)
 return {"game":checkpoint.game,"sequence":checkpoint.sequence}
