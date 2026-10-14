extends "res://tests/support/rules_base.gd"
const G=preload("res://scripts/rules/gensokyo_exploration.gd")
const Series=preload("res://net/series_controller.gd")
const Codec=preload("res://net/state_codec.gd")
const Seat=preload("res://net/seat_projection.gd")

func fresh_random():
 fresh();e.start(G.deck(true),G.deck(true),0,42)
 for p in e.players:
  for zone in ["hand","palette","field","grave","exile"]:p[zone]=[]
  p.potato=false;p.mulligan_done=true;p.turns=3
 e.phase="main";e.active=0;e.priority=0;e.turn=6;e.presentation_events.clear()

func definitions_and_series():
 var deck=G.deck(true)
 expect(G.fixed_deck(deck,true) and not G.fixed_deck(deck) and not G.fixed_deck(G.deck(),true),"fixed deck validation separates both entertainment submodes")
 expect(deck.main.size()==50 and deck.main.count(G.RANDOM_SPELLS[0])==15 and deck.main.count(G.RANDOM_SPELLS[1])==15 and deck.main.count(G.RANDOM_SPELLS[2])==8 and deck.main.count(G.RANDOM_SPELLS[3])==12,"random mode retains the fixed discovery deck composition")
 expect(G.RANDOM_SPELLS.all(func(id):return e.cards[id].rules_text.contains("等概率随机") and e.cards[id].rules_text.contains("不同名") and not e.cards[id].rules_text.contains("至少生成") and not e.cards[id].constructible),"all random discovery cards explain their actual behavior and stay outside constructed decks")
 expect(not e.cards[G.RANDOM_LEADER].rules_text.contains("更容易") and e.Extra.has(e.cards[G.RANDOM_LEADER],G.ANY_SELF),"random leader retains wildcard identity without a misleading weight bonus")
 expect(G.RANDOM_SPELLS.all(func(id):return e.cards[id].fast==(id==G.RANDOM_SPELLS[1]) and "极彩" in e.cards[id].keywords),"random discovery spells preserve their costs, timing and palette colors")
 expect(not Store.validate(deck,true).is_empty(),"random cards cannot be submitted as an ordinary constructed deck")
 var series=Series.new();series.setup(Series.EXPLORATION_RANDOM,false,"official")
 expect(series.state.decks==[deck,deck] and series.state.strict and series.state.rule_set=="unrestricted","random rooms supply both presets and the fixed room rules")
 series.ready(0)
 expect(series.select_entertainment(Series.EXPLORATION).is_empty() and series.state.ready==[false,false] and series.state.decks==[G.deck(),G.deck()],"switching entertainment submode resets both decks and readiness")
 expect(series.select_entertainment(Series.EXPLORATION_RANDOM).is_empty(),"room can switch back to random exploration")
 series.ready(0);series.ready(1);series.prepare_choice()
 expect(not series.select_entertainment(Series.EXPLORATION).is_empty(),"submode locks once both players prepare")
 series.choose_first(series.state.chooser,true);series.start_game();series.record_result(0)
 expect(series.state.status=="complete" and series.rematch().is_empty() and series.state.format==Series.EXPLORATION_RANDOM and series.state.decks==[deck,deck],"random exploration ends after one win and rematch restores its own preset")

func pools_and_randomness():
 var visit=G.candidates(e,0,G.RANDOM_SPELLS[0])
 expect(visit.any(func(id):return e.cards[id].kind=="自机") and not G.candidates(e,0,G.VISIT).any(func(id):return e.cards[id].kind=="自机"),"random visit includes leaders without any battlefield colors")
 for i in range(4):
  var pool=G.candidates(e,0,G.RANDOM_SPELLS[i])
  expect(not pool.is_empty() and pool.all(func(id):
   var info=e.cards[id]
   if info.token or info.get("exploration_only",false) or not info.constructible or info.canonical_id!=id:return false
   if i==0:return info.kind in ["单位","自机"]
   if i==2:return info.kind in ["道具","结界"]
   return info.kind=="符卡" and (not info.requires_character.is_empty() if i==3 else info.requires_character.is_empty())),"random discovery draws only from the corresponding canonical card pool: "+str(i))
  e.rng.seed=7161;var before=G.discoveries(e,0,G.RANDOM_SPELLS[i],false)
  var names=before.map(func(option):return e.cards[option.outside_id].name)
  expect(before.size()==3 and names.all(func(name):return names.count(name)==1),"all random categories offer three distinct card names: "+str(i))
  mana();e.move_to(e.players[0].leader,"field",false)
  e.rng.seed=7161
  expect(G.discoveries(e,0,G.RANDOM_SPELLS[i],true)==before,"resources, leader and fast timing do not change random offers: "+str(i))
  e.players[0].palette=[];e.move_to(e.players[0].leader,"leader",false)
 # Use contrasting real cards in a small pool so timing, cost and card tuning
 # would create a large, detectable skew if the ordinary rules leaked through.
 var original=e.cards;var ids=["spell-fdf-027","spell-fdf-009"]
 e.cards={}
 for id in ids:e.cards[id]=original[id]
 var counts={ids[0]:0,ids[1]:0};var samples=2000;var distinct_options=true
 e.rng.seed=9102
 for i in range(samples):
  var offered=G.discoveries(e,0,G.RANDOM_SPELLS[3],true)
  distinct_options=distinct_options and offered.size()==2 and offered[0].outside_id!=offered[1].outside_id
  counts[offered[0].outside_id]+=1
 expect(distinct_options,"a two-card pool supplies both distinct choices without repeated filler")
 expect(counts.values().all(func(n):return n>samples*0.4 and n<samples*0.6),"cost and per-card rarity adjustments do not bias uniform random draws")
 for kind in G.RANDOM_SPELLS:
  e.cards=original
  var template=original[G.candidates(e,0,kind)[0]]
  e.cards={}
  for i in range(4):
   var id="random-name-sample-"+str(i);var info=template.duplicate(true)
   info.canonical_id=id;info.name="同名候选" if i<2 else "不同名候选"+str(i)
   e.cards[id]=info
  var unique_names=true
  for i in range(80):
   var offered=G.discoveries(e,0,kind)
   var names=offered.map(func(option):return e.cards[option.outside_id].name)
   unique_names=unique_names and offered.size()==3 and names.all(func(name):return names.count(name)==1)
  expect(unique_names,"same-name cards with different canonical IDs cannot repeat in a random offer: "+kind)
 e.cards={ids[0]:original[ids[0]]}
 expect(G.discoveries(e,0,G.RANDOM_SPELLS[3]).size()==1,"a singleton pool supplies one option without duplicates")
 e.cards={}
 expect(G.discoveries(e,0,G.RANDOM_SPELLS[1]).is_empty(),"an empty category resolves without invalid random access")
 e.cards=original

func resolution_and_restore():
 for id in G.RANDOM_SPELLS:
  fresh_random();put(G.RANDOM_SPELLS[0],"palette");put(G.RANDOM_SPELLS[1],"palette")
  var c=put(id,"hand");var rng_state=e.rng.state
  for i in range(3):e.targets_for(id,0)
  expect(e.rng.state==rng_state,"legality checks do not reroll random discoveries: "+id)
  expect(e.commit_cast(0,c.uid,{"none":true},e.payment(0,e.cast_cost(0,c)).plan).is_empty(),"random discovery casts with normal payment: "+id);one()
  expect(c.zone=="grave" and e.pending.get("trigger",{}).get("effect","")=="exploration:take","random discovery uses the real three-card selection flow")
  var spec=e.pending.options[0];var options=spec.selection[0].pool
  var names=options.map(func(option):return e.cards[option.outside_id].name)
  expect(options.size()==3 and names.all(func(name):return names.count(name)==1),"real random discovery selection contains three distinct names: "+id)
  var saved=Codec.capture(e);var restored=Duel.new();Codec.restore(restored,saved)
  expect(restored.pending==e.pending and restored.rng.state==e.rng.state and restored.players[0].leader.card_id==G.RANDOM_LEADER,"save restoration preserves random mode, offers and generator state")
  expect(Seat.build(e,0).state.pending.options==e.pending.options and Seat.build(e,1).state.pending.kind=="network_wait","network projections expose authoritative offers only to the choosing player")
  var choice=spec.duplicate(true);choice.erase("selection");choice.picks=[[{"outside_id":G.VISIT,"none":true}]]
  var frozen=JSON.stringify(e.pending);e.choose_effect(choice)
  expect(JSON.stringify(e.pending)==frozen,"injected choices cannot escape the offered random pool")
  choice.picks=[[options[1]]];e.choose_effect(choice)
  expect(e.players[0].hand.size()==1 and e.players[0].hand[0].card_id==options[1].outside_id and e.pending.kind=="reveal_review","chosen random card enters hand and is revealed normally")
  expect(e.confirm_revealed(1,e.pending.serial).is_empty(),"opponent can acknowledge random discovery")

func run():
 fresh_random();definitions_and_series();pools_and_randomness();resolution_and_restore()
 print("GENSOKYO EXPLORATION RANDOM: %d checks; %d failures" % [checks,failures.size()])
 quit(0 if failures.is_empty() else 1)
