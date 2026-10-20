extends "res://tests/support/network_base.gd"
const Registry=preload("res://scripts/rules/mod_registry.gd")
const Replay=preload("res://scripts/replay_archive.gd")
var spectator
func send(seat: int,command: Dictionary):
 sync_views()
 var session=host if seat==0 else guest
 check(session.submit(command).is_empty(),"submit "+command.name)
 check(await until(func():return host.sequence==guest.sequence and not session.busy),"authority and client acknowledge command")
 sync_views()
func run():
 Registry._shared=Registry.new();check(Registry.shared().register_pack("res://mods/example.cards").is_empty(),"load mod pack")
 check(Registry.shared().register_pack("res://examples/testmod").is_empty(),"load corrected testmod pack")
 Store.CARDS=Store.Database.load_cards()
 var directory="res://work/mod-network/"+str(Time.get_ticks_usec())
 host=Session.new();guest=Session.new();spectator=Session.new()
 for session in [host,guest,spectator]:root.add_child(session)
 host.initialize(directory+"/host");guest.initialize(directory+"/guest");spectator.initialize(directory+"/spectator")
 host.error_raised.connect(func(message):print("HOST: "+message));guest.error_raised.connect(func(message):print("GUEST: "+message))
 check(host.create_room(host.Series.BO1,true,48118,"127.0.0.1",Store.RuleSet.MOD).is_empty(),"create local BO1 room with mod rules")
 var join_error=guest.join_room("127.0.0.1",48118)
 check(join_error.is_empty(),"guest starts loopback connection: "+join_error)
 if not await until(func():return not host.applicant.is_empty(),20):check(false,"guest connection · "+guest.notice+" · "+host.notice);quit(1);return
 host.accept_applicant(true)
 check(await until(func():return host.can_act() and guest.can_act()),"both mod clients connected")
 var decks=JSON.parse_string(FileAccess.get_file_as_string("res://data/test_precons.json")).decks
 for seat in [0,1]:
  var deck=decks[seat].duplicate(true);deck.main[0]="example.cards/top_three"
  check(Store.validate(deck,true,Store.RuleSet.MOD).is_empty(),"mod deck passes authoritative construction validation")
  host.handle_room_action(seat,{"name":"deck","deck":deck})
 check(await until(func():return guest.sequence==host.sequence),"mod deck registration synchronizes")
 await prepare()
 check(spectator.join_spectator("127.0.0.1",48118).is_empty(),"connect local spectator")
 check(await until(func():return spectator.connected),"spectator handshake uses same mod fingerprint")
 var e=host.authority
 e.pending={};e.triggers=[];e.stack=[];e.phase="main";e.active=1;e.priority=1;e.turn=5
 for player in e.players:player.mulligan_done=true
 var card=e.make_card("example.cards/top_three",1,"hand");e.players[1].hand.append(card)
 host.sequence+=1;host.persist();host.publish([])
 check(await until(func():return guest.sequence==host.sequence),"guest receives mod spell")
 await send(1,{"name":"commit_cast","args":[card.uid,{"none":true},[]]})
 await send(e.priority,{"name":"pass_priority","args":[]});await send(e.priority,{"name":"pass_priority","args":[]})
 check(e.pending.get("trigger",{}).get("mod_resume",false),"private mod continuation opens over transport")
 if e.mod_resolution.is_empty():quit(1);return
 var answer=e.pending.options[0].duplicate(true);var frame=e.mod_resolution.frame.duplicate(true)
 check(guest.latest_snapshot.projection.queries.lookup.has(answer.uid),"guest receives private inspected card")
 check(await until(func():return spectator.sequence==host.sequence),"spectator receives pending projection")
 check(spectator.latest_snapshot.projection.state.pending.kind=="network_wait" and not str(spectator.latest_snapshot).contains("remaining"),"spectator cannot inspect private frame")
 var replay=Replay.new();replay.record(guest.latest_snapshot,1)
 check(replay.metadata.mods==Registry.shared().manifest(),"replay records mod version hash and API")
 guest.transport.close()
 check(await until(func():return not host.connected),"disconnect during private choice")
 check(guest.resume_guest().is_empty(),"resume guest with saved identity")
 check(await until(func():return host.can_act() and guest.can_act()),"reconnect acknowledged")
 check(e.mod_resolution.frame==frame and guest.latest_snapshot.projection.state.pending.options.has(answer),"reconnect preserves exact step and private options")
 var saved=host.Codec.capture(e);var restored=host.Duel.new()
 check(host.Codec.restore(restored,saved).is_empty(),"authority snapshot restores paused mod operation")
 host.authority=restored;e=restored
 await send(1,{"name":"choose_effect","args":[answer]})
 await send(1,{"name":"choose_effect","args":[e.pending.options.back().duplicate(true)]})
 check(e.mod_resolution.is_empty() and e.find_card(card.uid).zone=="grave", "restored authority completes both choices")
 check(await until(func():return spectator.sequence==host.sequence),"spectator synchronizes final public state")
 e.players[1].deck.clear();e.players[1].exile.clear()
 var items=[]
 for id in ["testmod/fuel","testmod/control","testmod/fuel"]:
  var item=e.make_card(id,1,"exile");e.players[1].exile.append(item);items.append(item)
 var furnace=e.make_card("testmod/furnace",1,"hand");e.enter_field(furnace,1);e.pump_choices()
 host.sequence+=1;host.persist();host.publish([])
 check(await until(func():return guest.sequence==host.sequence),"guest receives furnace enter trigger")
 await send(e.priority,{"name":"pass_priority","args":[]});await send(e.priority,{"name":"pass_priority","args":[]})
 check(e.pending.trigger.get("mod_resume",false) and guest.latest_snapshot.projection.state.pending.options[0].selection[0].max==2,"guest receives up-to-two rod recovery selection")
 check(await until(func():return spectator.sequence==host.sequence),"spectator receives rod-selection wait state")
 check(spectator.latest_snapshot.projection.state.pending.kind=="network_wait","spectator cannot answer another player's recovery selection")
 var selection=e.pending.options[0].duplicate(true);selection.erase("selection");selection.picks=[[e.Mods.Context.new(e,{}).ref(items[0]),e.Mods.Context.new(e,{}).ref(items[1])]]
 guest.transport.close();check(await until(func():return not host.connected),"disconnect during exact item selection")
 check(guest.resume_guest().is_empty(),"resume guest during item selection")
 check(await until(func():return host.can_act() and guest.can_act()),"reconnected guest keeps recovery choice")
 saved=host.Codec.capture(e);restored=host.Duel.new()
 check(host.Codec.restore(restored,saved).is_empty(),"authority restores furnace resolution and eligible rod pool")
 host.authority=restored;e=restored
 await send(1,{"name":"choose_effect","args":[selection]})
 check(items[0].uid in e.players[1].deck.map(func(card):return card.uid) and items[1].uid in e.players[1].deck.map(func(card):return card.uid) and items[2].uid in e.players[1].exile.map(func(card):return card.uid) and e.mod_resolution.is_empty(),"network command shuffles exactly the chosen item copies after restoration")
 check(await until(func():return spectator.sequence==host.sequence),"spectator synchronizes completed furnace recovery")
 for session in [host,guest,spectator]:session.transport.close();session.queue_free()
 await process_frame
 print("MOD_ABILITIES_NETWORK: %d checks; %d failures" % [checks,failures.size()])
 quit(0 if failures.is_empty() else 1)
