extends "res://tests/support/ui_base.gd"
const Art=preload("res://scripts/card_art.gd")
const Seat=preload("res://net/seat_projection.gd")
const Remote=preload("res://net/remote_duel.gd")
func editor_tiles(node: Node) -> Array:
 var result=[]
 for child in node.get_children():
  if child.get_script()==preload("res://scripts/deck_card.gd"):result.append(child)
  else:result.append_array(editor_tiles(child))
 return result
func editor_tile(source: String):
 for child in editor_tiles(app.deck_canvas):
  if child.source_zone==source:return child
 return null
func run():
 Store.Paths.root_override=ProjectSettings.globalize_path("res://work/alternate-art-ui/"+str(Time.get_ticks_usec()))
 root.gui_embed_subwindows=true
 app=load("res://main.tscn").instantiate();root.add_child(app);await process_frame
 app.show_card_inspection=true
 var a=Store.blank("异画界面测试");a.leader="70";a.rule_set="test";a.main=["100","100","character-soi-018","character-soi-018"];a.side=["100"]
 var other=a.duplicate(true);other.id="other_art_deck"
 app.decks=[other];app.draft=a;app.selected="100";app.editor();await process_frame
 app.query=Store.CARDS["100"].name;app.update_library();await process_frame
 var row=app.library_rows["100"].row
 var before=a.main.duplicate()
 await click(row.get_global_rect().get_center(),MOUSE_BUTTON_MIDDLE)
 var dialog=app.get_node_or_null("CardArtPicker")
 expect(dialog!=null and a.main==before,"middle click on library opens the art chooser without adding a card")
 if dialog==null:quit(1);return
 var pick=dialog.find_child("Art_tts_150900",true,false)
 expect(pick!=null,"chooser includes the verified alternate spell face")
 pick.pressed.emit();await process_frame;await process_frame
 expect(a.art_overrides["100"]=="tts_150900" and app.dirty and not other.has("art_overrides"),"selection dirties only this deck")
 var chosen=app.texture("100","tts_150900")
 expect(app.texture("100")==chosen,"library preview uses this deck's selected art")
 var matching=0
 for source in ["main","side"]:
  for tile in editor_tiles(app.deck_canvas):
   if tile.get("source_zone")==source and tile.get("card_id")=="100":
    matching+=1;expect(tile.face_texture==chosen and tile.get_child(0).texture==chosen,"every main and side copy refreshes its face and drag preview")
 expect(matching==3,"all spell copies remain in their original zones")
 for source in ["main","side","leader"]:
  var tile=editor_tile(source)
  await click(tile.get_global_rect().get_center(),MOUSE_BUTTON_MIDDLE)
  dialog=app.get_node_or_null("CardArtPicker")
  expect(dialog!=null,"middle click supports "+source+" zone")
  if source=="leader":
   dialog.find_child("Art_tts_151600",true,false).pressed.emit()
  else:dialog.queue_free()
  await process_frame;await process_frame
 app.open_art_picker("70");await process_frame
 await capture("alternate-art-picker")
 app.get_node("CardArtPicker").queue_free();await process_frame
 expect(a.leader=="70" and a.art_overrides["70"]=="tts_151600","leader art changes without replacing the leader")
 a.art_overrides["character-soi-018"]="tts_150800"
 app.clear_page("battle")
 view=preload("res://scripts/duel_view.gd").new();app.duel_view=view;app.screen.add_child(view);view.begin(app,a,other,0,332);view.set_process(false);e=view.engine
 var unit=(e.players[0].hand+e.players[0].deck).filter(func(c):return c.card_id=="character-soi-018")[0]
 var spell=(e.players[0].hand+e.players[0].deck).filter(func(c):return c.card_id=="100")[0]
 e.move_to(unit,"field");e.move_to(spell,"grave");e.presentation_events.clear();e.pending={};e.phase="main";e.turn=3;e.players[0].mulligan_done=true;e.players[1].mulligan_done=true
 var snap=Seat.build(e,1)
 var remote=Remote.new();remote.seat=1;remote.apply_snapshot(snap)
 view.engine=remote;view.table.duel=remote;view.local_seat=1;view.table.local_seat=1
 view.reveal_player.reset();view.previous_snapshot={};view.table.last_combat={}
 view.render();await process_frame
 var face=view.table.visuals["card_"+str(unit.uid)].get_node("Face")
 expect(face.material_override.albedo_texture==app.texture(unit.card_id,"tts_150800"),"opponent battlefield displays the owner's selected unit art")
 view.inspect_card(unit.card_id,unit.uid)
 expect(view.inspection.get_child(0).get_child(0).texture==app.preview_texture(unit.card_id,"tts_150800"),"opponent unit inspection preserves the selected art")
 view.inspect_card(spell.card_id,spell.uid)
 expect(view.inspection.get_child(0).get_child(0).texture==app.preview_texture(spell.card_id,"tts_150900"),"opponent spell inspection preserves the selected horizontal art")
 expect(view.table.piles["pgrave"].get_node("Top").material_override.albedo_texture==app.texture(spell.card_id,"tts_150900"),"graveyard top face shows the selected spell print")
 var stack_card=remote.find_card(spell.uid).duplicate(true);stack_card.zone="stack"
 remote.stack=[{"id":500,"kind":"card","card":stack_card,"owner":0,"name":Store.CARDS[spell.card_id].name,"target":{},"paid":true}]
 view.render();await process_frame
 expect(view.stack_panel.tiles[500].art.texture==app.preview_texture(spell.card_id,"tts_150900"),"opponent stack displays the selected spell print")
 remote.stack=[];view.render();view.inspect_card(unit.card_id,unit.uid);await capture("alternate-art-opponent")
 expect(app.texture(unit.card_id)!=app.texture(unit.card_id,"tts_150800"),"default and alternate textures remain distinct in the shared cache")
 app.clear_page("editor");app.draft=other;app.selected="100";app.editor();await process_frame
 expect(app.texture("100")!=chosen,"switching decks restores that deck's own art")
 print("ALTERNATE_ART_UI: ",checks," checks; failures=",failures)
 quit(0 if failures.is_empty() else 1)
