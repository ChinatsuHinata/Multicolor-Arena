extends "res://tests/support/rules_base.gd"

func choose_cards(groups: Array):
 var choice=e.pending.options[0].duplicate(true)
 choice.erase("selection");choice.picks=groups
 e.choose_effect(choice)

func deploy(timed: Dictionary):
 var field=put("170","deck")
 var unit=put("27","deck")
 var item=put("167","deck")
 var spell=e.make_card("spell-fdn-011",0,"stack")
 expect(e.Extra.spell_resolve(e,{"card":spell,"owner":0,"target":{"none":true}}),"四重结界正常结算")
 expect(e.pending.get("trigger",{}).get("effect","")=="cat:four_search","结算时搜寻四类牌")
 choose_cards([[e.Cat.ref(e,field)],[e.Cat.ref(e,unit)],[e.Cat.ref(e,item)],[e.Cat.ref(e,timed)]])
 expect(e.pending.get("trigger",{}).get("effect","")=="cat:four_enter","搜寻后选择放进战场的牌")
 choose_cards([[e.Cat.ref(e,timed)]])
 expect(timed.zone=="field" and timed.timer==int(e.cards[timed.card_id].time),timed.card_id+"带有且仅有牌面数量的计时进场")
 expect([field,unit,item].all(func(c):return c.zone=="hand"),"其余三类牌置于手牌")
 expect(spell.zone=="exile","四重结界结算后移除")

func run():
 fresh()
 var timed_ids=[]
 for id in e.cards:
  var info=e.cards[id]
  if "时符" in info.get("spell_type","") and int(info.get("time",0))>0 and info.get("canonical_id",id)==id and id in DB.IDS:timed_ids.append(id)
 for id in timed_ids:
  fresh();e.players[0].deck.clear()
  var timed=put(id,"deck")
  if e.Extra.cost_value(e,timed)<=5:deploy(timed)

 for delta in [-1,0,1]:
  fresh();e.players[0].deck.clear()
  var sakuya=put("75");sakuya.leader=true
  var timed=put("102","deck")
  deploy(timed)
  expect(e.pending.get("kind","")=="timer","四重结界放入的时符允许咲夜调整计时")
  e.choose_timer(delta)
  expect(timed.timer==2+delta,"计时调整生效："+str(delta))

 fresh();e.players[0].deck.clear()
 var dolls=put("spell-fdf-017");dolls.timer=2
 put("27","field",1)
 var timed=put("102","deck")
 deploy(timed)
 var events=e.triggers+e.stack
 if e.pending.has("trigger"):events.append(e.pending.trigger)
 expect(events.any(func(t):return t.get("effect","")=="cat:murder_dolls" and t.get("data",{}).get("amount",0)==2),"放置计时正常触发杀人玩偶")
 print("FOURFOLD_BARRIER: ",checks," checks; ",failures.size()," failures")
 quit(0 if failures.is_empty() else 1)
