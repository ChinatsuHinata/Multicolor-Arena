extends SceneTree
## 单特效验收：只跑 fx/ 下的东西，不启动对战、不加载卡牌、不碰本体脚本。
## 用法
##   Godot --headless --path . --script tests/test_fx_module.gd
##   Godot --headless --path . --script tests/test_fx_module.gd -- --only=<id>
## 退出码 0 表示所有清单合法、每个模块都能独立建、跑完、自我清理。

const Manifest=preload("res://fx/fx_manifest.gd")
const Registry=preload("res://fx/fx_registry.gd")
const Stage=preload("res://fx/fx_stage.gd")
const Fixture=preload("res://tests/support/fx_registry_fixture.gd")
const CARD_SIZE=Vector2(1.95,2.72)
const FOIL_MIN_Y=0.019
const FOIL_MAX_Y=0.055
const FORBIDDEN=["duel_table","duel_view","main.gd","scripts/rules","CARD_SIZE","Time.get_ticks"]

var failures=0
var checks=0

func expect(ok: bool,message: String) -> void:
 checks+=1
 if not ok:
  failures+=1
  push_error("FX FAIL: "+message)

func _initialize() -> void:
 call_deferred("run")

func run() -> void:
 var only=""
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--only="):only=arg.trim_prefix("--only=")
 var registry=Registry.new()
 registry.allow_all=true
 registry.reload(true)
 expect(registry.errors.is_empty(),"manifest errors: "+str(registry.errors))
 if not only.is_empty():expect(registry.definitions.has(only),"requested effect exists: "+only)
 for id in registry.definitions:
  var def=registry.definitions[id]
  expect(Manifest.validate(def,str(def.get("source",""))).is_empty(),"manifest re-validates: "+id)
  if not only.is_empty() and id!=only:continue
  await check_effect(registry,def)
 expect(Manifest.valid_id("Bad ID")==false and Manifest.valid_id("ok_id_2"),"id validation rejects spaces and uppercase")
 var bad={"id":"x","category":"nope","script":"res://fx/modules/x.gd"}
 expect(not Manifest.validate(bad,"res://fx/definitions/x.json").is_empty(),"short id and unknown category are rejected")
 var outside={"id":"escape","category":"entrance","script":"res://scripts/duel_table.gd"}
 expect(not Manifest.validate(outside,"res://fx/definitions/escape.json").is_empty(),"modules outside fx/modules are rejected")
 var purchase=Fixture.create()
 expect(not purchase.enabled("entrance",{}).is_empty(),"free effects run without a purchase")
 var paid=Fixture.create()
 paid.definitions={"paid_entrance":paid.definitions.probe_entrance.duplicate(true)}
 paid.definitions.paid_entrance.id="paid_entrance"
 paid.definitions.paid_entrance.free=false
 expect(paid.enabled("entrance",{}).is_empty(),"a paid effect stays off until equipped")
 expect(paid.enabled("entrance",{"p_other":{"fx":"missing_effect"}}).is_empty(),"an unknown product binds nothing")
 expect(paid.enabled("entrance",{"paid_entrance":{}}).size()==1,"a product id equal to the effect id binds it")
 expect(paid.enabled("entrance",{"p_paid":{"fx":"paid_entrance"}}).size()==1,"a product binds the effect named by fx")
 var locked=Fixture.create()
 expect(locked.enabled("foil",{"p_other":{"fx":"missing_effect"}}).any(func(d):return str(d.id)=="probe_foil"),"a free foil still runs without a purchase")
 check_card_filter()
 await check_stage()
 print("FX MODULES: ",checks," checks; ",failures," failures")
 quit(0 if failures==0 else 1)

func check_effect(registry,def: Dictionary) -> void:
 var id=str(def.id)
 var anchor=Node3D.new()
 anchor.name="Anchor_"+id
 root.add_child(anchor)
 var module=registry.spawn(def,{"parent":anchor,"card_size":CARD_SIZE,"uid":7,"card_id":"test"})
 expect(module!=null,"module spawns: "+id)
 if module==null:
  anchor.queue_free()
  return
 module.auto_advance=false
 var started=Time.get_ticks_usec()
 expect(module.start(),"module starts: "+id)
 var build_ms=float(Time.get_ticks_usec()-started)/1000.0
 expect(build_ms<180.0,"build stays under 180 ms (was %.1f): %s" % [build_ms,id])
 var built=module.count_nodes(anchor)
 expect(anchor.get_child_count()==1 and str(anchor.get_child(0).name)=="Fx_"+id,"module owns exactly one holder: "+id)
 expect(built>0,"module builds visible nodes: "+id)
 expect(built<=module.MAX_NODES,"node budget respected: "+id)
 if str(def.category)=="foil":check_foil_bounds(module.holder,id)
 check_boundary(registry,id)
 var elapsed=0.0
 var limit=float(def.get("budget_ms",700))/1000.0 if str(def.category)!="foil" else 3.0
 while elapsed<limit+0.5 and not module.finished:
  module.advance(1.0/60.0)
  elapsed+=1.0/60.0
 if str(def.category)=="foil":
  expect(not module.finished,"foil keeps running past one cycle: "+id)
  expect(module.phase()>=0.0 and module.phase()<1.0,"foil phase stays in 0..1: "+id)
  module.stop()
 else:
  expect(module.finished,"module finishes within its budget: "+id)
  expect(elapsed<=limit+0.2,"finished in %.2fs, budget %.2fs: %s" % [elapsed,limit,id])
 await process_frame
 expect(not is_instance_valid(module.holder),"module frees its holder: "+id)
 expect(anchor.get_child_count()==0,"module leaves no nodes behind: "+id)
 anchor.queue_free()
 await process_frame
 if is_instance_valid(module):module.free()

## 清单 cards / timing 的校验与按卡筛选。
func check_card_filter() -> void:
 var base={"id":"probe","category":"entrance","script":"res://fx/modules/reimu_yinyang_gather/effect.gd","cards":["70"],"timing":"before"}
 var path="res://fx/definitions/probe.json"
 expect(Manifest.validate(base,path).is_empty(),"cards and timing pass validation: "+Manifest.validate(base,path))
 for bad in [{"cards":[]},{"cards":"70"},{"cards":[70]},{"cards":[""]},{"timing":"during"},{"timing":true}]:
  var data=base.duplicate();data.merge(bad,true)
  expect(not Manifest.validate(data,path).is_empty(),"manifest rejects "+str(bad))
 var foil=base.duplicate();foil.category="foil"
 expect(not Manifest.validate(foil,path).is_empty(),"timing is rejected outside entrance")
 var filtered=Fixture.create()
 filtered.definitions.probe_entrance.cards=["70"]
 expect(filtered.enabled("entrance",{},"70").size()==1,"an effect runs on a card its cards list names")
 expect(filtered.enabled("entrance",{},"71").is_empty(),"an effect skips cards its cards list does not name")
 expect(filtered.enabled("entrance",{}).size()==1,"no card id skips the card filter")
 expect(filtered.enabled("foil",{},"71").size()==1,"an effect without cards runs on every card")
 filtered.allow_all=true
 expect(filtered.enabled("entrance",{},"71").size()==1,"allow_all previews ignore the card filter")

func check_foil_bounds(holder: Node,id: String) -> void:
 if not is_instance_valid(holder):return
 for child in holder.get_children():
  var y=child.position.y
  expect(y>=FOIL_MIN_Y and y<=FOIL_MAX_Y,"foil plane y=%.3f stays above the mist layer: %s (%s)" % [y,id,child.name])

## 模块只能看见 fx/：源码里出现本体文件名即判失败。
func check_boundary(registry,id: String) -> void:
 var def=registry.get_effect(id)
 var source=str(def.get("script",""))
 if source.is_empty():return
 var text=FileAccess.get_file_as_string(source)
 for word in FORBIDDEN:
  expect(not text.contains(word),"module %s must not reference %s" % [id,word])

func check_stage() -> void:
 var host=Node3D.new();root.add_child(host)
 var empty=Registry.new();empty.loaded=true
 var stage=Stage.new();stage.use_registry(empty);host.add_child(stage)
 stage.auto_step=true
 for category in ["entrance","foil","spell"]:
  expect(stage.play(category,{"parent":host,"card_size":CARD_SIZE}).is_empty(),"empty catalog spawns no "+category+" effects")
 expect(stage.active.is_empty() and host.get_child_count()==1,"empty catalog leaves no holders or active modules")
 stage.use_registry(Fixture.create())
 var started=stage.play("entrance",{"parent":host,"card_size":CARD_SIZE,"uid":3})
 expect(started.size()>=1,"stage spawns free entrance effects onto its layer")
 expect(stage.layer("entrance").name=="FxLayer_entrance","stage creates a named layer per category")
 stage.stop_all()
 await process_frame
 expect(stage.active.is_empty(),"stage drops finished modules")
 # 时间点：after 等 ctx.travel 秒（卡牌落场）才生成，before 立即生成。
 var timed=Fixture.create()
 timed.definitions["probe_before"]=timed.definitions.probe_entrance.duplicate(true)
 timed.definitions.probe_before.id="probe_before";timed.definitions.probe_before.timing="before"
 stage.use_registry(timed)
 var card=Node3D.new();host.add_child(card)
 var now=stage.play("entrance",{"parent":card,"card_size":CARD_SIZE,"uid":4,"travel":0.4})
 expect(now.size()==1 and str(now[0].id)=="probe_before","only the before effect starts during the flight")
 expect(not now.is_empty() and is_equal_approx(now[0].land_seconds(),0.4),"before effect lands at ctx.travel")
 expect(stage.pending.size()==1,"the after effect waits for the landing")
 stage.advance_all(0.2)
 expect(stage.pending.size()==1 and not card.has_node("Fx_probe_entrance"),"the after effect does not start mid-flight")
 stage.advance_all(0.25)
 expect(stage.pending.is_empty() and card.has_node("Fx_probe_entrance"),"the after effect starts once the card lands")
 var landed=stage.active.filter(func(module):return is_instance_valid(module) and str(module.id)=="probe_entrance")
 expect(not landed.is_empty() and landed[0].land_seconds()==0.0,"after effect starts already landed")
 stage.stop_all()
 var gone=Node3D.new();host.add_child(gone)
 stage.play("entrance",{"parent":gone,"card_size":CARD_SIZE,"uid":5,"travel":0.4})
 gone.free()
 stage.advance_all(0.5)
 expect(stage.pending.is_empty() and not stage.active.any(func(module):return is_instance_valid(module) and int(module.ctx.get("uid",-1))==5 and str(module.id)=="probe_entrance"),"a card that leaves before landing drops its after effect")
 stage.stop_all()
 await process_frame
 host.free()
 await process_frame
