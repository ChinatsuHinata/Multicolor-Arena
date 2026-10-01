extends "res://tests/support/rules_base.gd"
const Models=preload("res://scripts/ai/matchup_models.gd")
const Matchup=preload("res://scripts/ai/matchup.gd")
const Value=preload("res://scripts/ai/position_evaluator.gd")
const Observation=preload("res://scripts/ai/observation.gd")
const Agent=preload("res://scripts/ai/decision_agent.gd")
const AI=preload("res://scripts/rules/remilia_aggro_ai.gd")
func run():
 fresh()
 e.players[0].leader=e.make_card("74",0,"leader",true)
 e.players[1].leader=e.make_card("71",1,"leader",true)
 var context=Matchup.identify(e,0)
 expect(context.key=="74::71" and Matchup.identify(e,1).key=="71::74","classification follows observer seat")
 var generic={"schema":Value.SCHEMA,"weights":Value.DEFAULT_WEIGHTS.duplicate(true)}
 var specialist=generic.duplicate(true);specialist.weights.life_margin=99.0;specialist.matchup=context
 var bundle={"schema":Models.SCHEMA,"generic":generic,"specialists":{"74::71":specialist}}
 var selected=Models.select(e,0,bundle)
 expect(selected.source=="specialist" and selected.weights.life_margin==99.0,"known matchup selects specialized weights")
 expect(Models.select(e,1,bundle).source=="generic","other seat cannot reuse opposite perspective model")
 var c=e.players[1].leader;c.copy_original="71";c.card_id="copied_temporary";c.zone="grave";c.owner=0;c.art_id="alternate"
 expect(Matchup.identify(e,0).key==context.key,"copy death control and alternate art preserve original self classification")
 c.card_id="71";c.erase("copy_original");c.owner=1;c.zone="leader"
 var before=JSON.stringify(e.players)
 expect(Observation.build(e,0).matchup.key==context.key and JSON.stringify(e.players)==before,"public observation carries classification without state mutation")
 e.players[1].extra_leaders=[e.make_card("70",1,"leader",true)]
 expect(Matchup.identify(e,0).opponent_key=="70+71" and Models.select(e,0,bundle).source=="generic","dual self is a distinct sorted combination")
 e.players[1].extra_leaders=[]
 specialist.weights.mana=NAN
 expect(Models.select(e,0,bundle).reason=="invalid_specialist" and Models.select(e,0,bundle).weights==generic.weights,"invalid specialized weights fall back to valid generic")
 specialist.weights.mana=1.0;specialist.matchup={"key":"74::70"}
 expect(Models.select(e,0,bundle).reason=="mismatched_specialist","mismatched model identity falls back")
 specialist.matchup=context
 var trace=Agent.step(e,0,AI,bundle)
 expect(trace.model_routing.source=="specialist","experimental decision consumes bundle and records selected model")
 var path="res://work/ai-training/strategic-2026-09-27/matchups/preference-models.json"
 if FileAccess.file_exists(path):
  var trained=Models.load_model(path)
  expect(not trained.is_empty(),"current trained preference bundle loads")
  for key in trained.specialists:
   expect(not Value.validate_weights(trained.specialists[key]).is_empty(),"trained specialist has valid complete features: "+key)
   var ctx=trained.specialists[key].matchup
   e.players[0].leader=e.make_card(ctx.own_leaders[0],0,"leader",true)
   e.players[1].leader=e.make_card(ctx.opponent_leaders[0],1,"leader",true)
   e.players[0].extra_leaders=[];e.players[1].extra_leaders=[]
   for id in ctx.own_leaders.slice(1):e.players[0].extra_leaders.append(e.make_card(id,0,"leader",true))
   for id in ctx.opponent_leaders.slice(1):e.players[1].extra_leaders.append(e.make_card(id,1,"leader",true))
   expect(Models.select(e,0,trained).source=="specialist","trained specialist selected by actual engine leader identity: "+key)
  e.players[1].leader=e.make_card("71",1,"leader",true);e.players[1].extra_leaders=[]
  expect(Models.select(e,0,trained).source=="generic","current sparse opponent uses trained generic")
 print("AI matchups: ",checks," checks, ",failures.size()," failures")
 quit(0 if failures.is_empty() else 1)
