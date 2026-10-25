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

## 只给本模块自己的节点用，绝不回写卡面材质。
func radial_plane(size_scale: Vector2,at_y: float,material: Material=null) -> MeshInstance3D:
 return make_plane(holder,Vector3(0.0,at_y,0.0),card_size()*size_scale,material)
