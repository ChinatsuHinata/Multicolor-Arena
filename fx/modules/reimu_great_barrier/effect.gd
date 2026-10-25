extends "res://fx/categories/fx_entrance_module.gd"
## 大结界·封魔阵：灵梦飞来途中，符札绕飞行中的卡牌盘旋，再依次掷向落点阵角，
## 每钉下一张阵就顺着画到那里，落地时阵正好闭合；随后闪光、结界壁升起后散去。
## 无飞行（预览或 after）时退回符札从四周螺旋收拢、阵按角度画开。
## 平常 8 张符札（八个阵角）、金色光晕；三符（疾行：颜色盘中同角色符卡 ≥ sustain_min）时
## 12 张符札（阵角 8 + 外环 4），阵与符札加红色光晕，阵与对角四张符札持续到回合结束。

const SEAL_SHADER="""
shader_type spatial;
render_mode unshaded,cull_disabled,depth_draw_never,blend_add;
uniform float draw=1.0;
uniform float alpha=1.0;
uniform float rot=0.0;
uniform float glow=1.0;
uniform float square=0.58;
uniform float sweep=0.0;
uniform float sweep_amt=0.0;
uniform vec2 hole=vec2(0.36,0.5);
uniform vec4 line:source_color=vec4(0.89,0.38,0.31,1.0);
uniform vec4 rune:source_color=vec4(0.91,0.76,0.46,1.0);
uniform vec4 fill:source_color=vec4(0.98,0.79,0.85,1.0);
uniform float aura=0.0;
uniform vec4 aura_tint:source_color=vec4(0.89,0.38,0.31,1.0);
float stroke(float d,float w){return exp(-pow(d/w,2.0));}
vec2 turn(vec2 p,float a){float c=cos(a);float s=sin(a);return vec2(c*p.x+s*p.y,-s*p.x+c*p.y);}
void fragment(){
 vec2 p=(UV-0.5)*2.0;
 float r=length(p);
 vec2 q=turn(p,rot);
 float a=fract(atan(q.y,q.x)/TAU+1.0);
 float shown=clamp((draw*1.02-a)/0.02,0.0,1.0);
 float ring=stroke(r-0.93,0.010)+0.8*stroke(r-0.85,0.007);
 float seg=floor(a*36.0);
 float h=fract(sin(seg*12.9898)*43758.5453);
 float f=fract(a*36.0);
 float tick=step(0.2,f)*step(f,0.6)*step(0.866,r)*step(r,0.872+0.04*(0.45+0.55*h));
 float d1=abs(max(abs(q.x),abs(q.y))-square);
 vec2 q2=turn(q,0.7853982);
 float d2=abs(max(abs(q2.x),abs(q2.y))-square);
 float sq=stroke(d1,0.008)+stroke(d2,0.008);
 float inner=stroke(r-0.42,0.006)+0.6*stroke(r-0.34,0.004);
 float k=floor(atan(q.y,q.x)/0.7853982+0.5);
 vec2 vp=square*1.4142136*vec2(cos(k*0.7853982),sin(k*0.7853982));
 float dots=stroke(length(q-vp),0.028);
 float soft=(1.0-smoothstep(0.0,0.93,r))*0.12;
 float pa=fract(atan(p.y,p.x)/TAU+1.0);
 float comet=exp(-fract((sweep-pa)*2.0)*10.0)*sweep_amt*3.0;
 float inside=(1.0-smoothstep(hole.x-0.03,hole.x,abs(p.x)))*(1.0-smoothstep(hole.y-0.03,hole.y,abs(p.y)));
 vec3 col=line.rgb*(ring+sq+inner)+rune.rgb*(tick+1.2*dots+ring*comet)+fill.rgb*soft;
 float wide=stroke(r-0.93,0.04)+stroke(r-0.85,0.03)+stroke(d1,0.035)+stroke(d2,0.035)+stroke(r-0.42,0.03)+1.5*stroke(length(q-vp),0.07);
 col+=aura_tint.rgb*aura*(0.55*wide+0.18*(1.0-smoothstep(0.0,0.95,r)));
 ALBEDO=col*glow;
 ALPHA=clamp(alpha*shown*(1.0-0.7*inside),0.0,1.0)*(1.0-step(1.0,r));
}
"""

const TALISMAN_SHADER="""
shader_type spatial;
render_mode unshaded,cull_disabled,depth_draw_never,blend_mix;
uniform float alpha=1.0;
uniform float glow=1.0;
uniform float tilt=0.0;
uniform float aspect=2.33;
uniform vec4 paper:source_color=vec4(0.98,0.95,0.94,1.0);
uniform vec4 ink:source_color=vec4(0.78,0.2,0.24,1.0);
uniform vec4 halo:source_color=vec4(0.91,0.76,0.46,1.0);
float bar(vec2 p,vec2 c,vec2 h){vec2 d=abs(p-c)-h;return 1.0-smoothstep(-0.01,0.01,max(d.x,d.y));}
void vertex(){
 float c=cos(tilt);float s=sin(tilt);
 VERTEX.xy=vec2(c*VERTEX.x-s*VERTEX.y,s*VERTEX.x+c*VERTEX.y);
 MODELVIEW_MATRIX=VIEW_MATRIX*mat4(INV_VIEW_MATRIX[0],INV_VIEW_MATRIX[1],INV_VIEW_MATRIX[2],MODEL_MATRIX[3]);
 MODELVIEW_MATRIX=MODELVIEW_MATRIX*mat4(vec4(length(MODEL_MATRIX[0].xyz),0.0,0.0,0.0),vec4(0.0,length(MODEL_MATRIX[1].xyz),0.0,0.0),vec4(0.0,0.0,length(MODEL_MATRIX[2].xyz),0.0),vec4(0.0,0.0,0.0,1.0));
 MODELVIEW_NORMAL_MATRIX=mat3(MODELVIEW_MATRIX);
}
void fragment(){
 vec2 p=UV*2.0-1.0;
 p.y*=aspect;
 vec2 half_size=vec2(0.66,0.84*aspect);
 vec2 d=abs(p)-half_size;
 float box=max(d.x,d.y);
 float body=1.0-smoothstep(-0.015,0.015,box);
 float e=-box;
 float frame=step(0.08,e)*(1.0-step(0.15,e));
 float glyph=bar(p,vec2(0.0,0.15*aspect),vec2(0.07,0.55*aspect));
 glyph=max(glyph,bar(p,vec2(0.0,-0.18*aspect),vec2(0.36,0.045)));
 glyph=max(glyph,bar(p,vec2(0.0,0.12*aspect),vec2(0.28,0.045)));
 glyph=max(glyph,bar(p,vec2(0.0,0.4*aspect),vec2(0.34,0.045)));
 float o=length(p-vec2(0.0,-0.55*aspect));
 glyph=max(glyph,exp(-pow((o-0.24)/0.05,2.0)));
 glyph=max(glyph,bar(p,vec2(0.0,0.7*aspect),vec2(0.16,0.1)));
 float mark=clamp(frame+glyph,0.0,1.0)*body;
 vec3 col=mix(paper.rgb,ink.rgb,mark);
 vec2 edge=abs(UV*2.0-1.0);
 float h=exp(-max(box,0.0)*9.0)*0.7*min(glow,1.6)*(1.0-body)*(1.0-smoothstep(0.75,1.0,max(edge.x,edge.y)));
 ALBEDO=mix(halo.rgb*glow,col,body);
 ALPHA=clamp(max(body,h)*alpha,0.0,1.0);
}
"""

const RING_SHADER="""
shader_type spatial;
render_mode unshaded,cull_disabled,depth_draw_never,blend_add;
uniform float radius=0.5;
uniform float width=0.06;
uniform float fill=0.0;
uniform float alpha=1.0;
uniform vec4 tint:source_color=vec4(0.98,0.79,0.85,1.0);
void fragment(){
 float r=length(UV-0.5)*2.0;
 float ring=exp(-pow((r-radius)/width,2.0));
 float core=fill*(1.0-smoothstep(0.0,max(radius,0.001),r));
 ALBEDO=tint.rgb;
 ALPHA=clamp((ring+core)*alpha,0.0,1.0)*(1.0-step(1.0,r));
}
"""

const WALL_SHADER="""
shader_type spatial;
render_mode unshaded,cull_disabled,depth_draw_never,blend_add;
uniform float alpha=1.0;
uniform float flow=0.0;
uniform vec4 tint:source_color=vec4(0.91,0.76,0.46,1.0);
void fragment(){
 float v=UV.y;
 float ends=smoothstep(0.0,0.08,UV.x)*smoothstep(1.0,0.92,UV.x);
 float base=pow(v,2.2);
 float bands=0.35*smoothstep(0.35,0.5,fract(v*5.0+flow))*smoothstep(0.65,0.5,fract(v*5.0+flow))*v;
 ALBEDO=tint.rgb;
 ALPHA=clamp((base+bands)*ends*alpha,0.0,1.0);
}
"""

static var seal_shader: Shader
static var talisman_shader: Shader
static var ring_shader: Shader
static var wall_shader: Shader

var seal: MeshInstance3D
var burst: MeshInstance3D
var walls: Array[MeshInstance3D]=[]
var talismans: Array[MeshInstance3D]=[]
var phase_offset: Array[float]=[]
var span=4.0
## 三符（疾行）：符札变多（阵角 8 张 + 外环 8 张），阵与符札加红色光晕。
var empowered=false

func _build() -> bool:
 if seal_shader==null:
  seal_shader=Shader.new();seal_shader.code=SEAL_SHADER
 if talisman_shader==null:
  talisman_shader=Shader.new();talisman_shader.code=TALISMAN_SHADER
 if ring_shader==null:
  ring_shader=Shader.new();ring_shader.code=RING_SHADER
 if wall_shader==null:
  wall_shader=Shader.new();wall_shader.code=WALL_SHADER
 var size=card_size()
 var w=size.x
 span=maxf(size.x,size.y)*float(params.get("seal_scale",2.0))
 empowered=bool(ctx.get("haste",false)) and int(ctx.get("owner_character_spells",0))>=int(params.get("sustain_min",3))
 var red=Color(str(params.get("aura","#e2604f")))
 var seal_mat=ShaderMaterial.new()
 seal_mat.shader=seal_shader
 seal_mat.set_shader_parameter("line",Color(str(params.get("line","#e2604f"))))
 seal_mat.set_shader_parameter("rune",Color(str(params.get("rune","#e9c175"))))
 seal_mat.set_shader_parameter("fill",Color(str(params.get("fill","#f9c9d8"))))
 seal_mat.set_shader_parameter("square",float(params.get("square",0.58)))
 seal_mat.set_shader_parameter("hole",Vector2(size.x/span,size.y/span))
 seal_mat.set_shader_parameter("alpha",0.0)
 seal_mat.set_shader_parameter("aura_tint",red)
 seal_mat.set_shader_parameter("aura",float(params.get("aura_strength",1.0)) if empowered else 0.0)
 seal=make_plane(holder,Vector3(0.0,0.006,0.0),Vector2(span,span),seal_mat)
 seal.name="Seal"
 var burst_mat=ShaderMaterial.new()
 burst_mat.shader=ring_shader
 burst_mat.set_shader_parameter("tint",red if empowered else Color(str(params.get("flash","#f9c9d8"))))
 burst_mat.set_shader_parameter("width",0.1)
 burst_mat.set_shader_parameter("alpha",0.0)
 burst=make_plane(holder,Vector3(0.0,0.014,0.0),Vector2(span,span),burst_mat)
 burst.name="Burst"
 var wall_tint=Color(str(params.get("wall","#e9c175")))
 var b=float(params.get("square",0.58))*span
 for i in range(4):
  var wall_mat=ShaderMaterial.new()
  wall_mat.shader=wall_shader
  wall_mat.set_shader_parameter("tint",wall_tint)
  wall_mat.set_shader_parameter("alpha",0.0)
  var quad=QuadMesh.new()
  quad.size=Vector2(b,float(params.get("wall_height",0.45))*w)
  var node=MeshInstance3D.new()
  node.name="Wall%d" % i
  node.mesh=quad
  node.material_override=wall_mat
  node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
  holder.add_child(node)
  walls.append(node)
 var count=clampi(int(params.get("talismans_empowered",12) if empowered else params.get("talismans",8)),4,16)
 build_slots(count)
 var tw=float(params.get("talisman_size",0.3))*w
 var aspect=float(params.get("talisman_aspect",2.33))
 for i in range(count):
  var mat=ShaderMaterial.new()
  mat.shader=talisman_shader
  mat.set_shader_parameter("paper",Color(str(params.get("paper","#fbf2f0"))))
  mat.set_shader_parameter("ink",Color(str(params.get("ink","#c8323c"))))
  mat.set_shader_parameter("halo",red if empowered else Color(str(params.get("halo","#e9c175"))))
  mat.set_shader_parameter("aspect",aspect)
  mat.set_shader_parameter("alpha",0.0)
  var quad=QuadMesh.new()
  quad.size=Vector2(tw,tw*aspect)*(float(params.get("outer_scale",0.8)) if outer_slot(i,count) else 1.0)
  var node=MeshInstance3D.new()
  node.name="Talisman%d" % i
  node.mesh=quad
  node.material_override=mat
  node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
  holder.add_child(node)
  talismans.append(node)
  phase_offset.append(rng.randf_range(0.0,TAU))
 if empowered:hold_until_turn_end()
 return true

func _frame(_delta: float) -> void:
 var t=elapsed
 var w=card_size().x
 var square=float(params.get("square",0.58))
 var R=square*sqrt(2.0)*span*0.5
 var A=maxf(land_seconds(),float(params.get("gather_ms",320))/1000.0)
 var lock=A+float(params.get("lock_ms",120))/1000.0
 var E0=maxf(A+0.55,budget-float(params.get("exit_ms",600))/1000.0)
 var s=clampf((t-E0)/maxf(budget-E0,0.15),0.0,1.0)
 var se=1.0-pow(1.0-s,2.0)
 var rp=release_progress()
 var held=sustaining
 var rot=float(params.get("seal_spin",0.25))*t
 var flash_k=exp(-pow((t-lock)/0.08,2.0))
 var pulse=1.0
 if held and t>E0:pulse=0.85+0.25*sin(TAU*t/maxf(float(params.get("pulse_ms",2400))/1000.0,0.2))
 var n=talismans.size()
 var T=flight_seconds()
 var flying_mode=T>=0.05
 # 阵：飞行中随符札落点逐段画开，落地闪光，退场淡出或降到持续亮度。
 var draw=smoothstep(0.0,1.0,clampf(t/maxf(A*0.9,0.05),0.0,1.0))
 if flying_mode:
  draw=0.0
  for i in range(n):
   draw+=smoothstep(throw_arrive(i,n,T)-0.04,throw_arrive(i,n,T)+0.12,t)/float(n)
 var seal_alpha=0.9*smoothstep(0.0,0.1,t)
 seal_alpha*=lerpf(1.0,float(params.get("sustain_alpha",0.45)),se) if held else 1.0-se
 seal_alpha*=1.0-rp
 var comet=smoothstep(lock,lock+0.2,t)*(1.0-s)
 if held:comet=maxf(comet,s)
 var seal_mat: ShaderMaterial=seal.material_override
 seal_mat.set_shader_parameter("draw",draw)
 seal_mat.set_shader_parameter("rot",rot)
 seal_mat.set_shader_parameter("alpha",seal_alpha)
 seal_mat.set_shader_parameter("glow",(1.0+1.5*flash_k)*pulse)
 seal_mat.set_shader_parameter("sweep",t*0.35)
 seal_mat.set_shader_parameter("sweep_amt",comet*(1.0-rp))
 seal.scale=Vector3.ONE*(1.0+0.04*flash_k+0.12*rp)
 # 落地闪光环
 var f=clampf((t-lock+0.04)/0.35,0.0,1.0)
 var burst_on=1.0 if t>=lock-0.04 else 0.0
 var burst_mat: ShaderMaterial=burst.material_override
 burst_mat.set_shader_parameter("radius",0.1+0.8*(1.0-pow(1.0-f,2.0)))
 burst_mat.set_shader_parameter("alpha",burst_on*pow(1.0-f,2.0)*0.8)
 burst_mat.set_shader_parameter("fill",0.6*(1.0-f))
 # 结界壁：沿第一个方形四边升起，退场时淡出（持续态不保留）。
 var b=square*span*0.5
 var rise=smoothstep(A+0.05,A+0.05+float(params.get("wall_rise_ms",260))/1000.0,t)
 var wall_alpha=rise*pow(1.0-s,2.0)*(0.75+0.6*flash_k)
 for i in range(walls.size()):
  var a=rot+float(i)*PI*0.5
  var node=walls[i]
  var quad: QuadMesh=node.mesh
  var height=quad.size.y*maxf(rise,0.001)
  node.rotation=Vector3(0.0,PI*0.5-a,0.0)
  node.scale=Vector3(1.0,maxf(rise,0.001),1.0)
  node.position=Vector3(cos(a)*b,height*0.5,sin(a)*b)
  var mat: ShaderMaterial=node.material_override
  mat.set_shader_parameter("alpha",wall_alpha)
  mat.set_shader_parameter("flow",-t*1.5)
 # 符札：螺旋收拢到八个阵角，落地放大一下；退场上升散开，持续态留对角四张。
 var h0=float(params.get("talisman_height",0.42))
 var boost=float(params.get("empowered_glow",1.5)) if empowered else 1.0
 var orbit_period=maxf(float(params.get("orbit_period_ms",800))/1000.0,0.1)
 var orbit_radius=float(params.get("orbit_radius",0.72))
 for i in range(n):
  var base=rot+slot_angle[i]
  var node=talismans[i]
  var mat: ShaderMaterial=node.material_override
  if flying_mode and t<throw_arrive(i,n,T):
   # 飞行中：先绕卡牌盘旋，到出手时刻旋转着掷向自己的阵角。
   var depart=throw_depart(i,n,T)
   var arrive=throw_arrive(i,n,T)
   var hold_t=minf(t,depart)
   var a=TAU*float(i)/float(n)+TAU*hold_t/orbit_period
   var start=flight_local(hold_t)*Vector3(cos(a)*orbit_radius*w,0.12,sin(a)*orbit_radius*w*1.3)
   var u=clampf((t-depart)/maxf(arrive-depart,0.01),0.0,1.0)
   var ue=4.0*u*u*u if u<0.5 else 1.0-pow(-2.0*u+2.0,3.0)/2.0
   var target=Vector3(cos(base)*slot_radius(i,n,R),h0+slot_lift(i),sin(base)*slot_radius(i,n,R))
   node.position=start.lerp(target,ue)+Vector3(0.0,0.5*sin(PI*u),0.0)
   node.scale=Vector3.ONE*(0.85+0.15*ue)
   mat.set_shader_parameter("alpha",smoothstep(0.0,0.1,t))
   mat.set_shader_parameter("glow",(1.0+0.6*u)*boost)
   mat.set_shader_parameter("tilt",TAU*(1.0-ue) if u>0.0 else 0.12*sin(1.7*t+phase_offset[i]))
   continue
  var delay=0.04*float(i)
  var u=clampf((t-delay)/maxf(A-delay,0.05),0.0,1.0)
  var ue=1.0-pow(1.0-u,3.0)
  var impact=0.0
  if flying_mode:
   ue=1.0
   impact=exp(-pow((t-throw_arrive(i,n,T))/0.06,2.0))
  var radius=lerpf(R*float(params.get("start_radius",2.2)),slot_radius(i,n,R),ue)
  var angle=base-(1.0-ue)*1.4
  var height=lerpf(1.3,h0+slot_lift(i),ue)+0.04*sin(2.6*t+phase_offset[i])*ue
  var scale=(0.7+0.3*ue)*(1.0+0.18*flash_k+0.25*impact)
  var alpha=smoothstep(delay,delay+0.1,t) if not flying_mode else 1.0
  var glow=(1.0+0.8*flash_k+1.2*impact)*boost
  var kept=held and kept_slot(i,n)
  if kept:
   radius=lerpf(radius,R*float(params.get("sustain_radius",0.9)),se)
   scale*=lerpf(1.0,float(params.get("sustain_scale",0.72)),se)
   glow*=pulse
   height+=0.9*rp*rp
   alpha*=1.0-rp
  else:
   radius*=1.0+0.35*se
   height+=1.0*se*se
   alpha*=pow(1.0-s,1.5)
  node.position=Vector3(cos(angle)*radius,height,sin(angle)*radius)
  node.scale=Vector3.ONE*scale
  mat.set_shader_parameter("alpha",alpha)
  mat.set_shader_parameter("glow",glow)
  mat.set_shader_parameter("tilt",0.12*sin(1.7*t+phase_offset[i]))

## 第 i 张符札的出手 / 钉入时刻：出手均匀排在飞行的 throw_from..throw_to，
## 飞行 throw_ms（不超过飞行的 30%），最后一张在落地前钉入。
func throw_depart(i: int,n: int,T: float) -> float:
 var from=float(params.get("throw_from",0.12))
 var to=float(params.get("throw_to",0.67))
 return T*(from+(to-from)*float(i)/float(maxi(n-1,1)))

func throw_arrive(i: int,n: int,T: float) -> float:
 return throw_depart(i,n,T)+minf(float(params.get("throw_ms",220))/1000.0,T*0.3)

## 符札槽位：前 min(n,8) 张均分在阵角（8 张时正好是二重结界的八个角），其余均分在
## 外环、落在阵角之间；按角度排序，出手顺序就是阵画开的顺序。持续态留下的四张
## 取阵角中的对角线四张（阵角只有 4 张时即全部）。
var slot_angle: Array[float]=[]
var slot_outer: Array[bool]=[]
var slot_keep: Array[bool]=[]

func build_slots(n: int) -> void:
 var inner=mini(n,8)
 var outer=n-inner
 var every=maxi(inner/4,1)
 var slots: Array=[]
 for k in range(inner):slots.append([TAU*float(k)/float(inner),false,k%every==every/2])
 for k in range(outer):slots.append([TAU*(float(k)+0.5)/float(outer),true,false])
 slots.sort_custom(func(a,b):return a[0]<b[0])
 for slot in slots:
  slot_angle.append(slot[0]);slot_outer.append(slot[1]);slot_keep.append(slot[2])

func outer_slot(i: int,_n: int) -> bool:
 return i<slot_outer.size() and slot_outer[i]

func slot_radius(i: int,n: int,R: float) -> float:
 return span*0.5*float(params.get("outer_radius",0.93)) if outer_slot(i,n) else R

## 外环符札抬高一层，和阵角符札在透视里错开。
func slot_lift(i: int) -> float:
 return float(params.get("outer_lift",0.3)) if outer_slot(i,0) else 0.0

func kept_slot(i: int,_n: int) -> bool:
 return i<slot_keep.size() and slot_keep[i]
