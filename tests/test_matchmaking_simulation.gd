extends SceneTree
const Session=preload("res://net/lan_session.gd")
const Directory=preload("res://net/cloud_directory.gd")
var failures=[]
var checks=0
var sessions=[]
var match_events=[0,0,0,0,0,0]

func _initialize():call_deferred("run")
func check(ok: bool,label: String):
 checks+=1
 if ok:print("PASS: ",label)
 else:failures.append(label);push_error(label)
func until(predicate: Callable,seconds: float=12.0) -> bool:
 var deadline=Time.get_ticks_msec()+int(seconds*1000)
 while Time.get_ticks_msec()<deadline:
  if predicate.call():return true
  await process_frame
 return predicate.call()
func found(index: int):match_events[index]+=1
func cleanup():
 for session in sessions:session.leave(false)

func run():
 var args=OS.get_cmdline_user_args();var position=args.find("--manifest")
 if position<0 or position+1>=args.size():push_error("Test manifest is required");quit(2);return
 var config=JSON.parse_string(FileAccess.get_file_as_string(args[position+1]))
 if not config is Dictionary or config.get("endpoint","")!="ws://127.0.0.1:48045":push_error("Only the isolated loopback fixture is supported");quit(2);return
 for index in range(6):
  var session=Session.new();root.add_child(session)
  session.initialize("res://work/matchmaking-simulation/%s-%d" % [str(Time.get_ticks_usec()),index])
  session.cloud_token=str(config.players[index].token);session.cloud_nickname=str(config.players[index].nickname)
  session.match_found.connect(found.bind(index));sessions.append(session)
 var queue_started=Time.get_ticks_msec()
 for index in range(6):check(sessions[index].start_matchmaking(config.endpoint).is_empty(),"queue simulation player %d, Elo %d" % [index,int(config.players[index].elo)])
 var queued=await until(func():return sessions.all(func(session):return session.matchmaking and session.notice.contains("正在自动匹配")))
 check(queued,"six real authenticated clients enter the same initial batch")
 if not queued:cleanup();quit(1);return
 sessions[0].transport.relay_control("test_release_batch")
 check(await until(func():return sessions.slice(0,4).all(func(session):return session.can_act())),"first four players synchronize into two matches")
 check(not sessions[0].relay_code.is_empty() and sessions[0].relay_code==sessions[2].relay_code,"1000 pairs with 1010 ahead of the earlier 1080 request")
 check(not sessions[1].relay_code.is_empty() and sessions[1].relay_code==sessions[3].relay_code and sessions[0].relay_code!=sessions[1].relay_code,"remaining 1080 pairs with 1170 in a separate room")
 check(sessions[4].matchmaking and sessions[5].matchmaking and sessions[4].match_gap==100 and sessions[5].match_gap==100,"1400 and 1600 remain queued at the initial 100-point range")
 var directory=Directory.new();root.add_child(directory);var listings=[]
 directory.changed.connect(func():listings.append(true));directory.start(config.endpoint,str(config.players[6].token))
 check(await until(func():return not listings.is_empty()),"seventh account reads the cloud directory")
 check(directory.rooms.size()==2 and directory.rooms.all(func(info):return info.watch_only),"both active simulation matches offer spectating only")
 print("SIMULATION: first pairs 1000 / 1010 and 1080 / 1170; waiting in real time for the 1400 / 1600 pair.")
 var before_minute=true;var last_progress=0
 while sessions[4].matchmaking and sessions[5].matchmaking and Time.get_ticks_msec()-queue_started<75000:
  var elapsed=Time.get_ticks_msec()-queue_started
  if elapsed<59000 and (sessions[4].match_gap!=100 or sessions[5].match_gap!=100):before_minute=false
  if elapsed/1000>=last_progress+15:
   last_progress=elapsed/1000;print("SIMULATION WAIT: ",last_progress," seconds, ranges ",sessions[4].match_gap," / ",sessions[5].match_gap)
  await process_frame
 var elapsed=Time.get_ticks_msec()-queue_started
 check(before_minute,"the real server keeps the initial range before the minute threshold")
 check(not sessions[4].matchmaking and not sessions[5].matchmaking and elapsed>=60000,"the 200-point pair waits at least one real minute before matching")
 check(await until(func():return sessions[4].can_act() and sessions[5].can_act()),"expanded-range match synchronizes both players")
 check(not sessions[4].relay_code.is_empty() and sessions[4].relay_code==sessions[5].relay_code,"1400 pairs with 1600 after expansion")
 check(match_events==[1,1,1,1,1,1],"each client receives one match-success notification event")
 check(sessions.all(func(session):return session.room.get("format",0)==Session.Series.BO1_SIDEBOARD and session.room.get("strict",false)),"all three matches use strict BO1 sideboarding")
 check(sessions.all(func(session):return not session.room.has("elo") and not session.room.has("ratings")),"shared room states contain no player ratings")
 listings.clear();directory.refresh();await until(func():return not listings.is_empty())
 check(directory.rooms.size()==3 and directory.rooms.all(func(info):return info.watch_only),"all three matches offer spectating after expansion")
 directory.stop();directory.queue_free();cleanup()
 print("MATCHMAKING SIMULATION: ",checks," checks; ",failures.size()," failures; wide-pair wait ",elapsed," ms")
 quit(0 if failures.is_empty() else 1)
