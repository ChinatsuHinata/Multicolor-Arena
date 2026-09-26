extends "res://tests/support/network_base.gd"
const Art=preload("res://scripts/card_art.gd")
const Remote=preload("res://net/remote_duel.gd")
const Observer=preload("res://net/observer_projection.gd")
var spectator
func run():
 var directory="res://work/alternate-art-network/"+str(Time.get_ticks_usec())
 Store.Paths.root_override=ProjectSettings.globalize_path(directory)
 host=Session.new();guest=Session.new();root.add_child(host);root.add_child(guest)
 host.initialize(directory+"/host");guest.initialize(directory+"/guest")
 check(host.create_room(3,false,47986,"127.0.0.1","test").is_empty(),"create alternate-art loopback room")
 guest.join_room("127.0.0.1",47986)
 var connected=await until(func():return not host.applicant.is_empty())
 check(connected,"guest requests art test room")
 if not connected:quit(1);return
 host.accept_applicant(true)
 check(await until(func():return host.can_act() and guest.can_act()),"both clients synchronize")
 var a=Store.blank("联机异画");a.leader="70";a.rule_set="test"
 a.main=["character-soi-018","character-soi-018","100","100","character-soi-018","100"]
 a.art_overrides={"70":"tts_151600","character-soi-018":"tts_150800","100":"tts_150900"}
 var b=a.duplicate(true);b.id="second_network_art_deck";b.art_overrides={"70":"tts_151700","character-soi-018":"tts_154908","100":"100"}
 host.room_action({"name":"deck","deck":a})
 check(await until(func():return host.can_act() and guest.can_act()),"host registration acknowledged")
 guest.room_action({"name":"deck","deck":b})
 check(await until(func():return host.series.state.decks[1].get("art_overrides",{})==b.art_overrides and host.can_act() and guest.can_act()),"wire registration retains guest cosmetic choices")
 await prepare()
 var e=host.authority
 var own=(e.players[0].hand+e.players[0].deck).filter(func(c):return c.card_id=="character-soi-018")[0]
 var enemy=(e.players[1].hand+e.players[1].deck).filter(func(c):return c.card_id=="character-soi-018")[0]
 var spell=(e.players[0].hand+e.players[0].deck).filter(func(c):return c.card_id=="100")[0]
 e.move_to(own,"field");e.move_to(enemy,"field");e.move_to(spell,"grave")
 host.publish(e.presentation_events)
 check(await until(func():return guest.latest_snapshot.projection.state.players[0].field.any(func(c):return c.uid==own.uid) and guest.can_act()),"public art changes sent through socket transport")
 var remote=Remote.new();remote.apply_snapshot(guest.latest_snapshot.projection)
 check(remote.find_card(own.uid).art_id=="tts_150800" and remote.find_card(enemy.uid).art_id=="tts_154908","same card on opposite sides retains each owner's chosen print over the wire")
 check(remote.find_card(spell.uid).art_id=="tts_150900" and remote.players[0].leader.art_id=="tts_151600" and remote.players[1].leader.art_id=="tts_151700","public spell and both leader prints survive network serialization")
 check(remote.players[0].hand.all(func(c):return c.card_id=="back" and not c.has("art_id")),"hidden enemy hand omits identifying art")
 var saved=host.Codec.capture(e);var restored=Session.Duel.new();host.Codec.restore(restored,saved)
 check(restored.find_card(own.uid).art_id=="tts_150800","recovery checkpoint retains public art")
 var observed=Observer.build(restored)
 check(observed.state.players[0].field[0].art_id=="tts_150800","spectator projection retains art after restoration")
 guest.leave();host.leave();await process_frame
 print("ALTERNATE_ART_NETWORK: ",checks," checks; failures=",failures)
 quit(0 if failures.is_empty() else 1)
