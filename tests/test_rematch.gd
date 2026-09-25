extends SceneTree
const Session=preload("res://net/lan_session.gd")
const Store=preload("res://scripts/deck_store.gd")
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
func drain(host,guest):
 for session in [host,guest]:
  while not session.snapshots.is_empty():session.pop_snapshot()
func find_button(node: Node,title: String) -> Button:
 if node is Button and node.text==title:return node
 for child in node.get_children():
  var found=find_button(child,title)
  if found!=null:return found
 return null
func start_game(host,guest):
 host.room_action({"name":"ready"});guest.room_action({"name":"ready"})
 check(await until(func():return host.series.state.status=="choosing" and guest.room.get("status","")=="choosing" and host.can_act() and guest.can_act()),"both seats ready for first-player choice")
 var choosing=host if host.series.state.chooser==0 else guest
 choosing.room_action({"name":"first","first":true})
 check(await until(func():return host.series.state.status=="playing" and guest.room.get("game_id","")==host.series.state.game_id),"chooser starts game")
 drain(host,guest)
func end_game(host,guest,index: int):
 host.handle_command(1,{"id":"rematch-result-%d-%d" % [host.series.state.format,index],"room_id":host.room_id,"game_id":host.series.state.game_id,"expected":host.sequence,"command":{"name":"surrender","args":[]}})
 check(await until(func():return guest.room.get("status","")==host.series.state.status and guest.sequence==host.sequence and host.series.state.status!="playing"),"result reaches both seats")
 drain(host,guest)
func run_format(format_value: int,port: int,decks: Array):
 var clean=[Store.clean_deck(decks[0]),Store.clean_deck(decks[1])]
 var host=Session.new();var guest=Session.new();root.add_child(host);root.add_child(guest)
 var run_id="%d-%d" % [format_value,Time.get_ticks_usec()]
 host.initialize("res://work/rematch/%s-host" % run_id);guest.initialize("res://work/rematch/%s-guest" % run_id)
 check(host.create_room(format_value,false,port,"127.0.0.1").is_empty(),"BO%d host listens" % format_value)
 check(guest.join_room("127.0.0.1",port).is_empty(),"guest joins")
 check(await until(func():return not host.applicant.is_empty()),"guest approval arrives")
 host.accept_applicant(true)
 check(await until(func():return host.can_act() and guest.can_act()),"both seats connected")
 host.room_action({"name":"deck","deck":decks[0]});guest.room_action({"name":"deck","deck":decks[1]})
 check(await until(func():return not host.series.state.decks[1].is_empty() and guest.room.get("own_deck",{})==host.series.state.decks[1]),"initial decks synchronized")
 await start_game(host,guest)
 var first_match=host.series.state.match_id;var first_game=host.series.state.game_id
 await end_game(host,guest,1)
 if format_value==3:
  check(host.series.state.status=="between","BO3 still has a sideboard round")
  check(host.series.set_deck(1,decks[0])!="","BO3 sideboard cannot replace registered deck")
  await start_game(host,guest)
  await end_game(host,guest,2)
 check(host.series.state.status=="complete" and guest.room.get("status","")=="complete","series completed")
 var old_game=host.series.state.game_id
 var app: Control=null
 if format_value==1:
  app=load("res://main.tscn").instantiate();root.add_child(app);await process_frame
  app.lan_session=guest;app.online();await process_frame
  var rematch_button=find_button(app.screen,"更换卡组，再来一场")
  check(rematch_button!=null and not rematch_button.disabled,"completed room offers rematch")
  if rematch_button!=null:rematch_button.pressed.emit()
 else:host.room_action({"name":"rematch"})
 check(await until(func():return host.series.state.status=="lobby" and guest.room.get("match_id","")==host.series.state.match_id),"rematch returns both players to lobby")
 if app!=null:check(find_button(app.screen,"选择此卡组")!=null and find_button(app.screen,"准备")!=null,"rematch room allows deck selection and ready")
 check(host.series.state.match_id!=first_match and host.series.state.game_id.is_empty() and host.series.state.scores==[0,0] and host.series.state.round==0 and host.series.state.ready==[false,false],"rematch resets match history")
 check(host.series.state.decks==clean and host.series.state.registered==[{},{}],"old decks remain selected and registration is cleared")
 check(host.authority==null and host.latest_snapshot.is_empty() and guest.latest_snapshot.is_empty() and host.recording.frames.is_empty() and guest.recording.frames.is_empty(),"old game state and replay are cleared")
 check(host.series.set_deck(0,decks[1]).is_empty(),"new match accepts another full deck")
 host.room_action({"name":"deck","deck":decks[1]});guest.room_action({"name":"deck","deck":decks[0]})
 check(await until(func():return host.series.state.decks[1]==clean[0] and guest.room.get("own_deck",{})==clean[0]),"replacement decks synchronized")
 await start_game(host,guest)
 check(host.series.state.round==1 and host.series.state.scores==[0,0] and host.series.state.game_id!=old_game and host.series.state.game_id!=first_game,"new series starts at game one")
 check(host.series.state.registered==[clean[1],clean[0]] and host.authority!=null,"new decks registered for new series")
 check(host.recording.metadata.get("room",{}).get("match_id","")==host.series.state.match_id and guest.recording.metadata.get("room",{}).get("match_id","")==host.series.state.match_id,"new replay records only new match")
 host.leave(false);guest.leave(false);host.queue_free();guest.queue_free()
 if app!=null:app.queue_free()
func run():
 var decks=JSON.parse_string(FileAccess.get_file_as_string("res://data/test_precons.json")).decks
 await run_format(1,47991,decks)
 await run_format(3,47993,decks)
 print("REMATCH ",checks," checks; failures=",failures)
 quit(0 if failures.is_empty() else 1)
