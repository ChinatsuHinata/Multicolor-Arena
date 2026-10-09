extends Control
# Replace this with a res:// image path to change the battlefield background.
@export_file("*.png", "*.jpg", "*.webp") var battlefield_background: String = "res://recourse/垫子3.png"
const CARD_BACK_PATH = "res://recourse/卡背.jpg"
const Store = preload("res://scripts/deck_store.gd")
const CardArt=preload("res://scripts/card_art.gd")
const RuleSet = preload("res://scripts/deck_rule_set.gd")
const Series=preload("res://net/series_controller.gd")
const SearchAliases=preload("res://scripts/card_search_aliases.gd")
const CardNameSearchPanel=preload("res://scripts/card_name_search_panel.gd")
const AndroidSwipeScroll=preload("res://scripts/android_swipe_scroll.gd")
const DeckImage=preload("res://scripts/deck_image_export.gd")
const CostDisplay=preload("res://scripts/card_cost_display.gd")
const HexCost=preload("res://scripts/cost_hex_display.gd")
const LocalExperiment=preload("res://scripts/ai/local_experiment.gd")
const AccountSessionStore=preload("res://scripts/account_session_store.gd")
const PatchService=preload("res://scripts/pck_patch_service.gd")
const PckAutoUpdater=preload("res://scripts/pck_auto_updater.gd")
const RoomJoinSound=preload("res://scripts/room_join_sound.gd")
const GOLD = Color("#e8c77e")
const INK = Color("#101c28")
const MUTED = Color("#b2c2ce")
const WHITE = Color("#e8edf0")
const UILayout=preload("res://scripts/ui_layout.gd")
var ui_metrics=UILayout.new()
var editor_ui
var menu_popup
var tutorial_ui
var tutorial_directory_ui
var tutorial_progress=preload("res://scripts/tutorial/progress.gd").new()
# Entries are discovered from the tutorial catalog; progress uses stable IDs.
var tutorial_entries: Array = []
var tutorial_catalog_errors: Array = []
var tutorial_local_directory="user://tutorials"
var completed_tutorials: Dictionary = {}
var android_editor_overview=false
var android_editor_main_page=0
var layout_dpi_override=0.0
var layout_safe_override=Rect2()
var layout_pending=false
var last_display_safe=Rect2i()
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
var saved_select: Button
var deck_picker_ui
var deck_picker_layout_changed=false
var player_choice = 0
var ai_choice = 0
var experimental_ai=false
var experiment_model_path=LocalExperiment.default_model_path()
var textures = {}
var duel_view
var lan_session
var network_game_open=""
var status = ""
var debug_mode=false
var debug_free_payment=false
var debug_drag_to_field=false
var is_android=OS.has_feature("android")
var android_swipe_scroll=AndroidSwipeScroll.new()
var suppress_swipe_mouse_until=0
var suppress_swipe_mouse_point=Vector2(-10000,-10000)
var about_code=""
var fullscreen = false
var top_down_view = false
var show_card_inspection = true
var delay_turn_end = true
var auto_camera_focus = true
var android_manual_camera = false
var android_zone_shortcuts = true
var android_zone_shortcut_positions: Dictionary = {}
var room_join_volume=RoomJoinSound.DEFAULT_VOLUME
var room_join_sound
var replay_training_mode = false
var is_test_build=OS.has_feature("debug")
var add_amount = 1
var zone_buttons = {}
var settings_path = "res://saves/settings.json" if OS.has_feature("editor") else "user://settings.json"
var sideboard_session
var sideboard_original={}
var sideboard_previous={}
var sideboard_waiting=false
var sideboard_status: Label
var sideboard_info: Label
var sideboard_leader_card: Control
var sideboard_done: Button
var replay_controller
var account_name=""
var account_nickname=""
var account_elo=1000
var account_rank: Dictionary={}
var account_token=""
var account_remember_token=""
var account_session_path=AccountSessionStore.DEFAULT_PATH
var account_notice=""
var account_action=""
var account_mode="login"
var account_pending=false
var account_client
var auto_pck_updater
var compatible_patch_service
var auto_patch_update_in_editor=false
var auto_pck_origin=PckAutoUpdater.ORIGIN
var auto_patch_check_pending=false
var auto_patch_restart_required=false
var auto_patch_dialog: AcceptDialog
var auto_patch_status: Label
var auto_patch_progress: ProgressBar
var auto_patch_reopen: Button
var account_status_label: Label
var account_username_input: LineEdit
var account_password_input: LineEdit
var account_confirm_input: LineEdit
var account_old_password_input: LineEdit
var account_password_change_button: Button
var deck_account_return=""
var deck_plaza_ui
var deck_plaza_form={}
var deck_plaza_browser={}
var cloud_edit_post={}
var cloud_edit_deck_id=""
var cloud_edit_account=""
var deck_plaza_server_url=preload("res://scripts/deck_plaza_client.gd").Account.SERVER_URL
func _ready():
 if not is_android:
  get_window().content_scale_aspect=Window.CONTENT_SCALE_ASPECT_KEEP
 var f = SystemFont.new()
 f.font_names = PackedStringArray(["Microsoft YaHei UI", "Microsoft YaHei", "Noto Sans CJK SC"])
 var t = Theme.new()
 t.default_font = f
 t.default_font_size = 18
 theme = t
 refresh_ui_metrics()
 get_viewport().size_changed.connect(queue_layout_refresh)
 if is_android:
  var safe_timer=Timer.new();safe_timer.wait_time=0.75;add_child(safe_timer)
  last_display_safe=DisplayServer.get_display_safe_area()
  safe_timer.timeout.connect(func():
   var current=DisplayServer.get_display_safe_area()
   if current!=last_display_safe:
    last_display_safe=current;queue_layout_refresh())
  safe_timer.start()
 var loaded = Store.load_decks()
 var cleanup_timer=Timer.new()
 cleanup_timer.name="DeletedDeckCleanupTimer"
 cleanup_timer.wait_time=Store.DELETED_CLEANUP_INTERVAL
 cleanup_timer.timeout.connect(func():
  var cleanup=Store.cleanup_deleted_files()
  for warning in cleanup.warnings:push_warning(warning))
 add_child(cleanup_timer)
 cleanup_timer.start()
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
   delay_turn_end = saved_settings.get("delay_turn_end", true) == true
   auto_camera_focus = saved_settings.get("auto_camera_focus", true) == true
   android_manual_camera = saved_settings.get("android_manual_camera", false) == true
   android_zone_shortcuts = saved_settings.get("android_zone_shortcuts", true) == true
   room_join_volume=RoomJoinSound.normalize_volume(saved_settings.get("room_join_volume",RoomJoinSound.DEFAULT_VOLUME))
   if saved_settings.get("android_zone_shortcut_positions") is Dictionary:
    android_zone_shortcut_positions = saved_settings.android_zone_shortcut_positions
   debug_drag_to_field = saved_settings.get("debug_drag_to_field", false) == true
   replay_training_mode = is_test_build and not is_android and saved_settings.get("replay_training_mode", false) == true
   if saved_settings.get("completed_tutorials") is Dictionary:
    completed_tutorials = saved_settings.completed_tutorials.duplicate()
 if fullscreen: DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
 load_tutorial_catalog()
 tutorial_progress.directory=settings_path.get_base_dir().path_join("tutorial_progress")
 menu()
 call_deferred("restore_account")
 if not load_error.is_empty(): alert(load_error)
 elif not loaded.get("warnings",[]).is_empty():
  call_deferred("alert","卡组加载提示：\n"+"\n".join(loaded.warnings))
 if not patch_manager().startup_error.is_empty():call_deferred("alert",patch_manager().startup_error,"补丁加载失败")

func _input(event: InputEvent):
 if page=="tutorial_scene":return # The embedded native surface owns its input.
 if deck_picker_open():deck_picker_ui.handle_input(event);return
 if menu_popup_open():return
 if not is_android or page=="battle":return
 if page=="editor" and editor_ui!=null and editor_ui.handle_touch(event):return
 if page=="editor" and get_viewport().gui_is_dragging():
  android_swipe_scroll.reset()
  return
 if android_swipe_scroll.handle(event,self):
  if page=="editor" and editor_ui!=null:editor_ui.cancel_touch_holds()
  suppress_swipe_mouse_until=Time.get_ticks_msec()+250
  suppress_swipe_mouse_point=event.position
  return
 if (event is InputEventMouseButton or event is InputEventMouseMotion) and Time.get_ticks_msec()<suppress_swipe_mouse_until and event.position.distance_to(suppress_swipe_mouse_point)<28:
  get_viewport().set_input_as_handled()

func enable_android_dialog_swipe(dialog: Window):
 if not is_android:return
 var swipe=AndroidSwipeScroll.new()
 var suppression={"until":0,"point":Vector2(-10000,-10000)}
 dialog.window_input.connect(func(event):
  if swipe.handle(event,dialog):
   suppression.until=Time.get_ticks_msec()+250
   suppression.point=event.position
  elif (event is InputEventMouseButton or event is InputEventMouseMotion) and Time.get_ticks_msec()<suppression.until and event.position.distance_to(suppression.point)<28:
   dialog.set_input_as_handled())

func enable_android_popup_swipe(popup: PopupMenu):
 if not is_android:return
 var gesture={"finger":-1,"last_y":0.0,"travel":0.0,"suppress_until":0,"suppress_point":Vector2.ZERO}
 popup.window_input.connect(func(event):
  if event is InputEventScreenTouch:
   if event.pressed and gesture.finger<0:
    gesture.finger=event.index;gesture.last_y=event.position.y;gesture.travel=0.0
   elif not event.pressed and event.index==gesture.finger:
    gesture.finger=-1
   return
  if event is InputEventScreenDrag and event.index==gesture.finger:
   gesture.travel+=gesture.last_y-event.position.y
   gesture.last_y=event.position.y
   if absf(gesture.travel)<72.0:return
   var wheel=InputEventMouseButton.new()
   wheel.button_index=MOUSE_BUTTON_WHEEL_DOWN if gesture.travel>0 else MOUSE_BUTTON_WHEEL_UP
   wheel.position=Vector2(popup.size)*0.5
   wheel.pressed=true
   wheel.factor=1.0
   gesture.suppress_until=Time.get_ticks_msec()+250
   gesture.suppress_point=event.position
   gesture.travel=0.0
   popup.push_input(wheel,true)
   return
  if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and Time.get_ticks_msec()<gesture.suppress_until and event.position.distance_to(gesture.suppress_point)<28:
   popup.set_input_as_handled())

func _draw():
 if page=="battle": return
 draw_rect(Rect2(Vector2.ZERO,size), Color("#09121d"))
 for i in range(22):
  draw_circle(Vector2(size.x*0.72,size.y*0.45),520-i*18,Color(0.13,0.28,0.35,0.018+float(i)*0.001))

func clear_page(next: String):
 close_deck_picker()
 close_menu_popup()
 if page=="sideboard" and next!="sideboard":restore_editor_draft()
 if is_instance_valid(screen):
  remove_child(screen)
  screen.queue_free()
 page=next
 refresh_ui_metrics()
 screen = Control.new()
 add_child(screen)
 if is_android:
  screen.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
  screen.position=ui_metrics.safe.position
  screen.size=ui_metrics.safe.size
  if next=="battle":screen.position=Vector2.ZERO;screen.size=get_viewport_rect().size
 else:screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 page = next
 queue_redraw()

func menu_popup_open() -> bool:
 return is_instance_valid(menu_popup) and not menu_popup.is_queued_for_deletion()

func deck_picker_open() -> bool:
 return is_instance_valid(deck_picker_ui) and not deck_picker_ui.is_queued_for_deletion()

func close_deck_picker():
 if not deck_picker_open():deck_picker_ui=null;return
 var focus=deck_picker_ui.previous_focus.get_ref() if deck_picker_ui.previous_focus!=null else null
 deck_picker_ui.get_parent().remove_child(deck_picker_ui);deck_picker_ui.queue_free();deck_picker_ui=null
 if is_instance_valid(focus) and not focus.is_queued_for_deletion() and focus.is_visible_in_tree():focus.grab_focus()
 if deck_picker_layout_changed:deck_picker_layout_changed=false;queue_layout_refresh()

func open_deck_picker(callback: Callable,current_id: String="",title: String="选择套牌"):
 close_deck_picker();close_menu_popup();reload_decks()
 deck_picker_ui=preload("res://scripts/deck_picker.gd").new()
 deck_picker_ui.app=self;deck_picker_ui.callback=callback;deck_picker_ui.selected_id=current_id;deck_picker_ui.caption=title
 var focus=get_viewport().gui_get_focus_owner()
 if focus!=null:deck_picker_ui.previous_focus=weakref(focus)
 screen.add_child(deck_picker_ui)

func deck_choice_caption(index: int) -> String:
 return "选择卡组："+str(decks[index].name) if index>=0 and index<decks.size() else "选择卡组"

func open_editor_deck_picker():
 open_deck_picker(func(index):
  var chosen=decks[index].duplicate(true)
  if chosen.id==draft.id:return
  guard(func():draft=chosen;dirty=false;editor()),str(draft.get("id","")),"选择要编辑的套牌")

func open_match_deck_picker(seat: int):
 var index=player_choice if seat==0 else ai_choice
 var current_id=str(decks[index].id) if index>=0 and index<decks.size() else ""
 open_deck_picker(func(chosen):
  if seat==0:player_choice=chosen
  else:ai_choice=chosen
  setup(),current_id,"选择你的套牌" if seat==0 else "选择人机的套牌")

func close_menu_popup():
 if menu_popup_open():menu_popup.close()
 menu_popup=null

func open_menu_popup(title: String,entries: Array,columns: int=1):
 close_menu_popup()
 android_swipe_scroll.reset()
 if page=="editor" and editor_ui!=null:editor_ui.cancel_touch_holds()
 menu_popup=preload("res://scripts/modal_menu.gd").new()
 screen.add_child(menu_popup)
 menu_popup.closed.connect(func():menu_popup=null)
 menu_popup.build(self,title,entries,columns)

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
 l.add_theme_font_size_override("font_size",ui_metrics.font_size(font_size) if uses_responsive_layout() else font_size)
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
 if is_android and page in ["editor","sideboard","menu"]:ui_metrics.button(b)
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
   if event is InputEventMouseButton and event.pressed!=is_android and event.button_index == MOUSE_BUTTON_LEFT: clickable.call())
 return p

func header(title: String, back: Callable, actions_width: float=0.0) -> Button:
 if is_android and page in ["online","replays"]:
  label(screen,"multicolor:arena",Rect2(0,6,screen.size.x-160-actions_width,32),20,GOLD)
  label(screen,title,Rect2(0,43,screen.size.x-160-actions_width,ui_metrics.hit),32)
  return button(screen,"返回",Rect2(screen.size.x-142,14,138,ui_metrics.hit),back)
 label(screen,"multicolor:arena  /  "+str(ProjectSettings.get_setting("application/config/version")),Rect2(42,22,500,34),20,GOLD)
 label(screen,title,Rect2(42,68,1100,48),32)
 var back_button=button(screen,"返回",Rect2(screen.size.x-146,20,126,ui_metrics.hit) if is_android else Rect2(1430,32,126,46),back)
 box(screen,Rect2(42,126,1514,1),Color("#30424f"),Color("#30424f"))
 return back_button

func alert(message: String, title: String = "提示"):
 var d = AcceptDialog.new()
 d.title = title
 d.dialog_text = message
 d.min_size = Vector2i(540,180)
 d.get_ok_button().text = "知道了"
 d.confirmed.connect(d.queue_free)
 d.canceled.connect(d.queue_free)
 add_child(d)
 style_dialog(d)
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
 style_dialog(d)
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

func main_menu_entries() -> Array:
 return [["游戏教程",tutorials],["人机对战",setup],["联网对战",online],["卡组编辑",func():editor()],["玩家账号",account_page],["对局回放",replays],["设置",settings],["退出游戏",func():get_tree().quit()]]

func menu():
 if not is_android:
  desktop_menu()
  return
 clear_page("menu")
 var margin=MarginContainer.new();screen.add_child(margin);margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 for edge in ["left","right","top","bottom"]:margin.add_theme_constant_override("margin_"+edge,int(ui_metrics.padding))
 var row=HBoxContainer.new();margin.add_child(row);row.add_theme_constant_override("separation",int(ui_metrics.gap))
 var left=VBoxContainer.new();left.name="MainMenuContent";row.add_child(left)
 left.size_flags_horizontal=Control.SIZE_EXPAND_FILL;left.size_flags_vertical=Control.SIZE_EXPAND_FILL;left.size_flags_stretch_ratio=1.15
 var version=Label.new();version.text="VERSION "+str(ProjectSettings.get_setting("application/config/version"));left.add_child(version);version.add_theme_color_override("font_color",GOLD);version.add_theme_font_size_override("font_size",24)
 rank_display(left,true)
 var spacer=Control.new();left.add_child(spacer);spacer.custom_minimum_size.y=ui_metrics.gap
 var actions=main_menu_entries()
 var main_actions=GridContainer.new();main_actions.name="MainMenuActions";main_actions.columns=2;left.add_child(main_actions);main_actions.size_flags_vertical=Control.SIZE_EXPAND_FILL
 main_actions.add_theme_constant_override("h_separation",int(ui_metrics.gap));main_actions.add_theme_constant_override("v_separation",int(ui_metrics.gap))
 for i in range(actions.size()):
  var item=actions[i]
  var b=button(main_actions,item[0],Rect2(),item[1],i==1);b.size_flags_horizontal=Control.SIZE_EXPAND_FILL;b.size_flags_vertical=Control.SIZE_EXPAND_FILL;b.custom_minimum_size=Vector2.ZERO
  b.add_theme_font_size_override("font_size",mini(ui_metrics.body,32))
 var art=Control.new();row.add_child(art);art.size_flags_horizontal=Control.SIZE_EXPAND_FILL;art.mouse_filter=Control.MOUSE_FILTER_IGNORE
 var a=card(art,"68",Rect2(0,0,255,356));var b=card(art,"70",Rect2(0,0,280,391))
 var arrange=func():
  var h=minf(art.size.y*0.62,440);a.size=Vector2(h/1.397,h);b.size=a.size
  a.position=Vector2(art.size.x*0.14,art.size.y*0.18);b.position=Vector2(art.size.x*0.5,art.size.y*0.3)
  a.rotation_degrees=-10;b.rotation_degrees=10
  for tile in [a,b]:tile.get_child(0).size=tile.size-Vector2(10,10)
 art.resized.connect(arrange)

func online():
 var restore_mode_selected=false
 var restore_cloud=false
 var lobby_deck_id=""
 var matching_deck_id=""
 var cloud_form={}
 var focused_cloud_field=""
 var focused_caret=0
 if is_instance_valid(lan_session):lobby_deck_id=str(lan_session.room.get("own_deck",{}).get("id",""))
 if page=="online" and is_instance_valid(screen):
  for child in screen.get_children():
   if child.get_script()==preload("res://net/lan_lobby.gd"):
    if child.deck_index>=0 and child.deck_index<decks.size():lobby_deck_id=str(decks[child.deck_index].id)
    restore_mode_selected=child.mode_selected;restore_cloud=child.cloud_selected
    if child.match_deck_index>=0 and child.match_deck_index<decks.size():matching_deck_id=str(decks[child.match_deck_index].id)
    if restore_cloud and is_instance_valid(child.cloud_title_input):
     cloud_form={"title":child.cloud_title_input.text,"password":child.cloud_password_input.text,"format":child.format_input.selected,"rule":child.rule_input.selected,"slot":child.cloud_host_slot.selected,"strict":child.strict_input.button_pressed}
     var focused=get_viewport().gui_get_focus_owner()
     if focused==child.cloud_title_input:focused_cloud_field="title"
     elif focused==child.cloud_password_input:focused_cloud_field="password"
     if not focused_cloud_field.is_empty():focused_caret=focused.get_caret_column()
    break
 reload_decks()
 if not is_instance_valid(lan_session):
  lan_session=preload("res://net/lan_session.gd").new();add_child(lan_session);lan_session.initialize()
  lan_session.snapshot_ready.connect(network_snapshot_ready)
  lan_session.room_joined.connect(on_room_joined)
  lan_session.rating_updated.connect(func(elo):account_elo=elo)
  lan_session.rank_updated.connect(func(rank):account_rank=rank.duplicate(true))
  lan_session.match_found.connect(preview_room_join_sound)
  lan_session.replay_finished.connect(func(archive):call_deferred("offer_replay",archive))
 lan_session.cloud_token=account_token;lan_session.cloud_nickname=account_nickname
 clear_page("online")
 var lobby=preload("res://net/lan_lobby.gd").new();lobby.deck_index=remaining_deck_index(lobby_deck_id,0)
 lobby.match_deck_index=remaining_deck_index(matching_deck_id,-1) if not matching_deck_id.is_empty() else -1
 screen.add_child(lobby);lobby.build(self,lan_session)
 if restore_cloud:lobby.set_cloud_mode(true)
 if not cloud_form.is_empty() and is_instance_valid(lobby.cloud_title_input):
  lobby.cloud_title_input.text=cloud_form.title
  lobby.cloud_password_input.text=cloud_form.password
  lobby.format_input.selected=cloud_form.format
  lobby.rule_input.selected=cloud_form.rule
  lobby.cloud_host_slot.selected=cloud_form.slot
  lobby.strict_input.button_pressed=cloud_form.strict
  var focus_target=lobby.cloud_title_input if focused_cloud_field=="title" else lobby.cloud_password_input if focused_cloud_field=="password" else null
  if focus_target!=null:
   focus_target.grab_focus.call_deferred()
   focus_target.set_caret_column.call_deferred(focused_caret)

func account_page():
 var focused=get_viewport().gui_get_focus_owner()
 var focused_name=focused.name if focused!=null and focused in [account_username_input,account_password_input,account_confirm_input,account_old_password_input] else ""
 var focused_caret=focused.get_caret_column() if focused is LineEdit and not focused_name.is_empty() else 0
 var saved_username=account_username_input.text if is_instance_valid(account_username_input) and account_username_input.name=="AccountUsername" else ""
 var saved_nickname=account_username_input.text if is_instance_valid(account_username_input) and account_username_input.name=="AccountNickname" else ""
 var saved_password=account_password_input.text if is_instance_valid(account_password_input) else ""
 var saved_confirm=account_confirm_input.text if is_instance_valid(account_confirm_input) else ""
 var saved_old_password=account_old_password_input.text if is_instance_valid(account_old_password_input) else ""
 var saved_status=account_notice if account_action=="resume" and account_pending else account_status_label.text if is_instance_valid(account_status_label) else account_notice
 clear_page("account")
 account_old_password_input=null;account_password_change_button=null
 account_password_input=null;account_confirm_input=null
 var margin=MarginContainer.new();screen.add_child(margin);margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 for edge in ["left","right","top","bottom"]:margin.add_theme_constant_override("margin_"+edge,int(ui_metrics.padding))
 var scroll: ScrollContainer=null
 var center=CenterContainer.new()
 if is_android:
  margin.add_child(center)
  center.size_flags_horizontal=Control.SIZE_EXPAND_FILL
  center.size_flags_vertical=Control.SIZE_EXPAND_FILL
 else:
  scroll=ScrollContainer.new();scroll.name="AccountScroll";margin.add_child(scroll)
  scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
  scroll.add_child(center)
  center.custom_minimum_size=Vector2(maxf(0,screen.size.x-ui_metrics.padding*2-16),maxf(0,screen.size.y-ui_metrics.padding*2))
  center.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 var panel=PanelContainer.new();panel.name="AccountPanel";center.add_child(panel)
 panel.custom_minimum_size.x=minf(1120 if is_android else 560,maxf(0,screen.size.x-ui_metrics.padding*4))
 if is_android and not account_name.is_empty():panel.custom_minimum_size.y=minf(720,screen.size.y-ui_metrics.padding*2)
 var panel_style=ui_metrics.panel_style()
 if is_android:panel_style.set_content_margin_all(minf(ui_metrics.padding,16))
 panel.add_theme_stylebox_override("panel",panel_style)
 var body: Container=HBoxContainer.new() if is_android else VBoxContainer.new();panel.add_child(body)
 body.add_theme_constant_override("separation",int(ui_metrics.gap))
 var info: Container=body
 var form: Container=body
 var compact_hit=clampf((screen.size.y-ui_metrics.padding*4-ui_metrics.gap*8)/6.0,64.0,104.0)
 var compact_font=maxi(24,mini(ui_metrics.body,roundi(compact_hit*0.4)))
 if is_android:
  info=VBoxContainer.new();body.add_child(info)
  info.custom_minimum_size.x=minf(380,panel.custom_minimum_size.x*0.34)
  info.add_theme_constant_override("separation",maxi(8,int(ui_metrics.gap*0.65)))
  var form_parent: Container=body
  if not account_name.is_empty():
   scroll=ScrollContainer.new();scroll.name="AccountSettingsScroll";body.add_child(scroll)
   scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;scroll.follow_focus=true
   scroll.size_flags_horizontal=Control.SIZE_EXPAND_FILL;scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
   scroll.set_meta("android_swipe_prefer_vertical",true)
   form_parent=scroll
  form=VBoxContainer.new();form_parent.add_child(form)
  form.size_flags_horizontal=Control.SIZE_EXPAND_FILL
  form.add_theme_constant_override("separation",maxi(8,int(ui_metrics.gap*0.65)))
 var heading=Label.new();heading.text="玩家账号";heading.add_theme_font_size_override("font_size",ui_metrics.title);heading.add_theme_color_override("font_color",GOLD);info.add_child(heading)
 var note=Label.new();note.text="登录后本机会记住账号，重新打开时自动登录；30 天内未打开需重新登录。同一账号的新登录会使旧设备的云端凭据失效。";note.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;info.add_child(note)
 if is_android:note.add_theme_font_size_override("font_size",mini(ui_metrics.small,32))
 if not account_name.is_empty():
  var current=Label.new();current.text="当前登录："+account_name+" · 昵称："+account_nickname;info.add_child(current)
  if is_android:
   current.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
   current.add_theme_font_size_override("font_size",mini(ui_metrics.small,30))
  var rating=Label.new();rating.name="AccountElo";rating.text="我的 Elo：%d" % account_elo;info.add_child(rating)
  if is_android:rating.add_theme_font_size_override("font_size",mini(ui_metrics.small,30))
  account_username_input=LineEdit.new();account_username_input.name="AccountNickname";account_username_input.text=saved_nickname if not saved_nickname.is_empty() else account_nickname;account_username_input.max_length=20;account_username_input.placeholder_text="设置房间中显示的昵称";form.add_child(account_username_input);account_username_input.custom_minimum_size.y=ui_metrics.hit
  var change=button(form,"保存昵称",Rect2(),account_change_nickname);ui_metrics.button(change);change.disabled=account_pending
  var password_heading=Label.new();password_heading.text="修改密码";form.add_child(password_heading)
  var password_note=Label.new();password_note.text="填写旧密码和新密码，再确认一次新密码后可提交。修改成功后，所有设备需使用新密码重新登录。";password_note.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;form.add_child(password_note)
  if is_android:
   password_heading.add_theme_font_size_override("font_size",compact_font)
   password_note.add_theme_font_size_override("font_size",mini(ui_metrics.small,26))
  account_old_password_input=account_password_field(form,"AccountOldPassword","旧密码",saved_old_password)
  account_password_input=account_password_field(form,"AccountNewPassword","新密码：8–64 位英文字母、数字或英文符号",saved_password)
  account_confirm_input=account_password_field(form,"AccountNewPasswordConfirm","再次输入新密码",saved_confirm)
  account_password_change_button=button(form,"修改密码",Rect2(),account_change_password,true);account_password_change_button.name="AccountChangePassword";ui_metrics.button(account_password_change_button)
  account_refresh_password_button()
  var logout=button(form,"退出账号",Rect2(),account_logout);ui_metrics.button(logout);logout.disabled=account_pending
 else:
  var tabs=HBoxContainer.new();form.add_child(tabs)
  var login_button=button(tabs,"登录",Rect2(),func():account_mode="login";account_page(),account_mode=="login");ui_metrics.button(login_button)
  var register_button=button(tabs,"注册",Rect2(),func():account_mode="register";account_page(),account_mode=="register");ui_metrics.button(register_button)
  account_username_input=LineEdit.new();account_username_input.name="AccountUsername";account_username_input.text=saved_username;account_username_input.placeholder_text="账号：3–24 位英文字母、数字或下划线";account_username_input.max_length=24;form.add_child(account_username_input)
  account_password_input=preload("res://scripts/password_edit.gd").new();account_password_input.name="AccountPassword";account_password_input.text=saved_password;account_password_input.placeholder_text="密码：8–64 位英文字母、数字或英文符号";account_password_input.max_length=64;form.add_child(account_password_input)
  account_password_input.text_changed.connect(func(value):account_password_text_changed(account_password_input,value))
  if account_mode=="register":
   account_confirm_input=preload("res://scripts/password_edit.gd").new();account_confirm_input.name="AccountConfirm";account_confirm_input.text=saved_confirm;account_confirm_input.placeholder_text="再次输入密码（仅英文字符）";account_confirm_input.max_length=64;form.add_child(account_confirm_input)
   account_confirm_input.text_changed.connect(func(value):account_password_text_changed(account_confirm_input,value))
  else:account_confirm_input=null
  for field in [account_username_input,account_password_input,account_confirm_input]:
   if field!=null:field.custom_minimum_size.y=ui_metrics.hit
  var submit=button(form,"注册账号" if account_mode=="register" else "登录",Rect2(),account_submit,true);ui_metrics.button(submit);submit.disabled=account_pending
  account_password_input.text_submitted.connect(func(_value):account_submit())
  if account_confirm_input!=null:account_confirm_input.text_submitted.connect(func(_value):account_submit())
 account_status_label=Label.new();account_status_label.name="AccountStatus";account_status_label.text=saved_status;account_status_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;info.add_child(account_status_label)
 if is_android:account_status_label.add_theme_font_size_override("font_size",mini(ui_metrics.small,30))
 var back=button(form,"返回主菜单" if deck_account_return.is_empty() else "返回套牌编辑器",Rect2(),return_from_account);ui_metrics.button(back)
 if is_android:
  for child in form.get_children():
   if child is Button or child is LineEdit:
    child.custom_minimum_size.y=compact_hit
    child.add_theme_font_size_override("font_size",compact_font)
   elif child is HBoxContainer:
    for tab in child.get_children():
     if tab is Button:
      tab.custom_minimum_size.y=compact_hit
      tab.add_theme_font_size_override("font_size",compact_font)
 var focus_target: LineEdit=null
 if is_instance_valid(account_username_input) and account_username_input.name==focused_name:focus_target=account_username_input
 elif is_instance_valid(account_password_input) and account_password_input.name==focused_name:focus_target=account_password_input
 elif is_instance_valid(account_confirm_input) and account_confirm_input.name==focused_name:focus_target=account_confirm_input
 elif is_instance_valid(account_old_password_input) and account_old_password_input.name==focused_name:focus_target=account_old_password_input
 if focus_target!=null:
  focus_target.grab_focus.call_deferred()
  focus_target.set_caret_column.call_deferred(focused_caret)
  if scroll!=null:scroll.ensure_control_visible.call_deferred(focus_target)

func account_password_field(body: Control,field_name: String,hint: String,value: String) -> LineEdit:
 var field=preload("res://scripts/password_edit.gd").new();field.name=field_name;field.placeholder_text=hint;field.max_length=64;field.text=value;field.editable=not account_pending;field.custom_minimum_size.y=ui_metrics.hit;body.add_child(field)
 field.text_changed.connect(func(text):account_password_text_changed(field,text);account_refresh_password_button())
 field.text_submitted.connect(func(_value):account_change_password())
 return field

func account_password_change_error() -> String:
 if not is_instance_valid(account_old_password_input) or not is_instance_valid(account_password_input) or not is_instance_valid(account_confirm_input):return "请填写旧密码、新密码并确认新密码"
 for field in [account_old_password_input,account_password_input,account_confirm_input]:
  var error=preload("res://scripts/account_client.gd").password_error(field.text)
  if not error.is_empty():return error
 if account_password_input.text!=account_confirm_input.text:return "两次输入的新密码不一致"
 if account_old_password_input.text==account_password_input.text:return "新密码不能与旧密码相同"
 return ""

func account_refresh_password_button():
 if is_instance_valid(account_password_change_button):account_password_change_button.disabled=account_pending or not account_password_change_error().is_empty()

func account_change_password():
 if account_pending or account_token.is_empty() or account_name.is_empty():return
 var error=account_password_change_error()
 if not error.is_empty():account_status_label.text=error;return
 var old_password=account_old_password_input.text
 var new_password=account_password_input.text
 var confirmation=account_confirm_input.text
 account_pending=true;account_action="password";account_status_label.text="正在验证并修改密码…"
 for field in [account_old_password_input,account_password_input,account_confirm_input]:field.clear()
 account_page()
 account_client=preload("res://scripts/account_client.gd").new();add_child(account_client)
 account_client.finished.connect(account_request_finished)
 account_client.change_password(account_name,old_password,new_password,confirmation)

func account_password_text_changed(field: LineEdit,value: String):
 var filtered=preload("res://scripts/account_client.gd").filter_password_chars(value)
 if filtered==value:return
 var caret=field.get_caret_column()
 field.text=filtered
 field.set_caret_column(preload("res://scripts/account_client.gd").filter_password_chars(value.substr(0,caret)).length())
 if is_instance_valid(account_status_label):account_status_label.text="密码只能使用英文字母、数字和英文符号"

func account_submit():
 if account_pending or account_name!="":return
 if account_mode=="register" and account_password_input.text!=account_confirm_input.text:
  account_status_label.text="两次输入的密码不一致";return
 account_pending=true
 account_action=account_mode
 account_status_label.text="正在连接账号服务器…"
 var username=account_username_input.text.strip_edges()
 var password=account_password_input.text
 account_password_input.clear()
 if account_confirm_input!=null:account_confirm_input.clear()
 account_client=preload("res://scripts/account_client.gd").new();add_child(account_client)
 account_client.finished.connect(account_request_finished)
 account_client.submit(account_mode,username,password)

func restore_account():
 if account_pending or not account_name.is_empty():return
 var saved=AccountSessionStore.load_token(preload("res://scripts/account_client.gd").device_id(),account_session_path)
 if saved.is_empty():return
 account_pending=true
 account_action="resume"
 account_notice="正在自动登录…"
 if page=="account":account_page()
 account_client=preload("res://scripts/account_client.gd").new();add_child(account_client)
 account_client.finished.connect(account_request_finished)
 account_client.resume(saved)

func account_change_nickname():
 if account_pending or account_token.is_empty():return
 var value=account_username_input.text.strip_edges()
 if value.is_empty() or value.length()>20:account_status_label.text="昵称须为 1–20 个字符";return
 account_pending=true;account_action="nickname";account_status_label.text="正在保存昵称…"
 account_client=preload("res://scripts/account_client.gd").new();add_child(account_client)
 account_client.finished.connect(account_request_finished)
 account_client.update_nickname(value,account_token)

func account_logout():
 if account_pending or account_token.is_empty():return
 account_pending=true;account_action="logout";account_status_label.text="正在退出账号…"
 var saved=account_remember_token
 account_remember_token=""
 AccountSessionStore.clear(account_session_path)
 account_client=preload("res://scripts/account_client.gd").new();add_child(account_client)
 account_client.finished.connect(account_request_finished)
 account_client.logout(account_token,saved)

func account_request_finished(ok: bool,message: String,username: String):
 account_pending=false
 var returned_token=account_client.session_token if is_instance_valid(account_client) else ""
 var returned_remember_token=account_client.remember_token if is_instance_valid(account_client) else ""
 var returned_nickname=account_client.nickname if is_instance_valid(account_client) else ""
 var returned_elo=account_client.elo if is_instance_valid(account_client) else 1000
 var returned_rank=account_client.rank.duplicate(true) if is_instance_valid(account_client) else {}
 if is_instance_valid(account_client):account_client.queue_free();account_client=null
 if account_action=="logout" or (account_action=="password" and ok):
  account_name="";account_nickname="";account_token="";account_remember_token="";account_elo=1000;account_rank={}
  account_mode="login"
  AccountSessionStore.clear(account_session_path)
  for field in [account_old_password_input,account_password_input,account_confirm_input]:
   if is_instance_valid(field):field.clear()
  if is_instance_valid(lan_session):lan_session.leave(false);lan_session.cloud_token="";lan_session.cloud_nickname=""
  if not ok:message="本机已退出；云端会话将在到期或下次登录时失效。"
 if ok:
  match account_action:
   "login","resume":
    account_name=username;account_nickname=returned_nickname;account_token=returned_token;account_remember_token=returned_remember_token;account_elo=returned_elo;account_rank=returned_rank
    if is_instance_valid(lan_session):lan_session.cloud_token=account_token;lan_session.cloud_nickname=account_nickname
    if not AccountSessionStore.save_token(preload("res://scripts/account_client.gd").device_id(),returned_remember_token,account_session_path):
     message+="；本机未能保存自动登录凭据"
   "register":account_mode="login"
   "nickname":account_nickname=returned_nickname;account_elo=returned_elo;account_rank=returned_rank
 elif account_action=="resume" and message=="自动登录已失效，请重新登录":
  AccountSessionStore.clear(account_session_path)
 account_notice=message
 if ok and account_action in ["login","resume"]:
  auto_patch_check_pending=not OS.has_feature("editor") or auto_patch_update_in_editor
  call_deferred("check_cloud_pck_patch")
 if ok and account_action in ["login","resume"] and not deck_account_return.is_empty():
  var destination=deck_account_return;deck_account_return=""
  call_deferred("upload_current_deck" if destination=="upload" else "open_deck_plaza")
  return
 if page=="menu" and ok:menu()
 if page=="account":
  if ok or account_action=="password":account_page()
  if is_instance_valid(account_status_label):account_status_label.text=message
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
 if not is_android:
  desktop_settings()
  return
 clear_page("settings")
 var layout=preload("res://scripts/menu_ui_layout.gd").new()
 layout.build_settings(self)

func tutorials():
 clear_page("tutorials")
 tutorial_ui=preload("res://scripts/tutorial_list.gd").new()
 tutorial_ui.app=self
 screen.add_child(tutorial_ui)
 if not tutorial_catalog_errors.is_empty():alert("\n".join(tutorial_catalog_errors),"教程目录错误")

func tutorial_editor_available() -> bool:
 return is_test_build and not is_android

func tutorial_editor(path: String=""):
 if not tutorial_editor_available():return
 var data={}
 if not path.is_empty():
  var loaded=preload("res://scripts/tutorial/config.gd").new().load_file(path,Store.CARDS)
  if not loaded.ok:alert("\n".join(loaded.errors),"教程配置错误");return
  data=loaded.data
 clear_page("tutorial_editor")
 var editor=load("res://scripts/tutorial/authoring_editor.gd").new()
 screen.add_child(editor);editor.begin(self,data,path)

func load_tutorial_catalog():
 tutorial_entries=[];tutorial_catalog_errors=[]
 var catalog=JSON.parse_string(FileAccess.get_file_as_string("res://data/tutorial/catalog.json"))
 if not catalog is Dictionary or not catalog.get("lessons") is Array:
  tutorial_catalog_errors.append("教程目录 data/tutorial/catalog.json.lessons 必须是数组");return
 var ids={}
 var paths=catalog.lessons.duplicate()
 var local_dir=tutorial_local_directory
 if DirAccess.dir_exists_absolute(local_dir):
  for filename in DirAccess.get_files_at(local_dir):
   if filename.ends_with(".json"):paths.append(local_dir.path_join(filename))
 for path in paths:
  if not path is String:tutorial_catalog_errors.append("教程目录 lessons：路径必须是字符串");continue
  var loaded=preload("res://scripts/tutorial/config.gd").new().load_file(path,Store.CARDS)
  if not loaded.ok:tutorial_catalog_errors.append_array(loaded.errors);continue
  var lesson=loaded.data
  if ids.has(lesson.id):
   # A local edited copy may intentionally replace a bundled lesson by ID.
   if path.begins_with(local_dir+"/") and not str(ids[lesson.id]).begins_with(local_dir+"/"):
    tutorial_entries=tutorial_entries.filter(func(entry):return entry.id!=lesson.id)
   else:tutorial_catalog_errors.append("教程目录：课程 ID 重复 "+lesson.id);continue
  ids[lesson.id]=path
  tutorial_entries.append({"id":lesson.id,"title":lesson.title,"category":lesson.get("category","beginner"),"path":path,"start":func():tutorial_directory(path)})

func tutorial_directory(path: String):
 var loaded=preload("res://scripts/tutorial/config.gd").new().load_file(path,Store.CARDS)
 if not loaded.ok:alert("\n".join(loaded.errors),"教程配置错误");return
 clear_page("tutorial_directory")
 tutorial_directory_ui=preload("res://scripts/tutorial/directory.gd").new()
 tutorial_directory_ui.app=self;tutorial_directory_ui.course=loaded.data;tutorial_directory_ui.path=path
 screen.add_child(tutorial_directory_ui)

func begin_tutorial(path: String,step_id: String=""):
 var loaded=preload("res://scripts/tutorial/config.gd").new().load_file(path,Store.CARDS)
 if not loaded.ok:alert("\n".join(loaded.errors),"教程配置错误");return
 var lesson=loaded.data
 if step_id.is_empty():step_id=lesson.start_step
 if not tutorial_progress.can_open(lesson,step_id):return
 var saved={}
 if step_id!=lesson.start_step:
  saved=tutorial_progress.snapshot(lesson,step_id,Store.CARDS)
  if saved.is_empty():alert(tutorial_progress.last_error,"教程进度读取失败");return
 var flow=preload("res://scripts/tutorial/runtime.gd").new()
 flow.course_path=path
 flow.checkpoint_ready.connect(func(id,snapshot):
  if not tutorial_progress.save(lesson,id,snapshot) and not tutorial_progress.last_error.is_empty():call_deferred("alert",tutorial_progress.last_error,"教程进度保存失败"))
 flow.previous_checkpoint=func():return tutorial_progress.snapshot(lesson,str(flow.completed_steps.back()),Store.CARDS) if not flow.completed_steps.is_empty() else {}
 flow.completed.connect(func(id):complete_tutorial(id))
 var reason=flow.start(lesson,Store.CARDS)
 if not reason.is_empty():flow.free();alert(reason,"教程初始化失败");return
 if not saved.is_empty() and not flow.restore(saved):flow.free();alert("无法恢复教程步骤。","教程初始化失败");return
 if loaded.data.scenarios.values().any(func(s):return s.has("type")) or loaded.data.steps.values().any(func(s):return s.guide.get("layout")=="side"):
  clear_page("tutorial_scene")
  var course=load("res://scripts/tutorial/scene_view.gd").new()
  screen.add_child(course);course.begin(self,flow)
  return
 clear_page("battle")
 duel_view=preload("res://scripts/duel_view.gd").new()
 duel_view.tutorial_runtime=flow
 screen.add_child(duel_view)
 duel_view.begin(self,{},{},0)

func tutorial_completed(tutorial_id: String) -> bool:
 return completed_tutorials.get(tutorial_id,false)==true

func complete_tutorial(tutorial_id: String) -> bool:
 if tutorial_id.is_empty() or not tutorial_entries.any(func(entry):return str(entry.get("id",""))==tutorial_id):return false
 completed_tutorials[tutorial_id]=true
 save_settings()
 if page=="tutorials" and is_instance_valid(tutorial_ui):tutorial_ui.render_rows()
 return true

func patch_manager():
 var installed=get_node_or_null("/root/PatchManager")
 if installed!=null and installed.has_method("install_chain"):return installed
 if is_instance_valid(compatible_patch_service):return compatible_patch_service
 compatible_patch_service=PatchService.new(false)
 if installed!=null:
  for property in ["base_version","active_version","patch_dir","startup_error","trusted_key"]:
   compatible_patch_service.set(property,installed.get(property))
 add_child(compatible_patch_service)
 return compatible_patch_service

func check_cloud_pck_patch():
 auto_patch_check_pending=false
 if OS.has_feature("editor") and not auto_patch_update_in_editor:return
 if account_name.is_empty():return
 if not is_instance_valid(auto_pck_updater):
  auto_pck_updater=PckAutoUpdater.new()
  auto_pck_updater.origin=auto_pck_origin
  add_child(auto_pck_updater)
  auto_pck_updater.completed.connect(cloud_pck_patch_completed)
  auto_pck_updater.download_started.connect(cloud_pck_download_started)
  auto_pck_updater.download_progress.connect(cloud_pck_download_progress)
 auto_pck_updater.check_for_update(patch_manager())

func cloud_match_blocked() -> bool:
 return auto_patch_check_pending or (is_instance_valid(auto_pck_updater) and auto_pck_updater.busy) or auto_patch_restart_required

func explain_cloud_match_block() -> void:
 if is_instance_valid(auto_patch_dialog):
  auto_patch_dialog.popup_centered()
 elif auto_patch_restart_required:
  alert("游戏补丁已安装，请重启游戏后进入云端对局。","需要重启游戏")
 else:
  alert("正在检查或下载游戏更新，请完成更新后再进入云端对局。","正在更新")

func cloud_pck_download_started(total_bytes: int, patch_count: int) -> void:
 if is_instance_valid(auto_patch_dialog):auto_patch_dialog.hide();auto_patch_dialog.queue_free()
 auto_patch_dialog=AcceptDialog.new()
 auto_patch_dialog.name="AutoPatchDownloadDialog"
 auto_patch_dialog.title="正在下载游戏更新"
 auto_patch_dialog.exclusive=false
 auto_patch_dialog.min_size=Vector2i(560,200)
 auto_patch_dialog.get_label().hide()
 auto_patch_dialog.get_ok_button().text="隐藏，继续下载"
 var content=VBoxContainer.new()
 content.add_theme_constant_override("separation",12)
 auto_patch_dialog.add_child(content)
 auto_patch_status=Label.new();auto_patch_status.name="DownloadStatus";content.add_child(auto_patch_status)
 var content_width=minf(480,ui_metrics.safe.size.x-64) if is_android else 480.0
 auto_patch_status.custom_minimum_size.x=content_width
 auto_patch_status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 auto_patch_progress=ProgressBar.new();auto_patch_progress.name="DownloadProgress";content.add_child(auto_patch_progress)
 auto_patch_progress.custom_minimum_size=Vector2(content_width,32)
 auto_patch_progress.max_value=maxi(1,total_bytes)
 auto_patch_progress.show_percentage=false
 var note=Label.new();note.text="可隐藏弹窗继续使用其他功能；更新完成前无法进入云端对局。";content.add_child(note)
 note.custom_minimum_size.x=content_width
 note.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 add_child(auto_patch_dialog)
 style_dialog(auto_patch_dialog)
 if not is_instance_valid(auto_patch_reopen):
  var layer=CanvasLayer.new();layer.name="AutoPatchProgressLayer";layer.layer=2;add_child(layer)
  auto_patch_reopen=button(layer,"查看更新进度",Rect2(0,0,200,48),func():
   if is_instance_valid(auto_patch_dialog):auto_patch_dialog.popup_centered())
  auto_patch_reopen.name="ShowAutoPatchProgress"
  auto_patch_reopen.anchor_left=1;auto_patch_reopen.anchor_right=1
  auto_patch_reopen.anchor_top=1;auto_patch_reopen.anchor_bottom=1
  auto_patch_reopen.offset_left=-220;auto_patch_reopen.offset_right=-20
  auto_patch_reopen.offset_top=-68;auto_patch_reopen.offset_bottom=-20
 auto_patch_dialog.visibility_changed.connect(func():
  if is_instance_valid(auto_patch_reopen) and is_instance_valid(auto_patch_dialog):auto_patch_reopen.visible=not auto_patch_dialog.visible)
 auto_patch_reopen.hide()
 cloud_pck_download_progress(0,total_bytes,"准备下载 %d 个补丁" % patch_count)
 auto_patch_dialog.popup_centered()

func cloud_pck_download_progress(downloaded_bytes: int,total_bytes: int,stage: String) -> void:
 if not is_instance_valid(auto_patch_dialog):return
 auto_patch_progress.value=downloaded_bytes
 var percent=int(100.0*float(downloaded_bytes)/float(maxi(1,total_bytes)))
 auto_patch_status.text="%s\n%.1f / %.1f MiB · %d%%" % [stage,float(downloaded_bytes)/1048576.0,float(total_bytes)/1048576.0,percent]

func close_cloud_pck_download_dialog() -> void:
 if is_instance_valid(auto_patch_dialog):auto_patch_dialog.hide();auto_patch_dialog.queue_free()
 auto_patch_dialog=null;auto_patch_status=null;auto_patch_progress=null
 if is_instance_valid(auto_patch_reopen):
  auto_patch_reopen.get_parent().queue_free()
 auto_patch_reopen=null

func cloud_pck_patch_completed(result: Dictionary):
 close_cloud_pck_download_dialog()
 if result.has("error"):
  push_warning("云端补丁检查失败："+str(result.error))
  if page=="account" and is_instance_valid(account_status_label):account_status_label.text=str(result.error)
  return
 if not result.get("installed",false):return
 auto_patch_restart_required=true
 if OS.has_feature("editor"):
  alert("已安装 %s 的模拟补丁；重新运行游戏后生效。" % result.version,"PCK 补丁已安装")
 else:
  var notice=ConfirmationDialog.new()
  notice.title="游戏补丁已安装"
  notice.dialog_text="已下载并安装 %s。重新启动游戏后生效。" % result.version
  notice.get_ok_button().text="退出游戏" if is_android else "立即重启"
  notice.get_cancel_button().text="稍后"
  notice.confirmed.connect(func():
   if not is_android:OS.set_restart_on_exit(true)
   get_tree().quit())
  add_child(notice)
  style_dialog(notice)
  notice.popup_centered()

func choose_pck_patch():
 var dialog=FileDialog.new()
 dialog.title="选择 PCK 补丁"
 dialog.file_mode=FileDialog.FILE_MODE_OPEN_FILE
 dialog.access=FileDialog.ACCESS_FILESYSTEM
 dialog.use_native_dialog=true
 dialog.filters=PackedStringArray(["*.pck ; multicolor:arena PCK 补丁","* ; 所有文件"])
 dialog.file_selected.connect(func(path):
  dialog.queue_free()
  var service=patch_manager()
  var details=service.inspect(path,service.active_version)
  if details.has("error"):
   alert(details.error,"补丁校验失败")
   return
  confirm_action("当前版本：%s\n升级至：%s\n\n应用后需要重新启动游戏。" % [details.from,details.to],func():apply_pck_patch(path)))
 dialog.canceled.connect(dialog.queue_free)
 add_child(dialog)
 dialog.popup_centered(Vector2i(1000,650))

func apply_pck_patch(path: String):
 var result=patch_manager().install(path)
 if result.has("error"):
  alert(result.error,"补丁安装失败")
  return
 if is_android:
  var notice=AcceptDialog.new()
  notice.title="补丁已安装"
  notice.dialog_text="补丁将于下次启动生效。点击“退出游戏”后，请重新打开游戏。"
  notice.get_ok_button().text="退出游戏"
  notice.confirmed.connect(func():get_tree().quit())
  add_child(notice)
  style_dialog(notice)
  notice.popup_centered()
 elif OS.has_feature("editor"):
  alert("补丁已保存。请关闭并重新运行游戏以生效。","补丁已安装")
 else:
  OS.set_restart_on_exit(true)
  get_tree().quit()

func save_settings():
 var f = FileAccess.open(settings_path,FileAccess.WRITE)
 if f:
  f.store_string(JSON.stringify({"fullscreen":fullscreen,"top_down_view":top_down_view,"show_card_inspection":show_card_inspection,"delay_turn_end":delay_turn_end,"auto_camera_focus":auto_camera_focus,"android_manual_camera":android_manual_camera,"android_zone_shortcuts":android_zone_shortcuts,"android_zone_shortcut_positions":android_zone_shortcut_positions,"room_join_volume":room_join_volume,"debug_drag_to_field":debug_drag_to_field,"replay_training_mode":replay_training_mode,"completed_tutorials":completed_tutorials}))
  f.close()
 else: alert("无法保存设置。")

func set_room_join_volume(value: float):
 room_join_volume=RoomJoinSound.normalize_volume(value)
 if is_instance_valid(room_join_sound):room_join_sound.set_notification_volume(room_join_volume)
 save_settings()

func preview_room_join_sound():
 if room_join_volume<=0.0:return
 if not is_instance_valid(room_join_sound):
  room_join_sound=RoomJoinSound.new();add_child(room_join_sound)
 room_join_sound.play_notification(room_join_volume)

func on_room_joined():
 if is_instance_valid(lan_session) and lan_session.is_host:preview_room_join_sound()

func set_top_down_view(value: bool):
 top_down_view=value
 save_settings()

func set_show_card_inspection(value: bool):
 show_card_inspection=value
 save_settings()

func set_delay_turn_end(value: bool):
 delay_turn_end=value
 save_settings()

func set_auto_camera_focus(value: bool):
 auto_camera_focus=value
 if is_instance_valid(duel_view):
  duel_view.android_manual_focus_override=-1
  duel_view.sync_automatic_camera_focus()
 save_settings()

func set_android_manual_camera(value: bool):
 android_manual_camera=value
 if is_instance_valid(duel_view):
  duel_view.camera_dragging=false;duel_view.camera_touches.clear();duel_view.camera_touch_mode=""
  duel_view.android_card_touch.cancel()
 save_settings()

func set_android_zone_shortcuts(value: bool):
 android_zone_shortcuts=value
 if is_instance_valid(duel_view) and is_instance_valid(duel_view.android_zone_shortcuts):
  duel_view.android_zone_shortcuts.refresh_visibility()
 save_settings()

func set_android_zone_shortcut_position(key: String,ratio: Vector2):
 android_zone_shortcut_positions[key]=[ratio.x,ratio.y]
 save_settings()

func set_debug_drag_to_field(value: bool):
 debug_drag_to_field=value
 save_settings()

func set_replay_training_mode(value: bool):
 if is_android:
  replay_training_mode=false
  return
 replay_training_mode=is_test_build and not is_android and value
 save_settings()
 if is_instance_valid(replay_controller):replay_controller.update_training_button()
 

func return_from_account():
 var from_deck=not deck_account_return.is_empty()
 deck_account_return=""
 if from_deck:editor()
 else:menu()

func require_deck_login(destination: String) -> bool:
 if not account_token.is_empty() and not account_name.is_empty():return true
 deck_account_return=destination;account_mode="login";account_notice="登录后即可"+("上传套牌" if destination=="upload" else "进入套牌广场")
 account_page()
 if is_instance_valid(account_status_label):account_status_label.text=account_notice
 return false

func deck_login_expired(destination: String,message: String):
 account_name="";account_nickname="";account_token="";account_elo=1000;account_rank={}
 require_deck_login(destination)
 account_notice=message
 if is_instance_valid(account_status_label):account_status_label.text=message

func open_deck_plaza():
 if not require_deck_login("list"):return
 clear_page("deck_plaza")
 deck_plaza_ui=preload("res://scripts/deck_plaza.gd").new();deck_plaza_ui.app=self
 screen.add_child(deck_plaza_ui)

func upload_current_deck():
 if not require_deck_login("upload"):return
 var error=Store.validate(draft,false,str(draft.get("rule_set",RuleSet.OFFICIAL)))
 if not error.is_empty():alert(error,"无法上传套牌");return
 var snapshot=draft.duplicate(true)
 clear_page("deck_plaza")
 deck_plaza_ui=preload("res://scripts/deck_plaza.gd").new();deck_plaza_ui.app=self
 deck_plaza_ui.mode="edit" if editing_uploaded_deck() else "upload";deck_plaza_ui.source_deck=snapshot
 if editing_uploaded_deck():deck_plaza_ui.current_post=cloud_edit_post.duplicate(true)
 screen.add_child(deck_plaza_ui)

func editing_uploaded_deck() -> bool:
 return cloud_edit_post.get("owned",false) and draft.get("id","")==cloud_edit_deck_id and not account_name.is_empty() and cloud_edit_account.to_lower()==account_name.to_lower()

func deck_upload_caption() -> String:
 return "更新套牌" if editing_uploaded_deck() else "上传套牌"

func edit_uploaded_deck(post: Dictionary):
 if not require_deck_login("list"):return
 if not post.get("owned",false):alert("只能编辑自己上传的套牌");return
 var imported=Store.decode(str(post.get("deck_code","")))
 if imported.has("error"):alert(imported.error,"无法编辑套牌");return
 var cloud_deck=imported.deck;cloud_deck.name=str(post.title)
 guard(func():
  cloud_edit_post=post.duplicate(true);cloud_edit_deck_id=cloud_deck.id;cloud_edit_account=account_name
  draft=cloud_deck;dirty=true;deck_plaza_form={};editor())

func editor(sideboarding: bool=false):
 if not is_android:
  editor_ui=null
  desktop_editor(sideboarding)
  return
 if not sideboarding:reload_decks()
 clear_page("sideboard" if sideboarding else "editor")
 editor_ui=preload("res://scripts/deck_editor_layout.gd").new() if sideboarding else preload("res://scripts/android_deck_editor.gd").new()
 editor_ui.build(self,sideboarding)

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
 if not is_android:
  if is_instance_valid(preview):desktop_update_preview()
  return
 if editor_ui!=null and is_instance_valid(preview):editor_ui.update_preview()

func update_library():
 if not is_android:
  desktop_update_library()
  return
 if page=="editor":
  editor_ui.update_library()
  return
 free_children(library)
 library_rows.clear()
 var rule_set=str(draft.get("rule_set",RuleSet.OFFICIAL))
 for id in library_ids():
  var info=Store.CARDS[id]
  var available=RuleSet.allowed(id,info,rule_set)
  var remaining=RuleSet.remaining(draft,id,Store.CARDS,rule_set)
  var row=preload("res://scripts/deck_card.gd").new()
  row.is_android=is_android
  row.card_id=id
  row.source_zone="library"
  row.draggable=available and remaining!=0
  row.texture_provider=func(): return texture(id)
  row.set_meta("card_id",id)
  row.custom_minimum_size=Vector2(0,maxf(ui_metrics.hit,ui_metrics.body*2.8))
  row.size_flags_horizontal=Control.SIZE_EXPAND_FILL
  row.add_theme_stylebox_override("panel",ui_metrics.panel_style())
  library.add_child(row)
  var margin=MarginContainer.new();row.add_child(margin);margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
  for edge in ["left","right","top","bottom"]:margin.add_theme_constant_override("margin_"+edge,8)
  margin.mouse_filter=Control.MOUSE_FILTER_IGNORE
  var line=HBoxContainer.new();margin.add_child(line);line.mouse_filter=Control.MOUSE_FILTER_IGNORE
  var full_name=Label.new();full_name.text=info.name;line.add_child(full_name)
  full_name.size_flags_horizontal=Control.SIZE_EXPAND_FILL
  full_name.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
  full_name.add_theme_font_size_override("font_size",ui_metrics.body)
  full_name.mouse_filter=Control.MOUSE_FILTER_IGNORE
  var remaining_label: Label=null
  if available and remaining>=0:
   remaining_label=Label.new();remaining_label.text="余 %d" % remaining;line.add_child(remaining_label)
   remaining_label.add_theme_font_size_override("font_size",ui_metrics.small)
   remaining_label.add_theme_color_override("font_color",GOLD if remaining>0 else MUTED)
   remaining_label.mouse_filter=Control.MOUSE_FILTER_IGNORE
  full_name.minimum_size_changed.connect(func():row.custom_minimum_size.y=maxf(ui_metrics.hit,full_name.get_minimum_size().y+16))
  library_rows[id]={"row":row,"remaining_label":remaining_label}
  var reason="仅供查看 · 不可加入卡组" if not info.get("constructible",false) or info.get("token",false) else "此规则集不可加入卡组"
  row.tooltip_text=info.name if available else info.name+"\n"+reason
  if CardArt.options(id,Store.CARDS).size()>1:row.tooltip_text+="\n"+("长按：更换当前卡组的异画" if is_android else "鼠标中键：更换当前卡组的异画")
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
 if is_android and page=="editor":editor_ui.queue_gallery_art()

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
 enable_android_dialog_swipe(dialog)
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
  item.row.draggable=not is_android and RuleSet.allowed(id,info,rule_set) and remaining!=0
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
  if filters.kind in ["普通符卡","自机符卡"]:return color_match
  return color_match or role_spell or alias_ids.has(id)
 if alias_exclusive:return role_spell or alias_ids.has(id)
 var searchable=[info.name,id,info.get("title",""),info.get("character",""),info.get("description",""),info.get("rules_text","")]
 searchable.append_array(info.get("keywords",[]))
 searchable.append_array(info.get("aliases",[]))
 if info.get("token",false):searchable.append("衍生物")
 if not info.get("constructible",false):searchable.append("不可构筑")
 return role_spell or alias_ids.has(id) or searchable.any(func(value):return term in str(value).to_lower()) or SearchAliases.name_contains(str(info.name),term) or info.get("aliases",[]).any(func(value):return SearchAliases.name_contains(str(value),term))

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
 return SearchAliases.alias_ids(Store.CARDS,term,rules,SearchAliases.ANDROID_KINDS if is_android else SearchAliases.KINDS)

func library_role_spell_characters(term: String,rules: Dictionary) -> Array:
 return SearchAliases.role_spell_characters(Store.CARDS,term,rules,is_android)

func library_kind_matches(info: Dictionary, wanted: String) -> bool:
 return SearchAliases.kind_matches(info,wanted)

func library_query_filters(term: String) -> Dictionary:
 var remaining=term.strip_edges().to_lower().replace(" ","").replace("\t","").replace("\n","")
 # "单位" is a category, so its first character is not the monochrome prefix.
 var single=remaining.begins_with("单") and remaining!="单位"
 if single:remaining=remaining.substr(1)
 var kind=""
 for suffix in SearchAliases.ANDROID_KINDS if is_android else SearchAliases.KINDS:
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
 if not is_android:return desktop_main_card_rect(index)
 return editor_ui.main_card_rect(index)

func update_deck_rows():
 if not is_android:
  if page in ["editor","sideboard"] and is_instance_valid(deck_canvas):desktop_update_deck_rows()
  return
 if page not in ["editor","sideboard"] or not is_instance_valid(deck_canvas):return
 name_label.text=draft.name+(" *" if dirty else "")
 counts.text="%d/%d·%d/10" % [draft.main.size(),RuleSet.main_limit(str(draft.get("rule_set",RuleSet.OFFICIAL))),draft.side.size()]
 if sideboard_session!=null:
  counts.text="%d/%d·%d/10" % [draft.main.size(),sideboard_original.main.size(),draft.side.size()]
  if not sideboard_waiting and is_instance_valid(sideboard_status):sideboard_status.text=""
  update_sideboard_info()
 editor_ui.update_deck()
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
 enable_android_dialog_swipe(dialog)
 var guide=RichTextLabel.new()
 guide.name="DeckTutorialText"
 guide.position=Vector2(22,18)
 guide.size=Vector2(776,585)
 guide.bbcode_enabled=true
 guide.text="""[color=#d9b775][b]卡组与规则[/b][/color]
点击右侧“新建”创建卡组；双击中央上方的卡组名称，或点击“重命名”修改名称。选择“规则集”后，卡库会标示卡牌可用性和同名剩余张数；右侧“卡组”下拉框可切换已保存卡组。

[color=#d9b775][b]选牌与编辑[/b][/color]
左侧显示鼠标悬停卡牌的预览。点击中央的自机位打开选择窗，也可将卡库的自机牌拖入自机位。点击右侧卡库中的卡名，向当前主卡组或副卡组加入一张牌；默认加入主卡组。将卡从卡库拖到主卡组或副卡组，也会切换当前加入区域。
主、副卡组中的卡牌左键再加一张，右键移除；在同一组的卡牌之间拖动可调整顺序，拖到另一组的卡牌上可直接交换两张，拖到另一组的空白处可移动一张，拖回右侧卡库可移除。顶部“排序卡组”整理主、副卡组的排列。

[color=#d9b775][b]搜索与筛选[/b][/color]
搜索框可输入卡名、卡牌编号或别名，例如“西瓜”“530”；输入“天子符卡”可找对应角色的符卡。“密封”显示命定的重逢、大空魔术与两张梦违单位，“密封符卡”显示六张关联符卡。
“小妖梦”“小猫车”分别显示3费妖梦、3费猫车；“炸弹人”指灵乌路空，“夜雀”指米斯蒂娅。“饼”显示2费单色产费道具，可加颜色，如“红饼”“蓝饼”。自机选择、调试选牌及鹿射、八云紫、椛等名称选择也支持这些别名。
可把颜色、类别和种族写在一起：如“红蓝单位”“单蓝普通符卡”“红黑人类”。搜索中的颜色表示“包含这些颜色”；开头加“单”限定单色牌。“普通单位”和“自机单位”分别筛选两类单位，“普通符卡”排除角色符卡。
颜色按钮则严格匹配卡牌的整组颜色，例如同时选红、蓝只显示红蓝双色牌。搜索框、颜色按钮和类别下拉框会叠加筛选；点击“全部”清除颜色筛选。卡库也可按类别、颜色值或名字排序。

[color=#d9b775][b]保存与使用[/b][/color]
右下角可保存、使用、清空或删除卡组；“导出代码”直接复制到剪贴板，“导入代码”直接读取剪贴板并创建新卡组。鼠标中键点击仓库、主副卡组或自机位的牌可更换异画，仅影响当前卡组的所有对应牌，并同步用于联机显示。顶部“卡组截图”将当前卡组保存为 PNG，并提示完整路径；“打开截图文件夹”可查看 deck/image 截图目录。名称后的 * 表示有未保存的修改。保存需要设置自机；正常对战还要求主卡组恰好 50 张。"""
 if is_android:
  guide.text=guide.text.replace("“普通符卡”排除角色符卡。", "“普通符卡”和“自机符卡”分别筛选通用符卡与角色专属符卡。")
  guide.text=guide.text.replace("顶部“卡组截图”", "卡组页菜单中的“卡组截图”")
  guide.text=guide.text.replace("；“打开截图文件夹”可查看 deck/image 截图目录", "")
  guide.text=guide.text.replace("左侧显示鼠标悬停卡牌的预览。点击中央的自机位打开选择窗，也可将卡库的自机牌拖入自机位。点击右侧卡库中的卡名，向当前主卡组或副卡组加入一张牌；默认加入主卡组。将卡从卡库拖到主卡组或副卡组，也会切换当前加入区域。", "轻点图鉴和卡组列表中的牌即可打开详情。通过详情中的“加入主卡组”或“加入副卡组”添加一张，“移出卡组”移除一张；自机单位也可以加入主副卡组，或选择“设为自机”。详情大图右下角显示同名牌余量，下方按钮切换主、副卡组列表。")
  guide.text=guide.text.replace("主、副卡组中的卡牌左键再加一张，右键移除；在同一组的卡牌之间拖动可调整顺序，拖到另一组的卡牌上可直接交换两张，拖到另一组的空白处可移动一张，拖回右侧卡库可移除。顶部“排序卡组”整理主、副卡组的排列。", "切换到卡组页后，可拖动主、副卡组中的卡牌调整顺序，拖到另一组的卡牌上可交换两张，拖到另一组空白处可移动一张；轻触详情中的“移出卡组”可移除一张。菜单中的“排序”整理主、副卡组。")
  guide.text=guide.text.replace("颜色按钮则严格匹配卡牌的整组颜色，例如同时选红、蓝只显示红蓝双色牌。搜索框、颜色按钮和类别下拉框会叠加筛选；点击“全部”清除颜色筛选。卡库也可按类别、颜色值或名字排序。", "点击顶部搜索栏右侧的“筛选”打开类型、颜色和排序窗口。颜色按钮严格匹配整组颜色，点击“全部”清除颜色筛选；搜索与其他筛选会叠加。每页显示两行四列共八张完整卡面，卡面下方显示余量，使用卡面区两侧箭头翻页。")
  guide.text=guide.text.replace("右下角可保存、使用、清空或删除卡组；", "卡组页右侧可保存卡组，菜单中可清空或删除卡组；图鉴页及卡组页均有“返回主菜单”按钮。")
  guide.text=guide.text.replace("鼠标中键点击仓库、主副卡组或自机位的牌可更换异画", "卡牌详情中的“更换异画”可更换图片")
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

func open_screenshot_folder():
 var folder=DeckImage.folder()
 var directory_error=DirAccess.make_dir_recursive_absolute(folder)
 if directory_error!=OK:
  alert("无法创建截图文件夹："+error_string(directory_error),"打开失败")
  return
 var open_error=OS.shell_open(folder)
 if open_error!=OK:alert("无法打开截图文件夹："+error_string(open_error),"打开失败")

func rename_dialog():
 var d = ConfirmationDialog.new()
 d.title = "卡组名称"
 d.min_size = Vector2i(500,112)
 var content=VBoxContainer.new()
 d.add_child(content)
 var entry = LineEdit.new()
 entry.name="DeckNameEntry"
 entry.text = draft.name
 entry.max_length = 40
 entry.custom_minimum_size=Vector2(450,36)
 content.add_child(entry)
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
 entry.text_submitted.connect(func(_text):d.confirmed.emit())
 add_child(d)
 style_dialog(d)
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
 show_deck_notice("代码已复制到剪贴板")

func import_deck():
 var code=DisplayServer.clipboard_get().strip_edges()
 if code.is_empty():alert("剪贴板为空，请先复制卡组代码。","导入失败");return
 var result=Store.decode(code)
 if result.has("error"):alert(result.error,"导入失败");return
 guard(func():
  draft=result.deck
  dirty=true
  editor()
  show_deck_notice("已从剪贴板导入，请保存卡组"))

func show_deck_notice(message: String):
 var previous=screen.get_node_or_null("DeckCodeNotice")
 if previous:
  screen.remove_child(previous)
  previous.queue_free()
 var notice=label(screen,message,Rect2(320,18,320,34),17,GOLD)
 notice.name="DeckCodeNotice"
 get_tree().create_timer(3.0).timeout.connect(func():
  if is_instance_valid(notice):notice.queue_free())

func setup():
 if not is_android:
  desktop_setup()
  return
 if is_android:debug_mode=false
 reload_decks()
 clear_page("setup")
 player_choice=clampi(player_choice,0,maxi(0,decks.size()-1))
 ai_choice=clampi(ai_choice,0,maxi(0,decks.size()-1))
 var layout=preload("res://scripts/menu_ui_layout.gd").new()
 layout.build_setup(self)

func start_match():
 if is_android:debug_mode=false
 if decks.is_empty(): alert("请选择卡组。"); return
 if experimental_ai and LocalExperiment.available() and not debug_mode:
  var model=LocalExperiment.read_model(experiment_model_path)
  if model.has("error"):alert(model.error,"试验 AI");return
 for i in [player_choice,ai_choice]:
  var error=Store.validate(decks[i],true,str(decks[i].get("rule_set",RuleSet.OFFICIAL)))
  if not error.is_empty():
   alert("「%s」：%s" % [decks[i].name,error],"卡组不合规")
   return
 if debug_mode:
  choose_first_player("测试模式","请选择先后手。")
  return
 var your_roll = randi_range(1,6)
 var bot_roll = randi_range(1,6)
 while your_roll==bot_roll: your_roll=randi_range(1,6); bot_roll=randi_range(1,6)
 if your_roll>bot_roll:
  choose_first_player("你赢得了投点","你投出 %d，人机投出 %d。请选择先后手。" % [your_roll,bot_roll])
 else:
  begin_battle(false)
  alert("你投出 %d，人机投出 %d。人机选择先手。" % [your_roll,bot_roll],"投点结果")

func choose_first_player(title: String,message: String):
 var d=ConfirmationDialog.new()
 d.title=title
 d.dialog_text=message
 d.min_size=Vector2i(540,180)
 d.get_ok_button().text="我方先手"
 d.get_cancel_button().text="我方后手"
 d.confirmed.connect(func(): d.queue_free(); begin_battle(true))
 d.canceled.connect(func(): d.queue_free(); begin_battle(false))
 add_child(d)
 style_dialog(d)
 d.popup_centered()

func begin_battle(first: bool):
 if experimental_ai and LocalExperiment.available() and not debug_mode:
  var model=LocalExperiment.read_model(experiment_model_path)
  if model.has("error"):alert(model.error,"试验 AI");return
 clear_page("battle")
 duel_view=preload("res://scripts/duel_view.gd").new()
 duel_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 screen.add_child(duel_view)
 duel_view.begin(self,decks[player_choice],decks[ai_choice],0 if first else 1)

func choose_experiment_model():
 if not LocalExperiment.available() or debug_mode:return
 var dialog=FileDialog.new()
 dialog.title="选择试验 AI 模型"
 dialog.file_mode=FileDialog.FILE_MODE_OPEN_FILE
 dialog.access=FileDialog.ACCESS_FILESYSTEM
 dialog.filters=PackedStringArray(["*.json ; AI 权重或分类模型包"])
 dialog.current_dir=ProjectSettings.globalize_path("res://work/ai-training")
 dialog.file_selected.connect(func(path):
  var result=LocalExperiment.read_model(path)
  dialog.queue_free()
  if result.has("error"):alert(result.error,"试验 AI");return
  experiment_model_path=path
  setup())
 dialog.canceled.connect(dialog.queue_free)
 add_child(dialog);dialog.popup_centered(Vector2i(1000,650))

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
 panel.set_drag_forwarding(Callable(),func(_at,data): return valid_drag_source(data),func(at,data):
  var insert_at=deck_insert_index(target,at) if data.get("source_zone","")==target else -1
  drop_editor_card(data,target,insert_at))
 if target=="leader":
  panel.name="LeaderDropZone"
  panel.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
  panel.gui_input.connect(func(event):
   if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT:open_leader_picker())
  if draft.leader.is_empty(): label(panel,"自机",Rect2(20,60,90,40),24,MUTED)
 return panel

func deck_insert_index(target: String, at: Vector2) -> int:
 if not is_android:
  if target=="main":
   var row=maxi(0,int(floorf(at.y/100.0)))
   var column=clampi(int(roundf((at.x-154.0)/70.0)),0,10)
   return clampi(row*10+column,0,draft.main.size())
  if target=="side":return clampi(int(roundf(at.x/86.0)),0,draft.side.size())
  return -1
 return editor_ui.insert_index(target,at)

func leader_picker_ids() -> Array:
 var ids=[]
 for id in Store.CARDS:
  var info=Store.CARDS[id]
  if info.kind=="自机" and RuleSet.allowed(id,info,str(draft.get("rule_set",RuleSet.OFFICIAL))) and info.get("canonical_id",id)==id:ids.append(id)
 ids.sort_custom(func(a,b):return Store.CARDS[a].name.naturalnocasecmp_to(Store.CARDS[b].name)<0)
 return ids

func open_leader_picker():
 if page!="editor" or sideboard_session!=null:return
 if get_node_or_null("LeaderPicker")!=null:return
 var layer=Control.new()
 layer.name="LeaderPicker"
 layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 layer.mouse_filter=Control.MOUSE_FILTER_STOP
 add_child(layer)
 var shade=ColorRect.new()
 shade.color=Color(0,0,0,0.7)
 shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 layer.add_child(shade)
 var panel=box(layer,Rect2(30,15,1540,870),INK,GOLD)
 label(panel,"选择自机",Rect2(24,10,600,42),27,GOLD)
 var selector=CardNameSearchPanel.new()
 selector.layout_metrics=ui_metrics
 selector.name="CardNameSearchPanel"
 selector.position=Vector2(0,60)
 panel.add_child(selector)
 var entries=[]
 for id in leader_picker_ids():entries.append({"id":id})
 selector.configure(Store.CARDS,entries,func(id):return preview_texture(id))
 if not draft.leader.is_empty():selector.select_id(draft.leader)
 var choose=button(panel,"设为自机",Rect2(1044,815,220,43),func():
  if not selector.selected_entry.is_empty():choose_leader_from_picker(str(selector.selected_entry.id),layer),true)
 choose.name="ConfirmSelection"
 choose.disabled=selector.selected_entry.is_empty()
 selector.selected.connect(func(_entry):choose.disabled=false)
 button(panel,"关闭",Rect2(1280,815,220,43),func():layer.queue_free())
 if not is_android:selector.search_input.grab_focus()
 call_deferred("fit_card_selector",panel,selector)

func choose_leader_from_picker(id: String,dialog: Control):
 if not is_instance_valid(dialog):return
 selected=id
 if draft.leader!=id:add_to("leader")
 update_preview()
 dialog.queue_free()

func editor_card(id: String, source: String, index: int, rect: Rect2, parent: Node = null):
 var tile=preload("res://scripts/deck_card.gd").new()
 tile.is_android=is_android
 tile.tap_action=sideboard_session!=null or (is_android and page=="editor")
 tile.long_press_enabled=not (is_android and page=="editor")
 tile.hold_to_drag=is_android and page=="editor"
 tile.card_id=id
 tile.face_texture=texture(id)
 tile.source_zone=source
 tile.source_index=index
 tile.tooltip_text=Store.CARDS[id].name
 if is_android and page=="editor":tile.tooltip_text+="\n点击：查看详情 · 拖动：调整卡牌"
 elif CardArt.options(id,Store.CARDS).size()>1:tile.tooltip_text+="\n"+("长按：更换当前卡组的异画" if is_android else "鼠标中键：更换当前卡组的异画")
 tile.position=rect.position
 tile.size=rect.size
 tile.add_theme_stylebox_override("panel",style(Color("#142737"),GOLD if source=="leader" else Color("#677585")))
 (parent if parent else deck_canvas).add_child(tile)
 var art=TextureRect.new()
 art.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
 art.texture=texture(id)
 art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 art.offset_left=3;art.offset_top=3;art.offset_right=-3;art.offset_bottom=-3
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
   if not right and from in ["main","side"] and not (is_android and tile.held):drop_editor_card({"card_id":card_id,"source_zone":from,"source_index":index_in_deck},"side" if from=="main" else "main")
   return
  if is_android:
   if page=="editor":editor_ui.show_details(card_id,from,index_in_deck)
   else:
    update_preview()
    if from=="leader":open_leader_picker()
  elif right:
   if from=="leader": draft.leader=""
   else: draft[from].remove_at(index_in_deck)
   dirty=true
   update_deck_rows()
  elif from=="leader":open_leader_picker()
  else: add_to(from))
 tile.set_drag_forwarding(tile._get_drag_data,func(_at,data): return valid_drag_source(data),func(at,data):
  var target_index=index
  if data.get("source_zone","")==source or data.get("source_zone","") not in ["main","side"]:
   target_index+=1 if at.x>=tile.size.x*0.5 else 0
  drop_editor_card(data,source,target_index,true))
 return tile

func drop_editor_card(data: Dictionary, target: String, target_index: int=-1, target_is_card: bool=false):
 if not valid_drag_source(data) or target not in ["main","side","leader"]: return
 var source=data.get("source_zone","")
 if sideboard_session!=null and (sideboard_locked() or source not in ["main","side"] or target not in ["main","side"]):return
 var next=draft.duplicate(true)
 if source==target:
  if source not in ["main","side"] or target_index<0:return
  var source_index=int(data.source_index)
  var insert_at=clampi(target_index,0,next[target].size())
  var moved=next[source].pop_at(source_index)
  if insert_at>source_index:insert_at-=1
  next[target].insert(insert_at,moved)
  if next[target]==draft[target]:return
 elif target_is_card and source in ["main","side"] and target in ["main","side"] and target_index>=0 and target_index<next[target].size():
  var source_index=int(data.source_index)
  var displaced=next[target][target_index]
  next[target][target_index]=next[source][source_index]
  next[source][source_index]=displaced
  if next==draft:return
 else:
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
  if target in ["main","side"] and target_index>=0:
   var moved=next[target].pop_back()
   next[target].insert(clampi(target_index,0,next[target].size()),moved)
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
 if is_android:
  var layout=preload("res://scripts/menu_ui_layout.gd").new()
  layout.build_about(self)
  return
 var title=label(screen,"关于",Rect2(100,210,1400,70),44,GOLD)
 title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
 var version=label(screen,"multicolor:arena  "+str(ProjectSettings.get_setting("application/config/version")),Rect2(100,295,1400,44),24,GOLD)
 version.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
 var body=label(screen,"本作品基于开源游戏引擎godot和东方project的二次创作“极彩multicolor”，由chatgpt辅助代码\n所制成。所有卡图等知识产权均归属于社团“The 495th Complex”",Rect2(100,365,1400,90),32)
 body.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
 if debug_mode and not is_android:
  var state=label(screen,"调试模式已开启",Rect2(100,495,1400,44),22,GOLD)
  state.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
  button(screen,"退出调试模式",Rect2(670,571,260,50),func(): debug_mode=false; about())
 button(screen,"返回",Rect2(670,660,260,54),settings)

func _unhandled_key_input(event: InputEvent):
 if deck_picker_open():return
 if menu_popup_open():return
 if is_android:return
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
 if session.read_only or session.room.get("status","") not in ["sideboarding","between"] or not session.can_act() or session.room.ready[session.seat]:return
 sideboard_previous={"draft":draft.duplicate(true),"dirty":dirty,"selected":selected,"zone":zone}
 sideboard_session=session;sideboard_original=session.room.get("own_registered",session.room.own_deck).duplicate(true)
 draft=session.room.own_deck.duplicate(true);dirty=false;selected=draft.leader;zone="main";sideboard_waiting=false
 if not session.changed.is_connected(sideboard_changed):session.changed.connect(sideboard_changed)
 if not session.error_raised.is_connected(sideboard_error):session.error_raised.connect(sideboard_error)
 editor(true)

func sideboard_locked() -> bool:
 return sideboard_session==null or sideboard_waiting or sideboard_session.room.get("status","") not in ["sideboarding","between"] or sideboard_session.room.ready[sideboard_session.seat] or not sideboard_session.can_act()

func sideboard_instructions_text() -> String:
 var text="点击卡牌或拖到另一卡组：移动 1 张。\n拖到卡牌上可交换；%s可预览。\n完成时须恢复主卡组张数，保持自机及登记牌池不变。" % ("长按" if is_android else "右键")
 if sideboard_session!=null and Series.sideboard_limit(sideboard_session.room)>=0:text+="\n最多从备牌换入 3 张，可不换。"
 return text

func update_sideboard_info():
 if not is_instance_valid(sideboard_info) or sideboard_session==null:return
 var room=sideboard_session.room
 var leaders=room.get("leaders",[])
 sideboard_info.text=""
 if leaders.size()==2:sideboard_info.text="对方自机："+str(Store.CARDS.get(leaders[1-sideboard_session.seat],{}).get("name","未知自机"))
 if Series.sideboard_limit(room)>=0:
  sideboard_info.text+="\n已从备牌换入 %d / 3 张" % Series.sideboard_additions(draft,sideboard_original)
 sideboard_info.visible=not sideboard_info.text.is_empty()

func public_leader_card(parent: Node,room: Dictionary,seat: int,rect: Rect2=Rect2()) -> Control:
 var leaders=room.get("leaders",[])
 if leaders.size()!=2 or seat not in [0,1] or not Store.CARDS.has(leaders[seat]):return null
 var tile=preload("res://scripts/public_leader_card.gd").new()
 tile.app=self;tile.card_id=str(leaders[seat])
 var arts=room.get("leader_arts",[])
 if arts.size()==2:tile.art_id=str(arts[seat])
 tile.position=rect.position;tile.size=rect.size
 if rect==Rect2():
  var height=clampf(screen.size.y*0.22,100,180)
  tile.custom_minimum_size=Vector2(height/1.397,height)
  var center=CenterContainer.new();parent.add_child(center);center.add_child(tile)
 else:parent.add_child(tile)
 return tile

func complete_sideboard():
 if sideboard_locked():return
 var error=Series.sideboard_error(draft,sideboard_original,sideboard_session.room.strict,sideboard_session.room.get("rule_set",RuleSet.UNRESTRICTED),Series.sideboard_limit(sideboard_session.room))
 if not error.is_empty():sideboard_status.text=error;return
 sideboard_waiting=true;sideboard_done.disabled=true;sideboard_status.text="正在确认更换…"
 sideboard_session.room_action({"name":"deck","deck":draft.duplicate(true)})

func sideboard_changed():
 if page!="sideboard" or sideboard_session==null:return
 if sideboard_session.room.get("status","") not in ["sideboarding","between"]:
  sideboard_waiting=false;sideboard_done.disabled=true;sideboard_status.text=sideboard_session.connection_status() if sideboard_session.ended() else "当前已不能换备牌";return
 if sideboard_waiting and not sideboard_session.busy and sideboard_session.room.own_deck==draft:
  online();return
 sideboard_done.disabled=sideboard_locked()
 update_sideboard_info()
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
 if page=="battle" and is_instance_valid(replay_controller) and replay_controller.get_parent()==screen:return
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
 var folder=Store.Paths.root().path_join("replay");Store.Paths.initialize()
 var scroll=ScrollContainer.new();scroll.name="ReplayScroll";screen.add_child(scroll)
 if is_android:
  var margin=ui_metrics.padding
  var top=ui_metrics.hit+ui_metrics.gap*3+ui_metrics.title+margin
  scroll.position=Vector2(margin,top)
  scroll.size=Vector2(screen.size.x-margin*2,maxf(ui_metrics.hit,screen.size.y-top-margin))
  scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
  label(screen,"replay / .mreply",Rect2(margin,top-ui_metrics.body-ui_metrics.gap,scroll.size.x,ui_metrics.body+4),18,GOLD)
 else:
  label(screen,"replay / .mreply",Rect2(80,151,1350,42),22,GOLD)
  scroll.position=Vector2(80,217);scroll.size=Vector2(1440,630)
 var list=VBoxContainer.new();list.size_flags_horizontal=Control.SIZE_EXPAND_FILL;list.add_theme_constant_override("separation",16);scroll.add_child(list)
 var files=DirAccess.get_files_at(folder);files.reverse()
 for filename in files:
  if filename.get_extension().to_lower()!="mreply":continue
  var row=Button.new();row.text=filename;row.custom_minimum_size=Vector2(0,ui_metrics.hit if is_android else 64);list.add_child(row)
  row.size_flags_horizontal=Control.SIZE_EXPAND_FILL
  if is_android:
   ui_metrics.button(row)
   row.custom_minimum_size.x=0
   row.tooltip_text=filename
  else:row.custom_minimum_size.x=1380
  row.pressed.connect(func():
   var result=preload("res://scripts/replay_archive.gd").read(folder.path_join(filename))
   if result.has("error"):alert(result.error,"无法播放");return
   clear_page("battle")
   replay_controller=preload("res://scripts/replay_player.gd").new();screen.add_child(replay_controller)
   replay_controller.error_raised.connect(func(error):alert(error))
   replay_controller.build(self,result.archive,folder.path_join(filename)))
 if list.get_child_count()==0:
  var empty=Label.new();empty.text="暂无回放";list.add_child(empty)
  if is_android:empty.add_theme_font_size_override("font_size",ui_metrics.body)

func uses_responsive_layout() -> bool:
 return is_android and page in ["","menu","editor","sideboard","setup","settings","about","tutorials","tutorial_directory","tutorial_scene","battle","online","account","deck_plaza","replays"]

func refresh_ui_metrics():
 ui_metrics.measure(self,is_android,layout_dpi_override,layout_safe_override)
 if theme!=null:
  var next_theme=Theme.new();next_theme.default_font=theme.default_font;next_theme.default_font_size=18
  if uses_responsive_layout():ui_metrics.apply_theme(next_theme)
  theme=next_theme

func queue_layout_refresh():
 if layout_pending:return
 layout_pending=true
 call_deferred("refresh_responsive_layout")

func refresh_responsive_layout():
 layout_pending=false
 refresh_ui_metrics()
 if not is_instance_valid(screen):return
 if not is_android:
  if page=="battle" and is_instance_valid(duel_view):duel_view.resize_world()
  return
 screen.position=ui_metrics.safe.position;screen.size=ui_metrics.safe.size
 queue_redraw()
 if deck_picker_open():deck_picker_layout_changed=true;deck_picker_ui.refresh_metrics();return
 if page in ["editor","sideboard"]:editor(page=="sideboard")
 elif page=="menu":menu()
 elif page=="setup":setup()
 elif page=="settings":settings()
 elif page=="about":about()
 elif page=="tutorials" and is_instance_valid(tutorial_ui):tutorial_ui.refresh_metrics()
 elif page=="tutorial_directory" and is_instance_valid(tutorial_directory_ui):tutorial_directory_ui.refresh_metrics()
 elif page=="online":online()
 elif page=="account":account_page()
 elif page=="replays":replays()
 elif page=="deck_plaza" and is_instance_valid(deck_plaza_ui):deck_plaza_ui.relayout()
 elif page=="battle" and is_instance_valid(duel_view):
  screen.position=Vector2.ZERO;screen.size=get_viewport_rect().size
  duel_view.resize_world()
  if is_instance_valid(replay_controller):replay_controller.layout_controls()

func style_dialog(dialog: AcceptDialog):
 if not is_android:return
 dialog.theme=theme.duplicate();ui_metrics.apply_theme(dialog.theme)
 if dialog.get_ok_button().text.is_empty():dialog.get_ok_button().text="确定"
 ui_metrics.button(dialog.get_ok_button())
 # AcceptDialog resets internal buttons' custom minima when it pops up.
 # Keep their intrinsic text width instead of the general toolbar ellipsis.
 dialog.get_ok_button().text_overrun_behavior=TextServer.OVERRUN_NO_TRIMMING
 if dialog is ConfirmationDialog:
  if dialog.get_cancel_button().text.is_empty():dialog.get_cancel_button().text="取消"
  ui_metrics.button(dialog.get_cancel_button())
  dialog.get_cancel_button().text_overrun_behavior=TextServer.OVERRUN_NO_TRIMMING
 dialog.min_size=Vector2i(minf(ui_metrics.safe.size.x-32,maxf(540,ui_metrics.body*20)),maxf(dialog.min_size.y,ui_metrics.hit*2.5))

func fit_card_selector(panel: Panel,selector: Control):
 if not is_instance_valid(panel) or not is_instance_valid(selector):return
 if not is_android:
  selector.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
  selector.offset_left=20;selector.offset_right=-20;selector.offset_top=60;selector.offset_bottom=-70
  return
 var selector_area=ui_metrics.safe
 if page=="battle":
  var toolbar_height=ui_metrics.hit+ui_metrics.gap
  selector_area.position.y+=toolbar_height;selector_area.size.y-=toolbar_height
 panel.size=Vector2(minf(1540,selector_area.size.x-16),minf(870,selector_area.size.y-16))
 panel.position=selector_area.position+(selector_area.size-panel.size)*0.5
 var footer=HBoxContainer.new();footer.alignment=BoxContainer.ALIGNMENT_END
 var actions=[]
 for child in panel.get_children():
  if child is Button:actions.append(child)
  elif child is Label:
   child.position=Vector2(20,10);child.size=Vector2(panel.size.x-40,ui_metrics.title*1.5)
 panel.add_child(footer)
 footer.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
 footer.offset_left=16;footer.offset_right=-16;footer.offset_top=-ui_metrics.hit-16;footer.offset_bottom=-16
 for action in actions:
  action.reparent(footer);ui_metrics.button(action)
 selector.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 selector.offset_left=16;selector.offset_right=-16;selector.offset_top=ui_metrics.title*1.5+20;selector.offset_bottom=-ui_metrics.hit-ui_metrics.gap-24

# PC layout retained from the pre-Android responsive interface.
func desktop_menu():
 clear_page("menu")
 label(screen,"VERSION "+str(ProjectSettings.get_setting("application/config/version")),Rect2(92,74,900,42),18,GOLD)
 var actions=main_menu_entries()
 var badge=rank_display(screen,true);badge.position=Vector2(92,140);badge.size=Vector2(620,112)
 var rows=[422,512,594,676]
 for i in range(actions.size()):
  var item=actions[i]
  button(screen,item[0],Rect2(96+(i%2)*374,rows[int(i/2)],350,70 if i<2 else 64),item[1],i==1)
 card(screen,"68",Rect2(890,205,255,360)).rotation_degrees = -12
 card(screen,"70",Rect2(1140,250,280,394)).rotation_degrees = 12

func desktop_settings():
 clear_page("settings")
 header("设置",menu)
 button(screen,"关于",Rect2(1260,32,140,46),about)
 var sound_settings=preload("res://scripts/menu_ui_layout.gd").new()
 sound_settings.app=self;sound_settings.metrics=ui_metrics
 var sound_row=sound_settings.room_join_volume_control(screen)
 sound_row.position=Vector2(420,202);sound_row.size=Vector2(700,60)
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
 var delay_cb=CheckButton.new()
 delay_cb.name="DelayTurnEnd"
 delay_cb.text="延迟回合结束（长按 1 秒）"
 delay_cb.position=Vector2(420,530)
 delay_cb.size=Vector2(700,60)
 delay_cb.button_pressed=delay_turn_end
 delay_cb.toggled.connect(set_delay_turn_end)
 screen.add_child(delay_cb)
 var drag_cb=CheckButton.new()
 drag_cb.text="测试模式：允许拖动卡牌放入战场"
 drag_cb.position=Vector2(420,610)
 drag_cb.size=Vector2(700,60)
 drag_cb.button_pressed=debug_drag_to_field
 drag_cb.toggled.connect(set_debug_drag_to_field)
 screen.add_child(drag_cb)
 if is_test_build:
  var training_cb=CheckButton.new()
  training_cb.text="回放训练模式：标注关键步骤与推荐招法"
  training_cb.position=Vector2(420,690)
  training_cb.size=Vector2(700,60)
  training_cb.button_pressed=replay_training_mode
  training_cb.toggled.connect(set_replay_training_mode)
  screen.add_child(training_cb)
 button(screen,"加载 PCK 补丁…",Rect2(420,780,360,58),choose_pck_patch)
 label(screen,"当前版本："+patch_manager().active_version,Rect2(800,784,500,48),20,GOLD)

func desktop_editor(sideboarding: bool=false):
 if not sideboarding:reload_decks()
 clear_page("sideboard" if sideboarding else "editor")
 label(screen,"换备牌" if sideboarding else "卡组编辑器",Rect2(24,12,270,46),28,GOLD)
 button(screen,"返回",Rect2(1480,14,100,40),online if sideboarding else func(): guard(menu))
 button(screen,"排序卡组",Rect2(1090,14,156,40),sort_current_deck)
 if not sideboarding:
  button(screen,"套牌广场",Rect2(302,14,156,40),open_deck_plaza).name="DeckPlazaButton"
  button(screen,deck_upload_caption(),Rect2(476,14,156,40),upload_current_deck).name="DeckUploadButton"
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
  var instructions=label(screen,sideboard_instructions_text(),Rect2(1252,138,314,190),17,MUTED)
  instructions.name="SideboardInstructions"
  instructions.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
  instructions.size=Vector2(314,190)
  sideboard_leader_card=public_leader_card(screen,sideboard_session.room,1-sideboard_session.seat,Rect2(1333,334,150,210))
  sideboard_info=label(screen,"",Rect2(1252,556,314,86),20,GOLD)
  sideboard_info.name="SideboardInfo";sideboard_info.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
  sideboard_status=label(screen,"",Rect2(1252,650,314,94),18,GOLD)
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
 saved_select=button(screen,"选择卡组",Rect2(1252,602,314,40),open_editor_deck_picker)
 saved_select.name="SavedDeckSelect"
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

func desktop_update_preview():
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

func desktop_update_library():
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

func desktop_main_card_rect(index: int) -> Rect2:
 # Fifty main-deck slots: ten columns by five rows, with an independent leader slot.
 return Rect2(154+(index%10)*70,4+(index/10)*100,67,97)

func desktop_update_deck_rows():
 name_label.text=draft.name+(" *" if dirty else "")
 counts.text="主卡组 %d / %d     副卡组 %d / 10     自机 %d / 1" % [draft.main.size(),RuleSet.main_limit(str(draft.get("rule_set",RuleSet.OFFICIAL))),draft.side.size(),0 if draft.leader.is_empty() else 1]
 if sideboard_session!=null:
  counts.text="主卡组 %d / %d     副卡组 %d / 10     自机 1 / 1" % [draft.main.size(),sideboard_original.main.size(),draft.side.size()]
  if not sideboard_waiting and is_instance_valid(sideboard_status):sideboard_status.text=""
  update_sideboard_info()
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
 var color_counts=Store.deck_color_counts(draft.main)
 var index=0
 for c in color_counts:
  label(deck_canvas,"%s %d" % [c,color_counts[c]],Rect2(146+index*116,519,108,30),18,MUTED)
  index+=1
 if page=="editor" and is_instance_valid(library):refresh_library_limits()

func desktop_setup():
 reload_decks()
 clear_page("setup")
 header("人机对战",menu)
 player_choice=clampi(player_choice,0,maxi(0,decks.size()-1))
 ai_choice=clampi(ai_choice,0,maxi(0,decks.size()-1))
 for i in range(2):
  var x=220+i*620
  box(screen,Rect2(x,186,540,340))
  label(screen,"你的卡组" if i==0 else "人机的卡组",Rect2(x+24,205,440,40),24,GOLD)
  var pick=button(screen,deck_choice_caption(player_choice if i==0 else ai_choice),Rect2(x+24,266,492,50),func():open_match_deck_picker(i))
  pick.name="PlayerDeckSelect" if i==0 else "AIDeckSelect"
  pick.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
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
 if LocalExperiment.available():
  var ai_toggle=CheckButton.new()
  ai_toggle.name="ExperimentalAI"
  ai_toggle.text="使用试验 AI（仅本机测试端）"
  ai_toggle.position=Vector2(420,794)
  ai_toggle.size=Vector2(430,48)
  ai_toggle.button_pressed=experimental_ai and not debug_mode
  ai_toggle.disabled=debug_mode
  ai_toggle.toggled.connect(func(value):experimental_ai=value;setup())
  screen.add_child(ai_toggle)
  var model_button=button(screen,"选择模型…",Rect2(860,794,220,48),choose_experiment_model)
  model_button.disabled=debug_mode or not experimental_ai

func open_deck_folder():
 var folder=Store.folder()
 var directory_error=DirAccess.make_dir_recursive_absolute(folder)
 if directory_error!=OK:
  alert("无法创建 deck 文件夹："+error_string(directory_error),"打开失败")
  return
 var open_error=OS.shell_show_in_file_manager(folder)
 if open_error!=OK:alert("无法打开 deck 文件夹："+error_string(open_error),"打开失败")

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

func rank_display(parent: Node,show_username: bool=false) -> HBoxContainer:
 var row=HBoxContainer.new();row.name="PlayerRank";parent.add_child(row)
 row.add_theme_constant_override("separation",16)
 var badge=preload("res://scripts/rank_badge.gd").new();row.add_child(badge);badge.setup(account_rank,Store.CARDS)
 var text=Label.new();text.name="RankCaption";row.add_child(text)
 text.text=preload("res://scripts/rank_badge.gd").caption(account_rank) if not account_token.is_empty() else "毛玉级 2 · 登录后开始排位"
 if show_username:text.text=(account_nickname if not account_nickname.is_empty() else account_name if not account_name.is_empty() else "未登录")+"\n"+text.text
 text.add_theme_font_size_override("font_size",mini(ui_metrics.body,30) if show_username else ui_metrics.body);text.add_theme_color_override("font_color",GOLD)
 text.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;text.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 row.custom_minimum_size.y=104
 return row

func _process(_delta):
 if page=="sideboard" and is_instance_valid(sideboard_session):
  if sideboard_session.room.get("status","") not in ["sideboarding","between"]:online()
