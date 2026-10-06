extends "res://tests/support/ui_base.gd"
const OUTPUT="res://work/tutorial-node-rename"
var editor

func frames(count: int=6):
 for i in range(count):await process_frame

func name_input():
 return editor.dialog_layer.find_child("RenameTutorialNodeInput",true,false)

func pointer(at: Vector2,down: bool,double: bool=false):
 var event=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.position=at;event.global_position=at;event.pressed=down;event.double_click=double
 root.push_input(event,true);await process_frame

func key(code: Key):
 var event=InputEventKey.new();event.keycode=code;event.pressed=true;root.push_input(event,true);await process_frame
 event=event.duplicate();event.pressed=false;root.push_input(event,true);await frames()

func shot(name: String):
 if DisplayServer.get_name()=="headless":return
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(OUTPUT.path_join(name+".png"))

func run():
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
 Store.Paths.root_override=ProjectSettings.globalize_path(OUTPUT.path_join("fixtures-"+str(Time.get_ticks_usec())))
 root.mode=Window.MODE_WINDOWED;root.size=Vector2i(1600,900);root.content_scale_size=root.size;root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
 app=load("res://main.tscn").instantiate();app.settings_path=OUTPUT.path_join("missing-settings.json");app.account_session_path=OUTPUT.path_join("missing-account.json")
 root.add_child(app);await frames();app.tutorial_editor();await frames();editor=app.screen.get_child(0)
 var original=editor.model.data.duplicate(true);var history=editor.model.undo_stack.size()
 await click(find_button(editor,"重命名节点").get_global_rect().get_center());await frames()
 expect(name_input().text=="step_1" and name_input().has_focus() and name_input().get_selected_text()=="step_1","rename button opens focused field with entire current name selected")
 expect(editor.dialog_layer.get_child(1).get_child(0).size.x<=540,"rename dialog stays compact")
 name_input().text="step_2";await key(KEY_ENTER)
 expect(is_instance_valid(editor.dialog_layer) and not editor.dialog_layer.find_child("RenameTutorialNodeError",true,false).text.is_empty() and editor.model.data==original,"duplicate name shows inline error without changing course")
 name_input().text="";await key(KEY_ENTER)
 expect(editor.model.data==original and editor.model.undo_stack.size()==history,"empty name leaves course and history intact")
 name_input().text="尚未应用";await key(KEY_ESCAPE)
 expect(not is_instance_valid(editor.dialog_layer) and editor.model.data==original,"Escape cancels pending name")
 await click(find_button(editor,"重命名节点").get_global_rect().get_center());await frames()
 await click(find_button(editor.dialog_layer,"确定").get_global_rect().get_center());await frames()
 expect(editor.model.data==original and editor.model.undo_stack.size()==history,"confirming unchanged name creates no checkpoint")
 var at=editor.nodes_list.get_node("Node_step_2").get_global_rect().get_center()
 await pointer(at,true,true);await frames()
 expect(editor.selected_step=="step_2" and name_input().text=="step_2","double click selects and renames an unselected node")
 await create_timer(0.55).timeout
 expect(editor.order_drag_id.is_empty(),"double click never starts a held reorder gesture")
 await pointer(at,false);await frames();await shot("rename-dialog")
 name_input().text=" 战斗练习 ";await key(KEY_ENTER)
 expect(not is_instance_valid(editor.dialog_layer) and editor.selected_step=="战斗练习" and editor.model.data.steps.step_1.next=="战斗练习","Enter applies trimmed name and updates incoming transition")
 expect(editor.nodes_list.get_node("Node_战斗练习").text.begins_with("2. 战斗练习") and editor.nodes_list.get_node("Node_战斗练习").button_pressed,"renamed node retains course position and selection")
 expect(editor.model.undo_stack.size()==history+1,"double-click rename creates exactly one edit")
 editor.search.text="战斗练习";editor.search.text_changed.emit(editor.search.text);await frames()
 await click(find_button(editor,"重命名节点").get_global_rect().get_center());await frames()
 name_input().text="完成任务";await click(find_button(editor.dialog_layer,"确定").get_global_rect().get_center());await frames()
 expect(editor.selected_step=="完成任务" and editor.search.text.is_empty() and editor.nodes_list.get_node_or_null("Node_完成任务")!=null,"button confirmation keeps renamed node visible after old-name filter")
 await click(find_button(editor,"重命名节点").get_global_rect().get_center());await frames();name_input().text="取消修改"
 await click(find_button(editor.dialog_layer,"取消").get_global_rect().get_center());await frames()
 expect(editor.selected_step=="完成任务" and not editor.model.data.steps.has("取消修改"),"cancel button discards pending name")
 var from=editor.nodes_list.get_node("Node_完成任务").get_global_rect().get_center()
 await pointer(from,true);await create_timer(0.55).timeout
 expect(editor.order_drag_id=="完成任务","renamed node still supports long-press reorder")
 await key(KEY_ESCAPE);await pointer(from,false);await frames()
 await shot("renamed-node")
 var saved=editor.model.data.duplicate(true);var path=OUTPUT.path_join("ui-renamed.json")
 expect(editor.model.save_course(path).is_empty(),"UI renamed course saves")
 app.tutorial_editor(path);await frames();editor=app.screen.get_child(0)
 expect(editor.model.data==JSON.parse_string(JSON.stringify(saved)) and editor.nodes_list.get_node_or_null("Node_完成任务")!=null and not editor.model.dirty(),"saved names reopen in node list")
 app.free();await frames()
 print("TUTORIAL NODE RENAME UI: %d checks; %d failures" % [checks,failures.size()])
 quit(0 if failures.is_empty() else 1)
