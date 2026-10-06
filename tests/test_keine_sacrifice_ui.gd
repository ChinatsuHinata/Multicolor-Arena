extends "res://tests/support/ui_base.gd"

func stress(top_down: bool):
 clean();view.table.set_top_down_view(top_down)
 var source=put("character-fdf-ex05","field")
 source.entered_turns=0
 var victims=[]
 for i in range(64):
  victims.append(put("roster_token_bat" if top_down else "53","field"))
  put("164","deck",1)
 view.render();await settle()
 var start=Time.get_ticks_msec()
 for victim in victims:
  # Passing the opponent's priority retains each separate activation on the stack.
  if e.priority==1:e.pass_priority(1)
  var target={"selection_id":"keine_devour","picks":[[e.ref_target(victim)],[{"player":1}]]}
  var error=e.commit_extension(0,source.uid,target,[],"keine_devour")
  if not error.is_empty():expect(false,"stress activation: "+error);return
 print("KEINE commit 64 ms=",Time.get_ticks_msec()-start)
 expect(e.stack.size()==64 and victims.all(func(c):return c.zone==("void" if top_down else "grave")),"all sacrifices pay for independent devour abilities")
 start=Time.get_ticks_msec();view.render();await process_frame
 print("KEINE presentation queue=",view.reveal_player.queue.size()," render ms=",Time.get_ticks_msec()-start)
 expect(view.reveal_player.queue.size()<=8,"large simultaneous sacrifices have a bounded presentation queue")
 expect(view.reveal_player.batch_faces.size()<=8,"mass sacrifice uses at most eight travelling card faces")
 expect(is_instance_valid(view.reveal_player.result_label) and view.STAGE.encloses(view.reveal_player.result_label.get_rect()),"mass movement count stays inside the visible battlefield")
 await capture("keine-sacrifice-"+("2d" if top_down else "3d"))
 var deadline=Time.get_ticks_msec()+4000
 while view.revealing() and Time.get_ticks_msec()<deadline:await process_frame
 expect(not view.revealing(),"Android regains control within four seconds after mass sacrifice")
 print("KEINE sacrifice presentation ms=",Time.get_ticks_msec()-start)
 if view.revealing():view.reveal_player.reset();view.render()
 expect(view.stack_panel.tiles.size()==64,"every devour ability remains visible and individually selectable")
 expect(view.reveal_player.movements.size()==(128 if top_down else 64),"all sacrifice movement records survive batching")
 start=Time.get_ticks_msec()
 while not e.stack.is_empty():resolve()
 view.render();await process_frame
 print("KEINE resolve 64 ms=",Time.get_ticks_msec()-start," queue=",view.reveal_player.queue.size())
 deadline=Time.get_ticks_msec()+4000
 while view.revealing() and Time.get_ticks_msec()<deadline:await process_frame
 expect(not view.revealing(),"Android regains control after mass devour resolution")
 if view.revealing():view.reveal_player.reset();view.render()
 expect(e.players[1].exile.size()==64 and e.players[1].exile.all(func(c):return c.get("devour_owner",-1)==0),"each resolved activation exiles exactly one card with its devour owner")
 expect(e.stack.is_empty() and e.pending.is_empty() and not view.modal,"mass devour leaves no stalled choice or overlay")

func presentation_contracts():
 clean()
 var tokens=[]
 for i in range(8):tokens.append(put("roster_token_bat","field"))
 view.render();await settle()
 for i in range(tokens.size()):
  if i==4:
   e.reveal_card(e.players[1].leader);e.show_result("牺牲中的展示")
  e.sacrifice(tokens[i])
 var events=e.presentation_events.duplicate(true);e.presentation_events.clear()
 view.reveal_player.enqueue(events)
 expect(view.reveal_player.queue.map(func(event):return event.type)==["move_batch","reveal","result","move_batch"],"public reveal and result retain their positions between move batches")
 await settle()
 expect(tokens.all(func(c):return c.zone=="void") and e.players[0].grave.is_empty(),"sacrificed tokens vanish after their death events")
 expect(view.reveal_player.movements.size()==16 and view.reveal_player.movements[0].to=="grave" and view.reveal_player.movements[1].to=="void","token death and disappearance each retain their movement record")
 expect(view.reveal_player.completed.size()==1 and view.reveal_player.results.size()==1,"reveal and result still finish between sacrifices")
 expect(not view.revealing() and view.reveal_player.batch_faces.is_empty(),"token sacrifice presentations finish and release their card faces")

 clean()
 for i in range(8):e.move_to(put("53","hand",1),"deck")
 view.render();await process_frame
 expect(not view.reveal_player.batch_faces.is_empty() and view.reveal_player.batch_faces.all(func(card_face):return card_face.texture==app.texture("back")),"batching preserves hidden opponent card faces")
 view.reveal_player.reset();await process_frame
 expect(not view.revealing() and view.reveal_player.batch_faces.is_empty() and view.reveal_player.get_child_count()==0,"reset cancels a running batch without stranded animations")

 clean()
 for i in range(4):e.move_to(put("53","field"),"grave")
 events=e.presentation_events.duplicate(true);e.presentation_events.clear()
 view.is_android=false;view.reveal_player.enqueue(events)
 expect(view.reveal_player.queue.size()==4 and view.reveal_player.queue.all(func(event):return event.type=="move"),"desktop keeps its existing individual move timeline")
 view.reveal_player.reset();view.is_android=true
 view.reveal_player.enqueue(events.slice(0,2))
 expect(view.reveal_player.queue.size()==2 and view.reveal_player.queue.all(func(event):return event.type=="move"),"small Android moves keep their individual animations")
 view.reveal_player.reset()

func run():
 Store.Paths.root_override=ProjectSettings.globalize_path("res://work/keine-sacrifice-ui/"+str(Time.get_ticks_usec()))
 root.content_scale_size=Vector2i(1600,900);root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
 root.size=Vector2i(1280,720)
 app=load("res://main.tscn").instantiate();root.add_child(app);await process_frame
 app.is_android=true;app.layout_dpi_override=240.0;app.refresh_responsive_layout();app.load_test_decks();app.begin_battle(true)
 view=app.duel_view;view.set_process(false);e=view.engine
 await process_frame
 await stress(false)
 await stress(true)
 await presentation_contracts()
 print("KEINE_SACRIFICE_UI: ",checks," checks; ",failures.size()," failures")
 app.queue_free();await process_frame
 quit(0 if failures.is_empty() else 1)
