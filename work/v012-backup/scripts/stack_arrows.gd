extends Control
var view
var arrows: Array=[]
func _process(_delta):
 if not is_instance_valid(view) or view.engine==null: return
 arrows=view.stack_target_arrows()
 queue_redraw()
func _draw():
 for arrow in arrows:
  var from: Vector2=arrow.from
  var to: Vector2=arrow.to
  var delta=to-from
  if delta.length()<12: continue
  var bend=(from+to)*0.5+Vector2(delta.y,-delta.x).normalized()*minf(65,delta.length()*0.16)
  var points=PackedVector2Array()
  for i in range(33):
   var t=i/32.0
   points.append((1-t)*(1-t)*from+2*(1-t)*t*bend+t*t*to)
  draw_polyline(points,Color(0.03,0.05,0.08,0.85),7,true)
  draw_polyline(points,Color("#f5d379"),3,true)
  var direction=(to-bend).normalized()
  var normal=Vector2(-direction.y,direction.x)
  draw_colored_polygon(PackedVector2Array([to,to-direction*17+normal*7,to-direction*17-normal*7]),Color("#ffe8a2"))
