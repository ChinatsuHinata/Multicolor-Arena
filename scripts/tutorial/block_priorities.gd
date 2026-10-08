extends RefCounted
## Ordered tutorial block presets, resolved against the current combat choice.
const STRATEGIES=["largest","smallest","lethal","all","selected"]
const LABELS={"largest":"选择最大的单位阻挡","smallest":"选择最小的单位阻挡","lethal":"尝试联合阻挡，让攻击单位死亡","all":"所有单位联合阻挡","selected":"制作者选择目标单位阻挡"}
const Preview=preload("res://scripts/rules/remilia_aggro_ai.gd")

static func defaults() -> Array:
 return STRATEGIES.map(func(strategy):return {"strategy":strategy,"enabled":strategy=="largest","cards":[]} if strategy=="selected" else {"strategy":strategy,"enabled":strategy=="largest"})

static func legal_group(e,attacker: Dictionary,group: Array) -> bool:
 return not group.is_empty() and (group.size()>1 or not e.Extra.keyword(e,attacker,"威吓"))

static func ordered(e,legal: Array,largest: bool) -> Array:
 var result=legal.duplicate()
 result.sort_custom(func(a,b):
  var power_a=e.stat(a,"power");var power_b=e.stat(b,"power")
  if power_a!=power_b:return power_a>power_b if largest else power_a<power_b
  var health_a=e.stat(a,"health")-a.damage;var health_b=e.stat(b,"health")-b.damage
  if health_a!=health_b:return health_a>health_b if largest else health_a<health_b
  return legal.find(a)<legal.find(b))
 return result

static func lethal_group(e,attacker: Dictionary,legal: Array) -> Array:
 if legal.size()<2:return []
 var group=ordered(e,legal,true)
 if not Preview.fight(e,attacker,group).attacker_dead:return []
 # Start with every legal blocker, then remove unnecessary smaller units.
 for card in ordered(e,legal,false):
  if group.size()<=2:break
  var reduced=group.duplicate();reduced.erase(card)
  if Preview.fight(e,attacker,reduced).attacker_dead:group=reduced
 return group

static func prepare(adapter,options: Array) -> Dictionary:
 var e=adapter.engine;var legal=e.legal_blockers();var attacker=e.find_card(e.combat.attacker.uid)
 for option in options:
  if not option.get("enabled",true):continue
  var group=[]
  match option.strategy:
   "largest","smallest":
    if not legal.is_empty():group=[ordered(e,legal,option.strategy=="largest")[0]]
   "lethal":group=lethal_group(e,attacker,legal)
   "all":group=legal.duplicate()
   "selected":
    for ref in option.cards:
     var card=adapter.resolve_card(ref)
     if card.is_empty() or card not in legal or card in group:group=[];break
     group.append(card)
  if legal_group(e,attacker,group):return {"available":true,"uids":group.map(func(card):return int(card.uid))}
 # All enabled choices failed: decline unless the real rules require blocking.
 if not legal.is_empty() and e.Cat.has(e,attacker,"character-fdf-090"):return {"available":false,"uids":[]}
 return {"available":true,"uids":[]}
