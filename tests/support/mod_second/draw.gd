extends RefCounted
func validate(_params: Dictionary) -> String:return ""
func describe_action(_ctx,_params: Dictionary) -> Dictionary:return {"options":[{"none":true}]}
func resolve(ctx,frame: Dictionary,_answer: Dictionary) -> Dictionary:
 if frame.step==0:
  ctx.draw(frame.owner,2);ctx.set_state("turn_count",2)
  return {"continue":true,"step":1}
 if frame.params.get("after_damage",0)>0:ctx.damage({"player":1-frame.owner},int(frame.params.after_damage))
 return {"done":true}
