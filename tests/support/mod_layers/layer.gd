extends RefCounted
func validate(_p):return ""
func get_modifiers(_ctx,q,p):
 if p.get("query","")=="action_lock":return [{"id":p.id,"layer":30,"operation":"set","value":true}] if q.kind=="action_lock" else []
 if p.get("query","")=="cost":return [{"id":p.id,"layer":30,"operation":"add","value":p.value}] if q.kind=="cost" and q.color=="红" else []
 if q.kind!="stat" or q.stat!="power":return []
 if q.value<p.get("threshold",-10000):return []
 return [{"id":p.id,"layer":p.layer,"operation":p.operation,"value":int(q.value)+p.value if p.get("from_current",false) else p.value,"depends_on":p.get("depends_on",[])}]
