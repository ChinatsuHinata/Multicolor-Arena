extends "res://tests/support/rules_base.gd"
const Experiment=preload("res://scripts/ai/local_experiment.gd")
func run():
 var agent=Experiment.new()
 expect(not agent.enabled,"trial opponent defaults to off")
 expect(Experiment.available()==OS.has_feature("editor"),"only source-project editor runtime allows trial AI")
 expect(agent.configure(true,"",true).is_empty() and not agent.enabled,"manual testing never enables automatic trial AI")
 expect(agent.configure(true,"",false,RefCounted.new()).is_empty() and not agent.enabled,"network and replay sessions never enable trial AI")
 if Experiment.available():
  expect(not agent.configure(true,"res://missing-trial-model.json").is_empty() and not agent.enabled,"missing model blocks opt-in instead of silently replacing it")
  var path="res://work/experimental-ai-invalid.json"
  var file=FileAccess.open(path,FileAccess.WRITE);file.store_string('{"schema":"invalid"}');file.close()
  expect(Experiment.read_model(path).has("error"),"invalid JSON model is rejected")
  expect(agent.configure(true,Experiment.default_model_path()).is_empty() and agent.enabled,"current local model or built-in evaluation enables the trial")
  fresh();e.active=1;e.priority=1
  for p in e.players:p.turns=0
  e.players[1].palette=[]
  put("165","hand",1)
  var before=e.revision;var trace=agent.step(e)
  expect(e.revision>before and not trace.get("fallback",true) and trace.get("applied",false),"trial agent actually executes a legal opponent main-phase action")
  expect(trace.has("model_routing"),"live trial decision retains model routing")
  before=e.revision;agent.step(e,true)
  expect(e.revision==before,"manual guard prevents automatic actions even after enabling")
  agent.step(e,false,RefCounted.new())
  expect(e.revision==before,"session guard prevents automatic actions even after enabling")
  fresh();e.active=1;e.priority=1;e.phase="mulligan";e.players[1].mulligan_done=false
  trace=agent.step(e)
  expect(trace.get("fallback",false) and e.players[1].mulligan_done,"trial delegates mulligan to existing AI")
 else:
  expect(agent.configure(true,"res://missing-trial-model.json").is_empty() and not agent.enabled,"release refuses forced opt-in before reading any model")
  expect(Experiment.default_model_path().is_empty() and Experiment.read_model("").has("error"),"release exposes no local trial model loading")
 expect(agent.configure(false,"").is_empty() and not agent.enabled,"disabling trial restores default opponent")
 fresh();e.active=1;e.priority=1
 var before=e.revision;agent.step(e)
 expect(e.revision>before,"disabled trial still lets normal AI act")
 print("Experimental AI: ",checks," checks, ",failures.size()," failures")
 quit(0 if failures.is_empty() else 1)
