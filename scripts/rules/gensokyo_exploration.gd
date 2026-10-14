extends RefCounted
## Fixed entertainment decks and authoritative, seeded three-card discoveries.
const LEADER="exploration-leader"
const VISIT="exploration-merry-visit"
const EXPLORE="exploration-renko-explore"
const TRAVEL="exploration-club-travel-bag"
const CLUB="exploration-club-activity"
const SPELLS=[VISIT,EXPLORE,TRAVEL,CLUB]
const MODE_NAME="探索幻想乡"
const RANDOM_MODE_NAME="探索幻想乡全随机版"
const RANDOM_LEADER="exploration-random-leader"
const RANDOM_SPELLS=["exploration-random-merry-visit","exploration-random-renko-explore","exploration-random-club-travel-bag","exploration-random-club-activity"]
const MODES=["exploration","exploration_random"]
const MODE_NAMES=[MODE_NAME,RANDOM_MODE_NAME]
const ANY_SELF="exploration:any_leader:self"
const VISIT_LEADER_WEIGHT=2.0
const EXACT_BUDGET_WEIGHT=4.0
const CARD_WEIGHT_MULTIPLIERS={
 "spell-fdf-027":0.1,"spell-fdf-076":0.1,"153":0.1,"spell-fdn-046":0.1,
 "spell-fdf-123":0.5,"new-spx-004":0.2,"spell-fdf-009":0.2
}
const TRAVEL_ART="res://recourse/数据库/探索幻想乡/club-travel-bag-dark.png"
const CLUB_ART="res://recourse/数据库/探索幻想乡/club-activity-blue.png"

static func binding(effect: String,caption: String) -> Dictionary:
 return {"实现":"extension","名称":caption,"参数":{"效果":effect}}

static func register(cards: Dictionary):
 if not cards.has("new-eto-003"):return
 var leader=cards["new-eto-003"].duplicate(true)
 leader.colors=["红","蓝","绿","黄","黑"];leader.color=" / ".join(leader.colors)
 leader.cost={"红":1,"蓝":1,"绿":1,"黄":1,"黑":1}
 leader.canonical_id=LEADER
 leader.constructible=false;leader.exploration_only=true;leader.souprce="娱乐模式：探索幻想乡"
 leader.abilities=[]
 leader.abilities.append(binding("exploration:color_bypass","该牌无需满足战场颜色约束即可使用。"))
 leader.abilities.append(binding(ANY_SELF,"自机能力：该牌在任何区域都视为任意自机；该牌在战场上时，你的「梅莉的拜访」更容易抽到自机。" ))
 leader.rules_text="\n".join(leader.abilities.map(func(a):return a.get("名称","")))
 leader.description=leader.rules_text;cards[LEADER]=leader
 var captions=[
  "从三张随机单位牌中选择一张加入手牌。至少生成一张符合剩余或下回合颜色值的单位。",
  "从三张随机非角色符卡中选择一张加入手牌，这些符卡根据剩余的颜色值生成，至少生成一张符合剩余颜色值的符卡；高速时机使用时，更容易生成高速符卡。",
  "从三张随机道具与结界牌中选择一张加入手牌，这些牌根据剩余的颜☁色值生成，至少生成一张符合剩余颜色值的牌。",
  "从三张随机角色符卡中选择一张加入手牌，这些符卡根据剩余的颜色值生成，剩余颜色值越高，越容易生成高费符卡。"
 ]
 var names=["梅莉的拜访","莲子的探索","俱乐部的旅行包","秘封俱乐部活动"]
 var colors=["黄","黑","蓝","蓝"]
 var art=["character-ucs-021","character-ucs-020","item-ucs-012","spell-ucs-022"]
 for i in range(SPELLS.size()):
  var info=cards["spell-ucs-022"].duplicate(true)
  info.name=names[i];info.colors=[colors[i]];info.color=colors[i];info.cost={colors[i]:1}
  info.image=cards[art[i]].image;info.file=cards[art[i]].file;info.landscape=cards[art[i]].landscape
  if SPELLS[i]==TRAVEL:info.image=TRAVEL_ART
  elif SPELLS[i]==CLUB:info.image=CLUB_ART
  info.file=info.image.get_file()
  info.fast=i==1;info.constructible=false;info.canonical_id=SPELLS[i];info.exploration_only=true;info.source="娱乐模式：探索幻想乡"
  info.rules_text=captions[i];info.abilities=[binding("exploration:discover",captions[i])];info.keywords=[]
  info.rules_text+="\n极彩。该牌在颜色盘或战场上视作任意颜色。"
  info.keywords=["极彩"]
  info.abilities.append({"实现":"precon","名称":"极彩。该牌在颜色盘或战场上视作任意颜色。","参数":{"效果":"all_colors"}})
  info.description=info.rules_text;cards[SPELLS[i]]=info
 var random_leader=leader.duplicate(true)
 random_leader.canonical_id=RANDOM_LEADER;random_leader.source="娱乐模式："+RANDOM_MODE_NAME
 random_leader.abilities[1]=binding(ANY_SELF,"自机能力：该牌在任何区域都视为任意自机。")
 random_leader.rules_text="\n".join(random_leader.abilities.map(func(a):return a.get("名称","")))
 random_leader.description=random_leader.rules_text;cards[RANDOM_LEADER]=random_leader
 var pools=["单位与自机牌","非角色符卡","道具与结界牌","角色符卡"]
 for i in range(RANDOM_SPELLS.size()):
  var info=cards[SPELLS[i]].duplicate(true)
  info.canonical_id=RANDOM_SPELLS[i];info.source="娱乐模式："+RANDOM_MODE_NAME
  var caption="从对应卡池等概率随机抽取三张不同名的%s，选择一张加入手牌。" % pools[i]
  info.abilities[0]=binding("exploration:discover",caption)
  info.rules_text=caption+"\n极彩。该牌在颜色盘或战场上视作任意颜色。"
  info.description=info.rules_text;cards[RANDOM_SPELLS[i]]=info

static func deck(random: bool=false) -> Dictionary:
 var spells=RANDOM_SPELLS if random else SPELLS
 var main=[]
 for i in range(15):main.append(spells[0])
 for i in range(15):main.append(spells[1])
 for i in range(8):main.append(spells[2])
 for i in range(12):main.append(spells[3])
 return {"id":"gensokyo-exploration-random" if random else "gensokyo-exploration","name":RANDOM_MODE_NAME if random else MODE_NAME,"leader":RANDOM_LEADER if random else LEADER,"main":main,"side":[],"rule_set":"unrestricted","art_overrides":{}}

static func fixed_deck(d: Dictionary,random: bool=false) -> bool:
 var expected=deck(random)
 if d.get("leader","")!=expected.leader or not d.get("main") is Array or d.get("side",[])!=[]:return false
 var actual=d.main.duplicate();var wanted=expected.main.duplicate();actual.sort();wanted.sort()
 return actual==wanted and d.get("art_overrides",{}).is_empty()

static func wildcard(e,c: Dictionary,required: String) -> bool:
 if c.is_empty() or required.is_empty() or not e.cards.get(c.card_id,{}).get("abilities",[]).any(func(a):return a.get("参数",{}).get("效果","")==ANY_SELF):return false
 var p=e.players[c.owner]
 var enabled=c.get("leader",false) or c.get("leader_counters",0)>0 or c.get("inherited_self",false)
 if c.zone in ["field","leader"] and p.get("all_self_turn",-1)==e.turn:enabled=true
 if c.zone=="field" and p.field.any(func(u):return e.DB.has_ability(e.cards[u.card_id],"grant_leader_abilities")):enabled=true
 if not enabled:return false
 return e.cards.values().any(func(info):return info.kind=="自机" and not info.get("exploration_only",false) and e.Roster.character_matches(info.get("character",""),required))

static func color_constraint_met(e,who: int,info: Dictionary) -> bool:
 var provided=[]
 for permanent in e.players[who].field:
  if e.cards[permanent.card_id].kind=="符卡":continue
  for color in e.Pack.colors(e,permanent):
   if color not in provided:provided.append(color)
 var requirements=info.cost.keys() if info.cost.keys().any(func(k):return "/" in k) else info.colors
 return requirements.all(func(requirement):return Array(str(requirement).split("/")).any(func(color):return color in provided))

static func candidates(e,who: int,kind: String) -> Array:
 var random=kind in RANDOM_SPELLS
 if random:kind=SPELLS[RANDOM_SPELLS.find(kind)]
 var pool=[]
 for id in e.cards:
  var info=e.cards[id]
  if info.get("exploration_only",false) or info.get("token",false) or not info.get("constructible",false) or info.get("canonical_id",id)!=id:continue
  if kind==VISIT:
   if info.kind not in ["单位","自机"]:continue
   if not random and info.kind=="自机" and not color_constraint_met(e,who,info):continue
  elif kind==TRAVEL:
   if info.kind not in ["道具","结界"]:continue
  elif info.kind!="符卡" or (info.requires_character.is_empty() if kind==CLUB else not info.requires_character.is_empty()):continue
  pool.append(id)
 return pool

static func budgets(e,who: int) -> Array:
 var remaining=0
 for source in e.source_resources(who):remaining+=source.get("pair",[0]).size()
 # Estimate refreshed resources and the usual palette growth, capped at eight.
 var p=e.players[who]
 var next_turn=p.palette.size()+(1 if p.palette.size()<8 and not p.deck.is_empty() else 0)+(1 if p.potato else 0)
 for c in e.players[who].field:
  if e.DB.has_ability(e.cards[c.card_id],"mana"):next_turn+=1
  elif e.Cat.enabled(e,c,"character-fdf-098"):next_turn+=2
 return [remaining,next_turn]

static func full_budget_payment(e,who: int,id: String,remaining: int) -> bool:
 # Probe the real cost and solver without creating a card or spending sources.
 var probe={"uid":-99999999,"epoch":0,"card_id":id,"owner":who,"original_owner":who,"zone":"hand","leader":false}
 var max_x=0
 if not e.cards[id].get("variable_cost","").is_empty() and not e.Roster.free_cast(e,probe,who) and not (e.debug_enabled and e.debug_free_payment):
  var high=1
  while e.VariableChoice.within_budget(e,probe,who,high,remaining,0):
   max_x=high;high*=2
  while high-max_x>1:
   var middle=(max_x+high)/2
   if e.VariableChoice.within_budget(e,probe,who,middle,remaining,0):max_x=middle
   else:high=middle
 for x in range(max_x,-1,-1):
  for cost in e.cast_cost_options(who,probe,{"x":x}):
   var total=0
   for amount in cost.values():total+=int(amount)
   if total==remaining and e.payment(who,cost).ways>0:return true
 return false

static func weight(info: Dictionary,kind: String,available: Array,fast_window: bool,visit_leader_bonus: bool=false,current_fit: Variant=null) -> float:
 var result=1.0
 var cost=0
 for amount in info.cost.values():cost+=int(amount)
 var remaining=maxi(0,int(available[0]));var variable_weight=1.0
 if kind in [VISIT,EXPLORE,CLUB] and not info.get("variable_cost","").is_empty():
  var x=int(maxi(0,remaining-cost)/maxi(1,int(info.get("variable_multiplier",1))))
  if x>0:
   # Flexible X costs fit the current budget band; each payable X adds 50% weight.
   cost=remaining;variable_weight+=0.5*x
 if kind==CLUB:
  # Each two points away from the current budget halves the cost weight.
  result=pow(2.0,-abs(cost-remaining)/2.0)
  if info.keywords.any(func(keyword):return "终言" in keyword or "限制级" in keyword) or "终言" in info.spell_type or "限制级" in info.spell_type:
   result*=minf(1.0,0.12+0.11*remaining)
 else:
  var limit=maxi(available[0],available[1])
  result=8.0 if cost<=limit else 0.5/float(cost-limit)
  var exact_current=cost==remaining if current_fit==null else bool(current_fit)
  if exact_current or cost==int(available[1]):
   # A payable exact fit remains affordable after cost reductions or taxes.
   result=8.0*EXACT_BUDGET_WEIGHT
  if kind==EXPLORE and fast_window and info.fast:result*=4.0
  if kind==VISIT and visit_leader_bonus and info.kind=="自机":result*=VISIT_LEADER_WEIGHT
 # Per-card tuning stacks with the existing budget, rarity and timing bonuses.
 return result*variable_weight*CARD_WEIGHT_MULTIPLIERS.get(info.get("canonical_id",""),1.0)

static func weighted_pick(e,pool: Array,weights: Dictionary) -> String:
 var total=0.0
 for id in pool:total+=weights[id]
 var roll=e.rng.randf()*total
 for id in pool:
  roll-=weights[id]
  if roll<0.0:return id
 return pool.back()

static func discoveries(e,who: int,kind: String,fast_window: bool=false) -> Array:
 var pool=candidates(e,who,kind);var offered=[]
 if kind in RANDOM_SPELLS:
  # Uniform draws with same-name removal and no other discovery weighting.
  while offered.size()<3 and not pool.is_empty():
   var selected=pool[e.rng.randi_range(0,pool.size()-1)]
   pool=pool.filter(func(id):return e.cards[id].name!=e.cards[selected].name)
   offered.append({"outside_id":selected,"none":true,"mode":e.cards[selected].name})
  return offered
 var available=budgets(e,who)
 var visit_leader_bonus=kind==VISIT and e.players[who].field.any(func(c):return e.Extra.has(e.cards[c.card_id],ANY_SELF) and e.has_leader_ability(c))
 var fixed=[];var variable=[];var weights={}
 var visit_cost_weights={}
 if kind==VISIT and available[0]==6:visit_cost_weights={"5":1.0,"6":1.0}
 elif kind==VISIT and available[0]==7:visit_cost_weights={"5":1.0,"6":3.0,"7":2.0}
 var visit_fixed={};var visit_variable={}
 for id in pool:
  var exact: Variant=null
  if kind!=CLUB:
   exact=full_budget_payment(e,who,id,available[0])
   var guaranteed_fit=exact or (kind==EXPLORE and available[0]==7 and full_budget_payment(e,who,id,6))
   if kind==VISIT and available[0]==0:
    # An empty current budget guarantees the predicted next-turn cost only.
    # Keep the current zero-cost fit for the ordinary discovery weight.
    var predicted_cost=0
    for amount in e.cards[id].cost.values():predicted_cost+=int(amount)
    guaranteed_fit=predicted_cost>0 and predicted_cost==available[1]
   if not visit_cost_weights.is_empty():
    var by_cost=visit_fixed if e.cards[id].get("variable_cost","").is_empty() else visit_variable
    for cost in visit_cost_weights:
     var fits=exact if int(cost)==available[0] else full_budget_payment(e,who,id,int(cost))
     if fits:
      if not by_cost.has(cost):by_cost[cost]=[]
      by_cost[cost].append(id)
   elif guaranteed_fit:
    if e.cards[id].get("variable_cost","").is_empty():fixed.append(id)
    else:variable.append(id)
  weights[id]=weight(e.cards[id],kind,available,fast_window,visit_leader_bonus,exact)
 var guaranteed=fixed if not fixed.is_empty() else variable
 # Pick the cost band first so its probability is independent of card counts
 # and exact-cost/leader bonuses. Fixed cards still take priority over X.
 var visit_by_cost=visit_fixed if not visit_fixed.is_empty() else visit_variable
 while offered.size()<3 and not pool.is_empty():
  var selection_pool=pool
  if offered.is_empty():
   if not visit_by_cost.is_empty():
    var cost=weighted_pick(e,visit_by_cost.keys(),visit_cost_weights)
    selection_pool=visit_by_cost[cost]
   elif not guaranteed.is_empty():selection_pool=guaranteed
  var selected=weighted_pick(e,selection_pool,weights)
  pool=pool.filter(func(id):return e.cards[id].name!=e.cards[selected].name)
  offered.append({"outside_id":selected,"none":true,"mode":e.cards[selected].name})
 return offered

static func spell_options(id: String) -> Variant:
 return [{"none":true}] if id in SPELLS or id in RANDOM_SPELLS else null

static func spell_resolve(e,t: Dictionary) -> bool:
 if t.card.card_id not in SPELLS and t.card.card_id not in RANDOM_SPELLS:return false
 var offered=discoveries(e,t.owner,t.card.card_id,t.get("exploration_fast_window",false))
 if not offered.is_empty():
  e.Roster.continue_choice(e,t,"exploration:take",e.Pack.selection([e.Pack.group(offered,1,1,"选择一张加入手牌")],"exploration:take"))
 e.to_grave(t.card)
 return true

static func resolve_trigger(e,t: Dictionary) -> bool:
 if t.get("effect","")!="exploration:take":return false
 for choice in e.Pack.picked(t.target):
  var c=e.make_card(choice.outside_id,t.owner,"outside")
  e.move_to(c,"hand");e.reveal_card(c)
 return true

static func ai_pick(e,who: int,spec: Dictionary) -> Dictionary:
 var pool=spec.selection[0].pool;var best=pool[0];var best_score=-100000.0
 var available=budgets(e,who)
 for option in pool:
  var info=e.cards[option.outside_id];var cost=0
  for n in info.cost.values():cost+=int(n)
  var score=20.0-abs(cost-maxi(available[0],available[1]))*3.0
  if info.kind in ["单位","自机"]:score+=info.power+info.health+info.spirit
  else:
   var probe={"uid":-99999999,"epoch":0,"card_id":option.outside_id,"owner":who,"original_owner":who,"zone":"hand","leader":false}
   if not e.character_constraint_error(probe,who).is_empty():score-=40.0
   if e.targets_for(option.outside_id,who).is_empty():score-=20.0
  if score>best_score:best_score=score;best=option
 var result=spec.duplicate(true);result.erase("selection");result.picks=[[best]]
 return result
