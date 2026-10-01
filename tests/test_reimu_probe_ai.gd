extends "res://tests/support/rules_base.gd"
const AI=preload("res://scripts/rules/remilia_aggro_ai.gd")
const Counter=preload("res://scripts/ai/release_counterplay.gd")
const GameEnv=preload("res://scripts/ai/game_environment.gd")
const Training=preload("res://scripts/ai/replay_training.gd")
const Archive=preload("res://scripts/replay_archive.gd")
const State=preload("res://scripts/ai/simulation_state.gd")

func setup(opponent: String="character-rei-001"):
 fresh()
 e.players[0].leader=e.make_card(AI.REMILIA,0,"field",true)
 e.players[0].leader.entered_turns=0;e.players[0].field.append(e.players[0].leader)
 e.players[1].leader=e.make_card(opponent,1,"field",true)
 e.players[1].leader.entered_turns=0;e.players[1].field.append(e.players[1].leader)
 e.ai_profiles=[AI.PROFILE,""];e.ai_memory=[{},{}]
 e.players[1].life=40
 for i in range(3):put("165","palette");put("168","palette")

func finish_combat():
 for i in range(100):
  e.pump_choices()
  if not e.pending.is_empty():
   match e.pending.kind:
    "damage_assignment":e.combat_damage(AI.damage_allocation(e,e.find_card(e.combat.attacker.uid),e.combat.blockers.map(func(t):return e.find_card(t.uid)),e.pending.total))
    "leader_return":e.choose_return(false)
    "trigger_order":e.choose_trigger_order(0)
    "effect_choice":e.choose_effect(e.pending.options[0])
    _:return
  elif e.combat.is_empty() and e.stack.is_empty():e.priority=0;return
  else:e.pass_priority(e.priority)
 expect(false,"combat completes")

func make_bat():
 var c=e.Roster.create_token(e,0,"bat",1,["黑"])
 c.entered_turns=0
 return c

func run():
 gun_guards()
 probe_and_finish()
 night_trades()
 recorded_positions()
 print("Reimu probe AI: ",checks," checks, ",failures.size()," failures")
 quit(0 if failures.is_empty() else 1)

func gun_guards():
 for id in ["70","character-rei-001"]:
  setup(id);put("field-fdn-016","field",1)
  var enemy=e.players[1].leader;var gun=put(AI.GUNGNIR,"hand");var target=e.ref_target(enemy)
  expect(Counter.reimu_probe_scope(e,0),"both Reimu entries enable probe tactics: "+id)
  expect(e.stat(enemy,"health")==5,"Prayer aura makes Reimu five health: "+id)
  expect(not AI.cast(e,0,gun,target,false) and not AI.execute(e,0,{"kind":"cast","uid":gun.uid,"card_id":gun.card_id,"target":target}),"normal and cached casts refuse partial Gungnir: "+id)
  expect(not AI.pressure_execute(e,0,{"kind":"cast","uid":gun.uid,"card_id":gun.card_id,"target":target}) and not AI.use_gungnir(e,0,enemy,false,true),"pressure and rescue cannot bypass Reimu finish guard: "+id)
  expect(AI.search_actions(e,0).all(func(a):return a.get("card_id","")!=AI.GUNGNIR or a.target.get("uid",-1)!=enemy.uid),"lethal search excludes oversized Reimu target: "+id)
  var env=GameEnv.new();env.setup(e)
  var policy=env.policy_actions()
  expect(env.legal_actions().actions.all(func(row):return row.id not in policy.ids or row.action.get("card_id","")!=AI.GUNGNIR or row.action.target.get("uid",-1)!=enemy.uid),"experimental policy excludes same partial hit: "+id)
  enemy.damage=1
  expect(AI.gungnir_target_allowed(e,0,enemy),"one real damage opens four-health finish: "+id)
  enemy.wards=[{"amount":1,"turn":-1}]
  expect(not AI.gungnir_target_allowed(e,0,enemy),"four remaining health plus ward still cannot be finished: "+id)
  enemy.wards=[]
  expect(AI.cast(e,0,gun,e.ref_target(enemy),false),"damaged Reimu accepts actual finishing Gungnir: "+id)
  settle();expect(enemy.zone!="field","finishing Gungnir really removes Reimu: "+id)
 setup();var broken=Counter.library().duplicate(true);broken.entries["74::character-rei-001"].policy.reimu_probe="yes"
 expect(Counter.select(e,0,broken).reason=="invalid_counterplay","probe flag must be boolean")
 setup("71");var reimu=put("70","field",1);put("field-fdn-016","field",1)
 expect(not AI.gungnir_target_allowed(e,0,reimu),"oversized Reimu remains protected from partial gun even in another leader's deck")

func probe_and_finish():
 setup();put("field-fdn-016","field",1);var enemy=e.players[1].leader
 var bat=make_bat();var gun=put(AI.GUNGNIR,"hand")
 var before=e.source_resources(0).size()
 e.ai_step(0)
 expect(e.stack.is_empty() and e.combat.get("attacker",{}).get("uid",-1)==bat.uid,"AI probes five-health Reimu with the bat before spending gun")
 expect(gun.zone=="hand" and e.source_resources(0).size()==before,"probe preserves Gungnir and its payment")
 for i in range(8):
  e.pump_choices()
  if e.pending.get("kind","")=="block":break
  e.pass_priority(e.priority)
 e.block([enemy.uid]);finish_combat()
 expect(enemy.zone=="field" and enemy.damage==2 and bat.zone!="field","actual bat combat leaves Reimu within Gungnir range")
 e.ai_step(0)
 expect(e.stack.size()==1 and e.stack[0].card.card_id==AI.GUNGNIR and e.stack[0].target.uid==enemy.uid,"AI finishes the combat-damaged Reimu with its retained gun")
 settle();expect(enemy.zone!="field","probe plus Gungnir truly removes the core")
 setup();put("field-fdn-016","field",1);enemy=e.players[1].leader
 bat=make_bat();var second=make_bat();gun=put(AI.GUNGNIR,"hand")
 e.ai_step(0)
 for i in range(8):
  e.pump_choices()
  if e.pending.get("kind","")=="block":break
  e.pass_priority(e.priority)
 e.block([]);finish_combat();e.ai_step(0)
 expect(enemy.damage==0 and gun.zone=="hand" and e.combat.get("attacker",{}).get("uid",-1)==second.uid,"declined block causes another small probe, never imaginary damage plus gun")
 setup();put("field-fdn-016","field",1);put(AI.LILY).tapped=true
 expect(AI.reimu_probe_choice(e,0).is_empty(),"tapped small unit cannot be invented as a probe")

func empower():
 var c=e.players[0].leader
 var night=put(AI.NIGHT,"hand")
 expect(AI.cast(e,0,night,e.ref_target(c)),"actual Night King cast is legal")
 settle();e.priority=0
 return c

func night_trades():
 for opponent in ["character-rei-001","71"]:
  setup(opponent);var enemy=e.players[1].leader
  enemy.base_override={"power":8,"health":5}
  var rem=empower()
  expect(AI.fight(e,rem,[enemy]).attacker_dead and enemy.uid in AI.fight(e,rem,[enemy]).dead,"fixture trades Night Remilia for opposing core: "+opponent)
  expect(AI.attack_allowed(e,rem) and AI.attack_choice(e,0).get("uid",-1)==rem.uid,"Night permits direct core exchange without small units: "+opponent)
  e.ai_step(0)
  expect(e.combat.get("attacker",{}).get("uid",-1)==rem.uid,"authored AI actually declares Night core exchange: "+opponent)
  for i in range(8):
   e.pump_choices()
   if e.pending.get("kind","")=="block":break
   e.pass_priority(e.priority)
  e.block([enemy.uid]);finish_combat()
  expect(rem.zone!="field" and enemy.zone!="field","real Night combat exchanges Remilia for opposing core: "+opponent)
 setup();put("field-fdn-016","field",1);var enemy=e.players[1].leader
 var momiji=put("character-fdf-101","field",1);var rem=empower()
 var allocated=AI.damage_allocation(e,rem,[momiji,enemy],e.stat(rem,"power"))
 expect(allocated[str(enemy.uid)]==5 and allocated[str(momiji.uid)]==2,"Night double-block damage prioritizes killing Reimu over smaller Momiji")
 expect(AI.attack_allowed(e,rem),"double-block death is permitted when Reimu is truly exchanged")
 var bat=make_bat()
 expect(AI.attack_choice(e,0).get("uid",-1)==bat.uid,"Night can still probe cheaply before direct exchange")
 setup();enemy=e.players[1].leader;enemy.base_override={"power":8,"health":5}
 rem=e.players[0].leader;rem.modifiers=[{"攻击力":4,"血量":4,"灵力":3,"歼灭":true}]
 expect(not AI.attack_allowed(e,rem),"same stats without actual Night lock do not allow sacrificial Remilia")
 setup();enemy=e.players[1].leader;enemy.tapped=true;rem=empower()
 var body=put(AI.FAIRY,"field",1);body.base_override={"power":8,"health":5}
 expect(not AI.attack_allowed(e,rem),"Night does not sacrifice Remilia for a noncore body")
 setup();enemy=e.players[1].leader;enemy.base_override={"power":8,"health":5};enemy.wards=[{"amount":4,"turn":-1}];rem=empower()
 expect(not AI.attack_allowed(e,rem),"warded core surviving the exchange keeps Remilia protected")
 setup();enemy=e.players[1].leader;enemy.base_override={"power":8,"health":5};rem=empower()
 body=put(AI.FAIRY,"field",1);body.base_override={"power":8,"health":8}
 expect(not AI.attack_allowed(e,rem),"an alternative lethal block with no dead core rejects direct exchange")

func recorded_positions():
 var path="res://replay/2026-09-27T14-19-18 你 vs 人机_396434885.mreply"
 if not FileAccess.file_exists(path):return
 var loaded=Archive.read(path);expect(not loaded.has("error"),"latest reported replay loads")
 if loaded.has("error"):return
 var training=Training.new();training.setup(loaded.archive,path)
 e=State.fork(training.restore(243),1);e.ai_profiles=["",AI.PROFILE]
 e.ai_step(1)
 expect(e.stack.is_empty() and e.combat.get("attacker",{}).get("uid",-1)==104 and e.find_card(83).zone=="hand","reported Gungnir window now probes with bat and retains gun")
 e=State.fork(training.restore(187),1);e.ai_profiles=["",AI.PROFILE]
 e.ai_step(1)
 expect(e.combat.get("attacker",{}).get("uid",-1)==104,"reported Night empty turn now begins with bat probe")
