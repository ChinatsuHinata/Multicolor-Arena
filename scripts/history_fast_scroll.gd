extends Control
## A full-height history scrubber; a track press jumps instead of paging slowly.
var scroll: ScrollContainer
var bar: VScrollBar
var minimum_thumb=36.0
var finger=-1
var mouse_dragging=false
var grab_offset=0.0
var track_style: StyleBoxFlat
var thumb_style: StyleBoxFlat

static func attach(target: ScrollContainer,touch: bool,hit: float) -> Control:
 var control=load("res://scripts/history_fast_scroll.gd").new()
 control.name="HistoryFastScroll"
 control.scroll=target;control.bar=target.get_v_scroll_bar()
 var width=maxf(48.0,hit*0.7) if touch else 24.0
 target.size.x-=width+6.0
 target.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_SHOW_NEVER
 control.position=target.position+Vector2(target.size.x+6,0)
 control.size=Vector2(width,target.size.y)
 control.minimum_thumb=maxf(64.0,hit) if touch else 36.0
 target.get_parent().add_child(control)
 return control

func _ready():
 mouse_filter=Control.MOUSE_FILTER_STOP
 mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
 tooltip_text="拖动滑块或点按滑条，快速定位记录"
 track_style=StyleBoxFlat.new();track_style.bg_color=Color("#263b4d");track_style.set_corner_radius_all(8)
 thumb_style=StyleBoxFlat.new();thumb_style.bg_color=Color("#b8c9da");thumb_style.set_corner_radius_all(8)
 bar.changed.connect(sync_range)
 bar.value_changed.connect(func(_value):queue_redraw())
 sync_range()

func sync_range():
 visible=bar.max_value>bar.page+1.0
 if not visible:finger=-1;mouse_dragging=false
 queue_redraw()

func thumb_rect() -> Rect2:
 var height=clampf(size.y*bar.page/maxf(bar.max_value,1.0),minf(minimum_thumb,size.y),size.y)
 var fraction=bar.value/maxf(bar.max_value-bar.page,1.0)
 return Rect2(4,(size.y-height)*fraction,size.x-8,height)

func _draw():
 if not is_instance_valid(bar):return
 var thickness=maxf(8.0,size.x*0.25)
 draw_style_box(track_style,Rect2((size.x-thickness)/2,0,thickness,size.y))
 draw_style_box(thumb_style,thumb_rect())

func move_to(point: Vector2):
 var travel=size.y-thumb_rect().size.y
 if travel>0:bar.value=clampf((point.y-grab_offset)/travel,0,1)*(bar.max_value-bar.page)

func begin(point: Vector2):
 var thumb=thumb_rect()
 grab_offset=point.y-thumb.position.y if thumb.has_point(point) else thumb.size.y/2
 move_to(point)

func handle(event: InputEvent) -> bool:
 if not is_visible_in_tree():finger=-1;mouse_dragging=false;return false
 if event is InputEventScreenTouch:
  if event.pressed:
   if finger>=0 or mouse_dragging or not get_global_rect().has_point(event.position):return false
   finger=event.index;begin(get_global_transform().affine_inverse()*event.position)
  elif event.index==finger:finger=-1
  else:return false
 elif event is InputEventScreenDrag:
  if event.index!=finger:return false
  move_to(get_global_transform().affine_inverse()*event.position)
 elif event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
  if event.pressed:
   if finger>=0 or not get_global_rect().has_point(event.position):return false
   mouse_dragging=true;begin(get_global_transform().affine_inverse()*event.position)
  elif mouse_dragging:mouse_dragging=false
  else:return false
 elif event is InputEventMouseMotion and mouse_dragging:
  # Window activation/resize can emit hover motion during a captured drag.
  if not event.button_mask&MOUSE_BUTTON_MASK_LEFT:return false
  move_to(get_global_transform().affine_inverse()*event.position)
 else:return false
 get_viewport().set_input_as_handled()
 return true
