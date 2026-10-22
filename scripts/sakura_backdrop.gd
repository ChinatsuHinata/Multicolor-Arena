extends Control
## PC menu backdrop: night shrine, moon, torii silhouette and drifting sakura petals.
const Palette=preload("res://scripts/ui_palette.gd")
const PETALS=46
var petals: Array=[]
var rng=RandomNumberGenerator.new()

func _ready():
 mouse_filter=Control.MOUSE_FILTER_IGNORE
 set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 rng.seed=20261021
 for i in range(PETALS):petals.append(new_petal(true))

func new_petal(anywhere: bool) -> Dictionary:
 var area=size if size.x>0 else Vector2(1600,900)
 return {
  "pos":Vector2(rng.randf_range(-60,area.x),rng.randf_range(-40,area.y) if anywhere else rng.randf_range(-80,-12)),
  "speed":rng.randf_range(22,52),"drift":rng.randf_range(10,34),"phase":rng.randf_range(0,TAU),
  "spin":rng.randf_range(-1.6,1.6),"angle":rng.randf_range(0,TAU),"scale":rng.randf_range(0.55,1.25),
  "tone":rng.randf_range(0,1),
 }

func _process(delta: float):
 if not is_visible_in_tree():return
 var limit=size+Vector2(60,40)
 for i in range(petals.size()):
  var p=petals[i]
  p.phase+=delta*0.9
  p.pos+=Vector2(p.drift+sin(p.phase)*18.0,p.speed)*delta
  p.angle+=p.spin*delta
  if p.pos.y>limit.y or p.pos.x>limit.x:petals[i]=new_petal(false)
 queue_redraw()

func _draw():
 var w=size.x;var h=size.y
 # Dusk sky: rose above, violet toward the horizon.
 var bands=24
 for i in range(bands):
  var t=float(i)/bands
  draw_rect(Rect2(0,h*t,w,h/bands+1),Color("#6a3c5c").lerp(Color("#3a2848"),t))
 # Moon with a soft halo.
 var moon=Vector2(w*0.8,h*0.2)
 for i in range(14):draw_circle(moon,150-i*7,Color(0.98,0.82,0.86,0.012+i*0.002))
 draw_circle(moon,56,Color("#f6e3e6"))
 draw_circle(moon+Vector2(12,-6),50,Color(0.95,0.78,0.83,0.35))
 # Distant hills.
 var hills=PackedVector2Array([Vector2(0,h)])
 for i in range(33):
  var x=w*i/32.0
  hills.append(Vector2(x,h*0.78-sin(i*0.55)*h*0.035-sin(i*1.7)*h*0.012))
 hills.append(Vector2(w,h))
 draw_colored_polygon(hills,Color("#3a2440"))
 draw_torii(Vector2(w*0.66,h*0.86),h*0.42)
 # Ground mist.
 for i in range(8):draw_rect(Rect2(0,h*0.84+i*h*0.02,w,h*0.02),Color(0.25,0.15,0.22,0.12+i*0.05))
 # Petals.
 for p in petals:draw_petal(p)
 # Vignette.
 for i in range(10):
  var inset=float(i)*10.0
  draw_rect(Rect2(inset,inset,w-inset*2,h-inset*2),Color(0.12,0.05,0.1,0.03),false,10.0)

func draw_torii(base: Vector2,height: float):
 var ink=Color("#3a1218")
 var red=Color(0.78,0.22,0.2,0.72)
 var span=height*0.95
 var post_w=height*0.055
 for side in [-1,1]:
  var x=base.x+side*span*0.36
  draw_rect(Rect2(x-post_w*0.5,base.y-height*0.78,post_w,height*0.78),red)
 draw_rect(Rect2(base.x-span*0.44,base.y-height*0.62,span*0.88,height*0.045),red)
 # Kasagi: the curved top beam.
 var top=PackedVector2Array()
 for i in range(17):
  var t=float(i)/16.0
  var x=base.x-span*0.58+span*1.16*t
  top.append(Vector2(x,base.y-height*0.86-pow(2.0*t-1.0,2.0)*height*0.06))
 for i in range(16,-1,-1):
  var t=float(i)/16.0
  var x=base.x-span*0.54+span*1.08*t
  top.append(Vector2(x,base.y-height*0.78-pow(2.0*t-1.0,2.0)*height*0.04))
 draw_colored_polygon(top,red)
 draw_rect(Rect2(base.x-height*0.03,base.y-height*0.78,height*0.06,height*0.16),Color(ink,0.6))

func draw_petal(p: Dictionary):
 var s=7.0*p.scale
 var tint=Palette.SAKURA.lerp(Color("#ffe6ee"),p.tone)
 tint.a=0.55+0.3*p.tone
 var xf=Transform2D(p.angle,p.pos)
 var shape=PackedVector2Array()
 for i in range(10):
  var a=TAU*i/10.0
  # A notched teardrop reads as a sakura petal at this size.
  var r=s*(1.0-0.28*pow(cos(a*0.5),8.0))
  shape.append(xf*Vector2(cos(a)*r*1.25,sin(a)*r*0.72))
 draw_colored_polygon(shape,tint)
