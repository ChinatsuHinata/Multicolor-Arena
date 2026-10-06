extends Control
## Configured lessons. Completion is keyed by stable lesson IDs.
var app
var margin: MarginContainer
var body: VBoxContainer
var heading: Label
var list_area: Control
var rows: VBoxContainer
var empty: Label
var navigation: VBoxContainer
var page_label: Label
var previous_button: Button
var next_button: Button
const CATEGORIES={"beginner":"新手教程","advanced":"进阶教程","leader":"自机教程"}
var category="beginner"
var categories: VBoxContainer
var category_buttons: Dictionary={}
var page_index=0
var page_size=1
var layout_pending=false

func action(parent: Node,caption: String,callback: Callable) -> Button:
 var button=app.button(parent,caption,Rect2(),callback)
 app.ui_metrics.button(button)
 return button

func _ready():
 name="TutorialList";set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 margin=MarginContainer.new();add_child(margin);margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 body=VBoxContainer.new();margin.add_child(body)
 var header=HBoxContainer.new();body.add_child(header)
 heading=Label.new();heading.text="游戏教程";header.add_child(heading)
 heading.size_flags_horizontal=Control.SIZE_EXPAND_FILL;heading.add_theme_color_override("font_color",app.GOLD)
 if app.tutorial_editor_available():action(header,"教程编辑器",app.tutorial_editor).name="OpenTutorialEditor"
 action(header,"返回",app.menu).name="TutorialBack"
 var content=HBoxContainer.new();body.add_child(content);content.size_flags_vertical=Control.SIZE_EXPAND_FILL
 categories=VBoxContainer.new();categories.name="TutorialCategories";content.add_child(categories)
 var group=ButtonGroup.new()
 for id in CATEGORIES:
  var button=action(categories,CATEGORIES[id],func():select_category(id))
  button.name="TutorialCategory"+id.capitalize();button.toggle_mode=true;button.button_group=group
  button.size_flags_vertical=Control.SIZE_EXPAND_FILL;category_buttons[id]=button
 category_buttons[category].set_pressed_no_signal(true)
 var panel=PanelContainer.new();content.add_child(panel);panel.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 panel.add_theme_stylebox_override("panel",app.ui_metrics.panel_style())
 list_area=Control.new();panel.add_child(list_area)
 rows=VBoxContainer.new();rows.name="TutorialRows";list_area.add_child(rows)
 rows.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 empty=Label.new();empty.name="TutorialEmpty";empty.text="暂无教程";list_area.add_child(empty)
 empty.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 empty.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;empty.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
 empty.add_theme_color_override("font_color",app.MUTED);empty.mouse_filter=Control.MOUSE_FILTER_IGNORE
 navigation=VBoxContainer.new();content.add_child(navigation)
 navigation.size_flags_vertical=Control.SIZE_SHRINK_CENTER
 previous_button=action(navigation,"↑ 上一页",func():turn_page(-1));previous_button.name="TutorialPrevious"
 page_label=Label.new();page_label.name="TutorialPage";navigation.add_child(page_label)
 page_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;page_label.add_theme_color_override("font_color",app.MUTED)
 next_button=action(navigation,"↓ 下一页",func():turn_page(1));next_button.name="TutorialNext"
 list_area.resized.connect(queue_layout)
 refresh_metrics();render_rows()

func refresh_metrics():
 for edge in ["left","right","top","bottom"]:
  margin.add_theme_constant_override("margin_"+edge,int(app.ui_metrics.padding))
 body.add_theme_constant_override("separation",int(app.ui_metrics.gap))
 body.get_child(1).add_theme_constant_override("separation",int(app.ui_metrics.gap))
 rows.add_theme_constant_override("separation",int(app.ui_metrics.gap))
 navigation.add_theme_constant_override("separation",int(app.ui_metrics.gap))
 categories.add_theme_constant_override("separation",int(app.ui_metrics.gap))
 for button in category_buttons.values():app.ui_metrics.button(button)
 heading.add_theme_font_size_override("font_size",app.ui_metrics.title)
 empty.add_theme_font_size_override("font_size",app.ui_metrics.body)
 page_label.add_theme_font_size_override("font_size",app.ui_metrics.small)
 for button in [previous_button,next_button,find_child("TutorialBack",true,false)]:app.ui_metrics.button(button)
 queue_layout()

func pages() -> int:
 return maxi(1,ceili(float(filtered_entries().size())/page_size))

func filtered_entries() -> Array:
 return app.tutorial_entries.filter(func(entry):return entry.get("category","beginner")==category)

func select_category(id: String):
 if not CATEGORIES.has(id):return
 category=id;page_index=0
 category_buttons[id].set_pressed_no_signal(true)
 render_rows()

func turn_page(direction: int):
 page_index=clampi(page_index+direction,0,pages()-1)
 render_rows()

func queue_layout():
 if layout_pending:return
 layout_pending=true;call_deferred("relayout")

func relayout():
 layout_pending=false
 if not is_instance_valid(list_area) or list_area.size.y<1:return
 var offset=page_index*page_size
 page_size=maxi(1,floori((list_area.size.y+app.ui_metrics.gap)/(app.ui_metrics.hit+app.ui_metrics.gap)))
 page_index=clampi(int(offset/page_size),0,pages()-1)
 render_rows()

func render_rows():
 app.free_children(rows)
 var entries=filtered_entries()
 page_index=clampi(page_index,0,pages()-1)
 empty.visible=entries.is_empty();empty.text="暂无"+CATEGORIES[category]
 for entry in entries.slice(page_index*page_size,mini(entries.size(),(page_index+1)*page_size)):
  var id=str(entry.get("id",""))
  var row=HBoxContainer.new();row.set_meta("tutorial_id",id);rows.add_child(row)
  row.add_theme_constant_override("separation",int(app.ui_metrics.gap))
  var callback: Callable=entry.get("start",Callable())
  var button=action(row,str(entry.get("title","")),func():
   if callback.is_valid():callback.call())
  button.size_flags_horizontal=Control.SIZE_EXPAND_FILL;button.custom_minimum_size.x=0
  button.disabled=not callback.is_valid()
  if entry.has("path") and app.tutorial_editor_available():
   var edit_path=str(entry.path)
   action(row,"编辑",func():app.tutorial_editor(edit_path)).name="EditTutorial"+id
  var completion=Label.new();completion.name="TutorialCompletion";row.add_child(completion)
  completion.text="已完成" if app.tutorial_completed(id) else ""
  completion.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
  completion.add_theme_font_size_override("font_size",app.ui_metrics.body)
  completion.add_theme_color_override("font_color",app.GOLD)
  completion.custom_minimum_size.x=completion.get_theme_font("font").get_string_size("已完成",HORIZONTAL_ALIGNMENT_LEFT,-1,app.ui_metrics.body).x+app.ui_metrics.padding
 page_label.text="第 %d / %d 页" % [page_index+1,pages()]
 previous_button.disabled=entries.is_empty() or page_index==0
 next_button.disabled=entries.is_empty() or page_index>=pages()-1

func _unhandled_key_input(event: InputEvent):
 if not event is InputEventKey or not event.pressed or event.echo:return
 if event.keycode in [KEY_ESCAPE,KEY_BACK]:app.menu()
 elif event.keycode in [KEY_PAGEUP,KEY_UP]:turn_page(-1)
 elif event.keycode in [KEY_PAGEDOWN,KEY_DOWN]:turn_page(1)
 else:return
 get_viewport().set_input_as_handled()
