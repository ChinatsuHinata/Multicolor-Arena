extends RefCounted
func validate(params: Dictionary) -> String:
 var amount=params.get("伤害倍率",1)
 return "" if (amount is int or amount is float) and amount==int(amount) and amount>=1 and amount<=10 else "伤害倍率必须是1至10的整数"
func describe_action(ctx, _params: Dictionary) -> Dictionary:
 var hand=ctx.cards_in(ctx.controller(),"hand").map(func(c):return ctx.ref(c))
 var targets=ctx.damage_targets()
 return {"cost":{"红":1},"tap":true,"extra_costs":[{"kind":"discard","group":0}],"options":[{"selection_id":"discard_and_damage","selection":[{"pool":hand,"min":1,"max":1,"title":"弃置一张手牌","cost":true},{"pool":targets,"min":1,"max":1,"title":"选择伤害目标"}]}]}
func resolve(ctx,frame: Dictionary,_answer: Dictionary) -> Dictionary:
 ctx.damage(frame.target.picks[1][0],2*int(frame.params.get("伤害倍率",1)))
 return {"done":true}
