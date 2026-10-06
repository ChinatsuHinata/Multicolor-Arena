extends "res://tests/support/ui_base.gd"

func frames():
 for i in range(6):await process_frame

func damage_fixture(total: int=3) -> Array:
 clean(false)
 var attacker=put("70","field",0)
 attacker.modifiers=[{"攻击力":total-3}]
 var blockers=[put("70","field",1),put("70","field",1),put("70","field",1)]
 e.combat={"attacker":e.ref_target(attacker),"blockers":blockers.map(func(c):return e.ref_target(c)),"owner":0,"step":"block_window","blocked":true,"strike_round":"normal"}
 e.pending={"kind":"damage_assignment","owner":0,"total":total}
 view.damage_dialog()
 return blockers

func check_assignment(prefix: String):
 var blockers=damage_fixture();await frames()
 var first=str(blockers[0].uid);var last=str(blockers.back().uid)
 expect(view.damage_controls.size()==3 and view.damage_controls.has(last),prefix+" every blocker including the last has allocation controls")
 expect(view.damage_confirm.disabled and view.damage_remaining()==3,prefix+" confirmation starts disabled until all damage is assigned")
 var before=snapshot()
 await click(view.damage_confirm.get_global_rect().get_center())
 view.confirm_damage()
 expect(snapshot()==before and view.modal,prefix+" incomplete confirmation leaves combat and the dialog unchanged")
 await click(view.damage_controls[first].plus.get_global_rect().get_center())
 expect(view.damage_values[first]==1 and view.damage_remaining()==2 and view.damage_confirm.disabled,prefix+" partial allocation keeps confirmation disabled")
 view.toggle_observation();view.toggle_observation()
 expect(view.damage_values[first]==1 and view.damage_confirm.disabled,prefix+" observation preserves the partial allocation and disabled button")
 view.damage_dialog();await frames()
 expect(view.damage_values[first]==1 and view.damage_confirm.disabled,prefix+" rebuilding the dialog preserves incomplete allocation")
 await click(view.damage_controls[last].plus.get_global_rect().get_center())
 await click(view.damage_controls[last].plus.get_global_rect().get_center())
 expect(view.damage_values[last]==2 and view.damage_remaining()==0 and not view.damage_confirm.disabled,prefix+" assigning the full total enables confirmation")
 expect(view.damage_controls.values().all(func(control):return control.plus.disabled),prefix+" no extra damage can be assigned after reaching the total")
 before=snapshot();view.toggle_observation();view.confirm_damage()
 expect(snapshot()==before,prefix+" observing the battlefield prevents submission")
 view.toggle_observation()
 await click(view.damage_controls[last].minus.get_global_rect().get_center())
 expect(view.damage_remaining()==1 and view.damage_confirm.disabled,prefix+" reducing damage disables confirmation again")
 view.confirm_damage()
 expect(snapshot()==before,prefix+" an incomplete callback cannot submit damage")
 await click(view.damage_controls[last].plus.get_global_rect().get_center())
 await click(view.damage_confirm.get_global_rect().get_center())
 expect(e.pending.get("kind","")!="damage_assignment" and blockers[0].damage==1 and blockers[1].damage==0 and blockers[2].damage==2,prefix+" confirmation applies the explicit allocation to every blocker")
 blockers=damage_fixture();await frames();last=str(blockers.back().uid)
 for i in range(3):view.change_damage(last,1)
 view.confirm_damage()
 expect(blockers[0].damage==0 and blockers[1].damage==0 and blockers[2].damage==3,prefix+" all damage can still be assigned to the last blocker")
 blockers=damage_fixture(0);await frames()
 expect(not view.damage_confirm.disabled and view.damage_controls.values().all(func(control):return control.plus.disabled and control.minus.disabled),prefix+" zero total damage is already fully assigned")
 view.confirm_damage()
 expect(e.pending.get("kind","")!="damage_assignment" and blockers.all(func(c):return c.damage==0),prefix+" zero damage can be confirmed without assigning a point")

func run():
 Store.Paths.root_override=ProjectSettings.globalize_path("res://work/combat-damage-assignment/fixtures/"+str(Time.get_ticks_usec()))
 root.mode=Window.MODE_WINDOWED;root.gui_embed_subwindows=true
 root.content_scale_size=Vector2i(1600,900);root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS;root.content_scale_aspect=Window.CONTENT_SCALE_ASPECT_EXPAND
 app=load("res://main.tscn").instantiate();root.add_child(app);await frames();app.load_legacy_test_decks()
 for mobile in [false,true]:
  if is_instance_valid(view):view.queue_free();app.duel_view=null;await frames()
  root.size=Vector2i(1280,720) if mobile else Vector2i(1600,900)
  app.is_android=mobile;app.layout_dpi_override=240.0 if mobile else 0.0
  app.layout_safe_override=Rect2(40,0,1220,704) if mobile else Rect2()
  await frames();app.refresh_responsive_layout();app.begin_battle(true)
  view=app.duel_view;view.set_process(false);e=view.engine;await frames()
  await check_assignment("android" if mobile else "desktop")
 print("COMBAT DAMAGE ASSIGNMENT UI: %d checks; %d failures" % [checks,failures.size()])
 app.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
