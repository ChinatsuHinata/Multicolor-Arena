extends Control
## Sakura dusk behind the transparent battle viewport.
const Palette=preload("res://scripts/ui_palette.gd")
const PETALS_DESKTOP=34
const PETALS_ANDROID=22
var petals: Array=[]
var rng=RandomNumberGenerator.new()

func _ready():
 mouse_filter=Control.MOUSE_FILTER_IGNORE
 set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 rng.seed=20261022
 var count=PETALS_ANDROID if OS.has_feature("android") else PETALS_DESKTOP
 for i in range(count):petals.append(new_petal(true))

func new_petal(anywhere: bool) -> Dictionary:
 return {
  "pos":Vector2(rng.randf_range(-40,size.x),rng.randf_range(-30,size.y) if anywhere else rng.randf_range(-60,-10)),
  "speed":rng.randf_range(14,34),"drift":rng.randf_range(6,22),"phase":rng.randf_range(0,TAU),
  "spin":rng.randf_range(-1.1,1.1),"angle":rng.randf_range(0,TAU),"scale":rng.randf_range(0.5,1.1),
  "tone":rng.randf_range(0,1),
 }

func _process(delta: float):
 if not is_visible_in_tree():return
 for i in range(petals.size()):
  var p=petals[i]
  p.phase+=delta*0.7
  p.pos+=Vector2(p.drift+sin(p.phase)*10.0,p.speed)*delta
  p.angle+=p.spin*delta
  if p.pos.y>size.y+30 or p.pos.x>size.x+50:petals[i]=new_petal(false)
 queue_redraw()

func _draw():
 var w=size.x;var h=size.y
 for i in range(48):
  var t=float(i)/(48-1)
  var c=Color("#100a16").lerp(Color("#43283f"),smoothstep(0.0,0.52,t))
  c=c.lerp(Color("#2a1626"),smoothstep(0.52,1.0,t))
  draw_rect(Rect2(0,h*t,w,h/48+1),c)
 # Warm light separates the table from the horizon.
 var glow=Vector2(w*0.5,h*0.52)
 for i in range(18):
  var rr=w*0.30-i*15
  if rr<=0.0:continue
  draw_circle(glow+Vector2(0,rr*0.42),rr,Color(0.58,0.26,0.34,0.006+i*0.0013))
 var moon=Vector2(w*0.79,h*0.15)
 for i in range(16):draw_circle(moon,132-i*6.5,Color(0.98,0.82,0.88,0.010+i*0.0018))
 draw_circle(moon,46,Color("#f7e6ea"))
 draw_circle(moon+Vector2(11,-5),41,Color(0.93,0.76,0.83,0.30))
 var hills=PackedVector2Array([Vector2(0,h)])
 for i in range(41):
  var x=w*i/40.0
  var y=h*0.30+sin(i*0.42)*h*0.020+sin(i*1.5)*h*0.008
  hills.append(Vector2(x,y))
 hills.append(Vector2(w,h))
 draw_colored_polygon(hills,Color(0.10,0.05,0.11,0.55))
 draw_torii(Vector2(w*0.19,h*0.315),h*0.20)
 for p in petals:draw_petal(p)
 for i in range(12):
  var inset=i*12.0
  draw_rect(Rect2(inset,inset,w-inset*2,h-inset*2),Color(0.05,0.02,0.06,0.022),false,14.0)

func draw_torii(base: Vector2,height: float):
 var red=Color(0.62,0.18,0.22,0.38)
 var span=height*0.95
 var post_width=height*0.05
 for side in [-1,1]:
  var x=base.x+side*span*0.34
  draw_rect(Rect2(x-post_width*0.5,base.y-height*0.72,post_width,height*0.72),red)
 draw_rect(Rect2(base.x-span*0.44,base.y-height*0.58,span*0.88,height*0.04),red)
 var beam=PackedVector2Array()
 for i in range(17):
  var t=float(i)/16.0
  beam.append(Vector2(base.x-span*0.58+span*1.16*t,base.y-height*0.80-pow(2.0*t-1.0,2.0)*height*0.05))
 for i in range(16,-1,-1):
  var t=float(i)/16.0
  beam.append(Vector2(base.x-span*0.54+span*1.08*t,base.y-height*0.74-pow(2.0*t-1.0,2.0)*height*0.03))
 draw_colored_polygon(beam,red)

func draw_petal(p: Dictionary):
 var s=5.0*p.scale
 var color=Palette.SAKURA.lerp(Color("#ffe6ee"),p.tone)
 color.a=0.16+0.16*p.tone
 var xf=Transform2D(p.angle,p.pos)
 var shape=PackedVector2Array()
 for i in range(10):
  var a=TAU*i/10.0
  var r=s*(1.0-0.28*pow(cos(a*0.5),8.0))
  shape.append(xf*Vector2(cos(a)*r*1.25,sin(a)*r*0.72))
 draw_colored_polygon(shape,color)
