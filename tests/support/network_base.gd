extends SceneTree
const Session=preload("res://net/lan_session.gd")
const Store=preload("res://scripts/deck_store.gd")
var host
var guest
var checks=0
var failures=[]
func _init():call_deferred("run")
func check(ok: bool,title: String):
 checks+=1
 if not ok:failures.append(title);push_error(title)
 else:print("PASS "+title)
func until(predicate: Callable,seconds: float=8) -> bool:
 var deadline=Time.get_ticks_msec()+int(seconds*1000)
 while Time.get_ticks_msec()<deadline:
  if predicate.call():return true
  await process_frame
 return false
func sync_views():
 for session in [host,guest]:
  while not session.snapshots.is_empty():session.pop_snapshot()
func prepare(wants_first: bool=true):
 host.room_action({"name":"ready"})
 guest.room_action({"name":"ready"})
 check(await until(func():return host.series.state.status=="choosing" and guest.room.get("status","")=="choosing" and host.can_act() and guest.can_act()),"both ready opens synchronized first-player choice")
 var chooser=int(host.series.state.chooser)
 var before=host.series.state.duplicate(true)
 host.handle_room_action(1-chooser,{"name":"first","first":true})
 check(host.series.state==before,"only the chooser can select first player")
 var selecting=host if chooser==0 else guest
 selecting.room_action({"name":"first","first":wants_first})
 check(await until(func():return host.series.state.status=="playing" and guest.room.get("game_id","")==host.series.state.game_id),"chooser starts game with selected order")
 check(await until(func():return host.can_act() and guest.can_act()),"choice command acknowledged")
 sync_views()
func concede(seat: int):
 var session=host if seat==0 else guest
 check(session.submit({"name":"surrender","args":[]}).is_empty(),"single-game surrender submitted")
 var duplicate=session.inflight.duplicate(true)
 check(await until(func():return host.series.state.status!="playing" and guest.sequence==host.sequence and session.can_act()),"single result synchronized")
 sync_views()
 var scores=host.series.state.scores.duplicate();var sequence=host.sequence
 host.handle_command(seat,duplicate);await process_frame
 check(host.sequence==sequence and host.series.state.scores==scores,"duplicate surrender cannot award another win")
 sync_views()
