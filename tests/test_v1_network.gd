extends "res://tests/test_v0181_series.gd"
class CapturedTransport:
 extends Node
 var sent=[]
 func send_to(_id,message,_heartbeat=false):sent.append(message)
class FailedSave:
 extends "res://net/lan_session.gd"
 func persist() -> bool:
  paused=true;notice="test storage failure";return false

func connect_pair():
 check(host.create_room(3,true,47981,"127.0.0.1").is_empty(),"create 1.0 BO3")
 guest.join_room("127.0.0.1",47981)
 check(await until(func():return not host.applicant.is_empty()),"new guest requests room")
 host.accept_applicant(true)
 check(await until(func():return host.can_act() and guest.can_act()),"both synchronized")
 var decks=JSON.parse_string(FileAccess.get_file_as_string("res://data/test_precons.json")).decks
 for seat in [0,1]:host.handle_room_action(seat,{"name":"deck","deck":decks[seat]})
 await until(func():return guest.sequence==host.sequence)
 await prepare()

func run():
 var guarded=FailedSave.new();guarded.transport=CapturedTransport.new();guarded.add_child(guarded.transport)
 guarded.is_host=true;guarded.connected=true;guarded.paused=true;guarded.remote_peer=7;guarded.sequence=3;guarded.room={"status":"playing"}
 guarded.disconnected_at=maxi(1,Time.get_ticks_msec());guarded.disconnect_deadline_unix=Time.get_unix_time_from_system()+30
 guarded.receive(7,{"type":"ack","sequence":3})
 check(guarded.paused and guarded.transport.sent.is_empty(),"failed recovery checkpoint cannot unlock guest")
 guarded.free()
 check(ProjectSettings.get_setting("application/config/name")=="multicolor:arena" and ProjectSettings.get_setting("application/config/version")=="1.2","project name and version updated")
 check(OS.get_user_data_dir().replace("\\","/").ends_with("/Godot/app_userdata/极彩 Multicolour"),"renaming preserves legacy save directory")
 var utopia=Store.CARDS["spell-fdf-068"].cost;var winter=Store.CARDS["spell-fdf-042"].cost
 check(utopia.size()==2 and int(utopia.get("蓝",0))==2 and int(utopia.get("绿",0))==1,"Last Utopia costs two blue one green")
 check(winter.size()==2 and int(winter.get("蓝",0))==2 and int(winter.get("黑",0))==1,"Winter costs two blue one black")
 var precons=JSON.parse_string(FileAccess.get_file_as_string("res://data/test_precons.json")).decks
 var duel=Session.Duel.new();duel.start(precons[0],precons[1],0,19)
 var mono={}
 for id in Store.CARDS:
  var colors=Store.CARDS[id].colors
  if colors.size()==1 and colors[0] in ["蓝","绿","黑"]:mono[colors[0]]=id
 for other in ["绿","黑"]:
  duel.players[0].palette=[];duel.players[0].field=[];duel.players[0].potato=false
  for color in ["蓝",other]:duel.players[0].palette.append(duel.make_card(mono[color],0,"palette"))
  var cost=utopia if other=="绿" else winter
  check(duel.payment(0,cost).ways==0,"one blue plus "+other+" is insufficient")
  duel.players[0].palette.append(duel.make_card(mono["蓝"],0,"palette"))
  check(duel.payment(0,cost).ways>0 and duel.payment(0,cost).plan.size()==3,"two blue plus "+other+" pays exactly three resources")
 host=Session.new();guest=Session.new();root.add_child(host);root.add_child(guest)
 host.initialize("res://work/v1/network-host");guest.initialize("res://work/v1/network-guest")
 host.error_raised.connect(func(_message):pass);guest.error_raised.connect(func(_message):pass)
 await connect_pair()
 # Reconnection before the deadline preserves every rule object and BO3 score.
 var frozen=host.Codec.capture(host.authority);var seq=host.sequence
 host.on_disconnect(host.remote_peer);host.transport.drop(host.remote_peer)
 check(host.paused and not host.can_act(true),"host locks immediately when guest disconnects")
 check(not host.submit({"name":"surrender","args":[]}).is_empty() and host.sequence==seq,"locked host cannot surrender or advance rules")
 check(host.connection_status().contains("秒") and Session.RECONNECT_LIMIT_MS==30000,"30 second reconnect countdown")
 var start=host.disconnected_at
 check(not host.check_reconnect_timeout(start+29999),"29.999 seconds stays recoverable")
 check(await until(func():return host.can_act() and guest.can_act(),12),"normal automatic reconnect succeeds in grace period")
 sync_views()
 check(host.disconnected_at==0 and guest.disconnected_at==0 and host.disconnect_deadline_unix==0,"successful sync clears both reconnect deadlines")
 check(host.Codec.capture(host.authority)==frozen and host.sequence==seq,"reconnection preserves full state without new moves")
 # A later outage starts a fresh grace period, but failed retries cannot extend it.
 host.on_disconnect(host.remote_peer);host.transport.drop(host.remote_peer)
 guest.on_disconnect(1);guest.transport.close();guest.retry_at=Time.get_ticks_msec()+60000
 var host_start=host.disconnected_at;var guest_start=guest.disconnected_at
 guest.on_failure("test retry failure");host.on_disconnect(host.remote_peer)
 check(host.disconnected_at==host_start and guest.disconnected_at==guest_start,"repeated disconnects and failed attempts do not reset timer")
 check(not guest.submit({"name":"pass_priority","args":[]}).is_empty(),"guest also freezes when host is missing")
 var scores=host.series.state.scores.duplicate();var counted=host.series.state.counted.duplicate()
 check(host.check_reconnect_timeout(host_start+30000),"host terminates at exactly 30 seconds")
 check(guest.check_reconnect_timeout(guest_start+30000),"guest terminates at exactly 30 seconds")
 check(host.ended() and guest.ended() and host.room.status=="complete" and guest.room.status=="complete","both terminate entire series")
 check(host.room.winner==0 and guest.room.winner==1 and guest.room.local_record and host.series.state.scores==scores and host.series.state.counted==counted,"disconnect forfeits entire match while preserving played scores")
 check(host.Codec.capture(host.authority)==frozen,"timeout leaves final battlefield intact for viewing")
 check(host.transport.peer==null and guest.transport.peer==null and not host.can_act() and not guest.can_act(),"expired sessions cannot accept gameplay")
 check(not host.restore_host().is_empty() and not guest.resume_guest().is_empty(),"expired host and guest cannot manually resume old match")
 var old_backup=host.Journal.load_from(host.storage+"/host.bin");old_backup.series.status="playing"
 host.Journal.save_to(host.storage+"/host.bin",old_backup)
 check(not host.restore_host().is_empty(),"ended-room tombstone also rejects stale pre-timeout backup")
 var ended_state=host.series.state.duplicate(true);host.end_disconnected_match()
 check(host.series.state==ended_state,"termination is idempotent")
 # The deadline is retained across restarting either side during the pause.
 await connect_pair()
 host.on_disconnect(host.remote_peer);host.transport.drop(host.remote_peer)
 guest.on_disconnect(1);guest.transport.close();guest.retry_at=Time.get_ticks_msec()+60000
 host.disconnect_deadline_unix=Time.get_unix_time_from_system()-1;host.persist()
 host.leave(false)
 check(not host.restore_host().is_empty() and host.ended(),"host checkpoint cannot reopen after persisted deadline")
 guest.identity.resume.deadline=Time.get_unix_time_from_system()-1;guest.save_identity()
 var client_restart=Session.new();root.add_child(client_restart);client_restart.initialize("res://work/v1/network-guest")
 check(not client_restart.resume_guest().is_empty() and client_restart.ended(),"fresh guest process refuses expired resume record")
 client_restart.leave(false);client_restart.queue_free();host.leave(false);guest.leave(false)
 # The abandoned series must not poison a newly created room.
 await connect_pair()
 check(not host.ended() and not guest.ended() and host.authority.winner==-2,"new room after timeout is playable")
 host.leave(false);guest.leave(false)
 print("V1 NETWORK ",checks," checks; failures=",failures)
 quit(0 if failures.is_empty() else 1)
