@tool
extends RefCounted
## Shipped challenge data, independent of portable/local deck files.
const MAIN=[["soi_unit_086",2],["character-fdn-048",2],["character-fdn-068",4],["character-fdn-014",4],["23",2],["32",3],["18",2],["character-fdf-065",2],["129",4],["94",1],["spell-fdf-038",3],["109",4],["143",4],["spell-fdf-035",2],["spell-ucs-052",2],["spell-fdf-037",4],["spell-fdn-008",1],["169",4]]

static func deck() -> Dictionary:
 var cards=[]
 for item in MAIN:
  for i in range(item[1]):cards.append(item[0])
 return {"id":"builtin_remilia_challenge","name":"蕾米速攻（AI）","leader":"74","main":cards,"side":[],"rule_set":"official","ai_profile":"remilia_aggro","art_overrides":{"169":"tts_154400","74":"tts_149900"}}
