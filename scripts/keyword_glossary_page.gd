extends Control
const KeywordGlossary=preload("res://scripts/keyword_glossary.gd")
var app
var margin: MarginContainer
var body: VBoxContainer
var heading: Label
var back_button: Button
var rows: VBoxContainer
var layout_pending=false
var wide=false

func _ready():
 name="KeywordGlossaryPage";set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 margin=MarginContainer.new();add_child(margin);margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 body=VBoxContainer.new();margin.add_child(body)
 var header=HBoxContainer.new();body.add_child(header)
 heading=Label.new();heading.text="词条百科";header.add_child(heading);heading.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 heading.add_theme_color_override("font_color",app.GOLD)
 back_button=app.button(header,"返回",Rect2(),app.tutorials);back_button.name="KeywordGlossaryBack"
 var scroll=ScrollContainer.new();scroll.name="KeywordGlossaryScroll";body.add_child(scroll)
 scroll.size_flags_horizontal=Control.SIZE_EXPAND_FILL;scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
 scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;scroll.set_meta("android_swipe_prefer_vertical",true)
 rows=VBoxContainer.new();rows.name="KeywordGlossaryList";scroll.add_child(rows);rows.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 resized.connect(queue_layout)
 refresh_metrics()

func refresh_metrics():
 for edge in ["left","right","top","bottom"]:margin.add_theme_constant_override("margin_"+edge,int(app.ui_metrics.padding))
 body.add_theme_constant_override("separation",int(app.ui_metrics.gap));body.get_child(0).add_theme_constant_override("separation",int(app.ui_metrics.gap))
 rows.add_theme_constant_override("separation",int(app.ui_metrics.gap))
 heading.add_theme_font_size_override("font_size",app.ui_metrics.title);app.ui_metrics.button(back_button)
 rebuild_list()

func queue_layout():
 if layout_pending:return
 layout_pending=true;call_deferred("relayout")

func relayout():
 layout_pending=false
 if wide!=(size.x>=720):rebuild_list()

func rebuild_list():
 wide=size.x>=720
 app.free_children(rows)
 var metrics=app.ui_metrics
 for category in KeywordGlossary.GROUPS:
  var title=Label.new();title.text=category;rows.add_child(title)
  title.add_theme_font_size_override("font_size",metrics.body+4);title.add_theme_color_override("font_color",app.GOLD)
  for item in KeywordGlossary.entries_in(category):
   var panel=PanelContainer.new();panel.name="KeywordEntry_"+item.id;rows.add_child(panel)
   panel.add_theme_stylebox_override("panel",metrics.panel_style())
   var row=HBoxContainer.new() if wide else VBoxContainer.new();panel.add_child(row)
   row.add_theme_constant_override("separation",int(metrics.gap))
   var term=Label.new();term.text=item.term;row.add_child(term)
   term.add_theme_font_size_override("font_size",metrics.body);term.add_theme_color_override("font_color",app.GOLD)
   term.vertical_alignment=VERTICAL_ALIGNMENT_TOP
   if wide:term.custom_minimum_size.x=term.get_theme_font("font").get_string_size("限制级符卡",HORIZONTAL_ALIGNMENT_LEFT,-1,metrics.body).x+metrics.padding
   KeywordGlossary.rich_text(app,row,item.definition,metrics.body,app.WHITE,item.id)

func _unhandled_key_input(event: InputEvent):
 if not event is InputEventKey or not event.pressed or event.echo:return
 if event.keycode in [KEY_ESCAPE,KEY_BACK]:
  get_viewport().set_input_as_handled();app.tutorials()
