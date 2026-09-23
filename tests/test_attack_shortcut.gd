extends "res://tests/test_v092.gd"

func press_a(echoed: bool=false):
 var event=InputEventKey.new()
 event.keycode=KEY_A
 event.physical_keycode=KEY_A
 event.unicode=97
 event.pressed=true
 event.echo=echoed
 root.push_input(event,true)
 await process_frame
 event=event.duplicate()
 event.pressed=false
 event.echo=false
 root.push_input(event,true)
 await process_frame

func run():
 Store.Paths.root_override=ProjectSettings.globalize_path("res://work/test-attack-shortcut/"+str(Time.get_ticks_usec()))
 app=load("res://main.tscn").instantiate()
 root.add_child(app)
 await process_frame
 app.load_legacy_test_decks()
 app.begin_battle(true)
 view=app.duel_view
 view.set_process(false)
 e=view.engine

 clean()
 var attacker=put("53","field")
 view.render()
 await settle()
 var before=snapshot()
 await press_a()
 expect(snapshot()==before and e.combat.is_empty(),"A does not choose an unselected unit")
 await click(point(attacker.uid))
 var attack_button=find_button(view.ui,"攻击")
 expect(view.attack_preview_uid==attacker.uid and attack_button!=null and attack_button.tooltip_text=="快捷键：A","selected attackable unit shows the A shortcut")
 before=snapshot()
 await press_a(true)
 expect(snapshot()==before and view.attack_preview_uid==attacker.uid,"repeated A key does not declare an attack")
 await press_a()
 expect(e.combat.get("attacker",{}).get("uid",0)==attacker.uid and attacker.tapped and view.attack_preview_uid==0,"A confirms the selected unit's attack once")

 clean()
 attacker=put("53","field")
 view.render()
 await settle()
 await click(point(attacker.uid))
 before=snapshot()
 view.settings_menu()
 await press_a()
 expect(snapshot()==before and view.attack_preview_uid==attacker.uid,"A does not attack behind settings")
 view.close_overlay()
 attacker.tapped=true
 before=snapshot()
 await press_a()
 expect(snapshot()==before and e.combat.is_empty(),"A does not attack with a unit that became ineligible")

 clean()
 e.cards["53"]=e.cards["53"].duplicate(true)
 e.cards["53"].abilities.append({"实现":"activated_damage","名称":"测试能力","参数":{"数值":1,"费用":{},"横置":false}})
 attacker=put("53","field")
 view.render()
 await settle()
 await click(point(attacker.uid))
 expect(view.action_menu_open and view.modal,"unit with multiple actions opens an action menu")
 await press_a()
 expect(e.combat.get("attacker",{}).get("uid",0)==attacker.uid and attacker.tapped,"A chooses attack from a multi-action unit's menu")

 print("ATTACK SHORTCUT: ",checks," checks; failures=",failures.size())
 app.queue_free()
 await process_frame
 quit(0 if failures.is_empty() else 1)
