extends "res://tests/support/network_base.gd"
const Clock=preload("res://scripts/response_clock.gd")
const Remote=preload("res://net/remote_duel.gd")

func run():
 var directory="res://work/network-response-timeout/"+str(Time.get_ticks_usec())
 host=Session.new();guest=Session.new();root.add_child(host);root.add_child(guest)
 host.initialize(directory+"/host");guest.initialize(directory+"/guest")
 check(host.create_room(1,true,47986,"127.0.0.1").is_empty(),"create isolated response-timeout room")
 guest.join_room("127.0.0.1",47986)
 var joined=await until(func():return not host.applicant.is_empty())
 check(joined,"guest requests entry")
 if not joined:host.leave(false);guest.leave(false);quit(1);return
 host.accept_applicant(true)
 check(await until(func():return host.can_act() and guest.can_act()),"both clients synchronize")
 var decks=JSON.parse_string(FileAccess.get_file_as_string("res://data/test_precons.json")).decks
 for seat in [0,1]:host.handle_room_action(seat,{"name":"deck","deck":decks[seat]})
 await until(func():return guest.sequence==host.sequence)
 await prepare()
 # Hold a real guest response in the preparation phase, with automatic passing absent.
 var e=host.authority
 for player in e.players:player.mulligan_done=true
 e.phase="prepare";e.pending={};e.entry_choices=[];e.combat={};e.stack=[];e.active=0;e.priority=1;e.passes=0
 host.publish();await process_frame;sync_views()
 var deadline=float(e.response_clock.deadline)
 var sequence=host.sequence
 host.check_response_timeout(deadline-0.001)
 check(host.sequence==sequence and e.priority==1,"authority does not release priority before the deadline")
 host.paused=true;host.check_response_timeout(deadline)
 check(host.sequence==sequence,"paused connections cannot submit a timeout command")
 host.paused=false
 host.check_response_timeout(deadline)
 check(host.sequence==sequence+1 and host.room.status=="complete" and host.room.winner==0 and host.room.forfeit==1,"guest timeout forfeits the entire match exactly once")
 check(e.winner==0 and e.phase=="over" and e.response_clock.is_empty(),"authority ends the game and clears its countdown")
 check(host.room.scores==[0,0] and host.room.get("end_cause","")=="response_timeout","forfeit keeps actual scores without inventing played games")
 check(await until(func():return guest.sequence==host.sequence),"guest receives the final timeout result")
 var remote=Remote.new();remote.apply_snapshot(guest.latest_snapshot.projection)
 check(remote.winner==0 and remote.phase=="over" and guest.room.forfeit==1,"guest agrees with the authoritative loss")
 check(host.latest_snapshot.projection.state.response_clock==guest.latest_snapshot.projection.state.response_clock,"both seats receive the cleared deadline")
 var data=Session.Journal.load_from(host.storage+"/host.bin")
 var saved=Session.Duel.new();Session.Codec.restore(saved,data.engine)
 check(saved.winner==0 and saved.response_clock.is_empty() and data.series.forfeit==1,"timeout loss and cleared clock are persisted together")
 sequence=host.sequence;host.check_response_timeout()
 check(host.sequence==sequence,"another frame cannot repeat the expired response")
 var guest_before=guest.sequence;guest.check_response_timeout(deadline+1000)
 check(guest.sequence==guest_before,"guest cannot enforce a local timeout")
 check(await until(func():return not host.transport.online and not guest.transport.online),"both player connections are released automatically")
 check(not host.spectator_hub.listening and not host.can_act() and not guest.can_act(),"spectator listener is closed and ended players cannot act")
 check(guest.identity.resume.is_empty() and host.room_id in host.identity.ended_rooms and guest.room_id in guest.identity.ended_rooms,"old room cannot be resumed")
 var probe=Session.Transport.new();root.add_child(probe)
 check(probe.host_room(47986,"127.0.0.1")==OK,"the released battle port can be reused")
 probe.close();probe.queue_free()
 host.leave(false);guest.leave(false)
 print("NETWORK RESPONSE TIMEOUT: ",checks," checks; ",failures.size()," failures")
 quit(0 if failures.is_empty() else 1)
