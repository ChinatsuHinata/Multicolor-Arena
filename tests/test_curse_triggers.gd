extends "res://tests/support/rules_base.gd"
const Caption=preload("res://scripts/rules/ability_caption.gd")
const Codec=preload("res://net/state_codec.gd")
const SeatView=preload("res://net/seat_projection.gd")
const Observer=preload("res://net/observer_projection.gd")
const Remote=preload("res://net/remote_duel.gd")
func install_curses(who: int,count: int,reuse: bool=false):
 e.debug_enabled=true;e.debug_free_payment=true;e.active=who
 put("character-fdf-ex02","field",who)
 var curse={}
 for i in range(count):
  if reuse and not curse.is_empty():e.move_to(curse,"hand")
  else:curse=put("spell-fdf-014","hand",who)
  e.priority=who
  var error=e.commit_cast(who,curse.uid,{"none":true},[])
  expect(error.is_empty(),"实际使用第 %d 层诅咒（玩家 %d）：%s" % [i+1,who,error])
  one()
 expect(e.players[who].get("etb_curse",0)==count and e.players[who].get("etb_curse_sources",[]).size()==count,"每次结算保留一个独立的永久诅咒来源")
func enter_plain(who: int,kind: String="单位"):
 var id="curse_test_"+str(e.next_uid)
 e.cards[id]=e.cards["53"].duplicate(true)
 e.cards[id].name="诅咒测试";e.cards[id].kind=kind;e.cards[id].abilities=[];e.cards[id].keywords=[]
 var c=put(id,"hand",who);e.enter_field(c,who)
 return c
func stack_curses(count: int):
 expect(e.triggers.size()==count and e.triggers.all(func(t):return t.effect=="cat:etb_curse" and not t.optional),"%d 层分别产生 %d 个强制触发" % [count,count])
 expect(e.triggers.all(func(t):return t.ability_text.contains("对手失去2点生命") and not t.ability_text.contains("cat:")),"触发入堆叠前已有中文能力文字")
 e.pump_choices()
 while e.pending.get("kind","")=="trigger_order":e.choose_trigger_order(0)
 expect(e.pending.is_empty() and e.stack.size()==count,"每层独立进入堆叠，无需选择目标")
 for entry in e.stack:expect(Caption.text(entry).contains("每当一个单位进战场") and not Caption.text(entry).contains("cat:"),"堆叠使用中文诅咒说明")
func lose_separately(who: int,count: int):
 var initial=e.players[who].life
 for i in range(count):
  one()
  expect(e.players[who].life==initial-2*(i+1) and e.stack.size()==count-i-1,"第 %d 次结算只失去 2 点生命" % (i+1))
func run():
 for caster in range(2):
  for count in [1,2,4,5]:
   fresh();e.players[0].life=80;e.players[1].life=80
   install_curses(caster,count)
   # A permanent curse survives its original card leaving the graveyard.
   for c in e.players[caster].grave.duplicate():e.move_to(c,"exile")
   var restored=Duel.new();Codec.restore(restored,Codec.capture(e));e=restored
   enter_plain(1-caster);stack_curses(count)
   for seat in range(2):
    var remote=Remote.new();remote.apply_snapshot(SeatView.build(e,seat))
    expect(remote.stack.size()==count and remote.stack.all(func(t):return Caption.text(t).contains("对手失去2点生命")),"联机玩家 %d 保留全部独立触发和中文说明" % seat)
   var observer=Remote.new();observer.apply_snapshot(Observer.build(e))
   expect(observer.stack.size()==count and observer.stack.all(func(t):return Caption.text(t).contains("对手失去2点生命")),"观战保留全部独立触发和中文说明")
   lose_separately(1-caster,count)
   expect(e.players[caster].life==80,"诅咒只扣对手生命")
   enter_plain(caster);stack_curses(count);lose_separately(1-caster,count)
   expect(e.players[caster].life==80,"按卡面规则，己方单位进场也使对手失去生命")
   enter_plain(1-caster,"道具")
   expect(e.triggers.is_empty() and e.stack.is_empty(),"非单位进场不触发诅咒")
 fresh();e.players[1].life=80;install_curses(0,3,true)
 expect(e.players[0].etb_curse_sources.all(func(c):return c.uid==e.players[0].etb_curse_sources[0].uid),"同一张诅咒反复使用也保留三层")
 enter_plain(1);stack_curses(3);lose_separately(1,3)
 expect(Caption.text({"effect":"cat:etb_curse","ability_text":"cat:etb_curse"}).contains("对手失去2点生命"),"旧存档中的占位符改为中文说明")
 expect(Caption.text({"effect":"cat:etb_curse"}).contains("对手失去2点生命"),"缺失能力文案的旧堆叠仍显示中文")
 print("CURSE_TRIGGERS: ",checks," checks; ",failures.size()," failures")
 quit(0 if failures.is_empty() else 1)
