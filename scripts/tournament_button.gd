extends Button
## A trophy drawn at native touch size, without a symbol-font dependency.
func _draw():
 var unit=minf(size.x,size.y)*0.52
 var origin=(size-Vector2(unit,unit))*0.5
 var color=Color("#e8c77e")
 var stroke=maxf(2.0,unit*0.055)
 var bowl=PackedVector2Array([origin+Vector2(unit*0.2,0),origin+Vector2(unit*0.8,0),origin+Vector2(unit*0.72,unit*0.48),origin+Vector2(unit*0.5,unit*0.62),origin+Vector2(unit*0.28,unit*0.48),origin+Vector2(unit*0.2,0)])
 draw_polyline(bowl,color,stroke,true)
 for side in [-1,1]:
  var edge=origin+Vector2(unit*(0.5+side*0.3),unit*0.12)
  draw_polyline(PackedVector2Array([edge,edge+Vector2(side*unit*0.18,0),edge+Vector2(side*unit*0.15,unit*0.24),edge+Vector2(0,unit*0.3)]),color,stroke,true)
 draw_line(origin+Vector2(unit*0.5,unit*0.62),origin+Vector2(unit*0.5,unit*0.92),color,stroke,true)
 draw_line(origin+Vector2(unit*0.24,unit*0.95),origin+Vector2(unit*0.76,unit*0.95),color,stroke,true)
