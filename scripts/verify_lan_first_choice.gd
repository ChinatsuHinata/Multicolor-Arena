extends SceneTree
const Session=preload("res://net/lan_session.gd")

var checks=0
var failures=[]

func check(ok: bool,title: String):
 checks+=1
 if not ok:failures.append(title);push_error(title)

func until(predicate: Callable,seconds: float=8) -> bool:
 var deadline=Time.get_ticks_msec()+int(seconds*1000)
 while Time.get_ticks_msec()<deadline:
  if predicate.call():return true
  await process_frame
 return false

func find_button(node: Node,title: String) -> Button:
 if node is Button and node.text==title:return node
 for child in node.get_children():
  var found=find_button(child,title)
  if found!=null:return found
 return null

func _init():call_deferred("run")

func run():
 var run_id=str(Time.get_ticks_usec())
 var host=Session.new();var guest=Session.new();root.add_child(host);root.add_child(guest)
 host.initialize("res://work/lan-choice/"+run_id+"-host")
 guest.initialize("res://work/lan-choice/"+run_id+"-guest")
 check(host.create_room(3,false,47988,"127.0.0.1").is_empty(),"host opens BO3 room")
 check(guest.join_room("127.0.0.1",47988).is_empty(),"guest joins")
 check(await until(func():return not host.applicant.is_empty()),"host receives join request")
 host.accept_applicant(true)
 check(await until(func():return host.can_act() and guest.can_act()),"both seats connected")
 var decks=JSON.parse_string(FileAccess.get_file_as_string("res://data/test_precons.json")).decks
 for seat in [0,1]:host.handle_room_action(seat,{"name":"deck","deck":decks[seat]})
 host.room_action({"name":"ready"});guest.room_action({"name":"ready"})
 check(await until(func():return host.series.state.status=="choosing" and guest.room.get("status","")=="choosing"),"dice choice reaches both clients")
 var chooser=int(host.series.state.chooser)
 var roll_before=host.series.state.roll.duplicate(true)
 host.on_disconnect(host.remote_peer);host.transport.drop(host.remote_peer)
 check(await until(func():return host.can_act() and guest.can_act() and guest.room.get("status","")=="choosing",12),"reconnect resumes pending choice")
 check(host.series.state.roll==roll_before and guest.room.roll==roll_before and host.series.state.chooser==chooser,"reconnect keeps dice and chooser")
 var app=load("res://main.tscn").instantiate();root.add_child(app);await process_frame
 app.lan_session=host if chooser==0 else guest
 app.online();await process_frame
 var second=find_button(app.screen,"我方后手")
 check(second!=null and not second.disabled,"dice winner sees second-player button")
 if second!=null:second.pressed.emit()
 check(await until(func():return host.series.state.status=="playing" and guest.room.get("status","")=="playing"),"button choice starts first game")
 check(host.series.state.first==1-chooser and host.authority.first==1-chooser,"chosen second player is applied by authority")
 host.handle_command(1,{"id":"choice-ui-result","room_id":host.room_id,"game_id":host.series.state.game_id,"expected":host.sequence,"command":{"name":"surrender","args":[]}})
 check(await until(func():return host.series.state.status=="between" and guest.room.get("status","")=="between"),"first result reaches both seats")
 host.room_action({"name":"ready"});guest.room_action({"name":"ready"})
 check(await until(func():return host.series.state.status=="choosing" and guest.room.get("status","")=="choosing"),"next-game choice reaches both clients")
 check(host.series.state.chooser==1 and host.series.state.roll_history.size()==1,"previous loser chooses without another roll")
 app.lan_session=guest;app.online();await process_frame
 var first=find_button(app.screen,"我方先手")
 check(first!=null and not first.disabled,"previous loser sees first-player button")
 if first!=null:first.pressed.emit()
 check(await until(func():return host.series.state.round==2 and guest.room.get("status","")=="playing"),"loser button starts second game")
 check(host.series.state.first==1 and host.authority.first==1,"loser choice is applied by authority")
 host.leave(false);guest.leave(false);app.queue_free();host.queue_free();guest.queue_free()
 print("LAN_FIRST_CHOICE: %d checks; %d failures" % [checks,failures.size()])
 quit(0 if failures.is_empty() else 1)
