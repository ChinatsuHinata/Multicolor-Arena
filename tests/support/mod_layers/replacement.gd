extends RefCounted
func validate(_p):return ""
func get_replacements(ctx,change,_p):
 if change.type!="draw" or change.owner!=ctx.controller() or not ctx.cards_in(change.owner,"deck").is_empty():return []
 return [{"id":"return","optional":false,"cancel":true,"operations":[{"op":"move","target":ctx.ref(ctx.source()),"zone":"hand"},{"op":"life","owner":ctx.controller(),"amount":3}]}]
