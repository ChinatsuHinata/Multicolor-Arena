extends SceneTree
const Session=preload("res://net/lan_session.gd")
const Store=preload("res://scripts/deck_store.gd")
var host
var guest
var checks=0
var failures=[]
func _init():call_deferred("run")
func check(ok: bool,name: String):
 checks+=1
 if not ok:failures.append(name);push_error("FAIL "+name)
 else:print("PASS "+name)
func until(predicate: Callable,seconds: float=7) -> bool:
 var deadline=Time.get_ticks_msec()+int(seconds*1000)
 while Time.get_ticks_msec()<deadline:
  if predicate.call():return true
  await process_frame
 return false
func sync_views():
 for session in [host,guest]:
  while not session.snapshots.is_empty():session.pop_snapshot()
func run():
 host=Session.new();guest=Session.new();root.add_child(host);root.add_child(guest)
 host.initialize("res://work/v018/session-host");guest.initialize("res://work/v018/session-guest")
 check(host.create_room(3,false,47971).is_empty(),"host listens")
 check(await until(func():return not guest.discovery.rooms.is_empty()),"UDP room discovery")
 check(guest.join_room("127.0.0.1",47971).is_empty(),"guest connects")
 check(await until(func():return not host.applicant.is_empty()),"host approval requested")
 host.accept_applicant(true)
 check(await until(func():return host.can_act() and guest.can_act()),"handshake and ready acknowledgement")
 var decks=Store.load_decks().decks
 host.room_action({"name":"deck","deck":decks[0]});guest.room_action({"name":"deck","deck":decks[1]})
 check(await until(func():return not host.series.state.decks[1].is_empty()),"both decks registered")
 host.handle_room_action(host.series.state.chooser,{"name":"first","first":true})
 host.room_action({"name":"ready"});guest.room_action({"name":"ready"})
 check(await until(func():return not guest.snapshots.is_empty()),"game snapshots delivered")
 sync_views()
 check(host.authority!=null and host.authority.phase=="mulligan","host is sole authority")
 check(guest.latest_snapshot.projection.state.players[0].hand.all(func(c):return c.card_id=="back"),"guest cannot read host hand")
 check(guest.latest_snapshot.projection.state.players[1].deck.all(func(c):return c.card_id=="back"),"own deck order concealed")
 host.submit({"name":"mulligan","args":[[]]})
 check(await until(func():return guest.sequence==host.sequence and not host.busy),"host command synchronized");sync_views()
 guest.submit({"name":"mulligan","args":[[]]})
 var duplicate=guest.inflight.duplicate(true)
 check(await until(func():return not guest.busy),"guest mulligan acknowledged");sync_views()
 var seq=host.sequence
 host.handle_command(1,duplicate)
 await process_frame
 check(host.sequence==seq,"duplicate command not applied twice")
 check(host.authority.turn==1,"both mulligans enter first turn")
 sync_views()
 var paused_state=host.Codec.capture(host.authority)
 host.on_disconnect(host.remote_peer);host.transport.drop(host.remote_peer)
 check(not host.can_act(),"disconnect freezes rules")
 check(host.submit({"name":"pass_priority","args":[]})!="","cannot act while disconnected")
 check(await until(func():return host.can_act() and guest.can_act(),12),"automatic reconnect restores original seat")
 sync_views()
 check(host.Codec.capture(host.authority)==paused_state,"reconnect preserves full authoritative state")
 check(guest.latest_snapshot.projection.state.phase==host.authority.phase,"reconnect recovers phase")
 guest.submit({"name":"surrender","args":[]})
 check(await until(func():return host.series.state.scores==[1,0]),"first result counted once")
 await until(func():return guest.sequence==host.sequence);sync_views()
 check(host.series.state.status=="between" and host.series.state.chooser==1,"loser chooses next first player")
 var bad=host.series.state.decks[1].duplicate(true);bad.main.append(bad.main[0])
 check(host.series.set_deck(1,bad)!="","sideboarding rejects cards outside registered pool")
 guest.room_action({"name":"first","first":true})
 await until(func():return host.series.state.first_chosen)
 host.room_action({"name":"ready"})
 guest.room_action({"name":"ready"})
 check(await until(func():return host.series.state.round==2),"BO3 starts second game")
 await until(func():return guest.sequence==host.sequence);sync_views()
 guest.submit({"name":"surrender","args":[]})
 check(await until(func():return host.series.state.status=="complete"),"BO3 first two wins completes")
 check(host.series.state.scores==[2,0],"BO3 score consistent")
 host.transport.close();guest.transport.close();host.discovery.stop();guest.discovery.stop()
 host.connected=false;guest.connected=false;guest.disconnected_at=0
 check(host.restore_host().is_empty(),"host process recovery file loads")
 check(host.series.state.status=="complete" and host.series.state.scores==[2,0],"persisted series survives restore")
 host.leave(false);guest.leave(false)
 print("V018 SESSION ",checks," checks; failures=",failures)
 quit(0 if failures.is_empty() else 1)
