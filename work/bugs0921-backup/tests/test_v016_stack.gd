extends "res://tests/test_v092.gd"
func capture(name:String):
 if DisplayServer.get_name()=="headless":return
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://work/v016/"+name+".png")
func run():
 var saved=FileAccess.get_file_as_string(Store.SAVE_PATH)
 app=load("res://main.tscn").instantiate();root.add_child(app);await process_frame
 app.load_test_decks();app.begin_battle(true);view=app.duel_view;view.set_process(false);e=view.engine
 clean()
 var units=[]
 for i in range(12):units.append(put("53","field",1))
 var spell=put("96","hand");put("165","palette");put("164","palette")
 view.render();await settle();view.request_cast(spell.uid)
 var enemy=units[0]
 await click(point(enemy.uid));await press("发动");await settle()
 expect(spell.zone=="stack","targeted spell enters independent stack")
 expect(not view.table.descriptors.values().any(func(d):return d.zone=="stack"),"no stack mesh or collider remains above battlefield")
 expect(not view.STAGE.intersects(view.stack_panel.AREA),"stack area lies wholly outside battlefield")
 var stack_rect=view.stack_panel.card_rect(spell.uid)
 expect(stack_rect.size.x>=210 and stack_rect.size.y>=300,"large upright stack artwork")
 expect(units.all(func(c):return not view.target_rect(e.ref_target(c)).intersects(stack_rect)),"twelve opposing units remain unobscured")
 expect(view.stack_target_arrows().size()==1,"stack-to-target arrow remains")
 await click(stack_rect.get_center(),MOUSE_BUTTON_RIGHT)
 expect(view.inspect_id==spell.card_id,"right click opens stack card preview")
 # The crowded right edge must still be selectable during a mandatory trigger.
 var sunny=e.make_card("1",0,"hand");e.enter_field(sunny,0);e.pump_choices();view.render();await settle()
 expect(view.picker_active(),"ETB still asks for battlefield target")
 var trigger=e.stack.back();var corner=units[0]
 view.toggle_observation();expect(view.observing,"observation opens with stack present")
 await click(point(corner.uid),MOUSE_BUTTON_RIGHT)
 expect(view.inspect_uid==corner.uid,"far-right unit is inspectable in observation")
 view.toggle_observation();await click(point(corner.uid))
 expect(view.picker.ready(),"far-right opposing unit can be selected behind prior stack location")
 await capture("crowded-field-stack")
 await press("确定");await settle()
 expect(view.stack_panel.tiles[trigger.id].caption.text.contains("疾行"),"ability caption remains below artwork")
 # Long stacks retain every entry in the scrolling rail without covering buttons.
 for i in range(7):
  var entry=e.stack[0].duplicate(true);entry.id=900+i;e.stack.append(entry)
 view.render();await settle()
 expect(view.stack_panel.tiles.size()==9,"long stack keeps all entries")
 view.stack_panel.scroll.scroll_vertical=99999;await process_frame;await process_frame
 expect(view.stack_panel.scroll.scroll_vertical>0,"long stack can scroll")
 expect(view.stack_panel.entry_rect(e.stack[0].id).has_area(),"oldest entry reachable at rail bottom")
 expect(view.stack_panel.AREA.end.y<676,"stack rail does not cover payment controls")
 expect(FileAccess.get_file_as_string(Store.SAVE_PATH)==saved,"saved decks unchanged")
 print("V016_STACK: ",checks," checks; ",failures," failures")
 quit(0 if failures.is_empty() else 1)
