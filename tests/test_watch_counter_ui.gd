extends "res://tests/support/ui_base.gd"
const Session=preload("res://net/lan_session.gd")
const SeatView=preload("res://net/seat_projection.gd")
const DuelView=preload("res://scripts/duel_view.gd")

class RecordingSession extends "res://net/lan_session.gd":
 var commands=[]
 func submit(command: Dictionary) -> String:
  commands.append(command.duplicate(true));return ""

var session
var authority

func frames(count: int=5):
 for i in range(count):await process_frame

func check_client(android: bool,seat: int):
 if is_instance_valid(view):
  view.queue_free();app.duel_view=null;session.queue_free();await frames()
 app.is_android=android;app.layout_dpi_override=320 if android else 0
 app.refresh_responsive_layout();app.clear_page("battle")
 authority=Session.Duel.new();authority.start(app.decks[0],app.decks[1],0,42)
 for p in authority.players:
  for z in ["hand","palette","field","grave","exile"]:p[z]=[]
  p.mulligan_done=true;p.turns=3
 authority.pending={};authority.stack=[];authority.presentation_events=[]
 authority.phase="main";authority.turn=6;authority.active=1-seat;authority.priority=1-seat
 e=authority
 var aya=put("79","field",1-seat);aya.leader=true
 var target=put("53","field",1-seat)
 var barrier=put("field-rei-003","field",seat)
 expect(authority.commit_extension(1-seat,aya.uid,authority.ref_target(target),[],"leader_bounce").is_empty(),"启动文的真实回手能力")
 var stack_id=authority.stack.back().id
 session=RecordingSession.new();root.add_child(session);session.set_process(false)
 session.seat=seat;session.connected=true;session.paused=false
 session.room={"status":"playing","game_id":"watch-counter-ui","round":1,"scores":[0,0],"names":["甲","乙"],"format":1,"undo_request":{}}
 var packet={"sequence":1,"game_id":"watch-counter-ui","projection":SeatView.build(authority,seat)}
 session.sequence=1;session.latest_snapshot=packet.duplicate(true);session.snapshots.append(packet)
 view=DuelView.new();app.screen.add_child(view);app.duel_view=view
 view.begin(app,{},{},0,0,session);view.set_process(false);view.fast_mode=true
 e=view.engine;await frames();session.commands.clear()
 var label=("安卓" if android else "PC")+"玩家%d" % seat
 expect(view.should_ask_response(),label+"默认响应保留警醒阵窗口")
 view.open_actions(e.find_card(barrier.uid));await frames()
 var rows=view.android_choice_panel.find_child("ActionChoiceGrid",true,false) if is_instance_valid(view.android_choice_panel) else null
 var button
 if rows!=null:
  for child in rows.get_children():
   if child.get_meta("action_type","")=="extension":button=child;break
 expect(button!=null and not button.disabled,label+"可点击警醒阵的启动能力")
 if button==null or button.disabled:return
 button.pressed.emit();await frames()
 expect(view.picker.available_refs().any(func(r):return r.get("stack_id",-1)==stack_id),label+"可以选择文在堆叠的能力")
 expect(view.stack_panel.tiles.has(stack_id),label+"显示文的能力卡图")
 var tile=view.stack_panel.tiles[stack_id].tile
 expect(tile.get_meta("legal",false),label+"文的能力卡图高亮为合法目标")
 var at=tile.get_global_rect().get_center()
 if android:
  var touch=InputEventScreenTouch.new();touch.index=0;touch.position=at;touch.pressed=true;root.push_input(touch,true);await frames()
  touch=touch.duplicate();touch.pressed=false;root.push_input(touch,true);await frames()
 else:await click(at);await frames()
 expect(view.picker.ready() and view.local.target.get("stack_id",-1)==stack_id,label+"实际点击选中文的能力")
 view.confirm_declaration();await frames()
 expect(session.commands.size()==1 and session.commands[0].name=="commit_extension",label+"发送警醒阵启动请求")
 if session.commands.is_empty():return
 expect(Session.Gateway.apply(authority,seat,session.commands[0]).is_empty(),label+"房主接受警醒阵反制请求")
 authority.pass_priority(authority.priority);authority.pass_priority(authority.priority)
 expect(authority.stack.is_empty() and target.zone=="field" and barrier.zone=="grave",label+"真实结算反制回手")

func run():
 Store.Paths.root_override=ProjectSettings.globalize_path("res://work/watch-counter-ui/"+str(Time.get_ticks_usec()))
 root.content_scale_size=Vector2i(1600,900);root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS;root.content_scale_aspect=Window.CONTENT_SCALE_ASPECT_EXPAND;root.size=Vector2i(1600,900)
 app=load("res://main.tscn").instantiate();app.settings_path="res://work/watch-counter-ui/settings.json";root.add_child(app);await frames();app.load_legacy_test_decks()
 for android in [false,true]:
  for seat in [0,1]:await check_client(android,seat)
 app.queue_free();session.queue_free();await frames()
 print("WATCH COUNTER UI: %d checks; %d failures" % [checks,failures.size()])
 quit(0 if failures.is_empty() else 1)
