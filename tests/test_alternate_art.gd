extends SceneTree
const Store=preload("res://scripts/deck_store.gd")
const Art=preload("res://scripts/card_art.gd")
const Duel=preload("res://scripts/rules/duel_engine.gd")
const Seat=preload("res://net/seat_projection.gd")
const Observer=preload("res://net/observer_projection.gd")
const Remote=preload("res://net/remote_duel.gd")
const Codec=preload("res://net/state_codec.gd")
const Series=preload("res://net/series_controller.gd")
var failures=[]
var checks=0
func expect(ok: bool,title: String):
 checks+=1
 if not ok:failures.append(title);push_error(title)
func _initialize():call_deferred("run")
func run():
 var manifest_ok=true
 var ids={}
 for key in Art.groups():
  manifest_ok=manifest_ok and Store.CARDS.has(key)
  for variant in Art.groups()[key]:
   manifest_ok=manifest_ok and not ids.has(variant.id) and ResourceLoader.exists(variant.image,"Texture2D")
   ids[variant.id]=true
 expect(manifest_ok,"all catalogue versions have unique IDs and packaged textures")
 var a=Store.blank("异画测试");a.leader="70";a.main=["character-soi-018","character-soi-018","100","100","21","rec_unit_097"];a.side=["character-soi-018","100"];a.rule_set="test"
 var b=a.duplicate(true);b.id="art_other_deck"
 a.art_overrides={"70":"tts_151600","character-soi-018":"tts_150800","100":"tts_150900","21":"rec_unit_097"}
 expect(Store.validate(a).is_empty(),"valid cosmetic settings do not alter deck legality")
 expect(not b.has("art_overrides"),"editing one deck does not edit another")
 var clean=Store.clean_deck(a);clean.art_overrides["70"]="70"
 expect(a.art_overrides["70"]=="tts_151600","cleaned network and saved decks own their cosmetic dictionary")
 for code in [Store.encode(a),JSON.stringify(a)]:
  var decoded=Store.decode(code)
  expect(decoded.has("deck") and decoded.deck.art_overrides==a.art_overrides and decoded.deck.main==a.main,"code import preserves art and gameplay IDs")
 expect(Store.decode('MA1:["旧代码","70",["100"],[]]').has("deck"),"old deck codes remain supported")
 var wrong=a.duplicate(true);wrong.art_overrides={"70":"tts_150800"}
 expect(not Store.validate(wrong).is_empty(),"another card's image cannot be assigned as this card's art")
 wrong.art_overrides={"70":"res://arbitrary.png"}
 expect(not Store.validate(wrong).is_empty(),"arbitrary resource paths are rejected")
 wrong.art_overrides=[]
 expect(not Store.validate(wrong).is_empty(),"malformed cosmetic records are rejected")
 Store.Paths.root_override=ProjectSettings.globalize_path("res://work/alternate-art-data/"+str(Time.get_ticks_usec()))
 expect(Store.save_file(a).is_empty(),"portable mdeck saves cosmetic settings")
 var loaded=Store.read_file(Store.file_paths[a.id])
 expect(loaded.has("deck") and loaded.deck.art_overrides==a.art_overrides,"portable mdeck reads cosmetic settings")
 var series=Series.new();series.setup(3,false,"test")
 expect(series.set_deck(0,a).is_empty() and series.state.decks[0].art_overrides==a.art_overrides,"lobby registration retains deck art")
 expect(Series.sideboard_error(a,b,false,"test").is_empty(),"cosmetic changes preserve the registered gameplay pool")
 var e=Duel.new();e.start(a,b,0,331)
 var copies=e.players[0].deck+e.players[0].hand
 expect(copies.all(func(c):return c.get("art_id","")==a.art_overrides.get(Art.canonical(c.card_id,e.cards),"")),"every copy and old print ID uses this deck's chosen art")
 expect(e.players[0].leader.art_id=="tts_151600" and not e.players[1].leader.has("art_id"),"opponents with identical cards keep separate art choices")
 var unit=copies.filter(func(c):return c.card_id=="character-soi-018")[0]
 e.move_to(unit,"field");e.presentation_events.clear()
 var spell=copies.filter(func(c):return c.card_id=="100")[0]
 e.move_to(spell,"grave");e.presentation_events.clear()
 var events=[{"type":"reveal","serial":99,"card":unit.duplicate(true)}]
 for projection in [Seat.build(e,1,events),Observer.build(e,events)]:
  var remote=Remote.new();remote.apply_snapshot(bytes_to_var(var_to_bytes(projection)))
  expect(remote.find_card(unit.uid).art_id=="tts_150800" and remote.find_card(spell.uid).art_id=="tts_150900","opponent and spectator snapshots show the chosen public unit and spell art")
  expect(remote.players[0].hand.all(func(c):return c.card_id=="back" and not c.has("art_id")) and remote.players[0].deck.all(func(c):return not c.has("art_id")),"cosmetic IDs do not disclose hidden hands or libraries")
  expect(remote.presentation_events[0].card.art_id=="tts_150800","public reveal event retains art")
 var hidden=copies.filter(func(c):return c.uid!=unit.uid and c.uid!=spell.uid)[0]
 e.history=[{"turn":0,"phase":"main","text":"隐藏移动","art":[{"card_id":hidden.card_id,"art_id":hidden.get("art_id",""),"owner":0,"hidden":true}]}]
 expect(not Seat.build(e,1).state.history[0].art[0].has("art_id") and not Observer.build(e).state.history[0].art[0].has("art_id"),"hidden history redacts alternate-art identifiers")
 var restored=Duel.new();Codec.restore(restored,bytes_to_var(var_to_bytes(Codec.capture(e))))
 expect(restored.find_card(unit.uid).art_id==unit.art_id and restored.deck_art_overrides==e.deck_art_overrides,"reconnect and replay state preserve art")
 unit.owner=1
 expect(unit.art_id=="tts_150800","control changes keep the physical card's chosen art")
 e.start(b,b,0,331)
 expect(not e.players[0].leader.has("art_id") and e.players[0].hand.all(func(c):return not c.has("art_id")),"starting another deck clears previous cosmetic preferences")
 print("ALTERNATE_ART: ",checks," checks; failures=",failures)
 quit(0 if failures.is_empty() else 1)
