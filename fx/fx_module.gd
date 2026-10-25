extends Node
## Shared base for every module under fx/modules/.
##
## Three rules keep an effect replaceable, and this base enforces them:
##  * the module clock (`elapsed`) is the only time source. Shaders take a
##    `progress` uniform instead of TIME, so replays and manual stepping in
##    tests see exactly the same frame;
##  * every node a module builds lives under `holder`, which the base frees;
##  * a module reads nothing from the duel engine. Its whole world is `ctx`,
##    built by fx_bridge.gd from a card descriptor.

signal done(id: String)

const CATEGORIES=["entrance","foil","spell"]
const DEFAULT_BUDGET_MS=700
const MAX_NODES=64
const MAX_BUDGET_MS=5000

var id=""
var category=""
var params: Dictionary={}
var ctx: Dictionary={}
var budget=0.7
var elapsed=0.0
var playing=false
var finished=false
var auto_advance=true
var holder: Node3D
var rng=RandomNumberGenerator.new()
var warnings: Array[String]=[]
var asset_dir=""
var _textures={}
var _stop_notified=false

func configure(def: Dictionary,context: Dictionary) -> void:
 id=str(def.get("id",""))
 category=str(def.get("category","entrance"))
 var raw=def.get("params",{})
 params=raw.duplicate(true) if raw is Dictionary else {}
 budget=clampf(float(def.get("budget_ms",DEFAULT_BUDGET_MS))/1000.0,0.05,float(MAX_BUDGET_MS)/1000.0)
 asset_dir=str(def.get("asset_dir","res://fx/assets/"+id+"/"))
 ctx=context.duplicate(true)
 if not ctx.has("offset"):ctx["offset"]=default_offset()
 rng.seed=hash("%s:%d" % [id,int(ctx.get("uid",0))])
 set_process(false)

func start() -> bool:
 if playing:return true
 var parent=ctx.get("parent")
 if not parent is Node or not is_instance_valid(parent):
  warnings.append("ctx.parent is missing")
  return false
 holder=Node3D.new()
 holder.name="Fx_"+id
 holder.position=ctx.get("offset",default_offset())
 parent.add_child(holder)
 playing=true;finished=false;elapsed=0.0;_stop_notified=false
 if not _build():
  warnings.append("_build() returned false")
  stop()
  return false
 var nodes=count_nodes(holder)
 if nodes>MAX_NODES:
  warnings.append("node budget exceeded: %d" % nodes)
  stop()
  return false
 set_process(auto_advance)
 _frame(0.0)
 return true

func advance(delta: float) -> void:
 if not playing:return
 # 父节点（卡牌视觉）被释放后 holder 会随之消失，模块必须自行收尾，
 # 否则它作为舞台的子节点会一直留着。闪卡常驻，所以这里不能只看 budget。
 if not is_instance_valid(holder) or not holder.is_inside_tree():
  finished=true
  stop()
  return
 elapsed+=delta
 _frame(delta)
 if category!="foil" and elapsed>=budget and not holds():
  finished=true
  stop()

func stop() -> void:
 playing=false
 set_process(false)
 if is_instance_valid(holder):holder.queue_free()
 holder=null
 if _stop_notified:return
 _stop_notified=true
 done.emit(id)

func progress() -> float:
 if budget<=0.0:return 1.0
 return clampf(elapsed/budget,0.0,1.0)

func count_nodes(node: Node) -> int:
 var total=0
 for child in node.get_children():
  total+=1+count_nodes(child)
 return total

## Overridable. `_build()` adds nodes under `holder`; `_frame()` animates them.
func _build() -> bool:return true
func _frame(_delta: float) -> void:pass
func default_offset() -> Vector3:return Vector3.ZERO
## 返回 true 时到 budget 也不收尾（入场的 sustain 用）。
func holds() -> bool:return false

func _process(delta: float) -> void:
 advance(delta)

func additive_material(color: Color=Color.WHITE) -> StandardMaterial3D:
 var mat=StandardMaterial3D.new()
 mat.albedo_color=color
 mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
 mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
 mat.blend_mode=BaseMaterial3D.BLEND_MODE_ADD
 mat.cull_mode=BaseMaterial3D.CULL_DISABLED
 return mat

func make_plane(parent: Node3D,at: Vector3,size: Vector2,material: Material=null) -> MeshInstance3D:
 var shape=PlaneMesh.new();shape.size=size
 var node=MeshInstance3D.new();node.mesh=shape;node.position=at
 if material!=null:node.material_override=material
 parent.add_child(node)
 return node

## 生图素材只从这里进来。文件放在 asset_dir 下，按文件名取；缺失时记一条
## warning 并返回 null，模块必须能靠纯几何/纯色继续跑（无素材降级是硬要求）。
func texture(file_name: String) -> Texture2D:
 if _textures.has(file_name):return _textures[file_name]
 var path=asset_dir+file_name if asset_dir.ends_with("/") else asset_dir+"/"+file_name
 var loaded: Texture2D=null
 if ResourceLoader.exists(path,"Texture2D"):
  loaded=load(path) as Texture2D
 elif FileAccess.file_exists(path):
  var image=Image.new()
  if image.load(path)==OK and not image.is_empty():loaded=ImageTexture.create_from_image(image)
 _textures[file_name]=loaded
 if loaded==null:warnings.append("missing or unreadable asset: "+path)
 return loaded

## 带贴图的平面（加法混合）。uv_scale 用材质 uv1_scale 做重复，不改网格尺寸。
func sprite_plane(parent: Node3D,at: Vector3,size: Vector2,file_name: String,tint: Color=Color.WHITE,uv_scale: Vector2=Vector2.ONE) -> MeshInstance3D:
 var tex=texture(file_name)
 var mat=additive_material(tint)
 if tex!=null:
  mat.albedo_texture=tex
  mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
 mat.uv1_scale=Vector3(uv_scale.x,uv_scale.y,1.0)
 return make_plane(parent,at,size,mat)
