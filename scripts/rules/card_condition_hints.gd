extends RefCounted
## Read-only hints for the card's extra condition, independent of action legality.
static func caption(e,c: Dictionary) -> String:
 if c.is_empty() or c.get("network_hidden",false) or not e.cards.has(c.card_id):return ""
 var info=e.cards[c.card_id];var p=e.players[c.owner];var C=e.Cat
 if C.has(e,c,"character-fdf-105") and e.Extra.cost_value(e,p.leader)>=5:return "额外条件满足：套牌自机颜色值至少 5，减费 2"
 if C.has(e,c,"spell-ucs-050") and p.grave.size()>=10:return "额外条件满足：墓地至少 10 张，额外抓 2 张"
 if C.has(e,c,"spell-fdn-009") and p.grave.size()>=4:return "额外条件满足：墓地至少 4 张，可以使用"
 if e.Pack.has(info,"reimu_leader"):
  var self_enabled=e.has_leader_ability(c)
  # A non-leader Reimu in hand can gain this ability on entry from a shrine
  # or the hair ornament's current-turn grant; ordinary copies cannot.
  if c.zone in ["hand","deck","exile","stack"]:
   self_enabled=self_enabled or p.get("all_self_turn",-1)==e.turn or p.field.any(func(u):return e.DB.has_ability(e.cards[u.card_id],"grant_leader_abilities"))
  if self_enabled and p.palette.filter(func(u):return e.cards[u.card_id].requires_character=="博丽灵梦").size()>=3:return "额外条件满足：自机能力有效，颜色盘至少 3 张灵梦角色符卡，获得疾行"
 if C.has(e,c,"character-fdf-100") and e.players[1-c.owner].deck.size()<=20:return "额外条件满足：对手牌库至多 20 张，结束阶段放置 -1/-1"
 if C.enabled(e,c,"character-fdn-004:self") and p.life<=10:return "额外条件满足：自机能力有效且生命至多 10，无视颜色约束并减费 2"
 var lines=[]
 if info.kind in ["单位","自机"] and C.race(e,c,"妖精") and c.zone in ["hand","leader","deck","exile","stack"]:
  if p.get("fairy_enter_turn",-1)!=e.turn and not C.with_key(e,c.owner,"spell-lof-006").is_empty():lines.append("额外条件满足：妖精叠奏曲，本回合首个进场妖精获得疾行与加成")
  if info.kind=="自机" and p.get("next_fairy_leader",-1)==e.turn:lines.append("额外条件满足：妖精公主，本回合下一张妖精自机可免费使用并获得疾行")
 return "\n".join(lines)

static func active(e,c: Dictionary) -> bool:return not caption(e,c).is_empty()

static func curse_count(e,who: int) -> int:return int(e.players[1-who].get("etb_curse",0))
static func curse_caption(e,who: int) -> String:
 var count=curse_count(e,who)
 return "八云紫诅咒：每有一个单位进入战场，你失去 %d 点生命（本局持续）" % (count*2) if count>0 else ""
