extends RefCounted
func validate(_params: Dictionary) -> String:return ""
func describe_action(_ctx,_params: Dictionary) -> Dictionary:return {"tap":true,"options":[{"none":true}]}
func resolve(ctx,frame: Dictionary,_answer: Dictionary) -> Dictionary:
 ctx.draw(frame.owner)
 return {"done":true}
