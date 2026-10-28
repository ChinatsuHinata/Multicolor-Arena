extends Control
## Local saved-deck gallery shared by the editor, match setup and room lobbies.
const Store=preload("res://scripts/deck_store.gd")
const Search=preload("res://scripts/card_search_aliases.gd")
const Art=preload("res://scripts/card_art.gd")
const Library=preload("res://scripts/deck_library.gd")
var library=Library.new()
var app
var callback: Callable
var selected_id=""
var caption="选择套牌"
var empty_message="还没有保存的套牌。请先在组卡器保存。"
var show_favorites=true
var deck_filter: Callable
var previous_focus: WeakRef
var entries=[]
var matches=[]
var colors=[]
var search: LineEdit
var sort_choice: OptionButton
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
 library.load_data()
 sort_choice=OptionButton.new();sort_choice.name="DeckPickerSort";filters.add_child(sort_choice)
 for title in ["使用次数","名称","自机"]:sort_choice.add_item("排序："+title)
 sort_choice.select(Library.SORT_MODES.find(library.sort_mode));refresh_sort_metrics()
 sort_choice.item_selected.connect(change_sort)
 action(filters,"清除",reset_search).name="DeckPickerClear"
 color_row=HBoxContainer.new();body.add_child(color_row)
 var inks=[Color("#344553"),Color("#a83035"),Color("#337aa7"),Color("#39794d"),Color("#ac963b"),Color("#383a42")]
 var swatch_colors=["全部","红","蓝","绿","黄","黑"]
 for i in range(swatch_colors.size()):
  var color=swatch_colors[i]
  var button=action(color_row,color,func():toggle_color(color));button.name="DeckPickerColor_"+color
  button.add_theme_stylebox_override("normal",app.style(inks[i]))
  button.add_theme_stylebox_override("pressed",app.style(inks[i].lightened(0.18),app.GOLD))
  button.toggle_mode=true;button.set_pressed_no_signal(color=="全部")
 if not app.is_android:notice=text(color_row,"",app.ui_metrics.small,app.MUTED)
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
 reload_entries()
 gallery.resized.connect(queue_layout)
 queue_layout()
 if app.is_android:back.grab_focus()
 else:search.grab_focus()

func source_decks() -> Array:return app.decks

func reload_entries():
 entries.clear()
 for deck in source_decks():
  if deck_filter.is_valid() and not deck_filter.call(deck):continue
  var counts=Store.deck_color_counts(deck.main+deck.side+[deck.leader])
  entries.append({"deck":deck.duplicate(true),"colors":Search.COLORS.filter(func(color):return counts[color]>0)})
 apply_search()

func apply_search():
 var queries=[]
 for token in search.text.strip_edges().replace("，"," ").replace(","," ").split(" ",false):
  queries.append(Search.prepare_query(Store.CARDS,token,alias_rules))
 matches=entries.filter(func(entry):return colors.all(func(color):return color in entry.colors) and queries.all(func(query):return matches_term(entry,query)))
 sort_matches()
 page_index=0;render_tiles()

func sort_matches():
 matches.sort_custom(func(a,b):return library.comes_before(a.deck,b.deck))

func refresh_sort_metrics():
 app.ui_metrics.button(sort_choice)
 var caption_width=sort_choice.get_theme_font("font").get_string_size("排序：使用次数",HORIZONTAL_ALIGNMENT_LEFT,-1,app.ui_metrics.button_font).x
 sort_choice.custom_minimum_size.x=caption_width+app.ui_metrics.padding*3+sort_choice.get_theme_icon("arrow").get_width()

func change_sort(index: int):
 var error=library.set_sort(Library.SORT_MODES[index])
 sort_choice.select(Library.SORT_MODES.find(library.sort_mode))
 if not error.is_empty():app.alert(error,"排序保存失败");return
 sort_matches();page_index=0;render_tiles()

func toggle_favorite(id: String):
 var error=library.set_favorite(id,not library.favorite(id))
 if not error.is_empty():app.alert(error,"收藏保存失败");return
 sort_matches();page_index=0;render_tiles()
 var favorite_button=find_child("DeckPickerFavorite_"+id,true,false)
 if favorite_button!=null:favorite_button.grab_focus()
 else:sort_choice.grab_focus()

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
  if not button.has_meta("deck_id") and not button.has_meta("deck_favorite"):app.ui_metrics.button(button)
 refresh_sort_metrics()
 grid.add_theme_constant_override("h_separation",int(app.ui_metrics.gap))
 grid.add_theme_constant_override("v_separation",int(app.ui_metrics.gap))
 last_gallery_size=Vector2(-1,-1);queue_layout()

func relayout():
 layout_pending=false
 if not is_instance_valid(gallery) or gallery.size.y<1:return
 var columns=clampi(int((gallery.size.x+app.ui_metrics.gap)/(maxf(280,app.ui_metrics.hit*4.2)+app.ui_metrics.gap)),1,3)
 var rows=1 if app.is_android or gallery.size.y<560 else 2
 var next_size=columns*rows
 var next_compact=gallery.size.y/rows<app.ui_metrics.hit+app.ui_metrics.body*2+100
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
  text(grid,empty_message if entries.is_empty() else "没有符合条件的套牌，请调整或清除筛选。",app.ui_metrics.body,app.MUTED)
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
 var rows=maxi(1,int(page_size/maxi(1,grid.columns)))
 var tile_height=(gallery.size.y-app.ui_metrics.gap*(rows-1))/rows
 var title_font=maxi(14,mini(app.ui_metrics.body+4,floori(tile_height*0.16)))
 var margin=MarginContainer.new();tile.add_child(margin);margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 margin.mouse_filter=Control.MOUSE_FILTER_IGNORE
 for edge in ["left","right","top","bottom"]:margin.add_theme_constant_override("margin_"+edge,int(padding))
 var content=VBoxContainer.new();content.name="DeckPickerTileContent";margin.add_child(content)
 content.add_theme_constant_override("separation",6)
 content.mouse_filter=Control.MOUSE_FILTER_IGNORE
 var picture=TextureRect.new();picture.name="DeckPickerLeaderArt";content.add_child(picture);expand(picture,true)
 picture.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;picture.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
 picture.texture=app.deck_cover_texture(deck)
 picture.mouse_filter=Control.MOUSE_FILTER_IGNORE
 var title=text(content,("☁ %02d · " % int(deck.cloud_slot) if deck.has("cloud_slot") else "")+deck.name,title_font,app.GOLD);title.name="DeckPickerTitle"
 title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
 if not show_favorites:return tile
 var favorite_button=app.button(tile,"★" if library.favorite(str(deck.id)) else "☆",Rect2(),func():toggle_favorite(str(deck.id)),library.favorite(str(deck.id)))
 favorite_button.name="DeckPickerFavorite_"+str(deck.id);favorite_button.set_meta("deck_favorite",str(deck.id))
 favorite_button.tooltip_text="取消收藏" if library.favorite(str(deck.id)) else "收藏套牌"
 favorite_button.toggle_mode=true;favorite_button.set_pressed_no_signal(library.favorite(str(deck.id)))
 favorite_button.mouse_filter=Control.MOUSE_FILTER_STOP
 favorite_button.custom_minimum_size=Vector2(app.ui_metrics.hit,app.ui_metrics.hit)
 favorite_button.add_theme_font_size_override("font_size",maxi(24,app.ui_metrics.small))
 favorite_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
 favorite_button.offset_left=-app.ui_metrics.hit-padding;favorite_button.offset_right=-padding
 favorite_button.offset_top=padding;favorite_button.offset_bottom=padding+app.ui_metrics.hit
 return tile

func choose(id: String):
 var result=callback
 var index=-1
 for i in range(app.decks.size()):
  if str(app.decks[i].id)==id:index=i;break
 if index<0:return
 if deck_filter.is_valid() and not deck_filter.call(app.decks[index]):return
 app.close_deck_picker()
 if result.is_valid():result.call(index)

func handle_input(event: InputEvent):
 if event.is_action_pressed("ui_cancel") or event is InputEventKey and event.pressed and event.keycode==KEY_BACK:
  get_viewport().set_input_as_handled();app.close_deck_picker()

func _unhandled_input(_event: InputEvent):get_viewport().set_input_as_handled()
