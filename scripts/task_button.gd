extends Button
## Draw an exclamation mark without relying on a symbol font.
var has_reward=false:
 set(value):
  has_reward=value;queue_redraw()
func _draw():
 var unit=minf(size.x,size.y)
 var center=size*0.5
 var color=Color("#e8c77e")
 draw_circle(center,unit*0.27,color,false,maxf(2.0,unit*0.035),true)
 draw_line(center+Vector2(0,-unit*0.15),center+Vector2(0,unit*0.025),color,maxf(3.0,unit*0.055),true)
 draw_circle(center+Vector2(0,unit*0.135),unit*0.032,color,true,-1,true)
 if has_reward:
  var dot=Vector2(size.x-unit*0.16,unit*0.16)
  draw_circle(dot,unit*0.105,Color("#e45858"),true,-1,true)
  draw_circle(dot,unit*0.105,Color("#fff1df"),false,maxf(1.0,unit*0.025),true)
