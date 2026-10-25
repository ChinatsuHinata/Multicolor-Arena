extends "res://fx/fx_module.gd"
## 单位入场特效：挂在卡牌视觉根节点下，随卡牌一起移动、缩放、消失。
##
## 契约
##  * parent 是花牌视觉根 Node3D（duel_table 的 card_<uid>），本模块只加子节点；
##  * 卡面尺寸来自 ctx.card_size，不得写死像素或世界坐标；
##  * 不修改 Face / Halo / Outline / SummoningMist 的材质，不改 Hit 碰撞；
##  * 时长随卡牌缩放，不允许把台面坐标当屏幕坐标。

const MIN_ENVELOPE=0.0

func default_offset() -> Vector3:
 return Vector3.ZERO

func card_size() -> Vector2:
 var value=ctx.get("card_size")
 return value if value is Vector2 and value.x>0.0 else Vector2(1.95,2.72)

## 0 → 1（入场）→ 0（收束），模块统一用它算透明度与位移。
func envelope() -> float:
 var t=progress()
 return sin(t*PI) if t<1.0 else 0.0

## 入场时间点（清单 timing）：
##  before：单位牌离开堆叠、正飞向战场时开播，卡牌尚未进场，land_seconds() 为落场时刻；
##  after ：卡牌落场后开播（缺省），land_seconds() 为 0。
var timing="after"

func configure(def: Dictionary,context: Dictionary) -> void:
 super(def,context)
 timing=str(def.get("timing","after"))
 flight_mode=str(def.get("flight","none"))
 sustain_mode=str(def.get("sustain","none"))

## 卡牌从堆叠飞到落点的时长，本体经 ctx.travel 传入；预览与单测没有时取 params.travel_ms。
func travel_seconds() -> float:
 return maxf(float(ctx.get("travel",float(params.get("travel_ms",420.0))/1000.0)),0.0)

## 卡牌落场时刻（模块时钟）。before 段的"进场后"部分从这里开始。
func land_seconds() -> float:
 return minf(travel_seconds(),budget) if timing=="before" else 0.0

## 飞行位姿由上下文插值，或实时追踪 3D 卡牌；holder 仍固定在落点。
var flight_mode="none"
var landed=false
var proxy: MeshInstance3D

func flight_seconds() -> float:
 if timing!="before":return 0.0
 var flight=ctx.get("flight")
 return maxf(float(flight.seconds),0.0) if flight is Dictionary and flight.has("seconds") else travel_seconds()

func flight_ease(u: float) -> float:
 u=clampf(u,0.0,1.0)
 var flight=ctx.get("flight")
 if flight is Dictionary and flight.get("ease","cubic_in_out")=="linear":return u
 if flight is Dictionary and flight.get("ease","cubic_in_out")=="sine_in_out":return -(cos(PI*u)-1.0)/2.0
 return 4.0*u*u*u if u<0.5 else 1.0-pow(-2.0*u+2.0,3.0)/2.0

func flight_global(t: float) -> Transform3D:
 var fs=flight_seconds()
 var landing=ctx.get("landing")
 if not landing is Transform3D:landing=holder.global_transform if is_instance_valid(holder) else Transform3D.IDENTITY
 var flight=ctx.get("flight")
 if flight is Dictionary and flight.get("from") is Transform3D:
  var from: Transform3D=flight.from
  var to: Transform3D=flight.get("to",landing)
  var u=flight_ease(t/fs) if fs>0.0 else 1.0
  var origin=from.origin.lerp(to.origin,u)
  var q=Quaternion(from.basis.orthonormalized()).slerp(Quaternion(to.basis.orthonormalized()),u)
  var sc=from.basis.get_scale().lerp(to.basis.get_scale(),u)
  return Transform3D(Basis(q).scaled(sc),origin)
 var node=ctx.get("node")
 if is_instance_valid(node) and node is Node3D and node.is_inside_tree():return node.global_transform
 return landing

func flight_local(t: float=-1.0) -> Transform3D:
 if t<0.0:t=elapsed
 if not is_instance_valid(holder) or not holder.is_inside_tree():return Transform3D.IDENTITY
 return holder.global_transform.affine_inverse()*flight_global(t)

func in_flight(t: float=-1.0) -> bool:
 if t<0.0:t=elapsed
 return flight_seconds()>0.0 and t<flight_seconds() and not landed

func owns_flight() -> bool:
 return is_instance_valid(proxy)

func card_landed() -> void:
 landed=true
 if is_instance_valid(proxy):proxy.visible=false

## 代理卡在模块节点检查后创建；flight=proxy 的模块自身节点须 ≤63。
func build_proxy() -> void:
 if flight_mode!="proxy" or ctx.get("flight_proxy",false)!=true:return
 var flight=ctx.get("flight")
 if not flight is Dictionary or not (flight.get("texture") is Texture2D or flight.get("color") is Color):return
 proxy=MeshInstance3D.new();proxy.name="FlightProxy"
 var plane=PlaneMesh.new();plane.size=card_size()
 proxy.mesh=plane
 proxy.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 var mat=StandardMaterial3D.new()
 mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
 mat.cull_mode=BaseMaterial3D.CULL_DISABLED
 if flight.get("texture") is Texture2D:
  mat.albedo_texture=flight.texture;mat.albedo_color=Color.WHITE
 else:mat.albedo_color=flight.color
 proxy.material_override=mat
 holder.add_child(proxy)

func update_proxy() -> void:
 if not is_instance_valid(proxy):return
 proxy.visible=not landed
 proxy.transform=flight_local(minf(elapsed,flight_seconds()))

func start() -> bool:
 var ok=super()
 if ok:build_proxy()
 pin_to_landing()
 update_proxy()
 return ok

func advance(delta: float) -> void:
 super(delta)
 pin_to_landing()
 update_proxy()

## ctx.landing 是落点的全局变换；有它时 holder 钉在落点，不随飞行中的卡牌移动。
func pin_to_landing() -> void:
 if not playing or not is_instance_valid(holder) or not holder.is_inside_tree():return
 var landing=ctx.get("landing")
 if landing is Transform3D:holder.global_transform=landing*Transform3D(Basis.IDENTITY,ctx.get("offset",Vector3.ZERO))

## 持续到回合结束（清单 sustain:"turn"）：模块在 _build() 里按 ctx 判断后调用
## hold_until_turn_end()，到 budget 不收尾、继续 _frame；舞台收到回合结束时
## 调 release()，再播 release_seconds()（params.release_ms，缺省 450）后收尾。
## 卡牌离场时 holder 随卡牌释放，基类照常收尾。
var sustain_mode="none"
var sustaining=false
var releasing=false
var release_started=0.0

func hold_until_turn_end() -> bool:
 if sustain_mode!="turn":return false
 sustaining=true
 return true

func release_seconds() -> float:
 return maxf(float(params.get("release_ms",450.0))/1000.0,0.05)

func release() -> void:
 if not sustaining or releasing:return
 releasing=true
 release_started=elapsed

## 0（未收尾）→ 1（收尾完毕）。
func release_progress() -> float:
 if not releasing:return 0.0
 return clampf((elapsed-release_started)/release_seconds(),0.0,1.0)

func holds() -> bool:
 if not sustaining:return false
 return not releasing or elapsed<release_started+release_seconds()

## 只给本模块自己的节点用，绝不回写卡面材质。
func radial_plane(size_scale: Vector2,at_y: float,material: Material=null) -> MeshInstance3D:
 return make_plane(holder,Vector3(0.0,at_y,0.0),card_size()*size_scale,material)
