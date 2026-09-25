extends RefCounted
const ENTER=["character-lof-004","character-fdf-114","character-fdn-024","character-fdf-106","character-ucs-036","character-fdf-092","character-ucs-020","character-ucs-023","character-fdf-065","character-ucs-034","character-ucs-003","character-fdn-034","field-rei-013"]
const ENTER_SELF=["character-ucs-067:self","character-fdn-048:self"]
static func on_enter(e,c):
 var C=e.Cat;var who=c.owner
 C.State.sync_fairies(e)
 if c.card_id in C.SPELLS and "时符" in e.cards[c.card_id].spell_type:e.add_timer(c,int(c.get("cast_x",0)) if c.card_id=="spell-fdf-024" else e.cards[c.card_id].time)
 if c.get("haste_on_enter",false):C.buff(e,c,0,0,0,["疾行"])
 for word in e.cards[c.card_id].get("keywords",[]):
  if word.begins_with("防避"):
   e.next_buff_order+=1
   c.wards=c.get("wards",[])+[{"amount":int(word.trim_prefix("防避")),"turn":-1,"order":e.next_buff_order}]
 for k in ENTER:
  if C.has(e,c,k):C.events(e,c,k,k in ["character-fdf-114","character-ucs-003"],{"event":"enter"})
 for k in ENTER_SELF:
  if C.enabled(e,c,k):C.events(e,c,k)
 if C.has(e,c,"character-fdf-101"):
  C.events(e,c,"cat:momiji_name",false,{"ref":C.ref(e,c)})
 if C.has(e,c,"character-fdf-046") and c.get("ichirin_paid",false):C.events(e,c,"character-fdf-046")
 if e.is_unit(c):
  for p in e.players:
   for source in p.get("etb_curse_sources",[]):C.events(e,source,"cat:etb_curse")
  for u in C.field(e,who).duplicate():
   if C.has(e,u,"item-ucs-005") and e.cards[c.card_id].kind=="自机":C.events(e,u,"item-ucs-005",false,{"amount":e.Extra.cost_value(e,c)})
   if C.has(e,u,"field-ucs-064") and e.cards[c.card_id].kind=="自机":C.events(e,u,"field-ucs-064",true,{"ref":C.ref(e,c)})
   if C.has(e,u,"spell-lof-006") and C.race(e,c,"妖精") and e.players[who].get("fairy_enter_turn",-1)!=e.turn:C.events(e,u,"spell-lof-006",false,{"ref":C.ref(e,c)})
  if C.race(e,c,"妖精"):e.players[who].fairy_enter_turn=e.turn
  if c.get("top_free_damage",false):C.events(e,c,"cat:top_free_damage")
  if e.cards[c.card_id].kind=="自机":
   for u in e.players[who].grave:
    if C.has(e,u,"spell-fdf-028"):C.events(e,u,"cat:nuclear_return",true)
 if C.has(e,c,"spell-fdf-024"):C.events(e,c,"spell-fdf-024")
 if C.has(e,c,"spell-fdn-012"):C.events(e,c,"spell-fdn-012",true)
static func on_leave(e,before,c):
 var C=e.Cat;var who=before.owner
 if c.zone=="hand" and c.owner==who:
  for k in ["character-fdn-037","character-fdn-038"]:
   if C.has(e,before,k):C.events(e,before,k)
  if C.race(e,before,"天狗"):
   for u in e.units(who):
    if C.has(e,u,"character-fdn-036"):C.events(e,u,"character-fdn-036")
 if c.zone=="exile":on_sacrifice_or_exile(e,before)
 if e.is_unit(before) and c.zone in ["grave","exile"]:
  for u in C.with_key(e,1-who,"spell-fdn-005"):C.events(e,u,"spell-fdn-005")
 if C.has(e,before,"field-rei-013"):
  for r in before.get("catalogue_castle",[]):
   if C.valid(e,r):var u=e.find_card(r.uid);e.Roster.field_many(e,[u],u.owner)
static func on_sacrifice_or_exile(e,c):
 for u in e.units(c.owner)+([c] if not e.units(c.owner).any(func(u):return u.uid==c.uid) else []):
  if e.Cat.has(e,u,"character-htk-005"):e.Cat.events(e,u,"character-htk-005")
static func on_death(e,c,before):
 var C=e.Cat;var who=before.owner
 for k in ["character-fdn-024","character-fdf-106","character-fdn-043","character-fdf-069","character-fdn-021","character-fdn-004","character-fdf-105","character-fdf-065","character-fdn-034"]:
  if k=="character-fdn-043":continue
  if C.has(e,before,k):C.events(e,before,k,k in ["character-fdf-106"],{"event":"death","ref":C.ref(e,c),"power":e.stat(before,"power")})
 if C.enabled(e,before,"character-fdf-029:self"):C.events(e,before,"character-fdf-029:self",true)
 if C.has(e,before,"character-fdn-042") and before.get("noncombat_damage_turn",-1)==e.turn:
  C.events(e,before,"cat:utsuho_return",false,{"ref":C.ref(e,c)})
 if before.has("rank_target"):C.events(e,before,"cat:rank_death",false,{"owner":before.owner})
 for u in C.with_key(e,1-who,"spell-fdf-040"):C.events(e,u,"cat:night_timer")
static func on_cast(e,c,who,old_zone):
 var C=e.Cat;var p=e.players[who]
 if C.role(e,c):
  for u in (p.field+p.grave).duplicate():
   for k in ["character-fdf-119","character-fdn-025","character-fdf-093","character-fdf-109","spell-fdn-010"]:
    if not C.has(e,u,k):continue
    if k=="character-fdf-109" and u.zone!="grave" or k!="character-fdf-109" and u.zone!="field":continue
    if k=="character-fdf-119" and e.usage_count(u.uid,k)>0:continue
    C.events(e,u,k,k in ["character-fdf-109","character-fdf-093"],{"event":"cast","value":e.Extra.cost_value(e,c)})
    if k=="character-fdf-119":e.use_once(u.uid,k)
 if C.has(e,c,"spell-fdn-010"):C.events(e,c,"spell-fdn-010",false,{"value":e.Extra.cost_value(e,c)})
 if e.Extra.cost_value(e,c)<=3:
  for u in C.with_key(e,1-who,"spell-fdf-018"):C.events(e,u,"spell-fdf-018")
 if old_zone=="palette" and C.role(e,c,"魂魄妖梦"):p.youmu_palette_turn=e.turn
 if old_zone=="exile" and p.get("exile_free",{}).get("turn",-1)==e.turn:p.exile_free.remaining-=1
 if e.is_unit(c) and p.get("next_free_unit",-1)==e.turn:c.top_free_damage=old_zone=="deck";p.next_free_unit=-1
 if e.cards[c.card_id].kind=="自机" and p.get("next_fairy_leader",-1)==e.turn:c.haste_on_enter=true;p.next_fairy_leader=-1
 if C.role(e,c) or C.race(e,c,"吸血鬼"):p.erase("maid_discount")
static func on_phase(e,phase):
 var C=e.Cat;var who=e.active
 for u in C.field(e).duplicate():
  if u.owner==who:
   if phase=="prepare":
    for k in ["character-fdf-103","character-ucs-021","spell-ucs-059","spell-fdf-024"]:
     if C.has(e,u,k):C.events(e,u,k,k=="character-ucs-021")
   if phase=="main":
    for k in ["item-fdf-097","character-lof-002"]:
     if C.has(e,u,k):C.events(e,u,k)
   if phase=="end":
    for k in ["character-ucs-016","character-fdf-104","character-fdf-117","character-fdf-094","character-fdf-100","character-fdn-045","spell-fdf-040","spell-fdn-033","spell-fdn-002"]:
     if C.has(e,u,k):C.events(e,u,k)
    for k in ["character-fdf-119:self","character-fdn-025:self"]:
     if C.enabled(e,u,k):C.events(e,u,k,true)
    if C.has(e,u,"character-ucs-056"):C.events(e,u,"character-ucs-056")
  elif phase=="end" and C.has(e,u,"spell-fdf-042"):C.events(e,u,"spell-fdf-042")
 if phase=="end":
  for watch in e.players[who].get("tengu_watches",[]):
   var observer=e.find_card(watch.uid)
   if not observer.is_empty() and observer.zone=="field" and observer.epoch==watch.epoch and observer.owner==watch.owner and e.players[who].get("attacked_player_turn",-1)==e.turn:C.events(e,watch,"cat:tengu_watch",true)
  e.players[who].tengu_watches=[]
static func on_attack(e,c):
 var C=e.Cat
 for k in ["character-fdf-110","character-fdf-065"]:
  if C.has(e,c,k):C.events(e,c,k)
 if c.get("imp_growth",false):C.events(e,c,"cat:imp_growth")
 if e.cards[c.card_id].kind=="自机":
  for u in e.players[c.owner].grave:
   if C.has(e,u,"spell-fdf-002"):C.events(e,u,"cat:rank_return")
static func on_block(e,c):
 if e.Cat.has(e,c,"character-fdf-065"):e.Cat.events(e,c,"character-fdf-065")
static func on_blocked(e,c):
 if e.Cat.has(e,c,"character-ucs-025"):e.Cat.events(e,c,"character-ucs-025")
 if e.Cat.enabled(e,c,"character-fdf-090:self"):e.Cat.events(e,c,"character-fdf-090:self")
static func options(e,t):
 var C=e.Cat;var who=t.owner;var k=t.effect;var data=t.get("data",{});var units=e.units(0)+e.units(1)
 match k:
  "cat:momiji_name":return C.name_options(e)
  "cat:etb_curse":return e.Pack.none()
  "character-lof-004","character-htk-005":return e.Pack.all_units(e)
  "character-fdf-119":return C.pick(e,units,0,1,"目标单位") if data.get("event","")=="enter" else e.Pack.selection([e.Pack.group(e.ability_targets(),0,1,"至多一个任意目标")],k)
  "character-fdf-114":return C.pick(e,units.filter(func(c):return c.uid!=t.source.uid),2,2,"两个其他单位互相造成伤害",k)
  "character-fdn-024":return [{"player":0},{"player":1}]
  "character-ucs-036","character-ucs-056":return [{"player":1-who}]
  "character-fdf-065","cat:top_free_damage":return e.ability_targets() if k=="character-fdf-065" else C.refs(e,units.filter(func(c):return c.uid!=t.source.uid))
  "character-fdf-046","field-ucs-064":return e.Pack.all_units(e,1-who)
  "field-rei-013":return C.pick(e,units.filter(func(c):return e.cards[c.card_id].kind!="自机"),0,1,"移除一个非自机单位",k)
  "item-ucs-005","character-fdf-069":return C.pick(e,units,0,1,"至多一个目标单位",k)
  "character-fdf-029:self":return C.refs(e,e.players[who].grave.filter(func(c):return C.role(e,c,"小野冢小町")))
  "spell-ucs-059":return C.refs(e,e.units(who).filter(func(c):return e.cards[c.card_id].kind=="自机"))
  "character-fdf-117":return C.pick(e,e.units(who),0,1,"变为不明物体",k)
  "character-fdf-093":return C.refs(e,e.players[1-who].palette)
  "character-fdn-045":return e.Extra.add_mode(e.ability_targets(),"造成4点伤害")+[{"none":true,"mode":"对对方所有单位造成2点伤害"},{"none":true,"mode":"获得5点生命"}]
  "spell-fdf-018":return e.Pack.none()
  "spell-fdf-123","cat:lie_damage","cat:god_damage","cat:murder_dolls":return C.pick(e,units,0,1,"至多一个目标单位",k) if k in ["spell-fdf-123","cat:murder_dolls"] else e.Pack.selection([e.Pack.group(e.ability_targets() if k=="cat:lie_damage" else C.opponents(),0,1,"至多一个目标")],k)
  "character-ucs-073":return C.pick(e,C.field(e).filter(func(u):return e.cards[u.card_id].kind in ["道具","结界"]),0,1,"消灭至多一个道具或结界",k)
  "character-fdf-091":return C.refs(e,e.players[who].grave.filter(func(u):return e.is_unit(u)))
 if k in ENTER+ENTER_SELF+["character-fdf-103","character-ucs-021","character-ucs-016","character-fdf-104","character-fdf-094","character-fdf-100","character-fdf-119:self","character-fdn-025:self","character-fdn-025","character-fdf-109","character-fdn-037","character-fdn-038","character-fdn-036","character-fdf-106","character-fdn-021","character-fdn-004","character-fdf-105","item-fdf-097","character-lof-002","character-fdf-110","character-ucs-025","character-fdf-090:self","spell-fdf-024","spell-fdn-012","spell-lof-006","spell-fdn-010","spell-fdn-005","spell-fdf-040","spell-fdn-033","spell-fdn-002","spell-fdf-042","cat:nuclear_return","cat:utsuho_return","cat:rank_death","cat:night_timer","cat:imp_growth","cat:rank_return","cat:tengu_watch","cat:element_reveal","cat:flower_cast","cat:unconscious_return","cat:sacrifice_recover","character-ucs-044","character-fdn-026","character-fdf-041:self"]:return e.Pack.none()
 return null
static func resolve(e,t):
 var C=e.Cat;var who=t.owner;var p=e.players[who];var k=t.effect;var a=t.target;var d=t.get("data",{});var source=t.source;var c=e.find_card(source.uid);var same=not c.is_empty() and c.epoch==source.epoch
 match k:
  "cat:etb_curse":e.players[1-who].life-=2
  "character-lof-004":if C.unit(e,a):C.buff(e,e.find_card(a.uid),0,0,0,["威吓"])
  "character-htk-005":if C.unit(e,a):C.buff(e,e.find_card(a.uid),0,0,1,["威吓"])
  "character-fdf-114":
   var list=e.Pack.picked(a)
   if list.size()==2:C.fight(e,list[0],list[1])
  "character-fdf-046":if same:C.forced_battle(e,C.ref(e,c),a)
  "field-ucs-064":C.forced_battle(e,d.ref,a)
  "character-fdf-119":
   if d.get("event","")!="enter":
    for r in e.Pack.picked(a):C.damage(e,r,3)
  "character-fdf-119:self","character-fdf-092","character-fdf-041:self":
   var top=p.deck.slice(maxi(0,p.deck.size()-3)) if k=="character-fdf-092" else p.deck.slice(0,3);C.reveal(e,top,k!="character-fdf-092","bottom" if k=="character-fdf-092" else "")
   C.choose(e,t,"cat:unit_reveal",C.pick(e,top.filter(func(u):return "时符" in e.cards[u.card_id].spell_type if k=="character-fdf-041:self" else C.role(e,u)),0,1,"选择一张展示的牌"),{"top":C.refs(e,top),"mode":k})
  "character-fdn-024":C.mill(e,a.player,1)
  "character-ucs-036":C.random_discard(e,a.player,1)
  "character-fdf-106":
   if d.get("event","")=="enter":e.gain_life(who,4)
   else:C.token(e,who,"埴轮",5,5,2,["黄"],["英勇"])
  "character-ucs-020":
   for u in p.exile.duplicate():
    if u.get("dream",0)>0:e.move_to(u,"hand")
  "character-ucs-021":C.choose(e,t,"cat:dream_exile",C.pick(e,p.deck,0,1,"检索并放置梦指示物"))
  "character-ucs-023","character-fdn-034":
   for i in range(3 if k=="character-ucs-023" else 1):C.token(e,who,"飞头",1,1,1,["红","蓝"],["不占战场格"])
  "character-fdf-065":C.damage(e,a,2);e.gain_life(who,2)
  "character-ucs-034":if not e.flip_coin(who):C.damage(e,{"player":who},3)
  "character-ucs-003":C.choose(e,t,"cat:megumu",C.pick(e,p.hand.filter(func(u):return e.is_unit(u) and e.Extra.cost_value(e,u)<=4 and e.Pack.colors(e,u).any(func(color):return color in ["蓝","黑"])),0,1,"放入蓝色或黑色单位"))
  "field-rei-013":
   for u in C.selected(e,a):
    e.move_to(u,"exile")
    if same:c.catalogue_castle=c.get("catalogue_castle",[])+[C.ref(e,u)]
    else:e.Roster.field_many(e,[u],u.owner)
  "character-ucs-067:self","character-fdn-048:self":C.continued_move(e,t,e.units(1-who).filter(func(u):return not u.get("token",false)),mini(1,e.units(1-who).filter(func(u):return not u.get("token",false)).size()),1,"sacrifice","牺牲一个非衍生物单位",{},1-who)
  "item-ucs-005","character-fdf-069","cat:murder_dolls":
   for r in e.Pack.picked(a):C.damage(e,r,int(d.get("amount",d.get("power",0))))
  "spell-lof-006":
   if C.unit(e,d.ref):
    var names=[]
    for u in p.palette:
     if C.race(e,u,"妖精") and e.cards[u.card_id].name not in names:names.append(e.cards[u.card_id].name)
    C.buff(e,e.find_card(d.ref.uid),names.size(),0,names.size(),["疾行"])
  "cat:top_free_damage":C.damage(e,a,e.stat(source,"power"))
  "cat:nuclear_return","cat:sacrifice_recover","character-ucs-044":
   var cost={"红":1,"黑":1} if k=="cat:nuclear_return" else {"黄":1,"黑":1} if k=="cat:sacrifice_recover" else {"绿":1}
   C.choose(e,t,"cat:trigger_pay",C.pay_options(e,who,cost),{"cost":cost,"effect":k,"ref":C.ref(e,c) if not c.is_empty() else {}})
  "spell-fdf-024":
   for u in e.units(who):C.buff(e,u,0,0,0,["防避3"],false)
  "spell-fdn-012":e.Cat.Spells.search(e,t,p.deck.filter(func(u):return C.character(e,u,"魂魄妖梦")),0,1,"field")
  "character-fdn-037":
   if not p.deck.is_empty():
    var top=p.deck[0];C.reveal(e,[top])
    if C.race(e,top,"天狗"):e.Roster.field_many(e,[top],who,true)
    else:e.move_to(top,"hand")
  "character-fdn-038":C.distribution(e,t,e.ability_targets(),3)
  "character-fdn-036":
   var token=C.printed_token(e,who,"token-fdn-082")
   if not token.is_empty():token.news_health=true # This creator explicitly grants +0/+1 and +1, unlike the generic Excel token.
  "character-fdn-021":e.draw(who,4)
  "character-fdn-004":
   if C.valid(e,d.ref):e.move_to(e.find_card(d.ref.uid),"hand")
  "character-fdf-105":
   if C.valid(e,d.ref):e.move_to(e.find_card(d.ref.uid),"deck");e.shuffle(p.deck)
   e.draw(who)
  "character-fdf-029:self":
   if C.valid(e,a):e.move_to(e.find_card(a.uid),"hand");p.life-=2
  "cat:utsuho_return":
   if C.valid(e,d.ref):C.delay(e,e.find_card(d.ref.uid),"return",-1,"prepare")
  "cat:rank_death":e.players[d.owner].life-=3
  "cat:night_timer":if same:e.add_timer(c,1)
  "spell-fdn-005":
   for u in e.units(who):C.buff(e,u,1,0,1)
  "character-fdf-103":if same:e.move_to(c,"hand")
  "spell-ucs-059":if C.unit(e,a):C.buff(e,e.find_card(a.uid),2,2,2,["退治"])
  "item-fdf-097":
   var u=C.token(e,who,"月兔",2,2,2,["蓝","黑"],["疾行","不占战场格"])
   if not u.is_empty():C.delay(e,u,"sacrifice",who)
  "character-lof-002":
   if same and c.zone=="field":e.present_move(c,"field",1-who);p.field.erase(c);c.owner=1-who;e.players[c.owner].field.append(c);c.entered_turns=e.players[c.owner].turns;p.next_fairy_leader=e.turn
  "character-ucs-016":e.draw(who);e.gain_life(who,1)
  "character-fdf-104":
   var u=C.token(e,who,"虫群",1,1,1,["黄"])
   if not u.is_empty():e.cards[u.card_id].race=["全部"]
  "character-fdf-117":
   for u in C.selected(e,a):C.unknown(e,u)
  "character-fdf-094":C.printed_token(e,who,"token-fdf-127")
  "character-fdf-100":
   if e.players[1-who].deck.size()<=20:
    for u in e.units(1-who):e.Roster.Batch.counter(e,u,"minus_counters",1,who)
  "character-fdn-045":
   if a.mode=="造成4点伤害":C.damage(e,a,4)
   elif a.mode=="获得5点生命":e.gain_life(who,5)
   else:
    for u in e.units(1-who):C.damage(e,e.ref_target(u),2)
  "spell-fdf-040":C.damage(e,{"player":1-who},1)
  "spell-fdn-002":C.damage(e,{"player":0},3);C.damage(e,{"player":1},3)
  "spell-fdf-042":
   for player in range(2):e.players[player].leader.timer=maxi(0,e.players[player].leader.timer-1);C.mill(e,player,1)
  "spell-fdn-033":C.choose(e,t,"cat:hypnosis",C.pick(e,p.hand,mini(1,p.hand.size()),1,"弃一张手牌"),{"controller":who,"first":true})
  "character-fdn-025:self":C.choose(e,t,"cat:sisters_exile",C.pick(e,p.hand.filter(func(u):return C.role(e,u,"蕾米莉亚") or C.role(e,u,"芙兰朵露")),0,1,"移除角色符卡，获得支援"))
  "character-ucs-056":e.players[a.player].tengu_watches=e.players[a.player].get("tengu_watches",[])+[source]
  "cat:tengu_watch":e.Cat.Spells.search(e,t,p.deck.filter(func(u):return C.race(e,u,"天狗")),0,1,"field")
  "character-fdf-110":
   for u in e.units(who):
    if C.race(e,u,"鬼"):C.buff(e,u,0,0,0,["疾行","歼灭"])
  "cat:imp_growth":if same:e.Roster.plus(e,c,2,who)
  "cat:rank_return":if same and c.zone=="grave":e.move_to(c,"hand")
  "character-ucs-025":e.draw(who)
  "character-fdf-090:self":
   var u=C.token(e,who,"幻象",3,3,2,["红","黑"],["先制"])
   if not u.is_empty():u.reisen_illusion=true
  "character-fdn-025":C.token(e,who,"吸血鬼",2,2,2,["红","黑","黄","蓝"],["吸血1","不占战场格"])
  "character-fdf-093":if C.valid(e,a):e.Roster.Batch.counter(e,e.find_card(a.uid),"poverty",1,who)
  "character-fdf-109":
   if same and c.zone=="grave":e.move_to(c,"palette");c.tapped=true
   e.gain_life(who,2)
  "spell-fdn-010":
   for i in range(int(d.get("value",0))):C.printed_token(e,who,"token-fdf-129")
  "spell-fdf-018":if not e.flip_coin(who):C.events(e,source,"cat:lie_damage",false)
  "cat:lie_damage","cat:god_damage":
   for r in e.Pack.picked(a):C.damage(e,r,int(d.get("amount",1)))
  "spell-fdf-123":
   for u in C.selected(e,a):e.Roster.Batch.counter(e,u,"scare",d.amount,who)
  "character-ucs-073":
   for u in C.selected(e,a):e.destroy(u)
  "character-fdf-091":if C.valid(e,a):e.move_to(e.find_card(a.uid),"hand")
  "character-fdn-026":
   if e.flip_coin(who):C.random_discard(e,d.player,1)
   else:e.draw(who)
  "cat:flower_cast":
   if same and c.zone=="palette":C.grant_cast(e,c,who,true)
  "cat:unconscious_return":
   if same and c.zone=="grave":e.move_to(c,"hand")
  "cat:element_reveal":
   if C.valid(e,d.ref):
    var u=e.find_card(d.ref.uid);e.move_to(u,"exile");C.grant_cast(e,u,who,u.card_id=="spell-fdf-079",{"红":1} if u.card_id=="spell-fdf-078" else {})
  _:return resolve_choices(e,t)
 return true
static func resolve_choices(e,t):
 var C=e.Cat;var who=t.owner;var p=e.players[who];var a=t.target;var d=t.get("data",{})
 match t.effect:
  "cat:momiji_name":if C.valid(e,d.ref):e.find_card(d.ref.uid).locked_name=a.card_name
  "cat:dream_exile":
   for u in C.selected(e,a):C.reveal(e,[u],false);e.move_to(u,"exile");u.dream=1
   e.shuffle(p.deck)
  "cat:unit_reveal":
   var chosen=C.selected(e,a)
   for u in chosen:
    if d.mode=="character-fdf-041:self":e.Roster.field_many(e,[u],who)
    else:e.move_to(u,"hand")
   var rest=d.top.filter(func(r):return C.valid(e,r))
   if d.mode=="character-fdf-119:self":C.choose(e,t,"cat:bottom_order",e.Roster.pick(e,rest,rest.size(),rest.size(),"依次放入牌库底"))
   else:
    for r in rest:e.move_to(e.find_card(r.uid),"grave")
  "cat:bottom_order":
   for u in C.selected(e,a):e.move_to(u,"deck")
  "cat:megumu":
   var list=C.selected(e,a);e.Roster.field_many(e,list,who)
   for u in list:
    if u.zone=="field":C.buff(e,u,0,0,0,["疾行"]);C.delay(e,u,"hand")
  "cat:hypnosis":
   for u in C.selected(e,a):e.move_to(u,"grave")
   if d.first:C.choose(e,t,"cat:hypnosis",C.pick(e,e.players[1-who].hand,mini(1,e.players[1-who].hand.size()),1,"弃一张手牌"),{"controller":d.controller,"first":false},1-who)
   else:p.life-=maxi(0,4-p.hand.size())
  "cat:sisters_exile":
   for u in C.selected(e,a):e.move_to(u,"exile");u.catalogue_access={"owner":who,"discount":2,"support":true}
  "cat:trigger_pay":
   if a.get("pay",false):
    var plan=a.get("payment",e.payment(who,d.cost).plan)
    if e.payment_valid(who,d.cost,plan):
     C.pay(e,who,plan)
     if d.effect=="character-ucs-044":e.draw(who)
     elif C.valid(e,d.ref):
      var u=e.find_card(d.ref.uid)
      if d.effect=="cat:nuclear_return":e.move_to(u,"hand")
      else:e.draw(who);e.move_to(u,"palette");u.tapped=true
  _:return false
 return true
static func activation_cost(k):
 return {"item-ucs-017":{"黑":1},"item-htk-008":{"蓝":1,"黄":1},"character-fdn-038":{"黑":1,"绿":1},"character-fdn-006":{"黄":1},"spell-fdn-032":{"红":2},"spell-fdf-059":{"绿":1}}.get(k,{})
static func activation_error(e,c,k):
 var C=e.Cat
 if not C.enabled(e,c,k):return "没有该异能"
 if k in ["item-ucs-013","item-htk-008","character-fdn-043","character-smm05","character-fdf-113","token-fdf-127","token-fdf-129"] and not e.can_sacrifice(c):return "不能牺牲该永久物"
 if k in ["item-fdn-044","item-lof-009","item-ucs-017","item-fdf-096","character-fdn-006","character-fdf-112","character-fdn-027","character-fdf-113","character-fdn-041"] and (c.tapped or e.is_unit(c) and e.summoning_sick(c)):return "不能横置"
 if k in ["item-fdf-096","character-fdn-006"] and (e.phase!="main" or not e.stack.is_empty() or not e.combat.is_empty() or e.active!=c.owner):return "只能在自由时机启动"
 if k=="character-fdn-036:self" and e.usage_count(c.uid,k)>0:return "本回合已发动"
 return ""
static func activation_options(e,c,k):
 var C=e.Cat;var who=c.owner;var p=e.players[who];var units=e.units(0)+e.units(1)
 match k:
  "item-fdn-044":return C.pick(e,p.grave,0,1,"洗回墓地中的牌",k)
  "item-lof-009":
   var g=C.group(e,e.units(who).filter(func(u):return C.race(e,u,"妖精")),1,1,"牺牲一个妖精",true)
   var targets=C.refs(e,units.filter(func(u):return u.get("original_owner",u.owner)==who and e.stat(u,"spirit")<=3))
   return e.Pack.selection([g,e.Pack.group(e.Extra.add_mode(targets,"重置")+e.Extra.add_mode(targets,"置于牌库顶"),1,1,"选择目标与效果")],k)
  "item-ucs-017":return e.Pack.selection([C.group(e,e.units(who),1,1,"牺牲一个单位",true)],k)
  "item-fdf-096":return C.refs(e,(p.palette+[p.leader]).filter(func(u):return e.cards[u.card_id].kind=="自机" and (u.zone=="palette" or u.zone=="leader" and u.timer==0)))
  "item-ucs-013","item-htk-008","character-smm05","character-fdn-038","token-fdf-127":return e.Pack.none()
  "character-fdn-036:self":return C.refs(e,e.units(who).filter(func(u):return u.uid!=c.uid and C.race(e,u,"天狗")))
  "character-fdn-006":return e.Pack.selection([C.group(e,p.hand.filter(func(u):return e.is_unit(u)),1,1,"弃一张单位牌",true)],k)
  "character-fdn-043":return C.pick(e,e.players[0].grave+e.players[1].grave,0,3,"移除墓地中的牌",k)
  "character-fdf-112":
   var out=[{"none":true,"mode":"创造两个人偶"}];var pool=e.units(who).filter(func(u):return C.race(e,u,"人偶"))
   out.append_array(e.Pack.selection([C.group(e,pool,0,pool.size(),"牺牲X个人偶并检索",true)],k));return out
  "character-fdf-102":return e.Pack.selection([C.group(e,p.hand.filter(func(u):return C.role(e,u,"魂魄妖梦")),1,1,"将角色符卡横置放入颜色盘",true),C.group(e,e.units(who).filter(func(u):return C.race(e,u,"亡灵") or C.race(e,u,"半灵")),1,1,"重置亡灵或半灵")],k)
  "character-fdn-027":return C.refs(e,units.filter(func(u):return e.cards[u.card_id].kind=="自机"))
  "character-fdf-113":return C.refs(e,e.players[0].palette+e.players[1].palette)
  "character-fdf-111":
   var out=[]
   for player in range(2):
    var pool=C.counter_refs(e,e.players[player].palette).filter(func(r):return r.counter=="poverty")
    var g=e.Pack.group(pool,3,3,"移除同一玩家的3个贫乏指示物");g.cost=true;out.append_array(e.Pack.selection([g],k+str(player)))
   return out
  "character-fdn-041":return [{"none":true,"mode":"减少1红","color":"红"},{"none":true,"mode":"减少1黄","color":"黄"}]
  "character-ucs-065:health","character-ucs-065:spirit":return e.Pack.selection([C.group(e,p.hand,1,1,"弃一张牌",true)],k)
  "spell-fdn-032":return C.refs(e,units)
  "spell-fdf-059":return e.Pack.selection([C.group(e,e.units(who).filter(func(u):return C.race(e,u,"小人")),1,1,"牺牲一个小人",true)],k)
  "spell-fdn-019":return e.Pack.selection([C.group(e,e.units(who),1,1,"牺牲一个单位",true),C.group(e,p.palette,1,1,"重置一张颜色盘")],k)
  "token-fdf-129":return e.ability_targets()
 return []
static func pay_activation(e,c,k,t):
 var C=e.Cat
 if k in ["item-fdn-044","item-lof-009","item-ucs-017","item-fdf-096","character-fdn-006","character-fdf-112","character-fdn-027","character-fdf-113","character-fdn-041"]:e.tap_card(c)
 if k in ["item-lof-009","item-ucs-017","spell-fdf-059","spell-fdn-019"] or k=="character-fdf-112" and t.has("picks"):
  for u in C.selected(e,t):e.sacrifice(u)
 if k in ["item-ucs-013","item-htk-008","character-fdn-043","character-smm05","character-fdf-113","token-fdf-127","token-fdf-129"]:e.sacrifice(c)
 if k in ["character-fdn-006","character-ucs-065:health","character-ucs-065:spirit"]:
  for u in C.selected(e,t):e.move_to(u,"grave")
 if k=="character-fdf-102":
  for u in C.selected(e,t):e.move_to(u,"palette");u.tapped=true
 if k=="character-fdf-111":C.remove_counters(e,e.Pack.picked(t))
 if k=="character-fdn-036:self":e.use_once(c.uid,k)
static func resolve_activation(e,t):
 var C=e.Cat;var who=t.owner;var p=e.players[who];var k=t.effect;var a=t.target;var c=e.find_card(t.source.uid);var same=not c.is_empty() and c.epoch==t.source.epoch
 match k:
  "item-fdn-044":
   for u in C.selected(e,a):e.move_to(u,"deck")
   e.shuffle(p.deck);e.gain_life(who,1)
  "item-lof-009":
   for r in e.Pack.picked(a,1):
    if C.unit(e,r):
     var u=e.find_card(r.uid)
     if r.mode=="重置":u.tapped=false
     else:e.Roster.to_top(e,u)
  "item-ucs-017":e.draw(who)
  "item-fdf-096":
   if C.valid(e,a):
    var u=e.find_card(a.uid);e.Roster.field_many(e,[u],who)
    if u.zone=="field":
     C.buff(e,u,0,0,0,["疾行"]);C.delay(e,u);e.delayed.back().expires_turn=e.turn
  "item-ucs-013":p.all_self_turn=e.turn
  "item-htk-008":e.draw(who,2);C.continued_move(e,t,p.hand,mini(1,p.hand.size()),1,"grave","弃一张牌")
  "character-fdn-036:self":if C.unit(e,a):e.move_to(e.find_card(a.uid),"hand")
  "character-fdn-038":if same:e.move_to(c,"hand")
  "character-fdn-006":C.copy_token(e,who,c if same else t.source,true,"mountain_fairy")
  "character-fdn-043":
   for u in C.selected(e,a):e.move_to(u,"exile")
  "character-smm05":
   for u in e.units(who):
    if u.get("token",false):C.buff(e,u,0,0,1,["英勇"])
  "character-fdf-112":
   if a.has("picks"):
    var n=a.picks[0].size();C.Spells.search(e,t,p.deck.filter(func(u):return C.role(e,u,"爱丽丝") and "终言" not in e.cards[u.card_id].keywords and e.Extra.cost_value(e,u)==n),0,1,"hand")
   else:
    for i in range(2):C.token(e,who,"人偶",1,1,1,["黄"])
  "character-fdf-102","spell-fdn-019":
   for u in C.selected(e,a,1):u.tapped=false
  "character-fdn-027":if C.unit(e,a):C.buff(e,e.find_card(a.uid),0,0,0,["防避3"])
  "character-fdf-113":
   if C.valid(e,a):
    var u=e.find_card(a.uid);var owner=u.owner;var draw=C.role(e,u);e.move_to(u,"grave")
    if not e.players[owner].deck.is_empty():e.move_to(e.players[owner].deck[0],"palette");e.players[owner].palette.back().tapped=true
    if draw:e.draw(who)
  "character-fdf-111":
   if same and c.zone=="grave":e.Roster.field_many(e,[c],who)
   e.players[1-who].life-=3
  "character-fdn-041":p.maid_discount={"turn":e.turn,"color":a.color}
  "character-ucs-065:health","character-ucs-065:spirit":
   if same:
    var stat="health" if k.ends_with("health") else "spirit";var power=e.stat(c,"power");var other=e.stat(c,stat)
    C.buff(e,c,other-power,power-other if stat=="health" else 0,power-other if stat=="spirit" else 0)
  "spell-fdn-032":
   if C.unit(e,a):var u=e.find_card(a.uid);e.Roster.Batch.counter(e,u,"madness",1,who)
  "spell-fdf-059":if same and c.zone=="grave":e.move_to(c,"hand")
  "token-fdf-127":e.gain_life(who,1)
  "token-fdf-129":
   if a.has("player"):
    e.next_buff_order+=1
    e.players[a.player].wards=e.players[a.player].get("wards",[])+[{"amount":1,"turn":e.turn,"order":e.next_buff_order}]
   elif C.unit(e,a):C.buff(e,e.find_card(a.uid),0,0,0,["防避1"])
