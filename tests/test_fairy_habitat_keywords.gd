extends "res://tests/support/rules_base.gd"

func run():
 fresh()
 var habitat=put("character-fdn-007")
 var expected=[]
 for id in e.cards.keys().duplicate():
  var info=e.cards[id]
  if info.kind not in ["单位","自机"] or "妖精" not in info.race:continue
  put(id)
  for keyword in info.keywords:
   if keyword not in expected:expected.append(keyword)
 e.judge()
 expected.sort()
 var inherited=e.cards[habitat.card_id].keywords.duplicate();inherited.sort()
 expect(expected==inherited,"habitat inherits every printed fairy keyword")
 for keyword in expected:
  expect(e.Extra.keyword(e,habitat,keyword),"inherited keyword is recognized by rules: "+keyword)
 expect(expected.has("疾行") and expected.has("英勇") and expected.has("结晶") and expected.has("吸血1") and expected.has("威吓") and expected.has("奇迹") and expected.has("极彩"),"all seven current fairy keywords are covered")
 expect(e.Pack.chromatic(e,habitat,0),"inherited chromatic keyword is recognized")

 fresh();habitat=put("character-fdn-007");var buffed_fairy=put("13")
 e.apply_turn_buff(e.ref_target(buffed_fairy),{"疾行":true,"英勇":true});e.judge()
 expect(e.has_haste(habitat) and e.Extra.keyword(e,habitat,"英勇"),"habitat also inherits currently granted fairy keywords")
 buffed_fairy.modifiers.clear();e.judge()
 expect(not e.has_haste(habitat) and not e.Extra.keyword(e,habitat,"英勇"),"inherited temporary keywords end with the source buff")
 buffed_fairy.extra_keywords=["威吓"];e.judge()
 expect(e.Extra.keyword(e,habitat,"威吓"),"habitat inherits an extra keyword granted to a fairy")
 buffed_fairy.extra_keywords=[];e.judge()
 expect(not e.Extra.keyword(e,habitat,"威吓"),"habitat loses an extra keyword when its fairy loses it")
 buffed_fairy.extra_keywords=["不占战场格"];e.judge()
 expect(e.Extra.keyword(e,habitat,"不占战场格"),"habitat inherits an explicit no-slot keyword")
 buffed_fairy.extra_keywords=[];e.judge()
 expect(not e.Extra.keyword(e,habitat,"不占战场格"),"habitat loses the explicit no-slot keyword with its fairy")

 fresh();habitat=put("character-fdn-007");put("13");var haste_aura=put("93")
 haste_aura.leader=true;e.judge()
 expect("疾行" in e.cards[habitat.card_id].keywords,"habitat inherits haste granted to a fairy by an aura")
 e.move_to(haste_aura,"grave");e.judge()
 expect("疾行" not in e.cards[habitat.card_id].keywords,"inherited aura haste ends when its source leaves")

 fresh();habitat=put("character-fdn-007");var haste=put("34");put("character-lof-001")
 habitat.entered_turns=e.players[0].turns;e.judge()
 expect(e.has_haste(habitat) and not e.summoning_sick(habitat) and e.can_attack(0,habitat.uid),"inherited haste lets newly entered habitat attack")
 e.attack(0,habitat.uid)
 expect(habitat.tapped and habitat.get("brave_attack_turn",-1)==e.turn,"inherited brave records habitat's attack")
 e.end_combat();e.pass_priority(0);e.pass_priority(1)
 expect(e.phase=="end" and not habitat.tapped,"inherited brave untaps habitat at end step")
 e.move_to(haste,"grave");e.judge()
 expect(not e.has_haste(habitat),"haste ends after the sole haste fairy leaves")

 fresh();habitat=put("character-fdn-007");put("character-fdn-014");e.judge()
 var life=e.players[0].life;e.combat_hit(habitat,{"player":1},1)
 expect(e.players[0].life==life+1,"inherited lifesteal 1 grants life on combat damage")

 fresh();habitat=put("character-fdn-007");put("character-fdn-068")
 var blocker_a=put("50","field",1);var blocker_b=put("51","field",1)
 e.judge();e.attack(0,habitat.uid);e.pass_priority(e.priority);e.pass_priority(e.priority)
 expect(e.pending.get("kind","")=="block" and e.Extra.keyword(e,habitat,"威吓"),"inherited menace reaches the block decision")
 e.block([blocker_a.uid])
 expect(e.pending.get("kind","")=="block","one blocker cannot block inherited menace")
 e.block([blocker_a.uid,blocker_b.uid])
 expect(e.pending.is_empty(),"two blockers can block inherited menace")

 fresh();habitat=put("character-fdn-007");put("character-fdn-006")
 var palette=put("164","palette");palette.tapped=true;e.judge()
 e.move_to(habitat,"grave");e.pump_choices()
 expect(e.pending.get("kind","")=="effect_choice" and e.pending.trigger.effect=="crystal","inherited crystal triggers when habitat dies")
 if e.pending.get("kind","")=="effect_choice":
  e.choose_effect(e.pending.options[0]);settle()
  expect(habitat.zone=="palette" and not habitat.tapped and palette.zone=="grave","inherited crystal exchanges habitat with tapped palette")

 print("FAIRY_HABITAT_KEYWORDS: ",checks," checks; ",failures.size()," failures")
 quit(1 if not failures.is_empty() else 0)
