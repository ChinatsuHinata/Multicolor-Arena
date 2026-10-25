extends "res://fx/categories/fx_entrance_module.gd"
## 飞行护送：红白阴阳玉绕卡牌正反面公转，末段逐渐压平为落点水平环。
## 落地收拢蓄力：水平环收紧变亮；无飞行时退回从四周螺旋聚集。
## 炸开散去：落点炸开绯光与白环，阴阳玉向外飞散、升高、淡出。

const ORB_SHADER="""
shader_type spatial;
render_mode unshaded,cull_disabled,depth_draw_never,blend_mix;
uniform float spin=0.0;
uniform float alpha=1.0;
uniform float glow_strength=1.0;
uniform vec4 red:source_color=vec4(0.78,0.2,0.24,1.0);
uniform vec4 white:source_color=vec4(0.98,0.95,0.94,1.0);
uniform vec4 glow:source_color=vec4(0.89,0.38,0.31,1.0);
const float BODY=0.66;
float inside(float d,float r){return 1.0-smoothstep(r-0.025,r+0.025,d);}
void vertex(){
 MODELVIEW_MATRIX=VIEW_MATRIX*mat4(INV_VIEW_MATRIX[0],INV_VIEW_MATRIX[1],INV_VIEW_MATRIX[2],MODEL_MATRIX[3]);
 MODELVIEW_MATRIX=MODELVIEW_MATRIX*mat4(vec4(length(MODEL_MATRIX[0].xyz),0.0,0.0,0.0),vec4(0.0,length(MODEL_MATRIX[1].xyz),0.0,0.0),vec4(0.0,0.0,length(MODEL_MATRIX[2].xyz),0.0),vec4(0.0,0.0,0.0,1.0));
 MODELVIEW_NORMAL_MATRIX=mat3(MODELVIEW_MATRIX);
}
void fragment(){
 vec2 p=(UV-0.5)*2.0;
 float r=length(p);
 float body=1.0-smoothstep(BODY-0.02,BODY,r);
 vec2 q=p/BODY;
 float c=cos(spin);float s=sin(spin);
 q=vec2(c*q.x-s*q.y,s*q.x+c*q.y);
 float w=smoothstep(-0.02,0.02,q.x);
 float up=length(q-vec2(0.0,0.5));
 float dn=length(q+vec2(0.0,0.5));
 w=mix(w,0.0,inside(up,0.5));
 w=mix(w,1.0,inside(dn,0.5));
 w=mix(w,1.0,inside(up,0.15));
 w=mix(w,0.0,inside(dn,0.15));
 vec3 col=mix(red.rgb,white.rgb,w);
 float rn=clamp(r/BODY,0.0,1.0);
 float z=sqrt(max(0.0,1.0-rn*rn));
 col*=0.6+0.4*z;
 col=mix(col,vec3(0.8,0.66,0.86),smoothstep(0.62,1.0,rn)*0.4);
 float hl=max(0.0,1.0-length(p/BODY-vec2(-0.34,-0.4))/0.42);
 col+=vec3(1.0)*hl*hl*0.6;
 float halo=pow(1.0-smoothstep(BODY,1.0,r),1.5)*0.75*glow_strength;
 ALBEDO=mix(glow.rgb,col,body);
 ALPHA=clamp(max(body,halo)*alpha,0.0,1.0);
}
"""

const RING_SHADER="""
shader_type spatial;
render_mode unshaded,cull_disabled,depth_draw_never,blend_add;
uniform float radius=0.5;
uniform float width=0.06;
uniform float fill=0.0;
uniform float alpha=1.0;
uniform vec4 tint:source_color=vec4(0.89,0.38,0.31,1.0);
void fragment(){
 float r=length(UV-0.5)*2.0;
 float ring=exp(-pow((r-radius)/width,2.0));
 float core=fill*(1.0-smoothstep(0.0,max(radius,0.001),r));
 ALBEDO=tint.rgb;
 ALPHA=clamp((ring+core)*alpha,0.0,1.0)*(1.0-step(1.0,r));
}
"""

static var orb_shader: Shader
static var ring_shader: Shader

var orbs: Array[MeshInstance3D]=[]
var orb_angle: Array[float]=[]
var orb_delay: Array[float]=[]
var orb_spin: Array[float]=[]
var orb_halo: Array[Color]=[]
var converge: MeshInstance3D
var ring: MeshInstance3D
var inner: MeshInstance3D
var flash: MeshInstance3D

func _build() -> bool:
 if orb_shader==null:
  orb_shader=Shader.new();orb_shader.code=ORB_SHADER
 if ring_shader==null:
  ring_shader=Shader.new();ring_shader.code=RING_SHADER
 var size=card_size()
 var count=clampi(int(params.get("orbs",6)),3,12)
 var red=Color(str(params.get("red","#c8323c")))
 var white=Color(str(params.get("white","#fbf2f0")))
 var glow=Color(str(params.get("glow","#e2604f")))
 var halos=params.get("halos",[])
 if not halos is Array or halos.is_empty():halos=[glow]
 var flash_tint=Color(str(params.get("flash","#f9c9d8")))
 var span=maxf(size.x,size.y)*1.7
 converge=make_plane(holder,Vector3(0.0,0.01,0.0),Vector2(span,span),ring_material(red,0.04,0.0))
 ring=make_plane(holder,Vector3(0.0,0.012,0.0),Vector2(span,span),ring_material(glow,0.05,0.0))
 inner=make_plane(holder,Vector3(0.0,0.014,0.0),Vector2(span,span),ring_material(white,0.025,0.0))
 flash=make_plane(holder,Vector3(0.0,0.016,0.0),Vector2(span,span),ring_material(flash_tint,0.12,1.0))
 var base=float(params.get("orb_size",0.3))*size.x
 for i in range(count):
  var mat=ShaderMaterial.new()
  mat.shader=orb_shader
  mat.set_shader_parameter("red",red)
  mat.set_shader_parameter("white",white)
  var halo=Color(halos[i%halos.size()])
  mat.set_shader_parameter("glow",halo)
  orb_halo.append(halo)
  var quad=QuadMesh.new()
  var scale_jitter=rng.randf_range(0.85,1.15)
  quad.size=Vector2.ONE*base*1.5*scale_jitter
  var node=MeshInstance3D.new()
  node.name="Orb%d" % i
  node.mesh=quad
  node.material_override=mat
  node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
  holder.add_child(node)
  orbs.append(node)
  orb_angle.append(TAU*float(i)/float(count)+rng.randf_range(-0.18,0.18))
  orb_delay.append(rng.randf_range(0.0,0.2))
  orb_spin.append(rng.randf_range(5.0,8.0)*(1.0 if rng.randf()<0.5 else -1.0))
 return true

func ring_material(tint: Color,width: float,fill: float) -> ShaderMaterial:
 var mat=ShaderMaterial.new()
 mat.shader=ring_shader
 mat.set_shader_parameter("tint",tint)
 mat.set_shader_parameter("width",width)
 mat.set_shader_parameter("fill",fill)
 mat.set_shader_parameter("alpha",0.0)
 return mat

## 飞行段使用基底位姿，落地后在 holder 原点收拢；无飞行时保留延迟聚集。
func _frame(_delta: float) -> void:
 var t=elapsed
 var size=card_size()
 var w=size.x
 var aspect=size.y/size.x*0.82
 var T=flight_seconds()
 var flying_mode=T>=0.05
 var period=maxf(float(params.get("orbit_period_ms",450))/1000.0,0.1)
 var tilt=deg_to_rad(float(params.get("orbit_tilt_deg",22)))
 var charge=float(params.get("charge_ms",110))/1000.0
 var settle=float(params.get("settle_ms",180))/1000.0 if flying_mode else maxf(float(params.get("gather_ms",560))/1000.0-charge,0.1)
 var B0=T if flying_mode else 0.0
 var G=minf(B0+settle+charge,budget-0.25)
 var c_start=G-charge
 var tail=maxf(budget-G,0.1)
 var orbit_radius=float(params.get("orbit_radius",0.78))
 var orbit_height=float(params.get("orbit_height",0.32))
 var front_scale=float(params.get("front_scale",0.18))
 var back_alpha=float(params.get("back_alpha",0.6))
 var r0=float(params.get("start_radius",1.6))
 var r1=float(params.get("gather_radius",0.5))
 var rc=float(params.get("charge_radius",0.36))
 var r2=float(params.get("scatter_radius",2.1))
 var cturns=float(params.get("charge_turns",0.3))
 var k=clampf((t-c_start)/charge,0.0,1.0)
 var s=clampf((t-G)/tail,0.0,1.0)
 var out=1.0-pow(1.0-s,3.0)
 var beat=exp(-pow((t-G)/0.07,2.0))
 for i in range(orbs.size()):
  var a=orb_angle[i]+TAU*t/period
  var d=sin(a)
  var pos: Vector3
  var scale: float
  var alpha: float
  var glow_strength: float
  if flying_mode and t<T:
   var F=flight_local(t)
   var V=F*Vector3(cos(a)*orbit_radius*w,sin(a)*orbit_radius*w*cos(tilt),sin(a)*orbit_radius*w*sin(tilt))
   var H=F.origin+Vector3(cos(a)*orbit_radius*w,orbit_height,sin(a)*orbit_radius*w*aspect)
   var blend=smoothstep(float(params.get("flatten_from",0.65)),1.0,t/T)
   pos=V.lerp(H,blend)
   var appear=smoothstep(0.0,0.08,t)
   scale=(0.5+0.5*appear)*(1.0+front_scale*d)
   alpha=appear*lerpf(back_alpha,1.0,(d+1.0)*0.5)
   glow_strength=1.0+0.4*(d+1.0)*0.5
  elif t<G:
   var start_radius=orbit_radius if flying_mode else r0
   var P=flight_local(T).origin+Vector3(cos(a)*orbit_radius*w,orbit_height,sin(a)*orbit_radius*w*aspect) if flying_mode else Vector3(cos(a)*r0*w,0.9,sin(a)*r0*w*aspect)
   var delay=0.0 if flying_mode else orb_delay[i]*settle
   var s1=smoothstep(0.0,1.0,clampf((t-B0-delay)/maxf(settle-delay,0.01),0.0,1.0))
   var radius=lerpf(start_radius,r1,s1)
   if k>0.0:radius=lerpf(r1,rc,k*k)
   var angle=a+TAU*cturns*k
   var height=lerpf(P.y,orbit_height,s1)-0.04*k
   pos=Vector3(cos(angle)*radius*w,height,sin(angle)*radius*w*aspect)
   var appear=1.0 if flying_mode else smoothstep(delay,delay+0.15,t)
   scale=(1.0+0.2*k)*(1.0+0.5*front_scale*d)
   if not flying_mode:scale*=0.5+0.5*appear
   alpha=appear
   glow_strength=0.8+0.6*s1+1.0*k
  else:
   var radius=lerpf(rc,r2,out)
   var height=orbit_height-0.04+0.5*out
   var angle=a+TAU*0.15*out
   pos=Vector3(cos(angle)*radius*w,height,sin(angle)*radius*w*aspect)
   scale=1.2*(1.0-0.18*beat)*(1.0+0.2*out)
   alpha=pow(1.0-s,1.5)
   glow_strength=0.8+0.6+1.0*(1.0-s)+1.0*beat
  orbs[i].position=pos
  orbs[i].scale=Vector3.ONE*scale
  var mat: ShaderMaterial=orbs[i].material_override
  mat.set_shader_parameter("alpha",alpha)
  mat.set_shader_parameter("spin",orb_spin[i]*t)
  mat.set_shader_parameter("glow_strength",glow_strength)
 var cg=clampf((t-B0)/maxf(G-B0,0.01),0.0,1.0)
 var live=1.0 if B0<=t and t<G else 0.0
 var alpha=live*0.6*smoothstep(B0,B0+0.08,t)*(1.0-smoothstep(G-0.06,G,t))
 set_ring(converge,lerpf(0.95,0.28,smoothstep(0.0,1.0,cg)),alpha)
 var converge_mat: ShaderMaterial=converge.material_override
 converge_mat.set_shader_parameter("fill",0.35*k)
 var f=clampf((t-G)/(tail*0.8),0.0,1.0)
 var fo=1.0-pow(1.0-f,2.0)
 var on=1.0 if t>=G else 0.0
 set_ring(ring,0.2+0.8*fo,on*pow(1.0-f,1.6)*0.95)
 set_ring(inner,0.1+0.65*fo,on*pow(1.0-f,2.2)*0.8)
 var ff=clampf((t-G)/0.2,0.0,1.0)
 set_ring(flash,0.2+0.35*ff,on*pow(1.0-ff,2.0)*0.45)

func set_ring(node: MeshInstance3D,radius: float,alpha: float) -> void:
 var mat: ShaderMaterial=node.material_override
 mat.set_shader_parameter("radius",radius)
 mat.set_shader_parameter("alpha",alpha)
