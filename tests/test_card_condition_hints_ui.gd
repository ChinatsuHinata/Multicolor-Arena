extends "res://tests/support/ui_base.gd"
const SeatView=preload("res://net/seat_projection.gd")
const Observer=preload("res://net/observer_projection.gd")
const Remote=preload("res://net/remote_duel.gd")
func red_frame(node: Control) -> bool:
 return node.get_meta("conditional_frame",false) and node.has_node("ConditionalFramePulse")
func run():
 Store.Paths.root_override=ProjectSettings.globalize_path("res://work/condition-hints-ui/"+str(Time.get_ticks_usec()))
 app=load("res://main.tscn").instantiate();root.add_child(app);await process_frame
 app.load_test_decks();app.begin_battle(true);view=app.duel_view;view.set_process(false);e=view.engine
 app.set_show_card_inspection(true);clean()
 e.debug_enabled=true;e.debug_free_payment=true
 e.players[0].leader=e.make_card("character-fdn-025",0,"leader",true)
 var hatate=put("character-fdf-105","hand");var rain=put("spell-ucs-050","hand")
 var ominous=put("spell-fdn-009","hand");var reimu=put("character-rei-001","hand")
 var mokou=put("character-fdn-004","hand");mokou.leader=true
 var fairy=put("1","hand");var fairy_leader=put("80","hand")
 var moon=put("spell-mar-012","hand");var plain=put("53","hand")
 var anthem=put("spell-lof-006","field");var shrine=put("170","field")
 var murasa=put("character-fdf-100","field")
 put("166","field");put("68","field")
 var victim=put("53","field",1)
 for i in range(8):put("53","grave")
 put("spell-mar-012","grave");put("spell-mar-012","grave")
 for i in range(21):put("164","deck",1)
 for i in range(10):put("164","deck")
 e.players[0].life=10;e.players[0].etb_curse=1
 for i in range(3):put("spell-rei-011","palette")
 for top_down in [false,true]:
  view.table.set_top_down_view(top_down);view.render();await settle()
  expect(view.life_widgets[1].has("curse_warning") and not view.life_widgets[0].has("curse_warning"),"Yukari curse warning sits beside only the affected player's life in "+str(top_down))
  var warning=view.life_widgets[1].curse_warning
  expect(warning.size.x<=28 and warning.tooltip_text.contains("失去 2 点生命"),"curse triangle stays small and explains the lasting life loss")
  expect(warning.get_global_rect().intersects(view.life_widgets[1].button.get_global_rect()),"curse warning stays next to the life total inside its widget")
  for c in [hatate,rain,ominous,reimu,mokou,fairy,fairy_leader]:
   expect(red_frame(view.hand_nodes[c.uid]) and view.hand_nodes[c.uid].tooltip_text.contains("额外条件满足"),"eligible hand card receives a red pulsing border: "+c.card_id+" in "+str(top_down))
  expect(not red_frame(view.hand_nodes[plain.uid]) and view.hand_nodes[plain.uid].get_theme_stylebox("panel").border_color==Color("#359bff"),"ordinary playable hand card retains its blue border")
  var node=view.hand_nodes[hatate.uid];var frame=node.get_theme_stylebox("panel")
  var first_color=frame.border_color
  await create_timer(0.35).timeout
  expect(frame.border_color!=first_color and node.art.modulate==Color.WHITE and frame.border_color.r>frame.border_color.g*1.8,"red border subtly pulses while the card art stays steady")
  view.selection=[hatate.uid];view.render()
  expect(not red_frame(node) and node.get_theme_stylebox("panel").border_color==Color("#ffd65c"),"selected card preserves its gold border")
  view.selection=[];view.render()
  expect(red_frame(node),"unselecting restores the conditional red border")
  expect(not view.table.visuals["card_"+str(murasa.uid)].get_meta("conditional_frame",false),"Murasa stays unmarked with twenty-one opposing library cards")
  e.players[1].deck.pop_back();view.render()
  var unit=view.table.visuals["card_"+str(murasa.uid)]
  expect(unit.get_meta("conditional_frame",false) and unit.get_node("Outline").visible and unit.get_node("Outline").material_override is ShaderMaterial,"Murasa switches to a red shader border at twenty library cards")
  e.players[1].deck.append(e.make_card("164",1,"deck"));view.render()
  expect(not unit.get_meta("conditional_frame",false),"Murasa's border clears when the library grows above the threshold")
  view.inspect_card(moon.card_id,moon.uid)
  expect(view.inspection_text.get_parsed_text().begins_with("预计抽牌：3 张") and view.hand_nodes[moon.uid].tooltip_text.contains("预计抽牌：3 张"),"Shoot the Moon draw count appears in inspection and hand hover")
  var extra=put("spell-mar-012","grave");view.render()
  expect(view.inspection_text.get_parsed_text().begins_with("预计抽牌：4 张") and view.hand_nodes[moon.uid].tooltip_text.contains("预计抽牌：4 张"),"Shoot the Moon draw count updates while the card stays inspected")
  e.players[0].grave.erase(extra);view.render()
  e.players[0].fairy_enter_turn=e.turn;view.render()
  expect(not red_frame(view.hand_nodes[fairy.uid]) and not red_frame(view.hand_nodes[fairy_leader.uid]),"consuming the anthem opportunity clears both fairy hand borders")
  e.players[0].next_fairy_leader=e.turn;view.render()
  expect(not red_frame(view.hand_nodes[fairy.uid]) and red_frame(view.hand_nodes[fairy_leader.uid]),"fairy princess highlights the next fairy leader only")
  e.players[0].next_fairy_leader=-1;e.players[0].fairy_enter_turn=-1;view.render()
  e.move_to(shrine,"grave");e.presentation_events.clear();view.reveal_player.reset();view.render()
  expect(not red_frame(view.hand_nodes[reimu.uid]),"ordinary Reimu's hand border clears without a leader-ability source")
  e.players[0].all_self_turn=e.turn;view.render()
  expect(red_frame(view.hand_nodes[reimu.uid]),"the hair ornament's current-turn grant enables Reimu's hand border")
  e.players[0].all_self_turn=-1;e.move_to(shrine,"field");e.presentation_events.clear();view.reveal_player.reset();view.render()
  if top_down:
   view.inspect_card(moon.card_id,moon.uid);await capture("condition-hints")
 e.players[1].etb_curse=2;view.render()
 expect(view.life_widgets[0].has("curse_warning") and view.life_widgets[0].curse_warning.tooltip_text.contains("4 点生命"),"both cursed players get separate warnings with their own stacked damage")
 e.players[0].etb_curse=0;view.render()
 expect(not view.life_widgets[1].has("curse_warning") and view.life_widgets[0].has("curse_warning"),"removing a curse in a restored state clears only its affected warning")
 var before=JSON.stringify([e.players,e.stack,e.revision]);view.render();await process_frame
 expect(JSON.stringify([e.players,e.stack,e.revision])==before,"warning markers and pulse refreshes never change game state")
 view.browse_zone(0,"hand");await process_frame
 var art=view.browser_cards.get_children().filter(func(row):return row.get_node("PileCard").get_meta("browser_uid",0)==hatate.uid)[0].get_node("PileCard")
 expect(red_frame(art),"public region browser uses the same red conditional border")
 view.close_debug()
 var spec=e.targets_for(moon.card_id,0,moon.uid)[0].duplicate(true);spec.erase("selection");spec.picks=[[]]
 var moon_error=e.commit_cast(0,moon.uid,spec,[])
 expect(moon_error.is_empty(),"UI fixture casts Shoot the Moon to the real stack: "+moon_error)
 if not moon_error.is_empty():quit(1);return
 var moon_stack_id=e.stack.filter(func(entry):return entry.kind=="card" and entry.card.uid==moon.uid)[0].id
 e.presentation_events.clear();view.render();await settle()
 expect(view.stack_panel.tiles[moon_stack_id].tile.tooltip_text.contains("预计抽牌：3 张"),"stack hover includes Shoot the Moon's expected draws")
 for seat in range(2):
  var remote=Remote.new();remote.apply_snapshot(SeatView.build(e,seat));view.engine=remote;view.table.duel=remote;view.local={}
  view.render();await process_frame
  expect(view.life_widgets[0].has("curse_warning") and view.life_widgets[0].curse_warning.tooltip_text.contains("4 点生命"),"network life warning uses the public curse state for seat "+str(seat))
  expect(view.ConditionHints.active(remote,remote.find_card(hatate.uid)) if seat==0 else remote.find_card(hatate.uid).is_empty(),"network condition hints preserve hand privacy for seat "+str(seat))
 var observer=Remote.new();observer.apply_snapshot(Observer.build(e));view.engine=observer;view.table.duel=observer
 view.render();await process_frame
 expect(view.life_widgets[0].has("curse_warning") and view.stack_panel.tiles[moon_stack_id].tile.tooltip_text.contains("预计抽牌：3 张"),"spectator sees the public warning and stack draw preview")
 view.engine=e;view.table.duel=e
 print("CARD_CONDITION_HINTS_UI: ",checks," checks; ",failures.size()," failures")
 quit(0 if failures.is_empty() else 1)
