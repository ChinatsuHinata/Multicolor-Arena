extends "res://tests/support/ui_base.gd"
const SeatView=preload("res://net/seat_projection.gd")
const Observer=preload("res://net/observer_projection.gd")
const Remote=preload("res://net/remote_duel.gd")

func run():
 Store.Paths.root_override=ProjectSettings.globalize_path("res://work/tokamak-ui/"+str(Time.get_ticks_usec()))
 app=load("res://main.tscn").instantiate();root.add_child(app);await process_frame
 app.load_test_decks();app.begin_battle(true);view=app.duel_view;view.set_process(false);e=view.engine
 app.set_show_card_inspection(true);clean()
 var first=put("162","deck");put("164","deck");var second=put("162","deck");var third=put("162","deck")
 var hand=put("164","hand")
 for i in range(3):put("162","palette")
 view.render()
 expect(view.deck_cast_tiles.is_empty(),"no Tokamak shortcut without Utsuho on its owner's field")
 var enemy=put("78","field",1);view.render()
 expect(view.deck_cast_tiles.is_empty(),"opposing Utsuho does not satisfy the character restriction")
 var utsuho=put("78","field")
 var order=e.players[0].deck.map(func(c):return c.uid)
 for top_down in [false,true]:
  view.table.set_top_down_view(top_down);view.render();await settle()
  expect(view.deck_cast_tiles.size()==3,"each playable deck copy is shown in "+str(top_down))
  expect(view.hand_zones[0]=="hand" and view.hand_nodes.has(hand.uid),"deck shortcuts keep the ordinary hand visible")
  var tile=view.deck_cast_tiles[first.uid]
  expect(tile.position.x>pile_point("deck").x and tile.visible,"shortcut is on the right of the deck")
  expect(view.deck_cast_tiles[second.uid].position.y>tile.position.y,"copies have separate clickable positions")
  expect(e.players[0].deck.map(func(c):return c.uid)==order,"showing shortcuts preserves library order")
  await click(tile.get_global_rect().position+Vector2(31,14),MOUSE_BUTTON_RIGHT)
  expect(view.inspect_uid==first.uid,"right click inspects the exact deck copy")
  await click(view.deck_cast_tiles[first.uid].get_global_rect().position+Vector2(31,14))
  expect(view.local.get("uid",0)==first.uid and not e.players[0].deck.is_empty(),"left click begins casting without moving the card or paying")
  view.right_cancel();await settle()
  var before=view.deck_cast_tiles[first.uid].position
  view.table.camera_offset.x+=0.5;view.table.set_camera();view.update_badge_positions()
  expect(view.deck_cast_tiles[first.uid].position!=before,"shortcuts follow camera movement")
  view.reset_camera_view();await settle();await capture("tokamak-"+str(top_down))
 e.players[0].palette[0].tapped=true;view.render()
 expect(view.deck_cast_tiles.is_empty(),"insufficient colors remove unavailable shortcuts")
 e.players[0].palette[0].tapped=false;e.phase="end";view.render()
 expect(view.deck_cast_tiles.is_empty(),"non-fast Tokamak is hidden outside its legal timing")
 e.phase="main";e.move_to(utsuho,"grave");e.triggers.clear();e.presentation_events.clear();view.render()
 expect(view.deck_cast_tiles.is_empty(),"Utsuho leaving the field removes the shortcuts")
 utsuho=put("character-fdn-042","field");view.render()
 expect(view.deck_cast_tiles.size()==3,"the other Utsuho printing also enables Tokamak")
 view.debug_mode=true;e.active=1;e.priority=1
 for i in range(3):put("162","palette",1)
 var opposing=put("162","deck",1);view.render()
 expect(view.deck_cast_tiles.size()==1 and view.deck_cast_tiles.has(opposing.uid),"manual test mode shows the acting player's deck shortcut")
 view.debug_mode=false;e.active=0;e.priority=0
 e.stack.append({"kind":"ability","id":999,"owner":0,"source":utsuho,"name":"测试","effect":"none","target":{}});view.render()
 expect(view.deck_cast_tiles.is_empty(),"a nonempty stack hides Tokamak during the main phase")
 e.stack.clear();e.active=1;view.render()
 expect(view.deck_cast_tiles.is_empty(),"opponent's main phase hides our Tokamak even with our priority")
 e.active=0;e.pending={"kind":"test","owner":1};view.render()
 expect(view.deck_cast_tiles.is_empty(),"a pending choice hides Tokamak")
 e.pending={}
 for seat in [0,1]:
  e.active=seat;e.priority=seat
  var remote=Remote.new();remote.seat=seat;remote.apply_snapshot(SeatView.build(e,seat))
  view.engine=remote;view.table.duel=remote;view.local_seat=seat;view.table.local_seat=seat;view.debug_mode=true
  view.render();await process_frame
  var expected=[first.uid,second.uid,third.uid] if seat==0 else [opposing.uid]
  expect(view.deck_cast_tiles.keys()==expected,"network seat sees its usable copies through the authority lookup: "+str(seat))
  expect(remote.players[seat].deck.all(func(c):return c.get("network_hidden",false)),"network shortcuts do not disclose deck order")
 var observer=Remote.new();observer.apply_snapshot(Observer.build(e));view.engine=observer;view.table.duel=observer;view.debug_mode=false;view.render()
 expect(view.deck_cast_tiles.is_empty(),"spectators do not see private deck shortcuts")
 view.engine=e;view.table.duel=e;view.local_seat=0;view.table.local_seat=0;e.active=0;e.priority=0;view.render()
 await settle();await click(view.deck_cast_tiles[first.uid].get_global_rect().position+Vector2(31,14))
 var rng_before=e.rng.state
 view.choose_target({"player":1});view.start_payment();view.commit_local()
 expect(first.zone=="stack" and e.players[0].palette.all(func(c):return c.tapped),"shortcut casting follows target selection and real color payment")
 expect(e.rng.state!=rng_before and e.log.back().contains("洗牌"),"casting through the deck shortcut shuffles the remaining library")
 expect(not view.deck_cast_tiles.has(first.uid) or not view.deck_cast_tiles[first.uid].visible,"casting hides the used deck shortcut")
 resolve()
 expect(e.players[1].life==17 and first.zone=="grave","Tokamak resolves normally for three damage")
 print("TOKAMAK_UI: ",checks," checks; ",failures.size()," failures")
 quit(0 if failures.is_empty() else 1)
