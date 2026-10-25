extends "res://fx/fx_module.gd"
## 符卡使用特效：符卡离开手牌进入堆叠/墓地之前，在台面上独立绽放。
##
## 契约
##  * parent 是特效根（fx_stage 的 spell 层），不是卡牌节点；卡牌此刻可能已翻面；
##  * 中心来自 ctx.center，尺寸来自 ctx.card_size，全部在世界坐标里算；
##  * 不碰任何卡牌节点、不碰堆叠与结算，纯表现；
##  * 时长超出 budget 由基类收尾，生命周期内必须自我清理。
##  * 角色符卡用 character_spell / character 参数，角色名缺省取 ctx.requires_character；
##  * 角色起点依次优先套牌自机、自机、颜色值高、卡牌 id 小、uid 小；
##  * 终点模式 destination 为 none 或 spell_target，目标世界坐标用 local_point() 转换。

const MIN_Y=0.02
const MAX_Y=0.06

var character_spell=false
var spell_character=""
var origin_mode="none"
var destination_mode="none"

func configure(def: Dictionary,context: Dictionary) -> void:
 super.configure(def,context)
 character_spell=def.get("character_spell",false)==true
 spell_character=str(def.get("character",""))
 if spell_character.is_empty():spell_character=str(ctx.get("requires_character",""))
 origin_mode=str(def.get("origin","character" if character_spell else "none"))
 destination_mode=str(def.get("destination","none"))

func caster() -> int:
 return int(ctx.get("owner",0))

func palette_character_spells() -> int:
 return maxi(int(ctx.get("palette_character_spells",0)),0)

## 角色符卡起始目标候选：施放者的、matching_uids 中的单位。
func origin_candidates() -> Array:
 var result: Array=[]
 for unit in ctx.get("units",[]):
  if not unit is Dictionary or int(unit.get("owner",-1))!=caster():continue
  if ctx.has("matching_uids"):
   if int(unit.get("uid",0)) in ctx.matching_uids:result.append(unit)
  else:
   var character=str(unit.get("character",""))
   if not character.is_empty() and (character==spell_character or character.begins_with(spell_character+"·") or character.begins_with(spell_character+"・")):result.append(unit)
 return result

static func rank_origins(list: Array) -> Array:
 var ranked=list.duplicate()
 ranked.sort_custom(func(a,b):
  var leader_a=bool(a.get("deck_leader",false));var leader_b=bool(b.get("deck_leader",false))
  if leader_a!=leader_b:return leader_a
  var self_a=str(a.get("kind",""))=="自机";var self_b=str(b.get("kind",""))=="自机"
  if self_a!=self_b:return self_a
  var color_a=int(a.get("color_value",0));var color_b=int(b.get("color_value",0))
  if color_a!=color_b:return color_a>color_b
  var card_a=str(a.get("card_id",""));var card_b=str(b.get("card_id",""))
  if card_a!=card_b:return card_a<card_b
  return int(a.get("uid",0))<int(b.get("uid",0)))
 return ranked

func origin_unit() -> Dictionary:
 if origin_mode!="character" or not character_spell:return {}
 var ranked=rank_origins(origin_candidates())
 return {} if ranked.is_empty() else ranked[0]

func has_origin() -> bool:
 return not origin_unit().is_empty()

func origin_position() -> Vector3:
 return origin_unit().get("position",center()) if has_origin() else center()

func destinations() -> Array[Vector3]:
 var result: Array[Vector3]=[]
 if destination_mode!="spell_target":return result
 for target in ctx.get("targets",[]):
  if target is Dictionary and target.get("position") is Vector3:result.append(target.position)
 return result

func local_point(world: Vector3) -> Vector3:
 return holder.to_local(world) if is_instance_valid(holder) else world

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
