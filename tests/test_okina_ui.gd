extends "res://tests/support/ui_base.gd"
const SeatView=preload("res://net/seat_projection.gd")
const Remote=preload("res://net/remote_duel.gd")

func run():
 Store.Paths.root_override=ProjectSettings.globalize_path("res://work/okina-ui/"+str(Time.get_ticks_usec()))
 app=load("res://main.tscn").instantiate();root.add_child(app);await process_frame
 app.load_test_decks();app.begin_battle(true);view=app.duel_view;view.set_process(false);e=view.engine
 clean()
 var okina=e.make_card("character-fdn-071",0,"leader",true)
 e.players[0].leader=okina;e.move_to(okina,"field")
 e.presentation_events.clear();view.reveal_player.reset()
 for i in range(3):put("70","palette")
 var top=e.make_card("70",0,"deck");e.players[0].deck.push_front(top)
 view.render()
 expect(is_instance_valid(view.deck_peek_tile) and view.deck_peek_tile.uid==top.uid,"Okina shows the current top card beside the library")
 if is_instance_valid(view.deck_peek_tile):
  expect(view.deck_peek_tile.position.x+view.deck_peek_tile.size.x<pile_point("deck").x and view.deck_peek_tile.visible,"top card appears left of the library")
  var previous_position=view.deck_peek_tile.position
  view.table.camera_offset.x+=0.5;view.table.set_camera();view.update_badge_positions()
  expect(view.deck_peek_tile.position!=previous_position,"top-card preview follows the camera")
  view.reset_camera_view()
  await click(view.deck_peek_tile.get_global_rect().get_center())
  expect(view.local.get("uid",0)==top.uid,"left click starts casting a top-deck self card")
  view.right_cancel()
 var unplayable=e.make_card("99",0,"deck");e.players[0].deck.push_front(unplayable)
 e.phase="end";view.render()
 expect(is_instance_valid(view.deck_peek_tile) and view.deck_peek_tile.uid==unplayable.uid,"top card updates and remains visible outside casting timing")
 if is_instance_valid(view.deck_peek_tile):
  await click(view.deck_peek_tile.get_global_rect().get_center(),MOUSE_BUTTON_RIGHT)
  expect(view.inspect_uid==unplayable.uid,"nonplayable top card can be inspected")
 var packet=SeatView.build(e,0)
 expect(packet.state.players[0].deck[0].card_id=="99" and packet.definitions.has("99"),"network owner receives visible top card and its definition")
 put("164","deck",1)
 packet=SeatView.build(e,0)
 expect(packet.state.players[1].deck[0].card_id=="back","opponent library stays hidden")
 var other_seat_packet=SeatView.build(e,1)
 expect(other_seat_packet.state.players[0].deck[0].card_id=="back" and not other_seat_packet.definitions.has("99"),"Okina's top-card information is private to its owner")
 var remote=Remote.new();remote.seat=0;remote.apply_snapshot(packet)
 view.engine=remote;view.table.duel=remote;view.render()
 expect(is_instance_valid(view.deck_peek_tile) and view.deck_peek_tile.uid==unplayable.uid,"network owner sees a nonplayable top card")
 view.engine=e;view.table.duel=e
 e.move_to(okina,"grave",false);e.triggers.clear();e.presentation_events.clear();view.render()
 expect(not is_instance_valid(view.deck_peek_tile),"top-card preview disappears when Okina leaves")
 put("character-ucs-068","field");view.render()
 expect(is_instance_valid(view.deck_peek_tile) and view.deck_peek_tile.uid==unplayable.uid,"ordinary Okina still permits viewing the library top")
 print("OKINA_UI: ",checks," checks; ",failures.size()," failures")
 quit(0 if failures.is_empty() else 1)
