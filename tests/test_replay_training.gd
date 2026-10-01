extends "res://tests/support/rules_base.gd"
const Archive=preload("res://scripts/replay_archive.gd")
const Observer=preload("res://net/observer_projection.gd")
const Training=preload("res://scripts/ai/replay_training.gd")
const Value=preload("res://scripts/ai/position_evaluator.gd")
const AI=preload("res://scripts/rules/remilia_aggro_ai.gd")
const State=preload("res://scripts/ai/simulation_state.gd")
var archive
func record():
 var room={"status":"playing","names":["甲","乙"],"scores":[0,0],"format":1,"round":1}
 archive.record({"game_id":"training-game","sequence":e.revision,"room":room,"projection":Observer.build(e,[],0,true)},0)
func run():
 Store.Paths.root_override=ProjectSettings.globalize_path("res://work/replay-training-test/"+str(Time.get_ticks_usec()))
 fresh();mana()
 put("18","hand");var hidden=put("129","hand",1)
 archive=Archive.new();record()
 var before=JSON.stringify(archive.frame(0))
 e.surrender(1);record()
 var training=Training.new();training.setup(archive)
 var ctx=training.context(0,0)
 expect(ctx.decision_available and not ctx.choices.is_empty(),"recorded clean main phase provides validated next actions")
 expect(ctx.observation.players[1].hand.is_empty() and ctx.observation.players[1].hand_count==1,"training observation hides opposing hand even in full replay")
 expect(not ctx.observation.players[0].has("deck") and not ctx.observation.players[1].has("deck"),"training observations omit deck order")
 expect(ctx.features==Value.features(e,0),"snapshot feature export agrees with runtime evaluator")
 expect(JSON.stringify(archive.frame(0))==before,"candidate simulation never changes replay frame")
 var cast_choice=ctx.choices.filter(func(choice):return choice.action.kind=="cast")
 var pass_choice=ctx.choices.filter(func(choice):return choice.action.kind=="pass")
 expect(not cast_choice.is_empty() and not pass_choice.is_empty(),"teacher and hold-fee actions are available")
 var fields={"comment":"先铺场保住颜色。","recommended_text":"使用光之三妖精，再留费。","confidence":"high","hindsight":false,"teacher_action":cast_choice[0],"comparison_action":pass_choice[0]}
 var saved=training.put(0,0,fields,ctx)
 expect(saved.has("path"),"annotation writes portable JSON")
 var data=JSON.parse_string(FileAccess.get_file_as_string(training.output_path))
 expect(data.annotations[0].outcome==1 and data.annotations[0].status=="terminal","actual terminal result stays separate from teacher preference")
 expect(not JSON.stringify(data).contains('"card_id": "'+hidden.card_id+'"'),"export does not carry unknown opponent identity")
 training.put(0,0,fields,ctx)
 expect(training.annotations.size()==1,"editing same frame and seat replaces rather than duplicates")
 var other=training.context(0,1);training.put(0,1,{"comment":"另一方点评"},other)
 expect(training.annotations.size()==2,"each seat has its own annotation")
 var reopened=Training.new();reopened.setup(archive)
 expect(reopened.find(0,0).get("comment","")==fields.comment,"annotations reload when replay reopens")
 reopened.remove(0,1)
 expect(reopened.annotations.size()==1,"delete affects only selected seat and step")
 # A private choice is stripped by the archive, but the new context marker survives.
 fresh();e.pending={"kind":"effect_choice","owner":0};archive=Archive.new();record()
 training=Training.new();training.setup(archive)
 expect(not training.context(0,0).decision_available,"stripped pending choice cannot masquerade as trainable main action")
 # Legacy files lack the marker and remain useful for notes, never invented legal labels.
 var packet=Observer.build(e,[],0,true);packet.erase("training_context")
 archive=Archive.new();packet.state.pending={};packet.state.phase="main"
 archive.record({"game_id":"legacy","sequence":1,"room":{"status":"playing","names":["甲","乙"],"scores":[0,0],"format":1,"round":1},"projection":packet},0)
 training=Training.new();training.setup(archive)
 expect(not training.context(0,0).decision_available,"legacy snapshots remain text-only without a verified decision marker")
 # A malformed existing sidecar must not be overwritten.
 var f=FileAccess.open(training.output_path,FileAccess.WRITE);f.store_string("{}");f.close()
 reopened=Training.new();reopened.setup(archive)
 expect(not reopened.load_error.is_empty() and reopened.save().has("error") and FileAccess.get_file_as_string(training.output_path)=="{}","malformed annotation is detected and never overwritten")
 computer_comparison_cases()
 random_endpoint_cases()
 print("REPLAY TRAINING: ",checks," checks; ",failures.size()," failures")
 quit(0 if failures.is_empty() else 1)

func computer_comparison_cases():
 fresh();mana()
 var leader=e.make_card(AI.REMILIA,0,"field",true);leader.entered_turns=0
 e.players[0].leader=leader;e.players[0].field.append(leader)
 var gun=put(AI.GUNGNIR,"hand");var enemy=put("70","field",1);var hidden=put("129","hand",1)
 var actual_target=e.ref_target(enemy)
 archive=Archive.new();record();var before=JSON.stringify(archive.frame(0))
 expect(e.commit_cast(0,gun.uid,actual_target,e.payment(0,e.cast_cost(0,gun,actual_target)).plan).is_empty(),"record computer spell with its real target")
 record();e.surrender(1);record()
 var training=Training.new();training.setup(archive)
 var ctx=training.context(0,0);var comparison=ctx.computer_choice
 expect(not comparison.is_empty() and comparison.action.uid==gun.uid and comparison.action.target==actual_target,"actual computer cast recovers exact UID and target from next replay frame")
 expect(comparison.source=="replay_actual" and comparison.recorded_frame==1,"computer comparison retains replay provenance")
 expect(ctx.choices.all(func(choice):return choice.action!=comparison.action),"recorded computer removal is available even outside heuristic candidates")
 expect(comparison.endpoint_complete and not comparison.features.is_empty(),"actual comparison uses the same public endpoint evaluator as recommended actions")
 expect(ctx.observation.players[1].hand.is_empty() and not JSON.stringify(comparison).contains('"card_id":"'+hidden.card_id+'"'),"actual comparison does not include opposing hidden cards")
 expect(JSON.stringify(archive.frame(0))==before,"comparison extraction and evaluation preserve archive bytes")
 var preferred=ctx.choices.filter(func(choice):return choice.action.kind=="pass")[0]
 training.put(0,0,{"comment":"保留神枪","recommended_text":"保留费用","confidence":"high","hindsight":false,"teacher_action":preferred,"comparison_action":comparison},ctx)
 var reopened=Training.new();reopened.setup(archive)
 expect(reopened.find(0,0).comparison_action==Training.normalize_json(comparison.duplicate(true)),"recorded computer comparison persists unchanged in sidecar")
 # An actual pass must be observed, not guessed from an empty next stack.
 fresh();archive=Archive.new();record();e.pass_priority(0);record()
 training=Training.new();training.setup(archive);ctx=training.context(0,0)
 expect(ctx.computer_choice.get("action",{}).get("kind","")=="pass","actual priority pass is recognized from its public state transition")
 fresh();archive=Archive.new();record();e.surrender(1);record()
 training=Training.new();training.setup(archive);ctx=training.context(0,0)
 expect(ctx.computer_choice.is_empty(),"surrender is not invented as a computer pass")
 fresh();var attacker=put("18");archive=Archive.new();record();e.attack(0,attacker.uid);record()
 training=Training.new();training.setup(archive);ctx=training.context(0,0)
 expect(ctx.computer_choice.get("action",{}).get("uid",-1)==attacker.uid and ctx.computer_choice.action.kind=="attack","actual computer attack preserves attacker UID")
 # Preserve a real draw declaration without using the replay's future cards.
 fresh();mana();leader=e.make_card(AI.REMILIA,0,"field",true);leader.entered_turns=0
 e.players[0].leader=leader;e.players[0].field.append(leader)
 var draw=put(AI.DRAW,"hand");var draw_target=e.targets_for(AI.DRAW,0,draw.uid).filter(func(t):return t.get("extra",-1)==2)[0]
 archive=Archive.new();record()
 expect(e.commit_cast(0,draw.uid,draw_target,e.payment(0,e.cast_cost(0,draw,draw_target)).plan).is_empty(),"record actual extra-draw mode")
 record();training=Training.new();training.setup(archive);ctx=training.context(0,0)
 expect(ctx.computer_choice.action.target.extra==2 and "额外抓 2 张" in ctx.computer_choice.label,"computer comparison retains the actual draw mode and displays it")
 expect(not ctx.computer_choice.endpoint_complete and ctx.computer_choice.features.is_empty(),"unknown future draws remain an incomplete preference endpoint")
 expect(training.context(0,1).computer_choice.is_empty(),"wrong evaluation seat cannot borrow active computer's move")
 fresh();archive=Archive.new();record();e.pass_priority(0)
 archive.record({"game_id":"different-game","sequence":e.revision,"room":{"status":"playing","names":["甲","乙"],"scores":[0,0],"format":1,"round":2},"projection":Observer.build(e,[],0,true)},0)
 training=Training.new();training.setup(archive)
 expect(training.context(0,0).computer_choice.is_empty(),"actual action lookup cannot cross a game boundary")
 fresh();attacker=put("character-fdf-065");archive=Archive.new();record();e.attack(0,attacker.uid);record()
 training=Training.new();training.setup(archive);ctx=training.context(0,0)
 expect(ctx.computer_choice.get("action",{}).get("kind","")=="attack","attack triggers do not hide the recorded computer attack")
 # The strategy was changed after this recording: the comparison must still
 # be its actual historical Gungnir, not today's recomputed reservation.
 var read=Archive.read("res://replay/2026-09-27T06-37-25 你 vs 人机_1677616425.mreply")
 expect(read.has("archive"),"original annotated computer replay loads")
 if read.has("archive"):
  training=Training.new();training.archive=read.archive;ctx=training.context(87,1)
  expect(ctx.computer_choice.get("action",{}).get("card_id","")==AI.GUNGNIR and ctx.computer_choice.action.target.uid==7,"real annotated replay offers historical Gungnir against Flandre as comparison")
  var current=State.fork(training.restore(87),1);current.ai_profiles[1]=AI.PROFILE;AI.step(current,1)
  expect(current.players[1].hand.any(func(c):return c.card_id==AI.GUNGNIR),"replay comparison stays historical even when current computer chooses differently")

func random_endpoint_cases():
 fresh();mana()
 var leader=e.make_card(AI.REMILIA,0,"field",true);leader.entered_turns=0
 e.players[0].leader=leader;e.players[0].field.append(leader)
 var wings=put(AI.WINGS,"hand");put("73","field",1);put("spell-fdf-018","field",1)
 archive=Archive.new();record()
 var before=JSON.stringify(archive.frame(0))
 var training=Training.new();training.archive=archive
 var restored=training.restore(0)
 var action={"kind":"cast","uid":wings.uid,"card_id":wings.card_id,"target":{"none":true}}
 var first=Training.evaluate_action(restored,0,action)
 expect(first.endpoint_complete and first.get("rng_policy","")=="public_sequence_seed_v1","random trigger endpoint exports its synthetic scenario provenance")
 var stable=true
 for i in range(4):
  restored=training.restore(0)
  stable=stable and Training.evaluate_action(restored,0,action)==first
 expect(stable,"Wings under Lie Detector reproduces its endpoint across independent replay restores")
 var changed=archive.frame(0);changed.projection.state.players[1].hand=[e.make_card("129",1,"hand")]
 # Same public revision with different hidden identities retains the same seed.
 var other=Archive.new();other.record(changed,0)
 var hidden=Training.new();hidden.archive=other
 expect(hidden.restore(0).rng.seed==training.restore(0).rng.seed,"synthetic replay seed is independent of hidden identities")
 expect(JSON.stringify(archive.frame(0))==before,"random endpoint evaluation preserves the replay bytes")
