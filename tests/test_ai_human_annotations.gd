extends "res://tests/support/rules_base.gd"
## Current replay decisions and nearby counterfactuals from human commentary.
const AI=preload("res://scripts/rules/remilia_aggro_ai.gd")
const Archive=preload("res://scripts/replay_archive.gd")
const Training=preload("res://scripts/ai/replay_training.gd")
const State=preload("res://scripts/ai/simulation_state.gd")
var archive
func load_replay(file: String):
 var result=Archive.read("res://replay/"+file)
 expect(result.has("archive"),"annotated replay loads: "+file)
 archive=result.archive
func restore(index: int):
 var training=Training.new();training.archive=archive
 e=State.fork(training.restore(index),1);e.ai_profiles=["",AI.PROFILE]
func possession():
 for i in range(8):
  if e.phase=="possession":break
  e.pass_priority(e.priority)
 e.pending={"kind":"possession","owner":1}
func offered(id: String) -> Dictionary:
 var found=e.players[1].hand.filter(func(c):return c.card_id==id)
 return found[0] if not found.is_empty() else {}
func run():
 load_replay("2026-09-27T03-07-55 你 vs 人机_1016025273.mreply")
 restore(3);possession();e.ai_possession(1)
 expect(not offered(AI.GUNGNIR).is_empty() and offered("character-fdf-065").is_empty(),"opening possession keeps Gungnir and buries uncastable Skyfire")
 restore(119)
 expect(AI.settle_sim(e,1),"draw annotation reaches a resolved main-phase decision")
 var draw=offered(AI.DRAW);var target=AI.draw_target(e,1,draw)
 expect(not target.is_empty(),"five-card hand can use idle two mana for role draw")
 AI.step(e,1)
 expect(e.stack.any(func(s):return s.get("card",{}).get("card_id","")==AI.DRAW),"live AI spends spare mana on the annotated role draw")
 load_replay("2026-09-27T06-37-25 你 vs 人机_1677616425.mreply")
 restore(87)
 var gun=offered(AI.GUNGNIR);var flandre=e.find_card(7)
 expect(AI.upcoming_gungnir_value(e,1)>=AI.REIMU_PRIORITY,"possible fourth palette resource forecasts next-turn public Reimu")
 expect(not AI.use_gungnir(e,1,flandre,true),"Gungnir is retained through the end of turn instead of shooting Flandre")
 AI.step(e,1)
 expect(gun.zone=="hand" and e.payment(1,{"红":1,"黑":1}).ways>0,"annotated Flandre position preserves both gun and response mana")
 restore(304);possession();e.ai_possession(1)
 expect(not offered(AI.AUTUMN).is_empty() and offered(AI.DRAW).is_empty(),"turn fourteen possession exchanges stocked draw rather than live Autumn removal")
 expect(AI.finish_possession_sim(e,1),"improved turn fourteen possession reaches main phase legally")
 var autumn=offered(AI.AUTUMN);var reimu=e.players[0].leader
 target=AI.removal_target(e,1,autumn,[reimu])
 expect(target.get("uid",-1)==reimu.uid and target.get("sacrifice",{}).get("uid",-1)==59,"Autumn trades bound Lily Black for five-health Reimu on a two-unit board")
 AI.step(e,1)
 expect(e.stack.any(func(s):return s.get("card",{}).get("card_id","")==AI.AUTUMN),"corrected possession leads to Autumn before expansion")
 expect(AI.settle_sim(e,1) and e.players[0].leader.zone!="field" and e.find_card(59).zone=="grave" and e.players[1].leader.zone=="field","Autumn resolves the real sacrifice and removes Reimu while retaining Remilia")
 # Revisit the turn-sixteen exchange rather than pretending a palette card
 # can be retrieved during main phase after the historical wrong exchange.
 var frame=350
 while frame>304:
  var raw=archive.frame(frame).projection.state
  if raw.turn==16 and raw.phase=="possession":break
  frame-=1
 restore(frame);possession();e.ai_possession(1)
 expect(not offered(AI.AUTUMN).is_empty(),"turn sixteen possession retrieves palette Autumn for the visible Reimu")
 expect(AI.finish_possession_sim(e,1),"turn sixteen improved possession reaches main phase")
 AI.step(e,1)
 expect(e.stack.any(func(s):return s.get("card",{}).get("card_id","")==AI.AUTUMN),"turn sixteen attempts effective Autumn removal before ordinary pressure")
 load_replay("2026-09-27T06-55-19 你 vs 人机_2285646244.mreply")
 restore(88);gun=offered(AI.GUNGNIR)
 AI.step(e,1)
 expect(gun.zone=="hand" and e.payment(1,{"红":1,"黑":1}).ways>0,"annotated Momiji position retains two mana for next-turn Reimu")
 # Mutation of unknown opposing identities cannot alter the reservation.
 restore(88);var reserve=AI.gungnir_reserve_score(e,1)
 for c in e.players[0].hand:c.card_id=AI.GUNGNIR
 e.ai_memory[1]={}
 expect(AI.gungnir_reserve_score(e,1)==reserve,"reservation depends on public leader and resources, not hidden hand identities")
 print("Human annotation AI: ",checks," checks, ",failures.size()," failures")
 quit(0 if failures.is_empty() else 1)
