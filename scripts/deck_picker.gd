extends Control
## Local saved-deck gallery shared by the editor, match setup and room lobbies.
const Store=preload("res://scripts/deck_store.gd")
const Search=preload("res://scripts/card_search_aliases.gd")
const Art=preload("res://scripts/card_art.gd")
var app
var callback: Callable
var selected_id=""
var caption="选择套牌"
var previous_focus: WeakRef
var entries=[]
var matches=[]
var colors=[]
var search: LineEdit
var grid: GridContainer
var gallery: Control
var notice: Label
var heading: Label
var margin: MarginContainer
var body: VBoxContainer
var page_label: Label
var previous_button: Button
var next_button: Button
var color_row: HBoxContainer
var color_toggle: Button
var page_index=0
var page_size=6
var compact=false
var layout_pending=false
var last_gallery_size=Vector2(-1,-1)
var alias_rules=Search.load_rules()

func expand(control: Control,vertical: bool=false):
 control.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 if vertical:control.size_flags_vertical=Control.SIZE_EXPAND_FILL

func text(parent: Node,value: String,font: int,color: Color) -> Label:
 var label=Label.new();parent.add_child(label);label.text=value
 label.add_theme_font_size_override("font_size",font);label.add_theme_color_override("font_color",color)
 label.clip_text=true;label.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
 label.mouse_filter=Control.MOUSE_FILTER_IGNORE;expand(label)
 return label

func action(parent: Node,value: String,fn: Callable) -> Button:
 var button=app.button(parent,value,Rect2(),fn);app.ui_metrics.button(button)
 return button

func _ready():
 name="DeckPicker";set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 mouse_filter=Control.MOUSE_FILTER_STOP
 var background=ColorRect.new();background.color=Color("#09121d");add_child(background)
 background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 margin=MarginContainer.new();add_child(margin);margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 for edge in ["left","right","top","bottom"]:margin.add_theme_constant_override("margin_"+edge,int(app.ui_metrics.padding))
 body=VBoxContainer.new();margin.add_child(body)
 body.add_theme_constant_override("separation",int(app.ui_metrics.gap))
 var header=HBoxContainer.new();body.add_child(header)
 heading=text(header,caption,app.ui_metrics.title,app.GOLD)
 if app.is_android:
  notice=text(header,"",app.ui_metrics.small,app.MUTED);notice.size_flags_horizontal=Control.SIZE_SHRINK_END
 var back=action(header,"返回",app.close_deck_picker);back.name="DeckPickerBack"
 var filters=HBoxContainer.new();body.add_child(filters)
 search=LineEdit.new();search.name="DeckPickerSearch";filters.add_child(search);expand(search)
 search.custom_minimum_size.y=app.ui_metrics.hit;search.clear_button_enabled=true
 search.placeholder_text="检索套牌名称 / 自机 / 卡牌名称或别名"
 search.text_changed.connect(func(_value):apply_search())
 action(filters,"清除",reset_search).name="DeckPickerClear"
 if app.is_android:
  color_toggle=action(filters,"颜色筛选",func():color_row.visible=not color_row.visible;queue_layout())
  color_toggle.name="DeckPickerColorToggle";color_toggle.toggle_mode=true
 color_row=HBoxContainer.new();body.add_child(color_row)
 var inks=[Color("#344553"),Color("#a83035"),Color("#337aa7"),Color("#39794d"),Color("#ac963b"),Color("#383a42")]
 var swatch_colors=["全部","红","蓝","绿","黄","黑"]
 for i in range(swatch_colors.size()):
  var color=swatch_colors[i]
  var button=action(color_row,color,func():toggle_color(color));button.name="DeckPickerColor_"+color
  button.add_theme_stylebox_override("normal",app.style(inks[i]))
  button.add_theme_stylebox_override("pressed",app.style(inks[i].lightened(0.18),app.GOLD))
  button.toggle_mode=true;button.set_pressed_no_signal(color=="全部")
 if app.is_android:color_row.hide()
 else:notice=text(color_row,"",app.ui_metrics.small,app.MUTED)
 notice.name="DeckPickerNotice"
 gallery=Control.new();body.add_child(gallery);expand(gallery,true)
 grid=GridContainer.new();grid.name="DeckPickerGrid";gallery.add_child(grid)
 grid.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 grid.add_theme_constant_override("h_separation",int(app.ui_metrics.gap))
 grid.add_theme_constant_override("v_separation",int(app.ui_metrics.gap))
 var pagination=HBoxContainer.new();body.add_child(pagination)
 previous_button=action(pagination,"上一页",func():turn_page(-1));previous_button.name="DeckPickerPrevious"
 page_label=text(pagination,"",app.ui_metrics.small,app.MUTED);page_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
 next_button=action(pagination,"下一页",func():turn_page(1));next_button.name="DeckPickerNext"
 for deck in app.decks:
  var counts=Store.deck_color_counts(deck.main+deck.side+[deck.leader])
  entries.append({"deck":deck.duplicate(true),"colors":Search.COLORS.filter(func(color):return counts[color]>0)})
 gallery.resized.connect(queue_layout)
 apply_search();queue_layout()
 if app.is_android:back.grab_focus()
 else:search.grab_focus()

func apply_search():
 var queries=[]
 for token in search.text.strip_edges().replace("，"," ").replace(","," ").split(" ",false):
  queries.append(Search.prepare_query(Store.CARDS,token,alias_rules))
 matches=entries.filter(func(entry):return colors.all(func(color):return color in entry.colors) and queries.all(func(query):return matches_term(entry,query)))
 page_index=0;render_tiles()

func matches_term(entry: Dictionary,query: Dictionary) -> bool:
 if query.term in str(entry.deck.name).to_lower():return true
 var wanted=query.term.trim_suffix("色")
 if not wanted.is_empty() and Array(wanted.split("")).all(func(color):return color in Search.COLORS):
  return Array(wanted.split("")).all(func(color):return color in entry.colors)
 for id in entry.deck.main+entry.deck.side+[entry.deck.leader]:
  if Store.CARDS.has(id) and Search.matches_query(Store.CARDS[id],id,query):return true
 return false

func toggle_color(color: String):
 if color=="全部":colors.clear()
 elif color in colors:colors.erase(color)
 else:colors.append(color)
 update_swatches();apply_search()

func update_swatches():
 if color_toggle!=null:color_toggle.text="颜色筛选"+("（%d）" % colors.size() if not colors.is_empty() else "")
 for color in ["全部","红","蓝","绿","黄","黑"]:
  var button=find_child("DeckPickerColor_"+color,true,false) as Button
  button.set_pressed_no_signal(colors.is_empty() if color=="全部" else color in colors)

func reset_search():
 search.text="";colors.clear();update_swatches();apply_search()

func pages() -> int:return maxi(1,ceili(float(matches.size())/page_size))

func turn_page(direction: int):
 page_index=clampi(page_index+direction,0,pages()-1);render_tiles()

func queue_layout():
 if layout_pending:return
 layout_pending=true;call_deferred("relayout")

func refresh_metrics():
 for edge in ["left","right","top","bottom"]:margin.add_theme_constant_override("margin_"+edge,int(app.ui_metrics.padding))
 body.add_theme_constant_override("separation",int(app.ui_metrics.gap))
 heading.add_theme_font_size_override("font_size",app.ui_metrics.title)
 notice.add_theme_font_size_override("font_size",app.ui_metrics.small)
 page_label.add_theme_font_size_override("font_size",app.ui_metrics.small)
 search.custom_minimum_size.y=app.ui_metrics.hit
 for button in find_children("*","Button",true,false):
  if not button.has_meta("deck_id"):app.ui_metrics.button(button)
 grid.add_theme_constant_override("h_separation",int(app.ui_metrics.gap))
 grid.add_theme_constant_override("v_separation",int(app.ui_metrics.gap))
 last_gallery_size=Vector2(-1,-1);queue_layout()

func relayout():
 layout_pending=false
 if not is_instance_valid(gallery) or gallery.size.y<1:return
 var columns=clampi(int((gallery.size.x+app.ui_metrics.gap)/(maxf(280,app.ui_metrics.hit*4.2)+app.ui_metrics.gap)),1,3)
 var rows=1 if app.is_android or gallery.size.y<560 else 2
 var next_size=columns*rows
 var next_compact=gallery.size.y/rows<app.ui_metrics.hit+app.ui_metrics.small*5+100
 if next_size!=page_size or grid.columns!=columns or compact!=next_compact or not last_gallery_size.is_equal_approx(gallery.size):
  var offset=page_index*page_size
  page_size=next_size;grid.columns=columns;compact=next_compact
  last_gallery_size=gallery.size
  page_index=mini(int(offset/page_size),pages()-1);render_tiles()

func render_tiles():
 app.free_children(grid)
 notice.text="共 %d 套" % matches.size()
 if app.is_android:notice.custom_minimum_size.x=notice.get_theme_font("font").get_string_size(notice.text,HORIZONTAL_ALIGNMENT_LEFT,-1,app.ui_metrics.small).x
 if matches.is_empty():
  text(grid,"还没有保存的套牌。请先在组卡器保存。" if entries.is_empty() else "没有符合条件的套牌，请调整或清除筛选。",app.ui_metrics.body,app.MUTED)
 var page_entries=matches.slice(page_index*page_size,mini(matches.size(),(page_index+1)*page_size))
 var tile_minimum_size=Vector2.ZERO
 for entry in page_entries:
  var tile=make_tile(entry)
  tile_minimum_size=tile_minimum_size.max(tile.get_combined_minimum_size())
 # Keep the full page footprint so sparse pages use the same tile sizes.
 if not page_entries.is_empty():
  for i in range(page_size-page_entries.size()):
   var placeholder=Control.new();grid.add_child(placeholder);expand(placeholder,true)
   placeholder.custom_minimum_size=tile_minimum_size
   placeholder.mouse_filter=Control.MOUSE_FILTER_IGNORE
 page_label.text="第 %d / %d 页" % [page_index+1,pages()]
 previous_button.disabled=page_index==0;next_button.disabled=page_index>=pages()-1
 var controls=focus_controls(self)
 for i in range(controls.size()):
  var previous=controls[i].get_path_to(controls[(i-1+controls.size())%controls.size()])
  var next=controls[i].get_path_to(controls[(i+1)%controls.size()])
  controls[i].focus_previous=previous;controls[i].focus_next=next
  controls[i].focus_neighbor_top=previous;controls[i].focus_neighbor_bottom=next
  controls[i].focus_neighbor_left=previous;controls[i].focus_neighbor_right=next

func focus_controls(node: Node) -> Array:
 var result=[]
 if node is CanvasItem and not node.is_visible_in_tree():return result
 if node is Control and node.focus_mode!=Control.FOCUS_NONE and (not node is BaseButton or not node.disabled):result.append(node)
 for child in node.get_children():result.append_array(focus_controls(child))
 return result

func make_tile(entry: Dictionary) -> Button:
 var deck=entry.deck
 var tile=app.button(grid,"",Rect2(),func():choose(str(deck.id)),deck.id==selected_id)
 tile.name="DeckPickerTile_"+str(deck.id);tile.set_meta("deck_id",str(deck.id));expand(tile,true)
 tile.tooltip_text=deck.name;tile.custom_minimum_size.x=0
 var padding=minf(10,app.ui_metrics.padding*0.5) if compact else app.ui_metrics.padding
 var tile_height=gallery.size.y/(float(page_size)/maxi(1,grid.columns))
 var font_scale=minf(1.0,maxf(1,tile_height-padding*2-16)/((app.ui_metrics.body+4+app.ui_metrics.small*4)*1.4)) if compact else 1.0
 var title_font=maxi(1,floori((app.ui_metrics.body+4)*font_scale))
 var detail_font=maxi(1,floori(app.ui_metrics.small*font_scale))
 var margin=MarginContainer.new();tile.add_child(margin);margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 margin.mouse_filter=Control.MOUSE_FILTER_IGNORE
 for edge in ["left","right","top","bottom"]:margin.add_theme_constant_override("margin_"+edge,int(padding))
 var content=HBoxContainer.new() if compact else VBoxContainer.new();margin.add_child(content)
 content.mouse_filter=Control.MOUSE_FILTER_IGNORE
 var picture=TextureRect.new();picture.name="DeckPickerLeaderArt";content.add_child(picture);expand(picture,true)
 picture.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;picture.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
 picture.texture=app.texture(deck.leader,Art.selected(deck,deck.leader,Store.CARDS)) if Store.CARDS.has(deck.leader) else null
 picture.mouse_filter=Control.MOUSE_FILTER_IGNORE
 if compact:picture.size_flags_stretch_ratio=0.65
 var info=VBoxContainer.new();content.add_child(info);expand(info);info.mouse_filter=Control.MOUSE_FILTER_IGNORE
 if compact:info.size_flags_vertical=Control.SIZE_SHRINK_CENTER;info.add_theme_constant_override("separation",4)
 text(info,deck.name,title_font,app.GOLD)
 text(info,"自机："+str(Store.CARDS.get(deck.leader,{}).get("name","未设置")),detail_font,app.WHITE)
 text(info,"主卡组 %d · 副卡组 %d" % [deck.main.size(),deck.side.size()],detail_font,app.MUTED)
 text(info,"颜色："+(" / ".join(entry.colors) if not entry.colors.is_empty() else "无色"),detail_font,app.MUTED)
 text(info,Store.RuleSet.label_for(str(deck.get("rule_set",Store.RuleSet.OFFICIAL)))+" · "+("当前选择" if deck.id==selected_id else "点击选择"),detail_font,app.GOLD if deck.id==selected_id else app.MUTED)
 return tile

func choose(id: String):
 var result=callback
 var index=-1
 for i in range(app.decks.size()):
  if str(app.decks[i].id)==id:index=i;break
 if index<0:return
 app.close_deck_picker()
 if result.is_valid():result.call(index)

func handle_input(event: InputEvent):
 if event.is_action_pressed("ui_cancel") or event is InputEventKey and event.pressed and event.keycode==KEY_BACK:
  get_viewport().set_input_as_handled();app.close_deck_picker()

func _unhandled_input(_event: InputEvent):get_viewport().set_input_as_handled()
