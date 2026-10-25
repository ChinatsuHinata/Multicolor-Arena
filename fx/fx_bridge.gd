extends RefCounted
## 本体与特效之间的唯一接口。本体只在三处调用这里：
##   unit_entered()      单位进入战场、卡牌视觉刚建好时（入场）
##   unit_landed()       飞行接管的单位落场、3D 卡已建好时
##   owns_flight()       是否有模块已接管飞行画面
##   flight_seconds()    已接管模块中的最长飞行秒数
##   card_face_built()   卡面材质建立或切换异画后（闪卡）
##   spell_resolved()    符卡结算、未被反制且目标未失效时（符卡）
## 除此之外本体不认识任何特效 id、材质或节点名。
##
## 接线示例（各一行，只在首次接入时加）：
##   var fx=FxBridge.new();fx.attach(self);fx.set_products(battle_products)
##   fx.unit_entered(node,d)            # d 是 duel_table 的 descriptor
##   fx.card_face_built(node,d)
##   fx.spell_resolved(node,d)

const Stage=preload("res://fx/fx_stage.gd")
const Registry=preload("res://fx/fx_registry.gd")

var stage: Node3D
var registry
var products: Dictionary={}
var owner_products: Array=[]
var enabled=true
var host: Node

func attach(parent: Node) -> Node3D:
 if is_instance_valid(stage):return stage
 registry=Registry.new()
 stage=Stage.new();stage.name="FxStage"
 stage.use_registry(registry)
 parent.add_child(stage)
 return stage

func set_products(loadout: Dictionary) -> void:
 products=loadout.duplicate(true)

func set_owner_products(loadouts: Array) -> void:
 owner_products=loadouts.duplicate(true)

func products_for(owner: int) -> Dictionary:
 if owner<0 or owner>=owner_products.size():return products
 var result={}
 for id in owner_products[owner]:result[id]={}
 return result

func card_context(node: Node3D,card_size: Vector2) -> Dictionary:
 return {"parent":node,"card_size":card_size,"node":node}

func unit_entered(node: Node3D,card_size: Vector2,extra: Dictionary={}) -> Array:
 if not enabled or not is_instance_valid(stage):return []
 var ctx=card_context(node,card_size)
 ctx.merge(extra,true)
 return stage.play("entrance",ctx,products_for(int(ctx.get("owner",-1))))

func card_face_built(node: Node3D,card_size: Vector2,extra: Dictionary={}) -> Array:
 if not enabled or not is_instance_valid(stage):return []
 var ctx=card_context(node,card_size)
 ctx.merge(extra,true)
 return stage.play("foil",ctx,products_for(int(ctx.get("owner",-1))))

func unit_landed(uid: int) -> void:
 if not enabled or not is_instance_valid(stage):return
 stage.landed(uid)

func owns_flight(modules: Array) -> bool:
 for module in modules:
  if is_instance_valid(module) and module.has_method("owns_flight") and module.owns_flight():return true
 return false

func flight_seconds(modules: Array) -> float:
 var seconds=0.0
 for module in modules:
  if is_instance_valid(module) and module.has_method("owns_flight") and module.owns_flight():seconds=maxf(seconds,module.flight_seconds())
 return seconds

func spell_resolved(node: Node3D,card_size: Vector2,extra: Dictionary={}) -> Array:
 if not enabled or not is_instance_valid(stage):return []
 var center=extra.get("center",node.global_position if is_instance_valid(node) else Vector3.ZERO)
 var ctx={"parent":null,"card_size":card_size,"node":node,"center":center}
 ctx.merge(extra,true)
 return stage.play("spell",ctx,products_for(int(ctx.get("owner",-1))))

## 单张卡离场：入场与闪卡都挂在卡牌节点下，节点释放即消失，这里只需收尾
## 那些以舞台为父节点的（符卡）特效。
func card_released(_uid: int) -> void:
 pass

func clear() -> void:
 if is_instance_valid(stage):stage.clear()
