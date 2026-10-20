extends SceneTree
const Session=preload("res://net/lan_session.gd")
var failures=[]
var checks=0
func _initialize():call_deferred("run")
func check(ok: bool,label: String):
 checks+=1
 if ok:print("PASS: ",label)
 else:failures.append(label);push_error(label)
func fixture(host: bool,mode: String):
 var session=Session.new();root.add_child(session)
 session.initialize("res://work/match-connection-timeout/"+str(Time.get_ticks_usec()))
 session.set_process(false);session.transport.set_process(false)
 session.cloud_mode=true;session.cloud_ranked=true;session.is_host=host
 session.cloud_match_id="TEST_ONLY_TIMEOUT";session.cloud_token="a".repeat(64);session.cloud_account="TEST_ONLY_TIMEOUT"
 session.address="127.0.0.1";session.port=48049;session.relay_websocket=true;session.relay_code="ABCDEF123456"
 session.cloud_slot=1 if host else 2;session.seat=session.cloud_slot-1;session.match_mode=mode
 session.series.setup(session.match_format(),true,session.match_rule_set())
 session.room=session.series.public_state(session.seat);session.room_id="TEST_ONLY_ROOM" if host else ""
 session.identity.resume={"cloud_match_id":session.cloud_match_id,"token":"b".repeat(64)}
 session.start_disconnect_wait()
 return session
func run():
 for mode in ["ranked","casual","exploration"]:
  for host in [true,false]:
   var session=fixture(host,mode)
   var started=session.disconnected_at;var deadline=session.disconnect_deadline_unix
   check(started>0 and deadline>0 and session.reconnect_limit_ms()==60000,"matched handshake starts a one-minute deadline: "+mode+" / "+str(host))
   check(not session.check_reconnect_timeout(started+30000) and not session.wait_choice_pending,"match continues automatic recovery after 30 seconds")
   session.on_failure("TEST_ONLY_CONNECTION_FAILURE")
   check(session.disconnected_at==started and session.disconnect_deadline_unix==deadline,"failed retry preserves the original deadline")
   check(session.saved_ranked_recovery().deadline==deadline,"saved recovery retains the absolute deadline across restart")
   check(not session.check_reconnect_timeout(started+59999) and session.ranked_match_pending(),"59 seconds retains the pending match")
   check(session.check_reconnect_timeout(started+60000) and not session.ranked_match_pending(),"60 seconds releases the pending match")
   check(session.room.status=="aborted" and session.identity.resume.is_empty() and session.saved_ranked_recovery().is_empty() and not session.transport.online,"expiry clears recovery, stops reconnecting and closes the connection")
   check(session.notice.contains("60 秒") and session.room.get("winner",-2)==-2,"expiry explains release without creating a local rated result")
   session.leave(false);session.queue_free();await process_frame
 for host in [true,false]:
  var session=fixture(host,"ranked")
  session.transport.online=true;session.transport.last_server_seen=Time.get_ticks_msec()
  session.disconnect_deadline_unix=Time.get_unix_time_from_system()-1
  check(not session.check_reconnect_timeout(Time.get_ticks_msec()) and session.ranked_match_pending(),"healthy relay waits for authoritative settlement rather than locally cancelling")
  session.on_relay_link_status({"match_id":session.cloud_match_id,"source":"relay_observation","states":["online","offline"]})
  check(session.notice.contains("对方" if host else "本方"),"server evidence is displayed relative to this player's seat")
  check(session.connection_status().contains("对方" if host else "本方"),"the visible recovery panel retains the attributed side")
  session.retry_connection(Time.get_ticks_msec())
  check(session.transport.online,"game-sync silence does not close a healthy relay connection")
  session.leave(false);session.queue_free();await process_frame
 var original=fixture(false,"exploration");var saved=original.saved_ranked_recovery();var storage=original.storage
 original.queue_free();await process_frame
 var restored=Session.new();root.add_child(restored);restored.initialize(storage);restored.set_process(false);restored.transport.set_process(false)
 restored.cloud_token="a".repeat(64);restored.cloud_account="TEST_ONLY_TIMEOUT"
 check(restored.restore_ranked_match(saved).is_empty() and restored.disconnect_deadline_unix==saved.deadline,"guest restart keeps its original minute instead of granting a fresh minute")
 restored.disconnect_deadline_unix=Time.get_unix_time_from_system()-1
 check(restored.check_reconnect_timeout(Time.get_ticks_msec()) and restored.saved_ranked_recovery().is_empty(),"expired wall-clock deadline releases recovery even after process restart")
 restored.leave(false);restored.queue_free();await process_frame
 var queue_session=Session.new();root.add_child(queue_session);queue_session.initialize("res://work/match-connection-timeout/queue-"+str(Time.get_ticks_usec()));queue_session.set_process(false);queue_session.transport.set_process(false)
 queue_session.cloud_token="a".repeat(64)
 check(queue_session.start_matchmaking("ws://127.0.0.1:48049",{},true,"exploration").is_empty(),"queue connection fixture starts on loopback")
 var connecting_since=queue_session.match_connect_started
 check(not queue_session.check_reconnect_timeout(connecting_since+59999) and queue_session.matchmaking,"unacknowledged queue connection waits for at most one minute")
 check(queue_session.check_reconnect_timeout(connecting_since+60000) and not queue_session.matchmaking and not queue_session.transport.online,"unacknowledged queue connection releases after one minute")
 queue_session.start_matchmaking("ws://127.0.0.1:48049",{},true,"exploration")
 queue_session.transport.relay_match_queued.emit(0,0,1)
 check(queue_session.match_connect_started==0 and not queue_session.check_reconnect_timeout(Time.get_ticks_msec()+60000) and queue_session.matchmaking,"confirmed queue waiting remains available while looking for an opponent")
 queue_session.leave(false);queue_session.queue_free();await process_frame
 print("MATCH CONNECTION TIMEOUT: %d checks; %d failures" % [checks,failures.size()])
 quit(0 if failures.is_empty() else 1)
