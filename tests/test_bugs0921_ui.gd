extends "res://tests/support/ui_base.gd"
func nodes_of_type(node,type):
 var out=[]
 if node.is_class(type):out.append(node)
 for child in node.get_children():out.append_array(nodes_of_type(child,type))
 return out
func run():
 Store.Paths.root_override=ProjectSettings.globalize_path("res://work/bugs0921-ui/"+str(Time.get_ticks_usec()))
 app=load("res://main.tscn").instantiate();root.add_child(app);await process_frame
 app.player_choice=0;app.ai_choice=1;app.begin_battle(true);await process_frame
 view=app.duel_view;view.set_process(false);e=view.engine;clean(true)
 var unit=put("53","field");unit.plus_counters=3;unit.minus_counters=1;unit.wards=[{"amount":2,"turn":-1}]
 var palette=put("164","palette");palette.poverty=2
 var tokens=[]
 for i in range(12):tokens.append(put("token-fdf-129","field"))
 view.render();await settle()
 var token_descriptors=view.table.descriptors.values().filter(func(d):return d.card_id=="token-fdf-129")
 expect(token_descriptors.size()==1 and token_descriptors[0].members.size()==12,"12个相同要石合并一张卡图")
 expect(e.players[0].field.size()==13,"展示合并不改变真实卡牌数量")
 var token_key=token_descriptors[0].key
 expect(view.card_badges[token_key].token_count.text=="×12","要石卡图标出数量")
 var badge=view.card_badges["card_"+str(unit.uid)]
 expect(badge.has("counters") and "+3" in badge.counters.text and "−1" in badge.counters.text and "防避 2" in badge.counters.text,"战场卡面显示增减指示物和防避")
 expect(view.card_badges["card_"+str(palette.uid)].counters.text.contains("贫穷 2"),"颜色盘指示物显示")
 view.inspect_card(unit.card_id,unit.uid)
 expect("防避：2" in view.inspection_text.get_parsed_text() and "+3/+3/+3" in view.inspection_text.get_parsed_text(),"左侧详情与卡面指示物一致")
 await capture("bugs0921-counters")
 view.selection=[tokens[0].uid];view.render();await settle()
 token_descriptors=view.table.descriptors.values().filter(func(d):return d.card_id=="token-fdf-129")
 expect(token_descriptors.size()==2 and token_descriptors.any(func(d):return d.members.size()==11),"多选时选中要石独立展开，其余仍显示数量")
 view.selection=[]
 expect(e.commit_extension(0,tokens[0].uid,{"player":0},[],"token-fdf-129").is_empty(),"合并要石可正常发动且只牺牲一个")
 e.pass_priority(e.priority);e.pass_priority(e.priority);view.render();await settle()
 expect(e.players[0].field.filter(func(c):return c.card_id=="token-fdf-129").size()==11,"使用后剩余11个要石")
 expect(view.table.descriptors.values().filter(func(d):return d.card_id=="token-fdf-129").size()==1,"使用后重新合并剩余要石")
 clean(true)
 var momiji=put("character-fdf-101","field");e.Cat.Units.on_enter(e,momiji);e.pump_choices();view.render();await settle()
 expect(e.stack.size()==1,"雪中椛进场有待选卡名的触发")
 expect(view.modal and is_instance_valid(view.modal_root) and not view.stack_panel.visible,"卡名检索窗口独立置顶，堆叠让出输入区域")
 var panel=view.modal_root.get_child(0)
 expect(panel.get_meta("name_picker",false) and panel.get_global_rect().get_center().distance_to(Vector2(800,450))<1,"卡名检索窗口居中")
 var search=nodes_of_type(panel,"LineEdit")[0];search.text="博丽灵梦";search.text_changed.emit(search.text);await process_frame
 var buttons=nodes_of_type(panel,"Button").filter(func(b):return b.visible and "博丽灵梦" in b.text)
 expect(not buttons.is_empty(),"能够检索卡名")
 await capture("bugs0921-name-picker")
 await click(buttons[0].get_global_rect().get_center());await settle();await press("确定");await settle()
 expect(e.pending.is_empty() and e.stack[0].target.has("card_name"),"鼠标选择名称并确认，触发留在堆叠等待响应")
 expect(view.stack_panel.visible,"选名结束后恢复堆叠显示")
 app.editor();await process_frame
 app.query="照国";app.update_library();await process_frame
 # The renderer filters aliases; keeping the old ID still lets old deck files load.
 expect(app.library.get_child_count()==1 and app.Store.CARDS["spell-rec-056"].canonical_id=="spell-kmo-003","组卡器照国只显示一张并保留旧ID兼容")
 print("BUGS0921 UI ",checks," checks; failures=",failures)
 app.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
