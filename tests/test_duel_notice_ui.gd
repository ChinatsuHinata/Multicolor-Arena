extends "res://tests/support/ui_base.gd"

func run():
 Store.Paths.root_override=ProjectSettings.globalize_path("res://work/duel-notice-ui/"+str(Time.get_ticks_usec()))
 app=load("res://main.tscn").instantiate();root.add_child(app);await process_frame
 app.load_test_decks();app.begin_battle(true);view=app.duel_view;view.set_process(false);e=view.engine
 clean()
 var leader=e.players[0].leader
 leader.timer=1
 var hand_card=put("53","hand")
 view.render();await settle()
 view.leader_zone_clicked(0)
 expect(view.message=="自机仍在计时","clicking a timed leader shows the cast warning")
 var notice: Label
 var prompt: Label
 for child in view.hud.get_children():
  if child is Label and child.text==view.message:notice=child
  if child is Label and child.text=="你的行动":prompt=child
 expect(is_instance_valid(notice) and is_instance_valid(prompt),"the notice and action prompt both remain visible")
 if is_instance_valid(notice) and is_instance_valid(prompt):
  var tab_top=view.HAND.position.y-32
  expect(notice.get_rect().end.y<tab_top and prompt.get_rect().end.y<tab_top,"both status lines leave room for hand tabs")
  expect(notice.get_rect().end.y<=prompt.get_rect().position.y,"the notice and action prompt do not overlap")
  expect(not notice.get_global_rect().intersects(view.hand_nodes[hand_card.uid].get_global_rect()),"the notice does not cover the hand card")
 print("DUEL NOTICE UI: ",checks," checks; ",failures.size()," failures")
 quit(0 if failures.is_empty() else 1)
