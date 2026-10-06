extends "res://tests/support/ui_base.gd"

func run():
 Store.Paths.root_override=ProjectSettings.globalize_path("res://work/multi-choice-stack-captions-ui/"+str(Time.get_ticks_usec()))
 root.size=Vector2i(1600,900)
 root.gui_embed_subwindows=true
 app=load("res://main.tscn").instantiate();root.add_child(app);await process_frame
 app.is_android=true
 root.content_scale_aspect=Window.CONTENT_SCALE_ASPECT_EXPAND
 app.refresh_ui_metrics()
 app.load_legacy_test_decks()
 app.clear_page("battle")
 view=preload("res://scripts/duel_view.gd").new();view.is_android=true
 app.duel_view=view;app.screen.add_child(view)
 view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 view.begin(app,app.decks[app.player_choice],app.decks[app.ai_choice],0,42)
 view.set_process(false);e=view.engine
 clean()
 var unit=put("53","field")
 var grave=put("53","grave")
 var alien={"parts":[{"mode":"造成2点伤害","uid":unit.uid,"epoch":unit.epoch},{"mode":"造成2点伤害","uid":unit.uid,"epoch":unit.epoch}]}
 var wheel={"parts":[{"mode":"全体强化","none":true},{"mode":"回收单位","uid":grave.uid,"epoch":grave.epoch,"zone":"grave"}]}
 var kokoro={"picks":[[{"mode":"造成1点伤害","player":0}],[{"mode":"造成1点伤害","player":1}],[{"mode":"反制，除非支付1点","stack_id":100}],[{"mode":"移回手牌","uid":grave.uid,"epoch":grave.epoch,"zone":"grave"}]]}
 for data in [[100,"176",alien],[101,"161",wheel],[102,"spell-htk-003",kokoro]]:
  var card=e.make_card(data[1],1,"stack")
  e.stack.append({"id":data[0],"kind":"card","owner":1,"card":card,"target":data[2],"name":e.cards[card.card_id].name})
 view.render();await process_frame
 var expected={100:"已选择：造成2点伤害 ×2",101:"已选择：己方单位获得+1/+0与+1、将目标墓地单位移回手上",102:"（造成2点伤害，对手需要多支付1费，将1张目标道具或单位移回手上）"}
 for id in expected:
  var tile=view.stack_panel.tiles[id]
  expect(tile.caption.text==expected[id],"Android stack shows all choices for "+str(id))
  expect(tile.tile.tooltip_text.contains(expected[id]),"Android stack tooltip retains the complete caption for "+str(id))
  expect(tile.caption.get_visible_line_count()==tile.caption.get_line_count(),"Android stack caption does not clip choices for "+str(id))
 print("MULTI_CHOICE_STACK_CAPTIONS_UI: ",checks," checks; ",failures.size()," failures")
 quit(0 if failures.is_empty() else 1)
