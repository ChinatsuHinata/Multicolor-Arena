extends Control
## Small road-warning triangle beside the affected player's life total.
func _ready():
 mouse_filter=Control.MOUSE_FILTER_PASS
func _draw():
 var points=PackedVector2Array([Vector2(size.x*0.5,1),Vector2(1,size.y-1),Vector2(size.x-1,size.y-1)])
 draw_colored_polygon(points,Color("#fff5df"))
 draw_polyline(PackedVector2Array([points[0],points[1],points[2],points[0]]),Color("#ec5d61"),3.0,true)
 draw_line(Vector2(size.x*0.5,7),Vector2(size.x*0.5,size.y-9),Color("#222630"),2.6,true)
 draw_circle(Vector2(size.x*0.5,size.y-5),1.5,Color("#222630"))
