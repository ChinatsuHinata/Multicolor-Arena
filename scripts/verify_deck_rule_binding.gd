extends SceneTree
const Store=preload("res://scripts/deck_store.gd")
const Rules=preload("res://scripts/deck_rule_set.gd")
const Duel=preload("res://scripts/rules/duel_engine.gd")
var failures=[]

func check(value: bool, message: String):
 if value:print("PASS "+message)
 else:failures.append(message);push_error(message)

func _initialize():
 var deck=Store.blank("规则绑定测试")
 check(deck.rule_set==Rules.OFFICIAL,"new decks default to official")
 var legacy={"id":"legacy","name":"旧卡组","leader":"70","main":[],"side":[]}
 check(Store.clean_deck(legacy).rule_set==Rules.UNRESTRICTED,"untagged custom decks keep their former rule")
 check(Rules.main_limit(Rules.TEST)==70 and Rules.main_limit(Rules.UNRESTRICTED)==50 and Rules.main_limit(Rules.OFFICIAL)==50 and Rules.main_limit(Rules.OFFICIAL_SPX)==50,"only test rule permits 70 main cards")
 var capacity=Store.blank("容量测试")
 capacity.leader="70"
 capacity.rule_set=Rules.OFFICIAL_SPX
 for i in range(51):capacity.main.append("new-spx-007")
 check(not Store.validate(capacity).is_empty(),"non-test deck over 50 cannot save or import")
 check(Store.prune_for_rule(capacity,Rules.OFFICIAL_SPX)==1 and capacity.main.size()==50,"rule check removes cards over 50")
 capacity.rule_set=Rules.TEST
 capacity.main.clear()
 for i in range(70):capacity.main.append("164")
 check(Store.validate(capacity,false,Rules.TEST).is_empty(),"test deck permits 70 main cards")
 capacity.main.append("164")
 check(not Store.validate(capacity,false,Rules.TEST).is_empty(),"test deck rejects 71 main cards")
 deck.leader="70"
 deck.rule_set=Rules.TEST
 deck.main=["104","104","104","new-spx-001","70","164","164","164","164","164","68"]
 deck.side=["104","70","68","new-spx-002"]
 check(Store.prune_for_rule(deck,Rules.OFFICIAL)==7,"rule switch removes every banned, excess and leader copy")
 check(deck.rule_set==Rules.OFFICIAL and deck.main==["104","104","164","164","164","164","68"] and deck.side==["68"],"rule switch preserves valid card order across zones")
 check(Rules.remaining(deck,"70",Store.CARDS,Rules.OFFICIAL)==0,"chosen leader has zero library stock")
 check(Store.add_card(deck,"68","leader",Rules.OFFICIAL).is_empty(),"switching leader succeeds")
 check(deck.main==["104","104","164","164","164","164"] and deck.side.is_empty(),"switching leader removes its copies from both zones")
 check(Rules.remaining(deck,"70",Store.CARDS,Rules.OFFICIAL)==4 and Rules.remaining(deck,"68",Store.CARDS,Rules.OFFICIAL)==0,"old leader stock returns and new leader stock reaches zero")
 var limited=Store.blank("关键词张数")
 limited.leader="70"
 check(Rules.limit("spell-fdf-001",Store.CARDS["spell-fdf-001"],Rules.OFFICIAL)==2,"limited spell keyword caps copies at two")
 check(Store.add_card(limited,"spell-fdf-001","main",Rules.OFFICIAL).is_empty() and Store.add_card(limited,"spell-fdf-001","side",Rules.OFFICIAL).is_empty(),"limited spell permits two copies across zones")
 check(not Store.add_card(limited,"spell-fdf-001","main",Rules.OFFICIAL).is_empty(),"limited spell rejects third copy")
 limited.main.append("spell-fdf-001")
 check(not Store.validate(limited,false,Rules.OFFICIAL).is_empty(),"validation catches excess limited spell")
 limited.main.pop_back()
 check(Rules.limit("105",Store.CARDS["105"],Rules.OFFICIAL)==1,"final word keyword caps copies at one")
 check(Store.add_card(limited,"105","main",Rules.OFFICIAL).is_empty() and not Store.add_card(limited,"105","side",Rules.OFFICIAL).is_empty(),"final word rejects second copy across zones")
 var duel=Duel.new()
 var sample=Store.blank("疾行验证")
 sample.leader="70"
 for i in range(10):sample.main.append("164")
 duel.start(sample,sample,0,123)
 var hatate=duel.make_card("character-fdf-105",0,"field")
 duel.players[0].field.append(hatate)
 check(duel.has_haste(hatate) and not duel.summoning_sick(hatate),"Hatate has haste on battlefield")
 for path in ["res://deck/预设卡组/预组-灵梦_ffc1d4d760ac.mdeck","res://deck/预设卡组/预组-魔理沙_c1ea9fe0a9b2.mdeck","res://deck/预设卡组/1.0红u_bb783f78017b.mdeck","res://deck/预设卡组/1.0四色妖梦_ee1aabc09ce7.mdeck"]:
  var preset=Store.read_file(path)
  check(preset.has("deck") and preset.deck.rule_set==Rules.OFFICIAL,"preset uses official: "+path.get_file())
  if preset.has("deck"):check(Store.validate(preset.deck,false,Rules.OFFICIAL).is_empty(),"preset obeys official: "+path.get_file())
 var sumireko=Store.read_file("res://deck/堇子（副本）_35b0c227ae2c.mdeck")
 check(sumireko.has("deck") and sumireko.deck.rule_set==Rules.OFFICIAL_SPX,"Sumireko deck permits limited cards")
 if sumireko.has("deck"):check(Store.validate(sumireko.deck,false,Rules.OFFICIAL_SPX).is_empty(),"Sumireko deck obeys selected rule")
 print("DECK_RULE_BINDING ","PASS" if failures.is_empty() else "FAIL")
 quit(0 if failures.is_empty() else 1)
