extends "res://fx/fx_module.gd"
## 符卡使用特效：符卡离开手牌进入堆叠/墓地之前，在台面上独立绽放。
##
## 契约
##  * parent 是特效根（fx_stage 的 spell 层），不是卡牌节点；卡牌此刻可能已翻面；
##  * 中心来自 ctx.center，尺寸来自 ctx.card_size，全部在世界坐标里算；
##  * 不碰任何卡牌节点、不碰堆叠与结算，纯表现；
##  * 时长超出 budget 由基类收尾，生命周期内必须自我清理。

const MIN_Y=0.02
const MAX_Y=0.06

func default_offset() -> Vector3:
 return Vector3(0.0,MIN_Y,0.0)

func card_size() -> Vector2:
 var value=ctx.get("card_size")
 return value if value is Vector2 and value.x>0.0 else Vector2(1.95,2.72)

func center() -> Vector3:
 var value=ctx.get("center")
 return value if value is Vector3 else Vector3.ZERO

## 0 → 1 → 0 的绽放强度，和 offset 一致：使用瞬间最亮，随后扩散消散。
func burst() -> float:
 var t=progress()
 return pow(1.0-t,2.0)*pow(minf(t*6.0,1.0),1.0)

func spell_plane(size_scale: Vector2,at_y: float,material: Material=null) -> MeshInstance3D:
 var y=clampf(at_y,MIN_Y,MAX_Y)
 return make_plane(holder,Vector3(0.0,y,0.0),card_size()*size_scale,material)
