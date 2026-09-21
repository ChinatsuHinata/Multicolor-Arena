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
func prepare():
 host.room_action({"name":"ready"})
 guest.room_action({"name":"ready"})
 check(await until(func():return host.series.state.status=="playing" and guest.room.get("game_id","")==host.series.state.game_id),"both ready starts game")
 check(await until(func():return host.can_act() and guest.can_act()),"ready commands acknowledged")
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
 check(host.series.state.coin.is_empty(),"coin is not tossed before preparation")
 await prepare()
 var first_coin=host.series.state.coin.duplicate(true)
 check(first_coin==guest.room.coin,"opening coin identical for both players")
 check(first_coin.first==host.authority.first and first_coin.face==("正面" if first_coin.first==0 else "反面"),"coin face determines first player")
 check(host.authority.players[1-first_coin.first].potato and not host.authority.players[first_coin.first].potato,"second player receives potato")
 check(host.authority.log.count(host.series.coin_text())==1,"opening coin recorded exactly once")
 check(guest.latest_snapshot.projection.state.presentation_events.any(func(event):return event.type=="result" and event.text==host.series.coin_text()),"coin has public presentation")
 var seq=host.sequence;host.handle_room_action(0,{"name":"ready"})
 check(host.sequence==seq and host.series.state.coin_history.size()==1,"extra ready cannot reroll coin")
 var frozen=host.Codec.capture(host.authority)
 host.on_disconnect(host.remote_peer);host.transport.drop(host.remote_peer)
 check(host.latency_text()=="已断开" and host.metrics.local_ms==-1,"disconnect replaces latency with disconnected status")
 check(await until(func():return host.can_act() and guest.can_act(),12),"reconnect completes")
 sync_views()
 check(host.series.state.coin==first_coin and host.Codec.capture(host.authority)==frozen,"reconnect keeps coin and complete game state")
 await concede(1)
 check(host.series.state.scores==[1,0] and host.series.state.status=="between","first surrender advances to next-game preparation")
 before=host.series.state.duplicate(true)
 host.handle_room_action(0,{"name":"concede_series"})
 check(host.series.state==before,"whole-series surrender command disabled")
 var bad=host.series.state.decks[1].duplicate(true);bad.main.append(bad.main[0])
 check(host.series.set_deck(1,bad)!="","between-game sideboard pool remains locked")
 await prepare()
 check(host.series.state.round==2 and host.series.state.coin_history.size()==2 and host.series.state.coin.game_id!=first_coin.game_id,"second game gets exactly one new coin")
 await concede(0)
 check(host.series.state.scores==[1,1] and host.series.state.status=="between","one surrender each leads to deciding game")
 await prepare()
 check(host.series.state.round==3 and guest.room.coin==host.series.state.coin,"deciding game coin synchronized")
 await concede(1)
 check(host.series.state.scores==[2,1] and host.series.state.status=="complete","only second victory ends BO3")
 var final_series=host.series.state.duplicate(true)
 host.leave(false);guest.leave(false)
 check(host.restore_host().is_empty() and host.series.state==final_series,"host restart keeps all coin results and score")
 host.leave(false)
 var series=Session.Series.new();series.setup(1,false)
 for seat in [0,1]:series.set_deck(seat,decks[seat]);series.ready(seat)
 series.start_game();series.record_result(1)
 check(series.state.status=="complete" and series.state.scores==[0,1],"BO1 still ends after single game")
 series=Session.Series.new();series.setup(3,false)
 for seat in [0,1]:series.set_deck(seat,decks[seat]);series.ready(seat)
 series.start_game();series.record_result(-1)
 check(series.state.status=="between" and series.state.scores==[0,0],"draw advances without a win")
 print("V0181 SERIES ",checks," checks; failures=",failures)
 quit(0 if failures.is_empty() else 1)
