extends "res://scripts/main.gd"
## The real editor in a private, memory-only host. No startup/account/save I/O.
const Actions=preload("res://scripts/tutorial/ui_actions.gd")
var flow
var owner_view
var command_depth=0
var building=false
var deck_only=false
var native_root: Control
var deck_overview: Control
var guide_finger=-1

func _ready():
 set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 theme=owner_view.host.theme
 get_viewport().size_changed.connect(queue_layout_refresh)

func configure(scene_owner,runtime):
 owner_view=scene_owner;flow=runtime;is_android=scene_owner.is_android
 layout_dpi_override=scene_owner.host.layout_dpi_override
 layout_safe_override=scene_owner.host.layout_safe_override
 deck_only=flow.adapter.scene_type=="deck"
 draft=flow.adapter.ui_deck.duplicate(true);decks=[draft.duplicate(true)]
 selected=draft.leader;dirty=false;zone="main";android_editor_overview=deck_only
 building=true;editor();building=false
 bind_controls()

func reload_decks():
 pass # This host has no connection to the player's saved decks.

func editor(sideboarding: bool=false):
 if deck_only:
  clear_page("editor");build_deck_surface()
 else:super.editor(sideboarding)

func clear_page(next: String):
 if next!="editor":
  flow.reject_ui_action("editor.return_menu",{});return
 super.clear_page(next)

func button(parent: Node,text: String,rect: Rect2,action: Callable,accent: bool=false) -> Button:
 var context={}
 var result=super.button(parent,text,rect,func():
  var control=context.control
  perform(Actions.identify(control,action),action_args(control,[]),action),accent)
 context.control=result;result.set_meta("tutorial_bound_pressed",true)
 return result

func perform(id: String,args: Dictionary,action: Callable) -> bool:
 if building or command_depth>0:action.call();return true
 if recording_dialog_open():return false
 if not flow.authorize_ui_action(id,args):return false
 var before=draft.duplicate(true)
 command_depth+=1
 action.call()
 command_depth-=1
 flow.adapter.ui_deck=draft.duplicate(true)
 bind_controls()
 if id in ["editor.add","editor.remove","editor.move"] and draft==before:
  flow.reject_ui_action(id,args,"真实组卡器未改变卡组，请检查张数限制和目标位置。")
  return false
 flow.ui_action_applied(id,args)
 return true

func action_args(control: Control,values: Array) -> Dictionary:
 var args=Actions.args_for(control,values)
 if Actions.identify(control)=="editor.add":args.card_id=selected
 if control is OptionButton and not values.is_empty():
  if control.name=="DeckRuleSet":args.value=RuleSet.IDS[int(values[0])]
  else:args.value=control.get_item_text(int(values[0]))
 return args

func bind_controls(node: Node=self):
 if node==owner_view.tutorial_guide or node==deck_overview:return
 if node is OptionButton:bind_signal(node,"item_selected",1)
 elif node is CheckButton:bind_signal(node,"toggled",1)
 elif node is Button:bind_signal(node,"pressed",0)
 elif node is LineEdit:bind_signal(node,"text_changed",1)
 if node.get_script()==preload("res://scripts/deck_card.gd"):
  bind_signal(node,"clicked",4);bind_signal(node,"remove_requested",3);bind_signal(node,"art_requested",1);bind_signal(node,"preview_requested",1)
 for child in node.get_children():bind_controls(child)

func bind_signal(control: Control,signal_name: String,count: int):
 var key="tutorial_bound_"+signal_name
 if control.has_meta(key):return
 var connections=control.get_signal_connection_list(signal_name)
 if connections.is_empty():return
 var callbacks=[]
 for connection in connections:
  callbacks.append(connection.callable);control.disconnect(signal_name,connection.callable)
 control.set_meta(key,true)
 var previous=control.text if control is LineEdit else control.selected if control is OptionButton else control.button_pressed if control is CheckButton else null
 control.set_meta("tutorial_previous_"+signal_name,previous)
 match count:
  0:control.connect(signal_name,func():invoke_signal(control,signal_name,callbacks,[]))
  1:control.connect(signal_name,func(a):invoke_signal(control,signal_name,callbacks,[a]))
  3:control.connect(signal_name,func(a,b,c):invoke_signal(control,signal_name,callbacks,[a,b,c]))
  4:control.connect(signal_name,func(a,b,c,d):invoke_signal(control,signal_name,callbacks,[a,b,c,d]))

func invoke_signal(control: Control,signal_name: String,callbacks: Array,values: Array):
 var id=Actions.identify(control,callbacks[0]);var args=action_args(control,values)
 if signal_name in ["clicked","remove_requested"]:
  id="editor.inspect" if signal_name=="clicked" and (is_android or (values[1]=="library" and values[3])) else "editor.remove" if signal_name=="remove_requested" or values[3] else "editor.add"
  args={"card_id":str(values[0]),"source_zone":str(values[1]),"source_index":int(values[2]),"zone":zone if values[1]=="library" else str(values[1])}
 elif signal_name=="art_requested":id="editor.external"
 elif signal_name=="preview_requested":id="editor.inspect";args={"card_id":str(values[0])}
 var accepted=perform(id,args,func():
  for callback in callbacks:callback.callv(values))
 if accepted:
  if not values.is_empty():control.set_meta("tutorial_previous_"+signal_name,values[0])
 else:
  var previous=control.get_meta("tutorial_previous_"+signal_name)
  if control is OptionButton:control.select(int(previous))
  elif control is CheckButton:control.set_pressed_no_signal(previous==true)
  elif control is LineEdit:control.text=str(previous)

func _process(_delta):
 if flow!=null:
  # Android view switches rebuild the native screen. Keep the guide last in
  # GUI input order as well as on top visually, without binding its buttons.
  var guide=owner_view.tutorial_guide
  if is_instance_valid(guide) and guide.get_parent()==self and guide.get_index()!=get_child_count()-1:move_child(guide,-1)
  layout_deck_surface();bind_controls()

func _input(event: InputEvent):
 if recording_dialog_open():return
 var guide=owner_view.tutorial_guide
 if is_instance_valid(guide):
  if event is InputEventScreenTouch:
   if event.pressed:
    # The guide's swipe helper may consume a release before it reaches this
    # parent. A new press always starts a fresh routing decision.
    guide_finger=event.index if guide_input_at(event.position) else -1
    if guide_finger>=0:return
   elif event.index==guide_finger:
    guide_finger=-1
    return
  elif event is InputEventScreenDrag and event.index==guide_finger:return
  elif (event is InputEventMouseButton or event is InputEventMouseMotion) and guide_input_at(event.position):return
 super._input(event)

func recording_dialog_open() -> bool:
 if not owner_view.has_meta("recording_editor"):return false
 var editor=owner_view.get_meta("recording_editor")
 return is_instance_valid(editor) and is_instance_valid(editor.dialog_layer)

func guide_input_at(point: Vector2) -> bool:
 var guide=owner_view.tutorial_guide
 if is_instance_valid(guide) and is_instance_valid(guide.illustration.overlay) and guide.illustration.overlay.is_visible_in_tree():return true
 if is_instance_valid(guide) and flow.answering():return true
 return is_instance_valid(guide) and ((is_instance_valid(guide.inspection_overlay) and guide.inspection_overlay.is_visible_in_tree()) or (guide.panel.is_visible_in_tree() and guide.panel.get_global_rect().has_point(point)) or (guide.restore_button.is_visible_in_tree() and guide.restore_button.get_global_rect().has_point(point)))

func refresh_responsive_layout():
 if not is_inside_tree() or is_queued_for_deletion():return
 building=true
 super.refresh_responsive_layout()
 building=false;bind_controls()

func menu():
 flow.reject_ui_action("editor.return_menu",{})

func save_deck():
 flow.reject_ui_action("editor.save",{})

func save_settings():
 pass

func guard(action: Callable):
 action.call() # All destination/editor callbacks still pass the action gate.

func rename_dialog():
 flow.reject_ui_action("editor.external",{})

func open_leader_picker():
 flow.reject_ui_action("editor.external",{})

func add_to(target: String):
 if command_depth>0:super.add_to(target);return
 perform("editor.add",{"card_id":selected,"zone":target},func():super.add_to(target))

func remove_card(id: String):
 if command_depth>0:super.remove_card(id);return
 perform("editor.remove",{"card_id":id,"zone":zone},func():super.remove_card(id))

func sort_current_deck():
 if command_depth>0:super.sort_current_deck();return
 perform("editor.sort",{},func():super.sort_current_deck())

func recording_state() -> Dictionary:
 var state={}
 for key in ["selected","zone","query","filter_kind","selected_colors","library_sort_mode","android_editor_overview","android_editor_main_page"]:
  var value=get(key);state[key]=value.duplicate(true) if value is Array else value
 if is_android and editor_ui!=null:
  state.library_page=editor_ui.library_page;state.main_page=editor_ui.main_page
 return state

func restore_recording_state(state: Dictionary):
 building=true
 for key in ["selected","zone","query","filter_kind","selected_colors","library_sort_mode","android_editor_overview","android_editor_main_page"]:
  if state.has(key):set(key,state[key].duplicate(true) if state[key] is Array else state[key])
 editor();building=false;bind_controls()
 if is_android and editor_ui!=null:
  editor_ui.change_library_page(int(state.get("library_page",0)));editor_ui.change_main_page(int(state.get("main_page",0)))

func replay_recorded_action(action: Dictionary) -> String:
 # Use the native deck operations when rebuilding an existing task timeline.
 var args=action.get("args",{});var before=draft.duplicate(true)
 command_depth+=1
 if args.has("card_id"):selected=args.card_id
 match action.id:
  "editor.add":add_to(args.get("zone","main"))
  "editor.remove":zone=args.get("zone",args.get("source_zone","main"));remove_card(args.get("card_id",selected))
  "editor.move":
   var source=args.get("source_zone","main" if args.get("zone")=="side" else "side")
   var ids=draft.get(source,[])
   var index=ids.find(args.get("card_id",selected)) if source in ["main","side"] else -1
   drop_editor_card({"card_id":selected,"source_zone":source,"source_index":index},args.get("zone","main"))
  "editor.sort":sort_current_deck()
  "editor.rule_set":draft.rule_set=args.get("value",draft.rule_set)
  "editor.search":query=str(args.get("value",""));update_library()
  "editor.select_zone":zone=args.get("zone","main");update_deck_rows()
  "editor.view":android_editor_overview=bool(args.get("value",not android_editor_overview))
  "editor.filter":
   var value=str(args.get("value",""))
   if value in ["红","蓝","绿","黄","黑"]:toggle_color(value)
   elif args.get("control")=="LibrarySortChoice":library_sort_mode=value
   elif not value.is_empty():filter_kind=value
   update_library()
  "editor.page":
   if is_android and editor_ui!=null:
    if args.get("control","") in ["PreviousMainPage","NextMainPage"]:editor_ui.change_main_page(int(args.get("page",editor_ui.main_page+1)))
    else:editor_ui.change_library_page(int(args.get("page",editor_ui.library_page+1)))
 command_depth-=1
 if action.id in ["editor.add","editor.remove","editor.move"] and draft==before:return "无法还原已有组卡操作："+Actions.caption(action,Store.CARDS)
 flow.adapter.ui_deck=draft.duplicate(true);flow.adapter.last_ui_action=action.duplicate(true)
 return ""

func drop_editor_card(data: Dictionary,target: String,target_index: int=-1,target_is_card: bool=false):
 var args={"card_id":str(data.get("card_id","")),"source_zone":str(data.get("source_zone","")),"source_index":int(data.get("source_index",-1)),"zone":target,"target_index":target_index}
 perform("editor.move",args,func():super.drop_editor_card(data,target,target_index,target_is_card))

func return_card_to_library(at: Vector2,data: Variant):
 perform("editor.remove",{"card_id":str(data.get("card_id","")),"source_zone":str(data.get("source_zone",""))},func():super.return_card_to_library(at,data))

func build_deck_surface():
 native_root=screen;native_root.name="NativeTutorialDeck"
 native_root.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
 native_root.clip_contents=true
 native_root.position=owner_view.deck_rect().position;native_root.size=owner_view.deck_rect().size
 var panel=PanelContainer.new();native_root.add_child(panel);panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 panel.add_theme_stylebox_override("panel",ui_metrics.panel_style())
 var column=VBoxContainer.new();panel.add_child(column)
 column.add_theme_constant_override("separation",int(ui_metrics.gap))
 name_label=Label.new();column.add_child(name_label);name_label.text=str(draft.name)
 name_label.add_theme_font_size_override("font_size",ui_metrics.title);name_label.add_theme_color_override("font_color",GOLD)
 name_label.clip_text=true
 deck_overview=preload("res://scripts/deck_plaza_overview.gd").new()
 deck_overview.app=self;deck_overview.deck=draft;deck_overview.fill_height=true;deck_overview.input_root=self
 column.add_child(deck_overview);deck_overview.size_flags_vertical=Control.SIZE_EXPAND_FILL;deck_overview.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 deck_overview.card_inspected.connect(func(id):perform("editor.inspect",{"card_id":id},func():owner_view.tutorial_guide.show_card_details(id,draft)))
 deck_canvas=deck_overview
 counts=Label.new();column.add_child(counts)
 counts.text="主卡组 %d / 50  ·  副卡组 %d / 10  ·  自机 1 / 1" % [draft.main.size(),draft.side.size()]
 counts.add_theme_font_size_override("font_size",ui_metrics.small);counts.add_theme_color_override("font_color",MUTED)
 counts.clip_text=true
 layout_deck_surface()

func layout_deck_surface():
 if not deck_only or not is_instance_valid(native_root):return
 var rect=owner_view.deck_rect()
 native_root.position=rect.position;native_root.size=rect.size
