extends "res://tests/support/ui_base.gd"

func run():
 Store.Paths.root_override=ProjectSettings.globalize_path("res://work/modal-spell-choices-ui/"+str(Time.get_ticks_usec()))
 app=load("res://main.tscn").instantiate();root.add_child(app);await process_frame
 app.load_test_decks();app.begin_battle(true);view=app.duel_view;view.set_process(false);e=view.engine
 clean(true)
 e.debug_free_payment=true
 e.players[0].leader=e.make_card("character-fdf-117",0,"leader",true)
 put("token-fdf-131","field")
 var ally=put("53","field")
 put("53","field",1)
 var spell=put("spell-fdf-072","hand")
 view.local={"uid":spell.uid,"mode":"target"}
 view.render()
 expect(find_button(view.ui,"名称改为不明物体并抓牌")!=null and find_button(view.ui,"牺牲并放入封兽鵺")!=null,"Nightmare displays both distinct modes in the live choice panel")
 var mode=view.picker.available().filter(func(atom):return atom.get("value","")=="名称改为不明物体并抓牌")[0]
 view.inline_pick(mode)
 expect(view.picker.available_refs().size()==3 and find_button(view.ui,"名称改为不明物体并抓牌")==null,"choosing rename mode advances to unit targets")
 view.local={};view.picker.reset();view.render()
 var target=e.ref_target(ally);target.mode="名称改为不明物体并抓牌"
 var error=e.commit_cast(0,spell.uid,target,[])
 expect(error.is_empty(),"fixture casts Nightmare: "+error)
 e.presentation_events.clear();view.reveal_player.reset();view.render()
 var entry=e.stack.back()
 expect(view.stack_panel.tiles[entry.id].caption.text=="已选择：名称改为不明物体并抓牌","declared mode is visible beneath the opponent's stack card")
 view.response_mode=view.ResponseMode.ON;view.render()
 expect(view.hud.get_children().any(func(node):return node is Label and node.text.contains("响应窗口 · 已选择：名称改为不明物体并抓牌")),"response prompt names the opponent's chosen mode")
 print("MODAL_SPELL_CHOICES_UI: ",checks," checks; ",failures.size()," failures")
 quit(0 if failures.is_empty() else 1)
