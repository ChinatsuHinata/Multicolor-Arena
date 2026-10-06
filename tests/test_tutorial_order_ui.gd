extends "res://tests/support/ui_base.gd"
const OUTPUT="res://work/tutorial-order"
var editor

func frames(count: int=6):
 for i in range(count):await process_frame

func node_ids() -> Array:
 return editor.nodes_list.get_children().filter(func(node):return node.has_meta("step_id")).map(func(node):return node.get_meta("step_id"))

func step_button(id: String):
 return editor.nodes_list.get_node("Node_"+id)

func pointer(at: Vector2,down: bool):
 var event=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.position=at;event.global_position=at;event.pressed=down
 root.push_input(event,true)
 await process_frame

func motion(from: Vector2,to: Vector2):
 var event=InputEventMouseMotion.new();event.position=to;event.global_position=to;event.relative=to-from;event.button_mask=MOUSE_BUTTON_MASK_LEFT
 root.push_input(event,true)
 await process_frame

func hold(id: String):
 var at=step_button(id).get_global_rect().get_center()
 await motion(at,at);await pointer(at,true);await create_timer(0.55).timeout
 expect(editor.order_drag_id==id,"holding "+id+" starts order dragging")
 return at

func shot(name: String):
 if DisplayServer.get_name()=="headless":return
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(OUTPUT.path_join(name+".png"))

func run():
 DirAccess.make_dir_recursive_absolute(OUTPUT)
 Store.Paths.root_override=ProjectSettings.globalize_path(OUTPUT.path_join("fixtures-"+str(Time.get_ticks_usec())))
 root.mode=Window.MODE_WINDOWED;root.size=Vector2i(1600,900);root.content_scale_size=root.size;root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
 app=load("res://main.tscn").instantiate();app.settings_path=OUTPUT.path_join("missing-settings.json");app.account_session_path=OUTPUT.path_join("missing-account.json")
 root.add_child(app);await frames();app.tutorial_editor();await frames();editor=app.screen.get_child(0)
 expect(editor.move_up.disabled and not editor.move_down.disabled,"first selected node can only move down")
 expect(find_button(editor,"设为起点")==null,"course start follows the list")
 var initial=editor.model.data.duplicate(true)
 await click(step_button("step_1").get_global_rect().get_center());await frames()
 expect(step_button("step_1").button_pressed and editor.model.data==initial,"clicking the selected node keeps its highlight without editing")
 await click(find_button(editor,"新增节点").get_global_rect().get_center());await frames()
 var added=editor.selected_step
 expect(node_ids()==["step_1",added,"step_2"],"left list follows actual course order after insertion")
 await click(editor.move_up.get_global_rect().get_center());await frames()
 expect(node_ids()==[added,"step_1","step_2"] and editor.model.data.start_step==added and editor.move_up.disabled,"up button moves the selection and updates the start boundary")
 await click(editor.move_down.get_global_rect().get_center());await frames()
 expect(node_ids()==["step_1",added,"step_2"] and editor.selected_step==added,"down button keeps selection on the moved node")
 var from=step_button(added).get_global_rect().get_center();var before=editor.model.data.duplicate(true)
 await pointer(from,true);await motion(from,from+Vector2(0,30));await create_timer(0.55).timeout
 expect(editor.order_drag_id.is_empty() and editor.model.data==before,"movement before the hold threshold cancels dragging")
 await pointer(from+Vector2(0,30),false);await frames()
 from=await hold(added)
 var target=step_button("step_2");var to=target.get_global_rect().get_center()+Vector2(0,target.size.y*0.3)
 await motion(from,to);expect(target.insertion==1,"drag shows insertion below the target")
 expect(editor.order_preview.get_child(0).size.y>=32,"drag preview includes a readable node caption")
 await shot("drag-insertion")
 await pointer(to,false);await frames()
 expect(node_ids()==["step_1","step_2",added] and editor.model.data.steps[added].next=="$complete" and editor.move_down.disabled,"drop below last node updates the list and completion boundary")
 from=await hold(added);target=step_button("step_1");to=target.get_global_rect().get_center()-Vector2(0,target.size.y*0.3)
 await motion(from,to);await pointer(to,false);await frames()
 expect(node_ids()==[added,"step_1","step_2"] and editor.model.data.start_step==added,"selected node can be dragged before the first node")
 before=editor.model.data.duplicate(true);var history=editor.model.undo_stack.size()
 from=await hold(added);to=editor.inspector.get_global_rect().get_center()
 await motion(from,to);await pointer(to,false);await frames()
 expect(editor.model.data==before and editor.model.undo_stack.size()==history,"dropping outside the list cancels without an edit")
 from=await hold(added);to=step_button(added).get_global_rect().get_center()
 await motion(from,to);await pointer(to,false);await frames()
 expect(editor.model.data==before and editor.model.undo_stack.size()==history,"dropping at the current position creates no edit")
 from=await hold(added)
 var escape=InputEventKey.new();escape.keycode=KEY_ESCAPE;escape.pressed=true;root.push_input(escape,true);await frames()
 await pointer(from,false);await frames()
 expect(editor.order_drag_id.is_empty() and editor.model.data==before and editor.model.undo_stack.size()==history,"Escape cancels a held drag without an edit")
 from=await hold(added);editor.notification(Control.NOTIFICATION_WM_WINDOW_FOCUS_OUT);await pointer(from,false);await frames()
 expect(editor.order_drag_id.is_empty() and editor.model.data==before,"losing window focus cancels a held drag")
 editor.search.text=added;editor.search.text_changed.emit(added);await frames()
 await click(editor.move_down.get_global_rect().get_center());await frames()
 expect(node_ids()==[added] and editor.model.ordered_steps()==["step_1",added,"step_2"] and step_button(added).text.begins_with("2."),"filtered moves use full-course positions and numbering")
 editor.search.clear();editor.search.text_changed.emit("");await frames();await shot("tutorial-order")
 var path=OUTPUT.path_join("ui-reordered.json")
 expect(editor.model.save_course(path).is_empty(),"UI reordered course saves")
 app.tutorial_editor(path);await frames();editor=app.screen.get_child(0)
 expect(node_ids()==["step_1",added,"step_2"] and not editor.model.dirty(),"saved UI order reopens cleanly")
 app.tutorial_editor("res://data/tutorial/beginner/t4.json");await frames();editor=app.screen.get_child(0)
 before=editor.model.data.duplicate(true);from=await hold(editor.selected_step)
 var rect=editor.nodes_scroll.get_global_rect();to=Vector2(rect.get_center().x,rect.end.y-6)
 await motion(from,to);await create_timer(0.6).timeout
 expect(editor.nodes_scroll.scroll_vertical>0,"dragging near the bottom scrolls a long course")
 to=editor.inspector.get_global_rect().get_center();await motion(from,to);await pointer(to,false);await frames()
 expect(editor.model.data==before,"auto scrolling alone never changes tutorial order")
 editor.nodes_scroll.scroll_vertical=0;await frames();await shot("long-course")
 app.free();await frames()
 print("TUTORIAL ORDER UI: %d checks; %d failures" % [checks,failures.size()])
 quit(0 if failures.is_empty() else 1)
