extends Control
## Chinese-style yellow and black warning triangle beside the life total.
const ICON_SIZE=Vector2(22,20)
const GAP=4.0
const MAX_VISIBLE=4
func _ready():
 mouse_filter=Control.MOUSE_FILTER_PASS
func _draw():
 var width=minf(size.x-3.0,(size.y-3.0)*2.0/sqrt(3.0))
 var height=width*sqrt(3.0)*0.5
 var top=(size.y-height)*0.5
 var center=size.x*0.5
 var points=PackedVector2Array([Vector2(center,top),Vector2(center-width*0.5,top+height),Vector2(center+width*0.5,top+height)])
 draw_colored_polygon(points,Color("#ffd800"))
 draw_polyline(PackedVector2Array([points[0],points[1],points[2],points[0]]),Color.BLACK,1.3,true)
 draw_line(Vector2(center,top+height*0.40),Vector2(center,top+height*0.65),Color.BLACK,1.8,true)
 draw_circle(Vector2(center,top+height*0.81),1.0,Color.BLACK)
