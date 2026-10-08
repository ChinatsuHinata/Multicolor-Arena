extends Control
## Node management and recording, with private native tutorial surfaces.
const Model=preload("res://scripts/tutorial/authoring_model.gd")
const Runtime=preload("res://scripts/tutorial/runtime.gd")
const Conditions=preload("res://scripts/tutorial/condition_graph.gd")
const Actions=preload("res://scripts/tutorial/ui_actions.gd")
const OrderStep=preload("res://scripts/tutorial/order_step.gd")
const GuideImage=preload("res://scripts/tutorial/guide_image.gd")
const GuideImageGallery=preload("res://scripts/tutorial/guide_image_gallery.gd")
var host
var is_android=false
var tutorial_guide
var model=Model.new()
var selected_step=""
var scene_id=""
var workspace: Control
var toolbar: HBoxContainer
var inspector: PanelContainer
var form: VBoxContainer
var status_label: Label
var nodes_list: VBoxContainer
var nodes_scroll: ScrollContainer
var move_up: Button
var move_down: Button
var order_drag_id=""
var order_pointer=Vector2.ZERO
var order_drop_target=""
var order_drop_before=true
var order_preview: Control
var search: LineEdit
var title_input: LineEdit
var category_input: OptionButton
var dialog_layer: Control
var playtest
var recorder
var record_view
var record_flow
var record_tools: PanelContainer
var record_status: Label
var selected_zone="hand"
var record_mode="function"
var record_config: Dictionary={}
var record_victory: Dictionary={}
var record_failure: Dictionary={}
var record_exact=true
var record_rows: Array=[]
var record_step_ids: Array=[]
var record_anchor=""
var record_loaded=false
var record_has_settings=false
var record_timeline: HBoxContainer
var record_position: OptionButton
var record_ui_state: Dictionary={}
var record_restore: Button
var condition_workspace
var condition_visibility: Array=[]
var editing_initial_board=false
var initial_board_baseline: Dictionary={}

func begin(app,data: Dictionary={},path: String=""):
 host=app;is_android=host.is_android;theme=host.theme
 name="TutorialAuthoringEditor";set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 model.fresh()
 if not data.is_empty():model.data=data.duplicate(true);model.path=path;model.saved_text=JSON.stringify(data)
 selected_step=model.data.start_step
 build_toolbar()
 workspace=PanelContainer.new();workspace.name="AuthoringNodes";add_child(workspace)
 workspace.add_theme_stylebox_override("panel",host.ui_metrics.panel_style())
 var column=VBoxContainer.new();workspace.add_child(column)
 text(column,"教程顺序").add_theme_color_override("font_color",host.GOLD)
 title_input=line(column,model.data.title,func(value):edit(func():model.data.title=value));title_input.name="AuthoringCourseTitle"
 category_input=option(column,["beginner","advanced","leader"],model.data.get("category","beginner"),func(value):edit(func():model.data.category=value),["新手教程","进阶教程","自机教程"])
 search=LineEdit.new();search.name="AuthoringNodeSearch";column.add_child(search);search.placeholder_text="搜索节点 ID 或指引文字"
 search.text_changed.connect(func(_value):rebuild_nodes())
 var order_tools=HBoxContainer.new();column.add_child(order_tools)
 move_up=action(order_tools,"上移",func():move_selected(-1));move_up.name="MoveTutorialStepUp"
 move_down=action(order_tools,"下移",func():move_selected(1));move_down.name="MoveTutorialStepDown"
 text(column,"双击节点重命名；长按拖拽调整顺序。").add_theme_font_size_override("font_size",16)
 nodes_scroll=ScrollContainer.new();nodes_scroll.name="AuthoringOrderScroll";column.add_child(nodes_scroll);nodes_scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;nodes_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
 nodes_list=VBoxContainer.new();nodes_scroll.add_child(nodes_list);nodes_list.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 inspector=PanelContainer.new();inspector.name="AuthoringInspector";add_child(inspector);inspector.add_theme_stylebox_override("panel",host.ui_metrics.panel_style())
 var details=ScrollContainer.new();inspector.add_child(details);details.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
 form=VBoxContainer.new();details.add_child(form);form.size_flags_horizontal=Control.SIZE_EXPAND_FILL;form.add_theme_constant_override("separation",8)
 resized.connect(layout);refresh()

func build_toolbar():
 var panel=PanelContainer.new();panel.name="AuthoringToolbar";add_child(panel);panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE);panel.offset_bottom=54
 panel.add_theme_stylebox_override("panel",host.ui_metrics.panel_style())
 toolbar=HBoxContainer.new();panel.add_child(toolbar)
 action(toolbar,"新建课程",func():guard_discard(func():host.tutorial_editor()))
 action(toolbar,"打开",func():guard_discard(open_file))
 action(toolbar,"保存",save)
 action(toolbar,"录制",open_recording).name="OpenRecording"
 action(toolbar,"试验当前节点",test_course).name="TestCurrentTutorialStep"
 action(toolbar,"返回",func():guard_discard(host.tutorials))
 status_label=Label.new();toolbar.add_child(status_label);status_label.size_flags_horizontal=Control.SIZE_EXPAND_FILL;status_label.clip_text=true
 status_label.add_theme_color_override("font_color",host.GOLD)

func layout():
 if inspector==null:return
 var width=clampf(size.x*0.48,340,660)
 workspace.position=Vector2(12,64);workspace.size=Vector2(maxf(180,size.x-width-36),maxf(100,size.y-76))
 inspector.position=Vector2(size.x-width-12,64);inspector.size=Vector2(width,maxf(100,size.y-76))
 layout_record_tools()

func layout_record_tools():
 if not is_instance_valid(record_tools):return
 var safe=host.ui_metrics.safe.intersection(get_global_rect())
 if not safe.has_area():safe=get_global_rect()
 var width=record_view.side_width()-16 if recorder.adapter.scene_type=="deck" else safe.size.x-16
 var left=safe.position.x+8
 if recorder.adapter.scene_type=="battlefield" and record_view.life_widgets.has(1-record_view.local_seat):
  # Keep the opponent's player badge available for initial-life editing.
  var player_rect=record_view.life_widgets[1-record_view.local_seat].button.get_global_rect()
  left=maxf(left,player_rect.end.x+8);width=safe.end.x-left-8
 record_tools.position=Vector2(left,safe.position.y+4)-global_position
 record_tools.size.x=maxf(260,width)
 record_restore.position=safe.position-global_position+Vector2(safe.size.x-record_restore.size.x-8,4)

func refresh():
 if not model.data.steps.has(selected_step):selected_step=model.data.start_step
 scene_id=model.scene_for(selected_step)
 title_input.text=model.data.title;category_input.select(maxi(0,["beginner","advanced","leader"].find(model.data.get("category","beginner"))))
 rebuild_form();rebuild_nodes();update_status();layout()

func rebuild_nodes():
 var scroll_position=nodes_scroll.scroll_vertical
 host.free_children(nodes_list)
 var query=search.text.strip_edges().to_lower()
 var found=0
 var order=model.ordered_steps()
 move_up.disabled=order.find(selected_step)<=0
 move_down.disabled=order.find(selected_step)>=order.size()-1
 for i in range(order.size()):
  var id=order[i]
  var step=model.data.steps[id]
  if not query.is_empty() and query not in (id+" "+step.guide.text).to_lower():continue
  found+=1
  var caption="%d. %s · %s" % [i+1,id,{"info":"讲解","task":"任务","wait":"等待"}.get(step.type,step.type)]
  caption+="\n"+str(step.guide.text).replace("\n"," ").left(90)
  if step.has("failure"):caption+="\n失败 → "+step.failure
  var button=OrderStep.new();button.editor=self;button.step_id=id;button.text=caption;nodes_list.add_child(button)
  button.pressed.connect(func():
   if button.dragged:return
   button.set_pressed_no_signal(true)
   if selected_step!=id:selected_step=id;refresh())
  button.name="Node_"+id;button.alignment=HORIZONTAL_ALIGNMENT_LEFT;button.custom_minimum_size.y=92;button.clip_text=true
  button.tooltip_text=step.guide.text+"\n双击重命名；长按拖拽调整教程顺序";button.set_meta("step_id",id);button.toggle_mode=true;button.set_pressed_no_signal(id==selected_step)
 if found==0:text(nodes_list,"没有匹配的节点。")
 nodes_scroll.set_deferred("scroll_vertical",scroll_position)

func move_selected(offset: int):
 move_step_to(selected_step,model.ordered_steps().find(selected_step)+offset)

func drop_step(id: String,target: String,before: bool):
 var order=model.ordered_steps();var index=order.find(target)+(0 if before else 1)
 if order.find(id)<index:index-=1
 move_step_to(id,index)

func move_step_to(id: String,index: int):
 var reason=model.move_step(id,index)
 if not reason.is_empty():host.alert(reason,"顺序未调整");return
 selected_step=id;refresh();call_deferred("reveal_selected_step")

func reveal_selected_step():
 var button=nodes_list.get_node_or_null("Node_"+selected_step)
 if button!=null:nodes_scroll.ensure_control_visible(button)

func rename_step_dialog(id: String):
 if not workspace.is_visible_in_tree() or is_instance_valid(dialog_layer) or not model.data.steps.has(id):return
 if selected_step!=id:selected_step=id;refresh()
 var column=modal("重命名节点")
 var panel=column.get_parent();panel.size_flags_horizontal=Control.SIZE_SHRINK_CENTER;panel.size_flags_vertical=Control.SIZE_SHRINK_CENTER
 panel.custom_minimum_size.x=minf(520,size.x-56)
 text(column,"节点名称")
 var input=LineEdit.new();column.add_child(input);input.name="RenameTutorialNodeInput";input.text=id;input.custom_minimum_size.y=36
 var error=text(column,"");error.name="RenameTutorialNodeError";error.add_theme_color_override("font_color",Color(1,0.4,0.4))
 var submit=func():
  var value=input.text.strip_edges();var reason=model.rename_step(id,value)
  if not reason.is_empty():error.text=reason;input.grab_focus();return
  close_dialog();selected_step=value
  var query=search.text.strip_edges().to_lower()
  if not query.is_empty() and query not in (value+" "+model.data.steps[value].guide.text).to_lower():search.clear()
  refresh();call_deferred("reveal_selected_step")
 var buttons=HBoxContainer.new();column.add_child(buttons)
 action(buttons,"确定",submit).name="ConfirmRenameTutorialNode"
 action(buttons,"取消",close_dialog).name="CancelRenameTutorialNode"
 input.text_submitted.connect(func(_value):submit.call())
 input.text_changed.connect(func(_value):error.text="")
 input.gui_input.connect(func(event):
  if event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE:
   input.accept_event();close_dialog())
 input.call_deferred("grab_focus");input.select_all()

func begin_order_drag(id: String):
 if not workspace.is_visible_in_tree() or is_instance_valid(dialog_layer):return
 order_drag_id=id
 var button=nodes_list.get_node("Node_"+id)
 var preview=PanelContainer.new();preview.add_theme_stylebox_override("panel",host.ui_metrics.panel_style());preview.modulate.a=0.85
 preview.custom_minimum_size=Vector2(minf(button.size.x,420),92)
 order_preview=preview;add_child(preview);preview.z_index=300;preview.mouse_filter=Control.MOUSE_FILTER_IGNORE
 var caption=text(preview,button.text);caption.clip_text=true;caption.mouse_filter=Control.MOUSE_FILTER_IGNORE
 caption.autowrap_mode=TextServer.AUTOWRAP_OFF;caption.custom_minimum_size.y=56
 preview.size=preview.custom_minimum_size
 update_order_drag()

func update_order_drag():
 if order_drag_id.is_empty():return
 order_preview.position=get_global_transform().affine_inverse()*order_pointer+Vector2(16,16)
 order_drop_target=""
 var buttons=nodes_list.get_children().filter(func(node):return node.has_meta("step_id"))
 for button in buttons:button.insertion=-1;button.queue_redraw()
 if buttons.is_empty() or not nodes_scroll.get_global_rect().has_point(order_pointer):return
 var target=buttons.back();order_drop_before=false
 for button in buttons:
  var rect=button.get_global_rect()
  if order_pointer.y<rect.end.y:
   target=button;order_drop_before=order_pointer.y<rect.get_center().y;break
 order_drop_target=target.step_id;target.insertion=0 if order_drop_before else 1;target.queue_redraw()

func finish_order_drag(apply: bool):
 var id=order_drag_id;var target=order_drop_target;var before=order_drop_before
 order_drag_id="";order_drop_target="";retire(order_preview);order_preview=null
 for button in nodes_list.get_children():
  if not button.has_meta("step_id"):continue
  button.holding=false;button.insertion=-1;button.set_pressed_no_signal(button.step_id==selected_step);button.queue_redraw()
 if apply and not target.is_empty():drop_step(id,target,before)

func _input(event: InputEvent):
 if event is InputEventMouseMotion or event is InputEventMouseButton:
  order_pointer=get_canvas_transform().affine_inverse()*event.position
 if order_drag_id.is_empty():return
 if event is InputEventMouseMotion:update_order_drag()
 elif event is InputEventMouseButton:
  if event.button_index==MOUSE_BUTTON_LEFT and not event.pressed:
   update_order_drag();finish_order_drag(true)
  elif event.button_index==MOUSE_BUTTON_RIGHT and event.pressed:finish_order_drag(false)
 elif event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE:finish_order_drag(false)
 else:return
 get_viewport().set_input_as_handled()

func _notification(what: int):
 if what==NOTIFICATION_WM_WINDOW_FOCUS_OUT and not order_drag_id.is_empty():finish_order_drag(false)

func rebuild_form():
 host.free_children(form)
 var step=model.data.steps[selected_step]
 text(form,"节点 · "+selected_step).add_theme_color_override("font_color",host.GOLD)
 var row=HBoxContainer.new();form.add_child(row)
 action(row,"新增节点",func():selected_step=model.add_step(selected_step);refresh()).name="AddTutorialNode"
 action(row,"重命名节点",func():rename_step_dialog(selected_step)).name="RenameTutorialNode"
 action(row,"删除节点",func():selected_step=model.remove_step(selected_step);refresh()).disabled=model.data.steps.size()==1
 text(form,"节点类型")
 var kinds=["info","task","wait"] if step.type=="wait" else ["info","task"]
 option(form,kinds,step.type,change_step_type,kinds.map(func(kind):return {"info":"讲解","task":"功能任务","wait":"等待事件"}[kind]))
 var paragraph=TextEdit.new();form.add_child(paragraph);paragraph.custom_minimum_size.y=120;paragraph.wrap_mode=TextEdit.LINE_WRAPPING_BOUNDARY;paragraph.text=step.guide.text
 paragraph.name="AuthoringGuideText";paragraph.text_changed.connect(func():edit(func():step.guide.text=paragraph.text);rebuild_nodes())
 build_guide_image(step)
 text(form,"教程位置 · 第 %d 步 / 共 %d 步" % [model.ordered_steps().find(selected_step)+1,model.data.steps.size()])
 text(form,"教学场景")
 var kind=model.data.scenarios[scene_id].get("type","battlefield")
 option(form,["battlefield","deck","in_game"],kind,change_scene,["对战场景","卡组查看","组卡器"])
 text(form,"场景来源")
 option(form,["$inherit"]+model.data.scenarios.keys(),step.get("scenario","$inherit"),func(value):
  edit(func():
   if value=="$inherit":step.erase("scenario");step.erase("scenario_mode")
   else:step.scenario=value;step.scenario_mode="reset")
  refresh(),["沿用上一步"]+model.data.scenarios.keys())
 if step.has("scenario"):
  option(form,["reset","resume"],step.get("scenario_mode","reset"),func(value):edit(func():step.scenario_mode=value),["从场景起点开始","恢复场景进度"])
 var scene=model.data.scenarios[scene_id]
 text(form,"初始配置 · "+scene_id).add_theme_color_override("font_color",host.GOLD)
 if kind=="battlefield":
  for who in range(2):
   var player=scene.players[who]
   text(form,"%s：%s · 牌库 %d 张" % ["我方" if who==0 else "对方",host.Store.CARDS.get(player.leader.card_id,{}).get("name",player.leader.card_id),player.get("deck_order",[]).size()])
 else:
  text(form,"%s · 主卡组 %d 张 / 副卡组 %d 张" % [host.Store.CARDS.get(scene.deck.leader,{}).get("name",scene.deck.leader),scene.deck.get("main",[]).size(),scene.deck.get("side",[]).size()])
 action(form,"编辑初始自机和卡组",open_initial_scene).name="EditTutorialInitialScene"
 action(form,"修改初始场面",func():open_recording(true)).name="EditTutorialInitialBoard"
 if step.has("task"):
  var task=step.task
  if task.get("timing") in ["answer","mulligan_selection"]:
   text(form,"答题／起手选择任务")
   action(form,"编辑任务条件与选择",func():config_dialog("任务条件与选择",task,func(value):
    var draft=model.data.duplicate(true);draft.steps[selected_step].task=value
    return apply_course_draft(draft)))
  else:
   text(form,"成功："+Conditions.describe(task.success,host.Store.CARDS))
   action(form,"条件编辑器",func():condition_dialog("成功条件",task.success,func(value):edit(func():task.success=value))).name="OpenConditionEditor"
   if task.get("timing")=="action":
    text(form,"所需操作："+Actions.caption(task.action,host.Store.CARDS))
    action(form,"修改所需操作",func():condition_dialog("所需操作",{"type":"ui_action","action":task.action.duplicate(true)},func(value):
     if value.type=="ui_action":edit(func():task.action=value.action)))
   flag(form,"启用失败条件",task.has("failure"),func(enabled):
    edit(func():
     if enabled:task.failure={"type":"life","player":0,"op":"le","value":0} if kind=="battlefield" else {"type":"ui_action","action":{"id":"editor.remove"}};step.failure=selected_step;step.restore_on_failure=true
     else:task.erase("failure");step.erase("failure");step.erase("restore_on_failure"))
    refresh())
   if task.has("failure"):
    text(form,"失败："+Conditions.describe(task.failure,host.Store.CARDS))
    action(form,"修改失败条件",func():condition_dialog("失败条件",task.failure,func(value):edit(func():task.failure=value)))
    text(form,"失败后前往")
    option(form,model.data.steps.keys()+["$complete"],step.get("failure",selected_step),func(value):edit(func():step.failure=value);rebuild_nodes())
    flag(form,"失败时恢复任务起点",step.get("restore_on_failure",true),func(value):edit(func():step.restore_on_failure=value))
  action(form,"编辑任务触发与参数",func():config_dialog("任务触发与参数",task,func(value):
   var draft=model.data.duplicate(true);draft.steps[selected_step].task=value
   return apply_course_draft(draft)))
 if step.type=="wait":
  text(form,"任务触发事件")
  option(form,preload("res://scripts/tutorial/config.gd").EVENTS,step.wait_event,func(value):edit(func():step.wait_event=value))
 if kind=="battlefield":
  var opponent=model.data.scenarios[scene_id].get("opponent",{"strategy":"paused"})
  text(form,"对手触发规则 · %d 条" % opponent.get("rules",[]).size())
  action(form,"编辑条件／触发器",open_opponent_rules).name="EditTutorialTriggers"
 text(form,"在真实场景中操作，录制后为各步骤设置指引和成败条件。")
 action(form,"编辑已有录制" if has_recording(step) else "录制此节点",open_recording).name="EditExistingRecording"
 action(form,"试验当前任务" if step.has("task") else "预览当前节点",test_course).name="PreviewCurrentTutorialStep"
 text(form,"直接从此节点的场景起点开始；返回后保留编辑内容。").add_theme_font_size_override("font_size",16)

func build_guide_image(step: Dictionary):
 text(form,"节点配图")
 var row=HBoxContainer.new();form.add_child(row)
 action(row,"编辑／更换配图" if step.guide.has("image") else "选择节点配图",open_guide_image).name="EditTutorialGuideImage"
 var remove=action(row,"移除全部配图",remove_guide_image);remove.name="RemoveTutorialGuideImage";remove.disabled=not step.guide.has("image")
 if not step.guide.has("image"):
  text(form,"搜索并指定卡图，支持横卡、竖卡、多卡排列和自定义图。").add_theme_font_size_override("font_size",16)
  return
 var configured=GuideImage.normalize(step.guide.image)
 for i in range(configured.items.size()):text(form,"%d. %s" % [i+1,GuideImage.caption(configured.items[i],host.Store.CARDS)]).add_theme_font_size_override("font_size",16)
 var preview=GuideImageGallery.new();form.add_child(preview);preview.name="AuthoringGuideImage"
 preview.configure(self,host);preview.set_data(step.guide.image)
 text(form,"%s · 点击任意配图放大。" % {"row":"横向并排","column":"纵向排列","grid":"网格排列"}.get(configured.layout,configured.layout)).add_theme_font_size_override("font_size",16)

func open_guide_image():
 var target=selected_step
 var column=modal("节点 "+target+" · 编辑配图")
 var fields=preload("res://scripts/tutorial/guide_image_form.gd").new();fields.configure(self,model.data.steps[target].guide.get("image",{}));column.add_child(fields)
 var buttons=HBoxContainer.new();column.add_child(buttons)
 action(buttons,"应用配图",func():
  var candidate=fields.value()
  if not candidate.is_empty():
   var reason=GuideImage.validate(candidate,host.Store.CARDS)
   if not reason.is_empty():fields.show_error(reason);return
  if model.data.steps[target].guide.get("image",{})!=candidate:
   edit(func():
    if candidate.is_empty():model.data.steps[target].guide.erase("image")
    else:model.data.steps[target].guide.image=candidate)
  close_dialog();refresh()).name="ApplyTutorialGuideImages"
 action(buttons,"取消",close_dialog).name="CancelTutorialGuideImages"

func set_guide_image(target: String,file: String) -> String:
 if not model.data.steps.has(target):return "节点不存在。"
 var result=GuideImage.import_file(file)
 if not result.error.is_empty():return result.error
 if model.data.steps[target].guide.get("image",{})==result.data:return ""
 edit(func():model.data.steps[target].guide.image=result.data);refresh()
 return ""

func remove_guide_image():
 var guide=model.data.steps[selected_step].guide
 if not guide.has("image"):return
 edit(func():guide.erase("image"));refresh()

func open_initial_scene():
 var target=scene_id
 var column=modal("场景 "+target+" · 初始自机和卡组")
 var users=model.data.steps.keys().filter(func(id):return model.scene_for(id)==target)
 text(column,"修改此场景的起点，供 %d 个节点使用；沿用或恢复进度的节点继续按课程流程运行。" % users.size())
 var fields=preload("res://scripts/tutorial/initial_scene_form.gd").new()
 fields.configure(self,target);column.add_child(fields);fields.size_flags_vertical=Control.SIZE_EXPAND_FILL
 var buttons=HBoxContainer.new();column.add_child(buttons)
 action(buttons,"应用初始配置",func():
  if fields.scene==model.data.scenarios[target]:close_dialog();return
  var reason=model.check_scene(target,fields.scene)
  if not reason.is_empty():fields.show_error(reason);return
  var draft=model.data.duplicate(true);draft.scenarios[target]=fields.scene.duplicate(true)
  var checked=preload("res://scripts/tutorial/config.gd").new().validate(draft,host.Store.CARDS)
  if not checked.ok:fields.show_error("\n".join(checked.errors));return
  edit(func():model.data=draft);close_dialog();refresh()).name="ApplyTutorialInitialScene"
 action(buttons,"取消",close_dialog).name="CancelTutorialInitialScene"

func change_step_type(kind: String):
 var step=model.data.steps[selected_step]
 if step.type==kind:return
 edit(func():
  step.type=kind;step.erase("sequence");step.erase("wait_event");step.erase("failure");step.erase("restore_on_failure")
  if kind=="info":step.erase("task");step.guide.next_button="manual"
  else:
   step.guide.next_button="hidden"
   var battlefield=model.data.scenarios[scene_id].get("type","battlefield")=="battlefield"
   step.task={"timing":"state_changed" if battlefield else "action","success":{"type":"life","player":1,"op":"le","value":0} if battlefield else {"type":"always"}}
   if kind=="wait":step.task.timing="event";step.wait_event="state_changed" if battlefield else "ui_action_accepted"
   if not battlefield:step.task.action={"id":"editor.inspect"};step.task.allowed_actions=Actions.ALLOWED.duplicate())
 refresh()

func change_scene(kind: String):
 var old_scene=scene_id
 var old_kind=model.data.scenarios[old_scene].get("type","battlefield")
 if kind==old_kind:return
 scene_id=model.new_scene(selected_step,kind)
 var step=model.data.steps[selected_step]
 for edge in ["next","failure"]:
  var target=step.get(edge,"")
  if target!=selected_step and model.data.steps.has(target) and not model.data.steps[target].has("scenario"):
   model.data.steps[target].scenario=old_scene;model.data.steps[target].scenario_mode="reset"
 step.guide.erase("focus");step.guide.erase("targets");step.erase("components");step.erase("camera_view");step.erase("open_zone")
 change_step_type("info");refresh()

func condition_dialog(caption: String,value: Dictionary,callback: Callable,return_to: Callable=Callable()):
 var kind=recorder.adapter.scene_type if recorder!=null else model.data.scenarios[scene_id].get("type","battlefield")
 if kind=="battlefield":open_condition_workspace(caption,value,callback,return_to);return
 var column=modal(caption)
 var scroll=ScrollContainer.new();column.add_child(scroll);scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
 var fields=preload("res://scripts/tutorial/condition_form.gd").new()
 fields.condition=value.duplicate(true);fields.steps=model.data.steps.keys();fields.cards=host.Store.CARDS
 if caption=="所需操作":fields.allowed_types=["ui_action"]
 fields.aliases=recorder.adapter.aliases.keys() if recorder!=null else model.aliases(scene_id)
 fields.scene_type=recorder.adapter.scene_type if recorder!=null else model.data.scenarios[scene_id].get("type","battlefield")
 scroll.add_child(fields);fields.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 action(column,"应用条件",func():
  var check=preload("res://scripts/tutorial/config.gd").new();check.definitions=host.Store.CARDS;check.condition(fields.condition,"condition",model.data.steps)
  if not check.errors.is_empty():host.alert("\n".join(check.errors),"条件未应用");return
  callback.call(fields.condition.duplicate(true));close_dialog()
  if return_to.is_valid():return_to.call()
  else:refresh())

func open_condition_workspace(caption: String,value: Dictionary,callback: Callable,return_to: Callable=Callable(),rule: Dictionary={},draft_scene: Dictionary={}):
 close_dialog()
 if recorder!=null and recorder.replaying:recorder.pause_replay()
 condition_visibility=[]
 for control in [workspace,inspector,get_node("AuthoringToolbar"),record_view,record_tools,record_restore]:
  if is_instance_valid(control):condition_visibility.append([control,control.visible]);control.hide()
 dialog_layer=Control.new();dialog_layer.name="BattleConditionDialog";dialog_layer.z_index=350;dialog_layer.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(dialog_layer)
 dialog_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 condition_workspace=preload("res://scripts/tutorial/condition_workspace.gd").new();dialog_layer.add_child(condition_workspace)
 var reason=condition_workspace.begin(self,caption,value,callback,return_to,rule,draft_scene)
 if not reason.is_empty():close_dialog();host.alert(reason,"条件战场无法打开")

func apply_course_draft(draft: Dictionary) -> bool:
 var check=preload("res://scripts/tutorial/config.gd").new().validate(draft,host.Store.CARDS)
 if not check.ok:host.alert("\n".join(check.errors),"设置未应用");return false
 edit(func():model.data=draft);return true

func config_dialog(caption: String,value: Variant,callback: Callable):
 var column=modal(caption)
 var scroll=ScrollContainer.new();column.add_child(scroll);scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
 var fields=preload("res://scripts/tutorial/config_form.gd").new();fields.value=value.duplicate(true);scroll.add_child(fields)
 action(column,"应用设置",func():
  if callback.call(fields.value.duplicate(true))==false:return
  close_dialog();refresh()).name="ApplyTutorialSettings"
 return fields

func open_opponent_rules(pending: Dictionary={},alias_scene: Dictionary={}):
 var value=pending.duplicate(true) if not pending.is_empty() else model.data.scenarios[scene_id].get("opponent",{"strategy":"paused"}).duplicate(true)
 if not value.has("rules"):value.rules=[]
 if not value.has("auto_response"):value.auto_response=true
 var target=scene_id
 var column=modal("任务场景触发器 · "+target)
 var users=model.data.steps.keys().filter(func(id):return model.scene_for(id)==target)
 text(column,"此场景由 %d 个节点共用；修改响应会作用于这些节点。" % users.size())
 var scroll=ScrollContainer.new();column.add_child(scroll);scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
 var fields=preload("res://scripts/tutorial/trigger_list_form.gd").new();fields.name="TutorialTriggerList";fields.editor=self;fields.value=value;fields.alias_scene=alias_scene.duplicate(true);scroll.add_child(fields)
 var apply_settings=func():
  var draft=model.data.duplicate(true)
  if not fields.alias_scene.is_empty():draft.scenarios[target]=fields.alias_scene.duplicate(true)
  draft.scenarios[target].opponent=fields.value.duplicate(true)
  draft.scenarios[target].opponent.auto_response=fields.value.get("auto_response",true)
  if not apply_course_draft(draft):return false
  close_dialog();refresh();return true
 var buttons=HBoxContainer.new();column.add_child(buttons)
 action(buttons,"应用设置",apply_settings).name="ApplyTutorialSettings"
 action(buttons,"应用并试验当前任务",func():if apply_settings.call():test_course()).name="TestTutorialTriggers"
 action(buttons,"取消",close_dialog).name="CancelTutorialTriggers"

func open_rule_graph(index: int,pending: Dictionary,alias_scene: Dictionary={}):
 var draft=pending.duplicate(true);var scene=alias_scene.duplicate(true);var state={"applied":false}
 if index<0:
  var used={}
  for item in draft.rules:used[item.id]=true
  draft.rules.append({"id":model.unique_id("trigger_",used),"event":"command_accepted","on_action":{"type":"pass_priority","player":0},"when":{"type":"priority","value":1},"action":"pass_priority","max_times":1})
  index=draft.rules.size()-1;draft.strategy="rules"
 var rule=draft.rules[index]
 open_condition_workspace("触发器 · "+rule.id,rule.when,func(value):
  draft.rules[index]=value
  state.applied=true
  scene.clear();scene.merge(condition_workspace.recorder.scene.duplicate(true))
  return true,func():open_opponent_rules(draft if state.applied else pending,scene if state.applied else alias_scene),rule,alias_scene)

func has_recording(step: Dictionary) -> bool:
 return step.has("sequence") or step.get("task",{}).has("sequence") or step.get("task",{}).get("timing")=="action"

func open_recording(setup_only: bool=false):
 close_dialog()
 editing_initial_board=setup_only
 record_step_ids=[];record_anchor=selected_step;record_loaded=false;record_has_settings=false;record_ui_state={}
 var step=model.data.steps[selected_step]
 if not setup_only and step.get("task",{}).get("timing")=="action":
  record_step_ids=model.recording_steps(selected_step)
  record_anchor=record_step_ids[0]
  scene_id=model.scene_for(record_anchor)
 var scene=model.data.scenarios[scene_id]
 var battle=scene.get("type","battlefield")=="battlefield"
 recorder=preload("res://scripts/tutorial/battle_recorder.gd").new() if battle else preload("res://scripts/tutorial/function_recorder.gd").new()
 var reason=recorder.configure(scene,host.Store.CARDS)
 if not reason.is_empty():recorder=null;host.alert(reason,"录制无法打开");return
 workspace.hide();inspector.hide();get_node("AuthoringToolbar").hide()
 if battle:
  record_flow=preload("res://scripts/tutorial/recording_flow.gd").new();record_flow.adapter=recorder.adapter
  add_child(record_flow);record_flow.set_process(false)
  record_view=preload("res://scripts/tutorial/recording_battle.gd").new();record_view.recorder=recorder;record_view.owner_editor=self
  record_view.tutorial_runtime=record_flow;record_view.tutorial_external=true
  add_child(record_view);record_view.begin(host,{},{},0);record_view.debug_mode=true;record_view.response_mode=record_view.ResponseMode.ON;record_view.render()
  recorder.rejected.connect(func(detail):host.alert(detail,"动作未执行"))
 else:
  record_flow=preload("res://scripts/tutorial/recording_ui_flow.gd").new();record_flow.recorder=recorder
  var data={"schema_version":1,"id":"function_recording","title":"功能录制","initial_scenario":"recording","start_step":"record","completion":{"type":"always"},"scenarios":{"recording":scene.duplicate(true)},"steps":{"record":{"type":"task","guide":{"text":"先布置教学卡组，再开始录制。每次操作会生成一个任务节点。","next_button":"hidden"},"task":{"timing":"action","action":{"id":"editor.inspect"},"allowed_actions":Actions.ALLOWED.duplicate(),"success":{"type":"always"}},"next":"$complete"}}}
  reason=record_flow.start(data,host.Store.CARDS)
  if not reason.is_empty():record_flow.free();record_flow=null;recorder=null;workspace.show();inspector.show();get_node("AuthoringToolbar").show();host.alert(reason,"录制无法打开");return
  recorder.adapter=record_flow.adapter
  record_view=preload("res://scripts/tutorial/scene_view.gd").new();add_child(record_view);record_view.begin(host,record_flow);record_flow.set_process(false)
  record_view.set_meta("recording_editor",self)
  var exit=record_view.tutorial_guide.exit_button
  for connection in exit.pressed.get_connections():exit.pressed.disconnect(connection.callable)
  exit.pressed.connect(close_recording);exit.text="返回编辑器"
  record_view.tutorial_guide.reset_button.hide()
  recorder.capture_ui=func():return record_view.editor_host.recording_state()
  recorder.restore_ui=func(state):record_ui_state=state;sync_record_surface()
  recorder.validation_steps=model.data.steps
  recorder.validation_scenarios=model.data.scenarios
 if setup_only:initial_board_baseline=initial_board_tableau()
 if not setup_only and has_recording(step):
  if battle:
   var config=step.get("sequence",step.get("task",{}).get("sequence",{}))
   reason=recorder.load_sequence(config)
  else:
   reason=recorder.load_nodes(record_step_ids.map(func(id):return model.data.steps[id]),func(value):return record_view.editor_host.replay_recorded_action(value))
  if not reason.is_empty():close_recording();host.alert(reason,"已有录制无法还原");return
  record_loaded=true;record_has_settings=true
  record_mode="demo" if step.has("sequence") else "function";record_exact=step.get("task",{}).has("sequence")
  record_victory=step.get("task",{}).get("success",{"type":"always"}).duplicate(true)
  record_failure=step.get("task",{}).get("failure",{}).duplicate(true)
  if not battle:recorder.seek(record_step_ids.find(selected_step))
  sync_record_surface()
 recorder.changed.connect(update_recording)
 build_record_tools();update_recording()

func build_record_tools():
 record_tools=PanelContainer.new();record_tools.name="RecordingTools";add_child(record_tools);record_tools.z_index=250;record_tools.position=Vector2(8,4)
 record_tools.add_theme_stylebox_override("panel",host.ui_metrics.panel_style())
 var column=VBoxContainer.new();record_tools.add_child(column)
 var setup_scroll=ScrollContainer.new();column.add_child(setup_scroll);setup_scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
 var row=HBoxContainer.new();column.add_child(row)
 column.remove_child(row);setup_scroll.add_child(row)
 if not editing_initial_board:
  action(row,"开始录制",begin_recording).name="BeginRecording"
  action(row,"重新布置",func():recorder.reset_setup();sync_record_surface()).name="ResetRecordingSetup"
 if recorder.adapter.scene_type=="battlefield":
  action(row,"我方加卡",func():record_view.open_debug_card_picker(0,selected_zone)).name="RecordingAddOwn"
  action(row,"对方加卡",func():record_view.open_debug_card_picker(1,selected_zone)).name="RecordingAddEnemy"
  option(row,["hand","field","palette","grave"],selected_zone,func(value):selected_zone=value,["加到手牌","加到战场","加到颜色盘","加到墓地"])
  var ready=flag(row,"单位已在场",true,func(value):recorder.ready_units=value);ready.name="RecordingReadyUnits"
  ready.tooltip_text="默认将未单独设置的战场单位视为已过一回合；选中单位按 P 可单独切换。"
 else:action(row,"布置教学卡组",edit_record_deck).name="RecordingSetupDeck"
 if editing_initial_board:action(row,"应用初始场面",apply_initial_board).name="ApplyTutorialInitialBoard"
 else:
  action(row,"撤回动作",func():if recorder.undo():sync_record_surface()).name="UndoRecording"
  action(row,"结束录制",finish_recording).name="FinishRecording"
 action(row,"取消",close_recording).name="CancelRecording"
 action(row,"隐藏布置栏" if editing_initial_board else "隐藏录制栏",func():record_tools.hide();record_restore.show())
 record_restore=action(self,"显示布置栏" if editing_initial_board else "显示录制栏",func():record_tools.show();record_restore.hide());record_restore.name="RecordingShowTools";record_restore.z_index=250;record_restore.hide()
 record_status=Label.new();column.add_child(record_status);record_status.add_theme_color_override("font_color",host.GOLD);record_status.clip_text=true
 if editing_initial_board:layout_record_tools();return
 var navigation_scroll=ScrollContainer.new();column.add_child(navigation_scroll);navigation_scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
 var navigation=HBoxContainer.new();navigation_scroll.add_child(navigation)
 action(navigation,"◀ 上一步",func():seek_recording(recorder.cursor-1)).name="RecordingPrevious"
 action(navigation,"播放",toggle_record_replay).name="RecordingPlay"
 action(navigation,"下一步 ▶",func():seek_recording(recorder.cursor+1)).name="RecordingNext"
 record_position=OptionButton.new();navigation.add_child(record_position);record_position.name="RecordingPosition";record_position.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 record_position.item_selected.connect(seek_recording)
 action(navigation,"从此步重录",resume_recording).name="RecordingResume"
 var scroll=ScrollContainer.new();column.add_child(scroll);scroll.custom_minimum_size.y=64 if is_android else 46;scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
 record_timeline=HBoxContainer.new();scroll.add_child(record_timeline);record_timeline.name="RecordingTimeline"
 record_tools.custom_minimum_size.x=0
 layout_record_tools()

func sync_record_surface():
 if recorder.adapter.scene_type=="battlefield":record_view.sync_tutorial_scenario()
 else:
  # Rebuild the private host to present the restored draft without recording it.
  record_view.rebuild()
  if not record_ui_state.is_empty():record_view.editor_host.restore_recording_state(record_ui_state)
  var exit=record_view.tutorial_guide.exit_button
  for connection in exit.pressed.get_connections():exit.pressed.disconnect(connection.callable)
  exit.pressed.connect(close_recording);exit.text="返回编辑器"
  record_view.tutorial_guide.reset_button.hide()
  if record_loaded:
   record_view.tutorial_guide.set_popup(false);record_view.tutorial_guide.restore_button.hide()

func update_recording():
 if recorder==null or not is_instance_valid(record_status):return
 if editing_initial_board:
  record_status.text="布置节点 · "+selected_step
  if recorder.adapter.scene_type=="battlefield":record_status.text+=" · 选中卡牌按 D 删除 / C 复制；战场单位按 P 切换已过一回合；右键玩家修改初始血量"
  return
 record_status.text=("录制中" if recorder.recording else "播放中" if recorder.replaying else "已有录制" if record_loaded else "已结束" if not recorder.actions.is_empty() else "布置场景")+" · 已完成 %d / %d 步 · 箭头表示既定流程" % [recorder.cursor,recorder.actions.size()]
 if recorder.adapter.scene_type=="battlefield" and recorder.editing_setup():record_status.text+=" · 选中卡牌按 D 删除 / C 复制；战场单位按 P 切换已过一回合；右键玩家修改初始血量"
 record_tools.find_child("BeginRecording",true,false).disabled=recorder.recording or not recorder.actions.is_empty()
 record_tools.find_child("ResetRecordingSetup",true,false).disabled=recorder.points.is_empty()
 for name in ["RecordingAddOwn","RecordingAddEnemy","RecordingReadyUnits","RecordingSetupDeck"]:
  var control=record_tools.find_child(name,true,false)
  if control!=null:control.disabled=recorder.recording or not recorder.actions.is_empty()
 for name in ["UndoRecording","FinishRecording"]:record_tools.find_child(name,true,false).disabled=recorder.actions.is_empty()
 record_tools.find_child("UndoRecording",true,false).disabled=recorder.cursor==0 or recorder.replaying
 record_tools.find_child("RecordingPrevious",true,false).disabled=recorder.points.is_empty() or recorder.cursor==0
 record_tools.find_child("RecordingNext",true,false).disabled=recorder.cursor>=recorder.actions.size()
 record_tools.find_child("RecordingPlay",true,false).disabled=recorder.actions.is_empty()
 record_tools.find_child("RecordingPlay",true,false).text="暂停" if recorder.replaying else "播放"
 record_tools.find_child("RecordingResume",true,false).disabled=recorder.points.is_empty() or recorder.recording or recorder.replaying
 record_position.clear()
 for i in range(recorder.actions.size()+1):record_position.add_item("起点 · 第 1 步前" if i==0 else "第 %d 步后" % i)
 record_position.select(recorder.cursor);record_position.disabled=recorder.points.is_empty()
 rebuild_record_timeline()

func rebuild_record_timeline():
 host.free_children(record_timeline)
 for i in range(recorder.actions.size()+1):
  if i>0:text(record_timeline,"→").add_theme_color_override("font_color",host.GOLD)
  var caption="终点" if i==recorder.actions.size() else str(i+1)+" · "+(preload("res://scripts/tutorial/battle_commands.gd").caption(recorder.adapter,recorder.actions[i]) if recorder.adapter.scene_type=="battlefield" else Actions.caption(recorder.actions[i],host.Store.CARDS))
  var button=action(record_timeline,("▶ " if i==recorder.cursor else "")+caption,func():seek_recording(i));button.name="RecordedStep_"+str(i);button.disabled=i==recorder.cursor;button.tooltip_text=caption+"\n恢复到此步骤开始前的局面；从此步重录将替换后续动作。"
  button.add_theme_color_override("font_disabled_color",host.GOLD)
  button.custom_minimum_size.x=260 if is_android else 220;button.clip_text=true

func seek_recording(index: int):
 if recorder.seek(index) and recorder.adapter.scene_type=="battlefield":sync_record_surface()

func resume_recording():
 if recorder.resume_record() and recorder.adapter.scene_type=="battlefield":sync_record_surface()

func toggle_record_replay():
 if recorder.replaying:recorder.pause_replay();sync_record_surface();return
 var reason=recorder.start_replay()
 if not reason.is_empty():host.alert(reason,"录制无法播放");return
 sync_record_surface()

func edit_record_deck():
 var deck=preload("res://scripts/tutorial/function_recorder.gd").clean_deck(recorder.adapter.ui_deck)
 var flow=Runtime.new()
 var data={"schema_version":1,"id":"recording_setup","title":"布置教学卡组","initial_scenario":"deck","start_step":"edit","completion":{"type":"always"},"scenarios":{"deck":{"type":"in_game","screen":"deck_editor","deck":deck}},"steps":{"edit":{"type":"task","guide":{"text":"布置教学卡组","next_button":"hidden"},"task":{"timing":"action","action":{"id":"editor.add"},"allowed_actions":Actions.ALLOWED.duplicate(),"success":{"type":"deck_count","zone":"main","op":"ge","value":100000}},"next":"$complete"}}}
 var reason=flow.start(data,host.Store.CARDS)
 if not reason.is_empty():flow.free();host.alert(reason,"教学卡组无法打开");return
 flow.set_process(false)
 modal("布置教学卡组 · 应用后作为录制起点")
 var native=preload("res://scripts/tutorial/authoring_deck.gd").new();native.owner_view=self
 dialog_layer.add_child(flow);dialog_layer.add_child(native);native.configure(self,flow)
 native.on_apply=func(value):
  recorder.adapter.ui_deck=preload("res://scripts/tutorial/function_recorder.gd").clean_deck(value)
  close_dialog();sync_record_surface()
 var buttons=HBoxContainer.new();dialog_layer.add_child(buttons);buttons.position=Vector2(16,8)
 action(buttons,"应用教学卡组",func():native.on_apply.call(native.draft))
 action(buttons,"取消",close_dialog)

func begin_recording():
 var reason=recorder.begin_record()
 if not reason.is_empty():host.alert(reason,"录制未开始");return
 if recorder.adapter.scene_type=="battlefield":sync_record_surface()

func finish_recording():
 if recorder==null or recorder.actions.is_empty():return
 recorder.finish()
 var reason=recorder.verify()
 if not reason.is_empty():host.alert(reason,"录制校验未通过");return
 if not record_has_settings:record_rows=[];record_failure={};record_mode="function";record_exact=true
 if recorder.adapter.scene_type=="battlefield":
  record_config=recorder.sequence_config()
  if not record_has_settings:
   var chosen=recorder.victory_candidates().filter(func(item):return item.selected).map(func(item):return item.condition.duplicate(true))
   record_victory=chosen[0] if chosen.size()==1 else {"type":"all","conditions":chosen} if not chosen.is_empty() else {"type":"always"}
 else:record_rows=recorder.nodes.duplicate(true)
 record_has_settings=true
 show_recording_result()

func show_recording_result():
 var column=modal("录制结果 · 设置每步指引和任务成败条件")
 dialog_layer.set_meta("recording_result",true)
 var scroll=ScrollContainer.new();column.add_child(scroll);scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
 var body=VBoxContainer.new();scroll.add_child(body);body.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 if recorder.adapter.scene_type=="battlefield":
  option(body,["function","demo"],record_mode,func(value):record_mode=value;show_recording_result(),["功能指导任务","动作演示"])
  for i in range(record_config.actions.size()):
   var row=HBoxContainer.new();body.add_child(row)
   text(row,("→ " if i>0 else "")+str(i+1)+". "+preload("res://scripts/tutorial/battle_commands.gd").caption(recorder.adapter,record_config.actions[i])).size_flags_horizontal=Control.SIZE_EXPAND_FILL
   action(row,"追溯此步",func():close_dialog();seek_recording(i)).name="TraceRecordedStep_"+str(i)
  if record_mode=="function":
   flag(body,"要求我方按录制顺序操作（对方自动执行）",record_exact,func(value):record_exact=value)
   text(body,"成功："+Conditions.describe(record_victory,host.Store.CARDS))
   action(body,"修改成功条件",func():condition_dialog("成功条件",record_victory,func(value):record_victory=value,show_recording_result))
   flag(body,"启用失败条件",not record_failure.is_empty(),func(value):record_failure={"type":"life","player":0,"op":"le","value":0} if value else {};show_recording_result())
   if not record_failure.is_empty():action(body,"修改失败条件",func():condition_dialog("失败条件",record_failure,func(value):record_failure=value,show_recording_result))
 else:
  for i in range(record_rows.size()):
   var node=record_rows[i]
   text(body,"步骤 %d · " % (i+1)+Actions.caption(node.task.action,host.Store.CARDS)).add_theme_color_override("font_color",host.GOLD)
   var guide=TextEdit.new();body.add_child(guide);guide.custom_minimum_size.y=72;guide.text=node.guide.text;guide.wrap_mode=TextEdit.LINE_WRAPPING_BOUNDARY
   guide.text_changed.connect(func():node.guide.text=guide.text)
   text(body,"成功："+Conditions.describe(node.task.success,host.Store.CARDS))
   action(body,"修改此步成功条件",func():condition_dialog("步骤 %d 成功条件" % (i+1),node.task.success,func(value):node.task.success=value,show_recording_result))
   flag(body,"此步启用失败条件",node.task.has("failure"),func(value):
    if value:node.task.failure={"type":"ui_action","action":{"id":"editor.remove"}};node.restore_on_failure=true
    else:node.task.erase("failure");node.erase("restore_on_failure")
    show_recording_result())
   if node.task.has("failure"):
    text(body,"失败："+Conditions.describe(node.task.failure,host.Store.CARDS))
    action(body,"修改此步失败条件",func():condition_dialog("步骤 %d 失败条件" % (i+1),node.task.failure,func(value):node.task.failure=value,show_recording_result))
   action(body,"删除此录制步骤",func():record_rows.remove_at(i);show_recording_result()).disabled=record_rows.size()==1
 action(column,"应用到节点",apply_recording).name="ApplyRecording"
 action(column,"返回录制场景",func():
  if recorder.adapter.scene_type!="battlefield" and record_rows.size()==recorder.nodes.size():recorder.nodes=record_rows.duplicate(true)
  close_dialog())

func apply_recording():
 if recorder==null or (recorder.adapter.scene_type!="battlefield" and record_rows.is_empty()):return
 var draft=model.data.duplicate(true);var scene=model.unique_id("recorded_scene_",draft.scenarios)
 draft.scenarios[scene]=recorder.scene.duplicate(true)
 var next=draft.steps[record_step_ids.back()].next if not record_step_ids.is_empty() else draft.steps[selected_step].next
 if recorder.adapter.scene_type=="battlefield":
  if record_mode=="function" and record_exact and not record_config.actions.any(func(value):return value.get("player")==0):host.alert("功能指导至少需要一个我方动作。","录制未应用");return
  var node=draft.steps[selected_step]
  var previous_task=node.get("task",{}).duplicate(true);var previous_failure=node.get("failure",selected_step);var previous_restore=node.get("restore_on_failure",true)
  for key in ["sequence","task","wait_event","failure","restore_on_failure"]:node.erase(key)
  node.scenario=scene;node.scenario_mode="reset";node.guide.popup="show"
  if record_mode=="demo":node.type="info";node.guide.next_button="manual";node.sequence=record_config.duplicate(true)
  else:
   node.type="task";node.guide.next_button="hidden"
   node.task=previous_task if record_loaded and record_mode=="function" else {"timing":"state_changed","allow_turn_end":true}
   node.task.success=record_victory.duplicate(true);node.task.erase("sequence");node.task.erase("failure")
   if record_exact:node.task.sequence=record_config.duplicate(true);node.task.sequence.student=0
   else:
    if record_victory.type=="always":host.alert("自由操作任务需要具体的成功条件。","录制未应用");return
    var rules=recorder.response_rules()
    draft.scenarios[scene].opponent={"strategy":"rules","rules":rules} if not rules.is_empty() else {"strategy":"paused"}
   if not record_failure.is_empty():node.task.failure=record_failure.duplicate(true);node.failure=previous_failure;node.restore_on_failure=previous_restore
 else:
  var ids=[record_anchor]
  for i in range(1,record_rows.size()):
   var id=record_step_ids[i] if i<record_step_ids.size() else model.unique_id("step_",draft.steps)
   draft.steps[id]={};ids.append(id)
  for i in range(ids.size()):
   var node=record_rows[i].duplicate(true);node.next=ids[i+1] if i+1<ids.size() else next
   if i==0:node.scenario=scene;node.scenario_mode="reset"
   if node.task.has("failure"):node.failure=node.get("failure",ids[i]);node.restore_on_failure=node.get("restore_on_failure",true)
   draft.steps[ids[i]]=node
  for id in record_step_ids:
   if id in ids:continue
   draft.steps.erase(id)
   for node in draft.steps.values():
    for edge in ["next","failure"]:
     if node.get(edge)==id:node[edge]=next
   model.prune_step_conditions(draft,id)
  selected_step=record_anchor
 var check=preload("res://scripts/tutorial/config.gd").new().validate(draft,host.Store.CARDS)
 if not check.ok:host.alert("\n".join(check.errors),"录制结果未应用");return
 edit(func():model.data=draft);close_recording();refresh();update_status("已应用录制，可保存教程")

func close_recording():
 close_dialog();retire(record_view);record_view=null
 if is_instance_valid(record_flow) and record_flow.get_parent()!=null:retire(record_flow)
 record_flow=null;retire(record_tools);record_tools=null;record_status=null;recorder=null
 retire(record_restore);record_restore=null
 record_timeline=null;record_position=null
 editing_initial_board=false;initial_board_baseline={}
 workspace.show();inspector.show();get_node("AuthoringToolbar").show()

func initial_board_tableau() -> Dictionary:
 if recorder.adapter.scene_type=="battlefield":return recorder.tableau()
 var value=recorder.scene.duplicate(true)
 value.deck=preload("res://scripts/tutorial/function_recorder.gd").clean_deck(recorder.adapter.ui_deck)
 return value

func apply_initial_board():
 if not editing_initial_board or recorder==null:return
 var value=initial_board_tableau()
 if value==initial_board_baseline:close_recording();return
 var draft=model.data.duplicate(true);var target=model.unique_id("node_scene_",draft.scenarios)
 draft.scenarios[target]=value
 draft.steps[selected_step].scenario=target;draft.steps[selected_step].scenario_mode="reset"
 var reason=model.check_scene(target,value)
 if not reason.is_empty():host.alert(reason,"初始场面未应用");return
 var checked=preload("res://scripts/tutorial/config.gd").new().validate(draft,host.Store.CARDS)
 if not checked.ok:host.alert("\n".join(checked.errors),"初始场面未应用");return
 edit(func():model.data=draft);close_recording();refresh()

func edit_setup_life(who: int):
 if recorder==null or recorder.adapter.scene_type!="battlefield" or not recorder.can_edit_setup():return
 var column=modal("修改初始血量 · "+recorder.adapter.engine.player_names[who])
 var panel=column.get_parent();panel.size_flags_horizontal=Control.SIZE_SHRINK_CENTER;panel.size_flags_vertical=Control.SIZE_SHRINK_CENTER
 panel.custom_minimum_size.x=minf(460,size.x-56)
 text(column,"初始血量")
 var life=SpinBox.new();column.add_child(life);life.name="TutorialInitialLife";life.min_value=1;life.max_value=100000;life.step=1
 life.value=recorder.adapter.engine.players[who].life;life.custom_minimum_size=Vector2(180,40)
 var apply=func():
  life.apply()
  if recorder.set_setup_life(who,int(life.value)):close_dialog();record_view.render()
 var buttons=HBoxContainer.new();column.add_child(buttons)
 action(buttons,"确定",apply).name="ApplyTutorialInitialLife"
 action(buttons,"取消",close_dialog).name="CancelTutorialInitialLife"
 life.get_line_edit().text_submitted.connect(func(_value):apply.call())
 life.get_line_edit().call_deferred("grab_focus");life.get_line_edit().select_all()

func _unhandled_key_input(event: InputEvent):
 if is_instance_valid(condition_workspace):
  if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_ESCAPE:condition_workspace.cancel();get_viewport().set_input_as_handled()
  return
 if not event is InputEventKey or not event.pressed or event.echo or is_instance_valid(playtest) or recorder!=null:return
 if event.ctrl_pressed and event.keycode==KEY_S:save()
 elif event.keycode==KEY_ESCAPE and is_instance_valid(dialog_layer):close_dialog()
 else:return
 get_viewport().set_input_as_handled()

func _process(delta):
 if not order_drag_id.is_empty():
  if not workspace.is_visible_in_tree():finish_order_drag(false)
  else:
   var rect=nodes_scroll.get_global_rect()
   if rect.has_point(order_pointer):
    if order_pointer.y<rect.position.y+32:nodes_scroll.scroll_vertical-=maxi(1,int(420*delta))
    elif order_pointer.y>rect.end.y-32:nodes_scroll.scroll_vertical+=maxi(1,int(420*delta))
   update_order_drag()
 if is_instance_valid(playtest):redirect_test_exit(playtest)
 if is_instance_valid(record_view) and recorder.adapter.scene_type!="battlefield":
  redirect_test_exit(record_view,close_recording)
  recorder.tick(delta)
func text(parent: Node,value: String) -> Label:
 var control=Label.new();parent.add_child(control);control.text=value;control.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 return control


func action(parent: Node,caption: String,callback: Callable) -> Button:
 var control=host.button(parent,caption,Rect2(),callback);control.custom_minimum_size.y=56 if is_android else 36
 control.add_theme_font_size_override("font_size",20 if is_android else 16)
 return control


func option(parent: Node,values: Array,current: Variant,callback: Callable,labels: Array=[]) -> OptionButton:
 var control=OptionButton.new();parent.add_child(control);control.custom_minimum_size.y=34
 for i in range(values.size()):control.add_item(str(values[i]) if labels.is_empty() else str(labels[i]))
 control.select(maxi(0,values.find(current)))
 control.item_selected.connect(func(index):callback.call(values[index]))
 return control


func line(parent: Node,value: String,callback: Callable) -> LineEdit:
 var control=LineEdit.new();parent.add_child(control);control.text=value;control.custom_minimum_size.y=34
 control.text_changed.connect(callback)
 return control


func flag(parent: Node,caption: String,value: bool,callback: Callable) -> CheckButton:
 var control=CheckButton.new();parent.add_child(control);control.text=caption;control.button_pressed=value
 control.toggled.connect(callback)
 return control


func edit(callback: Callable):
 model.checkpoint();callback.call();update_status()


func update_status(message: String=""):
 status_label.text=message if not message.is_empty() else ("● 未保存 · " if model.dirty() else "已保存 · ")+model.data.title
 status_label.tooltip_text=model.path if message.is_empty() else message


func retire(node):
 if is_instance_valid(node):node.get_parent().remove_child(node);node.queue_free()


func modal(caption: String) -> VBoxContainer:
 close_dialog()
 dialog_layer=Control.new();dialog_layer.name="AuthoringDialog";add_child(dialog_layer);dialog_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 if recorder!=null:dialog_layer.z_index=300
 dialog_layer.mouse_filter=Control.MOUSE_FILTER_STOP
 var dim=ColorRect.new();dialog_layer.add_child(dim);dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);dim.color=Color(0,0,0,0.72)
 var margin=MarginContainer.new();dialog_layer.add_child(margin);margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 for edge in ["left","right","top","bottom"]:margin.add_theme_constant_override("margin_"+edge,28)
 var panel=PanelContainer.new();margin.add_child(panel);panel.add_theme_stylebox_override("panel",host.ui_metrics.panel_style())
 var column=VBoxContainer.new();panel.add_child(column)
 var header=HBoxContainer.new();column.add_child(header)
 var heading=text(header,caption);heading.size_flags_horizontal=Control.SIZE_EXPAND_FILL;heading.add_theme_color_override("font_color",host.GOLD)
 action(header,"关闭",close_dialog)
 return column


func close_dialog():
 if recorder!=null and is_instance_valid(dialog_layer) and dialog_layer.has_meta("recording_result") and recorder.adapter.scene_type!="battlefield" and record_rows.size()==recorder.nodes.size():
  recorder.nodes=record_rows.duplicate(true)
 retire(dialog_layer);dialog_layer=null
 condition_workspace=null
 for item in condition_visibility:
  if is_instance_valid(item[0]):item[0].visible=item[1]
 condition_visibility=[]


func guard_discard(callback: Callable):
 if not model.dirty():callback.call();return
 host.confirm_action("当前课程有未保存修改，继续将丢弃这些修改。",callback)


func open_file():
 file_dialog(false)


func file_dialog(saving: bool):
 var dialog=FileDialog.new();add_child(dialog);dialog.access=FileDialog.ACCESS_FILESYSTEM
 dialog.file_mode=FileDialog.FILE_MODE_SAVE_FILE if saving else FileDialog.FILE_MODE_OPEN_FILE
 dialog.title="保存教程课程" if saving else "打开教程课程";dialog.filters=PackedStringArray(["*.json ; 教程课程"])
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(Model.LOCAL_DIR))
 dialog.current_dir=ProjectSettings.globalize_path(Model.LOCAL_DIR)
 if saving:dialog.current_file=model.data.id.validate_filename()+".json"
 dialog.file_selected.connect(func(file):
  if saving:save_to(file)
  else:
   var reason=model.load_course(file)
   if not reason.is_empty():host.alert(reason,"打开失败")
   else:selected_step=model.data.start_step;refresh()
  dialog.queue_free())
 dialog.canceled.connect(dialog.queue_free)
 dialog.popup_centered_ratio(0.8)


func save():
 if model.path.is_empty() or (model.path.begins_with("res://") and not OS.has_feature("editor")):file_dialog(true)
 else:save_to(model.path)


func save_to(file: String):
 var reason=model.save_course(file)
 if not reason.is_empty():host.alert(reason,"课程保存失败");return
 host.load_tutorial_catalog();update_status()


func test_course():
 var checked=model.validate()
 if not checked.ok:host.alert("\n".join(checked.errors),"试玩前请修正课程");return
 # Preview old authored scenes with basic responses without changing the document.
 for scene in checked.data.scenarios.values():
  if scene.get("type","battlefield")!="battlefield":continue
  if not scene.has("opponent"):scene.opponent={"strategy":"paused"}
  if not scene.opponent.has("auto_response"):scene.opponent.auto_response=true
 close_dialog()
 var context=model.context_for(selected_step)
 var flow=Runtime.new();var reason=flow.start(checked.data,host.Store.CARDS,selected_step,context.scene,context.steps)
 if not reason.is_empty():flow.free();host.alert(reason,"试玩初始化失败");return
 workspace.hide();inspector.hide();get_node("AuthoringToolbar").hide()
 playtest=preload("res://scripts/tutorial/scene_view.gd").new();add_child(playtest);playtest.begin(host,flow)
 # Native recordings contain one task per action. Restore their preceding
 # actions privately so a later remove/inspect task has the expected deck.
 if flow.adapter.scene_type!="battlefield":
  for id in model.recording_steps(selected_step):
   if id==selected_step:break
   reason=playtest.editor_host.replay_recorded_action(model.data.steps[id].task.action)
   if not reason.is_empty():stop_test();host.alert(reason,"试玩准备失败");return
  flow.adapter.last_ui_action={};flow.events.clear();flow.checkpoint=flow.capture()
 var back=action(playtest,"返回编辑器",stop_test);back.name="ReturnToAuthoring";back.position=Vector2(12,12);back.size=Vector2(156,40);back.z_index=250
 # All normal tutorial exit buttons return to the still-live unsaved document.
 redirect_test_exit(playtest)
 flow.scenario_changed.connect(func():call_deferred("redirect_test_exit",playtest))


func redirect_test_exit(node: Node,return_action: Callable=Callable()):
 if not is_instance_valid(node):return
 if not return_action.is_valid():return_action=stop_test
 if node is Button:
  var exits=node.has_meta("authoring_exit") or node.name in ["TutorialInspectionExit"]
  for connection in node.pressed.get_connections():
   if connection.callable.get_object()==host and connection.callable.get_method()=="tutorials":exits=true
  if exits:
   if not node.has_meta("authoring_exit"):
    for connection in node.pressed.get_connections():node.pressed.disconnect(connection.callable)
    node.set_meta("authoring_exit",true);node.pressed.connect(return_action)
   node.text="返回编辑器"
 for child in node.get_children():redirect_test_exit(child,return_action)


func stop_test():
 retire(playtest);playtest=null
 host.screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 workspace.show();inspector.show();get_node("AuthoringToolbar").show();rebuild_nodes()


