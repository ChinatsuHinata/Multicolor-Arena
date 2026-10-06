extends Control
## A course opens here before any step is marked read.
var app
var course: Dictionary={}
var path=""
var margin: MarginContainer
var body: VBoxContainer
var heading: Label
var summary: Label
var scroll: ScrollContainer
var row_insets: MarginContainer
var rows: VBoxContainer
var continue_button: Button
var buttons: Array=[]
var step_buttons: Dictionary={}

func action(parent: Node,caption: String,callback: Callable) -> Button:
 var button=app.button(parent,caption,Rect2(),callback)
 app.ui_metrics.button(button);buttons.append(button)
 return button

func _ready():
 name="TutorialDirectory";set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 margin=MarginContainer.new();add_child(margin);margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 body=VBoxContainer.new();margin.add_child(body)
 var header=HBoxContainer.new();body.add_child(header)
 heading=Label.new();heading.text=course.title+" · 教程目录";header.add_child(heading)
 heading.size_flags_horizontal=Control.SIZE_EXPAND_FILL;heading.clip_text=true;heading.tooltip_text=heading.text
 heading.add_theme_color_override("font_color",app.GOLD)
 action(header,"返回教程列表",app.tutorials).name="TutorialDirectoryBack"
 summary=Label.new();body.add_child(summary);summary.add_theme_color_override("font_color",app.MUTED)
 summary.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 var panel=PanelContainer.new();body.add_child(panel);panel.size_flags_vertical=Control.SIZE_EXPAND_FILL
 panel.add_theme_stylebox_override("panel",app.ui_metrics.panel_style())
 scroll=ScrollContainer.new();panel.add_child(scroll);scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
 row_insets=MarginContainer.new();scroll.add_child(row_insets);row_insets.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 rows=VBoxContainer.new();row_insets.add_child(rows);rows.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 var ids=app.tutorial_progress.ordered_steps(course)
 for i in range(ids.size()):
  var id=str(ids[i]);var step=course.steps[id]
  var row=HBoxContainer.new();row.set_meta("step_id",id);rows.add_child(row)
  var text=preview(step.guide.text)
  var button=action(row,"%d. %s" % [i+1,text],func():app.begin_tutorial(path,id))
  button.name="TutorialDirectoryStep"+id;button.size_flags_horizontal=Control.SIZE_EXPAND_FILL;button.custom_minimum_size.x=0
  button.disabled=not app.tutorial_progress.can_open(course,id);button.tooltip_text=step.guide.text
  step_buttons[id]=button
  var status=Label.new();status.name="TutorialReadStatus";row.add_child(status)
  status.text="已读" if app.tutorial_progress.has_read(course,id) else "未读" if id==course.start_step else "未解锁"
  status.add_theme_color_override("font_color",app.GOLD if status.text=="已读" else app.MUTED)
  status.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
 var footer=HBoxContainer.new();body.add_child(footer)
 continue_button=action(footer,"继续阅读" if not app.tutorial_progress.record(course).read.is_empty() else "开始阅读",func():app.begin_tutorial(path,app.tutorial_progress.latest_step(course)))
 continue_button.name="TutorialDirectoryContinue";continue_button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 var restart=action(footer,"从头阅读",func():app.begin_tutorial(path,course.start_step))
 restart.name="TutorialDirectoryRestart";restart.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 summary.text="已读 %d / %d 步 · 可跳转至上次读到的步骤，后续步骤随阅读解锁。" % [app.tutorial_progress.record(course).read.size(),ids.size()]
 refresh_metrics()

func preview(value: String) -> String:
 var expression=RegEx.new();expression.compile("\\[[^\\]]*\\]")
 var text=expression.sub(value,"",true).replace("\r"," ").replace("\n"," ").strip_edges()
 return text.left(48)+("…" if text.length()>48 else "")

func refresh_metrics():
 var metrics=app.ui_metrics
 for edge in ["left","right","top","bottom"]:margin.add_theme_constant_override("margin_"+edge,int(metrics.padding))
 body.add_theme_constant_override("separation",int(metrics.gap));rows.add_theme_constant_override("separation",int(metrics.gap))
 row_insets.add_theme_constant_override("margin_right",int(metrics.gap))
 heading.add_theme_font_size_override("font_size",metrics.title);summary.add_theme_font_size_override("font_size",metrics.small)
 for button in buttons:
  metrics.button(button)
  if button in step_buttons.values():button.custom_minimum_size.x=0
 for row in rows.get_children():
  row.add_theme_constant_override("separation",int(metrics.gap))
  row.get_node("TutorialReadStatus").add_theme_font_size_override("font_size",metrics.body)

func _unhandled_key_input(event: InputEvent):
 if event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_ESCAPE,KEY_BACK]:
  app.tutorials();get_viewport().set_input_as_handled()
