extends "res://fx/fx_module.gd"
## 闪卡特效：贴在卡面上方的一层持续动态覆盖，不影响卡图、费用和输入。
##
## 契约
##  * parent 是花牌视觉根 Node3D；只允许在 y ≥ 0.019 处加平面
##    （0.018 是召唤失调雾层，0.06 是颜色六边形，别越界）；
##  * 不替换 Face 的 material_override，不读也不写卡图纹理；
##  * 持续播放，category=foil 时预算不做自动收尾，由 stop() 控制；
##  * 相位用 phase() 匀速循环，不用 TIME，保证录屏与回放一致。

const MIN_Y=0.019
const MAX_Y=0.055
const DEFAULT_CYCLE=2.4

func default_offset() -> Vector3:
 return Vector3(0.0,MIN_Y,0.0)

func card_size() -> Vector2:
 var value=ctx.get("card_size")
 return value if value is Vector2 and value.x>0.0 else Vector2(1.95,2.72)

func cycle_seconds() -> float:
 return clampf(float(params.get("cycle",DEFAULT_CYCLE)),0.4,30.0)

## 0..1 循环相位，缓动、镜像、扫光都用它。
func phase() -> float:
 var cycle=cycle_seconds()
 return fposmod(elapsed,cycle)/cycle

func sweep_position() -> float:
 return phase()

func foil_plane(size_scale: Vector2,at_y: float,material: Material=null) -> MeshInstance3D:
 var y=clampf(at_y,MIN_Y,MAX_Y)
 return make_plane(holder,Vector3(0.0,y,0.0),card_size()*size_scale,material)
