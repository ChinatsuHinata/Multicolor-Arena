extends SceneTree
## 单特效预览：不开对战、不读卡组、不依赖任何本体脚本，只把 fx/ 里的一个
## 特效放进一个迷你台面里跑起来。用来做开发时的视觉确认与截图。
##
##   Godot --path . --script fx/fx_showcase.gd
##   Godot --path . --script fx/fx_showcase.gd -- --only=<id>
##   Godot --path . --script fx/fx_showcase.gd -- --only=<id> --png=work/fx/preview.png
##   --count=<n> 设置模拟双方颜色盘中的角色符卡数，缺省 6。
## 无 --only 时轮流播放全部特效。--png 需要非 headless 的渲染后端。

const Registry=preload("res://fx/fx_registry.gd")
const Stage=preload("res://fx/fx_stage.gd")
const CARD_SIZE=Vector2(1.95,2.72)

var registry
var stage: Node3D
var card: Node3D
var modules: Array[Node]=[]
var index=0
var clock=0.0
var capture_path=""
var capture_at=-1.0
var showcase_count=6
var capturing=false
var only=""
var camera: Camera3D

func _initialize() -> void:
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--only="):only=arg.trim_prefix("--only=")
  if arg.begins_with("--png="):capture_path=arg.trim_prefix("--png=")
  if arg.begins_with("--at="):capture_at=float(arg.trim_prefix("--at="))
  if arg.begins_with("--count="):showcase_count=int(arg.trim_prefix("--count="))
 registry=Registry.new()
 registry.allow_all=true
 registry.reload(true)
 if not registry.errors.is_empty():
  for error in registry.errors:push_error("%s: %s" % [error.file,error.reason])
 build_scene()
 call_deferred("play_index",0)

func build_scene() -> void:
 var root_node=Node3D.new()
 root_node.name="FxShowcase"
 root.add_child(root_node)

 var sun=DirectionalLight3D.new()
 sun.rotation_degrees=Vector3(-62.0,-38.0,0.0)
 sun.light_energy=1.1
 root_node.add_child(sun)

 card=MeshInstance3D.new()
 var face=PlaneMesh.new();face.size=CARD_SIZE
 card.mesh=face
 var paper=StandardMaterial3D.new()
 paper.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
 paper.albedo_color=Color("#6b5566")
 card.material_override=paper
 card.position.y=0.0
 root_node.add_child(card)

 var mat_mesh=MeshInstance3D.new()
 var mat_plane=PlaneMesh.new();mat_plane.size=Vector2(9.0,9.0)
 mat_mesh.mesh=mat_plane
 var mat=StandardMaterial3D.new()
 mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
 mat.albedo_color=Color("#33202f")
 mat_mesh.material_override=mat
 mat_mesh.position.y=-0.02
 root_node.add_child(mat_mesh)

 camera=Camera3D.new()
 camera.position=Vector3(0.0,5.4,4.6)
 camera.rotation_degrees=Vector3(-52.0,0.0,0.0)
 camera.fov=42.0
 root_node.add_child(camera)

 stage=Stage.new()
 stage.name="FxStage"
 stage.auto_step=true
 stage.use_registry(registry)
 root_node.add_child(stage)

func play_index(value: int) -> void:
 if stage==null:return
 stage.set_process(false)
 stage.stop_all()
 modules.clear()
 clock=0.0
 card.visible=true
 var all: Array=[]
 for category in ["entrance","foil","spell"]:
  for def in registry.by_category(category):
   if only.is_empty() or str(def.id)==only:all.append(def)
 if all.is_empty():
  push_error("no effect matches --only="+only)
  quit(1)
  return
 index=value%all.size()
 var def=all[index]
 var ctx={"parent":null if str(def.category)=="spell" else card,"card_size":CARD_SIZE,"uid":1,"card_id":"showcase"}
 card.position=Vector3(0.0,0.0,-1.4) if str(def.category)=="spell" else Vector3.ZERO
 if str(def.category)=="entrance" and Registry.timing(def)=="before":
  ctx.parent=null
  ctx["landing"]=card.global_transform
  ctx["travel"]=(float(def.flight_ms) if def.has("flight_ms") else float(def.get("params",{}).get("travel_ms",300)))/1000.0
  if Registry.flight(def) in ["track","proxy"]:
   ctx["flight"]={"from":showcase_flight_source(),"to":card.global_transform,"seconds":ctx.travel,"ease":str(def.get("flight_ease","cubic_in_out")),"color":Color("#8a6d80")}
  card.visible=false
 if str(def.category)=="spell":
  ctx.merge({
   "owner":0,"requires_character":str(def.get("character","")),
   "center":Vector3(0.0,0.0,1.6),
   "units":[
    {"uid":11,"card_id":"showcase_leader","owner":0,"zone":"field","deck_leader":true,"kind":"自机","character":str(def.get("character","")),"color_value":3,"position":Vector3(-2.1,0.0,1.1)},
    {"uid":12,"card_id":"showcase_unit","owner":0,"zone":"field","deck_leader":false,"kind":"单位","character":str(def.get("character","")),"color_value":5,"position":Vector3(2.1,0.0,1.1)},
    {"uid":21,"card_id":"showcase_foe","owner":1,"zone":"field","deck_leader":false,"kind":"单位","character":"","color_value":2,"position":Vector3(0.0,0.0,-1.4)}],
   "targets":[{"uid":21,"position":Vector3(0.0,0.0,-1.4)}],
   "palette_character_spells":showcase_count},true)
 var started=stage.play(str(def.category),ctx)
 modules.append_array(started)
 for module in modules:
  module.auto_advance=false

func showcase_flight_source() -> Transform3D:
 var viewport_size=root.get_visible_rect().size
 var point=viewport_size*Vector2(0.86,0.28)
 var pixel_height=viewport_size.y*0.30
 var origin=camera.project_ray_origin(point);var dir=camera.project_ray_normal(point)
 var hit=Plane(Vector3.UP,card.global_position.y).intersects_ray(origin,dir)
 var reach=origin.distance_to(hit) if hit!=null else 10.0
 var at=origin+dir*reach*0.5
 var cam=camera.global_basis
 var up_px=camera.unproject_position(at).distance_to(camera.unproject_position(at+cam.y))
 var k=pixel_height/maxf(up_px*CARD_SIZE.y,0.001)
 var basis=Basis(cam.x,cam.z,-cam.y).scaled(Vector3(k,k,k))
 return Transform3D(basis,at)

func _process(delta: float) -> bool:
 if modules.is_empty():return true
 if capturing:return false
 var longest=0.0
 for module in modules:
  if is_instance_valid(module):longest=maxf(longest,module.budget)
 var peak=capture_at if capture_at>=0.0 else peak_seconds()
 var step=minf(delta,maxf(peak-clock,0.0)) if not capture_path.is_empty() else delta
 clock+=step
 for module in modules:
  if is_instance_valid(module):module.advance(step)
 if not card.visible:
  for module in modules:
   if is_instance_valid(module) and module.category=="entrance" and clock>=float(module.ctx.get("travel",0.0)):
    card.visible=true
    stage.landed(1)
    break
 if not capture_path.is_empty():
  # 抓帧默认落在演出峰值：入场/符卡取预算的 35%，闪卡取周期的 25%。
  if clock>=peak:capture()
  return false
 if clock>longest+0.8:play_index(index+1)
 return false

func peak_seconds() -> float:
 for module in modules:
  if not is_instance_valid(module):continue
  if str(module.category)=="foil":return module.cycle_seconds()*0.25
  return module.budget*0.35
 return 0.3

func capture() -> void:
 if capturing:return
 capturing=true
 # 抓帧请求发生在动画帧内，本帧的 3D 还没提交；等一帧再读帧缓冲。
 await process_frame
 var image=root.get_texture().get_image()
 if image==null:
  push_error("no framebuffer to capture; run without --headless")
  quit(1)
  return
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(capture_path.get_base_dir()))
 image.save_png(capture_path)
 print("FX SHOWCASE saved ",capture_path)
 quit(0)
