extends RefCounted
func validate(_params: Dictionary) -> String:return ""
func describe_action(ctx,_params: Dictionary) -> Dictionary:return {"options":ctx.damage_targets()}
func collect_triggers(_ctx,event: Dictionary,_params: Dictionary) -> Array:
 return [{}] if event.type=="self_leave" else []
func resolve(ctx,frame: Dictionary,_answer: Dictionary) -> Dictionary:
 # The engine captures last-known stats before detaching the source.
 ctx.damage(frame.target,int(frame.source.mod_stats.power))
 return {"done":true}
