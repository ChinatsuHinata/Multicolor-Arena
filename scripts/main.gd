extends Control
# Replace this with a res:// image path to change the battlefield background.
@export_file("*.png", "*.jpg", "*.webp") var battlefield_background: String = "res://recourse/垫子3.png"
const CARD_BACK_PATH = "res://recourse/卡背.jpg"
const Store = preload("res://scripts/deck_store.gd")
const CardArt=preload("res://scripts/card_art.gd")
const RuleSet = preload("res://scripts/deck_rule_set.gd")
const SearchAliases=preload("res://scripts/card_search_aliases.gd")
const DeckImage=preload("res://scripts/deck_image_export.gd")
const CostDisplay=preload("res://scripts/card_cost_display.gd")
const HexCost=preload("res://scripts/cost_hex_display.gd")
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
var deck_capture_busy = false
var load_error = ""
var selected = "70"
var zone = "main"
var query = ""
var filter_kind = "全部"
var selected_colors: Array = []
var library_sort_mode="类别"
var color_buttons = {}
var main_scroll: ScrollContainer
var main_content: Control
var library: GridContainer
var library_rows: Dictionary = {}
var library_sort_choice: OptionButton
var deck_rows: VBoxContainer
var preview: Control
var counts: Label
var name_label: Label
var saved_select: OptionButton
var player_choice = 0
var ai_choice = 0
var textures = {}
var duel_view
var lan_session
var network_game_open=""
var status = ""
var debug_mode=false
var debug_free_payment=false
var debug_drag_to_field=false
var about_code=""
var fullscreen = false
var top_down_view = false
var show_card_inspection = true
var add_amount = 1
var zone_buttons = {}
var settings_path = "res://saves/settings.json" if OS.has_feature("editor") else "user://settings.json"
var sideboard_session
var sideboard_original={}
var sideboard_previous={}
var sideboard_waiting=false
var sideboard_status: Label
var sideboard_done: Button
var replay_controller

func _ready():
 var f = SystemFont.new()
 f.font_names = PackedStringArray(["Microsoft YaHei UI", "Microsoft YaHei", "Noto Sans CJK SC"])
 var t = Theme.new()
 t.default_font = f
 t.default_font_size = 18
 theme = t
 var loaded = Store.load_decks()
 decks = loaded.decks
 for i in range(decks.size()):
  if decks[i].id=="precon_reimu_v1": player_choice=i
  elif decks[i].id=="precon_marisa_v1": ai_choice=i
 load_error = loaded.get("error", "")
 if Store.CARDS.is_empty(): load_error=Store.Database.last_error
 draft = Store.blank()
 if FileAccess.file_exists(settings_path):
  var saved_settings = JSON.parse_string(FileAccess.get_file_as_string(settings_path))
  if saved_settings is Dictionary:
   fullscreen = saved_settings.get("fullscreen", false) == true
   top_down_view = saved_settings.get("top_down_view", false) == true
   show_card_inspection = saved_settings.get("show_card_inspection", true) == true
   debug_drag_to_field = saved_settings.get("debug_drag_to_field", false) == true
 if fullscreen: DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
 menu()
 if not load_error.is_empty(): alert(load_error)
 elif not loaded.get("warnings",[]).is_empty():
  call_deferred("alert","卡组加载提示：\n"+"\n".join(loaded.warnings))

func _draw():
 if page=="battle": return
 draw_rect(Rect2(0,0,1600,900), Color("#09121d"))
 for i in range(22):
  draw_circle(Vector2(1150,400),520-i*18,Color(0.13,0.28,0.35,0.018+float(i)*0.001))

func clear_page(next: String):
 if page=="sideboard" and next!="sideboard":restore_editor_draft()
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

func editor_art_id(id: String) -> String:
 return CardArt.selected(draft,id,Store.CARDS) if page in ["editor","sideboard"] else ""
func texture(id: String,art_id: String="") -> Texture2D:
 if id=="back": return load(CARD_BACK_PATH)
 if id=="potato": return load("res://assets/potato_tts_149404.jpg")
 if id=="token_halfghost" and Store.CARDS.has("token-ucs-099"):return texture("token-ucs-099")
 if id in ["token_ufo","token_halfghost"]: return load("res://assets/"+id+".svg")
 var image_path=""
 if not Store.CARDS.has(id):
  if is_instance_valid(duel_view) and duel_view.engine.cards.has(id):
   var info=duel_view.engine.cards[id]
   if info.has("copy_source_id"):return texture(info.copy_source_id,art_id)
   image_path=info.get("image","")
   if image_path.is_empty() and info.get("token",false):return load("res://assets/roster_token.svg")
  if image_path.is_empty():return null
 else:image_path=Store.CARDS[id].image
 if art_id.is_empty():art_id=editor_art_id(id)
 if Store.CARDS.has(id):image_path=CardArt.image_path(id,art_id,Store.CARDS)
 var key=image_path
 if textures.has(key):
  var cached=textures[key]; textures.erase(key); textures[key]=cached
  return cached
 var resource = load(image_path) as Texture2D
 if resource == null: return null
 var img = resource.get_image()
 if img.get_width() > img.get_height(): img.rotate_90(CLOCKWISE)
 img.resize(1200,1676,Image.INTERPOLATE_LANCZOS)
 if not img.has_mipmaps(): img.generate_mipmaps()
 var tex = ImageTexture.create_from_image(img)
 # Keep the growing library lazy and bound CPU/GPU cache residency.
 if textures.size()>=48: textures.erase(textures.keys()[0])
 textures[key] = tex
 return tex

func landscape_card(id: String) -> bool:
 var info=Store.CARDS.get(id,{})
 return info.get("landscape",info.get("kind","") in ["符卡","结界"])
func preview_texture(id: String,art_id: String="") -> Texture2D:
 if art_id.is_empty():art_id=editor_art_id(id)
 var original=texture(id,art_id)
 if original==null or not landscape_card(id):return original
 var key="preview:"+id+":"+art_id
 if textures.has(key):return textures[key]
 var img=original.get_image();img.rotate_90(COUNTERCLOCKWISE)
 var result=ImageTexture.create_from_image(img)
 if textures.size()>=48:textures.erase(textures.keys()[0])
 textures[key]=result;return result
func card(parent: Node, id: String, rect: Rect2, clickable: Callable = Callable(),art_id: String="") -> Control:
 var p = box(parent,rect,Color("#172936"),GOLD if id in ["68","70"] else Color("#416078"))
 var art = TextureRect.new()
 art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
 art.texture = texture(id,art_id)
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
 label(screen,"multicolor:arena  /  "+str(ProjectSettings.get_setting("application/config/version")),Rect2(42,22,500,34),20,GOLD)
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
 label(screen,"VERSION "+str(ProjectSettings.get_setting("application/config/version")),Rect2(92,74,900,42),18,GOLD)
 label(screen,"multicolor:arena",Rect2(86,173,760,125),66)
 label(screen,"以色彩为契约，展开你的幻想之战。",Rect2(94,309,740,48),24,MUTED)
 button(screen,"人机对战    →",Rect2(96,422,440,70),setup,true)
 button(screen,"联网对战",Rect2(96,512,440,64),online)
 button(screen,"编辑牌组",Rect2(96,594,440,64),func(): editor())
 button(screen,"设置",Rect2(96,676,440,64),settings)
 button(screen,"关于",Rect2(96,758,440,64),about)
 button(screen,"退出游戏",Rect2(570,676,280,64),func(): get_tree().quit())
 button(screen,"对局回放",Rect2(570,758,280,64),replays)
 card(screen,"68",Rect2(890,205,255,360)).rotation_degrees = -12
 card(screen,"70",Rect2(1140,250,280,394)).rotation_degrees = 12

func online():
 reload_decks()
 if not is_instance_valid(lan_session):
  lan_session=preload("res://net/lan_session.gd").new();add_child(lan_session);lan_session.initialize()
  lan_session.snapshot_ready.connect(network_snapshot_ready)
  lan_session.replay_finished.connect(func(archive):call_deferred("offer_replay",archive))
 clear_page("online")
 var lobby=preload("res://net/lan_lobby.gd").new();screen.add_child(lobby);lobby.build(self,lan_session)
func network_snapshot_ready():
 if lan_session.latest_snapshot.game_id!=network_game_open:
  network_game_open=lan_session.latest_snapshot.game_id
  call_deferred("return_network_battle")
func return_network_battle():
 if lan_session.latest_snapshot.is_empty():return
 var fresh_game=not is_instance_valid(duel_view) or duel_view.network_session==null or lan_session.local_game_id!=lan_session.latest_snapshot.game_id
 lan_session.snapshots=[lan_session.latest_snapshot.duplicate(true)]
 if not fresh_game:lan_session.snapshots.back().projection.state.presentation_events=[]
 clear_page("battle")
 duel_view=preload("res://scripts/duel_view.gd").new();screen.add_child(duel_view);duel_view.begin(self,{},{},0,0,lan_session)

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
  save_settings())
 screen.add_child(cb)
 var view_cb = CheckButton.new()
 view_cb.text = "游戏内卡牌使用 2D 上方俯视"
 view_cb.position = Vector2(420,370)
 view_cb.size = Vector2(700,60)
 view_cb.button_pressed = top_down_view
 view_cb.toggled.connect(set_top_down_view)
 screen.add_child(view_cb)
 var inspection_cb = CheckButton.new()
 inspection_cb.text = "显示左侧卡牌效果说明栏"
 inspection_cb.position = Vector2(420,450)
 inspection_cb.size = Vector2(700,60)
 inspection_cb.button_pressed = show_card_inspection
 inspection_cb.toggled.connect(set_show_card_inspection)
 screen.add_child(inspection_cb)
 var drag_cb=CheckButton.new()
 drag_cb.text="测试模式：允许拖动卡牌放入战场"
 drag_cb.position=Vector2(420,530)
 drag_cb.size=Vector2(700,60)
 drag_cb.button_pressed=debug_drag_to_field
 drag_cb.toggled.connect(set_debug_drag_to_field)
 screen.add_child(drag_cb)

func save_settings():
 var f = FileAccess.open(settings_path,FileAccess.WRITE)
 if f:
  f.store_string(JSON.stringify({"fullscreen":fullscreen,"top_down_view":top_down_view,"show_card_inspection":show_card_inspection,"debug_drag_to_field":debug_drag_to_field}))
  f.close()
 else: alert("无法保存设置。")

func set_top_down_view(value: bool):
 top_down_view=value
 save_settings()

func set_show_card_inspection(value: bool):
 show_card_inspection=value
 save_settings()

func set_debug_drag_to_field(value: bool):
 debug_drag_to_field=value
 save_settings()
 

func editor(sideboarding: bool=false):
 if not sideboarding:reload_decks()
 clear_page("sideboard" if sideboarding else "editor")
 label(screen,"换备牌" if sideboarding else "卡组编辑器",Rect2(24,12,270,46),28,GOLD)
 button(screen,"返回",Rect2(1480,14,100,40),online if sideboarding else func(): guard(menu))
 button(screen,"排序卡组",Rect2(1090,14,156,40),sort_current_deck)
 if not sideboarding:
  var capture_button=button(screen,"卡组截图",Rect2(650,14,156,40),capture_current_deck)
  capture_button.name="DeckCaptureButton"
  var folder_button=button(screen,"打开 deck 文件夹",Rect2(820,14,242,40),open_deck_folder)
  folder_button.name="OpenDeckFolderButton"
  button(screen,"组卡教程",Rect2(1294,14,156,40),show_deck_tutorial)
 box(screen,Rect2(18,72,286,810))
 preview=Control.new()
 preview.position=Vector2(30,88)
 screen.add_child(preview)
 box(screen,Rect2(320,72,902,810))
 name_label=label(screen,"",Rect2(338,80,482,36),23,GOLD)
 if not sideboarding:
  name_label.mouse_filter=Control.MOUSE_FILTER_STOP
  name_label.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
  name_label.tooltip_text="双击卡组名称可重命名"
  name_label.gui_input.connect(on_deck_title_input)
 counts=label(screen,"",Rect2(338,818,858,32),17,MUTED)
 deck_canvas=Control.new()
 deck_canvas.position=Vector2(334,126)
 deck_canvas.size=Vector2(874,680)
 screen.add_child(deck_canvas)
 var rules=OptionButton.new()
 rules.name="DeckRuleSet"
 rules.position=Vector2(826,78)
 rules.size=Vector2(250,40)
 rules.tooltip_text="无限制：普通同名最多 4 张，终言 1 张，限制级 2 张。\n官限：另有三张限 2，禁用线下独占卡。\n官限有限定卡：三张限 2，可以使用线下独占卡。\n测试卡组：所有卡均可加入，同名张数不限。"
 for index in range(RuleSet.IDS.size()):rules.add_item("规则集："+RuleSet.LABELS[index])
 rules.select(maxi(0,RuleSet.IDS.find(str(draft.get("rule_set",RuleSet.OFFICIAL)))))
 rules.disabled=sideboarding
 rules.item_selected.connect(func(index):change_deck_rule_set(RuleSet.IDS[index]))
 screen.add_child(rules)
 if sideboarding:
  box(screen,Rect2(1238,72,344,810))
  label(screen,"调整方法",Rect2(1252,92,314,36),23,GOLD)
  var instructions=label(screen,"左键单击卡牌，或拖到另一卡组：移动 1 张。\n右键：预览卡牌。\n可暂时超过副卡组上限；完成时须恢复主卡组张数，并符合副卡组上限与登记牌池。",Rect2(1252,138,314,145),17,MUTED)
  instructions.name="SideboardInstructions"
  instructions.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
  sideboard_status=label(screen,"",Rect2(1252,300,314,290),20,GOLD)
  sideboard_status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
  sideboard_done=button(screen,"更换完成",Rect2(1252,756,314,64),complete_sideboard,true)
  update_preview();update_deck_rows();sideboard_changed()
  return
 box(screen,Rect2(1238,72,344,810))
 var search=LineEdit.new()
 search.name="LibrarySearch"
 search.placeholder_text="名称 / 红蓝单位 / 单蓝普通符卡"
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
 kind.name="LibraryKindFilter"
 kind.position=Vector2(1252,190)
 kind.size=Vector2(314,38)
 var kinds=["全部","单位","普通单位","自机单位","符卡","普通符卡","道具","结界"]
 for x in kinds: kind.add_item(x)
 kind.select(maxi(0,kinds.find("自机单位" if filter_kind=="自机" else filter_kind)))
 kind.item_selected.connect(func(i): filter_kind=kind.get_item_text(i); update_library())
 screen.add_child(kind)
 library_sort_choice=OptionButton.new()
 library_sort_choice.name="LibrarySortChoice"
 library_sort_choice.position=Vector2(1252,236)
 library_sort_choice.size=Vector2(314,38)
 for mode in ["类别","颜色值","名字"]:library_sort_choice.add_item("卡库排序："+mode)
 library_sort_choice.select(["类别","颜色值","名字"].find(library_sort_mode))
 library_sort_choice.item_selected.connect(func(index):library_sort_mode=["类别","颜色值","名字"][index]; update_library())
 screen.add_child(library_sort_choice)
 var scroll=ScrollContainer.new()
 scroll.position=Vector2(1252,282)
 scroll.size=Vector2(314,305)
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
 button(screen,"导出代码",Rect2(1252,710,150,42),export_deck)
 button(screen,"导入代码",Rect2(1416,710,150,42),func(): guard(import_dialog))
 button(screen,"新建",Rect2(1252,764,150,42),func(): guard(func(): draft=Store.blank(); dirty=false; editor(); rename_dialog()))
 button(screen,"重命名",Rect2(1416,764,150,42),rename_dialog)
 button(screen,"清空卡组",Rect2(1252,818,150,42),func(): confirm_action("清空当前卡组？",func(): draft.main.clear(); draft.side.clear(); draft.leader=""; dirty=true; update_deck_rows()))
 button(screen,"删除卡组",Rect2(1416,818,150,42),delete_deck_dialog)
 update_preview()
 update_library()
 update_deck_rows()

func change_deck_rule_set(rule_set: String):
 if sideboard_session!=null:return
 if rule_set==str(draft.get("rule_set",RuleSet.OFFICIAL)):return
 Store.prune_for_rule(draft,rule_set)
 dirty=true
 update_preview()
 update_deck_rows()
 update_library()

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
 return info.colors.size()==selected_colors.size() and info.colors.all(func(color): return color in selected_colors)

func update_preview():
 free_children(preview)
 var landscape=landscape_card(selected)
 var picture=card(preview,selected,Rect2(0,0,260,190 if landscape else 350))
 picture.get_child(0).texture=preview_texture(selected)
 var info=Store.CARDS[selected]
 var scroll=ScrollContainer.new()
 scroll.name="CardTextScroll"
 scroll.position=Vector2(0,202 if landscape else 362)
 scroll.size=Vector2(260,501 if landscape else 341)
 scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
 preview.add_child(scroll)
 var column=VBoxContainer.new()
 column.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 column.add_theme_constant_override("separation",12)
 scroll.add_child(column)
 var preview_lines=[info.name,card_description(selected)]
 for index in range(preview_lines.size()):
  if index==1:
   var cost_icons=HexCost.new();column.add_child(cost_icons);cost_icons.configure(info.cost,false,252,34,info.get("variable_cost",""))
  var value=preview_lines[index]
  var text=Label.new()
  text.text=value
  text.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
  text.size_flags_horizontal=Control.SIZE_EXPAND_FILL
  text.add_theme_font_size_override("font_size",20 if value==info.name else 17)
  text.add_theme_color_override("font_color",GOLD if value==info.name else WHITE)
  column.add_child(text)
 if sideboard_session==null:
  if not RuleSet.allowed(selected,info,str(draft.get("rule_set",RuleSet.OFFICIAL))):
   var reason="仅供查看 · 不可加入卡组" if not info.get("constructible",false) or info.get("token",false) else "此规则集不可加入卡组"
   var notice=label(preview,reason,Rect2(0,715,260,43),17,MUTED)
   notice.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
  elif info.kind=="自机":button(preview,"设为自机",Rect2(0,715,260,43),func(): add_to("leader"),true)

func update_library():
 free_children(library)
 library_rows.clear()
 var rule_set=str(draft.get("rule_set",RuleSet.OFFICIAL))
 for id in library_ids():
  var info=Store.CARDS[id]
  var available=RuleSet.allowed(id,info,rule_set)
  var remaining=RuleSet.remaining(draft,id,Store.CARDS,rule_set)
  var row=preload("res://scripts/deck_card.gd").new()
  row.card_id=id
  row.source_zone="library"
  row.draggable=available and remaining!=0
  row.texture_provider=func(): return texture(id)
  row.set_meta("card_id",id)
  row.custom_minimum_size=Vector2(296,64)
  row.add_theme_stylebox_override("panel",style(Color("#142737") if available else Color("#24303a"),Color("#3d5161") if available else MUTED))
  library.add_child(row)
  var full_name=label(row,info.name,Rect2(10,4,222 if available and remaining>=0 else 276,54),17,WHITE if available else MUTED)
  full_name.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
  full_name.clip_text=false
  full_name.mouse_filter=Control.MOUSE_FILTER_IGNORE
  var remaining_label: Label=null
  if available and remaining>=0:remaining_label=label(row,"余 %d" % remaining,Rect2(232,16,54,32),16,GOLD if remaining>0 else MUTED)
  library_rows[id]={"row":row,"remaining_label":remaining_label}
  var reason="仅供查看 · 不可加入卡组" if not info.get("constructible",false) or info.get("token",false) else "此规则集不可加入卡组"
  row.tooltip_text=info.name if available else info.name+"\n"+reason
  if CardArt.options(id,Store.CARDS).size()>1:row.tooltip_text+="\n鼠标中键：更换当前卡组的异画"
  row.preview_requested.connect(func(card_id): selected=card_id; update_preview())
  row.art_requested.connect(open_art_picker)
  row.clicked.connect(func(card_id,_from,_index,right):
   selected=card_id
   update_preview()
   if not right and RuleSet.allowed(card_id,Store.CARDS[card_id],rule_set): add_to("side" if zone=="side" else "main"))
  row.set_drag_forwarding(row._get_drag_data,can_return_card,return_card_to_library)

func choose_card_art(id: String,art_id: String):
 if sideboard_session!=null and sideboard_locked():return
 if not CardArt.valid(id,art_id,Store.CARDS):return
 var key=CardArt.canonical(id,Store.CARDS)
 if draft.get("art_overrides",{}).get(key,"")==art_id:return
 if not draft.has("art_overrides"):draft.art_overrides={}
 draft.art_overrides[key]=art_id
 selected=id;dirty=true
 update_preview();update_deck_rows()

func open_art_picker(id: String):
 if sideboard_session!=null and sideboard_locked():return
 selected=id;update_preview()
 var variants=CardArt.options(id,Store.CARDS)
 if variants.size()<2:
  alert("这张牌暂无可选异画。","更换异画")
  return
 var dialog=AcceptDialog.new()
 dialog.name="CardArtPicker"
 dialog.title="更换异画 · "+Store.CARDS[id].name
 var rows=ceili(variants.size()/3.0)
 var gallery_height=mini(480,rows*244)
 dialog.size=Vector2i(870,gallery_height+100)
 dialog.get_ok_button().text="关闭"
 dialog.confirmed.connect(dialog.queue_free);dialog.canceled.connect(dialog.queue_free)
 var content=VBoxContainer.new();dialog.add_child(content)
 var notice=Label.new();notice.text="仅应用于当前卡组中所有对应牌 · 点击卡面选择";content.add_child(notice)
 var scroll=ScrollContainer.new();scroll.custom_minimum_size=Vector2(840,gallery_height)
 scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;content.add_child(scroll)
 var grid=GridContainer.new();grid.columns=3;grid.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 grid.add_theme_constant_override("h_separation",16);grid.add_theme_constant_override("v_separation",16);scroll.add_child(grid)
 var current=CardArt.selected(draft,id,Store.CARDS)
 if current.is_empty():current=id
 for variant in variants:
  var cell=VBoxContainer.new();cell.custom_minimum_size=Vector2(258,226);grid.add_child(cell)
  var pick=Button.new();pick.name="Art_"+variant.id;pick.custom_minimum_size=Vector2(250,190)
  pick.tooltip_text=variant.label;cell.add_child(pick)
  pick.add_theme_stylebox_override("normal",style(Color("#142737"),GOLD if current==variant.id else MUTED))
  var face=TextureRect.new();face.texture=preview_texture(id,variant.id);face.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
  face.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;face.mouse_filter=Control.MOUSE_FILTER_IGNORE
  pick.add_child(face);face.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);face.offset_left=5;face.offset_top=5;face.offset_right=-5;face.offset_bottom=-5
  var caption=Label.new();caption.text=("✓ " if current==variant.id else "")+variant.label
  caption.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;caption.custom_minimum_size=Vector2(250,38);caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;cell.add_child(caption)
  pick.pressed.connect(func():choose_card_art(id,variant.id);dialog.queue_free())
 add_child(dialog);dialog.popup_centered()

func refresh_library_limits():
 var rule_set=str(draft.get("rule_set",RuleSet.OFFICIAL))
 var counts={}
 for id in draft.main+draft.side:
  if not Store.CARDS.has(id):continue
  var key=RuleSet.name_key(id,Store.CARDS)
  counts[key]=counts.get(key,0)+1
 var leader_key=RuleSet.name_key(draft.leader,Store.CARDS) if Store.CARDS.has(draft.leader) else ""
 for id in library_rows:
  var info=Store.CARDS[id]
  var item=library_rows[id]
  var maximum=RuleSet.limit(id,info,rule_set)
  var remaining=maximum if maximum<0 else maxi(0,maximum-counts.get(RuleSet.name_key(id,Store.CARDS),0))
  if not leader_key.is_empty() and RuleSet.name_key(id,Store.CARDS)==leader_key:remaining=0
  item.row.draggable=RuleSet.allowed(id,info,rule_set) and remaining!=0
  if item.remaining_label!=null:
   item.remaining_label.text="余 %d" % remaining
   item.remaining_label.add_theme_color_override("font_color",GOLD if remaining>0 else MUTED)

func library_ids() -> Array:
 var ids=[]
 var alias_rules=SearchAliases.load_rules()
 var alias_result=library_alias_ids(query,alias_rules)
 var alias_ids=alias_result.ids
 var role_characters=library_role_spell_characters(query,alias_rules)
 var filters=library_query_filters(query)
 var race_characters=library_race_characters(str(filters.get("race","")))
 for id in Store.CARDS:
  var info=Store.CARDS[id]
  if info.get("canonical_id",id)!=id: continue
  if not library_matches_query(id,info,role_characters,alias_ids,alias_result.exclusive,filters,race_characters): continue
  if not library_kind_matches(info,filter_kind): continue
  if not matches_colors(info): continue
  ids.append(id)
 ids.sort_custom(func(a,b):return library_card_less(a,b))
 return ids

func library_matches_query(id: String,info: Dictionary,role_characters: Array,alias_ids: Dictionary,alias_exclusive: bool,filters: Dictionary,race_characters: Array) -> bool:
 var term=query.strip_edges().to_lower()
 if term.is_empty():return true
 if term=="衍生物":return info.get("token",false)
 if term=="梦违":return not info.get("constructible",false) and not info.get("token",false) and ("梦违" in info.name or "梦违" in info.get("rules_text","") or "梦违" in info.get("keywords",[]))
 var required_character=str(info.get("requires_character",""))
 var role_spell=info.kind=="符卡" and not required_character.is_empty() and role_characters.any(func(character):return character==required_character or str(character).begins_with(required_character+"·") or str(character).begins_with(required_character+"・"))
 if not filters.is_empty():
  var race_match=filters.race=="" or filters.race in info.get("race",[]) or library_related_to_race(info,filters.race,race_characters)
  var color_match=library_kind_matches(info,filters.kind) and race_match and (not filters.single or info.colors.size()==1) and filters.colors.all(func(color):return color in info.colors)
  if filters.kind=="普通符卡":return color_match
  return color_match or role_spell or alias_ids.has(id)
 if alias_exclusive:return role_spell or alias_ids.has(id)
 var searchable=[info.name,id,info.get("title",""),info.get("character","")]
 searchable.append_array(info.get("keywords",[]))
 searchable.append_array(info.get("aliases",[]))
 if info.get("token",false):searchable.append("衍生物")
 if not info.get("constructible",false):searchable.append("不可构筑")
 return role_spell or alias_ids.has(id) or searchable.any(func(value):return term in str(value).to_lower())

func library_race_characters(race: String) -> Array:
 if race.is_empty():return []
 var characters=[]
 for info in Store.CARDS.values():
  if race in info.get("race",[]):
   var character=str(info.get("character",""))
   if not character.is_empty() and character not in characters:characters.append(character)
 return characters

func library_related_to_race(info: Dictionary,race: String,characters: Array) -> bool:
 if race.is_empty() or info.kind not in ["符卡","道具","结界"]:return false
 if race in info.name or race in info.get("rules_text",""):return true
 var character=str(info.get("requires_character",""))
 if character.is_empty():character=str(info.get("character",""))
 if character.is_empty():return false
 return characters.any(func(candidate):return character in candidate or candidate in character)

func library_alias_ids(term: String,rules: Dictionary) -> Dictionary:
 return SearchAliases.alias_ids(Store.CARDS,term,rules)

func library_role_spell_characters(term: String,rules: Dictionary) -> Array:
 return SearchAliases.role_spell_characters(Store.CARDS,term,rules)

func library_kind_matches(info: Dictionary, wanted: String) -> bool:
 return SearchAliases.kind_matches(info,wanted)

func library_query_filters(term: String) -> Dictionary:
 var remaining=term.strip_edges().to_lower().replace(" ","").replace("\t","").replace("\n","")
 # "单位" is a category, so its first character is not the monochrome prefix.
 var single=remaining.begins_with("单") and remaining!="单位"
 if single:remaining=remaining.substr(1)
 var kind=""
 for suffix in ["自机单位","普通单位","普通符卡","单位","自机","符卡","道具","结界"]:
  if remaining.ends_with(suffix):
   kind=suffix
   remaining=remaining.substr(0,remaining.length()-suffix.length())
   break
 var race=""
 for race_name in library_races():
  if remaining.ends_with(race_name):
   race=race_name
   remaining=remaining.substr(0,remaining.length()-race_name.length())
   break
 var colors=[]
 for index in range(remaining.length()):
  var color=remaining.substr(index,1)
  if color not in Store.Database.COLORS:return {}
  if color not in colors:colors.append(color)
 if colors.is_empty() and kind.is_empty() and race.is_empty() and not single:return {}
 return {"kind":kind,"race":race,"colors":colors,"single":single}

func library_races() -> Array:
 var found={}
 for info in Store.CARDS.values():
  for race in info.get("race",[]):found[race]=true
 var races=found.keys()
 races.sort_custom(func(a,b):return a.length()>b.length() if a.length()!=b.length() else a.naturalnocasecmp_to(b)<0)
 return races

func library_card_color_value(id: String) -> int:
 var value=0
 for amount in Store.CARDS[id].cost.values():value+=int(amount)
 return value

func library_card_less(a: String,b: String) -> bool:
 var x=Store.CARDS[a]
 var y=Store.CARDS[b]
 if library_sort_mode=="类别" and x.kind!=y.kind:
  var categories=["自机","单位","符卡","道具","结界"]
  return categories.find(x.kind)<categories.find(y.kind)
 if library_sort_mode!="名字":
  var a_value=library_card_color_value(a)
  var b_value=library_card_color_value(b)
  if a_value!=b_value:return a_value<b_value
 if x.name!=y.name:return x.name.naturalnocasecmp_to(y.name)<0
 return a.naturalnocasecmp_to(b)<0

func can_return_card(_at: Vector2, data: Variant) -> bool:
 return valid_drag_source(data) and data.source_zone in ["main","side","leader"]

func valid_drag_source(data: Variant) -> bool:
 if not data is Dictionary or not Store.CARDS.has(data.get("card_id","")): return false
 var source=data.get("source_zone","")
 if sideboard_session!=null and (sideboard_locked() or source not in ["main","side"]):return false
 if source=="library": return RuleSet.allowed(data.card_id,Store.CARDS[data.card_id],str(draft.get("rule_set",RuleSet.OFFICIAL))) and RuleSet.remaining(draft,data.card_id,Store.CARDS,str(draft.get("rule_set",RuleSet.OFFICIAL)))!=0
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
 # Fifty main-deck slots: ten columns by five rows, with an independent leader slot.
 return Rect2(154+(index%10)*70,4+(index/10)*100,67,97)

func update_deck_rows():
 name_label.text=draft.name+(" *" if dirty else "")
 counts.text="主卡组 %d / %d     副卡组 %d / 10     自机 %d / 1" % [draft.main.size(),RuleSet.main_limit(str(draft.get("rule_set",RuleSet.OFFICIAL))),draft.side.size(),0 if draft.leader.is_empty() else 1]
 if sideboard_session!=null:
  counts.text="主卡组 %d / %d     副卡组 %d / 10     自机 1 / 1" % [draft.main.size(),sideboard_original.main.size(),draft.side.size()]
  if not sideboard_waiting and is_instance_valid(sideboard_status):sideboard_status.text=""
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
 make_drop_zone("leader",Rect2(0,0,154,200),main_content)
 if not draft.leader.is_empty(): editor_card(draft.leader,"leader",0,Rect2(4,4,140,195),main_content)
 for i in range(draft.main.size()):
  editor_card(draft.main[i],"main",i,main_card_rect(i),main_content)
 main_scroll.set_deferred("scroll_vertical",old_scroll)
 var side_parent=deck_canvas
 var side_origin=Vector2(9,559)
 if sideboard_session!=null:
  var side_scroll=ScrollContainer.new();side_scroll.name="SideDeckScroll";side_scroll.position=Vector2(0,553);side_scroll.size=Vector2(872,124);side_scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;deck_canvas.add_child(side_scroll)
  side_parent=Control.new();side_parent.custom_minimum_size=Vector2(maxi(872,draft.side.size()*86+12),114);side_scroll.add_child(side_parent)
  make_drop_zone("side",Rect2(Vector2.ZERO,side_parent.custom_minimum_size),side_parent);side_origin=Vector2(9,2)
 else:make_drop_zone("side",Rect2(0,553,872,124))
 for i in range(draft.side.size()):
  editor_card(draft.side[i],"side",i,Rect2(side_origin+Vector2(i*86,0),Vector2(78,109)),side_parent)
 label(deck_canvas,"副卡组",Rect2(5,519,130,32),18,GOLD)
 var color_counts={"红":0,"蓝":0,"绿":0,"黄":0,"黑":0}
 for id in draft.main:
  for color in Store.CARDS[id].colors: color_counts[color]+=1
 var index=0
 for c in color_counts:
  label(deck_canvas,"%s %d" % [c,color_counts[c]],Rect2(146+index*116,519,108,30),18,MUTED)
  index+=1
 if page=="editor" and is_instance_valid(library):refresh_library_limits()

func add_selected(): add_to(zone)
func add_to(target: String):
 var amount = 1 if target=="leader" else add_amount
 var copy = draft.duplicate(true)
 for i in range(amount):
  var error = Store.add_card(copy,selected,target,str(draft.get("rule_set",RuleSet.OFFICIAL)))
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

func on_deck_title_input(event: InputEvent):
 if page=="editor" and event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT and event.double_click:
  rename_dialog()

func show_deck_tutorial():
 var dialog=AcceptDialog.new()
 dialog.name="DeckTutorial"
 dialog.title="组卡教程"
 dialog.min_size=Vector2i(820,680)
 dialog.get_ok_button().text="关闭"
 dialog.confirmed.connect(dialog.queue_free)
 dialog.canceled.connect(dialog.queue_free)
 var guide=RichTextLabel.new()
 guide.name="DeckTutorialText"
 guide.position=Vector2(22,18)
 guide.size=Vector2(776,585)
 guide.bbcode_enabled=true
 guide.text="""[color=#d9b775][b]卡组与规则[/b][/color]
点击右侧“新建”创建卡组；双击中央上方的卡组名称，或点击“重命名”修改名称。选择“规则集”后，卡库会标示卡牌可用性和同名剩余张数；右侧“卡组”下拉框可切换已保存卡组。

[color=#d9b775][b]选牌与编辑[/b][/color]
左侧显示鼠标悬停卡牌的预览。点击中央的自机位打开选择窗，也可将卡库的自机牌拖入自机位。点击右侧卡库中的卡名，向当前主卡组或副卡组加入一张牌；默认加入主卡组。将卡从卡库拖到主卡组或副卡组，也会切换当前加入区域。
主、副卡组中的卡牌左键再加一张，右键移除；在主、副卡组间拖动可移动卡牌，拖回右侧卡库可移除。顶部“排序卡组”整理主、副卡组的排列。

[color=#d9b775][b]搜索与筛选[/b][/color]
搜索框可输入卡名、卡牌编号或别名，例如“西瓜”“530”；输入“天子符卡”可找对应角色的符卡。“密封”显示命定的重逢、大空魔术与两张梦违单位，“密封符卡”显示六张关联符卡。
“小妖梦”“小猫车”分别显示3费妖梦、3费猫车；“炸弹人”指灵乌路空，“夜雀”指米斯蒂娅。“饼”显示2费单色产费道具，可加颜色，如“红饼”“蓝饼”。自机选择、调试选牌及鹿射、八云紫、椛等名称选择也支持这些别名。
可把颜色、类别和种族写在一起：如“红蓝单位”“单蓝普通符卡”“红黑人类”。搜索中的颜色表示“包含这些颜色”；开头加“单”限定单色牌。“普通单位”和“自机单位”分别筛选两类单位，“普通符卡”排除角色符卡。
颜色按钮则严格匹配卡牌的整组颜色，例如同时选红、蓝只显示红蓝双色牌。搜索框、颜色按钮和类别下拉框会叠加筛选；点击“全部”清除颜色筛选。卡库也可按类别、颜色值或名字排序。

[color=#d9b775][b]保存与使用[/b][/color]
右下角可保存、使用、清空或删除卡组，也可导出代码到剪贴板、从代码导入新卡组。鼠标中键点击仓库、主副卡组或自机位的牌可更换异画，仅影响当前卡组的所有对应牌，并同步用于联机显示。顶部“卡组截图”将当前卡组保存为 PNG，并提示完整路径；“打开 deck 文件夹”可查看卡组文件和 image 截图目录。名称后的 * 表示有未保存的修改。保存需要设置自机；正常对战还要求主卡组恰好 50 张。"""
 dialog.add_child(guide)
 add_child(dialog)
 dialog.popup_centered()

func capture_current_deck():
 if page!="editor" or deck_capture_busy:return
 deck_capture_busy=true
 var result=await DeckImage.capture(self,draft.duplicate(true),dirty)
 deck_capture_busy=false
 if result.has("error"):alert(result.error,"截图失败")
 else:alert("卡组截图已保存：\n"+str(result.path),"截图完成")

func open_deck_folder():
 var folder=Store.folder()
 var directory_error=DirAccess.make_dir_recursive_absolute(folder)
 if directory_error!=OK:
  alert("无法创建 deck 文件夹："+error_string(directory_error),"打开失败")
  return
 var open_error=OS.shell_show_in_file_manager(folder)
 if open_error!=OK:alert("无法打开 deck 文件夹："+error_string(open_error),"打开失败")

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
 if not load_error.is_empty(): alert(load_error); return
 var error = Store.validate(draft,false,str(draft.get("rule_set",RuleSet.OFFICIAL)))
 if not error.is_empty(): alert(error,"无法保存"); return
 var next = decks.duplicate(true)
 var found = false
 for i in range(next.size()):
  if next[i].id == draft.id: next[i]=draft.duplicate(true); found=true; break
 if not found: next.append(draft.duplicate(true))
 error = Store.save_file(draft)
 if not error.is_empty(): alert(error,"保存失败"); return
 decks = next
 dirty = false
 editor()

func delete_deck_dialog():
 if not load_error.is_empty(): alert(load_error,"无法删除"); return
 confirm_action("删除卡组「%s」？" % draft.name,func():
  var error=delete_current_deck()
  if not error.is_empty(): alert(error,"删除失败")
  else: editor())

func delete_current_deck(path: String="") -> String:
 if not load_error.is_empty(): return load_error
 var removed_index=-1
 for i in range(decks.size()):
  if decks[i].id==draft.id: removed_index=i; break
 if removed_index<0:
  draft=Store.blank(); dirty=false; zone="main"
  return ""
 var player_id=decks[player_choice].id if player_choice>=0 and player_choice<decks.size() else ""
 var ai_id=decks[ai_choice].id if ai_choice>=0 and ai_choice<decks.size() else ""
 var next=decks.duplicate(true)
 next.remove_at(removed_index)
 var error=Store.delete_file(draft.id) if path.is_empty() else Store.persist(next,path)
 if not error.is_empty(): return error
 # Keep the previous in-memory state until the saved replacement succeeds.
 decks=next
 player_choice=remaining_deck_index(player_id,player_choice)
 ai_choice=remaining_deck_index(ai_id,ai_choice)
 draft=Store.blank() if decks.is_empty() else decks[mini(removed_index,decks.size()-1)].duplicate(true)
 dirty=false; zone="main"
 return ""

func remaining_deck_index(id: String,fallback: int) -> int:
 for i in range(decks.size()):
  if decks[i].id==id: return i
 return clampi(fallback,0,maxi(0,decks.size()-1))

func export_deck():
 var error = Store.validate(draft,false,str(draft.get("rule_set",RuleSet.OFFICIAL)))
 if not error.is_empty(): alert(error,"无法导出"); return
 var code=Store.encode(draft)
 DisplayServer.clipboard_set(code)
 var d=AcceptDialog.new()
 d.title="导出卡组代码"
 d.min_size=Vector2i(690,260)
 label(d,"代码已复制到剪贴板",Rect2(20,20,650,32),18,GOLD)
 var entry=TextEdit.new()
 entry.position=Vector2(20,60)
 entry.size=Vector2(650,145)
 entry.text=code
 entry.editable=false
 d.add_child(entry)
 d.get_ok_button().text="关闭"
 d.confirmed.connect(d.queue_free)
 add_child(d)
 d.popup_centered()
 

func import_dialog():
 var d = ConfirmationDialog.new()
 d.title = "导入卡组代码"
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
 reload_decks()
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
 var test_mode=CheckButton.new()
 test_mode.text="测试模式（手动控制双方）"
 test_mode.position=Vector2(420,585)
 test_mode.size=Vector2(390,40)
 test_mode.button_pressed=debug_mode
 test_mode.toggled.connect(func(value): debug_mode=value; setup())
 screen.add_child(test_mode)
 var free_payment=CheckButton.new()
 free_payment.text="无需付费"
 free_payment.position=Vector2(820,585)
 free_payment.size=Vector2(260,40)
 free_payment.button_pressed=debug_free_payment
 free_payment.disabled=not debug_mode
 free_payment.tooltip_text="测试模式中跳过出牌、异能与攻击的颜色费用"
 free_payment.toggled.connect(func(value): debug_free_payment=value)
 screen.add_child(free_payment)
 button(screen,"开始对战",Rect2(570,654,460,68),start_match,true)
 button(screen,"编辑牌组",Rect2(1080,730,250,50),editor)
 button(screen,"载入测试卡组",Rect2(80,730,270,50),load_test_decks)

func start_match():
 if decks.is_empty(): alert("请选择卡组。"); return
 for i in [player_choice,ai_choice]:
  var error=Store.validate(decks[i],true,str(decks[i].get("rule_set",RuleSet.OFFICIAL)))
  if not error.is_empty():
   alert("「%s」：%s" % [decks[i].name,error],"卡组不合规")
   return
 var your_roll = randi_range(1,6)
 var bot_roll = randi_range(1,6)
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
 var templates=JSON.parse_string(FileAccess.get_file_as_string("res://data/test_precons.json"))
 if not templates is Dictionary: alert("测试套牌模板读取失败"); return
 var positions=[]
 for template in templates.decks:
  var error=Store.validate(template,true)
  if not error.is_empty(): alert(error); return
  var found=-1
  for i in range(decks.size()):
   if decks[i].id==template.id: found=i; break
  if found<0: found=decks.size(); decks.append(template.duplicate(true))
  else: decks[found]=template.duplicate(true)
  positions.append(found)
 player_choice=positions[0]; ai_choice=positions[1]
 setup()

func load_legacy_test_decks():
 for id in ["demo_reimu","demo_marisa"]:
  for d in decks.duplicate():
   if d.id==id: decks.erase(d)
 var reimu=Store.blank("测试 · 灵梦")
 reimu.id="demo_reimu"; reimu.leader="70"; reimu.rule_set=RuleSet.TEST
 var marisa=Store.blank("测试 · 魔理沙")
 marisa.id="demo_marisa"; marisa.leader="68"; marisa.rule_set=RuleSet.TEST
 for i in range(5):
  reimu.main.append_array(["164","164","165","165","167","68","70","99","100","170"])
  marisa.main.append_array(["164","164","165","167","167","68","70","99","100","170"])
 player_choice=decks.size(); ai_choice=decks.size()+1
 decks.append(reimu); decks.append(marisa)
 setup()

func card_description(id: String) -> String:
 return Store.CARDS[id].rules_text

func make_drop_zone(target: String, rect: Rect2, parent: Node = null):
 var panel=box(parent if parent else deck_canvas,rect,Color("#13232f"),GOLD if zone==target else Color("#3b5060"))
 panel.set_drag_forwarding(Callable(),func(_at,data): return valid_drag_source(data),func(_at,data): drop_editor_card(data,target))
 if target=="leader":
  panel.name="LeaderDropZone"
  panel.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
  panel.gui_input.connect(func(event):
   if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT:open_leader_picker())
  if draft.leader.is_empty(): label(panel,"自机",Rect2(20,60,90,40),24,MUTED)

func leader_picker_ids() -> Array:
 var ids=[]
 for id in Store.CARDS:
  var info=Store.CARDS[id]
  if info.kind=="自机" and RuleSet.allowed(id,info,str(draft.get("rule_set",RuleSet.OFFICIAL))) and info.get("canonical_id",id)==id:ids.append(id)
 ids.sort_custom(func(a,b):return Store.CARDS[a].name.naturalnocasecmp_to(Store.CARDS[b].name)<0)
 return ids

func leader_picker_thumb(id: String,cache: Dictionary) -> Texture2D:
 if cache.has(id):return cache[id]
 var resource=load(Store.CARDS[id].image) as Texture2D
 if resource==null:return null
 var image=resource.get_image()
 if image.get_width()>image.get_height():image.rotate_90(CLOCKWISE)
 image.resize(202,276,Image.INTERPOLATE_BILINEAR)
 var thumbnail=ImageTexture.create_from_image(image)
 cache[id]=thumbnail
 return thumbnail

func populate_leader_picker(grid: GridContainer,dialog: AcceptDialog,term: String,cache: Dictionary):
 free_children(grid)
 var search_query=SearchAliases.prepare_query(Store.CARDS,term,SearchAliases.load_rules())
 for id in leader_picker_ids():
  var info=Store.CARDS[id]
  if not SearchAliases.matches_query(info,id,search_query):continue
  var tile=Panel.new()
  tile.custom_minimum_size=Vector2(218,334)
  tile.add_theme_stylebox_override("panel",style(Color("#142737"),GOLD if id==draft.leader else Color("#536b7b")))
  tile.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
  tile.tooltip_text=info.name+"\n点击设为自机"
  tile.set_meta("card_id",id)
  grid.add_child(tile)
  var art=TextureRect.new()
  art.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
  art.texture=leader_picker_thumb(id,cache)
  art.position=Vector2(8,8)
  art.size=Vector2(202,276)
  art.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
  art.mouse_filter=Control.MOUSE_FILTER_IGNORE
  tile.add_child(art)
  var title=label(tile,("✓ " if id==draft.leader else "")+info.name,Rect2(8,289,202,38),15,GOLD if id==draft.leader else WHITE)
  title.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
  title.clip_text=false
  tile.gui_input.connect(func(event):
   if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT:choose_leader_from_picker(id,dialog))
 if grid.get_child_count()==0:label(grid,"没有符合条件的自机",Rect2(0,0,900,36),18,MUTED)

func open_leader_picker():
 if page!="editor" or sideboard_session!=null:return
 if get_node_or_null("LeaderPicker")!=null:return
 var dialog=AcceptDialog.new()
 dialog.name="LeaderPicker"
 dialog.title="选择自机"
 dialog.min_size=Vector2i(976,690)
 dialog.get_ok_button().text="关闭"
 dialog.confirmed.connect(dialog.queue_free)
 dialog.canceled.connect(dialog.queue_free)
 var search=LineEdit.new()
 search.name="LeaderPickerSearch"
 search.placeholder_text="按自机名称、编号或别名筛选"
 search.position=Vector2(20,16)
 search.size=Vector2(936,42)
 dialog.add_child(search)
 var scroll=ScrollContainer.new()
 scroll.position=Vector2(20,70)
 scroll.size=Vector2(936,550)
 scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
 dialog.add_child(scroll)
 var grid=GridContainer.new()
 grid.name="LeaderChoices"
 grid.columns=4
 grid.add_theme_constant_override("h_separation",12)
 grid.add_theme_constant_override("v_separation",12)
 scroll.add_child(grid)
 var thumbnail_cache={}
 search.text_changed.connect(func(value):populate_leader_picker(grid,dialog,value,thumbnail_cache))
 add_child(dialog)
 populate_leader_picker(grid,dialog,"",thumbnail_cache)
 dialog.popup_centered()
 search.grab_focus()

func choose_leader_from_picker(id: String,dialog: AcceptDialog):
 if not is_instance_valid(dialog):return
 selected=id
 if draft.leader!=id:add_to("leader")
 update_preview()
 dialog.queue_free()

func editor_card(id: String, source: String, index: int, rect: Rect2, parent: Node = null):
 var tile=preload("res://scripts/deck_card.gd").new()
 tile.card_id=id
 tile.face_texture=texture(id)
 tile.source_zone=source
 tile.source_index=index
 tile.tooltip_text=Store.CARDS[id].name
 if CardArt.options(id,Store.CARDS).size()>1:tile.tooltip_text+="\n鼠标中键：更换当前卡组的异画"
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
 tile.art_requested.connect(open_art_picker)
 tile.clicked.connect(func(card_id,from,index_in_deck,right):
  selected=card_id
  zone=from
  if sideboard_session!=null:
   update_preview()
   if not right and from in ["main","side"]:drop_editor_card({"card_id":card_id,"source_zone":from,"source_index":index_in_deck},"side" if from=="main" else "main")
   return
  if right:
   if from=="leader": draft.leader=""
   else: draft[from].remove_at(index_in_deck)
   dirty=true
   update_deck_rows()
  elif from=="leader":open_leader_picker()
  else: add_to(from))
 tile.set_drag_forwarding(tile._get_drag_data,func(_at,data): return valid_drag_source(data),func(_at,data): drop_editor_card(data,source))

func drop_editor_card(data: Dictionary, target: String):
 if not valid_drag_source(data) or target not in ["main","side","leader"]: return
 var source=data.get("source_zone","")
 if sideboard_session!=null and (sideboard_locked() or source not in ["main","side"] or target not in ["main","side"]):return
 if source==target: return
 var next=draft.duplicate(true)
 var error=""
 if sideboard_session!=null:
  next[source].remove_at(int(data.source_index))
  next[target].append(data.card_id)
 else:
  if source=="leader":next.leader=""
  elif source in ["main","side"]:
   var source_index=int(data.get("source_index",-1))
   if source_index>=0 and source_index<next[source].size():next[source].remove_at(source_index)
  error=Store.add_card(next,data.card_id,target,str(draft.get("rule_set",RuleSet.OFFICIAL)))
 if not error.is_empty(): alert(error); return
 draft=next
 dirty=true
 zone=target
 update_deck_rows()

func use_deck():
 var error=Store.validate(draft,false,str(draft.get("rule_set",RuleSet.OFFICIAL)))
 if not error.is_empty(): alert(error); return
 save_deck()
 if dirty: return
 for i in range(decks.size()):
  if decks[i].id==draft.id: player_choice=i; break
 setup()


func about():
 clear_page("about")
 about_code=""
 var title=label(screen,"关于",Rect2(100,210,1400,70),44,GOLD)
 title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
 var version=label(screen,"multicolor:arena  "+str(ProjectSettings.get_setting("application/config/version")),Rect2(100,295,1400,44),24,GOLD)
 version.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
 var body=label(screen,"本作品基于开源游戏引擎godot和东方project的二次创作“极彩multicolor”，由chatgpt辅助代码\n所制成。所有卡图等知识产权均归属于社团“The 495th Complex”",Rect2(100,365,1400,90),32)
 body.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
 if debug_mode:
  var state=label(screen,"调试模式已开启",Rect2(100,495,1400,44),22,GOLD)
  state.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
  button(screen,"退出调试模式",Rect2(670,571,260,50),func(): debug_mode=false; about())
 button(screen,"返回",Rect2(670,660,260,54),menu)

func _unhandled_key_input(event: InputEvent):
 if page!="about" or not event is InputEventKey or not event.pressed or event.echo: return
 if event.unicode<=0: return
 about_code=(about_code+String.chr(event.unicode).to_lower()).right(10)
 if about_code=="multicolor": debug_mode=true; about()

func sort_current_deck():
 if sideboard_session!=null and sideboard_locked():return
 var before=JSON.stringify([draft.main,draft.side])
 Store.sort_deck(draft,"类别")
 if JSON.stringify([draft.main,draft.side])!=before: dirty=true
 update_deck_rows()

func open_sideboard(session):
 if session.room.get("status","")!="between" or not session.can_act() or session.room.ready[session.seat]:return
 sideboard_previous={"draft":draft.duplicate(true),"dirty":dirty,"selected":selected,"zone":zone}
 sideboard_session=session;sideboard_original=session.room.own_deck.duplicate(true)
 draft=sideboard_original.duplicate(true);dirty=false;selected=draft.leader;zone="main";sideboard_waiting=false
 if not session.changed.is_connected(sideboard_changed):session.changed.connect(sideboard_changed)
 if not session.error_raised.is_connected(sideboard_error):session.error_raised.connect(sideboard_error)
 editor(true)

func sideboard_locked() -> bool:
 return sideboard_session==null or sideboard_waiting or not sideboard_session.can_act()

func complete_sideboard():
 if sideboard_locked():return
 var error=preload("res://net/series_controller.gd").sideboard_error(draft,sideboard_original,sideboard_session.room.strict,sideboard_session.room.get("rule_set",RuleSet.UNRESTRICTED))
 if not error.is_empty():sideboard_status.text=error;return
 sideboard_waiting=true;sideboard_done.disabled=true;sideboard_status.text="正在确认更换…"
 sideboard_session.room_action({"name":"deck","deck":draft.duplicate(true)})

func sideboard_changed():
 if page!="sideboard" or sideboard_session==null:return
 if sideboard_session.room.get("status","")!="between":
  sideboard_waiting=false;sideboard_done.disabled=true;sideboard_status.text=sideboard_session.connection_status() if sideboard_session.ended() else "当前已不能换备牌";return
 if sideboard_waiting and not sideboard_session.busy and sideboard_session.room.own_deck==draft:
  online();return
 sideboard_done.disabled=sideboard_locked()
 if not sideboard_session.can_act():sideboard_status.text=sideboard_session.connection_status()
 elif not sideboard_waiting:sideboard_status.text=""

func sideboard_error(error: String):
 if page!="sideboard":return
 sideboard_waiting=false;sideboard_done.disabled=sideboard_locked();sideboard_status.text=error

func restore_editor_draft():
 if sideboard_session!=null:
  if sideboard_session.changed.is_connected(sideboard_changed):sideboard_session.changed.disconnect(sideboard_changed)
  if sideboard_session.error_raised.is_connected(sideboard_error):sideboard_session.error_raised.disconnect(sideboard_error)
 if not sideboard_previous.is_empty():
  draft=sideboard_previous.draft;dirty=sideboard_previous.dirty;selected=sideboard_previous.selected;zone=sideboard_previous.zone
 sideboard_session=null;sideboard_previous={};sideboard_original={};sideboard_waiting=false

func reload_decks():
 var a=decks[player_choice].id if player_choice>=0 and player_choice<decks.size() else ""
 var b=decks[ai_choice].id if ai_choice>=0 and ai_choice<decks.size() else ""
 var loaded=Store.load_decks()
 if loaded.has("error"):load_error=loaded.error;return
 load_error="";decks=loaded.decks
 player_choice=remaining_deck_index(a,player_choice);ai_choice=remaining_deck_index(b,ai_choice)
 if not dirty and not draft.is_empty():
  for d in decks:
   if d.id==draft.id:draft=d.duplicate(true);break
 if not loaded.get("warnings",[]).is_empty():call_deferred("alert","卡组加载提示：\n"+"\n".join(loaded.warnings))

func offer_replay(archive):
 if archive.prompted or archive.frames.is_empty():return
 if get_children().any(func(child):return child is AcceptDialog and child.visible):
  await get_tree().create_timer(0.3).timeout
  offer_replay(archive);return
 archive.prompted=true
 var dialog=ConfirmationDialog.new();dialog.title="保存回放";dialog.dialog_text="对局已结束，是否保存回放？"
 dialog.min_size=Vector2i(520,180);dialog.get_ok_button().text="保存";dialog.get_cancel_button().text="不保存"
 dialog.confirmed.connect(func():
  dialog.hide()
  var result=archive.save()
  if result.has("error"):alert(result.error,"回放保存失败")
  else:alert("已保存至：\n"+result.path,"回放已保存")
  dialog.queue_free())
 dialog.canceled.connect(dialog.queue_free);add_child(dialog);dialog.popup_centered()

func replays():
 clear_page("replays");header("对局回放",menu)
 label(screen,"replay / .mreply",Rect2(80,151,1350,42),22,GOLD)
 var folder=Store.Paths.root().path_join("replay");Store.Paths.initialize()
 var scroll=ScrollContainer.new();scroll.position=Vector2(80,217);scroll.size=Vector2(1440,630);screen.add_child(scroll)
 var list=VBoxContainer.new();list.size_flags_horizontal=Control.SIZE_EXPAND_FILL;list.add_theme_constant_override("separation",16);scroll.add_child(list)
 var files=DirAccess.get_files_at(folder);files.reverse()
 for filename in files:
  if filename.get_extension().to_lower()!="mreply":continue
  var row=Button.new();row.text=filename;row.custom_minimum_size=Vector2(1380,64);list.add_child(row)
  row.pressed.connect(func():
   var result=preload("res://scripts/replay_archive.gd").read(folder.path_join(filename))
   if result.has("error"):alert(result.error,"无法播放");return
   clear_page("battle")
   replay_controller=preload("res://scripts/replay_player.gd").new();screen.add_child(replay_controller)
   replay_controller.error_raised.connect(func(error):alert(error))
   replay_controller.build(self,result.archive))
 if list.get_child_count()==0:
  var empty=Label.new();empty.text="暂无回放";list.add_child(empty)
