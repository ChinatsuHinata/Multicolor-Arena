extends Node3D
## One persistent world per duel. Moving cards reuse their meshes and collision objects.
signal object_selected(uid: int)
signal avatar_selected(who: int)
signal stack_selected(id: int)
signal pile_selected(zone: String)
signal card_inspected(id: String, uid: int, caption: String)
signal combat_animation_finished
signal combat_impact(attacker_uid: int,blocker_uid: int)
signal empty_right_clicked
const LAYER_HEIGHT=0.012
const SLOT_SCALE=0.82
const BOARD_SIZE=Vector2(23,16)
# Normalized centers measured from the printed zones on playmat 3.
const MAT_SLOTS={"exile":Vector2(1070.0/1200.0,590.0/1200.0),"deck":Vector2(1070.0/1200.0,809.0/1200.0),"grave":Vector2(1070.0/1200.0,1027.0/1200.0),"leader":Vector2(124.0/1200.0,809.0/1200.0)}
const CARD_SIZE=Vector2(1.95,2.72)
var camera: Camera3D
var board: MeshInstance3D
var camera_distance=0.85
var duel
var texture_provider: Callable
var materials={}
var visuals={}
var descriptors={}
var piles={}
var stack_heights={}
var tweens={}
var old_cards={}
var reserved=[]
var chosen=[]
var highlighted=[]
var inspect_root: Node3D
var inspect_page=0
var animation_count=0
var last_combat={}
var busy_until=0
var animation_duration=0.42
var combat_animating=false
var deferred_sync={}
var collision_count=0
var last_collision_targets=[]

static func pile_height(count: int) -> float:
 return maxi(count,0)*LAYER_HEIGHT

func material(id: String) -> StandardMaterial3D:
 if materials.has(id): return materials[id]
 var m=StandardMaterial3D.new()
 m.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
 m.cull_mode=BaseMaterial3D.CULL_DISABLED
 m.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
 if id.begins_with("#"):
  m.albedo_color=Color(id)
 elif id=="back": m.albedo_texture=load("res://assets/card_back.svg")
 else: m.albedo_texture=texture_provider.call(id)
 materials[id]=m
 return m

func plane(parent: Node3D, at: Vector3, dimensions: Vector2, mat: Material) -> MeshInstance3D:
 var node=MeshInstance3D.new()
 var shape=PlaneMesh.new(); shape.size=dimensions
 node.mesh=shape; node.material_override=mat; node.position=at
 parent.add_child(node)
 return node

func area(parent: Node3D, at: Vector3, dimensions: Vector3) -> Area3D:
 var hit=Area3D.new(); hit.position=at
 var collision=CollisionShape3D.new()
 var shape=BoxShape3D.new(); shape.size=dimensions
 collision.shape=shape; hit.add_child(collision); parent.add_child(hit)
 return hit

func build(engine, provider: Callable, mat_path: String, payment_reservations: Array=[], selection: Array=[]):
 duel=engine; texture_provider=provider
 var world=WorldEnvironment.new()
 var env=Environment.new(); env.background_mode=Environment.BG_COLOR
 env.background_color=Color("#09121d")
 env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
 env.ambient_light_color=Color.WHITE; env.ambient_light_energy=0.7
 world.environment=env; add_child(world)
 camera=Camera3D.new(); camera.fov=33; camera.near=0.1; camera.far=90
 add_child(camera); set_camera()
 camera.current=true
 var mat=StandardMaterial3D.new()
 mat.albedo_texture=load(mat_path); mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
 mat.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
 board=plane(self,Vector3.ZERO,BOARD_SIZE,mat); board.name="Playmat3"
 sync(payment_reservations,selection,[],false)

func set_camera():
 camera.position=Vector3(0,23.5,18)*camera_distance+Vector3(-2,0,0)
 camera.look_at(Vector3(-2,0,0.5))

func zone_position(zone: String, who: int) -> Vector3:
 var side=1.0 if who==0 else -1.0
 var slot="leader" if zone=="return_pending" else zone
 if MAT_SLOTS.has(slot):
  var uv=MAT_SLOTS[slot]
  return Vector3((uv.x-0.5)*BOARD_SIZE.x*side,0.035,(uv.y-0.5)*BOARD_SIZE.y*side)
 match zone:
  "hand": return Vector3(0,1,10*side)
  "palette": return Vector3(0,0.035,5.7*side)
 return Vector3.ZERO

func card_snapshot() -> Dictionary:
 var result={}
 for p in duel.players:
  result[p.leader.uid]=p.leader.duplicate(true)
  for zone in ["deck","hand","field","palette","grave","exile"]:
   for c in p[zone]: result[c.uid]=c.duplicate(true)
 for entry in duel.stack:
  if entry.kind=="card": result[entry.card.uid]=entry.card.duplicate(true)
 return result

func description(c: Dictionary, at: Vector3, scale_value: float=1.0) -> Dictionary:
 var tapping=c.tapped or reserved.any(func(r): return r.uid==c.uid)
 return {"key":"card_"+str(c.uid),"card_id":c.card_id,"uid":c.uid,"owner":c.owner,"zone":c.get("zone","palette"),"at":at,"rotation":Vector3(0,PI/2 if tapping else 0,0),"scale":Vector3.ONE*scale_value,"kind":"object","tapped":tapping,"blue":c.uid in highlighted,"gold":c.uid in chosen or reserved.any(func(r): return r.uid==c.uid)}

func layout() -> Dictionary:
 var result={}
 for who in range(2):
  var p=duel.players[who]
  var side=1.0 if who==0 else -1.0
  if p.leader.zone in ["leader","return_pending"]:
   var d=description(p.leader,zone_position("leader",who),SLOT_SCALE); result[d.key]=d
  var unit_index=0
  var item_groups={}
  for c in p.field:
   var d
   if duel.is_unit(c):
    var crowded=duel.units(who).size()>6
    var columns=maxi(6,ceili(duel.units(who).size()/2.0)) if crowded else 6
    var at=Vector3(-6.2+(unit_index%columns)*12.3/maxi(5,columns-1),0.035,(1.05+(unit_index/columns)*1.7)*side) if crowded else Vector3(-6.2+unit_index*2.46,0.035,1.65*side)
    d=description(c,at,0.62 if crowded else 0.95); unit_index+=1
   else:
    var group=["164","165","167","170"].find(c.card_id)
    if group<0: group=3
    var n=item_groups.get(group,0)
    d=description(c,Vector3(-4.8+group*2.7+n*0.25,0.035+n*0.028,3.9*side),0.48)
    item_groups[group]=n+1
   if c.uid in chosen: d.at.y+=0.055
   result[d.key]=d
  for i in range(p.palette.size()):
   var d=description(p.palette[i],Vector3(-6.1+(i%8)*1.67,0.035+(i/8)*0.04,(5.7+(i/8)*0.25)*side),0.7)
   result[d.key]=d
  if p.potato:
   var c={"uid":-100-who,"card_id":"potato","owner":who,"zone":"palette","tapped":false}
   var d=description(c,Vector3(7.35,0.035,5.7*side),0.7); result[d.key]=d
 for i in range(duel.stack.size()):
  var entry=duel.stack[i]
  var c=entry.card if entry.kind=="card" else entry.source
  var d=description(c,Vector3(5.5+i*1.08,2.8+i*0.5,-0.7+i*0.1),1.92)
  d.key="card_"+str(c.uid) if entry.kind=="card" else "ability_"+str(entry.id)
  d.zone="stack"; d.kind="stack"; d.stack_id=entry.id
  d.rotation=Vector3(deg_to_rad(40),deg_to_rad(-7),0)
  d.gold=false; d.blue=false; d.tapped=false
  result[d.key]=d
 return result

func sync(payment_reservations: Array=[], selection: Array=[], available: Array=[], animate: bool=true):
 if combat_animating:
  deferred_sync={"reserved":payment_reservations.duplicate(true),"chosen":selection.duplicate(),"available":available.duplicate()}
  return
 if animate and duel.combat.get("step","") in ["damage_window","first_damage_window"] and last_combat.get("step","")!=duel.combat.get("step","") and visuals.has("card_"+str(duel.combat.attacker.uid)):
  deferred_sync={"reserved":payment_reservations.duplicate(true),"chosen":selection.duplicate(),"available":available.duplicate()}
  animate_combat_resolution()
  return
 reserved=payment_reservations; chosen=selection; highlighted=available
 var now=card_snapshot()
 var next=layout()
 for key in next:
  var d=next[key]
  var fresh=not visuals.has(key)
  if fresh:
   visuals[key]=create_visual(d)
   var old=old_cards.get(d.uid,{})
   visuals[key].position=zone_position(old.get("zone","hand"),d.owner) if animate else d.at
   if animate and key.begins_with("ability_") and visuals.has("card_"+str(d.uid)):
    visuals[key].position=visuals["card_"+str(d.uid)].position
   visuals[key].scale=d.scale*0.8 if animate else d.scale
   visuals[key].rotation=d.rotation
  var node=visuals[key]
  var prev=descriptors.get(key,{})
  var can_possess=duel.pending.get("kind","")=="possession" and duel.pending.get("owner",-1)==d.owner and d.zone=="palette" and d.uid>0 and not duel.find_card(d.uid).tapped and duel.can_possess(duel.find_card(d.uid))
  var outline=node.get_node("Outline")
  outline.visible=d.gold or d.blue or can_possess
  outline.material_override=material("#ffd65c" if d.gold else "#359bff")
  var halo=node.get_node("Halo")
  halo.visible=outline.visible
  halo.material_override=material("#785415" if d.gold else "#184878")
  if not fresh and prev.get("card_id","")!=d.card_id:
   node.get_node("Face").material_override=material(d.card_id).duplicate()
  var face_mat=node.get_node("Face").material_override
  face_mat.albedo_color=Color(0.43,0.46,0.51) if d.tapped and d.zone in ["field","palette"] else Color.WHITE
  var hit=node.get_node("Hit")
  hit.set_meta("kind",d.kind); hit.set_meta("uid",d.uid)
  hit.set_meta("card_id",d.card_id); hit.set_meta("stack_id",d.get("stack_id",-1))
  if fresh or prev.get("at")!=d.at or prev.get("rotation")!=d.rotation or prev.get("scale")!=d.scale:
   move_card(key,node,d,animate)
  if old_cards.has(d.uid) and now.has(d.uid):
   if now[d.uid].damage>old_cards[d.uid].damage: pulse(node,Color("#f17b73"))
 for key in visuals.keys():
  if next.has(key): continue
  var node=visuals[key]
  var d=descriptors[key]
  visuals.erase(key)
  stop_tween(key)
  node.get_node("Hit").collision_layer=0
  if animate:
   var c=now.get(d.uid,{})
   var dest=zone_position(c.get("zone","grave"),d.owner)
   var tween=create_tween().set_parallel(true)
   tween.tween_property(node,"position",dest,animation_duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
   tween.tween_property(node,"scale",Vector3.ONE*0.25,animation_duration)
   tween.chain().tween_callback(node.queue_free)
   animation_count+=1; mark_busy()
  else: node.queue_free()
 for who in range(2):
  update_pile("pdeck" if who==0 else "adeck",duel.players[who].deck,zone_position("deck",who),false)
  update_pile("pgrave" if who==0 else "agrave",duel.players[who].grave,zone_position("grave",who),true)
  update_pile("pexile" if who==0 else "aexile",duel.players[who].exile,zone_position("exile",who),true)
 if not duel.combat.is_empty() and duel.combat.get("attacker",{})!=last_combat.get("attacker",{}):
  var key="card_"+str(duel.combat.attacker.uid)
  if visuals.has(key):
   var node=visuals[key]
   stop_tween(key)
   var d=next[key]
   node.rotation=d.rotation
   var tween=create_tween()
   tween.tween_property(node,"position",d.at+Vector3(0,0.55,-1.4 if duel.combat.owner==0 else 1.4),0.2)
   tween.tween_property(node,"position",d.at,0.25)
   tweens[key]=tween; animation_count+=1; mark_busy()
 last_combat=duel.combat.duplicate(true)
 descriptors=next
 old_cards=now

func create_visual(d: Dictionary) -> Node3D:
 var root=Node3D.new(); root.name=d.key; add_child(root)
 plane(root,Vector3(0,-0.015,0),CARD_SIZE+Vector2(0.48,0.48),material("#785415")).name="Halo"
 plane(root,Vector3(0,-0.009,0),CARD_SIZE+Vector2(0.27,0.27),material("#ffd65c")).name="Outline"
 plane(root,Vector3.ZERO,CARD_SIZE,material(d.card_id).duplicate()).name="Face"
 var hit=area(root,Vector3.ZERO,Vector3(CARD_SIZE.x,0.12,CARD_SIZE.y)); hit.name="Hit"
 return root

func stop_tween(key: String):
 if tweens.has(key):
  if tweens[key].is_valid(): tweens[key].kill()
  tweens.erase(key)
func move_card(key: String,node: Node3D,d: Dictionary,animate: bool):
 stop_tween(key)
 if not animate:
  node.position=d.at; node.scale=d.scale; node.rotation=d.rotation
  return
 var tween=create_tween().set_parallel(true)
 tween.tween_property(node,"position",d.at,animation_duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
 tween.tween_property(node,"rotation",d.rotation,animation_duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
 tween.tween_property(node,"scale",d.scale,animation_duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
 tweens[key]=tween; animation_count+=1; mark_busy()
func mark_busy(): busy_until=maxi(busy_until,Time.get_ticks_msec()+int(animation_duration*1000))
func is_animating() -> bool: return combat_animating or Time.get_ticks_msec()<busy_until
func pulse(node: Node3D,_color: Color):
 var face=node.get_node("Face")
 var tween=create_tween()
 tween.tween_property(face,"position:y",0.22,0.1)
 tween.tween_property(face,"position:y",0.0,0.2)
 animation_count+=1

func update_pile(key: String,cards: Array,at: Vector3,face_up: bool):
 at.y=0.02
 var count=cards.size()
 var height=pile_height(count); stack_heights[key]=height
 if not piles.has(key):
  var root=Node3D.new(); root.position=at; add_child(root)
  var layers=MultiMeshInstance3D.new(); layers.name="Layers"
  var mm=MultiMesh.new(); mm.transform_format=MultiMesh.TRANSFORM_3D
  var mesh=BoxMesh.new(); mesh.size=Vector3(CARD_SIZE.x*SLOT_SCALE,LAYER_HEIGHT*0.88,CARD_SIZE.y*SLOT_SCALE)
  mm.mesh=mesh; layers.multimesh=mm; layers.material_override=material("#706f79")
  root.add_child(layers)
  plane(root,Vector3.ZERO,CARD_SIZE*SLOT_SCALE,material("back")).name="Top"
  var hit=area(root,Vector3.ZERO,Vector3(CARD_SIZE.x*SLOT_SCALE,0.2,CARD_SIZE.y*SLOT_SCALE)); hit.name="Hit"
  hit.set_meta("kind","pile"); hit.set_meta("zone",key)
  piles[key]=root
 var root=piles[key]
 var mm=root.get_node("Layers").multimesh
 if mm.instance_count!=count:
  mm.instance_count=count
  for i in range(count): mm.set_instance_transform(i,Transform3D(Basis.IDENTITY,Vector3(0,LAYER_HEIGHT*(i+0.5),0)))
 root.get_node("Top").position.y=height+0.003
 root.get_node("Top").visible=count>0
 root.get_node("Top").material_override=material(cards.back().card_id if face_up and count>0 else "back")
 var hit=root.get_node("Hit"); hit.position.y=maxf(0.1,height)/2
 hit.get_child(0).shape.size.y=maxf(0.2,height)
 hit.set_meta("card_id",cards.back().card_id if face_up and count>0 else "back")
 hit.set_meta("uid",cards.back().uid if face_up and count>0 else 0)
 hit.collision_layer=0 if "exile" in key and count==0 else 1
 hit.set_meta("caption",("除外区" if "exile" in key else "墓地" if face_up else "牌库")+" · %d 张" % count)

func pointer(event: InputEvent):
 if not event is InputEventMouseButton or not event.pressed: return
 if event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
  camera_distance=clampf(camera_distance+(-0.025 if event.button_index==MOUSE_BUTTON_WHEEL_UP else 0.025),0.77,0.98)
  set_camera(); return
 if event.button_index not in [MOUSE_BUTTON_LEFT,MOUSE_BUTTON_RIGHT]: return
 var from=camera.project_ray_origin(event.position)
 var ray=PhysicsRayQueryParameters3D.create(from,from+camera.project_ray_normal(event.position)*100)
 ray.collide_with_areas=true; ray.collide_with_bodies=false
 var result=get_world_3d().direct_space_state.intersect_ray(ray)
 if result.is_empty():
  if event.button_index==MOUSE_BUTTON_RIGHT: empty_right_clicked.emit()
  return
 var hit=result.collider
 if event.button_index==MOUSE_BUTTON_RIGHT:
  card_inspected.emit(hit.get_meta("card_id","back"),hit.get_meta("uid",0),hit.get_meta("caption","")); return
 match hit.get_meta("kind",""):
  "object": object_selected.emit(hit.get_meta("uid"))
  "stack": stack_selected.emit(hit.get_meta("stack_id"))
  "pile": pile_selected.emit(hit.get_meta("zone"))

func inspect_cards(ids: Array):
 if is_instance_valid(inspect_root): inspect_root.queue_free(); inspect_page+=1
 if ids.is_empty(): return
 if inspect_page*8>=ids.size(): inspect_page=0
 inspect_root=Node3D.new(); add_child(inspect_root)
 for i in range(inspect_page*8,mini(inspect_page*8+8,ids.size())):
  var j=i-inspect_page*8
  var at=Vector3(-6+(j%4)*2.6,1.0,-1.7+(j/4)*3.0)
  plane(inspect_root,at,CARD_SIZE,material(ids[i]))
  var hit=area(inspect_root,at,Vector3(CARD_SIZE.x,0.15,CARD_SIZE.y))
  hit.set_meta("card_id",ids[i]); hit.set_meta("kind","inspect")


func animate_combat_resolution():
 # Hold the pre-damage meshes, including dead units, until impact has been shown.
 combat_animating=true
 last_collision_targets=[]
 var fight=duel.combat.duplicate(true)
 var attacker=visuals["card_"+str(fight.attacker.uid)]
 stop_tween("card_"+str(fight.attacker.uid))
 var home=attacker.position
 var duration=maxf(0.025,animation_duration*0.5)
 var sequence=create_tween()
 if fight.blockers.is_empty():
  last_collision_targets.append(0)
  var destination=home+Vector3(0,0.7,-5.1 if fight.owner==0 else 5.1)
  sequence.tween_property(attacker,"position",destination,duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
  sequence.tween_callback(func(): combat_impact.emit(fight.attacker.uid,0); collision_count+=1)
  sequence.tween_interval(duration*0.3)
  sequence.tween_property(attacker,"position",home,duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
 else:
  for target in fight.blockers:
   var key="card_"+str(target.uid)
   if not visuals.has(key): continue
   var blocker=visuals[key]
   stop_tween(key)
   var block_home=blocker.position
   var center=(home+block_home)*0.5+Vector3(0,0.65,0)
   var direction=(block_home-home).normalized()
   last_collision_targets.append(target.uid)
   sequence.tween_property(attacker,"position",center-direction*0.42,duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
   sequence.parallel().tween_property(blocker,"position",center+direction*0.42,duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
   sequence.tween_callback(func(): combat_impact.emit(fight.attacker.uid,target.uid); collision_count+=1)
   sequence.tween_interval(duration*0.3)
   sequence.tween_property(attacker,"position",home,duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
   sequence.parallel().tween_property(blocker,"position",block_home,duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
 animation_count+=1
 sequence.tween_callback(func():
  last_combat=duel.combat.duplicate(true)
  combat_animating=false
  var pending_sync=deferred_sync; deferred_sync={}
  sync(pending_sync.get("reserved",[]),pending_sync.get("chosen",[]),pending_sync.get("available",[]),true)
  combat_animation_finished.emit())
