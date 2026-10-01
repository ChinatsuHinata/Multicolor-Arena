extends "res://tests/support/ui_base.gd"
const Experiment=preload("res://scripts/ai/local_experiment.gd")
func run():
 Store.Paths.root_override=ProjectSettings.globalize_path("res://work/experimental-ai-ui/"+str(Time.get_ticks_usec()))
 DirAccess.make_dir_recursive_absolute(Store.Paths.root())
 app=load("res://main.tscn").instantiate();app.settings_path=Store.Paths.root().path_join("settings.json");root.add_child(app);await process_frame
 expect(not app.experimental_ai,"local trial starts unchecked")
 app.setup()
 var toggle=app.screen.get_node_or_null("ExperimentalAI")
 expect((toggle!=null)==Experiment.available(),"trial entry exists only in source-project test client")
 if Experiment.available():
  toggle.button_pressed=true
  expect(app.experimental_ai,"trial toggle enables opt-in")
  var picker=find_button(app.screen,"选择模型…")
  expect(picker!=null and not picker.disabled,"enabled trial offers local model selection")
  app.debug_mode=true;app.setup();toggle=app.screen.get_node("ExperimentalAI")
  expect(toggle.disabled and not toggle.button_pressed,"manual mode disables automatic trial toggle")
  app.begin_battle(true);view=app.duel_view;view.set_process(false);await settle()
  expect(not view.experiment_agent.enabled,"manual battle ignores saved trial selection")
  app.debug_mode=false
  var selected_model=app.experiment_model_path
  app.experiment_model_path="res://missing-trial-model.json";app.setup();app.begin_battle(true)
  expect(app.page=="setup","invalid selected model prevents starting a misleading normal battle")
  for child in app.get_children():
   if child is AcceptDialog:child.queue_free()
  await process_frame
  app.experiment_model_path=selected_model
 else:
  expect(find_button(app.screen,"选择模型…")==null,"release has no model picker")
  app.experimental_ai=true;app.experiment_model_path="res://missing-trial-model.json"
 app.begin_battle(true);view=app.duel_view;view.set_process(false);await settle()
 expect(view.experiment_agent.enabled==Experiment.available(),"live battle applies source-only runtime guard")
 expect(view.player_caption(1)==("试验 AI" if Experiment.available() else "人机"),"battle labels trial opponent only when active")
 if Experiment.available():
  e=view.engine;clean();view.fast_mode=true;e.active=1;e.priority=1
  for player in e.players:player.turns=0
  put("165","hand",1)
  var before=e.revision;view._process(1.0)
  expect(e.revision>before and not view.experiment_agent.last_decision.get("fallback",true),"live opponent timer calls the trial agent for main-phase decisions")
  await settle()
  app.setup();await process_frame
  await capture("experimental-ai-setup")
 app.experimental_ai=false;app.begin_battle(true);view=app.duel_view;view.set_process(false);await settle()
 expect(not view.experiment_agent.enabled and view.player_caption(1)=="人机","unchecked trial uses normal opponent")
 app.queue_free();await process_frame
 print("Experimental AI UI: ",checks," checks, ",failures.size()," failures")
 quit(0 if failures.is_empty() else 1)
