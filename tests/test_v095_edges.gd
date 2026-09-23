extends "res://tests/test_v092.gd"
func capture(name: String):
 if DisplayServer.get_name()=="headless": return
 view.banner.visible=false
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://work/v095-"+name+".png")
func run():
 var saved=FileAccess.get_file_as_string(Store.SAVE_PATH)
 app=load("res://main.tscn").instantiate(); root.add_child(app); await process_frame
 app.load_legacy_test_decks(); app.begin_battle(true); view=app.duel_view; view.set_process(false); e=view.engine
 clean(true); var sunny=put("1","deck"); var item=put("165","deck")
 view.render(); await settle(); view.browse_zone(0,"deck"); await process_frame
 var original=e.log.duplicate(); var next=e.next_stack
 await drag(top_art().get_global_rect().get_center(),view.project(Vector3(0,0,2)))
 expect(sunny.zone=="field" and e.stack.is_empty() and e.pending.is_empty() and e.triggers.is_empty() and e.next_stack==next,"compact debug sidebar still supports silent move to field")
 expect(e.log.size()==original.size()+1 and e.log.back().begins_with("调试移动：") and view.debug_open,"debug drop records only debug movement and restores sidebar")
 clean(true); var mokou=put("rec_unit_097","grave"); put("165","palette")
 view.render(); view.browse_zone(0,"grave"); await process_frame
 await click(top_art().get_global_rect().get_center())
 expect(view.local.get("uid")==mokou.uid and view.local.get("action")=="extension","debug-mode click without drag still activates a legal card")
 view.cancel_cast(); clean()
 var unknown=put("91","deck"); view.render(); view.browse_zone(0,"deck"); await process_frame
 expect(view.browser_cards.get_child(0).get_meta("display_id")=="back","normal deck sidebar hides all card faces")
 var before=snapshot(); await click(top_art().get_global_rect().get_center())
 expect(view.local.is_empty() and snapshot()==before,"normal hidden deck click does not reveal or cast")
 view.close_debug(); clean()
 # Each candidate zone uses the same image picker; target refs retain the zone.
 for zone in ["deck","grave","exile"]:
  clean(); var c=put("53",zone); var source=put("18","field")
  view.local={"uid":source.uid,"mode":"target","target":{},"plan":[]}
  view.picker.configure([e.Extra.zone_refs(e,zone,0)[0]],"isolated region UI "+zone)
  view.region_picker(); await process_frame
  expect(view.region_tiles.has(c.uid) and view.modal,"image region picker supports "+zone)
  var at=view.region_tiles[c.uid].get_global_rect().get_center()
  await click(at); before=snapshot(); var chosen=view.region_selected.duplicate(true)
  await click(at,MOUSE_BUTTON_RIGHT)
  expect(view.modal and view.region_selected==chosen and snapshot()==before and not view.local.is_empty(),"right inspecting region card preserves selection: "+zone)
  expect(chosen.value.zone==zone,"region selection retains source zone: "+zone)
  view.open_history(); await process_frame
  var pending_local=view.local.duplicate(true)
  await click(Vector2(1200,603)); view._process(10)
  expect(view.history_open and view.local==pending_local and snapshot()==before,"history blocks clicks over an existing choice: "+zone)
  await click(Vector2(900,810),MOUSE_BUTTON_RIGHT)
  expect(not view.history_open and view.modal and view.region_selected==chosen,"closing history restores existing region choice: "+zone)
 # Preview greys only the printed leader ability.
 clean(); var ordinary=put("71","field"); view.render(); await settle(); view.inspect_card("71",ordinary.uid)
 expect(not view.inspection_text.get_meta("leader_enabled") and view.inspection_text.get_parsed_text().contains("牺牲一个单位") and view.inspection_text.get_parsed_text().contains("自机能力："),"inactive leader preview retains both normal and gray leader ability text")
 await capture("inactive-leader-preview")
 ordinary.leader_counters=1; view.render(); await settle()
 expect(view.inspection_text.get_meta("leader_enabled"),"leader counter removes gray formatting")
 await capture("active-leader-preview")
 # Hexes span one fifth of the card per color and don't remain on stack.
 var palette=put("170","palette"); var original_colors=e.cards["170"].colors.duplicate()
 e.cards["170"].colors=["红","蓝","绿","黄","黑"]; view.render(); await settle()
 var group=view.table.visuals["card_"+str(palette.uid)].get_node("ColorHexes")
 expect(group.get_child_count()==5,"five-color palette renders five hexagons")
 var width=view.table.CARD_SIZE.x/5.0
 expect(is_equal_approx(group.get_child(4).position.x-group.get_child(0).position.x,width*4),"five hexagons span complete card width")
 for id in ["91","133","rec_unit_097","soi_unit_086"]:
  var texture=app.texture(id)
  expect(texture.get_width()==1200 and texture.get_height()==1676,"card art normalized: "+id)
 e.cards["170"].colors=original_colors
 var wheel=InputEventMouseButton.new(); wheel.button_index=MOUSE_BUTTON_WHEEL_DOWN; wheel.pressed=true
 var zoom_before=view.table.top_down_camera_size if view.table.top_down_view else view.table.camera_distance
 view.table.pointer(wheel)
 var zoom_after=view.table.top_down_camera_size if view.table.top_down_view else view.table.camera_distance
 expect(zoom_after>zoom_before,"wheel down zooms out from the battlefield")
 wheel.button_index=MOUSE_BUTTON_WHEEL_UP; view.table.pointer(wheel)
 expect(FileAccess.get_file_as_string(Store.SAVE_PATH)==saved,"real saved decks unchanged")
 var report="%d checks; %d failures\n%s" % [checks,failures.size(),"\n".join(failures)]
 FileAccess.open("res://work/v095-edge-tests.txt",FileAccess.WRITE).store_string(report)
 print("V095_EDGES: "+report); quit(0 if failures.is_empty() else 1)
