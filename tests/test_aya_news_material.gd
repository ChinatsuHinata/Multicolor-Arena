extends "res://tests/support/rules_base.gd"
const AYA="character-fdn-036"
const NEWS="token-fdn-082"
const Codec=preload("res://net/state_codec.gd")

func news(who: int=0) -> Array:
 return e.players[who].field.filter(func(c):return c.card_id==NEWS)

func run():
 for leader in [false,true]:
  for return_home in [false,true] if leader else [false]:
   fresh()
   var aya=put(AYA);aya.leader=leader
   if leader:e.players[0].leader=aya
   e.move_to(aya,"hand");e.pump_choices()
   if leader:
    expect(e.pending.get("kind","")=="leader_return","bounced leader offers its destination choice")
    e.choose_return(return_home)
   settle()
   expect(news().size()==(0 if return_home else 1),"Aya observes her own return to hand, but not a return home: %s / %s" % [leader,return_home])
   if not news().is_empty():expect(news()[0].get("news_health",false),"self-bounce creates the news token with its health bonus")
 fresh()
 var aya=put(AYA);put(AYA)
 e.move_to(aya,"hand");settle()
 expect(news().size()==2,"each Aya observes the bounce exactly once, including the leaving Aya")
 fresh();put(AYA)
 var tengu=put("18");e.move_to(tengu,"hand");settle()
 expect(news().size()==1,"another controlled tengu returning to hand still creates news")
 fresh();put(AYA)
 var unit=put("164");e.move_to(unit,"hand");settle()
 expect(news().is_empty(),"non-tengu returns do not create news")
 fresh()
 aya=put(AYA);aya.original_owner=1
 e.move_to(aya,"hand");settle()
 expect(news().is_empty() and news(1).is_empty(),"a stolen Aya returning to its owner's hand does not trigger for either player")
 fresh()
 aya=put(AYA);aya.leader=true;e.players[0].leader=aya
 e.move_to(aya,"hand");e.pump_choices()
 var saved=Codec.capture(e);e=Duel.new();Codec.restore(e,saved)
 e.choose_return(false);settle()
 expect(news().size()==1,"pending self-bounce survives save restoration")
 print("AYA NEWS MATERIAL: %d checks; %d failures" % [checks,failures.size()])
 quit(0 if failures.is_empty() else 1)
