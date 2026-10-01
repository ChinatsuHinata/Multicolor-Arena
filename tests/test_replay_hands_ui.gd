extends "res://tests/support/ui_base.gd"
const Archive=preload("res://scripts/replay_archive.gd")
const Observer=preload("res://net/observer_projection.gd")
func open_archive(archive,seat: int=0):
 archive.metadata.seat=seat
 app.clear_page("battle")
 var player=preload("res://scripts/replay_player.gd").new();app.screen.add_child(player)
 app.replay_controller=player;player.build(app,archive)
 view=app.duel_view
 await settle()
 return player
func run():
 Store.Paths.root_override=ProjectSettings.globalize_path("res://work/replay-hands-ui/"+str(Time.get_ticks_usec()))
 app=load("res://main.tscn").instantiate();root.add_child(app);await process_frame
 app.setup();app.begin_battle(true);view=app.duel_view;e=view.engine
 await settle()
 for i in range(12):e.players[1].hand.append(e.make_card("53",1,"hand"))
 e.revision+=1;view.render()
 var index=view.replay_recording.frames.size()-1
 var hands=e.players.map(func(p):return p.hand.duplicate(true))
 var archive=view.replay_recording
 expect(archive.frame(index).projection.state.players.map(func(p):return p.hand)==hands,"offline recorder captures every card in both hands")
 e.surrender(0);view.render();await process_frame
 for child in app.get_children():
  if child is AcceptDialog:child.queue_free()
 var path=Store.Paths.root().path_join("replay/hands.mreply")
 expect(archive.save(path).has("path"),"offline replay saves")
 var readback=Archive.read(path)
 expect(readback.has("archive"),"offline replay reads")
 var player=await open_archive(readback.archive)
 player.seek(index);view=app.duel_view;await settle()
 expect(player.connection_status()=="回放 · 双方手牌可见","playback reports both hands visible")
 expect(view.hand_nodes.size()==hands[0].size() and view.enemy_nodes.size()==hands[1].size(),"both hand rows include all recorded cards")
 for who in [0,1]:
  var nodes=view.hand_nodes if who==0 else view.enemy_nodes
  expect(nodes.values().all(func(n):return not n.hidden_card and n.art.texture!=null and n.tooltip_text!="对手手牌 · 未公开"),"hand "+str(who)+" shows faces and readable tooltips")
  var c=hands[who][0]
  view.hand_clicked(c.uid)
  expect(view.inspect_id==c.card_id and view.inspect_uid==c.uid and view.selection.is_empty() and view.local.is_empty(),"click reads hand "+str(who)+" without taking actions")
  var right=InputEventMouseButton.new();right.pressed=true;right.button_index=MOUSE_BUTTON_RIGHT
  nodes[c.uid].input_card(right)
  expect(view.inspect_id==c.card_id and view.inspect_uid==c.uid,"right click reads full card details")
  view.close_debug()
  var button=find_button(view.hud,("己方" if who==0 else "对手")+"手牌 "+str(hands[who].size()))
  expect(button!=null and not button.disabled,"hand list button is usable in read only replay")
  button.pressed.emit();await process_frame
  expect(view.browser_cards.get_child_count()==hands[who].size(),"hand browser lists every card")
  expect(view.browser_cards.get_children().map(func(n):return n.get_meta("display_id"))==hands[who].map(func(c):return c.card_id),"hand browser uses real card identities")
  expect(view.browser_cards.get_children().all(func(n):return not n.get_node("PileCard").get_meta("hidden")),"hand browser details are visible")
  expect(view.browser_panel.get_global_rect().end.y<646,"hand browser leaves replay controls available")
 view.close_debug();await capture("replay-both-hands")
 view.browse_zone(1,"deck")
 expect(view.browser_cards.get_children().all(func(n):return n.get_meta("display_id")=="back"),"replay library remains hidden")
 player.seek(0);view=app.duel_view;await settle()
 expect(view.engine.players.map(func(p):return p.hand)==archive.frame(0).projection.state.players.map(func(p):return p.hand),"seeking restores exact hands at that step")
 player=await open_archive(readback.archive,1);player.seek(index);view=app.duel_view;await settle()
 expect(view.hand_nodes.keys()==hands[1].map(func(c):return c.uid) and view.enemy_nodes.keys()==hands[0].map(func(c):return c.uid),"guest perspective keeps owners correct with both hands visible")
 player=await open_archive(readback.archive,-1);player.seek(index);view=app.duel_view;await settle()
 expect(view.enemy_nodes.values().all(func(n):return not n.hidden_card),"spectator replay reveals opponent hand")
 var old=Archive.new();var room=archive.metadata.room
 old.record({"game_id":"old","sequence":1,"room":room,"projection":Observer.build(e,[],0)},0)
 old.finish(room)
 player=await open_archive(old);view=app.duel_view
 expect(view.enemy_nodes.values().all(func(n):return n.hidden_card),"legacy replay preserves unknown card backs")
 view.browse_zone(1,"hand")
 expect(view.browser_cards.get_children().all(func(n):return n.get_meta("display_id")=="back" and n.get_node("PileCard").tooltip_text=="未公开"),"legacy replay does not fabricate card information")
 print("REPLAY HANDS UI: ",checks," checks; ",failures.size()," failures")
 quit(0 if failures.is_empty() else 1)
