extends SceneTree
const Store=preload("res://scripts/deck_store.gd")
const Aliases=preload("res://scripts/card_search_aliases.gd")
var checks=0
var failures=[]

func expect(ok: bool,title: String):
 checks+=1
 if not ok:failures.append(title);push_error(title)

func found(term: String,rules: Dictionary) -> Array:
 var query=Aliases.prepare_query(Store.CARDS,term,rules)
 var ids=[]
 for id in Store.CARDS:
  if Aliases.matches_query(Store.CARDS[id],id,query):ids.append(id)
 ids.sort()
 return ids

func _initialize():
 var rules=Aliases.load_rules()
 for pair in [["小妖梦",["39"]],["小猫车",["character-ucs-038"]],["炸弹人",["78","character-fdn-042"]],["夜雀",["22","character-fdf-094"]],["红饼",["165"]],["蓝饼",["167"]],["绿饼",["166"]],["黄饼",["164"]],["黑饼",["168"]],["饼",["164","165","166","167","168"]],["530",["spell-fdf-085"]],["小妖梦普通单位",["39"]],["小猫车普通单位",["character-ucs-038"]],["红饼道具",["165"]],["红色饼",["165"]],["小妖梦自机",[]]]:
  pair[1].sort()
  expect(found(pair[0],rules)==pair[1],"exact search results for "+pair[0])
 for id in ["39","character-ucs-038"]:
  expect(Store.CARDS[id].cost.values().reduce(func(n,v):return n+int(v),0)==3,"small alias identifies a three-cost unit: "+id)
 expect(found(" UU ",rules)==found("uu",rules),"aliases ignore case and outer whitespace")
 expect(Aliases.find_rule(rules,"紫饼")==null,"unknown color is not a mana-item alias")
 expect(not rules["饼"].has("colors"),"color modifier leaves the shared base rule unchanged")
 var query=Aliases.prepare_query(Store.CARDS,"小妖梦",rules)
 var fake=Store.CARDS["87"].duplicate(true);fake.name="小妖梦"
 expect(not Aliases.matches_query(fake,"87",query),"exclusive alias cannot include a different unit by text")
 var red_rule=Aliases.find_rule(rules,"红饼")
 fake=Store.CARDS["165"].duplicate(true);fake.cost={"红":3}
 expect(not Aliases.card_matches(fake,red_rule,"fake"),"colored cake rejects a three-cost mana item")
 fake=Store.CARDS["165"].duplicate(true);fake.colors=["红","蓝"]
 expect(not Aliases.card_matches(fake,red_rule,"fake"),"colored cake rejects a multicolor item")
 fake=Store.CARDS["165"].duplicate(true);fake.abilities=[]
 expect(not Aliases.card_matches(fake,red_rule,"fake"),"colored cake requires a mana ability")
 query=Aliases.prepare_query(Store.CARDS,"小五符卡",rules)
 var spells=Store.CARDS.keys().filter(func(id):return Aliases.matches_query(Store.CARDS[id],id,query))
 expect(not spells.is_empty() and spells.all(func(id):return Store.CARDS[id].kind=="符卡" and "古明地觉" in Store.CARDS[id].requires_character),"alias plus spell suffix finds the character's spells")
 query=Aliases.prepare_query(Store.CARDS,"红饼",rules)
 var names=Aliases.matching_names(Store.CARDS,query)
 expect(names.keys()==[Store.CARDS["165"].name],"name declaration search resolves the precise colored mana item")
 for pair in [["炮","99"],["530","spell-fdf-085"],["密封","new-eto-003"]]:
  expect(found(pair[0],rules).has(pair[1]),"existing special alias remains searchable: "+pair[0])
 print("CARD_SEARCH_ALIASES: %d checks; %d failures" % [checks,failures.size()])
 quit(0 if failures.is_empty() else 1)
