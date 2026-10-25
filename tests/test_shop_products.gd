extends SceneTree
const Store=preload("res://scripts/deck_store.gd")
const Duel=preload("res://scripts/rules/duel_engine.gd")
const Emotes=preload("res://scripts/rules/leader_emotes.gd")
const Grants=preload("res://net/shop_entitlements.gd")
const Seat=preload("res://net/seat_projection.gd")
const Remote=preload("res://net/remote_duel.gd")
var failures=0
var checks=0
func expect(ok: bool,message: String):
 checks+=1
 if not ok:failures+=1;push_error(message)
func _initialize():call_deferred("run")
func run():
 var catalogue=JSON.parse_string(FileAccess.get_file_as_string("res://data/shop.json")).products
 var a=Store.blank("正式表情测试");a.main=["100","100","100","100","100","100"];a.rule_set="test"
 var b=a.duplicate(true);b.leader="70"
 for item in catalogue:
  a.leader=item.leader_id
  var e=Duel.new();e.start(a,b,0,42);e.phase="main";e.pending={};e.entry_choices=[];e.presentation_events.clear()
  expect(not e.leader_emote_profiles[0].enabled,"purchase is required for "+item.id)
  Emotes.equip(e,0,["unrelated"])
  expect(not e.leader_emote_profiles[0].enabled,"another pack cannot enable "+item.id)
  Emotes.equip(e,0,[item.id])
  for kind in Emotes.KINDS:
   e.emote_ready_at[0]=0
   expect(e.send_emote(0,kind).is_empty() and e.presentation_events.back().text==Emotes.PROFILES[item.leader_id].lines[kind],item.id+" sends "+kind)
  var remote=Remote.new();remote.apply_snapshot(bytes_to_var(var_to_bytes(Seat.build(e,1,e.presentation_events))))
  expect(remote.leader_emote_profiles[0].lines==e.leader_emote_profiles[0].lines and remote.presentation_events==e.presentation_events,item.id+" dialogue survives peer serialization")
  e.surrender(0)
  expect(e.presentation_events.back().text==Emotes.PROFILES[item.leader_id].lines.surrender and e.winner==1,item.id+" surrender dialogue")
  expect(item.price==10 and ResourceLoader.exists(item.image),item.id+" price and portrait source")
 expect(catalogue.size()==Emotes.PROFILES.size(),"every dialogue profile has a shop product")
 for special in [
  ["character-fdf-ex01","74","姐姐大人，是要和芙兰玩吗"],
  ["character-fdf-ex01","character-ucs-067","姐姐大人，是要和芙兰玩吗"],
  ["character-fdf-ex02","71","幽幽子，怎么没带着妖梦就出门了"],
  ["71","character-fdf-ex02","紫？我只是自己出门玩"],
  ["74","character-fdf-ex01","芙兰，你该回地下室了"],
  ["75","74","大小姐，我想自己做个决定"],
  ["75","character-fdn-048","大小姐，我想自己做个决定"],
  ["character-fdf-ex04","character-fdf-ex04","哈哈，你可敢与我一战！"],
  ["character-fdf-ex04","character-ucs-061","哈哈，你可敢与我一战！"]
 ]:
  for who in [0,1]:
   a.leader=special[0];b.leader=special[1]
   var e=Duel.new();e.start(a if who==0 else b,b if who==0 else a,0,42)
   Emotes.equip(e,who,[Emotes.PROFILES[a.leader].product_id])
   var rng_state=e.rng.state
   Emotes.emit_event(e,who,"greeting")
   expect(e.presentation_events.back().text==special[2],"opponent-specific greeting for seat "+str(who)+": "+a.leader+" / "+b.leader)
   expect(e.rng.state==rng_state,"greetings preserve gameplay RNG")
   var ordinary=b.duplicate(true);ordinary.leader="70"
   e.start(a if who==0 else ordinary,ordinary if who==0 else a,0,42)
   expect(e.leader_emote_profiles[who].lines.greeting==Emotes.PROFILES[a.leader].lines.greeting,"special greeting does not leak into the next match")
 var sisters=Emotes.PROFILES["character-fdn-026"].lines
 expect(sisters.greeting=="恋恋，别偷偷站在别人背后\n姐姐，她在想什么呢" and sisters.surrender=="恋，你要不要再试一次。\n姐姐，换我来。","paired leader preserves both speakers")
 expect(Grants.verify({"emotes_reimu":"forged"}).is_empty(),"forged entitlement rejected")
 expect(Grants.verify({"emotes_reimu":true}).is_empty(),"invalid entitlement rejected")
 print("SHOP PRODUCTS: ",checks," checks; ",failures," failures")
 quit(0 if failures==0 else 1)
