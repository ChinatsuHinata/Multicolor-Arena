extends "res://tests/support/ui_base.gd"

const CostDisplay=preload("res://scripts/card_cost_display.gd")
const HexCost=preload("res://scripts/cost_hex_display.gd")
const SeatView=preload("res://net/seat_projection.gd")
const Observer=preload("res://net/observer_projection.gd")
const Remote=preload("res://net/remote_duel.gd")
var output="res://work/nue-transformation"

func hex_cost(node: Node):
 if node.get_script()==HexCost:return node
 for child in node.get_children():
  var found=hex_cost(child)
  if found!=null:return found
 return null

func shot(name: String):
 if DisplayServer.get_name()=="headless":return
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(output.path_join(name+".png"))

func cost_symbols():
 for spec in [["token-ucs-098",["蓝","绿"]],["token-fdf-129",["红","蓝","绿"]]]:
  var info=e.cards[spec[0]];var symbols=HexCost.tokens(CostDisplay.for_card(info))
  expect(symbols.size()==1 and symbols[0].number=="0" and symbols[0].colors==spec[1],"printed token has one zero showing all its colors: "+spec[0])
 var bat=e.Cat.token(e,0,"蝙蝠",1,1,1,["红","黑"])
 expect(HexCost.tokens(CostDisplay.for_card(e.cards[bat.card_id]))==[{"colors":["红","黑"],"number":"0"}],"generated bat displays a red-black zero")
 var info=e.cards["53"].duplicate(true);info.cost={}
 expect(HexCost.tokens(CostDisplay.for_card(info))[0].colors==["灰"],"ordinary zero-cost units keep the neutral zero")
 info=e.cards["token-ucs-098"].duplicate(true);info.cost={"蓝":1}
 expect(HexCost.tokens(CostDisplay.for_card(info))==[{"colors":["蓝"],"number":""}],"a token copy with a nonzero printed cost keeps that cost")

func run():
 Store.Paths.root_override=ProjectSettings.globalize_path(output+"/profile-"+str(Time.get_ticks_usec()))
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
 root.size=Vector2i(1280,720);root.gui_embed_subwindows=true
 app=load("res://main.tscn").instantiate();app.tutorial_local_directory=output+"/tutorials";root.add_child(app);await process_frame
 app.load_test_decks();app.begin_battle(true);view=app.duel_view;view.set_process(false);e=view.engine
 app.set_show_card_inspection(true);clean();cost_symbols()
 var unit=put("character-fdn-026","field")
 var frog=e.Cat.token(e,0,"青蛙",4,4,2,["蓝","绿"],["不占战场格"])
 var source=put("character-rei-022","field")
 e.Pack.resolve_trigger(e,{"source":source.duplicate(true),"owner":0,"effect":"shou_shield","target":e.ref_target(unit)})
 e.Cat.unknown(e,unit);e.Cat.unknown(e,frog)
 e.Pack.prevent_next_damage(e,{"player":0})
 e.presentation_events.clear()
 for android in [false,true]:
  app.is_android=android;view.is_android=android;view.android_inspection_allowed=true;app.refresh_ui_metrics();view.render();await process_frame
  var prefix="android" if android else "desktop"
  view.inspect_card(unit.card_id,unit.uid);await process_frame
  var rules=view.inspection_text.get_parsed_text()
  expect(rules.contains("原本信息") and rules.contains("意识之底「古明地觉&古明地恋」") and rules.contains("原本属性：") and rules.contains("防避1，防避1"),prefix+" details show the original name, attributes and abilities")
  expect(rules.contains("本回合防止下一次伤害") and not rules.contains("999999"),prefix+" details distinguish Shou's effect from a ward")
  expect(view.counter_lines(unit)==["本回合防止下一次伤害"],prefix+" battlefield marks do not show removed original wards")
  expect(view.board_counter_text(unit)=="下次防伤",prefix+" battlefield prevention marker stays compact")
  expect(view.player_buffs(0).contains("本回合防止下一次伤害") and view.player_buffs_compact(0).contains("本回合防止下一次伤害"),prefix+" player buffs show independent next-damage prevention")
  view.inspection_text.scroll_to_line(1);await shot(prefix+"-original-unit")
  view.inspect_card(frog.card_id,frog.uid);await process_frame
  var costs=hex_cost(view.inspection)
  expect(costs!=null and costs.symbols==[{"colors":["蓝","绿"],"number":"0"}],prefix+" transformed frog displays a blue-green zero")
  rules=view.inspection_text.get_parsed_text()
  expect(rules.contains("原本属性：4/4/2") and rules.contains("原本能力：不占战场格") and rules.contains("颜色：蓝、绿"),prefix+" frog details show its generated original information")
  await shot(prefix+"-frog-cost")
  expect(view.inspection_text.get_global_rect().end.y<=view.inspection.get_global_rect().end.y+1,prefix+" expanded original information stays inside the scrolling details panel")
 var authority=e
 for snapshot in [SeatView.build(authority,0),SeatView.build(authority,1),Observer.build(authority)]:
  var remote=Remote.new();remote.apply_snapshot(snapshot);view.engine=remote
  var shown=remote.find_card(frog.uid);view.inspect_card(shown.card_id,shown.uid)
  expect(view.inspection_text.get_parsed_text().contains("原本属性：4/4/2"),"seat and spectator details show the generated original frog")
 view.engine=authority
 e.move_to(unit,"hand");view.inspect_card(unit.card_id,unit.uid)
 expect(not view.inspection_text.get_parsed_text().contains("原本信息"),"restored cards stop showing a transformation section")
 print("NUE_TRANSFORMATION_UI: ",checks," checks; ",failures.size()," failures")
 app.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
