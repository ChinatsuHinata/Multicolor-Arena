extends RefCounted

const UNRESTRICTED="unrestricted"
const OFFICIAL="official"
const OFFICIAL_SPX="official_spx"
const TEST="test"
const IDS=[UNRESTRICTED,OFFICIAL,OFFICIAL_SPX,TEST]
const LABELS=["无限制","官限","官限有限定卡","测试卡组"]
const OFFICIAL_TWO=["character-ucs-038","104","item-fdf-096"]

static func main_limit(rule_set: String) -> int:
 return 70 if rule_set==TEST else 50

static func label_for(rule_set: String) -> String:
 var index=IDS.find(rule_set)
 return LABELS[index] if index>=0 else "未知规则集"

static func allowed(id: String,info: Dictionary,rule_set: String) -> bool:
 if not info.get("constructible",false) or info.get("token",false):return false
 if rule_set==TEST:return true
 return rule_set!=OFFICIAL or not id in ["new-spx-001","new-spx-002","new-spx-003","new-spx-004","new-spx-005","new-spx-006","new-spx-007"]

static func limit(id: String,info: Dictionary,rule_set: String) -> int:
 if not allowed(id,info,rule_set):return 0
 if rule_set==TEST:return -1
 var keywords=info.get("keywords",[])
 if "终言" in keywords:return 1
 if "限制级" in keywords or "限制级符卡" in keywords:return 2
 if rule_set in [OFFICIAL,OFFICIAL_SPX] and id in OFFICIAL_TWO:return 2
 if info.get("unlimited",false):return -1
 return 4

static func name_key(id: String,cards: Dictionary) -> String:
 var canonical=str(cards[id].get("canonical_id",id))
 return str(cards[canonical].name) if cards.has(canonical) else str(cards[id].name)

static func copies(deck: Dictionary,id: String,cards: Dictionary) -> int:
 var key=name_key(id,cards)
 var count=0
 for other in deck.get("main",[])+deck.get("side",[]):
  if cards.has(other) and name_key(other,cards)==key:count+=1
 return count

static func remaining(deck: Dictionary,id: String,cards: Dictionary,rule_set: String) -> int:
 if cards.has(deck.get("leader","")) and name_key(id,cards)==name_key(deck.leader,cards):return 0
 var maximum=limit(id,cards[id],rule_set)
 return maximum if maximum<0 else maxi(0,maximum-copies(deck,id,cards))
