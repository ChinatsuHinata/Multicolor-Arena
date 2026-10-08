extends "res://tests/support/network_ui_base.gd"
var fixtures=[]

func frames(count: int=4):
 for i in range(count):await process_frame

func show_lobby(session,android: bool):
 app.lan_session=session;app.is_android=android
 app.clear_page("menu")
 app.online();await frames()

func choose_deck(id: String):
 var button=app.screen.find_child("NetworkDeckSelect",true,false)
 expect(button!=null and not button.disabled,"connected player can open deck gallery")
 if button==null or button.disabled:return
 button.pressed.emit();await frames()
 expect(app.deck_picker_open(),"room deck selector opens gallery")
 if app.deck_picker_open():app.deck_picker_ui.choose(id)
 if app.lan_session.busy:
  var ready=find_button(app.screen,"取消准备")
  if ready==null:ready=find_button(app.screen,"准备")
  expect(ready!=null and ready.disabled and app.screen.find_child("NetworkDeckSelect",true,false).disabled,"pending replacement locks ready and further deck changes")
 await frames()

func synchronized() -> bool:
 return authority_session.can_act() and client_session.can_act() and client_session.sequence==authority_session.sequence

func start_game(expected_decks: Array):
 for session in [authority_session,client_session]:
  session.room_action({"name":"ready"})
  expect(await until(synchronized),"ready request is acknowledged")
 expect(authority_session.series.state.status=="choosing","both ready opens first-player choice")
 if authority_session.series.state.status!="choosing":return
 var chooser=authority_session if authority_session.series.state.chooser==0 else client_session
 chooser.room_action({"name":"first","first":true})
 expect(await until(func():return synchronized() and client_session.room.get("status","")=="playing"),"game starts on both clients")
 for seat in range(2):
  var deck=expected_decks[seat]
  var player=authority_session.authority.players[seat]
  var cards=(player.hand+player.deck).map(func(card):return card.card_id)
  var expected=deck.main.duplicate();cards.sort();expected.sort()
  expect(cards==expected and player.leader.card_id==deck.leader,"new game uses selected leader and exact main deck")
 expect(authority_session.series.state.registered==expected_decks,"new match registers the replacement decks")
 for session in [authority_session,client_session]:
  while not session.snapshots.is_empty():session.pop_snapshot()

func run():
 var directory="res://work/network-deck-switch/"+str(Time.get_ticks_usec())
 Store.Paths.root_override=ProjectSettings.globalize_path(directory)
 app=load("res://main.tscn").instantiate();root.add_child(app);await frames()
 for i in range(2):
  var deck=Store.blank("联机换组样本%d" % i);deck.id="network_switch_%d" % i
  deck.rule_set="test";deck.leader="70" if i==0 else "68"
  deck.main=["53","100","53","100","53","100"] if i==0 else ["39","164","39","164","39","164"]
  deck.side=["39"] if i==0 else ["53","100"]
  expect(Store.save_file(deck).is_empty(),"isolated deck fixture is saved")
  fixtures.append(Store.clean_deck(deck))
 authority_session=Session.new();client_session=Session.new()
 root.add_child(authority_session);root.add_child(client_session)
 authority_session.initialize(directory+"/host");client_session.initialize(directory+"/guest")
 expect(authority_session.create_room(1,false,47995,"127.0.0.1","test").is_empty(),"loopback host creates room")
 expect(client_session.join_room("127.0.0.1",47995).is_empty(),"loopback guest joins room")
 expect(await until(func():return not authority_session.applicant.is_empty()),"guest approval arrives")
 authority_session.accept_applicant(true)
 expect(await until(synchronized),"both players synchronize")
 for seat in range(2):
  authority_session.handle_room_action(seat,{"name":"deck","deck":fixtures[seat]})
  expect(await until(synchronized),"original deck registration is synchronized")
 for android in [false,true]:
  for seat in range(2):
   var session=authority_session if seat==0 else client_session
   var replacement=fixtures[1-seat] if not android else fixtures[seat]
   await show_lobby(session,android)
   var lobby=app.screen.get_children().filter(func(child):return child.get_script()==preload("res://net/lan_lobby.gd"))[0]
   expect(app.decks[lobby.deck_index].id==session.room.own_deck.id,"reopening lobby shows its currently registered deck")
   session.room_action({"name":"ready"})
   expect(await until(synchronized),"player prepares with original deck")
   await choose_deck(replacement.id)
   expect(await until(func():return synchronized() and authority_session.series.state.decks[seat]==replacement,2),"gallery selection replaces authoritative deck over socket")
   expect(session.room.own_deck==replacement and not session.room.ready[seat],"replacement updates local room and cancels previous ready")
   var selected_id=app.decks[lobby.deck_index].id
   app.screen.find_child("NetworkDeckSelect",true,false).pressed.emit();await frames()
   app.close_deck_picker();await frames()
   expect(session.room.own_deck==replacement and app.decks[lobby.deck_index].id==selected_id,"canceling gallery preserves the registered replacement")
   await choose_deck(replacement.id)
   expect(await until(synchronized),"selecting the same deck is acknowledged")
   expect(not find_button(app.screen,"准备").disabled and not app.screen.find_child("NetworkDeckSelect",true,false).disabled,"unchanged deck acknowledgment restores lobby controls")
   find_button(app.screen,"选择此卡组").pressed.emit()
   expect(await until(synchronized),"explicit registration remains available")
   expect(not find_button(app.screen,"准备").disabled,"explicit same-deck registration restores ready button")
   # Keep the other player unready until both replacements have been tested.
   if session.room.ready[seat]:
    session.room_action({"name":"unready"});await until(synchronized)
  await start_game(fixtures if android else [fixtures[1],fixtures[0]])
  if android:break
  expect(authority_session.submit({"name":"surrender","args":[]}).is_empty(),"host submits single-game surrender")
  expect(await until(func():return synchronized() and client_session.room.get("status","")=="complete"),"first match completes")
  client_session.room_action({"name":"rematch"})
  expect(await until(func():return synchronized() and client_session.room.get("status","")=="lobby"),"rematch returns both players to deck selection")
  expect(authority_session.series.state.registered==[{},{}],"rematch clears previous registered pool")
 authority_session.leave(false);client_session.leave(false)
 app.lan_session=null;app.queue_free();await frames()
 print("NETWORK DECK SWITCH ",checks," checks; ",failures," failures")
 quit(0 if failures.is_empty() else 1)
