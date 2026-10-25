extends "res://relay/server.gd"
## Exercise the relay's actual result receiver, including encoded packet limits.
var failures=[]
func _initialize():call_deferred("run")
func _process(_delta) -> bool:return false
func check(value: bool,label: String):
 if value:print("PASS: ",label)
 else:failures.append(label);push_error(label)
func fixture() -> Dictionary:
 var room={"ranked":true,"settled":false,"cancel":false,"started":true,"match_id":"a".repeat(32),"players":[101,202],"slots":[11,22],"reports":{},"outcome":-2}
 rooms={"TASK":room};clients={11:{"room":"TASK","player_id":101},22:{"room":"TASK","player_id":202},33:{"room":"TASK","player_id":303}}
 return room
func report(id: int,evidence: Variant=null,winner: int=0):
 var data={"kind":"match_result","match_id":"a".repeat(32),"winner":winner}
 if evidence!=null:data.evidence=evidence
 handle_packet(id,("MCR1"+JSON.stringify(data)).to_utf8_buffer(),0)
func run():
 var proof={"version":1,"players":[{"player_damage":40,"cast_cards":{"precon_reimu_royal_flare":1}},{"player_damage":5}]}
 var room=fixture()
 report(33,proof)
 check(room.reports.is_empty(),"spectators cannot submit task evidence")
 report(11,proof)
 check(agreed_task_evidence(room).is_empty(),"one player cannot credit battle counters")
 report(22,proof)
 check(room.outcome==0 and agreed_task_evidence(room)==JSON.parse_string(JSON.stringify(proof)),"matching results and summaries permit battle progress")
 report(11,proof)
 check(agreed_task_evidence(room)==JSON.parse_string(JSON.stringify(proof)),"identical report retries preserve the summary")
 var changed=proof.duplicate(true);changed.players[0].player_damage=400
 report(11,changed);report(11,proof)
 check(agreed_task_evidence(room).is_empty() and room.outcome==0,"changing a report invalidates its telemetry without altering the winner")
 room=fixture();report(11,proof);report(22,changed)
 check(agreed_task_evidence(room).is_empty() and room.outcome==0,"conflicting counters do not grant task progress")
 room=fixture();report(11,proof);report(22)
 check(agreed_task_evidence(room).is_empty() and room.outcome==0,"old clients retain result settlement without invented counters")
 room=fixture();report(11,proof);room.outcome=0
 check(agreed_task_evidence(room).is_empty(),"disconnect adjudication cannot trust a one-sided summary")
 room=fixture();report(11,proof);report(22,proof,1)
 check(room.cancel and agreed_task_evidence(room).is_empty(),"conflicting winners cannot award evidence")
 room=fixture();report(11,{"version":1,"players":[{}]});report(22,{"version":1,"players":[{}]})
 check(agreed_task_evidence(room).is_empty(),"malformed evidence is discarded")
 room=fixture()
 var large=proof.duplicate(true)
 large.players[0].cast_cards={}
 for number in range(800):large.players[0].cast_cards["test_card_"+str(number)]=1
 check(JSON.stringify(large).to_utf8_buffer().size()>13024,"fixture exceeds the old game-packet limit")
 report(11,large);report(22,large)
 check(room.outcome==0 and agreed_task_evidence(room)==JSON.parse_string(JSON.stringify(large)),"bounded detailed summaries cross the real packet receiver")
 check(not valid_task_evidence({"version":1,"players":[{"oversized":"x".repeat(32768)},{}]}),"oversized summaries are rejected")
 quit(0 if failures.is_empty() else 1)
