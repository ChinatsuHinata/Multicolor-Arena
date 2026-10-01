extends "res://tests/support/ui_base.gd"

func deck_tile(node: Node, zone: String, index: int):
 if node.get_script()==load("res://scripts/deck_card.gd") and node.source_zone==zone and node.source_index==index:return node
 for child in node.get_children():
  var found=deck_tile(child,zone,index)
  if found:return found
 return null

func run():
 Store.Paths.root_override=ProjectSettings.globalize_path("res://work/deck-drag-tests/"+str(Time.get_ticks_usec()))
 root.size=Vector2i(1600,900)
 root.gui_embed_subwindows=true
 app=load("res://main.tscn").instantiate()
 root.add_child(app)
 await process_frame
 app.is_android=true
 root.content_scale_aspect=Window.CONTENT_SCALE_ASPECT_EXPAND
 app.refresh_ui_metrics()
 app.editor()
 app.editor_ui.set_overview(true)
 await process_frame
 var precon=JSON.parse_string(FileAccess.get_file_as_string("res://data/test_precons.json")).decks[0]
 var ids=[precon.main[0],precon.main[2],precon.main[4],precon.main[6],precon.main[8]]
 var deck=Store.blank("拖拽顺序测试")
 deck.rule_set="test"
 deck.leader=precon.leader
 deck.main=[ids[0],ids[1],ids[0],ids[2]]
 while deck.main.size()<70:deck.main.append(ids[3])
 deck.side=[ids[4],ids[2]]
 while deck.side.size()<10:deck.side.append(ids[3])
 expect(Store.validate(deck,false,"test").is_empty(),"full deck drag fixture is valid")
 app.draft=deck
 app.dirty=false
 app.update_deck_rows()
 await process_frame

 var source=deck_tile(app.deck_canvas,"main",2)
 var target=deck_tile(app.deck_canvas,"main",1)
 await drag(source.get_global_rect().get_center(),target.get_global_rect().get_center())
 expect(app.draft.main.slice(0,4)==[ids[0],ids[0],ids[1],ids[2]],"dragging onto a card reorders the chosen duplicate")
 expect(app.deck_insert_index("main",app.main_card_rect(2).position+Vector2(0,10))==2 and app.deck_insert_index("side",Vector2(app.editor_ui.side_stride,10))==1,"responsive gaps resolve to their insertion slots")
 app.drop_editor_card({"card_id":ids[2],"source_zone":"main","source_index":3},"main",2)
 expect(app.draft.main.slice(0,4)==[ids[0],ids[0],ids[2],ids[1]],"gap insertion moves a card without changing deck size")
 for frame in range(4):await process_frame

 source=deck_tile(app.deck_canvas,"main",0)
 target=deck_tile(app.deck_canvas,"side",0)
 await drag(source.get_global_rect().get_center(),target.get_global_rect().get_center())
 expect(app.draft.main[0]==ids[4] and app.draft.side[0]==ids[0] and app.draft.main.size()==70 and app.draft.side.size()==10,"card-to-card drag swaps full main and side decks")
 expect(not app.get_children().any(func(node):return node is AcceptDialog and not node.is_queued_for_deletion()),"full-deck swap shows no limit error")
 source=deck_tile(app.deck_canvas,"side",1)
 target=deck_tile(app.deck_canvas,"main",1)
 await drag(source.get_global_rect().get_center(),target.get_global_rect().get_center())
 expect(app.draft.main[1]==ids[2] and app.draft.side[1]==ids[0],"side-to-main card drag also swaps exact slots")

 var unchanged=app.draft.duplicate(true)
 app.drop_editor_card({"card_id":ids[3],"source_zone":"library","source_index":0},"side")
 expect(app.draft==unchanged,"adding from the library still obeys the full side limit")
 var dialogs=app.get_children().filter(func(node):return node is AcceptDialog and not node.is_queued_for_deletion())
 expect(dialogs.size()==1 and dialogs[0].dialog_text.contains("上限"),"a true extra card still reports the limit")
 for dialog in dialogs:dialog.queue_free()
 await process_frame

 app.draft.side.remove_at(9)
 app.update_deck_rows()
 await process_frame
 source=deck_tile(app.deck_canvas,"main",0)
 var moved_id=source.card_id
 var side_before=app.draft.side.duplicate()
 var side_scroll=app.editor_ui.side_scroll
 side_scroll.scroll_horizontal=int(side_scroll.get_h_scroll_bar().max_value)
 for frame in range(4):await process_frame
 await drag(source.get_global_rect().get_center(),side_scroll.get_global_rect().end-Vector2(8,30))
 expect(app.draft.main.size()==69 and app.draft.side.size()==10 and app.draft.side==side_before+[moved_id],"cross-deck blank-area drop still moves one card")
 var decoded=Store.decode(Store.encode(app.draft))
 expect(not decoded.has("error") and decoded.deck.main==app.draft.main and decoded.deck.side==app.draft.side,"saved deck code preserves the dragged order")

 print("DECK DRAG ORDER: ",checks," checks; ",failures.size()," failures")
 quit(0 if failures.is_empty() else 1)
