extends Control
## Responsive card search. The caller owns the selected entry's action.
signal selected(entry: Dictionary)

const SearchAliases = preload("res://scripts/card_search_aliases.gd")
const CostDisplay = preload("res://scripts/card_cost_display.gd")
const GOLD = Color("#d9b775")
const WHITE = Color("#e8edf0")
const MUTED = Color("#91a5b7")
const KINDS = SearchAliases.FILTER_KINDS
const SORT_MODES = ["类别", "颜色值", "名字"]
const COLORS = ["全部", "红", "蓝", "绿", "黄", "黑"]
const SWATCHES = [Color("#344553"), Color("#a83035"), Color("#337aa7"), Color("#39794d"), Color("#ac963b"), Color("#383a42")]

var layout_metrics
var cards: Dictionary = {}
var entries: Array = []
var selected_entry: Dictionary = {}
var texture_provider: Callable
var show_filter_controls = true
var search_input: LineEdit
var search_results: VBoxContainer
var selected_card: Panel
var preview_card: Control
var result_count: Label
var color_buttons: Dictionary = {}
var query = ""
var filter_kind = "全部"
var sort_mode = "类别"
var selected_colors: Array = []
var preview_id = ""
var alias_rules: Dictionary = {}

func configure(card_database: Dictionary, choices: Array, card_texture_provider: Callable = Callable()):
 cards = card_database
 entries = choices
 texture_provider = card_texture_provider
 selected_entry = {}
 preview_id = ""
 alias_rules = SearchAliases.load_rules()
 if is_node_ready():
  update_results()
  update_preview()
  update_selected_card()

func _ready():
 if layout_metrics==null:
  layout_metrics=preload("res://scripts/ui_layout.gd").new();layout_metrics.measure(self,OS.has_feature("android"))
 mouse_filter=Control.MOUSE_FILTER_STOP
 alias_rules=SearchAliases.load_rules()
 var root=HBoxContainer.new();add_child(root);root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 var left=VBoxContainer.new();root.add_child(left);left.size_flags_horizontal=Control.SIZE_EXPAND_FILL;left.size_flags_stretch_ratio=0.8
 selected_card=Panel.new();selected_card.name="SelectedCard";left.add_child(selected_card)
 selected_card.custom_minimum_size.y=layout_metrics.body*3
 selected_card.add_theme_stylebox_override("panel",layout_metrics.panel_style())
 preview_card=VBoxContainer.new();preview_card.name="CardPreview";left.add_child(preview_card);preview_card.size_flags_vertical=Control.SIZE_EXPAND_FILL
 var right=VBoxContainer.new();root.add_child(right);right.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 right.custom_minimum_size.x=layout_metrics.hit*6+layout_metrics.gap*5
 search_input=LineEdit.new();search_input.name="SearchInput";search_input.placeholder_text="搜索名称 / 描述 / 编号 / 颜色 / 类别";search_input.text=query
 search_input.custom_minimum_size.y=layout_metrics.hit;right.add_child(search_input)
 search_input.text_changed.connect(func(value):query=value;update_results())
 if show_filter_controls:
  var colors=HBoxContainer.new();right.add_child(colors)
  for i in range(COLORS.size()):
   var color=COLORS[i]
   var choice=_button(color,Rect2(),SWATCHES[i]);choice.reparent(colors);layout_metrics.button(choice);choice.size_flags_horizontal=Control.SIZE_EXPAND_FILL
   choice.toggle_mode=true;choice.pressed.connect(func():toggle_color(color));color_buttons[color]=choice
  _refresh_color_buttons()
  var filters=HBoxContainer.new();right.add_child(filters)
  var kind=OptionButton.new();kind.name="KindFilter";filters.add_child(kind);layout_metrics.button(kind);kind.size_flags_horizontal=Control.SIZE_EXPAND_FILL
  var kinds=SearchAliases.ANDROID_FILTER_KINDS if layout_metrics.touch else KINDS
  for value in kinds:kind.add_item(value)
  kind.item_selected.connect(func(index):filter_kind=kinds[index];update_results())
  var order=OptionButton.new();order.name="SortChoice";filters.add_child(order);layout_metrics.button(order);order.size_flags_horizontal=Control.SIZE_EXPAND_FILL
  for mode in SORT_MODES:order.add_item("排序："+mode)
  order.item_selected.connect(func(index):sort_mode=SORT_MODES[index];update_results())
 result_count=_label(right,"",Rect2(),layout_metrics.small,MUTED)
 var scroll=ScrollContainer.new();scroll.name="SearchScroll";right.add_child(scroll);scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
 scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
 search_results=VBoxContainer.new();search_results.name="SearchResults";search_results.size_flags_horizontal=Control.SIZE_EXPAND_FILL;scroll.add_child(search_results)
 update_preview();update_selected_card();update_results()

func _style(color: Color, border: Color = Color("#3d5161")) -> StyleBoxFlat:
 var value = StyleBoxFlat.new()
 value.bg_color = color
 value.border_color = border
 value.set_border_width_all(1)
 value.set_corner_radius_all(10)
 value.content_margin_left = 12
 value.content_margin_right = 12
 value.content_margin_top = 7
 value.content_margin_bottom = 7
 return value

func _panel(rect: Rect2, color: Color = Color("#101c28")) -> Panel:
 var panel = Panel.new()
 panel.position = rect.position
 panel.size = rect.size
 panel.add_theme_stylebox_override("panel",_style(color))
 add_child(panel)
 return panel

func _label(parent: Node, value: String, rect: Rect2, font_size: int = 18, color: Color = WHITE) -> Label:
 var text = Label.new()
 text.text = value
 text.position = rect.position
 text.size = rect.size
 text.add_theme_font_size_override("font_size",font_size)
 text.add_theme_color_override("font_color",color)
 text.mouse_filter = Control.MOUSE_FILTER_IGNORE
 parent.add_child(text)
 return text

func _button(value: String, rect: Rect2, color: Color) -> Button:
 var result = Button.new()
 result.text = value
 result.position = rect.position
 result.size = rect.size
 result.add_theme_stylebox_override("normal",_style(color))
 result.add_theme_stylebox_override("hover",_style(color.lightened(0.15),GOLD))
 result.add_theme_stylebox_override("pressed",_style(color,GOLD))
 result.add_theme_stylebox_override("focus",_style(Color(0,0,0,0),GOLD))
 result.add_theme_color_override("font_color",WHITE)
 result.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
 add_child(result)
 return result

func _clear(parent: Node):
 for child in parent.get_children():
  parent.remove_child(child)
  child.queue_free()

func toggle_color(color: String):
 if color=="全部":selected_colors.clear()
 elif color in selected_colors:selected_colors.erase(color)
 else:selected_colors.append(color)
 _refresh_color_buttons()
 update_results()

func _refresh_color_buttons():
 for color in color_buttons:
  var active = selected_colors.is_empty() if color=="全部" else color in selected_colors
  color_buttons[color].set_pressed_no_signal(active)
  color_buttons[color].text = ("✓" if active and color!="全部" else "")+color

func _matches_colors(info: Dictionary) -> bool:
 if selected_colors.is_empty():return true
 var colors: Array = info.get("colors",[])
 return colors.size()==selected_colors.size() and colors.all(func(color):return color in selected_colors)

func _races() -> Array:
 var found = {}
 for info in cards.values():
  if not info is Dictionary:continue
  for race in info.get("race",[]):found[race]=true
 var result = found.keys()
 result.sort_custom(func(a,b):return a.length()>b.length() if a.length()!=b.length() else a.naturalnocasecmp_to(b)<0)
 return result

func _query_filters(term: String) -> Dictionary:
 var remaining = term.strip_edges().to_lower().replace(" ","").replace("\t","").replace("\n","")
 var single = remaining.begins_with("单") and remaining!="单位"
 if single:remaining=remaining.substr(1)
 var kind = ""
 for suffix in SearchAliases.ANDROID_KINDS if layout_metrics.touch else SearchAliases.KINDS:
  if remaining.ends_with(suffix):
   kind=suffix
   remaining=remaining.substr(0,remaining.length()-suffix.length())
   break
 var race = ""
 for race_name in _races():
  if remaining.ends_with(race_name):
   race=race_name
   remaining=remaining.substr(0,remaining.length()-race_name.length())
   break
 var colors = []
 for index in range(remaining.length()):
  var color = remaining.substr(index,1)
  if color not in SearchAliases.COLORS:return {}
  if color not in colors:colors.append(color)
 if colors.is_empty() and kind.is_empty() and race.is_empty() and not single:return {}
 return {"kind":kind,"race":race,"colors":colors,"single":single}

func _race_characters(race: String) -> Array:
 if race.is_empty():return []
 var found = []
 for info in cards.values():
  if not info is Dictionary:continue
  if race in info.get("race",[]):
   var character = str(info.get("character",""))
   if not character.is_empty() and character not in found:found.append(character)
 return found

func _related_to_race(info: Dictionary, race: String, characters: Array) -> bool:
 if race.is_empty() or info.get("kind","") not in ["符卡","道具","结界"]:return false
 if race in str(info.get("name","")) or race in str(info.get("rules_text","")):return true
 var character = str(info.get("requires_character",""))
 if character.is_empty():character=str(info.get("character",""))
 if character.is_empty():return false
 return characters.any(func(candidate):return character in candidate or candidate in character)

func _matches_query(id: String, info: Dictionary, prepared: Dictionary, filters: Dictionary, race_characters: Array) -> bool:
 var term = query.strip_edges().to_lower()
 if term.is_empty():return true
 if term=="衍生物":return info.get("token",false)
 if term=="梦违":return not info.get("constructible",false) and not info.get("token",false) and ("梦违" in str(info.get("name","")) or "梦违" in str(info.get("rules_text","")) or "梦违" in info.get("keywords",[]))
 if filters.is_empty():return SearchAliases.matches_query(info,id,prepared)
 var race: String = str(filters.race)
 var race_match = race.is_empty() or race in info.get("race",[]) or _related_to_race(info,race,race_characters)
 var colors_match = filters.colors.all(func(color):return color in info.get("colors",[]))
 var match_filter = SearchAliases.kind_matches(info,str(filters.kind)) and race_match and (not filters.single or info.get("colors",[]).size()==1) and colors_match
 if filters.kind in ["普通符卡","自机符卡"]:return match_filter
 var required_character = str(info.get("requires_character",""))
 var role_spell = info.get("kind","")=="符卡" and not required_character.is_empty() and prepared.role_characters.any(func(character):return character==required_character or str(character).begins_with(required_character+"·") or str(character).begins_with(required_character+"・"))
 return match_filter or role_spell or prepared.ids.has(id)

func visible_entries() -> Array:
 var filtered = []
 var prepared = SearchAliases.prepare_query(cards,query,alias_rules,layout_metrics.touch)
 var filters = _query_filters(query)
 var race_characters = _race_characters(str(filters.get("race","")))
 for candidate in entries:
  if not candidate is Dictionary:continue
  var id = str(candidate.get("id",""))
  if not cards.has(id) or not cards[id] is Dictionary:continue
  var info: Dictionary = cards[id]
  if not _matches_query(id,info,prepared,filters,race_characters):continue
  if not SearchAliases.kind_matches(info,filter_kind) or not _matches_colors(info):continue
  filtered.append(candidate)
 filtered.sort_custom(func(a,b):return _entry_less(a,b))
 return filtered

func _color_value(info: Dictionary) -> int:
 var result = 0
 for amount in info.get("cost",{}).values():result+=int(amount)
 return result

func _entry_less(a: Dictionary, b: Dictionary) -> bool:
 var x: Dictionary = cards[str(a.id)]
 var y: Dictionary = cards[str(b.id)]
 if sort_mode=="类别" and x.get("kind","")!=y.get("kind",""):
  var categories = ["自机","单位","符卡","道具","结界"]
  var first = categories.find(x.get("kind",""))
  var second = categories.find(y.get("kind",""))
  return (99 if first<0 else first)<(99 if second<0 else second)
 if sort_mode!="名字":
  var first_cost = _color_value(x)
  var second_cost = _color_value(y)
  if first_cost!=second_cost:return first_cost<second_cost
 var first_name = str(x.get("name",""))
 var second_name = str(y.get("name",""))
 if first_name!=second_name:return first_name.naturalnocasecmp_to(second_name)<0
 var first_id = str(a.id)
 var second_id = str(b.id)
 if first_id!=second_id:return first_id.naturalnocasecmp_to(second_id)<0
 return str(a.get("caption","")).naturalnocasecmp_to(str(b.get("caption","")))<0

func update_results():
 if not is_instance_valid(search_results):return
 _clear(search_results)
 var matches = visible_entries()
 result_count.text = "找到 %d 张" % matches.size()
 if matches.is_empty():
  var empty = _label(search_results,"没有符合条件的卡牌",Rect2(8,8,290,44),17,MUTED)
  empty.custom_minimum_size = Vector2(290,50)
  return
 for entry in matches:
  var chosen_entry: Dictionary = entry.duplicate()
  var id: String = str(chosen_entry.id)
  var info: Dictionary = cards[id]
  var caption = str(chosen_entry.get("caption",info.get("name",id)))
  var row = Button.new()
  row.name = "CardResult"
  row.text = caption
  row.alignment = HORIZONTAL_ALIGNMENT_LEFT
  row.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
  layout_metrics.button(row)
  row.custom_minimum_size = Vector2(0,layout_metrics.hit)
  row.tooltip_text = str(info.get("name",id))+" · "+str(info.get("kind",""))
  row.set_meta("entry",chosen_entry)
  row.set_meta("card_id",id)
  row.set_meta("card_name",str(info.get("name",id)))
  row.add_theme_stylebox_override("normal",_style(Color("#142737"),GOLD if selected_entry==chosen_entry else Color("#3d5161")))
  row.add_theme_stylebox_override("hover",_style(Color("#294354"),GOLD))
  row.add_theme_stylebox_override("pressed",_style(Color("#3b3325"),GOLD))
  row.add_theme_color_override("font_color",WHITE)
  row.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
  search_results.add_child(row)
  row.mouse_entered.connect(func():show_preview(id))
  row.pressed.connect(func():choose_entry(chosen_entry))

func _card_texture(id: String) -> Texture2D:
 if texture_provider.is_valid():
  var supplied = texture_provider.call(id)
  if supplied is Texture2D:return supplied
 var info: Dictionary = cards.get(id,{})
 var path = str(info.get("image",""))
 if path.is_empty() or not ResourceLoader.exists(path):return null
 return load(path) as Texture2D

func _card_image(parent: Node, id: String, rect: Rect2):
 var picture = TextureRect.new()
 picture.position = rect.position
 picture.size = rect.size
 picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
 picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
 picture.texture = _card_texture(id)
 picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
 parent.add_child(picture)
 if picture.texture==null:
  var missing = _label(parent,"暂无卡图",rect,20,MUTED)
  missing.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
  missing.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

func show_preview(id: String):
 if not cards.has(id):return
 preview_id = id
 update_preview()

func update_preview():
 if not is_instance_valid(preview_card):return
 _clear(preview_card)
 if preview_id.is_empty() or not cards.has(preview_id):
  var hint=_label(preview_card,"点击右侧卡名查看并选择卡牌。",Rect2(),layout_metrics.body,MUTED)
  hint.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
  return
 var info: Dictionary=cards[preview_id]
 var image=TextureRect.new();image.texture=_card_texture(preview_id);image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;image.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
 image.custom_minimum_size.y=120;image.size_flags_vertical=Control.SIZE_EXPAND_FILL;preview_card.add_child(image)
 var scroll=ScrollContainer.new();scroll.name="CardTextScroll";scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;preview_card.add_child(scroll);scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
 var body=VBoxContainer.new();body.size_flags_horizontal=Control.SIZE_EXPAND_FILL;scroll.add_child(body)
 for value in [str(info.get("name",preview_id)),CostDisplay.caption(info.get("cost",{})),str(info.get("rules_text",""))]:
  var line=_label(body,value,Rect2(),layout_metrics.body,GOLD if value==info.get("name") else WHITE)
  line.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART

func select_id(id: String) -> bool:
 for entry in entries:
  if entry is Dictionary and str(entry.get("id",""))==id and cards.has(id):
   choose_entry(entry)
   return true
 return false

func choose_entry(entry: Dictionary):
 var id = str(entry.get("id",""))
 if not cards.has(id):return
 selected_entry = entry
 show_preview(id)
 update_selected_card()
 update_results()
 selected.emit(selected_entry)

func update_selected_card():
 if not is_instance_valid(selected_card):return
 _clear(selected_card)
 var value="从右侧选择一张卡牌"
 if not selected_entry.is_empty() and cards.has(str(selected_entry.get("id",""))):value="已选："+str(cards[str(selected_entry.id)].get("name",selected_entry.id))
 var title=_label(selected_card,value,Rect2(),layout_metrics.body,GOLD)
 title.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;title.clip_text=true
 title.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 title.offset_left=12;title.offset_right=-12;title.offset_top=8;title.offset_bottom=-8
