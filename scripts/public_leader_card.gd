extends PanelContainer
## Public leader artwork with read-only mouse/touch inspection.
const Inspection=preload("res://scripts/card_inspection.gd")
const Art=preload("res://scripts/card_art.gd")
var app
var card_id=""
var art_id=""
var picture: TextureRect
var overlay: Control
var popup: PanelContainer
var finger=-1
var origin=Vector2.ZERO
var hold_ring: Control
var suppress_mouse_until=0
var touch_surfaces=preload("res://scripts/android_card_touch.gd").new()

func _ready():
 name="OpponentLeaderCard"
 mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
 tooltip_text="长按 1 秒：查看详情" if app.is_android else "右键：查看详情"
 add_theme_stylebox_override("panel",app.style(Color("#142737"),app.GOLD))
 picture=TextureRect.new();picture.name="OpponentLeaderArt";add_child(picture)
 picture.texture=load(Art.image_path(card_id,art_id,app.Store.CARDS))
 picture.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
 picture.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
 picture.mouse_filter=Control.MOUSE_FILTER_IGNORE

func _gui_input(event: InputEvent):
 if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_RIGHT and event.pressed and Time.get_ticks_msec()>=suppress_mouse_until:
  show_details();accept_event()

func _input(event: InputEvent):
 if not app.is_android or not is_visible_in_tree():return
 if event is InputEventMouseButton or event is InputEventMouseMotion:
  if finger>=0 or Time.get_ticks_msec()<suppress_mouse_until and event.position.distance_to(origin)<28:get_viewport().set_input_as_handled()
  return
 if event is InputEventScreenTouch and event.pressed and not event.canceled:
  if finger>=0:cancel_hold();return
  if is_instance_valid(overlay) or touch_surfaces.surface_at(app.screen,event.position)!=self:return
  finger=event.index;origin=event.position
  hold_ring=preload("res://scripts/card_hold_ring.gd").new();hold_ring.position=origin
  hold_ring.valid=func():return is_visible_in_tree() and not is_queued_for_deletion() and finger>=0 and not is_instance_valid(overlay)
  get_viewport().add_child(hold_ring)
  hold_ring.completed.connect(show_details)
 elif event is InputEventScreenDrag and event.index==finger:
  if event.position.distance_to(origin)>12:cancel_hold()
 elif event is InputEventScreenTouch and event.index==finger:cancel_hold()
 else:return
 suppress_mouse_until=Time.get_ticks_msec()+250
 get_viewport().set_input_as_handled()

func cancel_hold():
 if is_instance_valid(hold_ring):hold_ring.queue_free()
 hold_ring=null;finger=-1

func _notification(what):
 if what in [NOTIFICATION_WM_WINDOW_FOCUS_OUT,NOTIFICATION_APPLICATION_PAUSED] or what==NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree():cancel_hold()

func show_details():
 cancel_hold()
 if is_instance_valid(overlay):return
 overlay=Control.new();overlay.name="OpponentLeaderDetails";app.screen.add_child(overlay)
 overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 var shade=ColorRect.new();shade.color=Color(0,0,0,0.8);overlay.add_child(shade)
 shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 shade.gui_input.connect(func(event):
  if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT:close_details())
 popup=PanelContainer.new();popup.name="OpponentLeaderPopup";overlay.add_child(popup)
 popup.add_theme_stylebox_override("panel",app.ui_metrics.panel_style())
 var safe=app.screen.get_global_rect().intersection(app.ui_metrics.safe).grow(-app.ui_metrics.padding)
 popup.size=Vector2(minf(1080,safe.size.x),minf(740,safe.size.y))
 popup.position=safe.get_center()-popup.size*0.5-app.screen.global_position
 var body=VBoxContainer.new();popup.add_child(body)
 var close=app.button(body,"关闭详情",Rect2(),close_details);app.ui_metrics.button(close)
 var panes=HBoxContainer.new();body.add_child(panes);Inspection.expand(panes,true)
 var art=Inspection.artwork(app,panes,card_id,{})
 art.texture=picture.texture
 Inspection.rules(app,panes,card_id,maxf(100,(popup.size.x-app.ui_metrics.padding*2-app.ui_metrics.gap)*0.5))

func close_details():
 if is_instance_valid(overlay):overlay.queue_free()
 overlay=null;popup=null

func _exit_tree():
 cancel_hold();close_details()
