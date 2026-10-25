extends Control
## Crop the original leader art, then compose a speech bubble at UI resolution.
var portrait: Texture2D
var region=Rect2()
var accent=Color.WHITE
var centered=false

func composition_rect() -> Rect2:
 var width=minf(size.x,size.y*1.45) if centered else size.x
 return Rect2((size.x-width)*0.5,0,width,size.y)

func configure(item: Dictionary):
 mouse_filter=Control.MOUSE_FILTER_IGNORE
 portrait=load(str(item.image)) as Texture2D
 var crop=item.portrait_region
 region=Rect2(float(crop[0]),float(crop[1]),float(crop[2]),float(crop[3]))
 accent=Color(str(item.get("accent","e98a9e")))
 resized.connect(queue_redraw)
 queue_redraw()

func bubble_rect() -> Rect2:
 var frame=composition_rect()
 return Rect2(frame.position.x+frame.size.x*0.66,8,frame.size.x*0.34-3,minf(42,size.y*0.35))

func image_rect() -> Rect2:
 var frame=composition_rect()
 var side=minf(size.y-8,frame.size.x*0.82)
 return Rect2(frame.position.x+3,size.y-side-3,side,side)

func _draw():
 if portrait==null:return
 var frame=image_rect()
 var style=StyleBoxFlat.new();style.bg_color=accent;style.set_corner_radius_all(12)
 draw_style_box(style,frame.grow(3))
 draw_texture_rect_region(portrait,frame,region)
 var bubble=bubble_rect()
 style=StyleBoxFlat.new();style.bg_color=Color("fff7ef");style.border_color=accent
 style.set_border_width_all(2);style.set_corner_radius_all(13)
 draw_style_box(style,bubble)
 var tail=PackedVector2Array([Vector2(bubble.position.x+14,bubble.end.y-2),Vector2(bubble.position.x+3,bubble.end.y+14),Vector2(bubble.position.x+34,bubble.end.y-2)])
 draw_colored_polygon(tail,style.bg_color);draw_polyline(tail,accent,2,true)
