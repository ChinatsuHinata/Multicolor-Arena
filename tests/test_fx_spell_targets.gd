extends SceneTree
## 符卡目标契约与梦想妙珠专项验收：只加载 fx/ 脚本，不启动对战。

const Spell=preload("res://fx/categories/fx_spell_module.gd")
const Manifest=preload("res://fx/fx_manifest.gd")
const Dream=preload("res://fx/modules/reimu_dream_orbs/effect.gd")
const DEFINITION="res://fx/definitions/reimu_dream_orbs.json"

var checks=0
var failures=0

func expect(ok: bool,message: String) -> void:
 checks+=1
 if not ok:
  failures+=1
  push_error("FX SPELL TARGETS FAIL: "+message)

func _initialize() -> void:
 call_deferred("run")

func run() -> void:
 check_rank()
 check_targets()
 check_manifest()
 var parent=Node3D.new()
 root.add_child(parent)
 parent.position=Vector3(3.0,0.4,-2.0)
 parent.rotation.y=0.3
 for pair in [[6,6],[0,1],[30,12]]:
  await check_orbs(parent,int(pair[0]),int(pair[1]))
 await check_scatter(parent)
 await check_determinism(parent)
 parent.free()
 print("FX SPELL TARGETS checks=%d failures=%d" % [checks,failures])
 quit(1 if failures>0 else 0)

func check_rank() -> void:
 var candidates=[
  {"uid":3,"card_id":"b","deck_leader":false,"kind":"单位","color_value":7},
  {"uid":5,"card_id":"a","deck_leader":false,"kind":"单位","color_value":7},
  {"uid":2,"card_id":"self","deck_leader":false,"kind":"自机","color_value":9},
  {"uid":1,"card_id":"deck","deck_leader":true,"kind":"单位","color_value":1},
  {"uid":4,"card_id":"a","deck_leader":false,"kind":"单位","color_value":7}]
 var ranked=Spell.rank_origins(candidates)
 expect(ranked.map(func(unit):return unit.uid)==[1,2,4,5,3],"origin order uses every tie breaker")
 expect(candidates.map(func(unit):return unit.uid)==[3,5,2,1,4],"ranking leaves its input order intact")

func check_targets() -> void:
 var module=Spell.new()
 var def={"character_spell":true,"character":"博丽灵梦","origin":"character","destination":"spell_target"}
 var ctx={"owner":0,"center":Vector3(1.0,0.0,2.0),"requires_character":"博丽灵梦","units":[
  {"uid":21,"owner":1,"character":"博丽灵梦","deck_leader":true,"kind":"自机","color_value":9,"card_id":"foe","position":Vector3(0.0,0.0,-1.4)},
  {"uid":12,"owner":0,"character":"博丽灵梦·测试","deck_leader":false,"kind":"自机","color_value":5,"card_id":"self","position":Vector3(2.1,0.0,1.1)},
  {"uid":11,"owner":0,"character":"博丽灵梦・测试","deck_leader":true,"kind":"单位","color_value":1,"card_id":"leader","position":Vector3(-2.1,0.0,1.1)},
  {"uid":13,"owner":0,"character":"其他角色","deck_leader":false,"kind":"单位","color_value":1,"card_id":"other","position":Vector3.ZERO}],
  "targets":[{"uid":21,"position":Vector3(0.0,0.0,-1.4)},{"uid":22,"position":Vector3(2.0,0.0,-1.4)},{"uid":23,"position":"invalid"}]}
 module.configure(def,ctx)
 expect(module.caster()==0 and module.origin_unit().get("uid")==11,"origin excludes the opponent and chooses the best allied match")
 expect(module.origin_candidates().map(func(unit):return unit.uid)==[12,11],"preview fallback recognizes both character separators")
 expect(module.origin_position()==Vector3(-2.1,0.0,1.1),"origin position comes from the selected unit")
 expect(module.destinations()==[Vector3(0.0,0.0,-1.4),Vector3(2.0,0.0,-1.4)],"spell targets preserve order and accept only Vector3 positions")
 ctx["matching_uids"]=[13,21]
 module.configure(def,ctx)
 expect(module.origin_unit().get("uid")==13,"rule matching uids are authoritative even when character text differs")
 ctx.matching_uids=[]
 module.configure(def,ctx)
 expect(not module.has_origin() and module.origin_position()==module.center(),"an explicit empty match list falls back to the center")
 ctx.matching_uids=[11]
 def.origin="none";def.destination="none"
 module.configure(def,ctx)
 expect(not module.has_origin() and module.origin_position()==module.center(),"origin none disables the character origin")
 expect(module.destinations().is_empty(),"destination none disables targets")
 def.origin="character";def.character_spell=false
 module.configure(def,ctx)
 expect(not module.has_origin(),"ordinary spells cannot select a character origin")
 module.configure({"character_spell":true},ctx)
 expect(module.origin_mode=="character" and module.spell_character=="博丽灵梦" and module.has_origin(),"character spells default to character origin and the context role")
 module.configure({}, {})
 expect(not module.character_spell and module.spell_character.is_empty() and module.origin_mode=="none" and module.destination_mode=="none","ordinary spell defaults remain empty")
 expect(module.palette_character_spells()==0 and module.caster()==0,"missing count and caster default to zero")
 module.configure({}, {"palette_character_spells":-3})
 expect(module.palette_character_spells()==0,"palette count cannot be negative")
 expect(module.local_point(Vector3.ONE)==Vector3.ONE,"local_point without a holder preserves world coordinates")
 module.free()

func check_manifest() -> void:
 var def: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(DEFINITION))
 expect(Manifest.validate(def,DEFINITION).is_empty(),"legal spell manifest passes")
 var missing=def.duplicate(true);missing.erase("character_spell")
 expect(Manifest.validate(missing,DEFINITION)=="origin character requires character_spell","character origin requires the character spell flag")
 for key in ["character_spell","character","origin","destination"]:
  var entrance={"id":def.id,"category":"entrance","script":def.script}
  entrance[key]=def[key]
  expect(Manifest.validate(entrance,DEFINITION)==key+" only applies to spell effects","entrance rejects spell field "+key)
 for pair in [["character_spell",1,"character_spell must be a boolean"],["character",1,"character must be a string"],["origin","bogus","origin must be one of none, character"],["destination","bogus","destination must be one of none, spell_target"]]:
  var bad=def.duplicate(true);bad[pair[0]]=pair[1]
  expect(Manifest.validate(bad,DEFINITION)==pair[2],"spell field validation: "+str(pair[0]))

func effect_context(parent: Node3D,count: int) -> Dictionary:
 return {"parent":parent,"uid":7,"card_size":Vector2(1.95,2.72),"owner":0,"center":Vector3(0.0,0.0,1.6),"matching_uids":[11],
  "units":[{"uid":11,"owner":0,"deck_leader":true,"kind":"自机","card_id":"showcase_leader","color_value":3,"character":"博丽灵梦","position":Vector3(-2.1,0.0,1.1)}],
  "targets":[{"uid":21,"position":Vector3(0.0,0.0,-1.4)}],"palette_character_spells":count}

func make_effect(ctx: Dictionary) -> Node:
 var module=Dream.new()
 module.configure(JSON.parse_string(FileAccess.get_file_as_string(DEFINITION)),ctx)
 module.auto_advance=false
 return module

func check_orbs(parent: Node3D,count: int,expected: int) -> void:
 var module=make_effect(effect_context(parent,count))
 expect(module.start(),"dream orbs starts for count %d" % count)
 if not is_instance_valid(module.holder):module.free();return
 var bodies=module.holder.get_children().filter(func(node):return str(node.name).begins_with("Orb") and not str(node.name).contains("Ghost"))
 expect(bodies.size()==expected,"count %d creates %d orb bodies" % [count,expected])
 expect(module.count_nodes(module.holder)==expected*3+3 and module.count_nodes(parent)<=64,"orb bodies, ghosts and rings fit the node budget")
 expect(module.holder.position==module.default_offset(),"holder keeps the base offset")
 expect(module.holder.to_global(module.origin_l).is_equal_approx(Vector3(-2.1,0.0,1.1)),"world origin converts correctly under a transformed parent")
 expect(module.holder.to_global(module.dests_l[0]).is_equal_approx(Vector3(0.0,0.0,-1.4)),"world destination converts correctly under a transformed parent")
 for step in range(30):
  if module.finished:break
  module.advance(0.05)
 expect(module.finished,"manual stepping reaches the budget")
 await process_frame
 expect(not is_instance_valid(module.holder) and not parent.has_node("Fx_reimu_dream_orbs"),"finished effect releases its holder")
 module.free()

func check_scatter(parent: Node3D) -> void:
 var ctx=effect_context(parent,6)
 ctx.targets=[];ctx.matching_uids=[]
 var module=make_effect(ctx)
 expect(module.start(),"dream orbs starts without a character or target")
 if is_instance_valid(module.holder):
  expect(module.holder.to_global(module.origin_l).is_equal_approx(ctx.center),"missing character uses the spell center")
  module.advance(0.5)
  var body: MeshInstance3D=module.holder.get_node("Orb0")
  var mat: ShaderMaterial=body.material_override
  expect(float(mat.get_shader_parameter("alpha"))>0.0 and float(mat.get_shader_parameter("alpha"))<1.0,"scatter flight fades its body")
  expect(module.impact_ring.material_override.get_shader_parameter("alpha")==0.0 and module.impact_flash.material_override.get_shader_parameter("alpha")==0.0,"scatter has no impact rings")
  module.advance(1.0)
 await process_frame
 expect(not parent.has_node("Fx_reimu_dream_orbs"),"scatter also releases its holder")
 module.free()

func check_determinism(parent: Node3D) -> void:
 var positions: Array[Vector3]=[]
 for repeat in range(2):
  var module=make_effect(effect_context(parent,6))
  expect(module.start(),"deterministic effect starts")
  if is_instance_valid(module.holder):
   module.advance(0.5)
   positions.append(module.holder.get_node("Orb0").position)
  module.stop()
  await process_frame
  module.free()
 expect(positions.size()==2 and positions[0].is_equal_approx(positions[1]),"same context gives the same first orb position at t=0.5")
