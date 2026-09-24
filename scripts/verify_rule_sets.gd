extends SceneTree
const Store=preload("res://scripts/deck_store.gd")
const Rules=preload("res://scripts/deck_rule_set.gd")
const Series=preload("res://net/series_controller.gd")
const Aliases=preload("res://scripts/card_search_aliases.gd")
var failures=[]

func check(ok: bool,description: String):
 if ok:print("PASS "+description)
 else:failures.append(description);push_error(description)

func _initialize():
 var deck=Store.blank("规则集测试")
 deck.leader="70"
 var limited="character-ucs-038"
 check(Rules.limit(limited,Store.CARDS[limited],Rules.OFFICIAL)==2,"official pet limit")
 check(Rules.limit("104",Store.CARDS["104"],Rules.OFFICIAL_SPX)==2,"official spell limit")
 check(Rules.limit("item-fdf-096",Store.CARDS["item-fdf-096"],Rules.OFFICIAL)==2,"official item limit")
 check(Rules.limit("new-spx-001",Store.CARDS["new-spx-001"],Rules.OFFICIAL)==0,"official SPX ban")
 check(Rules.limit("new-spx-001",Store.CARDS["new-spx-001"],Rules.OFFICIAL_SPX)>0,"official SPX exception")
 check(Rules.limit(limited,Store.CARDS[limited],Rules.TEST)==-1,"test copy count unlimited")
 check(Store.add_card(deck,limited,"main",Rules.OFFICIAL).is_empty(),"first official copy")
 check(Store.add_card(deck,limited,"side",Rules.OFFICIAL).is_empty(),"second official copy across sideboard")
 check(Rules.remaining(deck,limited,Store.CARDS,Rules.OFFICIAL)==0,"remaining counts both zones")
 check(not Store.add_card(deck,limited,"main",Rules.OFFICIAL).is_empty(),"third official copy rejected")
 deck.main.append(limited)
 check(not Store.validate(deck,false,Rules.OFFICIAL).is_empty(),"host validation rejects oversized copy pool")
 check(Store.validate(deck,false,Rules.UNRESTRICTED).is_empty(),"unrestricted uses ordinary copy limit")
 deck.main.clear();deck.side.clear()
 deck.main.append("new-spx-001")
 check(not Store.validate(deck,false,Rules.OFFICIAL).is_empty(),"official ban applies to saved decks")
 check(Store.validate(deck,false,Rules.OFFICIAL_SPX).is_empty(),"official SPX rule accepts card")
 deck.main.clear()
 for i in range(5):deck.main.append("164")
 check(not Store.validate(deck,false,Rules.UNRESTRICTED).is_empty(),"ordinary cards capped at four")
 check(Store.validate(deck,false,Rules.TEST).is_empty(),"test cards ignore copy limit")
 check(not Store.add_card(deck,"token-ucs-099","side",Rules.TEST).is_empty() and not Store.add_card(deck,"character-ucs-020","main",Rules.TEST).is_empty(),"test rule still rejects tokens and dream cards")
 for mode in Rules.IDS:
  check(not Rules.allowed("token-ucs-099",Store.CARDS["token-ucs-099"],mode) and not Rules.allowed("character-ucs-020",Store.CARDS["character-ucs-020"],mode),"read-only cards forbidden in "+mode)
 var forged={"name":"非法卡组","leader":"70","main":["token-ucs-099"],"side":[],"rule_set":Rules.TEST}
 check(not Store.validate(forged,false,Rules.TEST).is_empty() and Store.decode(JSON.stringify(forged)).has("error"),"forged test deck cannot import tokens")
 forged.main=["character-ucs-020"]
 check(not Store.validate(forged,false,Rules.TEST).is_empty() and Store.decode(JSON.stringify(forged)).has("error"),"forged test deck cannot import dream cards")
 var legacy=Store.blank("旧测试卡组");legacy.leader="70";legacy.main=["token-ucs-099","164","character-ucs-020"]
 check(Store.prune_for_rule(legacy,Rules.TEST)==2 and legacy.main==["164"],"rule change removes legacy read-only cards")
 deck.main.append(deck.leader)
 check(Store.validate(deck,false,Rules.TEST).is_empty(),"test rule admits leader names in deck")
 deck.main.pop_back();deck.side.clear()
 var series=Series.new();series.setup(1,false,Rules.OFFICIAL)
 deck.rule_set=Rules.TEST
 check(not series.set_deck(0,deck).is_empty(),"room enforces host rules even for test-tagged deck")
 deck.main=[limited,limited]
 check(series.set_deck(0,deck).is_empty(),"room accepts legal deck built under another editor rule")
 check(series.state.rule_set==Rules.OFFICIAL and series.public_state(1).rule_set==Rules.OFFICIAL,"room publishes chosen rule")
 deck.rule_set=Rules.OFFICIAL_SPX
 var decoded=Store.decode(Store.encode(deck))
 check(decoded.has("deck") and decoded.deck.rule_set==Rules.OFFICIAL_SPX,"deck code preserves editor rule")
 var alias_rules=Aliases.load_rules()
 for pair in [["老虎","寅丸星"],["老鼠","纳兹琳"],["船长","村纱水蜜"],["兔子","因幡帝"],["兔子","铃仙·优昙华院·因幡"],["雷米","蕾米莉亚·斯卡雷特"],["9","琪露诺"],["神妈","八坂神奈子"],["鸡","庭渡久诧歌"],["花妈","风见幽香"],["僵尸","宫古芳香"],["猫车","火焰猫燐"]]:
  check(Aliases.find_rule(alias_rules,pair[0]).has(pair[1]),"alias "+pair[0])
 print("RULE_SET_TEST ","PASS" if failures.is_empty() else "FAIL")
 quit(0 if failures.is_empty() else 1)
