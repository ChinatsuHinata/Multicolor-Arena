extends "res://tests/support/ui_base.gd"
const Session=preload("res://net/lan_session.gd")
const SeatProjection=preload("res://net/seat_projection.gd")
const DuelView=preload("res://scripts/duel_view.gd")

class RecordingSession extends "res://net/lan_session.gd":
 var commands: Array=[]
 func submit(command: Dictionary) -> String:
  if not can_act(true):return "等待连接或同步完成"
  commands.append(command.duplicate(true));return ""

var sessions=[]
var views=[]
var decks=[]
var sequence=1
var game_id="mulligan-selection-game"

func frames(count: int=3):
 for index in range(count):await process_frame

func packet(seat: int) -> Dictionary:
 return {"sequence":sequence,"game_id":game_id,"projection":SeatProjection.build(e,seat)}

func queue_packet(session,next: Dictionary):
 session.sequence=next.sequence
 session.latest_snapshot=next.duplicate(true)
 session.snapshots.append(next.duplicate(true))

func open_case(mobile: bool,cloud: bool):
 app.clear_page("battle")
 for session in sessions:session.queue_free()
 sessions.clear();views.clear();await frames()
 root.size=Vector2i(1280,720) if mobile else Vector2i(1600,900)
 app.is_android=mobile;app.layout_dpi_override=360 if mobile else 0
 app.layout_safe_override=Rect2(40,12,1200,684) if mobile else Rect2()
 app.refresh_responsive_layout()
 e=Session.Duel.new();e.start(decks[0],decks[1],0,45);e.presentation_events.clear()
 sequence=1;game_id="mulligan-selection-game"
 for seat in [0,1]:
  var session=RecordingSession.new();root.add_child(session);session.set_process(false)
  session.seat=seat;session.is_host=seat==0;session.cloud_mode=cloud
  session.connected=true;session.paused=false
  session.room={"status":"playing","game_id":game_id,"round":1,"scores":[0,0],"names":["玩家甲","玩家乙"],"format":1}
  queue_packet(session,packet(seat));sessions.append(session)
  var surface=DuelView.new();app.screen.add_child(surface);views.append(surface)
  surface.begin(app,{},{},0,0,session);surface.set_process(false)
 await frames()

func selected_styles(surface,chosen: Array) -> bool:
 return chosen.all(func(uid):return surface.hand_nodes.has(uid) and surface.hand_nodes[uid].get_theme_stylebox("panel").border_color==Color("#ffd65c"))

func confirm(surface,label: String):
 var button=find_button(surface.hud,"调度 2 张")
 expect(button!=null and not button.disabled,label+" confirmation keeps the selected count")
 if button!=null and not button.disabled:button.pressed.emit()

func check_submission(mobile: bool,cloud: bool,first_submit: int):
 await open_case(mobile,cloud)
 var label=("Android" if mobile else "PC")+" / "+("cloud" if cloud else "LAN")+" / first seat "+str(first_submit)
 var choices=e.players.map(func(player):return [player.hand[0].uid,player.hand[1].uid])
 for seat in [0,1]:
  for uid in choices[seat]:views[seat].hand_clicked(uid)
 expect(views[0].selection==choices[0] and views[1].selection==choices[1],label+" both players select before either confirms")
 confirm(views[first_submit],label)
 expect(sessions[first_submit].commands.size()==1 and sessions[first_submit].commands[0].args==[choices[first_submit]],label+" first confirmation submits the chosen cards")
 if not sessions[first_submit].commands.is_empty():e.mulligan(first_submit,sessions[first_submit].commands[0].args[0])
 sequence+=1
 for seat in [0,1]:queue_packet(sessions[seat],packet(seat))
 var other=1-first_submit
 if cloud:
  sessions[0].paused=true;sessions[0].changed.emit()
  expect(views[other].selection==choices[other],label+" cloud acknowledgment pause preserves the unconfirmed choice")
  expect(views[0].network_locked(),label+" cloud acknowledgment still locks actions")
 for surface in views:surface._process(0.0)
 expect(views[other].selection==choices[other] and selected_styles(views[other],choices[other]),label+" opponent confirmation snapshot preserves cards and their highlights")
 if cloud:
  sessions[0].paused=false;sessions[0].changed.emit()
 queue_packet(sessions[other],packet(other));views[other]._process(0.0)
 expect(views[other].selection==choices[other],label+" repeated unchanged snapshot preserves the choice")
 confirm(views[other],label)
 expect(sessions[other].commands.size()==1 and sessions[other].commands[0].args==[choices[other]],label+" second player confirms the original choice without reselecting")
 if not sessions[other].commands.is_empty():e.mulligan(other,sessions[other].commands[0].args[0])
 e.presentation_events.clear();sequence+=1
 for seat in [0,1]:
  queue_packet(sessions[seat],packet(seat));views[seat]._process(0.0)
 expect(e.phase!="mulligan" and views.all(func(surface):return surface.selection.is_empty()),label+" both submissions resolve and clear the selection")
 expect(e.players.all(func(player):return player.hand.size()==4 and player.hand.all(func(card):return card.uid not in choices[card.owner])),label+" both original choices receive replacement cards")

func check_invalid_updates():
 await open_case(false,true)
 var surface=views[0];var session=sessions[0]
 for reason in ["recovery","new game","changed hand","changed epoch","own submission","phase change","rewind"]:
  e.start(decks[0],decks[1],0,45);e.presentation_events.clear()
  session.local_game_id=game_id;surface.engine.apply_snapshot(packet(0).projection)
  surface.selection=[e.players[0].hand[0].uid];surface.render()
  var next=packet(0)
  match reason:
   "recovery":next.recovery=true
   "new game":next.game_id="another-game"
   "changed hand":next.projection.state.players[0].hand.pop_back()
   "changed epoch":next.projection.state.players[0].hand[0].epoch+=1
   "own submission":next.projection.state.players[0].mulligan_done=true
   "phase change":next.projection.state.phase="prepare"
   "rewind":next.rewinds=[{"id":sequence+1}]
  queue_packet(session,next);surface._process(0.0)
  expect(surface.selection.is_empty(),reason+" clears a stale mulligan choice")
 e.start(decks[0],decks[1],0,45);e.presentation_events.clear()
 session.local_game_id=game_id;surface.engine.apply_snapshot(packet(0).projection)
 surface.selection=[e.players[0].hand[0].uid]
 session.connected=false;session.paused=true;session.changed.emit()
 expect(surface.selection.is_empty() and surface.network_locked(),"disconnect clears private selections and locks interaction")

func run():
 var fixture="res://work/mulligan-selection-ui/"+str(Time.get_ticks_usec())
 Store.Paths.root_override=ProjectSettings.globalize_path(fixture)
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(fixture))
 root.mode=Window.MODE_WINDOWED;root.content_scale_size=Vector2i(1600,900)
 root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS;root.content_scale_aspect=Window.CONTENT_SCALE_ASPECT_EXPAND
 app=load("res://main.tscn").instantiate()
 app.settings_path=fixture+"/settings.json";app.account_session_path=fixture+"/account.json";app.lan_storage_directory=fixture+"/unused-session"
 app.tutorial_local_directory=fixture+"/tutorials"
 root.add_child(app);await frames()
 decks=JSON.parse_string(FileAccess.get_file_as_string("res://data/test_precons.json")).decks
 for mobile in [false,true]:
  for cloud in [false,true]:
   for first_submit in [0,1]:await check_submission(mobile,cloud,first_submit)
 await check_invalid_updates()
 print("MULLIGAN SELECTION UI: %d checks; %d failures" % [checks,failures.size()])
 app.queue_free()
 for session in sessions:session.queue_free()
 await frames();quit(0 if failures.is_empty() else 1)
