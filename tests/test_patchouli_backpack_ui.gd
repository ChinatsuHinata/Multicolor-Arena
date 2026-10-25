extends "res://tests/support/ui_base.gd"

func show_board():
 e.presentation_events.clear();view.reveal_player.reset();view.picker.reset();view.render()

func confirm(label: String):
 var button=find_button(view.ui,"确定")
 expect(button!=null and not button.disabled,label+" confirmation is available")
 if button!=null and not button.disabled:button.pressed.emit()

func check_refusal(platform: String):
 for free_payment in [false,true]:
  for kind in ["player","unit"]:
   clean(free_payment);e.debug_free_payment=free_payment
   var label=platform+" "+kind+" free="+str(free_payment)+": "
   put("character-fdf-119","field")
   var victim=put("53","field",1);victim.plus_counters=10
   put("item-ucs-012","field",1)
   for i in range(2):put("167","palette")
   var drawn=put("164","deck")
   var spell=put("spell-fdf-077","hand");var target={"none":true}
   expect(e.commit_cast(0,spell.uid,target,e.payment(0,e.cast_cost(0,spell,target)).plan).is_empty(),label+"cast a character spell without a target")
   show_board()
   expect(e.pending.get("trigger",{}).get("effect","")=="character-fdf-119",label+"Patchouli requests her damage target")
   view.choose_target({"player":1} if kind=="player" else e.ref_target(victim))
   confirm(label+"damage target")
   expect(e.pending.is_empty() and e.stack.back().effect=="backpack_tax",label+"target confirmation triggers Backpack")
   resolve();show_board()
   expect(e.pending.get("trigger",{}).get("effect","")=="backpack_pay",label+"Backpack displays its payment choice")
   var decline=find_button(view.ui,"不支付")
   expect(decline!=null,label+"the explicit refusal button is shown")
   if decline==null:continue
   decline.pressed.emit()
   expect(view.picker.ready() and not view.picker.option().has("color"),label+"refusal selects an unpaid decision")
   confirm(label+"refusal")
   expect(e.pending.is_empty() and e.stack.size()==1 and e.stack[0].kind=="card",label+"refusal counters Patchouli's damage ability")
   resolve()
   expect(e.players[1].life==20 and victim.damage==0,label+"neither the player nor the unit takes damage")
   expect(spell.zone=="grave" and drawn.zone=="hand",label+"the original draw spell still resolves")

func run():
 Store.Paths.root_override=ProjectSettings.globalize_path("res://work/patchouli-backpack-ui/"+str(Time.get_ticks_usec()))
 root.content_scale_size=Vector2i(1600,900);root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
 app=load("res://main.tscn").instantiate();root.add_child(app);await process_frame
 app.load_test_decks()
 for android in [false,true]:
  if is_instance_valid(view):view.queue_free();app.duel_view=null;await process_frame
  app.is_android=android;app.layout_dpi_override=240.0 if android else 0.0
  root.size=Vector2i(1280,720) if android else Vector2i(1600,900)
  await process_frame;app.refresh_responsive_layout();app.begin_battle(true)
  view=app.duel_view;view.set_process(false);view.fast_mode=true;e=view.engine
  await process_frame
  check_refusal("Android" if android else "Desktop")
 print("PATCHOULI_BACKPACK_UI: %d checks; %d failures" % [checks,failures.size()])
 app.queue_free();await process_frame
 quit(0 if failures.is_empty() else 1)
