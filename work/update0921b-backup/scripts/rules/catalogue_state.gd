extends RefCounted
## Continuous rules, permissions and costs for the reviewed catalogue.
static func stat_adjust(e,c,k):
 if c.zone!="field":return 0
 var C=e.Cat;var who=c.owner;var n=int(c.get("madness",0))
 if C.has(e,c,"character-fdn-013") and k in ["power","spirit"]:n+=e.units(who).filter(func(u):return u.uid!=c.uid and C.race(e,u,"妖精")).size()
 if C.has(e,c,"character-fdf-100") and k=="spirit":n+=e.players[1-who].grave.filter(func(u):return e.cards[u.card_id].kind=="符卡").size()
 if C.character(e,c,"火焰猫燐"):n+=e.players[who].grave.filter(func(u):return C.has(e,u,"spell-fdf-006")).size()
 for u in e.players[who].field:
  if C.has(e,u,"token-fdn-082") and C.race(e,c,"天狗") and (k=="spirit" or k=="health" and u.get("news_health",false)):n+=1
  if C.enabled(e,u,"character-fdf-117:self") and e.Extra.keyword(e,c,"威吓"):n+=1
 return n
static func keyword(e,c,k):
 var C=e.Cat;var who=c.owner
 if k=="不占战场格":
  if c.get("token",false) and not C.with_key(e,who,"character-fdf-104").is_empty():return true
  if C.race(e,c,"妖精") and C.has(e,e.players[who].leader,"character-fdn-007:self"):return true
  if C.character(e,c,"半灵") and not C.with_key(e,who,"spell-fdn-012").is_empty():return true
 if c.zone!="field":return false
 if k=="不会被消灭":return e.players[who].get("indestructible",-1)==e.turn or e.players[who].get("dolls_indestructible",-1)==e.turn and (C.race(e,c,"人偶") or C.character(e,c,"爱丽丝"))
 if k=="追击" and (C.race(e,c,"神") or C.character(e,c,"御柱")) and not C.with_key(e,who,"spell-ucs-033").is_empty():return true
 if k=="不能被阻挡" and C.enabled(e,c,"character-fdn-026:self"):return true
 if k=="英勇" and C.enabled(e,c,"character-ucs-061:self"):return true
 if k=="退治" and C.enabled(e,c,"character-fdf-041:self"):return true
 if k=="高速移动" and C.enabled(e,c,"character-fdn-036:self"):return true
 return false
static func grant_self(e,c):
 var C=e.Cat;var who=c.owner
 if e.players.is_empty():return false
 if c.get("inherited_self",false):return true
 if e.players[who].get("all_self_turn",-1)==e.turn and (c.zone=="leader" or c.zone=="field" and e.cards[c.card_id].kind=="自机"):return true
 if c.zone=="field" and e.cards[c.card_id].kind=="自机" and (C.character(e,c,"古明地觉") or C.character(e,c,"古明地恋")):
  return e.units(who).any(func(u):return u.uid!=c.uid and C.has(e,u,"character-fdn-026:self") and (u.get("leader",false) or u.get("leader_counters",0)>0 or e.players[who].field.any(func(f):return e.DB.has_ability(e.cards[f.card_id],"grant_leader_abilities"))))
 return false
static func permission(e,c,who):
 var C=e.Cat;var p=e.players[who]
 if c.zone=="exile" and c.get("catalogue_access",{}).get("owner",-1)==who:return true
 if c.zone=="exile" and p.get("exile_free",{}).get("turn",-1)==e.turn and p.exile_free.remaining>0:return true
 if c.owner!=who:return false
 if c.zone=="grave" and C.has(e,c,"spell-fdf-012"):return true
 if c.zone=="palette":return p.get("palette_access",-1)==e.turn or C.role(e,c,"魂魄妖梦") and p.get("youmu_palette_turn",-1)!=e.turn and e.active==who and not C.with_key(e,who,"character-fdf-102:self").is_empty()
 if c.zone=="deck" and not p.deck.is_empty() and p.deck[0].uid==c.uid:
  for u in e.units(who):
   if C.has(e,u,"character-ucs-068") or C.has(e,u,"character-fdn-071"):
    if e.is_unit(c) or C.role(e,c,"摩多罗"):return true
 return false
static func bypass(e,c,who):
 var C=e.Cat;var p=e.players[who]
 if c.zone=="exile" and p.get("exile_free",{}).get("turn",-1)==e.turn and p.exile_free.remaining>0:return true
 if C.race(e,c,"神") and p.get("god_bypass",-1)==e.turn:return true
 if C.enabled(e,c,"character-fdn-004:self") and p.life<=10:return true
 for u in e.units(who)+[c]:
  if (C.enabled(e,u,"character-ucs-068:self") or C.enabled(e,u,"character-fdn-071:self")) and (u.uid==c.uid or c.leader):return true
 return false
static func role_present(e,c,who):
 var C=e.Cat;var required=e.cards[c.card_id].requires_character
 if C.normalized(required).contains("小野冢小町") and e.players[who].grave.any(func(u):return C.has(e,u,"character-fdf-029")):return true
 if required.contains("铃仙") and not C.with_key(e,who,"spell-fdn-032").is_empty() and not e.units(who).is_empty():return true
 if C.has(e,c,"spell-fdn-023") and e.players[who].grave.any(func(u):return C.character(e,u,"少名针妙丸") and e.Extra.cost_value(e,u)==3):return true
 if c.get("catalogue_access",{}).get("support",false) and e.players[who].leader.zone=="leader" and C.role(e,c,e.cards[e.players[who].leader.card_id].character):return true
 return false
static func free_cast(e,c,who):
 if e.paid_cast_uid==c.uid:return false
 var C=e.Cat;var p=e.players[who]
 if c.zone=="exile" and p.get("exile_free",{}).get("turn",-1)==e.turn and p.exile_free.remaining>0:return true
 if c.zone=="palette" and C.role(e,c,"魂魄妖梦") and p.get("youmu_palette_turn",-1)!=e.turn and e.active==who and not C.with_key(e,who,"character-fdf-102:self").is_empty():return true
 if e.is_unit(c) and p.get("next_free_unit",-1)==e.turn:return true
 if C.has(e,c,"spell-fdf-088") and e.units(who).size()>=5:return true
 if C.has(e,c,"spell-fdf-005") and e.units(1-who).size()>e.units(who).size():return true
 return p.get("next_fairy_leader",-1)==e.turn and e.cards[c.card_id].kind=="自机" and C.race(e,c,"妖精")
static func discount(e,who,cost,n):
 var options=[cost.duplicate()]
 for i in range(n):
  var next=[]
  for candidate in options:
   for color in candidate:
    if candidate[color]>0:
     var copy=candidate.duplicate();copy[color]-=1
     if copy not in next:next.append(copy)
  if next.is_empty():break
  options=next
 var best=options[0];var score=999999
 for choice in options:
  var payment=e.payment(who,choice)
  if payment.ways>0 and payment.score<score:best=choice;score=payment.score
 return best
static func cost(e,c,who,base,target):
 var C=e.Cat;var p=e.players[who];var result=base.duplicate();var n=0
 if e.Roster.forced(e,c,who) and not e.forced_cast.get("cost",{}).is_empty():result=e.forced_cast.cost.duplicate()
 if free_cast(e,c,who):result={}
 if C.role(e,c):
  if result.get("黑",0)>0:result["黑"]=maxi(0,result["黑"]-C.with_key(e,who,"field-fdf-089").size())
  if C.role(e,c,"八云紫"):n+=2*p.palette.filter(func(u):return C.has(e,u,"spell-fdf-014")).size()
 if C.enabled(e,c,"character-fdn-004:self") and p.life<=10:n+=2
 if C.has(e,c,"character-fdf-105") and e.Extra.cost_value(e,p.leader)>=5:n+=2
 if C.has(e,c,"spell-fdf-010"):n+=(e.players[0].exile+e.players[1].exile).filter(func(u):return u.has("devour_owner")).size()
 n+=int(c.get("catalogue_access",{}).get("discount",0))
 if p.get("maid_discount",{}).get("turn",-1)==e.turn and (C.role(e,c) or C.race(e,c,"吸血鬼")):
  var color=p.maid_discount.color;result[color]=maxi(0,int(result.get(color,0))-1)
 result=discount(e,who,result,n)
 if C.has(e,c,"spell-fdf-082") and target.has("ignore_color"):result.erase(target.ignore_color)
 if C.has(e,c,"spell-fdf-053"):result["绿"]=maxi(0,int(result.get("绿",0))-int(target.get("counter_payment",0)))
 if C.has(e,c,"spell-fdf-030") and target.get("pitch",false):result={}
 if C.has(e,c,"character-fdf-046") and target.get("extra_green",false):result["绿"]=int(result.get("绿",0))+1
 var tax=C.with_key(e,1-who,"spell-ucs-031").size()
 if tax>0:result["红/蓝/绿/黄/黑"]=int(result.get("红/蓝/绿/黄/黑",0))+tax
 return result
static func cast_error(e,c,who):
 var C=e.Cat;var p=e.players[who]
 if p.get("night_lock",-1)==e.turn:return "本回合不能使用牌或启动能力"
 var lock=p.get("type_lock",{})
 if lock.get("turn",-1)==e.turn and (e.cards[c.card_id].kind==lock.kind or lock.kind=="单位" and e.is_unit(c)):return "本回合不能使用该类别的牌"
 if C.has(e,c,"spell-fdn-022") and (e.phase!="prepare" or e.active==who):return "只能在对手准备阶段使用"
 return ""
static func protected(e,t,who,spell):
 var C=e.Cat
 if t.has("player"):return not C.with_key(e,-1,"character-ucs-046").is_empty()
 var c=e.find_card(t.get("uid",-1))
 if c.is_empty() or c.zone!="field":return false
 if C.race(e,c,"神") and c.owner!=who and not C.with_key(e,c.owner,"field-fdf-107").is_empty() and e.units(c.owner).filter(func(u):return not C.race(e,u,"神")).size()>=3:return true
 return spell and e.is_unit(c) and not C.with_key(e,c.owner,"character-ucs-061").is_empty() and e.get("catalogue_target_fast")
static func activation_locked(e,c):
 if e.players[c.owner].get("night_lock",-1)==e.turn:return true
 return e.Cat.field(e).any(func(u):return e.Cat.has(e,u,"character-fdf-101") and u.get("locked_name","")==e.cards[c.card_id].name)
static func can_combat(e,c):
 var C=e.Cat
 if C.has(e,c,"character-fdn-045") and not e.units(c.owner).any(func(u):return C.character(e,u,"爱丽丝")):return false
 return C.with_key(e,-1,"spell-fdf-044").is_empty() or C.counter_total(e,[c])>0
static func on_draw(e,who):
 var p=e.players[who];var map=p.get("drawn",{});map[str(e.turn)]=int(map.get(str(e.turn),0))+1;p.drawn=map
 for c in e.Cat.with_key(e,1-who,"spell-fdf-018"):e.Cat.events(e,c,"spell-fdf-018")
static func on_gain(e,who,n):
 var C=e.Cat;var p=e.players[who];var map=p.get("life_gained",{});map[str(e.turn)]=int(map.get(str(e.turn),0))+n;p.life_gained=map
 for c in C.with_key(e,who,"character-fdf-091"):
  if e.usage_count(c.uid,"gain_recover")==0:e.use_once(c.uid,"gain_recover");C.events(e,c,"character-fdf-091",true)
static func on_damage(e,t,n,remaining):
 var C=e.Cat;var context=e.damage_context;var source=context.get("source",{})
 if source.is_empty() or n<=0:return
 var who=source.owner
 if C.unit(e,t) and not context.get("combat",false):
  var c=e.find_card(t.uid);c.noncombat_damage_turn=e.turn
  if e.cards[source.card_id].kind=="自机" and e.players[who].get("mage_flare",-1)==e.turn and n>maxi(0,remaining):C.damage(e,{"player":c.owner},n-maxi(0,remaining))
 if C.unit(e,t) and source.uid!=t.uid and C.character(e,source,"丰聪耳神子"):
  for c in C.with_key(e,who,"spell-fdf-001"):C.events(e,c,"cat:god_damage",false,{"amount":n})
 if not t.has("player") or t.player==who or not context.get("combat",false):return
 if C.has(e,source,"character-ucs-073"):C.events(e,source,"character-ucs-073")
 if C.has(e,source,"character-fdn-035"):C.mill(e,t.player,n)
 if C.character(e,source,"古明地觉") or C.character(e,source,"古明地恋"):
  for c in C.with_key(e,who,"character-fdn-026"):C.events(e,c,"character-fdn-026",false,{"player":t.player})
 if C.character(e,source,"十六夜咲夜"):
  for c in C.with_key(e,who,"character-fdf-041:self"):C.events(e,c,"character-fdf-041:self",true)
static func on_palette(e,c):
 var C=e.Cat
 if e.active==c.owner and C.has(e,c,"spell-fdf-031"):C.events(e,c,"cat:flower_cast",true)
 if e.phase=="main" and e.active==c.owner:
  for u in C.with_key(e,c.owner,"character-ucs-044"):C.events(e,u,"character-ucs-044",true)
static func on_coin(e,who,heads):
 if heads:return
 for c in e.players[who].grave:
  if e.Cat.has(e,c,"spell-fdf-022"):e.Cat.events(e,c,"cat:unconscious_return",true)
static func state_checks(e):
 var C=e.Cat
 for c in (e.units(0)+e.units(1)).duplicate():
  if c.get("reisen_illusion",false) and not e.units(c.owner).any(func(u):return "铃仙" in e.cards[u.card_id].name):e.move_to(c,"exile")
  if c.has("rank_target") and e.players[c.rank_target.owner].turns>=c.rank_target.turns:c.erase("rank_target")
 for who in range(2):
  if not C.with_key(e,who,"spell-fdn-002").is_empty() and not e.units(who).is_empty():e.players[who].life=maxi(1,e.players[who].life)
 sync_fairies(e)
static func sync_fairies(e):
 for who in range(e.players.size()):
  for c in e.units(who):
   var base=c.get("habitat_base",c.card_id)
   if not e.Roster.has(e.cards[base],"character-fdn-007"):continue
   var info=e.cards[base].duplicate(true);info.copy_source_id=base
   for u in e.units(who):
    if u.uid==c.uid or not e.Cat.race(e,u,"妖精"):continue
    var other=e.cards[u.get("habitat_base",u.card_id)]
    for a in other.abilities:
     if a not in info.abilities:info.abilities.append(a.duplicate(true))
    for k in other.keywords:
     if k not in info.keywords:info.keywords.append(k)
   var id="catalogue_habitat_"+str(c.uid);e.cards[id]=info;c.card_id=id;c.habitat_base=base;c.inherited_self=true

