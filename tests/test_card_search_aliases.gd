extends SceneTree
const Store=preload("res://scripts/deck_store.gd")
const Aliases=preload("res://scripts/card_search_aliases.gd")
var checks=0
var failures=[]

func expect(ok: bool,title: String):
 checks+=1
 if not ok:failures.append(title);push_error(title)

func found(term: String,rules: Dictionary,character_spell_filter: bool=false) -> Array:
 var query=Aliases.prepare_query(Store.CARDS,term,rules,character_spell_filter)
 var ids=[]
 for id in Store.CARDS:
  if Aliases.matches_query(Store.CARDS[id],id,query):ids.append(id)
 ids.sort()
 return ids

func _initialize():
 var rules=Aliases.load_rules()
 var copies=found("复制",rules)
 expect(copies.any(func(id):return Store.CARDS[id].kind in ["单位","自机"]),"printed copy effects find units")
 expect(copies.any(func(id):return Store.CARDS[id].kind=="符卡"),"printed copy effects find spells")
 for id in Store.CARDS:
  var info=Store.CARDS[id]
  if "复制" in str(info.description)+str(info.rules_text):expect(id in copies,"copy text is searchable: "+id)
 var description_query=Aliases.prepare_query(Store.CARDS,"独有说明检索词",rules)
 var text_only=Store.CARDS["87"].duplicate(true);text_only.description="独有说明检索词";text_only.rules_text="能力内容检索词"
 expect(Aliases.matches_query(text_only,"87",description_query),"full description participates in search")
 expect(Aliases.matches_query(text_only,"87",Aliases.prepare_query(Store.CARDS,"能力内容检索词",rules)),"ability text participates in search")
 for pair in [["小妖梦",["39"]],["小猫车",["character-ucs-038"]],["炸弹人",["78","character-fdn-042"]],["转转",["32"]],["夜雀",["22","character-fdf-094","token-fdf-127"]],["夜雀道具",["token-fdf-127"]],["红饼",["165"]],["蓝饼",["167"]],["绿饼",["166"]],["黄饼",["164"]],["黑饼",["168"]],["饼",["164","165","166","167","168"]],["530",["spell-fdf-085"]],["小妖梦普通单位",["39"]],["小猫车普通单位",["character-ucs-038"]],["红饼道具",["165"]],["红色饼",["165"]],["小妖梦自机",[]]]:
  pair[1].sort()
  expect(found(pair[0],rules)==pair[1],"exact search results for "+pair[0])
 for id in ["39","character-ucs-038"]:
  expect(Store.CARDS[id].cost.values().reduce(func(n,v):return n+int(v),0)==3,"small alias identifies a three-cost unit: "+id)
 expect(found(" UU ",rules)==found("uu",rules),"aliases ignore case and outer whitespace")
 for term in ["神ノ风","神风","神之风"]:
  expect(found(term,rules).has("134"),"printed ノ spell is found through "+term)
 expect(Aliases.name_contains("幻波ノ影、狂气ノ瞳","幻波之影、狂气瞳"),"each ノ can use a different spelling")
 expect(not Aliases.name_contains("神风","神之风"),"之 only substitutes for a printed ノ")
 var spell_names=Aliases.matching_names(Store.CARDS,Aliases.prepare_query(Store.CARDS,"神之风",rules))
 expect(spell_names.has(Store.CARDS["134"].name),"name declaration finds the printed spell through 之")
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
 expect(found("小五自机符卡",rules,true)==found("小五符卡",rules),"Android character alias accepts the new character spell suffix")
 var character_spells=found("自机符卡",rules,true)
 expect(character_spells.has("spell-fdn-039") and not character_spells.is_empty() and character_spells.all(func(id):return Store.CARDS[id].kind=="符卡" and (not Store.CARDS[id].requires_character.is_empty() or "角色" in Store.CARDS[id].spell_type)),"plain character spell search matches only character specific spells")
 fake=Store.CARDS["spell-fdn-039"].duplicate(true);fake.requires_character=""
 expect(Aliases.kind_matches(fake,"自机符卡") and not Aliases.kind_matches(fake,"普通符卡"),"spell role tag identifies character spells even without a character constraint")
 fake.spell_type="符卡·高速"
 expect(Aliases.kind_matches(fake,"普通符卡") and not Aliases.kind_matches(fake,"自机符卡"),"ordinary and character spell filters stay distinct")
 query=Aliases.prepare_query(Store.CARDS,"红饼",rules)
 var names=Aliases.matching_names(Store.CARDS,query)
 expect(names.keys()==[Store.CARDS["165"].name],"name declaration search resolves the precise colored mana item")
 for pair in [["炮","99"],["530","spell-fdf-085"],["密封","new-eto-003"]]:
  expect(found(pair[0],rules).has(pair[1]),"existing special alias remains searchable: "+pair[0])
 print("CARD_SEARCH_ALIASES: %d checks; %d failures" % [checks,failures.size()])
 quit(0 if failures.is_empty() else 1)
