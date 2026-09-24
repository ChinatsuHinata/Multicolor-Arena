extends "res://tests/test_v092.gd"

func nodes_of_type(node: Node,type: String) -> Array:
 var out=[]
 if node.is_class(type):out.append(node)
 for child in node.get_children():out.append_array(nodes_of_type(child,type))
 return out

func run():
 Store.Paths.root_override=ProjectSettings.globalize_path("res://work/stackable-test/"+str(Time.get_ticks_usec()))
 app=load("res://main.tscn").instantiate();root.add_child(app);await process_frame
 app.player_choice=0;app.ai_choice=1;app.begin_battle(true);await process_frame
 view=app.duel_view;view.set_process(false);e=view.engine;clean(true)
 for id in ["token-fdf-129","new-eto-s001","token-fdf-127","token-fdf-128","token-fdn-082"]:
  expect(e.cards[id].stackable and "stackable" in e.cards[id].keywords,id+" 具有 stackable 词条")
 view.inspect_card("token-fdf-129")
 expect("stackable" in view.inspection_text.get_parsed_text(),"卡牌详情展示 stackable 词条")
 var stones=[]
 for i in range(4):stones.append(put("token-fdf-129","field"))
 for id in ["new-eto-s001","token-fdf-127","token-fdf-128","token-fdn-082"]:
  put(id,"field");put(id,"field")
 view.render();await process_frame
 for id in ["token-fdf-129","new-eto-s001","token-fdf-127","token-fdf-128","token-fdn-082"]:
  var displays=view.table.descriptors.values().filter(func(d):return d.card_id==id)
  var expected=4 if id=="token-fdf-129" else 2
  expect(displays.size()==1 and displays[0].members.size()==expected and view.card_badges[displays[0].key].token_count.text=="×%d" % expected,id+" 合并显示正确数量")
 for id in ["token-fdf-129","new-eto-s001","token-fdf-127","token-fdf-128","token-fdn-082"]:
  clean(true)
  var first_copy=e.make_card(id,0,"hand") if id=="new-eto-s001" else e.Cat.printed_token(e,0,id)
  if id=="new-eto-s001":e.players[0].hand.append(first_copy);e.Roster.field_many(e,[first_copy],0)
  view.render();await settle()
  e.turn+=2;e.players[0].turns+=1
  var later_copy=e.make_card(id,0,"hand") if id=="new-eto-s001" else e.Cat.printed_token(e,0,id)
  if id=="new-eto-s001":e.players[0].hand.append(later_copy);e.Roster.field_many(e,[later_copy],0)
  var destination=view.table.layout().values().filter(func(d):return d.card_id==id)
  var arrival_rect=view.reveal_player.zone_rect("field",0,later_copy.uid,false)
  expect(destination.size()==1 and arrival_rect.get_center().distance_to(view.project(destination[0].at))<1,id+" 后续入场动画指向叠放牌")
  view.render();await settle()
  var displayed=view.table.descriptors.values().filter(func(d):return d.card_id==id)
  expect(displayed.size()==1 and displayed[0].members.size()==2 and view.card_badges[displayed[0].key].token_count.text=="×2",id+" 跨回合入场后自动合并")
 clean(true)
 var early=e.make_card("new-eto-s001",0,"hand");e.players[0].hand.append(early)
 e.Roster.field_many(e,[early],0)
 e.turn+=2;e.players[0].turns+=1
 var late=e.make_card("new-eto-s001",0,"hand");e.players[0].hand.append(late)
 e.Roster.field_many(e,[late],0)
 expect(e.stackable_members(early).size()==2,"不同回合进场的灵异珠自动合并")
 view.render();await settle()
 expect(view.table.descriptors.values().filter(func(d):return d.card_id=="new-eto-s001").size()==1,"不同回合进场的灵异珠只显示一张")
 clean(true)
 var first_ball=e.make_card("new-eto-s001",0,"hand");e.players[0].hand.append(first_ball)
 e.move_to(first_ball,"palette");var first_trigger=e.triggers.back();first_trigger.target={"none":true};e.Roster.New.resolve_trigger(e,first_trigger)
 view.render();await settle()
 e.turn+=2;e.players[0].turns+=1
 var second_ball=e.make_card("new-eto-s001",0,"hand");e.players[0].hand.append(second_ball)
 e.move_to(second_ball,"palette");var second_trigger=e.triggers.back();second_trigger.target={"none":true};e.Roster.New.resolve_trigger(e,second_trigger)
 expect(first_ball.zone=="field" and second_ball.zone=="field" and e.stackable_members(first_ball).size()==2,"不同时点触发入场的灵异珠自动合并")
 var ball_layout=view.table.layout().values().filter(func(d):return d.card_id=="new-eto-s001")
 var arrival=view.reveal_player.zone_rect("field",0,second_ball.uid,false)
 expect(ball_layout.size()==1 and arrival.get_center().distance_to(view.project(ball_layout[0].at))<1,"后来入场的灵异珠动画落到已有叠放牌")
 view.render();await settle()
 var final_balls=view.table.descriptors.values().filter(func(d):return d.card_id=="new-eto-s001")
 expect(final_balls.size()==1 and final_balls[0].members.size()==2 and view.card_badges[final_balls[0].key].token_count.text=="×2","入场动画结束后自动合并并更新数量")
 var departure=view.reveal_player.zone_rect("field",0,second_ball.uid,true)
 expect(departure.get_center().distance_to(view.projected_card_rect(view.table.visuals[final_balls[0].key]).get_center())<1,"叠放牌中的灵异珠离场也从叠放位置播放动画")
 clean(true)
 stones=[]
 for i in range(4):stones.append(put("token-fdf-129","field"))
 var changed=e.stackable_members(stones[0])
 changed[1].tapped=true
 view.render();await process_frame
 expect(e.stackable_members(stones[0]).size()==3 and view.table.descriptors.values().filter(func(d):return d.card_id=="token-fdf-129").size()==2,"不同状态的实体分别显示")
 changed[1].tapped=false
 expect(e.commit_extension(0,stones[0].uid,{"player":1,"stackable_count":2},[],"token-fdf-129")=="该牌不能批量牺牲","要石不能批量牺牲")
 expect(e.players[0].field.size()==4 and e.stack.is_empty(),"要石批量请求失败时保持原状")
 view.execute_action({"type":"extension","uid":stones[0].uid,"key":"token-fdf-129","enabled":true})
 expect(not view.modal and view.local.get("stackable_count",0)==1,"点击要石不弹出数量选择")
 view.cancel_cast()
 clean(true)
 var fish=[]
 for i in range(3):fish.append(put("token-fdf-127","field"))
 view.execute_action({"type":"extension","uid":fish[0].uid,"key":"token-fdf-127","enabled":true})
 expect(view.modal and nodes_of_type(view.modal_root,"SpinBox").size()==1,"点击叠放的烤八目鳗可选择牺牲数量")
 var spinner=nodes_of_type(view.modal_root,"SpinBox")[0]
 expect(spinner.max_value==3,"烤八目鳗数量上限为叠放数")
 spinner.value=2
 await press("确认")
 expect(view.local.get("stackable_count",0)==2,"所选数量进入启动流程")
 view.cancel_cast()
 expect(e.commit_extension(0,fish[0].uid,{"none":true,"stackable_count":4},[],"token-fdf-127")=="可牺牲数量不足","拒绝超出实际数量的牺牲请求")
 expect(e.players[0].field.size()==3 and e.stack.is_empty(),"非法牺牲数量不改变战况")
 expect(e.commit_extension(0,fish[0].uid,{"none":true,"stackable_count":2},[],"token-fdf-127").is_empty(),"烤八目鳗可批量牺牲")
 expect(e.players[0].field.size()==1 and e.stack.size()==2,"仅牺牲所选的两条烤八目鳗")
 for i in range(8):
  if e.stack.is_empty():break
  e.pass_priority(e.priority)
 expect(e.players[0].life==22,"两次生命效果分别结算")
 clean(true)
 var wine=put("token-fdf-128","field");put("token-fdf-128","field")
 expect(e.commit_extension(0,wine.uid,{"color":"蓝","stackable_count":2},[],"wine_discount").is_empty(),"美宵之酒可批量牺牲")
 for i in range(8):
  if e.stack.is_empty():break
  e.pass_priority(e.priority)
 expect(e.players[0].wine==["蓝","蓝"],"两次酒的折扣分别保留")
 clean(true)
 var model=e.cards["token-fdf-127"].duplicate(true)
 model.abilities=[{"实现":"activated_damage","名称":"横置：对目标造成1点伤害","参数":{"横置":true,"费用":{},"数值":1}}]
 e.cards["token-fdf-127"]=model
 var first=put("token-fdf-127","field");put("token-fdf-127","field")
 expect(e.commit_ability(0,first.uid,0,{"player":1,"stackable_count":2},[]).is_empty(),"通用启动异能可按数量发动")
 expect(e.stack.size()==2 and e.players[0].field.all(func(c):return c.tapped),"两张来源均被横置且分别入堆叠")
 for i in range(8):
  if e.stack.is_empty():break
  e.pass_priority(e.priority)
 expect(e.players[1].life==18,"两次通用伤害分别结算")
 print("STACKABLE ",checks," checks; failures=",failures)
 app.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
