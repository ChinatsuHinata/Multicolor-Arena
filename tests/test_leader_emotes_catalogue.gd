extends SceneTree
const Store=preload("res://scripts/deck_store.gd")
const Duel=preload("res://scripts/rules/duel_engine.gd")
const Emotes=preload("res://scripts/rules/leader_emotes.gd")
const Inventory=preload("res://scripts/shop_inventory.gd")
var checks=0
var failures=[]
func expect(ok: bool,title: String):
 checks+=1
 if not ok:failures.append(title);push_error(title)
func _initialize():call_deferred("run")
func deck(leader: String) -> Dictionary:
 var result=Store.blank("自机对话目录测试")
 result.leader=leader;result.main=["100","100","100","100","100","100"];result.rule_set="test"
 return result
func run():
 var inventory=Inventory.new();inventory.initialize("res://work/emotes-import/catalogue-preferences.json")
 var products={};var leaders={}
 for item in inventory.catalogue:
  expect(not products.has(item.id),"unique product ID: "+item.id);products[item.id]=item
  if item.category!="emotes":continue
  expect(not leaders.has(item.leader_id),"one dialogue package per canonical leader: "+item.leader_id)
  leaders[item.leader_id]=item.id
  expect(Emotes.PROFILES.get(item.leader_id,{}).get("product_id","")==item.id,"catalogue maps to shipped dialogue: "+item.id)
  var texture=load(item.image) as Texture2D
  expect(texture!=null,"product artwork loads: "+item.id)
  if texture!=null:
   var crop=item.portrait_region
   expect(Rect2(Vector2.ZERO,texture.get_size()).encloses(Rect2(crop[0],crop[1],crop[2],crop[3])),"portrait stays inside artwork: "+item.id)
 for id in Emotes.PROFILES:
  var configured=Emotes.PROFILES[id]
  expect(leaders.get(id,"")==configured.product_id,"every profile is on sale: "+id)
  expect(configured.lines.size()==Emotes.DEFAULT_LINES.size(),"six dialogue categories: "+id)
  var e=Duel.new();e.start(deck(id),deck("70"),0,8457)
  var data=Emotes.profile(e,0)
  expect(data.leader_id==id and not data.enabled,"purchase required for canonical leader: "+id)
  Emotes.equip(e,0,["unknown_product"])
  expect(not data.enabled,"unrelated equipment never enables dialogue: "+id)
  Emotes.equip(e,0,[configured.product_id])
  expect(data.enabled,"matching equipment enables dialogue: "+id)
  e.phase="main";e.pending={};e.entry_choices=[];e.priority=0;e.presentation_events.clear()
  for kind in Emotes.DEFAULT_LINES:
   var line=configured.lines.get(kind,"")
   expect(line is String and not line.strip_edges().is_empty() and line.length()<=120 and not line.contains("/"),"complete untruncated dialogue: "+id+" / "+kind)
   expect(data.lines.get(kind,"")==line,"match profile preserves exact dialogue: "+id+" / "+kind)
   if kind=="surrender":e.surrender(0)
   else:
    e.emote_ready_at=[0.0,0.0]
    expect(e.send_emote(0,kind).is_empty(),"equipped leader sends dialogue: "+id+" / "+kind)
   expect(e.presentation_events.back().text==line,"authoritative event preserves dialogue: "+id+" / "+kind)
  for character in configured.get("greetings",{}):
   var variants=e.cards.keys().filter(func(card_id):return e.cards[card_id].kind=="自机" and e.cards[card_id].character.contains(character))
   expect(not variants.is_empty(),"special greeting has a real opposing character: "+id+" / "+character)
   for other_id in variants:
    e.start(deck(id),deck(other_id),0,8457)
    expect(Emotes.profile(e,0).lines.greeting==configured.greetings[character],"special greeting matches opposing title or art: "+id+" / "+other_id)
 # FDN-071 is the same card as UCS-068 and must use the same purchased package.
 var alternate=Duel.new();alternate.start(deck("character-fdn-071"),deck("70"),0,8457)
 Emotes.equip(alternate,0,["emotes_okina"])
 expect(Emotes.profile(alternate,0).leader_id=="character-ucs-068" and Emotes.profile(alternate,0).enabled,"Okina alternate uses canonical ownership")
 for id in ["new-eto-003","character-fdn-025","character-fdn-026"]:
  expect(Emotes.PROFILES[id].lines.values().all(func(line):return line.split("\n").size()==2),"paired characters retain both speakers: "+id)
 expect(Emotes.PROFILES["character-fdn-026"].lines.praise=="恋，要看好这一手\n姐姐，她好厉害哦","updated Satori and Koishi praise")
 expect(Emotes.PROFILES["71"].lines.praise=="比只会打扫卫生的妖梦厉害呢","updated Yuyuko praise")
 print("LEADER_EMOTES_CATALOGUE: ",checks," checks; failures=",failures)
 quit(0 if failures.is_empty() else 1)
