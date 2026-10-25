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
 Store.Paths.root_override=ProjectSettings.globalize_path(folder)
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
 var probes=Fixture.create()
 # before 段探针：飞行开始即开播；other 探针只认一张不存在的卡，永远不该出现。
 probes.definitions["probe_before"]=probes.definitions.probe_entrance.duplicate(true)
 probes.definitions.probe_before.id="probe_before";probes.definitions.probe_before.timing="before"
 probes.definitions["probe_other"]=probes.definitions.probe_entrance.duplicate(true)
 probes.definitions.probe_other.id="probe_other";probes.definitions.probe_other.cards=["no-such-card"]
 stage.use_registry(probes)

 clean()
 var unit=put("character-fdf-ex02","field",0)
 view.previous_snapshot={"seed":1}
 view.render();await frames()
 var node=view.table.visuals.get("card_"+str(unit.uid))
 expect(node!=null,"the unit has a battle visual")
 expect(holder_ids(node).has("probe_before"),"a before-timing entrance starts while the card is still flying in")
 expect(not holder_ids(node).has("probe_entrance"),"an after-timing entrance waits for the card to land")
 var before=modules_with("entrance").filter(func(module):return str(module.id)=="probe_before" and holder_ok(module))
 expect(not before.is_empty() and is_equal_approx(before[0].land_seconds(),view.table.animation_duration),"the before effect lands when the card flight ends")
 stage.advance_all(view.table.animation_duration+0.02)
 var entrance=holder_ids(node)
 expect(not entrance.has("probe_other"),"an entrance limited to other cards does not run on this unit")
 expect(entrance.has("probe_entrance"),"entering a unit runs the free entrance effect")
 expect(modules_with("entrance").any(func(module):return str(module.id)=="probe_entrance" and holder_ok(module)),"the entrance module has a live holder")
 view.render();await frames()
 # before 探针此时可能已按预算播完，只要求不出现新的 holder。
 var again=holder_ids(node)
 expect(again.size()<=entrance.size() and again.all(func(id):return entrance.has(id)),"re-rendering does not replay the entrance effect")

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
 expect(not started.is_empty() and started[0].ctx.get("units") is Array,"spell context includes the unit snapshot")
 expect(not started.is_empty() and started[0].ctx.get("palette_character_spells") is int,"spell context includes the palette character spell count")
 # 自机区里尚未出场的自机不是战场单位，不能成为角色符卡起点。
 var waiting=e.players[0].leader
 expect(waiting.get("zone","")=="leader","the test leader is still waiting in the leader zone")
 expect(not started.is_empty() and started[0].ctx.units.all(func(u):return u.zone=="field" and u.uid!=waiting.get("uid",-1)),"the spell snapshot only lists battlefield units")
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

 # 同一单位离场后再次进场要重新演出：离场时 fx_seen 被清掉。
 unit.zone="field";e.players[0].field.append(unit)
 view.render();await frames()
 stage.advance_all(view.table.animation_duration+0.02)
 var back=view.table.visuals.get("card_"+str(removed_uid))
 expect(holder_ids(back).has("probe_entrance"),"a unit re-entering the field replays its entrance effect")
 var pinned=modules_with("entrance").filter(func(module):return int(module.ctx.get("uid",-1))==removed_uid and str(module.id)=="probe_entrance" and holder_ok(module))
 expect(not pinned.is_empty() and pinned[0].ctx.get("landing") is Transform3D,"the entrance effect receives its landing transform")
 expect(not pinned.is_empty() and pinned[0].land_seconds()==0.0,"an after-timing effect starts with the card already landed")

 # 付费特效未装备时不跑。
 var registry=stage.registry
 registry.allow_all=false
 expect(registry.enabled("entrance",{}).any(func(def):return str(def.id)=="probe_entrance"),"free effects run without any purchase")
 expect(registry.enabled("entrance",{}).all(func(def):return def.get("free",false)),"paid effects stay off until equipped")
 finish()

func finish():
 Store.Paths.root_override=""
 print("FX INTEGRATION: ",checks," checks; ",len(failures)," failures")
 quit(0 if failures.is_empty() else 1)
