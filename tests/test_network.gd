extends "res://tests/support/network_base.gd"
class CapturedTransport:
 extends Node
 var sent=[]
 func send_to(_id,message,_heartbeat=false):sent.append(message)
class FailedSave:
 extends "res://net/lan_session.gd"
 func persist() -> bool:
  paused=true;notice="test storage failure";return false

func connect_pair():
 check(host.create_room(3,true,47981,"127.0.0.1").is_empty(),"create BO3")
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
 check(ProjectSettings.get_setting("application/config/name")=="multicolor:arena","project name is correct")
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
 host.initialize("res://work/network-current/network-host");guest.initialize("res://work/network-current/network-guest")
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
 check(not host.check_reconnect_timeout(host_start+30000) and not guest.check_reconnect_timeout(guest_start+30000),"30 seconds offers a wait decision without ending the match")
 check(host.wait_choice_pending and guest.wait_choice_pending and not host.ended() and not guest.ended(),"both players can choose whether to keep waiting")
 check(host.room.status=="playing" and guest.room.status=="playing" and host.series.state.scores==scores and host.series.state.counted==counted,"waiting does not award a win or change played scores")
 check(host.Codec.capture(host.authority)==frozen and not host.can_act() and not guest.can_act(),"waiting preserves the battlefield and keeps actions locked")
 host.continue_waiting();guest.continue_waiting()
 check(host.wait_choice_confirmed and guest.wait_choice_confirmed and not host.check_reconnect_timeout(host_start+90000) and not guest.check_reconnect_timeout(guest_start+90000),"confirmed wait has no later timeout")
 check(not host.wait_choice_pending and not guest.wait_choice_pending and host.connection_status().contains("持续等待"),"wait choice stays dismissed")
 guest.retry_at=0
 check(await until(func():return host.can_act() and guest.can_act(),12),"original players can reconnect after 30 seconds")
 sync_views()
 check(host.disconnected_at==0 and guest.disconnected_at==0 and host.series.state.scores==scores,"late reconnection resumes original match")
 # The elapsed grace period is retained across restarting either side.
 await connect_pair()
 host.on_disconnect(host.remote_peer);host.transport.drop(host.remote_peer)
 guest.on_disconnect(1);guest.transport.close();guest.retry_at=Time.get_ticks_msec()+60000
 host.disconnect_deadline_unix=Time.get_unix_time_from_system()-1;host.persist()
 host.leave(false)
 check(host.restore_host().is_empty() and host.wait_choice_pending and not host.ended(),"host checkpoint remains recoverable after 30 seconds")
 guest.identity.resume.deadline=Time.get_unix_time_from_system()-1;guest.save_identity()
 var client_restart=Session.new();root.add_child(client_restart);client_restart.initialize("res://work/network-current/network-guest")
 guest.leave(false)
 check(client_restart.resume_guest().is_empty() and client_restart.wait_choice_pending,"fresh guest process can resume an old disconnected match")
 check(await until(func():return host.can_act() and client_restart.can_act(),12),"restored host accepts guest after the old deadline")
 host.on_disconnect(host.remote_peer);host.transport.drop(host.remote_peer)
 client_restart.on_disconnect(1);client_restart.transport.close();client_restart.retry_at=Time.get_ticks_msec()+60000
 host.check_reconnect_timeout(host.disconnected_at+30000);client_restart.check_reconnect_timeout(client_restart.disconnected_at+30000)
 var abandoned_id=host.room_id
 host.stop_waiting();client_restart.stop_waiting()
 check(host.room_id.is_empty() and client_restart.room_id.is_empty() and abandoned_id in host.identity.ended_rooms and abandoned_id in client_restart.identity.ended_rooms,"either player can leave waiting without a forfeit")
 check(not host.restore_host().is_empty() and not client_restart.resume_guest().is_empty(),"explicitly left match cannot reopen")
 client_restart.queue_free();host.leave(false);guest.leave(false)
 # An abandoned series must not poison a newly created room.
 await connect_pair()
 check(not host.ended() and not guest.ended() and host.authority.winner==-2,"new room after leaving is playable")
 host.on_disconnect(host.remote_peer);host.transport.drop(host.remote_peer)
 guest.on_disconnect(1);guest.transport.close();guest.retry_at=Time.get_ticks_msec()+60000
 var early_id=host.room_id
 host.stop_waiting();guest.stop_waiting()
 check(early_id in host.identity.ended_rooms and early_id in guest.identity.ended_rooms and host.series.state.status=="aborted" and not host.series.state.has("forfeit"),"exit is available before 30 seconds and does not award a win")
 host.leave(false);guest.leave(false)
 print("NETWORK ",checks," checks; failures=",failures)
 quit(0 if failures.is_empty() else 1)
