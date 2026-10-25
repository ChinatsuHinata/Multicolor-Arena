extends Control
## Draw a refined gold coin icon with metallic gradient and depth.
static var textures: Dictionary={}

static func texture(extent: int) -> Texture2D:
 if textures.has(extent):return textures[extent]
 var svg='<svg xmlns="http://www.w3.org/2000/svg" width="32" height="32" viewBox="0 0 32 32"><circle cx="16" cy="16" r="14.72" fill="#a67c1b"/><circle cx="14.72" cy="17.28" r="13.6" fill="#f4d17e"/><circle cx="16" cy="16" r="13.6" fill="#e8c77e"/><circle cx="17.28" cy="14.72" r="12.48" fill="#d4b86e"/><rect x="13.76" y="13.76" width="4.48" height="4.48" fill="#5a3a0f"/></svg>'
 var image=Image.new()
 image.load_svg_from_string(svg,float(maxi(1,extent))/32.0)
 textures[extent]=ImageTexture.create_from_image(image)
 return textures[extent]

func _notification(what):
 if what==NOTIFICATION_RESIZED:queue_redraw()

func _draw():
 var radius=minf(size.x,size.y)*0.5
 var center=size*0.5
 # 外圈深色描边
 draw_circle(center,radius*0.92,Color("#a67c1b"),true,-1,true)
 # 主体金色带光泽
 draw_circle(center+Vector2(-radius*0.08,radius*0.08),radius*0.85,Color("#f4d17e"),true,-1,true)
 draw_circle(center,radius*0.85,Color("#e8c77e"),true,-1,true)
 # 内圈阴影加深
 draw_circle(center+Vector2(radius*0.08,-radius*0.08),radius*0.78,Color("#d4b86e"),true,-1,true)
 # 方孔（正方形）
 var hole=radius*0.28
 draw_rect(Rect2(center.x-hole*0.5,center.y-hole*0.5,hole,hole),Color("#5a3a0f"),true)
