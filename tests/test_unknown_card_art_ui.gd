extends "res://tests/support/ui_base.gd"
const UnknownArt=preload("res://scripts/unknown_card_art.gd")
func hover(at: Vector2):
 var event=InputEventMouseMotion.new();event.position=at;event.global_position=at
 root.push_input(event,true);await process_frame;await physics_frame
func run():
 Store.Paths.root_override=ProjectSettings.globalize_path("res://work/unknown-art-ui/"+str(Time.get_ticks_usec()))
 app=load("res://main.tscn").instantiate();root.add_child(app);await process_frame
 app.load_test_decks();app.begin_battle(true);view=app.duel_view;view.set_process(false);e=view.engine
 app.set_show_card_inspection(true);clean()
 var aya=put("18","field");aya.entered_turns=0
 var foe=put("53","field",1);foe.entered_turns=0
 var ufo=put("token-fdf-131","field");ufo.entered_turns=0
 var spell=put("spell-fdf-071","hand")
 var nightmare=put("spell-fdf-072","hand")
 for i in range(5):put("164","deck")
 for c in [aya,foe,ufo]:
  e.Cat.Spells.resolve(e,{"owner":0,"card":nightmare,"target":{"uid":c.uid,"epoch":c.epoch,"mode":"名称改为不明物体并抓牌"}})
 e.presentation_events.clear()
 for top_down in [false,true]:
  view.table.set_top_down_view(top_down);view.render();await settle()
  await hover(Vector2(1300,620))
  var original=view.card_texture(aya)
  var face=view.table.visuals["card_"+str(aya.uid)].get_node("Face")
  var noise=face.get_node("UnknownNoise")
  expect(noise.visible and face.material_override.albedo_texture==original,"renamed unit retains its original texture under noise in "+str(top_down))
  expect(view.table.visuals["card_"+str(foe.uid)].get_node("Face/UnknownNoise").visible,"opposing renamed unit also has noise")
  expect(not view.table.visuals["card_"+str(ufo.uid)].get_node("Face/UnknownNoise").visible,"native UFO stays clear")
  expect(view.hand_nodes[spell.uid].tooltip_text.contains("预计伤害：4 点"),"Barrage hand tooltip counts both friendly unknowns")
  view.inspect_card(spell.card_id,spell.uid)
  expect(view.inspection_text.get_parsed_text().begins_with("预计伤害：4 点"),"Barrage inspection displays damage above rules")
  if top_down:await capture("unknown-art-noise")
  await hover(point(aya.uid))
  expect(view.stage_hover_uid==aya.uid and not noise.visible,"real mouse hover restores the original battlefield card")
  view.render();await process_frame
  expect(not noise.visible,"render refresh preserves the hovered clear card")
  if top_down:await capture("unknown-art-hover")
  await hover(point(foe.uid))
  expect(noise.visible and not view.table.visuals["card_"+str(foe.uid)].get_node("Face/UnknownNoise").visible,"moving hover restores the previous noise and clears the next card")
  await hover(Vector2(1300,620))
  view.inspect_card(aya.card_id,aya.uid);await process_frame
  var image=view.inspection.get_child(0).get_child(0)
  expect(image.material is ShaderMaterial,"inspection art also shows Nightmare noise")
  await hover(image.get_global_rect().get_center())
  expect(image.material==null,"inspection hover reveals original art")
  await hover(Vector2(1300,620))
  expect(image.material is ShaderMaterial,"inspection exit restores noise")
 e.move_to(aya,"hand");view.render();await settle()
 expect(view.hand_nodes[aya.uid].art.material==null and aya.card_id=="18","returned unit has its original clear hand art")
 print("UNKNOWN_CARD_ART_UI: ",checks," checks; ",failures.size()," failures")
 quit(0 if failures.is_empty() else 1)
