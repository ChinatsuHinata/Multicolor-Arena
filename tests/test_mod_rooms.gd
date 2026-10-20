extends "res://tests/support/network_base.gd"
const Registry=preload("res://scripts/rules/mod_registry.gd")
const Replay=preload("res://scripts/replay_archive.gd")
var spectator
func run():
 Registry._shared=Registry.new()
 check(Registry.shared().register_pack(ProjectSettings.globalize_path("res://examples/testmod")).is_empty(),"load testmod as external filesystem scripts")
 Store.CARDS=Store.Database.load_cards()
 for format_value in [Session.Series.BO1,Session.Series.BO1_SIDEBOARD,Session.Series.BO3]:
  await check_room(format_value)
 print("MOD_ROOMS: %d checks; %d failures" % [checks,failures.size()])
 quit(0 if failures.is_empty() else 1)

func check_room(format_value: int):
 var path="res://work/mod-rooms/"+str(Time.get_ticks_usec())
 host=Session.new();guest=Session.new();spectator=Session.new()
 for session in [host,guest,spectator]:root.add_child(session)
 host.initialize(path+"/host");guest.initialize(path+"/guest");spectator.initialize(path+"/spectator")
 guest.error_raised.connect(func(_message):pass);host.error_raised.connect(func(_message):pass)
 spectator.error_raised.connect(func(_message):pass)
 var enabled=host.mod_config.duplicate(true);host.mod_config=[]
 check(host.create_room(format_value,false,48124,"127.0.0.1",Store.RuleSet.MOD).contains("启用模组"),"LAN mod rules require enabled packs")
 check(host.create_relay_room("ws://127.0.0.1:47862",format_value,false,Store.RuleSet.MOD).contains("启用模组"),"cloud mod rules require enabled packs")
 host.mod_config=enabled
 check(host.create_room(format_value,false,48124,"127.0.0.1",Store.RuleSet.MOD).is_empty(),"create mod rules with "+Session.Series.format_label(format_value))
 check(host.room.rule_set==Store.RuleSet.MOD and host.room.format==format_value and host.room.mods==enabled,"room publishes independent format, rule set and manifest")
 var restorer=Session.new();root.add_child(restorer);restorer.initialize(path+"/host");restorer.mod_config=[]
 check(restorer.restore_host().contains("模组配置不一致"),"host restore checks mod rules before opening transport")
 restorer.queue_free()
 var expected=guest.mod_config.duplicate(true)
 for field in ["hash","version","api","missing","extra"]:
  guest.mod_config=expected.duplicate(true)
  if field=="missing":guest.mod_config=[]
  elif field=="extra":guest.mod_config.append({"id":"extra","version":"1","api":2,"hash":"x"})
  else:guest.mod_config[0][field]="different" if field!="api" else 99
  guest.join_room("127.0.0.1",48124)
  check(await until(func():return guest.rejected),"reject unequal mod "+field)
  check(host.applicant.is_empty() and not host.connected and guest.notice.contains("模组配置不一致"),"reject before accepting participant: "+field)
  guest.leave(false)
 guest.mod_config=expected
 guest.join_room("127.0.0.1",48124)
 check(await until(func():return not host.applicant.is_empty()),"equal configuration reaches host approval")
 host.accept_applicant(true)
 check(await until(func():return host.can_act() and guest.can_act()),"equal configuration connects")
 var decks=JSON.parse_string(FileAccess.get_file_as_string("res://data/test_precons.json")).decks
 for seat in [0,1]:
  var deck=decks[seat].duplicate(true);deck.main[0]="testmod/control"
  host.handle_room_action(seat,{"name":"deck","deck":deck})
 check(await until(func():return guest.sequence==host.sequence),"mod decks synchronize")
 if format_value==Session.Series.BO1_SIDEBOARD:
  host.room_action({"name":"ready"});guest.room_action({"name":"ready"})
  check(await until(func():return guest.room.get("status","")=="sideboarding" and host.can_act() and guest.can_act()),"mod rules retain BO1 pregame sideboarding")
 await prepare()
 check(host.authority.cards.has("testmod/control") and host.authority.mod_registry.manifest()==enabled,"selected rule enables mod authority for this format")
 spectator.mod_config=[];spectator.join_spectator("127.0.0.1",48124)
 check(await until(func():return spectator.rejected),"mismatched spectator gets explicit rejection")
 check(spectator.notice.contains("模组配置不一致") and host.spectator_hub.watchers.is_empty(),"mismatched spectator receives no projection")
 spectator.leave(false);spectator.mod_config=expected
 spectator.join_spectator("127.0.0.1",48124)
 check(await until(func():return spectator.connected),"matching spectator connects")
 var e=host.authority
 e.pending={};e.stack=[];e.triggers=[];e.phase="main";e.active=1;e.priority=1;e.turn=5
 e.players[1].deck.clear()
 var rod=e.make_card("testmod/control",1,"exile");e.players[1].exile.append(rod)
 var furnace=e.make_card("testmod/furnace",1,"hand");e.enter_field(furnace,1);e.pump_choices()
 e.pass_priority(e.priority);e.pass_priority(e.priority)
 host.sequence+=1;host.persist();host.publish([])
 check(await until(func():return guest.sequence==host.sequence and spectator.sequence==host.sequence),"furnace recovery prompt synchronizes")
 sync_views()
 check(guest.latest_snapshot.projection.state.pending.get("trigger",{}).get("mod_resume",false),"guest receives furnace recovery choice")
 check(spectator.latest_snapshot.projection.state.pending.kind=="network_wait" and not str(spectator.latest_snapshot).contains("mod_resolution"),"spectator receives no private resolution state")
 var replay=Replay.new();replay.record(guest.latest_snapshot,1)
 check(replay.metadata.mods==expected,"replay records exact external pack content")
 var answer=e.pending.options[0].duplicate(true);answer.erase("selection")
 answer.picks=[[e.Mods.Context.new(e,{}).ref(rod)]]
 guest.transport.close();check(await until(func():return not host.connected),"disconnect during furnace recovery")
 check(guest.resume_guest().is_empty(),"reconnect request")
 check(await until(func():return host.can_act() and guest.can_act()),"reconnect with identical configuration")
 var state=host.Codec.capture(e);var restored=host.Duel.new()
 check(host.Codec.restore(restored,state).is_empty(),"authority furnace selection restores")
 host.authority=restored;e=restored;sync_views()
 check(guest.submit({"name":"choose_effect","args":[answer]}).is_empty(),"submit recovery after restore")
 check(await until(func():return host.sequence==guest.sequence and not guest.busy),"recovery command acknowledged")
 sync_views()
 check(e.find_card(rod.uid).zone=="deck" and e.mod_resolution.is_empty() and e.winner==-2,"furnace recovery commits exactly once after reconnect")
 for session in [host,guest,spectator]:session.leave(false);session.queue_free()
 await process_frame
