extends Node3D
signal object_selected(uid: int)
signal avatar_selected(who: int)
signal stack_selected(id: int)
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
var label_font: SystemFont
static var material_cache = {}

static func pile_height(count: int) -> float:
 return maxf(0,count) * LAYER_HEIGHT

func make_material(color: Color, tex: Texture2D = null) -> StandardMaterial3D:
 var key=str(color)+":"+str(tex.get_instance_id() if tex else 0)
 if material_cache.has(key): return material_cache[key]
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
 material_cache[key]=m
 return m

var duel
var reserved: Array=[]
var chosen: Array=[]
func build(engine, provider: Callable, mat_path: String, payment_reservations: Array=[], selection: Array=[]):
 duel=engine
 reserved=payment_reservations
 chosen=selection
 texture_provider=provider
 label_font=SystemFont.new()
 label_font.font_names=PackedStringArray(["Microsoft YaHei UI","Microsoft YaHei"])
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
 back_mat=make_material(Color.WHITE,load("res://assets/card_back.svg"))
 for who in range(2):
  var p=duel.players[who]
  var enemy=who==1
  var z=-1.0 if enemy else 1.0
  var side=-1.0 if enemy else 1.0
  pile("adeck" if enemy else "pdeck",p.deck.map(func(c): return c.card_id),Vector3(9.0*side,0,3.6*z),false,enemy)
  pile("agrave" if enemy else "pgrave",p.grave.map(func(c): return c.card_id),Vector3(9.0*side,0,0.4*z),true,enemy)
  surface_label("牌库",Vector3(9.0*side,0.04,5.15*z),Color("#d3c9b4"))
  surface_label("墓地",Vector3(9.0*side,0.04,1.9*z),Color("#d3c9b4"))
  if p.leader.zone=="leader":
   render_card(p.leader,Vector3(-8.7*side,0.04,3.4*z),enemy)
   if p.leader.timer>0: surface_label("计时 %d" % p.leader.timer,Vector3(-8.7*side,0.2,4.9*z),Color("#e9c871"))
  var unit_index=0
  var groups={}
  for c in p.field:
   if duel.is_unit(c):
    var x=-4.8+(unit_index%3)*2.4
    render_card(c,Vector3(x,0.08,(1.65+(unit_index/3)*2.3)*z),enemy)
    surface_label("%d / %d · %d" % [duel.cards[c.card_id].power,duel.cards[c.card_id].health-c.damage,duel.cards[c.card_id].spirit],Vector3(x,0.14,(2.8+(unit_index/3)*2.3)*z),Color("#f2dbac"),0.003)
    unit_index+=1
   else:
    var group=["164","165","167","170"].find(c.card_id)
    var n=groups.get(group,0)
    render_card(c,Vector3(-4.8+group*2.1+n*0.55,0.06+n*0.03,3.95*z),enemy,true)
    groups[group]=n+1
  var palette=p.palette
  for i in range(palette.size()):
   render_card(palette[i],Vector3(-5.8+(i%8)*1.62,0.08+(i/8)*0.09,5.65*z+(i/8)*0.35*z),enemy,true)
  if p.potato:
   render_card({"uid":-100-who,"card_id":"potato","tapped":false,"owner":who},Vector3(7.0*side,0.09,5.65*z),enemy,true)
  surface_label("人机  %d" % p.life if enemy else "你  %d" % p.life,Vector3(0,0.2,7.35*z),Color("#dbeafa") if enemy else Color("#f6d396"),0.005)
  var avatar=hitbox(Vector3(0,0.3,7.35*z),Vector3(3.2,0.5,0.8))
  avatar.set_meta("kind","avatar"); avatar.set_meta("who",who)
  if enemy:
   surface_label("手牌 %d" % p.hand.size(),Vector3(4.5,0.04,-7.35),Color("#bccbdd"),0.003)
 for i in range(duel.stack.size()):
  var entry=duel.stack[i]
  var id=entry.card.card_id if entry.kind=="card" else entry.source.card_id
  var at=Vector3(4.5+i*0.9,1.0+i*0.38,0.3+i*0.18)
  var mesh=plane(at,Vector2(2.2,3.08),face_material(id))
  mesh.rotation.x=deg_to_rad(35)
  mesh.rotation.y=deg_to_rad(-8)
  var area=hitbox(at,Vector3(2.2,0.12,3.08))
  area.rotation=mesh.rotation
  area.set_meta("kind","stack"); area.set_meta("stack_id",entry.id)
  area.set_meta("card_id",id)
 if not duel.stack.is_empty():
  surface_label("堆叠  %d" % duel.stack.size(),Vector3(5.9,0.2,3.0),Color("#edd394"),0.004)

func render_card(c: Dictionary,at: Vector3,enemy: bool,palette: bool=false):
 var is_reserved=reserved.any(func(r): return r.uid==c.uid)
 var tapped=c.tapped or is_reserved
 var size=CARD_SIZE*0.8 if palette else CARD_SIZE
 var mesh=plane(at,size,face_material(c.card_id))
 mesh.rotation.y=(PI if enemy else 0.0)+(PI/2 if tapped else 0.0)
 var area=hitbox(at,Vector3(size.x,0.15,size.y))
 area.rotation.y=mesh.rotation.y
 area.set_meta("kind","object"); area.set_meta("uid",c.uid)
 area.set_meta("card_id",c.card_id)
 if not duel.combat.is_empty() and (duel.combat.attacker.uid==c.uid or duel.combat.blockers.any(func(t): return t.uid==c.uid)):
  surface_label("攻击" if duel.combat.attacker.uid==c.uid else "阻挡",at+Vector3(0,0.19,0),Color("#ffbc78"),0.004)
 if c.uid in chosen or is_reserved:
  var outline=plane(at-Vector3(0,0.015,0),size+Vector2(0.17,0.17),make_material(Color("#e5bd62")))
  outline.rotation.y=mesh.rotation.y
 if palette:
  var colors=["任意"] if c.card_id=="potato" else duel.cards[c.card_id].colors
  surface_label(" / ".join(colors),at+Vector3(0,0.06,1.03),Color("#e9d6aa"),0.0025)
 if is_reserved: surface_label("预付",at+Vector3(0,0.12,0),Color("#ffe398"),0.003)

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
 l.font=label_font
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
    match hit.get_meta("kind",""):
     "object": call_deferred("emit_signal","object_selected",hit.get_meta("uid"))
     "avatar": call_deferred("emit_signal","avatar_selected",hit.get_meta("who"))
     "stack": call_deferred("emit_signal","stack_selected",hit.get_meta("stack_id"))
     "pile": call_deferred("emit_signal","pile_selected",hit.get_meta("zone"))
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




