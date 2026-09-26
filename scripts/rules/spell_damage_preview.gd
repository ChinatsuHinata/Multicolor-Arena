extends RefCounted
## Display-only estimates: payment and spell effects are never committed here.
static func caption(e,c: Dictionary,draft: Dictionary={},keystones: Dictionary={}) -> String:
 if c.is_empty() or c.get("network_hidden",false):return ""
 var info=e.cards[c.card_id]
 var noon=e.Cat.has(e,c,"spell-fdn-029")
 var royal=e.Cat.has(e,c,"spell-ucs-041")
 var orbs=e.Pack.has(info,"dream_orbs")
 var lake=e.Roster.has(info,"lake_mill")
 var unknown=e.Extra.has(info,"draw_hand_damage")
 var heaven=e.Cat.has(e,c,"spell-fdf-086")
 var cherry=e.Cat.has(e,c,"spell-fdf-048")
 var moon=e.Pack.has(info,"shoot_moon")
 if not (noon or royal or orbs or lake or unknown or heaven or cherry or moon):return ""
 var who=c.owner;var stack_index=-1;var target={}
 for i in range(e.stack.size()):
  var entry=e.stack[i]
  if entry.kind=="card" and entry.card.uid==c.uid:
   if entry.get("rewritten_fairy",false):return ""
   who=entry.owner;stack_index=i;target=entry.target;break
 var choosing=draft.get("uid",0)==c.uid and draft.get("action","cast")=="cast" and draft.get("mode","") in ["target","payment"] and stack_index<0
 if choosing:target=draft.get("target",{})
 var p=e.players[who]
 var leaves_hand=p.hand.any(func(u):return u.uid==c.uid) and stack_index<0
 var leaves_palette=p.palette.any(func(u):return u.uid==c.uid) and stack_index<0
 if moon:
  var count=p.grave.filter(func(u):return e.Pack.name_is(e.cards[u.card_id],info.name) and (u.uid!=c.uid or c.zone!="grave")).size()
  var requested=count+1;var available=mini(requested,p.deck.size())
  return "预计抽牌：%d 张\n墓地射月：%d 张 + 1\n%s" % [available,count,"牌库剩余 %d 张，需抓 %d 张，无法完成全部抓牌" % [p.deck.size(),requested] if available<requested else "以结算时墓地数量为准"]
 if noon:
  var upright=p.palette.filter(func(u):return not u.tapped)
  var plan=[];var note="以结算时数量为准"
  if stack_index<0:
   if choosing:
    plan=draft.get("plan",[]);note="按当前支付方案"
   else:
    # The normal solver prefers field items (weight 8) over palette cards (10+).
    var payment=e.payment(who,e.cast_cost(who,c))
    if payment.ways>0:plan=payment.plan;note="模拟支付费用后（优先道具）"
    else:note="费用不足，未模拟支付"
  var reserved=plan.map(func(r):return r.uid)
  var count=upright.filter(func(u):return u.uid not in reserved and (not leaves_palette or u.uid!=c.uid)).size()
  if leaves_palette:note+="；此牌移出颜色盘"
  return "预计伤害：%d 点\n未横置颜色盘：%d 张\n%s，剩余 %d 张" % [count,upright.size(),note,count]
 if orbs:
  var count=(e.players[0].palette+e.players[1].palette).filter(func(u):return e.Pack.role(e.cards[u.card_id]) and (not leaves_palette or u.uid!=c.uid)).size()
  return "预计伤害：%d 点\n双方颜色盘角色符卡：%d 张 × 2\n以结算时数量为准" % [count*2,count]
 if lake:
  var count=p.grave.size()
  var self_damage=count+(0 if p.deck.is_empty() else 1)
  var mill_player=-1
  for part in target.get("parts",[]):
   if part.has("player"):mill_player=int(part.player);break
  var amount=str(count) if count==self_damage else "%d～%d" % [count,self_damage]
  if mill_player>=0:amount=str(self_damage if mill_player==who else count)
  return "预计伤害：%s 点\n磨牌对手：%d 点\n磨牌自己：%d 点\n你的墓地：%d 张%s" % [amount,count,self_damage,count,"；牌库为空，无法磨牌" if p.deck.is_empty() else "；含自己磨入的 1 张"]
 var can_draw=not p.deck.is_empty()
 if unknown:
  var count=p.hand.size()-(1 if leaves_hand else 0)+(1 if can_draw else 0)
  return "预计伤害：%d 点\n当前手牌：%d 张\n%s%s" % [count,p.hand.size(),"使用此牌 −1 张；" if leaves_hand else "", "先抓牌 +1 张" if can_draw else "牌库为空，无法抓牌"]
 if cherry:
  var count=p.hand.size()-(1 if leaves_hand else 0)
  var note="默认双方移除全部手牌"
  if stack_index>=0:count=int(c.get("exiled_hand",0));note="按已支付的移除数量；对方默认移除全部手牌"
  elif choosing:
   if target.get("picks",[]).size()>1:count=target.picks[1].size();note="按当前选择；对方默认移除全部手牌"
   elif draft.has("preview_exiled_hand"):count=int(draft.preview_exiled_hand);note="按当前选择；对方默认移除全部手牌"
  var prevent=e.players[1-who].hand.size()
  return "预计伤害：%d 点\n己方移除：%d 张 × 3 = %d 点\n对方移除：%d 张 × 2 = 防止 %d 点\n%s%s" % [maxi(0,count*3-prevent*2),count,count*3,prevent,prevent*2,note,"（不含此符卡）" if leaves_hand else ""]
 if heaven:
  var units=e.units(who).size()
  var barriers=p.field.filter(func(u):return e.cards[u.card_id].kind=="结界").size()
  var bonus=0
  if stack_index<0:
   if not e.Pack.trigger_locked(e):bonus=p.field.filter(func(u):return e.Cat.has(e,u,"spell-fdn-010")).size()*e.Extra.cost_value(e,c)
  else:
   # Only unresolved triggers above this spell add future keystones. Resolved
   # keystones already appear in the field count; a copy does not trigger on cast.
   bonus=int(keystones.get(c.uid,pending_keystones(e,stack_index,who)))
  return "预计伤害：%d 点（每位对手及其每个单位）\n己方单位：%d；结界：%d\n%s" % [units+barriers+bonus,units,barriers,"幼心乐章要石：+%d（待结算）" % bonus if bonus>0 else "以结算时数量为准"]
 var drawn=int(p.get("drawn",{}).get(str(e.turn),0))
 return "预计伤害：%d 点\n本回合已抓：%d 张\n%s" % [drawn+(1 if can_draw else 0),drawn,"含此牌先抓的 1 张" if can_draw else "牌库为空，无法抓牌"]

static func pending_keystones(e,stack_index: int,who: int) -> int:
 var count=0
 for trigger in e.stack.slice(stack_index+1)+e.triggers:
  if trigger.get("effect","")=="spell-fdn-010" and trigger.owner==who:count+=int(trigger.get("data",{}).get("value",0))
 return count

static func public_keystone_estimates(e) -> Dictionary:
 # Trigger-order pools are private. Publish only the future token count needed
 # by a visible Heaven spell, so both seats and spectators get the same estimate.
 var result={}
 for i in range(e.stack.size()):
  var entry=e.stack[i]
  if entry.kind=="card" and e.Cat.has(e,entry.card,"spell-fdf-086"):result[entry.card.uid]=pending_keystones(e,i,entry.owner)
 return result
