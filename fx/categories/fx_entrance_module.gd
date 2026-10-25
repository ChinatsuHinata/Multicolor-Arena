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

## 卡牌从堆叠飞到落点的时长，本体经 ctx.travel 传入；预览与单测没有时取 params.travel_ms。
func travel_seconds() -> float:
 return maxf(float(ctx.get("travel",float(params.get("travel_ms",420.0))/1000.0)),0.0)

## 卡牌落场时刻（模块时钟）。before 段的"进场后"部分从这里开始。
func land_seconds() -> float:
 return minf(travel_seconds(),budget) if timing=="before" else 0.0

func start() -> bool:
 var ok=super()
 pin_to_landing()
 return ok

func advance(delta: float) -> void:
 super(delta)
 pin_to_landing()

## ctx.landing 是落点的全局变换；有它时 holder 钉在落点，不随飞行中的卡牌移动。
func pin_to_landing() -> void:
 if not playing or not is_instance_valid(holder) or not holder.is_inside_tree():return
 var landing=ctx.get("landing")
 if landing is Transform3D:holder.global_transform=landing*Transform3D(Basis.IDENTITY,ctx.get("offset",Vector3.ZERO))

## 只给本模块自己的节点用，绝不回写卡面材质。
func radial_plane(size_scale: Vector2,at_y: float,material: Material=null) -> MeshInstance3D:
 return make_plane(holder,Vector3(0.0,at_y,0.0),card_size()*size_scale,material)
