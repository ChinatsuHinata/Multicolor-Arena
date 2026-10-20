extends RefCounted
func validate(params: Dictionary) -> String:
 return "" if params.keys().size()==1 else "top_three 不接受额外参数"
func describe_action(_ctx, _params: Dictionary) -> Dictionary:
 return {"options":[{"none":true}]}
func resolve(ctx,frame: Dictionary,answer: Dictionary) -> Dictionary:
 if frame.step==0:
  var top=ctx.top(frame.owner,3).map(func(c):return ctx.ref(c))
  if top.is_empty():return {"done":true}
  ctx.set_state("last_seen",top)
  return {"step":1,"data":{"remaining":top},"choice":top}
 if frame.step==1:
  ctx.move(answer,"hand")
  var remaining=frame.data.remaining.duplicate(true);remaining.erase(answer)
  if remaining.size()<2:return {"done":true}
  return {"step":2,"data":{"remaining":remaining},"choice":remaining}
 var ordered=frame.data.remaining.duplicate(true);ordered.erase(answer);ordered.push_front(answer)
 ctx.reorder_top(frame.owner,ordered)
 return {"done":true}
