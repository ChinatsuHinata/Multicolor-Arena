extends "res://tests/support/network_base.gd"
const Service=preload("res://scripts/task_service.gd")
const Inventory=preload("res://scripts/shop_inventory.gd")
const Grants=preload("res://net/shop_entitlements.gd")
var service

func synced(ok: bool=true):
 check(await until(func():return not is_instance_valid(service.client),20),"account request completes")
 check(service.error.is_empty()==ok,"account request returns expected outcome")

func run():
 var args=OS.get_cmdline_user_args();var index=args.find("--fixture")
 if index<0:push_error("Requires local TEST_ONLY fixture");quit(1);return
 var fixture=JSON.parse_string(FileAccess.get_file_as_string(args[index+1]))
 var directory=str(fixture.folder).replace("\\","/")
 Store.Paths.root_override=directory
 service=Service.new();root.add_child(service)
 service.set_session("TEST_ONLY_shop",fixture.token,"ws://127.0.0.1:48073")
 service.refresh();await synced()
 check(service.snapshot.coins==fixture.price and service.snapshot.purchased_product_ids.is_empty(),"fresh server wallet and inventory")
 service.purchase("emotes_reimu",int(fixture.price));await synced()
 check(service.snapshot.coins==0 and service.snapshot.purchased_product_ids==["emotes_reimu"],"encrypted purchase charges the confirmed current price")
 service.purchase("emotes_reimu");await synced()
 check(service.snapshot.coins==0,"purchase retry never debits twice")
 service.purchase("emotes_marisa");await synced(false)
 check(service.snapshot.coins==0 and service.snapshot.purchased_product_ids==["emotes_reimu"],"insufficient balance preserves wallet and inventory")
 service.purchase("test_leader_emotes");await synced(false)
 var effects=["entrance_reimu_yinyang_gather","spell_reimu_dream_orbs"]
 for id in effects:
  service.purchase(id,0);await synced()
  check(service.snapshot.coins==0 and service.snapshot.purchased_product_ids.has(id),"free effect claimed through authenticated transport: "+id)
 var inventory=Inventory.new();inventory.initialize(directory.path_join("loadout.json"))
 inventory.sync_session(service.account,service.snapshot)
 check(inventory.battle_enabled("emotes_reimu"),"server purchase enables the product without manual equipment")
 var loadout=inventory.network_loadout()
 var equipped=["emotes_reimu"]+effects;equipped.sort()
 check(Grants.verify(loadout)==equipped,"real relay signs valid anonymous grants for dialogue and free effects")
 check(loadout.keys()==equipped,"peer payload contains only equipped cosmetic IDs and signatures")
 var forged=loadout.duplicate();forged.emotes_marisa=forged.emotes_reimu
 check(Grants.verify(forged)==equipped,"signature cannot unlock another product")
 host=Session.new();guest=Session.new();root.add_child(host);root.add_child(guest)
 host.initialize(directory+"/host");guest.initialize(directory+"/guest");guest.shop_inventory=inventory
 check(host.create_room(3,false,48107,"127.0.0.1","test").is_empty(),"create local paid-emote room")
 check(guest.join_room("127.0.0.1",48107).is_empty(),"connect local paid-emote guest")
 if not await until(func():return not host.applicant.is_empty()):check(false,"guest connected");quit(1);return
 host.accept_applicant(true)
 check(await until(func():return host.can_act() and guest.can_act()),"peers synchronize")
 var deck=Store.blank("正式自机表情联机测试");deck.leader="character-rei-001";deck.main=["100","100","100","100","100","100"];deck.rule_set="test"
 host.room_action({"name":"deck","deck":deck})
 check(await until(func():return host.can_act() and guest.can_act()),"host deck ready")
 guest.room_action({"name":"deck","deck":deck})
 check(await until(func():return host.can_act() and guest.can_act()),"guest deck ready")
 await prepare()
 var engine=host.authority
 check(not engine.leader_emote_profiles[0].enabled and engine.leader_emote_profiles[1].enabled,"only purchased and equipped seat is enabled")
 check(engine.equipped_shop_products==[[],equipped],"room freezes verified effect ownership separately for each seat")
 check(guest.latest_snapshot.projection.state.equipped_shop_products==[[],equipped],"opponent effect equipment reaches the peer snapshot")
 inventory.set_battle_enabled(effects[0],false)
 check(engine.equipped_shop_products[1].has(effects[0]),"inventory changes leave the active match equipment frozen")
 engine.phase="main";engine.pending={};engine.entry_choices=[];engine.priority=1;engine.presentation_events.clear()
 host.sequence+=1;host.publish([])
 check(await until(func():return guest.can_act() and guest.sequence==host.sequence),"active battle synchronized")
 sync_views();guest.submit({"name":"send_emote","args":["greeting"]})
 check(await until(func():return engine.emote_serial==1 and guest.can_act()),"purchased emote accepted over real peer transport")
 var event=guest.latest_snapshot.projection.state.presentation_events.back()
 check(event.text=="是你啊，是要来和我对决的吧","opponent receives exact configured dialogue")
 host.leave(false);guest.leave(false);service.queue_free();host.queue_free();guest.queue_free()
 await process_frame
 print("SHOP NETWORK: ",checks," checks; failures=",failures)
 quit(0 if failures.is_empty() else 1)
