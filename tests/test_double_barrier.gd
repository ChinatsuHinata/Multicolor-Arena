extends "res://tests/support/rules_base.gd"

const Codec=preload("res://net/state_codec.gd")
const SeatView=preload("res://net/seat_projection.gd")
const Observer=preload("res://net/observer_projection.gd")
const Remote=preload("res://net/remote_duel.gd")
const BARRIER="spell-fdf-011"

func prepare():
 fresh();mana();put("70")
 for id in ["165","167","166","164","168"]:
  for i in range(8):put(id,"palette",1)

func use_card(id: String,who: int=0,target: Dictionary={"none":true}):
 var c=put(id,"hand",who);e.priority=who
 expect(e.commit_cast(who,c.uid,target,e.payment(who,e.cast_cost(who,c)).plan).is_empty(),"use "+id+" by player "+str(who))
 one()
 return c

func stats(c: Dictionary,values: Array,title: String):
 var actual=[e.stat(c,"power"),e.stat(c,"health"),e.stat(c,"spirit")]
 expect(actual==values,title+" "+str(actual))

func run():
 later_casts()
 entry_paths_and_zones()
 modifiers_and_control()
 duration_and_recasts()
 synchronized_state()
 print("DOUBLE_BARRIER: ",checks," checks; ",failures.size()," failures")
 quit(0 if failures.is_empty() else 1)

func later_casts():
 prepare()
 var own=put("53");var enemy=put("53","field",1)
 var spell=put(BARRIER,"hand")
 expect(e.commit_cast(0,spell.uid,{"none":true},e.payment(0,e.cast_cost(0,spell)).plan).is_empty(),"barrier enters the stack")
 stats(own,[2,2,1],"barrier does not apply before resolution")
 one()
 stats(own,[4,4,4],"existing friendly unit")
 stats(enemy,[2,2,2],"existing opposing unit")
 expect(spell.zone=="grave","aura persists after the spell reaches the grave")
 own=use_card("53")
 stats(own,[4,4,4],"friendly unit cast after barrier")
 enemy=use_card("character-fdn-037",1)
 expect(enemy.zone=="field","opponent's later fast unit really resolves")
 stats(enemy,[2,2,2],"opposing unit cast after barrier")

func entry_paths_and_zones():
 prepare();use_card(BARRIER)
 var reimu=e.units(0).filter(func(c):return c.card_id=="70")[0]
 e.move_to(reimu,"hand")
 stats(enter("53"),[4,4,4],"friendly effect entry after Reimu leaves")
 stats(enter("53",1),[2,2,2],"opposing effect entry after Reimu leaves")
 for who in range(2):
  var c=e.Cat.token(e,who,"人偶",1,3,1,["黄"])
  var n=4 if who==0 else 2
  stats(c,[n,n,n],"later token on side "+str(who))
  var batch=[put("53","hand",who),put("53","grave",who)]
  e.Roster.field_many(e,batch,who)
  for u in batch:stats(u,[n,n,n],"later batch entry on side "+str(who))
  e.move_to(batch[0],"hand")
  stats(batch[0],[2,2,1],"unit outside battlefield keeps printed stats")
  e.detach(batch[0]);e.enter_field(batch[0],who)
  stats(batch[0],[n,n,n],"returned unit receives aura again")
 stats(reimu,[3,4,2],"Reimu in hand keeps printed stats")
 stats(e.players[1].leader,[3,4,2],"self zone is outside the aura")
 stats(put("164"),[0,0,0],"non-unit permanent is outside the aura")

func modifiers_and_control():
 prepare()
 var own=put("53");own.plus_counters=2
 e.apply_turn_buff(e.ref_target(own),{"攻击力":3,"血量":1,"灵力":2})
 use_card(BARRIER)
 stats(own,[9,7,8],"barrier changes base stats and preserves counters and buffs")
 var enemy=enter("53",1);enemy.minus_counters=1
 stats(enemy,[1,1,2],"later opposing unit preserves negative counters")
 put("field-fdn-016");put("169")
 stats(own,[10,8,10],"other stat auras still add after the barrier")
 e.move_to(e.players[0].field.filter(func(c):return c.card_id=="field-fdn-016")[0],"grave")
 e.move_to(e.players[0].field.filter(func(c):return c.card_id=="169")[0],"grave")
 use_card("140",0,e.ref_target(enemy))
 expect(enemy.owner==0 and enemy.original_owner==1,"control effect changes controller without changing ownership")
 stats(enemy,[3,3,4],"barrier follows the new controller immediately")

func duration_and_recasts():
 for next_player in range(2):
  prepare();e.phase="end";use_card(BARRIER)
  var own=enter("53");var enemy=enter("53",1)
  stats(own,[4,4,4],"friendly entry in end phase")
  stats(enemy,[2,2,2],"opposing entry in end phase")
  var previous_turn=e.turn
  if next_player==0:e.extra_turns.push_front(0)
  e.cleanup_end()
  expect(e.turn==previous_turn+1 and e.active==next_player,"turn completes normally or enters an extra turn")
  stats(own,[2,2,1],"friendly stats restore after cleanup")
  stats(enemy,[2,2,1],"opposing stats restore after cleanup")
  stats(enter("53",1),[2,2,1],"next-turn entry receives no expired barrier")
 prepare();put("70","field",1)
 use_card(BARRIER);use_card(BARRIER,1)
 stats(enter("53"),[2,2,2],"latest opposing barrier controls friendly base stats")
 stats(enter("53",1),[4,4,4],"latest opposing barrier controls opposing base stats")

func synchronized_state():
 prepare();use_card(BARRIER)
 var graph=Codec.capture(e);e=Duel.new();Codec.restore(e,bytes_to_var(var_to_bytes(graph)))
 var own=enter("53");var enemy=enter("53",1)
 stats(own,[4,4,4],"restored aura applies to later friendly entry")
 stats(enemy,[2,2,2],"restored aura applies to later opposing entry")
 var snapshots=[SeatView.build(e,0),SeatView.build(e,1),Observer.build(e)]
 for snapshot in snapshots:
  var remote=Remote.new();remote.apply_snapshot(snapshot)
  expect([remote.stat(remote.find_card(own.uid),"power"),remote.stat(remote.find_card(own.uid),"health"),remote.stat(remote.find_card(own.uid),"spirit")]==[4,4,4],"seat or observer shows later friendly unit stats")
  expect([remote.stat(remote.find_card(enemy.uid),"power"),remote.stat(remote.find_card(enemy.uid),"health"),remote.stat(remote.find_card(enemy.uid),"spirit")]==[2,2,2],"seat or observer shows later opposing unit stats")
