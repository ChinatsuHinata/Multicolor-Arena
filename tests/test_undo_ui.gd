extends "res://tests/support/ui_base.gd"
const Session=preload("res://net/lan_session.gd")
const SeatProjection=preload("res://net/seat_projection.gd")
const DuelView=preload("res://scripts/duel_view.gd")

class RecordingSession extends "res://net/lan_session.gd":
 var commands: Array=[]
 var room_actions: Array=[]
 func submit(command: Dictionary) -> String:
  commands.append(command.duplicate(true));return ""
 func room_action(action: Dictionary):
  room_actions.append(action.duplicate(true))

var session: RecordingSession
var authority
var sequence=1

func frames(count: int=3):
 for index in range(count):await process_frame

func packet(rewind: Dictionary={}) -> Dictionary:
 var projected=SeatProjection.build(authority,session.seat)
 projected.queries.response=false
 return {"sequence":sequence,"game_id":"undo-ui-game","projection":projected,"rewinds":[] if rewind.is_empty() else [rewind]}

func queue_packet(next: Dictionary):
 session.sequence=int(next.sequence)
 session.latest_snapshot=next.duplicate(true)
 session.snapshots.append(next.duplicate(true))

func open_case(mobile: bool,seat: int):
 if is_instance_valid(view):
  view.queue_free();app.duel_view=null
  session.queue_free();await frames()
 app.is_android=mobile;app.layout_dpi_override=360 if mobile else 0
 app.layout_safe_override=Rect2(40,0,1520,860) if mobile else Rect2()
 app.refresh_responsive_layout();app.clear_page("battle")
 authority=Session.Duel.new();authority.start(app.decks[app.player_choice],app.decks[app.ai_choice],seat,42)
 for player in authority.players:
  for zone in ["hand","palette","field","grave","exile","deck"]:player[zone]=[]
  player.mulligan_done=true;player.turns=3
 authority.presentation_events=[];authority.pending={};authority.stack=[];authority.combat={}
 authority.phase="end";authority.turn=6;authority.active=seat;authority.priority=seat;authority.passes=0
 sequence=1
 session=RecordingSession.new();root.add_child(session);session.set_process(false)
 session.seat=seat;session.connected=true;session.paused=false
 session.room={"status":"playing","game_id":"undo-ui-game","round":1,"scores":[0,0],"names":["玩家甲","玩家乙"],"format":3,"undo_available":true,"undo_request":{}}
 queue_packet(packet())
 view=DuelView.new();app.screen.add_child(view);app.duel_view=view
 view.begin(app,{},{},0,0,session);view.set_process(false);view.fast_mode=true
 await frames()
 session.commands.clear();session.room_actions.clear()

func pause_and_resume(label: String,mode: int,requester: int):
 view.set_response_mode(mode)
 sequence+=1
 var rewind={"id":sequence,"from":requester,"target":1}
 view.local={"kind":"private_selection"};view.selection=[999];view.attack_preview_uid=999
 view.clock_time=12.0
 queue_packet(packet(rewind));view._process(10.0)
 var until=view.undo_auto_pause_until
 expect(view.local.is_empty() and view.selection.is_empty() and view.attack_preview_uid==0,label+" rewind clears uncommitted local choices")
 expect(until-Time.get_ticks_msec()>3000 and until-Time.get_ticks_msec()<=view.UNDO_AUTO_PAUSE_MS,label+" accepted rewind pauses automatic progression for both seats")
 expect(session.commands.is_empty() and view.clock_time==0,label+" automatic priority passing stays paused")
 queue_packet(packet(rewind));view._process(10.0)
 expect(view.undo_auto_pause_until==until,label+" duplicate rewind snapshot does not restart the pause")
 expect(session.commands.is_empty(),label+" duplicate snapshot cannot advance restored priority")
 view.pass_response()
 expect(session.commands.size()==1 and session.commands.back().name=="pass_priority",label+" player can act manually during the automatic pause")
 expect(view.undo_auto_pause_until==until,label+" manual response does not restart the pause")
 session.commands.clear()
 view.undo_auto_pause_until=Time.get_ticks_msec()-1;view.clock_time=0
 view._process(1.0)
 expect(session.commands.size()==1 and session.commands.back().name=="pass_priority",label+" automatic response resumes after the grace period")
 expect(view.response_mode==mode,label+" rewind preserves the selected response mode")
 session.commands.clear()

func menu_and_reply(label: String):
 session.room.undo_request={}
 view.render()
 var actions=view.responsive.tools_actions()
 var undo=actions.filter(func(action):return action[0] in ["悔棋","请求悔棋"])
 expect(undo.size()==1 and not undo[0][2],label+" tools menu offers an actionable undo request")
 if undo.size()==1:undo[0][1].call()
 expect(session.room_actions.size()==1 and session.room_actions.back()=={"name":"undo_request"},label+" menu requests undo through shared room_action")
 session.room.undo_request={"id":77,"from":1-session.seat,"target":1}
 view.render()
 for reply in [["同意" if view.is_android else "同意悔棋","undo_accept"],["拒绝" if view.is_android else "拒绝悔棋","undo_decline"]]:
  var choice=find_button(view.ui,reply[0])
  expect(choice!=null and not choice.disabled,label+" opponent request exposes "+reply[0])
  if choice!=null:choice.pressed.emit()
  expect(session.room_actions.back()=={"name":reply[1],"ticket":77},label+" "+reply[0]+" uses the shared request ticket")
 session.room.undo_request={"id":78,"from":session.seat,"target":1}
 view.render()
 var cancel=find_button(view.ui,"取消请求")
 expect(cancel!=null and not cancel.disabled,label+" requester can cancel instead of approving their own request")
 if cancel!=null:cancel.pressed.emit()
 expect(session.room_actions.back()=={"name":"undo_cancel","ticket":78},label+" cancel uses shared room_action")
 session.room.undo_request={};session.room_actions.clear()

func observer_exclusions(label: String):
 for replay in [false,true]:
  session.read_only=not replay;session.replay_mode=replay
  view.undo_auto_pause_until=0;view.clock_time=5.0
  sequence+=1
  view.observe_rewind(packet({"id":sequence,"from":session.seat,"target":1}))
  var role="replay" if replay else "spectator"
  expect(view.undo_auto_pause_until==0 and view.clock_time==5.0,label+" "+role+" does not receive a player automation pause")
  expect(not view.responsive.tools_actions().any(func(action):return action[0] in ["悔棋","请求悔棋"]),label+" "+role+" cannot request player undo")
 session.read_only=false;session.replay_mode=false

func run():
 Store.Paths.root_override=ProjectSettings.globalize_path("res://work/undo-ui/"+str(Time.get_ticks_usec()))
 root.mode=Window.MODE_WINDOWED;root.size=Vector2i(1600,900)
 root.content_scale_size=Vector2i(1600,900);root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS;root.content_scale_aspect=Window.CONTENT_SCALE_ASPECT_EXPAND
 app=load("res://main.tscn").instantiate();root.add_child(app);await frames();app.load_legacy_test_decks()
 for mobile in [false,true]:
  for seat in [0,1]:
   await open_case(mobile,seat)
   var label=("Android" if mobile else "PC")+" seat "+str(seat)
   for requester in [0,1]:
    await pause_and_resume(label+" requester "+str(requester)+" default response",view.ResponseMode.DEFAULT,requester)
    await pause_and_resume(label+" requester "+str(requester)+" response off",view.ResponseMode.OFF,requester)
   await menu_and_reply(label)
   observer_exclusions(label)
 print("UNDO UI: %d/%d checks" % [checks-failures.size(),checks])
 app.queue_free();session.queue_free();await process_frame
 quit(0 if failures.is_empty() else 1)
