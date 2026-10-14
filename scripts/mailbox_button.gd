extends Button
## Draw the envelope at any touch size without depending on a symbol font.
var unread=0:
 set(value):
  unread=value
  tooltip_text="公告邮箱 · %d 条未读" % unread if unread>0 else "公告邮箱"
  queue_redraw()

func _draw():
 var width=minf(size.x,size.y)*0.55
 var rect=Rect2((size-Vector2(width,width*0.68))*0.5,Vector2(width,width*0.68))
 var color=Color("#e8c77e")
 var stroke=maxf(2.0,width*0.05)
 draw_rect(rect,color,false,stroke)
 var fold=Vector2(rect.get_center().x,rect.position.y+rect.size.y*0.58)
 draw_polyline(PackedVector2Array([rect.position,fold,Vector2(rect.end.x,rect.position.y)]),color,stroke,true)
 if unread>0:
  draw_circle(Vector2(rect.end.x+2,rect.position.y-2),maxf(5.0,width*0.14),Color("#f16d69"),true,-1,true)
