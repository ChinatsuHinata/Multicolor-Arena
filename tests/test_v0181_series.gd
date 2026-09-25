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
func run():
 host=Session.new();guest=Session.new();root.add_child(host);root.add_child(guest)
 host.initialize("res://work/v0181/session-host");guest.initialize("res://work/v0181/session-guest")
 host.set_display_name("房主测试");guest.set_display_name("客机测试")
 host.error_raised.connect(func(_message):pass)
 check(host.create_room(3,false,47971,"127.0.0.1").is_empty(),"host listens")
 check(guest.join_room("127.0.0.1",47971).is_empty(),"guest connects")
 check(await until(func():return not host.applicant.is_empty()),"approval requested")
 host.accept_applicant(true)
 check(await until(func():return host.can_act() and guest.can_act()),"both seats connected")
 var metrics_sequence=host.sequence
 check(await until(func():return host.metrics.local_ms>=0 and host.metrics.remote_ms>=0 and guest.metrics.local_ms>=0 and guest.metrics.remote_ms>=0,8),"both peers report measured latency")
 check("ms" in host.latency_text() and "ms" in guest.latency_text() and host.sequence==metrics_sequence,"latency probes do not mutate match sequence")
 var decks=JSON.parse_string(FileAccess.get_file_as_string(Store.SAVE_PATH)).decks
 for seat in [0,1]:host.handle_room_action(seat,{"name":"deck","deck":decks[seat]})
 await until(func():return guest.sequence==host.sequence)
 var before=host.series.state.duplicate(true)
 host.handle_room_action(0,{"name":"first","first":true})
 check(host.series.state==before,"host cannot choose first player")
 host.handle_room_action(1,{"name":"first","first":false})
 check(host.series.state==before,"guest cannot choose first player")
 check(host.series.state.roll.is_empty(),"dice are not rolled before preparation")
 await prepare(false)
 var first_roll=host.series.state.roll.duplicate(true)
 check(first_roll==guest.room.roll and first_roll["values"][0]!=first_roll["values"][1],"opening dice synchronized and ties rerolled")
 check(first_roll.chooser==(0 if first_roll["values"][0]>first_roll["values"][1] else 1),"higher roll wins choice")
 check(host.authority.first==1-first_roll.chooser,"chooser may elect to play second")
 check(host.authority.players[1-host.authority.first].potato and not host.authority.players[host.authority.first].potato,"second player receives potato")
 check(host.authority.log.count(host.series.opening_text())==1,"opening choice recorded exactly once")
 check(guest.latest_snapshot.projection.state.presentation_events.any(func(event):return event.type=="result" and event.text==host.series.opening_text()),"choice has public presentation")
 var seq=host.sequence;host.handle_room_action(0,{"name":"ready"})
 check(host.sequence==seq and host.series.state.roll_history.size()==1,"extra ready cannot reroll dice")
 var frozen=host.Codec.capture(host.authority)
 host.on_disconnect(host.remote_peer);host.transport.drop(host.remote_peer)
 check(host.latency_text()=="已断开" and host.metrics.local_ms==-1,"disconnect replaces latency with disconnected status")
 check(await until(func():return host.can_act() and guest.can_act(),12),"reconnect completes")
 sync_views()
 check(host.series.state.roll==first_roll and host.Codec.capture(host.authority)==frozen,"reconnect keeps dice and complete game state")
 await concede(1)
 check(host.series.state.scores==[1,0] and host.series.state.status=="between","first surrender advances to next-game preparation")
 before=host.series.state.duplicate(true)
 host.handle_room_action(0,{"name":"concede_series"})
 check(host.series.state==before,"whole-series surrender command disabled")
 var bad=host.series.state.decks[1].duplicate(true);bad.main.append(bad.main[0])
 check(host.series.set_deck(1,bad)!="","between-game sideboard pool remains locked")
 await prepare()
 check(host.series.state.round==2 and host.series.state.chooser==1 and host.series.state.roll_history.size()==1 and host.series.state.choice_history.size()==2,"previous loser chooses game two without reroll")
 await concede(0)
 check(host.series.state.scores==[1,1] and host.series.state.status=="between","one surrender each leads to deciding game")
 await prepare(false)
 check(host.series.state.round==3 and host.series.state.chooser==0 and guest.room.first==host.series.state.first,"game three loser choice synchronized")
 await concede(1)
 check(host.series.state.scores==[2,1] and host.series.state.status=="complete","only second victory ends BO3")
 var final_series=host.series.state.duplicate(true)
 host.leave(false);guest.leave(false)
 check(host.restore_host().is_empty() and host.series.state==final_series,"host restart keeps all choices and score")
 host.leave(false)
 var series=Session.Series.new();series.setup(1,false)
 for seat in [0,1]:series.set_deck(seat,decks[seat]);series.ready(seat)
 series.prepare_choice();series.choose_first(series.state.chooser,true);series.start_game();series.record_result(1)
 check(series.state.status=="complete" and series.state.scores==[0,1],"BO1 still ends after single game")
 series=Session.Series.new();series.setup(3,false)
 for seat in [0,1]:series.set_deck(seat,decks[seat]);series.ready(seat)
 series.prepare_choice();series.choose_first(series.state.chooser,true);series.start_game();series.record_result(-1)
 check(series.state.status=="between" and series.state.scores==[0,0],"draw advances without a win")
 for seat in [0,1]:series.ready(seat)
 var previous_chooser=series.state.chooser
 series.prepare_choice()
 check(series.state.chooser==previous_chooser and series.state.choice_reason.contains("平局"),"draw keeps previous chooser")
 print("V0181 SERIES ",checks," checks; failures=",failures)
 quit(0 if failures.is_empty() else 1)
