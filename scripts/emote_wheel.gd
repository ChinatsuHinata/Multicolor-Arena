extends Control
## Five actual pie sectors; the empty centre is a cancel target.
signal selected(kind: String)
signal dismissed
const Palette=preload("res://scripts/ui_palette.gd")
const Icon=preload("res://scripts/emote_icon.gd")
const KINDS=["greeting","praise","surprise","mistake","threat"]
const CAPTIONS=["问候","称赞","惊讶","犯错","威胁"]
const SECTOR_ANGLE=TAU/5.0
var hovered=-1
var pressed_sector=-2
var keyboard_sector=0
var touch_index=-1

func _init():
 name="LeaderEmoteWheel"
 size=Vector2(330,330)
 custom_minimum_size=Vector2(260,260)
 mouse_filter=Control.MOUSE_FILTER_STOP
 focus_mode=Control.FOCUS_ALL
 mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND

func _ready():
 mouse_exited.connect(func():hovered=-1;queue_redraw())
 focus_entered.connect(queue_redraw)
 focus_exited.connect(queue_redraw)

func radius() -> float:return minf(size.x,size.y)*0.5-5.0
func inner_radius() -> float:return radius()*0.27

func sector_at(point: Vector2) -> int:
 var offset=point-size*0.5
 if offset.length()>radius():return -2
 if offset.length()<inner_radius():return -1
 return int(floor(fposmod(offset.angle()+PI*0.5+SECTOR_ANGLE*0.5,TAU)/SECTOR_ANGLE))%5

func sector_center(index: int) -> Vector2:
 return size*0.5+Vector2.from_angle(-PI*0.5+index*SECTOR_ANGLE)*radius()*0.65

func _has_point(point: Vector2) -> bool:return point.distance_to(size*0.5)<=radius()+4.0

func _get_tooltip(at: Vector2) -> String:
 var sector=sector_at(at)
 return CAPTIONS[sector]+"（"+str(sector+1)+"）" if sector>=0 else "关闭表情轮盘（Esc）" if sector==-1 else ""

func _notification(what):
 if what==NOTIFICATION_RESIZED:queue_redraw()

func activate(index: int):
 if index>=0 and index<KINDS.size():selected.emit(KINDS[index])
 elif index==-1:dismissed.emit()

func _gui_input(event: InputEvent):
 if event is InputEventMouseMotion:
  hovered=sector_at(event.position);queue_redraw();accept_event()
 elif event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
  var current=sector_at(event.position)
  if event.pressed:pressed_sector=current;grab_focus()
  else:
   if current==pressed_sector:activate(current)
   pressed_sector=-2
  hovered=current;queue_redraw();accept_event()
 elif event is InputEventScreenTouch:
  if event.pressed and touch_index==-1:
   touch_index=event.index;pressed_sector=sector_at(event.position);hovered=pressed_sector;grab_focus()
  elif not event.pressed and event.index==touch_index:
   var current=sector_at(event.position)
   if not event.canceled and current==pressed_sector:activate(current)
   touch_index=-1;pressed_sector=-2;hovered=-1
  queue_redraw();accept_event()
 elif event is InputEventScreenDrag and event.index==touch_index:
  hovered=sector_at(event.position);queue_redraw();accept_event()
 elif event is InputEventKey and event.pressed and not event.echo:
  if event.keycode==KEY_ESCAPE: dismissed.emit()
  elif event.keycode in [KEY_LEFT,KEY_UP]:keyboard_sector=posmod(keyboard_sector-1,5);hovered=-1
  elif event.keycode in [KEY_RIGHT,KEY_DOWN,KEY_TAB]:keyboard_sector=posmod(keyboard_sector+(-1 if event.shift_pressed else 1),5);hovered=-1
  elif event.keycode in [KEY_ENTER,KEY_KP_ENTER,KEY_SPACE]:activate(keyboard_sector)
  elif event.keycode>=KEY_1 and event.keycode<=KEY_5:activate(event.keycode-KEY_1)
  else:return
  queue_redraw();accept_event()

func wedge(index: int) -> PackedVector2Array:
 var center=size*0.5
 var start=-PI*0.5+index*SECTOR_ANGLE-SECTOR_ANGLE*0.5+0.016
 var end=start+SECTOR_ANGLE-0.032
 var points=PackedVector2Array()
 for step in range(25):points.append(center+Vector2.from_angle(lerpf(start,end,float(step)/24))*radius())
 for step in range(24,-1,-1):points.append(center+Vector2.from_angle(lerpf(start,end,float(step)/24))*inner_radius())
 return points

func _draw():
 var center=size*0.5
 var outer=radius()
 draw_circle(center+Vector2(0,4),outer+4,Color(0.06,0.03,0.07,0.4),true,-1,true)
 var border=Palette.tint(Color("#637a93"))
 var font=get_theme_default_font()
 var font_size=maxi(15,int(outer*0.105))
 for index in range(KINDS.size()):
  var hot=hovered==index or (hovered<0 and has_focus() and keyboard_sector==index)
  var points=wedge(index)
  draw_colored_polygon(points,Palette.tint(Color("#4b4130") if hot else Color("#172936")))
  var outline=points.duplicate();outline.append(points[0])
  draw_polyline(outline,Palette.tint(Color("#e8c77e")) if hot else border,2.0 if hot else 1.0,true)
  var point=sector_center(index)
  Icon.draw_on(self,KINDS[index],point-Vector2(0,9),outer*0.16)
  var text_size=font.get_string_size(CAPTIONS[index],HORIZONTAL_ALIGNMENT_LEFT,-1,font_size)
  draw_string(font,point+Vector2(-text_size.x*0.5,outer*0.24),CAPTIONS[index],HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,Palette.tint(Color("#e8edf0")))
 draw_circle(center,inner_radius()-2,Palette.tint(Color("#101c28")),true,-1,true)
 draw_arc(center,inner_radius()-2,0,TAU,60,border,1.0,true)
 var x_radius=outer*0.043
 var x_color=Palette.tint(Color("#b2c2ce"))
 draw_line(center-Vector2.ONE*x_radius,center+Vector2.ONE*x_radius,x_color,2.5,true)
 draw_line(center+Vector2(-x_radius,x_radius),center+Vector2(x_radius,-x_radius),x_color,2.5,true)
