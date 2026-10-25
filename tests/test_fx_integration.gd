extends "res://tests/support/ui_base.gd"
## 接通验收：真开一局，验证 fx_bridge 的三个接线点确实把模块挂到了该挂的地方。
## 单特效自身的验收在 tests/test_fx_module.gd，这里只测"本体到 fx/"这一段。

const Fixture=preload("res://tests/support/fx_registry_fixture.gd")

var settings_fixture=""

func frames(count: int=6):
 for i in range(count):await process_frame

func fx_stage() -> Node3D:
 if not is_instance_valid(view):return null
 return view.table.get_node_or_null("FxStage")

## 卡牌节点下挂的是 holder（Fx_<id>），模块本体挂在舞台上。
func holder_ids(node: Node) -> Array:
 if not is_instance_valid(node):return []
 return node.get_children().filter(func(child):return str(child.name).begins_with("Fx_")).map(func(child):return str(child.name).trim_prefix("Fx_"))

func live(module) -> bool:
 return module!=null and is_instance_valid(module)

func modules_with(category: String) -> Array:
 var stage=fx_stage()
 if stage==null:return []
 return stage.active.filter(func(module):return live(module) and str(module.category)==category)

func holder_ok(module) -> bool:
 return live(module) and is_instance_valid(module.holder)

func run():
 var folder="res://work/fx-integration/"+str(Time.get_ticks_usec())
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
 settings_fixture=folder.path_join("settings.json")
 app=load("res://main.tscn").instantiate();app.settings_path=settings_fixture
 root.add_child(app);await frames()
 app.load_test_decks();app.begin_battle(true);view=app.duel_view;view.set_process(false);e=view.engine
 await frames()
 expect(view.table.fx!=null,"battle table attaches the fx bridge")
 var stage=fx_stage()
 expect(stage!=null and stage.name=="FxStage","fx stage lives under the battle table")
 if stage==null:finish();return
 expect(stage.registry.errors.is_empty(),"fx manifests load without errors: "+str(stage.registry.errors))
 stage.auto_step=true
 # 接线验收使用测试内存清单，不要求游戏内置任何测试特效。
 stage.stop_all()
 await process_frame
 stage.use_registry(Fixture.create())

 clean()
 var unit=put("character-fdf-ex02","field",0)
 view.previous_snapshot={"seed":1}
 view.render();await frames()
 var node=view.table.visuals.get("card_"+str(unit.uid))
 expect(node!=null,"the unit has a battle visual")
 var entrance=holder_ids(node)
 expect(entrance.has("probe_entrance"),"entering a unit runs the free entrance effect")
 expect(modules_with("entrance").any(func(module):return str(module.id)=="probe_entrance" and holder_ok(module)),"the entrance module has a live holder")
 view.render();await frames()
 expect(holder_ids(node).size()==entrance.size(),"re-rendering does not replay the entrance effect")

 expect(holder_ids(node).has("probe_foil"),"the card face carries the free foil effect")
 var foil=modules_with("foil")
 expect(not foil.is_empty(),"a foil module is running")
 for module in foil:
  if not holder_ok(module):continue
  expect(module.holder.position.is_equal_approx(Vector3(0.0,module.MIN_Y,0.0)),"foil holder uses the category's safe offset")
  for plane in module.holder.get_children():
   expect(plane.position.y>=0.019 and plane.position.y<=0.055,"foil plane stays above the mist layer")

 var spell_card=put("spell-fdf-017","palette",0)
 view.render();await frames()
 var started=view.table.show_spell_effect(spell_card.uid)
 expect(started.size()>=1,"casting a slot card runs the free spell effect")
 var spell_layer=stage.get_node_or_null("FxLayer_spell")
 expect(spell_layer!=null and spell_layer.get_children().any(func(child):return str(child.name)=="Fx_probe_spell"),"spell effect lands on its own layer")
 for module in started:
  if live(module):module.advance(2.0)
 await process_frame
 expect(not spell_layer.get_children().any(func(child):return str(child.name)=="Fx_probe_spell"),"the spell effect frees itself after its budget")

 # 单位离场：入场与闪卡挂在卡牌节点下，节点释放即 holder 失效，舞台上不留孤儿。
 # 离场有 0.42s 的退场补间，等它跑完再判断。只检查挂在这张卡上的模块——
 # 自机、符卡各自也有自己的闪卡，不属于这次移除。
 var removed_uid=unit.uid
 e.players[0].field.erase(unit)
 view.render()
 await create_timer(1.0).timeout
 await frames()
 expect(view.table.visuals.get("card_"+str(removed_uid))==null,"removing the unit releases its visual")
 var attached=stage.active.filter(func(module):return is_instance_valid(module) and int(module.ctx.get("uid",-1))==removed_uid)
 for module in attached:
  if is_instance_valid(module):module.advance(0.016)
 await frames()
 for module in attached:
  expect(not holder_ok(module),"module does not outlive its card (%s)" % str(module.id))

 # 付费特效未装备时不跑。
 var registry=stage.registry
 registry.allow_all=false
 expect(registry.enabled("entrance",{}).any(func(def):return str(def.id)=="probe_entrance"),"free effects run without any purchase")
 expect(registry.enabled("entrance",{}).all(func(def):return def.get("free",false)),"paid effects stay off until equipped")
 finish()

func finish():
 print("FX INTEGRATION: ",checks," checks; ",len(failures)," failures")
 quit(0 if failures.is_empty() else 1)
