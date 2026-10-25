extends SceneTree
## Free storefront effects remain account-owned and follow the equipped seat.
const Inventory=preload("res://scripts/shop_inventory.gd")
const Registry=preload("res://fx/fx_registry.gd")
const Bridge=preload("res://fx/fx_bridge.gd")
const Duel=preload("res://scripts/rules/duel_engine.gd")
const Store=preload("res://scripts/deck_store.gd")
const Seat=preload("res://net/seat_projection.gd")
const Remote=preload("res://net/remote_duel.gd")
const Codec=preload("res://net/state_codec.gd")
var checks=0
var failures=0

func expect(ok: bool,message: String):
 checks+=1
 if not ok:failures+=1;push_error(message)

func _initialize():call_deferred("run")

func run():
 var folder="res://work/shop-effects/"+str(Time.get_ticks_usec())
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
 var inventory=Inventory.new();inventory.initialize(folder.path_join("loadout.json"))
 var effects=inventory.catalogue.filter(func(item):return item.category in ["entrance","spell"])
 var registry=Registry.new();registry.reload()
 expect(registry.errors.is_empty() and effects.size()==2,"both shop effects have valid manifests")
 var deck=Store.blank("免费特效测试");deck.leader="70";deck.main=["100","100","100","100","100","100"];deck.rule_set="test"
 var engine=Duel.new();engine.start(deck,deck,0,42)
 var host=Node3D.new();root.add_child(host)
 var card=Node3D.new();host.add_child(card)
 var bridge=Bridge.new();var stage=bridge.attach(host);stage.auto_step=true;stage.set_process(false)
 for item in effects:
  var definition=registry.get_effect(item.fx)
  expect(item.price==0 and definition.get("shop_product","")==item.id and not definition.get("free",false),"free price requires claiming and equipping: "+item.id)
  expect(ResourceLoader.exists(item.image),"effect product has a card image: "+item.id)
  expect(registry.enabled(item.category,{},item.card_id).is_empty(),"unowned effect stays off: "+item.id)
  expect(registry.enabled(item.category,{item.id:{}},item.card_id).size()==1,"equipped product binds its effect: "+item.id)
  expect(registry.enabled(item.category,{item.id:{}},"unrelated").is_empty(),"effect remains limited to the corresponding card: "+item.id)
  inventory.sync_session("TEST_ONLY_effects",{"purchased_product_ids":[item.id],"shop_grants":{item.id:"fixture"}})
  expect(inventory.battle_enabled(item.id) and inventory.network_loadout().has(item.id),"claimed effect defaults on and enters signed loadout")
  var frozen=inventory.battle_loadout()
  engine.equip_shop_products(0,frozen.keys())
  bridge.set_owner_products(engine.equipped_shop_products)
  inventory.set_battle_enabled(item.id,false)
  expect(inventory.battle_loadout().is_empty() and frozen.has(item.id),"switching effect off preserves the current match snapshot")
  var remote=Remote.new();remote.apply_snapshot(bytes_to_var(var_to_bytes(Seat.build(engine,1))))
  expect(remote.equipped_shop_products==[[item.id],[]],"effect equipment survives anonymous peer projection")
  var restored=Duel.new()
  expect(Codec.restore(restored,Codec.capture(engine)).is_empty() and restored.equipped_shop_products==engine.equipped_shop_products,"effect equipment survives match restore and undo")
  var extra={"uid":77,"owner":0,"card_id":item.card_id,"targets":[{"uid":88,"position":Vector3(0,0,-2)}],"palette_character_spells":3}
  var started=bridge.unit_entered(card,Vector2(1.95,2.72),extra) if item.category=="entrance" else bridge.spell_resolved(card,Vector2(1.95,2.72),extra)
  expect(started.size()==1 and started[0].id==item.fx,"owner's equipped effect plays on its card: "+item.id)
  stage.stop_all()
  extra.owner=1
  started=bridge.unit_entered(card,Vector2(1.95,2.72),extra) if item.category=="entrance" else bridge.spell_resolved(card,Vector2(1.95,2.72),extra)
  expect(started.is_empty(),"opponent cannot borrow the owner's equipped effect: "+item.id)
  inventory.sync_session("TEST_ONLY_other",{})
  expect(not inventory.owns(item.id),"free ownership does not leak to another account")
  engine.start(deck,deck,0,42)
  expect(engine.equipped_shop_products==[[],[]],"starting a new match clears previous equipment")
 host.free()
 print("SHOP EFFECTS: ",checks," checks; ",failures," failures")
 quit(0 if failures==0 else 1)
