extends SceneTree
const Store=preload("res://scripts/deck_store.gd")
var checks=0
func check(condition: bool, message: String):
 if not condition:
  push_error("FAIL: "+message)
  quit(1)
  return
 checks+=1
 print("PASS: "+message)
func _initialize():
 var d=Store.blank("测试卡组")
 check(not Store.validate(d).is_empty(),"missing leader rejected")
 check(not Store.add_card(d,"164","leader").is_empty(),"non leader rejected")
 check(Store.add_card(d,"70","leader").is_empty(),"leader accepted")
 check(Store.validate(d).is_empty(),"leader only deck can save")
 for i in range(50): Store.add_card(d,"164","main")
 check(not Store.validate(d,true).is_empty(),"50 cards with over four copies rejected")
 check(Store.validate(d,false).is_empty(),"explicit test mode permits repeated demo cards")
 d.main.pop_back()
 check(not Store.validate(d,true).is_empty(),"49 cards rejected")
 check(Store.validate(d,false).is_empty(),"ignore size permits 49")
 Store.add_card(d,"164","main")
 Store.add_card(d,"164","main")
 check(not Store.validate(d,true).is_empty(),"51 cards rejected")
 for i in range(19): Store.add_card(d,"164","main")
 check(d.main.size()==70,"70 main capacity")
 check(not Store.add_card(d,"164","main").is_empty() and d.main.size()==70,"71st main rejected")
 for i in range(10): Store.add_card(d,"167","side")
 check(not Store.add_card(d,"167","side").is_empty() and d.side.size()==10,"11th side rejected")
 var decoded=Store.decode(JSON.stringify(d))
 check(decoded.has("deck") and decoded.deck.id!=d.id and decoded.deck.main==d.main,"copy paste new identity")
 check(Store.decode("{bad").has("error"),"malformed input rejected")
 check(Store.decode('{"name":"x","main":[],"side":[],"leader":"164"}').has("error"),"non leader import rejected")
 var invalid=d.duplicate(true)
 invalid.main[0]="unknown"
 check(not Store.validate(invalid).is_empty(),"unknown card rejected")
 invalid=d.duplicate(true)
 invalid.main.append("164")
 check(not Store.validate(invalid).is_empty(),"oversized import rejected")
 var path="res://work/test-decks.json"
 check(Store.persist([d],path).is_empty(),"persist succeeds")
 var loaded=Store.load_decks(path)
 check(loaded.decks.size()==1 and loaded.decks[0]==d,"disk round trip")
 d.name="改名"
 check(Store.persist([d],path).is_empty(),"rename persist succeeds")
 check(Store.load_decks(path).decks[0].name=="改名","rename round trip")
 check(FileAccess.file_exists(path+".bak"),"backup exists")
 var f=FileAccess.open("res://work/data-test.txt",FileAccess.WRITE)
 f.store_string("PASS: %d checks" % checks)
 print("DATA_TEST_PASS: ",checks)
 quit()

