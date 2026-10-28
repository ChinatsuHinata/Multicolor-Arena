extends CanvasLayer
var app
var glossary
var panel: PanelContainer
var scroll: ScrollContainer
var body: VBoxContainer
var term: Label
var group: Label
var definition: RichTextLabel
var close_button: Button
var layout_pending=false
var swipe=preload("res://scripts/android_swipe_scroll.gd").new()

func _ready():
 # One above ModalMenu.TOP_LAYER so definitions open over task and shop menus.
 name="KeywordDefinitionPopup";layer=preload("res://scripts/modal_menu.gd").TOP_LAYER+1
 var backdrop=Control.new();backdrop.theme=app.theme;add_child(backdrop);backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 var shade=ColorRect.new();backdrop.add_child(shade);shade.color=Color(0,0,0,0.6);shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 shade.gui_input.connect(func(event):
  if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.pressed or event is InputEventScreenTouch and not event.pressed:close())
 panel=PanelContainer.new();panel.name="KeywordDefinitionPanel";backdrop.add_child(panel);panel.mouse_filter=Control.MOUSE_FILTER_STOP
 scroll=ScrollContainer.new();panel.add_child(scroll);scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
 scroll.set_meta("android_swipe_prefer_vertical",true)
 body=VBoxContainer.new();scroll.add_child(body);body.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 var header=HBoxContainer.new();body.add_child(header)
 term=Label.new();term.name="KeywordDefinitionTerm";header.add_child(term);term.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 close_button=app.button(header,"关闭",Rect2(),close);close_button.name="KeywordDefinitionClose"
 group=Label.new();group.name="KeywordDefinitionGroup";body.add_child(group)
 definition=glossary.rich_text(app,body,"",app.ui_metrics.body,app.WHITE);definition.name="KeywordDefinitionText"
 body.minimum_size_changed.connect(queue_layout)
 get_viewport().size_changed.connect(queue_layout)

func show_entry(id: String):
 var item=glossary.entry(id)
 term.text=item.term;group.text=item.group
 definition.clear();definition.set_meta("keyword_exclude_id",id);glossary.append(definition,item.definition,app.GOLD)
 scroll.scroll_vertical=0
 queue_layout()

func queue_layout():
 if layout_pending:return
 layout_pending=true;call_deferred("relayout")

func relayout():
 layout_pending=false
 var metrics=app.ui_metrics;var safe=metrics.safe
 panel.add_theme_stylebox_override("panel",metrics.panel_style())
 body.add_theme_constant_override("separation",int(metrics.gap));term.get_parent().add_theme_constant_override("separation",int(metrics.gap))
 term.add_theme_font_size_override("font_size",metrics.title);term.add_theme_color_override("font_color",app.GOLD)
 group.add_theme_font_size_override("font_size",metrics.small);group.add_theme_color_override("font_color",app.MUTED)
 definition.add_theme_font_size_override("normal_font_size",metrics.body);app.ui_metrics.button(close_button)
 var width=minf(1100 if app.is_android else 720,safe.size.x-metrics.padding*2)
 var height=minf(body.get_combined_minimum_size().y+panel.get_theme_stylebox("panel").get_minimum_size().y,safe.size.y*0.7)
 panel.size=Vector2(width,height);panel.position=safe.position+(safe.size-panel.size)*0.5

func _input(event: InputEvent):
 if event.is_action_pressed("ui_cancel") or event is InputEventKey and event.pressed and event.keycode==KEY_BACK:
  get_viewport().set_input_as_handled();close();return
 if app.is_android:swipe.handle(event,get_child(0))

func _unhandled_input(_event: InputEvent):
 get_viewport().set_input_as_handled()

func close():
 glossary.close_definition()

func _exit_tree():
 if glossary.current==self:glossary.current=null
