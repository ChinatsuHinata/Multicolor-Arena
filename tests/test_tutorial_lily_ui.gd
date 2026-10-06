extends "res://tests/support/ui_base.gd"
const COURSE="res://data/tutorial/beginner/t2.json"

func frames(count: int=6):
 for i in range(count):await process_frame

func check_wrong_possession_ui(scene,flow,scenario: String,step: String,palette_alias: String):
 var reason=flow.load_scenario(scenario)
 expect(reason.is_empty(),step+" scenario loads for UI possession")
 if not reason.is_empty():return
 view=scene.surface
 var e=flow.adapter.engine
 for i in range(8):
  if e.phase=="possession":break
  e.pass_priority(e.priority)
 flow.adapter.reset_observation()
 flow.enter(step)
 await frames()
 var palette=flow.adapter.entity(palette_alias)
 var aurora=e.players[0].hand.back()
 expect(e.pending.get("kind","")=="possession" and aurora.card_id=="143" and view.tutorial_controls_enabled,step+" reaches selectable drawn Aurora")
 if e.pending.get("kind","")!="possession" or aurora.card_id!="143":return
 var notices=[]
 flow.task_failed.connect(func(message):notices.append(message),CONNECT_ONE_SHOT)
 view.selection=[palette.uid,aurora.uid]
 view.confirm_possession()
 await frames()
 expect(notices.size()==1 and flow.current_step==step and e.players[0].possession_count==0,step+" UI Aurora possession fails and restores")
 expect(e.find_card(aurora.uid).zone=="hand" and flow.adapter.entity(palette_alias).zone=="palette",step+" restores both cards after failure")

func run():
 var fixture="res://work/tutorial-lily-ui-fixture-"+str(Time.get_ticks_usec())
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(fixture))
 Store.Paths.root_override=ProjectSettings.globalize_path(fixture)
 var settings=fixture.path_join("settings.json")
 var file=FileAccess.open(settings,FileAccess.WRITE)
 file.store_string('{"fullscreen":false}')
 file.close()
 root.mode=Window.MODE_WINDOWED
 root.size=Vector2i(1600,900)
 root.content_scale_size=Vector2i(1600,900)
 root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
 app=load("res://main.tscn").instantiate()
 app.settings_path=settings
 app.account_session_path=fixture.path_join("account.json")
 root.add_child(app)
 await frames()
 app.begin_tutorial(COURSE)
 await frames(12)
 var scene=app.screen.get_child(0)
 var flow=scene.runtime
 flow.enter("d7")
 flow.next()
 await frames()
 view=scene.surface
 var e=flow.adapter.engine
 var lily=flow.adapter.entity("lily_black")
 expect(flow.current_step=="r2" and view.tutorial_runtime==flow,"battlefield reaches Lily task")
 expect(not flow.allows_turn_end() and e.tutorial_turn_end_blocked,"task defaults to blocking turn end in the engine")
 var before_turn_end=e.revision
 e.pass_priority(e.priority)
 expect(e.revision==before_turn_end and e.phase=="main" and flow.current_step=="r2","direct engine pass cannot end an unfinished task turn")
 e.advance_phase()
 expect(e.revision==before_turn_end and e.phase=="main","direct phase advance cannot bypass the task turn-end rule")
 view.render()
 var end_button=view.hud.find_child("MainPhaseEnd",true,false)
 expect(end_button!=null and end_button.disabled,"battlefield disables turn end during a task")
 var plan=e.payment(0,e.cast_cost(0,lily)).plan
 expect(flow.adapter.submit(0,{"name":"commit_cast","args":[lily.uid,{},plan]}).is_empty(),"Lily cast submitted")
 for i in range(10):flow.tick()
 expect(e.priority==0 and e.stack.size()==1,"opponent responds to cast")
 expect(flow.adapter.submit(0,{"name":"pass_priority","args":[]}).is_empty(),"Lily resolves to color choice")
 for i in range(10):flow.tick()
 expect(e.pending.get("trigger",{}).get("effect","")=="lily_color" and flow.running,"choice is available without tutorial error")
 view.sync_picker()
 var revision=e.revision
 view.inline_pick({"kind":"mode","value":"蓝"})
 expect(view.picker.ready(),"blue option is selectable")
 view.confirm_trigger()
 expect(e.revision==revision and e.pending.get("kind","")=="effect_choice" and flow.current_step=="r2" and view.tutorial_controls_enabled,"UI blocks blue but leaves selection active")
 view.picker.path=[]
 view.inline_pick({"kind":"mode","value":"红"})
 expect(view.picker.ready(),"red option is selectable")
 view.confirm_trigger()
 expect(e.revision>revision and e.pending.is_empty() and flow.running,"UI accepts red through tutorial runtime")
 for i in range(10):flow.tick()
 expect(e.priority==0 and flow.opponent.counts.get("pass_responses",0)==2,"opponent resumes after red choice")
 expect(flow.adapter.submit(0,{"name":"pass_priority","args":[]}).is_empty(),"color trigger resolves")
 for i in range(10):flow.tick()
 expect(flow.current_step=="d8" and "红" in lily.get("color_counters",[]) and flow.last_error.is_empty(),"UI path advances to next lesson step")
 await check_wrong_possession_ui(scene,flow,"second_main","r3","black_resource")
 await check_wrong_possession_ui(scene,flow,"third_main","r5","new_resource")
 app.queue_free()
 await frames()
 print("TUTORIAL LILY UI: %d checks; %d failures" % [checks,failures.size()])
 quit(0 if failures.is_empty() else 1)
