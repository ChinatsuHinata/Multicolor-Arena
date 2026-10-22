extends Control
const Palette=preload("res://scripts/ui_palette.gd")
var view
var arrows: Array=[]
func _process(_delta):
 if not is_instance_valid(view) or view.engine==null: return
 arrows=view.stack_target_arrows()
 queue_redraw()
func _draw():
 var sakura=Palette.enabled
 # Phones show the board smaller, so the target link is drawn heavier there.
 var weight=1.6 if view.is_android else 1.0
 var shade=Color(0.09,0.03,0.08,0.85) if sakura else Color(0.03,0.05,0.08,0.85)
 var stroke=Color("#ffb3c7") if sakura else Color("#f5d379")
 var head=Color("#ffe1ea") if sakura else Color("#ffe8a2")
 var clock=float(Time.get_ticks_msec())/1000.0
 for index in range(arrows.size()):
  var arrow=arrows[index]
  var from: Vector2=arrow.from
  var to: Vector2=arrow.to
  var delta=to-from
  if delta.length()<12: continue
  var bend=(from+to)*0.5+Vector2(delta.y,-delta.x).normalized()*minf(65,delta.length()*0.16)
  var points=PackedVector2Array()
  for i in range(33):
   var t=i/32.0
   points.append((1-t)*(1-t)*from+2*(1-t)*t*bend+t*t*to)
  var breath=0.5+0.5*sin(clock*TAU/1.4+index)
  draw_polyline(points,Color(stroke,0.12+0.1*breath),18*weight,true)
  draw_polyline(points,shade,7*weight,true)
  draw_polyline(points,stroke,3*weight,true)
  # Origin knot and a spark travelling toward the target.
  draw_circle(from,5*weight,shade);draw_circle(from,3*weight,Palette.VERMILION if sakura else stroke)
  var t=fmod(clock*0.75+index*0.23,1.0)
  var spark=(1-t)*(1-t)*from+2*(1-t)*t*bend+t*t*to
  draw_circle(spark,7*weight,Color(stroke,0.3));draw_circle(spark,3*weight,Color.WHITE)
  var direction=(to-bend).normalized()
  var normal=Vector2(-direction.y,direction.x)
  draw_colored_polygon(PackedVector2Array([to+direction*2*weight,to-direction*19*weight+normal*9*weight,to-direction*19*weight-normal*9*weight]),shade)
  draw_colored_polygon(PackedVector2Array([to,to-direction*17*weight+normal*7*weight,to-direction*17*weight-normal*7*weight]),head)
  if not arrow.get("valid",true):
   draw_circle(to,9,Palette.tint(Color("#101c28")))
   draw_line(to-Vector2(5,5),to+Vector2(5,5),Color("#ff8276"),3,true)
   draw_line(to+Vector2(-5,5),to+Vector2(5,-5),Color("#ff8276"),3,true)
