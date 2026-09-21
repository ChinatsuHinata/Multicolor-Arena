extends Control
# Replace this with a res:// image path to change the battlefield background.
@export_file("*.png", "*.jpg", "*.webp") var battlefield_background: String = "res://recourse/垫子3.png"
const Store = preload("res://scripts/deck_store.gd")
const GOLD = Color("#d9b775")
const INK = Color("#101c28")
const MUTED = Color("#91a5b7")
const WHITE = Color("#e8edf0")
var deck_canvas: Control
var screen: Control
var page = ""
var decks: Array = []
var draft: Dictionary
var dirty = false
var load_error = ""
var selected = "70"
var zone = "main"
var query = ""
var filter_kind = "全部"
var selected_colors: Array = []
var color_buttons = {}
var main_scroll: ScrollContainer
var main_content: Control
var library: GridContainer
var deck_rows: VBoxContainer
var preview: Control
var counts: Label
var name_label: Label
var saved_select: OptionButton
var player_choice = 0
var ai_choice = 0
var skip_check = false
var ai_one = false
var textures = {}
var duel_view
var status = ""
var fullscreen = false
var add_amount = 1
var zone_buttons = {}
var settings_path = "res://saves/settings.json"

func _ready():
 var f = SystemFont.new()
 f.font_names = PackedStringArray(["Microsoft YaHei UI", "Microsoft YaHei", "Noto Sans CJK SC"])
 var t = Theme.new()
 t.default_font = f
 t.default_font_size = 18
 theme = t
 var loaded = Store.load_decks()
 decks = loaded.decks
 load_error = loaded.get("error", "")
 if Store.CARDS.is_empty(): load_error=Store.Database.last_error
 draft = Store.blank()
 if FileAccess.file_exists(settings_path):
  var saved_settings = JSON.parse_string(FileAccess.get_file_as_string(settings_path))
  if saved_settings is Dictionary:
   fullscreen = saved_settings.get("fullscreen", false) == true
 if fullscreen: DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
 menu()
 if not load_error.is_empty(): alert(load_error)

func _draw():
 draw_rect(Rect2(0,0,1600,900), Color("#09121d"))
 if page=="battle": return
 for i in range(22):
  draw_circle(Vector2(1150,400),520-i*18,Color(0.13,0.28,0.35,0.018+float(i)*0.001))

func clear_page(next: String):
 if is_instance_valid(screen):
  remove_child(screen)
  screen.queue_free()
 screen = Control.new()
 screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 add_child(screen)
 page = next
 queue_redraw()

func box(parent: Node, rect: Rect2, color: Color = INK, border: Color = Color("#30424f")) -> Panel:
 var p = Panel.new()
 p.position = rect.position
 p.size = rect.size
 p.add_theme_stylebox_override("panel", style(color,border))
 parent.add_child(p)
 return p

func style(color: Color, border: Color = Color("#3d5161")) -> StyleBoxFlat:
 var s = StyleBoxFlat.new()
 s.bg_color = color
 s.border_color = border
 s.set_border_width_all(1)
 s.set_corner_radius_all(10)
 s.content_margin_left = 14
 s.content_margin_right = 14
 s.content_margin_top = 7
 s.content_margin_bottom = 7
 return s

func label(parent: Node, text: String, rect: Rect2, font_size: int = 18, color: Color = WHITE) -> Label:
 var l = Label.new()
 l.text = text
 l.position = rect.position
 l.size = rect.size
 l.add_theme_font_size_override("font_size",font_size)
 l.add_theme_color_override("font_color",color)
 l.clip_text = true
 l.mouse_filter = Control.MOUSE_FILTER_IGNORE
 parent.add_child(l)
 return l

func button(parent: Node, text: String, rect: Rect2, action: Callable, accent: bool = false) -> Button:
 var b = Button.new()
 b.text = text
 b.position = rect.position
 b.size = rect.size
 b.add_theme_stylebox_override("normal",style(Color("#3b3325") if accent else Color("#192a38"),GOLD if accent else Color("#3d5161")))
 b.add_theme_stylebox_override("hover",style(Color("#4b4130") if accent else Color("#294354"),GOLD))
 b.add_theme_stylebox_override("pressed",style(Color("#615135"),GOLD))
 b.add_theme_stylebox_override("focus",style(Color(0,0,0,0),GOLD))
 b.add_theme_color_override("font_color",GOLD if accent else WHITE)
 b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
 b.pressed.connect(action)
 parent.add_child(b)
 return b

func texture(id: String) -> Texture2D:
 if id=="potato": return load("res://assets/potato.svg")
 if not Store.CARDS.has(id): return null
 if textures.has(id): return textures[id]
 var resource = load(Store.CARDS[id].image) as Texture2D
 if resource == null: return null
 var img = resource.get_image()
 if img.get_width() > img.get_height(): img.rotate_90(CLOCKWISE)
 if img.get_width() > 1200: img.resize(1200,int(float(img.get_height())*1200/img.get_width()),Image.INTERPOLATE_LANCZOS)
 if not img.has_mipmaps(): img.generate_mipmaps()
 var tex = ImageTexture.create_from_image(img)
 textures[id] = tex
 return tex

func card(parent: Node, id: String, rect: Rect2, clickable: Callable = Callable()) -> Control:
 var p = box(parent,rect,Color("#172936"),GOLD if id in ["68","70"] else Color("#416078"))
 var art = TextureRect.new()
 art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
 art.texture = texture(id)
 art.position = Vector2(5,5)
 art.size = rect.size - Vector2(10,10)
 art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
 art.mouse_filter = Control.MOUSE_FILTER_IGNORE
 p.add_child(art)
 if clickable.is_valid():
  p.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
  p.gui_input.connect(func(event):
   if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT: clickable.call())
 return p

func header(title: String, back: Callable):
 label(screen,"极 彩  /  MULTICOLOUR",Rect2(42,22,500,34),20,GOLD)
 label(screen,title,Rect2(42,68,1100,48),32)
 button(screen,"返回",Rect2(1430,32,126,46),back)
 box(screen,Rect2(42,126,1514,1),Color("#30424f"),Color("#30424f"))

func alert(message: String, title: String = "提示"):
 var d = AcceptDialog.new()
 d.title = title
 d.dialog_text = message
 d.min_size = Vector2i(540,180)
 d.get_ok_button().text = "知道了"
 d.confirmed.connect(d.queue_free)
 d.canceled.connect(d.queue_free)
 add_child(d)
 d.popup_centered()

func confirm_action(message: String, action: Callable):
 var d = ConfirmationDialog.new()
 d.title = "确认操作"
 d.dialog_text = message
 d.min_size = Vector2i(500,170)
 d.get_ok_button().text = "确认"
 d.get_cancel_button().text = "取消"
 d.confirmed.connect(func(): d.queue_free(); action.call())
 d.canceled.connect(d.queue_free)
 add_child(d)
 d.popup_centered()

func guard(action: Callable):
 if dirty: confirm_action("当前卡组有未保存的修改。是否放弃修改并继续？",func():
  var restored=Store.blank()
  for d in decks:
   if d.id==draft.id: restored=d.duplicate(true); break
  draft=restored
  dirty=false
  action.call())
 else: action.call()

func menu():
 clear_page("menu")
 label(screen,"MULTICOLOUR  /  CARD BATTLE",Rect2(92,74,900,42),18,GOLD)
 label(screen,"极 彩",Rect2(86,173,700,125),92)
 label(screen,"以色彩为契约，展开你的幻想之战。",Rect2(94,309,740,48),24,MUTED)
 button(screen,"人机对战    →",Rect2(96,422,440,70),setup,true)
 button(screen,"联网对战",Rect2(96,512,440,64),online)
 button(screen,"编辑牌组",Rect2(96,594,440,64),func(): editor())
 button(screen,"设置",Rect2(96,676,440,64),settings)
 card(screen,"68",Rect2(890,205,255,360)).rotation_degrees = -12
 card(screen,"70",Rect2(1140,250,280,394)).rotation_degrees = 12

func online():
 clear_page("online")
 header("联网对战",menu)
 label(screen,"联机模式尚未开放",Rect2(410,320,900,72),38,GOLD)
 button(screen,"前往人机对战",Rect2(410,518,350,62),setup,true)

func settings():
 clear_page("settings")
 header("设置",menu)
 var cb = CheckButton.new()
 cb.text = "全屏显示"
 cb.position = Vector2(420,290)
 cb.size = Vector2(700,60)
 cb.button_pressed = fullscreen
 cb.toggled.connect(func(value):
  fullscreen = value
  DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if value else DisplayServer.WINDOW_MODE_WINDOWED)
  var f = FileAccess.open(settings_path,FileAccess.WRITE)
  if f: f.store_string(JSON.stringify({"fullscreen":value}))
  else: alert("无法保存设置。"))
 screen.add_child(cb)
 

func editor():
 clear_page("editor")
 label(screen,"卡组编辑器",Rect2(24,12,270,46),28,GOLD)
 button(screen,"返回",Rect2(1480,14,100,40),func(): guard(menu))
 box(screen,Rect2(18,72,286,810))
 preview=Control.new()
 preview.position=Vector2(30,88)
 screen.add_child(preview)
 box(screen,Rect2(320,72,902,810))
 name_label=label(screen,"",Rect2(338,80,670,36),23,GOLD)
 counts=label(screen,"",Rect2(338,818,858,32),17,MUTED)
 deck_canvas=Control.new()
 deck_canvas.position=Vector2(334,126)
 deck_canvas.size=Vector2(874,680)
 screen.add_child(deck_canvas)
 box(screen,Rect2(1238,72,344,810))
 var search=LineEdit.new()
 search.placeholder_text="搜索卡牌"
 search.text=query
 search.position=Vector2(1252,88)
 search.size=Vector2(314,42)
 search.text_changed.connect(func(value): query=value; update_library())
 screen.add_child(search)
 color_buttons.clear()
 var colors=["全部","红","蓝","绿","黄","黑"]
 var swatches=[Color("#344553"),Color("#a83035"),Color("#337aa7"),Color("#39794d"),Color("#ac963b"),Color("#383a42")]
 for i in range(colors.size()):
  var color=colors[i]
  var b=button(screen,color,Rect2(1252+i*53,142,47,36),func(): toggle_color(color))
  b.add_theme_font_size_override("font_size",16)
  b.add_theme_stylebox_override("normal",style(swatches[i]))
  b.add_theme_stylebox_override("pressed",style(swatches[i],GOLD))
  b.toggle_mode=true
  color_buttons[color]=b
 refresh_color_buttons()
 var kind=OptionButton.new()
 kind.position=Vector2(1252,190)
 kind.size=Vector2(314,38)
 for x in ["全部","自机","符卡","道具","结界"]: kind.add_item(x)
 kind.select(["全部","自机","符卡","道具","结界"].find(filter_kind))
 kind.item_selected.connect(func(i): filter_kind=kind.get_item_text(i); update_library())
 screen.add_child(kind)
 var scroll=ScrollContainer.new()
 scroll.position=Vector2(1252,242)
 scroll.size=Vector2(314,345)
 scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
 screen.add_child(scroll)
 library=GridContainer.new()
 scroll.set_drag_forwarding(Callable(),can_return_card,return_card_to_library)
 library.columns=1
 library.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 library.add_theme_constant_override("v_separation",6)
 scroll.add_child(library)
 library.set_drag_forwarding(Callable(),can_return_card,return_card_to_library)
 saved_select=OptionButton.new()
 saved_select.position=Vector2(1252,602)
 saved_select.size=Vector2(314,40)
 saved_select.add_item("卡组")
 for d in decks:
  saved_select.add_item(d.name)
  if d.id==draft.id: saved_select.select(saved_select.item_count-1)
 saved_select.item_selected.connect(func(i):
  if i>0: guard(func(): draft=decks[i-1].duplicate(true); dirty=false; editor()))
 screen.add_child(saved_select)
 button(screen,"保存",Rect2(1252,656,150,42),save_deck,true)
 button(screen,"使用卡组",Rect2(1416,656,150,42),use_deck)
 button(screen,"复制",Rect2(1252,710,150,42),copy_deck)
 button(screen,"粘贴",Rect2(1416,710,150,42),func(): guard(paste_dialog))
 button(screen,"新建",Rect2(1252,764,150,42),func(): guard(func(): draft=Store.blank(); dirty=false; editor(); rename_dialog()))
 button(screen,"重命名",Rect2(1416,764,150,42),rename_dialog)
 button(screen,"清空卡组",Rect2(1252,818,150,42),func(): confirm_action("清空当前卡组？",func(): draft.main.clear(); draft.side.clear(); draft.leader=""; dirty=true; update_deck_rows()))
 button(screen,"备牌" if zone!="side" else "主卡组",Rect2(1416,818,150,42),func(): zone="main" if zone=="side" else "side"; editor())
 update_preview()
 update_library()
 update_deck_rows()

func free_children(parent: Node):
 for c in parent.get_children():
  parent.remove_child(c)
  c.queue_free()

func toggle_color(color: String):
 if color=="全部": selected_colors.clear()
 elif color in selected_colors: selected_colors.erase(color)
 else: selected_colors.append(color)
 refresh_color_buttons()
 update_library()

func refresh_color_buttons():
 for color in color_buttons:
  var active=selected_colors.is_empty() if color=="全部" else color in selected_colors
  color_buttons[color].set_pressed_no_signal(active)
  color_buttons[color].text=("✓" if active and color!="全部" else "")+color

func matches_colors(info: Dictionary) -> bool:
 if selected_colors.is_empty(): return true
 for color in info.colors:
  if color in selected_colors: return true
 return false

func update_preview():
 free_children(preview)
 card(preview,selected,Rect2(0,0,260,350))
 var info=Store.CARDS[selected]
 var scroll=ScrollContainer.new()
 scroll.name="CardTextScroll"
 scroll.position=Vector2(0,362)
 scroll.size=Vector2(260,341)
 scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
 preview.add_child(scroll)
 var column=VBoxContainer.new()
 column.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 column.add_theme_constant_override("separation",12)
 scroll.add_child(column)
 for value in [info.name,card_description(selected)]:
  var text=Label.new()
  text.text=value
  text.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
  text.size_flags_horizontal=Control.SIZE_EXPAND_FILL
  text.add_theme_font_size_override("font_size",20 if value==info.name else 17)
  text.add_theme_color_override("font_color",GOLD if value==info.name else WHITE)
  column.add_child(text)
 button(preview,"设为自机",Rect2(0,715,260,43),func(): add_to("leader"),true)

func update_library():
 free_children(library)
 for id in Store.CARDS:
  var info=Store.CARDS[id]
  if not query.is_empty() and not query.to_lower() in info.name.to_lower(): continue
  if filter_kind!="全部" and info.kind!=filter_kind: continue
  if not matches_colors(info): continue
  var row=preload("res://scripts/deck_card.gd").new()
  row.card_id=id
  row.source_zone="library"
  row.face_texture=texture(id)
  row.set_meta("card_id",id)
  row.custom_minimum_size=Vector2(296,64)
  row.add_theme_stylebox_override("panel",style(Color("#142737")))
  library.add_child(row)
  var full_name=label(row,info.name,Rect2(10,4,276,54),17,WHITE)
  full_name.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
  full_name.clip_text=false
  full_name.mouse_filter=Control.MOUSE_FILTER_IGNORE
  row.tooltip_text=info.name
  row.preview_requested.connect(func(card_id): selected=card_id; update_preview())
  row.clicked.connect(func(card_id,_from,_index,right):
   selected=card_id
   update_preview()
   if not right: add_to("side" if zone=="side" else "main"))
  row.set_drag_forwarding(row._get_drag_data,can_return_card,return_card_to_library)

func can_return_card(_at: Vector2, data: Variant) -> bool:
 return valid_drag_source(data) and data.source_zone in ["main","side","leader"]

func valid_drag_source(data: Variant) -> bool:
 if not data is Dictionary or not Store.CARDS.has(data.get("card_id","")): return false
 var source=data.get("source_zone","")
 if source=="library": return true
 if source=="leader": return draft.leader==data.card_id
 if source in ["main","side"]:
  var index=int(data.get("source_index",-1))
  return index>=0 and index<draft[source].size() and draft[source][index]==data.card_id
 return false

func return_card_to_library(at: Vector2, data: Variant):
 if not can_return_card(at,data): return
 if data.source_zone=="leader": draft.leader=""
 else: draft[data.source_zone].remove_at(int(data.source_index))
 dirty=true
 update_deck_rows()

func main_card_rect(index: int) -> Rect2:
 var column=2+index%8 if index<16 else (index-16)%10
 var row=index/8 if index<16 else 2+(index-16)/10
 return Rect2(4+column*85,4+row*120,79,111)

func update_deck_rows():
 name_label.text=draft.name+(" *" if dirty else "")
 counts.text="主卡组 %d / 70     副卡组 %d / 10     自机 %d / 1" % [draft.main.size(),draft.side.size(),0 if draft.leader.is_empty() else 1]
 var old_scroll=main_scroll.scroll_vertical if is_instance_valid(main_scroll) else 0
 free_children(deck_canvas)
 main_scroll=ScrollContainer.new()
 main_scroll.name="MainDeckScroll"
 main_scroll.size=Vector2(874,509)
 main_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
 deck_canvas.add_child(main_scroll)
 main_content=Control.new()
 main_content.name="MainDeckCards"
 var height=maxf(509,main_card_rect(maxi(0,draft.main.size()-1)).end.y+5)
 main_content.custom_minimum_size=Vector2(854,height)
 main_scroll.add_child(main_content)
 make_drop_zone("main",Rect2(0,0,854,height),main_content)
 make_drop_zone("leader",Rect2(0,0,170,240),main_content)
 if not draft.leader.is_empty(): editor_card(draft.leader,"leader",0,Rect2(4,4,162,231),main_content)
 for i in range(draft.main.size()):
  editor_card(draft.main[i],"main",i,main_card_rect(i),main_content)
 main_scroll.set_deferred("scroll_vertical",old_scroll)
 make_drop_zone("side",Rect2(0,553,872,124))
 for i in range(draft.side.size()):
  editor_card(draft.side[i],"side",i,Rect2(9+i*86,559,78,109))
 label(deck_canvas,"副卡组",Rect2(5,519,130,32),18,GOLD)
 var color_counts={"红":0,"蓝":0,"绿":0,"黄":0,"黑":0}
 for id in draft.main:
  for color in Store.CARDS[id].colors: color_counts[color]+=1
 var index=0
 for c in color_counts:
  label(deck_canvas,"%s %d" % [c,color_counts[c]],Rect2(146+index*116,519,108,30),18,MUTED)
  index+=1

func add_selected(): add_to(zone)
func add_to(target: String):
 var amount = 1 if target=="leader" else add_amount
 var copy = draft.duplicate(true)
 for i in range(amount):
  var error = Store.add_card(copy,selected,target)
  if not error.is_empty(): alert(error); return
 draft=copy
 zone = target
 dirty = true
 update_deck_rows()

func remove_card(id: String):
 if zone == "leader": draft.leader = ""
 else: draft[zone].erase(id)
 dirty = true
 update_deck_rows()

func rename_dialog():
 var d = ConfirmationDialog.new()
 d.title = "卡组名称"
 d.min_size = Vector2i(500,180)
 var entry = LineEdit.new()
 entry.text = draft.name
 entry.max_length = 40
 entry.position = Vector2(24,42)
 entry.size = Vector2(450,48)
 d.add_child(entry)
 d.get_ok_button().text = "确定"
 d.get_cancel_button().text = "取消"
 d.confirmed.connect(func():
  var new_name = entry.text.strip_edges()
  if new_name.is_empty(): alert("卡组名称不能为空。")
  else:
   draft.name=new_name
   dirty=true
   update_deck_rows()
  d.queue_free())
 d.canceled.connect(d.queue_free)
 add_child(d)
 d.popup_centered()
 entry.grab_focus()
 entry.select_all()

func save_deck():
 if not load_error.is_empty(): alert(load_error + "\n请先修复 saves/decks.json，避免覆盖原有数据。"); return
 var error = Store.validate(draft)
 if not error.is_empty(): alert(error,"无法保存"); return
 var next = decks.duplicate(true)
 var found = false
 for i in range(next.size()):
  if next[i].id == draft.id: next[i]=draft.duplicate(true); found=true; break
 if not found: next.append(draft.duplicate(true))
 error = Store.persist(next)
 if not error.is_empty(): alert(error,"保存失败"); return
 decks = next
 dirty = false
 editor()

func copy_deck():
 var error = Store.validate(draft)
 if not error.is_empty(): alert(error,"无法复制"); return
 DisplayServer.clipboard_set(JSON.stringify(draft))
 

func paste_dialog():
 var d = ConfirmationDialog.new()
 d.title = "粘贴卡组代码"
 d.min_size = Vector2i(690,430)
 var entry = TextEdit.new()
 entry.position=Vector2(20,40)
 entry.size=Vector2(650,310)
 entry.text=DisplayServer.clipboard_get()
 d.add_child(entry)
 d.get_ok_button().text="导入为新卡组"
 d.get_cancel_button().text="取消"
 d.confirmed.connect(func():
  var result=Store.decode(entry.text)
  if result.has("error"): alert(result.error,"导入失败")
  else: draft=result.deck; dirty=true; editor()
  d.queue_free())
 d.canceled.connect(d.queue_free)
 add_child(d)
 d.popup_centered()

func setup():
 clear_page("setup")
 header("人机对战",menu)
 player_choice=clampi(player_choice,0,maxi(0,decks.size()-1))
 ai_choice=clampi(ai_choice,0,maxi(0,decks.size()-1))
 for i in range(2):
  var x=220+i*620
  box(screen,Rect2(x,186,540,340))
  label(screen,"你的卡组" if i==0 else "人机的卡组",Rect2(x+24,205,440,40),24,GOLD)
  var pick=OptionButton.new()
  pick.position=Vector2(x+24,266)
  pick.size=Vector2(492,50)
  if decks.is_empty():
   pick.add_item("未选择")
  else:
   for d in decks: pick.add_item(d.name)
   pick.select(player_choice if i==0 else ai_choice)
  pick.item_selected.connect(func(index):
   if i==0: player_choice=index
   else: ai_choice=index
   setup())
  screen.add_child(pick)
  if not decks.is_empty():
   var chosen=decks[player_choice if i==0 else ai_choice]
   card(screen,chosen.leader,Rect2(x+24,340,106,151))
   label(screen,"主卡组 %d\n副卡组 %d" % [chosen.main.size(),chosen.side.size()],Rect2(x+160,352,340,110),22)
 var skip=CheckButton.new()
 skip.text="不检查卡组"
 skip.position=Vector2(420,568)
 skip.size=Vector2(800,45)
 skip.button_pressed=skip_check
 skip.toggled.connect(func(value): skip_check=value)
 screen.add_child(skip)
 var one=CheckButton.new()
 one.text="人机必定投 1"
 one.position=Vector2(420,630)
 one.size=Vector2(800,45)
 one.button_pressed=ai_one
 one.toggled.connect(func(value): ai_one=value)
 screen.add_child(one)
 button(screen,"开始对战",Rect2(570,721,460,68),start_match,true)
 button(screen,"编辑牌组",Rect2(1080,730,250,50),editor)
 button(screen,"载入测试卡组",Rect2(80,730,270,50),load_test_decks)

func start_match():
 if decks.is_empty(): alert("请选择卡组。"); return
 for i in [player_choice,ai_choice]:
  var error=Store.validate(decks[i],not skip_check)
  if not error.is_empty():
   alert("「%s」：%s" % [decks[i].name,error],"卡组不合规")
   return
 var your_roll = randi_range(2,6) if ai_one else randi_range(1,6)
 var bot_roll = 1 if ai_one else randi_range(1,6)
 while your_roll==bot_roll: your_roll=randi_range(1,6); bot_roll=randi_range(1,6)
 if your_roll>bot_roll:
  var d=ConfirmationDialog.new()
  d.title="你赢得了投点"
  d.dialog_text="你投出 %d，人机投出 %d。请选择先后手。" % [your_roll,bot_roll]
  d.min_size=Vector2i(540,180)
  d.get_ok_button().text="我方先手"
  d.get_cancel_button().text="我方后手"
  d.confirmed.connect(func(): d.queue_free(); begin_battle(true))
  d.canceled.connect(func(): d.queue_free(); begin_battle(false))
  add_child(d)
  d.popup_centered()
 else:
  begin_battle(false)
  alert("你投出 %d，人机投出 %d。人机选择先手。" % [your_roll,bot_roll],"投点结果")

func begin_battle(first: bool):
 clear_page("battle")
 duel_view=preload("res://scripts/duel_view.gd").new()
 duel_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 screen.add_child(duel_view)
 duel_view.begin(self,decks[player_choice],decks[ai_choice],0 if first else 1)

func load_test_decks():
 for id in ["demo_reimu","demo_marisa"]:
  for d in decks.duplicate():
   if d.id==id: decks.erase(d)
 var reimu=Store.blank("测试 · 灵梦")
 reimu.id="demo_reimu"; reimu.leader="70"
 var marisa=Store.blank("测试 · 魔理沙")
 marisa.id="demo_marisa"; marisa.leader="68"
 for i in range(5):
  reimu.main.append_array(["164","164","165","165","167","68","70","99","100","170"])
  marisa.main.append_array(["164","164","165","167","167","68","70","99","100","170"])
 player_choice=decks.size(); ai_choice=decks.size()+1
 decks.append(reimu); decks.append(marisa)
 skip_check=true; ai_one=true
 setup()

func card_description(id: String) -> String:
 return Store.CARDS[id].rules_text

func make_drop_zone(target: String, rect: Rect2, parent: Node = null):
 var panel=box(parent if parent else deck_canvas,rect,Color("#13232f"),GOLD if zone==target else Color("#3b5060"))
 panel.set_drag_forwarding(Callable(),func(_at,data): return valid_drag_source(data),func(_at,data): drop_editor_card(data,target))
 if target=="leader" and draft.leader.is_empty(): label(panel,"自机",Rect2(20,60,90,40),24,MUTED)

func editor_card(id: String, source: String, index: int, rect: Rect2, parent: Node = null):
 var tile=preload("res://scripts/deck_card.gd").new()
 tile.card_id=id
 tile.face_texture=texture(id)
 tile.source_zone=source
 tile.source_index=index
 tile.position=rect.position
 tile.size=rect.size
 tile.add_theme_stylebox_override("panel",style(Color("#142737"),GOLD if source=="leader" else Color("#677585")))
 (parent if parent else deck_canvas).add_child(tile)
 var art=TextureRect.new()
 art.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
 art.texture=texture(id)
 art.position=Vector2(3,3)
 art.size=rect.size-Vector2(6,6)
 art.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
 art.mouse_filter=Control.MOUSE_FILTER_IGNORE
 tile.add_child(art)
 tile.preview_requested.connect(func(card_id): selected=card_id; update_preview())
 tile.clicked.connect(func(card_id,from,index_in_deck,right):
  selected=card_id
  zone=from
  if right:
   if from=="leader": draft.leader=""
   else: draft[from].remove_at(index_in_deck)
   dirty=true
   update_deck_rows()
  else: add_to(from))
 tile.set_drag_forwarding(tile._get_drag_data,func(_at,data): return valid_drag_source(data),func(_at,data): drop_editor_card(data,source))

func drop_editor_card(data: Dictionary, target: String):
 if not valid_drag_source(data) or target not in ["main","side","leader"]: return
 var source=data.get("source_zone","")
 if source==target: return
 var next=draft.duplicate(true)
 var error=Store.add_card(next,data.card_id,target)
 if not error.is_empty(): alert(error); return
 if source=="leader": next.leader="" if target!="leader" else next.leader
 elif source in ["main","side"]:
  var index=int(data.get("source_index",-1))
  if index>=0 and index<next[source].size(): next[source].remove_at(index)
 draft=next
 dirty=true
 zone=target
 update_deck_rows()

func use_deck():
 var error=Store.validate(draft)
 if not error.is_empty(): alert(error); return
 save_deck()
 if dirty: return
 for i in range(decks.size()):
  if decks[i].id==draft.id: player_choice=i; break
 setup()

