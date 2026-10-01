extends "res://tests/support/rules_base.gd"

func setup_entry(id: String,extra: int=3,protected: bool=true,target_id: String="character-fdf-110") -> Dictionary:
 fresh()
 var enemy=put(target_id,"field",1)
 if protected:put("spell-fdn-015","field",1).timer=3
 var discard=put("53","hand")
 var resources={"红":"165","蓝":"167","绿":"166","黄":"164","黑":"168"}
 for color in e.cards[id].cost:
  for i in range(e.cards[id].cost[color]):put(resources[color],"palette")
 for i in range(extra):put(["164","166","165"][i%3],"palette")
 var source=put(id,"hand")
 expect(e.commit_cast(0,source.uid,{},e.payment(0,e.cast_cost(0,source)).plan).is_empty(),"cast entry unit: "+e.cards[id].name)
 one()
 expect(source.zone=="field" and e.pending.get("kind","")=="effect_choice","unit enters before selecting its ability target: "+id)
 expect(e.players[0].palette.filter(func(c):return c.tapped).size()==3,"casting spends only the unit's three-point base cost: "+id)
 return {"source":source,"enemy":enemy,"discard":discard}

func choose_payment(pay: bool):
 var option=e.pending.options.filter(func(t):return t.get("pay",false)==pay)[0].duplicate(true)
 if pay:option.payment=e.payment(0,e.pending.trigger.data.cost).plan
 e.choose_effect(option)

func finish_discard(c: Dictionary):
 expect(e.pending.get("trigger",{}).get("effect","")=="orin_kill","paid cat ability proceeds to its discard choice")
 var target=e.pending.options[0].duplicate(true)
 target.erase("selection");target.picks=[[e.Pack.ref(e,c)]]
 e.choose_effect(target)

func run():
 var board=setup_entry("character-ucs-038")
 e.choose_effect(e.ref_target(board.enemy))
 expect(e.pending.trigger.effect=="trigger_target_payment" and e.pending.trigger.data.cost=={"红/蓝/绿/黄/黑":3},"three-cost cat must pay three extra colors to target protected Yuugi")
 expect(board.discard.zone=="hand" and board.enemy.zone=="field","cat neither discards nor destroys before tax payment")
 choose_payment(true)
 expect(e.players[0].palette.all(func(c):return c.tapped),"cat spends six colors total: three for the unit and three for targeting")
 one();finish_discard(board.discard)
 expect(board.discard.zone=="grave" and board.enemy.zone=="grave","paid cat discards one card and destroys Yuugi")
 expect(e.pending.is_empty(),"cat discard continuation finishes without a second tax")

 for extra in [0,2]:
  board=setup_entry("character-ucs-038",extra)
  e.choose_effect(e.ref_target(board.enemy))
  expect(not e.pending.options.any(func(t):return t.get("pay",false)),"cat cannot target protected Yuugi with only %d spare colors" % extra)
  choose_payment(false)
  expect(board.source.zone=="field" and board.discard.zone=="hand" and board.enemy.zone=="field" and e.stack.is_empty(),"unpaid cat remains in play without discarding or destroying")

 board=setup_entry("39")
 e.choose_effect(e.ref_target(board.enemy))
 expect(e.pending.trigger.effect=="trigger_target_payment" and e.pending.trigger.data.cost=={"红/蓝/绿/黄/黑":3},"Youmu's entry duel must pay three extra colors to target protected Yuugi")
 expect(e.combat.is_empty() and e.combat_queue.is_empty(),"Youmu starts no duel before paying the tax")
 choose_payment(true);one()
 expect(e.players[0].palette.all(func(c):return c.tapped) and e.combat.get("forced",false),"paid Youmu starts a forced duel after spending six colors total")
 for i in range(8):
  if e.combat.is_empty():break
  one();settle()
 expect(board.source.zone=="grave" and board.enemy.zone=="field" and board.enemy.damage==3,"paid duel resolves actual Youmu and Yuugi combat damage")

 for extra in [0,2]:
  board=setup_entry("39",extra)
  e.choose_effect(e.ref_target(board.enemy));choose_payment(false)
  expect(board.source.zone=="field" and board.enemy.damage==0 and e.combat.is_empty() and e.combat_queue.is_empty(),"unpaid Youmu enters normally and starts no duel with %d spare colors" % extra)

 for id in ["character-ucs-038","39"]:
  for scenario in ["without_mist","non_oni"]:
   board=setup_entry(id,0,scenario!="without_mist","53" if scenario=="non_oni" else "character-fdf-110")
   e.choose_effect(e.ref_target(board.enemy))
   expect(e.pending.is_empty() and e.stack.back().get("announced",false),"no tax for "+id+" "+scenario)
   one()
   if id=="character-ucs-038":
    finish_discard(board.discard)
    expect(board.enemy.zone=="grave","untaxed cat still destroys its target: "+scenario)
   else:
    expect(e.combat.get("forced",false),"untaxed Youmu still duels its target: "+scenario)

 print("MIST_UNIT_ABILITIES: ",checks," checks; ",failures.size()," failures")
 quit(0 if failures.is_empty() else 1)
