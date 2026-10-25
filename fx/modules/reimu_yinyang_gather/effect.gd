extends "res://fx/categories/fx_entrance_module.gd"
## 博丽灵梦入场：红白阴阳玉从高处螺旋聚向卡牌，单位落场时一圈绯光炸开，
## 阴阳玉随即向外散去。阴阳玉与光环全部由着色器程序化绘制，不需要素材。
##
## 框架没有按卡牌挑选入场特效的字段，这里用 params.cards 对照 ctx.card_id
## 自行过滤：不是灵梦的卡只留一个空 holder，到预算静默收尾。

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

var active=true
var orbs: Array[MeshInstance3D]=[]
var orb_angle: Array[float]=[]
var orb_delay: Array[float]=[]
var orb_size: Array[float]=[]
var orb_spin: Array[float]=[]
var ring: MeshInstance3D
var inner: MeshInstance3D
var flash: MeshInstance3D

func _build() -> bool:
 var card_id=str(ctx.get("card_id",""))
 var allowed=params.get("cards",[]).map(func(v):return str(v))
 var preview=params.get("preview_ids",[]).map(func(v):return str(v))
 active=card_id.is_empty() or allowed.has(card_id) or preview.has(card_id)
 if not active:return true
 if orb_shader==null:
  orb_shader=Shader.new();orb_shader.code=ORB_SHADER
 if ring_shader==null:
  ring_shader=Shader.new();ring_shader.code=RING_SHADER
 var size=card_size()
 var count=clampi(int(params.get("orbs",6)),3,12)
 var red=Color(str(params.get("red","#c8323c")))
 var white=Color(str(params.get("white","#fbf2f0")))
 var glow=Color(str(params.get("glow","#e2604f")))
 var flash_tint=Color(str(params.get("flash","#f9c9d8")))
 var span=maxf(size.x,size.y)*1.7
 ring=make_plane(holder,Vector3(0.0,0.012,0.0),Vector2(span,span),ring_material(glow,0.05,0.0))
 inner=make_plane(holder,Vector3(0.0,0.014,0.0),Vector2(span,span),ring_material(white,0.025,0.0))
 flash=make_plane(holder,Vector3(0.0,0.016,0.0),Vector2(span,span),ring_material(flash_tint,0.12,1.0))
 var base=float(params.get("orb_size",0.3))*size.x
 for i in range(count):
  var mat=ShaderMaterial.new()
  mat.shader=orb_shader
  mat.set_shader_parameter("red",red)
  mat.set_shader_parameter("white",white)
  mat.set_shader_parameter("glow",glow)
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
  orb_delay.append(rng.randf_range(0.0,0.07))
  orb_size.append(scale_jitter)
  orb_spin.append(rng.randf_range(7.0,11.0)*(1.0 if rng.randf()<0.5 else -1.0))
 return true

func ring_material(tint: Color,width: float,fill: float) -> ShaderMaterial:
 var mat=ShaderMaterial.new()
 mat.shader=ring_shader
 mat.set_shader_parameter("tint",tint)
 mat.set_shader_parameter("width",width)
 mat.set_shader_parameter("fill",fill)
 mat.set_shader_parameter("alpha",0.0)
 return mat

func _frame(_delta: float) -> void:
 if not active:return
 var t=progress()
 var size=card_size()
 var gather_end=clampf(float(params.get("gather_end",0.46)),0.2,0.8)
 var r0=float(params.get("start_radius",1.45))
 var r1=float(params.get("gather_radius",0.55))
 var r2=float(params.get("scatter_radius",1.9))
 var turns=float(params.get("spin_turns",0.55))
 var aspect=size.y/size.x*0.82
 for i in range(orbs.size()):
  var delay=orb_delay[i]
  var g=smoothstep(0.0,1.0,clampf((t-delay)/(gather_end-delay),0.0,1.0))
  var s=clampf((t-gather_end-0.03)/(1.0-gather_end-0.03),0.0,1.0)
  var out=1.0-pow(1.0-s,3.0)
  var radius=lerpf(r0,r1,g) if s<=0.0 else lerpf(r1,r2,out)
  var angle=orb_angle[i]+TAU*turns*g+TAU*0.12*out
  var height=lerpf(0.95,0.32,g)+0.38*out
  orbs[i].position=Vector3(cos(angle)*radius*size.x,height,sin(angle)*radius*size.x*aspect)
  var appear=smoothstep(delay,delay+0.12,t)
  # 聚合瞬间轻微收缩再弹开，强调"落场"那一拍
  var pulse=1.0-0.22*exp(-pow((t-gather_end)/0.05,2.0))
  orbs[i].scale=Vector3.ONE*(0.55+0.45*appear)*pulse*(1.0+0.15*out)
  var mat: ShaderMaterial=orbs[i].material_override
  mat.set_shader_parameter("alpha",appear*(1.0-pow(s,1.4)))
  mat.set_shader_parameter("spin",orb_spin[i]*t)
  mat.set_shader_parameter("glow_strength",1.0+0.8*exp(-pow((t-gather_end)/0.08,2.0)))
 var f=clampf((t-gather_end+0.02)/0.42,0.0,1.0)
 var fo=1.0-pow(1.0-f,2.0)
 var live=1.0 if f>0.0 else 0.0
 set_ring(ring,0.18+0.78*fo,live*pow(1.0-f,1.6)*0.95)
 set_ring(inner,0.1+0.62*fo,live*pow(1.0-f,2.2)*0.8)
 var flash_f=clampf((t-gather_end+0.02)/0.16,0.0,1.0)
 set_ring(flash,0.2+0.35*flash_f,(1.0 if flash_f>0.0 else 0.0)*pow(1.0-flash_f,2.0)*0.35)

func set_ring(node: MeshInstance3D,radius: float,alpha: float) -> void:
 var mat: ShaderMaterial=node.material_override
 mat.set_shader_parameter("radius",radius)
 mat.set_shader_parameter("alpha",alpha)
