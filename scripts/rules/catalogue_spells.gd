extends RefCounted
## Each branch is keyed to an Excel edition; common continuations preserve choices.
static func options(e,id,who):
 var C=e.Cat;var units=e.units(0)+e.units(1);var own=e.units(who);var foe=e.units(1-who);var p=e.players[who];var all=e.ability_targets();var rs=C.refs(e,units)
 match id:
  "spell-fdn-017","spell-fdn-022","spell-fdf-009","spell-fdf-048","spell-fdf-008","spell-ucs-054":
   if id=="spell-fdf-048":return e.Pack.selection([e.Pack.group([{"player":1-who}],1,1,"目标对手"),C.group(e,p.hand,0,p.hand.size(),"移除手牌",true)],id)
   return [{"player":1-who}]
  "spell-fdn-009":return C.refs(e,foe.filter(func(c):return e.Extra.cost_value(e,c)<=3)) if p.grave.size()>=4 else []
  "spell-fdf-120":return C.refs(e,units.filter(func(c):return e.Extra.cost_value(e,c)<=3 and e.Pack.colors(e,c).size()==2))
  "spell-fdn-029","spell-ucs-009","spell-ucs-052","spell-fdf-047","spell-fdf-028","spell-fdf-078","spell-fdf-022","spell-fdf-002","spell-fdf-032","spell-ucs-015","spell-fdf-050","spell-fdn-028","spell-rec-054","spell-smm-002","spell-soi-119","spell-rec-056","spell-kmo-003":return rs
  "spell-fdf-043":
   var highest=0
   for c in foe:highest=maxi(highest,e.stat(c,"power"))
   return C.refs(e,foe.filter(func(c):return e.stat(c,"power")==highest))
  "spell-fdf-066":return C.refs(e,units.filter(func(c):return not C.race(e,c,"人类") and not C.race(e,c,"神")))
  "spell-fdf-049","spell-fdf-059","spell-ucs-041","spell-fdf-035","spell-fdf-015":return all if id!="spell-fdf-015" else rs
  "spell-fdf-071":return e.Pack.selection([e.Pack.group(all,0,3,"选择至多三个不同目标")],id)
  "spell-fdf-031":return e.Pack.selection([e.Pack.group(all,1,1,"造成4点伤害"),C.group(e,units,1,1,"重置一个单位")],id)
  "spell-fdn-030":return C.refs(e,C.field(e).filter(func(c):return e.cards[c.card_id].kind in ["道具","结界","单位"]))
  "spell-fdn-031":return C.refs(e,C.field(e).filter(func(c):return e.cards[c.card_id].kind in ["自机","道具"]))
  "spell-fdf-056":return C.refs(e,C.field(e).filter(func(c):return e.Roster.permanent(e,c)))
  "spell-fdf-074":return C.pick(e,C.field(e).filter(func(c):return e.cards[c.card_id].kind in ["道具","结界"] or e.is_unit(c) and e.Extra.cost_value(e,c)>3),0,999,"选择要消灭的永久物",id)
  "spell-fdn-020":return C.refs(e,p.grave.filter(func(c):return e.is_unit(c)))
  "spell-ucs-037":return C.pick(e,p.grave.filter(func(c):return e.cards[c.card_id].kind in ["道具","结界"]),0,3,"选择墓地的道具或结界",id)
  "spell-ucs-004":return C.opponents()
  "spell-fdn-008":return C.refs(e,units.filter(func(c):return C.race(e,c,"吸血鬼")))
  "spell-ucs-050":return C.pick(e,units,0,1,"选择至多一个单位",id)
  "spell-fdf-055":return e.Extra.add_mode(C.refs(e,C.field(e).filter(func(c):return "时符" in e.cards[c.card_id].get("spell_type","") and e.Pack.colors(e,c).size()>1)),"放置2个计时")+e.Extra.add_mode(C.refs(e,C.field(e).filter(func(c):return "时符" in e.cards[c.card_id].get("spell_type","") and e.Pack.colors(e,c).size()>1)),"移除2个计时")
  "spell-fdf-038":return range(4).map(func(n):return {"none":true,"mode":"额外抓 %d 张" % n,"extra":n})
  "spell-fdf-016","spell-fdf-081":return [{"parts":[{"player":0},{"player":1}]}]
  "spell-smm-003","spell-rec-055":
   var out=[]
   for a in units:
    for b in units:
     if a.uid<b.uid and a.owner==b.owner:out.append({"parts":[C.ref(e,a),C.ref(e,b)]})
   return out
  "spell-fdn-039":return e.Pack.selection([C.group(e,own.filter(func(c):return C.race(e,c,"天狗")),1,1,"移回手牌的天狗"),C.group(e,units,1,1,"另一个单位")],id)
  "spell-ucs-057":return e.Pack.selection([C.group(e,own.filter(func(c):return C.race(e,c,"人偶")),1,1,"选择自己的人偶"),C.group(e,units,1,1,"复制另一个单位")],id)
  "spell-fdf-064":
   var out=[]
   for c in p.grave.filter(func(c):return e.is_unit(c)):
    for s in p.grave.filter(func(s):return C.role(e,s,e.cards[c.card_id].character) and not "终言" in e.cards[s.card_id].keywords):out.append({"parts":[C.ref(e,c),C.ref(e,s)]})
   return out
  "spell-fdn-023":
   var g=C.group(e,p.grave.filter(func(c):return e.is_unit(c) and "黄" in e.Pack.colors(e,c)),0,3,"灵力合计至多3的黄色单位");g.sum_stat="spirit";g.sum_max=3
   for r in g.pool:r.choice_weight=e.stat(e.find_card(r.uid),"spirit")
   return e.Pack.selection([g],id)
  "spell-fdf-052":return e.stack.filter(func(s):return not e.Pack.flatten(s.target).is_empty()).map(func(s):return {"stack_id":s.id})
  "spell-fdf-087":return e.stack.filter(func(s):return s.kind=="card").map(func(s):return {"stack_id":s.id})
  "spell-fdf-063":return e.Pack.selection([e.Pack.group(all,1,1,"伤害目标"),C.group(e,own.filter(func(c):return C.race(e,c,"神")),1,1,"放置指示物的神")],id)
  "spell-fdf-061":return [{"player":1-who,"mode":"本回合不能使用符卡"},{"player":1-who,"mode":"本回合不能使用单位"}]
  "spell-fdf-034":return [{"none":true,"mode":"保留蓝色"},{"none":true,"mode":"保留绿色"}]
  "spell-fdf-124":return [{"player":0},{"player":1}]
  "spell-fdf-072":
   var out=e.Extra.add_mode(rs,"名称改为不明物体并抓牌")
   var g=C.group(e,own.filter(func(c):return C.is_unknown(e,c)),1,1,"牺牲一个不明物体",true)
   var spec=e.Pack.selection([g],id)
   for x in spec:x.mode="牺牲并放入封兽鵺"
   return out+spec
  "spell-fdf-082":
   var out=[]
   for color in ["无","红","蓝","绿","黄","黑"]:
    if color!="无" and color not in e.cards[id].cost:continue
    var choice_title="不忽略颜色" if color=="无" else "忽略"+color+"色"
    var groups=[C.group(e,units,0,2,choice_title+" · 移除至多两个目标单位")] if color!="蓝" else [e.Pack.group([],0,0,choice_title)]
    var spec=e.Pack.selection(groups,id+":"+color)[0];spec.ignore_color=color;out.append(spec)
   return out
  "spell-fdf-025","spell-fdn-046":
   var pool=(p.field+p.grave).filter(func(c):return C.race(e,c,"人偶"));var g=C.group(e,pool,3 if id=="spell-fdn-046" else 0,3 if id=="spell-fdn-046" else 5,"洗回牌库的人偶",true)
   g.distinct_names=id=="spell-fdn-046"
   if g.distinct_names:
    for r in g.pool:r.choice_name=e.cards[e.find_card(r.uid).card_id].name
   var groups=[g]
   if id=="spell-fdf-025":groups.append(e.Pack.group(all,1,1,"伤害目标"))
   return e.Pack.selection(groups,id)
  "spell-fdf-012":
   var out=[];var pool=own.filter(func(c):return not C.character(e,c,"火焰猫燐"))
   for x in range(pool.size()+1):
    var groups=[C.group(e,pool,x,x,"牺牲 %d 个单位" % x,true)]
    for j in range(x):groups.append(e.Pack.group(all,0,1,"选择第 %d 个伤害目标" % [j+1]))
    var spec=e.Pack.selection(groups,id+":"+str(x));out.append_array(spec)
   return out
  "spell-fdf-053","spell-fdf-051","spell-fdf-024":
   var out=[]
   var max_x=maxi(e.catalogue_x_override,e.source_resources(who).size()+C.counter_total(e,own) if id=="spell-fdf-053" else e.source_resources(who).size())
   for x in range(max_x+1):
    if id=="spell-fdf-024":out.append({"none":true,"x":x,"mode":"X = %d" % x});continue
    var targets=C.refs(e,C.field(e).filter(func(c):return e.Roster.permanent(e,c) and e.Extra.cost_value(e,c)==x)) if id=="spell-fdf-051" else e.stack.filter(func(s):return s.kind=="card" and not e.is_unit(s.card) and e.Extra.cost_value(e,s.card)==x).map(func(s):return {"stack_id":s.id})
    if id=="spell-fdf-051":
     var spec=e.Pack.selection([e.Pack.group(targets,0,1,"X = %d · 消灭永久物" % x)],id+":"+str(x))[0];spec.x=x;out.append(spec)
    else:
     for n in range(mini(x,C.counter_total(e,own))+1):
      var groups=[e.Pack.group(targets,1,1,"X = %d · 反制非单位牌" % x)]
      for j in range(n):
       var cg=e.Pack.group(C.counter_refs(e,own),1,1,"移除一个指示物");cg.exclude_previous=true;cg.cost=true;groups.append(cg)
      var specs=e.Pack.selection(groups,id+":"+str(x)+":"+str(n))
      for spec in specs:spec.x=x;spec.counter_payment=n
      out.append_array(specs)
   return out
 return e.Pack.none()
static func resolve(e,t):
 var C=e.Cat;var c=t.card;var id=c.card_id;var who=t.owner;var p=e.players[who];var aim=t.target;var foe=1-who;var exile=false
 if "时符" in e.cards[id].spell_type or "乐章" in e.cards[id].spell_type:
  c.cast_x=int(aim.get("x",0));e.enter_field(c,who)
  return true
 e.resolving_spell=true
 match id:
  "spell-fdf-085":
   for u in (e.units(0)+e.units(1)).duplicate():
    if e.Extra.cost_value(e,u)<=3:e.destroy(u)
  "spell-fdf-086":
   var n=e.units(who).size()+p.field.filter(func(u):return e.cards[u.card_id].kind=="结界").size()
   C.damage(e,{"player":foe},n)
   for u in e.units(foe):C.damage(e,e.ref_target(u),n)
  "spell-fdf-088":
   for u in e.units(who):C.buff(e,u,0,0,0,["防避5"],false)
  "spell-fdf-005":p.leader.timer=0
  "spell-fdf-039":e.gain_life(who,p.palette.size())
  "spell-fdf-033":C.random_discard(e,foe,1);e.players[foe].life-=3
  "spell-ucs-004":C.random_discard(e,aim.player,2)
  "spell-fdf-003":e.draw(who,4);C.continued_move(e,t,p.hand,mini(1,p.hand.size()),1,"grave","弃一张牌")
  "spell-ucs-039":
   for u in p.hand.duplicate():e.move_to(u,"grave")
   e.draw(who,8)
  "spell-fdf-038":e.draw(who,1+aim.extra);p.life-=4*aim.extra
  "spell-fdf-077":e.draw(who)
  "spell-fdf-009":
   for u in e.players[foe].deck.slice(0,3):e.move_to(u,"exile");u.devour_owner=who
   p.exile_free={"turn":e.turn,"remaining":2}
  "spell-fdf-016":var life=p.life;p.life=e.players[foe].life;e.players[foe].life=life;exile=true
  "spell-fdf-008":e.players[aim.player].life=1;exile=true
  "spell-fdf-027":p.mage_flare=e.turn
  "spell-fdf-067":p.next_free_unit=e.turn
  "spell-ucs-035":p.palette_access=e.turn
  "spell-fdf-010":p.indestructible=e.turn
  "spell-fdf-030":p.dolls_indestructible=e.turn
  "spell-fdf-014":
   p.etb_curse=int(p.get("etb_curse",0))+1
   p.etb_curse_sources=p.get("etb_curse_sources",[])+[c.duplicate(true)]
  "spell-fdf-057":
   for u in e.units(who):u.tapped=false
  "spell-fdn-022":
   for u in e.units(aim.player):e.tap_card(u)
  "spell-fdf-061":e.players[aim.player].type_lock={"turn":e.turn,"kind":"符卡" if "符卡" in aim.mode else "单位"}
  "spell-fdf-034":
   var retained="蓝" if aim.mode=="保留蓝色" else "绿"
   var reshuffle=[false,false]
   var victims=C.field(e).filter(func(u):return retained not in e.Pack.colors(e,u))
   for u in victims:
    if u.zone!="field":continue
    var owner=u.get("original_owner",u.owner)
    if u.get("leader",false):u.shuffle_on_return_deck=true
    e.move_to(u,"deck")
    if u.zone=="deck":reshuffle[owner]=true
   for owner in range(2):
    if reshuffle[owner]:e.shuffle(e.players[owner].deck)
  "spell-fdf-124":
   var total=0
   var waiting=0
   for u in e.units(who).duplicate():
    if u.zone!="field":continue
    var value=e.Extra.cost_value(e,u)
    if u.get("leader",false):u.wind_bounce_spell=c.uid;u.wind_bounce_value=value
    e.move_to(u,"hand")
    if u.zone=="hand":total+=value
    elif u.zone=="return_pending":waiting+=1
   if waiting>0:c.wind_bounce={"target":aim.player,"total":total,"remaining":waiting}
   else:e.players[aim.player].life-=int(total/2)
  "spell-fdf-066","spell-fdf-047","spell-fdf-028","spell-fdf-078","spell-fdn-029":
   C.damage(e,aim,2 if id=="spell-fdf-066" else p.palette.filter(func(u):return not u.tapped).size() if id=="spell-fdn-029" else 3)
  "spell-fdf-049":C.damage(e,aim,6);e.draw(who,2)
  "spell-fdf-059":C.damage(e,aim,2)
  "spell-ucs-041":e.draw(who);C.damage(e,aim,int(p.get("drawn",{}).get(str(e.turn),0)))
  "spell-fdf-035":e.gain_life(who,3);C.damage(e,aim,int(p.get("life_gained",{}).get(str(e.turn),0)))
  "spell-fdf-071":
   var n=2+e.units(who).filter(func(u):return C.is_unknown(e,u)).size()
   for r in e.Pack.picked(aim):C.damage(e,r,n)
  "spell-fdf-031":
   for r in e.Pack.picked(aim):C.damage(e,r,4)
   for u in C.selected(e,aim,1):u.tapped=false
  "spell-fdf-025":
   for r in e.Pack.picked(aim,1):C.damage(e,r,int(c.get("paid_dolls",0)))
  "spell-fdf-012":
   for i in range(1,aim.get("picks",[]).size()):
    for r in aim.picks[i]:C.damage(e,r,2)
  "spell-fdf-022":
   if C.unit(e,aim):C.buff(e,e.find_card(aim.uid),-3,-3,0)
  "spell-fdn-028":
   C.damage(e,aim,2);p.life-=3
   if C.unit(e,aim):C.buff(e,e.find_card(aim.uid),0,0,0,["疾行","追击"])
  "spell-rec-054","spell-smm-002":
   if C.unit(e,aim):var u=e.find_card(aim.uid);C.buff(e,u,e.stat(u,"power"),0,e.stat(u,"spirit"))
  "spell-fdn-008":
   if C.unit(e,aim):C.buff(e,e.find_card(aim.uid),4,4,3,["歼灭"])
   if who==e.active:e.players[foe].night_lock=e.turn
  "spell-fdf-050":
   if C.unit(e,aim):
    var u=e.find_card(aim.uid);C.buff(e,u,4,4,3)
    if u.owner==who and C.character(e,u,"魂魄妖梦"):C.delay(e,u,"youmu_fight",who);e.delayed.back().after_turn=e.turn
  "spell-fdf-002":
   if C.unit(e,aim):e.find_card(aim.uid).rank_target={"owner":who,"turns":p.turns+1}
  "spell-fdf-055":
   if C.valid(e,aim):
    var u=e.find_card(aim.uid)
    if aim.mode=="放置2个计时":e.add_timer(u,2)
    else:u.timer=maxi(0,u.timer-2)
  "spell-ucs-050":
   for u in C.selected(e,aim):e.Roster.Batch.counter(e,u,"scare",1,who)
   if p.grave.size()>=10:e.draw(who,2)
  "spell-ucs-052","spell-ucs-009","spell-fdn-030","spell-fdn-031":
   if C.valid(e,aim):
    var u=e.find_card(aim.uid);var owner=u.owner;var value=e.Extra.cost_value(e,u);e.destroy(u)
    if id=="spell-ucs-009":e.players[owner].life-=value
   if id=="spell-fdn-030":e.gain_life(who,2)
   if id=="spell-fdn-031":search(e,t,p.deck.filter(func(u):return e.cards[u.card_id].name=="非想「非想非非想ノ剑」"),0,1,"hand")
  "spell-fdf-074":
   for u in C.selected(e,aim):e.destroy(u)
  "spell-fdn-009":
   if C.unit(e,aim):e.Roster.to_top(e,e.find_card(aim.uid))
  "spell-fdf-120","spell-soi-119","spell-fdf-056":
   if C.valid(e,aim):
    var u=e.find_card(aim.uid);var owner=u.owner;e.move_to(u,"exile")
    if id=="spell-fdf-056":e.add_coin(owner)
  "spell-rec-056","spell-kmo-003":
   if C.unit(e,aim):e.move_to(e.find_card(aim.uid),"hand")
   e.players[foe].life-=2
  "spell-smm-003","spell-rec-055":
   var living=aim.parts.filter(func(r):return C.unit(e,r))
   if not living.is_empty():
    for u in e.units(e.find_card(living[0].uid).owner).duplicate():
     if not living.any(func(r):return r.uid==u.uid):e.move_to(u,"hand")
  "spell-fdn-020":
   if C.valid(e,aim):
    var u=e.find_card(aim.uid);e.Roster.field_many(e,[u],who)
    if u.zone=="field":C.delay(e,u)
  "spell-ucs-037","spell-fdn-023":e.Roster.field_many(e,C.selected(e,aim),who)
  "spell-fdf-064":
   for r in aim.parts:
    if C.valid(e,r):e.move_to(e.find_card(r.uid),"hand")
   exile=true
  "spell-fdf-026":search(e,t,p.deck.filter(func(u):return C.role(e,u)),0,1,"palette")
  "spell-fdf-075":search(e,t,p.deck.filter(func(u):return e.cards[u.card_id].kind=="符卡" and e.Extra.cost_value(e,u)<=2),1,1,"hand")
  "spell-fdf-076":C.choose(e,t,"cat:earth",C.pick(e,p.grave.filter(func(u):return C.role(e,u,"帕秋莉")),0,3,"置于牌库顶"));exile=true
  "spell-fdf-073":C.choose(e,t,"cat:hunt",C.pick(e,C.field(e).filter(func(u):return e.is_unit(u) and u.get("original_owner",u.owner)==who),0,3,"放进颜色盘"))
  "spell-fdf-079":C.choose(e,t,"cat:wood",C.refs(e,p.hand.filter(func(u):return C.role(e,u) and e.Extra.cost_value(e,u)>=4)))
  "spell-ucs-043":e.draw(who,3);C.continued_move(e,t,p.hand,mini(3,p.hand.size()),3,"top","依次选择放到牌库顶的牌")
  "spell-ucs-018":e.draw(who,3);C.choose(e,t,"cat:whale",C.pick(e,p.hand.filter(func(u):return e.cards[u.card_id].kind=="符卡" and e.Extra.cost_value(e,u)<=6),0,1,"不支付费用使用符卡"))
  "spell-fdf-068":
   if p.deck.size()<2:e.lose(foe,"最后ノ理想国");return true
   e.draw(who,2);C.choose(e,t,"cat:gate",C.pick(e,p.hand,0,2,"横置放入颜色盘"));e.move_to(c,"deck");e.shuffle(p.deck);return true
  "spell-ucs-015":
   if C.unit(e,aim):C.buff(e,e.find_card(aim.uid),3,3,0)
   var maximum=0
   for u in e.units(who):maximum=maxi(maximum,e.stat(u,"power"))
   C.distribution(e,t,e.Pack.all_units(e),maximum)
  "spell-fdn-003":C.distribution(e,t,e.Pack.all_units(e),5,false,10)
  "spell-fdf-063":
   var n=9 if p.palette.filter(func(u):return e.Extra.keyword(e,u,"奇迹")).size()>=5 else 4
   for r in e.Pack.picked(aim):C.damage(e,r,n)
   for u in C.selected(e,aim,1):e.Roster.plus(e,u,n,who)
  "spell-fdf-087":
   for s in e.stack.duplicate():
    if s.id==aim.stack_id:
     var n=e.Extra.cost_value(e,s.card);e.counter_entry(s.id);C.distribution(e,t,e.Pack.all_units(e,who),n,true);break
  "spell-fdf-053":e.counter_entry(aim.picks[0][0].stack_id)
  "spell-fdf-013","spell-fdf-084":
   for i in range(3 if id=="spell-fdf-013" else 2):C.printed_token(e,who,"token-fdf-129")
   if id=="spell-fdf-013":e.draw(who,3)
   elif not p.deck.is_empty():e.move_to(p.deck[0],"palette");p.palette.back().tapped=true
  "spell-fdn-040":
   var u=C.token(e,who,"半灵",4,2,2,["黑","绿"],["疾行","先制"],[],"token-ucs-099")
   if not u.is_empty():C.delay(e,u,"sacrifice",who)
   e.move_to(c,"palette");c.tapped=true;return true
  "spell-fdf-080":
   for i in range(2 if e.units(who).any(func(u):return C.character(e,u,"泄矢诹访子")) else 1):C.token(e,who,"青蛙",4,4,2,["蓝","绿"],["不占战场格"])
  "spell-fdf-037","spell-fdf-058","spell-fdf-062":
   for i in range(4 if id=="spell-fdf-037" else 3 if id=="spell-fdf-058" else 2):
    var u=C.token(e,who,"蝙蝠" if id=="spell-fdf-037" else "吸血鬼" if id=="spell-fdf-058" else "鬼",3 if id=="spell-fdf-058" else 1,3 if id=="spell-fdf-058" else 1,2 if id=="spell-fdf-058" else 1,["红","黑"] if id=="spell-fdf-037" else ["红","黄"],["先制","歼灭","疾行","直接攻击单位"] if id=="spell-fdf-058" else ["疾行"] if id=="spell-fdf-037" else [])
    if not u.is_empty():
     if id=="spell-fdf-062":u.imp_growth=true
     else:C.delay(e,u,"sacrifice",who if id=="spell-fdf-037" else -1)
  _:return resolve_complex(e,t)
 e.resolving_spell=false
 e.move_to(c,"exile" if exile else "grave")
 return true
static func search(e,t,pool,low,high,zone):
 if pool.size()<low:low=0
 e.Cat.choose(e,t,"cat:search",e.Cat.pick(e,pool,low,high,"从牌库选择卡牌"),{"zone":zone})
static func trigger_options(_e,_t):return null
static func resolve_choice(e,t):
 var C=e.Cat;var who=t.owner;var p=e.players[who];var d=t.get("data",{});var a=t.target
 match t.effect:
  "cat:search":
   var list=C.selected(e,a);C.reveal(e,list,false)
   if d.zone=="field":e.Roster.field_many(e,list,who)
   else:
    for c in list:e.move_to(c,d.zone)
   e.shuffle(p.deck)
  "cat:earth":
   var list=C.selected(e,a);e.shuffle(list)
   for c in list:e.Roster.to_top(e,c)
  "cat:hunt":
   var list=C.selected(e,a)
   for c in list:e.move_to(c,"palette")
   p.god_bypass=e.turn
   if list.size()>=2:e.draw(who,2)
  "cat:wood":
   if C.valid(e,a):var c=e.find_card(a.uid);e.move_to(c,"exile");c.catalogue_access={"owner":who,"discount":2}
  "cat:whale":
   for c in C.selected(e,a):C.grant_cast(e,c,who,true)
  "cat:gate":
   for c in C.selected(e,a):e.move_to(c,"palette");c.tapped=true
  _:return resolve_complex_choice(e,t)
 return true
static func resolve_complex(e,t):
 var C=e.Cat;var c=t.card;var id=c.card_id;var who=t.owner;var p=e.players[who];var a=t.target;var foe=1-who;var exile=false
 match id:
  "spell-fdn-017":
   var groups=[]
   for z in ["field","grave","palette"]:groups.append(C.group(e,e.players[a.player][z],0,2,{"field":"战场","grave":"墓地","palette":"颜色盘"}[z]+" · 移除至多两张"))
   C.choose(e,t,"cat:qed",e.Pack.selection(groups,id))
  "spell-ucs-022":
   var groups=[]
   for name in ["宇佐见莲子","玛艾露贝莉·赫恩"]:
    var pool=[]
    for card_id in e.DB.IDS:
     if e.cards[card_id].kind in ["自机","单位"] and name in e.cards[card_id].name:pool.append({"outside_id":card_id,"mode":e.cards[card_id].name,"none":true})
    groups.append(e.Pack.group(pool,0,1,"从游戏外选择"+name))
   C.choose(e,t,"cat:outside",e.Pack.selection(groups,id))
  "spell-fdf-072":
   if a.get("mode","")=="名称改为不明物体并抓牌":
    if C.unit(e,a):
     var u=e.find_card(a.uid);C.rename(e,u,"不明物体")
    e.draw(who)
   else:C.choose(e,t,"cat:deploy",C.pick(e,(p.hand+[p.leader]).filter(func(u):return u.zone in ["hand","leader"] and C.character(e,u,"封兽鵺")),0,1,"放入封兽鵺"))
  "spell-fdf-122":C.choose(e,t,"cat:deploy",C.pick(e,(p.hand+[p.leader]).filter(func(u):return u.zone in ["hand","leader"] and C.character(e,u,"多多良小伞")),1,1,"放入多多良小伞"))
  "spell-fdn-046":search(e,t,(p.hand+p.grave+p.palette+p.deck).filter(func(u):return e.is_unit(u) and C.character(e,u,"歌莉娅人偶")),1,1,"field")
  "spell-fdf-081":
   e.draw(0,2);e.draw(1,2)
   C.choose(e,t,"cat:poverty_pair",C.pick(e,e.players[1-who].palette,mini(2,e.players[1-who].palette.size()),2,"在对方颜色盘放置贫乏指示物"),{"other":1-who,"first":true})
  "spell-ucs-054":C.choose(e,t,"cat:split_grave",C.pick(e,p.grave,0,p.grave.size(),"分出墓地第一堆"),{"controller":who,"all":C.refs(e,p.grave)},foe)
  "spell-fdf-060":
   var victims=(e.units(0)+e.units(1)).duplicate()
   for u in victims:e.destroy(u)
   C.choose(e,t,"cat:resurrect",C.pick(e,victims.filter(func(u):return u.zone=="grave"),0,victims.size(),"横置放入你的战场"))
  "spell-fdf-043":
   if C.unit(e,a):
    var u=e.find_card(a.uid);var owner=u.owner;var before=e.stat(u,"health")-u.damage;var dealt=C.damage(e,a,8);var overflow=maxi(0,dealt-maxi(0,before))
    for other in e.units(owner):
     if other.uid!=u.uid:C.damage(e,e.ref_target(other),overflow)
  "spell-fdf-048":C.choose(e,t,"cat:cherry_prevent",C.pick(e,e.players[foe].hand,0,e.players[foe].hand.size(),"移除手牌，每张防止2点伤害"),{"amount":int(c.get("exiled_hand",0))*3,"target":a.picks[0][0],"controller":who},foe)
  "spell-fdf-052":
   for s in e.stack:
    if s.id!=a.stack_id:continue
    var choices=C.retarget_options(e,s)
    C.choose(e,t,"cat:retarget",choices,{"id":s.id});break
  "spell-fdf-051":
   var list=C.selected(e,a)
   if not list.is_empty():
    var u=list[0];var old=u.epoch;e.destroy(u)
    if u.zone!="field" or u.epoch!=old:
     copy_x_menu(e,t)
  "spell-fdf-021":
   e.draw(who)
   if e.flip_coin(who):C.copy_spell(e,t)
  "spell-fdf-082":
   var ignored=a.get("ignore_color","无")
   if ignored!="蓝":
    for u in C.selected(e,a):e.move_to(u,"exile")
   if ignored!="黄":C.choose(e,t,"cat:copy_exile",C.pick(e,(e.players[0].exile+e.players[1].exile).filter(func(u):return e.is_unit(u)),0,2,"复制至多两个除外单位"))
  "spell-fdn-011":
   var groups=[]
   for kinds in [["结界"],["自机","单位"],["道具"],["符卡"]]:groups.append(C.group(e,p.deck.filter(func(u):return e.cards[u.card_id].kind in kinds),0,1,"检索"+" / ".join(kinds)))
   C.choose(e,t,"cat:four_search",e.Pack.selection(groups,id));exile=true
  "spell-fdf-032":
   if C.unit(e,a):C.choose(e,t,"cat:brain_name",C.name_options(e),{"target":a})
  "spell-fdf-015":
   var top=p.deck.slice(0,5);C.reveal(e,top)
   C.choose(e,t,"cat:heaven",C.pick(e,top.filter(func(u):return e.cards[u.card_id].kind=="符卡"),0,2,"将至多两张符卡送墓"),{"top":C.refs(e,top),"target":a})
  "spell-fdf-121":
   C.mill(e,foe,4);e.players[foe].life-=3
   C.choose(e,t,"cat:atonement_discard",C.pick(e,e.players[foe].hand,mini(2,e.players[foe].hand.size()),2,"弃两张牌"),{},foe)
  "spell-fdf-045":C.choose(e,t,"cat:scythe",C.pick(e,e.units(foe),0,1,"牺牲一个单位，或失去2点生命"),{"remaining":3,"controller":who},foe)
  "spell-fdn-039":
   var one=C.selected(e,a);var two=C.selected(e,a,1)
   for u in one:e.move_to(u,"hand")
   for u in two:
    if u.zone=="field":C.buff(e,u,0,1,1,["不能被阻挡"])
  "spell-ucs-057":
   var one=C.selected(e,a);var two=C.selected(e,a,1)
   if not one.is_empty() and not two.is_empty() and one[0].uid!=two[0].uid:C.copy_unit(e,one[0],two[0],true,"alice")
  "spell-fdf-006":pass # Graveyard static ability; resolution sends this card to the grave.
  "spell-fdn-018":
   C.choose(e,t,"cat:death_song_mode",[{"none":true,"mode":"自机区"},{"none":true,"mode":"牌库"}])
  _:push_error("未覆盖的新符卡契约："+id);return false
 e.resolving_spell=false;e.move_to(c,"exile" if exile else "grave");return true
static func resolve_complex_choice(e,t):
 var C=e.Cat;var who=t.owner;var p=e.players[who];var a=t.target;var d=t.get("data",{})
 match t.effect:
  "cat:qed":
   var n=0
   for r in e.Pack.flatten(a):
    if C.valid(e,r):
     var u=e.find_card(r.uid)
     if not e.is_unit(u):n+=1
     e.move_to(u,"exile")
   e.draw(who,n)
  "cat:outside":
   for r in e.Pack.flatten(a):
    if r.has("outside_id"):
     var u=e.make_card(r.outside_id,who,"void");e.move_to(u,"hand");C.reveal(e,[u],false)
  "cat:deploy":e.Roster.field_many(e,C.selected(e,a),who)
  "cat:poverty_pair":
   for u in C.selected(e,a):e.Roster.Batch.counter(e,u,"poverty",1,who)
   if d.first:C.choose(e,t,"cat:poverty_pair",C.pick(e,p.palette,mini(2,p.palette.size()),2,"在对方颜色盘放置贫乏指示物"),{"first":false},d.other)
  "cat:split_grave":
   var chosen=e.Pack.picked(a);var rest=d.all.filter(func(r):return r not in chosen)
   C.choose(e,t,"cat:take_pile",[{"none":true,"mode":"第一堆 · %d 张" % chosen.size(),"pile":0},{"none":true,"mode":"第二堆 · %d 张" % rest.size(),"pile":1}],{"piles":[chosen,rest]},d.controller)
  "cat:take_pile":
   var n=d.piles[1-a.pile].filter(func(r):return C.valid(e,r)).size()
   for r in d.piles[a.pile]:
    if C.valid(e,r):e.move_to(e.find_card(r.uid),"hand")
   e.gain_life(who,n)
  "cat:resurrect":
   var list=C.selected(e,a);e.Roster.field_many(e,list,who,true)
   for u in list:
    if u.zone=="field":C.delay(e,u,"exile",who)
  "cat:cherry_prevent":
   var list=C.selected(e,a)
   for u in list:e.move_to(u,"exile")
   C.damage(e,d.target,maxi(0,d.amount-list.size()*2))
  "cat:retarget":
   for s in e.stack:
    if s.id==d.id:s.target=C.retarget_result(a)
  "cat:copy_x":
   if not a.get("copy_stop",false):C.copy_spell(e,d.entry,a.value,true)
  "cat:spell_copy":
   if a.get("copy_back",false) and d.has("copy_menu_entry"):
    copy_x_menu(e,d.copy_menu_entry);return true
   var c=d.card;var copy={"id":e.next_stack,"kind":"card","card":c,"owner":who,"target":C.retarget_result(a),"name":e.cards[c.card_id].name,"copy":true};e.next_stack+=1;e.stack.append(copy);e.Roster.New.on_target(e,copy.target);e.priority=e.active;e.passes=0
   if d.get("rewritten_fairy",false):copy.rewritten_fairy=true
  "cat:copy_exile":
   for u in C.selected(e,a):C.copy_token(e,who,u,false,"yukari")
  "cat:four_search":
   var list=[]
   for r in e.Pack.flatten(a):
    if C.valid(e,r):list.append(e.find_card(r.uid))
   C.reveal(e,list,false)
   var eligible=list.filter(func(u):return e.Extra.cost_value(e,u)<=5 and e.field_error(u,who).is_empty() and (e.Roster.permanent(e,u) or "时符" in e.cards[u.card_id].spell_type or "乐章" in e.cards[u.card_id].spell_type))
   C.choose(e,t,"cat:four_enter",C.pick(e,eligible,mini(1,eligible.size()),1,"放进战场的一张牌"),{"all":C.refs(e,list)})
  "cat:four_enter":
   var chosen=C.selected(e,a);e.Roster.field_many(e,chosen,who)
   for r in d.all:
    if C.valid(e,r):e.move_to(e.find_card(r.uid),"hand")
   e.shuffle(p.deck)
  "cat:brain_name":
   if C.unit(e,d.target):
    var u=e.find_card(d.target.uid);var owner=u.owner;var list=e.players[owner].hand+e.players[owner].deck.slice(0,1);C.reveal(e,list)
    var matches=list.filter(func(v):return C.normalized(e.cards[v.card_id].name)==C.normalized(a.card_name))
    if matches.size()>0:e.destroy(u)
    if matches.size()>1:
     for v in matches:e.move_to(v,"grave")
  "cat:heaven":
   e.mill_cards(C.selected(e,a))
   var rest=d.top.filter(func(r):return C.valid(e,r));e.shuffle(rest)
   for r in rest:e.move_to(e.find_card(r.uid),"deck")
   C.damage(e,d.target,p.grave.filter(func(u):return e.cards[u.card_id].kind=="符卡").size())
  "cat:atonement_discard":
   for u in C.selected(e,a):e.move_to(u,"grave")
   var biggest=0
   for u in e.units(who):biggest=maxi(biggest,e.Extra.cost_value(e,u))
   C.continued_move(e,t,e.units(who).filter(func(u):return e.Extra.cost_value(e,u)==biggest),mini(1,e.units(who).size()),1,"sacrifice","牺牲颜色值最大的单位")
  "cat:scythe":
   var list=C.selected(e,a)
   if list.is_empty():p.life-=2;e.gain_life(d.controller,2)
   else:e.sacrifice(list[0])
   if d.remaining>1:C.choose(e,t,"cat:scythe",C.pick(e,e.units(who),0,1,"牺牲单位或失去2点生命"),{"remaining":d.remaining-1,"controller":d.controller})
  "cat:death_song_mode":
   var pool=[p.leader] if a.mode=="自机区" and p.leader.zone=="leader" else p.deck.filter(func(u):return e.is_unit(u)) if a.mode=="牌库" else []
   C.choose(e,t,"cat:death_song",C.pick(e,pool,mini(1,pool.size()),1,"选择送去墓地的单位"),{"shuffle":a.mode=="牌库"})
  "cat:death_song":
   for u in C.selected(e,a):e.move_to(u,"grave")
   if d.shuffle:e.shuffle(p.deck)
   e.gain_life(who,4)
  "cat:grant":
   if C.valid(e,d.ref):
    var u=e.find_card(d.ref.uid);e.forced_cast={"owner":who,"uid":u.uid,"free":d.free,"cost":d.cost,"ignore":false};e.priority=who
    var plan=a.get("payment",e.payment(who,e.cast_cost(who,u,a)).plan);a.erase("payment")
    if e.payment_valid(who,e.cast_cost(who,u,a),plan):e.commit_cast(who,u.uid,a,plan)
    e.forced_cast={}
  _:return false
 return true
static func copy_x_menu(e,entry):
 var x=int(entry.target.get("x",0));var options=[{"none":true,"mode":"X 翻倍","value":x*2}]
 if x%2==0:options.append({"none":true,"mode":"X 减半","value":int(x/2)})
 options.append({"none":true,"mode":"停止","copy_stop":true})
 e.Cat.choose(e,entry,"cat:copy_x",options,{"entry":entry.duplicate(true)})
