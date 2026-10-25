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
 draw_moon(w,h)
 draw_hills(w,h)
 var base=Vector2(w*0.72,h*0.955)
 var th=h*0.86
 draw_shrine_glow(base,th)
 draw_torii(Vector2(w*0.545,h*0.80),h*0.26,Color(0.46,0.14,0.15,0.34),false)
 draw_terrace(base,th)
 draw_torii(base,th,Color(0.70,0.19,0.17,0.92),true)
 draw_mist(w,h)
 var lantern_scale=th*0.105
 var lantern_reach=th*0.95*0.36+th*0.075
 draw_lantern(Vector2(base.x-lantern_reach,base.y),lantern_scale)
 draw_lantern(Vector2(base.x+lantern_reach,base.y),lantern_scale)
 # Petals.
 for p in petals:draw_petal(p)
 draw_vignette(w,h)

func draw_torii(base: Vector2,height: float,red: Color,detail: bool):
 var span=height*0.95
 var post_w=height*0.058
 var post_top=base.y-height*0.775
 var shade=Color(0,0,0,red.a*0.40)
 var rim=Color(1.0,0.70,0.62,red.a*0.30)
 for side in [-1,1]:
  var x=base.x+side*span*0.36
  var wtop=post_w*0.84
  var poly=PackedVector2Array([
   Vector2(x-wtop*0.5,post_top),Vector2(x+wtop*0.5,post_top),
   Vector2(x+post_w*0.5,base.y),Vector2(x-post_w*0.5,base.y)])
  draw_colored_polygon(poly,red)
  if detail:
   # Shadowed inner face and a moonlit outer edge give the post volume.
   draw_rect(Rect2(x-side*wtop*0.5-wtop*0.22,post_top,wtop*0.26,base.y-post_top),shade)
   draw_rect(Rect2(x+side*post_w*0.5-post_w*0.16,post_top,post_w*0.16,base.y-post_top),rim)
   # Kamaki: the stone ring the post stands on.
   draw_rect(Rect2(x-post_w*0.70,base.y-height*0.030,post_w*1.40,height*0.030),Color(0.10,0.045,0.07,0.75))
   draw_rect(Rect2(x-post_w*0.70,base.y-height*0.030,post_w*1.40,height*0.008),Color(1.0,0.72,0.62,0.14))
 # Shimaki: the upper beam carried by the kasagi.
 var shim_y=base.y-height*0.735
 var shim_h=height*0.030
 draw_rect(Rect2(base.x-span*0.415,shim_y,span*0.83,shim_h),red)
 if detail:
  draw_rect(Rect2(base.x-span*0.415,shim_y+shim_h,span*0.83,height*0.009),Color(0.06,0.02,0.04,0.36))
  draw_rect(Rect2(base.x-span*0.415,shim_y,span*0.83,height*0.006),Color(1.0,0.70,0.60,0.20))
 # Nuki: the tie beam that runs through both posts.
 var nuki_y=base.y-height*0.620
 var nuki_h=height*0.048
 var nuki_half=span*0.455
 draw_rect(Rect2(base.x-nuki_half,nuki_y,nuki_half*2,nuki_h),red)
 if detail:
  draw_rect(Rect2(base.x-nuki_half,nuki_y+nuki_h,nuki_half*2,height*0.011),Color(0.06,0.02,0.04,0.38))
  draw_rect(Rect2(base.x-nuki_half,nuki_y,nuki_half*2,height*0.007),Color(1.0,0.70,0.60,0.22))
  for side in [-1,1]:
   var ex=base.x+side*nuki_half
   draw_rect(Rect2(ex-post_w*0.17,nuki_y-nuki_h*0.10,post_w*0.34,nuki_h*1.20),Color(0.08,0.03,0.05,0.42))
 # Kasagi: the curved top lintel, with a lit crown and shadowed underside.
 var band=PackedVector2Array()
 for i in range(29):
  var t=float(i)/28.0
  band.append(Vector2(base.x-span*0.575+span*1.15*t,base.y-height*0.855-pow(2.0*t-1.0,2.0)*height*0.060))
 for i in range(28,-1,-1):
  var t=float(i)/28.0
  band.append(Vector2(base.x-span*0.540+span*1.08*t,base.y-height*0.775-pow(2.0*t-1.0,2.0)*height*0.038))
 draw_colored_polygon(band,red)
 if detail:
  var crown=PackedVector2Array()
  for i in range(29):
   var t=float(i)/28.0
   crown.append(Vector2(base.x-span*0.575+span*1.15*t,base.y-height*0.855-pow(2.0*t-1.0,2.0)*height*0.060))
  for i in range(28,-1,-1):
   var t=float(i)/28.0
   crown.append(Vector2(base.x-span*0.571+span*1.142*t,base.y-height*0.843-pow(2.0*t-1.0,2.0)*height*0.0575))
  draw_colored_polygon(crown,Color(1.0,0.72,0.62,red.a*0.26))
  var under=PackedVector2Array()
  for i in range(29):
   var t=float(i)/28.0
   under.append(Vector2(base.x-span*0.540+span*1.08*t,base.y-height*0.775-pow(2.0*t-1.0,2.0)*height*0.038))
  for i in range(28,-1,-1):
   var t=float(i)/28.0
   under.append(Vector2(base.x-span*0.545+span*1.09*t,base.y-height*0.764-pow(2.0*t-1.0,2.0)*height*0.036))
  draw_colored_polygon(under,Color(0.06,0.02,0.04,red.a*0.42))
 # Gakuzuka: the name plaque between nuki and shimaki.
 var gw=height*0.046
 var gy=nuki_y+height*0.010
 var gh=shim_y-gy
 draw_rect(Rect2(base.x-gw*0.5,gy,gw,gh),Color(0.11,0.04,0.07,0.86 if detail else red.a*0.45))
 if detail:
  draw_rect(Rect2(base.x-gw*0.5,gy,gw,gh),Color(0.85,0.66,0.40,0.26),false,height*0.004)

func draw_terrace(base: Vector2,height: float):
 var span=height*0.95
 for i in range(3):
  var t=float(i)
  draw_rect(Rect2(base.x-span*(0.62-t*0.06),base.y-height*0.004+t*height*0.014,
   span*(1.24-t*0.12),height*0.014),Color(0.085,0.035,0.06,0.52+t*0.10))

func draw_shrine_glow(base: Vector2,height: float):
 var c=Vector2(base.x,base.y-height*0.66)
 for i in range(16):
  var r=height*(0.84-float(i)*0.048)
  draw_circle(c,r,Color(0.85,0.42,0.34,0.010))

func draw_lantern(base: Vector2,s: float):
 var ink=Color(0.13,0.055,0.085,0.86)
 draw_rect(Rect2(base.x-s*0.58,base.y-s*0.14,s*1.16,s*0.14),ink)
 draw_rect(Rect2(base.x-s*0.16,base.y-s*0.62,s*0.32,s*0.50),ink)
 draw_circle(Vector2(base.x,base.y-s*0.74),s*0.40,Color(1.0,0.72,0.38,0.14))
 draw_rect(Rect2(base.x-s*0.30,base.y-s*0.88,s*0.60,s*0.28),ink)
 draw_rect(Rect2(base.x-s*0.17,base.y-s*0.83,s*0.34,s*0.18),Color(1.0,0.83,0.52,0.66))
 var roof=PackedVector2Array([
  Vector2(base.x-s*0.54,base.y-s*0.88),Vector2(base.x+s*0.54,base.y-s*0.88),
  Vector2(base.x+s*0.22,base.y-s*1.05),Vector2(base.x-s*0.22,base.y-s*1.05)])
 draw_colored_polygon(roof,ink)
 draw_circle(Vector2(base.x,base.y-s*1.10),s*0.07,ink)

func draw_mist(w: float,h: float):
 for i in range(8):draw_rect(Rect2(0,h*0.86+i*h*0.018,w,h*0.018),Color(0.25,0.15,0.22,0.10+i*0.045))

func draw_vignette(w: float,h: float):
 for i in range(10):
  var inset=float(i)*10.0
  draw_rect(Rect2(inset,inset,w-inset*2,h-inset*2),Color(0.12,0.05,0.1,0.03),false,10.0)

func draw_moon(w: float,h: float):
 var moon=Vector2(w*0.740,h*0.118)
 for i in range(18):draw_circle(moon,200-i*8,Color(0.98,0.82,0.86,0.009+i*0.0018))
 draw_circle(moon,60,Color("#f6e3e6"))
 draw_circle(moon+Vector2(11,-6),46,Color(0.95,0.78,0.83,0.32))

func draw_hills(w: float,h: float):
 var hills=PackedVector2Array([Vector2(0,h)])
 for i in range(33):
  var x=w*i/32.0
  hills.append(Vector2(x,h*0.78-sin(i*0.55)*h*0.035-sin(i*1.7)*h*0.012))
 hills.append(Vector2(w,h))
 draw_colored_polygon(hills,Color("#3a2440"))

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
