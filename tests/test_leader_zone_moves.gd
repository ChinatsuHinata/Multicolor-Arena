extends "res://tests/support/catalogue_rules_base.gd"
const Codec=preload("res://net/state_codec.gd")

func leader_at(zone: String,who: int=0) -> Dictionary:
 var c=e.players[who].leader
 e.move_to(c,zone,false)
 return c

func expect_placement(c: Dictionary,zone: String,label: String):
 expect(c.zone==zone and c.leader and is_same(c,e.players[c.owner].leader),label+" 保留实际自机身份")
 for z in ["hand","deck","field","palette","grave","exile"]:
  expect(e.players[c.owner][z].count(c)==(1 if z==zone else 0),label+" 区域无重复或残留："+z)

func regional_choices():
 var moves=[["hand","palette"],["hand","deck"],["hand","grave"],["hand","exile"],["palette","hand"],["palette","deck"],["palette","grave"],["deck","hand"],["deck","palette"],["grave","palette"],["exile","hand"],["field","grave"]]
 for who in [0,1]:
  for move in moves:
   for home in [false,true]:
    fresh();var c=leader_at(move[0],who)
    var label=str(who)+" "+move[0]+" → "+move[1]+(" 返回" if home else "继续")
    e.move_to(c,move[1]);e.pump_choices()
    expect(e.pending.get("kind","")=="leader_return" and e.pending.owner==who and e.pending.card.uid==c.uid,label+" 由拥有者选择去向")
    e.choose_return(home)
    expect_placement(c,"leader" if home else move[1],label)
    expect(c.timer==(2 if home else 0) and e.pending.is_empty(),label+" 完成选择及计时")

func possession_choices():
 for who in [0,1]:
  for from_hand in [true,false]:
   for home in [false,true]:
    fresh();e.active=who;e.priority=who;e.phase="possession"
    var c=leader_at("hand" if from_hand else "palette",who)
    var other=put("164","palette" if from_hand else "hand",who)
    var p=other if from_hand else c;var h=c if from_hand else other
    e.pending={"kind":"possession","owner":who}
    e.possession(p.uid,h.uid)
    expect(e.pending.get("kind","")=="leader_return" and e.phase=="possession" and e.players[who].possession_count==1,"真实凭依等待自机区域选择："+str(who)+str(from_hand))
    expect(other.zone==("hand" if from_hand else "palette"),"凭依的另一张牌正常交换")
    e.choose_return(home)
    expect_placement(c,"leader" if home else "palette" if from_hand else "hand","凭依后自机")
    expect(e.pending.is_empty() and e.returns.is_empty(),"一次凭依完成后不重复选择")

 # Both exchanged cards can be genuine leaders; each receives one decision.
 fresh();e.phase="possession"
 var first=leader_at("hand")
 var second=e.make_card("68",0,"palette",true)
 e.players[0].extra_leaders=[second];e.players[0].palette.append(second)
 e.pending={"kind":"possession","owner":0}
 e.possession(second.uid,first.uid)
 expect(e.pending.card.uid==second.uid and e.returns.size()==1,"双自机凭依分别排队")
 e.choose_return(false)
 expect(second.zone=="hand" and e.pending.card.uid==first.uid,"第一张的选择不会覆盖第二张")
 e.choose_return(true)
 expect(first.zone=="leader" and second.zone=="hand" and e.pending.is_empty(),"双自机去向分别生效")

 # A third possession must wait until the physical leader's move is settled.
 fresh();e.phase="possession";put("spell-htk-004")
 var c=leader_at("hand");var color=put("164","palette")
 put("165","hand");put("167","palette")
 e.pending={"kind":"possession","owner":0};e.possession(color.uid,c.uid)
 expect(e.pending.get("kind","")=="leader_return" and e.possession_resume,"多次凭依先完成自机去向")
 var saved=Codec.capture(e);var restored=Duel.new();Codec.restore(restored,saved);e=restored
 c=e.players[0].leader;e.choose_return(false)
 expect(c.zone=="palette" and e.pending.get("kind","")=="possession" and not e.possession_resume,"存档恢复后继续后续凭依")

func automatic_moves():
 for who in [0,1]:
  for home in [false,true]:
   fresh();var c=leader_at("deck",who)
   e.players[who].deck.erase(c);e.players[who].deck.push_front(c)
   var next=e.players[who].deck[1]
   e.draw(who,2);e.pump_choices()
   expect(e.pending.get("kind","")=="leader_return" and next.zone=="hand","连续抓牌仍检测牌库中的自机")
   e.choose_return(home)
   expect_placement(c,"leader" if home else "hand","抓牌去向")
   expect(e.players[who].deck.all(func(u):return u.uid!=c.uid) and next.zone=="hand","连续抓牌不重复抽取自机")
   fresh();c=leader_at("deck",who)
   e.players[who].deck.erase(c);e.players[who].deck.push_front(c)
   e.start_turn(who)
   expect(e.pending.get("kind","")=="leader_return" and e.phase=="prepare" and e.active==who,"回合补充颜色盘等待自机去向")
   e.choose_return(home)
   expect_placement(c,"leader" if home else "palette","回合补盘去向")
   expect(e.phase=="prepare" and c.timer==(2 if home else 0),"补盘选择不跳过准备阶段")

func hand_to_deck():
 for home in [false,true]:
  fresh();var c=leader_at("hand")
  var old_top=e.players[0].deck[0]
  e.Roster.to_top(e,c);e.pump_choices();e.choose_return(home)
  expect(e.players[0].deck[0].uid==(old_top.uid if home else c.uid),"手牌自机放回牌库顶保留原牌序及返回选择")

func discard_choices():
 for who in [0,1]:
  for home in [false,true]:
   fresh();e.active=who;e.priority=who;e.phase="end"
   var c=leader_at("hand",who)
   for i in range(7):put("164","hand",who)
   e.cleanup_end();expect(e.pending.get("kind","")=="discard","超过手牌上限请求弃牌")
   e.discard([c.uid])
   expect(e.pending.get("kind","")=="leader_return" and e.active==who and e.phase=="end","弃置自机先等待拥有者选择，保留当前回合")
   var restored=Duel.new();Codec.restore(restored,Codec.capture(e));e=restored;c=e.players[who].leader
   e.choose_return(home)
   expect_placement(c,"leader" if home else "grave","弃牌去向")
   expect(e.active==1-who and e.players[who].hand.size()==7 and e.pending.is_empty(),"恢复并选择后只推进一次回合")
   expect(c.timer==(2 if home else 0),"回合末返回不会立即多移除计时")

 fresh();e.phase="end";var first=leader_at("hand")
 var second=e.make_card("68",0,"hand",true)
 e.players[0].extra_leaders=[second];e.players[0].hand.append(second)
 for i in range(7):put("164","hand")
 e.cleanup_end();e.discard([first.uid,second.uid]);e.choose_return(true)
 expect(e.active==0 and e.pending.get("card",{}).get("uid",-1)==second.uid,"批量弃自机等所有选择完成后才结束回合")
 e.choose_return(false)
 expect(e.active==1 and first.zone=="leader" and second.zone=="grave","批量弃牌的两种去向都生效")

func palette_effects():
 for home in [false,true]:
  fresh();var watcher=put("character-ucs-044");var c=leader_at("hand")
  e.move_to(c,"palette");c.tapped=true;c.poverty=1;e.pump_choices();e.choose_return(home)
  var events=e.triggers+e.stack+[e.pending.get("trigger",{})]
  expect(events.any(func(t):return t.get("source",{}).get("uid",-1)==watcher.uid)==not home,"实际进颜色盘才触发监视能力")
  expect((not c.tapped and c.poverty==0) if home else (c.tapped and c.poverty==1),"颜色盘的横置和贫乏效果在等待选择后仍保留")

 for effect in ["cat:clown_palette","spell-fdf-084"]:
  for home in [false,true]:
   fresh();var c=leader_at("deck")
   e.players[0].deck.erase(c);e.players[0].deck.push_front(c)
   if effect=="cat:clown_palette":
    var color=put("164","palette")
    e.Cat.continuation(e,{"effect":effect,"target":e.Pack.ref(e,color),"owner":0})
   else:resolve_spell(effect)
   e.pump_choices()
   expect(e.pending.get("kind","")=="leader_return" and c.tapped,effect+" 在空颜色盘补入自机时正确等待选择")
   e.choose_return(home)
   expect(c.zone==("leader" if home else "palette") and c.tapped==not home,effect+" 横置只作用于实际补入的自机")

func boundaries():
 fresh();var c=leader_at("hand")
 e.move_to(c,"hand");e.pump_choices()
 expect(e.pending.is_empty() and e.returns.is_empty(),"同区域整理不生成自机返回选择")
 var ordinary=put("70","hand")
 e.move_to(ordinary,"palette");e.pump_choices()
 expect(ordinary.zone=="palette" and e.pending.is_empty(),"普通同名自机单位牌不获得本局自机返回规则")
 e.move_to(c,"grave",false);e.pump_choices()
 expect(c.zone=="grave" and e.pending.is_empty(),"显式不提供返回的移动继续生效")
 e.move_to(c,"hand");e.pump_choices();var epoch=c.epoch
 e.move_to(c,"deck");e.pump_choices()
 expect(e.pending.card.uid==c.uid and c.epoch==epoch and e.returns.is_empty(),"等待中的同一自机不能再次移动或重复排队")
 e.choose_return(false);e.choose_return(true)
 expect(c.zone=="hand" and c.timer==0,"重复提交不会再次移动已完成选择的自机")

func run():
 if "--palette-effects" in OS.get_cmdline_user_args():palette_effects()
 else:regional_choices();possession_choices();automatic_moves();hand_to_deck();discard_choices();palette_effects();boundaries()
 print("LEADER_ZONE_MOVES: ",checks," checks; ",failures.size()," failures")
 quit(0 if failures.is_empty() else 1)
