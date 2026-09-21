extends "res://tests/test_v092.gd"
const Session=preload("res://net/lan_session.gd")
var authority_session
var client_session
func until(predicate: Callable,seconds: float=8) -> bool:
 var deadline=Time.get_ticks_msec()+int(seconds*1000)
 while Time.get_ticks_msec()<deadline:
  if predicate.call():return true
  await process_frame
 return false
func capture(name: String):
 if DisplayServer.get_name()=="headless":return
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://work/v018/"+name+".png")
func run():
 app=load("res://main.tscn").instantiate();root.add_child(app);await process_frame
 authority_session=Session.new();client_session=Session.new();root.add_child(authority_session);root.add_child(client_session)
 authority_session.initialize("res://work/v018/ui-host");client_session.initialize("res://work/v018/ui-guest")
 authority_session.set_display_name("灵梦");client_session.set_display_name("魔理沙")
 app.lan_session=client_session;app.online();await process_frame;await capture("lan-lobby")
 expect(find_button(app.screen,"创建房间")!=null,"LAN menu exposes create room")
 authority_session.create_room(3,false,47972)
 client_session.join_room("127.0.0.1",47972)
 await until(func():return not authority_session.applicant.is_empty());authority_session.accept_applicant(true)
 await until(func():return client_session.can_act())
 await capture("lan-room")
 for seat in [0,1]:
  authority_session.handle_room_action(seat,{"name":"deck","deck":app.decks[seat]})
 authority_session.handle_room_action(authority_session.series.state.chooser,{"name":"first","first":true})
 for seat in [0,1]:authority_session.handle_room_action(seat,{"name":"ready"})
 await until(func():return not client_session.latest_snapshot.is_empty())
 app.return_network_battle();view=app.duel_view
 await until(func():return not view.revealing())
 expect(view.local_seat==1 and view.acting_player()==1,"guest acts as stable seat one")
 expect(view.hand_nodes.size()==4 and view.enemy_nodes.size()==4,"guest sees both hands with correct counts")
 expect(view.hand_nodes.values().all(func(n):return not n.hidden_card) and view.enemy_nodes.values().all(func(n):return n.hidden_card),"guest sees own faces and host backs")
 expect(view.table.zone_position("leader",1).z>0 and view.table.zone_position("leader",0).z<0,"guest battlefield perspective rotated")
 await capture("guest-mulligan")
 await press("保留")
 expect(await until(func():return authority_session.authority.players[1].mulligan_done),"guest UI mulligan reaches authority")
 # Server-side fixture; normal clients have no debug or direct-state command.
 e=authority_session.authority
 for p in e.players:
  for z in ["deck","hand","field","palette","grave","exile"]:p[z]=[]
  p.potato=false;p.mulligan_done=true;p.turns=3
 e.phase="main";e.turn=6;e.active=1;e.priority=1;e.pending={};e.stack=[];e.combat={};e.presentation_events=[]
 var hand=put("5","hand",1);var rb=put("34","palette",1);var gb=put("5","palette",1);var item=put("167","field",1)
 var enemy=put("53","field",0)
 authority_session.sequence+=1;authority_session.publish()
 await until(func():return client_session.view_sequence==authority_session.sequence);await settle()
 var before=snapshot();var seq=authority_session.sequence
 view.request_cast(hand.uid);await process_frame
 expect(view.payment_ready() and view.local.plan.any(func(r):return r.uid==item.uid),"guest recommends tool mana")
 expect(view.table.descriptors["card_"+str(item.uid)].gold,"guest gold recommendation visible")
 view.reserve_resource(item.uid);view.reserve_resource(rb.uid)
 expect(view.payment_ready() and view.local.plan.any(func(r):return r.uid==rb.uid),"guest replaces payment resource locally")
 expect(authority_session.sequence==seq and snapshot()==before,"private payment edits never reach authority")
 view.cancel_cast();expect(snapshot()==before,"guest cancellation is private")
 view.request_cast(hand.uid);view.confirm_declaration()
 expect(await until(func():return hand.zone=="stack"),"guest activation atomically enters shared stack")
 await until(func():return client_session.view_sequence==authority_session.sequence);await settle()
 expect(view.engine.stack.size()==1 and e.stack.size()==1,"guest and host show same stack")
 expect(view.engine.players[1].palette.any(func(c):return c.uid==gb.uid and c.tapped),"selected mana tapped once after commit")
 await capture("guest-stack-payment")
 # Drain priority using actual gateway, not the read-model engine.
 for i in range(2):
  var actor=e.priority;authority_session.handle_command(actor,{"id":"ui-resolve-"+str(i),"room_id":authority_session.room_id,"game_id":authority_session.series.state.game_id,"expected":authority_session.sequence,"command":{"name":"pass_priority","args":[]}})
 await until(func():return client_session.view_sequence==authority_session.sequence);await settle()
 expect(hand.zone=="field" and view.engine.find_card(hand.uid).zone=="field","resolution is consistent on guest")
 view.settings_menu();expect(find_button(view.ui,"返回联机房间")!=null,"battle has lobby return path")
 view.close_overlay()
 expect(view.debug_mode==false and view.engine.debug_move(hand.uid,"grave")!="","network match cannot use debug mutation")
 var old=e.revision;view.engine.damage_target({"player":0},100)
 expect(e.revision==old and e.players[0].life==20,"read model cannot mutate host authority")
 # Refresh replaces any local memory change.
 authority_session.sequence+=1;authority_session.publish();await until(func():return client_session.view_sequence==authority_session.sequence)
 app.online();await process_frame;await capture("lan-in-match-room")
 authority_session.leave(false);client_session.leave(false)
 print("V018 UI ",checks," checks; ",failures," failures")
 quit(0 if failures.is_empty() else 1)
