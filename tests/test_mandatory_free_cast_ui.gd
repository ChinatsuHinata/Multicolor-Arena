extends "res://tests/support/ui_base.gd"

func run():
 Store.Paths.root_override=ProjectSettings.globalize_path("res://work/mandatory-free-ui/"+str(Time.get_ticks_usec()))
 app=load("res://main.tscn").instantiate();root.add_child(app);await process_frame
 app.load_test_decks();app.begin_battle(true);view=app.duel_view;view.set_process(false);e=view.engine

 clean()
 var youmu=put("character-fdf-102","field");youmu.leader=true
 var palette_spell=put("spell-fdf-049","palette")
 view.request_cast(palette_spell.uid)
 expect(view.local.get("mode","")=="target" and find_button(view.ui,"支付颜色使用")==null,"Youmu palette cast goes directly to targets")

 clean()
 var unit=put("53","hand")
 e.players[0].next_free_unit=e.turn
 view.request_cast(unit.uid)
 expect(view.local.get("mode","")=="target" and find_button(view.ui,"支付颜色使用")==null,"next unit free cast hides paid option")

 clean()
 put("spell-ucs-019","field")
 unit=put("53","hand")
 view.request_cast(unit.uid)
 expect(view.local.get("mode","")=="free_offer" and find_button(view.ui,"支付颜色使用")!=null,"optional free anthem retains paid option")

 clean()
 put("53","field")
 var granted=put("112","hand")
 e.Cat.grant_cast(e,granted,0,true)
 view.render()
 expect(e.pending.get("kind","")=="effect_choice" and find_button(view.ui,"支付颜色使用")==null,"mandatory immediate grant hides paid option")

 clean()
 put("53","field")
 granted=put("112","hand")
 e.Cat.grant_cast(e,granted,0,true,{},true)
 view.render()
 expect(e.pending.get("kind","")=="effect_choice" and find_button(view.ui,"支付颜色使用")!=null,"optional immediate grant retains paid option")

 print("MANDATORY_FREE_CAST_UI: ",checks," checks; ",failures.size()," failures")
 quit(0 if failures.is_empty() else 1)
