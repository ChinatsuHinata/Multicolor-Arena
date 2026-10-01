extends "res://tests/support/rules_base.gd"

func komachi(who: int=0):
 var c=e.make_card("character-kmo-001",who,"hand")
 c.leader=true
 e.enter_field(c,who)
 return c

func run():
 for who in range(2):
  fresh();e.players[who].coins=3;komachi()
  expect(e.winner==1-who and e.phase=="over","entering Komachi checks existing coins for player %d" % who)
 fresh();e.players[0].coins=3;e.players[1].coins=4;komachi(1)
 expect(e.winner==-1,"all coin losers are collected before settling a draw")
 fresh();komachi();e.add_coin(1,2)
 expect(e.winner==-2,"two coins do not lose")
 e.add_coin(1)
 expect(e.winner==0,"third coin immediately loses with Komachi present")
 fresh();e.add_coin(1,3);e.judge()
 expect(e.winner==-2,"coins alone do not end the game")
 fresh();var c=komachi();e.move_to(c,"grave");e.add_coin(1,3);e.judge()
 expect(e.winner==-2,"Komachi outside the battlefield does not enforce coin loss")
 fresh();put("character-kmo-001");e.add_coin(1,3);e.judge()
 expect(e.winner==-2,"Komachi without an active leader ability does not enforce coin loss")
 fresh();komachi();e.players[0].coins=3;e.players[1].coins=3;e.judge()
 expect(e.winner==-1,"state check settles simultaneous coin losses as a draw")
 print("KOMACHI COINS: ",checks," checks; ",failures.size()," failures")
 quit(0 if failures.is_empty() else 1)
