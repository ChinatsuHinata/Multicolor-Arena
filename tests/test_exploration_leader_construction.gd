extends "res://tests/support/rules_base.gd"
const G=preload("res://scripts/rules/gensokyo_exploration.gd")
const Rules=preload("res://scripts/deck_rule_set.gd")

func run():
 fresh()
 for rule in Rules.IDS:
  var allowed=rule in [Rules.UNRESTRICTED,Rules.TEST]
  var d=Store.blank("全随机秘封构筑");d.rule_set=rule
  expect(Rules.allowed(G.RANDOM_LEADER,Store.CARDS[G.RANDOM_LEADER],rule)==allowed,"random exploration leader availability: "+rule)
  expect(Store.add_card(d,G.RANDOM_LEADER,"leader",rule).is_empty()==allowed,"explicit rule leader selection: "+rule)
  expect(Store.add_card(d,G.RANDOM_LEADER,"leader").is_empty()==allowed,"saved rule leader selection: "+rule)
  d.leader=G.RANDOM_LEADER
  expect(Store.validate(d,false,rule).is_empty()==allowed,"explicit rule validation: "+rule)
  expect(Store.validate(d).is_empty()==allowed,"saved rule validation: "+rule)
  if allowed:
   var decoded=Store.decode(Store.encode(d))
   expect(decoded.has("deck") and decoded.deck.leader==G.RANDOM_LEADER and decoded.deck.rule_set==rule,"constructed random leader deck code round trip: "+rule)
  expect(not Rules.allowed(G.LEADER,Store.CARDS[G.LEADER],rule) and (G.SPELLS+G.RANDOM_SPELLS).all(func(id):return not Rules.allowed(id,Store.CARDS[id],rule)),"ordinary exploration leader and discovery spells remain unavailable: "+rule)
 var d=Store.blank("全随机秘封对局");d.rule_set=Rules.UNRESTRICTED
 Store.add_card(d,G.RANDOM_LEADER,"leader",Rules.UNRESTRICTED)
 for id in Store.CARDS:
  if Rules.allowed(id,Store.CARDS[id],Rules.UNRESTRICTED) and Store.CARDS[id].kind!="自机":
   d.main.append(id)
   if d.main.size()==50:break
 expect(Store.validate(d,true,Rules.UNRESTRICTED).is_empty(),"random leader can lead a full unrestricted constructed deck")
 expect(Store.prune_for_rule(d.duplicate(true),Rules.UNRESTRICTED)==0,"unrestricted pruning retains the constructed random leader")
 var official=d.duplicate(true);Store.prune_for_rule(official,Rules.OFFICIAL)
 expect(official.leader.is_empty(),"switching to official rules removes the random leader")
 e.start(d,d,0,42)
 var leader=e.players[0].leader
 expect(G.wildcard(e,leader,"博丽灵梦") and G.wildcard(e,leader,"雾雨魔理沙"),"constructed leader keeps wildcard role identity")
 expect(not (G.candidates(e,0,G.VISIT)+G.candidates(e,0,G.RANDOM_SPELLS[0])).has(G.RANDOM_LEADER),"constructed availability does not add the mode leader to discovery pools")
 print("EXPLORATION LEADER CONSTRUCTION: %d checks; %d failures" % [checks,failures.size()])
 quit(0 if failures.is_empty() else 1)
