extends "res://tests/support/ui_base.gd"
const Session=preload("res://net/lan_session.gd")
const Series=preload("res://net/series_controller.gd")

class Wire:
 extends "res://net/lan_transport.gd"
 var packets=[]
 func send_to(id: int,message: Dictionary,_heartbeat: bool=false):
  packets.append({"peer":id,"message":message.duplicate(true)})

class FixedRollSeries:
 extends "res://net/series_controller.gd"
 var rolls=[]
 func roll_die() -> int:return rolls.pop_front()

var fixture="res://work/match-preparation-sync/"+str(Time.get_ticks_usec())

func make_session(actor: int,mode: String,deck: Dictionary):
 var session=Session.new();root.add_child(session);session.initialize(fixture+"/"+mode+"-"+str(actor)+"-"+str(Time.get_ticks_usec()))
 session.set_process(false);session.discovery.set_process(false)
 session.transport.close();session.transport.queue_free()
 session.transport=Wire.new();session.add_child(session.transport);session.transport.set_process(false)
 session.cloud_mode=true;session.cloud_ranked=true;session.matchmaking=true;session.match_mode=mode
 session.cloud_token="a".repeat(64);session.cloud_nickname="Player "+str(actor);session.match_deck=Store.clean_deck(deck)
 return session

func deliver(sender,receiver,peer_id: int):
 var packets=sender.transport.packets.duplicate(true);sender.transport.packets.clear()
 for packet in packets:receiver.receive(peer_id,packet.message)

func synchronize(host,guest):
 for i in range(8):
  if host.transport.packets.is_empty() and guest.transport.packets.is_empty():break
  deliver(host,guest,1);deliver(guest,host,22)

func check_choice_ui(session,chooser: int,label: String):
 app.lan_session=session
 for mobile in [false,true]:
  app.is_android=mobile;app.layout_dpi_override=240 if mobile else 0
  root.size=Vector2i(1280,720) if mobile else Vector2i(1600,900)
  app.online();await process_frame
  var stage=label+" / "+("Android" if mobile else "desktop")
  expect((find_button(app.screen,"我方先手")!=null)==(session.seat==chooser),stage+": only the chooser sees first-player actions")
  expect(find_button(app.screen,"准备")==null and find_button(app.screen,"取消准备")==null,stage+": choice view has no stale preparation actions")
  var labels=app.screen.find_children("*","Label",true,false)
  expect(not labels.any(func(node):return node.text=="对手：未准备"),stage+": neither choice view claims the opponent is unready")
  if session.seat!=chooser:expect(labels.any(func(node):return node.text=="等待 %s 选择先后手" % session.room.names[chooser]),stage+": the other player waits for the same chooser")

func run():
 Store.Paths.root_override=ProjectSettings.globalize_path(fixture)
 app=load("res://main.tscn").instantiate()
 app.settings_path=fixture+"/settings.json";app.account_session_path=fixture+"/account.bin";app.tutorial_local_directory=fixture+"/tutorials"
 app.lan_storage_directory=fixture+"/unused-session"
 root.add_child(app);await process_frame
 app.account_name="TEST_ONLY_PREPARATION";app.account_token="a".repeat(64)
 var decks=JSON.parse_string(FileAccess.get_file_as_string("res://data/test_precons.json")).decks
 for mode in ["ranked","casual","exploration"]:
  for chooser in [0,1]:
   var pair_decks=[Series.Exploration.deck(),Series.Exploration.deck()] if mode=="exploration" else decks
   var host=make_session(0,mode,pair_decks[0]);var guest=make_session(1,mode,pair_decks[1])
   var info={"mode":mode,"match_id":"TEST_ONLY_MATCH","room":"ABCDEF123456","format":host.match_format(),"rule_set":host.match_rule_set(),"deck_hashes":pair_decks.map(func(deck):return JSON.stringify(Store.clean_deck(deck)).sha256_text())}
   host.on_match_found(info.merged({"role":"host","seat":1}));guest.on_match_found(info.merged({"role":"guest","seat":2}))
   var fixed=FixedRollSeries.new();fixed.state=host.series.state.duplicate(true);fixed.rolls=[6,1] if chooser==0 else [1,6];host.series=fixed
   # Deliver seat metadata before hello, with no later directory/observer event to refresh the host view.
   host.on_cloud_seats(["Player 0","Player 1","","","","","",""],[1,22,0,0,0,0,0,0])
   guest.on_connect(1);deliver(guest,host,22)
   var label=mode+" / chooser "+str(chooser)
   var initial_stage="choosing" if mode=="exploration" else "sideboarding"
   expect(host.series.state.status==initial_stage and host.room.status==initial_stage,label+": hello immediately updates the host's local room")
   expect(host.room.ready==host.series.state.ready,label+": host readiness reflects automatic deck registration")
   synchronize(host,guest)
   expect(host.can_act() and guest.can_act() and host.room.status==guest.room.status,label+": handshake leaves both players on the same actionable stage")
   if mode!="exploration":
    host.room_action({"name":"ready"});synchronize(host,guest)
    guest.room_action({"name":"ready"});synchronize(host,guest)
   expect(host.room.status=="choosing" and guest.room.status=="choosing" and host.room.chooser==chooser and guest.room.chooser==chooser,label+": both players share the first-player choice")
   await check_choice_ui(host,chooser,label+" / host")
   await check_choice_ui(guest,chooser,label+" / guest")
   var selecting=host if chooser==0 else guest
   selecting.room_action({"name":"first","first":true});synchronize(host,guest)
   expect(host.can_act() and guest.can_act() and host.room.status=="playing" and guest.room.status=="playing" and host.room.game_id==guest.room.game_id,label+": either chooser can start the same battlefield")
   app.clear_page("menu");app.lan_session=null;host.leave(false);guest.leave(false);host.queue_free();guest.queue_free();await process_frame
 app.queue_free();await process_frame
 print("MATCH PREPARATION SYNC: %d checks; %d failures" % [checks,failures.size()])
 quit(0 if failures.is_empty() else 1)
