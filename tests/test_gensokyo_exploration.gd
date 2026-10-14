extends "res://tests/support/rules_base.gd"
const G=preload("res://scripts/rules/gensokyo_exploration.gd")
const Series=preload("res://net/series_controller.gd")
const Codec=preload("res://net/state_codec.gd")
const Seat=preload("res://net/seat_projection.gd")
const Remote=preload("res://net/remote_duel.gd")

func fresh_mode(passive: bool=false):
 var opponent=G.deck()
 if passive:opponent.ai_passive=true
 fresh();e.start(G.deck(),opponent,0,42)
 for p in e.players:
  for z in ["hand","field","palette","grave","exile"]:p[z]=[]
  p.potato=false;p.mulligan_done=true;p.turns=3
 e.phase="main";e.active=0;e.priority=0;e.turn=6;e.presentation_events.clear()

func pick(spec: Dictionary,pool: Array) -> Dictionary:
 var result=spec.duplicate(true);result.erase("selection");result.picks=[pool];return result

func check_definitions():
 var deck=G.deck();var base=Store.CARDS["new-eto-003"];var leader=Store.CARDS[G.LEADER]
 expect(deck.main.size()==50 and deck.main.count(G.VISIT)==15 and deck.main.count(G.EXPLORE)==15 and deck.main.count(G.TRAVEL)==8 and deck.main.count(G.CLUB)==12,"fixed 15/15/8/12 deck")
 var altered=deck.duplicate(true);altered.main[altered.main.find(G.TRAVEL)]=G.CLUB
 expect(G.fixed_deck(deck) and not G.fixed_deck(altered),"fixed deck validates each discovery count")
 expect(leader.name==base.name and leader.image==base.image,"original leader name and art preserved")
 expect(leader.colors==["红","蓝","绿","黄","黑"] and leader.cost=={"红":1,"蓝":1,"绿":1,"黄":1,"黑":1},"mode leader has five colors and one cost of each color")
 expect([leader.power,leader.health,leader.spirit,leader.race]==[base.power,base.health,base.spirit,base.race],"original leader stats and race preserved")
 expect(not e.Roster.has(leader,"n21:ETO-003") and not e.Roster.has(leader,"n21:ETO-003:self"),"mode leader removes original entry search and replaces self ability")
 expect(e.Roster.has(base,"n21:ETO-003") and e.Roster.has(base,"n21:ETO-003:self"),"ordinary Merry and Renko retain their original abilities")
 var old_self=base.abilities.filter(func(a):return a.get("参数",{}).get("效果","")=="n21:ETO-003:self")[0].get("名称","")
 var entry=base.abilities.filter(func(a):return a.get("参数",{}).get("效果","")=="n21:ETO-003")[0].get("名称","")
 expect(not leader.rules_text.contains(old_self) and not leader.description.contains(old_self) and leader.rules_text.count("自机能力：")==1,"leader description contains only the new self ability")
 expect(not leader.rules_text.contains(entry) and not leader.description.contains(entry) and not leader.abilities.any(func(a):return a.get("名称","")==entry),"mode leader carries no original entry effect or description")
 expect(Store.CARDS[G.VISIT].cost=={"黄":1} and Store.CARDS[G.EXPLORE].cost=={"黑":1} and Store.CARDS[G.TRAVEL].cost=={"蓝":1} and Store.CARDS[G.CLUB].cost=={"蓝":1},"four spell costs and colors")
 expect(G.SPELLS.all(func(id):return Store.CARDS[id].fast==(id==G.EXPLORE)),"only Renko exploration has fast timing")
 expect(Store.CARDS[G.VISIT].image==Store.CARDS["character-ucs-021"].image and Store.CARDS[G.EXPLORE].image==Store.CARDS["character-ucs-020"].image,"requested Merry and Renko art")
 expect(Store.CARDS[G.CLUB].image==G.CLUB_ART and ResourceLoader.exists(G.CLUB_ART,"Texture2D"),"club activity uses the current blue art")
 var travel=Store.CARDS[G.TRAVEL];var backpack=Store.CARDS["item-ucs-012"]
 expect(travel.name=="俱乐部的旅行包" and travel.kind=="符卡" and travel.image==G.TRAVEL_ART and ResourceLoader.exists(G.TRAVEL_ART,"Texture2D") and travel.landscape==backpack.landscape,"travel bag uses the current dark art with backpack orientation")
 expect(not e.Roster.has(travel,"backpack") and "极彩" in travel.keywords,"travel bag has discovery and Lily White colors without original backpack ability")
 expect(not Store.validate(deck,true).is_empty(),"entertainment cards cannot enter ordinary constructed decks")
 expect(not Store.CARDS["new-eto-003"].rules_text.contains("任意自机"),"original leader definition remains independent")
 for id in G.SPELLS:
  expect("极彩" in Store.CARDS[id].keywords and Store.CARDS[id].rules_text.contains("极彩。"),"discovery spell displays Lily White colors: "+id)
  for zone in ["palette","field","hand","grave"]:
   var c=put(id,zone)
   expect(e.Pack.colors(e,c).size()==(5 if zone in ["palette","field"] else 1),"Lily White colors only in palette and field: "+id+" "+zone)

func check_leader():
 fresh_mode();mana()
 expect(e.cast_error(0,e.players[0].leader.uid).is_empty(),"fixed leader casts with no colored permanents")
 var ordinary=put("70","hand")
 expect(e.cast_error(0,ordinary.uid).contains("颜色约束"),"other leaders still require colored permanents")
 var role="";var support="";var komachi=""
 for id in e.cards:
  var info=e.cards[id]
  if info.kind!="符卡" or info.requires_character.is_empty():continue
  if "支援" in info.keywords:support=id
  else:role=id
  if info.requires_character.contains("小野冢小町"):komachi=id
 var source=e.players[0].leader
 var plain=put(role,"hand");var assisted=put(support,"hand");var death=put(komachi,"hand")
 expect(not e.character_constraint_error(plain,0).is_empty(),"ordinary role spell cannot use leader-zone wildcard")
 expect(e.character_constraint_error(assisted,0).is_empty(),"support sees wildcard in leader zone")
 for zone in ["hand","deck","palette","grave","exile","field"]:
  e.move_to(source,zone,false)
  expect(e.character_matches(source,"博丽灵梦") and e.Cat.character(e,source,"雾雨魔理沙"),"wildcard identity in "+zone)
  expect(e.character_constraint_error(plain,0).is_empty()==(zone=="field"),"ordinary role spell respects battlefield requirement in "+zone)
  if zone=="grave":expect(e.character_constraint_error(death,0).is_empty(),"Komachi grave permission accepts wildcard")
  if zone=="field":expect(e.Pack.has_character(e,0,"博丽灵梦"),"other role effects recognize wildcard on battlefield")
 expect(not e.character_matches(ordinary,"雾雨魔理沙"),"ordinary cards do not become wildcards")
 fresh_mode()
 var copy=put(G.LEADER)
 expect(not e.character_matches(copy,"雾雨魔理沙"),"ordinary copy does not gain the self wildcard ability")
 var shrine=e.cards.keys().filter(func(id):return e.DB.has_ability(e.cards[id],"grant_leader_abilities"))[0]
 put(shrine)
 expect(e.character_matches(copy,"雾雨魔理沙"),"granted self ability enables wildcard on a battlefield copy")
 fresh_mode();e.move_to(e.players[0].leader,"grave",false)
 var revival=put("spell-fdn-023","hand")
 expect(not e.character_constraint_error(revival,0).is_empty(),"three-cost grave rule still rejects five-cost wildcard")
 fresh_mode();mana()
 var entry=put("new-eto-007","deck")
 var error=e.commit_cast(0,e.players[0].leader.uid,{},e.payment(0,e.cast_cost(0,e.players[0].leader)).plan)
 expect(error.is_empty(),"leader can be paid normally")
 one()
 expect(e.players[0].leader.zone=="field" and e.pending.is_empty() and e.stack.is_empty() and e.triggers.is_empty(),"mode leader enters without original song search or any entry choice")
 expect(entry.zone=="deck","mode leader entry leaves available songs in deck")
 e.move_to(e.players[0].leader,"exile",false);e.enter_field(e.players[0].leader,0);e.pump_choices()
 expect(e.pending.is_empty() and e.stack.is_empty() and e.triggers.is_empty(),"mode leader reentry also has no original entry effect")
 fresh_mode()
 entry=put("new-eto-007","deck")
 enter("new-eto-003");one()
 expect(e.pending.get("trigger",{}).get("effect","")=="n21:three_books_search" and e.pending.options[0].selection[0].pool.any(func(r):return r.uid==entry.uid),"ordinary Merry and Renko still trigger the original song search")

func check_discovery():
 for id in G.SPELLS:
  fresh_mode();put(G.VISIT,"palette");put(G.EXPLORE,"palette")
  var c=put(id,"hand");var before_rng=e.rng.state
  for i in range(3):e.targets_for(id,0)
  expect(e.rng.state==before_rng,"legality queries do not reroll "+id)
  var error=e.commit_cast(0,c.uid,{"none":true},e.payment(0,e.cast_cost(0,c)).plan)
  expect(error.is_empty(),"cast discovery "+id);one()
  expect(c.zone=="grave" and e.pending.get("trigger",{}).get("effect","")=="exploration:take","resolution opens discovery and sends source to grave")
  var spec=e.pending.options[0];var pool=spec.selection[0].pool
  expect(pool.size()==3 and pool[0]!=pool[1] and pool[1]!=pool[2] and pool[0]!=pool[2],"exactly three different cards offered")
  expect(pool.all(func(r):
   var info=e.cards[r.outside_id]
   if id==G.VISIT:return info.kind=="单位"
   if id==G.TRAVEL:return info.kind in ["道具","结界"]
   return info.kind=="符卡" and (not info.requires_character.is_empty() if id==G.CLUB else info.requires_character.is_empty())),"discovery category and no leaders without field colors")
  var snapshot=Codec.capture(e);var restored=Duel.new();Codec.restore(restored,snapshot)
  expect(restored.pending==e.pending and restored.rng.state==e.rng.state,"saved discovery keeps choices and RNG")
  var remote=Remote.new();remote.seat=0;remote.apply_snapshot(Seat.build(e,0))
  expect(remote.pending.options==e.pending.options,"choosing network client receives exact options")
  expect(Seat.build(e,1).state.pending.kind=="network_wait","opponent waits without private options")
  var frozen=JSON.stringify(e.pending)
  for invalid in [[],[pool[0],pool[1]],[{"outside_id":"70","none":true}]]:
   e.choose_effect(pick(spec,invalid));expect(JSON.stringify(e.pending)==frozen,"reject empty, multiple and injected choices")
  e.ai_step(0)
  expect(e.players[0].hand.size()==1 and e.players[0].hand[0].card_id in pool.map(func(r):return r.outside_id),"AI selects one offered card into hand")
  expect(e.players[0].field.is_empty(),"discovered card still requires normal payment and timing")
  expect(e.pending.kind=="reveal_review","chosen card is revealed for opponent review")
  expect(e.confirm_revealed(1,e.pending.serial).is_empty() and e.pending.is_empty(),"resolution completes after reveal review")
 fresh_mode()
 var travel_pool=G.candidates(e,0,G.TRAVEL)
 expect(travel_pool.any(func(id):return e.cards[id].kind=="道具") and travel_pool.any(func(id):return e.cards[id].kind=="结界") and travel_pool.all(func(id):return e.cards[id].kind in ["道具","结界"]),"travel bag discovers from the combined item and barrier pool")
 var pool=G.candidates(e,0,G.VISIT)
 expect(not pool.any(func(id):return e.cards[id].kind=="自机"),"no leader options without battlefield colors")
 put(G.VISIT,"field")
 expect(not G.candidates(e,0,G.VISIT).any(func(id):return e.cards[id].kind=="自机"),"spell on field does not satisfy leader permanent requirement")
 put("character-soi-006")
 expect(G.candidates(e,0,G.VISIT).any(func(id):return e.cards[id].kind=="自机"),"Lily White permanent allows corresponding leader options")
 fresh_mode();e.active=1;e.phase="end";e.priority=0;put(G.VISIT,"palette")
 var response=put(G.EXPLORE,"hand")
 expect(e.commit_cast(0,response.uid,{"none":true},e.payment(0,e.cast_cost(0,response)).plan).is_empty() and e.stack.back().exploration_fast_window,"real response captures fast discovery context")

func frequency(kind: String,fast: bool=false) -> Dictionary:
 var counts={}
 for i in range(200):
  for offer in G.discoveries(e,0,kind,fast):counts[offer.outside_id]=counts.get(offer.outside_id,0)+1
 return counts

func discovery_samples(kind: String,samples: Array):
 var definitions={}
 for id in [G.LEADER,G.VISIT,G.EXPLORE,G.TRAVEL,G.CLUB]:
  definitions[id]=e.cards[id].duplicate(true)
 for c in e.players[0].field+e.players[0].palette+e.players[1].field:
  definitions[c.card_id]=e.cards[c.card_id].duplicate(true);definitions[c.card_id].constructible=false
 for i in range(samples.size()):
  var id="guarantee-sample-"+str(i);var info=e.cards[kind].duplicate(true)
  info.name=id;info.canonical_id=id;info.exploration_only=false;info.constructible=true
  info.kind="单位" if kind==G.VISIT else "道具" if kind==G.TRAVEL else "符卡"
  info.requires_character="博丽灵梦" if kind==G.CLUB else ""
  info.abilities=[];info.keywords=[];info.variable_cost="";info.fast=false;info.spell_type=""
  for key in samples[i]:info[key]=samples[i][key]
  info.colors=info.cost.keys();definitions[id]=info
 e.cards=definitions

func check_budget_guarantee():
 for kind in [G.VISIT,G.EXPLORE,G.TRAVEL]:
  fresh_mode();put("164","palette");put("167");put("character-fdf-098")
  discovery_samples(kind,[{"cost":{"黄":2,"绿":1,"蓝":1}},{"cost":{"红":4}},{"cost":{"黄":1}},{"cost":{"蓝":1}},{"cost":{"黄":1},"variable_cost":"黄"}])
  expect(G.budgets(e,0)[0]==4,"budget counts palette, item and paired Inaba resources: "+kind)
  expect(G.full_budget_payment(e,0,"guarantee-sample-0",4) and not G.full_budget_payment(e,0,"guarantee-sample-1",4),"guarantee requires a real colored payment: "+kind)
  var before=JSON.stringify([e.players,e.next_uid,e.revision,e.stack,e.presentation_events]);var rng_state=e.rng.state
  var first=[];var sequence=[];var unique=true
  for i in range(80):
   var offers=G.discoveries(e,0,kind);first.append(offers[0].outside_id);sequence.append(offers)
   var names=offers.map(func(o):return e.cards[o.outside_id].name)
   unique=unique and names.size()==3 and names[0]!=names[1] and names[1]!=names[2] and names[0]!=names[2]
  expect(first.all(func(id):return id=="guarantee-sample-0"),"every discovery guarantees the only payable fixed exact fit before X: "+kind)
  expect(unique,"guarantee still offers three distinct cards: "+kind)
  expect(before==JSON.stringify([e.players,e.next_uid,e.revision,e.stack,e.presentation_events]),"simulated guarantee never spends resources or creates cards: "+kind)
  e.rng.state=rng_state;var repeated=[]
  for i in range(80):repeated.append(G.discoveries(e,0,kind))
  expect(sequence==repeated,"seeded guarantee is reproducible: "+kind)
  # The only exact fixed card becomes unavailable; X now uses the entire budget.
  e.cards["guarantee-sample-0"].cost={"红":4}
  e.cards["guarantee-sample-4"].cost={"黄":1,"绿":1,"蓝":1}
  expect(G.full_budget_payment(e,0,"guarantee-sample-4",4),"X fallback can consume paired and single sources: "+kind)
  var x_first=true
  for i in range(40):x_first=x_first and G.discoveries(e,0,kind)[0].outside_id=="guarantee-sample-4"
  expect(x_first,"X guarantees only when no fixed exact fit exists: "+kind)
  # Neither fixed nor X can pay red; ordinary weighted discovery remains possible.
  e.cards["guarantee-sample-4"].variable_cost="红"
  expect(not G.full_budget_payment(e,0,"guarantee-sample-4",4),"color-stalled X is never a guarantee: "+kind)
  expect(frequency(kind).keys().size()>1,"no exact payment falls back to ordinary weighted choices: "+kind)
 fresh_mode();put("character-fdf-098")
 discovery_samples(G.VISIT,[{"cost":{"黄":2}},{"cost":{"黄":1,"绿":1}},{"cost":{"黄":1}}])
 expect(not G.full_budget_payment(e,0,"guarantee-sample-0",2) and G.full_budget_payment(e,0,"guarantee-sample-1",2),"Inaba pays yellow and green together, never two yellow")
 e.players[0].field[0].entered_turns=e.players[0].turns
 expect(G.budgets(e,0)[0]==0,"summoning-sick Inaba is excluded from remaining budget")
 fresh_mode();put("167","palette").tapped=true;put("165").tapped=true
 discovery_samples(G.TRAVEL,[{"cost":{}},{"cost":{"红":2}},{"cost":{"蓝":1}}])
 expect(G.budgets(e,0)[0]==0 and G.discoveries(e,0,G.TRAVEL)[0].outside_id=="guarantee-sample-0","zero resources guarantee a zero-cost card and ignore tapped sources")
 fresh_mode();for i in range(5):put("164","palette")
 discovery_samples(G.EXPLORE,[{"cost":{"黄":2},"variable_cost":"黄","variable_multiplier":2},{"cost":{"黄":1}},{"cost":{"黄":3}}])
 expect(not G.full_budget_payment(e,0,"guarantee-sample-0",5),"double X cannot consume an odd remainder")
 put("164","palette")
 expect(G.full_budget_payment(e,0,"guarantee-sample-0",6),"double X consumes an even remainder")
 fresh_mode();put("24");put("167","palette");put("167","palette")
 discovery_samples(G.EXPLORE,[{"cost":{"蓝":3}},{"cost":{"蓝":1}},{"cost":{"黄":2}}])
 expect(G.full_budget_payment(e,0,"guarantee-sample-0",2) and G.discoveries(e,0,G.EXPLORE)[0].outside_id=="guarantee-sample-0","guarantee uses the effective discounted casting cost")
 put("24")
 e.cards["guarantee-sample-0"].cost={};e.cards["guarantee-sample-0"].variable_cost="蓝"
 expect(G.full_budget_payment(e,0,"guarantee-sample-0",2),"X search passes zero-cost discount bands to reach the payable exact X")
 fresh_mode();put("164","palette");e.players[0].potato=true
 discovery_samples(G.TRAVEL,[{"cost":{"黄":1,"黑":1}},{"cost":{"黄":1}},{"cost":{"蓝":1}}])
 expect(G.budgets(e,0)[0]==2 and G.full_budget_payment(e,0,"guarantee-sample-0",2),"potato is included as a remaining wildcard payment")
 fresh_mode();put(G.VISIT,"palette");put(G.VISIT,"palette")
 discovery_samples(G.TRAVEL,[{"cost":{"黄":2}},{"cost":{"黄":2}},{"cost":{"黄":1}},{"cost":{"黄":3}}])
 e.cards["guarantee-sample-1"].name=e.cards["guarantee-sample-0"].name
 var distinct_names=true
 for i in range(40):
  var names=G.discoveries(e,0,G.TRAVEL).map(func(o):return e.cards[o.outside_id].name)
  distinct_names=distinct_names and names.size()==3 and names[0]!=names[1] and names[1]!=names[2] and names[0]!=names[2]
 expect(distinct_names,"guaranteed and ordinary slots cannot repeat the same card name across IDs")
 fresh_mode();for i in range(4):put("164","palette")
 discovery_samples(G.CLUB,[{"cost":{"黄":4}},{"cost":{"黄":1}},{"cost":{"黄":2}},{"cost":{"黄":3}},{"cost":{"黄":5}}])
 var unguaranteed=false
 for i in range(80):unguaranteed=unguaranteed or not G.discoveries(e,0,G.CLUB).any(func(o):return o.outside_id=="guarantee-sample-0")
 expect(unguaranteed,"club activity retains ordinary random discovery without a guarantee")

func check_visit_zero_budget():
 for next_turn in [1,4,8]:
  fresh_mode()
  for i in range(next_turn-1 if next_turn<8 else 8):put("164","palette").tapped=true
  discovery_samples(G.VISIT,[{"cost":{}},{"cost":{"红":next_turn}},{"cost":{"黄":next_turn+1}},{"cost":{"黄":next_turn},"variable_cost":"黄"}])
  expect(G.budgets(e,0)==[0,next_turn],"zero-resource Merry fixture predicts refreshed palette and growth: "+str(next_turn))
  expect(G.full_budget_payment(e,0,"guarantee-sample-0",0) and not G.full_budget_payment(e,0,"guarantee-sample-1",next_turn),"zero-resource Merry has a payable zero cost but no current payment for the predicted cost")
  var before=JSON.stringify([e.players,e.next_uid,e.revision,e.stack,e.presentation_events]);var rng_state=e.rng.state
  var sequence=[];var guaranteed=true;var zero_offered=false
  for i in range(40):
   var offers=G.discoveries(e,0,G.VISIT);sequence.append(offers)
   guaranteed=guaranteed and offers[0].outside_id=="guarantee-sample-1"
   zero_offered=zero_offered or offers.any(func(o):return o.outside_id=="guarantee-sample-0")
  expect(guaranteed,"zero-resource Merry guarantees the predicted fixed cost before X, never zero cost: "+str(next_turn))
  expect(zero_offered,"zero-cost units remain in ordinary Merry discovery slots")
  expect(G.weight(e.cards["guarantee-sample-0"],G.VISIT,[0,next_turn],false,false,true)==G.weight(e.cards["guarantee-sample-1"],G.VISIT,[0,next_turn],false,false,false),"zero-cost units retain the same exact-budget bonus as the predicted cost")
  expect(before==JSON.stringify([e.players,e.next_uid,e.revision,e.stack,e.presentation_events]),"predicted guarantee never changes cards or resources")
  e.rng.state=rng_state;var repeated=[]
  for i in range(40):repeated.append(G.discoveries(e,0,G.VISIT))
  expect(sequence==repeated,"zero-resource predicted guarantee is reproducible")
  e.cards["guarantee-sample-1"].cost={"红":next_turn+1}
  expect(G.discoveries(e,0,G.VISIT)[0].outside_id=="guarantee-sample-3","predicted X cost is the fallback when no fixed predicted cost exists")
 fresh_mode();e.players[0].deck=[]
 discovery_samples(G.VISIT,[{"cost":{}},{"cost":{"黄":1}},{"cost":{"黄":2}},{"cost":{"黄":3}}])
 var first={}
 for i in range(80):first[G.discoveries(e,0,G.VISIT)[0].outside_id]=true
 expect(G.budgets(e,0)==[0,0] and first.size()>1,"no predicted resources leave Merry unguaranteed, without forcing a zero-cost unit")
 for kind in [G.EXPLORE,G.TRAVEL]:
  fresh_mode();put("164","palette").tapped=true
  discovery_samples(kind,[{"cost":{}},{"cost":{"黄":2}},{"cost":{"黄":1}}])
  expect(G.discoveries(e,0,kind)[0].outside_id=="guarantee-sample-0","other discovery categories retain the current zero-cost guarantee: "+kind)

func check_visit_high_budget():
 for remaining in [6,7]:
  fresh_mode();e.enter_field(e.players[0].leader,0)
  for i in range(8):put(G.VISIT,"palette").tapped=i>=remaining
  # Uneven band sizes and a leader bonus must not change cost probabilities.
  var samples=[{"cost":{"黄":5}}]
  for i in range(4):samples.append({"cost":{"黄":6},"kind":"自机"})
  for i in range(2):samples.append({"cost":{"黄":7}})
  samples.append({"cost":{"黄":8}});samples.append({"cost":{"黄":1},"variable_cost":"黄"})
  discovery_samples(G.VISIT,samples);e.rng.seed=6143+remaining
  var expected={5:0.5,6:0.5} if remaining==6 else {5:1.0/6.0,6:0.5,7:1.0/3.0}
  var counts={};var valid=true;var unique=true;var trials=900
  var before=JSON.stringify([e.players,e.next_uid,e.revision,e.stack,e.presentation_events])
  for i in range(trials):
   var offers=G.discoveries(e,0,G.VISIT);var info=e.cards[offers[0].outside_id]
   var cost=int(info.cost["黄"]);counts[cost]=counts.get(cost,0)+1
   valid=valid and expected.has(cost) and info.variable_cost.is_empty()
   var names=offers.map(func(o):return e.cards[o.outside_id].name)
   unique=unique and names.size()==3 and names[0]!=names[1] and names[1]!=names[2] and names[0]!=names[2]
  expect(valid and unique,"Merry high-budget guarantees only payable fixed bands and three distinct names: "+str(remaining))
  for cost in expected:
   expect(abs(float(counts.get(cost,0))/trials-expected[cost])<0.05,"Merry guarantee cost probability ignores band size and leader/exact bonuses: "+str(remaining)+" -> "+str(cost))
  expect(before==JSON.stringify([e.players,e.next_uid,e.revision,e.stack,e.presentation_events]),"Merry high-budget probes preserve cards and resources")
  var rng_state=e.rng.state;var sequence=[];var repeated=[]
  for i in range(30):sequence.append(G.discoveries(e,0,G.VISIT))
  e.rng.state=rng_state
  for i in range(30):repeated.append(G.discoveries(e,0,G.VISIT))
  expect(sequence==repeated,"Merry cost-band and card picks restore from the same RNG state")
  print("MERRY GUARANTEE COST COUNTS at remaining "+str(remaining)+": "+str(counts))
 fresh_mode();for i in range(7):put("164","palette")
 discovery_samples(G.VISIT,[{"cost":{"黄":5}},{"cost":{"红":6}},{"cost":{"黄":7}},{"cost":{"黄":1},"variable_cost":"黄"},{"cost":{"黄":8}}])
 var counts={};var valid=true
 for i in range(300):
  var id=G.discoveries(e,0,G.VISIT)[0].outside_id;counts[id]=counts.get(id,0)+1
  valid=valid and id in ["guarantee-sample-0","guarantee-sample-2"]
 expect(valid and abs(float(counts.get("guarantee-sample-0",0))/300-1.0/3.0)<0.08,"missing payable six-cost band renormalizes five/seven odds to one/two before X")
 e.cards["guarantee-sample-2"].cost={"红":7}
 expect(G.discoveries(e,0,G.VISIT)[0].outside_id=="guarantee-sample-0","only payable fixed five-cost card still guarantees ahead of X")
 e.cards["guarantee-sample-0"].cost={"红":5}
 expect(G.discoveries(e,0,G.VISIT)[0].outside_id=="guarantee-sample-3","Merry uses payable X bands only after all fixed bands disappear")
 e.cards["guarantee-sample-3"].variable_cost="红"
 var first={}
 for i in range(40):first[G.discoveries(e,0,G.VISIT)[0].outside_id]=true
 expect(first.size()>1,"no payable fixed or X band falls back to ordinary Merry discovery")
 fresh_mode();put("character-soi-006")
 for i in range(6):put("167","palette")
 discovery_samples(G.VISIT,[{"cost":{"蓝":7},"abilities":Store.CARDS["174"].abilities.duplicate(true)},{"cost":{"蓝":1}},{"cost":{"黄":5}}])
 expect(G.full_budget_payment(e,0,"guarantee-sample-0",6) and G.discoveries(e,0,G.VISIT)[0].outside_id=="guarantee-sample-0","Merry high-budget bands use effective casting costs after unit discounts")

func check_explore_seven_budget():
 fresh_mode()
 for i in range(8):put("164","palette").tapped=i==7
 discovery_samples(G.EXPLORE,[{"cost":{"黄":6}},{"cost":{"黄":7}},{"cost":{"蓝":6}},{"cost":{"黄":5}},{"cost":{"黄":8}},{"cost":{"黄":1},"variable_cost":"黄","variable_multiplier":2}])
 expect(G.budgets(e,0)==[7,8],"Renko seven-budget fixture separates current and next-turn costs")
 var first={};var guaranteed=true
 for i in range(120):
  var id=G.discoveries(e,0,G.EXPLORE)[0].outside_id;first[id]=true
  guaranteed=guaranteed and id in ["guarantee-sample-0","guarantee-sample-1"]
 expect(guaranteed and first.size()==2,"payable fixed six and seven costs share Renko's seven-budget guarantee pool before X")
 expect(G.weight(e.cards["guarantee-sample-1"],G.EXPLORE,[7,8],false,false,true)==4.0*G.weight(e.cards["guarantee-sample-0"],G.EXPLORE,[7,8],false,false,false),"six-cost guarantee entry retains its ordinary weight while exact seven costs receive the fourfold bonus")
 e.cards["guarantee-sample-1"].cost={"红":7}
 guaranteed=true
 for i in range(40):guaranteed=guaranteed and G.discoveries(e,0,G.EXPLORE)[0].outside_id=="guarantee-sample-0"
 expect(guaranteed,"payable fixed six cost guarantees ahead of exact X when seven cost is color-stalled")
 e.cards["guarantee-sample-0"].cost={"红":6}
 e.cards["guarantee-sample-5"].cost={"黄":2}
 expect(not G.full_budget_payment(e,0,"guarantee-sample-5",7) and G.full_budget_payment(e,0,"guarantee-sample-5",6) and G.discoveries(e,0,G.EXPLORE)[0].outside_id=="guarantee-sample-5","X can use the six-cost fallback only after both fixed guarantee costs are unavailable")
 # Other budgets retain the exact guarantee outside the dedicated exceptions.
 for kind in [G.VISIT,G.EXPLORE,G.TRAVEL]:
  for remaining in [6,7,8]:
   if (kind==G.EXPLORE and remaining==7) or (kind==G.VISIT and remaining in [6,7]):continue
   fresh_mode()
   for i in range(remaining):put("164","palette")
   discovery_samples(kind,[{"cost":{"黄":remaining}},{"cost":{"黄":remaining-1}},{"cost":{"黄":1}},{"cost":{"黄":9}}])
   guaranteed=true
   for i in range(25):guaranteed=guaranteed and G.discoveries(e,0,kind)[0].outside_id=="guarantee-sample-0"
   expect(guaranteed,"other budgets retain the exact guarantee: "+kind+" "+str(remaining))

func check_stacked_weights():
 fresh_mode()
 var ordinary=e.cards["character-soi-006"].duplicate(true);ordinary.cost={"黄":2};ordinary.kind="单位";ordinary.variable_cost=""
 var leader=ordinary.duplicate(true);leader.cost={"黄":4};leader.kind="自机"
 expect(G.weight(leader,G.VISIT,[4,7],false,true,true)==8.0*G.weight(ordinary,G.VISIT,[4,7],false,false,false),"payable exact leader stacks fourfold cost and twofold Merry/Renko bonuses into eightfold weight")
 var fast=ordinary.duplicate(true);fast.cost={"黄":4};fast.fast=true
 expect(G.weight(fast,G.EXPLORE,[4,7],true,false,true)==16.0*G.weight(ordinary,G.EXPLORE,[4,7],false,false,false),"fast and exact-cost weights multiply")
 expect(G.weight(fast,G.EXPLORE,[4,7],false,false,false)==G.weight(ordinary,G.EXPLORE,[4,7],false,false,false),"an unpayable current exact cost receives no exact-current bonus")
 expect(G.weight(fast,G.EXPLORE,[2,4],false,false,false)==4.0*G.weight(ordinary,G.EXPLORE,[1,4],false,false,false),"next-turn exact cost retains fourfold preference")
 # Both guarantee and ordinary slots use the same leader/fast multipliers.
 fresh_mode();e.enter_field(e.players[0].leader,0);for i in range(4):put(G.VISIT,"palette")
 var samples=[]
 for i in range(16):samples.append({"cost":{"黄":4 if i<8 else 2},"kind":"自机" if i%2==0 else "单位"})
 discovery_samples(G.VISIT,samples);e.rng.seed=719
 var boosted=[0,0];var normal=[0,0];var source=e.players[0].leader
 for with_bonus in [true,false]:
  if not with_bonus:
   e.move_to(source,"leader",false);e.cards["character-soi-006"]=Store.CARDS["character-soi-006"].duplicate(true)
   put("character-soi-006");e.cards["character-soi-006"].constructible=false
  e.rng.seed=719
  for i in range(200):
   var offers=G.discoveries(e,0,G.VISIT)
   for slot in range(offers.size()):
    if e.cards[offers[slot].outside_id].kind=="自机":
     var counts=boosted if with_bonus else normal;counts[0 if slot==0 else 1]+=1
 expect(boosted[0]>normal[0]+20 and boosted[1]>normal[1]+30,"leader bonus applies in both guaranteed and ordinary discovery slots")

func check_visit_leader_preference():
 fresh_mode()
 var definitions={G.LEADER:e.cards[G.LEADER],"character-soi-006":e.cards["character-soi-006"].duplicate(true)}
 definitions["character-soi-006"].constructible=false
 put("character-soi-006")
 for i in range(8):
  var info=e.cards["character-soi-006"].duplicate(true);var id="visit-sample-"+str(i)
  info.name=id;info.canonical_id=id;info.constructible=true;info.abilities=[];info.keywords=[]
  info.kind="自机" if i<4 else "单位";info.cost={"黄":1};info.colors=["黄"];definitions[id]=info
 e.cards=definitions;e.rng.seed=16384
 var baseline=frequency(G.VISIT)
 var source=e.players[0].leader
 e.enter_field(source,0);e.rng.seed=16384
 var boosted=frequency(G.VISIT);var normal_leaders=0;var boosted_leaders=0
 for i in range(4):normal_leaders+=baseline.get("visit-sample-"+str(i),0);boosted_leaders+=boosted.get("visit-sample-"+str(i),0)
 expect(boosted_leaders>normal_leaders+50,"mode leader on battlefield increases leader offers with the same costs and eligible pool")
 source.tapped=true;e.rng.seed=16384
 expect(frequency(G.VISIT)==boosted,"tapped mode leader keeps the continuous discovery bonus")
 for zone in ["leader","hand","deck","palette","grave","exile"]:
  e.move_to(source,zone,false);source.tapped=true;e.rng.seed=16384
  expect(frequency(G.VISIT)==baseline,"leader discovery bonus stops outside battlefield: "+zone)
 e.enter_field(e.players[1].leader,1);e.rng.seed=16384
 expect(frequency(G.VISIT)==baseline,"opponent's mode leader does not boost own discovery")
 var copy=put(G.LEADER);e.rng.seed=16384
 expect(frequency(G.VISIT)==baseline,"ordinary mode-leader copy without self ability does not boost discovery")
 copy.leader_counters=1;e.rng.seed=16384
 expect(frequency(G.VISIT)==boosted,"granted self ability enables the bonus on a battlefield copy")
 e.move_to(copy,"exile",false);e.enter_field(source,0);e.rng.seed=16384
 expect(frequency(G.VISIT)==boosted,"mode leader reentry restores discovery bonus")
 var restored=Duel.new();Codec.restore(restored,Codec.capture(e))
 expect(G.discoveries(restored,0,G.VISIT)==G.discoveries(e,0,G.VISIT),"saved battlefield leader and RNG reproduce boosted discovery")
 print("VISIT LEADER OFFER COUNTS [before, on battlefield]: "+str([normal_leaders,boosted_leaders]))
 fresh_mode();source=e.players[0].leader;e.enter_field(source,0);source.token_colors=["红","黄"]
 var pool=G.candidates(e,0,G.VISIT)
 expect(pool.any(func(id):return e.cards[id].kind=="自机") and pool.all(func(id):return e.cards[id].kind!="自机" or G.color_constraint_met(e,0,e.cards[id])),"boosted discovery still filters leaders by actual battlefield colors")
 e.move_to(source,"exile",false)
 var other_offers={}
 for kind in [G.EXPLORE,G.TRAVEL,G.CLUB]:
  e.rng.seed=16384;other_offers[kind]=G.discoveries(e,0,kind)
 e.enter_field(source,0)
 for kind in other_offers:
  e.rng.seed=16384
  expect(G.discoveries(e,0,kind)==other_offers[kind],"mode leader bonus leaves other discovery kinds unchanged: "+kind)

func check_random_preferences():
 fresh_mode()
 for i in range(8):put(G.VISIT,"palette").tapped=true
 expect(G.budgets(e,0)==[0,8],"next-turn cost preference respects the eight-card palette growth cap")
 e.players[0].palette=[]
 var definitions={}
 for i in range(8):
  var info=e.cards[G.EXPLORE].duplicate(true);var id="sample-"+str(i)
  info.name=id;info.canonical_id=id;info.exploration_only=false;info.constructible=true
  info.cost={"黄":1};info.keywords=[];info.fast=i<4;info.requires_character="";definitions[id]=info
 e.cards=definitions;e.rng.seed=2048
 var ordinary=frequency(G.EXPLORE);var sped=frequency(G.EXPLORE,true);var normal_fast=0;var boosted_fast=0
 for i in range(4):normal_fast+=ordinary.get("sample-"+str(i),0);boosted_fast+=sped.get("sample-"+str(i),0)
 expect(boosted_fast>normal_fast+100,"fast windows substantially increase fast spell offerings")
 for i in range(8):
  definitions["sample-"+str(i)].requires_character="博丽灵梦"
  if i<2:definitions["sample-"+str(i)].keywords=["限制级" if i==0 else "终言"]
 var rare=frequency(G.CLUB)
 expect(rare.get("sample-0",0)+rare.get("sample-1",0)<80,"limited and last-word spells appear less often")
 for i in range(8):
  definitions["sample-"+str(i)].requires_character="";definitions["sample-"+str(i)].cost={"黄":1 if i<4 else 9}
 var affordable=frequency(G.EXPLORE);var low=0
 for i in range(4):low+=affordable.get("sample-"+str(i),0)
 expect(low>500,"discovery overwhelmingly favors remaining or next-turn budget")

func check_exact_budget_preferences():
 for kind in [G.VISIT,G.EXPLORE,G.TRAVEL]:
  fresh_mode()
  for i in range(6):put(G.VISIT,"palette").tapped=i>=4
  expect(G.budgets(e,0)==[4,7],"discovery fixture has distinct remaining and next-turn total budgets")
  var definitions={G.VISIT:e.cards[G.VISIT]}
  for i in range(16):
   var info=e.cards[kind].duplicate(true);var id="budget-sample-"+str(i)
   info.name=id;info.canonical_id=id;info.exploration_only=false;info.constructible=true
   info.kind="单位" if kind==G.VISIT else "符卡" if kind==G.EXPLORE else "道具" if i%2==0 else "结界"
   info.requires_character="";info.fast=false;info.keywords=[]
   info.cost={"黄":4 if i<4 else 7 if i<8 else 2 if i<12 else 9};definitions[id]=info
  e.cards=definitions;e.rng.seed=4096
  var counts=frequency(kind);var remaining=0;var next_turn=0;var cheaper=0;var expensive=0
  for i in range(16):
   var count=counts.get("budget-sample-"+str(i),0)
   if i<4:remaining+=count
   elif i<8:next_turn+=count
   elif i<12:cheaper+=count
   else:expensive+=count
  expect(remaining>200 and next_turn>200 and remaining+next_turn>500,"both exact budgets dominate other affordable costs: "+kind)
  expect(cheaper>0 and expensive>0,"other costs remain discoverable: "+kind)
  print("EXACT BUDGET OFFER COUNTS [remaining, next-turn, cheaper, expensive] "+kind+": "+str([remaining,next_turn,cheaper,expensive]))

func check_club_preferences():
 fresh_mode()
 for i in range(8):put(G.VISIT,"palette")
 var definitions={G.VISIT:e.cards[G.VISIT]}
 for i in range(8):
  var info=e.cards[G.CLUB].duplicate(true);var id="club-sample-"+str(i)
  info.name=id;info.canonical_id=id;info.exploration_only=false;info.constructible=true
  info.requires_character="博丽灵梦";info.cost={"蓝":1 if i<4 else 7};info.keywords=[];info.spell_type="角色符卡"
  if i==0:info.keywords=["限制级符卡"]
  elif i==1:info.keywords=["终言"]
  elif i==4:info.spell_type="限制级角色符卡"
  elif i==5:info.spell_type="终言"
  definitions[id]=info
 e.cards=definitions
 var totals=[]
 for remaining in [0,3,7]:
  for i in range(8):e.players[0].palette[i].tapped=i>=remaining
  expect(G.budgets(e,0)==[remaining,8],"club fixture changes current resources with the same next-turn budget")
  e.rng.seed=8192
  var counts=frequency(G.CLUB);var high=0;var limited=0;var last_word=0
  for i in range(8):
   var count=counts.get("club-sample-"+str(i),0)
   if i>=4:high+=count
   if i in [0,4]:limited+=count
   if i in [1,5]:last_word+=count
  totals.append([high,limited,last_word])
 expect(totals[0][0]<totals[1][0] and totals[1][0]<totals[2][0],"higher remaining resources increase high-cost character spell offerings")
 expect(totals[0][1]<totals[1][1] and totals[1][1]<totals[2][1],"higher remaining resources increase limited spell offerings with keyword or spell-type tags")
 expect(totals[0][2]<totals[1][2] and totals[1][2]<totals[2][2],"higher remaining resources increase last-word offerings with keyword or spell-type tags")
 print("CLUB OFFER COUNTS [high-cost, limited, last-word] at remaining 0/3/7: "+str(totals))
 fresh_mode()

func check_adjusted_card_weights():
 fresh_mode()
 var adjusted={"spell-fdf-027":0.1,"spell-fdf-076":0.1,"153":0.1,"spell-fdn-046":0.1,"spell-fdf-123":0.5}
 for id in adjusted:
  var info=Store.CARDS[id];var baseline=info.duplicate(true);baseline.canonical_id="ordinary-weight-sample"
  expect(id in G.candidates(e,0,G.CLUB),"adjusted spell remains in the character discovery pool: "+id)
  for remaining in [0,4,7]:
   for fast in [false,true]:
    expect(is_equal_approx(G.weight(info,G.CLUB,[remaining,8],fast),adjusted[id]*G.weight(baseline,G.CLUB,[remaining,8],fast)),"card-specific discovery reduction stacks with existing cost/rarity weights: "+id+" "+str(remaining))
  var alias=info.duplicate(true);alias.name="alternate-name"
  expect(G.weight(alias,G.CLUB,[4,8],false)==G.weight(info,G.CLUB,[4,8],false),"alternate names retain canonical card tuning: "+id)
 for id in ["spell-fdf-024","128"]:
  var info=Store.CARDS[id];var baseline=info.duplicate(true);baseline.canonical_id="ordinary-weight-sample"
  expect(G.weight(info,G.CLUB,[7,8],false)==G.weight(baseline,G.CLUB,[7,8],false),"other limited and last-word spells keep their existing weight: "+id)
 # Compare equal-cost groups to exercise actual sampling with all five tunings.
 fresh_mode();for i in range(4):put(G.VISIT,"palette")
 var samples=[];var ids=adjusted.keys()
 for id in ids:samples.append({"cost":{"黄":4},"canonical_id":id})
 for i in range(20):samples.append({"cost":{"黄":4}})
 discovery_samples(G.CLUB,samples)
 for i in range(ids.size()):
  var sample_id="guarantee-sample-"+str(i);e.cards[ids[i]]=e.cards[sample_id];e.cards.erase(sample_id)
 e.rng.seed=50123;var groups=[0,0,0]
 for i in range(1000):
  for offer in G.discoveries(e,0,G.CLUB):groups[1 if offer.outside_id=="spell-fdf-123" else 0 if offer.outside_id in ids else 2]+=1
 expect(groups[0]*20<groups[2]*4*0.25,"four heavily reduced spells are much rarer per card across discovery slots")
 expect(groups[1]*20<groups[2]*0.8 and groups[1]*4>groups[0]*2.0,"Rainy Night's moderate reduction lies between ordinary cards and the four rare cards")
 expect(groups[0]>0 and groups[1]>0,"reduced spells can still be discovered")
 print("ADJUSTED SPELL OFFER COUNTS [four rare, rainy night, ordinary]: "+str(groups))

func check_variable_cost_preferences():
 for kind in G.SPELLS:
  fresh_mode()
  for i in range(8):put(G.VISIT,"palette")
  var definitions={G.VISIT:e.cards[G.VISIT]}
  for i in range(16):
   var info=e.cards[kind].duplicate(true);var id="x-sample-"+str(i)
   info.name=id;info.canonical_id=id;info.exploration_only=false;info.constructible=true
   info.kind="单位" if kind==G.VISIT else "道具" if kind==G.TRAVEL else "符卡"
   info.requires_character="博丽灵梦" if kind==G.CLUB else "";info.fast=false;info.keywords=[];info.spell_type=""
   info.cost={"黄":2};info.variable_cost="黄" if i<4 else "";info.variable_multiplier=1 if i<2 else 2
   definitions[id]=info
  e.cards=definitions
  var totals=[];var last_counts={}
  for remaining in [2,4,8]:
   for i in range(8):e.players[0].palette[i].tapped=i>=remaining
   expect(G.budgets(e,0)==[remaining,8],"X fixture holds the next-turn budget constant: "+kind)
   e.rng.seed=32768;last_counts=frequency(kind);var variable=0
   for i in range(4):variable+=last_counts.get("x-sample-"+str(i),0)
   totals.append(variable)
  if kind==G.TRAVEL:
   expect(totals[0]<totals[1] and totals[1]==totals[2],"travel bag uses X only after fixed guarantee disappears, without an extra X magnitude bonus")
  else:
   expect(totals[1]>totals[0]+100 and totals[2]>totals[1]+20,"higher current resources increasingly favor X-cost offers: "+kind)
   var single=last_counts.get("x-sample-0",0)+last_counts.get("x-sample-1",0)
   var doubled=last_counts.get("x-sample-2",0)+last_counts.get("x-sample-3",0)
   expect(single>doubled,"X bonus accounts for the payable X with doubled costs: "+kind)
  e.rng.seed=32768
  expect(frequency(kind)==last_counts,"seeded X discovery reproduces the same offers: "+kind)
  print("X OFFER COUNTS at remaining 2/4/8 "+kind+": "+str(totals))
 fresh_mode()
 var variable=e.cards["111"].duplicate(true);var fixed=variable.duplicate(true);fixed.variable_cost=""
 for kind in [G.VISIT,G.EXPLORE,G.CLUB]:
  for remaining in [0,1,2]:
   expect(G.weight(variable,kind,[remaining,8],false)==G.weight(fixed,kind,[remaining,8],false),"X cost receives no bonus without resources above its fixed cost: "+kind)
  var doubled=variable.duplicate(true);doubled.variable_multiplier=2
  expect(G.weight(doubled,kind,[3,8],false)==G.weight(fixed,kind,[3,8],false),"doubled X requires two resources above its fixed cost: "+kind)
  expect(G.weight(variable,kind,[8,8],false)>G.weight(doubled,kind,[8,8],false),"larger payable X receives a stronger discovery bonus: "+kind)
 expect(G.weight(variable,G.EXPLORE,[8,8],true)==4.0*G.weight(variable,G.EXPLORE,[8,8],false),"fast-window preference stacks with the X bonus")
 variable.kind="自机"
 expect(G.weight(variable,G.VISIT,[8,8],false,true)==G.VISIT_LEADER_WEIGHT*G.weight(variable,G.VISIT,[8,8],false),"battlefield leader preference stacks with the X bonus")
 variable.keywords=["限制级符卡"]
 var ordinary=variable.duplicate(true);ordinary.keywords=[]
 expect(G.weight(variable,G.CLUB,[4,8],false)<G.weight(ordinary,G.CLUB,[4,8],false),"limited X spells retain the club rarity penalty")

func check_series():
 var series=Series.new();series.setup(Series.EXPLORATION,false,"official")
 expect(series.state.decks==[G.deck(),G.deck()] and series.state.strict and series.state.rule_set=="unrestricted","entertainment room assigns both fixed decks")
 expect(not series.set_deck(0,Store.blank()).is_empty(),"room rejects custom deck replacement")
 expect(series.ready(0).is_empty() and not series.prepare_choice(),"one ready player cannot start")
 expect(series.ready(1).is_empty() and series.prepare_choice() and series.state.status=="choosing","both fixed decks prepare directly for dice")
 series.choose_first(series.state.chooser,true)
 expect(series.start_game() and series.state.registered==[G.deck(),G.deck()],"fixed room begins a real game")
 expect(series.public_state(1).own_deck==G.deck(),"guest receives fixed deck in room state")
 expect(series.record_result(0) and series.state.status=="complete","entertainment room is a single game")
 expect(series.rematch().is_empty() and series.state.format==Series.EXPLORATION and series.state.decks==[G.deck(),G.deck()],"rematch preserves format and restores fixed decks")

func check_passive_ai():
 var opponent=G.deck();opponent.ai_passive=true
 e=Duel.new();e.start(G.deck(),opponent,1,42)
 var hand=e.players[1].hand.map(func(c):return c.uid)
 e.ai_step(1)
 expect(e.players[1].mulligan_done and not e.players[0].mulligan_done and e.players[1].hand.map(func(c):return c.uid)==hand,"passive opponent confirms its original opening hand without changing the human hand")
 expect(e.ai_profiles==["",Duel.PASSIVE_AI] and not G.deck().has("ai_passive"),"passive behavior belongs only to the local opponent")
 fresh_mode(true);e.active=1;e.priority=1
 for i in range(5):put(G.VISIT,"palette",1)
 var spell=put(G.VISIT,"hand",1);var fast=put(G.EXPLORE,"hand",1);var fighter=put("70","field",1)
 expect(e.legal_casts(1).size()>=3 and e.can_attack(1,fighter.uid),"passive fixture has legal spells, leader and attack")
 e.ai_step(1)
 expect(e.priority==0 and e.stack.is_empty() and e.combat.is_empty() and spell.zone=="hand" and not fighter.tapped and e.players[1].leader.zone=="leader","passive main phase passes without casting, deploying or attacking")
 e.offer_possession();e.ai_step(1)
 expect(e.pending.is_empty() and spell.zone=="hand" and e.players[1].palette.size()==5,"passive opponent skips possession")
 e.priority=0;var human_spell=put(G.EXPLORE,"hand");put(G.EXPLORE,"palette")
 expect(e.commit_cast(0,human_spell.uid,{"none":true},e.payment(0,e.cast_cost(0,human_spell)).plan).is_empty(),"human can cast during passive opponent turn")
 e.ai_step(1)
 expect(e.priority==0 and e.stack.size()==1 and fast.zone=="hand" and not e.players[1].palette.any(func(c):return c.tapped),"passive response window passes without using a fast spell")
 fresh_mode(true);e.active=0;e.priority=0
 var attacker=put("70");var blocker=put("70","field",1)
 e.attack(0,attacker.uid);e.ai_step(1);e.pass_priority(0)
 expect(e.pending.get("kind","")=="block" and not e.legal_blockers().is_empty(),"attack offers a legal passive blocker")
 e.ai_step(1)
 expect(e.pending.is_empty() and e.combat.blockers.is_empty() and not blocker.tapped,"passive opponent declines voluntary blocking")
 fresh_mode(true);var source=put("70","field",1);put("70")
 e.queue_trigger(1,source,1,"可选效果");e.pump_choices();e.ai_step(1)
 expect(e.pending.is_empty() and e.stack.is_empty(),"passive opponent declines optional triggered ability")
 fresh_mode(true);source=put("2","field",1);e.move_to(source,"grave");e.pump_choices();e.ai_step(1)
 expect(e.pending.is_empty() and e.stack.is_empty() and source.zone=="grave","passive opponent declines optional extended ability")
 fresh_mode(true);e.active=1;e.priority=1;put(G.EXPLORE,"palette",1);spell=put(G.VISIT,"hand",1)
 e.commit_cast(1,spell.uid,{"none":true},e.payment(1,e.cast_cost(1,spell)).plan);one();e.ai_step(1)
 expect(e.players[1].hand.size()==1 and e.pending.get("kind","")=="reveal_review" and e.pending.owner==0,"forced discovery chooses one card and leaves human reveal confirmation to the human")
 var before=e.revision;e.ai_step(1);expect(e.revision==before,"passive AI cannot confirm a human-owned choice")
 e.confirm_revealed(0,e.pending.serial)
 e.pending={"kind":"reveal_review","owner":1,"serial":99};e.ai_step(1)
 expect(e.pending.is_empty(),"passive opponent automatically acknowledges shown cards")
 fresh_mode(true);e.active=1;e.priority=1;e.phase="end"
 for i in range(9):put(G.VISIT,"hand",1)
 e.cleanup_end();e.ai_step(1)
 expect(e.players[1].hand.size()==7 and e.players[1].grave.size()==2 and e.active==0,"passive forced discard completes and advances to the human turn")
 fresh_mode(true)
 var snapshot=Codec.capture(e);var restored=Duel.new();Codec.restore(restored,snapshot)
 expect(restored.ai_profiles[1]==Duel.PASSIVE_AI,"saved game retains passive opponent behavior")
 var agent=preload("res://scripts/ai/local_experiment.gd").new();agent.enabled=true;e.active=1;e.priority=1;put(G.VISIT,"palette",1);put(G.VISIT,"hand",1)
 expect(agent.step(e).get("passive",false) and e.stack.is_empty() and e.priority==0,"experiment adapter cannot override passive opponent")
 fresh_mode();e.active=1;e.priority=1;put(G.VISIT,"palette",1);put(G.VISIT,"hand",1);e.ai_step(1)
 expect(e.ai_profiles[1]!=Duel.PASSIVE_AI and not e.stack.is_empty(),"a normal start resets passive behavior and ordinary AI still casts")

func run():
 fresh_mode();check_definitions();check_leader();check_discovery();check_budget_guarantee();check_visit_zero_budget();check_visit_high_budget();check_explore_seven_budget();check_stacked_weights();check_visit_leader_preference();check_random_preferences();check_exact_budget_preferences();check_club_preferences();check_adjusted_card_weights();check_variable_cost_preferences();check_series();check_passive_ai()
 print("GENSOKYO EXPLORATION: %d checks; %d failures" % [checks,failures.size()])
 quit(0 if failures.is_empty() else 1)
