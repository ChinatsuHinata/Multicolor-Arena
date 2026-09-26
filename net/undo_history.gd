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
 return engine!=null and engine.winner==-2 and engine.combat.is_empty() and engine.combat_queue.is_empty() and engine.stack.is_empty() and engine.pending.get("kind","") in ["","possession","discard"] and engine.triggers.is_empty() and engine.returns.is_empty() and engine.timer_changes.is_empty() and engine.zone_replacements.is_empty()
func remember(engine,game: String,sequence: int):
 if not settled(engine):return
 if not entries.is_empty() and entries.back().game!=game:entries.clear()
 var raw=var_to_bytes(Codec.capture(engine))
 entries.append({"game":game,"sequence":sequence,"size":raw.size(),"bytes":raw.compress(FileAccess.COMPRESSION_ZSTD)})
 if entries.size()>LIMIT:entries.pop_front()
func available(engine,game: String) -> bool:
 return settled(engine) and entries.size()>1 and entries.back().game==game
func previous() -> Dictionary:return entries[-2] if entries.size()>1 else {}
func restore_previous(engine) -> Dictionary:
 if entries.size()<2:return {}
 var checkpoint=previous()
 var raw=checkpoint.bytes.decompress(checkpoint.size,FileAccess.COMPRESSION_ZSTD)
 if raw.size()!=checkpoint.size:return {}
 var graph=bytes_to_var(raw)
 if not graph is Dictionary:return {}
 Codec.restore(engine,graph);engine.presentation_events=[];engine.paid_cast_uid=-1
 entries.pop_back()
 return {"game":checkpoint.game,"sequence":checkpoint.sequence}
