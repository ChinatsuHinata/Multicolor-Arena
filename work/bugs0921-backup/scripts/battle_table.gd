extends Node3D
signal field_selected(index: int, enemy: bool)
signal pile_selected(zone: String)
const LAYER_HEIGHT = 0.026
const CARD_SIZE = Vector2(1.52, 2.12)
var camera: Camera3D
var card_materials = {}
var texture_provider: Callable
var board_mat: StandardMaterial3D
var back_mat: StandardMaterial3D
var board: MeshInstance3D
var stack_heights = {}
var camera_distance = 0.82

static func pile_height(count: int) -> float:
 return maxf(0,count) * LAYER_HEIGHT

func make_material(color: Color, tex: Texture2D = null) -> StandardMaterial3D:
 var m=StandardMaterial3D.new()
 m.albedo_color=color
 if tex!=null:
  var image=tex.get_image()
  if not image.has_mipmaps(): image.generate_mipmaps()
  m.albedo_texture=ImageTexture.create_from_image(image)
  m.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
  m.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
 m.roughness=0.82
 m.cull_mode=BaseMaterial3D.CULL_DISABLED
 return m

func build(state: Dictionary, player: Dictionary, bot: Dictionary, provider: Callable, mat_path: String):
 texture_provider=provider
 var world=WorldEnvironment.new()
 var env=Environment.new()
 env.background_mode=Environment.BG_COLOR
 env.background_color=Color("#090e19")
 env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
 env.ambient_light_color=Color("#c7d6ef")
 env.ambient_light_energy=0.72
 env.tonemap_mode=Environment.TONE_MAPPER_LINEAR
 world.environment=env
 add_child(world)
 var light=DirectionalLight3D.new()
 light.rotation_degrees=Vector3(-60,-28,0)
 light.light_energy=1.15
 light.shadow_enabled=true
 add_child(light)
 camera=Camera3D.new()
 camera.position=Vector3(0,20.8,17.2)*camera_distance
 camera.fov=46
 camera.near=0.1
 camera.far=90
 add_child(camera)
 camera.look_at(Vector3(0,0,2.0))
 camera.current=true
 var mat_tex=load(mat_path) as Texture2D
 board_mat=make_material(Color.WHITE,mat_tex)
 var table=MeshInstance3D.new()
 var table_mesh=BoxMesh.new()
 table_mesh.size=Vector3(22.4,0.32,16.4)
 table.mesh=table_mesh
 table.position.y=-0.19
 table.material_override=make_material(Color("#302b35"))
 add_child(table)
 board=plane(Vector3(0,0,0),Vector2(22,16),board_mat)
 board.name="Playmat3"
 back_mat=make_material(Color.WHITE,texture_provider.call("back"))
 pile("pdeck",state.pdeck,Vector3(8.6,0,2.85),false)
 pile("adeck",state.adeck,Vector3(-8.6,0,-2.85),false,true)
 pile("pgrave",state.pgrave,Vector3(8.6,0,5.7),true)
 pile("agrave",state.agrave,Vector3(-8.6,0,-5.7),true,true)
 pile("pside",player.side,Vector3(-8.6,0,5.7),false)
 pile("aside",bot.side,Vector3(8.6,0,-5.7),false,true)
 single_card(player.leader,Vector3(-8.6,0.04,2.85),false,-1)
 single_card(bot.leader,Vector3(8.6,0.04,-2.85),true,-1)
 for i in range(state.pfield.size()):
  single_card(state.pfield[i],Vector3(-5.0+i*2,0.04,1.1),false,i,i in state.attacked)
 for i in range(state.afield.size()):
  single_card(state.afield[i],Vector3(-5.0+i*2,0.04,-1.5),true,i)
 surface_label("你  %d" % state.php,Vector3(0,0.04,5.9),Color("#e7c88f"),0.006)
 surface_label("人机  %d" % state.ahp,Vector3(0,0.04,-5.9),Color("#c8d8ed"),0.006)
 surface_label("备牌 %d" % player.side.size(),Vector3(-8.6,0.04,7.05),Color("#b7c6d8"))
 surface_label("备牌 %d" % bot.side.size(),Vector3(8.6,0.04,-7.05),Color("#b7c6d8"))

func plane(at: Vector3, dimensions: Vector2, material: Material) -> MeshInstance3D:
 var mesh=MeshInstance3D.new()
 var shape=PlaneMesh.new()
 shape.size=dimensions
 mesh.mesh=shape
 mesh.material_override=material
 mesh.position=at
 add_child(mesh)
 return mesh

func face_material(id: String) -> Material:
 if not card_materials.has(id):
  card_materials[id]=make_material(Color.WHITE,texture_provider.call(id))
 return card_materials[id]

func single_card(id: String, at: Vector3, enemy: bool, index: int, tapped: bool=false):
 var mesh=plane(at,CARD_SIZE,face_material(id))
 mesh.name=("Enemy" if enemy else "Player")+"Card"+str(index)
 mesh.rotation.y=PI if enemy else 0.0
 if tapped: mesh.rotation.y+=PI/2
 var base=MeshInstance3D.new()
 var shape=BoxMesh.new()
 shape.size=Vector3(CARD_SIZE.x,0.035,CARD_SIZE.y)
 base.mesh=shape
 base.material_override=make_material(Color("#d8cbb4"))
 base.position=at-Vector3(0,0.022,0)
 base.rotation.y=mesh.rotation.y
 add_child(base)
 var hit=hitbox(at,Vector3(CARD_SIZE.x,0.1,CARD_SIZE.y))
 hit.rotation.y=mesh.rotation.y
 hit.set_meta("kind","field")
 hit.set_meta("index",index)
 hit.set_meta("enemy",enemy)

func pile(zone: String, ids: Array, at: Vector3, face_up: bool, enemy: bool=false):
 var count=ids.size()
 var height=pile_height(count)
 stack_heights[zone]=height
 if count>0:
  var layers=MultiMeshInstance3D.new()
  var mm=MultiMesh.new()
  mm.transform_format=MultiMesh.TRANSFORM_3D
  var layer=BoxMesh.new()
  layer.size=Vector3(CARD_SIZE.x, LAYER_HEIGHT*0.85, CARD_SIZE.y)
  mm.mesh=layer
  mm.instance_count=count
  for i in range(count):
   mm.set_instance_transform(i,Transform3D(Basis.IDENTITY,at+Vector3(0,LAYER_HEIGHT*(i+0.5),0)))
  layers.multimesh=mm
  layers.material_override=make_material(Color("#c7c1b2"))
  layers.name=zone+"_layers_"+str(count)
  add_child(layers)
  var top=plane(at+Vector3(0,height+0.003,0),CARD_SIZE,face_material(ids.back()) if face_up else back_mat)
  top.rotation.y=PI if enemy else 0.0
 var area=hitbox(at+Vector3(0,maxf(height,0.05)/2,0),Vector3(CARD_SIZE.x,maxf(height,0.1),CARD_SIZE.y))
 area.set_meta("kind","pile")
 area.set_meta("zone",zone)
 surface_label(str(count),at+Vector3(0,height+0.06,1.42),Color("#f1dfb5"))

func hitbox(at: Vector3, dimensions: Vector3) -> Area3D:
 var area=Area3D.new()
 area.position=at
 var collision=CollisionShape3D.new()
 var shape=BoxShape3D.new()
 shape.size=dimensions
 collision.shape=shape
 area.add_child(collision)
 area.input_ray_pickable=true
 add_child(area)
 return area

func surface_label(text: String, at: Vector3, color: Color, pixel: float=0.004):
 var l=Label3D.new()
 l.text=text
 var font=SystemFont.new()
 font.font_names=PackedStringArray(["Microsoft YaHei UI","Microsoft YaHei"])
 l.font=font
 l.font_size=72
 l.pixel_size=pixel
 l.modulate=color
 l.outline_size=8
 l.position=at
 l.rotation_degrees.x=-90
 add_child(l)

func _input(event):
 if event is InputEventMouseButton and event.pressed:
  if event.button_index==MOUSE_BUTTON_LEFT:
   var from=camera.project_ray_origin(event.position)
   var ray=PhysicsRayQueryParameters3D.create(from,from+camera.project_ray_normal(event.position)*100)
   ray.collide_with_areas=true
   ray.collide_with_bodies=false
   var result=get_world_3d().direct_space_state.intersect_ray(ray)
   if not result.is_empty():
    var hit=result.collider
    if hit.get_meta("kind","")=="field" and hit.get_meta("index",-1)>=0: call_deferred("emit_signal","field_selected",hit.get_meta("index"),hit.get_meta("enemy"))
    elif hit.get_meta("kind","")=="pile": call_deferred("emit_signal","pile_selected",hit.get_meta("zone"))
   return
  if event.button_index==MOUSE_BUTTON_WHEEL_UP: camera_distance=maxf(0.78,camera_distance-0.04)
  elif event.button_index==MOUSE_BUTTON_WHEEL_DOWN: camera_distance=minf(1.2,camera_distance+0.04)
  else: return
  camera.position=Vector3(0,20.8,17.2)*camera_distance
  camera.look_at(Vector3(0,0,2.0))


var inspect_root: Node3D
var inspect_page=0
func inspect_cards(ids: Array):
 if is_instance_valid(inspect_root):
  inspect_root.queue_free()
  inspect_root=null
  inspect_page+=1
 if ids.is_empty(): return
 if inspect_page*10>=ids.size(): inspect_page=0
 inspect_root=Node3D.new()
 add_child(inspect_root)
 var start=inspect_page*10
 for i in range(start,mini(start+10,ids.size())):
  var j=i-start
  var mesh=plane(Vector3(-4.0+(j%5)*2.0,0.6,-1.3+(j/5)*2.5),CARD_SIZE,face_material(ids[i]))
  mesh.reparent(inspect_root)




