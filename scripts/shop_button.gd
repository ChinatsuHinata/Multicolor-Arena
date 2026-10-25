extends Button
## A shop awning, drawn at the same native size as the other toolbar icons.

func _draw():
 draw_shop(self,Rect2(size*0.21,size*0.58),Color("#e8c77e"))

static func draw_shop(canvas: Control,area: Rect2,color: Color):
 var unit=minf(area.size.x,area.size.y)
 var origin=area.position+(area.size-Vector2.ONE*unit)*0.5
 var stroke=maxf(2.0,unit*0.055)
 var roof=PackedVector2Array([origin+Vector2(unit*0.12,unit*0.08),origin+Vector2(unit*0.88,unit*0.08),origin+Vector2(unit,unit*0.36),origin+Vector2(0,unit*0.36),origin+Vector2(unit*0.12,unit*0.08)])
 canvas.draw_polyline(roof,color,stroke,true)
 for i in range(4):
  var x=unit*(float(i)+0.5)/4.0
  canvas.draw_arc(origin+Vector2(x,unit*0.36),unit*0.125,0,PI,16,color,stroke,true)
 canvas.draw_polyline(PackedVector2Array([origin+Vector2(unit*0.08,unit*0.49),origin+Vector2(unit*0.08,unit*0.94),origin+Vector2(unit*0.92,unit*0.94),origin+Vector2(unit*0.92,unit*0.49)]),color,stroke,true)
 canvas.draw_rect(Rect2(origin+Vector2(unit*0.22,unit*0.59),Vector2(unit*0.22,unit*0.35)),color,false,stroke)
 canvas.draw_line(origin+Vector2(unit*0.59,unit*0.64),origin+Vector2(unit*0.78,unit*0.64),color,stroke,true)
