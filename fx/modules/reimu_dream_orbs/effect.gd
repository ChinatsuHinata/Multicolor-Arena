extends "res://fx/categories/fx_spell_module.gd"
## 灵符·梦想妙珠：角色起点聚集，阴阳玉依次追向符卡目标，无目标时向外散射。

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
 float halo=(1.0-smoothstep(BODY,1.0,r))*0.55*glow_strength;
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

var origin_l=Vector3.ZERO
var dests_l: Array[Vector3]=[]
var orbs: Array[Dictionary]=[]
var charge_ring: MeshInstance3D
var impact_ring: MeshInstance3D
var impact_flash: MeshInstance3D
var charge=0.26
var flight=0.38
var trail=0.05
var last=0.0
var gather_radius=0.5
var gather_height=0.55
var scatter_radius=2.6
var hits=0

func _build() -> bool:
 if orb_shader==null:
  orb_shader=Shader.new();orb_shader.code=ORB_SHADER
 if ring_shader==null:
  ring_shader=Shader.new();ring_shader.code=RING_SHADER
 origin_l=local_point(origin_position())
 dests_l.assign(destinations().map(local_point))
 var n=clampi(palette_character_spells(),int(params.get("min_orbs",1)),int(params.get("max_orbs",12)))
 var size=card_size().x
 charge=float(params.get("charge_ms",260))/1000.0
 flight=float(params.get("flight_ms",380))/1000.0
 trail=float(params.get("trail_ms",50))/1000.0
 var stagger=minf(float(params.get("stagger_ms",95))/1000.0,float(params.get("stagger_total_ms",520))/1000.0/maxf(n-1,1))
 gather_radius=float(params.get("gather_radius",0.5))
 gather_height=float(params.get("gather_height",0.55))
 scatter_radius=float(params.get("scatter_radius",2.6))
 var arc_height=float(params.get("arc_height",1.1))
 var arc_spread=float(params.get("arc_spread",0.3))
 var red=Color(str(params.get("red","#c8323c")))
 var white=Color(str(params.get("white","#fbf2f0")))
 var glow=Color(str(params.get("glow","#e2604f")))
 var flash=Color(str(params.get("flash","#f9c9d8")))
 var gold=Color(str(params.get("gold","#e9c175")))
 charge_ring=make_plane(holder,origin_l+Vector3(0.0,0.012,0.0),Vector2.ONE*size*2.2,ring_material(glow,0.06,0.0))
 var impact_at=origin_l if dests_l.is_empty() else dests_l[0]+Vector3(0.0,0.014,0.0)
 impact_ring=make_plane(holder,impact_at,Vector2.ONE*size*2.6,ring_material(gold,0.05,0.0))
 impact_flash=make_plane(holder,impact_at,Vector2.ONE*size*2.6,ring_material(flash,0.14,1.0))
 orbs.clear()
 for i in range(n):
  var quad=QuadMesh.new()
  var jitter=rng.randf_range(0.9,1.1)
  quad.size=Vector2.ONE*float(params.get("orb_size",0.26))*size*1.5*jitter
  var node=make_orb("Orb%d" % i,quad,red,white,glow)
  var ghost_a=make_orb("Orb%dGhostA" % i,quad,red,white,glow)
  var ghost_b=make_orb("Orb%dGhostB" % i,quad,red,white,glow)
  var angle=TAU*float(i)/float(n)+rng.randf_range(-0.12,0.12)
  var spin=rng.randf_range(6.0,9.0)*(1.0 if rng.randf()<0.5 else -1.0)
  var side=1.0 if i%2==0 else -1.0
  var dest=null if dests_l.is_empty() else dests_l[i%dests_l.size()]
  var launch=charge*0.85+stagger*i
  var orb={"node":node,"ghosts":[ghost_a,ghost_b],"angle":angle,"spin":spin,"side":side,"dest":dest,"launch":launch,"arrive":launch+flight}
  orbs.append(orb)
  var start=gather_position(i,launch)
  orb["start"]=start
  if dest!=null:
   var end: Vector3=dest+Vector3(0.0,0.25,0.0)
   var lateral=Vector3.UP.cross(end-start).normalized()
   if lateral.is_zero_approx():lateral=Vector3.RIGHT
   orb["end"]=end
   orb["control"]=(start+end)*0.5+Vector3(0.0,arc_height*size,0.0)+side*arc_spread*size*lateral
 last=charge*0.85+stagger*(n-1)+flight
 return true

func make_orb(node_name: String,quad: QuadMesh,red: Color,white: Color,glow: Color) -> MeshInstance3D:
 var mat=ShaderMaterial.new()
 mat.shader=orb_shader
 mat.set_shader_parameter("red",red)
 mat.set_shader_parameter("white",white)
 mat.set_shader_parameter("glow",glow)
 var node=MeshInstance3D.new()
 node.name=node_name
 node.mesh=quad
 node.material_override=mat
 node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 holder.add_child(node)
 return node

func ring_material(tint: Color,width: float,fill: float) -> ShaderMaterial:
 var mat=ShaderMaterial.new()
 mat.shader=ring_shader
 mat.set_shader_parameter("tint",tint)
 mat.set_shader_parameter("width",width)
 mat.set_shader_parameter("fill",fill)
 mat.set_shader_parameter("alpha",0.0)
 return mat

func gather_position(i: int,t: float) -> Vector3:
 var appear=smoothstep(0.03*i,0.03*i+0.18,t)
 var ring_r=gather_radius*card_size().x*(0.6+0.4*appear)
 var angle=float(orbs[i].angle)+TAU*0.35*t
 return origin_l+Vector3(cos(angle)*ring_r,gather_height*card_size().x*appear+0.05,sin(angle)*ring_r)

func orb_position(i: int,t: float) -> Vector3:
 var orb=orbs[i]
 if t<float(orb.launch):return gather_position(i,t)
 var u=clampf((t-float(orb.launch))/flight,0.0,1.0)
 var e=u*u*(3.0-2.0*u)*0.35+pow(u,1.6)*0.65
 var start: Vector3=orb.start
 if orb.dest==null:
  var direction=Vector3(cos(float(orb.angle)),0.0,sin(float(orb.angle)))
  return start+direction*scatter_radius*card_size().x*e+Vector3(0.0,0.6*e,0.0)
 var control: Vector3=orb.control
 var end: Vector3=orb.end
 return pow(1.0-e,2.0)*start+2.0*(1.0-e)*e*control+e*e*end

func _frame(_delta: float) -> void:
 var t=elapsed
 var pulse=0.0
 hits=0
 for i in range(orbs.size()):
  var orb=orbs[i]
  var launch=float(orb.launch)
  var arrive=float(orb.arrive)
  var flying=t>=launch and t<arrive
  var appear=smoothstep(0.03*i,0.03*i+0.18,t)
  var u=clampf((t-launch)/flight,0.0,1.0)
  var scale_value=0.6+0.4*appear if t<launch else 1.0+0.15*sin(PI*u)
  var alpha=appear if t<launch else (1.0 if orb.dest!=null else 1.0-u)
  if t>=arrive:alpha=0.0;hits+=1
  var node: MeshInstance3D=orb.node
  node.position=orb_position(i,t)
  node.scale=Vector3.ONE*scale_value
  var mat: ShaderMaterial=node.material_override
  mat.set_shader_parameter("alpha",alpha)
  mat.set_shader_parameter("spin",float(orb.spin)*t)
  mat.set_shader_parameter("glow_strength",1.0+0.6*smoothstep(0.0,charge,t) if t<launch else 1.6)
  for j in range(2):
   var ghost: MeshInstance3D=orb.ghosts[j]
   ghost.position=orb_position(i,t-trail*(0.5 if j==0 else 1.0))
   ghost.scale=Vector3.ONE*scale_value*(0.85 if j==0 else 0.7)
   var ghost_mat: ShaderMaterial=ghost.material_override
   ghost_mat.set_shader_parameter("alpha",(0.45 if j==0 else 0.2) if flying else 0.0)
   ghost_mat.set_shader_parameter("spin",float(orb.spin)*t)
   ghost_mat.set_shader_parameter("glow_strength",2.0)
  pulse+=exp(-pow((t-arrive)/0.06,2.0))
 pulse=minf(pulse,1.5)
 var f=clampf(t/(charge+0.15),0.0,1.0)
 set_ring(charge_ring,0.25+0.45*f,sin(PI*f)*0.8 if f<1.0 else 0.0)
 var final=clampf((t-last)/maxf(budget-last,0.05),0.0,1.0)
 var impact_alpha=clampf(0.55*minf(pulse,1.0)+(0.9*pow(1.0-final,1.5) if t>=last else 0.0),0.0,1.0)
 set_ring(impact_ring,0.2+0.15*minf(pulse,1.0)+0.6*(1.0-pow(1.0-final,2.0)),impact_alpha if not dests_l.is_empty() else 0.0)
 set_ring(impact_flash,0.18+0.3*minf(pulse,1.0),0.35*minf(pulse,1.0) if not dests_l.is_empty() else 0.0)

func set_ring(node: MeshInstance3D,radius: float,alpha: float) -> void:
 var mat: ShaderMaterial=node.material_override
 mat.set_shader_parameter("radius",radius)
 mat.set_shader_parameter("alpha",alpha)
