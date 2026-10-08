extends Control
## Presentation only. Hiding this popup never changes Runtime's progress.
const CardInspection=preload("res://scripts/card_inspection.gd")
var view
var runtime
var blocker: Control
var panel: PanelContainer
var body: VBoxContainer
var middle: BoxContainer
var heading: Label
var message: RichTextLabel
var illustration
var scroll: ScrollContainer
var footer: VBoxContainer
var secondary_actions: HBoxContainer
var next_button: Button
var hide_button: Button
var restore_button: Button
var exit_button: Button
var previous_button: Button
var reset_button: Button
var confirm_answer_button: Button
var selected_answer=""
var selected_epoch=-1
var popup_open=true
var step: Dictionary={}
var original_visibility: Dictionary={}
var focus_card: TextureRect
var focus_kind=""
var focus_id=""
var focus_finger=-1
var focus_hold_origin=Vector2.ZERO
var focus_hold_ring: Control
var inspection: VBoxContainer
var inspection_overlay: Control
var inspection_popup: PanelContainer
var inspection_art: TextureRect
var inspection_id=""
var answers_scroll: ScrollContainer
var answers: GridContainer
var answer_buttons: Array=[]
var answer_feedback: Label
var swipe_scroll=preload("res://scripts/android_swipe_scroll.gd").new()
var practice_feedback=""
var practice_feedback_index=-1

func build(owner_view,flow):
 view=owner_view;runtime=flow;name="TutorialGuide"
 set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 mouse_filter=Control.MOUSE_FILTER_IGNORE;z_index=200
 blocker=Control.new();blocker.name="TutorialInputBlocker";add_child(blocker)
 blocker.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);blocker.mouse_filter=Control.MOUSE_FILTER_STOP
 blocker.gui_input.connect(blocked_battle_input)
 panel=PanelContainer.new();panel.name="TutorialPopup";add_child(panel)
 body=VBoxContainer.new();panel.add_child(body)
 heading=Label.new();body.add_child(heading);heading.add_theme_color_override("font_color",view.host.GOLD)
 middle=BoxContainer.new();body.add_child(middle);middle.size_flags_vertical=Control.SIZE_EXPAND_FILL
 focus_card=TextureRect.new();focus_card.name="TutorialFocusCard";middle.add_child(focus_card)
 focus_card.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;focus_card.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
 focus_card.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
 focus_card.mouse_filter=Control.MOUSE_FILTER_STOP if view.is_android else Control.MOUSE_FILTER_IGNORE;focus_card.hide()
 if view.is_android:focus_card.tooltip_text="长按 1 秒：查看详情"
 scroll=ScrollContainer.new();middle.add_child(scroll);scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;scroll.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
 var content=VBoxContainer.new();scroll.add_child(content);content.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 message=RichTextLabel.new();message.name="TutorialText";content.add_child(message)
 message.fit_content=true;message.scroll_active=false;message.size_flags_horizontal=Control.SIZE_EXPAND_FILL;message.bbcode_enabled=false
 illustration=preload("res://scripts/tutorial/guide_image_gallery.gd").new();illustration.name="TutorialGuideImage";content.add_child(illustration)
 illustration.configure(self,view.host);illustration.hide()
 answers_scroll=ScrollContainer.new();answers_scroll.name="TutorialAnswersScroll";body.add_child(answers_scroll)
 answers_scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;answers_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
 answers=GridContainer.new();answers.name="TutorialAnswers";answers_scroll.add_child(answers)
 answers.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 answer_feedback=Label.new();answer_feedback.name="TutorialAnswerFeedback";body.add_child(answer_feedback)
 answer_feedback.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;answer_feedback.add_theme_color_override("font_color",view.host.GOLD)
 inspection=VBoxContainer.new();inspection.name="TutorialCardInspection";body.add_child(inspection)
 inspection.size_flags_vertical=Control.SIZE_EXPAND_FILL;inspection.hide()
 footer=VBoxContainer.new();body.add_child(footer)
 next_button=view.host.button(footer,"下一步",Rect2(),func():runtime.next(),true);next_button.name="TutorialNextStep"
 secondary_actions=HBoxContainer.new();footer.add_child(secondary_actions)
 confirm_answer_button=view.host.button(secondary_actions,"确定",Rect2(),confirm_answer,true);confirm_answer_button.name="TutorialConfirmAnswer"
 previous_button=view.host.button(secondary_actions,"上一步",Rect2(),func():runtime.previous());previous_button.name="TutorialPreviousStep"
 reset_button=view.host.button(secondary_actions,"重置局面",Rect2(),reset_task);reset_button.name="TutorialResetTask"
 reset_button.tooltip_text="恢复本任务开始时的局面，重新尝试。";reset_button.hide()
 hide_button=view.host.button(secondary_actions,"隐藏指引",Rect2(),func():set_popup(false))
 exit_button=view.host.button(secondary_actions,"教程目录" if not runtime.course_path.is_empty() else "退出教程",Rect2(),leave_tutorial)
 restore_button=view.host.button(self,"显示指引",Rect2(),func():set_popup(true));restore_button.name="TutorialRestoreGuide"
 runtime.step_changed.connect(show_step)
 runtime.completed.connect(finish)
 runtime.failed.connect(show_error)
 runtime.task_failed.connect(show_task_failure)
 runtime.sequence_changed.connect(show_sequence_state)
 if runtime.running:show_step(runtime.current_step,runtime.tutorial.steps[runtime.current_step])

func detach_runtime():
 # queue_free happens after the step signal; retire this guide immediately.
 cancel_focus_hold()
 for pair in [[runtime.step_changed,show_step],[runtime.completed,finish],[runtime.failed,show_error],[runtime.task_failed,show_task_failure],[runtime.sequence_changed,show_sequence_state]]:
  if pair[0].is_connected(pair[1]):pair[0].disconnect(pair[1])
 set_process(false);set_process_input(false)

func show_step(_id: String,value: Dictionary):
 close_card_details()
 if runtime.adapter.scene_type=="battlefield":
  var battle=view.surface if view.has_method("tutorial_component") else view
  battle.inspect_id="";battle.update_inspection()
  if value.get("task",{}).has("sequence"):battle.response_mode=battle.ResponseMode.ON
 step=value;heading.text=runtime.tutorial.title
 practice_feedback="";practice_feedback_index=-1
 hide_button.show();exit_button.text="教程目录" if not runtime.course_path.is_empty() else "退出教程"
 message.text=value.guide.text;scroll.scroll_vertical=0
 illustration.set_data(value.guide.get("image",{}))
 var focus=value.guide.get("focus",runtime.adapter.scene_config.get("focus",{}))
 var entity=runtime.adapter.entity(focus.get("alias",""))
 focus_id=str(focus.get("card_id",entity.get("card_id","")))
 focus_card.visible=view.host.Store.CARDS.has(focus_id)
 focus_kind=view.host.Store.CARDS.get(focus_id,{}).get("kind","")
 if focus_card.visible:focus_card.texture=view.host.preview_texture(focus_id,entity.get("art_id",""))
 update_card_highlights(value.guide.get("targets",[]))
 next_button.text="完成教程" if value.next=="$complete" else "下一步"
 next_button.visible=value.type=="info" and value.guide.get("next_button","manual")=="manual"
 reset_button.visible=value.has("sequence") or value.type in ["task","wait"] and not runtime.answering()
 reset_button.text="重置演示" if value.has("sequence") else "重置局面"
 reset_button.tooltip_text="恢复演示开始时的局面，再看一遍相同的动作和随机结果。" if value.has("sequence") else "恢复本任务开始时的局面，重新尝试。"
 build_answers()
 set_popup(value.guide.get("popup","show")=="show")
 if view.has_method("apply_tutorial_presentation"):view.apply_tutorial_presentation(runtime.presentation)

func build_answers():
 view.host.free_children(answers);answer_buttons=[];answer_feedback.text="";selected_answer="";selected_epoch=-1
 confirm_answer_button.visible=runtime.answering() and step.task.quiz.answers.any(func(answer):return answer.has("card_id"))
 confirm_answer_button.disabled=true
 answers_scroll.visible=runtime.answering();answer_feedback.visible=runtime.answering()
 middle.size_flags_vertical=Control.SIZE_FILL if runtime.answering() else Control.SIZE_EXPAND_FILL
 if not runtime.answering():return
 hide_button.hide()
 var generation=runtime.epoch
 for answer in step.task.quiz.answers:
  var button: Button
  if answer.has("card_id"):
   button=preload("res://scripts/tutorial/answer_card_button.gd").new();button.is_android=view.is_android
   button.inspection_enabled=func():return runtime.answering() and runtime.epoch==generation and not is_instance_valid(inspection_overlay)
   answers.add_child(button);button.toggle_mode=true
   button.selected.connect(func():select_answer(answer.id,generation))
   button.inspection_requested.connect(func():
    if runtime.answering() and runtime.epoch==generation:show_answer_details(answer.card_id))
  else:button=view.host.button(answers,"",Rect2(),func():runtime.submit_answer(answer.id,generation))
  button.name="TutorialAnswer"+answer.id;button.set_meta("answer_id",answer.id)
  button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
  var column=VBoxContainer.new();button.add_child(column);column.mouse_filter=Control.MOUSE_FILTER_IGNORE
  column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
  if answer.has("card_id"):
   var art=TextureRect.new();art.name="AnswerCardArt";column.add_child(art)
   art.texture=view.host.preview_texture(answer.card_id);art.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
   art.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;art.mouse_filter=Control.MOUSE_FILTER_IGNORE
   art.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
  if not answer.has("card_id"):
   var caption=Label.new();caption.name="AnswerCaption";column.add_child(caption)
   caption.text=answer.text
   caption.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
   caption.mouse_filter=Control.MOUSE_FILTER_IGNORE;button.tooltip_text=caption.text
  else:button.tooltip_text=answer.get("text","")
  answer_buttons.append(button)

func select_answer(id: String,generation: int):
 if not runtime.answering() or runtime.epoch!=generation:return
 selected_answer=id;selected_epoch=generation;confirm_answer_button.disabled=false
 answer_feedback.text="已选择答案，请点击确定。"
 for button in answer_buttons:button.set_pressed_no_signal(button.get_meta("answer_id")==id)

func confirm_answer():
 if selected_answer.is_empty() or selected_epoch!=runtime.epoch:return
 runtime.submit_answer(selected_answer,selected_epoch)

func reset_task():
 if step.has("sequence"):
  runtime.replay_sequence();return
 if runtime.reset_task() and is_instance_valid(view.tutorial_guide):view.tutorial_guide.set_popup(true)

func show_sequence_state(playing: bool):
 if step.has("sequence"):
  if playing:close_card_details()
  set_popup(not playing)

func finish(_id: String):
 close_card_details()
 update_card_highlights([])
 if view.has_method("apply_tutorial_presentation"):view.apply_tutorial_presentation({"camera_view":runtime.presentation.camera_view,"open_zone":{}})
 heading.text="教程完成";message.text="已完成本课的全部步骤。"
 illustration.hide();illustration.clear()
 next_button.hide();hide_button.hide();exit_button.text="返回教程目录" if not runtime.course_path.is_empty() else "返回教程列表"
 reset_button.hide()
 build_answers()
 set_popup(true)

func show_error(reason: String):
 close_card_details()
 update_card_highlights([])
 if view.has_method("apply_tutorial_presentation"):view.apply_tutorial_presentation({"camera_view":runtime.presentation.camera_view,"open_zone":{}})
 heading.text="教程配置或执行错误";message.text=reason
 illustration.hide();illustration.clear()
 reset_button.hide()
 next_button.hide();hide_button.hide();build_answers();set_popup(true)

func show_task_failure(reason: String):
 close_card_details()
 if step.get("task",{}).has("sequence"):practice_feedback=reason;practice_feedback_index=runtime.practice.index
 if runtime.answering():
  selected_answer="";selected_epoch=-1;confirm_answer_button.disabled=true
  for button in answer_buttons:button.set_pressed_no_signal(false)
  answer_feedback.text=reason;set_popup(true);return
 message.text=step.get("guide",{}).get("text","")+"\n\n"+reason
 set_popup(true)

func side_layout() -> bool:
 if runtime.answering():return false
 return step.get("guide",{}).get("layout","side" if runtime.adapter.scene_type!="battlefield" else "modal")=="side"

func set_popup(value: bool):
 if runtime.answering():value=true
 if runtime.playing_sequence():value=false
 if not value:close_card_details()
 swipe_scroll.reset()
 popup_open=value;panel.visible=value;restore_button.visible=not value and not runtime.playing_sequence()
 apply_components();relayout();queue_redraw()

func component(id: String):
 if view.has_method("tutorial_component"):return view.tutorial_component(id)
 match id:
  "battlefield":return view.stage
  "hand":return view.hand_scroll
  "opponent_hand":return view.opponent_layer
  "inspection":return view.inspection
  "hud":return view.hud
  "stack":return view.stack_panel
 return null

func apply_components():
 var policy=runtime.adapter.components
 view.tutorial_controls_enabled=policy.get("interaction",{}).get("enabled",true) and runtime.permits_match_actions() and (side_layout() or not popup_open)
 if runtime.adapter.scene_type=="battlefield":
  var battle=view.surface if view.has_method("tutorial_component") else view
  if battle.tutorial_controls_enabled!=view.tutorial_controls_enabled:
   battle.tutorial_controls_enabled=view.tutorial_controls_enabled
   battle.update_inspection()
  battle.inspection.z_index=202 if not view.tutorial_controls_enabled else 0
 # Battle dialogues also block native GUI buttons when the guide is hidden.
 blocker.visible=not view.tutorial_controls_enabled and (runtime.adapter.scene_type=="battlefield" or not side_layout())
 for id in original_visibility.keys():
  if not policy.get(id,{}).has("visible"):
   var node=component(id)
   if is_instance_valid(node):node.visible=original_visibility[id]
   original_visibility.erase(id)
 for id in policy:
  var node=component(id)
  if is_instance_valid(node) and policy[id].has("visible"):
   if not original_visibility.has(id):original_visibility[id]=node.visible
   node.visible=policy[id].visible

func blocked_battle_input(event: InputEvent):
 if runtime.adapter.scene_type!="battlefield" or view.tutorial_controls_enabled:return
 if not (event is InputEventMouseButton or event is InputEventScreenTouch or event is InputEventScreenDrag):return
 var surface=view.surface if view.has_method("tutorial_component") else view
 surface.tutorial_blocker_input(event,blocker.get_global_transform()*event.position)

func update_card_highlights(targets: Array):
 if runtime.adapter.scene_type=="deck" and is_instance_valid(view.editor_host):
  view.editor_host.deck_overview.set_card_highlights(targets.filter(func(target):return target.has("card_id")))
 elif runtime.adapter.scene_type=="battlefield" and view.has_method("set_tutorial_card_highlights"):
  view.set_tutorial_card_highlights(targets)

func relayout():
 var m=view.host.ui_metrics
 var reserved=view.guide_rect() if side_layout() and view.has_method("guide_rect") else Rect2()
 var embedded=reserved.has_area()
 var split_zone=runtime.running and runtime.adapter.scene_type=="battlefield" and not runtime.presentation.open_zone.is_empty()
 var compact=(embedded and runtime.adapter.scene_type=="in_game") or split_zone
 var gap=10 if compact else int(m.gap)
 var safe=view.get_global_rect().intersection(m.safe).grow(-m.gap)
 if not safe.has_area():return
 safe.position-=global_position
 var width=minf(820,safe.size.x)
 var height=minf(340 if not view.is_android else maxf(360,m.hit*3+m.body*5),safe.size.y)
 if focus_card.visible and not embedded:
  width=minf(1000,safe.size.x);height=safe.size.y if view.is_android else minf(800 if focus_kind in ["符卡","结界"] else 640,safe.size.y)
 if illustration.visible and not embedded:height=maxf(height,minf(640,safe.size.y))
 if runtime.answering():
  width=safe.size.x;height=safe.size.y
 panel.position=safe.get_center()-Vector2(width,height)*0.5;panel.size=Vector2(width,height)
 if split_zone:
  panel.size=Vector2(maxf(1,safe.size.x*0.5-m.gap),height)
  panel.position=Vector2(safe.position.x,safe.get_center().y-height*0.5)
 if embedded:
  panel.position=reserved.position;panel.size=reserved.size
 panel.add_theme_stylebox_override("panel",m.panel_style(true))
 if embedded:
  var embedded_style=m.panel_style(compact)
  if compact:embedded_style.set_content_margin_all(14)
  else:
   embedded_style.bg_color=Color.TRANSPARENT
   embedded_style.set_border_width_all(0);embedded_style.set_corner_radius_all(0)
  panel.add_theme_stylebox_override("panel",embedded_style)
 hide_button.text="隐藏" if embedded or split_zone else "隐藏指引"
 if runtime.running:
  if not runtime.course_path.is_empty():exit_button.text="目录" if split_zone else "教程目录"
  else:exit_button.text="退出" if split_zone else "退出教程"
 heading.add_theme_font_size_override("font_size",(30 if view.is_android else 22) if compact else m.title)
 heading.tooltip_text=heading.text
 heading.clip_text=true
 message.add_theme_font_size_override("normal_font_size",(26 if view.is_android else 18) if compact else m.body)
 body.add_theme_constant_override("separation",gap)
 footer.add_theme_constant_override("separation",gap)
 secondary_actions.add_theme_constant_override("separation",gap)
 middle.add_theme_constant_override("separation",gap)
 middle.vertical=side_layout()
 previous_button.disabled=not runtime.can_previous()
 next_button.disabled=runtime.playing_sequence()
 reset_button.disabled=not (runtime.can_replay_sequence() if step.has("sequence") else runtime.can_reset_task())
 for button in [next_button,confirm_answer_button,previous_button,reset_button,hide_button,exit_button,restore_button]:m.button(button)
 if compact:
  for button in [next_button,confirm_answer_button,previous_button,reset_button,hide_button,exit_button,restore_button]:
   button.custom_minimum_size=Vector2(0,64 if view.is_android else 40)
   button.add_theme_font_size_override("font_size",24 if view.is_android else 16)
   for state in ["normal","hover","pressed","focus"]:
    var style=m.panel_style(state in ["pressed","focus"])
    style.set_content_margin_all(8)
    if state=="hover":style.bg_color=Color("#223b4b")
    elif state=="pressed":style.bg_color=Color("#514328")
    elif state=="focus":style.bg_color=Color.TRANSPARENT
    button.add_theme_stylebox_override(state,style)
 for button in [next_button,confirm_answer_button,previous_button,reset_button,hide_button,exit_button]:button.custom_minimum_size.x=0;button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 scroll.custom_minimum_size.y=80 if compact else minf(panel.size.y*0.3,maxf(m.body*3,100)) if side_layout() or focus_card.visible else 0
 if runtime.answering():layout_answers(m,gap)
 if side_layout() and not compact:
  var buttons=[previous_button,reset_button,hide_button,exit_button].filter(func(button):return button.visible)
  var letters=0
  for button in buttons:letters=maxi(letters,button.text.length())
  var footer_font=mini(m.small,maxi(12,int((panel.size.x-m.padding*(buttons.size()+1)-m.gap*(buttons.size()-1))/maxi(1,letters*buttons.size()))))
  for button in buttons:button.add_theme_font_size_override("font_size",footer_font)
 if step.has("sequence") and not side_layout() and not compact:
  # Dense Android layouts keep every action caption readable, including replay.
  for button in [confirm_answer_button,previous_button,reset_button,hide_button,exit_button]:
   if not button.visible or button.size.x<=0:continue
   var space=maxf(1,button.size.x-button.get_theme_stylebox("normal").get_minimum_size().x)
   var caption_width=button.get_theme_font("font").get_string_size(button.text,HORIZONTAL_ALIGNMENT_LEFT,-1,m.small).x
   var font=mini(m.small,maxi(12,floori(m.small*space/maxf(1,caption_width))))
   button.add_theme_font_size_override("font_size",font)
 focus_card.custom_minimum_size=Vector2.ZERO
 focus_card.size_flags_horizontal=Control.SIZE_FILL
 focus_card.size_flags_vertical=Control.SIZE_EXPAND_FILL
 if focus_card.visible and not embedded and not runtime.answering():
  var horizontal_card=focus_kind in ["符卡","结界"]
  middle.vertical=horizontal_card
  middle.move_child(focus_card,0 if horizontal_card else 1)
  var available=maxf(80,panel.size.y-m.padding*2-heading.get_combined_minimum_size().y-footer.get_combined_minimum_size().y-gap*2)
  if horizontal_card:
   focus_card.size_flags_horizontal=Control.SIZE_EXPAND_FILL
   focus_card.size_flags_vertical=Control.SIZE_FILL
   focus_card.custom_minimum_size.y=available*0.68
   scroll.custom_minimum_size.y=minf(available*0.20,maxf(60,m.body*2))
  else:
   focus_card.custom_minimum_size.x=minf(panel.size.x*0.46,available/1.397)
 if focus_card.visible and embedded:
  focus_card.custom_minimum_size.y=minf(panel.size.y*0.40,360)
  var others=panel.get_combined_minimum_size().y-focus_card.get_combined_minimum_size().y
  focus_card.custom_minimum_size.y=minf(focus_card.custom_minimum_size.y,maxf(0,panel.size.y-others))
 if runtime.answering() and focus_card.visible:
  middle.vertical=true
  middle.move_child(focus_card,0)
  focus_card.size_flags_horizontal=Control.SIZE_EXPAND_FILL
  focus_card.size_flags_vertical=Control.SIZE_FILL
  focus_card.custom_minimum_size.y=minf(400,panel.size.y*(0.30 if view.is_android else 0.43))
 if illustration.visible:
  illustration.set_height_limit(minf(320,maxf(64,scroll.size.y*0.80)))
 if restore_button.visible:place_restore(safe)
 fit_card_details()

func layout_answers(m,gap: int):
 var font=mini(m.body,32 if view.is_android else 18)
 heading.add_theme_font_size_override("font_size",mini(m.title,40))
 message.add_theme_font_size_override("normal_font_size",font)
 scroll.custom_minimum_size.y=minf(panel.size.y*0.16,maxf(font*2.8,64))
 middle.vertical=true
 answer_feedback.visible=not answer_feedback.text.is_empty()
 answer_feedback.add_theme_font_size_override("font_size",font)
 answers.add_theme_constant_override("h_separation",gap);answers.add_theme_constant_override("v_separation",gap)
 var available=maxf(1,panel.size.x-m.padding*2-24)
 answers.columns=mini(answer_buttons.size(),clampi(floori((available+gap)/((220 if view.is_android else 190)+gap)),1,4))
 var cell_width=(available-gap*(answers.columns-1))/answers.columns
 for button in answer_buttons:
  m.button(button);button.custom_minimum_size.x=cell_width
  var column=button.get_child(0)
  column.offset_left=gap;column.offset_top=gap;column.offset_right=-gap;column.offset_bottom=-gap
  column.add_theme_constant_override("separation",gap)
  var caption=column.get_node_or_null("AnswerCaption")
  var text_height=0.0
  if caption!=null:
   caption.add_theme_font_size_override("font_size",font)
   text_height=caption.get_theme_font("font").get_multiline_string_size(caption.text,HORIZONTAL_ALIGNMENT_CENTER,maxf(1,cell_width-gap*2),font).y
  var art=column.get_node_or_null("AnswerCardArt")
  var art_height=minf(480,maxf(80,answers_scroll.size.y-text_height-gap*2)) if art!=null else 0.0
  if art!=null:art.custom_minimum_size.y=art_height
  button.custom_minimum_size.y=maxf(m.hit,text_height+gap*2+art_height)

func inspection_header(parent: Node):
 var header=HBoxContainer.new();parent.add_child(header)
 var title=CardInspection.text(view.host,header,"卡牌详情",view.host.ui_metrics.body,view.host.GOLD)
 title.autowrap_mode=TextServer.AUTOWRAP_OFF;title.clip_text=true
 var previous=view.host.button(header,"上一步",Rect2(),close_card_details)
 previous.name="TutorialInspectionPrevious";view.host.ui_metrics.button(previous)
 var close=view.host.button(header,"关闭",Rect2(),close_card_details)
 close.name="TutorialCloseCardDetails";view.host.ui_metrics.button(close)
 if is_instance_valid(inspection_overlay):
  var leave=view.host.button(header,"教程目录" if not runtime.course_path.is_empty() else "退出教程",Rect2(),leave_tutorial)
  leave.name="TutorialInspectionExit";view.host.ui_metrics.button(leave)

func leave_tutorial():
 if not runtime.course_path.is_empty():view.host.tutorial_directory(runtime.course_path)
 else:view.host.tutorials()

func show_answer_details(id: String):
 close_card_details()
 inspection_id=id
 inspection_overlay=Control.new();inspection_overlay.name="TutorialCardOverlay";add_child(inspection_overlay)
 inspection_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 var shade=ColorRect.new();shade.color=Color(0,0,0,0.88);inspection_overlay.add_child(shade)
 shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 inspection_popup=PanelContainer.new();inspection_popup.name="TutorialCardPopup";inspection_overlay.add_child(inspection_popup)
 inspection_popup.add_theme_stylebox_override("panel",view.host.ui_metrics.panel_style())
 fit_card_details()
 var column=VBoxContainer.new();inspection_popup.add_child(column)
 column.add_theme_constant_override("separation",int(view.host.ui_metrics.gap));inspection_header(column)
 card_detail_panes(column,id,{})

func card_detail_panes(parent: Node,id: String,deck: Dictionary):
 var m=view.host.ui_metrics
 var horizontal_card=view.host.Store.CARDS[id].kind in ["符卡","结界"]
 var panes=BoxContainer.new();panes.name="TutorialCardPanes";panes.vertical=horizontal_card
 parent.add_child(panes);CardInspection.expand(panes,true)
 panes.add_theme_constant_override("separation",int(m.gap))
 var words=VBoxContainer.new();words.name="TutorialCardWords";panes.add_child(words);CardInspection.expand(words,true)
 var width=inspection_popup.size.x-m.padding*2-m.gap
 CardInspection.rules(view.host,words,id,maxf(100,(width if horizontal_card else width*0.52)-16))
 inspection_art=CardInspection.artwork(view.host,panes,id,deck)
 inspection_art.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
 if horizontal_card:panes.move_child(inspection_art,0)
 else:inspection_art.size_flags_stretch_ratio=0.92
 fit_card_details()

func show_card_details(id: String,deck: Dictionary):
 if runtime.adapter.scene_type!="deck" or not view.host.Store.CARDS.has(id):return
 close_card_details();set_popup(true);inspection_id=id
 var m=view.host.ui_metrics
 if not view.is_android:
  heading.hide();middle.hide();inspection.show()
  inspection.add_theme_constant_override("separation",int(m.gap))
  inspection_header(inspection)
  inspection_art=CardInspection.artwork(view.host,inspection,id,deck)
  inspection_art.size_flags_vertical=Control.SIZE_FILL
  fit_card_details()
  CardInspection.rules(view.host,inspection,id,maxf(100,panel.size.x-m.padding*2-16))
  return
 inspection_overlay=Control.new();inspection_overlay.name="TutorialCardOverlay";add_child(inspection_overlay)
 inspection_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 var shade=ColorRect.new();shade.color=Color(0,0,0,0.78);inspection_overlay.add_child(shade)
 shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 shade.gui_input.connect(func(event):
  if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT:close_card_details())
 inspection_popup=PanelContainer.new();inspection_popup.name="TutorialCardPopup";inspection_overlay.add_child(inspection_popup)
 inspection_popup.add_theme_stylebox_override("panel",m.panel_style())
 fit_card_details()
 var column=VBoxContainer.new();inspection_popup.add_child(column)
 column.add_theme_constant_override("separation",int(m.gap));inspection_header(column)
 card_detail_panes(column,id,deck)

func fit_card_details():
 var m=view.host.ui_metrics
 if is_instance_valid(inspection_popup):
  var safe=view.get_global_rect().intersection(m.safe).grow(-m.padding)
  inspection_popup.size=Vector2(minf(1200,safe.size.x),safe.size.y)
  inspection_popup.position=safe.get_center()-inspection_popup.size*0.5-global_position
  if is_instance_valid(inspection_art):
   var panes=inspection_art.get_parent()
   if panes is BoxContainer and panes.vertical:
    inspection_art.size_flags_vertical=Control.SIZE_FILL
    inspection_art.custom_minimum_size.y=maxf(80,(inspection_popup.size.y-m.padding*2-m.hit-m.gap*2)*0.58)
 elif is_instance_valid(inspection_art) and not inspection_id.is_empty():
  var width=maxf(100,panel.size.x-m.padding*2)
  inspection_art.custom_minimum_size.y=minf(view.size.y*0.3,width*(0.72 if view.host.landscape_card(inspection_id) else 1.397))

func close_card_details():
 if is_instance_valid(illustration):illustration.close_preview()
 cancel_focus_hold()
 if is_instance_valid(inspection_overlay):
  remove_child(inspection_overlay);inspection_overlay.queue_free()
 inspection_overlay=null;inspection_popup=null;inspection_art=null;inspection_id=""
 if is_instance_valid(inspection):inspection.hide();view.host.free_children(inspection)
 if is_instance_valid(heading):heading.show()
 if is_instance_valid(middle):middle.show()

func existing_buttons(node: Node,rects: Array):
 if node==self:return
 if node is BaseButton and node.is_visible_in_tree():
  var rect=node.get_global_rect()
  if node.get_viewport()!=get_viewport() and view.has_method("project_rect"):rect=view.project_rect(rect)
  rect.position-=global_position
  if rect.has_area():rects.append(rect.grow(4))
 for child in node.get_children():existing_buttons(child,rects)

func place_restore(safe: Rect2):
 restore_button.size=Vector2(minf(safe.size.x,maxf(150,restore_button.get_combined_minimum_size().x)),restore_button.get_combined_minimum_size().y)
 var reserved=view.guide_rect() if view.has_method("guide_rect") else Rect2()
 var region=reserved if reserved.has_area() else safe
 var occupied=[];existing_buttons(view,occupied)
 # Search the entire safe area after the preferred corner; re-evaluate on
 # every layout update, including native button changes and window resizing.
 var candidates=[region.position,Vector2(region.end.x-restore_button.size.x,region.position.y)]
 var stride=Vector2(maxf(24,restore_button.size.x/2),maxf(16,restore_button.size.y/2))
 var y=region.position.y
 while y+restore_button.size.y<=region.end.y:
  var x=region.position.x
  while x+restore_button.size.x<=region.end.x:
   candidates.append(Vector2(x,y));x+=stride.x
  y+=stride.y
 for at in candidates:
  var rect=Rect2(at,restore_button.size)
  if region.encloses(rect) and not occupied.any(func(other):return other.intersects(rect)):
   restore_button.position=at;return
 # A crowded legacy screen gets a reserved strip. Shrink its presentation
 # instead of covering an existing action. Typed scenes already reserve one.
 if not reserved.has_area():
  var reserve=restore_button.size.y+view.host.ui_metrics.gap*2
  var factor=maxf(0.1,(safe.size.y-reserve)/view.size.y)
  var presentation=view.surface if view.has_method("tutorial_component") else view
  for node in presentation.get_children():
   if node is Control and node!=self:
    node.scale=Vector2.ONE*factor;node.position.y=maxf(node.position.y,reserve)
  restore_button.position=safe.position

func target_rect(target: Dictionary) -> Rect2:
 if target.has("card_id"):return Rect2() # Deck faces draw their own clipped red borders.
 if target.has("alias"):
  var c=runtime.adapter.entity(target.alias)
  return view.target_rect(view.engine.ref_target(c)) if not c.is_empty() else Rect2()
 if target.has("player"):return view.target_rect({"player":int(target.player)})
 var node=component(target.get("component",""))
 if view.has_method("component_rect"):return view.component_rect(target.get("component",""))
 return node.get_global_rect() if is_instance_valid(node) and node.visible else Rect2()

func _process(_delta):
 if runtime.running and step.get("task",{}).has("sequence"):
  var config=step.task.sequence
  var progress="动作 %d / %d" % [mini(runtime.practice.index+1,config.actions.size()),config.actions.size()]
  if runtime.practice.playing and runtime.practice.index<config.actions.size():
   progress+=" · "+preload("res://scripts/tutorial/battle_commands.gd").caption(runtime.adapter,config.actions[runtime.practice.index])
  else:progress+=" · 动作已完成，判定任务条件"
  message.text=step.guide.text+"\n\n"+progress
  if runtime.practice.index==practice_feedback_index and not practice_feedback.is_empty():message.text+="\n"+practice_feedback
 update_card_highlights(step.get("guide",{}).get("targets",[]) if runtime.running else [])
 apply_components();relayout();queue_redraw()

func owns_pointer_event(event: InputEvent) -> bool:
 if not (event is InputEventMouseButton or event is InputEventMouseMotion or event is InputEventScreenTouch or event is InputEventScreenDrag):return false
 return (is_instance_valid(illustration.overlay) and illustration.overlay.is_visible_in_tree()) or (is_instance_valid(inspection_overlay) and inspection_overlay.is_visible_in_tree()) or (panel.is_visible_in_tree() and panel.get_global_rect().has_point(event.position)) or (restore_button.is_visible_in_tree() and restore_button.get_global_rect().has_point(event.position))

func cancel_focus_hold():
 if is_instance_valid(focus_hold_ring):focus_hold_ring.queue_free()
 focus_hold_ring=null;focus_finger=-1

func _exit_tree():cancel_focus_hold()

func _notification(what):
 if what in [NOTIFICATION_WM_WINDOW_FOCUS_OUT,NOTIFICATION_APPLICATION_PAUSED]:cancel_focus_hold()

func focus_card_touch(event: InputEvent) -> bool:
 if not (event is InputEventScreenTouch or event is InputEventScreenDrag):return false
 if event is InputEventScreenTouch and event.pressed:
  if focus_finger>=0:
   cancel_focus_hold();return false
  if not popup_open or is_instance_valid(inspection_overlay) or view.host.menu_popup_open() or not focus_card.is_visible_in_tree() or not focus_card.get_global_rect().has_point(event.position):return false
  focus_finger=event.index;focus_hold_origin=event.position
  var id=focus_id;var generation=runtime.epoch
  focus_hold_ring=preload("res://scripts/card_hold_ring.gd").new()
  focus_hold_ring.position=event.position
  focus_hold_ring.valid=func():return not is_queued_for_deletion() and popup_open and focus_card.is_visible_in_tree() and runtime.epoch==generation and focus_id==id and focus_finger>=0 and not is_instance_valid(inspection_overlay) and not view.host.menu_popup_open()
  get_viewport().add_child(focus_hold_ring)
  focus_hold_ring.completed.connect(func():
   show_answer_details(id)
   inspection_art.texture=focus_card.texture)
 elif event.index!=focus_finger:return false
 elif event is InputEventScreenDrag:
  if event.position.distance_to(focus_hold_origin)>12:cancel_focus_hold()
 else:cancel_focus_hold()
 get_viewport().set_input_as_handled()
 return true

func _input(event: InputEvent):
 if view!=null and view.is_android:
  if focus_card_touch(event):return
  if popup_open:swipe_scroll.handle(event,inspection_overlay if is_instance_valid(inspection_overlay) else self)

func _draw():
 if runtime==null:return
 var targets=step.get("guide",{}).get("targets",[]).duplicate()
 for id in runtime.adapter.components:
  if runtime.adapter.components[id].get("highlight",false):targets.append({"component":id})
 for target in targets:
  if target.has("alias") and runtime.adapter.entity(target.alias).get("zone","") in ["field","palette","leader"]:continue
  var rect=target_rect(target)
  if not rect.has_area():continue
  rect.position-=global_position
  draw_rect(rect.grow(4),view.host.GOLD,false,3)
