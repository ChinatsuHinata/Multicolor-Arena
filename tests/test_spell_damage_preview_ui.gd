extends "res://tests/support/ui_base.gd"

func hover(at: Vector2):
 var event=InputEventMouseMotion.new();event.position=at;event.global_position=at
 root.push_input(event,true);await process_frame;await physics_frame

func live_tooltip(node: Node):
 if node.name=="LiveCardTooltip":return node
 for child in node.get_children(true):
  var found=live_tooltip(child)
  if found:return found
 return null

func run():
 Store.Paths.root_override=ProjectSettings.globalize_path("res://work/spell-damage-ui/"+str(Time.get_ticks_usec()))
 app=load("res://main.tscn").instantiate();root.add_child(app);await process_frame
 app.load_test_decks();app.begin_battle(true);view=app.duel_view;view.set_process(false);e=view.engine
 app.set_show_card_inspection(true)
 clean()
 var noon=put("spell-fdn-029","hand");var royal=put("spell-ucs-041","hand")
 var red=put("165","palette");var green=put("166","palette")
 put("167","palette");put("164","palette");put("168","palette").tapped=true
 var foe=put("50","field",1);foe.plus_counters=20
 put("character-mar-021","field")
 for i in range(8):put("164","deck")
 e.players[0].drawn={str(e.turn):3}
 var enemy=put("spell-ucs-041","grave",1);put("164","deck",1)
 e.players[1].drawn={str(e.turn):1}
 for top_down in [false,true]:
  view.table.set_top_down_view(top_down);view.render();await settle()
  var noon_node=view.hand_nodes[noon.uid];var royal_node=view.hand_nodes[royal.uid]
  await hover(noon_node.get_global_rect().get_center())
  expect(noon_node.tooltip_text.contains("预计伤害：2 点") and noon_node.tooltip_text.contains("模拟支付费用后"),"hand hover shows Noon's simulated paid damage in "+str(top_down))
  await click(noon_node.get_global_rect().get_center(),MOUSE_BUTTON_RIGHT)
  expect(view.inspection.visible and view.inspection_text.get_parsed_text().begins_with("预计伤害：2 点"),"Noon damage appears at the top of the left explanation board in "+str(top_down))
  expect(view.inspection_text.get_parsed_text().contains(e.cards[noon.card_id].rules_text),"Noon preview retains the printed rules")
  view.hand_clicked(noon.uid)
  expect(view.inspect_uid==noon.uid and view.inspection_text.get_parsed_text().begins_with("预计伤害：2 点"),"starting a Noon cast automatically inspects damage after the suggested payment")
  expect(not red.tapped and not green.tapped,"previewing payment does not mutate the palette")
  view.reserve_resource(red.uid)
  expect(view.inspection_text.get_parsed_text().begins_with("预计伤害：3 点") and noon_node.tooltip_text.contains("预计伤害：3 点"),"changing reserved payment refreshes both the left board and hand tooltip")
  view.reserve_resource(red.uid)
  expect(view.inspection_text.get_parsed_text().begins_with("预计伤害：2 点"),"restoring the reservation refreshes Noon's damage")
  view.right_cancel()
  expect(view.inspection_text.get_parsed_text().begins_with("预计伤害：2 点") and noon_node.tooltip_text.contains("模拟支付费用后"),"canceling payment restores the automatically simulated preview")
  await hover(royal_node.get_global_rect().get_center())
  expect(royal_node.tooltip_text.contains("预计伤害：4 点") and royal_node.tooltip_text.contains("含此牌先抓的 1 张"),"Royal Flare hand hover includes its own draw in "+str(top_down))
  await click(royal_node.get_global_rect().get_center(),MOUSE_BUTTON_RIGHT)
  expect(view.inspection_text.get_parsed_text().begins_with("预计伤害：4 点"),"Royal Flare appears in the left explanation board")
  e.players[0].drawn[str(e.turn)]=5;view.render()
  expect(view.inspection_text.get_parsed_text().begins_with("预计伤害：6 点") and royal_node.tooltip_text.contains("预计伤害：6 点"),"additional draws refresh the inspection cache and hand tooltip")
  e.players[0].drawn[str(e.turn)]=3;view.render()
 view.browse_zone(1,"grave");await process_frame
 var enemy_art=view.browser_cards.get_child(0).get_node("PileCard")
 expect(enemy_art.tooltip_text.contains("预计伤害：2 点"),"public pile hover calculates for the opposing controller")
 await click(enemy_art.get_global_rect().get_center(),MOUSE_BUTTON_RIGHT)
 expect(view.inspect_uid==enemy.uid and view.inspection_text.get_parsed_text().begins_with("预计伤害：2 点"),"opponent public card inspection uses the opponent's count")
 view.close_debug()
 view.inspect_card(noon.card_id,noon.uid)
 var plan=[{"uid":red.uid,"color":"红"},{"uid":green.uid,"color":"绿"}]
 expect(e.commit_cast(0,noon.uid,e.ref_target(foe),plan).is_empty(),"UI fixture commits Noon to the real stack")
 e.presentation_events.clear();view.render();await settle()
 for top_down in [false,true]:
  view.table.set_top_down_view(top_down);view.render();await settle()
  var stack_tile=view.stack_panel.tiles[e.stack.back().id].tile
  await hover(stack_tile.get_global_rect().get_center())
  await create_timer(0.7).timeout
  var popup=live_tooltip(root)
  expect(popup!=null and popup.text.contains("预计伤害：2 点"),"visible stack tooltip opens with the current damage")
  expect(stack_tile.tooltip_text.contains("预计伤害：2 点"),"stack hover shows paid Noon damage in "+str(top_down))
  red.tapped=false;view.render()
  await process_frame;await process_frame
  expect(is_instance_valid(popup) and popup.text.contains("预计伤害：3 点"),"visible tooltip updates while the mouse stays still")
  expect(stack_tile.tooltip_text.contains("预计伤害：3 点") and view.inspection_text.get_parsed_text().begins_with("预计伤害：3 点"),"stationary stack hover and left board refresh when a palette card untaps")
  green.tapped=false;view.render()
  await process_frame;await process_frame
  if top_down:await capture("spell-damage-preview")
  red.tapped=true;green.tapped=true;view.render()
 view.inspect_card(royal.card_id,royal.uid)
 e.players[0].deck=[];view.render()
 expect(view.inspection_text.get_parsed_text().begins_with("预计伤害：3 点") and view.inspection_text.get_parsed_text().contains("无法抓牌"),"empty-library preview refreshes without counting an impossible draw")
 view.inspect_card("back",royal.uid)
 expect(not view.inspection_text.get_parsed_text().contains("预计伤害"),"hidden inspection cannot leak the calculated card identity")
 clean()
 var orbs=put("spell-rei-011","hand");var lake=put("126","hand")
 var unknown=put("139","hand");var heaven=put("spell-fdf-086","hand")
 var cherry=put("spell-fdf-048","hand");var fuel=put("53","hand")
 put("53","hand",1);put("54","hand",1)
 put("character-fdf-ex04","field");put("48","field");put("spell-fdn-010","field");put("token-fdf-129","field")
 foe=put("53","field",1);foe.plus_counters=30
 put("53","grave");put("164","deck");put("164","deck",1)
 put("spell-rei-011","palette").tapped=true;put("spell-ucs-041","palette",1)
 for id in ["165","167","166","164","168"]:
  for i in range(4):put(id,"palette")
 for top_down in [false,true]:
  view.table.set_top_down_view(top_down);view.render();await settle()
  for sample in [{"card":orbs,"damage":4},{"card":unknown,"damage":6},{"card":heaven,"damage":12},{"card":cherry,"damage":11}]:
   var node=view.hand_nodes[sample.card.uid]
   expect(node.tooltip_text.contains("预计伤害：%d 点" % sample.damage),"expanded hand preview calculates "+sample.card.card_id+" in "+str(top_down))
   view.inspect_card(sample.card.card_id,sample.card.uid)
   expect(view.inspection_text.get_parsed_text().begins_with("预计伤害：%d 点" % sample.damage),"expanded inspection preview calculates "+sample.card.card_id+" in "+str(top_down))
  view.inspect_card(lake.card_id,lake.uid)
  expect(view.inspection_text.get_parsed_text().contains("磨牌对手：1 点") and view.inspection_text.get_parsed_text().contains("磨牌自己：2 点"),"Lake inspection displays both milling scenarios")
  if top_down:await capture("lake-damage-preview")
  view.hand_clicked(lake.uid);view.choose_target({"player":0})
  expect(view.inspection_text.get_parsed_text().begins_with("预计伤害：2 点"),"Lake updates after only the milling player is selected")
  view.choose_target(e.ref_target(foe))
  expect(view.inspection_text.get_parsed_text().begins_with("预计伤害：2 点"),"Lake keeps the chosen self-mill estimate after unit selection")
  view.right_cancel()
  view.inspect_card(cherry.card_id,cherry.uid)
  put("53","hand",1);view.render()
  expect(view.inspection_text.get_parsed_text().begins_with("预计伤害：9 点") and view.hand_nodes[cherry.uid].tooltip_text.contains("预计伤害：9 点"),"opposing hand changes refresh Cherry Blossom inspection and hover")
  e.players[1].hand.pop_back();view.render()
  view.hand_clicked(cherry.uid);view.choose_target({"player":1})
  view.picker.select({"kind":"finish_group","value":"下一项（1）"});view.render()
  view.choose_target(e.ref_target(fuel))
  expect(view.inspection_text.get_parsed_text().begins_with("预计伤害：0 点") and view.hand_nodes[cherry.uid].tooltip_text.contains("预计伤害：0 点"),"Cherry Blossom partial hand selection replaces the default all-hands estimate")
  view.right_cancel()
  expect(view.hand_nodes[cherry.uid].tooltip_text.contains("预计伤害：11 点"),"canceling Cherry Blossom restores both default full-hand assumptions")
  if top_down:await capture("cherry-damage-preview")
 print("SPELL_DAMAGE_PREVIEW_UI: ",checks," checks; ",failures.size()," failures")
 quit(0 if failures.is_empty() else 1)
