extends TextureRect
## The same aspect-preserving thumbnail and enlarged view in authoring and play.
var preview_root: Control
var host
var overlay: Control
var touch_finger=-1
var touch_origin=Vector2.ZERO
var touch_dragged=false
var suppress_mouse_until=0

func configure(owner_control: Control,app,image: Texture2D):
 preview_root=owner_control;host=app;texture=image
 expand_mode=TextureRect.EXPAND_IGNORE_SIZE;stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
 texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR;size_flags_horizontal=Control.SIZE_EXPAND_FILL
 mouse_filter=Control.MOUSE_FILTER_STOP;mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
 tooltip_text="点击放大配图"
 gui_input.connect(func(event):
  if event is InputEventScreenTouch and event.pressed:
   touch_finger=event.index;touch_origin=get_global_transform_with_canvas()*event.position;touch_dragged=false;accept_event()
  elif event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.pressed:
   accept_event()
   if touch_finger<0 and Time.get_ticks_msec()>=suppress_mouse_until:open_preview())

func open_preview():
 if texture==null or not is_visible_in_tree() or is_instance_valid(overlay):return
 overlay=Control.new();overlay.name="TutorialImageOverlay";preview_root.add_child(overlay)
 overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);overlay.z_index=400;overlay.mouse_filter=Control.MOUSE_FILTER_STOP
 var shade=ColorRect.new();overlay.add_child(shade);shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);shade.color=Color(0,0,0,0.92)
 var margin=MarginContainer.new();overlay.add_child(margin);margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 for edge in ["left","right","top","bottom"]:margin.add_theme_constant_override("margin_"+edge,16)
 var column=VBoxContainer.new();margin.add_child(column)
 var header=HBoxContainer.new();column.add_child(header)
 var title=Label.new();header.add_child(title);title.text="节点配图";title.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 title.add_theme_font_size_override("font_size",host.ui_metrics.body)
 var close=host.button(header,"关闭",Rect2(),close_preview);close.name="CloseTutorialImagePreview";host.ui_metrics.button(close)
 var art=TextureRect.new();art.name="TutorialImageFullSize";column.add_child(art);art.texture=texture
 art.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;art.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
 art.size_flags_vertical=Control.SIZE_EXPAND_FILL;art.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
 art.mouse_filter=Control.MOUSE_FILTER_IGNORE
 close.grab_focus()

func close_preview():
 touch_finger=-1
 if is_instance_valid(overlay):overlay.get_parent().remove_child(overlay);overlay.queue_free()
 overlay=null

func _input(event: InputEvent):
 if touch_finger>=0:
  if event is InputEventScreenDrag and event.index==touch_finger:
   if event.position.distance_to(touch_origin)>12:touch_dragged=true
  elif event is InputEventScreenTouch and not event.pressed and event.index==touch_finger:
   touch_finger=-1;suppress_mouse_until=Time.get_ticks_msec()+250
   if not touch_dragged and event.position.distance_to(touch_origin)<=12:
    open_preview();get_viewport().set_input_as_handled()
 if is_instance_valid(overlay) and event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE:
  close_preview();get_viewport().set_input_as_handled()

func _notification(what: int):
 if what in [NOTIFICATION_WM_WINDOW_FOCUS_OUT,NOTIFICATION_APPLICATION_PAUSED]:touch_finger=-1

func _exit_tree():
 # A scene switch can remove our root and its children in the same traversal.
 if is_instance_valid(overlay):overlay.hide();overlay.queue_free()
 overlay=null
