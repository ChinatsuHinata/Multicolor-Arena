extends "res://tests/support/ui_base.gd"
func labels(node: Node) -> Array:
 var result=[]
 if node is Label:result.append(node.text)
 for child in node.get_children():result.append_array(labels(child))
 return result
func run():
 Store.Paths.root_override=ProjectSettings.globalize_path("res://work/curse-ui/"+str(Time.get_ticks_usec()))
 app=load("res://main.tscn").instantiate();root.add_child(app);await process_frame
 app.load_test_decks();app.begin_battle(true);view=app.duel_view;view.set_process(false);e=view.engine;clean()
 e.debug_enabled=true;e.debug_free_payment=true;e.players[1].life=60
 put("character-fdf-ex02","field")
 for count in range(1,6):
  var curse=put("spell-fdf-014","hand");e.priority=0
  expect(e.commit_cast(0,curse.uid,{"none":true},[]).is_empty(),"界面场景实际使用第 %d 张诅咒" % count)
  resolve()
  e.presentation_events.clear();view.reveal_player.reset()
  for top_down in [false,true]:
   view.table.set_top_down_view(top_down);view.render();await process_frame
   var widget=view.life_widgets[1];var warnings=widget.get("curse_warnings",[])
   expect(warnings.size()==mini(count,4),"两种视角下，诅咒图标最多显示四个：%d / %s" % [count,top_down])
   for i in range(warnings.size()):
    expect(not warnings[i].get_rect().intersects(widget.bar.get_rect()) and widget.button.get_rect().size==Vector2(218,61),"警告不遮住生命条或撑大生命区域")
    if i>0:expect(not warnings[i-1].get_rect().intersects(warnings[i].get_rect()),"相邻警告保持间距")
 await capture("curse-warning-thin-border")
 e.enter_field(put("53","hand",1),1);e.pump_choices();e.presentation_events.clear();view.reveal_player.reset();view.render();await process_frame
 expect(e.pending.get("kind","")=="trigger_order" and e.pending.options.size()==5,"五层诅咒均进入触发排序")
 var descriptions=labels(view.modal_root).filter(func(text):return text.contains("对手失去2点生命"))
 expect(descriptions.size()==5 and not labels(view.modal_root).any(func(text):return text.contains("cat:etb_curse")),"触发排序中的五个能力显示中文说明")
 await capture("curse-trigger-chinese-order")
 while e.pending.get("kind","")=="trigger_order":e.choose_trigger_order(0)
 view.render();await process_frame
 expect(view.stack_panel.tiles.size()==5 and view.stack_panel.tiles.values().all(func(tile):return tile.caption.text.contains("对手失去2点生命") and not tile.tile.tooltip_text.contains("cat:etb_curse")),"堆叠和悬停提示显示五个独立中文能力")
 # Old saved entries are rendered through the same UI path.
 for entry in e.stack:entry.ability_text="cat:etb_curse"
 view.render();await process_frame
 expect(view.stack_panel.tiles.values().all(func(tile):return tile.caption.text.contains("对手失去2点生命")),"旧存档的占位符在堆叠界面恢复为中文")
 print("CURSE_UI: ",checks," checks; ",failures.size()," failures")
 quit(0 if failures.is_empty() else 1)
