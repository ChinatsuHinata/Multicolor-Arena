extends "res://tests/support/rules_base.gd"

const DETECTOR="spell-fdf-018"

func detector(who: int=1,zone: String="field"):
 var c=put(DETECTOR,zone,who)
 if zone=="field":c.timer=6
 return c

func detector_triggers() -> int:
 var entries=e.triggers+e.stack
 if e.pending.has("trigger") and not e.pending.has("stack_id"):entries.append(e.pending.trigger)
 return entries.filter(func(t):return t.get("effect","")==DETECTOR).size()

func draws(who: int) -> int:
 return int(e.players[who].get("drawn",{}).get(str(e.turn),0))

func run():
 # Exercise the actual cast, optional entry trigger and recovery resolution.
 fresh();mana();var reaction=detector()
 var recovered=put("18","grave");var aya=put("18","hand")
 var error=e.commit_cast(0,aya.uid,{},e.payment(0,e.cast_cost(0,aya)).plan)
 expect(error.is_empty(),"小文文实际使用成功")
 expect(detector_triggers()==0,"颜色值4的小文文使用不触发测谎仪")
 one()
 expect(e.pending.get("trigger",{}).get("effect","")=="enter_grave_damage","小文文进场开启回收目标选择")
 var target=e.pending.options.filter(func(t):return t.get("parts",[]).size()==2 and t.parts[0].uid==recovered.uid and t.parts[1].get("player",-1)==1)[0]
 e.choose_effect(target)
 one()
 expect(recovered.zone=="hand" and e.players[0].hand.has(recovered),"小文文把墓地单位移回手牌")
 expect(e.players[1].life==19,"小文文回收后造成灵力伤害")
 expect(draws(0)==0 and detector_triggers()==0,"小文文回收既不计抓牌也不触发测谎仪")
 expect(reaction.zone=="field" and reaction.timer==6,"回收结算时测谎仪仍在战场")

 # Even deck-to-hand movement is not necessarily a draw (search/reveal).
 for zone in ["grave","field","deck","exile","palette"]:
  fresh();reaction=detector()
  var card=put("18",zone);var deck_size=e.players[0].deck.size()
  e.move_to(card,"hand");e.pump_choices()
  expect(card.zone=="hand" and e.players[0].hand.size()==1,"移回/取得手牌成功："+zone)
  expect(draws(0)==0 and detector_triggers()==0,"非抓牌的手牌增加不触发："+zone)
  expect(reaction.zone=="field","移牌后测谎仪仍在战场："+zone)
  expect(e.players[0].deck.size()==deck_size-(1 if zone=="deck" else 0),"只有牌库移牌才减少牌库："+zone)

 fresh();detector();e.draw(0,3);e.pump_choices()
 expect(draws(0)==3 and detector_triggers()==3,"实际抓三张逐张触发三次")
 fresh();detector(0);e.draw(0);e.pump_choices()
 expect(draws(0)==1 and detector_triggers()==0,"自己的抓牌不触发自己的测谎仪")
 fresh();detector(1,"grave");e.draw(0);e.pump_choices()
 expect(detector_triggers()==0,"墓地中的测谎仪不触发")

 # A recovered cheap card triggers only when subsequently cast.
 fresh();mana();detector()
 var cheap=put("53","grave");e.move_to(cheap,"hand");e.pump_choices()
 expect(detector_triggers()==0,"低费单位移回手牌也不触发")
 expect(e.Extra.cost_value(e,cheap)<=3,"后续使用的测试单位颜色值不大于3")
 error=e.commit_cast(0,cheap.uid,{},e.payment(0,e.cast_cost(0,cheap)).plan)
 expect(error.is_empty() and detector_triggers()==1,"随后使用低费单位正常触发一次")
 expect(draws(0)==0,"低费使用触发与抓牌计数分开")

 print("LIE DETECTOR: ",checks," checks; ",failures.size()," failures")
 quit(0 if failures.is_empty() else 1)
