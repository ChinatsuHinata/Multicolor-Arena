extends "res://net/remote_duel.gd"
var last_request={}
func request(name: String,args: Array=[]) -> String:
 last_request={"name":name,"args":args,"paid_uid":paid_cast_uid,"grant_payment":grant_payment}
 return super.request(name,args)
