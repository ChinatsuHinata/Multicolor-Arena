extends Control
const Duel=preload("res://scripts/rules/duel_engine.gd")
const PaymentDraft=preload("res://scripts/payment_draft.gd")
const SpellDamagePreview=preload("res://scripts/rules/spell_damage_preview.gd")
const UnknownArt=preload("res://scripts/unknown_card_art.gd")
const RemoteDuel=preload("res://net/remote_duel.gd")
const ConditionHints=preload("res://scripts/rules/card_condition_hints.gd")
const ConditionalFrame=preload("res://scripts/conditional_frame_pulse.gd")
const CurseWarning=preload("res://scripts/duel_curse_warning.gd")
const AbilityCaption=preload("res://scripts/rules/ability_caption.gd")
const CostDisplay=preload("res://scripts/card_cost_display.gd")
const HexCost=preload("res://scripts/cost_hex_display.gd")
const SearchAliases=preload("res://scripts/card_search_aliases.gd")
const CardNameSearchPanel=preload("res://scripts/card_name_search_panel.gd")
const AndroidSwipeScroll=preload("res://scripts/android_swipe_scroll.gd")
const LocalExperiment=preload("res://scripts/ai/local_experiment.gd")
var STAGE=Rect2(0,0,1600,900)
var TOUCH_CAMERA_AREA=Rect2(250,100,1110,560)
const TOUCH_PAN_HOLD_MS=450
const TOUCH_DRAG_THRESHOLD=12.0
var ANDROID_BACK_SWIPE_EDGE_X=1440.0
const ANDROID_BACK_SWIPE_DISTANCE=120.0
const ANDROID_BACK_SWIPE_VERTICAL_LIMIT=80.0
const CARD_ICON_SIZE=28.0
const CARD_ICON_GAP=3.0
const CARD_ICON_INSET=3.0
var HAND=Rect2(246,663,1108,232)
var NOTICE=Rect2(307,568,995,28)
var PROMPT=Rect2(310,598,1000,28)
var OPPONENT_HAND_COUNT=Rect2(1070,78,170,30)
var SIDEBAR=Rect2(1366,100,218,660)
var INSPECTION=Rect2(16,100,218,660)
var ANDROID_ACTION_X=1366.0
var ANDROID_ACTION_WIDTH=218.0
var ANDROID_ACTION_CONFIRM_Y=769.0
var ANDROID_ACTION_FOOTER_Y=834.0
var ANDROID_ACTION_FOOTER_HEIGHT=55.0
var ANDROID_PALETTE_RECT=Rect2(340,245,920,365)
var reveal_player
const COLOR_INK={"红":Color("#cf5b60"),"蓝":Color("#4d94d5"),"绿":Color("#48996d"),"黄":Color("#d9b54f"),"黑":Color("#77758b")}
var debug_mode=false
var experiment_agent=LocalExperiment.new()
var debug_controls: Control
var debug_button: Button
var debug_help_button: Button
var debug_free_checkbox: CheckButton
var debug_root: Control
var debug_open=false
var history_open=false
var history_root: Control
var history_panel: Panel
var region_selected: Dictionary={}
var region_batch: Array=[]
var region_batch_key=""
var region_tiles={}
var inspection_text: RichTextLabel
const ZONE_NAMES={"deck":"牌库","grave":"墓地","exile":"除外区","field":"战场","palette":"颜色盘","hand":"手牌","leader":"自机区","stack":"堆叠"}
var hand_zones={0:"hand",1:"hand"}
var hand_zone_tabs={}
var debug_drag_browser=false
var browser_owner=0
var browser_zone="deck"
var browser_scroll: ScrollContainer
var battle_choice_scroll: ScrollContainer
var battle_choice_touch_index=-1
var battle_choice_touch_last=Vector2.ZERO
var battle_choice_touch_dragged=false
var browser_cards: GridContainer
var browser_panel: Panel
var debug_drag_uid=0
var debug_drag_epoch=0
var debug_dragging=false
var debug_drag_origin=Vector2.ZERO
var debug_drag_pointer=Vector2.ZERO
var debug_drag_art: Control
var debug_drop_hint: Label
var attack_preview_uid=0
var stage_hover_uid=0
var host
var local_seat=0
var replay_recording=preload("res://scripts/replay_archive.gd").new()
var network_session
var network_status_label: Label
var network_latency_label: Label
var chat_panel: Panel
var was_network_locked=false
var was_network_disconnected=false
var was_network_wait_choice=false
var was_network_ended=false
var engine
var table
var stack_panel
var viewport: SubViewport
var stage: TextureRect
var ui: Control
var hud: Control
var responsive=preload("res://scripts/battle_ui_layout.gd").new()
var hand_scroll: ScrollContainer
var resize_queued=false
var hand_layer: Control
var opponent_layer: Control
var deck_cast_layer: Control
var deck_cast_tiles={}
var deck_peek_tile
var badges: Control
var inspection: Control
var hand_nodes={}
var enemy_nodes={}
var card_badges={}
var hand_tweens={}
var picker=preload("res://scripts/target_picker.gd").new()
var card_search_target_key=""
var life_widgets={}
var life_last={}
var life_flashes={}
var life_flash_tweens={}
var arrow_layer: Control
var grave_target_layer: Control
var grave_target_tiles={}
var local: Dictionary={}
var selection: Array=[]
enum ResponseMode { DEFAULT, ON, OFF }
const RESPONSE_LABELS=["默认","开","关"]
var response_mode=ResponseMode.DEFAULT
var modal=false
var modal_root: Control
var action_menu_open=false
var android_action_uid=0
var android_choice_panel: Panel
var android_choice_restore: Button
var android_choice_hidden_key=""
var is_android=OS.has_feature("android")
var android_swipe_scroll=AndroidSwipeScroll.new()
var android_back_button: Button
var android_back_swipe_index=-1
var android_back_swipe_start=Vector2.ZERO
var android_back_swipe_active=false
var android_palette_owner=-1
var android_palette_auto_open=false
var android_palette_was_possession=false
var android_palette_panel: Panel
var android_palette_scroll: ScrollContainer
var android_palette_tiles={}
var android_palette_touch_index=-1
var android_palette_touch_start=Vector2.ZERO
var android_palette_touch_last=Vector2.ZERO
var android_palette_touch_dragged=false
var android_palette_scroll_x=0
var suppress_touch_mouse_until=0
var suppress_touch_mouse_point=Vector2(-10000,-10000)
var clock_time=0.0
var last_revision=-1
var message=""
var fast_mode=false
var last_phase=""
var last_turn=0
var banner: Control
var banner_tween: Tween
var banner_until=0
var inspect_id=""
var inspect_art_id=""
var inspect_uid=0
var inspect_caption=""
var inspection_signature=""
var drag_uid=0
var drag_origin=Vector2.ZERO
var drag_pointer=Vector2.ZERO
var dragging=false
var drag_art: Control
var unit_drag_uid=0
var unit_drag_epoch=0
var unit_drag_owner=0
var unit_drag_origin=Vector2.ZERO
var unit_drag_pointer=Vector2.ZERO
var unit_dragging=false
var unit_drag_art: Control
var previous_snapshot={}
var frame_count=0
var observing=false
var observe_button: Button
var sort_units_button: Button
var reset_view_button: Button
var camera_dragging=false
var camera_drag_last=Vector2.ZERO
var camera_touches={}
var camera_touch_mode=""
var camera_touch_start=Vector2.ZERO
var camera_touch_last=Vector2.ZERO
var camera_touch_started_ms=0
var camera_pinch_distance=0.0
var building_prompt=false
var effects: Control
var damage_values={}
var damage_controls={}
var damage_signature=""
var damage_remainder: Label
var phase_names={"mulligan":"起手调度","reset":"重置阶段","prepare":"准备阶段","draw":"抓牌阶段","possession":"凭依阶段","main":"主要阶段","end":"结束阶段","over":"对局结束"}

func layer(parent: Node) -> Control:
 var node=Control.new(); node.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 node.mouse_filter=Control.MOUSE_FILTER_IGNORE; parent.add_child(node)
 return node
func begin(parent,a: Dictionary,b: Dictionary,first: int,seed_value: int=0,session=null):
 host=parent;network_session=session
 is_android=host.is_android
 set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 responsive.measure(self)
 var model_path=parent.get("experiment_model_path")
 var experiment_error=experiment_agent.configure(parent.get("experimental_ai")==true,str(model_path) if model_path!=null else "",parent.debug_mode,session)
 if not experiment_error.is_empty():host.alert(experiment_error,"试验 AI")
 if session!=null:
  local_seat=session.seat;debug_mode=false
  engine=preload("res://net/remote_duel.gd").new();engine.session=session;engine.seat=local_seat
  var packet=session.pop_snapshot();engine.apply_snapshot(packet.projection)
  session.error_raised.connect(network_error)
 else:
  debug_mode=host.debug_mode and not is_android;engine=Duel.new();engine.debug_enabled=debug_mode;engine.debug_free_payment=debug_mode and host.debug_free_payment;engine.start(a,b,first,seed_value)
 viewport=SubViewport.new(); viewport.own_world_3d=true
 viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
 viewport.render_target_clear_mode=SubViewport.CLEAR_MODE_ALWAYS
 viewport.msaa_3d=Viewport.MSAA_4X; add_child(viewport)
 resize_world()
 stage=TextureRect.new(); stage.position=STAGE.position; stage.size=STAGE.size
 stage.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; stage.texture=viewport.get_texture()
 stage.stretch_mode=TextureRect.STRETCH_SCALE; add_child(stage)
 stage.gui_input.connect(stage_input)
 stage.mouse_exited.connect(func():stage_hover_uid=0;table.set_hovered_card(0);stage.tooltip_text="")
 table=preload("res://scripts/duel_table.gd").new(); viewport.add_child(table)
 table.external_stack=true;table.local_seat=local_seat
 table.build(engine,host.texture,host.battlefield_background)
 table.set_top_down_view(host.top_down_view)
 table.object_selected.connect(object_clicked)
 table.avatar_selected.connect(leader_zone_clicked)
 table.combat_animation_finished.connect(render)
 table.combat_damage_shown.connect(rebuild_badges)
 table.combat_impact.connect(show_combat_impact)
 table.stack_selected.connect(func(id): choose_target({"stack_id":id}))
 table.card_inspected.connect(inspect_card)
 table.empty_right_clicked.connect(right_cancel)
 table.pile_selected.connect(func(zone):
  if zone in ["pgrave","agrave","pexile","aexile"]:
   var who=0 if zone.begins_with("p") else 1
   browse_zone(who,"exile" if "exile" in zone else "grave")
  elif zone in ["pdeck","adeck"]: browse_zone(0 if zone=="pdeck" else 1,"deck"))
 ui=layer(self); badges=layer(ui)
 arrow_layer=preload("res://scripts/stack_arrows.gd").new(); arrow_layer.view=self; arrow_layer.mouse_filter=Control.MOUSE_FILTER_IGNORE; ui.add_child(arrow_layer)
 deck_cast_layer=layer(ui)
 hand_scroll=ScrollContainer.new();hand_scroll.name="ResponsiveHandScroll";ui.add_child(hand_scroll)
 hand_scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
 hand_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_AUTO if is_android else ScrollContainer.SCROLL_MODE_DISABLED
 hand_scroll.mouse_filter=Control.MOUSE_FILTER_PASS if is_android else Control.MOUSE_FILTER_IGNORE
 hand_layer=Control.new();hand_layer.mouse_filter=Control.MOUSE_FILTER_IGNORE;hand_scroll.add_child(hand_layer)
 opponent_layer=layer(ui); hud=layer(ui)
 ui.move_child(arrow_layer,-1)
 inspection=Control.new(); inspection.position=INSPECTION.position; inspection.size=INSPECTION.size; ui.add_child(inspection)
 effects=layer(ui)
 stack_panel=preload("res://scripts/duel_stack.gd").new(); ui.add_child(stack_panel); stack_panel.build(self)
 if is_android:
  stack_panel.size.y=327
  stack_panel.scroll.size.y=294
 grave_target_layer=layer(ui)
 reveal_player=preload("res://scripts/duel_reveal.gd").new();reveal_player.view=self;ui.add_child(reveal_player)
 banner=layer(ui)
 ui.move_child(banner,0)
 if session!=null and not session.read_only and not session.replay_mode:
  chat_panel=preload("res://net/chat_panel.gd").new();ui.add_child(chat_panel)
  chat_panel.build(session,Rect2(1168,194,402,432));chat_panel.visible=false
 observe_button=btn("观察战场",Rect2(1290,12,152,40),toggle_observation,false,ui)
 observe_button.visible=false
 reset_view_button=btn("视角复原",Rect2(1315,57,116,34),reset_camera_view,false,ui)
 reset_view_button.tooltip_text="复原战场缩放和位置"
 if is_android:
  android_back_button=host.button(ui,"后退",Rect2(1516,ANDROID_ACTION_FOOTER_Y,68,ANDROID_ACTION_FOOTER_HEIGHT),android_back)
  android_back_button.z_index=102

 if debug_mode:
  debug_controls=layer(ui)
  debug_help_button=btn("测试说明",Rect2(1450,840,120,34),open_debug_help,false,debug_controls)
  debug_help_button.tooltip_text="查看测试模式的区域操作与快捷键"
  debug_button=btn("调试",Rect2(1460,57,116,34),debug_menu,false,debug_controls)
  debug_button.toggle_mode=true
  debug_free_checkbox=CheckButton.new()
  debug_free_checkbox.text="无需付费"
  debug_free_checkbox.position=Vector2(1160,57)
  debug_free_checkbox.size=Vector2(145,34)
  debug_free_checkbox.button_pressed=engine.debug_free_payment
  debug_free_checkbox.tooltip_text="跳过出牌、异能与攻击的颜色费用"
  debug_free_checkbox.toggled.connect(func(value):
   engine.debug_free_payment=value
   host.debug_free_payment=value
   render())
  debug_controls.add_child(debug_free_checkbox)
 responsive.position_persistent()
 get_viewport().size_changed.connect(resize_world)
 if session!=null:
  was_network_locked=network_locked();was_network_ended=session.ended();was_network_disconnected=not session.connected;was_network_wait_choice=not session.replay_mode and session.wait_choice_pending;session.changed.connect(network_changed)
 render()

func resize_world():
 if not is_instance_valid(viewport): return
 host.refresh_ui_metrics()
 responsive.measure(self)
 var window_size=Vector2(get_window().size)
 var scale_value=clampf(window_size.y/get_viewport_rect().size.y,0.5,2.2) if is_android else clampf(minf(window_size.x/1600.0,window_size.y/900.0),1.0,2.2)
 viewport.size=Vector2i(STAGE.size*scale_value)
 if is_instance_valid(stage):stage.position=STAGE.position;stage.size=STAGE.size
 if is_instance_valid(ui):
  responsive.position_persistent()
  inspection_signature=""
  if not resize_queued:
   resize_queued=true
   call_deferred("render_after_resize")

func render_after_resize():
 resize_queued=false
 if is_instance_valid(ui):render()

func project(at: Vector3) -> Vector2:
 return STAGE.position+table.camera.unproject_position(at)/Vector2(viewport.size)*STAGE.size
func stage_point(at: Vector2) -> Vector2:
 return (at-STAGE.position)/STAGE.size*Vector2(viewport.size)
func camera_drag_input(event: InputEvent) -> bool:
 if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_MIDDLE:
  if not event.pressed:
   if not camera_dragging:return false
   camera_dragging=false
   get_viewport().set_input_as_handled()
   return true
  var point=make_input_local(event).position
  if not STAGE.has_point(point) or history_open or (modal and not observing) or dragging or debug_drag_uid!=0:return false
  camera_dragging=true
  camera_drag_last=stage_point(point)
  get_viewport().set_input_as_handled()
  return true
 if event is InputEventMouseMotion and camera_dragging:
  if (event.button_mask & MOUSE_BUTTON_MASK_MIDDLE)==0:
   camera_dragging=false
   return false
  var point=make_input_local(event).position
  var current=stage_point(STAGE.position+(point-STAGE.position).clamp(Vector2.ZERO,STAGE.size))
  table.pan_camera(camera_drag_last,current)
  camera_drag_last=current
  update_badge_positions()
  get_viewport().set_input_as_handled()
  return true
 return false
func reset_camera_view():
 camera_dragging=false
 camera_touches.clear()
 camera_touch_mode=""
 table.reset_camera()
 update_badge_positions()
func touch_camera_available(point: Vector2) -> bool:
 if not is_instance_valid(table) or history_open or modal or revealing() or table.combat_animating or drag_uid!=0 or debug_drag_uid!=0 or unit_drag_uid!=0:return false
 if inspection.visible and inspection.get_global_rect().has_point(point):return false
 if is_android and (is_instance_valid(android_choice_panel) and android_choice_panel.get_global_rect().has_point(point) or is_instance_valid(android_choice_restore) and android_choice_restore.get_global_rect().has_point(point)):return false
 if is_android and (android_palette_toggle_at(point)>=0 or is_instance_valid(android_palette_panel) and android_palette_panel.is_visible_in_tree() and android_palette_panel.get_global_rect().has_point(point)):return false
 if TOUCH_CAMERA_AREA.has_point(point):return true
 if engine.pending.get("kind","")!="possession" or not STAGE.has_point(point):return false
 for card in hand_nodes.values():
  if is_instance_valid(card) and card.is_visible_in_tree() and card.get_global_rect().has_point(point):return false
 var uid=table.card_at(stage_point(point))
 return uid>0 and engine.find_card(uid).get("zone","")=="palette"

func touch_android_back_swipe(event: InputEvent) -> bool:
 if not is_android or not (event is InputEventScreenTouch or event is InputEventScreenDrag):return false
 var point=make_input_local(event).position
 if event is InputEventScreenTouch and event.pressed:
  if android_back_swipe_index>=0:
   android_back_swipe_index=-1;android_back_swipe_active=false
  elif point.x>=ANDROID_BACK_SWIPE_EDGE_X and STAGE.has_point(point):
   android_back_swipe_index=event.index
   android_back_swipe_start=point
   android_back_swipe_active=false
  return false
 if event.index!=android_back_swipe_index:return false
 var delta=point-android_back_swipe_start
 if event is InputEventScreenDrag:
  if not android_back_swipe_active and absf(delta.y)>ANDROID_BACK_SWIPE_VERTICAL_LIMIT:
   android_back_swipe_index=-1
   return false
  if delta.x<=-ANDROID_BACK_SWIPE_DISTANCE and absf(delta.y)<=ANDROID_BACK_SWIPE_VERTICAL_LIMIT:android_back_swipe_active=true
  if not android_back_swipe_active:return false
  get_viewport().set_input_as_handled()
  return true
 android_back_swipe_index=-1
 var completed=delta.x<=-ANDROID_BACK_SWIPE_DISTANCE and absf(delta.y)<=ANDROID_BACK_SWIPE_VERTICAL_LIMIT
 if not android_back_swipe_active and not completed:return false
 android_back_swipe_active=false
 if battle_choice_touch_index==event.index:
  battle_choice_touch_index=-1
  battle_choice_touch_dragged=false
 suppress_touch_mouse_until=Time.get_ticks_msec()+250
 suppress_touch_mouse_point=event.position
 if completed:android_back()
 get_viewport().set_input_as_handled()
 return true

func android_palette_toggle_at(point: Vector2) -> int:
 for i in range(2):
  var who=local_seat if i==0 else 1-local_seat
  var toggle=hud.get_node_or_null("AndroidPaletteToggle"+str(who))
  if is_instance_valid(toggle) and toggle.is_visible_in_tree() and toggle.get_global_rect().has_point(point):return who
 return -1

func touch_android_palette(event: InputEvent) -> bool:
 if not is_android or not (event is InputEventScreenTouch or event is InputEventScreenDrag):return false
 var point=make_input_local(event).position
 if event is InputEventScreenTouch and event.pressed:
  if history_open or modal or observing or revealing() or table.combat_animating:return false
  if android_palette_touch_index>=0 or android_palette_toggle_at(point)<0 and (not is_instance_valid(android_palette_panel) or not android_palette_panel.get_global_rect().has_point(point)):return false
  android_palette_touch_index=event.index
  android_palette_touch_start=point
  android_palette_touch_last=point
  android_palette_touch_dragged=false
 elif event.index!=android_palette_touch_index:return false
 elif event is InputEventScreenDrag:
  if point.distance_to(android_palette_touch_start)>TOUCH_DRAG_THRESHOLD:android_palette_touch_dragged=true
  if android_palette_touch_dragged and is_instance_valid(android_palette_scroll) and android_palette_scroll.get_global_rect().has_point(android_palette_touch_start):
   if absf(point.y-android_palette_touch_start.y)>absf(point.x-android_palette_touch_start.x):android_palette_scroll.scroll_vertical+=roundi(android_palette_touch_last.y-point.y)
   else:android_palette_scroll.scroll_horizontal+=roundi(android_palette_touch_last.x-point.x)
  android_palette_touch_last=point
 else:
  android_palette_touch_index=-1
  if not android_palette_touch_dragged and not (history_open or modal or observing or revealing() or table.combat_animating):
   var toggle_who=android_palette_toggle_at(point)
   if toggle_who>=0 and toggle_who==android_palette_toggle_at(android_palette_touch_start):toggle_android_palette(toggle_who)
   elif is_instance_valid(android_palette_panel) and android_palette_panel.get_global_rect().has_point(point):
    var close=android_palette_panel.get_node("AndroidPaletteClose")
    if close.get_global_rect().has_point(point) and close.get_global_rect().has_point(android_palette_touch_start):toggle_android_palette(android_palette_owner)
    else:
     for uid in android_palette_tiles:
      var tile=android_palette_tiles[uid]
      if is_instance_valid(tile) and tile.get_global_rect().has_point(point) and tile.get_global_rect().has_point(android_palette_touch_start):
       object_clicked(uid)
       break
  android_palette_touch_dragged=false
 suppress_touch_mouse_until=Time.get_ticks_msec()+250
 suppress_touch_mouse_point=event.position
 get_viewport().set_input_as_handled()
 return true

func touch_battle_choice_scroll(event: InputEvent) -> bool:
 if not is_android or not is_instance_valid(battle_choice_scroll) or not battle_choice_scroll.is_visible_in_tree():return false
 if event is InputEventScreenTouch and event.pressed:
  if battle_choice_touch_index<0 and battle_choice_scroll.get_global_rect().has_point(event.position):
   battle_choice_touch_index=event.index
   battle_choice_touch_last=event.position
   battle_choice_touch_dragged=false
  return false
 if event is InputEventScreenDrag and event.index==battle_choice_touch_index:
  var distance=battle_choice_touch_last.y-event.position.y
  if not battle_choice_touch_dragged and absf(distance)<8:return false
  if absf(distance)>0.0:
   battle_choice_scroll.scroll_vertical+=roundi(distance)
   battle_choice_touch_last=event.position
   battle_choice_touch_dragged=true
  suppress_touch_mouse_until=Time.get_ticks_msec()+250
  suppress_touch_mouse_point=event.position
  get_viewport().set_input_as_handled()
  return true
 if event is InputEventScreenTouch and not event.pressed and event.index==battle_choice_touch_index:
  battle_choice_touch_index=-1
  if battle_choice_touch_dragged:
   battle_choice_touch_dragged=false
   suppress_touch_mouse_until=Time.get_ticks_msec()+250
   suppress_touch_mouse_point=event.position
   get_viewport().set_input_as_handled()
   return true
 return false
func touch_camera_input(event: InputEvent) -> bool:
 if not is_android or not (event is InputEventScreenTouch or event is InputEventScreenDrag):return false
 var point=make_input_local(event).position
 if event is InputEventScreenTouch and event.pressed:
  if camera_touches.is_empty():
   if not touch_camera_available(point):return false
   camera_touch_mode="pending"
   camera_touch_start=point
   camera_touch_last=point
   camera_touch_started_ms=Time.get_ticks_msec()
  elif not STAGE.has_point(point):return false
  camera_touches[event.index]=point
  if camera_touches.size()==2:
   camera_touch_mode="pinch"
   if unit_drag_uid!=0:finish_unit_drag(true)
   var points=camera_touches.values()
   camera_pinch_distance=points[0].distance_to(points[1])
 elif event is InputEventScreenDrag:
  if not camera_touches.has(event.index):return false
  camera_touches[event.index]=point
  if camera_touch_mode=="pinch" and camera_touches.size()==2:
   var points=camera_touches.values()
   var distance=points[0].distance_to(points[1])
   if camera_pinch_distance>20.0 and distance>20.0:
    table.zoom_camera(camera_pinch_distance/distance)
    update_badge_positions()
   camera_pinch_distance=distance
  elif camera_touch_mode=="pending" and event.index==0:
   if Time.get_ticks_msec()-camera_touch_started_ms>=TOUCH_PAN_HOLD_MS:
    camera_touch_mode="pan"
   elif point.distance_to(camera_touch_start)>TOUCH_DRAG_THRESHOLD:
    camera_touch_mode="unit_drag"
    var press=InputEventMouseButton.new()
    press.button_index=MOUSE_BUTTON_LEFT;press.pressed=true;press.position=camera_touch_start-STAGE.position
    stage_input(press)
   if camera_touch_mode=="pan":
    table.pan_camera(stage_point(camera_touch_last),stage_point(point))
    update_badge_positions()
   elif camera_touch_mode=="unit_drag" and unit_drag_uid!=0:move_unit_drag(point)
   camera_touch_last=point
  elif camera_touch_mode=="pan" and event.index==0:
   table.pan_camera(stage_point(camera_touch_last),stage_point(point))
   camera_touch_last=point
   update_badge_positions()
  elif camera_touch_mode=="unit_drag" and event.index==0 and unit_drag_uid!=0:move_unit_drag(point)
 elif event is InputEventScreenTouch:
  if not camera_touches.has(event.index):return false
  camera_touches.erase(event.index)
  if camera_touch_mode=="pending" and camera_touches.is_empty() and Time.get_ticks_msec()-camera_touch_started_ms<TOUCH_PAN_HOLD_MS:
   var press=InputEventMouseButton.new()
   press.button_index=MOUSE_BUTTON_LEFT;press.pressed=true;press.position=point-STAGE.position
   stage_input(press)
   if unit_drag_uid!=0:
    unit_drag_pointer=point
    finish_unit_drag(false)
  elif camera_touch_mode=="unit_drag" and camera_touches.is_empty() and unit_drag_uid!=0:
   unit_drag_pointer=point
   finish_unit_drag(false)
  if camera_touches.is_empty():camera_touch_mode=""
  elif camera_touch_mode=="pinch":camera_touch_mode="consumed"
 suppress_touch_mouse_until=Time.get_ticks_msec()+250
 suppress_touch_mouse_point=event.position
 get_viewport().set_input_as_handled()
 return true
func stage_input(event: InputEvent):
 if event is InputEventMouseMotion:
  stage_hover_uid=0
  if not revealing() and not table.combat_animating and not history_open and (not modal or observing):
   stage_hover_uid=table.card_at(event.position/STAGE.size*Vector2(viewport.size))
  refresh_stage_tooltip()
  return
 if event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
  if history_open or (modal and not observing) or dragging or debug_drag_uid!=0:return
  var wheel=event.duplicate()
  wheel.position=event.position/STAGE.size*Vector2(viewport.size)
  table.pointer(wheel)
  update_badge_positions()
  return
 if revealing():return
 if table.combat_animating: return
 if debug_mode and can_begin_debug_drag() and event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT:
  var uid=table.card_at(event.position/STAGE.size*Vector2(viewport.size))
  if uid>0:
   begin_debug_drag(uid,STAGE.position+event.position); return
 if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT and not observing and not modal and not history_open and drag_uid==0 and debug_drag_uid==0:
  var uid=table.card_at(event.position/STAGE.size*Vector2(viewport.size))
  if uid>0:
   var c=engine.find_card(uid)
   if not c.is_empty() and c.zone=="field" and engine.is_unit(c):
    unit_drag_uid=uid
    unit_drag_epoch=c.epoch
    unit_drag_owner=c.owner
    unit_drag_origin=STAGE.position+event.position
    unit_drag_pointer=unit_drag_origin
    unit_dragging=false
    return
 if history_open or (modal and not observing) or dragging or debug_drag_uid!=0: return
 if event is InputEventMouseButton:
  var converted=event.duplicate()
  converted.position=event.position/STAGE.size*Vector2(viewport.size)
  if event.pressed and event.button_index==MOUSE_BUTTON_LEFT and can_debug_add() and table.card_at(converted.position)==0:
   var spot=table.debug_field_group(converted.position)
   if not spot.is_empty():
    open_debug_card_picker(int(spot.owner),"field",spot.group)
    return
  table.pointer(converted)
func free_main() -> bool:
 return engine.active==acting_player() and engine.phase=="main" and engine.pending.is_empty() and engine.stack.is_empty() and engine.combat.is_empty()
func in_response_window() -> bool:
 return engine!=null and engine.winner==-2 and engine.priority==acting_player() and engine.phase!="mulligan" and engine.pending.is_empty() and not free_main()
func should_ask_response() -> bool:
 if not in_response_window(): return false
 match response_mode:
  ResponseMode.ON: return true
  ResponseMode.OFF: return false
 return engine.has_response(acting_player())
func pass_response():
 engine.pass_priority(acting_player())
 message=""
 render()
func response_disabled() -> bool:
 return network_locked() or response_mode==ResponseMode.OFF and in_response_window()
func cycle_response_mode():
 set_response_mode((response_mode+1)%RESPONSE_LABELS.size())
func set_response_mode(mode: int):
 response_mode=clampi(mode,ResponseMode.DEFAULT,ResponseMode.OFF)
 if response_disabled():
  # Uncommitted response selections are private and can be discarded without paying.
  engine.paid_cast_uid=-1
  local={}; selection=[]; message=""; drag_uid=0; dragging=false
  if is_instance_valid(drag_art): drag_art.queue_free()
 clock_time=0
 render()
func _process(delta):
 if engine==null: return
 if network_session!=null:
  if not network_session.snapshots.is_empty() and not revealing() and not table.combat_animating:
   var packet=network_session.pop_snapshot()
   local={};selection=[];picker.reset();attack_preview_uid=0;close_overlay()
   if packet.get("recovery",false):reveal_player.reset()
   engine.apply_snapshot(packet.projection);render()
  if is_instance_valid(network_status_label):
   network_status_label.text=network_session.connection_status() if not network_session.can_act(true) else ""
  if is_instance_valid(network_latency_label):network_latency_label.text=network_session.latency_text()
 if not engine.presentation_events.is_empty() or revealing():
  render();return
 update_badge_positions()
 if table.combat_animating or history_open or debug_drag_uid!=0 or observing or modal or not local.is_empty() or drag_uid!=0 or engine.winner!=-2: return
 if not fast_mode and (table.is_animating() or Time.get_ticks_msec()<banner_until): return
 clock_time+=delta
 if clock_time<(0.02 if fast_mode else 0.48): return
 clock_time=0
 var before=engine.revision
 if network_session!=null:
  if network_session.can_act(true) and in_response_window() and not should_ask_response():engine.pass_priority(acting_player())
 elif debug_mode:
  if in_response_window() and not should_ask_response(): engine.pass_priority(acting_player())
 elif engine.phase=="mulligan":
  if not engine.players[1].mulligan_done: experiment_agent.step(engine,debug_mode,network_session)
 elif not engine.pending.is_empty():
  if engine.pending.owner==1: experiment_agent.step(engine,debug_mode,network_session)
 elif engine.priority==1: experiment_agent.step(engine,debug_mode,network_session)
 elif in_response_window() and not should_ask_response(): engine.pass_priority(acting_player())
 if before!=engine.revision or last_revision!=engine.revision: render()

func clear_children(node: Node):
 for child in node.get_children(): node.remove_child(child); child.queue_free()
func right_rect(rect: Rect2) -> Rect2:
 if rect.position.x>=1290:
  rect.position.x=SIDEBAR.position.x+(rect.position.x-1290)*SIDEBAR.size.x/294.0
  rect.size.x*=SIDEBAR.size.x/294.0
 return rect

func txt(text: String,rect: Rect2,font: int=18,color: Color=Color("#e8edf0"),parent: Node=null):
 if parent==null:rect=right_rect(rect)
 var label=host.label(hud if parent==null else parent,text,rect,font,color)
 if building_prompt and parent==null: label.set_meta("choice_widget",true)
 return label
func btn(text: String,rect: Rect2,action: Callable,accent: bool=false,parent: Node=null):
 if parent==null and rect.position.y>=90:rect=right_rect(rect)
 var inspection_action=text in ["设置","对局记录","单位自动排序","聊天","继续游戏","继续等待","不再等待，离开对局","返回联机房间","观察战场","返回选择","视角复原","×","同意悔棋","拒绝悔棋","取消请求","3D 斜视","2D 上方俯视"]
 var button=host.button(hud if parent==null else parent,text,rect,func():
  if not network_locked() or inspection_action:action.call(),accent)
 if network_locked() and not inspection_action:button.disabled=true
 if building_prompt and parent==null: button.set_meta("choice_widget",true)
 return button

func battle_button(text: String,desktop_rect: Rect2,_android_y: float,action: Callable,accent: bool=false) -> Button:
 var result=btn(text,desktop_rect,action,accent)
 responsive.add_phase_action(result)
 return result

func android_choice_box(title: String,key: String) -> Panel:
 var rect=responsive.choice_rect
 battle_choice_scroll=null
 if is_instance_valid(android_choice_panel):android_choice_panel.queue_free();android_choice_panel=null
 if is_instance_valid(android_choice_restore):android_choice_restore.queue_free();android_choice_restore=null
 if android_choice_hidden_key==key:
  android_choice_restore=host.button(hud,"展开"+title,Rect2(rect.position,Vector2(minf(260,rect.size.x),host.ui_metrics.hit)),func():android_choice_hidden_key="";render())
  android_choice_restore.name="AndroidChoiceRestore"
  return null
 var panel=host.box(hud,rect,Color("#101c28"),host.GOLD)
 panel.name="AndroidChoicePanel"
 panel.mouse_filter=Control.MOUSE_FILTER_STOP
 android_choice_panel=panel
 var heading=txt(title,Rect2(20,10,rect.size.x-190,host.ui_metrics.hit),23,host.GOLD,panel)
 heading.clip_text=true
 var hide=host.button(panel,"隐藏",Rect2(rect.size.x-146,10,126,host.ui_metrics.hit),func():android_choice_hidden_key=key;render())
 hide.name="AndroidChoiceHide"
 return panel

func android_choice_on_top():
 if is_instance_valid(android_choice_panel):hud.move_child(android_choice_panel,-1)
 if is_instance_valid(android_choice_restore):hud.move_child(android_choice_restore,-1)

func toggle_android_palette(who: int):
 if not is_android:return
 android_palette_owner=-1 if android_palette_owner==who else who
 android_palette_auto_open=false
 android_palette_scroll_x=0
 render()

func render_android_palette(available: Array):
 var possession_active=engine.phase=="possession" and engine.pending.get("kind","")=="possession" and engine.pending.get("owner",-1)==local_seat and acting_player()==local_seat and not network_locked()
 if possession_active and not android_palette_was_possession:
  android_palette_owner=local_seat
  android_palette_auto_open=true
 elif not possession_active and android_palette_was_possession and android_palette_auto_open:
  android_palette_owner=-1
  android_palette_auto_open=false
 android_palette_was_possession=possession_active
 android_palette_panel=null
 android_palette_scroll=null
 android_palette_tiles={}
 for i in range(2):
  var who=local_seat if i==0 else 1-local_seat
  var title=("我方" if i==0 else "敌方")+"颜色盘"
  var toggle=responsive.palette_toggle(who,i,title)
  toggle.name="AndroidPaletteToggle"+str(who)
  toggle.toggle_mode=true
  toggle.set_pressed_no_signal(android_palette_owner==who)
  toggle.tooltip_text="点击查看或关闭"+title
 if android_palette_owner not in [0,1]:return
 var who=android_palette_owner
 var cards=engine.players[who].palette
 var panel=host.box(hud,ANDROID_PALETTE_RECT,Color("#101c28"),host.GOLD)
 panel.name="AndroidPalettePanel"
 panel.mouse_filter=Control.MOUSE_FILTER_STOP
 android_palette_panel=panel
 var heading=txt(("我方" if who==local_seat else "敌方")+"颜色盘  %d 张" % cards.size(),Rect2(18,12,ANDROID_PALETTE_RECT.size.x-190,host.ui_metrics.hit*0.5),24,host.GOLD,panel)
 heading.mouse_filter=Control.MOUSE_FILTER_IGNORE
 var hint=txt("点击卡牌进行凭依、付费或选择目标",Rect2(18,host.ui_metrics.hit*0.55,ANDROID_PALETTE_RECT.size.x-190,host.ui_metrics.small*1.5),16,host.MUTED,panel)
 hint.mouse_filter=Control.MOUSE_FILTER_IGNORE
 var close=host.button(panel,"关闭",Rect2(ANDROID_PALETTE_RECT.size.x-150,12,132,host.ui_metrics.hit),func():toggle_android_palette(who))
 close.name="AndroidPaletteClose"
 var scroll=ScrollContainer.new()
 scroll.name="AndroidPaletteScroll"
 scroll.position=Vector2(18,host.ui_metrics.hit+24)
 scroll.size=Vector2(ANDROID_PALETTE_RECT.size.x-36,ANDROID_PALETTE_RECT.size.y-scroll.position.y-12)
 scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_AUTO
 scroll.scroll_deadzone=8
 panel.add_child(scroll)
 android_palette_scroll=scroll
 var row=HBoxContainer.new()
 row.add_theme_constant_override("separation",12)
 scroll.add_child(row)
 if cards.is_empty():
  var empty=txt("颜色盘中没有卡牌",Rect2(20,85,500,48),20,host.MUTED,panel)
  empty.mouse_filter=Control.MOUSE_FILTER_IGNORE
 for c in cards:
  if not engine.cards.has(c.card_id):continue
  var holder=VBoxContainer.new()
  var holder_width=maxf(164,host.ui_metrics.small*7)
  holder.custom_minimum_size=Vector2(holder_width,0)
  holder.mouse_filter=Control.MOUSE_FILTER_PASS
  row.add_child(holder)
  var uid=int(c.uid)
  var tile=card_tile(holder,c,Rect2(0,0,holder_width,150),func():object_clicked(uid))
  tile.custom_minimum_size=Vector2(holder_width,150)
  tile.name="AndroidPaletteCard"+str(uid)
  tile.set_meta("palette_uid",uid)
  tile.mouse_filter=Control.MOUSE_FILTER_PASS
  tile.tooltip_text=hand_card_tooltip(c)
  tile.gui_input.connect(func(event):
   if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_RIGHT:
    inspect_card(c.card_id,uid);tile.accept_event())
  var selected=uid in selected_uids() or local.get("plan",[]).any(func(reservation):return reservation.uid==uid)
  var legal=uid in available
  var frame=host.style(Color("#172936"),Color("#ffd65c") if selected else Color("#359bff") if legal else Color("#416078"))
  frame.set_border_width_all(4 if selected or legal else 2)
  tile.add_theme_stylebox_override("panel",frame)
  if c.tapped and not selected and not legal:tile.modulate=Color(0.67,0.67,0.67)
  var name=Label.new();name.text=engine.cards[c.card_id].name;holder.add_child(name)
  name.add_theme_font_size_override("font_size",host.ui_metrics.small)
  name.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
  name.max_lines_visible=2;name.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
  name.custom_minimum_size=Vector2(0,host.ui_metrics.small*2.6)
  name.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
  name.mouse_filter=Control.MOUSE_FILTER_IGNORE
  var color_names="".join(engine.Pack.colors(engine,c))
  var state=Label.new();state.text=("横置" if c.tapped else "竖直")+(" · "+color_names if not color_names.is_empty() else "");holder.add_child(state)
  state.add_theme_font_size_override("font_size",host.ui_metrics.small)
  state.add_theme_color_override("font_color",host.MUTED)
  state.clip_text=true;state.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
  state.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
  state.mouse_filter=Control.MOUSE_FILTER_IGNORE
  android_palette_tiles[uid]=tile
 scroll.set_deferred("scroll_horizontal",android_palette_scroll_x)
func highlights() -> Array:
 var result=[]
 if network_locked():return result
 if engine.phase=="mulligan" and not engine.players[acting_player()].mulligan_done:
  return engine.players[acting_player()].hand.map(func(c): return c.uid)
 if not local.is_empty():
  if local.mode in ["target","payment"]:
   for resource in payment_sources(): result.append(resource.uid)
  if local.mode=="target":
   for target in picker.available_refs():
    if target.has("uid"): result.append(target.uid)
  return result
 if engine.pending.get("owner",-1)==acting_player():
  if engine.pending.kind=="block": return engine.legal_blockers().map(func(c): return c.uid)
  if engine.pending.kind=="discard": return engine.players[acting_player()].hand.map(func(c): return c.uid)
  if engine.pending.kind in ["trigger","effect_choice"]: return picker.available_refs().filter(func(t): return t.has("uid")).map(func(t): return t.uid)
  if engine.pending.kind=="possession":
   result=engine.players[acting_player()].palette.filter(func(c): return not c.tapped and engine.can_possess(c)).map(func(c): return c.uid)
   if selected_in_zone("palette")!=0: result.append_array(engine.players[acting_player()].hand.filter(func(c): return engine.can_possess(c)).map(func(c): return c.uid))
   return result
 if response_disabled(): return result
 for c in engine.legal_casts(acting_player()): result.append(c.uid)
 for c in engine.players[acting_player()].field:
  if not engine.available_actions(acting_player(),c.uid).is_empty(): result.append(c.uid)
 return result
func revealing() -> bool:
 return is_instance_valid(reveal_player) and reveal_player.busy
func render():
 if not is_instance_valid(ui): return
 if network_session==null and not replay_recording.finished and replay_recording.last_key!="offline:"+str(engine.revision)+":"+("complete" if engine.winner!=-2 else "playing"):
  var room={"format":1,"round":1,"status":"complete" if engine.winner!=-2 else "playing","winner":engine.winner,"names":engine.player_names,"scores":[1 if engine.winner==0 else 0,1 if engine.winner==1 else 0]}
  replay_recording.record({"game_id":"offline","sequence":engine.revision,"room":room,"projection":preload("res://net/observer_projection.gd").build(engine,engine.presentation_events,0,true)},0)
  if engine.winner!=-2:
   replay_recording.finish(room);host.call_deferred("offer_replay",replay_recording)
 # Finish damage/collision display before showing subsequent zone changes.
 if table.combat_animating:return
 if engine.combat.get("damage_batch",0)>0 and engine.combat.damage_batch!=table.last_damage_batch and table.visuals.has("card_"+str(engine.combat.attacker.uid)):
  table.sync();return
 if is_instance_valid(reveal_player):
  if not engine.presentation_events.is_empty():
   reveal_player.enqueue(engine.presentation_events);engine.presentation_events.clear()
  if revealing():
   refresh_stackable_badges()
   update_badge_positions()
   return
 if attack_preview_uid!=0 and not engine.can_attack(acting_player(),attack_preview_uid):
  selection.erase(attack_preview_uid); attack_preview_uid=0
 close_overlay(true)
 if is_instance_valid(android_palette_scroll):android_palette_scroll_x=android_palette_scroll.scroll_horizontal
 clear_children(hud)
 android_choice_panel=null
 android_choice_restore=null
 battle_choice_scroll=null
 battle_choice_touch_index=-1
 last_revision=engine.revision
 sync_picker()
 if android_action_uid>0 and (not local.is_empty() or not engine.pending.is_empty() or network_locked()):
  android_action_uid=0;action_menu_open=false
 refresh_payment_plan()
 responsive.begin_frame()
 var available=highlights()
 table.targetable_stacks=picker.available_refs().filter(func(t): return t.has("stack_id")).map(func(t): return t.stack_id) if picker_active() else []
 table.selected_stacks=picker.selected_refs().filter(func(t): return t.has("stack_id")).map(func(t): return t.stack_id)
 table.stack_target_uids=interactive_stack_target_uids()
 table.sync(local.get("plan",[]),selected_uids(),available,not previous_snapshot.is_empty())
 render_deck_casts()
 render_hands(available)
 refresh_stage_tooltip()
 stack_panel.sync()
 render_grave_targets()
 table.presented_moves.clear()
 rebuild_badges()
 if network_session!=null:
  network_latency_label=txt(network_session.latency_text(),Rect2(1000,58,303,31),16,host.MUTED)
  network_latency_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
  network_latency_label.tooltip_text="双方各自测到对端的往返延迟（RTT），约每2秒更新。"
  render_undo()
 if debug_mode:
  txt("操作："+player_caption(acting_player()),Rect2(866,15,158,32),18,host.GOLD)
 life_widgets={}
 render_life(1-local_seat,responsive.enemy_life)
 render_life(local_seat,responsive.own_life)
 if replay_view():
  for i in range(2):
   var who=local_seat if i==0 else 1-local_seat
   var button=host.button(hud,("己方" if i==0 else "对手")+"手牌 %d" % engine.players[who].hand.size(),Rect2(1366+i*110,608,102,30),func():browse_zone(who,"hand"))
   button.add_theme_font_size_override("font_size",14)
 txt("手牌 %d" % engine.players[1-local_seat].hand.size(),OPPONENT_HAND_COUNT,18,host.WHITE,hud)
 building_prompt=true
 if not table.combat_animating: render_prompt()
 building_prompt=false
 if is_android:render_android_palette(available)
 if not message.is_empty(): txt(message,NOTICE,18,Color("#f0cf93")).horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
 if not engine.log.is_empty(): txt(engine.log.back(),responsive.log_rect,15,host.MUTED)
 update_inspection()
 if last_phase!=engine.phase or last_turn!=engine.turn:
  show_phase_banner()
 last_phase=engine.phase; last_turn=engine.turn
 previous_snapshot=table.card_snapshot()
 if network_locked():pass
 elif engine.winner!=-2 and not table.combat_animating: result_overlay()
 elif engine.pending.get("kind","")=="damage_assignment" and engine.pending.owner==acting_player() and not table.combat_animating: damage_dialog()
 elif engine.pending.get("kind","")=="ward_order" and engine.pending.owner==acting_player() and not table.combat_animating: ward_order_menu()
 elif engine.pending.get("kind","")=="trigger_order" and engine.pending.owner==acting_player() and not table.combat_animating: trigger_order_menu()
 elif region_picker_needed() and not table.combat_animating: region_picker()
 if is_android and android_action_uid>0 and local.is_empty() and engine.pending.is_empty() and not network_locked():
  var action_card=engine.find_card(android_action_uid)
  if not action_card.is_empty() and action_card.zone=="field" and action_card.owner==acting_player():
   render_android_actions(action_card,engine.available_actions(acting_player(),android_action_uid,true).filter(func(action):return action.enabled or action.type in ["ability","extension","ran_discount"]))
  else:android_action_uid=0;action_menu_open=false
 android_choice_on_top()
 refresh_observation()
 if debug_open and is_instance_valid(debug_root): ui.move_child(debug_root,-1); ui.move_child(observe_button,-1)
 if debug_open and not debug_dragging and not observing and not table.combat_animating:
  var scroll_at=browser_scroll.scroll_vertical
  browse_zone(browser_owner,browser_zone,scroll_at)
 update_browser_styles()
 if history_open and is_instance_valid(history_root): ui.move_child(history_root,-1)
 raise_card_search_overlay()
 responsive.position_persistent()
 if is_instance_valid(android_back_button):ui.move_child(android_back_button,-1)

func render_hands(available: Array):
 render_hand_zone_tabs()
 sync_hand_nodes(local_seat,hand_nodes,hand_layer,available)
 sync_hand_nodes(1-local_seat,enemy_nodes,opponent_layer,available if debug_mode else [])
func replay_view() -> bool:
 return network_session!=null and network_session.replay_mode
func sync_hand_nodes(who: int,nodes: Dictionary,parent: Control,available: Array):
 var cards=displayed_hand_cards(who) if who==local_seat or debug_mode or replay_view() else []
 var compact=is_android and who==local_seat and engine.pending.get("kind","")=="possession"
 var arrangement=host.ui_metrics.hand_layout(HAND,cards.size(),compact)
 if not is_android:
  var buff_space=160 if not player_buffs(who).is_empty() else 0
  arrangement={"card":Vector2(146,204),"stride":minf(154,(HAND.size.x-80-buff_space)/maxi(1,cards.size())),"extent":HAND.size.x,"inset":15+buff_space}
 if who==local_seat:
  hand_scroll.position=HAND.position;hand_scroll.size=HAND.size
  hand_layer.custom_minimum_size=Vector2(arrangement.extent,HAND.size.y-16)
  hand_layer.size=hand_layer.custom_minimum_size
 var ids=cards.map(func(c): return c.uid)
 for uid in nodes.keys():
  if uid in ids: continue
  var node=nodes[uid]; nodes.erase(uid)
  if table.presented_moves.has(uid):node.queue_free();continue
  if hand_tweens.has(uid) and hand_tweens[uid].is_valid(): hand_tweens[uid].kill()
  node.mouse_filter=Control.MOUSE_FILTER_IGNORE
  var tween=create_tween().set_parallel(true)
  tween.tween_property(node,"modulate:a",0.0,0.18)
  tween.tween_property(node,"position:y",node.position.y-45,0.18)
  tween.chain().tween_callback(node.queue_free)
 for i in range(cards.size()):
  var c=cards[i]
  var tile_size=arrangement.card if who==local_seat else Vector2(70,98) if is_android or debug_mode or replay_view() else Vector2(54,75)
  var stride=arrangement.stride if who==local_seat else minf(74 if is_android or debug_mode or replay_view() else 52,750.0/maxi(1,cards.size()))
  var target=Vector2(arrangement.inset+i*stride,maxf(6,HAND.size.y-tile_size.y-20) if is_android else 17) if who==local_seat else Vector2(STAGE.get_center().x-tile_size.x/2-(cards.size()-1)*stride/2+i*stride,responsive.log_rect.end.y+8 if is_android else 64)
  var fresh=not nodes.has(c.uid)
  if fresh:
   var tile=preload("res://scripts/duel_hand_card.gd").new()
   tile.size=tile_size; parent.add_child(tile); tile.build(self,c,c.card_id=="back" or who!=local_seat and not debug_mode and not replay_view())
   nodes[c.uid]=tile
   var old=previous_snapshot.get(c.uid,{})
   tile.position=(project(table.zone_position(old.get("zone","deck"),who))-HAND.position if who==local_seat else project(table.zone_position(old.get("zone","deck"),who))) if not previous_snapshot.is_empty() else target+Vector2(0,65 if who==local_seat else -65)
   tile.modulate.a=0.1
  var node=nodes[c.uid]
  if node.size!=tile_size:
   node.size=tile_size
   if not node.hidden_card:
    var card_info=engine.cards[c.card_id]
    node.update_cost(card_info.cost,card_info.get("variable_cost",""))
  if node.card_id!=c.card_id or node.art_id!=c.get("art_id",""):
   node.card_id=c.card_id
   node.art_id=c.get("art_id","")
   if who==local_seat or debug_mode or replay_view():
    var info=engine.cards[c.card_id]
    node.art.texture=card_texture(c)
    node.update_cost(info.cost,info.get("variable_cost",""))
  if not node.hidden_card:node.tooltip_text=hand_card_tooltip(c)
  node.show()
  if table.presented_moves.has(c.uid):
   node.position=target;node.modulate.a=1;node.set_meta("target",target);fresh=false
  node.update_style(c.uid in available or (c.zone!="hand" and can_use_region_card(c)),c.uid in selected_uids(),ConditionHints.active(engine,c))
  if fresh or node.get_meta("target",Vector2(-999,-999))!=target:
   if hand_tweens.has(c.uid) and hand_tweens[c.uid].is_valid(): hand_tweens[c.uid].kill()
   var tween=create_tween().set_parallel(true)
   tween.tween_property(node,"position",target,0.42).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
   tween.tween_property(node,"modulate:a",1.0,0.3)
   hand_tweens[c.uid]=tween; node.set_meta("target",target)

func render_deck_casts():
 clear_children(deck_cast_layer); deck_cast_tiles={}; deck_peek_tile=null
 if local_seat in [0,1] and engine.Cat.may_peek(engine,local_seat) and not engine.players[local_seat].deck.is_empty():
  var top_card=engine.players[local_seat].deck[0]
  if top_card.card_id!="back" and engine.cards.has(top_card.card_id):
   deck_peek_tile=preload("res://scripts/duel_hand_card.gd").new()
   deck_peek_tile.size=Vector2(74,104);deck_cast_layer.add_child(deck_peek_tile);deck_peek_tile.build(self,top_card)
   deck_peek_tile.tooltip_text="当前牌库顶牌 · "+hand_card_tooltip(top_card)
   deck_peek_tile.update_style(engine.cast_error(local_seat,top_card.uid).is_empty(),top_card.uid in selected_uids())
 if not response_disabled() and free_main():
  for who in range(2):
   if who!=acting_player() or who!=local_seat and not debug_mode:continue
   var cards=engine.legal_casts(who).filter(func(c):return c.zone=="deck" and engine.Extra.has(engine.cards[c.card_id],"deck_damage"))
   # Display copies independently without revealing their order in the library.
   cards.sort_custom(func(a,b):return a.uid<b.uid)
   for c in cards:
    var tile=preload("res://scripts/duel_hand_card.gd").new()
    tile.size=Vector2(62,87);deck_cast_layer.add_child(tile);tile.build(self,c)
    tile.tooltip_text="可从牌库使用 · "+hand_card_tooltip(c)
    tile.update_style(true,c.uid in selected_uids())
    deck_cast_tiles[c.uid]=tile
 update_deck_cast_positions()

func update_deck_cast_positions():
 if not is_instance_valid(deck_cast_layer):return
 if is_instance_valid(deck_peek_tile):
  var peek_card=engine.find_card(deck_peek_tile.uid)
  var peek_key="pdeck" if local_seat==0 else "adeck"
  if peek_card.is_empty() or not table.piles.has(peek_key):deck_peek_tile.hide()
  else:
   var peek_rect=projected_deck_rect(peek_key)
   deck_peek_tile.position=Vector2(peek_rect.position.x-deck_peek_tile.size.x-10,peek_rect.position.y)
   deck_peek_tile.visible=peek_card.zone=="deck" and not engine.players[local_seat].deck.is_empty() and engine.players[local_seat].deck[0].uid==peek_card.uid and STAGE.intersects(Rect2(deck_peek_tile.position,deck_peek_tile.size)) and not table.combat_animating and not revealing()
 var indices={0:0,1:0}
 for uid in deck_cast_tiles:
  var tile=deck_cast_tiles[uid]
  var c=engine.find_card(uid)
  var key="pdeck" if c.get("owner",0)==0 else "adeck"
  if c.is_empty() or not table.piles.has(key):tile.hide();continue
  var rect=projected_deck_rect(key)
  tile.position=Vector2(rect.end.x+10,rect.position.y+indices[c.owner]*28)
  tile.visible=c.zone=="deck" and free_main() and not response_disabled() and STAGE.intersects(Rect2(tile.position,tile.size)) and not table.combat_animating and not revealing()
  indices[c.owner]+=1

func projected_deck_rect(key: String) -> Rect2:
 var top=table.piles[key].get_node("Top")
 var half=table.CARD_SIZE*table.SLOT_SCALE/2.0
 var rect=Rect2(project(top.to_global(Vector3(-half.x,0,-half.y))),Vector2.ZERO)
 for corner in [Vector3(half.x,0,-half.y),Vector3(-half.x,0,half.y),Vector3(half.x,0,half.y)]:rect=rect.expand(project(top.to_global(corner)))
 return rect

func rebuild_badges():
 clear_children(badges); card_badges={}
 for key in table.descriptors:
  var d=table.descriptors[key]
  if d.zone=="stack":
   for entry in engine.stack:
    if entry.id!=d.stack_id or entry.kind!="ability" and not entry.has("ability_text"): continue
    var caption=AbilityCaption.text(entry)
    var root=Control.new(); root.mouse_filter=Control.MOUSE_FILTER_IGNORE; badges.add_child(root)
    var detail_height=108 if caption.begins_with("来源：") else 68
    var label=txt(caption,Rect2(-118,0,236,detail_height),15 if detail_height>68 else 16,host.WHITE,root)
    label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
    label.size=Vector2(236,detail_height)
    label.add_theme_color_override("font_shadow_color",Color("#081019")); label.add_theme_constant_override("shadow_offset_y",2)
    label.add_theme_color_override("font_outline_color",Color("#081019")); label.add_theme_constant_override("outline_size",5)
    card_badges[key]={"root":root,"zone":"stack","caption":label,"stack_index":engine.stack.find(entry)}
   continue
  if d.zone not in ["field","palette","leader"]: continue
  var c=(table.combat_display_cards.get(d.uid,table.old_cards.get(d.uid,{})) if table.damage_revealed else table.old_cards.get(d.uid,{})) if table.combat_animating else engine.find_card(d.uid)
  if c.is_empty(): continue
  var root=Control.new(); root.mouse_filter=Control.MOUSE_FILTER_IGNORE; badges.add_child(root)
  var parts={"root":root,"zone":d.zone,"owner":d.owner}
  var icons=[]
  if c.get("leader",false):icons.append("res://assets/leader_crown.svg")
  if d.zone=="field" and engine.is_unit(c) and engine.Extra.keyword(engine,c,"不占战场格"):icons.append("res://assets/slot_ghost.svg")
  var copy_marker=String(engine.cards[c.card_id].get("copy_marker",""))
  if copy_marker in ["keiki","alice","yukari","mountain_fairy"]:icons.append("res://assets/copy_markers/"+copy_marker+".png")
  if not icons.is_empty():
   parts.icons=[]
   for icon_path in icons:
    var icon=TextureRect.new()
    icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
    icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    icon.texture=load(icon_path)
    icon.size=Vector2(CARD_ICON_SIZE,CARD_ICON_SIZE)
    icon.mouse_filter=Control.MOUSE_FILTER_IGNORE
    icon.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
    root.add_child(icon);parts.icons.append(icon)
  if d.zone=="field" and engine.is_unit(c):
   var panel=host.box(root,Rect2(0,0,76,25),Color("#111d2b"),Color("#aaa080")); panel.mouse_filter=Control.MOUSE_FILTER_IGNORE
   var stat_names=["power","health","spirit"]
   var positions=[0,27,52]
   parts.values={}
   for index in range(3):
    var key_name=stat_names[index]
    var value=c.get("display_stats",{}).get(key_name,engine.stat(c,key_name)-(c.damage if key_name=="health" else 0))
    var base=int(engine.cards[c.card_id][key_name])
    var label=txt(str(value),Rect2(positions[index],0,24,25),15,stat_color(value,base),panel)
    label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
    parts.values[key_name]=label
   txt("/",Rect2(23,0,7,25),15,host.WHITE,panel)
   txt("·",Rect2(48,0,7,25),15,host.WHITE,panel)
   parts.stats=panel
   if c.get("courage",0)>0:parts.courage=txt("◆ %d" % c.courage,Rect2(0,0,56,24),17,host.GOLD,root)
   var marker=combat_marker(c.uid)
   if not marker.is_empty():
    var icon=TextureRect.new(); icon.size=Vector2(42,42)
    icon.texture=load("res://assets/combat_"+marker+".svg")
    icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; icon.mouse_filter=Control.MOUSE_FILTER_IGNORE
    icon.set_meta("combat_role",marker); root.add_child(icon); parts.marker=icon
  elif d.zone=="leader" and c.timer>0:
   parts.sick=txt("计时 %d" % c.timer,Rect2(0,0,100,24),17,host.GOLD,root)
  var marks=board_counter_text(c)
  if not marks.is_empty():
   var mark=txt(marks,Rect2(0,0,100,40),13,Color("#fff2bb"),root)
   mark.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
   mark.add_theme_color_override("font_outline_color",Color("#081019"));mark.add_theme_constant_override("outline_size",5)
   parts.counters=mark
  if d.get("members",[]).size()>1 or d.zone=="field" and engine.cards[c.card_id].get("stackable",false):
   var count=txt("×%d" % d.members.size(),Rect2(0,0,80,32),26,host.GOLD,root)
   count.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;count.add_theme_color_override("font_outline_color",Color("#081019"));count.add_theme_constant_override("outline_size",6)
   count.visible=d.members.size()>1
   parts.token_count=count
  if d.get("copy_total",0)>1:
   var fanned=d.get("fanned",false)
   var number=txt(str(d.copy_index) if fanned else "%d/%d" % [d.copy_index,d.copy_total],Rect2(0,0,28 if fanned else 48,22),12 if fanned else 14,host.GOLD,root)
   number.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
   number.add_theme_color_override("font_outline_color",Color("#081019"));number.add_theme_constant_override("outline_size",5)
   parts.copy_number=number;parts.fanned=fanned
  card_badges[key]=parts
 for key in table.piles:
  if "exile" in key and engine.players[0 if key.begins_with("p") else 1].exile.is_empty(): continue
  var root=Control.new(); root.mouse_filter=Control.MOUSE_FILTER_IGNORE; badges.add_child(root)
  card_badges[key]={"root":root,"zone":"pile"}
  var zone_name="deck" if "deck" in key else "exile" if "exile" in key else "grave"
  var who=0 if key.begins_with("p") else 1
  var count=table.piles[key].get_meta("count",0) if table.combat_animating else engine.players[who][zone_name].size()
  var label=txt({"deck":"牌库 ","grave":"墓地 ","exile":"除外 "}[zone_name]+str(count),Rect2(-48,0,96,26),17,host.WHITE,root)
  label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
 update_badge_positions()
func refresh_stackable_badges():
 for key in card_badges:
  if not table.descriptors.has(key):continue
  var parts=card_badges[key]
  if parts.get("zone","")!="field" or not parts.has("token_count"):continue
  var d=table.descriptors[key]
  var c=engine.find_card(d.uid)
  if c.is_empty() or c.zone!="field" or not engine.cards[c.card_id].get("stackable",false):continue
  var isolated=d.uid in table.chosen or d.uid in table.stack_target_uids or table.reserved.any(func(r):return r.uid==d.uid)
  var count=1 if isolated else engine.stackable_members(c).filter(func(u):return u.uid not in table.chosen and u.uid not in table.stack_target_uids and not table.reserved.any(func(r):return r.uid==u.uid)).size()
  parts.token_count.text="×%d" % count
  parts.token_count.visible=count>1
func projected_card_rect(node: Node3D) -> Rect2:
 var rect=Rect2(project(node.to_global(Vector3(-0.975,0,-1.36))),Vector2.ZERO)
 for corner in [Vector3(0.975,0,-1.36),Vector3(-0.975,0,1.36),Vector3(0.975,0,1.36)]: rect=rect.expand(project(node.to_global(corner)))
 return rect
func position_card_icons(icons: Array, rect: Rect2):
 var icon_count=icons.size()
 var columns=maxi(1,mini(icon_count,int(floor((rect.size.x-2.0*CARD_ICON_INSET+CARD_ICON_GAP)/(CARD_ICON_SIZE+CARD_ICON_GAP)))))
 var right=rect.size.x/2.0-CARD_ICON_INSET
 var top=-rect.size.y/2.0+CARD_ICON_INSET
 for index in range(icon_count):
  var row=int(index/columns)
  var column=index%columns
  var row_count=mini(columns,icon_count-row*columns)
  var row_width=row_count*CARD_ICON_SIZE+(row_count-1)*CARD_ICON_GAP
  icons[index].position=Vector2(right-row_width+column*(CARD_ICON_SIZE+CARD_ICON_GAP),top+row*(CARD_ICON_SIZE+CARD_ICON_GAP))
func update_badge_positions():
 if not is_instance_valid(table): return
 update_deck_cast_positions()
 var stack_rects=[]
 var caption_rects=[]
 for key in table.descriptors:
  if table.descriptors[key].zone=="stack": stack_rects.append(projected_card_rect(table.visuals[key]).grow(6))
 for key in card_badges:
  var parts=card_badges[key]; var root=parts.root
  if table.visuals.has(key):
   var node=table.visuals[key]
   var rect=projected_card_rect(node)
   root.position=rect.get_center()
   if parts.has("stats"): parts.stats.position=Vector2(-38,rect.size.y/2-24)
   if parts.has("courage"):parts.courage.position=Vector2(-rect.size.x/2,-rect.size.y/2-20)
   if parts.has("counters"):parts.counters.position=Vector2(-50,rect.size.y/2-58 if parts.has("stats") else -rect.size.y/2+12)
   if parts.has("token_count"):parts.token_count.position=Vector2(-40,rect.size.y/2-33)
   if parts.has("copy_number"):parts.copy_number.position=Vector2(-rect.size.x/2+2 if parts.fanned else rect.size.x/2-46,rect.size.y/2-25)
   if parts.has("marker"): parts.marker.position=Vector2(rect.size.x/2-32,-rect.size.y/2-10)
   if parts.has("sick"): parts.sick.position=Vector2(-49,rect.size.y/2+1)
   if parts.has("icons"):position_card_icons(parts.icons,rect)
   if parts.has("caption"):
    root.position=Vector2(clampf(rect.get_center().x,STAGE.position.x+118,STAGE.end.x-118),rect.end.y+6)
    var occupied=Rect2(root.position+parts.caption.position,parts.caption.size)
    for earlier in caption_rects:
     if occupied.grow(4).intersects(earlier):
      root.position.y=earlier.end.y+8; occupied.position.y=root.position.y
    caption_rects.append(occupied)
  elif table.piles.has(key):
   root.position=project(table.piles[key].position+Vector3(0,0.03,1.3))
  root.visible=STAGE.grow(5).has_point(root.position) or parts.zone=="stack" and root.position.y<790
  if parts.zone!="stack" and stack_rects.any(func(r): return r.has_point(root.position)): root.visible=false

func show_phase_banner():
 clear_children(banner)
 if is_instance_valid(banner_tween): banner_tween.kill()
 var caption=phase_names[engine.phase]
 if engine.turn!=last_turn: caption=("你的回合" if engine.active==local_seat else "对手回合")+" · "+caption
 var label=txt(caption,Rect2(STAGE.get_center()-Vector2(425,90),Vector2(850,76)),42,Color("#fff2c0"),banner)
 label.add_theme_color_override("font_shadow_color",Color(0.01,0.02,0.03,0.95))
 label.add_theme_constant_override("shadow_offset_x",3)
 label.add_theme_constant_override("shadow_offset_y",4)
 label.add_theme_constant_override("outline_size",5)
 label.add_theme_color_override("font_outline_color",Color("#151a24"))
 label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
 banner.modulate.a=0
 banner_tween=create_tween()
 banner_tween.tween_property(banner,"modulate:a",1.0,0.14)
 banner_tween.tween_interval(0.6)
 banner_tween.tween_property(banner,"modulate:a",0.0,0.3)
 banner_until=Time.get_ticks_msec()+1050

func card_texture(c: Dictionary,preview: bool=false) -> Texture2D:
 return host.preview_texture(c.card_id,c.get("art_id","")) if preview else host.texture(c.card_id,c.get("art_id",""))
func card_tile(parent: Node,c: Dictionary,rect: Rect2,clickable: Callable=Callable()) -> Control:
 var tile=host.card(parent,c.card_id,rect,clickable,c.get("art_id",""))
 UnknownArt.apply(tile.get_child(0),tile,engine,c)
 return tile
func inspect_card(id: String,uid: int=0,caption: String="",art_id: String=""):
 inspect_art_id=art_id
 inspect_id=id; inspect_uid=uid; inspect_caption=caption; update_inspection()
func declaration_caption(c: Dictionary) -> String:
 if c.is_empty() or c.get("zone","")!="field" or not engine.Cat.has(engine,c,"character-fdf-101"):return ""
 var declared=String(c.get("locked_name",""))
 return "宣称："+declared if not declared.is_empty() else "宣称：尚未宣称"
func damage_caption(c: Dictionary) -> String:
 var draft=local
 if local.get("uid",0)==c.get("uid",-1) and local.get("mode","")=="target" and local.get("target",{}).is_empty():
  var refs=picker.selected_refs()
  if not refs.is_empty():
   draft=local.duplicate();draft.target={"parts":refs}
  if not picker.specs.is_empty():
   var state=picker.dynamic_state()
   if state.group==1 and not state.current.is_empty():
    draft=local.duplicate();draft.preview_exiled_hand=state.current.size()
 return SpellDamagePreview.caption(engine,c,draft,engine.queries.get("pending_keystones",{}) if engine is RemoteDuel else {})
func card_context_caption(c: Dictionary) -> String:
 var lines=[]
 if not c.is_empty() and c.get("zone","")=="field" and engine.Roster.has(engine.cards[c.card_id],"ran_discount"):
  lines.append("常驻减费：已关闭" if c.get("ran_discount_disabled",false) else "常驻减费：已开启（蓝色费用减少 1）")
 for caption in [declaration_caption(c),damage_caption(c),ConditionHints.caption(engine,c)]:
  if not caption.is_empty():lines.append(caption)
 return "\n".join(lines)
func hand_card_tooltip(c: Dictionary) -> String:
 var info=engine.cards[c.card_id]
 var result=info.name+"\n"+CostDisplay.caption(info.cost)+( "  "+info.variable_cost+"X" if not info.variable_cost.is_empty() else "")
 var context=card_context_caption(c)
 return result+("\n"+context if not context.is_empty() else "")
func refresh_stage_tooltip():
 stage.tooltip_text=""
 table.set_hovered_card(0 if revealing() or table.combat_animating or history_open or modal and not observing else stage_hover_uid)
 if revealing() or table.combat_animating or history_open or modal and not observing:return
 var c=engine.find_card(stage_hover_uid)
 var context=card_context_caption(c)
 if not context.is_empty():stage.tooltip_text=engine.cards[c.card_id].name+"\n"+context
func inspect_declaring_unit(c: Dictionary):
 if not declaration_caption(c).is_empty() or not c.is_empty() and c.get("zone","")=="field" and engine.Roster.has(engine.cards[c.card_id],"ran_discount"):inspect_card(c.card_id,c.uid)
func update_inspection():
 var current=engine.find_card(inspect_uid)
 var declared=card_context_caption(current) if inspect_id not in ["back","potato"] else ""
 var enabled=not current.is_empty() and engine.has_leader_ability(current)
 inspection.visible=host.show_card_inspection and not inspect_id.is_empty()
 var counters=counter_lines(current)
 var shown_id=current.card_id if not current.is_empty() and inspect_id not in ["back","potato"] else inspect_id
 var info=engine.cards.get(shown_id,{})
 var inherited_keywords=[]
 var inherited_abilities=[]
 if not current.is_empty() and engine.Roster.has(info,"character-fdn-007"):
  var base_id=shown_id
  var visited={}
  while not visited.has(base_id):
   visited[base_id]=true
   var source_id=String(engine.cards[base_id].get("copy_source_id",""))
   if source_id.is_empty() or not engine.cards.has(source_id):break
   base_id=source_id
  var base_info=engine.cards[base_id]
  for keyword in info.get("keywords",[]):
   if keyword not in base_info.get("keywords",[]):inherited_keywords.append(keyword)
  for ability in info.get("abilities",[]):
   if ability not in base_info.get("abilities",[]):
    var ability_text=String(ability.get("名称",""))
    if not ability_text.is_empty() and ability_text not in inherited_abilities:inherited_abilities.append(ability_text)
 var shown_art=current.get("art_id","") if not current.is_empty() else inspect_art_id
 var signature=str(INSPECTION)+inspect_id+shown_id+shown_art+str(inspect_uid)+inspect_caption+str(enabled)+str(counters)+str(current.get("moods",[]))+str(inherited_keywords)+str(inherited_abilities)+declared
 if signature==inspection_signature: return
 inspection_signature=signature
 clear_children(inspection)
 if inspect_id.is_empty(): return
 var bg=Control.new(); bg.size=INSPECTION.size; bg.mouse_filter=Control.MOUSE_FILTER_IGNORE; inspection.add_child(bg)
 var image=TextureRect.new(); image.position=Vector2(10,10); image.size=Vector2(198,277)
 image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; image.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
 image.texture=host.preview_texture(shown_id,shown_art)
 var landscape=host.landscape_card(inspect_id)
 if landscape:image.size=Vector2(198,142)
 image.mouse_filter=Control.MOUSE_FILTER_IGNORE; bg.add_child(image)
 if inspect_id not in ["back","potato"] and UnknownArt.active(engine,current):
  image.mouse_filter=Control.MOUSE_FILTER_PASS
  UnknownArt.apply(image,image,engine,current)
 var name=inspect_caption if inspect_id=="back" else "红薯" if inspect_id=="potato" else info.name
 var title=txt(name,Rect2(10,164 if landscape else 296,198,74),18,host.GOLD,bg)
 title.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; title.size=Vector2(198,74)
 if info.has("cost"):
  var cost_icons=HexCost.new();cost_icons.position=Vector2(10,239 if landscape else 372)
  bg.add_child(cost_icons);cost_icons.configure(info.cost,false,198,31,info.get("variable_cost",""))
 inspection_text=RichTextLabel.new(); inspection_text.position=Vector2(10,378); inspection_text.size=Vector2(198,270)
 if landscape:inspection_text.position.y=278;inspection_text.size.y=370
 else:inspection_text.position.y=411;inspection_text.size.y=237
 inspection_text.add_theme_font_size_override("normal_font_size",17); inspection_text.add_theme_color_override("default_color",host.WHITE)
 inspection_text.add_theme_color_override("font_outline_color",Color("#081019")); inspection_text.add_theme_constant_override("outline_size",3)
 inspection_text.scroll_active=true; bg.add_child(inspection_text)
 var rules="未公开" if inspect_id=="back" else "任选一种颜色支付 1 点，使用后消失。" if inspect_id=="potato" else info.rules_text
 if not declared.is_empty():
  inspection_text.push_color(host.GOLD);inspection_text.add_text(declared+"\n\n");inspection_text.pop()
 if info.get("fast",false): inspection_text.add_text("高速\n")
 var at=rules.find("自机能力：")
 if at>=0:
  inspection_text.add_text(rules.left(at))
  inspection_text.push_color(host.WHITE if enabled else Color("#78818b"))
  inspection_text.add_text(rules.substr(at)); inspection_text.pop()
 else: inspection_text.add_text(rules)
 if not inherited_keywords.is_empty():inspection_text.add_text("\n继承词条："+"、".join(inherited_keywords))
 if not inherited_abilities.is_empty():inspection_text.add_text("\n继承能力：\n"+"\n".join(inherited_abilities))
 for line in counters:inspection_text.add_text("\n"+line)
 if not current.get("moods",[]).is_empty():inspection_text.add_text("\n已选心情："+"、".join(current.moods))
 inspection_text.set_meta("leader_enabled",enabled)
 layout_inspection(bg,image,title)

func board_counter_text(c: Dictionary) -> String:
 var marks=[]
 var stats=[]
 if c.get("plus_counters",0)>0:stats.append("+"+str(c.plus_counters))
 if c.get("minus_counters",0)>0:stats.append("−"+str(c.minus_counters))
 if not stats.is_empty():marks.append("  ".join(stats))
 for line in counter_lines(c):
  if line.begins_with("属性指示物"):continue
  marks.append(line.replace("色指示物", "").replace("：", " "))
 return "\n".join(marks)

func counter_lines(c: Dictionary) -> Array:
 var lines=[]
 for k in ["drunk_counters","plus_counters","minus_counters","leader_counters","timer","poverty","scare","courage","dream","madness"]:
  var n=int(c.get(k,0))
  if n<=0:continue
  if k=="plus_counters":lines.append("属性指示物：+%d/+%d/+%d" % [n,n,n])
  elif k=="minus_counters":lines.append("属性指示物：-%d/-%d" % [n,n])
  else:
   var names={"drunk_counters":"醉熏熏 +1/+1/+1","leader_counters":"自机","timer":"计时","poverty":"贫穷","scare":"惊吓","courage":"勇气等级","dream":"梦违","madness":"狂乱"}
   lines.append(names[k]+"："+str(n))
 var colors=c.get("color_counters",[])
 for color in engine.COLORS:
  if colors.count(color)>0:lines.append(color+"色指示物："+str(colors.count(color)))
 lines.append_array(ward_timeline(c.get("wards",[]),0,-1))
 for name in c.get("counters",{}):
  if c.counters[name]!=0:lines.append(str(name)+"："+str(c.counters[name]))
 return lines

func render_prompt():
 if network_session!=null and network_session.replay_mode:return
 if network_session!=null and not network_session.room.get("undo_request",{}).is_empty() and network_session.connected and not network_session.paused:return
 if network_session!=null and not network_session.can_act(true):
  network_status_label=txt(network_session.connection_status(),Rect2(1290,630,294,110),18,host.GOLD)
  if is_android:
   network_status_label.position=SIDEBAR.position
   network_status_label.size=SIDEBAR.size
  network_status_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
  if network_session.ended() or network_session.read_only and not network_session.replay_mode:
   battle_button("返回联机房间",Rect2(1330,799,237,49),ANDROID_ACTION_CONFIRM_Y,func():host.online(),true)
  else:
   if network_session.wait_choice_pending:
    battle_button("继续等待",Rect2(1300,750,267,49),695,func():network_session.continue_waiting(),true)
   if network_session.disconnected_at>0:
    battle_button("不再等待，离开对局",Rect2(1300,810,267,49),ANDROID_ACTION_CONFIRM_Y,func():network_session.stop_waiting();host.online())
  return
 if table.combat_animating: return
 var text=""
 if not local.is_empty():
  text=local_prompt()
  if local.mode=="free_offer":
   battle_button("不支付颜色使用",Rect2(1330,690,237,49),695,func(): choose_cast_payment(false),true)
   battle_button("支付颜色使用",Rect2(1330,752,237,49),ANDROID_ACTION_CONFIRM_Y,func(): choose_cast_payment(true))
  elif local.mode=="target": render_inline_picker(confirm_declaration)
  elif local.mode=="payment":
   if payment_ready():battle_button("发动",Rect2(1330,799,237,49),ANDROID_ACTION_CONFIRM_Y,commit_local,true)
  if local.mode!="target" and not is_android:btn("取消使用",Rect2(1330,853,237,36),cancel_cast)
  if local.mode in ["target","payment"]:render_floating_resources()
 elif engine.phase=="mulligan" and not engine.players[acting_player()].mulligan_done:
  text="选择要调度的手牌"
  battle_button("保留" if selection.is_empty() else "调度 %d 张" % selection.size(),Rect2(1330,770,237,55),ANDROID_ACTION_CONFIRM_Y,func(): engine.mulligan(acting_player(),selection); selection=[]; render(),true)
 elif engine.pending.get("owner",-1)==acting_player():
  match engine.pending.kind:
   "effect_choice":
    var t=engine.pending.trigger
    if t.effect=="fairy_rewrite_resolution":text="妖精ノ巡礼：选择要改写的其他符卡"
    if t.effect=="blue_flower_resolution":text="青ノ花：选择一张符卡（包括自身）"
    if t.effect=="cat:grant" and t.data.get("free",false) and t.data.get("optional_payment",false) and not t.data.get("payment_chosen",false) and not engine.Roster.mandatory_free_cast(engine,engine.find_card(t.data.ref.uid),t.owner):
     text="是否支付颜色使用？"
     battle_button("不支付颜色使用",Rect2(1330,675,237,49),622,func(): engine.set_granted_payment(false);picker.reset();render(),true)
     battle_button("支付颜色使用",Rect2(1330,736,237,49),695,func(): engine.set_granted_payment(true);picker.reset();render())
     battle_button("不使用",Rect2(1330,803,237,43),ANDROID_ACTION_CONFIRM_Y,decline_trigger)
    else:
     render_inline_picker(confirm_trigger,t.optional)
     if t.optional: optional_trigger_prompt()
   "trigger_order": pass
   "ward_order": text="选择先损失的防避"
   "timer":
    text=engine.pending.change.get("source_name","")+" · 计时替代"
    for i in range(3):
     var delta=i-1
     var timer_button=btn(["−1","不改变","+1"][i],Rect2(1330+i*80,770,75,50),func(): engine.choose_timer(delta); render())
     responsive.add_phase_action(timer_button)
   "possession":
    text="凭依"
    var confirm=battle_button("确定凭依",Rect2(1330,735,237,52),695,confirm_possession,true)
    confirm.disabled=selected_in_zone("palette")==0 or selected_in_zone("hand")==0
    battle_button("跳过凭依",Rect2(1330,803,237,45),ANDROID_ACTION_CONFIRM_Y,func(): engine.possession(); selection=[]; render())
   "block":
    text="选择阻挡单位"
    var confirm=battle_button("不阻挡" if selection.is_empty() else "确认阻挡 %d 个" % selection.size(),Rect2(1330,770,237,55),ANDROID_ACTION_CONFIRM_Y,func(): engine.block(selection); selection=[]; render(),true)
    confirm.disabled=(selection.size()==1 and engine.Extra.keyword(engine,engine.find_card(engine.combat.attacker.uid),"威吓")) or (selection.is_empty() and engine.must_block())
   "grave_replacement":
    text="改为移回战场？"
    battle_button("移回战场",Rect2(1330,741,237,49),695,func(): engine.choose_grave_replacement(true); render(),true)
    battle_button("移回手牌",Rect2(1330,804,237,43),ANDROID_ACTION_CONFIRM_Y,func(): engine.choose_grave_replacement(false); render())
   "trigger":
    render_inline_picker(confirm_trigger,true)
    optional_trigger_prompt()
   "leader_return":
    text="将自机放回自机区？"
    battle_button("返回自机区",Rect2(1330,740,237,49),695,func(): engine.choose_return(true); render(),true)
    var destination=engine.pending.card.get("return_destination","grave")
    var label={"grave":"送入墓地","exile":"移除游戏","hand":"移回手牌","deck":"放入牌库","palette":"放入颜色盘"}.get(destination,"继续移动")
    battle_button(label,Rect2(1330,810,237,43),ANDROID_ACTION_CONFIRM_Y,func(): engine.choose_return(false); render())
   "discard":
    text="弃置 %d 张手牌" % engine.pending.count
    var b=battle_button("确认弃牌",Rect2(1330,770,237,55),ANDROID_ACTION_CONFIRM_Y,func(): engine.discard(selection); selection=[]; render(),true)
    b.disabled=selection.size()!=engine.pending.count
   "damage_assignment":
    text="分配战斗伤害"
 elif not engine.pending.is_empty():
  text="等待对手完成选择"
 elif engine.priority==acting_player() and engine.winner==-2:
  if attack_preview_uid!=0:
   var attack_button=battle_button("攻击",Rect2(1330,770,237,55),ANDROID_ACTION_CONFIRM_Y,confirm_attack,true)
   attack_button.tooltip_text="快速双击单位：单位攻击" if is_android else "快捷键：A"
  elif free_main():
   text=player_caption(acting_player())+"的行动"
   battle_button("结束主要阶段",Rect2(1330,770,237,55),ANDROID_ACTION_CONFIRM_Y,func(): engine.pass_priority(acting_player()); message=""; render(),true)
  elif should_ask_response():
   text="响应窗口"
   if not engine.stack.is_empty() and engine.stack.back().get("owner",acting_player())!=acting_player():
    var chosen_mode=stack_panel.chosen_mode(engine.stack.back())
    if not chosen_mode.is_empty():text+=" · "+chosen_mode
   var response_button=battle_button("不响应 / 继续",Rect2(1330,770,237,55),ANDROID_ACTION_CONFIRM_Y,pass_response,true)
   response_button.tooltip_text="快速双击屏幕：跳过时点" if is_android else "快捷键：Q"
 txt(text,PROMPT,21,host.GOLD).horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER

func shortcut_attack() -> bool:
 if attack_preview_uid!=0:
  if not engine.can_attack(acting_player(),attack_preview_uid):return false
  confirm_attack()
  return true
 if not action_menu_open:return false
 var uid=android_action_uid if is_android else int(modal_root.get_child(0).get_meta("action_card_uid",0)) if is_instance_valid(modal_root) and modal_root.get_child_count()>0 else 0
 if uid==0 or not engine.can_attack(acting_player(),uid):return false
 execute_action({"type":"attack","uid":uid,"enabled":true})
 return true

func _unhandled_key_input(event: InputEvent):
 if not event is InputEventKey or not event.pressed or event.echo or event.keycode not in [KEY_Q,KEY_A,KEY_G,KEY_H]:return
 if event.ctrl_pressed or event.alt_pressed or event.meta_pressed:return
 if not is_visible_in_tree() or not is_instance_valid(table):return
 var focus=get_viewport().gui_get_focus_owner()
 if focus is LineEdit or focus is TextEdit:return
 if event.keycode in [KEY_G,KEY_H]:
  if revealing() or table.combat_animating or history_open or debug_drag_uid!=0:return
  var zone="grave" if event.keycode==KEY_G else "exile"
  var who=acting_player()
  if debug_open and is_instance_valid(browser_panel) and browser_owner==who and browser_zone==zone:close_debug()
  else:browse_zone(who,zone)
  get_viewport().set_input_as_handled()
  return
 if network_locked() or network_session!=null and not network_session.can_act(true):return
 if revealing() or table.combat_animating or history_open or debug_open or observing:return
 if drag_uid!=0 or debug_drag_uid!=0 or not local.is_empty():return
 if event.keycode==KEY_A:
  if modal and not action_menu_open:return
  if shortcut_attack():get_viewport().set_input_as_handled()
  return
 if modal or attack_preview_uid!=0:return
 if not should_ask_response():return
 get_viewport().set_input_as_handled()
 pass_response()

func begin_hand_drag(uid: int,at: Vector2):
 if network_locked():return
 if debug_open or observing or modal or table.combat_animating or not local.is_empty() or response_disabled(): return
 if engine.find_card(uid).owner!=acting_player(): return
 clear_attack_preview()
 drag_uid=uid; drag_origin=at; drag_pointer=at; dragging=false
func sort_units():
 table.auto_sort_units()
 render()
func finish_unit_drag(cancelled: bool):
 var uid=unit_drag_uid
 var epoch=unit_drag_epoch
 var owner=unit_drag_owner
 var moved=unit_dragging
 var at=unit_drag_pointer
 unit_drag_uid=0;unit_dragging=false
 if is_instance_valid(unit_drag_art):unit_drag_art.queue_free()
 unit_drag_art=null
 if cancelled:return
 var c=engine.find_card(uid)
 if c.is_empty() or c.epoch!=epoch or c.zone!="field" or c.owner!=owner:return
 if moved:
  if STAGE.has_point(at) and table.reorder_unit(uid,stage_point(at)):render()
 else:object_clicked(uid)
func handle_unit_drag(event: InputEvent) -> bool:
 if unit_drag_uid==0:return false
 if event is InputEventMouseMotion:
  move_unit_drag(make_input_local(event).position)
  get_viewport().set_input_as_handled()
  return true
 if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_RIGHT and event.pressed:
  finish_unit_drag(true);get_viewport().set_input_as_handled();return true
 if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and not event.pressed:
  unit_drag_pointer=make_input_local(event).position
  finish_unit_drag(false);get_viewport().set_input_as_handled();return true
 return false
func move_unit_drag(point: Vector2):
 unit_drag_pointer=point
 if not unit_dragging and unit_drag_pointer.distance_to(unit_drag_origin)>10:
  unit_dragging=true
  var c=engine.find_card(unit_drag_uid)
  if c.is_empty():finish_unit_drag(true);return
  unit_drag_art=card_tile(ui,c,Rect2(unit_drag_pointer-Vector2(70,97),Vector2(140,195)))
  unit_drag_art.mouse_filter=Control.MOUSE_FILTER_IGNORE;unit_drag_art.modulate.a=0.82
 if unit_dragging and is_instance_valid(unit_drag_art):unit_drag_art.position=unit_drag_pointer-Vector2(70,97)
func _input(event: InputEvent):
 if is_android and event is InputEventScreenTouch and event.pressed and event.double_tap and event.index==0 and android_double_tap(make_input_local(event).position):
  camera_touches.clear();camera_touch_mode=""
  suppress_touch_mouse_until=Time.get_ticks_msec()+250
  suppress_touch_mouse_point=event.position
  get_viewport().set_input_as_handled()
  return
 if touch_android_back_swipe(event):return
 if touch_android_palette(event):return
 if touch_battle_choice_scroll(event):return
 if is_android and android_swipe_scroll.handle(event,self):
  android_back_swipe_index=-1
  android_back_swipe_active=false
  suppress_touch_mouse_until=Time.get_ticks_msec()+250
  suppress_touch_mouse_point=event.position
  return
 if touch_camera_input(event):return
 if is_android and is_instance_valid(android_back_button) and (event is InputEventScreenTouch or event is InputEventMouseButton) and android_back_button.get_global_rect().has_point(event.position):return
 if is_android and (event is InputEventMouseButton or event is InputEventMouseMotion) and Time.get_ticks_msec()<suppress_touch_mouse_until and event.position.distance_to(suppress_touch_mouse_point)<28:
  get_viewport().set_input_as_handled()
  return
 if camera_drag_input(event):return
 if handle_unit_drag(event):return
 if revealing():
  get_viewport().set_input_as_handled();return
 if is_instance_valid(table) and table.combat_animating:
  get_viewport().set_input_as_handled(); return
 if history_open:
  if event is InputEventMouseButton and event.pressed:
   var at=make_input_local(event).position
   if not history_panel.get_global_rect().has_point(at):
    if event.button_index==MOUSE_BUTTON_RIGHT: close_history()
    get_viewport().set_input_as_handled()
  return
 if debug_open and debug_drag_uid==0 and event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_RIGHT:
  if not browser_panel.get_global_rect().has_point(make_input_local(event).position):
   if not local.is_empty(): cancel_cast()
   close_debug(); get_viewport().set_input_as_handled(); return

 if debug_drag_uid!=0:
  handle_debug_drag(event)
  return
 if debug_open and event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE:
  close_debug(); get_viewport().set_input_as_handled(); return
 if event is InputEventKey and event.pressed and not event.echo and not event.ctrl_pressed and not event.alt_pressed and not event.meta_pressed and can_debug_add():
  var destination={KEY_Z:"hand",KEY_X:"palette",KEY_C:"grave"}.get(event.keycode,"")
  if not destination.is_empty():
   open_debug_card_picker(engine.active,destination)
   get_viewport().set_input_as_handled();return
 if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_RIGHT and modal:
  var at=make_input_local(event).position
  for uid in region_tiles:
   var art=region_tiles[uid]
   if is_instance_valid(art) and art.is_visible_in_tree() and art.get_global_rect().has_point(at):
    var card=engine.find_card(uid)
    if not card.is_empty(): inspect_card(card.card_id,uid)
    get_viewport().set_input_as_handled(); return
 if not modal and not debug_open and event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_RIGHT:
  if stack_panel.inspect_at(make_input_local(event).position):
   get_viewport().set_input_as_handled();return
 if attack_preview_uid!=0 and not observing and event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_RIGHT:
  clear_attack_preview(); render()
 if observing and event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
  var point=make_input_local(event).position
  var on_debug_toggle=is_instance_valid(debug_button) and debug_button.get_global_rect().has_point(point)
  if not on_debug_toggle and not observe_button.get_global_rect().has_point(point) and not STAGE.has_point(point) and not (inspection.visible and inspection.get_global_rect().has_point(point)):
   get_viewport().set_input_as_handled(); return
 if not observing and drag_uid==0 and event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_RIGHT:
  if not local.is_empty(): cancel_cast()
  elif picker_active() and not picker.path.is_empty(): picker.path=[]; picker.normalize(); render()
 if action_menu_open and is_instance_valid(modal_root) and not observing and event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_RIGHT:
  var at=make_input_local(event).position
  var panel=modal_root.get_child(0)
  var inspected=false
  for child in panel.get_children():
   if child is Panel and child.get_global_rect().has_point(at):
    var uid=panel.get_meta("action_card_uid",0)
    var c=engine.find_card(uid)
    if not c.is_empty(): inspect_card(c.card_id,uid); inspected=true
  if not inspected: close_overlay()
  get_viewport().set_input_as_handled(); return
 if drag_uid==0: return
 if event is InputEventMouseMotion:
  var at=make_input_local(event).position
  drag_pointer=at
  if at.distance_to(drag_origin)>10 and not dragging:
   dragging=true
   if engine.pending.is_empty() and engine.phase!="mulligan":
    selection=[drag_uid]
    if hand_nodes.has(drag_uid): hand_nodes[drag_uid].update_style(true,true)
   drag_art=card_tile(ui,engine.find_card(drag_uid),Rect2(at-Vector2(82,115),Vector2(164,230)))
   drag_art.mouse_filter=Control.MOUSE_FILTER_IGNORE; drag_art.modulate.a=0.9
   var drag_style=host.style(Color("#27313d"),Color("#ffd65c")); drag_style.set_border_width_all(5)
   drag_art.add_theme_stylebox_override("panel",drag_style)
  if dragging: drag_art.position=at-Vector2(82,115)
 elif event is InputEventMouseButton:
  drag_pointer=make_input_local(event).position
  if event.button_index==MOUSE_BUTTON_RIGHT and event.pressed:
   finish_drag(true); get_viewport().set_input_as_handled()
  elif event.button_index==MOUSE_BUTTON_LEFT and not event.pressed:
   finish_drag(false); get_viewport().set_input_as_handled()
func finish_drag(cancelled: bool):
 var uid=drag_uid; var moved=dragging; var at=drag_pointer
 drag_uid=0; dragging=false
 if is_instance_valid(drag_art): drag_art.queue_free()
 if cancelled:
  selection=[]; render(); return
 if moved:
  if not over_hand_card(at,engine.find_card(uid).owner): request_cast(uid)
  else: selection=[]; render()
 else: hand_clicked(uid)
func hand_clicked(uid: int):
 if replay_view():
  var c=engine.find_card(uid)
  if not c.is_empty():inspect_card(c.card_id,c.uid,"",c.get("art_id",""))
  return
 if network_locked():return
 if history_open or observing or response_disabled(): return
 message=""
 if picker_active():
  var c=engine.find_card(uid)
  if not c.is_empty(): choose_target(engine.ref_target(c))
  return
 if engine.phase=="mulligan" or engine.pending.get("kind","")=="discard": toggle_selection(uid); return
 if engine.pending.get("kind","")=="possession" and engine.pending.owner==acting_player():
  if selected_in_zone("palette")!=0 and engine.can_possess(engine.find_card(uid)): select_possession(uid,"hand")
  return
 var card=engine.find_card(uid)
 if card.is_empty(): return
 if engine.cast_error(acting_player(),uid).is_empty():
  close_debug(); request_cast(uid)
 elif card.zone!="hand" and engine.extension_activation_error(acting_player(),card).is_empty():
  close_debug(); execute_action(engine.extra_action(card))
func selected_in_zone(zone: String) -> int:
 for uid in selection:
  var c=engine.find_card(uid)
  if not c.is_empty() and c.zone==zone and c.owner==acting_player(): return uid
 return 0
func select_possession(uid: int,zone: String):
 var old=selected_in_zone(zone)
 if old==uid:
  if is_android:return
  selection.erase(uid)
  if zone=="palette":selection=[]
  render()
  return
 if old!=0: selection.erase(old)
 selection.append(uid)
 render()
func confirm_possession():
 var p=selected_in_zone("palette"); var h=selected_in_zone("hand")
 if p==0 or h==0: return
 engine.possession(p,h); selection=[]; render()
func right_cancel():
 if observing:
  if is_instance_valid(table.inspect_root): table.inspect_root.queue_free()
  return
 if not network_locked() and engine.pending.get("owner",-1)==acting_player() and engine.pending.get("kind","")=="effect_choice" and engine.pending.trigger.effect=="cat:spell_copy" and engine.pending.trigger.get("data",{}).has("copy_menu_entry"):
  engine.choose_effect({"none":true,"mode":"返回","copy_back":true});picker.reset();selection=[];render();return
 if attack_preview_uid!=0: clear_attack_preview(); render()
 elif not local.is_empty(): cancel_cast()
 elif picker_active(): picker.path=[]; picker.normalize(); render()
 elif engine.pending.get("kind","")=="possession": selection=[]; render()
 elif is_instance_valid(table.inspect_root): table.inspect_root.queue_free()
func android_back():
 if history_open:close_history();return
 if debug_open:close_debug();return
 if observing:toggle_observation();return
 if is_instance_valid(android_choice_panel):
  if android_action_uid>0:android_action_uid=0;action_menu_open=false;render()
  else:android_choice_hidden_key=android_choice_panel.get_meta("choice_key","");render()
  return
 if not local.is_empty() or attack_preview_uid!=0 or picker_active() and not picker.path.is_empty():
  right_cancel();return
 if is_instance_valid(modal_root):close_overlay();return
 if android_palette_owner!=-1:android_palette_owner=-1;android_palette_auto_open=false;render();return
 if not selection.is_empty():selection=[];render();return
 if is_instance_valid(table.inspect_root):table.inspect_root.queue_free();return
 settings_menu()
func open_android_help():
 if not is_android or modal or history_open or revealing() or table.combat_animating:return
 var panel=overlay("安卓操作说明")
 var m=host.ui_metrics
 panel.size=Vector2(minf(1100,m.safe.size.x-24),minf(760,m.safe.size.y-24));center_panel(panel)
 var guide=RichTextLabel.new()
 guide.position=Vector2(28,m.title*1.5+28);guide.size=Vector2(panel.size.x-56,panel.size.y-m.title*1.5-m.hit-72)
 guide.bbcode_enabled=true;guide.scroll_active=true
 guide.add_theme_font_size_override("normal_font_size",m.body)
 guide.add_theme_color_override("default_color",host.WHITE)
 guide.text="[b]卡牌与颜色盘[/b]\n点按卡牌进行选择或查看操作；能力和多选卡牌会在上方弹出。点按「隐藏」可收起，再点「展开」继续选择。颜色盘可同时打开。点按战场左上的「我方颜色盘」「敌方颜色盘」展开颜色盘。\n\n[b]滚动列表[/b]\n在堆叠、卡库、记录等区域上下滑动浏览；横向卡列左右滑动。\n\n[b]快捷操作[/b]\n快速双击战场空白处：跳过可响应时点。快速双击可攻击的己方单位：发起攻击。\n\n[b]战场视角[/b]\n长按并拖动战场：平移视角。双指张开或捏合：缩放视角。点按「视角复原」恢复初始视角。\n\n[b]回退[/b]\n点按右下角「后退」，或从屏幕右侧边缘向左滑动：关闭当前选择、面板或弹窗。"
 panel.add_child(guide)
 var back=btn("返回对局",Rect2(28,panel.size.y-m.hit-20,panel.size.x-56,m.hit),close_overlay,false,panel)
 m.button(back)
func android_double_tap(point: Vector2) -> bool:
 if not is_android or not TOUCH_CAMERA_AREA.has_point(point):return false
 if inspection.visible and inspection.get_global_rect().has_point(point):return false
 if is_instance_valid(android_choice_panel) and android_choice_panel.get_global_rect().has_point(point):return false
 if android_palette_toggle_at(point)>=0 or is_instance_valid(android_palette_panel) and android_palette_panel.is_visible_in_tree() and android_palette_panel.get_global_rect().has_point(point):return false
 if network_locked() or network_session!=null and not network_session.can_act(true):return false
 if revealing() or table.combat_animating or history_open or debug_open or observing or drag_uid!=0 or debug_drag_uid!=0 or not local.is_empty():return false
 if modal and not action_menu_open:return false
 var uid=table.card_at(stage_point(point))
 if uid!=0:
  var c=engine.find_card(uid)
  if not c.is_empty() and c.zone=="field" and engine.is_unit(c) and c.owner==acting_player() and engine.can_attack(acting_player(),uid):
   close_overlay();clear_attack_preview();begin_attack_payment(uid)
   return true
  return false
 if not TOUCH_CAMERA_AREA.has_point(point) or modal or attack_preview_uid!=0 or not should_ask_response():return false
 pass_response()
 return true
func object_clicked(uid: int):
 inspect_declaring_unit(engine.find_card(uid))
 if network_locked():
  var object=engine.find_card(uid)
  if not object.is_empty():inspect_card(object.card_id,uid)
  return
 if history_open or observing or table.combat_animating: return
 message=""
 if not local.is_empty():
  if local.mode in ["target","payment"] and payment_sources().any(func(r):return r.uid==uid): reserve_resource(uid)
  elif local.mode=="target":
   var target=engine.find_card(uid)
   if not target.is_empty(): choose_target(engine.ref_target(target))
  return
 var c=engine.find_card(uid)
 if engine.pending.get("owner",-1)==acting_player():
  match engine.pending.kind:
   "trigger", "effect_choice":
    if not c.is_empty(): choose_target(engine.ref_target(c))
   "block":
    if c in engine.legal_blockers(): toggle_selection(uid)
   "possession":
    if not c.is_empty() and c.owner==acting_player() and c.zone=="palette" and not c.tapped and engine.can_possess(c): select_possession(uid,"palette")
  return
 if c.is_empty(): return
 if c.owner==acting_player() and c.zone=="leader": leader_zone_clicked(c.owner)
 elif c.owner==acting_player() and c.zone=="field": open_actions(c)
func leader_zone_clicked(who: int):
 if network_locked() or history_open or observing or table.combat_animating or modal or not local.is_empty():return
 if who!=acting_player() or not engine.pending.is_empty():return
 var leaders=engine.leaders(who).filter(func(c):return c.zone=="leader")
 if leaders.is_empty():return
 if leaders.size()==1:
  request_cast(leaders[0].uid)
  return
 var panel=overlay("选择要使用的自机")
 panel.size=Vector2(728,470);center_panel(panel)
 var content=choice_card_content(panel,leaders.size(),Vector2(688,310))
 for i in range(leaders.size()):
  var leader=leaders[i]
  var error=engine.cast_error(who,leader.uid)
  var at=choice_card_position(i,leaders.size())
  var choose_leader=func():
   close_overlay()
   request_cast(leader.uid)
  var tile=card_tile(content,leader,Rect2(at,Vector2(173,241)),choose_leader if error.is_empty() else Callable())
  tile.gui_input.connect(func(event):
   if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_RIGHT:inspect_card(leader.card_id,leader.uid))
  tile.set_meta("leader_choice_uid",leader.uid)
  if not error.is_empty():tile.modulate=Color(0.55,0.55,0.55);tile.tooltip_text=error
  var label=txt(engine.cards[leader.card_id].name,Rect2(at+Vector2(-15,247),Vector2(195,38)),16,host.GOLD,content)
  label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
  if not error.is_empty():
   var reason=txt(error,Rect2(at+Vector2(-15,283),Vector2(195,44)),14,host.MUTED,content)
   reason.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;reason.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
 btn("取消",Rect2(480,420,220,42),close_overlay,false,panel)
func open_actions(c: Dictionary):
 inspect_declaring_unit(c)
 if network_locked():return
 if response_disabled(): return
 var actions=engine.available_actions(acting_player(),c.uid,true).filter(func(action):return action.enabled or action.type in ["ability","extension","ran_discount"])
 if actions.size()==1 and actions[0].type=="attack":
  clear_attack_preview(); attack_preview_uid=c.uid; selection=[c.uid]; render(); return
 clear_attack_preview()
 if actions.is_empty(): inspect_card(c.card_id,c.uid); return
 if is_android:
  android_action_uid=c.uid
  action_menu_open=true
  android_choice_hidden_key=""
  render_android_actions(c,actions)
  android_choice_on_top()
  return
 var panel=overlay("选择行动")
 action_menu_open=true
 panel.size=Vector2(728,470); center_panel(panel)
 panel.set_meta("action_card_uid",c.uid)
 var content=choice_card_content(panel,actions.size(),Vector2(688,375))
 for i in range(actions.size()):
  var action=actions[i]
  var at=choice_card_position(i,actions.size())
  var tile=card_tile(content,c,Rect2(at,Vector2(173,241)),func(): execute_action(action))
  tile.set_meta("action_type",action.type)
  if action.type=="attack":tile.tooltip_text="快速双击单位：单位攻击" if is_android else "快捷键：A"
  if not action.enabled:
   tile.modulate=Color(0.55,0.55,0.55)
   tile.tooltip_text=action.get("reason","当前不能发动")
  var label=txt(action.label,Rect2(at+Vector2(-4,251),Vector2(185,74)),18,host.GOLD if action.enabled else host.MUTED,content)
  label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
  label.size=Vector2(185,74)
  if not action.enabled:label.tooltip_text=action.get("reason","当前不能发动")
func render_android_actions(c: Dictionary,actions: Array):
 if actions.is_empty():return
 battle_choice_scroll=null
 if is_instance_valid(android_choice_panel):android_choice_panel.queue_free();android_choice_panel=null
 if is_instance_valid(android_choice_restore):android_choice_restore.queue_free();android_choice_restore=null
 var key="actions:"+str(c.uid)
 var panel=android_choice_box(engine.cards[c.card_id].name+" · 选择行动",key)
 if panel==null:return
 panel.set_meta("choice_key",key)
 panel.set_meta("action_card_uid",c.uid)
 var scroll=ScrollContainer.new();scroll.name="AndroidActionScroll"
 scroll.position=Vector2(18,host.ui_metrics.hit+18)
 scroll.size=Vector2(panel.size.x-36,panel.size.y-scroll.position.y-12)
 scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;panel.add_child(scroll)
 var grid=GridContainer.new();grid.columns=maxi(1,floori((panel.size.x-28)/218.0));grid.add_theme_constant_override("h_separation",8);grid.add_theme_constant_override("v_separation",8);scroll.add_child(grid)
 for action in actions:
  var cell=Control.new();cell.custom_minimum_size=Vector2(210,245);grid.add_child(cell)
  var tile=card_tile(cell,c,Rect2(39,0,132,184),func():execute_action(action))
  tile.set_meta("action_type",action.type)
  if not action.enabled:tile.modulate=Color(0.55,0.55,0.55);tile.tooltip_text=action.get("reason","当前不能发动")
  var label=txt(action.label,Rect2(8,188,194,55),17,host.GOLD if action.enabled else host.MUTED,cell)
  label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
  if not action.enabled:label.tooltip_text=action.get("reason","当前不能发动")
func choice_card_content(panel: Control,count: int,dimensions: Vector2) -> Control:
 var scroll=ScrollContainer.new(); scroll.position=Vector2(20,75); scroll.size=dimensions
 scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED; panel.add_child(scroll)
 var content=Control.new(); content.custom_minimum_size=Vector2(dimensions.x-16,ceili(count/3.0)*335)
 scroll.add_child(content); return content
func choice_card_position(index: int,count: int,card_width: float=173.0) -> Vector2:
 var row=index/3
 var row_count=mini(3,count-row*3)
 var row_width=(row_count-1)*222+card_width
 return Vector2((688-row_width)*0.5+(index%3)*222,row*335)
func trigger_order_menu():
 var panel=overlay("选择入堆叠顺序")
 panel.size=Vector2(728,495); center_panel(panel)
 panel.set_meta("trigger_order",true)
 var options=engine.pending.options
 var content=choice_card_content(panel,options.size(),Vector2(688,395))
 for i in range(options.size()):
  var t=options[i]; var at=choice_card_position(i,options.size())
  var tile=card_tile(content,t.source,Rect2(at,Vector2(173,241)),func():
   if observing or engine.pending.get("kind","")!="trigger_order": return
   engine.choose_trigger_order(i); picker.reset(); render())
  tile.set_meta("trigger_index",i)
  var caption=AbilityCaption.text(t)
  var detail_height=104 if caption.begins_with("来源：") else 78
  var label=txt(caption,Rect2(at+Vector2(-4,251),Vector2(194,detail_height)),15 if detail_height>78 else 17,host.WHITE,content)
  label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
  label.size=Vector2(194,detail_height)
func ward_order_menu():
 if engine.pending.get("kind","")!="ward_order":return
 var target=engine.find_card(engine.pending.target.uid)
 if target.is_empty():return
 var panel=overlay("选择先损失的防避")
 panel.size=Vector2(650,465);center_panel(panel)
 var art=card_tile(panel,target,Rect2(28,80,180,251),func():inspect_card(target.card_id,target.uid))
 art.tooltip_text="右键查看单位"
 var name=txt(engine.cards[target.card_id].name,Rect2(25,342,190,74),17,host.WHITE,panel)
 name.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;name.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
 txt("将受到 %d 点伤害。请选择优先消耗的防避。" % engine.pending.incoming,Rect2(233,81,390,56),18,host.WHITE,panel).autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 var scroll=ScrollContainer.new();scroll.position=Vector2(232,146);scroll.size=Vector2(391,269)
 panel.add_child(scroll)
 var rows=VBoxContainer.new();rows.size_flags_horizontal=Control.SIZE_EXPAND_FILL;scroll.add_child(rows)
 for index in engine.pending.options:
  var ward=target.wards[index]
  var expiry="持续" if int(ward.get("turn",engine.turn))==-1 else "本回合"
  if ward.get("next",false):expiry+=" · 下一次伤害"
  var button=Button.new();button.text="防避 %d  ·  %s" % [int(ward.get("amount",0)),expiry]
  button.custom_minimum_size=Vector2(365,48);rows.add_child(button)
  button.pressed.connect(func():
   if observing or engine.pending.get("kind","")!="ward_order":return
   engine.choose_ward(index);render())
 refresh_observation()
func optional_trigger_prompt():
 var inline_rows=picker.available().any(func(atom):
  if atom.kind!="target": return true
  if not atom.value.has("uid"): return false
  var c=engine.find_card(atom.value.uid)
  return not c.is_empty() and c.zone not in ["field","palette","leader","stack","hand"])
 var title="是否发动%s的触发效果" % engine.cards[engine.pending.trigger.source.card_id].name
 if is_android and not picker.prompt().is_empty():title+="\n"+picker.prompt()
 elif is_android and picker.available().any(func(atom):return atom.get("role","")=="sacrifice"):title+="\n选择牺牲的单位"
 var label=txt(title,Rect2(1330,586 if inline_rows else 702,237,78),17,host.GOLD)
 label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 if is_android:
  label.position=Vector2(ANDROID_ACTION_X,responsive.log_rect.end.y+8)
  label.size=Vector2(ANDROID_ACTION_WIDTH,host.ui_metrics.body*4)
 else:label.size=Vector2(right_rect(Rect2(1330,0,237,78)).size.x,96)
 label.set_meta("optional_trigger_prompt",true)
func execute_action(action: Dictionary):
 if response_disabled() or not action.enabled: return
 if action.type=="ran_discount":
  close_overlay();clear_attack_preview()
  message=engine.toggle_ran_discount(acting_player(),action.uid)
  render();return
 if action.type in ["ability","extension"]:
  var c=engine.find_card(action.uid)
  var can_batch=not c.is_empty() and (action.type=="ability" and engine.cards[c.card_id].get("stackable",false) or action.type=="extension" and engine.can_batch_stackable_sacrifice(c,action.key))
  if can_batch:
   var count=engine.stackable_members(c).size()
   if count>1:
    var panel=overlay("选择牺牲数量" if action.type=="extension" else "选择一次启动的数量")
    txt("%s：可牺牲 1 至 %d 个" % [engine.cards[c.card_id].name,count] if action.type=="extension" else "%s：可启动 1 至 %d 个" % [engine.cards[c.card_id].name,count],Rect2(38,83,570,42),21,host.WHITE,panel)
    var spinner=SpinBox.new();spinner.position=Vector2(196,137);spinner.size=Vector2(260,48)
    spinner.min_value=1;spinner.max_value=count;spinner.step=1;spinner.rounded=true;spinner.value=1
    panel.add_child(spinner)
    btn("确认",Rect2(120,225,180,48),func():begin_action(action,int(spinner.value)),true,panel)
    btn("取消",Rect2(350,225,180,48),close_overlay,false,panel)
    return
 begin_action(action)
func begin_action(action: Dictionary,count: int=1):
 close_overlay()
 clear_attack_preview()
 if action.type=="extension":
  var source=engine.find_card(action.uid)
  var error="牌已离开" if source.is_empty() else engine.extension_activation_error(acting_player(),source,action.key)
  if not error.is_empty():message=error;render();return
 if action.type=="attack": begin_attack_payment(action.uid)
 elif action.type=="direct_attack":
  local={"uid":action.uid,"action":"direct_attack","mode":"target","target":{},"plan":[]}
  picker.reset(); render()
 elif action.type=="extension":
  local={"uid":action.uid,"action":"extension","key":action.key,"mode":"target","target":{},"plan":[],"stackable_count":count}
  picker.reset(); render()
 else:
  local={"uid":action.uid,"action":"ability","index":action.index,"mode":"target","target":{},"plan":[],"stackable_count":count}
  picker.reset(); render()
func toggle_selection(uid: int):
 if uid in selection: selection.erase(uid)
 else: selection.append(uid)
 render()

func clear_attack_preview():
 if attack_preview_uid!=0: selection.erase(attack_preview_uid)
 attack_preview_uid=0
func confirm_attack():
 var uid=attack_preview_uid
 if uid==0 or observing: return
 clear_attack_preview()
 if engine.can_attack(acting_player(),uid): begin_attack_payment(uid)
 message=""
 render()

func local_prompt() -> String:
 if local.mode=="free_offer":return "是否支付颜色使用？"
 if not payment_ready():return "选择支付费用"
 var c=engine.find_card(local.uid)
 if local.mode=="target" and not picker.ready():return engine.cards[c.card_id].name
 return "是否发动%s？" % (engine.cards[c.card_id].name if not c.is_empty() else engine.pending.get("trigger",{}).get("name","该效果"))

func local_cost() -> Dictionary:
 if local.get("action","")=="choice_payment": return local.choice_cost
 if local.get("action","") in ["attack","direct_attack"]: return engine.attack_cost(acting_player())
 if local.get("action","")=="extension": return engine.extension_cost(acting_player(),engine.find_card(local.uid),local.key,activation_target())
 if local.get("action","")=="ability": return engine.ability_cost(acting_player(),local.uid,local.index,activation_target())
 return engine.cast_cost(acting_player(),engine.find_card(local.uid),local.get("target",{}))
func local_cost_options() -> Array:
 if not local.get("action","").is_empty():return [local_cost()]
 return engine.cast_cost_options(acting_player(),engine.find_card(local.uid),local.get("target",{}))
func activation_target() -> Dictionary:
 var target=local.get("target",{}).duplicate(true)
 if local.get("action","") in ["ability","extension"] and local.get("stackable_count",1)>1:target.stackable_count=local.stackable_count
 return target
func local_targets() -> Array:
 if local.get("action","")=="direct_attack": return engine.Pack.all_units(engine,1-acting_player()).filter(func(r):return engine.Pack.direct_attack(engine,engine.find_card(local.uid)) or engine.find_card(r.uid).has("rank_target"))
 if local.get("action","")=="extension": return engine.activation_options(engine.find_card(local.uid),local.key)
 if local.get("action","")=="ability": return engine.ability_targets()
 return engine.targets_for(engine.find_card(local.uid).card_id,acting_player(),local.uid)
func payment_excluded() -> Array:
 if local.get("action","")!="ability" or not engine.ability_parameters(local.uid,local.index).get("横置",false):return []
 var c=engine.find_card(local.uid)
 var members=engine.stackable_members(c) if local.get("stackable_count",1)>1 else [c]
 members.erase(c);members.push_front(c)
 return members.slice(0,local.get("stackable_count",1)).map(func(member):return member.uid)
func refresh_payment_plan():
 if local.is_empty() or local.mode not in ["target","payment"]:return
 if local.mode=="target":local.target=picker.option() if picker.ready() else {}
 var costs=local_cost_options();var excluded=payment_excluded()
 var signature=JSON.stringify([costs,excluded,engine.source_resources(acting_player())])
 if local.get("payment_signature","")!=signature:
  local.payment_signature=signature
  local.plan=PaymentDraft.solve_costs(engine,acting_player(),costs,[],excluded).plan
 var key=signature+JSON.stringify(local.plan)
 if local.get("options_signature","")!=key:
  local.options_signature=key
  local.payment_options=PaymentDraft.options_for_costs(engine,acting_player(),costs,local.plan,excluded)
func payment_ready() -> bool:
 return not local.is_empty() and local_cost_options().any(func(cost):return engine.payment_valid(acting_player(),cost,local.get("plan",[])))
func payment_sources() -> Array:
 return local.get("payment_options",[]) if not local.is_empty() else []
func close_overlay(preserve_android_action: bool=false):
 modal=false; action_menu_open=preserve_android_action and android_action_uid>0; observing=false
 if not preserve_android_action:android_action_uid=0;android_choice_hidden_key=""
 if is_instance_valid(android_choice_panel):android_choice_panel.queue_free()
 if is_instance_valid(android_choice_restore):android_choice_restore.queue_free()
 android_choice_panel=null;android_choice_restore=null
 for child in hud.get_children():
  if child.has_meta("choice_widget"): child.visible=true
 if is_instance_valid(modal_root):
  modal_root.get_parent().remove_child(modal_root); modal_root.queue_free()
 modal_root=null
 if is_instance_valid(stack_panel):stack_panel.visible=not engine.stack.is_empty()
 refresh_observation()

func request_cast(uid: int):
 if network_locked():return
 if observing or table.combat_animating or response_disabled(): return
 clear_attack_preview()
 var error=engine.cast_error(acting_player(),uid)
 if not error.is_empty(): message=error; render(); return
 engine.paid_cast_uid=-1
 local={"uid":uid,"target":{},"plan":[],"mode":"free_offer" if engine.offers_free_cast(acting_player(),engine.find_card(uid)) else "target"}
 if not damage_caption(engine.find_card(uid)).is_empty():inspect_card(engine.find_card(uid).card_id,uid)
 picker.reset(); region_selected={}; selection=[]; message=""; render()

func choose_cast_payment(pay_colors: bool):
 if local.get("mode","")!="free_offer":return
 if pay_colors and engine.Roster.mandatory_free_cast(engine,engine.find_card(local.uid),acting_player()):return
 engine.paid_cast_uid=local.uid if pay_colors else -1
 local.mode="target";local.target={};local.plan=[]
 picker.reset();render()
func choose_target(target: Dictionary):
 if network_locked():return
 if observing or table.combat_animating or not picker_active(): return
 sync_picker()
 if picker.select_target(target):
  if not local.is_empty(): local.target=picker.option()
  message=""; render()

func start_payment():
 if local.is_empty():return
 local.mode="payment";refresh_payment_plan();render()

func reserve_resource(uid: int):
 if network_locked():return
 if observing or local.is_empty() or local.mode not in ["target","payment"]:return
 for reservation in local.plan:
  if reservation.uid==uid:
   local.plan.erase(reservation);message="";render();return
 for source in payment_sources():
  if source.uid==uid and source.has("reservation"):
   local.plan.append(source.reservation.duplicate(true));message="";render();return

func commit_local():
 if network_locked():return
 if local.is_empty() or local.mode!="payment" or response_disabled() or not payment_ready(): return
 if local.get("action","")=="choice_payment":
  var paid_target=local.target.duplicate(true);paid_target.payment=local.plan.duplicate(true)
  if not engine.payment_valid(acting_player(),local.choice_cost,local.plan):message="支付方案已失效";render();return
  local={};engine.choose_effect(paid_target);engine.paid_cast_uid=-1;picker.reset();selection=[];render();return
 if local.get("action","") in ["attack","direct_attack"]:
  engine.attack(acting_player(),local.uid,local.target,local.plan); local={}; selection=[]; picker.reset(); render(); return
 var error=engine.commit_extension(acting_player(),local.uid,activation_target(),local.plan,local.get("key","")) if local.get("action","")=="extension" else engine.commit_ability(acting_player(),local.uid,local.index,activation_target(),local.plan) if local.get("action","")=="ability" else engine.commit_cast(acting_player(),local.uid,local.target,local.plan)
 if error.is_empty(): engine.paid_cast_uid=-1;local={}; selection=[]; picker.reset(); message=""; close_debug()
 else: message=error
 modal=false; render()
func cancel_cast():
 if local.get("action","")=="choice_payment" and engine.pending.get("kind","")=="effect_choice" and engine.pending.trigger.effect=="cat:grant":engine.pending.trigger.data.erase("payment_chosen")
 engine.paid_cast_uid=-1
 local={}; selection=[]; region_selected={}; picker.reset(); modal=false; message=""; render()
func overlay(title: String,card_search: bool=false) -> Panel:
 close_overlay()
 modal=true
 if is_instance_valid(stack_panel):stack_panel.hide()
 var shade=ColorRect.new(); shade.color=Color(0,0,0,0.65); shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); ui.add_child(shade)
 if card_search:
  shade.set_meta("card_search_topmost",true)
  shade.z_index=100
 modal_root=shade
 var panel=host.box(shade,Rect2(475,285,650,330),Color("#101c28"),host.GOLD)
 var heading=txt(title,Rect2(30,18,590,42),27,host.GOLD,panel)
 heading.name="DialogTitle"; heading.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
 refresh_observation()
 return panel

func raise_card_search_overlay():
 if is_instance_valid(observe_button):observe_button.z_index=0
 if is_instance_valid(modal_root) and modal_root.get_meta("card_search_topmost",false) and modal_root.get_parent()==ui:
  ui.move_child(modal_root,-1)
  if is_instance_valid(observe_button):
   observe_button.z_index=101
   ui.move_child(observe_button,-1)
func network_error(error: String):
 message=error
 if is_instance_valid(table):render()
func network_locked() -> bool:
 return network_session!=null and (network_session.read_only or not network_session.connected or network_session.paused or network_session.ended() or not network_session.room.get("undo_request",{}).is_empty())
func network_changed():
 var locked=network_locked()
 var ended=network_session.ended()
 var disconnected=not network_session.connected
 var wait_choice=not network_session.replay_mode and network_session.wait_choice_pending
 if locked==was_network_locked and ended==was_network_ended and disconnected==was_network_disconnected and wait_choice==was_network_wait_choice:return
 was_network_locked=locked;was_network_ended=ended;was_network_disconnected=disconnected;was_network_wait_choice=wait_choice
 if locked:
  local={};selection=[];picker.reset();attack_preview_uid=0;engine.paid_cast_uid=-1
  close_overlay()
 render()
func settings_menu():
 var panel=overlay("对战设置")
 var m=host.ui_metrics
 panel.size=Vector2(minf(840,m.safe.size.x-32),minf(m.safe.size.y-32,m.hit*(6 if debug_mode or replay_view() else 5)+m.gap*6+52))
 center_panel(panel)
 panel.get_node("DialogTitle").size=Vector2(panel.size.x-60,m.title*1.4)
 var margin=MarginContainer.new();panel.add_child(margin)
 margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 margin.offset_left=24;margin.offset_right=-24;margin.offset_top=m.title*1.5+24;margin.offset_bottom=-24
 var column=VBoxContainer.new();margin.add_child(column)
 var toolkit=preload("res://scripts/menu_ui_layout.gd").new();toolkit.app=host;toolkit.metrics=m
 var views=HBoxContainer.new();column.add_child(views)
 for entry in [["3D 斜视",false],["2D 上方俯视",true]]:
  var choice=btn(entry[0],Rect2(),func():set_card_view(entry[1]),table.top_down_view==entry[1],views)
  m.button(choice);choice.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 toolkit.check(column,"显示左侧卡牌效果说明栏",host.show_card_inspection,func(value):host.set_show_card_inspection(value);update_inspection())
 if debug_mode:toolkit.check(column,"允许调试拖动放入战场",host.debug_drag_to_field,host.set_debug_drag_to_field)
 if replay_view():toolkit.check(column,"回放训练模式：标注步骤与推荐招法",host.replay_training_mode,host.set_replay_training_mode)
 var resume=btn("继续游戏",Rect2(),func():modal=false;render(),true,column);m.button(resume)
 if network_session!=null and not network_session.replay_mode:
  var lobby=btn("返回联机房间",Rect2(),func():host.online(),false,column);m.button(lobby)
 if network_session!=null and network_session.read_only:return
 var surrender=btn("本局投降",Rect2(),func():
  host.confirm_action("确认本局投降？",func():modal=false;local={};engine.surrender(local_seat);render()),false,column)
 m.button(surrender)

func set_card_view(top_down: bool):
 if table.top_down_view==top_down:return
 host.set_top_down_view(top_down)
 table.set_top_down_view(top_down)
 settings_menu()
func result_overlay():
 var panel=overlay("本局平局" if engine.winner==-1 else "本局胜利" if engine.winner==local_seat else "本局结束")
 txt(engine.log.back(),Rect2(30,90,590,80),22,host.WHITE,panel)
 var next_label="返回对局准备"
 if network_session!=null:
  var room=network_session.room
  next_label="下一局" if room.get("status","")=="between" else "返回联机房间"
  txt("BO%d · %d : %d" % [room.format,room.scores[0],room.scores[1]],Rect2(30,160,590,40),22,host.GOLD,panel)
 btn(next_label,Rect2(160,220,330,56),func(): host.online() if network_session!=null else host.setup(),true,panel)
func damage_dialog():
 if engine.pending.get("kind","")!="damage_assignment":return
 var targets=engine.combat.blockers
 var signature=str(engine.combat.attacker)+str(targets)+str(engine.pending.total)
 if signature!=damage_signature:
  damage_signature=signature;damage_values={}
  for target in targets.slice(0,-1):damage_values[str(target.uid)]=0
 var m=host.ui_metrics
 var panel=overlay("分配 %d 点战斗伤害" % engine.pending.total)
 panel.size=Vector2(minf(1040,m.safe.size.x-24),minf(760,m.safe.size.y-24));center_panel(panel)
 panel.get_node("DialogTitle").size=Vector2(panel.size.x-60,m.title*1.5)
 var margin=MarginContainer.new();panel.add_child(margin);margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 margin.offset_left=20;margin.offset_right=-20;margin.offset_top=m.title*1.5+28;margin.offset_bottom=-20
 var body=VBoxContainer.new();margin.add_child(body)
 var scroll=ScrollContainer.new();body.add_child(scroll);scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
 scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
 var grid=GridContainer.new();scroll.add_child(grid);grid.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 var card_width=maxf(190,m.hit*2+m.body*2+m.gap*2)
 grid.columns=maxi(1,int((panel.size.x-50)/(card_width+m.gap)))
 damage_controls={}
 for target in targets.slice(0,-1):
  var c=engine.find_card(target.uid);var key=str(c.uid)
  var column=VBoxContainer.new();column.custom_minimum_size.x=card_width;grid.add_child(column)
  var art=TextureRect.new();art.custom_minimum_size=Vector2(card_width,220)
  art.texture=card_texture(c);art.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;art.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
  art.set_meta("damage_card",c.uid);column.add_child(art)
  art.gui_input.connect(func(event):
   if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_RIGHT:inspect_card(c.card_id,c.uid))
  var row=HBoxContainer.new();column.add_child(row)
  var minus=btn("−",Rect2(),func():change_damage(key,-1),false,row);m.button(minus)
  var value=Label.new();value.text="0";value.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;value.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row.add_child(value)
  value.add_theme_font_size_override("font_size",m.title)
  var plus=btn("+",Rect2(),func():change_damage(key,1),false,row);m.button(plus)
  damage_controls[key]={"value":value,"minus":minus,"plus":plus}
 damage_remainder=Label.new();body.add_child(damage_remainder);damage_remainder.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 damage_remainder.add_theme_font_size_override("font_size",m.body)
 var confirm=btn("确定分配",Rect2(),confirm_damage,true,body);m.button(confirm)
 update_damage_controls();refresh_observation()

func change_damage(key: String,delta: int):
 var remaining=damage_remaining()
 if delta>0 and remaining<=0: return
 damage_values[key]=maxi(0,int(damage_values[key])+delta)
 update_damage_controls()
func damage_remaining() -> int:
 var used=0
 for value in damage_values.values(): used+=int(value)
 return maxi(0,int(engine.pending.get("total",0))-used)
func update_damage_controls():
 var remaining=damage_remaining()
 for key in damage_controls:
  var controls=damage_controls[key]
  controls.value.text=str(damage_values[key]); controls.minus.disabled=damage_values[key]==0; controls.plus.disabled=remaining==0
 var last=engine.find_card(engine.combat.blockers.back().uid)
 damage_remainder.text=engine.cards[last.card_id].name+"：剩余 %d 点" % remaining
func confirm_damage():
 if observing or engine.pending.get("kind","")!="damage_assignment": return
 var allocation=damage_values.duplicate()
 allocation[str(engine.combat.blockers.back().uid)]=damage_remaining()
 engine.combat_damage(allocation); damage_values={}; damage_signature=""; modal=false; render()

func selected_uids() -> Array:
 var selected=selection.duplicate()
 for target in picker.selected_refs():
  if target.has("uid") and target.uid not in selected: selected.append(target.uid)
 if not local.is_empty():
  if local.uid not in selected: selected.append(local.uid)
  var target=local.get("target",{})
  if target.has("uid") and target.uid not in selected: selected.append(target.uid)
 return selected
func stat_color(value: int,base: int) -> Color:
 return Color("#69e59a") if value>base else Color("#ff737b") if value<base else host.WHITE
func combat_marker(uid: int) -> String:
 if attack_preview_uid==uid: return "sword"
 if engine.combat.is_empty(): return ""
 if engine.combat.attacker.uid==uid: return "sword"
 if engine.combat.blockers.any(func(t): return t.uid==uid): return "shield"
 if engine.pending.get("kind","")=="block" and uid in selection: return "shield"
 return ""
func show_combat_impact(attacker_uid: int,blocker_uid: int):
 var attacker=table.visuals.get("card_"+str(attacker_uid))
 if not is_instance_valid(attacker): return
 var at=attacker.global_position
 var blocker=table.visuals.get("card_"+str(blocker_uid))
 if is_instance_valid(blocker): at=(at+blocker.global_position)*0.5
 var point=project(at)
 var flash=txt("✦",Rect2(point-Vector2(45,50),Vector2(90,100)),72,Color("#fff0bc"),effects)
 flash.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
 var tween=create_tween(); tween.tween_property(flash,"modulate:a",0.0,0.28); tween.tween_callback(flash.queue_free)
func choice_active() -> bool:
 return engine!=null and engine.winner==-2 and not table.combat_animating and (attack_preview_uid!=0 or debug_open or modal or not local.is_empty() or engine.pending.get("owner",-1)==acting_player() or (engine.phase=="mulligan" and not engine.players[acting_player()].mulligan_done))
func refresh_observation():
 if not is_instance_valid(observe_button): return
 if is_instance_valid(debug_button):
  debug_button.set_pressed_no_signal(debug_open)
  debug_button.tooltip_text="收起调试，返回对局" if debug_open else "查看或移动区域卡牌"
 if is_instance_valid(debug_free_checkbox):
  debug_free_checkbox.set_pressed_no_signal(engine.debug_free_payment)
  debug_free_checkbox.disabled=modal or not local.is_empty() or not engine.pending.is_empty()
 if is_instance_valid(debug_help_button):
  debug_help_button.disabled=modal
 observe_button.visible=true
 if is_instance_valid(sort_units_button):sort_units_button.visible=not observe_button.visible
 observe_button.text="返回选择" if observing else "观察战场"
 ui.move_child(inspection,-1)
 ui.move_child(observe_button,-1)
 if is_instance_valid(debug_controls): ui.move_child(debug_controls,-1)
 if history_open and is_instance_valid(history_root): ui.move_child(history_root,-1)
 raise_card_search_overlay()
 if is_instance_valid(android_back_button):ui.move_child(android_back_button,-1)
func toggle_observation():
 observing=not observing
 if is_instance_valid(modal_root): modal_root.visible=not observing
 if is_instance_valid(stack_panel):stack_panel.visible=not engine.stack.is_empty() and (not modal or observing)
 if is_instance_valid(debug_root): debug_root.visible=not observing
 for child in hud.get_children():
  if child.has_meta("choice_widget"): child.visible=not observing
 refresh_observation()

func acting_player() -> int:
 if network_session!=null:return local_seat
 if not debug_mode or engine==null: return 0
 if not engine.pending.is_empty(): return int(engine.pending.owner)
 if engine.phase=="mulligan": return 0 if not engine.players[0].mulligan_done else 1
 return engine.priority
func hand_area(who: int) -> Rect2:
 return HAND if who==local_seat else Rect2(320,60,1000,150)
func over_hand_card(at: Vector2,who: int) -> bool:
 var nodes=hand_nodes if who==local_seat else enemy_nodes
 for node in nodes.values():
  if is_instance_valid(node) and node.visible and node.get_global_rect().has_point(at) and (who!=local_seat or hand_scroll.get_global_rect().has_point(at)):return true
 return false
func target_caption(t: Dictionary) -> String:
 if t.has("parts"): return " + ".join(t.parts.map(func(x): return target_caption(x)))
 var parts=[]
 if t.has("mode"): parts.append(t.mode)
 if t.has("color"): parts.append(t.color)
 if t.has("uid"):
  var c=engine.find_card(t.uid)
  if not c.is_empty(): parts.append((player_caption(c.owner)+" · ")+engine.cards[c.card_id].name)
 elif t.has("player"): parts.append(player_caption(t.player))
 elif t.has("stack_id"):
  for entry in engine.stack:
   if entry.id==t.stack_id: parts.append(entry.name)
 if t.has("sacrifice"):
  var c=engine.find_card(t.sacrifice.uid)
  if not c.is_empty(): parts.append("牺牲："+engine.cards[c.card_id].name)
 return " · ".join(parts) if not parts.is_empty() else "使用"
func choose_options(title: String,options: Array,callback: Callable):
 var panel=overlay(title)
 panel.size=Vector2(minf(850,host.ui_metrics.safe.size.x-24),minf(700,host.ui_metrics.safe.size.y-24)); center_panel(panel)
 var scroll=ScrollContainer.new(); scroll.position=Vector2(25,host.ui_metrics.title*1.5+25); scroll.size=Vector2(panel.size.x-50,panel.size.y-scroll.position.y-host.ui_metrics.hit-45); panel.add_child(scroll)
 scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
 var column=VBoxContainer.new(); column.size_flags_horizontal=Control.SIZE_EXPAND_FILL; scroll.add_child(column)
 for option in options:
  var row=Button.new(); row.text=target_caption(option); row.custom_minimum_size=Vector2(650,54); row.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
  column.add_child(row);host.ui_metrics.button(row);row.custom_minimum_size.x=0
  row.pressed.connect(func(): close_overlay(); callback.call(option))
  row.gui_input.connect(func(event):
   if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_RIGHT and option.has("uid"):
    var c=engine.find_card(option.uid)
    if not c.is_empty(): inspect_card(c.card_id,c.uid))
 var back=btn("返回",Rect2(panel.size.x-245,panel.size.y-host.ui_metrics.hit-18,220,host.ui_metrics.hit),func():close_overlay(),false,panel)
 host.ui_metrics.button(back)
func open_local_choices():
 # Compatibility entry point: choices are rendered in the battlefield HUD.
 render()

func open_effect_choices():
 render()

func open_deck_casts():
 # The region tab remains part of the hand area, so browsing never traps priority.
 hand_zones[acting_player()]="deck"
 render()
func close_debug():
 if debug_drag_uid!=0: finish_debug_drag(true)
 if is_instance_valid(debug_root):
  debug_root.get_parent().remove_child(debug_root); debug_root.queue_free()
 debug_root=null; browser_panel=null; browser_scroll=null; browser_cards=null; debug_open=false
 if observing:
  observing=false
  if is_instance_valid(modal_root): modal_root.visible=true
  for widget in hud.get_children():
   if widget.has_meta("choice_widget"): widget.visible=true
 refresh_observation()
func zone_cards(who: int,zone: String) -> Array:
 if zone=="leader":
  return engine.leaders(who).filter(func(c):return c.zone=="leader")
 if zone=="stack": return engine.stack.filter(func(e): return e.kind=="card" and e.owner==who).map(func(e): return e.card)
 var result=engine.players[who][zone].duplicate()
 # Deck front is the next draw; graveyard/exile back is the visible top card.
 if zone in ["grave","exile"]: result.reverse()
 return result
func browse_zone(who: int,zone: String,scroll_position: int=0):
 if history_open or table.combat_animating: return
 close_debug(); debug_open=true; browser_owner=who; browser_zone=zone
 debug_root=layer(ui)
 browser_panel=host.box(debug_root,SIDEBAR,Color.TRANSPARENT,Color.TRANSPARENT); browser_panel.name="PileBrowser"
 var m=host.ui_metrics
 if is_android:
  browser_panel.size=Vector2(minf(920,m.safe.size.x-24),minf(680,m.safe.size.y-m.hit-48))
  center_panel(browser_panel)
  browser_panel.add_theme_stylebox_override("panel",m.panel_style())
 if network_session!=null and network_session.replay_mode:browser_panel.size.y=530
 var browser_header=host.box(browser_panel,Rect2(0,0,browser_panel.size.x,m.hit+12),Color("#101c28"),Color("#637a93"))
 browser_header.mouse_filter=Control.MOUSE_FILTER_IGNORE
 var cards=zone_cards(who,zone)
 txt(player_caption(who)+" · "+ZONE_NAMES[zone]+" · %d" % cards.size(),Rect2(10,10,browser_panel.size.x-m.hit-24,m.hit),18,host.GOLD,browser_panel)
 var close=btn("×",Rect2(browser_panel.size.x-m.hit-8,6,m.hit,m.hit),close_debug,false,browser_panel)
 m.button(close)
 close.name="ClosePileBrowser"; close.tooltip_text="返回对局"
 var top=m.hit+20
 if debug_mode:
  var owner_picker=OptionButton.new(); owner_picker.position=Vector2(10,49); owner_picker.size=Vector2(76,34); browser_panel.add_child(owner_picker)
  owner_picker.add_item("你"); owner_picker.add_item("人机"); owner_picker.selected=who
  owner_picker.item_selected.connect(func(index): browse_zone(index,browser_zone))
  var zone_picker=OptionButton.new(); zone_picker.position=Vector2(92,49); zone_picker.size=Vector2(116,34); browser_panel.add_child(zone_picker)
  var zones=ZONE_NAMES.keys()
  for key in zones: zone_picker.add_item(ZONE_NAMES[key])
  zone_picker.selected=zones.find(zone)
  zone_picker.item_selected.connect(func(index): browse_zone(browser_owner,zones[index]))
  top=92
 browser_scroll=ScrollContainer.new(); browser_scroll.position=Vector2(8,top); browser_scroll.size=Vector2(browser_panel.size.x-16,browser_panel.size.y-top-8)
 browser_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED; browser_panel.add_child(browser_scroll)
 browser_cards=GridContainer.new(); browser_cards.columns=2; browser_cards.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 if is_android:browser_cards.columns=maxi(2,int((browser_panel.size.x-24)/150))
 browser_cards.add_theme_constant_override("h_separation",5); browser_cards.add_theme_constant_override("v_separation",7); browser_scroll.add_child(browser_cards)
 var hidden=zone=="deck" and not debug_mode or zone=="hand" and who!=local_seat and not debug_mode and not replay_view()
 for c in cards:
  var card_hidden=c.card_id=="back" or hidden and not (zone=="deck" and who==acting_player() and not cards.is_empty() and cards[0].uid==c.uid and engine.Cat.may_peek(engine,who))
  var tile_size=Vector2(140,196) if is_android else Vector2(91,129)
  var tile=Control.new(); tile.custom_minimum_size=tile_size; browser_cards.add_child(tile)
  tile.set_meta("display_id","back" if card_hidden else c.card_id)
  var art=host.card(tile,"back",Rect2(Vector2.ZERO,tile_size)) if card_hidden else card_tile(tile,c,Rect2(Vector2.ZERO,tile_size)); art.name="PileCard"
  art.set_script(preload("res://scripts/live_tooltip_panel.gd"))
  art.set_meta("browser_uid",c.uid); art.set_meta("hidden",card_hidden)
  art.tooltip_text="未公开" if card_hidden else hand_card_tooltip(c)
  art.gui_input.connect(func(event):
   if not event is InputEventMouseButton:return
   if event.button_index==MOUSE_BUTTON_RIGHT and event.pressed: inspect_card("back",0,"未公开") if card_hidden else inspect_card(c.card_id,c.uid)
   elif event.button_index==MOUSE_BUTTON_LEFT and event.pressed!=is_android:
    if debug_mode and can_begin_debug_drag(): begin_debug_drag(c.uid,art.get_global_transform()*event.position)
    elif not card_hidden: browse_card_action(c))
 if cards.is_empty(): txt("空",Rect2(80,top+35,60,35),22,host.MUTED,browser_panel)
 browser_scroll.set_deferred("scroll_vertical",scroll_position)
 update_browser_styles(); refresh_observation()

func update_browser_styles():
 if not is_instance_valid(browser_cards): return
 for row in browser_cards.get_children():
  var art=row.get_node_or_null("PileCard")
  if art==null or art.get_meta("hidden",true): continue
  var c=engine.find_card(art.get_meta("browser_uid",0))
  if c.is_empty(): continue
  art.tooltip_text=hand_card_tooltip(c)
  var selected=c.uid in selected_uids()
  var legal=(c.owner==acting_player() or engine.Pack.cast_from(engine,c,acting_player())) and not response_disabled() and (engine.cast_error(acting_player(),c.uid).is_empty() or not engine.extra_action(c).is_empty() and engine.extension_activation_error(c.owner,c).is_empty())
  var style=host.style(Color("#172936"),Color("#ffd65c") if selected else Color("#359bff") if legal else Color("#304657"))
  var conditional=ConditionHints.active(engine,c)
  style.set_border_width_all(4 if selected or legal or conditional else 1); art.add_theme_stylebox_override("panel",style)
  ConditionalFrame.apply(art,style,conditional and not selected)
func browse_card_action(c: Dictionary):
 inspect_card(c.card_id,c.uid)
 if network_locked():return
 if picker_active(): choose_target(engine.ref_target(c)); return
 if c.owner!=acting_player() and not engine.Pack.cast_from(engine,c,acting_player()) or response_disabled(): return
 if not local.is_empty(): return
 if engine.cast_error(acting_player(),c.uid).is_empty(): request_cast(c.uid); return
 var action=engine.extra_action(c)
 if not action.is_empty() and engine.extension_activation_error(c.owner,c).is_empty(): execute_action(action)

func debug_menu():
 if not debug_mode or history_open or table.combat_animating: return
 if debug_open: close_debug()
 else: browse_zone(acting_player(),"deck")

func open_debug_help():
 if not debug_mode or modal or history_open or table.combat_animating:return
 var panel=overlay("测试操作说明")
 panel.size=Vector2(790,610);center_panel(panel)
 var guide=RichTextLabel.new()
 guide.position=Vector2(35,72);guide.size=Vector2(720,454)
 guide.bbcode_enabled=true;guide.scroll_active=true
 guide.add_theme_font_size_override("normal_font_size",18)
 guide.add_theme_color_override("default_color",host.WHITE)
 guide.text="[b]手动测试[/b]\n人机不会自动行动；顶部「操作」提示当前可操作的一方。双方手牌均可查看。「无需付费」只跳过颜色费用，目标和使用时机照常检查。\n\n[b]加入任意卡牌[/b]\n对抗和选择均为空时，左键点击双方战场的空白单位／道具／结界区域，搜索卡牌并加入对应阵营。可选梦违和衍生物。\nZ：加入当前回合玩家的手牌。\nX：竖直加入当前回合玩家的颜色盘。\nC：加入当前回合玩家的墓地，包括梦违牌。\n\n[b]移动已有卡牌[/b]\n按住场上单位拖到所属玩家的单位区域可调整摆放顺序；拖到其他区域执行调试移动。点击「调试」可打开区域列表，列表和手牌中的卡面也可拖到所属玩家的目标区域。拖入战场需要先在「设置」中开启「允许调试拖动放入战场」。移入牌库会放在牌库顶。新增或调试移动不会触发进场、离场、死亡效果。\n\n[b]查看区域[/b]\n点击场上的牌库、墓地或除外区查看；G／H 可打开己方墓地／除外区。请先完成或取消当前选择，再加入或拖动卡牌。"
 panel.add_child(guide)
 btn("返回对局",Rect2(535,544,220,46),close_overlay,false,panel)

func can_debug_add() -> bool:
 return debug_mode and network_session==null and engine!=null and engine.debug_enabled and engine.winner==-2 and engine.phase!="mulligan" and engine.stack.is_empty() and engine.combat.is_empty() and engine.pending.is_empty() and local.is_empty() and not history_open and not debug_open and not observing and not modal and not table.combat_animating and debug_drag_uid==0

func debug_card_matches(id: String,group: String) -> bool:
 var info=engine.cards[id]
 match group:
  "unit":return info.kind in ["自机","单位"]
  "item":return info.kind=="道具"
  "support":return info.kind=="结界"
 return true

func open_debug_card_picker(who: int,destination: String,group: String=""):
 if not can_debug_add():return
 var title=player_caption(who)+" · 加入"+({"field":{"unit":"单位区域","item":"道具区域","support":"结界区域"}.get(group,"战场"),"hand":"手牌","palette":"颜色盘（竖直）","grave":"墓地"}.get(destination,destination))
 var panel=overlay(title,true)
 panel.size=Vector2(1540,870);center_panel(panel)
 panel.set_meta("card_search_picker",true)
 var entries=[]
 for id in engine.cards:
  if engine.cards[id].get("canonical_id",id)!=id:continue
  if not debug_card_matches(id,group):continue
  entries.append({"id":id})
 var selector=make_card_name_search(panel,entries)
 var confirm=btn("加入卡牌",Rect2(1044,815,220,43),func():
  if selector.selected_entry.is_empty():return
  var id=str(selector.selected_entry.id)
  close_overlay()
  message=engine.debug_add(id,who,destination)
  render(),true,panel)
 confirm.name="ConfirmSelection"
 confirm.disabled=true
 confirm.hide()
 selector.selected.connect(func(_entry):confirm.show();confirm.disabled=false)
 btn("返回对局",Rect2(1280,815,220,43),close_overlay,false,panel)
 if not is_android:selector.search_input.grab_focus()

func make_card_name_search(panel: Panel,entries: Array):
 var selector=CardNameSearchPanel.new()
 selector.layout_metrics=host.ui_metrics
 selector.show_filter_controls=not is_android
 selector.name="CardNameSearchPanel"
 selector.position=Vector2(0,60)
 panel.add_child(selector)
 selector.configure(engine.cards,entries,func(id):return host.preview_texture(id))
 host.call_deferred("fit_card_selector",panel,selector)
 return selector
func begin_debug_drag(uid: int,at: Vector2):
 if not debug_mode or observing: return
 var c=engine.find_card(uid)
 if c.is_empty(): return
 inspect_card(c.card_id,uid)
 if not local.is_empty() or not engine.pending.is_empty() or modal or table.combat_animating:
  message="请先完成或取消当前选择"; return
 if attack_preview_uid!=0: clear_attack_preview(); render()
 debug_drag_browser=is_instance_valid(browser_panel) and browser_panel.get_global_rect().has_point(at)
 debug_drag_uid=uid; debug_drag_epoch=c.epoch; debug_drag_origin=at; debug_drag_pointer=at; debug_dragging=false
func debug_destination(at: Vector2,owner: int) -> String:
 if is_instance_valid(browser_panel) and browser_panel.visible and browser_panel.get_global_rect().has_point(at): return ""
 var board_zone=table.debug_drop_zone((at-STAGE.position)/STAGE.size*Vector2(viewport.size),owner) if STAGE.has_point(at) else ""
 if board_zone=="field" and not host.debug_drag_to_field:return ""
 if board_zone in ["deck","grave","exile","leader"]: return board_zone
 if hand_area(owner).has_point(at): return "hand"
 return board_zone

func debug_unit_reorder_target(c: Dictionary,at: Vector2) -> bool:
 if debug_drag_browser or c.is_empty() or c.zone!="field" or not engine.is_unit(c) or not STAGE.has_point(at):return false
 var spot=table.debug_field_group(stage_point(at))
 return not spot.is_empty() and spot.owner==c.owner and spot.group=="unit"
func handle_debug_drag(event: InputEvent):
 if event is InputEventMouseMotion:
  debug_drag_pointer=make_input_local(event).position
  if not debug_dragging and debug_drag_pointer.distance_to(debug_drag_origin)>10:
   debug_dragging=true
   if is_instance_valid(browser_panel): browser_panel.hide()
   debug_drag_art=card_tile(ui,engine.find_card(debug_drag_uid),Rect2(debug_drag_pointer-Vector2(70,97),Vector2(140,195)))
   debug_drag_art.mouse_filter=Control.MOUSE_FILTER_IGNORE; debug_drag_art.modulate.a=0.82
   debug_drop_hint=txt("",Rect2(0,0,170,38),22,host.GOLD,debug_drag_art)
   debug_drop_hint.position=Vector2(-15,-43); debug_drop_hint.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
   debug_drop_hint.add_theme_constant_override("outline_size",6); debug_drop_hint.add_theme_color_override("font_outline_color",Color("#101c28"))
  if debug_dragging:
   debug_drag_art.position=debug_drag_pointer-Vector2(70,97)
   var c=engine.find_card(debug_drag_uid)
   var destination=debug_destination(debug_drag_pointer,c.owner) if not c.is_empty() else ""
   if debug_unit_reorder_target(c,debug_drag_pointer):debug_drop_hint.text="调整单位位置"
   elif not destination.is_empty():debug_drop_hint.text="放入"+ZONE_NAMES[destination]+("顶" if destination=="deck" else "")
   else:debug_drop_hint.text="取消移动"
  get_viewport().set_input_as_handled()
 elif event is InputEventMouseButton:
  debug_drag_pointer=make_input_local(event).position
  if event.button_index==MOUSE_BUTTON_RIGHT and event.pressed:
   finish_debug_drag(true); get_viewport().set_input_as_handled()
  elif event.button_index==MOUSE_BUTTON_LEFT and not event.pressed:
   finish_debug_drag(false); get_viewport().set_input_as_handled()
 elif event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE:
  finish_debug_drag(true); get_viewport().set_input_as_handled()
func finish_debug_drag(cancelled: bool):
 var uid=debug_drag_uid; var moved=debug_dragging; var at=debug_drag_pointer
 debug_drag_uid=0; debug_dragging=false
 if is_instance_valid(debug_drag_art): debug_drag_art.queue_free()
 debug_drag_art=null
 var c=engine.find_card(uid)
 var destination=debug_destination(at,c.owner) if not c.is_empty() and moved and not cancelled else ""
 if is_instance_valid(browser_panel): browser_panel.visible=not observing
 if cancelled or c.is_empty() or c.epoch!=debug_drag_epoch: return
 if not moved:
  if c.zone in ["field","leader"]: object_clicked(c.uid)
  elif c.zone=="hand": hand_clicked(c.uid)
  else: browse_card_action(c)
  return
 if debug_unit_reorder_target(c,at):
  if table.reorder_unit(uid,stage_point(at)):render()
  return
 if destination.is_empty(): return
 var error=engine.debug_move(uid,destination)
 message=error
 var scroll_position=browser_scroll.scroll_vertical if is_instance_valid(browser_scroll) else 0
 if error.is_empty(): selection=[]
 render()
 if debug_drag_browser: browse_zone(browser_owner,browser_zone,scroll_position)

func picker_active() -> bool:
 if network_locked():return false
 if not local.is_empty(): return local.mode=="target"
 return engine.pending.get("owner",-1)==acting_player() and engine.pending.get("kind","") in ["trigger","effect_choice"]
func sync_picker():
 if not local.is_empty():
  if local.mode!="target": return
  var options=local_targets()
  if local.get("action","")=="" and engine.cards[engine.find_card(local.uid).card_id].kind!="符卡" and options.is_empty(): options=[{"none":true}]
  picker.configure(options,"local:"+str(local.uid)+":"+local.get("action","")+":"+str(local.get("index",-1))+":"+str(engine.revision))
 elif picker_active():
  var options=engine.pending.options
  picker.configure(options,"trigger:"+str(engine.revision)+JSON.stringify(engine.pending),engine.pending.trigger.get("effect","")=="death_poverty")
 else: picker.reset()
func confirm_declaration():
 if observing or local.is_empty() or local.mode!="target" or response_disabled(): return
 sync_picker()
 if not picker.ready(): return
 local.target=picker.option()
 refresh_payment_plan()
 if not payment_ready():return
 local.mode="payment";commit_local()
func confirm_trigger():
 if network_locked():return
 if observing or not local.is_empty() or not picker_active(): return
 sync_picker()
 if not picker.ready(): return
 var target=picker.option()
 if engine.pending.kind=="effect_choice" and engine.pending.trigger.effect in ["cat:grant","cat:trigger_pay"] and (engine.pending.trigger.effect=="cat:grant" or target.get("pay",false)):
  var t=engine.pending.trigger;var cost=engine.Cat.granted_cost(engine,t,target) if t.effect=="cat:grant" else t.data.cost
  local={"uid":t.source.uid,"action":"choice_payment","choice_cost":cost,"target":target,"mode":"payment","plan":[]}
  start_payment();return
 if engine.pending.kind=="effect_choice": engine.choose_effect(target)
 else: engine.choose_trigger(target)
 picker.reset(); selection=[]; render()
func decline_trigger():
 engine.paid_cast_uid=-1
 if observing or not picker_active() or not local.is_empty(): return
 if engine.pending.kind=="trigger": engine.choose_trigger({})
 elif engine.pending.trigger.optional: engine.choose_effect({})
 picker.reset(); selection=[]; render()
func inline_pick(atom: Dictionary):
 if observing or not picker_active(): return
 if picker.select(atom):
  if not local.is_empty(): local.target=picker.option()
  render()
func choice_matches_query(atom: Dictionary,caption: String,query: Dictionary,names: Dictionary,card_name: String="") -> bool:
 if query.term.is_empty():return true
 if not card_name.is_empty():return names.has(card_name)
 var value=atom.value
 if atom.kind=="target" and value is Dictionary:
  if value.has("card_name"):return names.has(value.card_name)
  var id=str(value.get("outside_id",""))
  if value.has("uid"):
   var c=engine.find_card(value.uid)
   id=str(c.get("card_id",""))
  if engine.cards.has(id):return SearchAliases.matches_query(engine.cards[id],id,query) or not query.exclusive and query.term in caption.to_lower()
 return query.term in caption.to_lower()
func render_inline_picker(confirm: Callable,optional: bool=false):
 var choice_parent=hud
 var wide_choices=false
 var deck_reveal_choice=engine.pending.get("kind","")=="effect_choice" and engine.pending.get("trigger",{}).get("effect","")=="cat:unit_reveal"
 if not picker.prompt().is_empty() and not (is_android and optional):
  var prompt_label=txt(picker.prompt(),Rect2(1330,610,237,48),17,host.GOLD)
  if is_android:
   prompt_label.position=Vector2(ANDROID_ACTION_X,responsive.log_rect.end.y+8)
   prompt_label.size=Vector2(ANDROID_ACTION_WIDTH,host.ui_metrics.body*2.5)
 elif picker.ready() and not (is_android and optional):
  var chosen=picker.option()
  if chosen.get("selection_id","")=="emotions":
   var effects=engine.Pack.flatten(chosen)
   var counters=effects.filter(func(effect):return str(effect.get("mode","")).begins_with("反制")).size()
   var summary=txt("已选反制 %d 项 · 其他 %d 项" % [counters,effects.size()-counters],Rect2(1330,610,237,48),16,host.GOLD)
   if is_android:
    summary.position=Vector2(ANDROID_ACTION_X,responsive.log_rect.end.y+8)
    summary.size=Vector2(ANDROID_ACTION_WIDTH,58)
   summary.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 var options=[]
 var declared_names={}
 for entry in picker.entries:
  if entry.option.has("card_name"):declared_names[entry.option.card_name]=true
 for atom in picker.available():
  if atom.kind!="target" or not atom.value.has("uid") and not atom.value.has("player") and not atom.value.has("stack_id") or atom.value.has("counter"): options.append(atom); continue
  if atom.value.has("uid"):
   var c=engine.find_card(atom.value.uid)
   if not c.is_empty() and deck_reveal_choice and c.zone=="deck":options.append(atom)
   elif not c.is_empty() and c.zone not in ["field","palette","leader","stack","hand"]:continue
 if not options.is_empty() and not declared_names.is_empty() and options.all(func(atom):return atom.kind=="mode" and declared_names.has(atom.value)):
  render_card_name_picker(options,confirm,optional)
  return
 if options.size()>16 or card_search_target_key==picker.key and not picker.key.is_empty():
  var card_entries=[]
  for atom in options:
   var card_id=choice_atom_card_id(atom)
   if card_id.is_empty():
    card_entries.clear()
    break
   var caption=target_caption(atom.value)
   if atom.value.has("counter"):caption+=" · "+str(atom.value.counter)+" "+str(atom.value.counter_index+1)
   card_entries.append({"id":card_id,"caption":caption,"payload":atom})
  if card_entries.size()==options.size():
   card_search_target_key=picker.key
   render_card_target_picker(card_entries,confirm,optional)
   return
 if not options.is_empty():
  var choice_box: Panel
  if is_android:
   var choice_key="inline:"+picker.key+JSON.stringify(picker.path)
   choice_box=android_choice_box(picker.prompt() if not picker.prompt().is_empty() else "选择能力或目标",choice_key)
   if choice_box!=null:choice_box.set_meta("choice_key",choice_key)
  if not is_android or choice_box!=null:
   var scroll=ScrollContainer.new();scroll.position=Vector2(1330,664);scroll.size=Vector2(237,123)
   if engine.pending.get("trigger",{}).get("effect","")=="cat:copy_x":scroll.position.y=630;scroll.size.y=157
   if is_android:
    scroll.position=Vector2(18,host.ui_metrics.hit+18)
    scroll.size=Vector2(choice_box.size.x-36,choice_box.size.y-scroll.position.y-12)
    scroll.scroll_deadzone=8
   scroll.name="BattleChoiceScroll"
   scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;scroll.set_meta("choice_widget",true)
   (choice_box if is_android else hud).add_child(scroll)
   if is_android:scroll.set_meta("android_swipe_handled",true);battle_choice_scroll=scroll
   var column=VBoxContainer.new();column.size_flags_horizontal=Control.SIZE_EXPAND_FILL;scroll.add_child(column)
   var search: LineEdit
   if options.size()>16:
    if not is_android:
     var panel=overlay("选择名称" if not declared_names.is_empty() else "选择效果")
     panel.size=Vector2(850,650);center_panel(panel);panel.set_meta("name_picker",true)
     hud.remove_child(scroll);panel.add_child(scroll)
     scroll.position=Vector2(24,70);scroll.size=Vector2(802,480)
     choice_parent=panel;wide_choices=true
    search=LineEdit.new();search.placeholder_text="输入卡名、编号或别名检索";search.custom_minimum_size=Vector2(215,36);column.add_child(search)
    search.text_changed.connect(func(value):
     var search_query=SearchAliases.prepare_query(engine.cards,value,SearchAliases.load_rules())
     var names=SearchAliases.matching_names(engine.cards,search_query)
     for child in column.get_children():
      if child is Button:child.visible=choice_matches_query(child.get_meta("choice_atom"),child.text,search_query,names,str(child.get_meta("search_card_name",""))))
   for atom in options:
    var row=Button.new();row.custom_minimum_size=Vector2(195 if is_android else 215,54 if is_android else 45);column.add_child(row)
    if is_android:row.mouse_filter=Control.MOUSE_FILTER_PASS
    row.set_meta("choice_atom",atom)
    if atom.kind=="mode" and declared_names.has(atom.value):row.set_meta("search_card_name",atom.value)
    row.text=(engine.cards[atom.value.outside_id].name if atom.value.has("outside_id") else target_caption(atom.value)) if atom.kind=="target" else str(atom.value)
    if atom.kind=="target" and atom.value.has("counter"):row.text+=" · "+str(atom.value.counter)+" "+str(atom.value.counter_index+1)
    row.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;host.ui_metrics.button(row)
    row.pressed.connect(func():inline_pick(atom))
    row.gui_input.connect(func(event):
     if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_RIGHT and atom.kind=="target" and atom.value.has("uid"):
      var c=engine.find_card(atom.value.uid)
      if not c.is_empty():inspect_card(c.card_id,c.uid))
 if picker.available().any(func(atom): return atom.get("role","")=="sacrifice") and (not is_android or not optional and picker.prompt().is_empty()):
  var sacrifice_label=txt("选择牺牲的单位",Rect2(1330,620,237,32),18,host.GOLD)
  if is_android and not optional:
   sacrifice_label.position=Vector2(ANDROID_ACTION_X,responsive.log_rect.end.y+8)
   sacrifice_label.size=Vector2(ANDROID_ACTION_WIDTH,58)
 if local.is_empty() or payment_ready():
  var confirm_rect=Rect2(580,570,240,49) if wide_choices else Rect2(1330,799,237,49)
  var button=btn("确定" if local.is_empty() else "发动",confirm_rect,confirm,true,choice_parent)
  if not wide_choices:responsive.add_phase_action(button)
  button.disabled=not picker.ready()
 if optional:
  var decline=btn("不使用",Rect2(1330,853,115,36),decline_trigger)
  responsive.add_phase_action(decline)
 if not picker.path.is_empty():
  var reset=btn("重选",Rect2(1452,853,115,36),func(): picker.path=[]; picker.normalize(); render())
  responsive.add_phase_action(reset)

func choice_atom_card_id(atom: Dictionary) -> String:
 if atom.get("kind","")!="target" or not atom.get("value") is Dictionary:return ""
 var value: Dictionary=atom.value
 var id=str(value.get("outside_id",""))
 if id.is_empty() and value.has("uid"):
  var card_instance=engine.find_card(int(value.uid))
  id=str(card_instance.get("card_id",""))
 return id if engine.cards.has(id) else ""

func render_card_target_picker(entries: Array,confirm: Callable,optional: bool):
 var title=picker.prompt() if not picker.prompt().is_empty() else "选择卡牌"
 var panel=overlay(title,true)
 panel.size=Vector2(1540,870);center_panel(panel);panel.set_meta("card_search_picker",true)
 var selector=make_card_name_search(panel,entries)
 if not picker.path.is_empty():
  var last_atom=picker.path.back()
  var last_id=choice_atom_card_id(last_atom)
  if not last_id.is_empty():
   var display_entry={"id":last_id,"caption":target_caption(last_atom.value),"payload":last_atom}
   for entry in entries:
    if entry.payload==last_atom:
     display_entry=entry
     break
   selector.choose_entry(display_entry)
 var confirm_button=btn("确定" if local.is_empty() else "发动",Rect2(1044,815,220,43),confirm,true,panel)
 confirm_button.name="ConfirmSelection"
 confirm_button.disabled=not picker.ready() or not local.is_empty() and not payment_ready()
 selector.selected.connect(func(entry):
  if observing or not picker_active():return
  if picker.select(entry.payload):
   if not local.is_empty():
    local.target=picker.option()
    refresh_payment_plan()
   if picker.ready():confirm_button.disabled=not local.is_empty() and not payment_ready()
   else:render())
 if optional:btn("不使用",Rect2(1280,815,220,43),decline_trigger,false,panel)
 elif not local.is_empty():btn("取消使用",Rect2(1280,815,220,43),cancel_cast,false,panel)
 if not is_android:selector.search_input.grab_focus()

func render_card_name_picker(options: Array,confirm: Callable,optional: bool):
 var panel=overlay("选择名称",true)
 panel.size=Vector2(1540,870);center_panel(panel);panel.set_meta("name_picker",true)
 var name_ids={}
 for id in engine.DB.IDS:
  if not engine.cards.has(id):continue
  if engine.cards[id].get("canonical_id",id)!=id:continue
  var card_name=str(engine.cards[id].name)
  if not name_ids.has(card_name):name_ids[card_name]=id
 for id in engine.cards:
  if id in engine.DB.IDS:continue
  var card_name=str(engine.cards[id].get("name",""))
  if not card_name.is_empty() and not name_ids.has(card_name):name_ids[card_name]=id
 var entries=[]
 for atom in options:
  var card_name=str(atom.value)
  if name_ids.has(card_name):entries.append({"id":name_ids[card_name],"caption":card_name,"payload":atom})
 var selector=make_card_name_search(panel,entries)
 if picker.ready():
  var chosen_name=str(picker.option().get("card_name",""))
  if name_ids.has(chosen_name):selector.select_id(name_ids[chosen_name])
 var confirm_button=btn("确定" if local.is_empty() else "发动",Rect2(1044,815,220,43),confirm,true,panel)
 confirm_button.name="ConfirmSelection"
 confirm_button.disabled=not picker.ready() or not local.is_empty() and not payment_ready()
 selector.selected.connect(func(entry):
  if observing or not picker_active():return
  if picker.select(entry.payload):
   if not local.is_empty():
    local.target=picker.option()
    refresh_payment_plan()
   confirm_button.disabled=not picker.ready() or not local.is_empty() and not payment_ready())
 if optional:btn("不使用",Rect2(1280,815,220,43),decline_trigger,false,panel)
 elif not local.is_empty():btn("取消使用",Rect2(1280,815,220,43),cancel_cast,false,panel)
 if not is_android:selector.search_input.grab_focus()
func ward_timeline(wards: Array,coins: int=0,coin_order: int=-1) -> Array:
 var events=[]
 for i in range(wards.size()):
  var w=wards[i]
  if int(w.get("turn",engine.turn)) not in [-1,engine.turn] or int(w.get("amount",0))<=0:continue
  events.append({"order":int(w.get("order",i)),"amount":int(w.amount),"coin":false})
 if coins>0:events.append({"order":coin_order,"amount":coins,"coin":true})
 events.sort_custom(func(a,b):return a.order<b.order)
 var lines=[];var last_amount=-1;var count=0
 for event in events:
  if event.coin:
   if count>0:lines.append("防避%d×%d" % [last_amount,count]);count=0
   lines.append("铜钱指示物"+("×%d" % event.amount if event.amount>1 else ""))
  elif event.amount==last_amount and count>0:count+=1
  else:
   if count>0:lines.append("防避%d×%d" % [last_amount,count])
   last_amount=event.amount;count=1
 if count>0:lines.append("防避%d×%d" % [last_amount,count])
 return lines
func player_buffs(who: int) -> String:
 var p=engine.players[who];var lines=[]
 lines.append_array(ward_timeline(p.get("wards",[]),int(p.get("coins",0)),int(p.get("coin_order",-1))))
 if p.get("shroud_turn",-1)==engine.turn:lines.append("不能成为目标")
 if not p.get("wine",[]).is_empty():lines.append("减费："+"、".join(p.wine))
 for key in p.get("counters",{}):
  if int(p.counters[key])!=0:lines.append(str(key)+"指示物："+str(p.counters[key]))
 return "\n".join(lines)
func player_buffs_compact(who: int) -> String:
 var p=engine.players[who];var lines=[]
 if int(p.get("coins",0))>0:lines.append("铜钱：%d" % p.coins)
 var ward=0
 for w in p.get("wards",[]):
  if int(w.get("turn",engine.turn)) in [-1,engine.turn]:ward+=maxi(0,int(w.get("amount",0)))
 if ward>0:lines.append("防避：%d" % ward)
 if p.get("shroud_turn",-1)==engine.turn:lines.append("不能成为目标")
 if not p.get("wine",[]).is_empty():lines.append("减费："+"、".join(p.wine))
 for key in p.get("counters",{}):
  if int(p.counters[key])!=0:lines.append(str(key)+"："+str(p.counters[key]))
 return "\n".join(lines)
func render_undo():
 if network_session.read_only:return
 var request=network_session.room.get("undo_request",{})
 if request.is_empty():
  var button=btn("悔棋",Rect2(1460,58,116,32),func():network_session.room_action({"name":"undo_request"}))
  button.disabled=not network_session.can_act(true) or not network_session.room.get("undo_available",false) or not engine.stack.is_empty()
  return
 var own=int(request.from)==local_seat
 var message_label=txt("等待对方同意悔棋" if own else "对方请求悔棋",Rect2(1366,618,218,68),19,host.GOLD)
 message_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 if own:btn("取消请求",Rect2(1366,694,218,42),func():network_session.room_action({"name":"undo_cancel","ticket":request.id}))
 else:
  btn("同意悔棋",Rect2(1366,694,218,42),func():network_session.room_action({"name":"undo_accept","ticket":request.id}),true)
  btn("拒绝悔棋",Rect2(1366,746,218,42),func():network_session.room_action({"name":"undo_decline","ticket":request.id}))
func render_life(who: int,rect: Rect2):
 var current_life=int(engine.players[who].life)
 if life_last.has(who) and int(life_last[who])!=current_life:
  var delta=current_life-int(life_last[who])
  if life_flash_tweens.has(who) and life_flash_tweens[who].is_valid():life_flash_tweens[who].kill()
  if life_flashes.has(who) and is_instance_valid(life_flashes[who]):life_flashes[who].queue_free()
  var popup=txt(("+" if delta>0 else "")+str(delta),Rect2(rect.position+Vector2(100,8),Vector2(100,42)),29,Color("#45d889") if delta>0 else Color("#f36464"),effects)
  popup.mouse_filter=Control.MOUSE_FILTER_IGNORE
  popup.add_theme_color_override("font_outline_color",Color("#081019"));popup.add_theme_constant_override("outline_size",5)
  life_flashes[who]=popup
  var tween=create_tween().set_parallel(true)
  tween.tween_property(popup,"position:y",popup.position.y-28,1.0)
  tween.tween_property(popup,"modulate:a",0.0,1.0)
  tween.chain().tween_callback(popup.queue_free)
  life_flash_tweens[who]=tween
 life_last[who]=current_life
 var selected=picker.selected_refs().any(func(t): return t.get("player",-1)==who)
 var legal=picker_active() and picker.available_refs().any(func(t): return t.get("player",-1)==who)
 var color=Color("#ffd65c") if selected else Color("#359bff") if legal else Color("#486376")
 var button=btn(player_caption(who)+"  %d" % engine.players[who].life,rect,func(): choose_target({"player":who}))
 var curse=ConditionHints.curse_caption(engine,who)
 var warning_count=clampi(ConditionHints.curse_count(engine,who),0,CurseWarning.MAX_VISIBLE)
 var warning_width=warning_count*CurseWarning.ICON_SIZE.x+maxi(0,warning_count-1)*CurseWarning.GAP
 button.tooltip_text="\n".join([player_buffs(who),curse].filter(func(line):return not line.is_empty()))
 if button.tooltip_text.is_empty():button.tooltip_text="当前没有玩家指示物或增益"
 var panel=host.style(Color("#192a38"),color); panel.set_border_width_all(4 if selected or legal else 1)
 if warning_count>0:
  panel.content_margin_right=warning_width+16
  panel.content_margin_bottom=15
  button.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
 button.add_theme_stylebox_override("normal",panel)
 for state in ["hover","pressed","focus"]:
  var feedback=panel.duplicate();feedback.border_color=host.GOLD;feedback.set_border_width_all(3)
  if state=="pressed":feedback.bg_color=Color("#514328")
  button.add_theme_stylebox_override(state,feedback)
 var bar=ProgressBar.new(); bar.position=Vector2(10,rect.size.y-15)
 bar.min_value=0; bar.max_value=20; bar.value=clampf(engine.players[who].life,0,20); bar.show_percentage=false
 bar.mouse_filter=Control.MOUSE_FILTER_IGNORE
 var background=StyleBoxFlat.new(); background.bg_color=Color("#09121d"); background.set_corner_radius_all(3)
 var fill=StyleBoxFlat.new(); fill.bg_color=Color("#a94752") if who!=local_seat else Color("#43b59a"); fill.set_corner_radius_all(3)
 bar.add_theme_stylebox_override("background",background); bar.add_theme_stylebox_override("fill",fill); button.add_child(bar)
 bar.add_theme_font_size_override("font_size",1); bar.size=Vector2(rect.size.x-20,7)
 life_widgets[who]={"button":button,"bar":bar,"legal":legal,"selected":selected}
 if warning_count>0:
  life_widgets[who].curse_warnings=[]
  for i in range(warning_count):
   var warning=CurseWarning.new();warning.name="CurseWarning"+str(i+1);warning.size=CurseWarning.ICON_SIZE
   warning.position=Vector2(rect.size.x-8-warning_width+i*(CurseWarning.ICON_SIZE.x+CurseWarning.GAP),(rect.size.y-CurseWarning.ICON_SIZE.y)*0.5-4)
   warning.tooltip_text=curse
   button.add_child(warning);life_widgets[who].curse_warnings.append(warning)
  life_widgets[who].curse_warning=life_widgets[who].curse_warnings[0]
 var buff_rect=Rect2(rect.position.x,rect.position.y-host.ui_metrics.body*2.5-8,rect.size.x,host.ui_metrics.body*2.5) if who==local_seat else Rect2(rect.position.x,rect.end.y+host.ui_metrics.hit*2+host.ui_metrics.gap*3,rect.size.x,host.ui_metrics.body*2.5)
 var status=txt(player_buffs_compact(who),buff_rect,16,host.GOLD)
 status.mouse_filter=Control.MOUSE_FILTER_IGNORE;status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 life_widgets[who].buffs=status
func target_rect(target: Dictionary) -> Rect2:
 if target.has("player") and life_widgets.has(int(target.player)): return life_widgets[int(target.player)].button.get_global_rect()
 if target.has("stack_id"): return stack_panel.entry_rect(int(target.stack_id))
 if target.has("uid"):
  var c=engine.find_card(target.uid)
  if c.is_empty() or c.epoch!=target.get("epoch",-1): return Rect2()
  if c.zone=="grave" and grave_target_tiles.has(c.uid):
   var tile=grave_target_tiles[c.uid]
   return tile.get_global_rect().intersection(tile.get_meta("target_scroll").get_global_rect())
  if c.zone=="stack": return stack_panel.card_rect(c.uid)
  var key="card_"+str(c.uid)
  if table.visuals.has(key): return projected_card_rect(table.visuals[key])
  for group_key in table.descriptors:
   if c.uid in table.descriptors[group_key].get("members",[]) and table.visuals.has(group_key):return projected_card_rect(table.visuals[group_key])
  var nodes=hand_nodes if c.owner==local_seat else enemy_nodes
  if c.zone=="hand" and nodes.has(c.uid): return nodes[c.uid].get_global_rect()
  if c.zone in ["deck","grave","exile"]:
   return Rect2(project(table.zone_position(c.zone,c.owner))-Vector2(25,30),Vector2(50,60))
 return Rect2()
func arrow_targets(target: Dictionary) -> Array:
 if target.has("picks"):
  var result=[]
  for p in engine.Pack.flatten(target): result.append_array(arrow_targets(p))
  return result
 if target.has("parts"):
  var result=[]
  for part in target.parts: result.append_array(arrow_targets(part))
  return result
 var actual={}
 for field in ["uid","epoch","zone","player","stack_id"]:
  if target.has(field): actual[field]=target[field]
 return [actual] if not actual.is_empty() else []

func interactive_stack_target_uids() -> Array:
 var result=[]
 for entry in engine.stack:
  for ref in arrow_targets(entry.get("target",{})):
   if not ref.has("uid"):continue
   var c=engine.find_card(ref.uid)
   if c.is_empty() or c.zone!="field" or c.epoch!=ref.get("epoch",-1):continue
   if not engine.cards[c.card_id].get("stackable",false):continue
   if engine.cards[c.card_id].kind not in ["道具","结界"]:continue
   if c.uid not in result:result.append(c.uid)
 return result

func stack_grave_targets() -> Dictionary:
 var targets={0:[],1:[]}
 for entry in engine.stack:
  for ref in arrow_targets(entry.get("target",{})):
   if not ref.has("uid"):continue
   var c=engine.find_card(ref.uid)
   if c.is_empty() or c.zone!="grave" or c.epoch!=ref.get("epoch",-1):continue
   if not targets[c.owner].any(func(other):return other.uid==c.uid):targets[c.owner].append(ref)
 return targets

func exposed_grave_choice() -> bool:
 var atoms=region_atoms()
 if atoms.is_empty() or not atoms.all(func(atom):return engine.find_card(atom.value.uid).zone=="grave"):return false
 return atoms.any(func(atom):return grave_target_tiles.has(atom.value.uid))

func render_grave_targets():
 clear_children(grave_target_layer);grave_target_tiles={}
 var targets=stack_grave_targets()
 var available=picker.available_refs() if picker_active() else []
 var selected=picker.selected_refs() if picker_active() else []
 for who in [1-local_seat,local_seat]:
  var refs=targets[who]
  if refs.is_empty():continue
  var width=maxf(190.0,minf(600.0,26.0+refs.size()*126.0))
  var at=Vector2(250,159 if who!=local_seat else 411)
  var panel=host.box(grave_target_layer,Rect2(at,Vector2(width,249)),Color("#101c28e8"),Color("#8c7242"))
  panel.name="GraveTargets%d" % who
  txt(player_caption(who)+"墓地 · 堆叠目标",Rect2(12,7,width-24,27),17,host.GOLD,panel)
  var scroll=ScrollContainer.new();scroll.position=Vector2(10,37);scroll.size=Vector2(width-20,178)
  scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;panel.add_child(scroll)
  var row=HBoxContainer.new();row.add_theme_constant_override("separation",8);scroll.add_child(row)
  for ref in refs:
   var c=engine.find_card(ref.uid)
   var cell=Control.new();cell.custom_minimum_size=Vector2(118,174);row.add_child(cell)
   var legal=available.any(func(option):return option.get("uid",-1)==c.uid and option.get("epoch",-1)==c.epoch)
   var chosen=selected.any(func(option):return option.get("uid",-1)==c.uid and option.get("epoch",-1)==c.epoch)
   var art=card_tile(cell,c,Rect2(4,0,110,153),func():
    if legal:choose_target(ref)
    else:inspect_card(c.card_id,c.uid))
   art.name="GraveTargetCard";art.set_meta("target_uid",c.uid)
   art.set_meta("target_scroll",scroll)
   art.tooltip_text=engine.cards[c.card_id].name+" · "+player_caption(who)+"墓地"
   art.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
   var style=host.style(Color("#172936"),Color("#ffd65c") if chosen else Color("#359bff") if legal else Color("#8c7242"))
   style.set_border_width_all(3 if legal or chosen else 1)
   art.add_theme_stylebox_override("panel",style)
   art.gui_input.connect(func(event):
    if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_RIGHT:inspect_card(c.card_id,c.uid))
   var name=txt(engine.cards[c.card_id].name,Rect2(0,155,118,19),13,host.WHITE,cell)
   name.clip_text=true;name.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
   grave_target_tiles[c.uid]=art
  if picker_active() and not region_atoms().is_empty() and exposed_grave_choice():
   var others=region_atoms().any(func(atom):return not grave_target_tiles.has(atom.value.uid))
   if others and who==local_seat or others and targets[local_seat].is_empty():
    var browse=btn("选择其他墓地牌",Rect2(width-169,218,157,27),region_picker,false,panel)
    browse.add_theme_font_size_override("font_size",13)
func rect_edge(rect: Rect2,toward: Vector2) -> Vector2:
 var direction=(toward-rect.get_center()).normalized()
 var distance=minf(rect.size.x*0.5/maxf(0.001,absf(direction.x)),rect.size.y*0.5/maxf(0.001,absf(direction.y)))
 return rect.get_center()+direction*(distance+5)
func stack_target_arrows() -> Array:
 var result=[]
 if not is_instance_valid(table): return result
 for entry in engine.stack:
  var origin=stack_panel.entry_rect(entry.id)
  if not origin.has_area(): continue
  var seen=[]
  for target in arrow_targets(entry.target):
   if target in seen: continue
   seen.append(target)
   var destination=target_rect(target)
   if destination.size==Vector2.ZERO: continue
   var from=rect_edge(origin,destination.get_center())
   var to=rect_edge(destination,origin.get_center())
   # Overlapping stack cards expose their left edge; a center-to-center line
   # would otherwise cross the target's far edge and appear to point backwards.
   if target.has("stack_id") and origin.intersects(destination):
    from=Vector2(origin.position.x,origin.get_center().y-25)
    to=Vector2(destination.position.x+7,destination.get_center().y)
   result.append({"entry":entry.id,"target":target,"from":from,"to":to})
 return result

func open_history():
 if history_open: return
 history_open=true; history_root=layer(ui)
 var shade=ColorRect.new(); shade.color=Color(0,0,0,0.38); shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); history_root.add_child(shade)
 history_panel=host.box(history_root,Rect2(1100,75,480,807),Color("#0f1b29"),Color("#637a93"))
 txt("对局流程记录",Rect2(20,15,435,40),26,host.GOLD,history_panel)
 var scroll=ScrollContainer.new(); scroll.position=Vector2(14,66); scroll.size=Vector2(453,724); scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED; history_panel.add_child(scroll)
 var column=VBoxContainer.new(); column.size_flags_horizontal=Control.SIZE_EXPAND_FILL; scroll.add_child(column)
 var events=engine.history.duplicate(); events.reverse()
 for entry in events:
  var row=PanelContainer.new(); row.custom_minimum_size=Vector2(432,96 if entry.art.is_empty() else 136); column.add_child(row)
  row.add_theme_stylebox_override("panel",host.style(Color("#162636"),Color("#2d455a")))
  var content=Control.new(); row.add_child(content)
  txt("第%d回合 · %s" % [entry.turn,phase_names.get(entry.phase,entry.phase)],Rect2(0,0,400,23),14,host.MUTED,content)
  var left=0
  if not entry.art.is_empty():
   var art=entry.art[0]; var hidden=art.card_id=="back" or art.get("hidden",false) and art.owner!=local_seat and not debug_mode and not replay_view()
   var card=host.card(content,"back",Rect2(0,28,62,87)) if hidden else card_tile(content,art,Rect2(0,28,62,87))
   card.set_meta("history_display_id","back" if hidden else art.card_id); left=74
   card.gui_input.connect(func(event):
    if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_RIGHT and not hidden: inspect_card(art.card_id,0,"",art.get("art_id","")))
  var label=txt(entry.text,Rect2(left,29,398-left,74),17,host.WHITE,content)
  label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; label.size=Vector2(398-left,74)
 refresh_observation()
func close_history():
 if is_instance_valid(history_root): history_root.queue_free()
 history_root=null; history_open=false; clock_time=0
func region_atoms() -> Array:
 if not picker_active(): return []
 return picker.available().filter(func(atom):
  if atom.kind!="target" or not atom.value.has("uid"): return false
  var c=engine.find_card(atom.value.uid)
  return not c.is_empty() and c.zone in ["deck","grave","exile","hand"])
func region_picker_needed() -> bool:
 return picker_active() and not picker.ready() and not region_atoms().is_empty() and (not exposed_grave_choice() or not region_batch_group().is_empty())
func region_batch_group() -> Dictionary:
 if picker.specs.is_empty() or picker.ready():return {}
 var state=picker.dynamic_state()
 if state.index<0 or state.group>=picker.specs[state.index].get("selection",[]).size():return {}
 var group=picker.specs[state.index].selection[state.group]
 if int(group.max)<=1 or group.pool.is_empty() or group.get("distinct_names",false) or group.has("sum_max"):return {}
 for ref in group.pool:
  if not ref.has("uid"):return {}
  var card=engine.find_card(ref.uid)
  if card.is_empty() or card.zone not in ["deck","grave","exile","hand"]:return {}
 return group
func region_picker():
 var atoms=region_atoms()
 if atoms.is_empty(): return
 var batch_group=region_batch_group()
 var batch_key=picker.key+JSON.stringify(picker.path)
 if region_batch_key!=batch_key:
  region_batch=[];region_batch_key=batch_key
 region_batch=region_batch.filter(func(atom):return atom in atoms)
 if region_selected not in atoms: region_selected={}
 var title=picker.prompt() if not picker.prompt().is_empty() else "选择卡牌"
 var panel: Panel
 if is_android:
  panel=android_choice_box(title,"region:"+batch_key)
  if panel==null:region_tiles={};return
  panel.set_meta("choice_key","region:"+batch_key)
 else:
  panel=overlay(title)
  panel.size=Vector2(895,460); center_panel(panel)
 panel.set_meta("region_picker",true)
 var scroll=ScrollContainer.new()
 scroll.position=Vector2(18,host.ui_metrics.hit+18) if is_android else Vector2(20,72)
 scroll.size=Vector2(panel.size.x-36,panel.size.y-scroll.position.y-host.ui_metrics.hit-22) if is_android else Vector2(855,308)
 scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED; panel.add_child(scroll)
 var row=HBoxContainer.new(); row.add_theme_constant_override("separation",12); row.size_flags_horizontal=Control.SIZE_EXPAND_FILL; row.alignment=BoxContainer.ALIGNMENT_CENTER; scroll.add_child(row); region_tiles={}
 for atom in atoms:
  var c=engine.find_card(atom.value.uid)
  var card_width=116.0 if is_android else 142.0
  var card_height=145.0 if is_android else 198.0
  var card_top=28.0 if is_android else 33.0
  var tile=Control.new(); tile.custom_minimum_size=Vector2(card_width,212 if is_android else 292); row.add_child(tile)
  var zone_title=txt((player_caption(c.owner)+" · ")+ZONE_NAMES[c.zone],Rect2(0,0,card_width,25 if is_android else 28),16,host.GOLD,tile)
  zone_title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
  var art=card_tile(tile,c,Rect2(0,card_top,card_width,card_height),func(): select_region_atom(atom))
  art.set_meta("region_uid",c.uid)
  art.gui_input.connect(func(event):
   if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_RIGHT: inspect_card(c.card_id,c.uid))
  var name=txt(engine.cards[c.card_id].name,Rect2(0,card_top+card_height+5,card_width,32 if is_android else 54),15,host.WHITE,tile)
  name.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
  region_tiles[c.uid]=art
 if not batch_group.is_empty():
  var count_label=txt("",Rect2(22,panel.size.y-host.ui_metrics.hit-12 if is_android else 396,panel.size.x-290 if is_android else 575,32),17,host.GOLD,panel)
  count_label.name="RegionCount"
 var confirm=btn("确定",Rect2(panel.size.x-260,panel.size.y-host.ui_metrics.hit-14,240,host.ui_metrics.hit) if is_android else Rect2(624,392,243,48),confirm_region_atom,true,panel)
 confirm.name="RegionConfirm"
 update_region_styles()
func select_region_atom(atom: Dictionary):
 if observing: return
 var group=region_batch_group()
 if group.is_empty():region_selected=atom if region_selected!=atom else {}
 elif atom in region_batch:region_batch.erase(atom)
 elif picker.dynamic_state().current.size()+region_batch.size()<int(group.max):region_batch.append(atom)
 update_region_styles()
func update_region_styles():
 for uid in region_tiles:
  var selected=region_selected.get("value",{}).get("uid",-1)==uid or region_batch.any(func(atom):return atom.value.uid==uid)
  var style=host.style(Color("#172936"),Color("#ffd65c") if selected else Color("#359bff")); style.set_border_width_all(4)
  region_tiles[uid].add_theme_stylebox_override("panel",style)
 var root_panel=android_choice_panel if is_android else modal_root
 if is_instance_valid(root_panel):
  var confirm=root_panel.find_child("RegionConfirm",true,false)
  if confirm:
   var group=region_batch_group()
   if not group.is_empty():
    var count=picker.dynamic_state().current.size()+region_batch.size()
    var count_label=root_panel.find_child("RegionCount",true,false)
    if count_label:count_label.text="点击卡牌多选 · 已选 %d / 最多 %d 张" % [count,int(group.max)]
    confirm.disabled=count<int(group.min) or count>int(group.max)
    confirm.text="确认选择（%d）" % count if count>0 else "跳过此项"
    return
   var finish=picker.available().filter(func(a): return a.kind=="finish_group")
   confirm.disabled=region_selected.is_empty() and finish.is_empty()
   confirm.text=finish[0].value if region_selected.is_empty() and not finish.is_empty() else "确定"
func confirm_region_atom():
 if observing: return
 var group=region_batch_group()
 if not group.is_empty():
  var count=picker.dynamic_state().current.size()+region_batch.size()
  if count<int(group.min) or count>int(group.max):return
  for atom in region_batch:
   if not picker.select(atom):return
  var finish=picker.available().filter(func(a):return a.kind=="finish_group")
  if finish.is_empty():return
  picker.select(finish[0]);region_batch=[];region_batch_key="";region_selected={}
  if not local.is_empty():local.target=picker.option()
  render();return
 if region_selected.is_empty():
  for a in picker.available():
   if a.kind=="finish_group": inline_pick(a); return
  return
 var atom=region_selected.duplicate(true); region_selected={}
 inline_pick(atom)

func center_panel(panel: Control):
 panel.position=host.ui_metrics.safe.position+(host.ui_metrics.safe.size-panel.size)*0.5
 if panel.has_node("DialogTitle"): panel.get_node("DialogTitle").size.x=panel.size.x-60


func can_begin_debug_drag() -> bool:
 return debug_mode and not observing and not history_open and not modal and local.is_empty() and engine.pending.is_empty() and engine.phase!="mulligan" and not table.combat_animating


func can_use_region_card(c: Dictionary) -> bool:
 if network_locked():return false
 if c.owner!=acting_player() and not engine.Pack.cast_from(engine,c,acting_player()) or response_disabled(): return false
 return engine.cast_error(acting_player(),c.uid).is_empty() or not engine.extra_action(c).is_empty() and engine.extension_activation_error(c.owner,c).is_empty()


func region_action_cards(who: int,zone: String) -> Array:
 if who!=acting_player() or response_disabled(): return []
 var pool=engine.players[who][zone].duplicate()
 if network_session!=null and zone=="deck":
  pool=(engine.queries.get("legal",[])+engine.queries.get("deck_actions",[])).map(func(uid):return engine.find_card(uid)).filter(func(c):return c.zone=="deck")
 if zone=="exile": pool.append_array(engine.players[1-who].exile.filter(func(c): return engine.Pack.cast_from(engine,c,who)))
 return pool.filter(func(c): return can_use_region_card(c))


func available_hand_zones(who: int) -> Array:
 var zones=["hand"]
 for zone in ["grave","exile","deck","palette"]:
  if not region_action_cards(who,zone).is_empty(): zones.append(zone)
 return zones


func displayed_hand_cards(who: int) -> Array:
 var zones=available_hand_zones(who)
 if hand_zones[who] not in zones: hand_zones[who]="hand"
 return engine.players[who].hand if hand_zones[who]=="hand" else region_action_cards(who,hand_zones[who])


func render_hand_zone_tabs():
 hand_zone_tabs={}
 for who in [0,1]:
  if who!=local_seat and not debug_mode: continue
  var zones=available_hand_zones(who)
  if hand_zones[who] not in zones: hand_zones[who]="hand"
  if zones.size()<2: continue
  for i in range(zones.size()):
   var zone=zones[i]
   var tab_width=maxf(112,host.ui_metrics.body*4.5)
   var at=Vector2(HAND.position.x+i*(tab_width+host.ui_metrics.gap),PROMPT.position.y-host.ui_metrics.hit-host.ui_metrics.gap) if who==local_seat else Vector2(560+i*119,52)
   var title=ZONE_NAMES[zone]
   var button=btn(title,Rect2(at,Vector2(tab_width,host.ui_metrics.hit)),func(): hand_zones[who]=zone; render(),hand_zones[who]==zone)
   button.set_meta("hand_zone",zone); button.set_meta("hand_zone_owner",who)
   hand_zone_tabs[str(who)+":"+zone]=button


func begin_attack_payment(uid: int):
 local={"uid":uid,"action":"attack","mode":"payment","target":{},"plan":[]}
 selection=[];picker.reset();refresh_payment_plan()
 if local_cost().values().all(func(n):return n==0):commit_local()
 else:render()
func render_floating_resources():
 var pool=payment_sources().filter(func(r):return r.get("kind","")=="floating")
 if pool.is_empty():return
 var scroll=ScrollContainer.new();var rect=right_rect(Rect2(1330,480,237,118));scroll.position=rect.position;scroll.size=rect.size;hud.add_child(scroll)
 if is_android:
  scroll.position=Vector2(1120,480)
  scroll.size=Vector2(218,118)
 var rows=VBoxContainer.new();rows.size_flags_horizontal=Control.SIZE_EXPAND_FILL;scroll.add_child(rows)
 for resource in pool:
  var button=Button.new();button.text="%s 1%s" % [resource.colors[0]," ✓" if local.plan.any(func(p):return p.uid==resource.uid) else ""]
  button.custom_minimum_size=Vector2(165,34);rows.add_child(button);button.pressed.connect(func():reserve_resource(resource.uid))
  var ink=Color("#ffd65c") if local.plan.any(func(p):return p.uid==resource.uid) else Color("#359bff")
  button.add_theme_stylebox_override("normal",host.style(Color("#172936"),ink))

func player_caption(who: int) -> String:
 return engine.player_names[who] if network_session!=null else ("你" if who==0 else "试验 AI" if experiment_agent.enabled else "人机")

func layout_inspection(bg: Control,image: TextureRect,title: Label):
 if not is_android:return
 var width=minf(620,host.ui_metrics.safe.size.x*0.42)
 inspection.position=Vector2(host.ui_metrics.safe.position.x,host.ui_metrics.safe.position.y+host.ui_metrics.hit+host.ui_metrics.gap)
 inspection.size=Vector2(width,host.ui_metrics.safe.size.y-host.ui_metrics.hit-host.ui_metrics.gap)
 var backing=host.box(bg,Rect2(Vector2.ZERO,inspection.size),Color("#101c28"))
 bg.move_child(backing,0)
 image.position=Vector2(16,16);image.size=Vector2(width*0.43,inspection.size.y*0.48)
 title.position=Vector2(image.size.x+32,host.ui_metrics.hit+24);title.size=Vector2(width-title.position.x-16,host.ui_metrics.body*4)
 for child in bg.get_children():
  if child.get_script()==HexCost:child.position=Vector2(title.position.x,title.position.y+title.size.y+8)
 inspection_text.position=Vector2(16,image.size.y+32);inspection_text.size=Vector2(width-32,inspection.size.y-inspection_text.position.y-16)
 inspection_text.add_theme_font_size_override("normal_font_size",host.ui_metrics.body)
 var close=host.button(bg,"关闭详情",Rect2(width-180,16,164,host.ui_metrics.hit),func():inspect_id="";update_inspection())
 host.ui_metrics.button(close)
