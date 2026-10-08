extends "res://tests/support/rules_base.gd"

func autumn_count(who: int=0) -> int:
 return (e.triggers+e.stack).filter(func(t):return t.get("effect","")=="hand_autumn" and t.owner==who).size()

func finish_autumn(accept: bool=true):
 for i in range(32):
  e.pump_choices()
  if not e.pending.is_empty():
   match e.pending.kind:
    "trigger_order":e.choose_trigger_order(0)
    "effect_choice":
     if e.pending.trigger.effect!="hand_autumn":
      expect(false,"unexpected choice while resolving Autumn");return
     e.choose_effect(e.pending.options[0] if accept else {})
    "reveal_review":e.confirm_revealed(e.pending.owner,e.pending.serial)
    _:
     expect(false,"unexpected pending state while resolving Autumn");return
  elif not e.stack.is_empty():one()
  else:return
 expect(false,"Autumn resolution finishes within the limit")

func run():
 spell_tokens()
 ability_tokens()
 effective_colors()
 entry_boundaries()
 print("AUTUMN_ENTRY: ",checks," checks; ",failures.size()," failures")
 quit(0 if failures.is_empty() else 1)

func spell_tokens():
 fresh();mana()
 var autumn=put("11","hand");var wings=put("129","hand")
 expect(e.commit_cast(0,wings.uid,{"none":true},e.payment(0,e.cast_cost(0,wings)).plan).is_empty(),"cast Wings through the normal spell stack")
 expect(autumn_count()==0 and autumn.zone=="hand","announcing a token spell does not trigger Autumn")
 one()
 var bats=e.units(0).filter(func(c):return c.card_id=="token-kmo-027")
 expect(bats.size()==2 and bats.all(func(c):return e.Pack.colors(e,c)==["红","黑"]),"Wings creates two red-black bats")
 expect(autumn_count()==2,"each bat's effect-defined color triggers Autumn once")
 expect(autumn.zone=="hand","Autumn stays in hand until its trigger resolves")
 finish_autumn()
 expect(autumn.zone=="field" and e.units(0).filter(func(c):return c.uid==autumn.uid).size()==1,"accepting batch triggers puts the same Autumn card onto the field once")
 expect(e.presentation_events.filter(func(v):return v.type=="reveal" and v.card.uid==autumn.uid).size()==1,"Autumn is revealed once before entering")
 expect(e.pending.is_empty() and e.stack.is_empty() and e.triggers.is_empty(),"remaining batch triggers finish after Autumn leaves the hand")

func ability_tokens():
 fresh()
 var alice=put("character-fdf-112");var autumn=put("11","hand")
 expect(e.commit_extension(0,alice.uid,{"none":true,"mode":"创造两个人偶"},[],"character-fdf-112").is_empty(),"activate Alice's token creation through the normal ability stack")
 expect(autumn_count()==0,"announcing a token ability does not trigger Autumn")
 one()
 var dolls=e.units(0).filter(func(c):return c.token and e.cards[c.card_id].name=="人偶")
 expect(dolls.size()==2 and autumn_count()==2,"each yellow doll created by the ability triggers Autumn")
 finish_autumn()
 expect(autumn.zone=="field","Autumn enters after the token ability resolves")

func effective_colors():
 for colors in [["红"],["黄"],["红","黄"],["蓝","绿"],[]]:
  fresh();var autumn=put("11","hand")
  var token=e.make_card("roster_token_bat",0,"token");token.token_colors=colors
  expect(e.enter_token_batch([token],0).size()==1,"effect-colored token enters: "+str(colors))
  var qualifies="红" in colors or "黄" in colors
  expect(autumn_count()==(1 if qualifies else 0),"Autumn uses the token's actual colors once per entry: "+str(colors))
  finish_autumn()
  expect(autumn.zone==("field" if qualifies else "hand"),"Autumn resolution follows the actual color condition: "+str(colors))

 fresh();put("11","hand")
 var blue=e.Cat.token(e,0,"鬼",1,1,1,["红","黄"],[],[],"",false);blue.token_colors=["蓝"]
 e.enter_token_batch([blue],0)
 expect(autumn_count()==0,"a token whose base red-yellow colors are replaced by blue does not trigger Autumn")

 fresh();put("11","hand")
 var colored=put("roster_token_bat");colored.color_counters=["黄"]
 e.Cat.copy_token(e,0,colored)
 expect(autumn_count()==1,"a token copy's inherited yellow color is included when checking entry")

func entry_boundaries():
 fresh()
 var own=put("11","hand");var enemy=put("11","hand",1)
 e.Cat.tokens(e,1,2,"人偶",1,1,1,["黄"])
 expect(autumn_count()==0 and autumn_count(1)==2,"only the controller of the entering tokens receives Autumn triggers")
 finish_autumn()
 expect(own.zone=="hand" and enemy.zone=="field","opponent tokens cannot put our Autumn onto the field")

 fresh();var autumn=put("11","hand")
 e.Cat.token(e,0,"蝙蝠",1,1,1,["红"])
 finish_autumn(false)
 expect(autumn.zone=="hand" and e.presentation_events.all(func(v):return v.type!="reveal"),"Autumn's token-entry trigger remains optional")

 fresh();put("11","hand")
 e.Cat.printed_token(e,0,"token-fdf-127");e.Cat.printed_token(e,0,"token-fdf-129")
 expect(autumn_count()==0,"yellow item and red barrier tokens do not satisfy the unit condition")

 fresh();put("11","hand")
 for i in range(6):put("roster_token_bat")
 var failed=e.Cat.tokens(e,0,2,"人偶",1,1,1,["黄"])
 expect(failed.is_empty() and autumn_count()==0,"a failed token batch creates no entry triggers")

 fresh();autumn=put("11","hand")
 for i in range(5):put("roster_token_bat")
 e.Cat.token(e,0,"人偶",1,1,1,["黄"])
 expect(autumn_count()==1,"a successful token entry still triggers Autumn when it fills the battlefield")
 finish_autumn()
 expect(autumn.zone=="hand","Autumn cannot enter when the battlefield has no remaining unit slot")
